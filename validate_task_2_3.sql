--------------------------------------------------------------------------------
-- Task 2.3 Validation Tests: DBMS_ASSERT and Input Validation
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-18
--------------------------------------------------------------------------------
-- Validates input validation with range checks and parameter validation
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

DECLARE
  l_test_count NUMBER := 0;
  l_pass_count NUMBER := 0;
  l_fail_count NUMBER := 0;
  l_test_name VARCHAR2(200);

  PROCEDURE start_test(p_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    l_test_name := p_name;
  END;

  PROCEDURE pass_test IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('[PASS] Test ' || l_test_count || ': ' || l_test_name);
  END;

  PROCEDURE fail_test(p_reason VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('[FAIL] Test ' || l_test_count || ': ' || l_test_name);
    IF p_reason IS NOT NULL THEN
      DBMS_OUTPUT.PUT_LINE('  Reason: ' || p_reason);
    END IF;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Task 2.3 Validation: Input Validation ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: SetFont Validation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: SetFont Validation ---');

  -- Test 1: SetFont accepts valid font family
  BEGIN
    start_test('SetFont accepts valid font family');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Helvetica', 'N', 12);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 2: SetFont rejects font family name too long
  BEGIN
    start_test('SetFont rejects font family > 80 chars');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont(RPAD('X', 81, 'X'), 'N', 12);
      fail_test('Exception not raised for long font name');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20100 AND SQLERRM LIKE '%Font family name too long%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 3: SetFont rejects invalid font style
  BEGIN
    start_test('SetFont rejects invalid font style');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Helvetica', 'INVALID', 12);
      fail_test('Exception not raised for invalid style');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20100 AND SQLERRM LIKE '%Invalid font style%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 4: SetFont accepts valid font styles
  BEGIN
    start_test('SetFont accepts valid font styles (B, I, BI)');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Helvetica', 'B', 12);
    PL_FPDF.SetFont('Helvetica', 'I', 12);
    PL_FPDF.SetFont('Helvetica', 'BI', 12);
    PL_FPDF.SetFont('Helvetica', '', 12);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 5: SetFont rejects negative font size
  BEGIN
    start_test('SetFont rejects negative font size');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Helvetica', 'N', -10);
      fail_test('Exception not raised for negative size');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20100 AND SQLERRM LIKE '%Invalid font size%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 6: SetFont rejects font size > 999
  BEGIN
    start_test('SetFont rejects font size > 999');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Helvetica', 'N', 1000);
      fail_test('Exception not raised for size > 999');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20100 AND SQLERRM LIKE '%Invalid font size%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: Color Validation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: Color Validation ---');

  -- Test 7: SetDrawColor accepts valid RGB
  BEGIN
    start_test('SetDrawColor accepts valid RGB (0-255)');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetDrawColor(0, 0, 0);        -- Black
    PL_FPDF.SetDrawColor(255, 255, 255);  -- White
    PL_FPDF.SetDrawColor(128, 64, 192);   -- Custom
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 8: SetDrawColor rejects negative red value
  BEGIN
    start_test('SetDrawColor rejects negative red value');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetDrawColor(-10, 100, 100);
      fail_test('Exception not raised for negative red');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20501 AND SQLERRM LIKE '%Invalid red value%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 9: SetDrawColor rejects red > 255
  BEGIN
    start_test('SetDrawColor rejects red value > 255');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetDrawColor(300, 100, 100);
      fail_test('Exception not raised for red > 255');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20501 AND SQLERRM LIKE '%Invalid red value%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 10: SetFillColor validates RGB
  BEGIN
    start_test('SetFillColor validates RGB values');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFillColor(100, 300, 100);
      fail_test('Exception not raised for green > 255');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20501 AND SQLERRM LIKE '%Invalid green value%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 11: SetTextColor validates RGB
  BEGIN
    start_test('SetTextColor validates RGB values');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetTextColor(100, 100, 300);
      fail_test('Exception not raised for blue > 255');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20501 AND SQLERRM LIKE '%Invalid blue value%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 3: Drawing Validation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: Drawing Validation ---');

  -- Test 12: SetLineWidth accepts positive values
  BEGIN
    start_test('SetLineWidth accepts positive values');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetLineWidth(0.1);
    PL_FPDF.SetLineWidth(1.0);
    PL_FPDF.SetLineWidth(5.0);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 13: SetLineWidth rejects zero
  BEGIN
    start_test('SetLineWidth rejects zero width');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetLineWidth(0);
      fail_test('Exception not raised for zero width');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20502 AND SQLERRM LIKE '%Invalid line width%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 14: SetLineWidth rejects negative values
  BEGIN
    start_test('SetLineWidth rejects negative values');
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetLineWidth(-1.5);
      fail_test('Exception not raised for negative width');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20502 AND SQLERRM LIKE '%Invalid line width%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected outer error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Summary
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('SUMMARY: ' || l_pass_count || '/' || l_test_count || ' tests passed');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('STATUS: ✓ ALL TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('STATUS: ✗ ' || l_fail_count || ' TEST(S) FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('TASK 2.3 COMPLETE: ✓ Input Validation');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('VALIDATIONS IMPLEMENTED:');
  DBMS_OUTPUT.PUT_LINE('  ✓ SetFont - family name length, style, size range');
  DBMS_OUTPUT.PUT_LINE('  ✓ SetDrawColor - RGB value ranges (0-255)');
  DBMS_OUTPUT.PUT_LINE('  ✓ SetFillColor - RGB value ranges (0-255)');
  DBMS_OUTPUT.PUT_LINE('  ✓ SetTextColor - RGB value ranges (0-255)');
  DBMS_OUTPUT.PUT_LINE('  ✓ SetLineWidth - positive values only');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('BENEFITS:');
  DBMS_OUTPUT.PUT_LINE('  • Prevents invalid parameter values');
  DBMS_OUTPUT.PUT_LINE('  • Clear error messages with context');
  DBMS_OUTPUT.PUT_LINE('  • Early detection of programming errors');
  DBMS_OUTPUT.PUT_LINE('  • Improved security and stability');

END;
/
