export function startOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function endOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(23, 59, 59, 999);
  return date.getTime();
}

export function startOfMonth(timestamp: number): number {
  const date = new Date(timestamp);
  date.setDate(1);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function endOfMonth(timestamp: number): number {
  const date = new Date(timestamp);
  date.setMonth(date.getMonth() + 1, 0);
  date.setHours(23, 59, 59, 999);
  return date.getTime();
}

export function startOfYear(timestamp: number): number {
  const date = new Date(timestamp);
  date.setMonth(0, 1);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function endOfYear(timestamp: number): number {
  const date = new Date(timestamp);
  date.setMonth(11, 31);
  date.setHours(23, 59, 59, 999);
  return date.getTime();
}

export type PeriodType = 'day' | 'month' | 'year';

export const PERIOD_PICKER_START_YEAR = 2020;
export const PERIOD_PICKER_END_YEAR = 2035;

export function getPeriodPickerTitle(type: PeriodType): string {
  if (type === 'year') {
    return '选择年份';
  }
  if (type === 'month') {
    return '选择年月';
  }
  return '选择日期';
}

export function buildYearPickerLabels(): string[] {
  const labels: string[] = [];
  for (let year = PERIOD_PICKER_START_YEAR; year <= PERIOD_PICKER_END_YEAR; year++) {
    labels.push(`${year}年`);
  }
  return labels;
}

export function yearToPickerIndex(year: number): number {
  const clamped = Math.min(PERIOD_PICKER_END_YEAR, Math.max(PERIOD_PICKER_START_YEAR, year));
  return clamped - PERIOD_PICKER_START_YEAR;
}

export function pickerIndexToYear(index: number): number {
  return PERIOD_PICKER_START_YEAR + index;
}

/** 按统计周期维度归一化 DatePicker / TextPicker 选中的日期 */
export function applyPeriodPickerDate(periodType: PeriodType, picked: Date, prev: Date): Date {
  if (periodType === 'day') {
    return applyPickerDateOnly(picked, prev);
  }
  if (periodType === 'month') {
    const year = picked.getFullYear();
    const month = picked.getMonth() + 1;
    const day = clampDayToMonth(year, month, prev.getDate());
    return new Date(year, month - 1, day, 0, 0, 0, 0);
  }
  const year = picked.getFullYear();
  return new Date(year, 0, 1, 0, 0, 0, 0);
}

export function applyYearPickerIndex(prev: Date, index: number): Date {
  const year = pickerIndexToYear(index);
  return new Date(year, 0, 1, 0, 0, 0, 0);
}

/** 按统计周期维度归一化「当前」日期锚点（日/月/年选择器「回到当前」） */
export function getCurrentPeriodAnchor(periodType: PeriodType): Date {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  const day = now.getDate();
  if (periodType === 'day' || periodType === 'month') {
    return new Date(year, month - 1, day, 0, 0, 0, 0);
  }
  return new Date(year, 0, 1, 0, 0, 0, 0);
}

export interface PeriodRange {
  startAt: number;
  endAt: number;
}

export function getPeriodRange(type: PeriodType, anchor: Date): PeriodRange {
  const ts = anchor.getTime();
  if (type === 'day') {
    return { startAt: startOfDay(ts), endAt: endOfDay(ts) };
  }
  if (type === 'month') {
    return { startAt: startOfMonth(ts), endAt: endOfMonth(ts) };
  }
  return { startAt: startOfYear(ts), endAt: endOfYear(ts) };
}

export function formatPeriodLabel(type: PeriodType, anchor: Date): string {
  const year = anchor.getFullYear();
  const month = anchor.getMonth() + 1;
  const day = anchor.getDate();
  if (type === 'day') {
    const today = new Date();
    if (isSameDay(anchor, today)) {
      return '今天';
    }
    const yesterday = new Date();
    yesterday.setDate(today.getDate() - 1);
    if (isSameDay(anchor, yesterday)) {
      return '昨天';
    }
    return `${year}年${month}月${day}日`;
  }
  if (type === 'month') {
    return `${year}年${month}月`;
  }
  return `${year}年`;
}

export function shiftPeriod(type: PeriodType, anchor: Date, delta: number): Date {
  const next = new Date(anchor.getTime());
  if (type === 'day') {
    next.setDate(next.getDate() + delta);
    return next;
  }
  if (type === 'month') {
    next.setMonth(next.getMonth() + delta);
    return next;
  }
  next.setFullYear(next.getFullYear() + delta);
  return next;
}

export function formatMonthLabel(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}年${date.getMonth() + 1}月`;
}

export function formatMonthKey(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}`;
}

export function formatDateLabel(timestamp: number): string {
  const date = new Date(timestamp);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);

  if (isSameDay(date, today)) {
    return '今天';
  }
  if (isSameDay(date, yesterday)) {
    return '昨天';
  }
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${month}月${day}日`;
}

export function formatDateKey(timestamp: number): string {
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = pad2(date.getMonth() + 1);
  const day = pad2(date.getDate());
  return `${year}-${month}-${day}`;
}

export function formatDateTime(timestamp: number): string {
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = pad2(date.getMonth() + 1);
  const day = pad2(date.getDate());
  const hour = pad2(date.getHours());
  const minute = pad2(date.getMinutes());
  const second = pad2(date.getSeconds());
  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
}

/** 格式化为 HH:mm，用于流水列表展示发生时间 */
export function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

/** 格式化为 M月d日 HH:mm，用于年维度流水列表展示发生时间 */
export function formatMonthDayTime(timestamp: number): string {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${month}月${day}日 ${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

/** 按统计周期维度格式化流水列表发生时间：年维度含月日，日/月维度仅时分 */
export function formatTransactionListTime(timestamp: number, periodType: PeriodType): string {
  if (periodType === 'year') {
    return formatMonthDayTime(timestamp);
  }
  return formatTime(timestamp);
}

/**
 * 解析常见账单日期时间字符串，保留时分秒。
 * 支持：yyyy-MM-dd HH:mm:ss、yyyy/MM/dd HH:mm、yyyy年MM月dd日 HH:mm:ss 等。
 * 解析失败返回 0。
 */
export function parseDateTimeString(raw: string): number {
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return 0;
  }
  const normalized = trimmed
    .replace(/年/g, '-')
    .replace(/月/g, '-')
    .replace(/日/g, ' ')
    .replace(/\//g, '-')
    .replace(/\./g, '-')
    .replace(/\s+/g, ' ')
    .trim();
  const match = normalized.match(
    /^(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?/
  );
  if (match) {
    const year = Number.parseInt(match[1]);
    const month = Number.parseInt(match[2]) - 1;
    const day = Number.parseInt(match[3]);
    const hour = match[4] !== undefined ? Number.parseInt(match[4]) : 0;
    const minute = match[5] !== undefined ? Number.parseInt(match[5]) : 0;
    const second = match[6] !== undefined ? Number.parseInt(match[6]) : 0;
    const date = new Date(year, month, day, hour, minute, second);
    if (!Number.isNaN(date.getTime())) {
      return date.getTime();
    }
  }
  const fallback = new Date(normalized);
  if (!Number.isNaN(fallback.getTime())) {
    return fallback.getTime();
  }
  return 0;
}

/** 解析日期时间，失败时使用当前时间 */
export function parseDateTimeOrNow(raw: string): number {
  const ts = parseDateTimeString(raw);
  return ts > 0 ? ts : Date.now();
}

/** Excel 序列日期（含小数时间）→ yyyy-MM-dd HH:mm:ss 字符串 */
export function formatExcelSerialDateTime(serial: number): string {
  const base = new Date(1899, 11, 30);
  const ms = base.getTime() + serial * 86400000;
  return formatDateTime(ms);
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function getDaysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

/** 将 day 限制在指定年月的有效范围内。month 为 1–12。 */
export function clampDayToMonth(year: number, month: number, day: number): number {
  const maxDay = getDaysInMonth(year, month);
  return day > maxDay ? maxDay : day;
}

function isDayBoundaryCross(
  prevYear: number, prevMonth: number, prevDay: number,
  nextYear: number, nextMonth: number, nextDay: number
): boolean {
  if (nextYear === prevYear && nextMonth === prevMonth) {
    return false;
  }
  const maxDay = getDaysInMonth(prevYear, prevMonth);
  if (prevDay === maxDay && nextDay === 1) {
    const expectedMonth = prevMonth === 12 ? 1 : prevMonth + 1;
    const expectedYear = prevMonth === 12 ? prevYear + 1 : prevYear;
    return nextMonth === expectedMonth && nextYear === expectedYear;
  }
  if (prevDay === 1) {
    const expectedMonth = prevMonth === 1 ? 12 : prevMonth - 1;
    const expectedYear = prevMonth === 1 ? prevYear - 1 : prevYear;
    const prevMonthMax = getDaysInMonth(expectedYear, expectedMonth);
    if (nextDay === prevMonthMax) {
      return nextMonth === expectedMonth && nextYear === expectedYear;
    }
  }
  return false;
}

function isMonthBoundaryCross(prevYear: number, prevMonth: number, nextYear: number, nextMonth: number): boolean {
  if (prevMonth === 12 && nextMonth === 1 && nextYear === prevYear + 1) {
    return true;
  }
  if (prevMonth === 1 && nextMonth === 12 && nextYear === prevYear - 1) {
    return true;
  }
  return nextYear === prevYear && Math.abs(nextMonth - prevMonth) === 1;
}

function isLikelyDayWheelChange(
  prevYear: number, prevMonth: number, prevDay: number,
  nextYear: number, nextMonth: number, nextDay: number
): boolean {
  if (nextYear === prevYear && nextMonth === prevMonth && nextDay !== prevDay) {
    return true;
  }
  return isDayBoundaryCross(prevYear, prevMonth, prevDay, nextYear, nextMonth, nextDay);
}

function isLikelyMonthWheelChange(
  prevYear: number, prevMonth: number, prevDay: number,
  nextYear: number, nextMonth: number, nextDay: number
): boolean {
  if (nextYear === prevYear && nextMonth === prevMonth) {
    return false;
  }
  if (isMonthBoundaryCross(prevYear, prevMonth, nextYear, nextMonth)) {
    return true;
  }
  if (nextYear === prevYear && nextMonth !== prevMonth && nextDay === prevDay) {
    return true;
  }
  if (nextYear === prevYear && nextMonth !== prevMonth &&
    nextDay === clampDayToMonth(prevYear, nextMonth, prevDay)) {
    return true;
  }
  return false;
}

/**
 * 根据 DatePicker 回调更新日期，避免年/月/日滚轮异常联动，并在换月/换年时钳位日。
 * preserveTime 为 true 时保留原有时分秒（用于记账时间选择）。
 */
export function applyDatePickerChange(prev: Date, value: DatePickerResult, preserveTime: boolean = false): Date {
  const prevYear = prev.getFullYear();
  const prevMonth = prev.getMonth() + 1;
  const prevDay = prev.getDate();
  const nextYear = value.year as number;
  const nextMonth = value.month as number;
  const nextDay = value.day as number;

  let year = prevYear;
  let month = prevMonth;
  let day = prevDay;

  const monthChanged = nextMonth !== prevMonth;
  const yearChanged = nextYear !== prevYear;
  const dayChanged = nextDay !== prevDay;

  if (isDayBoundaryCross(prevYear, prevMonth, prevDay, nextYear, nextMonth, nextDay)) {
    year = nextYear;
    month = nextMonth;
    day = nextDay;
  } else if (isLikelyMonthWheelChange(prevYear, prevMonth, prevDay, nextYear, nextMonth, nextDay) &&
    !isLikelyDayWheelChange(prevYear, prevMonth, prevDay, nextYear, nextMonth, nextDay)) {
    year = nextYear;
    month = nextMonth;
    day = clampDayToMonth(year, month, prevDay);
  } else if (yearChanged &&
    (nextMonth === prevMonth || prevDay > getDaysInMonth(nextYear, prevMonth))) {
    year = nextYear;
    day = clampDayToMonth(year, month, prevDay);
  } else if (yearChanged && !monthChanged && !dayChanged) {
    year = nextYear;
    day = clampDayToMonth(year, month, prevDay);
  } else if (monthChanged && !dayChanged) {
    month = nextMonth;
    day = clampDayToMonth(year, month, prevDay);
  } else if (dayChanged && !monthChanged && !yearChanged) {
    day = nextDay;
  } else if (dayChanged && Math.abs(nextDay - prevDay) <= 1) {
    day = nextDay;
  } else if (monthChanged) {
    year = nextYear;
    month = nextMonth;
    day = clampDayToMonth(year, month, prevDay);
  } else if (yearChanged) {
    year = nextYear;
    day = clampDayToMonth(year, month, prevDay);
  } else {
    year = nextYear;
    month = nextMonth;
    day = clampDayToMonth(year, month, nextDay);
  }

  const hours = preserveTime ? prev.getHours() : 0;
  const minutes = preserveTime ? prev.getMinutes() : 0;
  const seconds = preserveTime ? prev.getSeconds() : 0;
  const ms = preserveTime ? prev.getMilliseconds() : 0;
  return new Date(year, month - 1, day, hours, minutes, seconds, ms);
}

/** 当月 1 号是星期几，0=周日 */
export function getFirstWeekdayOfMonth(year: number, month: number): number {
  return new Date(year, month - 1, 1).getDay();
}

export function dateFromParts(year: number, month: number, day: number): Date {
  return new Date(year, month - 1, day);
}

/** DatePicker onDateChange：结合 prev 智能更新年月日，避免滚轮联动并在换月/换年时钳位日 */
export function applyPickerDateOnly(picked: Date, prev: Date): Date {
  return applyDatePickerChange(prev, {
    year: picked.getFullYear(),
    month: picked.getMonth() + 1,
    day: picked.getDate()
  }, false);
}

/** DatePicker onDateChange：结合 prev 更新年月日，保留时分秒 */
export function applyPickerDateKeepTime(picked: Date, prev: Date): Date {
  return applyDatePickerChange(prev, {
    year: picked.getFullYear(),
    month: picked.getMonth() + 1,
    day: picked.getDate()
  }, true);
}
