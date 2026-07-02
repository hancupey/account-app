/**
 * 账单表头识别：归一化单元格、扫描前 N 行、兼容支付宝/微信列名别名。
 */
export class BillHeaderUtil {
  static readonly SCAN_LIMIT = 60;
  static readonly TIME_MARKERS: string[] = ['交易时间', '时间'];
  static readonly INCOME_EXPENSE_MARKERS: string[] = ['收/支', '收支'];
  static readonly AMOUNT_MARKERS: string[] = ['金额(元)', '金额（元）', '金额'];

  static normalizeCell(text: string): string {
    let normalized = text.trim();
    if (normalized.length > 0 && normalized.charCodeAt(0) === 0xFEFF) {
      normalized = normalized.substring(1).trim();
    }
    return normalized.replace(/[\u200B-\u200D\uFEFF]/g, '');
  }

  static rowJoined(row: string[]): string {
    return row.map((cell: string) => BillHeaderUtil.normalizeCell(cell)).join(',');
  }

  static containsAny(text: string, markers: string[]): boolean {
    return markers.some((marker: string) => text.includes(marker));
  }

  static containsTimeMarker(text: string): boolean {
    return BillHeaderUtil.containsAny(text, BillHeaderUtil.TIME_MARKERS);
  }

  static containsBillHeaderMarkers(text: string): boolean {
    if (!BillHeaderUtil.containsTimeMarker(text)) {
      return false;
    }
    return BillHeaderUtil.containsAny(text, BillHeaderUtil.INCOME_EXPENSE_MARKERS) ||
      BillHeaderUtil.containsAny(text, BillHeaderUtil.AMOUNT_MARKERS);
  }

  static findGenericHeaderRow(rows: string[][]): number {
    const limit = Math.min(rows.length, BillHeaderUtil.SCAN_LIMIT);
    for (let i = 0; i < limit; i++) {
      const joined = BillHeaderUtil.rowJoined(rows[i]);
      if (joined.includes('交易时间') &&
        BillHeaderUtil.containsAny(joined, BillHeaderUtil.INCOME_EXPENSE_MARKERS) &&
        BillHeaderUtil.containsAny(joined, BillHeaderUtil.AMOUNT_MARKERS)) {
        return i;
      }
    }
    for (let i = 0; i < limit; i++) {
      if (BillHeaderUtil.rowJoined(rows[i]).includes('交易时间')) {
        return i;
      }
    }
    return -1;
  }

  static findAlipayHeaderRow(rows: string[][]): number {
    const limit = Math.min(rows.length, BillHeaderUtil.SCAN_LIMIT);
    for (let i = 0; i < limit; i++) {
      const joined = BillHeaderUtil.rowJoined(rows[i]);
      if (BillHeaderUtil.containsTimeMarker(joined) &&
        BillHeaderUtil.containsAny(joined, BillHeaderUtil.INCOME_EXPENSE_MARKERS) &&
        (joined.includes('交易分类') || joined.includes('商品说明'))) {
        return i;
      }
    }
    for (let i = 0; i < limit; i++) {
      const joined = BillHeaderUtil.rowJoined(rows[i]);
      if (BillHeaderUtil.containsTimeMarker(joined) &&
        BillHeaderUtil.containsAny(joined, BillHeaderUtil.INCOME_EXPENSE_MARKERS)) {
        return i;
      }
    }
    return -1;
  }

  static findWechatHeaderRow(rows: string[][]): number {
    const limit = Math.min(rows.length, BillHeaderUtil.SCAN_LIMIT);
    for (let i = 0; i < limit; i++) {
      const joined = BillHeaderUtil.rowJoined(rows[i]);
      if (BillHeaderUtil.containsTimeMarker(joined) &&
        (BillHeaderUtil.containsAny(joined, BillHeaderUtil.INCOME_EXPENSE_MARKERS) ||
          BillHeaderUtil.containsAny(joined, BillHeaderUtil.AMOUNT_MARKERS)) &&
        (joined.includes('交易类型') || joined.includes('商品'))) {
        return i;
      }
    }
    return -1;
  }

  static buildColumnMap(headers: string[]): Map<string, number> {
    const map = new Map<string, number>();
    for (let i = 0; i < headers.length; i++) {
      const normalized = BillHeaderUtil.normalizeCell(headers[i]);
      if (normalized.length > 0) {
        map.set(normalized, i);
      }
    }
    return map;
  }

  static colIndex(map: Map<string, number>, names: string[]): number {
    for (const name of names) {
      const idx = map.get(name);
      if (idx !== undefined) {
        return idx;
      }
    }
    return -1;
  }
}
