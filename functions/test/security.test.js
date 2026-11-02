const {test} = require('node:test');
const assert = require('node:assert/strict');
const security = require('../lib/security');
const endpoints = require('../lib/index');
const user = {uid: 'test-user', token: {firebase: {sign_in_provider: 'password'}}};
const code = expected => error => error.code === expected;

test('every callable rejects missing and anonymous authentication before work', async () => {
  const names = ['searchExercises', 'getExerciseById', 'downloadAllExercisesComplete',
    'triggerExerciseDownload', 'getCacheStats', 'getBodyParts', 'getEquipmentList', 'refreshGymFitImage'];
  for (const name of names) {
    for (const auth of [undefined, {uid: 'anon', token: {firebase: {sign_in_provider: 'anonymous'}}}]) {
      await assert.rejects(endpoints[name].run({data: {}, auth}), code('unauthenticated'), name);
    }
  }
});

test('ordinary signed-in users cannot call bulk download functions', async () => {
  for (const name of ['downloadAllExercisesComplete', 'triggerExerciseDownload']) {
    await assert.rejects(endpoints[name].run({data: {}, auth: user, rawRequest: {headers: {}}}), code('permission-denied'));
  }
});

test('admin verification requires a verified boolean claim and rejects revoked tokens', async () => {
  for (const header of [undefined, '', 'Basic password', 'Bearer', 'Bearer a b']) {
    await assert.rejects(security.verifyAdminHeader(header, async () => {throw Error('must not verify');}), code('unauthenticated'));
  }
  for (const admin of [undefined, false, 'true', 1]) {
    await assert.rejects(security.verifyAdminHeader('Bearer test', async () => ({...user.token, admin})), code('permission-denied'));
  }
  await assert.rejects(security.verifyAdminHeader('Bearer test', async () => {throw Error('revoked');}), code('unauthenticated'));
  await assert.rejects(security.verifyAdminHeader('Bearer test', async () => ({admin: true, firebase: {sign_in_provider: 'anonymous'}})), code('permission-denied'));
  const result = await security.verifyAdminHeader('Bearer test', async (token, revoked) => {
    assert.equal(token, 'test'); assert.equal(revoked, true);
    return {uid: 'admin-user', admin: true, firebase: {sign_in_provider: 'password'}};
  });
  assert.equal(result.uid, 'admin-user');
});

function response() {
  return Object.assign(new (require('node:events').EventEmitter)(), {statusCode: 200, headers: {}, set(k, v) {this.headers[k] = v; return this;},
    status(n) {this.statusCode = n; return this;}, json(body) {this.body = body; this.emit('finish'); return this;},
    send(body) {this.body = body; this.emit('finish'); return this;}, end() {this.emit('finish'); return this;},
    getHeader(k) {return this.headers[k];}, setHeader(k, v) {this.headers[k] = v;}});
}

test('all HTTP mutations reject GET and legacy password/API-key inputs', async () => {
  for (const name of ['adminDownloadAllExercises', 'bulkDownloadExercises', 'downloadAllExercises', 'downloadFromGymFit', 'refreshAllGymFitImages']) {
    for (const method of ['GET', 'POST']) {
      const res = response();
      await endpoints[name]({method, headers: {'x-api-key': 'old-key'}, query: {secret: 'old-secret'}, body: {secret: 'old-secret'}}, res);
      assert.equal(res.statusCode, method === 'GET' ? 405 : 401, name);
    }
  }
});

test('input bounds reject malformed data and path/URL injection', () => {
  for (const data of [null, [], 'x', {limit: 0}, {limit: 101}, {limit: 1.5}, {limit: '30'}, {limit: NaN}, {query: {}}, {query: 'a'.repeat(101)}]) {
    assert.throws(() => security.searchInput(data), code('invalid-argument'));
  }
  assert.equal(security.searchInput({}).limit, 30);
  assert.equal(security.searchInput({query: ' bench ', limit: 100}).query, 'bench');
  for (const externalId of ['', '../a', 'a/b', 'a?x=1', 'a#b', {}, 'a'.repeat(129)]) {
    assert.throws(() => security.exerciseIdInput({externalId}, 'externalId'), code('invalid-argument'));
  }
  assert.equal(security.exerciseIdInput({externalId: 'abc-123_X'}, 'externalId'), 'abc-123_X');
  assert.throws(() => security.exerciseIdInput({exerciseId: 'other_123'}, 'exerciseId', true), code('invalid-argument'));
  assert.equal(security.exerciseIdInput({exerciseId: 'gymfit_123'}, 'exerciseId', true), 'gymfit_123');
});

test('invalid authenticated requests fail before database/quota/upstream access', async () => {
  for (const [name, data] of [['searchExercises', {limit: -1}], ['getExerciseById', {externalId: '../x'}], ['refreshGymFitImage', {exerciseId: 'other_123'}]]) {
    await assert.rejects(endpoints[name].run({auth: user, data}), code('invalid-argument'));
  }
});

test('quota allows 30, rejects 31, resets after a minute and separates accounts', async () => {
  const documents = new Map();
  const fakeDb = {
    collection(name) {assert.equal(name, '_endpointQuotas'); return {doc: key => key};},
    async runTransaction(fn) {return fn({get: async key => ({data: () => documents.get(key)}), set: (key, value) => documents.set(key, value)});},
  };
  for (let i = 0; i < 30; i++) await security.consumeExerciseQuota('user-a', fakeDb, 1000);
  await assert.rejects(security.consumeExerciseQuota('user-a', fakeDb, 2000), code('resource-exhausted'));
  await security.consumeExerciseQuota('user-b', fakeDb, 2000);
  await security.consumeExerciseQuota('user-a', fakeDb, 61000);
  assert.equal(documents.size, 2);
});


test('signed-in users can still read exercise filter metadata', async () => {
  assert.ok((await endpoints.getBodyParts.run({auth: user, data: {}})).bodyParts.includes('chest'));
  assert.ok((await endpoints.getEquipmentList.run({auth: user, data: {}})).equipment.includes('barbell'));
});
