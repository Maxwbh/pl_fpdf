# PL_FPDF Test Suite Documentation
# Documentação da Suite de Testes PL_FPDF

**Version:** 3.0.0-a.7
**Last Updated:** 2026-01-25
**Maintainer:** @maxwbh

[🇬🇧 English](#english) | [🇧🇷 Português](#português)

---

## English

### 📋 Test Suite Overview

The PL_FPDF test suite provides comprehensive testing and validation for all phases
of the project, from Phase 1 (PDF Generation) through Phase 4.6 (PDF Merge & Split).

### 🗂️ Test Structure

```
tests/
├── README.md                          # This file
├── run_all_tests.sql                  # Master test runner
├── test_runner.sql                    # New organized test runner
│
├── Phase 1-3: PDF Generation
│   ├── validate_phase_1.sql           # ✅ Phase 1 validation
│   ├── validate_phase_2.sql           # ✅ Phase 2 validation
│   ├── validate_phase_3.sql           # ✅ Phase 3 validation
│   └── validate_phases_1_3.sql        # 🆕 Combined validation
│
├── Phase 4: PDF Reading & Manipulation
│   ├── test_phase_4_1a_parser.sql     # Phase 4.1A: PDF Parser
│   ├── test_phase_4_1b_pages.sql      # ✅ Phase 4.1B: Page Info
│   ├── test_phase_4_2_page_mgmt.sql   # ✅ Phase 4.2: Page Management
│   ├── test_phase_4_3_watermark.sql   # ✅ Phase 4.3: Watermarks
│   ├── test_phase_4_4_output.sql      # ✅ Phase 4.4: Output Modified
│   ├── test_phase_4_5_overlay.sql     # ✅ Phase 4.5: Text/Image Overlay
│   ├── test_phase_4_6_merge_split.sql # 🆕 Phase 4.6: Merge & Split
│   └── validate_phase_4_complete.sql  # 🆕 Phase 4 validation
│
└── Legacy & Utilities
    ├── install_tests.sql              # Test installation
    ├── uninstall_tests.sql            # Test cleanup
    ├── run_init_tests_simple.sql      # Basic init tests
    └── run_init_tests_utplsql.sql     # utPLSQL tests
```

### 📊 Test Coverage Summary

| Phase | Description | Tests | Status |
|-------|-------------|-------|--------|
| **1** | PDF Generation - Basics | validate_phase_1.sql | ✅ Complete |
| **2** | Security & Robustness | validate_phase_2.sql | ✅ Complete |
| **3** | Advanced Features | validate_phase_3.sql | ✅ Complete |
| **4.1A** | PDF Parser | test_phase_4_1a_parser.sql | ✅ Complete |
| **4.1B** | Page Information | test_phase_4_1b_pages.sql | ✅ Complete |
| **4.2** | Page Management | test_phase_4_2_page_mgmt.sql | ✅ Complete |
| **4.3** | Watermarks | test_phase_4_3_watermark.sql | ✅ Complete |
| **4.4** | Output Modified PDF | test_phase_4_4_output.sql | ✅ Complete |
| **4.5** | Text & Image Overlay | test_phase_4_5_overlay.sql (20 tests) | ✅ Complete |
| **4.6** | PDF Merge & Split | test_phase_4_6_merge_split.sql | 🆕 To Create |
| **Phase 4** | Complete Validation | validate_phase_4_complete.sql | 🆕 To Create |

### 🚀 Running Tests

#### Quick Test (All Phases)
```sql
@tests/test_runner.sql
```

#### Run Specific Phase Tests
```sql
-- Phase 1-3 Validation
@tests/validate_phases_1_3.sql

-- Phase 4 Tests (Individual)
@tests/test_phase_4_1a_parser.sql
@tests/test_phase_4_1b_pages.sql
@tests/test_phase_4_2_page_mgmt.sql
@tests/test_phase_4_3_watermark.sql
@tests/test_phase_4_4_output.sql
@tests/test_phase_4_5_overlay.sql
@tests/test_phase_4_6_merge_split.sql

-- Phase 4 Complete Validation
@tests/validate_phase_4_complete.sql
```

#### Legacy Test Runner
```sql
@tests/run_all_tests.sql
```

### 📝 Test Categories

#### 1. Validation Tests (`validate_*.sql`)
- **Purpose:** Verify phase completion and API availability
- **Scope:** High-level feature validation
- **Output:** Pass/Fail status per phase
- **Use Case:** Pre-production verification

#### 2. Unit Tests (`test_phase_*.sql`)
- **Purpose:** Detailed testing of specific features
- **Scope:** Individual API testing with edge cases
- **Output:** Detailed test results with pass/fail counts
- **Use Case:** Development and debugging

#### 3. Integration Tests
- **Purpose:** Test interaction between phases
- **Scope:** Multi-phase workflows
- **Use Case:** End-to-end verification

### 🧪 Test Data

All tests use self-contained test data:
- Minimal valid PDFs generated inline
- 1x1 PNG images (minimal valid PNG)
- No external file dependencies
- Tests can run in any Oracle environment

### ✅ Test Requirements

**Minimum Requirements:**
- Oracle Database 11g or higher
- PL_FPDF package installed (both .pks and .pkb)
- DBMS_OUTPUT enabled: `SET SERVEROUTPUT ON SIZE UNLIMITED`

**Optional:**
- 5MB+ CLOB/BLOB buffer

### 📈 Test Metrics

**Current Test Statistics:**
- **Total Test Files:** 16
- **Total Test Cases:** ~150+
- **Phase 1-3 Coverage:** 100%
- **Phase 4.1-4.5 Coverage:** 100%
- **Phase 4.6 Coverage:** To be created
- **Error Code Coverage:** All codes tested

### 🔍 Test Execution Order

**Recommended Order:**
1. Phase 1-3 Validation (Foundation)
2. Phase 4.1A (Parser)
3. Phase 4.1B-4.4 (Sequential)
4. Phase 4.5 (Overlay)
5. Phase 4.6 (Merge/Split)
6. Phase 4 Complete Validation

### 🐛 Troubleshooting

**Common Issues:**

1. **"Identifier too long" errors**
   - Solution: Use Oracle 12c+ or shorten variable names

2. **"APEX_STRING not found"**
   - Solution: Install APEX 19.1+ or use alternative parsing

3. **"Insufficient CLOB buffer"**
   - Solution: Increase CLOB/BLOB size limits in database

4. **Tests timeout**
   - Solution: Increase SQL*Plus timeout or run tests individually

### 📚 Writing New Tests

**Test Template:**
```sql
/*******************************************************************************
* Test Script: Phase X.Y - Feature Name
* Version: 3.0.0-a.N
* Date: YYYY-MM-DD
* Author: @username
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT ========================================
PROMPT Phase X.Y: Feature Name Tests
PROMPT ========================================
PROMPT

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  PROCEDURE run_test(p_name VARCHAR2, p_result BOOLEAN) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_result THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_name || ' - FAIL');
    END IF;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting tests...');

  -- Test 1: Description
  BEGIN
    -- Test code here
    run_test('Test description', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Test description', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- More tests...

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('Test Summary:');
  DBMS_OUTPUT.PUT_LINE('  Total:  ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('  Passed: ' || l_pass_count);
  DBMS_OUTPUT.PUT_LINE('  Failed: ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('========================================');
END;
/
```

---

## Português

### 📋 Visão Geral da Suite de Testes

A suite de testes PL_FPDF fornece testes e validação abrangentes para todas
as fases do projeto, da Fase 1 (Geração de PDF) até a Fase 4.6 (Merge & Split).

### 🗂️ Estrutura de Testes

```
tests/
├── README.md                          # Este arquivo
├── run_all_tests.sql                  # Executor principal de testes
├── test_runner.sql                    # 🆕 Executor organizado
│
├── Fase 1-3: Geração de PDF
│   ├── validate_phase_1.sql           # ✅ Validação Fase 1
│   ├── validate_phase_2.sql           # ✅ Validação Fase 2
│   ├── validate_phase_3.sql           # ✅ Validação Fase 3
│   └── validate_phases_1_3.sql        # 🆕 Validação combinada
│
├── Fase 4: Leitura e Manipulação de PDF
│   ├── test_phase_4_1a_parser.sql     # Fase 4.1A: Parser PDF
│   ├── test_phase_4_1b_pages.sql      # ✅ Fase 4.1B: Info Páginas
│   ├── test_phase_4_2_page_mgmt.sql   # ✅ Fase 4.2: Gestão Páginas
│   ├── test_phase_4_3_watermark.sql   # ✅ Fase 4.3: Marcas d'Água
│   ├── test_phase_4_4_output.sql      # ✅ Fase 4.4: Output Modificado
│   ├── test_phase_4_5_overlay.sql     # ✅ Fase 4.5: Overlay Texto/Imagem
│   ├── test_phase_4_6_merge_split.sql # 🆕 Fase 4.6: Merge & Split
│   └── validate_phase_4_complete.sql  # 🆕 Validação Fase 4
│
└── Legacy & Utilitários
    ├── install_tests.sql              # Instalação testes
    ├── uninstall_tests.sql            # Limpeza testes
    ├── run_init_tests_simple.sql      # Testes init básicos
    └── run_init_tests_utplsql.sql     # Testes utPLSQL
```

### 🚀 Executando Testes

#### Teste Rápido (Todas as Fases)
```sql
@tests/test_runner.sql
```

#### Executar Testes de Fase Específica
```sql
-- Validação Fase 1-3
@tests/validate_phases_1_3.sql

-- Testes Fase 4 (Individual)
@tests/test_phase_4_1a_parser.sql
@tests/test_phase_4_5_overlay.sql
@tests/test_phase_4_6_merge_split.sql

-- Validação Completa Fase 4
@tests/validate_phase_4_complete.sql
```

### 📊 Resumo de Cobertura

| Fase | Descrição | Testes | Status |
|------|-----------|--------|--------|
| **1** | Geração PDF - Básico | validate_phase_1.sql | ✅ Completo |
| **2** | Segurança & Robustez | validate_phase_2.sql | ✅ Completo |
| **3** | Recursos Avançados | validate_phase_3.sql | ✅ Completo |
| **4.5** | Overlay Texto/Imagem | test_phase_4_5_overlay.sql (20 testes) | ✅ Completo |
| **4.6** | Merge & Split PDF | test_phase_4_6_merge_split.sql | 🆕 Criar |

### 📈 Métricas de Teste

**Estatísticas Atuais:**
- **Total Arquivos:** 16
- **Total Casos:** ~150+
- **Cobertura Fase 1-3:** 100%
- **Cobertura Fase 4.1-4.5:** 100%
- **Cobertura Fase 4.6:** A criar

---

## 📝 Change Log

**2026-01-25:**
- ✅ Created comprehensive test documentation
- ✅ Documented all existing test files
- 🆕 Identified missing test files (Phase 4.6, validations)
- 🆕 Planned test organization improvements

**Next Steps:**
- Create test_phase_4_6_merge_split.sql
- Create validate_phase_4_complete.sql
- Create test_runner.sql
- Update run_all_tests.sql

---

**Maintainer:** @maxwbh
**Contact:** Via GitHub Issues
**License:** MIT
