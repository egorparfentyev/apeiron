// Keep the original localStorage key so earlier installations open their history.
export const historyKey = 'vector.web.v1';
const databaseName = 'apeiron-history';
const arrays = ['goals', 'tasks', 'habits', 'logs', 'events', 'reflections'];

export function isHistory(value) {
  return value?.version === 1 && arrays.every(name => Array.isArray(value[name]));
}

export function newestHistory(primary, backup) {
  if (!isHistory(primary)) return isHistory(backup) ? backup : null;
  if (isHistory(backup) && (backup.savedAt || 0) > (primary.savedAt || 0)) return backup;
  return primary;
}

export function mergeHistory(current, backup) {
  const result = {...current};
  if (backup.quantumOlympiadPlan) result.quantumOlympiadPlan = true;
  for (const key of [...arrays, 'archivedGoals']) {
    const identify = item => item.id || JSON.stringify([item.habitID, item.day]);
    const entries = new Map((result[key] || []).map(item => [identify(item), item]));
    for (const item of backup[key] || []) {
      const id = identify(item);
      if (!entries.has(id)) entries.set(id, item);
      else if (key === 'goals' || key === 'archivedGoals') {
        const goal = entries.get(id);
        const milestones = new Map((goal.milestones || []).map(step => [step.id, step]));
        for (const step of item.milestones || []) {
          if (!milestones.has(step.id)) milestones.set(step.id, step);
        }
        entries.set(id, {...goal, milestones: [...milestones.values()]});
      }
    }
    result[key] = [...entries.values()];
  }
  result.progressGoalIDs = [...new Set([...(current.progressGoalIDs || []), ...(backup.progressGoalIDs || [])])];
  result.dayLines = {...backup.dayLines, ...current.dayLines};
  result.routeProgress = {...backup.routeProgress};
  for (const [key, value] of Object.entries(current.routeProgress || {})) {
    result.routeProgress[key] = {...result.routeProgress[key], ...value};
  }
  return result;
}

let connection;
function openDatabase() {
  if (!connection) connection = new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('history');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('History database is blocked'));
  }).catch(error => {connection = undefined; throw error});
  return connection;
}

export async function readBackup() {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    const request = db.transaction('history').objectStore('history').get('current');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function writeBackup(state) {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction('history', 'readwrite');
    const store = transaction.objectStore('history');
    const previous = store.get('current');
    previous.onsuccess = () => {
      if ((previous.result?.savedAt || 0) <= (state.savedAt || 0)) store.put(state, 'current');
    };
    transaction.oncomplete = resolve;
    transaction.onabort = () => reject(transaction.error);
  });
}
