import { Item } from '../domain/Item';
import { SyncWrite, SyncDocument, RemoteSnapshot, SyncConflict, SyncResult } from '../domain/Sync';
import { ApiClient, ApiError } from '../data/remote/ApiClient';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';
import { BatchLocalRepository } from '../data/local/BatchLocalRepository';
import { SnapshotLocalRepository } from '../data/local/SnapshotLocalRepository';
import { LocalEvents, PendingEvent, EventProperties } from '../data/local/LocalEvents';

export class SyncUseCase {
  private repository: ItemLocalRepository = new ItemLocalRepository();
  private snapshots: SnapshotLocalRepository = new SnapshotLocalRepository();
  async conflicts(): Promise<SyncConflict[]> { return this.snapshots.conflicts(); }
  private async write(item: Item, version?: number): Promise<RemoteSnapshot> {
    const id = await this.repository.ensureRemoteId(item);
    const doc: SyncDocument = { item, batches:await new BatchLocalRepository().list(item.id) };
    const body: SyncWrite = { expectedVersion:version, payload:JSON.stringify(doc) };
    return ApiClient.syncPut(id,body);
  }
  async sync(): Promise<SyncResult> {
    const result: SyncResult = {uploaded:0,downloaded:0,conflicts:0};
    for (const item of await this.repository.listPending()) {
      try { const saved = await this.write(item,item.remoteVersion); await this.repository.acknowledge(item,saved.version); await this.snapshots.clearConflict(item.id); result.uploaded++; }
      catch (error) {
        if (error instanceof ApiError && error.status===409) {
          const remote = await ApiClient.syncGet(await this.repository.ensureRemoteId(item));
          await this.snapshots.conflict(item,remote); result.conflicts++; continue;
        }
        throw new Error(`部分同步完成：已上传 ${result.uploaded}，待重试；${String(error)}`);
      }
    }
    const local = (await this.repository.exportBackup()).items;
    for (const remote of await ApiClient.syncList()) {
      const item = local.find((i: Item) => i.remoteId===remote.id);
      if (item?.pending===1) continue;
      if (item && item.remoteVersion===remote.version) continue;
      await this.snapshots.apply(remote,item); result.downloaded++;
    }
    const queued = await LocalEvents.pending(); const sending: PendingEvent[] = [];
    for (const event of queued) {
      const item = local.find((i: Item) => i.id===event.properties.itemId);
      if (!item?.remoteId || item.pending===1) continue;
      const properties=JSON.parse(JSON.stringify(event.properties)) as EventProperties;
      properties.itemId=item.remoteId;
      sending.push({eventId:event.eventId,eventType:event.eventType,eventVersion:event.eventVersion,occurredAt:event.occurredAt,properties});
    }
    if (sending.length) { await ApiClient.sendEvents(sending); await LocalEvents.acknowledge(sending); }
    return result;
  }
  async resolve(conflict: SyncConflict, keepLocal: boolean): Promise<void> {
    const item = (await this.repository.exportBackup()).items.find((i: Item) => i.id===conflict.itemId);
    if (!item || !item.remoteId || item.updatedAt!==conflict.localUpdatedAt) throw new Error('冲突后本地又有修改，请重新同步');
    if (keepLocal) {
      const saved = await this.write(item,conflict.remoteVersion);
      await this.repository.acknowledge(item,saved.version); await this.snapshots.clearConflict(item.id);
    } else {
      const remote = await ApiClient.syncGet(item.remoteId);
      if (remote.version!==conflict.remoteVersion) throw new Error('云端已再次变化，请重新同步');
      await this.snapshots.apply(remote,item);
    }
  }
}
