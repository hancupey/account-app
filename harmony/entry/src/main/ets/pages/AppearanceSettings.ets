import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { ThemePreference, ThemeService } from '../services/ThemeService';

@Entry
@Component
struct AppearanceSettings {
  @State themePreference: ThemePreference = 'follow_system';

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    ThemeService.getInstance().ensureReady(context);
    this.themePreference = ThemeService.getInstance().getPreference();
  }

  private switchTheme(preference: ThemePreference): void {
    if (this.themePreference === preference) {
      return;
    }
    this.themePreference = preference;
    const context = getContext(this) as common.UIAbilityContext;
    ThemeService.getInstance().setPreference(context, preference);
  }

  @Builder
  ThemeSelector() {
    Row({ space: 8 }) {
      Button($r('app.string.theme_follow_system'))
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.themePreference === 'follow_system' ?
          $r('app.color.brand_primary') : $r('app.color.button_inactive_bg'))
        .fontColor(this.themePreference === 'follow_system' ?
          $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.switchTheme('follow_system');
        })
      Button($r('app.string.theme_light'))
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.themePreference === 'light' ?
          $r('app.color.brand_primary') : $r('app.color.button_inactive_bg'))
        .fontColor(this.themePreference === 'light' ?
          $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.switchTheme('light');
        })
      Button($r('app.string.theme_dark'))
        .layoutWeight(1)
        .height(38)
        .fontSize(14)
        .backgroundColor(this.themePreference === 'dark' ?
          $r('app.color.brand_primary') : $r('app.color.button_inactive_bg'))
        .fontColor(this.themePreference === 'dark' ?
          $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
        .onClick(() => {
          this.switchTheme('dark');
        })
    }
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text($r('app.string.appearance_section'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank()
          .width(22)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Column({ space: 12 }) {
        Text($r('app.string.theme_switch_title'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text($r('app.string.theme_section_desc'))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        this.ThemeSelector()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
