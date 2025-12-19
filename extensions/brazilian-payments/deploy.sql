--------------------------------------------------------------------------------
-- Brazilian Payments Extension Deployment Script
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-19
--
-- Description: Installs PL_FPDF_PIX and PL_FPDF_BOLETO extension packages
--
-- Prerequisites:
--   - PL_FPDF core package must be installed first
--   - Oracle Database 19c or higher
--   - JSON_OBJECT_T support
--
-- Usage:
--   sqlplus user/pass@db @deploy.sql
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET VERIFY OFF
SET ECHO ON

PROMPT
PROMPT ================================================================================
PROMPT   Brazilian Payments Extension for PL_FPDF - Installation
PROMPT ================================================================================
PROMPT
PROMPT This extension provides Brazilian-specific payment functionality:
PROMPT   - PIX QR Codes (EMV standard)
PROMPT   - Boleto Bancario (FEBRABAN standard)
PROMPT
PROMPT WARNING: This is an OPTIONAL extension and NOT part of official PL_FPDF
PROMPT

-- Check if PL_FPDF core is installed
PROMPT Checking for PL_FPDF core package...
PROMPT

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO l_count
  FROM user_objects
  WHERE object_name = 'PL_FPDF'
    AND object_type = 'PACKAGE BODY'
    AND status = 'VALID';

  IF l_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'PL_FPDF core package not found or invalid. ' ||
      'Please install PL_FPDF core first from the main project.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✓ PL_FPDF core package found and valid');
  END IF;
END;
/

PROMPT
PROMPT ================================================================================
PROMPT   Installing PL_FPDF_PIX Package
PROMPT ================================================================================
PROMPT

PROMPT Installing package specification...
@@packages/PL_FPDF_PIX.pks

SHOW ERRORS PACKAGE PL_FPDF_PIX

PROMPT
PROMPT Installing package body...
@@packages/PL_FPDF_PIX.pkb

SHOW ERRORS PACKAGE BODY PL_FPDF_PIX

PROMPT
PROMPT ================================================================================
PROMPT   Installing PL_FPDF_BOLETO Package
PROMPT ================================================================================
PROMPT

PROMPT Installing package specification...
@@packages/PL_FPDF_BOLETO.pks

SHOW ERRORS PACKAGE PL_FPDF_BOLETO

PROMPT
PROMPT Installing package body...
@@packages/PL_FPDF_BOLETO.pkb

SHOW ERRORS PACKAGE BODY PL_FPDF_BOLETO

PROMPT
PROMPT ================================================================================
PROMPT   Verifying Installation
PROMPT ================================================================================
PROMPT

SELECT object_name,
       object_type,
       status,
       TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS last_compiled
FROM user_objects
WHERE object_name IN ('PL_FPDF_PIX', 'PL_FPDF_BOLETO')
ORDER BY object_name, object_type;

PROMPT
PROMPT ================================================================================
PROMPT   Testing Basic Functionality
PROMPT ================================================================================
PROMPT

DECLARE
  l_pix_payload VARCHAR2(1000);
  l_boleto_linha VARCHAR2(100);
  l_pix_data JSON_OBJECT_T;
  l_boleto_data JSON_OBJECT_T;
BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Testing PL_FPDF_PIX...');

  -- Test PIX
  l_pix_data := JSON_OBJECT_T();
  l_pix_data.put('pixKey', 'test@example.com');
  l_pix_data.put('pixKeyType', 'EMAIL');
  l_pix_data.put('merchantName', 'Test Store');
  l_pix_data.put('merchantCity', 'Sao Paulo');
  l_pix_data.put('amount', 100.00);

  l_pix_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);

  IF l_pix_payload IS NOT NULL AND LENGTH(l_pix_payload) > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ PIX payload generation: OK');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ PIX payload generation: FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Testing PL_FPDF_BOLETO...');

  -- Test Boleto
  l_boleto_data := JSON_OBJECT_T();
  l_boleto_data.put('banco', '001');
  l_boleto_data.put('moeda', '9');
  l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
  l_boleto_data.put('valor', 1000.00);
  l_boleto_data.put('campoLivre', '1234567890123456789012345');

  l_boleto_linha := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data);

  IF l_boleto_linha IS NOT NULL AND LENGTH(l_boleto_linha) = 54 THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ Boleto linha digitavel: OK');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✗ Boleto linha digitavel: FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
END;
/

PROMPT
PROMPT ================================================================================
PROMPT   Installation Complete
PROMPT ================================================================================
PROMPT
PROMPT Brazilian Payments Extension has been installed successfully!
PROMPT
PROMPT Available packages:
PROMPT   - PL_FPDF_PIX: PIX QR Code generation
PROMPT   - PL_FPDF_BOLETO: Boleto Bancario generation
PROMPT
PROMPT Next steps:
PROMPT   1. Review documentation: README.md and README_PT_BR.md
PROMPT   2. Run validation tests: @tests/validate_pix_package.sql
PROMPT   3. Test with your own data
PROMPT
PROMPT For examples and API reference, see:
PROMPT   - extensions/brazilian-payments/README.md
PROMPT
PROMPT ================================================================================
PROMPT

SET ECHO OFF
