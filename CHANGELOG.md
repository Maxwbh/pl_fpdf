# Changelog

All notable changes to PL_FPDF will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.1.0] - TBD (In Planning 🚧)

### 🎯 Phase 5: Advanced Page Operations & Automation

**Status:** Planning stage - Depends on Phase 4.6 completion
**Planning Document:** [PHASE_5_IMPLEMENTATION_PLAN.md](PHASE_5_IMPLEMENTATION_PLAN.md)

Phase 5 focuses on advanced page manipulation and automation workflows.

### Planned Features

#### Phase 5.1: Page Insertion (v3.1.0-a.1)
- `InsertPagesFrom()` - Insert pages from another PDF at specific position
- `PrependPages()` - Insert pages at beginning
- `AppendPages()` - Insert pages at end

#### Phase 5.2: Page Reordering (v3.1.0-a.2)
- `ReorderPages()` - Reorder pages by new sequence
- `MovePage()` - Move single page to new position
- `SwapPages()` - Swap two pages
- `ReversePages()` - Reverse page order

#### Phase 5.3: Page Replacement (v3.1.0-a.3)
- `ReplacePage()` - Replace page content from another PDF
- `ReplacePageRange()` - Replace multiple pages

#### Phase 5.4: Page Duplication (v3.1.0-a.4)
- `DuplicatePage()` - Copy page within or across documents
- `DuplicatePageRange()` - Copy multiple pages

#### Phase 5.5: Batch Processing (v3.1.0-a.5)
- `BatchProcess()` - Apply same operations to multiple PDFs
- Template-based processing workflows

#### Phase 5.6: Smart Bookmarks (v3.1.0-a.6)
- Automatic bookmark management across operations
- Bookmark synchronization after page changes

### Use Cases

- **Print Preparation** - Reorder pages for booklet printing
- **Template Processing** - Apply same modifications to multiple documents
- **Page Replacement** - Update specific pages across document versions
- **Document Assembly** - Build documents from page templates

---

## [3.0.0-a.7] - TBD (In Planning 🚧)

### 🎯 Phase 4.6: PDF Merge & Split

**Status:** Planning stage
**Planning Document:** [PHASE_4_6_MERGE_SPLIT_PLAN.md](PHASE_4_6_MERGE_SPLIT_PLAN.md)

Essential multi-document PDF operations.

### Planned Features

- `LoadPDFWithID()` - Load multiple PDFs with identifiers
- `GetLoadedPDFs()` - List all loaded PDF IDs
- `UnloadPDF()` - Unload specific PDF from memory
- `MergePDFs()` - Combine multiple PDFs into single document
- `SplitPDF()` - Split PDF into multiple files by page ranges
- `ExtractPages()` - Create new PDF from specific page range

### Technical Improvements

- Multi-document memory management (up to 10 PDFs)
- Object renumbering and conflict resolution
- Cross-reference table merging
- Resource consolidation (fonts, images)
- 12 new error codes (-20828 to -20839)

### Use Cases

- **Document Consolidation** - Merge monthly reports into annual report
- **Document Distribution** - Split contracts into sections for parties
- **Selective Extraction** - Extract executive summary from full report

---

## [3.0.0-a.6] - 2026-01-25 ✅

### 🎉 Phase 4.5: Text & Image Overlay - Complete

**Status:** Implemented
**Planning Document:** [PHASE_4_5_OVERLAY_PLAN.md](PHASE_4_5_OVERLAY_PLAN.md)
**Author:** @maxwbh

Phase 4.5 adds precise text and image overlay capabilities to PDFs.

### Added Features

#### Overlay APIs (5 new procedures/functions)

- `OverlayText()` - Add formatted text overlays at specific x,y coordinates
  - Font control (name, size, bold)
  - Color support (RGB hex format)
  - Opacity control (0.0-1.0)
  - Rotation support (0-360 degrees)
  - Text alignment (left, center, right)
  - Z-order layering
  - Optional max width for text wrapping

- `OverlayImage()` - Add image overlays at specific positions
  - Support for JPEG and PNG formats
  - Width and height control (or NULL for original size)
  - Opacity control (0.0-1.0)
  - Rotation support (0-360 degrees)
  - Maintain aspect ratio option
  - Scale to fit option
  - Z-order layering

- `GetOverlays()` - List all applied overlays as JSON array
  - Filter by page number (or NULL for all pages)
  - Returns complete overlay metadata (type, position, properties)
  - JSON format for easy processing

- `RemoveOverlay()` - Remove specific overlay by ID
  - Overlay IDs returned by GetOverlays()
  - Clean removal from overlay cache

- `ClearOverlays()` - Clear all overlays
  - Clear all overlays (no parameter)
  - Or clear overlays from specific page

### Technical Improvements

- **Overlay Data Structure** - New overlay_rec type with comprehensive properties
- **Global Overlay Cache** - g_overlays collection for efficient overlay management
- **Overlay Counter** - g_overlay_count for unique ID generation
- **Helper Functions** - generate_text_overlay_stream(), generate_image_overlay_stream()
- **Image Validation** - PNG and JPEG format detection
- **Coordinate Validation** - Ensure valid x,y positions
- **Opacity Validation** - Range checking (0.0-1.0)
- **Z-Order Support** - Layer management for multiple overlays
- **Integration** - Updated ClearPDFCache() to clear overlays
- **7 New Error Codes** (-20821 to -20827):
  - -20821: INVALID_COORDINATES
  - -20822: INVALID_FONT
  - -20823: INVALID_IMAGE_FORMAT
  - -20824: INVALID_DIMENSIONS
  - -20825: OVERLAY_NOT_FOUND
  - -20826: OVERLAY_POSITION_OUT_OF_BOUNDS
  - -20827: CONTENT_STREAM_ERROR

### Testing

- **New Test Suite** - tests/test_phase_4_5_overlay.sql
- **20 Comprehensive Tests**:
  - Text overlay tests (6 tests)
  - Image overlay tests (5 tests)
  - Overlay management tests (6 tests)
  - Integration tests (3 tests)
- **Error Handling** - Tests for all error conditions
- **Edge Cases** - Invalid inputs, NULL handling, boundary conditions

### Use Cases

- **Document Stamping** - Add "APPROVED", "CONFIDENTIAL" stamps at precise positions
- **Logo Addition** - Add company logo to all pages at specific coordinates
- **Form Filling** - Dynamically fill form fields with data at exact positions
- **Signatures** - Add signature images at signature line positions
- **Custom Annotations** - Add custom text and image annotations anywhere on pages

### Version Information

- Package Version: 3.0.0-a.6 (Phase 4.5)
- Test Coverage: 20 tests implemented
- Status: Fully implemented and tested

---

## [3.0.0] - 2026-01-25

### 🎉 Phase 4 Complete: PDF Reading and Manipulation

Phase 4 adds comprehensive PDF manipulation capabilities to PL_FPDF.

### Added

#### Phase 4.1A: PDF Parser - Basic Reading (v3.0.0-alpha)
- `LoadPDF()` - Load and parse existing PDF documents (PDF 1.4+)
- `GetPageCount()` - Get total number of pages
- `GetPDFInfo()` - Extract PDF metadata and document information
- `ClearPDFCache()` - Clear loaded PDF and free memory
- 100% PL/SQL PDF parser (no Java dependencies)
- Support for cross-reference tables and trailer parsing

#### Phase 4.1B: Page Information and Manipulation (v3.0.0-a.2)
- `GetPageInfo()` - Extract detailed page information (dimensions, rotation, resources)
- `RotatePage()` - Rotate individual pages (0°, 90°, 180°, 270°)
- Page dimension extraction (MediaBox, CropBox)
- Resource identification (fonts, images, XObjects)

#### Phase 4.2: Page Management & Modification Tracking (v3.0.0-a.3)
- `RemovePage()` - Mark pages for removal
- `GetActivePageCount()` - Get count of non-removed pages
- `IsPageRemoved()` - Check if specific page is removed
- `IsPDFModified()` - Check if PDF has modifications
- Modification tracking system

#### Phase 4.3: Watermark Management (v3.0.0-a.4)
- `AddWatermark()` - Add customizable text watermarks
  - Opacity control (0.0-1.0)
  - Rotation angles (0, 45, 90, 135, 180, 225, 270, 315)
  - Page range support ('ALL', '1-5', '1,3,5')
  - Font and size customization
  - Color options (gray, red, blue, green)
- `GetWatermarks()` - Get list of applied watermarks as JSON

#### Phase 4.4: Output Modified PDF (v3.0.0-a.5)
- `OutputModifiedPDF()` - Generate modified PDF with all changes
- Applies page rotations, removals, and watermarks
- Rebuilds PDF structure (xref table, trailer)
- Complete PDF generation from modified content

### Documentation

- **Bilingual Documentation** - All Phase 4 APIs documented in English and Portuguese (PT-BR)
- **Modern Package Specification** - Complete package header modernization with MIT license
- **Phase 4 Guide** - Comprehensive 922-line bilingual guide ([docs/guides/PHASE_4_GUIDE.md](docs/guides/PHASE_4_GUIDE.md))
- **Consolidated Documentation** - Removed 85KB of obsolete documentation, organized into `docs/` structure

### Technical Details

- 13 new Phase 4 APIs
- 21 error codes for Phase 4 operations (-20800 to -20820)
- JSON-based metadata structures using JSON_OBJECT_T and JSON_ARRAY_T
- BLOB-based PDF manipulation
- Memory-efficient page caching system
- Version consolidated to single source: `co_version := '3.0.0'`

### Changed

- Package specification modernized with bilingual structure
- Version management simplified (consolidated from 3 variables to 1)
- Documentation reorganized into hierarchical `docs/` structure
- README updated with Phase 4 features and bilingual support

### Removed

- Obsolete documentation files (85KB):
  - MODERNIZATION_TODO.md
  - PHASE_4_IMPLEMENTATION_PLAN.md
  - PHASE_4_QUICKSTART.md
  - TASK_4_1_PDF_PARSER.md
  - README_PT_BR.md (merged into main README.md)

---

## [2.0.0] - 2025-12-19

### 🎉 Major Release - Complete Modernization for Oracle 19c/23c

This is a major modernization release with significant improvements in performance, security, and functionality while maintaining backward compatibility for most common use cases.

### Added

#### Phase 1: Critical Refactoring

- **Modern Initialization** (`Init()` procedure)
  - UTF-8 encoding support by default
  - CLOB buffer initialization for unlimited document size
  - Better error handling with specific exception codes
  - Replaces legacy `fpdf()` constructor (still supported)

- **Enhanced Page Management**
  - `AddPage()` with rotation support (0°, 90°, 180°, 270°)
  - Custom page formats via `width,height` syntax
  - `SetPage()` for navigating between pages
  - `GetCurrentPage()` for current page number
  - CLOB-based page content (no VARCHAR2 limits)

- **TrueType/OpenType Font Support**
  - `AddTTFFont()` - Load fonts from BLOB
  - `LoadTTFFromFile()` - Load fonts from filesystem
  - `IsTTFFontLoaded()` - Check if font is loaded
  - `GetTTFFontInfo()` - Get font metadata
  - `ClearTTFFontCache()` - Clear font cache
  - Full UTF-8 character support
  - Font embedding in PDF

- **Text Rotation Features**
  - `CellRotated()` - Cell with rotation (0°, 90°, 180°, 270°)
  - `WriteRotated()` - Write with rotation
  - Rotation support for all text operations

- **Modern Output Methods**
  - `OutputBlob()` - Generate PDF as BLOB (no OWA dependencies)
  - `OutputFile()` - Save directly to Oracle directory
  - No dependencies on OWA_UTIL or HTP packages
  - Works in all contexts (web, batch, APEX, etc.)

- **Native BLOB Image Handling**
  - `recImageBlob` type - Native BLOB-based image container
  - PNG and JPEG native parsing (no OrdImage dependency)
  - Automatic dimension extraction from image headers
  - `getImageFromUrl()` - Fetch images from URLs as BLOB
  - Transparency and color depth detection

#### Phase 2: Security & Robustness

- **Custom Exception System**
  - Initialization errors: `-20001` to `-20010`
  - Page errors: `-20101` to `-20110`
  - Font errors: `-20201` to `-20215`
  - Image errors: `-20301` to `-20310`
  - File I/O errors: `-20401` to `-20410`
  - Color/Drawing errors: `-20501` to `-20510`
  - 17 specific exception types with clear error messages

- **Input Validation**
  - Parameter validation for all public procedures
  - Range checking for numeric inputs
  - Format validation for strings
  - Null handling improvements

- **UTF-8/Unicode Support**
  - `UTF8ToPDFString()` - Convert UTF-8 to PDF format
  - `IsUTF8Enabled()` - Check UTF-8 status
  - `SetUTF8Enabled()` - Enable/disable UTF-8
  - Automatic character encoding
  - International character support

- **File I/O Security**
  - Directory validation
  - File access checks
  - Error handling for file operations
  - Safe file writing with rollback

- **Enhanced Logging**
  - `SetLogLevel()` - Configure logging (0=OFF to 4=DEBUG)
  - `GetLogLevel()` - Get current log level
  - Integration with DBMS_APPLICATION_INFO
  - Performance tracking
  - Error diagnostics

#### Phase 3: Advanced Modernization

- **JSON Configuration APIs**
  - `SetDocumentConfig()` - Configure via JSON_OBJECT_T
  - `GetDocumentMetadata()` - Retrieve metadata as JSON
  - `GetPageInfo()` - Get page information as JSON
  - Modern integration with REST APIs
  - Centralized configuration management

- **Performance Optimization**
  - Native compilation support (2-3x faster)
  - `optimize_native_compile.sql` - Automated optimization script
  - CLOB buffer optimization with DBMS_LOB.WRITEAPPEND
  - Result cache for font metrics
  - Init/Reset cycle optimization
  - Reduced memory footprint

- **Unit Testing Framework**
  - 87 automated tests using utPLSQL
  - >82% code coverage
  - Test suites for:
    - Initialization (43 tests, >90% coverage)
    - Fonts (18 tests, >85% coverage)
    - Images (14 tests, >80% coverage)
    - Output (7 tests, >90% coverage)
    - Performance (5 tests, 100% coverage)
  - `run_all_tests.sql` - Master test runner

- **Comprehensive Documentation**
  - README.md - English documentation
  - README_PT_BR.md - Brazilian Portuguese documentation
  - API_REFERENCE.md - Complete API reference
  - MIGRATION_GUIDE.md - Migration guide from v0.9.4
  - PERFORMANCE_TUNING.md - Performance optimization guide
  - VALIDATION_GUIDE.md - Testing and validation guide
  - tests/README_TESTS.md - Unit testing documentation

### Changed

- **Performance Improvements**
  - Init() 50-70% faster than legacy fpdf()
  - 100-page document generation 2-3x faster
  - Overall performance improvement of 77% with native compilation
  - CLOB buffers eliminate VARCHAR2 size limits

- **Code Quality**
  - Removed all OWA/HTP dependencies
  - Removed deprecated ORDSYS.ORDIMAGE dependencies
  - Modernized PL/SQL patterns
  - Improved error messages
  - Better code organization

- **Architecture**
  - CLOB-based internal buffers
  - JSON-based configuration
  - Modular exception handling
  - Extensible font system

### Deprecated

- `fpdf()` - Use `Init()` instead (still works for backward compatibility)
- `Output()` - Use `OutputBlob()` or `OutputFile()` instead
- `ReturnBlob()` - Use `OutputBlob()` instead

### Removed

- OWA_UTIL dependencies
- HTP dependencies
- ORDSYS.ORDIMAGE dependencies
- VARCHAR2-based page content arrays

### Fixed

- UTF-8 character encoding issues
- Large document size limitations (VARCHAR2 limits)
- Memory leaks in font caching
- Image parsing edge cases
- Error handling inconsistencies

### Security

- Input validation for all parameters
- Directory access validation
- File path sanitization
- SQL injection prevention in dynamic SQL
- Buffer overflow protection

---

## [0.9.4] - 2017-12-27

### Initial Release (by Pierre-Gilles Levallois et al)

- Port of FPDF PHP library v1.53 to Oracle PL/SQL
- Basic PDF generation functionality
- Core fonts support (Arial, Courier, Times, Helvetica)
- PNG and JPEG image embedding via OrdImage
- Multi-page documents
- Text rendering (Cell, MultiCell, Write)
- Graphics primitives (Line, Rect)
- Page headers and footers
- Hyperlinks and internal links
- Compression support

---

## Extension: Brazilian Payments [1.0.0] - 2025-12-19

**Note**: PIX and Boleto are separate optional extensions, not part of core PL_FPDF.

### Added

- **PL_FPDF_PIX Package**
  - PIX QR Code generation (EMV standard)
  - All key types: CPF, CNPJ, Email, Phone, Random (EVP)
  - Static and dynamic PIX
  - CRC16-CCITT validation
  - `GetPixPayload()` - Generate EMV payload
  - `AddQRCodePIX()` - Add QR code to PDF
  - `ValidatePixKey()` - Validate PIX key format

- **PL_FPDF_BOLETO Package**
  - Boleto Bancário generation (FEBRABAN standard)
  - Interbank 2 of 5 (ITF-14) barcode
  - Linha digitável (47-digit formatted line)
  - Módulo 11 check digit calculation
  - Fator de vencimento calculation
  - `GetCodigoBarras()` - Generate barcode
  - `GetLinhaDigitavel()` - Generate linha digitável
  - `AddBarcodeBoleto()` - Add barcode to PDF
  - `CalcularFatorVencimento()` - Calculate due date factor

- **Extension Documentation**
  - extensions/brazilian-payments/README.md (English)
  - extensions/brazilian-payments/README_PT_BR.md (Portuguese)
  - Separate deployment script
  - 58 validation tests (>83% coverage)

---

## Version History

| Version | Date | Oracle | Status | Notes |
|---------|------|--------|--------|-------|
| 2.0.0 | 2025-12-19 | 19c/23c | ✅ Production | Complete modernization |
| 0.9.4 | 2017-12-27 | 11g+ | 🔒 Legacy | Original port |

---

## Upgrade Path

| From | To | Compatibility | Recommended Action |
|------|----|--------------|--------------------|
| 0.9.4 | 2.0.0 | High (90%+) | See MIGRATION_GUIDE.md |

---

## Performance Benchmarks

### v2.0.0 (Oracle 19c, Native Compilation)

| Operation | v0.9.4 | v2.0.0 | Improvement |
|-----------|--------|--------|-------------|
| Init() | 50-100ms | 15-30ms | 70% faster |
| 100-page doc | 5-7s | 1.2-1.8s | 77% faster |
| 1000-page doc | 45-60s | 8-12s | 80% faster |
| OutputBlob (50 pages) | 400-600ms | 150-250ms | 62% faster |

### Test Environment
- Oracle Database 19c Enterprise Edition
- 4 CPU cores, 16GB RAM
- Native compilation enabled
- PLSQL_OPTIMIZE_LEVEL = 3

---

## Breaking Changes by Version

### 2.0.0

#### Must Change
- Oracle version requirement: 11g+ → 19c+
- OrdImage removed (automatic migration to BLOB)

#### Should Change (Deprecated but still works)
- `fpdf()` → `Init()`
- `Output()` → `OutputBlob()` or `OutputFile()`
- `ReturnBlob()` → `OutputBlob()`

#### Recommended Changes
- Update exception handling to use specific exceptions
- Enable native compilation for performance
- Add UTF-8 encoding parameter

---

## Contributors

### v2.0.0 Modernization
- **Maxwell da Silva Oliveira** (@maxwbh) - Lead Developer
- **M&S do Brasil LTDA** - Sponsor

### v0.9.4 Original Port
- **Pierre-Gilles Levallois** et al - Original PL/SQL port

### FPDF Original
- **Olivier PLATHEY** - Original FPDF PHP library

---

## Links

- **Repository**: https://github.com/maxwbh/pl_fpdf
- **Issues**: https://github.com/maxwbh/pl_fpdf/issues
- **Original FPDF**: http://www.fpdf.org/

---

**Last Updated**: December 19, 2025
