import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { InventoryBatch } from '../../domain/Item';

export class AppDatabase {
  private static context?: common.UIAbilityContext;
  private static store?: relationalStore.RdbStore;
  private static opening?: Promise<relationalStore.RdbStore>;
  private static readonly CONFIG: relationalStore.StoreConfig = {
    name: 'smart_expiry.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };

  static initialize(context: common.UIAbilityContext): void {
    AppDatabase.context = context;
  }

  static async switchAccount(userId: string = ''): Promise<void> {
    if (userId !== '' && !/^[a-f0-9-]{36}$/.test(userId)) throw new Error('账号标识无效');
    if (AppDatabase.opening !== undefined) await AppDatabase.opening;
    if (AppDatabase.store !== undefined) await AppDatabase.store.close();
    AppDatabase.store = undefined;
    AppDatabase.opening = undefined;
    const previous = AppDatabase.CONFIG.name;
    AppDatabase.CONFIG.name = userId === '' ? 'smart_expiry.db' : `account_${userId}.db`;
    try { await AppDatabase.getStore(); }
    catch (error) {
      AppDatabase.CONFIG.name = previous; AppDatabase.store = undefined; AppDatabase.opening = undefined;
      await AppDatabase.getStore();
      throw new Error(String(error));
    }
  }

  static async getStore(): Promise<relationalStore.RdbStore> {
    if (AppDatabase.store !== undefined) return AppDatabase.store;
    if (AppDatabase.opening === undefined) {
      AppDatabase.opening = AppDatabase.open();
    }
    try {
      return await AppDatabase.opening;
    } catch (error) {
      AppDatabase.opening = undefined;
      throw new Error(String(error));
    }
  }

  private static async open(): Promise<relationalStore.RdbStore> {
    if (AppDatabase.context === undefined) throw new Error('AppDatabase is not initialized');
    const store = await relationalStore.getRdbStore(AppDatabase.context, AppDatabase.CONFIG);
    await store.executeSql(`CREATE TABLE IF NOT EXISTS item (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category_id TEXT NOT NULL,
      expiry_date TEXT,
      lifecycle_status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )`);
    if (store.version < 1) {
      store.beginTransaction();
      try {
        await store.executeSql('ALTER TABLE item ADD COLUMN pending INTEGER NOT NULL DEFAULT 1');
        await store.executeSql('ALTER TABLE item ADD COLUMN remote_id TEXT');
        store.version = 1;
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error(String(error));
      }
    }
    await store.executeSql('CREATE TABLE IF NOT EXISTS setting (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    if (store.version < 2) {
      store.beginTransaction();
      try {
        await store.executeSql("ALTER TABLE item ADD COLUMN metadata TEXT NOT NULL DEFAULT '{}'");
        await store.executeSql('CREATE TABLE inventory_batch (id TEXT PRIMARY KEY, item_id TEXT NOT NULL UNIQUE REFERENCES item(id), payload TEXT NOT NULL)');
        const legacy = await store.querySql('SELECT id, expiry_date FROM item');
        try {
          while (legacy.goToNextRow()) {
            const id = legacy.getString(0);
            const batch: InventoryBatch = { expiryDate: legacy.isColumnNull(1) ? undefined : legacy.getString(1), quantity: 1, unit: '件' };
            await store.executeSql('INSERT INTO inventory_batch(id, item_id, payload) VALUES (?, ?, ?)', [id, id, JSON.stringify(batch)]);
          }
        } finally { legacy.close(); }
        await store.executeSql('CREATE TABLE consumption_record (id TEXT PRIMARY KEY, item_id TEXT NOT NULL, name TEXT NOT NULL, action TEXT NOT NULL, quantity REAL NOT NULL, created_at INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0)');
        await store.executeSql('CREATE TABLE shopping_entry (id TEXT PRIMARY KEY, name TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)');
        store.version = 2;
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error(String(error));
      }
    }
    if (store.version < 3) {
      store.beginTransaction();
      try {
        await store.executeSql('CREATE TABLE inventory_batch_v3 (id TEXT PRIMARY KEY, item_id TEXT NOT NULL REFERENCES item(id), payload TEXT NOT NULL, lifecycle_status TEXT NOT NULL DEFAULT \'ACTIVE\', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
        await store.executeSql('INSERT INTO inventory_batch_v3 SELECT b.id,b.item_id,b.payload,i.lifecycle_status,i.created_at,i.updated_at FROM inventory_batch b JOIN item i ON i.id=b.item_id');
        await store.executeSql('DROP TABLE inventory_batch');
        await store.executeSql('ALTER TABLE inventory_batch_v3 RENAME TO inventory_batch');
        await store.executeSql('CREATE INDEX idx_local_batch_item ON inventory_batch(item_id)');
        await store.executeSql('ALTER TABLE consumption_record ADD COLUMN batch_id TEXT');
        await store.executeSql('ALTER TABLE consumption_record ADD COLUMN batch_snapshot TEXT');
        await store.executeSql('CREATE TABLE local_event_outbox (event_id TEXT PRIMARY KEY,event_type TEXT NOT NULL,occurred_at INTEGER NOT NULL,properties TEXT NOT NULL,pending INTEGER NOT NULL DEFAULT 1)');
        await store.executeSql('CREATE TABLE item_draft (id TEXT PRIMARY KEY,payload TEXT NOT NULL,state TEXT NOT NULL DEFAULT \'DRAFT\',created_at INTEGER NOT NULL)');
        await store.executeSql('ALTER TABLE item ADD COLUMN remote_version INTEGER');
        await store.executeSql('CREATE TABLE sync_conflict (item_id TEXT PRIMARY KEY,remote_version INTEGER NOT NULL,payload TEXT NOT NULL,local_updated_at INTEGER NOT NULL)');
        store.version = 3;
        store.commit();
      } catch (error) { store.rollBack(); throw new Error(String(error)); }
    }
    if (store.version < 4) {
      store.beginTransaction();
      try {
        await store.executeSql('CREATE TABLE algorithm_decision (id TEXT PRIMARY KEY,decision_key TEXT NOT NULL UNIQUE,item_id TEXT NOT NULL,payload TEXT NOT NULL,created_at INTEGER NOT NULL,feedback TEXT,feedback_at INTEGER)');
        store.version=4; store.commit();
      } catch(error) { store.rollBack(); throw new Error(String(error)); }
    }
    AppDatabase.store = store;
    return store;
  }
}
