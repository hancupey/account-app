import { zlib } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { formatExcelSerialDateTime } from '../../utils/DateUtil';

/**
 * 轻量 XLSX 读取器：解压 OOXML（zip）并解析 sharedStrings + sheet1。
 * 适用于微信账单等单表、结构简单的导出文件。
 */
export class MinimalXlsxReader {
  static async extractToDir(xlsxPath: string, outDir: string): Promise<void> {
    MinimalXlsxReader.ensureDir(outDir);
    const options: zlib.Options = {};
    await zlib.decompressFile(xlsxPath, outDir, options);
  }

  static readSheetRows(extractDir: string): string[][] {
    const sharedStrings = MinimalXlsxReader.readSharedStrings(extractDir);
    const sheetPath = `${extractDir}/xl/worksheets/sheet1.xml`;
    const sheetXml = MinimalXlsxReader.readUtf8File(sheetPath);
    return MinimalXlsxReader.parseSheetXml(sheetXml, sharedStrings);
  }

  static ensureDir(dir: string): void {
    try {
      fileIo.mkdirSync(dir, true);
    } catch (_err) {
      // 目录已存在
    }
  }

  static removeDirRecursive(dir: string): void {
    try {
      fileIo.rmdirSync(dir);
    } catch (_err) {
      // 忽略清理失败
    }
  }

  private static readUtf8File(path: string): string {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      const bytes = new Uint8Array(buffer);
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeToString(bytes, { stream: false });
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static readSharedStrings(extractDir: string): string[] {
    const path = `${extractDir}/xl/sharedStrings.xml`;
    try {
      const xml = MinimalXlsxReader.readUtf8File(path);
      return MinimalXlsxReader.parseSharedStrings(xml);
    } catch (_err) {
      return [];
    }
  }

  private static parseSharedStrings(xml: string): string[] {
    const strings: string[] = [];
    let searchFrom = 0;
    while (true) {
      const start = xml.indexOf('<si', searchFrom);
      if (start < 0) {
        break;
      }
      const end = xml.indexOf('</si>', start);
      if (end < 0) {
        break;
      }
      const block = xml.substring(start, end);
      strings.push(MinimalXlsxReader.extractTextFromSiBlock(block));
      searchFrom = end + 5;
    }
    return strings;
  }

  private static extractTextFromSiBlock(block: string): string {
    let text = '';
    let searchFrom = 0;
    while (true) {
      const tStart = block.indexOf('<t', searchFrom);
      if (tStart < 0) {
        break;
      }
      const contentStart = block.indexOf('>', tStart);
      if (contentStart < 0) {
        break;
      }
      const contentEnd = block.indexOf('</t>', contentStart);
      if (contentEnd < 0) {
        break;
      }
      text += MinimalXlsxReader.decodeXmlEntities(
        block.substring(contentStart + 1, contentEnd)
      );
      searchFrom = contentEnd + 4;
    }
    return text;
  }

  private static decodeXmlEntities(text: string): string {
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'");
  }

  private static parseSheetXml(xml: string, sharedStrings: string[]): string[][] {
    const sparseRows = new Map<number, Map<number, string>>();
    let maxRow = 0;
    let maxCol = 0;
    let searchFrom = 0;
    while (true) {
      const rowStart = xml.indexOf('<row', searchFrom);
      if (rowStart < 0) {
        break;
      }
      const rowEnd = xml.indexOf('</row>', rowStart);
      if (rowEnd < 0) {
        break;
      }
      const rowBlock = xml.substring(rowStart, rowEnd);
      const rowNum = MinimalXlsxReader.parseRowNumber(rowBlock);
      if (rowNum > 0) {
        const cells = MinimalXlsxReader.parseCellsInRow(rowBlock, sharedStrings);
        sparseRows.set(rowNum, cells);
        if (rowNum > maxRow) {
          maxRow = rowNum;
        }
        cells.forEach((_value: string, col: number) => {
          if (col > maxCol) {
            maxCol = col;
          }
        });
      }
      searchFrom = rowEnd + 6;
    }

    const rows: string[][] = [];
    for (let r = 1; r <= maxRow; r++) {
      const rowCells = sparseRows.get(r);
      const row: string[] = [];
      for (let c = 0; c <= maxCol; c++) {
        row.push(rowCells !== undefined && rowCells.has(c) ? rowCells.get(c)! : '');
      }
      if (row.some((cell: string) => cell.length > 0)) {
        rows.push(row);
      }
    }
    return rows;
  }

  private static parseRowNumber(rowBlock: string): number {
    const match = rowBlock.match(/\br="(\d+)"/);
    if (match === null) {
      return 0;
    }
    return Number.parseInt(match[1]);
  }

  private static parseCellsInRow(rowBlock: string, sharedStrings: string[]): Map<number, string> {
    const cells = new Map<number, string>();
    let searchFrom = 0;
    while (true) {
      const cellStart = rowBlock.indexOf('<c ', searchFrom);
      if (cellStart < 0) {
        break;
      }
      const cellEnd = rowBlock.indexOf('</c>', cellStart);
      const selfClose = rowBlock.indexOf('/>', cellStart);
      let cellBlock = '';
      let nextFrom = 0;
      if (cellEnd >= 0 && (selfClose < 0 || cellEnd < selfClose)) {
        cellBlock = rowBlock.substring(cellStart, cellEnd + 4);
        nextFrom = cellEnd + 4;
      } else if (selfClose >= 0) {
        cellBlock = rowBlock.substring(cellStart, selfClose + 2);
        nextFrom = selfClose + 2;
      } else {
        break;
      }

      const refMatch = cellBlock.match(/\br="([A-Z]+)(\d+)"/);
      const typeMatch = cellBlock.match(/\bt="([^"]+)"/);
      const valueMatch = cellBlock.match(/<v>([\s\S]*?)<\/v>/);
      if (refMatch !== null && valueMatch !== null) {
        const colIndex = MinimalXlsxReader.colLettersToIndex(refMatch[1]);
        const rawValue = valueMatch[1].trim();
        const cellType = typeMatch !== null ? typeMatch[1] : '';
        cells.set(colIndex, MinimalXlsxReader.resolveCellValue(rawValue, cellType, sharedStrings));
      }
      searchFrom = nextFrom;
    }
    return cells;
  }

  private static resolveCellValue(rawValue: string, cellType: string, sharedStrings: string[]): string {
    if (cellType === 's') {
      const idx = Number.parseInt(rawValue);
      if (!Number.isNaN(idx) && idx >= 0 && idx < sharedStrings.length) {
        return sharedStrings[idx];
      }
      return '';
    }
    const numeric = Number.parseFloat(rawValue);
    if (!Number.isNaN(numeric) && numeric > 30000 && numeric < 60000 && rawValue.includes('.')) {
      return formatExcelSerialDateTime(numeric);
    }
    return rawValue;
  }

  private static colLettersToIndex(letters: string): number {
    let index = 0;
    for (let i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.charCodeAt(i) - 64);
    }
    return index - 1;
  }
}
