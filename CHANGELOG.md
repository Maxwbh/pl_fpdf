# Changelog

All notable changes to PL_FPDF will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
