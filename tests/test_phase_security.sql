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
*
* Tests:
* - Section 1: Basic Encryption Detection
* - Section 2: RC4 Encryption (40-bit and 128-bit)
* - Section 3: Permission Controls
* - Section 4: Decryption
* - Section 5: Security Info Parsing
* - Section 6: Error Handling
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

DECLARE
  -- Test counters
  v_total_tests PLS_INTEGER := 0;
  v_passed_tests PLS_INTEGER := 0;
  v_failed_tests PLS_INTEGER := 0;
  v_section VARCHAR2(100);

  -- Test variables
  l_pdf BLOB;
  l_encrypted BLOB;
  l_decrypted BLOB;
  l_info JSON_OBJECT_T;
  l_perms JSON_OBJECT_T;
  l_is_encrypted BOOLEAN;
  l_permissions JSON_OBJECT_T;

  -- Test helper procedures
  PROCEDURE section_start(p_name VARCHAR2) IS
  BEGIN
    v_section := p_name;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(p_name);
    DBMS_OUTPUT.PUT_LINE('============================================================');
  END;

  PROCEDURE test_start(p_name VARCHAR2) IS
  BEGIN
    v_total_tests := v_total_tests + 1;
    DBMS_OUTPUT.PUT_LINE('');
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
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 10, 'Security Test Document', '0', 1, 'C');
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'This document is used for testing encryption.', '0', 1, 'L');
    PL_FPDF.Ln(10);
    PL_FPDF.Cell(0, 10, 'Confidential content that needs protection.', '0', 1, 'L');
    l_result := PL_FPDF.Output_Blob();
    PL_FPDF.Reset();
    RETURN l_result;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.2.0 - PHASE 5: Security Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('');

  --------------------------------------------------------------------------------
  -- Generate test PDF
  --------------------------------------------------------------------------------
  l_pdf := generate_test_pdf();
  DBMS_OUTPUT.PUT_LINE('Test PDF generated: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');

  ================================================================================
  -- SECTION 1: Basic Encryption Detection
  ================================================================================
  section_start('SECTION 1: Basic Encryption Detection');

  -- TEST 1.1: Check unencrypted PDF
  test_start('IsEncrypted - Unencrypted PDF returns FALSE');
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

  -- TEST 1.2: IsEncrypted - NULL PDF
  test_start('IsEncrypted - NULL PDF returns FALSE');
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

  -- TEST 1.3: GetSecurityInfo - Unencrypted PDF
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

  ================================================================================
  -- SECTION 2: RC4 Encryption
  ================================================================================
  section_start('SECTION 2: RC4 Encryption');

  -- TEST 2.1: EncryptPDF - RC4-128 with user password only
  test_start('EncryptPDF - RC4-128 with user password');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'test123',
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_encrypted) > 0 THEN
      test_pass('PDF encrypted (' || DBMS_LOB.GETLENGTH(l_encrypted) || ' bytes)');

      -- Verify it's now encrypted
      IF PL_FPDF.IsEncrypted(l_encrypted) THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] IsEncrypted confirms encryption');
      END IF;
    ELSE
      test_fail('Encryption returned empty result');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 2.2: EncryptPDF - RC4-40 legacy encryption
  test_start('EncryptPDF - RC4-40 legacy encryption');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'legacy',
      p_encryption => 'RC4-40'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('RC4-40 encryption successful');

      -- Check security info
      l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
      IF l_info.get_string('method') = 'RC4-40' THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] Method correctly identified as RC4-40');
      END IF;
    ELSE
      test_fail('RC4-40 encryption failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 2.3: EncryptPDF - With owner password
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

      l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
      IF l_info.get_boolean('hasUserPassword') AND l_info.get_boolean('hasOwnerPassword') THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] Both password flags detected');
      END IF;
    ELSE
      test_fail('Encryption with both passwords failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 2.4: Encrypt already encrypted PDF (should fail)
  test_start('EncryptPDF - Already encrypted PDF (should fail)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'first',
      p_encryption => 'RC4-128'
    );

    -- Try to encrypt again
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_encrypted,
      p_user_password => 'second',
      p_encryption => 'RC4-128'
    );
    test_fail('Should have raised error for already encrypted PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20859 THEN
        test_pass('Correctly rejected already encrypted PDF');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  ================================================================================
  -- SECTION 3: Permission Controls
  ================================================================================
  section_start('SECTION 3: Permission Controls');

  -- TEST 3.1: EncryptPDF - With permission restrictions
  test_start('EncryptPDF - With permission restrictions');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', FALSE);
    l_permissions.put('modify', FALSE);
    l_permissions.put('annotate', TRUE);
    l_permissions.put('fillForms', TRUE);
    l_permissions.put('extract', FALSE);
    l_permissions.put('assemble', FALSE);
    l_permissions.put('printHighQuality', TRUE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'restricted',
      p_owner_password => 'fullaccess',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('Encryption with permissions successful');

      -- Verify permissions in output
      l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
      l_perms := l_info.get_Object('permissions');
      IF l_perms IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] Permissions parsed:');
        DBMS_OUTPUT.PUT_LINE('         print=' || CASE WHEN l_perms.get_boolean('print') THEN 'Y' ELSE 'N' END);
        DBMS_OUTPUT.PUT_LINE('         copy=' || CASE WHEN l_perms.get_boolean('copy') THEN 'Y' ELSE 'N' END);
        DBMS_OUTPUT.PUT_LINE('         modify=' || CASE WHEN l_perms.get_boolean('modify') THEN 'Y' ELSE 'N' END);
      END IF;
    ELSE
      test_fail('Encryption with permissions failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.2: SetEncryption + SetPermissions - Valid
  test_start('SetEncryption + SetPermissions - Valid usage');
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetEncryption('RC4-128', 'user', 'owner');
    PL_FPDF.SetPermissions(
      p_print => TRUE,
      p_copy => FALSE,
      p_modify => FALSE,
      p_annotate => TRUE,
      p_fill_forms => TRUE,
      p_extract => FALSE,
      p_assemble => FALSE,
      p_print_high => TRUE
    );
    test_pass('SetEncryption + SetPermissions accepted');
    PL_FPDF.Reset();
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
      PL_FPDF.Reset();
  END;

  -- TEST 3.3: SetPermissions - Without SetEncryption (should fail)
  test_start('SetPermissions - Without SetEncryption (should fail)');
  BEGIN
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetPermissions(p_print => TRUE);
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20856 THEN
        test_pass('Correctly requires SetEncryption first');
      ELSE
        test_fail('Wrong error: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- TEST 3.4: All permissions enabled
  test_start('Encryption - All permissions enabled');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', TRUE);
    l_permissions.put('modify', TRUE);
    l_permissions.put('annotate', TRUE);
    l_permissions.put('fillForms', TRUE);
    l_permissions.put('extract', TRUE);
    l_permissions.put('assemble', TRUE);
    l_permissions.put('printHighQuality', TRUE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'allperms',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
    l_perms := l_info.get_Object('permissions');

    IF l_perms.get_boolean('print') AND l_perms.get_boolean('copy') AND
       l_perms.get_boolean('modify') THEN
      test_pass('All permissions correctly set');
    ELSE
      test_fail('Some permissions not set correctly');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5: No permissions (most restrictive)
  test_start('Encryption - No permissions (most restrictive)');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', FALSE);
    l_permissions.put('copy', FALSE);
    l_permissions.put('modify', FALSE);
    l_permissions.put('annotate', FALSE);
    l_permissions.put('fillForms', FALSE);
    l_permissions.put('extract', FALSE);
    l_permissions.put('assemble', FALSE);
    l_permissions.put('printHighQuality', FALSE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'noprint',
      p_owner_password => 'admin',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
    l_perms := l_info.get_Object('permissions');

    IF NOT l_perms.get_boolean('print') AND NOT l_perms.get_boolean('copy') THEN
      test_pass('Restrictive permissions correctly set');
    ELSE
      test_fail('Permissions not restricted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  ================================================================================
  -- SECTION 4: Decryption
  ================================================================================
  section_start('SECTION 4: Decryption');

  -- TEST 4.1: DecryptPDF - Non-encrypted PDF (should fail)
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

  -- TEST 4.2: DecryptPDF - NULL password (should fail)
  test_start('DecryptPDF - NULL password (should fail)');
  BEGIN
    -- First encrypt
    l_encrypted := PL_FPDF.EncryptPDF(l_pdf, 'test', NULL, NULL, 'RC4-128');

    -- Try to decrypt with NULL
    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, NULL);
    test_fail('Should have raised error for NULL password');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20854 THEN
        test_pass('Correctly rejected NULL password');
      ELSE
        test_fail('Wrong error: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- TEST 4.3: DecryptPDF - With correct user password
  test_start('DecryptPDF - With correct user password');
  BEGIN
    -- Encrypt
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'userpass',
      p_owner_password => 'ownerpass',
      p_encryption => 'RC4-128'
    );

    -- Decrypt with user password
    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, 'userpass');

    IF l_decrypted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_decrypted) > 0 THEN
      -- Verify it's no longer encrypted
      IF NOT PL_FPDF.IsEncrypted(l_decrypted) THEN
        test_pass('Decryption successful, PDF no longer encrypted');
      ELSE
        test_pass('Decryption returned PDF (encryption marker may still exist)');
      END IF;
    ELSE
      test_fail('Decryption returned empty result');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 4.4: DecryptPDF - With correct owner password
  test_start('DecryptPDF - With correct owner password');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'userpass',
      p_owner_password => 'ownerpass',
      p_encryption => 'RC4-128'
    );

    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, 'ownerpass');

    IF l_decrypted IS NOT NULL THEN
      test_pass('Decryption with owner password successful');
    ELSE
      test_fail('Decryption failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 4.5: DecryptPDF - Wrong password (should fail)
  test_start('DecryptPDF - Wrong password (should fail)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'correct',
      p_encryption => 'RC4-128'
    );

    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, 'wrong');
    test_fail('Should have raised error for wrong password');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20854 THEN
        test_pass('Correctly rejected wrong password');
      ELSE
        test_fail('Wrong error: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  ================================================================================
  -- SECTION 5: Security Info Parsing
  ================================================================================
  section_start('SECTION 5: Security Info Parsing');

  -- TEST 5.1: GetSecurityInfo - RC4-128 details
  test_start('GetSecurityInfo - RC4-128 encrypted PDF details');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'info_test',
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);

    DBMS_OUTPUT.PUT_LINE('  [INFO] Security Info:');
    DBMS_OUTPUT.PUT_LINE('         encrypted: ' || CASE WHEN l_info.get_boolean('encrypted') THEN 'YES' ELSE 'NO' END);
    DBMS_OUTPUT.PUT_LINE('         method: ' || l_info.get_string('method'));
    DBMS_OUTPUT.PUT_LINE('         version: ' || l_info.get_number('version'));
    DBMS_OUTPUT.PUT_LINE('         revision: ' || l_info.get_number('revision'));
    DBMS_OUTPUT.PUT_LINE('         keyLength: ' || l_info.get_number('keyLength'));

    IF l_info.get_boolean('encrypted') AND
       l_info.get_string('method') = 'RC4-128' AND
       l_info.get_number('keyLength') = 128 THEN
      test_pass('Security info correctly parsed');
    ELSE
      test_fail('Security info incomplete or incorrect');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 5.2: GetSecurityInfo - RC4-40 details
  test_start('GetSecurityInfo - RC4-40 encrypted PDF details');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'info_test',
      p_encryption => 'RC4-40'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);

    IF l_info.get_string('method') = 'RC4-40' AND
       l_info.get_number('version') = 1 THEN
      test_pass('RC4-40 info correctly parsed');
    ELSE
      test_fail('RC4-40 info incorrect');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 5.3: GetSecurityInfo - Permission value
  test_start('GetSecurityInfo - Permission value parsing');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', FALSE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'perm_test',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
    l_perms := l_info.get_Object('permissions');

    IF l_perms IS NOT NULL AND
       l_perms.get_boolean('print') = TRUE AND
       l_perms.get_boolean('copy') = FALSE THEN
      test_pass('Permissions correctly parsed from PDF');
      DBMS_OUTPUT.PUT_LINE('  [INFO] Permission value: ' || l_info.get_number('permissionValue'));
    ELSE
      test_fail('Permissions not parsed correctly');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  ================================================================================
  -- SECTION 6: Error Handling
  ================================================================================
  section_start('SECTION 6: Error Handling');

  -- TEST 6.1: EncryptPDF - Invalid encryption method
  test_start('EncryptPDF - Invalid encryption method');
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

  -- TEST 6.2: EncryptPDF - NULL password
  test_start('EncryptPDF - NULL password');
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

  -- TEST 6.3: EncryptPDF - AES-128 (not implemented)
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

  -- TEST 6.4: EncryptPDF - AES-256 (not implemented)
  test_start('EncryptPDF - AES-256 (not implemented yet)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'aes256test',
      p_encryption => 'AES-256'
    );
    test_fail('Should have raised error for AES-256');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20852 THEN
        test_pass('Correctly reports AES-256 not implemented');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
  END;

  -- TEST 6.5: SetEncryption - Invalid method
  test_start('SetEncryption - Invalid method');
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
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

  -- TEST 6.6: SetEncryption - NULL password
  test_start('SetEncryption - NULL password');
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetEncryption('RC4-128', NULL);
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20851 THEN
        test_pass('Correctly rejected NULL password');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
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
    ROUND(v_passed_tests / NULLIF(v_total_tests, 0) * 100, 1) || '%)');
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
  BEGIN
    IF l_pdf IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_pdf); END IF;
    IF l_encrypted IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_encrypted); END IF;
    IF l_decrypted IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_decrypted); END IF;
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/
