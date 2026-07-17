"""
docx_to_plfpdf
==============

Reads a .docx file and emits an Oracle PL/SQL anonymous block that uses the
PL_FPDF package to reproduce the document as a PDF.

Usage:
    python docx_to_plfpdf.py input.docx -o output.sql
    python docx_to_plfpdf.py input.docx           # writes to stdout

Mapping (DOCX -> PL_FPDF):
    Heading 1..6   -> SetFont('Arial','B', size); Cell + Ln
    Paragraph      -> MultiCell, run-level bold/italic via SetFont
    Bullet list    -> '- ' prefix + MultiCell
    Numbered list  -> 'N. ' prefix + MultiCell
    Table          -> Cell() grid, one row per docx row
    Inline image   -> Image() loaded from a temp BLOB (base64 inline)
    Page break     -> AddPage()

Requires: python-docx (`pip install python-docx`).
"""

from __future__ import annotations

import argparse
import base64
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from docx import Document
from docx.document import Document as _DocxDoc
from docx.oxml.ns import qn
from docx.table import Table as DocxTable
from docx.text.paragraph import Paragraph as DocxPara


# ---------------------------------------------------------------------------
# Intermediate representation
# ---------------------------------------------------------------------------

@dataclass
class Run:
    text: str
    bold: bool = False
    italic: bool = False


@dataclass
class Heading:
    level: int
    text: str


@dataclass
class Paragraph:
    runs: list[Run] = field(default_factory=list)
    list_prefix: str | None = None  # "- " or "1. " etc.


@dataclass
class Image:
    data: bytes
    ext: str  # "png", "jpg"


@dataclass
class Table:
    rows: list[list[str]]


@dataclass
class PageBreak:
    pass


Block = Heading | Paragraph | Image | Table | PageBreak


# ---------------------------------------------------------------------------
# DOCX -> IR
# ---------------------------------------------------------------------------

HEADING_SIZES = {1: 20, 2: 16, 3: 14, 4: 12, 5: 11, 6: 10}


def _iter_block_items(parent: _DocxDoc) -> Iterable:
    """Yield paragraphs and tables in document order."""
    body = parent.element.body
    for child in body.iterchildren():
        if child.tag == qn("w:p"):
            yield DocxPara(child, parent)
        elif child.tag == qn("w:tbl"):
            yield DocxTable(child, parent)


def _para_has_pagebreak(p: DocxPara) -> bool:
    for br in p._element.iter(qn("w:br")):
        if br.get(qn("w:type")) == "page":
            return True
    return False


def _extract_images(p: DocxPara, doc: _DocxDoc) -> list[Image]:
    out: list[Image] = []
    for blip in p._element.iter(qn("a:blip")):
        rid = blip.get(qn("r:embed"))
        if not rid:
            continue
        part = doc.part.related_parts.get(rid)
        if part is None:
            continue
        ext = (part.partname.ext or ".png").lstrip(".").lower()
        if ext == "jpeg":
            ext = "jpg"
        out.append(Image(data=part.blob, ext=ext))
    return out


def _list_prefix(p: DocxPara, counters: dict[int, int]) -> str | None:
    pPr = p._element.find(qn("w:pPr"))
    if pPr is None:
        return None
    numPr = pPr.find(qn("w:numPr"))
    if numPr is None:
        return None
    ilvl_el = numPr.find(qn("w:ilvl"))
    ilvl = int(ilvl_el.get(qn("w:val"))) if ilvl_el is not None else 0
    style = (p.style.name or "").lower() if p.style else ""
    # Heuristic: docx doesn't expose numbering text easily without resolving
    # numbering.xml. Use style name + counter as a best-effort.
    indent = "  " * ilvl
    if "number" in style or "ordered" in style:
        counters[ilvl] = counters.get(ilvl, 0) + 1
        return f"{indent}{counters[ilvl]}. "
    counters.pop(ilvl, None)
    return f"{indent}- "


def parse_docx(path: Path) -> list[Block]:
    doc = Document(str(path))
    blocks: list[Block] = []
    counters: dict[int, int] = {}

    for item in _iter_block_items(doc):
        if isinstance(item, DocxTable):
            rows = [
                [cell.text.strip() for cell in row.cells]
                for row in item.rows
            ]
            if rows:
                blocks.append(Table(rows=rows))
            continue

        p = item
        style = (p.style.name or "") if p.style else ""

        if _para_has_pagebreak(p):
            blocks.append(PageBreak())

        imgs = _extract_images(p, doc)
        for img in imgs:
            blocks.append(img)

        text = p.text
        if style.startswith("Heading"):
            try:
                level = int(style.split()[-1])
            except ValueError:
                level = 1
            if text.strip():
                blocks.append(Heading(level=max(1, min(6, level)), text=text))
            continue

        if not text.strip() and not imgs:
            continue

        prefix = _list_prefix(p, counters)
        runs = [
            Run(
                text=r.text,
                bold=bool(r.bold),
                italic=bool(r.italic),
            )
            for r in p.runs
            if r.text
        ]
        if not runs and text:
            runs = [Run(text=text)]
        if runs:
            blocks.append(Paragraph(runs=runs, list_prefix=prefix))

    return blocks


# ---------------------------------------------------------------------------
# IR -> PL/SQL
# ---------------------------------------------------------------------------

PLSQL_PREAMBLE = """\
-- Generated by docx_to_plfpdf.py
-- Reproduces the source DOCX as a PDF using the PL_FPDF package.
DECLARE
  l_pdf BLOB;
  l_img BLOB;
  l_raw RAW(32767);

  PROCEDURE load_b64(p_b64 IN CLOB, p_blob OUT BLOB) IS
    l_dest_offset   INTEGER := 1;
    l_src_offset    INTEGER := 1;
    l_lang_ctx      INTEGER := DBMS_LOB.default_lang_ctx;
    l_warning       INTEGER;
  BEGIN
    DBMS_LOB.createtemporary(p_blob, TRUE);
    DBMS_LOB.converttoblob(
      dest_lob     => p_blob,
      src_clob     => p_b64,
      amount       => DBMS_LOB.lobmaxsize,
      dest_offset  => l_dest_offset,
      src_offset   => l_src_offset,
      blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
      lang_context => l_lang_ctx,
      warning      => l_warning
    );
    -- decode base64
    DECLARE
      l_decoded BLOB;
      l_chunk   VARCHAR2(32767);
      l_pos     INTEGER := 1;
      l_len     INTEGER := DBMS_LOB.getlength(p_blob);
      l_step    INTEGER := 24000;
    BEGIN
      DBMS_LOB.createtemporary(l_decoded, TRUE);
      WHILE l_pos <= l_len LOOP
        l_chunk := UTL_RAW.cast_to_varchar2(
                     DBMS_LOB.substr(p_blob, LEAST(l_step, l_len - l_pos + 1), l_pos));
        DBMS_LOB.append(l_decoded, UTL_ENCODE.base64_decode(UTL_RAW.cast_to_raw(l_chunk)));
        l_pos := l_pos + l_step;
      END LOOP;
      DBMS_LOB.freetemporary(p_blob);
      p_blob := l_decoded;
    END;
  END load_b64;

BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetMargins(15, 15, 15);
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 11);
"""

PLSQL_EPILOGUE = """\
  l_pdf := PL_FPDF.Output_Blob();
  -- TODO: persist l_pdf (INSERT into your table, return via OUT param, etc.)
  DBMS_OUTPUT.put_line('PDF generated, bytes=' || DBMS_LOB.getlength(l_pdf));
END;
/
"""


def _q(s: str) -> str:
    """Quote a Python string as a PL/SQL VARCHAR2 literal (q-quoted)."""
    s = s.replace("\r", "")
    # PL/SQL q-quote: open/close are paired brackets when available.
    for opener, closer in (("[", "]"), ("{", "}"), ("<", ">"), ("(", ")")):
        if closer not in s:
            return f"q'{opener}{s}{closer}'"
    for delim in ("!", "#", "~", "|", "^"):
        if delim not in s:
            return f"q'{delim}{s}{delim}'"
    return "'" + s.replace("'", "''") + "'"


def _emit_font(bold: bool, italic: bool, size: int) -> str:
    style = ("B" if bold else "") + ("I" if italic else "")
    return f"  PL_FPDF.SetFont('Arial', '{style}', {size});\n"


def _emit_paragraph(p: Paragraph) -> str:
    out = []
    # leading prefix (list marker) printed with default style
    if p.list_prefix:
        out.append(_emit_font(False, False, 11))
        out.append(f"  PL_FPDF.Write(6, {_q(p.list_prefix)});\n")
    for run in p.runs:
        if not run.text:
            continue
        out.append(_emit_font(run.bold, run.italic, 11))
        out.append(f"  PL_FPDF.Write(6, {_q(run.text)});\n")
    out.append("  PL_FPDF.Ln(8);\n")
    return "".join(out)


def _emit_heading(h: Heading) -> str:
    size = HEADING_SIZES.get(h.level, 11)
    return (
        "  PL_FPDF.Ln(4);\n"
        + _emit_font(True, False, size)
        + f"  PL_FPDF.Cell(0, {size * 0.6:.0f}, {_q(h.text)}, '0', 1, 'L');\n"
        + "  PL_FPDF.Ln(2);\n"
    )


def _emit_table(t: Table) -> str:
    if not t.rows:
        return ""
    out = ["  PL_FPDF.Ln(2);\n", _emit_font(False, False, 10)]
    cols = max(len(r) for r in t.rows)
    # available width 180mm (A4 minus margins) split evenly
    col_w = 180 / cols
    for r_idx, row in enumerate(t.rows):
        bold = r_idx == 0
        out.append(_emit_font(bold, False, 10))
        for c_idx in range(cols):
            cell = row[c_idx] if c_idx < len(row) else ""
            out.append(
                f"  PL_FPDF.Cell({col_w:.2f}, 7, {_q(cell)}, '1', 0, 'L');\n"
            )
        out.append("  PL_FPDF.Ln(7);\n")
    out.append("  PL_FPDF.Ln(2);\n")
    return "".join(out)


def _emit_image(img: Image, idx: int) -> str:
    b64 = base64.b64encode(img.data).decode("ascii")
    # chunk the base64 into 200-char pieces wrapped as a CLOB via concat.
    chunks = [b64[i : i + 200] for i in range(0, len(b64), 200)]
    parts = ["  DECLARE l_b64 CLOB; BEGIN\n", "    DBMS_LOB.createtemporary(l_b64, TRUE);\n"]
    for c in chunks:
        parts.append(f"    DBMS_LOB.append(l_b64, TO_CLOB('{c}'));\n")
    parts.append("    load_b64(l_b64, l_img);\n")
    parts.append(
        f"    PL_FPDF.Image(p_image_blob => l_img, p_x => NULL, p_y => NULL, "
        f"p_w => 80, p_h => 0, p_type => '{img.ext.upper()}');\n"
    )
    parts.append("    DBMS_LOB.freetemporary(l_img);\n")
    parts.append("    DBMS_LOB.freetemporary(l_b64);\n")
    parts.append("  END;\n")
    parts.append("  PL_FPDF.Ln(4);\n")
    return "".join(parts)


def emit_plsql(blocks: list[Block]) -> str:
    out: list[str] = [PLSQL_PREAMBLE]
    img_idx = 0
    for b in blocks:
        if isinstance(b, Heading):
            out.append(_emit_heading(b))
        elif isinstance(b, Paragraph):
            out.append(_emit_paragraph(b))
        elif isinstance(b, Table):
            out.append(_emit_table(b))
        elif isinstance(b, Image):
            out.append(_emit_image(b, img_idx))
            img_idx += 1
        elif isinstance(b, PageBreak):
            out.append("  PL_FPDF.AddPage();\n")
    out.append(PLSQL_EPILOGUE)
    return "".join(out)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Convert a .docx into a PL_FPDF PL/SQL block.")
    ap.add_argument("input", type=Path, help="Path to the .docx file.")
    ap.add_argument("-o", "--output", type=Path, help="Output .sql path (default: stdout).")
    args = ap.parse_args(argv)

    if not args.input.exists():
        print(f"error: {args.input} not found", file=sys.stderr)
        return 2

    blocks = parse_docx(args.input)
    sql = emit_plsql(blocks)

    if args.output:
        args.output.write_text(sql, encoding="utf-8")
        print(f"wrote {args.output} ({len(sql)} bytes, {len(blocks)} blocks)", file=sys.stderr)
    else:
        sys.stdout.write(sql)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
