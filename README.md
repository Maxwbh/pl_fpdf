# PL_FPDF - PDF Generation for Oracle PL/SQL

<!-- Badges Section -->
<p align="center">
  <a href="https://github.com/Maxwbh/pl_fpdf/releases"><img src="https://img.shields.io/badge/version-2.0.0-blue.svg" alt="Version"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/blob/master/LICENSE"><img src="https://img.shields.io/badge/license-GPL%20v2-green.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/Oracle-19c%2F23c-red.svg" alt="Oracle">
  <img src="https://img.shields.io/badge/tests-87%20passing-brightgreen.svg" alt="Tests">
  <img src="https://img.shields.io/badge/coverage-82%25-brightgreen.svg" alt="Coverage">
</p>

<p align="center">
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers"><img src="https://img.shields.io/github/stars/Maxwbh/pl_fpdf?style=social" alt="GitHub Stars"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/network/members"><img src="https://img.shields.io/github/forks/Maxwbh/pl_fpdf?style=social" alt="GitHub Forks"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/watchers"><img src="https://img.shields.io/github/watchers/Maxwbh/pl_fpdf?style=social" alt="GitHub Watchers"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/issues"><img src="https://img.shields.io/github/issues/Maxwbh/pl_fpdf" alt="GitHub Issues"></a>
</p>

<p align="center">
  <strong>Modern, high-performance PDF generation library for Oracle Database 19c/23c</strong>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-documentation">Documentation</a> •
  <a href="#-contributing">Contributing</a>
</p>

---

## 🎯 Why PL_FPDF?

**Generate PDFs directly from your Oracle Database** without external dependencies, middleware, or complex integrations.

| Challenge | PL_FPDF Solution |
|-----------|-----------------|
| Need to generate reports from Oracle? | Pure PL/SQL - runs inside the database |
| Performance bottlenecks? | Native compilation gives 2-3x speed boost |
| Complex external dependencies? | Zero dependencies - no OWA, no OrdImage |
| Limited document sizes? | CLOB buffers support unlimited pages |
| International characters? | Full UTF-8 and TrueType font support |

**Perfect for:** Reports, Invoices, Receipts, Certificates, Labels, Tickets, and any PDF document generation from Oracle Database.

---

PL_FPDF is a pure PL/SQL library for generating PDF documents directly from Oracle Database. Originally ported from FPDF PHP library (v1.53), it has been completely modernized for Oracle 19c/23c with native compilation, UTF-8 support, and advanced Oracle features.

[**Português (Brasil)**](README_PT_BR.md) | [**API Reference**](API_REFERENCE.md) | [**Contributing**](CONTRIBUTING.md)

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
- ✅ **Zero external dependencies** (no OWA, no OrdImage)

---

## 📦 Installation

### Quick Install

```sql
sqlplus user/password@database @deploy_all.sql
```

### Manual Installation

```sql
-- 1. Install core package
@PL_FPDF.pks
@PL_FPDF.pkb

-- 2. Verify installation
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PL_FPDF';
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

  -- Save to Oracle directory
  PL_FPDF.OutputFile('MY_DIRECTORY', 'sample.pdf');

  PL_FPDF.Reset();
END;
/
```

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


---

## 🧪 Testing

### Run All Tests

```bash
cd tests
sqlplus user/pass@db @run_all_tests.sql
```

### Test Coverage

| Module | Tests | Coverage |
|--------|-------|----------|
| Initialization | 43 | >90% |
| Fonts | 18 | >85% |
| Images | 14 | >80% |
| Output | 7 | >90% |
| Performance | 5 | 100% |
| **Total** | **87** | **>82%** |

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

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's bug reports, feature requests, documentation improvements, or code contributions.

**Ways to contribute:**
- 🐛 [Report bugs](https://github.com/Maxwbh/pl_fpdf/issues/new?template=bug_report.md)
- 💡 [Request features](https://github.com/Maxwbh/pl_fpdf/issues/new?template=feature_request.md)
- 📝 Improve documentation
- 🔧 Submit pull requests

See our [**Contributing Guide**](CONTRIBUTING.md) for detailed information.

### Original Authors
- **FPDF (PHP)**: Olivier PLATHEY
- **PL_FPDF (Oracle)**: Pierre-Gilles Levallois et al

### Modernization Project
- **Lead Developer**: Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))
- **Email**: maxwbh@gmail.com
- **LinkedIn**: [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

---


## 🔗 Links

- **Original FPDF**: http://www.fpdf.org/
- **Original Repository**: https://github.com/Pilooz/pl_fpdf

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

## ⭐ Support the Project

If you find PL_FPDF useful, please consider:

- ⭐ **Star this repository** - It helps others discover the project
- 🐛 **Report issues** - Help us improve by reporting bugs
- 💬 **Share** - Tell your colleagues about PL_FPDF
- 🤝 **Contribute** - Submit PRs to help the project grow

[![GitHub stars](https://img.shields.io/github/stars/Maxwbh/pl_fpdf?style=for-the-badge&logo=github)](https://github.com/Maxwbh/pl_fpdf/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Maxwbh/pl_fpdf?style=for-the-badge&logo=github)](https://github.com/Maxwbh/pl_fpdf/network/members)

---

## 📣 Spread the Word

**Keywords:** Oracle PL/SQL PDF, PDF Generation Oracle, Oracle Report Generator, PL/SQL PDF Library, Oracle 19c PDF, Oracle 23c PDF, FPDF Oracle, Generate PDF Oracle Database, Oracle PDF Export, PL/SQL Report Library

**Hashtags:** #Oracle #PLSQL #PDF #OracleDatabase #PDFGeneration #OpenSource

---

**Last Updated**: December 19, 2025
**Version**: 2.0.0
**Status**: Production Ready ✅

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/maxwbh">Maxwell Oliveira</a> and the open source community.
</p>
