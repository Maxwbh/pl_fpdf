--------------------------------------------------------------------------------
-- PL_FPDF - Escrita do stream de imagem (p_putstream do BLOB)
--
-- O p_putstream lia o BLOB para um buffer VARCHAR2. Com um BLOB no primeiro
-- argumento o DBMS_LOB.READ resolve para a sobrecarga cujo buffer e RAW, e a
-- conversao implicita devolve a representacao hexadecimal: 2000 bytes viravam
-- 4000 caracteres, que nao cabiam no varchar2(2000).
--
-- Ele e privado, entao os casos 1 a 3 exercitam as duas formas do laco e as duas
-- codificacoes lado a lado, sobre um BLOB controlado: medem o comportamento em
-- vez de inferi-lo de um arquivo gerado. Os casos 5 e 6 percorrem o caminho
-- completo da imagem pelo ImageFromBlob, que recebe os bytes prontos e por isso
-- nao precisa da ACL de rede que o Image() exige.
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

  -- Um BLOB de n bytes iguais.
  FUNCTION blob_de(p_bytes IN PLS_INTEGER) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_b, TRUE);
    FOR i IN 1 .. p_bytes LOOP
      DBMS_LOB.WRITEAPPEND(l_b, 1, HEXTORAW('41'));
    END LOOP;
    RETURN l_b;
  END blob_de;

  -- Escreve o texto num CLOB e converte de volta para BLOB, que e o percurso
  -- que todo stream faz: o documento e montado em CLOB e convertido no fim.
  FUNCTION ida_e_volta(p_texto IN VARCHAR2) RETURN BLOB IS
    l_c CLOB;
    l_b BLOB;
    l_in   PLS_INTEGER := 1;
    l_out  PLS_INTEGER := 1;
    l_lang PLS_INTEGER := 0;
    l_warn PLS_INTEGER := 0;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_c, TRUE);
    DBMS_LOB.WRITEAPPEND(l_c, LENGTH(p_texto), p_texto);
    DBMS_LOB.CREATETEMPORARY(l_b, TRUE);
    DBMS_LOB.CONVERTTOBLOB(l_b, l_c, DBMS_LOB.GETLENGTH(l_c), l_in, l_out,
                           DBMS_LOB.DEFAULT_CSID, l_lang, l_warn);
    DBMS_LOB.FREETEMPORARY(l_c);
    RETURN l_b;
  END ida_e_volta;

  -- Procura um texto no BLOB. Devolve 0 quando nao acha.
  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  l_blob    BLOB;
  l_buf     RAW(2000);
  l_qtd     INTEGER;
  l_pos     INTEGER;
  l_lidos   INTEGER;
  l_tam     INTEGER;
  l_origem  RAW(256);
  l_texto   VARCHAR2(4000);
  l_charset VARCHAR2(60);
  l_pdf     BLOB;
  l_hex     VARCHAR2(4000);
BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - stream de imagem');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O laco le ate o ultimo byte');
  --------------------------------------------------------------------------
  -- O teste era offset < tamanho. Quando o ultimo pedaco comeca exatamente no
  -- byte final, o laco termina sem le-lo: o stream sai um byte curto enquanto
  -- o /Length continua prometendo o total. 2001 bytes e o menor caso que
  -- mostra isso com pedaco de 2000.
  l_blob := blob_de(2001);
  l_tam  := DBMS_LOB.GETLENGTH(l_blob);

  l_lidos := 0;
  l_pos   := 1;
  WHILE l_pos < l_tam LOOP
    l_qtd := 2000;
    DBMS_LOB.READ(l_blob, l_qtd, l_pos, l_buf);
    l_lidos := l_lidos + l_qtd;
    l_pos   := l_pos + l_qtd;
  END LOOP;

  IF l_lidos < l_tam THEN
    passou('a forma antiga leu ' || l_lidos || ' de ' || l_tam || ' bytes');
  ELSE
    falhou('a forma antiga leu tudo - o defeito nao reproduziu');
  END IF;

  l_lidos := 0;
  l_pos   := 1;
  WHILE l_pos <= l_tam LOOP
    l_qtd := 2000;
    DBMS_LOB.READ(l_blob, l_qtd, l_pos, l_buf);
    l_lidos := l_lidos + l_qtd;
    l_pos   := l_pos + l_qtd;
  END LOOP;

  IF l_lidos = l_tam THEN
    passou('a forma corrigida leu os ' || l_tam || ' bytes');
  ELSE
    falhou('a forma corrigida leu ' || l_lidos || ' de ' || l_tam);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_blob);

  --------------------------------------------------------------------------
  caso('O tamanho do pedaco e IN OUT');
  --------------------------------------------------------------------------
  -- O DBMS_LOB.READ devolve no parametro de quantidade o que leu de fato. Se a
  -- variavel for inicializada uma vez so, em vez de atribuida a cada passagem,
  -- uma leitura curta vira o tamanho de todas as seguintes.
  l_blob := blob_de(500);
  l_qtd  := 2000;
  DBMS_LOB.READ(l_blob, l_qtd, 1, l_buf);

  IF l_qtd = 500 THEN
    passou('depois de leitura curta a quantidade volta 500, nao os 2000 dados');
  ELSE
    falhou('a quantidade voltou ' || l_qtd);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_blob);

  --------------------------------------------------------------------------
  caso('Por que o stream sai em hexadecimal');
  --------------------------------------------------------------------------
  -- O documento e montado como CLOB e convertido no fim, entao tudo o que se
  -- escreve nele faz um percurso de ida e volta pelo charset do banco. Este
  -- caso manda os 256 valores de byte pelos dois caminhos e compara.
  SELECT value INTO l_charset
    FROM nls_database_parameters
   WHERE parameter = 'NLS_CHARACTERSET';
  DBMS_OUTPUT.PUT_LINE('  NLS_CHARACTERSET = ' || l_charset);

  l_origem := NULL;
  FOR i IN 0 .. 255 LOOP
    l_origem := UTL_RAW.CONCAT(l_origem, HEXTORAW(TO_CHAR(i, 'FM0X')));
  END LOOP;

  l_pdf := ida_e_volta(UTL_RAW.CAST_TO_VARCHAR2(l_origem));
  DBMS_OUTPUT.PUT_LINE('  como caracteres:  256 bytes entraram, '
                       || DBMS_LOB.GETLENGTH(l_pdf) || ' sairam');
  IF DBMS_LOB.GETLENGTH(l_pdf) = 256
     AND UTL_RAW.COMPARE(DBMS_LOB.SUBSTR(l_pdf, 256, 1), l_origem) = 0 THEN
    pulou('este banco preserva byte cru no percurso - charset de um byte, '
          || 'entao o caso nao distingue as duas codificacoes');
  ELSE
    passou('byte cru nao sobrevive ao percurso, que e por que o stream nao '
           || 'e escrito assim');
  END IF;
  DBMS_LOB.FREETEMPORARY(l_pdf);

  l_texto := RAWTOHEX(l_origem);
  l_pdf   := ida_e_volta(l_texto);
  DBMS_OUTPUT.PUT_LINE('  como hexadecimal: ' || LENGTH(l_texto)
                       || ' caracteres entraram, ' || DBMS_LOB.GETLENGTH(l_pdf)
                       || ' bytes sairam');
  IF DBMS_LOB.GETLENGTH(l_pdf) = LENGTH(l_texto)
     AND UTL_RAW.COMPARE(UTL_RAW.CAST_TO_RAW(l_texto),
                         DBMS_LOB.SUBSTR(l_pdf, DBMS_LOB.GETLENGTH(l_pdf), 1)) = 0 THEN
    passou('hexadecimal atravessa o percurso intacto');
  ELSE
    falhou('hexadecimal nao sobreviveu - a premissa da codificacao nao vale aqui');
  END IF;
  DBMS_LOB.FREETEMPORARY(l_pdf);

  --------------------------------------------------------------------------
  caso('O package segue gerando documento');
  --------------------------------------------------------------------------
  -- O p_out esta no caminho de toda linha do documento, entao qualquer mexida
  -- na escrita de stream passa por aqui.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'stream', '0', 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
    passou('documento gerado, ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
  ELSE
    falhou('OutputBlob devolveu LOB vazio');
  END IF;

  --------------------------------------------------------------------------
  caso('A imagem inteira, do parser ao stream');
  --------------------------------------------------------------------------
  -- Pelo ImageFromBlob, que recebe os bytes prontos: sem HTTP, sem ACL, nada
  -- fora do schema. O PNG abaixo tem 2x2 pixels e paleta de quatro cores,
  -- indexado de proposito, porque a paleta e a parte que o percurso binario
  -- mais toca.
  l_hex := '89504E470D0A1A0A0000000D494844520000000200000002080300000045';
  l_hex := l_hex || '68FD160000000C504C5445FF000000FF000000FFFFFF00D6028F7B000000';
  l_hex := l_hex || '0E4944415478DA63606064606206000011000783CA64640000000049454E';
  l_hex := l_hex || '44AE426082';

  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.ImageFromBlob(HEXTORAW(l_hex), 'TESTE_PNG', 10, 10, 40);
  l_pdf := PL_FPDF.OutputBlob;

  IF acha(l_pdf, '/ASCIIHexDecode') > 0 THEN
    passou('o stream declara /ASCIIHexDecode');
  ELSE
    falhou('/ASCIIHexDecode ausente - o binario nao atravessaria o CLOB');
  END IF;

  IF acha(l_pdf, '/DecodeParms [') > 0 THEN
    passou('/DecodeParms saiu como vetor, acompanhando o /Filter');
  ELSE
    falhou('/DecodeParms nao e vetor - o /Predictor cairia no filtro errado');
  END IF;

  IF acha(l_pdf, '/Subtype /Image') > 0 AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
    passou('PDF com imagem gerado, ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
  ELSE
    falhou('o objeto de imagem nao foi emitido');
  END IF;

  --------------------------------------------------------------------------
  caso('Formato nao suportado e recusado, nao aceito em silencio');
  --------------------------------------------------------------------------
  -- Um SVG comeca com '<?xml' ou '<svg': nao tem assinatura binaria de PNG nem
  -- marcador SOI de JPEG. Recusar com erro proprio vale mais que gravar um
  -- objeto de imagem que nenhum leitor desenha.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.ImageFromBlob(UTL_RAW.CAST_TO_RAW('<svg xmlns="http://www.w3.org/2000/svg"/>'),
                          'TESTE_SVG', 10, 10, 40);
    falhou('o SVG foi aceito - deveria ter sido recusado');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20303') > 0
         OR INSTR(SQLERRM, 'Unsupported image format') > 0 THEN
        passou('formato nao suportado recusado com erro proprio');
      ELSE
        falhou('recusou, mas com outro erro: ' || SQLERRM);
      END IF;
  END;

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
