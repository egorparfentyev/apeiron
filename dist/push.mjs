import {config} from './push-config.mjs';
const accountKey='kairos.push.account', activeKey='kairos.push.active';
async function json(url, options) {
  const response=await fetch(url,options);
  if(!response.ok) throw Error('Сервис уведомлений недоступен. Повторите попытку.');
  return response.json();
}
async function account() {
  const saved=localStorage.getItem(accountKey);
  let uid, token, refresh;
  if(saved){
    const data=await json('https://securetoken.googleapis.com/v1/token?key='+config.apiKey,{
      method:'POST',body:new URLSearchParams({grant_type:'refresh_token',refresh_token:saved})
    });
    uid=data.user_id;token=data.id_token;refresh=data.refresh_token;
  }else{
    const data=await json('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key='+config.apiKey,{
      method:'POST',headers:{'Content-Type':'application/json'},body:'{"returnSecureToken":true}'
    });
    uid=data.localId;token=data.idToken;refresh=data.refreshToken;
  }
  localStorage.setItem(accountKey,refresh);
  return config.database+'/devices/'+encodeURIComponent(uid)+'.json?auth='+encodeURIComponent(token);
}
export function bindPush(button,status) {
  const ios=/iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform==='MacIntel' && navigator.maxTouchPoints>1);
  if(ios && !navigator.standalone && !matchMedia('(display-mode: standalone)').matches){
    status.textContent='В Safari нажмите «Поделиться» → «На экран Домой». Откройте Кайрос с иконки, чтобы разрешить уведомления.';
    button.disabled=true;return;
  }
  if(!('PushManager' in window) || !('Notification' in window) || !navigator.serviceWorker){
    button.disabled=true;status.textContent='В этом браузере push-уведомления недоступны.';return;
  }
  const paint=()=>button.textContent=localStorage.getItem(activeKey)?'Отключить уведомления':'Включить уведомления';
  paint();
  button.onclick=async()=>{
    button.disabled=true;
    try{
      const disable=Boolean(localStorage.getItem(activeKey));
      if(!disable && await Notification.requestPermission()!=='granted') throw Error('Разрешите уведомления для Кайроса в настройках устройства.');
      const registration=await navigator.serviceWorker.ready;
      let subscription=await registration.pushManager.getSubscription();
      if(disable){
        const url=await account();await json(url,{method:'DELETE'});
        if(subscription)await subscription.unsubscribe();
        localStorage.removeItem(activeKey);status.textContent='Уведомления отключены.';
      }else{
        const raw=atob(config.publicKey.replace(/-/g,'+').replace(/_/g,'/'));
        subscription ||= await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:Uint8Array.from(raw,c=>c.charCodeAt(0))});
        const {endpoint,keys}=subscription.toJSON();
        await json(await account(),{method:'PUT',body:JSON.stringify({endpoint,keys})});
        localStorage.setItem(activeKey,'1');
        status.textContent='Устройство подключено. Утром — план дня, вечером — проверка дел.';
        await registration.showNotification('Кайрос подключён',{body:'Уведомления разрешены на этом устройстве.',tag:'kairos-confirm'});
      }
    }catch(error){status.textContent=error.message;}
    finally{paint();button.disabled=false;}
  };
}
