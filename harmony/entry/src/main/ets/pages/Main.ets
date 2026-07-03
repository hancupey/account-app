import { Index } from './Index';
import { SettingsContent } from './Settings';

@Entry
@Component
struct Main {
  @State currentTabIndex: number = 0;
  @State indexRefreshToken: number = 0;

  onPageShow(): void {
    this.indexRefreshToken++;
  }

  @Builder
  LedgerTabBar() {
    Column() {
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize(24)
        .fontColor([this.currentTabIndex === 0 ? $r('app.color.brand_primary') : $r('app.color.text_hint')])
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SettingsTabBar() {
    Column() {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(24)
        .fontColor([this.currentTabIndex === 1 ? $r('app.color.brand_primary') : $r('app.color.text_hint')])
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
      TabContent() {
        Index({ refreshToken: this.indexRefreshToken })
      }
      .tabBar(this.LedgerTabBar())

      TabContent() {
        SettingsContent()
      }
      .tabBar(this.SettingsTabBar())
    }
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .barHeight(56)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
