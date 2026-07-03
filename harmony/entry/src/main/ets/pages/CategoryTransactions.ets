import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { DayGroup, MonthGroup, Transaction, TransactionType } from '../models/Transaction';
import { TransactionService } from '../services/TransactionService';
import { formatTransactionListTime, PeriodType } from '../utils/DateUtil';
import { formatAmount } from '../utils/MoneyUtil';

interface CategoryTransactionsParams {
  categoryId?: number;
  categoryName?: string;
  periodType?: string;
  anchorTime?: number;
  transactionType?: string;
}

@Entry
@Component
struct CategoryTransactions {
  @State categoryId: number = 0;
  @State categoryName: string = '';
  @State periodType: PeriodType = 'month';
  @State anchorDate: Date = new Date();
  @State transactionType: TransactionType = 'expense';
  @State flatItems: Transaction[] = [];
  @State dayGroups: DayGroup[] = [];
  @State monthGroups: MonthGroup[] = [];
  @State loading: boolean = true;

  aboutToAppear(): void {
    const params = router.getParams() as CategoryTransactionsParams;
    if (params.categoryId !== undefined) {
      this.categoryId = params.categoryId;
    }
    if (params.categoryName !== undefined && params.categoryName.length > 0) {
      this.categoryName = params.categoryName;
    }
    if (params.periodType === 'day' || params.periodType === 'month' || params.periodType === 'year') {
      this.periodType = params.periodType;
    }
    if (params.anchorTime !== undefined && params.anchorTime > 0) {
      this.anchorDate = new Date(params.anchorTime);
    }
    if (params.transactionType === 'income' || params.transactionType === 'expense') {
      this.transactionType = params.transactionType;
    }
    this.ensureReady();
  }

  onPageShow(): void {
    this.ensureReady();
  }

  private ensureReady(): void {
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.loadData();
    });
  }

  private loadData(): void {
    this.loading = true;
    const service = TransactionService.getInstance();
    const range = service.getPeriodRange(this.periodType, this.anchorDate);
    let listPromise: Promise<void>;
    if (this.periodType === 'day') {
      listPromise = service.listByCategoryInRange(
        this.categoryId, this.transactionType, range.startAt, range.endAt
      ).then((items: Transaction[]) => {
        this.flatItems = items;
        this.dayGroups = [];
        this.monthGroups = [];
      });
    } else if (this.periodType === 'month') {
      listPromise = service.listByCategoryGroupedInRange(
        this.categoryId, this.transactionType, range.startAt, range.endAt
      ).then((groups: DayGroup[]) => {
        this.dayGroups = groups;
        this.flatItems = [];
        this.monthGroups = [];
      });
    } else {
      listPromise = service.listByCategoryGroupedByMonthInRange(
        this.categoryId, this.transactionType, range.startAt, range.endAt
      ).then((groups: MonthGroup[]) => {
        this.monthGroups = groups;
        this.flatItems = [];
        this.dayGroups = [];
      });
    }
    listPromise
      .then(() => {
        this.loading = false;
      })
      .catch(() => {
        this.loading = false;
      });
  }

  private getPageTitle(): string {
    const year = this.anchorDate.getFullYear();
    const month = this.anchorDate.getMonth() + 1;
    if (this.periodType === 'day') {
      const day = this.anchorDate.getDate();
      return `${this.categoryName} - ${month}月${day}日明细`;
    }
    if (this.periodType === 'month') {
      return `${this.categoryName} - ${month}月明细`;
    }
    return `${this.categoryName} - ${year}年明细`;
  }

  private hasTransactions(): boolean {
    return this.flatItems.length > 0 || this.dayGroups.length > 0 || this.monthGroups.length > 0;
  }

  @Builder
  TransactionRow(item: Transaction) {
    Row() {
      Column({ space: 4 }) {
        if (item.payee.length > 0) {
          Text(item.payee)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
        } else {
          Text(item.categoryName.length > 0 ? item.categoryName : '未分类')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
        }
        Text(formatTransactionListTime(item.occurredAt, this.periodType))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
        if (item.note.length > 0) {
          Text(item.note)
            .fontSize(13)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 12 })

      Text(`${item.type === 'income' ? '+' : '-'}¥${formatAmount(item.amount)}`)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.type === 'income' ? $r('app.color.income') : $r('app.color.expense'))
        .flexShrink(0)
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ top: 12, bottom: 12, left: 4, right: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.item_background'))
  }

  @Builder
  GroupHeader(label: string) {
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
      .padding({ top: 16, bottom: 8 })
      .width('100%')
      .backgroundColor($r('app.color.item_background'))
  }

  @Builder
  TransactionListContent() {
    if (this.periodType === 'day') {
      ForEach(this.flatItems, (item: Transaction) => {
        ListItem() {
          this.TransactionRow(item);
        }
      }, (item: Transaction) => `${item.id}`)
    } else if (this.periodType === 'month') {
      ForEach(this.dayGroups, (group: DayGroup) => {
        ListItemGroup({ header: this.GroupHeader(group.dateLabel) }) {
          ForEach(group.items, (item: Transaction) => {
            ListItem() {
              this.TransactionRow(item);
            }
          }, (item: Transaction) => `${item.id}`)
        }
      }, (group: DayGroup) => group.dateKey)
    } else {
      ForEach(this.monthGroups, (group: MonthGroup) => {
        ListItemGroup({ header: this.GroupHeader(group.monthLabel) }) {
          ForEach(group.items, (item: Transaction) => {
            ListItem() {
              this.TransactionRow(item);
            }
          }, (item: Transaction) => `${item.id}`)
        }
      }, (group: MonthGroup) => group.monthKey)
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text(this.getPageTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(' ')
          .width(22)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      if (this.loading) {
        Column() {
          Text('加载中...')
            .fontSize(16)
            .fontColor($r('app.color.text_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.hasTransactions()) {
        Column() {
          Text('暂无流水')
            .fontSize(16)
            .fontColor($r('app.color.text_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          this.TransactionListContent()
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .divider({ strokeWidth: 1, color: $r('app.color.border_divider') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
