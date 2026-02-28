# PL_FPDF Roadmap

> Gestao de features e evolucao do projeto

**Versao Atual:** 3.2.0 (Security In Progress)
**Ultima Atualizacao:** 2026-02-28

---

## Status

| Status | Descricao |
|--------|-----------|
| ✅ Released | Disponivel em producao |
| 🧪 Beta | Em validacao/testes |
| 🚧 In Progress | Em desenvolvimento |
| 📋 Planned | Planejado |
| 💡 Proposed | Em avaliacao |

---

## v2.0.0 - Foundation ✅

**Status:** Released (Dez 2025)

| Feature | Status |
|---------|--------|
| Init/Reset/IsInitialized | ✅ |
| Multi-page documents | ✅ |
| CLOB buffer (unlimited size) | ✅ |
| UTF-8 encoding | ✅ |
| TrueType fonts | ✅ |
| PNG/JPEG images | ✅ |
| Text rotation | ✅ |
| Native compilation (2-3x faster) | ✅ |
| Custom exceptions | ✅ |
| JSON configuration | ✅ |
| QR Code / Barcode | ✅ |
| PIX QR Code (extension) | ✅ |
| Boleto barcode (extension) | ✅ |

---

## v3.0.0 - PDF Manipulation ✅

**Status:** Released (Fev 2026)

### Phase 4 - Features Completas

| Feature | Status | Descricao |
|---------|--------|-----------|
| **4.1 PDF Parser** | ✅ Released | Leitura de PDFs existentes |
| **4.2 Page Management** | ✅ Released | Navegacao e info de paginas |
| **4.3 Watermarks** | ✅ Released | Marca d'agua texto/imagem |
| **4.4 OutputModifiedPDF** | ✅ Released | Salvar PDF modificado |
| **4.5 Text/Image Overlay** | ✅ Released | Adicionar conteudo sobre PDF |
| **4.6 Merge & Split** | ✅ Released | Combinar/dividir PDFs |

### API Examples

```sql
-- Carregar PDF existente
PL_FPDF.LoadPDF(l_pdf_blob);

-- Informacoes das paginas
l_count := PL_FPDF.GetPageCount();
l_info := PL_FPDF.GetPageInfo(1);

-- Adicionar watermark
PL_FPDF.AddWatermark('CONFIDENCIAL', p_opacity => 0.3);

-- Overlay de texto
PL_FPDF.OverlayText(1, 100, 50, 'Aprovado');

-- Merge de PDFs
PL_FPDF.LoadPDFWithID(l_pdf1, 'doc1');
PL_FPDF.LoadPDFWithID(l_pdf2, 'doc2');
l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["doc1","doc2"]'));

-- Split de PDF
l_parts := PL_FPDF.SplitPDF('doc1', JSON_ARRAY_T('["1-5","6-10"]'));

-- Salvar modificacoes
l_result := PL_FPDF.OutputModifiedPDF();
```

### Melhorias v3.0.0

- [x] Parser xref robusto (fallback para offsets incorretos)
- [x] Compatibilidade Oracle (INSTR/SUBSTR em vez de REGEXP)
- [x] Sem dependencias APEX
- [x] Suite completa de testes (100% passing)
- [x] PDF version 1.4 padrao

---

## v3.1.0 - Page Operations 📋

**Status:** Planned
**Target:** Q2 2026

| Feature | Status | Prioridade |
|---------|--------|------------|
| InsertPagesFrom | 📋 Planned | Alta |
| PrependPages | 📋 Planned | Alta |
| AppendPages | 📋 Planned | Alta |
| DeletePages | 📋 Planned | Alta |
| ReorderPages | 📋 Planned | Media |
| RotatePages | 📋 Planned | Media |
| ExtractPages | 📋 Planned | Media |

---

## v3.2.0 - Security 📋

**Status:** In Progress 🚧
**Target:** Q3 2026

### Objetivo
Adicionar criptografia e protecao por senha a PDFs, seguindo especificacoes PDF 1.4-2.0.

### Features

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Password Protection** | ✅ Done | Alta | Senha de usuario e owner |
| **RC4 40-bit** | ✅ Done | Alta | Criptografia legada (PDF 1.4) |
| **RC4 128-bit** | ✅ Done | Alta | Criptografia padrao (PDF 1.4) |
| **AES 128-bit** | 📋 Planned | Alta | Criptografia moderna (PDF 1.5) |
| **AES 256-bit** | 📋 Planned | Media | Criptografia avancada (PDF 1.7) |
| **Permission Controls** | ✅ Done | Alta | Controle de impressao/copia/edicao |
| **PDF Decryption** | 🚧 Partial | Alta | Remover protecao com senha |
| **PDF Version Control** | ✅ Done | Alta | SetPDFVersion, GetPDFVersion |

### API Proposta

```sql
-- Proteger PDF com senha simples
l_pdf := PL_FPDF.EncryptPDF(
  p_pdf           => l_original_pdf,
  p_user_password => 'senha123'
);

-- Proteger com senha owner e permissoes
l_pdf := PL_FPDF.EncryptPDF(
  p_pdf            => l_original_pdf,
  p_user_password  => 'user123',      -- Senha para abrir
  p_owner_password => 'owner456',     -- Senha para editar
  p_permissions    => JSON_OBJECT_T('{
    "print": true,
    "printHighQuality": false,
    "modify": false,
    "copy": false,
    "annotate": true,
    "fillForms": true,
    "extract": false,
    "assemble": false
  }'),
  p_encryption     => 'AES-128'       -- RC4-40, RC4-128, AES-128, AES-256
);

-- Descriptografar PDF
l_pdf := PL_FPDF.DecryptPDF(
  p_pdf      => l_encrypted_pdf,
  p_password => 'senha123'
);

-- Verificar se PDF esta protegido
l_info := PL_FPDF.GetSecurityInfo(l_pdf);
-- Retorna: {"encrypted": true, "method": "AES-128", "permissions": {...}}

-- Proteger durante geracao
PL_FPDF.fpdf();
PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE);
PL_FPDF.AddPage();
PL_FPDF.Cell(0, 10, 'Documento Confidencial');
l_pdf := PL_FPDF.Output();
```

### Implementacao TODO

- [x] **Fase 1: Infraestrutura Criptografica** ✅
  - [x] Usar DBMS_CRYPTO (MD5, RC4)
  - [x] Key derivation conforme PDF spec (Algorithm 2, 3, 4, 5)
  - [x] Compute O value (owner hash)
  - [x] Compute U value (user hash)

- [x] **Fase 2: RC4 Encryption (PDF 1.4)** ✅
  - [x] RC4 40-bit encryption
  - [x] RC4 128-bit encryption
  - [x] EncryptPDF() function
  - [x] SetEncryption() procedure

- [ ] **Fase 3: AES Encryption (PDF 1.5+)**
  - [ ] AES 128-bit CBC mode
  - [ ] AES 256-bit CBC mode (PDF 1.7)
  - [ ] Initialization vectors (IV)
  - [ ] Padding (PKCS#7)

- [x] **Fase 4: Password Management** ✅
  - [x] User password (abrir documento)
  - [x] Owner password (permissoes completas)
  - [x] Password validation
  - [x] SetPDFVersion() - versao automatica por encryption

- [x] **Fase 5: Permission Controls** ✅
  - [x] Print permission (bit 3)
  - [x] Modify permission (bit 4)
  - [x] Copy permission (bit 5)
  - [x] Annotate permission (bit 6)
  - [x] Fill forms permission (bit 9)
  - [x] Extract permission (bit 10)
  - [x] Assemble permission (bit 11)
  - [x] Print high quality (bit 12)
  - [x] SetPermissions() procedure

- [x] **Fase 6: Decryption** (Parcial)
  - [x] IsEncrypted() - Detectar PDF criptografado
  - [x] GetSecurityInfo() - Identificar metodo de criptografia
  - [ ] Validar senha
  - [ ] Descriptografar objetos
  - [ ] Remover encryption dictionary

### Especificacoes PDF

| Versao PDF | Encryption | Key Size |
|------------|------------|----------|
| 1.1-1.3 | RC4 | 40-bit |
| 1.4 | RC4 | 128-bit |
| 1.5 | AES | 128-bit |
| 1.6 | AES | 128-bit |
| 2.0 | AES | 256-bit |

### Estrutura Encryption Dictionary

```
/Encrypt <<
  /Filter /Standard
  /V 4                    % Version (4 = AES)
  /R 4                    % Revision
  /Length 128             % Key length in bits
  /CF <<                  % Crypt filters
    /StdCF <<
      /CFM /AESV2
      /Length 16
    >>
  >>
  /StmF /StdCF           % Stream filter
  /StrF /StdCF           % String filter
  /O (owner_hash)        % Owner password hash
  /U (user_hash)         % User password hash
  /P -3904               % Permissions flags
>>
```

### Consideracoes de Seguranca

- RC4 40-bit: **INSEGURO** - apenas para compatibilidade legada
- RC4 128-bit: **FRACO** - usar apenas se necessario
- AES 128-bit: **RECOMENDADO** - padrao atual
- AES 256-bit: **FORTE** - para documentos sensiveis

### Dependencias

**Opcao 1: PL/SQL Puro**
- Implementar MD5, SHA-256, RC4, AES do zero
- Maior complexidade, sem dependencias

**Opcao 2: DBMS_CRYPTO**
- Usar pacote Oracle nativo
- Disponivel em Oracle 10g+
- Mais simples e performatico

**Recomendacao:** Usar DBMS_CRYPTO quando disponivel, fallback para PL/SQL puro.

### Limitacoes Conhecidas

- Certificados digitais (X.509) serao v4.0.0
- Public key encryption nao suportado inicialmente
- Metadata encryption opcional

---

## v3.3.0 - HTML to PDF 💡

**Status:** Proposed
**Target:** Q4 2026

### Objetivo
Converter HTML para PDF diretamente em PL/SQL, sem dependencias externas.

### Features Planejadas

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **HTML Parser** | 💡 Proposed | Alta | Parser HTML basico em PL/SQL |
| **CSS Inline** | 💡 Proposed | Alta | Suporte a estilos inline |
| **Tags Basicas** | 💡 Proposed | Alta | h1-h6, p, br, hr, div, span |
| **Tabelas** | 💡 Proposed | Alta | table, tr, td, th, thead, tbody |
| **Listas** | 💡 Proposed | Media | ul, ol, li |
| **Links** | 💡 Proposed | Media | a href (interno/externo) |
| **Imagens** | 💡 Proposed | Media | img src (base64/URL) |
| **CSS Classes** | 💡 Proposed | Baixa | Suporte a classes CSS |
| **CSS Externo** | 💡 Proposed | Baixa | Arquivo CSS separado |

### API Proposta

```sql
-- Conversao simples
l_pdf := PL_FPDF.HTMLToPDF('<h1>Titulo</h1><p>Paragrafo</p>');

-- Com opcoes
l_pdf := PL_FPDF.HTMLToPDF(
  p_html    => l_html_content,
  p_options => JSON_OBJECT_T('{
    "pageSize": "A4",
    "orientation": "P",
    "margins": {"top": 20, "right": 15, "bottom": 20, "left": 15},
    "defaultFont": "Arial",
    "defaultFontSize": 12
  }')
);

-- Render parcial (adiciona ao PDF atual)
PL_FPDF.fpdf();
PL_FPDF.AddPage();
PL_FPDF.RenderHTML('<table>...</table>');
PL_FPDF.RenderHTML('<p>Mais conteudo</p>');
l_pdf := PL_FPDF.Output();
```

### Implementacao TODO

- [ ] **Fase 1: Parser HTML**
  - [ ] Tokenizer HTML (tags, atributos, texto)
  - [ ] Arvore DOM simplificada
  - [ ] Tratamento de entidades HTML (&amp;, &lt;, etc.)
  - [ ] Suporte a HTML mal-formado (tolerante)

- [ ] **Fase 2: Tags Basicas**
  - [ ] Headings (h1-h6) → SetFont + Cell
  - [ ] Paragrafos (p) → MultiCell
  - [ ] Line breaks (br) → Ln
  - [ ] Horizontal rule (hr) → Line
  - [ ] Div/Span → containers

- [ ] **Fase 3: Tabelas**
  - [ ] Estrutura table/tr/td
  - [ ] Colspan/rowspan
  - [ ] Larguras automaticas/fixas
  - [ ] Bordas e padding
  - [ ] Quebra de pagina em tabelas longas

- [ ] **Fase 4: Estilos**
  - [ ] Parser CSS inline (style="...")
  - [ ] Cores (color, background-color)
  - [ ] Fontes (font-family, font-size, font-weight)
  - [ ] Alinhamento (text-align)
  - [ ] Margens/padding

- [ ] **Fase 5: Elementos Avancados**
  - [ ] Listas (ul, ol, li)
  - [ ] Links (a href)
  - [ ] Imagens (img src)
  - [ ] Negrito/Italico (b, i, strong, em)

### Limitacoes Conhecidas

- Sem suporte a JavaScript
- Sem suporte a CSS externo (fase inicial)
- Sem suporte a flexbox/grid
- Layout simplificado (fluxo vertical)
- Fontes limitadas as disponiveis no PL_FPDF

### Dependencias

- PL_FPDF v3.0.0+ (base)
- Nenhuma dependencia externa

---

## v3.4.0 - PDF 1.5/1.6 Complete Support 📋

**Status:** Planned
**Target:** Q1 2027

### Objetivo
Implementacao completa das especificacoes PDF 1.5 e 1.6, incluindo estrutura, compressao, graficos, fontes e seguranca.

---

### 1. Estrutura e Compressao

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Object Streams** | 📋 Planned | Alta | Multiplos objetos em um stream comprimido |
| **Cross-Reference Streams** | 📋 Planned | Alta | xref como stream binario comprimido |
| **Incremental Updates** | 📋 Planned | Media | Atualizacoes incrementais ao PDF |
| **Linearization** | 💡 Proposed | Baixa | PDF otimizado para web (Fast Web View) |

#### Object Streams (ObjStm)
```
% Antes (PDF 1.4): Cada objeto separado
1 0 obj << /Type /Page >> endobj
2 0 obj << /Type /Font >> endobj

% Depois (PDF 1.5): Objetos agrupados em stream
3 0 obj <<
  /Type /ObjStm
  /N 2                    % Numero de objetos
  /First 10               % Offset do primeiro objeto
  /Filter /FlateDecode
>>
stream
1 0 2 20                  % obj_num offset pairs
<< /Type /Page >>
<< /Type /Font >>
endstream
endobj
```

#### Cross-Reference Streams
```
% Antes (PDF 1.4): xref table em texto
xref
0 4
0000000000 65535 f
0000000015 00000 n

% Depois (PDF 1.5): xref em stream binario
4 0 obj <<
  /Type /XRef
  /Size 4
  /W [1 2 1]              % Largura dos campos
  /Filter /FlateDecode
>>
stream
[binary data]
endstream
```

---

### 2. Graficos e Imagens

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **JPEG2000 (JPX)** | 📋 Planned | Media | Imagens JPX/JP2 nativas |
| **Soft Masks** | 📋 Planned | Media | Mascaras de transparencia |
| **Blend Modes** | 📋 Planned | Media | Modos de mesclagem avancados |
| **ICC Color Profiles** | 💡 Proposed | Baixa | Perfis de cor ICC embedded |

#### Blend Modes Suportados
- Normal, Multiply, Screen, Overlay
- Darken, Lighten, ColorDodge, ColorBurn
- HardLight, SoftLight, Difference, Exclusion

#### API Proposta - Graficos
```sql
-- Definir blend mode
PL_FPDF.SetBlendMode('Multiply');
PL_FPDF.SetOpacity(0.5);

-- Imagem JPEG2000
PL_FPDF.ImageJPX(l_jpx_blob, 10, 10, 100, 100);

-- Soft mask
PL_FPDF.SetSoftMask(l_mask_blob);
PL_FPDF.Image(l_image_blob, 10, 10);
PL_FPDF.ClearSoftMask();
```

---

### 3. Fontes e Texto

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **OpenType CFF** | 📋 Planned | Alta | Fontes OpenType com outlines CFF |
| **CIDFont Improvements** | 📋 Planned | Media | Melhor suporte a fontes CJK |
| **ActualText** | 📋 Planned | Media | Texto real para acessibilidade |
| **ToUnicode CMap** | 📋 Planned | Alta | Mapeamento correto de caracteres |

#### Estrutura CIDFont
```
/Font <<
  /Type /Font
  /Subtype /Type0
  /BaseFont /MyFont-Identity-H
  /Encoding /Identity-H
  /DescendantFonts [<<
    /Type /Font
    /Subtype /CIDFontType0
    /BaseFont /MyFont
    /CIDSystemInfo <<
      /Registry (Adobe)
      /Ordering (Identity)
      /Supplement 0
    >>
    /FontDescriptor 5 0 R
    /W [...]                % Larguras por CID
  >>]
  /ToUnicode 6 0 R
>>
```

---

### 4. Seguranca (AES-128)

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-128 Encryption** | 📋 Planned | Alta | Criptografia AES CBC |
| **Crypt Filters** | 📋 Planned | Alta | Filtros por tipo de objeto |
| **Metadata Encryption** | 📋 Planned | Media | Criptografar/nao criptografar metadata |

#### Encryption Dictionary (V=4, R=4)
```
/Encrypt <<
  /Filter /Standard
  /V 4
  /R 4
  /Length 128
  /CF <<
    /StdCF <<
      /CFM /AESV2
      /AuthEvent /DocOpen
      /Length 16
    >>
  >>
  /StmF /StdCF
  /StrF /StdCF
  /EFF /StdCF               % Embedded files filter
  /O (32 bytes)
  /U (32 bytes)
  /P permissions
>>
```

#### Algoritmo AES-128
```
1. Gerar IV aleatorio (16 bytes)
2. Derivar object key: MD5(file_key || obj_num || gen_num || "sAlT")
3. Truncar para 16 bytes
4. AES-CBC encrypt: IV || ciphertext
5. Padding: PKCS#7
```

---

### 5. Interatividade

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Optional Content** | 📋 Planned | Media | Layers/camadas (OCG) |
| **Embedded Files** | 📋 Planned | Media | Arquivos anexados |
| **Markup Annotations** | 💡 Proposed | Baixa | Highlight, Underline, Strikeout |

#### Optional Content Groups (Layers)
```sql
-- Criar layer
l_layer_id := PL_FPDF.CreateLayer('Background');

-- Ativar layer
PL_FPDF.BeginLayer(l_layer_id);
PL_FPDF.Rect(0, 0, 210, 297, 'F');
PL_FPDF.EndLayer();

-- Layer visibility
PL_FPDF.SetLayerVisibility(l_layer_id, TRUE);
```

---

### 6. Acessibilidade (Tagged PDF)

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Structure Tree** | 📋 Planned | Alta | Arvore de estrutura do documento |
| **Standard Tags** | 📋 Planned | Alta | P, H1-H6, Table, TR, TD, etc. |
| **Alt Text** | 📋 Planned | Alta | Texto alternativo para imagens |
| **Reading Order** | 📋 Planned | Media | Ordem de leitura definida |

#### Tagged PDF Structure
```
/StructTreeRoot <<
  /Type /StructTreeRoot
  /K [<<
    /Type /StructElem
    /S /Document
    /K [
      << /S /H1 /K (Titulo) >>
      << /S /P /K (Paragrafo) >>
      << /S /Table /K [...] >>
    ]
  >>]
  /ParentTree 10 0 R
>>
```

#### API Proposta - Tagged PDF
```sql
-- Habilitar tagged PDF
PL_FPDF.SetTagged(TRUE);

-- Marcar elementos
PL_FPDF.BeginTag('H1');
PL_FPDF.Cell(0, 10, 'Titulo do Documento');
PL_FPDF.EndTag();

PL_FPDF.BeginTag('P');
PL_FPDF.MultiCell(0, 5, 'Paragrafo de texto...');
PL_FPDF.EndTag();

-- Imagem com alt text
PL_FPDF.BeginTag('Figure', p_alt => 'Grafico de vendas 2026');
PL_FPDF.Image('chart.png', 10, 50, 100);
PL_FPDF.EndTag();
```

---

### TODO Implementacao v3.4.0

- [ ] **Sprint 1: Estrutura**
  - [ ] Object Streams (ObjStm)
  - [ ] Cross-Reference Streams
  - [ ] Parser para novos formatos

- [ ] **Sprint 2: Seguranca**
  - [ ] AES-128 CBC encryption
  - [ ] Crypt filters (/CF)
  - [ ] DBMS_CRYPTO integration

- [ ] **Sprint 3: Graficos**
  - [ ] Blend modes
  - [ ] Soft masks
  - [ ] Opacity groups

- [ ] **Sprint 4: Fontes**
  - [ ] OpenType CFF support
  - [ ] ToUnicode CMap generation
  - [ ] CIDFont improvements

- [ ] **Sprint 5: Tagged PDF**
  - [ ] Structure tree root
  - [ ] Standard structure tags
  - [ ] Content marking API

- [ ] **Sprint 6: Interatividade**
  - [ ] Optional content groups (layers)
  - [ ] Embedded files
  - [ ] Markup annotations

---

## v3.5.0 - PDF 1.7 Complete Support 📋

**Status:** Planned
**Target:** Q2 2027

### Objetivo
Implementacao completa da especificacao PDF 1.7 (ISO 32000-1:2008), padrao mais usado atualmente.

---

### 1. Seguranca Avancada (AES-256)

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-256 Encryption** | 📋 Planned | Alta | Criptografia forte |
| **SHA-256 Key Derivation** | 📋 Planned | Alta | Substituir MD5 |
| **Unicode Passwords** | 📋 Planned | Alta | Senhas UTF-8 |
| **Extension Levels** | 📋 Planned | Media | /Extensions dictionary |

#### Encryption Dictionary (V=5, R=5)
```
/Encrypt <<
  /Filter /Standard
  /V 5
  /R 5
  /Length 256
  /CF <<
    /StdCF <<
      /CFM /AESV3
      /AuthEvent /DocOpen
      /Length 32
    >>
  >>
  /StmF /StdCF
  /StrF /StdCF
  /O (48 bytes)
  /U (48 bytes)
  /OE (32 bytes)            % Encrypted owner key
  /UE (32 bytes)            % Encrypted user key
  /Perms (16 bytes)         % Encrypted permissions
  /P permissions
>>
```

#### Extension Level para AES-256
```
/Extensions <<
  /ADBE <<
    /BaseVersion /1.7
    /ExtensionLevel 3
  >>
>>
```

---

### 2. Formularios Avancados

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AcroForms** | 📋 Planned | Alta | Formularios interativos |
| **Field Types** | 📋 Planned | Alta | Text, Button, Choice, Signature |
| **JavaScript Actions** | 💡 Proposed | Baixa | Acoes em campos |
| **Field Validation** | 📋 Planned | Media | Validacao de entrada |

#### AcroForm Structure
```
/AcroForm <<
  /Fields [
    <<
      /Type /Annot
      /Subtype /Widget
      /FT /Tx                % Text field
      /T (nome)              % Field name
      /V (valor)             % Current value
      /Rect [100 700 300 720]
      /F 4                   % Flags
    >>
    <<
      /FT /Btn               % Button/Checkbox
      /T (aceito)
      /V /Yes
    >>
    <<
      /FT /Ch                % Choice (dropdown/list)
      /T (estado)
      /Opt [(SP) (RJ) (MG)]
      /V (SP)
    >>
  ]
  /NeedAppearances true
  /SigFlags 3
>>
```

#### API Proposta - Forms
```sql
-- Criar formulario
PL_FPDF.BeginForm();

-- Campo de texto
PL_FPDF.AddTextField(
  p_name     => 'nome',
  p_x        => 50,
  p_y        => 100,
  p_width    => 150,
  p_height   => 20,
  p_default  => '',
  p_required => TRUE
);

-- Checkbox
PL_FPDF.AddCheckbox(
  p_name    => 'aceito_termos',
  p_x       => 50,
  p_y       => 130,
  p_checked => FALSE
);

-- Dropdown
PL_FPDF.AddDropdown(
  p_name    => 'estado',
  p_x       => 50,
  p_y       => 160,
  p_options => JSON_ARRAY_T('["SP","RJ","MG","RS"]'),
  p_default => 'SP'
);

-- Campo de assinatura
PL_FPDF.AddSignatureField(
  p_name   => 'assinatura',
  p_x      => 50,
  p_y      => 200,
  p_width  => 200,
  p_height => 50
);

PL_FPDF.EndForm();
```

---

### 3. Anotacoes Avancadas

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Text Annotations** | 📋 Planned | Alta | Notas/comentarios |
| **Link Annotations** | 📋 Planned | Alta | Hyperlinks internos/externos |
| **File Attachment** | 📋 Planned | Media | Anexar arquivos |
| **Stamp Annotations** | 💡 Proposed | Baixa | Carimbos predefinidos |
| **Redaction** | 💡 Proposed | Baixa | Remocao segura de conteudo |

#### Annotation Types
```
% Text annotation (sticky note)
<<
  /Type /Annot
  /Subtype /Text
  /Rect [100 700 120 720]
  /Contents (Comentario aqui)
  /Open false
  /Name /Comment
>>

% Link annotation
<<
  /Type /Annot
  /Subtype /Link
  /Rect [100 600 200 620]
  /A <<
    /Type /Action
    /S /URI
    /URI (https://example.com)
  >>
>>

% File attachment
<<
  /Type /Annot
  /Subtype /FileAttachment
  /Rect [100 500 120 520]
  /FS <<
    /Type /Filespec
    /F (documento.pdf)
    /EF << /F 5 0 R >>
  >>
>>
```

---

### 4. Navegacao e Estrutura

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Bookmarks (Outlines)** | 📋 Planned | Alta | Indice navegavel |
| **Named Destinations** | 📋 Planned | Alta | Destinos nomeados |
| **Page Labels** | 📋 Planned | Media | Numeracao customizada |
| **Article Threads** | 💡 Proposed | Baixa | Fluxo de leitura |

#### Bookmark Structure
```
/Outlines <<
  /Type /Outlines
  /Count 3
  /First 10 0 R
  /Last 12 0 R
>>

10 0 obj <<
  /Title (Capitulo 1)
  /Parent 9 0 R
  /Next 11 0 R
  /Dest [1 0 R /XYZ 0 800 0]
  /Count 2
  /First 13 0 R
>>
```

#### API Proposta - Navegacao
```sql
-- Adicionar bookmark
l_bm1 := PL_FPDF.AddBookmark('Capitulo 1', p_page => 1);
l_bm2 := PL_FPDF.AddBookmark('Secao 1.1', p_page => 2, p_parent => l_bm1);
l_bm3 := PL_FPDF.AddBookmark('Capitulo 2', p_page => 10);

-- Named destination
PL_FPDF.AddDestination('intro', p_page => 1, p_y => 700);

-- Link para destino
PL_FPDF.AddInternalLink(50, 100, 100, 20, 'intro');

-- Page labels
PL_FPDF.SetPageLabels(JSON_OBJECT_T('{
  "1": {"style": "r", "prefix": ""},
  "5": {"style": "D", "prefix": "", "start": 1}
}'));
-- Paginas 1-4: i, ii, iii, iv
-- Paginas 5+: 1, 2, 3...
```

---

### 5. Multimedia

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Rich Media** | 💡 Proposed | Baixa | Video/Audio embedded |
| **3D Content** | 💡 Proposed | Baixa | Modelos 3D (U3D, PRC) |
| **Screen Annotations** | 💡 Proposed | Baixa | Players multimedia |

---

### 6. Transparencia Avancada

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Transparency Groups** | 📋 Planned | Media | Grupos de transparencia |
| **Knockout Groups** | 📋 Planned | Media | Knockout behavior |
| **Isolated Groups** | 📋 Planned | Media | Grupos isolados |
| **Spot Colors** | 💡 Proposed | Baixa | Cores especiais |

---

### TODO Implementacao v3.5.0

- [ ] **Sprint 1: AES-256**
  - [ ] SHA-256 key derivation
  - [ ] AES-256-CBC encryption
  - [ ] Unicode password support

- [ ] **Sprint 2: AcroForms**
  - [ ] Text fields
  - [ ] Checkboxes and radio buttons
  - [ ] Dropdowns and list boxes
  - [ ] Signature fields

- [ ] **Sprint 3: Bookmarks**
  - [ ] Outline tree structure
  - [ ] Named destinations
  - [ ] Page labels

- [ ] **Sprint 4: Annotations**
  - [ ] Text annotations
  - [ ] Link annotations
  - [ ] File attachments

- [ ] **Sprint 5: Transparency**
  - [ ] Transparency groups
  - [ ] Isolated/knockout groups

---

## v3.6.0 - PDF 2.0 Complete Support 💡

**Status:** Proposed
**Target:** Q3-Q4 2027

### Objetivo
Implementacao da especificacao PDF 2.0 (ISO 32000-2:2020), a versao mais atual do padrao.

---

### 1. Mudancas Estruturais

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Header Simplificado** | 💡 Proposed | Alta | %PDF-2.0 sem binary marker |
| **Deprecations Removidas** | 💡 Proposed | Alta | Limpar features obsoletas |
| **Document Parts** | 💡 Proposed | Media | PDFs modulares |
| **Namespaces** | 💡 Proposed | Baixa | Extensoes padronizadas |

#### Features Removidas no PDF 2.0
- RC4 encryption (totalmente removido)
- LZW compression (substituido por FlateDecode)
- Standard security handler R2-R4
- Embedded GoTo actions
- Movie annotations
- Sound annotations

---

### 2. Seguranca PDF 2.0

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-256 Nativo** | 💡 Proposed | Alta | Sem Extension Level |
| **SHA-384/512** | 💡 Proposed | Alta | Hashes mais fortes |
| **Page-Level Security** | 💡 Proposed | Media | Criptografia por pagina |
| **Unencrypted Wrapper** | 💡 Proposed | Media | Metadata nao criptografada |

#### Encryption Dictionary (V=6, R=6)
```
/Encrypt <<
  /Filter /Standard
  /V 6
  /R 6
  /Length 256
  /CF << /StdCF << /CFM /AESV3 /Length 32 >> >>
  /StmF /StdCF
  /StrF /StdCF
  /O (48 bytes)
  /U (48 bytes)
  /OE (32 bytes)
  /UE (32 bytes)
  /Perms (16 bytes)
  /P permissions
  /EncryptMetadata false    % Opcional: metadata nao criptografada
>>
```

---

### 3. Acessibilidade Avancada

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **PDF/UA-2** | 💡 Proposed | Alta | Universal Accessibility v2 |
| **MathML** | 💡 Proposed | Media | Formulas matematicas acessiveis |
| **Pronunciations** | 💡 Proposed | Baixa | Guias de pronuncia |
| **Namespaces Tags** | 💡 Proposed | Media | Tags estruturadas com namespace |

#### Structure Element com Namespace
```
/StructElem <<
  /Type /StructElem
  /S /mathml:math         % Tag com namespace
  /NS /mathml
  /K (...)
  /Alt (x squared plus 2x)
>>
```

---

### 4. Associated Files

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AF Dictionary** | 💡 Proposed | Media | Arquivos associados estruturados |
| **Relationship Types** | 💡 Proposed | Media | Source, Data, Alternative, etc. |
| **MIME Types** | 💡 Proposed | Media | Tipos de arquivo padronizados |

#### Associated Files Structure
```
/AF [<<
  /Type /Filespec
  /F (dados.xml)
  /UF (dados.xml)
  /AFRelationship /Data
  /EF << /F 10 0 R >>
>>]
```

#### API Proposta - Associated Files
```sql
-- Anexar arquivo estruturado
PL_FPDF.AddAssociatedFile(
  p_filename     => 'invoice.xml',
  p_content      => l_xml_blob,
  p_mime_type    => 'application/xml',
  p_relationship => 'Data'           -- Source, Data, Alternative, Supplement
);

-- ZUGFeRD/Factur-X invoice
PL_FPDF.AddAssociatedFile(
  p_filename     => 'factur-x.xml',
  p_content      => l_facturx_xml,
  p_mime_type    => 'text/xml',
  p_relationship => 'Alternative'
);
```

---

### 5. Rich Media Updates

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **Geospatial Data** | 💡 Proposed | Baixa | Dados geograficos |
| **3D Annotations** | 💡 Proposed | Baixa | PRC format updates |

---

### 6. Comparativo de Versoes

| Aspecto | PDF 1.4 | PDF 1.7 | PDF 2.0 |
|---------|---------|---------|---------|
| **Encryption** | RC4-128 | AES-256 | AES-256 only |
| **Hash** | MD5 | SHA-256 | SHA-256/384/512 |
| **Compression** | Flate, LZW | Flate, JBIG2 | Flate only |
| **Forms** | AcroForms | XFA opcional | AcroForms only |
| **Accessibility** | Basic | PDF/UA | PDF/UA-2 |
| **Tamanho medio** | 100% | 80-90% | 70-85% |

---

### 7. Compatibilidade de Leitores

| Leitor | PDF 1.4 | PDF 1.5 | PDF 1.7 | PDF 2.0 |
|--------|---------|---------|---------|---------|
| Adobe Reader DC | ✅ | ✅ | ✅ | ✅ |
| Foxit Reader | ✅ | ✅ | ✅ | ✅ |
| Chrome PDF | ✅ | ✅ | ✅ | ⚠️ |
| Firefox PDF.js | ✅ | ✅ | ✅ | ⚠️ |
| Preview (macOS) | ✅ | ✅ | ✅ | ✅ |
| Sumatra PDF | ✅ | ✅ | ✅ | ⚠️ |
| MuPDF | ✅ | ✅ | ✅ | ✅ |

⚠️ = Suporte parcial

---

### TODO Implementacao v3.6.0

- [ ] **Sprint 1: Core Updates**
  - [ ] PDF 2.0 header generation
  - [ ] Remove deprecated features
  - [ ] V6/R6 encryption

- [ ] **Sprint 2: Associated Files**
  - [ ] AF dictionary
  - [ ] Relationship types
  - [ ] ZUGFeRD/Factur-X support

- [ ] **Sprint 3: Accessibility**
  - [ ] PDF/UA-2 compliance
  - [ ] Namespace support
  - [ ] MathML integration

---

### Comparativo de Seguranca

| Versao | Encryption | Key | Hash | Nivel |
|--------|------------|-----|------|-------|
| PDF 1.4 | RC4-128 | 128-bit | MD5 | ⚠️ Fraco |
| PDF 1.5 | AES-128 | 128-bit | MD5 | ✅ Bom |
| PDF 1.7 Ext3 | AES-256 | 256-bit | SHA-256 | ✅✅ Forte |
| PDF 2.0 | AES-256 | 256-bit | SHA-256+ | ✅✅✅ Muito Forte |

---

## v4.0.0 - Advanced 💡

**Status:** Proposed
**Target:** 2027

| Feature | Status | Prioridade |
|---------|--------|------------|
| Digital Signatures (X.509) | 💡 Proposed | Alta |
| PDF/A Compliance | 💡 Proposed | Media |
| Bookmarks/Outline | 💡 Proposed | Media |
| Hyperlinks | 💡 Proposed | Media |
| Annotations | 💡 Proposed | Baixa |
| Form Fields (AcroForms) | 💡 Proposed | Baixa |

---

## Estrategia de Migracao PDF

### Analise: Pular Versoes ou Migrar Gradualmente?

**Situacao Atual:** PL_FPDF gera PDF 1.4

#### Opcao 1: Migracao Gradual (RECOMENDADA)
```
PDF 1.4 → PDF 1.5 → PDF 1.7 → PDF 2.0
         (Skip 1.6)
```

**Por que pular PDF 1.6?**
- PDF 1.6 nao adiciona features essenciais
- Principais adicoes (3D, OpenType) sao baixa prioridade
- PDF 1.5 ja inclui AES-128 e object streams

#### Opcao 2: Salto Direto para PDF 1.7
```
PDF 1.4 → PDF 1.7 → PDF 2.0
```

**Vantagens:**
- Menos releases
- AES-256 diretamente

**Desvantagens:**
- Maior complexidade por release
- Mais tempo ate primeira entrega de AES

---

### Roadmap de Migracao Recomendado

```
┌─────────────────────────────────────────────────────────────────┐
│                    ESTRATEGIA DE MIGRACAO                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PDF 1.4 (Atual)                                               │
│     │                                                           │
│     │  v3.2.0 - Security (RC4-128) ✅                          │
│     │  - Password protection                                    │
│     │  - Permission controls                                    │
│     │                                                           │
│     ▼                                                           │
│  PDF 1.5 ─────────────────────────────────────────────────────  │
│     │  v3.4.0 - PDF 1.5/1.6 Support                            │
│     │  Prioridade: ALTA                                         │
│     │  Features criticas:                                       │
│     │  ✓ AES-128 encryption (substituir RC4)                   │
│     │  ✓ Object streams (reducao 30% tamanho)                  │
│     │  ✓ Cross-reference streams                               │
│     │  ✓ Tagged PDF basics                                      │
│     │                                                           │
│     ▼                                                           │
│  PDF 1.6 (SKIP) ─────────────────────────────────────────────   │
│     │  Nao implementar separadamente                            │
│     │  Features de baixa prioridade:                            │
│     │  - 3D annotations                                         │
│     │  - OpenType fonts                                         │
│     │  Incluir apenas se necessario em v3.4.0                  │
│     │                                                           │
│     ▼                                                           │
│  PDF 1.7 ─────────────────────────────────────────────────────  │
│     │  v3.5.0 - PDF 1.7 Support                                │
│     │  Prioridade: ALTA                                         │
│     │  Features criticas:                                       │
│     │  ✓ AES-256 encryption (seguranca forte)                  │
│     │  ✓ SHA-256 hashing                                        │
│     │  ✓ AcroForms completos                                    │
│     │  ✓ Bookmarks/navigation                                   │
│     │  ✓ Extension levels                                       │
│     │                                                           │
│     ▼                                                           │
│  PDF 2.0 ─────────────────────────────────────────────────────  │
│        v3.6.0 - PDF 2.0 Support                                │
│        Prioridade: MEDIA (futuro)                               │
│        Features:                                                │
│        ✓ AES-256 nativo (sem extensions)                       │
│        ✓ Associated files (ZUGFeRD)                            │
│        ✓ PDF/UA-2 accessibility                                 │
│        ✓ Remover features deprecadas                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Matriz de Decisao

| Criterio | PDF 1.5 | PDF 1.6 | PDF 1.7 | PDF 2.0 |
|----------|---------|---------|---------|---------|
| **Urgencia** | Alta | Baixa | Alta | Media |
| **Complexidade** | Media | Baixa | Alta | Alta |
| **Valor agregado** | Alto | Baixo | Muito Alto | Alto |
| **Compatibilidade** | 99% | 99% | 98% | 85% |
| **Decisao** | ✅ Impl. | ⏭️ Skip | ✅ Impl. | 💡 Futuro |

---

### Por que cada versao?

#### PDF 1.5 - IMPLEMENTAR
- **AES-128**: RC4 esta quebrado, AES e obrigatorio
- **Object Streams**: Reducao de 30% no tamanho
- **Xref Streams**: Melhor parsing e compressao
- **Tagged PDF**: Base para acessibilidade

#### PDF 1.6 - PULAR
- **3D Annotations**: Nicho muito especifico
- **OpenType**: TrueType ja atende 99% dos casos
- **Embedding files**: Ja disponivel em 1.5

#### PDF 1.7 - IMPLEMENTAR
- **AES-256**: Padrao de seguranca atual
- **SHA-256**: MD5 esta obsoleto
- **AcroForms**: Muito solicitado por usuarios
- **Bookmarks**: Navegacao essencial

#### PDF 2.0 - FUTURO
- **Baixa compatibilidade**: 15% dos viewers nao suportam
- **RC4 removido**: Precisamos manter fallback
- **ZUGFeRD**: Importante para faturas eletronicas EU

---

### Cronograma Sugerido

| Versao | Release | PDF Version | Principais Features |
|--------|---------|-------------|---------------------|
| v3.2.0 | Q1 2026 | 1.4 | RC4-128, Passwords |
| v3.3.0 | Q2 2026 | 1.4 | HTML to PDF |
| v3.4.0 | Q1 2027 | 1.5 | AES-128, ObjStm, Tagged |
| v3.5.0 | Q2 2027 | 1.7 | AES-256, Forms, Bookmarks |
| v3.6.0 | Q4 2027 | 2.0 | Full 2.0, ZUGFeRD |

---

### Retrocompatibilidade

```sql
-- Default: PDF 1.4 (compativel com tudo)
PL_FPDF.fpdf();  -- Gera PDF 1.4

-- Especificar versao
PL_FPDF.fpdf();
PL_FPDF.SetPDFVersion('1.7');  -- Gera PDF 1.7

-- Auto-upgrade por feature
PL_FPDF.fpdf();
PL_FPDF.SetEncryption('AES-256', 'pass');  -- Auto: PDF 1.7
PL_FPDF.SetTagged(TRUE);                   -- Requer: PDF 1.5+

-- Verificar versao minima
l_min := PL_FPDF.GetMinimumVersion();  -- Retorna versao minima necessaria
```

---

### Beneficios por Versao

| Beneficio | 1.4 | 1.5 | 1.7 | 2.0 |
|-----------|-----|-----|-----|-----|
| Tamanho arquivo | 100% | 70% | 70% | 65% |
| Seguranca | ⚠️ | ✅ | ✅✅ | ✅✅✅ |
| Acessibilidade | ❌ | ✅ | ✅✅ | ✅✅✅ |
| Forms | ❌ | ❌ | ✅✅ | ✅✅ |
| Compatibilidade | 100% | 99% | 98% | 85% |

---

## Principios

### Oracle 19c Forever
Todas as versoes mantem compatibilidade com Oracle 19c.

### Package-Only Architecture
Apenas 2 arquivos: `PL_FPDF.pks` + `PL_FPDF.pkb`
Sem tabelas, tipos externos ou dependencias.

### Backward Compatible
Sem breaking changes. Codigo existente continua funcionando.

---

## Contribuir

1. Escolha uma feature do roadmap
2. Abra uma issue para discussao
3. Fork e implemente
4. Envie um PR

Veja [CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Documentacao Detalhada

- [PHASE_4_GUIDE.md](guides/PHASE_4_GUIDE.md) - Guia da Fase 4
- [API_REFERENCE.md](api/API_REFERENCE.md) - Referencia da API
- [PHASE_5_IMPLEMENTATION_PLAN.md](plans/PHASE_5_IMPLEMENTATION_PLAN.md) - Plano Fase 5

---

**Contato:** maxwbh@gmail.com
