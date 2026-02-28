# Arquitetura Moderna - Oracle 19c/23c/26c

Este documento descreve features modernas do Oracle que podem facilitar o desenvolvimento e migracao das versoes PDF no PL_FPDF.

---

## 1. JSON Nativo (Oracle 19c+)

### Uso: Configuracao e Metadados

```sql
-- Substituir constantes hardcoded por JSON config
CREATE OR REPLACE PACKAGE PL_FPDF_CONFIG AS

  -- Configuracao por versao PDF
  gc_pdf_versions CONSTANT CLOB := '{
    "1.4": {
      "encryption": ["RC4-40", "RC4-128"],
      "compression": ["FlateDecode", "LZWDecode"],
      "features": ["basic_fonts", "images", "links"]
    },
    "1.5": {
      "encryption": ["RC4-128", "AES-128"],
      "compression": ["FlateDecode", "JBIG2Decode"],
      "features": ["object_streams", "xref_streams", "tagged_pdf"]
    },
    "1.7": {
      "encryption": ["AES-128", "AES-256"],
      "compression": ["FlateDecode"],
      "features": ["acroforms", "bookmarks", "extensions"]
    },
    "2.0": {
      "encryption": ["AES-256"],
      "compression": ["FlateDecode"],
      "features": ["associated_files", "namespaces", "page_security"]
    }
  }';

END PL_FPDF_CONFIG;
/

-- Funcao para verificar feature
FUNCTION IsFeatureSupported(
  p_pdf_version  IN VARCHAR2,
  p_feature      IN VARCHAR2
) RETURN BOOLEAN IS
  l_json JSON_OBJECT_T;
  l_features JSON_ARRAY_T;
BEGIN
  l_json := JSON_OBJECT_T.parse(gc_pdf_versions);
  l_features := l_json.get_Object(p_pdf_version).get_Array('features');

  FOR i IN 0 .. l_features.get_size - 1 LOOP
    IF l_features.get_String(i) = p_feature THEN
      RETURN TRUE;
    END IF;
  END LOOP;

  RETURN FALSE;
END;
```

### JSON para Estrutura PDF

```sql
-- Representar objetos PDF como JSON antes de serializar
TYPE t_pdf_object IS RECORD (
  obj_num   PLS_INTEGER,
  gen_num   PLS_INTEGER,
  obj_type  VARCHAR2(50),
  content   JSON_OBJECT_T
);

-- Exemplo: Font object como JSON
l_font := JSON_OBJECT_T('{
  "Type": "/Font",
  "Subtype": "/TrueType",
  "BaseFont": "/Helvetica",
  "Encoding": "/WinAnsiEncoding"
}');

-- Serializar para PDF syntax
l_pdf_syntax := JsonToPdfObject(l_font);
-- Resultado: << /Type /Font /Subtype /TrueType /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>
```

---

## 2. Colecoes Tipadas (Oracle 19c+)

### Uso: Object Pools e Caches

```sql
-- Tipos para gestao de objetos PDF
CREATE OR REPLACE TYPE t_pdf_obj_rec AS OBJECT (
  obj_num     NUMBER,
  gen_num     NUMBER,
  obj_type    VARCHAR2(50),
  offset      NUMBER,
  content     BLOB,
  compressed  CHAR(1)
);
/

CREATE OR REPLACE TYPE t_pdf_obj_list AS TABLE OF t_pdf_obj_rec;
/

-- Package com colecao tipada
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Pool de objetos usando colecao tipada
  g_objects t_pdf_obj_list := t_pdf_obj_list();

  PROCEDURE AddObject(
    p_type    IN VARCHAR2,
    p_content IN BLOB
  ) IS
    l_obj t_pdf_obj_rec;
  BEGIN
    l_obj := t_pdf_obj_rec(
      obj_num    => g_objects.COUNT + 1,
      gen_num    => 0,
      obj_type   => p_type,
      offset     => NULL,
      content    => p_content,
      compressed => 'N'
    );
    g_objects.EXTEND;
    g_objects(g_objects.COUNT) := l_obj;
  END;

  -- Buscar objetos por tipo
  FUNCTION GetObjectsByType(p_type VARCHAR2) RETURN t_pdf_obj_list IS
    l_result t_pdf_obj_list;
  BEGIN
    SELECT VALUE(t)
    BULK COLLECT INTO l_result
    FROM TABLE(g_objects) t
    WHERE t.obj_type = p_type;

    RETURN l_result;
  END;

END PL_FPDF;
```

---

## 3. Conditional Compilation

### Uso: Versoes PDF Condicionais

```sql
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

  -- Flags de compilacao
  $IF $$PDF_VERSION >= 1.5 $THEN
    gc_supports_aes128 CONSTANT BOOLEAN := TRUE;
    gc_supports_objstm CONSTANT BOOLEAN := TRUE;
  $ELSE
    gc_supports_aes128 CONSTANT BOOLEAN := FALSE;
    gc_supports_objstm CONSTANT BOOLEAN := FALSE;
  $END

  $IF $$PDF_VERSION >= 1.7 $THEN
    gc_supports_aes256 CONSTANT BOOLEAN := TRUE;
    gc_supports_sha256 CONSTANT BOOLEAN := TRUE;
  $ELSE
    gc_supports_aes256 CONSTANT BOOLEAN := FALSE;
    gc_supports_sha256 CONSTANT BOOLEAN := FALSE;
  $END

  PROCEDURE SetEncryption(
    p_algorithm IN VARCHAR2,
    p_user_pass IN VARCHAR2,
    p_owner_pass IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    CASE p_algorithm
      WHEN 'RC4-128' THEN
        EncryptRC4_128(p_user_pass, p_owner_pass);

      $IF $$PDF_VERSION >= 1.5 $THEN
      WHEN 'AES-128' THEN
        EncryptAES_128(p_user_pass, p_owner_pass);
      $END

      $IF $$PDF_VERSION >= 1.7 $THEN
      WHEN 'AES-256' THEN
        EncryptAES_256(p_user_pass, p_owner_pass);
      $END

      ELSE
        RAISE_APPLICATION_ERROR(-20001,
          'Encryption ' || p_algorithm || ' not supported in PDF ' || $$PDF_VERSION);
    END CASE;
  END;

END PL_FPDF;

-- Compilar com versao especifica
ALTER PACKAGE PL_FPDF COMPILE BODY PLSQL_CCFLAGS='PDF_VERSION:1.7';
```

---

## 4. Polimorfismo com Object Types

### Uso: Strategy Pattern para Versoes

```sql
-- Tipo base para encoder
CREATE OR REPLACE TYPE t_pdf_encoder AS OBJECT (
  pdf_version VARCHAR2(10),

  -- Metodos abstratos
  NOT INSTANTIABLE MEMBER FUNCTION encode_object(
    p_content IN BLOB
  ) RETURN BLOB,

  NOT INSTANTIABLE MEMBER FUNCTION encode_xref RETURN CLOB,

  NOT INSTANTIABLE MEMBER FUNCTION get_trailer RETURN CLOB

) NOT FINAL NOT INSTANTIABLE;
/

-- Encoder PDF 1.4 (tradicional)
CREATE OR REPLACE TYPE t_pdf14_encoder UNDER t_pdf_encoder (

  OVERRIDING MEMBER FUNCTION encode_object(
    p_content IN BLOB
  ) RETURN BLOB,

  OVERRIDING MEMBER FUNCTION encode_xref RETURN CLOB,

  OVERRIDING MEMBER FUNCTION get_trailer RETURN CLOB

);
/

-- Encoder PDF 1.5+ (object streams)
CREATE OR REPLACE TYPE t_pdf15_encoder UNDER t_pdf_encoder (
  use_objstm   CHAR(1),  -- Usar object streams
  use_xrefstm  CHAR(1),  -- Usar xref streams

  OVERRIDING MEMBER FUNCTION encode_object(
    p_content IN BLOB
  ) RETURN BLOB,

  OVERRIDING MEMBER FUNCTION encode_xref RETURN CLOB,

  OVERRIDING MEMBER FUNCTION get_trailer RETURN CLOB

);
/

-- Factory para criar encoder correto
CREATE OR REPLACE FUNCTION GetPdfEncoder(
  p_version IN VARCHAR2
) RETURN t_pdf_encoder IS
BEGIN
  RETURN CASE
    WHEN p_version = '1.4' THEN
      t_pdf14_encoder(p_version)
    WHEN p_version IN ('1.5', '1.6') THEN
      t_pdf15_encoder(p_version, 'Y', 'Y')
    WHEN p_version = '1.7' THEN
      t_pdf17_encoder(p_version, 'Y', 'Y', 'Y')
    WHEN p_version = '2.0' THEN
      t_pdf20_encoder(p_version, 'Y', 'Y', 'Y', 'Y')
  END;
END;
```

---

## 5. PL/SQL Result Cache

### Uso: Cache de Fontes e Metricas

```sql
-- Cache de metricas de fonte
FUNCTION GetFontMetrics(
  p_font_name IN VARCHAR2
) RETURN JSON_OBJECT_T
RESULT_CACHE RELIES_ON (pl_fpdf_fonts)
IS
  l_metrics JSON_OBJECT_T;
BEGIN
  -- Lookup em tabela ou arquivo
  SELECT JSON_OBJECT(
    'ascender'  VALUE ascender,
    'descender' VALUE descender,
    'widths'    VALUE char_widths
  )
  INTO l_metrics
  FROM pl_fpdf_fonts
  WHERE font_name = p_font_name;

  RETURN l_metrics;
END;

-- Cache de glifos Unicode
FUNCTION GetGlyphId(
  p_font_name IN VARCHAR2,
  p_char_code IN PLS_INTEGER
) RETURN PLS_INTEGER
RESULT_CACHE
IS
BEGIN
  -- Lookup no cmap da fonte
  RETURN GetCmapEntry(p_font_name, p_char_code);
END;
```

---

## 6. UTL_COMPRESS Melhorado

### Uso: Compressao de Streams

```sql
-- Wrapper para compressao com fallback
FUNCTION CompressStream(
  p_data       IN BLOB,
  p_algorithm  IN VARCHAR2 DEFAULT 'DEFLATE'
) RETURN BLOB IS
  l_result BLOB;
BEGIN
  CASE p_algorithm
    WHEN 'DEFLATE' THEN
      -- FlateDecode (padrao PDF)
      l_result := UTL_COMPRESS.LZ_COMPRESS(p_data);
      -- Remover header/trailer zlib para raw deflate
      l_result := StripZlibWrapper(l_result);

    WHEN 'GZIP' THEN
      l_result := UTL_COMPRESS.LZ_COMPRESS(p_data, quality => 9);

    WHEN 'NONE' THEN
      l_result := p_data;

  END CASE;

  RETURN l_result;
END;

-- Estatisticas de compressao
PROCEDURE GetCompressionStats(
  p_original    IN BLOB,
  p_compressed  IN BLOB,
  p_ratio       OUT NUMBER,
  p_saved_bytes OUT NUMBER
) IS
BEGIN
  p_saved_bytes := DBMS_LOB.GETLENGTH(p_original) - DBMS_LOB.GETLENGTH(p_compressed);
  p_ratio := 1 - (DBMS_LOB.GETLENGTH(p_compressed) / DBMS_LOB.GETLENGTH(p_original));
END;
```

---

## 7. DBMS_CRYPTO Moderno

### Uso: Encryption por Versao PDF

```sql
-- Encryption manager com suporte a multiplos algoritmos
CREATE OR REPLACE PACKAGE PL_FPDF_CRYPTO AS

  -- Constantes por versao
  gc_rc4_128  CONSTANT PLS_INTEGER := DBMS_CRYPTO.ENCRYPT_RC4;
  gc_aes_128  CONSTANT PLS_INTEGER := DBMS_CRYPTO.ENCRYPT_AES128 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5;
  gc_aes_256  CONSTANT PLS_INTEGER := DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5;

  -- Hash algorithms
  gc_md5     CONSTANT PLS_INTEGER := DBMS_CRYPTO.HASH_MD5;
  gc_sha256  CONSTANT PLS_INTEGER := DBMS_CRYPTO.HASH_SH256;
  gc_sha384  CONSTANT PLS_INTEGER := DBMS_CRYPTO.HASH_SH384;
  gc_sha512  CONSTANT PLS_INTEGER := DBMS_CRYPTO.HASH_SH512;

  TYPE t_encryption_config IS RECORD (
    algorithm      PLS_INTEGER,
    hash_algorithm PLS_INTEGER,
    key_length     PLS_INTEGER,
    iv_length      PLS_INTEGER,
    pdf_v          PLS_INTEGER,  -- /V value
    pdf_r          PLS_INTEGER   -- /R value
  );

  -- Obter config por versao
  FUNCTION GetEncryptionConfig(
    p_pdf_version IN VARCHAR2,
    p_algorithm   IN VARCHAR2
  ) RETURN t_encryption_config;

  -- Encrypt com config
  FUNCTION Encrypt(
    p_data   IN BLOB,
    p_key    IN RAW,
    p_config IN t_encryption_config
  ) RETURN BLOB;

END PL_FPDF_CRYPTO;
/

CREATE OR REPLACE PACKAGE BODY PL_FPDF_CRYPTO AS

  FUNCTION GetEncryptionConfig(
    p_pdf_version IN VARCHAR2,
    p_algorithm   IN VARCHAR2
  ) RETURN t_encryption_config IS
    l_config t_encryption_config;
  BEGIN
    CASE p_algorithm
      WHEN 'RC4-128' THEN
        l_config := t_encryption_config(
          algorithm      => gc_rc4_128,
          hash_algorithm => gc_md5,
          key_length     => 128,
          iv_length      => 0,
          pdf_v          => 2,
          pdf_r          => 3
        );

      WHEN 'AES-128' THEN
        l_config := t_encryption_config(
          algorithm      => gc_aes_128,
          hash_algorithm => gc_md5,
          key_length     => 128,
          iv_length      => 16,
          pdf_v          => 4,
          pdf_r          => 4
        );

      WHEN 'AES-256' THEN
        l_config := t_encryption_config(
          algorithm      => gc_aes_256,
          hash_algorithm => CASE
            WHEN p_pdf_version = '2.0' THEN gc_sha512
            ELSE gc_sha256
          END,
          key_length     => 256,
          iv_length      => 16,
          pdf_v          => CASE WHEN p_pdf_version = '2.0' THEN 6 ELSE 5 END,
          pdf_r          => CASE WHEN p_pdf_version = '2.0' THEN 6 ELSE 5 END
        );
    END CASE;

    RETURN l_config;
  END;

  FUNCTION Encrypt(
    p_data   IN BLOB,
    p_key    IN RAW,
    p_config IN t_encryption_config
  ) RETURN BLOB IS
    l_iv     RAW(16);
    l_result BLOB;
  BEGIN
    -- Gerar IV para AES
    IF p_config.iv_length > 0 THEN
      l_iv := DBMS_CRYPTO.RANDOMBYTES(p_config.iv_length);
    END IF;

    -- Encrypt
    l_result := DBMS_CRYPTO.ENCRYPT(
      src => p_data,
      typ => p_config.algorithm,
      key => p_key,
      iv  => l_iv
    );

    -- Prepend IV para AES
    IF p_config.iv_length > 0 THEN
      DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
      DBMS_LOB.WRITEAPPEND(l_result, p_config.iv_length, l_iv);
      DBMS_LOB.APPEND(l_result, DBMS_CRYPTO.ENCRYPT(p_data, p_config.algorithm, p_key, l_iv));
    END IF;

    RETURN l_result;
  END;

END PL_FPDF_CRYPTO;
```

---

## 8. Editions-Based Redefinition (EBR)

### Uso: Versoes Paralelas em Producao

```sql
-- Criar edicao para nova versao
CREATE EDITION pdf_v35 AS CHILD OF pdf_v34;

-- Alterar sessao para nova edicao
ALTER SESSION SET EDITION = pdf_v35;

-- Package na nova edicao (nao afeta producao)
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS
  -- Nova implementacao AES-256
  ...
END;
/

-- Testar na nova edicao
BEGIN
  PL_FPDF.SetEncryption('AES-256', 'test');
  -- Testes...
END;

-- Promover para producao
ALTER SESSION SET EDITION = ora$base;
-- ... migrar gradualmente usuarios
```

---

## 9. Oracle 23c+ Features

### Boolean Nativo (23c+)

```sql
-- Antes (19c)
PROCEDURE SetTagged(p_enabled IN VARCHAR2) IS  -- 'Y'/'N'
BEGIN
  g_tagged := (p_enabled = 'Y');
END;

-- Depois (23c+)
PROCEDURE SetTagged(p_enabled IN BOOLEAN) IS
BEGIN
  g_tagged := p_enabled;
END;

-- Uso
PL_FPDF.SetTagged(TRUE);  -- Mais limpo!
```

### SQL Domains (23c+)

```sql
-- Definir dominio para versao PDF
CREATE DOMAIN pdf_version_d AS VARCHAR2(10)
  CHECK (VALUE IN ('1.4', '1.5', '1.6', '1.7', '2.0'));

-- Usar no package
PROCEDURE SetPDFVersion(
  p_version IN pdf_version_d
) IS
BEGIN
  g_pdf_version := p_version;
END;

-- Erro automatico se versao invalida
PL_FPDF.SetPDFVersion('1.8');  -- Erro: domain constraint violated
```

### IF NOT EXISTS (23c+)

```sql
-- Criar tabela de config apenas se nao existir
CREATE TABLE IF NOT EXISTS pl_fpdf_config (
  config_key   VARCHAR2(100) PRIMARY KEY,
  config_value JSON
);
```

---

## 10. Arquitetura Modular Proposta

```
┌─────────────────────────────────────────────────────────────┐
│                      PL_FPDF (Main API)                     │
│  fpdf(), AddPage(), Cell(), Image(), Output()               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF_VERSION                          │
│  Abstraction layer - seleciona implementacao por versao     │
│  GetEncoder(), GetEncryptor(), GetWriter()                  │
└─────────────────────────────────────────────────────────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ PDF 1.4  │   │ PDF 1.5  │   │ PDF 1.7  │   │ PDF 2.0  │
    │ Writer   │   │ Writer   │   │ Writer   │   │ Writer   │
    └──────────┘   └──────────┘   └──────────┘   └──────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF_CRYPTO                           │
│  RC4-128, AES-128, AES-256, Key Derivation                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF_COMPRESS                         │
│  FlateDecode, Object Streams, XRef Streams                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PL_FPDF_FONTS                            │
│  TrueType, OpenType, CIDFont, ToUnicode                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 11. Matriz de Compatibilidade Oracle

| Feature | 19c | 21c | 23c | 26c |
|---------|-----|-----|-----|-----|
| JSON_OBJECT_T | ✅ | ✅ | ✅ | ✅ |
| RESULT_CACHE | ✅ | ✅ | ✅ | ✅ |
| Conditional Compilation | ✅ | ✅ | ✅ | ✅ |
| Object Types | ✅ | ✅ | ✅ | ✅ |
| DBMS_CRYPTO AES-256 | ✅ | ✅ | ✅ | ✅ |
| UTL_COMPRESS | ✅ | ✅ | ✅ | ✅ |
| EBR (Editions) | ✅ | ✅ | ✅ | ✅ |
| Boolean Params | ❌ | ❌ | ✅ | ✅ |
| SQL Domains | ❌ | ❌ | ✅ | ✅ |
| IF NOT EXISTS | ❌ | ❌ | ✅ | ✅ |
| SQL Macros | ❌ | ✅ | ✅ | ✅ |

---

## 12. Recomendacao de Implementacao

### Fase 1: Foundation (v3.3.0)
- [ ] Refatorar para usar JSON config
- [ ] Criar PL_FPDF_CRYPTO package
- [ ] Criar PL_FPDF_COMPRESS package
- [ ] Adicionar Result Cache para fontes

### Fase 2: Version Abstraction (v3.4.0)
- [ ] Criar PL_FPDF_VERSION abstraction layer
- [ ] Implementar Object Types para encoders
- [ ] Conditional Compilation para features

### Fase 3: Modularization (v3.5.0+)
- [ ] Separar packages por responsabilidade
- [ ] Usar EBR para deploy sem downtime
- [ ] 23c features com fallback 19c

---

## Beneficios da Arquitetura Moderna

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Adicionar nova versao PDF | Modificar codigo existente | Criar novo encoder |
| Mudar algoritmo crypto | Refatorar multiplos locais | Config JSON |
| Deploy nova versao | Downtime | EBR zero-downtime |
| Testar versao especifica | Dificil isolamento | Edicoes separadas |
| Performance fontes | Lookup repetido | Result Cache |
| Configuracao | Hardcoded | JSON flexivel |
