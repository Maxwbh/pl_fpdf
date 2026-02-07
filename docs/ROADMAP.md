# PL_FPDF Feature Roadmap

> Gestao de features e evolucao do projeto

---

## Status das Features

| Status | Descricao |
|--------|-----------|
| ✅ Released | Disponivel em producao |
| 🚧 In Progress | Em desenvolvimento |
| 📋 Planned | Planejado para proxima versao |
| 💡 Proposed | Proposta em avaliacao |

---

## v2.0.0 - Current Release ✅

**Status:** Released (Dez 2025)

| Feature | Status | Notas |
|---------|--------|-------|
| Init/Reset/IsInitialized | ✅ Released | API moderna |
| Multi-page documents | ✅ Released | Paginas ilimitadas |
| CLOB buffer | ✅ Released | Sem limite de tamanho |
| UTF-8 encoding | ✅ Released | Caracteres internacionais |
| TrueType fonts | ✅ Released | Embedding completo |
| PNG/JPEG images | ✅ Released | Parsing nativo |
| Text rotation | ✅ Released | 0, 90, 180, 270 graus |
| Native compilation | ✅ Released | 2-3x mais rapido |
| Custom exceptions | ✅ Released | 17 tipos de erro |
| JSON configuration | ✅ Released | Oracle 19c+ |
| QR Code (generic) | ✅ Released | Qualquer payload |
| Barcode (generic) | ✅ Released | Code128, ITF |

### Extensions (Opcional)

| Feature | Status | Notas |
|---------|--------|-------|
| PIX QR Code | ✅ Released | EMV standard |
| Boleto barcode | ✅ Released | FEBRABAN standard |

---

## v2.1.0 - Security 📋

**Status:** Planned
**Target:** Q1 2026

### PDF Password Protection

Protecao de documentos com criptografia.

```sql
PL_FPDF.SetProtection(
  p_user_password  => 'abrir123',
  p_owner_password => 'admin456',
  p_permissions    => 'print,copy'
);
```

| Subtask | Status | Prioridade |
|---------|--------|------------|
| RC4 40-bit encryption | 📋 Planned | Alta |
| AES 128-bit encryption | 📋 Planned | Alta |
| AES 256-bit encryption | 💡 Proposed | Media |
| User password (open) | 📋 Planned | Alta |
| Owner password (edit) | 📋 Planned | Alta |
| Permission: print | 📋 Planned | Alta |
| Permission: copy | 📋 Planned | Alta |
| Permission: modify | 📋 Planned | Media |
| Permission: annotations | 💡 Proposed | Baixa |

**Referencias:**
- PDF Reference 1.7 - Chapter 3.5 Encryption
- FPDF Protection Script #37

---

## v2.2.0 - Navigation 📋

**Status:** Planned
**Target:** Q2 2026

### Hyperlinks

```sql
-- Link externo
PL_FPDF.AddLink(
  p_url    => 'https://example.com',
  p_x      => 10,
  p_y      => 50,
  p_width  => 80,
  p_height => 10
);

-- Link interno
PL_FPDF.AddInternalLink(
  p_page   => 2,
  p_x      => 10,
  p_y      => 70
);
```

| Subtask | Status | Prioridade |
|---------|--------|------------|
| External URL links | 📋 Planned | Alta |
| Internal page links | 📋 Planned | Media |
| Named destinations | 💡 Proposed | Baixa |

### Bookmarks (Outline)

```sql
PL_FPDF.AddBookmark('Capitulo 1', p_level => 0);
PL_FPDF.AddBookmark('Secao 1.1', p_level => 1);
```

| Subtask | Status | Prioridade |
|---------|--------|------------|
| Simple bookmarks | 📋 Planned | Alta |
| Hierarchical levels | 📋 Planned | Media |
| Bookmark styling | 💡 Proposed | Baixa |

---

## v2.3.0 - Archiving 💡

**Status:** Proposed
**Target:** Q3 2026

### PDF/A Compliance

Documentos para arquivamento de longo prazo (ISO 19005).

```sql
PL_FPDF.Init('P', 'mm', 'A4', p_pdfa => TRUE);
```

| Subtask | Status | Prioridade |
|---------|--------|------------|
| PDF/A-1b basic | 💡 Proposed | Alta |
| XMP metadata | 💡 Proposed | Alta |
| Color profiles | 💡 Proposed | Media |
| Font embedding required | 💡 Proposed | Alta |
| veraPDF validation | 💡 Proposed | Media |

---

## v3.0.0 - Digital Signature 💡

**Status:** Proposed
**Target:** 2026

### X.509 Certificates

```sql
PL_FPDF.AddSignature(
  p_certificate => l_cert_blob,
  p_password    => 'cert_pass',
  p_reason      => 'Aprovacao',
  p_location    => 'Sao Paulo'
);
```

| Subtask | Status | Prioridade |
|---------|--------|------------|
| PKCS#7 signature | 💡 Proposed | Alta |
| Visible signature | 💡 Proposed | Media |
| Timestamp (TSA) | 💡 Proposed | Media |
| Multiple signatures | 💡 Proposed | Baixa |
| ICP-Brasil support | 💡 Proposed | Alta |

---

## Backlog 💡

Features em avaliacao para versoes futuras.

| Feature | Prioridade | Complexidade | Notas |
|---------|------------|--------------|-------|
| Watermarks | Media | Baixa | Texto/imagem |
| Annotations | Baixa | Media | Comentarios |
| Layers (OCG) | Baixa | Alta | PDF 1.5+ |
| Attachments | Baixa | Media | Arquivos embarcados |
| Forms (AcroForms) | Baixa | Alta | Campos interativos |
| Compression | Media | Media | Flate/LZW |
| Merge PDFs | Media | Media | Combinar docs |
| Split PDFs | Baixa | Media | Dividir docs |

---

## Como Contribuir

1. **Escolha uma feature** do roadmap
2. **Abra uma issue** para discussao
3. **Fork e implemente**
4. **Envie um PR**

Veja [CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Prioridades

**Alta:** Recursos solicitados por multiplos usuarios ou essenciais para casos de uso comuns.

**Media:** Recursos uteis mas nao criticos.

**Baixa:** Nice-to-have, implementar quando houver tempo.

---

**Contato:** maxwbh@gmail.com
**Ultima atualizacao:** 2025-12-19
