import { common } from '@kit.AbilityKit';
import { getDefaultCategoryName, resolveImportCategoryName } from '../../database/CategoryDefaults';
import { Category } from '../../models/Category';
import { PaymentPlatform } from '../../models/ParsedTransaction';
import { RecognizedDraft } from '../../models/RecognizedDraft';
import { TransactionType } from '../../models/Transaction';
import { formatAmount } from '../../utils/MoneyUtil';
import { OcrService } from './OcrService';

/** 从 OCR 结果构建多图识别草稿 */
export class ScreenshotDraftBuilder {
  static readonly MAX_SCREENSHOTS: number = 9;

  static createEmptyDraft(imageUri: string, index: number): RecognizedDraft {
    const draft = new RecognizedDraft();
    draft.id = `draft_${Date.now()}_${index}`;
    draft.imageUri = imageUri;
    return draft;
  }

  static async buildFromUri(
    imageUri: string,
    index: number,
    platform: PaymentPlatform,
    categories: Category[]
  ): Promise<RecognizedDraft> {
    const draft = ScreenshotDraftBuilder.createEmptyDraft(imageUri, index);
    try {
      const text = await OcrService.recognizeFromUri(imageUri);
      draft.ocrText = text;
      if (text.trim().length === 0) {
        draft.status = 'failed';
        draft.failReason = '未识别到文字';
        return draft;
      }
      ScreenshotDraftBuilder.applyOcrText(draft, text, platform, categories);
    } catch (_err) {
      draft.status = 'failed';
      draft.failReason = '识别失败';
    }
    return draft;
  }

  static reparseDraft(draft: RecognizedDraft, platform: PaymentPlatform, categories: Category[]): void {
    if (draft.ocrText.trim().length === 0) {
      return;
    }
    ScreenshotDraftBuilder.applyOcrText(draft, draft.ocrText, platform, categories);
  }

  private static applyOcrText(
    draft: RecognizedDraft,
    text: string,
    platform: PaymentPlatform,
    categories: Category[]
  ): void {
    const parsed = OcrService.parseOcrText(text, platform);
    draft.detectedPlatform = OcrService.detectPlatform(text);
    draft.type = parsed.type;
    draft.payee = parsed.payee;
    draft.note = parsed.note;
    draft.occurredAt = parsed.occurredAt > 0 ? parsed.occurredAt : Date.now();
    draft.confidence = parsed.confidence;

    if (parsed.amount <= 0) {
      draft.status = 'failed';
      draft.failReason = '未识别到有效金额';
      draft.amount = 0;
      draft.amountText = '';
      draft.categoryId = 0;
      draft.categoryName = '';
      return;
    }

    draft.status = 'recognized';
    draft.amount = parsed.amount;
    draft.amountText = formatAmount(parsed.amount);
    const category = ScreenshotDraftBuilder.resolveCategory(parsed.type, categories, parsed.categoryName);
    draft.categoryId = category.id;
    draft.categoryName = category.name;
  }

  private static resolveCategory(
    type: TransactionType,
    categories: Category[],
    parsedCategoryName: string = ''
  ): CategoryRef {
    const targetName = parsedCategoryName.length > 0
      ? resolveImportCategoryName(parsedCategoryName, type)
      : getDefaultCategoryName(type);
    let fallbackId = 0;
    let fallbackName = '';
    for (const item of categories) {
      if (item.type !== type) {
        continue;
      }
      if (fallbackId === 0) {
        fallbackId = item.id;
        fallbackName = item.name;
      }
      if (item.name === targetName) {
        return { id: item.id, name: item.name };
      }
    }
    return { id: fallbackId, name: fallbackName.length > 0 ? fallbackName : targetName };
  }

  static async deleteSourceImages(context: common.Context, uris: string[]): Promise<number> {
    if (uris.length === 0) {
      return 0;
    }
    return OcrService.deleteSourceImages(context, uris);
  }

  /** 从已成功入账的草稿中收集可删除的源截图 URI（排除未识别与已从列表移除的项） */
  static collectDeletionUris(savedDrafts: RecognizedDraft[]): string[] {
    const uris: string[] = [];
    for (const draft of savedDrafts) {
      if (draft.isEligibleForSourceDeletion()) {
        uris.push(draft.imageUri);
      }
    }
    return uris;
  }
}

interface CategoryRef {
  id: number;
  name: string;
}
