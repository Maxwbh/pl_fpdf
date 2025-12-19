--------------------------------------------------------------------------------
-- Phase 1 Validation Script: Critical Refactoring
-- PL_FPDF Modernization Project
-- Date: 2025-12-19
--------------------------------------------------------------------------------
-- Tests all Phase 1 functionality:
-- - Modern initialization (Init/Reset)
-- - Enhanced page management (AddPage/SetPage)
-- - TrueType/Unicode font support
-- - Text rotation (CellRotated/WriteRotated)
-- - Modern output methods (OutputBlob/OutputFile)
-- - Native BLOB image handling
-- - CLOB buffer support
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   Phase 1 Validation: Critical Refactoring
PROMPT ================================================================================
PROMPT

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  PROCEDURE test_result(p_test_name VARCHAR2, p_passed BOOLEAN, p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_passed THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_test_name);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_test_name ||
        CASE WHEN p_message IS NOT NULL THEN ' - ' || p_message ELSE '' END);
    END IF;
  END test_result;

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.1: Modern Initialization');
  DBMS_OUTPUT.PUT_LINE('--------------------------------');

  -- Test 1.1.1: Init procedure with UTF-8
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    test_result('Init with UTF-8 encoding', PL_FPDF.IsInitialized());
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Init with UTF-8 encoding', FALSE, SQLERRM);
  END;

  -- Test 1.1.2: IsInitialized function
  BEGIN
    PL_FPDF.Reset();
    test_result('IsInitialized returns FALSE after Reset', NOT PL_FPDF.IsInitialized());
    PL_FPDF.Init();
    test_result('IsInitialized returns TRUE after Init', PL_FPDF.IsInitialized());
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('IsInitialized function', FALSE, SQLERRM);
  END;

  -- Test 1.1.3: Reset cleanup
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.Reset();
    test_result('Reset cleans up resources', NOT PL_FPDF.IsInitialized());
  EXCEPTION WHEN OTHERS THEN
    test_result('Reset cleanup', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.2: Enhanced Page Management');
  DBMS_OUTPUT.PUT_LINE('-----------------------------------');

  -- Test 1.2.1: AddPage with rotation
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage('P', 'A4', 0);
    PL_FPDF.AddPage('L', 'A4', 90);
    test_result('AddPage with rotation support', PL_FPDF.GetCurrentPage() = 2);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('AddPage with rotation', FALSE, SQLERRM);
  END;

  -- Test 1.2.2: SetPage navigation
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();
    PL_FPDF.SetPage(1);
    test_result('SetPage navigation', PL_FPDF.GetCurrentPage() = 1);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('SetPage navigation', FALSE, SQLERRM);
  END;

  -- Test 1.2.3: Custom page format
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage('P', '210,297');  -- Custom A4 size
    test_result('Custom page format (width,height)', TRUE);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Custom page format', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.3: TrueType/Unicode Font Support');
  DBMS_OUTPUT.PUT_LINE('----------------------------------------');

  -- Test 1.3.1: UTF-8 encoding
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    test_result('UTF-8 encoding enabled', PL_FPDF.IsUTF8Enabled());
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('UTF-8 encoding', FALSE, SQLERRM);
  END;

  -- Test 1.3.2: UTF8ToPDFString conversion
  DECLARE
    l_result VARCHAR2(1000);
  BEGIN
    PL_FPDF.Init();
    l_result := PL_FPDF.UTF8ToPDFString('Hello World');
    test_result('UTF8ToPDFString basic conversion', l_result IS NOT NULL);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('UTF8ToPDFString conversion', FALSE, SQLERRM);
  END;

  -- Test 1.3.3: Unicode characters
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'São Paulo - Zürich');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Unicode character support', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Unicode characters', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.4: Text Rotation');
  DBMS_OUTPUT.PUT_LINE('------------------------');

  -- Test 1.4.1: CellRotated
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.CellRotated(50, 10, 'Rotated 90°', '1', 0, 'C', 0, '', 90);
    l_pdf := PL_FPDF.OutputBlob();
    test_result('CellRotated with 90° rotation', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('CellRotated', FALSE, SQLERRM);
  END;

  -- Test 1.4.2: WriteRotated
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.WriteRotated(10, 'Rotated text', '', 180);
    l_pdf := PL_FPDF.OutputBlob();
    test_result('WriteRotated with 180° rotation', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('WriteRotated', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.5: Modern Output Methods');
  DBMS_OUTPUT.PUT_LINE('--------------------------------');

  -- Test 1.5.1: OutputBlob (no OWA dependencies)
  DECLARE
    l_pdf BLOB;
    l_header RAW(4);
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test PDF');
    l_pdf := PL_FPDF.OutputBlob();
    l_header := DBMS_LOB.SUBSTR(l_pdf, 4, 1);
    test_result('OutputBlob generates valid PDF',
                UTL_RAW.CAST_TO_VARCHAR2(l_header) = '%PDF');
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('OutputBlob', FALSE, SQLERRM);
  END;

  -- Test 1.5.2: Multi-page document
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    FOR i IN 1..10 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Page ' || i);
    END LOOP;
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Multi-page document (10 pages)', DBMS_LOB.GETLENGTH(l_pdf) > 1000);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Multi-page document', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.6: Native BLOB Image Handling');
  DBMS_OUTPUT.PUT_LINE('-------------------------------------');

  -- Test 1.6.1: recImageBlob type
  DECLARE
    l_img PL_FPDF.recImageBlob;
  BEGIN
    l_img.mime_type := 'image/png';
    l_img.file_format := 'PNG';
    l_img.width := 100;
    l_img.height := 100;
    test_result('recImageBlob type definition', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('recImageBlob type', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 1.7: CLOB Buffer Support');
  DBMS_OUTPUT.PUT_LINE('------------------------------');

  -- Test 1.7.1: Large document (CLOB unlimited size)
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1..100 LOOP
      PL_FPDF.AddPage();
      FOR j IN 1..50 LOOP
        PL_FPDF.Cell(0, 5, 'Line ' || j || ' on page ' || i);
        PL_FPDF.Ln(5);
      END LOOP;
    END LOOP;
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Large document (100 pages, 5000 lines)',
                DBMS_LOB.GETLENGTH(l_pdf) > 50000);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Large document CLOB support', FALSE, SQLERRM);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Phase 1 Validation Summary');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count || ' (' ||
    ROUND(l_pass_count * 100 / l_test_count, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASE 1: ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASE 1: SOME TESTS FAILED - REVIEW REQUIRED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/
