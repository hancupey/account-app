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
      const lines = splitOcrLines(`樟荣沙县\n-29.00\n商品\n636义乌樟荣江东街道店-点餐即支付-2931779347549276181\n商户全称\n三明沙县樟荣餐饮服务有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
    });

    it('extractsWechatNoteInlineWithColon', 0, () => {
      const lines = splitOcrLines(`樟荣沙县\n-29.00\n商品：636义乌樟荣江东街道店-点餐即支付-2931779347549276181\n商户全称\n三明沙县樟荣餐饮服务有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
    });

    it('extractsWechatNoteInlineWithoutSeparator', 0, () => {
      const lines = splitOcrLines(`樟荣沙县\n-29.00\n商品636义乌樟荣江东街道店-点餐即支付-2931779347549276181\n商户全称\n三明沙县樟荣餐饮服务有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
    });

    it('doesNotUseMerchantFullNameWhenGoodsLabelExists', 0, () => {
      const lines = splitOcrLines(`樟荣沙县\n-29.00\n商户全称\n三明沙县樟荣餐饮服务有限公司\n商品\n636义乌樟荣江东街道店-点餐即支付-2931779347549276181`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('636义乌樟荣江东街道店-点餐即支付-2931779347549276181');
    });

    it('doesNotMatchShangPinShuoMingWhenSearchingShangPin', 0, () => {
      const lines = splitOcrLines(`全家FamilyMart\n-6.00\n商品说明\n杭州全家便利店\n收款方全称\n杭州顶全便利店有限公司`);
      expect(extractLabeledNote(lines, ['商品'])).assertEqual('');
      expect(extractLabeledNote(lines, ['商品说明'])).assertEqual('杭州全家便利店');
    });

    it('extractsAlipayNoteFromNextLine', 0, () => {
      const lines = splitOcrLines(`全家FamilyMart\n-6.00\n商品说明\n杭州全家便利店\n收款方全称\n杭州顶全便利店有限公司`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('杭州全家便利店');
    });

    it('extractsAlipayNoteInlineWithColon', 0, () => {
      const lines = splitOcrLines(`全家FamilyMart\n-6.00\n商品说明：杭州全家便利店`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('杭州全家便利店');
    });

    it('extractsAlipayNoteWhenLabelSplitAcrossLines', 0, () => {
      const lines = splitOcrLines(`全家FamilyMart\n-6.00\n商品\n说明\n杭州全家便利店`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('杭州全家便利店');
    });

    it('extractsShangPinMiaoShuAlias', 0, () => {
      const lines = splitOcrLines(`商户\n-1.00\n商品描述\n杭州全家便利店`);
      expect(extractLabeledNote(lines, ['商品说明', '商品描述'])).assertEqual('杭州全家便利店');
    });

    it('isExactLabelLineRejectsPartialMatch', 0, () => {
      expect(isExactLabelLine('商品说明', '商品')).assertFalse();
      expect(isExactLabelLine('商品', '商品')).assertTrue();
      expect(isExactLabelLine('商品：美式咖啡', '商品')).assertTrue();
    });

    it('extractInlineLabelValueHandlesNoSeparator', 0, () => {
      expect(extractInlineLabelValue('商品636义乌店', '商品')).assertEqual('636义乌店');
      expect(extractInlineLabelValue('商品：636义乌店', '商品')).assertEqual('636义乌店');
      expect(extractInlineLabelValue('商品', '商品')).assertEqual('');
    });
  });
}
