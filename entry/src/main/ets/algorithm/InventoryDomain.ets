import { Item, ConsumptionRecord } from '../domain/Item';
import { ExpiryService, ExpiryEvaluation, ExpiryStatus, ShelfLifeUnit } from './ExpiryService';
import { RecognitionEngine } from './RecognitionEngine';

export interface CategoryView { id: string; name: string; mark: string; color: string; days: number; }
export interface Overview { active: number; near: number; expired: number; consumed: number; discarded: number; }
export interface ParsedDraft { name: string; expiry: string; production: string; shelfLife: string; unit: number; evidence: string; }

export class InventoryDomain {
  static readonly categories: CategoryView[] = [
    { id: 'food', name: '食品', mark: '食', color: '#28785C', days: 7 },
    { id: 'cosmetics', name: '美妆个护', mark: '妆', color: '#A15B73', days: 30 },
    { id: 'pet_food', name: '宠物粮', mark: '宠', color: '#AD7835', days: 14 },
    { id: 'other', name: '日用其他', mark: '物', color: '#5576A1', days: 7 }
  ];
  static today(): string { return InventoryDomain.dateText(new Date()); }
  static dateText(date: Date): string {
    return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}-${`${date.getDate()}`.padStart(2, '0')}`;
  }
  static validDate(value: string): boolean {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const p = value.split('-').map((n: string) => Number(n));
    const d = new Date(Date.UTC(p[0], p[1] - 1, p[2]));
    return p[0] >= 1900 && p[0] <= 9999 && d.getUTCFullYear() === p[0] && d.getUTCMonth() === p[1] - 1 && d.getUTCDate() === p[2];
  }
  static category(id: string): CategoryView { return InventoryDomain.categories.find((c: CategoryView) => c.id === id) ?? InventoryDomain.categories[3]; }
  static evaluate(item: Item, today: string = InventoryDomain.today()): ExpiryEvaluation {
    return new ExpiryService().evaluate(item.expiryDate, item.openedDate, item.afterOpenValue,
      item.afterOpenUnit as ShelfLifeUnit | undefined, item.reminderDays ?? InventoryDomain.category(item.categoryId).days, today);
  }
  static validate(item: Item): string {
    if (item.name.trim().length === 0 || item.name.trim().length > 80) return '名称需为 1–80 个字';
    if ((item.brand ?? '').length > 120) return '品牌不能超过 120 个字';
    if ((item.unit ?? '').length > 32) return '单位不能超过 32 个字';
    if ((item.location ?? '').length > 80) return '存放位置不能超过 80 个字';
    if ((item.notes ?? '').length > 500) return '备注不能超过 500 个字';
    if (!InventoryDomain.categories.some((c: CategoryView) => c.id === item.categoryId)) return '请选择分类';
    const quantity = item.quantity ?? 1;
    if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 999999999 || Math.abs(quantity * 1000 - Math.round(quantity * 1000)) > 0.00001) return '数量需大于 0，最多保留 3 位小数';
    if (item.expiryDate === undefined || !InventoryDomain.validDate(item.expiryDate)) return '填写到期日期，或提供生产日期与保质期';
    if (item.productionDate !== undefined && !InventoryDomain.validDate(item.productionDate)) return '生产日期无效';
    if (item.productionDate !== undefined && item.expiryDate < item.productionDate) return '到期日期不能早于生产日期';
    if (item.openedDate !== undefined && (!InventoryDomain.validDate(item.openedDate) || item.openedDate > InventoryDomain.today())) return '开封日期需为今天或之前的有效日期';
    if (item.openedDate !== undefined && item.productionDate !== undefined && item.openedDate < item.productionDate) return '开封日期不能早于生产日期';
    if (item.afterOpenValue !== undefined && (!Number.isInteger(item.afterOpenValue) || item.afterOpenValue <= 0 || item.afterOpenValue > 1200)) return '开封后期限需为 1–1200 的整数';
    if (item.shelfLifeValue !== undefined && (!Number.isInteger(item.shelfLifeValue) || item.shelfLifeValue <= 0 || item.shelfLifeValue > 1200)) return '保质期需为 1–1200 的整数';
    if (item.afterOpenValue !== undefined && item.openedDate === undefined) return '请补充开封日期';
    if (item.afterOpenValue !== undefined && !['DAY', 'MONTH', 'YEAR'].includes(item.afterOpenUnit ?? '')) return '请选择开封期限单位';
    if (!Number.isInteger(item.reminderDays ?? 7) || (item.reminderDays ?? 7) < 0 || (item.reminderDays ?? 7) > 365) return '提前提醒天数需为 0–365 的整数';
    return '';
  }
  static statusLabel(item: Item, today: string = InventoryDomain.today()): string {
    if (item.lifecycleStatus === 'CONSUMED') return '已用完';
    if (item.lifecycleStatus === 'DISCARDED') return '已丢弃';
    if (item.lifecycleStatus === 'ARCHIVED') return '已归档';
    const r = InventoryDomain.evaluate(item, today);
    if (r.status === ExpiryStatus.UNKNOWN) return '待补日期';
    if ((r.remainingDays ?? 0) < 0) return `过期 ${Math.abs(r.remainingDays ?? 0)} 天`;
    if (r.remainingDays === 0) return '今天到期';
    return `${r.status === ExpiryStatus.NEAR_EXPIRY ? '临期 · ' : ''}剩 ${r.remainingDays} 天`;
  }
  static statusColor(item: Item, today: string = InventoryDomain.today()): string {
    if (item.lifecycleStatus !== 'ACTIVE') return '#79867E';
    const status = InventoryDomain.evaluate(item, today).status;
    return status === ExpiryStatus.EXPIRED ? '#B84A46' : status === ExpiryStatus.NEAR_EXPIRY ? '#AC6A27' : '#28785C';
  }
  static urgent(items: Item[], today: string, includeSnoozed: boolean = false): Item[] {
    return items.filter((i: Item) => i.lifecycleStatus === 'ACTIVE' && (InventoryDomain.evaluate(i, today).remainingDays ?? 999999) <= (i.reminderDays ?? InventoryDomain.category(i.categoryId).days)
      && (includeSnoozed || i.snoozeUntil === undefined || i.snoozeUntil <= today))
      .sort((a: Item, b: Item) => (InventoryDomain.evaluate(a, today).remainingDays ?? 999999) - (InventoryDomain.evaluate(b, today).remainingDays ?? 999999));
  }
  static filter(items: Item[], query: string, category: string, status: string, order: number, today: string): Item[] {
    const key = query.trim().toLowerCase();
    return items.filter((i: Item) => {
      if (key && !`${i.name} ${i.brand ?? ''} ${i.location ?? ''}`.toLowerCase().includes(key)) return false;
      if (category !== 'all' && i.categoryId !== category) return false;
      if (status === 'all') return true;
      if (status === 'NEAR_EXPIRY' || status === 'EXPIRED') return i.lifecycleStatus === 'ACTIVE' && InventoryDomain.evaluate(i, today).status === status;
      return i.lifecycleStatus === status;
    }).sort((a: Item, b: Item) => order === 1 ? b.updatedAt - a.updatedAt : order === 2 ? a.name.localeCompare(b.name)
      : (InventoryDomain.evaluate(a, today).remainingDays ?? 999999) - (InventoryDomain.evaluate(b, today).remainingDays ?? 999999));
  }
  static overview(items: Item[], records: ConsumptionRecord[], today: string): Overview {
    return {
      active: items.filter((i: Item) => i.lifecycleStatus === 'ACTIVE').length,
      near: items.filter((i: Item) => i.lifecycleStatus === 'ACTIVE' && InventoryDomain.evaluate(i, today).status === ExpiryStatus.NEAR_EXPIRY).length,
      expired: items.filter((i: Item) => i.lifecycleStatus === 'ACTIVE' && InventoryDomain.evaluate(i, today).status === ExpiryStatus.EXPIRED).length,
      consumed: records.filter((r: ConsumptionRecord) => r.revoked === 0 && r.action === 'CONSUMED').length,
      discarded: records.filter((r: ConsumptionRecord) => r.revoked === 0 && r.action === 'DISCARDED').length
    };
  }
  static advice(item: Item, today: string): string {
    const r = InventoryDomain.evaluate(item, today);
    if (item.lifecycleStatus !== 'ACTIVE') return '这件物品已处理，可按实际需要加入补货清单。';
    if (r.status === ExpiryStatus.EXPIRED) return '已超过记录的有效期限，请停止使用并按包装说明处理；不建议继续食用或喂养。';
    if (r.status === ExpiryStatus.UNKNOWN) return '先补充包装上的日期，再安排后续使用。';
    if (item.categoryId === 'cosmetics') return '留意开封后期限及外观、气味变化，优先使用临期品；发生异常应停止使用。';
    if (item.categoryId === 'pet_food') return '按包装要求密封保存，并按日常喂食计划安排余量，不为清库存增加喂食量。';
    if (item.categoryId === 'food') return '可优先安排近期使用，仍需检查包装、储存条件和实际状态；日期记录不等于安全保证。';
    return '把临期物品放在容易看见的位置，按产品说明优先使用，减少重复购买。';
  }
  static parseText(text: string): ParsedDraft {
    const draft = RecognitionEngine.parse(text);
    return { name: draft.name, expiry: draft.expiry, production: draft.production, shelfLife: draft.shelfLife, unit: draft.unit,
      evidence: draft.warnings.join('；') || '请对照包装逐项核对后保存。' };
  }
}
