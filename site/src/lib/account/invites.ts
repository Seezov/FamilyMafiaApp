// Invites: an admin links an email to a roster player ahead of time; on that person's first
// sign-in /account/ approves the claim and creates the profile itself (firestore.rules, match /invites).
import { normalizeName } from '../hosting/form';

export interface Invite { email: string; player: string; createdBy?: string; createdAt?: number }

/** Invite doc id: the email, lower-cased (rules compare it with the signed-in email lower-cased). */
export const inviteKey = (email: string) => email.trim().toLowerCase();

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/**
 * Lines of «email — nick» (any of — – - , ; : tab or spaces between). The nick is a roster name or
 * nickname, any case; it is stored as the roster's display name. `aliases`: lower-cased name or
 * nickname → display name.
 */
export function parseInvites(text: string, aliases: Map<string, string>): { invites: Invite[]; errors: string[] } {
  const invites: Invite[] = [];
  const errors: string[] = [];
  const seen = new Set<string>();
  text.split(/\r?\n/).forEach((raw, i) => {
    const line = raw.trim();
    if (!line) return;
    // The email runs up to a space, comma, semicolon or dash «—/–» (a «-» may be inside the email).
    const m = /^([^\s,;—–]+)[\s,;:—–]+(.+)$/.exec(line);
    const where = `Рядок ${i + 1}`;
    if (!m || !EMAIL.test(m[1])) { errors.push(`${where}: спершу імейл, потім нік`); return; }
    const email = inviteKey(m[1]);
    const nick = normalizeName(m[2].replace(/^[\s,;:—–-]+/, ''));
    const player = aliases.get(nick.toLowerCase());
    if (!player) { errors.push(`${where}: «${nick}» немає в списку гравців`); return; }
    if (seen.has(email)) { errors.push(`${where}: ${email} уже є вище`); return; }
    seen.add(email);
    invites.push({ email, player });
  });
  return { invites, errors };
}
