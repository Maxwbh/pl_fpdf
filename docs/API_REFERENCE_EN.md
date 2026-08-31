# PL_FPDF — API Reference

**Version:** 3.3.0 | **Oracle:** 19c+ | **License:** MIT

Detailed documentation of every public function and procedure of the `PL_FPDF` package:
syntax, parameters with accepted values, return, errors raised and an example.

> Task-oriented guide: [DOCUMENTATION_EN.md](DOCUMENTATION_EN.md) ·
> Browsable version: [maxwbh.github.io/pl_fpdf/en/reference.html](https://maxwbh.github.io/pl_fpdf/en/reference.html) ·
> Referência da API (português): [API_REFERENCE.md](API_REFERENCE.md)

## Index

**Lifecycle** — [fpdf](#fpdf) · [Init](#init) · [IsInitialized](#isinitialized) · [Reset](#reset)
**Pages and positioning** — [AcceptPageBreak](#acceptpagebreak) · [AddPage](#addpage) · [GetCurrentPage](#getcurrentpage) · [GetX](#getx) · [GetY](#gety) · [Ln](#ln) · [PageNo](#pageno) · [SetAutoPageBreak](#setautopagebreak) · [SetLeftMargin](#setleftmargin) · [SetMargins](#setmargins) · [SetPage](#setpage) · [SetRightMargin](#setrightmargin) · [SetTopMargin](#settopmargin) · [SetX](#setx) · [SetXY](#setxy) · [SetY](#sety)
**Fonts and UTF-8** — [AddFont](#addfont) · [AddTTFFont](#addttffont) · [ClearTTFFontCache](#clearttffontcache) · [GetTTFFontInfo](#getttffontinfo) · [IsTTFFontLoaded](#isttffontloaded) · [IsUTF8Enabled](#isutf8enabled) · [LoadTTFFromFile](#loadttffromfile) · [SetFont](#setfont) · [SetFontSize](#setfontsize) · [SetUTF8Enabled](#setutf8enabled) · [UTF8ToPDFString](#utf8topdfstring)
**Writing text** — [Cell](#cell) · [CellRotated](#cellrotated) · [GetCurrentFontFamily](#getcurrentfontfamily) · [GetCurrentFontSize](#getcurrentfontsize) · [GetCurrentFontStyle](#getcurrentfontstyle) · [GetLineSpacing](#getlinespacing) · [GetStringWidth](#getstringwidth) · [MultiCell](#multicell) · [SetLineSpacing](#setlinespacing) · [Text](#text) · [Write](#write) · [WriteRotated](#writerotated)
**Colours and drawing** — [Line](#line) · [Poly](#poly) · [Rect](#rect) · [SetDash](#setdash) · [SetDrawColor](#setdrawcolor) · [SetFillColor](#setfillcolor) · [SetLineDashPattern](#setlinedashpattern) · [SetLineWidth](#setlinewidth) · [SetTextColor](#settextcolor) · [Triangle](#triangle)
**Images** — [getImageFromUrl](#getimagefromurl) · [image](#image)
**Links** — [AddLink](#addlink) · [Link](#link) · [SetLink](#setlink)
**Header and footer** — [Footer](#footer) · [Header](#header) · [SetAliasNbPages](#setaliasnbpages) · [SetFooterProc](#setfooterproc) · [SetHeaderProc](#setheaderproc)
**QR codes and barcodes** — [AddBarcode](#addbarcode) · [AddQRCode](#addqrcode)
**Metadata and document setup** — [GetDocumentMetadata](#getdocumentmetadata) · [GetPageInfo](#getpageinfo) · [SetAuthor](#setauthor) · [SetCompression](#setcompression) · [SetCreator](#setcreator) · [SetDisplayMode](#setdisplaymode) · [SetDocumentConfig](#setdocumentconfig) · [SetKeywords](#setkeywords) · [SetSubject](#setsubject) · [SetTitle](#settitle)
**Document output** — [ClosePDF](#closepdf) · [OpenPDF](#openpdf) · [Output](#output) · [OutputBlob](#outputblob) · [OutputFile](#outputfile) · [ReturnBlob](#returnblob)
**Manipulating an existing PDF** — [AddWatermark](#addwatermark) · [ClearPDFCache](#clearpdfcache) · [FlateDecode](#flatedecode) · [FlateEncode](#flateencode) · [GetActivePageCount](#getactivepagecount) · [GetPageCount](#getpagecount) · [GetPDFInfo](#getpdfinfo) · [GetWatermarks](#getwatermarks) · [IsPageRemoved](#ispageremoved) · [IsPDFModified](#ispdfmodified) · [LoadPDF](#loadpdf) · [OutputModifiedPDF](#outputmodifiedpdf) · [RemovePage](#removepage) · [RotatePage](#rotatepage)
**Overlays** — [ClearOverlays](#clearoverlays) · [GetOverlays](#getoverlays) · [OverlayImage](#overlayimage) · [OverlayText](#overlaytext) · [RemoveOverlay](#removeoverlay)
**Multi-PDF (merge, split, extract)** — [ExtractPages](#extractpages) · [GetLoadedPDFs](#getloadedpdfs) · [LoadPDFWithID](#loadpdfwithid) · [MergePDFs](#mergepdfs) · [SplitPDF](#splitpdf) · [UnloadPDF](#unloadpdf)
**Security and encryption** — [DecryptPDF](#decryptpdf) · [EncryptPDF](#encryptpdf) · [GetPDFVersion](#getpdfversion) · [GetSecurityInfo](#getsecurityinfo) · [IsEncrypted](#isencrypted) · [SetEncryption](#setencryption) · [SetPDFVersion](#setpdfversion) · [SetPermissions](#setpermissions)
**Diagnostics and utilities** — [DebugDisabled](#debugdisabled) · [DebugEnabled](#debugenabled) · [Error](#error) · [GetLogLevel](#getloglevel) · [GetScaleFactor](#getscalefactor) · [SetLogLevel](#setloglevel)

---

## Lifecycle

### fpdf

Initialises the document in the classic FPDF style. Kept for compatibility with v0.9.4; use Init in new code.

#### Syntax

```sql
PROCEDURE PL_FPDF.fpdf(
    orientation varchar2 DEFAULT 'P',
    unit        varchar2 DEFAULT 'mm',
    format      varchar2 DEFAULT 'A4');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `orientation` | VARCHAR2 | Orientation. | 'P' (default) or 'L' | `'P'` |
| `unit` | VARCHAR2 | Unit of measurement. | 'mm' (default), 'cm', 'pt' or 'in' | `'mm'` |
| `format` | VARCHAR2 | Page format. | 'A3', 'A4' (default), 'A5', 'Letter' or 'Legal' | `'A4'` |

**See also:** [Init](#init)

---

### Init

Initialises a new PDF document. This must be the first call of any generation; it sets the orientation, unit of measurement, page format and encoding used by every other API.

#### Syntax

```sql
PROCEDURE PL_FPDF.Init(
    p_orientation varchar2 DEFAULT 'P',
    p_unit        varchar2 DEFAULT 'mm',
    p_format      varchar2 DEFAULT 'A4',
    p_encoding    varchar2 DEFAULT 'UTF-8');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_orientation` | VARCHAR2 | Default page orientation. | 'P' (portrait, the default) or 'L' (landscape) | `'P'` |
| `p_unit` | VARCHAR2 | Unit of measurement for every coordinate and dimension in the document. | 'mm' (default), 'cm', 'pt' or 'in' | `'mm'` |
| `p_format` | VARCHAR2 | Default page format. | 'A3', 'A4' (default), 'A5', 'Letter' or 'Legal' | `'A4'` |
| `p_encoding` | VARCHAR2 | Character encoding of the text. | 'UTF-8' (default) or 'WINDOWS-1252' | `'UTF-8'` |

#### Example

```sql
BEGIN
  PL_FPDF.Init(p_orientation => 'P', p_unit => 'mm', p_format => 'A4');
  PL_FPDF.AddPage();
  -- ...
END;
```

**See also:** [Reset](#reset), [IsInitialized](#isinitialized), [AddPage](#addpage)

---

### IsInitialized

Tells whether a document is currently being built in this session.

#### Syntax

```sql
FUNCTION PL_FPDF.IsInitialized
    RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if Init has been called and the document has not been finalised.

#### Example

```sql
IF NOT PL_FPDF.IsInitialized THEN
  PL_FPDF.Init;
END IF;
```

**See also:** [Init](#init)

---

### Reset

Returns the PDF engine to its initial state, freeing temporary CLOBs and clearing every internal array. Use it between documents generated in the same job, or at the end of long routines.

#### Syntax

```sql
PROCEDURE PL_FPDF.Reset;
```

#### Example

```sql
PL_FPDF.Reset;
```

**See also:** [Init](#init), [ClearPDFCache](#clearpdfcache)

---

## Pages and positioning

### AcceptPageBreak

Reports whether an automatic page break should happen at the current point. The engine calls it internally; you can read it for your own pagination logic.

#### Syntax

```sql
FUNCTION PL_FPDF.AcceptPageBreak
    RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if the automatic page break is enabled.

**See also:** [SetAutoPageBreak](#setautopagebreak)

---

### AddPage

Adds a new page to the document and makes it the current one. NULL parameters inherit the values set in Init, which lets you mix orientations and formats within the same PDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddPage(
    p_orientation varchar2 DEFAULT null,
    p_format      varchar2 DEFAULT null,
    p_rotation    pls_integer DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_orientation` | VARCHAR2 | Orientation for this page only. | 'P', 'L' or NULL (inherits from Init) | `null` |
| `p_format` | VARCHAR2 | Page format for this page only. | 'A3', 'A4', 'A5', 'Letter', 'Legal' or NULL (inherits from Init) | `null` |
| `p_rotation` | PLS_INTEGER | Display rotation applied by the PDF reader. | 0 (default), 90, 180 or 270 | `0` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20005` | Document not initialised (call Init first) |
| `-20107` | Invalid orientation (only 'P' or 'L') |
| `-20103` | Unknown page format |
| `-20101` | Invalid dimensions for the custom format |
| `-20104` | Invalid rotation (only 0, 90, 180 or 270) |

#### Example

```sql
PL_FPDF.AddPage;                                      -- inherits everything from Init
PL_FPDF.AddPage(p_orientation => 'L');                -- this one in landscape
PL_FPDF.AddPage(p_format => 'A5', p_rotation => 90);  -- A5, rotated
```

**See also:** [Init](#init), [SetPage](#setpage), [GetCurrentPage](#getcurrentpage)

---

### GetCurrentPage

Returns the number of the current page — the one receiving content.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentPage
    RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — number of the active page.

**See also:** [SetPage](#setpage), [PageNo](#pageno)

---

### GetX

Returns the current X position of the cursor.

#### Syntax

```sql
FUNCTION PL_FPDF.GetX
    RETURN NUMBER;
```

#### Returns

NUMBER — X coordinate.

**See also:** [SetX](#setx), [SetXY](#setxy)

---

### GetY

Returns the current Y position of the cursor.

#### Syntax

```sql
FUNCTION PL_FPDF.GetY
    RETURN NUMBER;
```

#### Returns

NUMBER — Y coordinate.

**See also:** [SetY](#sety)

---

### Ln

Moves the cursor to the next line, back at the left margin.

#### Syntax

```sql
PROCEDURE PL_FPDF.Ln(
    h number DEFAULT null);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `h` | NUMBER | Height of the jump. | Number in the unit set by Init (mm, cm, pt or in); NULL (default) uses the height of the last cell written | `null` |

#### Example

```sql
PL_FPDF.Ln(6);
```

**See also:** [SetXY](#setxy)

---

### PageNo

Returns the current page number during generation; typically used in footers.

#### Syntax

```sql
FUNCTION PL_FPDF.PageNo
    RETURN NUMBER;
```

#### Returns

NUMBER — number of the current page.

#### Example

```sql
PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
```

**See also:** [SetAliasNbPages](#setaliasnbpages), [SetFooterProc](#setfooterproc)

---

### SetAutoPageBreak

Turns the automatic page break on or off and sets how far from the bottom edge it happens.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetAutoPageBreak(
    pauto   boolean,
    pMargin number DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pauto` | BOOLEAN | Enables the automatic page break. | TRUE or FALSE | — |
| `pMargin` | NUMBER | Bottom margin that triggers the break. | Number in the unit set by Init (mm, cm, pt or in); 0 is the default | `0` |

#### Example

```sql
PL_FPDF.SetAutoPageBreak(pauto => TRUE, pMargin => 15);
```

**See also:** [AcceptPageBreak](#acceptpagebreak), [SetMargins](#setmargins)

---

### SetLeftMargin

Sets the left margin only.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLeftMargin(
    pMargin number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pMargin` | NUMBER | Left margin. | Number in the unit set by Init (mm, cm, pt or in) | — |

**See also:** [SetMargins](#setmargins)

---

### SetMargins

Sets the left, top and right margins of the document. The bottom margin is controlled by SetAutoPageBreak.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetMargins(
    left  number,
    top   number,
    right number DEFAULT -1);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `left` | NUMBER | Left margin. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `top` | NUMBER | Top margin. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `right` | NUMBER | Right margin. | Number in the unit set by Init (mm, cm, pt or in); -1 (default) reuses the left margin value | `-1` |

#### Example

```sql
PL_FPDF.SetMargins(left => 20, top => 15, right => 20);
```

**See also:** [SetLeftMargin](#setleftmargin), [SetTopMargin](#settopmargin), [SetRightMargin](#setrightmargin), [SetAutoPageBreak](#setautopagebreak)

---

### SetPage

Chooses which existing page receives the content of the next calls, so you can go back to an earlier page — to fill in a table of contents once the final page numbers are known, for instance.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetPage(
    p_page_number pls_integer);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page that becomes the current one. | Integer >= 1, up to GetPageCount | — |

#### Errors

| Code | Condition |
|--------|----------|
| `-20005` | Document not initialised (call Init first) |
| `-20106` | The given page does not exist |

#### Example

```sql
PL_FPDF.SetPage(1);
PL_FPDF.SetXY(20, 40);
PL_FPDF.Cell(0, 8, 'Filled in afterwards');
```

**See also:** [AddPage](#addpage), [GetCurrentPage](#getcurrentpage)

---

### SetRightMargin

Sets the right margin only.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetRightMargin(
    pMargin number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pMargin` | NUMBER | Right margin. | Number in the unit set by Init (mm, cm, pt or in) | — |

**See also:** [SetMargins](#setmargins)

---

### SetTopMargin

Sets the top margin only.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetTopMargin(
    pMargin number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pMargin` | NUMBER | Top margin. | Number in the unit set by Init (mm, cm, pt or in) | — |

**See also:** [SetMargins](#setmargins)

---

### SetX

Sets the X position of the cursor.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetX(
    px number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | New X coordinate. | Number in the unit set by Init (mm, cm, pt or in); negative values count from the right edge | — |

**See also:** [GetX](#getx)

---

### SetXY

Sets both X and Y of the cursor in a single call.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetXY(
    x number,
    y number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `x` | NUMBER | X coordinate. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `y` | NUMBER | Y coordinate. | Number in the unit set by Init (mm, cm, pt or in) | — |

#### Example

```sql
PL_FPDF.SetXY(x => 20, y => 40);
```

**See also:** [SetX](#setx), [SetY](#sety)

---

### SetY

Sets the Y position of the cursor, and moves X back to the left margin.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetY(
    py number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `py` | NUMBER | New Y coordinate. | Number in the unit set by Init (mm, cm, pt or in); negative values count from the bottom edge — e.g. -15 for a footer | — |

#### Example

```sql
PL_FPDF.SetY(-15);  -- 15 units above the end of the page
```

**See also:** [GetY](#gety), [SetXY](#setxy)

---

## Fonts and UTF-8

### AddFont

Registers an additional font (FPDF compatibility). For TrueType with UTF-8, prefer AddTTFFont.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddFont(
    family   varchar2,
    style    varchar2 DEFAULT '',
    filename varchar2 DEFAULT '');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `family` | VARCHAR2 | Family name to register. | Free text; used later in SetFont | — |
| `style` | VARCHAR2 | Style tied to the file. | '', 'B', 'I' or 'BI' | `''` |
| `filename` | VARCHAR2 | Font definition file. | File name; empty uses the standard FPDF convention | `''` |

**See also:** [AddTTFFont](#addttffont), [SetFont](#setfont)

---

### AddTTFFont

Loads a TrueType font from a BLOB — from an assets table, say — and makes it available to SetFont, with full UTF-8 support.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddTTFFont(
    p_font_name varchar2,
    p_font_blob blob,
    p_encoding  varchar2 DEFAULT 'UTF-8',
    p_embed     boolean DEFAULT true);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Name by which the font will be referenced in SetFont. | Free text, e.g. 'Roboto' | — |
| `p_font_blob` | BLOB | Binary content of the .ttf file. | Non-null BLOB holding a valid TrueType font | — |
| `p_encoding` | VARCHAR2 | Font encoding. | 'UTF-8' (default) or 'WINDOWS-1252' | `'UTF-8'` |
| `p_embed` | BOOLEAN | Embeds the font in the PDF, which guarantees the look in any reader and grows the file. | TRUE or FALSE; TRUE is the default | `true` |

#### Example

```sql
DECLARE
  l_ttf BLOB;
BEGIN
  SELECT file INTO l_ttf FROM fonts WHERE name = 'Roboto-Regular';
  PL_FPDF.AddTTFFont(p_font_name => 'Roboto', p_font_blob => l_ttf, p_embed => TRUE);
  PL_FPDF.SetFont('Roboto', '', 12);
END;
```

**See also:** [LoadTTFFromFile](#loadttffromfile), [IsTTFFontLoaded](#isttffontloaded), [SetFont](#setfont)

---

### ClearTTFFontCache

Discards every loaded TrueType font, freeing session memory.

#### Syntax

```sql
PROCEDURE PL_FPDF.ClearTTFFontCache;
```

**See also:** [AddTTFFont](#addttffont)

---

### GetTTFFontInfo

Returns the metadata of a loaded TrueType font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetTTFFontInfo(
    p_font_name varchar2)
    RETURN RECTTFFONT;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Font name. | The same one used when loading | — |

#### Returns

recTTFFont — record with the font's metrics and information.

**See also:** [AddTTFFont](#addttffont)

---

### IsTTFFontLoaded

Checks whether a TrueType font has already been loaded in this session.

#### Syntax

```sql
FUNCTION PL_FPDF.IsTTFFontLoaded(
    p_font_name varchar2)
    RETURN BOOLEAN;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Font name. | The same one used when loading | — |

#### Returns

BOOLEAN — TRUE if the font is in the cache.

**See also:** [AddTTFFont](#addttffont), [ClearTTFFontCache](#clearttffontcache)

---

### IsUTF8Enabled

Tells whether UTF-8 mode is active.

#### Syntax

```sql
FUNCTION PL_FPDF.IsUTF8Enabled
    RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if UTF-8 is enabled.

**See also:** [SetUTF8Enabled](#setutf8enabled)

---

### LoadTTFFromFile

Loads a TrueType font from a file inside an Oracle DIRECTORY.

#### Syntax

```sql
PROCEDURE PL_FPDF.LoadTTFFromFile(
    p_font_name varchar2,
    p_file_path varchar2,
    p_directory varchar2 DEFAULT 'FONTS_DIR',
    p_encoding  varchar2 DEFAULT 'UTF-8');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Name to use in SetFont. | Free text | — |
| `p_file_path` | VARCHAR2 | Name of the .ttf file inside the directory. | E.g. 'Roboto-Regular.ttf' | — |
| `p_directory` | VARCHAR2 | Oracle DIRECTORY with read permission. | Default: 'FONTS_DIR' | `'FONTS_DIR'` |
| `p_encoding` | VARCHAR2 | Font encoding. | 'UTF-8' (default) or 'WINDOWS-1252' | `'UTF-8'` |

#### Example

```sql
PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');
```

**See also:** [AddTTFFont](#addttffont)

---

### SetFont

Sets the font family, style and size used by the next text writes.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetFont(
    pfamily varchar2,
    pstyle  varchar2 DEFAULT '',
    psize   number DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pfamily` | VARCHAR2 | Font family. | 'Arial'/'Helvetica', 'Times', 'Courier', 'Symbol', 'ZapfDingbats' or the name of a TrueType font loaded with AddTTFFont/LoadTTFFromFile | — |
| `pstyle` | VARCHAR2 | Text style. | '' (regular), 'B' (bold), 'I' (italic), 'BI' (bold italic) or 'U' (underlined) | `''` |
| `psize` | NUMBER | Size in points. | Number > 0; 0 (default) keeps the current size | `0` |

#### Example

```sql
PL_FPDF.SetFont('Arial', 'B', 16);
```

**See also:** [SetFontSize](#setfontsize), [AddTTFFont](#addttffont), [GetStringWidth](#getstringwidth)

---

### SetFontSize

Changes only the size of the current font.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetFontSize(
    psize number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `psize` | NUMBER | Size in points. | Number > 0 | — |

**See also:** [SetFont](#setfont)

---

### SetUTF8Enabled

Turns UTF-8 handling of text on or off.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetUTF8Enabled(
    p_enabled boolean DEFAULT true);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_enabled` | BOOLEAN | Enables UTF-8. | TRUE or FALSE; TRUE is the default | `true` |

**See also:** [IsUTF8Enabled](#isutf8enabled), [UTF8ToPDFString](#utf8topdfstring)

---

### UTF8ToPDFString

Converts UTF-8 text to the PDF's internal representation. Called internally; useful when debugging accented characters.

#### Syntax

```sql
FUNCTION PL_FPDF.UTF8ToPDFString(
    p_text   varchar2,
    p_escape boolean DEFAULT true)
    RETURN VARCHAR2;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_text` | VARCHAR2 | Text to convert. | Any VARCHAR2 in UTF-8 | — |
| `p_escape` | BOOLEAN | Escapes the PDF special characters (parentheses and backslash). | TRUE or FALSE | `true` |

#### Returns

VARCHAR2 — the converted text.

**See also:** [SetUTF8Enabled](#setutf8enabled)

---

## Writing text

### Cell

Writes a rectangular block of text, with optional borders, alignment, fill and link. It is the API most used to build reports and tables.

#### Syntax

```sql
PROCEDURE PL_FPDF.Cell(
    pw      number,
    ph      number DEFAULT 0,
    ptxt    varchar2 DEFAULT '',
    pborder varchar2 DEFAULT '0',
    pln     number DEFAULT 0,
    palign  varchar2 DEFAULT '',
    pfill   number DEFAULT 0,
    plink   varchar2 DEFAULT '');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pw` | NUMBER | Cell width. | Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin | — |
| `ph` | NUMBER | Cell height. | Number in the unit set by Init (mm, cm, pt or in); 0 is the default | `0` |
| `ptxt` | VARCHAR2 | Text to write. | Any VARCHAR2; empty draws the cell alone | `''` |
| `pborder` | VARCHAR2 | Borders to draw. | '0' (none), '1' (full frame) or a combination of 'L', 'T', 'R', 'B' — e.g. 'LTB' | `'0'` |
| `pln` | NUMBER | Where the cursor goes afterwards. | 0 = to the right of the cell (default), 1 = start of the next line, 2 = below the cell | `0` |
| `palign` | VARCHAR2 | Text alignment. | 'L' (left), 'C' (centre), 'R' (right) or '' (default, left) | `''` |
| `pfill` | NUMBER | Fills the background with the SetFillColor colour. | 0 = transparent (default), 1 = filled | `0` |
| `plink` | VARCHAR2 | Makes the cell clickable. | URL ('https://...') or the identifier returned by AddLink | `''` |

#### Example

```sql
PL_FPDF.SetFillColor(240, 240, 240);
PL_FPDF.Cell(
  pw      => 0,
  ph      => 10,
  ptxt    => 'Total: 1,234.56',
  pborder => 'LTB',
  pln     => 1,
  palign  => 'R',
  pfill   => 1);
```

**See also:** [MultiCell](#multicell), [Write](#write), [CellRotated](#cellrotated), [SetFillColor](#setfillcolor)

---

### CellRotated

Cell with the text rotated — useful for vertical table headers and labels.

#### Syntax

```sql
PROCEDURE PL_FPDF.CellRotated(
    p_width    number,
    p_height   number DEFAULT 0,
    p_text     varchar2 DEFAULT '',
    p_border   varchar2 DEFAULT '0',
    p_ln       number DEFAULT 0,
    p_align    varchar2 DEFAULT '',
    p_fill     number DEFAULT 0,
    p_link     varchar2 DEFAULT '',
    p_rotation pls_integer DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_width` | NUMBER | Cell width. | Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin | — |
| `p_height` | NUMBER | Cell height. | Number in the unit set by Init (mm, cm, pt or in) | `0` |
| `p_text` | VARCHAR2 | Text to write. | Any VARCHAR2 | `''` |
| `p_border` | VARCHAR2 | Borders. | '0', '1' or a combination of 'L', 'T', 'R', 'B' | `'0'` |
| `p_ln` | NUMBER | Cursor position afterwards. | 0 = to the right, 1 = next line, 2 = below | `0` |
| `p_align` | VARCHAR2 | Alignment. | 'L', 'C' or 'R' | `''` |
| `p_fill` | NUMBER | Fill. | 0 or 1 | `0` |
| `p_link` | VARCHAR2 | Optional link. | URL or an AddLink identifier | `''` |
| `p_rotation` | PLS_INTEGER | Rotation angle of the text. | 0 (default), 90, 180 or 270 — any other value raises an error | `0` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20110` | Invalid rotation value (use 0, 90, 180 or 270) |

#### Example

```sql
PL_FPDF.CellRotated(40, 10, 'VERTICAL', p_rotation => 90);
```

**See also:** [Cell](#cell), [WriteRotated](#writerotated)

---

### GetCurrentFontFamily

Returns the family of the current font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentFontFamily
    RETURN VARCHAR2;
```

#### Returns

VARCHAR2 — the family name.

**See also:** [SetFont](#setfont)

---

### GetCurrentFontSize

Returns the size of the current font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentFontSize
    RETURN NUMBER;
```

#### Returns

NUMBER — size in points.

**See also:** [SetFont](#setfont)

---

### GetCurrentFontStyle

Returns the style of the current font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentFontStyle
    RETURN VARCHAR2;
```

#### Returns

VARCHAR2 — '', 'B', 'I', 'BI' or 'U'.

**See also:** [SetFont](#setfont)

---

### GetLineSpacing

Returns the current line spacing.

#### Syntax

```sql
FUNCTION PL_FPDF.GetLineSpacing
    RETURN NUMBER;
```

#### Returns

NUMBER — the configured spacing.

**See also:** [SetLineSpacing](#setlinespacing)

---

### GetStringWidth

Measures how wide a piece of text will be in the current font and size — use it to centre by hand, size columns, or decide where to break.

#### Syntax

```sql
FUNCTION PL_FPDF.GetStringWidth(
    pstr varchar2)
    RETURN NUMBER;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pstr` | VARCHAR2 | Text to measure. | Any VARCHAR2 | — |

#### Returns

NUMBER — width in the document's unit.

#### Example

```sql
l_w := PL_FPDF.GetStringWidth(l_title);
PL_FPDF.SetX((210 - l_w) / 2);   -- centred on A4 portrait (210 mm)
```

**See also:** [SetFont](#setfont), [Cell](#cell)

---

### MultiCell

Writes a paragraph with automatic line breaking inside a given width. It exists as a function, returning the number of lines, and as a procedure.

#### Syntax

```sql
FUNCTION PL_FPDF.MultiCell(
    pw      number,
    ph      number DEFAULT 0,
    ptxt    varchar2,
    pborder varchar2 DEFAULT '0',
    palign  varchar2 DEFAULT 'J',
    pfill   number DEFAULT 0,
    phMax   number DEFAULT 0)
    RETURN NUMBER;
```

```sql
PROCEDURE PL_FPDF.MultiCell(
    pwidth     number,
    pheight    number DEFAULT 0,
    ptext      varchar2,
    pbrdr      varchar2 DEFAULT '0',
    palignment varchar2 DEFAULT 'J',
    pfillin    number DEFAULT 0,
    phMaximum  number DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pw` | NUMBER | Block width. | Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin | — |
| `ph` | NUMBER | Height of each line. | Number in the unit set by Init (mm, cm, pt or in) | `0` |
| `ptxt` | VARCHAR2 | Paragraph text; line breaks are honoured. | Any VARCHAR2 | — |
| `pborder` | VARCHAR2 | Block borders. | '0', '1' or a combination of 'L', 'T', 'R', 'B' | `'0'` |
| `palign` | VARCHAR2 | Alignment. | 'J' (justified, default), 'L', 'C' or 'R' | `'J'` |
| `pfill` | NUMBER | Fills the background. | 0 (default) or 1 | `0` |
| `phMax` | NUMBER | Maximum block height; text beyond it is truncated. | Number; 0 (default) = no limit | `0` |
| `pwidth` | NUMBER | Block width (procedure version). | Number in the unit set by Init (mm, cm, pt or in); 0 to the right margin | — |
| `pheight` | NUMBER | Height of each line (procedure version). | Number in the unit set by Init (mm, cm, pt or in) | `0` |
| `ptext` | VARCHAR2 | Paragraph text (procedure version). | Any VARCHAR2 | — |
| `pbrdr` | VARCHAR2 | Borders (procedure version). | '0', '1' or 'LTRB' | `'0'` |
| `palignment` | VARCHAR2 | Alignment (procedure version). | 'J', 'L', 'C' or 'R' | `'J'` |
| `pfillin` | NUMBER | Fill (procedure version). | 0 or 1 | `0` |
| `phMaximum` | NUMBER | Maximum height (procedure version). | Number; 0 = no limit | `0` |

#### Returns

NUMBER (function version) — how many lines were produced.

#### Example

```sql
l_lines := PL_FPDF.MultiCell(
  pw      => 0,
  ph      => 6,
  ptxt    => l_description,
  pborder => '1',
  palign  => 'J');
```

**See also:** [Cell](#cell), [Write](#write)

---

### SetLineSpacing

Sets the line spacing used by Write and MultiCell.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLineSpacing(
    pls number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pls` | NUMBER | Spacing factor or height. | Number > 0 | — |

**See also:** [GetLineSpacing](#getlinespacing)

---

### Text

Writes text at absolute coordinates, without moving the cursor or breaking lines.

#### Syntax

```sql
PROCEDURE PL_FPDF.Text(
    px   number,
    py   number,
    ptxt varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X coordinate where the text starts. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `py` | NUMBER | Y coordinate of the baseline. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `ptxt` | VARCHAR2 | Text to write. | Any VARCHAR2 | — |

**See also:** [Cell](#cell), [Write](#write)

---

### Write

Writes text as a flow, continuing where the previous one stopped and breaking lines automatically — which lets you switch fonts and styles in the middle of a sentence.

#### Syntax

```sql
PROCEDURE PL_FPDF.Write(
    pH    varchar2,
    ptxt  varchar2,
    plink varchar2 DEFAULT null);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pH` | VARCHAR2 | Line height. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `ptxt` | VARCHAR2 | Text to write. | Any VARCHAR2 | — |
| `plink` | VARCHAR2 | Optional link applied to the text. | URL or an AddLink identifier; NULL (default) = no link | `null` |

#### Example

```sql
PL_FPDF.Write(6, 'Document generated by ');
PL_FPDF.SetFont('Arial', 'B');
PL_FPDF.Write(6, 'PL_FPDF', 'https://maxwbh.github.io/pl_fpdf/');
```

**See also:** [Cell](#cell), [MultiCell](#multicell), [WriteRotated](#writerotated)

---

### WriteRotated

Write with the text rotated.

#### Syntax

```sql
PROCEDURE PL_FPDF.WriteRotated(
    p_height   number,
    p_text     varchar2,
    p_link     varchar2 DEFAULT null,
    p_rotation pls_integer DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_height` | NUMBER | Line height. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_text` | VARCHAR2 | Text to write. | Any VARCHAR2 | — |
| `p_link` | VARCHAR2 | Optional link. | URL or an AddLink identifier; NULL = no link | `null` |
| `p_rotation` | PLS_INTEGER | Rotation angle. | 0 (default), 90, 180 or 270 | `0` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20110` | Invalid rotation value |

**See also:** [Write](#write), [CellRotated](#cellrotated)

---

## Colours and drawing

### Line

Draws a straight line between two points.

#### Syntax

```sql
PROCEDURE PL_FPDF.Line(
    x1 number,
    y1 number,
    x2 number,
    y2 number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `x1` | NUMBER | X of the start point. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `y1` | NUMBER | Y of the start point. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `x2` | NUMBER | X of the end point. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `y2` | NUMBER | Y of the end point. | Number in the unit set by Init (mm, cm, pt or in) | — |

#### Example

```sql
PL_FPDF.Line(10, 30, 200, 30);
```

**See also:** [SetDrawColor](#setdrawcolor), [SetLineWidth](#setlinewidth)

---

### Poly

Draws a polygon from a collection of points.

#### Syntax

```sql
PROCEDURE PL_FPDF.Poly(
    points tab_points,
    pclose boolean,
    pstyle varchar2 DEFAULT '');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `points` | TAB_POINTS | Points of the polygon. | tab_points collection with X/Y pairs in the document's unit | — |
| `pclose` | BOOLEAN | Closes the polygon, joining the last point to the first. | TRUE or FALSE | — |
| `pstyle` | VARCHAR2 | Rendering style. | '' or 'D' (outline), 'F' (filled), 'DF' (both) | `''` |

**See also:** [Line](#line), [Triangle](#triangle)

---

### Rect

Draws a rectangle: outlined, filled, or both.

#### Syntax

```sql
PROCEDURE PL_FPDF.Rect(
    px     number,
    py     number,
    pw     number,
    ph     number,
    pstyle varchar2 DEFAULT '');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `py` | NUMBER | Y of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `pw` | NUMBER | Width. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `ph` | NUMBER | Height. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `pstyle` | VARCHAR2 | Rendering style. | '' or 'D' (outline only, the default), 'F' (fill only), 'DF'/'FD' (outline + fill) | `''` |

#### Example

```sql
PL_FPDF.Rect(px => 10, py => 40, pw => 60, ph => 25, pstyle => 'DF');
```

**See also:** [SetDrawColor](#setdrawcolor), [SetFillColor](#setfillcolor)

---

### SetDash

Sets a simple dashed-line pattern.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetDash(
    pblack number DEFAULT 0,
    pwhite number DEFAULT 0);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pblack` | NUMBER | Length of the dash. | Number in the unit set by Init (mm, cm, pt or in); 0 (default) goes back to a solid line | `0` |
| `pwhite` | NUMBER | Length of the gap. | Number in the unit set by Init (mm, cm, pt or in); 0 (default) goes back to a solid line | `0` |

#### Example

```sql
PL_FPDF.SetDash(2, 2);   -- dashed
PL_FPDF.SetDash(0, 0);   -- back to solid
```

**See also:** [SetLineDashPattern](#setlinedashpattern)

---

### SetDrawColor

Sets the colour of the lines and outlines drawn next.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetDrawColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `r` | NUMBER | Red component, or the grey level when g and b are omitted. | 0 to 255 | — |
| `g` | NUMBER | Green component. | 0 to 255; -1 (default) means greyscale, using r | `-1` |
| `b` | NUMBER | Blue component. | 0 to 255; -1 (default) means greyscale, using r | `-1` |

#### Example

```sql
PL_FPDF.SetDrawColor(200, 0, 0);   -- red
PL_FPDF.SetDrawColor(128);         -- mid grey
```

**See also:** [SetFillColor](#setfillcolor), [SetTextColor](#settextcolor), [SetLineWidth](#setlinewidth)

---

### SetFillColor

Sets the fill colour of cells (pfill = 1), rectangles and shapes.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetFillColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `r` | NUMBER | Red component, or the grey level. | 0 to 255 | — |
| `g` | NUMBER | Green component. | 0 to 255; -1 = greyscale | `-1` |
| `b` | NUMBER | Blue component. | 0 to 255; -1 = greyscale | `-1` |

#### Example

```sql
PL_FPDF.SetFillColor(240, 240, 240);
```

**See also:** [Cell](#cell), [Rect](#rect)

---

### SetLineDashPattern

Sets the dash pattern using the PDF's own syntax, for fine control.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLineDashPattern(
    pdash varchar2 DEFAULT '[] 0');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pdash` | VARCHAR2 | Pattern in PDF format. | '[] 0' (solid, the default), '[3 2] 0' (3 on, 2 off), '[1 2 3 2] 0' and so on | `'[] 0'` |

**See also:** [SetDash](#setdash)

---

### SetLineWidth

Sets the thickness of the lines drawn next.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLineWidth(
    width number);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `width` | NUMBER | Line thickness. | Number in the unit set by Init (mm, cm, pt or in); the PDF default is about 0.2 mm | — |

**See also:** [Line](#line), [Rect](#rect)

---

### SetTextColor

Sets the colour of the text written next.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetTextColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `r` | NUMBER | Red component, or the grey level. | 0 to 255 | — |
| `g` | NUMBER | Green component. | 0 to 255; -1 = greyscale | `-1` |
| `b` | NUMBER | Blue component. | 0 to 255; -1 = greyscale | `-1` |

**See also:** [SetFont](#setfont), [Cell](#cell)

---

### Triangle

Draws an isosceles triangle with a base of 2xpsize and a height of psize, pointing in the direction given.

#### Syntax

```sql
PROCEDURE PL_FPDF.Triangle(
    px           number,
    py           number,
    psize        number,
    porientation varchar2 DEFAULT 'left',
    pstyle       varchar2 DEFAULT '');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X of the top-left corner of the triangle's bounding box. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `py` | NUMBER | Y of the top-left corner of the triangle's bounding box. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `psize` | NUMBER | Height of the triangle; the base is twice that. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `porientation` | VARCHAR2 | Direction the tip points to. | 'up', 'down', 'left' or 'right' — or the initials 'U', 'D', 'L', 'R' | `'left'` |
| `pstyle` | VARCHAR2 | Rendering style. | '' or 'D' (outline), 'F' (filled), 'DF' (both) | `''` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20821` | Invalid orientation — use up/down/left/right or U/D/L/R |

**See also:** [Poly](#poly), [Rect](#rect)

---

## Images

### getImageFromUrl

Downloads an image from a URL through UTL_HTTP for use in the document. The database needs a network ACL for this.

#### Syntax

```sql
FUNCTION PL_FPDF.getImageFromUrl(
    p_Url varchar2)
    RETURN RECIMAGEBLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_Url` | VARCHAR2 | Address of the image. | http:// or https:// URL reachable from the database | — |

#### Returns

recImageBlob — record with the image's content and metadata.

**See also:** [Image](#image)

---

### image

Places a PNG or JPEG image on the current page, with optional proportional scaling.

#### Syntax

```sql
PROCEDURE PL_FPDF.image(
    pFile   varchar2,
    pX      number,
    pY      number,
    pWidth  number DEFAULT 0,
    pHeight number DEFAULT 0,
    pType   varchar2 DEFAULT null,
    pLink   varchar2 DEFAULT null);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pFile` | VARCHAR2 | Source of the image. | File name in an Oracle DIRECTORY, or the identifier returned by getImageFromUrl | — |
| `pX` | NUMBER | X of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `pY` | NUMBER | Y of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `pWidth` | NUMBER | Desired width. | Number in the unit set by Init (mm, cm, pt or in); 0 (default) derives it from the height | `0` |
| `pHeight` | NUMBER | Desired height. | Number in the unit set by Init (mm, cm, pt or in); 0 (default) derives it from the width, keeping the aspect ratio | `0` |
| `pType` | VARCHAR2 | Image format. | 'PNG', 'JPG'/'JPEG', or NULL (default) to detect it automatically | `null` |
| `pLink` | VARCHAR2 | Makes the image clickable. | URL or an AddLink identifier; NULL = no link | `null` |

#### Example

```sql
PL_FPDF.Image(
  pFile   => 'logo.png',
  pX      => 10, pY => 10,
  pWidth  => 40,
  pHeight => 0,                     -- proportional to the width
  pLink   => 'https://msbrasil.inf.br');
```

**See also:** [getImageFromUrl](#getimagefromurl), [OverlayImage](#overlayimage)

---

## Links

### AddLink

Creates an internal link, still without a destination, and returns its identifier — used later in SetLink and in the text APIs.

#### Syntax

```sql
FUNCTION PL_FPDF.AddLink
    RETURN NUMBER;
```

#### Returns

NUMBER — the link identifier.

#### Example

```sql
l_link := PL_FPDF.AddLink;
PL_FPDF.SetLink(l_link, 0, 3);
PL_FPDF.Cell(60, 8, 'Go to chapter 3', plink => l_link);
```

**See also:** [SetLink](#setlink), [Link](#link)

---

### Link

Creates a clickable rectangle anywhere on the page.

#### Syntax

```sql
PROCEDURE PL_FPDF.Link(
    px    number,
    py    number,
    pw    number,
    ph    number,
    plink varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `py` | NUMBER | Y of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `pw` | NUMBER | Width of the area. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `ph` | NUMBER | Height of the area. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `plink` | VARCHAR2 | Destination. | URL ('https://...') or an AddLink identifier | — |

**See also:** [AddLink](#addlink), [SetLink](#setlink)

---

### SetLink

Sets the destination of an internal link created by AddLink.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLink(
    plink number,
    py    number DEFAULT 0,
    ppage number DEFAULT -1);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `plink` | NUMBER | Link identifier. | The value returned by AddLink | — |
| `py` | NUMBER | Vertical destination on the page. | Number in the unit set by Init (mm, cm, pt or in); 0 (default) = top of the page | `0` |
| `ppage` | NUMBER | Destination page. | Page number; -1 (default) = the current page | `-1` |

**See also:** [AddLink](#addlink)

---

## Header and footer

### Footer

Footer extension point, called internally as each page is closed.

#### Syntax

```sql
PROCEDURE PL_FPDF.Footer;
```

**See also:** [SetFooterProc](#setfooterproc)

---

### Header

Header extension point, called internally on every new page.

#### Syntax

```sql
PROCEDURE PL_FPDF.Header;
```

**See also:** [SetHeaderProc](#setheaderproc)

---

### SetAliasNbPages

Sets the placeholder that will be replaced by the total page count when the document is finalised — so you can write 'Page 2 of 10' without knowing the total in advance.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetAliasNbPages(
    palias varchar2 DEFAULT '{nb}');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `palias` | VARCHAR2 | Placeholder to replace. | Any text; '{nb}' is the default | `'{nb}'` |

#### Example

```sql
PL_FPDF.SetAliasNbPages;   -- enables '{nb}'
PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo || ' of {nb}', 0, 0, 'C');
```

**See also:** [PageNo](#pageno)

---

### SetFooterProc

Registers a procedure of yours to run automatically in the footer of every page.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetFooterProc(
    footerprocname varchar2,
    paramTable     tv4000a DEFAULT noParam);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `footerprocname` | VARCHAR2 | Qualified name of the procedure. | 'package.procedure' or 'procedure' | — |
| `paramTable` | TV4000A | Parameters passed on to the procedure, by name. | PL_FPDF.tv4000a — an associative array INDEXED BY THE NAME of your procedure's parameter: l_p('p_title') := 'Report'. There is no tv4000a(...) constructor: declare a variable and fill it by key. noParam (default) = called with no parameters | `noParam` |

#### Example

```sql
-- your procedure:
--   PL_FPDF.SetY(-15);
--   PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
PL_FPDF.SetFooterProc('my_pkg.footer');
PL_FPDF.SetAliasNbPages;
```

**See also:** [SetHeaderProc](#setheaderproc), [SetAliasNbPages](#setaliasnbpages), [Footer](#footer)

---

### SetHeaderProc

Registers a procedure of yours to run automatically at the top of every page.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetHeaderProc(
    headerprocname varchar2,
    paramTable     tv4000a DEFAULT noParam);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `headerprocname` | VARCHAR2 | Qualified name of the procedure. | 'package.procedure' or 'procedure'; it must be reachable by the database user | — |
| `paramTable` | TV4000A | Parameters passed on to the procedure, by name. | PL_FPDF.tv4000a — an associative array INDEXED BY THE NAME of your procedure's parameter: l_p('p_title') := 'Report'. There is no tv4000a(...) constructor: declare a variable and fill it by key. noParam (default) = called with no parameters | `noParam` |

#### Example

```sql
DECLARE
  l_p PL_FPDF.tv4000a;   -- associative array: no constructor, filled by key
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');

  -- without parameters
  PL_FPDF.SetHeaderProc('my_pkg.header');

  -- with parameters: the key is the NAME of your procedure's parameter
  l_p('p_title')  := 'Monthly Report';
  l_p('p_period') := 'Aug/2026';
  PL_FPDF.SetHeaderProc('my_pkg.header', l_p);
  -- produces: Begin my_pkg.header(p_title=>'Monthly Report', p_period=>'Aug/2026'); end;

  PL_FPDF.AddPage();
END;
```

**See also:** [SetFooterProc](#setfooterproc), [Header](#header)

---

## QR codes and barcodes

### AddBarcode

Draws a linear barcode on the current page, with an optional human-readable caption.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddBarcode(
    p_x         number,
    p_y         number,
    p_width     number,
    p_height    number,
    p_code      varchar2,
    p_type      varchar2 DEFAULT 'CODE128',
    p_show_text boolean DEFAULT true);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_x` | NUMBER | X of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_y` | NUMBER | Y of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_width` | NUMBER | Total width of the code. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_height` | NUMBER | Height of the bars. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_code` | VARCHAR2 | Data to encode. | It must match the chosen symbology: EAN13 = 13 digits, EAN8 = 8 digits, ITF = any even number of digits (a Brazilian bank slip uses 44), ITF14 = 14 digits, CODE39 = uppercase alphanumeric, CODE128 = ASCII | — |
| `p_type` | VARCHAR2 | Barcode symbology. | 'CODE128' (default), 'CODE39', 'EAN13', 'EAN8', 'ITF' or 'ITF14' | `'CODE128'` |
| `p_show_text` | BOOLEAN | Prints the readable value below the bars. | TRUE or FALSE; TRUE is the default | `true` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20880` | Empty code |
| `-20881` | Width and height must be positive |
| `-20882` | Unsupported symbology |
| `-20883` | CODE39 does not accept the given character |
| `-20884` | CODE128 (Code B) accepts only ASCII 32 to 126 |
| `-20885` | EAN requires the digit count of the symbology |
| `-20886` | EAN: invalid check digit |
| `-20887` | ITF14 requires 13 or 14 digits |
| `-20888` | ITF with no digits in the content |

#### Example

```sql
PL_FPDF.AddBarcode(
  p_x => 30, p_y => 70, p_width => 150, p_height => 20,
  p_code      => '7891234567895',
  p_type      => 'EAN13',
  p_show_text => TRUE);
```

**See also:** [AddQRCode](#addqrcode)

---

### AddQRCode

Draws a QR code on the current page, with a configurable content format and error-correction level.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddQRCode(
    p_x                number,
    p_y                number,
    p_size             number,
    p_data             varchar2,
    p_format           varchar2 DEFAULT 'TEXT',
    p_error_correction varchar2 DEFAULT 'M');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_x` | NUMBER | X of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_y` | NUMBER | Y of the top-left corner. | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_size` | NUMBER | Side of the QR code (width = height). | Number in the unit set by Init (mm, cm, pt or in) | — |
| `p_data` | VARCHAR2 | Content to encode. | Up to 2953 bytes in binary mode; the content must follow the format chosen in p_format | — |
| `p_format` | VARCHAR2 | Content format, which tells readers how to interpret the code. | 'TEXT' (default, free text), 'URL', 'PIX', 'VCARD', 'WIFI' or 'EMAIL' | `'TEXT'` |
| `p_error_correction` | VARCHAR2 | Error-correction level: the higher it is, the better the code survives dirt and creases, and the less data fits. | 'L' (7%), 'M' (15%, default), 'Q' (25%) or 'H' (30%) | `'M'` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20870` | Empty content |
| `-20871` | Size must be greater than zero |
| `-20872` | Invalid correction level (use L, M, Q or H) |
| `-20873` | Content exceeds the QR code capacity at the requested level |

#### Example

```sql
PL_FPDF.AddQRCode(
  p_x => 150, p_y => 20, p_size => 40,
  p_data             => 'https://msbrasil.inf.br',
  p_format           => 'URL',
  p_error_correction => 'M');
```

**See also:** [AddBarcode](#addbarcode)

---

## Metadata and document setup

### GetDocumentMetadata

Returns the metadata currently set on the document.

#### Syntax

```sql
FUNCTION PL_FPDF.GetDocumentMetadata
    RETURN JSON_OBJECT_T;
```

#### Returns

JSON_OBJECT_T — object with title, subject, author, keywords, creator and the remaining options.

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

### GetPageInfo

Returns information about a page of the document being built.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPageInfo(
    p_page_number pls_integer DEFAULT null)
    RETURN JSON_OBJECT_T;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page to query. | Integer >= 1, up to GetPageCount; NULL (default) = the current page | `null` |

#### Returns

JSON_OBJECT_T — width, height, orientation and rotation of the page.

**See also:** [GetCurrentPage](#getcurrentpage), [GetPDFInfo](#getpdfinfo)

---

### SetAuthor

Sets the document author in the metadata.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetAuthor(
    pauthor varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pauthor` | VARCHAR2 | Author. | Any VARCHAR2 | — |

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

### SetCompression

Turns compression of the page content stream on or off. When on, each page comes out with /Filter [/ASCIIHexDecode /FlateDecode] — a deflate written inside the package itself, in hexadecimal because the document is assembled as text. Hexadecimal doubles the compressed size, so compression is only applied when the stream still ends up smaller than the original; a page that does not benefit comes out unfiltered. Text usually drops below a fifth.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetCompression(
    p_compress boolean DEFAULT false);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_compress` | BOOLEAN | Enables compression. | TRUE or FALSE; FALSE is the default | `false` |

**See also:** [FlateEncode](#flateencode), [FlateDecode](#flatedecode)

---

### SetCreator

Sets the creating application in the document metadata.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetCreator(
    pcreator varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pcreator` | VARCHAR2 | Name of the generating system. | Any VARCHAR2 | — |

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

### SetDisplayMode

Tells the PDF reader how to display the document when it opens.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetDisplayMode(
    zoom   varchar2,
    layout varchar2 DEFAULT 'continuous');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `zoom` | VARCHAR2 | Initial zoom level. | 'fullpage' (whole page), 'fullwidth' (page width), 'real' (100%), 'default', or a number standing for the percentage | — |
| `layout` | VARCHAR2 | Page layout. | 'continuous' (default), 'single', 'two' or 'default' | `'continuous'` |

#### Example

```sql
PL_FPDF.SetDisplayMode(zoom => 'fullpage', layout => 'single');
```

---

### SetDocumentConfig

Sets several document metadata fields and options at once, from a JSON object.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetDocumentConfig(
    p_config JSON_OBJECT_T);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_config` | JSON_OBJECT_T | Document configuration. | JSON_OBJECT_T with the optional keys: title, subject, author, keywords, creator, compression (boolean) | — |

#### Example

```sql
PL_FPDF.SetDocumentConfig(
  JSON_OBJECT_T('{"title":"Monthly Report","author":"M&S do Brasil","compression":true}'));
```

**See also:** [GetDocumentMetadata](#getdocumentmetadata), [SetTitle](#settitle)

---

### SetKeywords

Sets the document keywords, which help search and indexing.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetKeywords(
    pkeywords varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pkeywords` | VARCHAR2 | Keywords. | Free text, usually comma separated | — |

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

### SetSubject

Sets the document subject in the metadata.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetSubject(
    psubject varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `psubject` | VARCHAR2 | Subject. | Any VARCHAR2 | — |

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

### SetTitle

Sets the document title, shown in the PDF reader's title bar.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetTitle(
    ptitle varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `ptitle` | VARCHAR2 | Title. | Any VARCHAR2 | — |

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

## Document output

### ClosePDF

Closes the document structure (advanced use; the output APIs already do it).

#### Syntax

```sql
PROCEDURE PL_FPDF.ClosePDF;
```

**See also:** [OutputBlob](#outputblob)

---

### OpenPDF

Explicitly opens the document structure (advanced use; Init already does it).

#### Syntax

```sql
PROCEDURE PL_FPDF.OpenPDF;
```

**See also:** [Init](#init)

---

### Output

Classic FPDF-style output (compatibility). Prefer OutputBlob or OutputFile.

#### Syntax

```sql
PROCEDURE PL_FPDF.Output(
    pname varchar2 DEFAULT null,
    pdest varchar2 DEFAULT null);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pname` | VARCHAR2 | File or document name. | Any VARCHAR2 | `null` |
| `pdest` | VARCHAR2 | Destination. | 'S', 'D', 'I' or 'F' | `null` |

**See also:** [OutputBlob](#outputblob), [OutputFile](#outputfile)

---

### OutputBlob

Synonym of OutputBlob: finalises the document and returns the PDF as a BLOB.

#### Syntax

```sql
FUNCTION PL_FPDF.OutputBlob
    RETURN BLOB;
```

#### Returns

BLOB — the PDF content.

**See also:** [OutputBlob](#outputblob)

---

### OutputFile

Finalises the document and writes the PDF straight to a file on the database server.

#### Syntax

```sql
PROCEDURE PL_FPDF.OutputFile(
    p_filename  varchar2,
    p_directory varchar2 DEFAULT 'PDF_DIR');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_filename` | VARCHAR2 | Name of the output file. | E.g. 'report.pdf' | — |
| `p_directory` | VARCHAR2 | Oracle DIRECTORY with write permission. | Default: 'PDF_DIR' | `'PDF_DIR'` |

#### Example

```sql
PL_FPDF.OutputFile('report.pdf', 'PDF_DIR');
```

**See also:** [OutputBlob](#outputblob)

---

### ReturnBlob

Returns the PDF as a BLOB (legacy compatibility). Prefer OutputBlob.

#### Syntax

```sql
FUNCTION PL_FPDF.ReturnBlob(
    pname varchar2 DEFAULT null,
    pdest varchar2 DEFAULT null)
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pname` | VARCHAR2 | Logical name of the document. | Any VARCHAR2; NULL = no name | `null` |
| `pdest` | VARCHAR2 | FPDF-style destination. | 'S' (string/BLOB), 'D' (download), 'I' (inline), 'F' (file) | `null` |

#### Returns

BLOB — the PDF content.

**See also:** [OutputBlob](#outputblob)

---

## Manipulating an existing PDF

### AddWatermark

Registers a text watermark, drawn by OutputModifiedPDF() into the page content stream: every affected page gets a content object and a /Resources of its own, so a /Resources shared between pages is never contaminated. The mark is centred and rotated about the centre of the page, always in Helvetica.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddWatermark(
    p_text     VARCHAR2,
    p_opacity  NUMBER DEFAULT 0.3,
    p_rotation NUMBER DEFAULT 45,
    p_pages    VARCHAR2 DEFAULT 'ALL',
    p_font     VARCHAR2 DEFAULT 'Helvetica',
    p_size     NUMBER DEFAULT 48,
    p_color    VARCHAR2 DEFAULT 'gray');
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_text` | VARCHAR2 | Watermark text. | Any VARCHAR2, e.g. 'CONFIDENTIAL' | — |
| `p_opacity` | NUMBER | Opacity of the mark. | 0.0 (invisible) to 1.0 (opaque); 0.3 is the default | `0.3` |
| `p_rotation` | NUMBER | Text angle in degrees. | 0 to 360; 45 (diagonal) is the default | `45` |
| `p_pages` | VARCHAR2 | Pages that receive the mark. | 'ALL' (default), or a list/ranges such as '1', '1,3,5', '2-8', '1,3-5,10' | `'ALL'` |
| `p_font` | VARCHAR2 | Font used. | 'Helvetica' (default), 'Arial', 'Times' or 'Courier' | `'Helvetica'` |
| `p_size` | NUMBER | Font size in points. | Number > 0; 48 is the default | `48` |
| `p_color` | VARCHAR2 | Colour of the watermark. | 'gray' (default), 'red', 'blue', 'green', 'black', or an RGB hex value such as 'FF0000' | `'gray'` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |

#### Example

```sql
PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.AddWatermark(
  p_text     => 'CONFIDENTIAL',
  p_opacity  => 0.3,
  p_rotation => 45,
  p_pages    => 'ALL',
  p_size     => 48,
  p_color    => 'gray');
l_pdf := PL_FPDF.OutputModifiedPDF();
```

**See also:** [GetWatermarks](#getwatermarks), [OverlayText](#overlaytext), [OutputModifiedPDF](#outputmodifiedpdf)

---

### ClearPDFCache

Discards the loaded PDFs and frees the memory used by manipulation.

#### Syntax

```sql
PROCEDURE PL_FPDF.ClearPDFCache;
```

**See also:** [LoadPDF](#loadpdf), [UnloadPDF](#unloadpdf)

---

### FlateDecode

Decompresses a PDF /FlateDecode stream (zlib, RFC 1950). Implemented in pure PL/SQL, because UTL_COMPRESS will not do: it only accepts a gzip trailer with a correct CRC-32, and that CRC is of the DECOMPRESSED content — to know it you would have to decompress first. Useful in its own right, and it is what lets the copier read cross-reference streams and object streams.

#### Syntax

```sql
FUNCTION PL_FPDF.FlateDecode(
    p_stream    BLOB,
    p_max_bytes PLS_INTEGER DEFAULT 8388608)
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_stream` | BLOB | Compressed stream. | BLOB with zlib data — what the PDF marks as /FlateDecode | — |
| `p_max_bytes` | PLS_INTEGER | Output ceiling, in bytes. | Number > 0; 8388608 (8 MB) is the default. A compressed stream is UNTRUSTED input: a few KB can expand into gigabytes (a zip bomb) and bring the session down with ORA-04036. With the ceiling it raises -20893 and says where it stopped | `8388608` |

#### Returns

BLOB — the decompressed content.

#### Errors

| Code | Condition |
|--------|----------|
| `-20890` | Truncated stream |
| `-20891` | Malformed DEFLATE data |
| `-20892` | Invalid zlib header |
| `-20893` | Output exceeded p_max_bytes (corrupt input or a zip bomb) |

#### Example

```sql
l_plain := PL_FPDF.FlateDecode(l_compressed);
```

**See also:** [LoadPDF](#loadpdf)

---

### FlateEncode

Compresses data into a PDF /FlateDecode stream (zlib, RFC 1950). Written in pure PL/SQL: a single block with FIXED Huffman and greedy LZ77 — it compresses less than zlib's dynamic Huffman, and far more than nothing. When the data is incompressible it falls back to a stored block, so the output never exceeds the input plus the block overhead.

#### Syntax

```sql
FUNCTION PL_FPDF.FlateEncode(
    p_data BLOB)
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_data` | BLOB | Content to compress. | BLOB of any size; NULL is treated as empty | — |

#### Returns

BLOB — zlib stream: header, DEFLATE and Adler-32.

**See also:** [FlateDecode](#flatedecode), [SetCompression](#setcompression)

---

### GetActivePageCount

Returns how many pages will remain once the pending removals are applied.

#### Syntax

```sql
FUNCTION PL_FPDF.GetActivePageCount
    RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — pages not marked for removal.

**See also:** [RemovePage](#removepage), [GetPageCount](#getpagecount)

---

### GetPageCount

Returns the total page count of the loaded PDF, including the pages marked for removal.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPageCount
    RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — number of pages.

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |

**See also:** [LoadPDF](#loadpdf), [GetActivePageCount](#getactivepagecount)

---

### GetPDFInfo

Returns information about the loaded PDF: version, metadata and page count.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPDFInfo
    RETURN JSON_OBJECT_T;
```

#### Returns

JSON_OBJECT_T — PDF version, title, author, page count and the remaining metadata.

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |

**See also:** [LoadPDF](#loadpdf), [GetPageInfo](#getpageinfo)

---

### GetWatermarks

Lists every watermark applied to the loaded PDF.

#### Syntax

```sql
FUNCTION PL_FPDF.GetWatermarks
    RETURN JSON_ARRAY_T;
```

#### Returns

JSON_ARRAY_T — objects with id, text, opacity, rotation, pageRange, font, fontSize and color.

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |

**See also:** [AddWatermark](#addwatermark)

---

### IsPageRemoved

Tells whether a page is marked for removal.

#### Syntax

```sql
FUNCTION PL_FPDF.IsPageRemoved(
    p_page_number PLS_INTEGER)
    RETURN BOOLEAN;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page to query. | Integer >= 1, up to GetPageCount | — |

#### Returns

BOOLEAN — TRUE if the page will be removed from the output.

**See also:** [RemovePage](#removepage)

---

### IsPDFModified

Tells whether there are pending changes — rotation, removal, watermark, overlay — on the loaded PDF.

#### Syntax

```sql
FUNCTION PL_FPDF.IsPDFModified
    RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if there are changes not yet applied.

**See also:** [OutputModifiedPDF](#outputmodifiedpdf)

---

### LoadPDF

Loads an existing PDF into session memory for reading and modification. It is the starting point of the whole manipulation flow, which ends at OutputModifiedPDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.LoadPDF(
    p_pdf_blob BLOB);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_blob` | BLOB | PDF document to load. | Non-null BLOB with a valid %PDF header | — |

#### Errors

| Code | Condition |
|--------|----------|
| `-20800` | Invalid PDF (NULL or too small) |
| `-20801` | Invalid PDF header |
| `-20802` | startxref not found |
| `-20803` | Invalid xref table |
| `-20804` | Root object not found in the trailer |

#### Example

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
  PL_FPDF.LoadPDF(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Pages: ' || PL_FPDF.GetPageCount());
END;
```

**See also:** [LoadPDFWithID](#loadpdfwithid), [GetPageCount](#getpagecount), [OutputModifiedPDF](#outputmodifiedpdf), [ClearPDFCache](#clearpdfcache)

---

### OutputModifiedPDF

Produces the PDF with the changes applied, copying the kept pages object by object: content, fonts, images and annotations arrive intact, with no re-rendering. It applies RemovePage and RotatePage, and draws watermarks and text and image overlays into the content stream: every affected page gets a content object and a /Resources of its own.

#### Syntax

```sql
FUNCTION PL_FPDF.OutputModifiedPDF
    RETURN BLOB;
```

#### Returns

BLOB — the modified PDF.

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |
| `-20819` | PDF has no pending changes |
| `-20820` | Every page was removed |
| `-20843` | Malformed cross-reference stream (unreadable /W, /Index or /Filter) |
| `-20847` | Malformed object stream (/N, /First or an offset outside the stream) |
| `-20848` | Unsupported predictor, or an invalid row in the cross-reference stream |
| `-20823` | Invalid or unsupported image (interlaced below 8 bits, indexed and interlaced, or above 4 megapixels with alpha/interlacing) |
| `-20846` | The page /Resources does not allow overlaying (shared indirect sub-dictionary) |

#### Example

```sql
l_pdf := PL_FPDF.OutputModifiedPDF();
```

**See also:** [LoadPDF](#loadpdf), [ClearPDFCache](#clearpdfcache)

---

### RemovePage

Marks a page of the loaded PDF for removal. The deletion is logical: it is only applied by OutputModifiedPDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.RemovePage(
    p_page_number PLS_INTEGER);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page to remove. | Integer >= 1, up to GetPageCount | — |

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |
| `-20810` | Invalid page number |

**See also:** [IsPageRemoved](#ispageremoved), [GetActivePageCount](#getactivepagecount), [OutputModifiedPDF](#outputmodifiedpdf)

---

### RotatePage

Rotates a page of the loaded PDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.RotatePage(
    p_page_number PLS_INTEGER,
    p_rotation    NUMBER);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page to rotate. | Integer >= 1, up to GetPageCount | — |
| `p_rotation` | NUMBER | Rotation angle applied. | 0, 90, 180 or 270 | — |

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |
| `-20810` | Invalid page number |

#### Example

```sql
PL_FPDF.RotatePage(p_page_number => 1, p_rotation => 90);
```

**See also:** [LoadPDF](#loadpdf), [RemovePage](#removepage), [OutputModifiedPDF](#outputmodifiedpdf)

---

## Overlays

### ClearOverlays

Removes every overlay, from one page or from the whole document.

#### Syntax

```sql
PROCEDURE PL_FPDF.ClearOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page to clear. | Integer >= 1, up to GetPageCount; NULL (default) clears every page | `NULL` |

**See also:** [RemoveOverlay](#removeoverlay), [GetOverlays](#getoverlays)

---

### GetOverlays

Lists the overlays applied, optionally filtered by page.

#### Syntax

```sql
FUNCTION PL_FPDF.GetOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL)
    RETURN JSON_ARRAY_T;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page filter. | Integer >= 1, up to GetPageCount; NULL (default) returns the overlays of every page | `NULL` |

#### Returns

JSON_ARRAY_T — objects with overlayId, overlayType ('TEXT' or 'IMAGE'), pageNumber, x, y, content, opacity, rotation and zOrder.

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |

**See also:** [OverlayText](#overlaytext), [RemoveOverlay](#removeoverlay)

---

### OverlayImage

Places an image at an exact position on a page of the loaded PDF — logos, scanned signatures, seals. Drawn by OutputModifiedPDF() into the content stream. Neither format is decompressed: JPEG goes in whole as /DCTDecode, and a PNG's IDAT blocks are already zlib, which is the PDF's /FlateDecode. Not supported, and refused with -20823 rather than drawn wrong: PNG with an alpha channel, interlaced PNG (Adam7) and 16-bit depth.

#### Syntax

```sql
PROCEDURE PL_FPDF.OverlayImage(
    p_page_number PLS_INTEGER,
    p_image_blob  BLOB,
    p_x           NUMBER,
    p_y           NUMBER,
    p_width       NUMBER DEFAULT NULL,
    p_height      NUMBER DEFAULT NULL,
    p_options     JSON_OBJECT_T DEFAULT NULL);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page that receives the image. | Integer >= 1, up to GetPageCount | — |
| `p_image_blob` | BLOB | Image content. | BLOB in JPEG or PNG format | — |
| `p_x` | NUMBER | X position in PDF points. | 0 to 612 on A4 portrait | — |
| `p_y` | NUMBER | Y position in PDF points, from the bottom. | 0 to 792 on A4 portrait | — |
| `p_width` | NUMBER | Width in points. | Number > 0; NULL (default) uses the original width | `NULL` |
| `p_height` | NUMBER | Height in points. | Number > 0; NULL (default) uses the original height, or keeps the aspect ratio | `NULL` |
| `p_options` | JSON_OBJECT_T | Image settings. | JSON_OBJECT_T with the optional keys: opacity (0.0-1.0), rotation (0-360), maintainAspect (true/false), scaleToFit (true/false), zOrder (integer) | `NULL` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |
| `-20810` | Invalid page number |
| `-20821` | Invalid coordinates |
| `-20823` | Invalid image format (use JPEG or PNG) |
| `-20824` | Invalid image dimensions |

#### Example

```sql
PL_FPDF.OverlayImage(
  p_page_number => 1,
  p_image_blob  => l_logo,
  p_x => 450, p_y => 750,
  p_width => 100, p_height => NULL,
  p_options => JSON_OBJECT_T('{"opacity":0.9,"maintainAspect":true}'));
```

**See also:** [OverlayText](#overlaytext), [Image](#image), [GetOverlays](#getoverlays)

---

### OverlayText

Places text at an exact position on a page of the loaded PDF — stamps, protocol numbers, signatures. Coordinates are in PDF points, with Y growing upwards from the bottom. Drawn by OutputModifiedPDF() into the content stream. When width is given it defines the text BOX: lines wrap inside it and align is relative to [x, x+width]. Without width there is nothing to wrap, and align becomes relative to the point itself — 'center' centres the text on x, 'right' ends it at x.

#### Syntax

```sql
PROCEDURE PL_FPDF.OverlayText(
    p_page_number PLS_INTEGER,
    p_text        VARCHAR2,
    p_x           NUMBER,
    p_y           NUMBER,
    p_options     JSON_OBJECT_T DEFAULT NULL);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Page that receives the text. | Integer >= 1, up to GetPageCount | — |
| `p_text` | VARCHAR2 | Text to overlay. | Any VARCHAR2 | — |
| `p_x` | NUMBER | X position in PDF points (1 pt = 1/72 in), from the left. | 0 to 612 on A4 portrait | — |
| `p_y` | NUMBER | Y position in PDF points, from the bottom of the page. | 0 to 792 on A4 portrait | — |
| `p_options` | JSON_OBJECT_T | Visual settings of the text. | JSON_OBJECT_T with the optional keys: font ('Helvetica'/'Arial', 'Times' or 'Courier'; any other name falls back to Helvetica), fontSize (number, 12), color (RGB hex, '000000'), opacity (0.0-1.0), rotation (0-360), align ('left', 'center', 'right'), width (box width in points: sets the line breaking and the reference for align), bold (true/false), zOrder (integer; higher goes on top, being drawn last) | `NULL` |

#### Errors

| Code | Condition |
|--------|----------|
| `-20809` | No PDF loaded |
| `-20810` | Invalid page number |
| `-20821` | Invalid position coordinates |

#### Example

```sql
PL_FPDF.OverlayText(
  p_page_number => 1,
  p_text        => 'APPROVED',
  p_x => 400, p_y => 700,
  p_options => JSON_OBJECT_T('{"fontSize":24,"color":"FF0000","opacity":0.8,"bold":true}'));
```

**See also:** [OverlayImage](#overlayimage), [GetOverlays](#getoverlays), [AddWatermark](#addwatermark)

---

### RemoveOverlay

Removes one specific overlay by its identifier.

#### Syntax

```sql
PROCEDURE PL_FPDF.RemoveOverlay(
    p_overlay_id VARCHAR2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_overlay_id` | VARCHAR2 | Overlay identifier. | The overlayId value returned by GetOverlays, e.g. 'OVL_001' | — |

**See also:** [GetOverlays](#getoverlays), [ClearOverlays](#clearoverlays)

---

## Multi-PDF (merge, split, extract)

### ExtractPages

Creates a new PDF holding only the selected pages of a loaded document. The requested order is honoured and a page may repeat; only the objects reachable from the chosen pages are copied, so the result is smaller than the source.

#### Syntax

```sql
FUNCTION PL_FPDF.ExtractPages(
    p_pdf_id  VARCHAR2,
    p_pages   VARCHAR2,
    p_options JSON_OBJECT_T DEFAULT NULL)
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identifier of the source document. | The same one used in LoadPDFWithID | — |
| `p_pages` | VARCHAR2 | Pages to extract. | Comma-separated list and ranges, e.g. '1', '1,5,9', '1,5-10,15', '5,1' (reversed order) or 'ALL' | — |
| `p_options` | JSON_OBJECT_T | Extraction options. | Optional JSON_OBJECT_T; keys reserved for future use | `NULL` |

#### Returns

BLOB — PDF with the extracted pages.

#### Errors

| Code | Condition |
|--------|----------|
| `-20831` | PDF ID not found |
| `-20838` | Invalid page specification |
| `-20839` | Page number out of range |
| `-20841` | Object dictionary too large to renumber |
| `-20843` | Malformed cross-reference stream (unreadable /W, /Index or /Filter) |
| `-20847` | Malformed object stream (/N, /First or an offset outside the stream) |
| `-20848` | Unsupported predictor, or an invalid row in the cross-reference stream |

#### Example

```sql
l_summary := PL_FPDF.ExtractPages('body', '1,5-10,15');
```

**See also:** [SplitPDF](#splitpdf), [MergePDFs](#mergepdfs)

---

### GetLoadedPDFs

Lists the documents currently loaded under an identifier.

#### Syntax

```sql
FUNCTION PL_FPDF.GetLoadedPDFs
    RETURN JSON_ARRAY_T;
```

#### Returns

JSON_ARRAY_T — objects with the id and the information of each loaded PDF.

**See also:** [LoadPDFWithID](#loadpdfwithid), [UnloadPDF](#unloadpdf)

---

### LoadPDFWithID

Loads a PDF into memory under an identifier, so several documents can be held open at once to merge, split or extract pages.

#### Syntax

```sql
PROCEDURE PL_FPDF.LoadPDFWithID(
    p_pdf_id   VARCHAR2,
    p_pdf_blob BLOB);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identifier of the document within the session. | Unique text, e.g. 'cover', 'annex1' | — |
| `p_pdf_blob` | BLOB | Document to load. | BLOB with a valid PDF | — |

#### Errors

| Code | Condition |
|--------|----------|
| `-20800` | Invalid PDF |
| `-20801` | Invalid PDF header |

#### Example

```sql
PL_FPDF.LoadPDFWithID(l_cover, 'cover');
PL_FPDF.LoadPDFWithID(l_body,  'body');
```

**See also:** [MergePDFs](#mergepdfs), [SplitPDF](#splitpdf), [ExtractPages](#extractpages), [UnloadPDF](#unloadpdf), [GetLoadedPDFs](#getloadedpdfs)

---

### MergePDFs

Merges several loaded PDFs into a single document, in the order given. The objects of each source — pages, fonts, images, annotations — are copied with their indirect references renumbered: nothing is re-rendered and the original content arrives intact. The same identifier may appear more than once.

#### Syntax

```sql
FUNCTION PL_FPDF.MergePDFs(
    p_pdf_ids JSON_ARRAY_T,
    p_options JSON_OBJECT_T DEFAULT NULL)
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_ids` | JSON_ARRAY_T | Identifiers of the documents, in the desired order. | JSON_ARRAY_T of strings, e.g. JSON_ARRAY_T('["cover","body","annex"]') | — |
| `p_options` | JSON_OBJECT_T | Merge options. | Optional JSON_OBJECT_T; keys reserved for future use | `NULL` |

#### Returns

BLOB — the merged PDF.

#### Errors

| Code | Condition |
|--------|----------|
| `-20832` | No PDF ID given |
| `-20833` | PDF ID not loaded |
| `-20834` | Merge failed |
| `-20841` | Object dictionary too large to renumber |
| `-20843` | Malformed cross-reference stream (unreadable /W, /Index or /Filter) |
| `-20847` | Malformed object stream (/N, /First or an offset outside the stream) |
| `-20848` | Unsupported predictor, or an invalid row in the cross-reference stream |

#### Example

```sql
PL_FPDF.LoadPDFWithID(l_cover, 'cover');
PL_FPDF.LoadPDFWithID(l_body,  'body');
l_final := PL_FPDF.MergePDFs(JSON_ARRAY_T('["cover","body"]'));
```

**See also:** [LoadPDFWithID](#loadpdfwithid), [SplitPDF](#splitpdf), [ExtractPages](#extractpages)

---

### SplitPDF

Splits a loaded PDF into several documents, following the ranges given. Each part carries only the objects reachable from its own pages, which is why it ends up far smaller than the source. The ranges may not overlap.

#### Syntax

```sql
FUNCTION PL_FPDF.SplitPDF(
    p_pdf_id      VARCHAR2,
    p_page_ranges JSON_ARRAY_T)
    RETURN JSON_ARRAY_T;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identifier of the document to split. | The same one used in LoadPDFWithID | — |
| `p_page_ranges` | JSON_ARRAY_T | Ranges defining each part produced. | JSON_ARRAY_T of strings: '1-10', '11-20', '5' (a single page), '1,3,5' (a list) or 'ALL' | — |

#### Returns

JSON_ARRAY_T — one entry per range, with the part's PDF in base64, without line breaks.

#### Errors

| Code | Condition |
|--------|----------|
| `-20831` | PDF ID not found |
| `-20835` | No range given |
| `-20836` | Overlapping ranges |
| `-20838` | Invalid page specification |
| `-20839` | Page number out of range |
| `-20843` | Malformed cross-reference stream (unreadable /W, /Index or /Filter) |
| `-20847` | Malformed object stream (/N, /First or an offset outside the stream) |
| `-20848` | Unsupported predictor, or an invalid row in the cross-reference stream |

#### Example

```sql
l_parts := PL_FPDF.SplitPDF('body', JSON_ARRAY_T('["1-10","11-20","21-30"]'));
```

**See also:** [ExtractPages](#extractpages), [MergePDFs](#mergepdfs)

---

### UnloadPDF

Drops from memory a document loaded by LoadPDFWithID.

#### Syntax

```sql
PROCEDURE PL_FPDF.UnloadPDF(
    p_pdf_id VARCHAR2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Document identifier. | The same one used in LoadPDFWithID | — |

#### Errors

| Code | Condition |
|--------|----------|
| `-20831` | PDF ID not found |

**See also:** [LoadPDFWithID](#loadpdfwithid), [ClearPDFCache](#clearpdfcache)

---

## Security and encryption

### DecryptPDF

Removes the protection from an encrypted PDF, given the right password. It supports RC4-40, RC4-128, AES-128 (AESV2) and AES-256 (AESV3), with either the user or the owner password. The filter is read from the document's /CFM, not assumed. A PDF 1.5+ source is flattened, and object streams are decrypted before being decompressed.

#### Syntax

```sql
FUNCTION PL_FPDF.DecryptPDF(
    p_pdf      BLOB,
    p_password VARCHAR2)
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Encrypted document. | BLOB with a protected PDF | — |
| `p_password` | VARCHAR2 | User or owner password. | Text matching one of the document's passwords | — |

#### Returns

BLOB — the PDF without encryption.

#### Errors

| Code | Condition |
|--------|----------|
| `-20853` | The PDF is not encrypted |
| `-20854` | Password missing or invalid |
| `-20857` | Invalid AES stream or inconsistent padding |
| `-20861` | Incomplete /Encrypt dictionary (AESV3 without /UE) |

**See also:** [EncryptPDF](#encryptpdf), [IsEncrypted](#isencrypted)

---

### EncryptPDF

Encrypts an existing PDF, applying passwords and permissions. This is the recommended way to protect documents you generate or receive. A PDF 1.5+ source (cross-reference streams, object streams) is flattened: the objects inside object streams become top-level objects, and the output carries a classic cross-reference table.

#### Syntax

```sql
FUNCTION PL_FPDF.EncryptPDF(
    p_pdf            BLOB,
    p_user_password  VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL,
    p_permissions    JSON_OBJECT_T DEFAULT NULL,
    p_encryption     VARCHAR2 DEFAULT 'RC4-128')
    RETURN BLOB;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Document to protect. | BLOB with a valid, unencrypted PDF | — |
| `p_user_password` | VARCHAR2 | Password asked for when opening the document. | Text; empty allows opening without a password while keeping the restrictions | — |
| `p_owner_password` | VARCHAR2 | Owner password, which allows changing permissions. | Text; NULL (default) reuses the user password | `NULL` |
| `p_permissions` | JSON_OBJECT_T | Permissions granted to the reader. | JSON_OBJECT_T with the boolean keys: print, modify, copy, annotate, fill_forms, extract, assemble, print_high. Missing keys take the restrictive default | `NULL` |
| `p_encryption` | VARCHAR2 | Encryption algorithm. | 'AES-256' and 'AES-128' (recommended), 'RC4-128' (the default, kept for compatibility) or 'RC4-40' (legacy). RC4 has been broken for years and PDF 2.0 dropped it from the specification; recent readers warn about it or refuse it | `'RC4-128'` |

#### Returns

BLOB — the encrypted PDF.

#### Errors

| Code | Condition |
|--------|----------|
| `-20850` | Invalid encryption method |
| `-20851` | User password is required |
| `-20859` | The PDF is already encrypted |
| `-20863` | AES does not reproduce the FIPS-197 vector on this database |
| `-20864` | Stream beyond the RC4 ceiling in RAW (internal use) |

#### Example

```sql
DECLARE
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_perms.put('print', TRUE);
  l_perms.put('copy',  FALSE);
  l_secure := PL_FPDF.EncryptPDF(
    p_pdf            => l_pdf,
    p_user_password  => 'readPassword',
    p_owner_password => 'adminPassword',
    p_permissions    => l_perms,
    p_encryption     => 'RC4-128');
END;
```

**See also:** [DecryptPDF](#decryptpdf), [IsEncrypted](#isencrypted), [SetEncryption](#setencryption), [SetPermissions](#setpermissions)

---

### GetPDFVersion

Returns the PDF version configured for the output.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPDFVersion
    RETURN VARCHAR2;
```

#### Returns

VARCHAR2 — the version, e.g. '1.7'.

**See also:** [SetPDFVersion](#setpdfversion)

---

### GetSecurityInfo

Returns the security details of an encrypted PDF.

#### Syntax

```sql
FUNCTION PL_FPDF.GetSecurityInfo(
    p_pdf BLOB)
    RETURN JSON_OBJECT_T;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Document to inspect. | BLOB with a valid PDF | — |

#### Returns

JSON_OBJECT_T — algorithm, key length and the permissions granted.

**See also:** [IsEncrypted](#isencrypted), [EncryptPDF](#encryptpdf)

---

### IsEncrypted

Checks whether a PDF is encrypted.

#### Syntax

```sql
FUNCTION PL_FPDF.IsEncrypted(
    p_pdf BLOB)
    RETURN BOOLEAN;
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Document to check. | BLOB with a valid PDF | — |

#### Returns

BOOLEAN — TRUE if the document carries encryption.

**See also:** [GetSecurityInfo](#getsecurityinfo), [DecryptPDF](#decryptpdf)

---

### SetEncryption

Sets the encryption of a document being built; it is applied when the PDF is finalised by OutputBlob.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetEncryption(
    p_encryption     VARCHAR2,
    p_user_password  VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_encryption` | VARCHAR2 | Encryption algorithm. | 'RC4-128' or 'RC4-40' | — |
| `p_user_password` | VARCHAR2 | Opening password. | Text | — |
| `p_owner_password` | VARCHAR2 | Owner password. | Text; NULL (default) = same as the user password | `NULL` |

#### Example

```sql
PL_FPDF.Init; PL_FPDF.AddPage;
PL_FPDF.SetEncryption('RC4-128', 'readPassword', 'adminPassword');
PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE);
l_pdf := PL_FPDF.OutputBlob();
```

**See also:** [SetPermissions](#setpermissions), [EncryptPDF](#encryptpdf)

---

### SetPDFVersion

Sets the version declared in the header of the generated PDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetPDFVersion(
    p_version VARCHAR2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_version` | VARCHAR2 | PDF file version. | '1.4', '1.5', '1.6' or '1.7' | — |

**See also:** [GetPDFVersion](#getpdfversion)

---

### SetPermissions

Sets the permissions of the document being built, applied together with the encryption defined in SetEncryption.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetPermissions(
    p_print      BOOLEAN DEFAULT TRUE,
    p_modify     BOOLEAN DEFAULT FALSE,
    p_copy       BOOLEAN DEFAULT FALSE,
    p_annotate   BOOLEAN DEFAULT TRUE,
    p_fill_forms BOOLEAN DEFAULT TRUE,
    p_extract    BOOLEAN DEFAULT FALSE,
    p_assemble   BOOLEAN DEFAULT FALSE,
    p_print_high BOOLEAN DEFAULT TRUE);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_print` | BOOLEAN | Allows printing. | TRUE or FALSE; TRUE is the default | `TRUE` |
| `p_modify` | BOOLEAN | Allows changing the content. | TRUE or FALSE; FALSE is the default | `FALSE` |
| `p_copy` | BOOLEAN | Allows copying text and images. | TRUE or FALSE; FALSE is the default | `FALSE` |
| `p_annotate` | BOOLEAN | Allows adding comments and annotations. | TRUE or FALSE; TRUE is the default | `TRUE` |
| `p_fill_forms` | BOOLEAN | Allows filling in form fields. | TRUE or FALSE; TRUE is the default | `TRUE` |
| `p_extract` | BOOLEAN | Allows extracting content for accessibility. | TRUE or FALSE; FALSE is the default | `FALSE` |
| `p_assemble` | BOOLEAN | Allows inserting, removing and rotating pages. | TRUE or FALSE; FALSE is the default | `FALSE` |
| `p_print_high` | BOOLEAN | Allows high-resolution printing. | TRUE or FALSE; TRUE is the default | `TRUE` |

#### Example

```sql
PL_FPDF.SetPermissions(
  p_print  => TRUE,
  p_copy   => FALSE,
  p_modify => FALSE);
```

**See also:** [SetEncryption](#setencryption), [EncryptPDF](#encryptpdf)

---

## Diagnostics and utilities

### DebugDisabled

Turns the debug messages off.

#### Syntax

```sql
PROCEDURE PL_FPDF.DebugDisabled;
```

**See also:** [SetLogLevel](#setloglevel)

---

### DebugEnabled

Turns the package's debug messages on.

#### Syntax

```sql
PROCEDURE PL_FPDF.DebugEnabled;
```

**See also:** [SetLogLevel](#setloglevel)

---

### Error

Raises a standard PL_FPDF error. For internal use and for extensions.

#### Syntax

```sql
PROCEDURE PL_FPDF.Error(
    pmsg varchar2);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `pmsg` | VARCHAR2 | Error message. | Any VARCHAR2 | — |

---

### GetLogLevel

Returns the configured log level.

#### Syntax

```sql
FUNCTION PL_FPDF.GetLogLevel
    RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — the current level (0 to 4).

**See also:** [SetLogLevel](#setloglevel)

---

### GetScaleFactor

Returns the conversion factor between the document's unit and PDF points.

#### Syntax

```sql
FUNCTION PL_FPDF.GetScaleFactor
    RETURN NUMBER;
```

#### Returns

NUMBER — the scale factor, e.g. 2.8346 for millimetres.

**See also:** [Init](#init)

---

### SetLogLevel

Sets how detailed the package's log messages are.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLogLevel(
    p_level pls_integer);
```

#### Parameters

| Parameter | Type | Description | Accepted values | Default |
|-----------|------|-----------|-------------------|--------|
| `p_level` | PLS_INTEGER | Log level. | 0 (off), 1 (error), 2 (warning), 3 (info) or 4 (debug) | — |

**See also:** [GetLogLevel](#getloglevel), [DebugEnabled](#debugenabled)

---
