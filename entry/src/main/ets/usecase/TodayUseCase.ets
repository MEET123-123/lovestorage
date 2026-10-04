import { Item } from '../domain/Item';
import { InventoryDomain } from '../algorithm/InventoryDomain';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';

export interface TodayUndo {
  itemId: string;
  action: string;
  updatedAt: number;
  previousSnooze?: string;
}
export class TodayUseCase {
  private repository: ItemLocalRepository;
  constructor(repository: ItemLocalRepository = new ItemLocalRepository()) { this.repository = repository; }
  private async find(id: string): Promise<Item> {
    const item = (await this.repository.listActive()).find((row: Item) => row.id === id);
    if (!item) throw new Error('物品已移除，请刷新后重试');
    return item;
  }
  async perform(id: string, action: string, today: string): Promise<TodayUndo> {
    const item = await this.find(id);
    if (item.lifecycleStatus !== 'ACTIVE') throw new Error('这件物品已处理，请刷新后重试');
    if (!['CONSUMED', 'DISCARDED', 'SNOOZE'].includes(action)) throw new Error('不支持的今日操作');
    const previousSnooze = item.snoozeUntil;
    if (action === 'SNOOZE') {
      const tomorrow = new Date(`${today}T12:00:00`); tomorrow.setDate(tomorrow.getDate() + 1);
      item.snoozeUntil = InventoryDomain.dateText(tomorrow);
      await this.repository.update(item);
    } else { await this.repository.transition(item, action); }
    const saved = await this.find(id);
    return { itemId: id, action, updatedAt: saved.updatedAt, previousSnooze };
  }
  async undo(token: TodayUndo): Promise<void> {
    const item = await this.find(token.itemId);
    if (item.updatedAt !== token.updatedAt || (token.action !== 'SNOOZE' && item.lifecycleStatus !== token.action)) {
      throw new Error('物品已再次修改，请在详情中处理，不能覆盖新记录');
    }
    if (token.action === 'SNOOZE') { item.snoozeUntil = token.previousSnooze; await this.repository.update(item); }
    else { await this.repository.transition(item, 'ACTIVE'); }
  }
}
