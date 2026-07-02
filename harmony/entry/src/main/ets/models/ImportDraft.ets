import { TransactionType } from './Transaction';
import { PaymentPlatform } from './ParsedTransaction';

/** 待导入的单条账单草稿 */
export class ImportDraft {
  amount: number = 0;
  type: TransactionType = 'expense';
  categoryId: number = 0;
  categoryName: string = '';
  /** 支付对象 / 商户名 */
  payee: string = '';
  note: string = '';
  occurredAt: number = 0;
  source: PaymentPlatform = 'unknown';
  /** 去重键：amount|type|occurredAt|payee */
  dedupeKey: string = '';
}

/** 文件解析结果 */
export class ImportParseResult {
  drafts: ImportDraft[] = [];
  platform: PaymentPlatform = 'unknown';
  fileName: string = '';
  errors: string[] = [];
}
