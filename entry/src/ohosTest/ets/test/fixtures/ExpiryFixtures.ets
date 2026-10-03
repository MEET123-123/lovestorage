// AUTO-GENERATED. DO NOT EDIT.
// Source: /shared/expiry-test-cases.json

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
    expectedStatus: "NEAR_EXPIRY",
    expectedEffectiveExpiryDate: "2026-10-02"
  },
  {
    id: "expired-yesterday",
    today: "2026-10-02",
    expiryDate: "2026-10-01",
    reminderDays: 7,
    expectedRemainingDays: -1,
    expectedStatus: "EXPIRED",
    expectedEffectiveExpiryDate: "2026-10-01"
  },
  {
    id: "cross-year",
    today: "2026-12-30",
    expiryDate: "2027-01-03",
    reminderDays: 3,
    expectedRemainingDays: 4,
    expectedStatus: "NORMAL",
    expectedEffectiveExpiryDate: "2027-01-03"
  },
  {
    id: "opened-pao-earlier",
    today: "2026-10-02",
    expiryDate: "2028-01-01",
    openedDate: "2026-08-01",
    afterOpenValue: 2,
    afterOpenUnit: "MONTH",
    reminderDays: 7,
    expectedRemainingDays: -1,
    expectedStatus: "EXPIRED",
    expectedEffectiveExpiryDate: "2026-10-01"
  },
  {
    id: "nominal-expiry-earlier-than-pao",
    today: "2026-10-02",
    expiryDate: "2026-10-10",
    openedDate: "2026-09-01",
    afterOpenValue: 12,
    afterOpenUnit: "MONTH",
    reminderDays: 7,
    expectedRemainingDays: 8,
    expectedStatus: "NORMAL",
    expectedEffectiveExpiryDate: "2026-10-10"
  },
  {
    id: "month-end-clamp",
    today: "2026-02-20",
    expiryDate: "2027-12-31",
    openedDate: "2026-01-31",
    afterOpenValue: 1,
    afterOpenUnit: "MONTH",
    reminderDays: 7,
    expectedRemainingDays: 8,
    expectedStatus: "NORMAL",
    expectedEffectiveExpiryDate: "2026-02-28"
  },
  {
    id: "leap-year-clamp",
    today: "2025-02-20",
    expiryDate: "2027-12-31",
    openedDate: "2024-02-29",
    afterOpenValue: 1,
    afterOpenUnit: "YEAR",
    reminderDays: 7,
    expectedRemainingDays: 8,
    expectedStatus: "NORMAL",
    expectedEffectiveExpiryDate: "2025-02-28"
  },
];
