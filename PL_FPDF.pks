create or replace PACKAGE PL_FPDF AS
/*******************************************************************************
* Logiciel : PL_FPDF                                                           *
* Version :  0.9.4                                                             *
* Date :     27-Dec-2017                                                       *
* Auteur :   Pierre-Gilles Levallois et al                                          *
* Licence :  GPL                                                               *
*                                                                              *
********************************************************************************
* Cette librairie PL/SQL est un portage de la version 1.53 de FPDF, célèbre    *
* classe PHP développée par Olivier PLATHEY (http://www.fpdf.org/)             *
********************************************************************************
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
********************************************************************************/
-- Public types and subtypes.
subtype word is varchar2(80);

type tv4000a is table of varchar2(4000) index by word;

--Point type use in polygons creation
type point is record (x number, y number);

type tab_points is table of point index by pls_integer;

--------------------------------------------------------------------------------
-- TASK 1.6: Native BLOB-based image handling (replaces deprecated OrdImage)
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-16
--------------------------------------------------------------------------------

/*******************************************************************************
* Type: recImageBlob
* Description: Native BLOB-based image container replacing deprecated ORDSYS.ORDIMAGE.
*              Supports PNG and JPEG formats with header parsing for metadata.
* Fields:
*   image_blob - The raw image data as BLOB
*   mime_type - MIME type ('image/png', 'image/jpeg', 'image/jpg')
*   file_format - File format code ('PNG', 'JPEG', 'JPG')
*   width - Image width in pixels (parsed from header)
*   height - Image height in pixels (parsed from header)
*   bit_depth - Bits per channel (8, 16, 24, 32)
*   color_type - PNG color type or JPEG marker (0=grayscale, 2=RGB, 3=indexed, 4=gray+alpha, 6=RGBA)
*   has_transparency - TRUE if image has alpha channel or transparency
*******************************************************************************/
type recImageBlob is record (
  image_blob blob,
  mime_type varchar2(100),
  file_format varchar2(20),
  width integer,
  height integer,
  bit_depth integer,
  color_type integer,
  has_transparency boolean
);

-- Constantes globales
FPDF_VERSION constant varchar2(10) := '1.53';
PL_FPDF_VERSION constant varchar2(10) := '0.9.4';
noParam tv4000a;

--------------------------------------------------------------------------------
-- TASK 1.1: Modernization - Initialization procedures (Oracle 19c/23c)
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-15
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: Init
* Description: Initializes the PDF generation engine with modern Oracle 19c+
*              features including UTF-8 support and CLOB buffers.
*              Replaces/extends the legacy fpdf() constructor.
* Parameters:
*   p_orientation - Page orientation ('P'=Portrait, 'L'=Landscape)
*   p_unit - Measurement unit ('mm', 'cm', 'in', 'pt')
*   p_format - Page format ('A4', 'Letter', 'Legal', etc.)
*   p_encoding - Character encoding (default 'UTF-8')
* Raises:
*   -20001: Invalid orientation parameter
*   -20002: Invalid measurement unit
*   -20003: Unsupported encoding
* Example:
*   PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
*******************************************************************************/
procedure Init(
  p_orientation varchar2 default 'P',
  p_unit varchar2 default 'mm',
  p_format varchar2 default 'A4',
  p_encoding varchar2 default 'UTF-8'
);

/*******************************************************************************
* Procedure: Reset
* Description: Resets the PDF engine to initial state, freeing all resources
*              including temporary CLOBs and clearing all arrays.
* Example:
*   PL_FPDF.Reset();
*******************************************************************************/
procedure Reset;

/*******************************************************************************
* Function: IsInitialized
* Description: Checks if the PDF engine has been properly initialized via Init()
* Returns: TRUE if initialized, FALSE otherwise
* Example:
*   IF PL_FPDF.IsInitialized() THEN ...
*******************************************************************************/
function IsInitialized return boolean
  DETERMINISTIC;

--------------------------------------------------------------------------------
-- End of Task 1.1 additions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TASK 1.2: Modernization - AddPage/SetPage with BLOB streaming (Oracle 19c/23c)
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-15
--------------------------------------------------------------------------------

/*******************************************************************************
* Type: recPageFormat
* Description: Record type for page dimensions (width x height)
*******************************************************************************/
type recPageFormat is record (
  width number(10,5),
  height number(10,5)
);

/*******************************************************************************
* Type: recPage
* Description: Enhanced page structure with CLOB content and metadata
* Fields:
*   number_val - Page number
*   orientation - Page orientation ('P' or 'L')
*   format - Page dimensions (recPageFormat)
*   rotation - Page rotation in degrees (0, 90, 180, 270)
*   content_clob - CLOB for page content (replaces VARCHAR2 array)
*   created_at - Timestamp when page was created
*******************************************************************************/
type recPage is record (
  number_val pls_integer,
  orientation varchar2(1),
  format recPageFormat,
  rotation pls_integer default 0,
  content_clob clob,
  created_at timestamp default systimestamp
);

/*******************************************************************************
* Type: tPages
* Description: Collection of pages indexed by page number
*******************************************************************************/
type tPages is table of recPage index by pls_integer;

--------------------------------------------------------------------------------
-- End of Task 1.2 type additions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TASK 1.3: TrueType/Unicode Font Support (Oracle 19c/23c)
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-15
--------------------------------------------------------------------------------

/*******************************************************************************
* Type: recTTFFont
* Description: TrueType font structure with parsed metrics
*******************************************************************************/
type recTTFFont is record (
  font_name varchar2(100),
  file_name varchar2(255),
  font_blob blob,
  encoding varchar2(20) default 'UTF-8',
  units_per_em number,
  ascent number,
  descent number,
  line_gap number default 0,
  cap_height number default 0,
  x_height number default 0,
  is_bold boolean default false,
  is_italic boolean default false,
  is_embedded boolean default true,
  loaded_at timestamp default systimestamp
);

/*******************************************************************************
* Type: tTTFFonts
* Description: Collection of TrueType fonts indexed by font name
*******************************************************************************/
type tTTFFonts is table of recTTFFont index by varchar2(100);

/*******************************************************************************
* Procedure: AddTTFFont - Add TrueType font from BLOB
*******************************************************************************/
procedure AddTTFFont(
  p_font_name varchar2,
  p_font_blob blob,
  p_encoding varchar2 default 'UTF-8',
  p_embed boolean default true
);

/*******************************************************************************
* Procedure: LoadTTFFromFile - Load TrueType from filesystem
*******************************************************************************/
procedure LoadTTFFromFile(
  p_font_name varchar2,
  p_file_path varchar2,
  p_directory varchar2 default 'FONTS_DIR',
  p_encoding varchar2 default 'UTF-8'
);

/*******************************************************************************
* Function: IsTTFFontLoaded - Check if font is loaded
*******************************************************************************/
function IsTTFFontLoaded(p_font_name varchar2) return boolean;

/*******************************************************************************
* Function: GetTTFFontInfo - Get font metadata
*******************************************************************************/
function GetTTFFontInfo(p_font_name varchar2) return recTTFFont;

/*******************************************************************************
* Procedure: ClearTTFFontCache - Clear font cache
*******************************************************************************/
procedure ClearTTFFontCache;

/*******************************************************************************
* Function: UTF8ToPDFString - Convert UTF-8 text to PDF-compatible string
* Description: Converts UTF-8 encoded text to PDF string format
* Parameters:
*   p_text - UTF-8 text to convert
*   p_escape - Whether to escape PDF special characters (default true)
* Returns: PDF-compatible string
*******************************************************************************/
function UTF8ToPDFString(
  p_text varchar2,
  p_escape boolean default true
) return varchar2;

/*******************************************************************************
* Function: IsUTF8Enabled - Check if UTF-8 encoding is enabled
*******************************************************************************/
function IsUTF8Enabled return boolean;

/*******************************************************************************
* Procedure: SetUTF8Enabled - Enable/disable UTF-8 encoding
*******************************************************************************/
procedure SetUTF8Enabled(p_enabled boolean default true);

--------------------------------------------------------------------------------
-- End of Task 1.3 additions
-- Task 2.1: UTF-8/Unicode Support additions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TASK 2.2 & 2.4: Custom Exceptions and Error Handling
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-17
--------------------------------------------------------------------------------

/*******************************************************************************
* Custom Exceptions for PL_FPDF
* Provides specific exception handling instead of generic ORA-20100 errors
*******************************************************************************/

-- Initialization Errors (-20001 to -20010)
exc_invalid_orientation EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_orientation, -20001);

exc_invalid_unit EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_unit, -20002);

exc_invalid_encoding EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_encoding, -20003);

exc_not_initialized EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_not_initialized, -20005);

-- Page Errors (-20101 to -20110)
exc_invalid_page_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_page_format, -20101);

exc_page_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_page_not_found, -20106);

-- Font Errors (-20201 to -20215)
exc_font_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_font_not_found, -20201);

exc_invalid_font_file EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_file, -20202);

exc_invalid_font_name EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_name, -20210);

exc_invalid_font_blob EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_blob, -20211);

-- Image Errors (-20301 to -20310)
exc_invalid_image EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_image, -20301);

exc_image_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_image_not_found, -20302);

exc_unsupported_image_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_unsupported_image_format, -20303);

-- File I/O Errors (-20401 to -20410)
exc_invalid_directory EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_directory, -20401);

exc_file_access_denied EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_access_denied, -20402);

exc_file_write_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_write_error, -20403);

-- Color/Drawing Errors (-20501 to -20510)
exc_invalid_color EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_color, -20501);

exc_invalid_line_width EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_line_width, -20502);

-- General Errors (-20100)
exc_general_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_general_error, -20100);

--------------------------------------------------------------------------------
-- End of TASK 2.2 & 2.4 additions
--------------------------------------------------------------------------------

-- methods added to FPDF
function GetCurrentFontSize return number;
function GetCurrentFontStyle return varchar2;
function GetCurrentFontFamily return varchar2;
procedure SetDash(pblack in number default 0, pwhite in number default 0);
function GetLineSpacing return number;
Procedure SetLineSpacing (pls in number);
-- Allows to create a polygon with a table of points
-- pclose define if the polygon is closed or not
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');
procedure Triangle(px in number, py in number, psize in number, 
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

-- FPDF public methods
procedure Ln(h number default null);
function  GetX return number;
procedure SetX(px in number);
function  GetY return number;
procedure SetY(py in number);
procedure SetXY(x in number,y in number);
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam);
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam);
procedure SetMargins(left in number, top in number, right in number default -1);
procedure SetLeftMargin(pMargin in number);
procedure SetTopMargin(pMargin in number);
procedure SetRightMargin(pMargin in number);
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0);
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous');
procedure SetCompression(p_compress in boolean default false);
procedure SetTitle(ptitle in varchar2);
procedure SetSubject(psubject in varchar2);
procedure SetAuthor(pauthor in varchar2);
procedure SetKeywords(pkeywords in varchar2);
procedure SetCreator(pcreator in varchar2);
procedure SetAliasNbPages(palias in varchar2 default '{nb}');
procedure Header;
procedure Footer;
function  PageNo return number;
procedure SetDrawColor(r in number, g in number default -1, b in number default -1);
procedure SetFillColor (r in number, g in number default -1, b in number default -1);
procedure SetTextColor (r in number, g in number default -1, b in number default -1);
procedure SetLineWidth(width in number);
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number);
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '');
function  AddLink return number;
procedure SetLink(plink in number, py in number default 0, ppage in number default -1);
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2);
procedure Text(px in number, py in number, ptxt in varchar2);
function  AcceptPageBreak return boolean;
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '');
procedure SetFont(pfamily in varchar2,pstyle in varchar2 default '', psize in number default 0);
function GetStringWidth(pstr in varchar2) return number;
procedure SetFontSize(psize in number);
procedure Cell
		 (pw in number,
		  ph in number default 0,
		  ptxt in varchar2 default '',
		  pborder in varchar2 default '0',
		  pln in number default 0,
		  palign in varchar2 default '',
		  pfill in number default 0,
		  plink in varchar2 default '');
--Now return the number of line created with multiCell
function MultiCell
  ( pw in number,
    ph in number default 0,
	ptxt in varchar2,
	pborder in varchar2 default '0',
	palign in varchar2 default 'J',
	pfill in number default 0,
	phMax in number default 0) return number;

procedure MultiCell
  ( pwidth in number,
    pheight in number default 0,
    ptext in varchar2,
    pbrdr in varchar2 default '0',
    palignment in varchar2 default 'J',
    pfillin in number default 0,
    phMaximum in number default 0);

procedure Write(pH in varchar2, ptxt in varchar2, plink in varchar2 default null);

--------------------------------------------------------------------------------
-- TASK 1.4: Modern Cell/MultiCell/Write with rotation support
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-16
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: CellRotated
* Description: Modern Cell with text rotation support
* Parameters:
*   p_width - Cell width (0 = extend to right margin)
*   p_height - Cell height
*   p_text - Text content
*   p_border - Border: 0=none, 1=frame, or combination of L,T,R,B
*   p_ln - Line break: 0=right, 1=below, 2=below
*   p_align - Alignment: L=left, C=center, R=right
*   p_fill - Fill: 0=no fill, 1=fill
*   p_link - URL/internal link
*   p_rotation - Text rotation: 0, 90, 180, 270 degrees
* Raises:
*   -20110: Invalid rotation value
*******************************************************************************/
procedure CellRotated(
  p_width number,
  p_height number default 0,
  p_text varchar2 default '',
  p_border varchar2 default '0',
  p_ln number default 0,
  p_align varchar2 default '',
  p_fill number default 0,
  p_link varchar2 default '',
  p_rotation pls_integer default 0
);

/*******************************************************************************
* Procedure: WriteRotated
* Description: Modern Write with text rotation support
* Parameters:
*   p_height - Line height
*   p_text - Text content
*   p_link - URL/internal link
*   p_rotation - Text rotation: 0, 90, 180, 270 degrees
* Raises:
*   -20110: Invalid rotation value
*******************************************************************************/
procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
);

procedure image ( pFile in varchar2, 
		  		pX in number, 
				  pY in number, 
				  pWidth in number default 0,
				  pHeight in number default 0,
				  pType in varchar2 default null,
				  pLink in varchar2 default null);
				  
procedure Output(pname in varchar2 default null, pdest in varchar2 default null);
function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null) return blob;

--------------------------------------------------------------------------------
-- TASK 1.5: Modern output methods without OWA/HTP dependencies
--------------------------------------------------------------------------------
function OutputBlob return blob;
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

procedure OpenPDF;
procedure ClosePDF;

--------------------------------------------------------------------------------
-- TASK 1.2: Enhanced AddPage with rotation and format support
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddPage
* Description: Adds a new page to the PDF document with modern CLOB streaming
*              and support for custom formats and rotation
* Parameters:
*   p_orientation - Page orientation ('P'=Portrait, 'L'=Landscape, NULL=current)
*   p_format - Page format ('A4', 'Letter', 'Legal', 'width,height', NULL=current)
*   p_rotation - Page rotation in degrees (0, 90, 180, 270)
* Raises:
*   -20100: PDF not initialized
*   -20101: Invalid orientation
*   -20102: Page dimensions too large (>10000mm)
*   -20103: Invalid custom format
*   -20104: Invalid rotation value
* Example:
*   PL_FPDF.AddPage('P', 'A4', 0);
*   PL_FPDF.AddPage('L', '210,297', 90);  -- Custom format with rotation
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*******************************************************************************/
procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
);

/*******************************************************************************
* Procedure: SetPage
* Description: Sets the current active page for content manipulation
* Parameters:
*   p_page_number - Page number to set as current (must exist)
* Raises:
*   -20105: PDF not initialized
*   -20106: Page does not exist
* Example:
*   PL_FPDF.SetPage(1);  -- Go back to page 1
*******************************************************************************/
procedure SetPage(p_page_number pls_integer);

/*******************************************************************************
* Function: GetCurrentPage
* Description: Returns the current page number
* Returns: Current page number (PLS_INTEGER)
* Example:
*   l_page := PL_FPDF.GetCurrentPage();
*******************************************************************************/
function GetCurrentPage return pls_integer
  DETERMINISTIC;

--------------------------------------------------------------------------------
-- Legacy compatibility (maintained for backward compatibility)
--------------------------------------------------------------------------------
procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');
procedure Error(pmsg in varchar2);
procedure DebugEnabled;
procedure DebugDisabled;
function GetScaleFactor return number;

/*******************************************************************************
* Function: getImageFromUrl
* Description: Fetches an image from a URL and returns it as a native BLOB
*              with parsed metadata (dimensions, format, etc.)
*              Replaces legacy OrdImage-based implementation.
* Parameters:
*   p_Url - Image URL (http/https)
* Returns: recImageBlob with image data and metadata
* Supported Formats: PNG, JPEG/JPG
* Raises:
*   -20220: Unsupported image format
*   -20221: Invalid image header
*   -20222: Unable to fetch image from URL
* Example:
*   l_img := PL_FPDF.getImageFromUrl('http://example.com/image.png');
*******************************************************************************/
function getImageFromUrl(p_Url in varchar2) return recImageBlob;

--
-- Sample codes.
--
procedure helloworld;
procedure testImg;
procedure test(pdest in varchar2 default 'D');
procedure MyRepetitiveHeader(param1 in varchar2, param2 in varchar2);
procedure MyRepetitiveFooter;
procedure testHeader;
--------------------------------------------------------------------------------
-- Affiche le numéro de page en base de page
--------------------------------------------------------------------------------
procedure lpc_footer;

--------------------------------------------------------------------------------
-- TASK 2.5: Enhanced Logging
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-18
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: SetLogLevel
* Description: Sets the logging level for debugging
* Parameters:
*   p_level - Log level (0=OFF, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG)
*******************************************************************************/
procedure SetLogLevel(p_level pls_integer);

/*******************************************************************************
* Function: GetLogLevel
* Description: Returns the current logging level
* Returns: Current log level (0-4)
*******************************************************************************/
function GetLogLevel return pls_integer
  DETERMINISTIC;

--------------------------------------------------------------------------------
-- TASK 3.2: JSON Support - Modern Configuration and Metadata APIs
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-18
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: SetDocumentConfig
* Description: Configure PDF document using JSON_OBJECT_T for modern integration
* Parameters:
*   p_config - JSON object containing configuration options
* Supported JSON keys:
*   - title, author, subject, keywords, creator (document metadata)
*   - orientation ('P' or 'L'), unit ('mm','cm','in','pt'), format (page format)
*   - fontFamily, fontSize, fontStyle (default font configuration)
*   - leftMargin, topMargin, rightMargin (page margins in current unit)
* Example:
*   DECLARE
*     l_config JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     l_config.put('title', 'Monthly Report');
*     l_config.put('author', 'Maxwell Oliveira');
*     l_config.put('orientation', 'P');
*     l_config.put('format', 'A4');
*     PL_FPDF.SetDocumentConfig(l_config);
*   END;
*******************************************************************************/
procedure SetDocumentConfig(p_config JSON_OBJECT_T);

/*******************************************************************************
* Function: GetDocumentMetadata
* Description: Returns document metadata and statistics as JSON_OBJECT_T
* Returns: JSON object with document information
* JSON structure:
*   {
*     "pageCount": <number>,
*     "title": "<string>",
*     "author": "<string>",
*     "subject": "<string>",
*     "keywords": "<string>",
*     "format": "<string>",
*     "orientation": "<string>",
*     "unit": "<string>",
*     "initialized": <boolean>
*   }
* Example:
*   DECLARE
*     l_meta JSON_OBJECT_T;
*   BEGIN
*     l_meta := PL_FPDF.GetDocumentMetadata();
*     DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
*   END;
*******************************************************************************/
function GetDocumentMetadata return JSON_OBJECT_T;

/*******************************************************************************
* Function: GetPageInfo
* Description: Returns information about a specific page as JSON_OBJECT_T
* Parameters:
*   p_page_number - Page number (NULL = current page)
* Returns: JSON object with page information
* JSON structure:
*   {
*     "number": <number>,
*     "format": "<string>",
*     "orientation": "<string>",
*     "width": <number>,
*     "height": <number>,
*     "unit": "<string>"
*   }
* Example:
*   DECLARE
*     l_page_info JSON_OBJECT_T;
*   BEGIN
*     l_page_info := PL_FPDF.GetPageInfo(1);
*     DBMS_OUTPUT.PUT_LINE('Width: ' || l_page_info.get_Number('width'));
*   END;
*******************************************************************************/
function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T;

--------------------------------------------------------------------------------
-- End of Task 3.2 additions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Task 3.7: Generic QR Code Generation
--------------------------------------------------------------------------------
-- NOTE: PIX QR Code rendering is available in PL_FPDF_PIX.AddQRCodePIX()
--       This package provides only generic QR Code rendering.
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddQRCode
* Description: Adds a generic QR Code to the current page
* Parameters:
*   p_x - X position (in current units)
*   p_y - Y position (in current units)
*   p_size - QR Code size (width=height, in current units)
*   p_data - Data to encode (max 2953 bytes for binary mode)
*   p_format - Format: 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'
*   p_error_correction - Error correction: 'L'(7%), 'M'(15%), 'Q'(25%), 'H'(30%)
* Example:
*   PL_FPDF.AddQRCode(50, 50, 40, 'https://example.com', 'URL', 'M');
*******************************************************************************/
procedure AddQRCode(
  p_x number,
  p_y number,
  p_size number,
  p_data varchar2,
  p_format varchar2 default 'TEXT',
  p_error_correction varchar2 default 'M'
);

--------------------------------------------------------------------------------
-- End of Task 3.7: Generic QR Code
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Task 3.8: Generic Barcode Generation
--------------------------------------------------------------------------------
-- NOTE: Boleto barcode rendering is available in PL_FPDF_BOLETO.AddBarcodeBoleto()
--       This package provides only generic barcode rendering.
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddBarcode
* Description: Adds a generic barcode to the current page
* Parameters:
*   p_x - X position (in current units)
*   p_y - Y position (in current units)
*   p_width - Barcode width (in current units)
*   p_height - Barcode height (in current units)
*   p_code - Data to encode
*   p_type - Barcode type: 'ITF14', 'CODE128', 'CODE39', 'EAN13', 'EAN8'
*   p_show_text - Show human-readable text below barcode
* Example:
*   PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
*******************************************************************************/
procedure AddBarcode(
  p_x number,
  p_y number,
  p_width number,
  p_height number,
  p_code varchar2,
  p_type varchar2 default 'CODE128',
  p_show_text boolean default true
);

--------------------------------------------------------------------------------
-- End of Task 3.8: Generic Barcode
--------------------------------------------------------------------------------

END PL_FPDF;