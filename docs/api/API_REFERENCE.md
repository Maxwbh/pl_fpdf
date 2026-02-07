# PL_FPDF API Reference v2.0

Complete API reference for PL_FPDF - PDF generation library for Oracle PL/SQL.

---

## Table of Contents

1. [Initialization & Lifecycle](#initialization--lifecycle)
2. [Page Management](#page-management)
3. [Font Management](#font-management)
4. [Text Rendering](#text-rendering)
5. [Graphics & Drawing](#graphics--drawing)
6. [Image Handling](#image-handling)
7. [Output Methods](#output-methods)
8. [Configuration & Metadata](#configuration--metadata)
9. [Utility Functions](#utility-functions)
10. [Custom Exceptions](#custom-exceptions)

---

## Initialization & Lifecycle

### `Init`

```sql
PROCEDURE Init(
  p_orientation VARCHAR2 DEFAULT 'P',
  p_unit VARCHAR2 DEFAULT 'mm',
  p_format VARCHAR2 DEFAULT 'A4',
  p_encoding VARCHAR2 DEFAULT 'UTF-8'
);
```

**Description**: Initializes the PDF generation engine with modern Oracle 19c+ features.

**Parameters**:
- `p_orientation` - Page orientation: `'P'` (Portrait) or `'L'` (Landscape)
- `p_unit` - Measurement unit: `'mm'`, `'cm'`, `'in'`, or `'pt'`
- `p_format` - Page format: `'A4'`, `'A3'`, `'A5'`, `'Letter'`, `'Legal'`, or custom `'width,height'`
- `p_encoding` - Character encoding (default `'UTF-8'`)

**Raises**:
- `-20001`: Invalid orientation parameter
- `-20002`: Invalid measurement unit
- `-20003`: Unsupported encoding

**Example**:
```sql
PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
```

---

### `Reset`

```sql
PROCEDURE Reset;
```

**Description**: Resets the PDF engine to initial state, freeing all resources including temporary CLOBs and clearing all arrays.

**Example**:
```sql
PL_FPDF.Reset();
```

---

### `IsInitialized`

```sql
FUNCTION IsInitialized RETURN BOOLEAN DETERMINISTIC;
```

**Description**: Checks if the PDF engine has been properly initialized via `Init()`.

**Returns**: `TRUE` if initialized, `FALSE` otherwise

**Example**:
```sql
IF PL_FPDF.IsInitialized() THEN
  -- Continue processing
END IF;
```

---

## Page Management

### `AddPage`

```sql
PROCEDURE AddPage(
  p_orientation VARCHAR2 DEFAULT NULL,
  p_format VARCHAR2 DEFAULT NULL,
  p_rotation PLS_INTEGER DEFAULT 0
);
```

**Description**: Adds a new page to the PDF document with modern CLOB streaming.

**Parameters**:
- `p_orientation` - Page orientation (`'P'` or `'L'`, `NULL` = current)
- `p_format` - Page format (`'A4'`, custom `'width,height'`, `NULL` = current)
- `p_rotation` - Page rotation in degrees (`0`, `90`, `180`, `270`)

**Raises**:
- `-20100`: PDF not initialized
- `-20101`: Invalid orientation
- `-20102`: Page dimensions too large (>10000mm)
- `-20104`: Invalid rotation value

**Examples**:
```sql
PL_FPDF.AddPage();                          -- Use current settings
PL_FPDF.AddPage('P', 'A4', 0);             -- Portrait A4, no rotation
PL_FPDF.AddPage('L', '210,297', 90);       -- Custom format with rotation
```

---

### `SetPage`

```sql
PROCEDURE SetPage(p_page_number PLS_INTEGER);
```

**Description**: Sets the current active page for content manipulation.

**Parameters**:
- `p_page_number` - Page number to set as current (must exist)

**Raises**:
- `-20105`: PDF not initialized
- `-20106`: Page does not exist

**Example**:
```sql
PL_FPDF.SetPage(1);  -- Go back to page 1
```

---

### `GetCurrentPage`

```sql
FUNCTION GetCurrentPage RETURN PLS_INTEGER DETERMINISTIC;
```

**Description**: Returns the current page number.

**Returns**: Current page number (PLS_INTEGER)

**Example**:
```sql
l_page := PL_FPDF.GetCurrentPage();
```

---

### `PageNo`

```sql
FUNCTION PageNo RETURN NUMBER;
```

**Description**: Returns the current page number (legacy compatibility).

**Returns**: Current page number

---

## Font Management

### `SetFont`

```sql
PROCEDURE SetFont(
  pfamily VARCHAR2,
  pstyle VARCHAR2 DEFAULT '',
  psize NUMBER DEFAULT 0
);
```

**Description**: Sets the current font family, style, and size.

**Parameters**:
- `pfamily` - Font family: `'Arial'`, `'Courier'`, `'Times'`, `'Helvetica'`, or custom TrueType font name
- `pstyle` - Font style: `''` (regular), `'B'` (bold), `'I'` (italic), `'BI'` (bold italic)
- `psize` - Font size in points (0 = keep current size)

**Raises**:
- `-20201`: Font not found

**Example**:
```sql
PL_FPDF.SetFont('Arial', 'B', 16);  -- Arial Bold 16pt
```

---

### `SetFontSize`

```sql
PROCEDURE SetFontSize(psize NUMBER);
```

**Description**: Sets font size without changing family or style.

**Parameters**:
- `psize` - Font size in points

**Example**:
```sql
PL_FPDF.SetFontSize(12);
```

---

### `GetCurrentFontSize`

```sql
FUNCTION GetCurrentFontSize RETURN NUMBER;
```

**Description**: Returns the current font size.

**Returns**: Font size in points

---

### `GetCurrentFontStyle`

```sql
FUNCTION GetCurrentFontStyle RETURN VARCHAR2;
```

**Description**: Returns the current font style.

**Returns**: Font style (`''`, `'B'`, `'I'`, `'BI'`)

---

### `GetCurrentFontFamily`

```sql
FUNCTION GetCurrentFontFamily RETURN VARCHAR2;
```

**Description**: Returns the current font family name.

**Returns**: Font family name

---

### `GetStringWidth`

```sql
FUNCTION GetStringWidth(pstr VARCHAR2) RETURN NUMBER;
```

**Description**: Calculates the width of a string in the current font.

**Parameters**:
- `pstr` - String to measure

**Returns**: String width in current unit

**Example**:
```sql
l_width := PL_FPDF.GetStringWidth('Hello World');
```

---

### `AddTTFFont`

```sql
PROCEDURE AddTTFFont(
  p_font_name VARCHAR2,
  p_font_blob BLOB,
  p_encoding VARCHAR2 DEFAULT 'UTF-8',
  p_embed BOOLEAN DEFAULT TRUE
);
```

**Description**: Adds a TrueType font from BLOB data.

**Parameters**:
- `p_font_name` - Unique font name identifier
- `p_font_blob` - TrueType font file as BLOB
- `p_encoding` - Character encoding (default `'UTF-8'`)
- `p_embed` - Embed font in PDF (default `TRUE`)

**Raises**:
- `-20211`: Invalid font BLOB

---

### `LoadTTFFromFile`

```sql
PROCEDURE LoadTTFFromFile(
  p_font_name VARCHAR2,
  p_file_path VARCHAR2,
  p_directory VARCHAR2 DEFAULT 'FONTS_DIR',
  p_encoding VARCHAR2 DEFAULT 'UTF-8'
);
```

**Description**: Loads a TrueType font from filesystem.

**Parameters**:
- `p_font_name` - Unique font name identifier
- `p_file_path` - Font filename
- `p_directory` - Oracle directory object (default `'FONTS_DIR'`)
- `p_encoding` - Character encoding (default `'UTF-8'`)

**Raises**:
- `-20202`: Invalid font file
- `-20401`: Invalid directory

---

### `IsTTFFontLoaded`

```sql
FUNCTION IsTTFFontLoaded(p_font_name VARCHAR2) RETURN BOOLEAN;
```

**Description**: Checks if a TrueType font is loaded.

**Parameters**:
- `p_font_name` - Font name to check

**Returns**: `TRUE` if font is loaded, `FALSE` otherwise

---

### `ClearTTFFontCache`

```sql
PROCEDURE ClearTTFFontCache;
```

**Description**: Clears all loaded TrueType fonts from memory.

---

## Text Rendering

### `Cell`

```sql
PROCEDURE Cell(
  pw NUMBER,
  ph NUMBER DEFAULT 0,
  ptxt VARCHAR2 DEFAULT '',
  pborder VARCHAR2 DEFAULT '0',
  pln NUMBER DEFAULT 0,
  palign VARCHAR2 DEFAULT '',
  pfill NUMBER DEFAULT 0,
  plink VARCHAR2 DEFAULT ''
);
```

**Description**: Outputs a cell (rectangular area) with optional borders, background color, and hyperlink.

**Parameters**:
- `pw` - Cell width (0 = extend to right margin)
- `ph` - Cell height
- `ptxt` - Text content
- `pborder` - Border: `'0'` (none), `'1'` (frame), or combination of `'L'`,`'T'`,`'R'`,`'B'`
- `pln` - Line break: `0` (to the right), `1` (below), `2` (below)
- `palign` - Alignment: `'L'` (left), `'C'` (center), `'R'` (right)
- `pfill` - Fill: `0` (transparent), `1` (filled with current fill color)
- `plink` - URL or internal link identifier

**Example**:
```sql
PL_FPDF.Cell(100, 10, 'Hello World', '1', 1, 'C', 0);
```

---

### `CellRotated`

```sql
PROCEDURE CellRotated(
  p_width NUMBER,
  p_height NUMBER DEFAULT 0,
  p_text VARCHAR2 DEFAULT '',
  p_border VARCHAR2 DEFAULT '0',
  p_ln NUMBER DEFAULT 0,
  p_align VARCHAR2 DEFAULT '',
  p_fill NUMBER DEFAULT 0,
  p_link VARCHAR2 DEFAULT '',
  p_rotation PLS_INTEGER DEFAULT 0
);
```

**Description**: Modern Cell with text rotation support.

**Parameters**: Same as `Cell` plus:
- `p_rotation` - Text rotation: `0`, `90`, `180`, `270` degrees

**Raises**:
- `-20110`: Invalid rotation value

**Example**:
```sql
PL_FPDF.CellRotated(100, 10, 'Rotated Text', '1', 1, 'C', 0, '', 90);
```

---

### `MultiCell`

```sql
FUNCTION MultiCell(
  pw NUMBER,
  ph NUMBER DEFAULT 0,
  ptxt VARCHAR2,
  pborder VARCHAR2 DEFAULT '0',
  palign VARCHAR2 DEFAULT 'J',
  pfill NUMBER DEFAULT 0,
  phMax NUMBER DEFAULT 0
) RETURN NUMBER;
```

**Description**: Outputs a multi-line cell with automatic line breaks.

**Parameters**:
- `pw` - Cell width
- `ph` - Line height
- `ptxt` - Text content (will be wrapped automatically)
- `pborder` - Border: `'0'` (none), `'1'` (frame), or combination of `'L'`,`'T'`,`'R'`,`'B'`
- `palign` - Alignment: `'L'` (left), `'C'` (center), `'R'` (right), `'J'` (justified)
- `pfill` - Fill: `0` (transparent), `1` (filled)
- `phMax` - Maximum height (0 = unlimited)

**Returns**: Number of lines created

**Example**:
```sql
l_lines := PL_FPDF.MultiCell(180, 5, 'Long text that will wrap...', '1', 'J', 0);
```

---

### `Write`

```sql
PROCEDURE Write(
  pH VARCHAR2,
  ptxt VARCHAR2,
  plink VARCHAR2 DEFAULT NULL
);
```

**Description**: Outputs text in flowing mode (line breaks at right margin).

**Parameters**:
- `pH` - Line height
- `ptxt` - Text content
- `plink` - URL or internal link identifier

**Example**:
```sql
PL_FPDF.Write(5, 'This is flowing text.');
```

---

### `WriteRotated`

```sql
PROCEDURE WriteRotated(
  p_height NUMBER,
  p_text VARCHAR2,
  p_link VARCHAR2 DEFAULT NULL,
  p_rotation PLS_INTEGER DEFAULT 0
);
```

**Description**: Modern Write with text rotation support.

**Parameters**: Same as `Write` plus:
- `p_rotation` - Text rotation: `0`, `90`, `180`, `270` degrees

**Raises**:
- `-20110`: Invalid rotation value

---

### `Text`

```sql
PROCEDURE Text(
  px NUMBER,
  py NUMBER,
  ptxt VARCHAR2
);
```

**Description**: Outputs text at absolute position (no automatic positioning).

**Parameters**:
- `px` - X coordinate
- `py` - Y coordinate
- `ptxt` - Text content

**Example**:
```sql
PL_FPDF.Text(50, 100, 'Positioned text');
```

---

### `UTF8ToPDFString`

```sql
FUNCTION UTF8ToPDFString(
  p_text VARCHAR2,
  p_escape BOOLEAN DEFAULT TRUE
) RETURN VARCHAR2;
```

**Description**: Converts UTF-8 encoded text to PDF-compatible string format.

**Parameters**:
- `p_text` - UTF-8 text to convert
- `p_escape` - Whether to escape PDF special characters (default `TRUE`)

**Returns**: PDF-compatible string

---

## Graphics & Drawing

### `SetDrawColor`

```sql
PROCEDURE SetDrawColor(
  r NUMBER,
  g NUMBER DEFAULT -1,
  b NUMBER DEFAULT -1
);
```

**Description**: Sets the drawing color for lines and borders.

**Parameters**:
- `r` - Red component (0-255) or grayscale (if g,b = -1)
- `g` - Green component (0-255) or -1 for grayscale
- `b` - Blue component (0-255) or -1 for grayscale

**Examples**:
```sql
PL_FPDF.SetDrawColor(255, 0, 0);    -- Red
PL_FPDF.SetDrawColor(128);          -- 50% gray
```

---

### `SetFillColor`

```sql
PROCEDURE SetFillColor(
  r NUMBER,
  g NUMBER DEFAULT -1,
  b NUMBER DEFAULT -1
);
```

**Description**: Sets the fill color for cells and shapes.

**Parameters**: Same as `SetDrawColor`

---

### `SetTextColor`

```sql
PROCEDURE SetTextColor(
  r NUMBER,
  g NUMBER DEFAULT -1,
  b NUMBER DEFAULT -1
);
```

**Description**: Sets the text color.

**Parameters**: Same as `SetDrawColor`

---

### `SetLineWidth`

```sql
PROCEDURE SetLineWidth(width NUMBER);
```

**Description**: Sets the line width for drawing operations.

**Parameters**:
- `width` - Line width in current unit

**Example**:
```sql
PL_FPDF.SetLineWidth(0.5);
```

---

### `Line`

```sql
PROCEDURE Line(
  x1 NUMBER,
  y1 NUMBER,
  x2 NUMBER,
  y2 NUMBER
);
```

**Description**: Draws a line from (x1,y1) to (x2,y2).

**Parameters**:
- `x1`, `y1` - Starting point coordinates
- `x2`, `y2` - Ending point coordinates

**Example**:
```sql
PL_FPDF.Line(10, 10, 100, 10);  -- Horizontal line
```

---

### `Rect`

```sql
PROCEDURE Rect(
  px NUMBER,
  py NUMBER,
  pw NUMBER,
  ph NUMBER,
  pstyle VARCHAR2 DEFAULT ''
);
```

**Description**: Draws a rectangle.

**Parameters**:
- `px` - X coordinate of top-left corner
- `py` - Y coordinate of top-left corner
- `pw` - Width
- `ph` - Height
- `pstyle` - Drawing style: `''` (draw), `'F'` (fill), `'DF'` or `'FD'` (draw and fill)

**Example**:
```sql
PL_FPDF.Rect(10, 10, 50, 30, 'DF');  -- Draw and fill
```

---

### `Poly`

```sql
PROCEDURE Poly(
  points tab_points,
  pclose BOOLEAN,
  pstyle VARCHAR2 DEFAULT ''
);
```

**Description**: Draws a polygon using a table of points.

**Parameters**:
- `points` - Table of points (see `tab_points` type)
- `pclose` - Close the polygon (connect last point to first)
- `pstyle` - Drawing style: `''` (draw), `'F'` (fill), `'DF'` or `'FD'` (draw and fill)

**Example**:
```sql
DECLARE
  l_points PL_FPDF.tab_points;
BEGIN
  l_points(1).x := 10; l_points(1).y := 10;
  l_points(2).x := 50; l_points(2).y := 10;
  l_points(3).x := 30; l_points(3).y := 40;
  PL_FPDF.Poly(l_points, TRUE, 'DF');
END;
```

---

### `Triangle`

```sql
PROCEDURE Triangle(
  px NUMBER,
  py NUMBER,
  psize NUMBER,
  porientation VARCHAR2 DEFAULT 'left',
  pstyle VARCHAR2 DEFAULT ''
);
```

**Description**: Draws a triangle.

**Parameters**:
- `px`, `py` - Base point coordinates
- `psize` - Triangle size
- `porientation` - Orientation: `'left'`, `'right'`, `'up'`, `'down'`
- `pstyle` - Drawing style: `''` (draw), `'F'` (fill), `'DF'` or `'FD'` (draw and fill)

---

### `SetDash`

```sql
PROCEDURE SetDash(
  pblack NUMBER DEFAULT 0,
  pwhite NUMBER DEFAULT 0
);
```

**Description**: Sets the line dash pattern.

**Parameters**:
- `pblack` - Length of black dashes (0 = solid line)
- `pwhite` - Length of white gaps

**Example**:
```sql
PL_FPDF.SetDash(3, 3);  -- Dashed line
PL_FPDF.SetDash(0, 0);  -- Solid line
```

---

## Image Handling

### `image`

```sql
PROCEDURE image(
  pFile VARCHAR2,
  pX NUMBER,
  pY NUMBER,
  pWidth NUMBER DEFAULT 0,
  pHeight NUMBER DEFAULT 0,
  pType VARCHAR2 DEFAULT NULL,
  pLink VARCHAR2 DEFAULT NULL
);
```

**Description**: Embeds an image in the PDF.

**Parameters**:
- `pFile` - Image filename or URL
- `pX` - X coordinate
- `pY` - Y coordinate
- `pWidth` - Width (0 = auto based on height or natural size)
- `pHeight` - Height (0 = auto based on width or natural size)
- `pType` - Image type: `'PNG'`, `'JPEG'`, `'JPG'` (auto-detected if NULL)
- `pLink` - URL or internal link identifier

**Supported Formats**: PNG, JPEG

**Example**:
```sql
PL_FPDF.image('logo.png', 10, 10, 50, 0);  -- Width 50, auto height
```

---

### `getImageFromUrl`

```sql
FUNCTION getImageFromUrl(p_Url VARCHAR2) RETURN recImageBlob;
```

**Description**: Fetches an image from a URL and returns it as a native BLOB with parsed metadata.

**Parameters**:
- `p_Url` - Image URL (http/https)

**Returns**: `recImageBlob` with image data and metadata

**Raises**:
- `-20220`: Unsupported image format
- `-20221`: Invalid image header
- `-20222`: Unable to fetch image from URL

**Example**:
```sql
l_img := PL_FPDF.getImageFromUrl('http://example.com/image.png');
```

---

## Output Methods

### `OutputBlob`

```sql
FUNCTION OutputBlob RETURN BLOB;
```

**Description**: Generates and returns the PDF as a BLOB (modern method, no OWA dependencies).

**Returns**: PDF document as BLOB

**Example**:
```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init();
  PL_FPDF.AddPage();
  PL_FPDF.Cell(0, 10, 'Hello');
  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
```

---

### `OutputFile`

```sql
PROCEDURE OutputFile(
  p_filename VARCHAR2,
  p_directory VARCHAR2 DEFAULT 'PDF_DIR'
);
```

**Description**: Saves the PDF to a file in an Oracle directory.

**Parameters**:
- `p_filename` - Output filename
- `p_directory` - Oracle directory object (default `'PDF_DIR'`)

**Raises**:
- `-20401`: Invalid directory
- `-20403`: File write error

**Example**:
```sql
PL_FPDF.OutputFile('report.pdf', 'MY_DIR');
```

---

### `Output` (Legacy)

```sql
PROCEDURE Output(
  pname VARCHAR2 DEFAULT NULL,
  pdest VARCHAR2 DEFAULT NULL
);
```

**Description**: Legacy output method (for backward compatibility).

**Parameters**:
- `pname` - Filename
- `pdest` - Destination: `'D'` (download), `'F'` (file), `'S'` (string)

---

### `ReturnBlob` (Legacy)

```sql
FUNCTION ReturnBlob(
  pname VARCHAR2 DEFAULT NULL,
  pdest VARCHAR2 DEFAULT NULL
) RETURN BLOB;
```

**Description**: Legacy BLOB output method (use `OutputBlob` instead).

---

## Configuration & Metadata

### `SetDocumentConfig`

```sql
PROCEDURE SetDocumentConfig(p_config JSON_OBJECT_T);
```

**Description**: Configure PDF document using JSON for modern integration.

**Parameters**:
- `p_config` - JSON object containing configuration options

**Supported JSON keys**:
- `title`, `author`, `subject`, `keywords`, `creator` (document metadata)
- `orientation` (`'P'` or `'L'`), `unit`, `format` (page settings)
- `fontFamily`, `fontSize`, `fontStyle` (default font)
- `leftMargin`, `topMargin`, `rightMargin` (margins)

**Example**:
```sql
DECLARE
  l_config JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_config.put('title', 'Monthly Report');
  l_config.put('author', 'John Doe');
  l_config.put('orientation', 'P');
  l_config.put('format', 'A4');
  PL_FPDF.SetDocumentConfig(l_config);
END;
```

---

### `GetDocumentMetadata`

```sql
FUNCTION GetDocumentMetadata RETURN JSON_OBJECT_T;
```

**Description**: Returns document metadata and statistics as JSON.

**Returns**: JSON object with document information

**JSON structure**:
```json
{
  "pageCount": 10,
  "title": "Report",
  "author": "John Doe",
  "subject": "Monthly Report",
  "keywords": "finance, report",
  "format": "A4",
  "orientation": "P",
  "unit": "mm",
  "initialized": true
}
```

**Example**:
```sql
DECLARE
  l_meta JSON_OBJECT_T;
BEGIN
  l_meta := PL_FPDF.GetDocumentMetadata();
  DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
END;
```

---

### `GetPageInfo`

```sql
FUNCTION GetPageInfo(p_page_number PLS_INTEGER DEFAULT NULL) RETURN JSON_OBJECT_T;
```

**Description**: Returns information about a specific page as JSON.

**Parameters**:
- `p_page_number` - Page number (NULL = current page)

**Returns**: JSON object with page information

**JSON structure**:
```json
{
  "number": 1,
  "format": "A4",
  "orientation": "P",
  "width": 210,
  "height": 297,
  "unit": "mm"
}
```

---

### `SetTitle`

```sql
PROCEDURE SetTitle(ptitle VARCHAR2);
```

**Description**: Sets the document title (metadata).

---

### `SetAuthor`

```sql
PROCEDURE SetAuthor(pauthor VARCHAR2);
```

**Description**: Sets the document author (metadata).

---

### `SetSubject`

```sql
PROCEDURE SetSubject(psubject VARCHAR2);
```

**Description**: Sets the document subject (metadata).

---

### `SetKeywords`

```sql
PROCEDURE SetKeywords(pkeywords VARCHAR2);
```

**Description**: Sets the document keywords (metadata).

---

### `SetCreator`

```sql
PROCEDURE SetCreator(pcreator VARCHAR2);
```

**Description**: Sets the document creator (metadata).

---

### `SetMargins`

```sql
PROCEDURE SetMargins(
  left NUMBER,
  top NUMBER,
  right NUMBER DEFAULT -1
);
```

**Description**: Sets page margins.

**Parameters**:
- `left` - Left margin
- `top` - Top margin
- `right` - Right margin (-1 = same as left)

**Example**:
```sql
PL_FPDF.SetMargins(10, 10, 10);
```

---

### `SetAutoPageBreak`

```sql
PROCEDURE SetAutoPageBreak(
  pauto BOOLEAN,
  pMargin NUMBER DEFAULT 0
);
```

**Description**: Enables or disables automatic page breaks.

**Parameters**:
- `pauto` - Enable automatic page breaks
- `pMargin` - Bottom margin (distance from bottom to trigger page break)

**Example**:
```sql
PL_FPDF.SetAutoPageBreak(TRUE, 15);
```

---

### `SetCompression`

```sql
PROCEDURE SetCompression(p_compress BOOLEAN DEFAULT FALSE);
```

**Description**: Enables or disables content compression (reduces file size).

**Parameters**:
- `p_compress` - Enable compression

**Example**:
```sql
PL_FPDF.SetCompression(TRUE);
```

---

## Utility Functions

### `GetX` / `GetY`

```sql
FUNCTION GetX RETURN NUMBER;
FUNCTION GetY RETURN NUMBER;
```

**Description**: Returns the current X or Y position.

**Returns**: Current position in current unit

---

### `SetX` / `SetY`

```sql
PROCEDURE SetX(px NUMBER);
PROCEDURE SetY(py NUMBER);
```

**Description**: Sets the current X or Y position.

**Parameters**:
- `px` - New X position
- `py` - New Y position

---

### `SetXY`

```sql
PROCEDURE SetXY(x NUMBER, y NUMBER);
```

**Description**: Sets both X and Y positions.

**Parameters**:
- `x` - New X position
- `y` - New Y position

---

### `Ln`

```sql
PROCEDURE Ln(h NUMBER DEFAULT NULL);
```

**Description**: Performs a line break.

**Parameters**:
- `h` - Line height (NULL = current cell height)

**Example**:
```sql
PL_FPDF.Ln(10);  -- Line break with 10mm height
```

---

### `SetLogLevel`

```sql
PROCEDURE SetLogLevel(p_level PLS_INTEGER);
```

**Description**: Sets the logging level for debugging.

**Parameters**:
- `p_level` - Log level: `0` (OFF), `1` (ERROR), `2` (WARN), `3` (INFO), `4` (DEBUG)

**Example**:
```sql
PL_FPDF.SetLogLevel(0);  -- Disable logging in production
```

---

### `GetLogLevel`

```sql
FUNCTION GetLogLevel RETURN PLS_INTEGER DETERMINISTIC;
```

**Description**: Returns the current logging level.

**Returns**: Current log level (0-4)

---

### `AddLink`

```sql
FUNCTION AddLink RETURN NUMBER;
```

**Description**: Creates a new internal link identifier.

**Returns**: Link identifier

---

### `SetLink`

```sql
PROCEDURE SetLink(
  plink NUMBER,
  py NUMBER DEFAULT 0,
  ppage NUMBER DEFAULT -1
);
```

**Description**: Defines the target of an internal link.

**Parameters**:
- `plink` - Link identifier (from `AddLink`)
- `py` - Y position on target page
- `ppage` - Target page number (-1 = current page)

---

### `Link`

```sql
PROCEDURE Link(
  px NUMBER,
  py NUMBER,
  pw NUMBER,
  ph NUMBER,
  plink VARCHAR2
);
```

**Description**: Creates a clickable area.

**Parameters**:
- `px`, `py` - Top-left corner coordinates
- `pw`, `ph` - Width and height
- `plink` - URL or internal link identifier

---

## Custom Exceptions

| Exception | Error Code | Description |
|-----------|------------|-------------|
| `exc_invalid_orientation` | -20001 | Invalid orientation parameter |
| `exc_invalid_unit` | -20002 | Invalid measurement unit |
| `exc_invalid_encoding` | -20003 | Unsupported encoding |
| `exc_not_initialized` | -20005 | PDF not initialized |
| `exc_invalid_page_format` | -20101 | Invalid page format |
| `exc_page_not_found` | -20106 | Page does not exist |
| `exc_font_not_found` | -20201 | Font not found |
| `exc_invalid_font_file` | -20202 | Invalid font file |
| `exc_invalid_font_name` | -20210 | Invalid font name |
| `exc_invalid_font_blob` | -20211 | Invalid font BLOB |
| `exc_invalid_image` | -20301 | Invalid image |
| `exc_image_not_found` | -20302 | Image not found |
| `exc_unsupported_image_format` | -20303 | Unsupported image format |
| `exc_invalid_directory` | -20401 | Invalid directory |
| `exc_file_access_denied` | -20402 | File access denied |
| `exc_file_write_error` | -20403 | File write error |
| `exc_invalid_color` | -20501 | Invalid color |
| `exc_invalid_line_width` | -20502 | Invalid line width |
| `exc_general_error` | -20100 | General error |

---

## Type Definitions

### `recImageBlob`

```sql
TYPE recImageBlob IS RECORD (
  image_blob BLOB,
  mime_type VARCHAR2(100),
  file_format VARCHAR2(20),
  width INTEGER,
  height INTEGER,
  bit_depth INTEGER,
  color_type INTEGER,
  has_transparency BOOLEAN
);
```

**Description**: Native BLOB-based image container with metadata.

---

### `recPageFormat`

```sql
TYPE recPageFormat IS RECORD (
  width NUMBER(10,5),
  height NUMBER(10,5)
);
```

**Description**: Page dimensions (width × height).

---

### `point`

```sql
TYPE point IS RECORD (
  x NUMBER,
  y NUMBER
);
```

**Description**: Point type for polygon creation.

---

### `tab_points`

```sql
TYPE tab_points IS TABLE OF point INDEX BY PLS_INTEGER;
```

**Description**: Collection of points for polygons.

---

## Version Information

```sql
FPDF_VERSION CONSTANT VARCHAR2(10) := '1.53';
PL_FPDF_VERSION CONSTANT VARCHAR2(10) := '0.9.4';
```

---

**Last Updated**: December 19, 2025
**Version**: 2.0.0
**Status**: Production Ready ✅
