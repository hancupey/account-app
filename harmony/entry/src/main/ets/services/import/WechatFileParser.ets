import { ImportDraft, ImportParseResult } from '../../models/ImportDraft';
import { TransactionType } from '../../models/Transaction';
import { parseDateTimeOrNow } from '../../utils/DateUtil';
import { BillHeaderUtil } from './BillHeaderUtil';
import { CsvUtil } from './CsvUtil';
import { ImportDedupeUtil } from './ImportDedupeUtil';
import { WechatCategoryMapper } from './WechatCategoryMapper';

/**
 * 微信支付账单解析（CSV 或 XLSX 解压后的行数据）。
 *
 * 微信 App 导出 xlsx 表头（第 18 行左右）：
 * | 交易时间 | 交易类型 | 交易对方 | 商品 | 收/支 | 金额(元) | 支付方式 | 当前状态 | 交易单号 | 商户单号 | 备注 |
 */
export class WechatFileParser {
  static readonly HEADER_MARKERS: string[] = ['交易时间', '收/支', '金额'];

  static canParse(headers: string[]): boolean {
    const joined = BillHeaderUtil.rowJoined(headers);
    if (BillHeaderUtil.containsTimeMarker(joined) &&
      BillHeaderUtil.containsAny(joined, BillHeaderUtil.INCOME_EXPENSE_MARKERS) &&
      BillHeaderUtil.containsAny(joined, BillHeaderUtil.AMOUNT_MARKERS)) {
      return joined.includes('交易类型') || joined.includes('商品');
    }
    return joined.includes('交易时间') && joined.includes('微信');
  }

  static parseCsv(content: string, fileName: string): ImportParseResult {
    return WechatFileParser.parseRows(CsvUtil.parse(content), fileName);
  }

  static parseRows(rows: string[][], fileName: string): ImportParseResult {
    const result = new ImportParseResult();
    result.platform = 'wechat';
    result.fileName = fileName;
    if (rows.length < 2) {
      result.errors.push('文件内容为空或格式不正确');
      return result;
    }
    const headerRowIndex = BillHeaderUtil.findWechatHeaderRow(rows);
    if (headerRowIndex < 0) {
      result.errors.push('未找到微信账单表头（需包含「交易时间」「收/支」「金额(元)」等列）');
      return result;
    }
    const headers = rows[headerRowIndex];
    const colMap = BillHeaderUtil.buildColumnMap(headers);
    for (let i = headerRowIndex + 1; i < rows.length; i++) {
      const row = rows[i];
      if (row.length < 3) {
        continue;
      }
      const draft = WechatFileParser.parseRow(row, colMap);
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
    const amountIdx = BillHeaderUtil.colIndex(colMap, ['金额(元)', '金额', '金额（元）']);
    const counterpartyIdx = BillHeaderUtil.colIndex(colMap, ['交易对方', '对方']);
    const productIdx = BillHeaderUtil.colIndex(colMap, ['商品', '商品说明']);
    const noteIdx = BillHeaderUtil.colIndex(colMap, ['备注']);
    const transactionTypeIdx = BillHeaderUtil.colIndex(colMap, ['交易类型', '类型']);
    const statusIdx = BillHeaderUtil.colIndex(colMap, ['当前状态', '交易状态']);

    if (statusIdx >= 0 && WechatFileParser.isFailedStatus(row[statusIdx])) {
      return null;
    }

    const draft = new ImportDraft();
    draft.source = 'wechat';

    if (amountIdx >= 0) {
      draft.amount = WechatFileParser.parseAmount(row[amountIdx]);
    }

    const incomeExpenseLabel = typeIdx >= 0 ? row[typeIdx].trim() : '';
    if (WechatFileParser.isNeutralType(incomeExpenseLabel)) {
      return null;
    }

    const csvType: TransactionType = incomeExpenseLabel.length > 0
      ? WechatFileParser.parseType(incomeExpenseLabel)
      : 'expense';

    if (timeIdx >= 0 && row[timeIdx].trim().length > 0) {
      draft.occurredAt = parseDateTimeOrNow(row[timeIdx]);
    } else {
      draft.occurredAt = Date.now();
    }

    const counterparty = counterpartyIdx >= 0 ? row[counterpartyIdx].trim() : '';
    const productName = productIdx >= 0 ? row[productIdx].trim() : '';
    const transactionType = transactionTypeIdx >= 0 ? row[transactionTypeIdx].trim() : '';

    if (counterparty.length > 0) {
      draft.payee = counterparty;
    }
    if (productName.length > 0 && productName !== '/') {
      draft.note = productName;
    }
    if (noteIdx >= 0 && row[noteIdx].trim().length > 0) {
      const remark = row[noteIdx].trim();
      if (remark !== '/') {
        draft.note = draft.note.length > 0 ? `${draft.note} · ${remark}` : remark;
      }
    }

    const mapped = WechatCategoryMapper.map({
      transactionType,
      productName,
      counterparty,
      incomeExpenseLabel,
      csvType
    });
    draft.type = mapped.type;
    draft.categoryName = mapped.categoryName;
    return draft;
  }

  /** 仅映射分类名（兼容测试与外部调用） */
  static mapCategory(
    transactionTypeLabel: string,
    type: TransactionType,
    productName: string = '',
    counterparty: string = ''
  ): string {
    return WechatCategoryMapper.mapCategoryNameOnly(
      transactionTypeLabel,
      type,
      productName,
      counterparty
    );
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
    return /关闭|失败|取消|已全额退款|等待/.test(normalized);
  }
}
