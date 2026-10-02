import { relationalStore } from '@kit.ArkData';
import { Item } from '../../domain/Item';
import { AppDatabase } from './AppDatabase';

export class ItemLocalRepository {
  async create(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = {
      id: item.id,
      name: item.name,
      category_id: item.categoryId,
      expiry_date: item.expiryDate ?? null,
      lifecycle_status: item.lifecycleStatus,
      created_at: item.createdAt,
      updated_at: item.updatedAt,
      deleted_at: item.deletedAt ?? null
    };
    await store.insert('item', values);
  }

  async listActive(): Promise<Item[]> {
    const store = await AppDatabase.getStore();
    const result = await store.querySql(
      'SELECT id, name, category_id, expiry_date, lifecycle_status, created_at, updated_at, deleted_at ' +
      'FROM item WHERE deleted_at IS NULL ORDER BY updated_at DESC'
    );
    const items: Item[] = [];
    while (result.goToNextRow()) {
      const expiry = result.getString(result.getColumnIndex('expiry_date'));
      items.push({
        id: result.getString(result.getColumnIndex('id')),
        name: result.getString(result.getColumnIndex('name')),
        categoryId: result.getString(result.getColumnIndex('category_id')),
        expiryDate: expiry.length > 0 ? expiry : undefined,
        lifecycleStatus: result.getString(result.getColumnIndex('lifecycle_status')),
        createdAt: result.getLong(result.getColumnIndex('created_at')),
        updatedAt: result.getLong(result.getColumnIndex('updated_at'))
      });
    }
    result.close();
    return items;
  }

  async updateName(id: string, name: string): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = { name, updated_at: Date.now() };
    const predicates = new relationalStore.RdbPredicates('item').equalTo('id', id);
    await store.update(values, predicates);
  }

  async softDelete(id: string): Promise<void> {
    const store = await AppDatabase.getStore();
    const now = Date.now();
    const values: relationalStore.ValuesBucket = { deleted_at: now, updated_at: now };
    const predicates = new relationalStore.RdbPredicates('item').equalTo('id', id);
    await store.update(values, predicates);
  }
}
