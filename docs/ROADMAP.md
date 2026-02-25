# PL_FPDF Roadmap

> Gestao de features e evolucao do projeto

**Versao Atual:** 3.0.0
**Ultima Atualizacao:** 2026-02

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

**Status:** Planned
**Target:** Q3 2026

| Feature | Status | Prioridade |
|---------|--------|------------|
| PDF Password Protection | 📋 Planned | Alta |
| RC4 40-bit encryption | 📋 Planned | Alta |
| AES 128-bit encryption | 📋 Planned | Alta |
| AES 256-bit encryption | 💡 Proposed | Media |
| Permission controls | 📋 Planned | Alta |
| PDF Decryption | 📋 Planned | Alta |

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
