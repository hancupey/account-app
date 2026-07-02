import { relationalStore } from '@kit.ArkData';

import { Category, CategoryType } from '../models/Category';
import { CategorySortOrder } from '../models/CategorySortOrder';

import { DEFAULT_CATEGORIES } from './CategoryDefaults';
import { RdbHelper } from './RdbHelper';

interface CategoryMerge {
  dupId: number;
  keeperId: number;
}

export class CategoryRepository {
  private static ensurePromise: Promise<void> | null = null;
  private static defaultsEnsured: boolean = false;

  async ensureDefaults(): Promise<void> {
    if (CategoryRepository.defaultsEnsured) {
      return;
    }
    if (CategoryRepository.ensurePromise !== null) {
      return CategoryRepository.ensurePromise;
    }
    CategoryRepository.ensurePromise = this.doEnsureDefaults();
    return CategoryRepository.ensurePromise;
  }

  private async doEnsureDefaults(): Promise<void> {
    await this.dedupeExisting();
    await this.syncSystemCategories();
    CategoryRepository.defaultsEnsured = true;
  }

  /** 幂等：插入缺失的系统分类，并校正 sort_order / is_system */
  async syncSystemCategories(): Promise<void> {
    const store = RdbHelper.getInstance().getStore();
    for (let i = 0; i < DEFAULT_CATEGORIES.length; i++) {
      const item = DEFAULT_CATEGORIES[i];
      const existing = await this.findByNameAndType(item.name, item.type);
      if (existing === null) {
        const bucket: relationalStore.ValuesBucket = {
          'name': item.name,
          'type': item.type,
          'sort_order': item.sortOrder,
          'is_system': 1
        };
        await store.insert('categories', bucket);
      } else {
        const bucket: relationalStore.ValuesBucket = {
          'is_system': 1
        };
        const predicates = new relationalStore.RdbPredicates('categories');
        predicates.equalTo('id', existing.id);
        await store.update(bucket, predicates);
      }
    }
  }

  private async dedupeExisting(): Promise<void> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.orderByAsc('id');
    const resultSet = await store.query(predicates);
    const keeperByKey = new Map<string, number>();
    const merges: CategoryMerge[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        const category = CategoryRepository.readRow(resultSet);
        const key = `${category.type}:${category.name}`;
        const keeperId = keeperByKey.get(key);
        if (keeperId === undefined) {
          keeperByKey.set(key, category.id);
        } else {
          merges.push({ dupId: category.id, keeperId: keeperId });
        }
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    for (let i = 0; i < merges.length; i++) {
      const merge = merges[i];
      await store.executeSql(
        'UPDATE transactions SET category_id = ? WHERE category_id = ?',
        [merge.keeperId, merge.dupId]
      );
      await store.executeSql(
        'UPDATE budgets SET category_id = ? WHERE category_id = ?',
        [merge.keeperId, merge.dupId]
      );
      const deletePredicates = new relationalStore.RdbPredicates('categories');
      deletePredicates.equalTo('id', merge.dupId);
      await store.delete(deletePredicates);
    }
  }

  async listByType(type: CategoryType): Promise<Category[]> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('type', type).orderByAsc('sort_order');
    const resultSet = await store.query(predicates);
    const list: Category[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        list.push(CategoryRepository.readRow(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return list;
  }

  async listAll(): Promise<Category[]> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.orderByAsc('type').orderByAsc('sort_order');
    const resultSet = await store.query(predicates);
    const list: Category[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        list.push(CategoryRepository.readRow(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return list;
  }

  async getAll(): Promise<Category[]> {
    return this.listAll();
  }

  async getById(id: number): Promise<Category | null> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    const resultSet = await store.query(predicates);
    let category: Category | null = null;
    if (resultSet.goToFirstRow()) {
      category = CategoryRepository.readRow(resultSet);
    }
    resultSet.close();
    return category;
  }

  async insertCustom(name: string, type: CategoryType): Promise<number> {
    const trimmed = name.trim();
    if (trimmed.length === 0) {
      throw new Error('Category name is required');
    }
    const existing = await this.findByNameAndType(trimmed, type);
    if (existing !== null) {
      throw new Error('Category already exists');
    }
    const sortOrder = await this.nextSortOrder(type);
    const store = RdbHelper.getInstance().getStore();
    const bucket: relationalStore.ValuesBucket = {
      'name': trimmed,
      'type': type,
      'sort_order': sortOrder,
      'is_system': 0
    };
    return store.insert('categories', bucket);
  }

  async update(id: number, name: string): Promise<void> {
    const category = await this.getById(id);
    if (category === null) {
      throw new Error('Category not found');
    }
    if (category.isSystem) {
      throw new Error('Cannot edit system category');
    }
    const trimmed = name.trim();
    if (trimmed.length === 0) {
      throw new Error('Category name is required');
    }
    const duplicate = await this.findByNameAndType(trimmed, category.type);
    if (duplicate !== null && duplicate.id !== id) {
      throw new Error('Category already exists');
    }
    const store = RdbHelper.getInstance().getStore();
    const bucket: relationalStore.ValuesBucket = {
      'name': trimmed
    };
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
  }

  async updateSortOrders(orders: CategorySortOrder[]): Promise<void> {
    if (orders.length === 0) {
      return;
    }
    const store = RdbHelper.getInstance().getStore();
    for (let i = 0; i < orders.length; i++) {
      const item = orders[i];
      const bucket: relationalStore.ValuesBucket = {
        'sort_order': item.sortOrder
      };
      const predicates = new relationalStore.RdbPredicates('categories');
      predicates.equalTo('id', item.id);
      await store.update(bucket, predicates);
    }
  }

  async delete(id: number): Promise<void> {
    const category = await this.getById(id);
    if (category === null) {
      throw new Error('Category not found');
    }
    if (category.isSystem) {
      throw new Error('Cannot delete system category');
    }
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  async findByNameAndType(name: string, type: CategoryType): Promise<Category | null> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('name', name).equalTo('type', type);
    const resultSet = await store.query(predicates);
    let category: Category | null = null;
    if (resultSet.goToFirstRow()) {
      category = CategoryRepository.readRow(resultSet);
    }
    resultSet.close();
    return category;
  }

  private async nextSortOrder(type: CategoryType): Promise<number> {
    const list = await this.listByType(type);
    if (list.length === 0) {
      return 1;
    }
    let maxOrder = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].sortOrder > maxOrder) {
        maxOrder = list[i].sortOrder;
      }
    }
    return maxOrder + 1;
  }

  private static readRow(resultSet: relationalStore.ResultSet): Category {
    const category = new Category();
    category.id = resultSet.getLong(resultSet.getColumnIndex('id'));
    category.name = resultSet.getString(resultSet.getColumnIndex('name'));
    category.type = resultSet.getString(resultSet.getColumnIndex('type')) as CategoryType;
    const iconIndex = resultSet.getColumnIndex('icon');
    if (!resultSet.isColumnNull(iconIndex)) {
      category.icon = resultSet.getString(iconIndex);
    }
    category.sortOrder = resultSet.getLong(resultSet.getColumnIndex('sort_order'));
    const isSystemIndex = resultSet.getColumnIndex('is_system');
    if (isSystemIndex >= 0 && !resultSet.isColumnNull(isSystemIndex)) {
      category.isSystem = resultSet.getLong(isSystemIndex) === 1;
    }
    return category;
  }
}
