import { describe, expect, it } from 'vitest';
import { indexBySlug } from './site.ts';

describe('indexBySlug', () => {
  it('maps slugs to profiles via the player key', () => {
    const idx = indexBySlug(
      [{ slug: 'braun', name: 'Braun' }, { slug: 'zaliznyi', name: 'Залізний' }],
      { braun: { nick: 'Boss', avatar: 'avatars/1.webp' } },
    );
    expect(idx.get('braun')).toEqual({ nick: 'Boss', avatar: 'avatars/1.webp' });
    expect(idx.get('zaliznyi')).toBeUndefined();
  });
});
