--------------------------------------------------------------------------------
-- Diagnóstico: o UTL_COMPRESS serve como inflate para o FlateDecode do PDF?
--
-- Por que isto existe
-- -------------------
-- O item mais valioso ainda em aberto no roadmap é a xref em stream (PDF 1.5+):
-- sem ela, merge, extract e marca d'água são recusados em qualquer PDF gerado
-- por produtor moderno. O bloqueio é que a xref em stream vem comprimida em
-- `FlateDecode`, e o PL/SQL não tem zlib.
--
-- O `UTL_COMPRESS` existe e usa Lempel-Ziv, mas **não é zlib**: a documentação
-- fala em compatibilidade com gzip, e versões do Oracle acrescentam bytes
-- próprios ao formato. Entre "usa Lempel-Ziv" e "descomprime o que o PDF traz"
-- há uma distância que só o banco responde.
--
-- O que os três formatos têm em comum é o miolo: **DEFLATE cru** (RFC 1951).
--   * zlib (RFC 1950, o FlateDecode): 2 bytes de cabeçalho + DEFLATE + Adler-32
--   * gzip (RFC 1952):               10 bytes de cabeçalho + DEFLATE + CRC-32 + tamanho
-- Então a pergunta prática é: dá para tirar a casca do zlib, vesti-la de gzip e
-- entregar ao `LZ_UNCOMPRESS`?
--
-- Os dados abaixo NÃO foram produzidos pelo Oracle: são um zlib real, gerado
-- fora do banco, com a cara de uma xref em stream (entradas de 5 bytes). Testar
-- com algo que o próprio `LZ_COMPRESS` gerou responderia à pergunta errada.
--
-- Execute na SQL Window do PL/SQL Developer (F8) e me envie a saída inteira.
-- Nenhum dos resultados é "errado": qualquer um deles decide o roadmap.
--------------------------------------------------------------------------------

DECLARE
  -- zlib (FlateDecode) de 600 bytes de carga binária -> 200 bytes
  co_zlib CONSTANT RAW(400) := HEXTORAW(
         '78DA15C4836E44010000B077B36DDBB66FB66DDBDE3E7F6BD2341484827F118A'
      || '5494A215A358C5295E094A54929295A254A5295D19CA5496B295A35CE5295F05'
      || '2A54918A55A25295A95C15AA5495AA55A35AD5A95E0D6A54939AD5A256B5A95D'
      || '1DEA5497BAD5A35EF5A95F031AD4908635A2B04635A6714D6852539AD68C6635'
      || 'A7792D68514B5AD68A56B5A6756D68535BDAD68E76B5A77D1DE850473AD6894E'
      || '75A6735DE85257BAD68D6E75A77B3DE8514F7AD68B5EF5A6777DE8535FFAD68F'
      || '7E83E00FDF1E1CD5');

  -- o mesmo, sem os 2 bytes de cabeçalho zlib e sem os 4 do Adler-32
  co_deflate CONSTANT RAW(400) := HEXTORAW(
         '15C4836E44010000B077B36DDBB66FB66DDBDE3E7F6BD2341484827F118A5494'
      || 'A215A358C5295E094A54929295A254A5295D19CA5496B295A35CE5295F052A54'
      || '918A55A25295A95C15AA5495AA55A35AD5A95E0D6A54939AD5A256B5A95D1DEA'
      || '5497BAD5A35EF5A95F031AD4908635A2B04635A6714D6852539AD68C6635A779'
      || '2D68514B5AD68A56B5A6756D68535BDAD68E76B5A77D1DE850473AD6894E75A6'
      || '735DE85257BAD68D6E75A77B3DE8514F7AD68B5EF5A6777DE8535FFAD68F7E83'
      || 'E00F');

  -- cabeçalho gzip mínimo: magia 1F8B, método 08 (deflate), sem flags,
  -- sem data, sem flags extras, SO desconhecido (03)
  co_gzip_hdr CONSTANT RAW(10) := HEXTORAW('1F8B0800000000000003');
  co_crc32    CONSTANT RAW(4)  := HEXTORAW('699D763C');  -- little-endian
  co_isize    CONSTANT RAW(4)  := HEXTORAW('58020000');  -- 600, little-endian
  co_zeros    CONSTANT RAW(4)  := HEXTORAW('00000000');

  co_carga_ini CONSTANT RAW(16) := HEXTORAW('01000100000100020000010003');

  l_bl   BLOB;
  l_out  BLOB;
  l_tmp  BLOB;
  l_n    PLS_INTEGER;

  PROCEDURE cabecalho(p_t VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('== ' || p_t);
  END;

  PROCEDURE nota(p_t VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('   ' || SUBSTR(p_t, 1, 250));
  END;

  FUNCTION blob_de(p_r RAW) RETURN BLOB IS
    l BLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l, TRUE);
    DBMS_LOB.WRITEAPPEND(l, UTL_RAW.LENGTH(p_r), p_r);
    RETURN l;
  END;

  -- tenta descomprimir e diz o que aconteceu, sem abortar o resto
  PROCEDURE tentar(p_rotulo VARCHAR2, p_entrada BLOB) IS
    l_r BLOB;
    l_t PLS_INTEGER;
  BEGIN
    l_r := UTL_COMPRESS.LZ_UNCOMPRESS(p_entrada);
    l_t := NVL(DBMS_LOB.GETLENGTH(l_r), 0);
    IF l_t = 600
       AND DBMS_LOB.SUBSTR(l_r, 13, 1) = co_carga_ini THEN
      nota(p_rotulo || ': FUNCIONOU — ' || l_t
           || ' bytes, e o conteudo confere');
    ELSIF l_t > 0 THEN
      nota(p_rotulo || ': devolveu ' || l_t || ' bytes, mas o conteudo NAO '
           || 'confere (esperado 600). Primeiros bytes: '
           || RAWTOHEX(DBMS_LOB.SUBSTR(l_r, 13, 1)));
    ELSE
      nota(p_rotulo || ': devolveu vazio');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      nota(p_rotulo || ': ERRO -> ' || SUBSTR(SQLERRM, 1, 150));
  END tentar;
BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================');
  DBMS_OUTPUT.PUT_LINE('  UTL_COMPRESS serve de inflate para o PDF?');
  DBMS_OUTPUT.PUT_LINE('================================================');

  ------------------------------------------------------------------------------
  cabecalho('1. A API funciona neste banco (ida e volta pelo proprio Oracle)');
  ------------------------------------------------------------------------------
  BEGIN
    l_bl := blob_de(UTL_RAW.COPIES(HEXTORAW('4142434445'), 200));  -- 1000 bytes
    l_tmp := UTL_COMPRESS.LZ_COMPRESS(l_bl, 6);
    l_out := UTL_COMPRESS.LZ_UNCOMPRESS(l_tmp);
    nota('LZ_COMPRESS: 1000 -> ' || DBMS_LOB.GETLENGTH(l_tmp) || ' bytes');
    nota('LZ_UNCOMPRESS devolveu ' || DBMS_LOB.GETLENGTH(l_out) || ' bytes ('
         || CASE WHEN DBMS_LOB.GETLENGTH(l_out) = 1000 THEN 'ok'
                 ELSE 'DIVERGENTE' END || ')');
  EXCEPTION
    WHEN OTHERS THEN nota('ERRO -> ' || SUBSTR(SQLERRM, 1, 150));
  END;

  ------------------------------------------------------------------------------
  cabecalho('2. Que formato o Oracle produz? (e o que revela sobre o que aceita)');
  ------------------------------------------------------------------------------
  BEGIN
    l_n := DBMS_LOB.GETLENGTH(l_tmp);
    nota('primeiros 20 bytes: ' || RAWTOHEX(DBMS_LOB.SUBSTR(l_tmp, 20, 1)));
    nota('ultimos 12 bytes:   '
         || RAWTOHEX(DBMS_LOB.SUBSTR(l_tmp, 12, GREATEST(1, l_n - 11))));
    -- gzip padrao comeca com 1F8B08; se comecar diferente, o Oracle usa
    -- formato proprio e o envelope de gzip provavelmente nao serve
    nota('comeca com 1F8B08 (gzip padrao)? '
         || CASE WHEN DBMS_LOB.SUBSTR(l_tmp, 3, 1) = HEXTORAW('1F8B08')
                 THEN 'SIM' ELSE 'NAO' END);
  EXCEPTION
    WHEN OTHERS THEN nota('ERRO -> ' || SUBSTR(SQLERRM, 1, 150));
  END;

  ------------------------------------------------------------------------------
  cabecalho('3. O zlib do PDF, sem alteracao nenhuma');
  ------------------------------------------------------------------------------
  -- Se isto funcionar, nao ha nada a fazer: passa o stream direto.
  tentar('zlib puro (78DA...)', blob_de(co_zlib));

  ------------------------------------------------------------------------------
  cabecalho('4. DEFLATE cru vestido de gzip, com CRC-32 e tamanho CORRETOS');
  ------------------------------------------------------------------------------
  -- É a hipótese principal: o miolo é o mesmo, só a casca muda.
  tentar('gzip(cabecalho + deflate + crc + tamanho)',
         blob_de(UTL_RAW.CONCAT(co_gzip_hdr, co_deflate, co_crc32, co_isize)));

  ------------------------------------------------------------------------------
  cabecalho('5. O mesmo, com CRC-32 e tamanho ZERADOS');
  ------------------------------------------------------------------------------
  -- Decide se seria preciso implementar CRC-32 em PL/SQL. Se o Oracle nao
  -- confere, o porte fica bem mais barato — e o PDF ja traz como conferir o
  -- resultado (/W, /Size e /N dizem o tamanho esperado).
  tentar('gzip com crc e tamanho zerados',
         blob_de(UTL_RAW.CONCAT(co_gzip_hdr, co_deflate, co_zeros, co_zeros)));

  ------------------------------------------------------------------------------
  cabecalho('6. DEFLATE cru, sem casca alguma');
  ------------------------------------------------------------------------------
  tentar('deflate cru', blob_de(co_deflate));

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Como ler o resultado:');
  DBMS_OUTPUT.PUT_LINE('  4 funcionou  -> xref em stream vira trabalho normal');
  DBMS_OUTPUT.PUT_LINE('  so 5 falhou  -> idem, mais um CRC-32 em PL/SQL');
  DBMS_OUTPUT.PUT_LINE('  4 e 5 falham -> UTL_COMPRESS nao serve; seria preciso');
  DBMS_OUTPUT.PUT_LINE('                  um inflate escrito a mao (RFC 1951)');
END;
/
