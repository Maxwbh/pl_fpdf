# Task 4.1: PDF Parser - Leitura e Modificação de PDFs Existentes

**Prioridade:** P3 (Desejável)
**Esforço:** Muito Alto (6-8 semanas)
**Status:** 📋 Planejada
**Versão Alvo:** PL_FPDF v3.0.0

---

## 📋 Visão Geral

Implementar um parser completo de PDF em PL/SQL puro que permita:
- ✅ Ler PDFs existentes (BLOB)
- ✅ Extrair estrutura (páginas, fontes, imagens, texto)
- ✅ Modificar PDFs incrementalmente
- ✅ Mesclar/dividir PDFs
- ✅ Adicionar overlays (texto, imagem, marca d'água)
- ✅ Extrair conteúdo (texto, imagens)

---

## 🎯 Objetivos

### Funcionalidades Principais

1. **Leitura de PDFs**
   - Parser de header PDF (versão 1.0 a 2.0)
   - Parser de cross-reference table (xref)
   - Parser de trailer
   - Parser de objetos indiretos
   - Suporte a PDF linearizado

2. **Extração de Conteúdo**
   - Extrair texto de páginas (content streams)
   - Extrair imagens (XObjects)
   - Extrair metadados (Info dictionary)
   - Listar fontes utilizadas

3. **Modificação de PDFs**
   - Adicionar texto sobre páginas existentes (overlay)
   - Adicionar imagens sobre páginas existentes
   - Adicionar marca d'água
   - Rotacionar páginas
   - Remover páginas

4. **Operações em Lote**
   - Mesclar múltiplos PDFs
   - Dividir PDF em múltiplos arquivos
   - Inserir páginas de outros PDFs

---

## 🔧 Arquitetura Técnica

### Estrutura de um PDF

```
%PDF-1.7                                    ← Header
1 0 obj                                     ← Object 1 (Catalog)
<<
  /Type /Catalog
  /Pages 2 0 R
>>
endobj

2 0 obj                                     ← Object 2 (Pages)
<<
  /Type /Pages
  /Kids [3 0 R]
  /Count 1
>>
endobj

3 0 obj                                     ← Object 3 (Page)
<<
  /Type /Page
  /Parent 2 0 R
  /MediaBox [0 0 612 792]
  /Contents 4 0 R
  /Resources <<
    /Font <<
      /F1 5 0 R
    >>
  >>
>>
endobj

4 0 obj                                     ← Object 4 (Content Stream)
<<
  /Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Hello World) Tj
ET
endstream
endobj

xref                                        ← Cross-reference table
0 5
0000000000 65535 f
0000000015 00000 n
0000000074 00000 n
0000000133 00000 n
0000000302 00000 n

trailer                                     ← Trailer
<<
  /Size 5
  /Root 1 0 R
>>
startxref
395
%%EOF
```

### Componentes do Parser

```
┌─────────────────────────────────────────────────────────┐
│                   PDF PARSER ARCHITECTURE                │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐                                       │
│  │  LoadPDF()   │  ← Entry point                        │
│  └──────┬───────┘                                       │
│         │                                                │
│         ├─────→ parse_header()        → PDF version     │
│         │                                                │
│         ├─────→ find_startxref()      → xref offset     │
│         │                                                │
│         ├─────→ parse_xref_table()    → object map      │
│         │                                                │
│         ├─────→ parse_trailer()       → Root, Info      │
│         │                                                │
│         ├─────→ parse_catalog()       → Pages tree      │
│         │                                                │
│         └─────→ parse_page_tree()     → All pages       │
│                         │                                │
│                         └──→ parse_page_content()        │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │  OBJECT CACHE (PL/SQL Collections)       │           │
│  ├──────────────────────────────────────────┤           │
│  │  g_pdf_objects: object_id → object_data  │           │
│  │  g_pdf_pages:   page_num → page_struct   │           │
│  │  g_pdf_fonts:   font_id → font_info      │           │
│  └──────────────────────────────────────────┘           │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 📐 Especificação da API

### Tipos Customizados

```sql
CREATE OR REPLACE TYPE pdf_object_rec AS OBJECT (
  obj_number PLS_INTEGER,
  generation PLS_INTEGER,
  obj_type VARCHAR2(50),      -- 'dictionary', 'stream', 'array', 'string', etc.
  obj_data CLOB,
  stream_data BLOB,
  is_compressed BOOLEAN
);

CREATE OR REPLACE TYPE pdf_page_rec AS OBJECT (
  page_number PLS_INTEGER,
  width NUMBER,
  height NUMBER,
  rotation NUMBER,
  media_box VARCHAR2(100),
  crop_box VARCHAR2(100),
  content_stream_obj PLS_INTEGER,
  resources_obj PLS_INTEGER
);

CREATE OR REPLACE TYPE pdf_blob_array AS TABLE OF BLOB;
CREATE OR REPLACE TYPE image_blob_array AS TABLE OF recImageBlob;
```

### API Pública

```sql
--------------------------------------------------------------------------------
-- LEITURA DE PDFs
--------------------------------------------------------------------------------

-- Carregar PDF de BLOB
PROCEDURE LoadPDF(p_pdf_blob BLOB);

-- Carregar PDF de arquivo (UTL_FILE)
PROCEDURE LoadPDFFromFile(
  p_directory VARCHAR2,
  p_filename VARCHAR2
);

-- Obter informações do PDF
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;
/*
  Retorna:
  {
    "version": "1.7",
    "pageCount": 10,
    "author": "John Doe",
    "title": "Sample Document",
    "creationDate": "2025-01-01T10:00:00",
    "producer": "PL_FPDF 2.0"
  }
*/

-- Obter número de páginas
FUNCTION GetPageCount RETURN PLS_INTEGER;

-- Obter informações de uma página específica
FUNCTION GetPageInfo(p_page_number PLS_INTEGER) RETURN JSON_OBJECT_T;

--------------------------------------------------------------------------------
-- EXTRAÇÃO DE CONTEÚDO
--------------------------------------------------------------------------------

-- Extrair texto de página
FUNCTION ExtractText(
  p_page_number PLS_INTEGER
) RETURN CLOB;

-- Extrair texto de todas as páginas
FUNCTION ExtractAllText RETURN CLOB;

-- Extrair imagens de página
FUNCTION ExtractImages(
  p_page_number PLS_INTEGER
) RETURN image_blob_array;

-- Obter lista de fontes utilizadas
FUNCTION GetFontsUsed RETURN JSON_ARRAY_T;

--------------------------------------------------------------------------------
-- MANIPULAÇÃO DE PÁGINAS
--------------------------------------------------------------------------------

-- Extrair página como PDF separado
FUNCTION ExtractPage(p_page_number PLS_INTEGER) RETURN BLOB;

-- Extrair range de páginas
FUNCTION ExtractPages(
  p_start_page PLS_INTEGER,
  p_end_page PLS_INTEGER
) RETURN BLOB;

-- Remover página
PROCEDURE RemovePage(p_page_number PLS_INTEGER);

-- Remover múltiplas páginas
PROCEDURE RemovePages(p_page_numbers page_number_array);

-- Rotacionar página (90, 180, 270 graus)
PROCEDURE RotatePage(
  p_page_number PLS_INTEGER,
  p_rotation PLS_INTEGER  -- 90, 180, 270
);

-- Reordenar páginas
PROCEDURE ReorderPages(p_new_order page_number_array);
-- Exemplo: ReorderPages([3,1,2]) → página 3 vira 1, página 1 vira 2, etc.

--------------------------------------------------------------------------------
-- INSERÇÃO DE PÁGINAS
--------------------------------------------------------------------------------

-- Inserir página em branco
PROCEDURE InsertBlankPage(
  p_position PLS_INTEGER,
  p_format VARCHAR2 DEFAULT 'A4',
  p_orientation VARCHAR2 DEFAULT 'P'
);

-- Inserir página de outro PDF
PROCEDURE InsertPageFromPDF(
  p_position PLS_INTEGER,
  p_source_pdf BLOB,
  p_source_page PLS_INTEGER
);

-- Duplicar página existente
PROCEDURE DuplicatePage(
  p_source_page PLS_INTEGER,
  p_destination_position PLS_INTEGER
);

--------------------------------------------------------------------------------
-- OVERLAY (Sobreposição de Conteúdo)
--------------------------------------------------------------------------------

-- Adicionar texto sobre página existente
PROCEDURE OverlayText(
  p_page_number PLS_INTEGER,
  p_x NUMBER,
  p_y NUMBER,
  p_text VARCHAR2,
  p_font VARCHAR2 DEFAULT 'Arial',
  p_size NUMBER DEFAULT 12,
  p_color VARCHAR2 DEFAULT '0,0,0',  -- RGB
  p_opacity NUMBER DEFAULT 1.0
);

-- Adicionar imagem sobre página existente
PROCEDURE OverlayImage(
  p_page_number PLS_INTEGER,
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_image BLOB,
  p_opacity NUMBER DEFAULT 1.0
);

-- Adicionar QR Code sobre página existente
PROCEDURE OverlayQRCode(
  p_page_number PLS_INTEGER,
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_data VARCHAR2,
  p_format VARCHAR2 DEFAULT 'TEXT'
);

-- Adicionar marca d'água
PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_font VARCHAR2 DEFAULT 'Arial',
  p_size NUMBER DEFAULT 72,
  p_pages VARCHAR2 DEFAULT 'ALL'  -- 'ALL', '1-5', '1,3,5'
);

--------------------------------------------------------------------------------
-- MERGE E SPLIT
--------------------------------------------------------------------------------

-- Mesclar múltiplos PDFs
PROCEDURE MergePDFs(p_pdf_list pdf_blob_array);

-- Mesclar com controle de páginas
PROCEDURE MergePDFsWithPages(
  p_pdf_configs JSON_ARRAY_T
);
/*
  Exemplo:
  [
    {"pdf": blob1, "pages": "1-3,5"},
    {"pdf": blob2, "pages": "ALL"},
    {"pdf": blob3, "pages": "1,4,7"}
  ]
*/

-- Dividir PDF em múltiplos arquivos
FUNCTION SplitPDF(
  p_pages_per_file PLS_INTEGER
) RETURN pdf_blob_array;

-- Dividir em páginas individuais
FUNCTION SplitIntoSinglePages RETURN pdf_blob_array;

--------------------------------------------------------------------------------
-- OUTPUT
--------------------------------------------------------------------------------

-- Gerar PDF modificado
FUNCTION OutputModifiedPDF RETURN BLOB;

-- Salvar PDF modificado em arquivo
PROCEDURE SaveModifiedPDF(
  p_directory VARCHAR2,
  p_filename VARCHAR2
);

-- Limpar estado (liberar memória)
PROCEDURE ClearPDFCache;
```

---

## 💡 Casos de Uso

### 1. Adicionar Número de Página

```sql
DECLARE
  l_pdf BLOB;
  l_total_pages PLS_INTEGER;
BEGIN
  -- Carregar PDF
  SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
  
  PL_FPDF.LoadPDF(l_pdf);
  l_total_pages := PL_FPDF.GetPageCount();
  
  -- Adicionar número em cada página
  FOR i IN 1..l_total_pages LOOP
    PL_FPDF.OverlayText(
      p_page_number => i,
      p_x => 297 / 2,  -- Centro da página A4
      p_y => 10,       -- 10mm do rodapé
      p_text => 'Página ' || i || ' de ' || l_total_pages,
      p_font => 'Arial',
      p_size => 10
    );
  END LOOP;
  
  -- Salvar modificado
  UPDATE documents
  SET pdf_content = PL_FPDF.OutputModifiedPDF()
  WHERE id = 123;
END;
```

### 2. Extrair Capítulos de PDF

```sql
DECLARE
  l_pdf_completo BLOB;
  l_capitulo_1 BLOB;
  l_capitulo_2 BLOB;
  l_capitulo_3 BLOB;
BEGIN
  -- Carregar livro completo (300 páginas)
  SELECT pdf_content INTO l_pdf_completo FROM livros WHERE id = 456;
  
  PL_FPDF.LoadPDF(l_pdf_completo);
  
  -- Extrair capítulo 1 (páginas 1-100)
  l_capitulo_1 := PL_FPDF.ExtractPages(1, 100);
  
  -- Extrair capítulo 2 (páginas 101-200)
  l_capitulo_2 := PL_FPDF.ExtractPages(101, 200);
  
  -- Extrair capítulo 3 (páginas 201-300)
  l_capitulo_3 := PL_FPDF.ExtractPages(201, 300);
  
  -- Salvar capítulos separados
  INSERT INTO livros_capitulos (livro_id, capitulo, pdf_content)
  VALUES (456, 1, l_capitulo_1);
  
  INSERT INTO livros_capitulos (livro_id, capitulo, pdf_content)
  VALUES (456, 2, l_capitulo_2);
  
  INSERT INTO livros_capitulos (livro_id, capitulo, pdf_content)
  VALUES (456, 3, l_capitulo_3);
END;
```

### 3. Indexação Full-Text de PDFs

```sql
DECLARE
  CURSOR c_pdfs IS
    SELECT id, pdf_content
    FROM documentos
    WHERE texto_indexado IS NULL;
  
  l_texto CLOB;
BEGIN
  FOR r IN c_pdfs LOOP
    -- Carregar PDF
    PL_FPDF.LoadPDF(r.pdf_content);
    
    -- Extrair todo o texto
    l_texto := PL_FPDF.ExtractAllText();
    
    -- Salvar para indexação Oracle Text
    UPDATE documentos
    SET texto_indexado = l_texto
    WHERE id = r.id;
    
    -- Liberar memória
    PL_FPDF.ClearPDFCache();
    
    COMMIT;
  END LOOP;
END;
```

### 4. Carimbo de "PAGO" em Boletos

```sql
DECLARE
  l_boleto_pdf BLOB;
  l_carimbo_img BLOB;
BEGIN
  -- Carregar boleto e imagem do carimbo "PAGO"
  SELECT pdf_content INTO l_boleto_pdf FROM boletos WHERE id = 789;
  SELECT img_content INTO l_carimbo_img FROM imagens WHERE nome = 'CARIMBO_PAGO.PNG';
  
  PL_FPDF.LoadPDF(l_boleto_pdf);
  
  -- Adicionar carimbo no centro da página
  PL_FPDF.OverlayImage(
    p_page_number => 1,
    p_x => 70,
    p_y => 120,
    p_width => 60,
    p_height => 60,
    p_image => l_carimbo_img,
    p_opacity => 0.7
  );
  
  -- Salvar boleto com carimbo
  UPDATE boletos
  SET pdf_content = PL_FPDF.OutputModifiedPDF(),
      status = 'PAGO',
      data_pagamento = SYSDATE
  WHERE id = 789;
END;
```

---

## 🔬 Desafios Técnicos

### 1. Decompressão de Streams

PDFs usam múltiplos algoritmos de compressão:

```sql
-- FlateDecode (zlib) - Usar UTL_COMPRESS
FUNCTION decompress_flate(p_stream BLOB) RETURN BLOB IS
  l_decompressed BLOB;
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_decompressed, TRUE);
  UTL_COMPRESS.LZ_UNCOMPRESS(p_stream, l_decompressed);
  RETURN l_decompressed;
END;

-- LZWDecode - Implementar algoritmo Lempel-Ziv-Welch
FUNCTION decompress_lzw(p_stream BLOB) RETURN BLOB IS
  -- Implementação complexa necessária
  -- Referência: https://en.wikipedia.org/wiki/Lempel–Ziv–Welch
END;

-- ASCIIHexDecode - Simples conversão hexadecimal
FUNCTION decode_ascii_hex(p_stream BLOB) RETURN BLOB IS
  l_hex VARCHAR2(32767);
  l_decoded BLOB;
BEGIN
  l_hex := UTL_RAW.CAST_TO_VARCHAR2(p_stream);
  l_decoded := HEXTORAW(REPLACE(l_hex, ' ', ''));
  RETURN l_decoded;
END;
```

### 2. Parsing de Content Streams

Content streams são sequências de operadores PDF:

```
BT                    % Begin Text
/F1 12 Tf             % Set font F1, size 12
100 700 Td            % Position at (100, 700)
(Hello) Tj            % Show text "Hello"
ET                    % End Text
```

Parser precisa interpretar operadores:

```sql
FUNCTION parse_content_stream(p_content BLOB) RETURN text_array IS
  l_content VARCHAR2(32767);
  l_operator VARCHAR2(10);
  l_text_array text_array;
  l_in_text_block BOOLEAN := FALSE;
BEGIN
  l_content := UTL_RAW.CAST_TO_VARCHAR2(p_content);
  
  -- Tokenizar content stream
  -- Identificar operadores: BT, ET, Tf, Td, Tj, TJ, etc.
  -- Extrair strings entre parênteses (texto)
  
  RETURN l_text_array;
END;
```

### 3. Gerenciamento de Referências

PDFs usam referências indiretas entre objetos:

```
5 0 obj
<<
  /Type /Page
  /Parent 2 0 R      ← Referência ao objeto 2
  /Resources 6 0 R   ← Referência ao objeto 6
>>
endobj
```

Necessário cache de objetos e resolução de referências:

```sql
TYPE object_cache_type IS TABLE OF pdf_object_rec INDEX BY PLS_INTEGER;
g_object_cache object_cache_type;

FUNCTION resolve_reference(p_ref VARCHAR2) RETURN pdf_object_rec IS
  l_obj_num PLS_INTEGER;
BEGIN
  -- Extrair número do objeto de "6 0 R"
  l_obj_num := TO_NUMBER(REGEXP_SUBSTR(p_ref, '^\d+'));
  
  -- Verificar cache
  IF g_object_cache.EXISTS(l_obj_num) THEN
    RETURN g_object_cache(l_obj_num);
  END IF;
  
  -- Carregar objeto do PDF original
  -- ...
END;
```

---

## 📚 Referências

### Especificações

- **PDF Reference 1.7 (ISO 32000-1:2008)**
  https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf

- **PDF 2.0 (ISO 32000-2:2020)**
  https://pdfa.org/resource/iso-32000-pdf/

### Implementações de Referência

- **QPDF** (C++) - https://github.com/qpdf/qpdf
- **PyPDF2** (Python) - https://github.com/py-pdf/pypdf
- **iText** (Java) - https://itextpdf.com/
- **PDFBox** (Java) - https://pdfbox.apache.org/

### Tutoriais

- **PDF Explained (O'Reilly)** - Livro excelente sobre estrutura PDF
- **Developing with PDF** - Adobe Developer Guide

---

## ✅ Checklist de Implementação

### Fase 1: Parser Básico (2-3 semanas)
- [ ] Ler header PDF
- [ ] Parser xref table (normal e comprimida)
- [ ] Parser trailer
- [ ] Carregar objetos indiretos
- [ ] Resolver referências entre objetos
- [ ] Parser page tree
- [ ] Extrair número de páginas

### Fase 2: Extração (2 semanas)
- [ ] Decompressão FlateDecode
- [ ] Parser content stream básico
- [ ] Extrair texto simples
- [ ] Extrair imagens (JPEG, PNG)
- [ ] Listar fontes utilizadas

### Fase 3: Modificação (2-3 semanas)
- [ ] Adicionar overlays de texto
- [ ] Adicionar overlays de imagem
- [ ] Marca d'água
- [ ] Rotacionar páginas
- [ ] Remover páginas

### Fase 4: Operações em Lote (1 semana)
- [ ] Mesclar PDFs
- [ ] Dividir PDFs
- [ ] Extrair páginas específicas
- [ ] Reordenar páginas

### Fase 5: Testes e Otimização (1 semana)
- [ ] Testes com PDFs reais
- [ ] Performance tuning
- [ ] Gestão de memória
- [ ] Documentação completa

---

**Status:** 📋 Especificação completa - Pronto para desenvolvimento
**Próximo Passo:** Obter aprovação e iniciar Fase 1 (Parser Básico)
