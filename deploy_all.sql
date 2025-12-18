--------------------------------------------------------------------------------
-- Deploy All Packages Script
-- Project: PL_FPDF Modernization - Phase 3
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
--------------------------------------------------------------------------------
-- This script deploys all packages in the correct order:
-- 1. PL_FPDF_PIX (independent utility package)
-- 2. PL_FPDF_BOLETO (independent utility package)
-- 3. PL_FPDF (main PDF generation package, uses PIX and Boleto)
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET VERIFY OFF
SET ECHO ON

PROMPT
PROMPT ================================================================================
PROMPT   Deploying PL_FPDF Package Suite
PROMPT ================================================================================
PROMPT

PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   Step 1: Deploying PL_FPDF_PIX Package
PROMPT --------------------------------------------------------------------------------
PROMPT

@@PL_FPDF_PIX.pks
SHOW ERRORS PACKAGE PL_FPDF_PIX

@@PL_FPDF_PIX.pkb
SHOW ERRORS PACKAGE BODY PL_FPDF_PIX

PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   Step 2: Deploying PL_FPDF_BOLETO Package
PROMPT --------------------------------------------------------------------------------
PROMPT

@@PL_FPDF_BOLETO.pks
SHOW ERRORS PACKAGE PL_FPDF_BOLETO

@@PL_FPDF_BOLETO.pkb
SHOW ERRORS PACKAGE BODY PL_FPDF_BOLETO

PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   Step 3: Deploying PL_FPDF Main Package
PROMPT --------------------------------------------------------------------------------
PROMPT

@@PL_FPDF.pks
SHOW ERRORS PACKAGE PL_FPDF

@@PL_FPDF.pkb
SHOW ERRORS PACKAGE BODY PL_FPDF

PROMPT
PROMPT ================================================================================
PROMPT   Deployment Summary
PROMPT ================================================================================
PROMPT

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('PL_FPDF', 'PL_FPDF_PIX', 'PL_FPDF_BOLETO')
ORDER BY object_name, object_type;

PROMPT
PROMPT ================================================================================
PROMPT   Deployment Complete
PROMPT ================================================================================
PROMPT
PROMPT Next steps:
PROMPT   - Run validation tests: @validate_task_3_7.sql and @validate_task_3_8.sql
PROMPT   - Test PIX: SELECT PL_FPDF_PIX.GetPixPayload(JSON_OBJECT_T()) FROM DUAL;
PROMPT   - Test Boleto: SELECT PL_FPDF_BOLETO.GetCodigoBarras(JSON_OBJECT_T()) FROM DUAL;
PROMPT
