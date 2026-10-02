// AUTO-GENERATED. DO NOT EDIT.
// Source: /contract/expiry-test-cases.json

export interface ExpiryFixture {
  id: string;
  today: string;
  expiryDate: string;
  openedDate?: string;
  afterOpenValue?: number;
  afterOpenUnit?: string;
  reminderDays: number;
  expectedRemainingDays: number;
  expectedStatus: string;
  expectedEffectiveExpiryDate: string;
}

export const EXPIRY_FIXTURES: ExpiryFixture[] = [
  {
    id: "normal-18-days",
    today: "2026-10-02",
    expiryDate: "2026-10-20",
    reminderDays: 7,
    expectedRemainingDays: 18,
    expectedStatus: "NORMAL",
    expectedEffectiveExpiryDate: "2026-10-20"
  },
  {
    id: "near-expiry-7-days",
    today: "2026-10-02",
    expiryDate: "2026-10-09",
    reminderDays: 7,
    expectedRemainingDays: 7,
    expectedStatus: "NEAR_EXPIRY",
    expectedEffectiveExpiryDate: "2026-10-09"
  },
  {
    id: "expires-today",
    today: "2026-10-02",
    expiryDate: "2026-10-02",
    reminderDays: 7,
    expectedRemainingDays: 0,
    expectedStatus: "NEAR_EXPIRY‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒ‹LLLˆ‚ˆKˆÂˆYˆ™^\™Y^Y\İ\™^H‹ˆÙ^NˆŒŒ‹LLLˆ‹ˆ^\Q]NˆŒŒ‹LLLH‹ˆ™[Z[™\‘^\ÎˆËˆ^XİY™[XZ[š[™Ñ^\ÎˆLKˆ^XİYİ]\Îˆ‘VT‘Q‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒ‹LLLH‚ˆKˆÂˆYˆ˜Ü›ÜÜË^YX\ˆ‹ˆÙ^NˆŒŒ‹LL‹LÌ‹ˆ^\Q]NˆŒŒËLKLÈ‹ˆ™[Z[™\‘^\ÎˆËˆ^XİY™[XZ[š[™Ñ^\Îˆˆ^XİYİ]\Îˆ““Ô“PS‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒËLKLÈ‚ˆKˆÂˆYˆ›Ü[™Y\[ËYX\›Y\ˆ‹ˆÙ^NˆŒŒ‹LLLˆ‹ˆ^\Q]NˆŒŒLKLH‹ˆÜ[™Y]NˆŒŒ‹LLH‹ˆY\“Ü[•˜[YNˆ‹ˆY\“Ü[•[š]ˆ“SÓ•‹ˆ™[Z[™\‘^\ÎˆËˆ^XİY™[XZ[š[™Ñ^\ÎˆLKˆ^XİYİ]\Îˆ‘VT‘Q‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒ‹LLLH‚ˆKˆÂˆYˆ››ÛZ[˜[Y^\KYX\›Y\‹][‹\[È‹ˆÙ^NˆŒŒ‹LLLˆ‹ˆ^\Q]NˆŒŒ‹LLLL‹ˆÜ[™Y]NˆŒŒ‹LKLH‹ˆY\“Ü[•˜[YNˆL‹ˆY\“Ü[•[š]ˆ“SÓ•‹ˆ™[Z[™\‘^\ÎˆËˆ^XİY™[XZ[š[™Ñ^\Îˆˆ^XİYİ]\Îˆ““Ô“PS‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒ‹LLLL‚ˆKˆÂˆYˆ›[ÛY[™XÛ[\‹ˆÙ^NˆŒŒ‹L‹LŒ‹ˆ^\Q]NˆŒŒËLL‹LÌH‹ˆÜ[™Y]NˆŒŒ‹LKLÌH‹ˆY\“Ü[•˜[YNˆKˆY\“Ü[•[š]ˆ“SÓ•‹ˆ™[Z[™\‘^\ÎˆËˆ^XİY™[XZ[š[™Ñ^\Îˆˆ^XİYİ]\Îˆ““Ô“PS‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒ‹L‹L‚ˆKˆÂˆYˆ›X\^YX\‹XÛ[\‹ˆÙ^NˆŒŒKL‹LŒ‹ˆ^\Q]NˆŒŒËLL‹LÌH‹ˆÜ[™Y]NˆŒŒL‹LH‹ˆY\“Ü[•˜[YNˆKˆY\“Ü[•[š]ˆ–QPTˆ‹ˆ™[Z[™\‘^\ÎˆËˆ^XİY™[XZ[š[™Ñ^\Îˆˆ^XİYİ]\Îˆ““Ô“PS‹ˆ^XİYY™™Xİ]™Q^\Q]NˆŒŒKL‹L‚ˆK—NÂ