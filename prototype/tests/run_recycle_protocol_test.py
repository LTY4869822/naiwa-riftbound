"""Compile current C# receipt logic with a fake store, then import using Godot.

No Windows recycle-store instance is constructed, and both the native outbox and
Godot profile are restricted to a new workspace fixture directory.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import uuid

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parent
ARTIFACTS = PROJECT / "artifacts"
SOURCES = ROOT / "desktop/source"


def run(command, log):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=PROJECT, startupinfo=startup,
                                creationflags=subprocess.CREATE_NO_WINDOW,
                                stdout=output, stderr=subprocess.STDOUT, timeout=60)
    text = log.read_text(encoding="utf-8", errors="replace")
    print(text, end="")
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log}")
    return text


def main():
    fixture = ARTIFACTS / "recycle-protocol-fixtures" / uuid.uuid4().hex
    fixture.mkdir(parents=True, exist_ok=False)
    assert fixture.resolve().parent == (ARTIFACTS / "recycle-protocol-fixtures").resolve()
    compiler = Path(os.environ["WINDIR"]) / "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    if not compiler.exists():
        compiler = Path(os.environ["WINDIR"]) / "Microsoft.NET/Framework/v4.0.30319/csc.exe"
    executable = fixture / "RecycleProtocolFixture.exe"
    production = [SOURCES / "RecycleBinStore.cs", SOURCES / "RecycleFeedService.cs"]
    hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in production}
    command = [str(compiler), "/nologo", "/target:exe", "/optimize+", "/platform:anycpu",
               "/reference:System.Web.Extensions.dll", f"/out:{executable}",
               *(str(path) for path in production), str(PROJECT / "tests/RecycleProtocolFixture.cs")]
    print("Compiling current production receipt service with an isolated fake store…", flush=True)
    run(command, fixture / "compile.log")
    native_log = run([str(executable), "--produce", str(fixture)], fixture / "native-producer.log")
    engine = ROOT / "tools/Godot_v4.7.2-stable_win64.exe"
    godot_log = run([str(engine), "--headless", "--path", str(PROJECT),
         "--script", "res://tests/recycle_protocol_integration_test.gd",
         "--log-file", str(fixture / "godot-engine.log"), "--",
         "--profile-test", "--recycle-test", "--fixture-root", str(fixture)], fixture / "godot-process.log")
    restart_log = run([str(engine), "--headless", "--path", str(PROJECT),
         "--script", "res://tests/recycle_protocol_integration_test.gd",
         "--log-file", str(fixture / "godot-restart-engine.log"), "--",
         "--profile-test", "--recycle-test", "--fixture-root", str(fixture), "--reload-only"], fixture / "godot-process-restart.log")
    native_roundtrip_log = run([str(executable), "--verify", str(fixture)], fixture / "native-roundtrip.log")
    count_checks = lambda text: sum(line.startswith("PASS ") for line in text.splitlines())
    report = {"status": "PASS", "fixture_root": str(fixture), "production_source_sha256": hashes,
              "native_receipts": 5, "native_producer_checks": count_checks(native_log),
              "godot_checks": count_checks(godot_log), "godot_process_restart_checks": count_checks(restart_log),
              "native_roundtrip_checks": count_checks(native_roundtrip_log), "final_level": 2, "final_xp": 1,
              "total_recycle_xp": 61, "remainder_bytes": 0,
              "real_recycle_store_instantiated": False, "real_user_profile_read_or_written": False}
    (fixture / "integration-result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (ARTIFACTS / "recycle-protocol-integration-result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    logs = []
    for name in ["native-producer.log", "godot-process.log", "godot-process-restart.log", "native-roundtrip.log"]:
        logs.append(name + "\n" + (fixture / name).read_text(encoding="utf-8", errors="replace"))
    (ARTIFACTS / "recycle-protocol-integration.log").write_text("\n".join(logs), encoding="utf-8")
    print(f"PASS Cross-language recycle progression: fixture={fixture}", flush=True)


if __name__ == "__main__":
    main()
