export const DB_NAME: string = 'accounting.db';
export const DB_VERSION: number = 5;

export const SQL_CREATE_CATEGORIES: string =
  `CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  icon TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_system INTEGER NOT NULL DEFAULT 0
)`;

export const SQL_MIGRATE_V2_ADD_IS_SYSTEM: string =
  'ALTER TABLE categories ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0';

export const SQL_MIGRATE_V3_ADD_PAYEE: string =
  'ALTER TABLE transactions ADD COLUMN payee TEXT';

export const SQL_CREATE_TRANSACTIONS: string =
  `CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  category_id INTEGER NOT NULL,
  payee TEXT,
  note TEXT,
  occurred_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(id)
)`;

export const SQL_CREATE_BUDGETS: string =
  `CREATE TABLE IF NOT EXISTS budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER,
  amount REAL NOT NULL CHECK (amount > 0),
  year_month TEXT NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(id)
)`;

export const SQL_CREATE_IDX_OCCURRED: string =
  'CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON transactions(occurred_at)';

export const SQL_CREATE_IDX_CATEGORY: string =
  'CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id)';

export const INIT_SQLS: string[] = [
  SQL_CREATE_CATEGORIES,
  SQL_CREATE_TRANSACTIONS,
  SQL_CREATE_BUDGETS,
  SQL_CREATE_IDX_OCCURRED,
  SQL_CREATE_IDX_CATEGORY
];
