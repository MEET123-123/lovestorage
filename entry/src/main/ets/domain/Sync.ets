import { Item, BatchRecord } from './Item';
export interface SyncDocument { item: Item; batches: BatchRecord[]; }
export interface RemoteSnapshot { id: string; version: number; payload: string; updatedAt: string; deletedAt?: string; }
export interface SyncWrite { expectedVersion?: number; payload: string; }
export interface SyncConflict { itemId: string; name: string; remoteVersion: number; payload: string; localUpdatedAt: number; }
export interface SyncResult { uploaded: number; downloaded: number; conflicts: number; }
