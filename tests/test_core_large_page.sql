--------------------------------------------------------------------------------
-- PL_FPDF - Núcleo: páginas grandes e alias de total de páginas
--
-- Regressão para o limite de 32 KB por página: antes do buffer de página em CLOB,
-- uma página com muitas células estourava ORA-06502 em p_out.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  l_pdf         BLOB;
  l_test_count  PLS_INTEGER := 0;
  l_pass_count  PLS_INTEGER := 0;
  l_fail_count  PLS_INTEGER := 0;

  PROCEDURE test_start(p_test_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test ' || l_test_count || ': ' || p_test_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
  END;

  PROCEDURE test_pass(p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || NVL(p_message, 'Test passed'));
  END;

  PROCEDURE test_fail(p_message VARCHAR2) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_message);
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================');
  DBMS_OUTPUT.PUT_LINE('  PL_FPDF - Núcleo: páginas grandes');
  DBMS_OUTPUT.PUT_LINE('================================================================');

  --------------------------------------------------------------------------
  test_start('Página única com 3.000 células (muito acima de 32 KB)');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);

    -- Cada célula emite ~100 bytes de instruções PDF: ~300 KB numa página só.
    FOR i IN 1 .. 3000 LOOP
      PL_FPDF.Cell(20, 4, 'L' || i, '1', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 32767 THEN
      test_pass('PDF gerado com ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      test_fail('PDF vazio ou truncado: ' || NVL(DBMS_LOB.GETLENGTH(l_pdf), 0) || ' bytes');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- ORA-06502 aqui significa que o teto de 32 KB por página voltou
      test_fail('Exceção ao gerar página grande: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Múltiplas páginas grandes mantêm o conteúdo separado');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 8);

    FOR pg IN 1 .. 3 LOOP
      PL_FPDF.AddPage();
      FOR i IN 1 .. 800 LOOP
        PL_FPDF.Cell(20, 4, 'P' || pg || '-' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
      END LOOP;
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 32767 THEN
      test_pass('3 páginas grandes geradas: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      test_fail('PDF vazio ou truncado');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção com múltiplas páginas grandes: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Alias {nb} substituído em página que ultrapassa 32 KB');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetAliasNbPages();          -- habilita '{nb}'
    PL_FPDF.SetFont('Arial', '', 8);
    PL_FPDF.AddPage();

    -- Enche a página e só então escreve o alias, garantindo que ele caia
    -- além do primeiro bloco de 32 KB do buffer.
    FOR i IN 1 .. 1200 LOOP
      PL_FPDF.Cell(20, 4, 'X' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Cell(0, 6, 'Total de paginas: {nb}', '0', 1);
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 6, 'Pagina 2 de {nb}', '0', 1);

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NULL OR DBMS_LOB.GETLENGTH(l_pdf) = 0 THEN
      test_fail('PDF vazio');
    ELSIF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW('{nb}')) > 0 THEN
      test_fail('Alias {nb} não foi substituído além do primeiro bloco');
    ELSE
      test_pass('Alias substituído corretamente em página grande');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção no teste de alias: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Reset libera recursos e permite novo documento');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    FOR i IN 1 .. 500 LOOP
      PL_FPDF.Cell(20, 4, 'A' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.Cell(0, 10, 'Documento novo apos Reset', '0', 1);
    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      test_pass('Segundo documento gerado após Reset');
    ELSE
      test_fail('Falha ao gerar documento após Reset');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção após Reset: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================');
  DBMS_OUTPUT.PUT_LINE('  Total: ' || l_test_count ||
                       ' | Passou: ' || l_pass_count ||
                       ' | Falhou: ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/
