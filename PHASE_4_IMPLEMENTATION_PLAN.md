# Fase 4 - Implementação 100% PL/SQL Puro

**Decisão:** Implementar PDF Parser completamente em PL/SQL, sem Java ou APIs externas
**Justificativa:** Máxima portabilidade, zero dependências externas, controle total
**Desafio:** Alto - PDF é formato complexo
**Abordagem:** Incremental - MVP funcional primeiro, depois expandir

---

## 🎯 MVP (Minimum Viable Product)

### Funcionalidades Essenciais - v3.0.0-alpha

**Fase 1A: Leitura Básica** (1-2 semanas)
- ✅ Ler header PDF (versão)
- ✅ Parser xref table simples (não comprimida)
- ✅ Parser trailer
- ✅ Localizar objeto Catalog
- ✅ Contar páginas (parse page tree)

**Fase 1B: Merge Simples** (1 semana)
- ✅ MergePDFs() - juntar 2+ PDFs
- ✅ Reescrever xref table
- ✅ Atualizar trailer
- ✅ Gerar PDF mesclado válido

**Fase 2A: Overlay Básico** (1 semana)
- ✅ Decompressão FlateDecode (UTL_COMPRESS)
- ✅ OverlayText() - adicionar texto sobre página
- ✅ Recomprimir content stream
- ✅ Atualizar página no PDF

**Fase 3A: Extração Básica** (1 semana)
- ✅ ExtractText() simples (operadores Tj, TJ)
- ✅ ExtractPages() - dividir PDF

---

## 📐 Arquitetura Técnica

### Estrutura de Dados

```sql
-- Tipos globais no package
TYPE pdf_object_rec IS RECORD (
  obj_id PLS_INTEGER,
  generation PLS_INTEGER,
  obj_offset PLS_INTEGER,
  obj_content CLOB,
  stream_data BLOB
);

TYPE pdf_object_array IS TABLE OF pdf_object_rec INDEX BY PLS_INTEGER;

-- Cache global de objetos
g_pdf_blob BLOB;                        -- PDF original em memória
g_pdf_objects pdf_object_array;         -- Cache de objetos
g_xref_table pdf_xref_array;            -- Tabela xref
g_root_obj_id PLS_INTEGER;              -- Catalog object ID
g_pages_obj_id PLS_INTEGER;             -- Pages object ID
g_page_count PLS_INTEGER;               -- Total de páginas
```

### Fluxo de Parsing

```
LoadPDF(p_pdf BLOB)
  ├─> 1. Armazenar BLOB em g_pdf_blob
  ├─> 2. parse_header() → versão PDF
  ├─> 3. find_startxref() → offset da xref table
  ├─> 4. parse_xref_table() → popular g_xref_table
  ├─> 5. parse_trailer() → obter /Root e /Size
  ├─> 6. get_object(g_root_obj_id) → Catalog
  ├─> 7. get_object(g_pages_obj_id) → Pages
  └─> 8. count_pages() → calcular g_page_count
```

---

## 💻 Código de Implementação

### Fase 1A: Parser Básico

```sql
--------------------------------------------------------------------------------
-- FASE 1A: PARSER BÁSICO DE PDF
--------------------------------------------------------------------------------

-- Variáveis globais do package body
g_pdf_blob BLOB;
g_pdf_version VARCHAR2(10);
g_xref_offset PLS_INTEGER;
g_xref_table xref_table_type;
g_root_obj_id PLS_INTEGER;
g_page_count PLS_INTEGER := 0;

--------------------------------------------------------------------------------
-- LoadPDF: Carregar PDF em memória
--------------------------------------------------------------------------------
PROCEDURE LoadPDF(p_pdf_blob BLOB) IS
BEGIN
  -- Validar PDF
  IF p_pdf_blob IS NULL OR DBMS_LOB.GETLENGTH(p_pdf_blob) < 100 THEN
    raise_application_error(-20801, 'Invalid PDF: too small or NULL');
  END IF;

  -- Armazenar em memória
  g_pdf_blob := p_pdf_blob;

  -- 1. Parse header
  g_pdf_version := parse_pdf_header();
  log_message(3, 'PDF version: ' || g_pdf_version);

  -- 2. Find startxref
  g_xref_offset := find_startxref();
  log_message(3, 'xref offset: ' || g_xref_offset);

  -- 3. Parse xref table
  parse_xref_table();
  log_message(3, 'xref entries: ' || g_xref_table.COUNT);

  -- 4. Parse trailer
  parse_trailer();
  log_message(3, 'Root object: ' || g_root_obj_id);

  -- 5. Count pages
  g_page_count := count_pages_in_tree();
  log_message(2, 'PDF loaded: ' || g_page_count || ' pages');

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error loading PDF: ' || SQLERRM);
    RAISE;
END LoadPDF;

--------------------------------------------------------------------------------
-- parse_pdf_header: Extrair versão do PDF
--------------------------------------------------------------------------------
FUNCTION parse_pdf_header RETURN VARCHAR2 IS
  l_header RAW(20);
  l_header_str VARCHAR2(20);
BEGIN
  -- Ler primeiros 20 bytes
  l_header := DBMS_LOB.SUBSTR(g_pdf_blob, 20, 1);
  l_header_str := UTL_RAW.CAST_TO_VARCHAR2(l_header);

  -- Validar header: deve começar com %PDF-
  IF NOT l_header_str LIKE '%PDF-%' THEN
    raise_application_error(-20802, 'Invalid PDF header: ' || l_header_str);
  END IF;

  -- Extrair versão (ex: "1.7" de "%PDF-1.7")
  RETURN REGEXP_SUBSTR(l_header_str, '[0-9]\.[0-9]');

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error parsing PDF header: ' || SQLERRM);
    RAISE;
END parse_pdf_header;

--------------------------------------------------------------------------------
-- find_startxref: Localizar offset da xref table
--------------------------------------------------------------------------------
FUNCTION find_startxref RETURN PLS_INTEGER IS
  l_file_size PLS_INTEGER;
  l_tail RAW(1024);
  l_tail_str VARCHAR2(1024);
  l_startxref_pos PLS_INTEGER;
  l_offset_str VARCHAR2(20);
BEGIN
  l_file_size := DBMS_LOB.GETLENGTH(g_pdf_blob);

  -- Ler últimos 1024 bytes (onde está startxref)
  l_tail := DBMS_LOB.SUBSTR(g_pdf_blob, 1024, GREATEST(1, l_file_size - 1023));
  l_tail_str := UTL_RAW.CAST_TO_VARCHAR2(l_tail);

  -- Procurar "startxref" seguido de número
  l_startxref_pos := INSTR(l_tail_str, 'startxref');
  
  IF l_startxref_pos = 0 THEN
    raise_application_error(-20803, 'startxref not found');
  END IF;

  -- Extrair número após "startxref"
  l_offset_str := REGEXP_SUBSTR(
    SUBSTR(l_tail_str, l_startxref_pos + 9), -- Pular "startxref"
    '[0-9]+'
  );

  RETURN TO_NUMBER(l_offset_str);

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error finding startxref: ' || SQLERRM);
    RAISE;
END find_startxref;

--------------------------------------------------------------------------------
-- parse_xref_table: Carregar cross-reference table
--------------------------------------------------------------------------------
PROCEDURE parse_xref_table IS
  l_xref_raw RAW(32767);
  l_xref_str VARCHAR2(32767);
  l_pos PLS_INTEGER := 1;
  l_line VARCHAR2(100);
  l_obj_id PLS_INTEGER := 0;
  l_offset PLS_INTEGER;
  l_generation PLS_INTEGER;
  l_in_use CHAR(1);
BEGIN
  g_xref_table.DELETE;

  -- Ler xref section (até 32KB)
  l_xref_raw := DBMS_LOB.SUBSTR(g_pdf_blob, 32767, g_xref_offset + 1);
  l_xref_str := UTL_RAW.CAST_TO_VARCHAR2(l_xref_raw);

  -- Validar que começa com "xref"
  IF NOT l_xref_str LIKE 'xref%' THEN
    raise_application_error(-20804, 'Invalid xref table');
  END IF;

  -- Pular linha "xref"
  l_pos := INSTR(l_xref_str, CHR(10)) + 1;

  -- Ler linha de subsection header (ex: "0 85")
  l_line := SUBSTR(l_xref_str, l_pos, INSTR(l_xref_str, CHR(10), l_pos) - l_pos);
  l_obj_id := TO_NUMBER(REGEXP_SUBSTR(l_line, '^[0-9]+'));
  l_pos := INSTR(l_xref_str, CHR(10), l_pos) + 1;

  -- Ler entradas xref (formato: "0000000015 00000 n")
  LOOP
    l_line := SUBSTR(l_xref_str, l_pos, 20);
    
    EXIT WHEN l_line LIKE 'trailer%' OR l_line IS NULL;

    -- Parse entrada: offset(10) generation(5) flag(1)
    l_offset := TO_NUMBER(TRIM(SUBSTR(l_line, 1, 10)));
    l_generation := TO_NUMBER(TRIM(SUBSTR(l_line, 12, 5)));
    l_in_use := SUBSTR(l_line, 18, 1);

    -- Armazenar se objeto está em uso
    IF l_in_use = 'n' THEN
      g_xref_table(l_obj_id).offset := l_offset;
      g_xref_table(l_obj_id).generation := l_generation;
      g_xref_table(l_obj_id).in_use := TRUE;
    END IF;

    l_obj_id := l_obj_id + 1;
    l_pos := INSTR(l_xref_str, CHR(10), l_pos) + 1;
  END LOOP;

  log_message(4, 'Parsed ' || g_xref_table.COUNT || ' xref entries');

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error parsing xref table: ' || SQLERRM);
    RAISE;
END parse_xref_table;

--------------------------------------------------------------------------------
-- parse_trailer: Extrair informações do trailer
--------------------------------------------------------------------------------
PROCEDURE parse_trailer IS
  l_trailer_raw RAW(4000);
  l_trailer_str VARCHAR2(4000);
  l_root_str VARCHAR2(20);
BEGIN
  -- Ler trailer section (após xref table)
  l_trailer_raw := DBMS_LOB.SUBSTR(
    g_pdf_blob,
    4000,
    g_xref_offset + 1
  );
  l_trailer_str := UTL_RAW.CAST_TO_VARCHAR2(l_trailer_raw);

  -- Procurar /Root
  l_root_str := REGEXP_SUBSTR(l_trailer_str, '/Root\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1);
  
  IF l_root_str IS NOT NULL THEN
    g_root_obj_id := TO_NUMBER(l_root_str);
  ELSE
    raise_application_error(-20805, 'Root object not found in trailer');
  END IF;

  log_message(4, 'Trailer parsed: Root=' || g_root_obj_id);

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error parsing trailer: ' || SQLERRM);
    RAISE;
END parse_trailer;

--------------------------------------------------------------------------------
-- get_object: Carregar objeto PDF por ID
--------------------------------------------------------------------------------
FUNCTION get_object(p_obj_id PLS_INTEGER) RETURN CLOB IS
  l_offset PLS_INTEGER;
  l_obj_raw RAW(32767);
  l_obj_str VARCHAR2(32767);
  l_obj_content CLOB;
  l_end_pos PLS_INTEGER;
BEGIN
  -- Verificar se objeto existe na xref table
  IF NOT g_xref_table.EXISTS(p_obj_id) THEN
    raise_application_error(-20806, 'Object ' || p_obj_id || ' not found in xref');
  END IF;

  l_offset := g_xref_table(p_obj_id).offset;

  -- Ler objeto (até 32KB)
  l_obj_raw := DBMS_LOB.SUBSTR(g_pdf_blob, 32767, l_offset + 1);
  l_obj_str := UTL_RAW.CAST_TO_VARCHAR2(l_obj_raw);

  -- Encontrar fim do objeto (endobj)
  l_end_pos := INSTR(l_obj_str, 'endobj');
  
  IF l_end_pos = 0 THEN
    raise_application_error(-20807, 'endobj not found for object ' || p_obj_id);
  END IF;

  -- Extrair conteúdo do objeto
  l_obj_content := SUBSTR(l_obj_str, 1, l_end_pos + 6);

  RETURN l_obj_content;

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error getting object ' || p_obj_id || ': ' || SQLERRM);
    RAISE;
END get_object;

--------------------------------------------------------------------------------
-- count_pages_in_tree: Contar total de páginas
--------------------------------------------------------------------------------
FUNCTION count_pages_in_tree RETURN PLS_INTEGER IS
  l_catalog CLOB;
  l_pages_id PLS_INTEGER;
  l_pages_obj CLOB;
  l_count_str VARCHAR2(20);
BEGIN
  -- 1. Obter objeto Catalog
  l_catalog := get_object(g_root_obj_id);

  -- 2. Extrair referência ao objeto Pages
  l_pages_id := TO_NUMBER(
    REGEXP_SUBSTR(l_catalog, '/Pages\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_pages_id IS NULL THEN
    raise_application_error(-20808, 'Pages reference not found in Catalog');
  END IF;

  -- 3. Obter objeto Pages
  l_pages_obj := get_object(l_pages_id);

  -- 4. Extrair /Count
  l_count_str := REGEXP_SUBSTR(l_pages_obj, '/Count\s+([0-9]+)', 1, 1, NULL, 1);

  IF l_count_str IS NULL THEN
    raise_application_error(-20809, 'Count not found in Pages object');
  END IF;

  RETURN TO_NUMBER(l_count_str);

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error counting pages: ' || SQLERRM);
    RAISE;
END count_pages_in_tree;

--------------------------------------------------------------------------------
-- GetPageCount: API pública
--------------------------------------------------------------------------------
FUNCTION GetPageCount RETURN PLS_INTEGER IS
BEGIN
  IF g_pdf_blob IS NULL THEN
    raise_application_error(-20810, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  RETURN g_page_count;
END GetPageCount;
```

---

## ✅ Próximos Passos

1. **Implementar na PL_FPDF.pkb** - Adicionar código acima
2. **Testar com PDFs simples** - Validar parsing básico
3. **Fase 1B: MergePDFs()** - Implementar merge de 2 PDFs
4. **Testes de validação** - Criar validate_phase_4.sql

