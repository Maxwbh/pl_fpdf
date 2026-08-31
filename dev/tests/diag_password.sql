--------------------------------------------------------------------------------
-- Diagnóstico: por que uma senha errada é aceita por DecryptPDF
--
-- Reproduz o caso do teste 17 (test_phase_security.sql) com o log em nível
-- DEBUG, para ver qual das duas comparações de /U está retornando verdadeiro:
-- a do caminho de usuário ou a do caminho de proprietário.
--
-- Execute na SQL Window do PL/SQL Developer (F8) e envie a saída.
--------------------------------------------------------------------------------

DECLARE
  l_pdf       BLOB;
  l_enc       BLOB;
  l_dec       BLOB;
  l_info      JSON_OBJECT_T;

  FUNCTION doc RETURN BLOB IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Documento de diagnostico', '0', 1);
    RETURN PL_FPDF.OutputBlob();
  END;

  PROCEDURE tentar(p_senha VARCHAR2, p_esperado VARCHAR2) IS
    l_x BLOB;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('-- DecryptPDF com senha ' || p_senha ||
                         ' (esperado: ' || p_esperado || ')');
    l_x := PL_FPDF.DecryptPDF(l_enc, p_senha);
    DBMS_OUTPUT.PUT_LINE('   RESULTADO: aceitou (' ||
                         NVL(DBMS_LOB.GETLENGTH(l_x), 0) || ' bytes)');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('   RESULTADO: recusou -> ' ||
                           SUBSTR(SQLERRM, 1, 120));
  END;
BEGIN
  -- São duas chaves: SetLogLevel define o nível, mas log_message só escreve se
  -- gb_mode_debug estiver ligado — e quem liga isso é DebugEnabled.
  PL_FPDF.DebugEnabled;
  PL_FPDF.SetLogLevel(4);          -- DEBUG: mostra as comparações de /U
  PL_FPDF.ClearPDFCache;

  l_pdf := doc;
  PL_FPDF.Reset;
  DBMS_OUTPUT.PUT_LINE('PDF de origem: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');

  -- Sem senha de proprietário: EncryptPDF usa a de usuário para as duas,
  -- então 'correct' vale como usuário E como proprietário.
  l_enc := PL_FPDF.EncryptPDF(
             p_pdf           => l_pdf,
             p_user_password => 'correct',
             p_encryption    => 'RC4-128');
  DBMS_OUTPUT.PUT_LINE('PDF cifrado:   ' || DBMS_LOB.GETLENGTH(l_enc) || ' bytes');

  l_info := PL_FPDF.GetSecurityInfo(l_enc);
  DBMS_OUTPUT.PUT_LINE('metodo=' || l_info.get_string('method') ||
                       ' V=' || l_info.get_number('version') ||
                       ' R=' || l_info.get_number('revision') ||
                       ' keyLength=' || l_info.get_number('keyLength'));

  -- Despeja o dicionario /Encrypt e o trailer em hexadecimal. Com /O, /U, /P e
  -- /ID em maos da para refazer os algoritmos 2, 5 e 7 fora do banco e comparar
  -- passo a passo com o que o package calcula.
  DECLARE
    l_tam  PLS_INTEGER := DBMS_LOB.GETLENGTH(l_enc);
    l_cauda VARCHAR2(4000);
    l_pos  PLS_INTEGER;
  BEGIN
    l_cauda := UTL_RAW.CAST_TO_VARCHAR2(
                 DBMS_LOB.SUBSTR(l_enc, LEAST(l_tam, 1200),
                                 GREATEST(1, l_tam - 1199)));
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('-- fim do PDF cifrado (dicionario /Encrypt e trailer):');
    l_pos := 1;
    WHILE l_pos <= LENGTH(l_cauda) LOOP
      DBMS_OUTPUT.PUT_LINE('   ' ||
        REPLACE(REPLACE(SUBSTR(l_cauda, l_pos, 100), CHR(13)), CHR(10), ' '));
      l_pos := l_pos + 100;
    END LOOP;
  END;

  tentar('correct', 'aceitar');
  tentar('wrong',   'recusar');

  PL_FPDF.SetLogLevel(0);
  PL_FPDF.DebugDisabled;
  PL_FPDF.ClearPDFCache;
  PL_FPDF.Reset;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('ERRO: ' || SQLERRM);
    BEGIN PL_FPDF.SetLogLevel(0); PL_FPDF.DebugDisabled; PL_FPDF.Reset;
    EXCEPTION WHEN OTHERS THEN NULL; END;
END;
/
