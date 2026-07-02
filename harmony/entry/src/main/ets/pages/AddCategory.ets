import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { CategoryType } from '../models/Category';
import { TransactionService } from '../services/TransactionService';

@Entry
@Component
struct AddCategory {
  @State mode: string = 'add';
  @State categoryId: number = 0;
  @State categoryType: CategoryType = 'expense';
  @State nameText: string = '';
  @State saving: boolean = false;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    this.applyParams();  
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context);
  }

  private applyParams(): void {
    const params = router.getParams() as Record<string, Object>;
    if (!params) {
      return;
    }
    if (params['mode']) {
      this.mode = params['mode'] as string;
    }
    if (params['categoryId']) {
      this.categoryId = params['categoryId'] as number;
    }
    if (params['categoryName']) {
      this.nameText = params['categoryName'] as string;
    }
    if (params['categoryType']) {
      this.categoryType = params['categoryType'] as CategoryType;
    }
  }

  private getTitle(): string {
    return this.mode === 'edit' ? '编辑分类' : '添加分类';
  }

  private async save(): Promise<void> {
    const trimmed = this.nameText.trim();
    if (trimmed.length === 0) {
      this.errorMessage = '请输入分类名称';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      const service = TransactionService.getInstance();
      if (this.mode === 'edit') {
        await service.updateCategory(this.categoryId, trimmed);
      } else {
        await service.insertCustomCategory(trimmed, this.categoryType);
      }
      router.back();
    } catch (err) {
      const message = (err as Error).message;
      if (message.includes('already exists')) {
        this.errorMessage = '该分类名称已存在';
      } else if (message.includes('system')) {
        this.errorMessage = '系统分类不可编辑';
      } else {
        this.errorMessage = '保存失败，请重试';
      }
      this.saving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor('#333333')
          .onClick(() => router.back())
        Text(this.getTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('保存')
          .fontSize(16)
          .fontColor(this.saving ? '#AAAAAA' : '#1565C0')
          .onClick(() => {
            if (!this.saving) {
              this.save();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Column({ space: 8 }) {
        Text('类型')
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
        Text(this.categoryType === 'expense' ? '支出' : '收入')
          .fontSize(16)
          .fontColor('#333333')
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24 })

      Column({ space: 8 }) {
        Text('名称')
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
        TextInput({ text: this.nameText, placeholder: '请输入分类名称' })
          .onChange((value: string) => {
            this.nameText = value;
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20 })

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor('#C62828')
          .margin({ top: 16 })
          .padding({ left: 24, right: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
