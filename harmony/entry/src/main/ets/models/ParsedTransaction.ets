import { TransactionType } from './Transaction';

/** 支付平台来源 */
export type PaymentPlatform = 'wechat' | 'alipay' | 'unknown';

/** OCR / 文件解析后的单笔交易草稿 */
export class ParsedTransaction {
  amount: number = 0;
  type: TransactionType = 'expense';
  /** 支付对象 / 商户名（如 示例商户、测试商户） */
  payee: string = '';
  note: string = '';
  occurredAt: number = 0;
  source: PaymentPlatform = 'unknown';
  /** 原始 OCR 文本，便于用户手动修正 */
  rawText: string = '';
  /** 解析置信度 0~1，低于阈值时提示用户核对 */
  confidence: number = 0;
  /** 映射后的应用分类名（如 日用）；空则使用收支类型默认分类 */
  categoryName: string = '';
}
