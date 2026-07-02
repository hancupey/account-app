import { describe, it, expect } from '@ohos/hypium';
import { AlipayScreenshotParser } from '../main/ets/services/ocr/AlipayScreenshotParser';
import { formatDateTime } from '../main/ets/utils/DateUtil';

const FAMILY_MART_OCR = `10:47
爱太空
账单详情
全部账单
全家FamilyMart
-6.00
交易成功
支付时间
2026-07-01 09:05:33
付款方式
花呗
商品说明
杭州全家便利店
支付奖励
已领取2积分
收单机构
支付宝支付科技有限公司
收款方全称
杭州顶全便利店有限公司
账单分类
日用百货
计入收支
备注
添加`;

export default function alipayScreenshotParserTest() {
  describe('AlipayScreenshotParser', () => {
    it('parsesFamilyMartBillDetail', 0, () => {
      const result = AlipayScreenshotParser.parse(FAMILY_MART_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(6);
      expect(result.payee).assertEqual('全家FamilyMart');
      expect(result.note).assertEqual('杭州全家便利店');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-01 09:05:33');
    });

    it('parsesFamilyMartInlineShangPinShuoMingWithColon', 0, () => {
      const ocrText = `账单详情\n全家FamilyMart\n-6.00\n交易成功\n支付时间\n2026-07-01 09:05:33\n商品说明：杭州全家便利店\n收款方全称\n杭州顶全便利店有限公司`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.payee).assertEqual('全家FamilyMart');
      expect(result.note).assertEqual('杭州全家便利店');
    });

    it('parsesFamilyMartSplitShangPinShuoMingLabel', 0, () => {
      const ocrText = `账单详情\n全家FamilyMart\n-6.00\n交易成功\n支付时间\n2026-07-01 09:05:33\n商品\n说明\n杭州全家便利店\n收款方全称\n杭州顶全便利店有限公司`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.payee).assertEqual('全家FamilyMart');
      expect(result.note).assertEqual('杭州全家便利店');
    });

    it('doesNotUseShouKuanFangQuanChengAsNote', 0, () => {
      const ocrText = `账单详情\n全家FamilyMart\n-6.00\n收款方全称\n杭州顶全便利店有限公司\n商品说明\n杭州全家便利店`;
      const result = AlipayScreenshotParser.parse(ocrText);
      expect(result.note).assertEqual('杭州全家便利店');
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
      expect(result.note).assertEqual('测试商品');
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
      expect(result.note).assertEqual('商品');
    });
  });
}
