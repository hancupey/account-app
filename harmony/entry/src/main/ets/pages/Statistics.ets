import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { CategoryStat, DailyExpenseStat, MonthSummary, MonthlyExpenseStat } from '../models/Transaction';
import { TransactionService } from '../services/TransactionService';
import { PeriodDatePickerBody } from '../components/PeriodDatePickerBody';
import {
  dateFromParts,
  formatPeriodLabel,
  getDaysInMonth,
  getFirstWeekdayOfMonth,
  getPeriodPickerTitle,
  PeriodType,
  shiftPeriod
} from '../utils/DateUtil';
import { formatAmount } from '../utils/MoneyUtil';

interface StatisticsParams {
  periodType?: string;
  anchorTime?: number;
}

interface PeriodSnapshot {
  periodType: PeriodType;
  selectedDate: Date;
}

interface CalendarCell {
  day: number;
  expense: number;
  date: Date | null;
}

@Entry
@Component
struct Statistics {
  @State summary: MonthSummary = new MonthSummary();
  @State categoryStats: CategoryStat[] = [];
  @State dailyExpenses: DailyExpenseStat[] = [];
  @State monthlyExpenses: MonthlyExpenseStat[] = [];
  @State loading: boolean = true;
  @State periodType: PeriodType = 'day';
  @State selectedDate: Date = new Date();
  @State showDatePicker: boolean = false;
  @State drillStack: PeriodSnapshot[] = [];
  @State calendarCells: CalendarCell[] = [];
  private periodTypes: PeriodType[] = ['day', 'month', 'year'];
  private weekdayLabels: string[] = ['日', '一', '二', '三', '四', '五', '六'];
  private monthNumbers: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  aboutToAppear(): void {
    const params = router.getParams() as StatisticsParams;
    if (params.periodType === 'day' || params.periodType === 'month' || params.periodType === 'year') {
      this.periodType = params.periodType;
    }
    if (params.anchorTime !== undefined && params.anchorTime > 0) {
      this.selectedDate = new Date(params.anchorTime);
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
    const range = service.getPeriodRange(this.periodType, this.selectedDate);
    const promises: Promise<void>[] = [
      service.getSummaryInRange(range.startAt, range.endAt).then((s: MonthSummary) => {
        this.summary = s;
      }),
      service.getCategoryBreakdown(range.startAt, range.endAt).then((stats: CategoryStat[]) => {
        this.categoryStats = stats;
      })
    ];
    if (this.periodType === 'month') {
      promises.push(
        service.getDailyExpenseInRange(range.startAt, range.endAt).then((stats: DailyExpenseStat[]) => {
          this.dailyExpenses = stats;
        })
      );
    } else {
      this.dailyExpenses = [];
    }
    if (this.periodType === 'year') {
      promises.push(
        service.getMonthlyExpenseInRange(range.startAt, range.endAt).then((stats: MonthlyExpenseStat[]) => {
          this.monthlyExpenses = stats;
        })
      );
    } else {
      this.monthlyExpenses = [];
    }
    Promise.all(promises)
      .then(() => {
        if (this.periodType === 'month') {
          this.calendarCells = this.buildMonthCalendarCells();
        } else {
          this.calendarCells = [];
        }
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
    this.drillStack = [];
    this.loadData();
  }

  private shiftDate(delta: number): void {
    this.selectedDate = shiftPeriod(this.periodType, this.selectedDate, delta);
    this.drillStack = [];
    this.loadData();
  }

  private goBack(): void {
    if (this.drillStack.length > 0) {
      const stack = this.drillStack.slice();
      const prev = stack.pop() as PeriodSnapshot;
      this.drillStack = stack;
      this.periodType = prev.periodType;
      this.selectedDate = prev.selectedDate;
      this.loadData();
      return;
    }
    router.back();
  }

  private pushDrillState(): void {
    const snapshot: PeriodSnapshot = {
      periodType: this.periodType,
      selectedDate: new Date(this.selectedDate.getTime())
    };
    this.drillStack = this.drillStack.concat([snapshot]);
  }

  private drillToDay(date: Date): void {
    this.pushDrillState();
    this.periodType = 'day';
    this.selectedDate = date;
    this.loadData();
  }

  private drillToMonth(month: number): void {
    this.pushDrillState();
    const year = this.selectedDate.getFullYear();
    this.periodType = 'month';
    this.selectedDate = dateFromParts(year, month, 1);
    this.loadData();
  }

  private getPeriodTitle(): string {
    if (this.periodType === 'day') {
      return '当日统计';
    }
    if (this.periodType === 'month') {
      return '本月统计';
    }
    return '本年统计';
  }

  private getDailyExpense(day: number): number {
    for (const stat of this.dailyExpenses) {
      if (stat.day === day) {
        return stat.total;
      }
    }
    return 0;
  }

  private getMonthlyExpense(month: number): number {
    for (const stat of this.monthlyExpenses) {
      if (stat.month === month) {
        return stat.total;
      }
    }
    return 0;
  }

  private buildMonthCalendarCells(): CalendarCell[] {
    const year = this.selectedDate.getFullYear();
    const month = this.selectedDate.getMonth() + 1;
    const daysInMonth = getDaysInMonth(year, month);
    const firstWeekday = getFirstWeekdayOfMonth(year, month);
    const cells: CalendarCell[] = [];
    for (let i = 0; i < firstWeekday; i++) {
      const empty: CalendarCell = { day: 0, expense: 0, date: null };
      cells.push(empty);
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const cell: CalendarCell = {
        day: d,
        expense: this.getDailyExpense(d),
        date: dateFromParts(year, month, d)
      };
      cells.push(cell);
    }
    return cells;
  }

  private formatCompactAmount(amount: number): string {
    if (amount <= 0) {
      return '';
    }
    return `¥${formatAmount(amount)}`;
  }

  private openCategoryDetail(stat: CategoryStat): void {
    router.pushUrl({
      url: 'pages/CategoryTransactions',
      params: {
        categoryId: stat.categoryId,
        categoryName: stat.categoryName,
        periodType: this.periodType,
        anchorTime: this.selectedDate.getTime(),
        transactionType: stat.type
      }
    });
  }

  @Builder
  CategoryRow(stat: CategoryStat) {
    Row() {
      Text(stat.categoryName)
        .fontSize(15)
        .fontColor('#333333')
        .layoutWeight(1)
      Text(`${stat.type === 'income' ? '+' : '-'}¥${formatAmount(stat.total)}`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(stat.type === 'income' ? '#2E7D32' : '#C62828')
      Text('›')
        .fontSize(18)
        .fontColor('#BBBBBB')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => this.openCategoryDetail(stat))
  }

  @Builder
  PeriodTabs() {
    Row({ space: 8 }) {
      ForEach(this.periodTypes, (type: PeriodType) => {
        Button(type === 'day' ? '日' : (type === 'month' ? '月' : '年'))
          .layoutWeight(1)
          .height(36)
          .fontSize(15)
          .backgroundColor(this.periodType === type ? '#1565C0' : '#EEEEEE')
          .fontColor(this.periodType === type ? '#FFFFFF' : '#666666')
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
        .fontSize(28)
        .fontColor('#333333')
        .width(40)
        .textAlign(TextAlign.Center)
        .onClick(() => this.shiftDate(-1))

      Text(formatPeriodLabel(this.periodType, this.selectedDate))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.showDatePicker = true;
        })

      Text('›')
        .fontSize(28)
        .fontColor('#333333')
        .width(40)
        .textAlign(TextAlign.Center)
        .onClick(() => this.shiftDate(1))
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
  }

  @Builder
  MonthDayCell(cell: CalendarCell) {
    Column({ space: 2 }) {
      if (cell.day > 0) {
        Text(`${cell.day}`)
          .fontSize(14)
          .fontColor('#333333')
        if (cell.expense > 0) {
          Text(this.formatCompactAmount(cell.expense))
            .fontSize(10)
            .fontColor('#C62828')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(cell.day > 0 && cell.expense > 0 ? '#FFF3E0' : '#FAFAFA')
    .borderRadius(6)
    .onClick(() => {
      if (cell.date !== null) {
        this.drillToDay(cell.date);
      }
    })
  }

  @Builder
  MonthCalendar() {
    Column() {
      Text('每日支出')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Row() {
        ForEach(this.weekdayLabels, (label: string) => {
          Text(label)
            .fontSize(12)
            .fontColor('#888888')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (label: string) => label)
      }
      .width('100%')
      .margin({ bottom: 8 })

      Grid() {
        ForEach(this.calendarCells, (cell: CalendarCell, index: number) => {
          GridItem() {
            this.MonthDayCell(cell);
          }
        }, (cell: CalendarCell, index: number) => `${index}_${cell.day}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
    .borderRadius(12)
  }

  @Builder
  YearMonthCell(month: number) {
    Column({ space: 4 }) {
      Text(`${month}月`)
        .fontSize(15)
        .fontColor('#333333')
      Text(this.formatCompactAmount(this.getMonthlyExpense(month)))
        .fontSize(12)
        .fontColor('#C62828')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.getMonthlyExpense(month) > 0 ? '#FFF3E0' : '#FAFAFA')
    .borderRadius(8)
    .onClick(() => {
      this.drillToMonth(month);
    })
  }

  @Builder
  YearCalendar() {
    Column() {
      Text('每月支出')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Grid() {
        ForEach(this.monthNumbers, (month: number) => {
          GridItem() {
            this.YearMonthCell(month);
          }
        }, (month: number) => `${month}`)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
    .borderRadius(12)
  }

  @Builder
  SummaryCard() {
    Column() {
      Text(this.getPeriodTitle())
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 16 })

      Row() {
        Column() {
          Text('收入')
            .fontSize(14)
            .fontColor('#888888')
          Text(`¥${formatAmount(this.summary.income)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2E7D32')
            .margin({ top: 8 })
        }
        .layoutWeight(1)

        Column() {
          Text('支出')
            .fontSize(14)
            .fontColor('#888888')
          Text(`¥${formatAmount(this.summary.expense)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#C62828')
            .margin({ top: 8 })
        }
        .layoutWeight(1)

        Column() {
          Text('结余')
            .fontSize(14)
            .fontColor('#888888')
          Text(`¥${formatAmount(this.summary.balance)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1565C0')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
    .borderRadius(12)
  }

  @Builder
  CategorySection() {
    Column() {
      Text('分类明细')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      if (this.categoryStats.length === 0) {
        Text('暂无数据')
          .fontSize(15)
          .fontColor('#999999')
          .padding({ top: 16, bottom: 16 })
      } else {
        ForEach(this.categoryStats, (stat: CategoryStat) => {
          this.CategoryRow(stat);
        }, (stat: CategoryStat) => `${stat.categoryId}_${stat.type}`)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
    .borderRadius(12)
  }

  @Builder
  DatePickerCover() {
    Column() {
      Column() {
        Row() {
          Text(getPeriodPickerTitle(this.periodType))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
          Text('完成')
            .fontSize(16)
            .fontColor('#1565C0')
            .onClick(() => {
              this.showDatePicker = false;
              this.drillStack = [];
              this.loadData();
            })
        }
        .width('100%')
        .margin({ bottom: 16 })

        PeriodDatePickerBody({
          selectedDate: $selectedDate,
          periodType: this.periodType,
          onJumpToCurrent: () => {
            this.showDatePicker = false;
            this.drillStack = [];
            this.loadData();
          }
        })
      }
      .width('100%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 16, topRight: 16 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .backgroundColor('rgba(0,0,0,0.4)')
    .onClick(() => {
      this.showDatePicker = false;
    })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor('#333333')
          .onClick(() => this.goBack())
        Text('统计')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text(' ')
          .width(22)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      this.PeriodTabs()
      this.DateNavigator()

      if (this.loading) {
        Column() {
          Text('加载中...')
            .fontSize(16)
            .fontColor('#888888')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            this.SummaryCard()

            if (this.periodType === 'month') {
              this.MonthCalendar()
            }
            if (this.periodType === 'year') {
              this.YearCalendar()
            }

            this.CategorySection()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .bindContentCover(this.showDatePicker, this.DatePickerCover(), {
      modalTransition: ModalTransition.DEFAULT,
      onDisappear: () => {
        this.showDatePicker = false;
      }
    })
  }
}
