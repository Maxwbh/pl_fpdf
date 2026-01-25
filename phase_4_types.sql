--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-alpha - Fase 4: PDF Parser Types
-- Tipos customizados para leitura e modificação de PDFs
--------------------------------------------------------------------------------

-- Entrada da tabela xref
CREATE OR REPLACE TYPE pdf_xref_entry AS OBJECT (
  offset PLS_INTEGER,
  generation PLS_INTEGER,
  in_use BOOLEAN
);
/

-- Objeto PDF
CREATE OR REPLACE TYPE pdf_object_type AS OBJECT (
  obj_id PLS_INTEGER,
  generation PLS_INTEGER,
  obj_type VARCHAR2(50),       -- 'dictionary', 'stream', 'array', 'number', 'string'
  obj_content CLOB,
  stream_data BLOB,
  is_compressed BOOLEAN
);
/

-- Página PDF
CREATE OR REPLACE TYPE pdf_page_type AS OBJECT (
  page_number PLS_INTEGER,
  page_obj_id PLS_INTEGER,
  width NUMBER,
  height NUMBER,
  rotation NUMBER,
  media_box VARCHAR2(100),
  content_stream_id PLS_INTEGER,
  resources_id PLS_INTEGER
);
/

-- Arrays
CREATE OR REPLACE TYPE pdf_blob_array AS TABLE OF BLOB;
/

CREATE OR REPLACE TYPE pdf_page_array AS TABLE OF pdf_page_type;
/

