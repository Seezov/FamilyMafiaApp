// /account/admin/: approve or reject player claims; reset or unlink profiles. Rules re-check everything.
import { signIn } from '../lib/firebase';
import { decideClaim, explainAccountError, listClaims, listProfiles, onAccount, resetProfile, unlink, type AccountUser } from '../lib/account/store';
import { sortClaims, takenKeys, type Claim, type Profile } from '../lib/account/state';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const STATUS = { pending: 'чекає', approved: 'схвалено', rejected: 'відхилено' } as const;
let user: AccountUser | null = null;
let claims: Claim[] = [];
let profiles: Profile[] = [];

async function load() {
  try { [claims, profiles] = await Promise.all([listClaims(), listProfiles()]); render(); }
  catch (e) { $('who').textContent = explainAccountError(e); }
}

function render() {
  const taken = takenKeys(profiles);
  $('claims').innerHTML = sortClaims(claims).map((c) => {
    const busy = c.status !== 'approved' && taken.has(c.playerKey);
    return `<div class="box item"><span class="grow"><b>${esc(c.player)}</b> ← ${esc(c.googleName)} &lt;${esc(c.email)}&gt;
      <span class="label">${c.createdAt ? new Date(c.createdAt).toLocaleDateString('uk-UA') : ''}</span></span>
      <span class="st-${c.status}">${STATUS[c.status]}</span>
      ${c.status === 'pending' ? `<button class="btn sm primary" data-act="approve" data-uid="${esc(c.uid)}" ${busy ? 'disabled title="вже привʼязаний"' : ''}>${busy ? 'вже привʼязаний' : 'Схвалити'}</button>
      <button class="btn sm" data-act="reject" data-uid="${esc(c.uid)}">Відхилити</button>` : ''}</div>`;
  }).join('') || '<p class="label">Заявок немає.</p>';
  $('profiles').innerHTML = profiles.map((p) => `<div class="box item">
      ${p.avatar ? `<img src="${esc(p.avatar)}" alt="" />` : ''}
      <span class="grow"><b>${esc(p.player)}</b>${p.nick ? ` → ${esc(p.nick)}` : ''}</span>
      ${p.nick ? `<button class="btn sm" data-act="reset-nick" data-key="${esc(p.key)}">Скинути нік</button>` : ''}
      ${p.avatar ? `<button class="btn sm" data-act="reset-avatar" data-key="${esc(p.key)}">Скинути аватарку</button>` : ''}
      <button class="btn sm" data-act="unlink" data-key="${esc(p.key)}">Відвʼязати</button></div>`).join('')
    || '<p class="label">Профілів ще немає.</p>';
}

document.addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-act]');
  if (!b || !user) return;
  // Destructive actions arm on the first tap and run on the second.
  if (b.dataset.act === 'unlink' && !b.dataset.armed) { b.dataset.armed = '1'; b.textContent = 'Точно відвʼязати?'; return; }
  b.disabled = true;
  try {
    const c = claims.find((x) => x.uid === b.dataset.uid);
    const p = profiles.find((x) => x.key === b.dataset.key);
    if (b.dataset.act === 'approve' && c) await decideClaim(c, true, user.email);
    if (b.dataset.act === 'reject' && c) await decideClaim(c, false, user.email);
    if (b.dataset.act === 'reset-nick' && p) await resetProfile(p.key, 'nick');
    if (b.dataset.act === 'reset-avatar' && p) await resetProfile(p.key, 'avatar');
    if (b.dataset.act === 'unlink' && p) await unlink(p);
    await load();
  } catch (err) {
    $('who').textContent = explainAccountError(err);
    b.disabled = false;
  }
});

$('sign-in').addEventListener('click', () => signIn().catch((e) => { $('gate-text').textContent = explainAccountError(e); }));
onAccount((u) => {
  user = u;
  $('who').textContent = u?.email ?? '';
  $('gate').hidden = !!u?.admin;
  $('admin').hidden = !u?.admin;
  if (u && !u.admin) { $('gate-text').textContent = 'Немає доступу.'; $('sign-in').hidden = true; }
  if (u?.admin) load();
});
