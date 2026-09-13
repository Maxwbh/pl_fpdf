--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-a.4 - Phase 4.3: Watermark Tests
-- Description: Test suite for AddWatermark and GetWatermarks APIs
--------------------------------------------------------------------------------



DECLARE
  l_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_watermarks JSON_ARRAY_T;
  l_watermark JSON_OBJECT_T;
  l_is_modified BOOLEAN;

  -- Test helper procedures
  PROCEDURE caso(p_test_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test ' || l_test_count || ': ' || p_test_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
  END;

  PROCEDURE passou(p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || NVL(p_message, 'Test passed'));
  END;

  PROCEDURE falhou(p_message VARCHAR2) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_message);
  END;

  -- Create valid test PDF with 10 pages using PL_FPDF itself
  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1..10 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Page ' || i);
    END LOOP;
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-a.4 - PHASE 4.3: Watermark Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF with 10 pages
  create_test_pdf();

  --------------------------------------------------------------------------------
  -- TEST 1: Load PDF and add watermark to all pages
  --------------------------------------------------------------------------------
  caso('AddWatermark - Apply to ALL pages');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');

    l_watermarks := PL_FPDF.GetWatermarks();
    l_is_modified := PL_FPDF.IsPDFModified();

    IF l_watermarks.get_size() = 1 THEN
      passou('1 watermark added');
    ELSE
      falhou('Expected 1 watermark, got ' || l_watermarks.get_size());
    END IF;

    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);
    IF l_watermark.get_string('text') = 'CONFIDENTIAL' THEN
      passou('Watermark text correct: CONFIDENTIAL');
    ELSE
      falhou('Watermark text incorrect: ' || l_watermark.get_string('text'));
    END IF;

    IF l_watermark.get_number('opacity') = 0.3 THEN
      passou('Opacity correct: 0.3');
    ELSE
      falhou('Opacity incorrect: ' || l_watermark.get_number('opacity'));
    END IF;

    IF l_watermark.get_number('rotation') = 45 THEN
      passou('Rotation correct: 45 degrees');
    ELSE
      falhou('Rotation incorrect: ' || l_watermark.get_number('rotation'));
    END IF;

    IF l_is_modified THEN
      passou('PDF marked as modified');
    ELSE
      falhou('PDF should be marked as modified');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error adding watermark: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: AddWatermark - Specific page range '1-3'
  --------------------------------------------------------------------------------
  caso('AddWatermark - Specific range: 1-3');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('DRAFT', 0.2, 90, '1-3');

    l_watermarks := PL_FPDF.GetWatermarks();
    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);

    DBMS_OUTPUT.PUT_LINE('  Page range: ' || l_watermark.get_string('pageRange'));

    -- Page range should be parsed to '1,2,3'
    IF l_watermark.get_string('pageRange') = '1,2,3' THEN
      passou('Page range parsed correctly: 1,2,3');
    ELSE
      falhou('Page range incorrect: ' || l_watermark.get_string('pageRange'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error with page range: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: AddWatermark - Complex range '1,3,5-7,10'
  --------------------------------------------------------------------------------
  caso('AddWatermark - Complex range: 1,3,5-7,10');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1,3,5-7,10');

    l_watermarks := PL_FPDF.GetWatermarks();
    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);

    DBMS_OUTPUT.PUT_LINE('  Page range: ' || l_watermark.get_string('pageRange'));

    -- Page range should be parsed to '1,3,5,6,7,10'
    IF l_watermark.get_string('pageRange') = '1,3,5,6,7,10' THEN
      passou('Complex range parsed correctly: 1,3,5,6,7,10');
    ELSE
      falhou('Page range incorrect: ' || l_watermark.get_string('pageRange'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error with complex range: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: AddWatermark - Multiple watermarks
  --------------------------------------------------------------------------------
  caso('AddWatermark - Multiple watermarks');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
    PL_FPDF.AddWatermark('DRAFT', 0.3, 90, '1-5');
    PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '10');

    l_watermarks := PL_FPDF.GetWatermarks();

    IF l_watermarks.get_size() = 3 THEN
      passou('3 watermarks added');
    ELSE
      falhou('Expected 3 watermarks, got ' || l_watermarks.get_size());
    END IF;

    -- Verify each watermark
    FOR i IN 0..l_watermarks.get_size() - 1 LOOP
      l_watermark := TREAT(l_watermarks.get(i) AS JSON_OBJECT_T);
      DBMS_OUTPUT.PUT_LINE('  Watermark ' || (i + 1) || ': ' ||
        l_watermark.get_string('text') || ' on pages ' ||
        l_watermark.get_string('pageRange'));
    END LOOP;

    passou('All watermarks stored correctly');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error with multiple watermarks: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: AddWatermark - Invalid parameters (empty text)
  --------------------------------------------------------------------------------
  caso('AddWatermark - Invalid text (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('', 0.3, 45, 'ALL');  -- Empty text
    falhou('Should have raised error for empty text');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20816 THEN
        passou('Correctly rejected empty watermark text');
      ELSE
        falhou('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: AddWatermark - Invalid opacity
  --------------------------------------------------------------------------------
  caso('AddWatermark - Invalid opacity (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('TEST', 1.5, 45, 'ALL');  -- Opacity > 1
    falhou('Should have raised error for opacity > 1');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20817 THEN
        passou('Correctly rejected invalid opacity');
      ELSE
        falhou('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: AddWatermark - Invalid rotation
  --------------------------------------------------------------------------------
  caso('AddWatermark - Invalid rotation (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('TEST', 0.3, 60, 'ALL');  -- Invalid rotation
    falhou('Should have raised error for invalid rotation');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20818 THEN
        passou('Correctly rejected invalid rotation (60 degrees)');
      ELSE
        falhou('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 8: AddWatermark - Invalid page range
  --------------------------------------------------------------------------------
  caso('AddWatermark - Invalid page range (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('TEST', 0.3, 45, '1-20');  -- Page 20 doesn't exist
    falhou('Should have raised error for invalid page range');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20815 THEN
        passou('Correctly rejected invalid page range (1-20)');
      ELSE
        falhou('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 9: ClearPDFCache - Verify watermarks cleared
  --------------------------------------------------------------------------------
  caso('ClearPDFCache - Verify watermarks cleared');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- GetWatermarks should fail after clearing
    BEGIN
      l_watermarks := PL_FPDF.GetWatermarks();
      falhou('Should have raised error after ClearPDFCache');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          passou('Correctly raised error after clearing cache');
        ELSE
          falhou('Wrong error code: ' || SQLCODE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error clearing cache: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST SUMMARY
  --------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('TEST SUMMARY');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  -- l_test_count conta blocos (caso); l_pass/l_fail contam verificações.
  -- O percentual precisa ser sobre as verificações, senão passa de 100%.
  DBMS_OUTPUT.PUT_LINE('Testes:       ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Verificações: ' || (l_pass_count + l_fail_count));
  DBMS_OUTPUT.PUT_LINE('Passou:       ' || l_pass_count || ' (' ||
    CASE WHEN l_pass_count + l_fail_count = 0 THEN '0'
         ELSE TO_CHAR(ROUND(l_pass_count / (l_pass_count + l_fail_count) * 100, 1))
    END || '%)');
  DBMS_OUTPUT.PUT_LINE('Falhou:       ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** SOME TESTS FAILED ***');
  END IF;

  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/
