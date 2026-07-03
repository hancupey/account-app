import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { BackupPayload, BackupTransaction } from '../models/BackupData';
import { BackupService } from '../services/backup/BackupService';
import { ImportService } from '../services/import/ImportService';
import { TransactionService } from '../services/TransactionService';
import { formatAmount } from '../utils/MoneyUtil';
import { formatDateTime } from '../utils/DateUtil';

@Entry
@Component
struct BackupPreview {
  @State fileName: string = '';
  @State fileUri: string = '';
  @State payload: BackupPayload | null = null;
  @State loading: boolean = true;
  @State restoring: boolean = false;
  @State skipDuplicates: boolean = true;
  @State errorMessage: string = '';
  @State parseErrors: string[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.fileUri = params['fileUri'] as string ?? '';
    this.fileName = params['fileName'] as string ?? ImportService.getFileName(this.fileUri);
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
    this.loading = true;
    this.errorMessage = '';
    try {
      const parseResult = await BackupService.parseFromUri(this.fileUri, this.fileName);
      this.parseErrors = parseResult.errors;
      this.payload = parseResult.payload;
      if (this.payload === null && this.parseErrors.length === 0) {
        this.parseErrors.push('无法解析备份文件');
      }
    } catch (_err) {
      this.errorMessage = '读取文件失败';
      this.payload = null;
      this.parseErrors = [];
    }
    this.loading = false;
  }

  private getCustomCategoryCount(): number {
    if (this.payload === null) {
      return 0;
    }
    let count = 0;
    for (const cat of this.payload.categories) {
      if (!cat.isSystem) {
        count++;
      }
    }
    return count;
  }

  private getSampleTransactions(): BackupTransaction[] {
    if (this.payload === null) {
      return [];
    }
    const max = Math.min(5, this.payload.transactions.length);
    const samples: BackupTransaction[] = [];
    for (let i = 0; i < max; i++) {
      samples.push(this.payload.transactions[i]);
    }
    return samples;
  }

  private async doMergeRestore(): Promise<void> {
    if (this.payload === null) {
      return;
    }
    this.restoring = true;
    try {
      const result = await BackupService.restore(this.payload, 'merge', this.skipDuplicates);
      promptAction.showToast({
        message: `恢复完成：新增 ${result.inserted} 条，跳过 ${result.skipped} 条，分类 ${result.categoriesAdded} 个`
      });
      router.back();
    } catch (_err) {
      promptAction.showToast({ message: '恢复失败' });
      this.restoring = false;
    }
  }

  private confirmOverwrite(): void {
    if (this.payload === null) {
      return;
    }
    AlertDialog.show({
      title: '确认全量覆盖',
      message: '将清空本地全部流水后导入备份数据，此操作不可撤销。确定继续吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '覆盖恢复',
        fontColor: $r('app.color.expense'),
        action: () => {
          this.doOverwriteRestore();
        }
      }
    });
  }

  private async doOverwriteRestore(): Promise<void> {
    if (this.payload === null) {
      return;
    }
    this.restoring = true;
    try {
      const result = await BackupService.restore(this.payload, 'overwrite', false);
      promptAction.showToast({
        message: `覆盖恢复完成：导入 ${result.inserted} 条，分类 ${result.categoriesAdded} 个`
      });
      router.back();
    } catch (_err) {
      promptAction.showToast({ message: '恢复失败' });
      this.restoring = false;
    }
  }

  @Builder
  SampleRow(tx: BackupTransaction) {
    Row() {
      Column({ space: 2 }) {
        Text(tx.note.length > 0 ? tx.note : tx.categoryName)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${formatDateTime(tx.occurredAt)} · ${tx.categoryName}`)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${tx.type === 'income' ? '+' : '-'}¥${formatAmount(tx.amount)}`)
        .fontSize(14)
        .fontColor(tx.type === 'income' ? $r('app.color.income') : $r('app.color.expense'))
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
        Text('备份恢复预览')
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
            Column({ space: 4 }) {
              Text(`文件：${this.fileName}`)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
              if (this.payload !== null) {
                Text(`导出时间：${formatDateTime(this.payload.exportedAt)}`)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                Text(`分类 ${this.payload.categories.length} 个（自定义 ${this.getCustomCategoryCount()}）`)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                Text(`流水 ${this.payload.transactions.length} 条`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .margin({ top: 4 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            if (this.payload !== null && this.payload.transactions.length > 0) {
              Row() {
                Text('跳过重复流水')
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

              Column({ space: 4 }) {
                Text('样例流水')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })
                ForEach(this.getSampleTransactions(), (tx: BackupTransaction, index: number) => {
                  this.SampleRow(tx);
                }, (tx: BackupTransaction, index: number) =>
                  `${index}_${tx.occurredAt}_${tx.amount}_${tx.note}`)
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

        Column({ space: 12 }) {
          Button(this.restoring ? '恢复中...' : '合并导入')
            .width('90%')
            .height(48)
            .enabled(!this.restoring && this.payload !== null && this.parseErrors.length === 0)
            .onClick(() => this.doMergeRestore())

          Button('全量覆盖')
            .width('90%')
            .height(44)
            .fontSize(15)
            .fontColor($r('app.color.expense'))
            .backgroundColor($r('app.color.expense_light'))
            .enabled(!this.restoring && this.payload !== null && this.parseErrors.length === 0)
            .onClick(() => this.confirmOverwrite())
        }
        .width('100%')
        .margin({ bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
