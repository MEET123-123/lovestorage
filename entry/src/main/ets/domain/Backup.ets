import { Item, BatchRecord, ConsumptionRecord, ShoppingEntry } from './Item';
export interface InventoryBackup {
  schemaVersion: number;
  items: Item[];
  records: ConsumptionRecord[];
  shopping: ShoppingEntry[];
  batches?: BatchRecord[];
}
