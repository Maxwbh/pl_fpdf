--------------------------------------------------------------------------------
-- PL_FPDF - Medicao: chave da tabela de larguras e conversao WinAnsi
--
-- DIAGNOSTICO, nao conserto. Este arquivo existe para responder uma pergunta
-- antes de qualquer linha ser mudada, porque a resposta muda o tamanho do
-- trabalho.
--
-- O dicionario da fonte declara /Encoding /WinAnsiEncoding, e nao existe
-- conversao correspondente: o texto sai do banco em AL32UTF8 e entra cru no
-- stream. Cada acentuado vira dois glifos. Isso ja esta estabelecido.
--
-- O que NAO esta estabelecido, e e o que se mede aqui, e o estado da tabela de
-- larguras. Ela e construida com
--
--     mySet(chr(i)) := ...   para i de 0 a 255
--
-- e consultada com
--
--     charSetWidth(substr(pstr, i, 1))
--
-- A chave e um caractere, e as duas pontas podem discordar em AL32UTF8: o
-- CHR(231) e uma coisa, o 'c' cedilha tirado de um texto UTF-8 e outra. Se
-- discordarem, GetStringWidth erra a largura de todo acentuado -- e
-- alinhamento, centralizacao, MultiCell e quebra de linha erram junto, o que e
-- um problema maior e diferente do da conversao de saida.
--
-- Cada caso IMPRIME o que mediu. Nao ha [FAIL] aqui de proposito: medicao que
-- reprova antes de existir criterio vira ruido, e a decisao e de quem le.
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_charset  VARCHAR2(60);
  l_um_byte  PLS_INTEGER := 0;
  l_dois     PLS_INTEGER := 0;
  l_outros   PLS_INTEGER := 0;
  l_distintas PLS_INTEGER;
  l_larg     NUMBER;
  l_larg_ced NUMBER;
  l_ced_chr  VARCHAR2(10);
  l_ced_txt  VARCHAR2(10);
  l_erro     VARCHAR2(400);

  -- O runner so imprime a saida de um teste que passou quando recebe -v.
  -- Aqui a saida E o resultado -- o arquivo mede, nao afere --, entao cada
  -- linha vai marcada com '***', que o runner imprime sempre. Sem isso o
  -- diagnostico rodava, passava, e nao dizia nada a ninguem.
  PROCEDURE diz(p_msg VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('*** ' || p_msg);
  END;
BEGIN
  diz('PL_FPDF - medicao WinAnsi');
  diz(RPAD('=', 70, '='));

  SELECT value INTO l_charset
    FROM nls_database_parameters
   WHERE parameter = 'NLS_CHARACTERSET';
  diz('NLS_CHARACTERSET = ' || l_charset);
  diz('');

  ------------------------------------------------------------------------
  diz('1. Quantos bytes tem CHR(i) de 128 a 255');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- Se CHR(i) devolver UM byte, a chave e o byte cru -- que nao e UTF-8
  -- valido sozinho, e nao vai casar com caractere nenhum tirado de um texto.
  -- Se devolver DOIS, a chave e o caractere do ponto de codigo i, que casa com
  -- texto mas nao com byte.
  FOR i IN 128 .. 255 LOOP
    CASE LENGTHB(CHR(i))
      WHEN 1 THEN l_um_byte := l_um_byte + 1;
      WHEN 2 THEN l_dois := l_dois + 1;
      ELSE l_outros := l_outros + 1;
    END CASE;
  END LOOP;
  diz('um byte: ' || l_um_byte || ' | dois bytes: ' || l_dois
      || ' | outros: ' || l_outros || '   (de 128 posicoes)');
  diz('');

  ------------------------------------------------------------------------
  diz('2. As 256 chaves CHR(i) sao distintas entre si?');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- Chave repetida significa posicao de largura perdida: a segunda sobrescreve
  -- a primeira, e as duas passam a devolver a mesma largura.
  SELECT COUNT(DISTINCT CHR(LEVEL - 1)) INTO l_distintas
    FROM dual CONNECT BY LEVEL <= 256;
  diz('chaves distintas: ' || l_distintas || ' de 256');
  IF l_distintas < 256 THEN
    diz('-> ' || (256 - l_distintas) || ' posicao(oes) colidem: a tabela de '
        || 'larguras tem menos entradas do que aparenta');
  END IF;
  diz('');

  ------------------------------------------------------------------------
  diz('3. A chave da tabela casa com o texto consultado?');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- A tabela e montada com CHR(231); a consulta usa SUBSTR de um texto. Se os
  -- dois nao forem iguais, a consulta nao acha a chave.
  l_ced_chr := CHR(231);
  l_ced_txt := SUBSTR('ç', 1, 1);
  diz('CHR(231):          ' || LENGTHB(l_ced_chr) || ' byte(s), hex '
      || RAWTOHEX(UTL_RAW.CAST_TO_RAW(l_ced_chr)));
  diz('SUBSTR(''ç'',1,1):   ' || LENGTHB(l_ced_txt) || ' byte(s), hex '
      || RAWTOHEX(UTL_RAW.CAST_TO_RAW(l_ced_txt)));
  IF l_ced_chr = l_ced_txt THEN
    diz('-> iguais: a consulta acha a chave, e a largura sai certa');
  ELSE
    diz('-> DIFERENTES: a consulta nao acha a chave da tabela');
  END IF;
  diz('');

  ------------------------------------------------------------------------
  diz('4. O que GetStringWidth devolve, na pratica');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- O .exists da consulta esta comentado no codigo, entao chave ausente sobe
  -- como NO_DATA_FOUND -- que e outro sintoma, e mais barulhento, do que o
  -- relato descreve. Medir qual dos dois acontece.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);

  BEGIN
    l_larg := PL_FPDF.GetStringWidth('Sao Paulo');
    diz('largura de ''Sao Paulo''  (sem acento): ' || TO_CHAR(l_larg));
  EXCEPTION
    WHEN OTHERS THEN
      diz('largura de ''Sao Paulo''  levantou: ' || SQLERRM);
  END;

  BEGIN
    l_larg_ced := PL_FPDF.GetStringWidth('São Paulo');
    diz('largura de ''São Paulo'' (com acento): ' || TO_CHAR(l_larg_ced));
    IF l_larg_ced = l_larg THEN
      diz('-> as duas medem igual, e nao deveriam: o ã e mais largo que o a');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_erro := SQLERRM;
      diz('largura de ''São Paulo'' levantou: ' || l_erro);
      IF INSTR(l_erro, 'ORA-01403') > 0 OR INSTR(l_erro, 'NO_DATA') > 0 THEN
        diz('-> NO_DATA_FOUND: a chave nao existe na tabela, e o .exists '
            || 'comentado no codigo deixa a excecao subir');
      END IF;
  END;
  diz('');

  ------------------------------------------------------------------------
  diz('5. O acentuado no stream do documento');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- Confirma o relato pelo lado do arquivo: os bytes do 'ç' chegam crus, em
  -- UTF-8, num stream declarado como WinAnsi.
  DECLARE
    l_pdf BLOB;
    l_utf RAW(2)  := HEXTORAW('C3A7');   -- 'ç' em UTF-8
    l_win RAW(1)  := HEXTORAW('E7');     -- 'ç' em cp1252
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(100, 10, 'cobrança');
    l_pdf := PL_FPDF.OutputBlob;

    diz('PDF gerado: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    diz('bytes C3 A7 (UTF-8) no arquivo:  '
        || CASE WHEN DBMS_LOB.INSTR(l_pdf, l_utf, 1, 1) > 0
                THEN 'SIM -- texto cru, e o defeito relatado'
                ELSE 'nao' END);
    diz('byte  E7    (cp1252) no arquivo: '
        || CASE WHEN DBMS_LOB.INSTR(l_pdf, l_win, 1, 1) > 0
                THEN 'SIM -- ja convertido'
                ELSE 'nao' END);
    diz('/WinAnsiEncoding declarado:      '
        || CASE WHEN DBMS_LOB.INSTR(l_pdf,
                       UTL_RAW.CAST_TO_RAW('/WinAnsiEncoding'), 1, 1) > 0
                THEN 'SIM' ELSE 'nao' END);
  EXCEPTION
    WHEN OTHERS THEN
      diz('geracao levantou: ' || SQLERRM);
  END;

  diz('');
  diz(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('[PASS] medicao concluida - a decisao esta na saida acima');
  PL_FPDF.Reset;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('[FAIL] a medicao nao concluiu: ' || SQLERRM);
    RAISE;
END;
/
