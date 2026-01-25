/*******************************************************************************
* Test Script: Phase 4.5 - Text & Image Overlay
* Version: 3.0.0-a.6
* Date: 2026-01-25
* Author: @maxwbh
*
* Description:
*   Comprehensive test suite for Phase 4.5 overlay functionality including
*   text overlays, image overlays, and overlay management operations.
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT ========================================
PROMPT Phase 4.5: Text & Image Overlay Tests
PROMPT ========================================
PROMPT

DECLARE
  -- Test counters
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  -- Test data
  l_test_pdf BLOB;
  l_logo_blob BLOB;
  l_result BLOB;
  l_overlays JSON_ARRAY_T;
  l_overlay JSON_OBJECT_T;
  l_options JSON_OBJECT_T;
  l_overlay_id VARCHAR2(50);

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
  DBMS_OUTPUT.PUT_LINE('Starting Phase 4.5 Overlay Tests...');
  DBMS_OUTPUT.PUT_LINE('');

  -- Create test PDF (simple PDF with one blank page)
  -- For testing purposes, we'll create a minimal valid PDF
  l_test_pdf := UTL_RAW.CAST_TO_RAW(
    '%PDF-1.4' || CHR(10) ||
    '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' || CHR(10) ||
    '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj' || CHR(10) ||
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R>>endobj' || CHR(10) ||
    '4 0 obj<</Length 44>>stream' || CHR(10) ||
    'BT /F1 12 Tf 100 700 Td (Test Page) Tj ET' || CHR(10) ||
    'endstream' || CHR(10) ||
    'endobj' || CHR(10) ||
    'xref' || CHR(10) ||
    '0 5' || CHR(10) ||
    '0000000000 65535 f ' || CHR(10) ||
    '0000000009 00000 n ' || CHR(10) ||
    '0000000058 00000 n ' || CHR(10) ||
    '0000000115 00000 n ' || CHR(10) ||
    '0000000214 00000 n ' || CHR(10) ||
    'trailer<</Size 5/Root 1 0 R>>' || CHR(10) ||
    'startxref' || CHR(10) ||
    '314' || CHR(10) ||
    '%%EOF'
  );

  -- Create test logo (1x1 PNG - simplest valid PNG)
  l_logo_blob := HEXTORAW('89504E470D0A1A0A0000000D494844520000000100000001010000000037' ||
                          '6EF9240000000A49444154789C626001000000050001ED5F38E40000000049' ||
                          '454E44AE426082');

  DBMS_OUTPUT.PUT_LINE('=== Text Overlay Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 1: OverlayText without PDF loaded (should fail)
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.OverlayText(1, 'Test', 100, 700, NULL);
    expect_error('OverlayText without PDF loaded', -20809);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('OverlayText without PDF loaded', -20809, SQLCODE);
  END;

  -- Test 2: Simple text overlay
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
    run_test('Simple text overlay', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Simple text overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 3: Text overlay with options
  BEGIN
    l_options := JSON_OBJECT_T();
    l_options.put('font', 'Helvetica-Bold');
    l_options.put('fontSize', 24);
    l_options.put('color', 'FF0000');  -- Red
    l_options.put('opacity', 0.8);
    l_options.put('rotation', 45);
    PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
    run_test('Text overlay with formatting options', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Text overlay with formatting options', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 4: Text overlay with invalid page number
  BEGIN
    PL_FPDF.OverlayText(999, 'Test', 100, 700, NULL);
    expect_error('Text overlay with invalid page number', -20810);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Text overlay with invalid page number', -20810, SQLCODE);
  END;

  -- Test 5: Text overlay with invalid coordinates
  BEGIN
    PL_FPDF.OverlayText(1, 'Test', -100, 700, NULL);
    expect_error('Text overlay with negative X coordinate', -20821);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Text overlay with negative X coordinate', -20821, SQLCODE);
  END;

  -- Test 6: Text overlay with invalid opacity
  BEGIN
    l_options := JSON_OBJECT_T();
    l_options.put('opacity', 1.5);
    PL_FPDF.OverlayText(1, 'Test', 100, 700, l_options);
    expect_error('Text overlay with invalid opacity', -20821);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Text overlay with invalid opacity', -20821, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Image Overlay Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 7: Simple image overlay
  BEGIN
    PL_FPDF.OverlayImage(1, l_logo_blob, 450, 750, 100, 50, NULL);
    run_test('Simple image overlay', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Simple image overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 8: Image overlay with options
  BEGIN
    l_options := JSON_OBJECT_T();
    l_options.put('opacity', 0.3);
    l_options.put('rotation', 45);
    l_options.put('maintainAspect', TRUE);
    PL_FPDF.OverlayImage(1, l_logo_blob, 200, 400, 300, NULL, l_options);
    run_test('Image overlay with transparency and rotation', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Image overlay with transparency and rotation', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 9: Image overlay with invalid format
  BEGIN
    PL_FPDF.OverlayImage(1, UTL_RAW.CAST_TO_RAW('Invalid'), 100, 100, NULL, NULL, NULL);
    expect_error('Image overlay with invalid format', -20823);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Image overlay with invalid format', -20823, SQLCODE);
  END;

  -- Test 10: Image overlay with NULL image
  BEGIN
    PL_FPDF.OverlayImage(1, NULL, 100, 100, NULL, NULL, NULL);
    expect_error('Image overlay with NULL image', -20823);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Image overlay with NULL image', -20823, SQLCODE);
  END;

  -- Test 11: Image overlay with invalid dimensions
  BEGIN
    PL_FPDF.OverlayImage(1, l_logo_blob, 100, 100, -50, 50, NULL);
    expect_error('Image overlay with negative width', -20824);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Image overlay with negative width', -20824, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Overlay Management Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 12: GetOverlays - list all overlays
  BEGIN
    l_overlays := PL_FPDF.GetOverlays();
    run_test('GetOverlays - list all', l_overlays.get_size() > 0);
    DBMS_OUTPUT.PUT_LINE('   Found ' || l_overlays.get_size() || ' overlays');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('GetOverlays - list all', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 13: GetOverlays - filter by page
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('GetOverlays - filter by page', l_overlays.get_size() > 0);
    DBMS_OUTPUT.PUT_LINE('   Found ' || l_overlays.get_size() || ' overlays on page 1');

    -- Display overlay details
    FOR i IN 0..l_overlays.get_size() - 1 LOOP
      l_overlay := TREAT(l_overlays.get(i) AS JSON_OBJECT_T);
      DBMS_OUTPUT.PUT_LINE('   - ' || l_overlay.get_string('overlayType') || ': ' ||
                          l_overlay.get_string('overlayId'));
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('GetOverlays - filter by page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 14: RemoveOverlay
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(1);
    IF l_overlays.get_size() > 0 THEN
      l_overlay := TREAT(l_overlays.get(0) AS JSON_OBJECT_T);
      l_overlay_id := l_overlay.get_string('overlayId');
      PL_FPDF.RemoveOverlay(l_overlay_id);
      run_test('RemoveOverlay - remove specific overlay', TRUE);
      DBMS_OUTPUT.PUT_LINE('   Removed overlay: ' || l_overlay_id);
    ELSE
      run_test('RemoveOverlay - remove specific overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   No overlays to remove');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('RemoveOverlay - remove specific overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 15: RemoveOverlay with invalid ID
  BEGIN
    PL_FPDF.RemoveOverlay('INVALID_ID');
    expect_error('RemoveOverlay with invalid ID', -20825);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('RemoveOverlay with invalid ID', -20825, SQLCODE);
  END;

  -- Test 16: ClearOverlays - specific page
  BEGIN
    PL_FPDF.ClearOverlays(1);
    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('ClearOverlays - specific page', l_overlays.get_size() = 0);
    DBMS_OUTPUT.PUT_LINE('   Overlays on page 1: ' || l_overlays.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('ClearOverlays - specific page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 17: Add more overlays and clear all
  BEGIN
    PL_FPDF.OverlayText(1, 'Test 1', 100, 100, NULL);
    PL_FPDF.OverlayText(1, 'Test 2', 200, 200, NULL);
    PL_FPDF.OverlayImage(1, l_logo_blob, 300, 300, 50, 50, NULL);

    l_overlays := PL_FPDF.GetOverlays();
    DBMS_OUTPUT.PUT_LINE('   Added 3 overlays, total: ' || l_overlays.get_size());

    PL_FPDF.ClearOverlays();  -- Clear all
    l_overlays := PL_FPDF.GetOverlays();
    run_test('ClearOverlays - clear all', l_overlays.get_size() = 0);
    DBMS_OUTPUT.PUT_LINE('   Remaining overlays: ' || l_overlays.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('ClearOverlays - clear all', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Integration Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 18: Multiple overlays with different z-orders
  BEGIN
    PL_FPDF.ClearOverlays();

    l_options := JSON_OBJECT_T();
    l_options.put('zOrder', 1);
    PL_FPDF.OverlayText(1, 'Bottom Layer', 100, 100, l_options);

    l_options := JSON_OBJECT_T();
    l_options.put('zOrder', 100);
    PL_FPDF.OverlayText(1, 'Top Layer', 120, 120, l_options);

    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('Multiple overlays with z-order', l_overlays.get_size() = 2);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Multiple overlays with z-order', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 19: Overlay persistence check
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('Overlay persistence', l_overlays.get_size() = 2);
    DBMS_OUTPUT.PUT_LINE('   Persisted overlays: ' || l_overlays.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Overlay persistence', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 20: ClearPDFCache clears overlays
  BEGIN
    PL_FPDF.ClearPDFCache();
    BEGIN
      l_overlays := PL_FPDF.GetOverlays();
      run_test('ClearPDFCache clears overlays', FALSE);
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          run_test('ClearPDFCache clears overlays', TRUE);
        ELSE
          run_test('ClearPDFCache clears overlays', FALSE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('ClearPDFCache clears overlays', FALSE);
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
