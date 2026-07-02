import { describe, it, expect } from '@ohos/hypium';
import { WechatCategoryMapper } from '../main/ets/services/import/WechatCategoryMapper';
import { WechatFileParser } from '../main/ets/services/import/WechatFileParser';

export default function wechatCategoryMapperTest() {
  describe('WechatCategoryMapper.detectType', () => {
    it('respectsIncomeExpenseColumnFirst', 0, () => {
      const result = WechatCategoryMapper.detectType({
        transactionType: '转账',
        productName: '转账-来自张三',
        counterparty: '张三',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(result).assertEqual('expense');
    });

    it('infersTypeFromProductNameWhenNoIncomeExpenseColumn', 0, () => {
      expect(WechatCategoryMapper.detectType({
        transactionType: '微信红包',
        productName: '微信红包-来自李四',
        counterparty: '李四',
        incomeExpenseLabel: '',
        csvType: 'expense'
      })).assertEqual('income');

      expect(WechatCategoryMapper.detectType({
        transactionType: '微信红包',
        productName: '微信红包-发给王五',
        counterparty: '王五',
        incomeExpenseLabel: '',
        csvType: 'income'
      })).assertEqual('expense');
    });

    it('forcesExpenseForRefundRegardlessOfIncomeColumn', 0, () => {
      expect(WechatCategoryMapper.detectType({
        transactionType: '有退款',
        productName: '商户消费退款',
        counterparty: '某商户',
        incomeExpenseLabel: '收入',
        csvType: 'income'
      })).assertEqual('expense');
    });
  });

  describe('WechatCategoryMapper.map screenshot patterns', () => {
    it('redPacketIncomeAndExpense', 0, () => {
      const income = WechatCategoryMapper.map({
        transactionType: '微信红包',
        productName: '微信红包-来自张三',
        counterparty: '张三',
        incomeExpenseLabel: '收入',
        csvType: 'income'
      });
      expect(income.type).assertEqual('income');
      expect(income.categoryName).assertEqual('礼金');

      const expense = WechatCategoryMapper.map({
        transactionType: '微信红包',
        productName: '微信红包-发给李四',
        counterparty: '李四',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(expense.type).assertEqual('expense');
      expect(expense.categoryName).assertEqual('礼金');
    });

    it('transferIncomeAndExpense', 0, () => {
      const income = WechatCategoryMapper.map({
        transactionType: '转账',
        productName: '转账-来自王五',
        counterparty: '王五',
        incomeExpenseLabel: '收入',
        csvType: 'income'
      });
      expect(income.type).assertEqual('income');
      expect(income.categoryName).assertEqual('其它');

      const expense = WechatCategoryMapper.map({
        transactionType: '转账',
        productName: '转账-转给赵六',
        counterparty: '赵六',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(expense.type).assertEqual('expense');
      expect(expense.categoryName).assertEqual('社交');
    });

    it('groupCollectionIncomeAndExpense', 0, () => {
      const income = WechatCategoryMapper.map({
        transactionType: '群收款',
        productName: '群收款-来自群聊',
        counterparty: '群聊',
        incomeExpenseLabel: '收入',
        csvType: 'income'
      });
      expect(income.type).assertEqual('income');
      expect(income.categoryName).assertEqual('礼金');

      const expense = WechatCategoryMapper.map({
        transactionType: '群收款',
        productName: '群收款-转给群聊',
        counterparty: '群聊',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(expense.type).assertEqual('expense');
      expect(expense.categoryName).assertEqual('社交');
    });

    it('qrCodePayment', 0, () => {
      const mapped = WechatCategoryMapper.map({
        transactionType: '二维码收付款',
        productName: '扫二维码付款-给路边摊',
        counterparty: '路边摊',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(mapped.type).assertEqual('expense');
      expect(mapped.categoryName).assertEqual('其他');
    });

    it('merchantConsumptionKeywordMatch', 0, () => {
      const supermarket = WechatCategoryMapper.map({
        transactionType: '商户消费',
        productName: '购物',
        counterparty: '永辉超市',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(supermarket.categoryName).assertEqual('购物');

      const market = WechatCategoryMapper.map({
        transactionType: '商户消费',
        productName: '买菜',
        counterparty: '城东菜场',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(market.categoryName).assertEqual('蔬菜');

      const defaultFood = WechatCategoryMapper.map({
        transactionType: '商户消费',
        productName: '消费',
        counterparty: '未知商户',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(defaultFood.categoryName).assertEqual('其他');
    });

    it('rechargeWithdrawAndCreditCard', 0, () => {
      const recharge = WechatCategoryMapper.map({
        transactionType: '充值提现',
        productName: '零钱充值',
        counterparty: '零钱',
        incomeExpenseLabel: '收入',
        csvType: 'income'
      });
      expect(recharge.type).assertEqual('income');
      expect(recharge.categoryName).assertEqual('理财');

      const withdraw = WechatCategoryMapper.map({
        transactionType: '充值提现',
        productName: '零钱提现-到建设银行(1234)',
        counterparty: '建设银行',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(withdraw.type).assertEqual('expense');
      expect(withdraw.categoryName).assertEqual('日用');

      const creditCard = WechatCategoryMapper.map({
        transactionType: '信用卡还款',
        productName: '还款',
        counterparty: '招商银行信用卡',
        incomeExpenseLabel: '支出',
        csvType: 'expense'
      });
      expect(creditCard.categoryName).assertEqual('其他');
    });

    it('refundMapsToExpenseDefaultCategory', 0, () => {
      const mapped = WechatCategoryMapper.map({
        transactionType: '有退款',
        productName: '退款-商户消费',
        counterparty: '某店',
        incomeExpenseLabel: '收入',
        csvType: 'income'
      });
      expect(mapped.type).assertEqual('expense');
      expect(mapped.categoryName).assertEqual('其他');
    });
  });

  describe('WechatFileParser.parseCsv', () => {
    it('parsesCsvRowWithPayeeAndProductNote', 0, () => {
      const csv = `交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-07-01 10:00:00,转账,张三,转账-来自张三,收入,17.90,零钱,支付成功,1001,2001,`;

      const result = WechatFileParser.parseCsv(csv, 'wechat.csv');
      expect(result.drafts.length).assertEqual(1);
      expect(result.drafts[0].payee).assertEqual('张三');
      expect(result.drafts[0].note).assertEqual('转账-来自张三');
      expect(result.drafts[0].type).assertEqual('income');
      expect(result.drafts[0].categoryName).assertEqual('其它');
      expect(result.drafts[0].amount).assertEqual(17.9);
    });

    it('parsesMerchantRowWithKeywordCategory', 0, () => {
      const csv = `交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-07-01 12:00:00,商户消费,盒马鲜生,生鲜购物,支出,58.00,零钱,支付成功,1002,2002,`;

      const result = WechatFileParser.parseCsv(csv, 'wechat.csv');
      expect(result.drafts.length).assertEqual(1);
      expect(result.drafts[0].categoryName).assertEqual('购物');
      expect(result.drafts[0].payee).assertEqual('盒马鲜生');
    });
  });
}
