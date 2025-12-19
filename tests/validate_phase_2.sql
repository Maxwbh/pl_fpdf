
DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  PROCEDURE test_result(p_test_name VARCHAR2,
                        p_passed    BOOLEAN,
                        p_message   VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_passed THEN
      l_pass_count := l_pass_count + 1;
      dbms_output.put_line('  [PASS] ' || p_test_name);
    ELSE
      l_fail_count := l_fail_count + 1;
      dbms_output.put_line('  [FAIL] ' || p_test_name || CASE WHEN p_message IS NOT NULL THEN ' - ' || p_message ELSE '' END);
    END IF;
  END test_result;

BEGIN
  dbms_output.put_line('');
  dbms_output.put_line('Task 2.1: UTF-8/Unicode Support');
  dbms_output.put_line('--------------------------------');

  -- Test 2.1.1: UTF-8 enabled by default
  BEGIN
    pl_fpdf.init();
    test_result('UTF-8 enabled by default',
                pl_fpdf.isutf8enabled());
    pl_fpdf.reset();
  EXCEPTION
    WHEN OTHERS THEN
      test_result('UTF-8 default enabled',
                  FALSE,
                  SQLERRM);
  END;

  -- Test 2.1.2: SetUTF8Enabled
  BEGIN
    pl_fpdf.setutf8enabled(FALSE);
    test_result('SetUTF8Enabled(FALSE)',
                NOT pl_fpdf.isutf8enabled());
    pl_fpdf.setutf8enabled(TRUE);
    test_result('SetUTF8Enabled(TRUE)',
                pl_fpdf.isutf8enabled());
  EXCEPTION
    WHEN OTHERS THEN
      test_result('SetUTF8Enabled',
                  FALSE,
                  SQLERRM);
  END;

  -- Test 2.1.3: International characters
  DECLARE
    l_pdf BLOB;
  BEGIN
    pl_fpdf.init('P',
                 'mm',
                 'A4',
                 'UTF-8');
    pl_fpdf.addpage();
    pl_fpdf.setfont('Arial',
                    '',
                    12);
    pl_fpdf.cell(0,
                 10,
                 'Português: São Paulo, Ação');
    pl_fpdf.ln(10);
    pl_fpdf.cell(0,
                 10,
                 'Deutsch: Zürich, Ä Ö Ü');
    pl_fpdf.ln(10);
    pl_fpdf.cell(0,
                 10,
                 'Français: Château, É È');
    l_pdf := pl_fpdf.outputblob();
    test_result('International characters rendering',
                dbms_lob.getlength(l_pdf) > 0);
    pl_fpdf.reset();
  EXCEPTION
    WHEN OTHERS THEN
      test_result('International characters',
                  FALSE,
                  SQLERRM);
  END;

  dbms_output.put_line('');
  dbms_output.put_line('Task 2.2 & 2.4: Custom Exceptions');
  dbms_output.put_line('----------------------------------');

  -- Test 2.2.1: exc_invalid_orientation
  BEGIN
    pl_fpdf.init('X',
                 'mm',
                 'A4'); -- Invalid orientation
    test_result('exc_invalid_orientation raised',
                FALSE,
                'Should have raised exception');
    pl_fpdf.reset();
  EXCEPTION
    WHEN pl_fpdf.exc_invalid_orientation THEN
      test_result('exc_invalid_orientation (-20001)',
                  TRUE);
    WHEN OTHERS THEN
      test_result('exc_invalid_orientation',
                  FALSE,
                  'Wrong exception: ' || SQLERRM);
  END;

  -- Test 2.2.2: exc_invalid_unit
  BEGIN
    pl_fpdf.init('P',
                 'xyz',
                 'A4'); -- Invalid unit
    test_result('exc_invalid_unit raised',
                FALSE,
                'Should have raised exception');
    pl_fpdf.reset();
  EXCEPTION
    WHEN pl_fpdf.exc_invalid_unit THEN
      test_result('exc_invalid_unit (-20002)',
                  TRUE);
    WHEN OTHERS THEN
      test_result('exc_invalid_unit',
                  FALSE,
                  'Wrong exception: ' || SQLERRM);
  END;

  -- Test 2.2.3: exc_not_initialized
  BEGIN
    pl_fpdf.reset(); -- Ensure not initialized
    pl_fpdf.addpage(); -- Should fail
    test_result('exc_not_initialized raised',
                FALSE,
                'Should have raised exception');
  EXCEPTION
    WHEN pl_fpdf.exc_not_initialized THEN
      test_result('exc_not_initialized (-20005)',
                  TRUE);
    WHEN OTHERS THEN
      test_result('exc_not_initialized',
                  FALSE,
                  'Wrong exception: ' || SQLERRM);
  END;

  -- Test 2.2.4: exc_font_not_found
  BEGIN
    pl_fpdf.init();
    pl_fpdf.addpage();
    pl_fpdf.setfont('NonExistentFont',
                    '',
                    12);
    test_result('exc_font_not_found raised',
                FALSE,
                'Should have raised exception');
    pl_fpdf.reset();
  EXCEPTION
    WHEN pl_fpdf.exc_font_not_found THEN
      test_result('exc_font_not_found (-20201)',
                  TRUE);
    WHEN OTHERS THEN
      test_result('exc_font_not_found',
                  FALSE,
                  'Wrong exception: ' || SQLERRM);
  END;

  -- Test 2.2.5: exc_page_not_found
  BEGIN
    pl_fpdf.init();
    pl_fpdf.addpage();
    pl_fpdf.setpage(999); -- Non-existent page
    test_result('exc_page_not_found raised',
                FALSE,
                'Should have raised exception');
    pl_fpdf.reset();
  EXCEPTION
    WHEN pl_fpdf.exc_page_not_found THEN
      test_result('exc_page_not_found (-20106)',
                  TRUE);
    WHEN OTHERS THEN
      test_result('exc_page_not_found',
                  FALSE,
                  'Wrong exception: ' || SQLERRM);
  END;

  dbms_output.put_line('');
  dbms_output.put_line('Task 2.3: Input Validation');
  dbms_output.put_line('---------------------------');

  -- Test 2.3.1: Valid orientation values
  BEGIN
    pl_fpdf.init('P',
                 'mm',
                 'A4');
    pl_fpdf.reset();
    pl_fpdf.init('L',
                 'mm',
                 'A4');
    test_result('Valid orientation values (P, L)',
                TRUE);
    pl_fpdf.reset();
  EXCEPTION
    WHEN OTHERS THEN
      test_result('Valid orientation values',
                  FALSE,
                  SQLERRM);
  END;

  -- Test 2.3.2: Valid unit values
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'in', 'A4');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'pt', 'A4');
    test_result('Valid unit values (mm, cm, in, pt)', TRUE);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Valid unit values', FALSE, SQLERRM);
  END;

  -- Test 2.3.3: Valid page formats
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A3');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'A5');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'Legal');
    test_result('Valid page formats (A3, A4, A5, Letter, Legal)', TRUE);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Valid page formats', FALSE, SQLERRM);
  END;

  -- Test 2.3.4: Parameter validation
  DECLARE
    l_passed BOOLEAN := TRUE;
  BEGIN
    -- Test NULL handling
    PL_FPDF.Init(NULL, 'mm', 'A4');  -- Should use default
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('NULL parameter handling', FALSE, SQLERRM);
    l_passed := FALSE;
  END;
  IF l_passed THEN
    test_result('NULL parameter handling (uses defaults)', TRUE);
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 2.5: Enhanced Logging');
  DBMS_OUTPUT.PUT_LINE('---------------------------');

  -- Test 2.5.1: SetLogLevel
  DECLARE
    l_initial_level PLS_INTEGER;
  BEGIN
    l_initial_level := PL_FPDF.GetLogLevel();
    PL_FPDF.SetLogLevel(4);  -- DEBUG
    test_result('SetLogLevel(4)', PL_FPDF.GetLogLevel() = 4);
    PL_FPDF.SetLogLevel(0);  -- OFF
    test_result('SetLogLevel(0)', PL_FPDF.GetLogLevel() = 0);
    -- Restore
    PL_FPDF.SetLogLevel(l_initial_level);
  EXCEPTION WHEN OTHERS THEN
    test_result('SetLogLevel', FALSE, SQLERRM);
  END;

  -- Test 2.5.2: GetLogLevel
  BEGIN
    PL_FPDF.SetLogLevel(3);
    test_result('GetLogLevel returns correct value', PL_FPDF.GetLogLevel() = 3);
    PL_FPDF.SetLogLevel(2);  -- Restore default
  EXCEPTION WHEN OTHERS THEN
    test_result('GetLogLevel', FALSE, SQLERRM);
  END;

  -- Test 2.5.3: Log levels 0-4
  DECLARE
    l_valid BOOLEAN := TRUE;
  BEGIN
    FOR i IN 0..4 LOOP
      PL_FPDF.SetLogLevel(i);
      IF PL_FPDF.GetLogLevel() != i THEN
        l_valid := FALSE;
      END IF;
    END LOOP;
    test_result('All log levels (0-4) valid', l_valid);
    PL_FPDF.SetLogLevel(2);  -- Restore default
  EXCEPTION WHEN OTHERS THEN
    test_result('Log levels 0-4', FALSE, SQLERRM);
  END;

  -- Test 2.5.4: Logging integration with operations
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.SetLogLevel(4);  -- DEBUG - most verbose
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 10, 'Logging Test');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Logging with DEBUG level', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
    PL_FPDF.SetLogLevel(2);  -- Restore default
  EXCEPTION WHEN OTHERS THEN
    test_result('Logging integration', FALSE, SQLERRM);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Phase 2 Validation Summary');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count || ' (' ||
    ROUND(l_pass_count * 100 / l_test_count, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASE 2: ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASE 2: SOME TESTS FAILED - REVIEW REQUIRED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/
