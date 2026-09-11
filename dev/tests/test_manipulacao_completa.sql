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
*   @tests/test_manipulacao_completa.sql
*******************************************************************************/

-- ================================================================================
-- PL_FPDF - Phase 4 Complete Validation (PDF Reading & Manipulation)
-- Version: 3.0.0-b.2
-- ================================================================================
--

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  l_test_pdf BLOB;
  l_test_pdf_2 BLOB;
  l_result BLOB;
  l_info JSON_OBJECT_T;
  l_arr  JSON_ARRAY_T;   -- retornos JSON_ARRAY_T
  l_num  PLS_INTEGER;    -- retornos numéricos

  PROCEDURE confere(p_test_name VARCHAR2, p_passed BOOLEAN, p_message VARCHAR2 DEFAULT NULL) IS
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
  END confere;

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
    confere('LoadPDF - Load existing PDF', TRUE);
  EXCEPTION WHEN OTHERS THEN
    confere('LoadPDF', FALSE, SQLERRM);
  END;

  -- Test: PDF carregado
  -- Nao existe IsPDFLoaded na API; GetPageCount levanta -20809 sem PDF carregado.
  BEGIN
    confere('PDF carregado - GetPageCount responde', PL_FPDF.GetPageCount > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('PDF carregado', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.1B: Page Information');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: GetPageCount
  BEGIN
    l_num := PL_FPDF.GetPageCount;
    confere('GetPageCount - Count pages in PDF', l_num = 3);
  EXCEPTION WHEN OTHERS THEN
    confere('GetPageCount', FALSE, SQLERRM);
  END;

  -- Test: GetPageInfo
  BEGIN
    l_info := PL_FPDF.GetPageInfo(1);
    -- as chaves do JSON são camelCase: pageNumber, não page_number
    confere('GetPageInfo - Get page 1 information',
                l_info.has('pageNumber') AND l_info.get_number('pageNumber') = 1);
  EXCEPTION WHEN OTHERS THEN
    confere('GetPageInfo', FALSE, SQLERRM);
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
    confere('RotatePage - Rotate page 90 degrees',
                l_info.get_number('rotation') = 90);
  EXCEPTION WHEN OTHERS THEN
    confere('RotatePage', FALSE, SQLERRM);
  END;

  -- Test: RemovePage
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RemovePage(2);
    -- RemovePage apenas MARCA a página; GetPageCount continua devolvendo o
    -- total do documento carregado. A remoção se concretiza em
    -- OutputModifiedPDF, e o estado é consultável por IsPageRemoved.
    confere('RemovePage - Remove page 2',
                PL_FPDF.IsPageRemoved(2)
                AND NOT PL_FPDF.IsPageRemoved(1)
                AND PL_FPDF.GetPageCount = 3);
  EXCEPTION WHEN OTHERS THEN
    confere('RemovePage', FALSE, SQLERRM);
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
    confere('AddWatermark - Add watermark to all pages', TRUE);
  EXCEPTION WHEN OTHERS THEN
    confere('AddWatermark', FALSE, SQLERRM);
  END;

  -- Test: GetWatermarks
  DECLARE
    l_watermarks JSON_ARRAY_T;
  BEGIN
    l_watermarks := PL_FPDF.GetWatermarks();
    confere('GetWatermarks - List watermarks',
                l_watermarks IS NOT NULL AND l_watermarks.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('GetWatermarks', FALSE, SQLERRM);
  END;

  -- RemoveWatermark e ClearWatermarks nao existem na API: o teste antigo as
  -- chamava e impedia o bloco inteiro de compilar (ORA-06550). A unica forma
  -- publica de descartar marcas d'agua e ClearPDFCache, que limpa tudo.
  DECLARE
    l_watermarks JSON_ARRAY_T;
  BEGIN
    l_watermarks := PL_FPDF.GetWatermarks();
    confere('GetWatermarks - lista as marcas registradas',
                l_watermarks.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('GetWatermarks', FALSE, SQLERRM);
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
    confere('OutputModifiedPDF - Generate modified PDF',
                l_result IS NOT NULL AND DBMS_LOB.GETLENGTH(l_result) > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('OutputModifiedPDF', FALSE, SQLERRM);
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
    confere('OverlayText - Add text overlay to page', TRUE);
  EXCEPTION WHEN OTHERS THEN
    confere('OverlayText', FALSE, SQLERRM);
  END;

  -- Test: GetOverlays
  DECLARE
    l_overlays JSON_ARRAY_T;
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(NULL);
    confere('GetOverlays - List all overlays',
                l_overlays IS NOT NULL AND l_overlays.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('GetOverlays', FALSE, SQLERRM);
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
    confere('OverlayImage - Add image overlay to page', TRUE);
  EXCEPTION WHEN OTHERS THEN
    confere('OverlayImage', FALSE, SQLERRM);
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
      l_overlay_id := l_overlay.get_string('overlayId');   -- camelCase
      PL_FPDF.RemoveOverlay(l_overlay_id);
      confere('RemoveOverlay - Remove specific overlay', TRUE);
    ELSE
      confere('RemoveOverlay', FALSE, 'No overlays to remove');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    confere('RemoveOverlay', FALSE, SQLERRM);
  END;

  -- Test: ClearOverlays
  BEGIN
    PL_FPDF.ClearOverlays(NULL);
    l_arr := PL_FPDF.GetOverlays(NULL);
    confere('ClearOverlays - Clear all overlays', l_arr.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    confere('ClearOverlays', FALSE, SQLERRM);
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
    confere('LoadPDFWithID - Load multiple PDFs with IDs', TRUE);
  EXCEPTION WHEN OTHERS THEN
    confere('LoadPDFWithID', FALSE, SQLERRM);
  END;

  -- Test: GetLoadedPDFs
  DECLARE
    l_pdfs JSON_ARRAY_T;
  BEGIN
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    confere('GetLoadedPDFs - List loaded PDFs',
                l_pdfs IS NOT NULL AND l_pdfs.get_size() = 2);
  EXCEPTION WHEN OTHERS THEN
    confere('GetLoadedPDFs', FALSE, SQLERRM);
  END;

  -- Test: MergePDFs
  DECLARE
    l_merged BLOB;
    l_pdf_ids JSON_ARRAY_T;
  BEGIN
    l_pdf_ids := JSON_ARRAY_T('["pdf1", "pdf2"]');
    l_merged := PL_FPDF.MergePDFs(l_pdf_ids, NULL);
    confere('MergePDFs - Merge two PDFs',
                l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('MergePDFs', FALSE, SQLERRM);
  END;

  -- Test: ExtractPages
  DECLARE
    l_extracted BLOB;
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', '1', NULL);
    confere('ExtractPages - Extract single page',
                l_extracted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_extracted) > 0);
  EXCEPTION WHEN OTHERS THEN
    confere('ExtractPages', FALSE, SQLERRM);
  END;

  -- Test: SplitPDF
  DECLARE
    l_splits JSON_ARRAY_T;
    l_ranges JSON_ARRAY_T;
  BEGIN
    l_ranges := JSON_ARRAY_T('["1", "2-3"]');
    l_splits := PL_FPDF.SplitPDF('pdf1', l_ranges);
    confere('SplitPDF - Split PDF into multiple parts',
                l_splits IS NOT NULL AND l_splits.get_size() = 2);
  EXCEPTION WHEN OTHERS THEN
    confere('SplitPDF', FALSE, SQLERRM);
  END;

  -- Test: UnloadPDF
  BEGIN
    PL_FPDF.UnloadPDF('pdf2');
    l_arr := PL_FPDF.GetLoadedPDFs();
    confere('UnloadPDF - Unload specific PDF', l_arr.get_size() = 1);
  EXCEPTION WHEN OTHERS THEN
    confere('UnloadPDF', FALSE, SQLERRM);
  END;

  -- Test: ClearPDFCache
  BEGIN
    PL_FPDF.ClearPDFCache();
    l_arr := PL_FPDF.GetLoadedPDFs();
    confere('ClearPDFCache - Clear all loaded PDFs', l_arr.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    confere('ClearPDFCache', FALSE, SQLERRM);
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

--
-- Validation complete. Review results above.
--
