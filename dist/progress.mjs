function weekHTML(tasks, today) {
  const days = Array.from({length:7}, (_, index) => {
    const day = new Date(today + 'T12:00:00Z');
    day.setUTCDate(day.getUTCDate() - 6 + index);
    return {day, key:day.toISOString().slice(0,10), done:0, total:0};
  });
  const byDate = new Map(days.map(item => [item.key,item]));
  for (const task of tasks) {
    const item = byDate.get(task.day);
    if (!item) continue;
    item.total++;
    if (task.mark === 'Сделано') item.done++;
  }
  const done = days.reduce((sum,item)=>sum+item.done,0);
  const total = days.reduce((sum,item)=>sum+item.total,0);
  return `<section class="card weekly"><h2>Последние 7 дней</h2>
    <p class="small muted">Выполнено по датам плана · ${done} из ${total}</p>
    <div class="week-chart">${days.map(({day,key,done,total})=>{
      const label = day.toLocaleDateString('ru',{day:'numeric',month:'long',timeZone:'UTC'});
      return `<button data-progress-day="${key}" aria-label="${label}, выполнено ${done} из ${total}. Открыть дела">
        <span>${day.toLocaleDateString('ru',{weekday:'short',timeZone:'UTC'})}</span>
        <i><b style="height:${total?100*done/total:0}%"></b></i><small>${done}/${total}</small></button>`;
    }).join('')}</div></section>`;
}
export function progressHTML(state,today,esc) {
  const tracked = state.goals.filter(goal=>state.progressGoalIDs?.includes(goal.id));
  let content=`<div class="heading"><h1>Прогресс</h1><button id="track-goal" class="primary">＋ Цель</button></div>
  ${weekHTML(state.tasks,today)}
  <div class="stats">
  <div class="card stat"><span class="eyebrow">Дела</span><strong>${state.tasks.filter(task=>task.mark==='Сделано').length}</strong><p>выполнено</p></div>
  <div class="card stat"><span class="eyebrow">Этапы</span><strong>${state.goals.flatMap(goal=>goal.milestones).filter(step=>step.done).length}</strong><p>достигнуто</p></div>
  <div class="card stat"><span class="eyebrow">Привычки</span><strong>${state.logs.filter(log=>log.mark==='Сделано').length}</strong><p>повторений</p></div>
  </div>
  <section class="progress-goals" aria-label="Отслеживаемые цели">${tracked.map(goal=>{
    const completed = goal.milestones.filter(step=>step.done).length;
    const total = goal.milestones.length;
    const tasksDone = state.tasks.filter(task=>task.goalID===goal.id&&task.mark==='Сделано').length;
    return `<article class="card tracked-goal">
      <div class="card-head"><h2>${esc(goal.title)}</h2><button class="text-btn" data-untrack="${esc(goal.id)}">Скрыть</button></div>
      <p class="small muted">${completed} из ${total} этапов · ${tasksDone} связанных дел выполнено</p>
      ${total?`<progress value="${completed}" max="${total}" aria-label="Выполненные этапы"></progress>`:''}
      <div class="goal-steps">${goal.milestones.map(step=>`<label class="step"><input type="checkbox" data-goal="${esc(goal.id)}" data-step="${esc(step.id)}" ${step.done?'checked':''}>${esc(step.title)}</label>`).join('')}</div>
      <button class="text-btn" data-goaledit="${esc(goal.id)}">Изменить этапы</button>
    </article>`;
  }).join('')||'<p class="card muted">Добавьте цель, чтобы видеть её этапы здесь.</p>'}</section>`;
  const byArea = new Map();
  for (const task of state.tasks) {
    if (task.mark !== 'Сделано') continue;
    const area = task.area || 'Личное';
    byArea.set(area, (byArea.get(area)||0)+1);
  }
  if(byArea.size)content+=`<section class="card area-progress"><h2>Дела по направлениям</h2>${[...byArea].sort((a,b)=>b[1]-a[1]).map(([area,count])=>`<div class="area-stat"><div class="row"><span>${esc(area)}</span><strong>${count}</strong></div></div>`).join('')}</section>`;

  return content;
}
