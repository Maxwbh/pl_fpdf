--------------------------------------------------------------------------------
-- PL_FPDF - Sublinhado
--
-- O `p_dounderline` não tinha um só chamador em teste nem em exemplo, e desenha
-- em TODO documento que use estilo 'U'. E o caminho em que "não levantou" prova
-- menos que em qualquer outro: o sublinhado e um retângulo preenchido, então um
-- erro de largura ou de profundidade não levanta nada -- sai um risco no lugar
-- errado, e só quem olha o PDF percebe.
--
-- Afere-se pelo operador que sai no fluxo: `x y w h re f`. O que se confere:
--
--   1. com 'U' sai o retângulo, sem 'U' não sai;
--   2. a LARGURA e a do texto, medida pela própria fonte (GetStringWidth
--      vezes o fator de escala), e não um chute;
--   3. a profundidade e NEGATIVA e menor que o corpo -- o retângulo desce da
--      linha de base, e não sobe por cima da letra;
--   4. em texto JUSTIFICADO o sublinhado acompanha o espaçamento entre
--      palavras. E o único caminho em que o `ws` e diferente de zero, e o
--      termo que o usa (`ws * número de espacos`) não existia em teste nenhum;
--   5. texto nulo não desenha sublinhado nenhum.
--
-- A comparação do caso 4 e entre DOIS documentos com a mesma largura, a mesma
-- fonte e o mesmo texto -- um justificado e outro não. Assim a primeira linha
-- quebra igual nos dois, e a diferença de largura só pode vir do `ws`. Nenhuma
-- constante privada do package entra na conta.
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
  l_pdf2   BLOB;
  l_larg   NUMBER;
  l_larg2  NUMBER;
  l_prof   NUMBER;
  l_esp    NUMBER;
  l_k      NUMBER;
  l_txt    VARCHAR2(400);
  l_frase  VARCHAR2(400) :=
    'texto longo o bastante para quebrar em mais de uma linha na coluna';

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

  -- O n-esimo número do operador `x y w h re f`, contando da esquerda.
  --
  -- Lê a janela de bytes ANTES do ' re f' e devolve o número pedido. A leitura
  -- e em RAW e a conversão e pelo UTL_RAW, que não mexe no charset: montar
  -- isso com SUBSTR sobre o BLOB traria byte do meio de caractere e não volta
  -- como ele. O separador decimal vai declarado no TO_NUMBER porque o fluxo do
  -- PDF usa ponto, e a sessão pode estar em vírgula.
  FUNCTION num_do_retangulo(p_pdf IN BLOB, p_qual IN PLS_INTEGER)
    RETURN NUMBER IS
    l_p    PLS_INTEGER;
    l_ini  PLS_INTEGER;
    l_win  VARCHAR2(400);
    l_str  VARCHAR2(60);
    l_neg  BOOLEAN;
    l_val  NUMBER;
  BEGIN
    l_p := acha(p_pdf, ' re f');
    IF l_p = 0 THEN
      RETURN NULL;
    END IF;
    l_ini := GREATEST(l_p - 80, 1);
    l_win := UTL_RAW.CAST_TO_VARCHAR2(
               DBMS_LOB.SUBSTR(p_pdf, l_p - l_ini, l_ini));
    -- Os quatro últimos números da janela são o x, o y, a largura e a
    -- profundidade, nessa ordem.
    --
    -- O digito antes do ponto e OPCIONAL, e isto custou a primeira rodada: o
    -- `tochar` do package formata com a máscara `TM9`, que NÃO escreve o zero
    -- da parte inteira. A profundidade do sublinhado, que é uma fração de
    -- ponto, sai como `-.72` -- valido no PDF, e fora de um padrão que exija
    -- digito antes do ponto. Exigindo-o, o quarto número não casava e a
    -- expressão inteira falhava, sem dizer por que.
    l_str := REGEXP_SUBSTR(
               l_win,
               '(-?[0-9]*\.?[0-9]+) +(-?[0-9]*\.?[0-9]+) +'
               || '(-?[0-9]*\.?[0-9]+) +(-?[0-9]*\.?[0-9]+)\s*$',
               1, 1, NULL, p_qual);
    IF l_str IS NULL THEN
      RETURN NULL;
    END IF;
    -- O sinal e a parte inteira vão na mão, e não por máscara: `TO_NUMBER`
    -- com máscara que declare o sinal exige que ele ESTEJA lá, e o x e a
    -- largura vem sem sinal. Tratado aqui, os dois formatos entram.
    l_neg := SUBSTR(l_str, 1, 1) = '-';
    l_str := LTRIM(l_str, '-');
    IF SUBSTR(l_str, 1, 1) = '.' THEN
      l_str := '0' || l_str;
    END IF;
    l_val := TO_NUMBER(l_str, '999999999.999999',
                       'NLS_NUMERIC_CHARACTERS=''.,''');
    RETURN CASE WHEN l_neg THEN -l_val ELSE l_val END;
  END num_do_retangulo;

  PROCEDURE novo_doc(p_estilo VARCHAR2) IS
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', p_estilo, 12);
  END novo_doc;

BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Sublinhado');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O estilo U desenha o retangulo, e sem ele nao sai nada');
  --------------------------------------------------------------------------
  -- A célula vai SEM borda e SEM preenchimento de propósito: assim o único
  -- `re f` que pode existir no fluxo e o do sublinhado.
  novo_doc('');
  PL_FPDF.Cell(80, 8, 'sem sublinhado', '0', 1, 'L');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, ' re f') = 0 THEN
    passou('sem o estilo U nao ha retangulo nenhum no fluxo');
  ELSE
    falhou('saiu um "re f" sem ninguem ter pedido sublinhado');
  END IF;

  novo_doc('U');
  PL_FPDF.Cell(80, 8, 'com sublinhado', '0', 1, 'L');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, ' re f') > 0 THEN
    passou('com o estilo U o sublinhado sai como retangulo preenchido');
  ELSE
    falhou('o estilo U nao desenhou sublinhado nenhum');
  END IF;

  --------------------------------------------------------------------------
  caso('A largura do sublinhado e a largura do texto, medida pela fonte');
  --------------------------------------------------------------------------
  l_txt := 'largura conferida';
  novo_doc('U');
  l_esp := PL_FPDF.GetStringWidth(l_txt);
  l_k   := PL_FPDF.GetScaleFactor;
  PL_FPDF.Cell(120, 8, l_txt, '0', 1, 'L');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  l_larg := num_do_retangulo(l_pdf, 3);
  IF l_larg IS NULL THEN
    falhou('nao se achou o retangulo do sublinhado no fluxo');
  ELSIF ABS(l_larg - l_esp * l_k) <= 0.5 THEN
    passou('a largura em pontos (' || TO_CHAR(ROUND(l_larg, 2))
           || ') e a do texto medida pela fonte');
  ELSE
    falhou('largura ' || TO_CHAR(ROUND(l_larg, 2)) || ' pt, esperada '
           || TO_CHAR(ROUND(l_esp * l_k, 2)) || ' pt');
  END IF;

  --------------------------------------------------------------------------
  caso('A profundidade desce da linha de base, e nao cobre a letra');
  --------------------------------------------------------------------------
  -- O quarto número e a altura do retângulo. Ela e negativa porque o
  -- sublinhado se desenha PARA BAIXO da linha de base; positiva, o risco
  -- sairia por cima do texto. E tem de ser menor que o corpo da fonte --
  -- uma altura da ordem do corpo seria uma tarja, não um sublinhado.
  IF l_larg IS NULL THEN
    pulou('sem retangulo no caso anterior, nao ha o que medir aqui');
  ELSE
    l_prof := num_do_retangulo(l_pdf, 4);
    IF l_prof IS NULL THEN
      falhou('nao se achou a altura do retangulo');
    ELSIF l_prof < 0 AND ABS(l_prof) < 12 THEN
      passou('altura ' || TO_CHAR(ROUND(l_prof, 3))
             || ' pt: desce da base, e bem menor que o corpo de 12 pt');
    ELSIF l_prof >= 0 THEN
      falhou('altura ' || TO_CHAR(ROUND(l_prof, 3))
             || ' pt: o retangulo sobe, e passaria por cima da letra');
    ELSE
      falhou('altura ' || TO_CHAR(ROUND(l_prof, 3))
             || ' pt: larga demais para um sublinhado de corpo 12');
    END IF;
  END IF;

  --------------------------------------------------------------------------
  caso('Em texto justificado o sublinhado acompanha o espacamento');
  --------------------------------------------------------------------------
  -- Dois documentos, mesma largura de coluna, mesma fonte, mesmo texto: a
  -- primeira linha quebra no mesmo ponto nos dois. No justificado o `ws`
  -- afasta as palavras, e o sublinhado tem de acompanhar -- se não
  -- acompanhasse, o risco terminaria antes da última palavra da linha.
  novo_doc('U');
  l_esp := PL_FPDF.MultiCell(60, 6, l_frase, '0', 'L');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  l_larg := num_do_retangulo(l_pdf, 3);

  novo_doc('U');
  l_esp := PL_FPDF.MultiCell(60, 6, l_frase, '0', 'J');
  l_pdf2 := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  l_larg2 := num_do_retangulo(l_pdf2, 3);

  IF l_larg IS NULL OR l_larg2 IS NULL THEN
    falhou('nao se achou o sublinhado em um dos dois documentos');
  ELSIF l_larg2 > l_larg THEN
    passou('justificado ' || TO_CHAR(ROUND(l_larg2, 2)) || ' pt contra '
           || TO_CHAR(ROUND(l_larg, 2))
           || ' pt sem justificar: o sublinhado acompanha o ws');
  ELSE
    falhou('justificado ' || TO_CHAR(ROUND(l_larg2, 2))
           || ' pt nao e maior que ' || TO_CHAR(ROUND(l_larg, 2))
           || ' pt: o termo do espacamento nao entrou na largura');
  END IF;

  --------------------------------------------------------------------------
  caso('Texto nulo nao desenha sublinhado');
  --------------------------------------------------------------------------
  -- A célula vazia existe para fechar tabela e reservar espaço, e e comum.
  -- Um sublinhado de largura zero -- ou pior, de largura indefinida -- num
  -- documento inteiro de células vazias não levanta erro nenhum.
  novo_doc('U');
  PL_FPDF.Cell(80, 8, NULL, '0', 1, 'L');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, ' re f') = 0 THEN
    passou('celula sem texto nao desenhou risco nenhum');
  ELSE
    falhou('desenhou sublinhado para texto nulo');
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
