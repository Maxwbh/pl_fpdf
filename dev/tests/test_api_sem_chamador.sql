--------------------------------------------------------------------------------
-- PL_FPDF - APIs publicas que ninguem chamava
--
-- 48 das 119 APIs publicas nao tinham UM chamador em dev/tests/ nem em
-- examples/. Compilar nao prova nada: o AddLink compilava e levantava
-- ORA-06531 na linha da propria declaracao, em toda versao que ja existiu, e
-- so apareceu quando alguem escreveu a primeira chamada. Foram QUATRO defeitos
-- no mesmo Link, achados um a cada teste novo.
--
-- Este arquivo escreve a primeira chamada das que nao dependem de nada de fora
-- do schema. Ficam para outro dia as que exigem DIRECTORY (LoadTTFFromFile,
-- OutputFile) ou ACL de rede (Image por URL, getImageFromUrl).
--
-- O criterio de cada caso: afere o que DISTINGUE a rotina, nao que ela "roda".
-- Chamar e ver se nao levanta prova pouco -- o AddWatermark passou meses sem
-- desenhar nada e ninguem reparou.
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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - APIs publicas que ninguem chamava');
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
  caso('Fonte: corpo, familia e estilo sao lidos de volta');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetFont('Times', 'B', 14);
  IF PL_FPDF.GetCurrentFontFamily = 'Times'
     AND PL_FPDF.GetCurrentFontStyle = 'B'
     AND PL_FPDF.GetCurrentFontSize = 14 THEN
    passou('familia, estilo e corpo conferem com o que o SetFont recebeu');
  ELSE
    falhou('SetFont(Times,B,14) devolveu ' || PL_FPDF.GetCurrentFontFamily
           || '/' || PL_FPDF.GetCurrentFontStyle || '/'
           || TO_CHAR(PL_FPDF.GetCurrentFontSize));
  END IF;

  PL_FPDF.SetFontSize(9);
  IF PL_FPDF.GetCurrentFontSize = 9
     AND PL_FPDF.GetCurrentFontFamily = 'Times' THEN
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
  caso('Metadados: assunto e criador chegam ao dicionario do documento');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetSubject('Fechamento mensal');
  PL_FPDF.SetCreator('ERP - faturamento');
  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '/Subject') > 0 AND acha(l_pdf, 'Fechamento mensal') > 0 THEN
    passou('o assunto esta no dicionario');
  ELSE
    falhou('o SetSubject nao chegou ao arquivo');
  END IF;

  IF acha(l_pdf, '/Creator') > 0 AND acha(l_pdf, 'ERP - faturamento') > 0 THEN
    passou('o criador esta no dicionario');
  ELSE
    falhou('o SetCreator nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('SetDisplayMode escreve a preferencia de abertura no catalogo');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '/OpenAction') > 0 AND acha(l_pdf, '/FitH') > 0 THEN
    passou('o zoom "fullwidth" saiu como /OpenAction com /FitH');
  ELSE
    falhou('o zoom nao chegou ao catalogo');
  END IF;

  IF acha(l_pdf, '/PageLayout /OneColumn') > 0 THEN
    passou('o layout "continuous" saiu como /PageLayout /OneColumn');
  ELSE
    falhou('o layout nao chegou ao catalogo');
  END IF;

  novo_doc;
  BEGIN
    PL_FPDF.SetDisplayMode('esquisito');
    falhou('aceitou um modo de zoom que nao existe');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20100') > 0 THEN
        passou('modo de zoom desconhecido recusado com ORA-20100');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('SetCompression: o conteudo sai comprimido, e declarado');
  --------------------------------------------------------------------------
  -- Ate agosto/2026 isto era um no-op: perguntava por uma funcao de zlib que o
  -- Oracle nao tem e desligava a compressao sempre. O teste afere o efeito, e
  -- nao a chamada: o texto deixa de aparecer cru E o filtro e declarado.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetCompression(TRUE);
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);
  FOR i IN 1 .. 60 LOOP
    PL_FPDF.Cell(0, 4, 'texto repetido para comprimir bem', '0', 1);
  END LOOP;
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '/FlateDecode') > 0 THEN
    passou('o filtro de compressao esta declarado no arquivo');
  ELSE
    falhou('o SetCompression(TRUE) nao comprimiu nada');
  END IF;

  IF acha(l_pdf, 'texto repetido para comprimir bem') = 0 THEN
    passou('o texto nao aparece mais cru: o fluxo esta de fato comprimido');
  ELSE
    falhou('o texto continua legivel no arquivo, entao nada foi comprimido');
  END IF;

  --------------------------------------------------------------------------
  caso('Versao do PDF: o que se pede e o que sai no cabecalho');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetPDFVersion('1.5');
  IF PL_FPDF.GetPDFVersion = '1.5' THEN
    passou('a versao e lida de volta');
  ELSE
    falhou('SetPDFVersion(1.5) e GetPDFVersion devolveu '
           || PL_FPDF.GetPDFVersion);
  END IF;

  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, '%PDF-1.5') > 0 THEN
    passou('o cabecalho do arquivo diz 1.5');
  ELSE
    falhou('o cabecalho nao acompanhou o SetPDFVersion');
  END IF;

  --------------------------------------------------------------------------
  caso('Nivel de registro: o que se define e o que se le');
  --------------------------------------------------------------------------
  l_n := PL_FPDF.GetLogLevel;
  PL_FPDF.SetLogLevel(1);
  IF PL_FPDF.GetLogLevel = 1 THEN
    passou('o nivel e lido de volta');
  ELSE
    falhou('SetLogLevel(1) e GetLogLevel devolveu '
           || TO_CHAR(PL_FPDF.GetLogLevel));
  END IF;
  PL_FPDF.SetLogLevel(l_n);   -- devolve como estava, para nao sujar o resto

  --------------------------------------------------------------------------
  caso('SetDocumentConfig configura o documento por JSON');
  --------------------------------------------------------------------------
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  l_json := JSON_OBJECT_T();
  l_json.put('title',   'Relatorio por JSON');
  l_json.put('subject', 'Assunto por JSON');
  l_json.put('creator', 'Sistema por JSON');
  PL_FPDF.SetDocumentConfig(l_json);
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);
  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, 'Relatorio por JSON') > 0
     AND acha(l_pdf, 'Assunto por JSON') > 0
     AND acha(l_pdf, 'Sistema por JSON') > 0 THEN
    passou('titulo, assunto e criador do JSON chegaram ao arquivo');
  ELSE
    falhou('o SetDocumentConfig nao aplicou os metadados');
  END IF;

  --------------------------------------------------------------------------
  caso('GetDocumentMetadata responde sobre o documento em andamento');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetTitle('Titulo corrente');
  PL_FPDF.AddPage;
  l_json := PL_FPDF.GetDocumentMetadata;
  IF l_json.get_Number('pageCount') = 2 THEN
    passou('a contagem de paginas confere');
  ELSE
    falhou('pageCount veio ' || TO_CHAR(l_json.get_Number('pageCount'))
           || ', esperado 2');
  END IF;

  IF l_json.get_String('title') = 'Titulo corrente' THEN
    passou('o titulo confere');
  ELSE
    falhou('title veio ' || NVL(l_json.get_String('title'), 'NULL'));
  END IF;
  PL_FPDF.Reset;

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
  caso('ClosePDF fecha, e fechar de novo nao estraga');
  --------------------------------------------------------------------------
  -- As rotinas de saida ja chamam o ClosePDF. Chamar antes, a mao, nao pode
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
  -- Sao chamadas pelo proprio motor a cada pagina. Sem SetHeaderProc, a
  -- chamada tem de ser inocua -- nao levantar e nao escrever.
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
  -- E o caminho interno de erro da biblioteca, publico por heranca. Se ele
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
  caso('Fontes TrueType: cache responde sem fonte carregada');
  --------------------------------------------------------------------------
  -- Sem arquivo de fonte a mao nao da para carregar nada, mas as consultas
  -- precisam responder em vez de levantar -- e o GetTTFFontInfo precisa
  -- recusar com o erro dele.
  PL_FPDF.ClearTTFFontCache;
  IF NOT NVL(PL_FPDF.IsTTFFontLoaded('NaoExiste'), TRUE) THEN
    passou('IsTTFFontLoaded diz que nao, sem levantar');
  ELSE
    falhou('IsTTFFontLoaded disse que sim para fonte que nao existe');
  END IF;

  BEGIN
    -- o retorno vai para uma variavel: o PL/SQL nao aceita selecionar campo
    -- direto do retorno de funcao
    l_fonte := PL_FPDF.GetTTFFontInfo('NaoExiste');
    falhou('GetTTFFontInfo devolveu dados de fonte inexistente: '
           || NVL(l_fonte.font_name, 'sem nome'));
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20206') > 0 THEN
        passou('GetTTFFontInfo recusa fonte inexistente com ORA-20206');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  BEGIN
    PL_FPDF.AddTTFFont(NULL, NULL);
    falhou('AddTTFFont aceitou nome nulo');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20210') > 0 THEN
        passou('AddTTFFont recusa nome vazio com ORA-20210');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  pulou('carregar fonte de verdade exige arquivo .ttf: fica para outro teste');

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
