# PL_FPDF Migration Roadmap: Future Versions & Strategies

**Version:** 3.0.0-b.2
**Date:** 2026-01
**Status:** Strategic Planning Document

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Version History & Timeline](#version-history--timeline)
3. [Future Version Roadmap](#future-version-roadmap)
4. [Migration Strategies](#migration-strategies)
5. [Compatibility Matrix](#compatibility-matrix)
6. [Deprecation Timeline](#deprecation-timeline)
7. [Step-by-Step Migration Paths](#step-by-step-migration-paths)
8. [Risk Assessment & Mitigation](#risk-assessment--mitigation)
9. [Testing Strategy](#testing-strategy)
10. [Rollback Plans](#rollback-plans)

---

## 📊 Executive Summary

This document provides a comprehensive roadmap for PL_FPDF migrations, covering:

- **Historical context**: v0.9.4 → v2.0.0 → v3.0.0
- **Current state**: v3.0.0-beta.2 (Phase 4.6 complete, not validated)
- **Future versions**: v3.1.0 → v3.2.0 → v4.0.0
- **Migration strategies**: Gradual, big-bang, parallel-run
- **Oracle platform evolution**: 11g → 19c → 23ai → 26ai
- **APEX integration**: Traditional → APEX 24.1 → APEX 24.2+

**Key Principles:**
- ✅ Maintain backward compatibility where possible
- ✅ Provide clear migration paths for breaking changes
- ✅ Gradual feature deprecation (minimum 1 major version notice)
- ✅ Comprehensive testing at each stage
- ✅ Rollback capability for critical systems

---

## 🕰️ Version History & Timeline

### Historical Versions

```
v0.9.4 (2017-12)
  ├── Legacy PHP FPDF port
  ├── Oracle 11g+ compatible
  ├── VARCHAR2 arrays (32K limit)
  ├── OrdImage dependencies
  └── Status: 🔒 Archived

v2.0.0 (2025-12)
  ├── Complete modernization
  ├── Oracle 19c/23c optimized
  ├── CLOB buffers (unlimited size)
  ├── Native BLOB images
  ├── Trivadis PL/SQL Cop compliant
  ├── Phases 1-3: PDF Generation
  └── Status: ✅ Production Ready

v3.0.0 (2026-01)
  ├── PDF Reading & Manipulation
  ├── Phases 4.1-4.4: Validated
  ├── Phases 4.5-4.6: Beta (not validated)
  ├── JSON_OBJECT_T APIs
  ├── Multi-document management
  └── Status: 🔄 In Validation
```

### Current State (2026-01)

**Version:** 3.0.0-b.2
**Phase:** 4.6 Complete (Overlay + Merge/Split)
**Status:** Beta - Awaiting Validation
**Next Step:** Validate Phase 4 → Promote to RC → Release 3.0.0

---

## 🚀 Future Version Roadmap

### Version 3.0.0-rc.1 → 3.0.0 (Q1 2026)

**Goal:** Validate and release Phase 4 complete

**Timeline:** 2-4 weeks

**Activities:**
1. ✅ Run comprehensive test suite (`test_runner.sql`)
2. ✅ Fix any failing tests
3. ✅ Update version to 3.0.0-rc.1
4. ✅ Community testing period (1 week)
5. ✅ Final release 3.0.0

**Deliverables:**
- All Phase 4 tests passing (150+ tests)
- Production-ready 3.0.0 release
- Complete API documentation
- Performance benchmarks

**Breaking Changes:** None (100% backward compatible with v2.0.0)

---

### Version 3.1.0 (Q2 2026)

**Goal:** Phase 5 - Advanced Page Operations

**Timeline:** 8-10 weeks

**Features:**

#### Phase 5.1: Page Insertion (v3.1.0-a.1)
- `InsertPagesFrom()` - Insert pages at specific position
- `PrependPages()` - Add pages at beginning
- `AppendPages()` - Add pages at end
- Page tree manipulation

#### Phase 5.2: Page Reordering (v3.1.0-a.2)
- `ReorderPages()` - Custom page sequence
- `MovePage()` - Single page repositioning
- `SwapPages()` - Exchange two pages
- `ReversePages()` - Reverse document

#### Phase 5.3: Page Replacement (v3.1.0-a.3)
- `ReplacePage()` - Replace single page
- `ReplacePageRange()` - Replace multiple pages
- Content-aware replacement

#### Phase 5.4: Page Duplication (v3.1.0-a.4)
- `DuplicatePage()` - Copy within/across documents
- `DuplicatePageRange()` - Batch duplication
- Resource optimization

#### Phase 5.5: Batch Processing (v3.1.0-a.5)
- `BatchProcess()` - Multi-PDF operations
- Template-based workflows
- Transaction support

#### Phase 5.6: Smart Bookmarks (v3.1.0-a.6)
- Automatic bookmark management
- Bookmark sync after operations
- TOC generation

**Breaking Changes:** None

**Deprecations:**
- None (additive release)

**Migration Path:**
- Drop-in replacement for v3.0.0
- New features optional
- Existing code unchanged

---

### Version 3.1.x → 3.2.0 (Q3-Q4 2026)

**Goal:** Oracle 26ai Modernization

**Timeline:** 12-16 weeks

**Features:**

#### Phase 5.7: SQL Domains Foundation (v3.1.0-a.7)
- Create SQL domains for PDF types
- Add annotations to objects
- Implement IF EXISTS syntax
- Multi-value INSERTs

**New SQL Domains:**
```sql
- pdf_opacity_domain (0.0-1.0 with validation)
- pdf_rotation_domain (0, 90, 180, 270)
- pdf_color_domain (RGB/Hex validation)
- pdf_page_number_domain (positive integer)
- pdf_coordinate_domain (PDF units)
```

#### Phase 5.8: APEX 24.2 Integration (v3.1.0-a.8)
- APEX Document Generator plugin
- Interactive Grid PDF export
- REST API endpoints (ORDS)
- Sample APEX application

#### Phase 6.0 Preparation (v3.2.0-rc.1)
- Enhanced JSON features (Oracle 26ai)
- Native BOOLEAN migration prep
- Deprecation warnings for old patterns
- Migration utilities

**Breaking Changes:** None (domains parallel to existing types)

**Deprecations Announced:**
- ⚠️ VARCHAR2 boolean flags (use BOOLEAN in v4.0)
- ⚠️ Direct type usage (recommend domains in v4.0)
- ⚠️ Legacy exception codes (unified in v4.0)

**Migration Path:**
1. Update to v3.2.0
2. Review deprecation warnings
3. Plan migration for v4.0
4. Test with compatibility mode

---

### Version 4.0.0 (Q1 2027)

**Goal:** Next-Generation Architecture with Enhanced Features

**Timeline:** 16-20 weeks

**Oracle Compatibility:** 🔴 **Oracle 19c+ (UNCHANGED)**

**Major Changes:**

#### 1. SQL Domains (Optional Enhancement)
```sql
-- v3.x and v4.0 on Oracle 19c
TYPE watermark_rec IS RECORD (
  opacity NUMBER  -- Manual validation
);

-- v4.0 on Oracle 23ai+ (Optional)
TYPE watermark_rec IS RECORD (
  opacity pdf_opacity_domain  -- Automatic validation
);
```

**Implementation:** Runtime detection, graceful fallback to manual validation on 19c

#### 2. BOOLEAN Type (Optional Enhancement)
```sql
-- v4.0 on Oracle 19c
g_pdf_modified VARCHAR2(1) := 'N';  -- 'Y'/'N' (unchanged)

-- v4.0 on Oracle 23ai+ (Optional)
g_pdf_modified BOOLEAN := FALSE;    -- Native BOOLEAN
```

**Implementation:** Compatibility layer, same API across all versions

#### 3. Unified Exception Framework
```sql
-- v3.x (multiple ranges)
-20801 to -20839  -- Various errors

-- v4.0 (unified, all Oracle versions)
-29000 to -29999  -- All PL_FPDF errors
```

**Migration:** Exception mapping table, compatibility layer (no breaking changes)

#### 4. Enhanced Oracle 23ai/26ai Features (All Optional)
- SQL Domains with annotations
- JavaScript MLE support (fallback to PL/SQL on 19c)
- Enhanced JSON features (standard JSON on 19c)
- Native BOOLEAN type (VARCHAR2 fallback on 19c)

**Breaking Changes:**
- 🟡 New exception number range (-29000 series)
- 🟡 Removed long-deprecated functions (announced in v3.2.0)
- ✅ **NO** Oracle version requirement change
- ✅ **NO** mandatory SQL Domains
- ✅ **NO** mandatory BOOLEAN types
- ✅ **100% compatible with Oracle 19c**

**Migration Path:**
- Step 1: Upgrade Oracle to 23ai/26ai
- Step 2: Run pre-migration validation
- Step 3: Backup current version
- Step 4: Run automated migration script
- Step 5: Test thoroughly
- Step 6: Update application code

**Rollback:** Keep v3.2.0 parallel for 6 months

---

## 🔄 Migration Strategies

### Strategy 1: Gradual Migration (Recommended)

**Best for:** Production systems, large codebases

**Timeline:** 3-6 months per major version

**Approach:**
```
Current → Beta → RC → Stable
  ↓        ↓      ↓      ↓
Test    Staging Pre-prod Production
```

**Steps:**
1. **Week 1-2:** Setup test environment with new version
2. **Week 3-4:** Run automated tests, identify issues
3. **Week 5-6:** Fix compatibility issues
4. **Week 7-8:** Deploy to staging
5. **Week 9-10:** User acceptance testing
6. **Week 11-12:** Production deployment (phased)

**Benefits:**
- ✅ Low risk
- ✅ Thorough testing
- ✅ Easy rollback

**Drawbacks:**
- ⏰ Slow process
- 💰 Higher maintenance cost

---

### Strategy 2: Big-Bang Migration

**Best for:** Small applications, greenfield projects

**Timeline:** 1-2 weeks

**Approach:**
```
v2.0.0 → [Testing] → v3.0.0
  (1 week)  (1 week)
```

**Steps:**
1. **Day 1:** Deploy to test environment
2. **Day 2-5:** Intensive testing
3. **Day 6-7:** Fix critical issues
4. **Weekend:** Production cutover
5. **Week 2:** Monitoring and fixes

**Benefits:**
- ⚡ Fast migration
- 💰 Lower cost

**Drawbacks:**
- ⚠️ Higher risk
- 🔧 Requires downtime

---

### Strategy 3: Parallel Run

**Best for:** Critical systems, zero-downtime requirements

**Timeline:** 2-3 months

**Approach:**
```
Production (v2.0.0) ──────────────┐
                                   ├─→ Results Compare ─→ Cutover
Parallel (v3.0.0)  ──────────────┘
```

**Steps:**
1. **Month 1:** Deploy v3.0.0 in parallel
2. **Month 2:** Run both versions, compare outputs
3. **Month 3:** Gradual traffic shift to v3.0.0
4. **Cutover:** Decommission v2.0.0

**Benefits:**
- ✅ Zero downtime
- ✅ Proven reliability
- ✅ Easy comparison

**Drawbacks:**
- 💰 Double resources
- 🔧 Complex setup

---

### Strategy 4: Feature-Flag Migration

**Best for:** SaaS applications, multi-tenant systems

**Timeline:** 1-2 months

**Approach:**
```sql
-- Feature flag control
IF get_feature_flag('USE_V3_PDF_GENERATION') THEN
  PL_FPDF_V3.Generate(...);
ELSE
  PL_FPDF_V2.Generate(...);
END IF;
```

**Steps:**
1. Deploy both versions
2. Enable v3.0.0 for internal users (10%)
3. Gradually increase percentage (25%, 50%, 75%)
4. Full rollout to 100%
5. Remove v2.0.0

**Benefits:**
- ✅ Gradual rollout
- ✅ Easy rollback
- ✅ A/B testing possible

**Drawbacks:**
- 🔧 Code complexity
- 💰 Maintenance overhead

---

## 📋 Compatibility Matrix

### Oracle Database Versions

| PL_FPDF Version | Oracle 11g | Oracle 19c | Oracle 23ai | Oracle 26ai | Notes |
|-----------------|-----------|-----------|------------|------------|-------|
| v0.9.4          | ✅        | ✅        | ✅         | ✅         | Legacy, archived |
| v2.0.0          | ⚠️        | ✅        | ✅         | ✅         | 11g limited features |
| v3.0.0          | ⚠️        | ✅        | ✅         | ✅         | 11g limited features |
| v3.2.0          | ❌        | ✅        | ✅         | ✅         | 19c minimum |
| **v4.0.0**      | ❌        | **✅**    | **✅+**    | **✅+**    | **19c full support, 23ai/26ai enhanced** |

**Legend:**
- ✅ Full support (all features work)
- ✅+ Full support + optional enhancements
- ⚠️ Limited support (degraded features)
- ❌ Not supported

**IMPORTANT:** v4.0.0 maintains full Oracle 19c compatibility. Enhanced features (Domains, Annotations) are optional on 23ai/26ai.

---

### APEX Versions

| PL_FPDF Version | APEX 19.1 | APEX 20.x | APEX 23.x | APEX 24.1 | APEX 24.2+ |
|-----------------|-----------|-----------|-----------|-----------|-----------|
| v2.0.0          | ✅        | ✅        | ✅        | ✅        | ✅        |
| v3.0.0          | ✅        | ✅        | ✅        | ✅        | ✅        |
| v3.2.0 (domains)| ⚠️        | ⚠️        | ✅        | ✅        | ✅        |
| v3.2.0 (APEX plugin)| ❌   | ❌        | ⚠️        | ✅        | ✅        |
| v4.0.0          | ❌        | ❌        | ❌        | ⚠️        | ✅        |

---

### Feature Availability Matrix

| Feature | v2.0.0 | v3.0.0 | v3.2.0 | v4.0.0 |
|---------|--------|--------|--------|--------|
| PDF Generation | ✅ | ✅ | ✅ | ✅ |
| PDF Reading | ❌ | ✅ | ✅ | ✅ |
| Page Rotation | ❌ | ✅ | ✅ | ✅ |
| Watermarks | ❌ | ✅ | ✅ | ✅ |
| Overlays | ❌ | ✅ | ✅ | ✅ |
| Merge/Split | ❌ | ✅ | ✅ | ✅ |
| Page Operations | ❌ | ❌ | ✅ | ✅ |
| SQL Domains | ❌ | ❌ | ⚠️ | ✅ |
| APEX Integration | ⚠️ | ⚠️ | ✅ | ✅ |
| JavaScript MLE | ❌ | ❌ | ❌ | ✅ |

**Legend:**
- ✅ Available
- ⚠️ Partial / Optional
- ❌ Not available

---

## ⏰ Deprecation Timeline

### Current Deprecations (v3.0.0)

**Effective:** 2026-01
**Removal:** v4.0.0 (2027-Q1)

| Deprecated Item | Replacement | Reason | Migration Effort |
|----------------|-------------|--------|-----------------|
| `fpdf()` | `Init()` | Naming consistency | Low (alias exists) |
| `ReturnBlob()` | `OutputBlob()` | Clarity | Low (alias exists) |
| `Output('F')` | `OutputFile()` | Type safety | Low (alias exists) |
| OrdImage types | `recImageBlob` | Oracle deprecated | Medium (auto-convert) |

**Status:** ⚠️ Deprecation warnings in logs, still functional

---

### Planned Deprecations (v3.2.0)

**Effective:** 2026-Q3
**Removal:** v4.0.0 (2027-Q1)

| Item to Deprecate | Replacement | Reason | Notice Period |
|------------------|-------------|--------|--------------|
| VARCHAR2 booleans | Native BOOLEAN | Type safety | 6 months |
| Direct type usage | SQL Domains | Validation | 6 months |
| Legacy exceptions | Unified codes | Consistency | 6 months |
| Manual JSON | Native JSON features | Oracle 26ai | 6 months |

**Timeline:**
- **2026-09:** Deprecation announced in v3.2.0
- **2026-10 to 2027-01:** Migration period with warnings
- **2027-02:** Removed in v4.0.0

---

### Sunset Timeline

```
2026-01: v3.0.0 Released
   │
   ├─ v2.0.0: Maintenance mode (bug fixes only)
   │
2026-Q3: v3.2.0 Released (deprecation warnings)
   │
   ├─ v2.0.0: Limited support (critical bugs only)
   │
2027-Q1: v4.0.0 Released
   │
   ├─ v2.0.0: End of Life (no support)
   ├─ v3.0.0: Maintenance mode
   │
2027-Q3: v3.2.0 maintenance only
   │
2028-Q1: v3.x End of Life
```

**Support Levels:**
- **Full Support:** Active development, all bugs fixed
- **Maintenance:** Bug fixes only, no new features
- **Limited Support:** Critical security/data corruption bugs only
- **End of Life:** No support, use at own risk

---

## 🛣️ Step-by-Step Migration Paths

### Path 1: v2.0.0 → v3.0.0

**Complexity:** 🟢 Low
**Breaking Changes:** None
**Timeline:** 1-2 weeks

#### Prerequisites
- Oracle 19c or higher
- Current v2.0.0 working
- Test environment available

#### Step-by-Step

**Phase 1: Preparation (Day 1-2)**
```sql
-- 1. Backup current package
CREATE OR REPLACE PACKAGE PL_FPDF_V2_BACKUP AS
  -- Copy of v2.0.0
END;

-- 2. Export test data
CREATE TABLE pdf_test_backup AS
SELECT * FROM pdf_documents;

-- 3. Document current usage
SELECT object_name, object_type
FROM user_dependencies
WHERE referenced_name = 'PL_FPDF';
```

**Phase 2: Installation (Day 3)**
```sql
-- 1. Download v3.0.0
-- wget https://github.com/maxwbh/pl_fpdf/releases/v3.0.0.zip

-- 2. Deploy package
@PL_FPDF.pks
@PL_FPDF.pkb

-- 3. Verify version
SELECT PL_FPDF.GetVersion() FROM DUAL;
-- Expected: 3.0.0
```

**Phase 3: Testing (Day 4-7)**
```sql
-- Run comprehensive test suite
SET SERVEROUTPUT ON SIZE UNLIMITED
@tests/test_runner.sql

-- Test your application-specific code
@my_app_tests.sql
```

**Phase 4: Validation (Day 8-10)**
```sql
-- Compare outputs (v2 vs v3)
DECLARE
  l_pdf_v2 BLOB;
  l_pdf_v3 BLOB;
BEGIN
  -- Generate with v2 backup
  l_pdf_v2 := generate_report_v2();

  -- Generate with v3
  l_pdf_v3 := generate_report_v3();

  -- Compare sizes (should be similar)
  DBMS_OUTPUT.PUT_LINE('V2 size: ' || DBMS_LOB.GETLENGTH(l_pdf_v2));
  DBMS_OUTPUT.PUT_LINE('V3 size: ' || DBMS_LOB.GETLENGTH(l_pdf_v3));

  -- Visual comparison (open both PDFs)
END;
```

**Phase 5: Deployment (Day 11-14)**
```sql
-- 1. Deploy to production (maintenance window)
@deploy_v3.sql

-- 2. Monitor first week
SELECT * FROM user_errors WHERE name = 'PL_FPDF';

-- 3. Remove backup after 1 month
DROP PACKAGE PL_FPDF_V2_BACKUP;
```

**Rollback Plan:**
```sql
-- If issues found:
@rollback_to_v2.sql

-- Restore backup
CREATE OR REPLACE PACKAGE PL_FPDF AS
  -- Copy from PL_FPDF_V2_BACKUP
END;
```

---

### Path 2: v3.0.0 → v3.2.0 (Oracle 26ai Features)

**Complexity:** 🟡 Medium
**Breaking Changes:** None (optional features)
**Timeline:** 2-4 weeks

#### Prerequisites
- Oracle 23ai or 26ai
- v3.0.0 installed
- Understanding of SQL Domains

#### Step-by-Step

**Phase 1: Environment Verification (Week 1)**
```sql
-- 1. Check Oracle version
SELECT version FROM v$instance;
-- Must be: 23.x or 26.x

-- 2. Check domain support
SELECT COUNT(*) FROM all_domains;
-- Should work without error

-- 3. Verify JSON features
SELECT JSON_OBJECT('test' VALUE 123) FROM DUAL;
```

**Phase 2: Deploy Domains (Week 2)**
```sql
-- 1. Create SQL domains
@sql_domains/pdf_domains.sql

-- Expected:
-- Domain PDF_OPACITY_DOMAIN created
-- Domain PDF_ROTATION_DOMAIN created
-- Domain PDF_COLOR_DOMAIN created
-- Domain PDF_PAGE_NUMBER_DOMAIN created

-- 2. Verify domains
SELECT domain_name, data_type, data_length
FROM user_domains;

-- 3. Add annotations
@sql_domains/annotations.sql
```

**Phase 3: Parallel Testing (Week 3)**
```sql
-- Test old types and new domains side-by-side
DECLARE
  -- Old way (still works)
  TYPE old_rec IS RECORD (
    opacity NUMBER
  );

  -- New way (recommended)
  TYPE new_rec IS RECORD (
    opacity pdf_opacity_domain
  );

  l_old old_rec;
  l_new new_rec;
BEGIN
  -- Test validation
  l_old.opacity := 2.5;  -- Invalid but no error
  l_new.opacity := 2.5;  -- ERROR: check constraint violated
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Domain validation working: ' || SQLERRM);
END;
```

**Phase 4: Gradual Adoption (Week 4)**
```sql
-- Migrate new code to use domains
-- Keep old code unchanged

-- Example: New overlay code
PROCEDURE add_overlay_v2(
  p_opacity IN pdf_opacity_domain,  -- New: validated
  p_rotation IN pdf_rotation_domain
) IS
BEGIN
  -- Implementation
END;

-- Old procedure still available
PROCEDURE add_overlay(
  p_opacity IN NUMBER,  -- Old: no validation
  p_rotation IN NUMBER
) IS
BEGIN
  -- Calls new version with validation
  add_overlay_v2(p_opacity, p_rotation);
END;
```

---

### Path 3: v3.2.0 → v4.0.0 (Breaking Changes)

**Complexity:** 🔴 High
**Breaking Changes:** Multiple
**Timeline:** 8-12 weeks

#### Prerequisites
- Oracle 26ai minimum
- v3.2.0 with all deprecation warnings resolved
- Comprehensive test suite
- Backup and rollback plan

#### Step-by-Step

**Phase 1: Pre-Migration Assessment (Week 1-2)**
```sql
-- 1. Run migration assessment tool
@migration/assess_v4_readiness.sql

-- Output:
-- ✅ Oracle version: 26ai (OK)
-- ⚠️ VARCHAR2 booleans found: 15 locations
-- ⚠️ Direct type usage: 47 locations
-- ⚠️ Legacy exceptions: 8 handlers
-- ❌ OrdImage usage: 2 locations (BLOCKER)

-- 2. Review deprecation warnings
SELECT * FROM user_deprecation_warnings
WHERE object_name = 'PL_FPDF';

-- 3. Estimate migration effort
@migration/estimate_effort.sql
-- Estimated effort: 40-60 hours
```

**Phase 2: Automated Migration (Week 3-4)**
```sql
-- 1. Run automated migration script
@migration/migrate_to_v4_auto.sql

-- This script:
-- - Converts VARCHAR2 booleans to BOOLEAN
-- - Updates type definitions to use domains
-- - Migrates exception handlers
-- - Updates deprecated function calls

-- 2. Review migration log
SELECT * FROM v4_migration_log
ORDER BY migration_date DESC;

-- 3. Handle manual migrations
@migration/manual_steps.sql
```

**Phase 3: Manual Code Updates (Week 5-6)**
```sql
-- Example manual migrations:

-- OLD (v3.x)
IF l_pdf_modified = 'Y' THEN
  regenerate_pdf();
END IF;

-- NEW (v4.0)
IF l_pdf_modified = TRUE THEN
  regenerate_pdf();
END IF;

-- OLD (v3.x)
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20809 THEN  -- Legacy code
      handle_no_pdf_loaded();
    END IF;
END;

-- NEW (v4.0)
EXCEPTION
  WHEN PL_FPDF.NO_PDF_LOADED THEN  -- Named exception
    handle_no_pdf_loaded();
END;
```

**Phase 4: Comprehensive Testing (Week 7-8)**
```sql
-- 1. Run all test suites
@tests/test_runner_v4.sql

-- 2. Performance benchmarking
@tests/performance_comparison.sql
-- Compare v3.2.0 vs v4.0.0

-- 3. Integration testing
-- Test all dependent applications

-- 4. User acceptance testing
-- 1 week UAT period
```

**Phase 5: Staged Deployment (Week 9-12)**
```
Week 9:  Development environment
Week 10: Test environment
Week 11: Staging environment
Week 12: Production (phased rollout)
```

**Rollback Plan:**
```sql
-- Keep v3.2.0 running in parallel for 6 months

-- If critical issue:
1. Switch database connection to v3.2.0 instance
2. Investigate issue
3. Fix in v4.0.x patch
4. Re-test
5. Re-deploy

-- Emergency rollback script:
@emergency_rollback_to_v3_2.sql
```

---

## ⚠️ Risk Assessment & Mitigation

### High-Risk Areas

| Risk | Probability | Impact | Mitigation |
|------|-----------|--------|-----------|
| Data corruption during migration | Low | Critical | Pre-migration backup, validation scripts |
| Performance regression | Medium | High | Benchmark before/after, rollback plan |
| Breaking changes in v4.0 | High | Medium | Gradual migration, compatibility layer |
| Oracle version incompatibility | Low | High | Version detection, feature flags |
| APEX integration issues | Medium | Medium | Separate APEX plugin, optional |

### Mitigation Strategies

#### 1. Data Corruption Prevention
```sql
-- Before migration
CREATE TABLE pdf_documents_backup AS
SELECT * FROM pdf_documents;

-- Checksum verification
CREATE OR REPLACE FUNCTION verify_pdf_integrity(
  p_pdf_before BLOB,
  p_pdf_after BLOB
) RETURN BOOLEAN IS
BEGIN
  RETURN DBMS_LOB.COMPARE(p_pdf_before, p_pdf_after) = 0;
END;

-- After migration validation
SELECT COUNT(*) as corrupted_pdfs
FROM pdf_documents d
JOIN pdf_documents_backup b ON d.id = b.id
WHERE NOT verify_pdf_integrity(b.pdf_blob, d.pdf_blob);
```

#### 2. Performance Regression Detection
```sql
-- Performance baseline (before migration)
CREATE TABLE performance_baseline AS
SELECT operation,
       AVG(elapsed_time) avg_time,
       MAX(elapsed_time) max_time,
       COUNT(*) executions
FROM performance_log
WHERE operation_date > SYSDATE - 30
GROUP BY operation;

-- After migration comparison
SELECT p.operation,
       b.avg_time baseline_avg,
       p.avg_time current_avg,
       ROUND((p.avg_time - b.avg_time) / b.avg_time * 100, 2) pct_change
FROM current_performance p
JOIN performance_baseline b ON p.operation = b.operation
WHERE ABS((p.avg_time - b.avg_time) / b.avg_time) > 0.1  -- 10% threshold
ORDER BY ABS(pct_change) DESC;
```

#### 3. Compatibility Layer (v4.0)
```sql
-- Provide backward-compatible wrappers
CREATE OR REPLACE PACKAGE PL_FPDF_COMPAT AS
  -- Wrapper for old VARCHAR2 boolean
  PROCEDURE set_modified_flag(p_flag VARCHAR2);

  -- Wrapper for old exception codes
  PROCEDURE handle_legacy_exception(p_error_code NUMBER);
END PL_FPDF_COMPAT;
```

---

## 🧪 Testing Strategy

### Test Pyramid

```
                     E2E Tests
                   (Full workflows)
                    /          \
                   /            \
              Integration Tests
            (Component interaction)
             /                  \
            /                    \
       Unit Tests              Performance Tests
    (Individual APIs)         (Benchmarking)
```

### Test Coverage Requirements

| Version | Unit Tests | Integration | E2E | Performance |
|---------|-----------|-------------|-----|-------------|
| v3.0.0  | 80%+ | 60%+ | 40%+ | Baseline |
| v3.2.0  | 85%+ | 70%+ | 50%+ | ±5% baseline |
| v4.0.0  | 90%+ | 80%+ | 60%+ | ±10% baseline |

### Test Suites

#### 1. Regression Test Suite
```sql
-- Ensure no existing functionality breaks
@tests/regression_suite.sql

-- Tests:
-- - All v2.0.0 functionality still works
-- - All v3.0.0 functionality still works
-- - PDF output identical (byte-for-byte when possible)
```

#### 2. New Feature Test Suite
```sql
-- Test new features in isolation
@tests/new_features_suite.sql

-- For v3.0.0:
-- - Phase 4.5: Overlay tests (20 tests)
-- - Phase 4.6: Merge/split tests (20 tests)
```

#### 3. Migration Test Suite
```sql
-- Test migration scripts
@tests/migration_suite.sql

-- Tests:
-- - Data migration correctness
-- - Type conversion accuracy
-- - Exception mapping
-- - Performance equivalence
```

#### 4. Compatibility Test Suite
```sql
-- Test across Oracle versions
@tests/compatibility_suite.sql

-- Run on:
-- - Oracle 19c (v3.x only)
-- - Oracle 23ai
-- - Oracle 26ai
```

---

## 🔙 Rollback Plans

### Rollback Strategy Matrix

| Scenario | Detection Time | Rollback Method | Data Loss Risk |
|----------|---------------|-----------------|----------------|
| Deployment failure | Immediate | Revert scripts | None |
| Performance issue | 1-7 days | Parallel run switch | None |
| Data corruption | 1-30 days | Backup restore | Low (backups) |
| Breaking change | 1-90 days | Version downgrade | Medium |

### Rollback Procedures

#### Quick Rollback (< 1 hour)
```sql
-- Use for: Immediate deployment failures

-- 1. Stop application
ALTER SYSTEM KILL SESSION 'sid,serial#';

-- 2. Revert package
@rollback/revert_package.sql

-- 3. Verify version
SELECT PL_FPDF.GetVersion() FROM DUAL;

-- 4. Restart application
```

#### Standard Rollback (< 1 day)
```sql
-- Use for: Performance issues, minor bugs

-- 1. Switch to old version (parallel run)
UPDATE app_config
SET pdf_package_version = 'V2'
WHERE config_key = 'PDF_GENERATOR';

-- 2. Monitor for 24 hours
SELECT * FROM error_log
WHERE error_date > SYSDATE - 1;

-- 3. Decommission new version
DROP PACKAGE PL_FPDF_V3;
```

#### Full Rollback (< 1 week)
```sql
-- Use for: Data corruption, critical bugs

-- 1. Stop all PDF operations
UPDATE app_config SET pdf_generation_enabled = 'N';

-- 2. Restore from backup
FLASHBACK TABLE pdf_documents TO TIMESTAMP
  TO_TIMESTAMP('2026-01-15 08:00:00', 'YYYY-MM-DD HH24:MI:SS');

-- 3. Revert package
@rollback/full_revert.sql

-- 4. Validate data integrity
@rollback/validate_restore.sql

-- 5. Resume operations
UPDATE app_config SET pdf_generation_enabled = 'Y';
```

### Rollback Testing

```sql
-- Test rollback procedures quarterly
@tests/test_rollback_procedures.sql

-- Scenarios:
-- 1. Simulated deployment failure
-- 2. Simulated performance regression
-- 3. Simulated data corruption
-- 4. Simulated breaking change discovery

-- Success criteria:
-- - Rollback completes in expected timeframe
-- - No data loss
-- - Full functionality restored
-- - No residual issues
```

---

## 📞 Support & Resources

### Migration Support Channels

- **GitHub Issues:** https://github.com/maxwbh/pl_fpdf/issues
- **Discussions:** https://github.com/maxwbh/pl_fpdf/discussions
- **Email:** maxwbh@gmail.com
- **Documentation:** https://github.com/maxwbh/pl_fpdf/wiki

### Migration Tools

| Tool | Purpose | Location |
|------|---------|----------|
| Version Detector | Check current version | `tools/detect_version.sql` |
| Compatibility Checker | Assess migration readiness | `tools/check_compatibility.sql` |
| Migration Script | Automated migration | `migration/migrate_to_vX.sql` |
| Rollback Script | Revert to previous version | `rollback/revert_to_vX.sql` |
| Test Suite | Validate migration | `tests/migration_suite.sql` |

### Professional Services

For enterprise migrations requiring:
- Custom migration scripts
- Performance optimization
- 24/7 support during migration
- Training and knowledge transfer

Contact: maxwbh@gmail.com

---

## 📊 Success Metrics

Track these metrics to measure migration success:

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Test pass rate | 100% | ___ | ⏳ |
| Performance vs baseline | ±5% | ___ | ⏳ |
| Migration duration | < 2 weeks | ___ | ⏳ |
| Production issues | 0 critical | ___ | ⏳ |
| Rollback events | 0 | ___ | ⏳ |
| User satisfaction | > 90% | ___ | ⏳ |

---

## 🎯 Conclusion

This roadmap provides a comprehensive strategy for migrating PL_FPDF across versions, from current v3.0.0-b.2 through future v4.0.0. Key takeaways:

✅ **Backward Compatibility:** v3.x maintains full compatibility with v2.0.0
✅ **Gradual Migration:** Multiple strategies available based on risk tolerance
✅ **Clear Timeline:** Structured phases with realistic timelines
✅ **Risk Management:** Comprehensive mitigation and rollback plans
✅ **Testing First:** Extensive test coverage at each stage
✅ **Oracle Evolution:** Aligned with Oracle 26ai roadmap

**Next Steps:**
1. Review this roadmap with stakeholders
2. Select migration strategy
3. Schedule migration windows
4. Execute pre-migration testing
5. Follow selected migration path

---

**Document Version:** 1.0
**Last Updated:** 2026-01
**Author:** @maxwbh
**Status:** Living Document (update quarterly)

**Related Documents:**
- [MIGRATION_GUIDE.md](../guides/MIGRATION_GUIDE.md) - v0.9 → v2.0 → v3.0
- [MODERNIZATION_ORACLE_26_APEX_24_2.md](../architecture/MODERNIZATION_ORACLE_26_APEX_24_2.md) - Oracle 26ai features
- [CHANGELOG.md](../../CHANGELOG.md) - Version history
- [PHASE_5_IMPLEMENTATION_PLAN.md](../plans/PHASE_5_IMPLEMENTATION_PLAN.md) - v3.1 features
