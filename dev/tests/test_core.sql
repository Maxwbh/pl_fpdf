--------------------------------------------------------------------------------
-- PL_FPDF - Núcleo: páginas grandes, alias {nb} e independência de NLS
--
-- Regressão para o limite de 32 KB por página: antes do buffer de página em CLOB,
-- uma página com muitas células estourava ORA-06502 em p_out.
--------------------------------------------------------------------------------

DECLARE
  l_pdf         BLOB;
  l_test_count  PLS_INTEGER := 0;
  l_pass_count  PLS_INTEGER := 0;
  l_fail_count  PLS_INTEGER := 0;

  PROCEDURE test_start(p_test_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test ' || l_test_count || ': ' || p_test_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
  END;

  PROCEDURE test_pass(p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || NVL(p_message, 'Test passed'));
  END;

  PROCEDURE test_fail(p_message VARCHAR2) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_message);
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================');
  DBMS_OUTPUT.PUT_LINE('  PL_FPDF - Núcleo');
  DBMS_OUTPUT.PUT_LINE('================================================================');

  --------------------------------------------------------------------------
  test_start('Página única com 3.000 células (muito acima de 32 KB)');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);

    -- Cada célula emite ~100 bytes de instruções PDF: ~300 KB numa página só.
    FOR i IN 1 .. 3000 LOOP
      PL_FPDF.Cell(20, 4, 'L' || i, '1', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 32767 THEN
      test_pass('PDF gerado com ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      test_fail('PDF vazio ou truncado: ' || NVL(DBMS_LOB.GETLENGTH(l_pdf), 0) || ' bytes');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- ORA-06502 aqui significa que o teto de 32 KB por página voltou
      test_fail('Exceção ao gerar página grande: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Múltiplas páginas grandes mantêm o conteúdo separado');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 8);

    FOR pg IN 1 .. 3 LOOP
      PL_FPDF.AddPage();
      FOR i IN 1 .. 800 LOOP
        PL_FPDF.Cell(20, 4, 'P' || pg || '-' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
      END LOOP;
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 32767 THEN
      test_pass('3 páginas grandes geradas: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      test_fail('PDF vazio ou truncado');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção com múltiplas páginas grandes: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Alias {nb} substituído em página que ultrapassa 32 KB');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetAliasNbPages();          -- habilita '{nb}'
    PL_FPDF.SetFont('Arial', '', 8);
    PL_FPDF.AddPage();

    -- Enche a página e só então escreve o alias, garantindo que ele caia
    -- além do primeiro bloco de 32 KB do buffer.
    FOR i IN 1 .. 1200 LOOP
      PL_FPDF.Cell(20, 4, 'X' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Cell(0, 6, 'Total de paginas: {nb}', '0', 1);
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 6, 'Pagina 2 de {nb}', '0', 1);

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NULL OR DBMS_LOB.GETLENGTH(l_pdf) = 0 THEN
      test_fail('PDF vazio');
    ELSIF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW('{nb}')) > 0 THEN
      test_fail('Alias {nb} não foi substituído além do primeiro bloco');
    ELSE
      test_pass('Alias substituído corretamente em página grande');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção no teste de alias: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Reset libera recursos e permite novo documento');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    FOR i IN 1 .. 500 LOOP
      PL_FPDF.Cell(20, 4, 'A' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.Cell(0, 10, 'Documento novo apos Reset', '0', 1);
    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      test_pass('Segundo documento gerado após Reset');
    ELSE
      test_fail('Falha ao gerar documento após Reset');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção após Reset: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Geração funciona com NLS decimal vírgula e não altera a sessão');
  --------------------------------------------------------------------------
  DECLARE
    l_nls_antes  VARCHAR2(64);
    l_nls_depois VARCHAR2(64);
  BEGIN
    -- Simula uma sessão pt-BR: vírgula como separador decimal
    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '',.''';

    SELECT value INTO l_nls_antes
      FROM nls_session_parameters
     WHERE parameter = 'NLS_NUMERIC_CHARACTERS';

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.SetXY(12.5, 20.75);                      -- coordenadas com decimais
    PL_FPDF.Cell(80.5, 8.25, 'Coordenadas decimais', '1', 1);
    PL_FPDF.Line(10.5, 40.25, 100.75, 40.25);
    l_pdf := PL_FPDF.OutputBlob();

    SELECT value INTO l_nls_depois
      FROM nls_session_parameters
     WHERE parameter = 'NLS_NUMERIC_CHARACTERS';

    IF l_pdf IS NULL OR DBMS_LOB.GETLENGTH(l_pdf) = 0 THEN
      test_fail('PDF não gerado com NLS vírgula');
    ELSIF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(',25')) > 0
       OR DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(',75')) > 0 THEN
      test_fail('Vírgula vazou como separador decimal no conteúdo do PDF');
    ELSIF l_nls_depois != l_nls_antes THEN
      test_fail('A biblioteca alterou NLS_NUMERIC_CHARACTERS da sessão: ' ||
                l_nls_antes || ' -> ' || l_nls_depois);
    ELSE
      test_pass('PDF correto e sessão preservada (' || l_nls_depois || ')');
    END IF;

    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''.,''';
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção com NLS vírgula: ' || SQLERRM);
      EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''.,''';
  END;

  --------------------------------------------------------------------------
  test_start('Callback com nome válido é aceito');
  --------------------------------------------------------------------------
  DECLARE
    -- tv4000a é um associative array (INDEX BY word): não tem construtor
    -- tv4000a(), e precisa ser qualificado com o nome do package.
    l_params PL_FPDF.tv4000a;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetHeaderProc('meu_pkg.cabecalho');
    l_params('titulo') := 'Relatorio';
    PL_FPDF.SetFooterProc('meu_pkg.rodape', l_params);
    test_pass('Nomes qualificados aceitos na configuração');
    -- meu_pkg nao existe: sem limpar, todo AddPage seguinte falharia ao
    -- executar o bloco dinamico do header.
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Nome válido foi rejeitado: ' || SQLERRM);
      PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Reset limpa os callbacks de header e rodapé');
  --------------------------------------------------------------------------
  -- Regressao: os callbacks sobreviviam ao Reset (e ao Init, que chama Reset).
  -- Um nome invalido configurado uma vez deixava a sessao inutilizavel: todo
  -- AddPage seguinte estourava ao executar o bloco dinamico do header.
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetHeaderProc('pacote_inexistente.cabecalho');
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'Sem header', '0', 1);
    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      test_pass('Documento gerado após Reset, sem o callback anterior');
    ELSE
      test_fail('PDF vazio após Reset');
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Callback sobreviveu ao Reset: ' || SQLERRM);
      PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Callback com injeção de PL/SQL é rejeitado na configuração');
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_payloads IS TABLE OF VARCHAR2(200);
    l_payloads t_payloads := t_payloads(
      'meu_pkg.proc; execute immediate ''drop table x''; --',
      'proc'' || chr(59) || ''',
      'meu pkg.proc',
      'proc(); raise_application_error(-20999,''x'');'
    );
    l_rejeitados PLS_INTEGER := 0;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    FOR i IN 1 .. l_payloads.COUNT LOOP
      BEGIN
        PL_FPDF.SetHeaderProc(l_payloads(i));
        DBMS_OUTPUT.PUT_LINE('  [!] aceito indevidamente: ' || l_payloads(i));
      EXCEPTION
        WHEN OTHERS THEN
          l_rejeitados := l_rejeitados + 1;   -- esperado
      END;
    END LOOP;

    IF l_rejeitados = l_payloads.COUNT THEN
      test_pass('Todos os ' || l_rejeitados || ' payloads rejeitados');
    ELSE
      test_fail('Apenas ' || l_rejeitados || ' de ' || l_payloads.COUNT || ' rejeitados');
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Erro do package informa a origem (backtrace)');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Reset;
    BEGIN
      -- SetPage sem documento inicializado: erro conhecido do package
      PL_FPDF.SetPage(99);
      test_fail('Erro esperado não ocorreu');
    EXCEPTION
      WHEN OTHERS THEN
        IF DBMS_UTILITY.FORMAT_ERROR_BACKTRACE IS NOT NULL THEN
          test_pass('Erro propagado com rastreamento disponível');
        ELSE
          test_fail('Erro sem backtrace');
        END IF;
    END;
  END;

  --------------------------------------------------------------------------
  test_start('QR Code gera matriz correta (vetores de referência)');
  --------------------------------------------------------------------------
  -- QR Code: confere a matriz gerada contra vetores de referência.
  --
  -- Cada módulo escuro vira um "re f" no fluxo de conteúdo, então a contagem
  -- dessa marca no PDF equivale ao número de módulos escuros. Os valores
  -- esperados vêm de uma implementação de referência validada contra o
  -- decodificador zxing-cpp (scripts/qr_reference/).
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_caso IS RECORD (
      txt     VARCHAR2(400),
      ecl     VARCHAR2(1),
      escuros PLS_INTEGER
    );
    TYPE t_casos IS TABLE OF t_caso;
    l_casos t_casos := t_casos();
    l_conta PLS_INTEGER;
    l_pos   PLS_INTEGER;
    l_falhas PLS_INTEGER := 0;

    PROCEDURE add(p_t VARCHAR2, p_e VARCHAR2, p_d PLS_INTEGER) IS
    BEGIN
      l_casos.EXTEND;
      l_casos(l_casos.COUNT).txt     := p_t;
      l_casos(l_casos.COUNT).ecl     := p_e;
      l_casos(l_casos.COUNT).escuros := p_d;
    END;
  BEGIN
    add('PL_FPDF', 'M', 246);
    add('https://msbrasil.inf.br', 'M', 344);
    add('00020126360014BR.GOV.BCB.PIX0114+5531999999995204000053039865802BR'
        -- CHR(38) = '&'. Escrito assim porque o PL/SQL Developer (e o SQL*Plus)
        -- tratam '&' como variável de substituição: o payload chegava ao banco
        -- com 113 bytes em vez de 114, e o QR gerado divergia do vetor.
        || '5913M' || CHR(38) || 'S do Brasil6008BRASILIA62070503***63041D3D',
        'M', 1010);
    add('teste', 'H', 230);
    add('1234567890', 'L', 224);

    FOR i IN 1 .. l_casos.COUNT LOOP
      BEGIN
        PL_FPDF.Init('P', 'mm', 'A4');
        PL_FPDF.AddPage();
        PL_FPDF.AddQRCode(
          p_x => 20, p_y => 20, p_size => 60,
          p_data             => l_casos(i).txt,
          p_error_correction => l_casos(i).ecl);
        l_pdf := PL_FPDF.OutputBlob();

        -- conta as ocorrências de 're f' (um retângulo preenchido por módulo)
        l_conta := 0;
        l_pos   := 1;
        LOOP
          l_pos := DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(' re f'), l_pos, 1);
          EXIT WHEN NVL(l_pos, 0) = 0;
          l_conta := l_conta + 1;
          l_pos   := l_pos + 1;
        END LOOP;

        IF l_conta = l_casos(i).escuros THEN
          DBMS_OUTPUT.PUT_LINE('  [ok] ' || l_casos(i).ecl || ' ' ||
            SUBSTR(l_casos(i).txt, 1, 24) || ' -> ' || l_conta || ' módulos');
        ELSE
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] ' || l_casos(i).ecl || ' ' ||
            SUBSTR(l_casos(i).txt, 1, 24) || ' -> ' || l_conta ||
            ' módulos, esperado ' || l_casos(i).escuros);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] exceção em ' ||
            SUBSTR(l_casos(i).txt, 1, 24) || ': ' || SQLERRM);
      END;
    END LOOP;

    IF l_falhas = 0 THEN
      test_pass('Matriz do QR Code igual à referência nos ' ||
                l_casos.COUNT || ' casos');
    ELSE
      test_fail(l_falhas || ' de ' || l_casos.COUNT || ' casos divergiram');
    END IF;
  END;

  --------------------------------------------------------------------------
  test_start('QR Code e barcode: cada recusa com o seu código de erro');
  --------------------------------------------------------------------------
  -- Os códigos do QR (-20870..-20879) e dos códigos de barras
  -- (-20880..-20889) colidiam com os da manipulação de PDF e da segurança:
  -- ORA-20843 significava ao mesmo tempo "AddQRCode: conteúdo vazio" e "xref
  -- em stream não suportada". Contar exceções, como este teste fazia antes,
  -- não pegaria a volta da colisão — só conferir o código pega.
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_caso IS RECORD (nome VARCHAR2(60), esperado PLS_INTEGER);
    TYPE t_casos IS TABLE OF t_caso;
    l_casos t_casos := t_casos(
      t_caso('QR sem conteúdo',            -20870),
      t_caso('QR com tamanho zero',        -20871),
      t_caso('QR com nível inválido',      -20872),
      t_caso('QR acima da capacidade',     -20873),
      t_caso('barcode sem código',         -20880),
      t_caso('barcode com largura zero',   -20881),
      t_caso('simbologia inexistente',     -20882),
      t_caso('CODE39 com caractere ruim',  -20883),
      t_caso('CODE128 com caractere de controle', -20884),
      t_caso('EAN13 com poucos dígitos',   -20885),
      t_caso('EAN13 com verificador ruim', -20886),
      t_caso('ITF14 com poucos dígitos',   -20887)
    );
    l_erros PLS_INTEGER := 0;
    l_msg   VARCHAR2(4000);

    PROCEDURE confere(p_i PLS_INTEGER) IS
    BEGIN
      CASE p_i
        WHEN 1  THEN PL_FPDF.AddQRCode(10, 10, 40, NULL);
        WHEN 2  THEN PL_FPDF.AddQRCode(10, 10, 0, 'x');
        WHEN 3  THEN PL_FPDF.AddQRCode(10, 10, 40, 'x', p_error_correction => 'Z');
        WHEN 4  THEN PL_FPDF.AddQRCode(10, 10, 40, RPAD('A', 4000, 'A'),
                                       p_error_correction => 'H');
        WHEN 5  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, NULL);
        WHEN 6  THEN PL_FPDF.AddBarcode(10, 10, 0, 20, 'ABC');
        WHEN 7  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, 'ABC', 'PDF417');
        -- 'abc' NAO serve: bc_code39 faz upper(), e 'ABC' e valido. O '#' nao
        -- esta em co_bc39_chars nem depois do upper.
        WHEN 8  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, 'AB#C', 'CODE39');
        -- CHR(9) e determinístico em qualquer charset; CHR(200) dependeria da
        -- codificacao da sessao, e o teste anterior passava por isso.
        WHEN 9  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, 'A' || CHR(9) || 'B',
                                        'CODE128');
        WHEN 10 THEN PL_FPDF.AddBarcode(10, 10, 100, 20, '123', 'EAN13');
        WHEN 11 THEN PL_FPDF.AddBarcode(10, 10, 100, 20, '7891234567890', 'EAN13');
        WHEN 12 THEN PL_FPDF.AddBarcode(10, 10, 100, 20, '123', 'ITF14');
      END CASE;
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [' || l_casos(p_i).nome || ': não recusou]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != l_casos(p_i).esperado THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [' || l_casos(p_i).nome || ': ' || SQLCODE
                         || ', esperado ' || l_casos(p_i).esperado || ']';
        END IF;
    END confere;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    FOR i IN 1 .. l_casos.COUNT LOOP
      confere(i);
    END LOOP;
    IF l_erros = 0 THEN
      test_pass(l_casos.COUNT || ' recusas, cada uma com o código da sua faixa');
    ELSE
      test_fail(l_erros || ' divergência(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Código de barras gera desenho correto (vetores de referência)');
  --------------------------------------------------------------------------
  -- Código de barras: confere o desenho contra vetores de referência.
  --
  -- Cada grupo de módulos escuros consecutivos vira um "re f" no PDF, então a
  -- contagem dessa marca equivale ao número de barras. Valores esperados vêm de
  -- scripts/barcode_reference/, validado contra o decodificador zxing-cpp.
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_caso IS RECORD (
      cod    VARCHAR2(60),
      tipo   VARCHAR2(20),
      barras PLS_INTEGER
    );
    TYPE t_casos IS TABLE OF t_caso;
    l_casos t_casos := t_casos();
    l_conta PLS_INTEGER;
    l_pos   PLS_INTEGER;
    l_falhas PLS_INTEGER := 0;

    PROCEDURE add(p_c VARCHAR2, p_t VARCHAR2, p_b PLS_INTEGER) IS
    BEGIN
      l_casos.EXTEND;
      l_casos(l_casos.COUNT).cod    := p_c;
      l_casos(l_casos.COUNT).tipo   := p_t;
      l_casos(l_casos.COUNT).barras := p_b;
    END;
  BEGIN
    add('PL-FPDF-123',   'CODE39',  65);
    add('ABC123abc',     'CODE128', 37);
    add('12345678',      'CODE128', 22);
    add('789123456789',  'EAN13',   30);
    add('1234567',       'EAN8',    22);
    add('1234567890123', 'ITF14',   39);

    FOR i IN 1 .. l_casos.COUNT LOOP
      BEGIN
        PL_FPDF.Init('P', 'mm', 'A4');
        PL_FPDF.AddPage();
        PL_FPDF.AddBarcode(
          p_x => 20, p_y => 30, p_width => 120, p_height => 20,
          p_code      => l_casos(i).cod,
          p_type      => l_casos(i).tipo,
          p_show_text => FALSE);          -- sem texto: só as barras viram 're f'
        l_pdf := PL_FPDF.OutputBlob();

        l_conta := 0; l_pos := 1;
        LOOP
          l_pos := DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(' re f'), l_pos, 1);
          EXIT WHEN NVL(l_pos, 0) = 0;
          l_conta := l_conta + 1;
          l_pos   := l_pos + 1;
        END LOOP;

        IF l_conta = l_casos(i).barras THEN
          DBMS_OUTPUT.PUT_LINE('  [ok] ' || RPAD(l_casos(i).tipo, 8) ||
            l_casos(i).cod || ' -> ' || l_conta || ' barras');
        ELSE
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] ' || RPAD(l_casos(i).tipo, 8) ||
            l_casos(i).cod || ' -> ' || l_conta || ' barras, esperado ' ||
            l_casos(i).barras);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] exceção em ' || l_casos(i).tipo || ': ' || SQLERRM);
      END;
    END LOOP;

    IF l_falhas = 0 THEN
      test_pass('Código de barras igual à referência nas ' ||
                l_casos.COUNT || ' simbologias');
    ELSE
      test_fail(l_falhas || ' de ' || l_casos.COUNT || ' divergiram');
    END IF;
  END;

  --------------------------------------------------------------------------
  test_start('Código de barras valida entrada e calcula verificador');
  --------------------------------------------------------------------------
  DECLARE
    l_erros PLS_INTEGER := 0;
    l_a PLS_INTEGER; l_b PLS_INTEGER; l_pos PLS_INTEGER;

    FUNCTION barras(p_cod VARCHAR2, p_tipo VARCHAR2) RETURN PLS_INTEGER IS
      l_n PLS_INTEGER := 0; l_p PLS_INTEGER := 1; l_doc BLOB;
    BEGIN
      PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
      PL_FPDF.AddBarcode(20, 30, 120, 20, p_cod, p_tipo, FALSE);
      l_doc := PL_FPDF.OutputBlob();
      LOOP
        l_p := DBMS_LOB.INSTR(l_doc, UTL_RAW.CAST_TO_RAW(' re f'), l_p, 1);
        EXIT WHEN NVL(l_p,0) = 0;
        l_n := l_n + 1; l_p := l_p + 1;
      END LOOP;
      RETURN l_n;
    END;
  BEGIN
    -- simbologia inexistente, caractere fora do CODE39 e EAN com tamanho errado
    BEGIN PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(10,10,80,20,'123','CODE99');
    EXCEPTION WHEN OTHERS THEN l_erros := l_erros + 1; END;
    BEGIN PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(10,10,80,20,'abc#','CODE39');
    EXCEPTION WHEN OTHERS THEN l_erros := l_erros + 1; END;
    BEGIN PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(10,10,80,20,'123','EAN13');
    EXCEPTION WHEN OTHERS THEN l_erros := l_erros + 1; END;

    -- com e sem verificador devem produzir o mesmo desenho
    l_a := barras('789123456789',  'EAN13');
    l_b := barras('7891234567895', 'EAN13');

    IF l_erros = 3 AND l_a = l_b AND l_a > 0 THEN
      test_pass('3 entradas inválidas rejeitadas; verificador calculado confere');
    ELSE
      test_fail('erros=' || l_erros || ' (esperado 3), barras ' || l_a || ' vs ' || l_b);
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Merge / Split / Extract: cópia real de objetos');
  --------------------------------------------------------------------------
  DECLARE
    l_a      BLOB;
    l_b      BLOB;
    l_out    BLOB;
    l_parts  JSON_ARRAY_T;
    l_erros  PLS_INTEGER := 0;
    l_msg    VARCHAR2(4000);

    -- gera um PDF de p_n páginas, cada uma com um texto identificável
    FUNCTION doc(p_n PLS_INTEGER, p_tag VARCHAR2) RETURN BLOB IS
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.SetFont('Arial', 'B', 16);
      FOR i IN 1 .. p_n LOOP
        PL_FPDF.AddPage();
        PL_FPDF.Cell(100, 10, p_tag || ' pagina ' || i, '1', 1);
      END LOOP;
      RETURN PL_FPDF.OutputBlob();
    END;

    -- nº de páginas de um PDF, medido pelo próprio parser da biblioteca
    FUNCTION paginas(p_pdf BLOB) RETURN PLS_INTEGER IS
      l_n PLS_INTEGER;
    BEGIN
      -- Sem ClearPDFCache aqui: ele descarta também os documentos de
      -- LoadPDFWithID, e este helper é chamado no meio do teste, com 'A' e 'B'
      -- ainda em uso. LoadPDF sobrescreve o PDF único a cada chamada.
      PL_FPDF.LoadPDF(p_pdf);
      l_n := PL_FPDF.GetPageCount;
      RETURN l_n;
    END;

    PROCEDURE espera_erro(p_o VARCHAR2, p_cod PLS_INTEGER) IS
      l_x BLOB;
    BEGIN
      l_x := PL_FPDF.ExtractPages('A', p_o, NULL);
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [' || p_o || ' deveria falhar]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != p_cod THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [' || p_o || ' deu ' || SQLCODE ||
                   ', esperado ' || p_cod || ']';
        END IF;
    END;
  BEGIN
    l_a := doc(3, 'A');
    l_b := doc(2, 'B');

    PL_FPDF.LoadPDFWithID('A', l_a);
    PL_FPDF.LoadPDFWithID('B', l_b);

    -- merge: 3 + 2 = 5 páginas
    l_out := PL_FPDF.MergePDFs(JSON_ARRAY_T('["A","B"]'), NULL);
    IF paginas(l_out) != 5 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge A+B deu ' || paginas(l_out) || ' páginas]';
    END IF;

    -- ordem inversa continua com 5
    l_out := PL_FPDF.MergePDFs(JSON_ARRAY_T('["B","A"]'), NULL);
    IF paginas(l_out) != 5 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge B+A deu ' || paginas(l_out) || ' páginas]';
    END IF;

    -- o mesmo documento duas vezes: ids têm de ser renumerados sem colidir
    l_out := PL_FPDF.MergePDFs(JSON_ARRAY_T('["A","A"]'), NULL);
    IF paginas(l_out) != 6 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge A+A deu ' || paginas(l_out) || ' páginas]';
    END IF;

    -- extract: intervalos, lista e ordem pedida
    IF paginas(PL_FPDF.ExtractPages('A', 'ALL',  NULL)) != 3 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract ALL]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '2',    NULL)) != 1 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 2]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '1,3',  NULL)) != 2 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 1,3]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '1-3',  NULL)) != 3 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 1-3]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '3,1',  NULL)) != 2 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 3,1]';
    END IF;

    -- uma página extraída tem de ser menor que o documento inteiro
    IF DBMS_LOB.GETLENGTH(PL_FPDF.ExtractPages('A', '1', NULL))
       >= DBMS_LOB.GETLENGTH(l_a) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [extract de 1 página não ficou menor]';
    END IF;

    -- entradas inválidas
    espera_erro('0',   -20838);
    espera_erro('9',   -20839);
    espera_erro('3-2', -20838);
    espera_erro('x',   -20838);

    -- split: 3 páginas em duas partes
    l_parts := PL_FPDF.SplitPDF('A', JSON_ARRAY_T('["1-2","3"]'));
    IF l_parts.get_size() != 2 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [split gerou ' || l_parts.get_size() || ' partes]';
    END IF;

    -- intervalos sobrepostos têm de ser recusados
    BEGIN
      l_parts := PL_FPDF.SplitPDF('A', JSON_ARRAY_T('["1-2","2-3"]'));
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [sobreposição não detectada]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -20836 THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [sobreposição deu ' || SQLCODE || ']';
        END IF;
    END;

    PL_FPDF.UnloadPDF('A');
    PL_FPDF.UnloadPDF('B');

    IF l_erros = 0 THEN
      test_pass('merge, extract e split preservam a contagem de páginas e '
                || 'rejeitam entradas inválidas');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      -- sem este handler um erro aqui abortava o arquivo de teste inteiro
      test_fail('exceção: ' || SQLERRM);
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END;

  --------------------------------------------------------------------------
  test_start('Merge preserva stream binário e acima de 32 KB');
  --------------------------------------------------------------------------
  -- Regressão: pdf_obj_extent devolvia o FIM do payload como se fosse o
  -- início, então o conteúdo do stream passava por VARCHAR2 e por
  -- pdf_scan_refs em vez de ser copiado byte a byte. Com texto ASCII curto
  -- passava despercebido; com stream binário corrompia, e acima de
  -- co_pdf_dict_limit o objeto era recusado com ORA-20841.
  DECLARE
    l_grande BLOB;
    l_saida  BLOB;
    l_erros  PLS_INTEGER := 0;
    l_msg    VARCHAR2(4000);
    l_n      PLS_INTEGER;
    l_base   PLS_INTEGER;

    FUNCTION paginas(p_pdf BLOB) RETURN PLS_INTEGER IS
      l_q PLS_INTEGER;
    BEGIN
      PL_FPDF.LoadPDF(p_pdf);
      l_q := PL_FPDF.GetPageCount;
      RETURN l_q;
    END;
  BEGIN
    PL_FPDF.ClearPDFCache;

    -- página densa: o fluxo de conteúdo passa de 32 KB com folga
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);
    FOR i IN 1 .. 1200 LOOP
      PL_FPDF.Cell(20, 4, 'Bloco ' || i, '1', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    l_grande := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    IF DBMS_LOB.GETLENGTH(l_grande) < 32767 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [o PDF de origem não passou de 32 KB]';
    END IF;

    -- 1200 células não cabem numa folha: o AddPage automático do Cell quebra o
    -- documento em várias páginas. O esperado do merge é o dobro do que a
    -- origem realmente tem, e não 2 — fixar 2 era erro do próprio teste.
    l_base := paginas(l_grande);

    PL_FPDF.LoadPDFWithID('G1', l_grande);
    PL_FPDF.LoadPDFWithID('G2', l_grande);
    l_saida := PL_FPDF.MergePDFs(JSON_ARRAY_T('["G1","G2"]'), NULL);

    l_n := paginas(l_saida);
    IF l_n != 2 * l_base THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge deu ' || l_n || ' páginas, esperado '
                     || (2 * l_base) || ' (origem: ' || l_base || ')]';
    END IF;

    -- o conteúdo tem de sobreviver: cada célula emite um 're' no fluxo
    IF DBMS_LOB.GETLENGTH(l_saida) < DBMS_LOB.GETLENGTH(l_grande) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [resultado menor que a origem: conteúdo perdido]';
    END IF;

    PL_FPDF.ClearPDFCache;
    IF l_erros = 0 THEN
      test_pass('stream acima de 32 KB copiado sem truncar nem corromper');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('exceção: ' || SQLERRM);
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END;

  --------------------------------------------------------------------------
  test_start('OutputModifiedPDF: remoção de página e rotação');
  --------------------------------------------------------------------------
  DECLARE
    l_src   BLOB;
    l_out   BLOB;
    l_erros PLS_INTEGER := 0;
    l_msg   VARCHAR2(4000);
    l_n     PLS_INTEGER;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1 .. 4 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(100, 10, 'Pagina ' || i, '1', 1);
    END LOOP;
    l_src := PL_FPDF.OutputBlob();

    PL_FPDF.LoadPDF(l_src);
    PL_FPDF.RemovePage(2);
    PL_FPDF.RotatePage(3, 90);
    l_out := PL_FPDF.OutputModifiedPDF();
    PL_FPDF.ClearPDFCache;

    PL_FPDF.LoadPDF(l_out);
    l_n := PL_FPDF.GetPageCount;
    PL_FPDF.ClearPDFCache;

    IF l_n != 3 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [esperado 3 páginas, veio ' || l_n || ']';
    END IF;

    -- a rotação pedida tem de aparecer no PDF gerado
    IF DBMS_LOB.INSTR(l_out, UTL_RAW.CAST_TO_RAW('/Rotate 90'), 1, 1) = 0 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [/Rotate 90 ausente]';
    END IF;

    -- sem alterações pendentes, tem de recusar
    BEGIN
      PL_FPDF.LoadPDF(l_src);
      l_out := PL_FPDF.OutputModifiedPDF();
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [gerou sem alterações]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -20819 THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [sem alterações deu ' || SQLCODE || ']';
        END IF;
    END;
    PL_FPDF.ClearPDFCache;

    IF l_erros = 0 THEN
      test_pass('página removida e rotação aplicada no documento copiado');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================');
  DBMS_OUTPUT.PUT_LINE('  Total: ' || l_test_count ||
                       ' | Passou: ' || l_pass_count ||
                       ' | Falhou: ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/
