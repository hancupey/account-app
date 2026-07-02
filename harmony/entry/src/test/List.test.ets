import localUnitTest from './LocalUnit.test';
import alipayScreenshotParserTest from './AlipayScreenshotParser.test';
import wechatScreenshotParserTest from './WechatScreenshotParser.test';
import dateUtilTest from './DateUtil.test';
import ocrParseUtilTest from './OcrParseUtil.test';
import categoryDefaultsTest from './CategoryDefaults.test';
import alipayCategoryMapperTest from './AlipayCategoryMapper.test';
import wechatCategoryMapperTest from './WechatCategoryMapper.test';
import billImportParserTest from './BillImportParser.test';

export default function testsuite() {
  localUnitTest();
  alipayScreenshotParserTest();
  wechatScreenshotParserTest();
  dateUtilTest();
  ocrParseUtilTest();
  categoryDefaultsTest();
  alipayCategoryMapperTest();
  wechatCategoryMapperTest();
  billImportParserTest();
}