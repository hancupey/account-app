import { describe, it, expect } from '@ohos/hypium';
import {
  extractInlineLabelValue,
  extractLabeledNote,
  isExactLabelLine,
  splitOcrLines
} from '../main/ets/services/ocr/OcrParseUtil';

export default function ocrParseUtilTest() {
  describe('OcrParseUtil note extraction', () => {
    it('extractsWechatNoteFromNextLine', 0, () => {
      const lines = splitOcrLines(`示例餐厅A\n-29.00\n商品\n测试门店-点餐即支付-ORD000001\n商户全称\n示例餐饮有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('extractsWechatNoteInlineWithColon', 0, () => {
      const lines = splitOcrLines(`示例餐厅A\n-29.00\n商品：测试门店-点餐即支付-ORD000001\n商户全称\n示例餐饮有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('extractsWechatNoteInlineWithoutSeparator', 0, () => {
      const lines = splitOcrLines(`示例餐厅A\n-29.00\n商品测试门店-点餐即支付-ORD000001\n商户全称\n示例餐饮有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('doesNotUseMerchantFullNameWhenGoodsLabelExists', 0, () => {
      const lines = splitOcrLines(`示例餐厅A\n-29.00\n商户全称\n示例餐饮有限公司\n商品\n测试门店-点餐即支付-ORD000001`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('测试门店-点餐即支付-ORD000001');
    });

    it('doesNotMatchShangPinShuoMingWhenSearchingShangPin', 0, () => {
      const lines = splitOcrLines(`测试商户B\n-6.00\n商品说明\n测试商品说明\n收款方全称\n测试收款方有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('');
      expect(extractLabeledNote(lines, ['商品说明'])).assertEqual('测试商品说明');
    });

    it('extractsAlipayNoteFromNextLine', 0, () => {
      const lines = splitOcrLines(`测试商户B\n-6.00\n商品说明\n测试商品说明\n收款方全称\n测试收款方有限公司`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('测试商品说明');
    });

    it('extractsAlipayNoteInlineWithColon', 0, () => {
      const lines = splitOcrLines(`测试商户B\n-6.00\n商品说明：测试商品说明`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('测试商品说明');
    });

    it('extractsAlipayNoteWhenLabelSplitAcrossLines', 0, () => {
      const lines = splitOcrLines(`测试商户B\n-6.00\n商品\n说明\n测试商品说明`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('测试商品说明');
    });

    it('extractsAlipayBillCategoryFromNextLine', 0, () => {
      const lines = splitOcrLines(`测试商户B\n-6.00\n账单分类\n日用百货\n商品说明\n测试商品说明`);
      expect(extractLabeledNote(lines, ['账单分类'])).assertEqual('日用百货');
    });

    it('extractsAlipayBillCategoryInlineWithColon', 0, () => {
      const lines = splitOcrLines(`测试商户B\n-6.00\n账单分类：餐饮美食`);
      expect(extractLabeledNote(lines, ['账单分类'])).assertEqual('餐饮美食');
    });

    it('isExactLabelLineRejectsPartialMatch', 0, () => {
      expect(isExactLabelLine('商品说明', '商品')).assertFalse();
      expect(isExactLabelLine('商品', '商品')).assertTrue();
      expect(isExactLabelLine('商品：美式咖啡', '商品')).assertTrue();
    });

    it('extractInlineLabelValueHandlesNoSeparator', 0, () => {
      expect(extractInlineLabelValue('商品测试门店', '商品')).assertEqual('测试门店');
      expect(extractInlineLabelValue('商品：测试门店', '商品')).assertEqual('测试门店');
      expect(extractInlineLabelValue('商品', '商品')).assertEqual('');
    });
  });
}
