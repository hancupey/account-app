import { TransactionType } from './Transaction';
import { PaymentPlatform } from './ParsedTransaction';

/** 单张截图识别状态 */
export type RecognizedDraftStatus = 'recognized' | 'failed';

/** 多图 OCR 后的单笔交易草稿 */
export class RecognizedDraft {
  id: string = '';
  imageUri: string = '';
  status: RecognizedDraftStatus = 'failed';
  /** 识别失败原因 */
  failReason: string = '';
  ocrText: string = '';
  detectedPlatform: PaymentPlatform = 'unknown';
  amount: number = 0;
  amountText: string = '';
  type: TransactionType = 'expense';
  payee: string = '';
  note: string = '';
  occurredAt: number = 0;
  categoryId: number = 0;
  categoryName: string = '';
  confidence: number = 0;
  /** 编辑版本号，用于 ForEach 键刷新列表 */
  revision: number = 0;

  isSavable(): boolean {
    return this.status === 'recognized' && this.amount > 0 && this.categoryId > 0;
  }

  /** 仅成功识别且仍在预览列表中的草稿，入账后才可删除源截图 */
  isEligibleForSourceDeletion(): boolean {
    return this.isSavable();
  }
}
