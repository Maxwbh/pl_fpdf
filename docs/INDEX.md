# PL_FPDF Documentation

**Version:** 3.2.0
**Last Updated:** 2026-03-01

---

## Quick Navigation

| Need | Document |
|------|----------|
| Get started | [Quick Start](#quick-start) |
| API reference | [API Reference](api/API_REFERENCE.md) |
| Manipulate PDFs | [Phase 4 Guide](guides/PHASE_4_GUIDE.md) |
| Security features | [Security](#security-encryption) |
| Upgrade from v0.9.4 | [Migration Guide](guides/MIGRATION_GUIDE.md) |
| Optimize performance | [Performance Tuning](guides/PERFORMANCE_TUNING.md) |
| See roadmap | [Roadmap](ROADMAP.md) |
| Architecture | [Architecture](architecture/) |

---

## Project Structure

```
pl_fpdf/
│
├── src/                           # Source Code
│   ├── PL_FPDF.pks               # Package specification
│   └── PL_FPDF.pkb               # Package body
│
├── extensions/                    # Optional Extensions
│   └── brazilian-payments/       # PIX & Boleto support
│       ├── packages/
│       └── tests/
│
├── tests/                         # Test Suite
│   ├── run_all_tests.sql         # Run all tests
│   ├── test_phase_*.sql          # Phase-specific tests
│   └── validate_phase_*.sql      # Validation scripts
│
├── scripts/                       # Utility Scripts
│   ├── optimize_native_compile.sql
│   └── recompile_package.sql
│
├── docs/                          # Documentation
│   ├── INDEX.md                  # This file
│   ├── ROADMAP.md                # Feature roadmap
│   ├── TODO_MASTER.md            # Task tracking
│   ├── api/                      # API documentation
│   ├── guides/                   # User guides
│   ├── architecture/             # Technical architecture
│   └── _archive/                 # Archived documents
│
├── .github/                       # GitHub Templates
│
├── README.md                      # Project overview (EN)
├── README_PT_BR.md               # Project overview (PT)
├── CHANGELOG.md                   # Version history
├── CONTRIBUTING.md                # Contribution guide
├── SECURITY.md                    # Security policy
├── CODE_OF_CONDUCT.md            # Code of conduct
└── deploy_all.sql                # Main deployment script
```

---

## Quick Start

### Installation

```sql
-- Deploy package (run from project root)
@deploy_all.sql

-- Or manually:
@src/PL_FPDF.pks
@src/PL_FPDF.pkb

-- Verify installation
SELECT PL_FPDF.co_version FROM DUAL;
-- Returns: 3.2.0
```

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
  l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["doc1","doc2"]'));
END;
```

---

## Security (Encryption)

### Encrypt PDF with Permissions

```sql
DECLARE
  l_pdf BLOB;
  l_encrypted BLOB;
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  -- Set permissions
  l_perms.put('print', TRUE);
  l_perms.put('copy', FALSE);
  l_perms.put('modify', FALSE);

  -- Encrypt
  l_encrypted := PL_FPDF.EncryptPDF(
    p_pdf            => l_pdf,
    p_user_password  => 'user123',
    p_owner_password => 'owner456',
    p_permissions    => l_perms,
    p_encryption     => 'RC4-128'
  );
END;
```

### Protect During Generation

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetEncryption('RC4-128', 'user123', 'owner456');
  PL_FPDF.SetPermissions(
    p_print  => TRUE,
    p_copy   => FALSE,
    p_modify => FALSE
  );
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Confidential Document');
  l_pdf := PL_FPDF.Output_Blob();
END;
```

### Decrypt PDF

```sql
l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
```

### Check Security Info

```sql
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetSecurityInfo(l_pdf);
  -- Returns: {"encrypted": true, "method": "RC4-128", "permissions": {...}}
END;
```

---

## Version History

| Version | Status | Features |
|---------|--------|----------|
| **3.2.0** | Current | Security (RC4 encryption, permissions, decryption) |
| 3.0.0 | Released | PDF manipulation (load, modify, merge, split, watermark) |
| 2.0.0 | Released | Foundation (UTF-8, TrueType, barcodes, QR codes) |

See [CHANGELOG.md](../CHANGELOG.md) for detailed history.

---

## Documentation Index

### API Reference
- [Complete API Reference](api/API_REFERENCE.md)

### User Guides
- [Phase 4 - PDF Manipulation](guides/PHASE_4_GUIDE.md)
- [Migration Guide](guides/MIGRATION_GUIDE.md)
- [Performance Tuning](guides/PERFORMANCE_TUNING.md)
- [Validation Guide](guides/VALIDATION_GUIDE.md)

### Architecture
- [Package-Only Architecture](architecture/PACKAGE_ONLY_ARCHITECTURE.md)
- [Oracle 19c Compatibility](architecture/ORACLE_19C_COMPATIBILITY_STRATEGY.md)
- [HTML to PDF Architecture](architecture/HTML_TO_PDF_ARCHITECTURE.md) (Planned)
- [PDF 2.0 Enterprise](architecture/PDF20_ENTERPRISE_ARCHITECTURE.md) (Future)
- [Modernization Strategy](architecture/ARCHITECTURE_MODERN.md)

### Planning
- [Roadmap](ROADMAP.md)
- [TODO Master](TODO_MASTER.md)

---

## Support

- **Issues:** [GitHub Issues](https://github.com/maxwbh/pl_fpdf/issues)
- **Discussions:** [GitHub Discussions](https://github.com/maxwbh/pl_fpdf/discussions)
