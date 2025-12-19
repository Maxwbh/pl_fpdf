# Migration Guide: PL_FPDF v0.9.4 → v2.0.0

Complete guide for migrating from PL_FPDF v0.9.4 to v2.0.0.

---

## Overview

PL_FPDF v2.0.0 is a major modernization release targeting Oracle 19c/23c with significant improvements in performance, security, and functionality. While maintaining **backward compatibility** for most common use cases, there are some breaking changes and new best practices.

---

## Quick Summary

| Category | v0.9.4 | v2.0.0 | Action Required |
|----------|--------|--------|-----------------|
| Initialization | `fpdf()` | `Init()` | ⚠️ Recommended |
| Output | `Output()`, `ReturnBlob()` | `OutputBlob()`, `OutputFile()` | ⚠️ Recommended |
| Images | OrdImage-based | BLOB-based (native) | ✅ Auto-migrated |
| UTF-8 | Limited | Full support | ✅ Automatic |
| CLOB Buffers | VARCHAR2 arrays | CLOB | ✅ Automatic |
| Exceptions | Generic `-20100` | Specific exceptions | 🔧 Update handlers |
| JSON Config | Not available | JSON_OBJECT_T | ⭐ New feature |
| Fonts | Core fonts only | TrueType/OpenType | ⭐ New feature |
| Performance | Interpreted | Native compilation | ⭐ 2-3x faster |

**Legend**:
- ✅ Automatic - No changes needed
- ⚠️ Recommended - Still works but update recommended
- 🔧 Update - Changes may be required
- ⭐ New - Optional new features

---

## Breaking Changes

### 1. Oracle Version Requirements

**v0.9.4**: Oracle 11g+
**v2.0.0**: Oracle 19c+ (23c recommended)

**Action**: Upgrade Oracle Database to 19c or higher.

---

### 2. Removed OrdImage Dependencies

**v0.9.4**:
```sql
-- Used ORDSYS.ORDIMAGE (deprecated)
l_img ORDSYS.ORDIMAGE;
```

**v2.0.0**:
```sql
-- Uses native BLOB with recImageBlob type
l_img PL_FPDF.recImageBlob;
```

**Migration**: No action required - image functions now use BLOB automatically.

**Benefits**:
- No external dependencies
- Better performance
- Native PNG/JPEG parsing

---

### 3. Exception Handling

**v0.9.4**:
```sql
-- All errors raised generic exception
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20100 THEN
      -- Handle generic error
    END IF;
END;
```

**v2.0.0**:
```sql
-- Specific exceptions for different error types
EXCEPTION
  WHEN PL_FPDF.exc_font_not_found THEN
    -- Handle font errors (-20201)
  WHEN PL_FPDF.exc_invalid_page_format THEN
    -- Handle page errors (-20101)
  WHEN PL_FPDF.exc_file_write_error THEN
    -- Handle file I/O errors (-20403)
END;
```

**Migration**:
1. Review error handling code
2. Update to use specific exceptions where applicable
3. Keep generic handler for backward compatibility

**Example**:
```sql
-- Old code (still works)
BEGIN
  PL_FPDF.SetFont('NonExistent', '', 12);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;

-- New code (better)
BEGIN
  PL_FPDF.SetFont('NonExistent', '', 12);
EXCEPTION
  WHEN PL_FPDF.exc_font_not_found THEN
    DBMS_OUTPUT.PUT_LINE('Font not found - using default');
    PL_FPDF.SetFont('Arial', '', 12);
  WHEN OTHERS THEN
    RAISE;
END;
```

---

## Deprecated Features (Still Supported)

### 1. `fpdf()` Constructor

**v0.9.4**:
```sql
PL_FPDF.fpdf('P', 'mm', 'A4');
```

**v2.0.0** (Recommended):
```sql
PL_FPDF.Init('P', 'mm', 'A4');
```

**Migration**: Replace `fpdf()` with `Init()`.

**Benefits**:
- UTF-8 encoding parameter
- Better error handling
- CLOB buffer initialization
- Clearer intent

---

### 2. `Output()` and `ReturnBlob()`

**v0.9.4**:
```sql
-- Download via OWA
PL_FPDF.Output('document.pdf', 'D');

-- Get BLOB
l_blob := PL_FPDF.ReturnBlob('document.pdf', 'S');
```

**v2.0.0** (Recommended):
```sql
-- Modern BLOB output (no OWA dependency)
l_blob := PL_FPDF.OutputBlob();

-- Save to file
PL_FPDF.OutputFile('document.pdf', 'PDF_DIR');
```

**Migration**:
1. Replace `ReturnBlob()` with `OutputBlob()`
2. Replace `Output('filename', 'F')` with `OutputFile()`
3. For web output, handle BLOB in your application layer

**Benefits**:
- No OWA/HTP dependencies
- Works in all contexts (web, batch, APEX, etc.)
- Better performance
- Cleaner code

---

## New Features & Enhancements

### 1. UTF-8 Support

**v2.0.0** automatically handles UTF-8:

```sql
PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');  -- UTF-8 enabled by default
PL_FPDF.SetFont('Arial', '', 12);
PL_FPDF.Cell(0, 10, 'São Paulo - Zürich - 北京');  -- Works!
```

**Features**:
- Full UTF-8 character support
- Automatic conversion
- International character sets

---

### 2. TrueType/OpenType Fonts

**v2.0.0** supports custom fonts:

```sql
-- Load from file
PL_FPDF.LoadTTFFromFile('MyFont', 'MyFont.ttf', 'FONTS_DIR', 'UTF-8');

-- Load from BLOB
PL_FPDF.AddTTFFont('MyFont', l_font_blob, 'UTF-8', TRUE);

-- Use custom font
PL_FPDF.SetFont('MyFont', '', 12);
```

---

### 3. JSON Configuration

**v2.0.0** supports JSON-based configuration:

```sql
DECLARE
  l_config JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_config.put('title', 'My Report');
  l_config.put('author', 'John Doe');
  l_config.put('orientation', 'P');
  l_config.put('format', 'A4');
  l_config.put('fontFamily', 'Arial');
  l_config.put('fontSize', 12);

  PL_FPDF.SetDocumentConfig(l_config);
END;
```

**Benefits**:
- Cleaner configuration
- Integration with REST APIs
- Centralized settings

---

### 4. Enhanced Page Management

**v2.0.0** improvements:

```sql
-- Add page with rotation
PL_FPDF.AddPage('P', 'A4', 90);  -- 90° rotation

-- Custom page format
PL_FPDF.AddPage('L', '210,297');  -- Custom width×height

-- Navigate pages
PL_FPDF.SetPage(1);  -- Go back to page 1
l_current := PL_FPDF.GetCurrentPage();

-- Get page info as JSON
l_info := PL_FPDF.GetPageInfo(1);
DBMS_OUTPUT.PUT_LINE('Width: ' || l_info.get_Number('width'));
```

---

### 5. Rotated Text

**v2.0.0** adds text rotation:

```sql
-- Rotated cell
PL_FPDF.CellRotated(50, 10, 'Vertical Text', '1', 0, 'C', 0, '', 90);

-- Rotated write
PL_FPDF.WriteRotated(10, 'Angled Text', '', 45);
```

**Rotation angles**: 0, 90, 180, 270 degrees

---

### 6. CLOB Buffers (Unlimited Size)

**v0.9.4**: Limited by VARCHAR2 arrays
**v2.0.0**: CLOB-based, unlimited document size

```sql
-- Generate 1000+ page documents
FOR i IN 1..1000 LOOP
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Page ' || i);
END LOOP;

l_pdf := PL_FPDF.OutputBlob();  -- No size limits!
```

---

### 7. Native Compilation

**v2.0.0** supports native compilation for 2-3x performance:

```sql
-- One-time setup
@optimize_native_compile.sql

-- Or manually
ALTER PACKAGE PL_FPDF COMPILE PLSQL_CODE_TYPE = NATIVE REUSE SETTINGS;
```

**Performance gains**:
- Init: 50-70% faster
- 100-page doc: 2-3x faster
- Overall: 77% faster

---

### 8. Enhanced Logging

**v2.0.0** adds configurable logging:

```sql
-- Development
PL_FPDF.SetLogLevel(4);  -- DEBUG

-- Production
PL_FPDF.SetLogLevel(0);  -- OFF

-- Check current level
l_level := PL_FPDF.GetLogLevel();
```

---

## Migration Strategies

### Strategy 1: Minimal Changes (Backward Compatible)

**Goal**: Keep existing code working with minimal changes.

**Steps**:
1. Deploy new PL_FPDF package
2. Test existing code - most will work unchanged
3. Gradually adopt new features

**Example**:
```sql
-- Old code - still works!
BEGIN
  PL_FPDF.fpdf('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Hello World');
  PL_FPDF.Output('test.pdf', 'D');
END;
```

**Risk**: Low
**Effort**: Minimal
**Benefits**: Quick migration

---

### Strategy 2: Modernize Gradually

**Goal**: Adopt new features incrementally.

**Phase 1** - Update initialization:
```sql
-- Change from:
PL_FPDF.fpdf('P', 'mm', 'A4');

-- To:
PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
```

**Phase 2** - Update output:
```sql
-- Change from:
l_blob := PL_FPDF.ReturnBlob();

-- To:
l_blob := PL_FPDF.OutputBlob();
```

**Phase 3** - Add exception handling:
```sql
-- Add specific exceptions
EXCEPTION
  WHEN PL_FPDF.exc_font_not_found THEN
    -- Handle
END;
```

**Phase 4** - Enable native compilation:
```sql
@optimize_native_compile.sql
```

**Risk**: Low to Medium
**Effort**: Moderate
**Benefits**: Performance + maintainability

---

### Strategy 3: Full Modernization

**Goal**: Leverage all v2.0 features.

**New Template**:
```sql
DECLARE
  l_pdf BLOB;
  l_config JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  -- Configure via JSON
  l_config.put('title', 'Modern Report');
  l_config.put('author', 'Your Name');
  l_config.put('format', 'A4');

  -- Initialize with modern methods
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  PL_FPDF.SetDocumentConfig(l_config);
  PL_FPDF.SetLogLevel(0);  -- Production mode

  -- Generate content
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Modern PL_FPDF');

  -- Modern output
  l_pdf := PL_FPDF.OutputBlob();

  -- Always cleanup
  PL_FPDF.Reset();

EXCEPTION
  WHEN PL_FPDF.exc_font_not_found THEN
    DBMS_OUTPUT.PUT_LINE('Font error - using default');
  WHEN PL_FPDF.exc_not_initialized THEN
    DBMS_OUTPUT.PUT_LINE('Not initialized');
  WHEN OTHERS THEN
    PL_FPDF.Reset();  -- Cleanup on error
    RAISE;
END;
```

**Risk**: Medium
**Effort**: Higher
**Benefits**: Maximum performance + features

---

## Testing Your Migration

### 1. Functional Testing

```sql
-- Test basic functionality
BEGIN
  PL_FPDF.Init();
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Migration Test');

  DECLARE
    l_pdf BLOB := PL_FPDF.OutputBlob();
  BEGIN
    DBMS_OUTPUT.PUT_LINE('PDF Size: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    IF DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      DBMS_OUTPUT.PUT_LINE('✓ Basic generation works');
    END IF;
  END;

  PL_FPDF.Reset();
END;
/
```

### 2. UTF-8 Testing

```sql
-- Test international characters
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'São Paulo - Zürich - Москва');

  DECLARE
    l_pdf BLOB := PL_FPDF.OutputBlob();
  BEGIN
    IF DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      DBMS_OUTPUT.PUT_LINE('✓ UTF-8 works');
    END IF;
  END;

  PL_FPDF.Reset();
END;
/
```

### 3. Performance Testing

```sql
-- Test large document generation
DECLARE
  l_start TIMESTAMP := SYSTIMESTAMP;
  l_pdf BLOB;
  l_duration NUMBER;
BEGIN
  PL_FPDF.Init();
  PL_FPDF.SetFont('Arial', '', 12);

  FOR i IN 1..100 LOOP
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Page ' || i);
  END LOOP;

  l_pdf := PL_FPDF.OutputBlob();
  l_duration := EXTRACT(SECOND FROM (SYSTIMESTAMP - l_start));

  DBMS_OUTPUT.PUT_LINE('100-page document: ' || l_duration || ' seconds');
  DBMS_OUTPUT.PUT_LINE('PDF Size: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');

  PL_FPDF.Reset();
END;
/
```

### 4. Run Unit Tests

```bash
cd tests
sqlplus user/pass@db @run_all_tests.sql
```

Expected: **87 tests passing**, **>82% coverage**

---

## Common Migration Issues

### Issue 1: "Package not initialized"

**Cause**: Missing `Init()` or `fpdf()` call

**Solution**:
```sql
-- Always initialize first
PL_FPDF.Init();
-- Then use other methods
```

---

### Issue 2: UTF-8 characters not displaying

**Cause**: Encoding not set to UTF-8

**Solution**:
```sql
-- Explicitly set UTF-8
PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
```

---

### Issue 3: Performance slower than expected

**Cause**: Native compilation not enabled

**Solution**:
```sql
-- Enable native compilation
@optimize_native_compile.sql
```

---

### Issue 4: ORA-06502 (numeric or value error)

**Cause**: Large documents hitting VARCHAR2 limits (v0.9.4 issue)

**Solution**: Automatically fixed in v2.0 (CLOB buffers)

---

### Issue 5: File output not working

**Cause**: Using deprecated `Output()` method

**Solution**:
```sql
-- Old
PL_FPDF.Output('file.pdf', 'F');

-- New
PL_FPDF.OutputFile('file.pdf', 'PDF_DIR');
```

---

## Rollback Plan

If migration issues occur:

### Option 1: Keep Both Versions

```sql
-- Rename packages
-- Old version
CREATE OR REPLACE PACKAGE PL_FPDF_OLD AS ...

-- New version
CREATE OR REPLACE PACKAGE PL_FPDF AS ...
```

### Option 2: Version Control

```bash
# Tag before migration
git tag v0.9.4-last

# Deploy v2.0
@deploy_all.sql

# If issues, rollback
git checkout v0.9.4-last
@PL_FPDF.pks
@PL_FPDF.pkb
```

---

## Resources

- **README.md**: Feature overview and quick start
- **API_REFERENCE.md**: Complete API documentation
- **PERFORMANCE_TUNING.md**: Optimization guide
- **VALIDATION_GUIDE.md**: Testing guide
- **tests/**: Unit test suite (87 tests)

---

## Support & Questions

- **Issues**: https://github.com/maxwbh/pl_fpdf/issues
- **Email**: maxwbh@gmail.com
- **LinkedIn**: [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

---

**Last Updated**: December 19, 2025
**Version**: 2.0.0
**Status**: Production Ready ✅
