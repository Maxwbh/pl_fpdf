--------------------------------------------------------------------------------
-- PL_FPDF - Metadados, preferencias de exibicao e configuracao
--
-- O que o documento diz sobre si mesmo, e o que o leitor recebe como
-- preferencia de abertura.
--
-- Tudo aqui se afere no BLOB gerado, e nao no retorno da chamada: um
-- SetSubject que nao chega ao dicionario nao levanta erro nenhum, e so
-- aparece quando alguem procura o assunto do arquivo e nao acha.
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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Metadados, preferencias de exibicao e configuracao');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

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
