import { common } from '@kit.AbilityKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ParsedTransaction, PaymentPlatform } from '../../models/ParsedTransaction';
import { AlipayScreenshotParser } from './AlipayScreenshotParser';
import { ScreenshotImageService } from './ScreenshotImageService';
import { WechatScreenshotParser } from './WechatScreenshotParser';

export class OcrService {
  static readonly MAX_SCREENSHOT_COUNT: number = 9;

  /** 从相册选择一张图片 */
  static async pickImage(): Promise<string> {
    const uris = await OcrService.pickImages(1);
    if (uris.length === 0) {
      return '';
    }
    return uris[0];
  }

  /** 从相册选择多张图片（最多 9 张） */
  static async pickImages(maxCount: number = OcrService.MAX_SCREENSHOT_COUNT): Promise<string[]> {
    const limit = Math.min(Math.max(maxCount, 1), OcrService.MAX_SCREENSHOT_COUNT);
    const photoPicker = new picker.PhotoViewPicker();
    const result = await photoPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: limit
    });
    return result.photoUris;
  }

  /** 按 URI 删除已入账的源截图（需 system_basic 级 WRITE_IMAGEVIDEO，未配置时返回 0） */
  static async deleteSourceImages(context: common.Context, uris: string[]): Promise<number> {
    return ScreenshotImageService.deleteImages(context, uris);
  }

  /** 将 URI 转为 PixelMap 并执行 OCR，返回识别文本 */
  static async recognizeFromUri(uri: string): Promise<string> {
    let file: fileIo.File | null = null;
    let imageSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(file.fd);
      pixelMap = await imageSource.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const config: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: true
      };
      const text = await OcrService.runRecognize(visionInfo, config);
      return text;
    } finally {
      if (pixelMap !== null) {
        pixelMap.release();
      }
      if (imageSource !== null) {
        imageSource.release();
      }
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  /** 自动检测平台并解析 OCR 文本 */
  static parseOcrText(ocrText: string, platform: PaymentPlatform): ParsedTransaction {
    if (platform === 'wechat') {
      return WechatScreenshotParser.parse(ocrText);
    }
    if (platform === 'alipay') {
      return AlipayScreenshotParser.parse(ocrText);
    }
    const wechatScore = WechatScreenshotParser.detectPlatform(ocrText) === 'wechat' ? 1 : 0;
    const alipayScore = AlipayScreenshotParser.detectPlatform(ocrText) === 'alipay' ? 1 : 0;
    if (alipayScore > wechatScore) {
      return AlipayScreenshotParser.parse(ocrText);
    }
    return WechatScreenshotParser.parse(ocrText);
  }

  static detectPlatform(ocrText: string): PaymentPlatform {
    const isWechat = WechatScreenshotParser.detectPlatform(ocrText) === 'wechat';
    const isAlipay = AlipayScreenshotParser.detectPlatform(ocrText) === 'alipay';
    if (isWechat && !isAlipay) {
      return 'wechat';
    }
    if (isAlipay && !isWechat) {
      return 'alipay';
    }
    if (isWechat && isAlipay) {
      if (/支付宝/.test(ocrText)) {
        return 'alipay';
      }
      return 'wechat';
    }
    return 'unknown';
  }

  private static runRecognize(
    visionInfo: textRecognition.VisionInfo,
    config: textRecognition.TextRecognitionConfiguration
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      textRecognition.recognizeText(visionInfo, config, (error: BusinessError, data: textRecognition.TextRecognitionResult) => {
        if (error && error.code !== 0) {
          reject(error);
          return;
        }
        resolve(data.value);
      });
    });
  }

  static isOcrError(error: BusinessError): boolean {
    return error.code !== 0;
  }
}
