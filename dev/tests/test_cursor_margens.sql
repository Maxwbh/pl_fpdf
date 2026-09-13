--------------------------------------------------------------------------------
-- PL_FPDF - Cursor, margens e quebra de pagina
--
-- Onde o proximo desenho vai cair. E a metade da biblioteca que nao aparece
-- no arquivo: o cursor, as margens e a quebra automatica decidem a posicao de
-- tudo, e erram em silencio -- o texto sai, so que no lugar errado.
--
-- Duas regras aqui nao estao no nome da rotina, e sao as que mordem:
-- coordenada NEGATIVA conta a partir da borda oposta, e o SetY devolve o x
-- para a margem esquerda.
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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Cursor, margens e quebra de pagina');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('GetX/SetX: negativo conta a partir da borda direita');
  --------------------------------------------------------------------------
  -- A regra do SetX nao esta no nome dele: px negativo NAO e erro, e sim
  -- medida a partir da direita. Quem nao sabe disso passa -10 achando que
  -- volta dez para tras e o texto vai parar do outro lado da pagina.
  novo_doc;
  PL_FPDF.SetX(30);
  IF PL_FPDF.GetX = 30 THEN
    passou('SetX positivo e lido de volta pelo GetX');
  ELSE
    falhou('SetX(30) e GetX devolveu ' || TO_CHAR(PL_FPDF.GetX));
  END IF;

  PL_FPDF.SetX(-40);
  -- A4 retrato tem 210 mm de largura: 210 - 40 = 170
  IF ROUND(PL_FPDF.GetX, 2) = 170 THEN
    passou('SetX(-40) poe o cursor a 40 da borda direita (170 de 210)');
  ELSE
    falhou('SetX(-40) devolveu ' || TO_CHAR(ROUND(PL_FPDF.GetX, 2))
           || ', esperado 170');
  END IF;

  --------------------------------------------------------------------------
  caso('SetY devolve o x para a margem, e o SetXY nao');
  --------------------------------------------------------------------------
  -- Esta e a surpresa do SetY, e o motivo de o SetXY existir. Quem chama
  -- SetY(100) achando que so desce perde a coluna em que estava.
  novo_doc;
  PL_FPDF.SetX(80);
  PL_FPDF.SetY(100);
  IF PL_FPDF.GetY = 100 THEN
    passou('SetY moveu o y');
  ELSE
    falhou('SetY(100) e GetY devolveu ' || TO_CHAR(PL_FPDF.GetY));
  END IF;

  IF PL_FPDF.GetX < 80 THEN
    passou('o SetY devolveu o x para a margem esquerda, como documentado');
  ELSE
    falhou('o x continuou em ' || TO_CHAR(PL_FPDF.GetX)
           || ': o SetY deixou de zerar o x, e a documentacao promete que zera');
  END IF;

  PL_FPDF.SetXY(80, 120);
  IF PL_FPDF.GetX = 80 AND PL_FPDF.GetY = 120 THEN
    passou('o SetXY respeita o x informado');
  ELSE
    falhou('SetXY(80,120) deixou x=' || TO_CHAR(PL_FPDF.GetX)
           || ' y=' || TO_CHAR(PL_FPDF.GetY));
  END IF;

  --------------------------------------------------------------------------
  caso('SetY negativo conta a partir do pe da pagina');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetY(-20);
  -- A4 retrato tem 297 mm de altura
  IF ROUND(PL_FPDF.GetY, 2) = 277 THEN
    passou('SetY(-20) poe o cursor a 20 do pe (277 de 297)');
  ELSE
    falhou('SetY(-20) devolveu ' || TO_CHAR(ROUND(PL_FPDF.GetY, 2))
           || ', esperado 277');
  END IF;

  --------------------------------------------------------------------------
  caso('PageNo acompanha as paginas');
  --------------------------------------------------------------------------
  novo_doc;
  l_n := PL_FPDF.PageNo;
  PL_FPDF.AddPage;
  PL_FPDF.AddPage;
  IF l_n = 1 AND PL_FPDF.PageNo = 3 THEN
    passou('PageNo foi de 1 a 3 com duas paginas novas');
  ELSE
    falhou('PageNo comecou em ' || TO_CHAR(l_n) || ' e terminou em '
           || TO_CHAR(PL_FPDF.PageNo) || ', esperado 1 e 3');
  END IF;

  --------------------------------------------------------------------------
  caso('GetScaleFactor converte a unidade corrente em pontos');
  --------------------------------------------------------------------------
  -- E o numero que traduz o que o chamador pede para o que o arquivo guarda.
  -- Uma polegada tem 72 pontos e 25,4 mm, entao o milimetro vale 2,8346...
  novo_doc;
  IF ROUND(PL_FPDF.GetScaleFactor, 4) = ROUND(72 / 25.4, 4) THEN
    passou('em mm o fator e 72/25,4 = '
           || TO_CHAR(ROUND(PL_FPDF.GetScaleFactor, 4)));
  ELSE
    falhou('em mm o fator veio ' || TO_CHAR(PL_FPDF.GetScaleFactor)
           || ', esperado ' || TO_CHAR(ROUND(72 / 25.4, 4)));
  END IF;

  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'pt', 'A4');
  PL_FPDF.AddPage;
  IF PL_FPDF.GetScaleFactor = 1 THEN
    passou('em pt o fator e 1, porque a unidade ja e a do arquivo');
  ELSE
    falhou('em pt o fator veio ' || TO_CHAR(PL_FPDF.GetScaleFactor));
  END IF;

  --------------------------------------------------------------------------
  caso('Margens: o Cell de largura 0 vai ate a margem direita');
  --------------------------------------------------------------------------
  -- As margens so se provam pelo efeito. Largura 0 significa "ate a margem
  -- direita", entao mexer na margem TEM de mexer onde o cursor para.
  novo_doc;
  PL_FPDF.SetMargins(20, 20, 20);
  PL_FPDF.Cell(0, 8, 'ate a margem');
  l_n := PL_FPDF.GetX;          -- 210 - 20 = 190

  novo_doc;
  PL_FPDF.SetMargins(20, 20, 60);
  PL_FPDF.Cell(0, 8, 'ate a margem');
  l_n2 := PL_FPDF.GetX;         -- 210 - 60 = 150

  IF ROUND(l_n, 2) = 190 AND ROUND(l_n2, 2) = 150 THEN
    passou('a margem direita limita a celula: 190 com margem 20, 150 com 60');
  ELSE
    falhou('celula de largura 0 parou em ' || TO_CHAR(ROUND(l_n, 2))
           || ' e ' || TO_CHAR(ROUND(l_n2, 2)) || ', esperado 190 e 150');
  END IF;

  novo_doc;
  PL_FPDF.SetLeftMargin(35);
  PL_FPDF.Ln;
  IF ROUND(PL_FPDF.GetX, 2) = 35 THEN
    passou('SetLeftMargin manda a quebra de linha para a margem nova');
  ELSE
    falhou('depois do Ln o x ficou em ' || TO_CHAR(ROUND(PL_FPDF.GetX, 2))
           || ', esperado 35');
  END IF;

  novo_doc;
  PL_FPDF.SetTopMargin(40);
  PL_FPDF.AddPage;
  IF ROUND(PL_FPDF.GetY, 2) = 40 THEN
    passou('SetTopMargin manda a pagina nova comecar na margem nova');
  ELSE
    falhou('a pagina nova comecou em y=' || TO_CHAR(ROUND(PL_FPDF.GetY, 2))
           || ', esperado 40');
  END IF;

  novo_doc;
  PL_FPDF.SetRightMargin(70);
  PL_FPDF.Cell(0, 8, 'ate a margem');
  IF ROUND(PL_FPDF.GetX, 2) = 140 THEN
    passou('SetRightMargin sozinho tambem limita a celula (140 de 210)');
  ELSE
    falhou('a celula parou em ' || TO_CHAR(ROUND(PL_FPDF.GetX, 2))
           || ', esperado 140');
  END IF;

  --------------------------------------------------------------------------
  caso('SetAutoPageBreak liga e desliga a quebra, e o AcceptPageBreak conta');
  --------------------------------------------------------------------------
  -- Desligada, o conteudo que passa do fim da pagina e escrito fora dela e
  -- SOME, sem erro nenhum. Vale saber qual e o estado.
  novo_doc;
  PL_FPDF.SetAutoPageBreak(TRUE, 20);
  IF NVL(PL_FPDF.AcceptPageBreak, FALSE) THEN
    passou('ligada, o AcceptPageBreak diz que sim');
  ELSE
    falhou('ligada, o AcceptPageBreak disse que nao');
  END IF;

  PL_FPDF.SetAutoPageBreak(FALSE);
  IF NOT NVL(PL_FPDF.AcceptPageBreak, TRUE) THEN
    passou('desligada, o AcceptPageBreak diz que nao');
  ELSE
    falhou('desligada, o AcceptPageBreak continuou dizendo que sim');
  END IF;

  -- e o efeito: com a quebra ligada, encher a pagina cria a segunda
  novo_doc;
  PL_FPDF.SetAutoPageBreak(TRUE, 20);
  FOR i IN 1 .. 40 LOOP
    PL_FPDF.Cell(0, 10, 'linha ' || i, '0', 1);
  END LOOP;
  IF PL_FPDF.PageNo > 1 THEN
    passou('a quebra automatica abriu a pagina ' || TO_CHAR(PL_FPDF.PageNo));
  ELSE
    falhou('40 linhas de 10 mm nao couberam em A4 e nenhuma pagina foi aberta');
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
