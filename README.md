# PL_FPDF v2.0

**Oracle PL/SQL PDF Generation Package - Modernized Edition**

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/Maxwbh/pl_fpdf)
[![Oracle](https://img.shields.io/badge/oracle-11g%2B-red.svg)](https://www.oracle.com/database/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

PL_FPDF is a powerful PL/SQL package that enables PDF generation directly from Oracle Database. Version 2.0 represents a complete modernization of the original package with enhanced security, performance, and maintainability.

---

## 🚀 What's New in v2.0

### Phase 1: Core Modernization ✅ COMPLETE
- ✅ **Task 1.1:** Clean code structure with comprehensive documentation
- ✅ **Task 1.2:** Named page format system (A3, A4, A5, Letter, Legal, etc.)
- ✅ **Task 1.3:** Explicit initialization with `Init()` procedure
- ✅ **Task 1.4:** Safe resource management with `Reset()` and proper cleanup
- ✅ **Task 1.5:** Removed OWA/HTP dependencies - use `OutputBlob()` or `OutputFile()`
- ✅ **Task 1.6:** Native BLOB-based image handling (PNG/JPEG)
- ✅ **Task 1.7:** CLOB-based buffer for unlimited document size (1000+ pages)

### Phase 2: Security & Robustness ✅ IN PROGRESS
- ✅ **Task 2.1:** Complete UTF-8/Unicode support with TrueType fonts
- ✅ **Task 2.2:** Custom exception framework (18 specific exceptions)
- ⏳ **Task 2.3:** Input validation with DBMS_ASSERT
- ✅ **Task 2.4:** Removed generic WHEN OTHERS blocks
- ⏳ **Task 2.5:** Enhanced structured logging

---

## 📋 Table of Contents

1. [Features](#features)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Basic Examples](#basic-examples)
6. [Advanced Features](#advanced-features)
7. [Error Handling](#error-handling)
8. [API Reference](#api-reference)
9. [Migration Guide](#migration-guide)
10. [Documentation](#documentation)
11. [Contributing](#contributing)
12. [License](#license)

---

## ✨ Features

### Core PDF Generation
- 📄 **Multiple page formats**: A3, A4, A5, Letter, Legal, Ledger, Executive, Folio, B5, custom sizes
- 📐 **Measurement units**: millimeters (mm), centimeters (cm), inches (in), points (pt)
- 🔄 **Page orientation**: Portrait (P) or Landscape (L)
- 📝 **Text rendering**: Cell, MultiCell, Text, Write with full formatting
- 🎨 **Graphics**: Lines, rectangles, circles, polygons with fill/stroke options
- 🖼️ **Images**: PNG and JPEG support with BLOB-based handling

### Typography
- 🔤 **Built-in fonts**: Helvetica, Times, Courier (standard PDF fonts)
- 🌍 **TrueType fonts**: Load custom .ttf fonts for Unicode support
- 🎯 **Font styles**: Regular, Bold, Italic, Bold+Italic
- 📏 **Font sizes**: Any size from 1pt to 999pt
- 🌐 **UTF-8 encoding**: Full Unicode character support

### Modern Features (v2.0)
- 🧹 **Clean initialization**: Explicit `Init()` with validation
- 💾 **Flexible output**: Save to file (`OutputFile`) or get as BLOB (`OutputBlob`)
- 📊 **Unlimited size**: CLOB-based buffer supports 1000+ page documents
- ⚡ **Performance**: Optimized memory management and BLOB operations
- 🛡️ **Security**: Input validation, custom exceptions, structured error handling
- 📝 **Logging**: Comprehensive logging with severity levels (1=Error to 4=Debug)

---

## 📦 Requirements

### Minimum Requirements
- **Oracle Database:** 11g Release 2 (11.2.0.1) or higher
- **PL/SQL Version:** 11.2+
- **Privileges:**
  - `CREATE PROCEDURE`
  - `CREATE TYPE`
  - `CREATE DIRECTORY` (for file output)
  - `READ/WRITE` on Oracle directories

### Removed Dependencies (v2.0)
- ❌ Oracle Web Agent (OWA) - **NO LONGER REQUIRED**
- ❌ HTP/HTF packages - **NO LONGER REQUIRED**
- ❌ OrdImage cartridge - **NO LONGER REQUIRED**
- ❌ URIFactory - Optional (only for `ImageFromUrl()`)

---

## 🔧 Installation

### 1. Create Oracle Directories

```sql
-- As DBA or user with CREATE ANY DIRECTORY privilege
CREATE OR REPLACE DIRECTORY PDF_DIR AS '/path/to/pdf/output';
CREATE OR REPLACE DIRECTORY FONTS_DIR AS '/path/to/fonts';

-- Grant permissions to your user
GRANT READ, WRITE ON DIRECTORY PDF_DIR TO your_user;
GRANT READ, WRITE ON DIRECTORY FONTS_DIR TO your_user;
```

### 2. Install Package

```sql
-- Connect as your user
@PL_FPDF.pks   -- Install package specification
@PL_FPDF.pkb   -- Install package body

-- Verify installation
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PL_FPDF';
```

### 3. Configure Logging (Optional)

```sql
-- Set log level (1=Error, 2=Warning, 3=Info, 4=Debug)
EXEC PL_FPDF.SetLogLevel(3);
```

---

## 🚀 Quick Start

### Your First PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- 1. Initialize PDF engine
  PL_FPDF.Init(
    p_orientation => 'P',      -- Portrait
    p_unit        => 'mm',     -- Millimeters
    p_format      => 'A4',     -- A4 page size
    p_encoding    => 'UTF-8'   -- UTF-8 encoding
  );

  -- 2. Add a page
  PL_FPDF.AddPage();

  -- 3. Set font
  PL_FPDF.SetFont('Helvetica', 'B', 16);

  -- 4. Add content
  PL_FPDF.Cell(0, 10, 'Hello World!', 0, 1, 'C');

  -- 5. Output PDF
  l_pdf := PL_FPDF.OutputBlob();

  -- Or save to file
  PL_FPDF.OutputFile('hello.pdf', 'PDF_DIR');

  DBMS_OUTPUT.PUT_LINE('PDF generated successfully!');
END;
/
```

---

## 📖 Basic Examples

### Example 1: Simple Text Document

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  PL_FPDF.AddPage();

  -- Title
  PL_FPDF.SetFont('Helvetica', 'B', 20);
  PL_FPDF.Cell(0, 10, 'Invoice #12345', 0, 1, 'C');
  PL_FPDF.Ln(5);

  -- Body text
  PL_FPDF.SetFont('Helvetica', '', 12);
  PL_FPDF.Cell(40, 10, 'Customer:', 0, 0);
  PL_FPDF.Cell(0, 10, 'Acme Corporation', 0, 1);

  PL_FPDF.Cell(40, 10, 'Date:', 0, 0);
  PL_FPDF.Cell(0, 10, TO_CHAR(SYSDATE, 'YYYY-MM-DD'), 0, 1);

  -- Save
  PL_FPDF.OutputFile('invoice_12345.pdf', 'PDF_DIR');
END;
/
```

### Example 2: Table with Data

```sql
DECLARE
  CURSOR c_employees IS
    SELECT employee_id, first_name, last_name, salary
    FROM employees
    WHERE rownum <= 10;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Header
  PL_FPDF.SetFont('Helvetica', 'B', 14);
  PL_FPDF.Cell(0, 10, 'Employee List', 0, 1, 'C');
  PL_FPDF.Ln(5);

  -- Table header
  PL_FPDF.SetFont('Helvetica', 'B', 11);
  PL_FPDF.SetFillColor(200, 200, 200);
  PL_FPDF.Cell(20, 7, 'ID', 1, 0, 'C', TRUE);
  PL_FPDF.Cell(50, 7, 'First Name', 1, 0, 'L', TRUE);
  PL_FPDF.Cell(50, 7, 'Last Name', 1, 0, 'L', TRUE);
  PL_FPDF.Cell(40, 7, 'Salary', 1, 1, 'R', TRUE);

  -- Table data
  PL_FPDF.SetFont('Helvetica', '', 10);
  FOR rec IN c_employees LOOP
    PL_FPDF.Cell(20, 6, rec.employee_id, 1, 0, 'C');
    PL_FPDF.Cell(50, 6, rec.first_name, 1, 0, 'L');
    PL_FPDF.Cell(50, 6, rec.last_name, 1, 0, 'L');
    PL_FPDF.Cell(40, 6, TO_CHAR(rec.salary, 'FM999G999D00'), 1, 1, 'R');
  END LOOP;

  PL_FPDF.OutputFile('employees.pdf', 'PDF_DIR');
END;
/
```

### Example 3: Images in PDF

```sql
DECLARE
  l_logo BLOB;
BEGIN
  -- Load image from database
  SELECT logo_data INTO l_logo
  FROM company_assets
  WHERE asset_name = 'company_logo';

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Add logo (x, y, width in mm)
  PL_FPDF.Image(l_logo, 10, 10, 50);

  -- Add text below logo
  PL_FPDF.SetY(70);
  PL_FPDF.SetFont('Helvetica', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Company Report', 0, 1, 'C');

  PL_FPDF.OutputFile('report_with_logo.pdf', 'PDF_DIR');
END;
/
```

### Example 4: UTF-8 and Custom Fonts

```sql
DECLARE
  l_font_blob BLOB;
BEGIN
  -- Load TrueType font
  SELECT font_data INTO l_font_blob
  FROM font_repository
  WHERE font_name = 'DejaVuSans';

  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');

  -- Add custom font
  PL_FPDF.AddTTFFont('DejaVu', l_font_blob, 'UTF-8', TRUE);

  PL_FPDF.AddPage();
  PL_FPDF.SetFont('DejaVu', 'N', 14);

  -- Unicode text
  PL_FPDF.Cell(0, 10, 'English: Hello World', 0, 1);
  PL_FPDF.Cell(0, 10, 'Português: Olá Mundo', 0, 1);
  PL_FPDF.Cell(0, 10, 'Español: Hola Mundo', 0, 1);
  PL_FPDF.Cell(0, 10, 'Français: Bonjour le Monde', 0, 1);
  PL_FPDF.Cell(0, 10, 'Deutsch: Hallo Welt', 0, 1);

  PL_FPDF.OutputFile('multilingual.pdf', 'PDF_DIR');
END;
/
```

---

## 🔥 Advanced Features

### Multi-Page Documents

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');

  -- Page 1
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Helvetica', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Page 1 - Introduction', 0, 1);

  -- Page 2
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Page 2 - Content', 0, 1);

  -- Page 3
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Page 3 - Conclusion', 0, 1);

  PL_FPDF.OutputFile('multipage.pdf', 'PDF_DIR');
END;
/
```

### Automatic Page Breaks

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetAutoPageBreak(TRUE, 15);  -- 15mm bottom margin
  PL_FPDF.AddPage();

  PL_FPDF.SetFont('Helvetica', '', 12);

  -- Add lots of text - will automatically create new pages
  FOR i IN 1..100 LOOP
    PL_FPDF.Cell(0, 10, 'Line ' || i || ' of text content', 0, 1);
  END LOOP;

  PL_FPDF.OutputFile('auto_pagination.pdf', 'PDF_DIR');
END;
/
```

### Colors and Styling

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Red text
  PL_FPDF.SetTextColor(255, 0, 0);
  PL_FPDF.SetFont('Helvetica', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Red Bold Text', 0, 1);

  -- Blue filled rectangle
  PL_FPDF.SetFillColor(0, 0, 255);
  PL_FPDF.SetDrawColor(0, 0, 0);
  PL_FPDF.Rect(10, 30, 50, 20, 'DF');  -- Draw and Fill

  -- Green text on yellow background
  PL_FPDF.SetTextColor(0, 128, 0);
  PL_FPDF.SetFillColor(255, 255, 0);
  PL_FPDF.Cell(0, 10, 'Green on Yellow', 1, 1, 'C', TRUE);

  PL_FPDF.OutputFile('colors.pdf', 'PDF_DIR');
END;
/
```

### Graphics and Shapes

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Line
  PL_FPDF.SetDrawColor(255, 0, 0);
  PL_FPDF.SetLineWidth(2);
  PL_FPDF.Line(10, 10, 100, 10);

  -- Rectangle
  PL_FPDF.SetDrawColor(0, 0, 255);
  PL_FPDF.Rect(10, 20, 50, 30, 'D');  -- Draw only

  -- Filled rectangle
  PL_FPDF.SetFillColor(200, 200, 200);
  PL_FPDF.Rect(70, 20, 50, 30, 'F');  -- Fill only

  -- Rectangle with border and fill
  PL_FPDF.SetDrawColor(0, 0, 0);
  PL_FPDF.SetFillColor(255, 200, 200);
  PL_FPDF.Rect(130, 20, 50, 30, 'DF');  -- Draw and Fill

  PL_FPDF.OutputFile('shapes.pdf', 'PDF_DIR');
END;
/
```

---

## 🛡️ Error Handling

PL_FPDF v2.0 implements a comprehensive custom exception framework with 18 specific exceptions organized by category.

### Quick Exception Handling

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('CustomFont', 'N', 12);
  PL_FPDF.Cell(0, 10, 'Hello');
  PL_FPDF.OutputFile('test.pdf', 'PDF_DIR');

EXCEPTION
  WHEN PL_FPDF.exc_invalid_orientation THEN
    DBMS_OUTPUT.PUT_LINE('Invalid orientation specified');

  WHEN PL_FPDF.exc_font_not_found THEN
    DBMS_OUTPUT.PUT_LINE('Font not loaded. Using Helvetica instead.');
    PL_FPDF.SetFont('Helvetica', 'N', 12);

  WHEN PL_FPDF.exc_invalid_directory THEN
    DBMS_OUTPUT.PUT_LINE('Output directory not configured');

  WHEN PL_FPDF.exc_file_write_error THEN
    DBMS_OUTPUT.PUT_LINE('Cannot write PDF file. Check permissions.');

  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
    RAISE;
END;
/
```

### Available Exceptions

| Category | Exceptions |
|----------|------------|
| **Initialization** | `exc_invalid_orientation`, `exc_invalid_unit`, `exc_invalid_encoding`, `exc_not_initialized` |
| **Pages** | `exc_invalid_page_format`, `exc_page_not_found` |
| **Fonts** | `exc_font_not_found`, `exc_invalid_font_file`, `exc_invalid_font_name`, `exc_invalid_font_blob` |
| **Images** | `exc_invalid_image`, `exc_image_not_found`, `exc_unsupported_image_format` |
| **File I/O** | `exc_invalid_directory`, `exc_file_access_denied`, `exc_file_write_error` |
| **Drawing** | `exc_invalid_color`, `exc_invalid_line_width` |
| **General** | `exc_general_error` |

### 📚 Complete Error Documentation

For detailed information about each exception including causes, solutions, and examples, see:

**[ERROR_REFERENCE.md](ERROR_REFERENCE.md)** - Complete error reference guide

---

## 📚 API Reference

### Initialization

```sql
-- Initialize PDF engine (required first step)
PROCEDURE Init(
  p_orientation VARCHAR2 DEFAULT 'P',      -- 'P' or 'L'
  p_unit        VARCHAR2 DEFAULT 'mm',     -- 'mm', 'cm', 'in', 'pt'
  p_format      VARCHAR2 DEFAULT 'A4',     -- Page format
  p_encoding    VARCHAR2 DEFAULT 'UTF-8'   -- Character encoding
);

-- Reset and cleanup
PROCEDURE Reset;
```

### Page Management

```sql
-- Add new page
PROCEDURE AddPage(
  p_orientation VARCHAR2 DEFAULT NULL,  -- Override default orientation
  p_format      VARCHAR2 DEFAULT NULL   -- Override default format
);

-- Get current page number
FUNCTION PageNo RETURN NUMBER;
```

### Font Management

```sql
-- Set current font (built-in fonts)
PROCEDURE SetFont(
  p_family VARCHAR2,           -- 'Helvetica', 'Times', 'Courier'
  p_style  VARCHAR2 DEFAULT '',-- 'B', 'I', 'BI', or ''
  p_size   NUMBER   DEFAULT 0  -- Font size in points
);

-- Add TrueType font from BLOB
PROCEDURE AddTTFFont(
  p_font_name VARCHAR2,
  p_font_blob BLOB,
  p_encoding  VARCHAR2 DEFAULT 'UTF-8',
  p_embed     BOOLEAN  DEFAULT TRUE
);

-- Load TrueType font from file
PROCEDURE LoadTTFFromFile(
  p_font_name  VARCHAR2,
  p_file_path  VARCHAR2,
  p_directory  VARCHAR2 DEFAULT 'FONTS_DIR',
  p_encoding   VARCHAR2 DEFAULT 'UTF-8'
);

-- Check if TTF font is loaded
FUNCTION IsTTFFontLoaded(p_font_name VARCHAR2) RETURN BOOLEAN;

-- Get TTF font info
FUNCTION GetTTFFontInfo(p_font_name VARCHAR2) RETURN recTTFFont;
```

### Text Output

```sql
-- Output text in cell
PROCEDURE Cell(
  w      NUMBER,              -- Width (0 = to right margin)
  h      NUMBER,              -- Height
  txt    VARCHAR2 DEFAULT '', -- Text
  border VARCHAR2 DEFAULT '0',-- Border: 0, 1, or 'LRTB'
  ln     NUMBER   DEFAULT 0,  -- Line break after: 0=right, 1=next line, 2=below
  align  VARCHAR2 DEFAULT '', -- Align: 'L', 'C', 'R'
  fill   BOOLEAN  DEFAULT FALSE -- Fill background
);

-- Multi-line text cell with word wrap
PROCEDURE MultiCell(
  w      NUMBER,              -- Width
  h      NUMBER,              -- Height per line
  txt    VARCHAR2,            -- Text
  border VARCHAR2 DEFAULT '0',
  align  VARCHAR2 DEFAULT 'J' -- 'L', 'C', 'R', 'J' (justified)
);

-- Text at specific position
PROCEDURE Text(
  x   NUMBER,    -- X coordinate
  y   NUMBER,    -- Y coordinate
  txt VARCHAR2   -- Text
);

-- Write text with automatic line breaks
PROCEDURE Write(
  h   NUMBER,    -- Line height
  txt VARCHAR2   -- Text
);
```

### Images

```sql
-- Add image from BLOB
PROCEDURE Image(
  p_blob BLOB,
  p_x    NUMBER,              -- X position
  p_y    NUMBER,              -- Y position
  p_w    NUMBER DEFAULT 0,    -- Width (0 = auto)
  p_h    NUMBER DEFAULT 0     -- Height (0 = auto)
);

-- Add image from URL (requires URIFactory)
PROCEDURE ImageFromUrl(
  p_url  VARCHAR2,
  p_x    NUMBER,
  p_y    NUMBER,
  p_w    NUMBER DEFAULT 0,
  p_h    NUMBER DEFAULT 0
);
```

### Drawing

```sql
-- Set draw color (RGB)
PROCEDURE SetDrawColor(r NUMBER, g NUMBER DEFAULT NULL, b NUMBER DEFAULT NULL);

-- Set fill color (RGB)
PROCEDURE SetFillColor(r NUMBER, g NUMBER DEFAULT NULL, b NUMBER DEFAULT NULL);

-- Set text color (RGB)
PROCEDURE SetTextColor(r NUMBER, g NUMBER DEFAULT NULL, b NUMBER DEFAULT NULL);

-- Set line width
PROCEDURE SetLineWidth(width NUMBER);

-- Draw line
PROCEDURE Line(x1 NUMBER, y1 NUMBER, x2 NUMBER, y2 NUMBER);

-- Draw rectangle
PROCEDURE Rect(
  x     NUMBER,
  y     NUMBER,
  w     NUMBER,
  h     NUMBER,
  style VARCHAR2 DEFAULT '' -- 'D' = draw, 'F' = fill, 'DF' = both
);
```

### Position and Layout

```sql
-- Get/Set X position
FUNCTION  GetX RETURN NUMBER;
PROCEDURE SetX(px NUMBER);

-- Get/Set Y position
FUNCTION  GetY RETURN NUMBER;
PROCEDURE SetY(py NUMBER);

-- Set both X and Y
PROCEDURE SetXY(x NUMBER, y NUMBER);

-- Line break
PROCEDURE Ln(h NUMBER DEFAULT NULL);  -- Height (NULL = current line height)

-- Set margins
PROCEDURE SetMargins(left NUMBER, top NUMBER, right NUMBER DEFAULT -1);
PROCEDURE SetLeftMargin(pMargin NUMBER);
PROCEDURE SetTopMargin(pMargin NUMBER);
PROCEDURE SetRightMargin(pMargin NUMBER);

-- Auto page break
PROCEDURE SetAutoPageBreak(pauto BOOLEAN, pMargin NUMBER DEFAULT 0);
```

### Output

```sql
-- Get PDF as BLOB
FUNCTION OutputBlob RETURN BLOB;

-- Save PDF to file
PROCEDURE OutputFile(
  p_filename  VARCHAR2,
  p_directory VARCHAR2 DEFAULT 'PDF_DIR'
);
```

### UTF-8 Support (Task 2.1)

```sql
-- Convert text to PDF string with UTF-8 encoding
FUNCTION UTF8ToPDFString(
  p_text   VARCHAR2,
  p_escape BOOLEAN DEFAULT TRUE
) RETURN VARCHAR2;

-- Check if UTF-8 is enabled
FUNCTION IsUTF8Enabled RETURN BOOLEAN;

-- Enable/disable UTF-8
PROCEDURE SetUTF8Enabled(p_enabled BOOLEAN DEFAULT TRUE);
```

### Logging

```sql
-- Set log level (1=Error, 2=Warning, 3=Info, 4=Debug)
PROCEDURE SetLogLevel(p_level NUMBER);

-- Get current log level
FUNCTION GetLogLevel RETURN NUMBER;
```

---

## 🔄 Migration Guide

### Migrating from v1.x to v2.0

#### 1. Replace FPDF() constructor with Init()

```sql
-- ❌ Old (v1.x)
pdf.FPDF('P', 'cm', 'A4');
pdf.openpdf;

-- ✅ New (v2.0)
PL_FPDF.Init('P', 'cm', 'A4', 'UTF-8');
```

#### 2. Replace Output() with OutputBlob() or OutputFile()

```sql
-- ❌ Old (v1.x) - requires OWA
pdf.Output();  -- Inline browser output

-- ✅ New (v2.0)
-- Option 1: Get as BLOB
l_pdf := PL_FPDF.OutputBlob();

-- Option 2: Save to file
PL_FPDF.OutputFile('report.pdf', 'PDF_DIR');
```

#### 3. Image handling - use BLOB instead of URL strings

```sql
-- ❌ Old (v1.x)
img := 'http://example.com/logo.gif';
pdf.Image(img, 1, 1, 10);

-- ✅ New (v2.0)
-- Option 1: From BLOB
PL_FPDF.Image(l_image_blob, 10, 10, 50);

-- Option 2: Still can use URL if URIFactory available
PL_FPDF.ImageFromUrl('http://example.com/logo.png', 10, 10, 50);
```

#### 4. Use specific exceptions instead of generic error handling

```sql
-- ❌ Old (v1.x)
BEGIN
  -- code
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20100 THEN
      -- handle error
    END IF;
END;

-- ✅ New (v2.0)
BEGIN
  -- code
EXCEPTION
  WHEN PL_FPDF.exc_font_not_found THEN
    -- handle specific error
  WHEN PL_FPDF.exc_invalid_directory THEN
    -- handle another specific error
END;
```

---

## 📚 Documentation

- **[ERROR_REFERENCE.md](ERROR_REFERENCE.md)** - Complete error reference with causes and solutions
- **[MODERNIZATION_TODO.md](MODERNIZATION_TODO.md)** - Modernization roadmap and progress
- **[TASK_1_3_README.md](TASK_1_3_README.md)** - Task 1.3 implementation details
- **[TASK_1_6_README.md](TASK_1_6_README.md)** - Task 1.6 image handling details
- **[tests/README_TESTS.md](tests/README_TESTS.md)** - Testing documentation

### Validation Scripts

Run these scripts to validate implementation:

```sql
@validate_task_1_3.sql  -- Init/Reset validation
@validate_task_1_6.sql  -- Image handling validation
@validate_task_1_7.sql  -- CLOB buffer validation
@validate_task_2_1.sql  -- UTF-8/Unicode validation
@validate_task_2_2_2_4.sql  -- Exception framework validation
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Test** your changes thoroughly
4. **Commit** with clear messages (`git commit -m 'Add amazing feature'`)
5. **Push** to your branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request

### Development Setup

```bash
git clone https://github.com/Maxwbh/pl_fpdf.git
cd pl_fpdf

# Run validation tests
sqlplus user/pass@db @validate_all.sql
```

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Original FPDF:** [Olivier Plathey](http://www.fpdf.org/) - Original PHP FPDF library
- **PL_FPDF v1.x:** Original Oracle PL/SQL port contributors
- **PL_FPDF v2.0:** [Maxwell da Silva Oliveira](https://github.com/Maxwbh) - Modernization and enhancements

---

## 📧 Support

- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues)
- **Documentation:** [Wiki](https://github.com/Maxwbh/pl_fpdf/wiki)
- **Email:** maxwbh@gmail.com

---

## 🗺️ Roadmap

### Phase 3: Advanced Features (Planned)
- Full TTF CMAP table parsing
- Advanced typography (kerning, ligatures)
- Asian language support (CJK)
- SVG import
- PDF/A compliance
- Digital signatures
- Form fields support
- Bookmarks and outlines
- JSON-based template system

---

**Made with ❤️ for the Oracle community**

**Version:** 2.0.0
**Last Updated:** 2025-12-18
**Status:** Active Development
