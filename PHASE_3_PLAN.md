# Fase 3 - Modernização e Features Avançadas

**Data de Início:** 2025-12-18
**Status:** 🚀 Pronto para Iniciar
**Branch:** `claude/modernize-pdf-oracle-dVui6`
**Prioridade:** P2-P3 (Desejável/Opcional)

---

## 🎯 Objetivos da Fase 3

1. **Modernizar código** para usar features Oracle 19c/23c
2. **Adicionar suporte JSON** para integração moderna
3. **Implementar parsing nativo** de imagens (remover dependências)
4. **Adicionar testes unitários** com utPLSQL
5. **Documentar completamente** APIs e migration path
6. **Otimizar performance** com features avançadas do Oracle

---

## 📋 Tasks da Fase 3

### 🔧 Task 3.1: Modernizar Estrutura de Código
**Prioridade:** P2 (Desejável)
**Esforço:** Médio
**Tempo Estimado:** 2-3 dias

#### Descrição
Refatorar código para usar features modernas do Oracle 19c/23c:
- Usar `CONSTANT` para valores fixos
- Adicionar `DETERMINISTIC` em funções puras
- Implementar `RESULT_CACHE` para lookups
- Simplificar tipos com validação inline

#### Mudanças Específicas

**1. Adicionar Constantes (CONSTANT)**
```sql
-- No package body (PL_FPDF.pkb)
c_PDF_VERSION CONSTANT VARCHAR2(10) := '1.3';
c_MAX_PAGE_WIDTH CONSTANT NUMBER := 10000;
c_MAX_PAGE_HEIGHT CONSTANT NUMBER := 10000;
c_DEFAULT_FONT_SIZE CONSTANT NUMBER := 12;
c_MIN_FONT_SIZE CONSTANT NUMBER := 1;
c_MAX_FONT_SIZE CONSTANT NUMBER := 999;
c_MIN_LINE_WIDTH CONSTANT NUMBER := 0.001;
c_MAX_LINE_WIDTH CONSTANT NUMBER := 1000;

-- Substituir magic numbers no código
-- ANTES:
IF psize < 0 OR psize > 999 THEN
-- DEPOIS:
IF psize < c_MIN_FONT_SIZE OR psize > c_MAX_FONT_SIZE THEN
```

**2. Adicionar DETERMINISTIC para funções puras**
```sql
-- Funções que sempre retornam mesmo resultado para mesma entrada

FUNCTION strtoupper(s IN VARCHAR2) RETURN VARCHAR2
DETERMINISTIC;

FUNCTION strtolower(s IN VARCHAR2) RETURN VARCHAR2
DETERMINISTIC;

FUNCTION tochar(n IN NUMBER, dec IN INTEGER DEFAULT 2) RETURN VARCHAR2
DETERMINISTIC;

FUNCTION GetCurrentPage RETURN PLS_INTEGER
DETERMINISTIC;

FUNCTION GetLogLevel RETURN PLS_INTEGER
DETERMINISTIC;

FUNCTION IsInitialized RETURN BOOLEAN
DETERMINISTIC;
```

**3. Adicionar RESULT_CACHE para lookups**
```sql
-- Para funções que fazem lookup em dados que mudam raramente

FUNCTION get_core_font_name(p_font_key VARCHAR2) RETURN VARCHAR2
RESULT_CACHE;
-- Consulta CoreFonts collection

FUNCTION get_page_dimensions(
  p_format VARCHAR2,
  p_orientation VARCHAR2
) RETURN dimensions_rec
RESULT_CACHE;
-- Calcula dimensões baseado em formato padrão
```

**4. Melhorar declarações de tipos**
```sql
-- ANTES:
myfamily word;
mystyle  word;

-- DEPOIS:
myfamily word NOT NULL := '';
mystyle  word NOT NULL := '';
```

#### Arquivos Afetados
- `PL_FPDF.pks` - Adicionar DETERMINISTIC nas declarações
- `PL_FPDF.pkb` - Adicionar constantes, RESULT_CACHE, refatorar

#### Benefícios
- ✅ Código mais legível e manutenível
- ✅ Melhor performance com RESULT_CACHE
- ✅ Otimizador Oracle pode fazer melhor análise (DETERMINISTIC)
- ✅ Reduz magic numbers e hardcoded values

---

### 🔧 Task 3.2: Adicionar Suporte a JSON
**Prioridade:** P2 (Desejável)
**Esforço:** Médio
**Tempo Estimado:** 2-3 dias

#### Descrição
Adicionar APIs modernas baseadas em JSON para configuração e metadados.

#### Novas APIs

**1. SetDocumentConfig() - Configuração via JSON**
```sql
PROCEDURE SetDocumentConfig(p_config JSON_OBJECT_T);

-- Uso:
DECLARE
  l_config JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_config.put('title', 'Relatório Mensal');
  l_config.put('author', 'Maxwell Oliveira');
  l_config.put('subject', 'Vendas Q4 2025');
  l_config.put('keywords', 'vendas,relatório,q4');
  l_config.put('pageFormat', 'A4');
  l_config.put('orientation', 'P');
  l_config.put('unit', 'mm');
  l_config.put('fontSize', 12);
  l_config.put('fontFamily', 'Helvetica');

  PL_FPDF.SetDocumentConfig(l_config);
END;
```

**2. GetDocumentMetadata() - Retornar metadados como JSON**
```sql
FUNCTION GetDocumentMetadata RETURN JSON_OBJECT_T;

-- Uso:
DECLARE
  l_metadata JSON_OBJECT_T;
BEGIN
  l_metadata := PL_FPDF.GetDocumentMetadata();

  DBMS_OUTPUT.PUT_LINE('Pages: ' || l_metadata.get_Number('pageCount'));
  DBMS_OUTPUT.PUT_LINE('Title: ' || l_metadata.get_String('title'));
  DBMS_OUTPUT.PUT_LINE('Size: ' || l_metadata.get_Number('sizeBytes') || ' bytes');
END;

-- Retorna:
-- {
--   "pageCount": 10,
--   "title": "Relatório Mensal",
--   "author": "Maxwell Oliveira",
--   "format": "A4",
--   "orientation": "Portrait",
--   "sizeBytes": 245678,
--   "fonts": ["Helvetica", "Times"],
--   "images": 3,
--   "created": "2025-12-18T14:30:00"
-- }
```

**3. GetPageInfo() - Informações de página específica**
```sql
FUNCTION GetPageInfo(p_page_number PLS_INTEGER DEFAULT NULL) RETURN JSON_OBJECT_T;

-- Retorna info da página atual ou especificada
-- {
--   "number": 1,
--   "format": "A4",
--   "orientation": "P",
--   "width": 210,
--   "height": 297,
--   "unit": "mm"
-- }
```

#### Arquivos Afetados
- `PL_FPDF.pks` - Adicionar declarações
- `PL_FPDF.pkb` - Implementar parsing/serialização JSON

#### Benefícios
- ✅ Integração moderna com REST APIs
- ✅ Configuração declarativa e flexível
- ✅ Metadados estruturados para processamento
- ✅ Compatível com Oracle APEX e ORDS

---

### 🔧 Task 3.3: Implementar Parsing de Imagens Nativo
**Prioridade:** P2 (Importante)
**Esforço:** Alto
**Tempo Estimado:** 5-7 dias

#### Descrição
Implementar parsers PNG e JPEG 100% em PL/SQL, removendo última dependência externa.

**⚠️ NOTA:** Esta é a task mais complexa da Fase 3!

#### Escopo

**PNG Parser:**
- Ler chunks: IHDR, PLTE, IDAT, IEND, tRNS
- Suportar transparência
- Descomprimir com UTL_COMPRESS
- Extrair dimensões, color type, bit depth

**JPEG Parser:**
- Ler markers: SOI, SOF0, DHT, SOS, EOI
- Extrair dimensões
- Extrair color space (RGB, CMYK, Grayscale)
- Parser básico (sem decompressão completa)

#### Implementação
```sql
-- Função principal
FUNCTION parse_image_native(
  p_image_blob BLOB,
  p_image_type VARCHAR2 -- 'PNG' ou 'JPEG'
) RETURN image_info_rec;

-- Tipo de retorno
TYPE image_info_rec IS RECORD (
  width        NUMBER,
  height       NUMBER,
  bits_per_component NUMBER,
  color_space  VARCHAR2(20),
  has_alpha    BOOLEAN,
  data         BLOB  -- Dados processados para PDF
);

-- Funções auxiliares
FUNCTION read_png_header(p_blob BLOB) RETURN png_header_rec;
FUNCTION read_jpeg_header(p_blob BLOB) RETURN jpeg_header_rec;
FUNCTION decompress_png_data(p_compressed BLOB) RETURN BLOB;
```

#### Arquivos Afetados
- `PL_FPDF.pkb` - Adicionar parsers completos (~500-800 linhas)

#### Benefícios
- ✅ Remove dependência de OrdImage/Java
- ✅ 100% PL/SQL nativo
- ✅ Funciona em qualquer Oracle 19c+ sem instalações extras
- ✅ Melhor controle sobre processamento de imagens

---

### 🔧 Task 3.4: Adicionar Testes Unitários com utPLSQL
**Prioridade:** P2 (Desejável)
**Esforço:** Médio
**Tempo Estimado:** 3-4 dias

#### Descrição
Implementar suite completa de testes unitários usando framework utPLSQL.

#### Estrutura de Testes
```
tests/
├── test_pl_fpdf_core.pks       -- Testes de Init/Reset/IsInitialized
├── test_pl_fpdf_core.pkb
├── test_pl_fpdf_pages.pks      -- Testes de AddPage/SetPage
├── test_pl_fpdf_pages.pkb
├── test_pl_fpdf_fonts.pks      -- Testes de SetFont/AddFont
├── test_pl_fpdf_fonts.pkb
├── test_pl_fpdf_text.pks       -- Testes de Cell/MultiCell/Text
├── test_pl_fpdf_text.pkb
├── test_pl_fpdf_graphics.pks   -- Testes de Line/Rect/Circle
├── test_pl_fpdf_graphics.pkb
├── test_pl_fpdf_colors.pks     -- Testes de SetDrawColor/SetFillColor
├── test_pl_fpdf_colors.pkb
├── test_pl_fpdf_images.pks     -- Testes de Image parsing
├── test_pl_fpdf_images.pkb
└── test_pl_fpdf_output.pks     -- Testes de Output/ReturnBlob
    └── test_pl_fpdf_output.pkb
```

#### Meta de Cobertura
- **Objetivo:** >80% code coverage
- Usar `ut.run()` para execução
- Integrar com CI/CD se disponível

---

### 🔧 Task 3.5: Documentação e Padronização
**Prioridade:** P2 (Importante)
**Esforço:** Baixo
**Tempo Estimado:** 2 dias

#### Documentos a Criar

1. **API_REFERENCE.md** - Referência completa de todas as APIs
2. **MIGRATION_GUIDE.md** - Guia de migração da v0.9.4 para v1.0.0
3. **BREAKING_CHANGES.md** - Lista de breaking changes
4. **EXAMPLES.md** - Exemplos práticos de uso
5. **PERFORMANCE_GUIDE.md** - Guia de otimização

#### Exemplos a Criar
```
examples/
├── example_basic.sql           -- Documento simples
├── example_unicode.sql         -- Unicode/UTF-8
├── example_images.sql          -- Imagens PNG/JPEG
├── example_json_config.sql     -- Configuração JSON
├── example_tables.sql          -- Tabelas complexas
└── example_rotation.sql        -- Rotação de texto
```

---

### 🔧 Task 3.6: Performance Tuning Oracle 23c
**Prioridade:** P3 (Opcional)
**Esforço:** Baixo
**Tempo Estimado:** 1-2 dias

#### Otimizações Específicas Oracle 23c

1. **BOOLEAN Type Nativo** (Oracle 23c)
```sql
-- Substituir PLS_INTEGER por BOOLEAN onde apropriado
g_initialized BOOLEAN := FALSE; -- Já funciona no 19c
```

2. **IF NOT EXISTS** (Oracle 23c)
```sql
-- Simplificar checks
IF NOT EXISTS (SELECT 1 FROM fonts WHERE key = fontkey) THEN
  -- load font
END IF;
```

3. **Annotations** (Oracle 23c)
```sql
-- Adicionar metadados
PROCEDURE SetFont(...)
@description('Sets the font family, style and size')
@param('pfamily', 'Font family name')
@param('pstyle', 'Font style: B=Bold, I=Italic, U=Underline')
@param('psize', 'Font size in points');
```

---

## 📊 Ordem de Execução Recomendada

### Opção A: Sequencial (Mais Seguro)
1. ✅ Task 3.1: Modernizar Estrutura → 2-3 dias
2. ✅ Task 3.2: Suporte JSON → 2-3 dias
3. ✅ Task 3.5: Documentação → 2 dias
4. ✅ Task 3.4: Testes unitários → 3-4 dias
5. ✅ Task 3.6: Performance Tuning → 1-2 dias
6. ⚠️ Task 3.3: Parsing Imagens → 5-7 dias (último pois é complexo)

**Total:** ~15-21 dias

### Opção B: Paralelo (Mais Rápido)
- **Sprint 1 (1 semana):**
  - Task 3.1 + Task 3.2

- **Sprint 2 (1 semana):**
  - Task 3.5 + Task 3.4

- **Sprint 3 (1 semana):**
  - Task 3.3 (parsing imagens)

- **Sprint 4 (2-3 dias):**
  - Task 3.6 (performance tuning)

**Total:** ~3-4 semanas

---

## ✅ Checklist de Conclusão - Fase 3

- [ ] Task 3.1: Código modernizado (CONSTANT, DETERMINISTIC, RESULT_CACHE)
- [ ] Task 3.2: APIs JSON implementadas e testadas
- [ ] Task 3.3: Parsing PNG/JPEG nativo funcionando
- [ ] Task 3.4: Suite utPLSQL com >80% coverage
- [ ] Task 3.5: Documentação completa publicada
- [ ] Task 3.6: Performance tuning aplicado e medido
- [ ] Todos os testes passando (Fase 1, 2 e 3)
- [ ] Performance 50% melhor vs v0.9.4
- [ ] Zero dependências legacy

---

## 🚀 Para Iniciar Fase 3

**Próximo passo sugerido:**
```
Task 3.1: Modernizar Estrutura de Código
```

Deseja que eu comece pela Task 3.1?
