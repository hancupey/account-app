import { CategoryType } from './Category';
import { TransactionType } from './Transaction';

export const BACKUP_VERSION: number = 1;
export const BACKUP_APP_ID: string = 'accounting-app';

/** 备份文件中的分类条目 */
export class BackupCategory {
  name: string = '';
  type: CategoryType = 'expense';
  icon: string = '';
  sortOrder: number = 0;
  isSystem: boolean = false;
}

/** 备份文件中的交易条目（用分类名映射，不保存本地 id） */
export class BackupTransaction {
  amount: number = 0;
  type: TransactionType = 'expense';
  categoryName: string = '';
  payee: string = '';
  note: string = '';
  occurredAt: number = 0;
  createdAt: number = 0;
}

/** 解析后的备份内容 */
export class BackupPayload {
  version: number = 0;
  exportedAt: number = 0;
  app: string = '';
  categories: BackupCategory[] = [];
  transactions: BackupTransaction[] = [];
}

/** 备份文件解析结果 */
export class BackupParseResult {
  payload: BackupPayload | null = null;
  fileName: string = '';
  errors: string[] = [];
}

/** 恢复执行结果 */
export class RestoreResult {
  categoriesAdded: number = 0;
  inserted: number = 0;
  skipped: number = 0;
}

export type RestoreMode = 'merge' | 'overwrite';

export type BackupExportStatus = 'success' | 'cancelled' | 'error';

/** 备份导出结果 */
export class BackupExportResult {
  status: BackupExportStatus = 'error';
  message: string = '';
}
