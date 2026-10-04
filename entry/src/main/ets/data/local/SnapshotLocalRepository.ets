import { AppDatabase } from './AppDatabase';
import { Item, ItemMetadata, BatchRecord } from '../../domain/Item';
import { RemoteSnapshot, SyncDocument, SyncConflict } from '../../domain/Sync';
import { InventoryDomain } from '../../algorithm/InventoryDomain';

export class SnapshotLocalRepository {
  async conflict(item: Item, remote: RemoteSnapshot): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('INSERT OR REPLACE INTO sync_conflict(item_id,remote_version,payload,local_updated_at) VALUES (?,?,?,?)',[item.id,remote.version,remote.payload,item.updatedAt]);
  }
  async conflicts(): Promise<SyncConflict[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT c.*,i.name FROM sync_conflict c JOIN item i ON i.id=c.item_id');
    const rows: SyncConflict[] = [];
    try { while (rs.goToNextRow()) rows.push({ itemId:rs.getString(0),remoteVersion:rs.getLong(1),payload:rs.getString(2),localUpdatedAt:rs.getLong(3),name:rs.getString(4) }); }
    finally { rs.close(); }
    return rows;
  }
  async clearConflict(id: string): Promise<void> { await (await AppDatabase.getStore()).executeSql('DELETE FROM sync_conflict WHERE item_id=?',[id]); }
  async apply(remote: RemoteSnapshot, local?: Item): Promise<void> {
    const doc = JSON.parse(remote.payload) as SyncDocument;
    if (!doc.item || !Array.isArray(doc.batches) || !doc.batches.length || doc.batches.length > 1000) throw new Error('云端批次格式无效');
    const item = doc.item; const id = local?.id ?? remote.id;
    const batchIds: string[] = [];
    for (const batch of doc.batches) {
      if (!batch.id || batchIds.includes(batch.id) || !Number.isFinite(batch.quantity) || batch.quantity < 0
        || !['ACTIVE','CONSUMED','DISCARDED','ARCHIVED'].includes(batch.lifecycleStatus)) throw new Error('云端批次字段无效');
      const check = JSON.parse(JSON.stringify(item)) as Item;
      check.expiryDate = batch.expiryDate; check.openedDate = batch.openedDate; check.afterOpenValue = batch.afterOpenValue;
      check.afterOpenUnit = batch.afterOpenUnit; check.quantity = Math.max(1,batch.quantity);
      if (InventoryDomain.validate(check)) throw new Error('云端批次未通过业务校验');
      batchIds.push(batch.id);
    }
    const meta: ItemMetadata = { sourceMode:item.sourceMode,brand:item.brand, notes:item.notes, reminderDays:item.reminderDays, snoozeUntil:item.snoozeUntil };
    const now = Math.max(Date.now(),(local?.updatedAt ?? 0)+1); const store = await AppDatabase.getStore();
    store.beginTransaction();
    try {
      if (local) {
        const rs = await store.querySql('SELECT updated_at FROM item WHERE id=?',[local.id]);
        try { if (!rs.goToFirstRow() || rs.getLong(0)!==local.updatedAt) throw new Error('本地物品已变化，请重新同步'); } finally { rs.close(); }
      }
      if (local) await store.executeSql('UPDATE item SET name=?,category_id=?,expiry_date=?,lifecycle_status=?,updated_at=?,deleted_at=?,pending=0,remote_id=?,metadata=?,remote_version=? WHERE id=?',
        [item.name,item.categoryId,doc.batches[0].expiryDate ?? null,item.lifecycleStatus,now,item.deletedAt ?? null,remote.id,JSON.stringify(meta),remote.version,id]);
      else await store.executeSql('INSERT INTO item(id,name,category_id,expiry_date,lifecycle_status,created_at,updated_at,deleted_at,pending,remote_id,metadata,remote_version) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [id,item.name,item.categoryId,doc.batches[0].expiryDate ?? null,item.lifecycleStatus,item.createdAt,now,item.deletedAt ?? null,0,remote.id,JSON.stringify(meta),remote.version]);
      await store.executeSql('DELETE FROM inventory_batch WHERE item_id=?',[id]);
      for (const batch of doc.batches) {
        batch.itemId = id;
        await store.executeSql('INSERT INTO inventory_batch(id,item_id,payload,lifecycle_status,created_at,updated_at) VALUES (?,?,?,?,?,?)',
          [batch.id,id,JSON.stringify(batch),batch.lifecycleStatus,batch.createdAt,batch.updatedAt]);
      }
      await store.executeSql('DELETE FROM sync_conflict WHERE item_id=?',[id]);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
}
