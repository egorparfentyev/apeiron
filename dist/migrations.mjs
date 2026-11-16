export function migrateGoals(state){if(state.routeMigration===2)return false;state.archivedGoals||=[];const titles=['Первый результат в фотонике','Встроиться в работу лаборатории','Английский: говорить увереннее','Технологический стартап и свобода'];state.goals=state.goals.filter(g=>{if(titles.includes(g.title)){state.archivedGoals.push(g);return false}return true});for(const [id,title,area]of [['route-startup','Стартап: от проблемы до проверенного пилота','Доход и стартапы'],['route-english','Английский: 8 недель системной разговорной практики','Английский'],['route-research','GaAs: GPE, ловушки и порог генерации','Физика и фотоника']])if(!state.goals.some(g=>g.id===id))state.goals.unshift({id,title,area,horizon:'Полгода',why:id==='route-startup'?'Проверять решения на реальных пользователях':'Говорить и понимать речь, измеряя изменения',milestones:[],route:id.slice(6)});state.routeMigration=2;return true}

export const quantumSessions = [
    [16, 30, 'Диагностика по демоверсии', 'В личном кабинете проверь своё направление, категорию и окно участия. Реши 2 задачи из демоверсии без подсказок. Запиши темы, на которых застрял. Материалы: https://yandex.ru/profi/'],
    [18, 40, 'Состояния и измерения', 'Нормируй состояние, найди вероятности и среднее наблюдаемой. Реши 2 задачи: измерение в другом базисе и последовательные измерения.'],
    [20, 45, 'Уравнение Шрёдингера и граничные условия', 'Реши по задаче на бесконечную яму и прохождение через ступеньку или барьер. Проверь сшивку решений и предельные случаи.'],
    [22, 45, 'Осциллятор и спин', 'Реши задачу на лестничные операторы и задачу на измерение спина вдоль двух осей. Выпиши по одному типичному промаху для каждой темы.'],
    [24, 40, 'Возмущения и двухуровневая система', 'Найди поправку к энергии первого порядка и реши задачу на эволюцию двухуровневой системы. Если этих тем нет в демоверсии, замени их своими слабыми темами.'],
    [26, 60, 'Пробник на время', 'Возьми задания своего направления и категории из архива. В первые 5 минут выбери порядок решения. Последние 10 минут оставь на проверку.'],
    [27, 35, 'Разбор ошибок пробника', 'Перерешай две задачи с ошибками без разбора перед глазами. Проверь размерности, знаки и нормировку.'],
    [28, 20, 'Лёгкое повторение и проверка доступа', 'Повтори формулы по памяти. Проверь вход и окно участия в разделе «Мои направления». Если отбор ещё не пройден, оставь запас времени до дедлайна своего направления.'],
  ];
export function addQuantumOlympiadPlan(state, today) {
  if (state.quantumOlympiadPlan || today > '2026-11-29') return false;
  for (const [date, minutes, title, note] of quantumSessions) {
    const id = 'quantum-olympiad-2026-' + date;
    if (!state.tasks.some(task => task.id === id)) {
      state.tasks.push({id, day:'2026-11-' + date, title:'Квантмех · ' + title, note, minutes, mark:'В плане', area:'Физика и фотоника'});
    }
  }
  state.quantumOlympiadPlan = true;
  return true;
}


export function linkQuantumOlympiadGoal(state) {
  const id = 'route-quantum';
  let changed = false;
  if (!state.goals.some(goal => goal.id === id)) {
    state.goals.unshift({
      id, title: 'Я — профессионал: подготовка по квантовой механике',
      area: 'Физика и фотоника', horizon: 'Полгода', route: 'quantum',
      why: 'До 29 ноября 2026: решить пробник и разобрать ошибки.',
      milestones: [
        {id:'quantum-diagnostic', title:'Решить две задачи из демоверсии', done:false},
        {id:'quantum-mock', title:'Решить пробник на время', done:false},
        {id:'quantum-review', title:'Перерешать две задачи с ошибками', done:false},
      ],
    });
    changed = true;
  }
  for (const task of state.tasks) {
    if (task.id?.startsWith('quantum-olympiad-2026-') && !task.goalID) {
      task.goalID = id;
      changed = true;
    }
  }
  return changed;
}
