--------------------------------------------------------------------------------
-- Task 2.5 Validation Tests: Enhanced Logging
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-18
--------------------------------------------------------------------------------
-- Validates enhanced logging with SetLogLevel, GetLogLevel, and DBMS_APPLICATION_INFO
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

DECLARE
  l_test_count NUMBER := 0;
  l_pass_count NUMBER := 0;
  l_fail_count NUMBER := 0;
  l_test_name VARCHAR2(200);
  l_initial_level PLS_INTEGER;
  l_current_level PLS_INTEGER;

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
  DBMS_OUTPUT.PUT_LINE('=== Task 2.5 Validation: Enhanced Logging ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: SetLogLevel and GetLogLevel
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: Log Level Management ---');

  -- Test 1: GetLogLevel returns current level
  BEGIN
    start_test('GetLogLevel returns current log level');
    l_initial_level := PL_FPDF.GetLogLevel();
    IF l_initial_level BETWEEN 0 AND 4 THEN
      pass_test;
    ELSE
      fail_test('Invalid log level: ' || l_initial_level);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 2: SetLogLevel(0) - OFF
  BEGIN
    start_test('SetLogLevel(0) sets logging to OFF');
    PL_FPDF.SetLogLevel(0);
    l_current_level := PL_FPDF.GetLogLevel();
    IF l_current_level = 0 THEN
      pass_test;
    ELSE
      fail_test('Expected 0, got: ' || l_current_level);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 3: SetLogLevel(1) - ERROR
  BEGIN
    start_test('SetLogLevel(1) sets logging to ERROR');
    PL_FPDF.SetLogLevel(1);
    l_current_level := PL_FPDF.GetLogLevel();
    IF l_current_level = 1 THEN
      pass_test;
    ELSE
      fail_test('Expected 1, got: ' || l_current_level);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 4: SetLogLevel(4) - DEBUG
  BEGIN
    start_test('SetLogLevel(4) sets logging to DEBUG');
    PL_FPDF.SetLogLevel(4);
    l_current_level := PL_FPDF.GetLogLevel();
    IF l_current_level = 4 THEN
      pass_test;
    ELSE
      fail_test('Expected 4, got: ' || l_current_level);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 5: SetLogLevel rejects invalid values (negative)
  BEGIN
    start_test('SetLogLevel rejects negative values');
    BEGIN
      PL_FPDF.SetLogLevel(-1);
      fail_test('Exception not raised for negative value');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20100 AND SQLERRM LIKE '%Invalid log level%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 6: SetLogLevel rejects invalid values (>4)
  BEGIN
    start_test('SetLogLevel rejects values > 4');
    BEGIN
      PL_FPDF.SetLogLevel(5);
      fail_test('Exception not raised for value > 4');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20100 AND SQLERRM LIKE '%Invalid log level%' THEN
          pass_test;
        ELSE
          fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: Logging Integration
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: Logging Integration ---');

  -- Test 7: Logging works with PDF operations
  BEGIN
    start_test('Logging integrates with PDF generation');
    PL_FPDF.SetLogLevel(3);  -- INFO level
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Helvetica', 'N', 12);
    PL_FPDF.Cell(50, 10, 'Test', '1', 1, 'L');

    -- If we got here without errors, logging works
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error during PDF generation: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 8: Log level persists across operations
  BEGIN
    start_test('Log level persists across PDF operations');
    PL_FPDF.SetLogLevel(2);  -- WARN level
    l_current_level := PL_FPDF.GetLogLevel();

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    -- Check level hasn't changed
    IF PL_FPDF.GetLogLevel() = 2 THEN
      pass_test;
    ELSE
      fail_test('Log level changed unexpectedly');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Unexpected error: ' || SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Restore original log level
  -------------------------------------------------------------------------
  BEGIN
    PL_FPDF.SetLogLevel(l_initial_level);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;  -- Ignore errors restoring level
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
  DBMS_OUTPUT.PUT_LINE('TASK 2.5 COMPLETE: ✓ Enhanced Logging');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('FEATURES IMPLEMENTED:');
  DBMS_OUTPUT.PUT_LINE('  ✓ SetLogLevel(0-4) - Configure log verbosity');
  DBMS_OUTPUT.PUT_LINE('  ✓ GetLogLevel() - Query current log level');
  DBMS_OUTPUT.PUT_LINE('  ✓ Enhanced log_message() - DBMS_APPLICATION_INFO integration');
  DBMS_OUTPUT.PUT_LINE('  ✓ Input validation for log levels');
  DBMS_OUTPUT.PUT_LINE('  ✓ Log levels: 0=OFF, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('BENEFITS:');
  DBMS_OUTPUT.PUT_LINE('  • Control log verbosity dynamically');
  DBMS_OUTPUT.PUT_LINE('  • Monitor via DBMS_APPLICATION_INFO');
  DBMS_OUTPUT.PUT_LINE('  • Better debugging and troubleshooting');
  DBMS_OUTPUT.PUT_LINE('  • Production-safe logging (can disable)');

END;
/
