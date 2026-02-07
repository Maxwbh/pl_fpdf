/*******************************************************************************
* Test Script: Phase 4.6 - PDF Merge & Split
* Version: 3.0.0-a.7
* Date: 2026-01-25
* Author: @maxwbh
*
* Description:
*   Comprehensive test suite for Phase 4.6 multi-document PDF operations
*   including merge, split, and extract functionality.
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT ========================================
PROMPT Phase 4.6: PDF Merge & Split Tests
PROMPT ========================================
PROMPT

DECLARE
  -- Test counters
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  -- Test data
  l_test_pdf1 BLOB;
  l_test_pdf2 BLOB;
  l_test_pdf3 BLOB;
  l_merged BLOB;
  l_split_pdfs JSON_ARRAY_T;
  l_extracted BLOB;
  l_pdfs JSON_ARRAY_T;
  l_pdf_obj JSON_OBJECT_T;

  -- Helper procedures
  PROCEDURE run_test(p_test_name VARCHAR2, p_result BOOLEAN) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_result THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_test_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name || ' - FAIL');
    END IF;
  END run_test;

  PROCEDURE expect_error(p_test_name VARCHAR2, p_expected_code NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name ||
                         ' - FAIL (Expected error ' || p_expected_code || ' but succeeded)');
  END expect_error;

  PROCEDURE handle_expected_error(p_test_name VARCHAR2, p_expected_code NUMBER, p_actual_code NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_actual_code = p_expected_code THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_test_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name ||
                           ' - FAIL (Expected ' || p_expected_code || ', got ' || p_actual_code || ')');
    END IF;
  END handle_expected_error;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting Phase 4.6 Multi-Document Tests...');
  DBMS_OUTPUT.PUT_LINE('');

  -- Create test PDFs (minimal valid PDFs)
  l_test_pdf1 := UTL_RAW.CAST_TO_RAW(
    '%PDF-1.4' || CHR(10) ||
    '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' || CHR(10) ||
    '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj' || CHR(10) ||
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R>>endobj' || CHR(10) ||
    '4 0 obj<</Length 44>>stream' || CHR(10) ||
    'BT /F1 12 Tf 100 700 Td (Test PDF 1) Tj ET' || CHR(10) ||
    'endstream endobj' || CHR(10) ||
    'xref' || CHR(10) || '0 5' || CHR(10) ||
    '0000000000 65535 f ' || CHR(10) ||
    '0000000009 00000 n ' || CHR(10) ||
    '0000000058 00000 n ' || CHR(10) ||
    '0000000115 00000 n ' || CHR(10) ||
    '0000000214 00000 n ' || CHR(10) ||
    'trailer<</Size 5/Root 1 0 R>>' || CHR(10) ||
    'startxref' || CHR(10) || '314' || CHR(10) || '%%EOF'
  );

  l_test_pdf2 := UTL_RAW.CAST_TO_RAW(
    '%PDF-1.4' || CHR(10) ||
    '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' || CHR(10) ||
    '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj' || CHR(10) ||
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R>>endobj' || CHR(10) ||
    '4 0 obj<</Length 44>>stream' || CHR(10) ||
    'BT /F1 12 Tf 100 700 Td (Test PDF 2) Tj ET' || CHR(10) ||
    'endstream endobj' || CHR(10) ||
    'xref' || CHR(10) || '0 5' || CHR(10) ||
    '0000000000 65535 f ' || CHR(10) ||
    '0000000009 00000 n ' || CHR(10) ||
    '0000000058 00000 n ' || CHR(10) ||
    '0000000115 00000 n ' || CHR(10) ||
    '0000000214 00000 n ' || CHR(10) ||
    'trailer<</Size 5/Root 1 0 R>>' || CHR(10) ||
    'startxref' || CHR(10) || '314' || CHR(10) || '%%EOF'
  );

  l_test_pdf3 := UTL_RAW.CAST_TO_RAW(
    '%PDF-1.4' || CHR(10) ||
    '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' || CHR(10) ||
    '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj' || CHR(10) ||
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R>>endobj' || CHR(10) ||
    '4 0 obj<</Length 44>>stream' || CHR(10) ||
    'BT /F1 12 Tf 100 700 Td (Test PDF 3) Tj ET' || CHR(10) ||
    'endstream endobj' || CHR(10) ||
    'xref' || CHR(10) || '0 5' || CHR(10) ||
    '0000000000 65535 f ' || CHR(10) ||
    '0000000009 00000 n ' || CHR(10) ||
    '0000000058 00000 n ' || CHR(10) ||
    '0000000115 00000 n ' || CHR(10) ||
    '0000000214 00000 n ' || CHR(10) ||
    'trailer<</Size 5/Root 1 0 R>>' || CHR(10) ||
    'startxref' || CHR(10) || '314' || CHR(10) || '%%EOF'
  );

  DBMS_OUTPUT.PUT_LINE('=== LoadPDFWithID Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 1: Load single PDF with ID
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf1);
    run_test('Load PDF with ID', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Load PDF with ID', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 2: Load multiple PDFs
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf2', l_test_pdf2);
    PL_FPDF.LoadPDFWithID('pdf3', l_test_pdf3);
    run_test('Load multiple PDFs', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Load multiple PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 3: Load duplicate ID (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf1);
    expect_error('Load duplicate PDF ID', -20828);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Load duplicate PDF ID', -20828, SQLCODE);
  END;

  -- Test 4: Load with NULL ID (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID(NULL, l_test_pdf1);
    expect_error('Load with NULL ID', -20830);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Load with NULL ID', -20830, SQLCODE);
  END;

  -- Test 5: Load with NULL BLOB (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf_null', NULL);
    expect_error('Load with NULL BLOB', -20830);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Load with NULL BLOB', -20830, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== GetLoadedPDFs Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 6: Get loaded PDFs
  BEGIN
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    run_test('GetLoadedPDFs returns array', l_pdfs IS NOT NULL AND l_pdfs.get_size() >= 3);
    DBMS_OUTPUT.PUT_LINE('   Found ' || l_pdfs.get_size() || ' loaded PDFs');

    -- Display PDF details
    FOR i IN 0..l_pdfs.get_size() - 1 LOOP
      l_pdf_obj := TREAT(l_pdfs.get(i) AS JSON_OBJECT_T);
      DBMS_OUTPUT.PUT_LINE('   - ' || l_pdf_obj.get_string('pdfId') ||
                          ': ' || l_pdf_obj.get_number('pageCount') || ' pages, ' ||
                          ROUND(l_pdf_obj.get_number('fileSize')/1024, 1) || ' KB');
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('GetLoadedPDFs returns array', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== MergePDFs Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 7: Merge 2 PDFs
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf2"]'), NULL);
    run_test('Merge 2 PDFs', l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
    DBMS_OUTPUT.PUT_LINE('   Merged PDF size: ' || DBMS_LOB.GETLENGTH(l_merged) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Merge 2 PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 8: Merge 3 PDFs
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf2","pdf3"]'), NULL);
    run_test('Merge 3 PDFs', l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
    DBMS_OUTPUT.PUT_LINE('   Merged PDF size: ' || DBMS_LOB.GETLENGTH(l_merged) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Merge 3 PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 9: Merge with empty array (should error)
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('[]'), NULL);
    expect_error('Merge with empty array', -20832);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Merge with empty array', -20832, SQLCODE);
  END;

  -- Test 10: Merge with non-loaded PDF (should error)
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf_notloaded"]'), NULL);
    expect_error('Merge with non-loaded PDF', -20833);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Merge with non-loaded PDF', -20833, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== ExtractPages Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 11: Extract ALL pages
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', 'ALL', NULL);
    run_test('Extract ALL pages', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Extracted PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Extract ALL pages', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 12: Extract single page
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', '1', NULL);
    run_test('Extract single page', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Extracted PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Extract single page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 13: Extract from non-loaded PDF (should error)
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf_notexist', '1', NULL);
    expect_error('Extract from non-loaded PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Extract from non-loaded PDF', -20831, SQLCODE);
  END;

  -- Test 14: Extract with NULL page spec (should error)
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', NULL, NULL);
    expect_error('Extract with NULL page spec', -20838);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Extract with NULL page spec', -20838, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== SplitPDF Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 15: Split PDF
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf1', JSON_ARRAY_T('["1"]'));
    run_test('Split PDF into 1 part', l_split_pdfs IS NOT NULL AND l_split_pdfs.get_size() = 1);
    DBMS_OUTPUT.PUT_LINE('   Split into ' || l_split_pdfs.get_size() || ' parts');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Split PDF into 1 part', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 16: Split with empty ranges (should error)
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf1', JSON_ARRAY_T('[]'));
    expect_error('Split with empty ranges', -20835);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Split with empty ranges', -20835, SQLCODE);
  END;

  -- Test 17: Split non-loaded PDF (should error)
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf_notexist', JSON_ARRAY_T('["1"]'));
    expect_error('Split non-loaded PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Split non-loaded PDF', -20831, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== UnloadPDF Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 18: Unload PDF
  BEGIN
    PL_FPDF.UnloadPDF('pdf3');
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    run_test('Unload PDF', l_pdfs.get_size() = 2);
    DBMS_OUTPUT.PUT_LINE('   Remaining PDFs: ' || l_pdfs.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Unload PDF', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 19: Unload non-existent PDF (should error)
  BEGIN
    PL_FPDF.UnloadPDF('pdf_notexist');
    expect_error('Unload non-existent PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Unload non-existent PDF', -20831, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Integration Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 20: Load, merge, extract workflow
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf4', l_test_pdf1);
    PL_FPDF.LoadPDFWithID('pdf5', l_test_pdf2);

    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf4","pdf5"]'), NULL);
    PL_FPDF.LoadPDFWithID('merged', l_merged);

    l_extracted := PL_FPDF.ExtractPages('merged', 'ALL', NULL);

    run_test('Load-Merge-Extract workflow', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Final PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Load-Merge-Extract workflow', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Final summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('Test Summary:');
  DBMS_OUTPUT.PUT_LINE('  Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('  Passed:      ' || l_pass_count || ' (' ||
                      ROUND(l_pass_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('  Failed:      ' || l_fail_count || ' (' ||
                      ROUND(l_fail_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('========================================');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('✓ ALL TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✗ SOME TESTS FAILED');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Test execution aborted at test ' || l_test_count);
    RAISE;
END;
/

PROMPT
PROMPT Test script completed.
PROMPT
