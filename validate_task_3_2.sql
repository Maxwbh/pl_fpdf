--------------------------------------------------------------------------------
-- VALIDATION SCRIPT: Task 3.2 - JSON Support
-- Project: PL_FPDF Modernization - Phase 3
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Purpose: Validate JSON_OBJECT_T integration for modern configuration
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   Task 3.2: JSON Support Validation
PROMPT ================================================================================
PROMPT   Testing JSON_OBJECT_T APIs for configuration and metadata
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
  l_config JSON_OBJECT_T;
  l_metadata JSON_OBJECT_T;
  l_page_info JSON_OBJECT_T;
  l_value VARCHAR2(4000);
  l_number NUMBER;
  l_blob BLOB;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Task 3.2 Validation Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: SetDocumentConfig with JSON_OBJECT_T
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: SetDocumentConfig ---');

  -- Test 1: SetDocumentConfig accepts valid JSON
  BEGIN
    start_test('SetDocumentConfig accepts valid JSON configuration');
    l_config := JSON_OBJECT_T();
    l_config.put('title', 'Test Report');
    l_config.put('author', 'Maxwell Oliveira');
    l_config.put('subject', 'JSON Integration Test');
    l_config.put('keywords', 'test,json,pdf');
    l_config.put('orientation', 'P');
    l_config.put('unit', 'mm');
    l_config.put('format', 'A4');

    PL_FPDF.SetDocumentConfig(l_config);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 2: SetDocumentConfig validates invalid orientation
  BEGIN
    start_test('SetDocumentConfig rejects invalid orientation');
    l_config := JSON_OBJECT_T();
    l_config.put('orientation', 'INVALID');

    PL_FPDF.SetDocumentConfig(l_config);
    fail_test('Should have raised error for invalid orientation');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20001 OR SQLERRM LIKE '%orientation%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 3: SetDocumentConfig validates invalid unit
  BEGIN
    start_test('SetDocumentConfig rejects invalid unit');
    l_config := JSON_OBJECT_T();
    l_config.put('unit', 'INVALID');

    PL_FPDF.SetDocumentConfig(l_config);
    fail_test('Should have raised error for invalid unit');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20002 OR SQLERRM LIKE '%unit%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 4: SetDocumentConfig with font configuration
  BEGIN
    start_test('SetDocumentConfig accepts font configuration');
    l_config := JSON_OBJECT_T();
    l_config.put('fontFamily', 'Helvetica');
    l_config.put('fontSize', 14);
    l_config.put('fontStyle', 'B');

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetDocumentConfig(l_config);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 5: SetDocumentConfig with margin configuration
  BEGIN
    start_test('SetDocumentConfig accepts margin configuration');
    l_config := JSON_OBJECT_T();
    l_config.put('leftMargin', 15);
    l_config.put('topMargin', 15);
    l_config.put('rightMargin', 15);

    PL_FPDF.SetDocumentConfig(l_config);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: GetDocumentMetadata
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: GetDocumentMetadata ---');

  -- Test 6: GetDocumentMetadata returns valid JSON
  BEGIN
    start_test('GetDocumentMetadata returns JSON_OBJECT_T');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    l_metadata := PL_FPDF.GetDocumentMetadata();

    IF l_metadata IS NOT NULL THEN
      pass_test;
    ELSE
      fail_test('Returned NULL instead of JSON_OBJECT_T');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 7: GetDocumentMetadata includes page count
  BEGIN
    start_test('GetDocumentMetadata includes pageCount');
    l_metadata := PL_FPDF.GetDocumentMetadata();

    IF l_metadata.has('pageCount') THEN
      l_number := l_metadata.get_Number('pageCount');
      IF l_number = 1 THEN
        pass_test;
      ELSE
        fail_test('Expected pageCount=1, got: ' || l_number);
      END IF;
    ELSE
      fail_test('Missing pageCount field');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 8: GetDocumentMetadata includes document properties
  BEGIN
    start_test('GetDocumentMetadata includes title, author, subject');
    l_config := JSON_OBJECT_T();
    l_config.put('title', 'My Title');
    l_config.put('author', 'My Author');
    l_config.put('subject', 'My Subject');

    PL_FPDF.SetDocumentConfig(l_config);
    l_metadata := PL_FPDF.GetDocumentMetadata();

    IF l_metadata.has('title') AND l_metadata.has('author') AND l_metadata.has('subject') THEN
      l_value := l_metadata.get_String('title');
      IF l_value = 'My Title' THEN
        pass_test;
      ELSE
        fail_test('Title mismatch: ' || l_value);
      END IF;
    ELSE
      fail_test('Missing title, author, or subject fields');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 9: GetDocumentMetadata includes format and orientation
  BEGIN
    start_test('GetDocumentMetadata includes format and orientation');
    l_metadata := PL_FPDF.GetDocumentMetadata();

    IF l_metadata.has('format') AND l_metadata.has('orientation') THEN
      l_value := l_metadata.get_String('format');
      IF l_value IN ('A4', 'Letter', 'Legal') THEN
        pass_test;
      ELSE
        fail_test('Unexpected format: ' || l_value);
      END IF;
    ELSE
      fail_test('Missing format or orientation fields');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 10: GetDocumentMetadata includes unit
  BEGIN
    start_test('GetDocumentMetadata includes unit');
    l_metadata := PL_FPDF.GetDocumentMetadata();

    IF l_metadata.has('unit') THEN
      l_value := l_metadata.get_String('unit');
      IF l_value IN ('mm', 'cm', 'in', 'pt') THEN
        pass_test;
      ELSE
        fail_test('Unexpected unit: ' || l_value);
      END IF;
    ELSE
      fail_test('Missing unit field');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 3: GetPageInfo
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: GetPageInfo ---');

  -- Test 11: GetPageInfo returns current page info
  BEGIN
    start_test('GetPageInfo returns current page information');
    PL_FPDF.Init('L', 'mm', 'Letter');
    PL_FPDF.AddPage();

    l_page_info := PL_FPDF.GetPageInfo();

    IF l_page_info IS NOT NULL THEN
      pass_test;
    ELSE
      fail_test('Returned NULL');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 12: GetPageInfo includes page number
  BEGIN
    start_test('GetPageInfo includes page number');
    l_page_info := PL_FPDF.GetPageInfo();

    IF l_page_info.has('number') THEN
      l_number := l_page_info.get_Number('number');
      IF l_number = 1 THEN
        pass_test;
      ELSE
        fail_test('Expected number=1, got: ' || l_number);
      END IF;
    ELSE
      fail_test('Missing number field');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 13: GetPageInfo includes dimensions
  BEGIN
    start_test('GetPageInfo includes width and height');
    l_page_info := PL_FPDF.GetPageInfo();

    IF l_page_info.has('width') AND l_page_info.has('height') THEN
      l_number := l_page_info.get_Number('width');
      IF l_number > 0 THEN
        pass_test;
      ELSE
        fail_test('Invalid width: ' || l_number);
      END IF;
    ELSE
      fail_test('Missing width or height fields');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 14: GetPageInfo for specific page
  BEGIN
    start_test('GetPageInfo(p_page_number) works for specific page');
    PL_FPDF.AddPage('P', 'A5', 0);  -- Add second page with different format

    l_page_info := PL_FPDF.GetPageInfo(1);  -- Get first page info

    IF l_page_info.has('number') THEN
      l_number := l_page_info.get_Number('number');
      IF l_number = 1 THEN
        pass_test;
      ELSE
        fail_test('Expected number=1, got: ' || l_number);
      END IF;
    ELSE
      fail_test('Missing number field');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 15: GetPageInfo rejects invalid page number
  BEGIN
    start_test('GetPageInfo rejects invalid page number');
    l_page_info := PL_FPDF.GetPageInfo(999);
    fail_test('Should have raised error for invalid page');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20106 OR SQLERRM LIKE '%page%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -------------------------------------------------------------------------
  -- Test Group 4: JSON Integration with PDF Generation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 4: JSON Integration ---');

  -- Test 16: Complete workflow with JSON configuration
  BEGIN
    start_test('Complete workflow: Config -> Generate -> Metadata');

    -- Configure via JSON
    l_config := JSON_OBJECT_T();
    l_config.put('title', 'JSON Test Document');
    l_config.put('author', 'Test Suite');
    l_config.put('orientation', 'P');
    l_config.put('format', 'A4');
    l_config.put('unit', 'mm');

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetDocumentConfig(l_config);
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'JSON Test', '1', 1, 'L');

    -- Get metadata
    l_metadata := PL_FPDF.GetDocumentMetadata();

    -- Generate PDF
    l_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_blob) > 0 THEN
      pass_test;
    ELSE
      fail_test('Generated empty PDF');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 17: JSON metadata can be serialized
  BEGIN
    start_test('GetDocumentMetadata JSON can be serialized to string');
    l_metadata := PL_FPDF.GetDocumentMetadata();
    l_value := l_metadata.to_string();

    IF LENGTH(l_value) > 0 AND l_value LIKE '{%}' THEN
      pass_test;
    ELSE
      fail_test('Invalid JSON string: ' || SUBSTR(l_value, 1, 100));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 18: NULL JSON config is handled gracefully
  BEGIN
    start_test('SetDocumentConfig handles NULL gracefully');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetDocumentConfig(NULL);
    pass_test;
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
