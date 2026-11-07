# Compatibility — PL_FPDF

[**Português**](COMPATIBILITY.md) · [Documentation index](README.md)

What was **measured**, and on what. Where there is no measurement, the table
says "not tested", not "compatible".

---

## 1. Oracle versions

| Oracle | 3.3.0 | 3.4.0 |
|--------|----------------|-------------------|
| 19c, AL32UTF8 | works | the full suite passed (maintainer's run) |
| 26ai (23.26), AL32UTF8 | **does not work**: every `SetFont` with a standard font raises `ORA-29275` | the full suite passed — see the evidence below |
| 21c; 23ai releases before 26ai | not tested | not tested |
| 18c and earlier | not supported | not supported |

**Why 3.3.0 breaks on 26ai.** It builds the font width table with `CHR(i)` for
i from 0 to 255. `CHR` returns the character whose **byte** is i in the database
character set, and on 26ai with AL32UTF8 the bytes that open a UTF-8 sequence
(194 to 244) raise `ORA-29275: partial multibyte character` — on 19c, the same
`CHR` returns the raw byte without complaint. 3.4.0 indexes the table by byte,
with no `CHR`. Measured on both databases, with each version's installer.

**In short:** on 26ai, use 3.4.0 or later.

### Evidence from the 26ai run

| | |
|---|---|
| Database | Oracle AI Database 26ai Free 23.26.3.0.0, image `gvenzl/oracle-free:23.26.3-faststart`, PDB `FREEPDB1`, AL32UTF8 |
| Code | the 3.4.0 `src/` (the `v3.4.0-rc2` candidate, without the encrypted-PDF refusal in `LoadPDF`, had passed 346 of 346 on the same database) |
| Command | `python dev/scripts/run_tests.py --full`, on the container's application schema |
| Result | 351 checks passed, 0 failed, 2 skipped; the documentation's 12 runnable samples ran; 29 PDFs generated in the database and checked by MuPDF and zxing-cpp |
| The 2 skipped | in `test_compat_legado`: the legacy `Output` writes to `DIRECTORY PDF_DIR`, which the test schema does not have; and the absence of the demo routines, checked another way |
| Date | 2026-11-07 |

The 19c run is the maintainer's, on their environment; the number of checks
changes with every test added, so the table does not pin it.

## 2. Database character set

| Character set | Status |
|---------------|--------|
| AL32UTF8 | tested on 19c and 26ai |
| Single-byte (WE8MSWIN1252, WE8ISO8859P1…) | outside the regular runs: not tested on 3.4.0 |

On AL32UTF8, text is converted to the font's encoding when it is written, and
the limit is the font's (section 3). On another character set there is a limit
before that one: only what the database can hold in a `VARCHAR2` reaches
PL_FPDF — and that path is not covered by the tests.

## 3. Text and fonts

| Font | Encoding | What it writes |
|------|----------|----------------|
| Helvetica, Times, Courier, in all four styles (Arial is Helvetica) | WinAnsi (cp1252), declared in the PDF | Portuguese, Spanish, French, German and the other Western European languages |
| Symbol | the font's own — the PDF does **not** declare WinAnsi | Greek letters and math symbols, picked **by code** |
| ZapfDingbats | the font's own — the PDF does **not** declare WinAnsi | ornaments and bullets, picked **by code** |
| Embedded TrueType (`AddTTFFont`, `LoadTTFFromFile`) | per the font's Unicode mapping (`cmap`) | whatever the font has |

A character outside WinAnsi in a standard font — an ideogram, Cyrillic, an
emoji — is **refused** with `ORA-20203` and its position (3.4.0). For those
scripts, embed a TrueType font.

**Symbol and ZapfDingbats pick the glyph by code, not by character.** Text goes
through the same conversion as the other fonts, and the resulting byte indexes
the font's own encoding. Measured on 26ai: in Symbol, `'abgp'` comes out as
`αβγπ`; but `'α'`, passed as a Greek letter, raises `ORA-20203`, because it
does not exist in WinAnsi. In ZapfDingbats, `'3'` draws the check mark; `'✓'`
raises `ORA-20203`. Look up the font's code table, and keep in mind that text
copied from the PDF does not carry the symbol — these fonts go out with no
Unicode map.

## 4. The generated PDF

| | |
|---|---|
| Default version | 1.4 |
| Versions `SetPDFVersion` accepts | 1.4, 1.5, 1.6, 1.7, 2.0 |
| Cipher × minimum version | RC4 → 1.4 · AES-128 → 1.5 · AES-256 → 1.7 · PDF 2.0 accepts only AES-256 |
| Compression | in-house DEFLATE, read by any viewer (output checked against zlib) |
| Checked with | MuPDF, and zxing-cpp for the codes — see [MANUTENCAO.md](MANUTENCAO.md) |

## 5. The PDF read (`LoadPDF` and manipulation)

| Input | Status |
|-------|--------|
| Classic xref (PDF 1.0–1.4) | reads it |
| Cross-reference streams and object streams (PDF 1.5+) | reads them; on output, objects are flattened and the xref is classic again |
| Encrypted PDF | refused with `ORA-20867`: `LoadPDF` does not decrypt. Run it through `DecryptPDF` first, which needs the password. Up to 3.4.0-rc2 it was accepted silently, and the output came out with blank pages |
| Compressed streams | FlateDecode, with an 8 MB ceiling per stream |
| Forms (AcroForm), digital signatures | not handled — see the limitations in the [README](../README_EN.md#limitations) |

## 6. What exists only in 3.4.0

If you are still on 3.3.0, this is not available:

| Feature | On 3.3.0 |
|---------|----------|
| Correct accents in standard fonts (conversion to WinAnsi) | an accent comes out as two wrong glyphs |
| `GetStringWidth`, centring and right alignment with accents | `ORA-06502` |
| TrueType font actually embedded (`/FontFile2`) | the registered font is not used |
| `ImageFromBlob` (image from a BLOB, no network ACL) | only `Image` from a URL |
| Running on Oracle 26ai | does not work (§1) |

The full list, with cause and fix, is in the [CHANGELOG](../CHANGELOG.md).

## 7. What the suite covers

Each set below is a file in `dev/tests/`, and all of them passed on 3.4.0, on
19c and on 26ai. The generated PDFs are read back by independent readers —
"no error" is not enough.

| Set | Files |
|-----|-------|
| Installation, life cycle and output | `test_core`, `test_ciclo_saida`, `test_compat_legado` |
| Generation: text, fonts, drawing | `test_geracao_basica`, `test_fonte_texto`, `test_winansi`, `test_desenho`, `test_cursor_margens`, `test_sublinhado` |
| Images | `test_stream_imagem` |
| TrueType | `test_fontes_truetype` |
| Manipulating an existing PDF | `test_manipulacao_completa`, `test_paginas_girar_remover`, `test_marca_dagua`, `test_sobreposicao`, `test_saida_modificada`, `test_mesclar_dividir` |
| Reading PDF | `test_leitura_pdf`, `test_leitura_paginas` |
| Encryption | `test_seguranca` |
| Metadata | `test_metadados_config` |
| Regressions | `test_regressoes_revisao` |

API by API, what exercises each one is in [TRACEABILITY.md](TRACEABILITY.md),
generated from the sources. How to run them: [MANUTENCAO.md](MANUTENCAO.md). The payments extension has its
own suites, separately: see the [extension README](../extensions/brazilian-payments/README.md).
