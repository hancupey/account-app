import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { Category } from '../../models/Category';
import { Transaction } from '../../models/Transaction';
import {
  BACKUP_APP_ID,
  BACKUP_VERSION,
  BackupCategory,
  BackupExportResult,
  BackupParseResult,
  BackupPayload,
  BackupTransaction,
  RestoreMode,
  RestoreResult
} from '../../models/BackupData';
import { CategoryRepository } from '../../database/CategoryRepository';
import { TransactionRepository } from '../../database/TransactionRepository';
import { getDefaultCategoryName } from '../../database/CategoryDefaults';
import { ImportService } from '../import/ImportService';

const BACKUP_LOG_DOMAIN: number = 0x0000;
const BACKUP_LOG_TAG: string = 'BackupService';

export class BackupService {
  private static categoryRepo: CategoryRepository = new CategoryRepository();
  private static transactionRepo: TransactionRepository = new TransactionRepository();

  /** 选择备份 JSON 文件 */
  static async pickBackupFile(): Promise<string> {
    const documentPicker = new picker.DocumentViewPicker();
    const result = await documentPicker.select({
      maxSelectNumber: 1,
      fileSuffixFilters: ['.json']
    });
    if (result.length === 0) {
      return '';
    }
    return result[0];
  }

  /** 从数据库构建备份载荷 */
  static async buildPayload(): Promise<BackupPayload> {
    const categories = await BackupService.categoryRepo.listAll();
    const transactions = await BackupService.transactionRepo.listAll();
    const payload = new BackupPayload();
    payload.version = BACKUP_VERSION;
    payload.exportedAt = Date.now();
    payload.app = BACKUP_APP_ID;
    payload.categories = BackupService.toBackupCategories(categories);
    payload.transactions = BackupService.toBackupTransactions(transactions);
    return payload;
  }

  static serializePayload(payload: BackupPayload): string {
    return JSON.stringify(payload);
  }

  /** 导出备份到用户选择的文件 */
  static async exportToFile(context: common.UIAbilityContext): Promise<BackupExportResult> {
    const result = new BackupExportResult();
    try {
      const payload = await BackupService.buildPayload();
      const json = BackupService.serializePayload(payload);
      const fileName = `accounting-backup-${BackupService.formatTimestamp(payload.exportedAt)}`;

      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [fileName];
      documentSaveOptions.fileSuffixChoices = ['JSON 备份|.json'];

      const documentViewPicker = new picker.DocumentViewPicker(context);
      const uris = await documentViewPicker.save(documentSaveOptions);
      if (uris.length === 0) {
        result.status = 'cancelled';
        return result;
      }
      BackupService.writeTextToUri(uris[0], json);
      result.status = 'success';
      return result;
    } catch (err) {
      const message = BackupService.formatError(err);
      hilog.error(BACKUP_LOG_DOMAIN, BACKUP_LOG_TAG, 'exportToFile failed: %{public}s', message);
      result.status = 'error';
      result.message = message;
      return result;
    }
  }

  static async parseFromUri(fileUri: string, fileName: string): Promise<BackupParseResult> {
    const result = new BackupParseResult();
    result.fileName = fileName;
    try {
      const text = await BackupService.readUtf8TextFromUri(fileUri);
      const payload = BackupService.parseJson(text);
      if (payload === null) {
        result.errors.push('无法解析备份文件');
        return result;
      }
      const validationErrors = BackupService.validatePayload(payload);
      if (validationErrors.length > 0) {
        result.errors = validationErrors;
        return result;
      }
      result.payload = payload;
    } catch (_err) {
      result.errors.push('读取备份文件失败');
    }
    return result;
  }

  /** 执行恢复 */
  static async restore(payload: BackupPayload, mode: RestoreMode, skipDuplicates: boolean): Promise<RestoreResult> {
    const result = new RestoreResult();
    if (mode === 'overwrite') {
      await BackupService.transactionRepo.deleteAll();
    }
    result.categoriesAdded = await BackupService.ensureCustomCategories(payload.categories);
    const categoryMap = await BackupService.buildCategoryIdMap();
    const transactions = BackupService.toLocalTransactions(payload.transactions, categoryMap);
    const shouldSkip = mode === 'merge' && skipDuplicates;
    const insertResult = await BackupService.transactionRepo.batchInsertWithDedupe(transactions, shouldSkip);
    result.inserted = insertResult.inserted;
    result.skipped = insertResult.skipped;
    return result;
  }

  private static toBackupCategories(categories: Category[]): BackupCategory[] {
    const list: BackupCategory[] = [];
    for (const cat of categories) {
      const item = new BackupCategory();
      item.name = cat.name;
      item.type = cat.type;
      item.icon = cat.icon;
      item.sortOrder = cat.sortOrder;
      item.isSystem = cat.isSystem;
      list.push(item);
    }
    return list;
  }

  private static toBackupTransactions(transactions: Transaction[]): BackupTransaction[] {
    const list: BackupTransaction[] = [];
    for (const tx of transactions) {
      const item = new BackupTransaction();
      item.amount = tx.amount;
      item.type = tx.type;
      item.categoryName = tx.categoryName.length > 0 ? tx.categoryName : getDefaultCategoryName(tx.type);
      item.payee = tx.payee;
      item.note = tx.note;
      item.occurredAt = tx.occurredAt;
      item.createdAt = tx.createdAt;
      list.push(item);
    }
    return list;
  }

  private static parseJson(text: string): BackupPayload | null {
    try {
      const raw = JSON.parse(text) as Record<string, Object>;
      if (raw === null || raw === undefined) {
        return null;
      }
      const payload = new BackupPayload();
      payload.version = BackupService.readNumber(raw['version']);
      payload.exportedAt = BackupService.readNumber(raw['exportedAt']);
      payload.app = BackupService.readString(raw['app']);
      payload.categories = BackupService.parseCategories(raw['categories']);
      payload.transactions = BackupService.parseTransactions(raw['transactions']);
      return payload;
    } catch (_err) {
      return null;
    }
  }

  private static parseCategories(value: Object | undefined): BackupCategory[] {
    const list: BackupCategory[] = [];
    if (!Array.isArray(value)) {
      return list;
    }
    const arr = value as Object[];
    for (let i = 0; i < arr.length; i++) {
      const raw = arr[i] as Record<string, Object>;
      if (raw === null || raw === undefined) {
        continue;
      }
      const item = new BackupCategory();
      item.name = BackupService.readString(raw['name']);
      const typeStr = BackupService.readString(raw['type']);
      item.type = typeStr === 'income' ? 'income' : 'expense';
      item.icon = BackupService.readString(raw['icon']);
      item.sortOrder = BackupService.readNumber(raw['sortOrder']);
      item.isSystem = BackupService.readBoolean(raw['isSystem']);
      if (item.name.length > 0) {
        list.push(item);
      }
    }
    return list;
  }

  private static parseTransactions(value: Object | undefined): BackupTransaction[] {
    const list: BackupTransaction[] = [];
    if (!Array.isArray(value)) {
      return list;
    }
    const arr = value as Object[];
    for (let i = 0; i < arr.length; i++) {
      const raw = arr[i] as Record<string, Object>;
      if (raw === null || raw === undefined) {
        continue;
      }
      const item = new BackupTransaction();
      item.amount = BackupService.readNumber(raw['amount']);
      const typeStr = BackupService.readString(raw['type']);
      item.type = typeStr === 'income' ? 'income' : 'expense';
      item.categoryName = BackupService.readString(raw['categoryName']);
      item.payee = BackupService.readString(raw['payee']);
      item.note = BackupService.readString(raw['note']);
      item.occurredAt = BackupService.readNumber(raw['occurredAt']);
      item.createdAt = BackupService.readNumber(raw['createdAt']);
      if (item.amount > 0 && item.occurredAt > 0) {
        list.push(item);
      }
    }
    return list;
  }

  private static validatePayload(payload: BackupPayload): string[] {
    const errors: string[] = [];
    if (payload.version !== BACKUP_VERSION) {
      errors.push(`不支持的备份版本：${payload.version}`);
    }
    if (payload.app.length > 0 && payload.app !== BACKUP_APP_ID) {
      errors.push('备份文件不是本应用的数据');
    }
    if (payload.transactions.length === 0 && payload.categories.length === 0) {
      errors.push('备份文件中没有可恢复的数据');
    }
    return errors;
  }

  private static async ensureCustomCategories(categories: BackupCategory[]): Promise<number> {
    let added = 0;
    for (const cat of categories) {
      if (cat.isSystem) {
        continue;
      }
      const existing = await BackupService.categoryRepo.findByNameAndType(cat.name, cat.type);
      if (existing === null) {
        await BackupService.categoryRepo.insertCustom(cat.name, cat.type);
        added++;
      }
    }
    return added;
  }

  private static async buildCategoryIdMap(): Promise<Map<string, number>> {
    const categories = await BackupService.categoryRepo.listAll();
    const map = new Map<string, number>();
    for (const cat of categories) {
      map.set(`${cat.type}:${cat.name}`, cat.id);
    }
    return map;
  }

  private static toLocalTransactions(
    items: BackupTransaction[],
    categoryMap: Map<string, number>
  ): Transaction[] {
    const now = Date.now();
    const list: Transaction[] = [];
    for (const item of items) {
      const resolvedName = item.categoryName.length > 0 ? item.categoryName : getDefaultCategoryName(item.type);
      const key = `${item.type}:${resolvedName}`;
      let categoryId = categoryMap.get(key);
      if (categoryId === undefined) {
        const fallbackName = getDefaultCategoryName(item.type);
        categoryId = categoryMap.get(`${item.type}:${fallbackName}`);
      }
      if (categoryId === undefined || categoryId <= 0) {
        continue;
      }
      const tx = new Transaction();
      tx.amount = item.amount;
      tx.type = item.type;
      tx.categoryId = categoryId;
      tx.payee = item.payee;
      tx.note = item.note;
      tx.occurredAt = item.occurredAt;
      tx.createdAt = item.createdAt > 0 ? item.createdAt : now;
      list.push(tx);
    }
    return list;
  }

  /** 备份 JSON 固定 UTF-8；勿用账单导入的 GBK 启发式解码 */
  private static async readUtf8TextFromUri(uri: string): Promise<string> {
    const buffer = await ImportService.readBinaryContent(uri);
    const bytes = new Uint8Array(buffer);
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeToString(bytes, { stream: false });
  }

  private static writeTextToUri(uri: string, text: string): void {
    const encoder = new util.TextEncoder();
    const contentBytes = encoder.encodeInto(text);
    const bom = new Uint8Array([0xEF, 0xBB, 0xBF]);
    const bytes = new Uint8Array(bom.length + contentBytes.length);
    bytes.set(bom, 0);
    bytes.set(contentBytes, bom.length);
    let file: fileIo.File | null = null;
    try {
      // Picker 已预创建空文件，仅需 READ_WRITE（勿加 CREATE/TRUNC，否则 URI 写入会失败）
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, bytes.buffer);
    } finally {
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  private static formatError(err: Object): string {
    const businessErr = err as BusinessError;
    if (businessErr.code !== undefined && businessErr.message !== undefined && businessErr.message.length > 0) {
      return `[${businessErr.code}] ${businessErr.message}`;
    }
    if (businessErr.message !== undefined && businessErr.message.length > 0) {
      return businessErr.message;
    }
    return `${err}`;
  }

  private static formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-` +
      `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
  }

  private static readString(value: Object | undefined): string {
    if (value === null || value === undefined) {
      return '';
    }
    return `${value}`;
  }

  private static readNumber(value: Object | undefined): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value);
      return Number.isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }

  private static readBoolean(value: Object | undefined): boolean {
    if (typeof value === 'boolean') {
      return value;
    }
    if (value === 1 || value === '1' || value === 'true') {
      return true;
    }
    return false;
  }
}
