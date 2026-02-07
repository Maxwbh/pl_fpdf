--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-alpha - Phase 4.1B: Page Information and Manipulation Tests
-- Description: Test suite for GetPageInfo and RotatePage APIs
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

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

  -- Create minimal PDF for testing
  PROCEDURE create_test_pdf IS
  BEGIN
    -- Minimal valid PDF with 2 pages
    l_pdf := UTL_RAW.CAST_TO_RAW(
      '%PDF-1.4' || CHR(10) ||
      '1 0 obj' || CHR(10) ||
      '<< /Type /Catalog /Pages 2 0 R >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '2 0 obj' || CHR(10) ||
      '<< /Type /Pages /Count 2 /Kids [3 0 R 4 0 R] >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '3 0 obj' || CHR(10) ||
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources 5 0 R /Contents 6 0 R >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '4 0 obj' || CHR(10) ||
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Rotate 90 /Resources 5 0 R /Contents 7 0 R >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '5 0 obj' || CHR(10) ||
      '<< /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '6 0 obj' || CHR(10) ||
      '<< /Length 44 >>' || CHR(10) ||
      'stream' || CHR(10) ||
      'BT /F1 12 Tf 100 700 Td (Page 1) Tj ET' || CHR(10) ||
      'endstream' || CHR(10) ||
      'endobj' || CHR(10) ||
      '7 0 obj' || CHR(10) ||
      '<< /Length 44 >>' || CHR(10) ||
      'stream' || CHR(10) ||
      'BT /F1 12 Tf 100 700 Td (Page 2) Tj ET' || CHR(10) ||
      'endstream' || CHR(10) ||
      'endobj' || CHR(10) ||
      'xref' || CHR(10) ||
      '0 8' || CHR(10) ||
      '0000000000 65535 f ' || CHR(10) ||
      '0000000009 65535 n ' || CHR(10) ||
      '0000000058 65535 n ' || CHR(10) ||
      '0000000127 65535 n ' || CHR(10) ||
      '0000000238 65535 n ' || CHR(10) ||
      '0000000363 65535 n ' || CHR(10) ||
      '0000000461 65535 n ' || CHR(10) ||
      '0000000554 65535 n ' || CHR(10) ||
      'trailer' || CHR(10) ||
      '<< /Size 8 /Root 1 0 R >>' || CHR(10) ||
      'startxref' || CHR(10) ||
      '647' || CHR(10) ||
      '%%EOF'
    );
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-alpha - PHASE 4.1B: Page Information & Manipulation Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF
  create_test_pdf();

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

    IF l_info.get_string('mediaBox') = '0 0 612 792' THEN
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
  -- TEST 3: Get page 2 information (with rotation)
  --------------------------------------------------------------------------------
  test_start('GetPageInfo for page 2 (with rotation)');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(2);

    DBMS_OUTPUT.PUT_LINE('  Page 2 Info:');
    DBMS_OUTPUT.PUT_LINE('    - Page Number: ' || l_info.get_number('pageNumber'));
    DBMS_OUTPUT.PUT_LINE('    - Object ID: ' || l_info.get_number('pageObjectId'));
    DBMS_OUTPUT.PUT_LINE('    - MediaBox: ' || l_info.get_string('mediaBox'));
    DBMS_OUTPUT.PUT_LINE('    - Rotation: ' || l_info.get_number('rotation') || ' degrees');

    IF l_info.get_string('mediaBox') = '0 0 595 842' THEN
      test_pass('MediaBox correct (A4 size)');
    ELSE
      test_fail('MediaBox incorrect: ' || l_info.get_string('mediaBox'));
    END IF;

    IF l_info.get_number('rotation') = 90 THEN
      test_pass('Rotation correct (90 degrees)');
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
