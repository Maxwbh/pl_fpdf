--------------------------------------------------------------------------------
-- PL_FPDF Complete Test Suite Runner
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-19
-- Task: 3.4 - Unit Tests with utPLSQL
--
-- Description: Runs all PL_FPDF test suites using utPLSQL framework
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
PROMPT   PL_FPDF Complete Test Suite
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
    DBMS_OUTPUT.PUT_LINE('Please install utPLSQL or use simple test runners:');
    DBMS_OUTPUT.PUT_LINE('  - @run_init_tests_simple.sql');
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
PROMPT   All test suites executed.
PROMPT   Check output above for detailed results.
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
