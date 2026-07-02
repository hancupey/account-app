import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

import {
  DEFAULT_CATEGORIES,
  getAllKnownSystemCategorySeeds,
  LEGACY_SYSTEM_CATEGORY_NAMES
} from './CategoryDefaults';
import { DB_NAME, DB_VERSION, INIT_SQLS, SQL_MIGRATE_V2_ADD_IS_SYSTEM, SQL_MIGRATE_V3_ADD_PAYEE } from './Schema';

export class RdbHelper {
  private static instance: RdbHelper;
  private store: relationalStore.RdbStore | null = null;
  private initPromise: Promise<void> | null = null;

  static getInstance(): RdbHelper {
    if (!RdbHelper.instance) {
      RdbHelper.instance = new RdbHelper();
    }
    return RdbHelper.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return;
    }
    if (this.initPromise !== null) {
      return this.initPromise;
    }
    this.initPromise = this.doInit(context);
    return this.initPromise;
  }

  private async doInit(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.migrate();
  }

  private async migrate(): Promise<void> {
    const store = this.getStore();
    const currentVersion = store.version;
    if (currentVersion >= DB_VERSION) {
      return;
    }
    if (currentVersion === 0) {
      for (const sql of INIT_SQLS) {
        await store.executeSql(sql);
      }
    }
    if (currentVersion < 2) {
      if (currentVersion === 1) {
        await store.executeSql(SQL_MIGRATE_V2_ADD_IS_SYSTEM);
        await RdbHelper.markSystemCategories(store);
      }
      store.version = 2;
    }
    if (currentVersion < 3) {
      if (currentVersion >= 1) {
        await store.executeSql(SQL_MIGRATE_V3_ADD_PAYEE);
      }
      store.version = 3;
    }
    if (currentVersion < 4) {
      await RdbHelper.migrateSystemCategoriesV4(store);
      store.version = 4;
    }
    if (currentVersion < 5) {
      await RdbHelper.migrateSystemCategoriesV5(store);
      store.version = 5;
    }
  }

  private static async markSystemCategories(store: relationalStore.RdbStore): Promise<void> {
    const seeds = getAllKnownSystemCategorySeeds();
    for (let i = 0; i < seeds.length; i++) {
      const seed = seeds[i];
      await store.executeSql(
        'UPDATE categories SET is_system = 1 WHERE name = ? AND type = ?',
        [seed[0], seed[1]]
      );
    }
  }

  /**
   * v4：插入新系统分类；有交易引用的旧系统分类降级为普通分类，无引用则删除。
   */
  private static async migrateSystemCategoriesV4(store: relationalStore.RdbStore): Promise<void> {
    for (let i = 0; i < DEFAULT_CATEGORIES.length; i++) {
      const seed = DEFAULT_CATEGORIES[i];
      const resultSet = await store.querySql(
        'SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1',
        [seed.name, seed.type]
      );
      let existingId = 0;
      if (resultSet.goToFirstRow()) {
        existingId = resultSet.getLong(resultSet.getColumnIndex('id'));
      }
      resultSet.close();
      if (existingId === 0) {
        await store.insert('categories', {
          'name': seed.name,
          'type': seed.type,
          'sort_order': seed.sortOrder,
          'is_system': 1
        });
      } else {
        await store.executeSql(
          'UPDATE categories SET sort_order = ?, is_system = 1 WHERE id = ?',
          [seed.sortOrder, existingId]
        );
      }
    }
    await RdbHelper.cleanupLegacySystemCategories(store);
  }

  /**
   * v5：同步含「其他」在内的最新系统分类；将旧「其他收入/其他支出」引用合并到「其它/其他」。
   */
  private static async migrateSystemCategoriesV5(store: relationalStore.RdbStore): Promise<void> {
    for (let i = 0; i < DEFAULT_CATEGORIES.length; i++) {
      const seed = DEFAULT_CATEGORIES[i];
      const resultSet = await store.querySql(
        'SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1',
        [seed.name, seed.type]
      );
      let existingId = 0;
      if (resultSet.goToFirstRow()) {
        existingId = resultSet.getLong(resultSet.getColumnIndex('id'));
      }
      resultSet.close();
      if (existingId === 0) {
        await store.insert('categories', {
          'name': seed.name,
          'type': seed.type,
          'sort_order': seed.sortOrder,
          'is_system': 1
        });
      } else {
        await store.executeSql(
          'UPDATE categories SET sort_order = ?, is_system = 1 WHERE id = ?',
          [seed.sortOrder, existingId]
        );
      }
    }
    await RdbHelper.mergeCategoryInto(store, '其他收入', 'income', '其它');
    await RdbHelper.mergeCategoryInto(store, '奖金', 'income', '其它');
    await RdbHelper.mergeCategoryInto(store, '其他支出', 'expense', '其他');
    await RdbHelper.cleanupLegacySystemCategories(store);
  }

  /** 将 fromName 的交易/预算引用迁移到 toName，然后删除 fromName 分类 */
  private static async mergeCategoryInto(
    store: relationalStore.RdbStore,
    fromName: string,
    type: string,
    toName: string
  ): Promise<void> {
    const fromId = await RdbHelper.findCategoryId(store, fromName, type);
    if (fromId === 0) {
      return;
    }
    const toId = await RdbHelper.findCategoryId(store, toName, type);
    if (toId === 0) {
      return;
    }
    if (fromId === toId) {
      return;
    }
    await store.executeSql(
      'UPDATE transactions SET category_id = ? WHERE category_id = ?',
      [toId, fromId]
    );
    await store.executeSql(
      'UPDATE budgets SET category_id = ? WHERE category_id = ?',
      [toId, fromId]
    );
    await store.executeSql('DELETE FROM categories WHERE id = ?', [fromId]);
  }

  private static async findCategoryId(
    store: relationalStore.RdbStore,
    name: string,
    type: string
  ): Promise<number> {
    const resultSet = await store.querySql(
      'SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1',
      [name, type]
    );
    let id = 0;
    if (resultSet.goToFirstRow()) {
      id = resultSet.getLong(resultSet.getColumnIndex('id'));
    }
    resultSet.close();
    return id;
  }

  private static async cleanupLegacySystemCategories(store: relationalStore.RdbStore): Promise<void> {
    for (let i = 0; i < LEGACY_SYSTEM_CATEGORY_NAMES.length; i++) {
      const name = LEGACY_SYSTEM_CATEGORY_NAMES[i];
      const type = name === '其他支出' ? 'expense' : 'income';
      const resultSet = await store.querySql(
        'SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1',
        [name, type]
      );
      if (!resultSet.goToFirstRow()) {
        resultSet.close();
        continue;
      }
      const categoryId = resultSet.getLong(resultSet.getColumnIndex('id'));
      resultSet.close();
      const txCount = await RdbHelper.countReferences(store, 'transactions', categoryId);
      const budgetCount = await RdbHelper.countReferences(store, 'budgets', categoryId);
      if (txCount > 0 || budgetCount > 0) {
        await store.executeSql('UPDATE categories SET is_system = 0 WHERE id = ?', [categoryId]);
      } else {
        await store.executeSql('DELETE FROM categories WHERE id = ?', [categoryId]);
      }
    }
  }

  private static async countReferences(
    store: relationalStore.RdbStore,
    table: string,
    categoryId: number
  ): Promise<number> {
    const resultSet = await store.querySql(
      `SELECT COUNT(*) AS cnt FROM ${table} WHERE category_id = ?`,
      [categoryId]
    );
    let count = 0;
    if (resultSet.goToFirstRow()) {
      count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
    }
    resultSet.close();
    return count;
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('RDB not initialized');
    }
    return this.store;
  }
}
