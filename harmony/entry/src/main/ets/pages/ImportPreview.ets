import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { ImportDraft } from '../models/ImportDraft';
import { PaymentPlatform } from '../models/ParsedTransaction';
import { ImportService } from '../services/import/ImportService';
import { TransactionService } from '../services/TransactionService';
import { formatAmount } from '../utils/MoneyUtil';
import { formatDateTime } from '../utils/DateUtil';

@Entry
@Component
struct ImportPreview {
  @State platform: PaymentPlatform = 'unknown';
  @State drafts: ImportDraft[] = [];
  @State fileName: string = '';
  @State fileUri: string = '';
  @State selectedPlatform: PaymentPlatform = 'unknown';
  @State detectedPlatform: PaymentPlatform = 'unknown';
  @State skipDuplicates: boolean = true;
  @State loading: boolean = true;
  @State importing: boolean = false;
  @State errorMessage: string = '';
  @State parseErrors: string[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.fileUri = params['fileUri'] as string ?? '';
    this.fileName = params['fileName'] as string ?? ImportService.getFileName(this.fileUri);
    if (params['platform']) {
      this.selectedPlatform = params['platform'] as PaymentPlatform;
    }
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.loadFile();
    });
  }

  private async loadFile(): Promise<void> {
    if (!this.fileUri || this.fileUri.length === 0) {
      this.errorMessage = '未选择文件';
      this.loading = false;
      return;
    }
    await this.parseFile(this.selectedPlatform === 'unknown');
  }

  private async parseFile(trackDetected: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const forcePlatform = this.selectedPlatform === 'unknown' ? undefined : this.selectedPlatform;
      const parseResult = await ImportService.parseFromUri(
        this.fileUri,
        this.fileName,
        context.cacheDir,
        forcePlatform
      );
      this.parseErrors = parseResult.errors;
      this.platform = parseResult.platform;
      if (trackDetected && this.selectedPlatform === 'unknown' &&
        (parseResult.platform === 'wechat' || parseResult.platform === 'alipay')) {
        this.detectedPlatform = parseResult.platform;
      }
      const categories = await TransactionService.getInstance().getAllCategories();
      this.drafts = ImportService.resolveCategoryIds(parseResult.drafts, categories);
      if (this.drafts.length === 0 && this.parseErrors.length === 0) {
        this.parseErrors.push('未解析到有效账单记录');
      }
    } catch (err) {
      this.errorMessage = '读取文件失败';
      this.drafts = [];
      this.parseErrors = [];
    }
    this.loading = false;
  }

  private async switchPlatform(platform: PaymentPlatform): Promise<void> {
    if (this.selectedPlatform === platform) {
      return;
    }
    this.selectedPlatform = platform;
    await this.parseFile(platform === 'unknown');
  }

  private getSampleDrafts(): ImportDraft[] {
    const max = Math.min(5, this.drafts.length);
    const samples: ImportDraft[] = [];
    for (let i = 0; i < max; i++) {
      samples.push(this.drafts[i]);
    }
    return samples;
  }

  private getPlatformLabel(platform: PaymentPlatform = this.platform): string {
    if (platform === 'wechat') {
      return '微信';
    }
    if (platform === 'alipay') {
      return '支付宝';
    }
    return '未知';
  }

  private async doImport(): Promise<void> {
    if (this.drafts.length === 0) {
      return;
    }
    this.importing = true;
    try {
      const result = await TransactionService.getInstance().importDrafts(this.drafts, this.skipDuplicates);
      promptAction.showToast({
        message: `导入完成：新增 ${result.inserted} 条，跳过 ${result.skipped} 条`
      });
      router.back();
    } catch (err) {
      promptAction.showToast({ message: '导入失败' });
      this.importing = false;
    }
  }

  @Builder
  PlatformSelector() {
    Row({ space: 8 }) {
      Button('自动')
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.selectedPlatform === 'unknown' ? $r('app.color.brand_primary') : '#EEEEEE')
        .fontColor(this.selectedPlatform === 'unknown' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.switchPlatform('unknown');
        })
      Button('微信')
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.selectedPlatform === 'wechat' ? $r('app.color.wechat') : '#EEEEEE')
        .fontColor(this.selectedPlatform === 'wechat' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.switchPlatform('wechat');
        })
      Button('支付宝')
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.selectedPlatform === 'alipay' ? $r('app.color.alipay') : '#EEEEEE')
        .fontColor(this.selectedPlatform === 'alipay' ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.switchPlatform('alipay');
        })
    }
    .width('100%')
  }

  @Builder
  SampleRow(draft: ImportDraft) {
    Row() {
      Column({ space: 2 }) {
        Text(draft.note.length > 0 ? draft.note : draft.categoryName)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${formatDateTime(draft.occurredAt)} · ${draft.categoryName}`)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${draft.type === 'income' ? '+' : '-'}¥${formatAmount(draft.amount)}`)
        .fontSize(14)
        .fontColor(draft.type === 'income' ? $r('app.color.income') : $r('app.color.expense'))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text('导入预览')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('  ')
          .width(22)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      if (this.loading) {
        Column() {
          Text('解析中...')
            .fontSize(16)
            .fontColor($r('app.color.text_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 8 }) {
              Text('账单来源')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
              this.PlatformSelector()
              if (this.selectedPlatform === 'unknown' && this.detectedPlatform !== 'unknown') {
                Text(`自动识别为：${this.getPlatformLabel(this.detectedPlatform)}`)
                  .fontSize(13)
                  .fontColor($r('app.color.brand_primary'))
                  .alignSelf(ItemAlign.Start)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 4 }) {
              Text(`文件：${this.fileName}`)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
              Text(`来源：${this.getPlatformLabel()}`)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
              Text(`共 ${this.drafts.length} 条记录`)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 4 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Row() {
              Text('跳过重复记录')
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.skipDuplicates })
                .onChange((isOn: boolean) => {
                  this.skipDuplicates = isOn;
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(8)

            if (this.drafts.length > 0) {
              Column({ space: 4 }) {
                Text('样例记录')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })
                ForEach(this.getSampleDrafts(), (draft: ImportDraft, index: number) => {
                  this.SampleRow(draft);
                }, (draft: ImportDraft, index: number) => `${index}_${draft.dedupeKey}`)
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_background_alt'))
              .borderRadius(8)
            }

            ForEach(this.parseErrors, (msg: string, index: number) => {
              Text(msg)
                .fontSize(14)
                .fontColor($r('app.color.expense'))
            }, (msg: string, index: number) => `${index}_${msg}`)

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(14)
                .fontColor($r('app.color.expense'))
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)

        Button(this.importing ? '导入中...' : `确认导入 ${this.drafts.length} 条`)
          .width('90%')
          .height(48)
          .margin({ bottom: 24 })
          .enabled(!this.importing && this.drafts.length > 0 && this.errorMessage.length === 0)
          .onClick(() => this.doImport())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
