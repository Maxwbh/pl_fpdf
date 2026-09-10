--------------------------------------------------------------------------------
-- PL_FPDF - Texto acentuado nas fontes padrao (conversao WinAnsi)
--
-- O dicionario da fonte declara /Encoding /WinAnsiEncoding e o texto sai do
-- banco em AL32UTF8. Sem conversao, cada acentuado chegava ao leitor como DOIS
-- bytes e ele desenhava dois glifos: 'cobranca' com cedilha virava 'cobranA§a'.
-- Sem erro nenhum, num arquivo que abre normalmente -- so se percebia olhando.
--
-- Medido antes do conserto, e vale registrar porque nenhuma das duas suposicoes
-- do relato se confirmou:
--
--   CHR(231) e 1 byte (E7); SUBSTR('c cedilha',1,1) sao 2 (C3A7)
--   GetStringWidth('Sao Paulo') = 19.5326
--   GetStringWidth('Sao Paulo' com til) levantava ORA-06502 -- nao
--     NO_DATA_FOUND: o subtipo car tem UM byte e o caractere tem dois, entao
--     estourava antes de consultar a tabela
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_larg   NUMBER;
  l_larg2  NUMBER;
  l_erro   VARCHAR2(400);
  l_txt    VARCHAR2(200);

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  FUNCTION pdf_com(p_texto IN VARCHAR2) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(100, 10, p_texto);
    l_b := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    RETURN l_b;
  END pdf_com;
BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - conversao WinAnsi');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O acentuado sai como escape octal, nao como UTF-8 cru');
  --------------------------------------------------------------------------
  -- O byte convertido NAO pode ir cru: o documento e montado num CLOB e
  -- convertido no fim por CONVERTTOBLOB, que recodifica pelo charset do banco.
  -- Medido no diag: 256 bytes entram, 422 saem. O escape octal e ASCII e
  -- atravessa intacto.
  l_pdf := pdf_com('cobrança');

  IF acha(l_pdf, '\347') > 0 THEN
    passou('o cedilha saiu como \347, que o leitor resolve como 0xE7');
  ELSE
    falhou('nao ha \347 no arquivo - a conversao nao aconteceu');
  END IF;

  IF DBMS_LOB.INSTR(l_pdf, HEXTORAW('C3A7'), 1, 1) = 0 THEN
    passou('os bytes C3 A7 (UTF-8 cru) sumiram do arquivo');
  ELSE
    falhou('C3 A7 ainda esta no arquivo - o texto continua cru');
  END IF;

  --------------------------------------------------------------------------
  caso('Texto sem acento nao mudou');
  --------------------------------------------------------------------------
  -- O ASCII coincide nas duas codificacoes, entao o caminho comum tem de sair
  -- exatamente como saia. E onde uma regressao passaria despercebida.
  l_pdf := pdf_com('Sao Paulo');
  IF acha(l_pdf, 'Sao Paulo') > 0 THEN
    passou('o texto ASCII continua legivel no arquivo, sem escape');
  ELSE
    falhou('o texto ASCII foi alterado');
  END IF;

  --------------------------------------------------------------------------
  caso('Parenteses e barra seguem escapados');
  --------------------------------------------------------------------------
  -- Sao o escape que o PDF ja exigia, e a conversao nao pode ter comido.
  l_pdf := pdf_com('Total (liquido) \ 50%');
  IF acha(l_pdf, '\(liquido\)') > 0 THEN
    passou('parenteses escapados');
  ELSE
    falhou('parenteses nao escapados - a string do PDF quebra');
  END IF;

  --------------------------------------------------------------------------
  caso('GetStringWidth mede acentuado, e mede diferente');
  --------------------------------------------------------------------------
  -- Antes levantava ORA-06502. E nao basta devolver numero: o 'a' com til e
  -- mais largo que o 'a', entao as duas medidas TEM de diferir -- se saissem
  -- iguais, a conversao estaria caindo num caractere so.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);

  BEGIN
    l_larg  := PL_FPDF.GetStringWidth('Sao Paulo');
    l_larg2 := PL_FPDF.GetStringWidth('São Paulo');
    passou('mediu as duas: ' || TO_CHAR(l_larg) || ' e ' || TO_CHAR(l_larg2));

    IF l_larg2 != l_larg THEN
      passou('as larguras diferem, como devem');
    ELSE
      falhou('as duas medem igual - o acentuado nao chegou na tabela certa');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('ainda levanta: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Alinhamento a direita com acento nao levanta mais');
  --------------------------------------------------------------------------
  -- O Cell so chama GetStringWidth para align C e R. Era ai que o ORA-06502
  -- aparecia, enquanto o alinhamento a esquerda desenhava errado calado.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(100, 10, 'Endereço de cobrança', '0', 1, 'R');
    PL_FPDF.Cell(100, 10, 'Endereço de cobrança', '0', 1, 'C');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    passou('alinhado a direita e centralizado, ' || DBMS_LOB.GETLENGTH(l_pdf)
           || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Caractere fora do WinAnsi e recusado com erro proprio');
  --------------------------------------------------------------------------
  -- O criterio: recusar, e nao virar '?' em silencio. E o erro tem de ser o
  -- nosso, com a posicao -- se voltar ORA-06502, o conserto so trocou de
  -- sintoma. Ideograma escolhido por nao existir em WinAnsi de forma alguma.
  BEGIN
    l_pdf := pdf_com('Relatorio ' || UNISTR('\4E2D') || ' final');
    falhou('aceitou o caractere fora da tabela');
  EXCEPTION
    WHEN OTHERS THEN
      l_erro := SQLERRM;
      IF INSTR(l_erro, 'ORA-20203') > 0 THEN
        passou('recusado com ORA-20203');
        IF INSTR(l_erro, 'posicao 11') > 0 THEN
          passou('a mensagem diz a posicao');
        ELSE
          falhou('a mensagem nao diz a posicao: ' || l_erro);
        END IF;
      ELSIF INSTR(l_erro, 'ORA-06502') > 0 THEN
        falhou('ORA-06502 - trocou de sintoma, nao consertou');
      ELSE
        falhou('recusou com outro erro: ' || l_erro);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('As 27 excecoes do cp1252 atravessam');
  --------------------------------------------------------------------------
  -- De 0xA0 a 0xFF o cp1252 e o Latin-1, e o byte e o proprio ponto de codigo.
  -- As 27 posicoes entre 0x80 e 0x9F sao as unicas que precisam de tabela, e
  -- sao as que um teste de acento comum nao alcanca: travessao, aspas curvas,
  -- euro, reticencias.
  l_txt := UNISTR('\20AC \2014 \201C \201D \2026 \2122');   -- EUR - " " ... TM
  BEGIN
    l_pdf := pdf_com(l_txt);
    IF acha(l_pdf, '\200') > 0 AND acha(l_pdf, '\227') > 0
       AND acha(l_pdf, '\223') > 0 AND acha(l_pdf, '\231') > 0 THEN
      passou('euro, travessao, aspas curvas e marca registrada convertidos');
    ELSE
      falhou('alguma das 27 excecoes nao saiu como octal');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('Casos: ' || l_total
                       || ' | PASS: ' || l_ok
                       || ' | FAIL: ' || l_falhas
                       || ' | SKIP: ' || l_skip);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || SQLERRM);
    RAISE;
END;
/
