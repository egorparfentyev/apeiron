import {historyKey as key, isHistory, newestHistory, mergeHistory, readBackup, writeBackup} from './history.mjs?v=18';
import {migrateGoals, addQuantumOlympiadPlan, linkQuantumOlympiadGoal} from './migrations.mjs?v=18';
import {diaryHTML,bindDiary,resetDiaryView} from './diary.mjs?v=23';
let routeModule=null,routeLoading=false,routeError=false;
function loadRoutes(){if(routeLoading||routeModule)return;routeLoading=true;routeError=false;import('./routes.mjs?v=23').then(m=>{routeModule=m;routeLoading=false;if(page==='Помощник')render()}).catch(()=>{routeLoading=false;routeError=true;if(page==='Помощник')render()})}
const $=s=>document.querySelector(s), esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])), day=(d=new Date())=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
let state, primary, locked = false;
try {
  const saved = localStorage.getItem(key);
  if (saved !== null) {
    primary = JSON.parse(saved);
    locked = !isHistory(primary);
  }
} catch {locked = true}
state = newestHistory(primary, await readBackup().catch(() => null));
const hasSavedHistory = Boolean(state);
if (state) locked = false;
else {
  const {seed} = await import('./seed.mjs?v=24');
  state = structuredClone(seed);
}
const migratedGoals = migrateGoals(state);
const addedPlan = !locked && addQuantumOlympiadPlan(state, day());
const linkedGoal = !locked && linkQuantumOlympiadGoal(state);
const migrated = migratedGoals || addedPlan || linkedGoal;
if (addedPlan || linkedGoal) state.savedAt = Math.max(Date.now(), (state.savedAt || 0) + 1);
let savedState = structuredClone(state);
let backupStatus = '';
if (hasSavedHistory || addedPlan || linkedGoal) {
  if (state !== primary || migrated) {
    try { localStorage.setItem(key, JSON.stringify(state)); } catch {}
  }
  syncBackup(savedState);
}
let page=['#english2027','#quantum'].includes(location.hash)?'Помощник':'Сегодня',date=day(),horizon='Полгода';
function showBackupStatus() {
  const label = $('#backup-status');
  if (label) label.textContent = backupStatus;
}
function syncBackup(snapshot) {
  writeBackup(snapshot).then(() => {
    if (snapshot !== savedState) return;
    backupStatus = 'Резервная копия на устройстве обновлена.';
    showBackupStatus();
  }).catch(() => {
    if (snapshot !== savedState) return;
    backupStatus = 'Резервное хранение недоступно. Скачайте копию в «Файлы».';
    showBackupStatus();
  });
}
let routeTrack=location.hash==='#quantum'?'quantum':location.hash==='#english2027'?'english2027':'startup',routeIndex=0;const nextMonday=new Date();nextMonday.setDate(nextMonday.getDate()+((8-nextMonday.getDay())%7));let routeStart=day(nextMonday);
const pages=['Сегодня','Цели','Помощник','Календарь','Прогресс','Настройки'];


function save(){
  if(locked){alert('Не удалось прочитать историю. Добавьте резервную копию в настройках.');return false}
  try {
    state.savedAt = Math.max(Date.now(), (savedState.savedAt || 0) + 1);
    const snapshot = structuredClone(state);
    localStorage.setItem(key, JSON.stringify(snapshot));
    savedState = snapshot;
  } catch {
    state = structuredClone(savedState);
    render();
    alert('Не удалось сохранить изменение. Скачайте резервную копию в настройках.');
    return false;
  }
  syncBackup(savedState);
  render();
  return true;
}
function modal(title,body,submit){$('#editor').innerHTML=`<div class="dialog-head"><h2>${title}</h2><button id="close">✕</button></div><form class="dialog-body">${body}<button class="primary">Сохранить</button></form>`;$('#close').onclick=()=>$('#editor').close();$('#editor form').onsubmit=e=>{e.preventDefault();submit(new FormData(e.target));$('#editor').close();save()};$('#editor').showModal()}
const field=(name,label,value='',type='text')=>`<label>${label}<input required name="${name}" type="${type}" value="${esc(value)}"></label>`;
function feedback(text){const el=$('#toast');el.textContent=text;el.classList.add('visible');setTimeout(()=>el.classList.remove('visible'),2600)}
let progressModule;
function render(){let content='';
if(page==='Сегодня' && !state.dayLines?.[date]){
  const selectedDate=date;
  import('./phrases.mjs?v=21').then(({dailyPhrase})=>{
    const quote=document.getElementById('daily-phrase');
    if(quote?.dataset.date===selectedDate && !state.dayLines?.[selectedDate])
      quote.textContent='«'+dailyPhrase(selectedDate)+'»';
  }).catch(()=>{});
}
if(page==='Сегодня')content=diaryHTML(state,date)+`<details class="diary-extra"><summary>Вечерняя заметка</summary><section class="card"><textarea id="journal" aria-label="Заметка дня" rows="4" placeholder="Заметка дня">${esc(state.reflections.find(r=>r.day===date)?.text||'')}</textarea><button class="text-btn" id="save-note">Сохранить заметку</button></section></details>`;
if(page==='Цели')content=`<div class="heading"><div><h1>Ваши цели</h1><p>Редактируйте формулировки и этапы под свою работу</p></div><button id="new-goal" class="primary">＋ Цель</button></div><div class="tabs">${['Полгода','Год','5–10 лет'].map(h=>`<button data-horizon="${h}" class="${h===horizon?'active':''}">${h}</button>`).join('')}</div><div class="grid">${state.goals.filter(g=>g.horizon===horizon).map(g=>`<div class="card goal-card"><span class="badge">${esc(g.area)}</span><h3>${esc(g.title)}</h3><p>${esc(g.why)}</p><div class="goal-steps">${g.milestones.map(m=>`<label class="step"><input type="checkbox" data-goal="${g.id}" data-step="${m.id}" ${m.done?'checked':''}>${esc(m.title)}</label>`).join('')}</div><button class="primary" data-plan-goal="${g.id}">${g.route?'Открыть маршрут →':'Запланировать этап →'}</button><button class="text-btn" data-goaledit="${g.id}">Изменить цель</button></div>`).join('')}</div>`;
if(page==='Цели'){content+=`<section class="card" style="margin-top:24px"><h2>Текущая работа в лаборатории</h2><p>Вы уже работаете в лаборатории. Поиск другой лаборатории убран. В маршруте «GaAs · GPE» — открытая GPE, ловушки, пороговые графики и различение режимов генерации. Параметры образца и тип накачки уточняются с руководителем.</p></section>${state.archivedGoals?.length?`<details class="card" style="margin-top:20px"><summary>Прежние шаблоны и их история (${state.archivedGoals.length})</summary><p>Сохранены для справки. Ваши дела и отметки не удалены.</p>${state.archivedGoals.map(g=>`<h3>${esc(g.title)}</h3><ul>${g.milestones.map(m=>`<li>${m.done?'✓ ':''}${esc(m.title)}</li>`).join('')}</ul>`).join('')}</details>`:''}`;}
if(page==='Календарь')content=`<div class="heading"><div><h1>События и программы</h1><p>Фотоника, исследования и новые знакомства</p></div></div><p class="notice">Источники проверены 28.10.2026. Перед подачей проверьте актуальные условия. Программы без даты не имеют подтверждённого нового набора.</p><div class="grid events-grid">${state.events.map(e=>`<article class="card event-card"><span class="badge">${esc(e.kind)}</span><h3 style="margin:16px 0">${esc(e.title)}</h3><p class="small">${esc(e.timing)}</p><p class="small muted" style="margin:12px 0">${esc(e.eligibility)}</p><a href="${esc(e.url)}" target="_blank" rel="noopener">Официальный источник ↗</a></article>`).join('')}</div>`;
if(page==='Прогресс'){
  if(progressModule) content=progressModule.progressHTML(state,day(),esc);
  else {
    content='<section class="card" role="status">Загрузка прогресса…</section>';
    import('./progress.mjs?v=24').then(module=>{
      progressModule=module;
      if(page==='Прогресс') render();
    }).catch(()=>{ if(page==='Прогресс') feedback('Откройте раздел ещё раз при подключении к сети'); });
  }
}

if(page==='Настройки')content=`<div class="heading"><div><h1>Настройки</h1><p>Установка и резервные копии</p></div></div><div class="settings-grid"><section class="card install-guide"><h2>Установить на iPhone</h2><ol><li>Откройте эту ссылку в Safari.</li><li>Нажмите «Поделиться».</li><li>Выберите «На экран Домой» и «Добавить».</li></ol><p>Первое открытие требует интернета. Данные хранятся в этом браузере на устройстве; очищение данных сайта удалит историю. Регулярно сохраняйте копию.</p><p id="offline-state">Проверка офлайн-доступа…</p></section><section class="card"><h2>Ваши данные</h2><button class="primary" id="export">Скачать резервную копию</button><label>Добавить данные из копии<input id="import" type="file" accept="application/json"></label><p>Импорт добавляет записи из файла и сохраняет текущие. Копию можно сохранить в «Файлы» или iCloud Drive.</p><button class="text-btn" id="protect-history">Защитить данные на устройстве</button><p id="backup-status" class="small muted" role="status"></p></section></div>`;

if(page==='Помощник'){if(routeModule)content=routeModule.routeHTML(state,routeTrack,routeIndex,routeStart);else{content=routeError?'<section class="card"><h2>Раздел недоступен</h2><p>При первом открытии маршрутов нужен интернет.</p><button id="retry-routes" class="primary">Повторить</button></section>':'<section class="card" role="status">Загрузка маршрутов…</section>';if(!routeError)loadRoutes()}}

$('#app').innerHTML=`<div class="shell"><aside class="sidebar"><a class="brand" href="#"><img src="./icon.svg?v=14" alt="">Апейрон</a><nav>${pages.map(p=>`<button class="navbtn ${page===p?'active':''}" data-page="${p}">${p==='Сегодня'?'Ежедневник':p==='Помощник'?'Маршруты':p}</button>`).join('')}</nav><div class="side-note">МФТИ · 3-й курс<strong>Исследования<br>и проекты</strong>GaAs · GPE · ML</div></aside><main class="workspace"><header class="topbar"><span class="breadcrumb">APEIRON / ${page==='Сегодня'?'Ежедневник':page==='Помощник'?'Маршруты':page}</span><a class="brand only-mobile" href="#"><img src="./icon.svg?v=14" alt="">Апейрон</a><div class="top-actions"><span class="small muted">${new Date().toLocaleDateString('ru',{day:'numeric',month:'long'})}</span></div></header>${locked?'<p class="notice warning">Ошибка чтения истории. Восстановите резервную копию в настройках.</p>':''}${content}</main></div><nav class="mobile-nav" aria-label="Разделы">${pages.map((p,i)=>`<button data-page="${p}" ${page===p?'aria-current="page"':''} class="${page===p?'active':''}" aria-label="${['Ежедневник','Цели','Маршруты','Календарь','Прогресс','Настройки'][i]}">${['Дела','Цели','Планы','Даты','Итоги','Ещё'][i]}</button>`).join('')}</nav>`;

document.querySelectorAll('[data-progress-day]').forEach(button=>button.onclick=()=>{
  resetDiaryView(); date=button.dataset.progressDay; page='Сегодня'; render(); scrollTo(0,0);
});
if($('#open-coach'))$('#open-coach').onclick=()=>{page='Помощник';render();scrollTo(0,0)};
if($('#retry-routes'))$('#retry-routes').onclick=()=>{loadRoutes();render()};
if(page==='Помощник'&&routeModule)routeModule.bindRoutes({state,track:routeTrack,index:routeIndex,start:routeStart,change:(t,i,d)=>{routeTrack=t;routeIndex=i;routeStart=d;render()},save,feedback,openDiary:d=>{resetDiaryView();date=d;page='Сегодня';render();scrollTo(0,0)},openGoals:()=>{page='Цели';render()}});
document.querySelectorAll('[data-plan-goal]').forEach(b=>b.onclick=()=>{const g=state.goals.find(g=>g.id===b.dataset.planGoal);if(g.route){routeTrack=g.route;routeIndex=0;page='Помощник';render();scrollTo(0,0)}else{const step=g.milestones.find(m=>!m.done);if(!step){feedback('Добавьте конкретный этап в редакторе цели.');return}modal('Дело из вашей цели',field('title','Конкретное действие',step.title)+field('date','День',day(),'date')+field('result','Как проверите результат?',step.title),f=>state.tasks.push({id:crypto.randomUUID(),title:f.get('title'),day:f.get('date'),note:f.get('result'),goalID:g.id,area:g.area,mark:'В плане',minutes:0}))}});
function createGoal(track=false){
  const horizons = ['Полгода','Год','5–10 лет'];
  modal('Новая цель',field('title','Название')+`<label>Почему это важно<textarea name="why" rows="2"></textarea></label><label>Срок<select name="horizon">${horizons.map(value=>`<option ${value===horizon?'selected':''}>${value}</option>`).join('')}</select></label>`+field('step','Первый этап'),form=>{
    const goal={id:crypto.randomUUID(),title:form.get('title').trim(),why:form.get('why').trim(),area:'Личное',horizon:form.get('horizon'),milestones:[{id:crypto.randomUUID(),title:form.get('step').trim(),done:false}]};
    if(!goal.title||!goal.milestones[0].title)return;
    state.goals.push(goal);
    if(track)(state.progressGoalIDs ||= []).push(goal.id);
    else horizon=goal.horizon;
  });
}
if($('#new-goal'))$('#new-goal').onclick=()=>createGoal();
if($('#track-goal'))$('#track-goal').onclick=()=>{
  const available=state.goals.filter(goal=>!state.progressGoalIDs?.includes(goal.id));
  if(!available.length){createGoal(true);return}
  modal('Добавить в прогресс',`<label>Цель<select name="goal" required>${available.map(goal=>`<option value="${esc(goal.id)}">${esc(goal.title)}</option>`).join('')}</select></label><button type="button" id="create-tracked" class="text-btn">Создать новую цель</button>`,form=>{
    (state.progressGoalIDs ||= []).push(form.get('goal'));
  });
  $('#create-tracked').onclick=()=>{$('#editor').close();createGoal(true)};
};
document.querySelectorAll('[data-untrack]').forEach(button=>button.onclick=()=>{
  state.progressGoalIDs=state.progressGoalIDs.filter(id=>id!==button.dataset.untrack);
  save();
});
if($('#edit-day-line'))$('#edit-day-line').onclick=()=>modal('Строка дня',
  `<label>Текст<textarea name="line" maxlength="280" rows="3">${esc(state.dayLines?.[date]||'')}</textarea></label><p class="small muted">Пустое поле уберёт строку с этой даты.</p>`,form=>{
    const value=form.get('line').trim();
    state.dayLines ||= {};
    if(value)state.dayLines[date]=value;
    else delete state.dayLines[date];
  });

document.querySelectorAll('[data-move]').forEach(b=>b.onclick=()=>{const t=state.tasks.find(t=>t.id===b.dataset.move);const next=new Date(date+'T12:00');next.setDate(next.getDate()+1);t.day=day(next);t.mark='В плане';if(save())feedback('Перенесено на '+next.toLocaleDateString('ru'))});

if(page==='Сегодня')bindDiary({state,date,setDate:d=>{date=d;render()},today:day,save,feedback});
document.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>{page=b.dataset.page;render();scrollTo(0,0)});document.querySelectorAll('[data-horizon]').forEach(b=>b.onclick=()=>{horizon=b.dataset.horizon;render()});
if($('#journal')){$('#journal').oninput=e=>{sessionStorage.setItem('kontur-draft-'+date,e.target.value)};$('#journal').value=sessionStorage.getItem('kontur-draft-'+date)??$('#journal').value;$('#save-note').onclick=()=>{state.reflections=state.reflections.filter(r=>r.day!==date);state.reflections.push({day:date,text:$('#journal').value});if(save()){sessionStorage.removeItem('kontur-draft-'+date);feedback('Заметка сохранена')}}}
document.querySelectorAll('[data-check]').forEach(b=>b.onclick=()=>{let t=state.tasks.find(t=>t.id===b.dataset.check);t.mark=t.mark==='Сделано'?'В плане':'Сделано';if(save())feedback(t.mark==='Сделано'?'Отмечено: выполнено':'Задача возвращена в план')});document.querySelectorAll('[data-remove]').forEach(b=>b.onclick=()=>{if(confirm('Удалить дело?')){state.tasks=state.tasks.filter(t=>t.id!==b.dataset.remove);save()}});document.querySelectorAll('[data-edit]').forEach(b=>b.onclick=()=>{let t=state.tasks.find(t=>t.id===b.dataset.edit);modal('Редактировать дело',field('title','Дело',t.title)+`<label>Результат<select name="mark">${['В плане','Сделано','Не сделал'].map(m=>`<option ${m===t.mark?'selected':''}>${m}</option>`).join('')}</select></label>`,f=>{t.title=f.get('title');t.mark=date>day()?'В плане':f.get('mark')})});document.querySelectorAll('[data-step]').forEach(b=>b.onchange=()=>{state.goals.find(g=>g.id===b.dataset.goal).milestones.find(m=>m.id===b.dataset.step).done=b.checked;save()});document.querySelectorAll('[data-goaledit]').forEach(b=>b.onclick=()=>{let g=state.goals.find(g=>g.id===b.dataset.goaledit);modal('Ваша цель',field('title','Название',g.title)+`<label>Почему важно<textarea name="why" rows="2">${esc(g.why)}</textarea></label>`+g.milestones.map((m,i)=>field('milestone-'+i,'Этап '+(i+1),m.title)).join('')+`<label>Добавить этапы (по одному на строке)<textarea name="extra" rows="3"></textarea></label>`,f=>{g.title=f.get('title').trim();g.why=f.get('why').trim();g.milestones.forEach((m,i)=>m.title=f.get('milestone-'+i).trim());String(f.get('extra')).split('\n').map(t=>t.trim()).filter(Boolean).forEach(title=>g.milestones.push({id:crypto.randomUUID(),title,done:false}))})});
if($('#export')){
  showBackupStatus();
  $('#export').onclick=()=>{
    const url=URL.createObjectURL(new Blob([JSON.stringify(state,null,2)],{type:'application/json'}));
    const link=document.createElement('a');
    link.href=url;
    link.download='Apeiron-'+day()+'.json';
    link.click();
    setTimeout(()=>URL.revokeObjectURL(url),1000);
  };
  $('#import').onchange=async event=>{
    const file=event.target.files[0];
    event.target.value='';
    if(!file)return;
    try{
      const backup=JSON.parse(await file.text());
      if(!isHistory(backup))throw new Error('Invalid backup');
      migrateGoals(backup);
      const wasLocked=locked;
      state=wasLocked?backup:mergeHistory(state,backup);
      locked=false;
      addQuantumOlympiadPlan(state, day());
      linkQuantumOlympiadGoal(state);
      if(save())feedback('Данные из копии добавлены');
      else if(wasLocked){locked=true;render()}
    }catch{alert('Файл не подходит. Текущие данные сохранены.')}
  };
  $('#protect-history').onclick=async()=>{
    let granted=false;
    try{granted=await navigator.storage?.persist?.()}catch{}
    feedback(granted?'Постоянное хранение разрешено':'Браузер не разрешил постоянное хранение. Скачайте копию.');
  };
  navigator.serviceWorker?.ready.then(()=>{if($('#offline-state'))$('#offline-state').textContent='Приложение подготовлено для работы без интернета.'});
}
}
render();performance.mark('apeiron-ready');
if('serviceWorker'in navigator){const register=()=>navigator.serviceWorker.register('./sw.js',{updateViaCache:'none'}).catch(()=>{});if(document.readyState==='complete')setTimeout(register,0);else window.addEventListener('load',register,{once:true})}
