--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-alpha - Phase 4.1B: Page Information and Manipulation Tests
-- Description: Test suite for GetPageInfo and RotatePage APIs
--------------------------------------------------------------------------------


DECLARE
  l_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_info JSON_OBJECT_T;
  l_page_count PLS_INTEGER;

  -- Test helper procedures
  PROCEDURE test_start(p_test_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test ' || l_test_count || ': ' || p_test_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
  END;

  PROCEDURE test_pass(p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || NVL(p_message, 'Test passed'));
  END;

  PROCEDURE test_fail(p_message VARCHAR2) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_message);
  END;

  -- Create valid test PDF using PL_FPDF itself (guarantees correct structure)
  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Page 1');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Page 2');
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-alpha - PHASE 4.1B: Page Information & Manipulation Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF
  create_test_pdf();

  -- Enable debug logging
  --PL_FPDF.EnableDebugMode();
  PL_FPDF.SetLogLevel(4);

  --------------------------------------------------------------------------------
  -- TEST 1: Load PDF and verify page tree parsing
  --------------------------------------------------------------------------------
  test_start('Load PDF and parse page tree');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);
    l_page_count := PL_FPDF.GetPageCount();

    IF l_page_count = 2 THEN
      test_pass('Page count correct: 2 pages');
    ELSE
      test_fail('Expected 2 pages, got ' || l_page_count);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error loading PDF: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: Get page 1 information
  --------------------------------------------------------------------------------
  test_start('GetPageInfo for page 1');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(1);

    DBMS_OUTPUT.PUT_LINE('  Page 1 Info:');
    DBMS_OUTPUT.PUT_LINE('    - Page Number: ' || l_info.get_number('pageNumber'));
    DBMS_OUTPUT.PUT_LINE('    - Object ID: ' || l_info.get_number('pageObjectId'));
    DBMS_OUTPUT.PUT_LINE('    - MediaBox: ' || l_info.get_string('mediaBox'));
    DBMS_OUTPUT.PUT_LINE('    - Rotation: ' || l_info.get_number('rotation') || ' degrees');

    IF l_info.get_number('pageNumber') = 1 THEN
      test_pass('Page number correct');
    ELSE
      test_fail('Page number incorrect');
    END IF;

    IF l_info.get_string('mediaBox') LIKE '0 0 612%792%' THEN
      test_pass('MediaBox correct (Letter size)');
    ELSE
      test_fail('MediaBox incorrect: ' || l_info.get_string('mediaBox'));
    END IF;

    IF l_info.get_number('rotation') = 0 THEN
      test_pass('Rotation correct (0 degrees)');
    ELSE
      test_fail('Rotation incorrect: ' || l_info.get_number('rotation'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error getting page 1 info: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: Get page 2 information
  --------------------------------------------------------------------------------
  test_start('GetPageInfo for page 2');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(2);

    DBMS_OUTPUT.PUT_LINE('  Page 2 Info:');
    DBMS_OUTPUT.PUT_LINE('    - Page Number: ' || l_info.get_number('pageNumber'));
    DBMS_OUTPUT.PUT_LINE('    - Object ID: ' || l_info.get_number('pageObjectId'));
    DBMS_OUTPUT.PUT_LINE('    - MediaBox: ' || l_info.get_string('mediaBox'));
    DBMS_OUTPUT.PUT_LINE('    - Rotation: ' || l_info.get_number('rotation') || ' degrees');

    IF l_info.get_string('mediaBox') LIKE '0 0 612%792%' THEN
      test_pass('MediaBox correct (Letter size)');
    ELSE
      test_fail('MediaBox incorrect: ' || l_info.get_string('mediaBox'));
    END IF;

    IF l_info.get_number('rotation') = 0 THEN
      test_pass('Rotation correct (0 degrees)');
    ELSE
      test_fail('Rotation incorrect: ' || l_info.get_number('rotation'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error getting page 2 info: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: RotatePage - Set page 1 to 180 degrees
  --------------------------------------------------------------------------------
  test_start('RotatePage - Set page 1 to 180 degrees');
  BEGIN
    PL_FPDF.RotatePage(1, 180);

    l_info := PL_FPDF.GetPageInfo(1);
    IF l_info.get_number('rotation') = 180 THEN
      test_pass('Page 1 rotation updated to 180 degrees');
    ELSE
      test_fail('Rotation not updated: ' || l_info.get_number('rotation'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error rotating page: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: RotatePage - Invalid rotation value
  --------------------------------------------------------------------------------
  test_start('RotatePage - Invalid rotation value (should fail)');
  BEGIN
    PL_FPDF.RotatePage(1, 45);  -- Invalid: must be 0, 90, 180, or 270
    test_fail('Should have raised error for invalid rotation');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20813 THEN
        test_pass('Correctly rejected invalid rotation value');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: GetPageInfo - Invalid page number
  --------------------------------------------------------------------------------
  test_start('GetPageInfo - Invalid page number (should fail)');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(99);  -- PDF only has 2 pages
    test_fail('Should have raised error for invalid page number');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20812 THEN
        test_pass('Correctly rejected invalid page number');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: ClearPDFCache and verify cleanup
  --------------------------------------------------------------------------------
  test_start('ClearPDFCache and verify cleanup');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- Try to get page count after clearing - should fail
    BEGIN
      l_page_count := PL_FPDF.GetPageCount();
      test_fail('Should have raised error after ClearPDFCache');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          test_pass('Correctly raised error after clearing cache');
        ELSE
          test_fail('Wrong error code: ' || SQLCODE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error clearing cache: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST SUMMARY
  --------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('TEST SUMMARY');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests:  ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:       ' || l_pass_count || ' (' ||
    ROUND(l_pass_count / l_test_count * 100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:       ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** SOME TESTS FAILED ***');
  END IF;

  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/
