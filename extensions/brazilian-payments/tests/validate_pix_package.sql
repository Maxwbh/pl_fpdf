--------------------------------------------------------------------------------
-- VALIDATION SCRIPT: PL_FPDF_PIX Package
-- Project: PL_FPDF Modernization - Phase 3
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Purpose: Validate standalone PIX utility package
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   PL_FPDF_PIX Package Validation
PROMPT ================================================================================
PROMPT   Testing PIX utility functions independently
PROMPT   Package: PL_FPDF_PIX (PIX validation, CRC16, payload generation)
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
  l_crc VARCHAR2(4);
  l_formatted_key VARCHAR2(100);

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== PL_FPDF_PIX Package Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: ValidatePixKey - CPF
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: ValidatePixKey (CPF) ---');

  -- Test 1: Valid CPF key accepted
  BEGIN
    start_test('ValidatePixKey accepts valid CPF (numeric only)');
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

  -- Test 3: CPF with formatting (should be cleaned)
  BEGIN
    start_test('ValidatePixKey handles CPF with dots/dashes');
    l_is_valid := PL_FPDF_PIX.ValidatePixKey('123.456.789-01', 'CPF');

    IF l_is_valid THEN
      pass_test;
    ELSE
      fail_test('Formatted CPF rejected');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: ValidatePixKey - CNPJ
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: ValidatePixKey (CNPJ) ---');

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
  -- Test Group 3: ValidatePixKey - Email
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: ValidatePixKey (Email) ---');

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

  -------------------------------------------------------------------------
  -- Test Group 4: ValidatePixKey - Phone
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 4: ValidatePixKey (Phone) ---');

  -- Test 8: Valid phone key accepted (with +55)
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

  -- Test 9: Valid phone key accepted (digits only)
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

  -------------------------------------------------------------------------
  -- Test Group 5: ValidatePixKey - Random (EVP)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 5: ValidatePixKey (Random/EVP) ---');

  -- Test 10: Valid random key accepted (UUID format)
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

  -- Test 11: Invalid random key (too short) rejected
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
  -- Test Group 6: FormatPixKey
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 6: FormatPixKey ---');

  -- Test 12: Format CPF with mask
  BEGIN
    start_test('FormatPixKey formats CPF with mask');
    l_formatted_key := PL_FPDF_PIX.FormatPixKey('12345678901', 'CPF');

    IF l_formatted_key = '123.456.789-01' THEN
      pass_test;
    ELSE
      fail_test('Wrong format: ' || l_formatted_key || ' (expected 123.456.789-01)');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 13: Format CNPJ with mask
  BEGIN
    start_test('FormatPixKey formats CNPJ with mask');
    l_formatted_key := PL_FPDF_PIX.FormatPixKey('12345678000195', 'CNPJ');

    IF l_formatted_key = '12.345.678/0001-95' THEN
      pass_test;
    ELSE
      fail_test('Wrong format: ' || l_formatted_key || ' (expected 12.345.678/0001-95)');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 14: Format phone with mask
  BEGIN
    start_test('FormatPixKey formats phone with mask');
    l_formatted_key := PL_FPDF_PIX.FormatPixKey('5511987654321', 'PHONE');

    IF l_formatted_key = '+55 (11) 98765-4321' THEN
      pass_test;
    ELSE
      fail_test('Wrong format: ' || l_formatted_key);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 7: CalculateCRC16
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 7: CalculateCRC16 ---');

  -- Test 15: CRC16 calculates correctly
  BEGIN
    start_test('CalculateCRC16 produces valid checksum');
    l_crc := PL_FPDF_PIX.CalculateCRC16('test payload');

    -- CRC should be 4 hex characters
    IF LENGTH(l_crc) = 4 AND l_crc = UPPER(l_crc) THEN
      pass_test;
    ELSE
      fail_test('Invalid CRC format: ' || l_crc);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 16: Different payloads produce different CRCs
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

  -- Test 17: CRC16 is deterministic
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
  -- Test Group 8: GetPixPayload
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 8: GetPixPayload ---');

  -- Test 18: Generate static PIX payload with CPF key
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

  -- Test 19: Generate PIX payload with email key
  BEGIN
    start_test('GetPixPayload generates valid PIX (email key)');
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

  -- Test 20: Payload includes amount when provided
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

  -- Test 21: Payload includes transaction ID when provided
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

  -- Test 22: Payload requires merchantName
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

  -- Test 23: Payload requires merchantCity
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

  -- Test 24: Payload validates PIX key
  BEGIN
    start_test('GetPixPayload validates invalid PIX key');
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '123');  -- Invalid CPF (too short)
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Test');
    l_pix_data.put('merchantCity', 'Test');

    l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);
    fail_test('Should have raised error for invalid PIX key');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20701 OR SQLERRM LIKE '%Invalid PIX key%' THEN
        pass_test;
      ELSE
        fail_test('Wrong error: ' || SUBSTR(SQLERRM, 1, 200));
      END IF;
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

  DBMS_OUTPUT.PUT_LINE('NOTE: PL_FPDF_PIX is a standalone package for PIX utilities.');
  DBMS_OUTPUT.PUT_LINE('      Can be used independently of PL_FPDF for PIX operations.');
  DBMS_OUTPUT.PUT_LINE('      Implements EMV QR Code and Banco Central do Brasil standards.');
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
