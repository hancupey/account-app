#!/usr/bin/env python3
"""Simulate HarmonyOS bill import parsing against real user files."""
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_USER = Path(
    r"d:\Program Files\Document\xwechat_files\wxid_y2h5tccvp25a22_8dcc\msg\file\2026-07\支付宝交易明细(20260601-20260701).csv"
)
CSV_SAMPLE = ROOT / "docs" / "samples" / "alipay_sample.csv"
XLSX_USER = Path(
    r"d:\Program Files\Document\xwechat_files\wxid_y2h5tccvp25a22_8dcc\msg\file\2026-07\微信支付账单流水文件(20260601-20260701)_20260701142826.xlsx"
)


def looks_like_utf8(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def contains_bill_header_markers(text: str) -> bool:
    marker = "\u4ea4\u6613\u65f6\u95f4"
    if marker not in text:
        return False
    return "\u6536/\u652f" in text or "\u91d1\u989d" in text


def count_cjk(text: str) -> int:
    return len(re.findall(r"[\u4e00-\u9fff]", text))


def read_text_content_fixed(raw: bytes) -> str:
    if len(raw) >= 3 and raw[0] == 0xEF and raw[1] == 0xBB and raw[2] == 0xBF:
        return raw.decode("utf-8-sig")
    utf8_text = raw.decode("utf-8", errors="replace")
    gb_text = raw.decode("gbk", errors="replace")
    utf8_has = contains_bill_header_markers(utf8_text)
    gb_has = contains_bill_header_markers(gb_text)
    if gb_has and not utf8_has:
        return gb_text
    if utf8_has and not gb_has:
        return utf8_text
    if count_cjk(gb_text) > count_cjk(utf8_text):
        return gb_text
    return utf8_text


def read_text_content_old(raw: bytes) -> str:
    utf8_text = raw.decode("utf-8", errors="replace")
    if re.search(r"[\u4e00-\u9fff]", utf8_text):
        return utf8_text
    return raw.decode("gbk", errors="replace")


def csv_parse(content: str) -> list[list[str]]:
    text = content.lstrip("\ufeff")
    rows: list[list[str]] = []
    row: list[str] = []
    field = ""
    in_quotes = False
    i = 0
    while i < len(text):
        ch = text[i]
        if in_quotes:
            if ch == '"':
                if i + 1 < len(text) and text[i + 1] == '"':
                    field += '"'
                    i += 1
                else:
                    in_quotes = False
            else:
                field += ch
        elif ch == '"':
            in_quotes = True
        elif ch == ",":
            row.append(field.strip())
            field = ""
        elif ch in "\n\r":
            if ch == "\r" and i + 1 < len(text) and text[i + 1] == "\n":
                i += 1
            row.append(field.strip())
            if any(cell for cell in row):
                rows.append(row)
            row = []
            field = ""
        else:
            field += ch
        i += 1
    row.append(field.strip())
    if any(cell for cell in row):
        rows.append(row)
    return rows


def find_header_row(rows: list[list[str]]) -> int:
    for i, r in enumerate(rows):
        joined = ",".join(r)
        if "交易时间" in joined:
            return i
    return -1


def alipay_find_header_row(rows: list[list[str]]) -> int:
    for i, r in enumerate(rows):
        joined = ",".join(r)
        if "交易时间" in joined and "收/支" in joined and "交易分类" in joined:
            return i
    for i, r in enumerate(rows):
        joined = ",".join(r)
        if "交易时间" in joined and "收/支" in joined:
            return i
    return -1


def wechat_find_header_row(rows: list[list[str]]) -> int:
    for i, r in enumerate(rows):
        joined = ",".join(r)
        if (
            "交易时间" in joined
            and ("收/支" in joined or "金额" in joined)
            and ("交易类型" in joined or "商品" in joined)
        ):
            return i
    return -1


def read_utf8_file_latin1(raw: bytes) -> str:
    return "".join(chr(b) for b in raw)


def parse_shared_strings(xml: str) -> list[str]:
    strings: list[str] = []
    search_from = 0
    while True:
        start = xml.find("<si", search_from)
        if start < 0:
            break
        end = xml.find("</si>", start)
        if end < 0:
            break
        block = xml[start:end]
        text = ""
        t_from = 0
        while True:
            t_start = block.find("<t", t_from)
            if t_start < 0:
                break
            content_start = block.find(">", t_start)
            content_end = block.find("</t>", content_start)
            if content_start < 0 or content_end < 0:
                break
            text += block[content_start + 1 : content_end]
            t_from = content_end + 4
        strings.append(text)
        search_from = end + 5
    return strings


def col_letters_to_index(letters: str) -> int:
    index = 0
    for ch in letters:
        index = index * 26 + (ord(ch) - 64)
    return index - 1


def parse_sheet_xml(xml: str, shared_strings: list[str]) -> list[list[str]]:
    sparse_rows: dict[int, dict[int, str]] = {}
    max_row = 0
    max_col = 0
    search_from = 0
    while True:
        row_start = xml.find("<row", search_from)
        if row_start < 0:
            break
        row_end = xml.find("</row>", row_start)
        if row_end < 0:
            break
        row_block = xml[row_start:row_end]
        m = re.search(r'\br="(\d+)"', row_block)
        if not m:
            search_from = row_end + 6
            continue
        row_num = int(m.group(1))
        cells: dict[int, str] = {}
        cell_from = 0
        while True:
            cell_start = row_block.find("<c ", cell_from)
            if cell_start < 0:
                break
            cell_end = row_block.find("</c>", cell_start)
            self_close = row_block.find("/>", cell_start)
            if cell_end >= 0 and (self_close < 0 or cell_end < self_close):
                cell_block = row_block[cell_start : cell_end + 4]
                next_from = cell_end + 4
            elif self_close >= 0:
                cell_block = row_block[cell_start : self_close + 2]
                next_from = self_close + 2
            else:
                break
            ref = re.search(r'\br="([A-Z]+)(\d+)"', cell_block)
            type_m = re.search(r'\bt="([^"]+)"', cell_block)
            value_m = re.search(r"<v>([\s\S]*?)</v>", cell_block)
            if ref and value_m:
                col_index = col_letters_to_index(ref.group(1))
                raw_value = value_m.group(1).strip()
                cell_type = type_m.group(1) if type_m else ""
                if cell_type == "s":
                    idx = int(raw_value)
                    value = shared_strings[idx] if 0 <= idx < len(shared_strings) else ""
                else:
                    value = raw_value
                cells[col_index] = value
                max_col = max(max_col, col_index)
            cell_from = next_from
        sparse_rows[row_num] = cells
        max_row = max(max_row, row_num)
        search_from = row_end + 6

    rows: list[list[str]] = []
    for r in range(1, max_row + 1):
        row_cells = sparse_rows.get(r, {})
        row = [row_cells.get(c, "") for c in range(max_col + 1)]
        if any(cell for cell in row):
            rows.append(row)
    return rows


def test_csv(path: Path, label: str) -> None:
    raw = path.read_bytes()
    print(f"\n=== CSV {label} ({path.name}) ===")
    print(f"size={len(raw)}, first bytes={raw[:8].hex()}")
    old = read_text_content_old(raw)
    fixed = read_text_content_fixed(raw)
    for name, text in [("old", old), ("fixed", fixed)]:
        rows = csv_parse(text)
        hi = find_header_row(rows)
        ahi = alipay_find_header_row(rows)
        print(f"[{name}] rows={len(rows)} header={hi} alipay_header={ahi}")
        if hi >= 0:
            print(f"[{name}] header cells: {rows[hi][:8]}")


def test_xlsx(path: Path) -> None:
    print(f"\n=== XLSX ({path.name}) ===")
    with zipfile.ZipFile(path) as z:
        ss_raw = z.read("xl/sharedStrings.xml")
        sheet_raw = z.read("xl/worksheets/sheet1.xml")

    for mode in ("utf8", "latin1"):
        if mode == "utf8":
            ss_xml = ss_raw.decode("utf-8")
            sheet_xml = sheet_raw.decode("utf-8")
        else:
            ss_xml = read_utf8_file_latin1(ss_raw)
            sheet_xml = read_utf8_file_latin1(sheet_raw)
        ss = parse_shared_strings(ss_xml)
        rows = parse_sheet_xml(sheet_xml, ss)
        hi = find_header_row(rows)
        whi = wechat_find_header_row(rows)
        print(f"[{mode}] sharedStrings={len(ss)}, rows={len(rows)}")
        print(f"[{mode}] has 交易时间 in shared strings: {any('交易时间' in s for s in ss)}")
        print(f"[{mode}] ImportService.findHeaderRow: {hi}")
        print(f"[{mode}] WechatFileParser.findHeaderRow: {whi}")
        if hi >= 0:
            print(f"[{mode}] header: {rows[hi]}")


def debug_csv_rows(path: Path, out_path: Path) -> None:
    text = read_text_content_fixed(path.read_bytes())
    rows = csv_parse(text)
    marker = "\u4ea4\u6613\u65f6\u95f4"  # 交易时间
    with out_path.open("w", encoding="utf-8") as f:
        f.write(f"rows={len(rows)}\n")
        for i, r in enumerate(rows):
            joined = ",".join(r)
            if marker in joined or "\u65f6\u95f4" in joined or 15 <= i <= 30:
                f.write(
                    f"row {i}: cols={len(r)} has_header={marker in joined}\n"
                    f"  cells={r[:12]}\n"
                    f"  joined={joined[:200]}\n\n"
                )


if __name__ == "__main__":
    debug_out = ROOT / "tools" / "csv_debug.txt"
    if CSV_USER.exists():
        test_csv(CSV_USER, "user")
        debug_csv_rows(CSV_USER, debug_out)
        print(f"debug written to {debug_out}")
    if CSV_SAMPLE.exists():
        test_csv(CSV_SAMPLE, "sample")
    if XLSX_USER.exists():
        test_xlsx(XLSX_USER)
