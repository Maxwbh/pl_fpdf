--------------------------------------------------------------------------------
-- Test Phase 4: PDF Parser - Basic Reading
-- Tests LoadPDF, GetPageCount, GetPDFInfo
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  -- Test counter
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  
  -- Helper procedure
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
  
  -- Test PDF (minimal valid PDF)
  l_test_pdf BLOB;
  l_page_count PLS_INTEGER;
  l_pdf_info JSON_OBJECT_T;
  
BEGIN
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4 - PDF PARSER: BASIC READING TESTS');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('');
  
  DBMS_OUTPUT.PUT_LINE('Test 4.1: Load Simple PDF');
  DBMS_OUTPUT.PUT_LINE('-------------------------');
  
  -- Create minimal valid PDF for testing
  -- This is a very simple 1-page PDF
  l_test_pdf := UTL_RAW.CAST_TO_RAW(
    '%PDF-1.4' || CHR(10) ||
    '1 0 obj' || CHR(10) ||
    '<< /Type /Catalog /Pages 2 0 R >>' || CHR(10) ||
    'endobj' || CHR(10) ||
    '2 0 obj' || CHR(10) ||
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' || CHR(10) ||
    'endobj' || CHR(10) ||
    '3 0 obj' || CHR(10) ||
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>' || CHR(10) ||
    'endobj' || CHR(10) ||
    'xref' || CHR(10) ||
    '0 4' || CHR(10) ||
    '0000000000 65535 f ' || CHR(10) ||
    '0000000009 00000 n ' || CHR(10) ||
    '0000000056 00000 n ' || CHR(10) ||
    '0000000115 00000 n ' || CHR(10) ||
    'trailer' || CHR(10) ||
    '<< /Size 4 /Root 1 0 R >>' || CHR(10) ||
    'startxref' || CHR(10) ||
    '198' || CHR(10) ||
    '%%EOF'
  );
  
  -- Test 1: LoadPDF
  BEGIN
    PL_FPDF.LoadPDF(l_test_pdf);
    test_result('LoadPDF() with minimal PDF', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('LoadPDF() with minimal PDF', FALSE, SQLERRM);
  END;
  
  -- Test 2: GetPageCount
  BEGIN
    l_page_count := PL_FPDF.GetPageCount();
    test_result('GetPageCount() returns 1', l_page_count = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageCount()', FALSE, SQLERRM);
  END;
  
  -- Test 3: GetPDFInfo
  BEGIN
    l_pdf_info := PL_FPDF.GetPDFInfo();
    test_result('GetPDFInfo() returns JSON', l_pdf_info IS NOT NULL);
    test_result('GetPDFInfo().version = 1.4', l_pdf_info.get_string('version') = '1.4');
    test_result('GetPDFInfo().pageCount = 1', l_pdf_info.get_number('pageCount') = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPDFInfo()', FALSE, SQLERRM);
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('SUMMARY');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count);
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('Success Rate: ' || ROUND(l_pass_count * 100 / l_test_count, 1) || '%');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  
  IF l_fail_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20000, 'Some tests failed');
  END IF;
END;
/

