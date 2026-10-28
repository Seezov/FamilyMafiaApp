// Shared by the federation scripts: polite sequential GETs and Firestore REST decoding.
import type { FedDoc } from '../../src/lib/federations/core.ts';

export const UA = 'Mozilla/5.0 (FamilyMafiaClub federation matcher)';
export const FED_DOC_URL = 'https://firestore.googleapis.com/v1/projects/familymafiaapp/databases/(default)/documents/config/federations';

/** Waits delayMs before each try; gives up on a try after timeoutMs (30 s); retries `retries` times (1), then throws. */
export async function politeGet(f: typeof fetch, url: string, o: { delayMs: number; retries?: number; timeoutMs?: number }): Promise<string> {
  for (let attempt = 0; ; attempt++) {
    if (o.delayMs) await new Promise((r) => setTimeout(r, o.delayMs));
    try {
      const signal = AbortSignal.timeout(o.timeoutMs ?? 30_000);
      const res = await f(url, { headers: { 'User-Agent': UA }, signal });
      if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
      return await res.text();
    } catch (e) {
      if (attempt >= (o.retries ?? 1)) throw e;
    }
  }
}

/** Firestore REST value → plain JSON (maps, arrays, strings, numbers, booleans). */
export function restValue(v: any): unknown {
  if (v == null) return null;
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields ?? {}).map(([k, x]) => [k, restValue(x)]));
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(restValue);
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  return null;
}

/** config/federations as read over REST (a missing document reads as empty). */
export function fedDocFromRest(doc: any): FedDoc {
  const d = restValue({ mapValue: { fields: doc?.fields ?? {} } }) as Partial<FedDoc>;
  return { links: d.links ?? {}, rejected: d.rejected ?? {}, gameDecisions: d.gameDecisions ?? {} };
}
