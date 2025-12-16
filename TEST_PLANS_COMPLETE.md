# PL_FPDF - Comprehensive Test Plans for Modernization
# Oracle 19c/23c Modernization Project

> **Complete Test Planning Document for Tasks 1.2 - 4.7**

---

## 📋 Document Information

| Field | Value |
|-------|-------|
| **Project** | PL_FPDF Modernization Test Plans |
| **Author** | Maxwell da Silva Oliveira (@maxwbh) |
| **Company** | M&S do Brasil LTDA |
| **Email** | maxwbh@gmail.com |
| **Date** | 2025-12-15 |
| **Version** | 1.0 |
| **Total Tasks** | 25 (Tasks 1.2 - 4.7) |
| **Total Test Cases** | ~450+ |

---

## 📊 Test Plan Summary

### Overview

| Phase | Tasks | Estimated Tests | Coverage Target |
|-------|-------|----------------|-----------------|
| **Phase 1** | 1.2-1.7 (6 tasks) | ~180 tests | >90% |
| **Phase 2** | 2.1-2.8 (8 tasks) | ~150 tests | >85% |
| **Phase 3** | 3.1-3.4 (4 tasks) | ~80 tests | >85% |
| **Phase 4** | 4.1-4.7 (7 tasks) | ~120 tests | >80% |
| **TOTAL** | **25 tasks** | **~530 tests** | **>85%** |

### Test Methodology

- **Framework:** utPLSQL v3+ (with fallback to PL/SQL pure)
- **Automation:** 100% automated tests
- **CI/CD:** Integrated with build pipeline
- **Performance:** Benchmark tests for critical operations
- **Security:** Injection and validation tests

---

## 🎯 Table of Contents - Test Plans

### [PHASE 1: Critical Refactoring](#phase-1-critical-refactoring)
- [Task 1.2: AddPage/SetPage BLOB Streaming](#task-12-test-plan---addpagesetpage-blob-streaming)
- [Task 1.3: SetFont/AddFont TrueType Support](#task-13-test-plan---setfontaddfont-truetype)
- [Task 1.4: Cell/MultiCell/Write Modernization](#task-14-test-plan---cellmulticellwrite)
- [Task 1.5: Remove OWA/HTP Dependency](#task-15-test-plan---remove-owahtp)
- [Task 1.6: Replace OrdImage](#task-16-test-plan---replace-ordimage)
- [Task 1.7: CLOB Buffer Refactoring](#task-17-test-plan---clob-buffer-refactoring)

### [PHASE 2: Security and Robustness](#phase-2-security-and-robustness)
- [Task 2.1: Complete UTF-8/Unicode Support](#task-21-test-plan---utf-8unicode-complete)
- [Task 2.2: Custom Exceptions](#task-22-test-plan---custom-exceptions)
- [Task 2.3: Input Validation with DBMS_ASSERT](#task-23-test-plan---dbms_assert-validation)
- [Task 2.4: Remove WHEN OTHERS](#task-24-test-plan---remove-when-others)
- [Task 2.5: Structured Logging](#task-25-test-plan---structured-logging)
- [Task 2.6: JSON Metadata](#task-26-test-plan---json-metadata)
- [Task 2.7: Page Counters](#task-27-test-plan---page-counters)
- [Task 2.8: Text/Ln Rotation](#task-28-test-plan---textln-rotation)

### [PHASE 3: Graphics and Layout](#phase-3-graphics-and-layout)
- [Task 3.1: Advanced Graphics (Line/Rect/Circle)](#task-31-test-plan---advanced-graphics)
- [Task 3.2: CMYK/Alpha Color Support](#task-32-test-plan---cmykalpha-colors)
- [Task 3.3: Dynamic Header/Footer](#task-33-test-plan---dynamic-headerfooter)
- [Task 3.4: Per-Page Margins](#task-34-test-plan---per-page-margins)

### [PHASE 4: Advanced Features](#phase-4-advanced-features)
- [Task 4.1: Modern Code Structure](#task-41-test-plan---modern-structure)
- [Task 4.2: JSON Configuration Support](#task-42-test-plan---json-configuration)
- [Task 4.3: Native PNG/JPEG Parser](#task-43-test-plan---native-pngjpeg-parser)
- [Task 4.4: utPLSQL Unit Tests](#task-44-test-plan---utplsql-unit-tests)
- [Task 4.5: Documentation](#task-45-test-plan---documentation)
- [Task 4.6: Performance Tuning](#task-46-test-plan---performance-tuning)
- [Task 4.7: Oracle 19c/26c Compatibility](#task-47-test-plan---oracle-19c26c-compatibility)

---

# PHASE 1: Critical Refactoring

---

## Task 1.2: Test Plan - AddPage/SetPage BLOB Streaming

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-1.2 |
| **Test Groups** | 8 |
| **Total Test Cases** | 32 |
| **Estimated Runtime** | 5-10 seconds |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Verify CLOB-based page storage works correctly
2. Validate all page formats (standard and custom)
3. Test page rotation (0°, 90°, 180°, 270°)
4. Ensure large documents (>1000 pages) work without memory issues
5. Validate SetPage() navigation
6. Test orientation switching (Portrait/Landscape)

### 📋 Test Groups

#### Group 1: Basic Page Creation (8 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.1 | AddPage with default params | Page created with P/A4/0° |
| T1.2.2 | AddPage Portrait A4 | Page created, orientation='P' |
| T1.2.3 | AddPage Landscape A4 | Page created, orientation='L', dims swapped |
| T1.2.4 | AddPage Letter format | Page 215.9x279.4mm created |
| T1.2.5 | AddPage Legal format | Page 215.9x355.6mm created |
| T1.2.6 | AddPage A3 format | Page 297x420mm created |
| T1.2.7 | AddPage A5 format | Page 148x210mm created |
| T1.2.8 | AddPage NULL params | Uses default orientation/format |

**Validation:**
- Page number increments correctly
- CLOB created for each page
- Page dimensions correct for format
- Orientation applied correctly

#### Group 2: Custom Page Formats (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.9 | Custom format "100,200" | Page 100x200mm created |
| T1.2.10 | Custom format "500,300" | Page 500x300mm created |
| T1.2.11 | Invalid format "abc,xyz" | Error -20103 raised |
| T1.2.12 | Invalid format "20000,30000" | Error -20102 (too large) |
| T1.2.13 | Custom format negative values | Error raised |

**Validation:**
- Custom dimensions parsed correctly
- Width/height stored in recPageFormat
- Validation rejects invalid inputs

#### Group 3: Page Rotation (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.14 | Rotation 0° (default) | No rotation matrix applied |
| T1.2.15 | Rotation 90° | Rotation matrix written to CLOB |
| T1.2.16 | Rotation 180° | Rotation matrix written |
| T1.2.17 | Rotation 270° | Rotation matrix written |
| T1.2.18 | Invalid rotation 45° | Error -20104 raised |

**Validation:**
- Rotation value stored in g_pages(n).rotation
- PDF transformation matrix correct for each angle

#### Group 4: Large Documents (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.19 | Create 100 pages | All created, no memory errors |
| T1.2.20 | Create 500 pages | All created, performance acceptable |
| T1.2.21 | Create 1000 pages | All created, log messages at 100/200/... |
| T1.2.22 | Create 2000 pages | All created, no ORA-04030 |

**Validation:**
- Memory usage stays reasonable (<500MB)
- CLOBs created/freed properly
- Performance: <1ms per page average

#### Group 5: SetPage Navigation (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.23 | SetPage(1) after creating 3 pages | Current page = 1, w/h correct |
| T1.2.24 | SetPage(2) | Current page = 2 |
| T1.2.25 | SetPage(999) when only 10 exist | Error -20106 raised |
| T1.2.26 | SetPage before Init | Error -20105 raised |

**Validation:**
- g_current_page updated correctly
- Global w/h variables match page format
- Previous page closed properly

#### Group 6: State Management (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.27 | g_state after AddPage | g_state = 1 (page open) |
| T1.2.28 | g_state after p_endpage | g_state = 0 |
| T1.2.29 | AddPage calls p_endpage for previous | Previous page closed |

**Validation:**
- State transitions correct
- Only one page open at a time

#### Group 7: Edge Cases (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.30 | AddPage before Init | Error -20100 raised |
| T1.2.31 | Mixed orientations in doc | Each page has correct orientation |

#### Group 8: GetCurrentPage (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.2.32 | GetCurrentPage after 5 pages | Returns 5 |

### ✅ Success Criteria

- [ ] All 32 tests pass
- [ ] 1000+ pages created without errors
- [ ] Memory usage < 500MB for 1000 pages
- [ ] All orientations/formats work
- [ ] Rotation matrices correct

---

## Task 1.3: Test Plan - SetFont/AddFont TrueType

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-1.3 |
| **Test Groups** | 10 |
| **Total Test Cases** | 38 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate TrueType font loading from BLOB
2. Test font caching mechanism
3. Verify Unicode character handling
4. Test font metrics extraction (widths, ascent, descent)
5. Validate legacy 14 standard fonts still work
6. Test font embedding in PDF

### 📋 Test Groups

#### Group 1: Legacy Font Support (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.1 | SetFont('Arial') | Font set, no errors |
| T1.3.2 | SetFont('Helvetica') | Font set |
| T1.3.3 | SetFont('Times') | Font set |
| T1.3.4 | SetFont('Courier') | Font set |
| T1.3.5 | SetFont with styles 'B', 'I', 'BI' | Styles applied |
| T1.3.6 | SetFont unknown legacy font | Fallback to Arial |

#### Group 2: TrueType Loading from BLOB (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.7 | AddTTFFont with valid TTF BLOB | Font loaded, name extracted |
| T1.3.8 | AddTTFFont with invalid BLOB | Error raised |
| T1.3.9 | AddTTFFont duplicate name | Font replaced |
| T1.3.10 | AddTTFFont then SetFont | Font active |
| T1.3.11 | Load TTF with UTF-8 encoding | Encoding stored |
| T1.3.12 | Load TTF with ISO-8859-1 | Encoding stored |

**Validation:**
- TTF header parsed correctly
- Font name extracted from name table
- UnitsPerEm from head table
- Font cached in g_ttf_fonts

#### Group 3: TrueType Loading from File (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.13 | LoadTTFFromFile with valid path | Font loaded |
| T1.3.14 | LoadTTFFromFile invalid path | Error raised |
| T1.3.15 | LoadTTFFromFile with directory | Font loaded from FONTS_DIR |
| T1.3.16 | LoadTTFFromFile large font (>10MB) | Font loaded |

#### Group 4: Font Caching (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.17 | Load same TTF twice | Second load uses cache |
| T1.3.18 | Cache hit performance | <1ms for cached font |
| T1.3.19 | Cache stores font BLOB | BLOB accessible |
| T1.3.20 | Reset clears font cache | Cache empty after Reset |

#### Group 5: Font Metrics (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.21 | Extract UnitsPerEm from TTF | Value >100 |
| T1.3.22 | Extract Ascent from hhea | Value correct |
| T1.3.23 | Extract Descent from hhea | Value correct (negative) |
| T1.3.24 | Extract character widths | Width array populated |
| T1.3.25 | GetStringWidth with TTF | Correct width calculated |
| T1.3.26 | GetStringWidth with Unicode | Multi-byte chars handled |

**Validation:**
- Metrics match font file
- Width calculations accurate

#### Group 6: Unicode Support (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.27 | SetFont with UTF-8, text "日本語" | Japanese chars handled |
| T1.3.28 | SetFont with UTF-8, text "Ñoño" | Spanish chars handled |
| T1.3.29 | SetFont UTF-8, emoji "😀" | Emoji handled (or error) |
| T1.3.30 | GetStringWidth Unicode | Correct width for multi-byte |
| T1.3.31 | TTF subset for used chars only | Subset created |

#### Group 7: Font Embedding (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.32 | Embed TTF in PDF output | Font stream in PDF |
| T1.3.33 | Use embedded font in Cell | Text renders in PDF |
| T1.3.34 | Multiple embedded fonts | All fonts in PDF |

#### Group 8: Parameter Validation (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.35 | SetFont NULL family | Error raised |
| T1.3.36 | SetFont size <0 | Error raised |

#### Group 9: Font Styles (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.37 | Combine TTF with style 'B' | Bold variant used |

#### Group 10: Edge Cases (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.3.38 | SetFont before Init | Error raised |

### ✅ Success Criteria

- [ ] All 38 tests pass
- [ ] TTF fonts load correctly
- [ ] Unicode characters work
- [ ] Font caching reduces load time
- [ ] Legacy fonts still work

---

## Task 1.4: Test Plan - Cell/MultiCell/Write

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-1.4 |
| **Test Groups** | 8 |
| **Total Test Cases** | 30 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate BLOB output instead of string concatenation
2. Test text rotation in cells
3. Verify improved text alignment (justify, center, etc.)
4. Test hyperlinks in cells
5. Validate border drawing
6. Test cell fill colors
7. Verify MultiCell line breaking

### 📋 Test Groups

#### Group 1: Basic Cell Functionality (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.1 | Cell with default params | Cell drawn at current position |
| T1.4.2 | Cell with width 50, height 10 | Correct dimensions |
| T1.4.3 | Cell with text "Hello" | Text in cell |
| T1.4.4 | Cell with border '1' | All borders drawn |
| T1.4.5 | Cell with border 'LTRB' | Specific borders |
| T1.4.6 | Cell with fill=TRUE | Background filled |

#### Group 2: Cell Alignment (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.7 | Cell align='L' | Text left-aligned |
| T1.4.8 | Cell align='C' | Text centered |
| T1.4.9 | Cell align='R' | Text right-aligned |
| T1.4.10 | Cell align='J' | Text justified |
| T1.4.11 | Cell align invalid | Default to left |

#### Group 3: Cell Rotation (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.12 | Cell with rotation=0 | No rotation |
| T1.4.13 | Cell with rotation=90 | Text rotated 90° |
| T1.4.14 | Cell with rotation=180 | Text rotated 180° |
| T1.4.15 | Cell with rotation=270 | Text rotated 270° |

**Validation:**
- Rotation matrix in page CLOB
- Text position calculated correctly

#### Group 4: Cell Hyperlinks (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.16 | Cell with link='http://...' | Link annotation created |
| T1.4.17 | Cell with link=AddLink() | Internal link created |

#### Group 5: MultiCell Line Breaking (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.18 | MultiCell with short text | Single line |
| T1.4.19 | MultiCell with long text | Multiple lines, wrapped |
| T1.4.20 | MultiCell with manual \n | Break at \n |
| T1.4.21 | MultiCell max height limit | Stops at limit |
| T1.4.22 | MultiCell returns line count | Correct count |

#### Group 6: Write Function (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.23 | Write with flowing text | Text flows to next line |
| T1.4.24 | Write with link | Link applied |
| T1.4.25 | Write long paragraph | Wraps correctly |

#### Group 7: BLOB Output (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.26 | Cell output to page CLOB | CLOB contains cell commands |
| T1.4.27 | 1000 cells performance | CLOB append efficient |
| T1.4.28 | Cell with UTF-8 text | UTF-8 encoded in CLOB |

#### Group 8: Edge Cases (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.4.29 | Cell before AddPage | Error or auto-page |
| T1.4.30 | Cell causes page break | Auto break works |

### ✅ Success Criteria

- [ ] All 30 tests pass
- [ ] Rotation works correctly
- [ ] BLOB output efficient
- [ ] Hyperlinks functional
- [ ] Line breaking accurate

---

## Task 1.5: Test Plan - Remove OWA/HTP

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-1.5 |
| **Test Groups** | 5 |
| **Total Test Cases** | 18 |
| **Coverage Target** | >95% |

### 🎯 Test Objectives

1. Verify OWA/HTP completely removed from code
2. Test new OutputBlob() function
3. Test OutputFile() function
4. Test OutputEmail() function (optional)
5. Validate backward compatibility

### 📋 Test Groups

#### Group 1: OWA/HTP Removal Verification (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.5.1 | Grep for 'htp.p' in code | 0 occurrences |
| T1.5.2 | Grep for 'owa_util' in code | 0 occurrences |
| T1.5.3 | Compile package | No missing dependencies |
| T1.5.4 | Check dependencies view | No OWA references |

#### Group 2: OutputBlob() Function (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.5.5 | OutputBlob() returns BLOB | BLOB returned |
| T1.5.6 | BLOB starts with %PDF-1.4 | Valid PDF signature |
| T1.5.7 | BLOB contains all pages | All pages in output |
| T1.5.8 | BLOB size >0 | Non-empty BLOB |
| T1.5.9 | OutputBlob() multiple calls | Each returns fresh BLOB |

**Validation:**
- BLOB contains valid PDF structure
- All content from CLOBs merged correctly

#### Group 3: OutputFile() Function (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.5.10 | OutputFile to valid directory | File created |
| T1.5.11 | OutputFile invalid path | Error raised |
| T1.5.12 | OutputFile overwrite existing | File replaced |
| T1.5.13 | File content = BLOB | Contents match |

#### Group 4: OutputEmail() (Optional) (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.5.14 | OutputEmail with valid address | Email sent |
| T1.5.15 | Email contains PDF attachment | Attachment present |

#### Group 5: Backward Compatibility (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.5.16 | Old Output() with pdest='F' | Works via OutputFile |
| T1.5.17 | Old Output() with pdest='D' | Returns BLOB |
| T1.5.18 | ReturnBlob() still works | BLOB returned |

### ✅ Success Criteria

- [ ] All 18 tests pass
- [ ] Zero OWA/HTP references
- [ ] All output methods work
- [ ] Backward compatibility maintained

---

## Task 1.6: Test Plan - Replace OrdImage

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-1.6 |
| **Test Groups** | 6 |
| **Total Test Cases** | 24 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Verify OrdImage completely removed
2. Test PNG parsing from BLOB
3. Test JPEG parsing from BLOB
4. Validate image dimensions extraction
5. Test image embedding in PDF
6. Performance comparison vs OrdImage

### 📋 Test Groups

#### Group 1: OrdImage Removal (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.6.1 | Grep for 'ordimage' in code | 0 occurrences |
| T1.6.2 | Grep for 'ordsys' in code | 0 occurrences |
| T1.6.3 | Package compiles without ordImage | Success |

#### Group 2: PNG Parsing (8 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.6.4 | Parse PNG signature | Valid signature detected |
| T1.6.5 | Parse PNG IHDR chunk | Width/height extracted |
| T1.6.6 | Parse PNG bit depth | Bit depth extracted |
| T1.6.7 | Parse PNG color type | Color type extracted |
| T1.6.8 | Parse PNG with PLTE | Palette extracted |
| T1.6.9 | Parse PNG with tRNS | Transparency extracted |
| T1.6.10 | Parse interlaced PNG | Interlace detected |
| T1.6.11 | Invalid PNG BLOB | Error raised |

**Validation:**
- All PNG chunks parsed correctly
- CRC validation for chunks
- Image dimensions match actual file

#### Group 3: JPEG Parsing (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.6.12 | Parse JPEG signature FFD8 | Valid signature |
| T1.6.13 | Parse JPEG SOF marker | Width/height extracted |
| T1.6.14 | Parse JPEG color space | RGB/CMYK detected |
| T1.6.15 | Parse JPEG progressive | Progressive detected |
| T1.6.16 | Parse JPEG with EXIF | EXIF ignored/handled |
| T1.6.17 | Invalid JPEG BLOB | Error raised |

#### Group 4: Image Embedding (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.6.18 | Embed PNG in PDF | PNG stream in PDF |
| T1.6.19 | Embed JPEG in PDF | JPEG stream in PDF |
| T1.6.20 | Multiple images per page | All embedded |
| T1.6.21 | Image with transparency | Alpha channel handled |

#### Group 5: Image Positioning (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.6.22 | Image at x,y with w,h | Correct position/size |
| T1.6.23 | Image auto-scaling | Aspect ratio preserved |

#### Group 6: Performance (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.6.24 | Parse 100 images | <5 seconds total |

### ✅ Success Criteria

- [ ] All 24 tests pass
- [ ] OrdImage removed
- [ ] PNG/JPEG parsing functional
- [ ] Images render in PDF
- [ ] Performance acceptable

---

## Task 1.7: Test Plan - CLOB Buffer Refactoring

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-1.7 |
| **Test Groups** | 6 |
| **Total Test Cases** | 22 |
| **Coverage Target** | >95% |

### 🎯 Test Objectives

1. Verify VARCHAR2 array removed
2. Test CLOB buffer for entire document
3. Validate DBMS_LOB operations
4. Test performance of CLOB vs array
5. Validate memory usage improvement
6. Test very large documents (10,000+ pages)

### 📋 Test Groups

#### Group 1: Array Removal Verification (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.7.1 | Search for 'tv32k' type | 0 occurrences |
| T1.7.2 | Search for 'pdfDoc tv32k' | 0 occurrences |
| T1.7.3 | Package uses g_pdf_clob only | Verified |

#### Group 2: CLOB Operations (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.7.4 | DBMS_LOB.CREATETEMPORARY | CLOB created |
| T1.7.5 | DBMS_LOB.WRITEAPPEND | Content appended |
| T1.7.6 | DBMS_LOB.FREETEMPORARY | CLOB freed |
| T1.7.7 | Append 100k times | No errors |
| T1.7.8 | CLOB size after 1000 pages | >10MB |
| T1.7.9 | DBMS_LOB.GETLENGTH | Correct length |

#### Group 3: Performance Tests (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.7.10 | p_out() 10k times | <100ms total |
| T1.7.11 | CLOB vs array benchmark | CLOB ≥ array speed |
| T1.7.12 | Memory usage with CLOB | <50MB for 1000 pages |
| T1.7.13 | Memory usage old array | >200MB for 1000 pages |
| T1.7.14 | Append efficiency | O(1) complexity |

**Validation:**
- CLOB is at least as fast as array
- Memory footprint significantly reduced

#### Group 4: Large Documents (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.7.15 | 1000 pages document | Success |
| T1.7.16 | 5000 pages document | Success |
| T1.7.17 | 10000 pages document | Success, <2GB memory |
| T1.7.18 | CLOB max size check | Can handle >4GB |

#### Group 5: Content Integrity (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.7.19 | Write, read back content | Content matches |
| T1.7.20 | UTF-8 content preserved | No corruption |
| T1.7.21 | Binary data in CLOB | Preserved correctly |

#### Group 6: Edge Cases (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T1.7.22 | p_out() with empty string | No error |

### ✅ Success Criteria

- [ ] All 22 tests pass
- [ ] VARCHAR2 array removed
- [ ] Memory usage reduced >60%
- [ ] 10,000 pages work
- [ ] No performance regression

---

# PHASE 2: Security and Robustness

---

## Task 2.1: Test Plan - UTF-8/Unicode Complete

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.1 |
| **Test Groups** | 7 |
| **Total Test Cases** | 26 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate full UTF-8 support across all functions
2. Test multi-byte character handling
3. Test emoji and special Unicode characters
4. Validate character width calculations for Unicode
5. Test UTF-8 in metadata
6. Test various languages (CJK, Arabic, Hebrew, etc.)

### 📋 Test Groups

#### Group 1: Basic UTF-8 (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.1 | Cell with "Héllo Wörld" | Accents display |
| T2.1.2 | Cell with "日本語" (Japanese) | Japanese chars display |
| T2.1.3 | Cell with "中文" (Chinese) | Chinese chars display |
| T2.1.4 | Cell with "한국어" (Korean) | Korean chars display |

#### Group 2: Multi-byte Characters (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.5 | LENGTHB vs LENGTH for "日" | Different values |
| T2.1.6 | SUBSTRB correct for UTF-8 | No char corruption |
| T2.1.7 | Character position calculation | Correct positions |
| T2.1.8 | GetStringWidth for "日本語" | Correct width |
| T2.1.9 | Line breaking on multi-byte | Breaks at char boundary |

#### Group 3: Special Characters (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.10 | Emoji "😀🎉" | Emoji displayed or error |
| T2.1.11 | Right-to-left "العربية" | RTL handled |
| T2.1.12 | Hebrew "עברית" | Hebrew displayed |
| T2.1.13 | Mathematical symbols "∑∫≠" | Symbols displayed |

#### Group 4: Encoding Conversion (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.14 | CONVERT to UTF-8 | Correct conversion |
| T2.1.15 | UTF-8 to ISO-8859-1 fallback | Handled gracefully |
| T2.1.16 | Invalid UTF-8 sequence | Error or replacement char |
| T2.1.17 | BOM handling | BOM removed or handled |

#### Group 5: Metadata UTF-8 (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.18 | SetTitle with UTF-8 | Title in PDF correct |
| T2.1.19 | SetAuthor with UTF-8 | Author in PDF correct |
| T2.1.20 | SetKeywords with UTF-8 | Keywords correct |

#### Group 6: Font Support (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.21 | UTF-8 with Arial (no Unicode) | Fallback or error |
| T2.1.22 | UTF-8 with TrueType Unicode | Characters display |
| T2.1.23 | Missing glyphs in font | Replacement glyph |
| T2.1.24 | Font subset for used chars | Subset correct |

#### Group 7: Performance (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.1.25 | 1000 UTF-8 cells | No slowdown |
| T2.1.26 | Large UTF-8 string (10k chars) | Handled efficiently |

### ✅ Success Criteria

- [ ] All 26 tests pass
- [ ] CJK characters work
- [ ] RTL languages handled
- [ ] No character corruption
- [ ] Unicode in metadata

---

## Task 2.2: Test Plan - Custom Exceptions

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.2 |
| **Test Groups** | 5 |
| **Total Test Cases** | 20 |
| **Coverage Target** | >95% |

### 🎯 Test Objectives

1. Verify all custom exceptions defined
2. Test exception raising conditions
3. Validate exception messages
4. Test exception handling in calling code
5. Ensure SQLCODE ranges don't conflict

### 📋 Test Groups

#### Group 1: Exception Definitions (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.2.1 | exc_invalid_orientation defined | Exception exists |
| T2.2.2 | exc_invalid_unit defined | Exception exists |
| T2.2.3 | exc_invalid_encoding defined | Exception exists |
| T2.2.4 | exc_not_initialized defined | Exception exists |
| T2.2.5 | exc_invalid_page_format defined | Exception exists |
| T2.2.6 | exc_invalid_rotation defined | Exception exists |

**Additional exceptions to test:**
- exc_invalid_font
- exc_invalid_color
- exc_image_parse_error
- exc_file_write_error
- exc_clob_error
- etc. (15+ total)

#### Group 2: Exception Raising (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.2.7 | Invalid orientation raises exc | Specific exception raised |
| T2.2.8 | Not initialized raises exc | exc_not_initialized |
| T2.2.9 | Invalid font raises exc | exc_invalid_font |
| T2.2.10 | Image error raises exc | exc_image_parse_error |
| T2.2.11 | CLOB error raises exc | exc_clob_error |
| T2.2.12 | Generic error raises exc | exc_internal_error |

#### Group 3: Exception Messages (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.2.13 | Exception message descriptive | Contains context info |
| T2.2.14 | Exception includes param values | Parameter values in message |
| T2.2.15 | Exception message in English | English message |
| T2.2.16 | Exception backtrace included | Backtrace available |

#### Group 4: SQLCODE Ranges (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.2.17 | All exceptions -20000 to -20999 | In valid range |
| T2.2.18 | No SQLCODE conflicts | Each code unique |
| T2.2.19 | Documentation lists all codes | All documented |

#### Group 5: Exception Handling (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.2.20 | Catch specific exception | Caught by WHEN exc_name |

### ✅ Success Criteria

- [ ] All 20 tests pass
- [ ] 15+ custom exceptions defined
- [ ] No SQLCODE conflicts
- [ ] Descriptive error messages
- [ ] All exceptions documented

---

## Task 2.3: Test Plan - DBMS_ASSERT Validation

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.3 |
| **Test Groups** | 6 |
| **Total Test Cases** | 22 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate all user inputs with DBMS_ASSERT
2. Test SQL injection prevention
3. Test path traversal prevention
4. Validate object names
5. Test qualified SQL names
6. Performance impact assessment

### 📋 Test Groups

#### Group 1: String Input Validation (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.3.1 | Valid string input | Passes validation |
| T2.3.2 | String with SQL injection | Rejected |
| T2.3.3 | String with quotes | Escaped properly |
| T2.3.4 | Very long string (>32k) | Rejected or truncated |
| T2.3.5 | NULL string | Handled gracefully |

#### Group 2: Object Name Validation (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.3.6 | DBMS_ASSERT.SIMPLE_SQL_NAME | Valid names pass |
| T2.3.7 | Invalid object name | Exception raised |
| T2.3.8 | Object name with schema | QUALIFIED_SQL_NAME used |
| T2.3.9 | Reserved word as name | Handled |

#### Group 3: File Path Validation (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.3.10 | Valid file path | Passes |
| T2.3.11 | Path traversal "../../../etc" | Rejected |
| T2.3.12 | Absolute path on Windows | Validated |
| T2.3.13 | Absolute path on Linux | Validated |
| T2.3.14 | Special characters in path | Escaped |

#### Group 4: Numeric Validation (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.3.15 | Valid number input | Passes |
| T2.3.16 | Non-numeric string | TO_NUMBER raises error |
| T2.3.17 | Number out of range | Validation error |

#### Group 5: SQL Injection Prevention (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.3.18 | Input "'; DROP TABLE" | Rejected |
| T2.3.19 | Input with UNION SELECT | Rejected |
| T2.3.20 | Input with comment -- | Rejected |
| T2.3.21 | Input with /* */ | Rejected |

#### Group 6: Performance (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.3.22 | 10k validations | <1 second total |

### ✅ Success Criteria

- [ ] All 22 tests pass
- [ ] SQL injection prevented
- [ ] Path traversal prevented
- [ ] All inputs validated
- [ ] Minimal performance impact

---

## Task 2.4: Test Plan - Remove WHEN OTHERS

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.4 |
| **Test Groups** | 4 |
| **Total Test Cases** | 16 |
| **Coverage Target** | >95% |

### 🎯 Test Objectives

1. Verify all WHEN OTHERS removed
2. Test specific exception handling
3. Validate error propagation
4. Test exception context preservation
5. Verify logging of all exceptions

### 📋 Test Groups

#### Group 1: WHEN OTHERS Removal (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.4.1 | Grep for "WHEN OTHERS" | Only in specific allowed cases |
| T2.4.2 | Count WHEN OTHERS | <5 occurrences total |
| T2.4.3 | Each WHEN OTHERS justified | Comment explains why |
| T2.4.4 | No silent WHEN OTHERS | All log or re-raise |

#### Group 2: Specific Exception Handling (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.4.5 | NO_DATA_FOUND handled | Specific handler |
| T2.4.6 | TOO_MANY_ROWS handled | Specific handler |
| T2.4.7 | VALUE_ERROR handled | Specific handler |
| T2.4.8 | INVALID_NUMBER handled | Specific handler |
| T2.4.9 | DUP_VAL_ON_INDEX handled | Specific handler |
| T2.4.10 | Custom exceptions handled | Specific handlers |

#### Group 3: Error Context (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.4.11 | DBMS_UTILITY.FORMAT_ERROR_BACKTRACE | Used in logging |
| T2.4.12 | DBMS_UTILITY.FORMAT_ERROR_STACK | Used in logging |
| T2.4.13 | Exception includes operation | Context in message |
| T2.4.14 | Exception includes parameters | Parameters logged |

#### Group 4: Error Propagation (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.4.15 | Unhandled exception propagates | Caller receives it |
| T2.4.16 | Re-raised exception preserves stack | Stack intact |

### ✅ Success Criteria

- [ ] All 16 tests pass
- [ ] <5 WHEN OTHERS in code
- [ ] All exceptions specific
- [ ] Error context preserved
- [ ] All errors logged

---

## Task 2.5: Test Plan - Structured Logging

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.5 |
| **Test Groups** | 7 |
| **Total Test Cases** | 24 |
| **Coverage Target** | >85% |

### 🎯 Test Objectives

1. Validate logging infrastructure
2. Test log levels (DEBUG, INFO, WARN, ERROR)
3. Test log formatting
4. Validate DBMS_APPLICATION_INFO usage
5. Test log filtering
6. Validate performance logging
7. Test log rotation/cleanup

### 📋 Test Groups

#### Group 1: Log Levels (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.1 | Log at DEBUG level | Message logged when level=DEBUG |
| T2.5.2 | Log at INFO level | Message logged when level>=INFO |
| T2.5.3 | Log at WARN level | Message logged when level>=WARN |
| T2.5.4 | Log at ERROR level | Always logged |
| T2.5.5 | Set log level to WARN | DEBUG/INFO not logged |

#### Group 2: Log Formatting (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.6 | Log includes timestamp | Timestamp in message |
| T2.5.7 | Log includes level | Level in message |
| T2.5.8 | Log includes procedure name | Procedure name in message |
| T2.5.9 | Log includes session ID | SID in message |

#### Group 3: DBMS_APPLICATION_INFO (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.10 | SET_MODULE called | Module set |
| T2.5.11 | SET_ACTION called | Action set |
| T2.5.12 | SET_CLIENT_INFO called | Client info set |
| T2.5.13 | Query V$SESSION shows info | Info visible |

#### Group 4: Log Destinations (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.14 | Log to DBMS_OUTPUT | Message in output |
| T2.5.15 | Log to table | Row inserted |
| T2.5.16 | Log to file (UTL_FILE) | File written |

#### Group 5: Contextual Logging (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.17 | Log with parameters | Parameters in message |
| T2.5.18 | Log with exception | Exception details in log |
| T2.5.19 | Log with call stack | Call stack in log |

#### Group 6: Performance (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.20 | Log 10k messages | <1 second |
| T2.5.21 | Log disabled | Zero overhead |
| T2.5.22 | Log timing information | Elapsed time logged |

#### Group 7: Log Management (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.5.23 | Purge old logs | Old entries removed |
| T2.5.24 | Log table size limit | Entries rotated |

### ✅ Success Criteria

- [ ] All 24 tests pass
- [ ] All log levels work
- [ ] DBMS_APPLICATION_INFO used
- [ ] Performance impact minimal
- [ ] Log management functional

---

## Task 2.6: Test Plan - JSON Metadata

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.6 |
| **Test Groups** | 6 |
| **Total Test Cases** | 22 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate JSON metadata storage
2. Test JSON_OBJECT_T usage
3. Test metadata in PDF output
4. Validate standard metadata fields
5. Test custom metadata
6. Validate JSON parsing/serialization

### 📋 Test Groups

#### Group 1: JSON_OBJECT_T Basic (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.6.1 | Create JSON_OBJECT_T | Object created |
| T2.6.2 | Put string value | Value stored |
| T2.6.3 | Get string value | Value retrieved |
| T2.6.4 | Serialize to string | Valid JSON string |

#### Group 2: Standard Metadata (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.6.5 | SetTitle stores in JSON | Title in metadata JSON |
| T2.6.6 | SetAuthor stores in JSON | Author in metadata JSON |
| T2.6.7 | SetSubject stores in JSON | Subject in metadata JSON |
| T2.6.8 | SetKeywords stores in JSON | Keywords in metadata JSON |
| T2.6.9 | SetCreator stores in JSON | Creator in metadata JSON |
| T2.6.10 | CreationDate auto-added | Date in metadata JSON |

#### Group 3: Custom Metadata (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.6.11 | Add custom field "Department" | Field in JSON |
| T2.6.12 | Add custom field "ProjectID" | Field in JSON |
| T2.6.13 | Nested JSON object | Nested structure works |
| T2.6.14 | JSON array in metadata | Array works |

#### Group 4: PDF Output (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.6.15 | Metadata in PDF /Info | /Info dict contains metadata |
| T2.6.16 | UTF-8 metadata in PDF | UTF-8 encoded correctly |
| T2.6.17 | XMP metadata stream | XMP created from JSON |

#### Group 5: Metadata Retrieval (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.6.18 | GetMetadata returns JSON | JSON_OBJECT_T returned |
| T2.6.19 | GetMetadataString | JSON string returned |
| T2.6.20 | GetMetadataValue by key | Specific value returned |

#### Group 6: Edge Cases (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.6.21 | Metadata before Init | Error or empty |
| T2.6.22 | Very long metadata value | Truncated or stored |

### ✅ Success Criteria

- [ ] All 22 tests pass
- [ ] JSON_OBJECT_T works
- [ ] Metadata in PDF
- [ ] Custom fields supported
- [ ] UTF-8 in metadata

---

## Task 2.7: Test Plan - Page Counters

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.7 |
| **Test Groups** | 5 |
| **Total Test Cases** | 18 |
| **Coverage Target** | >95% |

### 🎯 Test Objectives

1. Validate PageNo() function accuracy
2. Test AliasNbPages functionality
3. Test page number replacement
4. Validate counter types (PLS_INTEGER)
5. Test page numbering formats

### 📋 Test Groups

#### Group 1: PageNo() Function (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.7.1 | PageNo() before AddPage | Returns 0 |
| T2.7.2 | PageNo() on page 1 | Returns 1 |
| T2.7.3 | PageNo() on page 100 | Returns 100 |
| T2.7.4 | PageNo() after SetPage(5) | Returns 5 |

#### Group 2: AliasNbPages (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.7.5 | SetAliasNbPages('{nb}') | Alias set |
| T2.7.6 | Cell with '{nb}' text | Replaced with page count |
| T2.7.7 | Multiple '{nb}' in doc | All replaced |
| T2.7.8 | Custom alias '{total}' | Custom alias works |
| T2.7.9 | Alias in header/footer | Replaced correctly |

#### Group 3: Counter Types (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.7.10 | g_page is PLS_INTEGER | Type correct |
| T2.7.11 | g_n is PLS_INTEGER | Type correct |
| T2.7.12 | Counter overflow test | Handles large values |
| T2.7.13 | Counter underflow test | Handles 0/negative |

#### Group 4: Page Numbering Formats (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.7.14 | Format "Page X of Y" | Formatted correctly |
| T2.7.15 | Format "X/Y" | Formatted correctly |
| T2.7.16 | Roman numerals (I, II, III) | Conversion works |

#### Group 5: Edge Cases (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.7.17 | 10,000 pages numbering | All numbered correctly |
| T2.7.18 | Delete page, renumber | Numbers sequential |

### ✅ Success Criteria

- [ ] All 18 tests pass
- [ ] PageNo() accurate
- [ ] AliasNbPages works
- [ ] Large page counts supported
- [ ] Numbering formats work

---

## Task 2.8: Test Plan - Text/Ln Rotation

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-2.8 |
| **Test Groups** | 5 |
| **Total Test Cases** | 18 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate Text() with rotation parameter
2. Test Ln() functionality preserved
3. Test rotation angles (0°, 90°, 180°, 270°, arbitrary)
4. Validate rotation matrix calculations
5. Test combined transformations

### 📋 Test Groups

#### Group 1: Text() Basic (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.8.1 | Text(x, y, "Hello") no rotation | Text at position |
| T2.8.2 | Text with UTF-8 | UTF-8 rendered |
| T2.8.3 | Text outside page bounds | Clipped or error |

#### Group 2: Text() Rotation (6 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.8.4 | Text rotation 0° | Normal horizontal |
| T2.8.5 | Text rotation 90° | Vertical upward |
| T2.8.6 | Text rotation 180° | Upside down |
| T2.8.7 | Text rotation 270° | Vertical downward |
| T2.8.8 | Text rotation 45° | Diagonal |
| T2.8.9 | Text rotation -90° | Equivalent to 270° |

**Validation:**
- Rotation matrix in PDF correct
- Text origin point preserved

#### Group 3: Rotation Matrix (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.8.10 | Matrix for 90° | Correct matrix values |
| T2.8.11 | Matrix for 45° | cos/sin calculated |
| T2.8.12 | Matrix translation | Origin translated |
| T2.8.13 | Nested rotations | Matrices combined |

#### Group 4: Ln() Function (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.8.14 | Ln() default height | Y += current line height |
| T2.8.15 | Ln(10) custom height | Y += 10 |
| T2.8.16 | Ln() with rotation active | Works correctly |

#### Group 5: Combined Operations (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T2.8.17 | Text rotated + Cell | Both render |
| T2.8.18 | Multiple Text different angles | All render correctly |

### ✅ Success Criteria

- [ ] All 18 tests pass
- [ ] All rotation angles work
- [ ] Rotation matrices correct
- [ ] Ln() unaffected
- [ ] Combined operations work

---

# PHASE 3: Graphics and Layout

---

## Task 3.1: Test Plan - Advanced Graphics

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-3.1 |
| **Test Groups** | 8 |
| **Total Test Cases** | 28 |
| **Coverage Target** | >85% |

### 🎯 Test Objectives

1. Test Line() with advanced styles
2. Test Rect() with rounded corners
3. Test Circle() and Ellipse()
4. Test path operations (stroke, fill, clip)
5. Validate coordinate precision
6. Test graphic state stack
7. Test bezier curves
8. Test polygon improvements

### 📋 Test Groups

#### Group 1: Line() Advanced (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.1 | Line with dash pattern | Dashed line |
| T3.1.2 | Line with width | Correct width |
| T3.1.3 | Line with cap style | Cap applied |
| T3.1.4 | Line with join style | Join applied |
| T3.1.5 | Diagonal line precision | Sub-pixel precision |

#### Group 2: Rect() Advanced (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.6 | Rect with rounded corners | Rounded |
| T3.1.7 | Rect fill='F' | Filled |
| T3.1.8 | Rect fill='D' | Filled+stroked |
| T3.1.9 | Rect fill='S' | Stroked only |
| T3.1.10 | Rect with rotation | Rotated rectangle |

#### Group 3: Circle/Ellipse (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.11 | Circle(x, y, r) | Perfect circle |
| T3.1.12 | Ellipse(x, y, rx, ry) | Ellipse drawn |
| T3.1.13 | Circle fill | Filled circle |
| T3.1.14 | Circle stroke | Stroked circle |

**Validation:**
- Bezier approximation accurate

#### Group 4: Bezier Curves (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.15 | Bezier cubic curve | Curve drawn |
| T3.1.16 | Bezier quadratic curve | Curve drawn |
| T3.1.17 | Complex path with beziers | Path drawn |

#### Group 5: Polygon Enhancements (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.18 | Poly with fill | Filled polygon |
| T3.1.19 | Poly with stroke | Stroked polygon |
| T3.1.20 | Poly closed vs open | Closed correctly |
| T3.1.21 | Complex polygon (100 points) | All points rendered |

#### Group 6: Graphic State (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.22 | Save graphic state (q) | State saved |
| T3.1.23 | Restore graphic state (Q) | State restored |
| T3.1.24 | Nested save/restore | Stack works |

#### Group 7: Coordinate Precision (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.25 | Sub-pixel coordinates (0.5px) | Rendered at 0.5 |
| T3.1.26 | Very large coordinates (10000) | Handled |

#### Group 8: Clipping (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.1.27 | Rect as clipping path | Clip applied |
| T3.1.28 | Circle as clipping path | Clip applied |

### ✅ Success Criteria

- [ ] All 28 tests pass
- [ ] Advanced styles work
- [ ] Rounded corners functional
- [ ] Bezier curves accurate
- [ ] Graphic state stack works

---

## Task 3.2: Test Plan - CMYK/Alpha Colors

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-3.2 |
| **Test Groups** | 6 |
| **Total Test Cases** | 22 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Test CMYK color support
2. Test alpha/transparency (soft masks)
3. Test RGB colors (existing)
4. Test grayscale colors
5. Validate color space conversions
6. Test color in various contexts (fill, stroke, text)

### 📋 Test Groups

#### Group 1: RGB Colors (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.2.1 | SetDrawColor(255, 0, 0) RGB | Red color |
| T3.2.2 | SetFillColor(0, 255, 0) RGB | Green color |
| T3.2.3 | SetTextColor(0, 0, 255) RGB | Blue color |
| T3.2.4 | RGB values validated | 0-255 range enforced |

#### Group 2: CMYK Colors (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.2.5 | SetDrawColorCMYK(0, 100, 100, 0) | CMYK red |
| T3.2.6 | SetFillColorCMYK(100, 0, 0, 0) | CMYK cyan |
| T3.2.7 | CMYK in PDF output | /DeviceCMYK used |
| T3.2.8 | CMYK values validated | 0-100 range |
| T3.2.9 | CMYK to RGB conversion | Fallback works |

#### Group 3: Grayscale (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.2.10 | SetDrawColor(128) single value | Gray color |
| T3.2.11 | Grayscale in PDF | /DeviceGray used |
| T3.2.12 | Grayscale 0-255 range | Range enforced |

#### Group 4: Alpha/Transparency (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.2.13 | SetAlpha(0.5) | 50% transparency |
| T3.2.14 | SetAlpha(1.0) | Fully opaque |
| T3.2.15 | SetAlpha(0.0) | Fully transparent |
| T3.2.16 | Alpha in PDF | /ExtGState created |
| T3.2.17 | Alpha for fill vs stroke | Separate alpha |

**Validation:**
- Soft mask (SMask) or transparency group created in PDF

#### Group 5: Color Contexts (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.2.18 | Color in Cell | Cell uses color |
| T3.2.19 | Color in Line | Line uses color |
| T3.2.20 | Color in Rect | Rect uses color |

#### Group 6: Edge Cases (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.2.21 | Invalid color values | Error raised |
| T3.2.22 | Color space mixing (RGB+CMYK) | Both work |

### ✅ Success Criteria

- [ ] All 22 tests pass
- [ ] CMYK support functional
- [ ] Alpha transparency works
- [ ] Color spaces correct in PDF
- [ ] Color validation works

---

## Task 3.3: Test Plan - Dynamic Header/Footer

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-3.3 |
| **Test Groups** | 6 |
| **Total Test Cases** | 20 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Test Header() customization
2. Test Footer() customization
3. Test header/footer with images
4. Test per-page header/footer variation
5. Test header/footer callbacks
6. Validate positioning

### 📋 Test Groups

#### Group 1: Basic Header/Footer (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.3.1 | Default Header() | Header drawn |
| T3.3.2 | Default Footer() | Footer drawn |
| T3.3.3 | Custom Header() procedure | Custom header used |
| T3.3.4 | Custom Footer() procedure | Custom footer used |

#### Group 2: Header/Footer Content (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.3.5 | Header with title | Title displayed |
| T3.3.6 | Footer with page number | Page number displayed |
| T3.3.7 | Header with logo image | Image in header |
| T3.3.8 | Footer with date | Date displayed |
| T3.3.9 | Header with line separator | Line drawn |

#### Group 3: Per-Page Variation (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.3.10 | Different header on first page | First page different |
| T3.3.11 | Different footer on odd/even | Alternating footers |
| T3.3.12 | Conditional header by page# | Conditional works |
| T3.3.13 | No header/footer on specific page | Suppressed |

#### Group 4: Header/Footer Positioning (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.3.14 | Header at top margin | Correct position |
| T3.3.15 | Footer at bottom margin | Correct position |
| T3.3.16 | Header/footer height | Doesn't overlap content |

#### Group 5: Callbacks (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.3.17 | SetHeaderProc with params | Params passed |
| T3.3.18 | SetFooterProc with params | Params passed |

#### Group 6: Edge Cases (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.3.19 | Very tall header | Content area reduced |
| T3.3.20 | Header/footer on rotated page | Positioned correctly |

### ✅ Success Criteria

- [ ] All 20 tests pass
- [ ] Custom headers/footers work
- [ ] Images in headers work
- [ ] Per-page variation works
- [ ] Positioning accurate

---

## Task 3.4: Test Plan - Per-Page Margins

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-3.4 |
| **Test Groups** | 5 |
| **Total Test Cases** | 16 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Validate SetMarginsForPage()
2. Test different margins per page
3. Validate margin inheritance
4. Test margin in different units
5. Validate auto page break with margins

### 📋 Test Groups

#### Group 1: SetMargins() Global (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.4.1 | SetMargins(10, 10, 10) | All pages use 10mm |
| T3.4.2 | SetLeftMargin(20) | Left margin 20mm |
| T3.4.3 | SetTopMargin(15) | Top margin 15mm |

#### Group 2: SetMarginsForPage() (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.4.4 | Set margins for page 1 | Page 1 has custom margins |
| T3.4.5 | Set margins for page 5 | Page 5 has custom margins |
| T3.4.6 | Other pages use default | Default margins |
| T3.4.7 | SetMarginsForPage before page exists | Error or deferred |
| T3.4.8 | Get margins for page | Returns correct values |

#### Group 3: Margin Inheritance (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.4.9 | New page inherits global | Inherits correctly |
| T3.4.10 | Override then revert | Revert to global |
| T3.4.11 | Margins stored per page | Each page independent |

#### Group 4: Units (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.4.12 | Margins in mm | Correct in mm |
| T3.4.13 | Margins in cm | Correct in cm |
| T3.4.14 | Margins in inches | Correct in inches |

#### Group 5: Auto Page Break (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T3.4.15 | Page break respects margins | Break at margin |
| T3.4.16 | Different bottom margin | Break adjusts |

### ✅ Success Criteria

- [ ] All 16 tests pass
- [ ] Per-page margins work
- [ ] Margin inheritance correct
- [ ] Auto page break respects margins
- [ ] All units supported

---

# PHASE 4: Advanced Features

---

## Task 4.1: Test Plan - Modern Structure

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.1 |
| **Test Groups** | 7 |
| **Total Test Cases** | 24 |
| **Coverage Target** | >80% |

### 🎯 Test Objectives

1. Validate use of Oracle 19c/23c types
2. Test BOOLEAN subtypes
3. Test RECORD types
4. Test TABLE types
5. Validate CONSTANT definitions
6. Test named notation in calls
7. Validate package organization

### 📋 Test Groups

#### Group 1: Type Definitions (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.1 | BOOLEAN subtypes defined | Subtypes exist |
| T4.1.2 | RECORD types for structured data | Records work |
| T4.1.3 | TABLE types for collections | Collections work |
| T4.1.4 | SUBTYPE for constraints | Constraints enforced |
| T4.1.5 | Type usage in signatures | Types in procedures |

#### Group 2: BOOLEAN Usage (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.6 | BOOLEAN parameters | TRUE/FALSE works |
| T4.1.7 | BOOLEAN return values | Returns BOOLEAN |
| T4.1.8 | NOT NULL BOOLEAN | Constraint works |
| T4.1.9 | DEFAULT TRUE/FALSE | Defaults work |

#### Group 3: RECORD Types (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.10 | recPage record | Fields accessible |
| T4.1.11 | recFont record | Fields accessible |
| T4.1.12 | Nested records | Nesting works |
| T4.1.13 | Record assignment | Assignment works |

#### Group 4: Collections (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.14 | Associative arrays | INDEX BY works |
| T4.1.15 | Nested tables | Nested tables work |
| T4.1.16 | VARRAYs | VARRAYs work |

#### Group 5: Constants (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.17 | CONSTANT declarations | Constants defined |
| T4.1.18 | Cannot modify constant | Error on assignment |
| T4.1.19 | Constants in expressions | Used correctly |

#### Group 6: Named Notation (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.20 | Call with named params | Works correctly |
| T4.1.21 | Mix positional and named | Works correctly |
| T4.1.22 | Named params out of order | Works correctly |

#### Group 7: Package Organization (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.1.23 | Public vs private separation | Separation clear |
| T4.1.24 | Package initialization | Init block works |

### ✅ Success Criteria

- [ ] All 24 tests pass
- [ ] Modern types used throughout
- [ ] Code more readable
- [ ] Type safety improved
- [ ] Package well-organized

---

## Task 4.2: Test Plan - JSON Configuration

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.2 |
| **Test Groups** | 6 |
| **Total Test Cases** | 20 |
| **Coverage Target** | >85% |

### 🎯 Test Objectives

1. Test InitFromJSON() function
2. Validate JSON schema
3. Test configuration sections
4. Test JSON validation
5. Test default values
6. Test JSON export

### 📋 Test Groups

#### Group 1: InitFromJSON() (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.2.1 | InitFromJSON with valid JSON | Initialized |
| T4.2.2 | InitFromJSON with invalid JSON | Error raised |
| T4.2.3 | InitFromJSON minimal config | Defaults used |
| T4.2.4 | InitFromJSON full config | All settings applied |
| T4.2.5 | InitFromJSON from CLOB | CLOB parsed |

#### Group 2: Configuration Sections (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.2.6 | JSON section "page" | Page settings applied |
| T4.2.7 | JSON section "margins" | Margins applied |
| T4.2.8 | JSON section "font" | Font settings applied |
| T4.2.9 | JSON section "metadata" | Metadata applied |
| T4.2.10 | JSON section "options" | Options applied |

**Example JSON:**
```json
{
  "page": {"orientation": "P", "format": "A4"},
  "margins": {"left": 10, "top": 10, "right": 10, "bottom": 10},
  "font": {"family": "Arial", "size": 12},
  "metadata": {"title": "My Doc", "author": "Maxwell"},
  "options": {"compress": true, "encoding": "UTF-8"}
}
```

#### Group 3: JSON Validation (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.2.11 | Invalid orientation in JSON | Error raised |
| T4.2.12 | Invalid margin value | Error raised |
| T4.2.13 | Unknown JSON key | Ignored or warning |
| T4.2.14 | JSON type mismatch | Error raised |

#### Group 4: Default Values (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.2.15 | Missing "orientation" | Default 'P' used |
| T4.2.16 | Missing "margins" | Default 10mm used |
| T4.2.17 | Partial JSON | Defaults for missing |

#### Group 5: JSON Export (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.2.18 | ExportConfigToJSON() | Valid JSON returned |
| T4.2.19 | Export then import | Config preserved |

#### Group 6: Edge Cases (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.2.20 | Very large JSON (1MB) | Parsed correctly |

### ✅ Success Criteria

- [ ] All 20 tests pass
- [ ] JSON initialization works
- [ ] Schema validation functional
- [ ] Defaults applied correctly
- [ ] Export/import symmetric

---

## Task 4.3: Test Plan - Native PNG/JPEG Parser

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.3 |
| **Test Groups** | 8 |
| **Total Test Cases** | 30 |
| **Coverage Target** | >90% |

### 🎯 Test Objectives

1. Test PNG parsing completeness
2. Test JPEG parsing completeness
3. Test GIF support (optional)
4. Validate chunk parsing (PNG)
5. Validate marker parsing (JPEG)
6. Test error handling
7. Test various image types
8. Performance comparison

### 📋 Test Groups

#### Group 1: PNG Basics (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.1 | Parse PNG signature | Signature valid |
| T4.3.2 | Parse IHDR chunk | Width/height extracted |
| T4.3.3 | Parse IDAT chunk | Image data extracted |
| T4.3.4 | Parse IEND chunk | End detected |
| T4.3.5 | CRC validation | CRC checked |

#### Group 2: PNG Advanced (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.6 | PNG with PLTE (palette) | Palette extracted |
| T4.3.7 | PNG with tRNS (transparency) | Transparency extracted |
| T4.3.8 | PNG interlaced (Adam7) | Interlace detected |
| T4.3.9 | PNG with gAMA (gamma) | Gamma extracted |
| T4.3.10 | PNG with tEXt (text) | Text chunks read |

#### Group 3: JPEG Basics (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.11 | Parse JPEG signature (FFD8) | Signature valid |
| T4.3.12 | Parse SOF marker | Width/height extracted |
| T4.3.13 | Parse SOS marker | Scan start detected |
| T4.3.14 | Parse EOI marker (FFD9) | End detected |
| T4.3.15 | Parse quantization tables | Tables extracted |

#### Group 4: JPEG Advanced (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.16 | JPEG progressive | Progressive detected |
| T4.3.17 | JPEG with EXIF | EXIF ignored/parsed |
| T4.3.18 | JPEG with JFIF | JFIF header parsed |
| T4.3.19 | JPEG CMYK color space | CMYK detected |

#### Group 5: Error Handling (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.20 | Corrupted PNG | Error raised |
| T4.3.21 | Corrupted JPEG | Error raised |
| T4.3.22 | Truncated image | Error raised |
| T4.3.23 | Invalid file format | Error raised |

#### Group 6: Various Image Types (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.24 | Grayscale PNG | Parsed correctly |
| T4.3.25 | RGB PNG | Parsed correctly |
| T4.3.26 | RGBA PNG | Alpha handled |
| T4.3.27 | Indexed PNG | Palette used |

#### Group 7: Image Sizes (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.28 | Small image (100x100) | Parsed |
| T4.3.29 | Large image (5000x5000) | Parsed |

#### Group 8: Performance (1 test)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.3.30 | Parse 100 images | <10 seconds |

### ✅ Success Criteria

- [ ] All 30 tests pass
- [ ] PNG parsing complete
- [ ] JPEG parsing complete
- [ ] All image types supported
- [ ] Performance acceptable

---

## Task 4.4: Test Plan - utPLSQL Unit Tests

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.4 |
| **Test Groups** | 6 |
| **Total Test Cases** | 20 (meta-tests) |
| **Coverage Target** | >80% code coverage |

### 🎯 Test Objectives

1. Validate utPLSQL framework installed
2. Test coverage measurement
3. Test all test suites execute
4. Validate test reporting
5. Test CI/CD integration
6. Performance of test suite

### 📋 Test Groups

#### Group 1: Framework Validation (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.4.1 | utPLSQL version >=3.0 | Version correct |
| T4.4.2 | ut.run() works | Tests execute |
| T4.4.3 | ut_runner package exists | Package found |

#### Group 2: Test Suites (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.4.4 | test_pl_fpdf_init suite | All tests pass |
| T4.4.5 | test_pl_fpdf_page suite | All tests pass |
| T4.4.6 | test_pl_fpdf_font suite | All tests pass |
| T4.4.7 | test_pl_fpdf_graphics suite | All tests pass |
| T4.4.8 | test_pl_fpdf_output suite | All tests pass |

#### Group 3: Coverage (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.4.9 | Overall coverage >80% | Coverage met |
| T4.4.10 | Init() coverage >90% | Coverage met |
| T4.4.11 | AddPage() coverage >90% | Coverage met |
| T4.4.12 | Coverage HTML report | Report generated |

#### Group 4: Reporting (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.4.13 | ut_documentation_reporter | Readable report |
| T4.4.14 | ut_coverage_html_reporter | HTML generated |
| T4.4.15 | ut_junit_reporter | JUnit XML generated |

#### Group 5: CI/CD (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.4.16 | Run tests via SQL*Plus | Exit code correct |
| T4.4.17 | Parse test results in CI | Parseable |
| T4.4.18 | Fail build on test failure | Build fails |

#### Group 6: Performance (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.4.19 | Full test suite runtime | <60 seconds |
| T4.4.20 | Individual test suite | <10 seconds each |

### ✅ Success Criteria

- [ ] All 20 meta-tests pass
- [ ] >80% code coverage achieved
- [ ] All test suites pass
- [ ] CI/CD integration works
- [ ] Test suite performant

---

## Task 4.5: Test Plan - Documentation

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.5 |
| **Test Groups** | 5 |
| **Total Test Cases** | 18 |
| **Coverage Target** | 100% API documented |

### 🎯 Test Objectives

1. Validate all procedures documented
2. Test DBMS_METADATA integration
3. Validate examples executable
4. Test documentation generation
5. Validate English standardization

### 📋 Test Groups

#### Group 1: Inline Documentation (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.5.1 | All public procedures have comments | 100% documented |
| T4.5.2 | Comments in English | English only |
| T4.5.3 | Parameters documented | All params described |
| T4.5.4 | Return values documented | Returns described |
| T4.5.5 | Examples in comments | Examples present |

#### Group 2: DBMS_METADATA (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.5.6 | DBMS_METADATA.GET_DDL | DDL retrieved |
| T4.5.7 | DBMS_METADATA includes comments | Comments in DDL |
| T4.5.8 | Metadata complete | All info present |

#### Group 3: README and Guides (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.5.9 | README.md exists | File exists |
| T4.5.10 | README has installation guide | Guide present |
| T4.5.11 | README has usage examples | Examples present |
| T4.5.12 | API_REFERENCE.md exists | File exists |

#### Group 4: Examples (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.5.13 | Example 1: Hello World | Executes successfully |
| T4.5.14 | Example 2: Multi-page doc | Executes successfully |
| T4.5.15 | Example 3: Images | Executes successfully |
| T4.5.16 | Example 4: Advanced graphics | Executes successfully |

#### Group 5: Documentation Generation (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.5.17 | Generate HTML docs | HTML created |
| T4.5.18 | Generate PDF docs | PDF created |

### ✅ Success Criteria

- [ ] All 18 tests pass
- [ ] 100% API documented
- [ ] All examples work
- [ ] README complete
- [ ] English standardization done

---

## Task 4.6: Test Plan - Performance Tuning

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.6 |
| **Test Groups** | 8 |
| **Total Test Cases** | 26 |
| **Coverage Target** | Performance targets met |

### 🎯 Test Objectives

1. Benchmark critical operations
2. Test CLOB performance
3. Test large document performance
4. Validate memory usage
5. Test parallel operations
6. Identify bottlenecks
7. Test optimization impact
8. Validate Oracle 23c features

### 📋 Test Groups

#### Group 1: Baseline Benchmarks (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.1 | Init() benchmark | <10ms |
| T4.6.2 | AddPage() benchmark | <5ms per page |
| T4.6.3 | Cell() benchmark | <1ms per cell |
| T4.6.4 | Output() benchmark 100 pages | <500ms |

#### Group 2: CLOB Performance (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.5 | DBMS_LOB.WRITEAPPEND 10k times | <100ms |
| T4.6.6 | CLOB vs VARCHAR2 array | CLOB ≥ array |
| T4.6.7 | CLOB read performance | <50ms for 1MB |
| T4.6.8 | CLOB memory usage | <50MB for 1000 pages |

#### Group 3: Large Documents (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.9 | 1000 pages generation time | <30 seconds |
| T4.6.10 | 5000 pages generation time | <2 minutes |
| T4.6.11 | 10000 pages generation time | <5 minutes |
| T4.6.12 | Memory for 10k pages | <500MB |

#### Group 4: Operation Benchmarks (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.13 | 10k Cell() calls | <10 seconds |
| T4.6.14 | 1k Image() calls | <20 seconds |
| T4.6.15 | 1k AddPage() calls | <5 seconds |
| T4.6.16 | 100 Output() calls | <50 seconds |

#### Group 5: Bottleneck Identification (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.17 | DBMS_PROFILER run | Profile data collected |
| T4.6.18 | Identify top 10 slow procedures | List generated |
| T4.6.19 | SQL trace analysis | Trace analyzed |

#### Group 6: Optimization Validation (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.20 | Before vs after optimization | >20% improvement |
| T4.6.21 | Bulk collect usage | Used where applicable |
| T4.6.22 | NOCOPY parameters | Used for large params |

#### Group 7: Oracle 23c Features (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.23 | SQL macro usage | Macros work |
| T4.6.24 | IF EXISTS usage | Syntax works |

#### Group 8: Parallel Operations (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.6.25 | Multiple sessions generating PDFs | No contention |
| T4.6.26 | Parallel DML (if applicable) | Works correctly |

### ✅ Success Criteria

- [ ] All 26 tests pass
- [ ] Performance targets met
- [ ] No regression vs baseline
- [ ] Bottlenecks identified
- [ ] Optimizations effective

---

## Task 4.7: Test Plan - Oracle 19c/26c Compatibility

### 📌 Test Information

| Field | Value |
|-------|-------|
| **Task ID** | TASK-4.7 |
| **Test Groups** | 6 |
| **Total Test Cases** | 22 |
| **Coverage Target** | 100% compatibility |

### 🎯 Test Objectives

1. Test on Oracle 19c
2. Test on Oracle 21c
3. Test on Oracle 23c
4. Test on Oracle 26c (if available)
5. Validate feature detection
6. Test version-specific features
7. Validate graceful degradation

### 📋 Test Groups

#### Group 1: Oracle 19c Compatibility (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.7.1 | Compile on 19c | Success |
| T4.7.2 | All tests pass on 19c | 100% pass |
| T4.7.3 | 19c features used | CLOB, BOOLEAN, etc. work |
| T4.7.4 | No 21c+ features used | Code compatible |
| T4.7.5 | Performance on 19c | Acceptable |

#### Group 2: Oracle 21c Compatibility (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.7.6 | Compile on 21c | Success |
| T4.7.7 | All tests pass on 21c | 100% pass |
| T4.7.8 | 21c enhancements work | JSON, etc. |

#### Group 3: Oracle 23c Compatibility (5 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.7.9 | Compile on 23c | Success |
| T4.7.10 | All tests pass on 23c | 100% pass |
| T4.7.11 | SQL macros work (23c) | Macros functional |
| T4.7.12 | IF EXISTS syntax (23c) | Syntax works |
| T4.7.13 | Enhanced JSON (23c) | JSON enhancements work |

#### Group 4: Oracle 26c Future (2 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.7.14 | Compile on 26c (if available) | Success |
| T4.7.15 | Tests pass on 26c | 100% pass |

#### Group 5: Feature Detection (4 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.7.16 | Detect Oracle version | Version detected |
| T4.7.17 | Conditional compilation | Works correctly |
| T4.7.18 | Feature flags set | Flags correct per version |
| T4.7.19 | Graceful degradation | Falls back gracefully |

**Example:**
```sql
$IF DBMS_DB_VERSION.VERSION >= 23 $THEN
  -- Use Oracle 23c features
$ELSE
  -- Use fallback
$END
```

#### Group 6: Cross-Version Tests (3 tests)

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| T4.7.20 | Same PDF on 19c vs 23c | Output identical |
| T4.7.21 | Upgrade 19c→23c | No issues |
| T4.7.22 | Backward compatibility | 23c PDF opens in 19c |

### ✅ Success Criteria

- [ ] All 22 tests pass
- [ ] Works on 19c, 21c, 23c
- [ ] Feature detection works
- [ ] Graceful degradation
- [ ] No breaking changes

---

## 📊 Test Execution Summary

### Total Test Coverage

| Phase | Tasks | Test Cases | Estimated Runtime |
|-------|-------|-----------|-------------------|
| **Phase 1** | 6 | 184 | ~30 seconds |
| **Phase 2** | 8 | 166 | ~25 seconds |
| **Phase 3** | 4 | 86 | ~15 seconds |
| **Phase 4** | 7 | 160 | ~20 seconds |
| **TOTAL** | **25** | **596** | **~90 seconds** |

### Coverage Targets by Phase

| Phase | Target Coverage | Priority |
|-------|-----------------|----------|
| Phase 1 | >90% | P0 (Critical) |
| Phase 2 | >85% | P1 (Important) |
| Phase 3 | >85% | P1 (Important) |
| Phase 4 | >80% | P2-P3 (Nice to have) |

---

## 🔄 Test Execution Workflow

### For Each Task:

1. **Pre-Implementation:**
   - Read test plan for task
   - Understand test scenarios
   - Plan implementation to pass tests

2. **During Implementation:**
   - Write code
   - Run quick validation tests
   - Fix issues immediately

3. **Post-Implementation:**
   - Create test package (test_pl_fpdf_taskX.pks/pkb)
   - Implement all test cases
   - Run full test suite
   - Verify 100% pass rate
   - Measure code coverage
   - Document test results

4. **CI/CD Integration:**
   - Add tests to automated pipeline
   - Run on commit
   - Block merge if tests fail

---

## ✅ Final Checklist

### Per Task:
- [ ] Test plan reviewed
- [ ] Test package created
- [ ] All test cases implemented
- [ ] All tests pass (100%)
- [ ] Coverage target met
- [ ] Performance benchmarks met
- [ ] Tests documented
- [ ] Tests in CI/CD

### Overall:
- [ ] All 25 tasks have test plans
- [ ] All 596+ tests defined
- [ ] Test infrastructure ready
- [ ] CI/CD pipeline configured
- [ ] Test documentation complete

---

## 📞 Support and Contact

**Test Plan Author:** Maxwell da Silva Oliveira
**Email:** maxwbh@gmail.com
**LinkedIn:** [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)
**Company:** M&S do Brasil LTDA

**Repository:** https://github.com/maxwbh/pl_fpdf
**Branch:** `claude/modernize-pdf-oracle-dVui6`

---

**Document Version:** 1.0
**Last Updated:** 2025-12-15
**Status:** ✅ Ready for Implementation
**Total Pages:** 100+
**Total Test Cases:** 596+
