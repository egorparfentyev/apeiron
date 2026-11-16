const CACHE='apeiron-v18';
const CORE=['./index.html','./style.css?v=14','./app.mjs?v=18','./diary.mjs?v=14','./migrations.mjs?v=17','./history.mjs?v=17','./seed.mjs?v=14','./icon.svg?v=14','./apple-touch-icon.png','./icon-192.png?v=14','./icon-512.png?v=14','./manifest.webmanifest?v=15'];
const OPTIONAL=['./routes.mjs?v=18','./english-plan.mjs','./research.mjs?v=14'];
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
