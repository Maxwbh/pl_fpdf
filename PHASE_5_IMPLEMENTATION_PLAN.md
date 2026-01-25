# Phase 5 Implementation Plan - Advanced Page Operations & Automation
# Plano de Implementação Fase 5 - Operações Avançadas de Páginas e Automação

**Version / Versão:** 3.1.0 (Phase 5)
**Status:** Planning / Planejamento 📋
**Dependencies:** Phase 4.6 (Merge/Split) must be complete
**Start Date / Data Início:** 2026-01-25

[🇬🇧 English](#english) | [🇧🇷 Português](#português)

---

## English

### 🎯 Phase 5 Overview

Phase 5 builds on Phase 4.6 (basic merge/split) with advanced page manipulation and automation features:
- **Insert pages** from one PDF into another at specific positions
- **Reorder pages** within documents with flexible operations
- **Replace pages** by swapping content
- **Duplicate pages** within or across documents
- **Batch operations** for processing multiple PDFs
- **Smart bookmarks** management across operations

**Note:** Basic merge and split operations are in Phase 4.6. This phase focuses on advanced manipulation and automation workflows.

### ✨ Key Features

| Feature | Description | Version |
|---------|-------------|---------|
| **InsertPagesFrom** | Insert pages from another PDF at position | 3.1.0-a.1 |
| **ReorderPages** | Rearrange page order with multiple operations | 3.1.0-a.2 |
| **ReplacePage** | Replace page content from another PDF | 3.1.0-a.3 |
| **DuplicatePage** | Copy page within or across PDFs | 3.1.0-a.4 |
| **BatchProcess** | Process multiple PDFs with same operations | 3.1.0-a.5 |
| **SmartBookmarks** | Automatic bookmark management | 3.1.0-a.6 |

### 🏗️ Architecture

Phase 5 builds on Phase 4.6's multi-document infrastructure:

```
Phase 4.6 Foundation:
├── LoadPDFWithID() - Multi-document loading
├── MergePDFs() - Basic PDF merging
├── SplitPDF() - PDF splitting
├── ExtractPages() - Page extraction
└── Multi-document structures (g_loaded_pdfs)

Phase 5 Extensions:
├── Advanced page insertion (at any position)
├── Page reordering operations (move, swap, reverse)
├── Page replacement and duplication
├── Batch processing automation
├── Bookmark management and synchronization
└── Template-based operations
```

### 📋 Implementation Sub-Phases

#### **Phase 5.1: Multi-Document Loading (v3.1.0-a.1)**

**Objective:** Support loading and managing multiple PDFs simultaneously

**New Global Structures:**
```sql
TYPE t_loaded_pdf IS RECORD (
  pdf_id        VARCHAR2(50),      -- Unique identifier
  pdf_blob      BLOB,              -- Original PDF
  pages         JSON_ARRAY_T,      -- Page information
  objects       JSON_OBJECT_T,     -- PDF objects
  xref          JSON_ARRAY_T,      -- Cross-reference table
  trailer       JSON_OBJECT_T,     -- PDF trailer
  page_count    PLS_INTEGER,       -- Number of pages
  loaded_date   TIMESTAMP          -- Load timestamp
);

TYPE t_loaded_pdfs IS TABLE OF t_loaded_pdf INDEX BY VARCHAR2(50);
g_loaded_pdfs t_loaded_pdfs;      -- Multiple PDF cache
```

**New APIs:**
```sql
-- Load PDF with identifier
PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
);

-- Get loaded PDF IDs
FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T;

-- Unload specific PDF
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);

-- Check if PDF is loaded
FUNCTION IsPDFLoaded(p_pdf_id IN VARCHAR2) RETURN BOOLEAN;
```

**Test Cases:**
- Load 2+ PDFs simultaneously
- Retrieve list of loaded PDFs
- Unload specific PDF
- Attempt to load duplicate ID (should error)

---

#### **Phase 5.2: PDF Merging (v3.1.0-a.2)**

**Objective:** Combine multiple PDFs into single document

**APIs:**
```sql
-- Merge loaded PDFs in specified order
FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,  -- ['pdf1', 'pdf2', 'pdf3']
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

-- Merge PDFs directly (convenience method)
FUNCTION MergePDFBlobs(
  p_pdfs IN JSON_ARRAY_T  -- Array of BLOBs
) RETURN BLOB;
```

**Options (JSON_OBJECT_T):**
```json
{
  "addBookmarks": true,           // Add bookmarks for each source PDF
  "bookmarkPrefix": "Document ",  // Bookmark name prefix
  "preserveMetadata": true,       // Keep metadata from first PDF
  "addPageNumbers": false         // Add page numbers to merged doc
}
```

**Process:**
1. Validate all PDFs loaded
2. Calculate new object numbering scheme
3. Merge page trees from all PDFs
4. Copy and renumber all objects
5. Consolidate resources (fonts, images)
6. Rebuild xref table
7. Generate new trailer
8. Output merged BLOB

**Test Cases:**
- Merge 2 PDFs
- Merge 5 PDFs
- Merge with bookmarks enabled
- Merge with conflicting resources
- Merge empty PDF (should error)

---

#### **Phase 5.3: PDF Splitting (v3.1.0-a.3)**

**Objective:** Split single PDF into multiple documents

**APIs:**
```sql
-- Split PDF by page ranges
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_ranges IN JSON_ARRAY_T  -- ['1-3', '4-6', '7-10']
) RETURN JSON_ARRAY_T;  -- Array of BLOBs

-- Split PDF into individual pages
FUNCTION SplitPDFByPages(
  p_pdf_id IN VARCHAR2
) RETURN JSON_ARRAY_T;  -- One BLOB per page

-- Split PDF into chunks of N pages
FUNCTION SplitPDFByChunkSize(
  p_pdf_id IN VARCHAR2,
  p_chunk_size IN PLS_INTEGER  -- e.g., 5 pages per file
) RETURN JSON_ARRAY_T;
```

**Process:**
1. Validate PDF loaded and page ranges
2. For each range:
   - Create new PDF structure
   - Copy specified pages with resources
   - Renumber objects
   - Build xref and trailer
   - Generate BLOB
3. Return array of BLOBs

**Test Cases:**
- Split 10-page PDF into 3 ranges
- Split into individual pages
- Split into 3-page chunks
- Invalid range (should error)
- Overlapping ranges (should error)

---

#### **Phase 5.4: Page Extraction (v3.1.0-a.4)**

**Objective:** Extract specific pages to create new PDF

**APIs:**
```sql
-- Extract specific pages to new PDF
FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,  -- '1,3,5-7,10' or 'ALL'
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

-- Extract pages excluding some
FUNCTION ExtractPagesExcept(
  p_pdf_id IN VARCHAR2,
  p_exclude_pages IN VARCHAR2  -- '2,4,8-9'
) RETURN BLOB;
```

**Options:**
```json
{
  "preserveBookmarks": true,    // Keep bookmarks for extracted pages
  "renumberPages": true,        // Renumber from page 1
  "addMetadata": {
    "title": "Extracted Pages",
    "author": "PL_FPDF"
  }
}
```

**Process:**
1. Parse page specification
2. Validate pages exist
3. Create new PDF with selected pages
4. Copy page resources (fonts, images)
5. Optionally filter bookmarks
6. Generate BLOB

**Test Cases:**
- Extract pages 1,3,5 from 10-page PDF
- Extract range 5-10
- Extract all except 2,4
- Extract with bookmarks preserved
- Invalid page number (should error)

---

#### **Phase 5.5: Page Insertion (v3.1.0-a.5)**

**Objective:** Insert pages from one PDF into another

**APIs:**
```sql
-- Insert pages from source PDF into current PDF
PROCEDURE InsertPagesFrom(
  p_source_pdf_id IN VARCHAR2,
  p_source_pages IN VARCHAR2,   -- '1-5' or 'ALL'
  p_insert_position IN PLS_INTEGER,  -- Position in target PDF
  p_target_pdf_id IN VARCHAR2 DEFAULT NULL  -- NULL = current PDF
);

-- Insert pages at beginning
PROCEDURE PrependPages(
  p_source_pdf_id IN VARCHAR2,
  p_source_pages IN VARCHAR2 DEFAULT 'ALL'
);

-- Insert pages at end
PROCEDURE AppendPages(
  p_source_pdf_id IN VARCHAR2,
  p_source_pages IN VARCHAR2 DEFAULT 'ALL'
);
```

**Process:**
1. Validate source and target PDFs loaded
2. Parse source page specification
3. Copy source pages with resources
4. Renumber objects to avoid conflicts
5. Insert into target page tree at position
6. Update page count and references
7. Mark target PDF as modified

**Test Cases:**
- Insert pages 1-3 at position 5
- Prepend 2 pages to PDF
- Append 5 pages to PDF
- Insert into empty PDF
- Insert with resource conflicts

---

#### **Phase 5.6: Page Reordering (v3.1.0-a.6)**

**Objective:** Rearrange page order within PDF

**APIs:**
```sql
-- Reorder pages by new sequence
PROCEDURE ReorderPages(
  p_pdf_id IN VARCHAR2 DEFAULT NULL,
  p_new_order IN JSON_ARRAY_T  -- [3,1,2,5,4]
);

-- Move page to new position
PROCEDURE MovePage(
  p_pdf_id IN VARCHAR2 DEFAULT NULL,
  p_from_page IN PLS_INTEGER,
  p_to_position IN PLS_INTEGER
);

-- Swap two pages
PROCEDURE SwapPages(
  p_pdf_id IN VARCHAR2 DEFAULT NULL,
  p_page1 IN PLS_INTEGER,
  p_page2 IN PLS_INTEGER
);

-- Reverse page order
PROCEDURE ReversePages(
  p_pdf_id IN VARCHAR2 DEFAULT NULL,
  p_page_range IN VARCHAR2 DEFAULT 'ALL'
);
```

**Process:**
1. Validate page numbers and order
2. Create new page sequence
3. Update page tree with new order
4. Maintain page resources and attributes
5. Mark PDF as modified

**Test Cases:**
- Reorder 5 pages to new sequence
- Move page 3 to position 1
- Swap pages 2 and 5
- Reverse all pages
- Reverse pages 3-7 only
- Invalid page number (should error)

---

### 🔧 Technical Considerations

#### **Object Numbering & Conflict Resolution**

When merging PDFs, object numbers from different documents may conflict:

```sql
-- Strategy: Renumber all objects sequentially
-- PDF1: objects 1-100
-- PDF2: objects 1-50 → renumbered to 101-150
-- PDF3: objects 1-75 → renumbered to 151-225

FUNCTION renumber_objects(
  p_pdf_objects IN JSON_OBJECT_T,
  p_offset IN PLS_INTEGER
) RETURN JSON_OBJECT_T;
```

#### **Resource Consolidation**

Duplicate resources (fonts, images) should be detected and deduplicated:

```sql
-- Font deduplication by name and properties
-- Image deduplication by content hash

TYPE t_resource_map IS TABLE OF VARCHAR2(100) INDEX BY VARCHAR2(100);
g_resource_map t_resource_map;  -- old_ref -> new_ref
```

#### **Cross-Reference Table Merging**

Merge xref tables from multiple PDFs:

```sql
FUNCTION merge_xref_tables(
  p_xrefs IN JSON_ARRAY_T,  -- Array of xref tables
  p_offsets IN JSON_ARRAY_T  -- Offset for each PDF's objects
) RETURN JSON_ARRAY_T;
```

#### **Bookmark Handling**

Preserve and merge bookmarks from source PDFs:

```sql
-- Bookmark structure
TYPE t_bookmark IS RECORD (
  title VARCHAR2(200),
  page_number PLS_INTEGER,
  level PLS_INTEGER,
  destination VARCHAR2(50)
);

PROCEDURE merge_bookmarks(
  p_source_bookmarks IN JSON_ARRAY_T,
  p_page_offset IN PLS_INTEGER,
  p_target_bookmarks IN OUT JSON_ARRAY_T
);
```

#### **Memory Management**

Phase 5 operations may load multiple large PDFs:

```sql
-- Maximum loaded PDFs at once
c_max_loaded_pdfs CONSTANT PLS_INTEGER := 10;

-- Auto-cleanup old PDFs
PROCEDURE cleanup_old_pdfs(p_keep_count IN PLS_INTEGER DEFAULT 5);

-- Memory usage monitoring
FUNCTION get_memory_usage RETURN NUMBER;
```

---

### 🧪 Testing Strategy

#### **Test Structure**

```
tests/
├── test_phase_5_1_multi_load.sql       -- Multi-document loading
├── test_phase_5_2_merge.sql            -- PDF merging
├── test_phase_5_3_split.sql            -- PDF splitting
├── test_phase_5_4_extract.sql          -- Page extraction
├── test_phase_5_5_insert.sql           -- Page insertion
├── test_phase_5_6_reorder.sql          -- Page reordering
└── test_phase_5_integration.sql        -- End-to-end workflows
```

#### **Test Data**

Create test PDFs:
- `test_pdf_3pages.pdf` - 3 pages, simple content
- `test_pdf_10pages.pdf` - 10 pages, with images
- `test_pdf_fonts.pdf` - Contains custom fonts
- `test_pdf_bookmarks.pdf` - Has bookmark structure
- `test_pdf_large.pdf` - 50+ pages for performance testing

#### **Performance Targets**

| Operation | Target | Notes |
|-----------|--------|-------|
| Merge 2 PDFs (10 pages each) | < 2 seconds | Simple merge |
| Merge 5 PDFs (50 pages total) | < 5 seconds | With resource dedup |
| Split 50-page PDF | < 3 seconds | Into 10 files |
| Extract 10 pages | < 1 second | From 50-page PDF |
| Reorder 20 pages | < 1 second | Simple reordering |

---

### 📊 Error Codes

New error codes for Phase 5:

| Code | Error | Description |
|------|-------|-------------|
| -20901 | PDF_NOT_LOADED | Specified PDF ID not loaded |
| -20902 | PDF_ALREADY_LOADED | PDF ID already in use |
| -20903 | MAX_PDFS_EXCEEDED | Maximum loaded PDFs exceeded |
| -20904 | INVALID_PDF_ID | Invalid or empty PDF ID |
| -20905 | MERGE_NO_PDFS | No PDFs specified for merge |
| -20906 | MERGE_INVALID_ORDER | Invalid PDF order for merge |
| -20907 | SPLIT_INVALID_RANGE | Invalid page range for split |
| -20908 | SPLIT_OVERLAPPING | Overlapping page ranges |
| -20909 | EXTRACT_INVALID_PAGES | Invalid pages for extraction |
| -20910 | INSERT_INVALID_POSITION | Invalid insertion position |
| -20911 | REORDER_INVALID_SEQUENCE | Invalid page sequence |
| -20912 | REORDER_DUPLICATE_PAGES | Duplicate pages in sequence |
| -20913 | RESOURCE_CONFLICT | Resource conflict during merge |
| -20914 | OBJECT_RENUMBER_FAILED | Object renumbering failed |
| -20915 | BOOKMARK_MERGE_FAILED | Bookmark merge failed |

---

### 🎯 Success Criteria

Phase 5 is complete when:

- ✅ All 6 sub-phases implemented and tested
- ✅ 15+ APIs fully functional
- ✅ 50+ test cases passing
- ✅ Performance targets met
- ✅ Documentation complete (EN/PT-BR)
- ✅ Integration with existing Phase 4 features
- ✅ No memory leaks with large PDFs
- ✅ Error handling for all edge cases

---

### 📝 Use Cases

#### **Use Case 1: Document Consolidation**
```sql
-- Merge monthly reports into annual report
DECLARE
  l_annual_report BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('jan', l_jan_pdf);
  PL_FPDF.LoadPDFWithID('feb', l_feb_pdf);
  -- ... load all 12 months

  l_annual_report := PL_FPDF.MergePDFs(
    JSON_ARRAY_T('["jan","feb","mar",...,"dec"]'),
    JSON_OBJECT_T('{"addBookmarks": true, "bookmarkPrefix": ""}')
  );

  -- Save annual report
  INSERT INTO reports VALUES (l_annual_report);
END;
```

#### **Use Case 2: Document Splitting for Distribution**
```sql
-- Split contract into sections for different parties
DECLARE
  l_sections JSON_ARRAY_T;
  l_party_a BLOB;
  l_party_b BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('contract', l_contract_pdf);

  -- Party A gets pages 1-5, 20-25
  l_party_a := PL_FPDF.ExtractPages('contract', '1-5,20-25');

  -- Party B gets pages 6-15, 20-25
  l_party_b := PL_FPDF.ExtractPages('contract', '6-15,20-25');
END;
```

#### **Use Case 3: Invoice Assembly**
```sql
-- Combine cover letter, invoice, and terms
DECLARE
  l_complete_invoice BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('cover', l_cover_letter);
  PL_FPDF.LoadPDFWithID('invoice', l_invoice_pdf);
  PL_FPDF.LoadPDFWithID('terms', l_terms_pdf);

  l_complete_invoice := PL_FPDF.MergePDFs(
    JSON_ARRAY_T('["cover","invoice","terms"]')
  );
END;
```

#### **Use Case 4: Page Reordering for Printing**
```sql
-- Rearrange pages for booklet printing (page order: 4,1,2,3)
BEGIN
  PL_FPDF.LoadPDFWithID('booklet', l_pdf);
  PL_FPDF.ReorderPages('booklet', JSON_ARRAY_T('[4,1,2,3]'));
  l_print_ready := PL_FPDF.OutputModifiedPDF('booklet');
END;
```

---

## Português

### 🎯 Visão Geral da Fase 5

A Fase 5 estende o PL_FPDF com operações poderosas de múltiplos documentos PDF, permitindo:
- **Mesclar múltiplos PDFs** em um único documento
- **Dividir PDFs** em múltiplos arquivos separados
- **Extrair páginas específicas** para criar novos PDFs
- **Inserir páginas** de um PDF em outro
- **Reordenar páginas** dentro e entre documentos
- **Copiar páginas** entre PDFs com recursos

Esta fase completa as capacidades de manipulação de PDF, tornando o PL_FPDF uma solução abrangente para geração de PDF e fluxos de gerenciamento de documentos.

### ✨ Recursos Principais

| Recurso | Descrição | Versão |
|---------|-----------|--------|
| **MergePDFs** | Combinar 2+ PDFs em único documento | 3.1.0-a.1 |
| **SplitPDF** | Dividir PDF em múltiplos arquivos por intervalos | 3.1.0-a.2 |
| **ExtractPages** | Criar novo PDF de intervalo de páginas específico | 3.1.0-a.3 |
| **InsertPagesFrom** | Inserir páginas de outro PDF em posição | 3.1.0-a.4 |
| **ReorderPages** | Reorganizar ordem de páginas dentro do PDF | 3.1.0-a.5 |
| **CopyPageResources** | Copiar fontes, imagens e recursos entre PDFs | 3.1.0-a.6 |

### 🏗️ Arquitetura

A Fase 5 se baseia na infraestrutura de análise e manipulação de PDF da Fase 4:

```
Fundação Fase 4:
├── LoadPDF() - Carregar e analisar PDF
├── GetPageInfo() - Extrair detalhes da página
├── OutputModifiedPDF() - Gerar PDF modificado
└── Estruturas internas (g_pdf_pages, g_pdf_objects)

Extensões Fase 5:
├── Gerenciamento de múltiplos documentos
├── Cópia de páginas com rastreamento de recursos
├── Mesclagem de tabela de referência cruzada
├── Renumeração de objetos e resolução de conflitos
└── Consolidação de recursos
```

### 📝 Casos de Uso

#### **Caso de Uso 1: Consolidação de Documentos**
```sql
-- Mesclar relatórios mensais em relatório anual
DECLARE
  l_relatorio_anual BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('jan', l_pdf_jan);
  PL_FPDF.LoadPDFWithID('fev', l_pdf_fev);
  -- ... carregar todos os 12 meses

  l_relatorio_anual := PL_FPDF.MergePDFs(
    JSON_ARRAY_T('["jan","fev","mar",...,"dez"]'),
    JSON_OBJECT_T('{"addBookmarks": true, "bookmarkPrefix": ""}')
  );

  -- Salvar relatório anual
  INSERT INTO relatorios VALUES (l_relatorio_anual);
END;
```

#### **Caso de Uso 2: Divisão de Documento para Distribuição**
```sql
-- Dividir contrato em seções para diferentes partes
DECLARE
  l_secoes JSON_ARRAY_T;
  l_parte_a BLOB;
  l_parte_b BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('contrato', l_pdf_contrato);

  -- Parte A recebe páginas 1-5, 20-25
  l_parte_a := PL_FPDF.ExtractPages('contrato', '1-5,20-25');

  -- Parte B recebe páginas 6-15, 20-25
  l_parte_b := PL_FPDF.ExtractPages('contrato', '6-15,20-25');
END;
```

---

## 📅 Implementation Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| 5.1 - Multi-Document Loading | 2-3 days | 📋 Planned |
| 5.2 - PDF Merging | 3-4 days | 📋 Planned |
| 5.3 - PDF Splitting | 2-3 days | 📋 Planned |
| 5.4 - Page Extraction | 2 days | 📋 Planned |
| 5.5 - Page Insertion | 3 days | 📋 Planned |
| 5.6 - Page Reordering | 2 days | 📋 Planned |
| Testing & Documentation | 3-4 days | 📋 Planned |
| **Total** | **17-21 days** | 📋 Planning |

---

## 🚀 Next Steps

1. **Review and approve this plan** ✅
2. **Create development branch** `claude/phase-5-pdf-merging`
3. **Begin Phase 5.1 implementation** - Multi-document loading
4. **Implement and test each sub-phase sequentially**
5. **Update documentation with bilingual support**
6. **Release v3.1.0** - Phase 5 Complete

---

**Prepared by:** Claude Code
**Date:** 2026-01-25
**Next Review:** After Phase 5.1 completion
