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

## v3.4.0 - PDF 1.5/1.6 Support 📋

**Status:** Planned
**Target:** Q1 2027

### Objetivo
Atualizar o PL_FPDF para suportar features do PDF 1.5 e 1.6, incluindo criptografia AES e compressao avancada.

### PDF 1.5 Features (ISO 32000-1:2008)

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-128 Encryption** | 📋 Planned | Alta | Criptografia AES CBC mode |
| **Object Streams** | 📋 Planned | Alta | Compressao de objetos em streams |
| **Cross-Reference Streams** | 📋 Planned | Media | xref como stream comprimido |
| **JPEG2000 Images** | 💡 Proposed | Baixa | Suporte a JPX/JP2 |

### PDF 1.6 Features

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-128 Improvements** | 📋 Planned | Alta | Metadata encryption |
| **OpenType Fonts** | 💡 Proposed | Media | Suporte a fontes OTF |
| **3D Annotations** | 💡 Proposed | Baixa | Objetos 3D (U3D) |

### Implementacao AES-128

```sql
-- Estrutura Encryption Dictionary (PDF 1.5+)
/Encrypt <<
  /Filter /Standard
  /V 4                    % Version 4 = AES
  /R 4                    % Revision 4
  /Length 128             % Key length
  /CF <<
    /StdCF <<
      /CFM /AESV2         % AES encryption
      /AuthEvent /DocOpen
      /Length 16
    >>
  >>
  /StmF /StdCF
  /StrF /StdCF
  /O (32 bytes)
  /U (32 bytes)
  /P -3904
>>
```

### TODO Tecnico

- [ ] **Fase 1: AES-128 CBC**
  - [ ] DBMS_CRYPTO.ENCRYPT com AES_CBC_PKCS5
  - [ ] Gerar IV (Initialization Vector) 16 bytes
  - [ ] Prepend IV ao ciphertext
  - [ ] PKCS#7 padding automatico

- [ ] **Fase 2: Crypt Filters**
  - [ ] Implementar /CF dictionary
  - [ ] Suporte a /StmF e /StrF
  - [ ] Identity filter para metadata

- [ ] **Fase 3: Object Streams**
  - [ ] Agrupar objetos em streams
  - [ ] Compressao FlateDecode
  - [ ] Offset table interno

- [ ] **Fase 4: Cross-Reference Streams**
  - [ ] xref como stream binario
  - [ ] Indice W[1 2 1] ou W[1 3 1]
  - [ ] Compressao FlateDecode

### Algoritmos AES (PDF Spec)

```
Algorithm 1a: AES-128 Key Derivation
1. Compute encryption key (Algorithm 2)
2. Truncate to 16 bytes for AES-128
3. Use with DBMS_CRYPTO.ENCRYPT

Algorithm 1b: AES Object Encryption
1. Generate random 16-byte IV
2. Concatenate: object_key || object_num || gen_num
3. MD5 hash, truncate to N+5 bytes (max 16)
4. AES-CBC encrypt with IV prepended
```

---

## v3.5.0 - PDF 1.7 Support 📋

**Status:** Planned
**Target:** Q2 2027

### Objetivo
Suporte completo ao PDF 1.7 (ISO 32000-1:2008), incluindo AES-256 e features avancadas.

### PDF 1.7 Features

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-256 Encryption** | 📋 Planned | Alta | Criptografia forte (PDF 1.7 ExtensionLevel 3) |
| **Unicode Passwords** | 📋 Planned | Alta | Senhas UTF-8 (SASLprep) |
| **SHA-256 Hashing** | 📋 Planned | Alta | Substituir MD5 por SHA-256 |
| **Extension Levels** | 📋 Planned | Media | /Extensions dictionary |
| **XFA Forms** | 💡 Proposed | Baixa | Adobe XML Forms |

### AES-256 Implementation (PDF 1.7 ExtensionLevel 3)

```sql
-- Encryption Dictionary AES-256
/Encrypt <<
  /Filter /Standard
  /V 5                    % Version 5 = AES-256
  /R 5                    % Revision 5
  /Length 256             % Key length in bits
  /CF <<
    /StdCF <<
      /CFM /AESV3         % AES-256
      /AuthEvent /DocOpen
      /Length 32
    >>
  >>
  /StmF /StdCF
  /StrF /StdCF
  /O (48 bytes)           % Owner hash
  /U (48 bytes)           % User hash
  /OE (32 bytes)          % Owner encryption key
  /UE (32 bytes)          % User encryption key
  /Perms (16 bytes)       % Encrypted permissions
  /P -3904
>>
```

### Algoritmos AES-256 (PDF 1.7 ExtensionLevel 3)

```
Algorithm 2.A: Computing encryption key (AES-256)
1. Generate random 32-byte file encryption key
2. Compute U = SHA-256(password || User Validation Salt)
3. Compute UE = AES-256-CBC(file_key, SHA-256(password || User Key Salt))
4. Similar for O and OE with owner password

Algorithm 2.B: Password validation (AES-256)
1. Compute hash = SHA-256(password || Validation Salt || U)
2. Compare with first 32 bytes of U
3. If match, decrypt UE with SHA-256(password || Key Salt) to get file key
```

### TODO Tecnico

- [ ] **Fase 1: SHA-256 Integration**
  - [ ] DBMS_CRYPTO.HASH com HASH_SH256
  - [ ] Substituir MD5 em key derivation
  - [ ] 32-byte validation/key salts

- [ ] **Fase 2: AES-256 CBC**
  - [ ] DBMS_CRYPTO.ENCRYPT com AES256_CBC_PKCS5
  - [ ] 32-byte encryption keys
  - [ ] 16-byte IV (mesmo que AES-128)

- [ ] **Fase 3: Unicode Passwords**
  - [ ] SASLprep normalization (RFC 4013)
  - [ ] UTF-8 encoding
  - [ ] Max 127 bytes

- [ ] **Fase 4: Extension Level**
  - [ ] /Extensions << /ADBE << /BaseVersion /1.7 /ExtensionLevel 3 >> >>
  - [ ] Compatibilidade com leitores

### Comparativo de Seguranca

| Versao | Encryption | Key | Hash | Seguranca |
|--------|------------|-----|------|-----------|
| PDF 1.4 | RC4-128 | 128-bit | MD5 | ⚠️ Fraco |
| PDF 1.5 | AES-128 | 128-bit | MD5 | ✅ Bom |
| PDF 1.7 Ext3 | AES-256 | 256-bit | SHA-256 | ✅✅ Forte |
| PDF 2.0 | AES-256 | 256-bit | SHA-256/384/512 | ✅✅✅ Muito Forte |

---

## v3.6.0 - PDF 2.0 Support 💡

**Status:** Proposed
**Target:** Q3 2027

### Objetivo
Suporte ao PDF 2.0 (ISO 32000-2:2020), a versao mais recente do padrao PDF.

### PDF 2.0 Novidades

| Feature | Status | Prioridade | Descricao |
|---------|--------|------------|-----------|
| **AES-256 Nativo** | 💡 Proposed | Alta | Sem Extension Level |
| **SHA-384/512** | 💡 Proposed | Alta | Hashes mais fortes |
| **Unencrypted Wrapper** | 💡 Proposed | Media | Documento wrapper nao criptografado |
| **Page-Level Encryption** | 💡 Proposed | Media | Criptografia por pagina |
| **Associated Files** | 💡 Proposed | Baixa | Arquivos associados (AF) |
| **Namespaces** | 💡 Proposed | Baixa | Namespaces para extensoes |
| **Deprecated Removal** | 💡 Proposed | Baixa | Remover features obsoletas |

### Estrutura PDF 2.0

```
%PDF-2.0
% Sem mais /Extensions necessario para AES-256
% Header mais limpo

/Encrypt <<
  /Filter /Standard
  /V 6                    % Version 6 = PDF 2.0 AES-256
  /R 6                    % Revision 6
  /Length 256
  /CF << ... >>
  /O (48 bytes)
  /U (48 bytes)
  /OE (32 bytes)
  /UE (32 bytes)
  /Perms (16 bytes)
  /P permissions
>>
```

### Mudancas Principais PDF 2.0

1. **Header simplificado**: `%PDF-2.0` (sem necessidade de binary marker)
2. **AES-256 como padrao**: Sem necessidade de Extension Level
3. **Deprecations removidas**:
   - RC4 encryption (removido)
   - LZW compression (removido)
   - Standard security handler revisions 2-4
4. **Novos objetos**:
   - Page-level security
   - Associated files (embedded resources)
   - Document parts (modular PDFs)

### API Proposta

```sql
-- Criar PDF 2.0 com AES-256
PL_FPDF.fpdf();
PL_FPDF.SetPDFVersion('2.0');
PL_FPDF.SetEncryption('AES-256', 'user123', 'owner456');
PL_FPDF.AddPage();
l_pdf := PL_FPDF.Output();

-- Verificar versao suportada
SELECT PL_FPDF.GetSupportedVersions() FROM DUAL;
-- Retorna: ["1.4", "1.5", "1.6", "1.7", "2.0"]

-- Upgrade de versao
l_pdf := PL_FPDF.UpgradePDFVersion(l_old_pdf, '2.0');
```

### Compatibilidade

| Leitor | PDF 1.4 | PDF 1.5 | PDF 1.7 | PDF 2.0 |
|--------|---------|---------|---------|---------|
| Adobe Reader DC | ✅ | ✅ | ✅ | ✅ |
| Foxit Reader | ✅ | ✅ | ✅ | ✅ |
| Chrome PDF | ✅ | ✅ | ✅ | ⚠️ |
| Firefox PDF.js | ✅ | ✅ | ✅ | ⚠️ |
| Preview (macOS) | ✅ | ✅ | ✅ | ✅ |

⚠️ = Suporte parcial (pode nao suportar todas as features)

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
