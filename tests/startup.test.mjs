import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
function graph(file,read,seen=new Set()){if(seen.has(file))return [];seen.add(file);const code=read(file);return [{file,bytes:Buffer.byteLength(code)},...[...code.matchAll(/^import .*? from ['"]\.\/(.*?)(?:\?[^'"]*)?['"]/gm)].flatMap(m=>graph(m[1],read,seen))]}
const current=graph('app.mjs',f=>readFileSync(new URL('../dist/'+f,import.meta.url),'utf8'));
assert(!current.some(x=>['routes.mjs','research.mjs','seed.mjs'].includes(x.file)));
const bytes=current.reduce((sum,module)=>sum+module.bytes,0);
assert(bytes<40_000, `Startup JavaScript exceeded 40 kB: ${bytes} bytes`);
console.log(JSON.stringify({initialJavaScriptBytes:bytes,initialModules:current.map(x=>x.file)}));
