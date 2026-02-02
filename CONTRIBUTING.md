# Contributing to PL_FPDF

First off, thank you for considering contributing to PL_FPDF! It's people like you that make PL_FPDF such a great tool for the Oracle community.

[**Leia em Português**](#contribuindo-para-o-pl_fpdf)

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Code Contributions](#code-contributions)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

---

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**How to submit a good bug report:**

1. Use a clear and descriptive title
2. Describe the exact steps to reproduce the problem
3. Include your Oracle Database version (19c, 23c, etc.)
4. Provide the PL_FPDF version you're using
5. Include any error messages or stack traces
6. Describe what you expected to happen vs. what actually happened

**Bug Report Template:**
```
**Environment:**
- Oracle Version:
- PL_FPDF Version:
- OS:

**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**

**Actual Behavior:**

**Error Messages:**
```

### Suggesting Features

We love new ideas! Feature suggestions help PL_FPDF grow.

**How to suggest a feature:**

1. Check if the feature has already been suggested
2. Clearly describe the use case
3. Explain why this feature would be useful to most users
4. Provide examples if possible

### Code Contributions

**Types of contributions we're looking for:**

- Bug fixes
- Performance improvements
- New PDF generation features
- Documentation improvements
- Test coverage improvements
- Example code and tutorials

---

## Development Setup

### Prerequisites

- Oracle Database 19c or 23c
- SQL*Plus or PL/SQL Developer
- Git

### Setting Up Your Environment

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/pl_fpdf.git
   cd pl_fpdf
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Install the package in your Oracle database**
   ```sql
   @PL_FPDF.pks
   @PL_FPDF.pkb
   ```

4. **Install the test framework** (optional but recommended)
   ```sql
   cd tests
   @install_tests.sql
   ```

5. **Run tests to ensure everything works**
   ```sql
   @run_all_tests.sql
   ```

---

## Pull Request Process

1. **Update documentation** if you're changing functionality
2. **Add tests** for new features
3. **Run all tests** and ensure they pass
4. **Update CHANGELOG.md** with your changes
5. **Submit your PR** with a clear description

### PR Checklist

- [ ] Code follows the style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated (if applicable)
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] CHANGELOG.md updated

### PR Title Format

Use a descriptive title:
- `feat: Add support for PDF/A format`
- `fix: Correct UTF-8 encoding for special characters`
- `docs: Update API reference for AddPage`
- `test: Add unit tests for image embedding`
- `perf: Optimize font loading performance`

---

## Style Guidelines

### PL/SQL Code Style

```sql
-- Use uppercase for keywords
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

-- Use meaningful variable names with prefixes
-- l_ for local variables
-- p_ for parameters
-- g_ for global/package variables
-- c_ for constants

PROCEDURE my_procedure(
    p_input_value    IN VARCHAR2,
    p_optional_param IN NUMBER DEFAULT NULL
) IS
    l_local_var VARCHAR2(100);
    c_constant  CONSTANT NUMBER := 100;
BEGIN
    -- Add comments for complex logic
    -- ...
END my_procedure;
```

### Documentation Style

- Use clear, concise language
- Include code examples where applicable
- Keep both English and Portuguese documentation in sync

### Commit Messages

Follow conventional commits:
```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## Community

- **Issues**: [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Maxwbh/pl_fpdf/discussions)
- **Maintainer**: Maxwell Oliveira ([@maxwbh](https://github.com/maxwbh))

---

## Recognition

Contributors will be recognized in:
- The project README
- Release notes
- The CONTRIBUTORS file

---

# Contribuindo para o PL_FPDF

Primeiramente, obrigado por considerar contribuir com o PL_FPDF! São pessoas como você que tornam o PL_FPDF uma ferramenta tão útil para a comunidade Oracle.

## Como Posso Contribuir?

### Reportando Bugs

Antes de criar relatórios de bugs, verifique as issues existentes para evitar duplicatas.

**Como enviar um bom relatório de bug:**

1. Use um título claro e descritivo
2. Descreva os passos exatos para reproduzir o problema
3. Inclua sua versão do Oracle Database (19c, 23c, etc.)
4. Forneça a versão do PL_FPDF que está usando
5. Inclua mensagens de erro ou stack traces
6. Descreva o que você esperava vs. o que realmente aconteceu

### Sugerindo Funcionalidades

Adoramos novas ideias! Sugestões de funcionalidades ajudam o PL_FPDF a crescer.

### Contribuições de Código

**Tipos de contribuições que procuramos:**

- Correções de bugs
- Melhorias de performance
- Novas funcionalidades de geração de PDF
- Melhorias na documentação
- Aumento da cobertura de testes
- Código de exemplo e tutoriais

## Processo de Pull Request

1. **Atualize a documentação** se estiver alterando funcionalidades
2. **Adicione testes** para novas funcionalidades
3. **Execute todos os testes** e garanta que passem
4. **Atualize o CHANGELOG.md** com suas alterações
5. **Envie seu PR** com uma descrição clara

---

**Obrigado por contribuir!**
