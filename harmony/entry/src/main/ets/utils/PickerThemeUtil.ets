export class PickerThemeUtil {
  static disappearStyle(): PickerTextStyle {
    return {
      color: $r('app.color.text_tertiary'),
      font: { size: '14fp', weight: FontWeight.Regular }
    };
  }

  static textStyle(): PickerTextStyle {
    return {
      color: $r('app.color.text_secondary'),
      font: { size: '16fp', weight: FontWeight.Regular }
    };
  }

  static selectedStyle(): PickerTextStyle {
    return {
      color: $r('app.color.text_primary'),
      font: { size: '20fp', weight: FontWeight.Medium }
    };
  }
}
