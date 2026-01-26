# PL_FPDF Package-Only Architecture

**Version:** 3.0.0-b.2
**Date:** 2026-01
**Priority:** 🔴 CRITICAL REQUIREMENT

---

## 📋 Executive Summary

**PL_FPDF is a 100% self-contained PL/SQL package with ZERO external dependencies.**

### Core Principles

1. ✅ **No External Tables:** All data is managed within package collections
2. ✅ **No External Types:** All types defined in package specification
3. ✅ **No External Objects:** No views, sequences, jobs, or other schema objects
4. ✅ **Single Package Deployment:** Deploy PL_FPDF.pks + PL_FPDF.pkb only
5. ✅ **Oracle 19c Compatible:** All features work on Oracle 19c without external dependencies

**This architecture ensures:**
- ✅ Simple deployment (2 files only)
- ✅ No schema pollution
- ✅ Easy uninstall (DROP PACKAGE)
- ✅ Portable across schemas
- ✅ No privilege requirements beyond CREATE PROCEDURE

---

## 🏗️ Current Architecture (Correct)

### Package Structure

```
PL_FPDF Package
├── PL_FPDF.pks (Specification)
│   ├── Public Types
│   ├── Public Constants
│   └── Public Procedures/Functions
│
└── PL_FPDF.pkb (Body)
    ├── Private Types (package-level)
    ├── Private Constants
    ├── Private Variables (cache/state)
    ├── Private Procedures/Functions
    └── Public Procedures/Functions Implementation
```

### All Types are Package Types

```sql
-- PL_FPDF.pks (PUBLIC types visible to users)
CREATE OR REPLACE PACKAGE PL_FPDF AS

  -- Public types for user interaction
  SUBTYPE word IS VARCHAR2(80);

  TYPE tv4000a IS TABLE OF VARCHAR2(4000) INDEX BY word;

  TYPE point IS RECORD (x NUMBER, y NUMBER);

  TYPE tab_points IS TABLE OF point INDEX BY PLS_INTEGER;

  TYPE recImageBlob IS RECORD (
    mime_type VARCHAR2(100),
    file_format VARCHAR2(10),
    width NUMBER,
    height NUMBER,
    blob_content BLOB
  );

END PL_FPDF;
```

```sql
-- PL_FPDF.pkb (PRIVATE types for internal use)
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Internal cache types (NOT visible outside)
  TYPE xref_entry_rec IS RECORD (
    offset PLS_INTEGER,
    generation PLS_INTEGER,
    in_use BOOLEAN
  );

  TYPE xref_table_type IS TABLE OF xref_entry_rec INDEX BY PLS_INTEGER;

  TYPE page_info_rec IS RECORD (
    page_obj_id PLS_INTEGER,
    media_box VARCHAR2(100),
    rotate NUMBER
  );

  TYPE page_info_table IS TABLE OF page_info_rec INDEX BY PLS_INTEGER;

  -- Package-level variables (session-persistent cache)
  g_xref_table xref_table_type;
  g_page_info_table page_info_table;
  g_loaded_pdf BLOB;

  -- All implementation code...

END PL_FPDF;
```

---

## ✅ Correct Patterns (Package-Only)

### 1. Configuration Management

**❌ WRONG (External Table):**
```sql
-- Don't do this!
CREATE TABLE pl_fpdf_config (
  config_key VARCHAR2(100),
  config_value VARCHAR2(4000)
);
```

**✅ CORRECT (Package Constants/Variables):**
```sql
-- PL_FPDF.pkb
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Configuration as package constants
  c_max_loaded_pdfs CONSTANT PLS_INTEGER := 10;
  c_default_font CONSTANT VARCHAR2(50) := 'Arial';
  c_default_font_size CONSTANT NUMBER := 12;
  c_cache_enabled CONSTANT BOOLEAN := TRUE;

  -- Or configurable via package variables
  g_debug_mode BOOLEAN := FALSE;
  g_compression_level PLS_INTEGER := 6;

  -- Configuration setters
  PROCEDURE set_debug_mode(p_enabled BOOLEAN) IS
  BEGIN
    g_debug_mode := p_enabled;
  END set_debug_mode;

  PROCEDURE set_compression_level(p_level PLS_INTEGER) IS
  BEGIN
    IF p_level BETWEEN 0 AND 9 THEN
      g_compression_level := p_level;
    END IF;
  END set_compression_level;

END PL_FPDF;
```

### 2. Caching Strategy

**❌ WRONG (External Table):**
```sql
-- Don't do this!
CREATE TABLE pdf_cache (
  pdf_id VARCHAR2(50),
  pdf_blob BLOB,
  is_modified VARCHAR2(1)
);
```

**✅ CORRECT (Package Collections):**
```sql
-- PL_FPDF.pkb
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- In-memory cache using associative arrays
  TYPE pdf_document_rec IS RECORD (
    pdf_id VARCHAR2(50),
    pdf_blob BLOB,
    page_count PLS_INTEGER,
    loaded_date TIMESTAMP,
    is_modified BOOLEAN
  );

  TYPE pdf_collection IS TABLE OF pdf_document_rec INDEX BY VARCHAR2(50);

  -- Session-persistent cache
  g_loaded_pdfs pdf_collection;
  g_loaded_pdf_count PLS_INTEGER := 0;

  -- Cache management
  PROCEDURE cache_pdf(p_id VARCHAR2, p_blob BLOB) IS
    l_doc pdf_document_rec;
  BEGIN
    l_doc.pdf_id := p_id;
    l_doc.pdf_blob := p_blob;
    l_doc.loaded_date := SYSTIMESTAMP;
    l_doc.is_modified := FALSE;

    g_loaded_pdfs(p_id) := l_doc;
    g_loaded_pdf_count := g_loaded_pdfs.COUNT;
  END cache_pdf;

  FUNCTION get_cached_pdf(p_id VARCHAR2) RETURN BLOB IS
  BEGIN
    IF g_loaded_pdfs.EXISTS(p_id) THEN
      RETURN g_loaded_pdfs(p_id).pdf_blob;
    ELSE
      RETURN NULL;
    END IF;
  END get_cached_pdf;

  PROCEDURE clear_cache IS
  BEGIN
    g_loaded_pdfs.DELETE;
    g_loaded_pdf_count := 0;
  END clear_cache;

END PL_FPDF;
```

### 3. Feature Flags / Settings

**❌ WRONG (External Table):**
```sql
-- Don't do this!
CREATE TABLE pl_fpdf_features (
  feature_name VARCHAR2(100),
  is_enabled VARCHAR2(1)
);
```

**✅ CORRECT (Package Variables with Getters/Setters):**
```sql
-- PL_FPDF.pkb
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Feature flags as package variables
  g_enable_compression BOOLEAN := TRUE;
  g_enable_encryption BOOLEAN := FALSE;
  g_enable_bookmarks BOOLEAN := TRUE;
  g_auto_detect_oracle_version BOOLEAN := TRUE;

  -- Public API for feature management
  PROCEDURE enable_feature(p_feature VARCHAR2) IS
  BEGIN
    CASE UPPER(p_feature)
      WHEN 'COMPRESSION' THEN g_enable_compression := TRUE;
      WHEN 'ENCRYPTION' THEN g_enable_encryption := TRUE;
      WHEN 'BOOKMARKS' THEN g_enable_bookmarks := TRUE;
      WHEN 'AUTO_DETECT' THEN g_auto_detect_oracle_version := TRUE;
      ELSE NULL;
    END CASE;
  END enable_feature;

  PROCEDURE disable_feature(p_feature VARCHAR2) IS
  BEGIN
    CASE UPPER(p_feature)
      WHEN 'COMPRESSION' THEN g_enable_compression := FALSE;
      WHEN 'ENCRYPTION' THEN g_enable_encryption := FALSE;
      WHEN 'BOOKMARKS' THEN g_enable_bookmarks := FALSE;
      WHEN 'AUTO_DETECT' THEN g_auto_detect_oracle_version := FALSE;
      ELSE NULL;
    END CASE;
  END disable_feature;

  FUNCTION is_feature_enabled(p_feature VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    CASE UPPER(p_feature)
      WHEN 'COMPRESSION' THEN RETURN g_enable_compression;
      WHEN 'ENCRYPTION' THEN RETURN g_enable_encryption;
      WHEN 'BOOKMARKS' THEN RETURN g_enable_bookmarks;
      WHEN 'AUTO_DETECT' THEN RETURN g_auto_detect_oracle_version;
      ELSE RETURN FALSE;
    END CASE;
  END is_feature_enabled;

END PL_FPDF;
```

### 4. Metadata Storage

**❌ WRONG (External Table):**
```sql
-- Don't do this!
CREATE TABLE pdf_metadata (
  pdf_id VARCHAR2(50),
  page_count NUMBER,
  file_size NUMBER
);
```

**✅ CORRECT (Part of Cached Document Record):**
```sql
-- PL_FPDF.pkb
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Metadata is part of the document record
  TYPE pdf_document_rec IS RECORD (
    pdf_id VARCHAR2(50),
    pdf_blob BLOB,
    page_count PLS_INTEGER,
    file_size NUMBER,
    pdf_version VARCHAR2(10),
    created_date TIMESTAMP,
    -- All metadata in ONE record
    xref_offset PLS_INTEGER,
    root_obj_id PLS_INTEGER,
    is_encrypted BOOLEAN,
    encryption_level VARCHAR2(20)
  );

  -- Single collection holds everything
  TYPE pdf_collection IS TABLE OF pdf_document_rec INDEX BY VARCHAR2(50);
  g_loaded_pdfs pdf_collection;

  -- Metadata queries work on collection
  FUNCTION get_pdf_metadata(p_id VARCHAR2) RETURN JSON_OBJECT_T IS
    l_result JSON_OBJECT_T;
    l_doc pdf_document_rec;
  BEGIN
    IF NOT g_loaded_pdfs.EXISTS(p_id) THEN
      RETURN NULL;
    END IF;

    l_doc := g_loaded_pdfs(p_id);
    l_result := JSON_OBJECT_T();
    l_result.put('pdf_id', l_doc.pdf_id);
    l_result.put('page_count', l_doc.page_count);
    l_result.put('file_size', l_doc.file_size);
    l_result.put('pdf_version', l_doc.pdf_version);
    l_result.put('is_encrypted', CASE WHEN l_doc.is_encrypted THEN 'Y' ELSE 'N' END);

    RETURN l_result;
  END get_pdf_metadata;

END PL_FPDF;
```

---

## 🚫 Anti-Patterns (What NOT to Do)

### 1. External Types (Oracle 23ai+ Only Anyway)

**❌ WRONG:**
```sql
-- Don't create schema-level types!
CREATE OR REPLACE TYPE pdf_page_obj AS OBJECT (
  page_number NUMBER,
  content CLOB
);

CREATE OR REPLACE TYPE pdf_page_table AS TABLE OF pdf_page_obj;
```

**Problem:**
- Requires extra privileges
- Schema pollution
- Harder to drop/recreate
- Not self-contained

**✅ CORRECT:**
```sql
-- Keep types inside package
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  TYPE pdf_page_rec IS RECORD (
    page_number PLS_INTEGER,
    content CLOB
  );

  TYPE pdf_page_table IS TABLE OF pdf_page_rec INDEX BY PLS_INTEGER;

END PL_FPDF;
```

### 2. External Tables for Logging

**❌ WRONG:**
```sql
-- Don't create log tables!
CREATE TABLE pl_fpdf_log (
  log_id NUMBER,
  log_date TIMESTAMP,
  log_message VARCHAR2(4000)
);
```

**✅ CORRECT (Use DBMS_OUTPUT or raise exceptions):**
```sql
-- PL_FPDF.pkb
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Use DBMS_OUTPUT for debugging
  PROCEDURE log_debug(p_message VARCHAR2) IS
  BEGIN
    IF g_debug_mode THEN
      DBMS_OUTPUT.PUT_LINE('[DEBUG] ' || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3') || ' - ' || p_message);
    END IF;
  END log_debug;

  -- Or store recent logs in memory
  TYPE log_entry_rec IS RECORD (
    log_date TIMESTAMP,
    log_level VARCHAR2(10),
    log_message VARCHAR2(4000)
  );

  TYPE log_buffer_type IS TABLE OF log_entry_rec INDEX BY PLS_INTEGER;
  g_log_buffer log_buffer_type;
  g_max_log_entries CONSTANT PLS_INTEGER := 100;

  PROCEDURE add_log(p_level VARCHAR2, p_message VARCHAR2) IS
    l_entry log_entry_rec;
    l_next_id PLS_INTEGER;
  BEGIN
    l_entry.log_date := SYSTIMESTAMP;
    l_entry.log_level := p_level;
    l_entry.log_message := p_message;

    l_next_id := NVL(g_log_buffer.LAST, 0) + 1;
    g_log_buffer(l_next_id) := l_entry;

    -- Keep only last N entries
    IF g_log_buffer.COUNT > g_max_log_entries THEN
      g_log_buffer.DELETE(g_log_buffer.FIRST);
    END IF;
  END add_log;

  FUNCTION get_recent_logs RETURN JSON_ARRAY_T IS
    l_result JSON_ARRAY_T;
    l_entry JSON_OBJECT_T;
    l_id PLS_INTEGER;
  BEGIN
    l_result := JSON_ARRAY_T();
    l_id := g_log_buffer.FIRST;

    WHILE l_id IS NOT NULL LOOP
      l_entry := JSON_OBJECT_T();
      l_entry.put('timestamp', TO_CHAR(g_log_buffer(l_id).log_date, 'YYYY-MM-DD HH24:MI:SS.FF3'));
      l_entry.put('level', g_log_buffer(l_id).log_level);
      l_entry.put('message', g_log_buffer(l_id).log_message);
      l_result.append(l_entry);

      l_id := g_log_buffer.NEXT(l_id);
    END LOOP;

    RETURN l_result;
  END get_recent_logs;

END PL_FPDF;
```

### 3. External Sequences

**❌ WRONG:**
```sql
-- Don't create sequences!
CREATE SEQUENCE pdf_id_seq START WITH 1;
```

**✅ CORRECT (Use package counter):**
```sql
-- PL_FPDF.pkb
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Package-level counter
  g_pdf_id_counter PLS_INTEGER := 0;

  FUNCTION get_next_pdf_id RETURN VARCHAR2 IS
  BEGIN
    g_pdf_id_counter := g_pdf_id_counter + 1;
    RETURN 'PDF_' || LPAD(g_pdf_id_counter, 8, '0');
  END get_next_pdf_id;

  -- Or use timestamp-based IDs
  FUNCTION generate_unique_id RETURN VARCHAR2 IS
  BEGIN
    RETURN 'PDF_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF6');
  END generate_unique_id;

END PL_FPDF;
```

---

## 📦 Deployment Strategy

### Single-File Deployment

```bash
# Deploy PL_FPDF (only 2 files needed)
sqlplus user/pass@db <<EOF
@PL_FPDF.pks
@PL_FPDF.pkb
EOF
```

### Complete Install Script

```sql
-- install_pl_fpdf.sql
SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT ================================================================================
PROMPT Installing PL_FPDF - Self-Contained PDF Generator
PROMPT ================================================================================
PROMPT

-- Check Oracle version
DECLARE
  l_version NUMBER;
BEGIN
  SELECT TO_NUMBER(SUBSTR(version, 1, 2)) INTO l_version FROM v$instance;

  IF l_version < 19 THEN
    RAISE_APPLICATION_ERROR(-20000, 'Oracle 19c or higher required. Current version: ' || l_version);
  END IF;

  DBMS_OUTPUT.PUT_LINE('Oracle version: ' || l_version || 'c (Compatible)');
END;
/

PROMPT
PROMPT Compiling package specification...
@@PL_FPDF.pks

PROMPT
PROMPT Compiling package body...
@@PL_FPDF.pkb

-- Verify installation
DECLARE
  l_status VARCHAR2(10);
  l_errors NUMBER;
BEGIN
  SELECT status INTO l_status
  FROM user_objects
  WHERE object_name = 'PL_FPDF' AND object_type = 'PACKAGE';

  IF l_status != 'VALID' THEN
    SELECT COUNT(*) INTO l_errors
    FROM user_errors
    WHERE name = 'PL_FPDF';

    RAISE_APPLICATION_ERROR(-20001, 'Package compilation failed. ' || l_errors || ' errors found.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF Status: ' || l_status);
  DBMS_OUTPUT.PUT_LINE('Version: ' || PL_FPDF.GetVersion());
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Installation complete!');
END;
/

PROMPT
PROMPT ================================================================================
PROMPT Installation Summary
PROMPT ================================================================================
PROMPT Objects created:
PROMPT   - PACKAGE PL_FPDF (specification)
PROMPT   - PACKAGE BODY PL_FPDF (body)
PROMPT
PROMPT No tables, types, or other schema objects created.
PROMPT Package is 100% self-contained.
PROMPT ================================================================================
```

### Uninstall Script

```sql
-- uninstall_pl_fpdf.sql
SET SERVEROUTPUT ON

PROMPT ================================================================================
PROMPT Uninstalling PL_FPDF
PROMPT ================================================================================

-- Drop package (that's it!)
DROP PACKAGE PL_FPDF;

PROMPT
PROMPT PL_FPDF uninstalled successfully.
PROMPT No other objects to clean up.
PROMPT ================================================================================
```

---

## 🔒 Oracle 19c Compatibility

### Feature Detection (Package-Only)

```sql
-- PL_FPDF.pkb - All detection within package
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Package-level version detection
  g_oracle_version NUMBER;
  g_supports_domains BOOLEAN := FALSE;
  g_supports_boolean_type BOOLEAN := FALSE;

  PROCEDURE detect_oracle_version IS
    l_version VARCHAR2(100);
  BEGIN
    -- Detect at package initialization
    SELECT version INTO l_version FROM v$instance;
    g_oracle_version := TO_NUMBER(SUBSTR(l_version, 1, 2));

    -- Set feature flags
    IF g_oracle_version >= 23 THEN
      g_supports_domains := check_domains_available();
      g_supports_boolean_type := TRUE;
    ELSE
      g_supports_domains := FALSE;
      g_supports_boolean_type := FALSE;
    END IF;
  END detect_oracle_version;

  FUNCTION check_domains_available RETURN BOOLEAN IS
    l_count NUMBER;
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM user_domains' INTO l_count;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END check_domains_available;

BEGIN
  -- Initialize on package load
  detect_oracle_version();
END PL_FPDF;
```

### No External Dependencies for Fallbacks

```sql
-- PL_FPDF.pkb - Validation without external objects
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- All validation functions in package
  FUNCTION validate_opacity(p_value NUMBER) RETURN BOOLEAN IS
  BEGIN
    RETURN p_value >= 0 AND p_value <= 1;
  END validate_opacity;

  FUNCTION validate_rotation(p_value NUMBER) RETURN BOOLEAN IS
  BEGIN
    RETURN p_value IN (0, 90, 180, 270);
  END validate_rotation;

  FUNCTION validate_color(p_value VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN p_value IS NULL OR
           REGEXP_LIKE(p_value, '^#[0-9A-Fa-f]{6}$') OR
           REGEXP_LIKE(p_value, '^rgb\(\d{1,3},\d{1,3},\d{1,3}\)$');
  END validate_color;

  FUNCTION validate_page_number(p_value PLS_INTEGER) RETURN BOOLEAN IS
  BEGIN
    RETURN p_value > 0;
  END validate_page_number;

  -- Use in procedures
  PROCEDURE add_watermark(
    p_text VARCHAR2,
    p_opacity NUMBER,
    p_rotation NUMBER
  ) IS
  BEGIN
    -- Validate (works on Oracle 19c without domains)
    IF NOT validate_opacity(p_opacity) THEN
      raise_error(-20821, 'Invalid opacity: must be 0.0-1.0');
    END IF;

    IF NOT validate_rotation(p_rotation) THEN
      raise_error(-20822, 'Invalid rotation: must be 0, 90, 180, or 270');
    END IF;

    -- Proceed...
  END add_watermark;

END PL_FPDF;
```

---

## 📊 Benefits of Package-Only Architecture

### 1. Simplicity

| Aspect | Package-Only | With External Objects |
|--------|-------------|----------------------|
| Deployment | 2 files | 10+ files |
| Privileges | CREATE PROCEDURE | CREATE TABLE, CREATE TYPE, CREATE SEQUENCE |
| Uninstall | DROP PACKAGE | DROP TABLE, DROP TYPE, DROP SEQUENCE, cleanup |
| Schema pollution | None | Multiple objects |
| Dependencies | None | Complex |

### 2. Portability

```sql
-- Move between schemas (easy)
CREATE OR REPLACE PACKAGE other_schema.PL_FPDF AS ...
CREATE OR REPLACE PACKAGE BODY other_schema.PL_FPDF AS ...
-- Done! No need to migrate tables/types
```

### 3. Testability

```sql
-- Test isolation (each session has own cache)
-- Session 1
BEGIN
  PL_FPDF.LoadPDF(l_pdf_1);
  -- Session 1 cache separate
END;

-- Session 2
BEGIN
  PL_FPDF.LoadPDF(l_pdf_2);
  -- Session 2 cache separate
END;
```

### 4. Security

- No sensitive data in tables
- No risk of data leakage between sessions
- No SQL injection risks (no dynamic queries on user tables)
- Everything in package = controlled access

---

## 🎯 Future Enhancements (Still Package-Only)

### Phase 5+ Features (All Self-Contained)

```sql
-- Even advanced features stay package-only
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Phase 5.1: Page operations cache
  TYPE page_operation_rec IS RECORD (
    operation_type VARCHAR2(50),
    source_pdf_id VARCHAR2(50),
    source_page NUMBER,
    target_pdf_id VARCHAR2(50),
    target_page NUMBER,
    executed_date TIMESTAMP
  );

  TYPE operation_history IS TABLE OF page_operation_rec INDEX BY PLS_INTEGER;
  g_operation_history operation_history;

  -- Phase 5.5: Batch processing queue
  TYPE batch_job_rec IS RECORD (
    job_id VARCHAR2(50),
    pdf_ids JSON_ARRAY_T,
    operations JSON_ARRAY_T,
    status VARCHAR2(20),
    created_date TIMESTAMP
  );

  TYPE batch_queue IS TABLE OF batch_job_rec INDEX BY VARCHAR2(50);
  g_batch_queue batch_queue;

  -- Phase 5.6: Bookmark cache
  TYPE bookmark_rec IS RECORD (
    bookmark_id VARCHAR2(50),
    pdf_id VARCHAR2(50),
    title VARCHAR2(500),
    page_number PLS_INTEGER,
    parent_id VARCHAR2(50),
    level PLS_INTEGER
  );

  TYPE bookmark_tree IS TABLE OF bookmark_rec INDEX BY VARCHAR2(50);
  g_bookmarks bookmark_tree;

  -- All features managed in-memory, no external storage

END PL_FPDF;
```

---

## ✅ Verification Checklist

Use this checklist for all new features:

- [ ] **No CREATE TABLE statements** - All data in package collections
- [ ] **No CREATE TYPE statements** - All types in package specification/body
- [ ] **No CREATE SEQUENCE statements** - Use package counters
- [ ] **No External Dependencies** - Self-contained
- [ ] **Works on Oracle 19c** - No 23ai/26ai requirements
- [ ] **Session-isolated** - Each session has own cache
- [ ] **Simple deployment** - Just .pks and .pkb files
- [ ] **Simple uninstall** - Just DROP PACKAGE
- [ ] **No privileges beyond CREATE PROCEDURE**
- [ ] **All validation in package functions**

---

## 📚 Documentation Standards

### Code Comments

```sql
-- GOOD: Clear about package-only nature
/**
 * PL_FPDF - Self-Contained PDF Generator
 *
 * Architecture: 100% Package-Only
 * - No external tables, types, or objects
 * - All state managed in package variables
 * - Session-isolated caching
 *
 * Oracle Compatibility: 19c+
 * Dependencies: None
 */
```

### API Documentation

```sql
/**
 * LoadPDF - Load PDF into memory cache
 *
 * Storage: Package-level collection (session-persistent)
 * Isolation: Each session has separate cache
 * Limit: Memory-bound (no disk storage)
 *
 * @param p_pdf_blob PDF content to load
 *
 * Note: Cache is cleared when session ends or ClearPDFCache() is called
 */
PROCEDURE LoadPDF(p_pdf_blob BLOB);
```

---

## 🎯 Summary

**PL_FPDF maintains a strict package-only architecture:**

✅ **ALWAYS:**
- Define types in package spec/body
- Use package variables for cache/state
- Keep all logic self-contained
- Deploy only .pks and .pkb files

❌ **NEVER:**
- Create external tables
- Create schema-level types
- Create sequences, views, or other objects
- Depend on external objects

**This ensures:**
- Simple deployment
- Easy maintenance
- Oracle 19c compatibility
- Zero external dependencies
- Clean uninstall

---

**Document Version:** 1.0
**Last Updated:** 2026-01
**Author:** @maxwbh
**Status:** Architectural Standard

**Related Documents:**
- [ORACLE_19C_COMPATIBILITY_STRATEGY.md](ORACLE_19C_COMPATIBILITY_STRATEGY.md)
- [MIGRATION_ROADMAP.md](../roadmaps/MIGRATION_ROADMAP.md)
- [README.md](../../README.md)
