# PL_FPDF

<p align="center">
  <img src="https://img.shields.io/badge/version-3.4.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/oracle-19c%2B-red.svg" alt="Oracle">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/security-AES--256-brightgreen.svg" alt="Security">
  <a href="https://github.com/Maxwbh/pl_fpdf/actions/workflows/ci.yml"><img src="https://github.com/Maxwbh/pl_fpdf/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/releases"><img src="https://img.shields.io/github/v/release/Maxwbh/pl_fpdf?label=release" alt="Release"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers"><img src="https://img.shields.io/github/stars/Maxwbh/pl_fpdf?style=social" alt="Stars"></a>
</p>

<p align="center">
  <b>Pure PL/SQL PDF Generation & Manipulation Library</b>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#features">Features</a> •
  <a href="#documentation">Docs</a> •
  <a href="README.md">🇧🇷 Português (principal)</a>
</p>

> **3.4.0 is under test.** The latest stable release is **3.3.0**, which does
> **not** carry the WinAnsi conversion for accented text nor embedded TrueType
> fonts — both are 3.4.0, now published as a candidate (**v3.4.0-rc2**). The
> suite runs against an Oracle **19c** database on every change, and the full
> round on **26ai** (23.26) passed.

A PDF library that runs **inside Oracle Database**: two PL/SQL packages, no
Java, no external service, no database object beyond them. It generates and
also **manipulates** — load, merge, split, watermark, and **protect with
passwords and AES-256 encryption**.

The full public surface is in
[`docs/API_REFERENCE_EN.md`](docs/API_REFERENCE_EN.md), maintained by
[@Maxwbh](https://github.com/Maxwbh) since 2019: PDF manipulation (v3.0), PDF 1.5+ reading with cross-reference and
object streams, AES-256/AES-128/RC4, QR codes and barcodes, DEFLATE and INFLATE
written in PL/SQL, UTF-8/TrueType and Oracle 19c and 26ai.

> **Lineage.** The generation core descends from the PL/SQL port by
> [Pierre-Gilles Levallois](https://github.com/Pilooz), who brought Olivier
> Plathey's [FPDF](http://www.fpdf.org/) to Oracle. That is where the API you
> may already know comes from — `Cell`, `AddPage`, `SetFont`, `MultiCell`. On
> top of it, this project added new APIs without removing a single original
> one. Full credits at the bottom of this page.
>
> This document is a secondary translation. The canonical, most complete README is
> [**README.md**](README.md) (Portuguese — Brazil).

---

## Why PL_FPDF?

Generate and manipulate PDFs **directly in Oracle Database** - no Java, no external services, no middleware.

| Need | Solution |
|------|----------|
| Create reports from Oracle | Pure PL/SQL - runs inside the database |
| Modify existing PDFs | Load, edit, merge, split - all in PL/SQL |
| Protect documents | AES-256, AES-128 or RC4 encryption with permissions |
| Zero dependencies | No OWA, no OrdImage, no external libs |
| Simple deployment | Two packages, no database objects: `PL_FPDF_UTIL` then `PL_FPDF` |
| Brazilian market | Optional extension for **PIX** (EMV QR code) and **Boleto** (FEBRABAN) |

---

## Installation

**One file, no clone.** Which file depends on what you want:

| For | Download |
|-----|----------|
| **Production** on Oracle 19c — the stable version, 3.3.0 | the [v3.3.0 release `pl_fpdf_install.sql`](https://github.com/Maxwbh/pl_fpdf/releases/download/v3.3.0/pl_fpdf_install.sql) |
| **Oracle 26ai** | **no stable version works** (3.3.0 raises `ORA-29275`). The only one that runs is the [v3.4.0-rc2](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2) candidate — see the [26ai policy](SECURITY.md#oracle-26ai) |
| **Trying 3.4.0** — candidate, still under test | the [v3.4.0-rc2 `pl_fpdf_install.sql`](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2), or [`dist/` on `master`](https://raw.githubusercontent.com/Maxwbh/pl_fpdf/master/dist/pl_fpdf_install.sql) |
| **Exactly what this page describes** | the [`dist/pl_fpdf_install.sql`](dist/pl_fpdf_install.sql) of the branch you are viewing — the link follows the branch |

`master` follows development and already carries 3.4.0; it is **not** the
stable version. This page describes 3.4.0, and what exists only there is marked
in the [CHANGELOG](CHANGELOG.md).
Open it in the PL/SQL Developer SQL Window (F8) — or run `@pl_fpdf_install.sql`
in SQL\*Plus / SQLcl — and you are done. It carries both packages in dependency
order, and it is plain SQL: no tool-specific commands, no table, sequence or
directory to create first.

```sql
-- If you would rather install from the clone, the utility comes FIRST:
-- PL_FPDF calls PL_FPDF_UTIL, and the reverse order leaves the former invalid.
@src/PL_FPDF_UTIL.pks
@src/PL_FPDF_UTIL.pkb
@src/PL_FPDF.pks
@src/PL_FPDF.pkb

-- Verify (the version shows in the Output tab; in SQL*Plus, turn on
-- SET SERVEROUTPUT ON first). A package constant cannot be read in a SELECT:
-- SELECT PL_FPDF.co_version FROM DUAL raises ORA-06553 PLS-221
BEGIN
  DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version);  -- 3.4.0
END;
/
```

**Requirements:** Oracle 19c+, and `CREATE PROCEDURE` in the schema where the
packages will live. Nothing else — in particular, **no**
`GRANT EXECUTE ON SYS.DBMS_CRYPTO` is needed.

3.4.0 passes the full suite on 19c and 26ai; what was measured on each Oracle
version and character set is in [Compatibility](docs/COMPATIBILITY_EN.md).
Checking the installation, granting access to other schemas, upgrading and
uninstalling: [Installation](docs/INSTALLATION_EN.md).

**No external dependencies, not even for encryption.** `EncryptPDF`/`DecryptPDF` use MD5 and SHA via `STANDARD_HASH` (native SQL functions); RC4 and AES are implemented in the package itself.

---

## Quick Start

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Hello World!', '0', 1, 'C');

  l_pdf := PL_FPDF.OutputBlob();          -- the PDF, in memory

  -- From here it is yours: store it, send it, serve it.
  INSERT INTO documents (name, pdf) VALUES ('hello.pdf', l_pdf);
  -- or PL_FPDF.OutputFile('hello.pdf', 'PDF_DIR');   straight to a DIRECTORY
  -- or serve it to a browser — see "Entregar o PDF a um navegador"
  --    in docs/DOCUMENTATION.md
END;
```

**Arial maps to Helvetica**, as in FPDF: to the library they are the same
typeface. The examples use both names; pick one and stay with it.

### Showcase: the layout of a Brazilian bank slip, drawn in PL/SQL

<p align="center">
  <img src="site/assets/exemplo-boleto.png" alt="Brazilian bank slip generated by PL_FPDF: two copies, field grid and ITF barcode" width="640">
</p>

<p align="center"><sub>
  Actual output of <code>examples/boleto.sql</code>, produced inside Oracle and
  verified here: zxing reads all 44 barcode digits off the rendered PDF.
</sub></p>

An easy document is a page with a heading. What actually shows what the library
can do is the **layout of a boleto bancário** (Brazilian bank slip) — and it
comes out of the database whole, with no images at all:

| Item | Detail |
|---|---|
| Page | A4 portrait, with the **177 mm** payment slip centred on it |
| Fonts | three Helvetica variants (regular, bold, italic) in four sizes |
| Grid | **50 boxes** placed to the millimetre, in two copies, with a cut line |
| Alignment | a 40 mm value column, with the money **right-aligned** |
| Barcode | **44-digit ITF** — the one a bank scanner actually reads |
| Images | **none**: logo, rules and bars are all vector drawing |

> **PL_FPDF draws; it does not compute billing.** The 44 barcode digits and the
> digitable line arrive **ready**, like any other value you pass in. Building
> them from bank, due date, amount and free field — check digits, due-date
> factor, each bank's own rules — belongs to a billing project, not to a PDF
> library.

```sql
-- one field of the slip: small label on top, value underneath.
-- Cell already applies a 1 mm inner margin on both sides, so the width passed
-- in is the whole box — right-aligned text lands 1 mm from the border.
PROCEDURE campo(px NUMBER, py NUMBER, pw NUMBER, ph NUMBER,
                protulo VARCHAR2, pvalor VARCHAR2 DEFAULT NULL,
                pneg BOOLEAN DEFAULT FALSE, palin VARCHAR2 DEFAULT 'L') IS
BEGIN
  PL_FPDF.Rect(px, py, pw, ph, 'D');
  PL_FPDF.SetFont('Arial', '', 6);
  PL_FPDF.SetXY(px, py + 0.7);
  PL_FPDF.Cell(pw, 2.4, protulo, '0', 0, 'L');
  IF pvalor IS NOT NULL THEN
    PL_FPDF.SetFont('Arial', CASE WHEN pneg THEN 'B' END, 9);
    PL_FPDF.SetXY(px, py + 3.2);
    PL_FPDF.Cell(pw, 3.4, pvalor, '0', 0, palin);
  END IF;
END campo;

-- ...and the slip barcode, 103 x 13 mm as the Brazilian standard requires
PL_FPDF.AddBarcode(16.5, 233, 103, 13,
                   '34197167700000150001090000012323073123451000',
                   'ITF', FALSE);
```

📄 **[Complete, runnable example: `examples/boleto.sql`](examples/boleto.sql)**

The same applies to any tight-grid form: invoices, tax forms, contracts with
fields, registration sheets. What the example shows is **millimetre-accurate
positioning** with the library's own primitives.

### And its colourful sibling: an event ticket

<p align="center">
  <img src="site/assets/exemplo-ticket.png" alt="Event ticket generated by PL_FPDF: coloured header, QR code, barcode and panels" width="560">
</p>

<p align="center"><sub>
  Actual output of <code>examples/ticket.sql</code>, produced inside Oracle and
  verified here: zxing reads both the QR and the Code 39, and they carry the
  same code.
</sub></p>

The bank slip proves the grid. [`examples/ticket.sql`](examples/ticket.sql)
proves the rest — and neither uses a single image:

| Item | Detail |
|---|---|
| Colour | filled header band, **white text on top of it**, grey panels with white cores |
| Two symbols | **QR Code and Code 39 on the same page**, carrying the same code |
| Multi-page | one ticket per page, each with its own attendee and code |
| Free shape | the speech-bubble tail, via `Poly` — not everything is a rectangle |

```sql
-- coloured panel, and the title in white on top of it
PL_FPDF.SetFillColor(13, 25, 44);
PL_FPDF.Rect(12, 13.5, 186, 36, 'F');

PL_FPDF.SetTextColor(255, 255, 255);
PL_FPDF.SetFont('Arial', 'B', 17);
PL_FPDF.SetXY(16, 18);
PL_FPDF.Cell(178, 9, 'Orquestra Sinfônica - Concerto de Gala', '0', 0, 'L');

-- the same code in two symbologies, for scanning at the door
PL_FPDF.AddQRCode(p_x => 156, p_y => 58, p_size => 32, p_data => l_codigo);
PL_FPDF.AddBarcode(45, 117, 120, 10, l_codigo, 'CODE39', FALSE);
```

---

Manipulating existing PDFs, merge/split, encryption, QR codes, watermarks and the
rest of the API are covered in the documentation:

- 📖 **[Full usage reference](docs/DOCUMENTATION.md)** (Portuguese) — every API with parameters and examples
- 🌐 **[API usage index on the site](https://maxwbh.github.io/pl_fpdf/en/api.html)** — browsable version

---

## Features

- **Generation**: multi-page, text/shapes/images (PNG with alpha channel and interlaced, JPEG), TrueType fonts with UTF-8, auto-paginated tables
- **Codes**: QR Code (TEXT, URL, PIX, VCARD, WIFI, EMAIL) and barcodes (CODE128, CODE39, EAN13, EAN8, ITF, ITF14 — ITF covers the Brazilian bank slip barcode)
- **Manipulation**: load existing PDFs, rotate/remove pages, watermarks, overlays, merge and split — including PDF 1.5+, with cross-reference streams and object streams
- **Security**: AES-256, AES-128 and RC4 40/128-bit encryption, user/owner passwords, permission controls
- **Brazilian extension** (optional): [PIX & Boleto](extensions/brazilian-payments/README.md)
- **Architecture**: pure PL/SQL, package-only, Oracle 19c+, native compilation

The complete list, with the signature and an example for each API, lives in the
[usage reference](docs/DOCUMENTATION.md).

---

## Project Structure

**Seven files are all you need to know about:** the installer, the four sources
and the two examples. The rest is tooling for people maintaining the project.

```
pl_fpdf/
│
│  ═══════════════ for people using the library ═══════════════
│
├── dist/
│   └── pl_fpdf_install.sql       # ← start here: download and run it
│                                 #   one file, both packages in dependency
│                                 #   order. Generated from src/, plain SQL
│
├── src/                          # the sources, if you'd rather install from the clone
│   ├── PL_FPDF_UTIL.pks          # ← utility: QR, barcode, deflate, crypto
│   ├── PL_FPDF_UTIL.pkb          #   INSTALL THIS FIRST: PL_FPDF calls it
│   ├── PL_FPDF.pks               # specification — the API reference comes from here
│   └── PL_FPDF.pkb               # body
│
├── examples/                     # open in the SQL Window and run
│   ├── boleto.sql                # bank slip: 50-box grid, 44-digit ITF
│   └── ticket.sql                # event ticket: colour, QR + Code 39, multi-page
│
├── docs/
│   ├── README.md                 # documentation index, PT and EN
│   ├── INSTALLATION_EN.md        # install, check, upgrade, uninstall
│   ├── COMPATIBILITY_EN.md       # Oracle, character set and PDF: what was measured
│   ├── DOCUMENTATION_EN.md       # usage reference, one example per API
│   ├── API_REFERENCE_EN.md       # signature, parameters and errors (generated)
│   ├── MIGRATION_EN.md           # what changes between versions
│   ├── TROUBLESHOOTING_EN.md     # common problems, by symptom
│   └── *.md (no _EN)             # each guide above, in Portuguese
│
├── extensions/                   # optional, install only if you use it
│   └── brazilian-payments/       # PIX (EMV QR) and Boleto (FEBRABAN)
│
├── README.md  README_EN.md  CHANGELOG.md  LICENSE
│
│  ═══════ below this line, nothing ships to the database ═══════
│
├── dev/                          # the maintainer's side — see CONTRIBUTING.md
│   ├── tests/                    # suite, validations and diagnostics
│   └── scripts/                  # runner, generators and the Python references
│
├── site/                         # the page at maxwbh.github.io/pl_fpdf
└── CONTRIBUTING.md  SECURITY.md  CODE_OF_CONDUCT.md
```

These files are **generated** and never edited by hand — CI rejects any of them
if it falls behind:

| Generated | From | By |
|-----------|------|----|
| `dist/pl_fpdf_install.sql` | the four sources in `src/` | `dev/scripts/build_release.py` |
| `dev/tests/run_all_tests.sql` | `dev/tests/test_*.sql` | `dev/scripts/build_run_all.py` |
| `docs/API_REFERENCE*.md` and the `site/` pages | the Javadoc in `src/*.pks` | `dev/scripts/gen_docs/generate.py` |
| the font-width block in `src/PL_FPDF.pkb` | Adobe's AFM files | `dev/scripts/font_reference/gerar.py` |

---

## Limitations

What the library does **not** do, so you do not find out late:

| | |
|---|---|
| **Digital signature** | there is none. Password and AES-256 **protect** the document; signing with a certificate (PAdES, ICP-Brasil) is something else and out of scope |
| **JavaScript in the PDF** | neither generated nor preserved |
| **Forms (AcroForm)** | neither filled nor created |
| **Per-session state** | the package keeps the document in session memory. Two simultaneous generations in the **same** session trample each other; use `Reset` between documents, and remember that `ORA-04068` drops the state after a recompile |
| **Very large documents** | everything is built in memory and the cost is database CPU. Thousands of pages with images weigh; measure before promising |
| **Reprocessed images** | a PNG that needs its pixels redone has a 4-megapixel ceiling and comes out **uncompressed** |
| **Business rules** | boleto, PIX and the like: the library **draws**; computing check digits, due-date factors or payloads belongs to a billing project |

---

## Documentation

**For people using the library** — these cover only generating and manipulating PDFs:

The [documentation index](docs/README.md) lists everything, in Portuguese and
English, by task.

| Document | Description |
|----------|-------------|
| [docs/INSTALLATION_EN.md](docs/INSTALLATION_EN.md) | Install, check, grant access to other schemas, upgrade, uninstall |
| [docs/DOCUMENTATION_EN.md](docs/DOCUMENTATION_EN.md) | Full usage reference: every API with examples, APEX included |
| [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md) | The same guide in Portuguese |
| [docs/COMPATIBILITY_EN.md](docs/COMPATIBILITY_EN.md) | Oracle versions and character sets measured, the PDF written and read |
| [docs/MIGRATION_EN.md](docs/MIGRATION_EN.md) | What changes from one version to the next, 0.9.4 to 3.4.0 |
| [docs/TROUBLESHOOTING_EN.md](docs/TROUBLESHOOTING_EN.md) | Common problems, by error message or symptom |
| [docs/API_REFERENCE_EN.md](docs/API_REFERENCE_EN.md) | Signature, parameters and errors of each API |
| [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | The same reference in Portuguese (generated) |
| [API reference on the site](https://maxwbh.github.io/pl_fpdf/en/reference.html) | The same reference, browsable, in English |
| [API index on the site](https://maxwbh.github.io/pl_fpdf/en/api.html) | Task-oriented index, in English |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

**For people maintaining the code** — tests, CI and working method:

| Document | Description |
|----------|-------------|
| [docs/MANUTENCAO.md](docs/MANUTENCAO.md) | How to run the tests, what CI checks, the validated references (PT) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Planning, known gaps and what each check catches (PT) |

---

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Follow [coding standards](CONTRIBUTING.md)
4. Add tests
5. Submit Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 💼 Maintainer & Sponsor

Ongoing development of PL_FPDF is financially supported by
**[M&S do Brasil LTDA](https://msbrasil.inf.br)**, a Brazilian company specialized in
Oracle solutions. This sponsorship gives developer
**Maxwell da Silva Oliveira** ([@Maxwbh](https://github.com/Maxwbh)) the time and
structure to keep evolving the library — new releases, fixes, documentation and
community support — while keeping the project **free and open source (MIT)** for everyone.

For consulting, custom development or specialized Oracle/PL/SQL support, contact the
maintainer company: [msbrasil.inf.br](https://msbrasil.inf.br) ·
[contato@msbrasil.inf.br](mailto:contato@msbrasil.inf.br)

---

## 🙏 Acknowledgements

This project stands on the shoulders of the developers who came first:
**[Olivier Plathey](http://www.fpdf.org/)**, author of the original FPDF (PHP), which
defined the simple, code-first way of producing PDFs and inspired ports in dozens of
languages; **[Pierre-Gilles Levallois](https://github.com/Pilooz)**
([Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf)), who pioneered bringing FPDF into
Oracle Database with the original PL/SQL port this work builds upon; and
**Anton Scheffer** and the other contributors to the original port. Thank you.

---

## Credits

- **FPDF (PHP):** [Olivier PLATHEY](http://www.fpdf.org/)
- **Original PL/SQL Port:** [Pierre-Gilles Levallois](https://github.com/Pilooz) ([Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf)), Anton Scheffer
- **Modernization & v2.x/v3.x:** Maxwell da Silva Oliveira ([@Maxwbh](https://github.com/Maxwbh))
- **Maintainer company:** [M&S do Brasil LTDA](https://msbrasil.inf.br) · [contato@msbrasil.inf.br](mailto:contato@msbrasil.inf.br)

---

## License

**MIT.** [LICENSE](LICENSE) is this library's licence: use it, modify it,
redistribute it and ship it inside a commercial product, keeping the copyright
notice.

The generation core descends from a 2017 PL/SQL port; the lineage credits are
just below.

---

<p align="center">
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers">Star on GitHub</a> •
  <a href="https://github.com/Maxwbh/pl_fpdf/issues">Report Issue</a> •
  <a href="mailto:maxwbh@gmail.com">Contact</a>
</p>
