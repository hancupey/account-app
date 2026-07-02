import { describe, it, expect } from '@ohos/hypium';

import {
  DEFAULT_CATEGORIES,
  DEFAULT_EXPENSE_CATEGORY_NAMES,
  DEFAULT_FALLBACK_EXPENSE,
  DEFAULT_FALLBACK_INCOME,
  DEFAULT_INCOME_CATEGORY_NAMES,
  getDefaultCategoryName,
  resolveImportCategoryName
} from '../main/ets/database/CategoryDefaults';
import { AlipayFileParser } from '../main/ets/services/import/AlipayFileParser';
import { WechatFileParser } from '../main/ets/services/import/WechatFileParser';

export default function categoryDefaultsTest() {
  describe('CategoryDefaults', () => {
    it('incomeCategoryCount', 0, () => {
      expect(DEFAULT_INCOME_CATEGORY_NAMES.length).assertEqual(5);
    });

    it('expenseCategoryCount', 0, () => {
      expect(DEFAULT_EXPENSE_CATEGORY_NAMES.length).assertEqual(34);
    });

    it('defaultCategoriesTotal', 0, () => {
      expect(DEFAULT_CATEGORIES.length).assertEqual(39);
    });

    it('expenseFirstIs餐饮', 0, () => {
      expect(DEFAULT_EXPENSE_CATEGORY_NAMES[0]).assertEqual('餐饮');
      expect(DEFAULT_EXPENSE_CATEGORY_NAMES[32]).assertEqual('快递');
      expect(DEFAULT_EXPENSE_CATEGORY_NAMES[33]).assertEqual('其他');
    });

    it('incomeIncludes其它Not其他收入', 0, () => {
      expect(DEFAULT_INCOME_CATEGORY_NAMES[4]).assertEqual('其它');
    });

    it('defaultFallbackNames', 0, () => {
      expect(getDefaultCategoryName('income')).assertEqual(DEFAULT_FALLBACK_INCOME);
      expect(getDefaultCategoryName('expense')).assertEqual(DEFAULT_FALLBACK_EXPENSE);
    });

    it('resolveLegacyIncomeNames', 0, () => {
      expect(resolveImportCategoryName('其他收入', 'income')).assertEqual('其它');
      expect(resolveImportCategoryName('奖金', 'income')).assertEqual('其它');
    });

    it('resolveLegacyExpenseNames', 0, () => {
      expect(resolveImportCategoryName('其他支出', 'expense')).assertEqual('其他');
    });

    it('resolveEmptyToFallback', 0, () => {
      expect(resolveImportCategoryName('', 'income')).assertEqual('其它');
      expect(resolveImportCategoryName('', 'expense')).assertEqual('其他');
    });
  });

  describe('ImportParserMapCategory', () => {
    it('alipayIncomeMapsToNewCategories', 0, () => {
      expect(AlipayFileParser.mapCategory('工资', 'income')).assertEqual('工资');
      expect(AlipayFileParser.mapCategory('兼职', 'income')).assertEqual('兼职');
      expect(AlipayFileParser.mapCategory('理财收益', 'income')).assertEqual('理财');
      expect(AlipayFileParser.mapCategory('未知', 'income')).assertEqual('其它');
    });

    it('alipayExpenseMapsToNewCategories', 0, () => {
      expect(AlipayFileParser.mapCategory('餐饮美食', 'expense')).assertEqual('餐饮');
      expect(AlipayFileParser.mapCategory('日用百货', 'expense')).assertEqual('日用');
      expect(AlipayFileParser.mapCategory('交通出行', 'expense')).assertEqual('交通');
      expect(AlipayFileParser.mapCategory('公益捐赠', 'expense')).assertEqual('捐赠');
      expect(AlipayFileParser.mapCategory('未知', 'expense')).assertEqual('其他');
    });

    it('alipayIncomeCategoryForcesType', 0, () => {
      expect(AlipayFileParser.mapCategoryWithType('转账红包', 'expense')).assertEqual('income');
      expect(AlipayFileParser.mapCategoryWithType('退款', 'income')).assertEqual('expense');
    });

    it('wechatIncomeMapsToNewCategories', 0, () => {
      expect(WechatFileParser.mapCategory('微信红包', 'income')).assertEqual('礼金');
      expect(WechatFileParser.mapCategory('转账', 'income')).assertEqual('其它');
      expect(WechatFileParser.mapCategory('其他', 'income')).assertEqual('其它');
    });

    it('wechatExpenseMapsToNewCategories', 0, () => {
      expect(WechatFileParser.mapCategory('商户消费', 'expense', '', '永辉超市')).assertEqual('购物');
      expect(WechatFileParser.mapCategory('商户消费', 'expense', '', '未知商户')).assertEqual('其他');
      expect(WechatFileParser.mapCategory('转账', 'expense')).assertEqual('社交');
      expect(WechatFileParser.mapCategory('其他', 'expense')).assertEqual('其他');
    });
  });
}
