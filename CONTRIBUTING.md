# Contributing to PL_FPDF

First off, thank you for considering contributing to PL_FPDF! 🎉

It's people like you that make PL_FPDF such a great tool for the Oracle community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to maxwell@msbrasil.inf.br.

---

## 🤝 How Can I Contribute?

### Reporting Bugs 🐛

Before creating bug reports, please check the [existing issues](https://github.com/Maxwbh/pl_fpdf/issues) to avoid duplicates.

**When creating a bug report, include:**

- **Clear title and description**
- **Oracle Database version** (e.g., 19c, 21c, 23ai)
- **PL_FPDF version** (check with `SELECT PL_FPDF.GetVersion() FROM DUAL;`)
- **Steps to reproduce** the issue
- **Expected behavior** vs **actual behavior**
- **Sample code** that demonstrates the problem
- **Error messages** (complete stack trace if available)
- **Sample PDF** if relevant (anonymize sensitive data)

**Template:**

```markdown
## Bug Description
[Clear description of the bug]

## Environment
- Oracle Database: 19c
- PL_FPDF Version: 3.0.0-b.2
- APEX Version (if applicable): 24.1

## Steps to Reproduce
1. Load PDF with LoadPDF()
2. Call RotatePage(1, 90)
3. Call OutputModifiedPDF()

## Expected Behavior
Page should be rotated 90 degrees clockwise

## Actual Behavior
Error: ORA-XXXXX [error message]

## Sample Code
\`\`\`sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- Your code here
END;
/
\`\`\`
```

### Suggesting Enhancements 💡

Enhancement suggestions are welcome! Please create an issue with:

- **Clear title** describing the enhancement
- **Detailed description** of the proposed functionality
- **Use cases** - why is this useful?
- **Proposed API** - how would users interact with it?
- **Oracle compatibility** - maintains Oracle 19c support?
- **Package-only** - can be implemented without external objects?

**Template:**

```markdown
## Enhancement Title
Add support for PDF bookmarks navigation

## Description
Currently PL_FPDF can read PDFs but doesn't expose bookmark information...

## Use Cases
1. Extract TOC from PDF documents
2. Navigate to specific sections programmatically
3. Preserve bookmarks when merging PDFs

## Proposed API
\`\`\`sql
FUNCTION GetBookmarks RETURN JSON_ARRAY_T;
PROCEDURE AddBookmark(p_title VARCHAR2, p_page NUMBER);
\`\`\`

## Compatibility
- ✅ Oracle 19c compatible
- ✅ Package-only implementation (using collections)
- ✅ No external dependencies

## Complexity
Medium - estimated 1-2 weeks
```

### Your First Code Contribution 🚀

Unsure where to begin? Look for issues labeled:

- `good first issue` - Simple issues perfect for newcomers
- `help wanted` - Issues where we'd appreciate community help
- `documentation` - Documentation improvements
- `enhancement` - New features to implement

---

## 🛠️ Development Setup

### Prerequisites

- Oracle Database 19c or higher
- SQL*Plus or SQL Developer
- Git
- (Optional) APEX 19.1+ for advanced features

### Setup Steps

1. **Fork the repository**

```bash
git clone https://github.com/YOUR_USERNAME/pl_fpdf.git
cd pl_fpdf
```

2. **Create development environment**

```sql
-- Connect to your Oracle database
sqlplus your_user/your_password@your_db

-- Install PL_FPDF
@PL_FPDF.pks
@PL_FPDF.pkb

-- Verify installation
SELECT PL_FPDF.GetVersion() FROM DUAL;
```

3. **Install test suite**

```sql
@tests/install_tests.sql
```

4. **Run tests to ensure everything works**

```sql
@tests/test_runner.sql
```

Expected output: All tests passing ✅

---

## 📏 Coding Standards

We follow **Trivadis PL/SQL & SQL Coding Guidelines** with some additional rules:

### Naming Conventions

```sql
-- Constants: UPPER_CASE with c_ prefix
c_MAX_PAGES CONSTANT PLS_INTEGER := 10000;

-- Variables: lower_case with l_ prefix (local) or g_ (global/package)
l_page_count PLS_INTEGER;
g_pdf_cache pdf_cache_type;

-- Parameters: lower_case with p_ prefix
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_angle NUMBER);

-- Types: PascalCase with _t suffix
TYPE page_info_t IS RECORD (...);

-- Procedures/Functions: PascalCase
FUNCTION GetPageCount RETURN PLS_INTEGER;
```

### Code Style

```sql
-- Good: Clear, documented, well-structured
PROCEDURE AddWatermark(
  p_text          VARCHAR2,
  p_opacity       NUMBER DEFAULT 0.5,
  p_angle         NUMBER DEFAULT 45,
  p_pages         VARCHAR2 DEFAULT 'ALL'
) IS
  l_page_count PLS_INTEGER;
  l_page_list  page_list_t;
BEGIN
  -- Validate input
  IF p_opacity NOT BETWEEN 0 AND 1 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Opacity must be between 0 and 1');
  END IF;

  -- Parse page specification
  l_page_list := parse_page_spec(p_pages);

  -- Apply watermark to each page
  FOR i IN 1..l_page_list.COUNT LOOP
    apply_watermark_to_page(
      p_page_num => l_page_list(i),
      p_text     => p_text,
      p_opacity  => p_opacity,
      p_angle    => p_angle
    );
  END LOOP;
END AddWatermark;

-- Bad: No validation, unclear, no comments
PROCEDURE AddWatermark(t VARCHAR2, o NUMBER, a NUMBER, p VARCHAR2) IS
BEGIN
  FOR i IN 1..parse(p).COUNT LOOP
    do_watermark(i,t,o,a);
  END LOOP;
END;
```

### Documentation

**Every public procedure/function must have:**

```sql
/**
 * Adds a text watermark to specified pages of the loaded PDF.
 *
 * @param p_text      Watermark text to display
 * @param p_opacity   Opacity level (0.0 = transparent, 1.0 = opaque)
 * @param p_angle     Rotation angle in degrees (typically 45)
 * @param p_pages     Page specification: '1', '1-3', '1,3,5', or 'ALL'
 *
 * @raises -20001 Invalid opacity value (must be 0-1)
 * @raises -20002 Invalid page specification
 * @raises -20003 No PDF loaded
 *
 * @example
 *   PL_FPDF.LoadPDF(l_pdf_blob);
 *   PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');
 *   l_result := PL_FPDF.OutputModifiedPDF();
 *
 * @since 3.0.0 (Phase 4.3)
 */
PROCEDURE AddWatermark(
  p_text          VARCHAR2,
  p_opacity       NUMBER DEFAULT 0.5,
  p_angle         NUMBER DEFAULT 45,
  p_pages         VARCHAR2 DEFAULT 'ALL'
);
```

### Error Handling

```sql
-- Use custom error codes in -20000 to -20999 range
-- Document error codes in docs/ERROR_CODES.md

-- Good: Specific, documented error
IF NOT is_pdf_loaded() THEN
  RAISE_APPLICATION_ERROR(
    -20003,
    'No PDF loaded. Call LoadPDF() first.'
  );
END IF;

-- Bad: Generic error
IF NOT is_pdf_loaded() THEN
  RAISE_APPLICATION_ERROR(-20000, 'Error');
END IF;
```

### Package-Only Architecture

**CRITICAL:** No external database objects allowed!

```sql
-- ✅ CORRECT: Use package collections
TYPE pdf_cache_t IS TABLE OF BLOB INDEX BY VARCHAR2(50);
g_loaded_pdfs pdf_cache_t;

-- ❌ WRONG: Don't create tables
CREATE TABLE pdf_cache (
  pdf_id VARCHAR2(50),
  pdf_blob BLOB
);

-- ✅ CORRECT: Package types
TYPE page_info_t IS RECORD (
  page_number PLS_INTEGER,
  width NUMBER,
  height NUMBER
);

-- ❌ WRONG: Don't create schema-level types
CREATE TYPE page_info_obj AS OBJECT (
  page_number NUMBER,
  width NUMBER,
  height NUMBER
);
```

---

## 📝 Commit Messages

We follow **Conventional Commits** specification:

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Adding/updating tests
- `chore`: Build process, dependencies, etc.

### Examples

```bash
# Good commit messages
feat(phase-4): Add PDF merge functionality

Implemented MergePDFs() procedure that combines multiple
loaded PDFs into a single document. Supports page range
selection and maintains proper page numbering.

Closes #42

---

fix(watermark): Correct opacity calculation for dark text

Fixed bug where dark watermark text appeared too light.
Updated opacity blending algorithm to properly handle
RGB values below 128.

Fixes #89

---

docs(readme): Add comparison with other PDF libraries

Added comprehensive comparison table showing PL_FPDF
advantages over Java-based solutions for Oracle environments.

---

perf(parser): Optimize page tree parsing by 40%

Replaced recursive algorithm with iterative approach using
package collection as stack. Reduces function call overhead
and improves performance on PDFs with 100+ pages.

Benchmark: 250ms -> 150ms for 100-page PDF

---

test(phase-4.5): Add overlay positioning tests

Added 15 new test cases covering edge cases in text/image
overlay positioning, including negative coordinates and
out-of-bounds scenarios.
```

```bash
# Bad commit messages
fix: stuff
update code
changes
WIP
asdf
```

---

## 🔄 Pull Request Process

### Before Submitting

1. ✅ **Create feature branch**
   ```bash
   git checkout -b feature/amazing-new-feature
   ```

2. ✅ **Follow coding standards** (Trivadis PL/SQL Cop)

3. ✅ **Add tests** for new functionality
   ```sql
   -- Create test_my_feature.sql in tests/
   @tests/test_my_feature.sql
   ```

4. ✅ **Update documentation**
   - Update `docs/api/API_REFERENCE.md`
   - Update `CHANGELOG.md`
   - Add examples if applicable

5. ✅ **Run all tests**
   ```sql
   @tests/test_runner.sql
   ```

   All tests must pass ✅

6. ✅ **Check Oracle 19c compatibility**
   ```sql
   -- Test on Oracle 19c instance
   -- Ensure no 21c/23ai-specific features used
   ```

7. ✅ **Verify package-only architecture**
   ```bash
   # Should only contain package files
   ls -la *.pks *.pkb

   # No DDL for tables, types, sequences
   grep -i "CREATE TABLE\|CREATE TYPE\|CREATE SEQUENCE" *.sql
   ```

### Pull Request Template

When creating PR, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix/feature causing existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] All existing tests pass
- [ ] Added new tests for new functionality
- [ ] Tested on Oracle 19c
- [ ] Tested on Oracle 21c/23ai (if applicable)

## Checklist
- [ ] Code follows Trivadis PL/SQL Cop guidelines
- [ ] Self-reviewed code
- [ ] Commented complex logic
- [ ] Updated documentation
- [ ] Updated CHANGELOG.md
- [ ] No external dependencies added
- [ ] Package-only architecture maintained
- [ ] Oracle 19c compatible

## Related Issues
Closes #123
Relates to #456

## Screenshots (if applicable)
[Add screenshots for visual changes]
```

### Review Process

1. **Automated checks** run on PR creation
2. **Maintainer review** within 3-5 business days
3. **Feedback addressed** by contributor
4. **Approval** from at least 1 maintainer
5. **Merge** to main branch
6. **Release** in next version

### After Merge

- Your contribution will be credited in `CHANGELOG.md`
- Added to contributors list in README
- Included in next release notes

---

## ✅ Testing Guidelines

### Test Structure

```sql
-- tests/test_my_feature.sql
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  PROCEDURE test(
    p_name VARCHAR2,
    p_condition BOOLEAN,
    p_message VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_condition THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ PASS: ' || p_name);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ FAIL: ' || p_name);
      IF p_message IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  Reason: ' || p_message);
      END IF;
    END IF;
  END test;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Test My Feature ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 1: Basic functionality
  test(
    'Feature works with valid input',
    my_function('valid') = expected_result,
    'Expected ' || expected_result || ', got ' || my_function('valid')
  );

  -- Test 2: Error handling
  BEGIN
    my_function(NULL);
    test('Should raise error for NULL input', FALSE);
  EXCEPTION
    WHEN OTHERS THEN
      test('Raises error for NULL input', SQLCODE = -20001);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Summary ===');
  DBMS_OUTPUT.PUT_LINE('Total: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Pass:  ' || l_pass_count || ' (' ||
    ROUND(l_pass_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Fail:  ' || l_fail_count);

  IF l_fail_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20999, 'Tests failed');
  END IF;
END;
/
```

### Test Coverage

Aim for **>80% code coverage** for new features:

- ✅ Happy path scenarios
- ✅ Edge cases (empty, NULL, boundary values)
- ✅ Error conditions
- ✅ Performance (for critical paths)
- ✅ Oracle version compatibility

---

## 📚 Documentation

### What to Document

1. **API Reference** (`docs/api/API_REFERENCE.md`)
   - All public procedures/functions
   - Parameters and types
   - Return values
   - Exceptions
   - Examples

2. **User Guides** (`docs/guides/`)
   - Step-by-step tutorials
   - Common use cases
   - Best practices

3. **Code Comments**
   - Complex algorithms
   - Performance considerations
   - Oracle version-specific code

### Documentation Style

- Clear, concise language
- Code examples for every feature
- Screenshots where helpful
- Both English and Portuguese (if possible)

---

## 🎯 Getting Help

- 💬 [GitHub Discussions](https://github.com/Maxwbh/pl_fpdf/discussions) - Q&A, ideas
- 🐛 [GitHub Issues](https://github.com/Maxwbh/pl_fpdf/issues) - Bugs, features
- 📧 Email: maxwell@msbrasil.inf.br

---

## 🏆 Recognition

Contributors are recognized in:

- `CHANGELOG.md` for each release
- GitHub contributors graph
- Special mentions in release notes for major contributions

---

## 📄 License

By contributing to PL_FPDF, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for making PL_FPDF better!** 🚀

Every contribution, no matter how small, makes a difference. We appreciate your time and effort in improving this project for the Oracle community.

Happy coding! 💻
