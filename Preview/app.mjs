import { APP_CATALOG, searchCatalog, emptyState, used, reconcile, grant, end, changeSelection, decode } from './engine.mjs';
const $ = id => document.getElementById(id);
const KEY = 'seuil-preview-v1';
let state;
let storageAvailable = true;
try { state = decode(localStorage.getItem(KEY)); }
catch { state = emptyState(); storageAvailable = false; }
let selected = state.protected[0];
let clockOffset = 0;
let recognition = null;
let renderedApps = '';
const now = () => Date.now() + clockOffset;
const symbols = Object.fromEntries(APP_CATALOG.map(app => [app.name, app.mark]));
let draftSelection = new Set();

function notify(message, type = 'info') {
  $('result').textContent = message;
  $('result').dataset.type = type;
  $('result').hidden = false;
}
function persist(next) {
  try { localStorage.setItem(KEY, JSON.stringify(next)); state = next; storageAvailable = true; return true; }
  catch { storageAvailable = false; notify('Sauvegarde indisponible. La session n’a pas été ouverte. Autorise le stockage local puis réessaie.', 'error'); return false; }
}
function render() {
  const reconciled = reconcile(state, now());
  if (state.session && !reconciled.session) {
    state = reconciled;
    persist(state);
    notify('Le temps est écoulé. L’app est à nouveau protégée dans cette démo. Reviens à ce qui compte.');
  }
  $('home').hidden = !!state.session;
  $('session').hidden = !state.session;
  if (!state.protected.includes(selected)) selected = state.protected[0];
  const appsKey = JSON.stringify([state.protected, selected]);
  if (appsKey !== renderedApps) {
  renderedApps = appsKey;
  $('apps').replaceChildren();
  for (const app of state.protected) {
    const button = document.createElement('button');
    button.type = 'button'; button.className = 'app-option'; button.setAttribute('aria-pressed', String(selected === app));
    button.setAttribute('aria-label', `Choisir ${app}`);
    const icon = document.createElement('span'); icon.className = 'app-icon'; icon.textContent = symbols[app]; icon.setAttribute('aria-hidden', 'true');
    const text = document.createElement('span'); text.textContent = app;
    const dot = document.createElement('span'); dot.className = 'selection-dot'; dot.setAttribute('aria-hidden', 'true');
    button.append(icon, text, dot);
    button.onclick = () => {
      selected = app; render();
      [...$('apps').querySelectorAll('button')].find(item => item.getAttribute('aria-label') === `Choisir ${app}`)?.focus();
    };
    $('apps').append(button);
  }
  if (!state.protected.length) {
    const empty = document.createElement('p'); empty.className = 'helper'; empty.textContent = 'Ajoute une app avec « Modifier » pour commencer.'; $('apps').append(empty);
  }
  }
  $('submit').disabled = !selected || !$('intention').value.trim() || $('intention').value.length > 600;
  const spent = used(state, now());
  $('budget-label').textContent = `${spent} / 45 min`;
  $('budget-bar').style.width = `${Math.min(100, spent / 45 * 100)}%`;
  $('characters').textContent = `${$('intention').value.length} / 600`;
  if (state.session) {
    const seconds = Math.max(0, Math.ceil((state.session.expiresAt - now()) / 1000));
    $('timer').textContent = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
    $('session-app').textContent = `${state.session.app} · accès simulé pendant 15 minutes`;
  }
}
$('intention').addEventListener('input', render);
document.querySelectorAll('[data-example]').forEach(button => button.addEventListener('click', () => {
  $('intention').value = button.dataset.example; $('intention').focus(); render();
}));
$('intent-form').addEventListener('submit', event => {
  event.preventDefault();
  if (!$('intention').value.trim() || $('intention').value.length > 600) return;
  const result = grant(state, selected, $('intention').value, now());
  if (result.decision === 'allow') {
    if (persist(result.state)) { $('intention').value = ''; notify('Intention validée. 15 minutes réservées, à toi de garder le cap.'); }
  } else {
    const messages = {
      deny: 'Une envie de scroller, ça arrive. Pour cette fois, garde cet espace pour toi. L’app reste protégée dans la démo.',
      clarify: 'Un peu plus précis ? Indique ce que tu veux apprendre et sur quel sujet. Essaie « Je veux comprendre comment connecter Supabase à mon app ».',
      budget: 'Tes 45 minutes sur les dernières 24 h sont réservées. Fais une pause ; le budget se libérera progressivement.',
      active: 'Une session est déjà en cours. Termine-la avant d’en commencer une autre.',
      selection: 'Choisis une app protégée pour continuer.'
    };
    notify(messages[result.decision], result.decision === 'deny' ? 'deny' : 'info');
  }
  render();
});
$('end-session').onclick = () => {
  if (persist(end(state))) notify('C’est fait. L’app est à nouveau protégée dans la démo. Les 15 minutes restent réservées.');
  render();
};
$('expire-session').onclick = () => {
  // This explicit demo control advances the test clock; it never changes iPhone settings.
  if (state.session) { clockOffset = state.session.expiresAt - Date.now() + 1000; render(); }
};
function updateSelectionCount() {
  const count = draftSelection.size;
  $('selection-count').textContent = `${count} app${count === 1 ? '' : 's'} sélectionnée${count === 1 ? '' : 's'}`;
}
function renderCatalog() {
  $('choices').replaceChildren();
  const matches = searchCatalog($('app-search').value);
  let category = '';
  for (const app of matches) {
    if (app.category !== category) {
      category = app.category;
      const heading = document.createElement('h3'); heading.textContent = category;
      $('choices').append(heading);
    }
    const label = document.createElement('label');
    const input = document.createElement('input'); input.type = 'checkbox'; input.value = app.name; input.checked = draftSelection.has(app.name);
    input.onchange = () => {
      if (input.checked) draftSelection.add(app.name); else draftSelection.delete(app.name);
      updateSelectionCount();
    };
    const icon = document.createElement('span'); icon.className = 'catalog-icon'; icon.textContent = app.mark; icon.setAttribute('aria-hidden', 'true');
    label.append(icon, document.createTextNode(app.name), input); $('choices').append(label);
  }
  if (!matches.length) {
    const empty = document.createElement('p'); empty.className = 'helper';
    empty.textContent = 'Aucun exemple correspondant. Essaie un autre nom. Sur iPhone, la liste vient directement du sélecteur Apple.';
    $('choices').append(empty);
  }
  updateSelectionCount();
}
$('manage').onclick = () => {
  draftSelection = new Set(state.protected);
  $('app-search').value = '';
  renderCatalog();
  $('settings').showModal();
  $('app-search').focus();
};
$('app-search').addEventListener('input', renderCatalog);
$('close-settings').onclick = () => $('settings').close();
$('save-settings').onclick = event => {
  event.preventDefault();
  try {
    const apps = [...draftSelection];
    if (persist(changeSelection(state, apps))) { $('settings').close(); notify('Tes apps protégées ont été mises à jour dans la démo.'); render(); }
  } catch (error) { notify(error.message, 'error'); }
};
$('reset').onclick = () => {
  recognition?.abort();
  clockOffset = 0;
  if (persist(emptyState())) {
    selected = state.protected[0]; $('intention').value = ''; $('voice-status').textContent = '';
    notify('La démo est réinitialisée. Aucune app réelle n’a été modifiée.');
  }
  render();
};
$('dictate').onclick = () => {
  const Speech = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!Speech) { $('voice-status').textContent = 'Utilise le micro du clavier sur iPhone, ou écris ton intention. La dictée du navigateur n’est pas disponible ici.'; return; }
  if (recognition) { recognition.stop(); return; }
  recognition = new Speech(); recognition.lang = 'fr-FR'; recognition.interimResults = false;
  $('voice-status').textContent = 'Écoute en cours. La dictée peut utiliser le service vocal de ton navigateur. Relis avant de valider.';
  recognition.onresult = event => { $('intention').value = event.results[0][0].transcript.slice(0, 600); render(); };
  recognition.onerror = () => { $('voice-status').textContent = 'La dictée n’a pas abouti. Tu peux saisir ton intention au clavier.'; };
  recognition.onend = () => { recognition = null; if ($('voice-status').textContent.startsWith('Écoute')) $('voice-status').textContent = 'Relis ton intention puis valide-la quand tu es prêt.'; };
  try { recognition.start(); } catch { recognition = null; $('voice-status').textContent = 'Micro indisponible. La saisie au clavier reste disponible.'; }
};
window.addEventListener('storage', event => {
  if (event.key !== KEY) return;
  try { state = decode(event.newValue); render(); } catch { notify('Une sauvegarde invalide a été détectée. Réinitialise la démo.', 'error'); }
});
window.addEventListener('pagehide', () => recognition?.abort());
render();
if (!storageAvailable) notify('Sauvegarde inaccessible ou invalide. Réinitialise la démo pour repartir proprement.', 'error');
setInterval(render, 1000);
