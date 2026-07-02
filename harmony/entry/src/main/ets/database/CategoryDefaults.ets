import { CategoryType } from '../models/Category';

export interface SeedCategory {
  name: string;
  type: CategoryType;
  sortOrder: number;
}

/** 系统默认收入分类（不含退票） */
export const DEFAULT_INCOME_CATEGORY_NAMES: string[] = [
  '工资', '兼职', '理财', '礼金', '其它'
];

/** 系统默认支出分类 */
export const DEFAULT_EXPENSE_CATEGORY_NAMES: string[] = [
  '餐饮', '购物', '日用', '交通', '蔬菜', '水果', '零食', '运动', '娱乐', '通讯',
  '服饰', '美容', '住房', '居家', '孩子', '长辈', '社交', '旅行', '烟酒', '数码',
  '汽车', '医疗', '书籍', '学习', '宠物', '礼金', '礼物', '办公', '维修', '捐赠',
  '彩票', '亲友', '快递', '其他'
];

/** v3 及更早版本的系统分类，升级后若无交易引用则移除 */
export const LEGACY_SYSTEM_CATEGORY_NAMES: string[] = [
  '奖金', '其他收入', '其他支出'
];

export const DEFAULT_FALLBACK_INCOME: string = '其它';
export const DEFAULT_FALLBACK_EXPENSE: string = '其他';

function buildSeeds(names: string[], type: CategoryType): SeedCategory[] {
  const seeds: SeedCategory[] = [];
  for (let i = 0; i < names.length; i++) {
    seeds.push({ name: names[i], type: type, sortOrder: i + 1 });
  }
  return seeds;
}

export const DEFAULT_CATEGORIES: SeedCategory[] = [
  ...buildSeeds(DEFAULT_INCOME_CATEGORY_NAMES, 'income'),
  ...buildSeeds(DEFAULT_EXPENSE_CATEGORY_NAMES, 'expense')
];

/** 供 RdbHelper v2 迁移标记 is_system 使用（含历史分类） */
export function getAllKnownSystemCategorySeeds(): string[][] {
  const pairs: string[][] = [];
  for (const item of DEFAULT_CATEGORIES) {
    pairs.push([item.name, item.type]);
  }
  pairs.push(['奖金', 'income']);
  pairs.push(['其他收入', 'income']);
  pairs.push(['其他支出', 'expense']);
  return pairs;
}

export function getDefaultCategoryName(type: CategoryType): string {
  return type === 'income' ? DEFAULT_FALLBACK_INCOME : DEFAULT_FALLBACK_EXPENSE;
}

/** 将导入/OCR 中的旧分类名或未知名解析为当前系统分类名 */
export function resolveImportCategoryName(name: string, type: CategoryType): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    return getDefaultCategoryName(type);
  }
  if (type === 'income') {
    if (trimmed === '其他收入' || trimmed === '奖金') {
      return DEFAULT_FALLBACK_INCOME;
    }
    for (let i = 0; i < DEFAULT_INCOME_CATEGORY_NAMES.length; i++) {
      if (DEFAULT_INCOME_CATEGORY_NAMES[i] === trimmed) {
        return trimmed;
      }
    }
    return DEFAULT_FALLBACK_INCOME;
  }
  if (trimmed === '其他支出') {
    return DEFAULT_FALLBACK_EXPENSE;
  }
  for (let i = 0; i < DEFAULT_EXPENSE_CATEGORY_NAMES.length; i++) {
    if (DEFAULT_EXPENSE_CATEGORY_NAMES[i] === trimmed) {
      return trimmed;
    }
  }
  return DEFAULT_FALLBACK_EXPENSE;
}

export function isCurrentSystemCategoryName(name: string, type: CategoryType): boolean {
  const list = type === 'income' ? DEFAULT_INCOME_CATEGORY_NAMES : DEFAULT_EXPENSE_CATEGORY_NAMES;
  for (let i = 0; i < list.length; i++) {
    if (list[i] === name) {
      return true;
    }
  }
  return false;
}
