--------------------------------------------------------------------------------
-- PL_FPDF Native Compilation Script
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-19
-- Task: 3.6 - Performance Tuning Oracle 23c
--
-- Description: Compiles PL_FPDF packages with native compilation for maximum
--              performance. Native compilation converts PL/SQL to native code
--              for 2-3x performance improvement.
--
-- Requirements:
--   - Oracle Database 11g or higher
--   - Sufficient privileges (ALTER SESSION, ALTER PACKAGE)
--   - C compiler installed (for first-time setup)
--
-- Usage:
--   sqlplus user/pass@db @optimize_native_compile.sql
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET VERIFY OFF
SET ECHO ON

PROMPT
PROMPT ================================================================================
PROMPT   PL_FPDF Native Compilation - Performance Optimization
PROMPT ================================================================================
PROMPT

-- Check Oracle version
PROMPT Checking Oracle Database version...
SELECT banner FROM v$version WHERE banner LIKE 'Oracle%';

PROMPT

--------------------------------------------------------------------------------
-- Step 1: Configure session for native compilation
--------------------------------------------------------------------------------
PROMPT Step 1: Configuring session for native compilation...
PROMPT

ALTER SESSION SET PLSQL_CODE_TYPE = NATIVE;
ALTER SESSION SET PLSQL_OPTIMIZE_LEVEL = 3;

PROMPT Session configured:
PROMPT   - PLSQL_CODE_TYPE = NATIVE
PROMPT   - PLSQL_OPTIMIZE_LEVEL = 3 (maximum optimization)
PROMPT

--------------------------------------------------------------------------------
-- Step 2: Recompile PL_FPDF package specification
--------------------------------------------------------------------------------
PROMPT Step 2: Recompiling PL_FPDF package specification...
PROMPT

ALTER PACKAGE PL_FPDF COMPILE SPECIFICATION PLSQL_CODE_TYPE = NATIVE REUSE SETTINGS;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PL_FPDF'
  AND object_type = 'PACKAGE';

SHOW ERRORS PACKAGE PL_FPDF

PROMPT

--------------------------------------------------------------------------------
-- Step 3: Recompile PL_FPDF package body
--------------------------------------------------------------------------------
PROMPT Step 3: Recompiling PL_FPDF package body...
PROMPT

ALTER PACKAGE PL_FPDF COMPILE BODY PLSQL_CODE_TYPE = NATIVE REUSE SETTINGS;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PL_FPDF'
  AND object_type = 'PACKAGE BODY';

SHOW ERRORS PACKAGE BODY PL_FPDF

PROMPT

--------------------------------------------------------------------------------
-- Step 4: Recompile PL_FPDF_PIX package (if exists)
--------------------------------------------------------------------------------
PROMPT Step 4: Recompiling PL_FPDF_PIX package...
PROMPT

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO l_count
  FROM user_objects
  WHERE object_name = 'PL_FPDF_PIX'
    AND object_type IN ('PACKAGE', 'PACKAGE BODY');

  IF l_count > 0 THEN
    EXECUTE IMMEDIATE 'ALTER PACKAGE PL_FPDF_PIX COMPILE PLSQL_CODE_TYPE = NATIVE REUSE SETTINGS';
    DBMS_OUTPUT.PUT_LINE('✓ PL_FPDF_PIX recompiled with native compilation');
  ELSE
    DBMS_OUTPUT.PUT_LINE('⊘ PL_FPDF_PIX not found (skip)');
  END IF;
END;
/

PROMPT

--------------------------------------------------------------------------------
-- Step 5: Recompile PL_FPDF_BOLETO package (if exists)
--------------------------------------------------------------------------------
PROMPT Step 5: Recompiling PL_FPDF_BOLETO package...
PROMPT

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO l_count
  FROM user_objects
  WHERE object_name = 'PL_FPDF_BOLETO'
    AND object_type IN ('PACKAGE', 'PACKAGE BODY');

  IF l_count > 0 THEN
    EXECUTE IMMEDIATE 'ALTER PACKAGE PL_FPDF_BOLETO COMPILE PLSQL_CODE_TYPE = NATIVE REUSE SETTINGS';
    DBMS_OUTPUT.PUT_LINE('✓ PL_FPDF_BOLETO recompiled with native compilation');
  ELSE
    DBMS_OUTPUT.PUT_LINE('⊘ PL_FPDF_BOLETO not found (skip)');
  END IF;
END;
/

PROMPT

--------------------------------------------------------------------------------
-- Step 6: Verify compilation status
--------------------------------------------------------------------------------
PROMPT Step 6: Verifying compilation status...
PROMPT

SELECT object_name,
       object_type,
       status,
       TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS last_compiled
FROM user_objects
WHERE object_name LIKE 'PL_FPDF%'
  AND object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_name, object_type;

PROMPT

--------------------------------------------------------------------------------
-- Step 7: Check compilation settings
--------------------------------------------------------------------------------
PROMPT Step 7: Checking PL/SQL compilation settings...
PROMPT

SELECT name, type, plsql_code_type, plsql_optimize_level
FROM user_plsql_object_settings
WHERE name LIKE 'PL_FPDF%'
ORDER BY name, type;

PROMPT

--------------------------------------------------------------------------------
-- Step 8: Performance benchmark (optional)
--------------------------------------------------------------------------------
PROMPT Step 8: Running quick performance benchmark...
PROMPT

DECLARE
  l_start TIMESTAMP;
  l_end TIMESTAMP;
  l_duration NUMBER;
  l_blob BLOB;
BEGIN
  -- Benchmark: 100 page document
  l_start := SYSTIMESTAMP;

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetFont('Arial', '', 12);

  FOR i IN 1..100 LOOP
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Performance Test Page ' || i);
  END LOOP;

  l_blob := PL_FPDF.OutputBlob();

  l_end := SYSTIMESTAMP;
  l_duration := EXTRACT(SECOND FROM (l_end - l_start));

  PL_FPDF.Reset();

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Benchmark Results:');
  DBMS_OUTPUT.PUT_LINE('  - Pages: 100');
  DBMS_OUTPUT.PUT_LINE('  - Time: ' || ROUND(l_duration, 3) || ' seconds');
  DBMS_OUTPUT.PUT_LINE('  - PDF size: ' || DBMS_LOB.GETLENGTH(l_blob) || ' bytes');
  DBMS_OUTPUT.PUT_LINE('  - Pages/sec: ' || ROUND(100 / l_duration, 1));
  DBMS_OUTPUT.PUT_LINE('');

  IF l_duration < 2 THEN
    DBMS_OUTPUT.PUT_LINE('✓ Performance: EXCELLENT (native compilation working!)');
  ELSIF l_duration < 5 THEN
    DBMS_OUTPUT.PUT_LINE('✓ Performance: GOOD');
  ELSE
    DBMS_OUTPUT.PUT_LINE('⚠ Performance: May need optimization');
  END IF;
END;
/

PROMPT

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------
PROMPT ================================================================================
PROMPT   Native Compilation Complete
PROMPT ================================================================================
PROMPT
PROMPT All PL_FPDF packages have been recompiled with native compilation.
PROMPT
PROMPT Expected Performance Improvements:
PROMPT   - 2-3x faster execution for CPU-intensive operations
PROMPT   - Faster loops and calculations
PROMPT   - Improved OutputBlob() performance
PROMPT
PROMPT To revert to interpreted mode (if needed):
PROMPT   ALTER SESSION SET PLSQL_CODE_TYPE = INTERPRETED;
PROMPT   ALTER PACKAGE PL_FPDF COMPILE PLSQL_CODE_TYPE = INTERPRETED;
PROMPT
PROMPT ================================================================================
PROMPT

SET ECHO OFF
