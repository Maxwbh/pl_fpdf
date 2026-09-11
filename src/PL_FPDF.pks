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

/**
 * PT: Prepara o gerador para um documento novo. Substitui o construtor legado
 *     fpdf(), acrescentando validação dos argumentos e os buffers em CLOB.
 *     Chamar de novo com um documento em andamento descarta o anterior.
 *
 * EN: Prepares the engine for a new document. Replaces the legacy fpdf()
 *     constructor, adding argument validation and the CLOB buffers. Calling it
 *     again discards the document in progress.
 *
 * @param p_orientation orientação da página / page orientation: 'P' (Portrait,
 *        retrato) ou 'L' (Landscape, paisagem)
 * @param p_unit unidade de medida / measurement unit ('mm', 'cm', 'in', 'pt')
 * @param p_format formato da página / page format ('A4', 'Letter', 'Legal')
 * @param p_encoding codificação de entrada / input encoding
 * @raises -20001 orientação inválida / invalid orientation
 * @raises -20002 unidade de medida inválida / invalid measurement unit
 * @raises -20003 codificação não suportada / unsupported encoding
 * @example
 *   PL_FPDF.Init('P', 'mm', 'A4');
 */
procedure Init(
  p_orientation varchar2 default 'P',
  p_unit varchar2 default 'mm',
  p_format varchar2 default 'A4',
  p_encoding varchar2 default 'UTF-8'
);

/**
 * PT: Devolve o package ao estado inicial: libera os CLOBs temporários e
 *     esvazia todas as tabelas de estado (fontes, imagens, links, metadados,
 *     mudanças de orientação). O package tem estado de sessão, e quem gera
 *     documentos em lote precisa chamar isto entre um e outro — sem isso, a
 *     configuração de um vaza para o seguinte.
 *
 * EN: Returns the package to its initial state: frees the temporary CLOBs and
 *     empties every state table (fonts, images, links, metadata, orientation
 *     changes). Package state is per session, so batch callers must call this
 *     between documents or one leaks into the next.
 *
 * @example
 *   PL_FPDF.Reset;
 */
procedure Reset;

/**
 * PT: Diz se Init (ou fpdf) já foi chamado nesta sessão.
 *
 * EN: Tells whether Init (or fpdf) has already been called in this session.
 *
 * @return BOOLEAN - TRUE se inicializado / TRUE when initialized
 * @example
 *   IF NOT PL_FPDF.IsInitialized THEN PL_FPDF.Init; END IF;
 */
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

/**
 * PT: Registra uma fonte TrueType a partir de um BLOB e a deixa disponível
 *     para o SetFont, pelo nome dado aqui. As tabelas do arquivo são lidas de
 *     verdade -- head, hhea, hmtx, cmap, OS/2 e post --, e a fonte vai
 *     embutida no PDF como /FontFile2. O arquivo cresce: o programa da fonte
 *     sai em hexadecimal, então ocupa o DOBRO do tamanho dela, e ainda não há
 *     subset (ver docs/ROADMAP.md). Para texto em português com acento não é
 *     preciso embutir nada: as fontes padrão escrevem acentuado desde a 3.4.0.
 *
 * EN: Registers a TrueType font from a BLOB and makes it available to SetFont
 *     under the name given here. The file's tables are really parsed -- head,
 *     hhea, hmtx, cmap, OS/2 and post -- and the font is embedded in the PDF
 *     as /FontFile2. The file grows: the font program goes out as hexadecimal,
 *     so it takes TWICE its size, and there is no subsetting yet (see
 *     docs/ROADMAP.md). Accented Portuguese needs no embedded font: the core
 *     fonts handle it since 3.4.0.
 *
 * @param p_font_name nome pelo qual SetFont a chamará / name used by SetFont
 * @param p_font_blob o arquivo .ttf / the .ttf file
 * @param p_encoding codificação da fonte / font encoding
 * @param p_embed embutir no PDF / embed in the PDF
 * @raises -20210 nome da fonte vazio / font name is null or empty
 * @raises -20211 BLOB da fonte nulo / font BLOB is null
 * @example
 *   SELECT arquivo INTO l_ttf FROM fontes WHERE nome = 'Roboto';
 *   PL_FPDF.AddTTFFont('Roboto', l_ttf);
 */
procedure AddTTFFont(
  p_font_name varchar2,
  p_font_blob blob,
  p_encoding varchar2 default 'UTF-8',
  p_embed boolean default true
);

/**
 * PT: Lê um .ttf de um DIRECTORY do banco e o registra como o AddTTFFont.
 *     Exige READ no diretório concedido ao schema; sem isso, AddTTFFont recebe
 *     os bytes direto, sem concessão nenhuma.
 *
 * EN: Reads a .ttf from a database DIRECTORY and registers it like AddTTFFont.
 *     Requires READ on that directory; without it, AddTTFFont takes the bytes
 *     directly, with no grant at all.
 *
 * @param p_font_name nome pelo qual SetFont a chamará / name used by SetFont
 * @param p_file_path nome do arquivo / file name
 * @param p_directory DIRECTORY do banco / database DIRECTORY object
 * @param p_encoding codificação da fonte / font encoding
 * @raises -20202 arquivo de fonte inválido / invalid font file
 * @raises -20401 diretório inválido / invalid directory
 * @raises -20402 sem permissão de leitura / read access denied
 * @example
 *   PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');
 */
procedure LoadTTFFromFile(
  p_font_name varchar2,
  p_file_path varchar2,
  p_directory varchar2 default 'FONTS_DIR',
  p_encoding varchar2 default 'UTF-8'
);

/**
 * PT: Diz se a fonte está registrada nesta sessão, e portanto disponível para
 *     o SetFont. O nome não diferencia maiúsculas de minúsculas.
 *
 * EN: Tells whether the font is registered in this session, and therefore
 *     available to SetFont. The name is case-insensitive.
 *
 * @param p_font_name nome da fonte / font name
 * @return BOOLEAN - TRUE se carregada / TRUE when loaded
 * @example
 *   IF NOT PL_FPDF.IsTTFFontLoaded('Roboto') THEN ... END IF;
 */
function IsTTFFontLoaded(p_font_name varchar2) return boolean;

/**
 * PT: Devolve o registro da fonte: os bytes guardados e as métricas lidas do
 *     arquivo -- unidades por em, ascendente, descendente, altura de caixa
 *     alta, a caixa e o ângulo do itálico. Tudo já reescalado para as 1000
 *     unidades por em do PDF, menos o units_per_em, que é o do arquivo.
 *
 * EN: Returns the font record: the stored bytes and the metrics parsed from
 *     the file -- units per em, ascent, descent, cap height, the box and the
 *     italic angle. All rescaled to the PDF's 1000 units per em, except
 *     units_per_em itself, which is the file's.
 *
 * @param p_font_name nome da fonte / font name
 * @return recTTFFont - as métricas da fonte / the font metrics
 * @raises -20206 fonte não carregada / font not loaded
 * @example
 *   l_fonte := PL_FPDF.GetTTFFontInfo('Roboto');
 */
function GetTTFFontInfo(p_font_name varchar2) return recTTFFont;

/**
 * PT: Descarrega as fontes TrueType e libera os LOBs temporários delas. Vale
 *     chamar ao fim de um lote: cada fonte embutida ocupa centenas de KB na
 *     sessão.
 *
 * EN: Unloads the TrueType fonts and frees their temporary LOBs. Worth calling
 *     at the end of a batch: each embedded font holds hundreds of KB in the
 *     session.
 *
 * @example
 *   PL_FPDF.ClearTTFFontCache;
 */
procedure ClearTTFFontCache;

/**
 * PT: Escapa os caracteres que a sintaxe de string do PDF reserva -- o
 *     parêntese e a barra invertida. NÃO converte codificação: quem escreve
 *     texto pelas rotinas normais (Cell, Write, Text) não precisa chamar isto,
 *     porque a conversão para WinAnsi já acontece lá dentro.
 *
 * EN: Escapes the characters reserved by the PDF string syntax -- parenthesis
 *     and backslash. It does NOT convert encoding: callers of the normal text
 *     routines (Cell, Write, Text) need not call this, since the WinAnsi
 *     conversion already happens inside them.
 *
 * @param p_text o texto / the text
 * @param p_escape escapar os caracteres reservados / escape reserved
 *        characters
 * @return VARCHAR2 - o texto pronto para ir entre parênteses num objeto PDF /
 *         text ready to sit inside parentheses in a PDF object
 * @example
 *   l_txt := PL_FPDF.UTF8ToPDFString('Total (liquido)');
 */
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

/**
 * PT: Devolve o corpo da fonte em uso, em pontos.
 *
 * EN: Returns the current font size, in points.
 *
 * @return NUMBER - o tamanho em pontos / size in points
 * @example
 *   l_corpo := PL_FPDF.GetCurrentFontSize;
 */
function GetCurrentFontSize return number;

/**
 * PT: Devolve o estilo em uso: '' (normal), 'B' (Bold, negrito), 'I' (Italic,
 *     itálico), 'U' (Underline, sublinhado) ou a combinação. Sempre em
 *     MAIÚSCULA: o SetFont normaliza, então 'b' entra e 'B' volta.
 *
 * EN: Returns the current style: '' (regular), 'B' (bold), 'I' (italic), 'U'
 *     (underline), or a combination. Always UPPERCASE: SetFont normalises it,
 *     so 'b' goes in and 'B' comes back.
 *
 * @return VARCHAR2 - o estilo corrente / the current style
 * @example
 *   l_estilo := PL_FPDF.GetCurrentFontStyle;
 */
function GetCurrentFontStyle return varchar2;

/**
 * PT: Devolve o nome da família em uso. Sempre em MINÚSCULA: o SetFont
 *     normaliza, então 'Times' entra e 'times' volta. Comparar com 'Times'
 *     nunca casa -- use LOWER() dos dois lados.
 *
 * EN: Returns the current font family. Always LOWERCASE: SetFont normalises
 *     it, so 'Times' goes in and 'times' comes back. Comparing against 'Times'
 *     never matches -- use LOWER() on both sides.
 *
 * @return VARCHAR2 - a família corrente / the current family
 * @example
 *   l_familia := PL_FPDF.GetCurrentFontFamily;
 */
function GetCurrentFontFamily return varchar2;

/**
 * PT: Passa a desenhar linha tracejada, com o comprimento do traço e o do
 *     intervalo na unidade corrente. Os dois em zero voltam à linha cheia.
 *     Vale para tudo o que for desenhado depois, até ser trocado.
 *
 * EN: Switches to a dashed line, giving the dash and gap lengths in the
 *     current unit. Both at zero restores a solid line. It applies to
 *     everything drawn afterwards, until changed.
 *
 * @param pblack comprimento do traço / dash length
 * @param pwhite comprimento do intervalo / gap length
 * @example
 *   PL_FPDF.SetDash(2, 2);          -- tracejado / dashed
 *   PL_FPDF.Line(10, 50, 200, 50);
 *   PL_FPDF.SetDash;                -- volta à linha cheia / back to solid
 */
procedure SetDash(pblack in number default 0, pwhite in number default 0);

/**
 * PT: Devolve a entrelinha usada pelo MultiCell quando a altura da linha vai
 *     em branco.
 *
 * EN: Returns the line spacing MultiCell uses when the line height is left
 *     empty.
 *
 * @return NUMBER - a entrelinha, na unidade corrente / line spacing, current
 *         unit
 * @example
 *   l_entre := PL_FPDF.GetLineSpacing;
 */
function GetLineSpacing return number;

/**
 * PT: Define a entrelinha do MultiCell para quando a altura da linha não for
 *     informada.
 *
 * EN: Sets the line spacing MultiCell uses when no line height is given.
 *
 * @param pls a entrelinha, na unidade corrente / line spacing, current unit
 * @example
 *   PL_FPDF.SetLineSpacing(5);
 */
Procedure SetLineSpacing (pls in number);

/**
 * PT: Desenha um polígono ligando os pontos na ordem da tabela, que precisa
 *     começar no índice 0. Fechado, o último ponto liga de volta ao primeiro.
 *
 * EN: Draws a polygon joining the points in table order; the table must start
 *     at index 0. When closed, the last point joins back to the first.
 *
 * @param points os vértices, indexados a partir de 0 / vertices, indexed from
 *        0
 * @param pclose fechar o contorno / close the outline
 * @param pstyle '' desenha o contorno (padrão), 'F' preenche (Fill), 'FD' ou
 *        'DF' preenche e contorna (Fill and Draw) / '' outlines (default), 'F'
 *        fills, 'FD'/'DF' fills and outlines
 * @example
 *   l_pontos(0).x := 10; l_pontos(0).y := 10;
 *   l_pontos(1).x := 50; l_pontos(1).y := 10;
 *   l_pontos(2).x := 30; l_pontos(2).y := 40;
 *   PL_FPDF.Poly(l_pontos, TRUE, 'F');
 */
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');

/**
 * PT: Desenha um triângulo isósceles de base 2*psize e altura psize, com a
 *     ponta virada para porientation. (px, py) é o canto superior esquerdo da
 *     caixa que envolve o triângulo, e não o vértice.
 *
 * EN: Draws an isosceles triangle with base 2*psize and height psize, apex
 *     pointing towards porientation. (px, py) is the top-left corner of the
 *     bounding box, not the apex.
 *
 * @param px canto superior esquerdo da caixa / top-left of bounding box
 * @param py canto superior esquerdo da caixa / top-left of bounding box
 * @param psize metade da base, e a altura / half the base, and the height
 * @param porientation para onde aponta / where the apex points: 'up'/'U',
 *        'down'/'D', 'left'/'L', 'right'/'R'
 * @param pstyle '' contorna, 'F' preenche (Fill), 'FD'/'DF' os dois / ''
 *        outlines, 'F' fills, 'FD'/'DF' both
 * @raises -20821 orientação inválida / invalid orientation
 * @example
 *   PL_FPDF.Triangle(20, 20, 5, 'right', 'F');
 */
procedure Triangle(px in number, py in number, psize in number,
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

/**
 * PT: Escreve o operador 'd' do PDF direto no fluxo de conteúdo, para quem
 *     precisa de um padrão que o SetDash não monta. O texto vai como está, e
 *     um padrão malformado só aparece no leitor. Prefira SetDash.
 *
 * EN: Writes the PDF 'd' operator straight into the content stream, for
 *     patterns SetDash cannot build. The text goes through verbatim, and a
 *     malformed pattern only shows up in the reader. Prefer SetDash.
 *
 * @param pdash o padrão, na sintaxe do PDF / the pattern in PDF syntax ('[] 0'
 *        = linha cheia / solid)
 * @example
 *   PL_FPDF.SetLineDashPattern('[3 2] 0');
 */
procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

/**
 * PT: Vai para a linha seguinte: leva o x de volta à margem esquerda e desce o
 *     y. Sem altura, desce o da última célula escrita.
 *
 * EN: Moves to the next line: x goes back to the left margin and y moves down.
 *     With no height given, it uses the last cell's height.
 *
 * @param h quanto descer, na unidade corrente / how far down, in the current
 *        unit
 * @example
 *   PL_FPDF.Cell(40, 10, 'Primeira');
 *   PL_FPDF.Ln;
 */
procedure Ln(h number default null);

/**
 * PT: Devolve a abscissa corrente, na unidade em uso.
 *
 * EN: Returns the current abscissa, in the current unit.
 *
 * @return NUMBER - o x corrente / the current x
 * @example
 *   l_x := PL_FPDF.GetX;
 */
function  GetX return number;

/**
 * PT: Move a abscissa. Valor negativo conta a partir da borda direita:
 *     SetX(-30) põe o cursor a 30 da direita.
 *
 * EN: Moves the abscissa. A negative value counts from the right edge:
 *     SetX(-30) puts the cursor 30 from the right.
 *
 * @param px a nova abscissa / the new abscissa
 * @example
 *   PL_FPDF.SetX(-40);
 */
procedure SetX(px in number);

/**
 * PT: Devolve a ordenada corrente, contada do topo da página.
 *
 * EN: Returns the current ordinate, measured from the top of the page.
 *
 * @return NUMBER - o y corrente / the current y
 * @example
 *   l_y := PL_FPDF.GetY;
 */
function  GetY return number;

/**
 * PT: Move a ordenada E devolve o x à margem esquerda -- é o efeito que
 *     surpreende quem só queria descer. Para mover os dois sem esse efeito,
 *     use SetXY. Valor negativo conta a partir do pé da página.
 *
 * EN: Moves the ordinate AND resets x to the left margin -- the surprise for
 *     callers who only meant to move down. To move both without that, use
 *     SetXY. A negative value counts from the bottom of the page.
 *
 * @param py a nova ordenada / the new ordinate
 * @example
 *   PL_FPDF.SetY(-20);   -- 20 acima do pé / 20 above the bottom
 */
procedure SetY(py in number);

/**
 * PT: Move as duas coordenadas. Ao contrário do SetY sozinho, o x informado é
 *     respeitado.
 *
 * EN: Moves both coordinates. Unlike SetY on its own, the x given here is
 *     honoured.
 *
 * @param x a abscissa / the abscissa
 * @param y a ordenada / the ordinate
 * @example
 *   PL_FPDF.SetXY(20, 50);
 */
procedure SetXY(x in number,y in number);

/**
 * PT: Registra o NOME de uma rotina que será executada no início de cada
 *     página. O nome e os nomes dos parâmetros são validados como
 *     identificadores SQL (DBMS_ASSERT) aqui, na configuração -- e não no meio
 *     do relatório, que é onde um nome inválido apareceria. O bloco é montado
 *     uma vez só, e não a cada página.
 *
 * EN: Registers the NAME of a routine to run at the start of every page. The
 *     name and the parameter names are validated as SQL identifiers
 *     (DBMS_ASSERT) here, at configuration time, rather than halfway through
 *     the report. The block is built once, not per page.
 *
 * @param headerprocname nome da rotina / routine name (NULL desliga /
 *        disables)
 * @param paramTable parâmetros nomeados / named parameters
 * @example
 *   PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');
 */
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam);

/**
 * PT: Como SetHeaderProc, para o rodapé: a rotina é executada ao fechar cada
 *     página, e é onde costuma entrar o "página N de {nb}".
 *
 * EN: Like SetHeaderProc, for the footer: the routine runs as each page is
 *     closed, and is where "page N of {nb}" usually goes.
 *
 * @param footerprocname nome da rotina / routine name (NULL desliga /
 *        disables)
 * @param paramTable parâmetros nomeados / named parameters
 * @example
 *   PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');
 */
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam);

/**
 * PT: Define as margens esquerda, superior e direita. A direita em branco fica
 *     igual à esquerda.
 *
 * EN: Sets the left, top and right margins. Leaving the right one out makes it
 *     equal to the left.
 *
 * @param left margem esquerda / left margin
 * @param top margem superior / top margin
 * @param right margem direita / right margin (-1 = igual à esquerda / same as
 *        left)
 * @example
 *   PL_FPDF.SetMargins(20, 15);
 */
procedure SetMargins(left in number, top in number, right in number default -1);

/**
 * PT: Define a margem esquerda. Com página já aberta e o cursor à esquerda da
 *     margem nova, o cursor é trazido para ela.
 *
 * EN: Sets the left margin. With a page already open and the cursor to the
 *     left of the new margin, the cursor is moved onto it.
 *
 * @param pMargin a margem, na unidade corrente / the margin, in the current
 *        unit
 * @example
 *   PL_FPDF.SetLeftMargin(25);
 */
procedure SetLeftMargin(pMargin in number);

/**
 * PT: Define a margem superior, usada pelas páginas seguintes.
 *
 * EN: Sets the top margin, used by the pages that follow.
 *
 * @param pMargin a margem, na unidade corrente / the margin, in the current
 *        unit
 * @example
 *   PL_FPDF.SetTopMargin(15);
 */
procedure SetTopMargin(pMargin in number);

/**
 * PT: Define a margem direita, que é o que limita a largura de uma célula
 *     pedida com largura 0.
 *
 * EN: Sets the right margin, which is what bounds a cell asked for with width
 *     0.
 *
 * @param pMargin a margem, na unidade corrente / the margin, in the current
 *        unit
 * @example
 *   PL_FPDF.SetRightMargin(20);
 */
procedure SetRightMargin(pMargin in number);

/**
 * PT: Liga ou desliga a quebra automática e define a margem de rodapé que a
 *     dispara. Desligada, o conteúdo que passar do fim da página é escrito
 *     fora dela e some -- sem erro nenhum.
 *
 * EN: Turns automatic page breaking on or off and sets the bottom margin that
 *     triggers it. With it off, content past the end of the page is written
 *     outside it and disappears -- with no error at all.
 *
 * @param pauto ligar a quebra automática / enable automatic breaking
 * @param pMargin margem de rodapé que dispara / bottom margin that triggers it
 * @example
 *   PL_FPDF.SetAutoPageBreak(TRUE, 20);
 */
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0);

/**
 * PT: Diz ao leitor de PDF como abrir o documento. É preferência de
 *     apresentação: o leitor pode ignorar.
 *
 * EN: Tells the PDF reader how to open the document. It is a presentation
 *     hint: the reader may ignore it.
 *
 * @param zoom 'fullpage' (página inteira), 'fullwidth' (largura da página),
 *        'real' (tamanho real), 'default' (padrão do leitor), ou um número que
 *        é o percentual de ampliação / 'fullpage', 'fullwidth', 'real',
 *        'default', or a number taken as a zoom percentage
 * @param layout 'single' (uma página), 'continuous' (contínuo), 'two' (duas
 *        colunas), 'default' (padrão do leitor) / 'single', 'continuous',
 *        'two', 'default'
 * @raises -20100 modo de zoom ou de layout desconhecido / unknown zoom or
 *         layout mode
 * @example
 *   PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
 */
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous');

/**
 * PT: Liga a compressão dos fluxos de conteúdo. Até agosto/2026 isto não fazia
 *     nada -- procurava uma rotina de zlib que o Oracle não tem e desligava
 *     sempre. Hoje o deflate está escrito no próprio pacote
 *     (PL_FPDF_UTIL.deflate) e a opção vale.
 *
 * EN: Turns on content-stream compression. Until August 2026 this did nothing
 *     -- it looked for a zlib routine Oracle does not have and always turned
 *     compression off. Deflate now lives in the package itself
 *     (PL_FPDF_UTIL.deflate) and the setting has effect.
 *
 * @param p_compress comprimir os fluxos / compress the streams
 * @example
 *   PL_FPDF.SetCompression(TRUE);
 */
procedure SetCompression(p_compress in boolean default false);

/**
 * PT: Grava o título nos metadados do PDF -- o que o leitor mostra na barra de
 *     título e o que o buscador indexa.
 *
 * EN: Records the title in the PDF metadata -- what the reader shows in its
 *     title bar and what search engines index.
 *
 * @param ptitle o título / the title
 * @example
 *   PL_FPDF.SetTitle('Relatório de Produção');
 */
procedure SetTitle(ptitle in varchar2);

/**
 * PT: Grava o assunto nos metadados do PDF.
 *
 * EN: Records the subject in the PDF metadata.
 *
 * @param psubject o assunto / the subject
 * @example
 *   PL_FPDF.SetSubject('Fechamento mensal');
 */
procedure SetSubject(psubject in varchar2);

/**
 * PT: Grava o autor nos metadados do PDF.
 *
 * EN: Records the author in the PDF metadata.
 *
 * @param pauthor o autor / the author
 * @example
 *   PL_FPDF.SetAuthor('Departamento Financeiro');
 */
procedure SetAuthor(pauthor in varchar2);

/**
 * PT: Grava as palavras-chave nos metadados do PDF, separadas por espaço.
 *
 * EN: Records the keywords in the PDF metadata, separated by spaces.
 *
 * @param pkeywords as palavras-chave / the keywords
 * @example
 *   PL_FPDF.SetKeywords('relatorio producao 2026');
 */
procedure SetKeywords(pkeywords in varchar2);

/**
 * PT: Grava, nos metadados, o nome do sistema que gerou o documento.
 *
 * EN: Records, in the metadata, the name of the system that produced the
 *     document.
 *
 * @param pcreator o sistema gerador / the producing system
 * @example
 *   PL_FPDF.SetCreator('ERP - modulo de faturamento');
 */
procedure SetCreator(pcreator in varchar2);

/**
 * PT: Define o texto que será trocado pelo total de páginas na hora de fechar
 *     o documento. É como se escreve "página 3 de 12" sem saber o 12 enquanto
 *     se escreve a página 3.
 *
 * EN: Sets the placeholder to be replaced by the page count when the document
 *     is closed. It is how "page 3 of 12" gets written without knowing the 12
 *     while page 3 is being written.
 *
 * @param palias o marcador / the placeholder
 * @example
 *   PL_FPDF.SetAliasNbPages;
 *   PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo || ' de {nb}');
 */
procedure SetAliasNbPages(palias in varchar2 default '{nb}');

/**
 * PT: Executa a rotina registrada em SetHeaderProc. É chamada sozinha ao abrir
 *     cada página; não se chama à mão.
 *
 * EN: Runs the routine registered with SetHeaderProc. It is called on its own
 *     as each page opens; it is not meant to be called by hand.
 *
 * @example
 *   PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');   -- e o resto é automático
 */
procedure Header;

/**
 * PT: Executa a rotina registrada em SetFooterProc. É chamada sozinha ao
 *     fechar cada página; não se chama à mão.
 *
 * EN: Runs the routine registered with SetFooterProc. It is called on its own
 *     as each page closes; it is not meant to be called by hand.
 *
 * @example
 *   PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');      -- e o resto é automático
 */
procedure Footer;

/**
 * PT: Devolve o número da página que está sendo escrita, começando em 1.
 *
 * EN: Returns the number of the page being written, starting at 1.
 *
 * @return NUMBER - a página corrente / the current page
 * @example
 *   PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo);
 */
function  PageNo return number;

/**
 * PT: Define a cor com que se desenham linhas, contornos e bordas de célula.
 *     Com um argumento só, é tom de cinza (0 preto, 255 branco); com três, é
 *     RGB. Vale do ponto em que é chamada em diante.
 *
 * EN: Sets the colour used for lines, outlines and cell borders. With one
 *     argument it is a grey level (0 black, 255 white); with three it is RGB.
 *     It applies from the call onwards.
 *
 * @param r vermelho, ou o nível de cinza / red, or the grey level (0..255)
 * @param g verde / green (0..255)
 * @param b azul / blue (0..255)
 * @raises -20501 componente fora de 0..255 / component outside 0..255
 * @example
 *   PL_FPDF.SetDrawColor(200);            -- cinza claro / light grey
 *   PL_FPDF.SetDrawColor(0, 90, 160);     -- azul / blue
 */
procedure SetDrawColor(r in number, g in number default -1, b in number default -1);

/**
 * PT: Define a cor de fundo das células preenchidas e das formas com estilo
 *     'F'. Um argumento é cinza, três são RGB.
 *
 * EN: Sets the background colour of filled cells and of shapes drawn with
 *     style 'F'. One argument is grey, three are RGB.
 *
 * @param r vermelho, ou o nível de cinza / red, or the grey level (0..255)
 * @param g verde / green (0..255)
 * @param b azul / blue (0..255)
 * @raises -20501 componente fora de 0..255 / component outside 0..255
 * @example
 *   PL_FPDF.SetFillColor(230, 230, 230);
 *   PL_FPDF.Cell(40, 8, 'Cabecalho', '1', 0, 'C', 1);
 */
procedure SetFillColor (r in number, g in number default -1, b in number default -1);

/**
 * PT: Define a cor do texto. Um argumento é cinza, três são RGB.
 *
 * EN: Sets the text colour. One argument is grey, three are RGB.
 *
 * @param r vermelho, ou o nível de cinza / red, or the grey level (0..255)
 * @param g verde / green (0..255)
 * @param b azul / blue (0..255)
 * @raises -20501 componente fora de 0..255 / component outside 0..255
 * @example
 *   PL_FPDF.SetTextColor(180, 0, 0);
 */
procedure SetTextColor (r in number, g in number default -1, b in number default -1);

/**
 * PT: Define a espessura do traço, na unidade corrente.
 *
 * EN: Sets the line width, in the current unit.
 *
 * @param width a espessura, maior que zero / the width, greater than zero
 * @raises -20502 espessura zero ou negativa / width is zero or negative
 * @example
 *   PL_FPDF.SetLineWidth(0.5);
 */
procedure SetLineWidth(width in number);

/**
 * PT: Desenha um segmento de reta entre dois pontos, com a cor e a espessura
 *     correntes.
 *
 * EN: Draws a straight segment between two points, using the current colour
 *     and width.
 *
 * @param x1 ponto inicial / start point
 * @param y1 ponto inicial / start point
 * @param x2 ponto final / end point
 * @param y2 ponto final / end point
 * @example
 *   PL_FPDF.Line(20, 60, 190, 60);
 */
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number);

/**
 * PT: Desenha um retângulo a partir do canto superior esquerdo.
 *
 * EN: Draws a rectangle from its top-left corner.
 *
 * @param px canto superior esquerdo / top-left corner
 * @param py canto superior esquerdo / top-left corner
 * @param pw largura / width
 * @param ph altura / height
 * @param pstyle '' contorna (padrão), 'F' preenche (Fill), 'FD' ou 'DF'
 *        preenche e contorna (Fill and Draw) / '' outlines (default), 'F'
 *        fills, 'FD'/'DF' fills and outlines
 * @example
 *   PL_FPDF.Rect(20, 40, 60, 25, 'FD');
 */
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '');

/**
 * PT: RECUSA com -20601. Criaria um link interno, e link interno não está
 *     implementado: o /Dest nunca chegou a ser escrito no arquivo, então o
 *     identificador que esta função devolveria não levaria a lugar nenhum -- e
 *     o Link o recusa. Até setembro/2026 a chamada levantava ORA-06531,
 *     "reference to uninitialized collection", porque a coleção interna nunca
 *     foi inicializada: nunca funcionou, em nenhuma versão. Passa a recusar
 *     com mensagem que diz o que usar no lugar.
 *
 * EN: REFUSES with -20601. It would create an internal link, and internal
 *     links are not implemented: the /Dest was never written to the file, so
 *     the identifier this function would return leads nowhere -- and Link
 *     refuses it. Until September 2026 the call raised ORA-06531, "reference
 *     to uninitialized collection", because the internal collection was never
 *     initialised: it never worked, in any version. It now refuses with a
 *     message that says what to use instead.
 *
 * @return NUMBER - nunca devolve: levanta antes / never returns: it raises
 *         first
 * @raises -20601 link interno não implementado / internal links not
 *         implemented
 * @example
 *   -- Use URL / use a URL:
 *   PL_FPDF.Cell(60, 8, 'Site', plink => 'https://example.com');
 */
function  AddLink return number;

/**
 * PT: RECUSA com -20601, pelo mesmo motivo do AddLink: guardar o destino não
 *     adiantaria, porque o /Dest não é emitido e ninguém o lê. Até
 *     setembro/2026 levantava ORA-06531.
 *
 * EN: REFUSES with -20601, for the same reason as AddLink: storing the
 *     destination would achieve nothing, since the /Dest is never emitted and
 *     nobody reads it. Until September 2026 it raised ORA-06531.
 *
 * @param plink identificador devolvido por AddLink / identifier from AddLink
 * @param py ordenada de chegada / destination ordinate (-1 = a posição
 *        corrente / the current position)
 * @param ppage página de chegada / destination page (-1 = a página corrente /
 *        the current page)
 * @raises -20601 link interno não implementado / internal links not
 *         implemented
 * @example
 *   -- Use URL / use a URL:
 *   PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
 */
procedure SetLink(plink in number, py in number default 0, ppage in number default -1);

/**
 * PT: Marca uma área retangular como clicável, levando a uma URL.
 *
 * EN: Marks a rectangular area as clickable, pointing at a URL.
 *
 * @param px canto superior esquerdo da área / top-left of the area
 * @param py canto superior esquerdo da área / top-left of the area
 * @param pw largura / width
 * @param ph altura / height
 * @param plink a URL / the URL
 * @limitation PT: 1. Uma área por página. Uma segunda chamada na mesma página
 *             substitui a primeira, em silêncio -- a estrutura guarda um
 *             registro por página. Documentado por ser assim, não por ser o
 *             desejável. 2. Link interno não é suportado, e é RECUSADO com
 *             -20601. O ramo que escreveria o /Dest saiu comentado no porte
 *             original e nunca voltou; emiti-lo assim produzia um /Annot com o
 *             dicionário aberto, isto é, arquivo malformado. Desde
 *             setembro/2026 a chamada levanta erro em vez de gravar o arquivo
 *             quebrado. Use URL.
 * @limitation EN: 1. One area per page. A second call on the same page
 *             silently replaces the first -- the structure holds one record
 *             per page. Documented because that is how it behaves, not because
 *             it is desirable. 2. Internal links are not supported and are
 *             REFUSED with -20601. The branch that would write the /Dest was
 *             commented out in the original port and never came back; emitting
 *             it as it stood produced an /Annot with an open dictionary, i.e.
 *             a malformed file. Since September 2026 the call raises instead
 *             of writing the broken file. Use a URL.
 * @example
 *   PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
 * @raises -20601 destino não é URL -- link interno ou NULL / destination is
 *         not a URL -- internal link or NULL
 */
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2);

/**
 * PT: Escreve texto num ponto exato, sem célula, sem quebra e sem mover o
 *     cursor. (px, py) é a LINHA DE BASE do texto, não o topo dele.
 *
 * EN: Writes text at an exact point, with no cell, no wrapping and no cursor
 *     movement. (px, py) is the text BASELINE, not its top.
 *
 * @param px a linha de base / the baseline
 * @param py a linha de base / the baseline
 * @param ptxt o texto / the text
 * @raises -20203 caractere fora do WinAnsi / character outside WinAnsi
 * @example
 *   PL_FPDF.Text(20, 50, 'Endereço de cobrança');
 */
procedure Text(px in number, py in number, ptxt in varchar2);

/**
 * PT: Diz se a quebra automática está ligada. É consultada pelo Cell antes de
 *     decidir abrir página nova.
 *
 * EN: Tells whether automatic page breaking is on. Cell consults it before
 *     deciding to start a new page.
 *
 * @return BOOLEAN - TRUE se a quebra automática está ligada / TRUE when
 *         automatic breaking is on
 * @example
 *   IF PL_FPDF.AcceptPageBreak THEN ... END IF;
 */
function  AcceptPageBreak return boolean;

/**
 * PT: Registra uma fonte para uso pelo SetFont. Para as 14 fontes padrão do
 *     PDF não é preciso chamar isto -- elas já estão disponíveis, e escrevem
 *     acentuado desde a 3.4.0.
 *
 * EN: Registers a font for SetFont to use. The 14 standard PDF fonts need no
 *     such call -- they are always available, and write accented text since
 *     3.4.0.
 *
 * @param family nome da família / family name
 * @param style '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'BI' os
 *        dois / '' regular, 'B' bold, 'I' italic, 'BI' both
 * @param filename arquivo de métricas da fonte / the font metrics file
 * @example
 *   PL_FPDF.AddFont('Arial', 'B');
 */
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '');

/**
 * PT: Escolhe a fonte, o estilo e o corpo do texto que vier depois. Corpo zero
 *     mantém o que já estava. As fontes padrão -- Helvetica, Times, Courier,
 *     Symbol e ZapfDingbats -- não precisam ser carregadas.
 *
 * EN: Chooses the font, style and size for the text that follows. A size of
 *     zero keeps the current one. The standard fonts -- Helvetica, Times,
 *     Courier, Symbol and ZapfDingbats -- need no loading.
 *
 * @param pfamily família / family ('Helvetica', 'Times', 'Courier'...)
 * @param pstyle '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'U'
 *        sublinhado (Underline), ou a combinação / '' regular, 'B' bold, 'I'
 *        italic, 'U' underline, or a mix
 * @param psize corpo em pontos / size in points (0 = mantém / keep current)
 * @note PT: A família é guardada em minúscula e o estilo em maiúscula. É o que
 *       os getters devolvem, e não o texto que entrou aqui.
 * @note EN: The family is stored lowercase and the style uppercase. That is
 *       what the getters return -- not the text passed in here.
 * @raises -20005 Init ainda não foi chamado / Init has not been called
 * @raises -20201 fonte não encontrada -- nem entre as padrão, nem no registro
 *         de TrueType / font not found -- neither a core font nor a registered
 *         TrueType one
 * @raises -20100 estilo inválido / invalid style
 * @example
 *   PL_FPDF.SetFont('Helvetica', 'B', 12);
 */
procedure SetFont(pfamily in varchar2,pstyle in varchar2 default '', psize in number default 0);

/**
 * PT: Mede quanto o texto ocupa na fonte e no corpo correntes, na unidade em
 *     uso. É o que permite alinhar, centralizar e decidir onde quebrar.
 *     Caractere acentuado mede o mesmo que o caractere base -- nas 14 fontes
 *     padrão do PDF o glifo acentuado tem a mesma largura de avanço.
 *
 * EN: Measures how much room the text takes in the current font and size, in
 *     the current unit. It is what makes alignment, centring and line breaking
 *     possible. An accented character measures the same as its base: in the 14
 *     standard PDF fonts the accented glyph has the same advance width.
 *
 * @param pstr o texto a medir / the text to measure
 * @return NUMBER - a largura, na unidade corrente / the width, in the current
 *         unit
 * @raises -20203 caractere fora do WinAnsi / character outside WinAnsi
 * @example
 *   l_larg := PL_FPDF.GetStringWidth('São Paulo');
 */
function GetStringWidth(pstr in varchar2) return number;

/**
 * PT: Troca só o corpo, mantendo família e estilo.
 *
 * EN: Changes the size alone, keeping family and style.
 *
 * @param psize corpo em pontos / size in points
 * @example
 *   PL_FPDF.SetFontSize(8);
 */
procedure SetFontSize(psize in number);

/**
 * PT: Escreve uma célula retangular: opcionalmente com borda, com fundo e com
 *     texto dentro, e move o cursor conforme pln. É a rotina mais usada da
 *     biblioteca. Se a célula não couber no que resta da página e a quebra
 *     automática estiver ligada, a página é trocada antes de escrever.
 *
 * EN: Writes a rectangular cell: optionally bordered, filled and with text
 *     inside, then moves the cursor according to pln. It is the library's most
 *     used routine. If the cell does not fit in what is left of the page and
 *     automatic breaking is on, the page is turned first.
 *
 * @param pw largura; 0 vai até a margem direita / width; 0 spans to the right
 *        margin
 * @param ph altura / height
 * @param ptxt o texto / the text
 * @param pborder '0' sem borda, '1' moldura inteira, ou a combinação de 'L'
 *        (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B'
 *        (Bottom, base) / '0' none, '1' full frame, or a mix of 'L', 'T', 'R',
 *        'B'
 * @param pln para onde vai o cursor / where the cursor goes:
 *        0 = à direita da célula / to the right of the cell
 *        1 = próxima linha, na margem esquerda / next line, at the left margin
 *        2 = abaixo, mantendo o x / below, keeping x
 * @param palign 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right,
 *        direita)
 * @param pfill 1 pinta o fundo com a cor de SetFillColor, 0 não / 1 paints the
 *        background with SetFillColor's colour, 0 does not
 * @param plink URL ou identificador de link interno / URL or internal link id
 * @raises -20100 qualquer falha na escrita da célula. O Cell embrulha o erro
 *         original neste código, mas preserva a pilha (keeperrorstack), de
 *         modo que a causa -- um ORA-20203 de caractere fora do WinAnsi, por
 *         exemplo -- continua visível no rastro. / any failure while writing
 *         the cell. Cell wraps the original error in this code but keeps the
 *         stack (keeperrorstack), so the cause -- an ORA-20203 for a character
 *         outside WinAnsi, say -- stays visible in the backtrace.
 * @example
 *   PL_FPDF.Cell(40, 8, 'Total', '1', 0, 'L');
 *   PL_FPDF.Cell(30, 8, '1.234,56', '1', 1, 'R');
 */
procedure Cell
  (pw in number,
    ph in number default 0,
    ptxt in varchar2 default '',
    pborder in varchar2 default '0',
    pln in number default 0,
    palign in varchar2 default '',
    pfill in number default 0,
    plink in varchar2 default '');

/**
 * PT: Escreve um bloco de texto que quebra sozinho na largura pedida, uma
 *     célula por linha, e devolve quantas linhas saíram. A quebra respeita o
 *     espaço entre palavras e a quebra explícita (CHR(10)). Esta é a versão
 *     FUNCTION, para quem precisa saber quantas linhas foram gastas -- para
 *     calcular a altura de uma tabela, tipicamente.
 *
 * EN: Writes a block of text that wraps by itself to the given width, one cell
 *     per line, and returns how many lines it produced. Wrapping respects word
 *     spaces and explicit breaks (CHR(10)). This is the FUNCTION form, for
 *     callers who need the line count -- to work out the height of a table
 *     row, typically.
 *
 * @param pw largura do bloco; 0 vai até a margem direita / block width; 0
 *        spans to the right margin
 * @param ph altura de cada linha; em branco usa a entrelinha de SetLineSpacing
 *        / height of each line; empty uses SetLineSpacing
 * @param ptxt o texto / the text
 * @param pborder '0' sem borda, '1' moldura, ou 'L','T','R','B' / '0' none,
 *        '1' frame, or 'L','T','R','B'
 * @param palign 'J' justificado (Justified, padrão), 'L' (Left, esquerda), 'C'
 *        (Center, centro), 'R' (Right, direita) / 'J' justified (default),
 *        'L', 'C', 'R'
 * @param pfill 1 pinta o fundo, 0 não / 1 paints the background, 0 does not
 * @param phMax altura máxima do bloco; 0 sem limite / maximum block height; 0
 *        for no limit
 * @return NUMBER - quantas linhas foram escritas / how many lines were written
 * @raises -20100 qualquer falha na escrita, com a pilha original preservada /
 *         any failure while writing, with the original stack preserved
 * @example
 *   l_linhas := PL_FPDF.MultiCell(120, 5, l_texto_longo, '1', 'J');
 */
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

/**
 * PT: Escreve texto corrido a partir de onde o cursor está, indo até a margem
 *     direita e continuando na linha seguinte -- como um parágrafo de
 *     processador de texto. Diferente do MultiCell, começa no meio da linha
 *     onde o cursor parou, o que é o que se quer para emendar texto de
 *     formatações diferentes.
 *
 * EN: Writes flowing text from wherever the cursor is, out to the right margin
 *     and on to the next line -- like a word-processor paragraph. Unlike
 *     MultiCell, it starts partway along the line where the cursor stopped,
 *     which is what you want when joining differently formatted runs of text.
 *
 * @param pH altura da linha, na unidade corrente / line height, current unit
 * @param ptxt o texto / the text
 * @param plink URL ou identificador de link interno / URL or internal link id
 * @raises -20100 qualquer falha na escrita, com a pilha original preservada /
 *         any failure while writing, with the original stack preserved
 * @example
 *   PL_FPDF.SetFont('Helvetica', '', 10);
 *   PL_FPDF.Write(5, 'Consulte o ');
 *   PL_FPDF.SetFont('Helvetica', 'U', 10);
 *   PL_FPDF.Write(5, 'manual', 'https://example.com/manual');
 */
procedure Write(pH in varchar2, ptxt in varchar2, plink in varchar2 default null);

/**
 * PT: O mesmo que Cell, com o texto girado dentro da célula. Serve para
 *     cabeçalho de coluna estreita e para carimbo na lateral da página.
 *
 * EN: The same as Cell, with the text rotated inside the cell. Useful for
 *     narrow column headings and for a stamp down the side of the page.
 *
 * @param p_width largura; 0 vai até a margem direita / width; 0 spans to the
 *        right margin
 * @param p_height altura / height
 * @param p_text o texto / the text
 * @param p_border '0' sem borda, '1' moldura, ou 'L','T','R','B' / '0' none,
 *        '1' frame, or 'L','T','R','B'
 * @param p_ln 0 à direita, 1 próxima linha na margem esquerda, 2 abaixo
 *        mantendo o x / 0 to the right, 1 next line at the left margin, 2
 *        below keeping x
 * @param p_align 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right,
 *        direita)
 * @param p_fill 1 pinta o fundo, 0 não / 1 fills the background, 0 does not
 * @param p_link URL ou link interno / URL or internal link
 * @param p_rotation giro do texto em graus / text rotation in degrees (0, 90,
 *        180, 270)
 * @raises -20110 giro inválido / invalid rotation value
 * @example
 *   PL_FPDF.CellRotated(10, 40, 'Janeiro', '1', 0, 'C', 0, '', 90);
 */
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

/**
 * PT: O mesmo que Write, com o texto girado.
 *
 * EN: The same as Write, with the text rotated.
 *
 * @param p_height altura da linha / line height
 * @param p_text o texto / the text
 * @param p_link URL ou link interno / URL or internal link
 * @param p_rotation giro em graus / rotation in degrees (0, 90, 180, 270)
 * @raises -20110 giro inválido / invalid rotation value
 * @example
 *   PL_FPDF.WriteRotated(5, 'CONFIDENCIAL', NULL, 90);
 */
procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
);

/**
 * PT: Coloca uma imagem buscada por URL. A busca sai pela rede e exige ACL
 *     concedida ao schema -- quando a imagem já está numa tabela ou numa
 *     variável, ImageFromBlob faz o mesmo sem rede e sem permissão. Largura e
 *     altura em zero saem da própria imagem, a 72 dpi; com uma das duas em
 *     zero, ela é derivada da outra, mantendo a proporção.
 *
 * EN: Places an image fetched by URL. The fetch goes over the network and
 *     needs an ACL granted to the schema -- when the image already sits in a
 *     table or a variable, ImageFromBlob does the same with no network and no
 *     permission. Width and height at zero come from the image itself at 72
 *     dpi; with one of them at zero, it is derived from the other, keeping the
 *     aspect ratio.
 *
 * @param pFile URL da imagem / image URL
 * @param pX canto superior esquerdo / top-left corner
 * @param pY canto superior esquerdo / top-left corner
 * @param pWidth largura / width (0 = derivada / derived)
 * @param pHeight altura / height (0 = derivada / derived)
 * @param pType formato, quando não se quer deduzir do arquivo / format, when
 *        it should not be inferred from the file
 * @param pLink URL ou identificador de link interno sobre a imagem / URL or
 *        internal link id over the image
 * @raises -20100 falha ao buscar ou interpretar a imagem, com a pilha original
 *         preservada / failure fetching or parsing the image, original stack
 *         preserved
 * @example
 *   PL_FPDF.Image('https://example.com/logo.png', 10, 10, 40);
 */
procedure image ( pFile   in varchar2,
                  pX      in number,
                  pY      in number,
                  pWidth  in number default 0,
                  pHeight in number default 0,
                  pType   in varchar2 default null,
                  pLink   in varchar2 default null);

/**
 * PT: Coloca uma imagem que o chamador já tem em mãos, sem passar por URL. O
 *     Image() busca pela rede e exige ACL concedida ao schema; quando a imagem
 *     já está numa tabela ou numa variável, esta entrada dispensa a rede e a
 *     permissão. O formato é reconhecido pelos primeiros bytes do arquivo, não
 *     pela extensão: PNG e JPEG; qualquer outra coisa é recusada.
 *
 * EN: Places an image the caller already has, with no URL involved. Image()
 *     fetches over the network and needs an ACL granted to the schema; when
 *     the image already sits in a table or a variable, this entry point needs
 *     neither. The format is recognised from the file's first bytes, not from
 *     an extension: PNG and JPEG; anything else is refused.
 *
 * @param p_blob bytes da imagem / the image bytes (PNG ou JPEG)
 * @param p_name chave no cache de imagens. Um BLOB não tem nome, então o
 *        chamador escolhe: nomes distintos para imagens distintas, e o mesmo
 *        nome reaproveita o objeto já emitido no documento / key in the image
 *        cache. A BLOB has no name, so the caller picks one: distinct names
 *        for distinct images, and the same name reuses the object already
 *        written to the document
 * @param pX posição, na unidade corrente / position, in the current unit
 * @param pY posição, na unidade corrente / position, in the current unit
 * @param pWidth largura / width (0 = derivada / derived)
 * @param pHeight altura / height (0 = derivada / derived)
 * @param pLink link opcional sobre a área da imagem / optional link over the
 *        image area
 * @raises -20301 cabeçalho inválido, BLOB vazio ou nome ausente / invalid
 *         header, empty BLOB or missing name
 * @raises -20303 formato não suportado / unsupported format
 * @example
 *   SELECT logo INTO l_logo FROM empresa WHERE id = 1;
 *   PL_FPDF.ImageFromBlob(l_logo, 'LOGO', 10, 10, 40);
 */
procedure ImageFromBlob( p_blob  in blob,
                         p_name  in varchar2,
                         pX      in number,
                         pY      in number,
                         pWidth  in number default 0,
                         pHeight in number default 0,
                         pLink   in varchar2 default null);

/**
 * PT: Fecha o documento e grava em arquivo, no DIRECTORY PDF_DIR. É a forma
 *     legada: os modos de entrega ao navegador ('I', 'D', 'S') saíram junto
 *     com o OWA/HTP e hoje recusam com -20306, dizendo o que usar no lugar.
 *     Para receber os bytes, use OutputBlob.
 *
 * EN: Closes the document and writes it to a file, in the PDF_DIR DIRECTORY.
 *     This is the legacy form: the browser delivery modes ('I', 'D', 'S') went
 *     away with OWA/HTP and now refuse with -20306, saying what to use
 *     instead. To get the bytes, use OutputBlob.
 *
 * @param pname nome do arquivo / file name (NULL grava 'doc.pdf')
 * @param pdest destino / destination: 'F' (File, arquivo) é o único suportado
 *        / 'F' is the only supported one
 * @raises -20100 destino desconhecido, ou falha na gravação / unknown
 *         destination, or a failure while writing
 * @raises -20306 modo de entrega ao navegador não é mais suportado; a mensagem
 *         aponta OutputBlob e o cabeçalho Content-Type / browser delivery mode
 *         no longer supported; the message points to OutputBlob and the
 *         Content-Type header
 * @example
 *   PL_FPDF.Output('relatorio.pdf', 'F');
 */
procedure Output(pname in varchar2 default null, pdest in varchar2 default null);

/**
 * PT: Fecha o documento e devolve os bytes. Existe por compatibilidade: os
 *     dois parâmetros são ACEITOS E IGNORADOS, e a chamada é repassada ao
 *     OutputBlob. Em código novo, chame OutputBlob direto.
 *
 * EN: Closes the document and returns its bytes. It exists for compatibility:
 *     both parameters are ACCEPTED AND IGNORED, and the call is handed to
 *     OutputBlob. In new code, call OutputBlob directly.
 *
 * @param pname ignorado / ignored
 * @param pdest ignorado / ignored
 * @return BLOB - o PDF / the PDF
 * @raises -20100 falha ao fechar ou montar o documento, com a pilha original
 *         preservada / failure closing or assembling the document, with the
 *         original stack preserved
 * @example
 *   l_pdf := PL_FPDF.OutputBlob;    -- prefira esta / prefer this one
 */
function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null) return blob;

/**
 * PT: Fecha o documento e devolve os bytes do PDF. É a saída principal da
 *     biblioteca: quem grava em tabela, quem anexa a e-mail e quem entrega por
 *     HTTP começa aqui.
 *
 * EN: Closes the document and returns the PDF bytes. It is the library's main
 *     output: storing in a table, attaching to an e-mail and serving over HTTP
 *     all start here.
 *
 * @return BLOB - o PDF pronto / the finished PDF
 * @raises -20005 Init ainda não foi chamado. Antes de agosto/2026 esta chamada
 *         seguia em frente e devolvia um PDF vazio, sem apontar a causa. /
 *         Init has not been called. Before August 2026 this call went ahead
 *         and returned an empty PDF, with nothing pointing at the cause.
 * @example
 *   l_pdf := PL_FPDF.OutputBlob;
 *   INSERT INTO documentos (id, arquivo) VALUES (1, l_pdf);
 */
function OutputBlob return blob;

/**
 * PT: Fecha o documento e grava num DIRECTORY do banco. Exige WRITE no
 *     diretório concedido ao schema.
 *
 * EN: Closes the document and writes it to a database DIRECTORY. Requires
 *     WRITE on that directory.
 *
 * @param p_filename nome do arquivo / file name
 * @param p_directory DIRECTORY do banco / database DIRECTORY object
 * @raises -20401 diretório inválido / invalid directory
 * @raises -20402 sem permissão de escrita / write access denied
 * @raises -20403 falha ao gravar / write failure
 * @example
 *   PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
 */
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

/**
 * PT: Marca o documento como aberto. O AddPage já faz isto quando preciso;
 *     chamar à mão é raro.
 *
 * EN: Marks the document as open. AddPage already does it when needed; calling
 *     it by hand is rare.
 *
 * @example
 *   PL_FPDF.OpenPDF;
 */
procedure OpenPDF;

/**
 * PT: Fecha o documento: escreve o rodapé da última página, monta a estrutura
 *     do arquivo e troca o marcador do total de páginas. Sem nenhuma página,
 *     uma é criada em branco. As rotinas de saída chamam isto sozinhas.
 *
 * EN: Closes the document: writes the last page's footer, assembles the file
 *     structure and replaces the page-count placeholder. With no page at all,
 *     a blank one is created. The output routines call it themselves.
 *
 * @example
 *   PL_FPDF.ClosePDF;
 */
procedure ClosePDF;

/**
 * PT: Fecha a página corrente, executando o rodapé, e abre outra, executando o
 *     cabeçalho. Orientação e formato em branco repetem os da página anterior.
 *     Além dos formatos com nome, aceita 'largura,altura' na unidade corrente.
 *
 * EN: Closes the current page, running the footer, and opens another, running
 *     the header. Orientation and format left empty repeat the previous
 *     page's. Besides the named formats, it accepts 'width,height' in the
 *     current unit.
 *
 * @param p_orientation 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem);
 *        NULL mantém a da página anterior / NULL keeps the previous page's
 * @param p_format 'A4', 'Letter', 'Legal', ou 'largura,altura'; NULL mantém o
 *        anterior / or 'width,height'; NULL keeps the previous
 * @param p_rotation giro da página em graus / page rotation in degrees (0, 90,
 *        180, 270)
 * @raises -20005 Init ainda não foi chamado / Init has not been called
 * @raises -20107 orientação inválida / invalid orientation
 * @raises -20103 formato desconhecido / unknown page format
 * @raises -20101 dimensões inválidas no formato livre / invalid dimensions in
 *         the custom format
 * @raises -20104 giro inválido / invalid rotation value
 * @note PT: O NOME do primeiro parâmetro mudou entre versões -- era
 *       'orientation' na 2.0.0 e hoje é 'p_orientation'. Quem chama por
 *       posição (AddPage('L')) não sente nada; quem chama por nome
 *       (AddPage(orientation => 'L')) precisa acertar o nome. Não há como
 *       aceitar os dois: sobrecargas que diferem só pelo nome do parâmetro
 *       deixam a chamada ambígua, e o Oracle recusa com PLS-00307. Ver a seção
 *       de migração em docs/DOCUMENTATION.md.
 * @note EN: The first parameter's NAME changed between versions -- it was
 *       'orientation' in 2.0.0 and is 'p_orientation' today. Positional
 *       callers (AddPage('L')) are unaffected; named callers
 *       (AddPage(orientation => 'L')) must use the new name. Accepting both is
 *       not possible: overloads differing only by parameter name make the call
 *       ambiguous and Oracle refuses with PLS-00307. See the migration section
 *       in docs/DOCUMENTATION.md.
 * @example
 *   PL_FPDF.AddPage;
 *   PL_FPDF.AddPage('L');
 *   PL_FPDF.AddPage('P', '210,297', 90);
 */
procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
);

/**
 * PT: Torna corrente uma página já criada, para escrever nela de novo. Serve
 *     para preencher depois um espaço que só se sabe no fim -- um total, por
 *     exemplo.
 *
 * EN: Makes an existing page current again, to write on it once more. Useful
 *     for filling in later something only known at the end -- a total, say.
 *
 * @param p_page_number a página, que precisa existir / the page, which must
 *        exist
 * @raises -20005 Init ainda não foi chamado / Init has not been called
 * @raises -20106 a página não existe / the page does not exist
 * @example
 *   PL_FPDF.SetPage(1);
 */
procedure SetPage(p_page_number pls_integer);

/**
 * PT: Devolve o número da página em que se está escrevendo.
 *
 * EN: Returns the number of the page being written.
 *
 * @return PLS_INTEGER - a página corrente / the current page
 * @example
 *   l_pagina := PL_FPDF.GetCurrentPage;
 */
function GetCurrentPage return pls_integer
  DETERMINISTIC;

/**
 * PT: Construtor herdado do FPDF original. Continua valendo, e o código
 *     escrito para as versões 0.9.4 e 2.0.0 segue rodando com ele. Em código
 *     novo prefira Init, que valida os argumentos e levanta erro nomeado em
 *     vez de seguir com um valor inesperado.
 *
 * EN: The constructor inherited from the original FPDF. It still works, and
 *     code written for versions 0.9.4 and 2.0.0 keeps running with it. In new
 *     code prefer Init, which validates its arguments and raises a named error
 *     instead of carrying on with an unexpected value.
 *
 * @param orientation 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem)
 * @param unit unidade de medida / measurement unit ('mm','cm','in','pt')
 * @param format formato da página / page format ('A4', 'Letter'...)
 * @example
 *   PL_FPDF.fpdf('L', 'mm', 'A4');
 */
procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');

/**
 * PT: Levanta ORA-20100 com a mensagem dada, acrescentando o rastro da origem
 *     e preservando a pilha original (keeperrorstack) -- é isso que mantém
 *     rastreável o erro de verdade por trás do -20100. É o caminho interno de
 *     erro da biblioteca; está público por herança.
 *
 * EN: Raises ORA-20100 with the given message, adding the origin backtrace and
 *     keeping the original stack (keeperrorstack) -- which is what keeps the
 *     real error behind the -20100 traceable. It is the library's internal
 *     error path, public by inheritance.
 *
 * @param pmsg a mensagem / the message
 * @raises -20100 sempre; é o que esta rotina faz / always; that is what it
 *         does
 * @example
 *   PL_FPDF.Error('nao foi possivel montar o documento');
 */
procedure Error(pmsg in varchar2);

/**
 * PT: Liga a saída de diagnóstico do tratamento de erro. Serve para depuração;
 *     num processo em produção deixa o erro mais verboso.
 *
 * EN: Turns on the error handler's diagnostic output. Useful while debugging;
 *     in production it only makes errors noisier.
 *
 * @example
 *   PL_FPDF.DebugEnabled;
 */
procedure DebugEnabled;

/**
 * PT: Desliga a saída de diagnóstico. É o estado padrão.
 *
 * EN: Turns the diagnostic output off. This is the default state.
 *
 * @example
 *   PL_FPDF.DebugDisabled;
 */
procedure DebugDisabled;

/**
 * PT: Devolve quantos pontos PDF valem uma unidade corrente -- 2,8346 para
 *     milímetro, 1 para ponto. É o número que converte entre a unidade do
 *     chamador e a do arquivo.
 *
 * EN: Returns how many PDF points make one current unit -- 2.8346 for
 *     millimetres, 1 for points. It is the number that converts between the
 *     caller's unit and the file's.
 *
 * @return NUMBER - pontos por unidade / points per unit
 * @example
 *   l_pontos := 10 * PL_FPDF.GetScaleFactor;
 */
function GetScaleFactor return number;

/**
 * PT: Busca uma imagem pela rede e devolve os bytes com o cabeçalho já
 *     interpretado. Exige ACL de rede concedida ao schema. Substitui a
 *     implementação sobre OrdImage, que saiu de linha.
 *
 * EN: Fetches an image over the network and returns its bytes with the header
 *     already parsed. Requires a network ACL granted to the schema. Replaces
 *     the OrdImage-based implementation, which is deprecated.
 *
 * @param p_Url a URL da imagem / the image URL (http/https)
 * @return recImageBlob - os bytes e os metadados / the bytes and the metadata
 * @note Formatos aceitos / Supported formats:
 *   PNG, JPEG/JPG
 * @raises -20301 cabeçalho de imagem inválido / invalid image header
 * @raises -20302 não foi possível buscar a imagem / could not fetch the image
 * @raises -20303 formato não suportado / unsupported format
 * @example
 *   l_img := PL_FPDF.getImageFromUrl('https://example.com/logo.png');
 */
function getImageFromUrl(p_Url in varchar2) return recImageBlob;

/**
 * PT: Define quanta informação a biblioteca escreve no DBMS_OUTPUT.
 *
 * EN: Sets how much the library writes to DBMS_OUTPUT.
 *
 * @param p_level 0 desligado (OFF), 1 erro (ERROR), 2 aviso (WARN), 3
 *        informação (INFO), 4 depuração (DEBUG) / 0 OFF, 1 ERROR, 2 WARN, 3
 *        INFO, 4 DEBUG
 * @example
 *   PL_FPDF.SetLogLevel(3);
 */
procedure SetLogLevel(p_level pls_integer);

/**
 * PT: Devolve o nível de registro em uso.
 *
 * EN: Returns the logging level in use.
 *
 * @return PLS_INTEGER - o nível corrente / the current level (0-4)
 * @example
 *   l_nivel := PL_FPDF.GetLogLevel;
 */
function GetLogLevel return pls_integer
  DETERMINISTIC;

/**
 * PT: Configura o documento inteiro a partir de um objeto JSON -- metadados,
 *     orientação, formato, fonte e margens numa chamada só. Serve a quem
 *     recebe a configuração de fora, de uma tabela ou de um serviço.
 *
 * EN: Configures the whole document from a JSON object -- metadata,
 *     orientation, format, font and margins in a single call. Useful when the
 *     configuration arrives from outside, from a table or a service.
 *
 * @param p_config o objeto JSON com as opções / the JSON object with the
 *        options
 * @note Chaves JSON / Supported JSON keys:
 *   - title, author, subject, keywords, creator (document metadata)
 *   - orientation ('P' or 'L'), unit ('mm','cm','in','pt'), format (page format)
 *   - fontFamily, fontSize, fontStyle (default font configuration)
 *   - leftMargin, topMargin, rightMargin (page margins in current unit)
 * @example
 *   DECLARE
 *     l_config JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     l_config.put('title', 'Monthly Report');
 *     l_config.put('author', 'Maxwell Oliveira');
 *     l_config.put('orientation', 'P');
 *     l_config.put('format', 'A4');
 *     PL_FPDF.SetDocumentConfig(l_config);
 *   END;
 */
procedure SetDocumentConfig(p_config JSON_OBJECT_T);

/**
 * PT: Devolve, em JSON, o que está configurado no documento em andamento e
 *     quantas páginas ele já tem.
 *
 * EN: Returns, as JSON, what is configured on the document in progress and how
 *     many pages it already has.
 *
 * @return JSON_OBJECT_T - os metadados / the metadata
 * @note Estrutura do JSON / JSON structure:
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
 * @example
 *   DECLARE
 *     l_meta JSON_OBJECT_T;
 *   BEGIN
 *     l_meta := PL_FPDF.GetDocumentMetadata();
 *     DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
 *   END;
 */
function GetDocumentMetadata return JSON_OBJECT_T;

/**
 * PT: Devolve, em JSON, o formato, a orientação e as medidas de uma página do
 *     documento em andamento.
 *
 * EN: Returns, as JSON, the format, orientation and measurements of one page
 *     of the document in progress.
 *
 * @param p_page_number a página / the page (NULL = a corrente / the current
 *        one)
 * @return JSON_OBJECT_T - os dados da página / the page data
 * @note Estrutura do JSON / JSON structure:
 *   {
 *     "number": <number>,
 *     "format": "<string>",
 *     "orientation": "<string>",
 *     "width": <number>,
 *     "height": <number>,
 *     "unit": "<string>"
 *   }
 * @example
 *   DECLARE
 *     l_page_info JSON_OBJECT_T;
 *   BEGIN
 *     l_page_info := PL_FPDF.GetPageInfo(1);
 *     DBMS_OUTPUT.PUT_LINE('Width: ' || l_page_info.get_Number('width'));
 *   END;
 */
function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T;

/**
 * PT: Desenha um QR Code na página corrente. O codificador é o do
 *     PL_FPDF_UTIL, validado contra o zxing-cpp -- o critério aqui não é
 *     "desenha um símbolo", é "um leitor decodifica".
 *
 * EN: Draws a QR Code on the current page. The encoder is PL_FPDF_UTIL's,
 *     validated against zxing-cpp -- the bar here is not "it draws a symbol",
 *     it is "a reader decodes it".
 *
 * @param p_x canto superior esquerdo, na unidade corrente / top-left corner,
 *        in the current unit
 * @param p_y canto superior esquerdo, na unidade corrente / top-left corner,
 *        in the current unit
 * @param p_size o lado do símbolo / the symbol's side
 * @param p_data o conteúdo a codificar / the content to encode
 * @param p_format 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'
 * @param p_error_correction nível de correção de erro / error correction
 *        level: 'L' (7%), 'M' (15%), 'Q' (25%), 'H' (30%)
 * @raises -20870 conteúdo vazio / empty content
 * @raises -20872 nível de correção inválido / invalid correction level
 * @example
 *   PL_FPDF.AddQRCode(50, 50, 40, 'https://example.com', 'URL', 'M');
 */
procedure AddQRCode(
  p_x number,
  p_y number,
  p_size number,
  p_data varchar2,
  p_format varchar2 default 'TEXT',
  p_error_correction varchar2 default 'M'
);

/**
 * PT: Desenha um código de barras linear na página corrente. O codificador é o
 *     do PL_FPDF_UTIL, validado contra o zxing-cpp.
 *
 * EN: Draws a linear barcode on the current page. The encoder is
 *     PL_FPDF_UTIL's, validated against zxing-cpp.
 *
 * @param p_x canto superior esquerdo / top-left corner
 * @param p_y canto superior esquerdo / top-left corner
 * @param p_width largura / width
 * @param p_height altura / height
 * @param p_code o conteúdo a codificar / the content to encode
 * @param p_type simbologia / symbology: 'CODE128', 'CODE39', 'EAN13', 'EAN8',
 *        'ITF14', ou 'ITF' (Interleaved 2 of 5, qualquer quantidade par de
 *        dígitos -- o código de barras do boleto bancário tem 44) / or 'ITF'
 *        (any even digit count -- the Brazilian bank slip barcode has 44)
 * @param p_show_text escrever o código embaixo, legível / print the
 *        human-readable code underneath
 * @raises -20880 código vazio / empty code
 * @raises -20882 simbologia não suportada / unsupported symbology
 * @example
 *   PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
 */
procedure AddBarcode(
  p_x number,
  p_y number,
  p_width number,
  p_height number,
  p_code varchar2,
  p_type varchar2 default 'CODE128',
  p_show_text boolean default true
);

/**
 * PT: Carregar documento PDF existente na memória para leitura e modificação
 *
 * EN: Load an existing PDF document into memory for reading and modification
 *
 * @param p_pdf_blob PDF document as BLOB / Documento PDF como BLOB
 * @raises -20800 Invalid PDF (NULL or too small) / PDF inválido (NULL ou
 *         pequeno)
 * @raises -20801 Invalid PDF header / Cabeçalho PDF inválido
 * @raises -20802 startxref not found / startxref não encontrado
 * @raises -20803 Invalid xref table / Tabela xref inválida
 * @raises -20804 Root object not found in trailer / Objeto Root não encontrado
 * @example
 *   DECLARE
 *     l_pdf BLOB;
 *   BEGIN
 *     SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || PL_FPDF.GetPageCount());
 *   END;
 */
PROCEDURE LoadPDF(p_pdf_blob BLOB);

/**
 * PT: Obter o número total de páginas no documento PDF carregado
 *
 * EN: Get the total number of pages in the loaded PDF document
 *
 * @return PLS_INTEGER - Number of pages / Número de páginas
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @example
 *   l_pages := PL_FPDF.GetPageCount();
 *   DBMS_OUTPUT.PUT_LINE('Total pages / Total de páginas: ' || l_pages);
 */
FUNCTION GetPageCount RETURN PLS_INTEGER;

/**
 * PT: Obter metadados e informações sobre o documento PDF carregado
 *
 * EN: Get metadata and information about the loaded PDF document
 *
 * @return
 *   JSON_OBJECT_T with / com:
 *   - version: PDF version (e.g., "1.4") / Versão do PDF
 *   - pageCount: Number of pages / Número de páginas
 *   - fileSize: Size in bytes / Tamanho em bytes
 *   - objectCount: Number of objects in xref / Número de objetos na xref
 *   - rootObjectId: Catalog object ID / ID do objeto Catalog
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @example
 *   DECLARE
 *     l_info JSON_OBJECT_T;
 *   BEGIN
 *     l_info := PL_FPDF.GetPDFInfo();
 *     DBMS_OUTPUT.PUT_LINE('Version / Versão: ' || l_info.get_string('version'));
 *     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || l_info.get_number('pageCount'));
 *   END;
 */
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;

/**
 * PT: Rotacionar uma página específica (armazenado em memória, aplicado na
 *     saída)
 *
 * EN: Rotate a specific page (stored in memory, applied on output)
 *
 * @param p_page_number Page number to rotate / Número da página para
 *        rotacionar
 * @param p_rotation Rotation angle / Ângulo de rotação (0, 90, 180, 270)
 * @note PT: Mudanças armazenadas em memória. Use OutputModifiedPDF() para
 *       gerar PDF
 * @note EN: Changes stored in memory. Use OutputModifiedPDF() to generate PDF
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   PL_FPDF.RotatePage(1, 90);    -- Rotate page 1 / Rotacionar página 1
 *   PL_FPDF.RotatePage(2, 180);   -- Rotate page 2 / Rotacionar página 2
 */
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER);

/**
 * PT: Marcar uma página para remoção do PDF
 *
 * EN: Mark a page for removal from the PDF
 *
 * @param p_page_number Page number to remove / Número da página para remover
 * @note PT: Página marcada para remoção. Use OutputModifiedPDF() para gerar
 *       PDF modificado
 * @note EN: Page marked for removal. Use OutputModifiedPDF() to generate
 *       modified PDF
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   PL_FPDF.RemovePage(2);  -- Remove page 2 / Remover página 2
 *   PL_FPDF.RemovePage(5);  -- Remove page 5 / Remover página 5
 */
PROCEDURE RemovePage(p_page_number PLS_INTEGER);

/**
 * PT: Obter contagem de páginas não marcadas para remoção
 *
 * EN: Get count of pages not marked for removal
 *
 * @return PLS_INTEGER - Number of active pages / Número de páginas ativas
 * @note PT: Difere de GetPageCount() que retorna a contagem original
 * @note EN: Differs from GetPageCount() which returns original count
 * @example
 *   l_total := PL_FPDF.GetPageCount();        -- Original: 10
 *   PL_FPDF.RemovePage(2);
 *   l_active := PL_FPDF.GetActivePageCount(); -- Active / Ativas: 9
 */
FUNCTION GetActivePageCount RETURN PLS_INTEGER;

/**
 * PT: Verificar se uma página está marcada para remoção
 *
 * EN: Check if a page is marked for removal
 *
 * @param p_page_number Page number to check / Número da página para verificar
 * @return BOOLEAN - TRUE if removed / TRUE se removida, FALSE otherwise / caso
 *         contrário
 * @example
 *   IF PL_FPDF.IsPageRemoved(2) THEN
 *     DBMS_OUTPUT.PUT_LINE('Page 2 removed / Página 2 removida');
 *   END IF;
 */
FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN;

/**
 * PT: Verificar se o PDF carregado foi modificado
 *
 * EN: Check if the loaded PDF has been modified
 *
 * @return BOOLEAN - TRUE if modified / TRUE se modificado, FALSE otherwise /
 *         caso contrário
 * @note PT: Use para determinar se OutputModifiedPDF() precisa ser chamado
 * @note EN: Use to determine if OutputModifiedPDF() needs to be called
 * @example
 *   IF PL_FPDF.IsPDFModified() THEN
 *     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
 *   END IF;
 */
FUNCTION IsPDFModified RETURN BOOLEAN;

/**
 * PT: Acrescenta marca d'água de texto às páginas indicadas
 *
 * EN: Adds a text watermark to the given pages
 *
 * @param p_text Watermark text / Texto da marca d'água
 * @param p_opacity Opacity (0.0 to 1.0) / Opacidade (0.0 a 1.0), default 0.3
 * @param p_rotation Rotation angle / Ângulo de rotação (0, 45, 90, 135, 180,
 *        225, 270, 315), default 45
 * @param p_pages Page range / Range de páginas: 'ALL', '1-5', '1,3,5', default
 *        'ALL'
 * @param p_font Font name / Nome da fonte, default 'Helvetica'
 * @param p_size Font size in points / Tamanho da fonte em pontos, default 48
 * @param p_color Color name / Nome da cor ('gray', 'red', 'blue'), default
 *        'gray'
 * @note PT: Desenhada por OutputModifiedPDF() no fluxo de conteúdo: cada
 *       página afetada ganha um objeto de conteúdo próprio e um /Resources
 *       próprio, de modo que um /Resources compartilhado entre páginas nunca é
 *       contaminado. Centralizada e girada em torno do centro da página; a
 *       fonte é sempre Helvetica.
 * @note EN: Rendered by OutputModifiedPDF() into the page content stream: each
 *       affected page gets its own content object and its own /Resources, so a
 *       /Resources shared between pages is never contaminated. Centred and
 *       rotated about the page centre; the font is always Helvetica.
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   -- All pages / Todas as páginas
 *   PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
 *   -- Specific pages / Páginas específicas
 *   PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
 *   -- Custom style / Estilo personalizado
 *   PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1', 'Helvetica', 72, 'green');
 */
PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_pages VARCHAR2 DEFAULT 'ALL',
  p_font VARCHAR2 DEFAULT 'Helvetica',
  p_size NUMBER DEFAULT 48,
  p_color VARCHAR2 DEFAULT 'gray'
);

/**
 * PT: Obter lista de todas as marcas d'água aplicadas como array JSON
 *
 * EN: Get list of all applied watermarks as JSON array
 *
 * @return
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
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @example
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
 */
FUNCTION GetWatermarks RETURN JSON_ARRAY_T;

/**
 * PT: Gerar o PDF modificado copiando as páginas mantidas objeto a objeto.
 *     Conteúdo, fontes, imagens e anotações são copiados sem alteração: nada é
 *     re-renderizado. Aplica RemovePage e RotatePage.
 *
 * EN: Generate the modified PDF, copying the kept pages object by object.
 *     Content, fonts, images and annotations are copied verbatim: nothing is
 *     re-rendered. Applies RemovePage and RotatePage.
 *
 * @return BLOB - Modified PDF document / Documento PDF modificado
 * @process PT: 1. Valida se PDF está carregado e modificado 2. Indexa a origem
 *          (cadeia de xref + árvore de páginas achatada) 3. Seleciona as
 *          páginas não marcadas por RemovePage, na ordem original 4. Copia
 *          todo objeto alcançável a partir dessas páginas, renumerando as
 *          referências indiretas; o payload dos streams é copiado byte a byte
 *          5. Emite um novo Catalog, um novo nó /Pages, xref e trailer
 * @process EN: 1. Validates PDF is loaded and modified 2. Indexes the source
 *          (xref chain + flattened page tree) 3. Selects the pages not marked
 *          by RemovePage, in the original order 4. Copies every object
 *          reachable from those pages, renumbering the indirect references;
 *          stream payloads are copied byte for byte 5. Emits a new Catalog, a
 *          new /Pages node, xref and trailer
 * @limitation PT: Marcas d'água e overlays de texto e de imagem são todos
 *             desenhados. xref em stream e object streams (PDF 1.5+) são
 *             lidos, inclusive com o predictor PNG; um malformado levanta
 *             -20843/-20847/-20848.
 * @limitation EN: Watermarks and text and image overlays are all rendered. PDF
 *             1.5+ cross-reference streams and object streams are read (the
 *             PNG predictor included); a malformed one raises
 *             -20843/-20847/-20848.
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @raises -20819 PDF has not been modified (no changes to apply) / PDF não foi
 *         modificado (sem alterações para aplicar)
 * @raises -20820 All pages have been removed (cannot generate empty PDF) /
 *         Todas as páginas foram removidas (não pode gerar PDF vazio)
 * @raises -20841 Object dictionary too large to renumber / Dicionário de
 *         objeto grande demais para renumerar
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @raises -20823 Invalid or unsupported image / Imagem inválida ou não
 *         suportada PT: PNG com alfa e entrelaçado são suportados; recusados
 *         são o entrelaçado abaixo de 8 bits por componente, o indexado E
 *         entrelaçado, e imagens acima de 4 megapixels no caminho que
 *         reprocessa pixels EN: alpha and interlaced PNG are supported;
 *         refused are interlaced below 8 bits per component, indexed AND
 *         interlaced, and images above 4 megapixels on the pixel-reprocessing
 *         path
 * @raises -20846 Page /Resources cannot be overlaid (shared indirect
 *         sub-dictionary) / /Resources da página não permite sobreposição
 *         (sub-dicionário indireto compartilhado)
 * @example
 *   DECLARE
 *     l_pdf BLOB;
 *     l_modified_pdf BLOB;
 *   BEGIN
 *     -- Load PDF / Carregar PDF
 *     SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Apply modifications / Aplicar modificações
 *     PL_FPDF.RotatePage(1, 90);
 *     PL_FPDF.RemovePage(3);
 *     -- Generate modified PDF / Gerar PDF modificado
 *     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
 *     -- Save modified PDF / Salvar PDF modificado
 *     UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
 *     PL_FPDF.ClearPDFCache();
 *   END;
 */
FUNCTION OutputModifiedPDF RETURN BLOB;

/**
 * PT: Limpar PDF carregado da memória e liberar todos os recursos em cache
 *
 * EN: Clear loaded PDF from memory and free all cached resources
 *
 * @note PT: Sempre chame isso após processar um PDF para liberar recursos de
 *       memória. Limpa: PDF carregado, info páginas, rotações, páginas
 *       removidas, marcas d'água.
 * @note EN: Always call this after processing a PDF to free memory resources.
 *       Clears: loaded PDF, page info, rotations, removed pages, watermarks.
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   -- Process PDF / Processar PDF
 *   l_modified := PL_FPDF.OutputModifiedPDF();
 *   -- Clear memory / Limpar memória
 *   PL_FPDF.ClearPDFCache();
 */
PROCEDURE ClearPDFCache;

/**
 * PT: Descomprime um stream /FlateDecode do PDF (zlib, RFC 1950). Implementado
 *     em PL/SQL puro: o UTL_COMPRESS não serve porque só aceita rodapé gzip
 *     com CRC-32 correto, e esse CRC é do conteúdo DESCOMPRIMIDO — para saber
 *     o CRC seria preciso descomprimir antes.
 *
 * EN: Decompress a PDF /FlateDecode stream (zlib, RFC 1950). Implemented in
 *     pure PL/SQL: UTL_COMPRESS cannot be used here because it only accepts a
 *     gzip trailer with a correct CRC-32, and that CRC is of the DECOMPRESSED
 *     data — knowing it would require decompressing first.
 *
 * @param p_stream Compressed stream / Stream comprimido (BLOB)
 * @param p_max_bytes Output ceiling, 8 MB by default. A compressed stream is
 *        untrusted input: a few KB can expand to gigabytes (zip bomb) and take
 *        the session down. Raises -20893 instead. / Teto da saída, 8 MB por
 *        padrão. Um stream comprimido é entrada não confiável: alguns KB podem
 *        virar gigabytes (zip bomb) e derrubar a sessão. Levanta -20893 em vez
 *        disso.
 * @return BLOB - Decompressed content / Conteúdo descomprimido
 * @raises -20890 Truncated stream / Stream truncado
 * @raises -20891 Malformed DEFLATE data / Dados DEFLATE malformados
 * @raises -20892 Invalid zlib header / Cabeçalho zlib inválido
 * @raises -20893 Output exceeded p_max_bytes / Saída passou de p_max_bytes
 * @example
 *     l_claro := PL_FPDF.FlateDecode(l_comprimido);
 *   Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
 */
FUNCTION FlateDecode(
  p_stream    IN BLOB,
  p_max_bytes IN PLS_INTEGER DEFAULT 8388608
) RETURN BLOB;

/**
 * PT: Comprime dados num stream /FlateDecode do PDF (zlib, RFC 1950). Escrito
 *     em PL/SQL puro: um bloco único com Huffman fixa e LZ77 guloso. Comprime
 *     menos que a Huffman dinâmica do zlib e muito mais que nada, e nunca
 *     devolve mais que a entrada somada ao custo do bloco armazenado.
 *
 * EN: Compresses data into a PDF /FlateDecode stream (zlib, RFC 1950). Written
 *     in pure PL/SQL: a single fixed-Huffman block with greedy LZ77. It
 *     compresses less than zlib's dynamic Huffman and far more than nothing,
 *     and never returns more than the input plus the stored-block overhead.
 *
 * @param p_data conteúdo a comprimir / content to compress (BLOB)
 * @return BLOB - stream zlib: cabeçalho, DEFLATE e Adler-32 / zlib stream:
 *         header, DEFLATE and Adler-32
 * @example
 *     l_comprimido := PL_FPDF.FlateEncode(l_claro);
 *   Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
 */
FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB;

/**
 * PT: Adicionar sobreposição de texto em posição específica com controle
 *     completo de formatação Desenhada por OutputModifiedPDF() no fluxo de
 *     conteúdo. x e y vão em pontos PDF, a partir do canto inferior esquerdo.
 *     Quando width é informado ele define a CAIXA do texto: as linhas quebram
 *     dentro dela e o align é relativo a [x, x+width]. Sem width não há o que
 *     quebrar, e o align passa a ser relativo ao próprio ponto — 'center'
 *     centraliza o texto em x, 'right' o termina em x.
 *
 * EN: Add text overlay at specific position on PDF page with full formatting
 *     control Rendered by OutputModifiedPDF() into the page content stream. x
 *     and y are in PDF points, from the bottom-left. When width is given it
 *     defines the text BOX: lines wrap inside it and align is relative to [x,
 *     x+width]. Without width there is nothing to wrap, and align becomes
 *     relative to the point itself — 'center' centres the text on x, 'right'
 *     ends it at x.
 *
 * @param p_page_number Page number (1-based) / Número da página (base 1)
 * @param p_text Text content / Conteúdo do texto
 * @param p_x X position in PDF points (1 point = 1/72 inch, from left) /
 *        Posição X
 * @param p_y Y position in PDF points (from bottom) / Posição Y (de baixo)
 * @param p_options JSON configuration (optional) / Configuração JSON
 *        (opcional)
 * @note Opções / Options (JSON_OBJECT_T):
 *   {
 *     "font": "Helvetica",           // Font name / Nome da fonte
 *     "fontSize": 12,                // Font size in points / Tamanho da fonte
 *     "color": "000000",             // RGB hex color / Cor RGB hexadecimal
 *     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
 *     "rotation": 0,                 // Rotation angle (0-360) / Ângulo de rotação
 *     "align": "left",               // left, center, right / esquerda, centro, direita
 *     "width": null,                 // Max width (auto-wrap) / Largura máxima
 *     "bold": false,                 // Bold text / Texto em negrito
 *     "zOrder": 100                  // Layer order (higher on top) / Ordem da camada
 *   }
 * @raises -20809 No PDF loaded / Nenhum PDF carregado
 * @raises -20810 Invalid page number / Número de página inválido
 * @raises -20821 Invalid position coordinates or opacity out of 0.0..1.0 /
 *         Coordenadas de posição inválidas, ou opacidade fora de 0.0..1.0
 * @example
 *   DECLARE
 *     l_options JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Simple text overlay / Sobreposição simples
 *     PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
 *     -- Formatted text / Texto formatado
 *     l_options.put('font', 'Helvetica-Bold');
 *     l_options.put('fontSize', 24);
 *     l_options.put('color', 'FF0000');  -- Red / Vermelho
 *     l_options.put('opacity', 0.8);
 *     l_options.put('rotation', 45);
 *     PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
 *     l_modified := PL_FPDF.OutputModifiedPDF();
 *   END;
 */
PROCEDURE OverlayText(
  p_page_number IN PLS_INTEGER,
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

/**
 * PT: Adicionar sobreposição de imagem em posição específica com controle de
 *     tamanho Desenhada por OutputModifiedPDF() no fluxo de conteúdo. No
 *     caminho comum nada é descomprimido: o JPEG entra inteiro como
 *     /DCTDecode, e os blocos IDAT do PNG já são zlib, que é o /FlateDecode do
 *     PDF — são concatenados e declarados com /Predictor 15, o que vale de 1 a
 *     16 bits por componente. PNG com canal alfa (color types 4 e 6) e
 *     entrelaçado (Adam7) também são desenhados, por um caminho que reprocessa
 *     pixel a pixel — e por isso sai sem compressão, já que não há deflate
 *     neste trecho. Recusados com -20823, em vez de desenhados errado:
 *     entrelaçado com menos de 8 bits por componente, indexado E entrelaçado,
 *     e imagem acima do teto de pixels do caminho que reprocessa.
 *
 * EN: Add image overlay at specific position on PDF page with sizing control
 *     Rendered by OutputModifiedPDF() into the page content stream. On the
 *     common path nothing is decompressed: JPEG goes in whole as /DCTDecode,
 *     and a PNG's IDAT blocks are already zlib, which is the PDF's
 *     /FlateDecode — they are concatenated and declared with /Predictor 15,
 *     which holds from 1 to 16 bits per component. PNG with an alpha channel
 *     (color types 4 and 6) and interlaced PNG (Adam7) are drawn too, by a
 *     path that reprocesses pixel by pixel — and therefore comes out
 *     uncompressed, there being no deflate on that path. Refused with -20823
 *     rather than drawn wrong: interlaced below 8 bits per component, indexed
 *     AND interlaced, and images above the pixel ceiling of the reprocessing
 *     path.
 *
 * @param p_page_number Page number (1-based) / Número da página (base 1)
 * @param p_image_blob Image data (JPEG or PNG) / Dados da imagem (JPEG ou PNG)
 * @param p_x X position in PDF points / Posição X em pontos PDF
 * @param p_y Y position in PDF points (from bottom) / Posição Y (de baixo)
 * @param p_width Image width in points (NULL = original) / Largura em pontos
 * @param p_height Image height in points (NULL = original) / Altura em pontos
 * @param p_options JSON configuration (optional) / Configuração JSON
 *        (opcional)
 * @note Opções / Options (JSON_OBJECT_T):
 *   {
 *     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
 *     "rotation": 0,                 // Rotation angle / Ângulo de rotação
 *     "maintainAspect": true,        // Keep aspect ratio / Manter proporção
 *     "scaleToFit": false,           // Scale to fit in width/height / Escalar para caber
 *     "zOrder": 100                  // Layer order / Ordem da camada
 *   }
 * @raises -20809 No PDF loaded / Nenhum PDF carregado
 * @raises -20810 Invalid page number / Número de página inválido
 * @raises -20821 Invalid position coordinates / Coordenadas de posição
 *         inválidas
 * @raises -20823 Invalid image format (must be JPEG or PNG) / Formato de
 *         imagem inválido
 * @raises -20824 Image dimensions invalid / Dimensões da imagem inválidas
 * @example
 *   DECLARE
 *     l_logo BLOB;
 *     l_options JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Add logo at top-right / Adicionar logo no canto superior direito
 *     PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
 *     -- Watermark image with transparency / Marca d'água com transparência
 *     l_options.put('opacity', 0.3);
 *     l_options.put('rotation', 45);
 *     PL_FPDF.OverlayImage(1, l_watermark, 200, 400, 300, NULL, l_options);
 *     l_modified := PL_FPDF.OutputModifiedPDF();
 *   END;
 */
PROCEDURE OverlayImage(
  p_page_number IN PLS_INTEGER,
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER DEFAULT NULL,
  p_height IN NUMBER DEFAULT NULL,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

/**
 * PT: Obter lista de todas as sobreposições aplicadas como array JSON
 *
 * EN: Get list of all applied overlays as JSON array for specific page or all
 *     pages
 *
 * @param p_page_number Filter by page (NULL = all pages) / Filtrar por página
 * @return
 *   JSON_ARRAY_T - Array of overlay objects / Array de objetos de sobreposição
 *     [{
 *       "overlayId": "OVL_001",
 *       "overlayType": "TEXT" | "IMAGE",
 *       "pageNumber": 1,
 *       "x": 100, "y": 700,
 *       "content": "APPROVED",     // For text overlays
 *       "opacity": 0.8,
 *       "rotation": 45,
 *       "zOrder": 100
 *     }, ...]
 * @raises -20809 No PDF loaded / Nenhum PDF carregado
 * @example
 *   DECLARE
 *     l_overlays JSON_ARRAY_T;
 *     l_overlay JSON_OBJECT_T;
 *   BEGIN
 *     l_overlays := PL_FPDF.GetOverlays(1);  -- Page 1 overlays
 *     FOR i IN 0..l_overlays.get_size() - 1 LOOP
 *       l_overlay := TREAT(l_overlays.get(i) AS JSON_OBJECT_T);
 *       DBMS_OUTPUT.PUT_LINE('Type: ' || l_overlay.get_string('overlayType'));
 *     END LOOP;
 *   END;
 */
FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T;

/**
 * PT: Remover sobreposição específica por ID
 *
 * EN: Remove specific overlay by ID
 *
 * @param p_overlay_id Overlay ID from GetOverlays() / ID da sobreposição
 * @raises -20825 Overlay not found / Sobreposição não encontrada
 * @example
 *   PL_FPDF.RemoveOverlay('OVL_001');
 */
PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2);

/**
 * PT: Limpar todas as sobreposições de todas ou de página específica
 *
 * EN: Clear all overlays from all pages or specific page
 *
 * @param p_page_number Clear from page (NULL = all pages) / Limpar de página
 * @example
 *   -- Clear all overlays / Limpar todas as sobreposições
 *   PL_FPDF.ClearOverlays();
 *   -- Clear overlays from page 1 only / Limpar apenas da página 1
 *   PL_FPDF.ClearOverlays(1);
 */
PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL);

/**
 * PT: Carregar PDF em memória com identificador único para operações
 *     multi-documento
 *
 * EN: Load PDF into memory with unique identifier for multi-document
 *     operations
 *
 * @param p_pdf_id Unique identifier (max 50 chars) / Identificador único
 * @param p_pdf_blob PDF document as BLOB / Documento PDF como BLOB
 * @note PT: Máximo de 10 PDFs podem ser carregados simultaneamente
 * @note EN: Maximum 10 PDFs can be loaded simultaneously
 * @raises -20828 PDF ID already loaded / ID do PDF já carregado
 * @raises -20829 Maximum PDFs exceeded (10 max) / Máximo de PDFs excedido
 * @raises -20830 Invalid PDF ID (empty or too long) / ID de PDF inválido
 * @example
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('report_jan', l_jan_pdf);
 *     PL_FPDF.LoadPDFWithID('report_feb', l_feb_pdf);
 *     PL_FPDF.LoadPDFWithID('report_mar', l_mar_pdf);
 *   END;
 */
PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
);

/**
 * PT: Obter lista de todos os IDs de PDF carregados e seus metadados
 *
 * EN: Get list of all loaded PDF IDs and their metadata as JSON array
 *
 * @return
 *   JSON_ARRAY_T - Array of PDF objects / Array de objetos PDF
 *     [{
 *       "pdfId": "report_jan",
 *       "pageCount": 5,
 *       "fileSize": 125678,
 *       "loadedDate": "2026-01-25T10:30:00"
 *     }, ...]
 * @example
 *   DECLARE
 *     l_pdfs JSON_ARRAY_T;
 *     l_pdf JSON_OBJECT_T;
 *   BEGIN
 *     l_pdfs := PL_FPDF.GetLoadedPDFs();
 *     FOR i IN 0..l_pdfs.get_size() - 1 LOOP
 *       l_pdf := TREAT(l_pdfs.get(i) AS JSON_OBJECT_T);
 *       DBMS_OUTPUT.PUT_LINE('PDF: ' || l_pdf.get_string('pdfId'));
 *     END LOOP;
 *   END;
 */
FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T;

/**
 * PT: Remover PDF específico da memória para liberar recursos
 *
 * EN: Remove specific PDF from memory to free resources
 *
 * @param p_pdf_id PDF identifier to unload / Identificador do PDF
 * @raises -20831 PDF ID not found / ID do PDF não encontrado
 * @example
 *   PL_FPDF.UnloadPDF('report_jan');
 */
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);

/**
 * PT: Mesclar múltiplos PDFs carregados em um único documento, na ordem dada.
 *     Todos os objetos de cada origem são copiados (páginas, fontes, imagens,
 *     anotações) com as referências indiretas renumeradas, e uma nova árvore
 *     de páginas é montada. Nada é re-renderizado: o conteúdo original chega
 *     intacto. O mesmo ID pode aparecer mais de uma vez.
 *
 * EN: Merge multiple loaded PDFs into a single document, in the given order.
 *     Every object of every source is copied (pages, fonts, images,
 *     annotations) with its indirect references renumbered, and a new page
 *     tree is built. Nothing is re-rendered: the original content arrives
 *     intact. The same ID may appear more than once.
 *
 * @param p_pdf_ids JSON array of PDF IDs to merge / Array JSON de IDs de PDF
 *        Example: JSON_ARRAY_T('["pdf1","pdf2","pdf3"]')
 * @param p_options Optional configuration / Configuração opcional (future use)
 * @return BLOB - Merged PDF document / Documento PDF mesclado
 * @raises -20832 No PDF IDs provided / Nenhum ID de PDF fornecido
 * @raises -20833 PDF ID in list not loaded / ID de PDF na lista não carregado
 * @raises -20834 Merge failed / Mesclagem falhou
 * @raises -20841 Object dictionary too large to renumber / Dicionário de
 *         objeto grande demais para renumerar
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @example
 *   DECLARE
 *     l_merged BLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('jan', l_jan_pdf);
 *     PL_FPDF.LoadPDFWithID('feb', l_feb_pdf);
 *     PL_FPDF.LoadPDFWithID('mar', l_mar_pdf);
 *     l_merged := PL_FPDF.MergePDFs(
 *       JSON_ARRAY_T('["jan","feb","mar"]'),
 *       NULL
 *     );
 *     INSERT INTO reports VALUES ('Q1_2026', l_merged);
 *   END;
 */
FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

/**
 * PT: Dividir o PDF carregado em vários documentos, um por intervalo. Cada
 *     parte leva apenas os objetos alcançáveis a partir das suas páginas, e
 *     por isso fica bem menor que a origem. Os intervalos não podem se
 *     sobrepor.
 *
 * EN: Split the loaded PDF into several documents, one per page range. Each
 *     part carries only the objects reachable from its own pages, so the parts
 *     are much smaller than the source. Ranges must not overlap.
 *
 * @param p_pdf_id PDF identifier to split / Identificador do PDF
 * @param p_page_ranges JSON array of page range strings / Array de intervalos
 *        Examples: '1-5', '6-10', '11', '1,3,5', 'ALL'
 * @return JSON_ARRAY_T - Array with base64 encoded PDFs, one per range,
 *         without line breaks / Array com PDFs em base64, um por intervalo,
 *         sem quebras de linha
 * @raises -20831 PDF ID not found / ID do PDF não encontrado
 * @raises -20835 No page ranges provided / Nenhum intervalo fornecido
 * @raises -20836 Overlapping page ranges / Intervalos sobrepostos
 * @raises -20838 Invalid page specification / Especificação de páginas
 *         inválida
 * @raises -20839 Page number out of range / Número de página fora do intervalo
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @example
 *   DECLARE
 *     l_split_pdfs JSON_ARRAY_T;
 *     l_part CLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('contract', l_contract_pdf);
 *     l_split_pdfs := PL_FPDF.SplitPDF('contract',
 *       JSON_ARRAY_T('["1-5", "6-10", "11-15"]')
 *     );
 *     FOR i IN 0..l_split_pdfs.get_size() - 1 LOOP
 *       l_part := l_split_pdfs.get_string(i);
 *       -- Process each part / Processar cada parte
 *     END LOOP;
 *   END;
 */
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T;

/**
 * PT: Extrair as páginas indicadas de um PDF carregado para um novo documento.
 *     A ordem pedida é respeitada ('5,1' devolve a página 5 e depois a 1) e
 *     uma página pode repetir. Só os objetos alcançáveis a partir das páginas
 *     escolhidas são copiados, então o resultado fica menor que a origem.
 *
 * EN: Extract the given pages from a loaded PDF into a new document. The
 *     requested order is kept ('5,1' returns page 5 then page 1) and a page
 *     may repeat. Only the objects reachable from the selected pages are
 *     copied, so the result is smaller than the source.
 *
 * @param p_pdf_id PDF identifier / Identificador do PDF
 * @param p_pages Page specification: '1', '1,3,5-7,10', '5,1' or 'ALL' /
 *        Especificação: '1', '1,3,5-7,10', '5,1' ou 'ALL'
 * @param p_options Optional configuration / Configuração opcional (future use)
 * @return BLOB - New PDF with extracted pages / Novo PDF com páginas extraídas
 * @raises -20831 PDF ID not found / ID do PDF não encontrado
 * @raises -20838 Invalid page specification / Especificação de páginas
 *         inválida
 * @raises -20839 Page number out of range / Número de página fora do intervalo
 * @raises -20841 Object dictionary too large to renumber / Dicionário de
 *         objeto grande demais para renumerar
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @example
 *   DECLARE
 *     l_extracted BLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
 *     -- Extract pages 1, 5-10, and 15 / Extrair páginas 1, 5-10 e 15
 *     l_extracted := PL_FPDF.ExtractPages('manual', '1,5-10,15', NULL);
 *     INSERT INTO documents VALUES ('Summary', l_extracted);
 *   END;
 */
FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

/**
 * PT: Criptografar PDF com proteção por senha seguindo especificação PDF
 *
 * EN: Encrypt PDF with password protection following PDF specification
 *
 * @param p_pdf PDF blob to encrypt / PDF blob para criptografar
 * @param p_user_password Password to open document / Senha para abrir
 *        documento
 * @param p_owner_password Password for full access (optional) / Senha acesso
 *        total
 * @param p_permissions JSON with permission flags / JSON com flags de
 *        permissão
 * @param p_encryption Encryption method:
 *        'RC4-40','RC4-128','AES-128','AES-256'
 * @return BLOB - Encrypted PDF / PDF criptografado
 * @raises -20850 Invalid encryption method / Método de criptografia inválido
 * @raises -20851 Password required / Senha obrigatória
 * @raises -20852 Encryption failed / Falha na criptografia
 * @note PT: Origem em PDF 1.5+ (xref em stream, object streams) é achatada: os
 *       objetos de dentro dos object streams viram objetos de primeiro nível e
 *       a saída leva xref clássica.
 * @note EN: A PDF 1.5+ source (cross-reference stream, object streams) is
 *       flattened: objects living inside object streams become top-level
 *       objects and the output carries a classic cross-reference table.
 * @example
 *   l_encrypted := PL_FPDF.EncryptPDF(
 *     p_pdf => l_pdf,
 *     p_user_password => 'user123',
 *     p_owner_password => 'owner456',
 *     p_permissions => JSON_OBJECT_T('{"print":true,"copy":false}'),
 *     p_encryption => 'AES-128'
 *   );
 */
FUNCTION EncryptPDF(
  p_pdf IN BLOB,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL,
  p_permissions IN JSON_OBJECT_T DEFAULT NULL,
  p_encryption IN VARCHAR2 DEFAULT 'RC4-128'
) RETURN BLOB;

/**
 * PT: Remover criptografia do PDF usando senha
 *
 * EN: Remove encryption from PDF using password
 *
 * @param p_pdf Encrypted PDF blob / PDF blob criptografado
 * @param p_password User or owner password / Senha de usuário ou owner
 * @return BLOB - Decrypted PDF / PDF descriptografado
 * @raises -20853 PDF is not encrypted / PDF não está criptografado
 * @raises -20854 Invalid password / Senha inválida
 * @raises -20855 Decryption failed / Falha na descriptografia
 * @note PT: Origem em PDF 1.5+ é achatada, e os object streams são decifrados
 *       antes de descomprimidos.
 * @note EN: A PDF 1.5+ source is flattened, and the object streams are
 *       decrypted before being decompressed.
 * @example
 *   l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
 */
FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB;

/**
 * PT: Verificar se PDF está criptografado
 *
 * EN: Check if PDF is encrypted
 *
 * @param p_pdf PDF blob to check / PDF blob para verificar
 * @return BOOLEAN - TRUE if encrypted / TRUE se criptografado
 * @example
 *   IF PL_FPDF.IsEncrypted(l_pdf) THEN ...
 */
FUNCTION IsEncrypted(p_pdf IN BLOB) RETURN BOOLEAN;

/**
 * PT: Obter informações de segurança do PDF
 *
 * EN: Get security information from PDF
 *
 * @param p_pdf PDF blob / PDF blob
 * @return
 *   JSON_OBJECT_T - Security info including:
 *     - encrypted: boolean
 *     - method: string (RC4-40, RC4-128, AES-128, AES-256)
 *     - permissions: object with print, copy, modify, etc.
 *     - hasUserPassword: boolean
 *     - hasOwnerPassword: boolean
 * @example
 *   l_info := PL_FPDF.GetSecurityInfo(l_pdf);
 *   IF l_info.get_boolean('encrypted') THEN ...
 */
FUNCTION GetSecurityInfo(p_pdf IN BLOB) RETURN JSON_OBJECT_T;

/**
 * PT: Definir criptografia para PDF em geração (usar antes do Output)
 *
 * EN: Set encryption for PDF being generated (use before Output)
 *
 * @param p_encryption Method: 'RC4-40','RC4-128','AES-128','AES-256'
 * @param p_user_password Password to open / Senha para abrir
 * @param p_owner_password Password for full access / Senha acesso total
 * @example
 *   PL_FPDF.Init;
 *   PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
 *   PL_FPDF.AddPage;
 *   l_pdf := PL_FPDF.OutputBlob;
 * @note Mapeamento de Versão / PDF Version Mapping:
 *   RC4-40/RC4-128 -> PDF 1.4
 *   AES-128 -> PDF 1.5
 *   AES-256 -> PDF 1.7
 */
PROCEDURE SetEncryption(
  p_encryption IN VARCHAR2,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL
);

/**
 * PT: Definir a versão do PDF para documentos gerados
 *
 * EN: Set the PDF version for generated documents
 *
 * @param p_version PDF version: '1.4', '1.5', '1.6', '1.7', '2.0'
 * @note Recursos por Versão / Version Features:
 *   1.4: RC4 128-bit encryption, transparency
 *   1.5: AES 128-bit, object streams, cross-reference streams
 *   1.6: AES 128-bit, OpenType fonts
 *   1.7: AES 256-bit, XFA forms
 *   2.0: AES 256-bit only, no RC4
 * @example
 *   PL_FPDF.SetPDFVersion('1.5');
 */
PROCEDURE SetPDFVersion(p_version IN VARCHAR2);

/**
 * PT: Obter a configuração atual de versão do PDF
 *
 * EN: Get the current PDF version setting
 *
 * @return VARCHAR2 - Current PDF version (e.g., '1.4')
 */
FUNCTION GetPDFVersion RETURN VARCHAR2;

/**
 * PT: Definir permissões do documento (requer SetEncryption antes)
 *
 * EN: Set document permissions (requires SetEncryption first)
 *
 * @param p_print Allow printing / Permitir impressão
 * @param p_modify Allow modification / Permitir modificação
 * @param p_copy Allow copy/extract / Permitir cópia/extração
 * @param p_annotate Allow annotations / Permitir anotações
 * @param p_fill_forms Allow form filling / Permitir preenchimento de
 *        formulários
 * @param p_extract Allow content extraction / Permitir extração de conteúdo
 * @param p_assemble Allow document assembly / Permitir montagem de documento
 * @param p_print_high Allow high quality print / Permitir impressão alta
 *        qualidade
 * @example
 *   PL_FPDF.SetEncryption('AES-128', 'user', 'owner');
 *   PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE, p_modify => FALSE);
 */
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
