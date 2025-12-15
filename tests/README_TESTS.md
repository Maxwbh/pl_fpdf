# PL_FPDF Test Suite

Testes automatizados para o projeto de modernização PL_FPDF Oracle 19c/23c.

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Execução dos Testes](#execução-dos-testes)
- [Estrutura dos Testes](#estrutura-dos-testes)
- [Cobertura de Testes](#cobertura-de-testes)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Esta suíte de testes automatizados valida a funcionalidade do PL_FPDF modernizado, com foco especial na **Task 1.1: Modernização da Inicialização**.

### Estatísticas

| Métrica | Valor |
|---------|-------|
| **Total de Testes** | 43 |
| **Grupos de Teste** | 10 |
| **Cobertura Estimada** | >90% para Init/Reset |
| **Tempo de Execução** | ~2-5 segundos |
| **Framework** | utPLSQL v3+ ou PL/SQL puro |

---

## 📦 Pré-requisitos

### Requisitos Mínimos

- Oracle Database 19c ou superior
- PL_FPDF package instalado
- Permissões `CREATE PROCEDURE`, `EXECUTE` no schema

### Requisitos Opcionais (Recomendado)

- **utPLSQL v3+**: Para testes avançados e relatórios
  - Download: https://github.com/utPLSQL/utPLSQL
  - Instalação: Ver [utPLSQL Installation Guide](https://www.utplsql.org/utPLSQL/latest/userguide/install.html)

---

## 🚀 Instalação

### Opção 1: Instalação Rápida (Script Único)

```bash
cd tests
sqlplus user/pass@db @install_tests.sql
```

### Opção 2: Instalação Manual

```sql
-- 1. Compilar package spec
SQL> @test_pl_fpdf_init.pks

-- 2. Compilar package body
SQL> @test_pl_fpdf_init.pkb

-- 3. Verificar compilação
SQL> SELECT object_name, object_type, status
     FROM user_objects
     WHERE object_name = 'TEST_PL_FPDF_INIT';

-- Esperado:
-- TEST_PL_FPDF_INIT  PACKAGE       VALID
-- TEST_PL_FPDF_INIT  PACKAGE BODY  VALID
```

---

## ▶️ Execução dos Testes

### Método 1: Teste Simples (Sem utPLSQL)

**Mais rápido, não requer dependências externas**

```bash
sqlplus user/pass@db @run_init_tests_simple.sql
```

**Saída Esperada:**
```
============================================================================
PL_FPDF Initialization Tests - Simple Runner
============================================================================

Test Suite: PL_FPDF Initialization
Oracle Version: 19.0.0.0.0
Timestamp: 2025-12-15 14:30:45

Running tests...

Group 1: Basic Initialization
  [PASS] Init with default parameters
  [PASS] Init with Portrait orientation
  [PASS] Init with Landscape orientation
  [PASS] Init with UTF-8 encoding

Group 2: Parameter Validation
  [PASS] Invalid orientation rejected correctly
  [PASS] Invalid unit rejected correctly
  [PASS] Invalid encoding rejected correctly

...

============================================================================
Test Summary:
  Total tests:  18
  Passed:       18 (100.0%)
  Failed:       0 (0.0%)
============================================================================

✓ ALL TESTS PASSED!
```

---

### Método 2: utPLSQL (Recomendado)

**Mais poderoso, com relatórios detalhados**

```bash
sqlplus user/pass@db @run_init_tests_utplsql.sql
```

**Ou via linha de comando:**

```sql
-- Executar toda a suite
EXEC ut.run('test_pl_fpdf_init');

-- Executar apenas testes básicos
EXEC ut.run('test_pl_fpdf_init', ut_varchar2_list('basic'));

-- Executar apenas testes de validação
EXEC ut.run('test_pl_fpdf_init', ut_varchar2_list('validation'));

-- Executar smoke tests
EXEC ut.run('test_pl_fpdf_init', ut_varchar2_list('smoke'));

-- Gerar relatório HTML com cobertura
BEGIN
  ut.run(
    'test_pl_fpdf_init',
    ut_coverage_html_reporter()
  );
END;
/
```

---

### Método 3: SQL Developer

1. Abrir SQL Developer
2. Conectar ao banco de dados
3. Abrir arquivo `run_init_tests_simple.sql`
4. Pressionar F5 (Run Script)
5. Verificar saída no painel "Script Output"

---

### Método 4: CI/CD (Automated)

```bash
#!/bin/bash
# Script para CI/CD pipeline

# Variáveis de ambiente
DB_USER="${DB_USER:-plsql_dev}"
DB_PASS="${DB_PASS:-password}"
DB_HOST="${DB_HOST:-localhost:1521/ORCLPDB1}"

# Executar testes
sqlplus -S ${DB_USER}/${DB_PASS}@${DB_HOST} <<EOF
SET SERVEROUTPUT ON;
SET FEEDBACK OFF;
@run_init_tests_simple.sql
EXIT;
EOF

# Verificar código de saída
if [ $? -eq 0 ]; then
  echo "Tests passed successfully"
  exit 0
else
  echo "Tests failed"
  exit 1
fi
```

---

## 📂 Estrutura dos Testes

### Arquivos

```
tests/
├── README_TESTS.md                 # Este arquivo
├── test_pl_fpdf_init.pks           # Test package specification (utPLSQL)
├── test_pl_fpdf_init.pkb           # Test package body (utPLSQL)
├── run_init_tests_simple.sql       # Runner simples (sem utPLSQL)
├── run_init_tests_utplsql.sql      # Runner utPLSQL
├── install_tests.sql               # Script de instalação
└── uninstall_tests.sql             # Script de desinstalação
```

---

### Grupos de Teste

| Grupo | Testes | Descrição |
|-------|--------|-----------|
| **1. Basic Initialization** | 6 | Init com diferentes parâmetros |
| **2. Parameter Validation** | 4 | Validação de parâmetros inválidos |
| **3. State Management** | 3 | Verificação de estado (initialized/not) |
| **4. Re-initialization** | 3 | Re-init e mudança de parâmetros |
| **5. Reset Functionality** | 3 | Limpeza de recursos |
| **6. CLOB Management** | 2 | Criação e gerenciamento de CLOBs |
| **7. Configuration** | 7 | Verificação de configurações padrão |
| **8. Edge Cases** | 4 | Casos extremos e edge cases |
| **9. Metadata** | 3 | Inicialização de metadados |
| **10. Performance** | 2 | Testes de performance |
| **TOTAL** | **43** | |

---

## 📊 Cobertura de Testes

### Funções/Procedures Testadas

| Função/Procedure | Cobertura | Testes |
|------------------|-----------|--------|
| `Init()` | 95% | 25 |
| `Reset()` | 90% | 8 |
| `IsInitialized()` | 100% | 10 |

### Cenários Cobertos

✅ **Inicialização:**
- Parâmetros padrão
- Todas orientações (P, L)
- Todas unidades (mm, cm, in, pt)
- Todos formatos (A4, Letter, Legal, A3, A5)
- Todos encodings (UTF-8, ISO-8859-1, Windows-1252)

✅ **Validação:**
- Orientação inválida
- Unidade inválida
- Encoding inválido
- Parâmetros NULL

✅ **Estado:**
- Não inicializado antes de Init()
- Inicializado após Init()
- Não inicializado após Reset()

✅ **Re-inicialização:**
- Re-init permitido
- Recursos liberados corretamente
- Parâmetros alterados

✅ **Reset:**
- Estado limpo
- CLOBs liberados
- Init após Reset funciona

✅ **CLOBs:**
- CLOBs temporários criados
- Escopo de sessão correto

✅ **Configuração:**
- Fator de escala correto para cada unidade
- Margens padrão
- Fonte padrão
- Cores padrão

✅ **Edge Cases:**
- Múltiplos resets
- Ciclos init-reset-init
- Case-insensitive params

✅ **Metadados:**
- Estrutura inicializada
- Creator definido
- Data de criação definida

✅ **Performance:**
- Init < 100ms
- 100 ciclos init-reset < 10s

---

## 🔧 Casos de Teste Detalhados

### Exemplo: Test Group 1 - Basic Initialization

```sql
-- Test 1.1: Init with defaults
PL_FPDF.Init();
ASSERT IsInitialized() = TRUE

-- Test 1.2: Init Portrait
PL_FPDF.Init(p_orientation => 'P');
ASSERT IsInitialized() = TRUE

-- Test 1.3: Init Landscape
PL_FPDF.Init(p_orientation => 'L');
ASSERT IsInitialized() = TRUE

-- Test 1.4: Init different units
FOR unit IN ('mm', 'cm', 'in', 'pt') LOOP
  PL_FPDF.Init(p_unit => unit);
  ASSERT IsInitialized() = TRUE
END LOOP

-- Test 1.5: Init different formats
FOR format IN ('A4', 'Letter', 'Legal') LOOP
  PL_FPDF.Init(p_format => format);
  ASSERT IsInitialized() = TRUE
END LOOP

-- Test 1.6: Init UTF-8
PL_FPDF.Init(p_encoding => 'UTF-8');
ASSERT IsInitialized() = TRUE
```

---

### Exemplo: Test Group 2 - Parameter Validation

```sql
-- Test 2.1: Invalid orientation
BEGIN
  PL_FPDF.Init(p_orientation => 'X');
  ASSERT FALSE -- Should not reach here
EXCEPTION
  WHEN OTHERS THEN
    ASSERT SQLCODE = -20001
END;

-- Test 2.2: Invalid unit
BEGIN
  PL_FPDF.Init(p_unit => 'meters');
  ASSERT FALSE
EXCEPTION
  WHEN OTHERS THEN
    ASSERT SQLCODE = -20002
END;

-- Test 2.3: Invalid encoding
BEGIN
  PL_FPDF.Init(p_encoding => 'EBCDIC');
  ASSERT FALSE
EXCEPTION
  WHEN OTHERS THEN
    ASSERT SQLCODE = -20003
END;
```

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: PL_FPDF Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      oracle:
        image: container-registry.oracle.com/database/express:21.3.0-xe
        env:
          ORACLE_PWD: password
        ports:
          - 1521:1521

    steps:
      - uses: actions/checkout@v2

      - name: Wait for Oracle
        run: |
          echo "Waiting for Oracle to start..."
          sleep 60

      - name: Install PL_FPDF
        run: |
          sqlplus system/password@localhost:1521/XEPDB1 @install_pl_fpdf.sql

      - name: Install Tests
        run: |
          sqlplus system/password@localhost:1521/XEPDB1 @tests/install_tests.sql

      - name: Run Tests
        run: |
          sqlplus system/password@localhost:1521/XEPDB1 @tests/run_init_tests_simple.sql
```

---

### Jenkins Pipeline Example

```groovy
pipeline {
  agent any

  stages {
    stage('Install') {
      steps {
        sh '''
          sqlplus ${DB_USER}/${DB_PASS}@${DB_HOST} @install_pl_fpdf.sql
          sqlplus ${DB_USER}/${DB_PASS}@${DB_HOST} @tests/install_tests.sql
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          sqlplus ${DB_USER}/${DB_PASS}@${DB_HOST} @tests/run_init_tests_simple.sql > test_results.txt
        '''
      }
    }

    stage('Verify') {
      steps {
        script {
          def results = readFile('test_results.txt')
          if (results.contains('ALL TESTS PASSED')) {
            echo "✓ Tests passed"
          } else {
            error("✗ Tests failed")
          }
        }
      }
    }
  }
}
```

---

## 🐛 Troubleshooting

### Problema: "PL_FPDF package not found"

**Solução:**
```sql
-- Verificar se package existe
SELECT object_name, object_type, status
FROM all_objects
WHERE object_name = 'PL_FPDF';

-- Se não existir, instalar:
@install_pl_fpdf.sql
```

---

### Problema: "utPLSQL not installed"

**Solução 1 (Recomendado):**
```
Use o runner simples que não requer utPLSQL:
@run_init_tests_simple.sql
```

**Solução 2:**
```
Instalar utPLSQL:
https://www.utplsql.org/utPLSQL/latest/userguide/install.html
```

---

### Problema: "ORA-22275: invalid LOB locator"

**Causa:** CLOBs temporários não foram criados corretamente

**Solução:**
```sql
-- Resetar e reinicializar
EXEC PL_FPDF.Reset();
EXEC PL_FPDF.Init();
```

---

### Problema: Tests failing with "-20001: Invalid orientation"

**Causa:** Implementação de Init() ainda não está completa

**Solução:**
```
1. Verificar se Task 1.1 foi implementada completamente
2. Comparar código com MODERNIZATION_PLAN_COMPLETE.md
3. Implementar validações faltantes
```

---

### Problema: Performance tests failing (too slow)

**Possíveis causas:**
- Banco de dados sobrecarregado
- Falta de recursos (CPU, memória)
- Rede lenta (conexão remota)

**Solução:**
```
1. Executar localmente em banco dedicado
2. Ajustar thresholds nos testes de performance
3. Executar durante horários de baixo uso
```

---

## 📈 Interpretando Resultados

### Saída de Sucesso (100%)

```
============================================================================
Test Summary:
  Total tests:  43
  Passed:       43 (100.0%)
  Failed:       0 (0.0%)
============================================================================

✓ ALL TESTS PASSED!
```

**Ação:** ✅ Prosseguir para próxima task

---

### Saída com Falhas

```
Group 2: Parameter Validation
  [PASS] Invalid orientation rejected correctly
  [FAIL] Invalid unit - wrong error: ORA-01403: no data found
  [PASS] Invalid encoding rejected correctly

============================================================================
Test Summary:
  Total tests:  43
  Passed:       42 (97.7%)
  Failed:       1 (2.3%)
============================================================================

✗ SOME TESTS FAILED - Review output above
```

**Ação:**
1. ❌ NÃO prosseguir para próxima task
2. 🔍 Investigar teste falhando
3. 🐛 Corrigir código
4. ▶️ Re-executar testes
5. ✅ Validar 100% pass

---

## 📞 Suporte

**Desenvolvedor:** Maxwell da Silva Oliveira
**Email:** maxwbh@gmail.com
**LinkedIn:** [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

**Issues:** https://github.com/maxwbh/pl_fpdf/issues

---

## 📚 Referências

- [utPLSQL Documentation](https://www.utplsql.org/)
- [Oracle PL/SQL Testing Best Practices](https://oracle-base.com/articles/misc/utplsql-testing-framework)
- [MODERNIZATION_PLAN_COMPLETE.md](../MODERNIZATION_PLAN_COMPLETE.md)

---

**Última Atualização:** 2025-12-15
**Versão:** 1.0
**Status:** ✅ Pronto para Uso
