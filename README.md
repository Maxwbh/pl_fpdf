# PL_FPDF

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0.0--beta-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/oracle-19c%2B-red.svg" alt="Oracle">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/tests-150%2B-brightgreen.svg" alt="Tests">
</p>

<p align="center">
  <b>Pure PL/SQL PDF Generation & Manipulation Library</b>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#features">Features</a> •
  <a href="#documentation">Docs</a> •
  <a href="README_PT_BR.md">Portugues</a>
</p>

---

## Why PL_FPDF?

Generate and manipulate PDFs **directly in Oracle Database** - no Java, no external services, no middleware.

| Need | Solution |
|------|----------|
| Create reports from Oracle | Pure PL/SQL - runs inside the database |
| Modify existing PDFs | Load, edit, merge, split - all in PL/SQL |
| Zero dependencies | No OWA, no OrdImage, no external libs |
| Simple deployment | Just 2 files: `.pks` + `.pkb` |

---

## Installation

```sql
-- Install
@PL_FPDF.pks
@PL_FPDF.pkb

-- Verify
SELECT PL_FPDF.GetVersion() FROM DUAL;
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
- Barcodes (Code128, QR Code)
- Tables with auto-pagination

### PDF Manipulation
- Load and parse existing PDFs
- Rotate pages (0, 90, 180, 270)
- Remove pages
- Add watermarks
- Text and image overlays
- Merge multiple PDFs
- Split PDF by page ranges

### Architecture
- Pure PL/SQL (no external dependencies)
- Package-only (no tables, types, or sequences)
- Oracle 19c compatible (guaranteed)
- Native compilation support (2-3x faster)

---

## Documentation

| Document | Description |
|----------|-------------|
| [API Reference](docs/api/API_REFERENCE.md) | Complete API documentation |
| [Phase 4 Guide](docs/guides/PHASE_4_GUIDE.md) | PDF manipulation guide |
| [Performance](docs/guides/PERFORMANCE_TUNING.md) | Optimization tips |
| [Migration](docs/guides/MIGRATION_GUIDE.md) | Upgrade from older versions |
| [Roadmap](docs/ROADMAP.md) | Future features |

---

## Project Structure

```
pl_fpdf/
├── PL_FPDF.pks          # Package specification
├── PL_FPDF.pkb          # Package body
├── docs/                # Documentation
├── tests/               # Test suite
├── scripts/             # Utility scripts
└── extensions/          # Optional extensions (PIX, Boleto)
```

---

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Follow [coding standards](CONTRIBUTING.md)
4. Add tests
5. Submit Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Credits

- **FPDF (PHP):** Olivier PLATHEY
- **PL/SQL Port:** Anton Scheffer, Pierre-Gilles Levallois
- **Modernization:** Maxwell Oliveira ([@maxwbh](https://github.com/maxwbh))

---

## License

MIT License - see [LICENSE](LICENSE)

---

<p align="center">
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers">Star on GitHub</a> •
  <a href="https://github.com/Maxwbh/pl_fpdf/issues">Report Issue</a> •
  <a href="mailto:maxwbh@gmail.com">Contact</a>
</p>
