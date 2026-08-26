# PL_FPDF

<p align="center">
  <img src="https://img.shields.io/badge/version-3.2.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/oracle-19c%2B-red.svg" alt="Oracle">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/security-RC4-brightgreen.svg" alt="Security">
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

> **📌 About this project:** This is a fork of [Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf) —
> the original PL/SQL port of [FPDF](http://www.fpdf.org/) by Pierre-Gilles Levallois — actively
> **maintained, modernized and extended** by [@maxwbh](https://github.com/maxwbh):
> Oracle 19c/23c support, UTF-8/TrueType, PDF manipulation (v3.0), RC4 encryption (v3.2) and tooling.
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
| Protect documents | RC4 encryption with permissions |
| Zero dependencies | No OWA, no OrdImage, no external libs |
| Simple deployment | Just 2 files in `src/` folder |

---

## Installation

```sql
-- Option 1: Run deployment script
@deploy_all.sql

-- Option 2: Install manually
@src/PL_FPDF.pks
@src/PL_FPDF.pkb

-- Verify
SELECT PL_FPDF.co_version FROM DUAL;
-- Returns: 3.2.0
```

**Requirements:** Oracle 19c+ | No external dependencies

---

## Quick Start

### Create PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Hello World!', '0', 1, 'C');
  l_pdf := PL_FPDF.Output_Blob();
END;
```

### Modify Existing PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documents WHERE id = 1;

  PL_FPDF.LoadPDF(l_pdf);
  PL_FPDF.RotatePage(1, 90);
  PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3);
  PL_FPDF.RemovePage(3);

  l_pdf := PL_FPDF.OutputModifiedPDF();
END;
```

### Encrypt PDF

```sql
DECLARE
  l_pdf BLOB;
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_perms.put('print', TRUE);
  l_perms.put('copy', FALSE);

  l_pdf := PL_FPDF.EncryptPDF(
    p_pdf            => l_original,
    p_user_password  => 'user123',
    p_owner_password => 'owner456',
    p_permissions    => l_perms,
    p_encryption     => 'RC4-128'
  );
END;
```

### Merge PDFs

```sql
DECLARE
  l_merged BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID(l_pdf1, 'doc1');
  PL_FPDF.LoadPDFWithID(l_pdf2, 'doc2');
  l_merged := PL_FPDF.MergePDFs('doc1,doc2');
END;
```

---

## Features

### PDF Generation
- Multi-page documents (unlimited pages)
- Text, shapes, images (PNG, JPEG)
- TrueType fonts with UTF-8
- Barcodes (Code39, EAN-13, QR Code)
- Tables with auto-pagination

### PDF Manipulation
- Load and parse existing PDFs
- Rotate pages (0, 90, 180, 270)
- Remove pages
- Add watermarks (text/image)
- Text and image overlays
- Merge multiple PDFs
- Split PDF by page ranges

### Security (v3.2.0)
- RC4 40-bit encryption (legacy)
- RC4 128-bit encryption (standard)
- Password protection (user/owner)
- Permission controls (print, copy, modify, etc.)
- PDF decryption

### Brazilian Payments Extension (optional)
- PIX QR Codes (EMV Merchant-Presented Mode)
- Boleto Bancário (FEBRABAN standard)
- See [extensions/brazilian-payments](extensions/brazilian-payments/README.md)

### Architecture
- Pure PL/SQL (no external dependencies)
- Package-only (no tables, types, or sequences)
- Oracle 19c compatible (guaranteed)
- Native compilation support (2-3x faster)

---

## Project Structure

```
pl_fpdf/
│
├── src/                          # Source Code
│   ├── PL_FPDF.pks              # Package specification
│   └── PL_FPDF.pkb              # Package body
│
├── extensions/                   # Optional Extensions
│   └── brazilian-payments/      # PIX QR Code & Boleto
│
├── tests/                        # Test Suite (25+ tests)
├── scripts/                      # Utilities (incl. docx_to_plfpdf generator)
├── docs/                         # Documentation
├── README.md                     # Portuguese (primary)
├── README_EN.md                  # This file
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── deploy_all.sql
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md) | API Reference, Architecture, Migration |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Version planning, TODOs, Backlog |

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **3.2.0** | Jul 2026 | Security: RC4 encryption, permissions, decryption • DOCX→PL/SQL generator |
| 3.0.0 | Feb 2026 | PDF manipulation: load, modify, merge, split |
| 2.0.0 | Dec 2025 | Foundation: UTF-8, TrueType, barcodes, QR |

See [CHANGELOG.md](CHANGELOG.md) for full history.

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
**Maxwell da Silva Oliveira** ([@maxwbh](https://github.com/maxwbh)) the time and
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
- **This fork — Modernization & v2.x/v3.x:** Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))
- **Maintainer company:** [M&S do Brasil LTDA](https://msbrasil.inf.br) · [contato@msbrasil.inf.br](mailto:contato@msbrasil.inf.br)

---

## License

MIT License - see [LICENSE](LICENSE)

---

<p align="center">
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers">Star on GitHub</a> •
  <a href="https://github.com/Maxwbh/pl_fpdf/issues">Report Issue</a> •
  <a href="mailto:maxwbh@gmail.com">Contact</a>
</p>
