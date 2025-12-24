/*******************************************************************************
* Script: run_init_tests_utplsql.sql
* Description: utPLSQL test runner for PL_FPDF initialization tests
*              Requires utPLSQL v3+ to be installed
*
* Prerequisites:
*   - utPLSQL v3+ installed in database
*   - test_pl_fpdf_init package compiled
*
* Usage:
*   SQL> @run_init_tests_utplsql.sql
*
* Installation of utPLSQL:
*   See: https://github.com/utPLSQL/utPLSQL
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 1000;

PROMPT
PROMPT ============================================================================
PROMPT PL_FPDF Initialization Tests - utPLSQL Runner
PROMPT ============================================================================
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
    DBMS_OUTPUT.PUT_LINE('ERROR: utPLSQL not found!');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Please install utPLSQL from:');
    DBMS_OUTPUT.PUT_LINE('  https://github.com/utPLSQL/utPLSQL');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Or use the simple test runner:');
    DBMS_OUTPUT.PUT_LINE('  @run_init_tests_simple.sql');
    DBMS_OUTPUT.PUT_LINE('');
    RAISE_APPLICATION_ERROR(-20999, 'utPLSQL not installed');
  END IF;

  DBMS_OUTPUT.PUT_LINE('utPLSQL found - running tests...');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Run all tests in the suite
EXEC ut.run('test_pl_fpdf_init');

PROMPT
PROMPT ============================================================================
PROMPT Run specific test groups:
PROMPT ============================================================================
PROMPT
PROMPT -- Run only basic initialization tests:
PROMPT EXEC ut.run('test_pl_fpdf_init', ut_varchar2_list('basic'));
PROMPT
PROMPT -- Run only validation tests:
PROMPT EXEC ut.run('test_pl_fpdf_init', ut_varchar2_list('validation'));
PROMPT
PROMPT -- Run smoke tests:
PROMPT EXEC ut.run('test_pl_fpdf_init', ut_varchar2_list('smoke'));
PROMPT
PROMPT -- Run with coverage:
PROMPT EXEC ut.run('test_pl_fpdf_init', ut_coverage_html_reporter());
PROMPT
PROMPT ============================================================================
PROMPT

-- Optional: Run with HTML reporter (save output to file)
/*
SET TERMOUT OFF;
SPOOL test_results.html;

SELECT *
FROM TABLE(
  ut.run(
    'test_pl_fpdf_init',
    ut_coverage_html_reporter()
  )
);

SPOOL OFF;
SET TERMOUT ON;

PROMPT Test results saved to test_results.html
*/
