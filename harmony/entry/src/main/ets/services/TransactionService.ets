import { common } from '@kit.AbilityKit';
import { Category, CategoryType } from '../models/Category';
import { CategorySortOrder } from '../models/CategorySortOrder';
import {
  CategoryStat,
  DailyExpenseStat,
  DayGroup,
  MonthGroup,
  MonthlyExpenseStat,
  MonthSummary,
  Transaction,
  TransactionType
} from '../models/Transaction';
import { CategoryRepository } from '../database/CategoryRepository';
import { RdbHelper } from '../database/RdbHelper';
import { TransactionRepository } from '../database/TransactionRepository';
import { BatchInsertResult } from '../models/BatchInsertResult';
import { ImportDraft } from '../models/ImportDraft';
import { RecognizedDraft } from '../models/RecognizedDraft';
import {
  endOfMonth,
  formatDateKey,
  formatDateLabel,
  formatMonthKey,
  formatMonthLabel,
  getPeriodRange,
  PeriodRange,
  PeriodType,
  startOfMonth
} from '../utils/DateUtil';

export class TransactionService {
  private static instance: TransactionService;
  private categoryRepo: CategoryRepository = new CategoryRepository();
  private transactionRepo: TransactionRepository = new TransactionRepository();
  private ready: boolean = false;
  private initPromise: Promise<void> | null = null;

  static getInstance(): TransactionService {
    if (!TransactionService.instance) {
      TransactionService.instance = new TransactionService();
    }
    return TransactionService.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.ready) {
      return;
    }
    if (this.initPromise !== null) {
      return this.initPromise;
    }
    this.initPromise = this.doInit(context);
    return this.initPromise;
  }

  private async doInit(context: common.Context): Promise<void> {
    await RdbHelper.getInstance().init(context);
    await this.categoryRepo.ensureDefaults();
    this.ready = true;
  }

  async getCategories(type: CategoryType): Promise<Category[]> {
    return this.categoryRepo.listByType(type);
  }

  async addTransaction(
    amount: number,
    type: TransactionType,
    categoryId: number,
    payee: string,
    note: string,
    occurredAt: number
  ): Promise<number> {
    const transaction = new Transaction();
    transaction.amount = amount;
    transaction.type = type;
    transaction.categoryId = categoryId;
    transaction.payee = payee;
    transaction.note = note;
    transaction.occurredAt = occurredAt;
    transaction.createdAt = Date.now();
    return this.transactionRepo.insert(transaction);
  }

  async getTransactionById(id: number): Promise<Transaction | null> {
    return this.transactionRepo.getById(id);
  }

  async updateTransaction(
    id: number,
    amount: number,
    type: TransactionType,
    categoryId: number,
    payee: string,
    note: string,
    occurredAt: number
  ): Promise<void> {
    const existing = await this.transactionRepo.getById(id);
    if (existing === null) {
      throw new Error('Transaction not found');
    }
    existing.amount = amount;
    existing.type = type;
    existing.categoryId = categoryId;
    existing.payee = payee;
    existing.note = note;
    existing.occurredAt = occurredAt;
    await this.transactionRepo.update(existing);
  }

  async deleteTransaction(id: number): Promise<void> {
    await this.transactionRepo.deleteById(id);
  }

  async getAllCategories(): Promise<Category[]> {
    return this.categoryRepo.listAll();
  }

  async insertCustomCategory(name: string, type: CategoryType): Promise<number> {
    return this.categoryRepo.insertCustom(name, type);
  }

  async updateCategory(id: number, name: string): Promise<void> {
    return this.categoryRepo.update(id, name);
  }

  async deleteCategory(id: number): Promise<void> {
    return this.categoryRepo.delete(id);
  }

  async updateCategorySortOrders(orders: CategorySortOrder[]): Promise<void> {
    return this.categoryRepo.updateSortOrders(orders);
  }

  async importDrafts(drafts: ImportDraft[], skipDuplicates: boolean): Promise<BatchInsertResult> {
    const now = Date.now();
    const transactions: Transaction[] = [];
    for (const draft of drafts) {
      if (draft.amount <= 0 || draft.categoryId <= 0) {
        continue;
      }
      const transaction = new Transaction();
      transaction.amount = draft.amount;
      transaction.type = draft.type;
      transaction.categoryId = draft.categoryId;
      transaction.payee = draft.payee;
      transaction.note = draft.note;
      transaction.occurredAt = draft.occurredAt;
      transaction.createdAt = now;
      transactions.push(transaction);
    }
    return this.transactionRepo.batchInsertWithDedupe(transactions, skipDuplicates);
  }

  /** 截图 OCR 批量入账，默认跳过与库中重复的流水 */
  async saveRecognizedDrafts(drafts: RecognizedDraft[], skipDuplicates: boolean = true): Promise<BatchInsertResult> {
    const now = Date.now();
    const transactions: Transaction[] = [];
    for (const draft of drafts) {
      if (!draft.isSavable()) {
        continue;
      }
      const transaction = new Transaction();
      transaction.amount = draft.amount;
      transaction.type = draft.type;
      transaction.categoryId = draft.categoryId;
      transaction.payee = draft.payee.trim();
      transaction.note = draft.note.trim();
      transaction.occurredAt = draft.occurredAt;
      transaction.createdAt = now;
      transactions.push(transaction);
    }
    return this.transactionRepo.batchInsertWithDedupe(transactions, skipDuplicates);
  }

  async listTransactionsGrouped(): Promise<DayGroup[]> {
    const transactions = await this.transactionRepo.listAll();
    return TransactionService.groupByDay(transactions);
  }

  async listTransactionsGroupedInRange(startAt: number, endAt: number): Promise<DayGroup[]> {
    const transactions = await this.transactionRepo.listInRange(startAt, endAt);
    return TransactionService.groupByDay(transactions);
  }

  async listTransactionsGroupedByMonthInRange(startAt: number, endAt: number): Promise<MonthGroup[]> {
    const transactions = await this.transactionRepo.listInRange(startAt, endAt);
    const groupMap: Map<string, MonthGroup> = new Map();
    for (const item of transactions) {
      const monthKey = formatMonthKey(item.occurredAt);
      let group = groupMap.get(monthKey);
      if (!group) {
        group = new MonthGroup();
        group.monthKey = monthKey;
        group.monthLabel = formatMonthLabel(item.occurredAt);
        group.items = [];
        groupMap.set(monthKey, group);
      }
      group.items.push(item);
    }
    const groups: MonthGroup[] = [];
    groupMap.forEach((group: MonthGroup) => {
      group.items.sort((a: Transaction, b: Transaction) => b.amount - a.amount);
      groups.push(group);
    });
    groups.sort((a: MonthGroup, b: MonthGroup) => b.monthKey.localeCompare(a.monthKey));
    return groups;
  }

  async listTransactionsInRange(startAt: number, endAt: number): Promise<Transaction[]> {
    return this.transactionRepo.listInRange(startAt, endAt);
  }

  async listByCategoryInRange(
    categoryId: number,
    type: TransactionType,
    startAt: number,
    endAt: number
  ): Promise<Transaction[]> {
    return this.transactionRepo.listByCategoryInRange(categoryId, type, startAt, endAt);
  }

  async listByCategoryGroupedInRange(
    categoryId: number,
    type: TransactionType,
    startAt: number,
    endAt: number
  ): Promise<DayGroup[]> {
    const transactions = await this.transactionRepo.listByCategoryInRange(categoryId, type, startAt, endAt);
    return TransactionService.groupByDay(transactions);
  }

  async listByCategoryGroupedByMonthInRange(
    categoryId: number,
    type: TransactionType,
    startAt: number,
    endAt: number
  ): Promise<MonthGroup[]> {
    const transactions = await this.transactionRepo.listByCategoryInRange(categoryId, type, startAt, endAt);
    const groupMap: Map<string, MonthGroup> = new Map();
    for (const item of transactions) {
      const monthKey = formatMonthKey(item.occurredAt);
      let group = groupMap.get(monthKey);
      if (!group) {
        group = new MonthGroup();
        group.monthKey = monthKey;
        group.monthLabel = formatMonthLabel(item.occurredAt);
        group.items = [];
        groupMap.set(monthKey, group);
      }
      group.items.push(item);
    }
    const groups: MonthGroup[] = [];
    groupMap.forEach((group: MonthGroup) => {
      group.items.sort((a: Transaction, b: Transaction) => b.amount - a.amount);
      groups.push(group);
    });
    groups.sort((a: MonthGroup, b: MonthGroup) => b.monthKey.localeCompare(a.monthKey));
    return groups;
  }

  async getSummaryInRange(startAt: number, endAt: number): Promise<MonthSummary> {
    const summary = new MonthSummary();
    summary.income = await this.transactionRepo.sumByTypeInRange('income', startAt, endAt);
    summary.expense = await this.transactionRepo.sumByTypeInRange('expense', startAt, endAt);
    return summary;
  }

  async getCurrentMonthSummary(): Promise<MonthSummary> {
    const now = Date.now();
    return this.getSummaryInRange(startOfMonth(now), endOfMonth(now));
  }

  async getSummaryForPeriod(type: PeriodType, anchor: Date): Promise<MonthSummary> {
    const range = getPeriodRange(type, anchor);
    return this.getSummaryInRange(range.startAt, range.endAt);
  }

  async getCategoryBreakdown(startAt: number, endAt: number): Promise<CategoryStat[]> {
    return this.transactionRepo.sumByCategoryInRange(startAt, endAt);
  }

  async getDailyExpenseInRange(startAt: number, endAt: number): Promise<DailyExpenseStat[]> {
    return this.transactionRepo.sumExpenseByDayInRange(startAt, endAt);
  }

  async getMonthlyExpenseInRange(startAt: number, endAt: number): Promise<MonthlyExpenseStat[]> {
    return this.transactionRepo.sumExpenseByMonthInRange(startAt, endAt);
  }

  getPeriodRange(type: PeriodType, anchor: Date): PeriodRange {
    return getPeriodRange(type, anchor);
  }

  private static groupByDay(transactions: Transaction[]): DayGroup[] {
    const groupMap: Map<string, DayGroup> = new Map();
    for (const item of transactions) {
      const dateKey = formatDateKey(item.occurredAt);
      let group = groupMap.get(dateKey);
      if (!group) {
        group = new DayGroup();
        group.dateKey = dateKey;
        group.dateLabel = formatDateLabel(item.occurredAt);
        group.items = [];
        groupMap.set(dateKey, group);
      }
      group.items.push(item);
    }
    const groups: DayGroup[] = [];
    groupMap.forEach((group: DayGroup) => {
      group.items.sort((a: Transaction, b: Transaction) => b.amount - a.amount);
      groups.push(group);
    });
    groups.sort((a: DayGroup, b: DayGroup) => b.dateKey.localeCompare(a.dateKey));
    return groups;
  }
}
