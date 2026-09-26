export const pendingKey = 'duofold.pending.v1';
export const completedKey = 'duofold.completed.v1';

export function newSession(cryptoProvider = globalThis.crypto) {
  return Array.from(cryptoProvider.getRandomValues(new Uint8Array(6)), byte => byte.toString(16).padStart(2, '0')).join('');
}

export function cleanURL(href) {
  const url = new URL(href);
  for (const key of [...url.searchParams.keys()]) {
    if (key === 'session' || key === 'result' || key.startsWith('df_')) url.searchParams.delete(key);
  }
  url.hash = '';
  return url;
}

export function appURL(session, callback) {
  if (!/^[a-zA-Z0-9]{12}$/.test(session)) throw new Error('Invalid session');
  const url = new URL(callback);
  if (url.protocol !== 'https:' || url.username || url.password) throw new Error('HTTPS callback required');
  const link = new URL('duofold://verify');
  link.searchParams.set('session', session);
  link.searchParams.set('callback', url.href);
  return link.href;
}

export function returnedSession(href, pending) {
  const url = new URL(href);
  return Boolean(pending && /^[a-zA-Z0-9]{12}$/.test(pending.session)
    && url.searchParams.getAll('session').length === 1
    && url.searchParams.getAll('result').length === 1
    && url.searchParams.get('session') === pending.session
    && url.searchParams.get('result') === 'success');
}

export function timings(href, pending, returnedAt) {
  const params = new URL(href).searchParams;
  const read = key => {
    const raw = params.get('df_' + key);
    const value = raw === null ? NaN : Number(raw);
    return Number.isFinite(value) ? value : null;
  };
  const received = read('app_received_ms');
  const sent = read('return_sent_ms');
  return {
    launch_ms: received === null ? null : received - pending.startedAt,
    challenge_ms: read('challenge_ms'),
    validation_ms: read('validation_ms'),
    browser_return_ms: sent === null ? null : returnedAt - sent,
    round_trip_ms: returnedAt - pending.startedAt
  };
}
