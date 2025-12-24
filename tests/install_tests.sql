/*******************************************************************************
* Script: install_tests.sql
* Description: Installs PL_FPDF test suite
*
* Usage:
*   sqlplus user/pass@db @install_tests.sql
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*******************************************************************************/

SET SERVEROUTPUT ON;
SET FEEDBACK ON;
SET VERIFY OFF;

PROMPT
PROMPT ============================================================================
PROMPT Installing PL_FPDF Test Suite
PROMPT ============================================================================
PROMPT

-- Check if PL_FPDF package exists
DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO l_count
  FROM all_objects
  WHERE object_name = 'PL_FPDF'
    AND object_type = 'PACKAGE';

  IF l_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('WARNING: PL_FPDF package not found!');
    DBMS_OUTPUT.PUT_LINE('Please install PL_FPDF before installing tests.');
    DBMS_OUTPUT.PUT_LINE('');
    RAISE_APPLICATION_ERROR(-20998, 'PL_FPDF package required');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✓ PL_FPDF package found');
  END IF;
END;
/

PROMPT
PROMPT Installing test package specification...
@@test_pl_fpdf_init.pks

PROMPT
PROMPT Installing test package body...
@@test_pl_fpdf_init.pkb

PROMPT
PROMPT Verifying installation...

DECLARE
  l_spec_status VARCHAR2(10);
  l_body_status VARCHAR2(10);
BEGIN
  -- Check spec
  SELECT status
  INTO l_spec_status
  FROM user_objects
  WHERE object_name = 'TEST_PL_FPDF_INIT'
    AND object_type = 'PACKAGE';

  -- Check body
  SELECT status
  INTO l_body_status
  FROM user_objects
  WHERE object_name = 'TEST_PL_FPDF_INIT'
    AND object_type = 'PACKAGE BODY';

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Package Specification: ' || l_spec_status);
  DBMS_OUTPUT.PUT_LINE('Package Body: ' || l_body_status);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_spec_status = 'VALID' AND l_body_status = 'VALID' THEN
    DBMS_OUTPUT.PUT_LINE('✓ Test suite installed successfully!');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✗ Test suite installation failed - check errors above');
    RAISE_APPLICATION_ERROR(-20997, 'Installation failed');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('✗ Test packages not found after installation');
    RAISE_APPLICATION_ERROR(-20996, 'Installation incomplete');
END;
/

PROMPT
PROMPT ============================================================================
PROMPT Installation Complete
PROMPT ============================================================================
PROMPT
PROMPT To run tests:
PROMPT   Simple runner:  @run_init_tests_simple.sql
PROMPT   utPLSQL runner: @run_init_tests_utplsql.sql
PROMPT
PROMPT   Or use: EXEC ut.run('test_pl_fpdf_init');
PROMPT
PROMPT ============================================================================
PROMPT
