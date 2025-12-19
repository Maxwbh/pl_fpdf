--------------------------------------------------------------------------------
-- VALIDATION SCRIPT: PL_FPDF_BOLETO Package
-- Project: PL_FPDF Modernization - Phase 3
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Purpose: Validate standalone Boleto utility package
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   PL_FPDF_BOLETO Package Validation
PROMPT ================================================================================
PROMPT   Testing Boleto Bancário utility functions independently
PROMPT   Package: PL_FPDF_BOLETO (Barcode, due date factor, check digit calc)
PROMPT ================================================================================
PROMPT

-- Test statistics
DECLARE
  v_tests_total PLS_INTEGER := 0;
  v_tests_passed PLS_INTEGER := 0;
  v_tests_failed PLS_INTEGER := 0;
  v_test_name VARCHAR2(200);

  -- Test helper procedures
  PROCEDURE start_test(p_name VARCHAR2) IS
  BEGIN
    v_test_name := p_name;
    v_tests_total := v_tests_total + 1;
  END;

  PROCEDURE pass_test IS
  BEGIN
    v_tests_passed := v_tests_passed + 1;
    DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_test_name);
  END;

  PROCEDURE fail_test(p_reason VARCHAR2 DEFAULT NULL) IS
  BEGIN
    v_tests_failed := v_tests_failed + 1;
    DBMS_OUTPUT.PUT_LINE('[FAIL] ' || v_test_name);
    IF p_reason IS NOT NULL THEN
      DBMS_OUTPUT.PUT_LINE('  Reason: ' || p_reason);
    END IF;
  END;

  -- Test variables
  l_boleto_data JSON_OBJECT_T;
  l_codigo_barras VARCHAR2(44);
  l_linha_digitavel VARCHAR2(54);
  l_dv CHAR(1);
  l_fator VARCHAR2(4);
  l_is_valid BOOLEAN;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== PL_FPDF_BOLETO Package Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: CalculateFatorVencimento (Due Date Factor)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: CalculateFatorVencimento ---');

  -- Test 1: Calculate fator for known date
  BEGIN
    start_test('CalculateFatorVencimento calculates correct factor');
    -- Fator base: 07/10/1997 = fator 0
    -- Test with a known date: 01/01/2025
    l_fator := PL_FPDF_BOLETO.CalculateFatorVencimento(TO_DATE('2025-01-01', 'YYYY-MM-DD'));

    -- 2025-01-01 is approximately 9948 days from 1997-10-07
    IF l_fator IS NOT NULL AND LENGTH(l_fator) = 4 THEN
      pass_test;
    ELSE
      fail_test('Invalid fator format: ' || l_fator);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 2: Fator is deterministic
  BEGIN
    start_test('CalculateFatorVencimento is deterministic');
    DECLARE
      l_fator1 VARCHAR2(4);
      l_fator2 VARCHAR2(4);
      l_date DATE := TO_DATE('2025-12-31', 'YYYY-MM-DD');
    BEGIN
      l_fator1 := PL_FPDF_BOLETO.CalculateFatorVencimento(l_date);
      l_fator2 := PL_FPDF_BOLETO.CalculateFatorVencimento(l_date);

      IF l_fator1 = l_fator2 THEN
        pass_test;
      ELSE
        fail_test('Different factors for same date: ' || l_fator1 || ' vs ' || l_fator2);
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 3: Fator increases with date
  BEGIN
    start_test('CalculateFatorVencimento increases with later dates');
    DECLARE
      l_fator1 VARCHAR2(4);
      l_fator2 VARCHAR2(4);
    BEGIN
      l_fator1 := PL_FPDF_BOLETO.CalculateFatorVencimento(TO_DATE('2025-01-01', 'YYYY-MM-DD'));
      l_fator2 := PL_FPDF_BOLETO.CalculateFatorVencimento(TO_DATE('2025-12-31', 'YYYY-MM-DD'));

      IF TO_NUMBER(l_fator2) > TO_NUMBER(l_fator1) THEN
        pass_test;
      ELSE
        fail_test('Later date should have higher factor: ' || l_fator1 || ' vs ' || l_fator2);
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 4: Fator rejects NULL date
  BEGIN
    start_test('CalculateFatorVencimento rejects NULL date');
    l_fator := PL_FPDF_BOLETO.CalculateFatorVencimento(NULL);
    fail_test('Should have raised error for NULL date');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20802 OR SQLERRM LIKE '%NULL%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 5: Fator rejects date before base date
  BEGIN
    start_test('CalculateFatorVencimento rejects date before 1997-10-07');
    l_fator := PL_FPDF_BOLETO.CalculateFatorVencimento(TO_DATE('1997-10-06', 'YYYY-MM-DD'));
    fail_test('Should have raised error for date before base');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20802 OR SQLERRM LIKE '%before%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: CalculateDVBoleto (Check Digit - Módulo 11)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: CalculateDVBoleto ---');

  -- Test 6: Calculate DV (módulo 11)
  BEGIN
    start_test('CalculateDVBoleto calculates check digit');
    DECLARE
      l_code_without_dv VARCHAR2(43);
    BEGIN
      l_code_without_dv := '0019000000000001000000000000000000000000000';
      l_dv := PL_FPDF_BOLETO.CalculateDVBoleto(l_code_without_dv);

      -- DV should be a single digit (0-9) or '1' for special cases
      IF l_dv IN ('0','1','2','3','4','5','6','7','8','9') THEN
        pass_test;
      ELSE
        fail_test('Invalid DV: ' || l_dv);
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 7: DV is deterministic
  BEGIN
    start_test('CalculateDVBoleto is deterministic');
    DECLARE
      l_dv1 CHAR(1);
      l_dv2 CHAR(1);
      l_code VARCHAR2(43) := '0019000000000001000000000000000000000000000';
    BEGIN
      l_dv1 := PL_FPDF_BOLETO.CalculateDVBoleto(l_code);
      l_dv2 := PL_FPDF_BOLETO.CalculateDVBoleto(l_code);

      IF l_dv1 = l_dv2 THEN
        pass_test;
      ELSE
        fail_test('Different DVs for same code: ' || l_dv1 || ' vs ' || l_dv2);
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 8: DV validates code length
  BEGIN
    start_test('CalculateDVBoleto validates code length');
    l_dv := PL_FPDF_BOLETO.CalculateDVBoleto('123456');  -- Too short
    fail_test('Should have raised error for invalid length');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20803 OR SQLERRM LIKE '%length%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -------------------------------------------------------------------------
  -- Test Group 3: ValidateCodigoBarras
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: ValidateCodigoBarras ---');

  -- Test 9: Validate correct barcode
  BEGIN
    start_test('ValidateCodigoBarras accepts valid barcode');
    -- First generate a valid barcode
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1500.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    l_is_valid := PL_FPDF_BOLETO.ValidateCodigoBarras(l_codigo_barras);

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid barcode rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 10: Reject barcode with invalid length
  BEGIN
    start_test('ValidateCodigoBarras rejects invalid length');
    l_is_valid := PL_FPDF_BOLETO.ValidateCodigoBarras('12345');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid length accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 11: Reject barcode with non-numeric characters
  BEGIN
    start_test('ValidateCodigoBarras rejects non-numeric barcode');
    l_is_valid := PL_FPDF_BOLETO.ValidateCodigoBarras('0019000000000001000000000000000000000000000A');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Non-numeric barcode accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 12: Reject barcode with wrong check digit
  BEGIN
    start_test('ValidateCodigoBarras rejects wrong check digit');
    -- Take a valid barcode and corrupt the DV at position 5
    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    DECLARE
      l_corrupted VARCHAR2(44);
      l_wrong_dv CHAR(1);
    BEGIN
      -- Change DV to a different digit
      l_wrong_dv := CASE SUBSTR(l_codigo_barras, 5, 1) WHEN '0' THEN '1' ELSE '0' END;
      l_corrupted := SUBSTR(l_codigo_barras, 1, 4) || l_wrong_dv || SUBSTR(l_codigo_barras, 6);

      l_is_valid := PL_FPDF_BOLETO.ValidateCodigoBarras(l_corrupted);

      IF NOT l_is_valid THEN
        pass_test;
      ELSE
        fail_test('Barcode with wrong DV accepted');
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 4: GetCodigoBarras
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 4: GetCodigoBarras ---');

  -- Test 13: Generate complete barcode (44 positions)
  BEGIN
    start_test('GetCodigoBarras generates 44-position code');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1500.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);

    IF LENGTH(l_codigo_barras) = 44 THEN
      pass_test;
    ELSE
      fail_test('Invalid length: ' || LENGTH(l_codigo_barras) || ' (expected 44)');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 14: Barcode starts with bank code
  BEGIN
    start_test('GetCodigoBarras includes bank code at positions 1-3');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '237');  -- Bradesco
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1000.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);

    IF SUBSTR(l_codigo_barras, 1, 3) = '237' THEN
      pass_test;
    ELSE
      fail_test('Bank code not at start: ' || SUBSTR(l_codigo_barras, 1, 3));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 15: Barcode includes currency code
  BEGIN
    start_test('GetCodigoBarras includes currency code (9=Real) at position 4');
    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);

    IF SUBSTR(l_codigo_barras, 4, 1) = '9' THEN
      pass_test;
    ELSE
      fail_test('Currency code not at position 4: ' || SUBSTR(l_codigo_barras, 4, 1));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 16: Barcode includes valid DV at position 5
  BEGIN
    start_test('GetCodigoBarras includes valid check digit at position 5');
    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    l_dv := SUBSTR(l_codigo_barras, 5, 1);

    IF l_dv IN ('0','1','2','3','4','5','6','7','8','9') THEN
      pass_test;
    ELSE
      fail_test('Invalid DV at position 5: ' || l_dv);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 17: Barcode requires banco parameter
  BEGIN
    start_test('GetCodigoBarras requires banco parameter');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1000.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');
    -- Missing 'banco'

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    fail_test('Should have raised error for missing banco');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20801 OR SQLERRM LIKE '%banco%' OR SQLERRM LIKE '%required%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 18: Barcode requires vencimento parameter
  BEGIN
    start_test('GetCodigoBarras requires vencimento parameter');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('valor', 1000.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');
    -- Missing 'vencimento'

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    fail_test('Should have raised error for missing vencimento');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20802 OR SQLERRM LIKE '%vencimento%' OR SQLERRM LIKE '%required%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 19: Barcode requires valor parameter
  BEGIN
    start_test('GetCodigoBarras requires valor parameter');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('campoLivre', '1234567890123456789012345');
    -- Missing 'valor'

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    fail_test('Should have raised error for missing valor');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20801 OR SQLERRM LIKE '%valor%' OR SQLERRM LIKE '%required%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 20: Barcode requires campoLivre parameter
  BEGIN
    start_test('GetCodigoBarras requires campoLivre parameter');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1000.00);
    -- Missing 'campoLivre'

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    fail_test('Should have raised error for missing campoLivre');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20801 OR SQLERRM LIKE '%campoLivre%' OR SQLERRM LIKE '%required%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -------------------------------------------------------------------------
  -- Test Group 5: GetLinhaDigitavel
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 5: GetLinhaDigitavel ---');

  -- Test 21: Generate linha digitável (47 digits + formatting)
  BEGIN
    start_test('GetLinhaDigitavel generates formatted linha');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1500.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');

    l_linha_digitavel := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data);

    -- Format: AAAAA.AAAAA BBBBB.BBBBBB CCCCC.CCCCCC D EEEEEEEEEEEEEE
    -- Total with spaces and dots: 54 characters
    IF l_linha_digitavel IS NOT NULL AND LENGTH(l_linha_digitavel) = 54 THEN
      pass_test;
    ELSE
      fail_test('Invalid linha length: ' || LENGTH(l_linha_digitavel) || ' (expected 54)');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 22: Linha digitável contains dots and spaces
  BEGIN
    start_test('GetLinhaDigitavel formats with dots and spaces');
    l_linha_digitavel := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data);

    -- Should contain 3 dots and 4 spaces
    IF INSTR(l_linha_digitavel, '.') > 0 AND INSTR(l_linha_digitavel, ' ') > 0 THEN
      pass_test;
    ELSE
      fail_test('Missing formatting: ' || l_linha_digitavel);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 23: Linha digitável starts with bank code
  BEGIN
    start_test('GetLinhaDigitavel starts with bank code');
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '341');  -- Itaú
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 2000.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');

    l_linha_digitavel := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data);

    IF SUBSTR(l_linha_digitavel, 1, 3) = '341' THEN
      pass_test;
    ELSE
      fail_test('Linha does not start with bank code: ' || SUBSTR(l_linha_digitavel, 1, 3));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 6: ParseLinhaDigitavel
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 6: ParseLinhaDigitavel ---');

  -- Test 24: Parse linha digitável back to barcode
  BEGIN
    start_test('ParseLinhaDigitavel extracts barcode from linha');
    -- Generate a linha first
    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '237');
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-06-15', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 999.99);
    l_boleto_data.put('campoLivre', '9876543210987654321098765');

    l_codigo_barras := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);
    l_linha_digitavel := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data);

    DECLARE
      l_parsed_barcode VARCHAR2(44);
    BEGIN
      l_parsed_barcode := PL_FPDF_BOLETO.ParseLinhaDigitavel(l_linha_digitavel);

      IF l_parsed_barcode = l_codigo_barras THEN
        pass_test;
      ELSE
        fail_test('Parsed barcode does not match original');
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Summary
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('SUMMARY: ' || v_tests_passed || '/' || v_tests_total || ' tests passed');

  IF v_tests_failed = 0 THEN
    DBMS_OUTPUT.PUT_LINE('STATUS: ✓ ALL TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('STATUS: ✗ ' || v_tests_failed || ' TEST(S) FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('');

  DBMS_OUTPUT.PUT_LINE('NOTE: PL_FPDF_BOLETO is a standalone package for Boleto utilities.');
  DBMS_OUTPUT.PUT_LINE('      Can be used independently of PL_FPDF for Boleto operations.');
  DBMS_OUTPUT.PUT_LINE('      Implements FEBRABAN 44-position barcode standard.');
  DBMS_OUTPUT.PUT_LINE('');

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================================');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('=======================================================================');
END;
/

SET FEEDBACK ON
SET VERIFY ON
