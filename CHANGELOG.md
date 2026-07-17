# Changelog

All notable changes to PL_FPDF will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - Planned 📋

### 🎯 Advanced Page Operations

**Status:** Planned - Q2 2026

### Planned Features

- `InsertPagesFrom()` - Insert pages from another PDF at specific position
- `PrependPages()` / `AppendPages()` - Insert pages at beginning/end
- `ReorderPages()` - Reorder pages by new sequence
- `ReplacePage()` - Replace page content from another PDF
- `DuplicatePage()` - Copy page within or across documents
- `BatchProcess()` - Apply same operations to multiple PDFs

---

## [3.2.0] - 2026-07-17 ✅

### 🔐 Security & Tooling

**Status:** Released
**Author:** @maxwbh

### Security (RC4 Encryption)
- `EncryptPDF()` - Encrypt PDF with owner/user passwords and permissions
- `DecryptPDF()` - Decrypt protected PDF
- `IsEncrypted()` - Check if PDF is encrypted
- `GetSecurityInfo()` - Security metadata as JSON
- `SetEncryption()` / `SetPermissions()` - Configure protection for generated PDFs
- `SetPDFVersion()` / `GetPDFVersion()` - Control output PDF version

### Tooling
- `scripts/docx_to_plfpdf/` - Python generator that converts `.docx` files
  into PL/SQL blocks using PL_FPDF (headings, styled runs, lists, tables,
  inline images, page breaks)
- Real-world examples in `scripts/docx_to_plfpdf/examples/`

### Fixed
- `co_version` and package headers aligned with released version (3.2.0)

---

## [3.0.0] - 2026-02-25 ✅

### 🎉 Phase 4 Complete: PDF Manipulation

**Status:** Released
**Author:** @maxwbh

Major release with full PDF reading and manipulation capabilities.

### Phase 4.1 - PDF Parser
- `LoadPDF()` - Load existing PDF into memory
- `GetPageCount()` - Get number of pages
- `GetPDFInfo()` - Get PDF metadata as JSON
- `GetPageInfo()` - Get page information (MediaBox, rotation)
- `ClearPDFCache()` - Clear loaded PDF from memory

### Phase 4.2 - Page Management
- `RotatePage()` - Rotate page (0, 90, 180, 270 degrees)
- `RemovePage()` - Mark page for removal
- `GetActivePageCount()` - Count non-removed pages
- `IsPageRemoved()` - Check if page is marked for removal
- `IsPDFModified()` - Check if PDF has pending changes

### Phase 4.3 - Watermarks
- `AddWatermark()` - Add text watermark with opacity, rotation, position
- `GetWatermarks()` - List all watermarks as JSON

### Phase 4.4 - Output Modified PDF
- `OutputModifiedPDF()` - Generate modified PDF with all changes applied

### Phase 4.5 - Text & Image Overlay
- `OverlayText()` - Add text at specific coordinates with formatting
- `OverlayImage()` - Add image at specific position with sizing
- `RemoveOverlay()` - Remove specific overlay by ID
- `ClearOverlays()` - Remove all overlays from page

### Phase 4.6 - Merge & Split
- `LoadPDFWithID()` - Load PDF with unique identifier
- `GetLoadedPDFs()` - List all loaded PDFs as JSON
- `UnloadPDF()` - Remove PDF from memory
- `MergePDFs()` - Merge multiple PDFs into single document
- `SplitPDF()` - Split PDF by page ranges
- `ExtractPages()` - Extract specific pages to new PDF

### Technical Improvements
- Removed APEX dependencies (pure PL/SQL)
- Replaced REGEXP_SUBSTR with INSTR/SUBSTR for Oracle compatibility
- PDF version updated to 1.4 default
- Robust xref parser with fallback for incorrect offsets
- MediaBox inheritance from parent Pages object
- 100% test coverage (all phases passing)

### Error Codes
- -20800 to -20839: Phase 4 specific error codes
- Consistent error handling across all operations

---

## [2.0.0] - 2025-12 ✅

### 🎉 Phases 1-3: PDF Generation

**Status:** Released

Complete PDF generation from scratch in pure PL/SQL.

### Phase 1 - Core Generation
- `fpdf()` - Initialize PDF document
- `AddPage()` - Add new page with orientation/format
- `SetFont()` - Set font family, style, size
- `Cell()` / `MultiCell()` - Add text cells
- `Text()` - Add text at position
- `Output()` - Generate PDF as BLOB
- `SetMargins()` - Set page margins

### Phase 2 - Graphics & Images
- `Line()` / `Rect()` / `Circle()` - Draw shapes
- `SetDrawColor()` / `SetFillColor()` - Set colors
- `Image()` / `ImageBlob()` - Add PNG/JPEG images
- Native BLOB image support (no ORDSYS.ORDIMAGE)
- `SetLineWidth()` - Set line thickness

### Phase 3 - Advanced Features
- TrueType font support with subsetting
- UTF-8 encoding
- Text rotation
- QR Code generation
- Barcode generation (Code39, EAN-13)
- PIX QR Code (Brazilian payments)
- Boleto barcode (Brazilian payments)
- JSON configuration support
- Native compilation for performance

### Infrastructure
- CLOB-based document buffer (unlimited size)
- Custom exception handling
- Logging system with debug levels

---

## [0.9.4] - 2017-12

### Original Release

**Author:** Pierre-Gilles Levallois

Original PL/SQL port of PHP FPDF library.

- Basic PDF generation
- Core fonts support
- Simple text and graphics
- Page management

---

## Links

- [Roadmap](docs/ROADMAP.md)
- [API Reference](docs/api/API_REFERENCE.md)
- [Contributing](CONTRIBUTING.md)
