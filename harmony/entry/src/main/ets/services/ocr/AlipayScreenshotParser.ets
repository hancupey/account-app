import { ParsedTransaction, PaymentPlatform } from '../../models/ParsedTransaction';
import { TransactionType } from '../../models/Transaction';
import { AlipayCategoryMapper } from '../import/AlipayCategoryMapper';
import { parseDateTimeString } from '../../utils/DateUtil';
import {
  detectTypeFromAmountSign,
  extractLabeledDateTime,
  extractLabeledNote,
  extractMerchantBeforeAmount,
  extractSignedAmountValue,
  isLikelyMerchantLine,
  OCR_DATETIME_PATTERN,
  shouldSkipAmountLine,
  splitOcrLines,
  stripTypeFalsePositives
} from './OcrParseUtil';

/**
 * 支付宝账单详情页截图 OCR 文本解析。
 *
 * 常见页面字段：
 * - 金额：-12.34 / 12.34 / ¥12.34
 * - 交易成功 / 等待确认收货
 * - 支付时间 / 付款时间：2024-01-15 12:30:45
 * - 商品说明 / 收款方全称 / 对方账户（备注由用户手动填写，不自动识别）
 * - 页面顶部商户名（如 全家FamilyMart）
 */
export class AlipayScreenshotParser {
  static parse(ocrText: string): ParsedTransaction {
    const result = new ParsedTransaction();
    result.source = 'alipay';
    result.rawText = ocrText;
    const lines = splitOcrLines(ocrText);
    const joined = lines.join('\n');

    result.type = AlipayScreenshotParser.detectType(joined, lines);
    result.amount = AlipayScreenshotParser.extractAmount(lines, joined);
    result.occurredAt = AlipayScreenshotParser.extractDateTime(lines, joined);
    result.payee = AlipayScreenshotParser.extractPayee(lines);
    result.note = '';
    AlipayScreenshotParser.applyCategoryMapping(result, lines);
    result.confidence = AlipayScreenshotParser.calcConfidence(result);
    return result;
  }

  static detectPlatform(ocrText: string): PaymentPlatform {
    if (/支付宝|Alipay|花呗|余额宝|蚂蚁/.test(ocrText)) {
      return 'alipay';
    }
    return 'unknown';
  }

  private static detectType(joined: string, lines: string[]): TransactionType {
    const fromSign = detectTypeFromAmountSign(lines);
    if (fromSign !== null) {
      return fromSign;
    }

    const cleaned = stripTypeFalsePositives(joined);
    if (/退款成功|退款到账|转账.*收入|类型[：:]\s*收入/.test(cleaned)) {
      return 'income';
    }
    if (/(?:^|\s)收入(?:$|\s)/.test(cleaned)) {
      return 'income';
    }
    if (/支出|付款|转出|消费|交易成功/.test(cleaned)) {
      return 'expense';
    }
    return 'expense';
  }

  private static extractAmount(lines: string[], joined: string): number {
    for (const line of lines) {
      if (shouldSkipAmountLine(line)) {
        continue;
      }
      const value = extractSignedAmountValue(line);
      if (value > 0) {
        return value;
      }
    }
    for (const line of lines) {
      if (shouldSkipAmountLine(line)) {
        continue;
      }
      const match = line.match(/金额[：:]\s*[+-]?¥?\s*([\d,]+\.?\d*)/);
      if (match && match[1]) {
        const value = AlipayScreenshotParser.parseNumber(match[1]);
        if (value > 0) {
          return value;
        }
      }
    }
    const joinedMatch = joined.match(/金额[：:]\s*[+-]?¥?\s*([\d,]+\.?\d*)/);
    if (joinedMatch && joinedMatch[1]) {
      const value = AlipayScreenshotParser.parseNumber(joinedMatch[1]);
      if (value > 0) {
        return value;
      }
    }
    return 0;
  }

  private static extractDateTime(lines: string[], joined: string): number {
    const timeLabels: string[] = ['支付时间', '付款时间', '创建时间', '交易时间'];
    const labeledTs = extractLabeledDateTime(lines, timeLabels);
    if (labeledTs > 0) {
      return labeledTs;
    }
    const globalMatch = joined.match(OCR_DATETIME_PATTERN);
    if (globalMatch && globalMatch[1]) {
      const ts = parseDateTimeString(globalMatch[1]);
      if (ts > 0) {
        return ts;
      }
    }
    return Date.now();
  }

  private static extractPayee(lines: string[]): string {
    const merchantFromAmount = extractMerchantBeforeAmount(lines);
    if (merchantFromAmount.length > 0) {
      return merchantFromAmount;
    }

    let passedBillHeader = false;
    for (const line of lines) {
      if (/账单详情/.test(line)) {
        passedBillHeader = true;
        continue;
      }
      if (!passedBillHeader) {
        continue;
      }
      if (isLikelyMerchantLine(line)) {
        return line.trim();
      }
    }
    return '';
  }

  private static extractBillCategory(lines: string[]): string {
    return extractLabeledNote(lines, ['账单分类']);
  }

  private static applyCategoryMapping(result: ParsedTransaction, lines: string[]): void {
    const alipayLabel = AlipayScreenshotParser.extractBillCategory(lines);
    if (alipayLabel.length === 0) {
      return;
    }
    const mapped = AlipayCategoryMapper.mapCategory(alipayLabel, result.type);
    result.type = mapped.type;
    result.categoryName = mapped.categoryName;
  }

  private static parseNumber(text: string): number {
    const cleaned = text.replace(/,/g, '');
    const value = Number.parseFloat(cleaned);
    if (Number.isNaN(value)) {
      return 0;
    }
    return value;
  }

  private static calcConfidence(result: ParsedTransaction): number {
    let score = 0;
    if (result.amount > 0) {
      score += 0.4;
    }
    if (result.occurredAt > 0) {
      score += 0.2;
    }
    if (result.payee.length > 0) {
      score += 0.2;
    }
    if (/支付宝|Alipay/.test(result.rawText)) {
      score += 0.2;
    }
    return score;
  }
}
