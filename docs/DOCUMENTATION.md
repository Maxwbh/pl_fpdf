# PL_FPDF Documentation

**Version:** 3.2.0 | **Oracle:** 19c+ | **License:** MIT

> PDF generation and manipulation library for Oracle PL/SQL

---

## Quick Start

```sql
-- Install
@deploy_all.sql

-- Verify
SELECT PL_FPDF.co_version FROM DUAL;  -- 3.2.0
```

### Create PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Hello World!', '0', 1, 'C');
  l_pdf := PL_FPDF.Output_Blob;
END;
```

### Modify Existing PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documents WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
  PL_FPDF.AddWatermark('CONFIDENTIAL', p_opacity => 0.3);
  PL_FPDF.RotatePage(1, 90);
  l_pdf := PL_FPDF.OutputModifiedPDF;
END;
```

### Encrypt PDF

```sql
l_encrypted := PL_FPDF.EncryptPDF(
  p_pdf            => l_pdf,
  p_user_password  => 'user123',
  p_owner_password => 'owner456',
  p_encryption     => 'RC4-128'
);
```

### Merge PDFs

```sql
PL_FPDF.LoadPDFWithID(l_pdf1, 'doc1');
PL_FPDF.LoadPDFWithID(l_pdf2, 'doc2');
l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["doc1","doc2"]'));
```

---

## API Reference

### Initialization

| Function | Description |
|----------|-------------|
| `Init(orientation, unit, format)` | Initialize PDF engine |
| `Reset` | Clear and reset state |
| `IsInitialized` | Check if initialized |

### Pages

| Function | Description |
|----------|-------------|
| `AddPage(orientation, format)` | Add new page |
| `SetPage(n)` | Set current page |
| `PageNo` | Get current page number |
| `GetPageCount` | Total pages |

### Content

| Function | Description |
|----------|-------------|
| `SetFont(family, style, size)` | Set font |
| `Cell(w, h, txt, border, ln, align)` | Add cell |
| `MultiCell(w, h, txt, border, align)` | Multi-line cell |
| `Write(h, txt, link)` | Write text |
| `Ln(h)` | Line break |
| `Text(x, y, txt)` | Text at position |

### Graphics

| Function | Description |
|----------|-------------|
| `Line(x1, y1, x2, y2)` | Draw line |
| `Rect(x, y, w, h, style)` | Draw rectangle |
| `SetDrawColor(r, g, b)` | Line color |
| `SetFillColor(r, g, b)` | Fill color |
| `SetTextColor(r, g, b)` | Text color |

### Images

| Function | Description |
|----------|-------------|
| `Image(file, x, y, w, h)` | Add image |
| `ImageBlob(blob, x, y, w, h, type)` | Add image from BLOB |

### PDF Manipulation (v3.0+)

| Function | Description |
|----------|-------------|
| `LoadPDF(blob)` | Load existing PDF |
| `GetPageInfo(n)` | Page info as JSON |
| `RotatePage(n, degrees)` | Rotate page |
| `RemovePage(n)` | Remove page |
| `AddWatermark(text, opacity)` | Add watermark |
| `OverlayText(page, x, y, text)` | Add text overlay |
| `OverlayImage(page, x, y, blob)` | Add image overlay |
| `OutputModifiedPDF` | Save changes |

### Multi-Document (v3.0+)

| Function | Description |
|----------|-------------|
| `LoadPDFWithID(blob, id)` | Load with identifier |
| `MergePDFs(json_array)` | Merge multiple PDFs |
| `SplitPDF(id, ranges)` | Split into parts |
| `ExtractPages(id, pages)` | Extract pages |
| `UnloadPDF(id)` | Remove from memory |

### Security (v3.2+)

| Function | Description |
|----------|-------------|
| `SetEncryption(method, user_pwd, owner_pwd)` | Set encryption for new PDF |
| `SetPermissions(print, copy, modify...)` | Set permissions |
| `EncryptPDF(blob, user_pwd, owner_pwd)` | Encrypt existing PDF |
| `DecryptPDF(blob, password)` | Remove encryption |
| `IsEncrypted(blob)` | Check if encrypted |
| `GetSecurityInfo(blob)` | Get security details |
| `SetPDFVersion(version)` | Set PDF version (1.4-2.0) |

### Output

| Function | Description |
|----------|-------------|
| `Output_Blob` | Get PDF as BLOB |
| `Output_Clob` | Get PDF as CLOB |
| `GetBuffer` | Get raw buffer |

---

## Version History

| Version | Date | Features |
|---------|------|----------|
| **3.2.0** | Jul 2026 | RC4 encryption, permissions, decryption |
| **3.0.0** | Feb 2026 | PDF manipulation, merge, split, watermark |
| **2.0.0** | Dec 2025 | UTF-8, TrueType, QR Code, Barcode |

See **[ROADMAP.md](ROADMAP.md)** for planned versions and TODOs.

---

## Error Codes

| Code | Description |
|------|-------------|
| -20001 | Invalid orientation |
| -20002 | Invalid unit |
| -20003 | Unsupported encoding |
| -20010 | Not initialized |
| -20020 | Invalid page number |
| -20030 | Font not found |
| -20040 | Image error |
| -20800 | PDF not loaded |
| -20850 | Invalid encryption method |
| -20851 | Invalid password |
| -20852 | Encryption failed |

---

## Architecture

### Package-Only Design

- **No external objects** - All in PL_FPDF package
- **No tables** - Session-based state
- **Oracle 19c minimum** - Uses DBMS_CRYPTO, JSON
- **Single deployment** - Just .pks and .pkb files

### File Structure

```
pl_fpdf/
├── src/
│   ├── PL_FPDF.pks     # Specification
│   └── PL_FPDF.pkb     # Body
├── extensions/          # Optional (PIX, Boleto)
├── tests/              # Test suite
└── deploy_all.sql      # Main deploy
```

---

## Migration from v0.9.4

### Breaking Changes

```sql
-- OLD (v0.9.4)
PL_FPDF.FPDF('P', 'mm', 'A4');
l_pdf := PL_FPDF.Output('S');

-- NEW (v2.0+)
PL_FPDF.Init('P', 'mm', 'A4');
l_pdf := PL_FPDF.Output_Blob;
```

### Key Differences

| v0.9.4 | v2.0+ |
|--------|-------|
| `FPDF()` | `Init()` |
| `Output('S')` | `Output_Blob` |
| `Output('F', path)` | Use UTL_FILE separately |
| Limited UTF-8 | Full UTF-8 |
| No encryption | RC4/AES encryption |

---

## Support

- **Author:** Maxwell da Silva Oliveira (@maxwbh)
- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues)
- **Email:** maxwbh@gmail.com
