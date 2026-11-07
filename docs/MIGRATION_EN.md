# Migrating between versions — PL_FPDF

[**Português**](MIGRATION.md) · [Documentation index](README.md)

What changes for someone who **already uses** PL_FPDF, jump by jump, newest
first. To swap the packages in the database, see
[Installation → Upgrading](INSTALLATION_EN.md#7-upgrading).

In each jump, first what **no longer compiles** or **raises an error** (you find
out on the first run), then what **changes the result** with no error at all
(you only find out by looking at the PDF).

The public surface counts come from comparing each tag's `.pks`, name by name:

| | 0.9.4 | 2.0.0 | 3.0.0 | 3.2.0 | 3.3.0 | 3.4.0 |
|---|---|---|---|---|---|---|
| Public subprograms in `PL_FPDF` | 70 | 94 | 125 | 125 | 120 | 119 |

---

## 3.3 → 3.4

### No longer compiles, or raises an error

| Before | Now | What to do |
|--------|-----|------------|
| `SetUTF8Enabled`, `IsUTF8Enabled` | removed | delete the calls. They did nothing: the variable was written and read, and nothing else looked at it |
| A character outside WinAnsi in a standard font (ideogram, Cyrillic, emoji) came out as `?` or a wrong glyph | `ORA-20203`, with the position | embed a TrueType font (`AddTTFFont`), or handle the `PL_FPDF.exc_fora_de_winansi` exception |
| `AddLink`, `SetLink`, `Link` with a numeric target | `ORA-20601` (`PL_FPDF.exc_link_nao_suportado`) | use URL links only. Internal links never worked: the `/Dest` was not written and the file came out malformed |
| `LoadPDF` / `LoadPDFWithID` with an encrypted PDF were accepted, and the output had blank pages | `ORA-20867` | decrypt first with `DecryptPDF`, which needs the password |

### Changes the result

- **Accents in standard fonts.** Before, `ação` came out with two wrong glyphs
  for each accent; now it is right. If your code worked around that —
  converting the text before passing it, or stripping the accents — remove the
  workaround: 3.4.0 converts on its own, and text that was already converted
  comes out wrong again.
- **Widths with accents.** `GetStringWidth`, `MultiCell`, `Write` and right or
  centred alignment measured wrong (or raised `ORA-06502`) with accents. A
  layout hand-tuned to compensate may move.
- **TrueType fonts.** The registered font is now actually embedded and used by
  `SetFont`, with the file's metrics. Text changes shape and width: check the
  layouts that use TrueType.
- **PNG on an AL32UTF8 database.** `Image` refused every PNG with "Not a PNG
  file"; it works now.
- **Oracle 26ai.** 3.3.0 does not work on 26ai with AL32UTF8 — see
  [Compatibility](COMPATIBILITY_EN.md#1-oracle-versions). 3.4.0 does.

### New

`ImageFromBlob` — an image from a BLOB, with no network ACL.

---

## 3.2 → 3.3

### No longer compiles, or raises an error

| Before | Now | What to do |
|--------|-----|------------|
| `helloworld`, `test`, `testImg`, `testHeader`, `MyRepetitiveHeader`, `MyRepetitiveFooter`, `lpc_footer` | removed | they were the 2017 port's demos, public by accident. Code that called them was running the sample, not the library |
| Content that overflowed an internal buffer was truncated silently | `ORA-20841` / `ORA-20866` | the document was coming out incomplete; the error only made it visible |

### Changes the result

- **`Triangle`** now honours `porientation`, which used to be accepted and
  ignored: the triangle may point another way. It is the only incompatible
  behaviour change in the jump.

### Installation

The library now has **two** packages: `PL_FPDF_UTIL` (QR codes, barcodes,
compression, encryption) and `PL_FPDF`. The installer creates both, in the
right order. Callers in another schema still need only `EXECUTE` on `PL_FPDF`.

### New

One-file installation (`dist/pl_fpdf_install.sql`), reading PDF 1.5+
(cross-reference streams and object streams), `FlateDecode`/`FlateEncode` with
in-house DEFLATE, and the MIT license.

---

## 3.0 → 3.2 and 2.0 → 3.0

Additions only: no public subprogram left, no signature changed. 3.0 brought
manipulation of existing PDFs (`LoadPDF`, pages, watermarks, overlays, merge and
split) and encryption (`EncryptPDF`, `DecryptPDF`, `SetEncryption`); the details
are in the [CHANGELOG](../CHANGELOG.md).

---

## 0.9.4 → 2.0

The jump from the original 2017 port to the modernization.

```sql
-- BEFORE (v0.9.4)                   -- NOW (v2.0+)
PL_FPDF.fpdf('P','mm','A4');         PL_FPDF.Init('P','mm','A4');
l_pdf := PL_FPDF.Output('S');        l_pdf := PL_FPDF.OutputBlob;
PL_FPDF.Output('F', path);           PL_FPDF.OutputFile(name, directory);
```

| v0.9.4 | v2.0+ |
|--------|-------|
| `fpdf()` | `Init()` (`fpdf()` remains available for compatibility) |
| `Output('S')` | `OutputBlob` |
| `Output` with destination `'I'`, `'D'` or `'S'` (the first two sent the HTTP headers) | raises `ORA-20306`: return the BLOB and deliver it yourself — see [Delivering the PDF to a browser](DOCUMENTATION_EN.md#delivering-the-pdf-to-a-browser) |
| Limited UTF-8 | Full UTF-8 + TrueType |
| No encryption | AES-256, AES-128 and RC4 (3.x) |

### What actually breaks

**Seven names are gone** between 0.9.4 and today, and all seven are the demo
routines listed in the 3.2 → 3.3 jump. None is API.

**Of the 133 signatures in common, one changed**, in 2.0.0: `AddPage`'s
parameter went from `orientation` to `p_orientation`.

```sql
PL_FPDF.AddPage('L');                    -- positional: still works
PL_FPDF.AddPage(orientation   => 'L');   -- 0.9.4: no longer compiles
PL_FPDF.AddPage(p_orientation => 'L');   -- today
```

The **positional** form — the one in the 2017 samples — goes through unchanged.
Only the **named** form needs one word changed.

> **Why not keep both names?** PL/SQL overloading resolves by type and
> position, never by parameter name, and a parameter can only have one name.
> Two `AddPage`s whose first parameter is a `VARCHAR2` cannot be told apart:
> `AddPage('L')` would match both and Oracle rejects it with `PLS-00307`.

### The legacy entry points still stand

The 2017 port's constructor and flow still work, and a test runs the original
`helloworld` sequence call by call:

```sql
PL_FPDF.FPDF('P', 'cm', 'A4');   -- the legacy constructor gets the package ready
PL_FPDF.openpdf;                 -- accepted; AddPage now calls it by itself
PL_FPDF.AddPage();
PL_FPDF.SetFont('Arial', 'B', 16);
PL_FPDF.Cell(0, 1.2, 'Hello World', 0, 1, 'C');
l_pdf := PL_FPDF.ReturnBlob;     -- from 0.9.4, still there
```

`SetHeaderProc` and `SetFooterProc`, the header and footer mechanism by
procedure name, also remain.
