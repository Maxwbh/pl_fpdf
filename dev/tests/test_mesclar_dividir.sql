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

  -- Vocabulario canonico da suite. ATE SETEMBRO/2026 ESTE ARQUIVO NAO ERA
  -- CONTADO: ele imprimia "✓ Test 1: nome - PASS", e o runner conta [PASS] e
  -- [FAIL]. Resultado: o arquivo aparecia como "ok 0/0" -- rodava, e uma falha
  -- aqui dentro nao chegava ao total. Sessenta e cinco afericoes invisiveis.
  PROCEDURE confere(p_nome VARCHAR2, p_cond BOOLEAN) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF NVL(p_cond, FALSE) THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_nome);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome);
    END IF;
  END confere;

  -- O erro esperado NAO veio: o caso pedia recusa e a chamada passou.
  PROCEDURE faltou_erro(p_nome VARCHAR2, p_codigo NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ' — esperava ORA' ||
                         p_codigo || ' e a chamada foi aceita');
  END faltou_erro;

  PROCEDURE erro_esperado(p_nome VARCHAR2, p_codigo NUMBER, p_veio NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_veio = p_codigo THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_nome);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ' — esperava ORA' ||
                           p_codigo || ' e veio ORA' || p_veio);
    END IF;
  END erro_esperado;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting Phase 4.6 Multi-Document Tests...');
  DBMS_OUTPUT.PUT_LINE('');

  -- Create valid test PDFs using PL_FPDF itself (guarantees correct structure)
  -- PDF 1
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test PDF 1');
  l_test_pdf1 := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- PDF 2
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test PDF 2');
  l_test_pdf2 := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- PDF 3
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test PDF 3');
  l_test_pdf3 := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- Estado limpo: sem isto, rodar o arquivo duas vezes na mesma sessão falha
  -- com ORA-20828 ('PDF ID already loaded'), porque a coleção multi-documento
  -- sobrevive entre execuções.
  BEGIN
    PL_FPDF.ClearPDFCache;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DBMS_OUTPUT.PUT_LINE('=== LoadPDFWithID Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 1: Load single PDF with ID
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf1);
    confere('Load PDF with ID', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      confere('Load PDF with ID', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 2: Load multiple PDFs
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf2', l_test_pdf2);
    PL_FPDF.LoadPDFWithID('pdf3', l_test_pdf3);
    confere('Load multiple PDFs', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      confere('Load multiple PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 3: Load duplicate ID (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf1);
    faltou_erro('Load duplicate PDF ID', -20828);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Load duplicate PDF ID', -20828, SQLCODE);
  END;

  -- Test 4: Load with NULL ID (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID(NULL, l_test_pdf1);
    faltou_erro('Load with NULL ID', -20830);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Load with NULL ID', -20830, SQLCODE);
  END;

  -- Test 5: Load with NULL BLOB (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf_null', NULL);
    faltou_erro('Load with NULL BLOB', -20830);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Load with NULL BLOB', -20830, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== GetLoadedPDFs Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 6: Get loaded PDFs
  BEGIN
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    confere('GetLoadedPDFs returns array', l_pdfs IS NOT NULL AND l_pdfs.get_size() >= 3);
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
      confere('GetLoadedPDFs returns array', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== MergePDFs Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 7: Merge 2 PDFs
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf2"]'), NULL);
    confere('Merge 2 PDFs', l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
    DBMS_OUTPUT.PUT_LINE('   Merged PDF size: ' || DBMS_LOB.GETLENGTH(l_merged) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      confere('Merge 2 PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 8: Merge 3 PDFs
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf2","pdf3"]'), NULL);
    confere('Merge 3 PDFs', l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
    DBMS_OUTPUT.PUT_LINE('   Merged PDF size: ' || DBMS_LOB.GETLENGTH(l_merged) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      confere('Merge 3 PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 9: Merge with empty array (should error)
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('[]'), NULL);
    faltou_erro('Merge with empty array', -20832);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Merge with empty array', -20832, SQLCODE);
  END;

  -- Test 10: Merge with non-loaded PDF (should error)
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf_notloaded"]'), NULL);
    faltou_erro('Merge with non-loaded PDF', -20833);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Merge with non-loaded PDF', -20833, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== ExtractPages Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 11: Extract ALL pages
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', 'ALL', NULL);
    confere('Extract ALL pages', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Extracted PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      confere('Extract ALL pages', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 12: Extract single page
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', '1', NULL);
    confere('Extract single page', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Extracted PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      confere('Extract single page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 13: Extract from non-loaded PDF (should error)
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf_notexist', '1', NULL);
    faltou_erro('Extract from non-loaded PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Extract from non-loaded PDF', -20831, SQLCODE);
  END;

  -- Test 14: Extract with NULL page spec (should error)
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', NULL, NULL);
    faltou_erro('Extract with NULL page spec', -20838);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Extract with NULL page spec', -20838, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== SplitPDF Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 15: Split PDF
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf1', JSON_ARRAY_T('["1"]'));
    confere('Split PDF into 1 part', l_split_pdfs IS NOT NULL AND l_split_pdfs.get_size() = 1);
    DBMS_OUTPUT.PUT_LINE('   Split into ' || l_split_pdfs.get_size() || ' parts');
  EXCEPTION
    WHEN OTHERS THEN
      confere('Split PDF into 1 part', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 16: Split with empty ranges (should error)
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf1', JSON_ARRAY_T('[]'));
    faltou_erro('Split with empty ranges', -20835);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Split with empty ranges', -20835, SQLCODE);
  END;

  -- Test 17: Split non-loaded PDF (should error)
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf_notexist', JSON_ARRAY_T('["1"]'));
    faltou_erro('Split non-loaded PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Split non-loaded PDF', -20831, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== UnloadPDF Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 18: Unload PDF
  BEGIN
    PL_FPDF.UnloadPDF('pdf3');
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    confere('Unload PDF', l_pdfs.get_size() = 2);
    DBMS_OUTPUT.PUT_LINE('   Remaining PDFs: ' || l_pdfs.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      confere('Unload PDF', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 19: Unload non-existent PDF (should error)
  BEGIN
    PL_FPDF.UnloadPDF('pdf_notexist');
    faltou_erro('Unload non-existent PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      erro_esperado('Unload non-existent PDF', -20831, SQLCODE);
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

    confere('Load-Merge-Extract workflow', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Final PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      confere('Load-Merge-Extract workflow', FALSE);
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

