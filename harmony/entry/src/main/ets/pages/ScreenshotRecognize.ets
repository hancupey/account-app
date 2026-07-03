import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { getDefaultCategoryName } from '../database/CategoryDefaults';
import { Category } from '../models/Category';
import { PaymentPlatform } from '../models/ParsedTransaction';
import { RecognizedDraft } from '../models/RecognizedDraft';
import { TransactionType } from '../models/Transaction';
import { OcrService } from '../services/ocr/OcrService';
import { ScreenshotDraftBuilder } from '../services/ocr/ScreenshotDraftBuilder';
import { TransactionService } from '../services/TransactionService';
import { applyPickerDateKeepTime, formatDateTime } from '../utils/DateUtil';
import { formatAmount, parseAmount } from '../utils/MoneyUtil';

@Entry
@Component
struct ScreenshotRecognize {
  @State selectedPlatform: PaymentPlatform = 'unknown';
  @State detectedPlatform: PaymentPlatform = 'unknown';
  @State drafts: RecognizedDraft[] = [];
  @State loading: boolean = false;
  @State recognizeProgress: number = 0;
  @State recognizeTotal: number = 0;
  @State errorMessage: string = '';
  @State deleteAfterSave: boolean = false;
  @State saving: boolean = false;
  @State editingDraftId: string = '';
  @State editAmount: string = '';
  @State editPayee: string = '';
  @State editNote: string = '';
  @State editType: string = 'expense';
  @State editDate: Date = new Date();
  @State showDateTimeEditor: boolean = false;
  @State showRawText: boolean = false;
  @State editOcrText: string = '';
  @State editCategories: Category[] = [];
  @State editCategoryOptions: SelectOption[] = [];
  @State editCategoryIndex: number = 0;
  private allCategories: Category[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['platform']) {
      this.selectedPlatform = params['platform'] as PaymentPlatform;
    }
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.loadAllCategories();
    });
  }

  private loadAllCategories(): void {
    TransactionService.getInstance().getAllCategories().then((list: Category[]) => {
      this.allCategories = list;
    });
  }

  private getSavableDrafts(): RecognizedDraft[] {
    const result: RecognizedDraft[] = [];
    for (const draft of this.drafts) {
      if (draft.isSavable()) {
        result.push(draft);
      }
    }
    return result;
  }

  private getRecognizedCount(): number {
    let count = 0;
    for (const draft of this.drafts) {
      if (draft.status === 'recognized') {
        count++;
      }
    }
    return count;
  }

  private getFailedCount(): number {
    let count = 0;
    for (const draft of this.drafts) {
      if (draft.status === 'failed') {
        count++;
      }
    }
    return count;
  }

  private async pickAndRecognize(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const uris = await OcrService.pickImages(ScreenshotDraftBuilder.MAX_SCREENSHOTS);
      if (uris.length === 0) {
        this.loading = false;
        return;
      }
      await this.recognizeUris(uris);
    } catch (_err) {
      this.errorMessage = '选择或识别失败，请重试';
      promptAction.showToast({ message: '选择或识别失败' });
      this.loading = false;
    }
  }

  private async recognizeUris(uris: string[]): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.recognizeTotal = uris.length;
    this.recognizeProgress = 0;
    const results: RecognizedDraft[] = [];
    try {
      for (let i = 0; i < uris.length; i++) {
        const draft = await ScreenshotDraftBuilder.buildFromUri(
          uris[i],
          i,
          this.selectedPlatform,
          this.allCategories
        );
        results.push(draft);
        this.recognizeProgress = i + 1;
      }
      this.drafts = results;
      this.updateDetectedPlatform();
      if (this.selectedPlatform === 'unknown' &&
        (this.detectedPlatform === 'wechat' || this.detectedPlatform === 'alipay')) {
        this.selectedPlatform = this.detectedPlatform;
        this.reparseAllDrafts(false);
      }
    } catch (_err) {
      this.errorMessage = '识别失败，请重试';
      promptAction.showToast({ message: 'OCR 识别失败' });
    }
    this.loading = false;
  }

  private updateDetectedPlatform(): void {
    for (const draft of this.drafts) {
      if (draft.detectedPlatform === 'wechat' || draft.detectedPlatform === 'alipay') {
        this.detectedPlatform = draft.detectedPlatform;
        return;
      }
    }
    this.detectedPlatform = 'unknown';
  }

  private reparseAllDrafts(jumpOnAutoDetect: boolean): void {
    const next: RecognizedDraft[] = [];
    for (const draft of this.drafts) {
      const copy = ScreenshotRecognize.cloneDraft(draft);
      if (copy.ocrText.trim().length > 0) {
        ScreenshotDraftBuilder.reparseDraft(copy, this.selectedPlatform, this.allCategories);
      }
      next.push(copy);
    }
    this.drafts = next;
    this.updateDetectedPlatform();
    if (jumpOnAutoDetect && this.selectedPlatform === 'unknown' &&
      (this.detectedPlatform === 'wechat' || this.detectedPlatform === 'alipay')) {
      this.selectedPlatform = this.detectedPlatform;
      this.reparseAllDrafts(false);
    }
  }

  private static cloneDraft(source: RecognizedDraft): RecognizedDraft {
    const copy = new RecognizedDraft();
    copy.id = source.id;
    copy.imageUri = source.imageUri;
    copy.status = source.status;
    copy.failReason = source.failReason;
    copy.ocrText = source.ocrText;
    copy.detectedPlatform = source.detectedPlatform;
    copy.amount = source.amount;
    copy.amountText = source.amountText;
    copy.type = source.type;
    copy.payee = source.payee;
    copy.note = source.note;
    copy.occurredAt = source.occurredAt;
    copy.categoryId = source.categoryId;
    copy.categoryName = source.categoryName;
    copy.confidence = source.confidence;
    copy.revision = source.revision;
    return copy;
  }

  private removeDraft(id: string): void {
    const next: RecognizedDraft[] = [];
    for (const draft of this.drafts) {
      if (draft.id !== id) {
        next.push(draft);
      }
    }
    this.drafts = next;
    if (this.editingDraftId === id) {
      this.closeEdit();
    }
  }

  private confirmRemoveDraft(draft: RecognizedDraft): void {
    AlertDialog.show({
      title: '确认删除',
      message: '确定从列表中移除这条识别结果吗？',
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
          this.removeDraft(draft.id);
        }
      }
    });
  }

  private getDraftById(id: string): RecognizedDraft | null {
    for (const draft of this.drafts) {
      if (draft.id === id) {
        return draft;
      }
    }
    return null;
  }

  private openEdit(draft: RecognizedDraft): void {
    const source = this.getDraftById(draft.id) ?? draft;
    this.editingDraftId = source.id;
    this.editAmount = source.amountText;
    this.editPayee = source.payee;
    this.editNote = source.note;
    this.editType = source.type;
    this.editDate = new Date(source.occurredAt > 0 ? source.occurredAt : Date.now());
    this.editOcrText = source.ocrText;
    this.showDateTimeEditor = false;
    this.showRawText = false;
    this.loadEditCategories();
  }

  private closeEdit(): void {
    this.editingDraftId = '';
    this.showDateTimeEditor = false;
    this.showRawText = false;
  }

  private getEditingDraft(): RecognizedDraft | null {
    for (const draft of this.drafts) {
      if (draft.id === this.editingDraftId) {
        return draft;
      }
    }
    return null;
  }

  private loadEditCategories(): void {
    TransactionService.getInstance().getCategories(this.editType as TransactionType)
      .then((list: Category[]) => {
        this.editCategories = list;
        this.editCategoryOptions = list.map((item: Category) => ({ value: item.name } as SelectOption));
        const editing = this.getEditingDraft();
        let index = 0;
        if (editing !== null && editing.categoryId > 0) {
          const found = list.findIndex((item: Category) => item.id === editing.categoryId);
          index = found >= 0 ? found : 0;
        } else {
          const defaultName = getDefaultCategoryName(this.editType as TransactionType);
          const defaultIdx = list.findIndex((item: Category) => item.name === defaultName);
          index = defaultIdx >= 0 ? defaultIdx : 0;
        }
        this.editCategoryIndex = index;
      });
  }

  private switchEditType(type: string): void {
    if (this.editType === type) {
      return;
    }
    this.editType = type;
    this.loadEditCategories();
  }

  private saveEdit(): void {
    const amount = parseAmount(this.editAmount);
    if (amount <= 0) {
      promptAction.showToast({ message: '请输入有效金额' });
      return;
    }
    if (this.editCategories.length === 0) {
      promptAction.showToast({ message: '暂无可用分类' });
      return;
    }
    const next: RecognizedDraft[] = [];
    for (const draft of this.drafts) {
      if (draft.id !== this.editingDraftId) {
        next.push(draft);
        continue;
      }
      const updated = ScreenshotRecognize.cloneDraft(draft);
      updated.status = 'recognized';
      updated.failReason = '';
      updated.amount = amount;
      updated.amountText = formatAmount(amount);
      updated.type = this.editType as TransactionType;
      updated.payee = this.editPayee.trim();
      updated.note = this.editNote.trim();
      updated.occurredAt = this.editDate.getTime();
      updated.categoryId = this.editCategories[this.editCategoryIndex].id;
      updated.categoryName = this.editCategories[this.editCategoryIndex].name;
      updated.revision = draft.revision + 1;
      next.push(updated);
    }
    this.drafts = next;
    this.closeEdit();
  }

  private async batchConfirmSave(): Promise<void> {
    const savable = this.getSavableDrafts();
    if (savable.length === 0) {
      this.errorMessage = '没有可保存的识别结果';
      promptAction.showToast({ message: '没有可保存的识别结果' });
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    const urisToDelete: string[] = [];
    try {
      const service = TransactionService.getInstance();
      const result = await service.saveRecognizedDrafts(savable, true);
      if (result.inserted === 0 && result.skipped === 0) {
        this.errorMessage = '没有可保存的识别结果';
        promptAction.showToast({ message: '没有可保存的识别结果' });
        this.saving = false;
        return;
      }
      const summary = result.skipped > 0
        ? `入账 ${result.inserted} 条，跳过 ${result.skipped} 条重复`
        : `入账成功 ${result.inserted} 条`;
      if (this.deleteAfterSave) {
        urisToDelete.push(...ScreenshotDraftBuilder.collectDeletionUris(savable));
      }
      if (this.deleteAfterSave && urisToDelete.length > 0) {
        const context = getContext(this) as common.UIAbilityContext;
        const deleted = await ScreenshotDraftBuilder.deleteSourceImages(context, urisToDelete);
        if (deleted === 0) {
          promptAction.showToast({ message: `${summary}，截图未能删除，请手动在相册中清理` });
        } else if (deleted < urisToDelete.length) {
          promptAction.showToast({ message: `${summary}，部分截图未能删除` });
        } else {
          promptAction.showToast({ message: `${summary}，已删除截图` });
        }
      } else {
        promptAction.showToast({ message: summary });
      }
      router.back({ url: 'pages/Main' });
    } catch (_err) {
      this.errorMessage = '保存失败，请重试';
      promptAction.showToast({ message: '保存失败，请重试' });
      this.saving = false;
    }
  }

  private updateEditTimePart(value: TimePickerResult): void {
    const prev = this.editDate;
    this.editDate = new Date(
      prev.getFullYear(),
      prev.getMonth(),
      prev.getDate(),
      value.hour as number,
      value.minute as number,
      value.second !== undefined ? value.second as number : 0
    );
  }

  private platformLabel(platform: PaymentPlatform): string {
    if (platform === 'wechat') {
      return '微信';
    }
    if (platform === 'alipay') {
      return '支付宝';
    }
    return '未知';
  }

  private draftTitle(draft: RecognizedDraft): string {
    if (draft.status === 'failed') {
      return draft.failReason.length > 0 ? draft.failReason : '未识别';
    }
    if (draft.payee.length > 0) {
      return draft.payee;
    }
    if (draft.note.length > 0) {
      return draft.note;
    }
    return '账单详情';
  }

  @Builder
  PlatformSelector() {
    Row({ space: 8 }) {
      Button('自动')
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.selectedPlatform === 'unknown' ? $r('app.color.brand_primary') : $r('app.color.button_inactive_bg'))
        .fontColor(this.selectedPlatform === 'unknown' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.selectedPlatform = 'unknown';
          if (this.drafts.length > 0) {
            this.reparseAllDrafts(false);
          }
        })
      Button('微信')
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.selectedPlatform === 'wechat' ? $r('app.color.wechat') : $r('app.color.button_inactive_bg'))
        .fontColor(this.selectedPlatform === 'wechat' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.selectedPlatform = 'wechat';
          if (this.drafts.length > 0) {
            this.reparseAllDrafts(false);
          }
        })
      Button('支付宝')
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.selectedPlatform === 'alipay' ? $r('app.color.alipay') : $r('app.color.button_inactive_bg'))
        .fontColor(this.selectedPlatform === 'alipay' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.selectedPlatform = 'alipay';
          if (this.drafts.length > 0) {
            this.reparseAllDrafts(false);
          }
        })
    }
    .width('100%')
  }

  @Builder
  DraftRow(draft: RecognizedDraft) {
    Row() {
      Column({ space: 4 }) {
        Text(this.draftTitle(draft))
          .fontSize(15)
          .fontColor(draft.status === 'failed' ? $r('app.color.expense') : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (draft.status === 'recognized') {
          Text(`${formatDateTime(draft.occurredAt)} · ${draft.categoryName}`)
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text('左滑可删除')
            .fontSize(12)
            .fontColor($r('app.color.text_disabled'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (draft.status === 'recognized') {
        Text(`${draft.type === 'income' ? '+' : '-'}¥${formatAmount(draft.amount)}`)
          .fontSize(15)
          .fontColor(draft.type === 'income' ? $r('app.color.income') : $r('app.color.expense'))
      } else {
        Text('未识别')
          .fontSize(13)
          .fontColor($r('app.color.expense'))
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ top: 12, bottom: 12, left: 4, right: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.item_background'))
  }

  @Builder
  DraftSwipeActions(draft: RecognizedDraft) {
    Row() {
      Blank()
        .width(16)
      if (draft.status === 'recognized') {
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
          this.openEdit(draft);
        })
      }
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
        this.confirmRemoveDraft(draft);
      })
    }
    .height('100%')
  }

  @Builder
  DraftListItem(draft: RecognizedDraft) {
    ListItem() {
      this.DraftRow(draft)
    }
    .backgroundColor($r('app.color.item_background'))
    .swipeAction({
      end: {
        builder: () => {
          this.DraftSwipeActions(draft);
        }
      },
      edgeEffect: SwipeEdgeEffect.None
    })
  }

  @Builder
  PickPhase() {
    Column({ space: 20 }) {
      Text($r('app.string.screenshot_recognize_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')

      this.PlatformSelector()

      if (this.selectedPlatform === 'unknown' && this.detectedPlatform !== 'unknown') {
        Text(`自动识别为：${this.platformLabel(this.detectedPlatform)}`)
          .fontSize(13)
          .fontColor($r('app.color.brand_primary'))
          .width('100%')
      }

      Button(this.loading ? '识别中...' : $r('app.string.screenshot_pick_and_recognize'))
        .width('100%')
        .height(44)
        .fontSize(16)
        .enabled(!this.loading)
        .onClick(() => this.pickAndRecognize())

      if (this.loading && this.recognizeTotal > 0) {
        Text(`识别中 ${this.recognizeProgress}/${this.recognizeTotal}...`)
          .fontSize(14)
          .fontColor($r('app.color.brand_primary'))
          .width('100%')
      }

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor($r('app.color.expense'))
          .width('100%')
      }

      if (!this.loading) {
        Button($r('app.string.screenshot_manual_entry'))
          .width('100%')
          .height(44)
          .fontSize(15)
          .backgroundColor($r('app.color.button_inactive_bg'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            router.pushUrl({ url: 'pages/AddTransaction' });
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultPhase() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Text($r('app.string.screenshot_recognize_hint'))
            .fontSize(14)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')

          this.PlatformSelector()

          if (this.selectedPlatform === 'unknown' && this.detectedPlatform !== 'unknown') {
            Text(`自动识别为：${this.platformLabel(this.detectedPlatform)}`)
              .fontSize(13)
              .fontColor($r('app.color.brand_primary'))
              .width('100%')
          }

          Row({ space: 8 }) {
            Text(`共 ${this.drafts.length} 张`)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text(`成功 ${this.getRecognizedCount()} 条`)
              .fontSize(14)
              .fontColor($r('app.color.income'))
            if (this.getFailedCount() > 0) {
              Text(`未识别 ${this.getFailedCount()} 张`)
                .fontSize(14)
                .fontColor($r('app.color.expense'))
            }
          }
          .width('100%')

          List({ space: 0 }) {
            ForEach(this.drafts, (draft: RecognizedDraft) => {
              this.DraftListItem(draft);
            }, (draft: RecognizedDraft) => `${draft.id}_${draft.revision}`)
          }
          .width('100%')
          .divider({ strokeWidth: 1, color: $r('app.color.border_light') })
          .edgeEffect(EdgeEffect.None)

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r('app.color.expense'))
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.screenshot_delete_after_save'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.deleteAfterSave })
            .onChange((isOn: boolean) => {
              this.deleteAfterSave = isOn;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })

        Button(this.saving ?
          $r('app.string.screenshot_saving') :
          `确认入账 ${this.getSavableDrafts().length} 条`)
          .width('100%')
          .height(48)
          .fontSize(16)
          .enabled(!this.saving && this.getSavableDrafts().length > 0)
          .margin({ left: 16, right: 16, bottom: 16 })
          .onClick(() => this.batchConfirmSave())
      }
    }
    .layoutWeight(1)
  }

  @Builder
  EditOverlay() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.closeEdit())
        Text('编辑识别结果')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('保存')
          .fontSize(16)
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.saveEdit())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 10 })

      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 8 }) {
            Button('支出')
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .backgroundColor(this.editType === 'expense' ? $r('app.color.expense') : $r('app.color.button_inactive_bg'))
              .fontColor(this.editType === 'expense' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
              .onClick(() => { this.switchEditType('expense'); })
            Button('收入')
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .backgroundColor(this.editType === 'income' ? $r('app.color.income') : $r('app.color.button_inactive_bg'))
              .fontColor(this.editType === 'income' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
              .onClick(() => { this.switchEditType('income'); })
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('分类')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            if (this.editCategoryOptions.length > 0) {
              Select(this.editCategoryOptions)
                .selected(this.editCategoryIndex)
                .value(this.editCategoryOptions[this.editCategoryIndex].value)
                .font({ size: 16 })
                .fontColor($r('app.color.text_primary'))
                .onSelect((index: number) => {
                  this.editCategoryIndex = index;
                })
            } else {
              Text('暂无分类')
                .fontSize(16)
                .fontColor($r('app.color.text_hint'))
            }
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('金额')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.editAmount, placeholder: '0.00' })
              .width('100%')
              .height(44)
              .fontSize(18)
              .type(InputType.NUMBER_DECIMAL)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor($r('app.color.input_background'))
              .caretColor($r('app.color.brand_primary'))
              .onChange((v: string) => { this.editAmount = v; })
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('支付对象')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.editPayee, placeholder: '商户/收款方' })
              .width('100%')
              .height(44)
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor($r('app.color.input_background'))
              .caretColor($r('app.color.brand_primary'))
              .onChange((v: string) => { this.editPayee = v; })
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('备注')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.editNote, placeholder: '商品说明' })
              .width('100%')
              .height(44)
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor($r('app.color.input_background'))
              .caretColor($r('app.color.brand_primary'))
              .cancelButton({ style: CancelButtonStyle.INPUT })
              .onChange((v: string) => { this.editNote = v; })
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('时间')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
            Row({ space: 8 }) {
              Text(formatDateTime(this.editDate.getTime()))
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

            if (this.showDateTimeEditor) {
              DatePicker({
                start: new Date('2020-1-1'),
                end: new Date('2035-12-31'),
                selected: this.editDate
              })
                .lunar(false)
                .onDateChange((value: Date) => {
                  this.editDate = applyPickerDateKeepTime(value, this.editDate);
                })
              TimePicker({
                selected: this.editDate
              })
                .onChange((value: TimePickerResult) => {
                  this.updateEditTimePart(value);
                })
            }
          }
          .width('100%')

          if (this.editOcrText.length > 0) {
            Text(this.showRawText ? '收起原始文本' : '查看原始 OCR 文本')
              .fontSize(13)
              .fontColor($r('app.color.brand_primary'))
              .alignSelf(ItemAlign.Start)
              .onClick(() => { this.showRawText = !this.showRawText; })

            if (this.showRawText) {
              Text(this.editOcrText)
                .fontSize(12)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.card_background'))
                .borderRadius(8)
            }
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('←')
            .fontSize(22)
            .fontColor($r('app.color.text_primary'))
            .onClick(() => router.back())
          Text($r('app.string.screenshot_recognize'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('  ')
            .width(22)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 10 })

        if (this.drafts.length === 0) {
          this.PickPhase()
        } else {
          this.ResultPhase()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      if (this.editingDraftId.length > 0) {
        this.EditOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
