/**
 * 简易 CSV 解析（支持引号包裹字段、UTF-8 BOM）。
 * 微信/支付宝导出 CSV 通常为逗号分隔、首行表头。
 */
export class CsvUtil {
  static parse(content: string): string[][] {
    const text = CsvUtil.stripBom(content);
    const rows: string[][] = [];
    let row: string[] = [];
    let field = '';
    let inQuotes = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i);
      if (inQuotes) {
        if (ch === '"') {
          if (i + 1 < text.length && text.charAt(i + 1) === '"') {
            field += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field += ch;
        }
      } else if (ch === '"') {
        inQuotes = true;
      } else if (ch === ',') {
        row.push(CsvUtil.normalizeField(field));
        field = '';
      } else if (ch === '\n' || ch === '\r') {
        if (ch === '\r' && i + 1 < text.length && text.charAt(i + 1) === '\n') {
          i++;
        }
        row.push(CsvUtil.normalizeField(field));
        if (row.some((cell: string) => cell.length > 0)) {
          rows.push(row);
        }
        row = [];
        field = '';
      } else {
        field += ch;
      }
    }
    row.push(CsvUtil.normalizeField(field));
    if (row.some((cell: string) => cell.length > 0)) {
      rows.push(row);
    }
    return rows;
  }

  private static normalizeField(field: string): string {
    let normalized = field.trim();
    if (normalized.length > 0 && normalized.charCodeAt(0) === 0xFEFF) {
      normalized = normalized.substring(1).trim();
    }
    return normalized.replace(/[\u200B-\u200D\uFEFF]/g, '');
  }

  private static stripBom(text: string): string {
    if (text.length > 0 && text.charCodeAt(0) === 0xFEFF) {
      return text.substring(1);
    }
    if (text.startsWith('\uFEFF')) {
      return text.substring(1);
    }
    return text;
  }
}
