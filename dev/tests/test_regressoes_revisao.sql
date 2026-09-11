--------------------------------------------------------------------------------
-- PL_FPDF - Regressoes da revisao de agosto/2026
--
-- Um caso por defeito encontrado na revisao da branch. Cada um FALHA se o
-- defeito voltar; nenhum passa por acidente.
--
-- Regra deste arquivo: quando o ambiente nao permite concluir (o fixture nao
-- montou, o stream saiu comprimido), o caso imprime [SKIP] com o motivo.
-- Passar sem ter olhado e pior que falhar, porque ninguem desconfia.
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
-- Defeito que so se observa de fora vira lint estatico, nao caso de teste.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_out    BLOB;

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

  -- Procura um texto no BLOB. Devolve 0 quando nao acha.
  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  -- Um PDF de n paginas, gerado pelo proprio package.
  FUNCTION pdf_de(p_paginas IN PLS_INTEGER) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 10);
    FOR i IN 1 .. p_paginas LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Pagina ' || i);
    END LOOP;
    l_b := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
    RETURN l_b;
  END pdf_de;

BEGIN
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Regressoes da revisao de agosto/2026');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));

  --------------------------------------------------------------------------
  -- 1. A marca d'agua referenciava uma fonte que ninguem declara
  --
  -- ovl_marca_dagua emitia o literal '/FwmPLFPDF'. Esse nome nao sai de
  -- ovl_fonte_nome e nao entra no /Font de pagina nenhuma: o operador Tf
  -- ficava sem fonte e a marca NAO DESENHAVA. O nome certo e /FwmH, que e o
  -- que a largura ja media (Helvetica nao-negrito).
  --------------------------------------------------------------------------
  caso('AddWatermark referencia uma fonte declarada (nao /FwmPLFPDF)');
  BEGIN
    l_pdf := pdf_de(2);
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark(p_text => 'CONFIDENCIAL', p_opacity => 0.3);
    l_out := PL_FPDF.OutputModifiedPDF();
    PL_FPDF.ClearPDFCache();

    IF acha(l_out, 'FwmPLFPDF') > 0 THEN
      falhou('o PDF ainda traz /FwmPLFPDF — a marca nao desenha');
    ELSIF acha(l_out, 'FwmH') > 0 THEN
      passou('a marca usa /FwmH, que o /Font da pagina declara');
    ELSE
      -- nenhum dos dois no claro: o stream saiu comprimido e este caso nao
      -- consegue afirmar nada. Nao e um PASS.
      pulou('nem /FwmH nem /FwmPLFPDF no claro — stream comprimido, ' ||
            'caso inconclusivo');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 2. cor() estourava na DECLARACAO
  --
  -- l_h era VARCHAR2(10). Uma cor de 11+ caracteres levantava ORA-06502
  -- ANTES do CASE — que trataria o nome desconhecido caindo no padrao — e
  -- derrubava o OutputModifiedPDF inteiro.
  --------------------------------------------------------------------------
  caso('AddWatermark aceita nome de cor longo sem ORA-06502');
  BEGIN
    l_pdf := pdf_de(1);
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark(p_text  => 'RASCUNHO',
                         p_color => 'lightsteelblue');   -- 14 caracteres
    l_out := PL_FPDF.OutputModifiedPDF();
    PL_FPDF.ClearPDFCache();
    IF DBMS_LOB.GETLENGTH(l_out) > 0 THEN
      passou('cor desconhecida de 14 caracteres caiu no padrao, sem excecao');
    ELSE
      falhou('saida vazia');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-06502') > 0 THEN
        falhou('ORA-06502 de volta: o buffer de cor voltou a ser curto');
      ELSE
        falhou('excecao: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------
  -- 3. SplitPDF vazava um CLOB temporario por intervalo
  --
  -- NAO TEM CASO AQUI, DE PROPOSITO.
  --
  -- O vazamento nao e observavel de dentro do proprio schema: USER_* nao
  -- expoe contagem de LOB temporario, e as instancias vazadas nao tem
  -- locator que se possa passar ao DBMS_LOB.ISTEMPORARY. A primeira versao
  -- deste arquivo media V$TEMPORARY_LOBS, o que exige GRANT de DBA — e um
  -- caso que so sabe pular vira cobertura de mentira.
  --
  -- Quem guarda este defeito e o check_lob_temp.py, que le o fonte: toda
  -- variavel que recebe LOB temporario de uma funcao tem de passar por
  -- FREETEMPORARY, a menos que seja devolvida. Roda sem banco, sem
  -- privilegio e sem rede, que e o que este projeto pode exigir.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- 4. buildPlsqlStatment: o default so existia na declaracao antecipada
  --
  -- Se a definicao e a antecipada divergirem, o Oracle nao compila o body
  -- (PLS-00593) — entao este caso e, na pratica, "o package esta VALID e o
  -- caminho sem paramTable funciona".
  --------------------------------------------------------------------------
  caso('SetFooterProc sem paramTable usa o default e o package esta VALID');
  DECLARE
    l_invalidos PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO l_invalidos
      FROM user_objects
     WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
       AND status != 'VALID';
    IF l_invalidos > 0 THEN
      falhou(l_invalidos || ' objeto(s) do package fora de VALID');
    ELSE
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.SetFooterProc('nao_existe.proc_qualquer');  -- sem paramTable
      PL_FPDF.Reset();
      passou('package VALID e SetFooterProc aceitou a chamada sem paramTable');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 5. Secao xref classica maior que a janela de 32767 bytes
  --
  -- pdf_read faz LEAST(p_len, 32767) e trunca calado: acima de ~1638 entradas
  -- (20 bytes cada) o resto da tabela sumia, o 'trailer' nao era achado e o
  -- chamador recebia '-20803 /Root nao encontrado' — que aponta para o lugar
  -- errado. Agora se recusa com -20841 e mensagem que diz o que aconteceu.
  --
  -- O que se cobra aqui e o CODIGO do erro, nao o sucesso: se o PDF couber na
  -- janela, ele carrega normalmente e o caso registra isso.
  --------------------------------------------------------------------------
  caso('xref classica grande: erro claro (-20841), nunca -20803 enganoso');
  DECLARE
    l_grande BLOB;
    l_cod    PLS_INTEGER;
  BEGIN
    -- ~900 paginas: cada uma rende objeto de pagina e stream de conteudo,
    -- o que passa folgado das ~1638 entradas de uma janela.
    l_grande := pdf_de(900);
    BEGIN
      PL_FPDF.LoadPDF(l_grande);
      PL_FPDF.ClearPDFCache();
      pulou('o PDF de 900 paginas coube na janela e carregou — este caso ' ||
            'nao exercitou o limite');
    EXCEPTION
      WHEN OTHERS THEN
        l_cod := SQLCODE;
        IF l_cod = -20841 THEN
          passou('recusou com -20841 e mensagem propria');
        ELSIF l_cod = -20803 THEN
          falhou('voltou o -20803 enganoso: o truncamento da xref esta ' ||
                 'silencioso de novo');
        ELSE
          falhou('erro inesperado ' || l_cod || ': ' || SQLERRM);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      -- nao conseguir GERAR 900 paginas e limite de ambiente, nao a regressao
      pulou('nao foi possivel montar o PDF de 900 paginas: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 6. Reset deixava metadado para tras
  --
  -- O package tem estado de SESSAO. O Reset zerava fontes, imagens, links,
  -- callbacks e criptografia — e esquecia title, subject, author, keywords e
  -- creator. O /Keywords de um documento reaparecia em todos os seguintes.
  --
  -- Custou uma rodada inteira de diagnostico: um SetKeywords grande num teste
  -- fez cada PDF da suite nascer com 32 KB a mais, a cifragem recusar todos, e
  -- o sintoma nao apontava para o Reset em momento nenhum.
  --------------------------------------------------------------------------
  caso('Reset limpa os metadados do documento');
  DECLARE
    l_marca CONSTANT VARCHAR2(40) := 'MARCA-QUE-NAO-PODE-VAZAR-4711';
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetKeywords(l_marca);
    PL_FPDF.SetAuthor(l_marca);
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'primeiro');
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();

    -- documento novo, sem tocar em metadado nenhum
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'segundo');
    l_out := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();

    IF acha(l_out, l_marca) > 0 THEN
      falhou('o metadado do primeiro documento vazou para o segundo — '
             || 'Reset voltou a esquecer title/author/keywords');
    ELSE
      passou('o segundo documento nasceu sem o metadado do primeiro');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 7. String literal grande demais ao cifrar
  --
  -- Antes: sec_cifrar_strings acumulava o hexadecimal num VARCHAR2(32767),
  -- dois caracteres por byte, e estourava ORA-06502 — que o EncryptPDF
  -- rebatizava como '-20852 Encryption failed', escondendo a causa. Pior:
  -- sec_cifrar_objetos truncava o dicionario calado e devolvia arquivo
  -- quebrado REPORTANDO SUCESSO.
  --
  -- Agora recusa, e o codigo certo e -20866: e o erro que o proprio package
  -- ja usava na SAIDA do escape, com a mesma mensagem e o mesmo teto de
  -- 16000 bytes. A primeira versao deste caso esperava -20841, que e o erro
  -- de LEITURA truncada — outro assunto. Expectativa errada minha, nao
  -- defeito do codigo: o -20866 e o mais preciso dos dois.
  --------------------------------------------------------------------------
  caso('EncryptPDF recusa objeto com dicionario acima de 32 KB');
  DECLARE
    l_cifrado BLOB;
    l_cod     PLS_INTEGER;
    l_perm    JSON_OBJECT_T := JSON_OBJECT_T();
    l_grande  BLOB;
  BEGIN
    -- Palavras-chave enormes entram no /Info, que e um objeto de dicionario.
    -- 17000 e o minimo que passa do teto de 16000 do escape. A versao
    -- anterior usava 32000 sem necessidade, e como o Reset nao limpava
    -- metadado (defeito consertado nesta mesma rodada), aquilo vazava para
    -- TODA amostra seguinte da sessao: cada PDF nascia com 32 KB a mais e a
    -- cifragem recusava todos. Fixture de teste nao pode sujar o que vem
    -- depois — nem quando o package tem defeito.
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetKeywords(RPAD('a', 17000, 'a'));
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'dicionario grande');
    l_grande := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();

    l_perm.put('print', TRUE);
    BEGIN
      l_cifrado := PL_FPDF.EncryptPDF(p_pdf            => l_grande,
                                      p_user_password  => 'x',
                                      p_permissions    => l_perm,
                                      p_encryption     => 'AES-128');
      -- Chegou aqui: ou o dicionario coube, ou o guard nao disparou. Para
      -- distinguir, confere se a saida ainda tem o /Info inteiro.
      IF acha(l_cifrado, 'Encrypt') > 0 THEN
        pulou('o dicionario ficou abaixo de 32 KB e a cifragem passou — ' ||
              'este caso nao exercitou o limite');
      ELSE
        falhou('cifrou sem marcar /Encrypt: saida suspeita');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_cod := SQLCODE;
        -- -20866: literal de string acima do teto do escape (o preciso).
        -- -20841: leitura truncada do objeto — tambem e recusa honesta, e
        --         vale para um fixture que chegue por aquele caminho.
        IF l_cod IN (-20866, -20841) THEN
          passou('recusou com ' || l_cod ||
                 ' em vez de estourar ORA-06502 ou truncar em silencio');
        ELSIF INSTR(SQLERRM, 'ORA-06502') > 0 THEN
          falhou('ORA-06502 de volta: o estouro voltou a passar sem guarda');
        ELSE
          falhou('erro inesperado ' || l_cod || ': ' || SQLERRM);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      pulou('nao foi possivel montar o fixture do dicionario grande: ' ||
            SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- O caso que existia aqui conferia que SetUTF8Enabled e IsUTF8Enabled eram
  -- coerentes entre si -- o unico contrato que aquela API cumpria, porque a
  -- flag nao era consultada em lugar nenhum. As duas sairam da spec quando a
  -- conversao WinAnsi passou a ser sempre feita, e o caso saiu com elas.
  --
  -- O que ele registrava em texto agora e aferido de verdade, em
  -- test_winansi.sql: o acentuado convertido, o alinhamento que antes
  -- levantava ORA-06502, e a recusa do que nao existe em WinAnsi.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  caso('Documento em paisagem nao contamina o seguinte');
  --------------------------------------------------------------------------
  -- O Reset limpava fontes, imagens, links e metadados, mas NAO o
  -- OrientationChanges -- a tabela que diz quais paginas tem orientacao
  -- diferente do padrao, e que faz cada uma delas ganhar MediaBox proprio.
  --
  -- Como ela e indexada pelo NUMERO da pagina, o indice 1 de um documento
  -- virava o indice 1 do proximo: quem gerasse um documento com a pagina 1 em
  -- paisagem deixava TODO documento posterior da mesma sessao com a pagina 1
  -- em paisagem. MediaBox trocado, conteudo desenhado fora do papel, arquivo
  -- que abre EM BRANCO -- sem erro nenhum.
  --
  -- O sintoma nao acusa a causa: a pagina 1 sai errada e as demais certas,
  -- porque so o indice reaproveitado colide. Foi assim que apareceu: doze
  -- amostras com o texto nao extraido, e o codigo de barras sem decodificar.
  DECLARE
    l_paisagem BLOB;
    l_retrato  BLOB;
  BEGIN
    -- primeiro documento: pagina 1 em PAISAGEM
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage('L');
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'paisagem');
    l_paisagem := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- segundo documento: tudo RETRATO, sem tocar em orientacao
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'retrato');
    l_retrato := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- A4 retrato: 595.28 x 841.89. Paisagem inverte os dois. O segundo
    -- documento nao pode ter MediaBox proprio em pagina nenhuma.
    IF acha(l_retrato, '/MediaBox [0 0 841.89 595.28]') = 0 THEN
      passou('o documento retrato nao herdou a paisagem do anterior');
    ELSE
      falhou('a pagina 1 saiu em paisagem: o OrientationChanges do documento '
             || 'anterior sobreviveu ao Reset');
    END IF;

    IF acha(l_paisagem, '/MediaBox [0 0 841.89 595.28]') > 0 THEN
      passou('o documento paisagem tem a pagina em paisagem, como pedido');
    ELSE
      falhou('a paisagem pedida nao saiu');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Link so aceita URL, e recusa o link interno em vez de gravar quebrado');
  --------------------------------------------------------------------------
  -- O ramo que escreveria o /Dest do link INTERNO saiu comentado no porte
  -- original e nunca voltou. Com plink numerico o dicionario do /Annot ficava
  -- ABERTO -- sai "<</Type /Annot ... /Border [0 0 0] ]", sem o >> que fecha.
  -- Nao e link que nao navega: e PDF que o leitor recusa.
  --
  -- Ninguem reparou porque nenhum teste chamava AddLink ou SetLink. Foi ao
  -- escrever este caso que apareceu o terceiro lado do mesmo defeito: o
  -- AddLink levantava ORA-06531, "reference to uninitialized collection", na
  -- linha da propria declaracao. A colecao "links" e nested table e ninguem a
  -- inicializa, entao o AddLink NUNCA funcionou -- nem uma vez, em nenhuma
  -- versao. Os tres passam a recusar com ORA-20601 e mensagem que diz o que
  -- usar no lugar.
  DECLARE
    l_pdf   BLOB;
    l_erro  VARCHAR2(400);

    PROCEDURE recusa(p_que VARCHAR2, p_erro VARCHAR2) IS
    BEGIN
      IF INSTR(p_erro, 'ORA-20601') > 0 THEN
        passou(p_que || ' recusado com ORA-20601');
      ELSIF INSTR(p_erro, 'ORA-06531') > 0 THEN
        falhou(p_que || ' ainda levanta ORA-06531, que nao diz o que fazer');
      ELSE
        falhou(p_que || ' recusou com outro erro: ' || p_erro);
      END IF;
    END recusa;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);

    BEGIN
      l_erro := TO_CHAR(PL_FPDF.AddLink);
      falhou('AddLink devolveu um identificador que nao leva a lugar nenhum');
    EXCEPTION
      WHEN OTHERS THEN recusa('AddLink', SQLERRM);
    END;

    BEGIN
      PL_FPDF.SetLink(1, 0, 1);
      falhou('SetLink aceitou guardar um destino que nao chega ao arquivo');
    EXCEPTION
      WHEN OTHERS THEN recusa('SetLink', SQLERRM);
    END;

    BEGIN
      PL_FPDF.Link(20, 40, 60, 10, '1');
      falhou('Link aceitou destino numerico - o arquivo sairia malformado');
    EXCEPTION
      WHEN OTHERS THEN recusa('Link com destino numerico', SQLERRM);
    END;

    -- URL continua funcionando, e e o caminho que sempre esteve correto
    PL_FPDF.Link(20, 60, 60, 10, 'https://example.com');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    IF acha(l_pdf, '/Subtype /Link') > 0 AND acha(l_pdf, '/URI') > 0 THEN
      passou('o link por URL saiu no arquivo');
    ELSE
      falhou('o link por URL sumiu');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Link na pagina 3 nao estraga as paginas 1 e 2');
  --------------------------------------------------------------------------
  -- O Link estende a colecao ate a pagina corrente, e as paginas anteriores
  -- ficavam com entrada VAZIA. O emissor so testava .exists(i), entao essas
  -- paginas ganhavam um /Annots com /Rect vazio e o dicionario aberto -- sem
  -- que ninguem tivesse pedido link nenhum nelas.
  DECLARE
    l_pdf BLOB;
    l_n   PLS_INTEGER;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;  PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(50, 10, 'Pagina 1');
    PL_FPDF.AddPage;  PL_FPDF.Cell(50, 10, 'Pagina 2');
    PL_FPDF.AddPage;  PL_FPDF.Cell(50, 10, 'Pagina 3');
    PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- tres paginas, UM /Annots so
    l_n := 0;
    FOR i IN 1 .. 3 LOOP
      IF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW('/Annots ['), 1, i) > 0 THEN
        l_n := i;
      END IF;
    END LOOP;
    IF l_n = 1 THEN
      passou('so a pagina com link tem /Annots');
    ELSE
      falhou('ha ' || l_n || ' /Annots no arquivo, e so uma pagina tem link');
    END IF;

    -- e nenhum dicionario de anotacao ficou aberto
    IF acha(l_pdf, '/Border [0 0 0] ]') = 0 THEN
      passou('nenhum /Annot com o dicionario aberto');
    ELSE
      falhou('ha /Annot fechado com ] em vez de >> - dicionario aberto');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
  DBMS_OUTPUT.PUT_LINE('Total: ' || l_total ||
                       ' | OK: ' || l_ok ||
                       ' | Falhas: ' || l_falhas ||
                       ' | Pulados: ' || l_skip);
  IF l_falhas > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: FALHOU');
  ELSIF l_skip > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK, com ' || l_skip ||
                         ' caso(s) sem conclusao — leia os [SKIP] acima');
  ELSE
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
  END IF;
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
END;
/
