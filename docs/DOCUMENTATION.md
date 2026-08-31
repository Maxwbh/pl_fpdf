# PL_FPDF — Referência Completa de Uso

**Versão:** 3.3.0 | **Oracle:** 19c+ | **Licença:** MIT

> Guia oficial de todas as funcionalidades do PL_FPDF: o que cada API faz e como usá-la.
> Versão navegável no site: [maxwbh.github.io/pl_fpdf/api.html](https://maxwbh.github.io/pl_fpdf/api.html) ·
> English version: [DOCUMENTATION_EN.md](DOCUMENTATION_EN.md)

## Índice

1. [Instalação e ciclo de vida](#1-instalação-e-ciclo-de-vida)
2. [Páginas e posicionamento](#2-páginas-e-posicionamento)
3. [Fontes e UTF-8](#3-fontes-e-utf-8)
4. [Escrita de texto](#4-escrita-de-texto)
5. [Cores e desenho](#5-cores-e-desenho)
6. [Imagens](#6-imagens)
7. [Links](#7-links)
8. [Cabeçalho e rodapé](#8-cabeçalho-e-rodapé)
9. [QR Code e código de barras](#9-qr-code-e-código-de-barras)
10. [Metadados e configuração do documento](#10-metadados-e-configuração-do-documento)
11. [Saída (gerar o PDF)](#11-saída-gerar-o-pdf)
12. [Manipulação de PDF existente](#12-manipulação-de-pdf-existente)
13. [Overlays (texto/imagem sobre PDF existente)](#13-overlays)
14. [Multi-PDF: merge, split e extração](#14-multi-pdf-merge-split-e-extração)
15. [Segurança e criptografia](#15-segurança-e-criptografia)
16. [Diagnóstico e utilidades](#16-diagnóstico-e-utilidades)
17. [Migração da v0.9.4](#17-migração-da-v094)
18. [Códigos de erro](#18-códigos-de-erro)

---

## Como passar parâmetros

Todas as APIs aceitam as duas notações do PL/SQL:

```sql
-- Posicional (ordem da assinatura)
PL_FPDF.Cell(0, 10, 'Olá', '1', 1, 'C');

-- Nomeada (recomendada: legível e imune a mudanças de ordem)
PL_FPDF.Cell(
  pw      => 0,        -- largura; 0 = até a margem direita
  ph      => 10,       -- altura da célula
  ptxt    => 'Olá',
  pborder => '1',      -- '0' | '1' | combinação de 'L','T','R','B'
  pln     => 1,        -- 0 = cursor à direita | 1 = próxima linha | 2 = abaixo
  palign  => 'C'       -- 'L' | 'C' | 'R'
);

-- Misturada (posicionais primeiro, nomeados depois)
PL_FPDF.Cell(0, 10, 'Olá', palign => 'C');
```

Convenções recorrentes na biblioteca:

| Convenção | Significado | Exemplo |
|-----------|-------------|---------|
| Parâmetro com `DEFAULT` | Pode ser omitido | `AddPage()` = `AddPage(NULL, NULL, 0)` |
| Cores `r, g, b` | RGB 0–255; só `r` = tom de cinza | `SetFillColor(230, 230, 230)` |
| Medidas | Na unidade do `Init` (mm, cm, pt, in); largura/altura `0` = automático/proporcional | `Cell(0, 10, ...)`, `Image(..., pWidth => 40, pHeight => 0)` |
| Faixas de páginas `VARCHAR2` | Lista e intervalos; `'ALL'` = todas; `'21-'` = até o fim | `'1,3-5,10'` |
| Opções em `JSON_OBJECT_T` | Chaves opcionais; ausentes assumem o padrão | `l_op.put('opacity', 0.5)` |
| Coordenadas de overlay | Pontos PDF (1 pt = 1/72"), Y de baixo para cima | `OverlayText(1, 'OK', 400, 700)` |
| Booleanos | `TRUE`/`FALSE` do PL/SQL | `SetAutoPageBreak(TRUE, 15)` |

---

## 1. Instalação e ciclo de vida

Baixe `dist/pl_fpdf_install.sql` e execute: é um arquivo só, com os dois
packages na ordem de dependência, e só SQL — roda igual na SQL Window do PL/SQL
Developer e no SQL\*Plus.

```sql
-- Verificar
SELECT PL_FPDF.co_version FROM DUAL;  -- 3.3.0

-- Os dois objetos precisam sair VALID
SELECT object_name, object_type, status FROM user_objects
 WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL');
```

### Init — inicia um documento novo

```sql
PL_FPDF.Init(
  p_orientation => 'P',      -- 'P' retrato | 'L' paisagem
  p_unit        => 'mm',     -- 'mm', 'cm', 'pt', 'in'
  p_format      => 'A4',     -- 'A4', 'A3', 'A5', 'Letter', 'Legal'
  p_encoding    => 'UTF-8'
);
```

Toda geração começa por `Init`. O estado vive na sessão (package-only, sem tabelas).

### Reset — limpa tudo

```sql
PL_FPDF.Reset;  -- libera CLOBs temporários e zera o estado
```

Use ao final de jobs longos ou entre documentos em loop.

### IsInitialized

```sql
IF NOT PL_FPDF.IsInitialized THEN PL_FPDF.Init; END IF;
```

---

## 2. Páginas e posicionamento

| API | O que faz |
|-----|-----------|
| `AddPage(p_orientation, p_format, p_rotation)` | Nova página; parâmetros NULL herdam do `Init`. Rotação: 0/90/180/270 |
| `SetPage(p_page_number)` | Volta a uma página existente para escrever nela |
| `GetCurrentPage` / `PageNo` | Página ativa / total corrente |
| `SetMargins(left, top, right)` | Margens; também `SetLeftMargin`, `SetTopMargin`, `SetRightMargin` |
| `SetAutoPageBreak(pauto, pMargin)` | Quebra automática ao atingir a margem inferior |
| `Ln(h)` | Pula linha (altura `h`, ou a última usada) |
| `GetX`/`SetX`, `GetY`/`SetY`, `SetXY` | Cursor de escrita em unidades do documento |

```sql
PL_FPDF.Init(p_orientation => 'P', p_unit => 'mm', p_format => 'A4');

PL_FPDF.SetMargins(
  left  => 20,                 -- margem esquerda (mm, unidade do Init)
  top   => 15,                 -- margem superior
  right => 20                  -- omitido/-1 = igual à esquerda
);
PL_FPDF.SetAutoPageBreak(
  pauto   => TRUE,             -- quebra automática ao chegar ao fim
  pMargin => 15                -- distância da borda inferior que dispara a quebra
);

PL_FPDF.AddPage;                                 -- página 1 (herda tudo do Init)
PL_FPDF.AddPage(p_orientation => 'L');           -- página 2 em paisagem
PL_FPDF.AddPage(p_format => 'A5', p_rotation => 90);  -- página 3: A5 rotacionada

PL_FPDF.SetPage(1);            -- volta a escrever na página 1
PL_FPDF.SetXY(x => 20, y => 40);   -- posiciona o cursor
```

---

## 3. Fontes e UTF-8

### Fontes padrão

```sql
PL_FPDF.SetFont('Arial', 'B', 16);   -- família, estilo ('', 'B', 'I', 'BI', 'U'), tamanho pt
PL_FPDF.SetFontSize(11);             -- muda só o tamanho
```

Famílias core: `Arial/Helvetica`, `Times`, `Courier`, `Symbol`, `ZapfDingbats`.

### Fontes TrueType (acentuação completa, fontes corporativas)

```sql
-- Carregar TTF de um BLOB (ex.: tabela de assets)
PL_FPDF.AddTTFFont(
  p_font_name => 'Roboto',
  p_font_blob => l_ttf_blob,
  p_encoding  => 'UTF-8',
  p_embed     => TRUE        -- embutir no PDF
);

-- Ou direto de um DIRECTORY Oracle
PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');

PL_FPDF.SetFont('Roboto', '', 12);
```

Auxiliares: `IsTTFFontLoaded(nome)`, `GetTTFFontInfo(nome)`, `ClearTTFFontCache`.

### UTF-8

```sql
PL_FPDF.SetUTF8Enabled(TRUE);        -- padrão; acentos funcionam nativamente
IF PL_FPDF.IsUTF8Enabled THEN ... END IF;
```

---

## 4. Escrita de texto

### Cell — bloco retangular (a API mais usada)

```sql
PL_FPDF.Cell(
  pw      => 0,          -- largura (0 = até a margem direita)
  ph      => 10,         -- altura
  ptxt    => 'Olá!',
  pborder => '1',        -- '0' sem, '1' moldura, ou 'LTRB' combinados
  pln     => 1,          -- 0 = cursor à direita | 1 = próxima linha | 2 = abaixo
  palign  => 'C',        -- 'L', 'C', 'R'
  pfill   => 0,          -- 1 = preenche com a cor de SetFillColor
  plink   => ''          -- URL ou link interno
);
```

### MultiCell — parágrafo com quebra automática

```sql
l_linhas := PL_FPDF.MultiCell(0, 6, l_texto_longo, '1', 'J');  -- retorna nº de linhas
-- ou a versão procedure, sem retorno
```

### Write — texto fluido (estilo HTML inline)

```sql
PL_FPDF.Write(6, 'Texto que continua ');
PL_FPDF.SetFont('Arial','B');
PL_FPDF.Write(6, 'em negrito');
```

### Texto rotacionado

```sql
PL_FPDF.CellRotated(40, 10, 'VERTICAL', p_rotation => 90);   -- 0/90/180/270
PL_FPDF.WriteRotated(6, 'Diagonal não; apenas retos', p_rotation => 270);
```

### Outros

| API | Uso |
|-----|-----|
| `Text(px, py, ptxt)` | Texto em posição absoluta, sem mover o cursor |
| `GetStringWidth(pstr)` | Largura do texto na fonte atual (para centralizar/medir) |
| `SetLineSpacing(pls)` / `GetLineSpacing` | Espaçamento entre linhas |

---

## 5. Cores e desenho

```sql
PL_FPDF.SetDrawColor(200, 0, 0);      -- contorno (RGB 0-255)
PL_FPDF.SetFillColor(240, 240, 240);  -- preenchimento
PL_FPDF.SetTextColor(0, 0, 0);        -- texto
PL_FPDF.SetLineWidth(0.5);

PL_FPDF.Line(10, 30, 200, 30);
PL_FPDF.Rect(10, 40, 60, 25, 'DF');   -- '' contorno | 'F' preenchido | 'DF' ambos
PL_FPDF.Triangle(50, 100, 20, 'up', 'D');  -- ponta para cima, so contorno
                                      -- (o 4o argumento e a ORIENTACAO,
                                      --  o 5o e o estilo)
PL_FPDF.Poly(l_pontos, TRUE, 'D');    -- polígono por tabela de pontos

PL_FPDF.SetDash(2, 2);                       -- tracejado simples
PL_FPDF.SetLineDashPattern('[3 2] 0');       -- padrão PDF nativo
```

---

## 6. Imagens

```sql
PL_FPDF.Image(
  pFile   => 'logo.png',    -- nome do arquivo (DIRECTORY) ou URL registrada
  pX      => 10,            -- posição X na unidade do documento
  pY      => 10,            -- posição Y
  pWidth  => 40,            -- largura; 0 = calcula pela altura
  pHeight => 0,             -- altura; 0 = mantém a proporção da largura
  pType   => NULL,          -- 'PNG' | 'JPG' | NULL = autodetecta
  pLink   => NULL           -- URL/link interno opcional (imagem clicável)
);

-- Imagem vinda de URL (via UTL_HTTP)
l_img := PL_FPDF.getImageFromUrl('https://exemplo.com/logo.png');
```

Formatos: **PNG** e **JPEG**.

### O que o overlay de imagem aceita

`OverlayImage` (seção 13) recebe o BLOB direto e cobre mais casos:

| Caso | Como sai |
|------|----------|
| JPEG | entra inteiro, `/DCTDecode` — quem decodifica é o leitor |
| PNG RGB, cinza ou indexado | passa direto, comprimido, de 1 a **16** bits |
| PNG com **canal alfa** | a transparência vira um `/SMask`, porque o PDF não a guarda dentro do pixel |
| PNG **entrelaçado** (Adam7) | as sete passagens são remontadas |

Os dois últimos exigem reprocessar os pixels, e a imagem sai **sem
compressão** — o arquivo fica maior. Esse caminho tem teto de **4 megapixels**;
acima disso `ORA-20823` pede que a imagem seja regravada sem alfa (ou achatada
sobre um fundo) e sem entrelaçar.

Seguem recusados: entrelaçado com menos de 8 bits por componente, e indexado
**e** entrelaçado ao mesmo tempo.

---

## 7. Links

```sql
l_link := PL_FPDF.AddLink;                 -- cria link interno
PL_FPDF.SetLink(l_link, 0, 3);             -- destino: topo da página 3
PL_FPDF.Cell(60, 8, 'Ir ao capítulo 3', plink => l_link);
PL_FPDF.Cell(60, 8, 'Site', plink => 'https://maxwbh.github.io/pl_fpdf/');
PL_FPDF.Link(10, 10, 50, 12, 'https://...');   -- área clicável arbitrária
```

---

## 8. Cabeçalho e rodapé

Registre procedures suas para rodarem a cada página:

```sql
-- No seu package:
PROCEDURE meu_header(p1 IN VARCHAR2, p2 IN VARCHAR2) IS ...
PROCEDURE meu_footer IS
BEGIN
  PL_FPDF.SetY(-15);
  PL_FPDF.SetFont('Arial','I',8);
  PL_FPDF.Cell(0, 10, 'Página ' || PL_FPDF.PageNo || '/{nb}', 0, 0, 'C');
END;

-- Na geração:
-- tv4000a é um associative array indexado pelo NOME do parâmetro:
-- declare uma variável e preencha por chave (não existe construtor tv4000a(...)).
--   l_p PL_FPDF.tv4000a;
--   l_p('p_titulo') := 'Título';
PL_FPDF.SetHeaderProc('meu_pkg.meu_header', l_p);
PL_FPDF.SetFooterProc('meu_pkg.meu_footer');
PL_FPDF.SetAliasNbPages;   -- habilita o placeholder {nb} = total de páginas
```

---

## 9. QR Code e código de barras

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

O `ITF` é o do **boleto bancário**: Interleaved 2 of 5 puro, qualquer quantidade
par de dígitos, sem dígito verificador de simbologia — o de controle do boleto
fica dentro dos 44, na posição 5. O `ITF14` é o caso particular de 14 dígitos,
com verificador próprio.

> **O `p_code` chega pronto.** O `AddBarcode` desenha os dígitos que você passa;
> ele não os calcula. Montar o código de barras de um boleto a partir de banco,
> vencimento, valor e campo livre é regra de cobrança, e fica fora desta
> biblioteca.

> **Exemplo completo:** [`examples/boleto.sql`](../examples/boleto.sql) desenha
> o layout de um boleto inteiro — duas vias, 50 caixas, três variantes de
> Helvetica e o código de barras de 44 dígitos —, tudo em PL/SQL e sem nenhuma
> imagem.

> **QR e código de barras juntos:** [`examples/ticket.sql`](../examples/ticket.sql)
> desenha um ingresso de evento com o mesmo código em duas simbologias — QR
> Code e Code 39 —, em duas páginas e com painéis coloridos.

---

## 10. Metadados e configuração do documento

```sql
PL_FPDF.SetTitle('Relatório Mensal');
PL_FPDF.SetSubject('Fechamento');
PL_FPDF.SetAuthor('M&S do Brasil');
PL_FPDF.SetKeywords('relatorio, oracle, pdf');
PL_FPDF.SetCreator('Meu ERP');

PL_FPDF.SetDisplayMode('fullpage', 'single');  -- zoom e layout iniciais no leitor
PL_FPDF.SetCompression(TRUE);                  -- comprime o conteúdo das páginas

-- Em lote, via JSON:
PL_FPDF.SetDocumentConfig(JSON_OBJECT_T('{"title":"Relatório","author":"M&S"}'));

l_meta := PL_FPDF.GetDocumentMetadata;         -- JSON com os metadados atuais
l_info := PL_FPDF.GetPageInfo(1);              -- dimensões/rotação da página
```

---

## 11. Saída (gerar o PDF)

| API | Quando usar |
|-----|-------------|
| `OutputBlob` / `OutputBlob` **RETURN BLOB** | Padrão: devolve o PDF para gravar em tabela, enviar por e-mail, APEX etc. |
| `OutputFile(p_filename, p_directory)` | Grava direto num DIRECTORY Oracle |
| `ReturnBlob(pname, pdest)` | Compatibilidade com código legado |
| `Output(pname, pdest)` | Compatibilidade FPDF clássica |

```sql
l_pdf := PL_FPDF.OutputBlob;
INSERT INTO documentos (pdf) VALUES (l_pdf);
-- ou
PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
```

### Entregar o PDF a um navegador

O `Output` com `'I'`, `'D'` ou `'S'` **não existe mais** desde a 2.x: levanta
`ORA-20306`. Aqueles modos mandavam os cabeçalhos HTTP por você. Agora a
biblioteca devolve o BLOB e **quem entrega é a sua aplicação** — inclusive o
cabeçalho.

Isso importa mais do que parece. Sem `Content-Type: application/pdf`, o
navegador pode tratar a resposta como HTML e mostrar o **fonte do PDF na tela**
— `%PDF-1.3`, `3 0 obj`, `stream`. Parece corrupção de caracteres e não é: o
arquivo está perfeito, só chegou rotulado errado.

E o sintoma engana porque **depende do navegador**. Firefox e Edge farejam a
assinatura `%PDF-` e corrigem sozinhos; Chrome e Opera obedecem ao tipo
declarado. O mesmo relatório abre num e quebra no outro, e some quando o
servidor manda `X-Content-Type-Options: nosniff`.

**Pelo gateway PL/SQL (mod_plsql):**

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- ... monta o documento ...
  l_pdf := PL_FPDF.OutputBlob();

  owa_util.mime_header('application/pdf', FALSE);
  htp.p('Content-Length: ' || DBMS_LOB.GETLENGTH(l_pdf));
  htp.p('Content-Disposition: inline; filename="relatorio.pdf"');
  owa_util.http_header_close();
  wpg_docload.download_file(l_pdf);
END;
```

`inline` abre no navegador; `attachment` força o download.

**Por ORDS:** declare o handler como recurso de mídia e devolva
`application/pdf` na coluna de content type.

**Por APEX:** `apex_util.download`, ou defina o Content-Type no processo e
encerre com `apex_application.stop_apex_engine`.

Duas armadilhas que produzem exatamente o mesmo sintoma:

| | |
|---|---|
| **Escrita antes do cabeçalho** | Um `htp.p` de depuração, ou uma mensagem de um `EXCEPTION`, vai para o buffer **antes** dos cabeçalhos e corrompe a resposta inteira |
| **`Content-Length` errado** | Se não bater com o tamanho real, ou faltar, alguns navegadores voltam a adivinhar o tipo |

Para conferir em dez segundos: F12 → aba **Network** → recarregue → clique na
requisição → **Response Headers**. Se o `Content-Type` não for
`application/pdf`, é isso.

---

## 12. Manipulação de PDF existente

Fluxo: `LoadPDF` → inspecionar/modificar → `OutputModifiedPDF`.

Vale para PDF de qualquer produtor, inclusive **PDF 1.5+** — onde a referência
cruzada é um stream comprimido e os objetos ficam dentro de *object streams*. O
conteúdo das páginas é copiado byte a byte, sem re-renderizar: fontes, imagens e
anotações chegam intactas.

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documentos WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);

  DBMS_OUTPUT.PUT_LINE('Páginas: ' || PL_FPDF.GetPageCount);
  DBMS_OUTPUT.PUT_LINE(PL_FPDF.GetPDFInfo().to_string);   -- versão, metadados…

  PL_FPDF.RotatePage(1, 90);            -- 0/90/180/270
  PL_FPDF.RemovePage(3);                -- remoção lógica
  PL_FPDF.AddWatermark(
    p_text     => 'CONFIDENCIAL',
    p_opacity  => 0.3,
    p_rotation => 45,
    p_pages    => 'ALL',                -- ou '1,3-5'
    p_font     => 'Helvetica',
    p_size     => 48,
    p_color    => 'gray'
  );

  l_pdf := PL_FPDF.OutputModifiedPDF;   -- PDF final com as alterações
  PL_FPDF.ClearPDFCache;                -- libera memória
END;
```

Consultas de estado: `GetActivePageCount`, `IsPageRemoved(n)`, `IsPDFModified`,
`GetWatermarks` (JSON com todas as marcas aplicadas).

---

## 13. Overlays

Sobrepõe conteúdo em posições exatas de um PDF carregado (carimbos, assinaturas, logos).
Coordenadas em **pontos PDF** (1 pt = 1/72"), com **Y a partir de baixo**.

### OverlayText

```sql
PL_FPDF.OverlayText(
  p_page_number => 1,
  p_text        => 'APROVADO',
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
  p_image_blob  => l_logo,        -- JPEG ou PNG
  p_x => 450, p_y => 750,
  p_width => 100, p_height => 50, -- NULL = tamanho original
  p_options => JSON_OBJECT_T('{"opacity":0.9,"maintainAspect":true}')
);
```

Gestão: `GetOverlays(pagina)` (lista em JSON), `RemoveOverlay(id)`, `ClearOverlays(pagina)`.
O resultado sai no mesmo `OutputModifiedPDF`.

---

## 14. Multi-PDF: merge, split e extração

Vários PDFs em memória simultaneamente, cada um com um ID:

```sql
PL_FPDF.LoadPDFWithID(l_capa,     'capa');
PL_FPDF.LoadPDFWithID(l_conteudo, 'conteudo');
PL_FPDF.LoadPDFWithID(l_anexos,   'anexos');

-- Mesclar na ordem desejada
l_final := PL_FPDF.MergePDFs(JSON_ARRAY_T('["capa","conteudo","anexos"]'));

-- Dividir por intervalos → array de BLOBs (JSON com os resultados)
l_partes := PL_FPDF.SplitPDF('conteudo', JSON_ARRAY_T('["1-10","11-20","21-"]'));

-- Extrair páginas específicas para um novo PDF
l_resumo := PL_FPDF.ExtractPages('conteudo', '1,5-10,15');

PL_FPDF.UnloadPDF('anexos');          -- libera um
l_lista := PL_FPDF.GetLoadedPDFs;     -- JSON com os IDs carregados
```

---

## 15. Segurança e criptografia

### Proteger um PDF pronto

```sql
DECLARE
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_perms.put('print', TRUE);
  l_perms.put('copy',  FALSE);
  l_perms.put('modify',FALSE);

  l_seguro := PL_FPDF.EncryptPDF(
    p_pdf            => l_pdf,
    p_user_password  => 'senhaLeitura',
    p_owner_password => 'senhaAdmin',     -- NULL = igual à de usuário
    p_permissions    => l_perms,
    p_encryption     => 'AES-256'         -- ou 'AES-128', 'RC4-128', 'RC4-40'
  );
END;
```

> **Prefira AES.** O RC4 está quebrado há anos e o PDF 2.0 o removeu da
> especificação; leitores novos avisam ou recusam. `'RC4-128'` continua sendo o
> padrão do parâmetro apenas por compatibilidade com quem já chamava assim.
>
> Origem em **PDF 1.5+** é achatada: os objetos que moram dentro de *object
> streams* viram objetos de primeiro nível e a saída leva xref clássica. Vale
> para os dois sentidos — ao decifrar, o object stream é decifrado antes de ser
> descomprimido.

### Demais APIs

| API | O que faz |
|-----|-----------|
| `DecryptPDF(p_pdf, p_password)` | Remove a proteção (exige a senha) |
| `IsEncrypted(p_pdf)` | TRUE se o BLOB está criptografado |
| `GetSecurityInfo(p_pdf)` | JSON: algoritmo, tamanho de chave, permissões |
| `SetEncryption(p_encryption, p_user_password, p_owner_password)` | Define criptografia **antes** do `OutputBlob` (documento novo) |
| `SetPermissions(p_print, p_modify, p_copy, p_annotate, p_fill_forms, p_extract, p_assemble, p_print_high)` | Permissões do documento novo |
| `SetPDFVersion('1.7')` / `GetPDFVersion` | Versão do arquivo PDF gerado |

> **Senha não é assinatura.** A criptografia acima protege o arquivo — quem
> abre, quem imprime, quem copia. Ela não atesta autoria nem detecta
> adulteração. Assinatura digital está no [roadmap](ROADMAP.md).

---

## 16. Diagnóstico e utilidades

```sql
PL_FPDF.SetLogLevel(3);              -- 0=off … níveis de verbosidade
PL_FPDF.DebugEnabled;                -- atalhos
PL_FPDF.DebugDisabled;
```

---

## 17. Migração da v0.9.4

```sql
-- ANTES (v0.9.4)                    -- AGORA (v2.0+)
PL_FPDF.fpdf('P','mm','A4');         PL_FPDF.Init('P','mm','A4');
l_pdf := PL_FPDF.Output('S');        l_pdf := PL_FPDF.OutputBlob;
PL_FPDF.Output('F', caminho);        PL_FPDF.OutputFile(nome, directory);
```

| v0.9.4 | v2.0+ |
|--------|-------|
| `fpdf()` | `Init()` (o `fpdf()` segue disponível por compatibilidade) |
| `Output('S')` | `OutputBlob` |
| UTF-8 limitado | UTF-8 completo + TrueType |
| Sem criptografia | AES-256, AES-128 e RC4 |

---

## 18. Códigos de erro

| Faixa | Área | Exemplos |
|-------|------|----------|
| -20005 | Ciclo de vida | uso antes do `Init` |
| -20101…-20107 | Páginas | formato desconhecido, orientação, rotação, página inexistente |
| -20110/-20111 | Texto | rotação inválida (só 0/90/180/270) |
| -20301…-20303 | Imagens | header inválido, falha ao buscar da URL, formato não suportado |
| -20800…-20810 | LoadPDF | PDF inválido, header/xref/trailer corrompidos; nenhum PDF carregado |
| -20821…-20825 | Overlays | coordenadas, opacidade, imagem ou dimensões inválidas |
| -20831…-20844 | Multi-PDF | ID não encontrado; especificação de páginas inválida |
| -20843/-20847/-20848 | PDF 1.5+ | xref em stream, object stream ou predictor que não dá para ler |
| -20850…-20865 | Segurança | senha, método de criptografia, PDF já protegido |
| -20870…-20879 | QR Code | conteúdo vazio, tamanho, nível de correção, capacidade |
| -20880…-20889 | Código de barras | código vazio, dimensões, simbologia, dígitos |
| -20890…-20894 | `FlateDecode` | stream inválido ou saída acima do teto |

A lista completa, erro a erro e por API, está em
[API_REFERENCE.md](API_REFERENCE.md).

---

## Suporte

- **Autor:** Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))
- **Mantenedora:** [M&S do Brasil LTDA](https://msbrasil.inf.br)
- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues) · **Dúvidas:** [Discussions](https://github.com/Maxwbh/pl_fpdf/discussions)
- **E-mail:** contato@msbrasil.inf.br
