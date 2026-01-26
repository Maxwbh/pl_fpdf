# PL_FPDF - Oracle PL/SQL PDF Generator

[![Version](https://img.shields.io/badge/version-3.0.0--b.2-blue.svg)](CHANGELOG.md)
[![Oracle](https://img.shields.io/badge/oracle-11g%2B-red.svg)](https://www.oracle.com/database/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-66%20passing-brightgreen.svg)](tests/)

[🇬🇧 English](#english) | [🇧🇷 Português](#português)

---

## English

### 📖 Overview

**PL_FPDF** is a powerful, pure PL/SQL library for **generating and manipulating PDF documents** directly in Oracle Database. No external dependencies, Java, or additional services required.

**Current Version:** 3.0.0-beta.2 ✨ (Phase 4.6 Complete - Not Validated)

### ✨ Key Features

#### ✅ Phase 1-3: PDF Generation (v2.0.0)
- Create PDF documents from scratch
- Text, shapes, images (JPEG, PNG)
- Fonts: Standard, TrueType, Unicode support
- Barcodes: Code 39, Code 128, EAN-13, QR Code
- Tables with auto-pagination
- Headers and footers
- Multi-page support with unlimited pages
- Page rotation and custom formats
- Trivadis PL/SQL Cop compliant

#### ✅ Phase 4.1-4.4: PDF Reading and Manipulation (v3.0.0)
- **Load and Parse PDFs** - Read existing PDF files (PDF 1.4+)
- **Page Information** - Extract page details (dimensions, rotation, resources)
- **Page Rotation** - Rotate individual pages (0°, 90°, 180°, 270°)
- **Page Removal** - Remove unwanted pages from PDFs
- **Watermarks** - Add customizable text watermarks to pages
- **Output Modified PDF** - Generate new PDF with all modifications applied

#### ✅ Phase 4.5: Text & Image Overlay (v3.0.0-b.1)
- **Text Overlay** - Add formatted text at specific x,y coordinates
- **Image Overlay** - Add images (JPEG/PNG) at specific positions with sizing
- **Precise Positioning** - Full control over position, size, opacity, rotation
- **Multiple Overlays** - Layer multiple text/image overlays per page
- **Z-Order Management** - Control layering with z-order values
- **Overlay Management** - List, remove, and clear overlays

#### ✅ Phase 4.6: PDF Merge & Split (v3.0.0-b.2)
- **LoadPDFWithID** - Load multiple PDFs with unique identifiers (max 10)
- **Merge PDFs** - Combine multiple PDF documents into one
- **Split PDFs** - Divide PDF into multiple files by page ranges
- **Extract Pages** - Create new PDF from specific page selection
- **Multi-Document Management** - GetLoadedPDFs(), UnloadPDF()
- **Simplified Implementation** - Foundation for Phase 5 advanced operations

#### 🚧 Phase 5: Advanced Operations (v3.1.0 - In Planning)
- **Insert Pages** - Insert pages from one PDF into another at any position
- **Reorder Pages** - Rearrange page order with move, swap, reverse operations
- **Replace Pages** - Replace page content from another PDF
- **Duplicate Pages** - Copy pages within or across documents
- **Batch Processing** - Process multiple PDFs with automated workflows

### 🚀 Quick Start

#### Installation

```sql
-- 1. Compile package specification
@PL_FPDF.pks

-- 2. Compile package body
@PL_FPDF.pkb

-- 3. Verify installation
SELECT PL_FPDF.GetVersion() FROM DUAL;
-- Expected output: 3.0.0-b.2
```

#### Create Your First PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- Initialize PDF
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Add content
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Hello World!', '0', 1, 'C');

  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.MultiCell(0, 5, 'This is my first PDF created with PL_FPDF!');

  -- Generate PDF
  l_pdf := PL_FPDF.Output_Blob();

  -- Save to table
  INSERT INTO my_documents (id, pdf_blob, created_date)
  VALUES (1, l_pdf, SYSDATE);

  COMMIT;
END;
/
```

#### Modify Existing PDF (Phase 4) 🆕

```sql
DECLARE
  l_original_pdf BLOB;
  l_modified_pdf BLOB;
BEGIN
  -- Load existing PDF
  SELECT pdf_blob INTO l_original_pdf FROM my_documents WHERE id = 1;

  PL_FPDF.LoadPDF(l_original_pdf);

  -- Apply modifications
  PL_FPDF.RotatePage(1, 90);                           -- Rotate page 1
  PL_FPDF.RemovePage(3);                                -- Remove page 3
  PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL'); -- Add watermark

  -- Generate modified PDF
  l_modified_pdf := PL_FPDF.OutputModifiedPDF();

  -- Save modified PDF
  UPDATE my_documents SET pdf_blob = l_modified_pdf WHERE id = 1;
  COMMIT;

  PL_FPDF.ClearPDFCache();
END;
/
```

### 📚 Documentation

**User Guides:**
- 📘 [Complete API Reference](docs/api/API_REFERENCE.md)
- 📗 [Phase 4 Guide - PDF Manipulation](docs/guides/PHASE_4_GUIDE.md)
- 📕 [Performance Tuning](docs/guides/PERFORMANCE_TUNING.md)
- 📔 [Validation & Testing Guide](docs/guides/VALIDATION_GUIDE.md)

**Implementation Plans:**
- 🚧 [Phase 4.5 Plan - Text & Image Overlay](docs/plans/PHASE_4_5_OVERLAY_PLAN.md)
- 🚧 [Phase 4.6 Plan - PDF Merge & Split](docs/plans/PHASE_4_6_MERGE_SPLIT_PLAN.md)
- 🚧 [Phase 5 Plan - Advanced Operations](docs/plans/PHASE_5_IMPLEMENTATION_PLAN.md)

**Strategic Documentation:**
- 🚀 [Future Improvements Roadmap](docs/roadmaps/FUTURE_IMPROVEMENTS_ROADMAP.md) ⭐ **NEW**
- 🗺️ [Migration Roadmap - Future Versions](docs/roadmaps/MIGRATION_ROADMAP.md)
- 📙 [Migration Guide v0.9 → v3.0](docs/guides/MIGRATION_GUIDE.md)
- 🏗️ [Package-Only Architecture](docs/architecture/PACKAGE_ONLY_ARCHITECTURE.md)
- 🔒 [Oracle 19c Compatibility Strategy](docs/architecture/ORACLE_19C_COMPATIBILITY_STRATEGY.md)
- 🔮 [Oracle 26ai & APEX 24.2 Modernization](docs/architecture/MODERNIZATION_ORACLE_26_APEX_24_2.md)

### 📋 Requirements

- **Oracle Database:** 🔴 **19c or higher** (19c fully supported indefinitely)
- **Privileges:** CREATE PROCEDURE, EXECUTE only
- **External Dependencies:** **NONE** - 100% self-contained package
- **Schema Objects:** **NONE** - No tables, types, sequences, or views required
- **Deployment:** 2 files only (PL_FPDF.pks + PL_FPDF.pkb)

**Optional Enhancements:**
  - Oracle 23ai/26ai: SQL Domains, Annotations, enhanced JSON (detected at runtime)
  - APEX 19.1+: `apex_string` utilities (Phase 4 page ranges)
  - APEX 24.2+: Document Generator integration

**Compatibility Guarantees:**
- ✅ All PL_FPDF versions (v3.x, v4.x, future) maintain full Oracle 19c compatibility
- ✅ Package-only architecture with zero external dependencies
- ✅ Simple deployment and uninstall (DROP PACKAGE)

### 📂 Project Structure

```
pl_fpdf/
├── README.md                  # This file
├── CHANGELOG.md               # Version history
├── PL_FPDF.pks                # Package specification (main file)
├── PL_FPDF.pkb                # Package body (main file)
├── deploy_all.sql             # Quick deployment script
├── docs/                      # 📚 Documentation
│   ├── api/                  # API references
│   │   └── API_REFERENCE.md
│   ├── architecture/         # Architecture & strategy docs
│   │   ├── PACKAGE_ONLY_ARCHITECTURE.md
│   │   ├── ORACLE_19C_COMPATIBILITY_STRATEGY.md
│   │   └── MODERNIZATION_ORACLE_26_APEX_24_2.md
│   ├── guides/               # User guides
│   │   ├── PHASE_4_GUIDE.md
│   │   ├── MIGRATION_GUIDE.md
│   │   ├── PERFORMANCE_TUNING.md
│   │   └── VALIDATION_GUIDE.md
│   ├── plans/                # Implementation plans
│   │   ├── PHASE_4_5_OVERLAY_PLAN.md
│   │   ├── PHASE_4_6_MERGE_SPLIT_PLAN.md
│   │   └── PHASE_5_IMPLEMENTATION_PLAN.md
│   ├── roadmaps/             # Strategic roadmaps
│   │   ├── FUTURE_IMPROVEMENTS_ROADMAP.md
│   │   └── MIGRATION_ROADMAP.md
│   ├── pt-br/                # Portuguese documentation
│   └── en/                   # English documentation
├── scripts/                   # 🔧 Utility scripts
│   ├── optimize_native_compile.sql
│   ├── recompile_package.sql
│   ├── phase_4_parser_starter.sql
│   ├── phase_4_types.sql
│   └── task_1_3_implementations.sql
├── tests/                     # ✅ Test & validation scripts
│   ├── test_runner.sql       # Main test runner
│   ├── run_all_validations.sql
│   ├── validate_phase_*.sql  # Phase 1-4 validation
│   └── test_phase_4_*.sql    # Phase 4 unit tests
└── extensions/                # 🔌 Optional extensions
    └── brazilian-payments/   # PIX/Boleto support
```

### 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Follow Trivadis PL/SQL Cop standards
4. Add tests for new features
5. Update documentation
6. Commit your changes (`git commit -m 'Add AmazingFeature'`)
7. Push to the branch (`git push origin feature/AmazingFeature`)
8. Open a Pull Request

### 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### 👥 Credits

- **Original FPDF (PHP):** Olivier PLATHEY
- **PHP FPDF Port:** Multiple contributors
- **PL/SQL Port:** Anton Scheffer, Marcel Amman, Pierre-Gilles Levallois
- **Phase 4 Implementation:** Maxwell Oliveira ([@maxwbh](https://github.com/maxwbh))

### 📞 Support

- 🐛 [Report Issues](https://github.com/Maxwbh/pl_fpdf/issues)
- 💬 [Discussions](https://github.com/Maxwbh/pl_fpdf/discussions)
- 📧 Email: maxwell@msbrasil.inf.br

---

## Português

### 📖 Visão Geral

**PL_FPDF** é uma poderosa biblioteca PL/SQL pura para **gerar e manipular documentos PDF** diretamente no Oracle Database. Sem dependências externas, Java ou serviços adicionais necessários.

**Versão Atual:** 3.0.0-alpha.5 ✨ (Fase 4 Completa)

### ✨ Recursos Principais

#### ✅ Fase 1-3: Geração de PDF (v2.0.0)
- Criar documentos PDF do zero
- Texto, formas, imagens (JPEG, PNG)
- Fontes: Padrão, TrueType, suporte Unicode
- Códigos de barras: Code 39, Code 128, EAN-13, QR Code
- Tabelas com auto-paginação
- Cabeçalhos e rodapés
- Suporte multi-página com páginas ilimitadas
- Rotação e formatos personalizados de página
- Compatível com Trivadis PL/SQL Cop

#### 🆕 Fase 4: Leitura e Manipulação de PDF (v3.0.0-alpha.5)
- **Carregar e Parsear PDFs** - Ler arquivos PDF existentes (PDF 1.4+)
- **Informações de Página** - Extrair detalhes (dimensões, rotação, recursos)
- **Rotação de Páginas** - Rotacionar páginas individuais (0°, 90°, 180°, 270°)
- **Remoção de Páginas** - Remover páginas indesejadas de PDFs
- **Marcas d'Água** - Adicionar marcas d'água de texto personalizáveis
- **Gerar PDF Modificado** - Gerar novo PDF com todas as modificações aplicadas

### 🚀 Início Rápido

#### Instalação

```sql
-- 1. Compilar especificação do pacote
@PL_FPDF.pks

-- 2. Compilar corpo do pacote
@PL_FPDF.pkb

-- 3. Verificar instalação
SELECT PL_FPDF.GetVersion() FROM DUAL;
-- Saída esperada: 3.0.0-a.5
```

#### Criar Seu Primeiro PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- Inicializar PDF
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Adicionar conteúdo
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Olá Mundo!', '0', 1, 'C');

  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.MultiCell(0, 5, 'Este é meu primeiro PDF criado com PL_FPDF!');

  -- Gerar PDF
  l_pdf := PL_FPDF.Output_Blob();

  -- Salvar na tabela
  INSERT INTO meus_documentos (id, pdf_blob, data_criacao)
  VALUES (1, l_pdf, SYSDATE);

  COMMIT;
END;
/
```

#### Modificar PDF Existente (Fase 4) 🆕

```sql
DECLARE
  l_pdf_original BLOB;
  l_pdf_modificado BLOB;
BEGIN
  -- Carregar PDF existente
  SELECT pdf_blob INTO l_pdf_original FROM meus_documentos WHERE id = 1;

  PL_FPDF.LoadPDF(l_pdf_original);

  -- Aplicar modificações
  PL_FPDF.RotatePage(1, 90);                           -- Rotacionar página 1
  PL_FPDF.RemovePage(3);                                -- Remover página 3
  PL_FPDF.AddWatermark('CONFIDENCIAL', 0.3, 45, 'ALL'); -- Adicionar marca d'água

  -- Gerar PDF modificado
  l_pdf_modificado := PL_FPDF.OutputModifiedPDF();

  -- Salvar PDF modificado
  UPDATE meus_documentos SET pdf_blob = l_pdf_modificado WHERE id = 1;
  COMMIT;

  PL_FPDF.ClearPDFCache();
END;
/
```

### 📚 Documentação

**Guias do Usuário:**
- 📘 [Referência Completa da API](docs/api/API_REFERENCE.md)
- 📗 [Guia Fase 4 - Manipulação de PDF](docs/guides/PHASE_4_GUIDE.md)
- 📕 [Otimização de Performance](docs/guides/PERFORMANCE_TUNING.md)
- 📔 [Guia de Validação e Testes](docs/guides/VALIDATION_GUIDE.md)

**Planos de Implementação:**
- 🚧 [Plano Fase 4.5 - Text & Image Overlay](docs/plans/PHASE_4_5_OVERLAY_PLAN.md)
- 🚧 [Plano Fase 4.6 - PDF Merge & Split](docs/plans/PHASE_4_6_MERGE_SPLIT_PLAN.md)
- 🚧 [Plano Fase 5 - Operações Avançadas](docs/plans/PHASE_5_IMPLEMENTATION_PLAN.md)

**Documentação Estratégica:**
- 🚀 [Roadmap de Melhorias Futuras](docs/roadmaps/FUTURE_IMPROVEMENTS_ROADMAP.md) ⭐ **NOVO**
- 🗺️ [Roadmap de Migração - Versões Futuras](docs/roadmaps/MIGRATION_ROADMAP.md)
- 📙 [Guia de Migração v0.9 → v3.0](docs/guides/MIGRATION_GUIDE.md)
- 🏗️ [Arquitetura Package-Only](docs/architecture/PACKAGE_ONLY_ARCHITECTURE.md)
- 🔒 [Estratégia Compatibilidade Oracle 19c](docs/architecture/ORACLE_19C_COMPATIBILITY_STRATEGY.md)
- 🔮 [Modernização Oracle 26ai & APEX 24.2](docs/architecture/MODERNIZATION_ORACLE_26_APEX_24_2.md)

### 📋 Requisitos

- **Oracle Database:** 11g ou superior (19c+ recomendado)
- **Privilégios:** CREATE PROCEDURE, EXECUTE
- **Opcional:** APEX 19.1+ para utilitários `apex_string` (ranges de páginas Fase 4)

### 📂 Estrutura do Projeto

```
pl_fpdf/
├── README.md                  # Este arquivo
├── CHANGELOG.md               # Histórico de versões
├── PL_FPDF.pks                # Especificação do pacote (arquivo principal)
├── PL_FPDF.pkb                # Corpo do pacote (arquivo principal)
├── deploy_all.sql             # Script de deploy rápido
├── docs/                      # 📚 Documentação
│   ├── api/                  # Referências da API
│   ├── architecture/         # Docs de arquitetura & estratégia
│   ├── guides/               # Guias do usuário
│   ├── plans/                # Planos de implementação
│   ├── roadmaps/             # Roadmaps estratégicos
│   ├── pt-br/                # Documentação em português
│   └── en/                   # Documentação em inglês
├── scripts/                   # 🔧 Scripts utilitários
│   ├── optimize_native_compile.sql
│   ├── recompile_package.sql
│   └── ...
├── tests/                     # ✅ Scripts de teste & validação
│   ├── test_runner.sql       # Executor principal de testes
│   ├── run_all_validations.sql
│   ├── validate_phase_*.sql  # Validação Fases 1-4
│   └── test_phase_4_*.sql    # Testes unitários Fase 4
└── extensions/                # 🔌 Extensões opcionais
    └── brazilian-payments/   # Suporte PIX/Boleto
```

### 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:
1. Faça fork do repositório
2. Crie uma branch para feature (`git checkout -b feature/RecursoIncrivel`)
3. Siga os padrões Trivadis PL/SQL Cop
4. Adicione testes para novos recursos
5. Atualize a documentação
6. Commit suas mudanças (`git commit -m 'Adiciona RecursoIncrivel'`)
7. Push para a branch (`git push origin feature/RecursoIncrivel`)
8. Abra um Pull Request

### 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

### 👥 Créditos

- **FPDF Original (PHP):** Olivier PLATHEY
- **Port PHP FPDF:** Múltiplos contribuidores
- **Port PL/SQL:** Anton Scheffer, Marcel Amman, Pierre-Gilles Levallois
- **Implementação Fase 4:** Maxwell Oliveira ([@maxwbh](https://github.com/maxwbh))

### 📞 Suporte

- 🐛 [Reportar Problemas](https://github.com/Maxwbh/pl_fpdf/issues)
- 💬 [Discussões](https://github.com/Maxwbh/pl_fpdf/discussions)
- 📧 Email: maxwell@msbrasil.inf.br

---

**Made with ❤️ in Brazil** 🇧🇷

**Last Updated:** January 2026
**Version:** 3.0.0-alpha.5
**Status:** Phase 4 Complete ✅
