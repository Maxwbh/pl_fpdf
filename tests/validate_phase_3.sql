--------------------------------------------------------------------------------
-- Phase 3 Validation Script: Advanced Modernization
-- PL_FPDF Modernization Project
-- Date: 2025-12-19
--------------------------------------------------------------------------------
-- Tests all Phase 3 functionality:
-- - Modern code structure with constants
-- - JSON configuration and metadata APIs
-- - Performance optimizations
-- - Generic QR Code generation
-- - Generic Barcode generation
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   Phase 3 Validation: Advanced Modernization
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
  DBMS_OUTPUT.PUT_LINE('Task 3.2: JSON Configuration APIs');
  DBMS_OUTPUT.PUT_LINE('----------------------------------');

  -- Test 3.2.1: SetDocumentConfig
  DECLARE
    l_config JSON_OBJECT_T := JSON_OBJECT_T();
    l_pdf BLOB;
  BEGIN
    l_config.put('title', 'Test Document');
    l_config.put('author', 'PL_FPDF Test Suite');
    l_config.put('subject', 'Phase 3 Validation');
    l_config.put('orientation', 'P');
    l_config.put('format', 'A4');

    PL_FPDF.Init();
    PL_FPDF.SetDocumentConfig(l_config);
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'JSON Config Test');
    l_pdf := PL_FPDF.OutputBlob();

    test_result('SetDocumentConfig with JSON', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('SetDocumentConfig', FALSE, SQLERRM);
  END;

  -- Test 3.2.2: GetDocumentMetadata
  DECLARE
    l_metadata JSON_OBJECT_T;
    l_page_count NUMBER;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.SetTitle('Metadata Test');
    PL_FPDF.SetAuthor('Test Author');
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();

    l_metadata := PL_FPDF.GetDocumentMetadata();
    l_page_count := l_metadata.get_Number('pageCount');

    test_result('GetDocumentMetadata returns valid JSON', l_metadata IS NOT NULL);
    test_result('GetDocumentMetadata pageCount correct', l_page_count = 3);
    test_result('GetDocumentMetadata title correct',
                l_metadata.get_String('title') = 'Metadata Test');

    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('GetDocumentMetadata', FALSE, SQLERRM);
  END;

  -- Test 3.2.3: GetPageInfo
  DECLARE
    l_page_info JSON_OBJECT_T;
    l_width NUMBER;
    l_height NUMBER;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    l_page_info := PL_FPDF.GetPageInfo(1);
    l_width := l_page_info.get_Number('width');
    l_height := l_page_info.get_Number('height');

    test_result('GetPageInfo returns valid JSON', l_page_info IS NOT NULL);
    test_result('GetPageInfo A4 dimensions',
                l_width = 210 AND l_height = 297);

    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageInfo', FALSE, SQLERRM);
  END;

  -- Test 3.2.4: JSON configuration with fonts
  DECLARE
    l_config JSON_OBJECT_T := JSON_OBJECT_T();
    l_pdf BLOB;
  BEGIN
    l_config.put('fontFamily', 'Courier');
    l_config.put('fontSize', 14);
    l_config.put('fontStyle', 'B');

    PL_FPDF.Init();
    PL_FPDF.SetDocumentConfig(l_config);
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Bold Courier 14pt');
    l_pdf := PL_FPDF.OutputBlob();

    test_result('JSON config with font settings', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('JSON font configuration', FALSE, SQLERRM);
  END;

  -- Test 3.2.5: JSON configuration with margins
  DECLARE
    l_config JSON_OBJECT_T := JSON_OBJECT_T();
    l_pdf BLOB;
  BEGIN
    l_config.put('leftMargin', 20);
    l_config.put('topMargin', 15);
    l_config.put('rightMargin', 20);

    PL_FPDF.Init();
    PL_FPDF.SetDocumentConfig(l_config);
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Custom Margins');
    l_pdf := PL_FPDF.OutputBlob();

    test_result('JSON config with margin settings', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('JSON margin configuration', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 3.3 & 3.6: Performance Optimization');
  DBMS_OUTPUT.PUT_LINE('-----------------------------------------');

  -- Test 3.3.1: Init performance
  DECLARE
    l_start TIMESTAMP;
    l_duration NUMBER;
  BEGIN
    l_start := SYSTIMESTAMP;
    FOR i IN 1..10 LOOP
      PL_FPDF.Init();
      PL_FPDF.Reset();
    END LOOP;
    l_duration := EXTRACT(SECOND FROM (SYSTIMESTAMP - l_start));

    test_result('Init/Reset cycle performance (10 iterations < 1s)',
                l_duration < 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('Init performance', FALSE, SQLERRM);
  END;

  -- Test 3.3.2: Large document performance
  DECLARE
    l_start TIMESTAMP;
    l_duration NUMBER;
    l_pdf BLOB;
  BEGIN
    l_start := SYSTIMESTAMP;
    PL_FPDF.Init();
    PL_FPDF.SetFont('Arial', '', 12);

    FOR i IN 1..100 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Page ' || i || ' of 100');
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();
    l_duration := EXTRACT(SECOND FROM (SYSTIMESTAMP - l_start));

    test_result('100-page document generation < 5s', l_duration < 5);
    DBMS_OUTPUT.PUT_LINE('      Duration: ' || ROUND(l_duration, 2) || 's');
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Large document performance', FALSE, SQLERRM);
  END;

  -- Test 3.3.3: CLOB buffer performance
  DECLARE
    l_start TIMESTAMP;
    l_duration NUMBER;
    l_pdf BLOB;
  BEGIN
    l_start := SYSTIMESTAMP;
    PL_FPDF.Init();
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.AddPage();

    -- Generate large content
    FOR i IN 1..1000 LOOP
      PL_FPDF.Cell(0, 4, 'Line ' || i || ': Testing CLOB buffer performance');
      PL_FPDF.Ln(4);
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();
    l_duration := EXTRACT(SECOND FROM (SYSTIMESTAMP - l_start));

    test_result('CLOB buffer (1000 lines) < 2s', l_duration < 2);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('CLOB buffer performance', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 3.7: Generic QR Code Generation');
  DBMS_OUTPUT.PUT_LINE('-------------------------------------');

  -- Test 3.7.1: AddQRCode TEXT format
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddQRCode(50, 50, 40, 'Hello QR Code', 'TEXT', 'M');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('AddQRCode TEXT format', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('AddQRCode TEXT', FALSE, SQLERRM);
  END;

  -- Test 3.7.2: AddQRCode URL format
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddQRCode(50, 50, 40, 'https://github.com/maxwbh/pl_fpdf', 'URL', 'M');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('AddQRCode URL format', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('AddQRCode URL', FALSE, SQLERRM);
  END;

  -- Test 3.7.3: QR Code error correction levels
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();

    -- Test all error correction levels
    PL_FPDF.AddQRCode(20, 20, 30, 'Level L', 'TEXT', 'L');  -- 7%
    PL_FPDF.AddQRCode(60, 20, 30, 'Level M', 'TEXT', 'M');  -- 15%
    PL_FPDF.AddQRCode(100, 20, 30, 'Level Q', 'TEXT', 'Q'); -- 25%
    PL_FPDF.AddQRCode(140, 20, 30, 'Level H', 'TEXT', 'H'); -- 30%

    l_pdf := PL_FPDF.OutputBlob();
    test_result('QR Code error correction levels (L,M,Q,H)',
                DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('QR Code error correction', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Task 3.8: Generic Barcode Generation');
  DBMS_OUTPUT.PUT_LINE('-------------------------------------');

  -- Test 3.8.1: AddBarcode CODE128
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
    l_pdf := PL_FPDF.OutputBlob();
    test_result('AddBarcode CODE128 format', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('AddBarcode CODE128', FALSE, SQLERRM);
  END;

  -- Test 3.8.2: AddBarcode ITF14
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddBarcode(30, 50, 150, 20, '12345678901234', 'ITF14', TRUE);
    l_pdf := PL_FPDF.OutputBlob();
    test_result('AddBarcode ITF14 format', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('AddBarcode ITF14', FALSE, SQLERRM);
  END;

  -- Test 3.8.3: Barcode with/without text
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddBarcode(30, 50, 150, 20, '123456', 'CODE128', TRUE);   -- With text
    PL_FPDF.AddBarcode(30, 100, 150, 20, '789012', 'CODE128', FALSE); -- Without text
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Barcode with/without human-readable text',
                DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Barcode text option', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Integration Tests');
  DBMS_OUTPUT.PUT_LINE('------------------');

  -- Test: Complete workflow
  DECLARE
    l_config JSON_OBJECT_T := JSON_OBJECT_T();
    l_metadata JSON_OBJECT_T;
    l_pdf BLOB;
  BEGIN
    -- Configure via JSON
    l_config.put('title', 'Phase 3 Integration Test');
    l_config.put('author', 'PL_FPDF v2.0');
    l_config.put('format', 'A4');

    PL_FPDF.Init();
    PL_FPDF.SetDocumentConfig(l_config);

    -- Add content
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 10, 'Integration Test Document');
    PL_FPDF.Ln(15);

    -- Add QR Code
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.Cell(0, 5, 'QR Code:');
    PL_FPDF.Ln(7);
    PL_FPDF.AddQRCode(20, 40, 30, 'https://github.com', 'URL', 'M');

    -- Add Barcode
    PL_FPDF.SetXY(20, 100);
    PL_FPDF.Cell(0, 5, 'Barcode:');
    PL_FPDF.AddBarcode(20, 110, 100, 15, '123456789', 'CODE128', TRUE);

    -- Get metadata
    l_metadata := PL_FPDF.GetDocumentMetadata();

    -- Generate PDF
    l_pdf := PL_FPDF.OutputBlob();

    test_result('Complete workflow (JSON + QR + Barcode)',
                DBMS_LOB.GETLENGTH(l_pdf) > 0 AND
                l_metadata.get_String('title') = 'Phase 3 Integration Test');
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Integration workflow', FALSE, SQLERRM);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Phase 3 Validation Summary');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count || ' (' ||
    ROUND(l_pass_count * 100 / l_test_count, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASE 3: ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASE 3: SOME TESTS FAILED - REVIEW REQUIRED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/
