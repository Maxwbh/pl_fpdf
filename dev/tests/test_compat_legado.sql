--------------------------------------------------------------------------------
-- PL_FPDF - Compatibilidade com codigo escrito para a 0.9.4 e a 2.0.0
--
-- A pergunta de quem migra e sempre a mesma: o que eu ja tenho escrito continua
-- funcionando? Este arquivo responde executando, nao afirmando.
--
-- O levantamento da superficie publica das tres versoes diz o seguinte:
--
--   0.9.4:  70 publicos    2.0.0: 94    3.4.0: 119
--
--   Da 0.9.4 para a 3.4.0 sumiram SETE nomes, e os sete sao rotinas de
--   demonstracao do porte original -- helloworld, test, testImg, testheader,
--   myRepetitiveHeader, myRepetitiveFooter, lpc_footer. Nenhuma delas e API:
--   sao os exemplos que vinham dentro do package.
--
--   Da 2.0.0 para a 3.4.0 sumiram DUAS: SetUTF8Enabled e IsUTF8Enabled, que
--   nao faziam nada -- a flag era escrita e lida, e ninguem a consultava.
--
--   Das 133 assinaturas em comum, UMA mudou, e nao foi nesta versao: o
--   parametro do AddPage passou de 'orientation' para 'p_orientation' na
--   2.0.0. Chamada posicional nao sente; chamada NOMEADA quebra, e e o unico
--   ponto de atrito real da 0.9.4 para ca. O caso 4 exercita os dois.
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
  l_erro   VARCHAR2(400);

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

  PROCEDURE pulou(p_msg VARCHAR2) IS
  BEGIN
    l_skip := l_skip + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - compatibilidade com o codigo legado');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O helloworld da 0.9.4, chamada a chamada');
  --------------------------------------------------------------------------
  -- Copiado do corpo do procedure helloworld do porte de 2017, com uma unica
  -- substituicao: OutputBlob() no lugar de Output(), porque o Output escreve
  -- pelo directory PDF_DIR e schema comum nao tem um. A substituicao nao muda
  -- o que se testa -- o que interessa e a sequencia de chamadas atravessar.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    PL_FPDF.openpdf;
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 1.2, 'Hello World', 0, 1, 'C');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      passou('a sequencia de 2017 gera documento: '
             || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      falhou('OutputBlob devolveu LOB vazio');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('O construtor legado dispensa o Init');
  --------------------------------------------------------------------------
  -- Codigo de 2017 nunca chamou Init: ele nao existia. O fpdf() precisa deixar
  -- o package pronto sozinho, senao o AddPage seguinte recusa com ORA-20005.
  -- Esse foi o defeito relatado contra a 2.0.0; aqui nunca existiu, e este
  -- caso e o que impede que volte.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    IF PL_FPDF.IsInitialized THEN
      passou('fpdf() deixa o package inicializado, sem Init');
    ELSE
      falhou('fpdf() nao inicializou - o AddPage seguinte daria ORA-20005');
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('O openpdf continua aceito, e deixou de ser obrigatorio');
  --------------------------------------------------------------------------
  -- Todo exemplo antigo chama openpdf depois do construtor. Hoje o AddPage o
  -- chama sozinho quando o documento ainda nao foi aberto, mas o codigo velho
  -- nao pode quebrar por chamar duas vezes.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    PL_FPDF.openpdf;
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'com openpdf', 0, 1, 'L');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'sem openpdf', 0, 1, 'L');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    passou('os dois caminhos geram documento');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('AddPage: o unico atrito real da 0.9.4 para ca');
  --------------------------------------------------------------------------
  -- Das 133 assinaturas em comum, so esta mudou -- e na 2.0.0, nao aqui. O
  -- parametro passou de 'orientation' para 'p_orientation'.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.AddPage('L');                       -- posicional: como em 2017
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'paisagem', 0, 1, 'L');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    passou('chamada POSICIONAL do AddPage continua valendo');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('a chamada posicional quebrou: ' || SQLERRM);
  END;

  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.AddPage(p_orientation => 'L');       -- nomeada: o nome de hoje
    PL_FPDF.Reset;
    passou('chamada NOMEADA funciona com p_orientation');
    DBMS_OUTPUT.PUT_LINE('  [NOTA] codigo de 2017 que escrevia '
                         || 'AddPage(orientation => ...) precisa trocar o');
    DBMS_OUTPUT.PUT_LINE('         nome do parametro. E o unico ajuste de '
                         || 'assinatura em 133.');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('a chamada nomeada quebrou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Cabecalho e rodape por procedure, como a 0.9.4 fazia');
  --------------------------------------------------------------------------
  -- O SetHeaderProc/SetFooterProc e o mecanismo do porte original, e continua.
  -- Nao se chama a procedure aqui: confere-se que os dois pontos de entrada
  -- existem e aceitam o que aceitavam.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.SetHeaderProc('meu_cabecalho');
    PL_FPDF.SetFooterProc('meu_rodape');
    PL_FPDF.Reset;
    passou('SetHeaderProc e SetFooterProc aceitos');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('As saidas legadas: Output e ReturnBlob');
  --------------------------------------------------------------------------
  -- O ReturnBlob e da 0.9.4 e continua; o Output escreve por directory e nao
  -- se exercita aqui, porque schema comum nao tem PDF_DIR -- registrar o
  -- motivo vale mais que fingir que cobriu.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    PL_FPDF.openpdf;
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'ReturnBlob', 0, 1, 'L');
    l_pdf := PL_FPDF.ReturnBlob;
    PL_FPDF.Reset;

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      passou('ReturnBlob da 0.9.4 devolve documento: '
             || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      falhou('ReturnBlob devolveu LOB vazio');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  pulou('Output(): escreve pelo directory PDF_DIR, que schema comum nao tem');

  --------------------------------------------------------------------------
  caso('O que saiu, e por que nao quebra codigo de verdade');
  --------------------------------------------------------------------------
  -- Os sete nomes que sumiram da 0.9.4 sao rotinas de demonstracao, e o
  -- proprio package as trazia como exemplo. Quem chamava PL_FPDF.helloworld
  -- num sistema estava rodando a demo, nao a biblioteca.
  --
  -- Este caso nao tem como aferir ausencia sem nao compilar -- referencia a
  -- procedure inexistente e erro de COMPILACAO, e derrubaria o arquivo
  -- inteiro. Fica registrado, e o check_test_calls guarda o outro lado: ele
  -- acusa qualquer teste que chame nome que a spec nao declara.
  pulou('as sete rotinas de demonstracao sairam; conferir a ausencia aqui '
        || 'derrubaria a compilacao do bloco');

  --------------------------------------------------------------------------
  -- Devolve a sessao ao estado de partida.
  --
  -- O caso 4 cria pagina em PAISAGEM, e o Reset zera state e page mas NAO
  -- restaura a geometria: DefOrientation, w e h sobrevivem. Numa suite que
  -- roda tudo na mesma sessao, e este arquivo e o primeiro da ordem
  -- alfabetica, o que ficar aqui vaza para todos os testes seguintes.
  --
  -- Um Init em retrato, com o formato padrao, e a ultima coisa que este
  -- arquivo faz. Teste que suja a sessao do vizinho e pior que teste que
  -- falha: a falha aparece longe da causa.
  --------------------------------------------------------------------------
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.Reset;

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
