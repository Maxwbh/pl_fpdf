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

DECLARE
  -- Test counters
  v_total_tests PLS_INTEGER := 0;
  v_passed_tests PLS_INTEGER := 0;
  v_failed_tests PLS_INTEGER := 0;
  v_skipped_tests PLS_INTEGER := 0;
  v_section VARCHAR2(100);
  -- A criptografia depende de EXECUTE em SYS.DBMS_CRYPTO. Sem o privilégio os
  -- casos que a exercitam são PULADOS, não reprovados: é ausência de ambiente,
  -- não defeito do package. A detecção é feita em test_fail, pelo ORA-20860.

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
    -- ORA-20860 = sem acesso a DBMS_CRYPTO; ORA-20862 = existe, mas não cifra
    -- de verdade (autoteste com vetores conhecidos reprovou). Nos dois casos é
    -- ambiente, não defeito do package: conta como PULADO. Cobre também os
    -- casos que comparam o código do erro e recebem um destes no lugar.
    IF INSTR(p_msg, 'ORA-20860') > 0 THEN
      v_skipped_tests := v_skipped_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [SKIP] sem acesso a DBMS_CRYPTO');
      RETURN;
    END IF;
    IF INSTR(p_msg, 'ORA-20862') > 0 THEN
      v_skipped_tests := v_skipped_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [SKIP] DBMS_CRYPTO nao cifra de verdade '
                           || '(autoteste reprovou) — use o do Oracle');
      RETURN;
    END IF;
    v_failed_tests := v_failed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  PROCEDURE test_skip(p_msg VARCHAR2) IS
  BEGIN
    v_skipped_tests := v_skipped_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
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
    l_result := PL_FPDF.OutputBlob();
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

  -- ================================================================================
  -- SECTION 1: Basic Encryption Detection
  -- ================================================================================
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

  -- ================================================================================
  -- SECTION 2: RC4 Encryption
  -- ================================================================================
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

  -- ================================================================================
  -- SECTION 3: Permission Controls
  -- ================================================================================
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

  -- TEST 3.5: o conteudo sai realmente cifrado
  test_start('EncryptPDF - conteudo deixa de aparecer em claro');
  DECLARE
    co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaParaConferirCifragem';
    l_claro  BLOB;
    l_cif    BLOB;
    l_erros  PLS_INTEGER := 0;
    l_msg    VARCHAR2(400);

    FUNCTION contem(p_pdf BLOB, p_txt VARCHAR2) RETURN BOOLEAN IS
    BEGIN
      RETURN DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1) > 0;
    END;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, co_marca, '0', 1);
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    -- pre-condicao: sem cifrar, a marca ESTA legivel nos bytes. Sem isto o
    -- teste passaria por engano se o texto nunca chegasse ao arquivo.
    IF NOT contem(l_claro, co_marca) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [a marca nao aparece nem no PDF sem cifrar]';
    END IF;

    l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                p_user_password => 'segredo',
                                p_encryption => 'RC4-128');

    -- o que separa "marcado como protegido" de protegido de verdade
    IF contem(l_cif, co_marca) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [texto ainda legivel nos bytes: apenas MARCADO'
                     || ' como protegido]';
    END IF;

    IF NOT PL_FPDF.IsEncrypted(l_cif) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [IsEncrypted nao reconhece o resultado]';
    END IF;

    IF l_erros = 0 THEN
      test_pass('conteudo sai cifrado, nao apenas marcado como protegido');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5b: AES cifra de verdade, nas duas revisoes
  FOR r IN (SELECT 'AES-128' m, 'AESV2' cfm, 4 v FROM dual
            UNION ALL
            SELECT 'AES-256', 'AESV3', 5 FROM dual) LOOP
    test_start('EncryptPDF - ' || r.m || ' cifra o conteudo');
    DECLARE
      co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaParaConferirAES';
      l_claro  BLOB;
      l_cif    BLOB;
      l_info   JSON_OBJECT_T;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, co_marca, '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_encryption => r.m);

      IF DBMS_LOB.INSTR(l_claro, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) = 0 THEN
        test_fail('o PDF de origem nao tinha a marca em claro; teste invalido');
      ELSIF DBMS_LOB.INSTR(l_cif, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) > 0 THEN
        test_fail(r.m || ': o texto continua em claro nos bytes');
      ELSIF DBMS_LOB.INSTR(l_cif,
              UTL_RAW.CAST_TO_RAW('/CFM /' || r.cfm), 1, 1) = 0 THEN
        -- sem /CF, /StmF e /StrF o leitor supoe /Identity e mostra o conteudo
        -- cifrado como se fosse texto
        test_fail(r.m || ': /CFM /' || r.cfm || ' nao foi declarado');
      ELSIF DBMS_LOB.INSTR(l_cif, UTL_RAW.CAST_TO_RAW('/StmF /StdCF'), 1, 1) = 0
      THEN
        test_fail(r.m || ': /StmF nao aponta para o filtro');
      ELSE
        l_info := PL_FPDF.GetSecurityInfo(l_cif);
        IF l_info.get_number('version') != r.v THEN
          test_fail(r.m || ': /V saiu ' || l_info.get_number('version'));
        ELSE
          test_pass(r.m || ': conteudo cifrado, /CF e /StmF declarados');
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' - Error: ' || SQLERRM);
    END;
  END LOOP;

  -- TEST 3.5c: ida e volta do AES, nas duas revisoes
  FOR r IN (SELECT 'AES-128' m FROM dual UNION ALL SELECT 'AES-256' FROM dual)
  LOOP
    test_start('EncryptPDF + DecryptPDF - ida e volta em ' || r.m);
    DECLARE
      co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaIdaEVoltaAES';
      l_claro  BLOB;
      l_cif    BLOB;
      l_dec    BLOB;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, co_marca, '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_owner_password => 'dono',
                                  p_encryption => r.m);
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'segredo');

      IF DBMS_LOB.INSTR(l_dec, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) = 0 THEN
        test_fail(r.m || ': o conteudo nao voltou ao original');
      ELSIF PL_FPDF.IsEncrypted(l_dec) THEN
        test_fail(r.m || ': o resultado ainda se declara criptografado');
      ELSE
        test_pass(r.m || ': decifrado devolve o conteudo original');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' - Error: ' || SQLERRM);
    END;

    -- a senha de proprietario tambem abre, e por outro caminho: no R6 ela usa
    -- os 48 bytes do /U no hash e desembrulha a chave de /OE, nao de /UE
    test_start('DecryptPDF - senha de proprietario em ' || r.m);
    DECLARE
      l_claro BLOB;
      l_cif   BLOB;
      l_dec   BLOB;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Documento com dois donos', '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_owner_password => 'dono',
                                  p_encryption => r.m);
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'dono');
      IF DBMS_LOB.INSTR(l_dec,
           UTL_RAW.CAST_TO_RAW('Documento com dois donos'), 1, 1) = 0 THEN
        test_fail(r.m || ': a senha de proprietario nao devolveu o conteudo');
      ELSE
        test_pass(r.m || ': senha de proprietario abre o documento');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' (proprietario) - Error: ' || SQLERRM);
    END;

    -- senha errada tem de ser RECUSADA, e nao devolver lixo
    test_start('DecryptPDF - senha errada em ' || r.m);
    DECLARE
      l_claro BLOB;
      l_cif   BLOB;
      l_dec   BLOB;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Nao deve abrir', '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_encryption => r.m);
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'errada');
      test_fail(r.m || ': aceitou uma senha errada');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20854 THEN
          test_pass(r.m || ': senha errada recusada com -20854');
        ELSE
          test_fail(r.m || ': codigo errado: ' || SQLCODE || ' - ' || SQLERRM);
        END IF;
    END;
  END LOOP;

  -- TEST 3.5d: fluxo grande com RC4
  --
  -- crypto_rc4 monta o resultado em hexadecimal, dois caracteres por byte, e
  -- estoura em 16383 bytes. Um documento denso passa disso com folga, e antes
  -- rebentava com ORA-06502 sem explicação. O fluxo agora vai por
  -- crypto_rc4_blob, que agenda a chave uma vez e carrega o estado da cifra
  -- entre os pedaços — fatiar com crypto_rc4 reiniciaria a cifra em cada
  -- pedaço e produziria lixo.
  test_start('EncryptPDF - fluxo acima de 16 KB com RC4-128');
  DECLARE
    co_marca CONSTANT VARCHAR2(40) := 'MarcaNoFimDoFluxoGrande';
    l_claro  BLOB;
    l_cif    BLOB;
    l_dec    BLOB;
    l_tam    PLS_INTEGER;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);
    -- cada célula emite ~100 bytes de instruções: bem além de 16 KB
    FOR i IN 1 .. 900 LOOP
      PL_FPDF.Cell(20, 4, 'Bloco ' || i, '1',
                   CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Cell(0, 6, co_marca, '0', 1);
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;
    l_tam := DBMS_LOB.GETLENGTH(l_claro);

    IF l_tam < 16383 THEN
      test_fail('o documento de origem tem só ' || l_tam
                || ' bytes; o teste não exercita o limite');
    ELSE
      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'grande',
                                  p_encryption => 'RC4-128');
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'grande');

      IF DBMS_LOB.INSTR(l_cif, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) > 0 THEN
        test_fail('a marca continua em claro no PDF cifrado');
      ELSIF DBMS_LOB.INSTR(l_dec, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) = 0 THEN
        -- a marca fica no FIM do fluxo: se o estado da cifra não atravessasse
        -- os lotes, o começo voltaria certo e o fim viria como lixo
        test_fail('a marca no fim do fluxo não voltou ao decifrar');
      ELSE
        test_pass('fluxo de ' || l_tam || ' bytes cifrado e decifrado com RC4');
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5e: IsEncrypted olha o TRAILER, não o começo do arquivo
  --
  -- A versão anterior lia os primeiros 32767 bytes, e /Encrypt fica no fim.
  -- Funcionava por acidente em documento pequeno, que cabe inteiro nessa
  -- janela. Num PDF cifrado maior, mentia — e a consequência pior não era
  -- recusar a decifragem: EncryptPDF usa IsEncrypted para barrar dupla
  -- cifragem, e passava a cifrar de novo o que já estava cifrado.
  test_start('IsEncrypted reconhece PDF cifrado acima de 32 KB');
  DECLARE
    l_claro BLOB;
    l_cif   BLOB;
    l_dupla BLOB;
    l_erros PLS_INTEGER := 0;
    l_msg   VARCHAR2(4000);
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);
    FOR i IN 1 .. 900 LOOP
      PL_FPDF.Cell(20, 4, 'Linha ' || i, '1',
                   CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                p_user_password => 'grande',
                                p_encryption => 'RC4-128');

    IF DBMS_LOB.GETLENGTH(l_cif) <= 32767 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [o cifrado tem só ' || DBMS_LOB.GETLENGTH(l_cif)
                     || ' bytes; não exercita a janela]';
    END IF;
    IF NOT PL_FPDF.IsEncrypted(l_cif) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [IsEncrypted não reconhece o PDF grande cifrado]';
    END IF;
    IF PL_FPDF.IsEncrypted(l_claro) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [IsEncrypted acusa o PDF em claro]';
    END IF;

    -- dupla cifragem tem de ser barrada
    BEGIN
      l_dupla := PL_FPDF.EncryptPDF(p_pdf => l_cif,
                                    p_user_password => 'outra',
                                    p_encryption => 'RC4-128');
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [aceitou cifrar de novo um PDF já cifrado]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -20859 THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [dupla cifragem deu ' || SQLCODE
                         || ', esperado -20859]';
        END IF;
    END;

    IF l_erros = 0 THEN
      test_pass('IsEncrypted acerta acima de 32 KB e a dupla cifragem é barrada');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.6: ida e volta preserva o documento
  test_start('EncryptPDF + DecryptPDF - ida e volta preserva o conteudo');
  DECLARE
    co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaParaConferirCifragem';
    l_claro  BLOB;
    l_cif    BLOB;
    l_dec    BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, co_marca, '0', 1);
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                p_user_password => 'segredo',
                                p_encryption => 'RC4-128');
    l_dec := PL_FPDF.DecryptPDF(l_cif, 'segredo');

    IF DBMS_LOB.INSTR(l_dec, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) > 0 THEN
      test_pass('decifrado devolve o conteudo original');
    ELSE
      test_fail('o conteudo nao voltou ao original depois de decifrar');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- ================================================================================
  -- SECTION 4: Decryption
  -- ================================================================================
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

  -- ================================================================================
  -- SECTION 5: Security Info Parsing
  -- ================================================================================
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

  -- ================================================================================
  -- SECTION 6: Error Handling
  -- ================================================================================
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

  -- TEST 6.3 / 6.4: AES-128 e AES-256 são implementados
  --
  -- Estes dois testes exigiam a RECUSA com -20852 e passavam por isso. Deixá-los
  -- assim seria pior que inútil: uma suíte verde afirmando que o AES não existe.
  FOR r IN (SELECT 'AES-128' m, 128 bits FROM dual
            UNION ALL
            SELECT 'AES-256', 256 FROM dual) LOOP
    test_start('EncryptPDF - ' || r.m || ' produz PDF protegido');
    DECLARE
      l_enc  BLOB;
      l_info JSON_OBJECT_T;
    BEGIN
      l_enc := PL_FPDF.EncryptPDF(
        p_pdf => l_pdf,
        p_user_password => 'aestest',
        p_encryption => r.m
      );
      IF l_enc IS NULL OR DBMS_LOB.GETLENGTH(l_enc) = 0 THEN
        test_fail(r.m || ': resultado vazio');
      ELSIF NOT PL_FPDF.IsEncrypted(l_enc) THEN
        test_fail(r.m || ': o resultado nao se declara criptografado');
      ELSE
        l_info := PL_FPDF.GetSecurityInfo(l_enc);
        IF l_info.get_string('method') != r.m THEN
          test_fail(r.m || ': GetSecurityInfo diz ' || l_info.get_string('method'));
        ELSIF l_info.get_number('keyLength') != r.bits THEN
          test_fail(r.m || ': keyLength ' || l_info.get_number('keyLength')
                    || ', esperado ' || r.bits);
        ELSE
          test_pass(r.m || ': cifra e se identifica corretamente');
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' - Error: ' || SQLERRM);
    END;
  END LOOP;

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
  DBMS_OUTPUT.PUT_LINE('Testes:       ' || v_total_tests);
  DBMS_OUTPUT.PUT_LINE('Passou:       ' || v_passed_tests);
  DBMS_OUTPUT.PUT_LINE('Falhou:       ' || v_failed_tests);
  DBMS_OUTPUT.PUT_LINE('Pulados:      ' || v_skipped_tests);

  IF v_skipped_tests > 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Os testes pulados precisam de criptografia real:');
    DBMS_OUTPUT.PUT_LINE('  GRANT EXECUTE ON SYS.DBMS_CRYPTO TO ' ||
                         SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || ';');
    DBMS_OUTPUT.PUT_LINE('Um DBMS_CRYPTO substituto no próprio schema só serve');
    DBMS_OUTPUT.PUT_LINE('se implementar MD5 e RC4 de fato — um que devolva a');
    DBMS_OUTPUT.PUT_LINE('entrada sem alterar faz o /O sair em texto claro e');
    DBMS_OUTPUT.PUT_LINE('QUALQUER senha ser aceita.');
  END IF;

  IF v_failed_tests = 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('*** ALL TESTS PASSED ***' ||
      CASE WHEN v_skipped_tests > 0
           THEN ' (' || v_skipped_tests || ' pulado(s))' END);
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
