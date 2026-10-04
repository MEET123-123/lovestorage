import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Item, ItemMetadata, InventoryBatch, BatchRecord, ConsumptionRecord, ShoppingEntry } from '../../domain/Item';
import { BatchLocalRepository } from './BatchLocalRepository';
import { LocalEvents } from './LocalEvents';
import { AppDatabase } from './AppDatabase';
import { InventoryBackup } from '../../domain/Backup';
import { InventoryDomain } from '../../algorithm/InventoryDomain';

export class ItemLocalRepository {
  private metadata(item: Item): string {
    const value: ItemMetadata = { sourceMode:item.sourceMode,brand: item.brand, notes: item.notes, reminderDays: item.reminderDays, snoozeUntil: item.snoozeUntil };
    return JSON.stringify(value);
  }
  private batch(item: Item): string {
    const value: InventoryBatch = { expiryDate: item.expiryDate, quantity: item.quantity ?? 1, unit: item.unit ?? '件', productionDate: item.productionDate,
      shelfLifeValue: item.shelfLifeValue, shelfLifeUnit: item.shelfLifeUnit, openedDate: item.openedDate,
      afterOpenValue: item.afterOpenValue, afterOpenUnit: item.afterOpenUnit, location: item.location };
    return JSON.stringify(value);
  }
  async create(item: Item, draftId: string = ''): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = {
      id: item.id, name: item.name, category_id: item.categoryId, expiry_date: item.expiryDate ?? null,
      lifecycle_status: item.lifecycleStatus, created_at: item.createdAt, updated_at: item.updatedAt,
      deleted_at: null, pending: 1, remote_id: util.generateRandomUUID(), metadata: this.metadata(item)
    };
    store.beginTransaction();
    try {
      await store.insert('item', values);
      await store.executeSql('INSERT INTO inventory_batch (id, item_id, payload,lifecycle_status,created_at,updated_at) VALUES (?, ?, ?,?,?,?)',
        [item.id,item.id,this.batch(item),'ACTIVE',item.createdAt,item.updatedAt]);
      if (draftId) {
        await store.executeSql("UPDATE item_draft SET state='SAVED' WHERE id=? AND state='DRAFT'",[draftId]);
        await LocalEvents.append(store,'DRAFT_SAVED',item.id);
      }
      await LocalEvents.append(store,'ITEM_CREATED',item.id,item.id,item.quantity ?? 1);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async listActive(): Promise<Item[]> { return this.query(false); }
  async listPending(): Promise<Item[]> { return this.query(true); }
  private async query(pending: boolean, all: boolean = false): Promise<Item[]> {
    const store = await AppDatabase.getStore();
    const batches = await new BatchLocalRepository().list();
    const result = await store.querySql('SELECT i.* FROM item i WHERE ' +
      (all ? '1 = 1' : pending ? 'i.pending = 1' : 'i.deleted_at IS NULL') + ' ORDER BY i.updated_at DESC');
    const items: Item[] = [];
    try {
      while (result.goToNextRow()) {
        const expiryIndex = result.getColumnIndex('expiry_date');
        const deletedIndex = result.getColumnIndex('deleted_at');
        const remoteIndex = result.getColumnIndex('remote_id');
        const id = result.getString(result.getColumnIndex('id'));
        const related = batches.filter((b: BatchRecord) => b.itemId === id);
        const live = related.filter((b: BatchRecord) => b.lifecycleStatus === 'ACTIVE' && b.quantity > 0)
          .sort((a: BatchRecord,b: BatchRecord) => BatchLocalRepository.expiry(a).localeCompare(BatchLocalRepository.expiry(b)) || a.id.localeCompare(b.id));
        const meta = JSON.parse(result.getString(result.getColumnIndex('metadata'))) as ItemMetadata;
        const primary = live[0] ?? related[0];
        const batch: InventoryBatch = primary ?? {};
        items.push({
          id: result.getString(result.getColumnIndex('id')), name: result.getString(result.getColumnIndex('name')),
          categoryId: result.getString(result.getColumnIndex('category_id')),
          expiryDate: batch.expiryDate ?? (result.isColumnNull(expiryIndex) ? undefined : result.getString(expiryIndex)),
          lifecycleStatus: result.getString(result.getColumnIndex('lifecycle_status')),
          createdAt: result.getLong(result.getColumnIndex('created_at')), updatedAt: result.getLong(result.getColumnIndex('updated_at')),
          deletedAt: result.isColumnNull(deletedIndex) ? undefined : result.getLong(deletedIndex),
          remoteId: result.isColumnNull(remoteIndex) ? undefined : result.getString(remoteIndex), pending: result.getLong(result.getColumnIndex('pending')),
          sourceMode:meta.sourceMode,brand: meta.brand, notes: meta.notes, reminderDays: meta.reminderDays, snoozeUntil: meta.snoozeUntil,
          primaryBatchId: primary?.id,
          remoteVersion: result.isColumnNull(result.getColumnIndex('remote_version')) ? undefined : result.getLong(result.getColumnIndex('remote_version')),
          quantity: live.length ? Math.round(live.reduce((sum: number,b: BatchRecord) => sum+b.quantity,0)*1000)/1000 : batch.quantity ?? 1,
          unit: batch.unit ?? '件', productionDate: batch.productionDate,
          shelfLifeValue: batch.shelfLifeValue, shelfLifeUnit: batch.shelfLifeUnit, openedDate: batch.openedDate,
          afterOpenValue: batch.afterOpenValue, afterOpenUnit: batch.afterOpenUnit, location: batch.location
        });
      }
    } finally { result.close(); }
    return items;
  }
  async update(item: Item): Promise<void> {
    const store = await AppDatabase.getStore();
    const batches = await new BatchLocalRepository().list(item.id);
    const primary = batches.find((b: BatchRecord) => b.id === (item.primaryBatchId ?? item.id)) ?? batches[0];
    if (!primary) throw new Error('库存批次不存在');
    const live = batches.filter((b: BatchRecord) => b.lifecycleStatus === 'ACTIVE' && b.quantity > 0);
    const payloadItem = JSON.parse(JSON.stringify(item)) as Item;
    if (live.length > 1) {
      const total = Math.round(live.reduce((sum: number,b: BatchRecord) => sum+b.quantity,0)*1000)/1000;
      if (item.quantity !== total || item.unit !== primary.unit) throw new Error('多批次数量和单位请在批次管理中修改');
      payloadItem.quantity = primary.quantity;
    }
    const now = Math.max(Date.now(), item.updatedAt + 1);
    const values: relationalStore.ValuesBucket = {
      name: item.name, category_id: item.categoryId, expiry_date: item.expiryDate ?? null,
      lifecycle_status: item.lifecycleStatus, updated_at: now, pending: 1, metadata: this.metadata(item)
    };
    store.beginTransaction();
    try {
      const changed = await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id).equalTo('updated_at', item.updatedAt));
      if (changed !== 1) throw new Error('物品已修改，请刷新后重试');
      await store.executeSql('UPDATE inventory_batch SET payload = ?,updated_at=? WHERE id = ?', [this.batch(payloadItem),now,primary.id]);
      await LocalEvents.append(store,item.snoozeUntil !== undefined ? 'ITEM_SNOOZED' : 'ITEM_UPDATED',item.id,primary.id);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async transition(item: Item, status: string): Promise<void> {
    if (!['ACTIVE','CONSUMED','DISCARDED','ARCHIVED'].includes(status)) throw new Error('不支持的生命周期');
    if (status === item.lifecycleStatus) return;
    if (status !== 'ACTIVE' && item.lifecycleStatus !== 'ACTIVE') throw new Error('先恢复在库，再执行其他处理');
    const store = await AppDatabase.getStore();
    const batches = await new BatchLocalRepository().list(item.id);
    const touched = batches.filter((b: BatchRecord) => b.lifecycleStatus === 'ACTIVE' && b.quantity > 0);
    store.beginTransaction();
    try {
      const values: relationalStore.ValuesBucket = { lifecycle_status: status, updated_at: Math.max(Date.now(), item.updatedAt + 1), pending: 1 };
      const changed = await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id)
        .equalTo('updated_at', item.updatedAt).equalTo('lifecycle_status', item.lifecycleStatus));
      if (changed !== 1) throw new Error('物品已修改，请刷新后重试');
      if (status === 'ACTIVE') {
        const rs = await store.querySql("SELECT batch_snapshot,id FROM consumption_record WHERE item_id=? AND revoked=0 ORDER BY created_at DESC,rowid DESC LIMIT 1",[item.id]);
        let previous: BatchRecord[] = [];
        let recordId: string = "";
        try { if (rs.goToFirstRow()) { recordId=rs.getString(1); if (!rs.isColumnNull(0)) previous = JSON.parse(rs.getString(0)) as BatchRecord[]; } } finally { rs.close(); }
        if (item.lifecycleStatus !== 'ARCHIVED' && !previous.length) previous=batches.filter((b: BatchRecord)=>b.quantity>0 && b.lifecycleStatus===item.lifecycleStatus).map((b: BatchRecord)=> { const restored=JSON.parse(JSON.stringify(b)) as BatchRecord; restored.lifecycleStatus='ACTIVE'; return restored; });
        if (item.lifecycleStatus !== 'ARCHIVED' && !previous.length) throw new Error('缺少可恢复的批次数量');
        for (const batch of previous) await store.executeSql('UPDATE inventory_batch SET payload=?,lifecycle_status=?,updated_at=? WHERE id=?',
          [JSON.stringify(batch),batch.lifecycleStatus,values.updated_at as number,batch.id]);
        await store.executeSql('UPDATE consumption_record SET revoked = 1 WHERE id = ? AND revoked = 0', [recordId]);
      } else if (status === 'CONSUMED' || status === 'DISCARDED') {
        for (const batch of touched) await store.executeSql('UPDATE inventory_batch SET lifecycle_status=?,updated_at=? WHERE id=?',[status,values.updated_at as number,batch.id]);
        await store.executeSql('INSERT INTO consumption_record (id,item_id,name,action,quantity,created_at,batch_snapshot) VALUES (?,?,?,?,?,?,?)',
          [util.generateRandomUUID(),item.id,item.name,status,item.quantity ?? 1,Date.now(),JSON.stringify(touched)]);
      }
      await LocalEvents.append(store,status === 'CONSUMED' ? 'ITEM_CONSUMED' : status === 'DISCARDED' ? 'ITEM_DISCARDED' : 'ITEM_UPDATED',item.id);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async records(): Promise<ConsumptionRecord[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM consumption_record ORDER BY created_at DESC');
    const rows: ConsumptionRecord[] = [];
    try {
      while (rs.goToNextRow()) rows.push({ id: rs.getString(0), itemId: rs.getString(1), name: rs.getString(2), action: rs.getString(3),
        quantity: rs.getDouble(4), createdAt: rs.getLong(5), revoked: rs.getLong(6),
        batchId: rs.isColumnNull(7) ? undefined : rs.getString(7), batchSnapshot: rs.isColumnNull(8) ? undefined : rs.getString(8) });
    } finally { rs.close(); }
    return rows;
  }
  async softDelete(id: string): Promise<void> {
    const store = await AppDatabase.getStore();
    store.beginTransaction();
    try {
      await store.executeSql('UPDATE item SET deleted_at = ?, updated_at = MAX(updated_at + 1, ?), pending = 1 WHERE id = ?', [Date.now(), Date.now(), id]);
      await LocalEvents.append(store,'ITEM_DELETED',id); store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async ensureRemoteId(item: Item): Promise<string> {
    if (item.remoteId !== undefined) return item.remoteId;
    const id = util.generateRandomUUID();
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = { remote_id: id };
    await store.update(values, new relationalStore.RdbPredicates('item').equalTo('id', item.id));
    return id;
  }
  async acknowledge(item: Item, remoteVersion?: number): Promise<void> {
    const store = await AppDatabase.getStore();
    const values: relationalStore.ValuesBucket = { pending: 0, remote_version: remoteVersion ?? item.remoteVersion ?? null };
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
  async exportBackup(): Promise<InventoryBackup> {
    return { schemaVersion: 2, items: await this.query(false, true), batches: await new BatchLocalRepository().list(), records: await this.records(), shopping: await this.shopping() };
  }
  async restoreBackup(backup: InventoryBackup, revision: number): Promise<void> {
    if (![1,2].includes(backup.schemaVersion) || !Array.isArray(backup.items) || !Array.isArray(backup.records) || !Array.isArray(backup.shopping)
      || (backup.schemaVersion === 2 && !Array.isArray(backup.batches))) throw new Error('备份格式不支持');
    if (backup.items.length > 10000 || backup.records.length > 10000 || backup.shopping.length > 10000) throw new Error('备份记录过多');
    const local = await this.exportBackup();
    if (local.items.length || local.records.length || local.shopping.length) throw new Error('仅可恢复到空账号库存，现有数据不会被覆盖');
    const ids: string[] = [];
    for (const item of backup.items) {
      if (!item.id || ids.includes(item.id) || !Number.isFinite(item.createdAt) || !Number.isFinite(item.updatedAt)) throw new Error('备份物品标识或时间无效');
      const checked = JSON.parse(JSON.stringify(item)) as Item;
      if (checked.lifecycleStatus !== 'ACTIVE' && checked.quantity === 0) checked.quantity = 1;
      if (InventoryDomain.validate(checked)) throw new Error('备份物品字段无效');
      if (!['ACTIVE', 'CONSUMED', 'DISCARDED', 'ARCHIVED'].includes(item.lifecycleStatus)) throw new Error('备份状态无效');
      ids.push(item.id);
    }
    const store = await AppDatabase.getStore();
    store.beginTransaction();
    try {
      for (const item of backup.items) {
        const values: relationalStore.ValuesBucket = { id: item.id, name: item.name, category_id: item.categoryId, expiry_date: item.expiryDate ?? null,
          lifecycle_status: item.lifecycleStatus, created_at: item.createdAt, updated_at: item.updatedAt, deleted_at: item.deletedAt ?? null,
          pending: 1, remote_id: item.remoteId ?? util.generateRandomUUID(), metadata: this.metadata(item) };
        await store.insert('item', values);
        if (backup.schemaVersion === 1) await store.executeSql('INSERT INTO inventory_batch(id,item_id,payload,lifecycle_status,created_at,updated_at) VALUES (?,?,?,?,?,?)',
          [item.id,item.id,this.batch(item),item.lifecycleStatus,item.createdAt,item.updatedAt]);
      }
      if (backup.schemaVersion === 2) {
        const batchIds: string[] = [];
        for (const batch of backup.batches ?? []) {
          if (!batch.id || batchIds.includes(batch.id) || !ids.includes(batch.itemId) || !Number.isFinite(batch.quantity) || batch.quantity < 0 || batch.quantity > 999999999
            || !['ACTIVE','CONSUMED','DISCARDED','ARCHIVED'].includes(batch.lifecycleStatus) || !Number.isFinite(batch.createdAt) || !Number.isFinite(batch.updatedAt)
            || (batch.lifecycleStatus === 'ACTIVE' && batch.quantity === 0)) throw new Error('备份批次无效');
          const parent = backup.items.find((i: Item) => i.id === batch.itemId);
          if (!parent) throw new Error('备份批次缺少物品');
          const check = JSON.parse(JSON.stringify(parent)) as Item;
          check.expiryDate = batch.expiryDate; check.openedDate = batch.openedDate; check.afterOpenValue = batch.afterOpenValue;
          check.afterOpenUnit = batch.afterOpenUnit; check.quantity = Math.max(1,batch.quantity);
          if (InventoryDomain.validate(check)) throw new Error('备份批次日期无效');
          batchIds.push(batch.id);
          await store.executeSql('INSERT INTO inventory_batch(id,item_id,payload,lifecycle_status,created_at,updated_at) VALUES (?,?,?,?,?,?)',
            [batch.id,batch.itemId,JSON.stringify(batch),batch.lifecycleStatus,batch.createdAt,batch.updatedAt]);
        }
        if (backup.items.some((i: Item) => !(backup.batches ?? []).some((b: BatchRecord) => b.itemId === i.id))) throw new Error('备份物品缺少批次');
      }
      for (const record of backup.records) {
        if (!record.id || !ids.includes(record.itemId) || !['CONSUMED','DISCARDED','PARTIAL_CONSUMED'].includes(record.action) || !Number.isFinite(record.quantity) || record.quantity <= 0 || !Number.isFinite(record.createdAt) || ![0,1].includes(record.revoked)) throw new Error('备份流水无效');
        await store.executeSql('INSERT INTO consumption_record(id,item_id,name,action,quantity,created_at,revoked,batch_id,batch_snapshot) VALUES (?,?,?,?,?,?,?,?,?)', [record.id,record.itemId,record.name,record.action,record.quantity,record.createdAt,record.revoked,record.batchId ?? null,record.batchSnapshot ?? null]);
      }
      for (const entry of backup.shopping) {
        if (!entry.id || !entry.name || entry.name.length > 80 || ![0,1].includes(entry.done) || !Number.isFinite(entry.createdAt)) throw new Error('备份补货条目无效');
        await store.executeSql('INSERT INTO shopping_entry(id,name,done,created_at) VALUES (?,?,?,?)', [entry.id,entry.name,entry.done,entry.createdAt]);
      }
      await store.executeSql('INSERT OR REPLACE INTO setting(key,value) VALUES (?,?)', ['backup_revision',`${revision}`]);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async setServer(url: string): Promise<void> {
    const store = await AppDatabase.getStore();
    const previous = await this.getServer();
    store.beginTransaction();
    try {
      if (previous !== '' && previous !== url) {
        await store.executeSql('UPDATE item SET pending = 1,remote_version=NULL');
        await store.executeSql('DELETE FROM sync_conflict');
      }
      await this.setSetting('server', url);store.commit();
    } catch(error) {store.rollBack();throw new Error(String(error));}
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
