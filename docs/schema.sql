-- accounting-app 共享表结构（HarmonyOS RDB / 后续 iOS·Android SQLite）
-- 版本: 5
-- 系统默认分类：收入 5 项（含「其它」），支出 34 项（含「其他」）

CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  icon TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_system INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  category_id INTEGER NOT NULL,
  payee TEXT,
  note TEXT,
  occurred_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON transactions(occurred_at);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id);

CREATE TABLE IF NOT EXISTS budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER,
  amount REAL NOT NULL CHECK (amount > 0),
  year_month TEXT NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(id)
);
