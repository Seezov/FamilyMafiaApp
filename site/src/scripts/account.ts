// The /account/ page: sign-in, claiming a player, nick + avatar settings.
import { signIn, signOutUser } from '../lib/firebase';
import { cancelClaim, explainAccountError, getClaim, listProfiles, onAccount, saveProfile, submitClaim, type AccountUser } from '../lib/account/store';
import { accountView, pickList, takenKeys, type Claim, type Profile } from '../lib/account/state';
import { cropRect, encodeAvatar } from '../lib/account/avatar';
import { cleanNick, nickError, playerKey } from '../lib/profiles/core';

type P = { name: string; slug: string; games: number; seasons: number };
const page = JSON.parse(document.getElementById('account-data')!.textContent!) as { players: P[]; base: string };
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const remember = (v: { label: string; avatar?: string } | null) => {
  try { if (v) localStorage.setItem('fm-account', JSON.stringify(v)); else localStorage.removeItem('fm-account'); } catch { /* private mode */ }
};

let user: AccountUser | null = null;
let claim: Claim | null = null;
let profiles: Profile[] = [];
let mine: Profile | null = null;
let img: HTMLImageElement | null = null; // newly chosen photo, not saved yet
let avatar: string | null = null;        // what will be saved

function show() {
  const view = accountView(!!user, claim, mine);
  document.querySelectorAll<HTMLElement>('[data-view]').forEach((s) => { s.hidden = s.dataset.view !== (view === 'rejected' ? 'pick' : view); });
  $('rejected-note').hidden = view !== 'rejected';
  $('who').textContent = user?.email ?? '';
  $('sign-out').hidden = !user;
  $('admin-link').hidden = !user?.admin;
  if (view === 'pick' || view === 'rejected') renderPick();
  if (view === 'pending') $('pending-player').textContent = claim!.player;
  if (view === 'settings') renderSettings();
}

function renderPick() {
  const rows = pickList(page.players, takenKeys(profiles), $<HTMLInputElement>('pick-q').value);
  $('pick-list').innerHTML = rows.map((p) => `<li><button type="button" data-name="${esc(p.name)}" ${p.taken ? 'disabled' : ''}>
    <span>${esc(p.name)}</span><span class="label">${p.taken ? 'вже привʼязаний' : `${p.games} ігор · ${p.seasons} сез.`}</span></button></li>`).join('');
}

function renderSettings() {
  const p = page.players.find((x) => playerKey(x.name) === mine!.key);
  const a = $<HTMLAnchorElement>('my-page');
  a.textContent = mine!.player;
  a.href = p ? `${page.base}players/${p.slug}/` : '#';
  $<HTMLInputElement>('nick').value = mine!.nick ?? '';
  avatar = mine!.avatar ?? null;
  img = null;
  drawPreview();
}

function drawPreview() {
  const c = $<HTMLCanvasElement>('av-preview');
  const ctx = c.getContext('2d')!;
  ctx.clearRect(0, 0, c.width, c.height);
  if (img) {
    const r = cropRect(img.width, img.height, Number($<HTMLInputElement>('av-zoom').value),
      Number($<HTMLInputElement>('av-dx').value), Number($<HTMLInputElement>('av-dy').value));
    ctx.drawImage(img, r.sx, r.sy, r.size, r.size, 0, 0, c.width, c.height);
  } else if (avatar) {
    const saved = new Image();
    saved.onload = () => ctx.drawImage(saved, 0, 0, c.width, c.height);
    saved.src = avatar;
  }
}

const msg = (text: string, kind: 'error' | 'ok' = 'ok') => { $('msg').className = kind === 'error' ? 'msg-error' : ''; $('msg').textContent = text; };

async function refresh() {
  if (!user) { claim = null; mine = null; return show(); }
  try {
    [claim, profiles] = await Promise.all([getClaim(user.uid), listProfiles()]);
    mine = claim?.status === 'approved' ? profiles.find((p) => p.key === claim!.playerKey && p.uid === user!.uid) ?? null : null;
    remember({ label: mine?.nick ?? mine?.player ?? user.name, avatar: mine?.avatar });
  } catch (e) { alertBox(explainAccountError(e)); }
  show();
}

function alertBox(text: string) { $('who').textContent = text; }

$('sign-in').addEventListener('click', () => signIn().catch((e) => alertBox(explainAccountError(e))));
$('sign-out').addEventListener('click', async () => { remember(null); await signOutUser(); });
$('pick-q').addEventListener('input', renderPick);
$('pick-list').addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-name]');
  if (!b || b.disabled || !user) return;
  if (!confirmInline(b)) return;
  try { await submitClaim(user, b.dataset.name!); await refresh(); } catch (err) { alertBox(explainAccountError(err)); }
});
// Two-tap confirm instead of window.confirm(): first tap arms, second sends.
function confirmInline(b: HTMLButtonElement) {
  if (b.dataset.armed) return true;
  document.querySelectorAll<HTMLButtonElement>('#pick-list button[data-armed]').forEach((x) => { delete x.dataset.armed; x.querySelector('.label')!.textContent = ''; });
  b.dataset.armed = '1';
  b.querySelector('.label')!.textContent = 'Натисни ще раз — «Це я»';
  return false;
}
$('cancel-claim').addEventListener('click', async () => {
  try { await cancelClaim(user!.uid); await refresh(); } catch (e) { alertBox(explainAccountError(e)); }
});
$('av-file').addEventListener('change', () => {
  const f = $<HTMLInputElement>('av-file').files?.[0];
  if (!f) return;
  const url = URL.createObjectURL(f);
  const i = new Image();
  i.onload = () => { img = i; ['av-zoom', 'av-dx', 'av-dy'].forEach((id) => { $<HTMLInputElement>(id).value = id === 'av-zoom' ? '1' : '0'; }); drawPreview(); msg(''); };
  i.onerror = () => msg('Не вдалося прочитати зображення.', 'error');
  i.src = url;
});
['av-zoom', 'av-dx', 'av-dy'].forEach((id) => $(id).addEventListener('input', drawPreview));
$('av-remove').addEventListener('click', () => { img = null; avatar = null; $<HTMLInputElement>('av-file').value = ''; drawPreview(); });
$('save').addEventListener('click', async () => {
  if (!mine) return;
  const nick = cleanNick($<HTMLInputElement>('nick').value);
  const others = [
    ...page.players.filter((p) => playerKey(p.name) !== mine!.key).map((p) => p.name),
    ...profiles.filter((p) => p.key !== mine!.key && p.nick).map((p) => p.nick!),
  ];
  const err = nickError(nick, mine.player, others);
  if (err) return msg(err, 'error');
  try {
    if (img) {
      avatar = encodeAvatar(img, cropRect(img.width, img.height, Number($<HTMLInputElement>('av-zoom').value),
        Number($<HTMLInputElement>('av-dx').value), Number($<HTMLInputElement>('av-dy').value)));
    }
  } catch { return msg('Зображення завелике навіть після стиснення — обери інше.', 'error'); }
  $<HTMLButtonElement>('save').disabled = true;
  try {
    await saveProfile(mine.key, { nick: nick.toLowerCase() === mine.player.toLowerCase() ? '' : nick, avatar });
    mine = { ...mine, nick: nick || undefined, avatar: avatar ?? undefined };
    img = null;
    remember({ label: mine.nick ?? mine.player, avatar: mine.avatar });
    msg('Збережено. На сайті зʼявиться протягом години.');
  } catch (e) { msg(explainAccountError(e), 'error'); } finally { $<HTMLButtonElement>('save').disabled = false; }
});

onAccount((u) => { user = u; refresh(); });
