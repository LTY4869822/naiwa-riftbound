// Exercise actual loader code with interrupted/corrupt network responses.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const zlib = require('node:zlib');
const {createHash, webcrypto} = require('node:crypto');
const source = fs.readFileSync(new URL('../web/dist/app.js', `file:///${__filename.replaceAll('\\','/')}`), 'utf8');

async function check(scenario) {
  const elements = new Map();
  const element = id => {
    if (!elements.has(id)) elements.set(id, {hidden:false, dataset:{}, handlers:{},
      addEventListener(name, handler) {this.handlers[name] = handler;}, focus() {}});
    return elements.get(id);
  };
  const chunks = ['first half of a real stream', 'second half of a real stream'].map(text => Buffer.from(text));
  const payload = Buffer.concat(chunks);
  const compressed = chunks.map(chunk => zlib.gzipSync(chunk));
  const parts = compressed.map((data, index) => ({
    file:`assets/part-${index}-${createHash('sha256').update(data).digest('hex').slice(0,12)}.gz`,
    size:chunks[index].length, compressed_size:data.length
  }));
  const manifest = {download_bytes:compressed.reduce((n,b) => n+b.length,0), files:{
    'naiwa.wasm':{size:payload.length,mime:'application/wasm',parts},
    'naiwa.pck':{size:payload.length,mime:'application/octet-stream',parts}
  }};
  const calls = new Map();
  const window = {addEventListener() {}};
  const fetch = async url => {
    if (url === 'game-manifest.json') return new Response(JSON.stringify(manifest));
    const index = parts.findIndex(part => part.file === url);
    assert.notEqual(index, -1);
    const count = (calls.get(url) || 0) + 1; calls.set(url, count);
    if (scenario === 'permanent') throw new TypeError('network error');
    if (index === 0 && count === 1) {
      if (scenario === 'interrupted') return {ok:true, arrayBuffer:async () => {throw new TypeError('network error');}};
      if (scenario === 'truncated') return new Response(compressed[index].subarray(0,5));
      if (scenario === 'corrupt') return new Response(Buffer.alloc(compressed[index].length, 0));
    }
    return new Response(compressed[index]);
  };
  window.fetch = fetch;
  let verified = 0;
  class Engine {
    static getMissingFeatures() {return [];}
    constructor(config) {this.config = config;}
    async startGame() {
      await Promise.all(Object.keys(manifest.files).map(async name => {
        const response = await window.fetch(name);
        assert.equal(response.headers.get('content-type'), manifest.files[name].mime);
        assert.deepEqual(Buffer.from(await response.arrayBuffer()), payload);
        verified++;
      }));
    }
  }
  window.Engine = Engine;
  vm.runInNewContext(source, {window, document:{getElementById:element}, Engine,
    location:{href:'https://example.test/',origin:'https://example.test',reload() {}},
    URL, Response, ReadableStream, DecompressionStream, Blob, AbortController,
    crypto:webcrypto, clearTimeout, setTimeout:(fn, delay) => setTimeout(fn, delay === 90000 ? delay : 0),
    matchMedia:() => ({matches:false}), innerHeight:800, innerWidth:1280});
  await element('start').handlers.click();
  if (scenario === 'permanent') {
    assert.equal(window.__naiwa.status, 'failed');
    assert.equal(element('retry').hidden, false);
    assert.equal(element('failure').hidden, false);
  } else {
    assert.equal(window.__naiwa.status, 'playing');
    assert.equal(verified, 2);
    assert.equal(element('cover').hidden, true);
  }
  assert.ok([...calls.values()].every(count => count <= (scenario === 'permanent' ? 8 : 3)));
  return scenario;
}
(async () => {
  const passed = [];
  for (const scenario of ['normal','interrupted','truncated','corrupt','permanent']) passed.push(await check(scenario));
  console.log(JSON.stringify({passed, identical_reconstructed_streams:true}));
})().catch(error => {console.error(error);process.exitCode=1;});
