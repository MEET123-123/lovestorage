import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { BatchRecord, Item, InventoryBatch } from '../../domain/Item';
import { InventoryDomain } from '../../algorithm/InventoryDomain';
import { ExpiryService, ShelfLifeUnit } from '../../algorithm/ExpiryService';
import { AppDatabase } from './AppDatabase';
import { LocalEvents } from './LocalEvents';
export interface BatchUndo { itemId: string; recordId: string; batch: BatchRecord; itemVersion: number; }
export class BatchLocalRepository {
  async list(itemId: string = ''): Promise<BatchRecord[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM inventory_batch' + (itemId ? ' WHERE item_id=?' : '') + ' ORDER BY created_at,id', itemId ? [itemId] : []);
    const rows: BatchRecord[] = [];
    try { while (rs.goToNextRow()) {
      const value = JSON.parse(rs.getString(rs.getColumnIndex('payload'))) as InventoryBatch;
      rows.push({ id: rs.getString(0), itemId: rs.getString(1), quantity: value.quantity ?? 1, unit: value.unit,
        expiryDate: value.expiryDate, productionDate: value.productionDate, shelfLifeValue: value.shelfLifeValue, shelfLifeUnit: value.shelfLifeUnit,
        openedDate: value.openedDate, afterOpenValue: value.afterOpenValue, afterOpenUnit: value.afterOpenUnit, location: value.location,
        lifecycleStatus: rs.getString(rs.getColumnIndex('lifecycle_status')), createdAt: rs.getLong(rs.getColumnIndex('created_at')), updatedAt: rs.getLong(rs.getColumnIndex('updated_at')) });
    }} finally { rs.close(); }
    return rows;
  }
  static expiry(batch: BatchRecord): string {
    return new ExpiryService().effectiveExpiryDate(batch.expiryDate,batch.openedDate,batch.afterOpenValue,batch.afterOpenUnit as ShelfLifeUnit | undefined) ?? '9999-12-31';
  }
  async add(item: Item, value: InventoryBatch, draftId: string = ''): Promise<void> {
    const candidate: Item = { id: item.id, name: item.name, categoryId: item.categoryId, lifecycleStatus: 'ACTIVE', createdAt: item.createdAt,
      updatedAt: item.updatedAt, quantity: value.quantity, unit: value.unit, expiryDate: value.expiryDate, productionDate: value.productionDate,
      openedDate: value.openedDate, afterOpenValue: value.afterOpenValue, afterOpenUnit: value.afterOpenUnit,
      shelfLifeValue:value.shelfLifeValue,shelfLifeUnit:value.shelfLifeUnit,location:value.location };
    const error = InventoryDomain.validate(candidate); if (error) throw new Error(error);
    if ((value.unit ?? '件') !== (item.unit ?? '件')) throw new Error('同一物品批次需使用相同计量单位');
    const store = await AppDatabase.getStore(); const now = Math.max(Date.now(),item.updatedAt+1); const id = util.generateRandomUUID();
    store.beginTransaction();
    try {
      const changed = await store.update({updated_at:now,pending:1,lifecycle_status:'ACTIVE'},new relationalStore.RdbPredicates('item').equalTo('id',item.id).equalTo('updated_at',item.updatedAt));
      if (changed !== 1) throw new Error('物品已更新，请刷新后添加批次');
      await store.executeSql('INSERT INTO inventory_batch(id,item_id,payload,lifecycle_status,created_at,updated_at) VALUES (?,?,?,?,?,?)',
        [id,item.id,JSON.stringify(value),'ACTIVE',now,now]);
      await LocalEvents.append(store,'ITEM_CREATED',item.id,id,value.quantity);
      if(draftId) {
        await store.executeSql("UPDATE item_draft SET state='SAVED' WHERE id=? AND state='DRAFT'",[draftId]);
        await LocalEvents.append(store,'DRAFT_SAVED',item.id,id);
      }
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async consume(item: Item, id: string, quantity: number, discarded: boolean = false): Promise<BatchUndo> {
    const batches = await this.list(item.id); const batch = batches.find((b: BatchRecord) => b.id === id);
    if (!batch || batch.lifecycleStatus !== 'ACTIVE' || item.lifecycleStatus !== 'ACTIVE') throw new Error('批次已处理');
    if (!Number.isFinite(quantity) || quantity <= 0 || quantity > batch.quantity || Math.abs(quantity*1000-Math.round(quantity*1000)) > 0.00001) throw new Error('处理数量必须大于 0、不超过余量，最多 3 位小数');
    const next = JSON.parse(JSON.stringify(batch)) as BatchRecord; next.quantity = Math.round((batch.quantity-quantity)*1000)/1000;
    next.lifecycleStatus = next.quantity === 0 ? (discarded ? 'DISCARDED' : 'CONSUMED') : 'ACTIVE';
    const now = Math.max(Date.now(),item.updatedAt+1); next.updatedAt = now;
    const active = batches.some((b: BatchRecord) => b.id !== id && b.lifecycleStatus === 'ACTIVE' && b.quantity > 0) || next.quantity > 0;
    const store = await AppDatabase.getStore(); const recordId = util.generateRandomUUID();
    store.beginTransaction();
    try {
      const changed = await store.update({updated_at:now,pending:1,lifecycle_status:active?'ACTIVE':next.lifecycleStatus},new relationalStore.RdbPredicates('item').equalTo('id',item.id).equalTo('updated_at',item.updatedAt));
      if (changed !== 1) throw new Error('物品已修改，请刷新后重试');
      await store.executeSql('UPDATE inventory_batch SET payload=?,lifecycle_status=?,updated_at=? WHERE id=?',[JSON.stringify(next),next.lifecycleStatus,now,id]);
      const action = discarded ? 'DISCARDED' : next.quantity > 0 ? 'PARTIAL_CONSUMED' : 'CONSUMED';
      await store.executeSql('INSERT INTO consumption_record(id,item_id,name,action,quantity,created_at,batch_id,batch_snapshot) VALUES (?,?,?,?,?,?,?,?)',
        [recordId,item.id,item.name,action,quantity,now,id,JSON.stringify([batch])]);
      await LocalEvents.append(store,discarded?'ITEM_DISCARDED':active?'ITEM_PARTIAL_CONSUMED':'ITEM_CONSUMED',item.id,id,quantity);
      store.commit();
      return { itemId:item.id, recordId, batch, itemVersion:now };
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
  async update(item: Item,id: string,value: InventoryBatch): Promise<void> {
    const batch=(await this.list(item.id)).find((b:BatchRecord)=>b.id===id);
    if(!batch || batch.lifecycleStatus!=='ACTIVE' || item.lifecycleStatus!=='ACTIVE') throw new Error('只能编辑在库批次');
    const candidate:Item={id:item.id,name:item.name,categoryId:item.categoryId,lifecycleStatus:item.lifecycleStatus,createdAt:item.createdAt,updatedAt:item.updatedAt,
      quantity:value.quantity,unit:value.unit,expiryDate:value.expiryDate,productionDate:value.productionDate,shelfLifeValue:value.shelfLifeValue,shelfLifeUnit:value.shelfLifeUnit,
      openedDate:value.openedDate,afterOpenValue:value.afterOpenValue,afterOpenUnit:value.afterOpenUnit,location:value.location};
    const error=InventoryDomain.validate(candidate);if(error)throw new Error(error);
    if((value.unit??'件')!==(item.unit??'件'))throw new Error('批次单位必须与物品一致');
    const store=await AppDatabase.getStore(),now=Math.max(Date.now(),item.updatedAt+1);
    store.beginTransaction();
    try {
      const changed=await store.update({updated_at:now,pending:1},new relationalStore.RdbPredicates('item').equalTo('id',item.id).equalTo('updated_at',item.updatedAt));
      if(changed!==1)throw new Error('库存已变化，请刷新后编辑');
      await store.executeSql('UPDATE inventory_batch SET payload=?,updated_at=? WHERE id=?',[JSON.stringify(value),now,id]);
      await LocalEvents.append(store,'ITEM_UPDATED',item.id,id);store.commit();
    } catch(error) {store.rollBack();throw new Error(String(error));}
  }
  async undo(token: BatchUndo): Promise<void> {
    const store = await AppDatabase.getStore(); const now = Math.max(Date.now(),token.itemVersion+1);
    store.beginTransaction();
    try {
      const changed = await store.update({updated_at:now,pending:1,lifecycle_status:'ACTIVE'},new relationalStore.RdbPredicates('item').equalTo('id',token.itemId).equalTo('updated_at',token.itemVersion));
      if (changed !== 1) throw new Error('物品已再次修改，不能覆盖后续操作');
      await store.executeSql('UPDATE inventory_batch SET payload=?,lifecycle_status=?,updated_at=? WHERE id=?',[JSON.stringify(token.batch),token.batch.lifecycleStatus,now,token.batch.id]);
      await store.executeSql('UPDATE consumption_record SET revoked=1 WHERE id=?',[token.recordId]);
      await LocalEvents.append(store,'ITEM_UPDATED',token.itemId,token.batch.id);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }
}
