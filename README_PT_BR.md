# PL_FPDF - Geração de PDF para Oracle PL/SQL

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2F23c-red.svg)
![License](https://img.shields.io/badge/license-GPL%20v2-green.svg)
![Tests](https://img.shields.io/badge/tests-87%20passing-brightgreen.svg)
![Coverage](https://img.shields.io/badge/coverage-82%25-brightgreen.svg)

> **Biblioteca moderna e de alta performance para geração de PDF em Oracle Database 19c/23c**

PL_FPDF é uma biblioteca PL/SQL pura para gerar documentos PDF diretamente do Oracle Database. Originalmente portado da biblioteca PHP FPDF (v1.53), foi completamente modernizado para Oracle 19c/23c com compilação nativa, suporte UTF-8 e recursos avançados do Oracle.

[**English**](README.md) | [**Referência da API**](API_REFERENCE.md) | [**Guia de Migração**](MIGRATION_GUIDE.md)

---

## ✨ Recursos

### Geração de PDF Core
- ✅ **Documentos multi-página** com páginas ilimitadas
- ✅ **Renderização de texto** com múltiplas fontes (Arial, Courier, Times, Helvetica)
- ✅ **Suporte a fontes TrueType/OpenType** com embedding completo
- ✅ **Codificação UTF-8** para caracteres internacionais
- ✅ **Primitivas gráficas** (linhas, retângulos, círculos, polígonos)
- ✅ **Incorporação de imagens** (PNG, JPEG) com parsing nativo
- ✅ **Rotação de texto** (0°, 90°, 180°, 270°)
- ✅ **Formatos de página personalizados** (A3, A4, A5, Letter, Legal, tamanhos customizados)

### Recursos Modernos do Oracle
- ✅ **Compilação nativa** (melhoria de performance de 2-3x)
- ✅ **Buffers CLOB** para tamanho ilimitado de documentos
- ✅ **Configuração JSON** (Oracle 19c+ JSON_OBJECT_T)
- ✅ **Logging estruturado** com DBMS_APPLICATION_INFO
- ✅ **Exceções customizadas** com códigos de erro significativos
- ✅ **Cache de resultados** para métricas de fontes
- ✅ **Zero dependências externas** (sem OWA, sem OrdImage)

---

## 📦 Instalação

### Instalação Rápida

```sql
sqlplus usuario/senha@banco @deploy_all.sql
```

### Instalação Manual

```sql
-- 1. Instalar pacote core
@PL_FPDF.pks
@PL_FPDF.pkb

-- 2. Verificar instalação
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PL_FPDF';
```

### Extensões Opcionais

Para sistemas de pagamento brasileiros (PIX e Boleto), veja `extensions/brazilian-payments/`

### Otimização de Performance (Recomendado)

```sql
-- Habilitar compilação nativa para performance 2-3x melhor
@optimize_native_compile.sql
```

---

## 🚀 Início Rápido

### Olá Mundo

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- Inicializar PDF
  PL_FPDF.Init('P', 'mm', 'A4');

  -- Adicionar página
  PL_FPDF.AddPage();

  -- Definir fonte
  PL_FPDF.SetFont('Arial', 'B', 16);

  -- Adicionar texto
  PL_FPDF.Cell(0, 10, 'Olá Mundo!');

  -- Gerar PDF
  l_pdf := PL_FPDF.OutputBlob();

  -- Limpeza
  PL_FPDF.Reset();

  -- Salvar em arquivo ou enviar ao cliente
  -- ... (veja exemplos abaixo)
END;
/
```

### Salvar PDF em Arquivo

```sql
BEGIN
  PL_FPDF.Init();
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'PDF de Exemplo');

  -- Salvar em diretório Oracle
  PL_FPDF.OutputFile('MEU_DIRETORIO', 'exemplo.pdf');

  PL_FPDF.Reset();
END;
/
```

### Documento Multi-Página

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init();
  PL_FPDF.SetFont('Arial', '', 12);

  -- Gerar 100 páginas
  FOR i IN 1..100 LOOP
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Página ' || i || ' de 100');
  END LOOP;

  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
/
```

---

## 📚 Documentação

| Documento | Descrição |
|-----------|-----------|
| [README.md](README.md) | Documentação completa em inglês |
| [API_REFERENCE.md](API_REFERENCE.md) | Referência completa da API com todas as funções |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Guia de migração da v0.9.4 para v2.0 |
| [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) | Guia de otimização de performance |
| [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) | Guia de testes e validação |
| [tests/README_TESTS.md](tests/README_TESTS.md) | Documentação de testes unitários |

---

## 🧪 Testes

### Executar Todos os Testes

```bash
cd tests
sqlplus usuario/senha@banco @run_all_tests.sql
```

### Cobertura de Testes

| Módulo | Testes | Cobertura |
|--------|--------|-----------|
| Inicialização | 43 | >90% |
| Fontes | 18 | >85% |
| Imagens | 14 | >80% |
| Saída | 7 | >90% |
| Performance | 5 | 100% |
| **Total** | **87** | **>82%** |

---

## ⚡ Performance

### Benchmarks (Oracle 19c, Compilação Nativa)

| Operação | Tempo | Throughput |
|----------|-------|------------|
| Init() | 15-30ms | - |
| Documento de 100 páginas | 1.2-1.8s | 55-83 páginas/seg |
| Documento de 1000 páginas | 8-12s | 83-125 páginas/seg |
| OutputBlob (50 páginas) | 150-250ms | - |

### Dicas de Otimização

1. **Habilitar compilação nativa** (2-3x mais rápido)
   ```sql
   @optimize_native_compile.sql
   ```

2. **Reutilizar Init/Reset** ao invés de criar novas instâncias
   ```sql
   PL_FPDF.Init();
   -- Gerar PDF #1
   PL_FPDF.Reset();
   PL_FPDF.Init();
   -- Gerar PDF #2
   ```

3. **Desabilitar logging em produção**
   ```sql
   PL_FPDF.SetLogLevel(0);
   ```

Veja [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) para o guia completo.

---

## 📋 Requisitos

- Oracle Database 19c ou superior (23c recomendado)
- PL/SQL Developer ou SQL*Plus
- Permissões: CREATE PROCEDURE, EXECUTE
- Opcional: utPLSQL v3+ para executar testes

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────┐
│         PL_FPDF (Pacote Principal)          │
│  • Geração de documentos PDF                │
│  • Renderização de texto e fontes           │
│  • Incorporação de imagens (PNG, JPEG)      │
│  • Primitivas gráficas                      │
│  • Suporte UTF-8, fontes TrueType           │
│  • Documentos multi-página                  │
│  • Renderização genérica QRCode/Barcode     │
└─────────────────────────────────────────────┘
```

**Extensões Opcionais**: Sistemas de pagamento brasileiros (PIX/Boleto) estão disponíveis como extensões separadas no diretório `extensions/`.

---

## 🤝 Contribuindo

Este é um projeto de modernização da biblioteca original PL_FPDF. Contribuições são bem-vindas!

### Autores Originais
- **FPDF (PHP)**: Olivier PLATHEY
- **PL_FPDF (Oracle)**: Pierre-Gilles Levallois et al

### Projeto de Modernização
- **Desenvolvedor Principal**: Maxwell da Silva Oliveira (@maxwbh)
- **Empresa**: M&S do Brasil LTDA
- **Contato**: maxwell@msbrasil.inf.br
- **LinkedIn**: [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

---

## 🔗 Links

- **FPDF Original**: http://www.fpdf.org/
- **Repositório GitHub**: https://github.com/maxwbh/pl_fpdf
- **Original Repository**: https://github.com/Pilooz/pl_fpdf

---

## 📊 Status do Projeto

✅ **v2.0.0 Lançado** - Dezembro 2025

| Fase | Status | Conclusão |
|------|--------|-----------|
| Fase 1: Refatoração Crítica | ✅ Completa | 100% |
| Fase 2: Segurança & Robustez | ✅ Completa | 100% |
| Fase 3: Modernização Avançada | ✅ Completa | 100% |

**Modernização completa: 100%**

---

## ⭐ Histórico de Estrelas

Se você achar este projeto útil, por favor dê uma estrela no GitHub!

---

**Última Atualização**: 19 de dezembro de 2025
**Versão**: 2.0.0
**Status**: Pronto para Produção ✅
