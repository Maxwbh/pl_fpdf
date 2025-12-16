/*******************************************************************************
* Validation Script for Task 1.2: AddPage/SetPage BLOB Streaming
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*
* This script validates the implementation of Task 1.2 enhancements:
* - New page types (recPageFormat, recPage, tPages)
* - Enhanced AddPage with rotation and custom formats
* - SetPage for page navigation
* - GetCurrentPage for current page inquiry
* - Standard page format library (A3, A4, A5, Letter, Legal, etc.)
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

PROMPT ======================================================================
PROMPT Task 1.2 Validation: AddPage/SetPage BLOB Streaming
PROMPT ======================================================================
PROMPT

DECLARE
  l_is_init boolean;
  l_current_page pls_integer;
  l_test_passed boolean := true;
  l_test_count pls_integer := 0;
  l_pass_count pls_integer := 0;

  procedure test_result(p_test_name varchar2, p_passed boolean) is
  begin
    l_test_count := l_test_count + 1;
    if p_passed then
      l_pass_count := l_pass_count + 1;
      dbms_output.put_line('[PASS] Test ' || l_test_count || ': ' || p_test_name);
    else
      dbms_output.put_line('[FAIL] Test ' || l_test_count || ': ' || p_test_name);
      l_test_passed := false;
    end if;
  end;

BEGIN
  dbms_output.put_line('=== Task 1.2 Validation Tests ===');
  dbms_output.put_line('');

  -------------------------------------------------------------------------
  -- Test Group 1: Initialization and Prerequisites
  -------------------------------------------------------------------------
  dbms_output.put_line('--- Test Group 1: Initialization ---');

  -- Test 1: Initialize PDF engine
  begin
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    l_is_init := PL_FPDF.IsInitialized();
    test_result('Init() before AddPage', l_is_init);
  exception
    when others then
      test_result('Init() before AddPage', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 2: Basic Page Creation
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 2: Basic Page Creation ---');

  -- Test 2: AddPage with default parameters
  begin
    PL_FPDF.AddPage();  -- Default: Portrait, A4, 0° rotation
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('AddPage() with defaults (page=1)', l_current_page = 1);
  exception
    when others then
      test_result('AddPage() with defaults', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 3: AddPage Portrait A4
  begin
    PL_FPDF.AddPage('P', 'A4', 0);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('AddPage(''P'', ''A4'', 0) (page=2)', l_current_page = 2);
  exception
    when others then
      test_result('AddPage Portrait A4', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 4: AddPage Landscape Letter
  begin
    PL_FPDF.AddPage('L', 'Letter', 0);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('AddPage(''L'', ''Letter'', 0) (page=3)', l_current_page = 3);
  exception
    when others then
      test_result('AddPage Landscape Letter', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 3: Custom Page Formats
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 3: Custom Page Formats ---');

  -- Test 5: Custom format "100,200"
  begin
    PL_FPDF.AddPage('P', '100,200', 0);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('AddPage custom format ''100,200'' (page=4)', l_current_page = 4);
  exception
    when others then
      test_result('AddPage custom format', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 6: Invalid custom format (should fail)
  begin
    PL_FPDF.AddPage('P', 'abc,xyz', 0);
    test_result('Invalid format should raise error', false);
  exception
    when others then
      if sqlcode = -20103 then
        test_result('Invalid format raises -20103', true);
      else
        test_result('Invalid format error code', false);
        dbms_output.put_line('  Expected: -20103, Got: ' || sqlcode);
      end if;
  end;

  -------------------------------------------------------------------------
  -- Test Group 4: Page Rotation
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 4: Page Rotation ---');

  -- Test 7: Rotation 90°
  begin
    PL_FPDF.AddPage('P', 'A4', 90);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('AddPage with 90° rotation (page=5)', l_current_page = 5);
  exception
    when others then
      test_result('AddPage 90° rotation', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 8: Rotation 180°
  begin
    PL_FPDF.AddPage('P', 'A4', 180);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('AddPage with 180° rotation (page=6)', l_current_page = 6);
  exception
    when others then
      test_result('AddPage 180° rotation', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 9: Invalid rotation (should fail)
  begin
    PL_FPDF.AddPage('P', 'A4', 45);
    test_result('Invalid rotation should raise error', false);
  exception
    when others then
      if sqlcode = -20104 then
        test_result('Invalid rotation raises -20104', true);
      else
        test_result('Invalid rotation error code', false);
        dbms_output.put_line('  Expected: -20104, Got: ' || sqlcode);
      end if;
  end;

  -------------------------------------------------------------------------
  -- Test Group 5: SetPage Navigation
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 5: SetPage Navigation ---');

  -- Test 10: SetPage to page 1
  begin
    PL_FPDF.SetPage(1);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('SetPage(1)', l_current_page = 1);
  exception
    when others then
      test_result('SetPage(1)', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 11: SetPage to page 3
  begin
    PL_FPDF.SetPage(3);
    l_current_page := PL_FPDF.GetCurrentPage();
    test_result('SetPage(3)', l_current_page = 3);
  exception
    when others then
      test_result('SetPage(3)', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 12: SetPage to non-existent page (should fail)
  begin
    PL_FPDF.SetPage(999);
    test_result('SetPage to invalid page should fail', false);
  exception
    when others then
      if sqlcode = -20106 then
        test_result('SetPage invalid page raises -20106', true);
      else
        test_result('SetPage invalid page error code', false);
        dbms_output.put_line('  Expected: -20106, Got: ' || sqlcode);
      end if;
  end;

  -------------------------------------------------------------------------
  -- Test Group 6: Multiple Page Formats
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 6: Standard Page Formats ---');

  -- Test 13-19: Test various standard formats
  declare
    l_formats dbms_sql.varchar2_table;
    l_idx pls_integer := 1;
  begin
    l_formats(1) := 'A3';
    l_formats(2) := 'A5';
    l_formats(3) := 'Legal';
    l_formats(4) := 'Ledger';
    l_formats(5) := 'Executive';
    l_formats(6) := 'Folio';
    l_formats(7) := 'B5';

    for i in 1..l_formats.count loop
      begin
        PL_FPDF.AddPage('P', l_formats(i), 0);
        test_result('AddPage format ' || l_formats(i), true);
      exception
        when others then
          test_result('AddPage format ' || l_formats(i), false);
          dbms_output.put_line('  Error: ' || sqlerrm);
      end;
    end loop;
  end;

  -------------------------------------------------------------------------
  -- Summary
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('=======================================================================');
  dbms_output.put_line('SUMMARY: ' || l_pass_count || '/' || l_test_count || ' tests passed');

  if l_test_passed then
    dbms_output.put_line('STATUS: ✓ ALL TESTS PASSED');
  else
    dbms_output.put_line('STATUS: ✗ SOME TESTS FAILED');
  end if;

  dbms_output.put_line('=======================================================================');

  -- Cleanup
  PL_FPDF.Reset();

  if not l_test_passed then
    raise_application_error(-20999, 'Task 1.2 validation failed');
  end if;

END;
/

PROMPT
PROMPT Validation complete!
PROMPT
