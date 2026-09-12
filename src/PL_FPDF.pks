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
 * Prepara o gerador para um documento novo. Substitui o construtor legado
 * fpdf(), acrescentando validação dos argumentos e os buffers em CLOB. Chamar
 * de novo com um documento em andamento descarta o anterior.
 *
 * @param p_orientation orientação da página: 'P' (Portrait, retrato) ou 'L'
 *        (Landscape, paisagem)
 * @param p_unit unidade de medida ('mm', 'cm', 'in', 'pt')
 * @param p_format formato da página ('A4', 'Letter', 'Legal')
 * @param p_encoding codificação de entrada
 * @raises -20001 orientação inválida
 * @raises -20002 unidade de medida inválida
 * @raises -20003 codificação não suportada
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
 * Devolve o package ao estado inicial: libera os CLOBs temporários e esvazia
 * todas as tabelas de estado (fontes, imagens, links, metadados, mudanças de
 * orientação). O package tem estado de sessão, e quem gera documentos em lote
 * precisa chamar isto entre um e outro — sem isso, a configuração de um vaza
 * para o seguinte.
 *
 * @example
 *   PL_FPDF.Reset;
 */
procedure Reset;

/**
 * Diz se Init (ou fpdf) já foi chamado nesta sessão.
 *
 * @return BOOLEAN - TRUE se inicializado
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
 * Registra uma fonte TrueType a partir de um BLOB e a deixa disponível para o
 * SetFont, pelo nome dado aqui. As tabelas do arquivo são lidas de verdade --
 * head, hhea, hmtx, cmap, OS/2 e post --, e a fonte vai embutida no PDF como
 * /FontFile2. O arquivo cresce: o programa da fonte sai em hexadecimal, então
 * ocupa o DOBRO do tamanho dela, e ainda não há subset — a fonte inteira vai
 * embutida, mesmo que o documento use dez glifos.
 * Para texto em português com acento não é preciso embutir nada: as fontes
 * padrão escrevem acentuado desde a 3.4.0.
 *
 * @param p_font_name nome pelo qual SetFont a chamará
 * @param p_font_blob o arquivo.ttf
 * @param p_encoding codificação da fonte
 * @param p_embed embutir no PDF
 * @raises -20210 nome da fonte vazio
 * @raises -20211 BLOB da fonte nulo
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
 * Lê um .ttf de um DIRECTORY do banco e o registra como o AddTTFFont. Exige
 * READ no diretório concedido ao schema; sem isso, AddTTFFont recebe os bytes
 * direto, sem concessão nenhuma.
 *
 * @param p_font_name nome pelo qual SetFont a chamará
 * @param p_file_path nome do arquivo
 * @param p_directory DIRECTORY do banco
 * @param p_encoding codificação da fonte
 * @raises -20202 arquivo de fonte inválido
 * @raises -20401 diretório inválido
 * @raises -20402 sem permissão de leitura
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
 * Diz se a fonte está registrada nesta sessão, e portanto disponível para o
 * SetFont. O nome não diferencia maiúsculas de minúsculas.
 *
 * @param p_font_name nome da fonte
 * @return BOOLEAN - TRUE se carregada
 * @example
 *   IF NOT PL_FPDF.IsTTFFontLoaded('Roboto') THEN ... END IF;
 */
function IsTTFFontLoaded(p_font_name varchar2) return boolean;

/**
 * Devolve o registro da fonte: os bytes guardados e as métricas lidas do
 * arquivo -- unidades por em, ascendente, descendente, altura de caixa alta, a
 * caixa e o ângulo do itálico. Tudo já reescalado para as 1000 unidades por em
 * do PDF, menos o units_per_em, que é o do arquivo.
 *
 * @param p_font_name nome da fonte
 * @return recTTFFont - as métricas da fonte
 * @raises -20206 fonte não carregada
 * @example
 *   l_fonte := PL_FPDF.GetTTFFontInfo('Roboto');
 */
function GetTTFFontInfo(p_font_name varchar2) return recTTFFont;

/**
 * Descarrega as fontes TrueType e libera os LOBs temporários delas. Vale
 * chamar ao fim de um lote: cada fonte embutida ocupa centenas de KB na
 * sessão.
 *
 * @example
 *   PL_FPDF.ClearTTFFontCache;
 */
procedure ClearTTFFontCache;

/**
 * Escapa os caracteres que a sintaxe de string do PDF reserva -- o parêntese e
 * a barra invertida. NÃO converte codificação: quem escreve texto pelas
 * rotinas normais (Cell, Write, Text) não precisa chamar isto, porque a
 * conversão para WinAnsi já acontece lá dentro.
 *
 * @param p_text o texto
 * @param p_escape escapar os caracteres reservados
 * @return VARCHAR2 - o texto pronto para ir entre parênteses num objeto PDF
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
 * Devolve o corpo da fonte em uso, em pontos.
 *
 * @return NUMBER - o tamanho em pontos
 * @example
 *   l_corpo := PL_FPDF.GetCurrentFontSize;
 */
function GetCurrentFontSize return number;

/**
 * Devolve o estilo em uso: '' (normal), 'B' (Bold, negrito), 'I' (Italic,
 * itálico), 'U' (Underline, sublinhado) ou a combinação. Sempre em MAIÚSCULA:
 * o SetFont normaliza, então 'b' entra e 'B' volta.
 *
 * @return VARCHAR2 - o estilo corrente
 * @example
 *   l_estilo := PL_FPDF.GetCurrentFontStyle;
 */
function GetCurrentFontStyle return varchar2;

/**
 * Devolve o nome da família em uso. Sempre em MINÚSCULA: o SetFont normaliza,
 * então 'Times' entra e 'times' volta. Comparar com 'Times' nunca casa -- use
 * LOWER() dos dois lados.
 *
 * @return VARCHAR2 - a família corrente
 * @example
 *   l_familia := PL_FPDF.GetCurrentFontFamily;
 */
function GetCurrentFontFamily return varchar2;

/**
 * Passa a desenhar linha tracejada, com o comprimento do traço e o do
 * intervalo na unidade corrente. Os dois em zero voltam à linha cheia. Vale
 * para tudo o que for desenhado depois, até ser trocado.
 *
 * @param pblack comprimento do traço
 * @param pwhite comprimento do intervalo
 * @example
 *   PL_FPDF.SetDash(2, 2);          -- tracejado
 *   PL_FPDF.Line(10, 50, 200, 50);
 *   PL_FPDF.SetDash;                -- volta à linha cheia
 */
procedure SetDash(pblack in number default 0, pwhite in number default 0);

/**
 * Devolve a entrelinha usada pelo MultiCell quando a altura da linha vai em
 * branco.
 *
 * @return NUMBER - a entrelinha, na unidade corrente
 * @example
 *   l_entre := PL_FPDF.GetLineSpacing;
 */
function GetLineSpacing return number;

/**
 * Define a entrelinha do MultiCell para quando a altura da linha não for
 * informada.
 *
 * @param pls a entrelinha, na unidade corrente
 * @example
 *   PL_FPDF.SetLineSpacing(5);
 */
Procedure SetLineSpacing (pls in number);

/**
 * Desenha um polígono ligando os pontos na ordem da tabela, que precisa
 * começar no índice 0. Fechado, o último ponto liga de volta ao primeiro.
 *
 * @param points os vértices, indexados a partir de 0
 * @param pclose fechar o contorno
 * @param pstyle '' desenha o contorno (padrão), 'F' preenche (Fill), 'FD' ou
 *        'DF' preenche e contorna (Fill and Draw)
 * @example
 *   l_pontos(0).x := 10; l_pontos(0).y := 10;
 *   l_pontos(1).x := 50; l_pontos(1).y := 10;
 *   l_pontos(2).x := 30; l_pontos(2).y := 40;
 *   PL_FPDF.Poly(l_pontos, TRUE, 'F');
 */
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');

/**
 * Desenha um triângulo isósceles de base 2*psize e altura psize, com a ponta
 * virada para porientation. (px, py) é o canto superior esquerdo da caixa que
 * envolve o triângulo, e não o vértice.
 *
 * @param px canto superior esquerdo da caixa
 * @param py canto superior esquerdo da caixa
 * @param psize metade da base, e a altura
 * @param porientation para onde aponta: 'up'/'U', 'down'/'D', 'left'/'L',
 *        'right'/'R'
 * @param pstyle '' contorna, 'F' preenche (Fill), 'FD'/'DF' os dois
 * @raises -20821 orientação inválida
 * @example
 *   PL_FPDF.Triangle(20, 20, 5, 'right', 'F');
 */
procedure Triangle(px in number, py in number, psize in number,
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

/**
 * Escreve o operador 'd' do PDF direto no fluxo de conteúdo, para quem precisa
 * de um padrão que o SetDash não monta. O texto vai como está, e um padrão
 * malformado só aparece no leitor. Prefira SetDash.
 *
 * @param pdash o padrão, na sintaxe do PDF ('[] 0' = linha cheia)
 * @example
 *   PL_FPDF.SetLineDashPattern('[3 2] 0');
 */
procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

/**
 * Vai para a linha seguinte: leva o x de volta à margem esquerda e desce o y.
 * Sem altura, desce o da última célula escrita.
 *
 * @param h quanto descer, na unidade corrente
 * @example
 *   PL_FPDF.Cell(40, 10, 'Primeira');
 *   PL_FPDF.Ln;
 */
procedure Ln(h number default null);

/**
 * Devolve a abscissa corrente, na unidade em uso.
 *
 * @return NUMBER - o x corrente
 * @example
 *   l_x := PL_FPDF.GetX;
 */
function  GetX return number;

/**
 * Move a abscissa. Valor negativo conta a partir da borda direita: SetX(-30)
 * põe o cursor a 30 da direita.
 *
 * @param px a nova abscissa
 * @example
 *   PL_FPDF.SetX(-40);
 */
procedure SetX(px in number);

/**
 * Devolve a ordenada corrente, contada do topo da página.
 *
 * @return NUMBER - o y corrente
 * @example
 *   l_y := PL_FPDF.GetY;
 */
function  GetY return number;

/**
 * Move a ordenada E devolve o x à margem esquerda -- é o efeito que surpreende
 * quem só queria descer. Para mover os dois sem esse efeito, use SetXY. Valor
 * negativo conta a partir do pé da página.
 *
 * @param py a nova ordenada
 * @example
 *   PL_FPDF.SetY(-20);   -- 20 acima do pé
 */
procedure SetY(py in number);

/**
 * Move as duas coordenadas. Ao contrário do SetY sozinho, o x informado é
 * respeitado.
 *
 * @param x a abscissa
 * @param y a ordenada
 * @example
 *   PL_FPDF.SetXY(20, 50);
 */
procedure SetXY(x in number,y in number);

/**
 * Registra o NOME de uma rotina que será executada no início de cada página. O
 * nome e os nomes dos parâmetros são validados como identificadores SQL
 * (DBMS_ASSERT) aqui, na configuração -- e não no meio do relatório, que é
 * onde um nome inválido apareceria. O bloco é montado uma vez só, e não a cada
 * página.
 *
 * @param headerprocname nome da rotina (NULL desliga)
 * @param paramTable parâmetros nomeados
 * @example
 *   PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');
 */
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam);

/**
 * Como SetHeaderProc, para o rodapé: a rotina é executada ao fechar cada
 * página, e é onde costuma entrar o "página N de {nb}".
 *
 * @param footerprocname nome da rotina (NULL desliga)
 * @param paramTable parâmetros nomeados
 * @example
 *   PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');
 */
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam);

/**
 * Define as margens esquerda, superior e direita. A direita em branco fica
 * igual à esquerda.
 *
 * @param left margem esquerda
 * @param top margem superior
 * @param right margem direita (-1 = igual à esquerda)
 * @example
 *   PL_FPDF.SetMargins(20, 15);
 */
procedure SetMargins(left in number, top in number, right in number default -1);

/**
 * Define a margem esquerda. Com página já aberta e o cursor à esquerda da
 * margem nova, o cursor é trazido para ela.
 *
 * @param pMargin a margem, na unidade corrente
 * @example
 *   PL_FPDF.SetLeftMargin(25);
 */
procedure SetLeftMargin(pMargin in number);

/**
 * Define a margem superior, usada pelas páginas seguintes.
 *
 * @param pMargin a margem, na unidade corrente
 * @example
 *   PL_FPDF.SetTopMargin(15);
 */
procedure SetTopMargin(pMargin in number);

/**
 * Define a margem direita, que é o que limita a largura de uma célula pedida
 * com largura 0.
 *
 * @param pMargin a margem, na unidade corrente
 * @example
 *   PL_FPDF.SetRightMargin(20);
 */
procedure SetRightMargin(pMargin in number);

/**
 * Liga ou desliga a quebra automática e define a margem de rodapé que a
 * dispara. Desligada, o conteúdo que passar do fim da página é escrito fora
 * dela e some -- sem erro nenhum.
 *
 * @param pauto ligar a quebra automática
 * @param pMargin margem de rodapé que dispara
 * @example
 *   PL_FPDF.SetAutoPageBreak(TRUE, 20);
 */
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0);

/**
 * Diz ao leitor de PDF como abrir o documento. É preferência de apresentação:
 * o leitor pode ignorar.
 *
 * @param zoom 'fullpage' (página inteira), 'fullwidth' (largura da página),
 *        'real' (tamanho real), 'default' (padrão do leitor), ou um número que
 *        é o percentual de ampliação
 * @param layout 'single' (uma página), 'continuous' (contínuo), 'two' (duas
 *        colunas), 'default' (padrão do leitor)
 * @raises -20100 modo de zoom ou de layout desconhecido
 * @example
 *   PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
 */
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous');

/**
 * Liga a compressão dos fluxos de conteúdo. Até agosto/2026 isto não fazia
 * nada -- procurava uma rotina de zlib que o Oracle não tem e desligava
 * sempre. Hoje o deflate está escrito no próprio pacote (PL_FPDF_UTIL.deflate)
 * e a opção vale.
 *
 * @param p_compress comprimir os fluxos
 * @example
 *   PL_FPDF.SetCompression(TRUE);
 */
procedure SetCompression(p_compress in boolean default false);

/**
 * Grava o título nos metadados do PDF -- o que o leitor mostra na barra de
 * título e o que o buscador indexa.
 *
 * @param ptitle o título
 * @example
 *   PL_FPDF.SetTitle('Relatório de Produção');
 */
procedure SetTitle(ptitle in varchar2);

/**
 * Grava o assunto nos metadados do PDF.
 *
 * @param psubject o assunto
 * @example
 *   PL_FPDF.SetSubject('Fechamento mensal');
 */
procedure SetSubject(psubject in varchar2);

/**
 * Grava o autor nos metadados do PDF.
 *
 * @param pauthor o autor
 * @example
 *   PL_FPDF.SetAuthor('Departamento Financeiro');
 */
procedure SetAuthor(pauthor in varchar2);

/**
 * Grava as palavras-chave nos metadados do PDF, separadas por espaço.
 *
 * @param pkeywords as palavras-chave
 * @example
 *   PL_FPDF.SetKeywords('relatorio producao 2026');
 */
procedure SetKeywords(pkeywords in varchar2);

/**
 * Grava, nos metadados, o nome do sistema que gerou o documento.
 *
 * @param pcreator o sistema gerador
 * @example
 *   PL_FPDF.SetCreator('ERP - modulo de faturamento');
 */
procedure SetCreator(pcreator in varchar2);

/**
 * Define o texto que será trocado pelo total de páginas na hora de fechar o
 * documento. É como se escreve "página 3 de 12" sem saber o 12 enquanto se
 * escreve a página 3.
 *
 * @param palias o marcador
 * @example
 *   PL_FPDF.SetAliasNbPages;
 *   PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo || ' de {nb}');
 */
procedure SetAliasNbPages(palias in varchar2 default '{nb}');

/**
 * Executa a rotina registrada em SetHeaderProc. É chamada sozinha ao abrir
 * cada página; não se chama à mão.
 *
 * @example
 *   PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');   -- e o resto é automático
 */
procedure Header;

/**
 * Executa a rotina registrada em SetFooterProc. É chamada sozinha ao fechar
 * cada página; não se chama à mão.
 *
 * @example
 *   PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');      -- e o resto é automático
 */
procedure Footer;

/**
 * Devolve o número da página que está sendo escrita, começando em 1.
 *
 * @return NUMBER - a página corrente
 * @example
 *   PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo);
 */
function  PageNo return number;

/**
 * Define a cor com que se desenham linhas, contornos e bordas de célula. Com
 * um argumento só, é tom de cinza (0 preto, 255 branco); com três, é RGB. Vale
 * do ponto em que é chamada em diante.
 *
 * @param r vermelho, ou o nível de cinza (0..255)
 * @param g verde (0..255)
 * @param b azul (0..255)
 * @raises -20501 componente fora de 0..255
 * @example
 *   PL_FPDF.SetDrawColor(200);            -- cinza claro
 *   PL_FPDF.SetDrawColor(0, 90, 160);     -- azul
 */
procedure SetDrawColor(r in number, g in number default -1, b in number default -1);

/**
 * Define a cor de fundo das células preenchidas e das formas com estilo 'F'.
 * Um argumento é cinza, três são RGB.
 *
 * @param r vermelho, ou o nível de cinza (0..255)
 * @param g verde (0..255)
 * @param b azul (0..255)
 * @raises -20501 componente fora de 0..255
 * @example
 *   PL_FPDF.SetFillColor(230, 230, 230);
 *   PL_FPDF.Cell(40, 8, 'Cabecalho', '1', 0, 'C', 1);
 */
procedure SetFillColor (r in number, g in number default -1, b in number default -1);

/**
 * Define a cor do texto. Um argumento é cinza, três são RGB.
 *
 * @param r vermelho, ou o nível de cinza (0..255)
 * @param g verde (0..255)
 * @param b azul (0..255)
 * @raises -20501 componente fora de 0..255
 * @example
 *   PL_FPDF.SetTextColor(180, 0, 0);
 */
procedure SetTextColor (r in number, g in number default -1, b in number default -1);

/**
 * Define a espessura do traço, na unidade corrente.
 *
 * @param width a espessura, maior que zero
 * @raises -20502 espessura zero ou negativa
 * @example
 *   PL_FPDF.SetLineWidth(0.5);
 */
procedure SetLineWidth(width in number);

/**
 * Desenha um segmento de reta entre dois pontos, com a cor e a espessura
 * correntes.
 *
 * @param x1 ponto inicial
 * @param y1 ponto inicial
 * @param x2 ponto final
 * @param y2 ponto final
 * @example
 *   PL_FPDF.Line(20, 60, 190, 60);
 */
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number);

/**
 * Desenha um retângulo a partir do canto superior esquerdo.
 *
 * @param px canto superior esquerdo
 * @param py canto superior esquerdo
 * @param pw largura
 * @param ph altura
 * @param pstyle '' contorna (padrão), 'F' preenche (Fill), 'FD' ou 'DF'
 *        preenche e contorna (Fill and Draw)
 * @example
 *   PL_FPDF.Rect(20, 40, 60, 25, 'FD');
 */
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '');

/**
 * RECUSA com -20601. Criaria um link interno, e link interno não está
 * implementado: o /Dest nunca chegou a ser escrito no arquivo, então o
 * identificador que esta função devolveria não levaria a lugar nenhum -- e o
 * Link o recusa. Até setembro/2026 a chamada levantava ORA-06531, "reference
 * to uninitialized collection", porque a coleção interna nunca foi
 * inicializada: nunca funcionou, em nenhuma versão. Passa a recusar com
 * mensagem que diz o que usar no lugar.
 *
 * @return NUMBER - nunca devolve: levanta antes
 * @raises -20601 link interno não implementado
 * @example
 *   -- Use URL:
 *   PL_FPDF.Cell(60, 8, 'Site', plink => 'https://example.com');
 */
function  AddLink return number;

/**
 * RECUSA com -20601, pelo mesmo motivo do AddLink: guardar o destino não
 * adiantaria, porque o /Dest não é emitido e ninguém o lê. Até setembro/2026
 * levantava ORA-06531.
 *
 * @param plink identificador devolvido por AddLink
 * @param py ordenada de chegada (-1 = a posição corrente)
 * @param ppage página de chegada (-1 = a página corrente)
 * @raises -20601 link interno não implementado
 * @example
 *   -- Use URL:
 *   PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
 */
procedure SetLink(plink in number, py in number default 0, ppage in number default -1);

/**
 * Marca uma área retangular como clicável, levando a uma URL.
 *
 * @param px canto superior esquerdo da área
 * @param py canto superior esquerdo da área
 * @param pw largura
 * @param ph altura
 * @param plink a URL
 * @limitation 1. Uma área por página. Uma segunda chamada na mesma página
 *             substitui a primeira, em silêncio -- a estrutura guarda um
 *             registro por página. Documentado por ser assim, não por ser o
 *             desejável. 2. Link interno não é suportado, e é RECUSADO com
 *             -20601. O ramo que escreveria o /Dest saiu comentado no porte
 *             original e nunca voltou; emiti-lo assim produzia um /Annot com o
 *             dicionário aberto, isto é, arquivo malformado. Desde
 *             setembro/2026 a chamada levanta erro em vez de gravar o arquivo
 *             quebrado. Use URL.
 * @example
 *   PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
 * @raises -20601 destino não é URL -- link interno ou NULL
 */
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2);

/**
 * Escreve texto num ponto exato, sem célula, sem quebra e sem mover o cursor.
 * (px, py) é a LINHA DE BASE do texto, não o topo dele.
 *
 * @param px a linha de base
 * @param py a linha de base
 * @param ptxt o texto
 * @raises -20203 caractere fora do WinAnsi
 * @example
 *   PL_FPDF.Text(20, 50, 'Endereço de cobrança');
 */
procedure Text(px in number, py in number, ptxt in varchar2);

/**
 * Diz se a quebra automática está ligada. É consultada pelo Cell antes de
 * decidir abrir página nova.
 *
 * @return BOOLEAN - TRUE se a quebra automática está ligada
 * @example
 *   IF PL_FPDF.AcceptPageBreak THEN ... END IF;
 */
function  AcceptPageBreak return boolean;

/**
 * Registra uma fonte para uso pelo SetFont. Para as 14 fontes padrão do PDF
 * não é preciso chamar isto -- elas já estão disponíveis, e escrevem acentuado
 * desde a 3.4.0.
 *
 * @param family nome da família
 * @param style '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'BI' os
 *        dois
 * @param filename arquivo de métricas da fonte
 * @example
 *   PL_FPDF.AddFont('Arial', 'B');
 */
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '');

/**
 * Escolhe a fonte, o estilo e o corpo do texto que vier depois. Corpo zero
 * mantém o que já estava. As fontes padrão -- Helvetica, Times, Courier,
 * Symbol e ZapfDingbats -- não precisam ser carregadas.
 *
 * @param pfamily família ('Helvetica', 'Times', 'Courier'...)
 * @param pstyle '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'U'
 *        sublinhado (Underline), ou a combinação
 * @param psize corpo em pontos (0 = mantém)
 * @note A família é guardada em minúscula e o estilo em maiúscula. É o que os
 *       getters devolvem, e não o texto que entrou aqui.
 * @raises -20005 Init ainda não foi chamado
 * @raises -20201 fonte não encontrada -- nem entre as padrão, nem no registro
 *         de TrueType
 * @raises -20100 estilo inválido
 * @example
 *   PL_FPDF.SetFont('Helvetica', 'B', 12);
 */
procedure SetFont(pfamily in varchar2,pstyle in varchar2 default '', psize in number default 0);

/**
 * Mede quanto o texto ocupa na fonte e no corpo correntes, na unidade em uso.
 * É o que permite alinhar, centralizar e decidir onde quebrar. Caractere
 * acentuado mede o mesmo que o caractere base -- nas 14 fontes padrão do PDF o
 * glifo acentuado tem a mesma largura de avanço.
 *
 * @param pstr o texto a medir
 * @return NUMBER - a largura, na unidade corrente
 * @raises -20203 caractere fora do WinAnsi
 * @example
 *   l_larg := PL_FPDF.GetStringWidth('São Paulo');
 */
function GetStringWidth(pstr in varchar2) return number;

/**
 * Troca só o corpo, mantendo família e estilo.
 *
 * @param psize corpo em pontos
 * @example
 *   PL_FPDF.SetFontSize(8);
 */
procedure SetFontSize(psize in number);

/**
 * Escreve uma célula retangular: opcionalmente com borda, com fundo e com
 * texto dentro, e move o cursor conforme pln. É a rotina mais usada da
 * biblioteca. Se a célula não couber no que resta da página e a quebra
 * automática estiver ligada, a página é trocada antes de escrever.
 *
 * @param pw largura; 0 vai até a margem direita
 * @param ph altura
 * @param ptxt o texto
 * @param pborder '0' sem borda, '1' moldura inteira, ou as letras dos lados
 *        que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo),
 *        'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas
 *        laterais; 'TB', só topo e base
 * @param pln para onde vai o cursor:
 *        0 = à direita da célula
 *        1 = próxima linha, na margem esquerda
 *        2 = abaixo, mantendo o x
 * @param palign 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right,
 *        direita)
 * @param pfill 1 pinta o fundo com a cor de SetFillColor, 0 não
 * @param plink URL ou identificador de link interno
 * @raises -20100 qualquer falha na escrita da célula. O Cell embrulha o erro
 *         original neste código, mas preserva a pilha (keeperrorstack), de
 *         modo que a causa -- um ORA-20203 de caractere fora do WinAnsi, por
 *         exemplo -- continua visível no rastro.
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
 * Escreve um bloco de texto que quebra sozinho na largura pedida, uma célula
 * por linha, e devolve quantas linhas saíram. A quebra respeita o espaço entre
 * palavras e a quebra explícita (CHR(10)). Esta é a versão FUNCTION, para quem
 * precisa saber quantas linhas foram gastas -- para calcular a altura de uma
 * tabela, tipicamente.
 *
 * @param pw largura do bloco; 0 vai até a margem direita
 * @param ph altura de cada linha; em branco usa a entrelinha de SetLineSpacing
 * @param ptxt o texto
 * @param pborder '0' sem borda, '1' moldura inteira, ou as letras dos lados
 *        que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo),
 *        'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas
 *        laterais; 'TB', só topo e base
 * @param palign 'J' justificado (Justified, o padrão), 'L' (Left, esquerda),
 *        'C' (Center, centro) ou 'R' (Right, direita)
 * @param pfill 1 pinta o fundo, 0 não
 * @param phMax altura máxima do bloco; 0 sem limite
 * @return NUMBER - quantas linhas foram escritas
 * @raises -20100 qualquer falha na escrita, com a pilha original preservada
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
 * Escreve texto corrido a partir de onde o cursor está, indo até a margem
 * direita e continuando na linha seguinte -- como um parágrafo de processador
 * de texto. Diferente do MultiCell, começa no meio da linha onde o cursor
 * parou, o que é o que se quer para emendar texto de formatações diferentes.
 *
 * @param pH altura da linha, na unidade corrente
 * @param ptxt o texto
 * @param plink URL ou identificador de link interno
 * @raises -20100 qualquer falha na escrita, com a pilha original preservada
 * @example
 *   PL_FPDF.SetFont('Helvetica', '', 10);
 *   PL_FPDF.Write(5, 'Consulte o ');
 *   PL_FPDF.SetFont('Helvetica', 'U', 10);
 *   PL_FPDF.Write(5, 'manual', 'https://example.com/manual');
 */
procedure Write(pH in varchar2, ptxt in varchar2, plink in varchar2 default null);

/**
 * O mesmo que Cell, com o texto girado dentro da célula. Serve para cabeçalho
 * de coluna estreita e para carimbo na lateral da página.
 *
 * @param p_width largura; 0 vai até a margem direita
 * @param p_height altura
 * @param p_text o texto
 * @param p_border '0' sem borda, '1' moldura inteira, ou as letras dos lados
 *        que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo),
 *        'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas
 *        laterais; 'TB', só topo e base
 * @param p_ln 0 à direita, 1 próxima linha na margem esquerda, 2 abaixo
 *        mantendo o x
 * @param p_align 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right,
 *        direita)
 * @param p_fill 1 pinta o fundo, 0 não
 * @param p_link URL ou link interno
 * @param p_rotation giro do texto em graus (0, 90, 180, 270)
 * @raises -20110 giro inválido
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
 * O mesmo que Write, com o texto girado.
 *
 * @param p_height altura da linha
 * @param p_text o texto
 * @param p_link URL ou link interno
 * @param p_rotation giro em graus (0, 90, 180, 270)
 * @raises -20110 giro inválido
 * @raises -20111 só o giro de 0 grau é suportado; use CellRotated
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
 * Coloca uma imagem buscada por URL. A busca sai pela rede e exige ACL
 * concedida ao schema -- quando a imagem já está numa tabela ou numa variável,
 * ImageFromBlob faz o mesmo sem rede e sem permissão. Largura e altura em zero
 * saem da própria imagem, a 72 dpi; com uma das duas em zero, ela é derivada
 * da outra, mantendo a proporção.
 *
 * @param pFile URL da imagem
 * @param pX canto superior esquerdo
 * @param pY canto superior esquerdo
 * @param pWidth largura (0 = derivada)
 * @param pHeight altura (0 = derivada)
 * @param pType formato, quando não se quer deduzir do arquivo
 * @param pLink URL ou identificador de link interno sobre a imagem
 * @raises -20100 falha ao buscar ou interpretar a imagem, com a pilha original
 *         preservada
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
 * Coloca uma imagem que o chamador já tem em mãos, sem passar por URL. O
 * Image() busca pela rede e exige ACL concedida ao schema; quando a imagem já
 * está numa tabela ou numa variável, esta entrada dispensa a rede e a
 * permissão. O formato é reconhecido pelos primeiros bytes do arquivo, não
 * pela extensão: PNG e JPEG; qualquer outra coisa é recusada.
 *
 * @param p_blob bytes da imagem (PNG ou JPEG)
 * @param p_name chave no cache de imagens. Um BLOB não tem nome, então o
 *        chamador escolhe: nomes distintos para imagens distintas, e o mesmo
 *        nome reaproveita o objeto já emitido no documento
 * @param pX posição, na unidade corrente
 * @param pY posição, na unidade corrente
 * @param pWidth largura (0 = derivada)
 * @param pHeight altura (0 = derivada)
 * @param pLink link opcional sobre a área da imagem
 * @raises -20301 cabeçalho inválido, BLOB vazio ou nome ausente
 * @raises -20303 formato não suportado
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
 * Fecha o documento e grava em arquivo, no DIRECTORY PDF_DIR. É a forma
 * legada: os modos de entrega ao navegador ('I', 'D', 'S') saíram junto com o
 * OWA/HTP e hoje recusam com -20306, dizendo o que usar no lugar. Para receber
 * os bytes, use OutputBlob.
 *
 * @param pname nome do arquivo (NULL grava 'doc.pdf')
 * @param pdest destino: 'F' (File, arquivo) é o único suportado
 * @raises -20100 destino desconhecido, ou falha na gravação
 * @raises -20306 modo de entrega ao navegador não é mais suportado; a mensagem
 *         aponta OutputBlob e o cabeçalho Content-Type
 * @example
 *   PL_FPDF.Output('relatorio.pdf', 'F');
 */
procedure Output(pname in varchar2 default null, pdest in varchar2 default null);

/**
 * Fecha o documento e devolve os bytes. Existe por compatibilidade: os dois
 * parâmetros são ACEITOS E IGNORADOS, e a chamada é repassada ao OutputBlob.
 * Em código novo, chame OutputBlob direto.
 *
 * @param pname ignorado
 * @param pdest ignorado
 * @return BLOB - o PDF
 * @raises -20100 falha ao fechar ou montar o documento, com a pilha original
 *         preservada
 * @example
 *   l_pdf := PL_FPDF.OutputBlob;    -- prefira esta
 */
function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null) return blob;

/**
 * Fecha o documento e devolve os bytes do PDF. É a saída principal da
 * biblioteca: quem grava em tabela, quem anexa a e-mail e quem entrega por
 * HTTP começa aqui.
 *
 * @return BLOB - o PDF pronto
 * @raises -20005 Init ainda não foi chamado. Antes de agosto/2026 esta chamada
 *         seguia em frente e devolvia um PDF vazio, sem apontar a causa.
 * @example
 *   l_pdf := PL_FPDF.OutputBlob;
 *   INSERT INTO documentos (id, arquivo) VALUES (1, l_pdf);
 */
function OutputBlob return blob;

/**
 * Fecha o documento e grava num DIRECTORY do banco. Exige WRITE no diretório
 * concedido ao schema.
 *
 * @param p_filename nome do arquivo
 * @param p_directory DIRECTORY do banco
 * @raises -20401 diretório inválido
 * @raises -20402 sem permissão de escrita
 * @raises -20403 falha ao gravar
 * @example
 *   PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
 */
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

/**
 * Marca o documento como aberto. O AddPage já faz isto quando preciso; chamar
 * à mão é raro.
 *
 * @example
 *   PL_FPDF.OpenPDF;
 */
procedure OpenPDF;

/**
 * Fecha o documento: escreve o rodapé da última página, monta a estrutura do
 * arquivo e troca o marcador do total de páginas. Sem nenhuma página, uma é
 * criada em branco. As rotinas de saída chamam isto sozinhas.
 *
 * @example
 *   PL_FPDF.ClosePDF;
 */
procedure ClosePDF;

/**
 * Fecha a página corrente, executando o rodapé, e abre outra, executando o
 * cabeçalho. Orientação e formato em branco repetem os da página anterior.
 * Além dos formatos com nome, aceita 'largura,altura' na unidade corrente.
 *
 * @param p_orientation 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem);
 *        NULL mantém a da página anterior
 * @param p_format 'A4', 'Letter', 'Legal', ou 'largura,altura'; NULL mantém o
 *        anterior
 * @param p_rotation giro da página em graus (0, 90, 180, 270)
 * @raises -20005 Init ainda não foi chamado
 * @raises -20107 orientação inválida
 * @raises -20103 formato desconhecido
 * @raises -20101 dimensões inválidas no formato livre
 * @raises -20104 giro inválido
 * @note O NOME do primeiro parâmetro mudou entre versões -- era 'orientation'
 *       na 2.0.0 e hoje é 'p_orientation'. Quem chama por posição
 *       (AddPage('L')) não sente nada; quem chama por nome
 *       (AddPage(orientation => 'L')) precisa acertar o nome. Não há como
 *       aceitar os dois: sobrecargas que diferem só pelo nome do parâmetro
 *       deixam a chamada ambígua, e o Oracle recusa com PLS-00307. Quem chama
 *       por posição não é afetado.
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
 * Torna corrente uma página já criada, para escrever nela de novo. Serve para
 * preencher depois um espaço que só se sabe no fim -- um total, por exemplo.
 *
 * @param p_page_number a página, que precisa existir
 * @raises -20005 Init ainda não foi chamado
 * @raises -20106 a página não existe
 * @example
 *   PL_FPDF.SetPage(1);
 */
procedure SetPage(p_page_number pls_integer);

/**
 * Devolve o número da página em que se está escrevendo.
 *
 * @return PLS_INTEGER - a página corrente
 * @example
 *   l_pagina := PL_FPDF.GetCurrentPage;
 */
function GetCurrentPage return pls_integer
  DETERMINISTIC;

/**
 * Construtor herdado do FPDF original. Continua valendo, e o código escrito
 * para as versões 0.9.4 e 2.0.0 segue rodando com ele. Em código novo prefira
 * Init, que valida os argumentos e levanta erro nomeado em vez de seguir com
 * um valor inesperado.
 *
 * @param orientation 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem)
 * @param unit unidade de medida ('mm','cm','in','pt')
 * @param format formato da página ('A4', 'Letter'...)
 * @example
 *   PL_FPDF.fpdf('L', 'mm', 'A4');
 */
procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');

/**
 * Levanta ORA-20100 com a mensagem dada, acrescentando o rastro da origem e
 * preservando a pilha original (keeperrorstack) -- é isso que mantém
 * rastreável o erro de verdade por trás do -20100. É o caminho interno de erro
 * da biblioteca; está público por herança.
 *
 * @param pmsg a mensagem
 * @raises -20100 sempre; é o que esta rotina faz
 * @example
 *   PL_FPDF.Error('nao foi possivel montar o documento');
 */
procedure Error(pmsg in varchar2);

/**
 * Liga a saída de diagnóstico do tratamento de erro. Serve para depuração; num
 * processo em produção deixa o erro mais verboso.
 *
 * @example
 *   PL_FPDF.DebugEnabled;
 */
procedure DebugEnabled;

/**
 * Desliga a saída de diagnóstico. É o estado padrão.
 *
 * @example
 *   PL_FPDF.DebugDisabled;
 */
procedure DebugDisabled;

/**
 * Devolve quantos pontos PDF valem uma unidade corrente -- 2,8346 para
 * milímetro, 1 para ponto. É o número que converte entre a unidade do chamador
 * e a do arquivo.
 *
 * @return NUMBER - pontos por unidade
 * @example
 *   l_pontos := 10 * PL_FPDF.GetScaleFactor;
 */
function GetScaleFactor return number;

/**
 * Busca uma imagem pela rede e devolve os bytes com o cabeçalho já
 * interpretado. Exige ACL de rede concedida ao schema. Substitui a
 * implementação sobre OrdImage, que saiu de linha.
 *
 * @param p_Url a URL da imagem (http/https)
 * @return recImageBlob - os bytes e os metadados
 * @note Formatos aceitos:
 *   PNG, JPEG/JPG
 * @raises -20301 cabeçalho de imagem inválido
 * @raises -20302 não foi possível buscar a imagem
 * @raises -20303 formato não suportado
 * @example
 *   l_img := PL_FPDF.getImageFromUrl('https://example.com/logo.png');
 */
function getImageFromUrl(p_Url in varchar2) return recImageBlob;

/**
 * Define quanta informação a biblioteca escreve no DBMS_OUTPUT.
 *
 * @param p_level 0 desligado (OFF), 1 erro (ERROR), 2 aviso (WARN), 3
 *        informação (INFO), 4 depuração (DEBUG)
 * @raises -20100 nível fora da faixa 0..4
 * @example
 *   PL_FPDF.SetLogLevel(3);
 */
procedure SetLogLevel(p_level pls_integer);

/**
 * Devolve o nível de registro em uso.
 *
 * @return PLS_INTEGER - o nível corrente (0-4)
 * @example
 *   l_nivel := PL_FPDF.GetLogLevel;
 */
function GetLogLevel return pls_integer
  DETERMINISTIC;

/**
 * Configura o documento inteiro a partir de um objeto JSON -- metadados,
 * orientação, formato, fonte e margens numa chamada só. Serve a quem recebe a
 * configuração de fora, de uma tabela ou de um serviço.
 *
 * @param p_config o objeto JSON com as opções
 * @note Chaves JSON:
 *   - title, author, subject, keywords, creator (metadados do documento)
 *   - orientation ('P' ou 'L'), unit ('mm','cm','in','pt'), format (formato da
 *     página)
 *   - fontFamily, fontSize, fontStyle (fonte padrão)
 *   - leftMargin, topMargin, rightMargin (margens, na unidade corrente)
 * @raises -20001 orientação inválida; só P ou L
 * @raises -20002 unidade inválida; só mm, cm, in ou pt
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
 * Devolve, em JSON, o que está configurado no documento em andamento e quantas
 * páginas ele já tem.
 *
 * @return JSON_OBJECT_T - os metadados
 * @note Estrutura do JSON:
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
 * Devolve, em JSON, o formato, a orientação e as medidas de uma página do
 * documento em andamento.
 *
 * @param p_page_number a página (NULL = a corrente)
 * @return JSON_OBJECT_T - os dados da página
 * @note Estrutura do JSON:
 *   {
 *     "number": <number>,
 *     "format": "<string>",
 *     "orientation": "<string>",
 *     "width": <number>,
 *     "height": <number>,
 *     "unit": "<string>"
 *   }
 * @raises -20106 a página não existe
 * @raises -20812 número de página fora da faixa
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
 * Desenha um QR Code na página corrente. O codificador é o do PL_FPDF_UTIL,
 * validado contra o zxing-cpp -- o critério aqui não é "desenha um símbolo", é
 * "um leitor decodifica".
 *
 * @param p_x canto superior esquerdo, na unidade corrente
 * @param p_y canto superior esquerdo, na unidade corrente
 * @param p_size o lado do símbolo
 * @param p_data o conteúdo a codificar
 * @param p_format 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'
 * @param p_error_correction quanto do símbolo pode ser perdido e ainda assim
 *        ler: 'L' (Low, 7%), 'M' (Medium, 15%), 'Q' (Quartile, 25%) ou
 *        'H' (High, 30%). Quanto maior, mais módulos o símbolo ocupa
 * @raises -20870 conteúdo vazio
 * @raises -20872 nível de correção inválido
 * @raises -20871 tamanho não positivo
 * @raises -20873 conteúdo além da capacidade do QR Code
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
 * Desenha um código de barras linear na página corrente. O codificador é o do
 * PL_FPDF_UTIL, validado contra o zxing-cpp.
 *
 * @param p_x canto superior esquerdo
 * @param p_y canto superior esquerdo
 * @param p_width largura
 * @param p_height altura
 * @param p_code o conteúdo a codificar
 * @param p_type simbologia: 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF14',
 *        ou 'ITF' (Interleaved 2 of 5, qualquer quantidade par de dígitos --
 *        o código de barras do boleto bancário tem 44)
 * @param p_show_text escrever o código embaixo, legível
 * @raises -20880 código vazio
 * @raises -20882 simbologia não suportada
 * @raises -20881 largura ou altura não positiva
 * @raises -20883 CODE39 não aceita o caractere informado
 * @raises -20884 CODE128 aceita só ASCII de 32 a 126
 * @raises -20885 EAN com quantidade de dígitos errada
 * @raises -20886 EAN com dígito verificador inválido
 * @raises -20887 ITF14 exige 13 dígitos (verificador calculado) ou 14
 * @raises -20888 ITF sem nenhum dígito no conteúdo
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
 * Carregar documento PDF existente na memória para leitura e modificação
 *
 * @param p_pdf_blob Documento PDF como BLOB
 * @raises -20800 PDF nulo, ou pequeno demais para ter cabeçalho e trailer
 * @raises -20801 Cabeçalho PDF inválido
 * @raises -20802 startxref não encontrado
 * @raises -20803 Tabela xref inválida
 * @raises -20804 Objeto Root não encontrado
 * @example
 *   DECLARE
 *     l_pdf BLOB;
 *   BEGIN
 *     SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     DBMS_OUTPUT.PUT_LINE('Páginas:' || PL_FPDF.GetPageCount());
 *   END;
 */
PROCEDURE LoadPDF(p_pdf_blob BLOB);

/**
 * Obter o número total de páginas no documento PDF carregado
 *
 * @return Número de páginas
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @example
 *   l_pages := PL_FPDF.GetPageCount();
 *   DBMS_OUTPUT.PUT_LINE('Total de páginas:' || l_pages);
 */
FUNCTION GetPageCount RETURN PLS_INTEGER;

/**
 * Obter metadados e informações sobre o documento PDF carregado
 *
 * @return
 *   com:
 *   - version: versão do PDF (por exemplo "1.4")
 *   - pageCount: Número de páginas
 *   - fileSize: Tamanho em bytes
 *   - objectCount: Número de objetos na xref
 *   - rootObjectId: ID do objeto Catalog
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @example
 *   DECLARE
 *     l_info JSON_OBJECT_T;
 *   BEGIN
 *     l_info := PL_FPDF.GetPDFInfo();
 *     DBMS_OUTPUT.PUT_LINE('Versão:' || l_info.get_string('version'));
 *     DBMS_OUTPUT.PUT_LINE('Páginas:' || l_info.get_number('pageCount'));
 *   END;
 */
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;

/**
 * Rotacionar uma página específica (armazenado em memória, aplicado na saída)
 *
 * @param p_page_number Número da página para rotacionar
 * @param p_rotation Ângulo de rotação (0, 90, 180, 270)
 * @note Mudanças armazenadas em memória. Use OutputModifiedPDF() para gerar
 *       PDF
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @raises -20813 giro inválido; só 0, 90, 180 ou 270
 * @raises -20810 /Pages não encontrado no catálogo do PDF
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   PL_FPDF.RotatePage(1, 90);    -- Rotacionar página 1
 *   PL_FPDF.RotatePage(2, 180);   -- Rotacionar página 2
 */
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER);

/**
 * Marcar uma página para remoção do PDF
 *
 * @param p_page_number Número da página para remover
 * @note Página marcada para remoção. Use OutputModifiedPDF() para gerar PDF
 *       modificado
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @raises -20812 número de página fora da faixa
 * @raises -20814 a página já estava marcada para remoção
 * @raises -20810 /Pages não encontrado no catálogo do PDF
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   PL_FPDF.RemovePage(2);  -- Remover página 2
 *   PL_FPDF.RemovePage(5);  -- Remover página 5
 */
PROCEDURE RemovePage(p_page_number PLS_INTEGER);

/**
 * Obter contagem de páginas não marcadas para remoção
 *
 * @return Número de páginas ativas
 * @note Difere de GetPageCount() que retorna a contagem original
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @example
 *   l_total := PL_FPDF.GetPageCount();        -- Original: 10
 *   PL_FPDF.RemovePage(2);
 *   l_active := PL_FPDF.GetActivePageCount(); -- Ativas: 9
 */
FUNCTION GetActivePageCount RETURN PLS_INTEGER;

/**
 * Verificar se uma página está marcada para remoção
 *
 * @param p_page_number Número da página para verificar
 * @return caso contrário
 * @example
 *   IF PL_FPDF.IsPageRemoved(2) THEN
 *     DBMS_OUTPUT.PUT_LINE('Página 2 removida');
 *   END IF;
 */
FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN;

/**
 * Verificar se o PDF carregado foi modificado
 *
 * @return TRUE se modificado, FALSE caso contrário
 * @note Use para determinar se OutputModifiedPDF() precisa ser chamado
 * @example
 *   IF PL_FPDF.IsPDFModified() THEN
 *     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
 *   END IF;
 */
FUNCTION IsPDFModified RETURN BOOLEAN;

/**
 * Acrescenta marca d'água de texto às páginas indicadas
 *
 * @param p_text Texto da marca d'água
 * @param p_opacity Opacidade (0.0 a 1.0), padrão 0.3
 * @param p_rotation Ângulo de rotação (0, 45, 90, 135, 180, 225, 270, 315),
 *        default 45
 * @param p_pages Range de páginas: 'ALL', '1-5', '1,3,5', default 'ALL'
 * @param p_font Nome da fonte, default 'Helvetica'
 * @param p_size Tamanho da fonte em pontos, default 48
 * @param p_color Nome da cor ('gray', 'red', 'blue'), default 'gray'
 * @note Desenhada por OutputModifiedPDF() no fluxo de conteúdo: cada página
 *       afetada ganha um objeto de conteúdo próprio e um /Resources próprio,
 *       de modo que um /Resources compartilhado entre páginas nunca é
 *       contaminado. Centralizada e girada em torno do centro da página; a
 *       fonte é sempre Helvetica.
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @raises -20816 texto da marca vazio
 * @raises -20817 opacidade fora de 0..1
 * @raises -20818 rotação fora de 0, 45, 90, 135, 180, 225, 270, 315
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   -- Todas as páginas
 *   PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
 *   -- Páginas específicas
 *   PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
 *   -- Estilo personalizado
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
 * Obter lista de todas as marcas d'água aplicadas como array JSON
 *
 * @return
 *   JSON_ARRAY_T - array com os objetos de marca d'água e suas propriedades:
 *     - id: ID da marca d'água
 *     - text: Texto da marca d'água
 *     - opacity: Valor de opacidade (0.0-1.0) (0.0-1.0)
 *     - rotation: Ângulo de rotação em graus
 *     - pageRange: faixa de páginas (separada por vírgulas)
 *     - font: Nome da fonte
 *     - fontSize: Tamanho da fonte em pontos
 *     - color: Nome da cor
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
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
 *       DBMS_OUTPUT.PUT_LINE('Marca d''água:' ||
 *                            l_watermark.get_string('text'));
 *     END LOOP;
 *   END;
 */
FUNCTION GetWatermarks RETURN JSON_ARRAY_T;

/**
 * Gerar o PDF modificado copiando as páginas mantidas objeto a objeto.
 * Conteúdo, fontes, imagens e anotações são copiados sem alteração: nada é
 * re-renderizado. Aplica RemovePage e RotatePage.
 *
 * @return Documento PDF modificado
 * @process 1. Valida se PDF está carregado e modificado 2. Indexa a origem
 *          (cadeia de xref + árvore de páginas achatada) 3. Seleciona as
 *          páginas não marcadas por RemovePage, na ordem original 4. Copia
 *          todo objeto alcançável a partir dessas páginas, renumerando as
 *          referências indiretas; o payload dos streams é copiado byte a byte
 *          5. Emite um novo Catalog, um novo nó /Pages, xref e trailer
 * @limitation Marcas d'água e overlays de texto e de imagem são todos
 *             desenhados. xref em stream e object streams (PDF 1.5+) são
 *             lidos, inclusive com o predictor PNG; um malformado levanta
 *             -20843/-20847/-20848.
 * @raises -20809 nenhum PDF carregado -- chame LoadPDF antes
 * @raises -20819 o PDF não foi modificado (sem alterações para aplicar)
 * @raises -20820 todas as páginas foram removidas (não dá para gerar PDF
 *         vazio)
 * @raises -20841 dicionário de objeto grande demais para renumerar
 * @raises -20843 xref em stream malformada
 * @raises -20847 object stream malformado
 * @raises -20848 predictor não suportado na xref em stream
 * @raises -20823 imagem inválida ou não suportada. PNG com alfa e entrelaçado
 *         são suportados; recusados são o entrelaçado abaixo de 8 bits por
 *         componente, o indexado E entrelaçado, e imagens acima de 4
 *         megapixels no caminho que reprocessa pixels
 * @raises -20846 o /Resources da página não pode ser sobreposto
 *         (subdicionário indireto compartilhado)
 * @example
 *   DECLARE
 *     l_pdf BLOB;
 *     l_modified_pdf BLOB;
 *   BEGIN
 *     -- Carregar PDF
 *     SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Aplicar modificações
 *     PL_FPDF.RotatePage(1, 90);
 *     PL_FPDF.RemovePage(3);
 *     -- Gerar PDF modificado
 *     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
 *     -- Salvar PDF modificado
 *     UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
 *     PL_FPDF.ClearPDFCache();
 *   END;
 */
FUNCTION OutputModifiedPDF RETURN BLOB;

/**
 * Limpar PDF carregado da memória e liberar todos os recursos em cache
 *
 * @note Sempre chame isso após processar um PDF para liberar recursos de
 *       memória. Limpa: PDF carregado, info páginas, rotações, páginas
 *       removidas, marcas d'água.
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   -- Processar PDF
 *   l_modified := PL_FPDF.OutputModifiedPDF();
 *   -- Limpar memória
 *   PL_FPDF.ClearPDFCache();
 */
PROCEDURE ClearPDFCache;

/**
 * Descomprime um stream /FlateDecode do PDF (zlib, RFC 1950). Implementado em
 * PL/SQL puro: o UTL_COMPRESS não serve porque só aceita rodapé gzip com
 * CRC-32 correto, e esse CRC é do conteúdo DESCOMPRIMIDO — para saber o CRC
 * seria preciso descomprimir antes.
 *
 * @param p_stream Stream comprimido (BLOB)
 * @param p_max_bytes Teto da saída, 8 MB por padrão. Um stream comprimido é
 *        entrada não confiável: alguns KB podem virar gigabytes (zip bomb) e
 *        derrubar a sessão. Levanta -20893 em vez disso.
 * @return Conteúdo descomprimido
 * @raises -20890 Stream truncado
 * @raises -20891 Dados DEFLATE malformados
 * @raises -20892 Cabeçalho zlib inválido
 * @raises -20893 Saída passou de p_max_bytes
 * @example
 *     l_claro := PL_FPDF.FlateDecode(l_comprimido);
 *   Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
 */
FUNCTION FlateDecode(
  p_stream    IN BLOB,
  p_max_bytes IN PLS_INTEGER DEFAULT 8388608
) RETURN BLOB;

/**
 * Comprime dados num stream /FlateDecode do PDF (zlib, RFC 1950). Escrito em
 * PL/SQL puro: um bloco único com Huffman fixa e LZ77 guloso. Comprime menos
 * que a Huffman dinâmica do zlib e muito mais que nada, e nunca devolve mais
 * que a entrada somada ao custo do bloco armazenado.
 *
 * @param p_data conteúdo a comprimir (BLOB)
 * @return BLOB - stream zlib: cabeçalho, DEFLATE e Adler-32
 * @example
 *     l_comprimido := PL_FPDF.FlateEncode(l_claro);
 *   Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
 */
FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB;

/**
 * Adicionar sobreposição de texto em posição específica com controle completo
 * de formatação Desenhada por OutputModifiedPDF() no fluxo de conteúdo. x e y
 * vão em pontos PDF, a partir do canto inferior esquerdo. Quando width é
 * informado ele define a CAIXA do texto: as linhas quebram dentro dela e o
 * align é relativo a [x, x+width]. Sem width não há o que quebrar, e o align
 * passa a ser relativo ao próprio ponto — 'center' centraliza o texto em x,
 * 'right' o termina em x.
 *
 * @param p_page_number Número da página (base 1)
 * @param p_text Conteúdo do texto
 * @param p_x Posição X (1 point = 1/72 inch, from left)
 * @param p_y Posição Y (de baixo) (from bottom)
 * @param p_options Configuração JSON (opcional)
 * @note Opções (JSON_OBJECT_T):
 *   {
 *     "font": "Helvetica",           // Nome da fonte
 *     "fontSize": 12,                // Tamanho da fonte
 *     "color": "000000",             // Cor RGB hexadecimal
 *     "opacity": 1.0,                // Opacidade 0.0 a 1.0
 *     "rotation": 0,                 // ângulo de rotação (0-360)
 *     "align": "left",               // esquerda, centro, direita
 *     "width": null,                 // largura máxima (quebra sozinho)
 *     "bold": false,                 // Texto em negrito
 *     "zOrder": 100                  // ordem da camada (maior fica por cima)
 *   }
 * @raises -20809 Nenhum PDF carregado
 * @raises -20810 Número de página inválido
 * @raises -20821 Coordenadas de posição inválidas, ou opacidade fora de
 *         0.0..1.0
 * @example
 *   DECLARE
 *     l_options JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Sobreposição simples
 *     PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
 *     -- Texto formatado
 *     l_options.put('font', 'Helvetica-Bold');
 *     l_options.put('fontSize', 24);
 *     l_options.put('color', 'FF0000');  -- Vermelho
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
 * Adicionar sobreposição de imagem em posição específica com controle de
 * tamanho Desenhada por OutputModifiedPDF() no fluxo de conteúdo. No caminho
 * comum nada é descomprimido: o JPEG entra inteiro como /DCTDecode, e os
 * blocos IDAT do PNG já são zlib, que é o /FlateDecode do PDF — são
 * concatenados e declarados com /Predictor 15, o que vale de 1 a 16 bits por
 * componente. PNG com canal alfa (color types 4 e 6) e entrelaçado (Adam7)
 * também são desenhados, por um caminho que reprocessa pixel a pixel — e por
 * isso sai sem compressão, já que não há deflate neste trecho. Recusados com
 * -20823, em vez de desenhados errado: entrelaçado com menos de 8 bits por
 * componente, indexado E entrelaçado, e imagem acima do teto de pixels do
 * caminho que reprocessa.
 *
 * @param p_page_number Número da página (base 1)
 * @param p_image_blob os bytes da imagem, em JPEG ou PNG
 * @param p_x Posição X em pontos PDF
 * @param p_y Posição Y (de baixo) (from bottom)
 * @param p_width Largura em pontos (NULL = original)
 * @param p_height Altura em pontos (NULL = original)
 * @param p_options Configuração JSON (opcional)
 * @note Opções (JSON_OBJECT_T):
 *   {
 *     "opacity": 1.0,                // Opacidade 0.0 a 1.0
 *     "rotation": 0,                 // Ângulo de rotação
 *     "maintainAspect": true,        // Manter proporção
 *     "scaleToFit": false,           // Escalar para caber
 *     "zOrder": 100                  // Ordem da camada
 *   }
 * @raises -20809 Nenhum PDF carregado
 * @raises -20810 Número de página inválido
 * @raises -20821 Coordenadas de posição inválidas
 * @raises -20823 formato de imagem inválido -- só JPEG ou PNG
 * @raises -20824 Dimensões da imagem inválidas
 * @example
 *   DECLARE
 *     l_logo BLOB;
 *     l_options JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Adicionar logo no canto superior direito
 *     PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
 *     -- Marca d'água com transparência
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
 * Obter lista de todas as sobreposições aplicadas como array JSON
 *
 * @param p_page_number filtrar por página (NULL = todas)
 * @return
 *   JSON_ARRAY_T - Array de objetos de sobreposição
 *     [{
 *       "overlayId": "OVL_001",
 *       "overlayType": "TEXT" | "IMAGE",
 *       "pageNumber": 1,
 *       "x": 100, "y": 700,
 *       "content": "APPROVED",     // só para sobreposição de texto
 *       "opacity": 0.8,
 *       "rotation": 45,
 *       "zOrder": 100
 *     }, ...]
 * @raises -20809 Nenhum PDF carregado
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
 * Remover sobreposição específica por ID
 *
 * @param p_overlay_id ID da sobreposição ()
 * @raises -20825 Sobreposição não encontrada
 * @example
 *   PL_FPDF.RemoveOverlay('OVL_001');
 */
PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2);

/**
 * Limpar todas as sobreposições de todas ou de página específica
 *
 * @param p_page_number limpar da página (NULL = todas)
 * @example
 *   -- Limpar todas as sobreposições
 *   PL_FPDF.ClearOverlays();
 *   -- Limpar apenas da página 1
 *   PL_FPDF.ClearOverlays(1);
 */
PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL);

/**
 * Carregar PDF em memória com identificador único para operações
 * multi-documento
 *
 * @param p_pdf_id Identificador único (max 50 chars)
 * @param p_pdf_blob Documento PDF como BLOB
 * @note Máximo de 10 PDFs podem ser carregados simultaneamente
 * @raises -20828 ID do PDF já carregado
 * @raises -20829 Máximo de PDFs excedido (10 max)
 * @raises -20830 identificador vazio ou longo demais
 * @raises -20800 PDF nulo ou pequeno demais para ser válido
 * @raises -20801 cabeçalho %PDF-x.x ausente ou malformado
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
 * Obter lista de todos os IDs de PDF carregados e seus metadados
 *
 * @return
 *   JSON_ARRAY_T - Array de objetos PDF
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
 * Remover PDF específico da memória para liberar recursos
 *
 * @param p_pdf_id Identificador do PDF
 * @raises -20831 ID do PDF não encontrado
 * @example
 *   PL_FPDF.UnloadPDF('report_jan');
 */
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);

/**
 * Mesclar múltiplos PDFs carregados em um único documento, na ordem dada.
 * Todos os objetos de cada origem são copiados (páginas, fontes, imagens,
 * anotações) com as referências indiretas renumeradas, e uma nova árvore de
 * páginas é montada. Nada é re-renderizado: o conteúdo original chega intacto.
 * O mesmo ID pode aparecer mais de uma vez.
 *
 * @param p_pdf_ids Array JSON de IDs de PDF Example:
 *        JSON_ARRAY_T('["pdf1","pdf2","pdf3"]')
 * @param p_options Configuração opcional (future use)
 * @return Documento PDF mesclado
 * @raises -20832 Nenhum ID de PDF fornecido
 * @raises -20833 ID de PDF na lista não carregado
 * @raises -20834 Mesclagem falhou
 * @raises -20841 Dicionário de objeto grande demais para renumerar
 * @raises -20843 xref em stream malformada
 * @raises -20847 object stream malformado
 * @raises -20848 predictor não suportado na xref em stream
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
 * Dividir o PDF carregado em vários documentos, um por intervalo. Cada parte
 * leva apenas os objetos alcançáveis a partir das suas páginas, e por isso
 * fica bem menor que a origem. Os intervalos não podem se sobrepor.
 *
 * @param p_pdf_id Identificador do PDF
 * @param p_page_ranges Array de intervalos Examples: '1-5', '6-10', '11',
 *        '1,3,5', 'ALL'
 * @return Array com PDFs em base64, um por intervalo, sem quebras de linha
 * @raises -20831 ID do PDF não encontrado
 * @raises -20835 Nenhum intervalo fornecido
 * @raises -20836 Intervalos sobrepostos
 * @raises -20838 Especificação de páginas inválida
 * @raises -20839 Número de página fora do intervalo
 * @raises -20843 xref em stream malformada
 * @raises -20847 object stream malformado
 * @raises -20848 predictor não suportado na xref em stream
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
 *       -- Processar cada parte
 *     END LOOP;
 *   END;
 */
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T;

/**
 * Extrair as páginas indicadas de um PDF carregado para um novo documento. A
 * ordem pedida é respeitada ('5,1' devolve a página 5 e depois a 1) e uma
 * página pode repetir. Só os objetos alcançáveis a partir das páginas
 * escolhidas são copiados, então o resultado fica menor que a origem.
 *
 * @param p_pdf_id Identificador do PDF
 * @param p_pages Especificação: '1', '1,3,5-7,10', '5,1' ou 'ALL'
 * @param p_options Configuração opcional (future use)
 * @return Novo PDF com páginas extraídas
 * @raises -20831 ID do PDF não encontrado
 * @raises -20838 Especificação de páginas inválida
 * @raises -20839 Número de página fora do intervalo
 * @raises -20841 Dicionário de objeto grande demais para renumerar
 * @raises -20843 xref em stream malformada
 * @raises -20847 object stream malformado
 * @raises -20848 predictor não suportado na xref em stream
 * @example
 *   DECLARE
 *     l_extracted BLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
 *     -- Extrair páginas 1, 5-10 e 15
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
 * Criptografar PDF com proteção por senha seguindo especificação PDF
 *
 * @param p_pdf PDF blob para criptografar
 * @param p_user_password Senha para abrir documento
 * @param p_owner_password senha de acesso total (opcional)
 * @param p_permissions JSON com flags de permissão
 * @param p_encryption Encryption method:
 *        'RC4-40','RC4-128','AES-128','AES-256'
 * @return PDF criptografado
 * @raises -20850 Método de criptografia inválido
 * @raises -20851 Senha obrigatória
 * @raises -20852 Falha na criptografia
 * @note Origem em PDF 1.5+ (xref em stream, object streams) é achatada: os
 *       objetos de dentro dos object streams viram objetos de primeiro nível e
 *       a saída leva xref clássica.
 * @raises -20859 o PDF já está cifrado; decifre antes
 * @raises -20860 PDF inválido: /Root não encontrado no trailer
 * @raises -20863 chave RC4 vazia
 * @raises -20864 conteúdo acima do limite que o RC4 desta base trata
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
 * Remover criptografia do PDF usando senha
 *
 * @param p_pdf PDF blob criptografado
 * @param p_password Senha de usuário ou owner
 * @return PDF descriptografado
 * @raises -20853 PDF não está criptografado
 * @raises -20854 Senha inválida
 * @raises -20855 Falha na descriptografia
 * @note Origem em PDF 1.5+ é achatada, e os object streams são decifrados
 *       antes de descomprimidos.
 * @raises -20861 dicionário /Encrypt não encontrado no PDF
 * @raises -20857 versão de PDF inválida
 * @example
 *   l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
 */
FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB;

/**
 * Verificar se PDF está criptografado
 *
 * @param p_pdf PDF blob para verificar
 * @return TRUE se criptografado
 * @example
 *   IF PL_FPDF.IsEncrypted(l_pdf) THEN ...
 */
FUNCTION IsEncrypted(p_pdf IN BLOB) RETURN BOOLEAN;

/**
 * Obter informações de segurança do PDF
 *
 * @param p_pdf PDF blob
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
 * Definir criptografia para PDF em geração (usar antes do Output)
 *
 * @param p_encryption Method: 'RC4-40','RC4-128','AES-128','AES-256'
 * @param p_user_password Senha para abrir
 * @param p_owner_password Senha acesso total
 * @raises -20850 método de cifragem não suportado
 * @raises -20851 senha inválida
 * @example
 *   PL_FPDF.Init;
 *   PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
 *   PL_FPDF.AddPage;
 *   l_pdf := PL_FPDF.OutputBlob;
 * @note Mapeamento de Versão:
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
 * Definir a versão do PDF para documentos gerados
 *
 * @param p_version PDF version: '1.4', '1.5', '1.6', '1.7', '2.0'
 * @note Recursos por Versão:
 *   1.4: cifra RC4 de 128 bits, transparência
 *   1.5: AES de 128 bits, object streams, cross-reference streams
 *   1.6: AES de 128 bits, fontes OpenType
 *   1.7: AES de 256 bits, formulários XFA
 *   2.0: só AES de 256 bits, sem RC4
 * @raises -20857 versão de PDF inválida; só 1.4, 1.5, 1.6, 1.7 ou 2.0
 * @raises -20858 AES-128 exige PDF 1.5 ou maior, e AES-256 exige 1.7
 * @example
 *   PL_FPDF.SetPDFVersion('1.5');
 */
PROCEDURE SetPDFVersion(p_version IN VARCHAR2);

/**
 * Obter a configuração atual de versão do PDF
 *
 * @return VARCHAR2 - a versão de PDF corrente (por exemplo '1.4')
 */
FUNCTION GetPDFVersion RETURN VARCHAR2;

/**
 * Definir permissões do documento (requer SetEncryption antes)
 *
 * @param p_print Permitir impressão
 * @param p_modify Permitir modificação
 * @param p_copy Permitir cópia/extração
 * @param p_annotate Permitir anotações
 * @param p_fill_forms Permitir preenchimento de formulários
 * @param p_extract Permitir extração de conteúdo
 * @param p_assemble Permitir montagem de documento
 * @param p_print_high Permitir impressão alta qualidade
 * @raises -20856 SetEncryption tem de ser chamada antes
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
