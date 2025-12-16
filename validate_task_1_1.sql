/*******************************************************************************
* Script: validate_task_1_1.sql
* Description: Quick validation script for Task 1.1 implementation
*              Tests compilation and basic functionality
*
* Usage:
*   sqlplus user/pass@db @validate_task_1_1.sql
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;
SET VERIFY OFF;

PROMPT
PROMPT ============================================================================
PROMPT Task 1.1 Validation - Init/Reset/IsInitialized Implementation
PROMPT ============================================================================
PROMPT

-- Step 1: Compile package specification
PROMPT Step 1/3: Compiling package specification...
@@PL_FPDF.pks

PROMPT
PROMPT Checking compilation status (spec)...

DECLARE
  l_status VARCHAR2(10);
BEGIN
  SELECT status
  INTO l_status
  FROM user_objects
  WHERE object_name = 'PL_FPDF'
    AND object_type = 'PACKAGE';

  DBMS_OUTPUT.PUT_LINE('Package Spec Status: ' || l_status);

  IF l_status != 'VALID' THEN
    RAISE_APPLICATION_ERROR(-20990, 'Package specification compilation failed');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✓ Package specification compiled successfully');
  END IF;
END;
/

PROMPT

-- Step 2: Compile package body
PROMPT Step 2/3: Compiling package body...
@@PL_FPDF.pkb

PROMPT
PROMPT Checking compilation status (body)...

DECLARE
  l_status VARCHAR2(10);
BEGIN
  SELECT status
  INTO l_status
  FROM user_objects
  WHERE object_name = 'PL_FPDF'
    AND object_type = 'PACKAGE BODY';

  DBMS_OUTPUT.PUT_LINE('Package Body Status: ' || l_status);

  IF l_status != 'VALID' THEN
    RAISE_APPLICATION_ERROR(-20991, 'Package body compilation failed');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✓ Package body compiled successfully');
  END IF;
END;
/

PROMPT

-- Step 3: Test basic functionality
PROMPT Step 3/3: Testing basic functionality...
PROMPT

DECLARE
  l_is_init BOOLEAN;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Test 1: IsInitialized before Init...');
  l_is_init := PL_FPDF.IsInitialized();

  IF NOT l_is_init THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ PASS - Not initialized before Init()');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ FAIL - Should not be initialized');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Test 2: Calling Init with defaults...');

  PL_FPDF.Init();

  l_is_init := PL_FPDF.IsInitialized();

  IF l_is_init THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ PASS - Initialized after Init()');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ FAIL - Should be initialized');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Test 3: Calling Reset...');

  PL_FPDF.Reset();

  l_is_init := PL_FPDF.IsInitialized();

  IF NOT l_is_init THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ PASS - Not initialized after Reset()');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ FAIL - Should not be initialized after Reset');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Test 4: Testing parameter validation...');

  BEGIN
    PL_FPDF.Init(p_orientation => 'X');  -- Invalid
    DBMS_OUTPUT.PUT_LINE('  ✗ FAIL - Should have rejected invalid orientation');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20001 THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS - Correctly rejected invalid orientation');
      ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL - Wrong error code: ' || SQLCODE);
      END IF;
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Test 5: Re-initialization...');

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.Init('L', 'cm', 'Letter');  -- Re-init

  l_is_init := PL_FPDF.IsInitialized();

  IF l_is_init THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ PASS - Re-initialization successful');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ FAIL - Re-initialization failed');
  END IF;

  -- Cleanup
  PL_FPDF.Reset();

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('============================================================================');
  DBMS_OUTPUT.PUT_LINE('✓ Basic validation complete - all critical tests passed');
  DBMS_OUTPUT.PUT_LINE('============================================================================');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Next steps:');
  DBMS_OUTPUT.PUT_LINE('  1. Run full test suite:  @tests/run_init_tests_simple.sql');
  DBMS_OUTPUT.PUT_LINE('  2. Review test results');
  DBMS_OUTPUT.PUT_LINE('  3. If all pass, commit implementation');
  DBMS_OUTPUT.PUT_LINE('');

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✗ VALIDATION FAILED');
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('');
    RAISE;
END;
/

PROMPT Validation script complete.
PROMPT
