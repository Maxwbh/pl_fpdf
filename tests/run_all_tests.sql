--------------------------------------------------------------------------------
-- PL_FPDF Complete Test Suite Runner (Legacy - utPLSQL)
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12 (Updated: 2026-01)
-- Version: 3.0.0-b.2
--
-- Description: Legacy test runner using utPLSQL framework
--
-- IMPORTANT: For the new organized test runner, use:
--   @tests/test_runner.sql  (Recommended - Phases 1-4 comprehensive tests)
--
-- This file uses utPLSQL (if installed) for legacy test compatibility.
-- For modern phase-based testing without utPLSQL dependency, use test_runner.sql
--
-- Usage:
--   sqlplus user/pass@db @run_all_tests.sql
--   Or: EXEC ut.run('test_pl_fpdf');
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 5000

PROMPT
PROMPT ================================================================================
PROMPT   PL_FPDF Complete Test Suite (Legacy - utPLSQL)
PROMPT   Version: 3.0.0-b.2
PROMPT ================================================================================
PROMPT   NOTICE: This is the legacy test runner using utPLSQL.
PROMPT   For modern phase-based testing, use: @tests/test_runner.sql
PROMPT ================================================================================
PROMPT   Running all test packages with utPLSQL framework
PROMPT ================================================================================
PROMPT

-- Check if utPLSQL is installed
DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO l_count
  FROM all_objects
  WHERE object_name = 'UT'
    AND object_type = 'PACKAGE';

  IF l_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: utPLSQL is not installed.');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Please use the modern test runner instead (no utPLSQL required):');
    DBMS_OUTPUT.PUT_LINE('  @tests/test_runner.sql        - Comprehensive test suite (RECOMMENDED)');
    DBMS_OUTPUT.PUT_LINE('  @tests/validate_phases_1_3.sql    - Phase 1-3 validation');
    DBMS_OUTPUT.PUT_LINE('  @tests/validate_phase_4_complete.sql - Phase 4 validation');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Or install utPLSQL: https://utplsql.org/');
    RAISE_APPLICATION_ERROR(-20000, 'utPLSQL not found');
  END IF;
END;
/

PROMPT
PROMPT Running test suite: test_pl_fpdf_init (Initialization Tests)
PROMPT --------------------------------------------------------------------------------
EXEC ut.run('test_pl_fpdf_init');

PROMPT
PROMPT Running test suite: test_pl_fpdf_fonts (Font Handling Tests)
PROMPT --------------------------------------------------------------------------------
EXEC ut.run('test_pl_fpdf_fonts');

PROMPT
PROMPT Running test suite: test_pl_fpdf_images (Image Processing Tests)
PROMPT --------------------------------------------------------------------------------
EXEC ut.run('test_pl_fpdf_images');

PROMPT
PROMPT Running test suite: test_pl_fpdf_output (PDF Generation Tests)
PROMPT --------------------------------------------------------------------------------
EXEC ut.run('test_pl_fpdf_output');

PROMPT
PROMPT Running test suite: test_pl_fpdf_performance (Performance Tests)
PROMPT --------------------------------------------------------------------------------
EXEC ut.run('test_pl_fpdf_performance');

PROMPT
PROMPT ================================================================================
PROMPT   Complete Test Suite - Summary
PROMPT ================================================================================
PROMPT   All legacy utPLSQL test suites executed.
PROMPT   Check output above for detailed results.
PROMPT ================================================================================
PROMPT
PROMPT   Note: These are legacy tests. For comprehensive Phase 1-4 testing:
PROMPT   @tests/test_runner.sql
PROMPT ================================================================================
PROMPT

-- Generate coverage report (optional - comment out if not needed)
PROMPT
PROMPT Generating code coverage report...
PROMPT
/*
BEGIN
  ut.run(
    ut_varchar2_list(
      'test_pl_fpdf_init',
      'test_pl_fpdf_fonts',
      'test_pl_fpdf_images',
      'test_pl_fpdf_output',
      'test_pl_fpdf_performance'
    ),
    ut_coverage_html_reporter()
  );
END;
/
*/

SET FEEDBACK ON
SET VERIFY ON

PROMPT
PROMPT Test suite execution complete.
PROMPT
