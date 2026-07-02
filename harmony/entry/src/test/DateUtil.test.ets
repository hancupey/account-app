import { describe, it, expect } from '@ohos/hypium';
import {
  applyPickerDateKeepTime,
  applyPickerDateOnly,
  clampDayToMonth,
  formatDateTime,
  formatMonthDayTime,
  formatTransactionListTime,
  parseDateTimeString
} from '../main/ets/utils/DateUtil';

export default function dateUtilTest() {
  describe('DateUtil picker helpers', () => {
    it('parseDateTimeString supports Chinese date format', 0, () => {
      const ts = parseDateTimeString('2026年6月28日 13:01:14');
      expect(formatDateTime(ts)).assertEqual('2026-06-28 13:01:14');
    });

    it('formatTransactionListTime shows month-day for year dimension', 0, () => {
      const ts = parseDateTimeString('2026-07-15 09:30:00');
      expect(formatMonthDayTime(ts)).assertEqual('7月15日 09:30');
      expect(formatTransactionListTime(ts, 'year')).assertEqual('7月15日 09:30');
      expect(formatTransactionListTime(ts, 'month')).assertEqual('09:30');
      expect(formatTransactionListTime(ts, 'day')).assertEqual('09:30');
    });

    it('clampDayToMonth limits day to month max', 0, () => {
      expect(clampDayToMonth(2024, 2, 31)).assertEqual(29);
      expect(clampDayToMonth(2025, 2, 31)).assertEqual(28);
      expect(clampDayToMonth(2024, 4, 31)).assertEqual(30);
    });

    it('applyPickerDateOnly keeps y/m/d at midnight', 0, () => {
      const prev = new Date(2024, 0, 15);
      const picked = new Date(2024, 1, 29);
      const result = applyPickerDateOnly(picked, prev);
      expect(result.getFullYear()).assertEqual(2024);
      expect(result.getMonth()).assertEqual(1);
      expect(result.getDate()).assertEqual(29);
      expect(result.getHours()).assertEqual(0);
    });

    it('applyPickerDateOnly clamps Mar 31 to Feb when month changes', 0, () => {
      const prev = new Date(2024, 2, 31);
      const picked = new Date(2024, 1, 29);
      const result = applyPickerDateOnly(picked, prev);
      expect(result.getFullYear()).assertEqual(2024);
      expect(result.getMonth()).assertEqual(1);
      expect(result.getDate()).assertEqual(29);
    });

    it('applyPickerDateOnly clamps Feb 29 to Feb 28 when year changes', 0, () => {
      const prev = new Date(2024, 1, 29);
      const picked = new Date(2025, 1, 28);
      const result = applyPickerDateOnly(picked, prev);
      expect(result.getFullYear()).assertEqual(2025);
      expect(result.getMonth()).assertEqual(1);
      expect(result.getDate()).assertEqual(28);
    });

    it('applyPickerDateOnly day scroll only changes day', 0, () => {
      const prev = new Date(2024, 2, 15);
      const picked = new Date(2024, 2, 16);
      const result = applyPickerDateOnly(picked, prev);
      expect(result.getMonth()).assertEqual(2);
      expect(result.getDate()).assertEqual(16);
    });

    it('applyPickerDateKeepTime preserves time-of-day', 0, () => {
      const prev = new Date(2024, 0, 15, 14, 30, 45);
      const picked = new Date(2024, 0, 16);
      const result = applyPickerDateKeepTime(picked, prev);
      expect(result.getFullYear()).assertEqual(2024);
      expect(result.getMonth()).assertEqual(0);
      expect(result.getDate()).assertEqual(16);
      expect(result.getHours()).assertEqual(14);
      expect(result.getMinutes()).assertEqual(30);
      expect(result.getSeconds()).assertEqual(45);
    });

    it('applyPickerDateKeepTime changes only year', 0, () => {
      const prev = new Date(2024, 2, 15, 9, 0, 0);
      const picked = new Date(2028, 2, 15);
      const result = applyPickerDateKeepTime(picked, prev);
      expect(result.getFullYear()).assertEqual(2028);
      expect(result.getMonth()).assertEqual(2);
      expect(result.getDate()).assertEqual(15);
      expect(result.getHours()).assertEqual(9);
    });
  });
}
