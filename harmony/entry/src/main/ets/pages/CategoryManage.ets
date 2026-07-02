import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { Category, CategoryType } from '../models/Category';
import { CategorySortOrder } from '../models/CategorySortOrder';
import { TransactionService } from '../services/TransactionService';

@Entry
@Component
struct CategoryManage {
  @State categoryType: CategoryType = 'expense';
  @State categories: Category[] = [];
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.ensureReady();
  }

  onPageShow(): void {
    this.loadCategories();
  }

  private ensureReady(): void {
    const context = getContext(this) as common.UIAbilityContext;
    TransactionService.getInstance().init(context).then(() => {
      this.loadCategories();
    });
  }

  private loadCategories(): void {
    this.loading = true;
    TransactionService.getInstance().getCategories(this.categoryType)
      .then((list: Category[]) => {
        this.categories = list;
        this.loading = false;
      })
      .catch(() => {
        this.loading = false;
      });
  }

  private switchType(type: CategoryType): void {
    if (this.categoryType === type) {
      return;
    }
    this.categoryType = type;
    this.loadCategories();
  }

  private openAdd(): void {
    router.pushUrl({
      url: 'pages/AddCategory',
      params: {
        mode: 'add',
        categoryType: this.categoryType
      }
    });
  }

  private openEdit(category: Category): void {
    if (category.isSystem) {
      return;
    }
    router.pushUrl({
      url: 'pages/AddCategory',
      params: {
        mode: 'edit',
        categoryId: category.id,
        categoryName: category.name,
        categoryType: category.type
      }
    });
  }

  private confirmDelete(category: Category): void {
    if (category.isSystem) {
      promptAction.showToast({ message: '系统分类不可删除' });
      return;
    }
    AlertDialog.show({
      title: '确认删除',
      message: `确定删除分类「${category.name}」吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#C62828',
        action: () => {
          this.deleteCategory(category.id);
        }
      }
    });
  }

  private deleteCategory(id: number): void {
    TransactionService.getInstance().deleteCategory(id)
      .then(() => {
        promptAction.showToast({ message: '已删除' });
        this.loadCategories();
      })
      .catch((err: Error) => {
        const message = err.message.includes('system') ? '系统分类不可删除' : '删除失败';
        promptAction.showToast({ message: message });
      });
  }

  private applyCategoryMove(from: number, to: number): void {
    if (from === to || from < 0 || to < 0 ||
      from >= this.categories.length || to >= this.categories.length) {
      return;
    }
    const list = this.categories.slice();
    const moved = list.splice(from, 1)[0];
    list.splice(to, 0, moved);

    const updates: CategorySortOrder[] = [];
    for (let i = 0; i < list.length; i++) {
      list[i].sortOrder = i + 1;
      const item = new CategorySortOrder();
      item.id = list[i].id;
      item.sortOrder = i + 1;
      updates.push(item);
    }
    this.categories = list;
    this.persistSortOrders(updates);
  }

  private persistSortOrders(updates: CategorySortOrder[]): void {
    TransactionService.getInstance().updateCategorySortOrders(updates)
      .catch(() => {
        promptAction.showToast({ message: '排序保存失败' });
        this.loadCategories();
      });
  }

  @Builder
  DragHandle() {
    SymbolGlyph($r('sys.symbol.line_3_horizontal'))
      .fontSize(22)
      .fontColor(['#1565C0'])
      .opacity(0.55)
      .width(32)
      .height(32)
  }

  @Builder
  CategoryRow(category: Category) {
    Row() {
      Column({ space: 4 }) {
        Text(category.name)
          .fontSize(16)
          .fontColor('#333333')
        Text(category.isSystem ? '系统默认' : '自定义')
          .fontSize(12)
          .fontColor(category.isSystem ? '#888888' : '#1565C0')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (!category.isSystem) {
        Text('编辑')
          .fontSize(14)
          .fontColor('#1565C0')
          .margin({ right: 16 })
          .onClick(() => {
            this.openEdit(category);
          })
        Text('删除')
          .fontSize(14)
          .fontColor('#C62828')
          .margin({ right: 12 })
          .onClick(() => {
            this.confirmDelete(category);
          })
      }

      this.DragHandle()
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor('#333333')
          .onClick(() => router.back())
        Text('分类管理')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('添加')
          .fontSize(16)
          .fontColor('#1565C0')
          .onClick(() => this.openAdd())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Row({ space: 12 }) {
        Button('支出')
          .layoutWeight(1)
          .height(40)
          .fontSize(16)
          .backgroundColor(this.categoryType === 'expense' ? '#C62828' : '#EEEEEE')
          .fontColor(this.categoryType === 'expense' ? '#FFFFFF' : '#666666')
          .onClick(() => this.switchType('expense'))

        Button('收入')
          .layoutWeight(1)
          .height(40)
          .fontSize(16)
          .backgroundColor(this.categoryType === 'income' ? '#2E7D32' : '#EEEEEE')
          .fontColor(this.categoryType === 'income' ? '#FFFFFF' : '#666666')
          .onClick(() => this.switchType('income'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (this.loading) {
        Column() {
          Text('加载中...')
            .fontSize(16)
            .fontColor('#888888')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.categories.length === 0) {
        Column() {
          Text('暂无分类')
            .fontSize(16)
            .fontColor('#888888')
          Button('添加分类')
            .margin({ top: 16 })
            .onClick(() => this.openAdd())
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Text('长按并拖动右侧手柄调整顺序')
          .fontSize(13)
          .fontColor('#888888')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })

        List() {
          ForEach(this.categories, (category: Category) => {
            ListItem() {
              this.CategoryRow(category)
            }
          }, (category: Category) => `${category.id}`)
            .onMove((from: number, to: number) => {
              this.applyCategoryMove(from, to);
            })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .divider({ strokeWidth: 1, color: '#EEEEEE' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
