# PL_FPDF — API Reference

**Version:** 3.4.0 | **Oracle:** 19c+ | **License:** MIT

Documentation of every public function and procedure: syntax, parameters,
return, errors raised and an example.

> **Generated page**, from the Javadoc in `src/PL_FPDF.pks` and the English
> text in `dev/scripts/gen_docs/textos_en.py`. Do not edit it here.

> Task-oriented guide: [DOCUMENTATION_EN.md](DOCUMENTATION_EN.md) · Referência da API (português): [API_REFERENCE.md](API_REFERENCE.md)

## Index

**Lifecycle** — [fpdf](#fpdf) · [Init](#init) · [IsInitialized](#isinitialized) · [Reset](#reset)  
**Pages and positioning** — [AcceptPageBreak](#acceptpagebreak) · [AddPage](#addpage) · [GetCurrentPage](#getcurrentpage) · [GetX](#getx) · [GetY](#gety) · [Ln](#ln) · [PageNo](#pageno) · [SetAutoPageBreak](#setautopagebreak) · [SetLeftMargin](#setleftmargin) · [SetMargins](#setmargins) · [SetPage](#setpage) · [SetRightMargin](#setrightmargin) · [SetTopMargin](#settopmargin) · [SetX](#setx) · [SetXY](#setxy) · [SetY](#sety)  
**Fonts and UTF-8** — [AddFont](#addfont) · [AddTTFFont](#addttffont) · [ClearTTFFontCache](#clearttffontcache) · [GetTTFFontInfo](#getttffontinfo) · [IsTTFFontLoaded](#isttffontloaded) · [LoadTTFFromFile](#loadttffromfile) · [SetFont](#setfont) · [SetFontSize](#setfontsize) · [UTF8ToPDFString](#utf8topdfstring)  
**Writing text** — [Cell](#cell) · [CellRotated](#cellrotated) · [GetCurrentFontFamily](#getcurrentfontfamily) · [GetCurrentFontSize](#getcurrentfontsize) · [GetCurrentFontStyle](#getcurrentfontstyle) · [GetLineSpacing](#getlinespacing) · [GetStringWidth](#getstringwidth) · [MultiCell](#multicell) · [SetLineSpacing](#setlinespacing) · [Text](#text) · [Write](#write) · [WriteRotated](#writerotated)  
**Colours and drawing** — [Line](#line) · [Poly](#poly) · [Rect](#rect) · [SetDash](#setdash) · [SetDrawColor](#setdrawcolor) · [SetFillColor](#setfillcolor) · [SetLineDashPattern](#setlinedashpattern) · [SetLineWidth](#setlinewidth) · [SetTextColor](#settextcolor) · [Triangle](#triangle)  
**Images** — [getImageFromUrl](#getimagefromurl) · [image](#image) · [ImageFromBlob](#imagefromblob)  
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `orientation` | VARCHAR2 | `'P'` | Orientation. 'P' (default) or 'L' |
| `unit` | VARCHAR2 | `'mm'` | Unit of measurement. 'mm' (default), 'cm', 'pt' or 'in' |
| `format` | VARCHAR2 | `'A4'` | Page format. 'A3', 'A4' (default), 'A5', 'Letter' or 'Legal' |

#### Example

```sql
PL_FPDF.fpdf('L', 'mm', 'A4');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_orientation` | VARCHAR2 | `'P'` | Default page orientation. 'P' (portrait, the default) or 'L' (landscape) |
| `p_unit` | VARCHAR2 | `'mm'` | Unit of measurement for every coordinate and dimension in the document. 'mm' (default), 'cm', 'pt' or 'in' |
| `p_format` | VARCHAR2 | `'A4'` | Default page format. 'A3', 'A4' (default), 'A5', 'Letter' or 'Legal' |
| `p_encoding` | VARCHAR2 | `'UTF-8'` | Character encoding of the text. 'UTF-8' (default) or 'WINDOWS-1252' |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20001` | invalid orientation |
| `ORA-20002` | invalid unit of measurement |
| `ORA-20003` | unsupported encoding |

#### Example

```sql
PL_FPDF.Init('P', 'mm', 'A4');
```

**See also:** [Reset](#reset) · [IsInitialized](#isinitialized) · [AddPage](#addpage)

---

### IsInitialized

Tells whether a document is currently being built in this session.

#### Syntax

```sql
FUNCTION PL_FPDF.IsInitialized RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if Init has been called and the document has not been finalised.

#### Example

```sql
IF NOT PL_FPDF.IsInitialized THEN PL_FPDF.Init; END IF;
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

**See also:** [Init](#init) · [ClearPDFCache](#clearpdfcache)

---

## Pages and positioning

### AcceptPageBreak

Reports whether an automatic page break should happen at the current point. The engine calls it internally; you can read it for your own pagination logic.

#### Syntax

```sql
FUNCTION PL_FPDF.AcceptPageBreak RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if the automatic page break is enabled. **See also:** [SetAutoPageBreak](#setautopagebreak)

#### Example

```sql
IF PL_FPDF.AcceptPageBreak THEN ... END IF;
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_orientation` | VARCHAR2 | `null` | Orientation for this page only. 'P', 'L' or NULL (inherits from Init) |
| `p_format` | VARCHAR2 | `null` | Page format for this page only. 'A3', 'A4', 'A5', 'Letter', 'Legal' or NULL (inherits from Init) |
| `p_rotation` | PLS_INTEGER | `0` | Display rotation applied by the PDF reader. 0 (default), 90, 180 or 270 |

#### Note

The NAME of the first parameter changed between versions -- it was 'orientation' in 2.0.0 and today it is 'p_orientation'. Callers that pass by position (AddPage('L')) are unaffected; callers that pass by name (AddPage(orientation => 'L')) have to use the new name. There is no way to accept both: overloads differing only in parameter name make the call ambiguous, and Oracle refuses them with PLS-00307.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20005` | Init has not been called yet |
| `ORA-20107` | invalid orientation |
| `ORA-20103` | unknown page format |
| `ORA-20101` | invalid dimensions in the free-form format |
| `ORA-20104` | invalid rotation |

#### Example

```sql
PL_FPDF.AddPage;
PL_FPDF.AddPage('L');
PL_FPDF.AddPage('P', '210,297', 90);
```

**See also:** [Init](#init) · [SetPage](#setpage) · [GetCurrentPage](#getcurrentpage)

---

### GetCurrentPage

Returns the number of the current page — the one receiving content.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentPage RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — number of the active page. **See also:** [SetPage](#setpage), [PageNo](#pageno)

#### Example

```sql
l_pagina := PL_FPDF.GetCurrentPage;
```

**See also:** [SetPage](#setpage) · [PageNo](#pageno)

---

### GetX

Returns the current X position of the cursor.

#### Syntax

```sql
FUNCTION PL_FPDF.GetX RETURN NUMBER;
```

#### Returns

NUMBER — X coordinate. **See also:** [SetX](#setx), [SetXY](#setxy)

#### Example

```sql
l_x := PL_FPDF.GetX;
```

**See also:** [SetX](#setx) · [SetXY](#setxy)

---

### GetY

Returns the current Y position of the cursor.

#### Syntax

```sql
FUNCTION PL_FPDF.GetY RETURN NUMBER;
```

#### Returns

NUMBER — Y coordinate. **See also:** [SetY](#sety)

#### Example

```sql
l_y := PL_FPDF.GetY;
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `h` | NUMBER | `null` | Height of the jump. Number in the unit set by Init (mm, cm, pt or in); NULL (default) uses the height of the last cell written |

#### Example

```sql
PL_FPDF.Cell(40, 10, 'First');
PL_FPDF.Ln;
```

**See also:** [SetXY](#setxy)

---

### PageNo

Returns the current page number during generation; typically used in footers.

#### Syntax

```sql
FUNCTION PL_FPDF.PageNo RETURN NUMBER;
```

#### Returns

NUMBER — number of the current page.

#### Example

```sql
PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo);
```

**See also:** [SetAliasNbPages](#setaliasnbpages) · [SetFooterProc](#setfooterproc)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pauto` | BOOLEAN | — | Enables the automatic page break. TRUE or FALSE |
| `pMargin` | NUMBER | `0` | Bottom margin that triggers the break. Number in the unit set by Init (mm, cm, pt or in); 0 is the default |

#### Example

```sql
PL_FPDF.SetAutoPageBreak(TRUE, 20);
```

**See also:** [AcceptPageBreak](#acceptpagebreak) · [SetMargins](#setmargins)

---

### SetLeftMargin

Sets the left margin only.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLeftMargin(
    pMargin number);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pMargin` | NUMBER | — | Left margin. Number in the unit set by Init (mm, cm, pt or in) |

#### Example

```sql
PL_FPDF.SetLeftMargin(25);
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `left` | NUMBER | — | Left margin. Number in the unit set by Init (mm, cm, pt or in) |
| `top` | NUMBER | — | Top margin. Number in the unit set by Init (mm, cm, pt or in) |
| `right` | NUMBER | `-1` | Right margin. Number in the unit set by Init (mm, cm, pt or in); -1 (default) reuses the left margin value |

#### Example

```sql
PL_FPDF.SetMargins(20, 15);
```

**See also:** [SetLeftMargin](#setleftmargin) · [SetTopMargin](#settopmargin) · [SetRightMargin](#setrightmargin) · [SetAutoPageBreak](#setautopagebreak)

---

### SetPage

Chooses which existing page receives the content of the next calls, so you can go back to an earlier page — to fill in a table of contents once the final page numbers are known, for instance.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetPage(
    p_page_number pls_integer);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Page that becomes the current one. Integer >= 1, up to GetPageCount |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20005` | Init has not been called yet |
| `ORA-20106` | the page does not exist |

#### Example

```sql
PL_FPDF.SetPage(1);
```

**See also:** [AddPage](#addpage) · [GetCurrentPage](#getcurrentpage)

---

### SetRightMargin

Sets the right margin only.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetRightMargin(
    pMargin number);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pMargin` | NUMBER | — | Right margin. Number in the unit set by Init (mm, cm, pt or in) |

#### Example

```sql
PL_FPDF.SetRightMargin(20);
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pMargin` | NUMBER | — | Top margin. Number in the unit set by Init (mm, cm, pt or in) |

#### Example

```sql
PL_FPDF.SetTopMargin(15);
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | New X coordinate. Number in the unit set by Init (mm, cm, pt or in); negative values count from the right edge |

#### Example

```sql
PL_FPDF.SetX(-40);
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `x` | NUMBER | — | X coordinate. Number in the unit set by Init (mm, cm, pt or in) |
| `y` | NUMBER | — | Y coordinate. Number in the unit set by Init (mm, cm, pt or in) |

#### Example

```sql
PL_FPDF.SetXY(20, 50);
```

**See also:** [SetX](#setx) · [SetY](#sety)

---

### SetY

Sets the Y position of the cursor, and moves X back to the left margin.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetY(
    py number);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `py` | NUMBER | — | New Y coordinate. Number in the unit set by Init (mm, cm, pt or in); negative values count from the bottom edge — e.g. -15 for a footer |

#### Example

```sql
PL_FPDF.SetY(-20);   -- 20 above the foot of the page
```

**See also:** [GetY](#gety) · [SetXY](#setxy)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `family` | VARCHAR2 | — | Family name to register. Free text; used later in SetFont |
| `style` | VARCHAR2 | `''` | Style tied to the file. '', 'B', 'I' or 'BI' |
| `filename` | VARCHAR2 | `''` | Font definition file. File name; empty uses the standard FPDF convention |

#### Example

```sql
PL_FPDF.AddFont('Arial', 'B');
```

**See also:** [AddTTFFont](#addttffont) · [SetFont](#setfont)

---

### AddTTFFont

Registers a TrueType font from a BLOB and makes it available to `SetFont`. The file's tables are really parsed, and the font is embedded in the PDF as `/FontFile2`.

#### Syntax

```sql
PROCEDURE PL_FPDF.AddTTFFont(
    p_font_name varchar2,
    p_font_blob blob,
    p_encoding  varchar2 DEFAULT 'UTF-8',
    p_embed     boolean DEFAULT true);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | Name by which the font will be referenced in SetFont. Free text, e.g. 'Roboto' |
| `p_font_blob` | BLOB | — | Binary content of the .ttf file. Non-null BLOB holding a valid TrueType font |
| `p_encoding` | VARCHAR2 | `'UTF-8'` | Font encoding. 'UTF-8' (default) or 'WINDOWS-1252' |
| `p_embed` | BOOLEAN | `true` | Embeds the font program in the PDF. TRUE or FALSE; TRUE is the default |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20210` | font name is empty |
| `ORA-20211` | font BLOB is null |

#### Example

```sql
SELECT arquivo INTO l_ttf FROM fontes WHERE nome = 'Roboto';
PL_FPDF.AddTTFFont('Roboto', l_ttf);
```

**See also:** [LoadTTFFromFile](#loadttffromfile) · [IsTTFFontLoaded](#isttffontloaded) · [SetFont](#setfont)

---

### ClearTTFFontCache

Discards every loaded TrueType font, freeing session memory.

#### Syntax

```sql
PROCEDURE PL_FPDF.ClearTTFFontCache;
```

#### Example

```sql
PL_FPDF.ClearTTFFontCache;
```

**See also:** [AddTTFFont](#addttffont)

---

### GetTTFFontInfo

Returns a TrueType font's record: the stored bytes and the metrics parsed from the file, rescaled to the PDF's 1000 units per em.

#### Syntax

```sql
FUNCTION PL_FPDF.GetTTFFontInfo(
    p_font_name varchar2) RETURN RECTTFFONT;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | Font name. The same one used when loading |

#### Returns

recTTFFont — record with the font's metrics and information. **See also:** [AddTTFFont](#addttffont)

#### Errors

| Code | When |
|--------|--------|
| `ORA-20206` | font not loaded |

#### Example

```sql
l_fonte := PL_FPDF.GetTTFFontInfo('Roboto');
```

**See also:** [AddTTFFont](#addttffont)

---

### IsTTFFontLoaded

Checks whether a TrueType font has already been loaded in this session.

#### Syntax

```sql
FUNCTION PL_FPDF.IsTTFFontLoaded(
    p_font_name varchar2) RETURN BOOLEAN;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | Font name. The same one used when loading |

#### Returns

BOOLEAN — TRUE if the font is in the cache. **See also:** [AddTTFFont](#addttffont), [ClearTTFFontCache](#clearttffontcache)

#### Example

```sql
IF NOT PL_FPDF.IsTTFFontLoaded('Roboto') THEN ... END IF;
```

**See also:** [AddTTFFont](#addttffont) · [ClearTTFFontCache](#clearttffontcache)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | Name to use in SetFont. Free text |
| `p_file_path` | VARCHAR2 | — | Name of the .ttf file inside the directory. E.g. 'Roboto-Regular.ttf' |
| `p_directory` | VARCHAR2 | `'FONTS_DIR'` | Oracle DIRECTORY with read permission. Default: 'FONTS_DIR' |
| `p_encoding` | VARCHAR2 | `'UTF-8'` | Font encoding. 'UTF-8' (default) or 'WINDOWS-1252' |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20202` | invalid font file |
| `ORA-20401` | invalid directory |
| `ORA-20402` | no read permission |

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pfamily` | VARCHAR2 | — | Font family. 'Arial'/'Helvetica', 'Times', 'Courier', 'Symbol', 'ZapfDingbats' or the name of a TrueType font loaded with AddTTFFont/LoadTTFFromFile |
| `pstyle` | VARCHAR2 | `''` | Text style. '' (regular), 'B' (bold), 'I' (italic), 'BI' (bold italic) or 'U' (underlined) |
| `psize` | NUMBER | `0` | Size in points. Number > 0; 0 (default) keeps the current size |

#### Note

The family is stored in lower case and the style in upper case. That is what the getters return, not the text given here.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20005` | Init has not been called yet |
| `ORA-20201` | font not found -- neither among the core fonts nor in the TrueType registry |
| `ORA-20100` | invalid style |

#### Example

```sql
PL_FPDF.SetFont('Helvetica', 'B', 12);
```

**See also:** [SetFontSize](#setfontsize) · [AddTTFFont](#addttffont) · [GetStringWidth](#getstringwidth)

---

### SetFontSize

Changes only the size of the current font.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetFontSize(
    psize number);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `psize` | NUMBER | — | Size in points. Number > 0 |

#### Example

```sql
PL_FPDF.SetFontSize(8);
```

**See also:** [SetFont](#setfont)

---

### UTF8ToPDFString

Converts UTF-8 text to the PDF's internal representation. Called internally; useful when debugging accented characters.

#### Syntax

```sql
FUNCTION PL_FPDF.UTF8ToPDFString(
    p_text   varchar2,
    p_escape boolean DEFAULT true) RETURN VARCHAR2;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_text` | VARCHAR2 | — | Text to convert. Any VARCHAR2 in UTF-8 |
| `p_escape` | BOOLEAN | `true` | Escapes the PDF special characters (parentheses and backslash). TRUE or FALSE |

#### Returns

VARCHAR2 — the converted text.

#### Example

```sql
l_txt := PL_FPDF.UTF8ToPDFString('Total (net)');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pw` | NUMBER | — | Cell width. Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin |
| `ph` | NUMBER | `0` | Cell height. Number in the unit set by Init (mm, cm, pt or in); 0 is the default |
| `ptxt` | VARCHAR2 | `''` | Text to write. Any VARCHAR2; empty draws the cell alone |
| `pborder` | VARCHAR2 | `'0'` | '0' for no border, '1' for the whole frame, or the letters of the sides you want, combined: 'L' (Left), 'T' (Top), 'R' (Right) and 'B' (Bottom). 'LR' draws only the two sides; 'TB', only top and bottom |
| `pln` | NUMBER | `0` | Where the cursor goes afterwards. 0 = to the right of the cell (default); 1 = start of the next line; 2 = below the cell |
| `palign` | VARCHAR2 | `''` | Text alignment. 'L' (left), 'C' (centre), 'R' (right) or '' (default, left) |
| `pfill` | NUMBER | `0` | Fills the background with the SetFillColor colour. 0 = transparent (default); 1 = filled |
| `plink` | VARCHAR2 | `''` | Makes the cell clickable. URL ('https://...'); an AddLink identifier is refused with ORA-20601 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | any failure while writing the cell. Cell wraps the original error in this code, but keeps the stack (keeperrorstack), so the cause -- an ORA-20203 for a character outside WinAnsi, for instance -- stays visible in the trace. |

#### Example

```sql
-- the whole frame around the cell
PL_FPDF.Cell(40, 8, 'Total', '1', 0, 'L');
PL_FPDF.Cell(30, 8, '1.234,56', '1', 1, 'R');

-- only the bottom, to underline a column heading
PL_FPDF.Cell(100, 8, 'Product', 'B', 1, 'L');

-- table body: each cell draws only the sides ('LR'), and an empty
-- cell with the top ('T') closes the table underneath. Without that,
-- '1' on every cell would give a double rule between the rows.
PL_FPDF.Cell(60, 8, 'Annual licence', 'LR', 0, 'L');
PL_FPDF.Cell(40, 8, '28.400,00',     'LR', 1, 'R');
PL_FPDF.Cell(60, 8, 'Support 8x5',   'LR', 0, 'L');
PL_FPDF.Cell(40, 8, '15.750,50',     'LR', 1, 'R');
PL_FPDF.Cell(100, 0, '', 'T', 1);
```

**See also:** [MultiCell](#multicell) · [Write](#write) · [CellRotated](#cellrotated) · [SetFillColor](#setfillcolor)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_width` | NUMBER | — | Cell width. Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin |
| `p_height` | NUMBER | `0` | Cell height. Number in the unit set by Init (mm, cm, pt or in) |
| `p_text` | VARCHAR2 | `''` | Text to write. Any VARCHAR2 |
| `p_border` | VARCHAR2 | `'0'` | '0' for no border, '1' for the whole frame, or the letters of the sides you want, combined: 'L' (Left), 'T' (Top), 'R' (Right) and 'B' (Bottom). 'LR' draws only the two sides; 'TB', only top and bottom |
| `p_ln` | NUMBER | `0` | Cursor position afterwards. 0 = to the right; 1 = next line; 2 = below |
| `p_align` | VARCHAR2 | `''` | Alignment. 'L', 'C' or 'R' |
| `p_fill` | NUMBER | `0` | Fill. 0 or 1 |
| `p_link` | VARCHAR2 | `''` | Optional link. URL; an AddLink identifier is refused with ORA-20601 |
| `p_rotation` | PLS_INTEGER | `0` | Rotation angle of the text. 0 (default), 90, 180 or 270 — any other value raises an error |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20110` | invalid rotation |

#### Example

```sql
PL_FPDF.CellRotated(10, 40, 'January', '1', 0, 'C', 0, '', 90);
```

**See also:** [Cell](#cell) · [WriteRotated](#writerotated)

---

### GetCurrentFontFamily

Returns the family of the current font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentFontFamily RETURN VARCHAR2;
```

#### Returns

VARCHAR2 — the family name. **See also:** [SetFont](#setfont)

#### Example

```sql
l_familia := PL_FPDF.GetCurrentFontFamily;
```

**See also:** [SetFont](#setfont)

---

### GetCurrentFontSize

Returns the size of the current font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentFontSize RETURN NUMBER;
```

#### Returns

NUMBER — size in points. **See also:** [SetFont](#setfont)

#### Example

```sql
l_corpo := PL_FPDF.GetCurrentFontSize;
```

**See also:** [SetFont](#setfont)

---

### GetCurrentFontStyle

Returns the style of the current font.

#### Syntax

```sql
FUNCTION PL_FPDF.GetCurrentFontStyle RETURN VARCHAR2;
```

#### Returns

VARCHAR2 — '', 'B', 'I', 'BI' or 'U', always **uppercase**. > `SetFont` normalises it: `'b'` goes in and `'B'` comes back. **See also:** [SetFont](#setfont)

#### Example

```sql
l_estilo := PL_FPDF.GetCurrentFontStyle;
```

**See also:** [SetFont](#setfont)

---

### GetLineSpacing

Returns the current line spacing.

#### Syntax

```sql
FUNCTION PL_FPDF.GetLineSpacing RETURN NUMBER;
```

#### Returns

NUMBER — the configured spacing. **See also:** [SetLineSpacing](#setlinespacing)

#### Example

```sql
l_entre := PL_FPDF.GetLineSpacing;
```

**See also:** [SetLineSpacing](#setlinespacing)

---

### GetStringWidth

Measures how wide a piece of text will be in the current font and size — use it to centre by hand, size columns, or decide where to break.

#### Syntax

```sql
FUNCTION PL_FPDF.GetStringWidth(
    pstr varchar2) RETURN NUMBER;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pstr` | VARCHAR2 | — | Text to measure. Any VARCHAR2 |

#### Returns

NUMBER — width in the document's unit.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20203` | character outside WinAnsi |

#### Example

```sql
l_larg := PL_FPDF.GetStringWidth('São Paulo');
```

**See also:** [SetFont](#setfont) · [Cell](#cell)

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
    phMax   number DEFAULT 0) RETURN NUMBER;
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pw` | NUMBER | — | Block width. Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin |
| `ph` | NUMBER | `0` | Height of each line. Number in the unit set by Init (mm, cm, pt or in) |
| `ptxt` | VARCHAR2 | — | Paragraph text; line breaks are honoured. Any VARCHAR2 |
| `pborder` | VARCHAR2 | `'0'` | '0' for no border, '1' for the whole frame, or the letters of the sides you want, combined: 'L' (Left), 'T' (Top), 'R' (Right) and 'B' (Bottom). 'LR' draws only the two sides; 'TB', only top and bottom |
| `palign` | VARCHAR2 | `'J'` | Alignment. 'J' (justified, default), 'L', 'C' or 'R' |
| `pfill` | NUMBER | `0` | Fills the background. 0 (default) or 1 |
| `phMax` | NUMBER | `0` | Maximum block height; text beyond it is truncated. Number; 0 (default) = no limit |

In the overload above the parameters are the same, in the same order, under other names: `pwidth`, `pheight`, `ptext`, `pbrdr`, `palignment`, `pfillin`, `phMaximum`.

#### Returns

NUMBER (function version) — how many lines were produced.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | any failure while writing, with the original stack preserved |

#### Example

```sql
-- justified paragraph, with the whole frame
l_linhas := PL_FPDF.MultiCell(120, 5, l_texto_longo, '1', 'J');

-- no border at all, which is the usual case in body text
l_linhas := PL_FPDF.MultiCell(120, 5, l_texto_longo, '0', 'J');

-- only the sides, for a block inside a table
l_linhas := PL_FPDF.MultiCell(120, 5, l_observacao, 'LR', 'L');
```

**See also:** [Cell](#cell) · [Write](#write)

---

### SetLineSpacing

Sets the line spacing used by Write and MultiCell.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLineSpacing(
    pls number);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pls` | NUMBER | — | Spacing factor or height. Number > 0 |

#### Example

```sql
PL_FPDF.SetLineSpacing(5);
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | X coordinate where the text starts. Number in the unit set by Init (mm, cm, pt or in) |
| `py` | NUMBER | — | Y coordinate of the baseline. Number in the unit set by Init (mm, cm, pt or in) |
| `ptxt` | VARCHAR2 | — | Text to write. Any VARCHAR2 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20203` | character outside WinAnsi |

#### Example

```sql
PL_FPDF.Text(20, 50, 'Billing address');
```

**See also:** [Cell](#cell) · [Write](#write)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pH` | VARCHAR2 | — | Line height. Number in the unit set by Init (mm, cm, pt or in) |
| `ptxt` | VARCHAR2 | — | Text to write. Any VARCHAR2 |
| `plink` | VARCHAR2 | `null` | Optional link applied to the text. URL; NULL (default) = no link. An AddLink identifier is refused with ORA-20601 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | any failure while writing, with the original stack preserved |

#### Example

```sql
PL_FPDF.SetFont('Helvetica', '', 10);
PL_FPDF.Write(5, 'Consulte o ');
PL_FPDF.SetFont('Helvetica', 'U', 10);
PL_FPDF.Write(5, 'manual', 'https://example.com/manual');
```

**See also:** [Cell](#cell) · [MultiCell](#multicell) · [WriteRotated](#writerotated)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_height` | NUMBER | — | Line height. Number in the unit set by Init (mm, cm, pt or in) |
| `p_text` | VARCHAR2 | — | Text to write. Any VARCHAR2 |
| `p_link` | VARCHAR2 | `null` | Optional link. URL NULL = no link. An AddLink identifier is refused with ORA-20601 |
| `p_rotation` | PLS_INTEGER | `0` | Rotation angle. 0 (default), 90, 180 or 270 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20110` | invalid rotation |
| `ORA-20111` | only 0-degree rotation is supported; use CellRotated |

#### Example

```sql
PL_FPDF.WriteRotated(5, 'CONFIDENTIAL', NULL, 90);
```

**See also:** [Write](#write) · [CellRotated](#cellrotated)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `x1` | NUMBER | — | X of the start point. Number in the unit set by Init (mm, cm, pt or in) |
| `y1` | NUMBER | — | Y of the start point. Number in the unit set by Init (mm, cm, pt or in) |
| `x2` | NUMBER | — | X of the end point. Number in the unit set by Init (mm, cm, pt or in) |
| `y2` | NUMBER | — | Y of the end point. Number in the unit set by Init (mm, cm, pt or in) |

#### Example

```sql
PL_FPDF.Line(20, 60, 190, 60);
```

**See also:** [SetDrawColor](#setdrawcolor) · [SetLineWidth](#setlinewidth)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `points` | TAB_POINTS | — | Points of the polygon. tab_points collection with X/Y pairs in the document's unit |
| `pclose` | BOOLEAN | — | Closes the polygon, joining the last point to the first. TRUE or FALSE |
| `pstyle` | VARCHAR2 | `''` | Rendering style. '' or 'D' (outline), 'F' (filled), 'DF' (both) |

#### Example

```sql
l_pontos(0).x := 10; l_pontos(0).y := 10;
l_pontos(1).x := 50; l_pontos(1).y := 10;
l_pontos(2).x := 30; l_pontos(2).y := 40;
PL_FPDF.Poly(l_pontos, TRUE, 'F');
```

**See also:** [Line](#line) · [Triangle](#triangle)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `py` | NUMBER | — | Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `pw` | NUMBER | — | Width. Number in the unit set by Init (mm, cm, pt or in) |
| `ph` | NUMBER | — | Height. Number in the unit set by Init (mm, cm, pt or in) |
| `pstyle` | VARCHAR2 | `''` | Rendering style. '' or 'D' (outline only, the default), 'F' (fill only), 'DF'/'FD' (outline + fill) |

#### Example

```sql
PL_FPDF.Rect(20, 40, 60, 25, 'FD');
```

**See also:** [SetDrawColor](#setdrawcolor) · [SetFillColor](#setfillcolor)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pblack` | NUMBER | `0` | Length of the dash. Number in the unit set by Init (mm, cm, pt or in); 0 (default) goes back to a solid line |
| `pwhite` | NUMBER | `0` | Length of the gap. Number in the unit set by Init (mm, cm, pt or in); 0 (default) goes back to a solid line |

#### Example

```sql
PL_FPDF.SetDash(2, 2);          -- tracejado
PL_FPDF.Line(10, 50, 200, 50);
PL_FPDF.SetDash;                -- back to the solid line
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `r` | NUMBER | — | Red component, or the grey level when g and b are omitted. 0 to 255 |
| `g` | NUMBER | `-1` | Green component. 0 to 255; -1 (default) means greyscale, using r |
| `b` | NUMBER | `-1` | Blue component. 0 to 255; -1 (default) means greyscale, using r |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20501` | component outside 0..255 |

#### Example

```sql
PL_FPDF.SetDrawColor(200);            -- cinza claro
PL_FPDF.SetDrawColor(0, 90, 160);     -- azul
```

**See also:** [SetFillColor](#setfillcolor) · [SetTextColor](#settextcolor) · [SetLineWidth](#setlinewidth)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `r` | NUMBER | — | Red component, or the grey level. 0 to 255 |
| `g` | NUMBER | `-1` | Green component. 0 to 255; - 1 = greyscale |
| `b` | NUMBER | `-1` | Blue component. 0 to 255; - 1 = greyscale |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20501` | component outside 0..255 |

#### Example

```sql
PL_FPDF.SetFillColor(230, 230, 230);
PL_FPDF.Cell(40, 8, 'Heading', '1', 0, 'C', 1);
```

**See also:** [Cell](#cell) · [Rect](#rect)

---

### SetLineDashPattern

Sets the dash pattern using the PDF's own syntax, for fine control.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetLineDashPattern(
    pdash varchar2 DEFAULT '[] 0');
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pdash` | VARCHAR2 | `'[] 0'` | Pattern in PDF format. '[] 0' (solid, the default), '[3 2] 0' (3 on, 2 off), '[1 2 3 2] 0' and so on |

#### Example

```sql
PL_FPDF.SetLineDashPattern('[3 2] 0');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `width` | NUMBER | — | Line thickness. Number in the unit set by Init (mm, cm, pt or in); the PDF default is about 0.2 mm |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20502` | zero or negative line width |

#### Example

```sql
PL_FPDF.SetLineWidth(0.5);
```

**See also:** [Line](#line) · [Rect](#rect)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `r` | NUMBER | — | Red component, or the grey level. 0 to 255 |
| `g` | NUMBER | `-1` | Green component. 0 to 255; - 1 = greyscale |
| `b` | NUMBER | `-1` | Blue component. 0 to 255; - 1 = greyscale |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20501` | component outside 0..255 |

#### Example

```sql
PL_FPDF.SetTextColor(180, 0, 0);
```

**See also:** [SetFont](#setfont) · [Cell](#cell)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | X of the top-left corner of the triangle's bounding box. Number in the unit set by Init (mm, cm, pt or in) |
| `py` | NUMBER | — | Y of the top-left corner of the triangle's bounding box. Number in the unit set by Init (mm, cm, pt or in) |
| `psize` | NUMBER | — | Height of the triangle; the base is twice that. Number in the unit set by Init (mm, cm, pt or in) |
| `porientation` | VARCHAR2 | `'left'` | Direction the tip points to. 'up', 'down', 'left' or 'right' — or the initials 'U', 'D', 'L', 'R' |
| `pstyle` | VARCHAR2 | `''` | Rendering style. '' or 'D' (outline), 'F' (filled), 'DF' (both) |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20821` | invalid orientation |

#### Example

```sql
PL_FPDF.Triangle(20, 20, 5, 'right', 'F');
```

**See also:** [Poly](#poly) · [Rect](#rect)

---

## Images

### getImageFromUrl

Downloads an image from a URL through UTL_HTTP for use in the document. The database needs a network ACL for this.

#### Syntax

```sql
FUNCTION PL_FPDF.getImageFromUrl(
    p_Url varchar2) RETURN RECIMAGEBLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_Url` | VARCHAR2 | — | Address of the image. http:// or https:// URL reachable from the database |

#### Returns

recImageBlob — record with the image's content and metadata. **See also:** [Image](#image)

#### Note

Accepted formats: PNG, JPEG/JPG

#### Errors

| Code | When |
|--------|--------|
| `ORA-20301` | invalid image header |
| `ORA-20302` | the image could not be fetched |
| `ORA-20303` | unsupported format |

#### Example

```sql
l_img := PL_FPDF.getImageFromUrl('https://example.com/logo.png');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pFile` | VARCHAR2 | — | Source of the image. File name in an Oracle DIRECTORY, or the identifier returned by getImageFromUrl |
| `pX` | NUMBER | — | X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `pY` | NUMBER | — | Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `pWidth` | NUMBER | `0` | Desired width. Number in the unit set by Init (mm, cm, pt or in); 0 (default) derives it from the height |
| `pHeight` | NUMBER | `0` | Desired height. Number in the unit set by Init (mm, cm, pt or in); 0 (default) derives it from the width, keeping the aspect ratio |
| `pType` | VARCHAR2 | `null` | Image format. 'PNG', 'JPG'/'JPEG', or NULL (default) to detect it automatically |
| `pLink` | VARCHAR2 | `null` | Makes the image clickable. URL NULL = no link. An AddLink identifier is refused with ORA-20601 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | failure fetching or parsing the image, with the original stack preserved |

#### Example

```sql
PL_FPDF.Image('https://example.com/logo.png', 10, 10, 40);
```

**See also:** [getImageFromUrl](#getimagefromurl) · [OverlayImage](#overlayimage)

---

### ImageFromBlob

Places an image you already hold — from a table, a BFILE or a variable — without going through a URL. `Image` fetches over the network, which needs an ACL granted to the schema; when the bytes are already in the database, this entry point needs neither the network nor the permission.

#### Syntax

```sql
PROCEDURE PL_FPDF.ImageFromBlob(
    p_blob  blob,
    p_name  varchar2,
    pX      number,
    pY      number,
    pWidth  number DEFAULT 0,
    pHeight number DEFAULT 0,
    pLink   varchar2 DEFAULT null);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_blob` | BLOB | — | Image bytes. PNG or JPEG |
| `p_name` | VARCHAR2 | — | Key in the image cache. A BLOB has no filename, so you pick one: distinct names for distinct images, and the same name reuses the object already emitted instead of writing the same bytes again. Any non-null text |
| `pX` | NUMBER | — | X of the top-left corner. Number in the unit set in Init (mm, cm, pt or in) |
| `pY` | NUMBER | — | Y of the top-left corner. Number in the unit set in Init (mm, cm, pt or in) |
| `pWidth` | NUMBER | `0` | Requested width. Number in the unit set in Init; 0 (default) derives it from the height |
| `pHeight` | NUMBER | `0` | Requested height. Number in the unit set in Init; 0 (default) derives it from the width, keeping the aspect ratio |
| `pLink` | VARCHAR2 | `null` | Makes the image clickable. URL NULL = no link. An AddLink identifier is refused with ORA-20601 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20301` | invalid header, empty BLOB or missing name |
| `ORA-20303` | unsupported format |

#### Example

```sql
SELECT logo INTO l_logo FROM empresa WHERE id = 1;
PL_FPDF.ImageFromBlob(l_logo, 'LOGO', 10, 10, 40);
```

**See also:** [image](#image) · [OverlayImage](#overlayimage)

---

## Links

### AddLink

Creates an internal link, still without a destination, and returns its identifier.

#### Syntax

```sql
FUNCTION PL_FPDF.AddLink RETURN NUMBER;
```

#### Returns

NUMBER — the link identifier.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20601` | internal link is not implemented |

#### Example

```sql
-- Use URL:
PL_FPDF.Cell(60, 8, 'Site', plink => 'https://example.com');
```

**See also:** [SetLink](#setlink) · [Link](#link)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `py` | NUMBER | — | Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `pw` | NUMBER | — | Width of the area. Number in the unit set by Init (mm, cm, pt or in) |
| `ph` | NUMBER | — | Height of the area. Number in the unit set by Init (mm, cm, pt or in) |
| `plink` | VARCHAR2 | — | Destination. URL ('https://...'); an AddLink identifier is refused with ORA-20601 |

#### Limitation

1. One area per page. A second call on the same page silently replaces the first -- the structure keeps one record per page. Documented because that is how it behaves, not because it is desirable. 2. Internal links are not supported, and are REFUSED with -20601. The branch that would write the /Dest was left commented out in the original port and never came back; emitting it as it stood produced an /Annot with an open dictionary, that is, a malformed file. Since September 2026 the call raises an error instead of writing the broken file. Use a URL.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20601` | destination is not a URL -- internal link or NULL |

#### Example

```sql
PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
```

**See also:** [AddLink](#addlink) · [SetLink](#setlink)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `plink` | NUMBER | — | Link identifier. The value returned by AddLink |
| `py` | NUMBER | `0` | Vertical destination on the page. Number in the unit set by Init (mm, cm, pt or in); 0 (default) = top of the page |
| `ppage` | NUMBER | `-1` | Destination page. Page number; -1 (default) = the current page |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20601` | internal link is not implemented |

#### Example

```sql
-- Use URL:
PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
```

**See also:** [AddLink](#addlink)

---

## Header and footer

### Footer

Footer extension point, called internally as each page is closed.

#### Syntax

```sql
PROCEDURE PL_FPDF.Footer;
```

#### Example

```sql
PL_FPDF.SetFooterProc('MY_PKG.FOOTER');       -- the rest is automatic
```

**See also:** [SetFooterProc](#setfooterproc)

---

### Header

Header extension point, called internally on every new page.

#### Syntax

```sql
PROCEDURE PL_FPDF.Header;
```

#### Example

```sql
PL_FPDF.SetHeaderProc('MY_PKG.HEADER');       -- the rest is automatic
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `palias` | VARCHAR2 | `'{nb}'` | Placeholder to replace. Any text; '{nb}' is the default |

#### Example

```sql
PL_FPDF.SetAliasNbPages;
PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo || ' of {nb}');
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `footerprocname` | VARCHAR2 | — | Qualified name of the procedure. 'package.procedure' or 'procedure' |
| `paramTable` | TV4000A | `noParam` | Parameters passed on to the procedure, by name. PL_FPDF.tv4000a — an associative array INDEXED BY THE NAME of your procedure's parameter: l_p('p_title') := 'Report'. There is no tv4000a(...) constructor: declare a variable and fill it by key. noParam (default) = called with no parameters |

#### Example

```sql
PL_FPDF.SetFooterProc('MY_PKG.FOOTER');
```

**See also:** [SetHeaderProc](#setheaderproc) · [SetAliasNbPages](#setaliasnbpages) · [Footer](#footer)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `headerprocname` | VARCHAR2 | — | Qualified name of the procedure. 'package.procedure' or 'procedure'; it must be reachable by the database user |
| `paramTable` | TV4000A | `noParam` | Parameters passed on to the procedure, by name. PL_FPDF.tv4000a — an associative array INDEXED BY THE NAME of your procedure's parameter: l_p('p_title') := 'Report'. There is no tv4000a(...) constructor: declare a variable and fill it by key. noParam (default) = called with no parameters |

#### Example

```sql
PL_FPDF.SetHeaderProc('MY_PKG.HEADER');
```

**See also:** [SetFooterProc](#setfooterproc) · [Header](#header)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_x` | NUMBER | — | X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `p_y` | NUMBER | — | Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `p_width` | NUMBER | — | Total width of the code. Number in the unit set by Init (mm, cm, pt or in) |
| `p_height` | NUMBER | — | Height of the bars. Number in the unit set by Init (mm, cm, pt or in) |
| `p_code` | VARCHAR2 | — | Data to encode. It must match the chosen symbology: EAN13 = 13 digits; EAN8 = 8 digits; ITF = any even number of digits (a Brazilian bank slip uses 44); ITF14 = 14 digits; CODE39 = uppercase alphanumeric; CODE128 = ASCII |
| `p_type` | VARCHAR2 | `'CODE128'` | Barcode symbology. 'CODE128' (default), 'CODE39', 'EAN13', 'EAN8', 'ITF' or 'ITF14' |
| `p_show_text` | BOOLEAN | `true` | Prints the readable value below the bars. TRUE or FALSE; TRUE is the default |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20880` | empty code |
| `ORA-20882` | unsupported symbology |
| `ORA-20881` | width or height is not positive |
| `ORA-20883` | CODE39 does not accept the given character |
| `ORA-20884` | CODE128 accepts only ASCII 32 to 126 |
| `ORA-20885` | EAN with the wrong number of digits |
| `ORA-20886` | EAN with an invalid check digit |
| `ORA-20887` | ITF14 requires 13 digits (check digit computed) or 14 |
| `ORA-20888` | ITF with no digit in the content |

#### Example

```sql
PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_x` | NUMBER | — | X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `p_y` | NUMBER | — | Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in) |
| `p_size` | NUMBER | — | Side of the QR code ( width = height). Number in the unit set by Init (mm, cm, pt or in) |
| `p_data` | VARCHAR2 | — | Content to encode. Up to 2953 bytes in binary mode; the content must follow the format chosen in p_format |
| `p_format` | VARCHAR2 | `'TEXT'` | Content format, which tells readers how to interpret the code. 'TEXT' (default, free text), 'URL', 'PIX', 'VCARD', 'WIFI' or 'EMAIL' |
| `p_error_correction` | VARCHAR2 | `'M'` | Error-correction level: the higher it is, the better the code survives dirt and creases, and the less data fits. 'L' (7%), 'M' (15%, default), 'Q' (25%) or 'H' (30%) |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20870` | empty content |
| `ORA-20872` | invalid error-correction level |
| `ORA-20871` | size is not positive |
| `ORA-20873` | content beyond the QR Code capacity |

#### Example

```sql
PL_FPDF.AddQRCode(50, 50, 40, 'https://example.com', 'URL', 'M');
```

**See also:** [AddBarcode](#addbarcode)

---

## Metadata and document setup

### GetDocumentMetadata

Returns the metadata currently set on the document.

#### Syntax

```sql
FUNCTION PL_FPDF.GetDocumentMetadata RETURN JSON_OBJECT_T;
```

#### Returns

JSON_OBJECT_T — object with title, subject, author, keywords, creator and the remaining options. **See also:** [SetDocumentConfig](#setdocumentconfig)

#### Note

JSON structure: { "pageCount": <number>, "title": "<string>", "author": "<string>", "subject": "<string>", "keywords": "<string>", "format": "<string>", "orientation": "<string>", "unit": "<string>", "initialized": <boolean> }

#### Example

```sql
DECLARE
  l_meta JSON_OBJECT_T;
BEGIN
  l_meta := PL_FPDF.GetDocumentMetadata();
  DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
END;
```

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

### GetPageInfo

Returns information about a page of the document being built.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPageInfo(
    p_page_number pls_integer DEFAULT null) RETURN JSON_OBJECT_T;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | `null` | Page to query. Integer >= 1, up to GetPageCount; NULL (default) = the current page |

#### Returns

JSON_OBJECT_T — width, height, orientation and rotation of the page. **See also:** [GetCurrentPage](#getcurrentpage), [GetPDFInfo](#getpdfinfo)

#### Note

JSON structure: { "number": <number>, "format": "<string>", "orientation": "<string>", "width": <number>, "height": <number>, "unit": "<string>" }

#### Errors

| Code | When |
|--------|--------|
| `ORA-20106` | the page does not exist |
| `ORA-20812` | page number out of range |

#### Example

```sql
DECLARE
  l_page_info JSON_OBJECT_T;
BEGIN
  l_page_info := PL_FPDF.GetPageInfo(1);
  DBMS_OUTPUT.PUT_LINE('Width: ' || l_page_info.get_Number('width'));
END;
```

**See also:** [GetCurrentPage](#getcurrentpage) · [GetPDFInfo](#getpdfinfo)

---

### SetAuthor

Sets the document author in the metadata.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetAuthor(
    pauthor varchar2);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pauthor` | VARCHAR2 | — | Author. Any VARCHAR2 |

#### Example

```sql
PL_FPDF.SetAuthor('Finance Department');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_compress` | BOOLEAN | `false` | Enables compression. TRUE or FALSE; FALSE is the default |

#### Example

```sql
PL_FPDF.SetCompression(TRUE);
```

**See also:** [FlateEncode](#flateencode) · [FlateDecode](#flatedecode)

---

### SetCreator

Sets the creating application in the document metadata.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetCreator(
    pcreator varchar2);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pcreator` | VARCHAR2 | — | Name of the generating system. Any VARCHAR2 |

#### Example

```sql
PL_FPDF.SetCreator('ERP - billing module');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `zoom` | VARCHAR2 | — | Initial zoom level. 'fullpage' (whole page), 'fullwidth' (page width), 'real' (100%), 'default', or a number standing for the percentage |
| `layout` | VARCHAR2 | `'continuous'` | Page layout. 'continuous' (default), 'single', 'two' or 'default' |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | unknown zoom or layout mode |

#### Example

```sql
PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_config` | JSON_OBJECT_T | — | Document configuration. JSON_OBJECT_T with the optional keys: title, subject, author, keywords, creator, compression (boolean) |

#### Note

JSON keys: - title, author, subject, keywords, creator (document metadata) - orientation ('P' or 'L'), unit ('mm','cm','in','pt'), format (page format) - fontFamily, fontSize, fontStyle (default font) - leftMargin, topMargin, rightMargin (margins, in the current unit)

#### Errors

| Code | When |
|--------|--------|
| `ORA-20001` | invalid orientation; only P or L |
| `ORA-20002` | invalid unit; only mm, cm, in or pt |

#### Example

```sql
DECLARE
  l_config JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_config.put('title', 'Monthly Report');
  l_config.put('author', 'Maxwell Oliveira');
  l_config.put('orientation', 'P');
  l_config.put('format', 'A4');
  PL_FPDF.SetDocumentConfig(l_config);
END;
```

**See also:** [GetDocumentMetadata](#getdocumentmetadata) · [SetTitle](#settitle)

---

### SetKeywords

Sets the document keywords, which help search and indexing.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetKeywords(
    pkeywords varchar2);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pkeywords` | VARCHAR2 | — | Keywords. Free text, usually comma separated |

#### Example

```sql
PL_FPDF.SetKeywords('production report 2026');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `psubject` | VARCHAR2 | — | Subject. Any VARCHAR2 |

#### Example

```sql
PL_FPDF.SetSubject('Monthly close');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `ptitle` | VARCHAR2 | — | Title. Any VARCHAR2 |

#### Example

```sql
PL_FPDF.SetTitle('Production Report');
```

**See also:** [SetDocumentConfig](#setdocumentconfig)

---

## Document output

### ClosePDF

Closes the document structure (advanced use; the output APIs already do it).

#### Syntax

```sql
PROCEDURE PL_FPDF.ClosePDF;
```

#### Example

```sql
PL_FPDF.ClosePDF;
```

**See also:** [OutputBlob](#outputblob)

---

### OpenPDF

Explicitly opens the document structure (advanced use; Init already does it).

#### Syntax

```sql
PROCEDURE PL_FPDF.OpenPDF;
```

#### Example

```sql
PL_FPDF.OpenPDF;
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pname` | VARCHAR2 | `null` | File or document name. Any VARCHAR2 |
| `pdest` | VARCHAR2 | `null` | Destination. 'S', 'D', 'I' or 'F' |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | unknown destination, or a failure while writing |
| `ORA-20306` | delivering straight to the browser is no longer supported; the message points to OutputBlob and the Content-Type header |

#### Example

```sql
PL_FPDF.Output('report.pdf', 'F');
```

**See also:** [OutputBlob](#outputblob) · [OutputFile](#outputfile)

---

### OutputBlob

Synonym of OutputBlob: finalises the document and returns the PDF as a BLOB.

#### Syntax

```sql
FUNCTION PL_FPDF.OutputBlob RETURN BLOB;
```

#### Returns

BLOB — the PDF content. **See also:** [OutputBlob](#outputblob)

#### Errors

| Code | When |
|--------|--------|
| `ORA-20005` | Init has not been called yet. Before August 2026 this call carried on and returned an empty PDF, without pointing to the cause. |

#### Example

```sql
l_pdf := PL_FPDF.OutputBlob;
INSERT INTO documentos (id, arquivo) VALUES (1, l_pdf);
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_filename` | VARCHAR2 | — | Name of the output file. E.g. 'report.pdf' |
| `p_directory` | VARCHAR2 | `'PDF_DIR'` | Oracle DIRECTORY with write permission. Default: 'PDF_DIR' |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20401` | invalid directory |
| `ORA-20402` | no write permission |
| `ORA-20403` | write failure |

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
    pdest varchar2 DEFAULT null) RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pname` | VARCHAR2 | `null` | Logical name of the document. Any VARCHAR2 NULL = no name |
| `pdest` | VARCHAR2 | `null` | FPDF-style destination. 'S' (string/BLOB), 'D' (download), 'I' (inline), 'F' (file) |

#### Returns

BLOB — the PDF content. **See also:** [OutputBlob](#outputblob)

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | failure closing or assembling the document, with the original stack preserved |

#### Example

```sql
l_pdf := PL_FPDF.OutputBlob;    -- prefira esta
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_text` | VARCHAR2 | — | Watermark text. Any VARCHAR2, e.g. 'CONFIDENTIAL' |
| `p_opacity` | NUMBER | `0.3` | Opacity of the mark. 0.0 (invisible) to 1.0 (opaque); 0.3 is the default |
| `p_rotation` | NUMBER | `45` | Text angle in degrees. 0 to 360; 45 (diagonal) is the default |
| `p_pages` | VARCHAR2 | `'ALL'` | Pages that receive the mark. 'ALL' (default), or a list/ranges such as '1', '1,3,5', '2-8', '1,3-5,10' |
| `p_font` | VARCHAR2 | `'Helvetica'` | Font used. 'Helvetica' (default), 'Arial', 'Times' or 'Courier' |
| `p_size` | NUMBER | `48` | Font size in points. Number > 0; 48 is the default |
| `p_color` | VARCHAR2 | `'gray'` | Colour of the watermark. 'gray' (default), 'red', 'blue', 'green', 'black', or an RGB hex value such as 'FF0000' |

#### Note

Drawn by OutputModifiedPDF() into the content stream: each affected page gets a content object of its own and a /Resources of its own, so a /Resources shared between pages is never contaminated. Centred and rotated around the centre of the page; the font is always Helvetica.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |
| `ORA-20816` | watermark text is empty |
| `ORA-20817` | opacity outside 0..1 |
| `ORA-20818` | rotation outside 0, 45, 90, 135, 180, 225, 270, 315 |

#### Example

```sql
PL_FPDF.LoadPDF(l_pdf);
-- every page
PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
-- specific pages
PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
-- Estilo personalizado
PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1', 'Helvetica', 72, 'green');
```

**See also:** [GetWatermarks](#getwatermarks) · [OverlayText](#overlaytext) · [OutputModifiedPDF](#outputmodifiedpdf)

---

### ClearPDFCache

Discards the loaded PDFs and frees the memory used by manipulation.

#### Syntax

```sql
PROCEDURE PL_FPDF.ClearPDFCache;
```

#### Note

Always call it after processing a PDF to release memory. It clears: the loaded PDF, page info, rotations, removed pages and watermarks.

#### Example

```sql
PL_FPDF.LoadPDF(l_pdf);
-- Processar PDF
l_modified := PL_FPDF.OutputModifiedPDF();
-- release the memory
PL_FPDF.ClearPDFCache();
```

**See also:** [LoadPDF](#loadpdf) · [UnloadPDF](#unloadpdf)

---

### FlateDecode

Decompresses a PDF /FlateDecode stream (zlib, RFC 1950). Implemented in pure PL/SQL, because UTL_COMPRESS will not do: it only accepts a gzip trailer with a correct CRC-32, and that CRC is of the DECOMPRESSED content — to know it you would have to decompress first. Useful in its own right, and it is what lets the copier read cross-reference streams and object streams.

#### Syntax

```sql
FUNCTION PL_FPDF.FlateDecode(
    p_stream    BLOB,
    p_max_bytes PLS_INTEGER DEFAULT 8388608) RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_stream` | BLOB | — | Compressed stream. BLOB with zlib data — what the PDF marks as /FlateDecode |
| `p_max_bytes` | PLS_INTEGER | `8388608` | Output ceiling, in bytes. Number > 0; 8388608 (8 MB) is the default. A compressed stream is UNTRUSTED input: a few KB can expand into gigabytes (a zip bomb) and bring the session down with ORA-04036. With the ceiling it raises -20893 and says where it stopped |

#### Returns

BLOB — the decompressed content.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20890` | truncated stream |
| `ORA-20891` | malformed DEFLATE data |
| `ORA-20892` | invalid zlib header |
| `ORA-20893` | output exceeded p_max_bytes |

#### Example

```sql
l_claro := PL_FPDF.FlateDecode(l_comprimido);
```

**See also:** [LoadPDF](#loadpdf)

---

### FlateEncode

Compresses data into a PDF /FlateDecode stream (zlib, RFC 1950). Written in pure PL/SQL: a single block with FIXED Huffman and greedy LZ77 — it compresses less than zlib's dynamic Huffman, and far more than nothing. When the data is incompressible it falls back to a stored block, so the output never exceeds the input plus the block overhead.

#### Syntax

```sql
FUNCTION PL_FPDF.FlateEncode(
    p_data BLOB) RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_data` | BLOB | — | Content to compress. BLOB of any size; NULL is treated as empty |

#### Returns

BLOB — zlib stream: header, DEFLATE and Adler-32. **See also:** [FlateDecode](#flatedecode), [SetCompression](#setcompression)

#### Example

```sql
l_comprimido := PL_FPDF.FlateEncode(l_claro);
```

**See also:** [FlateDecode](#flatedecode) · [SetCompression](#setcompression)

---

### GetActivePageCount

Returns how many pages will remain once the pending removals are applied.

#### Syntax

```sql
FUNCTION PL_FPDF.GetActivePageCount RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — pages not marked for removal. **See also:** [RemovePage](#removepage), [GetPageCount](#getpagecount)

#### Note

Differs from GetPageCount(), which returns the original count

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |

#### Example

```sql
l_total := PL_FPDF.GetPageCount();        -- Original: 10
PL_FPDF.RemovePage(2);
l_active := PL_FPDF.GetActivePageCount(); -- Ativas: 9
```

**See also:** [RemovePage](#removepage) · [GetPageCount](#getpagecount)

---

### GetPageCount

Returns the total page count of the loaded PDF, including the pages marked for removal.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPageCount RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — number of pages.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |

#### Example

```sql
l_pages := PL_FPDF.GetPageCount();
DBMS_OUTPUT.PUT_LINE('Total pages:' || l_pages);
```

**See also:** [LoadPDF](#loadpdf) · [GetActivePageCount](#getactivepagecount)

---

### GetPDFInfo

Returns information about the loaded PDF: version, metadata and page count.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPDFInfo RETURN JSON_OBJECT_T;
```

#### Returns

JSON_OBJECT_T — PDF version, title, author, page count and the remaining metadata.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |

#### Example

```sql
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetPDFInfo();
  DBMS_OUTPUT.PUT_LINE('Version:' || l_info.get_string('version'));
  DBMS_OUTPUT.PUT_LINE('Pages:' || l_info.get_number('pageCount'));
END;
```

**See also:** [LoadPDF](#loadpdf) · [GetPageInfo](#getpageinfo)

---

### GetWatermarks

Lists every watermark applied to the loaded PDF.

#### Syntax

```sql
FUNCTION PL_FPDF.GetWatermarks RETURN JSON_ARRAY_T;
```

#### Returns

JSON_ARRAY_T — objects with id, text, opacity, rotation, pageRange, font, fontSize and color.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |

#### Example

```sql
DECLARE
  l_watermarks JSON_ARRAY_T;
  l_watermark JSON_OBJECT_T;
BEGIN
  PL_FPDF.LoadPDF(l_pdf);
  PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
  l_watermarks := PL_FPDF.GetWatermarks();
  FOR i IN 0..l_watermarks.get_size() - 1 LOOP
    l_watermark := TREAT(l_watermarks.get(i) AS JSON_OBJECT_T);
    DBMS_OUTPUT.PUT_LINE('Watermark:' ||
                         l_watermark.get_string('text'));
  END LOOP;
END;
```

**See also:** [AddWatermark](#addwatermark)

---

### IsPageRemoved

Tells whether a page is marked for removal.

#### Syntax

```sql
FUNCTION PL_FPDF.IsPageRemoved(
    p_page_number PLS_INTEGER) RETURN BOOLEAN;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Page to query. Integer >= 1, up to GetPageCount |

#### Returns

BOOLEAN — TRUE if the page will be removed from the output. **See also:** [RemovePage](#removepage)

#### Example

```sql
IF PL_FPDF.IsPageRemoved(2) THEN
  DBMS_OUTPUT.PUT_LINE('Page 2 removed');
END IF;
```

**See also:** [RemovePage](#removepage)

---

### IsPDFModified

Tells whether there are pending changes — rotation, removal, watermark, overlay — on the loaded PDF.

#### Syntax

```sql
FUNCTION PL_FPDF.IsPDFModified RETURN BOOLEAN;
```

#### Returns

BOOLEAN — TRUE if there are changes not yet applied. **See also:** [OutputModifiedPDF](#outputmodifiedpdf)

#### Note

Use it to decide whether OutputModifiedPDF() has to be called

#### Example

```sql
IF PL_FPDF.IsPDFModified() THEN
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();
END IF;
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf_blob` | BLOB | — | PDF document to load. Non-null BLOB with a valid %PDF header |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20800` | PDF is null, or too small to hold a header and a trailer |
| `ORA-20801` | invalid PDF header |
| `ORA-20802` | startxref not found |
| `ORA-20803` | invalid xref table |
| `ORA-20804` | Root object not found |

#### Example

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
  PL_FPDF.LoadPDF(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Pages:' || PL_FPDF.GetPageCount());
END;
```

**See also:** [LoadPDFWithID](#loadpdfwithid) · [GetPageCount](#getpagecount) · [OutputModifiedPDF](#outputmodifiedpdf) · [ClearPDFCache](#clearpdfcache)

---

### OutputModifiedPDF

Produces the PDF with the changes applied, copying the kept pages object by object: content, fonts, images and annotations arrive intact, with no re-rendering. It applies RemovePage and RotatePage, and draws watermarks and text and image overlays into the content stream: every affected page gets a content object and a /Resources of its own.

#### Syntax

```sql
FUNCTION PL_FPDF.OutputModifiedPDF RETURN BLOB;
```

#### Returns

BLOB — the modified PDF.

#### Process

1. Checks that a PDF is loaded and modified 2. Indexes the source (xref chain + flattened page tree) 3. Selects the pages not marked by RemovePage, in the original order 4. Copies every object reachable from those pages, renumbering the indirect references; stream payloads are copied byte for byte 5. Emits a new Catalog, a new /Pages node, xref and trailer

#### Limitation

Watermarks and both text and image overlays are all drawn. Cross-reference streams and object streams (PDF 1.5+) are read, including with the PNG predictor; a malformed one raises -20843/-20847/-20848.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |
| `ORA-20819` | the PDF has not been modified (no changes to apply) |
| `ORA-20820` | every page was removed (an empty PDF cannot be generated) |
| `ORA-20841` | object dictionary too large to renumber |
| `ORA-20843` | malformed cross-reference stream |
| `ORA-20847` | malformed object stream |
| `ORA-20848` | unsupported predictor in the cross-reference stream |
| `ORA-20823` | invalid or unsupported image. PNG with alpha and interlaced PNG are supported; refused are interlaced below 8 bits per component, indexed AND interlaced, and images above 4 megapixels on the path that reprocesses pixels |
| `ORA-20846` | the page /Resources cannot be overlaid (shared indirect sub-dictionary) |

#### Example

```sql
DECLARE
  l_pdf BLOB;
  l_modified_pdf BLOB;
BEGIN
  -- Carregar PDF
  SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
  -- apply the changes
  PL_FPDF.RotatePage(1, 90);
  PL_FPDF.RemovePage(3);
  -- Gerar PDF modificado
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();
  -- Salvar PDF modificado
  UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
  PL_FPDF.ClearPDFCache();
END;
```

**See also:** [LoadPDF](#loadpdf) · [ClearPDFCache](#clearpdfcache)

---

### RemovePage

Marks a page of the loaded PDF for removal. The deletion is logical: it is only applied by OutputModifiedPDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.RemovePage(
    p_page_number PLS_INTEGER);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Page to remove. Integer >= 1, up to GetPageCount |

#### Note

The page is marked for removal. Use OutputModifiedPDF() to produce the modified PDF

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |
| `ORA-20812` | page number out of range |
| `ORA-20814` | the page was already marked for removal |
| `ORA-20810` | /Pages not found in the PDF catalog |

#### Example

```sql
PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.RemovePage(2);  -- remove page 2
PL_FPDF.RemovePage(5);  -- remove page 5
```

**See also:** [IsPageRemoved](#ispageremoved) · [GetActivePageCount](#getactivepagecount) · [OutputModifiedPDF](#outputmodifiedpdf)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Page to rotate. Integer >= 1, up to GetPageCount |
| `p_rotation` | NUMBER | — | Rotation angle applied. 0, 90, 180 or 270 |

#### Note

Changes are kept in memory. Use OutputModifiedPDF() to produce the PDF

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded -- call LoadPDF first |
| `ORA-20813` | invalid rotation; only 0, 90, 180 or 270 |
| `ORA-20810` | /Pages not found in the PDF catalog |

#### Example

```sql
PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.RotatePage(1, 90);    -- rotate page 1
PL_FPDF.RotatePage(2, 180);   -- rotate page 2
```

**See also:** [LoadPDF](#loadpdf) · [RemovePage](#removepage) · [OutputModifiedPDF](#outputmodifiedpdf)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | `NULL` | Page to clear. Integer >= 1, up to GetPageCount; NULL (default) clears every page |

#### Example

```sql
-- clear every overlay
PL_FPDF.ClearOverlays();
-- clear only those on page 1
PL_FPDF.ClearOverlays(1);
```

**See also:** [RemoveOverlay](#removeoverlay) · [GetOverlays](#getoverlays)

---

### GetOverlays

Lists the overlays applied, optionally filtered by page.

#### Syntax

```sql
FUNCTION PL_FPDF.GetOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL) RETURN JSON_ARRAY_T;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | `NULL` | Page filter. Integer >= 1, up to GetPageCount; NULL (default) returns the overlays of every page |

#### Returns

JSON_ARRAY_T — objects with overlayId, overlayType ('TEXT' or 'IMAGE'), pageNumber, x, y, content, opacity, rotation and zOrder.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded |

#### Example

```sql
DECLARE
  l_overlays JSON_ARRAY_T;
  l_overlay JSON_OBJECT_T;
BEGIN
  l_overlays := PL_FPDF.GetOverlays(1);  -- Page 1 overlays
  FOR i IN 0..l_overlays.get_size() - 1 LOOP
    l_overlay := TREAT(l_overlays.get(i) AS JSON_OBJECT_T);
    DBMS_OUTPUT.PUT_LINE('Type: ' || l_overlay.get_string('overlayType'));
  END LOOP;
END;
```

**See also:** [OverlayText](#overlaytext) · [RemoveOverlay](#removeoverlay)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Page that receives the image. Integer >= 1, up to GetPageCount |
| `p_image_blob` | BLOB | — | Image content. BLOB in JPEG or PNG format |
| `p_x` | NUMBER | — | X position in PDF points. 0 to 612 on A4 portrait |
| `p_y` | NUMBER | — | Y position in PDF points, from the bottom. 0 to 792 on A4 portrait |
| `p_width` | NUMBER | `NULL` | Width in points. Number > 0; NULL (default) uses the original width |
| `p_height` | NUMBER | `NULL` | Height in points. Number > 0; NULL (default) uses the original height, or keeps the aspect ratio |
| `p_options` | JSON_OBJECT_T | `NULL` | Image settings. JSON_OBJECT_T with the optional keys: opacity (0.0-1.0), rotation (0-360), maintainAspect (true/false), scaleToFit (true/false), zOrder (integer) |

#### Note

Options (JSON_OBJECT_T): { "opacity": 1.0, // Opacity 0.0 to 1.0 "rotation": 0, // Rotation angle "maintainAspect": true, // Keep the aspect ratio "scaleToFit": false, // Scale to fit "zOrder": 100 // Layer order }

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded |
| `ORA-20810` | invalid page number |
| `ORA-20821` | invalid position coordinates |
| `ORA-20823` | invalid image format -- only JPEG or PNG |
| `ORA-20824` | invalid image dimensions |

#### Example

```sql
DECLARE
  l_logo BLOB;
  l_options JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
  -- add a logo in the top right corner
  PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
  -- a watermark with transparency
  l_options.put('opacity', 0.3);
  l_options.put('rotation', 45);
  PL_FPDF.OverlayImage(1, l_watermark, 200, 400, 300, NULL, l_options);
  l_modified := PL_FPDF.OutputModifiedPDF();
END;
```

**See also:** [OverlayText](#overlaytext) · [Image](#image) · [GetOverlays](#getoverlays)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Page that receives the text. Integer >= 1, up to GetPageCount |
| `p_text` | VARCHAR2 | — | Text to overlay. Any VARCHAR2 |
| `p_x` | NUMBER | — | X position in PDF points (1 pt = 1/72 in), from the left. 0 to 612 on A4 portrait |
| `p_y` | NUMBER | — | Y position in PDF points, from the bottom of the page. 0 to 792 on A4 portrait |
| `p_options` | JSON_OBJECT_T | `NULL` | Visual settings of the text. JSON_OBJECT_T with the optional keys: font ('Helvetica'/'Arial', 'Times' or 'Courier'; any other name falls back to Helvetica), fontSize (number, 12), color (RGB hex, '000000'), opacity (0.0-1.0), rotation (0-360), align ('left', 'center', 'right'), width (box width in points: sets the line breaking and the reference for align), bold (true/false), zOrder (integer; higher goes on top, being drawn last) |

#### Note

Options (JSON_OBJECT_T): { "font": "Helvetica", // Font name "fontSize": 12, // Font size "color": "000000", // RGB colour in hex "opacity": 1.0, // Opacity 0.0 to 1.0 "rotation": 0, // Rotation angle (0-360) "align": "left", // left, center, right "width": null, // maximum width (wraps on its own) "bold": false, // Bold text "zOrder": 100 // layer order (higher goes on top) }

#### Errors

| Code | When |
|--------|--------|
| `ORA-20809` | no PDF loaded |
| `ORA-20810` | invalid page number |
| `ORA-20821` | invalid position coordinates, or opacity outside 0.0..1.0 |

#### Example

```sql
DECLARE
  l_options JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  PL_FPDF.LoadPDF(l_pdf);
  -- a plain overlay
  PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
  -- formatted text
  l_options.put('font', 'Helvetica-Bold');
  l_options.put('fontSize', 24);
  l_options.put('color', 'FF0000');  -- Vermelho
  l_options.put('opacity', 0.8);
  l_options.put('rotation', 45);
  PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
  l_modified := PL_FPDF.OutputModifiedPDF();
END;
```

**See also:** [OverlayImage](#overlayimage) · [GetOverlays](#getoverlays) · [AddWatermark](#addwatermark)

---

### RemoveOverlay

Removes one specific overlay by its identifier.

#### Syntax

```sql
PROCEDURE PL_FPDF.RemoveOverlay(
    p_overlay_id VARCHAR2);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_overlay_id` | VARCHAR2 | — | Overlay identifier. The overlayId value returned by GetOverlays, e.g. 'OVL_001' |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20825` | overlay not found |

#### Example

```sql
PL_FPDF.RemoveOverlay('OVL_001');
```

**See also:** [GetOverlays](#getoverlays) · [ClearOverlays](#clearoverlays)

---

## Multi-PDF (merge, split, extract)

### ExtractPages

Creates a new PDF holding only the selected pages of a loaded document. The requested order is honoured and a page may repeat; only the objects reachable from the chosen pages are copied, so the result is smaller than the source.

#### Syntax

```sql
FUNCTION PL_FPDF.ExtractPages(
    p_pdf_id  VARCHAR2,
    p_pages   VARCHAR2,
    p_options JSON_OBJECT_T DEFAULT NULL) RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identifier of the source document. The same one used in LoadPDFWithID |
| `p_pages` | VARCHAR2 | — | Pages to extract. Comma-separated list and ranges, e.g. '1', '1,5,9', '1,5-10,15', '5,1' (reversed order) or 'ALL' |
| `p_options` | JSON_OBJECT_T | `NULL` | Extraction options. Optional JSON_OBJECT_T; keys reserved for future use |

#### Returns

BLOB — PDF with the extracted pages.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20831` | PDF id not found |
| `ORA-20838` | invalid page specification |
| `ORA-20839` | page number out of range |
| `ORA-20841` | object dictionary too large to renumber |
| `ORA-20843` | malformed cross-reference stream |
| `ORA-20847` | malformed object stream |
| `ORA-20848` | unsupported predictor in the cross-reference stream |

#### Example

```sql
DECLARE
  l_extracted BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
  -- extract pages 1, 5-10 and 15
  l_extracted := PL_FPDF.ExtractPages('manual', '1,5-10,15', NULL);
  INSERT INTO documents VALUES ('Summary', l_extracted);
END;
```

**See also:** [SplitPDF](#splitpdf) · [MergePDFs](#mergepdfs)

---

### GetLoadedPDFs

Lists the documents currently loaded under an identifier.

#### Syntax

```sql
FUNCTION PL_FPDF.GetLoadedPDFs RETURN JSON_ARRAY_T;
```

#### Returns

JSON_ARRAY_T — objects with the id and the information of each loaded PDF. **See also:** [LoadPDFWithID](#loadpdfwithid), [UnloadPDF](#unloadpdf)

#### Example

```sql
DECLARE
  l_pdfs JSON_ARRAY_T;
  l_pdf JSON_OBJECT_T;
BEGIN
  l_pdfs := PL_FPDF.GetLoadedPDFs();
  FOR i IN 0..l_pdfs.get_size() - 1 LOOP
    l_pdf := TREAT(l_pdfs.get(i) AS JSON_OBJECT_T);
    DBMS_OUTPUT.PUT_LINE('PDF: ' || l_pdf.get_string('pdfId'));
  END LOOP;
END;
```

**See also:** [LoadPDFWithID](#loadpdfwithid) · [UnloadPDF](#unloadpdf)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identifier of the document within the session. Unique text, e.g. 'cover', 'annex1' |
| `p_pdf_blob` | BLOB | — | Document to load. BLOB with a valid PDF |

#### Note

At most 10 PDFs can be loaded at the same time

#### Errors

| Code | When |
|--------|--------|
| `ORA-20828` | PDF id already loaded |
| `ORA-20829` | maximum number of loaded PDFs exceeded (10) |
| `ORA-20830` | identifier empty or too long |
| `ORA-20800` | PDF is null or too small to be valid |
| `ORA-20801` | %PDF-x.x header missing or malformed |

#### Example

```sql
BEGIN
  PL_FPDF.LoadPDFWithID('report_jan', l_jan_pdf);
  PL_FPDF.LoadPDFWithID('report_feb', l_feb_pdf);
  PL_FPDF.LoadPDFWithID('report_mar', l_mar_pdf);
END;
```

**See also:** [MergePDFs](#mergepdfs) · [SplitPDF](#splitpdf) · [ExtractPages](#extractpages) · [UnloadPDF](#unloadpdf) · [GetLoadedPDFs](#getloadedpdfs)

---

### MergePDFs

Merges several loaded PDFs into a single document, in the order given. The objects of each source — pages, fonts, images, annotations — are copied with their indirect references renumbered: nothing is re-rendered and the original content arrives intact. The same identifier may appear more than once.

#### Syntax

```sql
FUNCTION PL_FPDF.MergePDFs(
    p_pdf_ids JSON_ARRAY_T,
    p_options JSON_OBJECT_T DEFAULT NULL) RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf_ids` | JSON_ARRAY_T | — | Identifiers of the documents, in the desired order. JSON_ARRAY_T of strings, e.g. JSON_ARRAY_T('["cover","body","annex"]') |
| `p_options` | JSON_OBJECT_T | `NULL` | Merge options. Optional JSON_OBJECT_T; keys reserved for future use |

#### Returns

BLOB — the merged PDF.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20832` | no PDF id was given |
| `ORA-20833` | a PDF id in the list is not loaded |
| `ORA-20834` | merge failed |
| `ORA-20841` | object dictionary too large to renumber |
| `ORA-20843` | malformed cross-reference stream |
| `ORA-20847` | malformed object stream |
| `ORA-20848` | unsupported predictor in the cross-reference stream |

#### Example

```sql
DECLARE
  l_merged BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('jan', l_jan_pdf);
  PL_FPDF.LoadPDFWithID('feb', l_feb_pdf);
  PL_FPDF.LoadPDFWithID('mar', l_mar_pdf);
  l_merged := PL_FPDF.MergePDFs(
    JSON_ARRAY_T('["jan","feb","mar"]'),
    NULL
  );
  INSERT INTO reports VALUES ('Q1_2026', l_merged);
END;
```

**See also:** [LoadPDFWithID](#loadpdfwithid) · [SplitPDF](#splitpdf) · [ExtractPages](#extractpages)

---

### SplitPDF

Splits a loaded PDF into several documents, following the ranges given. Each part carries only the objects reachable from its own pages, which is why it ends up far smaller than the source. The ranges may not overlap.

#### Syntax

```sql
FUNCTION PL_FPDF.SplitPDF(
    p_pdf_id      VARCHAR2,
    p_page_ranges JSON_ARRAY_T) RETURN JSON_ARRAY_T;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identifier of the document to split. The same one used in LoadPDFWithID |
| `p_page_ranges` | JSON_ARRAY_T | — | Ranges defining each part produced. JSON_ARRAY_T of strings: '1-10', '11-20', '5' (a single page), '1,3,5' (a list) or 'ALL' |

#### Returns

JSON_ARRAY_T — one entry per range, with the part's PDF in base64, without line breaks.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20831` | PDF id not found |
| `ORA-20835` | no range was given |
| `ORA-20836` | overlapping ranges |
| `ORA-20838` | invalid page specification |
| `ORA-20839` | page number out of range |
| `ORA-20843` | malformed cross-reference stream |
| `ORA-20847` | malformed object stream |
| `ORA-20848` | unsupported predictor in the cross-reference stream |

#### Example

```sql
DECLARE
  l_split_pdfs JSON_ARRAY_T;
  l_part CLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('contract', l_contract_pdf);
  l_split_pdfs := PL_FPDF.SplitPDF('contract',
    JSON_ARRAY_T('["1-5", "6-10", "11-15"]')
  );
  FOR i IN 0..l_split_pdfs.get_size() - 1 LOOP
    l_part := l_split_pdfs.get_string(i);
    -- process each part
  END LOOP;
END;
```

**See also:** [ExtractPages](#extractpages) · [MergePDFs](#mergepdfs)

---

### UnloadPDF

Drops from memory a document loaded by LoadPDFWithID.

#### Syntax

```sql
PROCEDURE PL_FPDF.UnloadPDF(
    p_pdf_id VARCHAR2);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Document identifier. The same one used in LoadPDFWithID |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20831` | PDF id not found |

#### Example

```sql
PL_FPDF.UnloadPDF('report_jan');
```

**See also:** [LoadPDFWithID](#loadpdfwithid) · [ClearPDFCache](#clearpdfcache)

---

## Security and encryption

### DecryptPDF

Removes the protection from an encrypted PDF, given the right password. It supports RC4-40, RC4-128, AES-128 (AESV2) and AES-256 (AESV3), with either the user or the owner password. The filter is read from the document's /CFM, not assumed. A PDF 1.5+ source is flattened, and object streams are decrypted before being decompressed.

#### Syntax

```sql
FUNCTION PL_FPDF.DecryptPDF(
    p_pdf      BLOB,
    p_password VARCHAR2) RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | Encrypted document. BLOB with a protected PDF |
| `p_password` | VARCHAR2 | — | User or owner password. Text matching one of the document's passwords |

#### Returns

BLOB — the PDF without encryption.

#### Note

A PDF 1.5+ source is flattened, and the object streams are decrypted before being decompressed.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20853` | the PDF is not encrypted |
| `ORA-20854` | invalid password |
| `ORA-20855` | decryption failed |
| `ORA-20861` | /Encrypt dictionary not found in the PDF |
| `ORA-20857` | invalid PDF version |

#### Example

```sql
l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
```

**See also:** [EncryptPDF](#encryptpdf) · [IsEncrypted](#isencrypted)

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
    p_encryption     VARCHAR2 DEFAULT 'RC4-128') RETURN BLOB;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | Document to protect. BLOB with a valid, unencrypted PDF |
| `p_user_password` | VARCHAR2 | — | Password asked for when opening the document. Text; empty allows opening without a password while keeping the restrictions |
| `p_owner_password` | VARCHAR2 | `NULL` | Owner password, which allows changing permissions. Text; NULL (default) reuses the user password |
| `p_permissions` | JSON_OBJECT_T | `NULL` | Permissions granted to the reader. JSON_OBJECT_T with the boolean keys: print, modify, copy, annotate, fill_forms, extract, assemble, print_high. Missing keys take the restrictive default |
| `p_encryption` | VARCHAR2 | `'RC4-128'` | Encryption algorithm. 'AES-256' and 'AES-128' (recommended), 'RC4-128' (the default, kept for compatibility) or 'RC4-40' (legacy). RC4 has been broken for years and PDF 2.0 dropped it from the specification; recent readers warn about it or refuse it |

#### Returns

BLOB — the encrypted PDF.

#### Note

A PDF 1.5+ source (cross-reference streams, object streams) is flattened: the objects inside the object streams become top-level objects and the output carries a classic xref.

#### Errors

| Code | When |
|--------|--------|
| `ORA-20850` | invalid encryption method |
| `ORA-20851` | a password is required |
| `ORA-20852` | encryption failed |
| `ORA-20859` | the PDF is already encrypted; decrypt it first |
| `ORA-20860` | invalid PDF: /Root not found in the trailer |
| `ORA-20863` | empty RC4 key |
| `ORA-20864` | content above the limit this RC4 implementation handles |

#### Example

```sql
l_encrypted := PL_FPDF.EncryptPDF(
  p_pdf => l_pdf,
  p_user_password => 'user123',
  p_owner_password => 'owner456',
  p_permissions => JSON_OBJECT_T('{"print":true,"copy":false}'),
  p_encryption => 'AES-128'
);
```

**See also:** [DecryptPDF](#decryptpdf) · [IsEncrypted](#isencrypted) · [SetEncryption](#setencryption) · [SetPermissions](#setpermissions)

---

### GetPDFVersion

Returns the PDF version configured for the output.

#### Syntax

```sql
FUNCTION PL_FPDF.GetPDFVersion RETURN VARCHAR2;
```

#### Returns

VARCHAR2 — the version, e.g. '1.7'. **See also:** [SetPDFVersion](#setpdfversion)

**See also:** [SetPDFVersion](#setpdfversion)

---

### GetSecurityInfo

Returns the security details of an encrypted PDF.

#### Syntax

```sql
FUNCTION PL_FPDF.GetSecurityInfo(
    p_pdf BLOB) RETURN JSON_OBJECT_T;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | Document to inspect. BLOB with a valid PDF |

#### Returns

JSON_OBJECT_T — algorithm, key length and the permissions granted. **See also:** [IsEncrypted](#isencrypted), [EncryptPDF](#encryptpdf)

#### Example

```sql
l_info := PL_FPDF.GetSecurityInfo(l_pdf);
IF l_info.get_boolean('encrypted') THEN ...
```

**See also:** [IsEncrypted](#isencrypted) · [EncryptPDF](#encryptpdf)

---

### IsEncrypted

Checks whether a PDF is encrypted.

#### Syntax

```sql
FUNCTION PL_FPDF.IsEncrypted(
    p_pdf BLOB) RETURN BOOLEAN;
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | Document to check. BLOB with a valid PDF |

#### Returns

BOOLEAN — TRUE if the document carries encryption. **See also:** [GetSecurityInfo](#getsecurityinfo), [DecryptPDF](#decryptpdf)

#### Example

```sql
IF PL_FPDF.IsEncrypted(l_pdf) THEN ...
```

**See also:** [GetSecurityInfo](#getsecurityinfo) · [DecryptPDF](#decryptpdf)

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_encryption` | VARCHAR2 | — | Encryption algorithm. 'RC4-128' or 'RC4-40' |
| `p_user_password` | VARCHAR2 | — | Opening password. Text |
| `p_owner_password` | VARCHAR2 | `NULL` | Owner password. Text; NULL (default) = same as the user password |

#### Note

Version mapping: RC4-40/RC4-128 -> PDF 1.4 AES-128 -> PDF 1.5 AES-256 -> PDF 1.7

#### Errors

| Code | When |
|--------|--------|
| `ORA-20850` | unsupported encryption method |
| `ORA-20851` | invalid password |

#### Example

```sql
PL_FPDF.Init;
PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
PL_FPDF.AddPage;
l_pdf := PL_FPDF.OutputBlob;
```

**See also:** [SetPermissions](#setpermissions) · [EncryptPDF](#encryptpdf)

---

### SetPDFVersion

Sets the version declared in the header of the generated PDF.

#### Syntax

```sql
PROCEDURE PL_FPDF.SetPDFVersion(
    p_version VARCHAR2);
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_version` | VARCHAR2 | — | PDF file version. '1.4', '1.5', '1.6' or '1.7' |

#### Note

Features by version: 1.4: 128-bit RC4 encryption, transparency 1.5: 128-bit AES, object streams, cross-reference streams 1.6: 128-bit AES, OpenType fonts 1.7: 256-bit AES, XFA forms 2.0: 256-bit AES only, no RC4

#### Errors

| Code | When |
|--------|--------|
| `ORA-20857` | invalid PDF version; only 1.4, 1.5, 1.6, 1.7 or 2.0 |
| `ORA-20858` | AES-128 requires PDF 1.5 or higher, and AES-256 requires 1.7 |

#### Example

```sql
PL_FPDF.SetPDFVersion('1.5');
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_print` | BOOLEAN | `TRUE` | Allows printing. TRUE or FALSE; TRUE is the default |
| `p_modify` | BOOLEAN | `FALSE` | Allows changing the content. TRUE or FALSE; FALSE is the default |
| `p_copy` | BOOLEAN | `FALSE` | Allows copying text and images. TRUE or FALSE; FALSE is the default |
| `p_annotate` | BOOLEAN | `TRUE` | Allows adding comments and annotations. TRUE or FALSE; TRUE is the default |
| `p_fill_forms` | BOOLEAN | `TRUE` | Allows filling in form fields. TRUE or FALSE; TRUE is the default |
| `p_extract` | BOOLEAN | `FALSE` | Allows extracting content for accessibility. TRUE or FALSE; FALSE is the default |
| `p_assemble` | BOOLEAN | `FALSE` | Allows inserting, removing and rotating pages. TRUE or FALSE; FALSE is the default |
| `p_print_high` | BOOLEAN | `TRUE` | Allows high-resolution printing. TRUE or FALSE; TRUE is the default |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20856` | SetEncryption must be called first |

#### Example

```sql
PL_FPDF.SetEncryption('AES-128', 'user', 'owner');
PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE, p_modify => FALSE);
```

**See also:** [SetEncryption](#setencryption) · [EncryptPDF](#encryptpdf)

---

## Diagnostics and utilities

### DebugDisabled

Turns the debug messages off.

#### Syntax

```sql
PROCEDURE PL_FPDF.DebugDisabled;
```

#### Example

```sql
PL_FPDF.DebugDisabled;
```

**See also:** [SetLogLevel](#setloglevel)

---

### DebugEnabled

Turns the package's debug messages on.

#### Syntax

```sql
PROCEDURE PL_FPDF.DebugEnabled;
```

#### Example

```sql
PL_FPDF.DebugEnabled;
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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `pmsg` | VARCHAR2 | — | Error message. Any VARCHAR2 |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | always; that is what this routine does |

#### Example

```sql
PL_FPDF.Error('could not assemble the document');
```

---

### GetLogLevel

Returns the configured log level.

#### Syntax

```sql
FUNCTION PL_FPDF.GetLogLevel RETURN PLS_INTEGER;
```

#### Returns

PLS_INTEGER — the current level (0 to 4). **See also:** [SetLogLevel](#setloglevel)

#### Example

```sql
l_nivel := PL_FPDF.GetLogLevel;
```

**See also:** [SetLogLevel](#setloglevel)

---

### GetScaleFactor

Returns the conversion factor between the document's unit and PDF points.

#### Syntax

```sql
FUNCTION PL_FPDF.GetScaleFactor RETURN NUMBER;
```

#### Returns

NUMBER — the scale factor, e.g. 2.8346 for millimetres. **See also:** [Init](#init)

#### Example

```sql
l_pontos := 10 * PL_FPDF.GetScaleFactor;
```

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

| Parameter | Type | Default | Description |
|-----------|------|--------|-----------|
| `p_level` | PLS_INTEGER | — | Log level. 0 (off), 1 (error), 2 (warning), 3 (info) or 4 (debug) |

#### Errors

| Code | When |
|--------|--------|
| `ORA-20100` | level outside the 0..4 range |

#### Example

```sql
PL_FPDF.SetLogLevel(3);
```

**See also:** [GetLogLevel](#getloglevel) · [DebugEnabled](#debugenabled)

---

