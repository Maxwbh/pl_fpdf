# PL_FPDF - PDF Generation for Oracle PL/SQL

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2F23c-red.svg)
![License](https://img.shields.io/badge/license-GPL%20v2-green.svg)
![Tests](https://img.shields.io/badge/tests-87%20passing-brightgreen.svg)
![Coverage](https://img.shields.io/badge/coverage-82%25-brightgreen.svg)

> **Modern, high-performance PDF generation library for Oracle Database 19c/23c**

PL_FPDF is a pure PL/SQL library for generating PDF documents directly from Oracle Database. Originally ported from FPDF PHP library (v1.53), it has been completely modernized for Oracle 19c/23c with native compilation, UTF-8 support, and Brazilian PIX/Boleto payment integration.

[**Português (Brasil)**](README_PT_BR.md) | [**API Reference**](API_REFERENCE.md) | [**Migration Guide**](MIGRATION_GUIDE.md)

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

### Brazilian Payment Systems
- ✅ **PIX QR Codes** (EMV QR Code Merchant-Presented Mode)
  - All key types: CPF, CNPJ, Email, Phone, Random (EVP)
  - Static and dynamic PIX
  - CRC16-CCITT validation

- ✅ **Boleto Bancário** (FEBRABAN standard)
  - Interbank 2 of 5 (ITF-14) barcode
  - Linha digitável (47-digit formatted line)
  - Módulo 11 check digit
  - Fator de vencimento calculation

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
-- 1. Install base package
@PL_FPDF.pks
@PL_FPDF.pkb

-- 2. Install PIX package (optional)
@PL_FPDF_PIX.pks
@PL_FPDF_PIX.pkb

-- 3. Install Boleto package (optional)
@PL_FPDF_BOLETO.pks
@PL_FPDF_BOLETO.pkb

-- 4. Verify installation
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name LIKE 'PL_FPDF%';
```

### Performance Optimization (Recommended)

```sql
-- Enable native compilation for 2-3x performance
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

## 💳 Brazilian Payment Systems

### PIX QR Code

```sql
DECLARE
  l_pix_data JSON_OBJECT_T;
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init();
  PL_FPDF.AddPage();

  -- Configure PIX data
  l_pix_data := JSON_OBJECT_T();
  l_pix_data.put('pixKey', 'payment@mystore.com');
  l_pix_data.put('pixKeyType', 'EMAIL');
  l_pix_data.put('merchantName', 'My Store');
  l_pix_data.put('merchantCity', 'Sao Paulo');
  l_pix_data.put('amount', 150.00);
  l_pix_data.put('txid', 'ORDER12345');

  -- Add QR Code to PDF
  PL_FPDF_PIX.AddQRCodePIX(50, 50, 50, l_pix_data);

  -- Add copy-paste code
  PL_FPDF.SetFont('Courier', '', 8);
  PL_FPDF.Text(50, 110, PL_FPDF_PIX.GetPixPayload(l_pix_data));

  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
/
```

### Boleto Bancário

```sql
DECLARE
  l_boleto_data JSON_OBJECT_T;
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init();
  PL_FPDF.AddPage();

  -- Configure Boleto data
  l_boleto_data := JSON_OBJECT_T();
  l_boleto_data.put('banco', '001');  -- Banco do Brasil
  l_boleto_data.put('moeda', '9');
  l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
  l_boleto_data.put('valor', 1500.00);
  l_boleto_data.put('campoLivre', '1234567890123456789012345');

  -- Add linha digitável
  PL_FPDF.SetFont('Arial', 'B', 12);
  PL_FPDF.Text(20, 190, PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data));

  -- Add barcode
  PL_FPDF_BOLETO.AddBarcodeBoleto(20, 200, 170, 15, l_boleto_data);

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
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Migration guide from v0.9.4 to v2.0 |
| [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) | Performance optimization guide |
| [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) | Testing and validation guide |
| [tests/README_TESTS.md](tests/README_TESTS.md) | Unit testing documentation |

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

See [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) for complete guide.

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
│            PL_FPDF (Base Package)           │
│  • PDF generation core                      │
│  • Generic QRCode/Barcode rendering         │
│  • UTF-8 support, TrueType fonts            │
└────────────┬───────────────────────┬────────┘
             │                       │
    ┌────────▼────────┐     ┌───────▼────────┐
    │  PL_FPDF_PIX    │     │ PL_FPDF_BOLETO │
    │  • PIX QR Codes │     │ • Boleto       │
    │  • EMV standard │     │ • FEBRABAN     │
    └─────────────────┘     └────────────────┘
```

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

## 📄 License

This program is free software; you can redistribute it and/or modify it under the terms of the **GNU General Public License v2** as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

---

## 🔗 Links

- **Original FPDF**: http://www.fpdf.org/
- **GitHub Repository**: https://github.com/maxwbh/pl_fpdf
- **Issues**: https://github.com/maxwbh/pl_fpdf/issues

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

**Last Updated**: December 19, 2025
**Version**: 2.0.0
**Status**: Production Ready ✅
