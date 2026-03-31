# PL_FPDF Documentation

**Version:** 3.2.0 | **Updated:** 2026-03-30

---

## Quick Start

```sql
-- Install
@deploy_all.sql

-- Create PDF
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

---

## Documentation

| Document | Description |
|----------|-------------|
| [API Reference](api/API_REFERENCE.md) | Complete function reference |
| [Phase 4 Guide](guides/PHASE_4_GUIDE.md) | PDF manipulation (load, watermark, merge) |
| [Migration Guide](guides/MIGRATION_GUIDE.md) | Upgrade from v0.9.4 to v2.0+ |
| [Roadmap](ROADMAP.md) | Version features and planning |

### Architecture

| Document | Description |
|----------|-------------|
| [Package-Only](architecture/PACKAGE_ONLY_ARCHITECTURE.md) | Current architecture |
| [Oracle 19c Compatibility](architecture/ORACLE_19C_COMPATIBILITY_STRATEGY.md) | Database compatibility |

---

## Project Structure

```
pl_fpdf/
├── src/                    # Source code
│   ├── PL_FPDF.pks        # Package spec
│   └── PL_FPDF.pkb        # Package body
├── extensions/             # Optional (PIX, Boleto)
├── tests/                  # Test scripts
├── docs/                   # Documentation
└── deploy_all.sql          # Main deploy script
```

---

## Features by Version

| Version | Features |
|---------|----------|
| **3.2.0** | RC4 encryption, permissions, decryption |
| **3.0.0** | PDF manipulation, merge, split, watermark |
| **2.0.0** | UTF-8, TrueType, QR Code, Barcode |

---

## Support

- **Author:** Maxwell da Silva Oliveira (@maxwbh)
- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues)
