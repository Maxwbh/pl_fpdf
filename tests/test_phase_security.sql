/*******************************************************************************
* Test Script: Phase 5 - Security / Password Protection
* Version: 3.2.0
* Author: @maxwbh
*
* Tests for PDF encryption and password protection features using DBMS_CRYPTO.
*
* Requirements:
* - Oracle 19c+ with DBMS_CRYPTO package
* - PL_FPDF package installed
* - EXECUTE privilege on DBMS_CRYPTO
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

DECLARE
  -- Test counters
  v_total_tests PLS_INTEGER := 0;
  v_passed_tests PLS_INTEGER := 0;
  v_failed_tests PLS_INTEGER := 0;

  -- Test variables
  l_pdf BLOB;
  l_encrypted BLOB;
  l_decrypted BLOB;
  l_info JSON_OBJECT_T;
  l_is_encrypted BOOLEAN;
  l_permissions JSON_OBJECT_T;

  -- Test helper procedures
  PROCEDURE test_start(p_name VARCHAR2) IS
  BEGIN
    v_total_tests := v_total_tests + 1;
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Test ' || v_total_tests || ': ' || p_name);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
  END;

  PROCEDURE test_pass(p_msg VARCHAR2 DEFAULT 'PASS') IS
  BEGIN
    v_passed_tests := v_passed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE test_fail(p_msg VARCHAR2) IS
  BEGIN
    v_failed_tests := v_failed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  -- Generate simple test PDF
  FUNCTION generate_test_pdf RETURN BLOB IS
    l_result BLOB;
  BEGIN
    PL_FPDF.fpdf('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 10, 'Security Test Document', '0', 1, 'C');
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'This document is used for testing encryption.', '0', 1, 'L');
    l_result := PL_FPDF.Output();
    PL_FPDF.Reset();
    RETURN l_result;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.2.0 - PHASE 5: Security Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('');

  --------------------------------------------------------------------------------
  -- Generate test PDF
  --------------------------------------------------------------------------------
  l_pdf := generate_test_pdf();
  DBMS_OUTPUT.PUT_LINE('Test PDF generated: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
  DBMS_OUTPUT.PUT_LINE('');

  --------------------------------------------------------------------------------
  -- TEST 1: Check unencrypted PDF
  --------------------------------------------------------------------------------
  test_start('IsEncrypted - Unencrypted PDF');
  BEGIN
    l_is_encrypted := PL_FPDF.IsEncrypted(l_pdf);
    IF NOT l_is_encrypted THEN
      test_pass('Correctly detected unencrypted PDF');
    ELSE
      test_fail('Should report PDF as unencrypted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: GetSecurityInfo - Unencrypted PDF
  --------------------------------------------------------------------------------
  test_start('GetSecurityInfo - Unencrypted PDF');
  BEGIN
    l_info := PL_FPDF.GetSecurityInfo(l_pdf);
    IF NOT l_info.get_boolean('encrypted') THEN
      test_pass('Correctly reports encrypted=false');
    ELSE
      test_fail('Should report encrypted=false');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: EncryptPDF - RC4-128 with user password only
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - RC4-128 with user password');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'test123',
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_encrypted) > 0 THEN
      test_pass('PDF encrypted successfully (' || DBMS_LOB.GETLENGTH(l_encrypted) || ' bytes)');
    ELSE
      test_fail('Encryption returned empty result');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: EncryptPDF - RC4-40 legacy encryption
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - RC4-40 legacy encryption');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'legacy',
      p_encryption => 'RC4-40'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('RC4-40 encryption successful');
    ELSE
      test_fail('RC4-40 encryption failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: EncryptPDF - With owner password
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - User and Owner passwords');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'user123',
      p_owner_password => 'owner456',
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('Encryption with both passwords successful');
    ELSE
      test_fail('Encryption with both passwords failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: EncryptPDF - With permissions
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - With permission restrictions');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', FALSE);
    l_permissions.put('modify', FALSE);
    l_permissions.put('annotate', TRUE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'restricted',
      p_owner_password => 'fullaccess',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('Encryption with permissions successful');
    ELSE
      test_fail('Encryption with permissions failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: EncryptPDF - Invalid encryption method
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - Invalid encryption method (should fail)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'test',
      p_encryption => 'INVALID'
    );
    test_fail('Should have raised error for invalid method');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20850 THEN
        test_pass('Correctly rejected invalid encryption method');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 8: EncryptPDF - NULL password (should fail)
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - NULL password (should fail)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => NULL,
      p_encryption => 'RC4-128'
    );
    test_fail('Should have raised error for NULL password');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20851 THEN
        test_pass('Correctly rejected NULL password');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 9: EncryptPDF - AES-128 (should fail - not implemented)
  --------------------------------------------------------------------------------
  test_start('EncryptPDF - AES-128 (not implemented yet)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'aestest',
      p_encryption => 'AES-128'
    );
    test_fail('Should have raised error for AES');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20852 THEN
        test_pass('Correctly reports AES not implemented');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 10: DecryptPDF - Non-encrypted PDF (should fail)
  --------------------------------------------------------------------------------
  test_start('DecryptPDF - Non-encrypted PDF (should fail)');
  BEGIN
    l_decrypted := PL_FPDF.DecryptPDF(l_pdf, 'password');
    test_fail('Should have raised error for non-encrypted PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20853 THEN
        test_pass('Correctly rejected non-encrypted PDF');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 11: SetEncryption - Valid method
  --------------------------------------------------------------------------------
  test_start('SetEncryption - Valid encryption method');
  BEGIN
    PL_FPDF.SetEncryption('RC4-128', 'user123', 'owner456');
    test_pass('SetEncryption accepted valid method');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 12: SetEncryption - Invalid method (should fail)
  --------------------------------------------------------------------------------
  test_start('SetEncryption - Invalid method (should fail)');
  BEGIN
    PL_FPDF.SetEncryption('INVALID', 'user123');
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20850 THEN
        test_pass('Correctly rejected invalid method');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 13: SetPermissions - Valid permissions
  --------------------------------------------------------------------------------
  test_start('SetPermissions - Valid permissions');
  BEGIN
    PL_FPDF.SetEncryption('RC4-128', 'user', 'owner');
    PL_FPDF.SetPermissions(
      p_print => TRUE,
      p_copy => FALSE,
      p_modify => FALSE,
      p_annotate => TRUE
    );
    test_pass('SetPermissions accepted valid parameters');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 14: SetPermissions - Without SetEncryption (should fail)
  --------------------------------------------------------------------------------
  test_start('SetPermissions - Without SetEncryption (should fail)');
  BEGIN
    -- Reset encryption state
    PL_FPDF.Reset();

    PL_FPDF.SetPermissions(p_print => TRUE);
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20856 THEN
        test_pass('Correctly requires SetEncryption first');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 15: IsEncrypted - NULL PDF
  --------------------------------------------------------------------------------
  test_start('IsEncrypted - NULL PDF');
  BEGIN
    l_is_encrypted := PL_FPDF.IsEncrypted(NULL);
    IF NOT l_is_encrypted THEN
      test_pass('Correctly returns FALSE for NULL');
    ELSE
      test_fail('Should return FALSE for NULL');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- Print Summary
  --------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('TEST SUMMARY');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests:  ' || v_total_tests);
  DBMS_OUTPUT.PUT_LINE('Passed:       ' || v_passed_tests || ' (' ||
    ROUND(v_passed_tests / v_total_tests * 100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:       ' || v_failed_tests);

  IF v_failed_tests = 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('*** ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('*** SOME TESTS FAILED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Cleanup
  IF l_pdf IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_pdf); END IF;
  IF l_encrypted IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_encrypted); END IF;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/
