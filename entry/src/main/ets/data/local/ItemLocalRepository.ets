import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Item, ItemMetadata, InventoryBatch, ConsumptionRecord, ShoppingEntry } from '../../domain/Item';
import { AppDatabase } from './AppDatabase';

export class ItemLocalRepository {
  private metadata(item: Item): string {
    const value: ItemMetadata = { brand: item.brand, notes: item.notes, reminderDays: item.reminderDays, snoozeUntil: item.snoozeUntil };
    return JSON.stringify(value);
  }
  private batch(item: Item): string {
    const value: InventoryBatch = { expiryDate: item.expiryDate, quantity: item.quantity ?? 1, unit: item.unit ?? '件', productionDate: item.productionDate,
      shelfLifeValue: item.shelfLifeValue, shelfLifeUnit: item.shelfLifeUnit, openedDate: item.openedDate,
      afterOpenValue: item.afterOpenValue, afterOpenUnit: item.afterOpenUnit, location: item.location };
    return JSON.stringify(value);
  }
  async create(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = {
      id: item.id, name: item.name, category_id: item.categoryId, expiry_date: item.expiryDate ?? null,
      lifecycle_status: item.lifecycleStatus, created_at: item.createdAt, updated_at: item.updatedAt,
      deleted_at: null, pending: 1, remote_id: util.generateRandomUUID(), metadata: this.metadata(item)
    };
    store.beginTransaction();
    try {
      await store.insert('item', values);
      await store.executeSql('INSERT INTO inventory_batch (id, item_id, payload) VALUES (?, ?, ?)', [item.id, item.id, this.batch(item)]);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async listActive(): Promise<Item[]> { return this.query(false); }
  async listPending(): Promise<Item[]> { return this.query(true); }
  private async query(pending: boolean): Promise<Item[]> {
    const store = await AppDatabase.getStore();
    const result = await store.querySql('SELECT i.*, b.payload AS batch_payload FROM item i LEFT JOIN inventory_batch b ON b.item_id=i.id WHERE ' +
      (pending ? 'i.pending = 1' : 'i.deleted_at IS NULL') + ' ORDER BY i.updated_at DESC');
    const items: Item[] = [];
    try {
      while (result.goToNextRow()) {
        const expiryIndex = result.getColumnIndex('expiry_date');
        const deletedIndex = result.getColumnIndex('deleted_at');
        const remoteIndex = result.getColumnIndex('remote_id');
        const batchIndex = result.getColumnIndex('batch_payload');
        const meta = JSON.parse(result.getString(result.getColumnIndex('metadata'))) as ItemMetadata;
        const batch: InventoryBatch = result.isColumnNull(batchIndex) ? {} : JSON.parse(result.getString(batchIndex)) as InventoryBatch;
        items.push({
          id: result.getString(result.getColumnIndex('id')), name: result.getString(result.getColumnIndex('name')),
          categoryId: result.getString(result.getColumnIndex('category_id')),
          expiryDate: batch.expiryDate ?? (result.isColumnNull(expiryIndex) ? undefined : result.getString(expiryIndex)),
          lifecycleStatus: result.getString(result.getColumnIndex('lifecycle_status')),
          createdAt: result.getLong(result.getColumnIndex('created_at')), updatedAt: result.getLong(result.getColumnIndex('updated_at')),
          deletedAt: result.isColumnNull(deletedIndex) ? undefined : result.getLong(deletedIndex),
          remoteId: result.isColumnNull(remoteIndex) ? undefined : result.getString(remoteIndex), pending: result.getLong(result.getColumnIndex('pending')),
          brand: meta.brand, notes: meta.notes, reminderDays: meta.reminderDays, snoozeUntil: meta.snoozeUntil,
          quantity: batch.quantity ?? 1, unit: batch.unit ?? '件', productionDate: batch.productionDate,
          shelfLifeValue: batch.shelfLifeValue, shelfLifeUnit: batch.shelfLifeUnit, openedDate: batch.openedDate,
          afterOpenValue: batch.afterOpenValue, afterOpenUnit: batch.afterOpenUnit, location: batch.location
        });
      }
    } finally { result.close(); }
    return items;
  }
  async update(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const now = Math.max(Date.now(), item.updatedAt + 1);
    const values: relationalStore.ValuesBucket = {
      name: item.name, category_id: item.categoryId, expiry_date: item.expiryDate ?? null,
      lifecycle_status: item.lifecycleStatus, updated_at: now, pending: 1, metadata: this.metadata(item)
    };
    store.beginTransaction();
    try {
      await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id));
      await store.executeSql('UPDATE inventory_batch SET payload = ? WHERE item_id = ?', [this.batch(item), item.id]);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async transition(item: Item, status: string): Promise<void> {
    if (status === item.lifecycleStatus) return;
    if (status !== 'ACTIVE' && item.lifecycleStatus !== 'ACTIVE') throw new Error('先恢复在库，再执行其他处理');
    const store = await AppDatabase.getStore();
    store.beginTransaction();
    try {
      const values: relationalStore.ValuesBucket = { lifecycle_status: status, updated_at: Math.max(Date.now(), item.updatedAt + 1), pending: 1 };
      await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id));
      if (status === 'ACTIVE') {
        await store.executeSql('UPDATE consumption_record SET revoked = 1 WHERE item_id = ? AND revoked = 0', [item.id]);
      } else if (status === 'CONSUMED' || status === 'DISCARDED') {
        await store.executeSql('INSERT INTO consumption_record (id,item_id,name,action,quantity,created_at) VALUES (?,?,?,?,?,?)',
          [util.generateRandomUUID(), item.id, item.name, status, item.quantity ?? 1, Date.now()]);
      }
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async records(): Promise<ConsumptionRecord[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM consumption_record ORDER BY created_at DESC');
    const rows: ConsumptionRecord[] = [];
    try {
      while (rs.goToNextRow()) rows.push({ id: rs.getString(0), itemId: rs.getString(1), name: rs.getString(2), action: rs.getString(3),
        quantity: rs.getDouble(4), createdAt: rs.getLong(5), revoked: rs.getLong(6) });
    } finally { rs.close(); }
    return rows;
  }
  async softDelete(id: string): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('UPDATE item SET deleted_at = ?, updated_at = MAX(updated_at + 1, ?), pending = 1 WHERE id = ?', [Date.now(), Date.now(), id]);
  }
  async ensureRemoteId(item: Item): Promise<string> {
    if (item.remoteId !== undefined) return item.remoteId;
    const id = util.generateRandomUUID();
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = { remote_id: id };
    await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id));
    return id;
  }
  async acknowledge(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = { pending: 0 };
    await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id).equalTo('updated_at', item.updatedAt));
  }
  async getSetting(key: string, fallback: string = ''): Promise<string> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT value FROM setting WHERE key = ?', [key]);
    try { return rs.goToFirstRow() ? rs.getString(0) : fallback; } finally { rs.close(); }
  }
  async setSetting(key: string, value: string): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)', [key, value]);
  }
  async getServer(): Promise<string> { return this.getSetting('server'); }
  async setServer(url: string): Promise<void> {
    const store = await AppDatabase.getStore();
    const previous = await this.getServer();
    if (previous !== '' && previous !== url) await store.executeSql('UPDATE item SET pending = 1');
    await this.setSetting('server', url);
  }
  async shopping(): Promise<ShoppingEntry[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM shopping_entry ORDER BY done, created_at DESC');
    const rows: ShoppingEntry[] = [];
    try { while (rs.goToNextRow()) rows.push({ id: rs.getString(0), name: rs.getString(1), done: rs.getLong(2), createdAt: rs.getLong(3) }); }
    finally { rs.close(); }
    return rows;
  }
  async addShopping(name: string): Promise<void> {
    const clean = name.trim();
    if (!clean || clean.length > 80) throw new Error('补货名称需为 1–80 个字');
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT id FROM shopping_entry WHERE name = ? AND done = 0', [clean]);
    let exists = false;
    try { exists = rs.goToFirstRow(); } finally { rs.close(); }
    if (!exists) await store.executeSql('INSERT INTO shopping_entry (id,name,created_at) VALUES (?,?,?)', [util.generateRandomUUID(), clean, Date.now()]);
  }
  async toggleShopping(entry: ShoppingEntry): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('UPDATE shopping_entry SET done = ? WHERE id = ?', [entry.done === 1 ? 0 : 1, entry.id]);
  }
  async removeShopping(id: string): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM shopping_entry WHERE id = ?', [id]);
  }
}
