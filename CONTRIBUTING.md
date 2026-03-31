# Contributing to PL_FPDF

## Quick Start

1. Fork the repository
2. Create your branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`@tests/run_all_tests.sql`)
5. Commit (`git commit -m 'feat: add new feature'`)
6. Push (`git push origin feature/my-feature`)
7. Open a Pull Request

---

## Development Setup

```sql
-- Requirements
-- Oracle Database 19c or higher
-- DBMS_CRYPTO grant (for encryption features)

-- Install
@deploy_all.sql

-- Verify
SELECT PL_FPDF.co_version FROM DUAL;
```

---

## Coding Standards

- **PL/SQL Style:** Follow existing code patterns
- **Variables:** Use `l_` prefix for locals, `p_` for parameters, `g_` for globals
- **Comments:** Only when logic isn't self-evident
- **Tests:** Add tests for new features

---

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add PDF bookmarks support
fix: correct page rotation calculation
docs: update API reference
test: add merge tests
refactor: simplify encryption logic
```

---

## Pull Request Checklist

- [ ] Tests pass (`@tests/run_all_tests.sql`)
- [ ] Code follows existing style
- [ ] Oracle 19c compatible
- [ ] Package-only (no external objects)
- [ ] Documentation updated if needed

---

## Reporting Issues

Open an issue with:
- Oracle version
- PL_FPDF version (`SELECT PL_FPDF.co_version FROM DUAL`)
- Steps to reproduce
- Error message

---

## Contact

- **Author:** Maxwell da Silva Oliveira (@maxwbh)
- **Email:** maxwbh@gmail.com
