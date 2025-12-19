/*******************************************************************************
* Script: uninstall_tests.sql
* Description: Uninstalls PL_FPDF test suite
*
* Usage:
*   sqlplus user/pass@db @uninstall_tests.sql
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*******************************************************************************/

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT
PROMPT ============================================================================
PROMPT Uninstalling PL_FPDF Test Suite
PROMPT ============================================================================
PROMPT

-- Drop test package
PROMPT Dropping test package...

DROP PACKAGE test_pl_fpdf_init;

PROMPT
PROMPT Verifying removal...

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO l_count
  FROM user_objects
  WHERE object_name = 'TEST_PL_FPDF_INIT';

  IF l_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✓ Test suite uninstalled successfully!');
  ELSE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✗ Test suite still exists after removal');
  END IF;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT Uninstallation Complete
PROMPT ============================================================================
PROMPT
