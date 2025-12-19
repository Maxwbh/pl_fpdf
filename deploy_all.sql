--------------------------------------------------------------------------------
-- PL_FPDF Core Package Deployment Script
-- Project: PL_FPDF v2.0
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-19
--------------------------------------------------------------------------------
-- This script deploys the core PL_FPDF package for PDF generation
--
-- For optional extensions (Brazilian PIX/Boleto), see:
--   extensions/brazilian-payments/deploy.sql
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET VERIFY OFF
SET ECHO ON

PROMPT
PROMPT ================================================================================
PROMPT   Deploying PL_FPDF Core Package
PROMPT ================================================================================
PROMPT
PROMPT   PL_FPDF v2.0 - Modern PDF generation library for Oracle Database
PROMPT
PROMPT   Features:
PROMPT     - Multi-page PDF documents
PROMPT     - Text rendering with multiple fonts
PROMPT     - TrueType/OpenType font support
PROMPT     - UTF-8 encoding
PROMPT     - Image embedding (PNG, JPEG)
PROMPT     - Graphics primitives
PROMPT     - Native compilation support
PROMPT
PROMPT ================================================================================
PROMPT


PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   Installing PL_FPDF Package
PROMPT --------------------------------------------------------------------------------
PROMPT

PROMPT Installing package specification...
@@PL_FPDF.pks
SHOW ERRORS PACKAGE PL_FPDF

PROMPT
PROMPT Installing package body...
@@PL_FPDF.pkb
SHOW ERRORS PACKAGE BODY PL_FPDF

PROMPT
PROMPT ================================================================================
PROMPT   Verifying Installation
PROMPT ================================================================================
PROMPT

SELECT object_name, object_type, status,
       TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS last_compiled
FROM user_objects
WHERE object_name = 'PL_FPDF'
ORDER BY object_type;

PROMPT
PROMPT ================================================================================
PROMPT   Testing Basic Functionality
PROMPT ================================================================================
PROMPT

DECLARE
  l_pdf BLOB;
BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Running basic functionality test...');

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'PL_FPDF Installation Test');
  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  IF DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ PDF generation: OK (' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ PDF generation: FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
END;
/

PROMPT
PROMPT ================================================================================
PROMPT   Deployment Complete
PROMPT ================================================================================
PROMPT
PROMPT PL_FPDF core package has been installed successfully!
PROMPT
PROMPT Next steps:
PROMPT   1. Review documentation: README.md
PROMPT   2. Run unit tests: @tests/run_all_tests.sql
PROMPT   3. Optimize performance: @optimize_native_compile.sql
PROMPT
PROMPT Optional extensions:
PROMPT   - Brazilian PIX/Boleto: @extensions/brazilian-payments/deploy.sql
PROMPT
PROMPT ================================================================================
PROMPT

SET ECHO OFF
