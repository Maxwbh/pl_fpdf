# Phase 4 Guide - PDF Reading and Manipulation / Guia Fase 4 - Leitura e Manipulação de PDF

**Version / Versão:** 3.0.0-alpha.5
**Status:** Complete / Completo ✅

[🇬🇧 English](#english) | [🇧🇷 Português](#português)

---

## English

### Overview

Phase 4 adds complete PDF reading and manipulation capabilities to PL_FPDF, enabling you to:
- Load and parse existing PDF files
- Extract page information and metadata
- Rotate, remove, and reorder pages
- Add watermarks to pages
- Generate modified PDFs with all changes applied

All operations are performed in 100% PL/SQL with no external dependencies.

### Architecture

Phase 4 is implemented in 5 sub-phases:

| Phase | Version | Features |
|-------|---------|----------|
| 4.1A | 3.0.0-alpha | PDF Parser - Basic Reading |
| 4.1B | 3.0.0-a.2 | Page Information & Manipulation |
| 4.2 | 3.0.0-a.3 | Page Management & Modification Tracking |
| 4.3 | 3.0.0-a.4 | Watermark Management |
| 4.4 | 3.0.0-a.5 | Output Modified PDF |

### API Reference

#### 4.1A - Load and Parse PDFs

**LoadPDF(p_pdf_blob BLOB)**
```sql
-- Load an existing PDF into memory
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documents WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
END;
/
```

**GetPageCount() → PLS_INTEGER**
```sql
-- Get total number of pages
l_page_count := PL_FPDF.GetPageCount();
-- Returns: 10
```

**GetPDFInfo() → JSON_OBJECT_T**
```sql
-- Get PDF metadata
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetPDFInfo();
  DBMS_OUTPUT.PUT_LINE('Version: ' || l_info.get_string('version'));
  DBMS_OUTPUT.PUT_LINE('Pages: ' || l_info.get_number('pageCount'));
  DBMS_OUTPUT.PUT_LINE('Size: ' || l_info.get_number('fileSize') || ' bytes');
END;
/
```

#### 4.1B - Page Information

**GetPageInfo(p_page_number PLS_INTEGER) → JSON_OBJECT_T**
```sql
-- Get detailed information about a specific page
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetPageInfo(1);
  DBMS_OUTPUT.PUT_LINE('MediaBox: ' || l_info.get_string('mediaBox'));
  DBMS_OUTPUT.PUT_LINE('Rotation: ' || l_info.get_number('rotation'));
END;
/
```

**RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER)**
```sql
-- Rotate a page (0, 90, 180, 270 degrees)
PL_FPDF.RotatePage(1, 90);   -- Rotate page 1 clockwise 90°
PL_FPDF.RotatePage(2, 180);  -- Rotate page 2 180°
```

#### 4.2 - Page Management

**RemovePage(p_page_number PLS_INTEGER)**
```sql
-- Mark a page for removal
PL_FPDF.RemovePage(3);   -- Remove page 3
PL_FPDF.RemovePage(7);   -- Remove page 7
```

**GetActivePageCount() → PLS_INTEGER**
```sql
-- Get count of non-removed pages
l_total := PL_FPDF.GetPageCount();        -- Returns 10 (original)
l_active := PL_FPDF.GetActivePageCount(); -- Returns 8 (after removing 2)
```

**IsPageRemoved(p_page_number PLS_INTEGER) → BOOLEAN**
```sql
-- Check if a page is marked for removal
IF PL_FPDF.IsPageRemoved(3) THEN
  DBMS_OUTPUT.PUT_LINE('Page 3 has been removed');
END IF;
```

**IsPDFModified() → BOOLEAN**
```sql
-- Check if PDF has been modified
IF PL_FPDF.IsPDFModified() THEN
  DBMS_OUTPUT.PUT_LINE('PDF has modifications');
END IF;
```

#### 4.3 - Watermarks

**AddWatermark(...)**
```sql
PROCEDURE AddWatermark(
  p_text VARCHAR2,                    -- Watermark text
  p_opacity NUMBER DEFAULT 0.3,       -- Opacity (0.0 - 1.0)
  p_rotation NUMBER DEFAULT 45,       -- Rotation (0, 45, 90, 135, 180, 225, 270, 315)
  p_pages VARCHAR2 DEFAULT 'ALL',     -- Page range
  p_font VARCHAR2 DEFAULT 'Helvetica', -- Font name
  p_size NUMBER DEFAULT 48,           -- Font size
  p_color VARCHAR2 DEFAULT 'gray'     -- Color
);
```

Examples:
```sql
-- Watermark all pages
PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');

-- Watermark specific pages
PL_FPDF.AddWatermark('DRAFT', 0.2, 90, '1-5');

-- Watermark with custom styling
PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '10', 'Helvetica', 72, 'green');
```

Page range formats:
- `'ALL'` - All pages
- `'1-5'` - Pages 1 through 5
- `'1,3,5'` - Specific pages
- `'1-3,5,7-10'` - Complex ranges

**GetWatermarks() → JSON_ARRAY_T**
```sql
-- Get list of applied watermarks
DECLARE
  l_watermarks JSON_ARRAY_T;
  l_watermark JSON_OBJECT_T;
BEGIN
  l_watermarks := PL_FPDF.GetWatermarks();

  FOR i IN 0..l_watermarks.get_size() - 1 LOOP
    l_watermark := TREAT(l_watermarks.get(i) AS JSON_OBJECT_T);
    DBMS_OUTPUT.PUT_LINE('Watermark: ' || l_watermark.get_string('text') ||
      ' on pages ' || l_watermark.get_string('pageRange'));
  END LOOP;
END;
/
```

#### 4.4 - Output Modified PDF

**OutputModifiedPDF() → BLOB**
```sql
-- Generate modified PDF with all changes applied
DECLARE
  l_modified_pdf BLOB;
BEGIN
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();

  -- Save to database
  UPDATE documents SET pdf_blob = l_modified_pdf WHERE id = 1;
  COMMIT;
END;
/
```

**ClearPDFCache()**
```sql
-- Clear loaded PDF and free memory
PL_FPDF.ClearPDFCache();
```

### Complete Workflow Example

```sql
DECLARE
  l_original_pdf BLOB;
  l_modified_pdf BLOB;
  l_info JSON_OBJECT_T;
  l_watermarks JSON_ARRAY_T;
BEGIN
  -- 1. Load PDF
  SELECT pdf_blob INTO l_original_pdf FROM documents WHERE id = 123;
  PL_FPDF.LoadPDF(l_original_pdf);

  -- 2. Get information
  l_info := PL_FPDF.GetPDFInfo();
  DBMS_OUTPUT.PUT_LINE('Original PDF: ' ||
    l_info.get_number('pageCount') || ' pages, ' ||
    l_info.get_number('fileSize') || ' bytes');

  -- 3. Apply modifications
  -- Rotate first page
  PL_FPDF.RotatePage(1, 90);

  -- Remove unwanted pages
  PL_FPDF.RemovePage(3);
  PL_FPDF.RemovePage(7);
  PL_FPDF.RemovePage(10);

  -- Add watermarks
  PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');
  PL_FPDF.AddWatermark('DRAFT', 0.2, 90, '1-5');

  -- 4. Verify modifications
  DBMS_OUTPUT.PUT_LINE('Active pages: ' || PL_FPDF.GetActivePageCount());
  DBMS_OUTPUT.PUT_LINE('Modified: ' ||
    CASE WHEN PL_FPDF.IsPDFModified() THEN 'YES' ELSE 'NO' END);

  l_watermarks := PL_FPDF.GetWatermarks();
  DBMS_OUTPUT.PUT_LINE('Watermarks: ' || l_watermarks.get_size());

  -- 5. Generate modified PDF
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();

  DBMS_OUTPUT.PUT_LINE('Modified PDF size: ' ||
    DBMS_LOB.GETLENGTH(l_modified_pdf) || ' bytes');

  -- 6. Save modified PDF
  UPDATE documents
  SET pdf_blob = l_modified_pdf,
      modified_date = SYSDATE
  WHERE id = 123;

  COMMIT;

  -- 7. Clean up
  PL_FPDF.ClearPDFCache();

  DBMS_OUTPUT.PUT_LINE('Complete!');
END;
/
```

### Error Codes

| Code | Description |
|------|-------------|
| -20800 | Invalid PDF (NULL or too small) |
| -20801 | Invalid PDF header |
| -20802 | xref table not found |
| -20803 | Trailer not found |
| -20804 | Root object not found |
| -20805 | Pages object not found |
| -20809 | No PDF loaded (call LoadPDF first) |
| -20810 | Pages not found in Catalog |
| -20811 | Kids array not found in Pages object |
| -20812 | Invalid page number |
| -20813 | Invalid rotation value |
| -20814 | Page already marked for removal |
| -20815 | Invalid page range |
| -20816 | Watermark text cannot be empty |
| -20817 | Invalid opacity (must be 0.0-1.0) |
| -20818 | Invalid rotation (must be 0, 45, 90, etc.) |
| -20819 | PDF not modified (no changes to output) |
| -20820 | All pages removed (cannot generate empty PDF) |

### Performance Tips

1. **Clear cache after processing**
   ```sql
   PL_FPDF.ClearPDFCache();  -- Frees memory
   ```

2. **Process multiple PDFs efficiently**
   ```sql
   FOR doc IN (SELECT id, pdf_blob FROM documents) LOOP
     PL_FPDF.LoadPDF(doc.pdf_blob);
     -- ... modifications ...
     l_modified := PL_FPDF.OutputModifiedPDF();
     -- ... save ...
     PL_FPDF.ClearPDFCache();  -- Important: clear between PDFs
   END LOOP;
   ```

3. **Use page ranges efficiently**
   ```sql
   -- Good: Single watermark call
   PL_FPDF.AddWatermark('TEXT', 0.3, 45, '1-10,15,20-25');

   -- Avoid: Multiple watermark calls for same text
   FOR i IN 1..10 LOOP
     PL_FPDF.AddWatermark('TEXT', 0.3, 45, TO_CHAR(i));
   END LOOP;
   ```

### Limitations

- **PDF Version Support:** PDF 1.4+ with non-compressed xref tables
- **Compressed Objects:** Compressed/encrypted PDFs not supported yet
- **Watermark Rendering:** Basic text watermarks (visual rendering in Phase 4.5)
- **Content Stream Modification:** Direct content editing in future phases
- **Font Embedding:** Uses existing PDF fonts for watermarks

### Testing

Run Phase 4 tests:
```bash
cd tests
sqlplus user/pass@db @test_phase_4_parser_basic.sql
sqlplus user/pass@db @test_phase_4_1b_pages.sql
sqlplus user/pass@db @test_phase_4_2_page_mgmt.sql
sqlplus user/pass@db @test_phase_4_3_watermark.sql
sqlplus user/pass@db @test_phase_4_4_output.sql
```

---

## Português

### Visão Geral

A Fase 4 adiciona capacidades completas de leitura e manipulação de PDF ao PL_FPDF, permitindo:
- Carregar e parsear arquivos PDF existentes
- Extrair informações de páginas e metadados
- Rotacionar, remover e reordenar páginas
- Adicionar marcas d'água às páginas
- Gerar PDFs modificados com todas as alterações aplicadas

Todas as operações são realizadas em 100% PL/SQL sem dependências externas.

### Arquitetura

A Fase 4 é implementada em 5 subfases:

| Fase | Versão | Recursos |
|------|--------|----------|
| 4.1A | 3.0.0-alpha | Parser PDF - Leitura Básica |
| 4.1B | 3.0.0-a.2 | Informação e Manipulação de Páginas |
| 4.2 | 3.0.0-a.3 | Gerenciamento e Rastreamento de Modificações |
| 4.3 | 3.0.0-a.4 | Gerenciamento de Marcas d'Água |
| 4.4 | 3.0.0-a.5 | Geração de PDF Modificado |

### Referência da API

#### 4.1A - Carregar e Parsear PDFs

**LoadPDF(p_pdf_blob BLOB)**
```sql
-- Carregar PDF existente na memória
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documentos WHERE id = 1;
  PL_FPDF.LoadPDF(l_pdf);
END;
/
```

**GetPageCount() → PLS_INTEGER**
```sql
-- Obter número total de páginas
l_total_paginas := PL_FPDF.GetPageCount();
-- Retorna: 10
```

**GetPDFInfo() → JSON_OBJECT_T**
```sql
-- Obter metadados do PDF
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetPDFInfo();
  DBMS_OUTPUT.PUT_LINE('Versão: ' || l_info.get_string('version'));
  DBMS_OUTPUT.PUT_LINE('Páginas: ' || l_info.get_number('pageCount'));
  DBMS_OUTPUT.PUT_LINE('Tamanho: ' || l_info.get_number('fileSize') || ' bytes');
END;
/
```

#### 4.1B - Informação de Páginas

**GetPageInfo(p_page_number PLS_INTEGER) → JSON_OBJECT_T**
```sql
-- Obter informações detalhadas de uma página específica
DECLARE
  l_info JSON_OBJECT_T;
BEGIN
  l_info := PL_FPDF.GetPageInfo(1);
  DBMS_OUTPUT.PUT_LINE('MediaBox: ' || l_info.get_string('mediaBox'));
  DBMS_OUTPUT.PUT_LINE('Rotação: ' || l_info.get_number('rotation'));
END;
/
```

**RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER)**
```sql
-- Rotacionar uma página (0, 90, 180, 270 graus)
PL_FPDF.RotatePage(1, 90);   -- Rotacionar página 1 em 90°
PL_FPDF.RotatePage(2, 180);  -- Rotacionar página 2 em 180°
```

#### 4.2 - Gerenciamento de Páginas

**RemovePage(p_page_number PLS_INTEGER)**
```sql
-- Marcar página para remoção
PL_FPDF.RemovePage(3);   -- Remover página 3
PL_FPDF.RemovePage(7);   -- Remover página 7
```

**GetActivePageCount() → PLS_INTEGER**
```sql
-- Obter contagem de páginas não removidas
l_total := PL_FPDF.GetPageCount();        -- Retorna 10 (original)
l_ativas := PL_FPDF.GetActivePageCount(); -- Retorna 8 (após remover 2)
```

**IsPageRemoved(p_page_number PLS_INTEGER) → BOOLEAN**
```sql
-- Verificar se página está marcada para remoção
IF PL_FPDF.IsPageRemoved(3) THEN
  DBMS_OUTPUT.PUT_LINE('Página 3 foi removida');
END IF;
```

**IsPDFModified() → BOOLEAN**
```sql
-- Verificar se PDF foi modificado
IF PL_FPDF.IsPDFModified() THEN
  DBMS_OUTPUT.PUT_LINE('PDF possui modificações');
END IF;
```

#### 4.3 - Marcas d'Água

**AddWatermark(...)**
```sql
PROCEDURE AddWatermark(
  p_text VARCHAR2,                    -- Texto da marca d'água
  p_opacity NUMBER DEFAULT 0.3,       -- Opacidade (0.0 - 1.0)
  p_rotation NUMBER DEFAULT 45,       -- Rotação (0, 45, 90, 135, 180, 225, 270, 315)
  p_pages VARCHAR2 DEFAULT 'ALL',     -- Range de páginas
  p_font VARCHAR2 DEFAULT 'Helvetica', -- Nome da fonte
  p_size NUMBER DEFAULT 48,           -- Tamanho da fonte
  p_color VARCHAR2 DEFAULT 'gray'     -- Cor
);
```

Exemplos:
```sql
-- Marca d'água em todas as páginas
PL_FPDF.AddWatermark('CONFIDENCIAL', 0.3, 45, 'ALL');

-- Marca d'água em páginas específicas
PL_FPDF.AddWatermark('RASCUNHO', 0.2, 90, '1-5');

-- Marca d'água com estilo personalizado
PL_FPDF.AddWatermark('APROVADO', 0.5, 0, '10', 'Helvetica', 72, 'green');
```

Formatos de range de páginas:
- `'ALL'` - Todas as páginas
- `'1-5'` - Páginas 1 até 5
- `'1,3,5'` - Páginas específicas
- `'1-3,5,7-10'` - Ranges complexos

**GetWatermarks() → JSON_ARRAY_T**
```sql
-- Obter lista de marcas d'água aplicadas
DECLARE
  l_marcas JSON_ARRAY_T;
  l_marca JSON_OBJECT_T;
BEGIN
  l_marcas := PL_FPDF.GetWatermarks();

  FOR i IN 0..l_marcas.get_size() - 1 LOOP
    l_marca := TREAT(l_marcas.get(i) AS JSON_OBJECT_T);
    DBMS_OUTPUT.PUT_LINE('Marca: ' || l_marca.get_string('text') ||
      ' nas páginas ' || l_marca.get_string('pageRange'));
  END LOOP;
END;
/
```

#### 4.4 - Gerar PDF Modificado

**OutputModifiedPDF() → BLOB**
```sql
-- Gerar PDF modificado com todas as alterações aplicadas
DECLARE
  l_pdf_modificado BLOB;
BEGIN
  l_pdf_modificado := PL_FPDF.OutputModifiedPDF();

  -- Salvar no banco
  UPDATE documentos SET pdf_blob = l_pdf_modificado WHERE id = 1;
  COMMIT;
END;
/
```

**ClearPDFCache()**
```sql
-- Limpar PDF carregado e liberar memória
PL_FPDF.ClearPDFCache();
```

### Exemplo Completo de Workflow

```sql
DECLARE
  l_pdf_original BLOB;
  l_pdf_modificado BLOB;
  l_info JSON_OBJECT_T;
  l_marcas JSON_ARRAY_T;
BEGIN
  -- 1. Carregar PDF
  SELECT pdf_blob INTO l_pdf_original FROM documentos WHERE id = 123;
  PL_FPDF.LoadPDF(l_pdf_original);

  -- 2. Obter informações
  l_info := PL_FPDF.GetPDFInfo();
  DBMS_OUTPUT.PUT_LINE('PDF original: ' ||
    l_info.get_number('pageCount') || ' páginas, ' ||
    l_info.get_number('fileSize') || ' bytes');

  -- 3. Aplicar modificações
  -- Rotacionar primeira página
  PL_FPDF.RotatePage(1, 90);

  -- Remover páginas indesejadas
  PL_FPDF.RemovePage(3);
  PL_FPDF.RemovePage(7);
  PL_FPDF.RemovePage(10);

  -- Adicionar marcas d'água
  PL_FPDF.AddWatermark('CONFIDENCIAL', 0.3, 45, 'ALL');
  PL_FPDF.AddWatermark('RASCUNHO', 0.2, 90, '1-5');

  -- 4. Verificar modificações
  DBMS_OUTPUT.PUT_LINE('Páginas ativas: ' || PL_FPDF.GetActivePageCount());
  DBMS_OUTPUT.PUT_LINE('Modificado: ' ||
    CASE WHEN PL_FPDF.IsPDFModified() THEN 'SIM' ELSE 'NÃO' END);

  l_marcas := PL_FPDF.GetWatermarks();
  DBMS_OUTPUT.PUT_LINE('Marcas d''água: ' || l_marcas.get_size());

  -- 5. Gerar PDF modificado
  l_pdf_modificado := PL_FPDF.OutputModifiedPDF();

  DBMS_OUTPUT.PUT_LINE('Tamanho PDF modificado: ' ||
    DBMS_LOB.GETLENGTH(l_pdf_modificado) || ' bytes');

  -- 6. Salvar PDF modificado
  UPDATE documentos
  SET pdf_blob = l_pdf_modificado,
      data_modificacao = SYSDATE
  WHERE id = 123;

  COMMIT;

  -- 7. Limpar
  PL_FPDF.ClearPDFCache();

  DBMS_OUTPUT.PUT_LINE('Concluído!');
END;
/
```

### Códigos de Erro

| Código | Descrição |
|--------|-----------|
| -20800 | PDF inválido (NULL ou muito pequeno) |
| -20801 | Header PDF inválido |
| -20802 | Tabela xref não encontrada |
| -20803 | Trailer não encontrado |
| -20804 | Objeto Root não encontrado |
| -20805 | Objeto Pages não encontrado |
| -20809 | Nenhum PDF carregado (chame LoadPDF primeiro) |
| -20810 | Pages não encontrado no Catalog |
| -20811 | Array Kids não encontrado no objeto Pages |
| -20812 | Número de página inválido |
| -20813 | Valor de rotação inválido |
| -20814 | Página já marcada para remoção |
| -20815 | Range de páginas inválido |
| -20816 | Texto da marca d'água não pode ser vazio |
| -20817 | Opacidade inválida (deve ser 0.0-1.0) |
| -20818 | Rotação inválida (deve ser 0, 45, 90, etc.) |
| -20819 | PDF não modificado (sem alterações para gerar) |
| -20820 | Todas as páginas removidas (não pode gerar PDF vazio) |

### Dicas de Performance

1. **Limpar cache após processamento**
   ```sql
   PL_FPDF.ClearPDFCache();  -- Libera memória
   ```

2. **Processar múltiplos PDFs eficientemente**
   ```sql
   FOR doc IN (SELECT id, pdf_blob FROM documentos) LOOP
     PL_FPDF.LoadPDF(doc.pdf_blob);
     -- ... modificações ...
     l_modificado := PL_FPDF.OutputModifiedPDF();
     -- ... salvar ...
     PL_FPDF.ClearPDFCache();  -- Importante: limpar entre PDFs
   END LOOP;
   ```

3. **Usar ranges de páginas eficientemente**
   ```sql
   -- Bom: Única chamada de marca d'água
   PL_FPDF.AddWatermark('TEXTO', 0.3, 45, '1-10,15,20-25');

   -- Evitar: Múltiplas chamadas para mesmo texto
   FOR i IN 1..10 LOOP
     PL_FPDF.AddWatermark('TEXTO', 0.3, 45, TO_CHAR(i));
   END LOOP;
   ```

### Limitações

- **Suporte à Versão PDF:** PDF 1.4+ com tabelas xref não comprimidas
- **Objetos Comprimidos:** PDFs comprimidos/criptografados ainda não suportados
- **Renderização de Marca d'Água:** Marcas d'água de texto básicas (renderização visual na Fase 4.5)
- **Modificação de Content Stream:** Edição direta de conteúdo em fases futuras
- **Incorporação de Fontes:** Usa fontes existentes do PDF para marcas d'água

### Testes

Executar testes da Fase 4:
```bash
cd tests
sqlplus user/pass@db @test_phase_4_parser_basic.sql
sqlplus user/pass@db @test_phase_4_1b_pages.sql
sqlplus user/pass@db @test_phase_4_2_page_mgmt.sql
sqlplus user/pass@db @test_phase_4_3_watermark.sql
sqlplus user/pass@db @test_phase_4_4_output.sql
```

---

**Last Updated:** January 2026
**Maintained by:** Maxwell Oliveira (@maxwbh)
