# Phase 4.6 Implementation Plan - PDF Merge & Split
# Plano de Implementação Fase 4.6 - Mesclar e Dividir PDFs

**Version / Versão:** 3.0.0-a.7 (Phase 4.6)
**Status:** Planning / Planejamento 📋
**Start Date / Data Início:** 2026-01-25

[🇬🇧 English](#english) | [🇧🇷 Português](#português)

---

## English

### 🎯 Phase 4.6 Overview

Phase 4.6 introduces essential multi-document PDF operations:
- **Merge multiple PDFs** into a single document
- **Split PDFs** into separate files by page ranges
- **Extract page ranges** to create new PDF documents
- **Manage multiple PDFs** in memory simultaneously

These are the most requested features for PDF manipulation and complete the core Phase 4 functionality.

### ✨ Key Features

| Feature | Description | API |
|---------|-------------|-----|
| **Merge PDFs** | Combine 2+ PDFs into one document | `MergePDFs()` |
| **Split PDF** | Divide PDF into multiple files | `SplitPDF()` |
| **Extract Pages** | Create new PDF from page range | `ExtractPages()` |
| **Multi-Load** | Load multiple PDFs with IDs | `LoadPDFWithID()` |
| **List Loaded** | Get all loaded PDF IDs | `GetLoadedPDFs()` |

### 🏗️ Architecture

Phase 4.6 extends Phase 4's single-document model to multi-document:

```
Current Phase 4 (Single Document):
├── g_pdf_loaded BOOLEAN
├── g_pdf_pages JSON_ARRAY_T
├── g_pdf_objects JSON_OBJECT_T
└── Single PDF in memory

Phase 4.6 (Multi-Document):
├── g_loaded_pdfs (collection of PDFs with IDs)
├── g_current_pdf_id (active PDF)
├── Multi-PDF management
└── Cross-document operations
```

---

### 📋 Phase 4.6 API Specification

#### **LoadPDFWithID() - Load PDF with Identifier**

```sql
/*******************************************************************************
* Procedure: LoadPDFWithID / Carregar PDF com Identificador
*
* Description / Descrição:
*   EN: Load PDF into memory with unique identifier for multi-document operations
*   PT: Carregar PDF em memória com identificador único para operações multi-documento
*
* Parameters / Parâmetros:
*   p_pdf_id - Unique identifier for this PDF / Identificador único para este PDF
*   p_pdf_blob - PDF document as BLOB / Documento PDF como BLOB
*
* Notes / Notas:
*   EN: Maximum 10 PDFs can be loaded simultaneously
*   PT: Máximo de 10 PDFs podem ser carregados simultaneamente
*
* Raises / Erros:
*   -20828: PDF ID already loaded / ID do PDF já carregado
*   -20829: Maximum PDFs exceeded (10 max) / Máximo de PDFs excedido
*   -20830: Invalid PDF ID (empty or too long) / ID de PDF inválido
*
* Example / Exemplo:
*   BEGIN
*     PL_FPDF.LoadPDFWithID('doc1', l_pdf1);
*     PL_FPDF.LoadPDFWithID('doc2', l_pdf2);
*     PL_FPDF.LoadPDFWithID('doc3', l_pdf3);
*
*     -- Now can merge them / Agora pode mesclar
*     l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["doc1","doc2","doc3"]'));
*   END;
*******************************************************************************/
PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
);
```

#### **GetLoadedPDFs() - List All Loaded PDFs**

```sql
/*******************************************************************************
* Function: GetLoadedPDFs / Obter PDFs Carregados
*
* Description / Descrição:
*   EN: Get list of all loaded PDF IDs and their metadata
*   PT: Obter lista de todos os IDs de PDF carregados e seus metadados
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array of PDF objects / Array de objetos PDF
*     [{
*       "pdfId": "doc1",
*       "pageCount": 5,
*       "fileSize": 125678,
*       "loadedDate": "2026-01-25T10:30:00"
*     }, ...]
*
* Example / Exemplo:
*   DECLARE
*     l_pdfs JSON_ARRAY_T;
*     l_pdf JSON_OBJECT_T;
*   BEGIN
*     l_pdfs := PL_FPDF.GetLoadedPDFs();
*     FOR i IN 0..l_pdfs.get_size() - 1 LOOP
*       l_pdf := TREAT(l_pdfs.get(i) AS JSON_OBJECT_T);
*       DBMS_OUTPUT.PUT_LINE('PDF: ' || l_pdf.get_string('pdfId') ||
*                           ' Pages: ' || l_pdf.get_number('pageCount'));
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T;
```

#### **UnloadPDF() - Remove PDF from Memory**

```sql
/*******************************************************************************
* Procedure: UnloadPDF / Descarregar PDF
*
* Description / Descrição:
*   EN: Remove specific PDF from memory to free resources
*   PT: Remover PDF específico da memória para liberar recursos
*
* Parameters / Parâmetros:
*   p_pdf_id - PDF identifier to unload / Identificador do PDF para descarregar
*
* Raises / Erros:
*   -20831: PDF ID not found / ID do PDF não encontrado
*******************************************************************************/
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);
```

#### **MergePDFs() - Combine Multiple PDFs**

```sql
/*******************************************************************************
* Function: MergePDFs / Mesclar PDFs
*
* Description / Descrição:
*   EN: Merge multiple loaded PDFs into single document in specified order
*   PT: Mesclar múltiplos PDFs carregados em único documento na ordem especificada
*
* Parameters / Parâmetros:
*   p_pdf_ids - Ordered array of PDF IDs to merge / Array ordenado de IDs de PDF
*   p_options - Optional configuration / Configuração opcional
*
* Options (JSON_OBJECT_T) / Opções:
*   {
*     "preserveMetadata": true,      // Keep metadata from first PDF
*     "addPageNumbers": false,       // Add page numbers to merged doc
*     "pageNumberFormat": "Page %d"  // Format for page numbers
*   }
*
* Returns / Retorna:
*   BLOB - Merged PDF document / Documento PDF mesclado
*
* Raises / Erros:
*   -20832: No PDF IDs provided / Nenhum ID de PDF fornecido
*   -20833: PDF ID in list not loaded / ID de PDF na lista não carregado
*   -20834: Merge failed (resource conflict) / Mesclagem falhou
*
* Example / Exemplo:
*   DECLARE
*     l_merged BLOB;
*     l_options JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     -- Load PDFs
*     PL_FPDF.LoadPDFWithID('report_jan', l_jan_pdf);
*     PL_FPDF.LoadPDFWithID('report_feb', l_feb_pdf);
*     PL_FPDF.LoadPDFWithID('report_mar', l_mar_pdf);
*
*     -- Merge in order / Mesclar em ordem
*     l_merged := PL_FPDF.MergePDFs(
*       JSON_ARRAY_T('["report_jan","report_feb","report_mar"]'),
*       NULL
*     );
*
*     -- Save merged PDF / Salvar PDF mesclado
*     INSERT INTO reports (type, pdf_blob) VALUES ('Q1_2026', l_merged);
*     COMMIT;
*   END;
*******************************************************************************/
FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;
```

#### **SplitPDF() - Divide PDF into Multiple Files**

```sql
/*******************************************************************************
* Function: SplitPDF / Dividir PDF
*
* Description / Descrição:
*   EN: Split loaded PDF into multiple documents by page ranges
*   PT: Dividir PDF carregado em múltiplos documentos por intervalos de páginas
*
* Parameters / Parâmetros:
*   p_pdf_id - PDF identifier to split / Identificador do PDF para dividir
*   p_page_ranges - Array of page range strings / Array de strings de intervalo
*                   Examples: '1-5', '6-10', '11', 'ALL'
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array of BLOB objects (split PDFs) / Array de BLOBs (PDFs divididos)
*
* Raises / Erros:
*   -20831: PDF ID not found / ID do PDF não encontrado
*   -20835: Invalid page range / Intervalo de páginas inválido
*   -20836: Overlapping page ranges / Intervalos de páginas sobrepostos
*   -20837: Page range exceeds document / Intervalo excede documento
*
* Example / Exemplo:
*   DECLARE
*     l_split_pdfs JSON_ARRAY_T;
*     l_part1 BLOB;
*     l_part2 BLOB;
*     l_part3 BLOB;
*   BEGIN
*     PL_FPDF.LoadPDFWithID('contract', l_contract_pdf);
*
*     -- Split into 3 parts / Dividir em 3 partes
*     l_split_pdfs := PL_FPDF.SplitPDF('contract',
*       JSON_ARRAY_T('["1-5", "6-10", "11-15"]')
*     );
*
*     -- Extract each part / Extrair cada parte
*     l_part1 := HEXTORAW(l_split_pdfs.get_string(0));
*     l_part2 := HEXTORAW(l_split_pdfs.get_string(1));
*     l_part3 := HEXTORAW(l_split_pdfs.get_string(2));
*
*     -- Save parts / Salvar partes
*     INSERT INTO contracts (section, pdf_blob) VALUES ('Part1', l_part1);
*     INSERT INTO contracts (section, pdf_blob) VALUES ('Part2', l_part2);
*     INSERT INTO contracts (section, pdf_blob) VALUES ('Part3', l_part3);
*   END;
*******************************************************************************/
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T;
```

#### **ExtractPages() - Create PDF from Page Range**

```sql
/*******************************************************************************
* Function: ExtractPages / Extrair Páginas
*
* Description / Descrição:
*   EN: Extract specific pages from loaded PDF to create new document
*   PT: Extrair páginas específicas do PDF carregado para criar novo documento
*
* Parameters / Parâmetros:
*   p_pdf_id - PDF identifier / Identificador do PDF
*   p_pages - Page specification: '1,3,5-7,10' or 'ALL' / Especificação de páginas
*   p_options - Optional configuration / Configuração opcional
*
* Options (JSON_OBJECT_T) / Opções:
*   {
*     "preserveMetadata": true,      // Keep original metadata
*     "renumberPages": false         // Renumber from page 1
*   }
*
* Returns / Retorna:
*   BLOB - New PDF with extracted pages / Novo PDF com páginas extraídas
*
* Raises / Erros:
*   -20831: PDF ID not found / ID do PDF não encontrado
*   -20838: Invalid page specification / Especificação de páginas inválida
*   -20839: Page number out of range / Número de página fora do intervalo
*
* Example / Exemplo:
*   DECLARE
*     l_extracted BLOB;
*   BEGIN
*     PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
*
*     -- Extract pages 1, 5-10, and 15 / Extrair páginas 1, 5-10 e 15
*     l_extracted := PL_FPDF.ExtractPages('manual', '1,5-10,15', NULL);
*
*     -- Extract all pages except 2 and 4 (use inverse logic)
*     -- First get total pages
*     l_info := PL_FPDF.GetPDFInfo('manual');
*     l_total := l_info.get_number('pageCount');
*     -- Build range excluding 2,4: '1,3,5-N'
*
*     -- Save extracted / Salvar extraído
*     INSERT INTO documents (title, pdf_blob)
*     VALUES ('Manual - Summary', l_extracted);
*   END;
*******************************************************************************/
FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;
```

---

### 🔧 Technical Implementation

#### **Multi-Document Data Structure**

```sql
-- Global structure for managing multiple PDFs
TYPE t_pdf_document IS RECORD (
  pdf_id        VARCHAR2(50),
  pdf_blob      BLOB,
  pages         JSON_ARRAY_T,      -- Page information
  objects       JSON_OBJECT_T,     -- PDF objects
  xref          JSON_ARRAY_T,      -- Cross-reference table
  trailer       JSON_OBJECT_T,     -- PDF trailer
  page_count    PLS_INTEGER,
  file_size     NUMBER,
  loaded_ts     TIMESTAMP
);

TYPE t_pdf_collection IS TABLE OF t_pdf_document INDEX BY VARCHAR2(50);
g_loaded_pdfs t_pdf_collection;

-- Maximum loaded PDFs
c_max_loaded_pdfs CONSTANT PLS_INTEGER := 10;
```

#### **Object Renumbering Strategy**

When merging PDFs, object numbers from different documents will conflict:

```sql
-- Example: Merge 3 PDFs
-- PDF1: objects 1-50
-- PDF2: objects 1-30  --> renumbered to 51-80
-- PDF3: objects 1-40  --> renumbered to 81-120

FUNCTION calculate_object_offset(
  p_merged_pdfs IN JSON_ARRAY_T
) RETURN JSON_OBJECT_T IS
  l_offsets JSON_OBJECT_T := JSON_OBJECT_T();
  l_current_offset PLS_INTEGER := 0;
BEGIN
  FOR i IN 0..p_merged_pdfs.get_size() - 1 LOOP
    l_pdf_id := p_merged_pdfs.get_string(i);
    l_offsets.put(l_pdf_id, l_current_offset);
    l_current_offset := l_current_offset +
                        g_loaded_pdfs(l_pdf_id).objects.get_keys().COUNT;
  END LOOP;
  RETURN l_offsets;
END;

FUNCTION renumber_object_references(
  p_object IN CLOB,
  p_offset IN PLS_INTEGER
) RETURN CLOB IS
  l_result CLOB := p_object;
BEGIN
  -- Replace object references: "5 0 R" -> "55 0 R" (if offset=50)
  l_result := REGEXP_REPLACE(l_result,
    '(\d+)\s+0\s+R',
    '(' || TO_CHAR(p_offset) || '+\1) 0 R');
  RETURN l_result;
END;
```

#### **Page Tree Merging**

Merge page trees from multiple PDFs:

```sql
FUNCTION merge_page_trees(
  p_pdf_ids IN JSON_ARRAY_T,
  p_offsets IN JSON_OBJECT_T
) RETURN JSON_ARRAY_T IS
  l_merged_pages JSON_ARRAY_T := JSON_ARRAY_T();
  l_page JSON_OBJECT_T;
BEGIN
  FOR i IN 0..p_pdf_ids.get_size() - 1 LOOP
    l_pdf_id := p_pdf_ids.get_string(i);
    l_offset := p_offsets.get_number(l_pdf_id);

    -- Copy pages from this PDF
    l_pages := g_loaded_pdfs(l_pdf_id).pages;
    FOR j IN 0..l_pages.get_size() - 1 LOOP
      l_page := TREAT(l_pages.get(j) AS JSON_OBJECT_T);

      -- Renumber object references
      l_page := renumber_page_references(l_page, l_offset);

      -- Add to merged pages
      l_merged_pages.append(l_page);
    END LOOP;
  END LOOP;

  RETURN l_merged_pages;
END;
```

#### **Resource Consolidation**

Detect and merge duplicate resources:

```sql
FUNCTION consolidate_resources(
  p_pdf_ids IN JSON_ARRAY_T
) RETURN JSON_OBJECT_T IS
  l_resources JSON_OBJECT_T := JSON_OBJECT_T();
  l_font_map JSON_OBJECT_T := JSON_OBJECT_T();
  l_image_map JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  -- Collect all unique fonts
  FOR i IN 0..p_pdf_ids.get_size() - 1 LOOP
    l_pdf_id := p_pdf_ids.get_string(i);
    merge_fonts(g_loaded_pdfs(l_pdf_id).objects, l_font_map);
    merge_images(g_loaded_pdfs(l_pdf_id).objects, l_image_map);
  END LOOP;

  l_resources.put('fonts', l_font_map);
  l_resources.put('images', l_image_map);

  RETURN l_resources;
END;
```

#### **Split Implementation**

```sql
FUNCTION split_pdf_by_range(
  p_pdf_id IN VARCHAR2,
  p_start_page IN PLS_INTEGER,
  p_end_page IN PLS_INTEGER
) RETURN BLOB IS
  l_new_pdf BLOB;
  l_pages JSON_ARRAY_T := JSON_ARRAY_T();
  l_objects JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  -- Validate range
  IF p_start_page < 1 OR p_end_page > g_loaded_pdfs(p_pdf_id).page_count THEN
    raise_error(-20837, 'Page range exceeds document');
  END IF;

  -- Extract pages in range
  FOR i IN p_start_page..p_end_page LOOP
    l_page := get_page_object(p_pdf_id, i);
    l_pages.append(l_page);

    -- Copy page resources
    copy_page_resources(p_pdf_id, i, l_objects);
  END LOOP;

  -- Build new PDF structure
  l_new_pdf := build_pdf_from_pages(l_pages, l_objects);

  RETURN l_new_pdf;
END;
```

---

### 🧪 Testing Strategy

#### **Test Cases:**

```sql
-- tests/test_phase_4_6_merge_split.sql

-- Multi-Document Loading Tests:
-- Test 1: Load single PDF with ID
-- Test 2: Load multiple PDFs (3 PDFs)
-- Test 3: Load duplicate ID (should error)
-- Test 4: Load 11 PDFs (should error - max 10)
-- Test 5: GetLoadedPDFs() listing
-- Test 6: UnloadPDF()
-- Test 7: Unload non-existent PDF (should error)

-- Merge Tests:
-- Test 8: Merge 2 PDFs (5 pages each)
-- Test 9: Merge 3 PDFs (different sizes)
-- Test 10: Merge with empty PDF list (should error)
-- Test 11: Merge with non-loaded PDF ID (should error)
-- Test 12: Merge with metadata preservation
-- Test 13: Merge PDFs with same fonts (resource consolidation)
-- Test 14: Merge 5 PDFs (performance test)

-- Split Tests:
-- Test 15: Split 10-page PDF into 2 parts (1-5, 6-10)
-- Test 16: Split 10-page PDF into 3 parts (1-3, 4-7, 8-10)
-- Test 17: Split with invalid range (should error)
-- Test 18: Split with overlapping ranges (should error)
-- Test 19: Split with range exceeding pages (should error)
-- Test 20: Split single page from PDF

-- Extract Tests:
-- Test 21: Extract pages 1,3,5 from 10-page PDF
-- Test 22: Extract range 5-10
-- Test 23: Extract all pages 'ALL'
-- Test 24: Extract with invalid page spec (should error)
-- Test 25: Extract page out of range (should error)
-- Test 26: Extract single page
-- Test 27: Extract with metadata preservation

-- Integration Tests:
-- Test 28: Load > Merge > Split > Extract workflow
-- Test 29: Merge then apply modifications (rotate, watermark)
-- Test 30: Extract then overlay text
```

---

### 📊 Error Codes

New error codes for Phase 4.6:

| Code | Error | Description |
|------|-------|-------------|
| -20828 | PDF_ID_ALREADY_LOADED | PDF ID is already loaded |
| -20829 | MAX_PDFS_EXCEEDED | Maximum 10 PDFs exceeded |
| -20830 | INVALID_PDF_ID | Invalid PDF ID (empty or too long) |
| -20831 | PDF_ID_NOT_FOUND | PDF ID not found in loaded PDFs |
| -20832 | NO_PDF_IDS_PROVIDED | No PDF IDs provided for merge |
| -20833 | PDF_NOT_LOADED_IN_LIST | PDF ID in list not loaded |
| -20834 | MERGE_FAILED | Merge operation failed |
| -20835 | INVALID_PAGE_RANGE | Invalid page range specification |
| -20836 | OVERLAPPING_RANGES | Page ranges overlap |
| -20837 | RANGE_EXCEEDS_DOCUMENT | Page range exceeds document |
| -20838 | INVALID_PAGE_SPEC | Invalid page specification |
| -20839 | PAGE_OUT_OF_RANGE | Page number out of range |

---

### 💼 Use Cases

#### **Use Case 1: Monthly Report Consolidation**
```sql
-- Merge 12 monthly reports into annual report
DECLARE
  l_annual_report BLOB;
  l_pdf_ids JSON_ARRAY_T := JSON_ARRAY_T();
BEGIN
  -- Load all monthly reports
  FOR i IN 1..12 LOOP
    SELECT pdf_blob INTO l_pdf
    FROM monthly_reports
    WHERE month = i AND year = 2026;

    PL_FPDF.LoadPDFWithID('month_' || i, l_pdf);
    l_pdf_ids.append('month_' || i);
  END LOOP;

  -- Merge into annual report
  l_annual_report := PL_FPDF.MergePDFs(l_pdf_ids, NULL);

  -- Save annual report
  INSERT INTO annual_reports (year, pdf_blob)
  VALUES (2026, l_annual_report);
  COMMIT;
END;
```

#### **Use Case 2: Contract Distribution**
```sql
-- Split contract into sections for different parties
DECLARE
  l_sections JSON_ARRAY_T;
  l_intro BLOB;
  l_terms_party_a BLOB;
  l_terms_party_b BLOB;
  l_signatures BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('contract', l_contract);

  -- Split into 4 sections
  l_sections := PL_FPDF.SplitPDF('contract',
    JSON_ARRAY_T('["1-2", "3-10", "11-18", "19-20"]')
  );

  -- Extract each section
  l_intro := HEXTORAW(l_sections.get_string(0));
  l_terms_party_a := HEXTORAW(l_sections.get_string(1));
  l_terms_party_b := HEXTORAW(l_sections.get_string(2));
  l_signatures := HEXTORAW(l_sections.get_string(3));

  -- Distribute to parties
  -- Party A gets: intro + their terms + signatures
  PL_FPDF.LoadPDFWithID('intro', l_intro);
  PL_FPDF.LoadPDFWithID('terms_a', l_terms_party_a);
  PL_FPDF.LoadPDFWithID('sigs', l_signatures);

  l_party_a_pack := PL_FPDF.MergePDFs(
    JSON_ARRAY_T('["intro","terms_a","sigs"]'), NULL
  );

  send_to_party_a(l_party_a_pack);
END;
```

#### **Use Case 3: Selective Page Extraction**
```sql
-- Extract executive summary from full report
DECLARE
  l_summary BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID('full_report', l_full_report);

  -- Extract pages 1 (cover), 2-5 (summary), 50 (conclusions)
  l_summary := PL_FPDF.ExtractPages('full_report', '1-5,50', NULL);

  -- Save executive summary
  INSERT INTO reports (type, pdf_blob)
  VALUES ('EXECUTIVE_SUMMARY', l_summary);
END;
```

---

## Português

### 🎯 Visão Geral da Fase 4.6

A Fase 4.6 introduz operações essenciais de múltiplos documentos PDF:
- **Mesclar múltiplos PDFs** em um único documento
- **Dividir PDFs** em arquivos separados por intervalos de páginas
- **Extrair intervalos de páginas** para criar novos documentos PDF
- **Gerenciar múltiplos PDFs** em memória simultaneamente

### 📝 APIs da Fase 4.6

1. **LoadPDFWithID()** - Carregar PDF com identificador
2. **GetLoadedPDFs()** - Listar todos os PDFs carregados
3. **UnloadPDF()** - Remover PDF da memória
4. **MergePDFs()** - Combinar múltiplos PDFs
5. **SplitPDF()** - Dividir PDF em múltiplos arquivos
6. **ExtractPages()** - Criar PDF de intervalo de páginas

### 💼 Casos de Uso

1. **Consolidação de Relatórios Mensais** - Mesclar 12 relatórios mensais em anual
2. **Distribuição de Contratos** - Dividir contrato em seções para partes diferentes
3. **Extração Seletiva de Páginas** - Extrair sumário executivo de relatório completo

---

## 🚀 Implementation Plan

**Duration:** 4-5 days

**Tasks:**
1. ✅ Day 1: Define API specification and multi-document structures
2. ⏳ Day 2: Implement multi-document loading (LoadPDFWithID, GetLoadedPDFs, UnloadPDF)
3. ⏳ Day 3: Implement MergePDFs with object renumbering
4. ⏳ Day 4: Implement SplitPDF and ExtractPages
5. ⏳ Day 5: Testing, documentation, and performance optimization

---

**Prepared by:** Claude Code
**Date:** 2026-01-25
**Target Version:** 3.0.0-a.7
