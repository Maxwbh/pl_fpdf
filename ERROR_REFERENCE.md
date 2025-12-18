# PL_FPDF - Error Reference Guide

**Version:** 2.0
**Last Updated:** 2025-12-18
**Tasks:** 2.2 & 2.4 - Custom Exceptions and Error Handling

---

## Table of Contents

1. [Introduction](#introduction)
2. [Error Code Ranges](#error-code-ranges)
3. [Initialization Errors (-20001 to -20010)](#initialization-errors)
4. [Page Errors (-20101 to -20110)](#page-errors)
5. [Font Errors (-20201 to -20215)](#font-errors)
6. [Image Errors (-20301 to -20310)](#image-errors)
7. [File I/O Errors (-20401 to -20410)](#file-io-errors)
8. [Color/Drawing Errors (-20501 to -20510)](#colordrawing-errors)
9. [General Errors (-20100)](#general-errors)
10. [How to Handle Exceptions](#how-to-handle-exceptions)

---

## Introduction

PL_FPDF v2.0 implements a comprehensive custom exception framework to provide clear, actionable error messages. Each exception has:

- **Unique error code** - Organized by category
- **Descriptive name** - Easy to catch in exception handlers
- **Contextual message** - Explains what went wrong and why
- **Resolution guidance** - How to fix the issue

All exceptions can be caught by name using `EXCEPTION WHEN PL_FPDF.exc_name THEN` blocks.

---

## Error Code Ranges

| Range | Category | Description |
|-------|----------|-------------|
| -20001 to -20010 | Initialization | Errors during PL_FPDF.Init() |
| -20101 to -20110 | Pages | Page format and page operations |
| -20201 to -20215 | Fonts | Font loading, validation, and usage |
| -20301 to -20310 | Images | Image loading and format validation |
| -20401 to -20410 | File I/O | File system operations |
| -20501 to -20510 | Colors/Drawing | Color validation and drawing operations |
| -20100 | General | Generic errors and legacy operations |

---

## Initialization Errors

### exc_invalid_orientation (-20001)

**When it occurs:**
During `PL_FPDF.Init()` when an invalid page orientation is specified.

**Possible causes:**
- Passed an orientation other than 'P' (Portrait) or 'L' (Landscape)
- Typo in orientation parameter
- Lowercase 'p' or 'l' (though these are auto-converted to uppercase)

**Message format:**
```
Invalid orientation: {orientation}. Must be P or L.
```

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.Init('X', 'mm', 'A4');  -- 'X' is invalid

-- ✅ Correct
PL_FPDF.Init('P', 'mm', 'A4');  -- Portrait
PL_FPDF.Init('L', 'mm', 'A4');  -- Landscape
```

**Exception handling:**
```sql
BEGIN
  PL_FPDF.Init(p_orientation, 'mm', 'A4');
EXCEPTION
  WHEN PL_FPDF.exc_invalid_orientation THEN
    DBMS_OUTPUT.PUT_LINE('Invalid orientation. Using Portrait as default.');
    PL_FPDF.Init('P', 'mm', 'A4');
END;
```

---

### exc_invalid_unit (-20002)

**When it occurs:**
During `PL_FPDF.Init()` when an invalid measurement unit is specified.

**Possible causes:**
- Specified a unit other than 'mm', 'cm', 'in', or 'pt'
- Typo in unit parameter
- Using full names like 'millimeter' instead of 'mm'

**Message format:**
```
Invalid unit: {unit}. Must be mm, cm, in, or pt.
```

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.Init('P', 'inch', 'A4');      -- Should be 'in'
PL_FPDF.Init('P', 'millimeter', 'A4'); -- Should be 'mm'

-- ✅ Correct
PL_FPDF.Init('P', 'mm', 'A4');  -- Millimeters
PL_FPDF.Init('P', 'cm', 'A4');  -- Centimeters
PL_FPDF.Init('P', 'in', 'A4');  -- Inches
PL_FPDF.Init('P', 'pt', 'A4');  -- Points (1/72 inch)
```

---

### exc_invalid_encoding (-20003)

**When it occurs:**
During `PL_FPDF.Init()` when an unsupported character encoding is specified.

**Possible causes:**
- Specified an encoding not supported by PL_FPDF
- Typo in encoding parameter
- Using older encoding names

**Message format:**
```
Unsupported encoding: {encoding}
```

**Supported encodings:**
- `UTF-8` (recommended)
- `UTF8` (alias for UTF-8)
- `AL32UTF8` (Oracle database charset)
- `ISO-8859-1` (Latin-1)
- `WINDOWS-1252` (Windows Latin-1)

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.Init('P', 'mm', 'A4', 'ASCII');      -- Not supported
PL_FPDF.Init('P', 'mm', 'A4', 'LATIN1');     -- Use ISO-8859-1

-- ✅ Correct
PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');      -- Recommended
PL_FPDF.Init('P', 'mm', 'A4', 'ISO-8859-1'); -- Latin-1
```

---

### exc_not_initialized (-20005)

**When it occurs:**
When calling PL_FPDF functions before calling `Init()`.

**Possible causes:**
- Forgot to call `PL_FPDF.Init()` at the start
- Calling functions in wrong order
- Session state was reset

**Message format:**
```
PL_FPDF not initialized. Call Init() first.
```

**How to resolve:**
```sql
-- ❌ Wrong - AddPage before Init
BEGIN
  PL_FPDF.AddPage();  -- ERROR: Not initialized
END;

-- ✅ Correct - Init first
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  -- ... rest of code
END;
```

---

## Page Errors

### exc_invalid_page_format (-20101)

**When it occurs:**
When an invalid page format is specified.

**Possible causes:**
- Using unknown page format name
- Typo in format name
- Invalid custom format dimensions
- Negative or zero dimensions in custom format

**Message format:**
```
Unknown page format: {format}. Use A3, A4, A5, Letter, Legal, Ledger, Executive, Folio, B5, or custom format like "100,200"
```
or
```
Invalid custom format dimensions: {format}. Width and height must be positive.
```

**Supported formats:**
- **ISO A series:** A3, A4, A5
- **North American:** Letter, Legal, Ledger, Tabloid
- **Other:** Executive, Folio, B5
- **Custom:** "width,height" in mm (e.g., "210,297")

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.Init('P', 'mm', 'A6');      -- A6 not supported
PL_FPDF.Init('P', 'mm', '0,100');   -- Zero width
PL_FPDF.Init('P', 'mm', '-10,100'); -- Negative dimension

-- ✅ Correct
PL_FPDF.Init('P', 'mm', 'A4');      -- Standard format
PL_FPDF.Init('P', 'mm', 'Letter');  -- US Letter
PL_FPDF.Init('P', 'mm', '100,150'); -- Custom 100mm x 150mm
```

---

### exc_page_not_found (-20106)

**When it occurs:**
When trying to access a page that doesn't exist.

**Possible causes:**
- Referencing page number that hasn't been created yet
- Page number out of range
- Trying to access page 0 or negative page numbers

**Message format:**
```
Page {page_number} not found. Valid range: 1 to {total_pages}
```

**How to resolve:**
```sql
-- Check page count first
DECLARE
  l_page_count NUMBER;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();  -- Creates page 1

  -- ❌ Wrong - page 2 doesn't exist yet
  -- PL_FPDF.SetPage(2);  -- ERROR

  -- ✅ Correct - check or create first
  l_page_count := PL_FPDF.PageNo();
  IF l_page_count >= 2 THEN
    PL_FPDF.SetPage(2);
  ELSE
    PL_FPDF.AddPage();  -- Create page 2
  END IF;
END;
```

---

## Font Errors

### exc_font_not_found (-20201)

**When it occurs:**
When trying to use a font that hasn't been loaded.

**Possible causes:**
- Font name typo
- Forgot to call `AddTTFFont()` or `LoadTTFFromFile()`
- Font name case mismatch (though names are normalized to uppercase)
- Using font before loading it

**Message format:**
```
Font not found: {font_name}. Call AddTTFFont() or LoadTTFFromFile() first.
```

**How to resolve:**
```sql
-- ❌ Wrong - using font before loading
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('MyFont', 'N', 12);  -- ERROR: MyFont not loaded
END;

-- ✅ Correct - load font first
DECLARE
  l_font_blob BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');

  -- Load font first
  SELECT font_data INTO l_font_blob
  FROM my_fonts_table
  WHERE font_name = 'MyFont';

  PL_FPDF.AddTTFFont('MyFont', l_font_blob);

  -- Now can use it
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('MyFont', 'N', 12);
END;

-- ✅ Or load from file
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.LoadTTFFromFile('MyFont', 'myfont.ttf', 'FONTS_DIR');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('MyFont', 'N', 12);
END;
```

---

### exc_invalid_font_file (-20202)

**When it occurs:**
When a TrueType font file is invalid or corrupted.

**Possible causes:**
- Font BLOB is NULL or too small (<12 bytes)
- Font file is corrupted
- Wrong file type (not TTF/OTF)
- TrueType Collection (.ttc) files not supported
- Invalid TTF/OTF magic number

**Message format:**
```
Invalid font BLOB: NULL or too small (<12 bytes)
```
or
```
Invalid TTF/OTF magic number: {hex_value}
```
or
```
TrueType Collections (.ttc) not yet supported
```
or
```
File not found: {file_path} in directory {directory}
```

**How to resolve:**
```sql
-- Check BLOB validity
DECLARE
  l_font_blob BLOB;
  l_blob_size NUMBER;
BEGIN
  SELECT font_data INTO l_font_blob
  FROM my_fonts_table
  WHERE font_name = 'MyFont';

  l_blob_size := DBMS_LOB.GETLENGTH(l_font_blob);

  -- ❌ Check if valid
  IF l_font_blob IS NULL OR l_blob_size < 12 THEN
    RAISE_APPLICATION_ERROR(-20100, 'Font file is invalid or empty');
  END IF;

  -- ✅ Valid BLOB
  PL_FPDF.AddTTFFont('MyFont', l_font_blob);
END;
```

**Supported font formats:**
- ✅ TrueType (.ttf)
- ✅ OpenType with TrueType outlines (.otf)
- ❌ TrueType Collections (.ttc) - not yet supported
- ❌ OpenType with CFF outlines - limited support

---

### exc_invalid_font_name (-20210)

**When it occurs:**
When font name is NULL or empty.

**Possible causes:**
- Passed NULL as font name
- Passed empty string ''
- Passed string with only whitespace '   '

**Message format:**
```
Font name cannot be NULL or empty
```

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.AddTTFFont(NULL, l_font_blob);     -- NULL name
PL_FPDF.AddTTFFont('', l_font_blob);       -- Empty name
PL_FPDF.AddTTFFont('   ', l_font_blob);    -- Whitespace only

-- ✅ Correct
PL_FPDF.AddTTFFont('MyFont', l_font_blob); -- Valid name
```

---

### exc_invalid_font_blob (-20211)

**When it occurs:**
When font BLOB parameter is NULL.

**Possible causes:**
- Passed NULL BLOB to `AddTTFFont()`
- Font file not found in table/query
- Variable not initialized

**Message format:**
```
Font BLOB cannot be NULL
```

**How to resolve:**
```sql
-- ❌ Wrong
DECLARE
  l_font_blob BLOB;  -- NULL by default
BEGIN
  PL_FPDF.AddTTFFont('MyFont', l_font_blob);  -- ERROR: BLOB is NULL
END;

-- ✅ Correct - check for NULL first
DECLARE
  l_font_blob BLOB;
BEGIN
  SELECT font_data INTO l_font_blob
  FROM my_fonts_table
  WHERE font_name = 'MyFont';

  IF l_font_blob IS NOT NULL THEN
    PL_FPDF.AddTTFFont('MyFont', l_font_blob);
  ELSE
    RAISE_APPLICATION_ERROR(-20100, 'Font data not found in database');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20100, 'Font not found in database');
END;
```

---

## Image Errors

### exc_invalid_image (-20301)

**When it occurs:**
When an image file has invalid or corrupted headers.

**Possible causes:**
- PNG file with invalid PNG signature
- JPEG file with invalid JPEG markers
- Corrupted image data
- Image BLOB is truncated or incomplete

**Message format:**
```
Invalid PNG header in image: {url/filename}
```
or
```
Invalid JPEG header in image: {url/filename}
```

**How to resolve:**
```sql
-- Validate image before adding
DECLARE
  l_img_blob BLOB;
  l_signature RAW(8);
BEGIN
  -- Load image
  SELECT image_data INTO l_img_blob
  FROM images_table
  WHERE id = 123;

  -- Check PNG signature (89 50 4E 47 0D 0A 1A 0A)
  l_signature := DBMS_LOB.SUBSTR(l_img_blob, 8, 1);

  IF l_signature = HEXTORAW('89504E470D0A1A0A') THEN
    -- Valid PNG
    PL_FPDF.Image(l_img_blob, 10, 10, 50);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Image is not a valid PNG');
  END IF;
END;
```

---

### exc_image_not_found (-20302)

**When it occurs:**
When unable to fetch image from URL or file.

**Possible causes:**
- URL is unreachable
- Network connectivity issues
- File doesn't exist at specified path
- Permission denied accessing file
- Invalid URL format

**Message format:**
```
Unable to fetch image from URL: {url} - {error_details}
```

**How to resolve:**
```sql
-- Handle network errors gracefully
BEGIN
  PL_FPDF.ImageFromUrl('https://example.com/image.png', 10, 10, 50);
EXCEPTION
  WHEN PL_FPDF.exc_image_not_found THEN
    DBMS_OUTPUT.PUT_LINE('Unable to fetch image. Using placeholder instead.');
    -- Use local placeholder image
    PL_FPDF.Image(get_placeholder_blob(), 10, 10, 50);
END;
```

---

### exc_unsupported_image_format (-20303)

**When it occurs:**
When trying to use an image format not supported by PL_FPDF.

**Possible causes:**
- Using BMP, GIF, TIFF, or other formats
- Image has unknown MIME type
- File extension doesn't match actual format

**Message format:**
```
Unsupported image format (only PNG and JPEG supported): {mime_type} for URL: {url}
```

**Supported formats:**
- ✅ PNG (.png)
- ✅ JPEG (.jpg, .jpeg)
- ❌ GIF, BMP, TIFF, WebP, SVG - not supported

**How to resolve:**
```sql
-- Convert images to PNG or JPEG before using
-- Use external tools or Oracle MULTIMEDIA for conversion

-- ❌ Wrong
PL_FPDF.Image('image.bmp', 10, 10, 50);  -- BMP not supported

-- ✅ Correct - convert to PNG first (pseudocode)
-- Use image conversion tool or library
-- Then load converted image
PL_FPDF.Image('image.png', 10, 10, 50);
```

---

## File I/O Errors

### exc_invalid_directory (-20401)

**When it occurs:**
When trying to access an invalid or non-existent Oracle directory.

**Possible causes:**
- Directory object doesn't exist in database
- Typo in directory name
- Directory object not created with `CREATE DIRECTORY`
- OS directory path doesn't exist

**Message format:**
```
Invalid or non-existent directory: {directory_name}
```

**How to resolve:**
```sql
-- 1. Check if directory exists
SELECT directory_name, directory_path
FROM all_directories
WHERE directory_name = 'PDF_DIR';

-- 2. Create directory if needed (as DBA or with CREATE ANY DIRECTORY privilege)
CREATE OR REPLACE DIRECTORY PDF_DIR AS '/path/to/pdf/directory';

-- 3. Grant permissions
GRANT READ, WRITE ON DIRECTORY PDF_DIR TO your_user;

-- 4. Use correct directory name
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Test');
  PL_FPDF.OutputFile('test.pdf', 'PDF_DIR');  -- Use exact directory name
END;
```

**Common directory errors:**
```sql
-- ❌ Wrong
PL_FPDF.OutputFile('test.pdf', '/tmp/pdf');     -- Use directory name, not path
PL_FPDF.OutputFile('test.pdf', 'pdf_dir');      -- Case sensitive: use 'PDF_DIR'

-- ✅ Correct
PL_FPDF.OutputFile('test.pdf', 'PDF_DIR');      -- Use Oracle directory name
PL_FPDF.LoadTTFFromFile('Arial', 'arial.ttf', 'FONTS_DIR');  -- Correct
```

---

### exc_file_access_denied (-20402)

**When it occurs:**
When user lacks permissions to read/write files in directory.

**Possible causes:**
- No READ/WRITE privileges on Oracle directory
- OS-level permissions deny access
- Directory path permissions incorrect
- SELinux or AppArmor blocking access

**Message format:**
```
Permission denied accessing: {directory_name}
```
or
```
Permission denied accessing directory: {directory_name}
```

**How to resolve:**
```sql
-- 1. Check current privileges
SELECT grantee, privilege
FROM all_tab_privs
WHERE table_name = 'PDF_DIR';

-- 2. Grant privileges (as DBA or directory owner)
GRANT READ, WRITE ON DIRECTORY PDF_DIR TO your_user;

-- 3. Check OS permissions (as OS admin)
-- Directory must be readable/writable by Oracle process owner
-- Typical: /oracle/admin/orcl/pdf_output
-- ls -ld /oracle/admin/orcl/pdf_output
-- chmod 755 /oracle/admin/orcl/pdf_output  (if needed)
-- chown oracle:dba /oracle/admin/orcl/pdf_output  (if needed)
```

---

### exc_file_write_error (-20403)

**When it occurs:**
When unable to write PDF file to disk.

**Possible causes:**
- Disk full (no space left on device)
- File already exists and is locked
- Invalid filename (special characters)
- Path too long
- Insufficient OS permissions

**Message format:**
```
Error opening file: {error_details}
```
or
```
Error writing file: {error_details}
```

**How to resolve:**
```sql
-- Use valid filenames
-- ❌ Wrong - invalid characters
PL_FPDF.OutputFile('report|2024.pdf', 'PDF_DIR');   -- Pipe char invalid
PL_FPDF.OutputFile('data/report.pdf', 'PDF_DIR');    -- No subdirectories

-- ✅ Correct - safe filenames
PL_FPDF.OutputFile('report_2024.pdf', 'PDF_DIR');
PL_FPDF.OutputFile('invoice_' || p_invoice_id || '.pdf', 'PDF_DIR');

-- Handle errors gracefully
BEGIN
  PL_FPDF.OutputFile('report.pdf', 'PDF_DIR');
EXCEPTION
  WHEN PL_FPDF.exc_file_write_error THEN
    -- Try alternative filename
    PL_FPDF.OutputFile('report_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS') || '.pdf', 'PDF_DIR');
  WHEN PL_FPDF.exc_invalid_directory THEN
    DBMS_OUTPUT.PUT_LINE('Directory not configured. Contact administrator.');
END;
```

---

## Color/Drawing Errors

### exc_invalid_color (-20501)

**When it occurs:**
When color values are out of valid range.

**Possible causes:**
- RGB values outside 0-255 range
- Negative color values
- Using decimal values instead of integers
- Wrong color format

**Message format:**
```
Invalid color value: {color}. RGB values must be 0-255.
```

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.SetFillColor(300, 100, 50);   -- 300 > 255
PL_FPDF.SetDrawColor(-10, 50, 100);   -- Negative value
PL_FPDF.SetTextColor(1.5, 2.8, 3.2);  -- Use integers, not decimals

-- ✅ Correct
PL_FPDF.SetFillColor(255, 100, 50);   -- Max red
PL_FPDF.SetDrawColor(0, 0, 0);        -- Black
PL_FPDF.SetTextColor(128, 128, 128);  -- Gray

-- Common colors
PL_FPDF.SetFillColor(255, 255, 255);  -- White
PL_FPDF.SetFillColor(0, 0, 0);        -- Black
PL_FPDF.SetFillColor(255, 0, 0);      -- Red
PL_FPDF.SetFillColor(0, 255, 0);      -- Green
PL_FPDF.SetFillColor(0, 0, 255);      -- Blue
```

---

### exc_invalid_line_width (-20502)

**When it occurs:**
When line width is negative or invalid.

**Possible causes:**
- Negative line width
- Zero line width when drawing
- Extremely large line width

**Message format:**
```
Invalid line width: {width}. Must be positive.
```

**How to resolve:**
```sql
-- ❌ Wrong
PL_FPDF.SetLineWidth(-1);      -- Negative
PL_FPDF.SetLineWidth(0);       -- Zero (invisible)
PL_FPDF.SetLineWidth(1000);    -- Too large

-- ✅ Correct
PL_FPDF.SetLineWidth(0.1);     -- Thin line
PL_FPDF.SetLineWidth(0.5);     -- Normal line (default)
PL_FPDF.SetLineWidth(1.0);     -- Thick line
PL_FPDF.SetLineWidth(2.0);     -- Very thick line
```

---

## General Errors

### exc_general_error (-20100)

**When it occurs:**
Generic errors that don't fit into specific categories, or legacy operations.

**Possible causes:**
- Using deprecated/removed functionality (OWA/HTP modes)
- Invalid parameters to legacy functions
- Unexpected internal errors
- Missing required parameters

**Message format:**
```
<B>PL_FPDF error: </B>{error_message}
```
or
```
Output mode '{mode}' is no longer supported (OWA/HTP removed). Use OutputBlob() to get PDF as BLOB, or OutputFile() to save to filesystem.
```
or
```
Invalid output destination: {dest}. Use 'F' for file output, or call OutputBlob()/OutputFile() directly.
```

**How to resolve:**
```sql
-- ❌ Wrong - using deprecated OWA modes
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Test');
  PL_FPDF.Output('test.pdf', 'I');  -- 'I' mode (inline browser) removed
END;

-- ✅ Correct - use modern methods
DECLARE
  l_pdf_blob BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Test');

  -- Get as BLOB for custom handling
  l_pdf_blob := PL_FPDF.OutputBlob();

  -- Or save directly to file
  PL_FPDF.OutputFile('test.pdf', 'PDF_DIR');
END;
```

---

## How to Handle Exceptions

### Basic Exception Handling

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'N', 12);
  PL_FPDF.Cell(0, 10, 'Hello World');
  l_pdf := PL_FPDF.OutputBlob();

EXCEPTION
  -- Catch specific exceptions
  WHEN PL_FPDF.exc_invalid_orientation THEN
    DBMS_OUTPUT.PUT_LINE('Invalid orientation specified');

  WHEN PL_FPDF.exc_invalid_unit THEN
    DBMS_OUTPUT.PUT_LINE('Invalid measurement unit');

  WHEN PL_FPDF.exc_font_not_found THEN
    DBMS_OUTPUT.PUT_LINE('Font not found. Using default font.');
    -- Retry with default font
    PL_FPDF.SetFont('Helvetica', 'N', 12);

  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
    RAISE;
END;
```

### Checking Error Codes

```sql
EXCEPTION
  WHEN OTHERS THEN
    CASE SQLCODE
      WHEN -20001 THEN
        DBMS_OUTPUT.PUT_LINE('Invalid orientation');
      WHEN -20002 THEN
        DBMS_OUTPUT.PUT_LINE('Invalid unit');
      WHEN -20201 THEN
        DBMS_OUTPUT.PUT_LINE('Font not found');
      ELSE
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
    END CASE;
END;
```

### Logging Exceptions with Stack Trace

```sql
EXCEPTION
  WHEN OTHERS THEN
    -- Log full error details
    INSERT INTO error_log (
      error_time,
      error_code,
      error_message,
      error_stack,
      error_backtrace
    ) VALUES (
      SYSTIMESTAMP,
      SQLCODE,
      SQLERRM,
      DBMS_UTILITY.FORMAT_ERROR_STACK,
      DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
    );
    COMMIT;
    RAISE;
END;
```

### Graceful Degradation

```sql
DECLARE
  l_pdf BLOB;
  l_font_name VARCHAR2(100) := 'CustomFont';
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Try custom font first, fall back to standard
  BEGIN
    PL_FPDF.SetFont(l_font_name, 'N', 12);
  EXCEPTION
    WHEN PL_FPDF.exc_font_not_found THEN
      DBMS_OUTPUT.PUT_LINE('Custom font not available, using Helvetica');
      PL_FPDF.SetFont('Helvetica', 'N', 12);
  END;

  PL_FPDF.Cell(0, 10, 'Document content');

  -- Try to save, fall back to BLOB
  BEGIN
    PL_FPDF.OutputFile('report.pdf', 'PDF_DIR');
  EXCEPTION
    WHEN PL_FPDF.exc_invalid_directory THEN
      DBMS_OUTPUT.PUT_LINE('Cannot write to directory, returning BLOB instead');
      l_pdf := PL_FPDF.OutputBlob();
      -- Store BLOB in database or return to application
  END;
END;
```

### Application-Level Error Handling

```sql
CREATE OR REPLACE PROCEDURE generate_customer_report(
  p_customer_id NUMBER,
  p_output_file VARCHAR2
) IS
  l_pdf BLOB;
  l_customer_name VARCHAR2(200);
BEGIN
  -- Get customer data
  SELECT customer_name INTO l_customer_name
  FROM customers
  WHERE customer_id = p_customer_id;

  -- Generate PDF
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Helvetica', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Customer Report: ' || l_customer_name);

  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.OutputFile(p_output_file, 'PDF_DIR');

  DBMS_OUTPUT.PUT_LINE('Report generated successfully: ' || p_output_file);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Customer not found: ' || p_customer_id);

  WHEN PL_FPDF.exc_invalid_directory THEN
    RAISE_APPLICATION_ERROR(-20002,
      'PDF output directory not configured. Contact administrator.');

  WHEN PL_FPDF.exc_file_write_error THEN
    RAISE_APPLICATION_ERROR(-20003,
      'Unable to write PDF file. Check disk space and permissions.');

  WHEN OTHERS THEN
    -- Log error and re-raise with context
    log_error('generate_customer_report',
              'customer_id=' || p_customer_id,
              SQLERRM);
    RAISE_APPLICATION_ERROR(-20099,
      'Error generating report: ' || SQLERRM);
END generate_customer_report;
```

---

## Best Practices

### 1. Always Initialize First
```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
  -- ... rest of code
END;
```

### 2. Validate Inputs Early
```sql
IF p_orientation NOT IN ('P', 'L') THEN
  RAISE_APPLICATION_ERROR(-20001, 'Invalid orientation');
END IF;
```

### 3. Use Named Exceptions
```sql
EXCEPTION
  WHEN PL_FPDF.exc_font_not_found THEN  -- ✅ Clear and specific
    handle_missing_font();
  -- Instead of:
  WHEN OTHERS THEN                       -- ❌ Too generic
    IF SQLCODE = -20201 THEN
      handle_missing_font();
    END IF;
END;
```

### 4. Provide Context in Logs
```sql
EXCEPTION
  WHEN OTHERS THEN
    log_error(
      'Failed to generate PDF for customer ' || p_customer_id ||
      ': ' || SQLERRM || CHR(10) ||
      DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
    );
    RAISE;
END;
```

### 5. Don't Swallow Exceptions
```sql
-- ❌ Bad - silently ignores errors
EXCEPTION
  WHEN OTHERS THEN
    NULL;

-- ✅ Good - log and re-raise
EXCEPTION
  WHEN OTHERS THEN
    log_error('Operation failed: ' || SQLERRM);
    RAISE;
```

---

## Quick Reference

| Exception Name | Code | Category | Common Cause |
|----------------|------|----------|--------------|
| exc_invalid_orientation | -20001 | Init | Wrong orientation parameter |
| exc_invalid_unit | -20002 | Init | Wrong unit parameter |
| exc_invalid_encoding | -20003 | Init | Unsupported encoding |
| exc_not_initialized | -20005 | Init | Forgot to call Init() |
| exc_invalid_page_format | -20101 | Page | Unknown page format |
| exc_page_not_found | -20106 | Page | Page number out of range |
| exc_font_not_found | -20201 | Font | Font not loaded |
| exc_invalid_font_file | -20202 | Font | Corrupted font file |
| exc_invalid_font_name | -20210 | Font | NULL or empty font name |
| exc_invalid_font_blob | -20211 | Font | NULL font BLOB |
| exc_invalid_image | -20301 | Image | Corrupted image |
| exc_image_not_found | -20302 | Image | Cannot fetch image |
| exc_unsupported_image_format | -20303 | Image | Wrong image format |
| exc_invalid_directory | -20401 | File I/O | Directory doesn't exist |
| exc_file_access_denied | -20402 | File I/O | No permissions |
| exc_file_write_error | -20403 | File I/O | Cannot write file |
| exc_invalid_color | -20501 | Drawing | Color out of range |
| exc_invalid_line_width | -20502 | Drawing | Invalid line width |
| exc_general_error | -20100 | General | Various errors |

---

## Support

For more information:
- **GitHub Issues:** https://github.com/Maxwbh/pl_fpdf/issues
- **Documentation:** See `README.md` and `MODERNIZATION_TODO.md`
- **Test Files:** `validate_task_2_2_2_4.sql`

**Version History:**
- v2.0 (2025-12-18): Added custom exception framework (Tasks 2.2 & 2.4)
- v1.x: Legacy error handling with generic codes
