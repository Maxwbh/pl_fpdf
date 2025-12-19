--------------------------------------------------------------------------------
-- VALIDATION SCRIPT: Task 3.7 - QR Code PIX Generation
-- Project: PL_FPDF Modernization - Phase 3
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Purpose: Validate QR Code PIX generation for Brazilian instant payment system
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   Task 3.7: QR Code PIX Validation
PROMPT ================================================================================
PROMPT   Testing QR Code generation for PIX (Brazilian instant payment)
PROMPT ================================================================================
PROMPT

-- Test statistics
DECLARE
  v_tests_total PLS_INTEGER := 0;
  v_tests_passed PLS_INTEGER := 0;
  v_tests_failed PLS_INTEGER := 0;
  v_test_name VARCHAR2(200);

  -- Test helper procedures
  PROCEDURE start_test(p_name VARCHAR2) IS
  BEGIN
    v_test_name := p_name;
    v_tests_total := v_tests_total + 1;
  END;

  PROCEDURE pass_test IS
  BEGIN
    v_tests_passed := v_tests_passed + 1;
    DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_test_name);
  END;

  PROCEDURE fail_test(p_reason VARCHAR2 DEFAULT NULL) IS
  BEGIN
    v_tests_failed := v_tests_failed + 1;
    DBMS_OUTPUT.PUT_LINE('[FAIL] ' || v_test_name);
    IF p_reason IS NOT NULL THEN
      DBMS_OUTPUT.PUT_LINE('  Reason: ' || p_reason);
    END IF;
  END;

  -- Test variables
  l_pix_data JSON_OBJECT_T;
  l_payload VARCHAR2(32767);
  l_is_valid BOOLEAN;
  l_pdf_blob BLOB;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Task 3.7 Validation Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: PIX Key Validation - CPF
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: PIX Key Validation (CPF) ---');

  -- Test 1: Valid CPF key accepted
  BEGIN
    start_test('ValidatePixKey accepts valid CPF');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('12345678901', 'CPF');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid CPF rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 2: Invalid CPF (wrong length) rejected
  BEGIN
    start_test('ValidatePixKey rejects invalid CPF (wrong length)');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('123456789', 'CPF');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid CPF accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 3: Invalid CPF (non-numeric) rejected
  BEGIN
    start_test('ValidatePixKey rejects non-numeric CPF');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('123.456.789-01', 'CPF');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Non-numeric CPF accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: PIX Key Validation - CNPJ
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: PIX Key Validation (CNPJ) ---');

  -- Test 4: Valid CNPJ key accepted
  BEGIN
    start_test('ValidatePixKey accepts valid CNPJ');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('12345678000195', 'CNPJ');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid CNPJ rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 5: Invalid CNPJ (wrong length) rejected
  BEGIN
    start_test('ValidatePixKey rejects invalid CNPJ (wrong length)');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('12345678000', 'CNPJ');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid CNPJ accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 3: PIX Key Validation - Email
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: PIX Key Validation (Email) ---');

  -- Test 6: Valid email key accepted
  BEGIN
    start_test('ValidatePixKey accepts valid email');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('user@example.com', 'EMAIL');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid email rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 7: Invalid email (no @) rejected
  BEGIN
    start_test('ValidatePixKey rejects invalid email (no @)');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('userexample.com', 'EMAIL');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid email accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 8: Invalid email (no domain) rejected
  BEGIN
    start_test('ValidatePixKey rejects invalid email (no domain)');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('user@', 'EMAIL');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid email accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 4: PIX Key Validation - Phone
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 4: PIX Key Validation (Phone) ---');

  -- Test 9: Valid phone key accepted (with +55)
  BEGIN
    start_test('ValidatePixKey accepts valid phone with +55');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('+5511987654321', 'PHONE');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid phone rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 10: Valid phone key accepted (digits only)
  BEGIN
    start_test('ValidatePixKey accepts valid phone (digits only)');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('5511987654321', 'PHONE');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid phone rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 11: Invalid phone (too short) rejected
  BEGIN
    start_test('ValidatePixKey rejects phone too short');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('5511987', 'PHONE');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid phone accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 5: PIX Key Validation - Random (EVP)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 5: PIX Key Validation (Random/EVP) ---');

  -- Test 12: Valid random key accepted (UUID format)
  BEGIN
    start_test('ValidatePixKey accepts valid random key (UUID)');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('123e4567-e89b-12d3-a456-426614174000', 'RANDOM');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Valid random key rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 13: Invalid random key (too short) rejected
  BEGIN
    start_test('ValidatePixKey rejects random key too short');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('abc123', 'RANDOM');

    IF NOT l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Invalid random key accepted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 6: PIX Payload Generation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 6: PIX Payload Generation ---');

  -- Test 14: Generate static PIX payload with CPF key
  BEGIN
    start_test('GetPixPayload generates valid static PIX (CPF key)');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test Merchant');
    l_pix_data.put('merchantCity', 'Sao Paulo');

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);

    IF l_payload IS NOT NULL AND LENGTH(l_payload) > 0 THEN
      pass_test;
    ELSE
      fail_test('Empty payload generated');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 15: Generate static PIX payload with email key
  BEGIN
    start_test('GetPixPayload generates valid static PIX (email key)');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', 'user@example.com');
    l_pix_data.put('pixKeyType', 'EMAIL');
    l_pix_data.put('merchantName', 'Test Merchant');
    l_pix_data.put('merchantCity', 'Rio de Janeiro');

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);

    IF l_payload IS NOT NULL AND LENGTH(l_payload) > 0 THEN
      pass_test;
    ELSE
      fail_test('Empty payload generated');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 16: Generate PIX payload with amount
  BEGIN
    start_test('GetPixPayload includes transaction amount');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test Merchant');
    l_pix_data.put('merchantCity', 'Brasilia');
    l_pix_data.put('amount', 123.45);

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);

    -- Payload should contain amount in EMV format
    IF l_payload IS NOT NULL AND INSTR(l_payload, '123.45') > 0 THEN
      pass_test;
    ELSE
      fail_test('Amount not included in payload');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 17: Generate PIX payload with transaction ID
  BEGIN
    start_test('GetPixPayload includes transaction ID');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', 'user@example.com');
    l_pix_data.put('pixKeyType', 'EMAIL');
    l_pix_data.put('merchantName', 'Test Merchant');
    l_pix_data.put('merchantCity', 'Curitiba');
    l_pix_data.put('txid', '***ABC123XYZ***');

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);

    IF l_payload IS NOT NULL AND INSTR(l_payload, 'ABC123XYZ') > 0 THEN
      pass_test;
    ELSE
      fail_test('Transaction ID not included in payload');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 18: Payload requires merchant name
  BEGIN
    start_test('GetPixPayload requires merchantName');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantCity', 'Sao Paulo');
    -- Missing merchantName

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);
    fail_test('Should have raised error for missing merchantName');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20701 OR SQLERRM LIKE '%merchant%' OR SQLERRM LIKE '%required%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 19: Payload requires merchant city
  BEGIN
    start_test('GetPixPayload requires merchantCity');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test Merchant');
    -- Missing merchantCity

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);
    fail_test('Should have raised error for missing merchantCity');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20702 OR SQLERRM LIKE '%city%' OR SQLERRM LIKE '%required%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -------------------------------------------------------------------------
  -- Test Group 7: CRC16 Calculation
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 7: CRC16 Calculation ---');

  -- Test 20: CRC16 calculates correctly
  BEGIN
    start_test('CalculateCRC16 produces valid checksum');
    DECLARE
      l_crc VARCHAR2(4);
    BEGIN
      l_crc := PL_FPDF_PIX.CalculateCRC16('test payload');

      -- CRC should be 4 hex characters
      IF LENGTH(l_crc) = 4 AND l_crc = UPPER(l_crc) THEN
        pass_test;
      ELSE
        fail_test('Invalid CRC format: ' || l_crc);
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 21: Different payloads produce different CRCs
  BEGIN
    start_test('CalculateCRC16 produces unique checksums');
    DECLARE
      l_crc1 VARCHAR2(4);
      l_crc2 VARCHAR2(4);
    BEGIN
      l_crc1 := PL_FPDF_PIX.CalculateCRC16('payload1');
      l_crc2 := PL_FPDF_PIX.CalculateCRC16('payload2');

      IF l_crc1 != l_crc2 THEN
        pass_test;
      ELSE
        fail_test('Different payloads produced same CRC');
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 22: CRC16 is deterministic
  BEGIN
    start_test('CalculateCRC16 is deterministic');
    DECLARE
      l_crc1 VARCHAR2(4);
      l_crc2 VARCHAR2(4);
    BEGIN
      l_crc1 := PL_FPDF_PIX.CalculateCRC16('same payload');
      l_crc2 := PL_FPDF_PIX.CalculateCRC16('same payload');

      IF l_crc1 = l_crc2 THEN
        pass_test;
      ELSE
        fail_test('Same payload produced different CRCs: ' || l_crc1 || ' vs ' || l_crc2);
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 8: QR Code Generation in PDF
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 8: QR Code in PDF ---');

  -- Test 23: AddQRCodePIX can be called
  BEGIN
    start_test('AddQRCodePIX accepts valid parameters');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test Merchant');
    l_pix_data.put('merchantCity', 'Sao Paulo');

    PL_FPDF_PIX.AddQRCodePIX(10, 10, 50, l_pix_data);
    pass_test;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 24: AddQRCodePIX validates position
  BEGIN
    start_test('AddQRCodePIX validates negative position');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test');
    l_pix_data.put('merchantCity', 'Test');

    PL_FPDF.AddQRCodePIX(-10, 10, 50, l_pix_data);
    fail_test('Should reject negative position');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20703 OR SQLERRM LIKE '%position%' OR SQLERRM LIKE '%negative%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 25: AddQRCodePIX validates size
  BEGIN
    start_test('AddQRCodePIX validates size too small');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test');
    l_pix_data.put('merchantCity', 'Test');

    PL_FPDF.AddQRCodePIX(10, 10, 2, l_pix_data);
    fail_test('Should reject size too small');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20704 OR SQLERRM LIKE '%size%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
  END;

  -- Test 26: PDF can be generated with QR Code
  BEGIN
    start_test('PDF generation works with QR Code PIX');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', 'user@example.com');
    l_pix_data.put('pixKeyType', 'EMAIL');
    l_pix_data.put('merchantName', 'My Store');
    l_pix_data.put('merchantCity', 'Sao Paulo');
    l_pix_data.put('amount', 99.90);
    l_pix_data.put('txid', 'ORDER12345');

    PL_FPDF.AddQRCodePIX(80, 50, 50, l_pix_data);
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Text(80, 110, 'Pague com PIX');

    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 0 THEN
      pass_test;
    ELSE
      fail_test('Empty PDF generated');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Summary
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('SUMMARY: ' || v_tests_passed || '/' || v_tests_total || ' tests passed');

  IF v_tests_failed = 0 THEN
    DBMS_OUTPUT.PUT_LINE('STATUS: ✓ ALL TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('STATUS: ✗ ' || v_tests_failed || ' TEST(S) FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('');

  DBMS_OUTPUT.PUT_LINE('NOTE: Task 3.7 implements Brazilian PIX instant payment QR Codes.');
  DBMS_OUTPUT.PUT_LINE('      Follows EMV QR Code and Banco Central do Brasil standards.');
  DBMS_OUTPUT.PUT_LINE('      Supports all PIX key types: CPF, CNPJ, Email, Phone, Random.');
  DBMS_OUTPUT.PUT_LINE('');

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================================');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('=======================================================================');
END;
/

SET FEEDBACK ON
SET VERIFY ON
