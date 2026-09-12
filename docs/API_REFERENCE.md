# PL_FPDF — Referência da API

**Versão:** 3.4.0 | **Oracle:** 19c+ | **Licença:** MIT

Documentação de cada função e procedure pública: sintaxe, parâmetros, retorno,
erros levantados e exemplo.

> **Página gerada** do Javadoc de `src/PL_FPDF.pks`.
> Não edite aqui: corrija o bloco na spec e rode o gerador.

> Guia de uso por tarefa: [DOCUMENTATION.md](DOCUMENTATION.md) · API Reference (English): [API_REFERENCE_EN.md](API_REFERENCE_EN.md)

## Índice

**Ciclo de vida** — [fpdf](#fpdf) · [Init](#init) · [IsInitialized](#isinitialized) · [Reset](#reset)  
**Páginas e posicionamento** — [AcceptPageBreak](#acceptpagebreak) · [AddPage](#addpage) · [GetCurrentPage](#getcurrentpage) · [GetX](#getx) · [GetY](#gety) · [Ln](#ln) · [PageNo](#pageno) · [SetAutoPageBreak](#setautopagebreak) · [SetLeftMargin](#setleftmargin) · [SetMargins](#setmargins) · [SetPage](#setpage) · [SetRightMargin](#setrightmargin) · [SetTopMargin](#settopmargin) · [SetX](#setx) · [SetXY](#setxy) · [SetY](#sety)  
**Fontes e UTF-8** — [AddFont](#addfont) · [AddTTFFont](#addttffont) · [ClearTTFFontCache](#clearttffontcache) · [GetTTFFontInfo](#getttffontinfo) · [IsTTFFontLoaded](#isttffontloaded) · [LoadTTFFromFile](#loadttffromfile) · [SetFont](#setfont) · [SetFontSize](#setfontsize) · [UTF8ToPDFString](#utf8topdfstring)  
**Escrita de texto** — [Cell](#cell) · [CellRotated](#cellrotated) · [GetCurrentFontFamily](#getcurrentfontfamily) · [GetCurrentFontSize](#getcurrentfontsize) · [GetCurrentFontStyle](#getcurrentfontstyle) · [GetLineSpacing](#getlinespacing) · [GetStringWidth](#getstringwidth) · [MultiCell](#multicell) · [SetLineSpacing](#setlinespacing) · [Text](#text) · [Write](#write) · [WriteRotated](#writerotated)  
**Cores e desenho** — [Line](#line) · [Poly](#poly) · [Rect](#rect) · [SetDash](#setdash) · [SetDrawColor](#setdrawcolor) · [SetFillColor](#setfillcolor) · [SetLineDashPattern](#setlinedashpattern) · [SetLineWidth](#setlinewidth) · [SetTextColor](#settextcolor) · [Triangle](#triangle)  
**Imagens** — [getImageFromUrl](#getimagefromurl) · [image](#image) · [ImageFromBlob](#imagefromblob)  
**Links** — [AddLink](#addlink) · [Link](#link) · [SetLink](#setlink)  
**Cabeçalho e rodapé** — [Footer](#footer) · [Header](#header) · [SetAliasNbPages](#setaliasnbpages) · [SetFooterProc](#setfooterproc) · [SetHeaderProc](#setheaderproc)  
**QR Code e código de barras** — [AddBarcode](#addbarcode) · [AddQRCode](#addqrcode)  
**Metadados e configuração** — [GetDocumentMetadata](#getdocumentmetadata) · [GetPageInfo](#getpageinfo) · [SetAuthor](#setauthor) · [SetCompression](#setcompression) · [SetCreator](#setcreator) · [SetDisplayMode](#setdisplaymode) · [SetDocumentConfig](#setdocumentconfig) · [SetKeywords](#setkeywords) · [SetSubject](#setsubject) · [SetTitle](#settitle)  
**Saída do documento** — [ClosePDF](#closepdf) · [OpenPDF](#openpdf) · [Output](#output) · [OutputBlob](#outputblob) · [OutputFile](#outputfile) · [ReturnBlob](#returnblob)  
**Manipulação de PDF existente** — [AddWatermark](#addwatermark) · [ClearPDFCache](#clearpdfcache) · [FlateDecode](#flatedecode) · [FlateEncode](#flateencode) · [GetActivePageCount](#getactivepagecount) · [GetPageCount](#getpagecount) · [GetPDFInfo](#getpdfinfo) · [GetWatermarks](#getwatermarks) · [IsPageRemoved](#ispageremoved) · [IsPDFModified](#ispdfmodified) · [LoadPDF](#loadpdf) · [OutputModifiedPDF](#outputmodifiedpdf) · [RemovePage](#removepage) · [RotatePage](#rotatepage)  
**Overlays** — [ClearOverlays](#clearoverlays) · [GetOverlays](#getoverlays) · [OverlayImage](#overlayimage) · [OverlayText](#overlaytext) · [RemoveOverlay](#removeoverlay)  
**Multi-PDF (merge, split, extract)** — [ExtractPages](#extractpages) · [GetLoadedPDFs](#getloadedpdfs) · [LoadPDFWithID](#loadpdfwithid) · [MergePDFs](#mergepdfs) · [SplitPDF](#splitpdf) · [UnloadPDF](#unloadpdf)  
**Segurança e criptografia** — [DecryptPDF](#decryptpdf) · [EncryptPDF](#encryptpdf) · [GetPDFVersion](#getpdfversion) · [GetSecurityInfo](#getsecurityinfo) · [IsEncrypted](#isencrypted) · [SetEncryption](#setencryption) · [SetPDFVersion](#setpdfversion) · [SetPermissions](#setpermissions)  
**Diagnóstico e utilidades** — [DebugDisabled](#debugdisabled) · [DebugEnabled](#debugenabled) · [Error](#error) · [GetLogLevel](#getloglevel) · [GetScaleFactor](#getscalefactor) · [SetLogLevel](#setloglevel)  

---

## Ciclo de vida

### fpdf

Construtor herdado do FPDF original. Continua valendo, e o código escrito para as versões 0.9.4 e 2.0.0 segue rodando com ele. Em código novo prefira Init, que valida os argumentos e levanta erro nomeado em vez de seguir com um valor inesperado.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.fpdf(
    orientation varchar2 DEFAULT 'P',
    unit        varchar2 DEFAULT 'mm',
    format      varchar2 DEFAULT 'A4');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `orientation` | VARCHAR2 | `'P'` | 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem) |
| `unit` | VARCHAR2 | `'mm'` | unidade de medida ('mm','cm','in','pt') |
| `format` | VARCHAR2 | `'A4'` | formato da página ('A4', 'Letter'...) |

#### Exemplo

```sql
PL_FPDF.fpdf('L', 'mm', 'A4');
```

**Veja também:** [Init](#init)

---

### Init

Prepara o gerador para um documento novo. Substitui o construtor legado fpdf(), acrescentando validação dos argumentos e os buffers em CLOB. Chamar de novo com um documento em andamento descarta o anterior.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Init(
    p_orientation varchar2 DEFAULT 'P',
    p_unit        varchar2 DEFAULT 'mm',
    p_format      varchar2 DEFAULT 'A4',
    p_encoding    varchar2 DEFAULT 'UTF-8');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_orientation` | VARCHAR2 | `'P'` | orientação da página: 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem) |
| `p_unit` | VARCHAR2 | `'mm'` | unidade de medida ('mm', 'cm', 'in', 'pt') |
| `p_format` | VARCHAR2 | `'A4'` | formato da página ('A4', 'Letter', 'Legal') |
| `p_encoding` | VARCHAR2 | `'UTF-8'` | codificação de entrada |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20001` | orientação inválida |
| `ORA-20002` | unidade de medida inválida |
| `ORA-20003` | codificação não suportada |

#### Exemplo

```sql
PL_FPDF.Init('P', 'mm', 'A4');
```

**Veja também:** [Reset](#reset) · [IsInitialized](#isinitialized) · [AddPage](#addpage)

---

### IsInitialized

Diz se Init (ou fpdf) já foi chamado nesta sessão.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsInitialized RETURN BOOLEAN;
```

#### Retorno

BOOLEAN - TRUE se inicializado

#### Exemplo

```sql
IF NOT PL_FPDF.IsInitialized THEN PL_FPDF.Init; END IF;
```

**Veja também:** [Init](#init)

---

### Reset

Devolve o package ao estado inicial: libera os CLOBs temporários e esvazia todas as tabelas de estado (fontes, imagens, links, metadados, mudanças de orientação). O package tem estado de sessão, e quem gera documentos em lote precisa chamar isto entre um e outro — sem isso, a configuração de um vaza para o seguinte.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Reset;
```

#### Exemplo

```sql
PL_FPDF.Reset;
```

**Veja também:** [Init](#init) · [ClearPDFCache](#clearpdfcache)

---

## Páginas e posicionamento

### AcceptPageBreak

Diz se a quebra automática está ligada. É consultada pelo Cell antes de decidir abrir página nova.

#### Sintaxe

```sql
FUNCTION PL_FPDF.AcceptPageBreak RETURN BOOLEAN;
```

#### Retorno

BOOLEAN - TRUE se a quebra automática está ligada

#### Exemplo

```sql
IF PL_FPDF.AcceptPageBreak THEN ... END IF;
```

**Veja também:** [SetAutoPageBreak](#setautopagebreak)

---

### AddPage

Fecha a página corrente, executando o rodapé, e abre outra, executando o cabeçalho. Orientação e formato em branco repetem os da página anterior. Além dos formatos com nome, aceita 'largura,altura' na unidade corrente.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddPage(
    p_orientation varchar2 DEFAULT null,
    p_format      varchar2 DEFAULT null,
    p_rotation    pls_integer DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_orientation` | VARCHAR2 | `null` | 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem); NULL mantém a da página anterior |
| `p_format` | VARCHAR2 | `null` | 'A4', 'Letter', 'Legal', ou 'largura,altura'; NULL mantém o anterior |
| `p_rotation` | PLS_INTEGER | `0` | giro da página em graus (0, 90, 180, 270) |

#### Nota

O NOME do primeiro parâmetro mudou entre versões -- era 'orientation' na 2.0.0 e hoje é 'p_orientation'. Quem chama por posição (AddPage('L')) não sente nada; quem chama por nome (AddPage(orientation => 'L')) precisa acertar o nome. Não há como aceitar os dois: sobrecargas que diferem só pelo nome do parâmetro deixam a chamada ambígua, e o Oracle recusa com PLS-00307. Quem chama por posição não é afetado.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20005` | Init ainda não foi chamado |
| `ORA-20107` | orientação inválida |
| `ORA-20103` | formato desconhecido |
| `ORA-20101` | dimensões inválidas no formato livre |
| `ORA-20104` | giro inválido |

#### Exemplo

```sql
PL_FPDF.AddPage;
PL_FPDF.AddPage('L');
PL_FPDF.AddPage('P', '210,297', 90);
```

**Veja também:** [Init](#init) · [SetPage](#setpage) · [GetCurrentPage](#getcurrentpage)

---

### GetCurrentPage

Devolve o número da página em que se está escrevendo.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentPage RETURN PLS_INTEGER;
```

#### Retorno

PLS_INTEGER - a página corrente

#### Exemplo

```sql
l_pagina := PL_FPDF.GetCurrentPage;
```

**Veja também:** [SetPage](#setpage) · [PageNo](#pageno)

---

### GetX

Devolve a abscissa corrente, na unidade em uso.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetX RETURN NUMBER;
```

#### Retorno

NUMBER - o x corrente

#### Exemplo

```sql
l_x := PL_FPDF.GetX;
```

**Veja também:** [SetX](#setx) · [SetXY](#setxy)

---

### GetY

Devolve a ordenada corrente, contada do topo da página.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetY RETURN NUMBER;
```

#### Retorno

NUMBER - o y corrente

#### Exemplo

```sql
l_y := PL_FPDF.GetY;
```

**Veja também:** [SetY](#sety)

---

### Ln

Vai para a linha seguinte: leva o x de volta à margem esquerda e desce o y. Sem altura, desce o da última célula escrita.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Ln(
    h number DEFAULT null);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `h` | NUMBER | `null` | quanto descer, na unidade corrente |

#### Exemplo

```sql
PL_FPDF.Cell(40, 10, 'Primeira');
PL_FPDF.Ln;
```

**Veja também:** [SetXY](#setxy)

---

### PageNo

Devolve o número da página que está sendo escrita, começando em 1.

#### Sintaxe

```sql
FUNCTION PL_FPDF.PageNo RETURN NUMBER;
```

#### Retorno

NUMBER - a página corrente

#### Exemplo

```sql
PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo);
```

**Veja também:** [SetAliasNbPages](#setaliasnbpages) · [SetFooterProc](#setfooterproc)

---

### SetAutoPageBreak

Liga ou desliga a quebra automática e define a margem de rodapé que a dispara. Desligada, o conteúdo que passar do fim da página é escrito fora dela e some -- sem erro nenhum.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetAutoPageBreak(
    pauto   boolean,
    pMargin number DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pauto` | BOOLEAN | — | ligar a quebra automática |
| `pMargin` | NUMBER | `0` | margem de rodapé que dispara |

#### Exemplo

```sql
PL_FPDF.SetAutoPageBreak(TRUE, 20);
```

**Veja também:** [AcceptPageBreak](#acceptpagebreak) · [SetMargins](#setmargins)

---

### SetLeftMargin

Define a margem esquerda. Com página já aberta e o cursor à esquerda da margem nova, o cursor é trazido para ela.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLeftMargin(
    pMargin number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pMargin` | NUMBER | — | a margem, na unidade corrente |

#### Exemplo

```sql
PL_FPDF.SetLeftMargin(25);
```

**Veja também:** [SetMargins](#setmargins)

---

### SetMargins

Define as margens esquerda, superior e direita. A direita em branco fica igual à esquerda.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetMargins(
    left  number,
    top   number,
    right number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `left` | NUMBER | — | margem esquerda |
| `top` | NUMBER | — | margem superior |
| `right` | NUMBER | `-1` | margem direita (- 1 = igual à esquerda) |

#### Exemplo

```sql
PL_FPDF.SetMargins(20, 15);
```

**Veja também:** [SetLeftMargin](#setleftmargin) · [SetTopMargin](#settopmargin) · [SetRightMargin](#setrightmargin) · [SetAutoPageBreak](#setautopagebreak)

---

### SetPage

Torna corrente uma página já criada, para escrever nela de novo. Serve para preencher depois um espaço que só se sabe no fim -- um total, por exemplo.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetPage(
    p_page_number pls_integer);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | a página, que precisa existir |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20005` | Init ainda não foi chamado |
| `ORA-20106` | a página não existe |

#### Exemplo

```sql
PL_FPDF.SetPage(1);
```

**Veja também:** [AddPage](#addpage) · [GetCurrentPage](#getcurrentpage)

---

### SetRightMargin

Define a margem direita, que é o que limita a largura de uma célula pedida com largura 0.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetRightMargin(
    pMargin number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pMargin` | NUMBER | — | a margem, na unidade corrente |

#### Exemplo

```sql
PL_FPDF.SetRightMargin(20);
```

**Veja também:** [SetMargins](#setmargins)

---

### SetTopMargin

Define a margem superior, usada pelas páginas seguintes.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetTopMargin(
    pMargin number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pMargin` | NUMBER | — | a margem, na unidade corrente |

#### Exemplo

```sql
PL_FPDF.SetTopMargin(15);
```

**Veja também:** [SetMargins](#setmargins)

---

### SetX

Move a abscissa. Valor negativo conta a partir da borda direita: SetX(-30) põe o cursor a 30 da direita.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetX(
    px number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | a nova abscissa |

#### Exemplo

```sql
PL_FPDF.SetX(-40);
```

**Veja também:** [GetX](#getx)

---

### SetXY

Move as duas coordenadas. Ao contrário do SetY sozinho, o x informado é respeitado.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetXY(
    x number,
    y number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `x` | NUMBER | — | a abscissa |
| `y` | NUMBER | — | a ordenada |

#### Exemplo

```sql
PL_FPDF.SetXY(20, 50);
```

**Veja também:** [SetX](#setx) · [SetY](#sety)

---

### SetY

Move a ordenada E devolve o x à margem esquerda -- é o efeito que surpreende quem só queria descer. Para mover os dois sem esse efeito, use SetXY. Valor negativo conta a partir do pé da página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetY(
    py number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `py` | NUMBER | — | a nova ordenada |

#### Exemplo

```sql
PL_FPDF.SetY(-20);   -- 20 acima do pé
```

**Veja também:** [GetY](#gety) · [SetXY](#setxy)

---

## Fontes e UTF-8

### AddFont

Registra uma fonte para uso pelo SetFont. Para as 14 fontes padrão do PDF não é preciso chamar isto -- elas já estão disponíveis, e escrevem acentuado desde a 3.4.0.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddFont(
    family   varchar2,
    style    varchar2 DEFAULT '',
    filename varchar2 DEFAULT '');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `family` | VARCHAR2 | — | nome da família |
| `style` | VARCHAR2 | `''` | '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'BI' os dois |
| `filename` | VARCHAR2 | `''` | arquivo de métricas da fonte |

#### Exemplo

```sql
PL_FPDF.AddFont('Arial', 'B');
```

**Veja também:** [AddTTFFont](#addttffont) · [SetFont](#setfont)

---

### AddTTFFont

Registra uma fonte TrueType a partir de um BLOB e a deixa disponível para o SetFont, pelo nome dado aqui. As tabelas do arquivo são lidas de verdade -- head, hhea, hmtx, cmap, OS/2 e post --, e a fonte vai embutida no PDF como /FontFile2. O arquivo cresce: o programa da fonte sai em hexadecimal, então ocupa o DOBRO do tamanho dela, e ainda não há subset — a fonte inteira vai embutida, mesmo que o documento use dez glifos. Para texto em português com acento não é preciso embutir nada: as fontes padrão escrevem acentuado desde a 3.4.0.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.AddTTFFont(
    p_font_name varchar2,
    p_font_blob blob,
    p_encoding  varchar2 DEFAULT 'UTF-8',
    p_embed     boolean DEFAULT true);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | nome pelo qual SetFont a chamará |
| `p_font_blob` | BLOB | — | o arquivo.ttf |
| `p_encoding` | VARCHAR2 | `'UTF-8'` | codificação da fonte |
| `p_embed` | BOOLEAN | `true` | embutir no PDF |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20210` | nome da fonte vazio |
| `ORA-20211` | BLOB da fonte nulo |

#### Exemplo

```sql
SELECT arquivo INTO l_ttf FROM fontes WHERE nome = 'Roboto';
PL_FPDF.AddTTFFont('Roboto', l_ttf);
```

**Veja também:** [LoadTTFFromFile](#loadttffromfile) · [IsTTFFontLoaded](#isttffontloaded) · [SetFont](#setfont)

---

### ClearTTFFontCache

Descarrega as fontes TrueType e libera os LOBs temporários delas. Vale chamar ao fim de um lote: cada fonte embutida ocupa centenas de KB na sessão.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClearTTFFontCache;
```

#### Exemplo

```sql
PL_FPDF.ClearTTFFontCache;
```

**Veja também:** [AddTTFFont](#addttffont)

---

### GetTTFFontInfo

Devolve o registro da fonte: os bytes guardados e as métricas lidas do arquivo -- unidades por em, ascendente, descendente, altura de caixa alta, a caixa e o ângulo do itálico. Tudo já reescalado para as 1000 unidades por em do PDF, menos o units_per_em, que é o do arquivo.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetTTFFontInfo(
    p_font_name varchar2) RETURN RECTTFFONT;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | nome da fonte |

#### Retorno

recTTFFont - as métricas da fonte

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20206` | fonte não carregada |

#### Exemplo

```sql
l_fonte := PL_FPDF.GetTTFFontInfo('Roboto');
```

**Veja também:** [AddTTFFont](#addttffont)

---

### IsTTFFontLoaded

Diz se a fonte está registrada nesta sessão, e portanto disponível para o SetFont. O nome não diferencia maiúsculas de minúsculas.

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsTTFFontLoaded(
    p_font_name varchar2) RETURN BOOLEAN;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | nome da fonte |

#### Retorno

BOOLEAN - TRUE se carregada

#### Exemplo

```sql
IF NOT PL_FPDF.IsTTFFontLoaded('Roboto') THEN ... END IF;
```

**Veja também:** [AddTTFFont](#addttffont) · [ClearTTFFontCache](#clearttffontcache)

---

### LoadTTFFromFile

Lê um .ttf de um DIRECTORY do banco e o registra como o AddTTFFont. Exige READ no diretório concedido ao schema; sem isso, AddTTFFont recebe os bytes direto, sem concessão nenhuma.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.LoadTTFFromFile(
    p_font_name varchar2,
    p_file_path varchar2,
    p_directory varchar2 DEFAULT 'FONTS_DIR',
    p_encoding  varchar2 DEFAULT 'UTF-8');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_font_name` | VARCHAR2 | — | nome pelo qual SetFont a chamará |
| `p_file_path` | VARCHAR2 | — | nome do arquivo |
| `p_directory` | VARCHAR2 | `'FONTS_DIR'` | DIRECTORY do banco |
| `p_encoding` | VARCHAR2 | `'UTF-8'` | codificação da fonte |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20202` | arquivo de fonte inválido |
| `ORA-20401` | diretório inválido |
| `ORA-20402` | sem permissão de leitura |

#### Exemplo

```sql
PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');
```

**Veja também:** [AddTTFFont](#addttffont)

---

### SetFont

Escolhe a fonte, o estilo e o corpo do texto que vier depois. Corpo zero mantém o que já estava. As fontes padrão -- Helvetica, Times, Courier, Symbol e ZapfDingbats -- não precisam ser carregadas.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFont(
    pfamily varchar2,
    pstyle  varchar2 DEFAULT '',
    psize   number DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pfamily` | VARCHAR2 | — | família ('Helvetica', 'Times', 'Courier'...) |
| `pstyle` | VARCHAR2 | `''` | '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'U' sublinhado (Underline), ou a combinação |
| `psize` | NUMBER | `0` | corpo em pontos ( 0 = mantém) |

#### Nota

A família é guardada em minúscula e o estilo em maiúscula. É o que os getters devolvem, e não o texto que entrou aqui.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20005` | Init ainda não foi chamado |
| `ORA-20201` | fonte não encontrada -- nem entre as padrão, nem no registro de TrueType |
| `ORA-20100` | estilo inválido |

#### Exemplo

```sql
PL_FPDF.SetFont('Helvetica', 'B', 12);
```

**Veja também:** [SetFontSize](#setfontsize) · [AddTTFFont](#addttffont) · [GetStringWidth](#getstringwidth)

---

### SetFontSize

Troca só o corpo, mantendo família e estilo.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFontSize(
    psize number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `psize` | NUMBER | — | corpo em pontos |

#### Exemplo

```sql
PL_FPDF.SetFontSize(8);
```

**Veja também:** [SetFont](#setfont)

---

### UTF8ToPDFString

Escapa os caracteres que a sintaxe de string do PDF reserva -- o parêntese e a barra invertida. NÃO converte codificação: quem escreve texto pelas rotinas normais (Cell, Write, Text) não precisa chamar isto, porque a conversão para WinAnsi já acontece lá dentro.

#### Sintaxe

```sql
FUNCTION PL_FPDF.UTF8ToPDFString(
    p_text   varchar2,
    p_escape boolean DEFAULT true) RETURN VARCHAR2;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_text` | VARCHAR2 | — | o texto |
| `p_escape` | BOOLEAN | `true` | escapar os caracteres reservados |

#### Retorno

VARCHAR2 - o texto pronto para ir entre parênteses num objeto PDF

#### Exemplo

```sql
l_txt := PL_FPDF.UTF8ToPDFString('Total (liquido)');
```

---

## Escrita de texto

### Cell

Escreve uma célula retangular: opcionalmente com borda, com fundo e com texto dentro, e move o cursor conforme pln. É a rotina mais usada da biblioteca. Se a célula não couber no que resta da página e a quebra automática estiver ligada, a página é trocada antes de escrever.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pw` | NUMBER | — | largura; 0 vai até a margem direita |
| `ph` | NUMBER | `0` | altura |
| `ptxt` | VARCHAR2 | `''` | o texto |
| `pborder` | VARCHAR2 | `'0'` | '0' sem borda, '1' moldura inteira, ou as letras dos lados que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas laterais; 'TB', só topo e base |
| `pln` | NUMBER | `0` | para onde vai o cursor: 0 = à direita da célula; 1 = próxima linha, na margem esquerda; 2 = abaixo, mantendo o x |
| `palign` | VARCHAR2 | `''` | 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right, direita) |
| `pfill` | NUMBER | `0` | 1 pinta o fundo com a cor de SetFillColor, 0 não |
| `plink` | VARCHAR2 | `''` | URL ou identificador de link interno |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | qualquer falha na escrita da célula. O Cell embrulha o erro original neste código, mas preserva a pilha (keeperrorstack), de modo que a causa -- um ORA-20203 de caractere fora do WinAnsi, por exemplo -- continua visível no rastro. |

#### Exemplo

```sql
-- moldura inteira em volta da célula
PL_FPDF.Cell(40, 8, 'Total', '1', 0, 'L');
PL_FPDF.Cell(30, 8, '1.234,56', '1', 1, 'R');

-- só a base, para sublinhar o título de uma coluna
PL_FPDF.Cell(100, 8, 'Produto', 'B', 1, 'L');

-- corpo de tabela: cada célula desenha só as laterais ('LR'), e uma
-- célula vazia com o topo ('T') fecha a tabela embaixo. Sem isso, usar
-- '1' em todas daria traço duplo entre as linhas.
PL_FPDF.Cell(60, 8, 'Licença anual', 'LR', 0, 'L');
PL_FPDF.Cell(40, 8, '28.400,00',     'LR', 1, 'R');
PL_FPDF.Cell(60, 8, 'Suporte 8x5',   'LR', 0, 'L');
PL_FPDF.Cell(40, 8, '15.750,50',     'LR', 1, 'R');
PL_FPDF.Cell(100, 0, '', 'T', 1);
```

**Veja também:** [MultiCell](#multicell) · [Write](#write) · [CellRotated](#cellrotated) · [SetFillColor](#setfillcolor)

---

### CellRotated

O mesmo que Cell, com o texto girado dentro da célula. Serve para cabeçalho de coluna estreita e para carimbo na lateral da página.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_width` | NUMBER | — | largura; 0 vai até a margem direita |
| `p_height` | NUMBER | `0` | altura |
| `p_text` | VARCHAR2 | `''` | o texto |
| `p_border` | VARCHAR2 | `'0'` | '0' sem borda, '1' moldura inteira, ou as letras dos lados que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas laterais; 'TB', só topo e base |
| `p_ln` | NUMBER | `0` | 0 à direita, 1 próxima linha na margem esquerda, 2 abaixo mantendo o x |
| `p_align` | VARCHAR2 | `''` | 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right, direita) |
| `p_fill` | NUMBER | `0` | 1 pinta o fundo, 0 não |
| `p_link` | VARCHAR2 | `''` | URL ou link interno |
| `p_rotation` | PLS_INTEGER | `0` | giro do texto em graus (0, 90, 180, 270) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20110` | giro inválido |

#### Exemplo

```sql
PL_FPDF.CellRotated(10, 40, 'Janeiro', '1', 0, 'C', 0, '', 90);
```

**Veja também:** [Cell](#cell) · [WriteRotated](#writerotated)

---

### GetCurrentFontFamily

Devolve o nome da família em uso. Sempre em MINÚSCULA: o SetFont normaliza, então 'Times' entra e 'times' volta. Comparar com 'Times' nunca casa -- use LOWER() dos dois lados.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentFontFamily RETURN VARCHAR2;
```

#### Retorno

VARCHAR2 - a família corrente

#### Exemplo

```sql
l_familia := PL_FPDF.GetCurrentFontFamily;
```

**Veja também:** [SetFont](#setfont)

---

### GetCurrentFontSize

Devolve o corpo da fonte em uso, em pontos.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentFontSize RETURN NUMBER;
```

#### Retorno

NUMBER - o tamanho em pontos

#### Exemplo

```sql
l_corpo := PL_FPDF.GetCurrentFontSize;
```

**Veja também:** [SetFont](#setfont)

---

### GetCurrentFontStyle

Devolve o estilo em uso: '' (normal), 'B' (Bold, negrito), 'I' (Italic, itálico), 'U' (Underline, sublinhado) ou a combinação. Sempre em MAIÚSCULA: o SetFont normaliza, então 'b' entra e 'B' volta.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetCurrentFontStyle RETURN VARCHAR2;
```

#### Retorno

VARCHAR2 - o estilo corrente

#### Exemplo

```sql
l_estilo := PL_FPDF.GetCurrentFontStyle;
```

**Veja também:** [SetFont](#setfont)

---

### GetLineSpacing

Devolve a entrelinha usada pelo MultiCell quando a altura da linha vai em branco.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetLineSpacing RETURN NUMBER;
```

#### Retorno

NUMBER - a entrelinha, na unidade corrente

#### Exemplo

```sql
l_entre := PL_FPDF.GetLineSpacing;
```

**Veja também:** [SetLineSpacing](#setlinespacing)

---

### GetStringWidth

Mede quanto o texto ocupa na fonte e no corpo correntes, na unidade em uso. É o que permite alinhar, centralizar e decidir onde quebrar. Caractere acentuado mede o mesmo que o caractere base -- nas 14 fontes padrão do PDF o glifo acentuado tem a mesma largura de avanço.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetStringWidth(
    pstr varchar2) RETURN NUMBER;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pstr` | VARCHAR2 | — | o texto a medir |

#### Retorno

NUMBER - a largura, na unidade corrente

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20203` | caractere fora do WinAnsi |

#### Exemplo

```sql
l_larg := PL_FPDF.GetStringWidth('São Paulo');
```

**Veja também:** [SetFont](#setfont) · [Cell](#cell)

---

### MultiCell

Escreve um bloco de texto que quebra sozinho na largura pedida, uma célula por linha, e devolve quantas linhas saíram. A quebra respeita o espaço entre palavras e a quebra explícita (CHR(10)). Esta é a versão FUNCTION, para quem precisa saber quantas linhas foram gastas -- para calcular a altura de uma tabela, tipicamente.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pw` | NUMBER | — | largura do bloco; 0 vai até a margem direita |
| `ph` | NUMBER | `0` | altura de cada linha; em branco usa a entrelinha de SetLineSpacing |
| `ptxt` | VARCHAR2 | — | o texto |
| `pborder` | VARCHAR2 | `'0'` | '0' sem borda, '1' moldura inteira, ou as letras dos lados que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas laterais; 'TB', só topo e base |
| `palign` | VARCHAR2 | `'J'` | 'J' justificado (Justified, o padrão), 'L' (Left, esquerda), 'C' (Center, centro) ou 'R' (Right, direita) |
| `pfill` | NUMBER | `0` | 1 pinta o fundo, 0 não |
| `phMax` | NUMBER | `0` | altura máxima do bloco; 0 sem limite |

Na sobrecarga acima os parâmetros são os mesmos, na mesma ordem, com outros nomes: `pwidth`, `pheight`, `ptext`, `pbrdr`, `palignment`, `pfillin`, `phMaximum`.

#### Retorno

NUMBER - quantas linhas foram escritas

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | qualquer falha na escrita, com a pilha original preservada |

#### Exemplo

```sql
-- parágrafo justificado, com moldura inteira
l_linhas := PL_FPDF.MultiCell(120, 5, l_texto_longo, '1', 'J');

-- sem borda nenhuma, que é o caso comum em corpo de texto
l_linhas := PL_FPDF.MultiCell(120, 5, l_texto_longo, '0', 'J');

-- só as laterais, para um bloco dentro de uma tabela
l_linhas := PL_FPDF.MultiCell(120, 5, l_observacao, 'LR', 'L');
```

**Veja também:** [Cell](#cell) · [Write](#write)

---

### SetLineSpacing

Define a entrelinha do MultiCell para quando a altura da linha não for informada.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLineSpacing(
    pls number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pls` | NUMBER | — | a entrelinha, na unidade corrente |

#### Exemplo

```sql
PL_FPDF.SetLineSpacing(5);
```

**Veja também:** [GetLineSpacing](#getlinespacing)

---

### Text

Escreve texto num ponto exato, sem célula, sem quebra e sem mover o cursor. (px, py) é a LINHA DE BASE do texto, não o topo dele.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Text(
    px   number,
    py   number,
    ptxt varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | a linha de base |
| `py` | NUMBER | — | a linha de base |
| `ptxt` | VARCHAR2 | — | o texto |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20203` | caractere fora do WinAnsi |

#### Exemplo

```sql
PL_FPDF.Text(20, 50, 'Endereço de cobrança');
```

**Veja também:** [Cell](#cell) · [Write](#write)

---

### Write

Escreve texto corrido a partir de onde o cursor está, indo até a margem direita e continuando na linha seguinte -- como um parágrafo de processador de texto. Diferente do MultiCell, começa no meio da linha onde o cursor parou, o que é o que se quer para emendar texto de formatações diferentes.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Write(
    pH    varchar2,
    ptxt  varchar2,
    plink varchar2 DEFAULT null);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pH` | VARCHAR2 | — | altura da linha, na unidade corrente |
| `ptxt` | VARCHAR2 | — | o texto |
| `plink` | VARCHAR2 | `null` | URL ou identificador de link interno |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | qualquer falha na escrita, com a pilha original preservada |

#### Exemplo

```sql
PL_FPDF.SetFont('Helvetica', '', 10);
PL_FPDF.Write(5, 'Consulte o ');
PL_FPDF.SetFont('Helvetica', 'U', 10);
PL_FPDF.Write(5, 'manual', 'https://example.com/manual');
```

**Veja também:** [Cell](#cell) · [MultiCell](#multicell) · [WriteRotated](#writerotated)

---

### WriteRotated

O mesmo que Write, com o texto girado.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.WriteRotated(
    p_height   number,
    p_text     varchar2,
    p_link     varchar2 DEFAULT null,
    p_rotation pls_integer DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_height` | NUMBER | — | altura da linha |
| `p_text` | VARCHAR2 | — | o texto |
| `p_link` | VARCHAR2 | `null` | URL ou link interno |
| `p_rotation` | PLS_INTEGER | `0` | giro em graus (0, 90, 180, 270) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20110` | giro inválido |
| `ORA-20111` | só o giro de 0 grau é suportado; use CellRotated |

#### Exemplo

```sql
PL_FPDF.WriteRotated(5, 'CONFIDENCIAL', NULL, 90);
```

**Veja também:** [Write](#write) · [CellRotated](#cellrotated)

---

## Cores e desenho

### Line

Desenha um segmento de reta entre dois pontos, com a cor e a espessura correntes.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Line(
    x1 number,
    y1 number,
    x2 number,
    y2 number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `x1` | NUMBER | — | ponto inicial |
| `y1` | NUMBER | — | ponto inicial |
| `x2` | NUMBER | — | ponto final |
| `y2` | NUMBER | — | ponto final |

#### Exemplo

```sql
PL_FPDF.Line(20, 60, 190, 60);
```

**Veja também:** [SetDrawColor](#setdrawcolor) · [SetLineWidth](#setlinewidth)

---

### Poly

Desenha um polígono ligando os pontos na ordem da tabela, que precisa começar no índice 0. Fechado, o último ponto liga de volta ao primeiro.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Poly(
    points tab_points,
    pclose boolean,
    pstyle varchar2 DEFAULT '');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `points` | TAB_POINTS | — | os vértices, indexados a partir de 0 |
| `pclose` | BOOLEAN | — | fechar o contorno |
| `pstyle` | VARCHAR2 | `''` | '' desenha o contorno (padrão), 'F' preenche (Fill), 'FD' ou 'DF' preenche e contorna (Fill and Draw) |

#### Exemplo

```sql
l_pontos(0).x := 10; l_pontos(0).y := 10;
l_pontos(1).x := 50; l_pontos(1).y := 10;
l_pontos(2).x := 30; l_pontos(2).y := 40;
PL_FPDF.Poly(l_pontos, TRUE, 'F');
```

**Veja também:** [Line](#line) · [Triangle](#triangle)

---

### Rect

Desenha um retângulo a partir do canto superior esquerdo.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | canto superior esquerdo |
| `py` | NUMBER | — | canto superior esquerdo |
| `pw` | NUMBER | — | largura |
| `ph` | NUMBER | — | altura |
| `pstyle` | VARCHAR2 | `''` | '' contorna (padrão), 'F' preenche (Fill), 'FD' ou 'DF' preenche e contorna (Fill and Draw) |

#### Exemplo

```sql
PL_FPDF.Rect(20, 40, 60, 25, 'FD');
```

**Veja também:** [SetDrawColor](#setdrawcolor) · [SetFillColor](#setfillcolor)

---

### SetDash

Passa a desenhar linha tracejada, com o comprimento do traço e o do intervalo na unidade corrente. Os dois em zero voltam à linha cheia. Vale para tudo o que for desenhado depois, até ser trocado.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDash(
    pblack number DEFAULT 0,
    pwhite number DEFAULT 0);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pblack` | NUMBER | `0` | comprimento do traço |
| `pwhite` | NUMBER | `0` | comprimento do intervalo |

#### Exemplo

```sql
PL_FPDF.SetDash(2, 2);          -- tracejado
PL_FPDF.Line(10, 50, 200, 50);
PL_FPDF.SetDash;                -- volta à linha cheia
```

**Veja também:** [SetLineDashPattern](#setlinedashpattern)

---

### SetDrawColor

Define a cor com que se desenham linhas, contornos e bordas de célula. Com um argumento só, é tom de cinza (0 preto, 255 branco); com três, é RGB. Vale do ponto em que é chamada em diante.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDrawColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `r` | NUMBER | — | vermelho, ou o nível de cinza (0..255) |
| `g` | NUMBER | `-1` | verde (0..255) |
| `b` | NUMBER | `-1` | azul (0..255) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20501` | componente fora de 0..255 |

#### Exemplo

```sql
PL_FPDF.SetDrawColor(200);            -- cinza claro
PL_FPDF.SetDrawColor(0, 90, 160);     -- azul
```

**Veja também:** [SetFillColor](#setfillcolor) · [SetTextColor](#settextcolor) · [SetLineWidth](#setlinewidth)

---

### SetFillColor

Define a cor de fundo das células preenchidas e das formas com estilo 'F'. Um argumento é cinza, três são RGB.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFillColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `r` | NUMBER | — | vermelho, ou o nível de cinza (0..255) |
| `g` | NUMBER | `-1` | verde (0..255) |
| `b` | NUMBER | `-1` | azul (0..255) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20501` | componente fora de 0..255 |

#### Exemplo

```sql
PL_FPDF.SetFillColor(230, 230, 230);
PL_FPDF.Cell(40, 8, 'Cabecalho', '1', 0, 'C', 1);
```

**Veja também:** [Cell](#cell) · [Rect](#rect)

---

### SetLineDashPattern

Escreve o operador 'd' do PDF direto no fluxo de conteúdo, para quem precisa de um padrão que o SetDash não monta. O texto vai como está, e um padrão malformado só aparece no leitor. Prefira SetDash.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLineDashPattern(
    pdash varchar2 DEFAULT '[] 0');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pdash` | VARCHAR2 | `'[] 0'` | o padrão, na sintaxe do PDF ('[] 0' = linha cheia) |

#### Exemplo

```sql
PL_FPDF.SetLineDashPattern('[3 2] 0');
```

**Veja também:** [SetDash](#setdash)

---

### SetLineWidth

Define a espessura do traço, na unidade corrente.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLineWidth(
    width number);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `width` | NUMBER | — | a espessura, maior que zero |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20502` | espessura zero ou negativa |

#### Exemplo

```sql
PL_FPDF.SetLineWidth(0.5);
```

**Veja também:** [Line](#line) · [Rect](#rect)

---

### SetTextColor

Define a cor do texto. Um argumento é cinza, três são RGB.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetTextColor(
    r number,
    g number DEFAULT -1,
    b number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `r` | NUMBER | — | vermelho, ou o nível de cinza (0..255) |
| `g` | NUMBER | `-1` | verde (0..255) |
| `b` | NUMBER | `-1` | azul (0..255) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20501` | componente fora de 0..255 |

#### Exemplo

```sql
PL_FPDF.SetTextColor(180, 0, 0);
```

**Veja também:** [SetFont](#setfont) · [Cell](#cell)

---

### Triangle

Desenha um triângulo isósceles de base 2*psize e altura psize, com a ponta virada para porientation. (px, py) é o canto superior esquerdo da caixa que envolve o triângulo, e não o vértice.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | canto superior esquerdo da caixa |
| `py` | NUMBER | — | canto superior esquerdo da caixa |
| `psize` | NUMBER | — | metade da base, e a altura |
| `porientation` | VARCHAR2 | `'left'` | para onde aponta: 'up'/'U', 'down'/'D', 'left'/'L', 'right'/'R' |
| `pstyle` | VARCHAR2 | `''` | '' contorna, 'F' preenche (Fill), 'FD'/'DF' os dois |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20821` | orientação inválida |

#### Exemplo

```sql
PL_FPDF.Triangle(20, 20, 5, 'right', 'F');
```

**Veja também:** [Poly](#poly) · [Rect](#rect)

---

## Imagens

### getImageFromUrl

Busca uma imagem pela rede e devolve os bytes com o cabeçalho já interpretado. Exige ACL de rede concedida ao schema. Substitui a implementação sobre OrdImage, que saiu de linha.

#### Sintaxe

```sql
FUNCTION PL_FPDF.getImageFromUrl(
    p_Url varchar2) RETURN RECIMAGEBLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_Url` | VARCHAR2 | — | a URL da imagem (http/https) |

#### Retorno

recImageBlob - os bytes e os metadados

#### Nota

Formatos aceitos: PNG, JPEG/JPG

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20301` | cabeçalho de imagem inválido |
| `ORA-20302` | não foi possível buscar a imagem |
| `ORA-20303` | formato não suportado |

#### Exemplo

```sql
l_img := PL_FPDF.getImageFromUrl('https://example.com/logo.png');
```

**Veja também:** [Image](#image)

---

### image

Coloca uma imagem buscada por URL. A busca sai pela rede e exige ACL concedida ao schema -- quando a imagem já está numa tabela ou numa variável, ImageFromBlob faz o mesmo sem rede e sem permissão. Largura e altura em zero saem da própria imagem, a 72 dpi; com uma das duas em zero, ela é derivada da outra, mantendo a proporção.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pFile` | VARCHAR2 | — | URL da imagem |
| `pX` | NUMBER | — | canto superior esquerdo |
| `pY` | NUMBER | — | canto superior esquerdo |
| `pWidth` | NUMBER | `0` | largura ( 0 = derivada) |
| `pHeight` | NUMBER | `0` | altura ( 0 = derivada) |
| `pType` | VARCHAR2 | `null` | formato, quando não se quer deduzir do arquivo |
| `pLink` | VARCHAR2 | `null` | URL ou identificador de link interno sobre a imagem |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | falha ao buscar ou interpretar a imagem, com a pilha original preservada |

#### Exemplo

```sql
PL_FPDF.Image('https://example.com/logo.png', 10, 10, 40);
```

**Veja também:** [getImageFromUrl](#getimagefromurl) · [OverlayImage](#overlayimage)

---

### ImageFromBlob

Coloca uma imagem que o chamador já tem em mãos, sem passar por URL. O Image() busca pela rede e exige ACL concedida ao schema; quando a imagem já está numa tabela ou numa variável, esta entrada dispensa a rede e a permissão. O formato é reconhecido pelos primeiros bytes do arquivo, não pela extensão: PNG e JPEG; qualquer outra coisa é recusada.

#### Sintaxe

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

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_blob` | BLOB | — | bytes da imagem (PNG ou JPEG) |
| `p_name` | VARCHAR2 | — | chave no cache de imagens. Um BLOB não tem nome, então o chamador escolhe: nomes distintos para imagens distintas, e o mesmo nome reaproveita o objeto já emitido no documento |
| `pX` | NUMBER | — | posição, na unidade corrente |
| `pY` | NUMBER | — | posição, na unidade corrente |
| `pWidth` | NUMBER | `0` | largura ( 0 = derivada) |
| `pHeight` | NUMBER | `0` | altura ( 0 = derivada) |
| `pLink` | VARCHAR2 | `null` | link opcional sobre a área da imagem |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20301` | cabeçalho inválido, BLOB vazio ou nome ausente |
| `ORA-20303` | formato não suportado |

#### Exemplo

```sql
SELECT logo INTO l_logo FROM empresa WHERE id = 1;
PL_FPDF.ImageFromBlob(l_logo, 'LOGO', 10, 10, 40);
```

**Veja também:** [image](#image) · [OverlayImage](#overlayimage)

---

## Links

### AddLink

RECUSA com -20601. Criaria um link interno, e link interno não está implementado: o /Dest nunca chegou a ser escrito no arquivo, então o identificador que esta função devolveria não levaria a lugar nenhum -- e o Link o recusa. Até setembro/2026 a chamada levantava ORA-06531, "reference to uninitialized collection", porque a coleção interna nunca foi inicializada: nunca funcionou, em nenhuma versão. Passa a recusar com mensagem que diz o que usar no lugar.

#### Sintaxe

```sql
FUNCTION PL_FPDF.AddLink RETURN NUMBER;
```

#### Retorno

NUMBER - nunca devolve: levanta antes

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20601` | link interno não implementado |

#### Exemplo

```sql
-- Use URL:
PL_FPDF.Cell(60, 8, 'Site', plink => 'https://example.com');
```

**Veja também:** [SetLink](#setlink) · [Link](#link)

---

### Link

Marca uma área retangular como clicável, levando a uma URL.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `px` | NUMBER | — | canto superior esquerdo da área |
| `py` | NUMBER | — | canto superior esquerdo da área |
| `pw` | NUMBER | — | largura |
| `ph` | NUMBER | — | altura |
| `plink` | VARCHAR2 | — | a URL |

#### Limitation

1. Uma área por página. Uma segunda chamada na mesma página substitui a primeira, em silêncio -- a estrutura guarda um registro por página. Documentado por ser assim, não por ser o desejável. 2. Link interno não é suportado, e é RECUSADO com -20601. O ramo que escreveria o /Dest saiu comentado no porte original e nunca voltou; emiti-lo assim produzia um /Annot com o dicionário aberto, isto é, arquivo malformado. Desde setembro/2026 a chamada levanta erro em vez de gravar o arquivo quebrado. Use URL.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20601` | destino não é URL -- link interno ou NULL |

#### Exemplo

```sql
PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
```

**Veja também:** [AddLink](#addlink) · [SetLink](#setlink)

---

### SetLink

RECUSA com -20601, pelo mesmo motivo do AddLink: guardar o destino não adiantaria, porque o /Dest não é emitido e ninguém o lê. Até setembro/2026 levantava ORA-06531.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLink(
    plink number,
    py    number DEFAULT 0,
    ppage number DEFAULT -1);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `plink` | NUMBER | — | identificador devolvido por AddLink |
| `py` | NUMBER | `0` | ordenada de chegada (- 1 = a posição corrente) |
| `ppage` | NUMBER | `-1` | página de chegada (- 1 = a página corrente) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20601` | link interno não implementado |

#### Exemplo

```sql
-- Use URL:
PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
```

**Veja também:** [AddLink](#addlink)

---

## Cabeçalho e rodapé

### Footer

Executa a rotina registrada em SetFooterProc. É chamada sozinha ao fechar cada página; não se chama à mão.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Footer;
```

#### Exemplo

```sql
PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');      -- e o resto é automático
```

**Veja também:** [SetFooterProc](#setfooterproc)

---

### Header

Executa a rotina registrada em SetHeaderProc. É chamada sozinha ao abrir cada página; não se chama à mão.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Header;
```

#### Exemplo

```sql
PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');   -- e o resto é automático
```

**Veja também:** [SetHeaderProc](#setheaderproc)

---

### SetAliasNbPages

Define o texto que será trocado pelo total de páginas na hora de fechar o documento. É como se escreve "página 3 de 12" sem saber o 12 enquanto se escreve a página 3.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetAliasNbPages(
    palias varchar2 DEFAULT '{nb}');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `palias` | VARCHAR2 | `'{nb}'` | o marcador |

#### Exemplo

```sql
PL_FPDF.SetAliasNbPages;
PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo || ' de {nb}');
```

**Veja também:** [PageNo](#pageno)

---

### SetFooterProc

Como SetHeaderProc, para o rodapé: a rotina é executada ao fechar cada página, e é onde costuma entrar o "página N de {nb}".

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetFooterProc(
    footerprocname varchar2,
    paramTable     tv4000a DEFAULT noParam);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `footerprocname` | VARCHAR2 | — | nome da rotina (NULL desliga) |
| `paramTable` | TV4000A | `noParam` | parâmetros nomeados |

#### Exemplo

```sql
PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');
```

**Veja também:** [SetHeaderProc](#setheaderproc) · [SetAliasNbPages](#setaliasnbpages) · [Footer](#footer)

---

### SetHeaderProc

Registra o NOME de uma rotina que será executada no início de cada página. O nome e os nomes dos parâmetros são validados como identificadores SQL (DBMS_ASSERT) aqui, na configuração -- e não no meio do relatório, que é onde um nome inválido apareceria. O bloco é montado uma vez só, e não a cada página.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetHeaderProc(
    headerprocname varchar2,
    paramTable     tv4000a DEFAULT noParam);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `headerprocname` | VARCHAR2 | — | nome da rotina (NULL desliga) |
| `paramTable` | TV4000A | `noParam` | parâmetros nomeados |

#### Exemplo

```sql
PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');
```

**Veja também:** [SetFooterProc](#setfooterproc) · [Header](#header)

---

## QR Code e código de barras

### AddBarcode

Desenha um código de barras linear na página corrente. O codificador é o do PL_FPDF_UTIL, validado contra o zxing-cpp.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_x` | NUMBER | — | canto superior esquerdo |
| `p_y` | NUMBER | — | canto superior esquerdo |
| `p_width` | NUMBER | — | largura |
| `p_height` | NUMBER | — | altura |
| `p_code` | VARCHAR2 | — | o conteúdo a codificar |
| `p_type` | VARCHAR2 | `'CODE128'` | simbologia: 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF14', ou 'ITF' (Interleaved 2 of 5, qualquer quantidade par de dígitos -- o código de barras do boleto bancário tem 44) |
| `p_show_text` | BOOLEAN | `true` | escrever o código embaixo, legível |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20880` | código vazio |
| `ORA-20882` | simbologia não suportada |
| `ORA-20881` | largura ou altura não positiva |
| `ORA-20883` | CODE39 não aceita o caractere informado |
| `ORA-20884` | CODE128 aceita só ASCII de 32 a 126 |
| `ORA-20885` | EAN com quantidade de dígitos errada |
| `ORA-20886` | EAN com dígito verificador inválido |
| `ORA-20887` | ITF14 exige 13 dígitos (verificador calculado) ou 14 |
| `ORA-20888` | ITF sem nenhum dígito no conteúdo |

#### Exemplo

```sql
PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
```

**Veja também:** [AddQRCode](#addqrcode)

---

### AddQRCode

Desenha um QR Code na página corrente. O codificador é o do PL_FPDF_UTIL, validado contra o zxing-cpp -- o critério aqui não é "desenha um símbolo", é "um leitor decodifica".

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_x` | NUMBER | — | canto superior esquerdo, na unidade corrente |
| `p_y` | NUMBER | — | canto superior esquerdo, na unidade corrente |
| `p_size` | NUMBER | — | o lado do símbolo |
| `p_data` | VARCHAR2 | — | o conteúdo a codificar |
| `p_format` | VARCHAR2 | `'TEXT'` | 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL' |
| `p_error_correction` | VARCHAR2 | `'M'` | quanto do símbolo pode ser perdido e ainda assim ler: 'L' (Low, 7%), 'M' (Medium, 15%), 'Q' (Quartile, 25%) ou 'H' (High, 30%). Quanto maior, mais módulos o símbolo ocupa |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20870` | conteúdo vazio |
| `ORA-20872` | nível de correção inválido |
| `ORA-20871` | tamanho não positivo |
| `ORA-20873` | conteúdo além da capacidade do QR Code |

#### Exemplo

```sql
PL_FPDF.AddQRCode(50, 50, 40, 'https://example.com', 'URL', 'M');
```

**Veja também:** [AddBarcode](#addbarcode)

---

## Metadados e configuração

### GetDocumentMetadata

Devolve, em JSON, o que está configurado no documento em andamento e quantas páginas ele já tem.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetDocumentMetadata RETURN JSON_OBJECT_T;
```

#### Retorno

JSON_OBJECT_T - os metadados

#### Nota

Estrutura do JSON: { "pageCount": <number>, "title": "<string>", "author": "<string>", "subject": "<string>", "keywords": "<string>", "format": "<string>", "orientation": "<string>", "unit": "<string>", "initialized": <boolean> }

#### Exemplo

```sql
DECLARE
  l_meta JSON_OBJECT_T;
BEGIN
  l_meta := PL_FPDF.GetDocumentMetadata();
  DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
END;
```

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### GetPageInfo

Devolve, em JSON, o formato, a orientação e as medidas de uma página do documento em andamento.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPageInfo(
    p_page_number pls_integer DEFAULT null) RETURN JSON_OBJECT_T;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | `null` | a página ( NULL = a corrente) |

#### Retorno

JSON_OBJECT_T - os dados da página

#### Nota

Estrutura do JSON: { "number": <number>, "format": "<string>", "orientation": "<string>", "width": <number>, "height": <number>, "unit": "<string>" }

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20106` | a página não existe |
| `ORA-20812` | número de página fora da faixa |

#### Exemplo

```sql
DECLARE
  l_page_info JSON_OBJECT_T;
BEGIN
  l_page_info := PL_FPDF.GetPageInfo(1);
  DBMS_OUTPUT.PUT_LINE('Width: ' || l_page_info.get_Number('width'));
END;
```

**Veja também:** [GetCurrentPage](#getcurrentpage) · [GetPDFInfo](#getpdfinfo)

---

### SetAuthor

Grava o autor nos metadados do PDF.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetAuthor(
    pauthor varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pauthor` | VARCHAR2 | — | o autor |

#### Exemplo

```sql
PL_FPDF.SetAuthor('Departamento Financeiro');
```

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetCompression

Liga a compressão dos fluxos de conteúdo. Até agosto/2026 isto não fazia nada -- procurava uma rotina de zlib que o Oracle não tem e desligava sempre. Hoje o deflate está escrito no próprio pacote (PL_FPDF_UTIL.deflate) e a opção vale.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetCompression(
    p_compress boolean DEFAULT false);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_compress` | BOOLEAN | `false` | comprimir os fluxos |

#### Exemplo

```sql
PL_FPDF.SetCompression(TRUE);
```

**Veja também:** [FlateEncode](#flateencode) · [FlateDecode](#flatedecode)

---

### SetCreator

Grava, nos metadados, o nome do sistema que gerou o documento.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetCreator(
    pcreator varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pcreator` | VARCHAR2 | — | o sistema gerador |

#### Exemplo

```sql
PL_FPDF.SetCreator('ERP - modulo de faturamento');
```

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetDisplayMode

Diz ao leitor de PDF como abrir o documento. É preferência de apresentação: o leitor pode ignorar.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDisplayMode(
    zoom   varchar2,
    layout varchar2 DEFAULT 'continuous');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `zoom` | VARCHAR2 | — | 'fullpage' (página inteira), 'fullwidth' (largura da página), 'real' (tamanho real), 'default' (padrão do leitor), ou um número que é o percentual de ampliação |
| `layout` | VARCHAR2 | `'continuous'` | 'single' (uma página), 'continuous' (contínuo), 'two' (duas colunas), 'default' (padrão do leitor) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | modo de zoom ou de layout desconhecido |

#### Exemplo

```sql
PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
```

---

### SetDocumentConfig

Configura o documento inteiro a partir de um objeto JSON -- metadados, orientação, formato, fonte e margens numa chamada só. Serve a quem recebe a configuração de fora, de uma tabela ou de um serviço.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetDocumentConfig(
    p_config JSON_OBJECT_T);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_config` | JSON_OBJECT_T | — | o objeto JSON com as opções |

#### Nota

Chaves JSON: - title, author, subject, keywords, creator (metadados do documento) - orientation ('P' ou 'L'), unit ('mm','cm','in','pt'), format (formato da página) - fontFamily, fontSize, fontStyle (fonte padrão) - leftMargin, topMargin, rightMargin (margens, na unidade corrente)

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20001` | orientação inválida; só P ou L |
| `ORA-20002` | unidade inválida; só mm, cm, in ou pt |

#### Exemplo

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

**Veja também:** [GetDocumentMetadata](#getdocumentmetadata) · [SetTitle](#settitle)

---

### SetKeywords

Grava as palavras-chave nos metadados do PDF, separadas por espaço.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetKeywords(
    pkeywords varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pkeywords` | VARCHAR2 | — | as palavras-chave |

#### Exemplo

```sql
PL_FPDF.SetKeywords('relatorio producao 2026');
```

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetSubject

Grava o assunto nos metadados do PDF.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetSubject(
    psubject varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `psubject` | VARCHAR2 | — | o assunto |

#### Exemplo

```sql
PL_FPDF.SetSubject('Fechamento mensal');
```

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

### SetTitle

Grava o título nos metadados do PDF -- o que o leitor mostra na barra de título e o que o buscador indexa.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetTitle(
    ptitle varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `ptitle` | VARCHAR2 | — | o título |

#### Exemplo

```sql
PL_FPDF.SetTitle('Relatório de Produção');
```

**Veja também:** [SetDocumentConfig](#setdocumentconfig)

---

## Saída do documento

### ClosePDF

Fecha o documento: escreve o rodapé da última página, monta a estrutura do arquivo e troca o marcador do total de páginas. Sem nenhuma página, uma é criada em branco. As rotinas de saída chamam isto sozinhas.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClosePDF;
```

#### Exemplo

```sql
PL_FPDF.ClosePDF;
```

**Veja também:** [OutputBlob](#outputblob)

---

### OpenPDF

Marca o documento como aberto. O AddPage já faz isto quando preciso; chamar à mão é raro.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.OpenPDF;
```

#### Exemplo

```sql
PL_FPDF.OpenPDF;
```

**Veja também:** [Init](#init)

---

### Output

Fecha o documento e grava em arquivo, no DIRECTORY PDF_DIR. É a forma legada: os modos de entrega ao navegador ('I', 'D', 'S') saíram junto com o OWA/HTP e hoje recusam com -20306, dizendo o que usar no lugar. Para receber os bytes, use OutputBlob.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Output(
    pname varchar2 DEFAULT null,
    pdest varchar2 DEFAULT null);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pname` | VARCHAR2 | `null` | nome do arquivo (NULL grava 'doc.pdf') |
| `pdest` | VARCHAR2 | `null` | destino: 'F' (File, arquivo) é o único suportado |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | destino desconhecido, ou falha na gravação |
| `ORA-20306` | modo de entrega ao navegador não é mais suportado; a mensagem aponta OutputBlob e o cabeçalho Content-Type |

#### Exemplo

```sql
PL_FPDF.Output('relatorio.pdf', 'F');
```

**Veja também:** [OutputBlob](#outputblob) · [OutputFile](#outputfile)

---

### OutputBlob

Fecha o documento e devolve os bytes do PDF. É a saída principal da biblioteca: quem grava em tabela, quem anexa a e-mail e quem entrega por HTTP começa aqui.

#### Sintaxe

```sql
FUNCTION PL_FPDF.OutputBlob RETURN BLOB;
```

#### Retorno

BLOB - o PDF pronto

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20005` | Init ainda não foi chamado. Antes de agosto/2026 esta chamada seguia em frente e devolvia um PDF vazio, sem apontar a causa. |

#### Exemplo

```sql
l_pdf := PL_FPDF.OutputBlob;
INSERT INTO documentos (id, arquivo) VALUES (1, l_pdf);
```

**Veja também:** [OutputBlob](#outputblob)

---

### OutputFile

Fecha o documento e grava num DIRECTORY do banco. Exige WRITE no diretório concedido ao schema.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.OutputFile(
    p_filename  varchar2,
    p_directory varchar2 DEFAULT 'PDF_DIR');
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_filename` | VARCHAR2 | — | nome do arquivo |
| `p_directory` | VARCHAR2 | `'PDF_DIR'` | DIRECTORY do banco |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20401` | diretório inválido |
| `ORA-20402` | sem permissão de escrita |
| `ORA-20403` | falha ao gravar |

#### Exemplo

```sql
PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
```

**Veja também:** [OutputBlob](#outputblob)

---

### ReturnBlob

Fecha o documento e devolve os bytes. Existe por compatibilidade: os dois parâmetros são ACEITOS E IGNORADOS, e a chamada é repassada ao OutputBlob. Em código novo, chame OutputBlob direto.

#### Sintaxe

```sql
FUNCTION PL_FPDF.ReturnBlob(
    pname varchar2 DEFAULT null,
    pdest varchar2 DEFAULT null) RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pname` | VARCHAR2 | `null` | ignorado |
| `pdest` | VARCHAR2 | `null` | ignorado |

#### Retorno

BLOB - o PDF

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | falha ao fechar ou montar o documento, com a pilha original preservada |

#### Exemplo

```sql
l_pdf := PL_FPDF.OutputBlob;    -- prefira esta
```

**Veja também:** [OutputBlob](#outputblob)

---

## Manipulação de PDF existente

### AddWatermark

Acrescenta marca d'água de texto às páginas indicadas

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_text` | VARCHAR2 | — | Texto da marca d'água |
| `p_opacity` | NUMBER | `0.3` | Opacidade (0.0 a 1.0), padrão 0.3 |
| `p_rotation` | NUMBER | `45` | Ângulo de rotação (0, 45, 90, 135, 180, 225, 270, 315), default 45 |
| `p_pages` | VARCHAR2 | `'ALL'` | Range de páginas: 'ALL', '1-5', '1,3,5', default 'ALL' |
| `p_font` | VARCHAR2 | `'Helvetica'` | Nome da fonte, default 'Helvetica' |
| `p_size` | NUMBER | `48` | Tamanho da fonte em pontos, default 48 |
| `p_color` | VARCHAR2 | `'gray'` | Nome da cor ('gray', 'red', 'blue'), default 'gray' |

#### Nota

Desenhada por OutputModifiedPDF() no fluxo de conteúdo: cada página afetada ganha um objeto de conteúdo próprio e um /Resources próprio, de modo que um /Resources compartilhado entre páginas nunca é contaminado. Centralizada e girada em torno do centro da página; a fonte é sempre Helvetica.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |
| `ORA-20816` | texto da marca vazio |
| `ORA-20817` | opacidade fora de 0..1 |
| `ORA-20818` | rotação fora de 0, 45, 90, 135, 180, 225, 270, 315 |

#### Exemplo

```sql
PL_FPDF.LoadPDF(l_pdf);
-- Todas as páginas
PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
-- Páginas específicas
PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
-- Estilo personalizado
PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1', 'Helvetica', 72, 'green');
```

**Veja também:** [GetWatermarks](#getwatermarks) · [OverlayText](#overlaytext) · [OutputModifiedPDF](#outputmodifiedpdf)

---

### ClearPDFCache

Limpar PDF carregado da memória e liberar todos os recursos em cache

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClearPDFCache;
```

#### Nota

Sempre chame isso após processar um PDF para liberar recursos de memória. Limpa: PDF carregado, info páginas, rotações, páginas removidas, marcas d'água.

#### Exemplo

```sql
PL_FPDF.LoadPDF(l_pdf);
-- Processar PDF
l_modified := PL_FPDF.OutputModifiedPDF();
-- Limpar memória
PL_FPDF.ClearPDFCache();
```

**Veja também:** [LoadPDF](#loadpdf) · [UnloadPDF](#unloadpdf)

---

### FlateDecode

Descomprime um stream /FlateDecode do PDF (zlib, RFC 1950). Implementado em PL/SQL puro: o UTL_COMPRESS não serve porque só aceita rodapé gzip com CRC-32 correto, e esse CRC é do conteúdo DESCOMPRIMIDO — para saber o CRC seria preciso descomprimir antes.

#### Sintaxe

```sql
FUNCTION PL_FPDF.FlateDecode(
    p_stream    BLOB,
    p_max_bytes PLS_INTEGER DEFAULT 8388608) RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_stream` | BLOB | — | Stream comprimido (BLOB) |
| `p_max_bytes` | PLS_INTEGER | `8388608` | Teto da saída, 8 MB por padrão. Um stream comprimido é entrada não confiável: alguns KB podem virar gigabytes (zip bomb) e derrubar a sessão. Levanta -20893 em vez disso. |

#### Retorno

Conteúdo descomprimido

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20890` | Stream truncado |
| `ORA-20891` | Dados DEFLATE malformados |
| `ORA-20892` | Cabeçalho zlib inválido |
| `ORA-20893` | Saída passou de p_max_bytes |

#### Exemplo

```sql
  l_claro := PL_FPDF.FlateDecode(l_comprimido);
Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
```

**Veja também:** [LoadPDF](#loadpdf)

---

### FlateEncode

Comprime dados num stream /FlateDecode do PDF (zlib, RFC 1950). Escrito em PL/SQL puro: um bloco único com Huffman fixa e LZ77 guloso. Comprime menos que a Huffman dinâmica do zlib e muito mais que nada, e nunca devolve mais que a entrada somada ao custo do bloco armazenado.

#### Sintaxe

```sql
FUNCTION PL_FPDF.FlateEncode(
    p_data BLOB) RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_data` | BLOB | — | conteúdo a comprimir (BLOB) |

#### Retorno

BLOB - stream zlib: cabeçalho, DEFLATE e Adler-32

#### Exemplo

```sql
  l_comprimido := PL_FPDF.FlateEncode(l_claro);
Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
```

**Veja também:** [FlateDecode](#flatedecode) · [SetCompression](#setcompression)

---

### GetActivePageCount

Obter contagem de páginas não marcadas para remoção

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetActivePageCount RETURN PLS_INTEGER;
```

#### Retorno

Número de páginas ativas

#### Nota

Difere de GetPageCount() que retorna a contagem original

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |

#### Exemplo

```sql
l_total := PL_FPDF.GetPageCount();        -- Original: 10
PL_FPDF.RemovePage(2);
l_active := PL_FPDF.GetActivePageCount(); -- Ativas: 9
```

**Veja também:** [RemovePage](#removepage) · [GetPageCount](#getpagecount)

---

### GetPageCount

Obter o número total de páginas no documento PDF carregado

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPageCount RETURN PLS_INTEGER;
```

#### Retorno

Número de páginas

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |

#### Exemplo

```sql
l_pages := PL_FPDF.GetPageCount();
DBMS_OUTPUT.PUT_LINE('Total de páginas:' || l_pages);
```

**Veja também:** [LoadPDF](#loadpdf) · [GetActivePageCount](#getactivepagecount)

---

### GetPDFInfo

Obter metadados e informações sobre o documento PDF carregado

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPDFInfo RETURN JSON_OBJECT_T;
```

#### Retorno

com: - version: versão do PDF (por exemplo "1.4") - pageCount: Número de páginas - fileSize: Tamanho em bytes - objectCount: Número de objetos na xref - rootObjectId: ID do objeto Catalog

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |

#### Exemplo

```sql
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetPDFInfo();
  DBMS_OUTPUT.PUT_LINE('Versão:' || l_info.get_string('version'));
  DBMS_OUTPUT.PUT_LINE('Páginas:' || l_info.get_number('pageCount'));
END;
```

**Veja também:** [LoadPDF](#loadpdf) · [GetPageInfo](#getpageinfo)

---

### GetWatermarks

Obter lista de todas as marcas d'água aplicadas como array JSON

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetWatermarks RETURN JSON_ARRAY_T;
```

#### Retorno

JSON_ARRAY_T - array com os objetos de marca d'água e suas propriedades: - id: ID da marca d'água - text: Texto da marca d'água - opacity: Valor de opacidade (0.0-1.0) (0.0-1.0) - rotation: Ângulo de rotação em graus - pageRange: faixa de páginas (separada por vírgulas) - font: Nome da fonte - fontSize: Tamanho da fonte em pontos - color: Nome da cor

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |

#### Exemplo

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
    DBMS_OUTPUT.PUT_LINE('Marca d''água:' ||
                         l_watermark.get_string('text'));
  END LOOP;
END;
```

**Veja também:** [AddWatermark](#addwatermark)

---

### IsPageRemoved

Verificar se uma página está marcada para remoção

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsPageRemoved(
    p_page_number PLS_INTEGER) RETURN BOOLEAN;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Número da página para verificar |

#### Retorno

caso contrário

#### Exemplo

```sql
IF PL_FPDF.IsPageRemoved(2) THEN
  DBMS_OUTPUT.PUT_LINE('Página 2 removida');
END IF;
```

**Veja também:** [RemovePage](#removepage)

---

### IsPDFModified

Verificar se o PDF carregado foi modificado

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsPDFModified RETURN BOOLEAN;
```

#### Retorno

TRUE se modificado, FALSE caso contrário

#### Nota

Use para determinar se OutputModifiedPDF() precisa ser chamado

#### Exemplo

```sql
IF PL_FPDF.IsPDFModified() THEN
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();
END IF;
```

**Veja também:** [OutputModifiedPDF](#outputmodifiedpdf)

---

### LoadPDF

Carregar documento PDF existente na memória para leitura e modificação

#### Sintaxe

```sql
PROCEDURE PL_FPDF.LoadPDF(
    p_pdf_blob BLOB);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf_blob` | BLOB | — | Documento PDF como BLOB |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20800` | PDF nulo, ou pequeno demais para ter cabeçalho e trailer |
| `ORA-20801` | Cabeçalho PDF inválido |
| `ORA-20802` | startxref não encontrado |
| `ORA-20803` | Tabela xref inválida |
| `ORA-20804` | Objeto Root não encontrado |

#### Exemplo

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
  PL_FPDF.LoadPDF(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Páginas:' || PL_FPDF.GetPageCount());
END;
```

**Veja também:** [LoadPDFWithID](#loadpdfwithid) · [GetPageCount](#getpagecount) · [OutputModifiedPDF](#outputmodifiedpdf) · [ClearPDFCache](#clearpdfcache)

---

### OutputModifiedPDF

Gerar o PDF modificado copiando as páginas mantidas objeto a objeto. Conteúdo, fontes, imagens e anotações são copiados sem alteração: nada é re-renderizado. Aplica RemovePage e RotatePage.

#### Sintaxe

```sql
FUNCTION PL_FPDF.OutputModifiedPDF RETURN BLOB;
```

#### Retorno

Documento PDF modificado

#### Process

1. Valida se PDF está carregado e modificado 2. Indexa a origem (cadeia de xref + árvore de páginas achatada) 3. Seleciona as páginas não marcadas por RemovePage, na ordem original 4. Copia todo objeto alcançável a partir dessas páginas, renumerando as referências indiretas; o payload dos streams é copiado byte a byte 5. Emite um novo Catalog, um novo nó /Pages, xref e trailer

#### Limitation

Marcas d'água e overlays de texto e de imagem são todos desenhados. xref em stream e object streams (PDF 1.5+) são lidos, inclusive com o predictor PNG; um malformado levanta -20843/-20847/-20848.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |
| `ORA-20819` | o PDF não foi modificado (sem alterações para aplicar) |
| `ORA-20820` | todas as páginas foram removidas (não dá para gerar PDF vazio) |
| `ORA-20841` | dicionário de objeto grande demais para renumerar |
| `ORA-20843` | xref em stream malformada |
| `ORA-20847` | object stream malformado |
| `ORA-20848` | predictor não suportado na xref em stream |
| `ORA-20823` | imagem inválida ou não suportada. PNG com alfa e entrelaçado são suportados; recusados são o entrelaçado abaixo de 8 bits por componente, o indexado E entrelaçado, e imagens acima de 4 megapixels no caminho que reprocessa pixels |
| `ORA-20846` | o /Resources da página não pode ser sobreposto (subdicionário indireto compartilhado) |

#### Exemplo

```sql
DECLARE
  l_pdf BLOB;
  l_modified_pdf BLOB;
BEGIN
  -- Carregar PDF
  SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
  -- Aplicar modificações
  PL_FPDF.RotatePage(1, 90);
  PL_FPDF.RemovePage(3);
  -- Gerar PDF modificado
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();
  -- Salvar PDF modificado
  UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
  PL_FPDF.ClearPDFCache();
END;
```

**Veja também:** [LoadPDF](#loadpdf) · [ClearPDFCache](#clearpdfcache)

---

### RemovePage

Marcar uma página para remoção do PDF

#### Sintaxe

```sql
PROCEDURE PL_FPDF.RemovePage(
    p_page_number PLS_INTEGER);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Número da página para remover |

#### Nota

Página marcada para remoção. Use OutputModifiedPDF() para gerar PDF modificado

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |
| `ORA-20812` | número de página fora da faixa |
| `ORA-20814` | a página já estava marcada para remoção |
| `ORA-20810` | /Pages não encontrado no catálogo do PDF |

#### Exemplo

```sql
PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.RemovePage(2);  -- Remover página 2
PL_FPDF.RemovePage(5);  -- Remover página 5
```

**Veja também:** [IsPageRemoved](#ispageremoved) · [GetActivePageCount](#getactivepagecount) · [OutputModifiedPDF](#outputmodifiedpdf)

---

### RotatePage

Rotacionar uma página específica (armazenado em memória, aplicado na saída)

#### Sintaxe

```sql
PROCEDURE PL_FPDF.RotatePage(
    p_page_number PLS_INTEGER,
    p_rotation    NUMBER);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Número da página para rotacionar |
| `p_rotation` | NUMBER | — | Ângulo de rotação (0, 90, 180, 270) |

#### Nota

Mudanças armazenadas em memória. Use OutputModifiedPDF() para gerar PDF

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | nenhum PDF carregado -- chame LoadPDF antes |
| `ORA-20813` | giro inválido; só 0, 90, 180 ou 270 |
| `ORA-20810` | /Pages não encontrado no catálogo do PDF |

#### Exemplo

```sql
PL_FPDF.LoadPDF(l_pdf);
PL_FPDF.RotatePage(1, 90);    -- Rotacionar página 1
PL_FPDF.RotatePage(2, 180);   -- Rotacionar página 2
```

**Veja também:** [LoadPDF](#loadpdf) · [RemovePage](#removepage) · [OutputModifiedPDF](#outputmodifiedpdf)

---

## Overlays

### ClearOverlays

Limpar todas as sobreposições de todas ou de página específica

#### Sintaxe

```sql
PROCEDURE PL_FPDF.ClearOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | `NULL` | limpar da página ( NULL = todas) |

#### Exemplo

```sql
-- Limpar todas as sobreposições
PL_FPDF.ClearOverlays();
-- Limpar apenas da página 1
PL_FPDF.ClearOverlays(1);
```

**Veja também:** [RemoveOverlay](#removeoverlay) · [GetOverlays](#getoverlays)

---

### GetOverlays

Obter lista de todas as sobreposições aplicadas como array JSON

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetOverlays(
    p_page_number PLS_INTEGER DEFAULT NULL) RETURN JSON_ARRAY_T;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | `NULL` | filtrar por página ( NULL = todas) |

#### Retorno

JSON_ARRAY_T - Array de objetos de sobreposição [{ "overlayId": "OVL_001", "overlayType": "TEXT" | "IMAGE", "pageNumber": 1, "x": 100, "y": 700, "content": "APPROVED", // só para sobreposição de texto "opacity": 0.8, "rotation": 45, "zOrder": 100 }, ...]

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | Nenhum PDF carregado |

#### Exemplo

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

**Veja também:** [OverlayText](#overlaytext) · [RemoveOverlay](#removeoverlay)

---

### OverlayImage

Adicionar sobreposição de imagem em posição específica com controle de tamanho Desenhada por OutputModifiedPDF() no fluxo de conteúdo. No caminho comum nada é descomprimido: o JPEG entra inteiro como /DCTDecode, e os blocos IDAT do PNG já são zlib, que é o /FlateDecode do PDF — são concatenados e declarados com /Predictor 15, o que vale de 1 a 16 bits por componente. PNG com canal alfa (color types 4 e 6) e entrelaçado (Adam7) também são desenhados, por um caminho que reprocessa pixel a pixel — e por isso sai sem compressão, já que não há deflate neste trecho. Recusados com -20823, em vez de desenhados errado: entrelaçado com menos de 8 bits por componente, indexado E entrelaçado, e imagem acima do teto de pixels do caminho que reprocessa.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Número da página (base 1) |
| `p_image_blob` | BLOB | — | os bytes da imagem, em JPEG ou PNG |
| `p_x` | NUMBER | — | Posição X em pontos PDF |
| `p_y` | NUMBER | — | Posição Y (de baixo) (from bottom) |
| `p_width` | NUMBER | `NULL` | Largura em pontos ( NULL = original) |
| `p_height` | NUMBER | `NULL` | Altura em pontos ( NULL = original) |
| `p_options` | JSON_OBJECT_T | `NULL` | Configuração JSON (opcional) |

#### Nota

Opções (JSON_OBJECT_T): { "opacity": 1.0, // Opacidade 0.0 a 1.0 "rotation": 0, // Ângulo de rotação "maintainAspect": true, // Manter proporção "scaleToFit": false, // Escalar para caber "zOrder": 100 // Ordem da camada }

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | Nenhum PDF carregado |
| `ORA-20810` | Número de página inválido |
| `ORA-20821` | Coordenadas de posição inválidas |
| `ORA-20823` | formato de imagem inválido -- só JPEG ou PNG |
| `ORA-20824` | Dimensões da imagem inválidas |

#### Exemplo

```sql
DECLARE
  l_logo BLOB;
  l_options JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
  -- Adicionar logo no canto superior direito
  PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
  -- Marca d'água com transparência
  l_options.put('opacity', 0.3);
  l_options.put('rotation', 45);
  PL_FPDF.OverlayImage(1, l_watermark, 200, 400, 300, NULL, l_options);
  l_modified := PL_FPDF.OutputModifiedPDF();
END;
```

**Veja também:** [OverlayText](#overlaytext) · [Image](#image) · [GetOverlays](#getoverlays)

---

### OverlayText

Adicionar sobreposição de texto em posição específica com controle completo de formatação Desenhada por OutputModifiedPDF() no fluxo de conteúdo. x e y vão em pontos PDF, a partir do canto inferior esquerdo. Quando width é informado ele define a CAIXA do texto: as linhas quebram dentro dela e o align é relativo a [x, x+width]. Sem width não há o que quebrar, e o align passa a ser relativo ao próprio ponto — 'center' centraliza o texto em x, 'right' o termina em x.

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_page_number` | PLS_INTEGER | — | Número da página (base 1) |
| `p_text` | VARCHAR2 | — | Conteúdo do texto |
| `p_x` | NUMBER | — | Posição X (1 point = 1/72 inch, from left) |
| `p_y` | NUMBER | — | Posição Y (de baixo) (from bottom) |
| `p_options` | JSON_OBJECT_T | `NULL` | Configuração JSON (opcional) |

#### Nota

Opções (JSON_OBJECT_T): { "font": "Helvetica", // Nome da fonte "fontSize": 12, // Tamanho da fonte "color": "000000", // Cor RGB hexadecimal "opacity": 1.0, // Opacidade 0.0 a 1.0 "rotation": 0, // ângulo de rotação (0-360) "align": "left", // esquerda, centro, direita "width": null, // largura máxima (quebra sozinho) "bold": false, // Texto em negrito "zOrder": 100 // ordem da camada (maior fica por cima) }

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20809` | Nenhum PDF carregado |
| `ORA-20810` | Número de página inválido |
| `ORA-20821` | Coordenadas de posição inválidas, ou opacidade fora de 0.0..1.0 |

#### Exemplo

```sql
DECLARE
  l_options JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  PL_FPDF.LoadPDF(l_pdf);
  -- Sobreposição simples
  PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
  -- Texto formatado
  l_options.put('font', 'Helvetica-Bold');
  l_options.put('fontSize', 24);
  l_options.put('color', 'FF0000');  -- Vermelho
  l_options.put('opacity', 0.8);
  l_options.put('rotation', 45);
  PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
  l_modified := PL_FPDF.OutputModifiedPDF();
END;
```

**Veja também:** [OverlayImage](#overlayimage) · [GetOverlays](#getoverlays) · [AddWatermark](#addwatermark)

---

### RemoveOverlay

Remover sobreposição específica por ID

#### Sintaxe

```sql
PROCEDURE PL_FPDF.RemoveOverlay(
    p_overlay_id VARCHAR2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_overlay_id` | VARCHAR2 | — | ID da sobreposição () |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20825` | Sobreposição não encontrada |

#### Exemplo

```sql
PL_FPDF.RemoveOverlay('OVL_001');
```

**Veja também:** [GetOverlays](#getoverlays) · [ClearOverlays](#clearoverlays)

---

## Multi-PDF (merge, split, extract)

### ExtractPages

Extrair as páginas indicadas de um PDF carregado para um novo documento. A ordem pedida é respeitada ('5,1' devolve a página 5 e depois a 1) e uma página pode repetir. Só os objetos alcançáveis a partir das páginas escolhidas são copiados, então o resultado fica menor que a origem.

#### Sintaxe

```sql
FUNCTION PL_FPDF.ExtractPages(
    p_pdf_id  VARCHAR2,
    p_pages   VARCHAR2,
    p_options JSON_OBJECT_T DEFAULT NULL) RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identificador do PDF |
| `p_pages` | VARCHAR2 | — | Especificação: '1', '1,3,5-7,10', '5,1' ou 'ALL' |
| `p_options` | JSON_OBJECT_T | `NULL` | Configuração opcional (future use) |

#### Retorno

Novo PDF com páginas extraídas

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20831` | ID do PDF não encontrado |
| `ORA-20838` | Especificação de páginas inválida |
| `ORA-20839` | Número de página fora do intervalo |
| `ORA-20841` | Dicionário de objeto grande demais para renumerar |
| `ORA-20843` | xref em stream malformada |
| `ORA-20847` | object stream malformado |
| `ORA-20848` | predictor não suportado na xref em stream |

#### Exemplo

```sql
DECLARE
  l_extracted BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
  -- Extrair páginas 1, 5-10 e 15
  l_extracted := PL_FPDF.ExtractPages('manual', '1,5-10,15', NULL);
  INSERT INTO documents VALUES ('Summary', l_extracted);
END;
```

**Veja também:** [SplitPDF](#splitpdf) · [MergePDFs](#mergepdfs)

---

### GetLoadedPDFs

Obter lista de todos os IDs de PDF carregados e seus metadados

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetLoadedPDFs RETURN JSON_ARRAY_T;
```

#### Retorno

JSON_ARRAY_T - Array de objetos PDF [{ "pdfId": "report_jan", "pageCount": 5, "fileSize": 125678, "loadedDate": "2026-01-25T10:30:00" }, ...]

#### Exemplo

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

**Veja também:** [LoadPDFWithID](#loadpdfwithid) · [UnloadPDF](#unloadpdf)

---

### LoadPDFWithID

Carregar PDF em memória com identificador único para operações multi-documento

#### Sintaxe

```sql
PROCEDURE PL_FPDF.LoadPDFWithID(
    p_pdf_id   VARCHAR2,
    p_pdf_blob BLOB);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identificador único (max 50 chars) |
| `p_pdf_blob` | BLOB | — | Documento PDF como BLOB |

#### Nota

Máximo de 10 PDFs podem ser carregados simultaneamente

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20828` | ID do PDF já carregado |
| `ORA-20829` | Máximo de PDFs excedido (10 max) |
| `ORA-20830` | identificador vazio ou longo demais |
| `ORA-20800` | PDF nulo ou pequeno demais para ser válido |
| `ORA-20801` | cabeçalho %PDF-x.x ausente ou malformado |

#### Exemplo

```sql
BEGIN
  PL_FPDF.LoadPDFWithID('report_jan', l_jan_pdf);
  PL_FPDF.LoadPDFWithID('report_feb', l_feb_pdf);
  PL_FPDF.LoadPDFWithID('report_mar', l_mar_pdf);
END;
```

**Veja também:** [MergePDFs](#mergepdfs) · [SplitPDF](#splitpdf) · [ExtractPages](#extractpages) · [UnloadPDF](#unloadpdf) · [GetLoadedPDFs](#getloadedpdfs)

---

### MergePDFs

Mesclar múltiplos PDFs carregados em um único documento, na ordem dada. Todos os objetos de cada origem são copiados (páginas, fontes, imagens, anotações) com as referências indiretas renumeradas, e uma nova árvore de páginas é montada. Nada é re-renderizado: o conteúdo original chega intacto. O mesmo ID pode aparecer mais de uma vez.

#### Sintaxe

```sql
FUNCTION PL_FPDF.MergePDFs(
    p_pdf_ids JSON_ARRAY_T,
    p_options JSON_OBJECT_T DEFAULT NULL) RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf_ids` | JSON_ARRAY_T | — | Array JSON de IDs de PDF Example: JSON_ARRAY_T('["pdf1","pdf2","pdf3"]') |
| `p_options` | JSON_OBJECT_T | `NULL` | Configuração opcional (future use) |

#### Retorno

Documento PDF mesclado

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20832` | Nenhum ID de PDF fornecido |
| `ORA-20833` | ID de PDF na lista não carregado |
| `ORA-20834` | Mesclagem falhou |
| `ORA-20841` | Dicionário de objeto grande demais para renumerar |
| `ORA-20843` | xref em stream malformada |
| `ORA-20847` | object stream malformado |
| `ORA-20848` | predictor não suportado na xref em stream |

#### Exemplo

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

**Veja também:** [LoadPDFWithID](#loadpdfwithid) · [SplitPDF](#splitpdf) · [ExtractPages](#extractpages)

---

### SplitPDF

Dividir o PDF carregado em vários documentos, um por intervalo. Cada parte leva apenas os objetos alcançáveis a partir das suas páginas, e por isso fica bem menor que a origem. Os intervalos não podem se sobrepor.

#### Sintaxe

```sql
FUNCTION PL_FPDF.SplitPDF(
    p_pdf_id      VARCHAR2,
    p_page_ranges JSON_ARRAY_T) RETURN JSON_ARRAY_T;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identificador do PDF |
| `p_page_ranges` | JSON_ARRAY_T | — | Array de intervalos Examples: '1-5', '6-10', '11', '1,3,5', 'ALL' |

#### Retorno

Array com PDFs em base64, um por intervalo, sem quebras de linha

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20831` | ID do PDF não encontrado |
| `ORA-20835` | Nenhum intervalo fornecido |
| `ORA-20836` | Intervalos sobrepostos |
| `ORA-20838` | Especificação de páginas inválida |
| `ORA-20839` | Número de página fora do intervalo |
| `ORA-20843` | xref em stream malformada |
| `ORA-20847` | object stream malformado |
| `ORA-20848` | predictor não suportado na xref em stream |

#### Exemplo

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
    -- Processar cada parte
  END LOOP;
END;
```

**Veja também:** [ExtractPages](#extractpages) · [MergePDFs](#mergepdfs)

---

### UnloadPDF

Remover PDF específico da memória para liberar recursos

#### Sintaxe

```sql
PROCEDURE PL_FPDF.UnloadPDF(
    p_pdf_id VARCHAR2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf_id` | VARCHAR2 | — | Identificador do PDF |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20831` | ID do PDF não encontrado |

#### Exemplo

```sql
PL_FPDF.UnloadPDF('report_jan');
```

**Veja também:** [LoadPDFWithID](#loadpdfwithid) · [ClearPDFCache](#clearpdfcache)

---

## Segurança e criptografia

### DecryptPDF

Remover criptografia do PDF usando senha

#### Sintaxe

```sql
FUNCTION PL_FPDF.DecryptPDF(
    p_pdf      BLOB,
    p_password VARCHAR2) RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | PDF blob criptografado |
| `p_password` | VARCHAR2 | — | Senha de usuário ou owner |

#### Retorno

PDF descriptografado

#### Nota

Origem em PDF 1.5+ é achatada, e os object streams são decifrados antes de descomprimidos.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20853` | PDF não está criptografado |
| `ORA-20854` | Senha inválida |
| `ORA-20855` | Falha na descriptografia |
| `ORA-20861` | dicionário /Encrypt não encontrado no PDF |
| `ORA-20857` | versão de PDF inválida |

#### Exemplo

```sql
l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
```

**Veja também:** [EncryptPDF](#encryptpdf) · [IsEncrypted](#isencrypted)

---

### EncryptPDF

Criptografar PDF com proteção por senha seguindo especificação PDF

#### Sintaxe

```sql
FUNCTION PL_FPDF.EncryptPDF(
    p_pdf            BLOB,
    p_user_password  VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL,
    p_permissions    JSON_OBJECT_T DEFAULT NULL,
    p_encryption     VARCHAR2 DEFAULT 'RC4-128') RETURN BLOB;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | PDF blob para criptografar |
| `p_user_password` | VARCHAR2 | — | Senha para abrir documento |
| `p_owner_password` | VARCHAR2 | `NULL` | senha de acesso total (opcional) |
| `p_permissions` | JSON_OBJECT_T | `NULL` | JSON com flags de permissão |
| `p_encryption` | VARCHAR2 | `'RC4-128'` | Encryption method: 'RC4-40','RC4-128','AES-128','AES-256' |

#### Retorno

PDF criptografado

#### Nota

Origem em PDF 1.5+ (xref em stream, object streams) é achatada: os objetos de dentro dos object streams viram objetos de primeiro nível e a saída leva xref clássica.

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20850` | Método de criptografia inválido |
| `ORA-20851` | Senha obrigatória |
| `ORA-20852` | Falha na criptografia |
| `ORA-20859` | o PDF já está cifrado; decifre antes |
| `ORA-20860` | PDF inválido: /Root não encontrado no trailer |
| `ORA-20863` | chave RC4 vazia |
| `ORA-20864` | conteúdo acima do limite que o RC4 desta base trata |

#### Exemplo

```sql
l_encrypted := PL_FPDF.EncryptPDF(
  p_pdf => l_pdf,
  p_user_password => 'user123',
  p_owner_password => 'owner456',
  p_permissions => JSON_OBJECT_T('{"print":true,"copy":false}'),
  p_encryption => 'AES-128'
);
```

**Veja também:** [DecryptPDF](#decryptpdf) · [IsEncrypted](#isencrypted) · [SetEncryption](#setencryption) · [SetPermissions](#setpermissions)

---

### GetPDFVersion

Obter a configuração atual de versão do PDF

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetPDFVersion RETURN VARCHAR2;
```

#### Retorno

VARCHAR2 - a versão de PDF corrente (por exemplo '1.4')

**Veja também:** [SetPDFVersion](#setpdfversion)

---

### GetSecurityInfo

Obter informações de segurança do PDF

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetSecurityInfo(
    p_pdf BLOB) RETURN JSON_OBJECT_T;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | PDF blob |

#### Retorno

JSON_OBJECT_T - Security info including: - encrypted: boolean - method: string (RC4-40, RC4-128, AES-128, AES-256) - permissions: object with print, copy, modify, etc. - hasUserPassword: boolean - hasOwnerPassword: boolean

#### Exemplo

```sql
l_info := PL_FPDF.GetSecurityInfo(l_pdf);
IF l_info.get_boolean('encrypted') THEN ...
```

**Veja também:** [IsEncrypted](#isencrypted) · [EncryptPDF](#encryptpdf)

---

### IsEncrypted

Verificar se PDF está criptografado

#### Sintaxe

```sql
FUNCTION PL_FPDF.IsEncrypted(
    p_pdf BLOB) RETURN BOOLEAN;
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_pdf` | BLOB | — | PDF blob para verificar |

#### Retorno

TRUE se criptografado

#### Exemplo

```sql
IF PL_FPDF.IsEncrypted(l_pdf) THEN ...
```

**Veja também:** [GetSecurityInfo](#getsecurityinfo) · [DecryptPDF](#decryptpdf)

---

### SetEncryption

Definir criptografia para PDF em geração (usar antes do Output)

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetEncryption(
    p_encryption     VARCHAR2,
    p_user_password  VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_encryption` | VARCHAR2 | — | Method: 'RC4-40','RC4-128','AES-128','AES-256' |
| `p_user_password` | VARCHAR2 | — | Senha para abrir |
| `p_owner_password` | VARCHAR2 | `NULL` | Senha acesso total |

#### Nota

Mapeamento de Versão: RC4-40/RC4-128 -> PDF 1.4 AES-128 -> PDF 1.5 AES-256 -> PDF 1.7

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20850` | método de cifragem não suportado |
| `ORA-20851` | senha inválida |

#### Exemplo

```sql
PL_FPDF.Init;
PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
PL_FPDF.AddPage;
l_pdf := PL_FPDF.OutputBlob;
```

**Veja também:** [SetPermissions](#setpermissions) · [EncryptPDF](#encryptpdf)

---

### SetPDFVersion

Definir a versão do PDF para documentos gerados

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetPDFVersion(
    p_version VARCHAR2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_version` | VARCHAR2 | — | PDF version: '1.4', '1.5', '1.6', '1.7', '2.0' |

#### Nota

Recursos por Versão: 1.4: cifra RC4 de 128 bits, transparência 1.5: AES de 128 bits, object streams, cross-reference streams 1.6: AES de 128 bits, fontes OpenType 1.7: AES de 256 bits, formulários XFA 2.0: só AES de 256 bits, sem RC4

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20857` | versão de PDF inválida; só 1.4, 1.5, 1.6, 1.7 ou 2.0 |
| `ORA-20858` | AES-128 exige PDF 1.5 ou maior, e AES-256 exige 1.7 |

#### Exemplo

```sql
PL_FPDF.SetPDFVersion('1.5');
```

**Veja também:** [GetPDFVersion](#getpdfversion)

---

### SetPermissions

Definir permissões do documento (requer SetEncryption antes)

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

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_print` | BOOLEAN | `TRUE` | Permitir impressão |
| `p_modify` | BOOLEAN | `FALSE` | Permitir modificação |
| `p_copy` | BOOLEAN | `FALSE` | Permitir cópia/extração |
| `p_annotate` | BOOLEAN | `TRUE` | Permitir anotações |
| `p_fill_forms` | BOOLEAN | `TRUE` | Permitir preenchimento de formulários |
| `p_extract` | BOOLEAN | `FALSE` | Permitir extração de conteúdo |
| `p_assemble` | BOOLEAN | `FALSE` | Permitir montagem de documento |
| `p_print_high` | BOOLEAN | `TRUE` | Permitir impressão alta qualidade |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20856` | SetEncryption tem de ser chamada antes |

#### Exemplo

```sql
PL_FPDF.SetEncryption('AES-128', 'user', 'owner');
PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE, p_modify => FALSE);
```

**Veja também:** [SetEncryption](#setencryption) · [EncryptPDF](#encryptpdf)

---

## Diagnóstico e utilidades

### DebugDisabled

Desliga a saída de diagnóstico. É o estado padrão.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.DebugDisabled;
```

#### Exemplo

```sql
PL_FPDF.DebugDisabled;
```

**Veja também:** [SetLogLevel](#setloglevel)

---

### DebugEnabled

Liga a saída de diagnóstico do tratamento de erro. Serve para depuração; num processo em produção deixa o erro mais verboso.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.DebugEnabled;
```

#### Exemplo

```sql
PL_FPDF.DebugEnabled;
```

**Veja também:** [SetLogLevel](#setloglevel)

---

### Error

Levanta ORA-20100 com a mensagem dada, acrescentando o rastro da origem e preservando a pilha original (keeperrorstack) -- é isso que mantém rastreável o erro de verdade por trás do -20100. É o caminho interno de erro da biblioteca; está público por herança.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.Error(
    pmsg varchar2);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `pmsg` | VARCHAR2 | — | a mensagem |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | sempre; é o que esta rotina faz |

#### Exemplo

```sql
PL_FPDF.Error('nao foi possivel montar o documento');
```

---

### GetLogLevel

Devolve o nível de registro em uso.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetLogLevel RETURN PLS_INTEGER;
```

#### Retorno

PLS_INTEGER - o nível corrente (0-4)

#### Exemplo

```sql
l_nivel := PL_FPDF.GetLogLevel;
```

**Veja também:** [SetLogLevel](#setloglevel)

---

### GetScaleFactor

Devolve quantos pontos PDF valem uma unidade corrente -- 2,8346 para milímetro, 1 para ponto. É o número que converte entre a unidade do chamador e a do arquivo.

#### Sintaxe

```sql
FUNCTION PL_FPDF.GetScaleFactor RETURN NUMBER;
```

#### Retorno

NUMBER - pontos por unidade

#### Exemplo

```sql
l_pontos := 10 * PL_FPDF.GetScaleFactor;
```

**Veja também:** [Init](#init)

---

### SetLogLevel

Define quanta informação a biblioteca escreve no DBMS_OUTPUT.

#### Sintaxe

```sql
PROCEDURE PL_FPDF.SetLogLevel(
    p_level pls_integer);
```

#### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `p_level` | PLS_INTEGER | — | 0 desligado (OFF), 1 erro (ERROR), 2 aviso (WARN), 3 informação (INFO), 4 depuração (DEBUG) |

#### Erros

| Código | Quando |
|--------|--------|
| `ORA-20100` | nível fora da faixa 0..4 |

#### Exemplo

```sql
PL_FPDF.SetLogLevel(3);
```

**Veja também:** [GetLogLevel](#getloglevel) · [DebugEnabled](#debugenabled)

---

