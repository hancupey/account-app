# accounting-app

个人自用、**纯本地**记账应用。首期 **鸿蒙原生（ArkTS + ArkUI + RDB）**，后续再考虑 iOS / Android。

| 项目 | 值 |
|------|-----|
| 目标系统 | HarmonyOS **6.1.0** |
| API Level | **23** |
| 壳工程路径 | `harmony/`（`D:\hancu-project\accounting-app\harmony`） |
| 后续升级 | HarmonyOS 7（升级后需回归核心流程） |

详细规划见 [plan.md](./plan.md)。共享表结构见 [docs/schema.sql](./docs/schema.sql)。

## 环境要求

- **DevEco Studio** 5.0+（建议 5.1+）
- 鸿蒙 SDK，至少包含 **API 23**
- 真机或模拟器：HarmonyOS 6.1.0 / API 23

## DevEco 首次操作清单

> 当前 `harmony/` 目录为空（仅 `.gitkeep`），需先在 DevEco Studio 中创建工程。  
> 完成本清单后，即可进入 [plan.md §11](./plan.md#11-下一步行动) 的编码阶段。

### 一、安装与 SDK 核对

1. 打开 **DevEco Studio**（建议 5.1+）。
2. 进入 **File → Settings → SDK**（macOS：**DevEco Studio → Settings → SDK**）。
3. 在 **HarmonyOS** 标签页确认已安装 **API 23**（对应 HarmonyOS 6.1.0）。
4. 若未安装：勾选 API 23 → 点击 **Apply** 下载，完成后重启 IDE。

### 二、创建鸿蒙工程

1. **File → New → Create Project**。
2. 选择 **Application**（普通 App，**不要**选元服务 / Atomic Service）。
3. 模板选 **Empty Ability**（空 Ability）。
4. 关键选项：

   | 选项 | 值 |
   |------|-----|
   | Model | **Stage** |
   | Language | **ArkTS** |
   | Compile SDK / Target API | **23** |
   | Save Location | `D:\hancu-project\accounting-app\harmony` |

5. 点击 **Finish**，等待 Gradle 同步完成。
6. 确认工程根目录出现 `build-profile.json5`、`entry/`、`AppScope/` 等文件。

> **注意：** 保存路径必须指向仓库内的 `harmony/` 文件夹本身，不要多建一层子目录。

### 三、真机准备（推荐，优先于模拟器）

1. 手机 **设置 → 关于手机**，连续点击「版本号」开启开发者模式。
2. **设置 → 系统和更新 → 开发人员选项**：
   - 开启 **USB 调试**
   - 开启 **"仅充电"模式下允许 ADB 调试**（如有）
3. USB 连接电脑，手机上允许调试授权。
4. 再次确认：**关于手机** 中 HarmonyOS 版本为 **6.1.0**，API Level 为 **23**。
5. DevEco 顶部设备下拉框应出现你的手机型号。

### 四、首次运行（Hello World）

1. 在 DevEco 中选择真机（或 API 23 模拟器）。
2. 点击 **Run ▶**（或 `Shift+F10`）。
3. 手机上应出现默认首页，显示 "Hello World" 或模板欢迎页。
4. 若构建失败：检查 SDK API 23 是否完整、设备 API 是否匹配。

**M0 里程碑验收：** 工程能编译、真机/模拟器能跑通默认页 → 工程初始化完成。

### 五、工程跑通后的编码顺序

按 [plan.md](./plan.md) 里程碑推进：

| 顺序 | 任务 | 参考 |
|------|------|------|
| 1 | **RDB 数据层** — 初始化数据库，执行 `docs/schema.sql` 建表，封装 Repository | plan §4、§9.2 |
| 2 | **记一笔** — 金额、分类、备注、日期 | plan §6 阶段一 |
| 3 | **首页 + 流水列表** — 按日分组展示账单 | plan §7 `pages/` |
| 4 | **本月统计** — 收支总览 | plan §6 P1 |
| 5 | **设置** — 货币符号、深色模式 | plan §6 P2 |

建议 `entry/src/main/ets/` 下按 plan §7 规划目录：

```text
ets/
├── entryability/
├── pages/          # Index, Add, Transactions, Statistics, Settings
├── components/
├── services/       # TransactionService 等
├── database/       # RdbStore + Repository
├── models/
└── utils/
```

## 快速开始（摘要）

1. 按上方 **DevEco 首次操作清单** 创建 `harmony/` 工程（Stage + ArkTS + API 23）
2. 真机核对：**设置 → 关于手机** → API Level 为 **23**
3. Hello World 跑通后，从 RDB 数据层开始编码

```text
accounting-app/
├── harmony/          # DevEco 鸿蒙工程（待创建）
├── docs/
│   └── schema.sql    # RDB 表结构
├── plan.md
└── README.md
```

## 历史说明

仓库曾短暂存在 **Taro 4 + React** 三端探索脚手架，已移除。当前正式技术路线为 **鸿蒙原生 ArkTS**，非 Taro 跨端方案。

## 许可证

私有项目，未指定开源许可证。
