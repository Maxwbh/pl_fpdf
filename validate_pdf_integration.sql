--------------------------------------------------------------------------------
-- VALIDATION SCRIPT: PDF + PIX + BOLETO Integration
-- Project: PL_FPDF Modernization - Phase 3
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Purpose: Validate integration of all three packages
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT
PROMPT ================================================================================
PROMPT   PDF + PIX + BOLETO Integration Validation
PROMPT ================================================================================
PROMPT   Testing complete workflow with all three packages
PROMPT   - PL_FPDF: Base PDF generation (independent)
PROMPT   - PL_FPDF_PIX: PIX QR Codes (uses PL_FPDF)
PROMPT   - PL_FPDF_BOLETO: Boleto barcodes (uses PL_FPDF)
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
  l_boleto_data JSON_OBJECT_T;
  l_pdf_blob BLOB;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Integration Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------------------------------
  -- Test Group 1: Package Independence
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- Test Group 1: Package Independence ---');

  -- Test 1: PL_FPDF works without PIX/BOLETO
  BEGIN
    start_test('PL_FPDF works independently (no PIX/BOLETO)');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Text(10, 10, 'PDF Test');
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

  -- Test 2: PL_FPDF_PIX functions work without PDF
  BEGIN
    start_test('PL_FPDF_PIX utilities work independently');
    DECLARE
      l_payload VARCHAR2(32767);
      l_is_valid BOOLEAN;
    BEGIN
      l_is_valid := PL_FPDF_PIX.ValidatePixKey('12345678901', 'CPF');

      l_pix_data := JSON_OBJECT_T();
      l_pix_data.put('pixKey', '12345678901');
      l_pix_data.put('pixKeyType', 'CPF');
      l_pix_data.put('merchantName', 'Test');
      l_pix_data.put('merchantCity', 'SP');
      l_payload := PL_FPDF_PIX.GetPixPayload(l_pix_data);

      IF l_is_valid AND l_payload IS NOT NULL THEN
        pass_test;
      ELSE
        fail_test('PIX utilities failed');
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 3: PL_FPDF_BOLETO functions work without PDF
  BEGIN
    start_test('PL_FPDF_BOLETO utilities work independently');
    DECLARE
      l_codigo VARCHAR2(44);
      l_fator VARCHAR2(4);
    BEGIN
      l_fator := PL_FPDF_BOLETO.CalculateFatorVencimento(SYSDATE);

      l_boleto_data := JSON_OBJECT_T();
      l_boleto_data.put('banco', '001');
      l_boleto_data.put('moeda', '9');
      l_boleto_data.put('vencimento', SYSDATE);
      l_boleto_data.put('valor', 1000.00);
      l_boleto_data.put('campoLivre', '1234567890123456789012345');
      l_codigo := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto_data);

      IF l_fator IS NOT NULL AND l_codigo IS NOT NULL THEN
        pass_test;
      ELSE
        fail_test('Boleto utilities failed');
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -------------------------------------------------------------------------
  -- Test Group 2: PIX Integration with PDF
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 2: PIX Integration ---');

  -- Test 4: Generic QR Code in PDF
  BEGIN
    start_test('PL_FPDF.AddQRCode renders generic QR Code');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.AddQRCode(10, 10, 50, 'Test QR Code Data', 'TEXT', 'M');
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

  -- Test 5: PIX QR Code in PDF
  BEGIN
    start_test('PL_FPDF_PIX.AddQRCodePIX integrates with PL_FPDF');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', 'user@example.com');
    l_pix_data.put('pixKeyType', 'EMAIL');
    l_pix_data.put('merchantName', 'My Store');
    l_pix_data.put('merchantCity', 'Sao Paulo');
    l_pix_data.put('amount', 99.90);
    l_pix_data.put('txid', 'ORDER12345');

    PL_FPDF_PIX.AddQRCodePIX(80, 50, 50, l_pix_data);
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

  -- Test 6: Multiple PIX QR Codes in same PDF
  BEGIN
    start_test('Multiple PIX QR Codes in same PDF');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    -- First PIX QR Code
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '12345678901');
    l_pix_data.put('pixKeyType', 'CPF');
    l_pix_data.put('merchantName', 'Store 1');
    l_pix_data.put('merchantCity', 'SP');
    PL_FPDF_PIX.AddQRCodePIX(10, 10, 40, l_pix_data);

    -- Second PIX QR Code
    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', 'store@example.com');
    l_pix_data.put('pixKeyType', 'EMAIL');
    l_pix_data.put('merchantName', 'Store 2');
    l_pix_data.put('merchantCity', 'RJ');
    PL_FPDF_PIX.AddQRCodePIX(10, 60, 40, l_pix_data);

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
  -- Test Group 3: Boleto Integration with PDF
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 3: Boleto Integration ---');

  -- Test 7: Generic Barcode in PDF
  BEGIN
    start_test('PL_FPDF.AddBarcode renders generic barcode');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.AddBarcode(10, 10, 100, 15, '1234567890123', 'CODE128', TRUE);
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

  -- Test 8: Boleto barcode in PDF
  BEGIN
    start_test('PL_FPDF_BOLETO.AddBarcodeBoleto integrates with PL_FPDF');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();

    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '237');  -- Bradesco
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 1500.00);
    l_boleto_data.put('campoLivre', '1234567890123456789012345');

    PL_FPDF_BOLETO.AddBarcodeBoleto(10, 100, 180, 13, l_boleto_data);
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.Text(10, 120, 'Boleto Bancario');

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
  -- Test Group 4: Complete Integration (PIX + Boleto + PDF)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test Group 4: Complete Integration ---');

  -- Test 9: PDF with both PIX and Boleto
  BEGIN
    start_test('PDF with both PIX QR Code and Boleto barcode');
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Text(10, 10, 'Invoice #12345');

    -- Add PIX QR Code
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Text(10, 25, 'Option 1: Pay with PIX');

    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', 'payment@store.com');
    l_pix_data.put('pixKeyType', 'EMAIL');
    l_pix_data.put('merchantName', 'My Store');
    l_pix_data.put('merchantCity', 'Sao Paulo');
    l_pix_data.put('amount', 2500.00);
    l_pix_data.put('txid', 'INV12345');

    PL_FPDF_PIX.AddQRCodePIX(10, 35, 50, l_pix_data);

    -- Add Boleto barcode
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Text(10, 100, 'Option 2: Pay with Boleto');

    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '341');  -- Itau
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
    l_boleto_data.put('valor', 2500.00);
    l_boleto_data.put('campoLivre', '9999999990000000001234567');

    PL_FPDF_BOLETO.AddBarcodeBoleto(10, 110, 180, 13, l_boleto_data);

    -- Add footer
    PL_FPDF.SetFont('Arial', 'I', 8);
    PL_FPDF.Text(10, 280, 'Generated by PL_FPDF + PL_FPDF_PIX + PL_FPDF_BOLETO');

    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 1000 THEN
      pass_test;
    ELSE
      fail_test('PDF too small: ' || DBMS_LOB.GETLENGTH(l_pdf_blob) || ' bytes');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fail_test(SUBSTR(SQLERRM, 1, 200));
  END;

  -- Test 10: Multi-page document with PIX and Boleto
  BEGIN
    start_test('Multi-page PDF with PIX and Boleto on different pages');
    PL_FPDF.Init('P', 'mm', 'A4');

    -- Page 1: PIX
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 14);
    PL_FPDF.Text(10, 10, 'Page 1: PIX Payment');

    l_pix_data := JSON_OBJECT_T();
    l_pix_data.put('pixKey', '11987654321');
    l_pix_data.put('pixKeyType', 'PHONE');
    l_pix_data.put('merchantName', 'Store ABC');
    l_pix_data.put('merchantCity', 'Brasilia');
    l_pix_data.put('amount', 750.50);

    PL_FPDF_PIX.AddQRCodePIX(80, 50, 50, l_pix_data);

    -- Page 2: Boleto
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 14);
    PL_FPDF.Text(10, 10, 'Page 2: Boleto Payment');

    l_boleto_data := JSON_OBJECT_T();
    l_boleto_data.put('banco', '001');  -- Banco do Brasil
    l_boleto_data.put('moeda', '9');
    l_boleto_data.put('vencimento', SYSDATE + 30);
    l_boleto_data.put('valor', 750.50);
    l_boleto_data.put('campoLivre', '0000000012345678901234567');

    PL_FPDF_BOLETO.AddBarcodeBoleto(10, 50, 180, 13, l_boleto_data);

    l_pdf_blob := PL_FPDF.OutputBlob();

    IF DBMS_LOB.GETLENGTH(l_pdf_blob) > 2000 THEN
      pass_test;
    ELSE
      fail_test('PDF too small for 2 pages: ' || DBMS_LOB.GETLENGTH(l_pdf_blob) || ' bytes');
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
    DBMS_OUTPUT.PUT_LINE('STATUS: ✓ ALL INTEGRATION TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('STATUS: ✗ ' || v_tests_failed || ' TEST(S) FAILED');
  END IF;

  DBMS_OUTPUT.PUT_LINE('=======================================================================');
  DBMS_OUTPUT.PUT_LINE('');

  DBMS_OUTPUT.PUT_LINE('ARCHITECTURE SUMMARY:');
  DBMS_OUTPUT.PUT_LINE('  PL_FPDF         - Base PDF generation (independent)');
  DBMS_OUTPUT.PUT_LINE('  PL_FPDF_PIX     - PIX utilities + rendering (uses PL_FPDF)');
  DBMS_OUTPUT.PUT_LINE('  PL_FPDF_BOLETO  - Boleto utilities + rendering (uses PL_FPDF)');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  - PL_FPDF provides: AddQRCode(), AddBarcode()');
  DBMS_OUTPUT.PUT_LINE('  - PL_FPDF_PIX provides: AddQRCodePIX() calls PL_FPDF.AddQRCode()');
  DBMS_OUTPUT.PUT_LINE('  - PL_FPDF_BOLETO provides: AddBarcodeBoleto() calls PL_FPDF.AddBarcode()');
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
