# PL_FPDF Test Suite

**Version:** 3.2.0

## Quick Start

```sql
-- Run all tests
@tests/run_all_tests.sql

-- Run specific phase
@tests/test_phase_security.sql
```

---

## Test Files

| File | Description | Status |
|------|-------------|--------|
| `run_all_tests.sql` | Master runner | - |
| `validate_phases_1_3.sql` | PDF generation | ✅ |
| `test_phase_4_*.sql` | PDF manipulation | ✅ |
| `test_phase_security.sql` | Encryption (v3.2) | ✅ |

---

## Test Structure

```
tests/
├── run_all_tests.sql           # Run all
├── validate_phase_1.sql        # Phase 1: Basic PDF
├── validate_phase_2.sql        # Phase 2: Security
├── validate_phase_3.sql        # Phase 3: Advanced
├── validate_phases_1_3.sql     # Phases 1-3 combined
├── test_phase_4_*.sql          # Phase 4: PDF manipulation
├── test_phase_security.sql     # Phase 5: Encryption
└── validate_phase_4_complete.sql
```

---

## Requirements

- Oracle 19c+
- PL_FPDF installed
- `SET SERVEROUTPUT ON SIZE UNLIMITED`

---

## Writing Tests

```sql
DECLARE
  l_pass PLS_INTEGER := 0;
  l_fail PLS_INTEGER := 0;
BEGIN
  -- Test
  BEGIN
    PL_FPDF.Init;
    l_pass := l_pass + 1;
    DBMS_OUTPUT.PUT_LINE('PASS: Init');
  EXCEPTION
    WHEN OTHERS THEN
      l_fail := l_fail + 1;
      DBMS_OUTPUT.PUT_LINE('FAIL: Init - ' || SQLERRM);
  END;
  
  -- Summary
  DBMS_OUTPUT.PUT_LINE('Passed: ' || l_pass || ', Failed: ' || l_fail);
END;
/
```
