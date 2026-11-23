const CACHE='apeiron-v27';
const CORE=['./reminders.mjs?v=27','./progress.mjs?v=24','./phrases.mjs?v=21','./index.html','./style.css?v=24','./app.mjs?v=27','./diary.mjs?v=23','./migrations.mjs?v=18','./history.mjs?v=18','./seed.mjs?v=24','./icon.svg?v=14','./apple-touch-icon.png','./icon-192.png?v=14','./icon-512.png?v=14','./manifest.webmanifest?v=26'];
const OPTIONAL=['./push.mjs?v=27','./push-config.mjs','./routes.mjs?v=23','./english-plan.mjs','./research.mjs?v=14'];
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

self.addEventListener('push',event=>{
  let kind;
  try { kind=event.data?.json()?.kind; } catch {}
  const evening=kind==='evening';
  event.waitUntil(self.registration.showNotification(evening?'Проверить дела дня':'Составить план дня',{
    body:evening?'Откройте Кайрос, отметьте выполненное и проверьте, что осталось.':'Откройте Кайрос и запишите дела на сегодня.',
    icon:'./icon-192.png?v=14',tag:'kairos-'+(evening?'evening':'morning')
  }));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const home=new URL('./',self.registration.scope).href;
    const client=windows.find(item=>item.url.startsWith(home));
    if(client){await client.focus();client.postMessage({type:'open-today'});}
    else await self.clients.openWindow(home);
  })());
});
