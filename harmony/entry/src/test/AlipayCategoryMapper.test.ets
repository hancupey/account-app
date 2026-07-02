import { describe, it, expect } from '@ohos/hypium';

import { AlipayCategoryMapper } from '../main/ets/services/import/AlipayCategoryMapper';
import { AlipayFileParser } from '../main/ets/services/import/AlipayFileParser';

export default function alipayCategoryMapperTest() {
  describe('AlipayCategoryMapper', () => {
    it('expenseCategoryExactMapping', 0, () => {
      const cases: string[][] = [
        ['餐饮美食', '餐饮'],
        ['服饰装扮', '服饰'],
        ['日用百货', '日用'],
        ['家居家装', '居家'],
        ['数码电器', '数码'],
        ['运动户外', '运动'],
        ['美容美发', '美容'],
        ['母婴亲子', '孩子'],
        ['宠物', '宠物'],
        ['交通出行', '交通'],
        ['爱车养车', '汽车'],
        ['住房物业', '住房'],
        ['酒店旅游', '旅行'],
        ['文化休闲', '娱乐'],
        ['教育培训', '学习'],
        ['医疗健康', '医疗'],
        ['生活服务', '日用'],
        ['公共服务', '办公'],
        ['商业服务', '办公'],
        ['公益捐赠', '捐赠'],
        ['互助保障', '医疗'],
        ['保险', '办公'],
        ['信用借还', '日用'],
        ['充值缴费', '通讯'],
      ];
      for (let i = 0; i < cases.length; i++) {
        const mapped = AlipayCategoryMapper.mapCategory(cases[i][0], 'expense');
        expect(mapped.type).assertEqual('expense');
        expect(mapped.categoryName).assertEqual(cases[i][1]);
      }
    });

    it('row6IncomeForceIncomeType', 0, () => {
      const labels: string[] = ['收入', '转账红包', '亲友代付', '账户存取'];
      for (let i = 0; i < labels.length; i++) {
        const mapped = AlipayCategoryMapper.mapCategory(labels[i], 'expense');
        expect(mapped.type).assertEqual('income');
      }
      expect(AlipayCategoryMapper.mapCategory('收入', 'expense').categoryName).assertEqual('其它');
      expect(AlipayCategoryMapper.mapCategory('转账红包', 'expense').categoryName).assertEqual('礼金');
      expect(AlipayCategoryMapper.mapCategory('亲友代付', 'expense').categoryName).assertEqual('其它');
      expect(AlipayCategoryMapper.mapCategory('账户存取', 'expense').categoryName).assertEqual('其它');
    });

    it('refundForceExpenseNotIncome', 0, () => {
      const mapped = AlipayCategoryMapper.mapCategory('退款', 'income');
      expect(mapped.type).assertEqual('expense');
      expect(mapped.categoryName).assertEqual('日用');
    });

    it('investmentTypeDependent', 0, () => {
      expect(AlipayCategoryMapper.mapCategory('投资理财', 'income').categoryName).assertEqual('理财');
      expect(AlipayCategoryMapper.mapCategory('投资理财', 'income').type).assertEqual('income');
      expect(AlipayCategoryMapper.mapCategory('投资理财', 'expense').categoryName).assertEqual('办公');
      expect(AlipayCategoryMapper.mapCategory('投资理财', 'expense').type).assertEqual('expense');
    });

    it('otherTypeDependent', 0, () => {
      expect(AlipayCategoryMapper.mapCategory('其他', 'income').categoryName).assertEqual('其它');
      expect(AlipayCategoryMapper.mapCategory('其他', 'expense').categoryName).assertEqual('其他');
      expect(AlipayCategoryMapper.mapCategory('其它', 'income').categoryName).assertEqual('其它');
      expect(AlipayCategoryMapper.mapCategory('其它', 'expense').categoryName).assertEqual('其他');
    });

    it('emptyLabelUsesCsvTypeFallback', 0, () => {
      expect(AlipayCategoryMapper.mapCategory('', 'income').categoryName).assertEqual('其它');
      expect(AlipayCategoryMapper.mapCategory('', 'expense').categoryName).assertEqual('其他');
    });

    it('fuzzyUnknownExpenseLabel', 0, () => {
      expect(AlipayCategoryMapper.mapCategory('未知分类', 'expense').categoryName).assertEqual('其他');
    });
  });

  describe('AlipayFileParserTypeOverride', () => {
    it('mapCategoryWithTypeOverridesCsv', 0, () => {
      expect(AlipayFileParser.mapCategoryWithType('收入', 'expense')).assertEqual('income');
      expect(AlipayFileParser.mapCategoryWithType('退款', 'income')).assertEqual('expense');
      expect(AlipayFileParser.mapCategoryWithType('餐饮美食', 'expense')).assertEqual('expense');
    });

    it('parseCsvAppliesCategoryTypeOverride', 0, () => {
      const csv = [
        '交易时间,交易分类,交易对方,商品说明,收/支,金额',
        '2024-01-01 12:00:00,转账红包,张三,红包,支出,10.00',
        '2024-01-02 12:00:00,退款,商户,退货,收入,20.00',
      ].join('\n');
      const result = AlipayFileParser.parseCsv(csv, 'alipay.csv');
      expect(result.drafts.length).assertEqual(2);
      expect(result.drafts[0].type).assertEqual('income');
      expect(result.drafts[0].categoryName).assertEqual('礼金');
      expect(result.drafts[1].type).assertEqual('expense');
      expect(result.drafts[1].categoryName).assertEqual('日用');
    });
  });
}
