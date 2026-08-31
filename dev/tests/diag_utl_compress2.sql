--------------------------------------------------------------------------------
-- Diagnóstico 2: dá para descomprimir SEM conhecer o CRC-32?
--
-- O primeiro diagnóstico respondeu o principal: o Oracle produz gzip padrão
-- (`1F8B08`), e o DEFLATE do PDF vestido de gzip **funciona** — 600 bytes,
-- conteúdo conferido. O caminho existe.
--
-- Mas o teste com CRC e tamanho zerados falhou, e isso levanta um impasse que
-- decide se o caminho serve na prática:
--
--   o gzip exige o CRC-32 do conteúdo DESCOMPRIMIDO no rodapé, e num PDF real
--   nós só temos o comprimido. Para calcular o CRC seria preciso descomprimir
--   primeiro — que é exatamente o que se está tentando fazer.
--
-- Se o Oracle confere o CRC, o envelope de gzip não serve para dado de
-- terceiro, por mais que tenha funcionado com o CRC que eu já sabia. Se ele
-- confere apenas o TAMANHO, está tudo bem: o tamanho descomprimido de uma xref
-- em stream é calculável do próprio dicionário (`/W` e `/Size`; nos object
-- streams, `/N` e `/First`).
--
-- E há uma terceira saída: a API por partes (`LZ_UNCOMPRESS_OPEN` /
-- `_EXTRACT` / `_CLOSE`) entrega os pedaços conforme descomprime, e a
-- conferência do rodapé só acontece no fim. Se o `_EXTRACT` devolver os dados
-- antes de reclamar, o rodapé deixa de importar.
--
-- Execute na SQL Window (F8) e me envie a saída inteira.
--
-- RESULTADO (ago/2026, Oracle 19c Autonomous)
-- -------------------------------------------
--   CRC correto + tamanho zerado ........ ORA-29294
--   CRC zerado  + tamanho correto ....... ORA-29294
--   CRC correto + tamanho errado por 1 .. ORA-29294
--   ambos corretos ...................... funcionou, 600 bytes
--   API por partes com rodapé zerado .... ORA-29294, sem entregar nada
--
-- Conclusão: o Oracle confere OS DOIS campos, e nenhum atalho entrega os dados
-- antes da conferência. Como o CRC é do conteúdo descomprimido, o caminho é
-- circular. O UTL_COMPRESS não serve de inflate para dado de terceiro.
--------------------------------------------------------------------------------

DECLARE
  co_deflate CONSTANT RAW(400) := HEXTORAW(
         '15C4836E44010000B077B36DDBB66FB66DDBDE3E7F6BD2341484827F118A5494'
      || 'A215A358C5295E094A54929295A254A5295D19CA5496B295A35CE5295F052A54'
      || '918A55A25295A95C15AA5495AA55A35AD5A95E0D6A54939AD5A256B5A95D1DEA'
      || '5497BAD5A35EF5A95F031AD4908635A2B04635A6714D6852539AD68C6635A779'
      || '2D68514B5AD68A56B5A6756D68535BDAD68E76B5A77D1DE850473AD6894E75A6'
      || '735DE85257BAD68D6E75A77B3DE8514F7AD68B5EF5A6777DE8535FFAD68F7E83'
      || 'E00F');

  co_hdr    CONSTANT RAW(10) := HEXTORAW('1F8B0800000000000003');
  co_crc    CONSTANT RAW(4)  := HEXTORAW('699D763C');   -- correto
  co_crc0   CONSTANT RAW(4)  := HEXTORAW('00000000');   -- errado
  co_size   CONSTANT RAW(4)  := HEXTORAW('58020000');   -- 600, correto
  co_size0  CONSTANT RAW(4)  := HEXTORAW('00000000');   -- errado
  co_sizeX  CONSTANT RAW(4)  := HEXTORAW('59020000');   -- 601, errado por 1

  co_ini    CONSTANT RAW(16) := HEXTORAW('01000100000100020000010003');

  PROCEDURE nota(p VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('   ' || SUBSTR(p, 1, 250));
  END;

  FUNCTION envelope(p_crc RAW, p_size RAW) RETURN BLOB IS
    l BLOB;
    r RAW(500) := UTL_RAW.CONCAT(co_hdr, co_deflate, p_crc, p_size);
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l, TRUE);
    DBMS_LOB.WRITEAPPEND(l, UTL_RAW.LENGTH(r), r);
    RETURN l;
  END;

  PROCEDURE tentar(p_rotulo VARCHAR2, p_crc RAW, p_size RAW) IS
    l_r BLOB;
    l_t PLS_INTEGER;
  BEGIN
    l_r := UTL_COMPRESS.LZ_UNCOMPRESS(envelope(p_crc, p_size));
    l_t := NVL(DBMS_LOB.GETLENGTH(l_r), 0);
    nota(p_rotulo || ': FUNCIONOU — ' || l_t || ' bytes, conteudo '
         || CASE WHEN l_t = 600 AND DBMS_LOB.SUBSTR(l_r, 13, 1) = co_ini
                 THEN 'confere' ELSE 'DIVERGENTE' END);
  EXCEPTION
    WHEN OTHERS THEN
      nota(p_rotulo || ': ERRO -> ' || SUBSTR(SQLERRM, 1, 120));
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==========================================');
  DBMS_OUTPUT.PUT_LINE('  O rodape do gzip precisa estar certo?');
  DBMS_OUTPUT.PUT_LINE('==========================================');

  ------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('== Qual dos dois campos o Oracle confere');
  ------------------------------------------------------------------------------
  tentar('CRC correto + tamanho ZERADO ', co_crc,  co_size0);
  tentar('CRC ZERADO  + tamanho correto', co_crc0, co_size);
  tentar('CRC correto + tamanho ERRADO por 1', co_crc, co_sizeX);
  tentar('ambos corretos (controle)   ', co_crc,  co_size);

  ------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('== A API por partes entrega os dados antes de conferir?');
  ------------------------------------------------------------------------------
  -- Se entregar, o rodapé deixa de importar: bastaria preencher com zeros,
  -- extrair tudo, e ignorar o erro do fechamento.
  DECLARE
    l_h    BINARY_INTEGER;
    l_ped  BLOB;
    l_acc  BLOB;
    l_n    PLS_INTEGER := 0;
    l_voltas PLS_INTEGER := 0;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_acc, TRUE);
    l_h := UTL_COMPRESS.LZ_UNCOMPRESS_OPEN(envelope(co_crc0, co_size0));
    BEGIN
      LOOP
        l_voltas := l_voltas + 1;
        EXIT WHEN l_voltas > 200;                 -- guarda contra laço infinito
        DBMS_LOB.CREATETEMPORARY(l_ped, TRUE);
        UTL_COMPRESS.LZ_UNCOMPRESS_EXTRACT(l_h, l_ped);
        EXIT WHEN NVL(DBMS_LOB.GETLENGTH(l_ped), 0) = 0;
        DBMS_LOB.APPEND(l_acc, l_ped);
        DBMS_LOB.FREETEMPORARY(l_ped);
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        nota('o laco de _EXTRACT parou com: ' || SUBSTR(SQLERRM, 1, 100));
    END;

    l_n := NVL(DBMS_LOB.GETLENGTH(l_acc), 0);
    IF l_n = 600 AND DBMS_LOB.SUBSTR(l_acc, 13, 1) = co_ini THEN
      nota('_EXTRACT com rodape ZERADO: ENTREGOU os 600 bytes, conteudo confere');
    ELSIF l_n > 0 THEN
      nota('_EXTRACT devolveu ' || l_n || ' bytes (esperado 600); inicio: '
           || RAWTOHEX(DBMS_LOB.SUBSTR(l_acc, 13, 1)));
    ELSE
      nota('_EXTRACT nao devolveu nada com o rodape zerado');
    END IF;

    BEGIN
      UTL_COMPRESS.LZ_UNCOMPRESS_CLOSE(l_h);
      nota('_CLOSE nao reclamou');
    EXCEPTION
      WHEN OTHERS THEN
        nota('_CLOSE reclamou (esperado): ' || SUBSTR(SQLERRM, 1, 90));
    END;
  EXCEPTION
    WHEN OTHERS THEN
      nota('API por partes indisponivel ou falhou: ' || SUBSTR(SQLERRM, 1, 120));
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Como ler:');
  DBMS_OUTPUT.PUT_LINE('  "CRC ZERADO + tamanho correto" funcionou');
  DBMS_OUTPUT.PUT_LINE('     -> so o tamanho e conferido, e ele e calculavel');
  DBMS_OUTPUT.PUT_LINE('        do proprio PDF. Caminho livre.');
  DBMS_OUTPUT.PUT_LINE('  so o _EXTRACT entregou os dados');
  DBMS_OUTPUT.PUT_LINE('     -> usa-se a API por partes e ignora-se o rodape.');
  DBMS_OUTPUT.PUT_LINE('  nenhum dos dois');
  DBMS_OUTPUT.PUT_LINE('     -> o CRC e exigido, e nao da para saber sem');
  DBMS_OUTPUT.PUT_LINE('        descomprimir: inflate a mao (RFC 1951).');
END;
/
