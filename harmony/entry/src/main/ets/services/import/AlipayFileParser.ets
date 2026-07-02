import { ImportDraft, ImportParseResult } from '../../models/ImportDraft';
import { TransactionType } from '../../models/Transaction';
import { parseDateTimeOrNow } from '../../utils/DateUtil';
import { AlipayCategoryMapper } from './AlipayCategoryMapper';
import { BillHeaderUtil } from './BillHeaderUtil';
import { CsvUtil } from './CsvUtil';
import { ImportDedupeUtil } from './ImportDedupeUtil';

/**
 * 支付宝账单 CSV 导出解析。
 *
 * 实际表头（第 24 行左右，GBK/UTF-8）：
 * | 交易时间 | 交易分类 | 交易对方 | 对方账号 | 商品说明 | 收/支 | 金额 | 收/付款方式 | 交易状态 | 交易订单号 | 商家订单号 | 备注 |
 */
export class AlipayFileParser {
  static readonly HEADER_MARKERS: string[] = ['交易时间', '收/支', '金额'];

  static canParse(headers: string[]): boolean {
    const joined = BillHeaderUtil.rowJoined(headers);
    return joined.includes('交易时间') &&
      BillHeaderUtil.containsAny(joined, BillHeaderUtil.INCOME_EXPENSE_MARKERS) &&
      (joined.includes('交易分类') || joined.includes('商品说明'));
  }

  static parseCsv(content: string, fileName: string): ImportParseResult {
    return AlipayFileParser.parseRows(CsvUtil.parse(content), fileName);
  }

  static parseRows(rows: string[][], fileName: string): ImportParseResult {
    const result = new ImportParseResult();
    result.platform = 'alipay';
    result.fileName = fileName;
    if (rows.length < 2) {
      result.errors.push('文件内容为空或格式不正确');
      return result;
    }
    const headerRowIndex = BillHeaderUtil.findAlipayHeaderRow(rows);
    if (headerRowIndex < 0) {
      result.errors.push('未找到支付宝账单表头（需包含「交易时间」「收/支」等列）');
      return result;
    }
    const headers = rows[headerRowIndex];
    const colMap = BillHeaderUtil.buildColumnMap(headers);
    for (let i = headerRowIndex + 1; i < rows.length; i++) {
      const row = rows[i];
      if (row.length < 3) {
        continue;
      }
      const draft = AlipayFileParser.parseRow(row, colMap);
      if (draft !== null && draft.amount > 0) {
        ImportDedupeUtil.applyToDraft(draft);
        result.drafts.push(draft);
      }
    }
    return result;
  }

  private static parseRow(row: string[], colMap: Map<string, number>): ImportDraft | null {
    const timeIdx = BillHeaderUtil.colIndex(colMap, ['交易时间', '时间']);
    const typeIdx = BillHeaderUtil.colIndex(colMap, ['收/支', '收支']);
    const amountIdx = BillHeaderUtil.colIndex(colMap, ['金额', '金额(元)', '金额（元）']);
    const counterpartyIdx = BillHeaderUtil.colIndex(colMap, ['交易对方', '对方']);
    const productIdx = BillHeaderUtil.colIndex(colMap, ['商品说明', '商品']);
    const categoryIdx = BillHeaderUtil.colIndex(colMap, ['交易分类', '类型']);
    const noteIdx = BillHeaderUtil.colIndex(colMap, ['备注']);
    const statusIdx = BillHeaderUtil.colIndex(colMap, ['交易状态', '当前状态']);

    const incomeExpenseLabel = typeIdx >= 0 ? row[typeIdx].trim() : '';
    if (AlipayFileParser.isNeutralType(incomeExpenseLabel)) {
      return null;
    }
    if (statusIdx >= 0 && AlipayFileParser.isFailedStatus(row[statusIdx])) {
      return null;
    }

    const draft = new ImportDraft();
    draft.source = 'alipay';

    if (amountIdx >= 0) {
      draft.amount = AlipayFileParser.parseAmount(row[amountIdx]);
    }
    const csvType: TransactionType = incomeExpenseLabel.length > 0
      ? AlipayFileParser.parseType(incomeExpenseLabel)
      : 'expense';
    draft.type = csvType;
    if (timeIdx >= 0 && row[timeIdx].trim().length > 0) {
      draft.occurredAt = parseDateTimeOrNow(row[timeIdx]);
    } else {
      draft.occurredAt = Date.now();
    }
    if (counterpartyIdx >= 0 && row[counterpartyIdx].trim().length > 0) {
      draft.payee = row[counterpartyIdx].trim();
    }
    if (productIdx >= 0 && row[productIdx].trim().length > 0) {
      draft.note = row[productIdx].trim();
    }
    if (noteIdx >= 0 && row[noteIdx].trim().length > 0) {
      const remark = row[noteIdx].trim();
      draft.note = draft.note.length > 0 ? `${draft.note} · ${remark}` : remark;
    }
    const categoryLabel = categoryIdx >= 0 ? row[categoryIdx] : '';
    const mapped = AlipayCategoryMapper.mapCategory(categoryLabel, csvType);
    draft.type = mapped.type;
    draft.categoryName = mapped.categoryName;
    return draft;
  }

  /** 仅映射分类名（兼容测试与外部调用）；类型请用 {@link mapCategoryWithType} */
  static mapCategory(categoryLabel: string, type: TransactionType): string {
    return AlipayCategoryMapper.mapCategory(categoryLabel, type).categoryName;
  }

  /** 映射分类名并应用支付宝分类对收支类型的覆盖规则 */
  static mapCategoryWithType(categoryLabel: string, csvType: TransactionType): TransactionType {
    return AlipayCategoryMapper.mapCategory(categoryLabel, csvType).type;
  }

  private static parseAmount(text: string): number {
    const cleaned = text.replace(/[¥,\s]/g, '').replace(/[^\d.-]/g, '');
    const value = Number.parseFloat(cleaned);
    return Number.isNaN(value) ? 0 : Math.abs(value);
  }

  private static parseType(text: string): TransactionType {
    const normalized = text.trim();
    if (/收入|收/.test(normalized) && !/支出/.test(normalized)) {
      return 'income';
    }
    if (/支出|付/.test(normalized)) {
      return 'expense';
    }
    return 'expense';
  }

  private static isNeutralType(text: string): boolean {
    return /不计收支|中性/.test(text.trim());
  }

  private static isFailedStatus(text: string): boolean {
    const normalized = text.trim();
    if (normalized.length === 0) {
      return false;
    }
    return /关闭|失败|取消|等待/.test(normalized);
  }
}
