import test from 'node:test';
import assert from 'node:assert/strict';
import { APP_CATALOG, searchCatalog, classify, decision, emptyState, grant, used, reconcile, end, changeSelection, decode, SESSION_MS } from '../engine.mjs';
const input = 'Je veux comprendre comment connecter Supabase à mon app';
const now = 1_800_000_000_000;
test('concrete learning gets one fifteen-minute session', () => {
  const result = grant(emptyState(),'TikTok',input,now);
  assert.equal(result.decision,'allow'); assert.equal(result.state.session.expiresAt,now+SESSION_MS);
  assert.equal(result.state.session.app,'TikTok'); assert.equal(used(result.state,now),15);
});
test('scrolling cannot be disguised with learning words', () => {
  assert.equal(grant(emptyState(),'X',input+' puis scroller',now).decision,'deny');
});
test('vague input is clarified', () => assert.equal(grant(emptyState(),'X','Les nouveautés IA',now).decision,'clarify'));
test('negation is not a learning grant', () => assert.equal(classify('Je veux apprendre à ne pas travailler sur mon app').kind,'unclear'));
test('empty and oversized input cannot unlock', () => {
  assert.equal(classify('').kind,'unclear'); assert.equal(classify(input+'a'.repeat(600)).kind,'unclear');
});
test('unprotected apps cannot be granted', () => assert.equal(grant(emptyState(),'Instagram',input,now).decision,'selection'));
test('existing session cannot be extended or replaced', () => {
  const state = grant(emptyState(),'TikTok',input,now).state;
  const result = grant(state,'X',input,now+1000);
  assert.equal(result.decision,'active'); assert.deepEqual(result.state.session,state.session);
});
test('expiry is derived from clock even after being closed', () => {
  const state = grant(emptyState(),'TikTok',input,now).state;
  assert.ok(reconcile(state,now+SESSION_MS-1).session); assert.equal(reconcile(state,now+SESSION_MS).session,null);
});
test('ending early does not refund budget', () => {
  const state = end(grant(emptyState(),'X',input,now).state);
  assert.equal(state.session,null); assert.equal(used(state,now),15);
});
test('fourth session refused after three early endings', () => {
  let state = emptyState();
  for(let i=0;i<3;i++) state=end(grant(state,'TikTok',input,now+i*1000).state);
  assert.equal(grant(state,'TikTok',input,now+4000).decision,'budget');
});
test('rolling window releases old budget at boundary', () => {
  const state=end(grant(emptyState(),'X',input,now).state);
  assert.equal(used(state,now+86_400_000-1),15); assert.equal(used(state,now+86_400_000),0);
});
test('clock moving backwards does not refund a receipt', () => {
  const state=end(grant(emptyState(),'X',input,now).state); assert.equal(used(state,now-1000),15);
});
test('selection cannot be edited during a session', () => {
  const state=grant(emptyState(),'X',input,now).state;
  assert.throws(()=>changeSelection(state,[]));
});
test('selection rejects invalid app and deduplicates', () => {
  assert.throws(()=>changeSelection(emptyState(),['Unknown']));
  assert.deepEqual(changeSelection(emptyState(),['X','X']).protected,['X']);
  assert.deepEqual(changeSelection(emptyState(),[]).protected,[]);
});
test('valid state survives reload', () => {
  const state=grant(emptyState(),'TikTok',input,now).state;
  assert.deepEqual(decode(JSON.stringify(state)),state);
});
test('corrupt, unsupported, or malformed storage fails explicitly', () => {
  for (const raw of ['invalid','null','{}',JSON.stringify({...emptyState(),version:2}),JSON.stringify({...emptyState(),receipts:[{minutes:-1,startedAt:now}]}),JSON.stringify({...emptyState(),session:{app:'X',startedAt:now,expiresAt:now+1}})]) assert.throws(()=>decode(raw));
});
test('model categories cannot override deterministic budget', () => {
  assert.equal(decision({kind:'communication',specific:true},45,false),'budget');
  assert.equal(decision({kind:'unknown',specific:true},0,false),'clarify');
});
test('state transitions do not mutate previous snapshots', () => {
  const state=emptyState(); grant(state,'X',input,now); assert.deepEqual(state,emptyState());
});
test('every catalog app can be selected, granted and restored', () => {
  for (const {name} of APP_CATALOG) {
    const state=changeSelection(emptyState(),[name]);
    const result=grant(state,name,input,now);
    assert.equal(result.decision,'allow');
    assert.equal(decode(JSON.stringify(result.state)).session.app,name);
  }
});
test('search matches names, categories, accents and casing', () => {
  assert.deepEqual(searchCatalog('  FACEBOOK ').map(a=>a.name),['Facebook']);
  assert.ok(searchCatalog('reseaux').some(a=>a.name==='Instagram'));
  assert.ok(searchCatalog('vidéo').some(a=>a.name==='YouTube'));
  assert.deepEqual(searchCatalog('not-an-app'),[]);
});
test('catalog expansion preserves old saved selections and budgets', () => {
  const before=grant(emptyState(),'TikTok',input,now).state;
  assert.deepEqual(decode(JSON.stringify(before)),before);
  const updated=changeSelection(end(before),['Facebook','Instagram']);
  assert.equal(used(updated,now),15);
});
test('catalog identifiers are unique', () => {
  assert.equal(new Set(APP_CATALOG.map(app=>app.name)).size,APP_CATALOG.length);
});
