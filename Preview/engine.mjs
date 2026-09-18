export const SESSION_MS = 15 * 60 * 1000;
export const BUDGET_MINUTES = 45;
// Examples for the browser only. The iPhone app uses Apple's device-provided picker.
export const APP_CATALOG = [
  { name: 'Facebook', category: 'Réseaux sociaux', mark: 'f' },
  { name: 'Instagram', category: 'Réseaux sociaux', mark: 'ig' },
  { name: 'TikTok', category: 'Réseaux sociaux', mark: 'tk' },
  { name: 'X', category: 'Réseaux sociaux', mark: 'X' },
  { name: 'Snapchat', category: 'Réseaux sociaux', mark: 'sc' },
  { name: 'Threads', category: 'Réseaux sociaux', mark: '@' },
  { name: 'Reddit', category: 'Réseaux sociaux', mark: 'r' },
  { name: 'Pinterest', category: 'Réseaux sociaux', mark: 'p' },
  { name: 'LinkedIn', category: 'Réseaux sociaux', mark: 'in' },
  { name: 'YouTube', category: 'Vidéo et divertissement', mark: 'yt' },
  { name: 'Twitch', category: 'Vidéo et divertissement', mark: 'tw' },
  { name: 'Netflix', category: 'Vidéo et divertissement', mark: 'N' },
  { name: 'Disney+', category: 'Vidéo et divertissement', mark: 'D+' },
  { name: 'Discord', category: 'Messagerie', mark: 'dc' },
  { name: 'Messenger', category: 'Messagerie', mark: 'm' },
  { name: 'WhatsApp', category: 'Messagerie', mark: 'wa' },
  { name: 'Telegram', category: 'Messagerie', mark: 'tg' },
  { name: 'Amazon', category: 'Shopping', mark: 'a' },
  { name: 'Vinted', category: 'Shopping', mark: 'V' },
  { name: 'Temu', category: 'Shopping', mark: 'T' }
];
export const APPS = APP_CATALOG.map(app => app.name);
export const normalize = input => input.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().trim();
export function searchCatalog(query) {
  const text = normalize(query);
  return APP_CATALOG.filter(app => normalize(`${app.name} ${app.category}`).includes(text));
}

export function classify(input) {
  const text = normalize(input);
  if (text.length < 12 || text.length > 600) return { kind: 'unclear', specific: false };
  if (["scroll", "m'ennuie", "m’ennuie", 'passer le temps', 'voir ce qu', 'pour toi', 'for you'].some(s => text.includes(s))) {
    return { kind: 'scrolling', specific: false };
  }
  const words = text.split(/[^\p{L}]+/u);
  if (words.includes('pas') || words.includes('sans') || text.includes('ignore')) return { kind: 'unclear', specific: false };
  for (const prefix of ['je veux apprendre a ', 'je veux comprendre comment ', 'je veux chercher comment ']) {
    if (text.startsWith(prefix) && text.slice(prefix.length).split(' ').filter(Boolean).length >= 3) {
      return { kind: 'learning', specific: true };
    }
  }
  return { kind: 'unclear', specific: false };
}

export function emptyState() { return { version: 1, protected: ['TikTok', 'X'], receipts: [], session: null }; }
export function used(state, now) { return state.receipts.filter(r => r.startedAt > now - 86_400_000).reduce((n, r) => n + r.minutes, 0); }
export function reconcile(state, now) {
  return { ...state, session: state.session && state.session.expiresAt > now ? state.session : null };
}
export function decision(assessment, minutes, active) {
  if (active) return 'active';
  if (minutes < 0 || minutes + 15 > BUDGET_MINUTES) return 'budget';
  if (assessment.kind === 'scrolling') return 'deny';
  if (assessment.specific && ['learning', 'communication'].includes(assessment.kind)) return 'allow';
  return 'clarify';
}
export function grant(state, app, input, now) {
  const current = reconcile(state, now);
  if (!current.protected.includes(app)) return { state: current, decision: 'selection' };
  const outcome = decision(classify(input), used(current, now), !!current.session);
  if (outcome !== 'allow') return { state: current, decision: outcome };
  return {
    decision: 'allow',
    state: {
      ...current,
      receipts: [...current.receipts.filter(r => r.startedAt > now - 86_400_000), { startedAt: now, minutes: 15 }],
      session: { app, startedAt: now, expiresAt: now + SESSION_MS }
    }
  };
}
export function end(state) { return { ...state, session: null }; }
export function changeSelection(state, apps) {
  if (state.session) throw new Error('Termine la session avant de modifier les apps.');
  if (!Array.isArray(apps) || apps.some(app => !APPS.includes(app))) throw new Error('Sélection invalide.');
  return { ...state, protected: [...new Set(apps)] };
}
export function decode(raw) {
  if (raw === null) return emptyState();
  const state = JSON.parse(raw);
  if (!state || state.version !== 1 || !Array.isArray(state.protected) || state.protected.some(a => !APPS.includes(a)) ||
      !Array.isArray(state.receipts) || state.receipts.some(r => !r || !Number.isFinite(r.startedAt) || r.minutes !== 15)) {
    throw new Error('Sauvegarde de démonstration invalide.');
  }
  const s = state.session;
  if (s !== null && (!s || !state.protected.includes(s.app) || !Number.isFinite(s.startedAt) ||
      !Number.isFinite(s.expiresAt) || s.expiresAt - s.startedAt !== SESSION_MS)) throw new Error('Session sauvegardée invalide.');
  return state;
}
