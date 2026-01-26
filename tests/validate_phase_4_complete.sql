/*******************************************************************************
* Validation Script: Phase 4 Complete Validation (4.1-4.6)
* Version: 3.0.0-b.2
* Date: 2026-01
* Author: @maxwbh
*
* Purpose: Complete validation for PDF Reading & Manipulation (Phase 4)
*
* Validates:
*   - Phase 4.1A: PDF Parser
*   - Phase 4.1B: Page Information
*   - Phase 4.2: Page Management (Rotate, Remove)
*   - Phase 4.3: Watermarks
*   - Phase 4.4: Output Modified PDF
*   - Phase 4.5: Text & Image Overlay
*   - Phase 4.6: PDF Merge & Split
*
* Usage:
*   SET SERVEROUTPUT ON SIZE UNLIMITED
*   @tests/validate_phase_4_complete.sql
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT ================================================================================
PROMPT PL_FPDF - Phase 4 Complete Validation (PDF Reading & Manipulation)
PROMPT Version: 3.0.0-b.2
PROMPT ================================================================================
PROMPT

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  l_test_pdf BLOB;
  l_test_pdf_2 BLOB;
  l_result BLOB;
  l_info JSON_OBJECT_T;

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

  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test Page 1');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Test Page 2');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Test Page 3');
    l_test_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END create_test_pdf;

  PROCEDURE create_test_pdf_2 IS
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Second PDF - Page 1');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Second PDF - Page 2');
    l_test_pdf_2 := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END create_test_pdf_2;

BEGIN
  -- Create test PDFs
  create_test_pdf();
  create_test_pdf_2();

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.1A: PDF Parser');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: LoadPDF
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    test_result('LoadPDF - Load existing PDF', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('LoadPDF', FALSE, SQLERRM);
  END;

  -- Test: IsPDFLoaded
  BEGIN
    test_result('IsPDFLoaded - Check if PDF is loaded', PL_FPDF.IsPDFLoaded());
  EXCEPTION WHEN OTHERS THEN
    test_result('IsPDFLoaded', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.1B: Page Information');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: GetPageCount
  BEGIN
    l_info := PL_FPDF.GetPageCount();
    test_result('GetPageCount - Count pages in PDF',
                l_info.get_number('count') = 3);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageCount', FALSE, SQLERRM);
  END;

  -- Test: GetPageInfo
  BEGIN
    l_info := PL_FPDF.GetPageInfo(1);
    test_result('GetPageInfo - Get page 1 information',
                l_info.has('page_number') AND l_info.get_number('page_number') = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageInfo', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.2: Page Management');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: RotatePage
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RotatePage(1, 90);
    l_info := PL_FPDF.GetPageInfo(1);
    test_result('RotatePage - Rotate page 90 degrees',
                l_info.get_number('rotation') = 90);
  EXCEPTION WHEN OTHERS THEN
    test_result('RotatePage', FALSE, SQLERRM);
  END;

  -- Test: RemovePage
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RemovePage(2);
    l_info := PL_FPDF.GetPageCount();
    test_result('RemovePage - Remove page 2',
                l_info.get_number('count') = 2);
  EXCEPTION WHEN OTHERS THEN
    test_result('RemovePage', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.3: Watermarks');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: AddWatermark
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.AddWatermark('CONFIDENTIAL', NULL);
    test_result('AddWatermark - Add watermark to all pages', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('AddWatermark', FALSE, SQLERRM);
  END;

  -- Test: GetWatermarks
  DECLARE
    l_watermarks JSON_ARRAY_T;
  BEGIN
    l_watermarks := PL_FPDF.GetWatermarks();
    test_result('GetWatermarks - List watermarks',
                l_watermarks IS NOT NULL AND l_watermarks.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetWatermarks', FALSE, SQLERRM);
  END;

  -- Test: RemoveWatermark
  DECLARE
    l_watermarks JSON_ARRAY_T;
    l_watermark JSON_OBJECT_T;
    l_wm_id VARCHAR2(100);
  BEGIN
    l_watermarks := PL_FPDF.GetWatermarks();
    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);
    l_wm_id := l_watermark.get_string('watermark_id');
    PL_FPDF.RemoveWatermark(l_wm_id);
    test_result('RemoveWatermark - Remove specific watermark', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('RemoveWatermark', FALSE, SQLERRM);
  END;

  -- Test: ClearWatermarks
  BEGIN
    PL_FPDF.ClearWatermarks();
    l_info := PL_FPDF.GetWatermarks();
    test_result('ClearWatermarks - Clear all watermarks',
                l_info.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ClearWatermarks', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.4: Output Modified PDF');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: OutputModifiedPDF
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RotatePage(1, 90);
    l_result := PL_FPDF.OutputModifiedPDF();
    test_result('OutputModifiedPDF - Generate modified PDF',
                l_result IS NOT NULL AND DBMS_LOB.GETLENGTH(l_result) > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('OutputModifiedPDF', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.5: Text & Image Overlay');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: OverlayText
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.OverlayText(1, 'APPROVED', 100, 100, NULL);
    test_result('OverlayText - Add text overlay to page', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('OverlayText', FALSE, SQLERRM);
  END;

  -- Test: GetOverlays
  DECLARE
    l_overlays JSON_ARRAY_T;
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(NULL);
    test_result('GetOverlays - List all overlays',
                l_overlays IS NOT NULL AND l_overlays.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetOverlays', FALSE, SQLERRM);
  END;

  -- Test: OverlayImage
  DECLARE
    l_minimal_png BLOB;
  BEGIN
    -- Minimal 1x1 PNG (67 bytes)
    l_minimal_png := HEXTORAW(
      '89504E470D0A1A0A' || -- PNG signature
      '0000000D49484452' || -- IHDR chunk
      '0000000100000001' || -- 1x1 dimensions
      '0806000000' ||       -- 8-bit RGBA
      '1F15C4890000000A' || -- CRC + IDAT chunk header
      '49444154' ||         -- IDAT
      '789C6300010000050001' || -- Compressed data
      '0D0A2DB40000000049454E44AE426082'); -- IEND chunk

    PL_FPDF.OverlayImage(1, l_minimal_png, 50, 50, NULL, NULL, NULL);
    test_result('OverlayImage - Add image overlay to page', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('OverlayImage', FALSE, SQLERRM);
  END;

  -- Test: RemoveOverlay
  DECLARE
    l_overlays JSON_ARRAY_T;
    l_overlay JSON_OBJECT_T;
    l_overlay_id VARCHAR2(100);
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(NULL);
    IF l_overlays.get_size() > 0 THEN
      l_overlay := TREAT(l_overlays.get(0) AS JSON_OBJECT_T);
      l_overlay_id := l_overlay.get_string('overlay_id');
      PL_FPDF.RemoveOverlay(l_overlay_id);
      test_result('RemoveOverlay - Remove specific overlay', TRUE);
    ELSE
      test_result('RemoveOverlay', FALSE, 'No overlays to remove');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    test_result('RemoveOverlay', FALSE, SQLERRM);
  END;

  -- Test: ClearOverlays
  BEGIN
    PL_FPDF.ClearOverlays(NULL);
    l_info := PL_FPDF.GetOverlays(NULL);
    test_result('ClearOverlays - Clear all overlays',
                l_info.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ClearOverlays', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.6: PDF Merge & Split');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: LoadPDFWithID
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf);
    PL_FPDF.LoadPDFWithID('pdf2', l_test_pdf_2);
    test_result('LoadPDFWithID - Load multiple PDFs with IDs', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('LoadPDFWithID', FALSE, SQLERRM);
  END;

  -- Test: GetLoadedPDFs
  DECLARE
    l_pdfs JSON_ARRAY_T;
  BEGIN
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    test_result('GetLoadedPDFs - List loaded PDFs',
                l_pdfs IS NOT NULL AND l_pdfs.get_size() = 2);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetLoadedPDFs', FALSE, SQLERRM);
  END;

  -- Test: MergePDFs
  DECLARE
    l_merged BLOB;
    l_pdf_ids JSON_ARRAY_T;
  BEGIN
    l_pdf_ids := JSON_ARRAY_T('["pdf1", "pdf2"]');
    l_merged := PL_FPDF.MergePDFs(l_pdf_ids, NULL);
    test_result('MergePDFs - Merge two PDFs',
                l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('MergePDFs', FALSE, SQLERRM);
  END;

  -- Test: ExtractPages
  DECLARE
    l_extracted BLOB;
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', '1', NULL);
    test_result('ExtractPages - Extract single page',
                l_extracted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_extracted) > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ExtractPages', FALSE, SQLERRM);
  END;

  -- Test: SplitPDF
  DECLARE
    l_splits JSON_ARRAY_T;
    l_ranges JSON_ARRAY_T;
  BEGIN
    l_ranges := JSON_ARRAY_T('["1", "2-3"]');
    l_splits := PL_FPDF.SplitPDF('pdf1', l_ranges, NULL);
    test_result('SplitPDF - Split PDF into multiple parts',
                l_splits IS NOT NULL AND l_splits.get_size() = 2);
  EXCEPTION WHEN OTHERS THEN
    test_result('SplitPDF', FALSE, SQLERRM);
  END;

  -- Test: UnloadPDF
  BEGIN
    PL_FPDF.UnloadPDF('pdf2');
    l_info := PL_FPDF.GetLoadedPDFs();
    test_result('UnloadPDF - Unload specific PDF',
                l_info.get_size() = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('UnloadPDF', FALSE, SQLERRM);
  END;

  -- Test: ClearPDFCache
  BEGIN
    PL_FPDF.ClearPDFCache();
    l_info := PL_FPDF.GetLoadedPDFs();
    test_result('ClearPDFCache - Clear all loaded PDFs',
                l_info.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ClearPDFCache', FALSE, SQLERRM);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Phase 4 Complete Validation Summary');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count || ' (' ||
    ROUND(l_pass_count * 100 / l_test_count, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase Coverage:');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.1A: PDF Parser         ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.1B: Page Information   ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.2:  Page Management    ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.3:  Watermarks         ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.4:  Output Modified    ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.5:  Text/Image Overlay ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.6:  Merge & Split      ✓');
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4: ALL TESTS PASSED ***');
    DBMS_OUTPUT.PUT_LINE('*** PDF READING & MANIPULATION: VALIDATED ***');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Phase 4 is now complete and ready for production use.');
    DBMS_OUTPUT.PUT_LINE('Version can be promoted from Beta to Release Candidate.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4: SOME TESTS FAILED - REVIEW REQUIRED ***');
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4 REMAINS IN BETA STATUS ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/

PROMPT
PROMPT Validation complete. Review results above.
PROMPT
