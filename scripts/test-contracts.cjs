// Host-side contract checks. Device APIs are not exercised by this runner.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const deveco = process.env.DEVECO_HOME || 'D:/DevEco/DevEco Studio';
const ts = require(path.join(deveco, 'tools/hvigor/hvigor/node_modules/typescript'));
function load(file, dependencies = {}) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } });
  const exports = {};
  vm.runInNewContext(compiled.outputText, { exports, require: (name) => {
    assert.ok(dependencies[name], `Unexpected import ${name}`);
    return dependencies[name];
  }, console, Date, JSON, Error });
  return exports;
}
async function main() {
  const { ExpiryService } = load('entry/src/main/ets/algorithm/ExpiryService.ets');
  const service = new ExpiryService();
  const fixtures = JSON.parse(fs.readFileSync(path.join(root, 'algorithm/contracts/expiry-test-cases.json')));
  for (const test of fixtures) {
    const actual = service.evaluate(test.expiryDate, test.openedDate, test.afterOpenValue, test.afterOpenUnit, test.reminderDays, test.today);
    assert.equal(actual.effectiveExpiryDate, test.expectedEffectiveExpiryDate ?? undefined, test.id);
    assert.equal(actual.remainingDays, test.expectedRemainingDays ?? undefined, test.id);
    assert.equal(actual.status, test.expectedStatus, test.id);
  }
  assert.equal(service.deriveExpiryDate('2024-01-31', 1, 'MONTH'), '2024-02-29');
  assert.equal(service.deriveExpiryDate('2024-02-29', 1, 'YEAR'), '2025-02-28');
  const {DEFAULT_ATTENTION_RULES}=load('entry/src/main/ets/algorithm/AttentionRules.ets');
  assert.equal(JSON.stringify(DEFAULT_ATTENTION_RULES),JSON.stringify(JSON.parse(fs.readFileSync(path.join(root,'algorithm/contracts/attention-rules.json'),'utf8'))));
  const serverContract = path.resolve(root, '../lovestorage/openapi/smart-expiry-v1.yaml');
  if (fs.existsSync(serverContract)) {
    assert.equal(fs.readFileSync(serverContract, 'utf8'), fs.readFileSync(path.join(root, 'contract/smart-expiry-v1.yaml'), 'utf8'));
    assert.deepEqual(fixtures, JSON.parse(fs.readFileSync(path.resolve(root, '../lovestorage/algorithm/contracts/expiry-test-cases.json'))));
    for(const name of ['recognition-test-cases.json','attention-rules.json','attention-test-cases.json'])
      assert.equal(fs.readFileSync(path.resolve(root,'../lovestorage/algorithm/contracts',name),'utf8'),fs.readFileSync(path.join(root,'algorithm/contracts',name),'utf8'));
  }
  console.log(`PASS: ${fixtures.length} expiry fixtures, 2 calendar boundaries, contract snapshot equality`);
  const url = process.argv[2];
  if (!url) return;
  // Adapt the native HTTP transport to fetch; run the actual ArkTS ApiClient against the real server.
  const http = {
    RequestMethod: { GET: 'GET', POST: 'POST', PUT: 'PUT', DELETE: 'DELETE' },
    createHttp: () => ({ destroy() {}, async request(url, options) {
      const result = await fetch(url, { method: options.method, headers: options.header,
        body: options.extraData || undefined, signal: AbortSignal.timeout(15000) });
      return { responseCode: result.status, result: await result.text() };
    } })
  };
  const { ApiClient } = load('entry/src/main/ets/data/remote/ApiClient.ets', {
    '@kit.NetworkKit': { http }, '../../algorithm/ExpiryService': { ExpiryService }
  });
  ApiClient.baseUrl = url;
  await ApiClient.health();
  const session = await ApiClient.authenticate('smoke_' + randomUUID().replaceAll('-', '').slice(0, 16), 'smoke-test-password-123', true);
  ApiClient.token = session.accessToken;
  const id = randomUUID();
  const item = { id, name: 'Contract smoke', categoryId: 'food', expiryDate: '2026-10-09', lifecycleStatus: 'ACTIVE', createdAt: Date.now(), updatedAt: Date.now() };
  try {
    await ApiClient.upload(item, id);
    await ApiClient.upload(item, id);
    item.name = 'Updated contract smoke'; item.lifecycleStatus = 'CONSUMED';
    item.quantity = 3; item.unit = 'box';
    item.openedDate = '2026-10-01'; item.afterOpenValue = 2; item.afterOpenUnit = 'DAY';
    await ApiClient.upload(item, id);
    const detail = JSON.parse(await ApiClient.request(`/items/${id}`, 'GET')).data;
    assert.equal(detail.name, item.name); assert.equal(detail.lifecycleStatus, 'CONSUMED');
    assert.ok(detail.expiryStatus);
    assert.equal(detail.quantity, 3); assert.equal(detail.unit, 'box');
    assert.equal(detail.expiryDate, '2026-10-03');
  } finally {
    item.deletedAt = Date.now();
    await ApiClient.upload(item, id);
    await ApiClient.upload(item, id);
  }
  await assert.rejects(() => ApiClient.request(`/items/${id}`, 'GET'));
  const snapshot = JSON.stringify({ schemaVersion: 1, items: [item], records: [], shopping: [] });
  assert.equal((await ApiClient.backup(snapshot, 0)).revision, 1);
  await assert.rejects(() => ApiClient.backup(snapshot, 0));
  assert.equal((await ApiClient.fetchBackup()).payload, snapshot);
  const draft = JSON.parse(await ApiClient.request('/recognition/text', 'POST', {text:'名称：牛奶\n生产日期：2026年10月03日\n保质期：30天'})).data;
  assert.equal(draft.production, '2026-10-03'); assert.equal(draft.requiresConfirmation, true);
  const syncId = randomUUID();
  const inventory = { item: { name: 'Multi-batch smoke', categoryId: 'food', lifecycleStatus: 'ACTIVE' },
    batches: [2, 3].map(quantity => ({ id: randomUUID(), quantity, unit: 'box', expiryDate: '2027-01-01', lifecycleStatus: 'ACTIVE' })) };
  const payload = JSON.stringify(inventory);
  const first = await ApiClient.syncPut(syncId, { payload });
  assert.equal((await ApiClient.syncPut(syncId, { payload })).version, first.version);
  const saved = JSON.parse((await ApiClient.syncGet(syncId)).payload);
  assert.equal(saved.item.name, inventory.item.name);
  assert.equal(saved.batches.length, 2);
  assert.equal(saved.batches.reduce((sum, batch) => sum + batch.quantity, 0), 5);
  assert.deepEqual(saved.batches.map(batch => batch.id).sort(), inventory.batches.map(batch => batch.id).sort());
  assert.ok((await ApiClient.syncList()).some(value => value.itemId === syncId || value.id === syncId));
  inventory.item.name = 'Updated multi-batch smoke';
  const changed = JSON.stringify(inventory);
  await assert.rejects(() => ApiClient.syncPut(syncId, { payload: changed }));
  const next = await ApiClient.syncPut(syncId, { payload: changed, expectedVersion: first.version });
  assert.ok(next.version > first.version);
  await assert.rejects(() => ApiClient.syncPut(syncId, { payload, expectedVersion: first.version }));
  const event = { eventId: randomUUID(), eventType: 'DECISION_SHOWN', eventVersion: '1.0', occurredAt: new Date().toISOString(),
    properties: { itemId: syncId, decisionId: randomUUID(), algorithmVersion: 'attention-rule-v1', score: 90, mock: true, reasonCodes: ['EXPIRES_TODAY'] } };
  await ApiClient.sendEvents([event]);
  await ApiClient.sendEvents([event]);
  let pending = -1;
  for (let attempt = 0; attempt < 40; attempt++) {
    pending = JSON.parse(await ApiClient.request('/events/status', 'GET')).data.pending;
    if (pending === 0) break;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  assert.equal(pending, 0, 'event outbox should drain');
  const exported = JSON.parse(await ApiClient.request('/events/export?limit=1000', 'GET')).data.events;
  const matching = exported.filter(value => value.eventId === event.eventId);
  assert.equal(matching.length, 1, 'event retries must deduplicate');
  assert.equal(matching[0].properties.mock, true);
  await ApiClient.logout();
  await assert.rejects(() => ApiClient.request('/auth/me', 'GET'));
  console.log('PASS: actual ApiClient auth, CRUD/retries, backup, recognition, multi-batch sync/conflicts, event export/deduplication and logout');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
