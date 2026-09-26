import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import * as session from './session.mjs';

const source = (await readFile(new URL('./app.js', import.meta.url), 'utf8')).replace(/^import .*;\n/, '');
function storage() {
  const values = new Map();
  return { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value), removeItem: key => values.delete(key) };
}
function browser(href = 'https://example.com/demo/', local = storage(), tab = storage()) {
  const elements = new Map();
  for (const id of ['title', 'description', 'verify', 'open-app', 'status']) {
    elements.set('#' + id, { hidden: id === 'open-app', textContent: '', addEventListener(event, callback) { this[event] = callback; } });
  }
  const location = { href, protocol: new URL(href).protocol };
  const handlers = {};
  const context = vm.createContext({ ...session, URL, Date, JSON, console: { table() {} },
    localStorage: local, sessionStorage: tab, location,
    history: { replaceState(_state, _title, url) { location.href = String(url); } },
    document: { querySelector: selector => elements.get(selector) },
    window: { addEventListener: (event, callback) => { handlers[event] = callback; } }
  });
  vm.runInContext(source, context);
  return { elements, location, handlers, local, tab };
}

test('Verify launches app and keeps a usable manual fallback', () => {
  const page = browser();
  page.elements.get('#verify').click();
  const pending = JSON.parse(page.local.getItem(session.pendingKey));
  assert.match(pending.session, /^[a-f0-9]{12}$/);
  assert.match(page.location.href, /^duofold:\/\/verify/);
  assert.equal(page.elements.get('#open-app').hidden, false);
  assert.equal(page.elements.get('#open-app').href, page.location.href);
});
test('matching new-tab return becomes Verified, consumes pending, survives reload', () => {
  const original = browser();
  original.elements.get('#verify').click();
  const pending = JSON.parse(original.local.getItem(session.pendingKey));
  const callback = `https://example.com/demo/?session=${pending.session}&result=success`;
  const returned = browser(callback, original.local);
  assert.equal(returned.elements.get('#title').textContent, 'Verified ✓');
  assert.equal(returned.local.getItem(session.pendingKey), null);
  assert.equal(returned.location.href, 'https://example.com/demo/');
  returned.handlers.pageshow();
  assert.equal(returned.elements.get('#title').textContent, 'Verified ✓');
  const reloaded = browser(returned.location.href, returned.local, returned.tab);
  assert.equal(reloaded.elements.get('#title').textContent, 'Verified ✓');
  const replay = browser(callback, returned.local);
  assert.notEqual(replay.elements.get('#title').textContent, 'Verified ✓');
});
test('mismatched callback never verifies or consumes the real pending session', () => {
  const original = browser();
  original.elements.get('#verify').click();
  const pending = original.local.getItem(session.pendingKey);
  const returned = browser('https://example.com/demo/?session=BAD000000000&result=success', original.local);
  assert.notEqual(returned.elements.get('#title').textContent, 'Verified ✓');
  assert.equal(returned.local.getItem(session.pendingKey), pending);
});
test('HTTP and unavailable browser storage fail visibly before app launch', () => {
  const http = browser('http://localhost/');
  http.elements.get('#verify').click();
  assert.match(http.elements.get('#status').textContent, /HTTPS/);
  assert.equal(http.location.href, 'http://localhost/');
  const blocked = { getItem() { throw Error('blocked'); }, setItem() { throw Error('blocked'); } };
  const page = browser('https://example.com/demo/', blocked);
  page.elements.get('#verify').click();
  assert.match(page.elements.get('#status').textContent, /storage/);
  assert.equal(page.location.href, 'https://example.com/demo/');
});
