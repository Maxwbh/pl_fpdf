/*******************************************************************************
* Script: run_init_tests_simple.sql
* Description: Simple test runner for PL_FPDF initialization tests
*              Does not require utPLSQL - uses basic PL/SQL
*
* Usage:
*   SQL> @run_init_tests_simple.sql
*   or
*   SQL> sqlplus user/pass@db @run_init_tests_simple.sql
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 1000;
SET FEEDBACK OFF;
SET VERIFY OFF;

PROMPT
PROMPT ============================================================================
PROMPT PL_FPDF Initialization Tests - Simple Runner
PROMPT ============================================================================
PROMPT

DECLARE
  -- Test counters
  l_total_tests NUMBER := 0;
  l_passed_tests NUMBER := 0;
  l_failed_tests NUMBER := 0;
  l_test_name VARCHAR2(200);

  -- Procedure to run a test
  PROCEDURE run_test(
    p_test_name VARCHAR2,
    p_test_proc VARCHAR2
  ) IS
    l_result BOOLEAN := FALSE;
  BEGIN
    l_total_tests := l_total_tests + 1;
    l_test_name := p_test_name;

    BEGIN
      -- Execute test dynamically
      EXECUTE IMMEDIATE 'BEGIN ' || p_test_proc || '; END;';
      l_result := TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        l_result := FALSE;
        DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_test_name);
        DBMS_OUTPUT.PUT_LINE('         Error: ' || SQLERRM);
    END;

    IF l_result THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_test_name);
    ELSE
      l_failed_tests := l_failed_tests + 1;
    END IF;

  END run_test;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Test Suite: PL_FPDF Initialization');
  DBMS_OUTPUT.PUT_LINE('Oracle Version: ' || (SELECT version FROM v$instance));
  DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Running tests...');
  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- TEST 1: Basic Initialization
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('Group 1: Basic Initialization');

  -- Test 1.1: Init with defaults
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init();

    IF PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Init with default parameters');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with default parameters - not initialized');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with default parameters - ' || SQLERRM);
  END;

  -- Test 1.2: Init Portrait
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init(p_orientation => 'P');

    IF PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Init with Portrait orientation');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with Portrait orientation');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with Portrait orientation - ' || SQLERRM);
  END;

  -- Test 1.3: Init Landscape
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init(p_orientation => 'L');

    IF PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Init with Landscape orientation');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with Landscape orientation');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with Landscape orientation - ' || SQLERRM);
  END;

  -- Test 1.4: UTF-8 Encoding
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init(p_encoding => 'UTF-8');

    IF PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Init with UTF-8 encoding');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with UTF-8 encoding');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with UTF-8 encoding - ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- TEST 2: Parameter Validation (Negative Tests)
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('Group 2: Parameter Validation');

  -- Test 2.1: Invalid orientation
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init(p_orientation => 'X');

    -- Should not reach here
    l_failed_tests := l_failed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] Invalid orientation - should have raised exception');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20001 THEN
        l_passed_tests := l_passed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('  [PASS] Invalid orientation rejected correctly');
      ELSE
        l_failed_tests := l_failed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('  [FAIL] Invalid orientation - wrong error: ' || SQLERRM);
      END IF;
  END;

  -- Test 2.2: Invalid unit
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init(p_unit => 'meters');

    -- Should not reach here
    l_failed_tests := l_failed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] Invalid unit - should have raised exception');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20002 THEN
        l_passed_tests := l_passed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('  [PASS] Invalid unit rejected correctly');
      ELSE
        l_failed_tests := l_failed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('  [FAIL] Invalid unit - wrong error: ' || SQLERRM);
      END IF;
  END;

  -- Test 2.3: Invalid encoding
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init(p_encoding => 'EBCDIC');

    -- Should not reach here
    l_failed_tests := l_failed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] Invalid encoding - should have raised exception');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20003 THEN
        l_passed_tests := l_passed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('  [PASS] Invalid encoding rejected correctly');
      ELSE
        l_failed_tests := l_failed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('  [FAIL] Invalid encoding - wrong error: ' || SQLERRM);
      END IF;
  END;

  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- TEST 3: State Management
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('Group 3: State Management');

  -- Test 3.1: Not initialized initially
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();

    IF NOT PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Not initialized before Init()');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Should not be initialized before Init()');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Not initialized initially - ' || SQLERRM);
  END;

  -- Test 3.2: Initialized after Init
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init();

    IF PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Initialized after Init()');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Should be initialized after Init()');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Initialized after Init - ' || SQLERRM);
  END;

  -- Test 3.3: Not initialized after Reset
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Init();
    PL_FPDF.Reset();

    IF NOT PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Not initialized after Reset()');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Should not be initialized after Reset()');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Not initialized after Reset - ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- TEST 4: Re-initialization
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('Group 4: Re-initialization');

  -- Test 4.1: Re-init allowed
  BEGIN
    l_total_tests := l_total_tests + 1;

    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.Init('L', 'cm', 'Letter');

    IF PL_FPDF.IsInitialized() THEN
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] Re-initialization allowed');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Re-initialization failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Re-initialization - ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- TEST 5: Multiple Units
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('Group 5: Different Units');

  -- Test all units
  DECLARE
    TYPE t_units IS TABLE OF VARCHAR2(10);
    l_units t_units := t_units('mm', 'cm', 'in', 'pt');
  BEGIN
    FOR i IN 1..l_units.COUNT LOOP
      BEGIN
        l_total_tests := l_total_tests + 1;

        PL_FPDF.Reset();
        PL_FPDF.Init(p_unit => l_units(i));

        IF PL_FPDF.IsInitialized() THEN
          l_passed_tests := l_passed_tests + 1;
          DBMS_OUTPUT.PUT_LINE('  [PASS] Init with unit: ' || l_units(i));
        ELSE
          l_failed_tests := l_failed_tests + 1;
          DBMS_OUTPUT.PUT_LINE('  [FAIL] Init with unit: ' || l_units(i));
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_failed_tests := l_failed_tests + 1;
          DBMS_OUTPUT.PUT_LINE('  [FAIL] Unit ' || l_units(i) || ' - ' || SQLERRM);
      END;
    END LOOP;
  END;

  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- TEST 6: Performance Test
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('Group 6: Performance');

  -- Test 6.1: Rapid cycles
  DECLARE
    l_start_time TIMESTAMP;
    l_end_time TIMESTAMP;
    l_duration_ms NUMBER;
  BEGIN
    l_total_tests := l_total_tests + 1;
    l_start_time := SYSTIMESTAMP;

    FOR i IN 1..50 LOOP
      PL_FPDF.Init();
      PL_FPDF.Reset();
    END LOOP;

    l_end_time := SYSTIMESTAMP;
    l_duration_ms := EXTRACT(SECOND FROM (l_end_time - l_start_time)) * 1000;

    IF l_duration_ms < 5000 THEN -- Less than 5 seconds for 50 cycles
      l_passed_tests := l_passed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] 50 init-reset cycles: ' || ROUND(l_duration_ms) || 'ms');
    ELSE
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] 50 cycles too slow: ' || ROUND(l_duration_ms) || 'ms');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_failed_tests := l_failed_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] Performance test - ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');

  -- =========================================================================
  -- SUMMARY
  -- =========================================================================
  DBMS_OUTPUT.PUT_LINE('============================================================================');
  DBMS_OUTPUT.PUT_LINE('Test Summary:');
  DBMS_OUTPUT.PUT_LINE('  Total tests:  ' || l_total_tests);
  DBMS_OUTPUT.PUT_LINE('  Passed:       ' || l_passed_tests || ' (' ||
    ROUND(l_passed_tests * 100 / l_total_tests, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('  Failed:       ' || l_failed_tests || ' (' ||
    ROUND(l_failed_tests * 100 / l_total_tests, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('============================================================================');

  IF l_failed_tests = 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✓ ALL TESTS PASSED!');
  ELSE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✗ SOME TESTS FAILED - Review output above');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');

  -- Cleanup
  PL_FPDF.Reset();

END;
/

SET FEEDBACK ON;
SET VERIFY ON;

PROMPT
PROMPT Test execution complete.
PROMPT
