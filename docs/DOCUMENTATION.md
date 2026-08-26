# PL_FPDF — Referência Completa de Uso

**Versão:** 3.2.0 | **Oracle:** 19c+ | **Licença:** MIT

> Guia oficial de todas as funcionalidades do PL_FPDF: o que cada API faz e como usá-la.
> Versão navegável no site: [maxwbh.github.io/pl_fpdf/api.html](https://maxwbh.github.io/pl_fpdf/api.html)

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

## 1. Instalação e ciclo de vida

```sql
-- Instalar
@deploy_all.sql

-- Verificar
SELECT PL_FPDF.co_version FROM DUAL;  -- 3.2.0
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
PL_FPDF.Init('P','mm','A4');
PL_FPDF.SetMargins(20, 15, 20);
PL_FPDF.SetAutoPageBreak(TRUE, 15);
PL_FPDF.AddPage;                       -- página 1
PL_FPDF.AddPage('L','A4');             -- página 2 em paisagem
PL_FPDF.SetPage(1);                    -- volta a escrever na página 1
PL_FPDF.SetXY(20, 40);
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
PL_FPDF.Triangle(50, 100, 20, 'D');
PL_FPDF.Poly(l_pontos, TRUE, 'D');    -- polígono por tabela de pontos

PL_FPDF.SetDash(2, 2);                       -- tracejado simples
PL_FPDF.SetLineDashPattern('[3 2] 0');       -- padrão PDF nativo
```

---

## 6. Imagens

```sql
PL_FPDF.Image(
  pFile   => 'logo.png',    -- arquivo em DIRECTORY, ou use getImageFromUrl
  pX      => 10, pY => 10,
  pWidth  => 40,            -- 0 = proporcional
  pHeight => 0,
  pType   => NULL,          -- autodetecta PNG/JPEG
  pLink   => NULL
);

-- Imagem vinda de URL (via UTL_HTTP)
l_img := PL_FPDF.getImageFromUrl('https://exemplo.com/logo.png');
```

Formatos: **PNG** e **JPEG**.

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
PL_FPDF.SetHeaderProc('meu_pkg.meu_header', tv4000a('Título','Subtítulo'));
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
  p_type      => 'CODE128',      -- 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF14'
  p_show_text => TRUE
);
```

> PIX "pronto para pagamento" (EMV completo) e Boleto FEBRABAN estão na
> [extensão brazilian-payments](../extensions/brazilian-payments/README_PT_BR.md).

---

## 10. Metadados e configuração do documento

```sql
PL_FPDF.SetTitle('Relatório Mensal');
PL_FPDF.SetSubject('Fechamento');
PL_FPDF.SetAuthor('M&S do Brasil');
PL_FPDF.SetKeywords('relatorio, oracle, pdf');
PL_FPDF.SetCreator('Meu ERP');

PL_FPDF.SetDisplayMode('fullpage', 'single');  -- zoom e layout iniciais no leitor
PL_FPDF.SetCompression(TRUE);                  -- comprime o conteúdo

-- Em lote, via JSON:
PL_FPDF.SetDocumentConfig(JSON_OBJECT_T('{"title":"Relatório","author":"M&S"}'));

l_meta := PL_FPDF.GetDocumentMetadata;         -- JSON com os metadados atuais
l_info := PL_FPDF.GetPageInfo(1);              -- dimensões/rotação da página
```

---

## 11. Saída (gerar o PDF)

| API | Quando usar |
|-----|-------------|
| `Output_Blob` / `OutputBlob` **RETURN BLOB** | Padrão: devolve o PDF para gravar em tabela, enviar por e-mail, APEX etc. |
| `OutputFile(p_filename, p_directory)` | Grava direto num DIRECTORY Oracle |
| `ReturnBlob(pname, pdest)` | Compatibilidade com código legado |
| `Output(pname, pdest)` | Compatibilidade FPDF clássica |

```sql
l_pdf := PL_FPDF.Output_Blob;
INSERT INTO documentos (pdf) VALUES (l_pdf);
-- ou
PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
```

---

## 12. Manipulação de PDF existente

Fluxo: `LoadPDF` → inspecionar/modificar → `OutputModifiedPDF`.

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
    p_encryption     => 'RC4-128'         -- ou 'RC4-40' (legado)
  );
END;
```

### Demais APIs

| API | O que faz |
|-----|-----------|
| `DecryptPDF(p_pdf, p_password)` | Remove a proteção (exige a senha) |
| `IsEncrypted(p_pdf)` | TRUE se o BLOB está criptografado |
| `GetSecurityInfo(p_pdf)` | JSON: algoritmo, tamanho de chave, permissões |
| `SetEncryption(p_encryption, p_user_password, p_owner_password)` | Define criptografia **antes** do `Output_Blob` (documento novo) |
| `SetPermissions(p_print, p_modify, p_copy, p_annotate, p_fill_forms, p_extract, p_assemble, p_print_high)` | Permissões do documento novo |
| `SetPDFVersion('1.7')` / `GetPDFVersion` | Versão do arquivo PDF gerado |

> AES-256 e assinatura digital estão no [roadmap](ROADMAP.md).

---

## 16. Diagnóstico e utilidades

```sql
PL_FPDF.SetLogLevel(3);              -- 0=off … níveis de verbosidade
PL_FPDF.DebugEnabled;                -- atalhos
PL_FPDF.DebugDisabled;
PL_FPDF.helloworld;                  -- smoke test clássico
```

Suíte de testes: `@tests/run_all_tests.sql` (veja [tests/README](../tests/README.md)).

---

## 17. Migração da v0.9.4

```sql
-- ANTES (v0.9.4)                    -- AGORA (v2.0+)
PL_FPDF.fpdf('P','mm','A4');         PL_FPDF.Init('P','mm','A4');
l_pdf := PL_FPDF.Output('S');        l_pdf := PL_FPDF.Output_Blob;
PL_FPDF.Output('F', caminho);        PL_FPDF.OutputFile(nome, directory);
```

| v0.9.4 | v2.0+ |
|--------|-------|
| `fpdf()` | `Init()` (o `fpdf()` segue disponível por compatibilidade) |
| `Output('S')` | `Output_Blob` |
| UTF-8 limitado | UTF-8 completo + TrueType |
| Sem criptografia | RC4 (AES no roadmap) |

---

## 18. Códigos de erro

| Faixa | Área | Exemplos |
|-------|------|----------|
| -20105/-20106 | Páginas | não inicializado; página inexistente |
| -20110 | Texto | rotação inválida (só 0/90/180/270) |
| -20800…-20804 | LoadPDF | PDF inválido, header/xref/trailer corrompidos |
| -20809/-20810 | Manipulação | nenhum PDF carregado; página inválida |
| -20821…-20824 | Overlays | coordenadas/formato/dimensões inválidos |
| -20831…-20839 | Multi-PDF | ID não encontrado; especificação de páginas inválida |

---

## Suporte

- **Autor:** Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))
- **Mantenedora:** [M&S do Brasil LTDA](https://msbrasil.inf.br)
- **Issues:** [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues) · **Dúvidas:** [Discussions](https://github.com/Maxwbh/pl_fpdf/discussions)
- **E-mail:** contato@msbrasil.inf.br
