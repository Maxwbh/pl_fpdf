# Modernization Recommendations: Oracle 26ai & APEX 24.2

**Version:** 3.0.0-b.2
**Date:** 2026-01
**Target Platforms:**
- Oracle AI Database 26ai (January 2026+)
- Oracle APEX 24.2

---

## 📋 Executive Summary

This document outlines strategic modernization opportunities for PL_FPDF leveraging Oracle AI Database 26ai and Oracle APEX 24.2 features. Implementation of these recommendations will improve type safety, performance, maintainability, and APEX integration.

**Priority Levels:**
- 🔴 **HIGH**: Significant impact, recommended for Phase 5
- 🟡 **MEDIUM**: Valuable improvements, consider for Phase 5.x
- 🟢 **LOW**: Nice to have, future consideration

---

## 🎯 Oracle 26ai Modernization Opportunities

### 1. SQL Domains for Type Safety 🔴 HIGH

**Current State:**
```sql
-- Multiple type definitions scattered across code
TYPE watermark_rec IS RECORD (
  text VARCHAR2(200),
  opacity NUMBER,
  rotation NUMBER,
  ...
);

TYPE overlay_rec IS RECORD (
  ...
  opacity NUMBER,
  rotation NUMBER,
  ...
);
```

**Recommended Approach:**
Create reusable SQL Domains for common PDF concepts:

```sql
-- Create SQL Domains for common PDF properties
CREATE DOMAIN IF NOT EXISTS pdf_opacity_domain AS NUMBER
  CONSTRAINT opacity_range CHECK (VALUE BETWEEN 0 AND 1)
  DISPLAY '0.00'
  ORDER VALUE
  ANNOTATIONS (
    description 'PDF opacity value (0=transparent, 1=opaque)',
    valid_range '0.0 to 1.0',
    usage 'watermarks, overlays, graphics'
  );

CREATE DOMAIN IF NOT EXISTS pdf_rotation_domain AS NUMBER
  CONSTRAINT rotation_range CHECK (VALUE IN (0, 90, 180, 270))
  DISPLAY '000'
  ORDER VALUE
  ANNOTATIONS (
    description 'PDF rotation angle in degrees',
    valid_values '0, 90, 180, 270',
    usage 'page rotation, text rotation, watermarks'
  );

CREATE DOMAIN IF NOT EXISTS pdf_color_domain AS VARCHAR2(50)
  CONSTRAINT color_format CHECK (
    VALUE IS NULL OR
    REGEXP_LIKE(VALUE, '^#[0-9A-Fa-f]{6}$') OR
    REGEXP_LIKE(VALUE, '^rgb\(\d{1,3},\d{1,3},\d{1,3}\)$')
  )
  ANNOTATIONS (
    description 'PDF color in hex (#RRGGBB) or rgb(r,g,b) format',
    examples '#FF0000, rgb(255,0,0)',
    usage 'text, watermarks, graphics'
  );

CREATE DOMAIN IF NOT EXISTS pdf_page_number_domain AS PLS_INTEGER
  CONSTRAINT page_positive CHECK (VALUE > 0)
  ANNOTATIONS (
    description 'PDF page number (1-based)',
    usage 'page operations, overlays, watermarks'
  );

-- Use domains in tables/types
CREATE TYPE watermark_rec_v2 AS OBJECT (
  watermark_id VARCHAR2(50),
  text VARCHAR2(200),
  opacity pdf_opacity_domain,
  rotation pdf_rotation_domain,
  color pdf_color_domain,
  page_number pdf_page_number_domain,
  ...
);
```

**Benefits:**
- ✅ Centralized validation logic (DRY principle)
- ✅ Self-documenting code via annotations
- ✅ Consistent constraints across all tables/types
- ✅ Better IDE/tool support with domain metadata
- ✅ Easier maintenance and refactoring

**Implementation Impact:**
- Phase 5.7: Create SQL Domains package
- Migration path: Create domains alongside existing types
- Gradual migration: New code uses domains, old code unchanged
- Full migration: Phase 6 (v3.2.0)

---

### 2. Annotations for Documentation 🟡 MEDIUM

**Current State:**
```sql
-- Documentation only in comments
TYPE overlay_rec IS RECORD (
  overlay_id VARCHAR2(50),     -- Unique ID
  overlay_type VARCHAR2(20),   -- 'TEXT' or 'IMAGE'
  page_number PLS_INTEGER,     -- Page number (1-based)
  ...
);
```

**Recommended Approach:**
```sql
-- Add annotations to tables, columns, and domains
ALTER TABLE pdf_metadata ADD ANNOTATIONS (
  description 'Stores metadata for loaded PDF documents',
  owner 'PL_FPDF Team',
  version '3.0.0-b.2',
  phase '4',
  last_modified '2026-01'
);

ALTER TABLE pdf_metadata MODIFY (
  pdf_id ANNOTATIONS (
    description 'Unique identifier for loaded PDF',
    format 'PDF_NNNNNN where N is digit',
    required 'true'
  ),
  page_count ANNOTATIONS (
    description 'Total number of pages in PDF',
    minimum '1',
    data_source 'Extracted from PDF catalog'
  )
);

-- Query annotations programmatically
SELECT column_name,
       annotation_name,
       annotation_value
FROM user_annotations_usage
WHERE object_name = 'PDF_METADATA'
  AND object_type = 'TABLE';
```

**Benefits:**
- ✅ Machine-readable documentation
- ✅ Better integration with data dictionaries
- ✅ Supports automated documentation generation
- ✅ Enables metadata-driven applications

---

### 3. Enhanced JSON Support 🔴 HIGH

**Current State:**
```sql
-- Basic JSON_OBJECT_T usage
l_info := JSON_OBJECT_T();
l_info.put('page_number', p_page_number);
l_info.put('rotation', l_rotation);
```

**Recommended Approach with Oracle 26ai:**

```sql
-- 1. JSON Data Type Constructor with Collections
FUNCTION GetAllOverlays RETURN JSON_OBJECT_T IS
  TYPE overlay_array IS TABLE OF overlay_rec INDEX BY PLS_INTEGER;
  l_overlays overlay_array;
  l_result JSON_OBJECT_T;
BEGIN
  -- Collect overlays
  l_overlays := get_all_overlays_internal();

  -- Oracle 26ai: JSON constructor accepts collections directly
  l_result := JSON_OBJECT_T(l_overlays);  -- NEW in 26ai

  RETURN l_result;
END GetAllOverlays;

-- 2. JSON_ARRAY with Subqueries (SQL/JSON standard)
FUNCTION GetPDFPages(p_pdf_id VARCHAR2) RETURN JSON_ARRAY_T IS
BEGIN
  -- Oracle 26ai: JSON_ARRAY accepts subqueries
  RETURN JSON_ARRAY(
    SELECT JSON_OBJECT(
      'page_number' VALUE page_number,
      'rotation' VALUE rotation,
      'dimensions' VALUE JSON_OBJECT(
        'width' VALUE width,
        'height' VALUE height
      )
    )
    FROM pdf_pages
    WHERE pdf_id = p_pdf_id
    ORDER BY page_number
  );
END GetPDFPages;

-- 3. Multiple Predicates in JSON Path
FUNCTION FindOverlaysByType(
  p_page NUMBER,
  p_type VARCHAR2
) RETURN JSON_ARRAY_T IS
  l_data JSON_OBJECT_T;
BEGIN
  -- Oracle 26ai: Multiple predicates in path
  RETURN l_data.get_array(
    '$.overlays[?(@.page == $page && @.type == $type)]'
    PASSING p_page AS "page", p_type AS "type"
  );
END FindOverlaysByType;

-- 4. JSON_BEHAVIOR Parameter for Error Handling
ALTER SESSION SET JSON_BEHAVIOR = ERROR;  -- Raise errors instead of NULL

-- Now JSON errors will raise exceptions instead of returning NULL
BEGIN
  l_value := l_json.get_number('invalid_key');
EXCEPTION
  WHEN JSON_KEY_NOT_FOUND THEN
    -- Handle missing key explicitly
    l_value := 0;
END;
```

**Benefits:**
- ✅ Cleaner code with native collection support
- ✅ Better SQL/JSON standard compliance
- ✅ More powerful JSON path expressions
- ✅ Explicit error handling control

---

### 4. JavaScript Stored Procedures (MLE) 🟢 LOW

**Potential Use Case:**
JavaScript for complex PDF parsing logic (optional alternative to PL/SQL):

```sql
-- Create JavaScript MLE Module
CREATE OR REPLACE MLE MODULE pdf_parser_js LANGUAGE JAVASCRIPT AS
export function parsePDFHeader(pdfBlob) {
  // JavaScript code for complex PDF header parsing
  // Can leverage existing JS PDF libraries (with licensing considerations)
  const header = extractHeader(pdfBlob);
  return {
    version: header.version,
    encrypted: header.encrypted,
    objectCount: header.objects.length
  };
}
/

-- Call JavaScript from PL/SQL
CREATE OR REPLACE FUNCTION ParsePDFHeaderJS(p_pdf BLOB)
RETURN JSON_OBJECT_T
AS MLE MODULE pdf_parser_js
SIGNATURE 'parsePDFHeader(oracle.sql.BLOB)';
/

-- Use it
DECLARE
  l_result JSON_OBJECT_T;
BEGIN
  l_result := ParsePDFHeaderJS(l_pdf_blob);
  DBMS_OUTPUT.PUT_LINE('PDF Version: ' || l_result.get_string('version'));
END;
```

**Consideration:**
- ⚠️ Adds complexity (mixing PL/SQL and JavaScript)
- ✅ May be useful for leveraging existing JS PDF libraries
- ✅ Better performance for certain operations
- 📝 Recommend: Keep PL/SQL primary, use JS only for specific complex operations

---

### 5. Native BOOLEAN Data Type 🟡 MEDIUM

**Current State:**
```sql
-- Using VARCHAR2 or NUMBER for boolean flags
g_pdf_modified BOOLEAN := FALSE;  -- PL/SQL only
-- Can't use in SQL tables

CREATE TABLE pdf_cache (
  pdf_id VARCHAR2(50),
  is_modified VARCHAR2(1)  -- 'Y'/'N' workaround
);
```

**Recommended Approach (Oracle 23ai+):**
```sql
-- Oracle 23ai/26ai: Native SQL BOOLEAN
CREATE TABLE pdf_cache (
  pdf_id VARCHAR2(50) PRIMARY KEY,
  pdf_blob BLOB,
  is_modified BOOLEAN DEFAULT FALSE,
  is_encrypted BOOLEAN DEFAULT FALSE,
  needs_reparse BOOLEAN DEFAULT FALSE,
  created_date TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Use directly in SQL
SELECT pdf_id, pdf_blob
FROM pdf_cache
WHERE is_modified = TRUE
  AND is_encrypted = FALSE;

-- PL/SQL integration
DECLARE
  l_modified BOOLEAN;
BEGIN
  SELECT is_modified
  INTO l_modified
  FROM pdf_cache
  WHERE pdf_id = 'PDF_001';

  IF l_modified THEN
    regenerate_pdf();
  END IF;
END;
```

**Benefits:**
- ✅ No more 'Y'/'N' or 0/1 workarounds
- ✅ Type safety
- ✅ Clearer intent in code
- ✅ Consistent with PL/SQL BOOLEAN type

---

### 6. IF EXISTS / IF NOT EXISTS Syntax 🟡 MEDIUM

**Current State:**
```sql
-- Manual existence checks
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE temp_pdf_work';
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
```

**Recommended Approach:**
```sql
-- Oracle 23ai/26ai: Clean DDL
DROP TABLE IF EXISTS temp_pdf_work;

CREATE TABLE IF NOT EXISTS pdf_temp_storage (
  session_id VARCHAR2(50),
  pdf_data BLOB,
  created_date TIMESTAMP
);

-- Useful for deployment scripts
CREATE INDEX IF NOT EXISTS idx_pdf_cache_id
  ON pdf_cache(pdf_id);
```

**Benefits:**
- ✅ Cleaner deployment scripts
- ✅ No exception handling needed
- ✅ Idempotent scripts (safe to run multiple times)

---

### 7. Multi-Value INSERT 🟡 MEDIUM

**Current State:**
```sql
-- Multiple INSERT statements
INSERT INTO pdf_metadata VALUES ('PDF_001', 3, 1024);
INSERT INTO pdf_metadata VALUES ('PDF_002', 5, 2048);
INSERT INTO pdf_metadata VALUES ('PDF_003', 2, 512);
```

**Recommended Approach:**
```sql
-- Oracle 23ai/26ai: Single statement
INSERT INTO pdf_metadata (pdf_id, page_count, file_size)
VALUES
  ('PDF_001', 3, 1024),
  ('PDF_002', 5, 2048),
  ('PDF_003', 2, 512);
```

**Benefits:**
- ✅ Better performance (single parse, single round-trip)
- ✅ More maintainable code
- ✅ Standard SQL compliance

---

## 🚀 Oracle APEX 24.2 Integration Opportunities

### 8. Document Generator Integration 🔴 HIGH

**Opportunity:**
Create APEX plugin to integrate PL_FPDF with APEX Document Generator.

**Current Workflow:**
```
User Data → PL_FPDF → PDF BLOB → Download
```

**Enhanced APEX 24.2 Workflow:**
```
User Data → APEX Template (DOCX/XLSX) → Document Generator → PDF
             ↓
          PL_FPDF overlay/merge → Enhanced PDF → Download
```

**Implementation:**

```sql
-- APEX Process Plugin: PL_FPDF Document Enhancer
CREATE OR REPLACE FUNCTION enhance_apex_pdf(
  p_generated_pdf IN BLOB,
  p_watermark_text IN VARCHAR2 DEFAULT NULL,
  p_overlay_data IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB
IS
  l_enhanced_pdf BLOB;
BEGIN
  -- Load APEX-generated PDF
  PL_FPDF.ClearPDFCache();
  PL_FPDF.LoadPDF(p_generated_pdf);

  -- Apply watermark if provided
  IF p_watermark_text IS NOT NULL THEN
    PL_FPDF.AddWatermark(p_watermark_text, NULL);
  END IF;

  -- Apply overlays if provided
  IF p_overlay_data IS NOT NULL THEN
    apply_overlays_from_json(p_overlay_data);
  END IF;

  -- Return enhanced PDF
  l_enhanced_pdf := PL_FPDF.OutputModifiedPDF();
  PL_FPDF.ClearPDFCache();

  RETURN l_enhanced_pdf;
END enhance_apex_pdf;

-- APEX Page Process (Dynamic Action)
BEGIN
  :P10_ENHANCED_PDF := enhance_apex_pdf(
    p_generated_pdf => :P10_GENERATED_PDF,
    p_watermark_text => 'CONFIDENTIAL - ' || :APP_USER,
    p_overlay_data => JSON_OBJECT_T(:P10_OVERLAY_CONFIG)
  );
END;
```

**Use Cases:**
1. **Excel Reports + PL_FPDF Overlays**
   - Generate report via APEX Document Generator (Excel → PDF)
   - Add dynamic watermarks based on user role
   - Add approval stamps/signatures via overlays

2. **Word Templates + PDF Merging**
   - Generate cover page via APEX (Word → PDF)
   - Generate body via PL_FPDF
   - Merge using `PL_FPDF.MergePDFs()`

3. **Multi-Sheet Excel → PDF with Bookmarks**
   - APEX generates multi-sheet Excel
   - Convert to PDF via Document Generator
   - PL_FPDF adds bookmarks/navigation

**Benefits:**
- ✅ Best of both worlds: APEX templates + PL_FPDF manipulation
- ✅ No need to recreate complex Excel layouts in PL/SQL
- ✅ Leverage APEX 24.2 Document Generator improvements
- ✅ Seamless user experience

---

### 9. APEX Interactive Grid Integration 🟡 MEDIUM

**Opportunity:**
Direct PDF generation from Interactive Grids.

```sql
-- APEX Process: Export IG to PDF
CREATE OR REPLACE PROCEDURE ig_to_pdf_report(
  p_region_id IN NUMBER,
  p_format IN VARCHAR2 DEFAULT 'A4'
) IS
  l_query VARCHAR2(32767);
  l_data SYS_REFCURSOR;
  l_pdf BLOB;
BEGIN
  -- Get IG query
  l_query := apex_region.get_query(p_region_id);

  -- Execute query
  OPEN l_data FOR l_query;

  -- Generate PDF via PL_FPDF
  PL_FPDF.Init('P', 'mm', p_format);
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 14);
  PL_FPDF.Cell(0, 10, 'Report: ' || apex_application.g_page_id);

  -- Create table from cursor
  create_table_from_cursor(l_data);

  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- Download
  apex_application.g_print_success_message := 'PDF generated';
  -- ... download logic
END ig_to_pdf_report;
```

**Benefits:**
- ✅ Export any IG to PDF with one click
- ✅ Maintains filters, sorting from IG
- ✅ Custom formatting via PL_FPDF

---

### 10. REST Data Source Integration 🟢 LOW

**Opportunity:**
Expose PL_FPDF as REST API for APEX Remote Database applications.

```sql
-- ORDS REST Handler
BEGIN
  ORDS.DEFINE_MODULE(
    p_module_name => 'pdf.generator',
    p_base_path   => '/pdf/'
  );

  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'pdf.generator',
    p_pattern     => 'merge'
  );

  ORDS.DEFINE_HANDLER(
    p_module_name => 'pdf.generator',
    p_pattern     => 'merge',
    p_method      => 'POST',
    p_source_type => ORDS.SOURCE_TYPE_PLSQL,
    p_source      => q'[
      DECLARE
        l_pdf_ids JSON_ARRAY_T;
        l_merged BLOB;
      BEGIN
        l_pdf_ids := JSON_ARRAY_T(:body);
        l_merged := PL_FPDF.MergePDFs(l_pdf_ids, NULL);
        :response := l_merged;
      END;
    ]'
  );

  COMMIT;
END;
```

**Benefits:**
- ✅ Microservices architecture support
- ✅ APEX remote database scenarios
- ✅ External application integration

---

## 📊 Implementation Roadmap

### Phase 5.7: Oracle 26ai Foundation (v3.1.0-a.7)
**Priority:** 🔴 HIGH
**Estimated Effort:** 2-3 weeks

1. Create SQL Domains for PDF types
2. Add annotations to existing objects
3. Implement enhanced JSON features
4. Add IF EXISTS syntax to all deployment scripts

**Deliverables:**
- `sql_domains/pdf_domains.sql`
- `sql_domains/annotations.sql`
- Updated `deploy_all.sql`
- Migration guide for domains

---

### Phase 5.8: APEX 24.2 Integration (v3.1.0-a.8)
**Priority:** 🔴 HIGH
**Estimated Effort:** 2 weeks

1. Create APEX plugin for Document Generator integration
2. Create IG export functionality
3. Sample APEX application demonstrating integration
4. Documentation and tutorials

**Deliverables:**
- `extensions/apex/PL_FPDF_APEX_PLUGIN.sql`
- `examples/apex_integration_app.sql`
- `docs/APEX_24_2_INTEGRATION.md`

---

### Phase 6.0: Full Modernization (v3.2.0)
**Priority:** 🟡 MEDIUM
**Estimated Effort:** 4-6 weeks

1. Migrate all types to use SQL Domains
2. Replace VARCHAR2 booleans with native BOOLEAN
3. Implement JavaScript MLE for complex parsing (optional)
4. Full annotation coverage
5. Performance benchmarking

**Deliverables:**
- Complete domain-based type system
- Breaking changes migration guide
- Performance comparison report
- Oracle 26ai certification

---

## 🎯 Quick Wins (Immediate Implementation)

These can be implemented immediately without breaking changes:

### 1. Add IF EXISTS to Deployment Scripts
```sql
-- Update deploy_all.sql
DROP TABLE IF EXISTS pdf_temp_work;
CREATE INDEX IF NOT EXISTS idx_pdf_cache ON ...;
```

### 2. Use Multi-Value INSERT in Test Scripts
```sql
-- Update test data creation
INSERT INTO test_pdfs VALUES
  ('PDF_001', l_blob_1),
  ('PDF_002', l_blob_2),
  ('PDF_003', l_blob_3);
```

### 3. Implement JSON_BEHAVIOR Error Handling
```sql
-- Add to package initialization
EXECUTE IMMEDIATE 'ALTER SESSION SET JSON_BEHAVIOR = ERROR';
```

### 4. Add Annotations to Documentation Tables
```sql
ALTER TABLE pdf_metadata ADD ANNOTATIONS (
  description 'PL_FPDF metadata cache table',
  version '3.0.0-b.2'
);
```

---

## 📖 References

### Oracle 26ai Documentation
- [Oracle AI Database New Features Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/nfcoa/)
- [JSON in Oracle AI Database](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-oracle-ai-database.html)
- [SQL Domains Documentation](https://docs.oracle.com/en/learn/db23ai-sql-features/index.html)
- [Oracle 23ai/26ai SQL and PL/SQL Enhancements](https://oracle-base.com/articles/23/sql-and-plsql-enhancements-23)

### APEX 24.2 Documentation
- [What's New in APEX 24.2](https://apex.oracle.com/en/platform/features/whats-new-242/)
- [APEX 24.2 Document Generator Enhancements](https://blogs.oracle.com/apex/enhancing-document-generation-with-oci-and-oracle-apex-242)
- [Oracle APEX 24.2 New Features PDF](https://www.oracle.com/a/otn/docs/apex-242-new-features.pdf)

### Community Resources
- [ORACLE-BASE Articles](https://oracle-base.com/articles/23/articles-23)
- [MaxAPEX APEX 24.2 Features](https://www.maxapex.com/blogs/oracle-apex-24-2-new-features/)

---

## 🤝 Contributing

To contribute modernization ideas:

1. Review this document
2. Create feature branch: `feature/oracle26-<feature-name>`
3. Implement with backward compatibility
4. Add tests for Oracle 26ai and APEX 24.2
5. Update this document with findings
6. Submit PR with Oracle version requirements

---

## 📋 Compatibility Matrix

| Feature | Oracle 11g | Oracle 19c | Oracle 23ai | Oracle 26ai | APEX 24.2 |
|---------|-----------|-----------|------------|------------|-----------|
| Current PL_FPDF | ✅ | ✅ | ✅ | ✅ | ✅ |
| SQL Domains | ❌ | ❌ | ✅ | ✅ | N/A |
| Annotations | ❌ | ❌ | ✅ | ✅ | N/A |
| Native BOOLEAN | ❌ | ❌ | ✅ | ✅ | ✅ |
| IF EXISTS | ❌ | ❌ | ✅ | ✅ | N/A |
| Enhanced JSON | ❌ | Partial | ✅ | ✅ | ✅ |
| Document Generator | N/A | N/A | N/A | N/A | ✅ |
| Multi-Value INSERT | ❌ | ❌ | ✅ | ✅ | N/A |

---

**Document Version:** 1.0
**Last Updated:** 2026-01
**Author:** @maxwbh
**Status:** Draft - Awaiting Review
