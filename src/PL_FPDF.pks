CREATE OR REPLACE PACKAGE PL_FPDF AS

subtype word is varchar2(80);

type tv4000a is table of varchar2(4000) index by word;

type point is record (x number, y number);

type tab_points is table of point index by pls_integer;

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

co_version CONSTANT VARCHAR2(10) := '3.4.0';
noParam tv4000a;

procedure Init(
  p_orientation varchar2 default 'P',
  p_unit varchar2 default 'mm',
  p_format varchar2 default 'A4',
  p_encoding varchar2 default 'UTF-8'
);

procedure Reset;

function IsInitialized return boolean
  DETERMINISTIC;

type recPageFormat is record (
  width number(10,5),
  height number(10,5)
);

type recPage is record (
  number_val pls_integer,
  orientation varchar2(1),
  format recPageFormat,
  rotation pls_integer default 0,
  content_clob clob,
  created_at timestamp default systimestamp
);

type tPages is table of recPage index by pls_integer;

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
  loaded_at timestamp default systimestamp,

  bbox_xmin number default 0,
  bbox_ymin number default 0,
  bbox_xmax number default 0,
  bbox_ymax number default 0,
  italic_angle number default 0,
  flags pls_integer default 32,
  larguras varchar2(1024)
);

type tTTFFonts is table of recTTFFont index by varchar2(100);

procedure AddTTFFont(
  p_font_name varchar2,
  p_font_blob blob,
  p_encoding varchar2 default 'UTF-8',
  p_embed boolean default true
);

procedure LoadTTFFromFile(
  p_font_name varchar2,
  p_file_path varchar2,
  p_directory varchar2 default 'FONTS_DIR',
  p_encoding varchar2 default 'UTF-8'
);

function IsTTFFontLoaded(p_font_name varchar2) return boolean;

function GetTTFFontInfo(p_font_name varchar2) return recTTFFont;

procedure ClearTTFFontCache;

function UTF8ToPDFString(
  p_text varchar2,
  p_escape boolean default true
) return varchar2;

exc_invalid_orientation EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_orientation, -20001);

exc_invalid_unit EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_unit, -20002);

exc_invalid_encoding EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_encoding, -20003);

exc_not_initialized EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_not_initialized, -20005);

exc_invalid_page_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_page_format, -20101);

exc_page_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_page_not_found, -20106);

exc_font_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_font_not_found, -20201);

exc_invalid_font_file EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_file, -20202);

exc_invalid_font_name EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_name, -20210);

exc_invalid_font_blob EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_blob, -20211);

exc_fora_de_winansi EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_fora_de_winansi, -20203);

exc_invalid_image EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_image, -20301);

exc_image_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_image_not_found, -20302);

exc_unsupported_image_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_unsupported_image_format, -20303);

exc_invalid_directory EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_directory, -20401);

exc_file_access_denied EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_access_denied, -20402);

exc_file_write_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_write_error, -20403);

exc_link_nao_suportado EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_link_nao_suportado, -20601);

exc_invalid_color EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_color, -20501);

exc_invalid_line_width EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_line_width, -20502);

exc_general_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_general_error, -20100);

function GetCurrentFontSize return number;

function GetCurrentFontStyle return varchar2;

function GetCurrentFontFamily return varchar2;

procedure SetDash(pblack in number default 0, pwhite in number default 0);

function GetLineSpacing return number;

Procedure SetLineSpacing (pls in number);

procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');

procedure Triangle(px in number, py in number, psize in number,
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

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

procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
);

procedure image ( pFile   in varchar2,
                  pX      in number,
                  pY      in number,
                  pWidth  in number default 0,
                  pHeight in number default 0,
                  pType   in varchar2 default null,
                  pLink   in varchar2 default null);

procedure ImageFromBlob( p_blob  in blob,
                         p_name  in varchar2,
                         pX      in number,
                         pY      in number,
                         pWidth  in number default 0,
                         pHeight in number default 0,
                         pLink   in varchar2 default null);

procedure Output(pname in varchar2 default null, pdest in varchar2 default null);

function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null) return blob;

function OutputBlob return blob;

procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

procedure OpenPDF;

procedure ClosePDF;

procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
);

procedure SetPage(p_page_number pls_integer);

function GetCurrentPage return pls_integer
  DETERMINISTIC;

procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');

procedure Error(pmsg in varchar2);

procedure DebugEnabled;

procedure DebugDisabled;

function GetScaleFactor return number;

function getImageFromUrl(p_Url in varchar2) return recImageBlob;

procedure SetLogLevel(p_level pls_integer);

function GetLogLevel return pls_integer
  DETERMINISTIC;

procedure SetDocumentConfig(p_config JSON_OBJECT_T);

function GetDocumentMetadata return JSON_OBJECT_T;

function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T;

procedure AddQRCode(
  p_x number,
  p_y number,
  p_size number,
  p_data varchar2,
  p_format varchar2 default 'TEXT',
  p_error_correction varchar2 default 'M'
);

procedure AddBarcode(
  p_x number,
  p_y number,
  p_width number,
  p_height number,
  p_code varchar2,
  p_type varchar2 default 'CODE128',
  p_show_text boolean default true
);

PROCEDURE LoadPDF(p_pdf_blob BLOB);

FUNCTION GetPageCount RETURN PLS_INTEGER;

FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;

PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER);

PROCEDURE RemovePage(p_page_number PLS_INTEGER);

FUNCTION GetActivePageCount RETURN PLS_INTEGER;

FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN;

FUNCTION IsPDFModified RETURN BOOLEAN;

PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_pages VARCHAR2 DEFAULT 'ALL',
  p_font VARCHAR2 DEFAULT 'Helvetica',
  p_size NUMBER DEFAULT 48,
  p_color VARCHAR2 DEFAULT 'gray'
);

FUNCTION GetWatermarks RETURN JSON_ARRAY_T;

FUNCTION OutputModifiedPDF RETURN BLOB;

PROCEDURE ClearPDFCache;

FUNCTION FlateDecode(
  p_stream    IN BLOB,
  p_max_bytes IN PLS_INTEGER DEFAULT 8388608
) RETURN BLOB;

FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB;

PROCEDURE OverlayText(
  p_page_number IN PLS_INTEGER,
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

PROCEDURE OverlayImage(
  p_page_number IN PLS_INTEGER,
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER DEFAULT NULL,
  p_height IN NUMBER DEFAULT NULL,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T;

PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2);

PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL);

PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
);

FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T;

PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);

FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T;

FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

FUNCTION EncryptPDF(
  p_pdf IN BLOB,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL,
  p_permissions IN JSON_OBJECT_T DEFAULT NULL,
  p_encryption IN VARCHAR2 DEFAULT 'RC4-128'
) RETURN BLOB;

FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB;

FUNCTION IsEncrypted(p_pdf IN BLOB) RETURN BOOLEAN;

FUNCTION GetSecurityInfo(p_pdf IN BLOB) RETURN JSON_OBJECT_T;

PROCEDURE SetEncryption(
  p_encryption IN VARCHAR2,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL
);

PROCEDURE SetPDFVersion(p_version IN VARCHAR2);

FUNCTION GetPDFVersion RETURN VARCHAR2;

PROCEDURE SetPermissions(
  p_print IN BOOLEAN DEFAULT TRUE,
  p_modify IN BOOLEAN DEFAULT FALSE,
  p_copy IN BOOLEAN DEFAULT FALSE,
  p_annotate IN BOOLEAN DEFAULT TRUE,
  p_fill_forms IN BOOLEAN DEFAULT TRUE,
  p_extract IN BOOLEAN DEFAULT FALSE,
  p_assemble IN BOOLEAN DEFAULT FALSE,
  p_print_high IN BOOLEAN DEFAULT TRUE
);

END PL_FPDF;
/
