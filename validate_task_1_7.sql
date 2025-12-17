--------------------------------------------------------------------------------
-- Task 1.7 Validation Tests: CLOB Buffer Refactoring
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-17
--------------------------------------------------------------------------------
-- Tests current buffer implementation and validates it works correctly
-- Task 1.7 full implementation (VARCHAR2 array → CLOB) is pending
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

DECLARE
  l_test_count NUMBER := 0;
  l_pass_count NUMBER := 0;
  l_fail_count NUMBER := 0;
  l_test_name VARCHAR2(200);
  l_pdf_blob BLOB;

  -- Test result tracking
  PROCEDURE start_test(p_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    l_test_name := p_name;
  END;

  PROCEDURE pass_test IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('[PASS] Test ' || l_test_count || ': ' || l_test_name);
  END;

  PROCEDURE fail_test(p_reason VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('[FAIL] Test ' || l_test_count || ': ' || l_test_name);
    IF p_reason IS NOT NULL THEN
      DBMS_OUTPUT.PUT_LINE('  Reason: ' || p_reason);
    END IF;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Task 1.7 Validation Tests ===');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('NOTE: Task 1.7 full implementation (VARCHAR2 → CLOB) is pending.');
  DBMS_OUTPUT.PUT_LINE('      These tests validate current buffer implementation works correctly.');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: Current Buffer Implementation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: Current Buffer Implementation ---');

  -- Test 1: Simple PDF generation
  BEGIN
    start_test('Generate simple PDF with current buffer');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'Buffer Test', '1', 1, 'L');
    l_pdf_blob := PL_FPDF.OutputBlob();

    IF l_pdf_blob IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf_blob) > 0 THEN
      pass_test;
    ELSE
      fail_test('PDF generation failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error: ' || SQLERRM);
  END;

  -- Test 2: Multi-page PDF
  BEGIN
    start_test('Generate 10-page PDF');
    PL_FPDF.Init('P', 'mm', 'A4');
    FOR i IN 1..10 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Page ' || i || ' of 10', '0', 1, 'L');
    END LOOP;
    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 5000 THEN
      pass_test;
    ELSE
      fail_test('Multi-page PDF too small');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error: ' || SQLERRM);
  END;

  -- Test 3: Large content page
  BEGIN
    start_test('Generate page with large content');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);

    FOR i IN 1..50 LOOP
      PL_FPDF.Cell(90, 5, 'Cell ' || i || ' Left', '1', 0, 'L');
      PL_FPDF.Cell(90, 5, 'Cell ' || i || ' Right', '1', 1, 'R');
    END LOOP;

    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 2000 THEN
      pass_test;
    ELSE
      fail_test('Large content PDF too small');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error: ' || SQLERRM);
  END;

  -- Test 4: Buffer overflow detection
  BEGIN
    start_test('Detect buffer limits (VARCHAR2 array)');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);

    -- Try to generate a lot of content
    FOR i IN 1..100 LOOP
      PL_FPDF.Cell(180, 4, 'Line ' || i || ': This is a test line with some content to fill the buffer', '1', 1, 'L');
    END LOOP;

    l_pdf_blob := PL_FPDF.OutputBlob();
    pass_test;

  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -6502 OR SQLERRM LIKE '%buffer%' OR SQLERRM LIKE '%string%small%' THEN
        fail_test('Buffer overflow detected (Task 1.7 will fix this)');
      ELSE
        fail_test('Error: ' || SQLERRM);
      END IF;
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: Performance Tests
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: Performance Tests ---');

  -- Test 5: 50-page document
  BEGIN
    start_test('Generate 50-page document');
    PL_FPDF.Init('P', 'mm', 'A4');

    FOR i IN 1..50 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', 'B', 14);
      PL_FPDF.Cell(0, 10, 'Page ' || i, '0', 1, 'C');
      PL_FPDF.SetFont('Arial', '', 10);
      PL_FPDF.MultiCell(0, 5, 'This is page ' || i || ' content. ' ||
                              'Testing buffer performance with multiple pages.');
    END LOOP;

    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 10000 THEN
      pass_test;
    ELSE
      fail_test('50-page document too small');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -6502 THEN
        fail_test('Buffer overflow at 50 pages (Task 1.7 will fix this)');
      ELSE
        fail_test('Error: ' || SQLERRM);
      END IF;
  END;

  -- Test 6: Multiple OutputBlob calls
  BEGIN
    start_test('Multiple OutputBlob() calls');

    -- First document
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'Doc 1', '1', 1, 'L');
    l_pdf_blob := PL_FPDF.OutputBlob();

    -- Second document
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'Doc 2', '1', 1, 'L');
    l_pdf_blob := PL_FPDF.OutputBlob();

    IF l_pdf_blob IS NOT NULL THEN
      pass_test;
    ELSE
      fail_test('Second OutputBlob failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error: ' || SQLERRM);
  END;

  -------------------------------------------------------------------------
  -- Test Group 3: Memory Management
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: Memory Management ---');

  -- Test 7: Buffer cleanup
  BEGIN
    start_test('Buffer cleanup between documents');

    -- Generate multiple small documents
    FOR i IN 1..5 LOOP
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 10);
      PL_FPDF.Cell(50, 10, 'Test ' || i, '1', 1, 'L');
      l_pdf_blob := PL_FPDF.OutputBlob();
    END LOOP;

    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error: ' || SQLERRM);
  END;

  -- Test 8: Large then small document
  BEGIN
    start_test('Large then small document generation');

    -- Large document
    PL_FPDF.Init('P', 'mm', 'A4');
    FOR i IN 1..20 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Large doc page ' || i, '0', 1, 'L');
    END LOOP;
    l_pdf_blob := PL_FPDF.OutputBlob();

    -- Small document
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'Small', '1', 1, 'L');
    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 0 AND DBMS_LOB.GETLENGTH(l_pdf_blob) < 5000 THEN
      pass_test;
    ELSE
      fail_test('Buffer not cleaned properly');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test('Error: ' || SQLERRM);
  END;

  -------------------------------------------------------------------------
  -- Summary
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('SUMMARY: ' || l_pass_count || '/' || l_test_count || ' tests passed');
  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('STATUS: ✓ ALL TESTS PASSED (Current buffer works correctly)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('STATUS: ✗ ' || l_fail_count || ' TEST(S) FAILED');
  END IF;
  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('TASK 1.7 STATUS: Infrastructure validation complete');
  DBMS_OUTPUT.PUT_LINE('PENDING: Full CLOB buffer refactoring (VARCHAR2 array → single CLOB)');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('BENEFITS OF CLOB REFACTORING:');
  DBMS_OUTPUT.PUT_LINE('  - No 32KB VARCHAR2 limits per element');
  DBMS_OUTPUT.PUT_LINE('  - Better performance with DBMS_LOB.WRITEAPPEND');
  DBMS_OUTPUT.PUT_LINE('  - Support for documents >1000 pages');
  DBMS_OUTPUT.PUT_LINE('  - Reduced memory fragmentation');
  DBMS_OUTPUT.PUT_LINE('  - Simpler code (single CLOB vs array management)');

END;
/
