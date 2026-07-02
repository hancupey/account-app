import { describe, it, expect } from '@ohos/hypium';
import { AlipayFileParser } from '../main/ets/services/import/AlipayFileParser';
import { WechatFileParser } from '../main/ets/services/import/WechatFileParser';
import { ImportService } from '../main/ets/services/import/ImportService';
import { BillHeaderUtil } from '../main/ets/services/import/BillHeaderUtil';
import { CsvUtil } from '../main/ets/services/import/CsvUtil';
import { formatExcelSerialDateTime } from '../main/ets/utils/DateUtil';

/** 支付宝标准表头（测试用） */
const ALIPAY_HEADER =
  '交易时间,交易分类,交易对方,对方账号,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注,';

const ALIPAY_PREAMBLE = `导出信息：
姓名：测试用户
起始时间：[2026-06-01 00:00:00]    终止时间：[2026-07-01 23:59:59]
导出时间：[2026-07-01 14:27:51]
------------------------支付宝支付科技有限公司  电子客户回单------------------------
${ALIPAY_HEADER}
2026-07-01 13:02:54,日用百货,示例商户A,test***@example.com,测试商品,支出,14.80,花呗,交易成功,ORD202607010001,MCH202607010001,,
2026-07-01 02:00:15,投资理财,示例理财,/,测试收益,不计收支,0.11,余额宝,交易成功,ORD202607010002,,,
2026-06-29 09:35:32,转账红包,测试用户B,138******00,转账,收入,600.00,账户余额,交易成功,ORD202606290001,,,`;

/** 微信 xlsx 表头行（测试用） */
const WECHAT_HEADERS: string[] = [
  '交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
  '支付方式', '当前状态', '交易单号', '商户单号', '备注'
];

const WECHAT_ROWS: string[][] = [
  ['微信支付账单明细'],
  ['共59笔记录'],
  WECHAT_HEADERS,
  ['2026-06-28 13:22:00', '商户消费', '示例餐厅A', '测试门店', '支出', '2', '零钱', '支付成功',
    'WX202606280001', 'MCH202606280001', '/'],
  ['2026-06-23 14:41:00', '群收款', '测试好友', '/', '收入', '83', '/', '已存入零钱',
    'WX202606230001', '/', '/'],
];

export default function billImportParserTest() {
  describe('AlipayFileParser real headers', () => {
    it('parsesPreambleCsvAndSkipsNeutral', 0, () => {
      const result = AlipayFileParser.parseCsv(ALIPAY_PREAMBLE, 'alipay.csv');
      expect(result.platform).assertEqual('alipay');
      expect(result.drafts.length).assertEqual(2);
      expect(result.drafts[0].amount).assertEqual(14.8);
      expect(result.drafts[0].categoryName).assertEqual('日用');
      expect(result.drafts[1].type).assertEqual('income');
      expect(result.drafts[1].categoryName).assertEqual('礼金');
    });

    it('canParseRealHeader', 0, () => {
      const headers = ALIPAY_HEADER.split(',');
      expect(AlipayFileParser.canParse(headers)).assertTrue();
    });
  });

  describe('WechatFileParser real headers', () => {
    it('parsesXlsxStyleRows', 0, () => {
      const result = WechatFileParser.parseRows(WECHAT_ROWS, 'wechat.xlsx');
      expect(result.platform).assertEqual('wechat');
      expect(result.drafts.length).assertEqual(2);
      expect(result.drafts[0].type).assertEqual('expense');
      expect(result.drafts[0].amount).assertEqual(2);
      expect(result.drafts[1].type).assertEqual('income');
      expect(result.drafts[1].amount).assertEqual(83);
    });

    it('canParseRealHeader', 0, () => {
      expect(WechatFileParser.canParse(WECHAT_HEADERS)).assertTrue();
    });
  });

  describe('BillHeaderUtil', () => {
    it('findsHeaderWithBomAndSpaces', 0, () => {
      const headers: string[] = ['\uFEFF交易时间 ', ' 交易分类', '收/支', '金额'];
      const rows: string[][] = [['preamble'], headers];
      expect(BillHeaderUtil.findAlipayHeaderRow(rows)).assertEqual(1);
      expect(BillHeaderUtil.buildColumnMap(headers).get('交易时间')).assertEqual(0);
    });
  });

  describe('ImportService auto-detect', () => {
    it('detectsAlipayFromCsvContent', 0, () => {
      const result = ImportService.parseFile(ALIPAY_PREAMBLE, 'alipay.csv');
      expect(result.platform).assertEqual('alipay');
      expect(result.drafts.length).assertEqual(2);
    });

    it('detectsAlipayDespiteMetadataTimeFields', 0, () => {
      const rows = CsvUtil.parse(ALIPAY_PREAMBLE);
      expect(BillHeaderUtil.findGenericHeaderRow(rows)).assertEqual(5);
      expect(ImportService.detectPlatformFromRows(rows)).assertEqual('alipay');
    });

    it('detectsWechatFromRows', 0, () => {
      const result = ImportService.parseRows(WECHAT_ROWS, 'wechat.xlsx');
      expect(result.platform).assertEqual('wechat');
      expect(result.drafts.length).assertEqual(2);
    });
  });

  describe('Excel date conversion', () => {
    it('formatsWechatSerialDate', 0, () => {
      const formatted = formatExcelSerialDateTime(46201.55695601852);
      expect(formatted.startsWith('2026-06-28')).assertTrue();
      expect(formatted.includes('13:')).assertTrue();
    });
  });
}
