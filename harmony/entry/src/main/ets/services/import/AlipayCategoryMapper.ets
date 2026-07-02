import { TransactionType } from '../../models/Transaction';
import { getDefaultCategoryName } from '../../database/CategoryDefaults';

/** 支付宝「交易分类」映射结果 */
export interface AlipayMappedCategory {
  type: TransactionType;
  categoryName: string;
}

interface AlipayCategoryEntry {
  categoryName: string;
  /** 强制收支类型；未设置则沿用 CSV「收/支」列 */
  forcedType?: TransactionType;
  /** 分类名随收/支变化（投资理财、其他） */
  typeDependent?: boolean;
}

function createAlipayCategoryEntry(
  categoryName: string,
  forcedType?: TransactionType,
  typeDependent?: boolean
): AlipayCategoryEntry {
  const entry: AlipayCategoryEntry = { categoryName: categoryName };
  if (forcedType !== undefined) {
    entry.forcedType = forcedType;
  }
  if (typeDependent !== undefined) {
    entry.typeDependent = typeDependent;
  }
  return entry;
}

function buildAlipayCategoryEntries(): Map<string, AlipayCategoryEntry> {
  const map = new Map<string, AlipayCategoryEntry>();
  // —— 第 6 行：收入类（强制 income，不含退款）——
  map.set('收入', createAlipayCategoryEntry('其它', 'income'));
  map.set('转账红包', createAlipayCategoryEntry('礼金', 'income'));
  map.set('亲友代付', createAlipayCategoryEntry('其它', 'income'));
  map.set('账户存取', createAlipayCategoryEntry('其它', 'income'));

  // —— 退款：支出冲销，强制 expense ——
  map.set('退款', createAlipayCategoryEntry('日用', 'expense'));

  // —— 第 1–5 行：支出类 ——
  map.set('餐饮美食', createAlipayCategoryEntry('餐饮'));
  map.set('服饰装扮', createAlipayCategoryEntry('服饰'));
  map.set('日用百货', createAlipayCategoryEntry('日用'));
  map.set('家居家装', createAlipayCategoryEntry('居家'));
  map.set('数码电器', createAlipayCategoryEntry('数码'));
  map.set('运动户外', createAlipayCategoryEntry('运动'));
  map.set('美容美发', createAlipayCategoryEntry('美容'));
  map.set('母婴亲子', createAlipayCategoryEntry('孩子'));
  map.set('宠物', createAlipayCategoryEntry('宠物'));
  map.set('交通出行', createAlipayCategoryEntry('交通'));
  map.set('爱车养车', createAlipayCategoryEntry('汽车'));
  map.set('住房物业', createAlipayCategoryEntry('住房'));
  map.set('酒店旅游', createAlipayCategoryEntry('旅行'));
  map.set('文化休闲', createAlipayCategoryEntry('娱乐'));
  map.set('教育培训', createAlipayCategoryEntry('学习'));
  map.set('医疗健康', createAlipayCategoryEntry('医疗'));
  map.set('生活服务', createAlipayCategoryEntry('日用'));
  map.set('公共服务', createAlipayCategoryEntry('办公'));
  map.set('商业服务', createAlipayCategoryEntry('办公'));
  map.set('公益捐赠', createAlipayCategoryEntry('捐赠'));
  map.set('互助保障', createAlipayCategoryEntry('医疗'));
  map.set('投资理财', createAlipayCategoryEntry('理财', undefined, true));
  map.set('保险', createAlipayCategoryEntry('办公'));
  map.set('信用借还', createAlipayCategoryEntry('日用', 'expense'));
  map.set('充值缴费', createAlipayCategoryEntry('通讯'));

  // —— 第 7 行：其他 ——
  map.set('其他', createAlipayCategoryEntry('其它', undefined, true));
  map.set('其它', createAlipayCategoryEntry('其它', undefined, true));
  return map;
}

/**
 * 支付宝账单导出「交易分类」→ 应用系统分类与收支类型。
 *
 * 类型优先级：
 * 1. 第 6 行收入类（收入、转账红包、亲友代付、账户存取）强制 income
 * 2. 退款强制 expense（不计入收入）
 * 3. 投资理财、其他 随「收/支」列决定类型与分类
 * 4. 其余默认 expense，并尊重「收/支」列
 */
export class AlipayCategoryMapper {
  private static readonly ENTRIES: Map<string, AlipayCategoryEntry> = buildAlipayCategoryEntries();

  /** 第 6 行收入类分类名（强制 income，退款除外） */
  static readonly INCOME_FORCE_LABELS: string[] = ['收入', '转账红包', '亲友代付', '账户存取'];

  static mapCategory(alipayLabel: string, csvType: TransactionType): AlipayMappedCategory {
    const label = alipayLabel.trim();
    if (label.length === 0) {
      return {
        type: csvType,
        categoryName: getDefaultCategoryName(csvType)
      };
    }

    const entry = AlipayCategoryMapper.ENTRIES.get(label);
    if (entry !== undefined) {
      return AlipayCategoryMapper.resolveEntry(label, entry, csvType);
    }

    return {
      type: csvType,
      categoryName: AlipayCategoryMapper.fuzzyCategoryName(label, csvType)
    };
  }

  private static resolveEntry(
    label: string,
    entry: AlipayCategoryEntry,
    csvType: TransactionType
  ): AlipayMappedCategory {
    if (entry.typeDependent === true) {
      if (label === '投资理财') {
        const type = csvType;
        return {
          type,
          categoryName: type === 'income' ? '理财' : '办公'
        };
      }
      const type = entry.forcedType ?? csvType;
      return {
        type,
        categoryName: type === 'income' ? '其它' : '其他'
      };
    }

    const type = entry.forcedType ?? csvType;
    return { type, categoryName: entry.categoryName };
  }

  /** 未在映射表中的分类：按关键词模糊匹配到系统分类 */
  private static fuzzyCategoryName(label: string, type: TransactionType): string {
    if (type === 'income') {
      if (/工资|薪资/.test(label)) {
        return '工资';
      }
      if (/兼职/.test(label)) {
        return '兼职';
      }
      if (/理财|基金|利息|收益/.test(label)) {
        return '理财';
      }
      if (/礼金|红包/.test(label)) {
        return '礼金';
      }
      return getDefaultCategoryName('income');
    }
    if (/餐饮|美食|外卖/.test(label)) {
      return '餐饮';
    }
    if (/购物/.test(label)) {
      return '购物';
    }
    if (/日用|生活缴费|水电/.test(label)) {
      return '日用';
    }
    if (/交通|出行|打车|地铁|公交/.test(label)) {
      return '交通';
    }
    if (/运动|健身|户外/.test(label)) {
      return '运动';
    }
    if (/娱乐|休闲|游戏|电影|文化/.test(label)) {
      return '娱乐';
    }
    if (/通讯|话费|流量|充值|缴费/.test(label)) {
      return '通讯';
    }
    if (/服饰|服装|装扮/.test(label)) {
      return '服饰';
    }
    if (/美容|化妆|美发/.test(label)) {
      return '美容';
    }
    if (/住房|房租|房贷|物业/.test(label)) {
      return '住房';
    }
    if (/居家|家居|家装/.test(label)) {
      return '居家';
    }
    if (/孩子|育儿|奶粉|母婴|亲子/.test(label)) {
      return '孩子';
    }
    if (/旅行|旅游|酒店/.test(label)) {
      return '旅行';
    }
    if (/数码|电子|电器/.test(label)) {
      return '数码';
    }
    if (/汽车|加油|停车|养车|爱车/.test(label)) {
      return '汽车';
    }
    if (/医疗|健康|医院|药品|保障/.test(label)) {
      return '医疗';
    }
    if (/学习|培训|教育/.test(label)) {
      return '学习';
    }
    if (/宠物/.test(label)) {
      return '宠物';
    }
    if (/捐赠|公益/.test(label)) {
      return '捐赠';
    }
    if (/办公|商业|公共|保险/.test(label)) {
      return '办公';
    }
    if (/转账|红包/.test(label)) {
      return '社交';
    }
    return getDefaultCategoryName('expense');
  }
}
