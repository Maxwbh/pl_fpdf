--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-alpha - Fase 4: PDF Parser Implementation (Starter Code)
-- Este código deve ser adicionado ao package body PL_FPDF.pkb
--------------------------------------------------------------------------------

/*******************************************************************************
 * FASE 4: PDF PARSER - VARIÁVEIS GLOBAIS DO PACKAGE BODY
 ******************************************************************************/

-- PDF carregado em memória
g_loaded_pdf BLOB;

-- Informações do PDF
g_pdf_version VARCHAR2(10);
g_xref_offset PLS_INTEGER;
g_root_obj_id PLS_INTEGER;
g_loaded_page_count PLS_INTEGER := 0;

-- Tabela xref (object_id => offset)
TYPE xref_entry_rec IS RECORD (
  offset PLS_INTEGER,
  generation PLS_INTEGER,
  in_use BOOLEAN
);
TYPE xref_table_type IS TABLE OF xref_entry_rec INDEX BY PLS_INTEGER;
g_xref_table xref_table_type;

-- Cache de objetos
TYPE object_cache_type IS TABLE OF CLOB INDEX BY PLS_INTEGER;
g_object_cache object_cache_type;


/*******************************************************************************
 * FUNÇÕES HELPER - PARSING DE PDF
 ******************************************************************************/

--------------------------------------------------------------------------------
-- read_blob_chunk: Ler pedaço de BLOB como texto
--------------------------------------------------------------------------------
FUNCTION read_blob_chunk(
  p_blob BLOB,
  p_offset PLS_INTEGER,
  p_length PLS_INTEGER
) RETURN VARCHAR2 IS
  l_raw RAW(32767);
BEGIN
  l_raw := DBMS_LOB.SUBSTR(p_blob, LEAST(p_length, 32767), p_offset);
  RETURN UTL_RAW.CAST_TO_VARCHAR2(l_raw);
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END read_blob_chunk;

--------------------------------------------------------------------------------
-- find_pattern_in_blob: Encontrar padrão em BLOB
--------------------------------------------------------------------------------
FUNCTION find_pattern_in_blob(
  p_blob BLOB,
  p_pattern VARCHAR2,
  p_start_pos PLS_INTEGER DEFAULT 1
) RETURN PLS_INTEGER IS
  l_chunk VARCHAR2(32767);
  l_chunk_size PLS_INTEGER := 32767;
  l_pos PLS_INTEGER := p_start_pos;
  l_blob_size PLS_INTEGER;
  l_found_pos PLS_INTEGER;
BEGIN
  l_blob_size := DBMS_LOB.GETLENGTH(p_blob);
  
  WHILE l_pos <= l_blob_size LOOP
    l_chunk := read_blob_chunk(p_blob, l_pos, l_chunk_size);
    l_found_pos := INSTR(l_chunk, p_pattern);
    
    IF l_found_pos > 0 THEN
      RETURN l_pos + l_found_pos - 1;
    END IF;
    
    -- Avançar, mas com overlap para não perder padrão na fronteira
    l_pos := l_pos + l_chunk_size - LENGTH(p_pattern);
  END LOOP;
  
  RETURN 0; -- Não encontrado
END find_pattern_in_blob;

--------------------------------------------------------------------------------
-- extract_number_after_pattern: Extrair número após padrão
--------------------------------------------------------------------------------
FUNCTION extract_number_after_pattern(
  p_text VARCHAR2,
  p_pattern VARCHAR2
) RETURN PLS_INTEGER IS
  l_pos PLS_INTEGER;
  l_num_str VARCHAR2(20);
BEGIN
  l_pos := INSTR(p_text, p_pattern);
  
  IF l_pos = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Extrair dígitos após o padrão
  l_num_str := REGEXP_SUBSTR(
    SUBSTR(p_text, l_pos + LENGTH(p_pattern)),
    '^\s*([0-9]+)',
    1, 1, NULL, 1
  );
  
  RETURN TO_NUMBER(l_num_str);
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END extract_number_after_pattern;


/*******************************************************************************
 * FASE 4.1: LEITURA DE PDFs - PARSING BÁSICO
 ******************************************************************************/

--------------------------------------------------------------------------------
-- parse_pdf_header: Extrair versão do PDF
--------------------------------------------------------------------------------
FUNCTION parse_pdf_header(p_pdf BLOB) RETURN VARCHAR2 IS
  l_header VARCHAR2(50);
BEGIN
  l_header := read_blob_chunk(p_pdf, 1, 50);
  
  -- Validar header %PDF-
  IF NOT l_header LIKE '%PDF-%' THEN
    raise_application_error(-20801, 
      'Invalid PDF header. Expected %PDF-x.x, got: ' || SUBSTR(l_header, 1, 20));
  END IF;
  
  -- Extrair versão (ex: "1.7" de "%PDF-1.7")
  RETURN REGEXP_SUBSTR(l_header, '[0-9]\.[0-9]');
END parse_pdf_header;

--------------------------------------------------------------------------------
-- find_startxref: Localizar offset da tabela xref
--------------------------------------------------------------------------------
FUNCTION find_startxref(p_pdf BLOB) RETURN PLS_INTEGER IS
  l_file_size PLS_INTEGER;
  l_tail VARCHAR2(2048);
  l_offset PLS_INTEGER;
BEGIN
  l_file_size := DBMS_LOB.GETLENGTH(p_pdf);
  
  -- Ler últimos 2KB do arquivo
  l_tail := read_blob_chunk(p_pdf, GREATEST(1, l_file_size - 2047), 2048);
  
  -- Extrair número após "startxref"
  l_offset := extract_number_after_pattern(l_tail, 'startxref');
  
  IF l_offset IS NULL THEN
    raise_application_error(-20802, 'startxref not found in PDF');
  END IF;
  
  RETURN l_offset;
END find_startxref;

--------------------------------------------------------------------------------
-- parse_xref_table: Analisar tabela de referências cruzadas
--------------------------------------------------------------------------------
PROCEDURE parse_xref_table(p_pdf BLOB, p_xref_offset PLS_INTEGER) IS
  l_xref_section VARCHAR2(32767);
  l_lines apex_t_varchar2;
  l_line VARCHAR2(100);
  l_obj_start PLS_INTEGER;
  l_obj_count PLS_INTEGER;
  l_obj_id PLS_INTEGER;
  l_offset PLS_INTEGER;
  l_generation PLS_INTEGER;
  l_flag CHAR(1);
  l_i PLS_INTEGER;
BEGIN
  g_xref_table.DELETE;
  
  -- Ler seção xref
  l_xref_section := read_blob_chunk(p_pdf, p_xref_offset + 1, 32767);
  
  -- Validar que começa com "xref"
  IF NOT l_xref_section LIKE 'xref%' THEN
    raise_application_error(-20803, 'Invalid xref table at offset ' || p_xref_offset);
  END IF;
  
  -- Dividir em linhas
  l_lines := apex_string.split(l_xref_section, CHR(10));
  
  -- Linha 1: "xref" (pular)
  -- Linha 2: subsection header "0 N" onde N = número de objetos
  l_line := l_lines(2);
  l_obj_start := TO_NUMBER(REGEXP_SUBSTR(l_line, '^[0-9]+'));
  l_obj_count := TO_NUMBER(REGEXP_SUBSTR(l_line, '[0-9]+$'));
  
  -- Processar entradas xref
  l_obj_id := l_obj_start;
  l_i := 3; -- Começar na linha 3
  
  FOR idx IN 1..l_obj_count LOOP
    EXIT WHEN l_i > l_lines.COUNT;
    
    l_line := l_lines(l_i);
    EXIT WHEN l_line LIKE 'trailer%';
    
    -- Formato: "NNNNNNNNNN GGGGG f/n"
    -- Exemplo: "0000000015 00000 n"
    l_offset := TO_NUMBER(TRIM(SUBSTR(l_line, 1, 10)));
    l_generation := TO_NUMBER(TRIM(SUBSTR(l_line, 12, 5)));
    l_flag := SUBSTR(l_line, 18, 1);
    
    -- Armazenar apenas objetos em uso ('n')
    IF l_flag = 'n' THEN
      g_xref_table(l_obj_id).offset := l_offset;
      g_xref_table(l_obj_id).generation := l_generation;
      g_xref_table(l_obj_id).in_use := TRUE;
    END IF;
    
    l_obj_id := l_obj_id + 1;
    l_i := l_i + 1;
  END LOOP;
  
  log_message(3, 'Parsed xref table: ' || g_xref_table.COUNT || ' objects');
END parse_xref_table;

--------------------------------------------------------------------------------
-- parse_trailer: Extrair informações do trailer
--------------------------------------------------------------------------------
PROCEDURE parse_trailer(p_pdf BLOB, p_xref_offset PLS_INTEGER) IS
  l_trailer VARCHAR2(4000);
  l_root_id PLS_INTEGER;
BEGIN
  -- Ler trailer (após xref)
  l_trailer := read_blob_chunk(p_pdf, p_xref_offset + 1, 4000);
  
  -- Extrair /Root object ID
  l_root_id := TO_NUMBER(
    REGEXP_SUBSTR(l_trailer, '/Root\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );
  
  IF l_root_id IS NULL THEN
    raise_application_error(-20804, 'Root object not found in trailer');
  END IF;
  
  g_root_obj_id := l_root_id;
  
  log_message(3, 'Trailer parsed: Root=' || g_root_obj_id);
END parse_trailer;

--------------------------------------------------------------------------------
-- get_pdf_object: Carregar objeto por ID
--------------------------------------------------------------------------------
FUNCTION get_pdf_object(p_obj_id PLS_INTEGER) RETURN CLOB IS
  l_offset PLS_INTEGER;
  l_obj_text VARCHAR2(32767);
  l_end_pos PLS_INTEGER;
  l_obj_content CLOB;
BEGIN
  -- Verificar cache
  IF g_object_cache.EXISTS(p_obj_id) THEN
    RETURN g_object_cache(p_obj_id);
  END IF;
  
  -- Verificar se objeto existe
  IF NOT g_xref_table.EXISTS(p_obj_id) THEN
    raise_application_error(-20805, 'Object ' || p_obj_id || ' not in xref table');
  END IF;
  
  l_offset := g_xref_table(p_obj_id).offset;
  
  -- Ler objeto
  l_obj_text := read_blob_chunk(g_loaded_pdf, l_offset + 1, 32767);
  
  -- Encontrar fim do objeto
  l_end_pos := INSTR(l_obj_text, 'endobj');
  
  IF l_end_pos = 0 THEN
    raise_application_error(-20806, 'endobj not found for object ' || p_obj_id);
  END IF;
  
  -- Extrair conteúdo
  l_obj_content := SUBSTR(l_obj_text, 1, l_end_pos + 5);
  
  -- Cache
  g_object_cache(p_obj_id) := l_obj_content;
  
  RETURN l_obj_content;
END get_pdf_object;

--------------------------------------------------------------------------------
-- count_pages: Contar páginas no PDF
--------------------------------------------------------------------------------
FUNCTION count_pages RETURN PLS_INTEGER IS
  l_catalog CLOB;
  l_pages_id PLS_INTEGER;
  l_pages_obj CLOB;
  l_count PLS_INTEGER;
BEGIN
  -- 1. Obter Catalog
  l_catalog := get_pdf_object(g_root_obj_id);
  
  -- 2. Extrair ID do objeto Pages
  l_pages_id := TO_NUMBER(
    REGEXP_SUBSTR(l_catalog, '/Pages\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );
  
  IF l_pages_id IS NULL THEN
    raise_application_error(-20807, 'Pages not found in Catalog');
  END IF;
  
  -- 3. Obter objeto Pages
  l_pages_obj := get_pdf_object(l_pages_id);
  
  -- 4. Extrair /Count
  l_count := TO_NUMBER(
    REGEXP_SUBSTR(l_pages_obj, '/Count\s+([0-9]+)', 1, 1, NULL, 1)
  );
  
  IF l_count IS NULL THEN
    raise_application_error(-20808, 'Count not found in Pages object');
  END IF;
  
  RETURN l_count;
END count_pages;


/*******************************************************************************
 * API PÚBLICA - FASE 4
 ******************************************************************************/

--------------------------------------------------------------------------------
-- LoadPDF: Carregar PDF existente em memória
--------------------------------------------------------------------------------
PROCEDURE LoadPDF(p_pdf_blob BLOB) IS
BEGIN
  log_message(3, 'Loading PDF...');
  
  -- Validar
  IF p_pdf_blob IS NULL OR DBMS_LOB.GETLENGTH(p_pdf_blob) < 100 THEN
    raise_application_error(-20800, 'Invalid PDF: NULL or too small');
  END IF;
  
  -- Limpar estado anterior
  g_loaded_pdf := p_pdf_blob;
  g_object_cache.DELETE;
  g_xref_table.DELETE;
  
  -- Parse header
  g_pdf_version := parse_pdf_header(p_pdf_blob);
  log_message(3, 'PDF version: ' || g_pdf_version);
  
  -- Find xref
  g_xref_offset := find_startxref(p_pdf_blob);
  log_message(3, 'xref offset: ' || g_xref_offset);
  
  -- Parse xref table
  parse_xref_table(p_pdf_blob, g_xref_offset);
  
  -- Parse trailer
  parse_trailer(p_pdf_blob, g_xref_offset);
  
  -- Count pages
  g_loaded_page_count := count_pages();
  
  log_message(2, 'PDF loaded successfully: ' || g_loaded_page_count || ' pages, version ' || g_pdf_version);
  
EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error loading PDF: ' || SQLERRM);
    RAISE;
END LoadPDF;

--------------------------------------------------------------------------------
-- GetPageCount: Obter número de páginas do PDF carregado
--------------------------------------------------------------------------------
FUNCTION GetPageCount RETURN PLS_INTEGER IS
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;
  
  RETURN g_loaded_page_count;
END GetPageCount;

--------------------------------------------------------------------------------
-- GetPDFInfo: Obter informações do PDF carregado
--------------------------------------------------------------------------------
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T IS
  l_info JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;
  
  l_info.put('version', g_pdf_version);
  l_info.put('pageCount', g_loaded_page_count);
  l_info.put('fileSize', DBMS_LOB.GETLENGTH(g_loaded_pdf));
  l_info.put('objectCount', g_xref_table.COUNT);
  l_info.put('rootObjectId', g_root_obj_id);
  
  RETURN l_info;
END GetPDFInfo;

