--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-a.3 - Phase 4.2: Page Management Tests
-- Description: Test suite for RemovePage, GetActivePageCount, modification tracking
--------------------------------------------------------------------------------


DECLARE
  l_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_page_count PLS_INTEGER;
  l_active_count PLS_INTEGER;
  l_is_removed BOOLEAN;
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

  -- Create valid test PDF with 5 pages using PL_FPDF itself
  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1..5 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Page ' || i);
    END LOOP;
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-a.3 - PHASE 4.2: Page Management Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF with 5 pages
  create_test_pdf();

  --------------------------------------------------------------------------------
  -- TEST 1: Load PDF and verify initial state
  --------------------------------------------------------------------------------
  caso('Load PDF and verify initial state');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);
    l_page_count := PL_FPDF.GetPageCount();
    l_active_count := PL_FPDF.GetActivePageCount();
    l_is_modified := PL_FPDF.IsPDFModified();

    IF l_page_count = 5 THEN
      passou('Total page count correct: 5 pages');
    ELSE
      falhou('Expected 5 pages, got ' || l_page_count);
    END IF;

    IF l_active_count = 5 THEN
      passou('Active page count correct: 5 pages (none removed)');
    ELSE
      falhou('Expected 5 active pages, got ' || l_active_count);
    END IF;

    IF NOT l_is_modified THEN
      passou('PDF not modified initially');
    ELSE
      falhou('PDF should not be marked as modified initially');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error loading PDF: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: RemovePage - Remove page 2
  --------------------------------------------------------------------------------
  caso('RemovePage - Remove page 2');
  BEGIN
    PL_FPDF.RemovePage(2);

    l_active_count := PL_FPDF.GetActivePageCount();
    l_is_removed := PL_FPDF.IsPageRemoved(2);
    l_is_modified := PL_FPDF.IsPDFModified();

    IF l_active_count = 4 THEN
      passou('Active page count correct: 4 pages (1 removed)');
    ELSE
      falhou('Expected 4 active pages, got ' || l_active_count);
    END IF;

    IF l_is_removed THEN
      passou('Page 2 marked as removed');
    ELSE
      falhou('Page 2 should be marked as removed');
    END IF;

    IF l_is_modified THEN
      passou('PDF marked as modified');
    ELSE
      falhou('PDF should be marked as modified');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error removing page: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: RemovePage - Remove multiple pages (3 and 5)
  --------------------------------------------------------------------------------
  caso('RemovePage - Remove pages 3 and 5');
  BEGIN
    PL_FPDF.RemovePage(3);
    PL_FPDF.RemovePage(5);

    l_active_count := PL_FPDF.GetActivePageCount();

    IF l_active_count = 2 THEN
      passou('Active page count correct: 2 pages (3 removed total)');
    ELSE
      falhou('Expected 2 active pages, got ' || l_active_count);
    END IF;

    -- Verify individual page status
    IF PL_FPDF.IsPageRemoved(2) AND PL_FPDF.IsPageRemoved(3) AND PL_FPDF.IsPageRemoved(5) THEN
      passou('Pages 2, 3, 5 correctly marked as removed');
    ELSE
      falhou('Not all pages correctly marked as removed');
    END IF;

    IF NOT PL_FPDF.IsPageRemoved(1) AND NOT PL_FPDF.IsPageRemoved(4) THEN
      passou('Pages 1, 4 correctly marked as active');
    ELSE
      falhou('Pages 1, 4 should not be marked as removed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error removing pages: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: RemovePage - Attempt to remove already removed page
  --------------------------------------------------------------------------------
  caso('RemovePage - Attempt to remove already removed page (should fail)');
  BEGIN
    PL_FPDF.RemovePage(2);  -- Already removed in TEST 2
    falhou('Should have raised error for already removed page');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20814 THEN
        passou('Correctly rejected attempt to remove already removed page');
      ELSE
        falhou('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: RemovePage - Invalid page number
  --------------------------------------------------------------------------------
  caso('RemovePage - Invalid page number (should fail)');
  BEGIN
    PL_FPDF.RemovePage(99);  -- PDF only has 5 pages
    falhou('Should have raised error for invalid page number');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20812 THEN
        passou('Correctly rejected invalid page number');
      ELSE
        falhou('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: RotatePage and check modification flag
  --------------------------------------------------------------------------------
  caso('RotatePage - Verify modification tracking');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Should not be modified initially
    IF NOT PL_FPDF.IsPDFModified() THEN
      passou('PDF not modified after fresh load');
    ELSE
      falhou('PDF should not be modified after fresh load');
    END IF;

    -- Rotate a page
    PL_FPDF.RotatePage(1, 90);

    IF PL_FPDF.IsPDFModified() THEN
      passou('PDF marked as modified after rotation');
    ELSE
      falhou('PDF should be marked as modified after rotation');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('Error in modification tracking: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: ClearPDFCache - Verify cleanup of modification tracking
  --------------------------------------------------------------------------------
  caso('ClearPDFCache - Verify cleanup');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- Try to check modification status after clearing - should fail
    BEGIN
      l_is_modified := PL_FPDF.IsPDFModified();
      -- IsPDFModified doesn't validate PDF loaded, so it will return FALSE
      IF NOT l_is_modified THEN
        passou('Modification flag cleared after cache clear');
      ELSE
        falhou('Modification flag should be cleared');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        falhou('Unexpected error: ' || SQLERRM);
    END;

    -- GetActivePageCount should fail after clearing
    BEGIN
      l_active_count := PL_FPDF.GetActivePageCount();
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
