import assert from 'node:assert/strict';
import {mergeHistory, newestHistory} from '../dist/history.mjs';

const base={version:1,goals:[],tasks:[],habits:[],logs:[],events:[],reflections:[]};
const current={...base,savedAt:200,tasks:[{id:'current',mark:'Сделано'}],progressGoalIDs:['a'],routeProgress:{english:{done:true}}};
const backup={...base,savedAt:100,tasks:[{id:'old',mark:'В плане'},{id:'current',mark:'В плане'}],progressGoalIDs:['b'],routeProgress:{research:{done:true}}};
assert.equal(newestHistory(null,current),current);
assert.equal(newestHistory(current,backup),current);
assert.equal(newestHistory(backup,current),current);
const merged=mergeHistory(current,backup);
assert.deepEqual(merged.tasks,[{id:'current',mark:'Сделано'},{id:'old',mark:'В плане'}]);
assert.deepEqual(merged.progressGoalIDs,['a','b']);
assert.deepEqual(merged.routeProgress,{english:{done:true},research:{done:true}});
assert.deepEqual(current.tasks,[{id:'current',mark:'Сделано'}]);
