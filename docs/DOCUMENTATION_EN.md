# PL_FPDF — Complete Usage Reference

**Version:** 3.3.0 | **Oracle:** 19c+ | **Licence:** MIT

> The official guide to everything PL_FPDF does: what each API is for and how to call it.
> Browsable version on the site: [maxwbh.github.io/pl_fpdf/en/api.html](https://maxwbh.github.io/pl_fpdf/en/api.html) ·
> Versão em português: [DOCUMENTATION.md](DOCUMENTATION.md)

## Index

1. [Installation and life cycle](#1-installation-and-life-cycle)
2. [Pages and positioning](#2-pages-and-positioning)
3. [Fonts and UTF-8](#3-fonts-and-utf-8)
4. [Writing text](#4-writing-text)
5. [Colours and drawing](#5-colours-and-drawing)
6. [Images](#6-images)
7. [Links](#7-links)
8. [Header and footer](#8-header-and-footer)
9. [QR Code and barcode](#9-qr-code-and-barcode)
10. [Metadata and document configuration](#10-metadata-and-document-configuration)
11. [Output (producing the PDF)](#11-output-producing-the-pdf)
12. [Editing an existing PDF](#12-editing-an-existing-pdf)
13. [Overlays (text/image on top of an existing PDF)](#13-overlays)
14. [Multi-PDF: merge, split and extraction](#14-multi-pdf-merge-split-and-extraction)
15. [Security and encryption](#15-security-and-encryption)
16. [Diagnostics and utilities](#16-diagnostics-and-utilities)
17. [Migrating from v0.9.4](#17-migrating-from-v094)
18. [Error codes](#18-error-codes)

---

## How to pass parameters

Every API accepts both PL/SQL notations:

```sql
-- Positional (the order of the signature)
PL_FPDF.Cell(0, 10, 'Hello', '1', 1, 'C');

-- Named (recommended: readable and immune to a change of order)
PL_FPDF.Cell(
  pw      => 0,        -- width; 0 = up to the right margin
  ph      => 10,       -- cell height
  ptxt    => 'Hello',
  pborder => '1',      -- '0' | '1' | any combination of 'L','T','R','B'
  pln     => 1,        -- 0 = cursor to the right | 1 = next line | 2 = below
  palign  => 'C'       -- 'L' | 'C' | 'R'
);

-- Mixed (positional first, named afterwards)
PL_FPDF.Cell(0, 10, 'Hello', palign => 'C');
```

Conventions that recur throughout the library:

| Convention | Meaning | Example |
|-----------|-------------|---------|
| Parameter with a `DEFAULT` | May be omitted | `AddPage()` = `AddPage(NULL, NULL, 0)` |
| Colours `r, g, b` | RGB 0–255; `r` alone = shade of grey | `SetFillColor(230, 230, 230)` |
| Measurements | In the unit given to `Init` (mm, cm, pt, in); width/height `0` = automatic/proportional | `Cell(0, 10, ...)`, `Image(..., pWidth => 40, pHeight => 0)` |
| Page ranges as `VARCHAR2` | Lists and intervals; `'ALL'` = every page; `'21-'` = to the end | `'1,3-5,10'` |
| Options in a `JSON_OBJECT_T` | Optional keys; absent ones take the default | `l_op.put('opacity', 0.5)` |
| Overlay coordinates | PDF points (1 pt = 1/72"), Y counting upwards | `OverlayText(1, 'OK', 400, 700)` |
| Booleans | PL/SQL `TRUE`/`FALSE` | `SetAutoPageBreak(TRUE, 15)` |

---

## 1. Installation and life cycle

Download `dist/pl_fpdf_install.sql` and run it: a single file, with both packages
in dependency order, and plain SQL only — it behaves the same in a PL/SQL
Developer SQL Window and in SQL\*Plus.

```sql
-- Check
SELECT PL_FPDF.co_version FROM DUAL;  -- 3.3.0

-- Both objects must come out VALID
SELECT object_name, object_type, status FROM user_objects
 WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL');
```

### Init — start a new document

```sql
PL_FPDF.Init(
  p_orientation => 'P',      -- 'P' portrait | 'L' landscape
  p_unit        => 'mm',     -- 'mm', 'cm', 'pt', 'in'
  p_format      => 'A4',     -- 'A4', 'A3', 'A5', 'Letter', 'Legal'
  p_encoding    => 'UTF-8'
);
```

Every document starts with `Init`. The state lives in the session (package-only,
no tables).

### Reset — clear everything

```sql
PL_FPDF.Reset;  -- frees temporary CLOBs and clears the state
```

Use it at the end of long-running jobs, or between documents in a loop.

### IsInitialized

```sql
IF NOT PL_FPDF.IsInitialized THEN PL_FPDF.Init; END IF;
```

---

## 2. Pages and positioning

| API | What it does |
|-----|-----------|
| `AddPage(p_orientation, p_format, p_rotation)` | New page; NULL parameters inherit from `Init`. Rotation: 0/90/180/270 |
| `SetPage(p_page_number)` | Go back to an existing page in order to write on it |
| `GetCurrentPage` / `PageNo` | Active page / running total |
| `SetMargins(left, top, right)` | Margins; also `SetLeftMargin`, `SetTopMargin`, `SetRightMargin` |
| `SetAutoPageBreak(pauto, pMargin)` | Automatic break on reaching the bottom margin |
| `Ln(h)` | Line break (height `h`, or the last one used) |
| `GetX`/`SetX`, `GetY`/`SetY`, `SetXY` | Writing cursor, in document units |

```sql
PL_FPDF.Init(p_orientation => 'P', p_unit => 'mm', p_format => 'A4');

PL_FPDF.SetMargins(
  left  => 20,                 -- left margin (mm, the Init unit)
  top   => 15,                 -- top margin
  right => 20                  -- omitted/-1 = same as the left one
);
PL_FPDF.SetAutoPageBreak(
  pauto   => TRUE,             -- break automatically on reaching the end
  pMargin => 15                -- distance from the bottom edge that triggers the break
);

PL_FPDF.AddPage;                                 -- page 1 (inherits everything from Init)
PL_FPDF.AddPage(p_orientation => 'L');           -- page 2 in landscape
PL_FPDF.AddPage(p_format => 'A5', p_rotation => 90);  -- page 3: A5, rotated

PL_FPDF.SetPage(1);            -- go back to writing on page 1
PL_FPDF.SetXY(x => 20, y => 40);   -- position the cursor
```

---

## 3. Fonts and UTF-8

### Standard fonts

```sql
PL_FPDF.SetFont('Arial', 'B', 16);   -- family, style ('', 'B', 'I', 'BI', 'U'), size in pt
PL_FPDF.SetFontSize(11);             -- change the size only
```

Core families: `Arial/Helvetica`, `Times`, `Courier`, `Symbol`, `ZapfDingbats`.

### TrueType fonts (full accents, corporate fonts)

```sql
-- Load a TTF from a BLOB (e.g. an assets table)
PL_FPDF.AddTTFFont(
  p_font_name => 'Roboto',
  p_font_blob => l_ttf_blob,
  p_encoding  => 'UTF-8',
  p_embed     => TRUE        -- embed it in the PDF
);

-- Or straight from an Oracle DIRECTORY
PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');

PL_FPDF.SetFont('Roboto', '', 12);
```

Helpers: `IsTTFFontLoaded(name)`, `GetTTFFontInfo(name)`, `ClearTTFFontCache`.

### UTF-8

```sql
PL_FPDF.SetUTF8Enabled(TRUE);        -- the default; accents work natively
IF PL_FPDF.IsUTF8Enabled THEN ... END IF;
```

---

## 4. Writing text

### Cell — rectangular block (the most used API)

```sql
PL_FPDF.Cell(
  pw      => 0,          -- width (0 = up to the right margin)
  ph      => 10,         -- height
  ptxt    => 'Hello!',
  pborder => '1',        -- '0' none, '1' a frame, or 'LTRB' combined
  pln     => 1,          -- 0 = cursor to the right | 1 = next line | 2 = below
  palign  => 'C',        -- 'L', 'C', 'R'
  pfill   => 0,          -- 1 = fill with the SetFillColor colour
  plink   => ''          -- URL or internal link
);
```

### MultiCell — paragraph with automatic wrapping

```sql
l_lines := PL_FPDF.MultiCell(0, 6, l_long_text, '1', 'J');  -- returns the line count
-- or the procedure version, which returns nothing
```

### Write — flowing text (inline, HTML-like)

```sql
PL_FPDF.Write(6, 'Text that carries on ');
PL_FPDF.SetFont('Arial','B');
PL_FPDF.Write(6, 'in bold');
```

### Rotated text

```sql
PL_FPDF.CellRotated(40, 10, 'VERTICAL', p_rotation => 90);   -- 0/90/180/270
PL_FPDF.WriteRotated(6, 'No diagonals; right angles only', p_rotation => 270);
```

### Others

| API | Use |
|-----|-----|
| `Text(px, py, ptxt)` | Text at an absolute position, without moving the cursor |
| `GetStringWidth(pstr)` | Width of the text in the current font (to centre or measure) |
| `SetLineSpacing(pls)` / `GetLineSpacing` | Line spacing |

---

## 5. Colours and drawing

```sql
PL_FPDF.SetDrawColor(200, 0, 0);      -- stroke (RGB 0-255)
PL_FPDF.SetFillColor(240, 240, 240);  -- fill
PL_FPDF.SetTextColor(0, 0, 0);        -- text
PL_FPDF.SetLineWidth(0.5);

PL_FPDF.Line(10, 30, 200, 30);
PL_FPDF.Rect(10, 40, 60, 25, 'DF');   -- '' outline | 'F' filled | 'DF' both
PL_FPDF.Triangle(50, 100, 20, 'up', 'D');  -- pointing up, outline only
                                      -- (the 4th argument is the ORIENTATION,
                                      --  the 5th is the style)
PL_FPDF.Poly(l_points, TRUE, 'D');    -- polygon from a table of points

PL_FPDF.SetDash(2, 2);                       -- simple dashes
PL_FPDF.SetLineDashPattern('[3 2] 0');       -- native PDF pattern
```

---

## 6. Images

```sql
PL_FPDF.Image(
  pFile   => 'logo.png',    -- file name (in a DIRECTORY) or a registered URL
  pX      => 10,            -- X position in the document unit
  pY      => 10,            -- Y position
  pWidth  => 40,            -- width; 0 = derive it from the height
  pHeight => 0,             -- height; 0 = keep the width's aspect ratio
  pType   => NULL,          -- 'PNG' | 'JPG' | NULL = auto-detect
  pLink   => NULL           -- optional URL/internal link (a clickable image)
);

-- An image fetched from a URL (via UTL_HTTP)
l_img := PL_FPDF.getImageFromUrl('https://example.com/logo.png');
```

Formats: **PNG** and **JPEG**.

### What the image overlay accepts

`OverlayImage` (section 13) takes the BLOB directly and covers more cases:

| Case | How it comes out |
|------|----------|
| JPEG | goes in whole, `/DCTDecode` — the reader is what decodes it |
| PNG in RGB, grey or indexed | passes straight through, compressed, from 1 to **16** bits |
| PNG with an **alpha channel** | the transparency becomes an `/SMask`, because PDF does not keep it inside the pixel |
| **Interlaced** PNG (Adam7) | the seven passes are reassembled |

The last two require reprocessing the pixels, and the image comes out
**uncompressed** — the file grows. That path has a ceiling of **4 megapixels**;
above it `ORA-20823` asks for the image to be saved again without alpha (or
flattened onto a background) and without interlacing.

Still refused: interlaced with fewer than 8 bits per component, and indexed
**and** interlaced at the same time.

---

## 7. Links

```sql
l_link := PL_FPDF.AddLink;                 -- create an internal link
PL_FPDF.SetLink(l_link, 0, 3);             -- destination: top of page 3
PL_FPDF.Cell(60, 8, 'Go to chapter 3', plink => l_link);
PL_FPDF.Cell(60, 8, 'Website', plink => 'https://maxwbh.github.io/pl_fpdf/');
PL_FPDF.Link(10, 10, 50, 12, 'https://...');   -- an arbitrary clickable area
```

---

## 8. Header and footer

Register procedures of your own to run on every page:

```sql
-- In your package:
PROCEDURE my_header(p1 IN VARCHAR2, p2 IN VARCHAR2) IS ...
PROCEDURE my_footer IS
BEGIN
  PL_FPDF.SetY(-15);
  PL_FPDF.SetFont('Arial','I',8);
  PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
END;

-- When generating:
-- tv4000a is an associative array indexed by the parameter NAME:
-- declare a variable and fill it by key (there is no tv4000a(...) constructor).
--   l_p PL_FPDF.tv4000a;
--   l_p('p_title') := 'Title';
PL_FPDF.SetHeaderProc('my_pkg.my_header', l_p);
PL_FPDF.SetFooterProc('my_pkg.my_footer');
PL_FPDF.SetAliasNbPages;   -- enables the {nb} placeholder = total pages
```

---

## 9. QR Code and barcode

### AddQRCode

```sql
PL_FPDF.AddQRCode(
  p_x => 150, p_y => 20, p_size => 40,
  p_data             => 'https://msbrasil.inf.br',
  p_format           => 'URL',   -- 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'
  p_error_correction => 'M'      -- 'L'(7%) 'M'(15%) 'Q'(25%) 'H'(30%)
);
```

### AddBarcode

```sql
PL_FPDF.AddBarcode(
  p_x => 30, p_y => 50, p_width => 150, p_height => 20,
  p_code      => 'ABC123456',
  p_type      => 'CODE128',      -- 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF', 'ITF14'
  p_show_text => TRUE
);
```

`ITF` is the one used on the **Brazilian bank Boleto**: plain Interleaved 2 of 5,
any even number of digits, with no symbology check digit — the Boleto's own
control digit sits inside the 44, at position 5. `ITF14` is the particular
14-digit case, which has a check digit of its own.

> **`p_code` arrives ready-made.** `AddBarcode` draws the digits you hand it; it
> does not compute them. Building a Boleto's barcode out of bank, due date,
> amount and free field is a billing rule, and it lives outside this library.

> **Full example:** [`examples/boleto.sql`](../examples/boleto.sql) draws the
> layout of a whole Boleto — two copies, 50 boxes, three Helvetica variants and
> the 44-digit barcode — all in PL/SQL and without a single image.

> **QR and barcode together:** [`examples/ticket.sql`](../examples/ticket.sql)
> draws an event ticket carrying the same code in two symbologies — QR Code and
> Code 39 — across two pages, with colourful panels.

---

## 10. Metadata and document configuration

```sql
PL_FPDF.SetTitle('Monthly Report');
PL_FPDF.SetSubject('Period close');
PL_FPDF.SetAuthor('M&S do Brasil');
PL_FPDF.SetKeywords('report, oracle, pdf');
PL_FPDF.SetCreator('My ERP');

PL_FPDF.SetDisplayMode('fullpage', 'single');  -- initial zoom and layout in the reader
PL_FPDF.SetCompression(TRUE);                  -- compress the page content

-- In one go, via JSON:
PL_FPDF.SetDocumentConfig(JSON_OBJECT_T('{"title":"Report","author":"M&S"}'));

l_meta := PL_FPDF.GetDocumentMetadata;         -- JSON with the current metadata
l_info := PL_FPDF.GetPageInfo(1);              -- page dimensions/rotation
```

---

## 11. Output (producing the PDF)

| API | When to use it |
|-----|-------------|
| `OutputBlob` / `OutputBlob` **RETURN BLOB** | The default: returns the PDF to store in a table, e-mail, feed to APEX and so on |
| `OutputFile(p_filename, p_directory)` | Writes straight into an Oracle DIRECTORY |
| `ReturnBlob(pname, pdest)` | Compatibility with legacy code |
| `Output(pname, pdest)` | Classic FPDF compatibility |

```sql
l_pdf := PL_FPDF.OutputBlob;
INSERT INTO documents (pdf) VALUES (l_pdf);
-- or
PL_FPDF.OutputFile('report.pdf', 'PDF_DIR');
```

### Delivering the PDF to a browser

`Output` with `'I'`, `'D'` or `'S'` **no longer exists** as of 2.x: it raises
`ORA-20306`. Those modes used to send the HTTP headers for you. Now the library
returns the BLOB and **your application is what delivers it** — headers included.

This matters more than it looks. Without `Content-Type: application/pdf`, the
browser may treat the response as HTML and show the **PDF source on screen** —
`%PDF-1.3`, `3 0 obj`, `stream`. It looks like character corruption and it is
not: the file is perfect, it just arrived labelled wrong.

And the symptom misleads because **it depends on the browser**. Firefox and Edge
sniff the `%PDF-` signature and fix it themselves; Chrome and Opera obey the
declared type. The same report opens in one and breaks in the other, and it
disappears once the server sends `X-Content-Type-Options: nosniff`.

**Through the PL/SQL gateway (mod_plsql):**

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- ... build the document ...
  l_pdf := PL_FPDF.OutputBlob();

  owa_util.mime_header('application/pdf', FALSE);
  htp.p('Content-Length: ' || DBMS_LOB.GETLENGTH(l_pdf));
  htp.p('Content-Disposition: inline; filename="report.pdf"');
  owa_util.http_header_close();
  wpg_docload.download_file(l_pdf);
END;
```

`inline` opens it in the browser; `attachment` forces a download.

**Through ORDS:** declare the handler as a media resource and return
`application/pdf` in the content type column.

**Through APEX:** `apex_util.download`, or set the Content-Type in the process
and finish with `apex_application.stop_apex_engine`.

Two traps that produce exactly the same symptom:

| | |
|---|---|
| **Writing before the header** | A debugging `htp.p`, or a message from an `EXCEPTION`, goes into the buffer **before** the headers and corrupts the whole response |
| **A wrong `Content-Length`** | If it does not match the real size, or is missing, some browsers go back to guessing the type |

To check in ten seconds: F12 → **Network** tab → reload → click the request →
**Response Headers**. If `Content-Type` is not `application/pdf`, that is it.

---

## 12. Editing an existing PDF

The flow: `LoadPDF` → inspect/modify → `OutputModifiedPDF`.

It works with a PDF from any producer, including **PDF 1.5+** — where the
cross-reference is a compressed stream and the objects sit inside *object
streams*. Page content is copied byte for byte, without re-rendering: fonts,
images and annotations arrive intact.

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documents WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);

  DBMS_OUTPUT.PUT_LINE('Pages: ' || PL_FPDF.GetPageCount);
  DBMS_OUTPUT.PUT_LINE(PL_FPDF.GetPDFInfo().to_string);   -- version, metadata…

  PL_FPDF.RotatePage(1, 90);            -- 0/90/180/270
  PL_FPDF.RemovePage(3);                -- logical removal
  PL_FPDF.AddWatermark(
    p_text     => 'CONFIDENTIAL',
    p_opacity  => 0.3,
    p_rotation => 45,
    p_pages    => 'ALL',                -- or '1,3-5'
    p_font     => 'Helvetica',
    p_size     => 48,
    p_color    => 'gray'
  );

  l_pdf := PL_FPDF.OutputModifiedPDF;   -- the final PDF, with the changes
  PL_FPDF.ClearPDFCache;                -- free the memory
END;
```

State queries: `GetActivePageCount`, `IsPageRemoved(n)`, `IsPDFModified`,
`GetWatermarks` (JSON with every watermark applied).

---

## 13. Overlays

Puts content at exact positions on a loaded PDF (stamps, sign-off marks, logos).
Coordinates in **PDF points** (1 pt = 1/72"), with **Y counting from the bottom**.

### OverlayText

```sql
PL_FPDF.OverlayText(
  p_page_number => 1,
  p_text        => 'APPROVED',
  p_x => 400, p_y => 700,
  p_options     => JSON_OBJECT_T('{
    "font":"Helvetica", "fontSize":24, "color":"FF0000",
    "opacity":0.8, "rotation":0, "align":"left",
    "width":null, "bold":true, "zOrder":100
  }')
);
```

### OverlayImage

```sql
PL_FPDF.OverlayImage(
  p_page_number => 1,
  p_image_blob  => l_logo,        -- JPEG or PNG
  p_x => 450, p_y => 750,
  p_width => 100, p_height => 50, -- NULL = original size
  p_options => JSON_OBJECT_T('{"opacity":0.9,"maintainAspect":true}')
);
```

Management: `GetOverlays(page)` (a JSON list), `RemoveOverlay(id)`,
`ClearOverlays(page)`. The result comes out of the same `OutputModifiedPDF`.

---

## 14. Multi-PDF: merge, split and extraction

Several PDFs in memory at once, each with an ID:

```sql
PL_FPDF.LoadPDFWithID(l_cover,   'cover');
PL_FPDF.LoadPDFWithID(l_content, 'content');
PL_FPDF.LoadPDFWithID(l_annexes, 'annexes');

-- Merge in the order you want
l_final := PL_FPDF.MergePDFs(JSON_ARRAY_T('["cover","content","annexes"]'));

-- Split by range → an array of BLOBs (JSON with the results)
l_parts := PL_FPDF.SplitPDF('content', JSON_ARRAY_T('["1-10","11-20","21-"]'));

-- Extract specific pages into a new PDF
l_summary := PL_FPDF.ExtractPages('content', '1,5-10,15');

PL_FPDF.UnloadPDF('annexes');         -- free one of them
l_list := PL_FPDF.GetLoadedPDFs;      -- JSON with the loaded IDs
```

---

## 15. Security and encryption

### Protecting a finished PDF

```sql
DECLARE
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_perms.put('print', TRUE);
  l_perms.put('copy',  FALSE);
  l_perms.put('modify',FALSE);

  l_protected := PL_FPDF.EncryptPDF(
    p_pdf            => l_pdf,
    p_user_password  => 'readPassword',
    p_owner_password => 'adminPassword',  -- NULL = same as the user one
    p_permissions    => l_perms,
    p_encryption     => 'AES-256'         -- or 'AES-128', 'RC4-128', 'RC4-40'
  );
END;
```

> **Prefer AES.** RC4 has been broken for years and PDF 2.0 dropped it from the
> specification; new readers warn about it or refuse it. `'RC4-128'` is still the
> parameter's default purely for compatibility with code that already called it
> that way.
>
> A **PDF 1.5+** source is flattened: objects living inside *object streams*
> become top-level objects and the output carries a classic xref. It holds in
> both directions — when decrypting, the object stream is decrypted before it is
> decompressed.

### The remaining APIs

| API | What it does |
|-----|-----------|
| `DecryptPDF(p_pdf, p_password)` | Removes the protection (the password is required) |
| `IsEncrypted(p_pdf)` | TRUE if the BLOB is encrypted |
| `GetSecurityInfo(p_pdf)` | JSON: algorithm, key size, permissions |
| `SetEncryption(p_encryption, p_user_password, p_owner_password)` | Sets encryption **before** `OutputBlob` (for a new document) |
| `SetPermissions(p_print, p_modify, p_copy, p_annotate, p_fill_forms, p_extract, p_assemble, p_print_high)` | Permissions for the new document |
| `SetPDFVersion('1.7')` / `GetPDFVersion` | Version of the generated PDF file |

> **A password is not a signature.** The encryption above protects the file — who
> opens it, who prints it, who copies from it. It does not attest authorship and
> it does not detect tampering. Digital signatures are on the
> [roadmap](ROADMAP.md).

---

## 16. Diagnostics and utilities

```sql
PL_FPDF.SetLogLevel(3);              -- 0=off … verbosity levels
PL_FPDF.DebugEnabled;                -- shortcuts
PL_FPDF.DebugDisabled;
```

---

## 17. Migrating from v0.9.4

```sql
-- BEFORE (v0.9.4)                    -- NOW (v2.0+)
PL_FPDF.fpdf('P','mm','A4');         PL_FPDF.Init('P','mm','A4');
l_pdf := PL_FPDF.Output('S');        l_pdf := PL_FPDF.OutputBlob;
PL_FPDF.Output('F', path);           PL_FPDF.OutputFile(name, directory);
```

| v0.9.4 | v2.0+ |
|--------|-------|
| `fpdf()` | `Init()` (`fpdf()` is still available for compatibility) |
| `Output('S')` | `OutputBlob` |
| Limited UTF-8 | Full UTF-8 + TrueType |
| No encryption | AES-256, AES-128 and RC4 |

---

## 18. Error codes

| Range | Area | Examples |
|-------|------|----------|
| -20005 | Life cycle | used before `Init` |
| -20101…-20107 | Pages | unknown format, orientation, rotation, page does not exist |
| -20110/-20111 | Text | invalid rotation (only 0/90/180/270) |
| -20301…-20303 | Images | invalid header, failure fetching from the URL, unsupported format |
| -20800…-20810 | LoadPDF | invalid PDF, corrupt header/xref/trailer; no PDF loaded |
| -20821…-20825 | Overlays | invalid coordinates, opacity, image or dimensions |
| -20831…-20844 | Multi-PDF | ID not found; invalid page specification |
| -20843/-20847/-20848 | PDF 1.5+ | an xref stream, object stream or predictor that cannot be read |
| -20850…-20865 | Security | password, encryption method, PDF already protected |
| -20870…-20879 | QR Code | empty content, size, correction level, capacity |
| -20880…-20889 | Barcode | empty code, dimensions, symbology, digits |
| -20890…-20894 | `FlateDecode` | invalid stream, or output above the ceiling |

The complete list, error by error and API by API, is in
[API_REFERENCE_EN.md](API_REFERENCE_EN.md).

---

## Support

- **Author:** Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))
- **Maintained by:** [M&S do Brasil LTDA](https://msbrasil.inf.br)
- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues) · **Questions:** [Discussions](https://github.com/Maxwbh/pl_fpdf/discussions)
- **E-mail:** contato@msbrasil.inf.br
