import { describe, it, expect } from '@ohos/hypium';
import { WechatScreenshotParser } from '../main/ets/services/ocr/WechatScreenshotParser';
import { formatDateTime } from '../main/ets/utils/DateUtil';

const STARBUCKS_OCR = `14:30
中国移动
微信支付
账单详情
星巴克
-28.00
支付成功
支付时间
2026-01-15 14:30:00
商品
美式咖啡
付款方式
零钱
收款方备注
吧台点单
计入收支`;

const TRANSFER_OCR = `账单详情
张三
-12.50
已转账
转账时间
2026-07-01
14:30:00
转账说明
午饭AA
计入收支
收款方备注
备注信息`;

const JI_RU_SHOU_ZHI_OCR = `账单详情
测试商户
-1.00
支付成功
支付时间
2026-07-01 10:00:00
计入收支
收款方备注
收款备注
商品
商品名`;

const INCOME_TRANSFER_OCR = `账单详情
+100.00
已收款
收款时间
2026-06-15 18:20:10
交易对方
李四
转账说明
还款`;

const SAMPLE_MERCHANT_OCR = `10:50
示例餐厅A
-29.00
支付成功
支付时间
2026年6月28日 13:01:14
商品
测试门店-点餐即支付-ORD000001
商户全称
示例餐饮有限公司
收单机构
拉卡拉支付股份有限公司
支付方式
零钱
交易单号
WX202606280001
商户单号
MCH202606280001
微信支付
账单详情`;


export default function wechatScreenshotParserTest() {
  describe('WechatScreenshotParser', () => {
    it('parsesStarbucksBillDetail', 0, () => {
      const result = WechatScreenshotParser.parse(STARBUCKS_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(28);
      expect(result.payee).assertEqual('星巴克');
      expect(result.note).assertEqual('美式咖啡');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-01-15 14:30:00');
    });

    it('parsesSampleMerchantBillDetail', 0, () => {
      const result = WechatScreenshotParser.parse(SAMPLE_MERCHANT_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(29);
      expect(result.payee).assertEqual('示例餐厅A');
      expect(result.note).assertEqual('测试门店-点餐即支付-ORD000001');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-06-28 13:01:14');
    });

    it('parsesSampleMerchantInlineGoodsWithoutSeparator', 0, () => {
      const ocrText = `示例餐厅A\n-29.00\n支付成功\n支付时间\n2026年6月28日 13:01:14\n商品测试门店-点餐即支付-ORD000001\n商户全称\n示例餐饮有限公司`;
      const result = WechatScreenshotParser.parse(ocrText);
      expect(result.payee).assertEqual('示例餐厅A');
      expect(result.note).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('parsesSampleMerchantInlineGoodsWithColon', 0, () => {
      const ocrText = `示例餐厅A\n-29.00\n商品：测试门店-点餐即支付-ORD000001\n商户全称\n示例餐饮有限公司`;
      const result = WechatScreenshotParser.parse(ocrText);
      expect(result.note).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('doesNotUseShangHuQuanChengAsNote', 0, () => {
      const ocrText = `示例餐厅A\n-29.00\n商户全称\n示例餐饮有限公司\n商品\n测试门店-点餐即支付-ORD000001`;
      const result = WechatScreenshotParser.parse(ocrText);
      expect(result.note).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('detectsExpenseFromSplitTransferTime', 0, () => {
      const result = WechatScreenshotParser.parse(TRANSFER_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(12.5);
      expect(result.payee).assertEqual('张三');
      expect(result.note).assertEqual('');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-01 14:30:00');
    });

    it('doesNotTreatJiRuShouZhiOrShouKuanRemarkAsIncome', 0, () => {
      const result = WechatScreenshotParser.parse(JI_RU_SHOU_ZHI_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.payee).assertEqual('测试商户');
      expect(result.note).assertEqual('商品名');
    });

    it('parsesIncomeTransfer', 0, () => {
      const result = WechatScreenshotParser.parse(INCOME_TRANSFER_OCR);
      expect(result.type).assertEqual('income');
      expect(result.amount).assertEqual(100);
      expect(result.payee).assertEqual('李四');
      expect(result.note).assertEqual('');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-06-15 18:20:10');
    });
  });
}
