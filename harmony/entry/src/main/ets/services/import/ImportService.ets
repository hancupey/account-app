import { picker, fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { getDefaultCategoryName, resolveImportCategoryName } from '../../database/CategoryDefaults';
import { ImportDraft, ImportParseResult } from '../../models/ImportDraft';
import { PaymentPlatform } from '../../models/ParsedTransaction';
import { Category } from '../../models/Category';
import { AlipayFileParser } from './AlipayFileParser';
import { WechatFileParser } from './WechatFileParser';
import { BillHeaderUtil } from './BillHeaderUtil';
import { CsvUtil } from './CsvUtil';
import { MinimalXlsxReader } from './MinimalXlsxReader';

export class ImportService {
  /** 选择账单文件：支付宝 CSV、微信 XLSX */
  static async pickFile(): Promise<string> {
    const documentPicker = new picker.DocumentViewPicker();
    const result = await documentPicker.select({
      maxSelectNumber: 1,
      fileSuffixFilters: ['.csv', '.xlsx', '.xls']
    });
    if (result.length === 0) {
      return '';
    }
    return result[0];
  }

  static getFileName(uri: string): string {
    const parts = uri.split('/');
    return parts.length > 0 ? parts[parts.length - 1] : uri;
  }

  static isXlsx(uri: string): boolean {
    const lower = uri.toLowerCase();
    return lower.endsWith('.xlsx') || lower.endsWith('.xls');
  }

  static async readBinaryContent(uri: string): Promise<ArrayBuffer> {
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      return buffer;
    } finally {
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  static async readTextContent(uri: string): Promise<string> {
    const bytes = new Uint8Array(await ImportService.readBinaryContent(uri));
    if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
      const utf8Decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return utf8Decoder.decodeToString(bytes, { stream: false });
    }
    const utf8Decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    const gbDecoder = util.TextDecoder.create('gbk', { ignoreBOM: true });
    const utf8Text = utf8Decoder.decodeToString(bytes, { stream: false });
    const gbText = gbDecoder.decodeToString(bytes, { stream: false });
    const utf8HasHeader = BillHeaderUtil.containsBillHeaderMarkers(utf8Text);
    const gbHasHeader = BillHeaderUtil.containsBillHeaderMarkers(gbText);
    if (gbHasHeader && !utf8HasHeader) {
      return gbText;
    }
    if (utf8HasHeader && !gbHasHeader) {
      return utf8Text;
    }
    if (ImportService.countCjkChars(gbText) > ImportService.countCjkChars(utf8Text)) {
      return gbText;
    }
    return utf8Text;
  }

  private static countCjkChars(text: string): number {
    let count = 0;
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        count++;
      }
    }
    return count;
  }

  static parseFile(content: string, fileName: string, forcePlatform?: PaymentPlatform): ImportParseResult {
    const rows = CsvUtil.parse(content);
    return ImportService.parseRows(rows, fileName, forcePlatform);
  }

  private static resolveForcePlatform(forcePlatform?: PaymentPlatform): PaymentPlatform | undefined {
    if (forcePlatform === undefined || forcePlatform === 'unknown') {
      return undefined;
    }
    return forcePlatform;
  }

  static detectPlatformFromRows(rows: string[][]): PaymentPlatform {
    if (rows.length === 0) {
      return 'unknown';
    }
    const alipayHeader = BillHeaderUtil.findAlipayHeaderRow(rows);
    if (alipayHeader >= 0 && AlipayFileParser.canParse(rows[alipayHeader])) {
      return 'alipay';
    }
    const wechatHeader = BillHeaderUtil.findWechatHeaderRow(rows);
    if (wechatHeader >= 0 && WechatFileParser.canParse(rows[wechatHeader])) {
      return 'wechat';
    }
    const headerRow = BillHeaderUtil.findGenericHeaderRow(rows);
    if (headerRow >= 0) {
      const headers = rows[headerRow];
      if (WechatFileParser.canParse(headers)) {
        return 'wechat';
      }
      if (AlipayFileParser.canParse(headers)) {
        return 'alipay';
      }
    }
    return 'unknown';
  }

  static parseRows(
    rows: string[][],
    fileName: string,
    forcePlatform?: PaymentPlatform
  ): ImportParseResult {
    const forced = ImportService.resolveForcePlatform(forcePlatform);
    if (forced === 'wechat') {
      return WechatFileParser.parseRows(rows, fileName);
    }
    if (forced === 'alipay') {
      return AlipayFileParser.parseRows(rows, fileName);
    }
    if (rows.length === 0) {
      const empty = new ImportParseResult();
      empty.fileName = fileName;
      empty.errors.push('无法解析文件内容');
      return empty;
    }
    const detected = ImportService.detectPlatformFromRows(rows);
    if (detected === 'wechat') {
      return WechatFileParser.parseRows(rows, fileName);
    }
    if (detected === 'alipay') {
      return AlipayFileParser.parseRows(rows, fileName);
    }
    const fallback = new ImportParseResult();
    fallback.fileName = fileName;
    fallback.errors.push('无法识别账单来源，请手动选择微信或支付宝后重新解析');
    return fallback;
  }

  /** 解析微信 xlsx：复制到沙箱 → zlib 解压 → 读取 sheet1 */
  static async parseXlsxFile(
    fileUri: string,
    fileName: string,
    cacheDir: string,
    forcePlatform?: PaymentPlatform
  ): Promise<ImportParseResult> {
    const forced = ImportService.resolveForcePlatform(forcePlatform);
    if (forced === 'alipay') {
      const result = new ImportParseResult();
      result.fileName = fileName;
      result.errors.push('支付宝账单请使用 CSV 格式导出');
      return result;
    }

    const workDir = `${cacheDir}/bill_import_work`;
    const xlsxPath = `${workDir}/source.xlsx`;
    const extractDir = `${workDir}/extract`;
    try {
      MinimalXlsxReader.ensureDir(workDir);
      MinimalXlsxReader.removeDirRecursive(extractDir);
      MinimalXlsxReader.ensureDir(extractDir);

      const buffer = await ImportService.readBinaryContent(fileUri);
      ImportService.writeBinaryFile(xlsxPath, buffer);
      await MinimalXlsxReader.extractToDir(xlsxPath, extractDir);
      const rows = MinimalXlsxReader.readSheetRows(extractDir);
      return WechatFileParser.parseRows(rows, fileName);
    } catch (_err) {
      const result = new ImportParseResult();
      result.fileName = fileName;
      result.errors.push('无法读取 xlsx 文件，请确认是微信账单导出');
      return result;
    } finally {
      MinimalXlsxReader.removeDirRecursive(workDir);
    }
  }

  static async parseFromUri(
    fileUri: string,
    fileName: string,
    cacheDir: string,
    forcePlatform?: PaymentPlatform
  ): Promise<ImportParseResult> {
    const forced = ImportService.resolveForcePlatform(forcePlatform);
    if (forced === 'wechat' && !ImportService.isXlsx(fileUri)) {
      const result = new ImportParseResult();
      result.fileName = fileName;
      result.errors.push('微信账单请使用 xlsx 格式导出');
      return result;
    }
    if (ImportService.isXlsx(fileUri)) {
      return ImportService.parseXlsxFile(fileUri, fileName, cacheDir, forcePlatform);
    }
    const content = await ImportService.readTextContent(fileUri);
    return ImportService.parseFile(content, fileName, forcePlatform);
  }

  private static writeBinaryFile(path: string, buffer: ArrayBuffer): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, buffer);
    } finally {
      fileIo.closeSync(file);
    }
  }

  /** 将 categoryName 映射到本地 categoryId */
  static resolveCategoryIds(drafts: ImportDraft[], categories: Category[]): ImportDraft[] {
    const categoryByName = new Map<string, Category>();
    for (const cat of categories) {
      categoryByName.set(`${cat.type}:${cat.name}`, cat);
    }
    for (const draft of drafts) {
      const resolvedName = resolveImportCategoryName(draft.categoryName, draft.type);
      const key = `${draft.type}:${resolvedName}`;
      const matched = categoryByName.get(key);
      if (matched) {
        draft.categoryId = matched.id;
        draft.categoryName = resolvedName;
      } else {
        const fallbackName = getDefaultCategoryName(draft.type);
        const fallback = categoryByName.get(`${draft.type}:${fallbackName}`);
        draft.categoryId = fallback !== undefined ? fallback.id : 0;
        draft.categoryName = fallbackName;
      }
    }
    return drafts;
  }
}
