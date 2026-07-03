import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'ThemeService';
const PREFERENCES_NAME = 'app_settings';
const THEME_KEY = 'theme_preference';

export type ThemePreference = 'follow_system' | 'light' | 'dark';

export class ThemeService {
  private static instance: ThemeService;
  private dataPreferences: preferences.Preferences | null = null;
  private currentPreference: ThemePreference = 'follow_system';

  static getInstance(): ThemeService {
    if (!ThemeService.instance) {
      ThemeService.instance = new ThemeService();
    }
    return ThemeService.instance;
  }

  initOnStartup(context: common.Context): void {
    try {
      const options: preferences.Options = { name: PREFERENCES_NAME };
      this.dataPreferences = preferences.getPreferencesSync(context, options);
      const saved = this.dataPreferences.getSync(THEME_KEY, 'follow_system') as string;
      if (saved === 'light' || saved === 'dark' || saved === 'follow_system') {
        this.currentPreference = saved;
      }
      this.applyColorMode(context, this.currentPreference);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init theme. Cause: %{public}s', JSON.stringify(err));
      this.applyColorMode(context, 'follow_system');
    }
  }

  ensureReady(context: common.Context): void {
    if (this.dataPreferences !== null) {
      return;
    }
    this.initOnStartup(context);
  }

  getPreference(): ThemePreference {
    return this.currentPreference;
  }

  setPreference(context: common.Context, preference: ThemePreference): void {
    this.currentPreference = preference;
    try {
      if (this.dataPreferences === null) {
        this.ensureReady(context);
      }
      if (this.dataPreferences !== null) {
        this.dataPreferences.putSync(THEME_KEY, preference);
        this.dataPreferences.flushSync();
      }
      this.applyColorMode(context, preference);
      this.refreshWindowBackground(context);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to save theme. Cause: %{public}s', JSON.stringify(err));
    }
  }

  applyWindowBackground(context: common.Context, mainWindow: window.Window): void {
    try {
      const colorValue = context.resourceManager.getColorSync($r('app.color.page_background').id);
      mainWindow.setWindowBackgroundColor('#' + colorValue.toString(16).padStart(8, '0'));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set window background. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private refreshWindowBackground(context: common.Context): void {
    const uiContext = context as common.UIAbilityContext;
    window.getLastWindow(uiContext).then((mainWindow: window.Window) => {
      this.applyWindowBackground(context, mainWindow);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window. Cause: %{public}s', JSON.stringify(err));
    });
  }

  private applyColorMode(context: common.Context, preference: ThemePreference): void {
    let mode: ConfigurationConstant.ColorMode;
    switch (preference) {
      case 'light':
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
        break;
      case 'dark':
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        break;
      default:
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
        break;
    }
    try {
      context.getApplicationContext().setColorMode(mode);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }
}
