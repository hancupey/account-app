export type TransactionType = 'income' | 'expense';

export class Transaction {
  id: number = 0;
  amount: number = 0;
  type: TransactionType = 'expense';
  categoryId: number = 0;
  /** 支付对象 / 商户名 */
  payee: string = '';
  note: string = '';
  occurredAt: number = 0;
  createdAt: number = 0;
  categoryName: string = '';
}

export class DayGroup {
  dateLabel: string = '';
  dateKey: string = '';
  items: Transaction[] = [];
}

export class MonthSummary {
  income: number = 0;
  expense: number = 0;

  get balance(): number {
    return this.income - this.expense;
  }
}

export class CategoryStat {
  categoryId: number = 0;
  categoryName: string = '';
  type: TransactionType = 'expense';
  total: number = 0;
}

export class MonthGroup {
  monthLabel: string = '';
  monthKey: string = '';
  items: Transaction[] = [];
}

export class DailyExpenseStat {
  day: number = 0;
  dateKey: string = '';
  total: number = 0;
}

export class MonthlyExpenseStat {
  month: number = 0;
  monthKey: string = '';
  total: number = 0;
}
