# Changelog

All notable changes to PL_FPDF will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.4.0] - 2026-11-07

### Corrigido
- Acento nas fontes padrão saía como dois glifos: o texto passa a ser convertido para WinAnsi
- `GetStringWidth`, centralizar e alinhar à direita com acento levantavam `ORA-06502`
- Oracle 26ai: a tabela de larguras usava `chr(i)`, e todo `SetFont` de fonte padrão levantava `ORA-29275`
- `Image` recusava todo PNG em banco AL32UTF8; o stream de imagem perdia o último byte
- `LoadPDF` aceitava PDF cifrado e devolvia páginas em branco; agora recusa com `ORA-20867`
- `Link` deixava `/Annots` aberto nas páginas anteriores (`ORA-06533` no segundo documento)
- Extensão de boleto: o fator de vencimento recomeça em 1000 desde 22/02/2025

### Adicionado
- `ImageFromBlob` (imagem de um BLOB, sem ACL de rede) e fonte TrueType de fato embutida
- Guias de instalação, compatibilidade, migração e problemas comuns (PT/EN), APEX, e `@since` em cada API

### Alterado — incompatível
- Caractere fora do WinAnsi numa fonte padrão levanta `ORA-20203`, em vez de sair como `?`
- `AddLink`, `SetLink` e link numérico levantam `ORA-20601`: o link interno nunca funcionou
- Saem `SetUTF8Enabled` e `IsUTF8Enabled`, que não faziam nada

> O que fazer em cada mudança: [MIGRATION.md](docs/MIGRATION.md). Validada no Oracle 19c e no 26ai.

---

## [3.3.0] - 2026-08-31

### Adicionado
- Instalação em **um arquivo**: `dist/pl_fpdf_install.sql`, sem clone
- `PL_FPDF_UTIL` — o package foi separado em dois; 3.147 linhas sem relação com PDF saíram do principal
- Documentação e site em inglês
- Exemplos completos, sem imagem: boleto (FEBRABAN) e ingresso de evento
- Cifragem de verdade: `EncryptPDF` e `SetEncryption` passam a cifrar os fluxos
  e as strings, em RC4 e em AES-128/AES-256 implementados no package, sem
  `DBMS_CRYPTO`. Até a 3.2.0 o PDF saía marcado como protegido e com o
  conteúdo em claro

### Corrigido
- `AddWatermark` não desenhava: a marca pedia uma fonte que nenhuma página declara
- `Reset` não limpava os metadados — `/Keywords` e `/Author` de um documento reapareciam em todos os seguintes da mesma sessão
- PDF cifrado abria com a senha, mas sem páginas
- Mais 14 defeitos, cada um com teste ou verificação estática que impede o retorno

### Alterado
- **Incompatível:** `Triangle` honra o `porientation`, que antes era aceito e ignorado
- Buffer estourado agora recusa com erro próprio (`-20841`, `-20866`) em vez de truncar em silêncio
- Licença MIT, com autorização de relicenciamento do autor do porte de 2017

### Removido
- Dez invólucros herdados do PHP e sete rotinas de demonstração do porte original

> Sintoma, causa e conserto de cada defeito: no comentário do código e na verificação que o guarda.

---

## [Não lançado]

O que está planejado, e em que ordem, fica no [ROADMAP](docs/ROADMAP.md). As
"operações avançadas de página" que este espaço anunciava para o 2º trimestre
de 2026 não saíram, e foram para o backlog de lá, sem data.

---

## [3.2.0] - 2026-07-17 ✅

### 🧰 Tooling

**Status:** Released
**Author:** @maxwbh

> **Correção (nov/2026).** Esta entrada dava a criptografia — `EncryptPDF`,
> `DecryptPDF`, `IsEncrypted`, `GetSecurityInfo`, `SetEncryption`,
> `SetPermissions`, `SetPDFVersion`, `GetPDFVersion` — como novidade da 3.2.0.
> Ela já estava na tag 3.0.0: entre as duas tags, o código só mudou o número
> de versão no cabeçalho. A lista foi para a entrada da 3.0.0, abaixo.

### Tooling
- `scripts/docx_to_plfpdf/` - Python generator that converts `.docx` files
  into PL/SQL blocks using PL_FPDF (headings, styled runs, lists, tables,
  inline images, page breaks)
- Real-world examples in `scripts/docx_to_plfpdf/examples/`

### Fixed
- `co_version` and package headers aligned with released version (3.2.0)

---

## [3.0.0] - 2026-02-25 ✅

### 🎉 Phase 4 Complete: PDF Manipulation

**Status:** Released
**Author:** @maxwbh

Major release with full PDF reading and manipulation capabilities.

### Phase 4.1 - PDF Parser
- `LoadPDF()` - Load existing PDF into memory
- `GetPageCount()` - Get number of pages
- `GetPDFInfo()` - Get PDF metadata as JSON
- `GetPageInfo()` - Get page information (MediaBox, rotation)
- `ClearPDFCache()` - Clear loaded PDF from memory

### Phase 4.2 - Page Management
- `RotatePage()` - Rotate page (0, 90, 180, 270 degrees)
- `RemovePage()` - Mark page for removal
- `GetActivePageCount()` - Count non-removed pages
- `IsPageRemoved()` - Check if page is marked for removal
- `IsPDFModified()` - Check if PDF has pending changes

### Phase 4.3 - Watermarks
- `AddWatermark()` - Add text watermark with opacity, rotation, position
- `GetWatermarks()` - List all watermarks as JSON

### Phase 4.4 - Output Modified PDF
- `OutputModifiedPDF()` - Generate modified PDF with all changes applied

### Phase 4.5 - Text & Image Overlay
- `OverlayText()` - Add text at specific coordinates with formatting
- `OverlayImage()` - Add image at specific position with sizing
- `RemoveOverlay()` - Remove specific overlay by ID
- `ClearOverlays()` - Remove all overlays from page

### Phase 4.6 - Merge & Split
- `LoadPDFWithID()` - Load PDF with unique identifier
- `GetLoadedPDFs()` - List all loaded PDFs as JSON
- `UnloadPDF()` - Remove PDF from memory
- `MergePDFs()` - Merge multiple PDFs into single document
- `SplitPDF()` - Split PDF by page ranges
- `ExtractPages()` - Extract specific pages to new PDF

### Security (encryption API)
- `EncryptPDF()` - Encrypt PDF with owner/user passwords and permissions
- `DecryptPDF()` - Decrypt protected PDF
- `IsEncrypted()` - Check if PDF is encrypted
- `GetSecurityInfo()` - Security metadata as JSON
- `SetEncryption()` / `SetPermissions()` - Configure protection for generated PDFs
- `SetPDFVersion()` / `GetPDFVersion()` - Control output PDF version

> **Protegia só no rótulo, até a 3.2.0.** O dicionário `/Encrypt`, as senhas e
> as permissões saíam corretos, mas os fluxos de conteúdo iam **em claro**, e o
> `DecryptPDF` apenas apagava o `/Encrypt`. A cifragem de fato — RC4 e AES nos
> fluxos e nas strings, sem `DBMS_CRYPTO` — chegou na 3.3.0. Esta lista
> constava, por engano, da entrada da 3.2.0.

### Technical Improvements
- Removed APEX dependencies (pure PL/SQL)
- Replaced REGEXP_SUBSTR with INSTR/SUBSTR for Oracle compatibility
- PDF version updated to 1.4 default
- Robust xref parser with fallback for incorrect offsets
- MediaBox inheritance from parent Pages object
- 100% test coverage (all phases passing)

### Error Codes
- -20800 to -20839: Phase 4 specific error codes
- Consistent error handling across all operations

---

## [2.0.0] - 2025-12 ✅

### 🎉 Phases 1-3: PDF Generation

**Status:** Released

Complete PDF generation from scratch in pure PL/SQL.

### Phase 1 - Core Generation
- `fpdf()` - Initialize PDF document
- `AddPage()` - Add new page with orientation/format
- `SetFont()` - Set font family, style, size
- `Cell()` / `MultiCell()` - Add text cells
- `Text()` - Add text at position
- `Output()` - Generate PDF as BLOB
- `SetMargins()` - Set page margins

### Phase 2 - Graphics & Images
- `Line()` / `Rect()` / `Circle()` - Draw shapes
- `SetDrawColor()` / `SetFillColor()` - Set colors
- `Image()` / `ImageBlob()` - Add PNG/JPEG images
- Native BLOB image support (no ORDSYS.ORDIMAGE)
- `SetLineWidth()` - Set line thickness

### Phase 3 - Advanced Features
- TrueType font support with subsetting
- UTF-8 encoding
- Text rotation
- QR Code generation
- Barcode generation (Code39, EAN-13)
- PIX QR Code (Brazilian payments)
- Boleto barcode (Brazilian payments)
- JSON configuration support
- Native compilation for performance

### Infrastructure
- CLOB-based document buffer (unlimited size)
- Custom exception handling
- Logging system with debug levels

---

## [0.9.4] - 2017-12

### Original Release

**Author:** Pierre-Gilles Levallois

Original PL/SQL port of PHP FPDF library.

- Basic PDF generation
- Core fonts support
- Simple text and graphics
- Page management

---

## Links

- [Roadmap](docs/ROADMAP.md)
- [API Reference](docs/API_REFERENCE.md)
- [Contributing](CONTRIBUTING.md)
