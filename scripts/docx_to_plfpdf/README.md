# docx_to_plfpdf

Reads a `.docx` file and emits an Oracle PL/SQL anonymous block that uses the
`PL_FPDF` package to reproduce the document as a PDF.

## Install

```bash
pip install -r requirements.txt
```

## Usage

```bash
python docx_to_plfpdf.py input.docx -o output.sql
sqlplus user/pwd@db @output.sql
```

Without `-o` the generated PL/SQL is written to stdout.

## Mapping

| DOCX                  | PL_FPDF call                              |
|-----------------------|-------------------------------------------|
| Heading 1-6           | `SetFont('Arial','B', size)` + `Cell`     |
| Paragraph runs        | `SetFont` per run, then `Write`           |
| Bullet / numbered list| `Write` with `- ` / `N. ` prefix          |
| Table                 | `Cell` grid; first row bold               |
| Inline image          | `Image` from a temp BLOB (inline base64)  |
| Page break            | `AddPage`                                 |

## Limitations

- Fonts are mapped to Arial; per-run size is not honored (only headings).
- Numbered lists use a local counter — does not resolve `numbering.xml`.
- Tables use equal column widths.
- Complex layouts (text boxes, shapes, multi-column) are ignored.

## Next steps

- Honor explicit run font size / color.
- Detect cell merges and column widths from the docx grid.
- Optional: emit a stored procedure instead of an anonymous block.
