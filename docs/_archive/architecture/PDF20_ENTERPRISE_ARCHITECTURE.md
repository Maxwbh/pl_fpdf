# Arquitetura Enterprise para PDF 2.0

**Version:** 4.0.0
**Date:** 2026-03
**Status:** Proposta

---

## Visao Geral

Para PDF 2.0 com features avancadas (assinaturas, PDF/A, accessibility), uma arquitetura **com tabelas e tipos externos** oferece:

- ✅ **Melhor organizacao** de objetos complexos
- ✅ **Persistencia** de certificados e fontes
- ✅ **Cache compartilhado** entre sessoes
- ✅ **Auditoria** de operacoes
- ✅ **Pipelining SQL** para processamento em lote
- ✅ **Querying** de metadados PDF

---

## Arquitetura Completa

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           APPLICATION LAYER                              │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   APEX App  │  │  PL/SQL Job │  │  REST API   │  │  OCI SDK    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           PL_FPDF API (Facade)                          │
│                                                                          │
│  PL_FPDF.Init() | AddPage() | Cell() | Output() | LoadPDF() | Sign()    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  PL_FPDF_CORE   │     │  PL_FPDF_CRYPTO │     │  PL_FPDF_SIGN   │
│  PDF Engine     │     │  Encryption     │     │  Signatures     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
          │                         │                         │
          └─────────────────────────┼─────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA LAYER (Tables)                           │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ FPDF_FONTS  │  │ FPDF_CERTS  │  │ FPDF_CACHE  │  │ FPDF_AUDIT  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           TYPE LAYER (Object Types)                     │
│                                                                          │
│  T_PDF_DOCUMENT | T_PDF_PAGE | T_PDF_OBJECT | T_SIGNATURE | T_FONT      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Object Types (Schema-Level)

### T_PDF_OBJECT - Base Object Type

```sql
CREATE OR REPLACE TYPE T_PDF_OBJECT AS OBJECT (
  obj_id          NUMBER,
  obj_generation  NUMBER,
  obj_type        VARCHAR2(50),
  raw_content     CLOB,
  stream_data     BLOB,
  is_compressed   CHAR(1),
  is_encrypted    CHAR(1),

  -- Methods
  MEMBER FUNCTION Serialize RETURN CLOB,
  MEMBER FUNCTION GetDictionary RETURN JSON_OBJECT_T,
  MEMBER PROCEDURE SetDictionary(p_dict JSON_OBJECT_T),
  MEMBER FUNCTION GetStream RETURN BLOB,
  MEMBER PROCEDURE SetStream(p_data BLOB, p_compress BOOLEAN DEFAULT TRUE)
) NOT FINAL;
/

CREATE OR REPLACE TYPE BODY T_PDF_OBJECT AS

  MEMBER FUNCTION Serialize RETURN CLOB IS
    l_result CLOB;
  BEGIN
    l_result := obj_id || ' ' || obj_generation || ' obj' || CHR(10);
    l_result := l_result || raw_content;
    IF stream_data IS NOT NULL THEN
      l_result := l_result || CHR(10) || 'stream' || CHR(10);
      -- Binary stream handled separately
      l_result := l_result || 'endstream' || CHR(10);
    END IF;
    l_result := l_result || 'endobj' || CHR(10);
    RETURN l_result;
  END;

  MEMBER FUNCTION GetDictionary RETURN JSON_OBJECT_T IS
  BEGIN
    -- Parse PDF dictionary to JSON
    RETURN PL_FPDF_UTIL.ParsePDFDict(raw_content);
  END;

  -- ... outros metodos

END;
/
```

### T_PDF_PAGE - Page Object

```sql
CREATE OR REPLACE TYPE T_PDF_PAGE UNDER T_PDF_OBJECT (
  page_number     NUMBER,
  media_box       VARCHAR2(100),    -- [0 0 612 792]
  crop_box        VARCHAR2(100),
  rotation        NUMBER,
  content_streams T_NUMBER_LIST,     -- List of content stream IDs
  resources       JSON_OBJECT_T,
  annotations     T_NUMBER_LIST,

  -- Page-specific methods
  MEMBER FUNCTION GetWidth RETURN NUMBER,
  MEMBER FUNCTION GetHeight RETURN NUMBER,
  MEMBER PROCEDURE SetRotation(p_angle NUMBER),
  MEMBER PROCEDURE AddContent(p_stream_id NUMBER),
  MEMBER FUNCTION GetAnnotations RETURN T_PDF_ANNOT_LIST
);
/
```

### T_PDF_DOCUMENT - Document Container

```sql
CREATE OR REPLACE TYPE T_PDF_DOCUMENT AS OBJECT (
  doc_id          VARCHAR2(50),
  pdf_version     VARCHAR2(10),
  title           VARCHAR2(500),
  author          VARCHAR2(500),
  subject         VARCHAR2(500),
  keywords        VARCHAR2(1000),
  creator         VARCHAR2(200),
  producer        VARCHAR2(200),
  creation_date   TIMESTAMP,
  mod_date        TIMESTAMP,
  page_count      NUMBER,
  is_encrypted    CHAR(1),
  encryption_info JSON_OBJECT_T,
  is_tagged       CHAR(1),
  is_pdfa         CHAR(1),
  pdfa_level      VARCHAR2(20),
  raw_pdf         BLOB,

  -- Document methods
  CONSTRUCTOR FUNCTION T_PDF_DOCUMENT RETURN SELF AS RESULT,
  MEMBER FUNCTION GetPage(p_num NUMBER) RETURN T_PDF_PAGE,
  MEMBER FUNCTION GetPageCount RETURN NUMBER,
  MEMBER PROCEDURE AddPage(p_page T_PDF_PAGE),
  MEMBER PROCEDURE RemovePage(p_num NUMBER),
  MEMBER FUNCTION GetObjects RETURN T_PDF_OBJECT_LIST,
  MEMBER FUNCTION Serialize RETURN BLOB,
  STATIC FUNCTION Parse(p_pdf BLOB) RETURN T_PDF_DOCUMENT
);
/
```

### T_SIGNATURE - Digital Signature

```sql
CREATE OR REPLACE TYPE T_SIGNATURE AS OBJECT (
  sig_id            NUMBER,
  sig_type          VARCHAR2(50),      -- PKCS7, PAdES-B, PAdES-T, etc.
  signer_name       VARCHAR2(500),
  signer_email      VARCHAR2(200),
  reason            VARCHAR2(500),
  location          VARCHAR2(500),
  sign_date         TIMESTAMP,
  certificate       BLOB,              -- X.509 certificate
  cert_chain        T_BLOB_LIST,       -- Certificate chain
  signature_value   BLOB,              -- PKCS#7 signature
  byte_range        VARCHAR2(100),     -- [0 offset1 offset2 length]
  timestamp         BLOB,              -- TSA response (PAdES-T)
  is_valid          CHAR(1),
  validation_errors JSON_ARRAY_T,

  -- Signature methods
  MEMBER FUNCTION Validate RETURN BOOLEAN,
  MEMBER FUNCTION GetCertificateInfo RETURN JSON_OBJECT_T,
  MEMBER FUNCTION IsTimestamped RETURN BOOLEAN,
  MEMBER FUNCTION GetTimestamp RETURN TIMESTAMP
);
/
```

### Collection Types

```sql
-- Number list for object IDs
CREATE OR REPLACE TYPE T_NUMBER_LIST AS TABLE OF NUMBER;
/

-- BLOB list for certificate chains
CREATE OR REPLACE TYPE T_BLOB_LIST AS TABLE OF BLOB;
/

-- PDF Object collection
CREATE OR REPLACE TYPE T_PDF_OBJECT_LIST AS TABLE OF T_PDF_OBJECT;
/

-- Page collection
CREATE OR REPLACE TYPE T_PDF_PAGE_LIST AS TABLE OF T_PDF_PAGE;
/

-- Signature collection
CREATE OR REPLACE TYPE T_SIGNATURE_LIST AS TABLE OF T_SIGNATURE;
/
```

---

## 2. Tabelas de Suporte

### FPDF_FONTS - Font Repository

```sql
CREATE TABLE FPDF_FONTS (
  font_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  font_name         VARCHAR2(200) NOT NULL,
  font_family       VARCHAR2(100),
  font_style        VARCHAR2(20),       -- Regular, Bold, Italic, BoldItalic
  font_type         VARCHAR2(20),       -- TrueType, OpenType, Type1
  font_data         BLOB NOT NULL,       -- Font file binary
  font_metrics      JSON,                -- Glyph widths, etc.
  cmap_data         BLOB,                -- Character mapping
  encoding          VARCHAR2(50),
  is_embeddable     CHAR(1) DEFAULT 'Y',
  license_info      VARCHAR2(500),
  created_date      TIMESTAMP DEFAULT SYSTIMESTAMP,
  created_by        VARCHAR2(100),

  CONSTRAINT uk_fpdf_fonts UNIQUE (font_name, font_style)
);

CREATE INDEX idx_fpdf_fonts_family ON FPDF_FONTS(font_family);

-- Core fonts pre-loaded
INSERT INTO FPDF_FONTS (font_name, font_family, font_style, font_type, font_data, is_embeddable)
VALUES ('Helvetica', 'Helvetica', 'Regular', 'Type1', EMPTY_BLOB(), 'N');
-- ... more core fonts
```

### FPDF_CERTIFICATES - Certificate Store

```sql
CREATE TABLE FPDF_CERTIFICATES (
  cert_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cert_name         VARCHAR2(200) NOT NULL,
  cert_type         VARCHAR2(20),        -- A1, A3, PFX, PEM
  certificate       BLOB NOT NULL,        -- X.509 certificate
  private_key       BLOB,                 -- Encrypted private key
  key_algorithm     VARCHAR2(20),         -- RSA, ECDSA
  key_size          NUMBER,               -- 2048, 4096
  issuer            VARCHAR2(500),
  subject           VARCHAR2(500),
  serial_number     VARCHAR2(100),
  valid_from        TIMESTAMP,
  valid_to          TIMESTAMP,
  is_ca             CHAR(1) DEFAULT 'N',
  chain_certs       BLOB,                 -- Certificate chain
  created_date      TIMESTAMP DEFAULT SYSTIMESTAMP,
  created_by        VARCHAR2(100),

  CONSTRAINT uk_fpdf_certs UNIQUE (cert_name)
);

CREATE INDEX idx_fpdf_certs_valid ON FPDF_CERTIFICATES(valid_to);
```

### FPDF_ICC_PROFILES - Color Profiles (PDF/A)

```sql
CREATE TABLE FPDF_ICC_PROFILES (
  profile_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  profile_name      VARCHAR2(100) NOT NULL,
  profile_type      VARCHAR2(20),        -- RGB, CMYK, Gray
  color_space       VARCHAR2(20),
  profile_data      BLOB NOT NULL,
  description       VARCHAR2(500),
  is_default        CHAR(1) DEFAULT 'N',

  CONSTRAINT uk_fpdf_icc UNIQUE (profile_name)
);

-- Default sRGB profile
INSERT INTO FPDF_ICC_PROFILES (profile_name, profile_type, color_space, is_default)
VALUES ('sRGB IEC61966-2.1', 'RGB', 'RGB', 'Y');
```

### FPDF_CACHE - Document Cache

```sql
CREATE TABLE FPDF_CACHE (
  cache_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  doc_id            VARCHAR2(50) NOT NULL,
  session_id        VARCHAR2(100),
  pdf_data          BLOB,
  page_count        NUMBER,
  metadata          JSON,
  xref_data         JSON,                -- Parsed xref for fast access
  objects           JSON,                -- Object index
  is_modified       CHAR(1) DEFAULT 'N',
  created_date      TIMESTAMP DEFAULT SYSTIMESTAMP,
  accessed_date     TIMESTAMP,
  expires_date      TIMESTAMP,

  CONSTRAINT uk_fpdf_cache UNIQUE (doc_id, session_id)
);

CREATE INDEX idx_fpdf_cache_expires ON FPDF_CACHE(expires_date);

-- Auto-cleanup job
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'FPDF_CACHE_CLEANUP',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'DELETE FROM FPDF_CACHE WHERE expires_date < SYSTIMESTAMP',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=HOURLY',
    enabled         => TRUE
  );
END;
/
```

### FPDF_AUDIT - Audit Trail

```sql
CREATE TABLE FPDF_AUDIT (
  audit_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  doc_id            VARCHAR2(50),
  operation         VARCHAR2(50),        -- CREATE, MODIFY, SIGN, ENCRYPT
  operation_detail  JSON,
  user_name         VARCHAR2(100),
  session_id        VARCHAR2(100),
  ip_address        VARCHAR2(50),
  timestamp         TIMESTAMP DEFAULT SYSTIMESTAMP,
  duration_ms       NUMBER,
  status            VARCHAR2(20),        -- SUCCESS, FAILURE
  error_message     VARCHAR2(4000)
);

CREATE INDEX idx_fpdf_audit_doc ON FPDF_AUDIT(doc_id);
CREATE INDEX idx_fpdf_audit_date ON FPDF_AUDIT(timestamp);

-- Partitioned by month for large volumes
-- ALTER TABLE FPDF_AUDIT MODIFY PARTITION BY RANGE (timestamp) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'));
```

### FPDF_BATCH_JOBS - Batch Processing

```sql
CREATE TABLE FPDF_BATCH_JOBS (
  job_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  job_name          VARCHAR2(200),
  job_type          VARCHAR2(50),        -- MERGE, SPLIT, CONVERT, MIGRATE
  status            VARCHAR2(20),        -- PENDING, RUNNING, COMPLETED, FAILED
  input_docs        JSON,                -- Array of doc_ids or BLOBs
  output_doc        BLOB,
  parameters        JSON,
  progress_pct      NUMBER,
  total_items       NUMBER,
  processed_items   NUMBER,
  error_items       NUMBER,
  error_log         CLOB,
  created_date      TIMESTAMP DEFAULT SYSTIMESTAMP,
  started_date      TIMESTAMP,
  completed_date    TIMESTAMP,
  created_by        VARCHAR2(100)
);

CREATE INDEX idx_fpdf_batch_status ON FPDF_BATCH_JOBS(status);
```

---

## 3. Views Uteis

### V_FPDF_DOCUMENT_INFO

```sql
CREATE OR REPLACE VIEW V_FPDF_DOCUMENT_INFO AS
SELECT
  c.doc_id,
  c.page_count,
  JSON_VALUE(c.metadata, '$.title') AS title,
  JSON_VALUE(c.metadata, '$.author') AS author,
  JSON_VALUE(c.metadata, '$.pdfVersion') AS pdf_version,
  JSON_VALUE(c.metadata, '$.encrypted') AS is_encrypted,
  JSON_VALUE(c.metadata, '$.pdfaLevel') AS pdfa_level,
  DBMS_LOB.GETLENGTH(c.pdf_data) AS file_size,
  c.created_date,
  c.accessed_date
FROM FPDF_CACHE c;
```

### V_FPDF_CERTIFICATES_VALID

```sql
CREATE OR REPLACE VIEW V_FPDF_CERTIFICATES_VALID AS
SELECT
  cert_id,
  cert_name,
  cert_type,
  subject,
  issuer,
  valid_from,
  valid_to,
  CASE
    WHEN valid_to < SYSTIMESTAMP THEN 'EXPIRED'
    WHEN valid_to < SYSTIMESTAMP + INTERVAL '30' DAY THEN 'EXPIRING_SOON'
    ELSE 'VALID'
  END AS status,
  ROUND(valid_to - SYSTIMESTAMP) AS days_remaining
FROM FPDF_CERTIFICATES
ORDER BY valid_to;
```

---

## 4. Packages com Tabelas

### PL_FPDF_FONTS - Font Management

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_FONTS AS

  -- Add font to repository
  PROCEDURE AddFont(
    p_font_name   VARCHAR2,
    p_font_data   BLOB,
    p_font_style  VARCHAR2 DEFAULT 'Regular',
    p_encoding    VARCHAR2 DEFAULT 'UTF-8'
  );

  -- Load font from repository (cached)
  FUNCTION LoadFont(
    p_font_name VARCHAR2,
    p_font_style VARCHAR2 DEFAULT 'Regular'
  ) RETURN BLOB
  RESULT_CACHE RELIES_ON (FPDF_FONTS);

  -- Get font metrics (cached)
  FUNCTION GetFontMetrics(p_font_name VARCHAR2) RETURN JSON_OBJECT_T
  RESULT_CACHE RELIES_ON (FPDF_FONTS);

  -- List available fonts
  FUNCTION ListFonts RETURN SYS_REFCURSOR;

  -- Remove font
  PROCEDURE RemoveFont(p_font_name VARCHAR2);

END PL_FPDF_FONTS;
/
```

### PL_FPDF_CERTS - Certificate Management

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_CERTS AS

  -- Import certificate
  PROCEDURE ImportCertificate(
    p_cert_name   VARCHAR2,
    p_cert_data   BLOB,
    p_password    VARCHAR2 DEFAULT NULL,
    p_cert_type   VARCHAR2 DEFAULT 'PFX'
  );

  -- Get certificate for signing
  FUNCTION GetCertificate(p_cert_name VARCHAR2) RETURN BLOB;

  -- Validate certificate
  FUNCTION ValidateCertificate(p_cert_name VARCHAR2) RETURN JSON_OBJECT_T;

  -- List certificates
  FUNCTION ListCertificates(p_valid_only BOOLEAN DEFAULT TRUE) RETURN SYS_REFCURSOR;

  -- Get expiring certificates
  FUNCTION GetExpiringCertificates(p_days NUMBER DEFAULT 30) RETURN SYS_REFCURSOR;

END PL_FPDF_CERTS;
/
```

### PL_FPDF_BATCH - Batch Processing

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_BATCH AS

  -- Create batch job
  FUNCTION CreateJob(
    p_job_type   VARCHAR2,
    p_parameters JSON_OBJECT_T
  ) RETURN NUMBER;  -- Returns job_id

  -- Add document to job
  PROCEDURE AddDocument(
    p_job_id NUMBER,
    p_doc_id VARCHAR2
  );

  -- Execute job (async)
  PROCEDURE ExecuteJob(p_job_id NUMBER);

  -- Get job status
  FUNCTION GetJobStatus(p_job_id NUMBER) RETURN JSON_OBJECT_T;

  -- Get job result
  FUNCTION GetJobResult(p_job_id NUMBER) RETURN BLOB;

  -- Cancel job
  PROCEDURE CancelJob(p_job_id NUMBER);

  -- Batch operations
  FUNCTION MergePDFsBatch(p_doc_ids JSON_ARRAY_T) RETURN NUMBER;

  FUNCTION ConvertToPDFABatch(
    p_doc_ids JSON_ARRAY_T,
    p_level VARCHAR2 DEFAULT 'PDF/A-3b'
  ) RETURN NUMBER;

  FUNCTION MigrateToPDF20Batch(p_doc_ids JSON_ARRAY_T) RETURN NUMBER;

END PL_FPDF_BATCH;
/
```

---

## 5. SQL Pipelining para Performance

### Table Function para Processamento

```sql
-- Pipelined function para processar PDFs em lote
CREATE OR REPLACE FUNCTION FPDF_PROCESS_BATCH(
  p_job_id NUMBER
) RETURN T_PDF_DOCUMENT_LIST PIPELINED AS
  l_docs JSON_ARRAY_T;
  l_doc T_PDF_DOCUMENT;
BEGIN
  -- Get documents from job
  SELECT JSON_ARRAYAGG(doc_id)
  INTO l_docs
  FROM FPDF_BATCH_JOBS_DOCS
  WHERE job_id = p_job_id;

  -- Process each document
  FOR i IN 0 .. l_docs.get_size - 1 LOOP
    l_doc := T_PDF_DOCUMENT.Parse(GetPDFFromCache(l_docs.get_String(i)));

    -- Process...
    PIPE ROW(l_doc);

    -- Update progress
    UPDATE FPDF_BATCH_JOBS
    SET processed_items = processed_items + 1,
        progress_pct = ROUND((processed_items + 1) / total_items * 100)
    WHERE job_id = p_job_id;
  END LOOP;

  RETURN;
END;
/

-- Usage with SQL
SELECT *
FROM TABLE(FPDF_PROCESS_BATCH(123))
WHERE page_count > 10;
```

### Parallel Processing

```sql
-- Parallel merge using DBMS_PARALLEL_EXECUTE
CREATE OR REPLACE PROCEDURE FPDF_PARALLEL_PROCESS(
  p_job_id NUMBER,
  p_parallel_level NUMBER DEFAULT 4
) AS
  l_task_name VARCHAR2(100) := 'FPDF_TASK_' || p_job_id;
BEGIN
  -- Create task
  DBMS_PARALLEL_EXECUTE.CREATE_TASK(l_task_name);

  -- Create chunks by doc_id
  DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_SQL(
    task_name => l_task_name,
    sql_stmt  => 'SELECT doc_id FROM FPDF_BATCH_JOBS_DOCS WHERE job_id = ' || p_job_id,
    by_rowid  => FALSE
  );

  -- Run in parallel
  DBMS_PARALLEL_EXECUTE.RUN_TASK(
    task_name      => l_task_name,
    sql_stmt       => 'BEGIN PL_FPDF_BATCH.ProcessDocument(:start_id, :end_id); END;',
    language_flag  => DBMS_SQL.NATIVE,
    parallel_level => p_parallel_level
  );

  -- Cleanup
  DBMS_PARALLEL_EXECUTE.DROP_TASK(l_task_name);
END;
/
```

---

## 6. REST API Integration

### ORDS Endpoints

```sql
-- Enable ORDS for PDF operations
BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'PDF_SCHEMA',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'pdf'
  );
END;
/

-- Create PDF endpoint
BEGIN
  ORDS.DEFINE_MODULE(
    p_module_name    => 'pdf',
    p_base_path      => '/pdf/',
    p_status         => 'PUBLISHED'
  );

  -- POST /pdf/generate
  ORDS.DEFINE_TEMPLATE(
    p_module_name    => 'pdf',
    p_pattern        => 'generate'
  );

  ORDS.DEFINE_HANDLER(
    p_module_name    => 'pdf',
    p_pattern        => 'generate',
    p_method         => 'POST',
    p_source_type    => 'plsql/block',
    p_source         => '
      DECLARE
        l_pdf BLOB;
      BEGIN
        l_pdf := PL_FPDF_REST.GeneratePDF(:body);
        :status := 200;
        :content_type := ''application/pdf'';
        HTP.P(UTL_RAW.CAST_TO_VARCHAR2(l_pdf));
      END;'
  );

  -- POST /pdf/sign
  ORDS.DEFINE_TEMPLATE(
    p_module_name    => 'pdf',
    p_pattern        => 'sign'
  );

  ORDS.DEFINE_HANDLER(
    p_module_name    => 'pdf',
    p_pattern        => 'sign',
    p_method         => 'POST',
    p_source_type    => 'plsql/block',
    p_source         => '
      DECLARE
        l_signed BLOB;
      BEGIN
        l_signed := PL_FPDF_REST.SignPDF(:body);
        :status := 200;
        :content_type := ''application/pdf'';
        -- Return signed PDF
      END;'
  );
END;
/
```

---

## 7. Deploy Scripts

### install_enterprise.sql

```sql
-- PL_FPDF Enterprise Installation
-- Requires: Oracle 19c+, DBMS_CRYPTO, UTL_HTTP

SET SERVEROUTPUT ON
SET DEFINE OFF

PROMPT ================================================================================
PROMPT Installing PL_FPDF Enterprise Edition
PROMPT ================================================================================

-- 1. Create Types
PROMPT Creating Object Types...
@@types/T_PDF_OBJECT.sql
@@types/T_PDF_PAGE.sql
@@types/T_PDF_DOCUMENT.sql
@@types/T_SIGNATURE.sql
@@types/collections.sql

-- 2. Create Tables
PROMPT Creating Tables...
@@tables/FPDF_FONTS.sql
@@tables/FPDF_CERTIFICATES.sql
@@tables/FPDF_ICC_PROFILES.sql
@@tables/FPDF_CACHE.sql
@@tables/FPDF_AUDIT.sql
@@tables/FPDF_BATCH_JOBS.sql

-- 3. Create Views
PROMPT Creating Views...
@@views/V_FPDF_DOCUMENT_INFO.sql
@@views/V_FPDF_CERTIFICATES_VALID.sql

-- 4. Create Core Packages
PROMPT Creating Core Packages...
@@packages/PL_FPDF_UTIL.pks
@@packages/PL_FPDF_UTIL.pkb
@@packages/PL_FPDF_CORE.pks
@@packages/PL_FPDF_CORE.pkb
@@packages/PL_FPDF_CRYPTO.pks
@@packages/PL_FPDF_CRYPTO.pkb
@@packages/PL_FPDF_COMPRESS.pks
@@packages/PL_FPDF_COMPRESS.pkb

-- 5. Create Feature Packages
PROMPT Creating Feature Packages...
@@packages/PL_FPDF_FONTS.pks
@@packages/PL_FPDF_FONTS.pkb
@@packages/PL_FPDF_CERTS.pks
@@packages/PL_FPDF_CERTS.pkb
@@packages/PL_FPDF_BATCH.pks
@@packages/PL_FPDF_BATCH.pkb

-- 6. Create PDF 2.0 Modules
PROMPT Creating PDF 2.0 Modules...
@@packages/PL_FPDF_SIGN.pks
@@packages/PL_FPDF_SIGN.pkb
@@packages/PL_FPDF_PDFA.pks
@@packages/PL_FPDF_PDFA.pkb
@@packages/PL_FPDF_TAGGED.pks
@@packages/PL_FPDF_TAGGED.pkb

-- 7. Create Main API
PROMPT Creating Main API...
@@packages/PL_FPDF.pks
@@packages/PL_FPDF.pkb

-- 8. Load default data
PROMPT Loading Default Data...
@@data/core_fonts.sql
@@data/icc_profiles.sql

-- 9. Create Scheduler Jobs
PROMPT Creating Scheduler Jobs...
@@jobs/cache_cleanup.sql

-- 10. Verify Installation
@@verify_installation.sql

PROMPT ================================================================================
PROMPT Installation Complete!
PROMPT ================================================================================
```

### uninstall_enterprise.sql

```sql
-- PL_FPDF Enterprise Uninstallation

PROMPT Dropping packages...
DROP PACKAGE PL_FPDF;
DROP PACKAGE PL_FPDF_SIGN;
DROP PACKAGE PL_FPDF_PDFA;
DROP PACKAGE PL_FPDF_TAGGED;
DROP PACKAGE PL_FPDF_BATCH;
DROP PACKAGE PL_FPDF_CERTS;
DROP PACKAGE PL_FPDF_FONTS;
DROP PACKAGE PL_FPDF_COMPRESS;
DROP PACKAGE PL_FPDF_CRYPTO;
DROP PACKAGE PL_FPDF_CORE;
DROP PACKAGE PL_FPDF_UTIL;

PROMPT Dropping views...
DROP VIEW V_FPDF_DOCUMENT_INFO;
DROP VIEW V_FPDF_CERTIFICATES_VALID;

PROMPT Dropping tables...
DROP TABLE FPDF_BATCH_JOBS;
DROP TABLE FPDF_AUDIT;
DROP TABLE FPDF_CACHE;
DROP TABLE FPDF_ICC_PROFILES;
DROP TABLE FPDF_CERTIFICATES;
DROP TABLE FPDF_FONTS;

PROMPT Dropping types...
DROP TYPE T_SIGNATURE_LIST;
DROP TYPE T_PDF_PAGE_LIST;
DROP TYPE T_PDF_OBJECT_LIST;
DROP TYPE T_BLOB_LIST;
DROP TYPE T_NUMBER_LIST;
DROP TYPE T_SIGNATURE;
DROP TYPE T_PDF_DOCUMENT;
DROP TYPE T_PDF_PAGE;
DROP TYPE T_PDF_OBJECT;

PROMPT Uninstallation complete!
```

---

## 8. Comparacao Final

| Aspecto | Package-Only | Modular Hibrida | Enterprise |
|---------|-------------|-----------------|------------|
| **Deploy** | 2 files | 8-10 files | 20+ files |
| **Complexidade** | Baixa | Media | Alta |
| **Features** | Basico | PDF 2.0 | PDF 2.0 + Enterprise |
| **Persistencia** | Sessao | Sessao | Banco |
| **Compartilhamento** | Nao | Nao | Sim |
| **Auditoria** | Nao | Nao | Sim |
| **Batch Processing** | Nao | Limitado | Paralelo |
| **REST API** | Nao | Nao | Sim |
| **Cache** | Memoria | Memoria | Banco + Memoria |
| **Manutencao** | Facil | Media | Requer DBA |

---

## Recomendacao

| Caso de Uso | Arquitetura Recomendada |
|-------------|------------------------|
| PDFs simples, deploy rapido | Package-Only |
| PDF 2.0, assinaturas, PDF/A | Modular Hibrida |
| Ambiente corporativo, auditoria, REST | Enterprise |
| Processamento em lote massivo | Enterprise |

Para **v4.0.0 com PDF 2.0**, recomendo comecar com **Modular Hibrida** e evoluir para **Enterprise** conforme necessidade.
