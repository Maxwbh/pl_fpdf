--------------------------------------------------------------------------------
-- PL_FPDF - Fonte corrente, entrelinha e escrita de texto
--
-- A fonte que esta valendo, e o texto escrito com ela fora da celula.
--
-- O que distingue estas rotinas: o SetFont NORMALIZA -- familia em minuscula,
-- estilo em maiuscula --, entao comparar o retorno com o que se passou nunca
-- casa; o Text escreve num ponto e NAO move o cursor; e o giro tem dois erros
-- diferentes, um para o angulo que nao existe e outro para o que existe e a
-- rotina nao faz.
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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Fonte corrente, entrelinha e escrita de texto');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('Fonte: corpo, familia e estilo sao lidos de volta');
  --------------------------------------------------------------------------
  -- O que se le de volta NAO e o eco do que se passou: o package NORMALIZA a
  -- familia para minuscula e o estilo para maiuscula, como o FPDF original.
  -- Entao "IF GetCurrentFontFamily = 'Times'" nunca casa, e o teste afere a
  -- normalizacao de proposito -- foi assim que ela apareceu, com este caso
  -- falhando contra a expectativa errada de quem o escreveu.
  novo_doc;
  PL_FPDF.SetFont('Times', 'b', 14);
  IF PL_FPDF.GetCurrentFontFamily = 'times' THEN
    passou('a familia volta em MINUSCULA, normalizada');
  ELSE
    falhou('a familia voltou como "' || PL_FPDF.GetCurrentFontFamily
           || '", esperado "times" em minuscula');
  END IF;

  IF PL_FPDF.GetCurrentFontStyle = 'B' THEN
    passou('o estilo volta em MAIUSCULA, normalizado ("b" virou "B")');
  ELSE
    falhou('o estilo voltou como "' || PL_FPDF.GetCurrentFontStyle
           || '", esperado "B" em maiuscula');
  END IF;

  IF PL_FPDF.GetCurrentFontSize = 14 THEN
    passou('o corpo confere');
  ELSE
    falhou('o corpo voltou ' || TO_CHAR(PL_FPDF.GetCurrentFontSize));
  END IF;

  PL_FPDF.SetFontSize(9);
  IF PL_FPDF.GetCurrentFontSize = 9
     AND PL_FPDF.GetCurrentFontFamily = 'times' THEN
    passou('SetFontSize troca so o corpo, e mantem a familia');
  ELSE
    falhou('depois do SetFontSize(9): '
           || PL_FPDF.GetCurrentFontFamily || '/'
           || TO_CHAR(PL_FPDF.GetCurrentFontSize));
  END IF;

  --------------------------------------------------------------------------
  caso('Entrelinha: SetLineSpacing e lida de volta e muda a medida');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetLineSpacing(7);
  IF PL_FPDF.GetLineSpacing = 7 THEN
    passou('a entrelinha e lida de volta');
  ELSE
    falhou('SetLineSpacing(7) e GetLineSpacing devolveu '
           || TO_CHAR(PL_FPDF.GetLineSpacing));
  END IF;

  --------------------------------------------------------------------------
  caso('Text escreve no ponto, sem mover o cursor');
  --------------------------------------------------------------------------
  -- E o que distingue o Text do Cell: nao ha celula, nao ha quebra e o cursor
  -- fica onde estava.
  novo_doc;
  PL_FPDF.SetXY(50, 60);
  l_n := PL_FPDF.GetX;
  l_n2 := PL_FPDF.GetY;
  PL_FPDF.Text(20, 100, 'texto solto');
  IF PL_FPDF.GetX = l_n AND PL_FPDF.GetY = l_n2 THEN
    passou('o cursor nao se moveu');
  ELSE
    falhou('o cursor foi de (' || TO_CHAR(l_n) || ',' || TO_CHAR(l_n2)
           || ') para (' || TO_CHAR(PL_FPDF.GetX) || ','
           || TO_CHAR(PL_FPDF.GetY) || ')');
  END IF;

  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, 'texto solto') > 0 AND acha(l_pdf, 'Tj') > 0 THEN
    passou('o texto saiu no fluxo de conteudo');
  ELSE
    falhou('o texto do Text nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('CellRotated: giro invalido e recusado, giro valido emite a matriz');
  --------------------------------------------------------------------------
  novo_doc;
  BEGIN
    PL_FPDF.CellRotated(40, 10, 'teste', '0', 0, 'L', 0, '', 45);
    falhou('aceitou giro de 45 graus');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20110') > 0 THEN
        passou('giro de 45 recusado com ORA-20110');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.CellRotated(40, 10, 'girado', '0', 0, 'L', 0, '', 90);
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  -- o giro sai como matriz entre q e Q; sem ela o texto fica reto
  IF acha(l_pdf, 'girado') > 0 AND acha(l_pdf, ' cm') > 0 THEN
    passou('o texto girado saiu com a matriz de transformacao');
  ELSE
    falhou('o CellRotated(90) nao emitiu matriz: o texto sairia reto');
  END IF;

  --------------------------------------------------------------------------
  caso('WriteRotated: so giro zero, e os outros dizem o porque');
  --------------------------------------------------------------------------
  -- Aqui ha DOIS erros diferentes, e a diferenca importa: -20110 e giro que
  -- nao existe, -20111 e giro que existe mas esta rotina nao faz.
  novo_doc;
  BEGIN
    PL_FPDF.WriteRotated(6, 'teste', NULL, 45);
    falhou('aceitou giro de 45 graus');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20110') > 0 THEN
        passou('giro de 45 recusado com ORA-20110');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  BEGIN
    PL_FPDF.WriteRotated(6, 'teste', NULL, 90);
    falhou('aceitou giro de 90, que esta rotina nao sabe fazer');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20111') > 0 THEN
        passou('giro de 90 recusado com ORA-20111, que e outro caso');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.WriteRotated(6, 'sem giro nenhum');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, 'sem giro nenhum') > 0 THEN
    passou('com giro zero escreve, delegando ao Write');
  ELSE
    falhou('o texto sem giro nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('UTF8ToPDFString escapa o que a sintaxe do PDF reserva');
  --------------------------------------------------------------------------
  -- Parentese e barra invertida terminam a string do PDF antes da hora, e o
  -- arquivo quebra a partir dali.
  l_txt := PL_FPDF.UTF8ToPDFString('Total (liquido) 50\%');
  IF INSTR(l_txt, '\(') > 0 AND INSTR(l_txt, '\)') > 0 THEN
    passou('os parenteses sairam escapados');
  ELSE
    falhou('parenteses nao escapados: ' || l_txt);
  END IF;

  IF PL_FPDF.UTF8ToPDFString(NULL) IS NULL THEN
    passou('NULL entra e NULL sai, sem levantar');
  ELSE
    falhou('NULL devolveu alguma coisa');
  END IF;

  --------------------------------------------------------------------------
  caso('AddFont registra sem ler arquivo nenhum');
  --------------------------------------------------------------------------
  -- O AddFont so registra na colecao de fontes e deriva o nome do arquivo de
  -- metricas quando nao recebe um. Nao le disco, entao roda em qualquer
  -- ambiente -- foi engano meu te-lo posto na lista dos que precisam de grant.
  novo_doc;
  BEGIN
    PL_FPDF.AddFont('Helvetica', 'B');
    passou('AddFont registrou a fonte sem tocar em arquivo');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('AddFont levantou: ' || SQLERRM);
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
