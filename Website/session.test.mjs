import test from 'node:test';
import assert from 'node:assert/strict';
import { newSession, cleanURL, appURL, returnedSession, timings } from './session.mjs';

test('random local sessions have the agreed shape', () => {
  const values = new Set(Array.from({ length: 1000 }, () => newSession()));
  assert.equal(values.size, 1000);
  for (const value of values) assert.match(value, /^[a-f0-9]{12}$/);
});
test('deep link round trips encoded HTTPS callback', () => {
  const callback = 'https://example.com/demo/?source=one%26two';
  const link = new URL(appURL('ABC123abc456', callback));
  assert.equal(link.searchParams.get('callback'), callback);
  assert.equal(link.searchParams.get('session'), 'ABC123abc456');
});
test('invalid callbacks and sessions cannot launch', () => {
  for (const callback of ['http://example.com', 'javascript:alert(1)', 'https://user:pass@example.com']) {
    assert.throws(() => appURL('ABC123abc456', callback));
  }
  assert.throws(() => appURL('invalid', 'https://example.com'));
});
test('matching pending session required, including new-tab use and consumed replay', () => {
  const pending = JSON.parse(JSON.stringify({ session: 'ABC123abc456', startedAt: 1000 }));
  const url = 'https://example.com/?session=ABC123abc456&result=success';
  assert.equal(returnedSession(url, pending), true);
  assert.equal(returnedSession(url, null), false);
  assert.equal(returnedSession(url, { session: '000000000000' }), false);
  assert.equal(returnedSession(url + '&session=ABC123abc456', pending), false);
  assert.equal(returnedSession(url.replace('success', 'failure'), pending), false);
});
test('URL cleanup preserves unrelated query values', () => {
  assert.equal(cleanURL('https://example.com/?source=demo&result=success&session=x&df_validation_ms=2#x').href,
    'https://example.com/?source=demo');
});
test('phase measurements stay separate', () => {
  assert.deepEqual(timings('https://example.com/?df_app_received_ms=1200&df_challenge_ms=900&df_validation_ms=1&df_return_sent_ms=2500',
    { startedAt: 1000 }, 2700), { launch_ms: 200, challenge_ms: 900, validation_ms: 1, browser_return_ms: 200, round_trip_ms: 1700 });
});
