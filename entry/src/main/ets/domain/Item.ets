export interface Item {
  id: string;
  name: string;
  categoryId: string;
  expiryDate?: string;
  lifecycleStatus: string;
  createdAt: number;
  updatedAt: number;
  deletedAt?: number;
  pending?: number;
  remoteId?: string;
  brand?: string;
  quantity?: number;
  unit?: string;
  productionDate?: string;
  shelfLifeValue?: number;
  shelfLifeUnit?: string;
  openedDate?: string;
  afterOpenValue?: number;
  afterOpenUnit?: string;
  location?: string;
  notes?: string;
  reminderDays?: number;
  snoozeUntil?: string;
  primaryBatchId?: string;
  remoteVersion?: number;
  sourceMode?: string;
}

// Separate batch storage; the current editor exposes one batch per item.
export interface InventoryBatch {
  expiryDate?: string;
  quantity?: number;
  unit?: string;
  productionDate?: string;
  shelfLifeValue?: number;
  shelfLifeUnit?: string;
  openedDate?: string;
  afterOpenValue?: number;
  afterOpenUnit?: string;
  location?: string;
}

export interface BatchRecord extends InventoryBatch {
  id: string;
  itemId: string;
  quantity: number;
  lifecycleStatus: string;
  createdAt: number;
  updatedAt: number;
}

export interface ItemMetadata {
  sourceMode?: string;
  brand?: string;
  notes?: string;
  reminderDays?: number;
  snoozeUntil?: string;
}

export interface ConsumptionRecord {
  id: string;
  itemId: string;
  name: string;
  action: string;
  quantity: number;
  createdAt: number;
  revoked: number;
  batchId?: string;
  batchSnapshot?: string;
}

export interface ShoppingEntry {
  id: string;
  name: string;
  done: number;
  createdAt: number;
}
