import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Item } from '../../domain/Item';
import { AppDatabase } from './AppDatabase';

export class ItemLocalRepository {
  async create(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = {
      id: item.id, name: item.name, category_id: item.categoryId,
      expiry_date: item.expiryDate ?? null, lifecycle_status: item.lifecycleStatus,
      created_at: item.createdAt, updated_at: item.updatedAt, deleted_at: item.deletedAt ?? null,
      pending: 1, remote_id: util.generateRandomUUID()
    };
    await store.insert('item', values);
  }

  async listActive(): Promise<Item[]> { return this.query(false); }
  async listPending(): Promise<Item[]> { return this.query(true); }

  private async query(pending: boolean): Promise<Item[]> {
    const store = await AppDatabase.getStore();
    const result = await store.querySql('SELECT * FROM item WHERE ' +
      (pending ? 'pending = 1' : 'deleted_at IS NULL') + ' ORDER BY updated_at DESC');
    const items: Item[] = [];
    try {
      while (result.goToNextRow()) {
        const expiryIndex = result.getColumnIndex('expiry_date');
        const deletedIndex = result.getColumnIndex('deleted_at');
        const remoteIndex = result.getColumnIndex('remote_id');
        items.push({
          id: result.getString(result.getColumnIndex('id')),
          name: result.getString(result.getColumnIndex('name')),
          categoryId: result.getString(result.getColumnIndex('category_id')),
          expiryDate: result.isColumnNull(expiryIndex) ? undefined : result.getString(expiryIndex),
          lifecycleStatus: result.getString(result.getColumnIndex('lifecycle_status')),
          createdAt: result.getLong(result.getColumnIndex('created_at')),
          updatedAt: result.getLong(result.getColumnIndex('updated_at')),
          deletedAt: result.isColumnNull(deletedIndex) ? undefined : result.getLong(deletedIndex),
          remoteId: result.isColumnNull(remoteIndex) ? undefined : result.getString(remoteIndex),
          pending: result.getLong(result.getColumnIndex('pending'))
        });
      }
    } finally { result.close(); }
    return items;
  }

  async update(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = {
      name: item.name, category_id: item.categoryId, expiry_date: item.expiryDate ?? null,
      lifecycle_status: item.lifecycleStatus, updated_at: Date.now(), pending: 1
    };
    await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id));
  }

  async softDelete(id: string): Promise<void> {
    const store = await AppDatabase.getStore();
    const now = Date.now();
    const values: relationalStore.ValuesBucket = { deleted_at: now, updated_at: now, pending: 1 };
    await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', id));
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
    await store.update(values, new relationalStore.RdbPredicates('item')
      .equalTo('id', item.id).equalTo('updated_at', item.updatedAt));
  }

  async getServer(): Promise<string> {
    const store = await AppDatabase.getStore();
    const result = await store.querySql("SELECT value FROM setting WHERE key = 'server'");
    try { return result.goToFirstRow() ? result.getString(0) : ''; }
    finally { result.close(); }
  }

  async setServer(url: string): Promise<void> {
    const store = await AppDatabase.getStore();
    const previous = await this.getServer();
    if (previous !== '' && previous !== url) {
      await store.executeSql('UPDATE item SET pending = 1');
    }
    await store.executeSql("INSERT OR REPLACE INTO setting (key, value) VALUES ('server', ?)", [url]);
  }
}
