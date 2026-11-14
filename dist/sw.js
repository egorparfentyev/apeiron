const CACHE='apeiron-v10';
const CORE=['./index.html','./style.css?v=10','./app.mjs?v=10','./diary.mjs?v=10','./migrations.mjs?v=10','./seed.mjs?v=10','./icon.svg?v=10','./icon-192.png?v=10','./icon-512.png?v=10','./manifest.webmanifest?v=10'];
const OPTIONAL=['./routes.mjs?v=10','./research.mjs?v=10'];
const URLS=new Set([...CORE,...OPTIONAL].map(p=>new URL(p,self.registration.scope).href));
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE))));
self.addEventListener('activate',event=>event.waitUntil((async()=>{await self.clients.claim();const cache=await caches.open(CACHE);await Promise.allSettled(OPTIONAL.map(p=>cache.add(p)));})()));
self.addEventListener('fetch',event=>{
 const request=event.request;if(request.method!=='GET'||new URL(request.url).origin!==location.origin)return;
 if(request.mode==='navigate'){
  // Cached shell opens immediately; newer releases are installed atomically by the browser.
  event.respondWith((async()=>{const cache=await caches.open(CACHE);return await cache.match('./index.html')||fetch(request)})());return;
 }
 if(!URLS.has(request.url))return;
 event.respondWith((async()=>{const cache=await caches.open(CACHE),hit=await cache.match(request);if(hit)return hit;const response=await fetch(request);if(response.ok)await cache.put(request,response.clone());return response})());
});
