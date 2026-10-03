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
  const { ExpiryService } = load('entry/src/main/ets/domain/ExpiryService.ets');
  const service = new ExpiryService();
  const fixtures = JSON.parse(fs.readFileSync(path.join(root, 'contract/expiry-test-cases.json')));
  for (const test of fixtures) {
    const actual = service.evaluate(test.expiryDate, test.openedDate, test.afterOpenValue, test.afterOpenUnit, test.reminderDays, test.today);
    assert.equal(actual.effectiveExpiryDate, test.expectedEffectiveExpiryDate ?? undefined, test.id);
    assert.equal(actual.remainingDays, test.expectedRemainingDays ?? undefined, test.id);
    assert.equal(actual.status, test.expectedStatus, test.id);
  }
  assert.equal(service.deriveExpiryDate('2024-01-31', 1, 'MONTH'), '2024-02-29');
  assert.equal(service.deriveExpiryDate('2024-02-29', 1, 'YEAR'), '2025-02-28');
  const serverContract = path.resolve(root, '../lovestorage/openapi/smart-expiry-v1.yaml');
  if (fs.existsSync(serverContract)) {
    assert.equal(fs.readFileSync(serverContract, 'utf8'), fs.readFileSync(path.join(root, 'contract/smart-expiry-v1.yaml'), 'utf8'));
    assert.deepEqual(fixtures, JSON.parse(fs.readFileSync(path.resolve(root, '../lovestorage/shared/expiry-test-cases.json'))));
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
    '@kit.NetworkKit': { http }, '../../domain/ExpiryService': { ExpiryService }
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
  await ApiClient.logout();
  await assert.rejects(() => ApiClient.request('/auth/me', 'GET'));
  console.log('PASS: actual ApiClient auth, CRUD/retries, snapshot/read/conflict, recognition and logout');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
