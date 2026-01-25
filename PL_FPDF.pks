CREATE OR REPLACE PACKAGE PL_FPDF AS
/*******************************************************************************
*                                                                              *
*                            PL_FPDF v3.0.0                                    *
*                Oracle PL/SQL PDF Generation and Manipulation                *
*                                                                              *
********************************************************************************
*                                                                              *
* English:                                                                     *
* --------                                                                     *
* Pure PL/SQL library for generating and manipulating PDF documents directly  *
* in Oracle Database. No external dependencies, Java, or additional services  *
* required.                                                                    *
*                                                                              *
* Português (Brasil):                                                          *
* ------------------                                                           *
* Biblioteca PL/SQL pura para gerar e manipular documentos PDF diretamente    *
* no Oracle Database. Sem dependências externas, Java ou serviços adicionais. *
*                                                                              *
********************************************************************************
*                                                                              *
* Version / Versão: 3.0.0                                                      *
* Release Date / Data de Lançamento: January 2026 / Janeiro 2026              *
* Status: Production Ready / Pronto para Produção                             *
*                                                                              *
* GitHub: https://github.com/maxwbh/pl_fpdf                                    *
* Documentation / Documentação: /docs                                          *
*                                                                              *
********************************************************************************
*                                                                              *
* FEATURES / RECURSOS:                                                         *
*                                                                              *
* Phase 1-3 (v2.0.0): PDF Generation / Geração de PDF                         *
* ──────────────────────────────────────────────────────────────────           *
* ✓ Create PDFs from scratch / Criar PDFs do zero                             *
* ✓ Text, images, shapes / Texto, imagens, formas                             *
* ✓ Multi-page documents / Documentos multi-página                            *
* ✓ TrueType fonts, UTF-8 / Fontes TrueType, UTF-8                            *
* ✓ Barcodes (Code39, EAN-13, QR) / Códigos de barras                         *
* ✓ Tables with auto-pagination / Tabelas com auto-paginação                  *
*                                                                              *
* Phase 4 (v3.0.0): PDF Manipulation / Manipulação de PDF                     *
* ──────────────────────────────────────────────────────────────────           *
* ✓ Load and parse PDFs / Carregar e parsear PDFs                             *
* ✓ Extract page info / Extrair informações de páginas                        *
* ✓ Rotate pages / Rotacionar páginas                                         *
* ✓ Remove pages / Remover páginas                                            *
* ✓ Add watermarks / Adicionar marcas d'água                                  *
* ✓ Output modified PDFs / Gerar PDFs modificados                             *
*                                                                              *
********************************************************************************
*                                                                              *
* CREDITS / CRÉDITOS:                                                          *
*                                                                              *
* Original FPDF (PHP): Olivier PLATHEY (http://www.fpdf.org/)                 *
* PL/SQL Port: Pierre-Gilles Levallois, Anton Scheffer, Marcel Amman          *
* Modernization & Phase 4: Maxwell Oliveira (@maxwbh)                         *
*                                                                              *
********************************************************************************
*                                                                              *
* LICENSE / LICENÇA: MIT License                                               *
*                                                                              *
* Copyright (c) 2026 Maxwell Oliveira and contributors                         *
*                                                                              *
* Permission is hereby granted, free of charge, to any person obtaining a      *
* copy of this software and associated documentation files (the "Software"),   *
* to deal in the Software without restriction, including without limitation    *
* the rights to use, copy, modify, merge, publish, distribute, sublicense,     *
* and/or sell copies of the Software, and to permit persons to whom the        *
* Software is furnished to do so, subject to the following conditions:         *
*                                                                              *
* The above copyright notice and this permission notice shall be included in   *
* all copies or substantial portions of the Software.                          *
*                                                                              *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING      *
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER          *
* DEALINGS IN THE SOFTWARE.                                                    *
*                                                                              *
*******************************************************************************/
-- Public types and subtypes.
subtype word is varchar2(80);

type tv4000a is table of varchar2(4000) index by word;

--Point type use in polygons creation
type point is record (x number, y number);

type tab_points is table of point index by pls_integer;

--------------------------------------------------------------------------------
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

-- Global constants / Constantes globais
co_version CONSTANT VARCHAR2(10) := '3.0.0';  -- PL_FPDF Version / Versão
noParam tv4000a;

/*******************************************************************************
*                                                                              *
*                         PACKAGE STRUCTURE / ESTRUTURA                        *
*                                                                              *
********************************************************************************
*                                                                              *
* This package is organized into functional groups:                           *
* Este pacote está organizado em grupos funcionais:                           *
*                                                                              *
* 1. INITIALIZATION & LIFECYCLE / INICIALIZAÇÃO E CICLO DE VIDA               *
*    ├─ Init()           - Initialize PDF engine / Inicializar engine         *
*    ├─ Reset()          - Reset state / Resetar estado                       *
*    └─ SetLogLevel()    - Configure logging / Configurar logging             *
*                                                                              *
* 2. PAGE MANAGEMENT / GERENCIAMENTO DE PÁGINAS                               *
*    ├─ AddPage()        - Add new page / Adicionar nova página               *
*    ├─ PageNo()         - Get page number / Obter número da página           *
*    └─ AliasNbPages()   - Total pages placeholder / Placeholder p/ total     *
*                                                                              *
* 3. TEXT & FONTS / TEXTO E FONTES                                            *
*    ├─ SetFont()        - Set current font / Definir fonte atual             *
*    ├─ Cell()           - Print cell / Imprimir célula                       *
*    ├─ MultiCell()      - Print multi-line / Imprimir multi-linha            *
*    ├─ Write()          - Write text / Escrever texto                        *
*    └─ Text()           - Place text at position / Colocar texto em posição  *
*                                                                              *
* 4. GRAPHICS / GRÁFICOS                                                       *
*    ├─ Line()           - Draw line / Desenhar linha                         *
*    ├─ Rect()           - Draw rectangle / Desenhar retângulo                *
*    ├─ Circle()         - Draw circle / Desenhar círculo                     *
*    └─ Polygon()        - Draw polygon / Desenhar polígono                   *
*                                                                              *
* 5. IMAGES / IMAGENS                                                          *
*    ├─ Image()          - Insert image / Inserir imagem                      *
*    └─ LoadImageBlob()  - Load image from BLOB / Carregar de BLOB            *
*                                                                              *
* 6. BARCODES / CÓDIGOS DE BARRAS                                              *
*    ├─ AddBarcode()     - Add barcode / Adicionar código de barras           *
*    └─ AddQRCode()      - Add QR code / Adicionar QR code                    *
*                                                                              *
* 7. TABLES / TABELAS                                                          *
*    └─ Table()          - Create table / Criar tabela                        *
*                                                                              *
* 8. OUTPUT / SAÍDA                                                            *
*    ├─ Output_Blob()    - Get PDF as BLOB / Obter PDF como BLOB              *
*    └─ OutputFile()     - Save to file / Salvar em arquivo                   *
*                                                                              *
* 9. PHASE 4: PDF READING & MANIPULATION / LEITURA E MANIPULAÇÃO              *
*    ├─ LoadPDF()        - Load existing PDF / Carregar PDF existente         *
*    ├─ GetPageCount()   - Get page count / Obter contagem de páginas         *
*    ├─ GetPageInfo()    - Get page details / Obter detalhes da página        *
*    ├─ GetPDFInfo()     - Get PDF metadata / Obter metadados do PDF          *
*    ├─ RotatePage()     - Rotate page / Rotacionar página                    *
*    ├─ RemovePage()     - Remove page / Remover página                       *
*    ├─ AddWatermark()   - Add watermark / Adicionar marca d'água             *
*    ├─ GetWatermarks()  - List watermarks / Listar marcas d'água             *
*    ├─ OutputModifiedPDF() - Generate modified / Gerar modificado            *
*    └─ ClearPDFCache()  - Clear cache / Limpar cache                         *
*                                                                              *
*******************************************************************************/

--------------------------------------------------------------------------------
-- Date: 2026-01-25
-- Updated: Phase 4 Complete / Fase 4 Completa
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
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------
function OutputBlob return blob;
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

procedure OpenPDF;
procedure ClosePDF;

--------------------------------------------------------------------------------
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
-- Displays page number at the bottom of page
--------------------------------------------------------------------------------
procedure lpc_footer;

--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

********************************************************************************
*                                                                              *
*                    PHASE 4: PDF PARSER AND EDITOR / EDITOR                   *
*                              v3.0.0 (Complete)                               *
*                                                                              *
********************************************************************************
*                                                                              *
* English: APIs for reading and modifying existing PDF documents               *
* Português: APIs para ler e modificar documentos PDF existentes              *
*                                                                              *
********************************************************************************

/*******************************************************************************
* Procedure: LoadPDF / Carregar PDF
*
* Description / Descrição:
*   EN: Load an existing PDF document into memory for reading and modification
*   PT: Carregar documento PDF existente na memória para leitura e modificação
*
* Parameters / Parâmetros:
*   p_pdf_blob - PDF document as BLOB / Documento PDF como BLOB
*
* Raises / Erros:
*   -20800: Invalid PDF (NULL or too small) / PDF inválido (NULL ou pequeno)
*   -20801: Invalid PDF header / Cabeçalho PDF inválido
*   -20802: startxref not found / startxref não encontrado
*   -20803: Invalid xref table / Tabela xref inválida
*   -20804: Root object not found in trailer / Objeto Root não encontrado
*
* Example / Exemplo:
*   DECLARE
*     l_pdf BLOB;
*   BEGIN
*     SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
*     PL_FPDF.LoadPDF(l_pdf);
*     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || PL_FPDF.GetPageCount());
*   END;
*******************************************************************************/
PROCEDURE LoadPDF(p_pdf_blob BLOB);

/*******************************************************************************
* Function: GetPageCount / Obter Contagem de Páginas
*
* Description / Descrição:
*   EN: Get the total number of pages in the loaded PDF document
*   PT: Obter o número total de páginas no documento PDF carregado
*
* Returns / Retorna:
*   PLS_INTEGER - Number of pages / Número de páginas
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*
* Example / Exemplo:
*   l_pages := PL_FPDF.GetPageCount();
*   DBMS_OUTPUT.PUT_LINE('Total pages / Total de páginas: ' || l_pages);
*******************************************************************************/
FUNCTION GetPageCount RETURN PLS_INTEGER;

/*******************************************************************************
* Function: GetPDFInfo / Obter Informações do PDF
*
* Description / Descrição:
*   EN: Get metadata and information about the loaded PDF document
*   PT: Obter metadados e informações sobre o documento PDF carregado
*
* Returns / Retorna:
*   JSON_OBJECT_T with / com:
*   - version: PDF version (e.g., "1.4") / Versão do PDF
*   - pageCount: Number of pages / Número de páginas
*   - fileSize: Size in bytes / Tamanho em bytes
*   - objectCount: Number of objects in xref / Número de objetos na xref
*   - rootObjectId: Catalog object ID / ID do objeto Catalog
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*
* Example / Exemplo:
*   DECLARE
*     l_info JSON_OBJECT_T;
*   BEGIN
*     l_info := PL_FPDF.GetPDFInfo();
*     DBMS_OUTPUT.PUT_LINE('Version / Versão: ' || l_info.get_string('version'));
*     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || l_info.get_number('pageCount'));
*   END;
*******************************************************************************/
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;

/*******************************************************************************
* Function: GetPageInfo / Obter Informações da Página
*
* Description / Descrição:
*   EN: Get detailed information about a specific page in the PDF
*   PT: Obter informações detalhadas sobre uma página específica do PDF
*
* Parameters / Parâmetros:
*   p_page_number - Page number (1-based) / Número da página (base 1)
*
* Returns / Retorna:
*   JSON_OBJECT_T with page details / com detalhes da página:
*   - pageNumber: Page number / Número da página
*   - pageObjectId: PDF object ID / ID do objeto PDF
*   - mediaBox: Dimensions (e.g., "0 0 612 792") / Dimensões
*   - rotation: Rotation in degrees / Rotação em graus (0, 90, 180, 270)
*   - resourcesObjectId: Resources object ID / ID do objeto Resources
*   - contentsObjectId: Contents object ID / ID do objeto Contents
*
* Example / Exemplo:
*   DECLARE
*     l_info JSON_OBJECT_T;
*   BEGIN
*     PL_FPDF.LoadPDF(l_pdf);
*     l_info := PL_FPDF.GetPageInfo(1);
*     DBMS_OUTPUT.PUT_LINE('MediaBox: ' || l_info.get_string('mediaBox'));
*     DBMS_OUTPUT.PUT_LINE('Rotation / Rotação: ' || l_info.get_number('rotation'));
*   END;
*******************************************************************************/
FUNCTION GetPageInfo(p_page_number PLS_INTEGER) RETURN JSON_OBJECT_T;

/*******************************************************************************
* Procedure: RotatePage / Rotacionar Página
*
* Description / Descrição:
*   EN: Rotate a specific page (stored in memory, applied on output)
*   PT: Rotacionar uma página específica (armazenado em memória, aplicado na saída)
*
* Parameters / Parâmetros:
*   p_page_number - Page number to rotate / Número da página para rotacionar
*   p_rotation - Rotation angle / Ângulo de rotação (0, 90, 180, 270)
*
* Note / Nota:
*   EN: Changes stored in memory. Use OutputModifiedPDF() to generate PDF
*   PT: Mudanças armazenadas em memória. Use OutputModifiedPDF() para gerar PDF
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   PL_FPDF.RotatePage(1, 90);    -- Rotate page 1 / Rotacionar página 1
*   PL_FPDF.RotatePage(2, 180);   -- Rotate page 2 / Rotacionar página 2
*******************************************************************************/
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER);

/*******************************************************************************
* Procedure: RemovePage / Remover Página
*
* Description / Descrição:
*   EN: Mark a page for removal from the PDF
*   PT: Marcar uma página para remoção do PDF
*
* Parameters / Parâmetros:
*   p_page_number - Page number to remove / Número da página para remover
*
* Note / Nota:
*   EN: Page marked for removal. Use OutputModifiedPDF() to generate modified PDF
*   PT: Página marcada para remoção. Use OutputModifiedPDF() para gerar PDF modificado
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   PL_FPDF.RemovePage(2);  -- Remove page 2 / Remover página 2
*   PL_FPDF.RemovePage(5);  -- Remove page 5 / Remover página 5
*******************************************************************************/
PROCEDURE RemovePage(p_page_number PLS_INTEGER);

/*******************************************************************************
* Function: GetActivePageCount / Obter Contagem de Páginas Ativas
*
* Description / Descrição:
*   EN: Get count of pages not marked for removal
*   PT: Obter contagem de páginas não marcadas para remoção
*
* Returns / Retorna:
*   PLS_INTEGER - Number of active pages / Número de páginas ativas
*
* Note / Nota:
*   EN: Differs from GetPageCount() which returns original count
*   PT: Difere de GetPageCount() que retorna a contagem original
*
* Example / Exemplo:
*   l_total := PL_FPDF.GetPageCount();        -- Original: 10
*   PL_FPDF.RemovePage(2);
*   l_active := PL_FPDF.GetActivePageCount(); -- Active / Ativas: 9
*******************************************************************************/
FUNCTION GetActivePageCount RETURN PLS_INTEGER;

/*******************************************************************************
* Function: IsPageRemoved / Verificar Se Página Foi Removida
*
* Description / Descrição:
*   EN: Check if a page is marked for removal
*   PT: Verificar se uma página está marcada para remoção
*
* Parameters / Parâmetros:
*   p_page_number - Page number to check / Número da página para verificar
*
* Returns / Retorna:
*   BOOLEAN - TRUE if removed / TRUE se removida, FALSE otherwise / caso contrário
*
* Example / Exemplo:
*   IF PL_FPDF.IsPageRemoved(2) THEN
*     DBMS_OUTPUT.PUT_LINE('Page 2 removed / Página 2 removida');
*   END IF;
*******************************************************************************/
FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN;

/*******************************************************************************
* Function: IsPDFModified / Verificar Se PDF Foi Modificado
*
* Description / Descrição:
*   EN: Check if the loaded PDF has been modified
*   PT: Verificar se o PDF carregado foi modificado
*
* Returns / Retorna:
*   BOOLEAN - TRUE if modified / TRUE se modificado, FALSE otherwise / caso contrário
*
* Note / Nota:
*   EN: Use to determine if OutputModifiedPDF() needs to be called
*   PT: Use para determinar se OutputModifiedPDF() precisa ser chamado
*
* Example / Exemplo:
*   IF PL_FPDF.IsPDFModified() THEN
*     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
*   END IF;
*******************************************************************************/
FUNCTION IsPDFModified RETURN BOOLEAN;

/*******************************************************************************
* Procedure: AddWatermark / Adicionar Marca d'Água
*
* Description / Descrição:
*   EN: Add customizable text watermark to specified pages
*   PT: Adicionar marca d'água de texto personaliz Ada em páginas específicas
*
* Parameters / Parâmetros:
*   p_text - Watermark text / Texto da marca d'água
*   p_opacity - Opacity (0.0 to 1.0) / Opacidade (0.0 a 1.0), default 0.3
*   p_rotation - Rotation angle / Ângulo de rotação
*                (0, 45, 90, 135, 180, 225, 270, 315), default 45
*   p_pages - Page range / Range de páginas: 'ALL', '1-5', '1,3,5', default 'ALL'
*   p_font - Font name / Nome da fonte, default 'Helvetica'
*   p_size - Font size in points / Tamanho da fonte em pontos, default 48
*   p_color - Color name / Nome da cor ('gray', 'red', 'blue'), default 'gray'
*
* Note / Nota:
*   EN: Watermarks stored in memory. Use OutputModifiedPDF() to apply
*   PT: Marcas d'água armazenadas em memória. Use OutputModifiedPDF() para aplicar
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   -- All pages / Todas as páginas
*   PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
*   -- Specific pages / Páginas específicas
*   PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
*   -- Custom style / Estilo personalizado
*   PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1', 'Helvetica', 72, 'green');
*******************************************************************************/
PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_pages VARCHAR2 DEFAULT 'ALL',
  p_font VARCHAR2 DEFAULT 'Helvetica',
  p_size NUMBER DEFAULT 48,
  p_color VARCHAR2 DEFAULT 'gray'
);

/*******************************************************************************
* Function: GetWatermarks / Obter Marcas d'Água
*
* Description / Descrição:
*   EN: Get list of all applied watermarks as JSON array
*   PT: Obter lista de todas as marcas d'água aplicadas como array JSON
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array containing watermark objects with properties:
*                  Array contendo objetos de marca d'água com propriedades:
*     - id: Watermark ID / ID da marca d'água
*     - text: Watermark text / Texto da marca d'água
*     - opacity: Opacity value (0.0-1.0) / Valor de opacidade (0.0-1.0)
*     - rotation: Rotation angle in degrees / Ângulo de rotação em graus
*     - pageRange: Parsed page range (comma-separated) / Range de páginas (separado por vírgulas)
*     - font: Font name / Nome da fonte
*     - fontSize: Font size in points / Tamanho da fonte em pontos
*     - color: Color name / Nome da cor
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*
* Example / Exemplo:
*   DECLARE
*     l_watermarks JSON_ARRAY_T;
*     l_watermark JSON_OBJECT_T;
*   BEGIN
*     PL_FPDF.LoadPDF(l_pdf);
*     PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
*     l_watermarks := PL_FPDF.GetWatermarks();
*     FOR i IN 0..l_watermarks.get_size() - 1 LOOP
*       l_watermark := TREAT(l_watermarks.get(i) AS JSON_OBJECT_T);
*       DBMS_OUTPUT.PUT_LINE('Watermark / Marca d''água: ' ||
*                            l_watermark.get_string('text'));
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION GetWatermarks RETURN JSON_ARRAY_T;

/*******************************************************************************
* Function: OutputModifiedPDF / Gerar PDF Modificado
*
* Description / Descrição:
*   EN: Generate modified PDF with all changes applied (rotations, removals, watermarks)
*   PT: Gerar PDF modificado com todas as alterações aplicadas (rotações, remoções, marcas d'água)
*
* Returns / Retorna:
*   BLOB - Modified PDF document / Documento PDF modificado
*
* Process / Processo:
*   EN: 1. Validates PDF is loaded and modified
*       2. Builds list of active (non-removed) pages
*       3. Generates new PDF structure with modified pages
*       4. Applies rotations to pages
*       5. Rebuilds page tree excluding removed pages
*       6. Generates new xref table and trailer
*   PT: 1. Valida se PDF está carregado e modificado
*       2. Constrói lista de páginas ativas (não removidas)
*       3. Gera nova estrutura PDF com páginas modificadas
*       4. Aplica rotações às páginas
*       5. Reconstrói árvore de páginas excluindo páginas removidas
*       6. Gera nova tabela xref e trailer
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*   -20819: PDF has not been modified (no changes to apply) /
*           PDF não foi modificado (sem alterações para aplicar)
*   -20820: All pages have been removed (cannot generate empty PDF) /
*           Todas as páginas foram removidas (não pode gerar PDF vazio)
*
* Example / Exemplo:
*   DECLARE
*     l_pdf BLOB;
*     l_modified_pdf BLOB;
*   BEGIN
*     -- Load PDF / Carregar PDF
*     SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
*     PL_FPDF.LoadPDF(l_pdf);
*
*     -- Apply modifications / Aplicar modificações
*     PL_FPDF.RotatePage(1, 90);
*     PL_FPDF.RemovePage(3);
*     PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');
*
*     -- Generate modified PDF / Gerar PDF modificado
*     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
*
*     -- Save modified PDF / Salvar PDF modificado
*     UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
*
*     PL_FPDF.ClearPDFCache();
*   END;
*******************************************************************************/
FUNCTION OutputModifiedPDF RETURN BLOB;

/*******************************************************************************
* Procedure: ClearPDFCache / Limpar Cache de PDF
*
* Description / Descrição:
*   EN: Clear loaded PDF from memory and free all cached resources
*   PT: Limpar PDF carregado da memória e liberar todos os recursos em cache
*
* Note / Nota:
*   EN: Always call this after processing a PDF to free memory resources.
*       Clears: loaded PDF, page info, rotations, removed pages, watermarks.
*   PT: Sempre chame isso após processar um PDF para liberar recursos de memória.
*       Limpa: PDF carregado, info páginas, rotações, páginas removidas, marcas d'água.
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   -- Process PDF / Processar PDF
*   l_modified := PL_FPDF.OutputModifiedPDF();
*   -- Clear memory / Limpar memória
*   PL_FPDF.ClearPDFCache();
*******************************************************************************/
PROCEDURE ClearPDFCache;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

END PL_FPDF;