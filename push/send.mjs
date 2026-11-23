import * as webPush from 'web-push';
import {config} from '../dist/push-config.mjs';
const kind=process.argv[2];
if(!['morning','evening','check'].includes(kind))throw Error('Unknown reminder');
const secret=JSON.parse(process.env.KAIROS_PUSH);
const auth=await fetch('https://securetoken.googleapis.com/v1/token?key='+config.apiKey,{
  method:'POST',body:new URLSearchParams({grant_type:'refresh_token',refresh_token:secret.reader})
});
if(!auth.ok)throw Error('Sender authentication failed');
const {id_token:token}=await auth.json();
const url=path=>config.database+'/devices'+path+'.json?auth='+encodeURIComponent(token);
const response=await fetch(url(''));
if(!response.ok)throw Error('Device registry unavailable: '+response.status);
const devices=Object.entries(await response.json()||{});
console.log('Registered devices:',devices.length);
webPush.setVapidDetails('https://apeiron-daily.web.app/',config.publicKey,secret.vapid);
for(const [id,sub] of devices){
  if(kind==='check')continue;
  const endpoint=new URL(sub.endpoint);
  if(!['https://web.push.apple.com','https://fcm.googleapis.com','https://updates.push.services.mozilla.com'].includes(endpoint.origin) || endpoint.username || endpoint.password)continue;
  try{await webPush.sendNotification(sub,JSON.stringify({kind}),{TTL:7200,urgency:'normal',timeout:15000});}
  catch(error){
    if([404,410].includes(error.statusCode)){
      // Only remove this subscription if it has not been replaced during delivery.
      const current=await fetch(url('/'+id),{headers:{'X-Firebase-ETag':'true'}});
      if(current.ok && (await current.json())?.endpoint===sub.endpoint)
        await fetch(url('/'+id),{method:'DELETE',headers:{'if-match':current.headers.get('etag')}});
    }else{console.error('Push service status:',error.statusCode||'unavailable');process.exitCode=1;}
  }
}
