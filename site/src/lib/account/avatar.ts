// site/src/lib/account/avatar.ts
// Square crop + 256×256 WebP (JPEG where the browser cannot encode WebP), small enough for Firestore.
import { AVATAR_MAX_CHARS } from '../profiles/core';

export const AVATAR_SIZE = 256;
const QUALITIES = [0.85, 0.7, 0.5];
const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

export function cropRect(w: number, h: number, zoom: number, dx: number, dy: number) {
  const size = Math.round(Math.min(w, h) / Math.max(1, zoom));
  const freeX = w - size, freeY = h - size;
  return {
    sx: Math.round(freeX / 2 + clamp(dx, -1, 1) * freeX / 2),
    sy: Math.round(freeY / 2 + clamp(dy, -1, 1) * freeY / 2),
    size,
  };
}

export interface Canvasish {
  width: number; height: number;
  getContext(t: '2d'): { drawImage(...a: unknown[]): void } | null;
  toDataURL(type: string, q?: number): string;
}

export function encodeAvatar(
  img: CanvasImageSource & { width: number; height: number },
  rect: { sx: number; sy: number; size: number },
  makeCanvas: () => Canvasish = () => document.createElement('canvas') as unknown as Canvasish,
): string {
  const c = makeCanvas();
  c.width = AVATAR_SIZE;
  c.height = AVATAR_SIZE;
  c.getContext('2d')!.drawImage(img, rect.sx, rect.sy, rect.size, rect.size, 0, 0, AVATAR_SIZE, AVATAR_SIZE);
  const webp = c.toDataURL('image/webp', QUALITIES[0]).startsWith('data:image/webp');
  const type = webp ? 'image/webp' : 'image/jpeg';
  for (const q of QUALITIES) {
    const url = c.toDataURL(type, q);
    if (url.length <= AVATAR_MAX_CHARS) return url;
  }
  throw new Error('too-big');
}
