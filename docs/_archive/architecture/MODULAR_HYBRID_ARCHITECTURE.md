# Arquitetura Evoluida para PDF 2.0

**Version:** 4.0.0
**Date:** 2026-03
**Status:** Proposta

---

## Visao Geral

A arquitetura atual "Package-Only" e excelente para simplicidade, mas PDF 2.0 traz complexidade que requer evolucao. Este documento propoe uma **Arquitetura Modular Hibrida** que:

- ✅ Mantem Oracle 19c como minimo
- ✅ Mantem deploy simples (arquivos .pks/.pkb)
- ✅ Sem tabelas externas obrigatorias
- ✅ Adiciona modularidade para features complexas
- ✅ Suporta extensibilidade para PDF 2.0

---

## Comparacao: Atual vs Proposta

| Aspecto | Package-Only (Atual) | Modular Hibrida (Proposta) |
|---------|---------------------|---------------------------|
| Deploy | 2 arquivos | 2-8 arquivos (core + modulos) |
| Complexidade | Baixa | Media |
| Extensibilidade | Limitada | Alta |
| Testabilidade | Media | Alta (modulos isolados) |
| Manutencao | Dificil (arquivo grande) | Facil (modulos pequenos) |
| PDF 2.0 Ready | Nao | Sim |

---

## Arquitetura Proposta

### Estrutura de Packages

```
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF (Facade API)                     │
│  Public interface - mantem compatibilidade retroativa       │
│  fpdf(), AddPage(), Cell(), Output(), LoadPDF(), etc.       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF_CORE (Engine)                    │
│  Nucleo de geracao/parsing PDF                              │
│  Object management, XRef, Streams                           │
└─────────────────────────────────────────────────────────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ PL_FPDF_ │   │ PL_FPDF_ │   │ PL_FPDF_ │   │ PL_FPDF_ │
    │ CRYPTO   │   │ COMPRESS │   │ FONTS    │   │ IMAGES   │
    └──────────┘   └──────────┘   └──────────┘   └──────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF_UTIL (Utilities)                 │
│  Binary operations, Encoding, Checksum, etc.                │
└─────────────────────────────────────────────────────────────┘
```

### Modulos Opcionais (PDF 2.0)

```
┌─────────────────────────────────────────────────────────────┐
│                    MODULOS OPCIONAIS                        │
├─────────────────────────────────────────────────────────────┤
│  PL_FPDF_SIGN      - Digital Signatures (PKCS#7, PAdES)     │
│  PL_FPDF_PDFA      - PDF/A Compliance                       │
│  PL_FPDF_PDFUA     - PDF/UA Accessibility                   │
│  PL_FPDF_FORMS     - AcroForms                              │
│  PL_FPDF_TAGGED    - Tagged PDF / Structure Tree            │
│  PL_FPDF_EINVOICE  - ZUGFeRD / Factur-X                     │
│  PL_FPDF_MIGRATE   - Version Migration Tools                │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Package Core Refatorado

### PL_FPDF.pks (Facade - Mantem API Atual)

```sql
CREATE OR REPLACE PACKAGE PL_FPDF AS
  /*
   * PL_FPDF v4.0.0 - PDF Generation & Manipulation
   *
   * This is the PUBLIC API - maintains backward compatibility
   * Internal implementation delegated to subpackages
   */

  -- Version info
  FUNCTION GetVersion RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION GetPDFVersion RETURN VARCHAR2;

  -- Lifecycle (delegates to PL_FPDF_CORE)
  PROCEDURE Init(
    p_orientation VARCHAR2 DEFAULT 'P',
    p_unit VARCHAR2 DEFAULT 'mm',
    p_format VARCHAR2 DEFAULT 'A4'
  );
  PROCEDURE Reset;
  FUNCTION IsInitialized RETURN BOOLEAN;

  -- Page Management (delegates to PL_FPDF_CORE)
  PROCEDURE AddPage(p_orientation VARCHAR2 DEFAULT NULL);
  PROCEDURE SetPage(p_page_number PLS_INTEGER);
  FUNCTION GetPageCount RETURN PLS_INTEGER;

  -- Content (delegates to PL_FPDF_CORE)
  PROCEDURE Cell(pw NUMBER, ph NUMBER DEFAULT 0, ptxt VARCHAR2 DEFAULT '');
  PROCEDURE MultiCell(pw NUMBER, ph NUMBER, ptxt VARCHAR2);
  PROCEDURE Image(pfile VARCHAR2, px NUMBER, py NUMBER);

  -- Output (delegates to PL_FPDF_CORE)
  FUNCTION OutputBlob RETURN BLOB;
  PROCEDURE OutputFile(p_filename VARCHAR2, p_directory VARCHAR2);

  -- PDF Manipulation (delegates to PL_FPDF_CORE)
  PROCEDURE LoadPDF(p_pdf BLOB);
  FUNCTION MergePDFs(p_pdf_ids VARCHAR2) RETURN BLOB;
  FUNCTION SplitPDF(p_ranges VARCHAR2) RETURN JSON_ARRAY_T;

  -- Security (delegates to PL_FPDF_CRYPTO)
  PROCEDURE SetProtection(
    p_permissions JSON_OBJECT_T,
    p_user_password VARCHAR2,
    p_owner_password VARCHAR2 DEFAULT NULL,
    p_encryption VARCHAR2 DEFAULT 'AES-128'
  );

  -- PDF 2.0 Features (optional modules)
  PROCEDURE SetPDFVersion(p_version VARCHAR2);
  PROCEDURE EnableTaggedPDF(p_enabled BOOLEAN DEFAULT TRUE);
  PROCEDURE SetPDFACompliance(p_level VARCHAR2);  -- PDF/A-1b, PDF/A-3b, etc.
  PROCEDURE SetAccessibility(p_enabled BOOLEAN DEFAULT TRUE);  -- PDF/UA

END PL_FPDF;
/
```

### PL_FPDF_CORE.pks (Engine)

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_CORE AS
  /*
   * Core PDF Engine
   * Handles: Object management, XRef, Streams, Page tree
   *
   * NOT for direct user access - use PL_FPDF facade
   */

  -- Types for PDF objects
  TYPE t_pdf_object IS RECORD (
    obj_num     PLS_INTEGER,
    gen_num     PLS_INTEGER,
    obj_type    VARCHAR2(50),
    content     CLOB,
    stream      BLOB,
    compressed  BOOLEAN DEFAULT FALSE
  );

  TYPE t_pdf_object_list IS TABLE OF t_pdf_object INDEX BY PLS_INTEGER;

  TYPE t_xref_entry IS RECORD (
    offset      PLS_INTEGER,
    generation  PLS_INTEGER,
    in_use      BOOLEAN DEFAULT TRUE
  );

  TYPE t_xref_table IS TABLE OF t_xref_entry INDEX BY PLS_INTEGER;

  -- PDF Version management
  PROCEDURE SetVersion(p_version VARCHAR2);
  FUNCTION GetVersion RETURN VARCHAR2;
  FUNCTION GetMinimumVersion RETURN VARCHAR2;

  -- Object management
  FUNCTION CreateObject(p_type VARCHAR2, p_content CLOB) RETURN PLS_INTEGER;
  PROCEDURE UpdateObject(p_obj_num PLS_INTEGER, p_content CLOB);
  FUNCTION GetObject(p_obj_num PLS_INTEGER) RETURN t_pdf_object;
  PROCEDURE DeleteObject(p_obj_num PLS_INTEGER);

  -- Stream management
  FUNCTION CreateStream(p_data BLOB, p_compress BOOLEAN DEFAULT TRUE) RETURN PLS_INTEGER;
  FUNCTION GetStreamData(p_obj_num PLS_INTEGER) RETURN BLOB;

  -- XRef management
  PROCEDURE BuildXRef;
  FUNCTION GetXRefTable RETURN t_xref_table;

  -- PDF 2.0: Object Streams
  FUNCTION CreateObjectStream(p_objects t_pdf_object_list) RETURN PLS_INTEGER;

  -- PDF 2.0: XRef Streams
  FUNCTION CreateXRefStream RETURN PLS_INTEGER;

  -- Serialization
  FUNCTION Serialize RETURN BLOB;

END PL_FPDF_CORE;
/
```

---

## 2. Modulos Especializados

### PL_FPDF_CRYPTO.pks

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_CRYPTO AS
  /*
   * Cryptographic operations for PDF
   * Supports: RC4, AES-128, AES-256 (PDF 2.0)
   * Uses: DBMS_CRYPTO
   */

  -- Encryption levels
  c_rc4_40    CONSTANT VARCHAR2(10) := 'RC4-40';
  c_rc4_128   CONSTANT VARCHAR2(10) := 'RC4-128';
  c_aes_128   CONSTANT VARCHAR2(10) := 'AES-128';
  c_aes_256   CONSTANT VARCHAR2(10) := 'AES-256';

  -- Configuration record
  TYPE t_encryption_config IS RECORD (
    algorithm       VARCHAR2(20),
    key_length      PLS_INTEGER,
    pdf_v           PLS_INTEGER,  -- /V value
    pdf_r           PLS_INTEGER,  -- /R value
    use_aes         BOOLEAN,
    metadata_encrypted BOOLEAN DEFAULT TRUE
  );

  -- Get config by algorithm
  FUNCTION GetConfig(p_algorithm VARCHAR2) RETURN t_encryption_config;

  -- Key derivation (PDF spec algorithms)
  FUNCTION DeriveKey(
    p_password  VARCHAR2,
    p_o_value   RAW,
    p_p_value   PLS_INTEGER,
    p_id        RAW,
    p_key_length PLS_INTEGER,
    p_revision  PLS_INTEGER
  ) RETURN RAW;

  -- Compute O value (owner password hash)
  FUNCTION ComputeOValue(
    p_owner_password VARCHAR2,
    p_user_password VARCHAR2,
    p_key_length PLS_INTEGER,
    p_revision PLS_INTEGER
  ) RETURN RAW;

  -- Compute U value (user password hash)
  FUNCTION ComputeUValue(
    p_password VARCHAR2,
    p_o_value RAW,
    p_permissions PLS_INTEGER,
    p_id RAW,
    p_key_length PLS_INTEGER,
    p_revision PLS_INTEGER
  ) RETURN RAW;

  -- PDF 2.0: AES-256 specific
  FUNCTION ComputeUE(p_key RAW, p_u_value RAW) RETURN RAW;
  FUNCTION ComputeOE(p_key RAW, p_o_value RAW) RETURN RAW;
  FUNCTION ComputePerms(p_key RAW, p_permissions PLS_INTEGER) RETURN RAW;

  -- Encrypt/Decrypt
  FUNCTION Encrypt(p_data BLOB, p_key RAW, p_algorithm VARCHAR2) RETURN BLOB;
  FUNCTION Decrypt(p_data BLOB, p_key RAW, p_algorithm VARCHAR2) RETURN BLOB;

  -- Encrypt PDF object
  FUNCTION EncryptObject(
    p_obj_num PLS_INTEGER,
    p_gen_num PLS_INTEGER,
    p_data BLOB,
    p_key RAW,
    p_algorithm VARCHAR2
  ) RETURN BLOB;

END PL_FPDF_CRYPTO;
/
```

### PL_FPDF_COMPRESS.pks

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_COMPRESS AS
  /*
   * Compression operations for PDF streams
   * Supports: FlateDecode (zlib), LZW (legacy)
   * Uses: UTL_COMPRESS
   */

  -- Compression filters
  c_flate     CONSTANT VARCHAR2(20) := 'FlateDecode';
  c_lzw       CONSTANT VARCHAR2(20) := 'LZWDecode';  -- Deprecated PDF 2.0
  c_none      CONSTANT VARCHAR2(20) := 'None';

  -- Compress stream
  FUNCTION Compress(
    p_data BLOB,
    p_filter VARCHAR2 DEFAULT c_flate,
    p_level PLS_INTEGER DEFAULT 6
  ) RETURN BLOB;

  -- Decompress stream
  FUNCTION Decompress(
    p_data BLOB,
    p_filter VARCHAR2
  ) RETURN BLOB;

  -- Get compression stats
  FUNCTION GetCompressionRatio(
    p_original_size PLS_INTEGER,
    p_compressed_size PLS_INTEGER
  ) RETURN NUMBER;

  -- PDF 2.0: Predictor support
  FUNCTION ApplyPredictor(
    p_data BLOB,
    p_predictor PLS_INTEGER,
    p_columns PLS_INTEGER,
    p_colors PLS_INTEGER DEFAULT 1,
    p_bits_per_component PLS_INTEGER DEFAULT 8
  ) RETURN BLOB;

END PL_FPDF_COMPRESS;
/
```

---

## 3. Modulos PDF 2.0 Opcionais

### PL_FPDF_SIGN.pks (Digital Signatures)

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_SIGN AS
  /*
   * Digital Signatures for PDF
   * Supports: PKCS#7, PAdES-B, PAdES-T, PAdES-LT, PAdES-LTA
   *
   * OPTIONAL MODULE - Only needed for signing PDFs
   */

  -- Signature levels
  c_pkcs7_detached  CONSTANT VARCHAR2(30) := 'adbe.pkcs7.detached';
  c_pades_basic     CONSTANT VARCHAR2(30) := 'ETSI.CAdES.detached';

  -- Configuration
  TYPE t_signature_config IS RECORD (
    certificate     BLOB,           -- X.509 certificate
    private_key     BLOB,           -- Private key (encrypted)
    key_password    VARCHAR2(100),  -- Key decryption password
    reason          VARCHAR2(500),
    location        VARCHAR2(500),
    contact_info    VARCHAR2(500),
    timestamp_url   VARCHAR2(500),  -- TSA URL for PAdES-T
    include_chain   BOOLEAN DEFAULT TRUE
  );

  -- Sign PDF
  FUNCTION SignPDF(
    p_pdf BLOB,
    p_config t_signature_config,
    p_level VARCHAR2 DEFAULT c_pkcs7_detached
  ) RETURN BLOB;

  -- Add signature field (for visual signature)
  PROCEDURE AddSignatureField(
    p_name VARCHAR2,
    p_page PLS_INTEGER,
    p_x NUMBER,
    p_y NUMBER,
    p_width NUMBER,
    p_height NUMBER,
    p_appearance BLOB DEFAULT NULL  -- Signature image
  );

  -- Validate signature
  FUNCTION ValidateSignature(
    p_pdf BLOB,
    p_signature_index PLS_INTEGER DEFAULT 1
  ) RETURN JSON_OBJECT_T;

  -- Get signature info
  FUNCTION GetSignatureInfo(p_pdf BLOB) RETURN JSON_ARRAY_T;

  -- PAdES-LTV: Add validation info
  PROCEDURE AddValidationInfo(
    p_pdf IN OUT BLOB,
    p_crls JSON_ARRAY_T,
    p_ocsps JSON_ARRAY_T
  );

END PL_FPDF_SIGN;
/
```

### PL_FPDF_PDFA.pks (PDF/A Compliance)

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_PDFA AS
  /*
   * PDF/A Compliance Generator
   * Supports: PDF/A-1b, PDF/A-2b, PDF/A-3b, PDF/A-4
   *
   * OPTIONAL MODULE - Only needed for archival PDFs
   */

  -- Compliance levels
  c_pdfa_1a  CONSTANT VARCHAR2(10) := 'PDF/A-1a';
  c_pdfa_1b  CONSTANT VARCHAR2(10) := 'PDF/A-1b';
  c_pdfa_2a  CONSTANT VARCHAR2(10) := 'PDF/A-2a';
  c_pdfa_2b  CONSTANT VARCHAR2(10) := 'PDF/A-2b';
  c_pdfa_3a  CONSTANT VARCHAR2(10) := 'PDF/A-3a';
  c_pdfa_3b  CONSTANT VARCHAR2(10) := 'PDF/A-3b';
  c_pdfa_4   CONSTANT VARCHAR2(10) := 'PDF/A-4';   -- PDF 2.0 based

  -- Set compliance level
  PROCEDURE SetComplianceLevel(p_level VARCHAR2);

  -- Get current level
  FUNCTION GetComplianceLevel RETURN VARCHAR2;

  -- Validate PDF for compliance
  FUNCTION Validate(p_pdf BLOB, p_level VARCHAR2) RETURN JSON_OBJECT_T;

  -- Convert to PDF/A
  FUNCTION ConvertToPDFA(
    p_pdf BLOB,
    p_level VARCHAR2 DEFAULT c_pdfa_3b,
    p_fix_issues BOOLEAN DEFAULT TRUE
  ) RETURN BLOB;

  -- XMP Metadata (required for PDF/A)
  FUNCTION GenerateXMPMetadata(
    p_title VARCHAR2,
    p_author VARCHAR2,
    p_subject VARCHAR2,
    p_keywords VARCHAR2,
    p_creator VARCHAR2,
    p_pdfa_level VARCHAR2
  ) RETURN CLOB;

  -- ICC Color Profile (required for PDF/A)
  PROCEDURE EmbedICCProfile(p_profile_name VARCHAR2 DEFAULT 'sRGB');

  -- PDF/A-3: Associated files
  PROCEDURE AddAssociatedFile(
    p_filename VARCHAR2,
    p_content BLOB,
    p_mime_type VARCHAR2,
    p_relationship VARCHAR2 DEFAULT 'Data'  -- Data, Source, Alternative
  );

END PL_FPDF_PDFA;
/
```

### PL_FPDF_TAGGED.pks (Tagged PDF / Structure Tree)

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_TAGGED AS
  /*
   * Tagged PDF for Accessibility
   * Implements: PDF Structure Tree, Standard Tags
   *
   * OPTIONAL MODULE - Needed for PDF/UA and accessibility
   */

  -- Standard structure types
  c_document   CONSTANT VARCHAR2(20) := 'Document';
  c_part       CONSTANT VARCHAR2(20) := 'Part';
  c_sect       CONSTANT VARCHAR2(20) := 'Sect';
  c_div        CONSTANT VARCHAR2(20) := 'Div';
  c_h1         CONSTANT VARCHAR2(20) := 'H1';
  c_h2         CONSTANT VARCHAR2(20) := 'H2';
  c_h3         CONSTANT VARCHAR2(20) := 'H3';
  c_p          CONSTANT VARCHAR2(20) := 'P';
  c_table      CONSTANT VARCHAR2(20) := 'Table';
  c_tr         CONSTANT VARCHAR2(20) := 'TR';
  c_th         CONSTANT VARCHAR2(20) := 'TH';
  c_td         CONSTANT VARCHAR2(20) := 'TD';
  c_figure     CONSTANT VARCHAR2(20) := 'Figure';
  c_link       CONSTANT VARCHAR2(20) := 'Link';
  c_span       CONSTANT VARCHAR2(20) := 'Span';

  -- Enable tagging
  PROCEDURE EnableTagging(p_enabled BOOLEAN DEFAULT TRUE);

  -- Structure tree operations
  FUNCTION BeginTag(
    p_tag_type VARCHAR2,
    p_attributes JSON_OBJECT_T DEFAULT NULL
  ) RETURN PLS_INTEGER;  -- Returns tag ID

  PROCEDURE EndTag(p_tag_id PLS_INTEGER);

  -- Set alt text for figures
  PROCEDURE SetAltText(p_tag_id PLS_INTEGER, p_alt_text VARCHAR2);

  -- Set actual text replacement
  PROCEDURE SetActualText(p_tag_id PLS_INTEGER, p_actual_text VARCHAR2);

  -- Set language
  PROCEDURE SetLanguage(p_tag_id PLS_INTEGER, p_lang VARCHAR2);

  -- Table structure helpers
  PROCEDURE BeginTable;
  PROCEDURE BeginTableRow;
  PROCEDURE BeginTableHeader(p_scope VARCHAR2 DEFAULT 'Column');  -- Column, Row, Both
  PROCEDURE BeginTableCell;
  PROCEDURE EndTable;

  -- Generate structure tree
  FUNCTION GenerateStructureTree RETURN CLOB;

  -- PDF/UA validation
  FUNCTION ValidateAccessibility RETURN JSON_ARRAY_T;

END PL_FPDF_TAGGED;
/
```

---

## 4. Estrategia de Deploy

### Opcao 1: Minimal (Apenas Core)

```bash
# Deploy basico - funcionalidade v3.x
sqlplus user/pass@db <<EOF
@PL_FPDF.pks
@PL_FPDF.pkb
EOF

# Inclui internamente:
# - PL_FPDF_CORE (embutido no body)
# - PL_FPDF_UTIL (embutido no body)
```

### Opcao 2: Standard (Core + Security)

```bash
# Deploy com criptografia completa
sqlplus user/pass@db <<EOF
@PL_FPDF.pks
@PL_FPDF.pkb
@PL_FPDF_CRYPTO.pks
@PL_FPDF_CRYPTO.pkb
@PL_FPDF_COMPRESS.pks
@PL_FPDF_COMPRESS.pkb
EOF
```

### Opcao 3: Full (PDF 2.0 Complete)

```bash
# Deploy completo para PDF 2.0
sqlplus user/pass@db <<EOF
# Core
@PL_FPDF.pks
@PL_FPDF.pkb
@PL_FPDF_CORE.pks
@PL_FPDF_CORE.pkb
@PL_FPDF_UTIL.pks
@PL_FPDF_UTIL.pkb

# Security & Compression
@PL_FPDF_CRYPTO.pks
@PL_FPDF_CRYPTO.pkb
@PL_FPDF_COMPRESS.pks
@PL_FPDF_COMPRESS.pkb

# PDF 2.0 Modules
@PL_FPDF_SIGN.pks
@PL_FPDF_SIGN.pkb
@PL_FPDF_PDFA.pks
@PL_FPDF_PDFA.pkb
@PL_FPDF_TAGGED.pks
@PL_FPDF_TAGGED.pkb
@PL_FPDF_PDFUA.pks
@PL_FPDF_PDFUA.pkb
EOF
```

---

## 5. Padroes de Design

### 5.1 Strategy Pattern (Versoes PDF)

```sql
-- Interface para writers de diferentes versoes
CREATE OR REPLACE PACKAGE PL_FPDF_WRITER AS

  TYPE t_writer_interface IS RECORD (
    write_header     VARCHAR2(100),  -- Nome da procedure
    write_xref       VARCHAR2(100),
    write_trailer    VARCHAR2(100),
    version          VARCHAR2(10)
  );

  -- Factory
  FUNCTION GetWriter(p_version VARCHAR2) RETURN t_writer_interface;

  -- Implementations
  PROCEDURE WriteHeader_14(p_buffer IN OUT CLOB);
  PROCEDURE WriteHeader_15(p_buffer IN OUT CLOB);
  PROCEDURE WriteHeader_17(p_buffer IN OUT CLOB);
  PROCEDURE WriteHeader_20(p_buffer IN OUT CLOB);

  PROCEDURE WriteXRef_14(p_buffer IN OUT CLOB);  -- Traditional xref
  PROCEDURE WriteXRef_15(p_buffer IN OUT CLOB);  -- XRef stream
  PROCEDURE WriteXRef_20(p_buffer IN OUT CLOB);  -- XRef stream mandatory

END PL_FPDF_WRITER;
/
```

### 5.2 Builder Pattern (PDF Construction)

```sql
-- Fluent builder para criar PDFs
CREATE OR REPLACE PACKAGE PL_FPDF_BUILDER AS

  -- Builder chain
  FUNCTION Create RETURN PL_FPDF_BUILDER;
  FUNCTION WithVersion(p_version VARCHAR2) RETURN PL_FPDF_BUILDER;
  FUNCTION WithCompression(p_enabled BOOLEAN) RETURN PL_FPDF_BUILDER;
  FUNCTION WithEncryption(p_algorithm VARCHAR2, p_password VARCHAR2) RETURN PL_FPDF_BUILDER;
  FUNCTION WithPDFACompliance(p_level VARCHAR2) RETURN PL_FPDF_BUILDER;
  FUNCTION WithAccessibility(p_enabled BOOLEAN) RETURN PL_FPDF_BUILDER;
  FUNCTION WithMetadata(p_metadata JSON_OBJECT_T) RETURN PL_FPDF_BUILDER;

  -- Build
  PROCEDURE Build;

  -- Usage example:
  -- PL_FPDF_BUILDER.Create()
  --   .WithVersion('2.0')
  --   .WithEncryption('AES-256', 'password')
  --   .WithPDFACompliance('PDF/A-3b')
  --   .Build();

END PL_FPDF_BUILDER;
/
```

### 5.3 Observer Pattern (Events)

```sql
-- Eventos para extensibilidade
CREATE OR REPLACE PACKAGE PL_FPDF_EVENTS AS

  -- Event types
  c_before_page   CONSTANT VARCHAR2(20) := 'BEFORE_PAGE';
  c_after_page    CONSTANT VARCHAR2(20) := 'AFTER_PAGE';
  c_before_output CONSTANT VARCHAR2(20) := 'BEFORE_OUTPUT';
  c_after_output  CONSTANT VARCHAR2(20) := 'AFTER_OUTPUT';
  c_on_error      CONSTANT VARCHAR2(20) := 'ON_ERROR';

  -- Callback type
  TYPE t_callback IS RECORD (
    event_type     VARCHAR2(20),
    callback_name  VARCHAR2(100),  -- Procedure name to call
    enabled        BOOLEAN DEFAULT TRUE
  );

  TYPE t_callbacks IS TABLE OF t_callback INDEX BY PLS_INTEGER;

  -- Register/unregister
  PROCEDURE RegisterCallback(
    p_event VARCHAR2,
    p_callback VARCHAR2
  );

  PROCEDURE UnregisterCallback(
    p_event VARCHAR2,
    p_callback VARCHAR2
  );

  -- Fire event
  PROCEDURE FireEvent(
    p_event VARCHAR2,
    p_context JSON_OBJECT_T DEFAULT NULL
  );

END PL_FPDF_EVENTS;
/
```

---

## 6. Compatibilidade Retroativa

### API Compatibility Layer

```sql
-- v3.x API calls automatically work in v4.x
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  PROCEDURE fpdf(
    p_orientation VARCHAR2 DEFAULT 'P',
    p_unit VARCHAR2 DEFAULT 'mm',
    p_format VARCHAR2 DEFAULT 'A4'
  ) IS
  BEGIN
    -- Delegate to new Init
    Init(p_orientation, p_unit, p_format);
  END;

  FUNCTION ReturnBlob(
    pname VARCHAR2 DEFAULT NULL,
    pdest VARCHAR2 DEFAULT NULL
  ) RETURN BLOB IS
  BEGIN
    -- Delegate to new OutputBlob
    RETURN OutputBlob();
  END;

  -- All legacy methods delegate to new implementation

END PL_FPDF;
/
```

---

## 7. Beneficios da Nova Arquitetura

| Aspecto | Package-Only | Modular Hibrida |
|---------|-------------|-----------------|
| **Testabilidade** | Teste do package inteiro | Teste por modulo isolado |
| **Manutencao** | 1 arquivo grande | Modulos pequenos focados |
| **Extensibilidade** | Modificar package principal | Adicionar novo modulo |
| **Performance** | Carrega tudo | Carrega sob demanda |
| **Complexidade** | Cresce exponencialmente | Linear por modulo |
| **Team Development** | Conflitos frequentes | Trabalho paralelo |
| **Debug** | Stack trace longo | Stack trace claro |

---

## 8. Migracao Gradual

### Fase 1 (v3.3.0): Extrair Crypto

```
PL_FPDF.pkb (atual)
    ↓
PL_FPDF.pkb + PL_FPDF_CRYPTO.pkb
```

### Fase 2 (v3.4.0): Extrair Compress

```
PL_FPDF.pkb + PL_FPDF_CRYPTO.pkb
    ↓
+ PL_FPDF_COMPRESS.pkb
```

### Fase 3 (v3.5.0): Criar Core

```
PL_FPDF.pkb (facade)
PL_FPDF_CORE.pkb (engine)
PL_FPDF_CRYPTO.pkb
PL_FPDF_COMPRESS.pkb
```

### Fase 4 (v4.0.0): Modulos PDF 2.0

```
+ PL_FPDF_SIGN.pkb
+ PL_FPDF_PDFA.pkb
+ PL_FPDF_TAGGED.pkb
+ PL_FPDF_PDFUA.pkb
```

---

## 9. Checklist de Implementacao

### Core Refactoring

- [ ] Extrair PL_FPDF_CRYPTO de PL_FPDF.pkb
- [ ] Extrair PL_FPDF_COMPRESS de PL_FPDF.pkb
- [ ] Criar PL_FPDF_CORE com object management
- [ ] Criar PL_FPDF_UTIL com funcoes utilitarias
- [ ] Atualizar PL_FPDF como facade
- [ ] Manter compatibilidade retroativa

### PDF 2.0 Modules

- [ ] PL_FPDF_SIGN para assinaturas digitais
- [ ] PL_FPDF_PDFA para compliance PDF/A
- [ ] PL_FPDF_TAGGED para estrutura de tags
- [ ] PL_FPDF_PDFUA para acessibilidade
- [ ] PL_FPDF_FORMS para AcroForms
- [ ] PL_FPDF_MIGRATE para migracao de versao

### Testing

- [ ] Testes unitarios por modulo
- [ ] Testes de integracao
- [ ] Testes de regressao
- [ ] Benchmarks de performance

---

## Conclusao

A **Arquitetura Modular Hibrida** permite:

1. **Evoluir gradualmente** sem quebrar codigo existente
2. **Adicionar features PDF 2.0** como modulos opcionais
3. **Manter deploy simples** para casos basicos
4. **Escalar complexidade** conforme necessidade
5. **Desenvolver em paralelo** por diferentes contribuidores

A migracao pode ser feita **incrementalmente** atraves das versoes v3.3 → v3.4 → v3.5 → v4.0.
