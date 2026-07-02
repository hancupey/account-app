import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { BackupService } from '../services/backup/BackupService';
import { ImportService } from '../services/import/ImportService';
import { TransactionService } from '../services/TransactionService';

@Component
export struct SettingsContent {
  @State exporting: boolean = false;
  @State restoring: boolean = false;

  private buildBackupErrorToast(message: string): string {
    if (message.length === 0) {
      return '备份失败';
    }
    const detail = message.length > 40 ? `${message.substring(0, 40)}…` : message;
    return `备份失败：${detail}`;
  }

  private async exportBackup(): Promise<void> {
    if (this.exporting) {
      return;
    }
    this.exporting = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await TransactionService.getInstance().init(context);
      const exportResult = await BackupService.exportToFile(context);
      if (exportResult.status === 'success') {
        promptAction.showToast({ message: '备份已保存' });
      } else if (exportResult.status === 'error') {
        promptAction.showToast({ message: this.buildBackupErrorToast(exportResult.message) });
      }
    } catch (err) {
      promptAction.showToast({ message: this.buildBackupErrorToast(`${err}`) });
    }
    this.exporting = false;
  }

  private async openRestore(): Promise<void> {
    if (this.restoring) {
      return;
    }
    this.restoring = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await TransactionService.getInstance().init(context);
      const uri = await BackupService.pickBackupFile();
      if (uri.length === 0) {
        this.restoring = false;
        return;
      }
      router.pushUrl({
        url: 'pages/BackupPreview',
        params: {
          fileUri: uri,
          fileName: ImportService.getFileName(uri)
        }
      });
    } catch (_err) {
      promptAction.showToast({ message: '选择文件失败' });
    }
    this.restoring = false;
  }

  build() {
    Column() {
      Row() {
        Text('设置')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 48, bottom: 16 })

      List() {
        ListItem() {
          Row() {
            Text('分类管理')
              .fontSize(16)
              .fontColor('#333333')
              .layoutWeight(1)
            Text('›')
              .fontSize(20)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/CategoryManage' });
          })
        }

        ListItem() {
          Row() {
            Column({ space: 4 }) {
              Text('数据备份')
                .fontSize(16)
                .fontColor('#333333')
              Text(this.exporting ? '导出中...' : '导出全部数据到 JSON 文件')
                .fontSize(13)
                .fontColor('#888888')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(20)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .onClick(() => {
            this.exportBackup();
          })
        }

        ListItem() {
          Row() {
            Column({ space: 4 }) {
              Text('从备份恢复')
                .fontSize(16)
                .fontColor('#333333')
              Text(this.restoring ? '选择中...' : '从 JSON 备份文件恢复数据')
                .fontSize(13)
                .fontColor('#888888')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(20)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .onClick(() => {
            this.openRestore();
          })
        }

        ListItem() {
          Row() {
            Column({ space: 4 }) {
              Text('关于')
                .fontSize(16)
                .fontColor('#BBBBBB')
              Text('即将推出')
                .fontSize(13)
                .fontColor('#CCCCCC')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .divider({ strokeWidth: 1, color: '#EEEEEE' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
