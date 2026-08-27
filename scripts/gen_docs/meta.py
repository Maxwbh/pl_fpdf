# -*- coding: utf-8 -*-
"""
Metadados curados da API do PL_FPDF.

Complementa o que o parser extrai de src/PL_FPDF.pks (nome, tipos, defaults,
retorno) com o que só um humano descreve: propósito, valores possíveis de cada
parâmetro, erros levantados e exemplo de uso.

Estrutura de cada entrada:
  'nome_da_api_lower': {
     'group':  grupo do índice,
     'desc':   descrição (1-3 frases),
     'params': {'p_nome': ('descrição', 'valores possíveis')},
     'returns': 'o que retorna' (funções),
     'raises': [('-20xxx', 'quando ocorre')],
     'example': 'bloco PL/SQL',
     'see': ['OutraApi', ...],
  }
"""

GROUPS = [
    ('lifecycle',  'Ciclo de vida'),
    ('pages',      'Páginas e posicionamento'),
    ('fonts',      'Fontes e UTF-8'),
    ('text',       'Escrita de texto'),
    ('draw',       'Cores e desenho'),
    ('images',     'Imagens'),
    ('links',      'Links'),
    ('headfoot',   'Cabeçalho e rodapé'),
    ('codes',      'QR Code e código de barras'),
    ('meta',       'Metadados e configuração'),
    ('output',     'Saída do documento'),
    ('manip',      'Manipulação de PDF existente'),
    ('overlay',    'Overlays'),
    ('multi',      'Multi-PDF (merge, split, extract)'),
    ('security',   'Segurança e criptografia'),
    ('diag',       'Diagnóstico e utilidades'),
]

# Valores reutilizados
V_UNIT = "Número na unidade definida em Init (mm, cm, pt ou in)"
V_PAGE = "Inteiro ≥ 1, até GetPageCount"
V_BOOL = "TRUE ou FALSE"

META = {
# ─────────────────────────────── ciclo de vida ───────────────────────────────
'init': dict(group='lifecycle',
  desc="Inicializa um novo documento PDF. Deve ser a primeira chamada de qualquer geração; "
       "define orientação, unidade de medida, formato de página e codificação usados por todas as demais APIs.",
  params={
    'p_orientation': ("Orientação padrão das páginas.", "'P' (retrato, padrão) ou 'L' (paisagem)"),
    'p_unit':        ("Unidade de medida de todas as coordenadas e dimensões do documento.",
                      "'mm' (padrão), 'cm', 'pt' ou 'in'"),
    'p_format':      ("Formato de página padrão.", "'A3', 'A4' (padrão), 'A5', 'Letter' ou 'Legal'"),
    'p_encoding':    ("Codificação de caracteres do texto.", "'UTF-8' (padrão) ou 'WINDOWS-1252'"),
  },
  example="""BEGIN
  PL_FPDF.Init(p_orientation => 'P', p_unit => 'mm', p_format => 'A4');
  PL_FPDF.AddPage();
  -- ...
END;""",
  see=['Reset', 'IsInitialized', 'AddPage']),

'reset': dict(group='lifecycle',
  desc="Reinicia o motor de PDF ao estado inicial, liberando CLOBs temporários e limpando todos os arrays "
       "internos. Use entre documentos gerados no mesmo job ou ao final de rotinas longas.",
  params={}, example="PL_FPDF.Reset;", see=['Init', 'ClearPDFCache']),

'isinitialized': dict(group='lifecycle',
  desc="Indica se há um documento em construção na sessão atual.",
  params={}, returns="BOOLEAN — TRUE se Init já foi chamado e o documento não foi finalizado.",
  example="""IF NOT PL_FPDF.IsInitialized THEN
  PL_FPDF.Init;
END IF;""", see=['Init']),

# ───────────────────────────────── páginas ──────────────────────────────────
'addpage': dict(group='pages',
  desc="Adiciona uma nova página ao documento e a torna a página corrente. Parâmetros nulos herdam os "
       "valores definidos em Init, permitindo misturar orientações e formatos no mesmo PDF.",
  params={
    'p_orientation': ("Orientação apenas desta página.", "'P', 'L' ou NULL (herda de Init)"),
    'p_format':      ("Formato apenas desta página.", "'A3', 'A4', 'A5', 'Letter', 'Legal' ou NULL (herda de Init)"),
    'p_rotation':    ("Rotação de exibição da página no leitor de PDF.", "0 (padrão), 90, 180 ou 270"),
  },
  raises=[('-20105', 'Documento não inicializado (chame Init antes)')],
  example="""PL_FPDF.AddPage;                                      -- herda tudo de Init
PL_FPDF.AddPage(p_orientation => 'L');                -- só esta em paisagem
PL_FPDF.AddPage(p_format => 'A5', p_rotation => 90);  -- A5 rotacionada""",
  see=['Init', 'SetPage', 'GetCurrentPage']),

'setpage': dict(group='pages',
  desc="Define qual página existente recebe o conteúdo das próximas chamadas, permitindo voltar a páginas "
       "anteriores (por exemplo, para preencher um sumário depois de conhecer os números finais).",
  params={'p_page_number': ("Página que passa a ser a corrente.", V_PAGE)},
  raises=[('-20105', 'PDF não inicializado'), ('-20106', 'A página informada não existe')],
  example="""PL_FPDF.SetPage(1);
PL_FPDF.SetXY(20, 40);
PL_FPDF.Cell(0, 8, 'Preenchido depois');""",
  see=['AddPage', 'GetCurrentPage']),

'getcurrentpage': dict(group='pages', desc="Retorna o número da página corrente (a que está recebendo conteúdo).",
  params={}, returns="PLS_INTEGER — número da página ativa.", see=['SetPage', 'PageNo']),

'pageno': dict(group='pages', desc="Retorna o número da página atual durante a geração — usado tipicamente em rodapés.",
  params={}, returns="NUMBER — número da página corrente.",
  example="PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');",
  see=['SetAliasNbPages', 'SetFooterProc']),

'setmargins': dict(group='pages',
  desc="Define as margens esquerda, superior e direita do documento. A margem inferior é controlada por SetAutoPageBreak.",
  params={
    'left':  ("Margem esquerda.", V_UNIT),
    'top':   ("Margem superior.", V_UNIT),
    'right': ("Margem direita.", V_UNIT + "; -1 (padrão) usa o mesmo valor da margem esquerda"),
  },
  example="PL_FPDF.SetMargins(left => 20, top => 15, right => 20);",
  see=['SetLeftMargin', 'SetTopMargin', 'SetRightMargin', 'SetAutoPageBreak']),

'setleftmargin':  dict(group='pages', desc="Define apenas a margem esquerda.",
  params={'pMargin': ("Margem esquerda.", V_UNIT)}, see=['SetMargins']),
'settopmargin':   dict(group='pages', desc="Define apenas a margem superior.",
  params={'pMargin': ("Margem superior.", V_UNIT)}, see=['SetMargins']),
'setrightmargin': dict(group='pages', desc="Define apenas a margem direita.",
  params={'pMargin': ("Margem direita.", V_UNIT)}, see=['SetMargins']),

'setautopagebreak': dict(group='pages',
  desc="Liga ou desliga a quebra automática de página e define a distância da borda inferior em que ela ocorre.",
  params={
    'pauto':   ("Ativa a quebra automática.", V_BOOL),
    'pMargin': ("Margem inferior que dispara a quebra.", V_UNIT + "; 0 é o padrão"),
  },
  example="PL_FPDF.SetAutoPageBreak(pauto => TRUE, pMargin => 15);",
  see=['AcceptPageBreak', 'SetMargins']),

'acceptpagebreak': dict(group='pages',
  desc="Informa se a quebra automática deve ocorrer no ponto atual. Chamada internamente pelo motor; "
       "pode ser consultada para lógicas próprias de paginação.",
  params={}, returns="BOOLEAN — TRUE se a quebra automática está habilitada.", see=['SetAutoPageBreak']),

'ln': dict(group='pages', desc="Move o cursor para a próxima linha, retornando à margem esquerda.",
  params={'h': ("Altura do salto.", V_UNIT + "; NULL (padrão) usa a altura da última célula escrita")},
  example="PL_FPDF.Ln(6);", see=['SetXY']),

'getx': dict(group='pages', desc="Retorna a posição X atual do cursor.", params={}, returns="NUMBER — coordenada X.", see=['SetX', 'SetXY']),
'setx': dict(group='pages', desc="Define a posição X do cursor.",
  params={'px': ("Nova coordenada X.", V_UNIT + "; valores negativos contam a partir da borda direita")}, see=['GetX']),
'gety': dict(group='pages', desc="Retorna a posição Y atual do cursor.", params={}, returns="NUMBER — coordenada Y.", see=['SetY']),
'sety': dict(group='pages', desc="Define a posição Y do cursor (e reposiciona X na margem esquerda).",
  params={'py': ("Nova coordenada Y.", V_UNIT + "; valores negativos contam a partir da borda inferior — ex.: -15 para rodapé")},
  example="PL_FPDF.SetY(-15);  -- 15 unidades acima do fim da página", see=['GetY', 'SetXY']),
'setxy': dict(group='pages', desc="Define X e Y do cursor em uma única chamada.",
  params={'x': ("Coordenada X.", V_UNIT), 'y': ("Coordenada Y.", V_UNIT)},
  example="PL_FPDF.SetXY(x => 20, y => 40);", see=['SetX', 'SetY']),

# ────────────────────────────────── fontes ──────────────────────────────────
'setfont': dict(group='fonts',
  desc="Define a fonte, o estilo e o tamanho usados pelas próximas escritas de texto.",
  params={
    'pfamily': ("Família da fonte.", "'Arial'/'Helvetica', 'Times', 'Courier', 'Symbol', 'ZapfDingbats' "
                "ou o nome de uma fonte TrueType carregada com AddTTFFont/LoadTTFFromFile"),
    'pstyle':  ("Estilo do texto.", "'' (normal), 'B' (negrito), 'I' (itálico), 'BI' (negrito itálico) ou 'U' (sublinhado)"),
    'psize':   ("Tamanho em pontos.", "Número > 0; 0 (padrão) mantém o tamanho atual"),
  },
  example="PL_FPDF.SetFont('Arial', 'B', 16);",
  see=['SetFontSize', 'AddTTFFont', 'GetStringWidth']),

'setfontsize': dict(group='fonts', desc="Altera apenas o tamanho da fonte corrente.",
  params={'psize': ("Tamanho em pontos.", "Número > 0")}, see=['SetFont']),

'addfont': dict(group='fonts',
  desc="Registra uma fonte adicional (compatibilidade FPDF). Para TrueType com UTF-8, prefira AddTTFFont.",
  params={
    'family':   ("Nome da família a registrar.", "Texto livre; usado depois em SetFont"),
    'style':    ("Estilo associado ao arquivo.", "'', 'B', 'I' ou 'BI'"),
    'filename': ("Arquivo de definição da fonte.", "Nome do arquivo; vazio usa a convenção padrão do FPDF"),
  }, see=['AddTTFFont', 'SetFont']),

'addttffont': dict(group='fonts',
  desc="Carrega uma fonte TrueType a partir de um BLOB (por exemplo, de uma tabela de assets) e a "
       "disponibiliza para SetFont, com suporte completo a UTF-8.",
  params={
    'p_font_name': ("Nome pelo qual a fonte será referenciada em SetFont.", "Texto livre, ex.: 'Roboto'"),
    'p_font_blob': ("Conteúdo binário do arquivo .ttf.", "BLOB não nulo com fonte TrueType válida"),
    'p_encoding':  ("Codificação da fonte.", "'UTF-8' (padrão) ou 'WINDOWS-1252'"),
    'p_embed':     ("Embute a fonte no PDF (garante a aparência em qualquer leitor, aumenta o arquivo).", V_BOOL + "; TRUE é o padrão"),
  },
  example="""DECLARE
  l_ttf BLOB;
BEGIN
  SELECT arquivo INTO l_ttf FROM fontes WHERE nome = 'Roboto-Regular';
  PL_FPDF.AddTTFFont(p_font_name => 'Roboto', p_font_blob => l_ttf, p_embed => TRUE);
  PL_FPDF.SetFont('Roboto', '', 12);
END;""",
  see=['LoadTTFFromFile', 'IsTTFFontLoaded', 'SetFont']),

'loadttffromfile': dict(group='fonts',
  desc="Carrega uma fonte TrueType a partir de um arquivo em um DIRECTORY do Oracle.",
  params={
    'p_font_name': ("Nome para uso em SetFont.", "Texto livre"),
    'p_file_path': ("Nome do arquivo .ttf dentro do diretório.", "Ex.: 'Roboto-Regular.ttf'"),
    'p_directory': ("DIRECTORY do Oracle com permissão de leitura.", "Padrão: 'FONTS_DIR'"),
    'p_encoding':  ("Codificação da fonte.", "'UTF-8' (padrão) ou 'WINDOWS-1252'"),
  },
  example="PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');",
  see=['AddTTFFont']),

'isttffontloaded': dict(group='fonts', desc="Verifica se uma fonte TrueType já foi carregada na sessão.",
  params={'p_font_name': ("Nome da fonte.", "O mesmo usado no carregamento")},
  returns="BOOLEAN — TRUE se a fonte está no cache.", see=['AddTTFFont', 'ClearTTFFontCache']),

'getttffontinfo': dict(group='fonts', desc="Retorna os metadados de uma fonte TrueType carregada.",
  params={'p_font_name': ("Nome da fonte.", "O mesmo usado no carregamento")},
  returns="recTTFFont — record com métricas e informações da fonte.", see=['AddTTFFont']),

'clearttffontcache': dict(group='fonts', desc="Descarta todas as fontes TrueType carregadas, liberando memória da sessão.",
  params={}, see=['AddTTFFont']),

'setutf8enabled': dict(group='fonts', desc="Liga ou desliga o tratamento UTF-8 do texto.",
  params={'p_enabled': ("Ativa UTF-8.", V_BOOL + "; TRUE é o padrão")}, see=['IsUTF8Enabled', 'UTF8ToPDFString']),
'isutf8enabled': dict(group='fonts', desc="Indica se o modo UTF-8 está ativo.", params={},
  returns="BOOLEAN — TRUE se UTF-8 está habilitado.", see=['SetUTF8Enabled']),
'utf8topdfstring': dict(group='fonts', desc="Converte um texto UTF-8 para a representação interna do PDF. "
  "Chamada internamente; útil para depuração de acentuação.",
  params={
    'p_text':   ("Texto a converter.", "Qualquer VARCHAR2 em UTF-8"),
    'p_escape': ("Aplica escape dos caracteres especiais do PDF (parênteses e barra invertida).", "TRUE ou FALSE"),
  },
  returns="VARCHAR2 — texto convertido.", see=['SetUTF8Enabled']),

# ─────────────────────────────────── texto ──────────────────────────────────
'cell': dict(group='text',
  desc="Escreve um bloco retangular de texto, com bordas, alinhamento, preenchimento e link opcionais. "
       "É a API mais usada para montar relatórios e tabelas.",
  params={
    'pw':      ("Largura da célula.", V_UNIT + "; 0 estende até a margem direita"),
    'ph':      ("Altura da célula.", V_UNIT + "; 0 é o padrão"),
    'ptxt':    ("Texto a escrever.", "Qualquer VARCHAR2; vazio desenha apenas a célula"),
    'pborder': ("Bordas desenhadas.", "'0' (nenhuma), '1' (moldura completa) ou combinação de 'L', 'T', 'R', 'B' — ex.: 'LTB'"),
    'pln':     ("Para onde o cursor vai depois.", "0 = à direita da célula (padrão), 1 = início da próxima linha, 2 = abaixo da célula"),
    'palign':  ("Alinhamento do texto.", "'L' (esquerda), 'C' (centro), 'R' (direita) ou '' (padrão, esquerda)"),
    'pfill':   ("Preenche o fundo com a cor de SetFillColor.", "0 = transparente (padrão), 1 = preenchido"),
    'plink':   ("Torna a célula clicável.", "URL ('https://…') ou identificador retornado por AddLink"),
  },
  example="""PL_FPDF.SetFillColor(240, 240, 240);
PL_FPDF.Cell(
  pw      => 0,
  ph      => 10,
  ptxt    => 'Total: R$ 1.234,56',
  pborder => 'LTB',
  pln     => 1,
  palign  => 'R',
  pfill   => 1);""",
  see=['MultiCell', 'Write', 'CellRotated', 'SetFillColor']),

'multicell': dict(group='text',
  desc="Escreve um parágrafo com quebra automática de linha dentro de uma largura definida. "
       "Existe como function (retorna o número de linhas) e como procedure.",
  params={
    'pw':      ("Largura do bloco.", V_UNIT + "; 0 estende até a margem direita"),
    'ph':      ("Altura de cada linha.", V_UNIT),
    'ptxt':    ("Texto do parágrafo (aceita quebras de linha).", "Qualquer VARCHAR2"),
    'pborder': ("Bordas do bloco.", "'0', '1' ou combinação de 'L', 'T', 'R', 'B'"),
    'palign':  ("Alinhamento.", "'J' (justificado, padrão), 'L', 'C' ou 'R'"),
    'pfill':   ("Preenche o fundo.", "0 (padrão) ou 1"),
    'phMax':   ("Altura máxima do bloco; o texto é truncado se exceder.", "Número; 0 (padrão) = sem limite"),
    'pwidth':     ("Largura do bloco (versão procedure).", V_UNIT + "; 0 até a margem direita"),
    'pheight':    ("Altura de cada linha (versão procedure).", V_UNIT),
    'ptext':      ("Texto do parágrafo (versão procedure).", "Qualquer VARCHAR2"),
    'pbrdr':      ("Bordas (versão procedure).", "'0', '1' ou 'LTRB'"),
    'palignment': ("Alinhamento (versão procedure).", "'J', 'L', 'C' ou 'R'"),
    'pfillin':    ("Preenchimento (versão procedure).", "0 ou 1"),
    'phMaximum':  ("Altura máxima (versão procedure).", "Número; 0 = sem limite"),
  },
  returns="NUMBER (versão function) — quantidade de linhas geradas.",
  example="""l_linhas := PL_FPDF.MultiCell(
  pw      => 0,
  ph      => 6,
  ptxt    => l_descricao,
  pborder => '1',
  palign  => 'J');""",
  see=['Cell', 'Write']),

'write': dict(group='text',
  desc="Escreve texto de forma fluida, continuando de onde o anterior parou e quebrando linha "
       "automaticamente — permite alternar fontes e estilos no meio de uma frase.",
  params={
    'pH':   ("Altura da linha.", V_UNIT),
    'ptxt': ("Texto a escrever.", "Qualquer VARCHAR2"),
    'plink':("Link opcional aplicado ao texto.", "URL ou identificador de AddLink; NULL (padrão) = sem link"),
  },
  example="""PL_FPDF.Write(6, 'Documento gerado por ');
PL_FPDF.SetFont('Arial', 'B');
PL_FPDF.Write(6, 'PL_FPDF', 'https://maxwbh.github.io/pl_fpdf/');""",
  see=['Cell', 'MultiCell', 'WriteRotated']),

'text': dict(group='text',
  desc="Escreve texto em coordenadas absolutas, sem alterar a posição do cursor nem quebrar linha.",
  params={
    'px':   ("Coordenada X do início do texto.", V_UNIT),
    'py':   ("Coordenada Y da linha de base.", V_UNIT),
    'ptxt': ("Texto a escrever.", "Qualquer VARCHAR2"),
  }, see=['Cell', 'Write']),

'cellrotated': dict(group='text',
  desc="Versão de Cell com rotação do texto — útil para cabeçalhos verticais de tabelas e etiquetas.",
  params={
    'p_width':   ("Largura da célula.", V_UNIT + "; 0 estende até a margem direita"),
    'p_height':  ("Altura da célula.", V_UNIT),
    'p_text':    ("Texto a escrever.", "Qualquer VARCHAR2"),
    'p_border':  ("Bordas.", "'0', '1' ou combinação de 'L', 'T', 'R', 'B'"),
    'p_ln':      ("Posição do cursor depois.", "0 = à direita, 1 = próxima linha, 2 = abaixo"),
    'p_align':   ("Alinhamento.", "'L', 'C' ou 'R'"),
    'p_fill':    ("Preenchimento.", "0 ou 1"),
    'p_link':    ("Link opcional.", "URL ou identificador de AddLink"),
    'p_rotation':("Ângulo de rotação do texto.", "0 (padrão), 90, 180 ou 270 — outros valores geram erro"),
  },
  raises=[('-20110', 'Valor de rotação inválido (use 0, 90, 180 ou 270)')],
  example="PL_FPDF.CellRotated(40, 10, 'VERTICAL', p_rotation => 90);",
  see=['Cell', 'WriteRotated']),

'writerotated': dict(group='text',
  desc="Versão de Write com rotação do texto.",
  params={
    'p_height':  ("Altura da linha.", V_UNIT),
    'p_text':    ("Texto a escrever.", "Qualquer VARCHAR2"),
    'p_link':    ("Link opcional.", "URL ou identificador de AddLink; NULL = sem link"),
    'p_rotation':("Ângulo de rotação.", "0 (padrão), 90, 180 ou 270"),
  },
  raises=[('-20110', 'Valor de rotação inválido')], see=['Write', 'CellRotated']),

'getstringwidth': dict(group='text',
  desc="Calcula a largura que um texto ocupará na fonte e no tamanho correntes — use para centralizar "
       "manualmente, dimensionar colunas ou decidir quebras.",
  params={'pstr': ("Texto a medir.", "Qualquer VARCHAR2")},
  returns="NUMBER — largura na unidade do documento.",
  example="""l_w := PL_FPDF.GetStringWidth(l_titulo);
PL_FPDF.SetX((210 - l_w) / 2);   -- centraliza em A4 retrato (210 mm)""",
  see=['SetFont', 'Cell']),

'setlinespacing': dict(group='text', desc="Define o espaçamento entre linhas usado por Write e MultiCell.",
  params={'pls': ("Fator/altura de espaçamento.", "Número > 0")}, see=['GetLineSpacing']),
'getlinespacing': dict(group='text', desc="Retorna o espaçamento de linhas atual.", params={},
  returns="NUMBER — espaçamento configurado.", see=['SetLineSpacing']),
'getcurrentfontsize':   dict(group='text', desc="Retorna o tamanho da fonte corrente.", params={}, returns="NUMBER — tamanho em pontos.", see=['SetFont']),
'getcurrentfontstyle':  dict(group='text', desc="Retorna o estilo da fonte corrente.", params={}, returns="VARCHAR2 — '', 'B', 'I', 'BI' ou 'U'.", see=['SetFont']),
'getcurrentfontfamily': dict(group='text', desc="Retorna a família da fonte corrente.", params={}, returns="VARCHAR2 — nome da família.", see=['SetFont']),

# ─────────────────────────────── cores e desenho ────────────────────────────
'setdrawcolor': dict(group='draw',
  desc="Define a cor das linhas e contornos desenhados a seguir.",
  params={
    'r': ("Componente vermelho ou tom de cinza quando g e b são omitidos.", "0 a 255"),
    'g': ("Componente verde.", "0 a 255; -1 (padrão) indica escala de cinza usando r"),
    'b': ("Componente azul.", "0 a 255; -1 (padrão) indica escala de cinza usando r"),
  },
  example="""PL_FPDF.SetDrawColor(200, 0, 0);   -- vermelho
PL_FPDF.SetDrawColor(128);         -- cinza médio""",
  see=['SetFillColor', 'SetTextColor', 'SetLineWidth']),

'setfillcolor': dict(group='draw', desc="Define a cor de preenchimento de células (pfill = 1), retângulos e formas.",
  params={
    'r': ("Componente vermelho ou tom de cinza.", "0 a 255"),
    'g': ("Componente verde.", "0 a 255; -1 = escala de cinza"),
    'b': ("Componente azul.", "0 a 255; -1 = escala de cinza"),
  },
  example="PL_FPDF.SetFillColor(240, 240, 240);", see=['Cell', 'Rect']),

'settextcolor': dict(group='draw', desc="Define a cor do texto escrito a seguir.",
  params={
    'r': ("Componente vermelho ou tom de cinza.", "0 a 255"),
    'g': ("Componente verde.", "0 a 255; -1 = escala de cinza"),
    'b': ("Componente azul.", "0 a 255; -1 = escala de cinza"),
  }, see=['SetFont', 'Cell']),

'setlinewidth': dict(group='draw', desc="Define a espessura das linhas desenhadas a seguir.",
  params={'width': ("Espessura da linha.", V_UNIT + "; padrão do PDF ≈ 0.2 mm")}, see=['Line', 'Rect']),

'line': dict(group='draw', desc="Desenha uma linha reta entre dois pontos.",
  params={
    'x1': ("X do ponto inicial.", V_UNIT), 'y1': ("Y do ponto inicial.", V_UNIT),
    'x2': ("X do ponto final.", V_UNIT),   'y2': ("Y do ponto final.", V_UNIT),
  },
  example="PL_FPDF.Line(10, 30, 200, 30);", see=['SetDrawColor', 'SetLineWidth']),

'rect': dict(group='draw', desc="Desenha um retângulo com contorno, preenchimento ou ambos.",
  params={
    'px': ("X do canto superior esquerdo.", V_UNIT),
    'py': ("Y do canto superior esquerdo.", V_UNIT),
    'pw': ("Largura.", V_UNIT), 'ph': ("Altura.", V_UNIT),
    'pstyle': ("Estilo de renderização.", "'' ou 'D' (apenas contorno, padrão), 'F' (apenas preenchimento), 'DF'/'FD' (contorno + preenchimento)"),
  },
  example="PL_FPDF.Rect(px => 10, py => 40, pw => 60, ph => 25, pstyle => 'DF');",
  see=['SetDrawColor', 'SetFillColor']),

'triangle': dict(group='draw', desc="Desenha um triângulo equilátero a partir do centro e do tamanho informados.",
  params={
    'px': ("X do centro.", V_UNIT), 'py': ("Y do centro.", V_UNIT),
    'psize': ("Tamanho do triângulo.", V_UNIT),
    'porientation': ("Direção para onde a ponta aponta.", "'U' (cima), 'D' (baixo), 'L' (esquerda) ou 'R' (direita)"),
    'pstyle': ("Estilo de renderização.", "'' ou 'D' (contorno), 'F' (preenchido), 'DF' (ambos)"),
  }, see=['Poly', 'Rect']),

'poly': dict(group='draw', desc="Desenha um polígono a partir de uma coleção de pontos.",
  params={
    'points': ("Pontos do polígono.", "Coleção tab_points com pares X/Y na unidade do documento"),
    'pclose': ("Fecha o polígono ligando o último ponto ao primeiro.", V_BOOL),
    'pstyle': ("Estilo de renderização.", "'' ou 'D' (contorno), 'F' (preenchido), 'DF' (ambos)"),
  }, see=['Line', 'Triangle']),

'setdash': dict(group='draw', desc="Define um padrão de linha tracejada simples.",
  params={
    'pblack': ("Comprimento do traço.", V_UNIT + "; 0 (padrão) volta para linha contínua"),
    'pwhite': ("Comprimento do espaço.", V_UNIT + "; 0 (padrão) volta para linha contínua"),
  },
  example="""PL_FPDF.SetDash(2, 2);   -- tracejado
PL_FPDF.SetDash(0, 0);   -- volta ao contínuo""",
  see=['SetLineDashPattern']),

'setlinedashpattern': dict(group='draw',
  desc="Define o padrão de tracejado usando a sintaxe nativa do PDF, para controle fino.",
  params={'pdash': ("Padrão no formato PDF.", "'[] 0' (contínuo, padrão), '[3 2] 0' (3 on, 2 off), '[1 2 3 2] 0' etc.")},
  see=['SetDash']),

# ────────────────────────────────── imagens ─────────────────────────────────
'image': dict(group='images',
  desc="Insere uma imagem PNG ou JPEG na página corrente, com dimensionamento proporcional opcional.",
  params={
    'pFile':   ("Origem da imagem.", "Nome de arquivo em DIRECTORY do Oracle ou identificador retornado por getImageFromUrl"),
    'pX':      ("X do canto superior esquerdo.", V_UNIT),
    'pY':      ("Y do canto superior esquerdo.", V_UNIT),
    'pWidth':  ("Largura desejada.", V_UNIT + "; 0 (padrão) calcula a partir da altura"),
    'pHeight': ("Altura desejada.", V_UNIT + "; 0 (padrão) calcula a partir da largura, mantendo a proporção"),
    'pType':   ("Formato da imagem.", "'PNG', 'JPG'/'JPEG' ou NULL (padrão) para autodetecção"),
    'pLink':   ("Torna a imagem clicável.", "URL ou identificador de AddLink; NULL = sem link"),
  },
  example="""PL_FPDF.Image(
  pFile   => 'logo.png',
  pX      => 10, pY => 10,
  pWidth  => 40,
  pHeight => 0,                     -- proporcional à largura
  pLink   => 'https://msbrasil.inf.br');""",
  see=['getImageFromUrl', 'OverlayImage']),

'getimagefromurl': dict(group='images',
  desc="Baixa uma imagem de uma URL via UTL_HTTP para uso no documento. Requer ACL de rede configurada no banco.",
  params={'p_Url': ("Endereço da imagem.", "URL http:// ou https:// acessível a partir do banco")},
  returns="recImageBlob — record com o conteúdo e os metadados da imagem.",
  see=['Image']),

# ─────────────────────────────────── links ──────────────────────────────────
'addlink': dict(group='links',
  desc="Cria um link interno (ainda sem destino) e retorna seu identificador, usado depois em SetLink e nas APIs de texto.",
  params={}, returns="NUMBER — identificador do link.",
  example="""l_link := PL_FPDF.AddLink;
PL_FPDF.SetLink(l_link, 0, 3);
PL_FPDF.Cell(60, 8, 'Ir ao capítulo 3', plink => l_link);""",
  see=['SetLink', 'Link']),

'setlink': dict(group='links', desc="Define o destino de um link interno criado por AddLink.",
  params={
    'plink': ("Identificador do link.", "Valor retornado por AddLink"),
    'py':    ("Posição vertical de destino na página.", V_UNIT + "; 0 (padrão) = topo da página"),
    'ppage': ("Página de destino.", "Número da página; -1 (padrão) = página corrente"),
  }, see=['AddLink']),

'link': dict(group='links', desc="Cria uma área retangular clicável em qualquer região da página.",
  params={
    'px': ("X do canto superior esquerdo.", V_UNIT), 'py': ("Y do canto superior esquerdo.", V_UNIT),
    'pw': ("Largura da área.", V_UNIT), 'ph': ("Altura da área.", V_UNIT),
    'plink': ("Destino.", "URL ('https://…') ou identificador de AddLink"),
  }, see=['AddLink', 'SetLink']),

# ────────────────────────────── cabeçalho e rodapé ──────────────────────────
'setheaderproc': dict(group='headfoot',
  desc="Registra uma procedure sua para ser executada automaticamente no início de cada página.",
  params={
    'headerprocname': ("Nome qualificado da procedure.", "'pacote.procedure' ou 'procedure'; deve ser acessível ao usuário do banco"),
    'paramTable':     ("Parâmetros repassados à procedure.", "Coleção tv4000a com até os valores esperados pela sua procedure; noParam (padrão) = sem parâmetros"),
  },
  example="PL_FPDF.SetHeaderProc('meu_pkg.cabecalho', tv4000a('Relatório Mensal', 'Ago/2026'));",
  see=['SetFooterProc', 'Header']),

'setfooterproc': dict(group='headfoot',
  desc="Registra uma procedure sua para ser executada automaticamente no rodapé de cada página.",
  params={
    'footerprocname': ("Nome qualificado da procedure.", "'pacote.procedure' ou 'procedure'"),
    'paramTable':     ("Parâmetros repassados à procedure.", "Coleção tv4000a; noParam (padrão) = sem parâmetros"),
  },
  example="""-- procedure sua:
--   PL_FPDF.SetY(-15);
--   PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
PL_FPDF.SetFooterProc('meu_pkg.rodape');
PL_FPDF.SetAliasNbPages;""",
  see=['SetHeaderProc', 'SetAliasNbPages', 'Footer']),

'header': dict(group='headfoot', desc="Ponto de extensão do cabeçalho, chamado internamente a cada nova página.", params={}, see=['SetHeaderProc']),
'footer': dict(group='headfoot', desc="Ponto de extensão do rodapé, chamado internamente ao fechar cada página.", params={}, see=['SetFooterProc']),

'setaliasnbpages': dict(group='headfoot',
  desc="Define o marcador que será substituído pelo total de páginas ao finalizar o documento — "
       "permite escrever 'Página 2 de 10' sem saber o total antecipadamente.",
  params={'palias': ("Marcador a substituir.", "Qualquer texto; '{nb}' é o padrão")},
  example="""PL_FPDF.SetAliasNbPages;   -- habilita '{nb}'
PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || ' de {nb}', 0, 0, 'C');""",
  see=['PageNo']),

# ───────────────────────────── QR Code e barras ─────────────────────────────
'addqrcode': dict(group='codes',
  desc="Desenha um QR Code na página corrente, com formato de conteúdo e nível de correção de erros configuráveis.",
  params={
    'p_x':    ("X do canto superior esquerdo.", V_UNIT),
    'p_y':    ("Y do canto superior esquerdo.", V_UNIT),
    'p_size': ("Lado do QR Code (largura = altura).", V_UNIT),
    'p_data': ("Conteúdo a codificar.", "Até 2953 bytes em modo binário; o conteúdo deve seguir o formato escolhido em p_format"),
    'p_format': ("Formato do conteúdo, que define como leitores interpretam o código.",
                 "'TEXT' (padrão, texto livre), 'URL', 'PIX', 'VCARD', 'WIFI' ou 'EMAIL'"),
    'p_error_correction': ("Nível de correção de erros: quanto maior, mais o código resiste a sujeira e dobras, "
                           "porém menos dados cabem.", "'L' (7%), 'M' (15%, padrão), 'Q' (25%) ou 'H' (30%)"),
  },
  example="""PL_FPDF.AddQRCode(
  p_x => 150, p_y => 20, p_size => 40,
  p_data             => 'https://msbrasil.inf.br',
  p_format           => 'URL',
  p_error_correction => 'M');""",
  see=['AddBarcode']),

'addbarcode': dict(group='codes',
  desc="Desenha um código de barras linear na página corrente, com texto legível opcional.",
  params={
    'p_x': ("X do canto superior esquerdo.", V_UNIT),
    'p_y': ("Y do canto superior esquerdo.", V_UNIT),
    'p_width':  ("Largura total do código.", V_UNIT),
    'p_height': ("Altura das barras.", V_UNIT),
    'p_code':   ("Dado a codificar.", "Deve respeitar o padrão escolhido: EAN13 = 13 dígitos, EAN8 = 8 dígitos, "
                 "ITF14 = 14 dígitos, CODE39 = alfanumérico maiúsculo, CODE128 = ASCII"),
    'p_type':   ("Simbologia do código de barras.", "'CODE128' (padrão), 'CODE39', 'EAN13', 'EAN8' ou 'ITF14'"),
    'p_show_text': ("Imprime o valor legível abaixo das barras.", V_BOOL + "; TRUE é o padrão"),
  },
  example="""PL_FPDF.AddBarcode(
  p_x => 30, p_y => 70, p_width => 150, p_height => 20,
  p_code      => '7891234567895',
  p_type      => 'EAN13',
  p_show_text => TRUE);""",
  see=['AddQRCode']),

# ──────────────────────────────── metadados ─────────────────────────────────
'settitle':    dict(group='meta', desc="Define o título do documento (exibido na barra do leitor de PDF).",
  params={'ptitle': ("Título.", "Qualquer VARCHAR2")}, see=['SetDocumentConfig']),
'setsubject':  dict(group='meta', desc="Define o assunto do documento nos metadados.",
  params={'psubject': ("Assunto.", "Qualquer VARCHAR2")}, see=['SetDocumentConfig']),
'setauthor':   dict(group='meta', desc="Define o autor do documento nos metadados.",
  params={'pauthor': ("Autor.", "Qualquer VARCHAR2")}, see=['SetDocumentConfig']),
'setkeywords': dict(group='meta', desc="Define as palavras-chave do documento (auxiliam buscas e indexação).",
  params={'pkeywords': ("Palavras-chave.", "Texto livre, normalmente separado por vírgulas")}, see=['SetDocumentConfig']),
'setcreator':  dict(group='meta', desc="Define o aplicativo criador do documento nos metadados.",
  params={'pcreator': ("Nome do sistema gerador.", "Qualquer VARCHAR2")}, see=['SetDocumentConfig']),

'setdisplaymode': dict(group='meta',
  desc="Define como o leitor de PDF deve exibir o documento ao abri-lo.",
  params={
    'zoom':   ("Nível de zoom inicial.", "'fullpage' (página inteira), 'fullwidth' (largura da página), "
               "'real' (100%), 'default' ou um número representando a porcentagem"),
    'layout': ("Disposição das páginas.", "'continuous' (padrão), 'single', 'two' ou 'default'"),
  },
  example="PL_FPDF.SetDisplayMode(zoom => 'fullpage', layout => 'single');"),

'setcompression': dict(group='meta', desc="Liga ou desliga a compressão do conteúdo do PDF (arquivos menores).",
  params={'p_compress': ("Ativa a compressão.", V_BOOL + "; FALSE é o padrão")}),

'setdocumentconfig': dict(group='meta',
  desc="Define vários metadados e opções do documento de uma só vez, a partir de um objeto JSON.",
  params={'p_config': ("Configuração do documento.",
    "JSON_OBJECT_T com as chaves opcionais: title, subject, author, keywords, creator, compression (boolean)")},
  example="""PL_FPDF.SetDocumentConfig(
  JSON_OBJECT_T('{"title":"Relatório Mensal","author":"M&S do Brasil","compression":true}'));""",
  see=['GetDocumentMetadata', 'SetTitle']),

'getdocumentmetadata': dict(group='meta', desc="Retorna os metadados atualmente definidos no documento.",
  params={}, returns="JSON_OBJECT_T — objeto com title, subject, author, keywords, creator e demais opções.",
  see=['SetDocumentConfig']),

'getpageinfo': dict(group='meta', desc="Retorna as informações de uma página do documento em construção.",
  params={'p_page_number': ("Página consultada.", V_PAGE + "; NULL (padrão) = página corrente")},
  returns="JSON_OBJECT_T — largura, altura, orientação e rotação da página.",
  see=['GetCurrentPage', 'GetPDFInfo']),

'setloglevel': dict(group='diag', desc="Define o nível de detalhamento das mensagens de log do package.",
  params={'p_level': ("Nível de log.", "0 (desligado), 1 (erro), 2 (aviso), 3 (info) ou 4 (debug)")},
  see=['GetLogLevel', 'DebugEnabled']),
'getloglevel': dict(group='diag', desc="Retorna o nível de log configurado.", params={},
  returns="PLS_INTEGER — nível atual (0 a 4).", see=['SetLogLevel']),

# ─────────────────────────────────── saída ──────────────────────────────────
'output_blob': dict(group='output',
  desc="Finaliza o documento e devolve o PDF como BLOB — forma recomendada de obter o resultado para "
       "gravar em tabela, enviar por e-mail ou servir via APEX/ORDS.",
  params={}, returns="BLOB — conteúdo completo do PDF.",
  example="""DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init; PL_FPDF.AddPage;
  PL_FPDF.Cell(0, 10, 'Olá!');
  l_pdf := PL_FPDF.OutputBlob();
  INSERT INTO documentos (pdf) VALUES (l_pdf);
END;""",
  see=['OutputFile', 'OutputModifiedPDF']),

'outputblob': dict(group='output', desc="Sinônimo de OutputBlob: finaliza o documento e retorna o PDF como BLOB.",
  params={}, returns="BLOB — conteúdo do PDF.", see=['OutputBlob']),

'outputfile': dict(group='output',
  desc="Finaliza o documento e grava o PDF diretamente em um arquivo no servidor de banco de dados.",
  params={
    'p_filename':  ("Nome do arquivo de saída.", "Ex.: 'relatorio.pdf'"),
    'p_directory': ("DIRECTORY do Oracle com permissão de escrita.", "Padrão: 'PDF_DIR'"),
  },
  example="PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');", see=['OutputBlob']),

'returnblob': dict(group='output', desc="Retorna o PDF como BLOB (compatibilidade com código legado). Prefira OutputBlob.",
  params={
    'pname': ("Nome lógico do documento.", "Qualquer VARCHAR2; NULL = sem nome"),
    'pdest': ("Destino no estilo FPDF.", "'S' (string/BLOB), 'D' (download), 'I' (inline), 'F' (arquivo)"),
  }, returns="BLOB — conteúdo do PDF.", see=['OutputBlob']),

'output': dict(group='output', desc="Saída no estilo FPDF clássico (compatibilidade). Prefira OutputBlob ou OutputFile.",
  params={
    'pname': ("Nome do arquivo/documento.", "Qualquer VARCHAR2"),
    'pdest': ("Destino.", "'S', 'D', 'I' ou 'F'"),
  }, see=['OutputBlob', 'OutputFile']),

'openpdf':  dict(group='output', desc="Abre explicitamente a estrutura do documento (uso avançado; Init já faz isso).", params={}, see=['Init']),
'closepdf': dict(group='output', desc="Fecha a estrutura do documento (uso avançado; as APIs de saída já fazem isso).", params={}, see=['OutputBlob']),

# ─────────────────────── manipulação de PDF existente ───────────────────────
'loadpdf': dict(group='manip',
  desc="Carrega um PDF existente na memória da sessão para leitura e modificação. É o ponto de partida "
       "de todo o fluxo de manipulação, encerrado por OutputModifiedPDF.",
  params={'p_pdf_blob': ("Documento PDF a carregar.", "BLOB não nulo, com cabeçalho %PDF válido")},
  raises=[('-20800', 'PDF inválido (NULL ou muito pequeno)'), ('-20801', 'Cabeçalho PDF inválido'),
          ('-20802', 'startxref não encontrado'), ('-20803', 'Tabela xref inválida'),
          ('-20804', 'Objeto Root não encontrado no trailer')],
  example="""DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_content INTO l_pdf FROM documentos WHERE id = 123;
  PL_FPDF.LoadPDF(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Páginas: ' || PL_FPDF.GetPageCount());
END;""",
  see=['LoadPDFWithID', 'GetPageCount', 'OutputModifiedPDF', 'ClearPDFCache']),

'getpagecount': dict(group='manip', desc="Retorna o total de páginas do PDF carregado (incluindo as marcadas para remoção).",
  params={}, returns="PLS_INTEGER — número de páginas.",
  raises=[('-20809', 'Nenhum PDF carregado')], see=['LoadPDF', 'GetActivePageCount']),

'getpdfinfo': dict(group='manip', desc="Retorna informações do PDF carregado: versão, metadados e contagem de páginas.",
  params={}, returns="JSON_OBJECT_T — versão do PDF, título, autor, número de páginas e demais metadados.",
  raises=[('-20809', 'Nenhum PDF carregado')], see=['LoadPDF', 'GetPageInfo']),

'rotatepage': dict(group='manip', desc="Rotaciona uma página do PDF carregado.",
  params={
    'p_page_number': ("Página a rotacionar.", V_PAGE),
    'p_rotation':    ("Ângulo de rotação aplicado.", "0, 90, 180 ou 270"),
  },
  raises=[('-20809', 'Nenhum PDF carregado'), ('-20810', 'Número de página inválido')],
  example="PL_FPDF.RotatePage(p_page_number => 1, p_rotation => 90);",
  see=['LoadPDF', 'RemovePage', 'OutputModifiedPDF']),

'removepage': dict(group='manip',
  desc="Marca uma página do PDF carregado para remoção. A exclusão é lógica: só é aplicada em OutputModifiedPDF.",
  params={'p_page_number': ("Página a remover.", V_PAGE)},
  raises=[('-20809', 'Nenhum PDF carregado'), ('-20810', 'Número de página inválido')],
  see=['IsPageRemoved', 'GetActivePageCount', 'OutputModifiedPDF']),

'getactivepagecount': dict(group='manip', desc="Retorna quantas páginas restarão após as remoções pendentes.",
  params={}, returns="PLS_INTEGER — páginas não marcadas para remoção.", see=['RemovePage', 'GetPageCount']),

'ispageremoved': dict(group='manip', desc="Indica se uma página está marcada para remoção.",
  params={'p_page_number': ("Página consultada.", V_PAGE)},
  returns="BOOLEAN — TRUE se a página será removida na saída.", see=['RemovePage']),

'ispdfmodified': dict(group='manip', desc="Indica se há alterações pendentes (rotação, remoção, marca d'água, overlay) no PDF carregado.",
  params={}, returns="BOOLEAN — TRUE se existem modificações não aplicadas.", see=['OutputModifiedPDF']),

'addwatermark': dict(group='manip',
  desc="Aplica uma marca d'água de texto sobre as páginas do PDF carregado, com opacidade, rotação e "
       "abrangência configuráveis.",
  params={
    'p_text':     ("Texto da marca d'água.", "Qualquer VARCHAR2, ex.: 'CONFIDENCIAL'"),
    'p_opacity':  ("Opacidade da marca.", "0.0 (invisível) a 1.0 (opaca); 0.3 é o padrão"),
    'p_rotation': ("Ângulo do texto em graus.", "0 a 360; 45 (diagonal) é o padrão"),
    'p_pages':    ("Páginas que recebem a marca.", "'ALL' (padrão) ou lista/intervalos como '1', '1,3,5', '2-8', '1,3-5,10'"),
    'p_font':     ("Fonte usada.", "'Helvetica' (padrão), 'Arial', 'Times' ou 'Courier'"),
    'p_size':     ("Tamanho da fonte em pontos.", "Número > 0; 48 é o padrão"),
    'p_color':    ("Cor da marca d'água.", "'gray' (padrão), 'red', 'blue', 'green', 'black' ou hexadecimal RGB como 'FF0000'"),
  },
  raises=[('-20809', 'Nenhum PDF carregado')],
  example="""PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.AddWatermark(
  p_text     => 'CONFIDENCIAL',
  p_opacity  => 0.3,
  p_rotation => 45,
  p_pages    => 'ALL',
  p_size     => 48,
  p_color    => 'gray');
l_pdf := PL_FPDF.OutputModifiedPDF();""",
  see=['GetWatermarks', 'OverlayText', 'OutputModifiedPDF']),

'getwatermarks': dict(group='manip', desc="Lista todas as marcas d'água aplicadas ao PDF carregado.",
  params={}, returns="JSON_ARRAY_T — objetos com id, text, opacity, rotation, pageRange, font, fontSize e color.",
  raises=[('-20809', 'Nenhum PDF carregado')], see=['AddWatermark']),

'outputmodifiedpdf': dict(group='manip',
  desc="Aplica todas as modificações pendentes (rotações, remoções, marcas d'água e overlays) e retorna o PDF resultante.",
  params={}, returns="BLOB — PDF modificado.",
  raises=[('-20809', 'Nenhum PDF carregado')],
  example="l_pdf := PL_FPDF.OutputModifiedPDF();",
  see=['LoadPDF', 'ClearPDFCache']),

'clearpdfcache': dict(group='manip', desc="Descarta os PDFs carregados e libera a memória usada pela manipulação.",
  params={}, see=['LoadPDF', 'UnloadPDF']),

# ────────────────────────────────── overlays ────────────────────────────────
'overlaytext': dict(group='overlay',
  desc="Sobrepõe texto em uma posição exata de uma página do PDF carregado — carimbos, protocolos e "
       "assinaturas. As coordenadas são em pontos PDF, com Y crescendo de baixo para cima.",
  params={
    'p_page_number': ("Página que recebe o texto.", V_PAGE),
    'p_text':        ("Texto sobreposto.", "Qualquer VARCHAR2"),
    'p_x':           ("Posição X em pontos PDF (1 pt = 1/72 pol), a partir da esquerda.", "0 a 612 em A4 retrato"),
    'p_y':           ("Posição Y em pontos PDF, a partir da base da página.", "0 a 792 em A4 retrato"),
    'p_options':     ("Configurações visuais do texto.",
      "JSON_OBJECT_T com as chaves opcionais: font ('Helvetica', 'Arial', 'Times', 'Courier'), "
      "fontSize (número, 12), color (hexadecimal RGB, '000000'), opacity (0.0–1.0), "
      "rotation (0–360), align ('left', 'center', 'right'), width (número para quebra automática), "
      "bold (true/false), zOrder (inteiro; maior fica por cima)"),
  },
  raises=[('-20809', 'Nenhum PDF carregado'), ('-20810', 'Número de página inválido'),
          ('-20821', 'Coordenadas de posição inválidas')],
  example="""PL_FPDF.OverlayText(
  p_page_number => 1,
  p_text        => 'APROVADO',
  p_x => 400, p_y => 700,
  p_options => JSON_OBJECT_T('{"fontSize":24,"color":"FF0000","opacity":0.8,"bold":true}'));""",
  see=['OverlayImage', 'GetOverlays', 'AddWatermark']),

'overlayimage': dict(group='overlay',
  desc="Sobrepõe uma imagem em posição exata de uma página do PDF carregado — logotipos, assinaturas "
       "digitalizadas e selos.",
  params={
    'p_page_number': ("Página que recebe a imagem.", V_PAGE),
    'p_image_blob':  ("Conteúdo da imagem.", "BLOB em formato JPEG ou PNG"),
    'p_x':           ("Posição X em pontos PDF.", "0 a 612 em A4 retrato"),
    'p_y':           ("Posição Y em pontos PDF (da base).", "0 a 792 em A4 retrato"),
    'p_width':       ("Largura em pontos.", "Número > 0; NULL (padrão) usa a largura original"),
    'p_height':      ("Altura em pontos.", "Número > 0; NULL (padrão) usa a altura original ou mantém a proporção"),
    'p_options':     ("Configurações da imagem.",
      "JSON_OBJECT_T com as chaves opcionais: opacity (0.0–1.0), rotation (0–360), "
      "maintainAspect (true/false), scaleToFit (true/false), zOrder (inteiro)"),
  },
  raises=[('-20809', 'Nenhum PDF carregado'), ('-20810', 'Número de página inválido'),
          ('-20821', 'Coordenadas inválidas'), ('-20823', 'Formato de imagem inválido (use JPEG ou PNG)'),
          ('-20824', 'Dimensões de imagem inválidas')],
  example="""PL_FPDF.OverlayImage(
  p_page_number => 1,
  p_image_blob  => l_logo,
  p_x => 450, p_y => 750,
  p_width => 100, p_height => NULL,
  p_options => JSON_OBJECT_T('{"opacity":0.9,"maintainAspect":true}'));""",
  see=['OverlayText', 'Image', 'GetOverlays']),

'getoverlays': dict(group='overlay', desc="Lista as sobreposições aplicadas, opcionalmente filtrando por página.",
  params={'p_page_number': ("Filtro de página.", V_PAGE + "; NULL (padrão) retorna as de todas as páginas")},
  returns="JSON_ARRAY_T — objetos com overlayId, overlayType ('TEXT' ou 'IMAGE'), pageNumber, x, y, content, opacity, rotation e zOrder.",
  raises=[('-20809', 'Nenhum PDF carregado')], see=['OverlayText', 'RemoveOverlay']),

'removeoverlay': dict(group='overlay', desc="Remove uma sobreposição específica pelo seu identificador.",
  params={'p_overlay_id': ("Identificador da sobreposição.", "Valor overlayId retornado por GetOverlays, ex.: 'OVL_001'")},
  see=['GetOverlays', 'ClearOverlays']),

'clearoverlays': dict(group='overlay', desc="Remove todas as sobreposições, de uma página específica ou de todo o documento.",
  params={'p_page_number': ("Página a limpar.", V_PAGE + "; NULL (padrão) limpa todas as páginas")},
  see=['RemoveOverlay', 'GetOverlays']),

# ───────────────────────────────── multi-PDF ────────────────────────────────
'loadpdfwithid': dict(group='multi',
  desc="Carrega um PDF na memória associando-o a um identificador, permitindo manter vários documentos "
       "abertos simultaneamente para mesclar, dividir ou extrair páginas.",
  params={
    'p_pdf_blob': ("Documento a carregar.", "BLOB com PDF válido"),
    'p_pdf_id':   ("Identificador do documento na sessão.", "Texto único, ex.: 'capa', 'anexo1'"),
  },
  raises=[('-20800', 'PDF inválido'), ('-20801', 'Cabeçalho PDF inválido')],
  example="""PL_FPDF.LoadPDFWithID(l_capa,  'capa');
PL_FPDF.LoadPDFWithID(l_corpo, 'corpo');""",
  see=['MergePDFs', 'SplitPDF', 'ExtractPages', 'UnloadPDF', 'GetLoadedPDFs']),

'getloadedpdfs': dict(group='multi', desc="Lista os documentos atualmente carregados com identificador.",
  params={}, returns="JSON_ARRAY_T — objetos com o id e as informações de cada PDF carregado.",
  see=['LoadPDFWithID', 'UnloadPDF']),

'unloadpdf': dict(group='multi', desc="Remove da memória um documento carregado por LoadPDFWithID.",
  params={'p_pdf_id': ("Identificador do documento.", "O mesmo usado em LoadPDFWithID")},
  raises=[('-20831', 'ID do PDF não encontrado')], see=['LoadPDFWithID', 'ClearPDFCache']),

'mergepdfs': dict(group='multi',
  desc="Mescla vários PDFs carregados em um único documento, na ordem informada.",
  params={
    'p_pdf_ids': ("Identificadores dos documentos, na ordem desejada.",
                  "JSON_ARRAY_T de textos, ex.: JSON_ARRAY_T('[\"capa\",\"corpo\",\"anexo\"]')"),
    'p_options': ("Opções da mesclagem.", "JSON_OBJECT_T opcional; chaves reservadas para uso futuro"),
  },
  returns="BLOB — PDF resultante da mesclagem.",
  raises=[('-20831', 'ID do PDF não encontrado')],
  example="""PL_FPDF.LoadPDFWithID(l_capa,  'capa');
PL_FPDF.LoadPDFWithID(l_corpo, 'corpo');
l_final := PL_FPDF.MergePDFs(JSON_ARRAY_T('["capa","corpo"]'));""",
  see=['LoadPDFWithID', 'SplitPDF', 'ExtractPages']),

'splitpdf': dict(group='multi',
  desc="Divide um PDF carregado em vários documentos, conforme os intervalos de páginas informados.",
  params={
    'p_pdf_id':      ("Identificador do documento a dividir.", "O mesmo usado em LoadPDFWithID"),
    'p_page_ranges': ("Intervalos que definem cada parte gerada.",
                      "JSON_ARRAY_T de textos: '1-10', '11-20', '21-' (até o fim), '5' (página única)"),
  },
  returns="JSON_ARRAY_T — uma entrada por parte gerada, com o intervalo e o PDF correspondente.",
  raises=[('-20831', 'ID do PDF não encontrado'), ('-20838', 'Especificação de páginas inválida'),
          ('-20839', 'Número de página fora do intervalo')],
  example="l_partes := PL_FPDF.SplitPDF('corpo', JSON_ARRAY_T('[\"1-10\",\"11-20\",\"21-\"]'));",
  see=['ExtractPages', 'MergePDFs']),

'extractpages': dict(group='multi',
  desc="Cria um novo PDF contendo apenas as páginas selecionadas de um documento carregado.",
  params={
    'p_pdf_id': ("Identificador do documento de origem.", "O mesmo usado em LoadPDFWithID"),
    'p_pages':  ("Páginas a extrair.", "Lista e intervalos separados por vírgula, ex.: '1', '1,5,9', '1,5-10,15'"),
    'p_options':("Opções da extração.", "JSON_OBJECT_T opcional; chaves reservadas para uso futuro"),
  },
  returns="BLOB — PDF com as páginas extraídas.",
  raises=[('-20831', 'ID do PDF não encontrado'), ('-20838', 'Especificação de páginas inválida'),
          ('-20839', 'Número de página fora do intervalo')],
  example="l_resumo := PL_FPDF.ExtractPages('corpo', '1,5-10,15');",
  see=['SplitPDF', 'MergePDFs']),

# ──────────────────────────────── segurança ─────────────────────────────────
'encryptpdf': dict(group='security',
  desc="Criptografa um PDF já existente, aplicando senhas e permissões. É a forma recomendada de proteger "
       "documentos gerados ou recebidos.",
  params={
    'p_pdf':            ("Documento a proteger.", "BLOB com PDF válido, não criptografado"),
    'p_user_password':  ("Senha solicitada para abrir o documento.", "Texto; vazio permite abrir sem senha, mantendo as restrições"),
    'p_owner_password': ("Senha de proprietário, que permite alterar permissões.",
                         "Texto; NULL (padrão) usa a mesma senha de usuário"),
    'p_permissions':    ("Permissões concedidas ao leitor.",
      "JSON_OBJECT_T com as chaves booleanas: print, modify, copy, annotate, fill_forms, extract, "
      "assemble, print_high. Ausentes assumem o padrão restritivo"),
    'p_encryption':     ("Algoritmo de criptografia.", "'RC4-128' (padrão) ou 'RC4-40' (legado, compatível com leitores antigos)"),
  },
  returns="BLOB — PDF criptografado.",
  example="""DECLARE
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_perms.put('print', TRUE);
  l_perms.put('copy',  FALSE);
  l_seguro := PL_FPDF.EncryptPDF(
    p_pdf            => l_pdf,
    p_user_password  => 'senhaLeitura',
    p_owner_password => 'senhaAdmin',
    p_permissions    => l_perms,
    p_encryption     => 'RC4-128');
END;""",
  see=['DecryptPDF', 'IsEncrypted', 'SetEncryption', 'SetPermissions']),

'decryptpdf': dict(group='security', desc="Remove a proteção de um PDF criptografado, exigindo a senha correta.",
  params={
    'p_pdf':      ("Documento criptografado.", "BLOB com PDF protegido"),
    'p_password': ("Senha de usuário ou de proprietário.", "Texto correspondente a uma das senhas do documento"),
  },
  returns="BLOB — PDF sem criptografia.", see=['EncryptPDF', 'IsEncrypted']),

'isencrypted': dict(group='security', desc="Verifica se um PDF está criptografado.",
  params={'p_pdf': ("Documento a verificar.", "BLOB com PDF válido")},
  returns="BOOLEAN — TRUE se o documento possui criptografia.", see=['GetSecurityInfo', 'DecryptPDF']),

'getsecurityinfo': dict(group='security', desc="Retorna os detalhes de segurança de um PDF criptografado.",
  params={'p_pdf': ("Documento a inspecionar.", "BLOB com PDF válido")},
  returns="JSON_OBJECT_T — algoritmo, tamanho da chave e permissões concedidas.",
  see=['IsEncrypted', 'EncryptPDF']),

'setencryption': dict(group='security',
  desc="Define a criptografia de um documento em construção; aplicada quando o PDF for finalizado por OutputBlob.",
  params={
    'p_encryption':     ("Algoritmo de criptografia.", "'RC4-128' ou 'RC4-40'"),
    'p_user_password':  ("Senha de abertura.", "Texto"),
    'p_owner_password': ("Senha de proprietário.", "Texto; NULL (padrão) = igual à de usuário"),
  },
  example="""PL_FPDF.Init; PL_FPDF.AddPage;
PL_FPDF.SetEncryption('RC4-128', 'senhaLeitura', 'senhaAdmin');
PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE);
l_pdf := PL_FPDF.OutputBlob();""",
  see=['SetPermissions', 'EncryptPDF']),

'setpermissions': dict(group='security',
  desc="Define as permissões do documento em construção, aplicadas junto com a criptografia definida em SetEncryption.",
  params={
    'p_print':      ("Permite imprimir.", V_BOOL + "; TRUE é o padrão"),
    'p_modify':     ("Permite alterar o conteúdo.", V_BOOL + "; FALSE é o padrão"),
    'p_copy':       ("Permite copiar texto e imagens.", V_BOOL + "; FALSE é o padrão"),
    'p_annotate':   ("Permite adicionar comentários e anotações.", V_BOOL + "; TRUE é o padrão"),
    'p_fill_forms': ("Permite preencher campos de formulário.", V_BOOL + "; TRUE é o padrão"),
    'p_extract':    ("Permite extrair conteúdo para acessibilidade.", V_BOOL + "; FALSE é o padrão"),
    'p_assemble':   ("Permite inserir, remover e girar páginas.", V_BOOL + "; FALSE é o padrão"),
    'p_print_high': ("Permite impressão em alta resolução.", V_BOOL + "; TRUE é o padrão"),
  },
  example="""PL_FPDF.SetPermissions(
  p_print  => TRUE,
  p_copy   => FALSE,
  p_modify => FALSE);""",
  see=['SetEncryption', 'EncryptPDF']),

'setpdfversion': dict(group='security', desc="Define a versão declarada no cabeçalho do PDF gerado.",
  params={'p_version': ("Versão do arquivo PDF.", "'1.4', '1.5', '1.6' ou '1.7'")},
  see=['GetPDFVersion']),
'getpdfversion': dict(group='security', desc="Retorna a versão de PDF configurada para a saída.",
  params={}, returns="VARCHAR2 — versão, ex.: '1.7'.", see=['SetPDFVersion']),

# ─────────────────────────────── diagnóstico ────────────────────────────────
'debugenabled':  dict(group='diag', desc="Ativa as mensagens de depuração do package.", params={}, see=['SetLogLevel']),
'debugdisabled': dict(group='diag', desc="Desativa as mensagens de depuração.", params={}, see=['SetLogLevel']),
'error': dict(group='diag', desc="Levanta um erro padronizado do PL_FPDF. Uso interno e em extensões.",
  params={'pmsg': ("Mensagem do erro.", "Qualquer VARCHAR2")}),
'getscalefactor': dict(group='diag', desc="Retorna o fator de conversão entre a unidade do documento e pontos PDF.",
  params={}, returns="NUMBER — fator de escala (ex.: 2.8346 para milímetros).", see=['Init']),
'helloworld': dict(group='diag', desc="Gera um PDF mínimo de demonstração — útil para validar a instalação.", params={},
  example="PL_FPDF.helloworld;", see=['Init']),
'fpdf': dict(group='lifecycle',
  desc="Inicializa o documento no estilo FPDF clássico. Mantido por compatibilidade com a v0.9.4; "
       "em código novo use Init.",
  params={
    'orientation': ("Orientação.", "'P' (padrão) ou 'L'"),
    'unit':        ("Unidade de medida.", "'mm' (padrão), 'cm', 'pt' ou 'in'"),
    'format':      ("Formato da página.", "'A3', 'A4' (padrão), 'A5', 'Letter' ou 'Legal'"),
  }, see=['Init']),
}

# APIs internas/demonstração que não entram na referência pública
SKIP = {'testimg', 'test', 'testheader', 'myrepetitiveheader', 'myrepetitivefooter', 'lpc_footer'}
