import { Item, InventoryBatch, BatchRecord } from '../domain/Item';
import { BatchLocalRepository, BatchUndo } from '../data/local/BatchLocalRepository';
export class BatchUseCase {
  private repository: BatchLocalRepository = new BatchLocalRepository();
  private token?: BatchUndo;
  async list(itemId: string): Promise<BatchRecord[]> { return this.repository.list(itemId); }
  async add(item: Item, batch: InventoryBatch): Promise<void> { await this.repository.add(item,batch); }
  async update(item:Item,id:string,batch:InventoryBatch):Promise<void> { await this.repository.update(item,id,batch);this.token=undefined; }
  async consume(item: Item, id: string, quantity: number, discarded: boolean): Promise<void> { this.token = await this.repository.consume(item,id,quantity,discarded); }
  async undo(): Promise<void> { const token = this.token; this.token = undefined; if (!token) throw new Error('没有可撤销的批次操作'); await this.repository.undo(token); }
}
