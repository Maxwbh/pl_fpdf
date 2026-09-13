--------------------------------------------------------------------------------
-- PL_FPDF - Tracejado e triangulo
--
-- O desenho vetorial que o test_geracao_basica nao cobre: o padrao de
-- tracejado e o triangulo.
--
-- Os dois se aferem pelo operador que sai no fluxo de conteudo -- '[] 0 d'
-- para linha cheia, 'm' e 'l' para o caminho --, porque "nao levantou" nao
-- prova desenho nenhum. Foi assim que a marca d'agua passou meses marcada
-- como pronta sem desenhar nada.
--
-- NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  -- TODAS as variaveis vem ANTES do primeiro subprograma local. Num DECLARE,
  -- depois do corpo do primeiro subprograma nao se declara mais nada, e o
  -- ORA-06550 aponta a linha da DECLARACAO -- nao a do subprograma que a
  -- invalidou --, entao se procura no lugar errado.
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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Tracejado e triangulo');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('Tracejado: SetDash liga, e sem argumento volta a linha cheia');
  --------------------------------------------------------------------------
  -- O operador 'd' do PDF: '[] 0 d' e linha cheia, qualquer outra coisa e
  -- tracejado. Sem isto a linha sai continua e ninguem nota ate imprimir.
  novo_doc;
  PL_FPDF.SetDash(2, 2);
  PL_FPDF.Line(20, 50, 190, 50);
  PL_FPDF.SetDash;
  PL_FPDF.Line(20, 60, 190, 60);
  PL_FPDF.SetLineDashPattern('[3 2] 0');
  PL_FPDF.Line(20, 70, 190, 70);
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '[] 0 d') > 0 THEN
    passou('o SetDash sem argumento devolveu a linha cheia');
  ELSE
    falhou('nao ha "[] 0 d" no arquivo: a linha nao volta a ser cheia');
  END IF;

  IF acha(l_pdf, '[3 2] 0 d') > 0 THEN
    passou('o SetLineDashPattern escreveu o padrao pedido, como esta');
  ELSE
    falhou('o padrao bruto nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('Triangle: desenha, e recusa orientacao que nao existe');
  --------------------------------------------------------------------------
  novo_doc;
  BEGIN
    PL_FPDF.Triangle(20, 20, 5, 'diagonal');
    falhou('aceitou a orientacao "diagonal"');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20821') > 0 THEN
        passou('orientacao invalida recusada com ORA-20821');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.Triangle(20, 20, 5, 'up', 'F');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  -- tres vertices: um 'm' para o primeiro e 'l' para os outros dois
  IF acha(l_pdf, ' m') > 0 AND acha(l_pdf, ' l') > 0 THEN
    passou('o triangulo saiu como caminho no fluxo de conteudo');
  ELSE
    falhou('o Triangle nao desenhou nada');
  END IF;

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
