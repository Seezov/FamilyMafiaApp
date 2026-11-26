// Additional points («Доп») the club allows: 0.2–1.0 in steps of 0.1, or 1.3 (no 1.1, 1.2).
// The same list bounds appeals. Keep in sync with validAdditional in firestore.rules.
export const ADDITIONAL_VALUES = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.3] as const;
export const ADDITIONAL_HINT = '0.2–1.0 (крок 0.1) або 1.3';

const r2 = (n: number) => Math.round(n * 100) / 100;
export const isAllowedAdditional = (n: number) => (ADDITIONAL_VALUES as readonly number[]).includes(r2(n));
/** A seat's доп: none, or one of the allowed values. */
export const isAllowedSeatAdditional = (n: number) => r2(n) === 0 || isAllowedAdditional(n);
