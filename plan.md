# accounting-app 项目计划文档

> 版本：v0.2 · 更新日期：2026-06-30  
> 项目路径：`D:\hancu-project\accounting-app`

---

## 1. 项目概述与目标

### 1.1 项目背景

个人自用、**完全本地化**的记账应用：数据不上传云端，隐私可控。首期在 **华为鸿蒙 HarmonyOS** 上交付可用版本；**iOS / Android 后续再做**，不与首期并行。

### 1.2 核心目标

| 目标 | 说明 |
|------|------|
| 鸿蒙优先 | ArkTS + ArkUI 原生实现，充分利用 RDB 与系统能力 |
| 纯本地 | 无网络依赖即可使用；数据存储在设备本地 |
| 隐私优先 | 不采集用户数据、不接入第三方统计 |
| 轻量占用 | 控制安装包体积与数据库大小，适合长期记账 |
| 可维护 | 清晰分层，便于后续迭代与跨端复用数据模型 |

### 1.3 非目标（本期不做）

- 多设备云同步
- 社交分享、社区功能
- 在线支付、银行账户自动拉取
- Taro / uni-app 等跨端框架
- iOS / Android 客户端（列入后续阶段）

---

## 2. 技术选型

### 2.1 最终选型（当前）

```
HarmonyOS 原生
├── 语言/UI   → ArkTS + ArkUI（声明式）
├── 本地存储  → @ohos.data.relationalStore（RDB）
├── 工程模型  → Stage 模型
├── 目标 API  → 23（HarmonyOS 6.1.0）
└── 工程路径  → harmony/
```

**选择鸿蒙原生的理由：**

1. **个人自用、单端交付**：无需为三端统一代码而引入跨端复杂度。
2. **与真机对齐**：目标设备 HarmonyOS 6.1.0 / API 23，原生开发路径最直接。
3. **RDB 一等公民**：relationalStore 与 ArkTS 集成成熟，适合记账类结构化数据。
4. **后续可扩展**：数据模型与 SQL 可复用到 iOS/Android 的 SQLite 实现。

### 2.2 本地存储

| 层级 | 技术 | 用途 |
|------|------|------|
| 主数据库 | **RDB（relationalStore）** | 账单、分类、预算等 |
| 轻量 KV | Preferences | 主题、货币符号等偏好 |
| 备份 | 文件系统 | JSON/CSV 导出（阶段二） |

表结构定义见 [`docs/schema.sql`](./docs/schema.sql)。

### 2.3 历史：Taro 探索（已废弃）

早期曾搭建 **Taro 4 + React** 三端脚手架（含 `package.json`、`src/`、`config/`、`node_modules/` 等），用于评估跨端可行性。**用户已明确不走 Taro 三端路线**，相关文件已从仓库移除。若本地仍有残留目录，可安全删除。

---

## 3. 目标设备与 SDK

| 项目 | 值 |
|------|-----|
| 目标系统 | HarmonyOS **6.1.0** |
| 目标 API Level | **23** |
| 鸿蒙工程路径 | `D:\hancu-project\accounting-app\harmony` |
| 后续升级 | **HarmonyOS 7**（升级后须回归核心流程） |

**DevEco Studio 创建工程时：**

1. 选择 **Stage 模型**、**ArkTS** 空工程
2. **Compile SDK / Target API** 选择 **API 23**
3. 工程保存至仓库内 `harmony/` 目录

**真机核对：** 手机 **设置 → 关于手机**，确认 HarmonyOS 版本与 API Level 为 **23** 后再真机调试。

---

## 4. 架构设计

```
┌─────────────────────────────────────────┐
│           UI 层（pages / components）    │
├─────────────────────────────────────────┤
│        状态层（AppStorage / 单例）       │
├─────────────────────────────────────────┤
│     业务层（TransactionService 等）      │
├─────────────────────────────────────────┤
│     数据层（RdbStore + Repository）      │
└─────────────────────────────────────────┘
```

**设计原则：**

- **离线优先**：所有读写走本地 RDB
- **单一数据源**：RDB 为唯一真相源
- **金额用整数（分）或 REAL**：与 `schema.sql` 保持一致，避免浮点误差
- **Schema 版本化**：升级时执行迁移脚本

---

## 5. 数据模型

详见 [`docs/schema.sql`](./docs/schema.sql)。核心表：

- `categories` — 收支分类
- `transactions` — 账单流水
- `budgets` — 预算（阶段二）

```
categories ──< transactions
budgets ────── (按 category 或全局)
```

---

## 6. 功能模块（分阶段）

### 阶段一：MVP（鸿蒙）

| 模块 | 功能点 | 优先级 |
|------|--------|--------|
| 工程 | DevEco 创建 `harmony/` 工程（API 23） | P0 |
| 数据层 | RDB 初始化、CRUD、迁移 v1 | P0 |
| 记账 | 记一笔（金额、分类、备注、日期） | P0 |
| 分类 | 预设收支分类 | P0 |
| 流水 | 账单列表、按日分组 | P0 |
| 统计 | 本月收支总览 | P1 |
| 设置 | 货币符号、深色模式（跟随系统） | P2 |

### 阶段二：增强

- 预算、搜索筛选、导出备份、多账户

### 阶段三：跨端（后续）

- iOS / Android 原生或共享逻辑层，复用 `docs/schema.sql` 与业务规则文档

---

## 7. 目录结构规划

```
accounting-app/
├── harmony/                    # DevEco 鸿蒙工程（待创建）
│   └── entry/
│       └── src/main/
│           ├── ets/
│           │   ├── entryability/
│           │   ├── pages/      # Index, Add, Transactions, Statistics, Settings
│           │   ├── components/
│           │   ├── services/   # 业务服务
│           │   ├── database/   # RDB 封装与 Repository
│           │   ├── models/
│           │   └── utils/
│           └── resources/
├── docs/
│   └── schema.sql
├── plan.md
└── README.md
```

---

## 8. 开发里程碑

| 里程碑 | 交付物 | 验收标准 |
|--------|--------|----------|
| **M0 工程** | `harmony/` DevEco 工程 | API 23，模拟器/真机跑通首页 |
| **M1 数据层** | RDB + Repository | CRUD 与迁移 v1 通过 |
| **M2 记账核心** | 记一笔 + 流水列表 | 重启后数据不丢 |
| **M3 统计** | 本月收支 | 与流水数据一致 |
| **M4 MVP 封板** | 设置与体验打磨 | 个人日常可用 |
| **M5 增强** | 预算、导出等 | 按阶段二清单 |
| **M6 跨端** | iOS/Android 规划 | 复用数据模型 |

---

## 9. 鸿蒙开发注意事项

### 9.1 环境

- DevEco Studio 5.0.3+，SDK 含 API 23
- Windows 模拟器注意 x86 限制；优先真机（API 23）

### 9.2 RDB 要点

- 使用 `relationalStore.getRdbStore` 打开数据库
- 建表 SQL 与 `docs/schema.sql` 对齐
- 列表分页查询，避免一次加载全表

### 9.3 权限

记账 App 通常只需文件读写（备份导出时）。**不需要**网络、定位等敏感权限。

### 9.4 HarmonyOS 7 升级

升级至 HarmonyOS 7 后，须重新测试：记一笔、流水列表、RDB 读写、统计页等核心流程。

---

## 10. 风险与依赖

| 风险 | 缓解 |
|------|------|
| `harmony/` 尚未创建 | 按 §3 在 DevEco 中初始化 |
| RDB 迁移失误 | 版本号 + 单元测试 + 备份提示 |
| 仅鸿蒙单端 | 数据模型文档化，便于后续 iOS/Android |
| 生态/API 变更 | 跟踪官方 Release Notes |

---

## 11. 下一步行动

1. 在 DevEco Studio 于 `harmony/` 创建 **Stage + ArkTS** 工程，**API 23**
2. 实现 RDB 初始化，执行 `docs/schema.sql` 建表
3. 实现首页与「记一笔」页面
4. 实现流水列表与本月统计
5. 真机（HarmonyOS 6.1.0 / API 23）完整走通

---

*本文档随项目演进持续更新。*
