/* Browser adapter for the genuine Godot Web export. No simulation of gameplay. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const state = window.__naiwa = {status: 'ready', errors: [], logs: [], edition: 'web-2026-10-31'};
  const nativeFetch = window.fetch.bind(window);
  let manifest, engine;
  const verifiedParts = new Set();
  function updateDownload(item) {
    if (verifiedParts.has(item.file)) return;
    verifiedParts.add(item.file);
    state.bytesLoaded = (state.bytesLoaded || 0) + item.compressed_size;
    const percent = Math.min(98, Math.floor(state.bytesLoaded / state.downloadBytes * 98));
    $('progress').value = percent;
    $('percent').textContent = percent + '%';
    $('load-detail').textContent = (state.bytesLoaded / 1048576).toFixed(1) + ' / ' + (state.downloadBytes / 1048576).toFixed(1) + ' MB · 首次载入后资源会缓存';
    $('status').textContent = percent === 98 ? '正在唤醒奶蛙…' : '正在装好冒险行囊…';
  }
  function log(kind, args) {
    const value = args.map(String).join(' ');
    state[kind].push(value);
    if (state[kind].length > 150) state[kind].shift();
    if (kind === 'errors') $('canvas').dataset.engineErrors = JSON.stringify(state.errors);
  }
  function failure(error) {
    if (state.status === 'failed') return;
    state.status = 'failed'; log('errors', [error.message || error]);
    $('loading').hidden = true;
    $('failure').textContent = '游戏未能载入。请检查网络后重试，或使用新版 Chrome、Edge、Safari 浏览器。';
    $('failure').hidden = false; $('retry').hidden = false;
  }
  async function loadPart(item) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 90000);
      try {
        const response = await nativeFetch(item.file, {signal: controller.signal, cache: 'force-cache'});
        if (!response.ok) throw new Error(`Resource request failed: ${response.status}`);
        // Buffer a whole compressed part before emitting any of its bytes. A failed
        // response can then be retried without duplicating half a part in the pack.
        const bytes = await response.arrayBuffer();
        if (bytes.byteLength !== item.compressed_size) throw new Error('Incomplete resource download');
        const digest = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
          .map(byte => byte.toString(16).padStart(2, '0')).join('');
        if (!item.file.includes(digest.slice(0, 12))) throw new Error('Resource checksum mismatch');
        updateDownload(item);
        return bytes;
      } catch (error) {
        if (attempt === 3) throw error;
        $('status').textContent = `网络波动，正在重试资源… ${attempt + 1}/3`;
        await new Promise(resolve => setTimeout(resolve, 750 * (attempt + 1)));
      } finally { clearTimeout(timer); }
    }
  }
  // A stream of independently compressed parts keeps every hosted file small.
  window.fetch = async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url || String(input), location.href);
    const name = url.pathname.split('/').pop();
    const record = url.origin === location.origin && manifest?.files[name];
    if (!record) return nativeFetch(input, init);
    let part = 0, reader;
    const pending = new Map();
    const queue = index => {
      if (index < record.parts.length && !pending.has(index)) {
        pending.set(index, loadPart(record.parts[index]).then(value => ({value}), error => ({error})));
      }
    };
    queue(0); queue(1);
    const body = new ReadableStream({
      async pull(controller) {
        try {
          while (true) {
            if (!reader) {
              if (part >= record.parts.length) { controller.close(); return; }
              const result = await pending.get(part);
              pending.delete(part++); queue(part + 1);
              if (result.error) throw result.error;
              reader = new Blob([result.value]).stream().pipeThrough(new DecompressionStream('gzip')).getReader();
            }
            const result = await reader.read();
            if (result.done) { reader.releaseLock(); reader = null; continue; }
            controller.enqueue(result.value); return;
          }
        } catch (error) { failure(error); controller.error(error); }
      },
      async cancel(reason) { if (reader) await reader.cancel(reason); }
    });
    return new Response(body, {status: 200, headers: {'Content-Type': record.mime, 'Content-Length': String(record.size)}});
  };
  $('start').addEventListener('click', async () => {
    if (state.status !== 'ready') return;
    state.status = 'loading'; $('start').hidden = true; $('start').disabled = true;
    $('launch-row').hidden = true; $('loading').hidden = false;
    try {
      if (!window.Engine || typeof DecompressionStream === 'undefined') throw new Error('Required browser features unavailable');
      const missing = Engine.getMissingFeatures({threads: false});
      if (missing.length) throw new Error(missing.join(', '));
      manifest = await (await nativeFetch('game-manifest.json', {cache: 'no-store'})).json();
      state.downloadBytes = manifest.download_bytes;
      $('status').textContent = '正在载入奶蛙世界…';
      engine = window.naiwaEngine = new Engine({executable: 'naiwa', mainPack: 'naiwa.pck',
        canvas: $('canvas'), canvasResizePolicy: 2, focusCanvas: true, args: [],
        fileSizes: Object.fromEntries(Object.entries(manifest.files).map(([name, file]) => [name, file.size])),
        onPrint: (...args) => log('logs', args), onPrintError: (...args) => log('errors', args),
        onExit: () => { state.status = 'exited'; location.reload(); }});
      await engine.startGame();
      if (state.status === 'failed') return;
      state.status = 'playing'; $('cover').hidden = true; $('canvas').focus();
      $('audio-hint').hidden = false;
      $('canvas').addEventListener('pointerdown', () => $('audio-hint').hidden = true, {once: true});
      updateRotation();
    } catch (error) { failure(error); }
  });
  $('retry').addEventListener('click', () => location.reload());
  $('fullscreen').addEventListener('click', async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await $('stage').requestFullscreen();
      $('canvas').focus();
    } catch (_) { /* The game remains playable in an embedded browser. */ }
  });
  function updateRotation() {
    $('rotate').hidden = !(state.status === 'playing' && matchMedia('(pointer: coarse)').matches && innerHeight > innerWidth);
  }
  window.addEventListener('resize', updateRotation);
  window.addEventListener('error', event => log('errors', [event.message]));
  window.addEventListener('unhandledrejection', event => log('errors', [String(event.reason)]));
})();
