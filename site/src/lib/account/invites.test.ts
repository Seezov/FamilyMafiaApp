import { describe, expect, it } from 'vitest';
import { inviteKey, parseInvites } from './invites';

const aliases = new Map([['мелок', 'Мелок'], ['мілок', 'Мелок'], ['green', 'Green'], ['дядя толя', 'Дядя Толя']]);

describe('parseInvites', () => {
  it('reads email — nick with several separators, stores the display name and a lower-cased email', () => {
    const r = parseInvites('Ann@Gmail.com — мілок\nbob@gmail.com, GREEN\n\ncat@ukr.net\tдядя  толя', aliases);
    expect(r.errors).toEqual([]);
    expect(r.invites).toEqual([
      { email: 'ann@gmail.com', player: 'Мелок' },
      { email: 'bob@gmail.com', player: 'Green' },
      { email: 'cat@ukr.net', player: 'Дядя Толя' },
    ]);
  });
  it('reports a bad email, an unknown nick and a repeated email by line', () => {
    const r = parseInvites('nope — Green\nann@gmail.com - Хтось\nann@gmail.com - Green\nANN@gmail.com - Мелок', aliases);
    expect(r.invites).toEqual([{ email: 'ann@gmail.com', player: 'Green' }]);
    expect(r.errors).toEqual([
      'Рядок 1: спершу імейл, потім нік',
      'Рядок 2: «Хтось» немає в списку гравців',
      'Рядок 4: ann@gmail.com уже є вище',
    ]);
  });
  it('an email with dashes, and a «-» separator', () => {
    const r = parseInvites('claude-test@my-site.com — мілок\nann.b@x-y.ua - Green\nc@d.com;Green', aliases);
    expect(r.errors).toEqual([]);
    expect(r.invites.map((i) => i.email)).toEqual(['claude-test@my-site.com', 'ann.b@x-y.ua', 'c@d.com']);
  });
  it('inviteKey trims and lower-cases', () => expect(inviteKey(' A@B.com ')).toBe('a@b.com'));
});
