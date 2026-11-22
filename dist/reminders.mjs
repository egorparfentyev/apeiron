const keys = ['morning', 'evening'];
const prefix = 'apeiron.reminder.';
const dateKey = d => [d.getFullYear(), String(d.getMonth()+1).padStart(2,'0'), String(d.getDate()).padStart(2,'0')].join('-');

export function reminderFor(now, tasks, preferences, dismissed) {
  const hour = now.getHours(), date = dateKey(now);
  const kind = hour >= 21 ? 'evening' : hour >= 9 ? 'morning' : null;
  if (!kind || !preferences[kind] || dismissed[kind] === date) return null;
  if (kind === 'morning') return {kind, date, text:'Какую привычку попробуете сегодня? Запишите первое действие в план дня.'};
  const count = tasks.filter(task => task.day === date && task.mark !== 'Сделано').length;
  return count ? {kind, date, text:'Незавершённых дел в плане дня: ' + count + '. Откройте список, чтобы закончить их.'} : null;
}

export const reminderSettings = '<section class="card"><h2>Напоминания</h2><p class="small muted">Появляются при открытом ежедневнике или при возвращении в приложение.</p><label class="step"><input type="checkbox" data-reminder="morning">09:00 · Новая привычка</label><label class="step"><input type="checkbox" data-reminder="evening">21:00 · Незавершённые дела дня</label></section>';

export function refreshReminders(tasks, openDay) {
  const preferences = {}, dismissed = {};
  try {
    for (const kind of keys) {
      preferences[kind] = localStorage.getItem(prefix+kind) === 'on';
      dismissed[kind] = localStorage.getItem(prefix+kind+'.dismissed');
    }
  } catch { return; }
  document.querySelectorAll('[data-reminder]').forEach(input => {
    const kind = input.dataset.reminder;
    input.checked = preferences[kind];
    input.onchange = () => {
      try { localStorage.setItem(prefix+kind,input.checked?'on':'off'); }
      catch { input.checked = preferences[kind]; alert('Не удалось сохранить настройку напоминания.'); }
      refreshReminders(tasks,openDay);
    };
  });
  const host = document.getElementById('reminder-banner');
  if (!host) return;
  const item = reminderFor(new Date(),tasks,preferences,dismissed);
  if (!item) { host.replaceChildren(); return; }
  if (host.querySelector('p')?.textContent === item.text && host.dataset.date === item.date) return;
  host.dataset.date = item.date;
  host.innerHTML = '<section class="card"><p></p><button class="text-btn" data-open>Открыть план дня</button><button class="text-btn" data-dismiss>Скрыть</button></section>';
  host.querySelector('p').textContent = item.text;
  const dismiss = () => {
    localStorage.setItem(prefix+item.kind+'.dismissed',item.date);
    host.replaceChildren();
  };
  host.querySelector('[data-dismiss]').onclick = dismiss;
  host.querySelector('[data-open]').onclick = () => { dismiss(); openDay(); };
}
