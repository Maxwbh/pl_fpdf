# Oracle 19c Compatibility Strategy

**Version:** 3.0.0-b.2
**Date:** 2026-01
**Priority:** 🔴 CRITICAL REQUIREMENT

---

## 📋 Executive Summary

**PL_FPDF maintains Oracle 19c compatibility as a CORE REQUIREMENT through all versions, including v4.0.0 and beyond.**

All Oracle 23ai/26ai features are **OPTIONAL** and detected at runtime. The package provides full functionality on Oracle 19c with graceful degradation for advanced features.

**Key Principles:**
- ✅ Oracle 19c is the **minimum supported version** (indefinitely)
- ✅ Oracle 23ai/26ai features are **OPTIONAL enhancements**
- ✅ Runtime feature detection (no compilation errors)
- ✅ Graceful degradation (fallback implementations)
- ✅ Zero performance penalty on Oracle 19c
- ✅ Same API surface across all Oracle versions

**🔴 CRITICAL: Package-Only Architecture**

**PL_FPDF is 100% self-contained.** Examples in this document showing `CREATE TABLE` or `CREATE TYPE` are for illustration of **Oracle 23ai features ONLY**. The actual PL_FPDF implementation:
- ✅ Uses **package collections** instead of tables
- ✅ Defines **types within package** (not schema-level)
- ✅ Deploys with **2 files only** (.pks + .pkb)
- ✅ Has **ZERO external dependencies**

See [PACKAGE_ONLY_ARCHITECTURE.md](PACKAGE_ONLY_ARCHITECTURE.md) for details.

---

## 🎯 Compatibility Requirements

### Mandatory Support Matrix

| Oracle Version | PL_FPDF Support | Status | Notes |
|---------------|-----------------|--------|-------|
| **Oracle 19c** | ✅ Full | **REQUIRED** | Minimum version, all features work |
| Oracle 21c | ✅ Full | Supported | Same as 19c |
| Oracle 23ai | ✅ Full + Enhanced | Supported | Optional advanced features |
| Oracle 26ai | ✅ Full + Enhanced | Supported | Optional advanced features |

**Guarantee:** All PL_FPDF versions (v3.0 through v4.x and beyond) will work on Oracle 19c without degradation of core functionality.

---

## 🔍 Feature Detection Strategy

### 1. Runtime Oracle Version Detection

```sql
-- Package-level Oracle version detection
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Global version information
  g_oracle_version NUMBER;
  g_oracle_release VARCHAR2(100);
  g_supports_domains BOOLEAN := FALSE;
  g_supports_annotations BOOLEAN := FALSE;
  g_supports_boolean_type BOOLEAN := FALSE;
  g_supports_if_exists BOOLEAN := FALSE;
  g_supports_enhanced_json BOOLEAN := FALSE;

  -- Initialize Oracle version detection
  PROCEDURE detect_oracle_features IS
    l_version VARCHAR2(100);
    l_banner VARCHAR2(4000);
  BEGIN
    -- Get Oracle version
    SELECT version INTO l_version FROM v$instance;
    g_oracle_release := l_version;

    -- Parse major version
    g_oracle_version := TO_NUMBER(SUBSTR(l_version, 1, INSTR(l_version, '.') - 1));

    -- Detect features based on version
    IF g_oracle_version >= 23 THEN
      g_supports_domains := check_domain_support();
      g_supports_annotations := TRUE;
      g_supports_boolean_type := TRUE;
      g_supports_if_exists := TRUE;
    END IF;

    IF g_oracle_version >= 26 THEN
      g_supports_enhanced_json := TRUE;
    END IF;

    -- Log detected features
    log_debug('Oracle Version: ' || g_oracle_release);
    log_debug('Domains Support: ' || CASE WHEN g_supports_domains THEN 'YES' ELSE 'NO' END);
    log_debug('Annotations Support: ' || CASE WHEN g_supports_annotations THEN 'YES' ELSE 'NO' END);

  EXCEPTION
    WHEN OTHERS THEN
      -- Default to 19c features only
      g_oracle_version := 19;
      g_supports_domains := FALSE;
      g_supports_annotations := FALSE;
      g_supports_boolean_type := FALSE;
      g_supports_if_exists := FALSE;
      g_supports_enhanced_json := FALSE;
  END detect_oracle_features;

  -- Check if SQL Domains are available
  FUNCTION check_domain_support RETURN BOOLEAN IS
    l_count NUMBER;
  BEGIN
    -- Try to query domain dictionary view
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM user_domains' INTO l_count;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END check_domain_support;

  -- Get Oracle version
  FUNCTION get_oracle_version RETURN NUMBER IS
  BEGIN
    RETURN g_oracle_version;
  END get_oracle_version;

  -- Check if feature is supported
  FUNCTION is_feature_supported(p_feature VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    CASE UPPER(p_feature)
      WHEN 'DOMAINS' THEN RETURN g_supports_domains;
      WHEN 'ANNOTATIONS' THEN RETURN g_supports_annotations;
      WHEN 'BOOLEAN' THEN RETURN g_supports_boolean_type;
      WHEN 'IF_EXISTS' THEN RETURN g_supports_if_exists;
      WHEN 'ENHANCED_JSON' THEN RETURN g_supports_enhanced_json;
      ELSE RETURN FALSE;
    END CASE;
  END is_feature_supported;

BEGIN
  -- Initialize on package load
  detect_oracle_features();
END PL_FPDF;
```

---

### 2. Conditional SQL Execution

```sql
-- Execute SQL with Oracle version detection
PROCEDURE execute_ddl_with_fallback(
  p_sql_23ai VARCHAR2,
  p_sql_19c VARCHAR2
) IS
BEGIN
  IF g_oracle_version >= 23 THEN
    BEGIN
      EXECUTE IMMEDIATE p_sql_23ai;
    EXCEPTION
      WHEN OTHERS THEN
        -- Fallback to 19c version
        log_warning('23ai DDL failed, using 19c fallback: ' || SQLERRM);
        EXECUTE IMMEDIATE p_sql_19c;
    END;
  ELSE
    EXECUTE IMMEDIATE p_sql_19c;
  END IF;
END execute_ddl_with_fallback;

-- Example usage:
BEGIN
  execute_ddl_with_fallback(
    p_sql_23ai => 'CREATE TABLE IF NOT EXISTS temp_pdf (id NUMBER)',
    p_sql_19c  => 'BEGIN
                     EXECUTE IMMEDIATE ''CREATE TABLE temp_pdf (id NUMBER)'';
                   EXCEPTION
                     WHEN OTHERS THEN NULL;
                   END;'
  );
END;
```

---

### 3. Feature-Specific Implementations

#### A. SQL Domains (23ai+) vs Regular Types (19c)

```sql
-- Validation function (works on all versions)
FUNCTION validate_opacity(p_value NUMBER) RETURN BOOLEAN IS
BEGIN
  RETURN p_value >= 0 AND p_value <= 1;
END validate_opacity;

FUNCTION validate_rotation(p_value NUMBER) RETURN BOOLEAN IS
BEGIN
  RETURN p_value IN (0, 90, 180, 270);
END validate_rotation;

-- Use in procedures with explicit validation
PROCEDURE add_watermark(
  p_opacity IN NUMBER,
  p_rotation IN NUMBER
) IS
BEGIN
  -- Manual validation (works on Oracle 19c)
  IF NOT validate_opacity(p_opacity) THEN
    raise_error(-20821, 'Invalid opacity: must be between 0.0 and 1.0');
  END IF;

  IF NOT validate_rotation(p_rotation) THEN
    raise_error(-20822, 'Invalid rotation: must be 0, 90, 180, or 270');
  END IF;

  -- Proceed with operation
  ...
END add_watermark;

-- On Oracle 23ai with domains, validation is automatic
-- On Oracle 19c, validation is manual but functionally identical
```

#### B. BOOLEAN Type (23ai+) vs VARCHAR2 (19c)

```sql
-- Compatibility layer for boolean handling
SUBTYPE boolean_compat IS VARCHAR2(1);

FUNCTION to_boolean(p_value VARCHAR2) RETURN BOOLEAN IS
BEGIN
  RETURN UPPER(p_value) IN ('Y', 'T', '1', 'TRUE', 'YES');
END to_boolean;

FUNCTION from_boolean(p_value BOOLEAN) RETURN VARCHAR2 IS
BEGIN
  RETURN CASE WHEN p_value THEN 'Y' ELSE 'N' END;
END from_boolean;

-- Use consistently
TYPE pdf_cache_rec IS RECORD (
  pdf_id VARCHAR2(50),
  is_modified boolean_compat,  -- Compatible with 19c
  is_encrypted boolean_compat
);

-- In procedures
PROCEDURE mark_modified(p_pdf_id VARCHAR2) IS
BEGIN
  UPDATE pdf_cache
  SET is_modified = 'Y'
  WHERE pdf_id = p_pdf_id;
END mark_modified;

-- Check modified status
FUNCTION is_pdf_modified(p_pdf_id VARCHAR2) RETURN BOOLEAN IS
  l_flag VARCHAR2(1);
BEGIN
  SELECT is_modified INTO l_flag
  FROM pdf_cache
  WHERE pdf_id = p_pdf_id;

  RETURN to_boolean(l_flag);
END is_pdf_modified;
```

#### C. JSON Enhancements (26ai) vs Standard JSON (19c)

```sql
-- Use standard JSON_OBJECT_T (available in 19c)
FUNCTION get_page_info_json(p_page NUMBER) RETURN JSON_OBJECT_T IS
  l_result JSON_OBJECT_T;
BEGIN
  l_result := JSON_OBJECT_T();
  l_result.put('page_number', p_page);
  l_result.put('rotation', get_page_rotation(p_page));

  -- Works on both 19c and 26ai
  RETURN l_result;
END get_page_info_json;

-- Enhanced JSON features (26ai only) with fallback
FUNCTION get_pages_array_enhanced RETURN JSON_ARRAY_T IS
  l_result JSON_ARRAY_T;
  l_page JSON_OBJECT_T;
BEGIN
  IF g_supports_enhanced_json THEN
    -- Oracle 26ai: Use subquery (more efficient)
    EXECUTE IMMEDIATE q'[
      SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
          'page' VALUE page_number,
          'rotation' VALUE rotation
        )
      ) FROM pdf_pages
    ]' INTO l_result;
  ELSE
    -- Oracle 19c: Build manually (works but slower)
    l_result := JSON_ARRAY_T();
    FOR r IN (SELECT page_number, rotation FROM pdf_pages ORDER BY page_number) LOOP
      l_page := JSON_OBJECT_T();
      l_page.put('page', r.page_number);
      l_page.put('rotation', r.rotation);
      l_result.append(l_page);
    END LOOP;
  END IF;

  RETURN l_result;
END get_pages_array_enhanced;
```

#### D. IF EXISTS Syntax (23ai+) vs Exception Handling (19c)

```sql
-- Deployment script with version detection
DECLARE
  l_version NUMBER;
BEGIN
  SELECT TO_NUMBER(SUBSTR(version, 1, 2)) INTO l_version FROM v$instance;

  IF l_version >= 23 THEN
    -- Oracle 23ai+: Use IF EXISTS
    EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS temp_pdf_work';
    EXECUTE IMMEDIATE 'CREATE TABLE IF NOT EXISTS pdf_cache (pdf_id VARCHAR2(50))';
  ELSE
    -- Oracle 19c: Use exception handling
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE temp_pdf_work';
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;

    BEGIN
      EXECUTE IMMEDIATE 'CREATE TABLE pdf_cache (pdf_id VARCHAR2(50))';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -955 THEN  -- Table already exists
          RAISE;
        END IF;
    END;
  END IF;
END;
/
```

---

## 🏗️ Architecture Patterns

### 1. Interface Segregation

```sql
-- Core interface (works on Oracle 19c)
PACKAGE PL_FPDF_CORE AS
  PROCEDURE init(...);
  PROCEDURE add_page(...);
  FUNCTION output_blob RETURN BLOB;
  -- All core PDF operations
END PL_FPDF_CORE;

-- Enhanced features (optional, 23ai/26ai)
PACKAGE PL_FPDF_ENHANCED AS
  -- Uses SQL Domains
  PROCEDURE add_watermark_validated(...);

  -- Uses Annotations
  FUNCTION get_annotated_metadata RETURN JSON_OBJECT_T;

  -- Requires 23ai+
END PL_FPDF_ENHANCED;

-- Main package facade
PACKAGE PL_FPDF AS
  -- Delegates to CORE or ENHANCED based on Oracle version
  PROCEDURE add_watermark(...);
END PL_FPDF;

PACKAGE BODY PL_FPDF AS
  PROCEDURE add_watermark(...) IS
  BEGIN
    IF is_feature_supported('DOMAINS') THEN
      PL_FPDF_ENHANCED.add_watermark_validated(...);
    ELSE
      PL_FPDF_CORE.add_watermark(...);
    END IF;
  END add_watermark;
END PL_FPDF;
```

### 2. Feature Flags

```sql
-- Configuration table
CREATE TABLE pl_fpdf_config (
  config_key VARCHAR2(100) PRIMARY KEY,
  config_value VARCHAR2(4000),
  description VARCHAR2(1000)
);

-- Feature flags
INSERT INTO pl_fpdf_config VALUES (
  'ENABLE_DOMAINS',
  'AUTO',  -- AUTO, FORCE_ON, FORCE_OFF
  'Enable SQL Domains if available'
);

INSERT INTO pl_fpdf_config VALUES (
  'ENABLE_ENHANCED_JSON',
  'AUTO',
  'Enable enhanced JSON features (26ai)'
);

-- Check feature flag
FUNCTION is_feature_enabled(p_feature VARCHAR2) RETURN BOOLEAN IS
  l_config VARCHAR2(100);
BEGIN
  SELECT config_value INTO l_config
  FROM pl_fpdf_config
  WHERE config_key = 'ENABLE_' || UPPER(p_feature);

  CASE l_config
    WHEN 'FORCE_ON' THEN RETURN TRUE;
    WHEN 'FORCE_OFF' THEN RETURN FALSE;
    WHEN 'AUTO' THEN RETURN is_feature_supported(p_feature);
    ELSE RETURN FALSE;
  END CASE;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN FALSE;
END is_feature_enabled;
```

---

## 📦 Deployment Strategy

### 1. Version-Agnostic Deployment

```sql
-- deploy_all.sql (works on Oracle 19c, 21c, 23ai, 26ai)

-- 1. Detect Oracle version
COLUMN oracle_version NEW_VALUE oracle_ver
SELECT TO_NUMBER(SUBSTR(version, 1, 2)) AS oracle_version FROM v$instance;

PROMPT Deploying PL_FPDF on Oracle &oracle_ver

-- 2. Deploy core package (always)
@@PL_FPDF_CORE.pks
@@PL_FPDF_CORE.pkb

-- 3. Deploy enhanced package (if supported)
DECLARE
  l_version NUMBER := &oracle_ver;
BEGIN
  IF l_version >= 23 THEN
    DBMS_OUTPUT.PUT_LINE('Deploying enhanced features (Oracle 23ai+)');
    EXECUTE IMMEDIATE '@PL_FPDF_ENHANCED.pks';
    EXECUTE IMMEDIATE '@PL_FPDF_ENHANCED.pkb';
  ELSE
    DBMS_OUTPUT.PUT_LINE('Skipping enhanced features (Oracle 19c)');
  END IF;
END;
/

-- 4. Deploy main facade (always)
@@PL_FPDF.pks
@@PL_FPDF.pkb

-- 5. Create SQL Domains (if supported)
DECLARE
  l_version NUMBER := &oracle_ver;
BEGIN
  IF l_version >= 23 THEN
    EXECUTE IMMEDIATE '@sql_domains/create_domains.sql';
  END IF;
END;
/

PROMPT PL_FPDF deployed successfully on Oracle &oracle_ver
```

### 2. Testing Across Versions

```sql
-- test_compatibility.sql

SET SERVEROUTPUT ON

DECLARE
  l_version NUMBER;
  l_test_passed BOOLEAN := TRUE;
BEGIN
  -- Detect version
  SELECT TO_NUMBER(SUBSTR(version, 1, 2)) INTO l_version FROM v$instance;

  DBMS_OUTPUT.PUT_LINE('Testing PL_FPDF on Oracle ' || l_version);
  DBMS_OUTPUT.PUT_LINE('----------------------------------------');

  -- Test 1: Basic PDF generation (must work on all versions)
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test PDF');
    DECLARE
      l_pdf BLOB := PL_FPDF.OutputBlob();
    BEGIN
      IF DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Basic PDF generation');
      ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Basic PDF generation');
        l_test_passed := FALSE;
      END IF;
    END;
    PL_FPDF.Reset();
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('[FAIL] Basic PDF generation: ' || SQLERRM);
      l_test_passed := FALSE;
  END;

  -- Test 2: Feature detection
  BEGIN
    IF l_version >= 23 THEN
      IF PL_FPDF.is_feature_supported('DOMAINS') THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] SQL Domains detected');
      ELSE
        DBMS_OUTPUT.PUT_LINE('[WARN] SQL Domains not detected (expected on 23ai+)');
      END IF;
    ELSE
      IF NOT PL_FPDF.is_feature_supported('DOMAINS') THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] SQL Domains correctly disabled on 19c');
      ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] SQL Domains incorrectly enabled on 19c');
        l_test_passed := FALSE;
      END IF;
    END IF;
  END;

  -- Test 3: Validation (must work on all versions)
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.LoadPDF(get_test_pdf());
    PL_FPDF.AddWatermark(
      p_text => 'TEST',
      p_options => JSON_OBJECT_T('{
        "opacity": 0.5,
        "rotation": 45
      }')
    );
    DBMS_OUTPUT.PUT_LINE('[PASS] Watermark with validation');
    PL_FPDF.ClearPDFCache();
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('[FAIL] Watermark: ' || SQLERRM);
      l_test_passed := FALSE;
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('----------------------------------------');
  IF l_test_passed THEN
    DBMS_OUTPUT.PUT_LINE('All compatibility tests PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Some tests FAILED - review output');
  END IF;
END;
/
```

---

## 🎯 Feature-by-Feature Compatibility

### Compatibility Matrix

| Feature | Oracle 19c | Oracle 23ai | Oracle 26ai | Implementation |
|---------|-----------|-------------|-------------|----------------|
| **Core PDF Generation** | ✅ Full | ✅ Full | ✅ Full | Same code |
| **PDF Reading** | ✅ Full | ✅ Full | ✅ Full | Same code |
| **Page Operations** | ✅ Full | ✅ Full | ✅ Full | Same code |
| **Watermarks** | ✅ Full | ✅ Full | ✅ Full | Same code |
| **Overlays** | ✅ Full | ✅ Full | ✅ Full | Same code |
| **Merge/Split** | ✅ Full | ✅ Full | ✅ Full | Same code |
| **SQL Domains** | ❌ N/A | ✅ Optional | ✅ Optional | Manual validation on 19c |
| **Annotations** | ❌ N/A | ✅ Optional | ✅ Optional | Comments on 19c |
| **BOOLEAN Type** | ❌ N/A | ✅ Optional | ✅ Optional | VARCHAR2(1) on 19c |
| **IF EXISTS** | ❌ N/A | ✅ Optional | ✅ Optional | Exception handling on 19c |
| **Enhanced JSON** | ❌ N/A | ❌ N/A | ✅ Optional | Standard JSON on 19c/23ai |
| **JavaScript MLE** | ❌ N/A | ✅ Optional | ✅ Optional | PL/SQL only on 19c |

**Legend:**
- ✅ Full: Complete functionality, same performance
- ✅ Optional: Available as enhancement, core works without
- ❌ N/A: Not available, graceful fallback provided

---

## 📊 Performance Considerations

### Performance Parity

| Operation | Oracle 19c | Oracle 23ai | Oracle 26ai | Notes |
|-----------|-----------|-------------|-------------|-------|
| PDF Generation | Baseline | Baseline | Baseline | No difference |
| PDF Parsing | Baseline | Baseline | Baseline | No difference |
| Validation | Baseline | +5% faster | +5% faster | Domains faster |
| JSON Operations | Baseline | Baseline | +10% faster | Enhanced JSON |

**Guarantee:** Oracle 19c performance will **never** be slower than 23ai/26ai for the same operations.

---

## 🔒 Long-Term Support Commitment

### Support Timeline

```
2026 ──────────────────────────────────────────────> 2030+
  │                                                      │
  v3.0.0                                            v5.0.0+
  │                                                      │
  └─────── Oracle 19c Full Support ───────────────────┘

Always supported:
- Oracle 19c: ✅ Full support (indefinitely)
- Oracle 21c: ✅ Full support
- Oracle 23ai: ✅ Full support + optional enhancements
- Oracle 26ai: ✅ Full support + optional enhancements
```

**Commitment:**
- Oracle 19c will be supported in **ALL** PL_FPDF versions
- No features will ever **require** Oracle 23ai/26ai
- Enhanced features are **always optional**
- Performance on 19c will **never degrade**

---

## 🧪 Testing Requirements

### Test Coverage by Version

| Test Category | Oracle 19c | Oracle 23ai | Oracle 26ai |
|--------------|-----------|-------------|-------------|
| Core functionality | 100% | 100% | 100% |
| Enhanced features | N/A | 100% | 100% |
| Fallback mechanisms | 100% | N/A | N/A |
| Performance | 100% | 100% | 100% |
| Integration | 100% | 100% | 100% |

### Continuous Integration

```yaml
# CI/CD Pipeline
test_matrix:
  - oracle_19c:
      tests: [core, fallback, performance]
      required: true
  - oracle_23ai:
      tests: [core, enhanced, fallback, performance]
      required: true
  - oracle_26ai:
      tests: [core, enhanced, performance]
      required: true

deployment:
  # Only deploy if ALL versions pass
  condition: all_tests_passed
```

---

## 📚 Documentation Standards

### User Documentation

All documentation must clearly state Oracle 19c compatibility:

```markdown
## Requirements

- **Oracle Database:** 19c or higher (**19c fully supported**)
- **Optional Enhancements:**
  - Oracle 23ai: SQL Domains, Annotations, BOOLEAN type
  - Oracle 26ai: Enhanced JSON features, JavaScript MLE
```

### API Documentation

```sql
/**
 * AddWatermark - Add watermark to PDF pages
 *
 * @param p_text Watermark text
 * @param p_options JSON options (opacity, rotation, etc.)
 *
 * Compatibility:
 *   Oracle 19c: ✅ Full support (manual validation)
 *   Oracle 23ai+: ✅ Enhanced (automatic validation with domains)
 *
 * Example:
 *   PL_FPDF.AddWatermark('CONFIDENTIAL', JSON_OBJECT_T('{
 *     "opacity": 0.3,
 *     "rotation": 45
 *   }'));
 */
PROCEDURE AddWatermark(
  p_text IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);
```

---

## 🎯 Migration Impact

### Updated Version Strategy

| Version | Oracle Requirement | Previous | New |
|---------|-------------------|----------|-----|
| v3.0.0  | Oracle 19c+ | ✅ Correct | ✅ No change |
| v3.1.0  | Oracle 19c+ | ✅ Correct | ✅ No change |
| v3.2.0  | Oracle 19c+ | ❌ Was "19c min" | ✅ Confirmed 19c |
| v4.0.0  | Oracle 19c+ | ❌ Was "23ai min" | ✅ Changed to 19c |

**Critical Change:** v4.0.0 will **NOT** require Oracle 23ai. All versions support Oracle 19c.

---

## ✅ Implementation Checklist

### For Developers

- [ ] All new features work on Oracle 19c
- [ ] Runtime version detection implemented
- [ ] Fallback implementations provided
- [ ] No compile-time dependencies on 23ai/26ai features
- [ ] Tests pass on Oracle 19c
- [ ] Documentation updated
- [ ] Performance benchmarked on 19c

### For Deployers

- [ ] Test on Oracle 19c environment first
- [ ] Verify feature detection works correctly
- [ ] Check logs for version information
- [ ] Run compatibility test suite
- [ ] Validate performance metrics

### For Users

- [ ] Read compatibility documentation
- [ ] Understand optional vs required features
- [ ] Plan Oracle upgrade if enhanced features desired
- [ ] No forced upgrade required

---

## 📞 Support

For Oracle 19c compatibility issues:

- **GitHub Issues:** Tag with `oracle-19c-compatibility`
- **Priority:** High (same as production bugs)
- **Response Time:** Within 24 hours
- **Resolution:** Within 1 week

---

**Document Version:** 1.0
**Last Updated:** 2026-01
**Author:** @maxwbh
**Status:** Living Document

**Related Documents:**
- [MIGRATION_ROADMAP.md](MIGRATION_ROADMAP.md)
- [MODERNIZATION_ORACLE_26_APEX_24_2.md](MODERNIZATION_ORACLE_26_APEX_24_2.md)
- [README.md](README.md)
