# PL_FPDF — Referência da API

**Versão:** 3.2.0 | **Oracle:** 19c+ | **Licença:** MIT

Documentação detalhada de cada função e procedure pública do package `PL_FPDF`:
sintaxe, parâmetros com valores possíveis, retorno, erros levantados e exemplo.

> Guia de uso por tarefa: [DOCUMENTATION.md](DOCUMENTATION.md) ·
> Versão navegável: [maxwbh.github.io/pl_fpdf/reference.html](https://maxwbh.github.io/pl_fpdf/reference.html)

## Índice

**Ciclo de vida** — [fpdf](#fpdf) · [Init](#init) · [IsInitialized](#isinitialized) · [Reset](#reset)
**Páginas e posicionamento** — [AcceptPageBreak](#acceptpagebreak) · [AddPage](#addpage) · [GetCurrentPage](#getcurrentpage) · [GetX](#getx) · [GetY](#gety) · [Ln](#ln) · [PageNo](#pageno) · [SetAutoPageBreak](#setautopagebreak) · [SetLeftMargin](#setleftmargin) · [SetMargins](#setmargins) · [SetPage](#setpage) · [SetRightMargin](#setrightmargin) · [SetTopMargin](#settopmargin) · [SetX](#setx) · [SetXY](#setxy) · [SetY](#sety)
**Fontes e UTF-8** — [AddFont](#addfont) · [AddTTFFont](#addttffont) · [ClearTTFFontCache](#clearttffontcache) · [GetTTFFontInfo](#getttffontinfo) · [IsTTFFontLoaded](#isttffontloaded) · [IsUTF8Enabled](#isutf8enabled) · [LoadTTFFromFile](#loadttffromfile) · [SetFont](#setfont) · [SetFontSize](#setfontsize) · [SetUTF8Enabled](#setutf8enabled) · [UTF8ToPDFString](#utf8topdfstring)
**Escrita de texto** — [Cell](#cell) · [CellRotated](#cellrotated) · [GetCurrentFontFamily](#getcurrentfontfamily) · [GetCurrentFontSize](#getcurrentfontsize) · [GetCurrentFontStyle](#getcurrentfontstyle) · [GetLineSpacing](#getlinespacing) · [GetStringWidth](#getstringwidth) · [MultiCell](#multicell) · [SetLineSpacing](#setlinespacing) · [Text](#text) · [Write](#write) · [WriteRotated](#writerotated)
**Cores e desenho** — [Line](#line) · [Poly](#poly) · [Rect](#rect) · [SetDash](#setdash) · [SetDrawColor](#setdrawcolor) · [SetFillColor](#setfillcolor) · [SetLineDashPattern](#setlinedashpattern) · [SetLineWidth](#setlinewidth) · [SetTextColor](#settextcolor) · [Triangle](#triangle)
**Imagens** — [getImageFromUrl](#getimagefromurl) · [image](#image)
**Links** — [AddLink](#addlink) · [Link](#link) · [SetLink](#setlink)
**Cabeçalho e rodapé** — [Footer](#footer) · [Header](#header) · [SetAliasNbPages](#setaliasnbpages) · [SetFooterProc](#setfooterproc) · [SetHeaderProc](#setheaderproc)
**QR Code e código de barras** — [AddBarcode](#addbarcode) · [AddQRCode](#addqrcode)
**Metadados e configuração** — [GetDocumentMetadata](#getdocumentmetadata) · [GetPageInfo](#getpageinfo) · [SetAuthor](#setauthor) · [SetCompression](#setcompression) · [SetCreator](#setcreator) · [SetDisplayMode](#setdisplaymode) · [SetDocumentConfig](#setdocumentconfig) · [SetKeywords](#setkeywords) · [SetSubject](#setsubject) · [SetTitle](#settitle)
**Saída do documento** — [ClosePDF](#closepdf) · [OpenPDF](#openpdf) · [Output](#output) · [OutputBlob](#outputblob) · [OutputFile](#outputfile) · [ReturnBlob](#returnblob)
**Manipulação de PDF existente** — [AddWatermark](#addwatermark) · [ClearPDFCache](#clearpdfcache) · [GetActivePageCount](#getactivepagecount) · [GetPageCount](#getpagecount) · [GetPDFInfo](#getpdfinfo) · [GetWatermarks](#getwatermarks) · [IsPageRemoved](#ispageremoved) · [IsPDFModified](#ispdfmodified) · [LoadPDF](#loadpdf) · [OutputModifiedPDF](#outputmodifiedpdf) · [RemovePage](#removepage) · [RotatePage](#rotatepage)
**Overlays** — [ClearOverlays](#clearoverlays) · [GetOverlays](#getoverlays) · [OverlayImage](#overlayimage) · [OverlayText](#overlaytext) · [RemoveOverlay](#removeoverlay)
**Multi-PDF (merge, split, extract)** — [ExtractPages](#extractpages) · [GetLoadedPDFs](#getloadedpdfs) · [LoadPDFWithID](#loadpdfwithid) · [MergePDFs](#mergepdfs) · [SplitPDF](#splitpdf) · [UnloadPDF](#unloadpdf)
**Segurança e criptografia** — [DecryptPDF](#decryptpdf) · [EncryptPDF](#encryptpdf) · [GetPDFVersion](#getpdfversion) · [GetSecurityInfo](#getsecurityinfo) · [IsEncrypted](#isencrypted) · [SetEncryption](#setencryption) · [SetPDFVersion](#setpdfversion) · [SetPermissions](#setpermissions)
**Diagnóstico e utilidades** — [DebugDisabled](#debugdisabled) · [DebugEnabled](#debugenabled) · [Error](#error) · [GetLogLevel](#getloglevel) · [GetScaleFactor](#getscalefactor) · [helloworld](#helloworld) · [SetLogLevel](#setloglevel)

---

## Ciclo de vida

### fpdf

Inicializa o documento no estilo FPDF clássico. Mantido por compatibilidade com a v0.9.4; em código novo use Init.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.fpdf(
    orientation varchar2 DEFAULT 'P',
    unit        varchar2 DEFAULT 'mm',
    format      varchar2 DEFAULT 'A4');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `orientation` | VARCHAR2 | Orientação. | 'P' (padrão) ou 'L' | `'P'` |
| `unit` | VARCHAR2 | Unidade de medida. | 'mm' (padrão), 'cm', 'pt' ou 'in' | `'mm'` |
| `format` | VARCHAR2 | Formato da página. | 'A3', 'A4' (padrão), 'A5', 'Letter' ou 'Legal' | `'A4'` |

**Veja também:** [Init](#init)

---

### Init

Inicializa um novo documento PDF. Deve ser a primeira chamada de qualquer geração; define orientação, unidade de medida, formato de página e codificação usados por todas as demais APIs.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Init(
    p_orientation varchar2 DEFAULT 'P',
    p_unit        varchar2 DEFAULT 'mm',
    p_format      varchar2 DEFAULT 'A4',
    p_encoding    varchar2 DEFAULT 'UTF-8');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_orientation` | VARCHAR2 | Orientação padrão das páginas. | 'P' (retrato, padrão) ou 'L' (paisagem) | `'P'` |
| `p_unit` | VARCHAR2 | Unidade de medida de todas as coordenadas e dimensões do documento. | 'mm' (padrão), 'cm', 'pt' ou 'in' | `'mm'` |
| `p_format` | VARCHAR2 | Formato de página padrão. | 'A3', 'A4' (padrão), 'A5', 'Letter' ou 'Legal' | `'A4'` |
| `p_encoding` | VARCHAR2 | Codificação de caracteres do texto. | 'UTF-8' (padrão) ou 'WINDOWS-1252' | `'UTF-8'` |

#### Exemplo

```sql
BEGIN
  PL_FPDF.Init(p_orientation => 'P', p_unit => 'mm', p_format => 'A4');
  PL_FPDF.AddPage();
  -- ...
END;
```

**Veja também:** [Reset](#reset), [IsInitialized](#isinitialized), [AddPage](#addpage)

---

### IsInitialized

Indica se há um documento em construção na sessão atual.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsInitialized
    RETURN BOOLEAN;
```

#### Retorno

BOOLEAN — TRUE se Init já foi chamado e o documento não foi finalizado.

#### Exemplo

```sql
IF NOT PL_FPDF.IsInitialized THEN
  PL_FPDF.Init;
END IF;
```

**Veja também:** [Init](#init)

---

### Reset

Reinicia o motor de PDF ao estado inicial, liberando CLOBs temporários e limpando todos os arrays internos. Use entre documentos gerados no mesmo job ou ao final de rotinas longas.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Reset;
```

#### Exemplo

```sql
PL_FPDF.Reset;
```

**Veja também:** [Init](#init), [ClearPDFCache](#clearpdfcache)

---

## Páginas e posicionamento

### AcceptPageBreak

Informa se a quebra automática deve ocorrer no ponto atual. Chamada internamente pelo motor; pode ser consultada para lógicas próprias de paginação.

#### Sintaxe

```sql
FUNCTION PL_FPDF.AcceptPageBreak
    RETURN BOOLEAN;
```

#### Retorno

BOOLEAN — TRUE se a quebra automática está habilitada.

**Veja também:** [SetAutoPageBreak](#setautopagebreak)

---

### AddPage

Adiciona uma nova página ao documento e a torna a página corrente. Parâmetros nulos herdam os valores definidos em Init, permitindo misturar orientações e formatos no mesmo PDF.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddPage(
    p_orientation varchar2 DEFAULT null,
    p_format      varchar2 DEFAULT null,
    p_rotation    pls_integer DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_orientation` | VARCHAR2 | Orientação apenas desta página. | 'P', 'L' ou NULL (herda de Init) | `null` |
| `p_format` | VARCHAR2 | Formato apenas desta página. | 'A3', 'A4', 'A5', 'Letter', 'Legal' ou NULL (herda de Init) | `null` |
| `p_rotation` | PLS_INTEGER | Rotação de exibição da página no leitor de PDF. | 0 (padrão), 90, 180 ou 270 | `0` |

#### Erros

| Código | Condição |
|--------|----------|
| `-20105` | Documento não inicializado (chame Init antes) |

#### Exemplo

```sql
PL_FPDF.AddPage;                                      -- herda tudo de Init
PL_FPDF.AddPage(p_orientation => 'L');                -- só esta em paisagem
PL_FPDF.AddPage(p_format => 'A5', p_rotation => 90);  -- A5 rotacionada
```

**Veja também:** [Init](#init), [SetPage](#setpage), [GetCurrentPage](#getcurrentpage)

---

### GetCurrentPage

Retorna o número da página corrente (a que está recebendo conteúdo).

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentPage
    RETURN PLS_INTEGER;
```

#### Retorno

PLS_INTEGER — número da página ativa.

**Veja também:** [SetPage](#setpage), [PageNo](#pageno)

---

### GetX

Retorna a posição X atual do cursor.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetX
    RETURN NUMBER;
```

#### Retorno

NUMBER — coordenada X.

**Veja também:** [SetX](#setx), [SetXY](#setxy)

---

### GetY

Retorna a posição Y atual do cursor.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetY
    RETURN NUMBER;
```

#### Retorno

NUMBER — coordenada Y.

**Veja também:** [SetY](#sety)

---

### Ln

Move o cursor para a próxima linha, retornando à margem esquerda.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Ln(
    h number DEFAULT null);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `h` | NUMBER | Altura do salto. | Número na unidade definida em Init (mm, cm, pt ou in); NULL (padrão) usa a altura da última célula escrita | `null` |

#### Exemplo

```sql
PL_FPDF.Ln(6);
```

**Veja também:** [SetXY](#setxy)

---

### PageNo

Retorna o número da página atual durante a geração — usado tipicamente em rodapés.

#### Sintaxe

```sql
FUNCTION PL_FPDF.PageNo
    RETURN NUMBER;
```

#### Retorno

NUMBER — número da página corrente.

#### Exemplo

```sql
PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
```

**Veja também:** [SetAliasNbPages](#setaliasnbpages), [SetFooterProc](#setfooterproc)

---

### SetAutoPageBreak

Liga ou desliga a quebra automática de página e define a distância da borda inferior em que ela ocorre.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetAutoPageBreak(
    pauto   boolean,
    pMargin number DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pauto` | BOOLEAN | Ativa a quebra automática. | TRUE ou FALSE | — |
| `pMargin` | NUMBER | Margem inferior que dispara a quebra. | Número na unidade definida em Init (mm, cm, pt ou in); 0 é o padrão | `0` |

#### Exemplo

```sql
PL_FPDF.SetAutoPageBreak(pauto => TRUE, pMargin => 15);
```

**Veja também:** [AcceptPageBreak](#acceptpagebreak), [SetMargins](#setmargins)

---

### SetLeftMargin

Define apenas a margem esquerda.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLeftMargin(
    pMargin number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pMargin` | NUMBER | Margem esquerda. | Número na unidade definida em Init (mm, cm, pt ou in) | — |

**Veja também:** [SetMargins](#setmargins)

---

### SetMargins

Define as margens esquerda, superior e direita do documento. A margem inferior é controlada por SetAutoPageBreak.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetMargins(
    left  number,
    top   number,
    right number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `left` | NUMBER | Margem esquerda. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `top` | NUMBER | Margem superior. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `right` | NUMBER | Margem direita. | Número na unidade definida em Init (mm, cm, pt ou in); -1 (padrão) usa o mesmo valor da margem esquerda | `-1` |

#### Exemplo

```sql
PL_FPDF.SetMargins(left => 20, top => 15, right => 20);
```

**Veja também:** [SetLeftMargin](#setleftmargin), [SetTopMargin](#settopmargin), [SetRightMargin](#setrightmargin), [SetAutoPageBreak](#setautopagebreak)

---

### SetPage

Define qual página existente recebe o conteúdo das próximas chamadas, permitindo voltar a páginas anteriores (por exemplo, para preencher um sumário depois de conhecer os números finais).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetPage(
    p_page_number pls_integer);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página que passa a ser a corrente. | Inteiro ≥ 1, até GetPageCount | — |

#### Erros

| Código | Condição |
|--------|----------|
| `-20105` | PDF não inicializado |
| `-20106` | A página informada não existe |

#### Exemplo

```sql
PL_FPDF.SetPage(1);
PL_FPDF.SetXY(20, 40);
PL_FPDF.Cell(0, 8, 'Preenchido depois');
```

**Veja também:** [AddPage](#addpage), [GetCurrentPage](#getcurrentpage)

---

### SetRightMargin

Define apenas a margem direita.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetRightMargin(
    pMargin number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pMargin` | NUMBER | Margem direita. | Número na unidade definida em Init (mm, cm, pt ou in) | — |

**Veja também:** [SetMargins](#setmargins)

---

### SetTopMargin

Define apenas a margem superior.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetTopMargin(
    pMargin number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pMargin` | NUMBER | Margem superior. | Número na unidade definida em Init (mm, cm, pt ou in) | — |

**Veja também:** [SetMargins](#setmargins)

---

### SetX

Define a posição X do cursor.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetX(
    px number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | Nova coordenada X. | Número na unidade definida em Init (mm, cm, pt ou in); valores negativos contam a partir da borda direita | — |

**Veja também:** [GetX](#getx)

---

### SetXY

Define X e Y do cursor em uma única chamada.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetXY(
    x number,
    y number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `x` | NUMBER | Coordenada X. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `y` | NUMBER | Coordenada Y. | Número na unidade definida em Init (mm, cm, pt ou in) | — |

#### Exemplo

```sql
PL_FPDF.SetXY(x => 20, y => 40);
```

**Veja também:** [SetX](#setx), [SetY](#sety)

---

### SetY

Define a posição Y do cursor (e reposiciona X na margem esquerda).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetY(
    py number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `py` | NUMBER | Nova coordenada Y. | Número na unidade definida em Init (mm, cm, pt ou in); valores negativos contam a partir da borda inferior — ex.: -15 para rodapé | — |

#### Exemplo

```sql
PL_FPDF.SetY(-15);  -- 15 unidades acima do fim da página
```

**Veja também:** [GetY](#gety), [SetXY](#setxy)

---

## Fontes e UTF-8

### AddFont

Registra uma fonte adicional (compatibilidade FPDF). Para TrueType com UTF-8, prefira AddTTFFont.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddFont(
    family   varchar2,
    style    varchar2 DEFAULT '',
    filename varchar2 DEFAULT '');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `family` | VARCHAR2 | Nome da família a registrar. | Texto livre; usado depois em SetFont | — |
| `style` | VARCHAR2 | Estilo associado ao arquivo. | '', 'B', 'I' ou 'BI' | `''` |
| `filename` | VARCHAR2 | Arquivo de definição da fonte. | Nome do arquivo; vazio usa a convenção padrão do FPDF | `''` |

**Veja também:** [AddTTFFont](#addttffont), [SetFont](#setfont)

---

### AddTTFFont

Carrega uma fonte TrueType a partir de um BLOB (por exemplo, de uma tabela de assets) e a disponibiliza para SetFont, com suporte completo a UTF-8.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddTTFFont(
    p_font_name varchar2,
    p_font_blob blob,
    p_encoding  varchar2 DEFAULT 'UTF-8',
    p_embed     boolean DEFAULT true);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Nome pelo qual a fonte será referenciada em SetFont. | Texto livre, ex.: 'Roboto' | — |
| `p_font_blob` | BLOB | Conteúdo binário do arquivo .ttf. | BLOB não nulo com fonte TrueType válida | — |
| `p_encoding` | VARCHAR2 | Codificação da fonte. | 'UTF-8' (padrão) ou 'WINDOWS-1252' | `'UTF-8'` |
| `p_embed` | BOOLEAN | Embute a fonte no PDF (garante a aparência em qualquer leitor, aumenta o arquivo). | TRUE ou FALSE; TRUE é o padrão | `true` |

#### Exemplo

```sql
DECLARE
  l_ttf BLOB;
BEGIN
  SELECT arquivo INTO l_ttf FROM fontes WHERE nome = 'Roboto-Regular';
  PL_FPDF.AddTTFFont(p_font_name => 'Roboto', p_font_blob => l_ttf, p_embed => TRUE);
  PL_FPDF.SetFont('Roboto', '', 12);
END;
```

**Veja também:** [LoadTTFFromFile](#loadttffromfile), [IsTTFFontLoaded](#isttffontloaded), [SetFont](#setfont)

---

### ClearTTFFontCache

Descarta todas as fontes TrueType carregadas, liberando memória da sessão.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClearTTFFontCache;
```

**Veja também:** [AddTTFFont](#addttffont)

---

### GetTTFFontInfo

Retorna os metadados de uma fonte TrueType carregada.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetTTFFontInfo(
    p_font_name varchar2)
    RETURN RECTTFFONT;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Nome da fonte. | O mesmo usado no carregamento | — |

#### Retorno

recTTFFont — record com métricas e informações da fonte.

**Veja também:** [AddTTFFont](#addttffont)

---

### IsTTFFontLoaded

Verifica se uma fonte TrueType já foi carregada na sessão.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsTTFFontLoaded(
    p_font_name varchar2)
    RETURN BOOLEAN;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Nome da fonte. | O mesmo usado no carregamento | — |

#### Retorno

BOOLEAN — TRUE se a fonte está no cache.

**Veja também:** [AddTTFFont](#addttffont), [ClearTTFFontCache](#clearttffontcache)

---

### IsUTF8Enabled

Indica se o modo UTF-8 está ativo.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsUTF8Enabled
    RETURN BOOLEAN;
```

#### Retorno

BOOLEAN — TRUE se UTF-8 está habilitado.

**Veja também:** [SetUTF8Enabled](#setutf8enabled)

---

### LoadTTFFromFile

Carrega uma fonte TrueType a partir de um arquivo em um DIRECTORY do Oracle.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.LoadTTFFromFile(
    p_font_name varchar2,
    p_file_path varchar2,
    p_directory varchar2 DEFAULT 'FONTS_DIR',
    p_encoding  varchar2 DEFAULT 'UTF-8');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_font_name` | VARCHAR2 | Nome para uso em SetFont. | Texto livre | — |
| `p_file_path` | VARCHAR2 | Nome do arquivo .ttf dentro do diretório. | Ex.: 'Roboto-Regular.ttf' | — |
| `p_directory` | VARCHAR2 | DIRECTORY do Oracle com permissão de leitura. | Padrão: 'FONTS_DIR' | `'FONTS_DIR'` |
| `p_encoding` | VARCHAR2 | Codificação da fonte. | 'UTF-8' (padrão) ou 'WINDOWS-1252' | `'UTF-8'` |

#### Exemplo

```sql
PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');
```

**Veja também:** [AddTTFFont](#addttffont)

---

### SetFont

Define a fonte, o estilo e o tamanho usados pelas próximas escritas de texto.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFont(
    pfamily varchar2,
    pstyle  varchar2 DEFAULT '',
    psize   number DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pfamily` | VARCHAR2 | Família da fonte. | 'Arial'/'Helvetica', 'Times', 'Courier', 'Symbol', 'ZapfDingbats' ou o nome de uma fonte TrueType carregada com AddTTFFont/LoadTTFFromFile | — |
| `pstyle` | VARCHAR2 | Estilo do texto. | '' (normal), 'B' (negrito), 'I' (itálico), 'BI' (negrito itálico) ou 'U' (sublinhado) | `''` |
| `psize` | NUMBER | Tamanho em pontos. | Número > 0; 0 (padrão) mantém o tamanho atual | `0` |

#### Exemplo

```sql
PL_FPDF.SetFont('Arial', 'B', 16);
```

**Veja também:** [SetFontSize](#setfontsize), [AddTTFFont](#addttffont), [GetStringWidth](#getstringwidth)

---

### SetFontSize

Altera apenas o tamanho da fonte corrente.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFontSize(
    psize number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `psize` | NUMBER | Tamanho em pontos. | Número > 0 | — |

**Veja também:** [SetFont](#setfont)

---

### SetUTF8Enabled

Liga ou desliga o tratamento UTF-8 do texto.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetUTF8Enabled(
    p_enabled boolean DEFAULT true);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_enabled` | BOOLEAN | Ativa UTF-8. | TRUE ou FALSE; TRUE é o padrão | `true` |

**Veja também:** [IsUTF8Enabled](#isutf8enabled), [UTF8ToPDFString](#utf8topdfstring)

---

### UTF8ToPDFString

Converte um texto UTF-8 para a representação interna do PDF. Chamada internamente; útil para depuração de acentuação.

#### Sintaxe

```sql
FUNCTION PL_FPDF.UTF8ToPDFString(
    p_text   varchar2,
    p_escape boolean DEFAULT true)
    RETURN VARCHAR2;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_text` | VARCHAR2 | Texto a converter. | Qualquer VARCHAR2 em UTF-8 | — |
| `p_escape` | BOOLEAN | Aplica escape dos caracteres especiais do PDF (parênteses e barra invertida). | TRUE ou FALSE | `true` |

#### Retorno

VARCHAR2 — texto convertido.

**Veja também:** [SetUTF8Enabled](#setutf8enabled)

---

## Escrita de texto

### Cell

Escreve um bloco retangular de texto, com bordas, alinhamento, preenchimento e link opcionais. É a API mais usada para montar relatórios e tabelas.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pw` | NUMBER | Largura da célula. | Número na unidade definida em Init (mm, cm, pt ou in); 0 estende até a margem direita | — |
| `ph` | NUMBER | Altura da célula. | Número na unidade definida em Init (mm, cm, pt ou in); 0 é o padrão | `0` |
| `ptxt` | VARCHAR2 | Texto a escrever. | Qualquer VARCHAR2; vazio desenha apenas a célula | `''` |
| `pborder` | VARCHAR2 | Bordas desenhadas. | '0' (nenhuma), '1' (moldura completa) ou combinação de 'L', 'T', 'R', 'B' — ex.: 'LTB' | `'0'` |
| `pln` | NUMBER | Para onde o cursor vai depois. | 0 = à direita da célula (padrão), 1 = início da próxima linha, 2 = abaixo da célula | `0` |
| `palign` | VARCHAR2 | Alinhamento do texto. | 'L' (esquerda), 'C' (centro), 'R' (direita) ou '' (padrão, esquerda) | `''` |
| `pfill` | NUMBER | Preenche o fundo com a cor de SetFillColor. | 0 = transparente (padrão), 1 = preenchido | `0` |
| `plink` | VARCHAR2 | Torna a célula clicável. | URL ('https://…') ou identificador retornado por AddLink | `''` |

#### Exemplo

```sql
PL_FPDF.SetFillColor(240, 240, 240);
PL_FPDF.Cell(
  pw      => 0,
  ph      => 10,
  ptxt    => 'Total: R$ 1.234,56',
  pborder => 'LTB',
  pln     => 1,
  palign  => 'R',
  pfill   => 1);
```

**Veja também:** [MultiCell](#multicell), [Write](#write), [CellRotated](#cellrotated), [SetFillColor](#setfillcolor)

---

### CellRotated

Versão de Cell com rotação do texto — útil para cabeçalhos verticais de tabelas e etiquetas.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_width` | NUMBER | Largura da célula. | Número na unidade definida em Init (mm, cm, pt ou in); 0 estende até a margem direita | — |
| `p_height` | NUMBER | Altura da célula. | Número na unidade definida em Init (mm, cm, pt ou in) | `0` |
| `p_text` | VARCHAR2 | Texto a escrever. | Qualquer VARCHAR2 | `''` |
| `p_border` | VARCHAR2 | Bordas. | '0', '1' ou combinação de 'L', 'T', 'R', 'B' | `'0'` |
| `p_ln` | NUMBER | Posição do cursor depois. | 0 = à direita, 1 = próxima linha, 2 = abaixo | `0` |
| `p_align` | VARCHAR2 | Alinhamento. | 'L', 'C' ou 'R' | `''` |
| `p_fill` | NUMBER | Preenchimento. | 0 ou 1 | `0` |
| `p_link` | VARCHAR2 | Link opcional. | URL ou identificador de AddLink | `''` |
| `p_rotation` | PLS_INTEGER | Ângulo de rotação do texto. | 0 (padrão), 90, 180 ou 270 — outros valores geram erro | `0` |

#### Erros

| Código | Condição |
|--------|----------|
| `-20110` | Valor de rotação inválido (use 0, 90, 180 ou 270) |

#### Exemplo

```sql
PL_FPDF.CellRotated(40, 10, 'VERTICAL', p_rotation => 90);
```

**Veja também:** [Cell](#cell), [WriteRotated](#writerotated)

---

### GetCurrentFontFamily

Retorna a família da fonte corrente.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentFontFamily
    RETURN VARCHAR2;
```

#### Retorno

VARCHAR2 — nome da família.

**Veja também:** [SetFont](#setfont)

---

### GetCurrentFontSize

Retorna o tamanho da fonte corrente.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentFontSize
    RETURN NUMBER;
```

#### Retorno

NUMBER — tamanho em pontos.

**Veja também:** [SetFont](#setfont)

---

### GetCurrentFontStyle

Retorna o estilo da fonte corrente.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentFontStyle
    RETURN VARCHAR2;
```

#### Retorno

VARCHAR2 — '', 'B', 'I', 'BI' ou 'U'.

**Veja também:** [SetFont](#setfont)

---

### GetLineSpacing

Retorna o espaçamento de linhas atual.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetLineSpacing
    RETURN NUMBER;
```

#### Retorno

NUMBER — espaçamento configurado.

**Veja também:** [SetLineSpacing](#setlinespacing)

---

### GetStringWidth

Calcula a largura que um texto ocupará na fonte e no tamanho correntes — use para centralizar manualmente, dimensionar colunas ou decidir quebras.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetStringWidth(
    pstr varchar2)
    RETURN NUMBER;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pstr` | VARCHAR2 | Texto a medir. | Qualquer VARCHAR2 | — |

#### Retorno

NUMBER — largura na unidade do documento.

#### Exemplo

```sql
l_w := PL_FPDF.GetStringWidth(l_titulo);
PL_FPDF.SetX((210 - l_w) / 2);   -- centraliza em A4 retrato (210 mm)
```

**Veja também:** [SetFont](#setfont), [Cell](#cell)

---

### MultiCell

Escreve um parágrafo com quebra automática de linha dentro de uma largura definida. Existe como function (retorna o número de linhas) e como procedure.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pw` | NUMBER | Largura do bloco. | Número na unidade definida em Init (mm, cm, pt ou in); 0 estende até a margem direita | — |
| `ph` | NUMBER | Altura de cada linha. | Número na unidade definida em Init (mm, cm, pt ou in) | `0` |
| `ptxt` | VARCHAR2 | Texto do parágrafo (aceita quebras de linha). | Qualquer VARCHAR2 | — |
| `pborder` | VARCHAR2 | Bordas do bloco. | '0', '1' ou combinação de 'L', 'T', 'R', 'B' | `'0'` |
| `palign` | VARCHAR2 | Alinhamento. | 'J' (justificado, padrão), 'L', 'C' ou 'R' | `'J'` |
| `pfill` | NUMBER | Preenche o fundo. | 0 (padrão) ou 1 | `0` |
| `phMax` | NUMBER | Altura máxima do bloco; o texto é truncado se exceder. | Número; 0 (padrão) = sem limite | `0` |
| `pwidth` | NUMBER | Largura do bloco (versão procedure). | Número na unidade definida em Init (mm, cm, pt ou in); 0 até a margem direita | — |
| `pheight` | NUMBER | Altura de cada linha (versão procedure). | Número na unidade definida em Init (mm, cm, pt ou in) | `0` |
| `ptext` | VARCHAR2 | Texto do parágrafo (versão procedure). | Qualquer VARCHAR2 | — |
| `pbrdr` | VARCHAR2 | Bordas (versão procedure). | '0', '1' ou 'LTRB' | `'0'` |
| `palignment` | VARCHAR2 | Alinhamento (versão procedure). | 'J', 'L', 'C' ou 'R' | `'J'` |
| `pfillin` | NUMBER | Preenchimento (versão procedure). | 0 ou 1 | `0` |
| `phMaximum` | NUMBER | Altura máxima (versão procedure). | Número; 0 = sem limite | `0` |

#### Retorno

NUMBER (versão function) — quantidade de linhas geradas.

#### Exemplo

```sql
l_linhas := PL_FPDF.MultiCell(
  pw      => 0,
  ph      => 6,
  ptxt    => l_descricao,
  pborder => '1',
  palign  => 'J');
```

**Veja também:** [Cell](#cell), [Write](#write)

---

### SetLineSpacing

Define o espaçamento entre linhas usado por Write e MultiCell.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLineSpacing(
    pls number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pls` | NUMBER | Fator/altura de espaçamento. | Número > 0 | — |

**Veja também:** [GetLineSpacing](#getlinespacing)

---

### Text

Escreve texto em coordenadas absolutas, sem alterar a posição do cursor nem quebrar linha.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Text(
    px   number,
    py   number,
    ptxt varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | Coordenada X do início do texto. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `py` | NUMBER | Coordenada Y da linha de base. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `ptxt` | VARCHAR2 | Texto a escrever. | Qualquer VARCHAR2 | — |

**Veja também:** [Cell](#cell), [Write](#write)

---

### Write

Escreve texto de forma fluida, continuando de onde o anterior parou e quebrando linha automaticamente — permite alternar fontes e estilos no meio de uma frase.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Write(
    pH    varchar2,
    ptxt  varchar2,
    plink varchar2 DEFAULT null);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pH` | VARCHAR2 | Altura da linha. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `ptxt` | VARCHAR2 | Texto a escrever. | Qualquer VARCHAR2 | — |
| `plink` | VARCHAR2 | Link opcional aplicado ao texto. | URL ou identificador de AddLink; NULL (padrão) = sem link | `null` |

#### Exemplo

```sql
PL_FPDF.Write(6, 'Documento gerado por ');
PL_FPDF.SetFont('Arial', 'B');
PL_FPDF.Write(6, 'PL_FPDF', 'https://maxwbh.github.io/pl_fpdf/');
```

**Veja também:** [Cell](#cell), [MultiCell](#multicell), [WriteRotated](#writerotated)

---

### WriteRotated

Versão de Write com rotação do texto.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.WriteRotated(
    p_height   number,
    p_text     varchar2,
    p_link     varchar2 DEFAULT null,
    p_rotation pls_integer DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_height` | NUMBER | Altura da linha. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_text` | VARCHAR2 | Texto a escrever. | Qualquer VARCHAR2 | — |
| `p_link` | VARCHAR2 | Link opcional. | URL ou identificador de AddLink; NULL = sem link | `null` |
| `p_rotation` | PLS_INTEGER | Ângulo de rotação. | 0 (padrão), 90, 180 ou 270 | `0` |

#### Erros

| Código | Condição |
|--------|----------|
| `-20110` | Valor de rotação inválido |

**Veja também:** [Write](#write), [CellRotated](#cellrotated)

---

## Cores e desenho

### Line

Desenha uma linha reta entre dois pontos.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Line(
    x1 number,
    y1 number,
    x2 number,
    y2 number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `x1` | NUMBER | X do ponto inicial. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `y1` | NUMBER | Y do ponto inicial. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `x2` | NUMBER | X do ponto final. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `y2` | NUMBER | Y do ponto final. | Número na unidade definida em Init (mm, cm, pt ou in) | — |

#### Exemplo

```sql
PL_FPDF.Line(10, 30, 200, 30);
```

**Veja também:** [SetDrawColor](#setdrawcolor), [SetLineWidth](#setlinewidth)

---

### Poly

Desenha um polígono a partir de uma coleção de pontos.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Poly(
    points tab_points,
    pclose boolean,
    pstyle varchar2 DEFAULT '');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `points` | TAB_POINTS | Pontos do polígono. | Coleção tab_points com pares X/Y na unidade do documento | — |
| `pclose` | BOOLEAN | Fecha o polígono ligando o último ponto ao primeiro. | TRUE ou FALSE | — |
| `pstyle` | VARCHAR2 | Estilo de renderização. | '' ou 'D' (contorno), 'F' (preenchido), 'DF' (ambos) | `''` |

**Veja também:** [Line](#line), [Triangle](#triangle)

---

### Rect

Desenha um retângulo com contorno, preenchimento ou ambos.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Rect(
    px     number,
    py     number,
    pw     number,
    ph     number,
    pstyle varchar2 DEFAULT '');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `py` | NUMBER | Y do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `pw` | NUMBER | Largura. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `ph` | NUMBER | Altura. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `pstyle` | VARCHAR2 | Estilo de renderização. | '' ou 'D' (apenas contorno, padrão), 'F' (apenas preenchimento), 'DF'/'FD' (contorno + preenchimento) | `''` |

#### Exemplo

```sql
PL_FPDF.Rect(px => 10, py => 40, pw => 60, ph => 25, pstyle => 'DF');
```

**Veja também:** [SetDrawColor](#setdrawcolor), [SetFillColor](#setfillcolor)

---

### SetDash

Define um padrão de linha tracejada simples.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDash(
    pblack number DEFAULT 0,
    pwhite number DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pblack` | NUMBER | Comprimento do traço. | Número na unidade definida em Init (mm, cm, pt ou in); 0 (padrão) volta para linha contínua | `0` |
| `pwhite` | NUMBER | Comprimento do espaço. | Número na unidade definida em Init (mm, cm, pt ou in); 0 (padrão) volta para linha contínua | `0` |

#### Exemplo

```sql
PL_FPDF.SetDash(2, 2);   -- tracejado
PL_FPDF.SetDash(0, 0);   -- volta ao contínuo
```

**Veja também:** [SetLineDashPattern](#setlinedashpattern)

---

### SetDrawColor

Define a cor das linhas e contornos desenhados a seguir.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDrawColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `r` | NUMBER | Componente vermelho ou tom de cinza quando g e b são omitidos. | 0 a 255 | — |
| `g` | NUMBER | Componente verde. | 0 a 255; -1 (padrão) indica escala de cinza usando r | `-1` |
| `b` | NUMBER | Componente azul. | 0 a 255; -1 (padrão) indica escala de cinza usando r | `-1` |

#### Exemplo

```sql
PL_FPDF.SetDrawColor(200, 0, 0);   -- vermelho
PL_FPDF.SetDrawColor(128);         -- cinza médio
```

**Veja também:** [SetFillColor](#setfillcolor), [SetTextColor](#settextcolor), [SetLineWidth](#setlinewidth)

---

### SetFillColor

Define a cor de preenchimento de células (pfill = 1), retângulos e formas.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFillColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `r` | NUMBER | Componente vermelho ou tom de cinza. | 0 a 255 | — |
| `g` | NUMBER | Componente verde. | 0 a 255; -1 = escala de cinza | `-1` |
| `b` | NUMBER | Componente azul. | 0 a 255; -1 = escala de cinza | `-1` |

#### Exemplo

```sql
PL_FPDF.SetFillColor(240, 240, 240);
```

**Veja também:** [Cell](#cell), [Rect](#rect)

---

### SetLineDashPattern

Define o padrão de tracejado usando a sintaxe nativa do PDF, para controle fino.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLineDashPattern(
    pdash varchar2 DEFAULT '[] 0');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pdash` | VARCHAR2 | Padrão no formato PDF. | '[] 0' (contínuo, padrão), '[3 2] 0' (3 on, 2 off), '[1 2 3 2] 0' etc. | `'[] 0'` |

**Veja também:** [SetDash](#setdash)

---

### SetLineWidth

Define a espessura das linhas desenhadas a seguir.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLineWidth(
    width number);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `width` | NUMBER | Espessura da linha. | Número na unidade definida em Init (mm, cm, pt ou in); padrão do PDF ≈ 0.2 mm | — |

**Veja também:** [Line](#line), [Rect](#rect)

---

### SetTextColor

Define a cor do texto escrito a seguir.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetTextColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `r` | NUMBER | Componente vermelho ou tom de cinza. | 0 a 255 | — |
| `g` | NUMBER | Componente verde. | 0 a 255; -1 = escala de cinza | `-1` |
| `b` | NUMBER | Componente azul. | 0 a 255; -1 = escala de cinza | `-1` |

**Veja também:** [SetFont](#setfont), [Cell](#cell)

---

### Triangle

Desenha um triângulo equilátero a partir do centro e do tamanho informados.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Triangle(
    px           number,
    py           number,
    psize        number,
    porientation varchar2 DEFAULT 'left',
    pstyle       varchar2 DEFAULT '');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X do centro. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `py` | NUMBER | Y do centro. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `psize` | NUMBER | Tamanho do triângulo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `porientation` | VARCHAR2 | Direção para onde a ponta aponta. | 'U' (cima), 'D' (baixo), 'L' (esquerda) ou 'R' (direita) | `'left'` |
| `pstyle` | VARCHAR2 | Estilo de renderização. | '' ou 'D' (contorno), 'F' (preenchido), 'DF' (ambos) | `''` |

**Veja também:** [Poly](#poly), [Rect](#rect)

---

## Imagens

### getImageFromUrl

Baixa uma imagem de uma URL via UTL_HTTP para uso no documento. Requer ACL de rede configurada no banco.

#### Sintaxe

```sql
FUNCTION PL_FPDF.getImageFromUrl(
    p_Url varchar2)
    RETURN RECIMAGEBLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_Url` | VARCHAR2 | Endereço da imagem. | URL http:// ou https:// acessível a partir do banco | — |

#### Retorno

recImageBlob — record com o conteúdo e os metadados da imagem.

**Veja também:** [Image](#image)

---

### image

Insere uma imagem PNG ou JPEG na página corrente, com dimensionamento proporcional opcional.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pFile` | VARCHAR2 | Origem da imagem. | Nome de arquivo em DIRECTORY do Oracle ou identificador retornado por getImageFromUrl | — |
| `pX` | NUMBER | X do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `pY` | NUMBER | Y do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `pWidth` | NUMBER | Largura desejada. | Número na unidade definida em Init (mm, cm, pt ou in); 0 (padrão) calcula a partir da altura | `0` |
| `pHeight` | NUMBER | Altura desejada. | Número na unidade definida em Init (mm, cm, pt ou in); 0 (padrão) calcula a partir da largura, mantendo a proporção | `0` |
| `pType` | VARCHAR2 | Formato da imagem. | 'PNG', 'JPG'/'JPEG' ou NULL (padrão) para autodetecção | `null` |
| `pLink` | VARCHAR2 | Torna a imagem clicável. | URL ou identificador de AddLink; NULL = sem link | `null` |

#### Exemplo

```sql
PL_FPDF.Image(
  pFile   => 'logo.png',
  pX      => 10, pY => 10,
  pWidth  => 40,
  pHeight => 0,                     -- proporcional à largura
  pLink   => 'https://msbrasil.inf.br');
```

**Veja também:** [getImageFromUrl](#getimagefromurl), [OverlayImage](#overlayimage)

---

## Links

### AddLink

Cria um link interno (ainda sem destino) e retorna seu identificador, usado depois em SetLink e nas APIs de texto.

#### Sintaxe

```sql
FUNCTION PL_FPDF.AddLink
    RETURN NUMBER;
```

#### Retorno

NUMBER — identificador do link.

#### Exemplo

```sql
l_link := PL_FPDF.AddLink;
PL_FPDF.SetLink(l_link, 0, 3);
PL_FPDF.Cell(60, 8, 'Ir ao capítulo 3', plink => l_link);
```

**Veja também:** [SetLink](#setlink), [Link](#link)

---

### Link

Cria uma área retangular clicável em qualquer região da página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Link(
    px    number,
    py    number,
    pw    number,
    ph    number,
    plink varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `px` | NUMBER | X do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `py` | NUMBER | Y do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `pw` | NUMBER | Largura da área. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `ph` | NUMBER | Altura da área. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `plink` | VARCHAR2 | Destino. | URL ('https://…') ou identificador de AddLink | — |

**Veja também:** [AddLink](#addlink), [SetLink](#setlink)

---

### SetLink

Define o destino de um link interno criado por AddLink.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLink(
    plink number,
    py    number DEFAULT 0,
    ppage number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `plink` | NUMBER | Identificador do link. | Valor retornado por AddLink | — |
| `py` | NUMBER | Posição vertical de destino na página. | Número na unidade definida em Init (mm, cm, pt ou in); 0 (padrão) = topo da página | `0` |
| `ppage` | NUMBER | Página de destino. | Número da página; -1 (padrão) = página corrente | `-1` |

**Veja também:** [AddLink](#addlink)

---

## Cabeçalho e rodapé

### Footer

Ponto de extensão do rodapé, chamado internamente ao fechar cada página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Footer;
```

**Veja também:** [SetFooterProc](#setfooterproc)

---

### Header

Ponto de extensão do cabeçalho, chamado internamente a cada nova página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Header;
```

**Veja também:** [SetHeaderProc](#setheaderproc)

---

### SetAliasNbPages

Define o marcador que será substituído pelo total de páginas ao finalizar o documento — permite escrever 'Página 2 de 10' sem saber o total antecipadamente.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetAliasNbPages(
    palias varchar2 DEFAULT '{nb}');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `palias` | VARCHAR2 | Marcador a substituir. | Qualquer texto; '{nb}' é o padrão | `'{nb}'` |

#### Exemplo

```sql
PL_FPDF.SetAliasNbPages;   -- habilita '{nb}'
PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || ' de {nb}', 0, 0, 'C');
```

**Veja também:** [PageNo](#pageno)

---

### SetFooterProc

Registra uma procedure sua para ser executada automaticamente no rodapé de cada página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFooterProc(
    footerprocname varchar2,
    paramTable     tv4000a DEFAULT noParam);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `footerprocname` | VARCHAR2 | Nome qualificado da procedure. | 'pacote.procedure' ou 'procedure' | — |
| `paramTable` | TV4000A | Parâmetros repassados à procedure. | Coleção tv4000a; noParam (padrão) = sem parâmetros | `noParam` |

#### Exemplo

```sql
-- procedure sua:
--   PL_FPDF.SetY(-15);
--   PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
PL_FPDF.SetFooterProc('meu_pkg.rodape');
PL_FPDF.SetAliasNbPages;
```

**Veja também:** [SetHeaderProc](#setheaderproc), [SetAliasNbPages](#setaliasnbpages), [Footer](#footer)

---

### SetHeaderProc

Registra uma procedure sua para ser executada automaticamente no início de cada página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetHeaderProc(
    headerprocname varchar2,
    paramTable     tv4000a DEFAULT noParam);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `headerprocname` | VARCHAR2 | Nome qualificado da procedure. | 'pacote.procedure' ou 'procedure'; deve ser acessível ao usuário do banco | — |
| `paramTable` | TV4000A | Parâmetros repassados à procedure. | Coleção tv4000a com até os valores esperados pela sua procedure; noParam (padrão) = sem parâmetros | `noParam` |

#### Exemplo

```sql
PL_FPDF.SetHeaderProc('meu_pkg.cabecalho', tv4000a('Relatório Mensal', 'Ago/2026'));
```

**Veja também:** [SetFooterProc](#setfooterproc), [Header](#header)

---

## QR Code e código de barras

### AddBarcode

Desenha um código de barras linear na página corrente, com texto legível opcional.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_x` | NUMBER | X do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_y` | NUMBER | Y do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_width` | NUMBER | Largura total do código. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_height` | NUMBER | Altura das barras. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_code` | VARCHAR2 | Dado a codificar. | Deve respeitar o padrão escolhido: EAN13 = 13 dígitos, EAN8 = 8 dígitos, ITF14 = 14 dígitos, CODE39 = alfanumérico maiúsculo, CODE128 = ASCII | — |
| `p_type` | VARCHAR2 | Simbologia do código de barras. | 'CODE128' (padrão), 'CODE39', 'EAN13', 'EAN8' ou 'ITF14' | `'CODE128'` |
| `p_show_text` | BOOLEAN | Imprime o valor legível abaixo das barras. | TRUE ou FALSE; TRUE é o padrão | `true` |

#### Exemplo

```sql
PL_FPDF.AddBarcode(
  p_x => 30, p_y => 70, p_width => 150, p_height => 20,
  p_code      => '7891234567895',
  p_type      => 'EAN13',
  p_show_text => TRUE);
```

**Veja também:** [AddQRCode](#addqrcode)

---

### AddQRCode

Desenha um QR Code na página corrente, com formato de conteúdo e nível de correção de erros configuráveis.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddQRCode(
    p_x                number,
    p_y                number,
    p_size             number,
    p_data             varchar2,
    p_format           varchar2 DEFAULT 'TEXT',
    p_error_correction varchar2 DEFAULT 'M');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_x` | NUMBER | X do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_y` | NUMBER | Y do canto superior esquerdo. | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_size` | NUMBER | Lado do QR Code (largura = altura). | Número na unidade definida em Init (mm, cm, pt ou in) | — |
| `p_data` | VARCHAR2 | Conteúdo a codificar. | Até 2953 bytes em modo binário; o conteúdo deve seguir o formato escolhido em p_format | — |
| `p_format` | VARCHAR2 | Formato do conteúdo, que define como leitores interpretam o código. | 'TEXT' (padrão, texto livre), 'URL', 'PIX', 'VCARD', 'WIFI' ou 'EMAIL' | `'TEXT'` |
| `p_error_correction` | VARCHAR2 | Nível de correção de erros: quanto maior, mais o código resiste a sujeira e dobras, porém menos dados cabem. | 'L' (7%), 'M' (15%, padrão), 'Q' (25%) ou 'H' (30%) | `'M'` |

#### Exemplo

```sql
PL_FPDF.AddQRCode(
  p_x => 150, p_y => 20, p_size => 40,
  p_data             => 'https://msbrasil.inf.br',
  p_format           => 'URL',
  p_error_correction => 'M');
```

**Veja também:** [AddBarcode](#addbarcode)

---

## Metadados e configuração

### GetDocumentMetadata

Retorna os metadados atualmente definidos no documento.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetDocumentMetadata
    RETURN JSON_OBJECT_T;
```

#### Retorno

JSON_OBJECT_T — objeto com title, subject, author, keywords, creator e demais opções.

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### GetPageInfo

Retorna as informações de uma página do documento em construção.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPageInfo(
    p_page_number pls_integer DEFAULT null)
    RETURN JSON_OBJECT_T;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página consultada. | Inteiro ≥ 1, até GetPageCount; NULL (padrão) = página corrente | `null` |

#### Retorno

JSON_OBJECT_T — largura, altura, orientação e rotação da página.

**Veja também:** [GetCurrentPage](#getcurrentpage), [GetPDFInfo](#getpdfinfo)

---

### SetAuthor

Define o autor do documento nos metadados.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetAuthor(
    pauthor varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pauthor` | VARCHAR2 | Autor. | Qualquer VARCHAR2 | — |

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetCompression

Liga ou desliga a compressão do conteúdo do PDF (arquivos menores).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetCompression(
    p_compress boolean DEFAULT false);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_compress` | BOOLEAN | Ativa a compressão. | TRUE ou FALSE; FALSE é o padrão | `false` |

---

### SetCreator

Define o aplicativo criador do documento nos metadados.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetCreator(
    pcreator varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pcreator` | VARCHAR2 | Nome do sistema gerador. | Qualquer VARCHAR2 | — |

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetDisplayMode

Define como o leitor de PDF deve exibir o documento ao abri-lo.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDisplayMode(
    zoom   varchar2,
    layout varchar2 DEFAULT 'continuous');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `zoom` | VARCHAR2 | Nível de zoom inicial. | 'fullpage' (página inteira), 'fullwidth' (largura da página), 'real' (100%), 'default' ou um número representando a porcentagem | — |
| `layout` | VARCHAR2 | Disposição das páginas. | 'continuous' (padrão), 'single', 'two' ou 'default' | `'continuous'` |

#### Exemplo

```sql
PL_FPDF.SetDisplayMode(zoom => 'fullpage', layout => 'single');
```

---

### SetDocumentConfig

Define vários metadados e opções do documento de uma só vez, a partir de um objeto JSON.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDocumentConfig(
    p_config JSON_OBJECT_T);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_config` | JSON_OBJECT_T | Configuração do documento. | JSON_OBJECT_T com as chaves opcionais: title, subject, author, keywords, creator, compression (boolean) | — |

#### Exemplo

```sql
PL_FPDF.SetDocumentConfig(
  JSON_OBJECT_T('{"title":"Relatório Mensal","author":"M&S do Brasil","compression":true}'));
```

**Veja também:** [GetDocumentMetadata](#getdocumentmetadata), [SetTitle](#settitle)

---

### SetKeywords

Define as palavras-chave do documento (auxiliam buscas e indexação).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetKeywords(
    pkeywords varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pkeywords` | VARCHAR2 | Palavras-chave. | Texto livre, normalmente separado por vírgulas | — |

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetSubject

Define o assunto do documento nos metadados.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetSubject(
    psubject varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `psubject` | VARCHAR2 | Assunto. | Qualquer VARCHAR2 | — |

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetTitle

Define o título do documento (exibido na barra do leitor de PDF).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetTitle(
    ptitle varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `ptitle` | VARCHAR2 | Título. | Qualquer VARCHAR2 | — |

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

## Saída do documento

### ClosePDF

Fecha a estrutura do documento (uso avançado; as APIs de saída já fazem isso).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClosePDF;
```

**Veja também:** [OutputBlob](#outputblob)

---

### OpenPDF

Abre explicitamente a estrutura do documento (uso avançado; Init já faz isso).

#### Sintaxe

```sql
PROCEDURE PL_FPDF.OpenPDF;
```

**Veja também:** [Init](#init)

---

### Output

Saída no estilo FPDF clássico (compatibilidade). Prefira OutputBlob ou OutputFile.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Output(
    pname varchar2 DEFAULT null,
    pdest varchar2 DEFAULT null);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pname` | VARCHAR2 | Nome do arquivo/documento. | Qualquer VARCHAR2 | `null` |
| `pdest` | VARCHAR2 | Destino. | 'S', 'D', 'I' ou 'F' | `null` |

**Veja também:** [OutputBlob](#outputblob), [OutputFile](#outputfile)

---

### OutputBlob

Sinônimo de OutputBlob: finaliza o documento e retorna o PDF como BLOB.

#### Sintaxe

```sql
FUNCTION PL_FPDF.OutputBlob
    RETURN BLOB;
```

#### Retorno

BLOB — conteúdo do PDF.

**Veja também:** [OutputBlob](#outputblob)

---

### OutputFile

Finaliza o documento e grava o PDF diretamente em um arquivo no servidor de banco de dados.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.OutputFile(
    p_filename  varchar2,
    p_directory varchar2 DEFAULT 'PDF_DIR');
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_filename` | VARCHAR2 | Nome do arquivo de saída. | Ex.: 'relatorio.pdf' | — |
| `p_directory` | VARCHAR2 | DIRECTORY do Oracle com permissão de escrita. | Padrão: 'PDF_DIR' | `'PDF_DIR'` |

#### Exemplo

```sql
PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
```

**Veja também:** [OutputBlob](#outputblob)

---

### ReturnBlob

Retorna o PDF como BLOB (compatibilidade com código legado). Prefira OutputBlob.

#### Sintaxe

```sql
FUNCTION PL_FPDF.ReturnBlob(
    pname varchar2 DEFAULT null,
    pdest varchar2 DEFAULT null)
    RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pname` | VARCHAR2 | Nome lógico do documento. | Qualquer VARCHAR2; NULL = sem nome | `null` |
| `pdest` | VARCHAR2 | Destino no estilo FPDF. | 'S' (string/BLOB), 'D' (download), 'I' (inline), 'F' (arquivo) | `null` |

#### Retorno

BLOB — conteúdo do PDF.

**Veja também:** [OutputBlob](#outputblob)

---

## Manipulação de PDF existente

### AddWatermark

Aplica uma marca d'água de texto sobre as páginas do PDF carregado, com opacidade, rotação e abrangência configuráveis.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_text` | VARCHAR2 | Texto da marca d'água. | Qualquer VARCHAR2, ex.: 'CONFIDENCIAL' | — |
| `p_opacity` | NUMBER | Opacidade da marca. | 0.0 (invisível) a 1.0 (opaca); 0.3 é o padrão | `0.3` |
| `p_rotation` | NUMBER | Ângulo do texto em graus. | 0 a 360; 45 (diagonal) é o padrão | `45` |
| `p_pages` | VARCHAR2 | Páginas que recebem a marca. | 'ALL' (padrão) ou lista/intervalos como '1', '1,3,5', '2-8', '1,3-5,10' | `'ALL'` |
| `p_font` | VARCHAR2 | Fonte usada. | 'Helvetica' (padrão), 'Arial', 'Times' ou 'Courier' | `'Helvetica'` |
| `p_size` | NUMBER | Tamanho da fonte em pontos. | Número > 0; 48 é o padrão | `48` |
| `p_color` | VARCHAR2 | Cor da marca d'água. | 'gray' (padrão), 'red', 'blue', 'green', 'black' ou hexadecimal RGB como 'FF0000' | `'gray'` |

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |

#### Exemplo

```sql
PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.AddWatermark(
  p_text     => 'CONFIDENCIAL',
  p_opacity  => 0.3,
  p_rotation => 45,
  p_pages    => 'ALL',
  p_size     => 48,
  p_color    => 'gray');
l_pdf := PL_FPDF.OutputModifiedPDF();
```

**Veja também:** [GetWatermarks](#getwatermarks), [OverlayText](#overlaytext), [OutputModifiedPDF](#outputmodifiedpdf)

---

### ClearPDFCache

Descarta os PDFs carregados e libera a memória usada pela manipulação.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClearPDFCache;
```

**Veja também:** [LoadPDF](#loadpdf), [UnloadPDF](#unloadpdf)

---

### GetActivePageCount

Retorna quantas páginas restarão após as remoções pendentes.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetActivePageCount
    RETURN PLS_INTEGER;
```

#### Retorno

PLS_INTEGER — páginas não marcadas para remoção.

**Veja também:** [RemovePage](#removepage), [GetPageCount](#getpagecount)

---

### GetPageCount

Retorna o total de páginas do PDF carregado (incluindo as marcadas para remoção).

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPageCount
    RETURN PLS_INTEGER;
```

#### Retorno

PLS_INTEGER — número de páginas.

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |

**Veja também:** [LoadPDF](#loadpdf), [GetActivePageCount](#getactivepagecount)

---

### GetPDFInfo

Retorna informações do PDF carregado: versão, metadados e contagem de páginas.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPDFInfo
    RETURN JSON_OBJECT_T;
```

#### Retorno

JSON_OBJECT_T — versão do PDF, título, autor, número de páginas e demais metadados.

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |

**Veja também:** [LoadPDF](#loadpdf), [GetPageInfo](#getpageinfo)

---

### GetWatermarks

Lista todas as marcas d'água aplicadas ao PDF carregado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetWatermarks
    RETURN JSON_ARRAY_T;
```

#### Retorno

JSON_ARRAY_T — objetos com id, text, opacity, rotation, pageRange, font, fontSize e color.

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |

**Veja também:** [AddWatermark](#addwatermark)

---

### IsPageRemoved

Indica se uma página está marcada para remoção.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsPageRemoved(
    p_page_number PLS_INTEGER)
    RETURN BOOLEAN;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página consultada. | Inteiro ≥ 1, até GetPageCount | — |

#### Retorno

BOOLEAN — TRUE se a página será removida na saída.

**Veja também:** [RemovePage](#removepage)

---

### IsPDFModified

Indica se há alterações pendentes (rotação, remoção, marca d'água, overlay) no PDF carregado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsPDFModified
    RETURN BOOLEAN;
```

#### Retorno

BOOLEAN — TRUE se existem modificações não aplicadas.

**Veja também:** [OutputModifiedPDF](#outputmodifiedpdf)

---

### LoadPDF

Carrega um PDF existente na memória da sessão para leitura e modificação. É o ponto de partida de todo o fluxo de manipulação, encerrado por OutputModifiedPDF.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.LoadPDF(
    p_pdf_blob BLOB);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_blob` | BLOB | Documento PDF a carregar. | BLOB não nulo, com cabeçalho %PDF válido | — |

#### Erros

| Código | Condição |
|--------|----------|
| `-20800` | PDF inválido (NULL ou muito pequeno) |
| `-20801` | Cabeçalho PDF inválido |
| `-20802` | startxref não encontrado |
| `-20803` | Tabela xref inválida |
| `-20804` | Objeto Root não encontrado no trailer |

#### Exemplo

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_content INTO l_pdf FROM documentos WHERE id = 123;
  PL_FPDF.LoadPDF(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Páginas: ' || PL_FPDF.GetPageCount());
END;
```

**Veja também:** [LoadPDFWithID](#loadpdfwithid), [GetPageCount](#getpagecount), [OutputModifiedPDF](#outputmodifiedpdf), [ClearPDFCache](#clearpdfcache)

---

### OutputModifiedPDF

Aplica todas as modificações pendentes (rotações, remoções, marcas d'água e overlays) e retorna o PDF resultante.

#### Sintaxe

```sql
FUNCTION PL_FPDF.OutputModifiedPDF
    RETURN BLOB;
```

#### Retorno

BLOB — PDF modificado.

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |

#### Exemplo

```sql
l_pdf := PL_FPDF.OutputModifiedPDF();
```

**Veja também:** [LoadPDF](#loadpdf), [ClearPDFCache](#clearpdfcache)

---

### RemovePage

Marca uma página do PDF carregado para remoção. A exclusão é lógica: só é aplicada em OutputModifiedPDF.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.RemovePage(
    p_page_number PLS_INTEGER);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página a remover. | Inteiro ≥ 1, até GetPageCount | — |

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |
| `-20810` | Número de página inválido |

**Veja também:** [IsPageRemoved](#ispageremoved), [GetActivePageCount](#getactivepagecount), [OutputModifiedPDF](#outputmodifiedpdf)

---

### RotatePage

Rotaciona uma página do PDF carregado.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.RotatePage(
    p_page_number PLS_INTEGER,
    p_rotation    NUMBER);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página a rotacionar. | Inteiro ≥ 1, até GetPageCount | — |
| `p_rotation` | NUMBER | Ângulo de rotação aplicado. | 0, 90, 180 ou 270 | — |

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |
| `-20810` | Número de página inválido |

#### Exemplo

```sql
PL_FPDF.RotatePage(p_page_number => 1, p_rotation => 90);
```

**Veja também:** [LoadPDF](#loadpdf), [RemovePage](#removepage), [OutputModifiedPDF](#outputmodifiedpdf)

---

## Overlays

### ClearOverlays

Remove todas as sobreposições, de uma página específica ou de todo o documento.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClearOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página a limpar. | Inteiro ≥ 1, até GetPageCount; NULL (padrão) limpa todas as páginas | `NULL` |

**Veja também:** [RemoveOverlay](#removeoverlay), [GetOverlays](#getoverlays)

---

### GetOverlays

Lista as sobreposições aplicadas, opcionalmente filtrando por página.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL)
    RETURN JSON_ARRAY_T;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Filtro de página. | Inteiro ≥ 1, até GetPageCount; NULL (padrão) retorna as de todas as páginas | `NULL` |

#### Retorno

JSON_ARRAY_T — objetos com overlayId, overlayType ('TEXT' ou 'IMAGE'), pageNumber, x, y, content, opacity, rotation e zOrder.

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |

**Veja também:** [OverlayText](#overlaytext), [RemoveOverlay](#removeoverlay)

---

### OverlayImage

Sobrepõe uma imagem em posição exata de uma página do PDF carregado — logotipos, assinaturas digitalizadas e selos.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página que recebe a imagem. | Inteiro ≥ 1, até GetPageCount | — |
| `p_image_blob` | BLOB | Conteúdo da imagem. | BLOB em formato JPEG ou PNG | — |
| `p_x` | NUMBER | Posição X em pontos PDF. | 0 a 612 em A4 retrato | — |
| `p_y` | NUMBER | Posição Y em pontos PDF (da base). | 0 a 792 em A4 retrato | — |
| `p_width` | NUMBER | Largura em pontos. | Número > 0; NULL (padrão) usa a largura original | `NULL` |
| `p_height` | NUMBER | Altura em pontos. | Número > 0; NULL (padrão) usa a altura original ou mantém a proporção | `NULL` |
| `p_options` | JSON_OBJECT_T | Configurações da imagem. | JSON_OBJECT_T com as chaves opcionais: opacity (0.0–1.0), rotation (0–360), maintainAspect (true/false), scaleToFit (true/false), zOrder (inteiro) | `NULL` |

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |
| `-20810` | Número de página inválido |
| `-20821` | Coordenadas inválidas |
| `-20823` | Formato de imagem inválido (use JPEG ou PNG) |
| `-20824` | Dimensões de imagem inválidas |

#### Exemplo

```sql
PL_FPDF.OverlayImage(
  p_page_number => 1,
  p_image_blob  => l_logo,
  p_x => 450, p_y => 750,
  p_width => 100, p_height => NULL,
  p_options => JSON_OBJECT_T('{"opacity":0.9,"maintainAspect":true}'));
```

**Veja também:** [OverlayText](#overlaytext), [Image](#image), [GetOverlays](#getoverlays)

---

### OverlayText

Sobrepõe texto em uma posição exata de uma página do PDF carregado — carimbos, protocolos e assinaturas. As coordenadas são em pontos PDF, com Y crescendo de baixo para cima.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.OverlayText(
    p_page_number PLS_INTEGER,
    p_text        VARCHAR2,
    p_x           NUMBER,
    p_y           NUMBER,
    p_options     JSON_OBJECT_T DEFAULT NULL);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_page_number` | PLS_INTEGER | Página que recebe o texto. | Inteiro ≥ 1, até GetPageCount | — |
| `p_text` | VARCHAR2 | Texto sobreposto. | Qualquer VARCHAR2 | — |
| `p_x` | NUMBER | Posição X em pontos PDF (1 pt = 1/72 pol), a partir da esquerda. | 0 a 612 em A4 retrato | — |
| `p_y` | NUMBER | Posição Y em pontos PDF, a partir da base da página. | 0 a 792 em A4 retrato | — |
| `p_options` | JSON_OBJECT_T | Configurações visuais do texto. | JSON_OBJECT_T com as chaves opcionais: font ('Helvetica', 'Arial', 'Times', 'Courier'), fontSize (número, 12), color (hexadecimal RGB, '000000'), opacity (0.0–1.0), rotation (0–360), align ('left', 'center', 'right'), width (número para quebra automática), bold (true/false), zOrder (inteiro; maior fica por cima) | `NULL` |

#### Erros

| Código | Condição |
|--------|----------|
| `-20809` | Nenhum PDF carregado |
| `-20810` | Número de página inválido |
| `-20821` | Coordenadas de posição inválidas |

#### Exemplo

```sql
PL_FPDF.OverlayText(
  p_page_number => 1,
  p_text        => 'APROVADO',
  p_x => 400, p_y => 700,
  p_options => JSON_OBJECT_T('{"fontSize":24,"color":"FF0000","opacity":0.8,"bold":true}'));
```

**Veja também:** [OverlayImage](#overlayimage), [GetOverlays](#getoverlays), [AddWatermark](#addwatermark)

---

### RemoveOverlay

Remove uma sobreposição específica pelo seu identificador.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.RemoveOverlay(
    p_overlay_id VARCHAR2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_overlay_id` | VARCHAR2 | Identificador da sobreposição. | Valor overlayId retornado por GetOverlays, ex.: 'OVL_001' | — |

**Veja também:** [GetOverlays](#getoverlays), [ClearOverlays](#clearoverlays)

---

## Multi-PDF (merge, split, extract)

### ExtractPages

Cria um novo PDF contendo apenas as páginas selecionadas de um documento carregado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.ExtractPages(
    p_pdf_id  VARCHAR2,
    p_pages   VARCHAR2,
    p_options JSON_OBJECT_T DEFAULT NULL)
    RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identificador do documento de origem. | O mesmo usado em LoadPDFWithID | — |
| `p_pages` | VARCHAR2 | Páginas a extrair. | Lista e intervalos separados por vírgula, ex.: '1', '1,5,9', '1,5-10,15' | — |
| `p_options` | JSON_OBJECT_T | Opções da extração. | JSON_OBJECT_T opcional; chaves reservadas para uso futuro | `NULL` |

#### Retorno

BLOB — PDF com as páginas extraídas.

#### Erros

| Código | Condição |
|--------|----------|
| `-20831` | ID do PDF não encontrado |
| `-20838` | Especificação de páginas inválida |
| `-20839` | Número de página fora do intervalo |

#### Exemplo

```sql
l_resumo := PL_FPDF.ExtractPages('corpo', '1,5-10,15');
```

**Veja também:** [SplitPDF](#splitpdf), [MergePDFs](#mergepdfs)

---

### GetLoadedPDFs

Lista os documentos atualmente carregados com identificador.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetLoadedPDFs
    RETURN JSON_ARRAY_T;
```

#### Retorno

JSON_ARRAY_T — objetos com o id e as informações de cada PDF carregado.

**Veja também:** [LoadPDFWithID](#loadpdfwithid), [UnloadPDF](#unloadpdf)

---

### LoadPDFWithID

Carrega um PDF na memória associando-o a um identificador, permitindo manter vários documentos abertos simultaneamente para mesclar, dividir ou extrair páginas.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.LoadPDFWithID(
    p_pdf_id   VARCHAR2,
    p_pdf_blob BLOB);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identificador do documento na sessão. | Texto único, ex.: 'capa', 'anexo1' | — |
| `p_pdf_blob` | BLOB | Documento a carregar. | BLOB com PDF válido | — |

#### Erros

| Código | Condição |
|--------|----------|
| `-20800` | PDF inválido |
| `-20801` | Cabeçalho PDF inválido |

#### Exemplo

```sql
PL_FPDF.LoadPDFWithID(l_capa,  'capa');
PL_FPDF.LoadPDFWithID(l_corpo, 'corpo');
```

**Veja também:** [MergePDFs](#mergepdfs), [SplitPDF](#splitpdf), [ExtractPages](#extractpages), [UnloadPDF](#unloadpdf), [GetLoadedPDFs](#getloadedpdfs)

---

### MergePDFs

Mescla vários PDFs carregados em um único documento, na ordem informada.

#### Sintaxe

```sql
FUNCTION PL_FPDF.MergePDFs(
    p_pdf_ids JSON_ARRAY_T,
    p_options JSON_OBJECT_T DEFAULT NULL)
    RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_ids` | JSON_ARRAY_T | Identificadores dos documentos, na ordem desejada. | JSON_ARRAY_T de textos, ex.: JSON_ARRAY_T('["capa","corpo","anexo"]') | — |
| `p_options` | JSON_OBJECT_T | Opções da mesclagem. | JSON_OBJECT_T opcional; chaves reservadas para uso futuro | `NULL` |

#### Retorno

BLOB — PDF resultante da mesclagem.

#### Erros

| Código | Condição |
|--------|----------|
| `-20831` | ID do PDF não encontrado |

#### Exemplo

```sql
PL_FPDF.LoadPDFWithID(l_capa,  'capa');
PL_FPDF.LoadPDFWithID(l_corpo, 'corpo');
l_final := PL_FPDF.MergePDFs(JSON_ARRAY_T('["capa","corpo"]'));
```

**Veja também:** [LoadPDFWithID](#loadpdfwithid), [SplitPDF](#splitpdf), [ExtractPages](#extractpages)

---

### SplitPDF

Divide um PDF carregado em vários documentos, conforme os intervalos de páginas informados.

#### Sintaxe

```sql
FUNCTION PL_FPDF.SplitPDF(
    p_pdf_id      VARCHAR2,
    p_page_ranges JSON_ARRAY_T)
    RETURN JSON_ARRAY_T;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identificador do documento a dividir. | O mesmo usado em LoadPDFWithID | — |
| `p_page_ranges` | JSON_ARRAY_T | Intervalos que definem cada parte gerada. | JSON_ARRAY_T de textos: '1-10', '11-20', '21-' (até o fim), '5' (página única) | — |

#### Retorno

JSON_ARRAY_T — uma entrada por parte gerada, com o intervalo e o PDF correspondente.

#### Erros

| Código | Condição |
|--------|----------|
| `-20831` | ID do PDF não encontrado |
| `-20838` | Especificação de páginas inválida |
| `-20839` | Número de página fora do intervalo |

#### Exemplo

```sql
l_partes := PL_FPDF.SplitPDF('corpo', JSON_ARRAY_T('["1-10","11-20","21-"]'));
```

**Veja também:** [ExtractPages](#extractpages), [MergePDFs](#mergepdfs)

---

### UnloadPDF

Remove da memória um documento carregado por LoadPDFWithID.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.UnloadPDF(
    p_pdf_id VARCHAR2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf_id` | VARCHAR2 | Identificador do documento. | O mesmo usado em LoadPDFWithID | — |

#### Erros

| Código | Condição |
|--------|----------|
| `-20831` | ID do PDF não encontrado |

**Veja também:** [LoadPDFWithID](#loadpdfwithid), [ClearPDFCache](#clearpdfcache)

---

## Segurança e criptografia

### DecryptPDF

Remove a proteção de um PDF criptografado, exigindo a senha correta.

#### Sintaxe

```sql
FUNCTION PL_FPDF.DecryptPDF(
    p_pdf      BLOB,
    p_password VARCHAR2)
    RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Documento criptografado. | BLOB com PDF protegido | — |
| `p_password` | VARCHAR2 | Senha de usuário ou de proprietário. | Texto correspondente a uma das senhas do documento | — |

#### Retorno

BLOB — PDF sem criptografia.

**Veja também:** [EncryptPDF](#encryptpdf), [IsEncrypted](#isencrypted)

---

### EncryptPDF

Criptografa um PDF já existente, aplicando senhas e permissões. É a forma recomendada de proteger documentos gerados ou recebidos.

#### Sintaxe

```sql
FUNCTION PL_FPDF.EncryptPDF(
    p_pdf            BLOB,
    p_user_password  VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL,
    p_permissions    JSON_OBJECT_T DEFAULT NULL,
    p_encryption     VARCHAR2 DEFAULT 'RC4-128')
    RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Documento a proteger. | BLOB com PDF válido, não criptografado | — |
| `p_user_password` | VARCHAR2 | Senha solicitada para abrir o documento. | Texto; vazio permite abrir sem senha, mantendo as restrições | — |
| `p_owner_password` | VARCHAR2 | Senha de proprietário, que permite alterar permissões. | Texto; NULL (padrão) usa a mesma senha de usuário | `NULL` |
| `p_permissions` | JSON_OBJECT_T | Permissões concedidas ao leitor. | JSON_OBJECT_T com as chaves booleanas: print, modify, copy, annotate, fill_forms, extract, assemble, print_high. Ausentes assumem o padrão restritivo | `NULL` |
| `p_encryption` | VARCHAR2 | Algoritmo de criptografia. | 'RC4-128' (padrão) ou 'RC4-40' (legado, compatível com leitores antigos) | `'RC4-128'` |

#### Retorno

BLOB — PDF criptografado.

#### Exemplo

```sql
DECLARE
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
END;
```

**Veja também:** [DecryptPDF](#decryptpdf), [IsEncrypted](#isencrypted), [SetEncryption](#setencryption), [SetPermissions](#setpermissions)

---

### GetPDFVersion

Retorna a versão de PDF configurada para a saída.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPDFVersion
    RETURN VARCHAR2;
```

#### Retorno

VARCHAR2 — versão, ex.: '1.7'.

**Veja também:** [SetPDFVersion](#setpdfversion)

---

### GetSecurityInfo

Retorna os detalhes de segurança de um PDF criptografado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetSecurityInfo(
    p_pdf BLOB)
    RETURN JSON_OBJECT_T;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Documento a inspecionar. | BLOB com PDF válido | — |

#### Retorno

JSON_OBJECT_T — algoritmo, tamanho da chave e permissões concedidas.

**Veja também:** [IsEncrypted](#isencrypted), [EncryptPDF](#encryptpdf)

---

### IsEncrypted

Verifica se um PDF está criptografado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsEncrypted(
    p_pdf BLOB)
    RETURN BOOLEAN;
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_pdf` | BLOB | Documento a verificar. | BLOB com PDF válido | — |

#### Retorno

BOOLEAN — TRUE se o documento possui criptografia.

**Veja também:** [GetSecurityInfo](#getsecurityinfo), [DecryptPDF](#decryptpdf)

---

### SetEncryption

Define a criptografia de um documento em construção; aplicada quando o PDF for finalizado por OutputBlob.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetEncryption(
    p_encryption     VARCHAR2,
    p_user_password  VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_encryption` | VARCHAR2 | Algoritmo de criptografia. | 'RC4-128' ou 'RC4-40' | — |
| `p_user_password` | VARCHAR2 | Senha de abertura. | Texto | — |
| `p_owner_password` | VARCHAR2 | Senha de proprietário. | Texto; NULL (padrão) = igual à de usuário | `NULL` |

#### Exemplo

```sql
PL_FPDF.Init; PL_FPDF.AddPage;
PL_FPDF.SetEncryption('RC4-128', 'senhaLeitura', 'senhaAdmin');
PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE);
l_pdf := PL_FPDF.OutputBlob();
```

**Veja também:** [SetPermissions](#setpermissions), [EncryptPDF](#encryptpdf)

---

### SetPDFVersion

Define a versão declarada no cabeçalho do PDF gerado.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetPDFVersion(
    p_version VARCHAR2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_version` | VARCHAR2 | Versão do arquivo PDF. | '1.4', '1.5', '1.6' ou '1.7' | — |

**Veja também:** [GetPDFVersion](#getpdfversion)

---

### SetPermissions

Define as permissões do documento em construção, aplicadas junto com a criptografia definida em SetEncryption.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_print` | BOOLEAN | Permite imprimir. | TRUE ou FALSE; TRUE é o padrão | `TRUE` |
| `p_modify` | BOOLEAN | Permite alterar o conteúdo. | TRUE ou FALSE; FALSE é o padrão | `FALSE` |
| `p_copy` | BOOLEAN | Permite copiar texto e imagens. | TRUE ou FALSE; FALSE é o padrão | `FALSE` |
| `p_annotate` | BOOLEAN | Permite adicionar comentários e anotações. | TRUE ou FALSE; TRUE é o padrão | `TRUE` |
| `p_fill_forms` | BOOLEAN | Permite preencher campos de formulário. | TRUE ou FALSE; TRUE é o padrão | `TRUE` |
| `p_extract` | BOOLEAN | Permite extrair conteúdo para acessibilidade. | TRUE ou FALSE; FALSE é o padrão | `FALSE` |
| `p_assemble` | BOOLEAN | Permite inserir, remover e girar páginas. | TRUE ou FALSE; FALSE é o padrão | `FALSE` |
| `p_print_high` | BOOLEAN | Permite impressão em alta resolução. | TRUE ou FALSE; TRUE é o padrão | `TRUE` |

#### Exemplo

```sql
PL_FPDF.SetPermissions(
  p_print  => TRUE,
  p_copy   => FALSE,
  p_modify => FALSE);
```

**Veja também:** [SetEncryption](#setencryption), [EncryptPDF](#encryptpdf)

---

## Diagnóstico e utilidades

### DebugDisabled

Desativa as mensagens de depuração.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.DebugDisabled;
```

**Veja também:** [SetLogLevel](#setloglevel)

---

### DebugEnabled

Ativa as mensagens de depuração do package.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.DebugEnabled;
```

**Veja também:** [SetLogLevel](#setloglevel)

---

### Error

Levanta um erro padronizado do PL_FPDF. Uso interno e em extensões.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Error(
    pmsg varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `pmsg` | VARCHAR2 | Mensagem do erro. | Qualquer VARCHAR2 | — |

---

### GetLogLevel

Retorna o nível de log configurado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetLogLevel
    RETURN PLS_INTEGER;
```

#### Retorno

PLS_INTEGER — nível atual (0 a 4).

**Veja também:** [SetLogLevel](#setloglevel)

---

### GetScaleFactor

Retorna o fator de conversão entre a unidade do documento e pontos PDF.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetScaleFactor
    RETURN NUMBER;
```

#### Retorno

NUMBER — fator de escala (ex.: 2.8346 para milímetros).

**Veja também:** [Init](#init)

---

### helloworld

Gera um PDF mínimo de demonstração — útil para validar a instalação.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.helloworld;
```

#### Exemplo

```sql
PL_FPDF.helloworld;
```

**Veja também:** [Init](#init)

---

### SetLogLevel

Define o nível de detalhamento das mensagens de log do package.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLogLevel(
    p_level pls_integer);
```

#### Parâmetros

| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |
|-----------|------|-----------|-------------------|--------|
| `p_level` | PLS_INTEGER | Nível de log. | 0 (desligado), 1 (erro), 2 (aviso), 3 (info) ou 4 (debug) | — |

**Veja também:** [GetLogLevel](#getloglevel), [DebugEnabled](#debugenabled)

---
