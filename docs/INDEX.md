# PL_FPDF Documentation Index

**Version:** 3.0.0+
**Last Updated:** 2026-03-01

---

## Quick Navigation

| Need | Document |
|------|----------|
| Get started quickly | [Quick Start](#quick-start) |
| API reference | [API Reference](api/API_REFERENCE.md) |
| Manipulate PDFs | [Phase 4 Guide](guides/PHASE_4_GUIDE.md) |
| Upgrade from v0.9.4 | [Migration Guide](guides/MIGRATION_GUIDE.md) |
| Optimize performance | [Performance Tuning](guides/PERFORMANCE_TUNING.md) |
| See roadmap | [Roadmap](ROADMAP.md) |
| See all TODOs | [TODO Master](TODO_MASTER.md) |

---

## Documentation Structure

```
docs/
├── INDEX.md                    # This file - start here
├── ROADMAP.md                  # Feature roadmap (all versions)
├── TODO_MASTER.md              # Consolidated TODO list
├── TODO_V4.md                  # v4.0.0 detailed tasks
├── ARCHITECTURE_MODERN.md      # Modern Oracle features
│
├── api/
│   └── API_REFERENCE.md        # Complete API documentation
│
├── guides/
│   ├── PHASE_4_GUIDE.md        # PDF manipulation guide
│   ├── MIGRATION_GUIDE.md      # Upgrade guide
│   ├── PERFORMANCE_TUNING.md   # Optimization tips
│   └── VALIDATION_GUIDE.md     # Input validation
│
├── architecture/
│   ├── PACKAGE_ONLY_ARCHITECTURE.md    # Core architecture
│   ├── ORACLE_19C_COMPATIBILITY_STRATEGY.md  # Oracle compatibility
│   └── MODERNIZATION_ORACLE_26_APEX_24_2.md  # Future modernization
│
├── plans/
│   └── PHASE_5_IMPLEMENTATION_PLAN.md  # Phase 5 planning
│
├── en/
│   └── README.md               # English documentation
│
└── pt-br/
    └── README.md               # Portuguese documentation
```

---

## Quick Start

### Installation

```sql
-- 1. Install package (2 files only)
@PL_FPDF.pks
@PL_FPDF.pkb

-- 2. Verify installation
SELECT PL_FPDF.GetVersion() FROM DUAL;
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

### Modify PDF

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
  l_merged := PL_FPDF.MergePDFs('doc1,doc2');
END;
```

---

## Document Descriptions

### Core Documentation

| Document | Description | Audience |
|----------|-------------|----------|
| [API Reference](api/API_REFERENCE.md) | Complete API with all functions, parameters, examples | Developers |
| [Roadmap](ROADMAP.md) | Feature plans for all versions (v2.0 - v4.0) | All |
| [TODO Master](TODO_MASTER.md) | Consolidated task list with priorities | Contributors |

### Guides

| Document | Description | Audience |
|----------|-------------|----------|
| [Phase 4 Guide](guides/PHASE_4_GUIDE.md) | PDF manipulation: parse, edit, merge, split | Developers |
| [Migration Guide](guides/MIGRATION_GUIDE.md) | Upgrade from v0.9.4 to v2.0+ | Developers |
| [Performance Tuning](guides/PERFORMANCE_TUNING.md) | Optimization for large PDFs, batches | DBAs, Developers |
| [Validation Guide](guides/VALIDATION_GUIDE.md) | Input validation patterns | Developers |

### Architecture

| Document | Description | Audience |
|----------|-------------|----------|
| [Package-Only Architecture](architecture/PACKAGE_ONLY_ARCHITECTURE.md) | Atual: sem tabelas/tipos externos | Architects |
| [Modular Hybrid Architecture](architecture/MODULAR_HYBRID_ARCHITECTURE.md) | **PDF 2.0**: packages modulares | Architects |
| [Enterprise Architecture](architecture/PDF20_ENTERPRISE_ARCHITECTURE.md) | **PDF 2.0**: tabelas, tipos, REST | Architects, DBAs |
| [Oracle 19c Compatibility](architecture/ORACLE_19C_COMPATIBILITY_STRATEGY.md) | Garantia de compatibilidade 19c | Architects, DBAs |
| [Modern Architecture](ARCHITECTURE_MODERN.md) | Features Oracle 19c+ | Architects |
| [Modernization Plan](architecture/MODERNIZATION_ORACLE_26_APEX_24_2.md) | Oracle 26ai integration | Architects |

---

## Version Documentation

### Current Version (v3.0.0)

| Feature | Documentation |
|---------|---------------|
| PDF Generation | [API Reference](api/API_REFERENCE.md) |
| PDF Parsing | [Phase 4 Guide](guides/PHASE_4_GUIDE.md) |
| Page Operations | [Phase 4 Guide](guides/PHASE_4_GUIDE.md) |
| Watermarks | [Phase 4 Guide](guides/PHASE_4_GUIDE.md) |
| Merge/Split | [Phase 4 Guide](guides/PHASE_4_GUIDE.md) |

### In Progress (v3.2.0)

| Feature | Documentation |
|---------|---------------|
| Encryption | [Roadmap - v3.2.0](ROADMAP.md#v320---security-) |
| Decryption | [Roadmap - v3.2.0](ROADMAP.md#v320---security-) |

### Planned Versions

| Version | Focus | Documentation |
|---------|-------|---------------|
| v3.1.0 | Page Operations | [Roadmap](ROADMAP.md#v310---page-operations-) |
| v3.3.0 | HTML to PDF | [Roadmap](ROADMAP.md#v330---html-to-pdf-) |
| v3.4.0 | PDF 1.5/1.6 | [Roadmap](ROADMAP.md#v340---pdf-1516-complete-support-) |
| v3.5.0 | PDF 1.7 | [Roadmap](ROADMAP.md#v350---pdf-17-complete-support-) |
| v4.0.0 | PDF 2.0 | [TODO v4.0](TODO_V4.md) |

---

## Feature Matrix

### PDF Generation

| Feature | Status | Version | Docs |
|---------|--------|---------|------|
| Basic text/cells | ✅ | v2.0 | [API](api/API_REFERENCE.md#text-rendering) |
| TrueType fonts | ✅ | v2.0 | [API](api/API_REFERENCE.md#font-management) |
| Images (PNG/JPEG) | ✅ | v2.0 | [API](api/API_REFERENCE.md#image-handling) |
| Shapes/Drawing | ✅ | v2.0 | [API](api/API_REFERENCE.md#graphics--drawing) |
| Barcodes/QR | ✅ | v2.0 | Extensions |
| UTF-8 | ✅ | v2.0 | [API](api/API_REFERENCE.md#initialization--lifecycle) |

### PDF Manipulation

| Feature | Status | Version | Docs |
|---------|--------|---------|------|
| Parse existing PDF | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Rotate pages | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Remove pages | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Watermarks | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Text overlay | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Image overlay | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Merge PDFs | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |
| Split PDF | ✅ | v3.0 | [Phase 4](guides/PHASE_4_GUIDE.md) |

### Security

| Feature | Status | Version | Docs |
|---------|--------|---------|------|
| RC4 40-bit | ✅ | v3.2 | [Roadmap](ROADMAP.md#v320---security-) |
| RC4 128-bit | ✅ | v3.2 | [Roadmap](ROADMAP.md#v320---security-) |
| AES 128-bit | 📋 | v3.2 | [Roadmap](ROADMAP.md#v320---security-) |
| AES 256-bit | 📋 | v3.2 | [Roadmap](ROADMAP.md#v320---security-) |
| Permissions | ✅ | v3.2 | [Roadmap](ROADMAP.md#v320---security-) |
| Decryption | 🚧 | v3.2 | [Roadmap](ROADMAP.md#v320---security-) |

### Future

| Feature | Status | Version | Docs |
|---------|--------|---------|------|
| HTML to PDF | 💡 | v3.3 | [Roadmap](ROADMAP.md#v330---html-to-pdf-) |
| Digital Signatures | 💡 | v4.0 | [TODO v4](TODO_V4.md) |
| PDF/A | 💡 | v4.0 | [TODO v4](TODO_V4.md) |
| PDF/UA | 💡 | v4.0 | [TODO v4](TODO_V4.md) |

---

## Oracle Compatibility

| Oracle Version | Support | Notes |
|----------------|---------|-------|
| **19c** | ✅ Full | Minimum version |
| 21c | ✅ Full | Same as 19c |
| 23ai | ✅ Full | + Optional enhancements |
| 26ai | ✅ Full | + Optional enhancements |

See [Oracle 19c Compatibility](architecture/ORACLE_19C_COMPATIBILITY_STRATEGY.md)

---

## Architecture Principles

1. **Package-Only:** No external tables, types, sequences
2. **Self-Contained:** Zero external dependencies
3. **Oracle 19c:** Always compatible
4. **Simple Deploy:** 2 files only (.pks + .pkb)
5. **Simple Uninstall:** DROP PACKAGE

See [Package-Only Architecture](architecture/PACKAGE_ONLY_ARCHITECTURE.md)

---

## Contributing

### Documentation Standards

1. All docs in Markdown format
2. Code examples tested and working
3. API changes reflected in API_REFERENCE.md
4. New features added to ROADMAP.md

### Code Standards

1. Package-only (no external objects)
2. Oracle 19c compatible
3. Unit tests required
4. Performance benchmarks for changes

See [CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Support

- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Maxwbh/pl_fpdf/discussions)
- **Email:** maxwbh@gmail.com

---

## Related Resources

### External

| Resource | Description |
|----------|-------------|
| [PDF Reference](https://www.adobe.com/devnet/pdf/pdf_reference.html) | Adobe PDF specification |
| [ISO 32000-1](https://www.iso.org/standard/51502.html) | PDF 1.7 standard |
| [ISO 32000-2](https://www.iso.org/standard/75839.html) | PDF 2.0 standard |
| [Oracle DBMS_CRYPTO](https://docs.oracle.com/en/database/) | Oracle crypto package |

### Original Projects

| Project | Description |
|---------|-------------|
| [FPDF (PHP)](http://www.fpdf.org/) | Original FPDF library |
| [Anton Scheffer's PL/SQL](http://technology.amis.nl/) | Initial PL/SQL port |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-03-01 | Created centralized documentation index |
| 2026-02-28 | Added v4.0.0 documentation |
| 2026-02 | v3.0.0 documentation complete |
