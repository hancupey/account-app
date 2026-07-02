import { relationalStore } from '@kit.ArkData';
import { BatchInsertResult } from '../models/BatchInsertResult';
import { CategoryStat, DailyExpenseStat, MonthlyExpenseStat, Transaction, TransactionType } from '../models/Transaction';
import { formatDateKey, formatMonthKey } from '../utils/DateUtil';
import { RdbHelper } from './RdbHelper';

export class TransactionRepository {
  async insert(transaction: Transaction): Promise<number> {
    const store = RdbHelper.getInstance().getStore();
    const bucket: relationalStore.ValuesBucket = {
      'amount': transaction.amount,
      'type': transaction.type,
      'category_id': transaction.categoryId,
      'payee': transaction.payee,
      'note': transaction.note,
      'occurred_at': transaction.occurredAt,
      'created_at': transaction.createdAt
    };
    return store.insert('transactions', bucket);
  }

  async batchInsert(transactions: Transaction[]): Promise<number> {
    if (transactions.length === 0) {
      return 0;
    }
    const store = RdbHelper.getInstance().getStore();
    await store.beginTransaction();
    let inserted = 0;
    try {
      for (const transaction of transactions) {
        const bucket: relationalStore.ValuesBucket = {
          'amount': transaction.amount,
          'type': transaction.type,
          'category_id': transaction.categoryId,
          'payee': transaction.payee,
          'note': transaction.note,
          'occurred_at': transaction.occurredAt,
          'created_at': transaction.createdAt
        };
        await store.insert('transactions', bucket);
        inserted++;
      }
      await store.commit();
    } catch (err) {
      await store.rollBack();
      throw err as Error;
    }
    return inserted;
  }

  /** 按 amount|type|occurred_at|payee 指纹去重批量插入 */
  async batchInsertWithDedupe(transactions: Transaction[], skipDuplicates: boolean): Promise<BatchInsertResult> {
    const result = new BatchInsertResult();
    if (transactions.length === 0) {
      return result;
    }
    const existingKeys = skipDuplicates ? await this.loadExistingDedupeKeys() : new Set<string>();
    const toInsert: Transaction[] = [];
    for (const transaction of transactions) {
      const key = TransactionRepository.buildDedupeKey(
        transaction.amount,
        transaction.type,
        transaction.occurredAt,
        transaction.payee
      );
      if (skipDuplicates && existingKeys.has(key)) {
        result.skipped++;
        continue;
      }
      toInsert.push(transaction);
      existingKeys.add(key);
    }
    result.inserted = await this.batchInsert(toInsert);
    return result;
  }

  /** 判断库中是否已有相同指纹的流水 */
  async existsByFingerprint(
    amount: number,
    type: TransactionType,
    occurredAt: number,
    payee: string
  ): Promise<boolean> {
    const keys = await this.loadExistingDedupeKeys();
    return keys.has(TransactionRepository.buildDedupeKey(amount, type, occurredAt, payee));
  }

  static buildDedupeKey(
    amount: number,
    type: TransactionType,
    occurredAt: number,
    payee: string
  ): string {
    const normalizedPayee = payee.trim().toLowerCase();
    const normalizedAmount = amount.toFixed(2);
    return `${normalizedAmount}|${type}|${occurredAt}|${normalizedPayee}`;
  }

  private async loadExistingDedupeKeys(): Promise<Set<string>> {
    const store = RdbHelper.getInstance().getStore();
    const sql = 'SELECT amount, type, occurred_at, payee FROM transactions';
    const resultSet = await store.querySql(sql);
    const keys = new Set<string>();
    if (resultSet.goToFirstRow()) {
      do {
        const amount = resultSet.getDouble(resultSet.getColumnIndex('amount'));
        const type = resultSet.getString(resultSet.getColumnIndex('type')) as TransactionType;
        const occurredAt = resultSet.getLong(resultSet.getColumnIndex('occurred_at'));
        const payeeIndex = resultSet.getColumnIndex('payee');
        let payee = '';
        if (!resultSet.isColumnNull(payeeIndex)) {
          payee = resultSet.getString(payeeIndex);
        }
        keys.add(TransactionRepository.buildDedupeKey(amount, type, occurredAt, payee));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return keys;
  }

  async listAll(): Promise<Transaction[]> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT t.id, t.amount, t.type, t.category_id, t.payee, t.note, t.occurred_at, t.created_at, c.name AS category_name ' +
      'FROM transactions t LEFT JOIN categories c ON t.category_id = c.id ' +
      'ORDER BY t.occurred_at DESC, t.id DESC';
    const resultSet = await store.querySql(sql);
    const list: Transaction[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        list.push(TransactionRepository.readRow(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return list;
  }

  async listByCategoryInRange(
    categoryId: number,
    type: TransactionType,
    startAt: number,
    endAt: number
  ): Promise<Transaction[]> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT t.id, t.amount, t.type, t.category_id, t.payee, t.note, t.occurred_at, t.created_at, c.name AS category_name ' +
      'FROM transactions t LEFT JOIN categories c ON t.category_id = c.id ' +
      'WHERE t.occurred_at >= ? AND t.occurred_at <= ? AND t.type = ? AND t.category_id = ? ' +
      'ORDER BY t.occurred_at DESC, t.id DESC';
    const resultSet = await store.querySql(sql, [startAt, endAt, type, categoryId]);
    const list: Transaction[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        list.push(TransactionRepository.readRow(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return list;
  }

  async listInRange(startAt: number, endAt: number): Promise<Transaction[]> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT t.id, t.amount, t.type, t.category_id, t.payee, t.note, t.occurred_at, t.created_at, c.name AS category_name ' +
      'FROM transactions t LEFT JOIN categories c ON t.category_id = c.id ' +
      'WHERE t.occurred_at >= ? AND t.occurred_at <= ? ' +
      'ORDER BY t.occurred_at DESC, t.id DESC';
    const resultSet = await store.querySql(sql, [startAt, endAt]);
    const list: Transaction[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        list.push(TransactionRepository.readRow(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return list;
  }

  async getById(id: number): Promise<Transaction | null> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT t.id, t.amount, t.type, t.category_id, t.payee, t.note, t.occurred_at, t.created_at, c.name AS category_name ' +
      'FROM transactions t LEFT JOIN categories c ON t.category_id = c.id ' +
      'WHERE t.id = ?';
    const resultSet = await store.querySql(sql, [id]);
    let transaction: Transaction | null = null;
    if (resultSet.goToFirstRow()) {
      transaction = TransactionRepository.readRow(resultSet);
    }
    resultSet.close();
    return transaction;
  }

  async update(transaction: Transaction): Promise<void> {
    const store = RdbHelper.getInstance().getStore();
    const bucket: relationalStore.ValuesBucket = {
      'amount': transaction.amount,
      'type': transaction.type,
      'category_id': transaction.categoryId,
      'payee': transaction.payee,
      'note': transaction.note,
      'occurred_at': transaction.occurredAt
    };
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('id', transaction.id);
    await store.update(bucket, predicates);
  }

  async deleteById(id: number): Promise<void> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  async deleteAll(): Promise<void> {
    const store = RdbHelper.getInstance().getStore();
    const predicates = new relationalStore.RdbPredicates('transactions');
    await store.delete(predicates);
  }

  async sumByTypeInRange(type: TransactionType, startAt: number, endAt: number): Promise<number> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE type = ? AND occurred_at >= ? AND occurred_at <= ?';
    const resultSet = await store.querySql(sql, [type, startAt, endAt]);
    let total = 0;
    if (resultSet.goToFirstRow()) {
      total = resultSet.getDouble(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  async sumExpenseByDayInRange(startAt: number, endAt: number): Promise<DailyExpenseStat[]> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT occurred_at, amount FROM transactions WHERE type = ? AND occurred_at >= ? AND occurred_at <= ?';
    const resultSet = await store.querySql(sql, ['expense', startAt, endAt]);
    const map: Map<number, DailyExpenseStat> = new Map();
    if (resultSet.goToFirstRow()) {
      do {
        const occurredAt = resultSet.getLong(resultSet.getColumnIndex('occurred_at'));
        const amount = resultSet.getDouble(resultSet.getColumnIndex('amount'));
        const date = new Date(occurredAt);
        const day = date.getDate();
        let stat = map.get(day);
        if (!stat) {
          stat = new DailyExpenseStat();
          stat.day = day;
          stat.dateKey = formatDateKey(occurredAt);
          stat.total = 0;
          map.set(day, stat);
        }
        stat.total += amount;
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    const list: DailyExpenseStat[] = [];
    map.forEach((stat: DailyExpenseStat) => {
      list.push(stat);
    });
    return list;
  }

  async sumExpenseByMonthInRange(startAt: number, endAt: number): Promise<MonthlyExpenseStat[]> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT occurred_at, amount FROM transactions WHERE type = ? AND occurred_at >= ? AND occurred_at <= ?';
    const resultSet = await store.querySql(sql, ['expense', startAt, endAt]);
    const map: Map<number, MonthlyExpenseStat> = new Map();
    if (resultSet.goToFirstRow()) {
      do {
        const occurredAt = resultSet.getLong(resultSet.getColumnIndex('occurred_at'));
        const amount = resultSet.getDouble(resultSet.getColumnIndex('amount'));
        const date = new Date(occurredAt);
        const month = date.getMonth() + 1;
        let stat = map.get(month);
        if (!stat) {
          stat = new MonthlyExpenseStat();
          stat.month = month;
          stat.monthKey = formatMonthKey(occurredAt);
          stat.total = 0;
          map.set(month, stat);
        }
        stat.total += amount;
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    const list: MonthlyExpenseStat[] = [];
    map.forEach((stat: MonthlyExpenseStat) => {
      list.push(stat);
    });
    return list;
  }

  async sumByCategoryInRange(startAt: number, endAt: number): Promise<CategoryStat[]> {
    const store = RdbHelper.getInstance().getStore();
    const sql =
      'SELECT t.category_id, c.name AS category_name, t.type, COALESCE(SUM(t.amount), 0) AS total ' +
      'FROM transactions t LEFT JOIN categories c ON t.category_id = c.id ' +
      'WHERE t.occurred_at >= ? AND t.occurred_at <= ? ' +
      'GROUP BY t.category_id, t.type ' +
      'ORDER BY total DESC';
    const resultSet = await store.querySql(sql, [startAt, endAt]);
    const list: CategoryStat[] = [];
    if (resultSet.goToFirstRow()) {
      do {
        const stat = new CategoryStat();
        stat.categoryId = resultSet.getLong(resultSet.getColumnIndex('category_id'));
        const nameIndex = resultSet.getColumnIndex('category_name');
        if (!resultSet.isColumnNull(nameIndex)) {
          stat.categoryName = resultSet.getString(nameIndex);
        } else {
          stat.categoryName = '未分类';
        }
        stat.type = resultSet.getString(resultSet.getColumnIndex('type')) as TransactionType;
        stat.total = resultSet.getDouble(resultSet.getColumnIndex('total'));
        list.push(stat);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return list;
  }

  private static readRow(resultSet: relationalStore.ResultSet): Transaction {
    const transaction = new Transaction();
    transaction.id = resultSet.getLong(resultSet.getColumnIndex('id'));
    transaction.amount = resultSet.getDouble(resultSet.getColumnIndex('amount'));
    transaction.type = resultSet.getString(resultSet.getColumnIndex('type')) as TransactionType;
    transaction.categoryId = resultSet.getLong(resultSet.getColumnIndex('category_id'));
    const payeeIndex = resultSet.getColumnIndex('payee');
    if (!resultSet.isColumnNull(payeeIndex)) {
      transaction.payee = resultSet.getString(payeeIndex);
    }
    const noteIndex = resultSet.getColumnIndex('note');
    if (!resultSet.isColumnNull(noteIndex)) {
      transaction.note = resultSet.getString(noteIndex);
    }
    transaction.occurredAt = resultSet.getLong(resultSet.getColumnIndex('occurred_at'));
    transaction.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
    const categoryNameIndex = resultSet.getColumnIndex('category_name');
    if (!resultSet.isColumnNull(categoryNameIndex)) {
      transaction.categoryName = resultSet.getString(categoryNameIndex);
    }
    return transaction;
  }
}
