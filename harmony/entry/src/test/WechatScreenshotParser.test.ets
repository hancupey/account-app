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
2026-07-01 09:05:33
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

const ZHANG_RONG_OCR = `10:50
樟荣沙县
-29.00
支付成功
支付时间
2026年6月28日 13:01:14
商品
636义乌樟荣江东街道店-点餐即支付-2931779347549276181
商户全称
三明沙县樟荣餐饮服务有限公司
收单机构
拉卡拉支付股份有限公司
支付方式
零钱
交易单号
4500000283202606287677043509
商户单号
20260628110113130266224559797346
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
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-07-01 09:05:33');
    });

    it('parsesZhangRongShaXianBillDetail', 0, () => {
      const result = WechatScreenshotParser.parse(ZHANG_RONG_OCR);
      expect(result.type).assertEqual('expense');
      expect(result.amount).assertEqual(29);
      expect(result.payee).assertEqual('樟荣沙县');
      expect(result.note).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
      expect(formatDateTime(result.occurredAt)).assertEqual('2026-06-28 13:01:14');
    });

    it('parsesZhangRongInlineGoodsWithoutSeparator', 0, () => {
      const ocrText = `樟荣沙县\n-29.00\n支付成功\n支付时间\n2026年6月28日 13:01:14\n商品636义乌樟荣江东街道店-点餐即支付-2931779347549276181\n商户全称\n三明沙县樟荣餐饮服务有限公司`;
      const result = WechatScreenshotParser.parse(ocrText);
      expect(result.payee).assertEqual('樟荣沙县');
      expect(result.note).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
    });

    it('parsesZhangRongInlineGoodsWithColon', 0, () => {
      const ocrText = `樟荣沙县\n-29.00\n商品：636义乌樟荣江东街道店-点餐即支付-2931779347549276181\n商户全称\n三明沙县樟荣餐饮服务有限公司`;
      const result = WechatScreenshotParser.parse(ocrText);
      expect(result.note).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
    });

    it('doesNotUseShangHuQuanChengAsNote', 0, () => {
      const ocrText = `樟荣沙县\n-29.00\n商户全称\n三明沙县樟荣餐饮服务有限公司\n商品\n636义乌樟荣江东街道店-点餐即支付-2931779347549276181`;
      const result = WechatScreenshotParser.parse(ocrText);
      expect(result.note).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
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
