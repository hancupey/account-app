import { ParsedTransaction, PaymentPlatform } from '../../models/ParsedTransaction';
import { TransactionType } from '../../models/Transaction';
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
 * 微信账单详情页截图 OCR 文本解析。
 *
 * 常见页面字段（详情页）：
 * - 金额：¥12.34 / -29.00 / -¥12.34
 * - 当前状态：支付成功 / 已转账 / 已收款
 * - 支付时间 / 转账时间 / 收款时间：2024-01-15 12:30:45 / 2026年6月28日 13:01:14
 * - 商品 / 商户全称 / 交易对方 / 收款方备注（备注由用户手动填写，不自动识别）
 */
export class WechatScreenshotParser {
  static parse(ocrText: string): ParsedTransaction {
    const result = new ParsedTransaction();
    result.source = 'wechat';
    result.rawText = ocrText;
    const lines = splitOcrLines(ocrText);
    const joined = lines.join('\n');

    result.type = WechatScreenshotParser.detectType(joined, lines);
    result.amount = WechatScreenshotParser.extractAmount(lines, joined);
    result.occurredAt = WechatScreenshotParser.extractDateTime(lines, joined);
    result.payee = WechatScreenshotParser.extractPayee(lines);
    result.note = '';
    result.confidence = WechatScreenshotParser.calcConfidence(result);
    return result;
  }

  static detectPlatform(ocrText: string): PaymentPlatform {
    if (/微信|WeChat|微信支付|零钱|转账给|收款方备注/.test(ocrText)) {
      return 'wechat';
    }
    return 'unknown';
  }

  private static detectType(joined: string, lines: string[]): TransactionType {
    const fromSign = detectTypeFromAmountSign(lines);
    if (fromSign !== null) {
      return fromSign;
    }

    const cleaned = stripTypeFalsePositives(joined);
    if (/退款成功|退款到账|向你转账|收到转账|类型[：:]\s*收入/.test(cleaned)) {
      return 'income';
    }
    if (/(?:^|\s)收入(?:$|\s)/.test(cleaned)) {
      return 'income';
    }
    if (/已收款/.test(cleaned) && !/支付成功|已支付|已转账|商户消费/.test(cleaned)) {
      return 'income';
    }
    if (/支出|已支付|支付成功|已转账|商户消费|扫二维码付款|付款/.test(cleaned)) {
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
        const value = WechatScreenshotParser.parseNumber(match[1]);
        if (value > 0) {
          return value;
        }
      }
    }
    const joinedMatch = joined.match(/金额[：:]\s*[+-]?¥?\s*([\d,]+\.?\d*)/);
    if (joinedMatch && joinedMatch[1]) {
      const value = WechatScreenshotParser.parseNumber(joinedMatch[1]);
      if (value > 0) {
        return value;
      }
    }
    return 0;
  }

  private static extractDateTime(lines: string[], joined: string): number {
    const timeLabels: string[] = ['支付时间', '转账时间', '收款时间', '交易时间', '创建时间'];
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

    const counterparty = extractLabeledNote(lines, ['交易对方']);
    if (counterparty.length > 0) {
      return counterparty;
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
    if (/微信|WeChat/.test(result.rawText)) {
      score += 0.2;
    }
    return score;
  }
}
