import { TransactionType } from '../../models/Transaction';
import { getDefaultCategoryName } from '../../database/CategoryDefaults';

/** 微信账单单行映射输入 */
export interface WechatMapInput {
  /** CSV「交易类型」列 */
  transactionType: string;
  /** CSV「商品」列（交易名称） */
  productName: string;
  /** CSV「交易对方」列 */
  counterparty: string;
  /** CSV「收/支」列原文 */
  incomeExpenseLabel: string;
  /** 由「收/支」列解析的收支类型 */
  csvType: TransactionType;
}

/** 微信账单映射结果 */
export interface WechatMappedCategory {
  type: TransactionType;
  categoryName: string;
}

/**
 * 微信账单导出分类与收支类型推断。
 *
 * 微信 CSV 无独立「交易分类」列，需结合「交易类型」「商品」「交易对方」与「收/支」列。
 *
 * 收支类型优先级：
 * 1. 「收/支」列（由调用方解析为 csvType）
 * 2. 「商品」名称模式（发给/转给→支出，来自→收入）
 * 3. 「交易类型」强制规则（退款→支出）及兜底
 */
export class WechatCategoryMapper {
  static map(input: WechatMapInput): WechatMappedCategory {
    const type = WechatCategoryMapper.detectType(input);
    const categoryName = WechatCategoryMapper.mapCategoryName(input, type);
    return { type, categoryName };
  }

  /** 仅映射分类名（兼容测试与外部调用） */
  static mapCategoryNameOnly(
    transactionType: string,
    type: TransactionType,
    productName: string = '',
    counterparty: string = '',
    incomeExpenseLabel: string = ''
  ): string {
    return WechatCategoryMapper.mapCategoryName(
      { transactionType, productName, counterparty, incomeExpenseLabel, csvType: type },
      type
    );
  }

  static detectType(input: WechatMapInput): TransactionType {
    const txType = input.transactionType.trim();
    const product = input.productName.trim();

    if (/有退款|退款/.test(txType) || /退款/.test(product)) {
      return 'expense';
    }

    if (WechatCategoryMapper.hasIncomeExpenseLabel(input.incomeExpenseLabel)) {
      return input.csvType;
    }

    const fromProduct = WechatCategoryMapper.detectTypeFromProductName(product);
    if (fromProduct !== null) {
      return fromProduct;
    }

    return WechatCategoryMapper.detectTypeFromTransactionType(txType);
  }

  private static hasIncomeExpenseLabel(label: string): boolean {
    const normalized = label.trim();
    if (normalized.length === 0) {
      return false;
    }
    if (/收入|收/.test(normalized) && !/支出/.test(normalized)) {
      return true;
    }
    return /支出|付/.test(normalized);
  }

  private static detectTypeFromProductName(productName: string): TransactionType | null {
    if (productName.length === 0) {
      return null;
    }
    if (/-发给|转给|扫二维码付款|零钱提现|提现-到/.test(productName)) {
      return 'expense';
    }
    if (/-来自|来自/.test(productName)) {
      return 'income';
    }
    return null;
  }

  private static detectTypeFromTransactionType(transactionType: string): TransactionType {
    if (/充值/.test(transactionType) && !/提现/.test(transactionType)) {
      return 'income';
    }
    if (/提现|还款/.test(transactionType)) {
      return 'expense';
    }
    return 'expense';
  }

  private static mapCategoryName(input: WechatMapInput, type: TransactionType): string {
    const txKind = WechatCategoryMapper.normalizeTransactionKind(
      input.transactionType,
      input.productName
    );

    if (txKind === '红包') {
      return '礼金';
    }
    if (txKind === '转账') {
      return type === 'income' ? '其它' : '社交';
    }
    if (txKind === '群收款') {
      return type === 'income' ? '礼金' : '社交';
    }
    if (txKind === '二维码收付款' || txKind === '商户消费') {
      const keyword = WechatCategoryMapper.matchKeywordCategory(
        `${input.counterparty} ${input.productName}`
      );
      return keyword ?? getDefaultCategoryName('expense');
    }
    if (txKind === '充值提现') {
      if (/提现|零钱提现/.test(input.productName) || /提现/.test(input.transactionType)) {
        return '日用';
      }
      return type === 'income' ? '理财' : '日用';
    }
    if (txKind === '信用卡还款') {
      return getDefaultCategoryName('expense');
    }
    if (txKind === '有退款') {
      return getDefaultCategoryName('expense');
    }

    const combined = `${input.transactionType} ${input.productName} ${input.counterparty}`;
    const fuzzy = WechatCategoryMapper.matchKeywordCategory(combined);
    if (fuzzy !== null) {
      return fuzzy;
    }
    return getDefaultCategoryName(type);
  }

  private static normalizeTransactionKind(transactionType: string, productName: string): string {
    const combined = `${transactionType} ${productName}`;
    if (/红包/.test(combined)) {
      return '红包';
    }
    if (/群收款/.test(combined)) {
      return '群收款';
    }
    if (/转账/.test(combined)) {
      return '转账';
    }
    if (/二维码|扫二维码/.test(combined)) {
      return '二维码收付款';
    }
    if (/商户消费/.test(transactionType)) {
      return '商户消费';
    }
    if (/充值|提现/.test(combined)) {
      return '充值提现';
    }
    if (/信用卡还款/.test(combined)) {
      return '信用卡还款';
    }
    if (/有退款|退款/.test(combined)) {
      return '有退款';
    }
    return transactionType.trim();
  }

  /** 按交易对方 / 商品关键词匹配支出分类 */
  static matchKeywordCategory(text: string): string | null {
    const label = text.trim();
    if (label.length === 0) {
      return null;
    }
    if (/餐饮|美食|外卖|美团|饿了么|肯德基|麦当劳|星巴克|咖啡|奶茶|饭店|餐馆|小吃|沙县/.test(label)) {
      return '餐饮';
    }
    if (/超市|沃尔玛|家乐福|永辉|盒马|大润发|华润万家|物美|山姆|购物|百货|商场|便利店|7-11|罗森/.test(label)) {
      return '购物';
    }
    if (/菜场|菜市场|生鲜|蔬菜|农贸/.test(label)) {
      return '蔬菜';
    }
    if (/水果|果业|果园/.test(label)) {
      return '水果';
    }
    if (/零食|良品铺子|三只松鼠/.test(label)) {
      return '零食';
    }
    if (/日用|生活缴费|水电|燃气|物业缴费/.test(label)) {
      return '日用';
    }
    if (/交通|地铁|公交|滴滴|出租|打车|高铁|火车|机票|航空|出行/.test(label)) {
      return '交通';
    }
    if (/运动|健身|游泳|球馆/.test(label)) {
      return '运动';
    }
    if (/娱乐|游戏|电影|KTV|影院/.test(label)) {
      return '娱乐';
    }
    if (/通讯|话费|流量|移动|联通|电信/.test(label)) {
      return '通讯';
    }
    if (/服饰|服装|优衣库|ZARA|鞋/.test(label)) {
      return '服饰';
    }
    if (/美容|化妆|美发|美甲/.test(label)) {
      return '美容';
    }
    if (/住房|房租|房贷/.test(label)) {
      return '住房';
    }
    if (/居家|家居|宜家/.test(label)) {
      return '居家';
    }
    if (/孩子|育儿|奶粉|母婴/.test(label)) {
      return '孩子';
    }
    if (/长辈|父母/.test(label)) {
      return '长辈';
    }
    if (/旅行|旅游|酒店|民宿|携程|飞猪/.test(label)) {
      return '旅行';
    }
    if (/烟酒|香烟|白酒/.test(label)) {
      return '烟酒';
    }
    if (/数码|电子|苹果|华为|小米|电脑|手机/.test(label)) {
      return '数码';
    }
    if (/汽车|加油|停车|洗车|4S/.test(label)) {
      return '汽车';
    }
    if (/医疗|医院|药店|药品|诊所/.test(label)) {
      return '医疗';
    }
    if (/书籍|图书|书店/.test(label)) {
      return '书籍';
    }
    if (/学习|培训|教育|课程/.test(label)) {
      return '学习';
    }
    if (/宠物|猫粮|狗粮/.test(label)) {
      return '宠物';
    }
    if (/礼金|红包/.test(label)) {
      return '礼金';
    }
    if (/礼物/.test(label)) {
      return '礼物';
    }
    if (/办公|文具/.test(label)) {
      return '办公';
    }
    if (/维修|修理/.test(label)) {
      return '维修';
    }
    if (/捐赠|公益/.test(label)) {
      return '捐赠';
    }
    if (/彩票/.test(label)) {
      return '彩票';
    }
    if (/亲友|亲戚/.test(label)) {
      return '亲友';
    }
    if (/快递|物流|顺丰|圆通|中通|韵达/.test(label)) {
      return '快递';
    }
    if (/理财|基金|利息|收益/.test(label)) {
      return '理财';
    }
    if (/工资|薪资/.test(label)) {
      return '工资';
    }
    if (/兼职/.test(label)) {
      return '兼职';
    }
    return null;
  }
}
