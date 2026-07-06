import { describe, it, expect } from '@ohos/hypium';
import { AlipayScreenshotParser } from '../main/ets/services/ocr/AlipayScreenshotParser';
import { formatDateTime } from '../main/ets/utils/DateUtil';

const SAMPLE_OCR = `10:47
爱太空
账单详情
全部账单
测试商户B
-6.00
交易成功
支付时间
2026-01-15 10:00:00
付款方式
花呗
商品说明
测试商品说明
支付奖励
已领取2积分
收单机构
支付宝支付科技有限公司
收款方全称
测试收款方有限公司
账单分类
日用百货
计入收支
备注
添加`;

export default function alipayScreenshotParserTest() {
  describe('AlipayScreenshotParser', () => {
    it('parsesSampleBillDetail', 0, () => {
      const result = AlipayScreenshotParser.parse(SAMPLE_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(6);
      expect(result.payee).assertEqual('测试商户B');
      expect(result.note).assertEqual('');
      expect(result.categoryName).assertEqual('日用');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-01-15 10:00:00');
    });

    it('parsesBillCategoryFromNextLine', 0, () => {
      const ocrText = `账单详情
杭州市西湖区腾业便利店
-3.50
交易成功
支付时间
2026-07-02 14:03:19
商品说明
二维码支付
账单分类
日用百货
计入收支`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(3.5);
      expect(result.payee).assertEqual('杭州市西湖区腾业便利店');
      expect(result.note).assertEqual('');
      expect(result.categoryName).assertEqual('日用');
    });

    it('parsesBillCategoryInlineWithColon', 0, () => {
      const ocrText = `账单详情\n测试商户\n-10.00\n账单分类：餐饮美食\n商品说明\n午餐`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.categoryName).assertEqual('餐饮');
    });

    it('fallsBackToEmptyCategoryWhenBillCategoryMissing', 0, () => {
      const ocrText = `账单详情\n测试商户\n-5.00\n商品说明\n测试`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.categoryName).assertEqual('');
    });

    it('mapsIncomeCategoryFromBillCategory', 0, () => {
      const ocrText = `账单详情\n+100.00\n账单分类\n转账红包\n商品说明\n红包`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('income');
      expect(result.categoryName).assertEqual('礼金');
    });

    it('parsesSampleInlineShangPinShuoMingWithColon', 0, () => {
      const ocrText = `账单详情\n测试商户B\n-6.00\n交易成功\n支付时间\n2026-01-15 10:00:00\n商品说明：测试商品说明\n收款方全称\n测试收款方有限公司`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.payee).assertEqual('测试商户B');
      expect(result.note).assertEqual('');
    });

    it('parsesSampleSplitShangPinShuoMingLabel', 0, () => {
      const ocrText = `账单详情\n测试商户B\n-6.00\n交易成功\n支付时间\n2026-01-15 10:00:00\n商品\n说明\n测试商品说明\n收款方全称\n测试收款方有限公司`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.payee).assertEqual('测试商户B');
      expect(result.note).assertEqual('');
    });

    it('doesNotUseShouKuanFangQuanChengAsNote', 0, () => {
      const ocrText = `账单详情\n测试商户B\n-6.00\n收款方全称\n测试收款方有限公司\n商品说明\n测试商品说明`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.note).assertEqual('');
    });

    it('detectsExpenseFromSplitDateTime', 0, () => {
      const ocrText = `账单详情
商户A
-12.50
支付时间
2026-07-01
14:30:00
商品说明
测试商品
计入收支`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('expense');
      expect(result.payee).assertEqual('商户A');
      expect(result.note).assertEqual('');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-01 14:30:00');
    });

    it('doesNotTreatJiRuShouZhiAsIncome', 0, () => {
      const ocrText = `账单详情
测试商户
-1.00
交易成功
支付时间
2026-07-01 10:00:00
计入收支
商品说明
商品`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('expense');
      expect(result.payee).assertEqual('测试商户');
      expect(result.note).assertEqual('');
    });

    it('parsesRefundBillWithPlainPositiveAmount', 0, () => {
      const ocrText = `10:35
账单详情
全部账单
智能自助设备
4.22
退款成功
创建时间
2026-07-05 13:35:33
退款方式
余额宝
商品说明
退款-自助服务-充电桩/示例订单
账单分类
退款
计入收支`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('income');
      expect(result.amount).assertEqual(4.22);
      expect(result.payee).assertEqual('智能自助设备');
      expect(result.categoryName).assertEqual('其它');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-05 13:35:33');
    });

    it('parsesRefundBillWithHuabeiAndMaskedMerchant', 0, () => {
      const ocrText = `账单详情
su**号
3.47
退款成功
创建时间
2026-07-05 14:20:10
退款方式
花呗
商品说明
退款-自助服务-充电桩/另一订单
账单分类
退款`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('income');
      expect(result.amount).assertEqual(3.47);
      expect(result.payee).assertEqual('su**号');
      expect(result.categoryName).assertEqual('其它');
    });

    it('parsesRefundBillWithLargerAmount', 0, () => {
      const ocrText = `账单详情
测试充电桩商户
52.80
退款成功
创建时间
2026-07-04 09:12:00
退款方式
余额宝
账单分类
退款`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('income');
      expect(result.amount).assertEqual(52.8);
      expect(result.payee).assertEqual('测试充电桩商户');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-04 09:12:00');
    });

    it('parsesRefundBillWithSplitCreateTime', 0, () => {
      const ocrText = `账单详情
退款商户A
12.00
退款成功
创建时间
2026-07-05
13:35:33
退款方式
余额宝
账单分类
退款`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.type).assertEqual('income');
      expect(result.amount).assertEqual(12);
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-05 13:35:33');
    });
  });
}
