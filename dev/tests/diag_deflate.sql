--------------------------------------------------------------------------------
-- Diagnóstico: o DEFLATE do package comprime igual à referência?
--
-- Não basta "descomprimiu, logo está certo": o inflate desta mesma base
-- toleraria escolhas diferentes das da referência, e o defeito só apareceria
-- em outro leitor. Por isso a comparação é BYTE A BYTE contra o que
-- scripts/pdfdeflate_reference/ produz para a mesma entrada — e essa referência
-- é validada contra o zlib.
--
-- Os casos cobrem o que costuma quebrar num compressor:
--   vazio e um byte ..... os limites do acumulador de bits
--   dois bytes .......... curto demais para casar (mínimo é 3)
--   'abcabc' ............ o casamento mínimo, exatamente
--   texto repetido ...... LZ77 em série, com casamentos longos
--
-- O que sai é um fluxo zlib: cabeçalho 78 9C, DEFLATE e Adler-32.
--
-- Execute na SQL Window do PL/SQL Developer (F8).
--------------------------------------------------------------------------------

DECLARE
  l_ok  PLS_INTEGER := 0;
  l_mau PLS_INTEGER := 0;

  PROCEDURE conferir(p_nome VARCHAR2, p_entrada VARCHAR2, p_esperado VARCHAR2) IS
    l_src  BLOB;
    l_out  BLOB;
    l_hex  VARCHAR2(32767);
    l_pos  PLS_INTEGER := 1;
    l_n    PLS_INTEGER;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_src, TRUE);
    IF p_entrada IS NOT NULL THEN
      DBMS_LOB.WRITEAPPEND(l_src, LENGTH(p_entrada) / 2, HEXTORAW(p_entrada));
    END IF;

    l_out := PL_FPDF.FlateEncode(l_src);
    l_n   := NVL(DBMS_LOB.GETLENGTH(l_out), 0);

    -- o resultado inteiro em hexadecimal, para comparar com a referência
    WHILE l_pos <= l_n LOOP
      l_hex := l_hex
            || RAWTOHEX(DBMS_LOB.SUBSTR(l_out, LEAST(2000, l_n - l_pos + 1),
                                        l_pos));
      l_pos := l_pos + 2000;
    END LOOP;

    IF NVL(l_hex, 'x') = NVL(p_esperado, 'x') THEN
      l_ok := l_ok + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_nome || ': '
        || NVL(LENGTH(p_entrada), 0) / 2 || ' -> ' || l_n || ' bytes');
    ELSE
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome);
      DBMS_OUTPUT.PUT_LINE('         esperado ' || SUBSTR(p_esperado, 1, 60));
      DBMS_OUTPUT.PUT_LINE('         obtido   ' || SUBSTR(l_hex, 1, 60));
    END IF;

    DBMS_LOB.FREETEMPORARY(l_src);
  END conferir;
BEGIN
  DBMS_OUTPUT.PUT_LINE('== DEFLATE: comprimido no banco x referência');

  conferir('vazio',
           '',
           '789C010000FFFF00000001');
  conferir('um byte',
           '41',
           '789C73040000420042');
  conferir('dois bytes',
           '4142',
           '789C7374020000C60084');
  conferir('casamento minimo',
           '616263616263',
           '789C4B4C4A062200080C024D');
  conferir('texto repetido (LZ77 em serie)',
           '4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A4254202F46312031322054662032302038303020546420284F6C61206D756E646F2920546A2045540A',
           '789C730A51D0773354303452084953303250B0303050084951D0F0CF4954C82DCD4BC9D75408C952700DE11A5538AA7054215821004289CCB1');

  -- O resumo NAO pode repetir os marcadores: o runner conta as ocorrencias de
  -- [PASS] e [FAIL] na saida, e uma linha com os dois vira um teste fantasma
  -- que passou e um que falhou.
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  ' || l_ok || ' passou | ' || l_mau || ' falhou');
END;
/
