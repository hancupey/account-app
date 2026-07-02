import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

/** 相册截图删除（仅删除已成功保存的源图；需 system_basic 级 WRITE_IMAGEVIDEO，未声明时静默失败） */
export class ScreenshotImageService {
  static async deleteImages(context: common.Context, uris: string[]): Promise<number> {
    if (uris.length === 0) {
      return 0;
    }
    try {
      await photoAccessHelper.MediaAssetChangeRequest.deleteAssets(context, uris);
      return uris.length;
    } catch (_err) {
      // WRITE_IMAGEVIDEO 为 system_basic 权限，普通应用无法声明；删除失败不影响入账
      return 0;
    }
  }
}
