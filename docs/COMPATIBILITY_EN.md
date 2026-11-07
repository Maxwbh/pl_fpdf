# Compatibility — PL_FPDF

[**Português**](COMPATIBILITY.md) · [Documentation index](README.md)

What was **measured**, and on what. Where there is no measurement, the table
says "not tested", not "compatible".

---

## 1. Oracle versions

| Oracle | 3.3.0 (stable) | 3.4.0 (candidate) |
|--------|----------------|-------------------|
| 19c, AL32UTF8 | works | the full suite runs on every change |
| 26ai (23.26), AL32UTF8 | **does not work**: every `SetFont` with a standard font raises `ORA-29275` | the full suite passed: 346 tests, 0 failures (2026-11-07, v3.4.0-rc2) |
| 21c; 23ai releases before 26ai | not tested | not tested |
| 18c and earlier | not supported | not supported |

**Why 3.3.0 breaks on 26ai.** It builds the font width table with `CHR(i)` for
i from 0 to 255. `CHR` returns the character whose **byte** is i in the database
character set, and on 26ai with AL32UTF8 the bytes that open a UTF-8 sequence
(194 to 244) raise `ORA-29275: partial multibyte character` — on 19c, the same
`CHR` returns the raw byte without complaint. 3.4.0 indexes the table by byte,
with no `CHR`. Measured on both databases, with each version's installer.

**In short:** on 26ai, use 3.4.0 (today, v3.4.0-rc2).

## 2. Database character set

| Character set | Status |
|---------------|--------|
| AL32UTF8 | tested on 19c and 26ai |
| Single-byte (WE8MSWIN1252, WE8ISO8859P1…) | outside the regular runs: not tested on 3.4.0 |

The database character set does not limit what goes into the PDF: text is
converted to the font's encoding when it is written.

## 3. Text and fonts

| Font | What it writes |
|------|----------------|
| The 14 standard PDF fonts (Helvetica, Times, Courier, Symbol, ZapfDingbats) | the WinAnsi (cp1252) repertoire: Portuguese, Spanish, French, German and the other Western European languages |
| Embedded TrueType (`AddTTFFont`, `LoadTTFFromFile`) | whatever the font has |

A character outside WinAnsi in a standard font — an ideogram, Cyrillic, an
emoji — is **refused** with `ORA-20203` and its position (3.4.0). For those
scripts, embed a TrueType font.

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
| Encrypted PDF | `LoadPDF` **accepts it silently and does not decrypt**: the output has the page blank. Run it through `DecryptPDF` first, which needs the password |
| Compressed streams | FlateDecode, with an 8 MB ceiling per stream |
| Forms (AcroForm), digital signatures | not handled — see the limitations in the [README](../README_EN.md#limitations) |

## 6. What exists only in 3.4.0

If you are on the stable 3.3.0, this is not available yet:

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

How to run them: [MANUTENCAO.md](MANUTENCAO.md). The payments extension has its
own suites, separately: see the [extension README](../extensions/brazilian-payments/README.md).
