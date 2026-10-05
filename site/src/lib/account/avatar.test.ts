import { describe, expect, it } from 'vitest';
import { cropRect, encodeAvatar, type Canvasish } from './avatar.ts';

describe('cropRect', () => {
  it('centres the largest square at zoom 1', () => {
    expect(cropRect(400, 200, 1, 0, 0)).toEqual({ sx: 100, sy: 0, size: 200 });
    expect(cropRect(200, 400, 1, 0, 0)).toEqual({ sx: 0, sy: 100, size: 200 });
  });
  it('zoom shrinks the square; shifts stay inside the image', () => {
    expect(cropRect(400, 400, 2, 0, 0)).toEqual({ sx: 100, sy: 100, size: 200 });
    expect(cropRect(400, 400, 2, 1, -1)).toEqual({ sx: 200, sy: 0, size: 200 });
    expect(cropRect(400, 400, 2, 5, -5)).toEqual({ sx: 200, sy: 0, size: 200 });
  });
  it('zoom below 1 is treated as 1', () => {
    expect(cropRect(300, 300, 0.5, 0, 0)).toEqual({ sx: 0, sy: 0, size: 300 });
  });
});

const fakeCanvas = (urls: (type: string, q?: number) => string): (() => Canvasish) => () => ({
  width: 0, height: 0, getContext: () => ({ drawImage: () => {} }), toDataURL: urls,
});
const img = { width: 100, height: 100 } as unknown as HTMLImageElement;
const rect = { sx: 0, sy: 0, size: 100 };

describe('encodeAvatar', () => {
  it('uses WebP when the browser encodes it', () => {
    expect(encodeAvatar(img, rect, fakeCanvas(() => 'data:image/webp;base64,AAAA'))).toBe('data:image/webp;base64,AAAA');
  });
  it('falls back to JPEG when WebP comes back as PNG (Safari)', () => {
    const out = encodeAvatar(img, rect, fakeCanvas((t) => (t === 'image/webp' ? 'data:image/png;base64,AAAA' : 'data:image/jpeg;base64,BBBB')));
    expect(out).toBe('data:image/jpeg;base64,BBBB');
  });
  it('lowers quality until it fits, else throws too-big', () => {
    const qs: number[] = [];
    const big = `data:image/webp;base64,${'A'.repeat(200_000)}`;
    const out = encodeAvatar(img, rect, fakeCanvas((_t, q) => { qs.push(q!); return q! <= 0.5 ? 'data:image/webp;base64,AAAA' : big; }));
    expect(out).toBe('data:image/webp;base64,AAAA');
    expect(qs).toEqual([0.85, 0.85, 0.7, 0.5]); // first call probes WebP support
    expect(() => encodeAvatar(img, rect, fakeCanvas(() => big))).toThrow('too-big');
  });
});
