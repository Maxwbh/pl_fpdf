# PL_FPDF - PDF Generation for Oracle PL/SQL

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2F23c-red.svg)

> **Modern, high-performance PDF generation library for Oracle Database 19c/23c**

PL_FPDF is a pure PL/SQL library for generating PDF documents directly from Oracle Database. Originally ported from FPDF PHP library (v1.53), it has been completely modernized for Oracle 19c/23c with native compilation, UTF-8 support, and advanced Oracle features.

[**Português (Brasil)**](README_PT_BR.md) | [**API Reference**](API_REFERENCE.md) 

---

## ✨ Features

### Core PDF Generation
- ✅ **Multi-page documents** with unlimited pages
- ✅ **Text rendering** with multiple fonts (Arial, Courier, Times, Helvetica)
- ✅ **TrueType/OpenType fonts** with full embedding support
- ✅ **UTF-8 encoding** for international characters
- ✅ **Graphics primitives** (lines, rectangles, circles, polygons)
- ✅ **Image embedding** (PNG, JPEG) with native parsing
- ✅ **Text rotation** (0°, 90°, 180°, 270°)
- ✅ **Custom page formats** (A3, A4, A5, Letter, Legal, custom sizes)

### Modern Oracle Features
- ✅ **Native compilation** (2-3x performance improvement)
- ✅ **CLOB buffers** for unlimited document size
- ✅ **JSON configuration** (Oracle 19c+ JSON_OBJECT_T)
- ✅ **Structured logging** with DBMS_APPLICATION_INFO
- ✅ **Custom exceptions** with meaningful error codes
- ✅ **Result cache** for font metrics
- ✅ **No OWA, no ORDSYS.ORDImage** — PNG and JPEG are parsed in PL/SQL

> Loading an image **by URL** goes through `URIFactory`, so it needs a network
> ACL for the calling schema. Everything else runs with no access outside the
> database.

---

## 📦 Installation

### Install

Two files, spec first. In SQL\*Plus or SQLcl:

```sql
@PL_FPDF.pks
@PL_FPDF.pkb
```

In PL/SQL Developer or any other GUI, open each file in a SQL window and run it.

Then verify — the status must be `VALID`:

```sql
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name = 'PL_FPDF';
```

Do not put the password on the command line; it lands in the shell history and
in the process list. Let the client prompt for it.

### Optional Extensions

Brazilian payment documents (PIX and Boleto) live in
`extensions/brazilian-payments/` and install separately, on top of the core
package.

### Performance Optimization (Recommended)

```sql
-- Native compilation, 2-3x faster
@optimize_native_compile.sql
```

---

## 🚀 Quick Start

### Hello World

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- Initialize PDF
  PL_FPDF.Init('P', 'mm', 'A4');

  -- Add page
  PL_FPDF.AddPage();

  -- Set font
  PL_FPDF.SetFont('Arial', 'B', 16);

  -- Add text
  PL_FPDF.Cell(0, 10, 'Hello World!');

  -- Generate PDF
  l_pdf := PL_FPDF.OutputBlob();

  -- Cleanup
  PL_FPDF.Reset();

  -- Save to file or send to client
  -- ... (see examples below)
END;
/
```

### Save PDF to File

```sql
BEGIN
  PL_FPDF.Init();
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Sample PDF');

  -- Save to an Oracle directory. Filename first, directory second; the
  -- directory defaults to PDF_DIR.
  PL_FPDF.OutputFile('sample.pdf', 'MY_DIRECTORY');

  PL_FPDF.Reset();
END;
/
```

### Legacy Constructor

`Init()` is the entry point for new code. Code written before it existed calls
`FPDF()` instead, and that still works — it sets the same state and leaves the
package initialized:

```sql
BEGIN
  PL_FPDF.FPDF('P', 'cm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(40, 10, 'Hello World!');
  PL_FPDF.Reset();
END;
/
```

Whichever one you call, call it before `AddPage()`. Without it the package is
not initialized and the next call raises `ORA-20005`. See
[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for the full list of legacy entry
points.

### Multi-Page Document

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init();
  PL_FPDF.SetFont('Arial', '', 12);

  -- Generate 100 pages
  FOR i IN 1..100 LOOP
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Page ' || i || ' of 100');
  END LOOP;

  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
/
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README_PT_BR.md](README_PT_BR.md) | Complete documentation in Portuguese |
| [API_REFERENCE.md](API_REFERENCE.md) | Complete API reference with all functions |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Moving from 0.9.x to 2.0.0, and which legacy calls still work |
| [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) | How to check that an installation is sound |
| [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) | Native compilation and tuning |
| [CHANGELOG.md](CHANGELOG.md) | What changed in each version |


---

## 🧪 Testing

### Run All Tests

The suite needs utPLSQL v3+. From the `tests` directory:

```sql
@install_tests.sql
@run_all_tests.sql
```

`run_init_tests_simple.sql` and `run_legacy_init_tests_simple.sql` are anonymous
blocks that run without utPLSQL, for checking an installation quickly.

### Test Count

| Module | Tests |
|--------|-------|
| Initialization | 37 |
| Fonts | 18 |
| Images | 14 |
| Output | 7 |
| Performance | 5 |
| **Total** | **81** |

---

## ⚡ Performance

### Benchmarks (Oracle 19c, Native Compilation)

| Operation | Time | Throughput |
|-----------|------|------------|
| Init() | 15-30ms | - |
| 100-page document | 1.2-1.8s | 55-83 pages/sec |
| 1000-page document | 8-12s | 83-125 pages/sec |
| OutputBlob (50 pages) | 150-250ms | - |

### Optimization Tips

1. **Enable native compilation** (2-3x faster)
   ```sql
   @optimize_native_compile.sql
   ```

2. **Reuse Init/Reset** instead of creating new instances
   ```sql
   PL_FPDF.Init();
   -- Generate PDF #1
   PL_FPDF.Reset();
   PL_FPDF.Init();
   -- Generate PDF #2
   ```

3. **Disable logging in production**
   ```sql
   PL_FPDF.SetLogLevel(0);
   ```


---

## 📋 Requirements

- Oracle Database 19c or higher (23c recommended)
- PL/SQL Developer or SQL*Plus
- Permissions: CREATE PROCEDURE, EXECUTE
- Optional: utPLSQL v3+ for running tests

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│            PL_FPDF (Core Package)           │
│  • PDF document generation                  │
│  • Text rendering and fonts                 │
│  • Image embedding (PNG, JPEG)              │
│  • Graphics primitives                      │
│  • UTF-8 support, TrueType fonts            │
│  • Multi-page documents                     │
│  • Generic QRCode/Barcode rendering         │
└─────────────────────────────────────────────┘
```

**Optional Extensions**: Brazilian payment documents (PIX/Boleto) ship as
separate extensions under `extensions/`.

---

## 🤝 Contributing

This is a modernization project of the original PL_FPDF library. Contributions are welcome!

### Original Authors
- **FPDF (PHP)**: Olivier PLATHEY
- **PL_FPDF (Oracle)**: Pierre-Gilles Levallois et al

### Modernization Project
- **Lead Developer**: Maxwell da Silva Oliveira (@maxwbh)
- **Company**: M&S do Brasil LTDA
- **Contact**: maxwbh@gmail.com
- **LinkedIn**: [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

---


## 🔗 Links

- **Original FPDF**: http://www.fpdf.org/
- **Original Repository**: https://github.com/Pilooz/pl_fpdf
- **This Repository**: https://github.com/maxwbh/pl_fpdf

---

## 📊 Project Status

✅ **v2.0.0 Released** - December 2025

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1: Critical Refactoring | ✅ Complete | 100% |
| Phase 2: Security & Robustness | ✅ Complete | 100% |
| Phase 3: Advanced Modernization | ✅ Complete | 100% |

**Modernization complete: 100%**

---

## ⭐ Star History

If you find this project useful, please give it a star on GitHub!

---

**Last Updated**: September 9, 2026
**Version**: 2.0.0
**Status**: Production Ready ✅
