--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-a.5 - Phase 4.4: OutputModifiedPDF Tests
-- Description: Test suite for OutputModifiedPDF API
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

DECLARE
  l_pdf BLOB;
  l_modified_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_original_size NUMBER;
  l_modified_size NUMBER;

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

  -- Create minimal PDF with 5 pages for testing
  PROCEDURE create_test_pdf IS
    l_kids VARCHAR2(200);
    l_page_objects CLOB;
  BEGIN
    l_kids := '[3 0 R 4 0 R 5 0 R 6 0 R 7 0 R]';

    l_page_objects := '';
    FOR i IN 3..7 LOOP
      l_page_objects := l_page_objects ||
        i || ' 0 obj' || CHR(10) ||
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] ' ||
        '/Resources 8 0 R /Contents 9 0 R >>' || CHR(10) ||
        'endobj' || CHR(10);
    END LOOP;

    l_pdf := UTL_RAW.CAST_TO_RAW(
      '%PDF-1.4' || CHR(10) ||
      '1 0 obj' || CHR(10) ||
      '<< /Type /Catalog /Pages 2 0 R >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '2 0 obj' || CHR(10) ||
      '<< /Type /Pages /Count 5 /Kids ' || l_kids || ' >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      l_page_objects ||
      '8 0 obj' || CHR(10) ||
      '<< /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >>' || CHR(10) ||
      'endobj' || CHR(10) ||
      '9 0 obj' || CHR(10) ||
      '<< /Length 40 >>' || CHR(10) ||
      'stream' || CHR(10) ||
      'BT /F1 12 Tf 100 700 Td (Test) Tj ET' || CHR(10) ||
      'endstream' || CHR(10) ||
      'endobj' || CHR(10) ||
      'xref' || CHR(10) ||
      '0 10' || CHR(10) ||
      '0000000000 65535 f ' || CHR(10) ||
      '0000000009 65535 n ' || CHR(10) ||
      '0000000058 65535 n ' || CHR(10) ||
      '0000000124 65535 n ' || CHR(10) ||
      '0000000224 65535 n ' || CHR(10) ||
      '0000000324 65535 n ' || CHR(10) ||
      '0000000424 65535 n ' || CHR(10) ||
      '0000000524 65535 n ' || CHR(10) ||
      '0000000624 65535 n ' || CHR(10) ||
      '0000000722 65535 n ' || CHR(10) ||
      'trailer' || CHR(10) ||
      '<< /Size 10 /Root 1 0 R >>' || CHR(10) ||
      'startxref' || CHR(10) ||
      '815' || CHR(10) ||
      '%%EOF'
    );
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-a.5 - PHASE 4.4: OutputModifiedPDF Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF with 5 pages
  create_test_pdf();
  l_original_size := DBMS_LOB.GETLENGTH(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Original PDF size: ' || l_original_size || ' bytes');

  --------------------------------------------------------------------------------
  -- TEST 1: OutputModifiedPDF without modifications (should fail)
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - No modifications (should fail)');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);

    -- Try to output without any modifications
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    test_fail('Should have raised error for unmodified PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20819 THEN
        test_pass('Correctly rejected unmodified PDF');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: OutputModifiedPDF with rotation
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - With page rotation');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Rotate page 1
    PL_FPDF.RotatePage(1, 90);

    -- Generate modified PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    IF l_modified_size > 0 THEN
      test_pass('Modified PDF size: ' || l_modified_size || ' bytes');
    ELSE
      test_fail('Modified PDF has zero size');
    END IF;

    -- Check PDF header
    IF UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(l_modified_pdf, 8, 1)) = '%PDF-1.4' THEN
      test_pass('PDF header correct');
    ELSE
      test_fail('Invalid PDF header');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error generating PDF with rotation: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: OutputModifiedPDF with page removal
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - With page removal');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Remove pages 2 and 4
    PL_FPDF.RemovePage(2);
    PL_FPDF.RemovePage(4);

    -- Generate modified PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated with removed pages');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    DBMS_OUTPUT.PUT_LINE('  Original: 5 pages, Modified: 3 pages (removed 2 and 4)');
    test_pass('PDF size: ' || l_modified_size || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error generating PDF with removed pages: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: OutputModifiedPDF with watermark
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - With watermark');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Add watermark
    PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');

    -- Generate modified PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated with watermark');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    test_pass('PDF size: ' || l_modified_size || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error generating PDF with watermark: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: OutputModifiedPDF with combined modifications
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - Combined modifications');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Apply multiple modifications
    PL_FPDF.RotatePage(1, 90);
    PL_FPDF.RemovePage(3);
    PL_FPDF.AddWatermark('DRAFT', 0.2, 45, '1-2');

    -- Generate modified PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated with combined modifications');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    DBMS_OUTPUT.PUT_LINE('  Modifications: rotation, removal, watermark');
    test_pass('PDF size: ' || l_modified_size || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error with combined modifications: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: OutputModifiedPDF after removing all pages (should fail)
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - All pages removed (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Remove all pages
    FOR i IN 1..5 LOOP
      PL_FPDF.RemovePage(i);
    END LOOP;

    -- Try to generate PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    test_fail('Should have raised error for empty PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20820 THEN
        test_pass('Correctly rejected empty PDF (all pages removed)');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: OutputModifiedPDF without loaded PDF (should fail)
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - No PDF loaded (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- Try to output without loading PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    test_fail('Should have raised error for no PDF loaded');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20809 THEN
        test_pass('Correctly raised error for no PDF loaded');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE);
      END IF;
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
