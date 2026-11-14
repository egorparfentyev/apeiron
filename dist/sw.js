const CACHE='apeiron-v12';
const CORE=['./index.html','./style.css?v=12','./app.mjs?v=12','./diary.mjs?v=12','./migrations.mjs?v=12','./seed.mjs?v=12','./icon.svg?v=12','./icon-192.png?v=12','./icon-512.png?v=12','./manifest.webmanifest?v=12'];
const OPTIONAL=['./routes.mjs?v=12','./research.mjs?v=12'];
const URLS=new Set([...CORE,...OPTIONAL].map(p=>new URL(p,self.registration.scope).href));
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE))));
self.addEventListener('activate',event=>event.waitUntil((async()=>{await self.clients.claim();const cache=await caches.open(CACHE);await Promise.allSettled(OPTIONAL.map(p=>cache.add(p)));})()));
async function openPage(request) {
  let timeout;
  try {
    const response = await Promise.race([
      fetch(request),
      new Promise(resolve => {timeout = setTimeout(resolve, 1800)}),
    ]);
    if (response?.ok) return response;
  } catch {
    // The same release is precached for offline use.
  } finally {
    clearTimeout(timeout);
  }
  const cached = await (await caches.open(CACHE)).match('./index.html');
  return cached || Response.error();
}

self.addEventListener('fetch',event=>{
 const request=event.request;if(request.method!=='GET'||new URL(request.url).origin!==location.origin)return;
 if(request.mode==='navigate'){
  event.respondWith(openPage(request));return;
 }
 if(!URLS.has(request.url))return;
 event.respondWith((async()=>{const cache=await caches.open(CACHE),hit=await cache.match(request);if(hit)return hit;const response=await fetch(request);if(response.ok)await cache.put(request,response.clone());return response})());
});
