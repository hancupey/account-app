import { parseDateTimeString } from '../../utils/DateUtil';
import { TransactionType } from '../../models/Transaction';

/** 支付宝/微信账单 OCR 行过滤与日期解析共用工具 */

const UI_NOISE_PATTERNS: RegExp[] = [
  /^\d{1,2}:\d{2}$/,
  /^[\d\s%]+$/,
  /账单详情|全部账单|推荐服务|账单管理|为您推荐|查看往来记录|申请电子回单/,
  /交易成功|等待确认|支付成功|已转账|已收款|当前状态/,
  /更多|请选择|添加|计入收支|5G|蓝牙|WLAN|WiFi|Wi-Fi/,
  /支付宝|Alipay|微信支付|WeChat|花呗|余额宝|蚂蚁/,
  /付款方式|支付奖励|收单机构|账单分类|标签|收付款方|零钱|转账给/,
  /^(商品|商品说明|商户全称|商户名称|交易对方|收款方备注|转账说明|支付时间|转账时间|收款时间|创建时间|备注)$/,
  /^[<>＞]+$/
];

const TIME_LABEL_IN_LINE = /创建时间|付款时间|支付时间|转账时间|收款时间|交易时间|交易号/;

const TIME_ONLY_PATTERN = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/;

/** 匹配 yyyy-MM-dd / yyyy年M月d日 等格式后的 HH:mm(:ss) */
export const OCR_DATETIME_PATTERN =
  /(\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?\s+\d{1,2}:\d{2}(?::\d{2})?)/;

const OCR_DATE_ONLY_PATTERN = /^(\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2})日?$/;

export function splitOcrLines(text: string): string[] {
  return text.split(/[\r\n]+/).map((line: string) => line.trim()).filter((line: string) => line.length > 0);
}

export function isOcrNoiseLine(line: string): boolean {
  const trimmed = line.trim();
  if (trimmed.length === 0) {
    return true;
  }
  for (const pattern of UI_NOISE_PATTERNS) {
    if (pattern.test(trimmed)) {
      return true;
    }
  }
  return false;
}

export function isLikelyMerchantLine(line: string): boolean {
  const trimmed = line.trim();
  if (trimmed.length < 2 || trimmed.length > 50) {
    return false;
  }
  if (isOcrNoiseLine(trimmed)) {
    return false;
  }
  if (/^\d/.test(trimmed) || /¥/.test(trimmed)) {
    return false;
  }
  if (/^[+-][\d,]+\.?\d*$/.test(trimmed)) {
    return false;
  }
  if (/时间|方式|机构|分类|标签|说明|付款|支付|积分|优惠券/.test(trimmed)) {
    return false;
  }
  return true;
}

/** 去掉「计入收支」「收款方全称」等字段值，避免误匹配「收入」「收款」 */
export function stripTypeFalsePositives(text: string): string {
  return text
    .replace(/计入收支/g, '')
    .replace(/收款方全称[：:][^\n]*/g, '')
    .replace(/收款方备注[：:][^\n]*/g, '')
    .replace(/交易对方[：:][^\n]*/g, '')
    .replace(/转账说明[：:][^\n]*/g, '')
    .replace(/商户全称[：:][^\n]*/g, '')
    .replace(/收单机构[：:][^\n]*/g, '')
    .replace(/对方账户[：:][^\n]*/g, '');
}

/** 是否为带正负号的金额行（含 OCR 常见的 ¥-6.00 / -¥6.00） */
export function isSignedAmountLine(line: string): boolean {
  const trimmed = line.trim();
  if (/^-[¥]?\s*[\d,]+\.?\d*$/.test(trimmed) || /^-[\d,]+\.\d{2}$/.test(trimmed)) {
    return true;
  }
  if (/^-¥\s*[\d,]+\.\d{2}$/.test(trimmed) || /^¥-\s*[\d,]+\.\d{2}$/.test(trimmed)) {
    return true;
  }
  if (/^\+[¥]?\s*[\d,]+\.?\d*$/.test(trimmed) || /^\+[\d,]+\.\d{2}$/.test(trimmed)) {
    return true;
  }
  if (/^\+¥\s*[\d,]+\.\d{2}$/.test(trimmed) || /^¥\+\s*[\d,]+\.\d{2}$/.test(trimmed)) {
    return true;
  }
  return false;
}

export function detectTypeFromAmountSign(lines: string[]): TransactionType | null {
  for (const line of lines) {
    const trimmed = line.trim();
    if (/^-[¥]?\s*[\d,]+\.?\d*$/.test(trimmed) || /^-[\d,]+\.\d{2}$/.test(trimmed)) {
      return 'expense';
    }
    if (/^-¥\s*[\d,]+\.\d{2}$/.test(trimmed) || /^¥-\s*[\d,]+\.\d{2}$/.test(trimmed)) {
      return 'expense';
    }
    if (/^\+[¥]?\s*[\d,]+\.?\d*$/.test(trimmed) || /^\+[\d,]+\.\d{2}$/.test(trimmed)) {
      return 'income';
    }
    if (/^\+¥\s*[\d,]+\.\d{2}$/.test(trimmed) || /^¥\+\s*[\d,]+\.\d{2}$/.test(trimmed)) {
      return 'income';
    }
  }
  return null;
}

/** 金额行上一行通常是商户名（如 星巴克 / 全家FamilyMart） */
export function extractMerchantBeforeAmount(lines: string[]): string {
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (!isSignedAmountLine(trimmed)) {
      continue;
    }
    if (i > 0) {
      const candidate = lines[i - 1].trim();
      if (isLikelyMerchantLine(candidate)) {
        return candidate;
      }
    }
  }
  return '';
}

export function shouldSkipAmountLine(line: string): boolean {
  return TIME_LABEL_IN_LINE.test(line);
}

export function parseLabeledValue(line: string, label: string): string {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const inline = line.match(new RegExp(`${escaped}[：:\\s]+(.+)`));
  if (inline && inline[1]) {
    return inline[1].trim();
  }
  return '';
}

/** 行是否为独立标签（精确匹配，避免「商品说明」误匹配「商品」） */
export function isExactLabelLine(line: string, label: string): boolean {
  const trimmed = line.trim();
  if (trimmed === label) {
    return true;
  }
  if (trimmed.startsWith(label)) {
    const rest = trimmed.substring(label.length);
    return rest.length === 0 || /^[：:\s]/.test(rest);
  }
  return false;
}

/** 从「标签行」提取同行值，支持「商品：值」「商品 值」「商品值」 */
export function extractInlineLabelValue(line: string, label: string): string {
  const trimmed = line.trim();
  if (trimmed === label) {
    return '';
  }
  if (!trimmed.startsWith(label)) {
    return '';
  }
  const rest = trimmed.substring(label.length);
  if (rest.length === 0) {
    return '';
  }
  if (/^[：:\s]/.test(rest)) {
    return rest.replace(/^[：:\s]+/, '').trim();
  }
  return rest.trim();
}

function isSplitLabelAt(lines: string[], index: number, label: string): boolean {
  if (index + 1 >= lines.length) {
    return false;
  }
  return lines[index].trim() + lines[index + 1].trim() === label;
}

function extractNoteValueAfterLabel(lines: string[], labelIndex: number, labels: string[]): string {
  for (let j = 1; j <= 3 && labelIndex + j < lines.length; j++) {
    const next = lines[labelIndex + j].trim();
    if (next.length === 0) {
      continue;
    }
    if (isOcrNoiseLine(next)) {
      continue;
    }
    if (labels.some((l: string) => isExactLabelLine(next, l) || isSplitLabelAt(lines, labelIndex + j, l))) {
      break;
    }
    return next;
  }
  return '';
}

export function extractLabeledNote(lines: string[], labels: string[]): string {
  const sortedLabels = [...labels].sort((a: string, b: string) => b.length - a.length);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    for (const label of sortedLabels) {
      if (isSplitLabelAt(lines, i, label)) {
        const splitValue = extractNoteValueAfterLabel(lines, i + 1, sortedLabels);
        if (splitValue.length > 0) {
          return splitValue;
        }
        continue;
      }

      if (!isExactLabelLine(line, label)) {
        continue;
      }

      const inline = extractInlineLabelValue(line, label);
      if (inline.length > 0) {
        return inline;
      }

      const nextLineValue = extractNoteValueAfterLabel(lines, i, sortedLabels);
      if (nextLineValue.length > 0) {
        return nextLineValue;
      }
    }
  }
  return '';
}

/**
 * 解析一行或「日期行 + 下一行时间」组合。
 * 例如 OCR 拆成 `2026-07-01` 与 `09:05:33` 两行时合并时分秒。
 */
export function parseDateTimeFromContext(lines: string[], startIndex: number): number {
  if (startIndex < 0 || startIndex >= lines.length) {
    return 0;
  }
  const line = lines[startIndex].trim();
  if (/\d{1,2}:\d{2}/.test(line)) {
    const fullTs = parseDateTimeString(line);
    if (fullTs > 0) {
      return fullTs;
    }
  }
  const dateOnlyMatch = line.match(OCR_DATE_ONLY_PATTERN);
  if (dateOnlyMatch && dateOnlyMatch[1]) {
    const dateTs = parseDateTimeString(dateOnlyMatch[1]);
    if (dateTs > 0 && startIndex + 1 < lines.length) {
      const timeLine = lines[startIndex + 1].trim();
      const timeMatch = timeLine.match(TIME_ONLY_PATTERN);
      if (timeMatch) {
        const base = new Date(dateTs);
        const hour = Number.parseInt(timeMatch[1]);
        const minute = Number.parseInt(timeMatch[2]);
        const second = timeMatch[3] !== undefined ? Number.parseInt(timeMatch[3]) : 0;
        return new Date(base.getFullYear(), base.getMonth(), base.getDate(), hour, minute, second).getTime();
      }
    }
    if (dateTs > 0) {
      return dateTs;
    }
  }
  const fallbackTs = parseDateTimeString(line);
  return fallbackTs > 0 ? fallbackTs : 0;
}

export function extractLabeledDateTime(lines: string[], labels: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (const label of labels) {
      if (!line.includes(label)) {
        continue;
      }
      const inlineValue = parseLabeledValue(line, label);
      if (inlineValue.length > 0) {
        const inlineTs = parseDateTimeString(inlineValue);
        if (inlineTs > 0) {
          return inlineTs;
        }
      }
      for (let j = 1; j <= 2 && i + j < lines.length; j++) {
        const candidateLine = lines[i + j].trim();
        if (isOcrNoiseLine(candidateLine)) {
          continue;
        }
        const contextTs = parseDateTimeFromContext(lines, i + j);
        if (contextTs > 0) {
          return contextTs;
        }
      }
    }
  }
  return 0;
}

/** 从 OCR 行中提取带正负号的金额（如 -29.00 / ¥-6.00），返回绝对值 */
export function extractSignedAmountValue(line: string): number {
  const trimmed = line.trim();
  const patterns: RegExp[] = [
    /^-¥\s*([\d,]+\.\d{2})$/,
    /^¥-\s*([\d,]+\.\d{2})$/,
    /^-([\d,]+\.\d{2})$/,
    /^\+¥\s*([\d,]+\.\d{2})$/,
    /^¥\+\s*([\d,]+\.\d{2})$/,
    /^\+([\d,]+\.\d{2})$/,
    /[+-]?¥\s*-?\s*([\d,]+\.\d{2})/,
    /([\d,]+\.\d{2})\s*元/
  ];
  for (const pattern of patterns) {
    const match = trimmed.match(pattern);
    if (match && match[1]) {
      const value = Number.parseFloat(match[1].replace(/,/g, ''));
      if (!Number.isNaN(value) && value > 0) {
        return value;
      }
    }
  }
  return 0;
}

export function hasNonZeroTime(timestamp: number): boolean {
  const date = new Date(timestamp);
  return date.getHours() !== 0 || date.getMinutes() !== 0 || date.getSeconds() !== 0;
}
