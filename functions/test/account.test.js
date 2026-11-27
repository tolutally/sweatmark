const {test} = require('node:test');
const assert = require('node:assert/strict');
const {deleteAccountData, requireRecentSignIn, OWNED_COLLECTIONS, RECENT_SIGN_IN_SECONDS} = require('../lib/account');
const endpoints = require('../lib/index');

function fakeDeps() {
  const calls = [];
  const record = name => async (...args) => { calls.push([name, ...args]); };
  return {
    calls,
    deps: {
      deleteUserTree: record('tree'),
      deleteOwned: record('owned'),
      deleteDoc: record('doc'),
      deleteFiles: record('files'),
      deleteAuthUser: record('auth'),
    },
  };
}

test('deleting an account removes data first and the sign-in last', async () => {
  const {calls, deps} = fakeDeps();
  await deleteAccountData('user-1', deps);
  assert.deepEqual(calls[0], ['tree', 'user-1']);
  for (const collection of OWNED_COLLECTIONS) {
    assert.ok(calls.some(c => c[0] === 'owned' && c[1] === collection && c[2] === 'user-1'));
  }
  assert.ok(calls.some(c => c[0] === 'doc' && /^_aiQuotas\/[0-9a-f]{64}$/.test(c[1])));
  assert.ok(calls.some(c => c[0] === 'files' && c[1] === 'users/user-1/'));
  assert.deepEqual(calls.at(-1), ['auth', 'user-1']);
});

test('a failed data delete keeps the sign-in so the person can retry', async () => {
  const {calls, deps} = fakeDeps();
  deps.deleteFiles = async () => { throw new Error('storage down'); };
  await assert.rejects(deleteAccountData('user-1', deps), /storage down/);
  assert.ok(!calls.some(c => c[0] === 'auth'));
});

test('deleting needs a recent, non-anonymous sign-in', () => {
  const now = 1_800_000_000_000;
  const request = (authTime, provider = 'apple.com') => ({
    auth: {uid: 'user-1', token: {auth_time: authTime, firebase: {sign_in_provider: provider}}},
  });
  assert.equal(requireRecentSignIn(request(now / 1000 - 60), now).uid, 'user-1');
  assert.throws(() => requireRecentSignIn(request(now / 1000 - RECENT_SIGN_IN_SECONDS - 1), now),
    e => e.code === 'failed-precondition');
  assert.throws(() => requireRecentSignIn(request(now / 1000, 'anonymous'), now),
    e => e.code === 'unauthenticated');
  assert.throws(() => requireRecentSignIn({}, now), e => e.code === 'unauthenticated');
});

test('deleteAccount is exported as a callable', () => {
  assert.equal(typeof endpoints.deleteAccount, 'function');
});
