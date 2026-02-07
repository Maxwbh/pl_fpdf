# PL_FPDF Roadmap

> Gestao de features e evolucao do projeto

**Versao Atual:** 3.0.0-beta
**Ultima Atualizacao:** 2026-01

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

## v3.0.0 - PDF Manipulation 🧪

**Status:** Beta (Em validacao)
**Target:** Q1 2026

### Phase 4 - Implemented Features

| Feature | Status | Descricao |
|---------|--------|-----------|
| **4.1 PDF Parser** | 🧪 Beta | Leitura de PDFs existentes |
| **4.2 Page Management** | 🧪 Beta | Navegacao e info de paginas |
| **4.3 Watermarks** | 🧪 Beta | Marca d'agua texto/imagem |
| **4.4 OutputModifiedPDF** | 🧪 Beta | Salvar PDF modificado |
| **4.5 Text/Image Overlay** | 🧪 Beta | Adicionar conteudo sobre PDF |
| **4.6 Merge & Split** | 🧪 Beta | Combinar/dividir PDFs |

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
PL_FPDF.AddTextOverlay(1, 100, 50, 'Aprovado');

-- Merge de PDFs
PL_FPDF.LoadPDF(l_pdf1, 'doc1');
PL_FPDF.LoadPDF(l_pdf2, 'doc2');
l_merged := PL_FPDF.MergePDFs('doc1,doc2');

-- Split de PDF
PL_FPDF.SplitPDF('1-5', l_part1);
PL_FPDF.SplitPDF('6-10', l_part2);

-- Salvar modificacoes
l_result := PL_FPDF.OutputModifiedPDF();
```

### Pendente para Release

- [ ] Executar suite completa de testes (150+ testes)
- [ ] Corrigir falhas encontradas
- [ ] Performance benchmarking
- [ ] Promover Beta → RC → Final

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

- [FUTURE_IMPROVEMENTS_ROADMAP.md](roadmaps/FUTURE_IMPROVEMENTS_ROADMAP.md) - Plano detalhado
- [MIGRATION_ROADMAP.md](roadmaps/MIGRATION_ROADMAP.md) - Estrategia de migracao
- [PHASE_4_GUIDE.md](guides/PHASE_4_GUIDE.md) - Guia da Fase 4

---

**Contato:** maxwbh@gmail.com
