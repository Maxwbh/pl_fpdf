# PL_FPDF Roadmap

**Versao Atual:** 3.2.0 | **Atualizado:** 2026-03-31

---

## Versoes Lancadas

### v2.0.0 - Foundation (Dez 2025) ✅

| Feature | Status |
|---------|--------|
| Init/Reset/IsInitialized | ✅ |
| Multi-page documents | ✅ |
| CLOB buffer (unlimited) | ✅ |
| UTF-8 encoding | ✅ |
| TrueType fonts | ✅ |
| PNG/JPEG images | ✅ |
| Text rotation | ✅ |
| Native compilation | ✅ |
| QR Code / Barcode | ✅ |
| PIX QR Code (extension) | ✅ |
| Boleto barcode (extension) | ✅ |

### v3.0.0 - PDF Manipulation (Fev 2026) ✅

| Feature | Status |
|---------|--------|
| LoadPDF - Carregar PDF existente | ✅ |
| GetPageCount / GetPageInfo | ✅ |
| RotatePage (0, 90, 180, 270) | ✅ |
| RemovePage | ✅ |
| AddWatermark (texto com opacidade) | ✅ |
| OverlayText / OverlayImage | ✅ |
| OutputModifiedPDF | ✅ |
| MergePDFs | ✅ |
| SplitPDF | ✅ |
| ExtractPages | ✅ |

### v3.2.0 - Security RC4 (Mar 2026) ✅

| Feature | Status |
|---------|--------|
| RC4 40-bit encryption | ✅ |
| RC4 128-bit encryption | ✅ |
| Password protection (user/owner) | ✅ |
| Permission controls (8 flags) | ✅ |
| DecryptPDF | ✅ |
| GetSecurityInfo | ✅ |
| SetPDFVersion | ✅ |

---

## Versoes Planejadas

### v3.2.1 - Security AES (Q2 2026)

**Prioridade:** Alta

| Feature | Status | Estimativa |
|---------|--------|------------|
| AES-128 CBC mode | Pendente | 3 dias |
| AES-256 CBC mode (PDF 1.7) | Pendente | 2 dias |
| Initialization vectors (IV) | Pendente | 1 dia |
| PKCS#7 padding | Pendente | 1 dia |
| PDF version auto-upgrade | Pendente | 1 dia |

**Total:** ~8 dias

---

### v3.3.0 - Bookmarks & Links (Q3 2026)

**Prioridade:** Media

| Feature | Status | Estimativa |
|---------|--------|------------|
| AddBookmark (outline entries) | Pendente | 2 dias |
| Nested bookmarks | Pendente | 1 dia |
| AddLink (URL externo) | Pendente | 1 dia |
| AddInternalLink (goto page) | Pendente | 1 dia |
| Named destinations | Pendente | 1 dia |
| GetBookmarks (parse existing) | Pendente | 2 dias |

**Total:** ~8 dias

---

### v3.4.0 - PDF 1.5/1.6 (Q4 2026)

**Prioridade:** Media

| Feature | Status | Estimativa |
|---------|--------|------------|
| Object Streams | Pendente | 1 semana |
| Cross-Reference Streams | Pendente | 1 semana |
| Compression filters | Pendente | 3 dias |
| Tagged PDF (basic) | Pendente | 1 semana |

**Total:** ~4 semanas

---

### v3.5.0 - AcroForms (Q1 2027)

**Prioridade:** Media

| Feature | Status | Estimativa |
|---------|--------|------------|
| Text fields | Pendente | 3 dias |
| Checkboxes | Pendente | 2 dias |
| Radio buttons | Pendente | 2 dias |
| Dropdown lists | Pendente | 2 dias |
| Form field validation | Pendente | 2 dias |
| Fill existing forms | Pendente | 3 dias |

**Total:** ~3 semanas

---

### v4.0.0 - PDF 2.0 (2028)

**Prioridade:** Futura

| Feature | Status |
|---------|--------|
| PDF 2.0 header nativo | Pendente |
| AES-256 sem extensions | Pendente |
| Digital signatures (PKCS#7) | Pendente |
| PAdES compliance | Pendente |
| PDF/A output | Pendente |
| PDF/UA accessibility | Pendente |
| ZUGFeRD / Factur-X | Pendente |

---

## Backlog (Sem Versao Definida)

| Feature | Complexidade | Valor |
|---------|--------------|-------|
| HTML to PDF (subset) | Alta | Alto |
| Table auto-pagination | Media | Alto |
| Headers/Footers automaticos | Baixa | Medio |
| Annotations (comments) | Media | Baixo |
| JavaScript actions | Alta | Baixo |
| Layers (OCG) | Media | Baixo |

---

## Principios

1. **Oracle 19c sempre suportado** - Nunca quebrar compatibilidade
2. **Package-only** - Sem tabelas, types ou sequences externas
3. **Backward compatible** - APIs existentes nao mudam
4. **Testes primeiro** - Toda feature com testes

---

## Como Contribuir

1. Escolha um item do roadmap
2. Abra issue para discussao
3. Implemente com testes
4. Envie Pull Request

**Contato:** @maxwbh | maxwbh@gmail.com
