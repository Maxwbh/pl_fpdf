--------------------------------------------------------------------------------
-- PL_FPDF_UTIL — o que nao e PDF
--
-- QR Code, codigos de barras, DEFLATE/INFLATE e criptografia. Nada aqui sabe o
-- que e uma pagina, uma fonte ou um objeto de PDF: entra dado, sai dado.
--
-- Por que existe
-- --------------
-- O body do PL_FPDF passou de 14 mil linhas, e um quinto disso nao tinha
-- relacao nenhuma com PDF. Os codificadores de QR e de barras produzem
-- matrizes e padroes; quem desenha e o AddQRCode/AddBarcode, que ficaram la.
-- O deflate e a cifra sao formatos de terceiros, validados contra o zlib, o
-- FIPS-197 e o MuPDF.
--
-- A separacao foi medida antes de ser feita: 57 subprogramas, uma unica
-- chamada para fora (tres linhas de log, que sairam) e um unico estado
-- compartilhado (a tabela byte->hexadecimal, exposta por hex_do_byte).
--
-- Ordem de instalacao: este package PRIMEIRO, o PL_FPDF depois. Recompilar
-- este invalida o PL_FPDF, que precisa ser recompilado em seguida.
--
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PL_FPDF_UTIL AS

-- tqr esta na spec: redeclarar aqui e PLS-00371.
--
-- Estes dois vieram do PL_FPDF junto com o codigo que os usa. Nao
-- atravessam a fronteira (nenhuma assinatura publica os menciona),
-- entao ficam privados do body.
type tpi    is table of pls_integer index by pls_integer;
type tv4000 is table of varchar2(4000) index by pls_integer;
-- Tabelas do codificador QR (ISO/IEC 18004), versoes 1..20
  co_qr_ecc_l constant varchar2(4000) :=
    '7,1,19,0,0|10,1,34,0,0|15,1,55,0,0|20,1,80,0,0|26,1,108,0,0|18,2,68,0,0|20,2,78,0,0|24,2' ||
    ',97,0,0|30,2,116,0,0|18,2,68,2,69|20,4,81,0,0|24,2,92,2,93|26,4,107,0,0|30,3,115,1,116|2' ||
    '2,5,87,1,88|24,5,98,1,99|28,1,107,5,108|30,5,120,1,121|28,3,113,4,114|28,3,107,5,108';
  co_qr_ecc_m constant varchar2(4000) :=
    '10,1,16,0,0|16,1,28,0,0|26,1,44,0,0|18,2,32,0,0|24,2,43,0,0|16,4,27,0,0|18,4,31,0,0|22,2' ||
    ',38,2,39|22,3,36,2,37|26,4,43,1,44|30,1,50,4,51|22,6,36,2,37|22,8,37,1,38|24,4,40,5,41|2' ||
    '4,5,41,5,42|28,7,45,3,46|28,10,46,1,47|26,9,43,4,44|26,3,44,11,45|26,3,41,13,42';
  co_qr_ecc_q constant varchar2(4000) :=
    '13,1,13,0,0|22,1,22,0,0|18,2,17,0,0|26,2,24,0,0|18,2,15,2,16|24,4,19,0,0|18,2,14,4,15|22' ||
    ',4,18,2,19|20,4,16,4,17|24,6,19,2,20|28,4,22,4,23|26,4,20,6,21|24,8,20,4,21|20,11,16,5,1' ||
    '7|30,5,24,7,25|24,15,19,2,20|28,1,22,15,23|28,17,22,1,23|26,17,21,4,22|30,15,24,5,25';
  co_qr_ecc_h constant varchar2(4000) :=
    '17,1,9,0,0|28,1,16,0,0|22,2,13,0,0|16,4,9,0,0|22,2,11,2,12|28,4,15,0,0|26,4,13,1,14|26,4' ||
    ',14,2,15|24,4,12,4,13|28,6,15,2,16|24,3,12,8,13|28,7,14,4,15|22,12,11,4,12|24,11,12,5,13' ||
    '|24,11,12,7,13|30,3,15,13,16|28,2,14,17,15|28,2,14,19,15|26,9,13,16,14|28,15,15,10,16';
  co_qr_align constant varchar2(4000) :=
    '|6,18|6,22|6,26|6,30|6,34|6,22,38|6,24,42|6,26,46|6,28,50|6,30,54|6,32,58|6,34,62|6,26,4' ||
    '6,66|6,26,48,70|6,26,50,74|6,30,54,78|6,30,56,82|6,30,58,86|6,34,62,90';
-- Tabelas dos codigos de barras lineares
  co_bc39_chars constant varchar2(4000) :=
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%*';
  co_bc39_pats constant varchar2(4000) :=
    'nnnwwnwnnwnnwnnnnwnnwwnnnnwwnwwnnnnnnnnwwnnnwwnnwwnnnnnnwwwnnnnnnnwnnwnwwnnwnnwnnnnwwn' ||
    'nwnnwnnnnwnnwnnwnnwnnwwnwnnwnnnnnnnwwnnwwnnnwwnnnnnwnwwnnnnnnnnwwnwwnnnnwwnnnnwnnwwnnn' ||
    'nnnwwwnnwnnnnnnwwnnwnnnnwwwnwnnnnwnnnnnwnnwwwnnnwnnwnnnwnwnnwnnnnnnnwwwwnnnnnwwnnnwnnn' ||
    'wwnnnnnwnwwnwwnnnnnnwnwwnnnnnwwwwnnnnnnnwnnwnnnwwwnnwnnnnnwwnwnnnnnwnnnnwnwwwnnnnwnnnw' ||
    'wnnnwnnnwnwnwnnnnwnwnnnwnnwnnnwnwnnnnwnwnwnnwnnwnwnn';
  co_bc128 constant varchar2(4000) :=
    '212222 222122 222221 121223 121322 131222 122213 122312 132212 221213 221312 231212 ' ||
    '112232 122132 122231 113222 123122 123221 223211 221132 221231 213212 223112 312131 ' ||
    '311222 321122 321221 312212 322112 322211 212123 212321 232121 111323 131123 131321 ' ||
    '112313 132113 132311 211313 231113 231311 112133 112331 132131 113123 113321 133121 ' ||
    '313121 211331 231131 213113 213311 213131 311123 311321 331121 312113 312311 332111 ' ||
    '314111 221411 431111 111224 111422 121124 121421 141122 141221 112214 112412 122114 ' ||
    '122411 142112 142211 241211 221114 413111 241112 134111 111242 121142 121241 114212 ' ||
    '124112 124211 411212 421112 421211 212141 214121 412121 111143 111341 131141 114113 ' ||
    '114311 411113 411311 113141 114131 311141 411131 211412 211214 211232 2331112';
  co_bc_ean_l constant varchar2(4000) :=
    '0001101001100100100110111101010001101100010101111011101101101110001011';
  co_bc_ean_g constant varchar2(4000) :=
    '0100111011001100110110100001001110101110010000101001000100010010010111';
  co_bc_ean_r constant varchar2(4000) :=
    '1110010110011011011001000010101110010011101010000100010010010001110100';
  co_bc_ean_par constant varchar2(4000) :=
    'LLLLLLLLGLGGLLGGLGLLGGGLLGLLGGLGGLLGLGGGLLLGLGLGLGLGGLLGGLGL';
  co_bc_itf constant varchar2(4000) :=
    'nnwwnwnnnwnwnnwwwnnnnnwnwwnwnnnwwnnnnnwwwnnwnnwnwn';
g_qr_exp tqr;                          -- tabelas do campo de Galois GF(256)
g_qr_log tqr;
g_qr_gf_ready boolean := false;
-- Resultado do autoteste de criptografia: null = ainda nao verificado.
-- Ver crypto_autoteste, chamado por EncryptPDF/DecryptPDF.
g_crypto_ok boolean := false;
--------------------------------------------------------------------------------
-- AES: tabelas montadas uma vez por sessao
--
-- A S-box e as multiplicacoes no corpo de Galois viram tabelas porque o PL/SQL
-- e lento demais para calcula-las a cada byte: sem elas, o MixColumns de um
-- unico bloco custa 640 multiplicacoes de 8 iteracoes cada.
--
-- co_aes_sbox e a S-box do FIPS-197 em hexadecimal. A inversa e as tabelas de
-- multiplicacao por 2, 3, 9, 11, 13 e 14 — as unicas constantes que o AES usa —
-- sao derivadas dela em aes_init.
--------------------------------------------------------------------------------
co_aes_sbox CONSTANT VARCHAR2(512) :=
  '637C777BF26B6FC53001672BFED7AB76' || 'CA82C97DFA5947F0ADD4A2AF9CA472C0' ||
  'B7FD9326363FF7CC34A5E5F171D83115' || '04C723C31896059A071280E2EB27B275' ||
  '09832C1A1B6E5AA0523BD6B329E32F84' || '53D100ED20FCB15B6ACBBE394A4C58CF' ||
  'D0EFAAFB434D338545F9027F503C9FA8' || '51A3408F929D38F5BCB6DA2110FFF3D2' ||
  'CD0C13EC5F974417C4A77E3D645D1973' || '60814FDC222A908846EEB814DE5E0BDB' ||
  'E0323A0A4906245CC2D3AC629195E479' || 'E7C8376D8DD54EA96C56F4EA657AAE08' ||
  'BA78252E1CA6B4C6E8DD741F4BBD8B8A' || '703EB5664803F60E613557B986C11D9E' ||
  'E1F8981169D98E949B1E87E9CE5528DF' || '8CA1890DBFE6426841992D0FB054BB16';
g_aes_pronto BOOLEAN := FALSE;   -- tabelas montadas
g_aes_ok     BOOLEAN := FALSE;   -- vetores do FIPS-197 conferidos
g_aes_sbox   tpi;    -- byte -> S-box(byte)
g_aes_inv    tpi;    -- byte -> S-box^-1(byte)
g_aes_m2     tpi;    -- multiplicacao por 2 em GF(2^8)
g_aes_m3     tpi;
g_aes_m9     tpi;
g_aes_m11    tpi;
g_aes_m13    tpi;
g_aes_m14    tpi;
g_aes_hex    tv4000; -- byte -> os dois digitos hexadecimais, para remontar o RAW
--------------------------------------------------------------------------------
-- INFLATE (RFC 1951): tabelas da especificacao
--
-- Portado de scripts/pdfinflate_reference/, validado contra o zlib (53/53).
--
-- Existe porque o UTL_COMPRESS nao serve: ele so descomprime com o CRC-32 e o
-- tamanho do rodape gzip corretos, e o CRC e do conteudo DESCOMPRIMIDO — para
-- calcula-lo seria preciso descomprimir. Ver tests/diag_utl_compress*.sql.
--
-- Sem isto o copiador recusa qualquer PDF com xref em stream ou object stream,
-- que e o que todo produtor moderno gera.
--------------------------------------------------------------------------------
co_inf_max_bits CONSTANT PLS_INTEGER := 15;
-- comprimentos, codigos 257..285
co_inf_cbase CONSTANT VARCHAR2(200) :=
  '3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,'
  || '163,195,227,258';
co_inf_cextra CONSTANT VARCHAR2(100) :=
  '0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0';
-- distancias, codigos 0..29
co_inf_dbase CONSTANT VARCHAR2(200) :=
  '1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,'
  || '2049,3073,4097,6145,8193,12289,16385,24577';
co_inf_dextra CONSTANT VARCHAR2(100) :=
  '0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13';
-- ordem em que os comprimentos do alfabeto de comprimentos aparecem
co_inf_ordem CONSTANT VARCHAR2(100) :=
  '16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15';
-- DEFLATE (comprimir), portado de scripts/pdfdeflate_reference/
--
-- Um bloco so, BFINAL=1 e BTYPE=01 (Huffman FIXA), com LZ77 guloso. Escrever e
-- mais facil que ler: o leitor tem de aceitar tudo o que a especificacao
-- permite, o escritor so precisa emitir UM subconjunto valido. Sem arvore para
-- transmitir some a metade complicada do formato.
--
-- Comprime menos que o zlib, que usa Huffman dinamica, e muito mais que nada.
co_def_janela  CONSTANT PLS_INTEGER := 32768;   -- janela do LZ77
co_def_cas_min CONSTANT PLS_INTEGER := 3;
co_def_cas_max CONSTANT PLS_INTEGER := 258;
co_def_hash    CONSTANT PLS_INTEGER := 32767;   -- mascara de 15 bits
co_def_corrente CONSTANT PLS_INTEGER := 16;     -- candidatos por posicao
-- Acima disto a entrada vai em bloco ARMAZENADO, sem comprimir: o LZ77 precisa
-- de uma posicao->anterior por byte, e uma tabela indexada com milhoes de
-- entradas estoura a PGA. Fluxo de conteudo de pagina nao chega perto disso.
co_def_max_comp CONSTANT PLS_INTEGER := 262144;
g_def_hex   VARCHAR2(32767);
g_def_acum  PLS_INTEGER;
g_def_nbits PLS_INTEGER;
g_def_ent   tpi;          -- entrada, byte a byte
g_def_cab   tpi;          -- hash -> ultima posicao
g_def_ant   tpi;          -- posicao -> posicao anterior com o mesmo hash
g_inf_pronto BOOLEAN := FALSE;
g_inf_cbase  tpi;
g_inf_cextra tpi;
g_inf_dbase  tpi;
g_inf_dextra tpi;
g_inf_ordem  tpi;
-- Tabelas de Huffman no formato do puff: contagem(c) = quantos codigos tem c
-- bits; simbolos(i) = os simbolos ordenados por (comprimento, valor).
--
-- Ficam em GLOBAIS, e nao num record devolvido e passado adiante, por causa de
-- memoria: um record com duas colecoes e COPIADO a cada chamada, e inf_sim e
-- chamada uma vez por simbolo. A primeira versao fazia isso e estourou a PGA
-- (ORA-04036) descomprimindo 688 bytes. Sao tres pares porque o bloco dinamico
-- precisa da tabela de comprimentos viva enquanto monta as outras duas.
g_inf_lit_c  tpi;  g_inf_lit_s  tpi;   -- literais e comprimentos
g_inf_dst_c  tpi;  g_inf_dst_s  tpi;   -- distancias
g_inf_cl_c   tpi;  g_inf_cl_s   tpi;   -- alfabeto de comprimentos de codigo
-- Janela deslizante de 32 KB, indexada por MOD(posicao, 32768).
--
-- Circular de proposito: uma referencia LZ77 alcanca no maximo 32768 bytes
-- atras, entao so isso precisa ficar vivo. A versao anterior guardava a saida
-- INTEIRA numa tabela indexada e apagava elemento a elemento — e o DELETE de
-- uma associative array nao devolve memoria, entao o consumo crescia com o
-- total descomprimido, nao com a janela.
co_inf_janela CONSTANT PLS_INTEGER := 32768;
g_inf_jan     tpi;
-- Estado do fluxo de bits em variaveis de pacote, e nao num record passado
-- adiante: inf_bits e chamada uma vez por BIT e inf_sim uma vez por simbolo;
-- copiar um record a cada chamada dominaria o custo.
--
-- g_inf_acum e NUMBER, nao PLS_INTEGER: ele acumula ate 8 bits alem dos que
-- faltam, e o deslocamento e feito por multiplicacao — o PL/SQL nao tem
-- operador de deslocamento, e PLS_INTEGER estouraria em 2147483647.
g_inf_src   BLOB;
g_inf_len   PLS_INTEGER := 0;
g_inf_pos   PLS_INTEGER := 1;    -- proximo byte a ler, base 1
g_inf_acum  NUMBER := 0;         -- bits lidos e ainda nao consumidos
g_inf_nbits PLS_INTEGER := 0;
-- inflate e deflate sao publicas: a declaracao esta na spec, e as duas ficam
-- no fim do body, depois das rotinas que usam.
-- crypto_rc4_blob, aes_cbc_decifrar e aes_chave_objeto nao tem declaracao
-- antecipada aqui: elas sao PUBLICAS, e a spec ja as declara. Declarar de novo
-- no body e redeclarar no mesmo escopo — PLS-00305.
-- pdf_inflate usa g_aes_hex (byte -> hexadecimal) para remontar a saida, e
-- aes_init e quem monta essa tabela; ela fica junto do AES, mais abaixo.
procedure aes_init;


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Task 3.7: QR Code Generation with PIX Support - Rendering Procedures
-- Note: PIX utility functions (ValidatePixKey, CalculateCRC16, GetPixPayload)
--       are now in PL_FPDF_PIX package. Use PL_FPDF_PIX.* to call them directly.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL/SQL nao tem operador XOR: a + b - 2*bitand(a,b) equivale a a XOR b.
-- Precisa vir antes de qr_init_gf, que a usa na reducao do polinomio do GF(256).
function qr_xor(a pls_integer, b pls_integer) return pls_integer is
begin
  return a + b - 2 * bitand(a, b);
end qr_xor;

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
procedure qr_init_gf is
  x pls_integer := 1;
begin
  if g_qr_gf_ready then return; end if;
  for i in 0..254 loop
    g_qr_exp(i) := x;
    g_qr_log(x) := i;
    x := x * 2;
    if x >= 256 then x := qr_xor(x, 285); end if;   -- x^8 + x^4 + x^3 + x^2 + 1
  end loop;
  for i in 255..511 loop
    g_qr_exp(i) := g_qr_exp(i - 255);
  end loop;
  g_qr_gf_ready := true;
end qr_init_gf;

--------------------------------------------------------------------------------
-- qr_xor : PL/SQL nao tem operador XOR bit a bit; para inteiros nao negativos
--          a XOR b = a + b - 2 * (a AND b)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_xor : PL/SQL nao tem operador XOR bit a bit; para inteiros nao negativos
--          a XOR b = a + b - 2 * (a AND b)
--------------------------------------------------------------------------------
function qr_gf_mul(a pls_integer, b pls_integer) return pls_integer is
begin
  if a = 0 or b = 0 then return 0; end if;
  return g_qr_exp(g_qr_log(a) + g_qr_log(b));
end qr_gf_mul;

--------------------------------------------------------------------------------
-- qr_field : n-esimo campo (base 1) de uma lista separada por p_sep
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_field : n-esimo campo (base 1) de uma lista separada por p_sep
--------------------------------------------------------------------------------
function qr_field(p_list varchar2, p_pos pls_integer, p_sep varchar2 default ',')
  return varchar2 is
  l_ini pls_integer := 1;
  l_fim pls_integer;
begin
  -- Feito com INSTR/SUBSTR, e nao com REGEXP_SUBSTR: '[^,]*' casa tambem a
  -- string vazia entre separadores, entao a ocorrencia 2 vinha vazia em vez do
  -- 2o campo — o que zerava os parametros de bloco e fazia qr_choose_version
  -- recusar qualquer conteudo. '[^,]+' resolveria isso, mas descartaria campos
  -- vazios, e co_qr_align comeca com um (a versao 1 nao tem alinhamento).
  if p_pos > 1 then
    l_ini := instr(p_list, p_sep, 1, p_pos - 1);
    if l_ini = 0 then
      return null;
    end if;
    l_ini := l_ini + 1;
  end if;
  l_fim := instr(p_list, p_sep, 1, p_pos);
  if l_fim = 0 then
    return substr(p_list, l_ini);
  end if;
  return substr(p_list, l_ini, l_fim - l_ini);
end qr_field;

--------------------------------------------------------------------------------
-- qr_ecc_params : parametros de bloco para (versao, nivel)
--   o_ec = codewords de correcao por bloco
--   o_g1/o_d1 = blocos e codewords de dados do grupo 1; o_g2/o_d2 idem grupo 2
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_ecc_params : parametros de bloco para (versao, nivel)
--   o_ec = codewords de correcao por bloco
--   o_g1/o_d1 = blocos e codewords de dados do grupo 1; o_g2/o_d2 idem grupo 2
--------------------------------------------------------------------------------
procedure qr_ecc_params(p_ver pls_integer, p_ecl varchar2,
                        o_ec out pls_integer, o_g1 out pls_integer,
                        o_d1 out pls_integer, o_g2 out pls_integer,
                        o_d2 out pls_integer) is
  l_tab varchar2(4000);
  l_row varchar2(100);
begin
  l_tab := case upper(p_ecl)
             when 'L' then co_qr_ecc_l
             when 'M' then co_qr_ecc_m
             when 'Q' then co_qr_ecc_q
             when 'H' then co_qr_ecc_h
           end;
  if l_tab is null then
    raise_application_error(-20872,
      'Nivel de correcao invalido: ' || p_ecl || '. Use L, M, Q ou H.');
  end if;
  l_row := qr_field(l_tab, p_ver, '|');
  o_ec := to_number(qr_field(l_row, 1));
  o_g1 := to_number(qr_field(l_row, 2));
  o_d1 := to_number(qr_field(l_row, 3));
  o_g2 := to_number(qr_field(l_row, 4));
  o_d2 := to_number(qr_field(l_row, 5));
end qr_ecc_params;

--------------------------------------------------------------------------------
-- qr_choose_version : menor versao que comporta os dados no nivel informado
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_choose_version : menor versao que comporta os dados no nivel informado
--------------------------------------------------------------------------------
function qr_choose_version(p_len pls_integer, p_ecl varchar2) return pls_integer is
  l_ec pls_integer; l_g1 pls_integer; l_d1 pls_integer;
  l_g2 pls_integer; l_d2 pls_integer;
  l_cap pls_integer; l_cci pls_integer; l_need pls_integer;
begin
  for v in 1..20 loop
    qr_ecc_params(v, p_ecl, l_ec, l_g1, l_d1, l_g2, l_d2);
    l_cap  := l_g1 * l_d1 + l_g2 * l_d2;
    l_cci  := case when v <= 9 then 8 else 16 end;
    l_need := ceil((4 + l_cci + p_len * 8) / 8);
    if l_need <= l_cap then return v; end if;
  end loop;
  raise_application_error(-20873,
    'Conteudo excede a capacidade do QR Code (' || p_len ||
    ' bytes no nivel ' || p_ecl || '). Use um nivel de correcao menor.');
end qr_choose_version;

--------------------------------------------------------------------------------
-- qr_encode : texto -> fluxo de codewords (dados + correcao, ja intercalados)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_encode : texto -> fluxo de codewords (dados + correcao, ja intercalados)
--------------------------------------------------------------------------------
procedure qr_encode(p_text varchar2, p_ecl varchar2,
                    o_cw out tqr, o_ver out pls_integer, o_len out pls_integer) is
  l_raw   raw(32767);
  l_nb    pls_integer;
  l_ec pls_integer; l_g1 pls_integer; l_d1 pls_integer;
  l_g2 pls_integer; l_d2 pls_integer;
  l_total pls_integer;
  l_bits  tqr;  l_nbits pls_integer := 0;
  l_data  tqr;  l_ndata pls_integer := 0;
  l_blocks tqr;                     -- inicio de cada bloco em l_data (base 1)
  l_sizes  tqr;                     -- tamanho de cada bloco
  l_eccs   tqr;                     -- ECC de todos os blocos, concatenado
  l_nblk  pls_integer := 0;
  l_pos   pls_integer := 1;
  l_pad   pls_integer := 0;
  l_max   pls_integer := 0;
  l_out   pls_integer := 0;

  procedure put_bits(p_val pls_integer, p_n pls_integer) is
  begin
    for i in reverse 0..p_n-1 loop
      l_nbits := l_nbits + 1;
      l_bits(l_nbits) := case when bitand(p_val, power(2, i)) > 0 then 1 else 0 end;
    end loop;
  end;
begin
  qr_init_gf;
  l_raw := utl_i18n.string_to_raw(p_text, 'AL32UTF8');
  l_nb  := utl_raw.length(l_raw);
  o_ver := qr_choose_version(l_nb, p_ecl);
  qr_ecc_params(o_ver, p_ecl, l_ec, l_g1, l_d1, l_g2, l_d2);
  l_total := l_g1 * l_d1 + l_g2 * l_d2;

  put_bits(4, 4);                                             -- modo byte
  put_bits(l_nb, case when o_ver <= 9 then 8 else 16 end);    -- contagem
  for i in 1..l_nb loop
    put_bits(to_number(rawtohex(utl_raw.substr(l_raw, i, 1)), 'XX'), 8);
  end loop;

  for i in 1..least(4, l_total * 8 - l_nbits) loop            -- terminador
    l_nbits := l_nbits + 1; l_bits(l_nbits) := 0;
  end loop;
  while mod(l_nbits, 8) != 0 loop                             -- alinha ao byte
    l_nbits := l_nbits + 1; l_bits(l_nbits) := 0;
  end loop;

  for i in 0..(l_nbits / 8) - 1 loop                          -- bits -> codewords
    l_ndata := l_ndata + 1;
    l_data(l_ndata) := 0;
    for j in 1..8 loop
      l_data(l_ndata) := l_data(l_ndata) * 2 + l_bits(i * 8 + j);
    end loop;
  end loop;

  while l_ndata < l_total loop                                -- preenchimento
    l_ndata := l_ndata + 1;
    l_data(l_ndata) := case when mod(l_pad, 2) = 0 then 236 else 17 end;
    l_pad := l_pad + 1;
  end loop;

  -- blocos: grupo 1 e grupo 2; ECC de cada bloco
  for g in 1..2 loop
    for b in 1..(case g when 1 then l_g1 else l_g2 end) loop
      declare
        l_sz pls_integer := case g when 1 then l_d1 else l_d2 end;
      begin
        l_nblk := l_nblk + 1;
        l_blocks(l_nblk) := l_pos;
        l_sizes(l_nblk)  := l_sz;
        -- Reed-Solomon: divisao sintetica pelo polinomio gerador
        declare
          l_gen tqr; l_res tqr; l_f pls_integer;
        begin
          l_gen(0) := 1;                                      -- gerador grau 0
          for i in 0..l_ec-1 loop
            declare l_ng tqr;
            begin
              for j in 0..i+1 loop l_ng(j) := 0; end loop;
              for j in 0..i loop
                l_ng(j)   := qr_xor(l_ng(j), qr_gf_mul(l_gen(j), g_qr_exp(i)));
                l_ng(j+1) := qr_xor(l_ng(j+1), l_gen(j));
              end loop;
              for j in 0..i+1 loop l_gen(j) := l_ng(j); end loop;
            end;
          end loop;
          -- inverte: consumimos do maior grau para o menor
          declare l_tmp tqr;
          begin
            for j in 0..l_ec loop l_tmp(j) := l_gen(l_ec - j); end loop;
            for j in 0..l_ec loop l_gen(j) := l_tmp(j); end loop;
          end;

          for j in 0..l_sz-1 loop l_res(j) := l_data(l_pos + j); end loop;
          for j in l_sz..l_sz+l_ec-1 loop l_res(j) := 0; end loop;
          for i in 0..l_sz-1 loop
            l_f := l_res(i);
            if l_f != 0 then
              for j in 0..l_ec loop
                l_res(i+j) := qr_xor(l_res(i+j), qr_gf_mul(l_gen(j), l_f));
              end loop;
            end if;
          end loop;
          for j in 0..l_ec-1 loop
            l_eccs((l_nblk-1) * l_ec + j + 1) := l_res(l_sz + j);
          end loop;
        end;
        l_pos := l_pos + l_sz;
        if l_sz > l_max then l_max := l_sz; end if;
      end;
    end loop;
  end loop;

  -- intercalacao: dados e depois correcao
  for i in 0..l_max-1 loop
    for b in 1..l_nblk loop
      if i < l_sizes(b) then
        l_out := l_out + 1;
        o_cw(l_out) := l_data(l_blocks(b) + i);
      end if;
    end loop;
  end loop;
  for i in 0..l_ec-1 loop
    for b in 1..l_nblk loop
      l_out := l_out + 1;
      o_cw(l_out) := l_eccs((b-1) * l_ec + i + 1);
    end loop;
  end loop;
  o_len := l_out;
end qr_encode;

--------------------------------------------------------------------------------
-- qr_mask_bit : as oito mascaras da norma
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_mask_bit : as oito mascaras da norma
--------------------------------------------------------------------------------
function qr_mask_bit(p_k pls_integer, p_r pls_integer, p_c pls_integer)
  return boolean is
begin
  return case p_k
    when 0 then mod(p_r + p_c, 2) = 0
    when 1 then mod(p_r, 2) = 0
    when 2 then mod(p_c, 3) = 0
    when 3 then mod(p_r + p_c, 3) = 0
    when 4 then mod(trunc(p_r/2) + trunc(p_c/3), 2) = 0
    when 5 then mod(p_r * p_c, 2) + mod(p_r * p_c, 3) = 0
    when 6 then mod(mod(p_r * p_c, 2) + mod(p_r * p_c, 3), 2) = 0
    else        mod(mod(p_r + p_c, 2) + mod(p_r * p_c, 3), 2) = 0
  end;
end qr_mask_bit;

--------------------------------------------------------------------------------
-- qr_build : padroes funcionais + dados em zigue-zague
--   o_m   = matriz (indice = linha * tamanho + coluna)
--   o_res = 1 nas posicoes reservadas (funcionais)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_build : padroes funcionais + dados em zigue-zague
--   o_m   = matriz (indice = linha * tamanho + coluna)
--   o_res = 1 nas posicoes reservadas (funcionais)
--------------------------------------------------------------------------------
procedure qr_build(p_ver pls_integer, p_cw tqr, p_ncw pls_integer,
                   o_m out tqr, o_res out tqr, o_size out pls_integer) is
  n     pls_integer;
  l_al  varchar2(100);
  l_np  pls_integer;
  l_idx pls_integer := 0;
  l_col pls_integer;
  l_up  boolean := true;
  l_bit pls_integer;

  procedure setm(r pls_integer, c pls_integer, v pls_integer, res pls_integer) is
  begin
    o_m(r * n + c) := v;
    o_res(r * n + c) := res;
  end;
  function isres(r pls_integer, c pls_integer) return boolean is
  begin
    return o_res.exists(r * n + c) and o_res(r * n + c) = 1;
  end;
  procedure finder(r pls_integer, c pls_integer) is
    rr pls_integer; cc pls_integer; dark boolean;
  begin
    for i in -1..7 loop
      for j in -1..7 loop
        rr := r + i; cc := c + j;
        if rr between 0 and n-1 and cc between 0 and n-1 then
          dark := (i between 0 and 6) and (j between 0 and 6)
                  and (i in (0,6) or j in (0,6)
                       or (i between 2 and 4 and j between 2 and 4));
          setm(rr, cc, case when dark then 1 else 0 end, 1);
        end if;
      end loop;
    end loop;
  end;
begin
  n := 17 + 4 * p_ver;
  o_size := n;
  for i in 0..n*n-1 loop o_m(i) := 0; o_res(i) := 0; end loop;

  finder(0, 0); finder(0, n-7); finder(n-7, 0);

  for i in 8..n-9 loop                                  -- temporizacao
    if not isres(6, i) then setm(6, i, case when mod(i,2)=0 then 1 else 0 end, 1); end if;
    if not isres(i, 6) then setm(i, 6, case when mod(i,2)=0 then 1 else 0 end, 1); end if;
  end loop;

  l_al := qr_field(co_qr_align, p_ver, '|');              -- alinhamento
  l_np := case when l_al is null then 0
               else length(l_al) - length(replace(l_al, ',')) + 1 end;
  for a in 1..l_np loop
    for b in 1..l_np loop
      declare
        r pls_integer := to_number(qr_field(l_al, a));
        c pls_integer := to_number(qr_field(l_al, b));
      begin
        -- pula apenas os que colidem com os tres finders; os que cruzam a linha
        -- de temporizacao DEVEM ser desenhados
        if not ((r <= 8 and c <= 8) or (r <= 8 and c >= n-9) or (r >= n-9 and c <= 8)) then
          for i in -2..2 loop
            for j in -2..2 loop
              setm(r+i, c+j,
                   case when greatest(abs(i), abs(j)) != 1 then 1 else 0 end, 1);
            end loop;
          end loop;
        end if;
      end;
    end loop;
  end loop;

  setm(n-8, 8, 1, 1);                                    -- modulo escuro

  for i in 0..8 loop                                     -- area de formato
    if not isres(8, i) then setm(8, i, 0, 1); end if;
    if not isres(i, 8) then setm(i, 8, 0, 1); end if;
  end loop;
  for i in 0..7 loop
    if not isres(8, n-1-i) then setm(8, n-1-i, 0, 1); end if;
    if not isres(n-1-i, 8) then setm(n-1-i, 8, 0, 1); end if;
  end loop;

  if p_ver >= 7 then                                     -- area de versao
    for i in 0..5 loop
      for j in 0..2 loop
        setm(n-11+j, i, 0, 1);
        setm(i, n-11+j, 0, 1);
      end loop;
    end loop;
  end if;

  -- dados em zigue-zague, da direita para a esquerda em pares de colunas
  l_col := n - 1;
  while l_col > 0 loop
    if l_col = 6 then l_col := l_col - 1; end if;
    for k in 0..n-1 loop
      declare
        r pls_integer := case when l_up then n-1-k else k end;
      begin
        for c in reverse l_col-1..l_col loop
          if not isres(r, c) then
            l_bit := 0;
            if trunc(l_idx/8) < p_ncw then
              l_bit := case
                         when bitand(p_cw(trunc(l_idx/8) + 1),
                                     power(2, 7 - mod(l_idx, 8))) > 0 then 1
                         else 0
                       end;
            end if;
            o_m(r * n + c) := l_bit;
            l_idx := l_idx + 1;
          end if;
        end loop;
      end;
    end loop;
    l_up := not l_up;
    l_col := l_col - 2;
  end loop;
end qr_build;

--------------------------------------------------------------------------------
-- qr_bch_format / qr_bch_version : codigos corretores dos campos de formato e versao
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_bch_format / qr_bch_version : codigos corretores dos campos de formato e versao
--------------------------------------------------------------------------------
function qr_bch_format(p_fmt pls_integer) return pls_integer is
  v pls_integer := p_fmt * 1024;              -- fmt << 10
begin
  for i in reverse 0..4 loop
    if bitand(v, power(2, i + 10)) > 0 then
      v := qr_xor(v, 1335 * power(2, i));     -- gerador 0b10100110111
    end if;
  end loop;
  return qr_xor(p_fmt * 1024 + v, 21522);     -- mascara 0b101010000010010
end qr_bch_format;


function qr_bch_version(p_ver pls_integer) return pls_integer is
  v pls_integer := p_ver * 4096;              -- ver << 12
begin
  for i in reverse 0..5 loop
    if bitand(v, power(2, i + 12)) > 0 then
      v := qr_xor(v, 7973 * power(2, i));     -- gerador 0b1111100100101
    end if;
  end loop;
  return p_ver * 4096 + v;
end qr_bch_version;

--------------------------------------------------------------------------------
-- qr_place_format : bit i (menos significativo primeiro). Copia 1 desce a coluna
-- 8 e vira na linha 8; copia 2 percorre a linha 8 pela direita e desce a coluna 8.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_place_format : bit i (menos significativo primeiro). Copia 1 desce a coluna
-- 8 e vira na linha 8; copia 2 percorre a linha 8 pela direita e desce a coluna 8.
--------------------------------------------------------------------------------
procedure qr_place_format(p_m in out nocopy tqr, p_n pls_integer,
                          p_ecl varchar2, p_mask pls_integer) is
  l_ecbits pls_integer := case upper(p_ecl) when 'L' then 1 when 'M' then 0
                                            when 'Q' then 3 else 2 end;
  l_bits pls_integer;
  b pls_integer;
begin
  l_bits := qr_bch_format(l_ecbits * 8 + p_mask);
  for i in 0..14 loop
    b := case when bitand(l_bits, power(2, i)) > 0 then 1 else 0 end;
    if    i < 6 then p_m(i * p_n + 8)       := b;
    elsif i = 6 then p_m(7 * p_n + 8)       := b;
    elsif i = 7 then p_m(8 * p_n + 8)       := b;
    elsif i = 8 then p_m(8 * p_n + 7)       := b;
    else             p_m(8 * p_n + (14 - i)) := b;
    end if;
    if i < 8 then p_m(8 * p_n + (p_n - 1 - i)) := b;
    else          p_m((p_n - 15 + i) * p_n + 8) := b;
    end if;
  end loop;
  p_m((p_n - 8) * p_n + 8) := 1;              -- modulo escuro
end qr_place_format;

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
procedure qr_place_version(p_m in out nocopy tqr, p_n pls_integer,
                           p_ver pls_integer) is
  l_bits pls_integer;
  b pls_integer; r pls_integer; c pls_integer;
begin
  if p_ver < 7 then return; end if;
  l_bits := qr_bch_version(p_ver);
  for i in 0..17 loop
    b := case when bitand(l_bits, power(2, i)) > 0 then 1 else 0 end;
    r := trunc(i / 3);
    c := mod(i, 3);
    p_m((p_n - 11 + c) * p_n + r) := b;
    p_m(r * p_n + (p_n - 11 + c))  := b;
  end loop;
end qr_place_version;

--------------------------------------------------------------------------------
-- qr_penalty : as quatro regras de penalidade da norma, usadas para escolher a
-- mascara que produz o simbolo mais legivel.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- qr_penalty : as quatro regras de penalidade da norma, usadas para escolher a
-- mascara que produz o simbolo mais legivel.
--------------------------------------------------------------------------------
function qr_penalty(p_m tqr, p_n pls_integer) return pls_integer is
  s     pls_integer := 0;
  run   pls_integer;
  prev  pls_integer;
  dark  pls_integer := 0;
  ratio pls_integer;

  function px(r pls_integer, c pls_integer) return pls_integer is
  begin
    return p_m(r * p_n + c);
  end;
  -- regra 3: 1011101 0000 e seu espelho
  function run3(r pls_integer, c pls_integer, horiz boolean) return boolean is
    pat varchar2(11) := '10111010000';
    pat_inv varchar2(11) := '00001011101';
    s1 varchar2(11) := '';
  begin
    for i in 0..10 loop
      s1 := s1 || (case when horiz then px(r, c+i) else px(r+i, c) end);
    end loop;
    return s1 = pat or s1 = pat_inv;
  end;
begin
  for r in 0..p_n-1 loop                       -- regra 1: linhas
    run := 1; prev := px(r, 0);
    for c in 1..p_n-1 loop
      if px(r, c) = prev then run := run + 1;
      else
        if run >= 5 then s := s + 3 + (run - 5); end if;
        run := 1; prev := px(r, c);
      end if;
    end loop;
    if run >= 5 then s := s + 3 + (run - 5); end if;
  end loop;
  for c in 0..p_n-1 loop                       -- regra 1: colunas
    run := 1; prev := px(0, c);
    for r in 1..p_n-1 loop
      if px(r, c) = prev then run := run + 1;
      else
        if run >= 5 then s := s + 3 + (run - 5); end if;
        run := 1; prev := px(r, c);
      end if;
    end loop;
    if run >= 5 then s := s + 3 + (run - 5); end if;
  end loop;

  for r in 0..p_n-2 loop                       -- regra 2: blocos 2x2
    for c in 0..p_n-2 loop
      if px(r,c) = px(r,c+1) and px(r,c) = px(r+1,c) and px(r,c) = px(r+1,c+1) then
        s := s + 3;
      end if;
    end loop;
  end loop;

  for r in 0..p_n-1 loop                       -- regra 3
    for c in 0..p_n-11 loop
      if run3(r, c, true) then s := s + 40; end if;
    end loop;
  end loop;
  for c in 0..p_n-1 loop
    for r in 0..p_n-11 loop
      if run3(r, c, false) then s := s + 40; end if;
    end loop;
  end loop;

  for i in 0..p_n*p_n-1 loop                   -- regra 4: proporcao de escuros
    dark := dark + p_m(i);
  end loop;
  ratio := trunc(dark * 100 / (p_n * p_n));
  s := s + 10 * trunc(abs(ratio - 50) / 5);
  return s;
end qr_penalty;

--------------------------------------------------------------------------------
-- AddQRCode : gera um QR Code real, legivel por qualquer leitor.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Task 3.8: Generic Barcode Rendering
-- Note: PIX QR Code rendering: Use PL_FPDF_PIX.AddQRCodePIX()
--       Boleto barcode rendering: Use PL_FPDF_BOLETO.AddBarcodeBoleto()
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Codigos de barras lineares: CODE39, CODE128, EAN13, EAN8 e ITF14
--
-- Substitui o desenho decorativo anterior, que variava a largura das barras por
-- mod(ascii(caractere),2) e ignorava o parametro p_type: nao era nenhuma
-- simbologia real e nenhum leitor conseguia interpretar.
--
-- As simbologias abaixo foram validadas fora do banco contra o decodificador
-- zxing-cpp (47 de 47 codigos lidos corretamente). A referencia esta em
-- scripts/barcode_reference/.
--
-- Convencao interna: cada rotina devolve uma cadeia de modulos, '1' = barra,
-- '0' = espaco. O desenho e feito uma vez, agrupando modulos consecutivos.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- bc_ean_check : digito verificador de EAN/ITF (pesos 3 e 1, da direita)
--------------------------------------------------------------------------------
function bc_ean_check(p_digits varchar2) return pls_integer is
  l_soma pls_integer := 0;
  l_len  pls_integer := length(p_digits);
  l_peso pls_integer;
begin
  for i in 1..l_len loop
    l_peso := case when mod(l_len - i, 2) = 0 then 3 else 1 end;
    l_soma := l_soma + to_number(substr(p_digits, i, 1)) * l_peso;
  end loop;
  return mod(10 - mod(l_soma, 10), 10);
end bc_ean_check;

--------------------------------------------------------------------------------
-- bc_only_digits : mantem apenas digitos
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- bc_only_digits : mantem apenas digitos
--------------------------------------------------------------------------------
function bc_only_digits(p_str varchar2) return varchar2 is
begin
  return regexp_replace(p_str, '[^0-9]', '');
end bc_only_digits;

--------------------------------------------------------------------------------
-- bc_code39 : 9 elementos por caractere (barra/espaco alternados), n=1 / w=ratio,
--             delimitado por '*' e com um espaco estreito entre caracteres.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- bc_code39 : 9 elementos por caractere (barra/espaco alternados), n=1 / w=ratio,
--             delimitado por '*' e com um espaco estreito entre caracteres.
--------------------------------------------------------------------------------
function bc_code39(p_data varchar2, p_ratio pls_integer default 3) return varchar2 is
  l_txt  varchar2(4000) := '*' || upper(p_data) || '*';
  l_out  varchar2(32767);
  l_pos  pls_integer;
  l_pat  varchar2(9);
  l_w    pls_integer;
begin
  for i in 1..length(l_txt) loop
    l_pos := instr(co_bc39_chars, substr(l_txt, i, 1));
    if l_pos = 0 then
      raise_application_error(-20883,
        'CODE39 nao aceita o caractere ' || substr(l_txt, i, 1) ||
        '. Use 0-9, A-Z, espaco ou - . $ / + %');
    end if;
    l_pat := substr(co_bc39_pats, (l_pos - 1) * 9 + 1, 9);
    for j in 1..9 loop
      l_w := case when substr(l_pat, j, 1) = 'w' then p_ratio else 1 end;
      l_out := l_out || rpad(case when mod(j, 2) = 1 then '1' else '0' end, l_w,
                             case when mod(j, 2) = 1 then '1' else '0' end);
    end loop;
    if i < length(l_txt) then
      l_out := l_out || '0';                       -- separador entre caracteres
    end if;
  end loop;
  return l_out;
end bc_code39;

--------------------------------------------------------------------------------
-- bc_code128 : Code C (pares de digitos) quando o dado e numerico de tamanho
--              par; caso contrario Code B (ASCII 32..126). Checksum modulo 103.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- bc_code128 : Code C (pares de digitos) quando o dado e numerico de tamanho
--              par; caso contrario Code B (ASCII 32..126). Checksum modulo 103.
--------------------------------------------------------------------------------
function bc_code128(p_data varchar2) return varchar2 is
  type tcodes is table of pls_integer index by pls_integer;
  l_codes tcodes;
  l_n     pls_integer := 0;
  l_chk   pls_integer;
  l_out   varchar2(32767);
  l_pat   varchar2(7);
  l_ch    pls_integer;
begin
  if regexp_like(p_data, '^[0-9]+$') and mod(length(p_data), 2) = 0 then
    l_n := 1; l_codes(1) := 105;                   -- START C
    for i in 1..length(p_data)/2 loop
      l_n := l_n + 1;
      l_codes(l_n) := to_number(substr(p_data, (i-1)*2 + 1, 2));
    end loop;
  else
    l_n := 1; l_codes(1) := 104;                   -- START B
    for i in 1..length(p_data) loop
      l_ch := ascii(substr(p_data, i, 1));
      if l_ch < 32 or l_ch > 126 then
        raise_application_error(-20884,
          'CODE128 (Code B) aceita apenas caracteres ASCII de 32 a 126.');
      end if;
      l_n := l_n + 1;
      l_codes(l_n) := l_ch - 32;
    end loop;
  end if;

  l_chk := l_codes(1);
  for i in 2..l_n loop
    l_chk := l_chk + (i - 1) * l_codes(i);
  end loop;
  l_n := l_n + 1; l_codes(l_n) := mod(l_chk, 103);
  l_n := l_n + 1; l_codes(l_n) := 106;             -- STOP

  for i in 1..l_n loop
    l_pat := rtrim(substr(co_bc128, l_codes(i) * 7 + 1, 7));
    for j in 1..length(l_pat) loop
      l_out := l_out || rpad(case when mod(j, 2) = 1 then '1' else '0' end,
                             to_number(substr(l_pat, j, 1)),
                             case when mod(j, 2) = 1 then '1' else '0' end);
    end loop;
  end loop;
  return l_out;
end bc_code128;

--------------------------------------------------------------------------------
-- bc_ean : EAN-13 (13 digitos) e EAN-8 (8 digitos). Aceita o codigo sem o
--          verificador e o calcula.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- bc_ean : EAN-13 (13 digitos) e EAN-8 (8 digitos). Aceita o codigo sem o
--          verificador e o calcula.
--------------------------------------------------------------------------------
function bc_ean(p_data varchar2, p_len pls_integer) return varchar2 is
  l_d   varchar2(20) := bc_only_digits(p_data);
  l_out varchar2(32767);
  l_par varchar2(6);
  l_dig pls_integer;
begin
  if length(l_d) = p_len - 1 then
    l_d := l_d || to_char(bc_ean_check(l_d));
  end if;
  if length(l_d) != p_len then
    raise_application_error(-20885,
      'EAN' || p_len || ' exige ' || (p_len - 1) ||
      ' digitos (verificador calculado) ou ' || p_len || '.');
  end if;
  if to_number(substr(l_d, p_len, 1)) != bc_ean_check(substr(l_d, 1, p_len - 1)) then
    raise_application_error(-20886, 'EAN' || p_len || ': digito verificador invalido.');
  end if;

  l_out := '101';                                   -- guarda inicial
  if p_len = 13 then
    l_par := substr(co_bc_ean_par, to_number(substr(l_d, 1, 1)) * 6 + 1, 6);
    for i in 1..6 loop
      l_dig := to_number(substr(l_d, i + 1, 1));
      l_out := l_out || case when substr(l_par, i, 1) = 'L'
                             then substr(co_bc_ean_l, l_dig * 7 + 1, 7)
                             else substr(co_bc_ean_g, l_dig * 7 + 1, 7) end;
    end loop;
    l_out := l_out || '01010';                      -- guarda central
    for i in 8..13 loop
      l_dig := to_number(substr(l_d, i, 1));
      l_out := l_out || substr(co_bc_ean_r, l_dig * 7 + 1, 7);
    end loop;
  else
    for i in 1..4 loop
      l_dig := to_number(substr(l_d, i, 1));
      l_out := l_out || substr(co_bc_ean_l, l_dig * 7 + 1, 7);
    end loop;
    l_out := l_out || '01010';
    for i in 5..8 loop
      l_dig := to_number(substr(l_d, i, 1));
      l_out := l_out || substr(co_bc_ean_r, l_dig * 7 + 1, 7);
    end loop;
  end if;
  return l_out || '101';                            -- guarda final
end bc_ean;

--------------------------------------------------------------------------------
-- bc_itf14 : Interleaved 2 of 5 com 14 digitos (13 + verificador).
--            Cada par de digitos ocupa 5 barras (1o digito) intercaladas com
--            5 espacos (2o digito).
--------------------------------------------------------------------------------
-- bc_itf : Interleaved 2 of 5 puro — qualquer quantidade PAR de digitos, sem
--          verificador de simbologia.
--
-- E o que o boleto bancario usa: 44 digitos, e o digito de controle do boleto
-- fica DENTRO deles, na posicao 5, calculado pelo emissor e nao pela
-- simbologia. O ITF14 e um caso particular disto — 14 digitos, com verificador
-- proprio — e passou a ser construido sobre esta funcao.
--
-- Sem ela o codigo de barras de um boleto NAO podia ser desenhado:
-- AddBarcodeBoleto passava os 44 digitos como 'ITF14' e sempre levantava
-- ORA-20887.

--------------------------------------------------------------------------------
-- bc_itf14 : Interleaved 2 of 5 com 14 digitos (13 + verificador).
--            Cada par de digitos ocupa 5 barras (1o digito) intercaladas com
--            5 espacos (2o digito).
--------------------------------------------------------------------------------
-- bc_itf : Interleaved 2 of 5 puro — qualquer quantidade PAR de digitos, sem
--          verificador de simbologia.
--
-- E o que o boleto bancario usa: 44 digitos, e o digito de controle do boleto
-- fica DENTRO deles, na posicao 5, calculado pelo emissor e nao pela
-- simbologia. O ITF14 e um caso particular disto — 14 digitos, com verificador
-- proprio — e passou a ser construido sobre esta funcao.
--
-- Sem ela o codigo de barras de um boleto NAO podia ser desenhado:
-- AddBarcodeBoleto passava os 44 digitos como 'ITF14' e sempre levantava
-- ORA-20887.
function bc_itf(p_data varchar2, p_ratio pls_integer default 3) return varchar2 is
  l_d   varchar2(4000) := bc_only_digits(p_data);
  l_out varchar2(32767);
  l_a   varchar2(5);
  l_b   varchar2(5);
begin
  if l_d is null then
    raise_application_error(-20888, 'ITF: nenhum digito no conteudo.');
  end if;
  if mod(length(l_d), 2) = 1 then
    l_d := '0' || l_d;                              -- ITF exige quantidade par
  end if;

  l_out := '1010';                                  -- start: n n n n
  for i in 1 .. length(l_d) / 2 loop
    l_a := substr(co_bc_itf, to_number(substr(l_d, (i-1)*2 + 1, 1)) * 5 + 1, 5);
    l_b := substr(co_bc_itf, to_number(substr(l_d, (i-1)*2 + 2, 1)) * 5 + 1, 5);
    for j in 1..5 loop
      l_out := l_out || rpad('1', case when substr(l_a, j, 1) = 'w' then p_ratio else 1 end, '1');
      l_out := l_out || rpad('0', case when substr(l_b, j, 1) = 'w' then p_ratio else 1 end, '0');
    end loop;
  end loop;
  return l_out || rpad('1', p_ratio, '1') || '0' || '1';   -- stop: w n n
end bc_itf;


function bc_itf14(p_data varchar2, p_ratio pls_integer default 3) return varchar2 is
  l_d varchar2(20) := bc_only_digits(p_data);
begin
  if length(l_d) = 13 then
    l_d := l_d || to_char(bc_ean_check(l_d));
  end if;
  if length(l_d) != 14 then
    raise_application_error(-20887,
      'ITF14 exige 13 digitos (verificador calculado) ou 14.');
  end if;
  return bc_itf(l_d, p_ratio);
end bc_itf14;

--------------------------------------------------------------------------------
-- AddBarcode : desenha um codigo de barras real na pagina corrente.
--
-- A largura do modulo e derivada de p_width e do total de modulos da simbologia,
-- de modo que o codigo ocupe exatamente a largura pedida. Modulos escuros
-- consecutivos viram um unico retangulo.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- INFLATE (RFC 1951), portado de scripts/pdfinflate_reference/
--
-- Estado do fluxo de bits em variaveis de pacote em vez de um record passado
-- adiante: o decodificador de Huffman le UM bit por vez e e chamado uma vez por
-- simbolo, entao copiar um record a cada chamada dominaria o custo.
--
-- ATENCAO ao sentido dos bits, que e a armadilha classica: dentro de cada byte
-- o DEFLATE le do bit MENOS significativo para o mais, mas os codigos de
-- Huffman sao formados do MAIS significativo para o menos. Trocar os dois
-- produz saida plausivel por alguns bytes e lixo depois.
--------------------------------------------------------------------------------
PROCEDURE inf_init IS
  -- Percorre a lista com um CURSOR de posicao, sem encurtar a string.
  --
  -- A versao anterior fazia l_s := SUBSTR(l_s, l_p + 1) ate esvaziar, e caiu na
  -- armadilha do NULL: em Oracle, SUBSTR que devolve vazio e NULL, INSTR(NULL)
  -- e NULL, e 'EXIT WHEN NULL = 0' NAO e verdadeiro — comparacao com NULL da
  -- NULL, e o EXIT so dispara com TRUE. O laco rodava para sempre atribuindo
  -- NULL a indices cada vez maiores, e a tabela indexada crescia ate estourar a
  -- PGA (ORA-04036). E a mesma familia do 'IF NOT f() THEN' com BOOLEAN nulo
  -- que ja esta anotada no CLAUDE.md.
  --
  -- Aqui p_txt nunca e NULL e l_ini so cresce, entao o laco termina por
  -- construcao, sem depender de comparacao com NULL.
  PROCEDURE carrega(p_txt IN VARCHAR2, p_tab IN OUT NOCOPY tpi,
                    p_esperado IN PLS_INTEGER) IS
    l_v   PLS_INTEGER := 0;
    l_ini PLS_INTEGER := 1;
    l_p   PLS_INTEGER;
    l_n   PLS_INTEGER := NVL(LENGTHB(p_txt), 0);
  BEGIN
    WHILE l_ini <= l_n LOOP
      l_p := INSTR(p_txt, ',', l_ini);
      IF l_p = 0 THEN
        l_p := l_n + 1;
      END IF;
      p_tab(l_v) := TO_NUMBER(SUBSTR(p_txt, l_ini, l_p - l_ini));
      l_v := l_v + 1;
      l_ini := l_p + 1;
    END LOOP;

    -- Um laco de carga que sai com a quantidade errada e silencioso: as tabelas
    -- ficam curtas e o inflate falha muito depois, em outro lugar.
    IF l_v != p_esperado THEN
      RAISE_APPLICATION_ERROR(-20894,
        'INFLATE: tabela carregada com ' || l_v || ' entradas, esperado '
        || p_esperado);
    END IF;
  END carrega;
BEGIN
  IF g_inf_pronto THEN
    RETURN;
  END IF;
  carrega(co_inf_cbase,  g_inf_cbase,  29);   -- comprimentos 257..285
  carrega(co_inf_cextra, g_inf_cextra, 29);
  carrega(co_inf_dbase,  g_inf_dbase,  30);   -- distancias 0..29
  carrega(co_inf_dextra, g_inf_dextra, 30);
  carrega(co_inf_ordem,  g_inf_ordem,  19);   -- alfabeto de comprimentos
  g_inf_pronto := TRUE;
END inf_init;

-- le p_n bits, do menos significativo para o mais

-- le p_n bits, do menos significativo para o mais
FUNCTION inf_bits(p_n IN PLS_INTEGER) RETURN PLS_INTEGER IS
  l_v PLS_INTEGER;
BEGIN
  WHILE g_inf_nbits < p_n LOOP
    IF g_inf_pos > g_inf_len THEN
      RAISE_APPLICATION_ERROR(-20890,
        'INFLATE: os dados terminaram no meio de um bloco');
    END IF;
    g_inf_acum := g_inf_acum
                + TO_NUMBER(RAWTOHEX(DBMS_LOB.SUBSTR(g_inf_src, 1, g_inf_pos)),
                            'XX') * POWER(2, g_inf_nbits);
    g_inf_pos   := g_inf_pos + 1;
    g_inf_nbits := g_inf_nbits + 8;
  END LOOP;
  l_v := MOD(g_inf_acum, POWER(2, p_n));
  g_inf_acum  := TRUNC(g_inf_acum / POWER(2, p_n));
  g_inf_nbits := g_inf_nbits - p_n;
  RETURN l_v;
END inf_bits;

-- monta a tabela canonica a partir dos comprimentos de codigo
--
-- p_qual escolhe o destino: 1 literais/comprimentos, 2 distancias, 3 alfabeto
-- de comprimentos. Escrever direto na global evita copiar duas colecoes por
-- chamada, que foi o que estourou a PGA.

-- monta a tabela canonica a partir dos comprimentos de codigo
--
-- p_qual escolhe o destino: 1 literais/comprimentos, 2 distancias, 3 alfabeto
-- de comprimentos. Escrever direto na global evita copiar duas colecoes por
-- chamada, que foi o que estourou a PGA.
PROCEDURE inf_huff(
  p_comp IN tpi,
  p_ini  IN PLS_INTEGER,
  p_qtd  IN PLS_INTEGER,
  p_qual IN PLS_INTEGER
) IS
  l_cont  tpi;
  l_sim   tpi;
  l_offs  tpi;
  l_sobra PLS_INTEGER;
  l_c     PLS_INTEGER;
BEGIN
  FOR c IN 0 .. co_inf_max_bits LOOP
    l_cont(c) := 0;
  END LOOP;
  FOR i IN 0 .. p_qtd - 1 LOOP
    l_c := p_comp(p_ini + i);
    l_cont(l_c) := l_cont(l_c) + 1;
  END LOOP;
  IF l_cont(0) = p_qtd THEN
    RAISE_APPLICATION_ERROR(-20891, 'INFLATE: alfabeto sem nenhum codigo');
  END IF;

  -- Um alfabeto INCOMPLETO e legitimo quando ha um unico codigo (acontece nas
  -- distancias de um fluxo sem referencia para tras), mas um alfabeto com
  -- codigos demais para o comprimento e corrupcao.
  l_sobra := 1;
  FOR c IN 1 .. co_inf_max_bits LOOP
    l_sobra := l_sobra * 2 - l_cont(c);
    IF l_sobra < 0 THEN
      RAISE_APPLICATION_ERROR(-20891,
        'INFLATE: codigo de Huffman invalido em ' || c || ' bits');
    END IF;
  END LOOP;

  l_offs(1) := 0;
  FOR c IN 1 .. co_inf_max_bits - 1 LOOP
    l_offs(c + 1) := l_offs(c) + l_cont(c);
  END LOOP;
  FOR i IN 0 .. p_qtd - 1 LOOP
    l_c := p_comp(p_ini + i);
    IF l_c > 0 THEN
      l_sim(l_offs(l_c)) := i;
      l_offs(l_c) := l_offs(l_c) + 1;
    END IF;
  END LOOP;

  CASE p_qual
    WHEN 1 THEN g_inf_lit_c := l_cont; g_inf_lit_s := l_sim;
    WHEN 2 THEN g_inf_dst_c := l_cont; g_inf_dst_s := l_sim;
    ELSE        g_inf_cl_c  := l_cont; g_inf_cl_s  := l_sim;
  END CASE;
END inf_huff;

-- decodifica um simbolo da tabela p_qual
-- os codigos vem do bit MAIS significativo para o menos

-- decodifica um simbolo da tabela p_qual
-- os codigos vem do bit MAIS significativo para o menos
FUNCTION inf_sim(p_qual IN PLS_INTEGER) RETURN PLS_INTEGER IS
  l_cod  PLS_INTEGER := 0;
  l_prim PLS_INTEGER := 0;
  l_ind  PLS_INTEGER := 0;
  l_qtd  PLS_INTEGER;
BEGIN
  FOR c IN 1 .. co_inf_max_bits LOOP
    l_cod := l_cod + inf_bits(1);
    l_qtd := CASE p_qual WHEN 1 THEN g_inf_lit_c(c)
                         WHEN 2 THEN g_inf_dst_c(c)
                         ELSE        g_inf_cl_c(c) END;
    IF l_cod - l_prim < l_qtd THEN
      RETURN CASE p_qual
               WHEN 1 THEN g_inf_lit_s(l_ind + (l_cod - l_prim))
               WHEN 2 THEN g_inf_dst_s(l_ind + (l_cod - l_prim))
               ELSE        g_inf_cl_s(l_ind + (l_cod - l_prim)) END;
    END IF;
    l_ind  := l_ind + l_qtd;
    l_prim := (l_prim + l_qtd) * 2;
    l_cod  := l_cod * 2;
  END LOOP;
  RAISE_APPLICATION_ERROR(-20891, 'INFLATE: codigo de Huffman nao encontrado');
END inf_sim;

--------------------------------------------------------------------------------
-- pdf_inflate: DEFLATE cru (RFC 1951) -> BLOB
--
-- A saida vai para o BLOB em lotes, e a janela de 32 KB fica numa tabela
-- CIRCULAR indexada por MOD(posicao, 32768). A primeira versao acumulava a
-- saida inteira numa tabela indexada e apagava elemento a elemento; como o
-- DELETE de uma associative array nao devolve memoria, o consumo crescia com o
-- total descomprimido — e, somado ao record de Huffman copiado a cada simbolo,
-- estourou a PGA (ORA-04036) em 688 bytes de saida.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- pdf_inflate: DEFLATE cru (RFC 1951) -> BLOB
--
-- A saida vai para o BLOB em lotes, e a janela de 32 KB fica numa tabela
-- CIRCULAR indexada por MOD(posicao, 32768). A primeira versao acumulava a
-- saida inteira numa tabela indexada e apagava elemento a elemento; como o
-- DELETE de uma associative array nao devolve memoria, o consumo crescia com o
-- total descomprimido — e, somado ao record de Huffman copiado a cada simbolo,
-- estourou a PGA (ORA-04036) em 688 bytes de saida.
--------------------------------------------------------------------------------
PROCEDURE pdf_inflate(
  p_src IN            BLOB,
  o_dst IN OUT NOCOPY BLOB,
  p_max IN            PLS_INTEGER DEFAULT 8388608
) IS
  l_final PLS_INTEGER;
  l_tipo  PLS_INTEGER;
  l_comp  tpi;
  l_sim   PLS_INTEGER;
  l_n     PLS_INTEGER;
  l_dist  PLS_INTEGER;
  l_i     PLS_INTEGER;
  l_tam   PLS_INTEGER;
  l_ntam  PLS_INTEGER;
  l_hex   VARCHAR2(32767);
  l_qtd   PLS_INTEGER := 0;      -- total ja produzido

  PROCEDURE descarregar IS
  BEGIN
    IF l_hex IS NOT NULL THEN
      DBMS_LOB.WRITEAPPEND(o_dst, LENGTH(l_hex) / 2, HEXTORAW(l_hex));
      l_hex := NULL;
    END IF;
  END descarregar;

  PROCEDURE emitir(p_b IN PLS_INTEGER) IS
  BEGIN
    -- Teto de saida. Estava na referencia e eu nao o portei, o que e uma falha
    -- de seguranca por si: um PDF de terceiro e entrada NAO CONFIAVEL, e um
    -- inflate sem teto e vetor classico de zip bomb — alguns KB comprimidos
    -- viram gigabytes e derrubam a sessao com ORA-04036, que e o que se viu.
    IF l_qtd >= p_max THEN
      RAISE_APPLICATION_ERROR(-20893,
        'INFLATE: a saida passou de ' || p_max || ' bytes. Entrada corrompida, '
        || 'zip bomb, ou limite baixo demais para este stream.');
    END IF;
    g_inf_jan(MOD(l_qtd, co_inf_janela)) := p_b;
    l_qtd := l_qtd + 1;
    l_hex := l_hex || g_aes_hex(p_b);
    IF LENGTH(l_hex) >= 16000 THEN
      descarregar;
    END IF;
  END emitir;
BEGIN
  inf_init;
  aes_init;                     -- g_aes_hex: byte -> hexadecimal
  g_inf_jan.DELETE;
  g_inf_src   := p_src;
  g_inf_len   := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  g_inf_pos   := 1;
  g_inf_acum  := 0;
  g_inf_nbits := 0;

  LOOP
    l_final := inf_bits(1);
    l_tipo  := inf_bits(2);

    IF l_tipo = 0 THEN                                   -- bloco armazenado
      g_inf_acum  := 0;                                  -- alinha no byte
      g_inf_nbits := 0;
      IF g_inf_pos + 3 > g_inf_len THEN
        RAISE_APPLICATION_ERROR(-20890, 'INFLATE: bloco armazenado truncado');
      END IF;
      l_tam  := inf_bits(16);
      l_ntam := inf_bits(16);
      IF l_tam != 65535 - l_ntam THEN
        RAISE_APPLICATION_ERROR(-20891,
          'INFLATE: LEN e NLEN nao sao complementares');
      END IF;
      IF g_inf_pos + l_tam - 1 > g_inf_len THEN
        RAISE_APPLICATION_ERROR(-20890,
          'INFLATE: bloco armazenado passa do fim dos dados');
      END IF;
      FOR k IN 1 .. l_tam LOOP
        emitir(TO_NUMBER(
          RAWTOHEX(DBMS_LOB.SUBSTR(g_inf_src, 1, g_inf_pos)), 'XX'));
        g_inf_pos := g_inf_pos + 1;
      END LOOP;

    ELSIF l_tipo IN (1, 2) THEN
      IF l_tipo = 1 THEN
        -- Huffman fixo: 0..143 em 8 bits, 144..255 em 9, 256..279 em 7,
        -- 280..287 em 8; distancias todas em 5
        l_comp.DELETE;
        FOR i IN 0 .. 143 LOOP l_comp(i) := 8; END LOOP;
        FOR i IN 144 .. 255 LOOP l_comp(i) := 9; END LOOP;
        FOR i IN 256 .. 279 LOOP l_comp(i) := 7; END LOOP;
        FOR i IN 280 .. 287 LOOP l_comp(i) := 8; END LOOP;
        inf_huff(l_comp, 0, 288, 1);
        l_comp.DELETE;
        FOR i IN 0 .. 29 LOOP l_comp(i) := 5; END LOOP;
        inf_huff(l_comp, 0, 30, 2);
      ELSE
        DECLARE
          l_nlit  PLS_INTEGER := inf_bits(5) + 257;
          l_ndist PLS_INTEGER := inf_bits(5) + 1;
          l_ncl   PLS_INTEGER := inf_bits(4) + 4;
          l_cl    tpi;
          l_k     PLS_INTEGER := 0;
          l_rep   PLS_INTEGER;
          l_val   PLS_INTEGER;
        BEGIN
          IF l_nlit > 286 OR l_ndist > 30 THEN
            RAISE_APPLICATION_ERROR(-20891,
              'INFLATE: contagem de codigos fora da especificacao');
          END IF;
          FOR i IN 0 .. 18 LOOP l_cl(i) := 0; END LOOP;
          FOR i IN 0 .. l_ncl - 1 LOOP
            l_cl(g_inf_ordem(i)) := inf_bits(3);
          END LOOP;
          inf_huff(l_cl, 0, 19, 3);

          l_comp.DELETE;
          WHILE l_k < l_nlit + l_ndist LOOP
            l_sim := inf_sim(3);
            IF l_sim < 16 THEN
              l_comp(l_k) := l_sim; l_k := l_k + 1;
            ELSE
              IF l_sim = 16 THEN
                IF l_k = 0 THEN
                  RAISE_APPLICATION_ERROR(-20891,
                    'INFLATE: repeticao sem comprimento anterior');
                END IF;
                l_val := l_comp(l_k - 1);
                l_rep := 3 + inf_bits(2);
              ELSIF l_sim = 17 THEN
                l_val := 0; l_rep := 3 + inf_bits(3);
              ELSE
                l_val := 0; l_rep := 11 + inf_bits(7);
              END IF;
              FOR r IN 1 .. l_rep LOOP
                l_comp(l_k) := l_val; l_k := l_k + 1;
              END LOOP;
            END IF;
          END LOOP;
          IF l_k > l_nlit + l_ndist THEN
            RAISE_APPLICATION_ERROR(-20891,
              'INFLATE: comprimentos passaram do alfabeto');
          END IF;
          inf_huff(l_comp, 0, l_nlit, 1);
          inf_huff(l_comp, l_nlit, l_ndist, 2);
        END;
      END IF;

      LOOP
        l_sim := inf_sim(1);
        EXIT WHEN l_sim = 256;
        IF l_sim < 256 THEN
          emitir(l_sim);
        ELSE
          l_i := l_sim - 257;
          IF l_i > 28 THEN
            RAISE_APPLICATION_ERROR(-20891,
              'INFLATE: codigo de comprimento ' || l_sim || ' invalido');
          END IF;
          l_n := g_inf_cbase(l_i) + inf_bits(g_inf_cextra(l_i));
          l_i := inf_sim(2);
          IF l_i > 29 THEN
            RAISE_APPLICATION_ERROR(-20891,
              'INFLATE: codigo de distancia ' || l_i || ' invalido');
          END IF;
          l_dist := g_inf_dbase(l_i) + inf_bits(g_inf_dextra(l_i));
          IF l_dist > l_qtd THEN
            RAISE_APPLICATION_ERROR(-20891,
              'INFLATE: distancia aponta antes do inicio dos dados');
          END IF;
          -- A copia PODE se sobrepor: com distancia 1 e comprimento 100 o mesmo
          -- byte se repete cem vezes, porque a origem avanca junto com o
          -- destino. Copiar de uma vez daria resultado errado.
          FOR k IN 0 .. l_n - 1 LOOP
            emitir(g_inf_jan(MOD(l_qtd - l_dist, co_inf_janela)));
          END LOOP;
        END IF;
      END LOOP;
    ELSE
      RAISE_APPLICATION_ERROR(-20891,
        'INFLATE: tipo de bloco 3 e reservado');
    END IF;

    EXIT WHEN l_final = 1;
  END LOOP;

  descarregar;
  g_inf_jan.DELETE;             -- devolve a janela; o BLOB ja tem tudo
  g_inf_src := NULL;
END pdf_inflate;

--------------------------------------------------------------------------------
-- inflate: tira a casca zlib (RFC 1950), que e o /FlateDecode do PDF
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- inflate: tira a casca zlib (RFC 1950), que e o /FlateDecode do PDF
--------------------------------------------------------------------------------
PROCEDURE inflate(
  p_src IN            BLOB,
  o_dst IN OUT NOCOPY BLOB,
  p_max IN            PLS_INTEGER DEFAULT 8388608
) IS
  l_cmf PLS_INTEGER;
  l_flg PLS_INTEGER;
  l_n   PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_cru BLOB;
BEGIN
  IF l_n < 6 THEN
    RAISE_APPLICATION_ERROR(-20890, 'FlateDecode: stream curto demais');
  END IF;
  l_cmf := TO_NUMBER(RAWTOHEX(DBMS_LOB.SUBSTR(p_src, 1, 1)), 'XX');
  l_flg := TO_NUMBER(RAWTOHEX(DBMS_LOB.SUBSTR(p_src, 1, 2)), 'XX');
  IF BITAND(l_cmf, 15) != 8 THEN
    RAISE_APPLICATION_ERROR(-20892,
      'FlateDecode: metodo de compressao ' || BITAND(l_cmf, 15)
      || ' nao e deflate');
  END IF;
  IF MOD(l_cmf * 256 + l_flg, 31) != 0 THEN
    RAISE_APPLICATION_ERROR(-20892,
      'FlateDecode: cabecalho zlib com verificacao invalida');
  END IF;
  IF BITAND(l_flg, 32) != 0 THEN
    RAISE_APPLICATION_ERROR(-20892,
      'FlateDecode: zlib com dicionario predefinido nao suportado');
  END IF;

  -- o miolo, sem os 2 bytes de cabecalho e sem os 4 do Adler-32
  DBMS_LOB.CREATETEMPORARY(l_cru, TRUE);
  DBMS_LOB.COPY(l_cru, p_src, l_n - 6, 1, 3);
  pdf_inflate(l_cru, o_dst, p_max);
  DBMS_LOB.FREETEMPORARY(l_cru);
END inflate;


--------------------------------------------------------------------------------
-- DEFLATE (RFC 1951) na direcao de COMPRIMIR
--
-- Portado de scripts/pdfdeflate_reference/, validado contra o zlib (32/32) e
-- contra o MuPDF abrindo um PDF com o fluxo comprimido por ele.
--
-- Decisao por decisao igual a referencia — mesma dispersao, mesmo limite de
-- corrente, mesmo desempate. Nao e capricho: e o que permite ao teste comparar
-- BYTE A BYTE o que o banco produz com o que a referencia produz. Um deflate
-- "equivalente mas diferente" so poderia ser conferido descomprimindo, e ai um
-- erro de escrita que o proprio inflate da casa tolera passaria despercebido.
--
-- ATENCAO ao sentido dos bits, a mesma armadilha do inflate: dentro de cada
-- byte o DEFLATE grava do bit MENOS significativo para o mais, mas os codigos
-- de Huffman se formam do MAIS significativo para o menos. Por isso ha duas
-- rotinas, def_bits e def_codigo, e trocar uma pela outra produz um fluxo que
-- descomprime alguns bytes e depois vira lixo.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- DEFLATE (RFC 1951) na direcao de COMPRIMIR
--
-- Portado de scripts/pdfdeflate_reference/, validado contra o zlib (32/32) e
-- contra o MuPDF abrindo um PDF com o fluxo comprimido por ele.
--
-- Decisao por decisao igual a referencia — mesma dispersao, mesmo limite de
-- corrente, mesmo desempate. Nao e capricho: e o que permite ao teste comparar
-- BYTE A BYTE o que o banco produz com o que a referencia produz. Um deflate
-- "equivalente mas diferente" so poderia ser conferido descomprimindo, e ai um
-- erro de escrita que o proprio inflate da casa tolera passaria despercebido.
--
-- ATENCAO ao sentido dos bits, a mesma armadilha do inflate: dentro de cada
-- byte o DEFLATE grava do bit MENOS significativo para o mais, mas os codigos
-- de Huffman se formam do MAIS significativo para o menos. Por isso ha duas
-- rotinas, def_bits e def_codigo, e trocar uma pela outra produz um fluxo que
-- descomprime alguns bytes e depois vira lixo.
--------------------------------------------------------------------------------
PROCEDURE def_descarregar(o_dst IN OUT NOCOPY BLOB) IS
BEGIN
  IF g_def_hex IS NOT NULL THEN
    DBMS_LOB.WRITEAPPEND(o_dst, LENGTH(g_def_hex) / 2, HEXTORAW(g_def_hex));
    g_def_hex := NULL;
  END IF;
END def_descarregar;


PROCEDURE def_byte(p_b IN PLS_INTEGER, o_dst IN OUT NOCOPY BLOB) IS
BEGIN
  g_def_hex := g_def_hex || g_aes_hex(p_b);
  IF LENGTH(g_def_hex) >= 16000 THEN
    def_descarregar(o_dst);
  END IF;
END def_byte;

-- bits do menos significativo para o mais (o sentido do fluxo)

-- bits do menos significativo para o mais (o sentido do fluxo)
PROCEDURE def_bits(p_v IN PLS_INTEGER, p_n IN PLS_INTEGER,
                   o_dst IN OUT NOCOPY BLOB) IS
BEGIN
  g_def_acum  := g_def_acum
               + BITAND(p_v, POWER(2, p_n) - 1) * POWER(2, g_def_nbits);
  g_def_nbits := g_def_nbits + p_n;
  WHILE g_def_nbits >= 8 LOOP
    def_byte(MOD(g_def_acum, 256), o_dst);
    g_def_acum  := TRUNC(g_def_acum / 256);
    g_def_nbits := g_def_nbits - 8;
  END LOOP;
END def_bits;

-- um codigo de Huffman: bit mais significativo primeiro

-- um codigo de Huffman: bit mais significativo primeiro
PROCEDURE def_codigo(p_v IN PLS_INTEGER, p_n IN PLS_INTEGER,
                     o_dst IN OUT NOCOPY BLOB) IS
BEGIN
  FOR i IN REVERSE 0 .. p_n - 1 LOOP
    def_bits(MOD(TRUNC(p_v / POWER(2, i)), 2), 1, o_dst);
  END LOOP;
END def_codigo;

-- literal ou comprimento na arvore FIXA (RFC 1951, 3.2.6). Sao quatro faixas,
-- e trocar uma pela outra da um fluxo plausivel por alguns bytes e lixo depois.

-- literal ou comprimento na arvore FIXA (RFC 1951, 3.2.6). Sao quatro faixas,
-- e trocar uma pela outra da um fluxo plausivel por alguns bytes e lixo depois.
PROCEDURE def_lit(p_sim IN PLS_INTEGER, o_dst IN OUT NOCOPY BLOB) IS
BEGIN
  IF p_sim <= 143 THEN
    def_codigo(48 + p_sim, 8, o_dst);
  ELSIF p_sim <= 255 THEN
    def_codigo(400 + p_sim - 144, 9, o_dst);
  ELSIF p_sim <= 279 THEN
    def_codigo(p_sim - 256, 7, o_dst);
  ELSE
    def_codigo(192 + p_sim - 280, 8, o_dst);
  END IF;
END def_lit;

-- Blocos ARMAZENADOS (BTYPE=00): 5 bytes de cabecalho por pedaco de 65535 e o
-- dado intacto. E o que impede o resultado de ficar MAIOR que a entrada — dado
-- incompressivel cresce ~5% com Huffman fixa, e num PDF isso e regressao: o
-- arquivo aumenta e ainda ganha um filtro para o leitor desfazer.

-- Blocos ARMAZENADOS (BTYPE=00): 5 bytes de cabecalho por pedaco de 65535 e o
-- dado intacto. E o que impede o resultado de ficar MAIOR que a entrada — dado
-- incompressivel cresce ~5% com Huffman fixa, e num PDF isso e regressao: o
-- arquivo aumenta e ainda ganha um filtro para o leitor desfazer.
PROCEDURE def_armazenado(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB) IS
  l_n    PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_pos  PLS_INTEGER := 1;
  l_tam  PLS_INTEGER;
  l_fim  PLS_INTEGER;
BEGIN
  LOOP
    l_tam := LEAST(65535, l_n - l_pos + 1);
    l_fim := CASE WHEN l_pos + l_tam > l_n THEN 1 ELSE 0 END;
    def_byte(l_fim, o_dst);                       -- BFINAL, BTYPE=00
    def_byte(MOD(l_tam, 256), o_dst);
    def_byte(TRUNC(l_tam / 256), o_dst);
    def_byte(255 - MOD(l_tam, 256), o_dst);
    def_byte(255 - TRUNC(l_tam / 256), o_dst);
    def_descarregar(o_dst);
    IF l_tam > 0 THEN
      DBMS_LOB.COPY(o_dst, p_src, l_tam, DBMS_LOB.GETLENGTH(o_dst) + 1, l_pos);
    END IF;
    l_pos := l_pos + l_tam;
    EXIT WHEN l_fim = 1;
  END LOOP;
END def_armazenado;

-- LZ77 + Huffman fixa. Quem decide se vale a pena e o deflate, comparando
-- o tamanho com o do bloco armazenado.

-- LZ77 + Huffman fixa. Quem decide se vale a pena e o deflate, comparando
-- o tamanho com o do bloco armazenado.
PROCEDURE def_comprimido(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB) IS
  l_n    PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_i    PLS_INTEGER;
  l_h    PLS_INTEGER;
  l_cand PLS_INTEGER;
  l_vis  PLS_INTEGER;
  l_tam  PLS_INTEGER;
  l_lim  PLS_INTEGER;
  l_mt   PLS_INTEGER;   -- melhor tamanho
  l_md   PLS_INTEGER;   -- melhor distancia
  l_k    PLS_INTEGER;
  l_cod  PLS_INTEGER;
  l_hex  VARCHAR2(32767);
  l_pos  PLS_INTEGER;

  FUNCTION disp(p_i IN PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN
    -- a mesma dispersao da referencia: tres bytes em 15 bits
    RETURN BITAND(g_def_ent(p_i) * 1024
                  + g_def_ent(p_i + 1) * 32 + g_def_ent(p_i + 2),
                  co_def_hash);
  END disp;
BEGIN
  -- entrada em memoria, byte a byte: o casamento le posicoes arbitrarias para
  -- tras, e ir ao LOB a cada byte custaria caro demais
  g_def_ent.DELETE; g_def_cab.DELETE; g_def_ant.DELETE;
  l_pos := 1;
  WHILE l_pos <= l_n LOOP
    l_hex := RAWTOHEX(DBMS_LOB.SUBSTR(p_src, LEAST(2000, l_n - l_pos + 1),
                                      l_pos));
    FOR k IN 0 .. LENGTH(l_hex) / 2 - 1 LOOP
      g_def_ent(l_pos - 1 + k) := TO_NUMBER(SUBSTR(l_hex, k * 2 + 1, 2), 'XX');
    END LOOP;
    l_pos := l_pos + LENGTH(l_hex) / 2;
  END LOOP;

  def_bits(1, 1, o_dst);            -- BFINAL
  def_bits(1, 2, o_dst);            -- BTYPE = 01, Huffman fixa

  l_i := 0;
  WHILE l_i < l_n LOOP
    l_mt := 0;
    l_md := 0;
    IF l_i + co_def_cas_min <= l_n THEN
      l_h    := disp(l_i);
      -- NVL(g_def_cab(l_h), -1) NAO serve: ler um indice que nao existe numa
      -- tabela indexada levanta NO_DATA_FOUND antes de o NVL ver qualquer
      -- coisa. E preciso perguntar com EXISTS.
      l_cand := CASE WHEN g_def_cab.EXISTS(l_h) THEN g_def_cab(l_h) ELSE -1 END;
      l_vis  := 0;
      WHILE l_cand >= 0 AND l_vis < co_def_corrente
            AND l_i - l_cand <= co_def_janela LOOP
        l_vis := l_vis + 1;
        l_tam := 0;
        l_lim := LEAST(co_def_cas_max, l_n - l_i);
        WHILE l_tam < l_lim
              AND g_def_ent(l_cand + l_tam) = g_def_ent(l_i + l_tam) LOOP
          l_tam := l_tam + 1;
        END LOOP;
        -- desempate pelo primeiro achado: e o mais PROXIMO, e distancia menor
        -- custa menos bits
        IF l_tam > l_mt THEN
          l_mt := l_tam;
          l_md := l_i - l_cand;
          EXIT WHEN l_tam >= co_def_cas_max;
        END IF;
        l_cand := CASE WHEN g_def_ant.EXISTS(l_cand) THEN g_def_ant(l_cand)
                       ELSE -1 END;
      END LOOP;
      g_def_ant(l_i) := CASE WHEN g_def_cab.EXISTS(l_h) THEN g_def_cab(l_h)
                             ELSE -1 END;
      g_def_cab(l_h) := l_i;
    END IF;

    IF l_mt >= co_def_cas_min THEN
      -- comprimento: acha o codigo 257..285 cuja base cobre l_mt
      l_cod := 0;
      FOR c IN 0 .. 28 LOOP
        EXIT WHEN g_inf_cbase(c) > l_mt;
        l_cod := c;
      END LOOP;
      def_lit(257 + l_cod, o_dst);
      IF g_inf_cextra(l_cod) > 0 THEN
        def_bits(l_mt - g_inf_cbase(l_cod), g_inf_cextra(l_cod), o_dst);
      END IF;

      -- distancia: 5 bits fixos, sempre
      l_cod := 0;
      FOR c IN 0 .. 29 LOOP
        EXIT WHEN g_inf_dbase(c) > l_md;
        l_cod := c;
      END LOOP;
      def_codigo(l_cod, 5, o_dst);
      IF g_inf_dextra(l_cod) > 0 THEN
        def_bits(l_md - g_inf_dbase(l_cod), g_inf_dextra(l_cod), o_dst);
      END IF;

      -- as posicoes cobertas pelo casamento tambem entram na corrente, senao
      -- casamentos futuros perdem candidatos
      l_k := l_i + 1;
      WHILE l_k < l_i + l_mt AND l_k + co_def_cas_min <= l_n LOOP
        l_h := disp(l_k);
        g_def_ant(l_k) := CASE WHEN g_def_cab.EXISTS(l_h) THEN g_def_cab(l_h)
                               ELSE -1 END;
        g_def_cab(l_h) := l_k;
        l_k := l_k + 1;
      END LOOP;
      l_i := l_i + l_mt;
    ELSE
      def_lit(g_def_ent(l_i), o_dst);
      l_i := l_i + 1;
    END IF;
  END LOOP;

  def_lit(256, o_dst);              -- fim do bloco
  IF g_def_nbits > 0 THEN           -- alinha no byte
    def_byte(MOD(g_def_acum, 256), o_dst);
    g_def_acum  := 0;
    g_def_nbits := 0;
  END IF;
  def_descarregar(o_dst);
  g_def_ent.DELETE; g_def_cab.DELETE; g_def_ant.DELETE;
END def_comprimido;

-- Adler-32 (RFC 1950), o rodape do envelope zlib

-- Adler-32 (RFC 1950), o rodape do envelope zlib
FUNCTION def_adler(p_src IN BLOB) RETURN NUMBER IS
  l_a   PLS_INTEGER := 1;
  l_b   PLS_INTEGER := 0;
  l_n   PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_pos PLS_INTEGER := 1;
  l_hex VARCHAR2(32767);
  l_res NUMBER;
BEGIN
  WHILE l_pos <= l_n LOOP
    l_hex := RAWTOHEX(DBMS_LOB.SUBSTR(p_src, LEAST(2000, l_n - l_pos + 1),
                                      l_pos));
    FOR k IN 0 .. LENGTH(l_hex) / 2 - 1 LOOP
      l_a := MOD(l_a + TO_NUMBER(SUBSTR(l_hex, k * 2 + 1, 2), 'XX'), 65521);
      l_b := MOD(l_b + l_a, 65521);
    END LOOP;
    l_pos := l_pos + LENGTH(l_hex) / 2;
  END LOOP;
  -- l_b * 65536 em aritmetica de PLS_INTEGER ESTOURA: l_b vai ate 65520, e o
  -- produto passa de 2147483647 (ORA-01426). O Adler-32 e um valor de 32 bits
  -- SEM SINAL, e PLS_INTEGER tem sinal — a mesma armadilha do /P das permissoes.
  -- Basta a conta acontecer em NUMBER.
  l_res := l_b;
  RETURN l_res * 65536 + l_a;
END def_adler;

--------------------------------------------------------------------------------
-- deflate: o fluxo zlib completo (RFC 1950) — cabecalho, DEFLATE, Adler-32
--
-- 0x78 0x9C e o par canonico: CMF = 0x78 (deflate, janela de 32 KB) e FLG
-- escolhido para que CMF*256+FLG seja multiplo de 31, sem dicionario.
--
-- Entre comprimir e armazenar escolhe o MENOR, e a escolha e deterministica:
-- e o mesmo criterio da referencia, para que os dois produzam os mesmos bytes.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- deflate: o fluxo zlib completo (RFC 1950) — cabecalho, DEFLATE, Adler-32
--
-- 0x78 0x9C e o par canonico: CMF = 0x78 (deflate, janela de 32 KB) e FLG
-- escolhido para que CMF*256+FLG seja multiplo de 31, sem dicionario.
--
-- Entre comprimir e armazenar escolhe o MENOR, e a escolha e deterministica:
-- e o mesmo criterio da referencia, para que os dois produzam os mesmos bytes.
--------------------------------------------------------------------------------
PROCEDURE deflate(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB) IS
  l_n     PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_comp  BLOB;
  l_arm   BLOB;
  l_som   NUMBER;
BEGIN
  inf_init;                         -- carrega as tabelas de comprimento/distancia
  aes_init;                         -- g_aes_hex: byte -> hexadecimal
  DBMS_LOB.WRITEAPPEND(o_dst, 2, HEXTORAW('789C'));

  DBMS_LOB.CREATETEMPORARY(l_arm, TRUE);
  g_def_hex := NULL; g_def_acum := 0; g_def_nbits := 0;
  def_armazenado(p_src, l_arm);
  def_descarregar(l_arm);

  IF l_n > 0 AND l_n <= co_def_max_comp THEN
    DBMS_LOB.CREATETEMPORARY(l_comp, TRUE);
    g_def_hex := NULL; g_def_acum := 0; g_def_nbits := 0;
    def_comprimido(p_src, l_comp);
    IF DBMS_LOB.GETLENGTH(l_comp) <= DBMS_LOB.GETLENGTH(l_arm) THEN
      DBMS_LOB.APPEND(o_dst, l_comp);
    ELSE
      DBMS_LOB.APPEND(o_dst, l_arm);
    END IF;
    DBMS_LOB.FREETEMPORARY(l_comp);
  ELSE
    DBMS_LOB.APPEND(o_dst, l_arm);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_arm);

  l_som := def_adler(p_src);
  DBMS_LOB.WRITEAPPEND(o_dst, 4,
    HEXTORAW(LPAD(TO_CHAR(l_som, 'FM0XXXXXXX'), 8, '0')));
END deflate;

--------------------------------------------------------------------------------
-- Marcas d'agua e overlays: operadores do fluxo de conteudo
--
-- Portado de scripts/pdfoverlay_reference/, validado contra o MuPDF (18/18).
--
-- O que existia antes (generate_watermark_stream e irmas) nao era PDF valido:
-- 'TO_CHAR(rotacao) || '' rotate''' nao e operador — rotacao no PDF e matriz,
-- em Tm para texto e em cm para imagem — e a cor da marca d'agua estava fixa
-- em cinza, ignorando o parametro. Como OutputModifiedPDF recusava com
-- ORA-20845, isso nunca chegou a ser gravado num arquivo.
--------------------------------------------------------------------------------
-- ovl_num: numero no formato do PDF (ponto decimal, sem notacao cientifica)
FUNCTION crypto_md5(p_src IN RAW) RETURN RAW IS
  l_hash RAW(16);
BEGIN
  IF p_src IS NULL THEN
    RETURN NULL;                       -- STANDARD_HASH recusa entrada nula
  END IF;
  SELECT STANDARD_HASH(p_src, 'MD5') INTO l_hash FROM dual;
  RETURN l_hash;
END crypto_md5;


FUNCTION crypto_rc4(p_src IN RAW, p_key IN RAW) RETURN RAW IS
  -- O resultado e montado em hexadecimal, dois caracteres por byte, entao o
  -- teto real desta funcao e 16383 bytes — nao os 32767 do RAW. Acima disso
  -- use crypto_rc4_blob, que carrega o estado da cifra entre os pedacos.
  co_max CONSTANT PLS_INTEGER := 16383;
  l_s    tpi;
  l_i    PLS_INTEGER := 0;
  l_j    PLS_INTEGER := 0;
  l_t    PLS_INTEGER;
  l_klen PLS_INTEGER := NVL(UTL_RAW.LENGTH(p_key), 0);
  l_dlen PLS_INTEGER := NVL(UTL_RAW.LENGTH(p_src), 0);
  l_hex  VARCHAR2(32767);
BEGIN
  IF l_dlen = 0 THEN
    RETURN p_src;
  END IF;
  IF l_klen = 0 THEN
    RAISE_APPLICATION_ERROR(-20863, 'RC4: chave vazia');
  END IF;
  IF l_dlen > co_max THEN
    RAISE_APPLICATION_ERROR(-20864,
      'RC4: ' || l_dlen || ' bytes excede o limite de ' || co_max
      || ' desta funcao. Use crypto_rc4_blob.');
  END IF;

  -- key-scheduling
  FOR x IN 0 .. 255 LOOP
    l_s(x) := x;
  END LOOP;
  FOR x IN 0 .. 255 LOOP
    l_j := MOD(l_j + l_s(x)
               + TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(p_key, MOD(x, l_klen) + 1, 1)), 'XX'),
               256);
    l_t := l_s(x); l_s(x) := l_s(l_j); l_s(l_j) := l_t;
  END LOOP;

  -- geracao do fluxo e XOR. O resultado e montado em hexadecimal e convertido
  -- de uma vez: concatenar RAW byte a byte seria quadratico.
  l_i := 0; l_j := 0;
  FOR x IN 1 .. l_dlen LOOP
    l_i := MOD(l_i + 1, 256);
    l_j := MOD(l_j + l_s(l_i), 256);
    l_t := l_s(l_i); l_s(l_i) := l_s(l_j); l_s(l_j) := l_t;
    l_hex := l_hex ||
      LPAD(TO_CHAR(
        TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(p_src, x, 1)), 'XX')
        + l_s(MOD(l_s(l_i) + l_s(l_j), 256))
        - 2 * BITAND(TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(p_src, x, 1)), 'XX'),
                     l_s(MOD(l_s(l_i) + l_s(l_j), 256))),
        'FMXX'), 2, '0');
  END LOOP;
  RETURN HEXTORAW(l_hex);
END crypto_rc4;

--------------------------------------------------------------------------------
-- crypto_rc4_blob: RC4 sobre BLOB, sem limite de tamanho
--
-- O RC4 tem ESTADO: a caixa S e os indices i e j evoluem byte a byte. Chamar
-- crypto_rc4 uma vez por pedaco reiniciaria a cifra em cada um e produziria
-- lixo — foi por isso que a cifragem de um fluxo grande nao podia simplesmente
-- ser fatiada. Aqui a chave e agendada UMA vez e o estado atravessa os pedacos.
--
-- Antes disto, um documento com fluxo de conteudo acima de 16 KB rebentava com
-- ORA-06502 sem explicacao: o acumulador hexadecimal de crypto_rc4 estourava.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- crypto_rc4_blob: RC4 sobre BLOB, sem limite de tamanho
--
-- O RC4 tem ESTADO: a caixa S e os indices i e j evoluem byte a byte. Chamar
-- crypto_rc4 uma vez por pedaco reiniciaria a cifra em cada um e produziria
-- lixo — foi por isso que a cifragem de um fluxo grande nao podia simplesmente
-- ser fatiada. Aqui a chave e agendada UMA vez e o estado atravessa os pedacos.
--
-- Antes disto, um documento com fluxo de conteudo acima de 16 KB rebentava com
-- ORA-06502 sem explicacao: o acumulador hexadecimal de crypto_rc4 estourava.
--------------------------------------------------------------------------------
PROCEDURE crypto_rc4_blob(
  p_src IN            BLOB,
  p_key IN            RAW,
  o_dst IN OUT NOCOPY BLOB
) IS
  co_lote CONSTANT PLS_INTEGER := 8000;   -- 16000 caracteres de hexadecimal
  l_s     tpi;
  l_i     PLS_INTEGER := 0;
  l_j     PLS_INTEGER := 0;
  l_t     PLS_INTEGER;
  l_klen  PLS_INTEGER := NVL(UTL_RAW.LENGTH(p_key), 0);
  l_dlen  PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_pos   PLS_INTEGER := 1;
  l_n     PLS_INTEGER;
  l_buf   RAW(8000);
  l_hex   VARCHAR2(16000);
  l_b     PLS_INTEGER;
  l_k     PLS_INTEGER;
BEGIN
  IF l_dlen = 0 THEN
    RETURN;
  END IF;
  IF l_klen = 0 THEN
    RAISE_APPLICATION_ERROR(-20863, 'RC4: chave vazia');
  END IF;

  -- key-scheduling: UMA vez para o fluxo inteiro
  FOR x IN 0 .. 255 LOOP
    l_s(x) := x;
  END LOOP;
  FOR x IN 0 .. 255 LOOP
    l_j := MOD(l_j + l_s(x)
               + TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(p_key, MOD(x, l_klen) + 1, 1)),
                           'XX'), 256);
    l_t := l_s(x); l_s(x) := l_s(l_j); l_s(l_j) := l_t;
  END LOOP;

  l_i := 0; l_j := 0;
  WHILE l_pos <= l_dlen LOOP
    l_n   := LEAST(co_lote, l_dlen - l_pos + 1);
    l_buf := DBMS_LOB.SUBSTR(p_src, l_n, l_pos);
    l_hex := NULL;
    FOR x IN 1 .. l_n LOOP
      l_i := MOD(l_i + 1, 256);
      l_j := MOD(l_j + l_s(l_i), 256);
      l_t := l_s(l_i); l_s(l_i) := l_s(l_j); l_s(l_j) := l_t;
      l_b := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_buf, x, 1)), 'XX');
      l_k := l_s(MOD(l_s(l_i) + l_s(l_j), 256));
      l_hex := l_hex || LPAD(TO_CHAR(l_b + l_k - 2 * BITAND(l_b, l_k), 'FMXX'),
                             2, '0');
    END LOOP;
    DBMS_LOB.WRITEAPPEND(o_dst, l_n, HEXTORAW(l_hex));
    l_pos := l_pos + l_n;
  END LOOP;
END crypto_rc4_blob;

/*******************************************************************************
* rc4_crypt: RC4 encryption/decryption (symmetric)
*******************************************************************************/

--------------------------------------------------------------------------------
-- AES (FIPS-197), portado de scripts/pdfaes_reference/
--
-- Escrito a mao porque nao ha DBMS_CRYPTO nesta base — foi eliminado de
-- proposito, e o STANDARD_HASH cobre so os hashes. O PDF 2.0 removeu o RC4 da
-- especificacao, entao isto e o que sobra para proteger um documento.
--
-- Desempenho: e trabalho de CPU em PL/SQL. Com as tabelas pre-calculadas um
-- bloco de 16 bytes custa cerca de mil operacoes, o que da alguns segundos para
-- um PDF de algumas centenas de KB. Para relatorios comuns nao incomoda; para
-- documentos grandes, incomoda.
--------------------------------------------------------------------------------
PROCEDURE aes_init IS
  l_b PLS_INTEGER;

  FUNCTION xtime(p IN PLS_INTEGER) RETURN PLS_INTEGER IS
    l PLS_INTEGER := p * 2;
  BEGIN
    -- reducao pelo polinomio 0x11B quando estoura 8 bits; o XOR sai do BITAND
    -- porque o PL/SQL nao tem operador de ou-exclusivo
    RETURN CASE WHEN l > 255
                THEN l - 256 + 27 - 2 * BITAND(l - 256, 27)
                ELSE l END;
  END xtime;

  FUNCTION gmul(p_a IN PLS_INTEGER, p_b IN PLS_INTEGER) RETURN PLS_INTEGER IS
    l_a PLS_INTEGER := p_a;
    l_b PLS_INTEGER := p_b;
    l_r PLS_INTEGER := 0;
  BEGIN
    WHILE l_b > 0 LOOP
      IF MOD(l_b, 2) = 1 THEN
        l_r := l_r + l_a - 2 * BITAND(l_r, l_a);
      END IF;
      l_b := TRUNC(l_b / 2);
      l_a := xtime(l_a);
    END LOOP;
    RETURN l_r;
  END gmul;
BEGIN
  IF g_aes_pronto THEN
    RETURN;
  END IF;
  FOR i IN 0 .. 255 LOOP
    l_b := TO_NUMBER(SUBSTR(co_aes_sbox, i * 2 + 1, 2), 'XX');
    g_aes_sbox(i) := l_b;
    g_aes_inv(l_b) := i;
    g_aes_hex(i)  := SUBSTR(co_aes_sbox, i * 2 + 1, 2);  -- so para reservar
  END LOOP;
  FOR i IN 0 .. 255 LOOP
    g_aes_hex(i) := LPAD(TO_CHAR(i, 'FMXX'), 2, '0');
    g_aes_m2(i)  := gmul(i, 2);
    g_aes_m3(i)  := gmul(i, 3);
    g_aes_m9(i)  := gmul(i, 9);
    g_aes_m11(i) := gmul(i, 11);
    g_aes_m13(i) := gmul(i, 13);
    g_aes_m14(i) := gmul(i, 14);
  END LOOP;
  g_aes_pronto := TRUE;
END aes_init;

--------------------------------------------------------------------------------
-- aes_expandir: sub-chaves de rodada, devolvidas como RAW de 16*(nr+1) bytes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_expandir: sub-chaves de rodada, devolvidas como RAW de 16*(nr+1) bytes
--------------------------------------------------------------------------------
FUNCTION aes_expandir(p_chave IN RAW, o_nr OUT PLS_INTEGER) RETURN RAW IS
  co_rcon CONSTANT VARCHAR2(28) := '01020408102040801B366CD8AB4D';
  l_nk  PLS_INTEGER := UTL_RAW.LENGTH(p_chave) / 4;
  l_w   tpi;                      -- bytes da chave expandida, base 0
  l_t   tpi;
  l_hex VARCHAR2(32767);
BEGIN
  aes_init;
  IF l_nk NOT IN (4, 8) THEN
    -- -20865, e nao -20852: aquele ja significa 'simbologia de codigo de
    -- barras nao suportada'. A colisao de codigos entre dominios esta no
    -- roadmap; nao vale a pena acrescentar mais uma.
    RAISE_APPLICATION_ERROR(-20865,
      'Chave AES deve ter 16 ou 32 bytes; recebeu '
      || UTL_RAW.LENGTH(p_chave));
  END IF;
  o_nr := l_nk + 6;

  l_hex := RAWTOHEX(p_chave);
  FOR i IN 0 .. l_nk * 4 - 1 LOOP
    l_w(i) := TO_NUMBER(SUBSTR(l_hex, i * 2 + 1, 2), 'XX');
  END LOOP;

  FOR i IN l_nk .. 4 * (o_nr + 1) - 1 LOOP
    FOR j IN 0 .. 3 LOOP
      l_t(j) := l_w((i - 1) * 4 + j);
    END LOOP;

    IF MOD(i, l_nk) = 0 THEN
      DECLARE
        l_tmp PLS_INTEGER := l_t(0);
      BEGIN
        l_t(0) := g_aes_sbox(l_t(1));               -- RotWord + SubWord
        l_t(1) := g_aes_sbox(l_t(2));
        l_t(2) := g_aes_sbox(l_t(3));
        l_t(3) := g_aes_sbox(l_tmp);
      END;
      DECLARE
        l_rc PLS_INTEGER := TO_NUMBER(
               SUBSTR(co_rcon, (i / l_nk - 1) * 2 + 1, 2), 'XX');
      BEGIN
        l_t(0) := l_t(0) + l_rc - 2 * BITAND(l_t(0), l_rc);
      END;
    ELSIF l_nk > 6 AND MOD(i, l_nk) = 4 THEN
      -- So existe para AES-256. Sem este ramo a expansao sai errada da setima
      -- palavra em diante — e a cifra continua "funcionando" consigo mesma,
      -- produzindo bytes que nenhum outro programa decifra.
      FOR j IN 0 .. 3 LOOP
        l_t(j) := g_aes_sbox(l_t(j));
      END LOOP;
    END IF;

    FOR j IN 0 .. 3 LOOP
      l_w(i * 4 + j) := l_w((i - l_nk) * 4 + j) + l_t(j)
                      - 2 * BITAND(l_w((i - l_nk) * 4 + j), l_t(j));
    END LOOP;
  END LOOP;

  l_hex := NULL;
  FOR i IN 0 .. 16 * (o_nr + 1) - 1 LOOP
    l_hex := l_hex || g_aes_hex(l_w(i));
  END LOOP;
  RETURN HEXTORAW(l_hex);
END aes_expandir;

--------------------------------------------------------------------------------
-- aes_bloco: cifra um bloco de 16 bytes
--
-- O estado e mantido num array de 16 inteiros (ordem de coluna, como no FIPS),
-- e nao em RAW: cada UTL_RAW.SUBSTR custaria uma chamada de funcao por byte.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_bloco: cifra um bloco de 16 bytes
--
-- O estado e mantido num array de 16 inteiros (ordem de coluna, como no FIPS),
-- e nao em RAW: cada UTL_RAW.SUBSTR custaria uma chamada de funcao por byte.
--------------------------------------------------------------------------------
FUNCTION aes_bloco(p_in IN RAW, p_w IN RAW, p_nr IN PLS_INTEGER) RETURN RAW IS
  l_s   tpi;
  l_t   tpi;
  l_wh  VARCHAR2(32767) := RAWTOHEX(p_w);
  l_hex VARCHAR2(64) := RAWTOHEX(p_in);
  l_out VARCHAR2(64);

  PROCEDURE add_round_key(p_r IN PLS_INTEGER) IS
    l_k PLS_INTEGER;
  BEGIN
    FOR i IN 0 .. 15 LOOP
      l_k := TO_NUMBER(SUBSTR(l_wh, (p_r * 16 + i) * 2 + 1, 2), 'XX');
      l_s(i) := l_s(i) + l_k - 2 * BITAND(l_s(i), l_k);
    END LOOP;
  END add_round_key;
BEGIN
  FOR i IN 0 .. 15 LOOP
    l_s(i) := TO_NUMBER(SUBSTR(l_hex, i * 2 + 1, 2), 'XX');
  END LOOP;

  add_round_key(0);
  FOR r IN 1 .. p_nr LOOP
    -- SubBytes e ShiftRows num passo so: o byte da linha i, coluna c, vem da
    -- coluna (c + i) mod 4
    FOR c IN 0 .. 3 LOOP
      FOR i IN 0 .. 3 LOOP
        l_t(c * 4 + i) := g_aes_sbox(l_s(MOD(c + i, 4) * 4 + i));
      END LOOP;
    END LOOP;

    IF r != p_nr THEN                              -- MixColumns
      FOR c IN 0 .. 3 LOOP
        DECLARE
          a0 PLS_INTEGER := l_t(c * 4);
          a1 PLS_INTEGER := l_t(c * 4 + 1);
          a2 PLS_INTEGER := l_t(c * 4 + 2);
          a3 PLS_INTEGER := l_t(c * 4 + 3);
          FUNCTION x4(p1 PLS_INTEGER, p2 PLS_INTEGER,
                      p3 PLS_INTEGER, p4 PLS_INTEGER) RETURN PLS_INTEGER IS
            l PLS_INTEGER;
          BEGIN
            l := p1 + p2 - 2 * BITAND(p1, p2);
            l := l + p3 - 2 * BITAND(l, p3);
            RETURN l + p4 - 2 * BITAND(l, p4);
          END x4;
        BEGIN
          l_s(c * 4)     := x4(g_aes_m2(a0), g_aes_m3(a1), a2, a3);
          l_s(c * 4 + 1) := x4(a0, g_aes_m2(a1), g_aes_m3(a2), a3);
          l_s(c * 4 + 2) := x4(a0, a1, g_aes_m2(a2), g_aes_m3(a3));
          l_s(c * 4 + 3) := x4(g_aes_m3(a0), a1, a2, g_aes_m2(a3));
        END;
      END LOOP;
    ELSE
      FOR i IN 0 .. 15 LOOP
        l_s(i) := l_t(i);
      END LOOP;
    END IF;
    add_round_key(r);
  END LOOP;

  FOR i IN 0 .. 15 LOOP
    l_out := l_out || g_aes_hex(l_s(i));
  END LOOP;
  RETURN HEXTORAW(l_out);
END aes_bloco;

--------------------------------------------------------------------------------
-- aes_bloco_inv: decifra um bloco de 16 bytes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_bloco_inv: decifra um bloco de 16 bytes
--------------------------------------------------------------------------------
FUNCTION aes_bloco_inv(p_in IN RAW, p_w IN RAW, p_nr IN PLS_INTEGER)
  RETURN RAW IS
  l_s   tpi;
  l_t   tpi;
  l_wh  VARCHAR2(32767) := RAWTOHEX(p_w);
  l_hex VARCHAR2(64) := RAWTOHEX(p_in);
  l_out VARCHAR2(64);

  PROCEDURE add_round_key(p_r IN PLS_INTEGER) IS
    l_k PLS_INTEGER;
  BEGIN
    FOR i IN 0 .. 15 LOOP
      l_k := TO_NUMBER(SUBSTR(l_wh, (p_r * 16 + i) * 2 + 1, 2), 'XX');
      l_s(i) := l_s(i) + l_k - 2 * BITAND(l_s(i), l_k);
    END LOOP;
  END add_round_key;
BEGIN
  FOR i IN 0 .. 15 LOOP
    l_s(i) := TO_NUMBER(SUBSTR(l_hex, i * 2 + 1, 2), 'XX');
  END LOOP;

  add_round_key(p_nr);
  FOR r IN REVERSE 0 .. p_nr - 1 LOOP
    -- InvShiftRows + InvSubBytes: a linha i desloca para a direita
    FOR c IN 0 .. 3 LOOP
      FOR i IN 0 .. 3 LOOP
        l_t(c * 4 + i) := g_aes_inv(l_s(MOD(c - i + 4, 4) * 4 + i));
      END LOOP;
    END LOOP;
    FOR i IN 0 .. 15 LOOP
      l_s(i) := l_t(i);
    END LOOP;
    add_round_key(r);

    IF r != 0 THEN                                 -- InvMixColumns
      FOR c IN 0 .. 3 LOOP
        DECLARE
          a0 PLS_INTEGER := l_s(c * 4);
          a1 PLS_INTEGER := l_s(c * 4 + 1);
          a2 PLS_INTEGER := l_s(c * 4 + 2);
          a3 PLS_INTEGER := l_s(c * 4 + 3);
          FUNCTION x4(p1 PLS_INTEGER, p2 PLS_INTEGER,
                      p3 PLS_INTEGER, p4 PLS_INTEGER) RETURN PLS_INTEGER IS
            l PLS_INTEGER;
          BEGIN
            l := p1 + p2 - 2 * BITAND(p1, p2);
            l := l + p3 - 2 * BITAND(l, p3);
            RETURN l + p4 - 2 * BITAND(l, p4);
          END x4;
        BEGIN
          l_s(c * 4)     := x4(g_aes_m14(a0), g_aes_m11(a1),
                               g_aes_m13(a2), g_aes_m9(a3));
          l_s(c * 4 + 1) := x4(g_aes_m9(a0), g_aes_m14(a1),
                               g_aes_m11(a2), g_aes_m13(a3));
          l_s(c * 4 + 2) := x4(g_aes_m13(a0), g_aes_m9(a1),
                               g_aes_m14(a2), g_aes_m11(a3));
          l_s(c * 4 + 3) := x4(g_aes_m11(a0), g_aes_m13(a1),
                               g_aes_m9(a2), g_aes_m14(a3));
        END;
      END LOOP;
    END IF;
  END LOOP;

  FOR i IN 0 .. 15 LOOP
    l_out := l_out || g_aes_hex(l_s(i));
  END LOOP;
  RETURN HEXTORAW(l_out);
END aes_bloco_inv;

--------------------------------------------------------------------------------
-- aes_iv: vetor de inicializacao aleatorio de 16 bytes
--
-- Nao precisa ser imprevisivel a nivel criptografico aqui — o CBC exige apenas
-- que nao se repita com a mesma chave — mas usar SYS_GUID em vez de um
-- contador evita o pior caso de dois documentos cifrados no mesmo instante.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_iv: vetor de inicializacao aleatorio de 16 bytes
--
-- Nao precisa ser imprevisivel a nivel criptografico aqui — o CBC exige apenas
-- que nao se repita com a mesma chave — mas usar SYS_GUID em vez de um
-- contador evita o pior caso de dois documentos cifrados no mesmo instante.
--------------------------------------------------------------------------------
FUNCTION aes_iv RETURN RAW IS
BEGIN
  RETURN UTL_RAW.SUBSTR(crypto_md5(UTL_RAW.CONCAT(SYS_GUID(),
           UTL_RAW.CAST_TO_RAW(TO_CHAR(SYSTIMESTAMP,
                               'YYYYMMDDHH24MISSFF9')))), 1, 16);
END aes_iv;

--------------------------------------------------------------------------------
-- aes_cbc_cifrar: AES-CBC com o IV no INICIO do resultado, como manda o PDF
--
-- Trabalha em BLOB porque um fluxo de conteudo passa facil dos 32 KB de um
-- RAW. O preenchimento e o PKCS#5: quando o dado ja e multiplo de 16 entra um
-- bloco INTEIRO de preenchimento — omiti-lo faria o decifrador comer 16 bytes
-- de dado real.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_cbc_cifrar: AES-CBC com o IV no INICIO do resultado, como manda o PDF
--
-- Trabalha em BLOB porque um fluxo de conteudo passa facil dos 32 KB de um
-- RAW. O preenchimento e o PKCS#5: quando o dado ja e multiplo de 16 entra um
-- bloco INTEIRO de preenchimento — omiti-lo faria o decifrador comer 16 bytes
-- de dado real.
--------------------------------------------------------------------------------
PROCEDURE aes_cbc_cifrar(
  p_chave IN            RAW,
  p_dados IN            BLOB,
  o_saida IN OUT NOCOPY BLOB,
  p_iv    IN            RAW DEFAULT NULL
) IS
  l_nr    PLS_INTEGER;
  l_w     RAW(240);
  l_n     PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_dados), 0);
  l_iv    RAW(16) := NVL(p_iv, aes_iv);
  l_ant   RAW(16);
  l_bloco RAW(16);
  l_pad   PLS_INTEGER;
  l_pos   PLS_INTEGER := 1;
BEGIN
  l_w := aes_expandir(p_chave, l_nr);
  DBMS_LOB.WRITEAPPEND(o_saida, 16, l_iv);
  l_ant := l_iv;

  l_pad := 16 - MOD(l_n, 16);
  WHILE l_pos <= l_n + l_pad LOOP
    IF l_pos + 15 <= l_n THEN
      l_bloco := DBMS_LOB.SUBSTR(p_dados, 16, l_pos);
    ELSIF l_pos <= l_n THEN
      -- ultimo bloco com dado: o que sobrou mais o preenchimento
      l_bloco := UTL_RAW.CONCAT(
        DBMS_LOB.SUBSTR(p_dados, l_n - l_pos + 1, l_pos),
        UTL_RAW.COPIES(HEXTORAW(g_aes_hex(l_pad)), l_pad));
    ELSE
      -- o dado acabou num multiplo de 16: entra um bloco INTEIRO de
      -- preenchimento. Omiti-lo faria o decifrador comer 16 bytes reais.
      l_bloco := UTL_RAW.COPIES(HEXTORAW(g_aes_hex(16)), 16);
    END IF;
    l_ant := aes_bloco(UTL_RAW.BIT_XOR(l_bloco, l_ant), l_w, l_nr);
    DBMS_LOB.WRITEAPPEND(o_saida, 16, l_ant);
    l_pos := l_pos + 16;
  END LOOP;
END aes_cbc_cifrar;

--------------------------------------------------------------------------------
-- aes_cbc_cifrar_raw: o mesmo para dados curtos, sem passar por BLOB
--
-- Serve para as strings do dicionario, que sao pequenas. Streams usam a versao
-- em BLOB: um fluxo de conteudo passa dos 32767 bytes que cabem num RAW.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_cbc_cifrar_raw: o mesmo para dados curtos, sem passar por BLOB
--
-- Serve para as strings do dicionario, que sao pequenas. Streams usam a versao
-- em BLOB: um fluxo de conteudo passa dos 32767 bytes que cabem num RAW.
--------------------------------------------------------------------------------
FUNCTION aes_cbc_cifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW IS
  l_ent BLOB;
  l_sai BLOB;
  l_out RAW(32767);
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_ent, TRUE);
  DBMS_LOB.CREATETEMPORARY(l_sai, TRUE);
  IF NVL(UTL_RAW.LENGTH(p_dados), 0) > 0 THEN
    DBMS_LOB.WRITEAPPEND(l_ent, UTL_RAW.LENGTH(p_dados), p_dados);
  END IF;
  aes_cbc_cifrar(p_chave, l_ent, l_sai);
  l_out := DBMS_LOB.SUBSTR(l_sai, DBMS_LOB.GETLENGTH(l_sai), 1);
  DBMS_LOB.FREETEMPORARY(l_ent);
  DBMS_LOB.FREETEMPORARY(l_sai);
  RETURN l_out;
END aes_cbc_cifrar_raw;

--------------------------------------------------------------------------------
-- aes_cbc_decifrar: inverso, tirando o IV e o preenchimento
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_cbc_decifrar: inverso, tirando o IV e o preenchimento
--------------------------------------------------------------------------------
PROCEDURE aes_cbc_decifrar(
  p_chave IN            RAW,
  p_dados IN            BLOB,
  o_saida IN OUT NOCOPY BLOB
) IS
  l_nr    PLS_INTEGER;
  l_w     RAW(240);
  l_n     PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_dados), 0);
  l_ant   RAW(16);
  l_c     RAW(16);
  l_claro RAW(16);
  l_pos   PLS_INTEGER := 17;         -- depois do IV
  l_pad   PLS_INTEGER;
BEGIN
  IF l_n < 32 OR MOD(l_n, 16) != 0 THEN
    RAISE_APPLICATION_ERROR(-20857,
      'Fluxo AES invalido: ' || l_n || ' bytes (esperado multiplo de 16, '
      || 'com IV e ao menos um bloco).');
  END IF;
  l_w := aes_expandir(p_chave, l_nr);
  l_ant := DBMS_LOB.SUBSTR(p_dados, 16, 1);

  WHILE l_pos <= l_n LOOP
    l_c     := DBMS_LOB.SUBSTR(p_dados, 16, l_pos);
    l_claro := UTL_RAW.BIT_XOR(aes_bloco_inv(l_c, l_w, l_nr), l_ant);
    IF l_pos + 16 > l_n THEN
      -- ultimo bloco: tira o preenchimento indicado pelo proprio ultimo byte
      l_pad := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_claro, 16, 1)), 'XX');
      IF l_pad BETWEEN 1 AND 15 THEN
        DBMS_LOB.WRITEAPPEND(o_saida, 16 - l_pad,
                             UTL_RAW.SUBSTR(l_claro, 1, 16 - l_pad));
      ELSIF l_pad != 16 THEN
        RAISE_APPLICATION_ERROR(-20857,
          'Preenchimento AES invalido (' || l_pad || '): senha errada ou '
          || 'fluxo corrompido.');
      END IF;
      -- l_pad = 16 significa bloco inteiro de preenchimento: nada a escrever
    ELSE
      DBMS_LOB.WRITEAPPEND(o_saida, 16, l_claro);
    END IF;
    l_ant := l_c;
    l_pos := l_pos + 16;
  END LOOP;
END aes_cbc_decifrar;

--------------------------------------------------------------------------------
-- aes_cbc_decifrar_raw: a volta para dados curtos (strings do dicionario)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_cbc_decifrar_raw: a volta para dados curtos (strings do dicionario)
--------------------------------------------------------------------------------
FUNCTION aes_cbc_decifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW IS
  l_ent BLOB;
  l_sai BLOB;
  l_out RAW(32767);
  l_n   PLS_INTEGER;
BEGIN
  IF NVL(UTL_RAW.LENGTH(p_dados), 0) < 32 THEN
    RETURN p_dados;                  -- curto demais para ser AES; devolve como esta
  END IF;
  DBMS_LOB.CREATETEMPORARY(l_ent, TRUE);
  DBMS_LOB.CREATETEMPORARY(l_sai, TRUE);
  DBMS_LOB.WRITEAPPEND(l_ent, UTL_RAW.LENGTH(p_dados), p_dados);
  aes_cbc_decifrar(p_chave, l_ent, l_sai);
  l_n := DBMS_LOB.GETLENGTH(l_sai);
  IF l_n > 0 THEN
    l_out := DBMS_LOB.SUBSTR(l_sai, l_n, 1);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_ent);
  DBMS_LOB.FREETEMPORARY(l_sai);
  RETURN l_out;
END aes_cbc_decifrar_raw;

--------------------------------------------------------------------------------
-- aes_ecb_cifrar: ECB sem preenchimento, so para o /Perms do R6
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_ecb_cifrar: ECB sem preenchimento, so para o /Perms do R6
--------------------------------------------------------------------------------
FUNCTION aes_ecb_cifrar(p_chave IN RAW, p_dados IN RAW) RETURN RAW IS
  l_nr  PLS_INTEGER;
  l_w   RAW(240);
  l_out RAW(32767);
BEGIN
  l_w := aes_expandir(p_chave, l_nr);
  FOR i IN 0 .. UTL_RAW.LENGTH(p_dados) / 16 - 1 LOOP
    l_out := UTL_RAW.CONCAT(l_out,
               aes_bloco(UTL_RAW.SUBSTR(p_dados, i * 16 + 1, 16), l_w, l_nr));
  END LOOP;
  RETURN l_out;
END aes_ecb_cifrar;

--------------------------------------------------------------------------------
-- aes_autoteste: confere o AES contra os vetores oficiais do FIPS-197
--
-- Vale o mesmo raciocinio do crypto_autoteste, e aqui e ainda mais necessario:
-- uma expansao de chave errada produz uma cifra que decifra CONSIGO MESMA e que
-- nenhum outro programa entende. Sem vetor conhecido, o PDF sairia "cifrado" e
-- so o leitor do usuario descobriria.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_autoteste: confere o AES contra os vetores oficiais do FIPS-197
--
-- Vale o mesmo raciocinio do crypto_autoteste, e aqui e ainda mais necessario:
-- uma expansao de chave errada produz uma cifra que decifra CONSIGO MESMA e que
-- nenhum outro programa entende. Sem vetor conhecido, o PDF sairia "cifrado" e
-- so o leitor do usuario descobriria.
--------------------------------------------------------------------------------
PROCEDURE aes_autoteste IS
  co_claro CONSTANT RAW(16) := HEXTORAW('00112233445566778899AABBCCDDEEFF');
  co_k128  CONSTANT RAW(16) := HEXTORAW('000102030405060708090A0B0C0D0E0F');
  co_c128  CONSTANT RAW(16) := HEXTORAW('69C4E0D86A7B0430D8CDB78070B4C55A');
  co_k256  CONSTANT RAW(32) := HEXTORAW(
    '000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F');
  co_c256  CONSTANT RAW(16) := HEXTORAW('8EA2B7CA516745BFEAFC49904B496089');
  l_nr PLS_INTEGER;
  l_w  RAW(240);
BEGIN
  IF g_aes_ok THEN
    RETURN;
  END IF;

  l_w := aes_expandir(co_k128, l_nr);
  IF aes_bloco(co_claro, l_w, l_nr) != co_c128
     OR aes_bloco_inv(co_c128, l_w, l_nr) != co_claro THEN
    RAISE_APPLICATION_ERROR(-20863,
      'AES-128 nao reproduz o vetor do FIPS-197. / AES-128 fails the '
      || 'FIPS-197 known-answer test.');
  END IF;

  l_w := aes_expandir(co_k256, l_nr);
  IF aes_bloco(co_claro, l_w, l_nr) != co_c256
     OR aes_bloco_inv(co_c256, l_w, l_nr) != co_claro THEN
    RAISE_APPLICATION_ERROR(-20863,
      'AES-256 nao reproduz o vetor do FIPS-197. / AES-256 fails the '
      || 'FIPS-197 known-answer test.');
  END IF;

  g_aes_ok := TRUE;
END aes_autoteste;

--------------------------------------------------------------------------------
-- aes_chave_objeto: algoritmo 1 com AES (revisao 4, /CF com AESV2)
--
-- Igual ao do RC4, mais os quatro bytes 'sAlT' no fim da entrada do MD5. Sem
-- eles a chave sai diferente da que qualquer leitor calcula, e o documento
-- abre com a senha certa e mostra lixo.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_chave_objeto: algoritmo 1 com AES (revisao 4, /CF com AESV2)
--
-- Igual ao do RC4, mais os quatro bytes 'sAlT' no fim da entrada do MD5. Sem
-- eles a chave sai diferente da que qualquer leitor calcula, e o documento
-- abre com a senha certa e mostra lixo.
--------------------------------------------------------------------------------
FUNCTION aes_chave_objeto(
  p_chave   IN RAW,
  p_obj_num IN PLS_INTEGER,
  p_gen_num IN PLS_INTEGER DEFAULT 0
) RETURN RAW IS
  co_salt CONSTANT RAW(4) := HEXTORAW('73416C54');   -- 's' 'A' 'l' 'T'
BEGIN
  RETURN UTL_RAW.SUBSTR(
    crypto_md5(UTL_RAW.CONCAT(
      p_chave,
      UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(
        p_obj_num, UTL_RAW.LITTLE_ENDIAN), 1, 3),
      UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(
        p_gen_num, UTL_RAW.LITTLE_ENDIAN), 1, 2),
      co_salt)),
    1, LEAST(UTL_RAW.LENGTH(p_chave) + 5, 16));
END aes_chave_objeto;

--------------------------------------------------------------------------------
-- aes_sha: SHA-256, 384 ou 512 pelo STANDARD_HASH
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_sha: SHA-256, 384 ou 512 pelo STANDARD_HASH
--------------------------------------------------------------------------------
FUNCTION aes_sha(p_src IN RAW, p_bits IN PLS_INTEGER) RETURN RAW IS
  l_out RAW(64);
BEGIN
  CASE p_bits
    WHEN 256 THEN SELECT STANDARD_HASH(p_src, 'SHA256') INTO l_out FROM dual;
    WHEN 384 THEN SELECT STANDARD_HASH(p_src, 'SHA384') INTO l_out FROM dual;
    ELSE          SELECT STANDARD_HASH(p_src, 'SHA512') INTO l_out FROM dual;
  END CASE;
  RETURN l_out;
END aes_sha;

--------------------------------------------------------------------------------
-- aes_hash_r6: algoritmo 2.B da especificacao (PDF 2.0, 7.6.4.3.4)
--
-- Laco que alterna SHA-256/384/512 com AES-CBC. O criterio de parada olha o
-- ULTIMO byte do resultado da rodada e o compara com o numero da rodada, depois
-- de no minimo 64 voltas — e o ponto que quase todo mundo erra na primeira
-- tentativa, porque a leitura apressada da especificacao sugere parar em 64.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_hash_r6: algoritmo 2.B da especificacao (PDF 2.0, 7.6.4.3.4)
--
-- Laco que alterna SHA-256/384/512 com AES-CBC. O criterio de parada olha o
-- ULTIMO byte do resultado da rodada e o compara com o numero da rodada, depois
-- de no minimo 64 voltas — e o ponto que quase todo mundo erra na primeira
-- tentativa, porque a leitura apressada da especificacao sugere parar em 64.
--------------------------------------------------------------------------------
FUNCTION aes_hash_r6(
  p_senha IN RAW,
  p_sal   IN RAW,
  p_extra IN RAW DEFAULT NULL
) RETURN RAW IS
  l_k    RAW(64);
  l_k1   RAW(32767);
  l_e    RAW(32767);
  l_um   RAW(255);
  l_i    PLS_INTEGER := 0;
  l_soma PLS_INTEGER;
  l_ult  PLS_INTEGER;
  l_len  PLS_INTEGER;
  l_nr   PLS_INTEGER;
  l_w    RAW(240);
  l_ant  RAW(16);
BEGIN
  -- Tudo em RAW, e nao em BLOB: o STANDARD_HASH nao aceita LOB (ORA-00902), e
  -- nao precisa — a senha do R6 vai a 127 bytes, K a 64 e o extra a 48, entao
  -- K1 = 64 * (127 + 64 + 48) = 15296 bytes no pior caso, dentro do RAW.
  l_k := aes_sha(UTL_RAW.CONCAT(p_senha, p_sal, NVL(p_extra, HEXTORAW(''))),
                 256);

  LOOP
    l_um  := UTL_RAW.CONCAT(p_senha, l_k, NVL(p_extra, HEXTORAW('')));
    l_k1  := UTL_RAW.COPIES(l_um, 64);
    l_len := UTL_RAW.LENGTH(l_k1);

    -- E = AES-CBC(chave = K[1..16], IV = K[17..32], K1), SEM preenchimento
    l_w   := aes_expandir(UTL_RAW.SUBSTR(l_k, 1, 16), l_nr);
    l_ant := UTL_RAW.SUBSTR(l_k, 17, 16);
    l_e   := NULL;
    FOR b IN 0 .. l_len / 16 - 1 LOOP
      l_ant := aes_bloco(
                 UTL_RAW.BIT_XOR(UTL_RAW.SUBSTR(l_k1, b * 16 + 1, 16), l_ant),
                 l_w, l_nr);
      l_e := UTL_RAW.CONCAT(l_e, l_ant);
    END LOOP;

    -- a escolha do SHA vem da soma dos 16 primeiros bytes de E, modulo 3
    l_soma := 0;
    FOR b IN 1 .. 16 LOOP
      l_soma := l_soma + TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_e, b, 1)), 'XX');
    END LOOP;
    l_ult := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_e, l_len, 1)), 'XX');

    l_k := aes_sha(l_e, CASE MOD(l_soma, 3) WHEN 0 THEN 256
                                            WHEN 1 THEN 384
                                            ELSE 512 END);

    l_i := l_i + 1;
    -- O criterio de parada olha o ULTIMO byte de E e o compara com o numero da
    -- rodada, depois de no minimo 64 voltas. Parar em 64, como a leitura
    -- apressada da especificacao sugere, da uma chave errada.
    EXIT WHEN l_i >= 64 AND l_ult <= l_i - 32;
  END LOOP;

  RETURN UTL_RAW.SUBSTR(l_k, 1, 32);
END aes_hash_r6;

--------------------------------------------------------------------------------
-- aes_valores_r6: /U, /UE, /O, /OE e /Perms do AES-256
--
-- No R6 a chave do arquivo e aleatoria e fica EMBRULHADA em /UE e /OE, cada uma
-- com uma chave derivada da senha correspondente. /U e /O tem 48 bytes: hash de
-- 32, validation salt de 8 e key salt de 8.
--
-- O /O leva os 48 bytes do /U no hash — e o que amarra as duas senhas ao mesmo
-- documento. E o /Perms carrega as permissoes cifradas em ECB, para que
-- adulterar o /P do dicionario, que vai em claro, seja detectavel.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_valores_r6: /U, /UE, /O, /OE e /Perms do AES-256
--
-- No R6 a chave do arquivo e aleatoria e fica EMBRULHADA em /UE e /OE, cada uma
-- com uma chave derivada da senha correspondente. /U e /O tem 48 bytes: hash de
-- 32, validation salt de 8 e key salt de 8.
--
-- O /O leva os 48 bytes do /U no hash — e o que amarra as duas senhas ao mesmo
-- documento. E o /Perms carrega as permissoes cifradas em ECB, para que
-- adulterar o /P do dicionario, que vai em claro, seja detectavel.
--------------------------------------------------------------------------------
PROCEDURE aes_valores_r6(
  p_senha_usr  IN  VARCHAR2,
  p_senha_dono IN  VARCHAR2,
  p_chave      IN  RAW,
  p_perms      IN  NUMBER,
  o_u          OUT RAW,
  o_ue         OUT RAW,
  o_o          OUT RAW,
  o_oe         OUT RAW,
  o_perms      OUT RAW
) IS
  l_su    RAW(127) := UTL_RAW.CAST_TO_RAW(SUBSTR(NVL(p_senha_usr, ''), 1, 127));
  l_sd    RAW(127) := UTL_RAW.CAST_TO_RAW(SUBSTR(NVL(p_senha_dono, ''), 1, 127));
  l_uvs   RAW(8);
  l_uks   RAW(8);
  l_ovs   RAW(8);
  l_oks   RAW(8);
  l_p32   RAW(16);

  -- AES-CBC com IV de zeros e SEM preenchimento, que e o que /UE e /OE pedem
  FUNCTION embrulhar(p_k IN RAW) RETURN RAW IS
    l_nr  PLS_INTEGER;
    l_w   RAW(240);
    l_ant RAW(16) := HEXTORAW('00000000000000000000000000000000');
    l_out RAW(32);
  BEGIN
    l_w := aes_expandir(p_k, l_nr);
    FOR b IN 0 .. 1 LOOP
      l_ant := aes_bloco(
                 UTL_RAW.BIT_XOR(UTL_RAW.SUBSTR(p_chave, b * 16 + 1, 16),
                                 l_ant), l_w, l_nr);
      l_out := UTL_RAW.CONCAT(l_out, l_ant);
    END LOOP;
    RETURN l_out;
  END embrulhar;
BEGIN
  aes_autoteste;

  l_uvs := UTL_RAW.SUBSTR(aes_iv, 1, 8);
  l_uks := UTL_RAW.SUBSTR(aes_iv, 1, 8);
  o_u   := UTL_RAW.CONCAT(aes_hash_r6(l_su, l_uvs), l_uvs, l_uks);
  o_ue  := embrulhar(aes_hash_r6(l_su, l_uks));

  l_ovs := UTL_RAW.SUBSTR(aes_iv, 1, 8);
  l_oks := UTL_RAW.SUBSTR(aes_iv, 1, 8);
  o_o   := UTL_RAW.CONCAT(aes_hash_r6(l_sd, l_ovs, o_u), l_ovs, l_oks);
  o_oe  := embrulhar(aes_hash_r6(l_sd, l_oks, o_u));

  -- /P em 4 bytes little-endian com sinal, FF FF FF FF, 'T', 'adb' e enchimento
  l_p32 := UTL_RAW.CONCAT(
    UTL_RAW.CAST_FROM_BINARY_INTEGER(p_perms, UTL_RAW.LITTLE_ENDIAN),
    HEXTORAW('FFFFFFFF'),
    UTL_RAW.CAST_TO_RAW('Tadb'),
    HEXTORAW('00000000'));
  o_perms := aes_ecb_cifrar(p_chave, l_p32);
END aes_valores_r6;

--------------------------------------------------------------------------------
-- aes_desembrulhar: recupera a chave do arquivo de /UE ou /OE
--
-- AES-CBC com IV de ZEROS e SEM preenchimento — diferente dos streams do
-- documento, que levam o IV no inicio e sao preenchidos. Tratar os dois do
-- mesmo jeito devolve uma chave errada por 16 bytes.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_desembrulhar: recupera a chave do arquivo de /UE ou /OE
--
-- AES-CBC com IV de ZEROS e SEM preenchimento — diferente dos streams do
-- documento, que levam o IV no inicio e sao preenchidos. Tratar os dois do
-- mesmo jeito devolve uma chave errada por 16 bytes.
--------------------------------------------------------------------------------
FUNCTION aes_desembrulhar(p_chave IN RAW, p_e IN RAW) RETURN RAW IS
  l_nr  PLS_INTEGER;
  l_w   RAW(240);
  l_ant RAW(16) := HEXTORAW('00000000000000000000000000000000');
  l_c   RAW(16);
  l_out RAW(32);
BEGIN
  l_w := aes_expandir(p_chave, l_nr);
  FOR b IN 0 .. 1 LOOP
    l_c   := UTL_RAW.SUBSTR(p_e, b * 16 + 1, 16);
    l_out := UTL_RAW.CONCAT(l_out,
               UTL_RAW.BIT_XOR(aes_bloco_inv(l_c, l_w, l_nr), l_ant));
    l_ant := l_c;
  END LOOP;
  RETURN l_out;
END aes_desembrulhar;

--------------------------------------------------------------------------------
-- aes_verificar_r6: confere a senha do AES-256 e devolve a chave do arquivo
--
-- Os 48 bytes de /U e /O sao: hash de 32, validation salt de 8, key salt de 8.
--
-- A ordem importa: testa-se o USUARIO primeiro. Uma senha que sirva as duas
-- coisas tem de abrir como usuario — o caminho do proprietario existe para
-- quem vai alterar permissoes, e assumi-lo por engano daria ao leitor poderes
-- que o documento nao concedeu.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- aes_verificar_r6: confere a senha do AES-256 e devolve a chave do arquivo
--
-- Os 48 bytes de /U e /O sao: hash de 32, validation salt de 8, key salt de 8.
--
-- A ordem importa: testa-se o USUARIO primeiro. Uma senha que sirva as duas
-- coisas tem de abrir como usuario — o caminho do proprietario existe para
-- quem vai alterar permissoes, e assumi-lo por engano daria ao leitor poderes
-- que o documento nao concedeu.
--------------------------------------------------------------------------------
FUNCTION aes_verificar_r6(
  p_senha  IN  VARCHAR2,
  p_u      IN  RAW,
  p_ue     IN  RAW,
  p_o      IN  RAW,
  p_oe     IN  RAW,
  o_chave  OUT RAW,
  o_dono   OUT BOOLEAN
) RETURN BOOLEAN IS
  l_s RAW(127) := UTL_RAW.CAST_TO_RAW(SUBSTR(NVL(p_senha, ''), 1, 127));
BEGIN
  o_dono  := FALSE;
  o_chave := NULL;

  IF p_u IS NULL OR UTL_RAW.LENGTH(p_u) < 48 THEN
    RETURN FALSE;
  END IF;

  IF aes_hash_r6(l_s, UTL_RAW.SUBSTR(p_u, 33, 8)) = UTL_RAW.SUBSTR(p_u, 1, 32)
  THEN
    o_chave := aes_desembrulhar(
                 aes_hash_r6(l_s, UTL_RAW.SUBSTR(p_u, 41, 8)), p_ue);
    RETURN TRUE;
  END IF;

  IF p_o IS NOT NULL AND UTL_RAW.LENGTH(p_o) >= 48
     -- no caminho do proprietario os 48 bytes do /U entram no hash: e o que
     -- amarra as duas senhas ao mesmo documento
     AND aes_hash_r6(l_s, UTL_RAW.SUBSTR(p_o, 33, 8), UTL_RAW.SUBSTR(p_u, 1, 48))
         = UTL_RAW.SUBSTR(p_o, 1, 32)
  THEN
    o_dono  := TRUE;
    o_chave := aes_desembrulhar(
                 aes_hash_r6(l_s, UTL_RAW.SUBSTR(p_o, 41, 8),
                             UTL_RAW.SUBSTR(p_u, 1, 48)), p_oe);
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END aes_verificar_r6;

/*******************************************************************************
* pdf_pad_password: senha preenchida ate 32 bytes conforme a especificacao
*
* A regra do PDF (algoritmos 2 e 3) e: os bytes da senha, ate 32, seguidos do
* INICIO da string de preenchimento padrao. O codigo anterior usava
* RPAD(senha, 32, CHR(0)) e so depois concatenava o preenchimento, cortando em
* 32 — ou seja, completava com ZEROS e nunca chegava a usar a string do padrao.
* O /O gerado assim nao e aceito por leitores conformes.
*******************************************************************************/
PROCEDURE crypto_autoteste IS
  co_md5_abc CONSTANT RAW(16) := HEXTORAW('900150983CD24FB0D6963F7D28E17F72');
  co_rc4_txt CONSTANT RAW(9)  := UTL_RAW.CAST_TO_RAW('Plaintext');
  co_rc4_key CONSTANT RAW(3)  := UTL_RAW.CAST_TO_RAW('Key');
  co_rc4_esp CONSTANT RAW(9)  := HEXTORAW('BBF316E8D940AF0AD3');
BEGIN
  IF g_crypto_ok THEN
    RETURN;
  END IF;

  IF crypto_md5(UTL_RAW.CAST_TO_RAW('abc')) != co_md5_abc THEN
    RAISE_APPLICATION_ERROR(-20862,
      'STANDARD_HASH(.., ''MD5'') nao produz o MD5 esperado neste banco '
      || '(vetor de teste falhou). / STANDARD_HASH does not produce a correct MD5.');
  END IF;

  IF crypto_rc4(co_rc4_txt, co_rc4_key) != co_rc4_esp THEN
    RAISE_APPLICATION_ERROR(-20862,
      'crypto_rc4 nao reproduz o vetor de teste do RC4. / crypto_rc4 does not '
      || 'match the RC4 test vector.');
  END IF;

  g_crypto_ok := TRUE;
END crypto_autoteste;

/*******************************************************************************
* rc4_key_xor: chave RC4 com XOR byte a byte pelo numero da rodada
*
* Usado pelas 19 rodadas extras dos algoritmos 3 (cifrar /O) e 7 (decifrar /O)
* quando a revisao e 3 ou maior. Cuidados que ja custaram dois bugs:
*   - CAST_FROM_BINARY_INTEGER devolve 4 bytes, e BIT_XOR de 1 com 4 devolve 4:
*     e preciso pegar so o byte menos significativo;
*   - UTL_RAW.SUBSTR(x, 1, 0) e invalido, entao a chave e montada acumulando.
*******************************************************************************/

--------------------------------------------------------------------------------
-- qr_matriz: a matriz do QR pronta, com a mascara ja escolhida
--
-- Estava dentro do AddQRCode, misturada com o desenho. Aqui dentro nao ha
-- desenho nenhum: entra texto, sai uma matriz de 0 e 1.
--------------------------------------------------------------------------------
PROCEDURE qr_matriz(p_dados IN VARCHAR2, p_ec IN VARCHAR2 DEFAULT 'M',
                    o_mat OUT NOCOPY tqr, o_lado OUT PLS_INTEGER,
                    o_versao OUT PLS_INTEGER, o_mascara OUT PLS_INTEGER) IS
  l_ecl        VARCHAR2(1);
  l_cw         tqr;
  l_ncw        PLS_INTEGER;
  l_m          tqr;
  l_res        tqr;
  l_cand       tqr;
  l_score      PLS_INTEGER;
  l_best_score PLS_INTEGER;
BEGIN
  IF p_dados IS NULL THEN
    raise_application_error(-20870, 'AddQRCode: conteudo vazio.');
  END IF;
  l_ecl := UPPER(NVL(SUBSTR(p_ec, 1, 1), 'M'));
  IF l_ecl NOT IN ('L','M','Q','H') THEN
    raise_application_error(-20872,
      'Nivel de correcao invalido: ' || p_ec || '. Use L, M, Q ou H.');
  END IF;

  qr_encode(p_dados, l_ecl, l_cw, o_versao, l_ncw);
  qr_build(o_versao, l_cw, l_ncw, l_m, l_res, o_lado);

  -- escolhe a mascara de menor penalidade
  FOR k IN 0 .. 7 LOOP
    FOR i IN 0 .. o_lado * o_lado - 1 LOOP
      l_cand(i) := CASE
                     WHEN l_res(i) = 0
                          AND qr_mask_bit(k, TRUNC(i / o_lado), MOD(i, o_lado))
                     THEN 1 - l_m(i)
                     ELSE l_m(i)
                   END;
    END LOOP;
    qr_place_format(l_cand, o_lado, l_ecl, k);
    qr_place_version(l_cand, o_lado, o_versao);
    l_score := qr_penalty(l_cand, o_lado);
    IF l_best_score IS NULL OR l_score < l_best_score THEN
      l_best_score := l_score;
      o_mascara    := k;
      FOR i IN 0 .. o_lado * o_lado - 1 LOOP
        o_mat(i) := l_cand(i);
      END LOOP;
    END IF;
  END LOOP;
END qr_matriz;

--------------------------------------------------------------------------------
-- bc_padrao: o padrao de barras de uma simbologia, como texto de 0 e 1
--
-- O despacho por simbologia estava dentro do AddBarcode. Aqui nao se desenha:
-- quem recebe o padrao decide a largura de cada modulo e desenha.
--------------------------------------------------------------------------------
FUNCTION bc_padrao(p_codigo IN VARCHAR2, p_tipo IN VARCHAR2 DEFAULT 'CODE128',
                   p_ratio IN NUMBER DEFAULT 3) RETURN VARCHAR2 IS
  l_tipo VARCHAR2(20) := UPPER(TRIM(NVL(p_tipo, 'CODE128')));
  l_mods VARCHAR2(32767);
BEGIN
  IF p_codigo IS NULL THEN
    raise_application_error(-20880, 'AddBarcode: codigo vazio.');
  END IF;

  l_mods := CASE l_tipo
              WHEN 'CODE39'  THEN bc_code39(p_codigo, p_ratio)
              WHEN 'CODE128' THEN bc_code128(p_codigo)
              WHEN 'EAN13'   THEN bc_ean(p_codigo, 13)
              WHEN 'EAN8'    THEN bc_ean(p_codigo, 8)
              WHEN 'ITF14'   THEN bc_itf14(p_codigo, p_ratio)
              WHEN 'ITF'     THEN bc_itf(p_codigo, p_ratio)
            END;
  IF l_mods IS NULL THEN
    raise_application_error(-20882,
      'Simbologia nao suportada: ' || p_tipo ||
      '. Use CODE128, CODE39, EAN13, EAN8, ITF ou ITF14.');
  END IF;
  RETURN l_mods;
END bc_padrao;

--------------------------------------------------------------------------------
-- hex_do_byte: os dois digitos hexadecimais de um byte
--
-- A tabela existe para remontar RAW sem passar por CHR(n), que nao devolve um
-- byte e sim o caractere daquele ponto de codigo. Quem precisa dela fora daqui
-- e o desfazedor de predictor do PNG.
--------------------------------------------------------------------------------
FUNCTION hex_do_byte(p_b IN PLS_INTEGER) RETURN VARCHAR2 IS
BEGIN
  aes_init;
  RETURN g_aes_hex(p_b);
END hex_do_byte;

END PL_FPDF_UTIL;
/
