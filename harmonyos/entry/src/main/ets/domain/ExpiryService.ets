export enum ExpiryStatus {
  UNKNOWN = 'UNKNOWN',
  NORMAL = 'NORMAL',
  NEAR_EXPIRY = 'NEAR_EXPIRY',
  EXPIRED = 'EXPIRED'
}

export enum ShelfLifeUnit {
  DAY = 'DAY',
  MONTH = 'MONTH',
  YEAR = 'YEAR'
}

export interface ExpiryEvaluation {
  effectiveExpiryDate?: string;
  remainingDays?: number;
  status: ExpiryStatus;
}

export class ExpiryService {
  evaluate(expiryDate: string | undefined, openedDate: string | undefined,
    afterOpenValue: number | undefined, afterOpenUnit: ShelfLifeUnit | undefined,
    reminderDays: number, today: string): ExpiryEvaluation {
    const effective = this.effectiveExpiryDate(expiryDate, openedDate, afterOpenValue, afterOpenUnit);
    if (effective === undefined) {
      return { status: ExpiryStatus.UNKNOWN };
    }
    const remaining = this.daysBetween(today, effective);
    let status: ExpiryStatus = ExpiryStatus.NORMAL;
    if (remaining < 0) {
      status = ExpiryStatus.EXPIRED;
    } else if (remaining <= reminderDays) {
      status = ExpiryStatus.NEAR_EXPIRY;
    }
    return { effectiveExpiryDate: effective, remainingDays: remaining, status };
  }

  effectiveExpiryDate(expiryDate: string | undefined, openedDate: string | undefined,
    afterOpenValue: number | undefined, afterOpenUnit: ShelfLifeUnit | undefined): string | undefined {
    let afterOpenExpiry: string | undefined = undefined;
    if (openedDate !== undefined && afterOpenValue !== undefined && afterOpenUnit !== undefined) {
      afterOpenExpiry = this.addDate(openedDate, afterOpenValue, afterOpenUnit);
    }
    if (expiryDate === undefined) return afterOpenExpiry;
    if (afterOpenExpiry === undefined) return expiryDate;
    return expiryDate < afterOpenExpiry ? expiryDate : afterOpenExpiry;
  }

  deriveExpiryDate(productionDate: string | undefined, value: number | undefined,
    unit: ShelfLifeUnit | undefined): string | undefined {
    if (productionDate === undefined || value === undefined || unit === undefined) return undefined;
    return this.addDate(productionDate, value, unit);
  }

  private addDate(dateText: string, value: number, unit: ShelfLifeUnit): string {
    const [year, month, day] = dateText.split('-').map((v: string) => Number(v));
    if (unit === ShelfLifeUnit.DAY) {
      const date = new Date(Date.UTC(year, month - 1, day));
      date.setUTCDate(date.getUTCDate() + value);
      return this.toIsoDate(date);
    }

    if (unit === ShelfLifeUnit.MONTH) {
      const totalMonths = year * 12 + (month - 1) + value;
      const targetYear = Math.floor(totalMonths / 12);
      const targetMonthIndex = totalMonths % 12;
      const targetDay = Math.min(day, this.daysInMonth(targetYear, targetMonthIndex + 1));
      return this.toIsoDate(new Date(Date.UTC(targetYear, targetMonthIndex, targetDay)));
    }

    const targetYear = year + value;
    const targetDay = Math.min(day, this.daysInMonth(targetYear, month));
    return this.toIsoDate(new Date(Date.UTC(targetYear, month - 1, targetDay)));
  }

  private daysInMonth(year: number, month: number): number {
    return new Date(Date.UTC(year, month, 0)).getUTCDate();
  }

  private daysBetween(from: string, to: string): number {
    const dayMs = 24 * 60 * 60 * 1000;
    const a = this.parseUtc(from).getTime();
    const b = this.parseUtc(to).getTime();
    return Math.round((b - a) / dayMs);
  }

  private parseUtc(value: string): Date {
    const [year, month, day] = value.split('-').map((v: string) => Number(v));
    return new Date(Date.UTC(year, month - 1, day));
  }

  private toIsoDate(date: Date): string {
    const y = date.getUTCFullYear();
    const m = `${date.getUTCMonth() + 1}`.padStart(2, '0');
    const d = `${date.getUTCDate()}`.padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
}
