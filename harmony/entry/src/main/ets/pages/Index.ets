import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { DayGroup, MonthGroup, MonthSummary, Transaction } from '../models/Transaction';
import { ImportService } from '../services/import/ImportService';
import { TransactionService } from '../services/TransactionService';
import { PeriodDatePickerBody } from '../components/PeriodDatePickerBody';
import { formatPeriodLabel, formatTransactionListTime, getPeriodPickerTitle, PeriodType, shiftPeriod } from '../utils/DateUtil';
import { formatAmount } from '../utils/MoneyUtil';

@Component
export struct Index {
  @Prop @Watch('onRefreshToken') refreshToken: number = 0;
  @State summary: MonthSummary = new MonthSummary();
  @State dayGroups: DayGroup[] = [];
  @State monthGroups: MonthGroup[] = [];
  @State flatItems: Transaction[] = [];
  @State loading: boolean = true;
  @State periodType: PeriodType = 'day';
  @State selectedDate: Date = new Date();
  @State showDatePicker: boolean = false;
  private periodTypes: PeriodType[] = ['day', 'month', 'year'];

  aboutToAppear(): void {
    this.ensureReady();
  }

  onPageShow(): void {
    this.ensureReady();
  }

  private onRefreshToken(): void {
    if (this.refreshToken <= 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.refreshData();
    });
  }

  private ensureReady(): void {
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.refreshData();
    });
  }

  private refreshData(): void {
    this.loading = true;
    const service = TransactionService.getInstance();
    const range = service.getPeriodRange(this.periodType, this.selectedDate);
    const summaryPromise = service.getSummaryInRange(range.startAt, range.endAt);
    let listPromise: Promise<void>;
    if (this.periodType === 'day') {
      listPromise = service.listTransactionsInRange(range.startAt, range.endAt).then((items: Transaction[]) => {
        this.flatItems = items;
        this.dayGroups = [];
        this.monthGroups = [];
      });
    } else if (this.periodType === 'month') {
      listPromise = service.listTransactionsGroupedInRange(range.startAt, range.endAt).then((groups: DayGroup[]) => {
        this.dayGroups = groups;
        this.flatItems = [];
        this.monthGroups = [];
      });
    } else {
      listPromise = service.listTransactionsGroupedByMonthInRange(range.startAt, range.endAt)
        .then((groups: MonthGroup[]) => {
          this.monthGroups = groups;
          this.flatItems = [];
          this.dayGroups = [];
        });
    }
    Promise.all([summaryPromise, listPromise])
      .then((results: [MonthSummary, void]) => {
        this.summary = results[0];
        this.loading = false;
      })
      .catch(() => {
        this.loading = false;
      });
  }

  private switchPeriod(type: PeriodType): void {
    if (this.periodType === type) {
      return;
    }
    this.periodType = type;
    this.refreshData();
  }

  private shiftDate(delta: number): void {
    this.selectedDate = shiftPeriod(this.periodType, this.selectedDate, delta);
    this.refreshData();
  }

  private confirmDelete(item: Transaction): void {
    AlertDialog.show({
      title: '确认删除',
      message: '确定要删除这条记录吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.expense'),
        action: () => {
          this.deleteItem(item.id);
        }
      }
    });
  }

  private openEdit(item: Transaction): void {
    router.pushUrl({
      url: 'pages/AddTransaction',
      params: {
        transactionId: item.id,
        prefillAmount: formatAmount(item.amount),
        prefillType: item.type,
        prefillCategoryId: item.categoryId,
        prefillPayee: item.payee,
        prefillNote: item.note,
        prefillOccurredAt: item.occurredAt
      }
    });
  }

  private deleteItem(id: number): void {
    TransactionService.getInstance().deleteTransaction(id)
      .then(() => {
        promptAction.showToast({ message: '已删除' });
        this.refreshData();
      })
      .catch(() => {
        promptAction.showToast({ message: '删除失败' });
      });
  }

  private openStatistics(): void {
    router.pushUrl({
      url: 'pages/Statistics',
      params: {
        periodType: this.periodType,
        anchorTime: this.selectedDate.getTime()
      }
    });
  }

  private openScreenshotRecognize(): void {
    router.pushUrl({ url: 'pages/ScreenshotRecognize' });
  }

  private async openImportBills(): Promise<void> {
    try {
      const uri = await ImportService.pickFile();
      if (uri.length === 0) {
        return;
      }
      router.pushUrl({
        url: 'pages/ImportPreview',
        params: {
          fileUri: uri,
          fileName: ImportService.getFileName(uri),
          platform: 'unknown'
        }
      });
    } catch (err) {
      promptAction.showToast({ message: '选择文件失败' });
    }
  }

  private hasTransactions(): boolean {
    return this.flatItems.length > 0 || this.dayGroups.length > 0 || this.monthGroups.length > 0;
  }

  @Builder
  TransactionRow(item: Transaction) {
    Row() {
      Column({ space: 2 }) {
        if (item.payee.length > 0) {
          Text(item.payee)
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text(item.categoryName.length > 0 ? item.categoryName : '未分类')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(item.note.length > 0
          ? `${formatTransactionListTime(item.occurredAt, this.periodType)} · ${item.note}`
          : formatTransactionListTime(item.occurredAt, this.periodType))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 8 })

      Text(`${item.type === 'income' ? '+' : '-'}¥${formatAmount(item.amount)}`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.type === 'income' ? $r('app.color.income') : $r('app.color.expense'))
        .flexShrink(0)
    }
    .width('100%')
    .constraintSize({ minHeight: 40 })
    .padding({ top: 8, bottom: 8, left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.item_background'))
  }

  @Builder
  SwipeActions(item: Transaction) {
    Row() {
      Blank()
        .width(16)
      Row() {
        Text('修改')
          .fontSize(16)
          .fontColor($r('app.color.text_on_primary'))
      }
      .width(80)
      .height('100%')
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.brand_primary'))
      .onClick(() => {
        this.openEdit(item);
      })
      Row() {
        Text('删除')
          .fontSize(16)
          .fontColor($r('app.color.text_on_primary'))
      }
      .width(80)
      .height('100%')
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.expense'))
      .onClick(() => {
        this.confirmDelete(item);
      })
    }
    .height('100%')
  }

  @Builder
  SwipeableItem(item: Transaction) {
    ListItem() {
      this.TransactionRow(item)
    }
    .backgroundColor($r('app.color.item_background'))
    .swipeAction({
      end: {
        builder: () => {
          this.SwipeActions(item);
        }
      },
      edgeEffect: SwipeEdgeEffect.None
    })
  }

  @Builder
  GroupHeader(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .padding({ top: 8, bottom: 4 })
      .width('100%')
      .backgroundColor($r('app.color.item_background'))
  }

  @Builder
  SummaryCard() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('收入')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.loading ? '--' : `¥${formatAmount(this.summary.income)}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.income'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text('支出')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.loading ? '--' : `¥${formatAmount(this.summary.expense)}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.expense'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text('结余')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.loading ? '--' : `¥${formatAmount(this.summary.balance)}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(8)
    .margin({ left: 16, right: 16, top: 4, bottom: 4 })
  }

  @Builder
  PeriodTabs() {
    Row({ space: 6 }) {
      ForEach(this.periodTypes, (type: PeriodType) => {
        Button(type === 'day' ? '日' : (type === 'month' ? '月' : '年'))
          .layoutWeight(1)
          .height(32)
          .fontSize(14)
          .backgroundColor(this.periodType === type ? $r('app.color.brand_primary') : $r('app.color.button_inactive_bg'))
          .fontColor(this.periodType === type ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
          .onClick(() => this.switchPeriod(type))
      }, (type: PeriodType) => type)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4 })
  }

  @Builder
  DateNavigator() {
    Row() {
      Text('‹')
        .fontSize(24)
        .fontColor($r('app.color.text_primary'))
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => this.shiftDate(-1))

      Text(formatPeriodLabel(this.periodType, this.selectedDate))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.showDatePicker = true;
        })

      Text('›')
        .fontSize(24)
        .fontColor($r('app.color.text_primary'))
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => this.shiftDate(1))
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
  }

  @Builder
  BottomActions() {
    Row({ space: 8 }) {
      Button('记一笔')
        .layoutWeight(1.2)
        .height(36)
        .fontSize(15)
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddTransaction' });
        })
      Button('截图识别')
        .layoutWeight(1)
        .height(36)
        .fontSize(13)
        .backgroundColor($r('app.color.brand_light'))
        .fontColor($r('app.color.brand_primary'))
        .onClick(() => this.openScreenshotRecognize())
      Button('导入账单')
        .layoutWeight(1)
        .height(36)
        .fontSize(13)
        .backgroundColor($r('app.color.income_light'))
        .fontColor($r('app.color.income'))
        .onClick(() => this.openImportBills())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 8 })
  }

  @Builder
  TransactionListContent() {
    if (this.periodType === 'day') {
      ForEach(this.flatItems, (item: Transaction) => {
        this.SwipeableItem(item);
      }, (item: Transaction) => `${item.id}`)
    } else if (this.periodType === 'month') {
      ForEach(this.dayGroups, (group: DayGroup) => {
        ListItemGroup({ header: this.GroupHeader(group.dateLabel) }) {
          ForEach(group.items, (item: Transaction) => {
            this.SwipeableItem(item);
          }, (item: Transaction) => `${item.id}`)
        }
      }, (group: DayGroup) => group.dateKey)
    } else {
      ForEach(this.monthGroups, (group: MonthGroup) => {
        ListItemGroup({ header: this.GroupHeader(group.monthLabel) }) {
          ForEach(group.items, (item: Transaction) => {
            this.SwipeableItem(item);
          }, (item: Transaction) => `${item.id}`)
        }
      }, (group: MonthGroup) => group.monthKey)
    }
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.app_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('统计')
          .fontSize(15)
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.openStatistics())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 4 })

      this.PeriodTabs()
      this.DateNavigator()
      this.SummaryCard()

      Column() {
        if (this.loading) {
          Column() {
            Text('加载中...')
              .fontSize(15)
              .fontColor($r('app.color.text_tertiary'))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (!this.hasTransactions()) {
          Column() {
            Text('暂无流水')
              .fontSize(15)
              .fontColor($r('app.color.text_tertiary'))
            Button('记一笔')
              .height(36)
              .fontSize(15)
              .margin({ top: 12 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/AddTransaction' });
              })
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
          .scrollBar(BarState.Off)
        }
      }
      .layoutWeight(1)
      .width('100%')

      this.BottomActions()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .bindContentCover(this.showDatePicker, this.DatePickerCover(), {
      modalTransition: ModalTransition.DEFAULT,
      onDisappear: () => {
        this.showDatePicker = false;
      }
    })
  }

  @Builder
  DatePickerCover() {
    Column() {
      Column() {
        Row() {
          Text(getPeriodPickerTitle(this.periodType))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text('完成')
            .fontSize(16)
            .fontColor($r('app.color.brand_primary'))
            .onClick(() => {
              this.showDatePicker = false;
              this.refreshData();
            })
        }
        .width('100%')
        .margin({ bottom: 16 })

        PeriodDatePickerBody({
          selectedDate: $selectedDate,
          periodType: this.periodType,
          onJumpToCurrent: () => {
            this.showDatePicker = false;
            this.refreshData();
          }
        })
      }
      .width('100%')
      .padding(24)
      .backgroundColor($r('app.color.modal_background'))
      .borderRadius({ topLeft: 16, topRight: 16 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .backgroundColor($r('app.color.overlay_scrim'))    .onClick(() => {
      this.showDatePicker = false;
    })
  }
}
