import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const listeners={},items=new Map();let network=0;
const normalize=x=>new URL(typeof x==='string'?x:x.url,'https://example.test/').href;
const cache={match:async x=>items.get(normalize(x))?.clone(),put:async(x,r)=>items.set(normalize(x),r.clone()),addAll:async paths=>{for(const p of paths)items.set(normalize(p),new Response('cached '+p))},add:async p=>items.set(normalize(p),new Response('optional '+p))};
vm.runInNewContext(readFileSync(new URL('../dist/sw.js',import.meta.url),'utf8'),{self:{registration:{scope:'https://example.test/'},clients:{claim:async()=>{}},addEventListener:(n,f)=>listeners[n]=f},location:{origin:'https://example.test'},URL,Set,Promise,caches:{open:async()=>cache},fetch:async()=>{network++;return new Response('network')}});
let work;listeners.install({waitUntil:p=>work=p});await work;listeners.activate({waitUntil:p=>work=p});await work;
async function request(url,mode='cors'){let response;listeners.fetch({request:{method:'GET',url,mode},respondWith:p=>response=p});return response?await (await response).text():null}
assert((await request('https://example.test/','navigate')).includes('index.html'));assert((await request('https://example.test/app.mjs?v=10')).includes('app.mjs'));assert((await request('https://example.test/routes.mjs?v=10')).includes('optional'));assert.equal(network,0);
assert.equal(await request('https://example.test/unrelated.json'),null);assert.equal(await request('https://other.test/app.mjs?v=10'),null);
items.delete('https://example.test/diary.mjs?v=10');assert.equal(await request('https://example.test/diary.mjs?v=10'),'network');assert.equal(network,1);assert.equal(await request('https://example.test/diary.mjs?v=10'),'network');assert.equal(network,1);
console.log('Cache: immediate cached shell, assets, routes; unknown URLs untouched; cache miss filled.');
