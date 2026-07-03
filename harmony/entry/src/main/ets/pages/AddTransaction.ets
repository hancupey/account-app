import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Category } from '../models/Category';
import { TransactionType } from '../models/Transaction';
import { TransactionService } from '../services/TransactionService';
import { applyPickerDateKeepTime, formatDateTime } from '../utils/DateUtil';
import { formatAmount, parseAmount } from '../utils/MoneyUtil';
import { PickerThemeUtil } from '../utils/PickerThemeUtil';

@Entry
@Component
struct AddTransaction {
  @State transactionType: TransactionType = 'expense';
  @State amountText: string = '';
  @State payee: string = '';
  @State note: string = '';
  @State categories: Category[] = [];
  @State categoryOptions: SelectOption[] = [];
  @State selectedCategoryIndex: number = 0;
  @State selectedDate: Date = new Date();
  @State showDateTimeEditor: boolean = false;
  @State saving: boolean = false;
  @State errorMessage: string = '';
  @State editingTransactionId: number = 0;
  private prefillCategoryId: number = 0;

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.applyPrefill();
      const loadPromise = this.editingTransactionId > 0 && this.amountText.length === 0
        ? this.loadForEdit()
        : Promise.resolve();
      loadPromise.then(() => {
        this.loadCategories();
      });
    });
  }

  private applyPrefill(): void {
    const params = router.getParams() as Record<string, Object>;
    if (!params) {
      return;
    }
    if (params['transactionId']) {
      this.editingTransactionId = params['transactionId'] as number;
    }
    if (params['prefillAmount']) {
      this.amountText = params['prefillAmount'] as string;
    }
    if (params['prefillType']) {
      this.transactionType = params['prefillType'] as TransactionType;
    }
    if (params['prefillCategoryId']) {
      this.prefillCategoryId = params['prefillCategoryId'] as number;
    }
    if (params['prefillPayee']) {
      this.payee = params['prefillPayee'] as string;
    }
    if (params['prefillNote']) {
      this.note = params['prefillNote'] as string;
    }
    if (params['prefillOccurredAt']) {
      this.selectedDate = new Date(params['prefillOccurredAt'] as number);
    }
  }

  private async loadForEdit(): Promise<void> {
    const tx = await TransactionService.getInstance().getTransactionById(this.editingTransactionId);
    if (tx === null) {
      return;
    }
    this.amountText = formatAmount(tx.amount);
    this.transactionType = tx.type;
    this.prefillCategoryId = tx.categoryId;
    this.payee = tx.payee;
    this.note = tx.note;
    this.selectedDate = new Date(tx.occurredAt);
  }

  private loadCategories(): void {
    TransactionService.getInstance().getCategories(this.transactionType)
      .then((list: Category[]) => {
        this.categories = list;
        this.categoryOptions = list.map((item: Category) => ({ value: item.name } as SelectOption));
        if (this.prefillCategoryId > 0) {
          const idx = list.findIndex((item: Category) => item.id === this.prefillCategoryId);
          this.selectedCategoryIndex = idx >= 0 ? idx : 0;
        } else {
          this.selectedCategoryIndex = 0;
        }
      });
  }

  private switchType(type: TransactionType): void {
    if (this.transactionType === type) {
      return;
    }
    this.transactionType = type;
    this.prefillCategoryId = 0;
    this.loadCategories();
  }

  private updateTimePart(value: TimePickerResult): void {
    const prev = this.selectedDate;
    this.selectedDate = new Date(
      prev.getFullYear(),
      prev.getMonth(),
      prev.getDate(),
      value.hour as number,
      value.minute as number,
      value.second !== undefined ? value.second as number : 0
    );
  }

  private async save(): Promise<void> {
    const amount = parseAmount(this.amountText);
    if (amount <= 0) {
      this.errorMessage = '请输入有效金额';
      return;
    }
    if (this.categories.length === 0) {
      this.errorMessage = '请先选择分类';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      const categoryId = this.categories[this.selectedCategoryIndex].id;
      const occurredAt = this.selectedDate.getTime();
      if (this.editingTransactionId > 0) {
        await TransactionService.getInstance().updateTransaction(
          this.editingTransactionId,
          amount,
          this.transactionType,
          categoryId,
          this.payee.trim(),
          this.note.trim(),
          occurredAt
        );
      } else {
        await TransactionService.getInstance().addTransaction(
          amount,
          this.transactionType,
          categoryId,
          this.payee.trim(),
          this.note.trim(),
          occurredAt
        );
      }
      router.back();
    } catch (err) {
      this.errorMessage = '保存失败，请重试';
      this.saving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text(this.editingTransactionId > 0 ? '修改' : '记一笔')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('保存')
          .fontSize(16)
          .fontColor(this.saving ? $r('app.color.text_disabled') : $r('app.color.brand_primary'))
          .onClick(() => {
            if (!this.saving) {
              this.save();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Scroll() {
        Column() {
          Row({ space: 12 }) {
            Button('支出')
              .layoutWeight(1)
              .height(40)
              .fontSize(16)
              .backgroundColor(this.transactionType === 'expense' ? $r('app.color.expense') : $r('app.color.button_inactive_bg'))
              .fontColor(this.transactionType === 'expense' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
              .onClick(() => this.switchType('expense'))

            Button('收入')
              .layoutWeight(1)
              .height(40)
              .fontSize(16)
              .backgroundColor(this.transactionType === 'income' ? $r('app.color.income') : $r('app.color.button_inactive_bg'))
              .fontColor(this.transactionType === 'income' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
              .onClick(() => this.switchType('income'))
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 8 })

          if (this.editingTransactionId === 0) {
            Column() {
              Button('从截图识别')
                .width('100%')
                .height(40)
                .fontSize(15)
                .backgroundColor($r('app.color.brand_light'))
                .fontColor($r('app.color.brand_primary'))
                .onClick(() => {
                  router.pushUrl({ url: 'pages/ScreenshotRecognize' });
                })
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 12 })
          }

          Column({ space: 8 }) {
            Text('金额')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.amountText, placeholder: '0.00' })
              .width('100%')
              .type(InputType.NUMBER_DECIMAL)
              .fontSize(28)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor($r('app.color.input_background'))
              .caretColor($r('app.color.brand_primary'))
              .onChange((value: string) => {
                this.amountText = value;
              })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 24 })

          Column({ space: 8 }) {
            Text('分类')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            if (this.categoryOptions.length > 0) {
              Select(this.categoryOptions)
                .selected(this.selectedCategoryIndex)
                .value(this.categoryOptions[this.selectedCategoryIndex].value)
                .font({ size: 16 })
                .fontColor($r('app.color.text_primary'))
                .onSelect((index: number) => {
                  this.selectedCategoryIndex = index;
                })
            } else {
              Text('暂无分类')
                .fontSize(16)
                .fontColor($r('app.color.text_hint'))
            }
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 20 })

          Column({ space: 8 }) {
            Text('支付对象')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.payee, placeholder: '商户/收款方（可选）' })
              .width('100%')
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor($r('app.color.input_background'))
              .caretColor($r('app.color.brand_primary'))
              .onChange((value: string) => {
                this.payee = value;
              })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 20 })

          Column({ space: 8 }) {
            Text('备注')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.note, placeholder: '可选' })
              .width('100%')
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor($r('app.color.input_background'))
              .caretColor($r('app.color.brand_primary'))
              .cancelButton({ style: CancelButtonStyle.INPUT })
              .onChange((value: string) => {
                this.note = value;
              })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 20 })

          Column({ space: 8 }) {
            Text('时间')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            Row({ space: 8 }) {
              Text(formatDateTime(this.selectedDate.getTime()))
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.showDateTimeEditor ? '收起' : '修改')
                .fontSize(14)
                .fontColor($r('app.color.brand_primary'))
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.showDateTimeEditor = !this.showDateTimeEditor;
                })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(8)
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              if (!this.showDateTimeEditor) {
                this.showDateTimeEditor = true;
              }
            })

            if (this.showDateTimeEditor) {
              DatePicker({
                start: new Date('2020-1-1'),
                end: new Date('2035-12-31'),
                selected: this.selectedDate
              })
                .disappearTextStyle(PickerThemeUtil.disappearStyle())
                .textStyle(PickerThemeUtil.textStyle())
                .selectedTextStyle(PickerThemeUtil.selectedStyle())
                .lunar(false)
                .onDateChange((value: Date) => {
                  this.selectedDate = applyPickerDateKeepTime(value, this.selectedDate);
                })
              TimePicker({
                selected: this.selectedDate
              })
                .disappearTextStyle(PickerThemeUtil.disappearStyle())
                .textStyle(PickerThemeUtil.textStyle())
                .selectedTextStyle(PickerThemeUtil.selectedStyle())
                .onChange((value: TimePickerResult) => {
                  this.updateTimePart(value);
                })
            }
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 20 })

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r('app.color.expense'))
              .margin({ top: 16 })
          }
        }
        .width('100%')
        .padding({ bottom: this.showDateTimeEditor ? 32 : 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
