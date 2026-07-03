import {
  applyPeriodPickerDate,
  applyYearPickerIndex,
  buildYearPickerLabels,
  getCurrentPeriodAnchor,
  PERIOD_PICKER_END_YEAR,
  PERIOD_PICKER_START_YEAR,
  PeriodType,
  yearToPickerIndex
} from '../utils/DateUtil';
import { PickerThemeUtil } from '../utils/PickerThemeUtil';

function datePickerModeForPeriod(type: PeriodType): DatePickerMode {
  if (type === 'month') {
    return DatePickerMode.YEAR_AND_MONTH;
  }
  return DatePickerMode.DATE;
}

@Component
export struct PeriodDatePickerBody {
  @Link selectedDate: Date;
  @Prop periodType: PeriodType;
  onJumpToCurrent: () => void = () => {};
  @State yearPickerIndex: number = 0;
  private yearLabels: string[] = buildYearPickerLabels();

  aboutToAppear(): void {
    this.syncYearPickerIndex();
  }

  private syncYearPickerIndex(): void {
    this.yearPickerIndex = yearToPickerIndex(this.selectedDate.getFullYear());
  }

  private jumpToCurrent(): void {
    this.selectedDate = getCurrentPeriodAnchor(this.periodType);
    if (this.periodType === 'year') {
      this.syncYearPickerIndex();
    }
    this.onJumpToCurrent();
  }

  build() {
    Column() {
      if (this.periodType === 'year') {
        TextPicker({
          range: this.yearLabels,
          selected: this.yearPickerIndex
        })
          .disappearTextStyle(PickerThemeUtil.disappearStyle())
          .textStyle(PickerThemeUtil.textStyle())
          .selectedTextStyle(PickerThemeUtil.selectedStyle())
          .onChange((value: string | string[], index: number | number[]) => {
            const idx = typeof index === 'number' ? index : (index as number[])[0];
            this.yearPickerIndex = idx;
            this.selectedDate = applyYearPickerIndex(this.selectedDate, idx);
          })
      } else {
        DatePicker({
          start: new Date(`${PERIOD_PICKER_START_YEAR}-1-1`),
          end: new Date(`${PERIOD_PICKER_END_YEAR}-12-31`),
          selected: this.selectedDate,
          mode: datePickerModeForPeriod(this.periodType)
        })
          .disappearTextStyle(PickerThemeUtil.disappearStyle())
          .textStyle(PickerThemeUtil.textStyle())
          .selectedTextStyle(PickerThemeUtil.selectedStyle())
          .lunar(false)
          .onDateChange((value: Date) => {
            this.selectedDate = applyPeriodPickerDate(this.periodType, value, this.selectedDate);
          })
      }

      Text('回到当前')
        .fontSize(16)
        .fontColor($r('app.color.brand_primary'))
        .margin({ top: 12 })
        .alignSelf(ItemAlign.Center)
        .onClick(() => {
          this.jumpToCurrent();
        })
    }
    .width('100%')
  }
}
