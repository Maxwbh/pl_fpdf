--------------------------------------------------------------------------------
-- PL_FPDF - Fechar o documento, callbacks, erro e os caminhos que exigem grant
--
-- As bordas do documento: fechá-lo, os callbacks de cabeçalho e rodapé, o
-- caminho interno de erro, e as saídas que dependem de recurso de fora.
--
-- Os três últimos casos existem para provar que a RECUSA funciona sem
-- concessão nenhuma -- diretório inexistente e URL que não responde --, e para
-- apontar a alternativa que não precisa de grant: o OutputBlob devolve os
-- mesmos bytes que o OutputFile gravaria, e o ImageFromBlob dispensa a rede.
--
-- NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). Só SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  -- TODAS as variáveis vem ANTES do primeiro subprograma local. Num DECLARE,
  -- depois do corpo do primeiro subprograma não se declara mais nada, e o
  -- ORA-06550 aponta a linha da DECLARAÇÃO -- não a do subprograma que a
  -- invalidou --, então se procura no lugar errado.
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_n      NUMBER;
  l_n2     NUMBER;
  l_txt    VARCHAR2(400);
  l_erro   VARCHAR2(400);
  l_json   JSON_OBJECT_T;
  l_fonte  PL_FPDF.recTTFFont;

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END caso;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END passou;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END falhou;

  PROCEDURE pulou(p_msg VARCHAR2) IS
  BEGIN
    l_skip := l_skip + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END pulou;

  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  PROCEDURE novo_doc(p_orient VARCHAR2 DEFAULT 'P') IS
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init(p_orient, 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
  END novo_doc;

BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Fechar o documento, callbacks, erro e os caminhos que exigem grant');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('ClosePDF fecha, e fechar de novo nao estraga');
  --------------------------------------------------------------------------
  -- As rotinas de saída já chamam o ClosePDF. Chamar antes, a mão, não pode
  -- gerar documento diferente nem levantar.
  novo_doc;
  PL_FPDF.Cell(50, 10, 'fechado a mao');
  PL_FPDF.ClosePDF;
  BEGIN
    PL_FPDF.ClosePDF;
    passou('fechar duas vezes nao levanta');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('o segundo ClosePDF levantou: ' || SQLERRM);
  END;

  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, 'fechado a mao') > 0 AND acha(l_pdf, '%%EOF') > 0 THEN
    passou('o documento fechado a mao sai inteiro');
  ELSE
    falhou('o documento fechado a mao saiu incompleto');
  END IF;

  --------------------------------------------------------------------------
  caso('Header e Footer sem callback registrado nao fazem nada');
  --------------------------------------------------------------------------
  -- São chamadas pelo próprio motor a cada página. Sem SetHeaderProc, a
  -- chamada tem de ser inócua -- não levantar e não escrever.
  novo_doc;
  BEGIN
    PL_FPDF.Header;
    PL_FPDF.Footer;
    passou('as duas sao inocuas sem callback registrado');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou sem callback: ' || SQLERRM);
  END;
  PL_FPDF.Reset;

  --------------------------------------------------------------------------
  caso('Error levanta ORA-20100 com a mensagem dada');
  --------------------------------------------------------------------------
  -- E o caminho interno de erro da biblioteca, publico por herança. Se ele
  -- deixar de levantar, sessenta handlers do package passam a engolir erro.
  BEGIN
    PL_FPDF.Error('mensagem de teste');
    falhou('o Error nao levantou nada');
  EXCEPTION
    WHEN OTHERS THEN
      l_erro := SQLERRM;
      IF INSTR(l_erro, 'ORA-20100') > 0
         AND INSTR(l_erro, 'mensagem de teste') > 0 THEN
        passou('levantou ORA-20100 com a mensagem');
      ELSE
        falhou('levantou outra coisa: ' || l_erro);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('Saida em arquivo: recusa sem DIRECTORY, e o BLOB e a alternativa');
  --------------------------------------------------------------------------
  -- OutputFile e Output gravam em DIRECTORY do banco, que exige WRITE
  -- concedido. O caminho de RECUSA não exige nada: diretório inexistente da
  -- ORA-29280, que o package traduz para -20401. E quem não tem o grant tem o
  -- OutputBlob, que devolve os mesmos bytes.
  novo_doc;
  PL_FPDF.Cell(50, 10, 'conteudo');
  BEGIN
    PL_FPDF.OutputFile('x.pdf', 'DIRETORIO_QUE_NAO_EXISTE_PLFPDF');
    falhou('gravou num diretorio que nao existe');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20401') > 0 THEN
        passou('diretorio inexistente recusado com ORA-20401');
      ELSIF INSTR(SQLERRM, 'ORA-20402') > 0 THEN
        passou('diretorio sem permissao recusado com ORA-20402');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.Cell(50, 10, 'conteudo');
  BEGIN
    PL_FPDF.Output('x.pdf', 'I');
    falhou('aceitou o modo de entrega ao navegador');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20306') > 0 THEN
        passou('modo "I" recusado com ORA-20306, que aponta o substituto');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.Cell(50, 10, 'conteudo');
  BEGIN
    PL_FPDF.Output('x.pdf', 'Z');
    falhou('aceitou um destino que nao existe');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20100') > 0 THEN
        passou('destino desconhecido recusado com ORA-20100');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;
  PL_FPDF.Reset;

  --------------------------------------------------------------------------
  caso('Imagem por URL: a alternativa sem rede e o ImageFromBlob');
  --------------------------------------------------------------------------
  -- Image e getImageFromUrl saem pela rede e exigem ACL concedida ao schema.
  -- Sem ela o UTL_HTTP levanta ORA-24247, que o package embrulha em -20100 --
  -- o MESMO código de uma URL invalida, então o teste não consegue distinguir
  -- os dois casos, e não finge que consegue.
  --
  -- O que da para afirmar sem ACL nenhuma: que a recusa acontece, e que o
  -- caminho equivalente por BLOB funciona. Esse já tem cobertura própria em
  -- test_stream_imagem.sql.
  novo_doc;
  BEGIN
    PL_FPDF.Image('http://nao.existe.invalid/x.png', 10, 10, 40);
    falhou('aceitou uma URL que nao responde');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20100') > 0
         OR INSTR(SQLERRM, 'ORA-24247') > 0 THEN
        passou('recusou a URL, com ou sem ACL: '
               || SUBSTR(REPLACE(SQLERRM, CHR(10), ' '), 1, 50));
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;
  PL_FPDF.Reset;

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('Casos: ' || l_total
                       || ' | PASS: ' || l_ok
                       || ' | FAIL: ' || l_falhas
                       || ' | SKIP: ' || l_skip);
  IF l_falhas > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: FALHOU');
  ELSIF l_skip > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK, com ' || l_skip
                         || ' caso(s) sem conclusao — leia os [SKIP] acima');
  ELSE
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
  END IF;
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || SQLERRM);
    RAISE;
END;
/
