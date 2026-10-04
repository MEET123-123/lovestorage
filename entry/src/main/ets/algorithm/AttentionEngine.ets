import { Item } from '../domain/Item';
import { InventoryDomain } from './InventoryDomain';
import { ExpiryService, ShelfLifeUnit } from './ExpiryService';
import { AttentionRules, DEFAULT_ATTENTION_RULES } from './AttentionRules';

export interface AttentionDecision {
  itemId: string;
  score: number;
  priority: string;
  reasonCodes: string[];
  effectiveExpiryDate?: string;
  remainingDays?: number;
  ruleVersion: string;
}

// Priority measures attention only. It never certifies safety or extends expiry dates.
export class AttentionEngine {
  private rules: AttentionRules;
  constructor(rules: AttentionRules = DEFAULT_ATTENTION_RULES) { this.rules = rules; }
  evaluate(item: Item, today: string): AttentionDecision | undefined {
    if (item.deletedAt !== undefined || item.lifecycleStatus !== 'ACTIVE' || (item.quantity ?? 1) <= 0
      || (item.snoozeUntil !== undefined && item.snoozeUntil > today)) return undefined;
    const result = InventoryDomain.evaluate(item, today);
    const days = result.remainingDays;
    if (days !== undefined && days > (item.reminderDays ?? InventoryDomain.category(item.categoryId).days)) return undefined;
    const r = this.rules;
    const reasons: string[] = [];
    let score: number = 0;
    if (days === undefined) { score = r.unknown; reasons.push('MISSING_EXPIRY'); }
    else if (days < 0) { score = r.expired; reasons.push('EXPIRED'); }
    else if (days === 0) { score = r.today; reasons.push('EXPIRES_TODAY'); }
    else if (days === 1) { score = r.tomorrow; reasons.push('EXPIRES_TOMORROW'); }
    else if (days === 2) { score = r.twoDays; reasons.push('EXPIRES_IN_TWO_DAYS'); }
    else if (days === 3) { score = r.threeDays; reasons.push('EXPIRES_IN_THREE_DAYS'); }
    else if (days <= 7) { score = r.week; reasons.push('EXPIRES_THIS_WEEK'); }
    else { score = r.withinWindow; reasons.push('WITHIN_REMINDER_WINDOW'); }
    if (item.openedDate !== undefined && item.openedDate <= today) {
      score += r.opened; reasons.push('OPENED');
      const pao = new ExpiryService().evaluate(undefined, item.openedDate, item.afterOpenValue,
        item.afterOpenUnit as ShelfLifeUnit | undefined, r.paoWindowDays, today).remainingDays;
      if (pao !== undefined && pao >= 0 && pao <= r.paoWindowDays) { score += r.paoNear; reasons.push('PAO_NEAR'); }
    }
    if (item.snoozeUntil !== undefined) { score += r.snoozeReturned; reasons.push('SNOOZE_RETURNED'); }
    if ((item.quantity ?? 1) >= r.quantityThreshold) { score += r.quantityBonus; reasons.push('LARGE_QUANTITY'); }
    return { itemId: item.id, score, priority: score >= r.highThreshold ? 'HIGH' : score >= r.mediumThreshold ? 'MEDIUM' : 'LOW',
      reasonCodes: reasons, effectiveExpiryDate: result.effectiveExpiryDate, remainingDays: days, ruleVersion: r.version };
  }
  rank(items: Item[], today: string, limit: number = 10): AttentionDecision[] {
    const decisions: AttentionDecision[] = [];
    for (const item of items) { const decision = this.evaluate(item, today); if (decision) decisions.push(decision); }
    return decisions.sort((a: AttentionDecision, b: AttentionDecision) => b.score - a.score
      || (a.effectiveExpiryDate ?? '9999-12-31').localeCompare(b.effectiveExpiryDate ?? '9999-12-31')
      || a.itemId.localeCompare(b.itemId)).slice(0, limit);
  }
  static reason(code: string): string {
    switch (code) {
      case 'EXPIRED': return '已过有效期限';
      case 'EXPIRES_TODAY': return '今天到期';
      case 'EXPIRES_TOMORROW': return '明天到期';
      case 'EXPIRES_IN_TWO_DAYS': return '两天后到期';
      case 'EXPIRES_IN_THREE_DAYS': return '三天后到期';
      case 'EXPIRES_THIS_WEEK': return '一周内到期';
      case 'WITHIN_REMINDER_WINDOW': return '已到提前提醒时间';
      case 'OPENED': return '已经开封';
      case 'PAO_NEAR': return '开封期限临近';
      case 'SNOOZE_RETURNED': return '稍后提醒已到期';
      case 'LARGE_QUANTITY': return '剩余数量较多';
      case 'MISSING_EXPIRY': return '需要补充日期';
      default: return '按到期日排列';
    }
  }
}
