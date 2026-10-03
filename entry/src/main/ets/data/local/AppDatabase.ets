import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';

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
    AppDatabase.store = store;
    return store;
  }
}
