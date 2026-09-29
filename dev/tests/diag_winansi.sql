--------------------------------------------------------------------------------
-- PL_FPDF - Medicao: chave da tabela de larguras e conversao WinAnsi
--
-- DIAGNOSTICO, nao conserto. Este arquivo nasceu para responder uma pergunta
-- antes de qualquer linha ser mudada, porque a resposta mudava o tamanho do
-- trabalho. A pergunta era: a tabela de larguras era montada com
--
--     mySet(chr(i)) := ...   para i de 0 a 255
--
-- e consultada com
--
--     charSetWidth(substr(pstr, i, 1))
--
-- ou seja, chave de um lado e caractere do outro. Em AL32UTF8 as duas pontas
-- discordam: CHR(231) e um byte, o cedilha tirado de um texto sao dois.
--
-- AS DUAS PONTAS FORAM CONSERTADAS DESDE ENTAO. A tabela passou a ser indexada
-- pelo BYTE WinAnsi e quem mede converte com p_winansi_byte antes de consultar
-- -- GetStringWidth, MultiCell, Write e o overlay. A saida tambem: o acentuado
-- sai como escape octal, e nao como UTF-8 cru num stream declarado WinAnsi.
--
-- O arquivo continua rodando porque a MEDICAO continua util: ela diz, em cada
-- instancia, o que CHR(i) devolve e se ele casa com o caractere. E dessa
-- resposta que dependem as duas decisoes de projeto acima, e ela muda de banco
-- para banco. O que mudou foram as CONCLUSOES impressas, que descreviam um
-- estado que nao existe mais. Quem guarda o comportamento agora e o
-- test_winansi.sql, com [FAIL] de verdade.
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
  -- Era assim que a tabela e a consulta se encontravam: a tabela montada com
  -- CHR(231) e a consulta com o SUBSTR de um texto. A medicao continua valendo
  -- como PROVA de que os dois nunca foram a mesma coisa em AL32UTF8 -- mas o
  -- package nao depende mais disso: a tabela e indexada pelo BYTE WinAnsi e
  -- quem consulta converte com p_winansi_byte antes de medir.
  l_ced_chr := CHR(231);
  l_ced_txt := SUBSTR('ç', 1, 1);
  diz('CHR(231):          ' || LENGTHB(l_ced_chr) || ' byte(s), hex '
      || RAWTOHEX(UTL_RAW.CAST_TO_RAW(l_ced_chr)));
  diz('SUBSTR(''ç'',1,1):   ' || LENGTHB(l_ced_txt) || ' byte(s), hex '
      || RAWTOHEX(UTL_RAW.CAST_TO_RAW(l_ced_txt)));
  IF l_ced_chr = l_ced_txt THEN
    diz('-> iguais: neste banco as duas formas coincidem');
  ELSE
    diz('-> DIFERENTES, e por isso a chave da tabela deixou de ser o');
    diz('   caractere: hoje ela e o byte WinAnsi, e a consulta converte');
    diz('   antes de medir. Consultar com o caractere cru era o defeito.');
  END IF;
  diz('');

  ------------------------------------------------------------------------
  diz('4. O que GetStringWidth devolve, na pratica');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- Media-se aqui qual sintoma acontecia: ORA-06502 na variavel de um byte ou
  -- NO_DATA_FOUND na chave ausente. Hoje o GetStringWidth converte o caractere
  -- para byte WinAnsi e trata a chave ausente, entao o que se mede e o VALOR.
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
      diz('-> as duas medem igual, e e o esperado: em Helvetica o ã tem a');
      diz('   largura de avanco do a (556 nos dois), conferido no AFM. Medir');
      diz('   MENOS e que seria defeito -- seria a chave nao encontrada');
      diz('   valendo zero.');
    ELSIF l_larg_ced < l_larg THEN
      diz('-> a acentuada mede MENOS: a consulta nao achou a chave e caiu');
      diz('   no zero. E o defeito que o test_winansi.sql guarda.');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_erro := SQLERRM;
      diz('largura de ''São Paulo'' levantou: ' || l_erro);
      IF INSTR(l_erro, 'ORA-01403') > 0 OR INSTR(l_erro, 'NO_DATA') > 0 THEN
        diz('-> NO_DATA_FOUND: a chave nao existe na tabela. Era o sintoma '
            || 'de antes; hoje o GetStringWidth trata a chave ausente');
      END IF;
  END;
  diz('');

  ------------------------------------------------------------------------
  diz('5. O acentuado no stream do documento');
  diz(RPAD('-', 70, '-'));
  ------------------------------------------------------------------------
  -- O relato original era este: os bytes do 'ç' chegavam crus, em UTF-8, num
  -- stream declarado como WinAnsi. As DUAS respostas abaixo sao 'nao' hoje, e
  -- isso nao e inconclusivo: o acentuado nao sai como byte nenhum, sai como
  -- escape octal de tres digitos, que e ASCII e atravessa o CONVERTTOBLOB. A
  -- terceira linha mede justamente isso.
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
                THEN 'SIM -- texto cru, que era o defeito relatado'
                ELSE 'nao' END);
    diz('byte  E7    (cp1252) no arquivo: '
        || CASE WHEN DBMS_LOB.INSTR(l_pdf, l_win, 1, 1) > 0
                THEN 'SIM -- ja convertido'
                ELSE 'nao' END);
    diz('escape octal \347 no arquivo:    '
        || CASE WHEN DBMS_LOB.INSTR(l_pdf,
                       UTL_RAW.CAST_TO_RAW('\347'), 1, 1) > 0
                THEN 'SIM -- convertido, e o que se espera'
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
