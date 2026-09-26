import { pendingKey, completedKey, newSession, cleanURL, appURL, returnedSession, timings } from './session.mjs';

const title = document.querySelector('#title');
const description = document.querySelector('#description');
const verify = document.querySelector('#verify');
const open = document.querySelector('#open-app');
const status = document.querySelector('#status');
const page = cleanURL(location.href);
let pending;

function showVerified() {
  title.textContent = 'Verified ✓';
  description.textContent = 'A human touch. Confirmed.';
  status.textContent = 'You’re all set.';
  verify.hidden = true;
  open.hidden = true;
}

function showPending(value) {
  open.href = appURL(value.session, page);
  open.hidden = false;
  status.textContent = 'Match three folds in Duo Fold, then return here.';
}

function restore() {
  try {
    pending = JSON.parse(localStorage.getItem(pendingKey) || 'null');
    if (returnedSession(location.href, pending)) {
      const measured = timings(location.href, pending, Date.now());
      sessionStorage.setItem(completedKey, JSON.stringify({ session: pending.session, metrics: measured }));
      localStorage.removeItem(pendingKey);
      console.table(measured);
      history.replaceState(null, '', page);
      showVerified();
    } else if (new URL(location.href).searchParams.has('result')) {
      sessionStorage.removeItem(completedKey);
      history.replaceState(null, '', page);
      status.textContent = 'This return did not match your verification. Try again.';
    } else if (sessionStorage.getItem(completedKey) && !pending) {
      showVerified();
    } else if (pending) {
      showPending(pending);
    }
  } catch {
    status.textContent = 'Browser storage is unavailable or the session expired. Tap Verify to try again.';
  }
}

verify.addEventListener('click', () => {
  try {
    const session = newSession();
    const link = appURL(session, page);
    pending = { session, startedAt: Date.now() };
    localStorage.setItem(pendingKey, JSON.stringify(pending));
    sessionStorage.removeItem(completedKey);
    showPending(pending);
    location.href = link;
  } catch {
    status.textContent = location.protocol !== 'https:'
      ? 'Open this demo from an HTTPS website to verify.'
      : 'Allow browser storage to start verification.';
  }
});

// Restore after Safari returns a cached page as well as after ordinary navigation.
window.addEventListener('pageshow', restore);
restore();
