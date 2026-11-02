"""Prepare the LIN4RUN desktop fork without overwriting maintained source.

The optional download command uses official HTTPS release/NuGet endpoints only.
No upstream executable is ever launched by this script.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "references/LIN4RUN-naiwa"
CACHE = ROOT / "references/releases"
DESTINATION = ROOT / "desktop/lin4run"
SOURCE = DESTINATION / "source"
COMMIT = "55e005b2ad6a1482a9d6544d8d691d87b23d9f1b"
RELEASE_URL = "https://github.com/LIN4RUN/naiwa-desktop-pet/releases/download/v2.5.1/naiwa-pet-v2.5.1-portable.zip"
RELEASE_SIZE = 196196375
RELEASE_SHA256 = "4529f445e6b75f3f39a50c338ef54e6bbddb620db9772ca025fd88597e10b13b"
RELEASE = CACHE / "naiwa-pet-v2.5.1-portable.zip"
COMPILER_URL = "https://api.nuget.org/v3-flatcontainer/microsoft.net.compilers.toolset/5.0.0/microsoft.net.compilers.toolset.5.0.0.nupkg"
COMPILER_SIZE = 22199160
COMPILER_SHA256 = "e3f0207e7a8caf2cf79ad8f276eb20b2b880b3a7bb0e8ad27b4d3183d0a81627"
COMPILER_PACKAGE = CACHE / "microsoft.net.compilers.toolset.5.0.0.nupkg"
COMPILER_DEST = ROOT / "tools/roslyn-5.0.0"


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def valid_download(path: Path, size: int, expected_hash: str | None) -> bool:
    return path.is_file() and path.stat().st_size == size and (expected_hash is None or sha256(path) == expected_hash)


def download(url: str, target: Path, size: int, expected_hash: str | None) -> None:
    """Download exact verified ranges; an interrupted own cache is resumable."""
    if valid_download(target, size, expected_hash):
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "NaiwaLocalBuild/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        resolved = response.url
        if int(response.headers.get("Content-Length", size)) != size:
            raise RuntimeError("Official download size changed; update the pinned release first")
    parts = target.parent / (target.name + ".parts")
    parts.mkdir(exist_ok=True)
    chunk = 2 * 1024 * 1024
    ranges = [(index, start, min(size - 1, start + chunk - 1)) for index, start in enumerate(range(0, size, chunk))]
    prefix = target.with_name(target.name + ".download")
    if prefix.is_file():
        with prefix.open("rb") as stream:
            for index, start, end in ranges:
                if prefix.stat().st_size <= end:
                    break
                part = parts / str(index)
                if not part.is_file() or part.stat().st_size != end - start + 1:
                    stream.seek(start)
                    part.write_bytes(stream.read(end - start + 1))

    def one(item: tuple[int, int, int]) -> int:
        index, start, end = item
        part = parts / str(index)
        length = end - start + 1
        if part.is_file() and part.stat().st_size == length:
            return index
        for attempt in range(4):
            try:
                request = urllib.request.Request(resolved, headers={"Range": f"bytes={start}-{end}", "User-Agent": "NaiwaLocalBuild/1.0"})
                with urllib.request.urlopen(request, timeout=45) as response:
                    expected_range = f"bytes {start}-{end}/{size}"
                    if response.status != 206 or response.headers.get("Content-Range") != expected_range:
                        raise RuntimeError("Download server did not honor the exact requested range")
                    data = response.read(length + 1)
                if len(data) != length:
                    raise RuntimeError("Incomplete range")
                temporary = part.with_suffix(".tmp")
                temporary.write_bytes(data)
                temporary.replace(part)
                return index
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(1 + attempt)
        raise RuntimeError("Unreachable download state")

    complete = 0
    with ThreadPoolExecutor(max_workers=24) as executor:
        for future in as_completed([executor.submit(one, item) for item in ranges]):
            future.result()
            complete += 1
            if complete % 8 == 0 or complete == len(ranges):
                print(f"{target.name}: {complete}/{len(ranges)} ranges complete", flush=True)
    temporary = target.with_name(target.name + ".assembled")
    with temporary.open("wb") as output:
        for index, _, _ in ranges:
            with (parts / str(index)).open("rb") as stream:
                shutil.copyfileobj(stream, output)
    if not valid_download(temporary, size, expected_hash):
        raise RuntimeError("Downloaded package failed the pinned size/hash check")
    with zipfile.ZipFile(temporary) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("Downloaded package has a corrupt ZIP entry")
    temporary.replace(target)


def safe_entries(archive: zipfile.ZipFile):
    for entry in archive.infolist():
        path = PurePosixPath(entry.filename.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts or ":" in entry.filename:
            raise RuntimeError("Unsafe archive path")
        if not entry.is_dir():
            yield entry, path


def copy_if_missing(source: Path, destination: Path) -> None:
    if source.is_file() and not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def prepare_sources() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    for source in (REFERENCE / "源码/NaiwaDesktop").glob("*.cs"):
        copy_if_missing(source, SOURCE / source.name)
    for name in ("app.manifest", "app.ico"):
        copy_if_missing(REFERENCE / "源码" / name, SOURCE / name)
    copy_if_missing(REFERENCE / "LICENSE", DESTINATION / "LICENSE")
    copy_if_missing(REFERENCE / "README.md", DESTINATION / "UPSTREAM_README.md")


def prepare_assets() -> list[dict]:
    if not valid_download(RELEASE, RELEASE_SIZE, RELEASE_SHA256):
        raise RuntimeError("Pinned portable ZIP missing; run this script with --download")
    records = []
    with zipfile.ZipFile(RELEASE) as archive:
        for entry, path in safe_entries(archive):
            if path.suffix.lower() not in (".nwp", ".mp3", ".wav"):
                continue
            target = DESTINATION / path.name
            data = archive.read(entry)
            digest = hashlib.sha256(data).hexdigest()
            if not target.is_file() or sha256(target) != digest:
                target.write_bytes(data)
            records.append({"name": path.name, "bytes": len(data), "sha256": digest})
    return records


def prepare_compiler() -> None:
    if not valid_download(COMPILER_PACKAGE, COMPILER_SIZE, COMPILER_SHA256):
        raise RuntimeError("Roslyn package missing; run this script with --download")
    with zipfile.ZipFile(COMPILER_PACKAGE) as archive:
        for entry, path in safe_entries(archive):
            if not path.as_posix().startswith("tasks/net472/"):
                continue
            target = COMPILER_DEST.joinpath(*path.parts[2:])
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(entry))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true")
    arguments = parser.parse_args()
    prepare_sources()
    if arguments.download:
        with ThreadPoolExecutor(max_workers=2) as executor:
            jobs = [executor.submit(download, RELEASE_URL, RELEASE, RELEASE_SIZE, RELEASE_SHA256),
                    executor.submit(download, COMPILER_URL, COMPILER_PACKAGE, COMPILER_SIZE, COMPILER_SHA256)]
            for job in jobs:
                job.result()
    records = prepare_assets()
    prepare_compiler()
    provenance = {"repository": "https://github.com/LIN4RUN/naiwa-desktop-pet", "source_commit": COMMIT,
                  "assets_release": "v2.5.1", "portable_url": RELEASE_URL, "portable_sha256": RELEASE_SHA256,
                  "compiler_package": "Microsoft.Net.Compilers.Toolset/5.0.0", "compiler_sha256": sha256(COMPILER_PACKAGE),
                  "assets": records, "maintained_source_overwritten": False}
    (DESTINATION / "UPSTREAM_PROVENANCE.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Prepared {len(records)} original asset files; maintained C# source was preserved.", flush=True)


if __name__ == "__main__":
    main()
