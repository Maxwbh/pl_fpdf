--------------------------------------------------------------------------------
-- PL_FPDF - Fonte TrueType: registro, metricas e embutimento
--
-- Registrar uma fonte, medir por ela e embuti-la no arquivo.
--
-- Ate setembro/2026 nada disto funcionava: o cache de fontes NAO TINHA
-- CONSUMIDOR -- o SetFont nunca o consultava e os bytes nunca iam para o PDF --
-- e o parser conferia o magic number e INVENTAVA as metricas, com upm 1000 e
-- ascendente 800 literais no codigo.
--
-- Por isso a fonte deste teste tem 2048 unidades por em e metricas que nao sao
-- numero redondo: com upm 1000 nao se distinguiria "leu do arquivo" de "chutou
-- a constante de sempre". Ela e gerada por dev/scripts/ttf_reference/gerar.py e
-- conferida reabrindo no fontTools; a estrutura que sai daqui e validada no
-- MuPDF por dev/scripts/ttfembed_reference/.
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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Fonte TrueType: registro, metricas e embutimento');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

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

  --------------------------------------------------------------------------
  caso('TTF por BLOB: as metricas saem do ARQUIVO, nao de constante');
  --------------------------------------------------------------------------
  -- O LoadTTFFromFile exige READ num DIRECTORY, e este projeto nao depende de
  -- concessao extra. O caminho equivalente e o AddTTFFont, que recebe BLOB --
  -- e o BLOB vem daqui, de uma TTF minima gerada por
  -- dev/scripts/ttf_reference/gerar.py e conferida reabrindo no fontTools.
  --
  -- A fonte tem 2048 unidades por em DE PROPOSITO. Ate setembro/2026 o parser
  -- conferia o magic number e inventava o resto -- upm 1000, ascent 800,
  -- descent -200 eram literais no codigo. Com metricas incomuns, cada numero
  -- abaixo so pode ter vindo do arquivo.
  -- fonte gerada por dev/scripts/ttf_reference/gerar.py
  -- 716 bytes, upm 2048, ascent 1900, descent -500, glifos ['.notdef', 'A']
  DECLARE
    l_hex  VARCHAR2(4000);
    l_ttf  BLOB;
  BEGIN
    -- TTF-INICIO
    l_hex := '00010000000A0080000300204F532F324E3B45E20000012800000060636D6170'
           || '000C00940000019000000034676C796605614061000001CC0000001868656164'
           || '30F599DE000000AC00000036686865610BBA03DF000000E400000024686D7478'
           || '08D2007800000188000000086C6F6361000C0000000001C4000000066D617870'
           || '0004000500000108000000206E616D651B7229D2000001E4000000BD706F7374'
           || '00280000000002A40000002600010000000100003BEFFE5E5F0F3CF500030800'
           || '00000000E6C9A7A800000000E6C9A7A80078000003D405960000000300020000'
           || '0000000000010000076CFE0C000004D2007800FE03D400010000000000000000'
           || '0000000000000002000100000002000300010000000000020000000000000000'
           || '0000000000000000000304690190000500040000000000000000000000000000'
           || '0000000000000000000000000000000000000000000100000000000000000000'
           || '00003F3F3F3F000000410041076CFE0C000000000000000000000000000003E8'
           || '05960000002000000400000004D2007800000002000000030000001400030001'
           || '0000001400040020000000040004000100000041FFFF00000041FFFFFFC00001'
           || '0000000000000000000C000000010078000003D405960002000033210178035C'
           || 'FE52059600000006004E0001000000000001000B000000010000000000020007'
           || '000B000100000000000600130012000300010409000100160025000300010409'
           || '0002000E003B000300010409000600260049504C465044465465737465526567'
           || '756C6172504C4650444654657374652D526567756C61720050004C0046005000'
           || '440046005400650073007400650052006500670075006C006100720050004C00'
           || '4600500044004600540065007300740065002D0052006500670075006C006100'
           || '7200000000020000000000000000000000000000000000000000000000000000'
           || '000000000002000000240000';
    -- TTF-FIM
    l_ttf := HEXTORAW(l_hex);

    PL_FPDF.ClearTTFFontCache;
    PL_FPDF.AddTTFFont('TesteBlob', l_ttf);

    IF NVL(PL_FPDF.IsTTFFontLoaded('TesteBlob'), FALSE) THEN
      passou('a fonte foi registrada a partir do BLOB');
    ELSE
      falhou('AddTTFFont nao registrou a fonte');
    END IF;

    l_fonte := PL_FPDF.GetTTFFontInfo('TesteBlob');

    IF l_fonte.units_per_em = 2048 THEN
      passou('unitsPerEm 2048, lido do head');
    ELSE
      falhou('unitsPerEm veio ' || TO_CHAR(l_fonte.units_per_em)
             || ', esperado 2048 -- 1000 seria a constante antiga');
    END IF;

    -- 1900 e -500 em 2048 por em viram 928 e -244 em 1000 por em
    IF l_fonte.ascent = 928 AND l_fonte.descent = -244 THEN
      passou('ascendente 928 e descendente -244, reescalados de 2048 para 1000');
    ELSE
      falhou('ascendente/descendente vieram ' || TO_CHAR(l_fonte.ascent)
             || '/' || TO_CHAR(l_fonte.descent) || ', esperado 928/-244');
    END IF;

    IF l_fonte.cap_height = 698 THEN
      passou('altura de caixa alta 698, lida do OS/2');
    ELSE
      falhou('cap_height veio ' || TO_CHAR(l_fonte.cap_height)
             || ', esperado 698');
    END IF;

    IF l_fonte.bbox_xmin = 59 AND l_fonte.bbox_ymin = 0
       AND l_fonte.bbox_xmax = 479 AND l_fonte.bbox_ymax = 698 THEN
      passou('a caixa [59 0 479 698] saiu do head');
    ELSE
      falhou('a caixa veio [' || TO_CHAR(l_fonte.bbox_xmin) || ' '
             || TO_CHAR(l_fonte.bbox_ymin) || ' ' || TO_CHAR(l_fonte.bbox_xmax)
             || ' ' || TO_CHAR(l_fonte.bbox_ymax) || '], esperado [59 0 479 698]');
    END IF;

    -- a largura e o que separa "a fonte esta la" de "o leitor usa a fonte que
    -- esta la": o A avanca 1234/2048 = 603, e o B nao tem glifo nenhum
    IF TO_NUMBER(SUBSTR(l_fonte.larguras, ASCII('A') * 4 + 1, 4)) = 603 THEN
      passou('a largura do A e 603, do hmtx pelo cmap');
    ELSE
      falhou('a largura do A veio '
             || SUBSTR(l_fonte.larguras, ASCII('A') * 4 + 1, 4)
             || ', esperado 0603');
    END IF;

    IF TO_NUMBER(SUBSTR(l_fonte.larguras, ASCII('B') * 4 + 1, 4)) = 0 THEN
      passou('o B, que a fonte nao tem, mede zero');
    ELSE
      falhou('o B mediu ' || SUBSTR(l_fonte.larguras, ASCII('B') * 4 + 1, 4)
             || ', e esta fonte so tem o glifo A');
    END IF;

    PL_FPDF.ClearTTFFontCache;
    IF NOT NVL(PL_FPDF.IsTTFFontLoaded('TesteBlob'), TRUE) THEN
      passou('o ClearTTFFontCache descarregou a fonte');
    ELSE
      falhou('a fonte sobreviveu ao ClearTTFFontCache');
    END IF;
  END;

  --------------------------------------------------------------------------
  caso('TTF: o SetFont a usa, e o programa da fonte vai para o arquivo');
  --------------------------------------------------------------------------
  -- Este e o caso que nao existia: o cache era consultavel e NADA o consumia.
  -- O SetFont nunca olhava para ele, entao registrar uma fonte e pedi-la dava
  -- "Undefined font"; e nada emitia os bytes no PDF.
  -- fonte gerada por dev/scripts/ttf_reference/gerar.py
  -- 716 bytes, upm 2048, ascent 1900, descent -500, glifos ['.notdef', 'A']
  DECLARE
    l_hex  VARCHAR2(4000);
    l_ttf  BLOB;
    l_doc  BLOB;
  BEGIN
    -- TTF-INICIO
    l_hex := '00010000000A0080000300204F532F324E3B45E20000012800000060636D6170'
           || '000C00940000019000000034676C796605614061000001CC0000001868656164'
           || '30F599DE000000AC00000036686865610BBA03DF000000E400000024686D7478'
           || '08D2007800000188000000086C6F6361000C0000000001C4000000066D617870'
           || '0004000500000108000000206E616D651B7229D2000001E4000000BD706F7374'
           || '00280000000002A40000002600010000000100003BEFFE5E5F0F3CF500030800'
           || '00000000E6C9A7A800000000E6C9A7A80078000003D405960000000300020000'
           || '0000000000010000076CFE0C000004D2007800FE03D400010000000000000000'
           || '0000000000000002000100000002000300010000000000020000000000000000'
           || '0000000000000000000304690190000500040000000000000000000000000000'
           || '0000000000000000000000000000000000000000000100000000000000000000'
           || '00003F3F3F3F000000410041076CFE0C000000000000000000000000000003E8'
           || '05960000002000000400000004D2007800000002000000030000001400030001'
           || '0000001400040020000000040004000100000041FFFF00000041FFFFFFC00001'
           || '0000000000000000000C000000010078000003D405960002000033210178035C'
           || 'FE52059600000006004E0001000000000001000B000000010000000000020007'
           || '000B000100000000000600130012000300010409000100160025000300010409'
           || '0002000E003B000300010409000600260049504C465044465465737465526567'
           || '756C6172504C4650444654657374652D526567756C61720050004C0046005000'
           || '440046005400650073007400650052006500670075006C006100720050004C00'
           || '4600500044004600540065007300740065002D0052006500670075006C006100'
           || '7200000000020000000000000000000000000000000000000000000000000000'
           || '000000000002000000240000';
    -- TTF-FIM
    l_ttf := HEXTORAW(l_hex);

    PL_FPDF.Reset;
    PL_FPDF.ClearTTFFontCache;
    PL_FPDF.AddTTFFont('TesteBlob', l_ttf);
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;

    BEGIN
      PL_FPDF.SetFont('TesteBlob', '', 14);
      passou('o SetFont aceitou a fonte do cache');
    EXCEPTION
      WHEN OTHERS THEN
        IF INSTR(SQLERRM, 'ORA-20201') > 0 THEN
          falhou('"Undefined font": o SetFont voltou a nao consultar o cache');
        ELSE
          falhou('o SetFont levantou: ' || SQLERRM);
        END IF;
    END;

    IF LOWER(PL_FPDF.GetCurrentFontFamily) = 'testeblob' THEN
      passou('a fonte corrente e a registrada');
    ELSE
      falhou('a fonte corrente e "' || PL_FPDF.GetCurrentFontFamily || '"');
    END IF;

    -- o A mede 603 milesimos do corpo: 14 * 603 / 1000 = 8,442 pt, e em mm
    -- isso e 8,442 / 2,8346 = 2,978
    IF ROUND(PL_FPDF.GetStringWidth('A'), 2) = ROUND(14 * 603 / 1000 / (72/25.4), 2) THEN
      passou('o GetStringWidth mede pela tabela da TTF');
    ELSE
      falhou('o GetStringWidth devolveu '
             || TO_CHAR(ROUND(PL_FPDF.GetStringWidth('A'), 3))
             || ', esperado ' || TO_CHAR(ROUND(14 * 603 / 1000 / (72/25.4), 3))
             || ' -- esta medindo por outra tabela');
    END IF;

    PL_FPDF.Cell(40, 10, 'A');
    l_doc := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    PL_FPDF.ClearTTFFontCache;

    IF acha(l_doc, '/Subtype /TrueType') > 0 THEN
      passou('o dicionario da fonte saiu como /TrueType');
    ELSE
      falhou('nao ha fonte /TrueType no arquivo');
    END IF;

    IF acha(l_doc, '/FontFile2') > 0 THEN
      passou('o descritor aponta o /FontFile2');
    ELSE
      falhou('o /FontFile2 nao foi emitido: a fonte nao esta embutida');
    END IF;

    IF acha(l_doc, '/Length1 716') > 0 THEN
      passou('o /Length1 declara os 716 bytes do programa da fonte');
    ELSE
      falhou('o /Length1 nao confere com o tamanho da fonte');
    END IF;

    IF acha(l_doc, '/ASCIIHexDecode') > 0 THEN
      passou('o programa saiu em hexadecimal, com o filtro declarado');
    ELSE
      falhou('sem /ASCIIHexDecode: byte cru nao atravessa o CLOB de montagem');
    END IF;

    -- 0603 na posicao do A dentro do /Widths
    IF acha(l_doc, ' 603 ') > 0 THEN
      passou('a largura 603 do A esta no /Widths');
    ELSE
      falhou('a largura da TTF nao chegou ao /Widths');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('TTF sem tabela obrigatoria e recusada, em vez de inventada');
  --------------------------------------------------------------------------
  -- Ate setembro/2026 um BLOB de 28 bytes com o magic number certo e mais nada
  -- era ACEITO, e devolvia upm 1000 e ascent 800 -- as constantes. Agora nao
  -- ha de onde tirar metrica, e recusar vale mais que inventar.
  BEGIN
    PL_FPDF.ClearTTFFontCache;
    PL_FPDF.AddTTFFont('TesteVazia', HEXTORAW('0001000000000000'
      || RPAD('00', 40, '0')));
    falhou('aceitou uma fonte sem tabela nenhuma');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20202') > 0 THEN
        passou('recusada com ORA-20202');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('LoadTTFFromFile recusa diretorio inexistente sem precisar de grant');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.LoadTTFFromFile('X', 'x.ttf', 'DIRETORIO_QUE_NAO_EXISTE_PLFPDF');
    falhou('leu de um diretorio que nao existe');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20401') > 0
         OR INSTR(SQLERRM, 'ORA-20402') > 0
         OR INSTR(SQLERRM, 'ORA-20202') > 0 THEN
        passou('recusado com erro proprio: ' || SUBSTR(SQLERRM, 1, 60));
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

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
