--------------------------------------------------------------------------------
-- PL_FPDF 3.3.0 — instalação completa
--
-- Gerado por dev/scripts/build_release.py. NÃO EDITE ESTE ARQUIVO: mexa em
-- src/ e gere de novo.
--
-- Como usar: abra na SQL Window do PL/SQL Developer e execute (F8), ou rode no
-- SQL*Plus / SQLcl com @pl_fpdf_install.sql. Não cria tabela, sequência nem
-- diretório — só os dois packages.
--
-- Só há SQL aqui: nenhum comando de SQL*Plus, para o arquivo rodar igual em
-- qualquer ferramenta. O SELECT do fim diz se ficou tudo VALID.
--
-- Requisitos: Oracle 19c ou superior. Nenhuma dependência externa — nem para
-- criptografia (MD5 e SHA saem do STANDARD_HASH; RC4 e AES são implementados
-- no próprio package).
--
-- Licença MIT. https://github.com/Maxwbh/pl_fpdf
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- PACKAGE PL_FPDF_UTIL — utilitário: QR Code, códigos de barras, DEFLATE e criptografia
--------------------------------------------------------------------------------
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
-- O deflate e a cifra sao formatos de terceiros, validados fora do banco
-- contra o zlib, os vetores do FIPS-197 e o MuPDF.
--
-- A separacao foi medida antes de ser feita: 57 subprogramas, UMA chamada para
-- fora (tres linhas de log, que sairam) e UM estado compartilhado, a tabela
-- byte->hexadecimal, exposta aqui por hex_do_byte.
--
-- INSTALACAO: este package PRIMEIRO, o PL_FPDF depois. Recompilar este
-- invalida o PL_FPDF, que precisa ser recompilado em seguida.
--
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- License: MIT
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE PL_FPDF_UTIL AS

co_version CONSTANT VARCHAR2(10) := '3.2.0';

-- Matriz do QR Code: um PLS_INTEGER 0/1 por modulo, em linha
-- (indice = linha * lado + coluna).
TYPE tqr IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

--------------------------------------------------------------------------------
-- QR Code (ISO/IEC 18004), versoes 1 a 20
--
-- Referencia validada no zxing-cpp (24/24): scripts/qr_reference/
--------------------------------------------------------------------------------
-- Devolve a matriz com a mascara de menor penalidade ja aplicada.
--   -20870 conteudo vazio | -20872 nivel de correcao invalido
PROCEDURE qr_matriz(p_dados   IN  VARCHAR2,
                    p_ec      IN  VARCHAR2 DEFAULT 'M',
                    o_mat     OUT NOCOPY tqr,
                    o_lado    OUT PLS_INTEGER,
                    o_versao  OUT PLS_INTEGER,
                    o_mascara OUT PLS_INTEGER);

--------------------------------------------------------------------------------
-- Codigos de barras lineares
--
-- Referencia validada no zxing-cpp (45/45): scripts/barcode_reference/
--------------------------------------------------------------------------------
-- O padrao de barras como texto de '0' e '1', um caractere por modulo.
-- Simbologias: CODE128, CODE39, EAN13, EAN8, ITF, ITF14.
--   -20880 codigo vazio | -20882 simbologia nao suportada
FUNCTION bc_padrao(p_codigo IN VARCHAR2,
                   p_tipo   IN VARCHAR2 DEFAULT 'CODE128',
                   p_ratio  IN NUMBER   DEFAULT 3) RETURN VARCHAR2;

--------------------------------------------------------------------------------
-- DEFLATE (RFC 1951) e zlib (RFC 1950), nos dois sentidos
--
-- O UTL_COMPRESS nao serve para ler: ele so aceita rodape gzip com CRC-32
-- correto, e esse CRC e do conteudo DESCOMPRIMIDO. Referencias validadas
-- contra o zlib: scripts/pdfinflate_reference/ e scripts/pdfdeflate_reference/
--------------------------------------------------------------------------------
-- Descomprime um fluxo zlib. O teto existe porque stream de terceiro e entrada
-- NAO CONFIAVEL: alguns KB podem virar gigabytes (zip bomb).
--   -20890 truncado | -20891 dados malformados | -20892 cabecalho invalido
--   -20893 passou do teto | -20894 tabela interna inconsistente
PROCEDURE inflate(p_src IN            BLOB,
                  o_dst IN OUT NOCOPY BLOB,
                  p_max IN            PLS_INTEGER DEFAULT 8388608);

-- Comprime num fluxo zlib: um bloco com Huffman FIXA e LZ77 guloso, com
-- escape para bloco armazenado quando nao compensa — a saida nunca fica maior
-- que a entrada mais o custo do bloco.
PROCEDURE deflate(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB);

-- Os dois digitos hexadecimais de um byte (0..255). Existe para remontar RAW
-- sem passar por CHR(n), que nao devolve um byte e sim o caractere daquele
-- ponto de codigo — em AL32UTF8, todo valor de 128 a 255 sai com DOIS bytes.
FUNCTION hex_do_byte(p_b IN PLS_INTEGER) RETURN VARCHAR2;

--------------------------------------------------------------------------------
-- Criptografia
--
-- Sem DBMS_CRYPTO, por decisao: MD5 e SHA saem do STANDARD_HASH, e RC4 e AES
-- sao implementados aqui. Referencia validada nos vetores do FIPS-197 e no
-- MuPDF (29/29): scripts/pdfaes_reference/
--------------------------------------------------------------------------------
FUNCTION  crypto_md5(p_src IN RAW) RETURN RAW;
FUNCTION  crypto_rc4(p_src IN RAW, p_key IN RAW) RETURN RAW;
PROCEDURE crypto_rc4_blob(p_src IN BLOB, p_key IN RAW,
                          o_dst IN OUT NOCOPY BLOB);
-- confere MD5 e RC4 contra vetores publicos; levanta se divergir
PROCEDURE crypto_autoteste;

-- AES-128/256 em CBC, e as rotinas do revisionamento 6 (AES-256, PDF 2.0)
PROCEDURE aes_cbc_cifrar(p_chave IN            RAW,
                         p_dados IN            BLOB,
                         o_saida IN OUT NOCOPY BLOB,
                         p_iv    IN            RAW DEFAULT NULL);
FUNCTION  aes_cbc_cifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW;
PROCEDURE aes_cbc_decifrar(p_chave IN            RAW,
                           p_dados IN            BLOB,
                           o_saida IN OUT NOCOPY BLOB);
FUNCTION  aes_cbc_decifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW;
FUNCTION  aes_chave_objeto(p_chave   IN RAW,
                           p_obj_num IN PLS_INTEGER,
                           p_gen_num IN PLS_INTEGER DEFAULT 0) RETURN RAW;
FUNCTION  aes_iv RETURN RAW;
PROCEDURE aes_valores_r6(p_senha_usr  IN  VARCHAR2,
                         p_senha_dono IN  VARCHAR2,
                         p_chave      IN  RAW,
                         p_perms      IN  NUMBER,
                         o_u          OUT RAW,
                         o_ue         OUT RAW,
                         o_o          OUT RAW,
                         o_oe         OUT RAW,
                         o_perms      OUT RAW);
FUNCTION  aes_verificar_r6(p_senha IN  VARCHAR2,
                           p_u     IN  RAW,
                           p_ue    IN  RAW,
                           p_o     IN  RAW,
                           p_oe    IN  RAW,
                           o_chave OUT RAW,
                           o_dono  OUT BOOLEAN) RETURN BOOLEAN;
-- confere o AES contra os vetores do FIPS-197; levanta se divergir
PROCEDURE aes_autoteste;

END PL_FPDF_UTIL;
/

--------------------------------------------------------------------------------
-- PACKAGE BODY PL_FPDF_UTIL
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- PACKAGE PL_FPDF — a biblioteca de PDF
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE PL_FPDF AS
/*******************************************************************************
*                                                                              *
*                            PL_FPDF v3.3.0                                    *
*                Oracle PL/SQL PDF Generation and Manipulation                *
*                                                                              *
********************************************************************************
*                                                                              *
* English:                                                                     *
* --------                                                                     *
* Pure PL/SQL library for generating and manipulating PDF documents directly  *
* in Oracle Database. No external dependencies, Java, or additional services  *
* required.                                                                    *
*                                                                              *
* Português (Brasil):                                                          *
* ------------------                                                           *
* Biblioteca PL/SQL pura para gerar e manipular documentos PDF diretamente    *
* no Oracle Database. Sem dependências externas, Java ou serviços adicionais. *
*                                                                              *
********************************************************************************
*                                                                              *
* Version / Versão: 3.2.0                                                      *
* Release Date / Data de Lançamento: July 2026 / Julho 2026                  *
* Status: Production Ready / Pronto para Produção                             *
*                                                                              *
* GitHub: https://github.com/maxwbh/pl_fpdf                                    *
* Documentation / Documentação: /docs                                          *
*                                                                              *
********************************************************************************
*                                                                              *
* FEATURES / RECURSOS:                                                         *
*                                                                              *
* Phase 1-3 (v2.0.0): PDF Generation / Geração de PDF                         *
* ──────────────────────────────────────────────────────────────────           *
* ✓ Create PDFs from scratch / Criar PDFs do zero                             *
* ✓ Text, images, shapes / Texto, imagens, formas                             *
* ✓ Multi-page documents / Documentos multi-página                            *
* ✓ TrueType fonts, UTF-8 / Fontes TrueType, UTF-8                            *
* ✓ Barcodes (Code39, EAN-13, QR) / Códigos de barras                         *
* ✓ Tables with auto-pagination / Tabelas com auto-paginação                  *
*                                                                              *
* Phase 4 (v3.0.0): PDF Manipulation / Manipulação de PDF                     *
* ──────────────────────────────────────────────────────────────────           *
* ✓ Load and parse PDFs / Carregar e parsear PDFs                             *
* ✓ Extract page info / Extrair informações de páginas                        *
* ✓ Rotate pages / Rotacionar páginas                                         *
* ✓ Remove pages / Remover páginas                                            *
* ✓ Add watermarks / Adicionar marcas d'água                                  *
* ✓ Output modified PDFs / Gerar PDFs modificados                             *
*                                                                              *
********************************************************************************
*                                                                              *
* NOTAS DE IMPLEMENTAÇÃO / IMPLEMENTATION NOTES:                               *
*                                                                              *
* Buffers de escrita / Write buffers                                           *
* ──────────────────────────────────────────────────────────────────           *
* O conteúdo de cada página e a estrutura do arquivo são acumulados em         *
* VARCHAR2 e descarregados em CLOB temporário a cada ~32 KB. Não há limite     *
* de tamanho por página, e o custo de montar a página é linear.                *
*   Page content and file structure are accumulated in VARCHAR2 and flushed    *
*   to a temporary CLOB every ~32 KB. No per-page size limit; linear cost.     *
*                                                                              *
* Independência de NLS / NLS independence                                      *
* ──────────────────────────────────────────────────────────────────           *
* A conversão numérica usa NLS explícito ('.' como separador decimal, exigido  *
* pelo PDF). A biblioteca NÃO altera NLS_NUMERIC_CHARACTERS da sessão do       *
* chamador — funciona igual com a sessão em pt-BR (vírgula) ou en-US (ponto).  *
*   Numeric conversion uses an explicit NLS parameter; the caller's session    *
*   settings are never modified.                                               *
*                                                                              *
* Callbacks de header/rodapé / Header-footer callbacks                         *
* ──────────────────────────────────────────────────────────────────           *
* SetHeaderProc/SetFooterProc recebem o NOME de uma rotina, executada           *
* dinamicamente a cada página. O nome e os nomes dos parâmetros são validados   *
* como identificadores SQL (DBMS_ASSERT) no momento da configuração.           *
* Requer EXECUTE em SYS.DBMS_ASSERT (concedido a PUBLIC por padrão).            *
*   The callback name and parameter names are validated as SQL identifiers      *
*   at configuration time. Requires EXECUTE on SYS.DBMS_ASSERT.                 *
*                                                                              *
* Diagnóstico / Diagnostics                                                     *
* ──────────────────────────────────────────────────────────────────           *
* Erros são levantados como ORA-20100 com o backtrace da origem e preservando   *
* a pilha original (keeperrorstack), o que mantém rastreável o erro real.       *
*   Errors are raised as ORA-20100 including the backtrace and keeping the      *
*   original error stack.                                                       *
*                                                                              *
* Estado de sessão / Session state                                             *
* ──────────────────────────────────────────────────────────────────           *
* O estado vive no package (package-only: sem tabelas, types ou sequences).    *
* Use Reset para liberar os LOBs temporários ao fim de jobs longos.            *
*   State lives in the package. Call Reset to free temporary LOBs.             *
*                                                                              *
********************************************************************************
*                                                                              *
* CREDITS / CRÉDITOS:                                                          *
*                                                                              *
* Original FPDF (PHP): Olivier PLATHEY (http://www.fpdf.org/)                 *
* PL/SQL Port: Pierre-Gilles Levallois, Anton Scheffer, Marcel Amman          *
* Modernization & Phase 4: Maxwell Oliveira (@maxwbh)                         *
*                                                                              *
********************************************************************************
*                                                                              *
* LICENSE / LICENÇA: MIT License                                               *
*                                                                              *
* Copyright (c) 2026 Maxwell Oliveira and contributors                         *
*                                                                              *
* Permission is hereby granted, free of charge, to any person obtaining a      *
* copy of this software and associated documentation files (the "Software"),   *
* to deal in the Software without restriction, including without limitation    *
* the rights to use, copy, modify, merge, publish, distribute, sublicense,     *
* and/or sell copies of the Software, and to permit persons to whom the        *
* Software is furnished to do so, subject to the following conditions:         *
*                                                                              *
* The above copyright notice and this permission notice shall be included in   *
* all copies or substantial portions of the Software.                          *
*                                                                              *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING      *
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER          *
* DEALINGS IN THE SOFTWARE.                                                    *
*                                                                              *
*******************************************************************************/
-- Public types and subtypes.
subtype word is varchar2(80);

type tv4000a is table of varchar2(4000) index by word;

--Point type use in polygons creation
type point is record (x number, y number);

type tab_points is table of point index by pls_integer;

/*******************************************************************************
* Type: recImageBlob
* Description: Native BLOB-based image container replacing deprecated ORDSYS.ORDIMAGE.
*              Supports PNG and JPEG formats with header parsing for metadata.
* Fields:
*   image_blob - The raw image data as BLOB
*   mime_type - MIME type ('image/png', 'image/jpeg', 'image/jpg')
*   file_format - File format code ('PNG', 'JPEG', 'JPG')
*   width - Image width in pixels (parsed from header)
*   height - Image height in pixels (parsed from header)
*   bit_depth - Bits per channel (8, 16, 24, 32)
*   color_type - PNG color type or JPEG marker (0=grayscale, 2=RGB, 3=indexed, 4=gray+alpha, 6=RGBA)
*   has_transparency - TRUE if image has alpha channel or transparency
*******************************************************************************/
type recImageBlob is record (
  image_blob blob,
  mime_type varchar2(100),
  file_format varchar2(20),
  width integer,
  height integer,
  bit_depth integer,
  color_type integer,
  has_transparency boolean
);

-- Global constants / Constantes globais
co_version CONSTANT VARCHAR2(10) := '3.3.0';  -- PL_FPDF Version / Versão
noParam tv4000a;

/*******************************************************************************
*                                                                              *
*                         PACKAGE STRUCTURE / ESTRUTURA                        *
*                                                                              *
********************************************************************************
*                                                                              *
* This package is organized into functional groups:                           *
* Este pacote está organizado em grupos funcionais:                           *
*                                                                              *
* 1. INITIALIZATION & LIFECYCLE / INICIALIZAÇÃO E CICLO DE VIDA               *
*    ├─ Init()           - Initialize PDF engine / Inicializar engine         *
*    ├─ Reset()          - Reset state / Resetar estado                       *
*    └─ SetLogLevel()    - Configure logging / Configurar logging             *
*                                                                              *
* 2. PAGE MANAGEMENT / GERENCIAMENTO DE PÁGINAS                               *
*    ├─ AddPage()        - Add new page / Adicionar nova página               *
*    ├─ PageNo()         - Get page number / Obter número da página           *
*    └─ AliasNbPages()   - Total pages placeholder / Placeholder p/ total     *
*                                                                              *
* 3. TEXT & FONTS / TEXTO E FONTES                                            *
*    ├─ SetFont()        - Set current font / Definir fonte atual             *
*    ├─ Cell()           - Print cell / Imprimir célula                       *
*    ├─ MultiCell()      - Print multi-line / Imprimir multi-linha            *
*    ├─ Write()          - Write text / Escrever texto                        *
*    └─ Text()           - Place text at position / Colocar texto em posição  *
*                                                                              *
* 4. GRAPHICS / GRÁFICOS                                                       *
*    ├─ Line()           - Draw line / Desenhar linha                         *
*    ├─ Rect()           - Draw rectangle / Desenhar retângulo                *
*    ├─ Circle()         - Draw circle / Desenhar círculo                     *
*    └─ Polygon()        - Draw polygon / Desenhar polígono                   *
*                                                                              *
* 5. IMAGES / IMAGENS                                                          *
*    ├─ Image()          - Insert image / Inserir imagem                      *
*    └─ LoadImageBlob()  - Load image from BLOB / Carregar de BLOB            *
*                                                                              *
* 6. BARCODES / CÓDIGOS DE BARRAS                                              *
*    ├─ AddBarcode()     - Add barcode / Adicionar código de barras           *
*    └─ AddQRCode()      - Add QR code / Adicionar QR code                    *
*                                                                              *
* 7. TABLES / TABELAS                                                          *
*    └─ Table()          - Create table / Criar tabela                        *
*                                                                              *
* 8. OUTPUT / SAÍDA                                                            *
*    ├─ OutputBlob()    - Get PDF as BLOB / Obter PDF como BLOB              *
*    └─ OutputFile()     - Save to file / Salvar em arquivo                   *
*                                                                              *
* 9. PHASE 4: PDF READING & MANIPULATION / LEITURA E MANIPULAÇÃO              *
*    ├─ LoadPDF()        - Load existing PDF / Carregar PDF existente         *
*    ├─ GetPageCount()   - Get page count / Obter contagem de páginas         *
*    ├─ GetPageInfo()    - Get page details / Obter detalhes da página        *
*    ├─ GetPDFInfo()     - Get PDF metadata / Obter metadados do PDF          *
*    ├─ RotatePage()     - Rotate page / Rotacionar página                    *
*    ├─ RemovePage()     - Remove page / Remover página                       *
*    ├─ AddWatermark()   - Add watermark / Adicionar marca d'água             *
*    ├─ GetWatermarks()  - List watermarks / Listar marcas d'água             *
*    ├─ OutputModifiedPDF() - Generate modified / Gerar modificado            *
*    └─ ClearPDFCache()  - Clear cache / Limpar cache                         *
*                                                                              *
*******************************************************************************/

--------------------------------------------------------------------------------
-- Phase 4 Complete / Fase 4 Completa
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: Init
* Description: Initializes the PDF generation engine with modern Oracle 19c+
*              features including UTF-8 support and CLOB buffers.
*              Replaces/extends the legacy fpdf() constructor.
* Parameters:
*   p_orientation - Page orientation ('P'=Portrait, 'L'=Landscape)
*   p_unit - Measurement unit ('mm', 'cm', 'in', 'pt')
*   p_format - Page format ('A4', 'Letter', 'Legal', etc.)
*   p_encoding - Character encoding (default 'UTF-8')
* Raises:
*   -20001: Invalid orientation parameter
*   -20002: Invalid measurement unit
*   -20003: Unsupported encoding
* Example:
*   PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
*******************************************************************************/
procedure Init(
  p_orientation varchar2 default 'P',
  p_unit varchar2 default 'mm',
  p_format varchar2 default 'A4',
  p_encoding varchar2 default 'UTF-8'
);

/*******************************************************************************
* Procedure: Reset
* Description: Resets the PDF engine to initial state, freeing all resources
*              including temporary CLOBs and clearing all arrays.
* Example:
*   PL_FPDF.Reset();
*******************************************************************************/
procedure Reset;

/*******************************************************************************
* Function: IsInitialized
* Description: Checks if the PDF engine has been properly initialized via Init()
* Returns: TRUE if initialized, FALSE otherwise
* Example:
*   IF PL_FPDF.IsInitialized() THEN ...
*******************************************************************************/
function IsInitialized return boolean
  DETERMINISTIC;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

/*******************************************************************************
* Type: recPageFormat
* Description: Record type for page dimensions (width x height)
*******************************************************************************/
type recPageFormat is record (
  width number(10,5),
  height number(10,5)
);

/*******************************************************************************
* Type: recPage
* Description: Enhanced page structure with CLOB content and metadata
* Fields:
*   number_val - Page number
*   orientation - Page orientation ('P' or 'L')
*   format - Page dimensions (recPageFormat)
*   rotation - Page rotation in degrees (0, 90, 180, 270)
*   content_clob - CLOB for page content (replaces VARCHAR2 array)
*   created_at - Timestamp when page was created
*******************************************************************************/
type recPage is record (
  number_val pls_integer,
  orientation varchar2(1),
  format recPageFormat,
  rotation pls_integer default 0,
  content_clob clob,
  created_at timestamp default systimestamp
);

/*******************************************************************************
* Type: tPages
* Description: Collection of pages indexed by page number
*******************************************************************************/
type tPages is table of recPage index by pls_integer;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

/*******************************************************************************
* Type: recTTFFont
* Description: TrueType font structure with parsed metrics
*******************************************************************************/
type recTTFFont is record (
  font_name varchar2(100),
  file_name varchar2(255),
  font_blob blob,
  encoding varchar2(20) default 'UTF-8',
  units_per_em number,
  ascent number,
  descent number,
  line_gap number default 0,
  cap_height number default 0,
  x_height number default 0,
  is_bold boolean default false,
  is_italic boolean default false,
  is_embedded boolean default true,
  loaded_at timestamp default systimestamp
);

/*******************************************************************************
* Type: tTTFFonts
* Description: Collection of TrueType fonts indexed by font name
*******************************************************************************/
type tTTFFonts is table of recTTFFont index by varchar2(100);

/*******************************************************************************
* Procedure: AddTTFFont - Add TrueType font from BLOB
*******************************************************************************/
procedure AddTTFFont(
  p_font_name varchar2,
  p_font_blob blob,
  p_encoding varchar2 default 'UTF-8',
  p_embed boolean default true
);

/*******************************************************************************
* Procedure: LoadTTFFromFile - Load TrueType from filesystem
*******************************************************************************/
procedure LoadTTFFromFile(
  p_font_name varchar2,
  p_file_path varchar2,
  p_directory varchar2 default 'FONTS_DIR',
  p_encoding varchar2 default 'UTF-8'
);

/*******************************************************************************
* Function: IsTTFFontLoaded - Check if font is loaded
*******************************************************************************/
function IsTTFFontLoaded(p_font_name varchar2) return boolean;

/*******************************************************************************
* Function: GetTTFFontInfo - Get font metadata
*******************************************************************************/
function GetTTFFontInfo(p_font_name varchar2) return recTTFFont;

/*******************************************************************************
* Procedure: ClearTTFFontCache - Clear font cache
*******************************************************************************/
procedure ClearTTFFontCache;

/*******************************************************************************
* Function: UTF8ToPDFString - Convert UTF-8 text to PDF-compatible string
* Description: Converts UTF-8 encoded text to PDF string format
* Parameters:
*   p_text - UTF-8 text to convert
*   p_escape - Whether to escape PDF special characters (default true)
* Returns: PDF-compatible string
*******************************************************************************/
function UTF8ToPDFString(
  p_text varchar2,
  p_escape boolean default true
) return varchar2;

/*******************************************************************************
* Function: IsUTF8Enabled - Check if UTF-8 encoding is enabled
*******************************************************************************/
function IsUTF8Enabled return boolean;

/*******************************************************************************
* Procedure: SetUTF8Enabled - Enable/disable UTF-8 encoding
*******************************************************************************/
procedure SetUTF8Enabled(p_enabled boolean default true);

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

/*******************************************************************************
* Custom Exceptions for PL_FPDF
* Provides specific exception handling instead of generic ORA-20100 errors
*******************************************************************************/

-- Initialization Errors (-20001 to -20010)
exc_invalid_orientation EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_orientation, -20001);

exc_invalid_unit EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_unit, -20002);

exc_invalid_encoding EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_encoding, -20003);

exc_not_initialized EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_not_initialized, -20005);

-- Page Errors (-20101 to -20110)
exc_invalid_page_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_page_format, -20101);

exc_page_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_page_not_found, -20106);

-- Font Errors (-20201 to -20215)
exc_font_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_font_not_found, -20201);

exc_invalid_font_file EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_file, -20202);

exc_invalid_font_name EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_name, -20210);

exc_invalid_font_blob EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_blob, -20211);

-- Image Errors (-20301 to -20310)
exc_invalid_image EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_image, -20301);

exc_image_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_image_not_found, -20302);

exc_unsupported_image_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_unsupported_image_format, -20303);

-- File I/O Errors (-20401 to -20410)
exc_invalid_directory EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_directory, -20401);

exc_file_access_denied EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_access_denied, -20402);

exc_file_write_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_write_error, -20403);

-- Color/Drawing Errors (-20501 to -20510)
exc_invalid_color EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_color, -20501);

exc_invalid_line_width EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_line_width, -20502);

-- General Errors (-20100)
exc_general_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_general_error, -20100);

--------------------------------------------------------------------------------
-- End of TASK 2.2 & 2.4 additions
--------------------------------------------------------------------------------

-- methods added to FPDF
function GetCurrentFontSize return number;
function GetCurrentFontStyle return varchar2;
function GetCurrentFontFamily return varchar2;
procedure SetDash(pblack in number default 0, pwhite in number default 0);
function GetLineSpacing return number;
Procedure SetLineSpacing (pls in number);
-- Allows to create a polygon with a table of points
-- pclose define if the polygon is closed or not
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');
-- Triangulo isosceles: base 2*psize, altura psize, ponta para porientation.
-- (px, py) e o canto superior esquerdo da caixa que envolve o triangulo.
-- Levanta -20821 se a orientacao nao for up/down/left/right (ou U/D/L/R).
procedure Triangle(px in number, py in number, psize in number,
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

-- FPDF public methods
procedure Ln(h number default null);
function  GetX return number;
procedure SetX(px in number);
function  GetY return number;
procedure SetY(py in number);
procedure SetXY(x in number,y in number);
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam);
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam);
procedure SetMargins(left in number, top in number, right in number default -1);
procedure SetLeftMargin(pMargin in number);
procedure SetTopMargin(pMargin in number);
procedure SetRightMargin(pMargin in number);
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0);
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous');
procedure SetCompression(p_compress in boolean default false);
procedure SetTitle(ptitle in varchar2);
procedure SetSubject(psubject in varchar2);
procedure SetAuthor(pauthor in varchar2);
procedure SetKeywords(pkeywords in varchar2);
procedure SetCreator(pcreator in varchar2);
procedure SetAliasNbPages(palias in varchar2 default '{nb}');
procedure Header;
procedure Footer;
function  PageNo return number;
procedure SetDrawColor(r in number, g in number default -1, b in number default -1);
procedure SetFillColor (r in number, g in number default -1, b in number default -1);
procedure SetTextColor (r in number, g in number default -1, b in number default -1);
procedure SetLineWidth(width in number);
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number);
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '');
function  AddLink return number;
procedure SetLink(plink in number, py in number default 0, ppage in number default -1);
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2);
procedure Text(px in number, py in number, ptxt in varchar2);
function  AcceptPageBreak return boolean;
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '');
procedure SetFont(pfamily in varchar2,pstyle in varchar2 default '', psize in number default 0);
function GetStringWidth(pstr in varchar2) return number;
procedure SetFontSize(psize in number);
procedure Cell
		 (pw in number,
		  ph in number default 0,
		  ptxt in varchar2 default '',
		  pborder in varchar2 default '0',
		  pln in number default 0,
		  palign in varchar2 default '',
		  pfill in number default 0,
		  plink in varchar2 default '');
--Now return the number of line created with multiCell
function MultiCell
  ( pw in number,
    ph in number default 0,
	ptxt in varchar2,
	pborder in varchar2 default '0',
	palign in varchar2 default 'J',
	pfill in number default 0,
	phMax in number default 0) return number;

procedure MultiCell
  ( pwidth in number,
    pheight in number default 0,
    ptext in varchar2,
    pbrdr in varchar2 default '0',
    palignment in varchar2 default 'J',
    pfillin in number default 0,
    phMaximum in number default 0);

procedure Write(pH in varchar2, ptxt in varchar2, plink in varchar2 default null);

--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: CellRotated
* Description: Modern Cell with text rotation support
* Parameters:
*   p_width - Cell width (0 = extend to right margin)
*   p_height - Cell height
*   p_text - Text content
*   p_border - Border: 0=none, 1=frame, or combination of L,T,R,B
*   p_ln - Line break: 0=right, 1=below, 2=below
*   p_align - Alignment: L=left, C=center, R=right
*   p_fill - Fill: 0=no fill, 1=fill
*   p_link - URL/internal link
*   p_rotation - Text rotation: 0, 90, 180, 270 degrees
* Raises:
*   -20110: Invalid rotation value
*******************************************************************************/
procedure CellRotated(
  p_width number,
  p_height number default 0,
  p_text varchar2 default '',
  p_border varchar2 default '0',
  p_ln number default 0,
  p_align varchar2 default '',
  p_fill number default 0,
  p_link varchar2 default '',
  p_rotation pls_integer default 0
);

/*******************************************************************************
* Procedure: WriteRotated
* Description: Modern Write with text rotation support
* Parameters:
*   p_height - Line height
*   p_text - Text content
*   p_link - URL/internal link
*   p_rotation - Text rotation: 0, 90, 180, 270 degrees
* Raises:
*   -20110: Invalid rotation value
*******************************************************************************/
procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
);

procedure image ( pFile in varchar2, 
		  		pX in number, 
				  pY in number, 
				  pWidth in number default 0,
				  pHeight in number default 0,
				  pType in varchar2 default null,
				  pLink in varchar2 default null);
				  
procedure Output(pname in varchar2 default null, pdest in varchar2 default null);
function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null) return blob;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function OutputBlob return blob;
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

procedure OpenPDF;
procedure ClosePDF;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddPage
* Description: Adds a new page to the PDF document with modern CLOB streaming
*              and support for custom formats and rotation
* Parameters:
*   p_orientation - Page orientation ('P'=Portrait, 'L'=Landscape, NULL=current)
*   p_format - Page format ('A4', 'Letter', 'Legal', 'width,height', NULL=current)
*   p_rotation - Page rotation in degrees (0, 90, 180, 270)
* Raises:
*   -20005: PDF not initialized (call Init first)
*   -20107: Invalid orientation (only 'P' or 'L')
*   -20103: Unknown page format
*   -20101: Invalid custom format dimensions
*   -20104: Invalid rotation value (only 0, 90, 180, 270)
* Example:
*   PL_FPDF.AddPage('P', 'A4', 0);
*   PL_FPDF.AddPage('L', '210,297', 90);  -- Custom format with rotation
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
*******************************************************************************/
procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
);

/*******************************************************************************
* Procedure: SetPage
* Description: Sets the current active page for content manipulation
* Parameters:
*   p_page_number - Page number to set as current (must exist)
* Raises:
*   -20005: PDF not initialized (call Init first)
*   -20106: Page does not exist
* Example:
*   PL_FPDF.SetPage(1);  -- Go back to page 1
*******************************************************************************/
procedure SetPage(p_page_number pls_integer);

/*******************************************************************************
* Function: GetCurrentPage
* Description: Returns the current page number
* Returns: Current page number (PLS_INTEGER)
* Example:
*   l_page := PL_FPDF.GetCurrentPage();
*******************************************************************************/
function GetCurrentPage return pls_integer
  DETERMINISTIC;

--------------------------------------------------------------------------------
-- Legacy compatibility (maintained for backward compatibility)
--------------------------------------------------------------------------------
procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');
procedure Error(pmsg in varchar2);
procedure DebugEnabled;
procedure DebugDisabled;
function GetScaleFactor return number;

/*******************************************************************************
* Function: getImageFromUrl
* Description: Fetches an image from a URL and returns it as a native BLOB
*              with parsed metadata (dimensions, format, etc.)
*              Replaces legacy OrdImage-based implementation.
* Parameters:
*   p_Url - Image URL (http/https)
* Returns: recImageBlob with image data and metadata
* Supported Formats: PNG, JPEG/JPG
* Raises:
*   -20301: Invalid image header (PNG or JPEG)
*   -20302: Unable to fetch image from URL
*   -20303: Unsupported image format (only PNG and JPEG)
* Example:
*   l_img := PL_FPDF.getImageFromUrl('http://example.com/image.png');
*******************************************************************************/
function getImageFromUrl(p_Url in varchar2) return recImageBlob;


--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: SetLogLevel
* Description: Sets the logging level for debugging
* Parameters:
*   p_level - Log level (0=OFF, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG)
*******************************************************************************/
procedure SetLogLevel(p_level pls_integer);

/*******************************************************************************
* Function: GetLogLevel
* Description: Returns the current logging level
* Returns: Current log level (0-4)
*******************************************************************************/
function GetLogLevel return pls_integer
  DETERMINISTIC;

--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: SetDocumentConfig
* Description: Configure PDF document using JSON_OBJECT_T for modern integration
* Parameters:
*   p_config - JSON object containing configuration options
* Supported JSON keys:
*   - title, author, subject, keywords, creator (document metadata)
*   - orientation ('P' or 'L'), unit ('mm','cm','in','pt'), format (page format)
*   - fontFamily, fontSize, fontStyle (default font configuration)
*   - leftMargin, topMargin, rightMargin (page margins in current unit)
* Example:
*   DECLARE
*     l_config JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     l_config.put('title', 'Monthly Report');
*     l_config.put('author', 'Maxwell Oliveira');
*     l_config.put('orientation', 'P');
*     l_config.put('format', 'A4');
*     PL_FPDF.SetDocumentConfig(l_config);
*   END;
*******************************************************************************/
procedure SetDocumentConfig(p_config JSON_OBJECT_T);

/*******************************************************************************
* Function: GetDocumentMetadata
* Description: Returns document metadata and statistics as JSON_OBJECT_T
* Returns: JSON object with document information
* JSON structure:
*   {
*     "pageCount": <number>,
*     "title": "<string>",
*     "author": "<string>",
*     "subject": "<string>",
*     "keywords": "<string>",
*     "format": "<string>",
*     "orientation": "<string>",
*     "unit": "<string>",
*     "initialized": <boolean>
*   }
* Example:
*   DECLARE
*     l_meta JSON_OBJECT_T;
*   BEGIN
*     l_meta := PL_FPDF.GetDocumentMetadata();
*     DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
*   END;
*******************************************************************************/
function GetDocumentMetadata return JSON_OBJECT_T;

/*******************************************************************************
* Function: GetPageInfo
* Description: Returns information about a specific page as JSON_OBJECT_T
* Parameters:
*   p_page_number - Page number (NULL = current page)
* Returns: JSON object with page information
* JSON structure:
*   {
*     "number": <number>,
*     "format": "<string>",
*     "orientation": "<string>",
*     "width": <number>,
*     "height": <number>,
*     "unit": "<string>"
*   }
* Example:
*   DECLARE
*     l_page_info JSON_OBJECT_T;
*   BEGIN
*     l_page_info := PL_FPDF.GetPageInfo(1);
*     DBMS_OUTPUT.PUT_LINE('Width: ' || l_page_info.get_Number('width'));
*   END;
*******************************************************************************/
function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--       This package provides only generic QR Code rendering.
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddQRCode
* Description: Adds a generic QR Code to the current page
* Parameters:
*   p_x - X position (in current units)
*   p_y - Y position (in current units)
*   p_size - QR Code size (width=height, in current units)
*   p_data - Data to encode (max 2953 bytes for binary mode)
*   p_format - Format: 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'
*   p_error_correction - Error correction: 'L'(7%), 'M'(15%), 'Q'(25%), 'H'(30%)
* Example:
*   PL_FPDF.AddQRCode(50, 50, 40, 'https://example.com', 'URL', 'M');
*******************************************************************************/
procedure AddQRCode(
  p_x number,
  p_y number,
  p_size number,
  p_data varchar2,
  p_format varchar2 default 'TEXT',
  p_error_correction varchar2 default 'M'
);

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--       This package provides only generic barcode rendering.
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddBarcode
* Description: Adds a generic barcode to the current page
* Parameters:
*   p_x - X position (in current units)
*   p_y - Y position (in current units)
*   p_width - Barcode width (in current units)
*   p_height - Barcode height (in current units)
*   p_code - Data to encode
*   p_type - Barcode type: 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF14',
*            or 'ITF' (Interleaved 2 of 5, any even digit count — the bank
*            boleto barcode has 44) / Simbologia
*   p_show_text - Show human-readable text below barcode
* Example:
*   PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
*******************************************************************************/
procedure AddBarcode(
  p_x number,
  p_y number,
  p_width number,
  p_height number,
  p_code varchar2,
  p_type varchar2 default 'CODE128',
  p_show_text boolean default true
);


/*******************************************************************************
* Procedure: LoadPDF / Carregar PDF
*
* Description / Descrição:
*   EN: Load an existing PDF document into memory for reading and modification
*   PT: Carregar documento PDF existente na memória para leitura e modificação
*
* Parameters / Parâmetros:
*   p_pdf_blob - PDF document as BLOB / Documento PDF como BLOB
*
* Raises / Erros:
*   -20800: Invalid PDF (NULL or too small) / PDF inválido (NULL ou pequeno)
*   -20801: Invalid PDF header / Cabeçalho PDF inválido
*   -20802: startxref not found / startxref não encontrado
*   -20803: Invalid xref table / Tabela xref inválida
*   -20804: Root object not found in trailer / Objeto Root não encontrado
*
* Example / Exemplo:
*   DECLARE
*     l_pdf BLOB;
*   BEGIN
*     SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
*     PL_FPDF.LoadPDF(l_pdf);
*     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || PL_FPDF.GetPageCount());
*   END;
*******************************************************************************/
PROCEDURE LoadPDF(p_pdf_blob BLOB);

/*******************************************************************************
* Function: GetPageCount / Obter Contagem de Páginas
*
* Description / Descrição:
*   EN: Get the total number of pages in the loaded PDF document
*   PT: Obter o número total de páginas no documento PDF carregado
*
* Returns / Retorna:
*   PLS_INTEGER - Number of pages / Número de páginas
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*
* Example / Exemplo:
*   l_pages := PL_FPDF.GetPageCount();
*   DBMS_OUTPUT.PUT_LINE('Total pages / Total de páginas: ' || l_pages);
*******************************************************************************/
FUNCTION GetPageCount RETURN PLS_INTEGER;

/*******************************************************************************
* Function: GetPDFInfo / Obter Informações do PDF
*
* Description / Descrição:
*   EN: Get metadata and information about the loaded PDF document
*   PT: Obter metadados e informações sobre o documento PDF carregado
*
* Returns / Retorna:
*   JSON_OBJECT_T with / com:
*   - version: PDF version (e.g., "1.4") / Versão do PDF
*   - pageCount: Number of pages / Número de páginas
*   - fileSize: Size in bytes / Tamanho em bytes
*   - objectCount: Number of objects in xref / Número de objetos na xref
*   - rootObjectId: Catalog object ID / ID do objeto Catalog
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*
* Example / Exemplo:
*   DECLARE
*     l_info JSON_OBJECT_T;
*   BEGIN
*     l_info := PL_FPDF.GetPDFInfo();
*     DBMS_OUTPUT.PUT_LINE('Version / Versão: ' || l_info.get_string('version'));
*     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || l_info.get_number('pageCount'));
*   END;
*******************************************************************************/
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;

/*******************************************************************************
* Procedure: RotatePage / Rotacionar Página
*
* Description / Descrição:
*   EN: Rotate a specific page (stored in memory, applied on output)
*   PT: Rotacionar uma página específica (armazenado em memória, aplicado na saída)
*
* Parameters / Parâmetros:
*   p_page_number - Page number to rotate / Número da página para rotacionar
*   p_rotation - Rotation angle / Ângulo de rotação (0, 90, 180, 270)
*
* Note / Nota:
*   EN: Changes stored in memory. Use OutputModifiedPDF() to generate PDF
*   PT: Mudanças armazenadas em memória. Use OutputModifiedPDF() para gerar PDF
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   PL_FPDF.RotatePage(1, 90);    -- Rotate page 1 / Rotacionar página 1
*   PL_FPDF.RotatePage(2, 180);   -- Rotate page 2 / Rotacionar página 2
*******************************************************************************/
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER);

/*******************************************************************************
* Procedure: RemovePage / Remover Página
*
* Description / Descrição:
*   EN: Mark a page for removal from the PDF
*   PT: Marcar uma página para remoção do PDF
*
* Parameters / Parâmetros:
*   p_page_number - Page number to remove / Número da página para remover
*
* Note / Nota:
*   EN: Page marked for removal. Use OutputModifiedPDF() to generate modified PDF
*   PT: Página marcada para remoção. Use OutputModifiedPDF() para gerar PDF modificado
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   PL_FPDF.RemovePage(2);  -- Remove page 2 / Remover página 2
*   PL_FPDF.RemovePage(5);  -- Remove page 5 / Remover página 5
*******************************************************************************/
PROCEDURE RemovePage(p_page_number PLS_INTEGER);

/*******************************************************************************
* Function: GetActivePageCount / Obter Contagem de Páginas Ativas
*
* Description / Descrição:
*   EN: Get count of pages not marked for removal
*   PT: Obter contagem de páginas não marcadas para remoção
*
* Returns / Retorna:
*   PLS_INTEGER - Number of active pages / Número de páginas ativas
*
* Note / Nota:
*   EN: Differs from GetPageCount() which returns original count
*   PT: Difere de GetPageCount() que retorna a contagem original
*
* Example / Exemplo:
*   l_total := PL_FPDF.GetPageCount();        -- Original: 10
*   PL_FPDF.RemovePage(2);
*   l_active := PL_FPDF.GetActivePageCount(); -- Active / Ativas: 9
*******************************************************************************/
FUNCTION GetActivePageCount RETURN PLS_INTEGER;

/*******************************************************************************
* Function: IsPageRemoved / Verificar Se Página Foi Removida
*
* Description / Descrição:
*   EN: Check if a page is marked for removal
*   PT: Verificar se uma página está marcada para remoção
*
* Parameters / Parâmetros:
*   p_page_number - Page number to check / Número da página para verificar
*
* Returns / Retorna:
*   BOOLEAN - TRUE if removed / TRUE se removida, FALSE otherwise / caso contrário
*
* Example / Exemplo:
*   IF PL_FPDF.IsPageRemoved(2) THEN
*     DBMS_OUTPUT.PUT_LINE('Page 2 removed / Página 2 removida');
*   END IF;
*******************************************************************************/
FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN;

/*******************************************************************************
* Function: IsPDFModified / Verificar Se PDF Foi Modificado
*
* Description / Descrição:
*   EN: Check if the loaded PDF has been modified
*   PT: Verificar se o PDF carregado foi modificado
*
* Returns / Retorna:
*   BOOLEAN - TRUE if modified / TRUE se modificado, FALSE otherwise / caso contrário
*
* Note / Nota:
*   EN: Use to determine if OutputModifiedPDF() needs to be called
*   PT: Use para determinar se OutputModifiedPDF() precisa ser chamado
*
* Example / Exemplo:
*   IF PL_FPDF.IsPDFModified() THEN
*     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
*   END IF;
*******************************************************************************/
FUNCTION IsPDFModified RETURN BOOLEAN;

/*******************************************************************************
* Procedure: AddWatermark / Adicionar Marca d'Água
*
* Description / Descrição:
*   EN: Add customizable text watermark to specified pages
*   PT: Adicionar marca d'água de texto personaliz Ada em páginas específicas
*
* Parameters / Parâmetros:
*   p_text - Watermark text / Texto da marca d'água
*   p_opacity - Opacity (0.0 to 1.0) / Opacidade (0.0 a 1.0), default 0.3
*   p_rotation - Rotation angle / Ângulo de rotação
*                (0, 45, 90, 135, 180, 225, 270, 315), default 45
*   p_pages - Page range / Range de páginas: 'ALL', '1-5', '1,3,5', default 'ALL'
*   p_font - Font name / Nome da fonte, default 'Helvetica'
*   p_size - Font size in points / Tamanho da fonte em pontos, default 48
*   p_color - Color name / Nome da cor ('gray', 'red', 'blue'), default 'gray'
*
* Note / Nota:
*   EN: Rendered by OutputModifiedPDF() into the page content stream: each
*       affected page gets its own content object and its own /Resources, so a
*       /Resources shared between pages is never contaminated. Centred and
*       rotated about the page centre; the font is always Helvetica.
*   PT: Desenhada por OutputModifiedPDF() no fluxo de conteúdo: cada página
*       afetada ganha um objeto de conteúdo próprio e um /Resources próprio, de
*       modo que um /Resources compartilhado entre páginas nunca é contaminado.
*       Centralizada e girada em torno do centro da página; a fonte é sempre
*       Helvetica.
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   -- All pages / Todas as páginas
*   PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
*   -- Specific pages / Páginas específicas
*   PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
*   -- Custom style / Estilo personalizado
*   PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1', 'Helvetica', 72, 'green');
*******************************************************************************/
PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_pages VARCHAR2 DEFAULT 'ALL',
  p_font VARCHAR2 DEFAULT 'Helvetica',
  p_size NUMBER DEFAULT 48,
  p_color VARCHAR2 DEFAULT 'gray'
);

/*******************************************************************************
* Function: GetWatermarks / Obter Marcas d'Água
*
* Description / Descrição:
*   EN: Get list of all applied watermarks as JSON array
*   PT: Obter lista de todas as marcas d'água aplicadas como array JSON
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array containing watermark objects with properties:
*                  Array contendo objetos de marca d'água com propriedades:
*     - id: Watermark ID / ID da marca d'água
*     - text: Watermark text / Texto da marca d'água
*     - opacity: Opacity value (0.0-1.0) / Valor de opacidade (0.0-1.0)
*     - rotation: Rotation angle in degrees / Ângulo de rotação em graus
*     - pageRange: Parsed page range (comma-separated) / Range de páginas (separado por vírgulas)
*     - font: Font name / Nome da fonte
*     - fontSize: Font size in points / Tamanho da fonte em pontos
*     - color: Color name / Nome da cor
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*
* Example / Exemplo:
*   DECLARE
*     l_watermarks JSON_ARRAY_T;
*     l_watermark JSON_OBJECT_T;
*   BEGIN
*     PL_FPDF.LoadPDF(l_pdf);
*     PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
*     l_watermarks := PL_FPDF.GetWatermarks();
*     FOR i IN 0..l_watermarks.get_size() - 1 LOOP
*       l_watermark := TREAT(l_watermarks.get(i) AS JSON_OBJECT_T);
*       DBMS_OUTPUT.PUT_LINE('Watermark / Marca d''água: ' ||
*                            l_watermark.get_string('text'));
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION GetWatermarks RETURN JSON_ARRAY_T;

/*******************************************************************************
* Function: OutputModifiedPDF / Gerar PDF Modificado
*
* Description / Descrição:
*   EN: Generate the modified PDF, copying the kept pages object by object.
*       Content, fonts, images and annotations are copied verbatim: nothing is
*       re-rendered. Applies RemovePage and RotatePage.
*   PT: Gerar o PDF modificado copiando as páginas mantidas objeto a objeto.
*       Conteúdo, fontes, imagens e anotações são copiados sem alteração: nada
*       é re-renderizado. Aplica RemovePage e RotatePage.
*
* Returns / Retorna:
*   BLOB - Modified PDF document / Documento PDF modificado
*
* Process / Processo:
*   EN: 1. Validates PDF is loaded and modified
*       2. Indexes the source (xref chain + flattened page tree)
*       3. Selects the pages not marked by RemovePage, in the original order
*       4. Copies every object reachable from those pages, renumbering the
*          indirect references; stream payloads are copied byte for byte
*       5. Emits a new Catalog, a new /Pages node, xref and trailer
*   PT: 1. Valida se PDF está carregado e modificado
*       2. Indexa a origem (cadeia de xref + árvore de páginas achatada)
*       3. Seleciona as páginas não marcadas por RemovePage, na ordem original
*       4. Copia todo objeto alcançável a partir dessas páginas, renumerando as
*          referências indiretas; o payload dos streams é copiado byte a byte
*       5. Emite um novo Catalog, um novo nó /Pages, xref e trailer
*
* Limitations / Limitações:
*   EN: Watermarks and text and image overlays are all rendered. PDF 1.5+
*       cross-reference streams and object streams are read (the PNG
*       predictor included); a malformed one raises -20843/-20847/-20848.
*   PT: Marcas d'água e overlays de texto e de imagem são todos desenhados.
*       xref em stream e object streams (PDF 1.5+) são lidos, inclusive com
*       o predictor PNG; um malformado levanta -20843/-20847/-20848.
*
* Raises / Erros:
*   -20809: No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
*   -20819: PDF has not been modified (no changes to apply) /
*           PDF não foi modificado (sem alterações para aplicar)
*   -20820: All pages have been removed (cannot generate empty PDF) /
*           Todas as páginas foram removidas (não pode gerar PDF vazio)
*   -20841: Object dictionary too large to renumber /
*           Dicionário de objeto grande demais para renumerar
*   -20843: Malformed cross-reference stream / xref em stream malformada
*   -20847: Malformed object stream / object stream malformado
*   -20848: Unsupported predictor in the xref stream /
*           predictor não suportado na xref em stream
*   -20823: Invalid or unsupported image / Imagem inválida ou não suportada
*           EN: alpha and interlaced PNG are supported; refused are interlaced
*               below 8 bits per component, indexed AND interlaced, and images
*               above 4 megapixels on the pixel-reprocessing path
*           PT: PNG com alfa e entrelaçado são suportados; recusados são o
*               entrelaçado abaixo de 8 bits por componente, o indexado E
*               entrelaçado, e imagens acima de 4 megapixels no caminho que
*               reprocessa pixels
*   -20846: Page /Resources cannot be overlaid (shared indirect sub-dictionary) /
*           /Resources da página não permite sobreposição (sub-dicionário
*           indireto compartilhado)
*
* Example / Exemplo:
*   DECLARE
*     l_pdf BLOB;
*     l_modified_pdf BLOB;
*   BEGIN
*     -- Load PDF / Carregar PDF
*     SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
*     PL_FPDF.LoadPDF(l_pdf);
*
*     -- Apply modifications / Aplicar modificações
*     PL_FPDF.RotatePage(1, 90);
*     PL_FPDF.RemovePage(3);
*
*     -- Generate modified PDF / Gerar PDF modificado
*     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
*
*     -- Save modified PDF / Salvar PDF modificado
*     UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
*
*     PL_FPDF.ClearPDFCache();
*   END;
*******************************************************************************/
FUNCTION OutputModifiedPDF RETURN BLOB;

/*******************************************************************************
* Procedure: ClearPDFCache / Limpar Cache de PDF
*
* Description / Descrição:
*   EN: Clear loaded PDF from memory and free all cached resources
*   PT: Limpar PDF carregado da memória e liberar todos os recursos em cache
*
* Note / Nota:
*   EN: Always call this after processing a PDF to free memory resources.
*       Clears: loaded PDF, page info, rotations, removed pages, watermarks.
*   PT: Sempre chame isso após processar um PDF para liberar recursos de memória.
*       Limpa: PDF carregado, info páginas, rotações, páginas removidas, marcas d'água.
*
* Example / Exemplo:
*   PL_FPDF.LoadPDF(l_pdf);
*   -- Process PDF / Processar PDF
*   l_modified := PL_FPDF.OutputModifiedPDF();
*   -- Clear memory / Limpar memória
*   PL_FPDF.ClearPDFCache();
*******************************************************************************/
PROCEDURE ClearPDFCache;

/*******************************************************************************
* Function: FlateDecode / Descomprimir stream
*
* Description / Descrição:
*   EN: Decompress a PDF /FlateDecode stream (zlib, RFC 1950). Implemented in
*       pure PL/SQL: UTL_COMPRESS cannot be used here because it only accepts a
*       gzip trailer with a correct CRC-32, and that CRC is of the DECOMPRESSED
*       data — knowing it would require decompressing first.
*   PT: Descomprime um stream /FlateDecode do PDF (zlib, RFC 1950). Implementado
*       em PL/SQL puro: o UTL_COMPRESS não serve porque só aceita rodapé gzip com
*       CRC-32 correto, e esse CRC é do conteúdo DESCOMPRIMIDO — para saber o
*       CRC seria preciso descomprimir antes.
*
* Parameters / Parâmetros:
*   p_stream - Compressed stream / Stream comprimido (BLOB)
*   p_max_bytes - Output ceiling, 8 MB by default. A compressed stream is
*                 untrusted input: a few KB can expand to gigabytes (zip bomb)
*                 and take the session down. Raises -20893 instead. /
*                 Teto da saída, 8 MB por padrão. Um stream comprimido é
*                 entrada não confiável: alguns KB podem virar gigabytes (zip
*                 bomb) e derrubar a sessão. Levanta -20893 em vez disso.
*
* Returns / Retorna:
*   BLOB - Decompressed content / Conteúdo descomprimido
*
* Raises / Erros:
*   -20890: Truncated stream / Stream truncado
*   -20891: Malformed DEFLATE data / Dados DEFLATE malformados
*   -20892: Invalid zlib header / Cabeçalho zlib inválido
*   -20893: Output exceeded p_max_bytes / Saída passou de p_max_bytes
*
* Example / Exemplo:
*   l_claro := PL_FPDF.FlateDecode(l_comprimido);
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
*******************************************************************************/
FUNCTION FlateDecode(
  p_stream    IN BLOB,
  p_max_bytes IN PLS_INTEGER DEFAULT 8388608
) RETURN BLOB;

/*******************************************************************************
* Function: FlateEncode / Comprimir stream
*
* Description:
*   EN: Compress data into a PDF /FlateDecode stream (zlib, RFC 1950). Written
*       in pure PL/SQL: a single fixed-Huffman block with greedy LZ77. It
*       compresses less than zlib's dynamic Huffman and far more than nothing,
*       and never returns more than the input plus the stored-block overhead.
*
*   PT: Comprime dados num stream /FlateDecode do PDF (zlib, RFC 1950). Escrito
*       em PL/SQL puro: um bloco unico com Huffman fixa e LZ77 guloso. Comprime
*       menos que a Huffman dinamica do zlib e muito mais que nada, e nunca
*       devolve mais que a entrada somada ao custo do bloco armazenado.
*
* Parameters:
*   p_data - Content to compress / Conteudo a comprimir (BLOB)
*
* Returns:
*   BLOB - zlib stream / Stream zlib (cabecalho, DEFLATE e Adler-32)
*
* Example / Exemplo:
*   l_comprimido := PL_FPDF.FlateEncode(l_claro);
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
*******************************************************************************/
FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB;

--------------------------------------------------------------------------------
-- PHASE 4.5: TEXT & IMAGE OVERLAY (v3.0.0-a.6)
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: OverlayText / Sobrepor Texto
*
* Description / Descrição:
*   EN: Add text overlay at specific position on PDF page with full formatting control
*   PT: Adicionar sobreposição de texto em posição específica com controle completo de formatação
*
*   EN: Rendered by OutputModifiedPDF() into the page content stream. x and y
*       are in PDF points, from the bottom-left. When width is given it defines
*       the text BOX: lines wrap inside it and align is relative to
*       [x, x+width]. Without width there is nothing to wrap, and align becomes
*       relative to the point itself — 'center' centres the text on x, 'right'
*       ends it at x.
*   PT: Desenhada por OutputModifiedPDF() no fluxo de conteúdo. x e y vão em
*       pontos PDF, a partir do canto inferior esquerdo. Quando width é
*       informado ele define a CAIXA do texto: as linhas quebram dentro dela e o
*       align é relativo a [x, x+width]. Sem width não há o que quebrar, e o
*       align passa a ser relativo ao próprio ponto — 'center' centraliza o
*       texto em x, 'right' o termina em x.
*
* Parameters / Parâmetros:
*   p_page_number - Page number (1-based) / Número da página (base 1)
*   p_text - Text content / Conteúdo do texto
*   p_x - X position in PDF points (1 point = 1/72 inch, from left) / Posição X
*   p_y - Y position in PDF points (from bottom) / Posição Y (de baixo)
*   p_options - JSON configuration (optional) / Configuração JSON (opcional)
*
* Options (JSON_OBJECT_T) / Opções:
*   {
*     "font": "Helvetica",           // Font name / Nome da fonte
*     "fontSize": 12,                // Font size in points / Tamanho da fonte
*     "color": "000000",             // RGB hex color / Cor RGB hexadecimal
*     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
*     "rotation": 0,                 // Rotation angle (0-360) / Ângulo de rotação
*     "align": "left",               // left, center, right / esquerda, centro, direita
*     "width": null,                 // Max width (auto-wrap) / Largura máxima
*     "bold": false,                 // Bold text / Texto em negrito
*     "zOrder": 100                  // Layer order (higher on top) / Ordem da camada
*   }
*
* Raises / Erros:
*   -20809: No PDF loaded / Nenhum PDF carregado
*   -20810: Invalid page number / Número de página inválido
*   -20821: Invalid position coordinates or opacity out of 0.0..1.0 /
*           Coordenadas de posição inválidas, ou opacidade fora de 0.0..1.0
*
* Example / Exemplo:
*   DECLARE
*     l_options JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     PL_FPDF.LoadPDF(l_pdf);
*
*     -- Simple text overlay / Sobreposição simples
*     PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
*
*     -- Formatted text / Texto formatado
*     l_options.put('font', 'Helvetica-Bold');
*     l_options.put('fontSize', 24);
*     l_options.put('color', 'FF0000');  -- Red / Vermelho
*     l_options.put('opacity', 0.8);
*     l_options.put('rotation', 45);
*     PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
*
*     l_modified := PL_FPDF.OutputModifiedPDF();
*   END;
*******************************************************************************/
PROCEDURE OverlayText(
  p_page_number IN PLS_INTEGER,
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

/*******************************************************************************
* Procedure: OverlayImage / Sobrepor Imagem
*
* Description / Descrição:
*   EN: Add image overlay at specific position on PDF page with sizing control
*   PT: Adicionar sobreposição de imagem em posição específica com controle de tamanho
*
*   EN: Rendered by OutputModifiedPDF() into the page content stream. Neither
*       format is decompressed: JPEG goes in whole as /DCTDecode, and a PNG's
*       IDAT blocks are already zlib, which is the PDF's /FlateDecode — they
*       are concatenated and declared with /Predictor 15. NOT supported, and
*       refused with -20823 rather than drawn wrong: PNG with an alpha channel
*       (color types 4 and 6), interlaced PNG (Adam7) and 16-bit depth.
*   PT: Desenhada por OutputModifiedPDF() no fluxo de conteúdo. Nenhum dos dois
*       formatos é descomprimido: o JPEG entra inteiro como /DCTDecode, e os
*       blocos IDAT do PNG já são zlib, que é o /FlateDecode do PDF — são
*       concatenados e declarados com /Predictor 15. NÃO suportados, e
*       recusados com -20823 em vez de desenhados errado: PNG com canal alfa
*       (color types 4 e 6), PNG entrelaçado (Adam7) e profundidade de 16 bits.
*
* Parameters / Parâmetros:
*   p_page_number - Page number (1-based) / Número da página (base 1)
*   p_image_blob - Image data (JPEG or PNG) / Dados da imagem (JPEG ou PNG)
*   p_x - X position in PDF points / Posição X em pontos PDF
*   p_y - Y position in PDF points (from bottom) / Posição Y (de baixo)
*   p_width - Image width in points (NULL = original) / Largura em pontos
*   p_height - Image height in points (NULL = original) / Altura em pontos
*   p_options - JSON configuration (optional) / Configuração JSON (opcional)
*
* Options (JSON_OBJECT_T) / Opções:
*   {
*     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
*     "rotation": 0,                 // Rotation angle / Ângulo de rotação
*     "maintainAspect": true,        // Keep aspect ratio / Manter proporção
*     "scaleToFit": false,           // Scale to fit in width/height / Escalar para caber
*     "zOrder": 100                  // Layer order / Ordem da camada
*   }
*
* Raises / Erros:
*   -20809: No PDF loaded / Nenhum PDF carregado
*   -20810: Invalid page number / Número de página inválido
*   -20821: Invalid position coordinates / Coordenadas de posição inválidas
*   -20823: Invalid image format (must be JPEG or PNG) / Formato de imagem inválido
*   -20824: Image dimensions invalid / Dimensões da imagem inválidas
*
* Example / Exemplo:
*   DECLARE
*     l_logo BLOB;
*     l_options JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
*     PL_FPDF.LoadPDF(l_pdf);
*
*     -- Add logo at top-right / Adicionar logo no canto superior direito
*     PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
*
*     -- Watermark image with transparency / Marca d'água com transparência
*     l_options.put('opacity', 0.3);
*     l_options.put('rotation', 45);
*     PL_FPDF.OverlayImage(1, l_watermark, 200, 400, 300, NULL, l_options);
*
*     l_modified := PL_FPDF.OutputModifiedPDF();
*   END;
*******************************************************************************/
PROCEDURE OverlayImage(
  p_page_number IN PLS_INTEGER,
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER DEFAULT NULL,
  p_height IN NUMBER DEFAULT NULL,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

/*******************************************************************************
* Function: GetOverlays / Obter Sobreposições
*
* Description / Descrição:
*   EN: Get list of all applied overlays as JSON array for specific page or all pages
*   PT: Obter lista de todas as sobreposições aplicadas como array JSON
*
* Parameters / Parâmetros:
*   p_page_number - Filter by page (NULL = all pages) / Filtrar por página
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array of overlay objects / Array de objetos de sobreposição
*     [{
*       "overlayId": "OVL_001",
*       "overlayType": "TEXT" | "IMAGE",
*       "pageNumber": 1,
*       "x": 100, "y": 700,
*       "content": "APPROVED",     // For text overlays
*       "opacity": 0.8,
*       "rotation": 45,
*       "zOrder": 100
*     }, ...]
*
* Raises / Erros:
*   -20809: No PDF loaded / Nenhum PDF carregado
*
* Example / Exemplo:
*   DECLARE
*     l_overlays JSON_ARRAY_T;
*     l_overlay JSON_OBJECT_T;
*   BEGIN
*     l_overlays := PL_FPDF.GetOverlays(1);  -- Page 1 overlays
*     FOR i IN 0..l_overlays.get_size() - 1 LOOP
*       l_overlay := TREAT(l_overlays.get(i) AS JSON_OBJECT_T);
*       DBMS_OUTPUT.PUT_LINE('Type: ' || l_overlay.get_string('overlayType'));
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T;

/*******************************************************************************
* Procedure: RemoveOverlay / Remover Sobreposição
*
* Description / Descrição:
*   EN: Remove specific overlay by ID
*   PT: Remover sobreposição específica por ID
*
* Parameters / Parâmetros:
*   p_overlay_id - Overlay ID from GetOverlays() / ID da sobreposição
*
* Raises / Erros:
*   -20825: Overlay not found / Sobreposição não encontrada
*
* Example / Exemplo:
*   PL_FPDF.RemoveOverlay('OVL_001');
*******************************************************************************/
PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2);

/*******************************************************************************
* Procedure: ClearOverlays / Limpar Sobreposições
*
* Description / Descrição:
*   EN: Clear all overlays from all pages or specific page
*   PT: Limpar todas as sobreposições de todas ou de página específica
*
* Parameters / Parâmetros:
*   p_page_number - Clear from page (NULL = all pages) / Limpar de página
*
* Example / Exemplo:
*   -- Clear all overlays / Limpar todas as sobreposições
*   PL_FPDF.ClearOverlays();
*
*   -- Clear overlays from page 1 only / Limpar apenas da página 1
*   PL_FPDF.ClearOverlays(1);
*******************************************************************************/
PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL);

--------------------------------------------------------------------------------
-- PHASE 4.6: PDF MERGE & SPLIT (v3.0.0-a.7)
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: LoadPDFWithID / Carregar PDF com Identificador
*
* Description / Descrição:
*   EN: Load PDF into memory with unique identifier for multi-document operations
*   PT: Carregar PDF em memória com identificador único para operações multi-documento
*
* Parameters / Parâmetros:
*   p_pdf_id - Unique identifier (max 50 chars) / Identificador único
*   p_pdf_blob - PDF document as BLOB / Documento PDF como BLOB
*
* Notes / Notas:
*   EN: Maximum 10 PDFs can be loaded simultaneously
*   PT: Máximo de 10 PDFs podem ser carregados simultaneamente
*
* Raises / Erros:
*   -20828: PDF ID already loaded / ID do PDF já carregado
*   -20829: Maximum PDFs exceeded (10 max) / Máximo de PDFs excedido
*   -20830: Invalid PDF ID (empty or too long) / ID de PDF inválido
*
* Example / Exemplo:
*   BEGIN
*     PL_FPDF.LoadPDFWithID('report_jan', l_jan_pdf);
*     PL_FPDF.LoadPDFWithID('report_feb', l_feb_pdf);
*     PL_FPDF.LoadPDFWithID('report_mar', l_mar_pdf);
*   END;
*******************************************************************************/
PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
);

/*******************************************************************************
* Function: GetLoadedPDFs / Obter PDFs Carregados
*
* Description / Descrição:
*   EN: Get list of all loaded PDF IDs and their metadata as JSON array
*   PT: Obter lista de todos os IDs de PDF carregados e seus metadados
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array of PDF objects / Array de objetos PDF
*     [{
*       "pdfId": "report_jan",
*       "pageCount": 5,
*       "fileSize": 125678,
*       "loadedDate": "2026-01-25T10:30:00"
*     }, ...]
*
* Example / Exemplo:
*   DECLARE
*     l_pdfs JSON_ARRAY_T;
*     l_pdf JSON_OBJECT_T;
*   BEGIN
*     l_pdfs := PL_FPDF.GetLoadedPDFs();
*     FOR i IN 0..l_pdfs.get_size() - 1 LOOP
*       l_pdf := TREAT(l_pdfs.get(i) AS JSON_OBJECT_T);
*       DBMS_OUTPUT.PUT_LINE('PDF: ' || l_pdf.get_string('pdfId'));
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T;

/*******************************************************************************
* Procedure: UnloadPDF / Descarregar PDF
*
* Description / Descrição:
*   EN: Remove specific PDF from memory to free resources
*   PT: Remover PDF específico da memória para liberar recursos
*
* Parameters / Parâmetros:
*   p_pdf_id - PDF identifier to unload / Identificador do PDF
*
* Raises / Erros:
*   -20831: PDF ID not found / ID do PDF não encontrado
*
* Example / Exemplo:
*   PL_FPDF.UnloadPDF('report_jan');
*******************************************************************************/
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);

/*******************************************************************************
* Function: MergePDFs / Mesclar PDFs
*
* Description / Descrição:
*   EN: Merge multiple loaded PDFs into a single document, in the given order.
*       Every object of every source is copied (pages, fonts, images,
*       annotations) with its indirect references renumbered, and a new page
*       tree is built. Nothing is re-rendered: the original content arrives
*       intact. The same ID may appear more than once.
*   PT: Mesclar múltiplos PDFs carregados em um único documento, na ordem dada.
*       Todos os objetos de cada origem são copiados (páginas, fontes, imagens,
*       anotações) com as referências indiretas renumeradas, e uma nova árvore
*       de páginas é montada. Nada é re-renderizado: o conteúdo original chega
*       intacto. O mesmo ID pode aparecer mais de uma vez.
*
* Parameters / Parâmetros:
*   p_pdf_ids - JSON array of PDF IDs to merge / Array JSON de IDs de PDF
*               Example: JSON_ARRAY_T('["pdf1","pdf2","pdf3"]')
*   p_options - Optional configuration / Configuração opcional (future use)
*
* Returns / Retorna:
*   BLOB - Merged PDF document / Documento PDF mesclado
*
* Raises / Erros:
*   -20832: No PDF IDs provided / Nenhum ID de PDF fornecido
*   -20833: PDF ID in list not loaded / ID de PDF na lista não carregado
*   -20834: Merge failed / Mesclagem falhou
*   -20841: Object dictionary too large to renumber /
*           Dicionário de objeto grande demais para renumerar
*   -20843: Malformed cross-reference stream / xref em stream malformada
*   -20847: Malformed object stream / object stream malformado
*   -20848: Unsupported predictor in the xref stream /
*           predictor não suportado na xref em stream
*
* Example / Exemplo:
*   DECLARE
*     l_merged BLOB;
*   BEGIN
*     PL_FPDF.LoadPDFWithID('jan', l_jan_pdf);
*     PL_FPDF.LoadPDFWithID('feb', l_feb_pdf);
*     PL_FPDF.LoadPDFWithID('mar', l_mar_pdf);
*
*     l_merged := PL_FPDF.MergePDFs(
*       JSON_ARRAY_T('["jan","feb","mar"]'),
*       NULL
*     );
*
*     INSERT INTO reports VALUES ('Q1_2026', l_merged);
*   END;
*******************************************************************************/
FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

/*******************************************************************************
* Function: SplitPDF / Dividir PDF
*
* Description / Descrição:
*   EN: Split the loaded PDF into several documents, one per page range. Each
*       part carries only the objects reachable from its own pages, so the
*       parts are much smaller than the source. Ranges must not overlap.
*   PT: Dividir o PDF carregado em vários documentos, um por intervalo. Cada
*       parte leva apenas os objetos alcançáveis a partir das suas páginas, e
*       por isso fica bem menor que a origem. Os intervalos não podem se
*       sobrepor.
*
* Parameters / Parâmetros:
*   p_pdf_id - PDF identifier to split / Identificador do PDF
*   p_page_ranges - JSON array of page range strings / Array de intervalos
*                   Examples: '1-5', '6-10', '11', '1,3,5', 'ALL'
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array with base64 encoded PDFs, one per range, without line
*                  breaks / Array com PDFs em base64, um por intervalo, sem
*                  quebras de linha
*
* Raises / Erros:
*   -20831: PDF ID not found / ID do PDF não encontrado
*   -20835: No page ranges provided / Nenhum intervalo fornecido
*   -20836: Overlapping page ranges / Intervalos sobrepostos
*   -20838: Invalid page specification / Especificação de páginas inválida
*   -20839: Page number out of range / Número de página fora do intervalo
*   -20843: Malformed cross-reference stream / xref em stream malformada
*   -20847: Malformed object stream / object stream malformado
*   -20848: Unsupported predictor in the xref stream /
*           predictor não suportado na xref em stream
*
* Example / Exemplo:
*   DECLARE
*     l_split_pdfs JSON_ARRAY_T;
*     l_part CLOB;
*   BEGIN
*     PL_FPDF.LoadPDFWithID('contract', l_contract_pdf);
*
*     l_split_pdfs := PL_FPDF.SplitPDF('contract',
*       JSON_ARRAY_T('["1-5", "6-10", "11-15"]')
*     );
*
*     FOR i IN 0..l_split_pdfs.get_size() - 1 LOOP
*       l_part := l_split_pdfs.get_string(i);
*       -- Process each part / Processar cada parte
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T;

/*******************************************************************************
* Function: ExtractPages / Extrair Páginas
*
* Description / Descrição:
*   EN: Extract the given pages from a loaded PDF into a new document. The
*       requested order is kept ('5,1' returns page 5 then page 1) and a page
*       may repeat. Only the objects reachable from the selected pages are
*       copied, so the result is smaller than the source.
*   PT: Extrair as páginas indicadas de um PDF carregado para um novo
*       documento. A ordem pedida é respeitada ('5,1' devolve a página 5 e
*       depois a 1) e uma página pode repetir. Só os objetos alcançáveis a
*       partir das páginas escolhidas são copiados, então o resultado fica
*       menor que a origem.
*
* Parameters / Parâmetros:
*   p_pdf_id - PDF identifier / Identificador do PDF
*   p_pages - Page specification: '1', '1,3,5-7,10', '5,1' or 'ALL' /
*             Especificação: '1', '1,3,5-7,10', '5,1' ou 'ALL'
*   p_options - Optional configuration / Configuração opcional (future use)
*
* Returns / Retorna:
*   BLOB - New PDF with extracted pages / Novo PDF com páginas extraídas
*
* Raises / Erros:
*   -20831: PDF ID not found / ID do PDF não encontrado
*   -20838: Invalid page specification / Especificação de páginas inválida
*   -20839: Page number out of range / Número de página fora do intervalo
*   -20841: Object dictionary too large to renumber /
*           Dicionário de objeto grande demais para renumerar
*   -20843: Malformed cross-reference stream / xref em stream malformada
*   -20847: Malformed object stream / object stream malformado
*   -20848: Unsupported predictor in the xref stream /
*           predictor não suportado na xref em stream
*
* Example / Exemplo:
*   DECLARE
*     l_extracted BLOB;
*   BEGIN
*     PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
*
*     -- Extract pages 1, 5-10, and 15 / Extrair páginas 1, 5-10 e 15
*     l_extracted := PL_FPDF.ExtractPages('manual', '1,5-10,15', NULL);
*
*     INSERT INTO documents VALUES ('Summary', l_extracted);
*   END;
*******************************************************************************/
FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

--------------------------------------------------------------------------------
-- Phase 5: Security / Segurança (v3.3.0)
--------------------------------------------------------------------------------

/*******************************************************************************
* Function: EncryptPDF / Criptografar PDF
*
* Description / Descrição:
*   EN: Encrypt PDF with password protection following PDF specification
*   PT: Criptografar PDF com proteção por senha seguindo especificação PDF
*
* Parameters / Parâmetros:
*   p_pdf - PDF blob to encrypt / PDF blob para criptografar
*   p_user_password - Password to open document / Senha para abrir documento
*   p_owner_password - Password for full access (optional) / Senha acesso total
*   p_permissions - JSON with permission flags / JSON com flags de permissão
*   p_encryption - Encryption method: 'RC4-40','RC4-128','AES-128','AES-256'
*
* Returns / Retorna:
*   BLOB - Encrypted PDF / PDF criptografado
*
* Raises / Erros:
*   -20850: Invalid encryption method / Método de criptografia inválido
*   -20851: Password required / Senha obrigatória
*   -20852: Encryption failed / Falha na criptografia
*
* Note / Nota:
*   EN: A PDF 1.5+ source (cross-reference stream, object streams) is
*       flattened: objects living inside object streams become top-level
*       objects and the output carries a classic cross-reference table.
*   PT: Origem em PDF 1.5+ (xref em stream, object streams) é achatada: os
*       objetos de dentro dos object streams viram objetos de primeiro nível
*       e a saída leva xref clássica.
*
* Example / Exemplo:
*   l_encrypted := PL_FPDF.EncryptPDF(
*     p_pdf => l_pdf,
*     p_user_password => 'user123',
*     p_owner_password => 'owner456',
*     p_permissions => JSON_OBJECT_T('{"print":true,"copy":false}'),
*     p_encryption => 'AES-128'
*   );
*******************************************************************************/
FUNCTION EncryptPDF(
  p_pdf IN BLOB,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL,
  p_permissions IN JSON_OBJECT_T DEFAULT NULL,
  p_encryption IN VARCHAR2 DEFAULT 'RC4-128'
) RETURN BLOB;

/*******************************************************************************
* Function: DecryptPDF / Descriptografar PDF
*
* Description / Descrição:
*   EN: Remove encryption from PDF using password
*   PT: Remover criptografia do PDF usando senha
*
* Parameters / Parâmetros:
*   p_pdf - Encrypted PDF blob / PDF blob criptografado
*   p_password - User or owner password / Senha de usuário ou owner
*
* Returns / Retorna:
*   BLOB - Decrypted PDF / PDF descriptografado
*
* Raises / Erros:
*   -20853: PDF is not encrypted / PDF não está criptografado
*   -20854: Invalid password / Senha inválida
*   -20855: Decryption failed / Falha na descriptografia
*
* Note / Nota:
*   EN: A PDF 1.5+ source is flattened, and the object streams are decrypted
*       before being decompressed.
*   PT: Origem em PDF 1.5+ é achatada, e os object streams são decifrados
*       antes de descomprimidos.
*
* Example / Exemplo:
*   l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
*******************************************************************************/
FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB;

/*******************************************************************************
* Function: IsEncrypted / Verificar Criptografia
*
* Description / Descrição:
*   EN: Check if PDF is encrypted
*   PT: Verificar se PDF está criptografado
*
* Parameters / Parâmetros:
*   p_pdf - PDF blob to check / PDF blob para verificar
*
* Returns / Retorna:
*   BOOLEAN - TRUE if encrypted / TRUE se criptografado
*
* Example / Exemplo:
*   IF PL_FPDF.IsEncrypted(l_pdf) THEN ...
*******************************************************************************/
FUNCTION IsEncrypted(p_pdf IN BLOB) RETURN BOOLEAN;

/*******************************************************************************
* Function: GetSecurityInfo / Obter Info Segurança
*
* Description / Descrição:
*   EN: Get security information from PDF
*   PT: Obter informações de segurança do PDF
*
* Parameters / Parâmetros:
*   p_pdf - PDF blob / PDF blob
*
* Returns / Retorna:
*   JSON_OBJECT_T - Security info including:
*     - encrypted: boolean
*     - method: string (RC4-40, RC4-128, AES-128, AES-256)
*     - permissions: object with print, copy, modify, etc.
*     - hasUserPassword: boolean
*     - hasOwnerPassword: boolean
*
* Example / Exemplo:
*   l_info := PL_FPDF.GetSecurityInfo(l_pdf);
*   IF l_info.get_boolean('encrypted') THEN ...
*******************************************************************************/
FUNCTION GetSecurityInfo(p_pdf IN BLOB) RETURN JSON_OBJECT_T;

/*******************************************************************************
* Procedure: SetEncryption / Definir Criptografia
*
* Description / Descrição:
*   EN: Set encryption for PDF being generated (use before Output)
*   PT: Definir criptografia para PDF em geração (usar antes do Output)
*
* Parameters / Parâmetros:
*   p_encryption - Method: 'RC4-40','RC4-128','AES-128','AES-256'
*   p_user_password - Password to open / Senha para abrir
*   p_owner_password - Password for full access / Senha acesso total
*
* Example / Exemplo:
*   PL_FPDF.fpdf();
*   PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
*   PL_FPDF.AddPage();
*   l_pdf := PL_FPDF.Output();
*
* PDF Version Mapping / Mapeamento de Versão:
*   RC4-40/RC4-128 -> PDF 1.4
*   AES-128 -> PDF 1.5
*   AES-256 -> PDF 1.7
*******************************************************************************/
PROCEDURE SetEncryption(
  p_encryption IN VARCHAR2,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL
);

/*******************************************************************************
* Procedure: SetPDFVersion / Definir Versão PDF
*
* Description / Descrição:
*   EN: Set the PDF version for generated documents
*   PT: Definir a versão do PDF para documentos gerados
*
* Parameters / Parâmetros:
*   p_version - PDF version: '1.4', '1.5', '1.6', '1.7', '2.0'
*
* Version Features / Recursos por Versão:
*   1.4: RC4 128-bit encryption, transparency
*   1.5: AES 128-bit, object streams, cross-reference streams
*   1.6: AES 128-bit, OpenType fonts
*   1.7: AES 256-bit, XFA forms
*   2.0: AES 256-bit only, no RC4
*
* Example / Exemplo:
*   PL_FPDF.SetPDFVersion('1.5');
*******************************************************************************/
PROCEDURE SetPDFVersion(p_version IN VARCHAR2);

/*******************************************************************************
* Function: GetPDFVersion / Obter Versão PDF
*
* Description / Descrição:
*   EN: Get the current PDF version setting
*   PT: Obter a configuração atual de versão do PDF
*
* Returns / Retorna:
*   VARCHAR2 - Current PDF version (e.g., '1.4')
*******************************************************************************/
FUNCTION GetPDFVersion RETURN VARCHAR2;

/*******************************************************************************
* Procedure: SetPermissions / Definir Permissões
*
* Description / Descrição:
*   EN: Set document permissions (requires SetEncryption first)
*   PT: Definir permissões do documento (requer SetEncryption antes)
*
* Parameters / Parâmetros:
*   p_print - Allow printing / Permitir impressão
*   p_modify - Allow modification / Permitir modificação
*   p_copy - Allow copy/extract / Permitir cópia/extração
*   p_annotate - Allow annotations / Permitir anotações
*   p_fill_forms - Allow form filling / Permitir preenchimento de formulários
*   p_extract - Allow content extraction / Permitir extração de conteúdo
*   p_assemble - Allow document assembly / Permitir montagem de documento
*   p_print_high - Allow high quality print / Permitir impressão alta qualidade
*
* Example / Exemplo:
*   PL_FPDF.SetEncryption('AES-128', 'user', 'owner');
*   PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE, p_modify => FALSE);
*******************************************************************************/
PROCEDURE SetPermissions(
  p_print IN BOOLEAN DEFAULT TRUE,
  p_modify IN BOOLEAN DEFAULT FALSE,
  p_copy IN BOOLEAN DEFAULT FALSE,
  p_annotate IN BOOLEAN DEFAULT TRUE,
  p_fill_forms IN BOOLEAN DEFAULT TRUE,
  p_extract IN BOOLEAN DEFAULT FALSE,
  p_assemble IN BOOLEAN DEFAULT FALSE,
  p_print_high IN BOOLEAN DEFAULT TRUE
);

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

END PL_FPDF;
/

--------------------------------------------------------------------------------
-- PACKAGE BODY PL_FPDF
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS
/*******************************************************************************
*                                                                              *
*                            PL_FPDF v3.3.0                                    *
*                Oracle PL/SQL PDF Generation and Manipulation                 *
*                           Package Body / Corpo do Pacote                     *
*                                                                              *
********************************************************************************
*                                                                              *
* Version / Versão: 3.2.0                                                      *
* Release Date / Data: February 2026 / Fevereiro 2026                          *
* License / Licença: MIT                                                       *
*                                                                              *
********************************************************************************
*                                                                              *
* CREDITS / CRÉDITOS:                                                          *
*                                                                              *
* Original FPDF (PHP): Olivier PLATHEY (http://www.fpdf.org/)                  *
* PL/SQL Port: Pierre-Gilles Levallois, Anton Scheffer, Marcel Amman           *
* Modernization & Phase 4: Maxwell Oliveira (@maxwbh)                          *
*                                                                              *
********************************************************************************
*                                                                              *
* CHANGELOG:                                                                   *
*                                                                              *
* v3.0.0 (2026-02):                                                            *
*   - Phase 4: PDF manipulation (load, parse, modify, merge, split)            *
*   - Removed APEX dependencies (pure PL/SQL)                                  *
*   - Removed ORDSYS.ORDIMAGE dependencies                                     *
*   - PDF version updated to 1.4                                               *
*   - Improved Oracle compatibility (INSTR/SUBSTR instead of REGEXP)           *
*                                                                              *
* v2.0.0 (2025-12):                                                            *
*   - Phase 1-3: PDF generation with images, fonts, barcodes                   *
*   - Native BLOB image support                                                *
*   - CLOB-based document buffer                                               *
*                                                                              *
* v0.9.4 (2017-12): Original release by Pierre-Gilles Levallois                *
*                                                                              *
*******************************************************************************/

-- Privates types 
subtype flag is boolean;
subtype car is varchar2(1);
subtype phrase is varchar2(255);
--@youcef
subtype txt is varchar2(32767); -- valor antigo: 2000, causava ORA-20100
subtype bigtext is varchar2(32767);
subtype margin is number;

-- type tv1 is table of varchar2(1) index by pls_integer;
type tbool is table of boolean index by pls_integer;
type tn is table of number index by pls_integer;
type tv4000 is table of varchar2(4000) index by pls_integer;
type tv32k is table of varchar2(32767) index by pls_integer;
type tclob is table of clob index by pls_integer;
type tblob is table of blob index by pls_integer;
type tpi is table of pls_integer index by pls_integer;
type tpi2 is table of tpi index by pls_integer;

-- Limite da porcao ASCII de um objeto PDF na copia entre documentos
-- (o payload do stream nao entra na conta). Ver "Copiador de objetos PDF".
co_pdf_dict_limit constant pls_integer := 32000;
-- Teto do caminho que REPROCESSA pixels (PNG com alfa ou entrelacado). Esse
-- caminho e O(pixels) em PL/SQL: separar o alfa e remontar as sete passagens do
-- Adam7 sao lacos por pixel, sem vetorizacao. Uma imagem de 4 megapixels ja
-- leva dezenas de segundos; acima disso a sessao trava e ninguem entende por
-- que. Recusar com mensagem clara custa menos.
co_img_max_px constant pls_integer := 4000000;
--------------------------------------------------------------------------------
-- Codificador QR Code (ISO/IEC 18004) — modo byte, versoes 1..20, niveis L/M/Q/H
--
-- Implementacao portada de uma referencia validada contra o decodificador
-- zxing-cpp: 25 de 25 simbolos gerados foram lidos corretamente, cobrindo
-- v1..v11, os quatro niveis de correcao, acentuacao UTF-8 e payload PIX.
--
-- Substitui o desenho decorativo anterior, que preenchia a area de dados com um
-- padrao derivado de dbms_utility.get_hash_value e nao codificava o conteudo.
--------------------------------------------------------------------------------















--------------------------------------------------------------------------------
-- Criptografia do PDF (revisao 2/3): MD5 e RC4, ambos implementados aqui.
--
-- MD5 vem de STANDARD_HASH (funcao SQL nativa, sem GRANT) e RC4 esta em
-- PL_FPDF_UTIL.crypto_rc4. Nao ha dependencia de DBMS_CRYPTO: antes era preciso EXECUTE em
-- SYS.DBMS_CRYPTO, e quem nao tinha acabava criando um substituto no proprio
-- schema — um substituto que nao cifre de verdade faz o PDF sair marcado como
-- protegido com /O em texto claro e qualquer senha ser aceita, em silencio.
--------------------------------------------------------------------------------


-- Conversao numerica do PDF: sempre ponto decimal, independente da sessao.
-- Usada por tochar/tonumber. A biblioteca nao altera NLS da sessao do chamador.
co_nls_num constant varchar2(40) := 'NLS_NUMERIC_CHARACTERS=''.,''';

/*******************************************************************************
* Modelo de buffers de escrita
*
* Toda saida passa por p_out, que grava em um de dois destinos conforme o estado:
*
*   state = 2  -> conteudo de pagina  : acumulador g_page_buf  -> pages(n) CLOB
*   state <> 2 -> estrutura do arquivo: acumulador g_doc_buf   -> pdfDoc    CLOB
*
* Em ambos os casos as instrucoes sao concatenadas num VARCHAR2 e so descarregadas
* no CLOB quando o acumulador enche (co_page_buf_limit, avaliado em BYTES para ser
* seguro em UTF-8). Isso evita:
*   - o teto de 32 KB por pagina que existia quando a pagina era um VARCHAR2;
*   - a recopia O(n^2) da pagina a cada instrucao emitida;
*   - uma chamada DBMS_LOB por instrucao (agora uma a cada ~32 KB).
*
* Regra de ouro: quem LE um dos CLOBs precisa descarregar o acumulador antes.
*   - p_flush_doc_buf  : antes de medir/ler pdfDoc. getPDFDocLength faz isso, e os
*                        offsets da tabela xref dependem dessa medida estar correta.
*   - p_flush_page_buf : antes de ler pages(n) e ao trocar de pagina.
* Os CLOBs de pagina sao temporarios e liberados por p_free_pages (Reset e nas
* duas rotas de inicializacao), evitando vazamento de LOB entre documentos.
*******************************************************************************/

type charSet is table of pls_integer index by car;

type recFont is record ( i    word, 
	 		 		   	 n pls_integer, 
	 		 		   	 type word,
						 name word,
						 dsc  tv4000,
						 up   word,
						 ut   word,
						 cw   charSet,
						 enc  word,
						 file word,
						 diff word,
						 length1 word,
						 length2 word);

type fontsArray is table of recFont index by phrase;

type recImage is record ( n number,  	 	  	 		-- indice d'insertion dans le document
	 		  	 		  i number,  	 	 			-- ?
	 		  	 		  w number,  		 			-- width
	 		  	 		  h number,  		 			-- height
						  cs txt,				    -- colorspace
						  bpc txt,				 	-- Bit per color
	 		  	 		  f txt,  	 			 	-- File Format
						  parms txt,			 	-- pdf parameter for this image
						  pal txt,				 	-- colors palette informations 
						  trns tn,			 	 	-- transparency 
						  data blob	 			 	-- Data
 );

type imagesArray is table of recImage index by txt;

type recFormat is record ( largeur number, 
	 		 		       hauteur number);
						 
type rec2chp is record ( zero txt, 
	 		 		   	 un txt); 

type rec5 is record ( zero txt, 
	 		 		  un txt,
					  deux txt,
					  trois txt,
					  quatre txt);
					  
type LinksArray is table of rec5;

type Array2dim is table of rec2chp;

type ArrayCharWidths is table of charSet index by word;

-- Private properties 
 page number;               -- current page number
 n number;                  -- current object number
 offsets tv4000;            -- array of object offsets
 -- Buffer do documento final: CLOB temporario, sem limite de tamanho
 pdfDoc CLOB;               -- buffer holding in-memory final PDF document (CLOB) 									   
 imgBlob blob;              -- allows creation of persistent blobs for images
 pages tclob;               -- conteudo de cada pagina (CLOB temporario, sem limite de 32k)
 -- Acumulador de escrita: p_out concatena aqui e so descarrega no CLOB quando enche.
 -- Evita uma chamada LOB por instrucao e a recopia O(n^2) da pagina inteira.
 g_page_buf varchar2(32767);
 g_doc_buf varchar2(32767);            -- mesmo acumulador para o buffer do documento
 g_page_buf_page pls_integer;          -- pagina a que o acumulador pertence
 co_page_buf_limit constant pls_integer := 32000;
 state word;                -- current document state
 b_compress flag := false;  -- compression flag 
 DefOrientation car;        -- default orientation
 CurOrientation car;        -- current orientation
 OrientationChanges tbool;    -- array indicating orientation changes
 k number;                  -- scale factor (number of points in user unit)
 fwPt number;
 fhPt number;         		-- dimensions of page format in points
 fw number;
 fh number;             	-- dimensions of page format in user unit
 wPt number;
 hPt number;           		-- current dimensions of page in points
 w number;
 h number;               	-- current dimensions of page in user unit
 lMargin margin;            -- left margin
 tMargin margin;            -- top margin
 rMargin margin;            -- right margin
 bMargin margin;            -- page break margin
 cMargin margin;            -- cell margin
 x number;
 y number;               	-- current position in user unit for cell positioning
 lasth number;              -- height of last cell printed 
 LineWidth number;          -- line width in user unit
 CoreFonts tv4000a;          	-- array of standard font names
 fonts fontsArray;            -- array of used fonts
 FontFiles fontsArray;          	-- array of font files
 diffs tv4000;              	-- array of encoding differences 
 images imagesArray;             	-- array of used images
 PageLinks LinksArray;          -- array of links in pages
 links Array2dim;              -- array of internal links
 FontFamily word;         	-- current font family
 FontStyle word;          	-- current font style
 underline flag;          	-- underlining flag
 CurrentFont recFont;        -- current font info
 FontSizePt number;         -- current font size in points
 FontSize number;           -- current font size in user unit
 DrawColor phrase;          -- commands for drawing color
 FillColor phrase;          -- commands for filling color
 TextColor phrase;          -- commands for txt color
 ColorFlag flag;          	-- indicates whether fill and txt colors are different
 ws word;                 	-- word spacing 
 AutoPageBreak flag;      	-- automatic page breaking
 PageBreakTrigger number;   -- threshold used to trigger page breaks
 InFooter flag;           	-- flag set when processing footer
 ZoomMode word;           	-- zoom display mode
 LayoutMode word;         	-- layout display mode
 title txt;              	-- title
 subject txt;            	-- subject
 author txt;             	-- author
 keywords txt;           	-- keywords
 creator txt;            	-- creator
 AliasNbPages word;       	-- alias for total number of pages
 PDFVersion word;         	-- PDF version number
 
 -- Proprietés ajoutées lors du portage en PLSQL.
 fpdf_charwidths ArrayCharWidths;		-- Characters table.
 MyHeader_Proc txt;						-- Personal Header procedure.
 MyHeader_ProcParam tv4000a;            -- Table of parameters of the personal header Proc.
 MyHeader_Stmt txt;                     -- bloco PL/SQL do header, montado uma vez
 MyFooter_Stmt txt;                     -- bloco PL/SQL do footer, montado uma vez
 MyFooter_Proc txt;						-- Personal Footer procedure.
 MyFooter_ProcParam tv4000a;            -- Table of parameters of the personal footer Proc.
 formatArray recFormat;					-- Dimension of the format (variable : format).
 gb_mode_debug boolean := false;
 Linespacing number;
 
 -- variables dont je ne maitrise pas bien l'emploi.
 -- A vérifier au court de la validation du portage.
 originalsize word;
 size1 word;
 size2 word;

--------------------------------------------------------------------------------
-- Date: 2025-12-15
--------------------------------------------------------------------------------
 g_initialized boolean := false;       -- Initialization state flag
 g_encoding varchar2(20) := 'UTF-8';   -- Character encoding
 g_log_level pls_integer := 2;         -- Log level (0=OFF, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG)
 -- Buffers de escrita: documento e paginas usam CLOB temporario, alimentados
 -- pelos acumuladores g_doc_buf / g_page_buf (ver "Modelo de buffers" abaixo).
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-15
--------------------------------------------------------------------------------
 type tPageFormats is table of recPageFormat index by varchar2(20);

 g_pages tPages;                           -- Modern page collection with CLOB content
 g_current_page pls_integer := 0;          -- Current page number
 g_page_formats tPageFormats;              -- Standard page format definitions
 g_default_format recPageFormat;           -- Default page format
 g_default_orientation varchar2(1) := 'P'; -- Default page orientation ('P' or 'L')
 g_formats_initialized boolean := false;  -- Flag indicating if page formats are initialized
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-15
--------------------------------------------------------------------------------
 g_ttf_fonts tTTFFonts;                     -- TrueType font cache
 g_ttf_fonts_count pls_integer := 0;        -- Number of loaded TTF fonts
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-17
--------------------------------------------------------------------------------
 g_utf8_enabled boolean := true;            -- UTF-8 encoding enabled by default
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-01-25
--------------------------------------------------------------------------------
 -- PDF Specification Constants
 c_PDF_VERSION CONSTANT VARCHAR2(10) := '1.4'; -- PDF output version

 -- Font Size Limits (in points)
 c_MIN_FONT_SIZE CONSTANT NUMBER := 1;
 c_MAX_FONT_SIZE CONSTANT NUMBER := 999;

 -- Font Name Limits
 c_MAX_FONT_NAME_LENGTH CONSTANT NUMBER := 80;

 -- Color Value Limits (RGB)
 c_MIN_COLOR_VALUE CONSTANT NUMBER := 0;
 c_MAX_COLOR_VALUE CONSTANT NUMBER := 255;

 -- Log Levels
 c_LOG_OFF CONSTANT PLS_INTEGER := 0;
 c_LOG_ERROR CONSTANT PLS_INTEGER := 1;
 c_LOG_WARN CONSTANT PLS_INTEGER := 2;
 c_LOG_INFO CONSTANT PLS_INTEGER := 3;
 c_LOG_DEBUG CONSTANT PLS_INTEGER := 4;

 -- Scale Factors (points per unit)
 c_SCALE_PT CONSTANT NUMBER := 1;          -- points
 c_SCALE_MM CONSTANT NUMBER := 72/25.4;    -- millimeters
 c_SCALE_CM CONSTANT NUMBER := 72/2.54;    -- centimeters
 c_SCALE_IN CONSTANT NUMBER := 72;         -- inches

 -- Image Format Signatures
 c_PNG_SIGNATURE CONSTANT RAW(8) := HEXTORAW('89504E470D0A1A0A');
 c_JPEG_SOI CONSTANT RAW(2) := HEXTORAW('FFD8');
--------------------------------------------------------------------------------

/*******************************************************************************
*                          PHASE 4: PDF PARSER                                 *
*                   Global Variables for PDF Reading/Editing                   *
*******************************************************************************/

-- PDF loaded in memory
g_loaded_pdf BLOB;

-- PDF information
g_pdf_version VARCHAR2(10);
g_xref_offset PLS_INTEGER;
g_root_obj_id PLS_INTEGER;
g_pages_obj_id PLS_INTEGER;  -- Parent Pages object ID (for inherited properties)
g_loaded_page_count PLS_INTEGER := 0;

-- xref table (object_id => xref_entry)
TYPE xref_entry_rec IS RECORD (
  offset PLS_INTEGER,
  generation PLS_INTEGER,
  in_use BOOLEAN
);
TYPE xref_table_type IS TABLE OF xref_entry_rec INDEX BY PLS_INTEGER;
g_xref_table xref_table_type;
-- Corpo dos objetos que moram dentro de um object stream (PDF 1.5+): eles nao
-- tem offset no arquivo, entao get_pdf_object nao teria onde le-los. Preenchido
-- por parse_xref_table quando a xref e um stream.
g_objstm_body tv32k;

-- Object cache
TYPE object_cache_type IS TABLE OF CLOB INDEX BY PLS_INTEGER;
g_object_cache object_cache_type;

-- Page information
TYPE page_info_rec IS RECORD (
  page_obj_id PLS_INTEGER,
  media_box VARCHAR2(100),
  crop_box VARCHAR2(100),
  rotate NUMBER,
  resources_id PLS_INTEGER,
  contents_id PLS_INTEGER
);
TYPE page_info_table IS TABLE OF page_info_rec INDEX BY PLS_INTEGER;
g_page_info_table page_info_table;

-- PDF modification tracking
g_pdf_modified BOOLEAN := FALSE;
TYPE page_removal_list IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
g_removed_pages page_removal_list;

-- Watermark tracking
TYPE watermark_rec IS RECORD (
  text VARCHAR2(200),
  opacity NUMBER,
  rotation NUMBER,
  page_range VARCHAR2(100),
  font_name VARCHAR2(50),
  font_size NUMBER,
  color VARCHAR2(20)
);
TYPE watermark_list IS TABLE OF watermark_rec INDEX BY PLS_INTEGER;
g_watermarks watermark_list;
g_watermark_count PLS_INTEGER := 0;

/*******************************************************************************
*                     PHASE 4.5: TEXT & IMAGE OVERLAY                          *
*                   Global Variables for Overlay Management                    *
*******************************************************************************/

-- Overlay tracking
TYPE overlay_rec IS RECORD (
  overlay_id VARCHAR2(50),
  overlay_type VARCHAR2(20),  -- 'TEXT' or 'IMAGE'
  page_number PLS_INTEGER,
  x NUMBER,
  y NUMBER,
  width NUMBER,
  height NUMBER,
  content CLOB,              -- Text content or image reference
  image_blob BLOB,           -- For image overlays
  opacity NUMBER,
  rotation NUMBER,
  font_name VARCHAR2(100),
  font_size NUMBER,
  color VARCHAR2(50),
  align VARCHAR2(20),
  bold BOOLEAN,              -- so para overlay de TEXTO
  z_order PLS_INTEGER,
  maintain_aspect BOOLEAN,
  scale_to_fit BOOLEAN,
  created_date TIMESTAMP
);
TYPE overlay_list IS TABLE OF overlay_rec INDEX BY VARCHAR2(50);
g_overlays overlay_list;
g_overlay_count PLS_INTEGER := 0;

/*******************************************************************************
*                     PHASE 4.6: PDF MERGE & SPLIT                             *
*                   Global Variables for Multi-Document Management             *
*******************************************************************************/

-- Multi-document tracking
TYPE pdf_document_rec IS RECORD (
  pdf_id VARCHAR2(50),
  pdf_blob BLOB,
  page_count PLS_INTEGER,
  file_size NUMBER,
  pdf_version VARCHAR2(10),
  xref_offset PLS_INTEGER,
  root_obj_id PLS_INTEGER,
  -- Cached parsed data
  pages JSON_ARRAY_T,
  objects JSON_OBJECT_T,
  xref_table JSON_OBJECT_T,
  trailer JSON_OBJECT_T,
  loaded_date TIMESTAMP
);

TYPE pdf_collection IS TABLE OF pdf_document_rec INDEX BY VARCHAR2(50);
g_loaded_pdfs pdf_collection;
g_loaded_pdf_count PLS_INTEGER := 0;

-- Maximum loaded PDFs
c_max_loaded_pdfs CONSTANT PLS_INTEGER := 10;

--------------------------------------------------------------------------------
-- Copiador de objetos em nivel de bytes / byte level object copier
--
-- PT: MergePDFs, SplitPDF, ExtractPages e OutputModifiedPDF compartilham a mesma
--     raiz: copiar objetos de um PDF de origem para um novo documento,
--     renumerando as referencias indiretas. O payload dos streams e copiado
--     byte a byte (DBMS_LOB.COPY), nunca por VARCHAR2, para nao corromper dados
--     binarios; so a porcao ASCII do dicionario e reescrita.
-- EN: MergePDFs, SplitPDF, ExtractPages and OutputModifiedPDF share one root:
--     copy objects from a source PDF into a new document, renumbering indirect
--     references. Stream payloads are copied byte for byte (DBMS_LOB.COPY),
--     never through VARCHAR2, so binary data survives; only the ASCII portion
--     of the dictionary is rewritten.
--
-- O algoritmo foi validado contra o MuPDF em scripts/pdfmerge_reference/.
--------------------------------------------------------------------------------
-- Uma origem ja indexada: xref + arvore de paginas achatada com heranca resolvida
TYPE pdf_source_rec IS RECORD (
  doc       BLOB,
  xref      xref_table_type,   -- id do objeto => offset/geracao/em uso
  -- Objetos que moram DENTRO de um object stream (PDF 1.5+): eles nao tem
  -- offset no arquivo, entao o corpo e materializado na carga e guardado aqui.
  -- A especificacao proibe que um objeto de dentro tenha stream, entao texto
  -- basta — o copiador nao precisa de um segundo caminho de bytes. O id
  -- continua aparecendo em `xref` (com offset NULL) para que todo
  -- `xref.EXISTS(...)` espalhado pelo copiador siga valendo.
  objstm    tv32k,
  -- /Root e /Info lidos do trailer de verdade. A cifragem precisava deles e os
  -- procurava com uma regex nos ultimos 4000 bytes do arquivo, o que funciona
  -- por acidente e falha numa atualizacao incremental.
  root      PLS_INTEGER,
  info      PLS_INTEGER,
  pages     tpi,               -- 1..n => id do objeto /Type /Page, em ordem
  media     tv32k,             -- heranca resolvida, indexada pelo id da pagina
  resources tv32k,
  cropbox   tv32k,
  rotate    tv32k,
  rot_force tv32k,             -- /Rotate imposto pelo chamador (RotatePage)
  -- Desenho a sobrepor, indexado pelo id do objeto da pagina. ovl_ops sao os
  -- operadores do fluxo de conteudo; ovl_res, as entradas que precisam entrar
  -- no /Resources dela (fonte, ExtGState da opacidade, XObject da imagem).
  ovl_ops   tv32k,
  ovl_res   tv32k,
  -- Imagens a sobrepor. Uma pagina pode ter varias, entao a lista e propria e
  -- ovl_img_pag diz de qual pagina cada uma e; os ids dos objetos so existem
  -- na montagem, e e la que /XObject entra no /Resources.
  ovl_img_dic tv32k,
  ovl_img_dat tblob,
  -- O /SMask de cada imagem, quando o PNG tem canal alfa: e um objeto de
  -- imagem SEPARADO, porque o PDF nao guarda a transparencia dentro do pixel.
  ovl_msk_dic tv32k,
  ovl_msk_dat tblob,
  ovl_img_pag tpi
);
TYPE pdf_source_list IS TABLE OF pdf_source_rec INDEX BY PLS_INTEGER;

/*******************************************************************************
*                          PHASE 5: SECURITY / SEGURANCA                       *
*                   Global Variables for Encryption / Criptografia             *
*                                                                              *
* PT: Estas declaracoes ficavam no meio do corpo do package, depois de dezenas  *
*     de subprogramas — o que o PL/SQL nao aceita (PLS-00103): uma vez que um   *
*     corpo de subprograma aparece na parte declarativa, nao se declaram mais   *
*     itens. Foram trazidas para junto das demais declaracoes globais.          *
* EN: These used to sit in the middle of the package body, after dozens of      *
*     subprogram bodies — which PL/SQL rejects (PLS-00103). Moved up here with  *
*     the other globals.                                                       *
*******************************************************************************/
g_encrypt_method VARCHAR2(20) := NULL;
g_user_password VARCHAR2(100) := NULL;
g_owner_password VARCHAR2(100) := NULL;
g_sec_permissions PLS_INTEGER := -1;
g_encrypt_obj_num PLS_INTEGER := NULL;  -- Object number of Encrypt dict
g_file_id RAW(16) := NULL;              -- Document ID
g_o_value RAW(32) := NULL;              -- /O value
g_u_value RAW(32) := NULL;              -- /U value
g_encryption_key RAW(16) := NULL;       -- Encryption key

-- PDF encryption padding string (32 bytes as per PDF spec)
c_PDF_PADDING CONSTANT RAW(32) := HEXTORAW(
  '28BF4E5E4E758A4164004E56FFFA0108' ||
  '2E2E00B6D0683E802F0CA9FE6453697A'
);











--------------------------------------------------------------------------------

/*******************************************************************************
*                                                                              *
*           Protected methods : Internal function and procedures               *
*                                                                              *
*******************************************************************************/
----------------------------------------------------------------------------------
-- proc. and func. spécifiques ajoutées au portage.
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- Declaracoes antecipadas
--
-- Os buffers de escrita (documento e pagina) sao descarregados por rotinas
-- definidas mais adiante, mas usadas antes: getPDFDocLength precisa descarregar
-- o acumulador do documento para medir o offset correto da xref.
----------------------------------------------------------------------------------------
procedure p_flush_doc_buf;
procedure p_flush_page_buf;
procedure p_ensure_page_clob(p_page in pls_integer);
procedure p_free_pages;

-- Callbacks de header/footer: validados e montados em SetHeaderProc/SetFooterProc,
-- que aparecem antes destas rotinas no corpo do package.
function p_assert_callback_name(p_name in varchar2) return varchar2;
function buildPlsqlStatment(callbackProc in varchar2,
                            tParam in tv4000a default noParam) return varchar2;

-- Copiador de objetos PDF: implementado junto de MergePDFs/SplitPDF/ExtractPages,
-- mas OutputModifiedPDF, que aparece antes no corpo, tambem o usa.
function pdf_src_load(p_doc in blob,
                     p_chave in raw default null,
                     p_aes in boolean default false,
                     p_r6 in boolean default false,
                     p_materializar in boolean default true)
  return pdf_source_rec;
function pdf_parse_pages(p_spec in varchar2, p_total in pls_integer) return tpi;
function pdf_assemble(p_srcs in out nocopy pdf_source_list,
                      p_sel  in out nocopy tpi2) return blob;



function compute_object_key(p_enc_key raw, p_obj_num pls_integer,
                            p_gen_num pls_integer default 0,
                            p_key_length pls_integer default 128) return raw;


-- Geradores dos operadores de marca d'agua e overlay: ficam junto do copiador,
-- porque dependem de pdf_dict_value e companhia, mas quem os chama e
-- OutputModifiedPDF, que aparece antes.
function ovl_marca_dagua(p_texto in varchar2, p_larg in number, p_alt in number,
                         p_rot in number, p_corpo in number, p_opac in number,
                         p_r in number, p_g in number, p_b in number)
  return varchar2;
function ovl_largura(p_txt in varchar2, p_corpo in number,
                     p_fonte in varchar2 default null,
                     p_bold in boolean default false) return number;
function ovl_texto(p_x in number, p_y in number, p_texto in varchar2,
                   p_corpo in number, p_rot in number, p_opac in number,
                   p_r in number, p_g in number, p_b in number,
                   p_fonte in varchar2 default null,
                   p_bold in boolean default false,
                   p_align in varchar2 default 'left',
                   p_larg in number default null) return varchar2;
function ovl_imagem(p_x in number, p_y in number, p_larg in number,
                    p_alt in number, p_nome in varchar2, p_rot in number,
                    p_opac in number) return varchar2;
function ovl_recursos_texto(p_gs in varchar2, p_fontes in varchar2)
  return varchar2;
function ovl_gs_entrada(p_opac in number) return varchar2;
function ovl_fonte_nome(p_fonte in varchar2, p_bold in boolean) return varchar2;
function ovl_fonte_entrada(p_fonte in varchar2, p_bold in boolean)
  return varchar2;
procedure ovl_img_xobject(p_img in blob, o_dic out varchar2,
                          o_dados in out nocopy blob,
                          o_larg out number, o_alt out number,
                          o_msk_dic out varchar2,
                          o_msk_dat in out nocopy blob);

----------------------------------------------------------------------------------------
procedure print (pstr in varchar2) is
begin
  -- Choose the output mode...
  htp.p(pstr);
  -- My outpout method
  -- affiche.p(pstr);
end print;

----------------------------------------------------------------------------------
-- Testing if method for additionnal fonts exists in this package
-- lv_existing_methods MUST reference all the "p_put..." procedure of the package.
----------------------------------------------------------------------------------
function methode_exists(pMethodName in varchar2) return boolean is
lv_existing_methods varchar2(200) := 'p_putstream,p_putxobjectdict,p_putresourcedict,p_putfonts,p_putimages,p_putresources,p_putinfo,p_putcatalog,p_putheader,p_puttrailer,p_putpages';
begin
   if (instr(lv_existing_methods, lower(pMethodName) ) > 0 ) then
     return true;
   end if;
   return false;
exception 
  when others then
   return false;
end methode_exists;

----------------------------------------------------------------------------------
-- Calculate the length of the final document contained in the plsql table pdfDoc.
----------------------------------------------------------------------------------
-- O comprimento alimenta os offsets da tabela xref (p_newobj): o acumulador
-- precisa estar descarregado antes de medir, ou os offsets saem errados.
function getPDFDocLength return pls_integer is
begin
  p_flush_doc_buf;
  return nvl(dbms_lob.getlength(pdfDoc), 0);
exception
  when others then
   error('getPDFDocLength : '||sqlerrm);
   return -1;
end getPDFDocLength;

----------------------------------------------------------------------------------
-- Setting metric for courier Font
----------------------------------------------------------------------------------
-- <larguras-das-fontes: gerado, nao edite>
----------------------------------------------------------------------------------------
-- Larguras das 14 fontes padrao do PDF, em milesimos de em.
--
-- GERADO por dev/scripts/font_reference/gerar.py a partir das fontes
-- primarias: os AFM da Adobe, as tabelas do reportlab (que se conferem entre
-- si, glifo a glifo) e a WinAnsiEncoding. NAO EDITE A MAO: rode o gerador.
--
-- Cada familia e uma sequencia de 256 campos de 4 digitos, um por posicao da
-- codificacao. A chave da tabela indexada e chr(i).
----------------------------------------------------------------------------------------
function p_larguras_de(p_tabela in varchar2) return charSet is
  mySet charSet;
begin
  for i in 0..255 loop
    mySet(chr(i)) := to_number(substr(p_tabela, i * 4 + 1, 4));
  end loop;
  return mySet;
end p_larguras_de;

function p_digitos_da_familia(p_familia in varchar2) return varchar2 is
begin
  case p_familia
    when 'Courier' then return
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '0600060006000600060006000600060006000600060006000600060006000600060006000600' ||
      '060006000600060006000600060006000600';
    when 'Helvetica' then return
      '0278027802780278027802780278027802780278027802780278027802780278027802780278' ||
      '0278027802780278027802780278027802780278027802780278027802780355055605560889' ||
      '0667019103330333038905840278033302780278055605560556055605560556055605560556' ||
      '0556027802780584058405840556101506670667072207220667061107780722027805000667' ||
      '0556083307220778066707780722066706110722066709440667066706110278027802780469' ||
      '0556033305560556050005560556027805560556022202220500022208330556055605560556' ||
      '0333050002780556050007220500050005000334026003340584035005560350022205560333' ||
      '1000055605560333100006670333100003500611035003500222022203330333035005561000' ||
      '0333100005000333094403500500066702780333055605560556055602600556033307370370' ||
      '0556058403330737033304000584033303330333055605370278033303330365055608340834' ||
      '0834061106670667066706670667066710000722066706670667066702780278027802780722' ||
      '0722077807780778077807780584077807220722072207220667066706110556055605560556' ||
      '0556055608890500055605560556055602780278027802780556055605560556055605560556' ||
      '058406110556055605560556050005560500';
    when 'Helveticab' then return
      '0278027802780278027802780278027802780278027802780278027802780278027802780278' ||
      '0278027802780278027802780278027802780278027802780278027803330474055605560889' ||
      '0722023803330333038905840278033302780278055605560556055605560556055605560556' ||
      '0556033303330584058405840611097507220722072207220667061107780722027805560722' ||
      '0611083307220778066707780722066706110722066709440667066706110333027803330584' ||
      '0556033305560611055606110556033306110611027802780556027808890611061106110611' ||
      '0389055603330611055607780556055605000389028003890584035005560350027805560500' ||
      '1000055605560333100006670333100003500611035003500278027805000500035005561000' ||
      '0333100005560333094403500500066702780333055605560556055602800556033307370370' ||
      '0556058403330737033304000584033303330333061105560278033303330365055608340834' ||
      '0834061107220722072207220722072210000722066706670667066702780278027802780722' ||
      '0722077807780778077807780584077807220722072207220667066706110556055605560556' ||
      '0556055608890556055605560556055602780278027802780611061106110611061106110611' ||
      '058406110611061106110611055606110556';
    when 'Helveticai' then return
      '0278027802780278027802780278027802780278027802780278027802780278027802780278' ||
      '0278027802780278027802780278027802780278027802780278027802780355055605560889' ||
      '0667019103330333038905840278033302780278055605560556055605560556055605560556' ||
      '0556027802780584058405840556101506670667072207220667061107780722027805000667' ||
      '0556083307220778066707780722066706110722066709440667066706110278027802780469' ||
      '0556033305560556050005560556027805560556022202220500022208330556055605560556' ||
      '0333050002780556050007220500050005000334026003340584035005560350022205560333' ||
      '1000055605560333100006670333100003500611035003500222022203330333035005561000' ||
      '0333100005000333094403500500066702780333055605560556055602600556033307370370' ||
      '0556058403330737033304000584033303330333055605370278033303330365055608340834' ||
      '0834061106670667066706670667066710000722066706670667066702780278027802780722' ||
      '0722077807780778077807780584077807220722072207220667066706110556055605560556' ||
      '0556055608890500055605560556055602780278027802780556055605560556055605560556' ||
      '058406110556055605560556050005560500';
    when 'Helveticabi' then return
      '0278027802780278027802780278027802780278027802780278027802780278027802780278' ||
      '0278027802780278027802780278027802780278027802780278027803330474055605560889' ||
      '0722023803330333038905840278033302780278055605560556055605560556055605560556' ||
      '0556033303330584058405840611097507220722072207220667061107780722027805560722' ||
      '0611083307220778066707780722066706110722066709440667066706110333027803330584' ||
      '0556033305560611055606110556033306110611027802780556027808890611061106110611' ||
      '0389055603330611055607780556055605000389028003890584035005560350027805560500' ||
      '1000055605560333100006670333100003500611035003500278027805000500035005561000' ||
      '0333100005560333094403500500066702780333055605560556055602800556033307370370' ||
      '0556058403330737033304000584033303330333061105560278033303330365055608340834' ||
      '0834061107220722072207220722072210000722066706670667066702780278027802780722' ||
      '0722077807780778077807780584077807220722072207220667066706110556055605560556' ||
      '0556055608890556055605560556055602780278027802780611061106110611061106110611' ||
      '058406110611061106110611055606110556';
    when 'Times' then return
      '0250025002500250025002500250025002500250025002500250025002500250025002500250' ||
      '0250025002500250025002500250025002500250025002500250025003330408050005000833' ||
      '0778018003330333050005640250033302500278050005000500050005000500050005000500' ||
      '0500027802780564056405640444092107220667066707220611055607220722033303890722' ||
      '0611088907220722055607220667055606110722072209440722072206110333027803330469' ||
      '0500033304440500044405000444033305000500027802780500027807780500050005000500' ||
      '0333038902780500050007220500050004440480020004800541035005000350033305000444' ||
      '1000050005000333100005560333088903500611035003500333033304440444035005001000' ||
      '0333098003890333072203500444072202500333050005000500050002000500033307600276' ||
      '0500056403330760033304000564030003000333050004530250033303000310050007500750' ||
      '0750044407220722072207220722072208890667061106110611061103330333033303330722' ||
      '0722072207220722072207220564072207220722072207220722055605000444044404440444' ||
      '0444044406670444044404440444044402780278027802780500050005000500050005000500' ||
      '056405000500050005000500050005000500';
    when 'Timesb' then return
      '0250025002500250025002500250025002500250025002500250025002500250025002500250' ||
      '0250025002500250025002500250025002500250025002500250025003330555050005001000' ||
      '0833027803330333050005700250033302500278050005000500050005000500050005000500' ||
      '0500033303330570057005700500093007220667072207220667061107780778038905000778' ||
      '0667094407220778061107780722055606670722072210000722072206670333027803330581' ||
      '0500033305000556044405560444033305000556027803330556027808330556050005560556' ||
      '0444038903330556050007220500050004440394022003940520035005000350033305000500' ||
      '1000050005000333100005560333100003500667035003500333033305000500035005001000' ||
      '0333100003890333072203500444072202500333050005000500050002200500033307470300' ||
      '0500057003330747033304000570030003000333055605400250033303000330050007500750' ||
      '0750050007220722072207220722072210000722066706670667066703890389038903890722' ||
      '0722077807780778077807780570077807220722072207220722061105560500050005000500' ||
      '0500050007220444044404440444044402780278027802780500055605000500050005000500' ||
      '057005000556055605560556050005560500';
    when 'Timesi' then return
      '0250025002500250025002500250025002500250025002500250025002500250025002500250' ||
      '0250025002500250025002500250025002500250025002500250025003330420050005000833' ||
      '0778021403330333050006750250033302500278050005000500050005000500050005000500' ||
      '0500033303330675067506750500092006110611066707220611061107220722033304440667' ||
      '0556083306670722061107220611050005560722061108330611055605560389027803890422' ||
      '0500033305000500044405000444027805000500027802780444027807220500050005000500' ||
      '0389038902780500044406670444044403890400027504000541035005000350033305000556' ||
      '0889050005000333100005000333094403500556035003500333033305560556035005000889' ||
      '0333098003890333066703500389055602500389050005000500050002750500033307600276' ||
      '0500067503330760033304000675030003000333050005230250033303000310050007500750' ||
      '0750050006110611061106110611061108890667061106110611061103330333033303330722' ||
      '0667072207220722072207220675072207220722072207220556061105000500050005000500' ||
      '0500050006670444044404440444044402780278027802780500050005000500050005000500' ||
      '067505000500050005000500044405000444';
    when 'Timesbi' then return
      '0250025002500250025002500250025002500250025002500250025002500250025002500250' ||
      '0250025002500250025002500250025002500250025002500250025003890555050005000833' ||
      '0778027803330333050005700250033302500278050005000500050005000500050005000500' ||
      '0500033303330570057005700500083206670667066707220667066707220778038905000667' ||
      '0611088907220722061107220667055606110722066708890667061106110333027803330570' ||
      '0500033305000500044405000444033305000556027802780500027807780556050005000500' ||
      '0389038902780556044406670500044403890348022003480570035005000350033305000500' ||
      '1000050005000333100005560333094403500611035003500333033305000500035005001000' ||
      '0333100003890333072203500389061102500389050005000500050002200500033307470266' ||
      '0500060603330747033304000570030003000333057605000250033303000300050007500750' ||
      '0750050006670667066706670667066709440667066706670667066703890389038903890722' ||
      '0722072207220722072207220570072207220722072207220611061105000500050005000500' ||
      '0500050007220444044404440444044402780278027802780500055605000500050005000500' ||
      '057005000556055605560556044405000444';
    when 'Symbol' then return
      '0250025002500250025002500250025002500250025002500250025002500250025002500250' ||
      '0250025002500250025002500250025002500250025002500250025003330713050005490833' ||
      '0778043903330333050005490250054902500278050005000500050005000500050005000500' ||
      '0500027802780549054905490444054907220667072206120611076306030722033306310722' ||
      '0686088907220722076807410556059206110690043907680645079506110333086303330658' ||
      '0500050006310549054904940439052104110603032906030549054905760521054905490521' ||
      '0549060304390576071306860493068604940480020004800549000000000000000000000000' ||
      '0000000000000000000000000000000000000000000000000000000000000000000000000000' ||
      '0000000000000000000000000000000007500620024705490167071305000753075307530753' ||
      '1042098706030987060304000549041105490549071304940460054905490549054910000603' ||
      '1000065808230686079509870768076808230768076807130713071307130713071307130768' ||
      '0713079007900890082305490250071306030603104209870603098706030494032907900790' ||
      '0786071303840384038403840384038404940494049404940000032902740686068606860384' ||
      '038403840384038403840494049404940000';
    when 'Zapfdingbats' then return
      '0000000000000000000000000000000000000000000000000000000000000000000000000000' ||
      '0000000000000000000000000000000000000000000000000000027809740961097409800719' ||
      '0789079007910690096009390549085509110933091109450974075508460762076105710677' ||
      '0763076007590754049405520537057706920786078807880790079307940816082307890841' ||
      '0823083308160831092307440723074907900792069507760768079207590707070806820701' ||
      '0826081507890789070706870696068907860787071307910785079108730761076207620759' ||
      '0759089208920788078404380138027704150392039206680668000003900390031703170276' ||
      '0276050905090410041002340234033403340000000000000000000000000000000000000000' ||
      '0000000000000000000000000000000000000732054405440910066707600760077605950694' ||
      '0626078807880788078807880788078807880788078807880788078807880788078807880788' ||
      '0788078807880788078807880788078807880788078807880788078807880788078807880788' ||
      '0788078807880894083810160458074809240748091809270928092808340873082809240924' ||
      '0917093009310463088308360836086708670696069608740000087407600946077108650771' ||
      '088809670888083108730927097009180000';
  else return null;
  end case;
end p_digitos_da_familia;

----------------------------------------------------------------------------------------
-- A metrica de uma chave 'familia+estilo'. Devolve tabela VAZIA para chave
-- desconhecida — quem chama decide o que fazer com isso, e precisa checar
-- ANTES de percorrer: sobre tabela vazia, .first e .last sao nulos.
----------------------------------------------------------------------------------------
function p_larguras_da_fonte(p_chave in varchar2) return charSet is
  l_digitos varchar2(1100);
  l_vazia   charSet;
begin
  l_digitos := p_digitos_da_familia(
    case lower(p_chave)
      when 'courier' then 'Courier'
      when 'courierb' then 'Courier'
      when 'courieri' then 'Courier'
      when 'courierbi' then 'Courier'
      when 'helvetica' then 'Helvetica'
      when 'helveticab' then 'Helveticab'
      when 'helveticai' then 'Helveticai'
      when 'helveticabi' then 'Helveticabi'
      when 'times' then 'Times'
      when 'timesb' then 'Timesb'
      when 'timesi' then 'Timesi'
      when 'timesbi' then 'Timesbi'
      when 'symbol' then 'Symbol'
      when 'zapfdingbats' then 'Zapfdingbats'
    end);
  if l_digitos is null then
    return l_vazia;
  end if;
  return p_larguras_de(l_digitos);
end p_larguras_da_fonte;
-- </larguras-das-fontes>

----------------------------------------------------------------------------------
-- Inclusion des métriques d'une font.
----------------------------------------------------------------------------------
procedure p_includeFont (pfontname in varchar2) is
  mySet charSet;
begin
  if pfontname is null then
    return;
  end if;
  mySet := p_larguras_da_fonte(pfontname);
  -- Chave desconhecida devolve tabela vazia. NAO se registra vazia: quem chama
  -- (SetFont) testa fpdf_charwidths.exists e levanta 'Could not include font
  -- metric file'. Registrar vazia faria o exists passar e o erro so aparecer
  -- depois, na medida do texto, com a fonte medindo zero.
  if mySet.count > 0 then
    fpdf_charwidths(pfontname) := mySet;
  end if;
end p_includeFont;

----------------------------------------------------------------------------------
-- p_getFontMetrics : récupérer les metric d'une font.
----------------------------------------------------------------------------------
function p_getFontMetrics(pFontName in varchar2) return charSet is
begin
  return p_larguras_da_fonte(pFontName);
end p_getFontMetrics;

----------------------------------------------------------------------------------
-- Parcours le tableau des images et renvoie true si l'image cherché existe 
-- dans le tableau.
----------------------------------------------------------------------------------
function imageExists(pFile in varchar2) return boolean is
begin
  if (images.exists(lower(pFile))) then
     return true;
  end if;
  return false;
exception 
  when others then
   error('imageExists : '||sqlerrm);
   return false;
end imageExists;

----------------------------------------------------------------------------------
-- Parcours le tableau des charwidths et renvoie true si il existe pour la font
-- donnée.
----------------------------------------------------------------------------------
function fpdf_charwidthsExists(pFontName in varchar2) return boolean is
chTab charSet;
begin
  if (fpdf_charwidths.exists(pFontName)) then
     chTab := fpdf_charwidths(pFontName);
	 if (nvl(chTab.count, 0) > 0) then
       return true;
	 end if;
  end if;
  return false;
exception
  when others then
    return false;
end fpdf_charwidthsExists;

----------------------------------------------------------------------------------
-- Parcours le tableau des fonts et renvoie true si il existe pour la font
-- donnée.
----------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
/*******************************************************************************
* Procedure: log_message (Internal helper)
* Description: Simple logging utility for debugging and monitoring
*******************************************************************************/
--------------------------------------------------------------------------------
-- Date: 2025-12-18
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: log_message (Internal)
* Description: Enhanced logging with DBMS_APPLICATION_INFO and DBMS_OUTPUT
*******************************************************************************/
procedure log_message(
  p_level pls_integer,
  p_message varchar2
) is
  l_log_text varchar2(4000);
  l_level_name varchar2(10);
begin
  if p_level <= g_log_level and gb_mode_debug then
    l_level_name := case p_level
      when 1 then 'ERROR'
      when 2 then 'WARN'
      when 3 then 'INFO'
      when 4 then 'DEBUG'
      else 'UNKNOWN'
    end;

    l_log_text := to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') || ' [' ||
                  l_level_name || '] ' || substr(p_message, 1, 3900);

    -- Output to DBMS_OUTPUT for interactive sessions
    dbms_output.put_line(l_log_text);

    -- Also log to DBMS_APPLICATION_INFO for monitoring
    begin
      dbms_application_info.set_client_info(substr(l_log_text, 1, 64));
    exception
      when others then
        null;  -- Silently ignore if DBMS_APPLICATION_INFO fails
    end;
  end if;
end log_message;

/*******************************************************************************
* Procedure: SetLogLevel
* Description: Sets the logging level for debugging
*******************************************************************************/
procedure SetLogLevel(p_level pls_integer) is
begin
  -- TASK 3.1: Using log level constants
  if p_level < c_LOG_OFF or p_level > c_LOG_DEBUG then
    raise_application_error(-20100,
      'Invalid log level: ' || p_level || '. Must be ' || c_LOG_OFF || '-' || c_LOG_DEBUG ||
      ' (' || c_LOG_OFF || '=OFF, ' || c_LOG_ERROR || '=ERROR, ' || c_LOG_WARN || '=WARN, ' ||
      c_LOG_INFO || '=INFO, ' || c_LOG_DEBUG || '=DEBUG)');
  end if;

  g_log_level := p_level;
  log_message(c_LOG_INFO, 'Log level changed to: ' || p_level || ' (' ||
    case p_level
      when c_LOG_OFF then 'OFF'
      when c_LOG_ERROR then 'ERROR'
      when c_LOG_WARN then 'WARN'
      when c_LOG_INFO then 'INFO'
      when c_LOG_DEBUG then 'DEBUG'
    end || ')');
end SetLogLevel;

/*******************************************************************************
* Function: GetLogLevel
* Description: Returns the current logging level
*******************************************************************************/
function GetLogLevel return pls_integer is
begin
  return g_log_level;
end GetLogLevel;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
/*******************************************************************************
* Procedure: init_page_formats (Internal)
* Description: Initializes standard page format definitions (in mm)
*******************************************************************************/
procedure init_page_formats is
begin
  if g_formats_initialized then
    return;  -- Already initialized
  end if;

  -- ISO A series (in mm)
  g_page_formats('A3').width := 297;
  g_page_formats('A3').height := 420;

  g_page_formats('A4').width := 210;
  g_page_formats('A4').height := 297;

  g_page_formats('A5').width := 148;
  g_page_formats('A5').height := 210;

  -- North American formats
  g_page_formats('LETTER').width := 215.9;
  g_page_formats('LETTER').height := 279.4;

  g_page_formats('LEGAL').width := 215.9;
  g_page_formats('LEGAL').height := 355.6;

  g_page_formats('LEDGER').width := 279.4;
  g_page_formats('LEDGER').height := 431.8;

  g_page_formats('TABLOID').width := 279.4;
  g_page_formats('TABLOID').height := 431.8;

  -- Other formats
  g_page_formats('EXECUTIVE').width := 184.15;
  g_page_formats('EXECUTIVE').height := 266.7;

  g_page_formats('FOLIO').width := 210;
  g_page_formats('FOLIO').height := 330;

  g_page_formats('B5').width := 176;
  g_page_formats('B5').height := 250;

  g_formats_initialized := true;

  log_message(4, 'Page formats initialized: ' || g_page_formats.count || ' formats');

exception
  when others then
    log_message(1, 'Error initializing page formats: ' || sqlerrm);
    raise;
end init_page_formats;

/*******************************************************************************
* Function: get_page_format (Internal)
* Description: Returns dimensions for a named page format
*******************************************************************************/
function get_page_format(p_format_name varchar2) return recPageFormat is
  l_format recPageFormat;
  l_format_upper varchar2(20) := upper(p_format_name);
begin
  -- Ensure formats are initialized
  if not g_formats_initialized then
    init_page_formats();
  end if;

  -- Look up format
  if g_page_formats.exists(l_format_upper) then
    l_format := g_page_formats(l_format_upper);
  else
    -- Unknown format, raise error (Task 1.2 requirement)
    raise_application_error(-20103,
      'Unknown page format: ' || p_format_name || '. Use A3, A4, A5, Letter, Legal, Ledger, Executive, Folio, B5, or custom format like "100,200"');
  end if;

  return l_format;
end get_page_format;

--------------------------------------------------------------------------------
-- Date: 2025-12-16
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Parse PNG header to extract metadata
--------------------------------------------------------------------------------
function parse_png_header(p_blob blob, p_img in out recImageBlob) return boolean is
  l_signature raw(8);
  l_chunk_length raw(4);
  l_chunk_type raw(4);
  l_ihdr_data raw(13);
  l_pos integer := 1;
  c_png_signature constant raw(8) := hextoraw('89504E470D0A1A0A');
begin
  -- Validate PNG signature
  if dbms_lob.getlength(p_blob) < 33 then
    return false;
  end if;

  l_signature := dbms_lob.substr(p_blob, 8, 1);
  if l_signature != c_png_signature then
    return false;
  end if;

  -- Read IHDR chunk (always first after signature)
  l_pos := 9;
  l_chunk_length := dbms_lob.substr(p_blob, 4, l_pos); -- Should be 0x0000000D (13 bytes)
  l_pos := l_pos + 4;
  l_chunk_type := dbms_lob.substr(p_blob, 4, l_pos);   -- Should be 'IHDR'
  l_pos := l_pos + 4;

  if l_chunk_type != hextoraw('49484452') then -- 'IHDR'
    return false;
  end if;

  -- Read IHDR data: width(4) height(4) bit_depth(1) color_type(1) ...
  l_ihdr_data := dbms_lob.substr(p_blob, 13, l_pos);

  -- Extract width (bytes 0-3, big-endian)
  p_img.width := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 1, 4), utl_raw.big_endian);

  -- Extract height (bytes 4-7, big-endian)
  p_img.height := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 5, 4), utl_raw.big_endian);

  -- Extract bit depth (byte 8)
  p_img.bit_depth := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 9, 1));

  -- Extract color type (byte 9)
  -- 0=grayscale, 2=RGB, 3=indexed, 4=grayscale+alpha, 6=RGBA
  p_img.color_type := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 10, 1));

  -- Check for transparency
  p_img.has_transparency := (p_img.color_type = 4 or p_img.color_type = 6);

  p_img.file_format := 'PNG';
  p_img.mime_type := 'image/png';

  log_message(4, 'PNG parsed: ' || p_img.width || 'x' || p_img.height ||
              ', bit_depth=' || p_img.bit_depth || ', color_type=' || p_img.color_type);

  return true;
exception
  when others then
    log_message(1, 'Error parsing PNG header: ' || sqlerrm);
    return false;
end parse_png_header;

--------------------------------------------------------------------------------
-- Parse JPEG header to extract metadata
--------------------------------------------------------------------------------
function parse_jpeg_header(p_blob blob, p_img in out recImageBlob) return boolean is
  l_marker raw(2);
  l_pos integer := 1;
  l_length integer;
  l_seg_length raw(2);
  l_seg_len integer;
  l_data raw(32767);
  c_soi constant raw(2) := hextoraw('FFD8'); -- Start of Image
  c_sof0 constant raw(2) := hextoraw('FFC0'); -- Start of Frame (baseline)
  c_sof2 constant raw(2) := hextoraw('FFC2'); -- Start of Frame (progressive)
begin
  l_length := dbms_lob.getlength(p_blob);

  if l_length < 4 then
    return false;
  end if;

  -- Validate JPEG signature (SOI marker)
  l_marker := dbms_lob.substr(p_blob, 2, 1);
  if l_marker != c_soi then
    return false;
  end if;

  l_pos := 3;

  -- Scan for SOF marker to get dimensions
  while l_pos < l_length - 10 loop
    l_marker := dbms_lob.substr(p_blob, 2, l_pos);

    -- Check if this is SOF0 or SOF2 marker
    if l_marker = c_sof0 or l_marker = c_sof2 then
      -- Read segment length
      l_seg_length := dbms_lob.substr(p_blob, 2, l_pos + 2);
      l_seg_len := utl_raw.cast_to_binary_integer(l_seg_length, utl_raw.big_endian);

      -- Read SOF data: length(2) precision(1) height(2) width(2) ...
      l_data := dbms_lob.substr(p_blob, 9, l_pos + 2);

      -- Precision (byte 2)
      p_img.bit_depth := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 3, 1));

      -- Height (bytes 3-4, big-endian)
      p_img.height := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 4, 2), utl_raw.big_endian);

      -- Width (bytes 5-6, big-endian)
      p_img.width := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 6, 2), utl_raw.big_endian);

      -- Number of components (byte 7) - 1=grayscale, 3=RGB, 4=CMYK
      p_img.color_type := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 8, 1));

      p_img.has_transparency := false; -- JPEG doesn't support transparency
      p_img.file_format := 'JPEG';
      p_img.mime_type := 'image/jpeg';

      log_message(4, 'JPEG parsed: ' || p_img.width || 'x' || p_img.height ||
                  ', bit_depth=' || p_img.bit_depth || ', components=' || p_img.color_type);

      return true;
    end if;

    -- Move to next marker
    if utl_raw.substr(l_marker, 1, 1) = hextoraw('FF') then
      -- Read segment length and skip
      l_seg_length := dbms_lob.substr(p_blob, 2, l_pos + 2);
      l_seg_len := utl_raw.cast_to_binary_integer(l_seg_length, utl_raw.big_endian);
      l_pos := l_pos + 2 + l_seg_len;
    else
      l_pos := l_pos + 1;
    end if;
  end loop;

  return false;
exception
  when others then
    log_message(1, 'Error parsing JPEG header: ' || sqlerrm);
    return false;
end parse_jpeg_header;

--------------------------------------------------------------------------------
-- Get image from URL with native BLOB handling (replaces OrdImage)
--------------------------------------------------------------------------------
function getImageFromUrl(p_Url in varchar2) return recImageBlob is
  l_img recImageBlob;
  lv_url varchar2(2000) := p_Url;
  urityp URIType;
  l_parsed boolean := false;
begin
  -- Initialize image BLOB
  dbms_lob.createtemporary(l_img.image_blob, true, dbms_lob.session);

  -- Normalize URL
  if instr(lv_url, 'http') = 0 then
    lv_url := 'http://' || owa_util.get_cgi_env('SERVER_NAME') || '/' || lv_url;
  end if;

  log_message(4, 'Fetching image from URL: ' || lv_url);

  begin
    -- Fetch image using URIFactory
    urityp := URIFactory.getURI(lv_url);
    l_img.image_blob := urityp.getBlob();
    l_img.mime_type := urityp.getContentType();

    log_message(4, 'Image fetched, MIME type: ' || l_img.mime_type ||
                ', size: ' || dbms_lob.getlength(l_img.image_blob) || ' bytes');

  exception
    when others then
      raise_application_error(-20302, 'Unable to fetch image from URL: ' || p_Url || ' - ' || sqlerrm);
  end;

  -- Parse image header based on format
  if l_img.mime_type like '%png%' or dbms_lob.substr(l_img.image_blob, 8, 1) = hextoraw('89504E470D0A1A0A') then
    l_parsed := parse_png_header(l_img.image_blob, l_img);
    if not l_parsed then
      raise_application_error(-20301, 'Invalid PNG header in image: ' || p_Url);
    end if;

  elsif l_img.mime_type like '%jpeg%' or l_img.mime_type like '%jpg%' or
        dbms_lob.substr(l_img.image_blob, 2, 1) = hextoraw('FFD8') then
    l_parsed := parse_jpeg_header(l_img.image_blob, l_img);
    if not l_parsed then
      raise_application_error(-20301, 'Invalid JPEG header in image: ' || p_Url);
    end if;

  else
    raise_application_error(-20303, 'Unsupported image format (only PNG and JPEG supported): ' ||
                           nvl(l_img.mime_type, 'unknown') || ' for URL: ' || p_Url);
  end if;

  return l_img;
exception
  when others then
    if dbms_lob.istemporary(l_img.image_blob) = 1 then
      dbms_lob.freetemporary(l_img.image_blob);
    end if;
    raise;
end getImageFromUrl;

--------------------------------------------------------------------------------
-- get an image in a blob from an oracle table (DEPRECATED - Task 1.6)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Enables debug infos
--------------------------------------------------------------------------------
procedure DebugEnabled is
begin
  gb_mode_debug := true;
end DebugEnabled;

--------------------------------------------------------------------------------
-- disables debug infos
--------------------------------------------------------------------------------
procedure DebugDisabled is
begin
  gb_mode_debug := false;
end DebugDisabled;

--------------------------------------------------------------------------------
-- Returns the k property
--------------------------------------------------------------------------------
function GetScaleFactor return number is
begin
	-- Get scale factor
	return k;
end GetScaleFactor;

--------------------------------------------------------------------------------
-- Returns the Linespacing property
--------------------------------------------------------------------------------
function GetLineSpacing return number is
begin
	-- Get LineSpacing property
	return LineSpacing;
end GetLineSpacing;

--------------------------------------------------------------------------------
-- sets the Linespacing property
--------------------------------------------------------------------------------
Procedure SetLineSpacing (pls in number) is
begin
    -- Set LineSpacing property
    LineSpacing := pls;
end SetLineSpacing;

----------------------------------------------------------------------------------
-- Compatibilité PHP -> PLSQL : proc. and func. spécifiques au portages
-- 				 	 		  	ajoutée pour des facilités de traduction
----------------------------------------------------------------------------------





-- Responde a mesma pergunta que o is_string do porte fazia: "este VARCHAR2 NAO
-- contem um numero?". La a resposta vinha de provocar excecao no to_number e
-- captura-la com WHEN OTHERS; aqui vem do TO_NUMBER ... DEFAULT NULL ON
-- CONVERSION ERROR, que responde sem excecao.
-- NULO continua contando como numero, porque era o comportamento antigo:
-- to_number(NULL) devolve NULL e nao levanta nada.
-- Nao se usa VALIDATE_CONVERSION: e funcao de SQL, e em expressao PL/SQL da
-- PLS-00201.
function nao_e_numero(p_txt in varchar2) return boolean is
begin
  return p_txt is not null
     and to_number(p_txt default null on conversion error) is null;
end nao_e_numero;

function tonumber(v_str in varchar2) return number is
   v_num number;
   v_str2 varchar2(255);
begin
   -- Numeros do PDF usam ponto como separador decimal. Se a sessao estiver com
   -- virgula (NLS_NUMERIC_CHARACTERS = ',.'), to_number(v_str) falha; nesse caso
   -- converte o ponto para o separador da sessao antes de tentar de novo.
   begin
      v_num := to_number(v_str);
   exception
      when others then
         v_num := null;
   end;
   if v_num is null then
      v_str2 := replace(v_str, '.', ',');
      begin
         v_num := to_number(v_str2);
      exception
         when others then
            v_num := null;
      end;
   end if;
   return v_num;
end;

function tochar(pnum in number, pprecision in number default 2) return varchar2 is
-- O PDF exige ponto como separador decimal. A conversao usa NLS explicito para nao
-- depender de (nem alterar) a configuracao da sessao do chamador.
-- round antes de formatar: truncar fazia 10.999 virar 10.99 na saida
mynum word := replace(to_char(round(pnum, pprecision), 'TM9', co_nls_num), ',', '.');
ceilnum word;
decnum word;
begin
  if (instr(mynum,'.') = 0) then
    mynum := mynum || '.0';
  end if;
  ceilnum := nvl(substr(mynum,1,instr(mynum,'.')-1), '0');
  decnum := nvl(substr(mynum,instr(mynum,'.')+1), '0');
  decnum := substr(decnum,1, pprecision);
  if (pprecision = 0 ) then 
  	 mynum := ceilnum;
  else
  	 mynum := ceilnum || '.' ||decnum;
  end if; 
  return mynum;
end tochar;



-- Parametro IN (nao IN OUT): as funcoes so leem o argumento. Com IN OUT, o
-- PL/SQL copiava o valor na entrada e na saida a cada chamada, e o chamador
-- era obrigado a passar uma variavel — nunca uma expressao ou literal.



----------------------------------------------------------------------------------------
--  Traduction des méthodes PHP.
----------------------------------------------------------------------------------------
procedure p_dochecks is
begin
  -- Nao altera mais NLS_NUMERIC_CHARACTERS da sessao do chamador: a conversao
  -- numerica passou a ser explicita em tochar/tonumber (co_nls_num).
  -- O valor antigo (',.') ainda quebrava tonumber('10.5'), usada nas coordenadas
  -- de links, alem de vazar para o codigo do usuario depois da geracao.
  null;
end p_dochecks;

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- p_ensure_page_clob : garante que a pagina possui um CLOB temporario alocado.
----------------------------------------------------------------------------------------
procedure p_ensure_page_clob(p_page in pls_integer) is
begin
  if not pages.exists(p_page) then
    pages(p_page) := null;              -- cria a entrada; so entao pode ir como OUT
  end if;
  if pages(p_page) is null then
    dbms_lob.createtemporary(pages(p_page), true, dbms_lob.session);
  end if;
end p_ensure_page_clob;

----------------------------------------------------------------------------------------
-- p_free_pages : libera os CLOBs temporarios de todas as paginas e zera o acumulador.
--                Evita vazamento de LOB de sessao entre documentos.
----------------------------------------------------------------------------------------
procedure p_free_pages is
  i pls_integer := pages.first;
begin
  while i is not null loop
    if pages(i) is not null and dbms_lob.istemporary(pages(i)) = 1 then
      dbms_lob.freetemporary(pages(i));
    end if;
    i := pages.next(i);
  end loop;
  pages.delete;
  g_page_buf := null;
  g_page_buf_page := null;
end p_free_pages;

----------------------------------------------------------------------------------------
-- p_flush_doc_buf : descarrega o acumulador do documento no CLOB final.
--                   Chamar antes de qualquer leitura de pdfDoc (tamanho ou conteudo).
----------------------------------------------------------------------------------------
procedure p_flush_doc_buf is
  l_len pls_integer;
begin
  l_len := nvl(length(g_doc_buf), 0);
  if l_len > 0 then
    dbms_lob.writeappend(pdfDoc, l_len, g_doc_buf);
  end if;
  g_doc_buf := null;
end p_flush_doc_buf;

----------------------------------------------------------------------------------------
-- p_flush_page_buf : descarrega o acumulador VARCHAR2 no CLOB da pagina correspondente.
--                    Chamar antes de trocar de pagina e antes de ler o conteudo.
----------------------------------------------------------------------------------------
procedure p_flush_page_buf is
  l_len pls_integer;
begin
  if g_page_buf is null or g_page_buf_page is null then
    g_page_buf := null;
    return;
  end if;
  l_len := length(g_page_buf);
  if l_len > 0 then
    p_ensure_page_clob(g_page_buf_page);
    dbms_lob.writeappend(pages(g_page_buf_page), l_len, g_page_buf);
  end if;
  g_page_buf := null;
end p_flush_page_buf;

----------------------------------------------------------------------------------------
procedure p_out(pstr in varchar2 default null, pCRLF in boolean default true) is 
lv_CRLF varchar2(2);
  lv_output varchar2(32767);
begin
  -- Task 1.7: Refactored to use CLOB with DBMS_LOB.WRITEAPPEND
  if (pCRLF) then
    lv_CRLF := chr(10);
  end if;

  lv_output := pstr || lv_CRLF;

  -- Add a line to the document
  if(state = 2) then
    -- Conteudo de pagina: acumula em VARCHAR2 e descarrega no CLOB quando enche.
    -- Sem teto de 32k por pagina e sem recopiar a pagina a cada instrucao.
    if g_page_buf_page is not null and g_page_buf_page != page then
      p_flush_page_buf;                      -- trocou de pagina: fecha a anterior
    end if;
    if nvl(lengthb(g_page_buf), 0) + nvl(lengthb(lv_output), 0) > co_page_buf_limit then
      p_flush_page_buf;
    end if;
    g_page_buf_page := page;
    g_page_buf := g_page_buf || lv_output;
  else
    -- Documento: mesmo acumulador, uma chamada LOB a cada ~32 KB em vez de
    -- uma por instrucao emitida.
    if lv_output is not null then
      if nvl(lengthb(g_doc_buf), 0) + lengthb(lv_output) > co_page_buf_limit then
        p_flush_doc_buf;
      end if;
      g_doc_buf := g_doc_buf || lv_output;
    end if;
  end if;
exception
  when others then
    error('p_out : '||sqlerrm);
end p_out;

----------------------------------------------------------------------------------------
procedure p_newobj is
begin
	-- Begin a new object
	n := n + 1;
	offsets(n) := getPDFDocLength();
	p_out(n || ' 0 obj');
exception 
  when others then
   error('p_newobj : '||sqlerrm);
end p_newobj;

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- Escapa uma string literal do PDF: dentro de (...) a barra invertida inicia
-- sequencia de escape, entao ela e os dois parenteses precisam de barra na
-- frente. A ORDEM importa: a barra vem PRIMEIRO, senao as barras que o proprio
-- escape dos parenteses introduz seriam escapadas de novo.
--
-- Esta e a UNICA implementacao. Existiam cinco, e TRES estavam erradas:
-- procuravam por '\\' e trocavam por '\\\\'. Em PL/SQL nao ha escape em
-- literal, entao aquilo procura DUAS barras e troca por QUATRO — e uma barra
-- sozinha, que e o caso comum, passava intacta para o arquivo. O comentario
-- original dizia "Add \ before \, ( and )": a intencao estava certa, a
-- implementacao nao. Pegava PL_FPDF.Text e os metadados do documento (titulo,
-- autor, assunto, palavras-chave, criador), que passam pelo p_textstring.
----------------------------------------------------------------------------------------
function p_escapa_pdf(p_txt in varchar2) return varchar2 is
begin
  return replace(replace(replace(p_txt, '\', '\\'), '(', '\('), ')', '\)');
end p_escapa_pdf;

----------------------------------------------------------------------------------------
function p_textstring(pstr in varchar2) return varchar2 is
begin
	-- Format a text string
  -- Task 2.1: Use UTF8ToPDFString for proper encoding
	return '(' || UTF8ToPDFString(pstr, true) || ')';
end p_textstring;

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- p_putstream_clob : escreve o conteudo de uma pagina (CLOB) no documento em blocos,
--                    sem materializar a pagina inteira em VARCHAR2.
----------------------------------------------------------------------------------------
procedure p_putstream_clob(pdata in clob) is
  l_off   pls_integer := 1;
  l_size  pls_integer := 8000;    -- chars; <= 32767 bytes em UTF-8
  l_total number := dbms_lob.getlength(pdata);
  l_part  varchar2(32767);
begin
  p_out('stream');
  while l_off <= l_total loop
    l_part := dbms_lob.substr(pdata, l_size, l_off);
    if l_part is not null then
      p_out(l_part, false);
    end if;
    l_off := l_off + l_size;
  end loop;
  p_out('');
  p_out('endstream');
exception
  when others then
    error('p_putstream_clob : '||sqlerrm);
end p_putstream_clob;

----------------------------------------------------------------------------------------
procedure p_putstream(pstr in varchar2) is 
begin
	p_out('stream');
	p_out(pstr);
	p_out('endstream');
exception 
  when others then
   error('p_putstream : '||sqlerrm);
end p_putstream;

----------------------------------------------------------------------------------------
procedure p_putstream(pData in out NOCOPY blob) is 
	offset integer := 1;
  lv_content_length number := dbms_lob.getlength(pdata);
	buf_size integer := 2000;
	buf varchar2(2000);
begin
	p_out('stream');
	-- read the blob and put it in small pieces in a varchar
	while offset < lv_content_length loop
	  dbms_lob.read(pData,buf_size,offset,buf);
	  p_out(buf, false);
	  offset := offset + buf_size;
	end loop;
	-- put a CRLF at te end of the blob
	p_out(chr(10), false);
	p_out('endstream');
exception 
  when others then
   error('p_putstream : '||sqlerrm);
end p_putstream;

----------------------------------------------------------------------------------------
procedure p_putxobjectdict is
v txt;
begin
   v := images.first;
   while (v is not null) loop
	 p_out('/I' || images(v).i || ' ' || images(v).n || ' 0 R');
	 v := images.next(v);
   end loop;
exception
  when others then
  error('p_putxobjectdict : '||sqlerrm);
end p_putxobjectdict;

----------------------------------------------------------------------------------------
procedure p_putresourcedict is
v varchar2(200);
begin
	p_out('/ProcSet [/PDF /Text /ImageB /ImageC /ImageI]');
	p_out('/Font <<');
	v := fonts.first;
	while (v is not null) 
	loop
	    p_out('/F' || fonts(v).i || ' ' || fonts(v).n  ||' 0 R');
	    v := fonts.next(v);
	end loop;
	p_out('>>');
	p_out('/XObject <<');
	p_putxobjectdict();
	p_out('>>');
exception 
  when others then
   error('p_putresourcedict : '||sqlerrm);
end p_putresourcedict;

----------------------------------------------------------------------------------------
procedure p_putfonts is 
nf number := n;
i pls_integer;
l_chave car;   -- charSet e indexado por VARCHAR2(1); percorre-se com .next
k varchar2(200);
v varchar2(200);
myFont varchar2(2000);
mySet charSet;
myHeader boolean;
myType word;
myName word;
myFile word;
s varchar2(2000);
cw charSet;
theType word;
methode word;
-- plsqlmethode word;
begin
    null;
	i := diffs.first;
	while (i is not null) 
	loop
		-- Encodings
		p_newobj();
		p_out('<</Type /Encoding /BaseEncoding /WinAnsiEncoding /Differences ['|| diffs(i) ||']>>');
		p_out('endobj');
	    i:= diffs.next(i);
	end loop;
		
	-- foreach($this->FontFiles as $file=>$info)
	v := FontFiles.first;
	while (v is not null) 
	loop
		-- Font file embedding
		p_newobj();
		FontFiles(v).n:= n;
		myFont := null;
		
		
		mySet := p_getFontMetrics(FontFiles(v).file);

		-- A checagem vem ANTES do laco, e por dois motivos que ja custaram uma
		-- rodada: sobre tabela vazia .first e .last sao NULOS, e um FOR
		-- numerico com limite nulo levanta ORA-06502 — antes desta mensagem,
		-- que existe justamente para explicar o caso. E charSet e indexado por
		-- VARCHAR2: percorrer com FOR numerico tentaria converter a chave.
		if mySet.count = 0 then
		  Error('Font file not found: ' || FontFiles(v).file);
		end if;

		l_chave := mySet.first;
		while l_chave is not null loop
		  myFont := myFont || mySet(l_chave);
		  l_chave := mySet.next(l_chave);
		end loop;
		
		if(FontFiles(v).length2 is not null) then
		    
			myHeader := false;
			if ( ascii(myFont) = 128) then
			  myHeader := true;
			end if;
			
			if(myHeader) then
				-- Strip first binary header
				myFont := substr(myFont,6);
			end if; 
			
			if(myHeader and ascii(substr(myFont,(FontFiles(v).length1), 1)) = 128) then
				-- Strip second binary header
				myFont := substr(myFont, 1, FontFiles(v).length1) || substr(myFont, FontFiles(v).length1 + 6);
			end if; 
		end if; 
		p_out('<</Length ' || length(myFont));

		p_out('/Length1 ' || FontFiles(v).length1);
		if(FontFiles(v).length2 is not null) then
			p_out('/Length2 '|| FontFiles(v).length2 ||' /Length3 0');
		end if; 
		p_out('>>');
		p_putstream(myFont);
		p_out('endobj');
		
		v := FontFiles.next(v);
	end loop;

	k := fonts.first;
	while (k is not null) loop

	--foreach(fonts as $k=>myFont)
	--{ 
		-- Font objects
		fonts(k).n := n+1;
		myType := fonts(k).type;
		myName := fonts(k).name;
		if(myType = 'core') then
			-- Standard font
			p_newobj();
			p_out('<</Type /Font');
			p_out('/BaseFont /' || myName);
			p_out('/Subtype /Type1');
			if(lower(myName) != 'symbol' and lower(myName) != 'zapfdingbats') then
				p_out('/Encoding /WinAnsiEncoding');
			end if;
			p_out('>>');
			p_out('endobj');
		elsif(lower(myType) = 'type1' or lower(myType) = 'truetype') then
			-- Additional Type1 or TrueType font
			p_newobj();
			p_out('<</Type /Font');
			p_out('/BaseFont /' || myName);
			p_out('/Subtype /' || myType);
			p_out('/FirstChar 32 /LastChar 255');
			p_out('/Widths ' || (n+1) || ' 0 R');
			p_out('/FontDescriptor ' || (n+2) || ' 0 R');
			if(fonts(k).enc is not null) then 			
				if(fonts(k).diff is not null) then
					p_out('/Encoding ' || (nf + fonts(k).diff) || ' 0 R');
				else
					p_out('/Encoding /WinAnsiEncoding');
			    end if;
			end if;
			p_out('>>');
			p_out('endobj');
			-- Widths
			p_newobj();
			
			cw := fonts(k).cw;
			s := '[';
			for i in 32..255 loop
				s := s || cw(chr(i)) || ' ';
		    end loop;
			p_out(s || ']');
			p_out('endobj');
			-- Descriptor
			p_newobj();
			s := '<</Type /FontDescriptor /FontName /' || myName;
			
			for l in fonts(k).dsc.first..fonts(k).dsc.last loop
				s := s || ' /' || l || ' ' || fonts(k).dsc(l);
			end loop;
			
			myFile := fonts(k).file;
			if (myFile is not null) then
			    if (lower(myType) = 'type1') then
				  theType := '';
				 else 
				  theType := '2';
				 end if;
				 s := s || ' /FontFile' || theType || ' ' || FontFiles(myFile).n || ' 0 R';
			end if;
			p_out(s || '>>');
			p_out('endobj');
		else
			-- Allow for additional types
			methode := 'p_put' || lower(myType);
			
			if(not methode_exists(methode)) then
				Error('Unsupported font type: ' || myType);
-- 			else
-- 			  plsqlmethode := 'begin pl_fpdf.'|| methode ||'(''' || fonts(k) || '''); end';
-- 			  execute immediate plsqlmethode;
			end if;
		end if;
		
		k := fonts.next(k);
	end loop;
exception 
  when others then
   error('p_putfonts : '||sqlerrm);
end p_putfonts;

----------------------------------------------------------------------------------------
procedure p_putimages is
  info recImage;
  v txt;
  trns txt;
  pal  txt;
begin
  -- Nao ha filtro a declarar aqui: a imagem traz o seu proprio (info.f, o
  -- /DCTDecode do JPEG por exemplo) e a paleta sai crua. O ramo que punha
  -- '/FlateDecode' quando b_compress estava ligado nao comprimia nada.
	--while(list($file,$info)=each($this->images))
	v := images.first;
	while (v is not null)  loop
		p_newobj();
		images(v).n := n;
	    info := images(v);
		p_out('<</Type /XObject');
		p_out('/Subtype /Image');
		p_out('/Width ' || info.w);
		p_out('/Height ' || info.h);
		if(info.cs = 'Indexed') then
			p_out('/ColorSpace [/Indexed /DeviceRGB ' || to_char(length(info.pal) / 3 - 1) || ' ' || to_char(n+1) || ' 0 R]');
		else
			p_out('/ColorSpace /' || info.cs);
			if(info.cs = 'DeviceCMYK') then
				p_out('/Decode (1 0 1 0 1 0 1 0)');
			end if;
		end if;

		p_out('/BitsPerComponent ' || info.bpc);
		if(info.f is not null) then
			p_out('/Filter /' || info.f);
		end if;
		if(info.parms is not null) then
			p_out(info.parms);
		end if;
		
		if(info.trns.first is not null ) then
			 trns := '';
			for i in info.trns.first..info.trns.count  loop
				 trns := trns || info.trns(i) || ' ' || info.trns(i) || ' ';
			end loop;
			p_out('/Mask (' || trns || ')');
		end if;

		p_out('/Length ' || dbms_lob.getlength(info.data) || '>>');
		p_putstream(info.data);
		images(v).data := null;
		p_out('endobj');

		--Palette
		if(info.cs = 'Indexed') then
			p_newobj();
			 -- a paleta sai crua: o ramo com b_compress declarava /FlateDecode e
			 -- deixava o dado VAZIO, o que produz PDF quebrado assim que alguem
			 -- ligasse a compressao
			 pal := info.pal;
			p_out('<</Length ' || length(pal) || '>>');
			p_putstream(pal);
			p_out('endobj');
		end if;
		v := images.next(v);
	end loop;
exception
  when others then
    error('p_putimages : '||sqlerrm);
end p_putimages;

----------------------------------------------------------------------------------------
procedure p_putresources is
begin
	p_putfonts();
	p_putimages();
	-- Resource dictionary
	offsets(2):= getPDFDocLength();
	p_out('2 0 obj');
	p_out('<<');
	p_putresourcedict();
	p_out('>>');
	p_out('endobj');
exception
  when others then
    error('p_putresources : '||sqlerrm);
end p_putresources;

----------------------------------------------------------------------------------------
procedure p_putinfo is
begin
	p_out('/Producer ' || p_textstring('PL_FPDF ' || co_version ));
	if(title is not null) then
		p_out('/Title ' || p_textstring(title));
	end if; 
	if(subject is not null) then
		p_out('/Subject ' || p_textstring(subject));
	end if; 
	if(author is not null) then
		p_out('/Author ' || p_textstring(author));
	end if; 
	if(keywords is not null) then
		p_out('/Keywords ' || p_textstring(keywords));
	end if; 
	if(creator is not null) then
		p_out('/Creator ' || p_textstring(creator));
	end if; 
	p_out('/CreationDate ' || p_textstring('D:' || to_char(sysdate, 'YYYYMMDDHH24MISS')));
exception
  when others then
    error('p_putinfo : '||sqlerrm);
end p_putinfo;

----------------------------------------------------------------------------------------
procedure p_putcatalog is
begin
	p_out('/Type /Catalog');
	p_out('/Pages 1 0 R');
	if(ZoomMode='fullpage') then
		p_out('/OpenAction [3 0 R /Fit]');
	elsif(ZoomMode='fullwidth') then
		p_out('/OpenAction [3 0 R /FitH null]');
	elsif(ZoomMode='real') then
		p_out('/OpenAction [3 0 R /XYZ null null 1]');
	elsif(not nao_e_numero(ZoomMode)) then
		p_out('/OpenAction [3 0 R /XYZ null null ' || (ZoomMode/100) || ']');
    end if; 
	if(LayoutMode='single') then
		p_out('/PageLayout /SinglePage');
	elsif(LayoutMode='continuous') then
		p_out('/PageLayout /OneColumn');
	elsif(LayoutMode='two') then
		p_out('/PageLayout /TwoColumnLeft');
    end if; 
exception
  when others then
    error('p_putcatalog : '||sqlerrm);
end p_putcatalog;

----------------------------------------------------------------------------------------
procedure p_putheader is
begin
	p_out('%PDF-' || PDFVersion);
end p_putheader;

----------------------------------------------------------------------------------------
procedure p_puttrailer is
  l_id_hex VARCHAR2(100);
begin
  p_out('/Size ' || (n+1));
  p_out('/Root ' || n || ' 0 R');
  p_out('/Info ' || (n-1) || ' 0 R');

  -- Add encryption reference if enabled
  IF g_encrypt_obj_num IS NOT NULL THEN
    p_out('/Encrypt ' || g_encrypt_obj_num || ' 0 R');
  END IF;

  -- Add file ID (required for encryption, optional otherwise)
  IF g_file_id IS NOT NULL THEN
    l_id_hex := RAWTOHEX(g_file_id);
    p_out('/ID [<' || l_id_hex || '><' || l_id_hex || '>]');
  END IF;
end p_puttrailer;

----------------------------------------------------------------------------------------
-- Forward declarations for encryption functions (defined in Phase 5 section)
----------------------------------------------------------------------------------------
FUNCTION generate_file_id RETURN RAW;
FUNCTION compute_owner_key(p_owner_pwd VARCHAR2, p_user_pwd VARCHAR2, p_key_length PLS_INTEGER) RETURN RAW;
FUNCTION compute_owner_value(p_owner_pwd VARCHAR2, p_user_pwd VARCHAR2, p_key_length PLS_INTEGER) RETURN RAW;
FUNCTION compute_encryption_key(p_user_pwd VARCHAR2, p_o_value RAW, p_permissions PLS_INTEGER, p_file_id RAW, p_key_length PLS_INTEGER) RETURN RAW;
FUNCTION compute_user_value(p_encryption_key RAW, p_file_id RAW, p_key_length PLS_INTEGER) RETURN RAW;

----------------------------------------------------------------------------------------
-- p_putencrypt: Write encryption dictionary
----------------------------------------------------------------------------------------
procedure p_putencrypt is
  l_v_value PLS_INTEGER;
  l_r_value PLS_INTEGER;
  l_key_length PLS_INTEGER;
begin
  IF g_encrypt_method IS NULL THEN
    RETURN;
  END IF;

  -- Determine V, R, and key length
  CASE g_encrypt_method
    WHEN 'RC4-40' THEN
      l_v_value := 1; l_r_value := 2; l_key_length := 40;
    WHEN 'RC4-128' THEN
      l_v_value := 2; l_r_value := 3; l_key_length := 128;
    WHEN 'AES-128' THEN
      l_v_value := 4; l_r_value := 4; l_key_length := 128;
    WHEN 'AES-256' THEN
      l_v_value := 5; l_r_value := 5; l_key_length := 256;
    ELSE
      l_v_value := 2; l_r_value := 3; l_key_length := 128;
  END CASE;

  -- Generate file ID if not exists
  IF g_file_id IS NULL THEN
    g_file_id := generate_file_id();
  END IF;

  -- Compute encryption values
  g_o_value := compute_owner_value(g_owner_password, g_user_password, l_key_length);
  g_encryption_key := compute_encryption_key(g_user_password, g_o_value, g_sec_permissions, g_file_id, l_key_length);
  g_u_value := compute_user_value(g_encryption_key, g_file_id, l_key_length);

  -- Write encrypt dictionary
  p_newobj();
  g_encrypt_obj_num := n;

  p_out('<<');
  p_out('/Filter /Standard');
  p_out('/V ' || l_v_value);
  p_out('/R ' || l_r_value);
  p_out('/Length ' || l_key_length);
  p_out('/P ' || g_sec_permissions);
  p_out('/O <' || RAWTOHEX(g_o_value) || '>');
  p_out('/U <' || RAWTOHEX(g_u_value) || '>');
  p_out('>>');
  p_out('endobj');

  log_message(2, 'Encryption dictionary written: V=' || l_v_value || ', R=' || l_r_value);
end p_putencrypt;

----------------------------------------------------------------------------------------
procedure p_endpage is
begin
	-- End of page contents
	state:=1;
end p_endpage;

----------------------------------------------------------------------------------------
procedure p_putpages is
   nb number := page;
   filter varchar2(200);
   -- compressao do fluxo de conteudo
   l_bin blob;
   l_z   blob;
   l_tam pls_integer;
   l_off pls_integer;
   l_in  pls_integer;
   l_out pls_integer;
   l_lang pls_integer;
   l_warn pls_integer;
   annots bigtext;
   rect txt;
   -- l Array2dim;
   -- h number;
   kids txt;
   v_0 varchar2(255);
   v_1 varchar2(255);
   v_2 varchar2(255);
   v_3 varchar2(255);
   v_4 varchar2(255);
   v_0n number;
   v_1n number;
   v_2n number;
   v_3n number;
begin
   -- Garante que todo conteudo acumulado ja esta nos CLOBs das paginas
   p_flush_page_buf;

   -- Replace number of pages
	 if AliasNbPages is not null then
		   for i in 1..nb loop
		      if pages.exists(i) and dbms_lob.getlength(pages(i)) > 0 then
		         declare
		           l_new    clob;
		           l_off    pls_integer := 1;
		           l_size   pls_integer := 8000;   -- chars; <= 32767 bytes em UTF-8
		           l_carry  varchar2(32767);   -- cauda retida: o alias pode cruzar blocos
		           l_keep   pls_integer := nvl(length(AliasNbPages), 0) - 1;
		           l_part   varchar2(32767);
		           l_total  number := dbms_lob.getlength(pages(i));
		           l_emit   varchar2(32767);
		         begin
		           dbms_lob.createtemporary(l_new, true, dbms_lob.session);
		           while l_off <= l_total loop
		             l_part := l_carry || dbms_lob.substr(pages(i), l_size, l_off);
		             l_part := replace(l_part, AliasNbPages, nb);
		             l_off  := l_off + l_size;
		             if l_off <= l_total and l_keep > 0 and length(l_part) > l_keep then
		               -- retem o final que pode conter um alias partido
		               l_carry := substr(l_part, length(l_part) - l_keep + 1);
		               l_emit  := substr(l_part, 1, length(l_part) - l_keep);
		             else
		               l_carry := null;
		               l_emit  := l_part;
		             end if;
		             if l_emit is not null then
		               dbms_lob.writeappend(l_new, length(l_emit), l_emit);
		             end if;
		           end loop;
		           if l_carry is not null then
		             dbms_lob.writeappend(l_new, length(l_carry), l_carry);
		           end if;
		           dbms_lob.freetemporary(pages(i));
		           pages(i) := l_new;
		         end;
		      end if;
		   end loop;
	 end if; 
	 
	 if DefOrientation = 'P' then
		  wPt:=fwPt;
		  hPt:=fhPt;
	 else
		  wPt:=fhPt;
		  hPt:=fwPt;
   end if; 
	 
	 -- o filtro do conteudo e decidido pagina a pagina, mais abaixo: depende
	 -- de a compressao ter compensado naquele fluxo
	 filter := ''; 
	 
   for i in 1..nb loop
		  -- Page
		  p_newobj();
		  p_out('<</Type /Page');
		  p_out('/Parent 1 0 R');
		  if(OrientationChanges.exists(i)) then
			   p_out('/MediaBox [0 0 '||tochar(hPt)||' '||tochar(wPt)||']');
	    end if; 
		  p_out('/Resources 2 0 R');
		
      if(PageLinks.exists(i)) then
			   --Links     [one/page]
			   annots := '/Annots [';
			   --for v in PageLinks(i).first..PageLinks(i).last loop
         v_0 := PageLinks(i).zero;
         v_0n := tonumber(v_0);
         v_1 := PageLinks(i).un;
         v_1n := tonumber(v_1);
         v_2 := PageLinks(i).deux;
         v_2n := tonumber(v_2);
         v_3 := PageLinks(i).trois;
         v_3n := tonumber(v_3);
         v_4 := PageLinks(i).quatre; 
			   rect := tochar(v_0) || ' ' || tochar(v_1) || ' ' || tochar(v_0n + v_2n) 
            || ' ' || tochar(v_1n - v_3n);
			   annots := annots || '<</Type /Annot /Subtype /Link /Rect [' || rect || 
            '] /Border [0 0 0] ';
         if nao_e_numero(PageLinks(i).quatre) then
					  annots := annots ||'/A <</S /URI /URI '||p_textstring(PageLinks(i).quatre) 
               || '>>>>';
             /* ????
				else
					l := links(PageLinks(i).quatre);
					if (OrientationChanges(l.zero) is not null) then
					  h := wPt;
					else
					  h := hPt;
					end if;
					annots := annots || '/Dest ('||tochar(1 + 2 * l.zero,2)||' 0 R /XYZ 0 '||tochar(h - l.un * k)||' null)>>';
                */
         end if;
			   --end loop;
			   p_out(annots || ']');
      end if; 

		  p_out('/Contents ' || to_char(n+1) || ' 0 R>>');
		  p_out('endobj');
		  -- Page content
      --
      -- Com SetCompression(TRUE) o fluxo sai deflatado e em HEXADECIMAL, com
      -- os dois filtros: /ASCIIHexDecode desfaz o hexadecimal e /FlateDecode
      -- descomprime, nessa ordem. O hexadecimal nao e enfeite — o documento e
      -- montado num CLOB e so vira BLOB no fim, com conversao de charset, e
      -- byte binario nao sobrevive a isso (em AL32UTF8 todo valor de 128 a 255
      -- vira DOIS bytes). E a mesma armadilha do CHR(n) ja paga nesta base.
      --
      -- O hexadecimal dobra o tamanho do comprimido, entao a compressao so e
      -- usada quando AINDA ASSIM fica menor que o conteudo cru. Texto de
      -- pagina comprime para uns 5%, e 10% continua sendo dez vezes menor.
	    p_newobj();
      l_tam := 0;
      if b_compress and dbms_lob.getlength(pages(i)) > 0 then
        dbms_lob.createtemporary(l_bin, true);
        dbms_lob.createtemporary(l_z, true);
        l_in := 1; l_out := 1; l_lang := 0; l_warn := 0;
        dbms_lob.convertToBlob(l_bin, pages(i), dbms_lob.getlength(pages(i)),
                               l_in, l_out, dbms_lob.default_csid,
                               l_lang, l_warn);
        PL_FPDF_UTIL.deflate(l_bin, l_z);
        l_tam := dbms_lob.getlength(l_z) * 2 + 1;      -- hexadecimal mais o '>'
        if l_tam >= dbms_lob.getlength(pages(i)) then
          l_tam := 0;                                  -- nao compensou
        end if;
      end if;

      if l_tam > 0 then
        p_out('<</Filter [/ASCIIHexDecode /FlateDecode] /Length '
              || l_tam || '>>');
        p_out('stream');
        l_off := 1;
        while l_off <= dbms_lob.getlength(l_z) loop
          p_out(rawtohex(dbms_lob.substr(l_z, 2000, l_off)), false);
          l_off := l_off + 2000;
        end loop;
        p_out('>');
        p_out('endstream');
      else
	      p_out('<<' || filter || '/Length ' || dbms_lob.getlength(pages(i))
              || '>>');
	      p_putstream_clob(pages(i));
      end if;
      if l_bin is not null then
        dbms_lob.freetemporary(l_bin);
        l_bin := null;
      end if;
      if l_z is not null then
        dbms_lob.freetemporary(l_z);
        l_z := null;
      end if;
	    p_out('endobj');
   end loop;

	 -- Pages root
	 offsets(1):=getPDFDocLength();
	 p_out('1 0 obj');
	 p_out('<</Type /Pages');
	 kids := '/Kids [';
     
      -- Bug dicoverd by Alexandre : arodichevski@newmed.net
	 --for i in 0..nb loop
     for i in 0..nb-1 loop
	    kids := kids || to_char(3+2*i) || ' 0 R ';
	 end loop;

	 p_out( kids || ']');
	 p_out('/Count '|| nb);
	 p_out('/MediaBox [0 0 '||tochar(wPt)||' '||tochar(hPt)||']');
	 p_out('>>');
	 p_out('endobj');
exception
   when others then
      error('p_putpages : '||sqlerrm);
end p_putpages;

----------------------------------------------------------------------------------------
procedure p_enddoc is
o number;
begin

	p_putheader();

	p_putpages();

	p_putresources();

	-- Info
	p_newobj();
	p_out('<<');
	p_putinfo();
	p_out('>>');
	p_out('endobj');

	-- Catalog
	p_newobj();
	p_out('<<');
	p_putcatalog();
	p_out('>>');
	p_out('endobj');

	-- Encryption dictionary (if encryption enabled)
	IF g_encrypt_method IS NOT NULL THEN
	  p_putencrypt();
	END IF;

    -- Cross-ref
	o := getPDFDocLength();
	p_out('xref');
	p_out('0 ' || (n+1));
	p_out('0000000000 65535 f ');

	for i in 1..n
	loop
	  p_out(substr('0000000000', 1, 10 - length(offsets(i)) ) ||offsets(i) || ' 00000 n ');
	end loop;
	-- Trailer
	p_out('trailer');
	p_out('<<');
	p_puttrailer();
	p_out('>>');
	p_out('startxref');
	p_out(o);
	p_out('%%EOF');
	state := 3;

exception
  when others then
    error('p_enddoc : '||sqlerrm);
end p_enddoc;

----------------------------------------------------------------------------------------
procedure p_beginpage(orientation in varchar2) is
Myorientation word := orientation;
begin
	p_flush_page_buf;            -- fecha o acumulador da pagina anterior
	page := page + 1;
	p_ensure_page_clob(page);    -- CLOB temporario da nova pagina
	dbms_lob.trim(pages(page), 0);
	state:=2;
	x:=lMargin;
	y:=tMargin;
	FontFamily:='';
	-- Page orientation
	if(Myorientation is null) then
		Myorientation:=DefOrientation;
	else
	    Myorientation := substr(Myorientation, 1, 1);
		Myorientation:=upper(Myorientation);
		if(Myorientation!=DefOrientation) then
			OrientationChanges(page):=true;
		end if; 
	end if; 
	if(Myorientation!=CurOrientation) then
		-- Change orientation
		if(orientation='P') then
			wPt:=fwPt;
			hPt:=fhPt;
			w:=fw;
			h:=fh;
		else
			wPt:=fhPt;
			hPt:=fwPt;
			w:=fh;
			h:=fw;
		end if; 
		pageBreakTrigger:=h-bMargin;
		CurOrientation:=Myorientation;
	end if; 
exception
  when others then
    error('p_beginpage : '||sqlerrm);
end p_beginpage;

----------------------------------------------------------------------------------------
function p_dounderline(px in number, py in number, ptxt in varchar2) return varchar2 is
up word := CurrentFont.up;
ut word := CurrentFont.ut;
w number := 0;
begin
	w:=GetStringWidth(ptxt) + ws * regexp_count(ptxt, ' ');
	return tochar(px*k,2)||' '||tochar((h-(py-up/1000*fontsize))*k,2)||' '||tochar(w*k,2)||' '||tochar(-ut/1000*fontsizePt,2)||' re f';
exception
  when others then
    error('p_dounderline : '||sqlerrm);
end p_dounderline;

--------------------------------------------------------------------------------
-- Parse an image (Updated for Task 1.6: Native BLOB support)
--------------------------------------------------------------------------------
function p_parseImage(pFile in varchar2) return recImage is
  myImg recImageBlob;  -- Changed from ordsys.ordImage to recImageBlob
  myImgInfo recImage;
  myblob blob;
  chunk_content blob;
  png_signature constant varchar2(8)  := chr(137) || 'PNG' || chr(13) || chr(10) || chr(26) || chr(10);
  signature_len integer := 8;
  chunklength_len integer := 4;
  chunktype_len integer := 4;
  chunkdata_len integer;
  widthheight_len integer := 8;
  hdrflag_len integer := 1;
  crc_len integer := 4;
  chunk_num integer := 0;
  --amount number;
  f number default 1;
  f_chunk number default 1;
  buf varchar2(8192);
  ct word;
  colors pls_integer;
  myType word;
  ---------------------------------------------------------------------------------------------
  function freadb(pBlob in out nocopy blob, pHandle in out number, pLength in out number) return raw is
    l_data_raw  raw(8192);
  begin
    dbms_lob.read(pBlob, pLength, pHandle, l_data_raw);
    pHandle := pHandle + pLength;
    return l_data_raw;
  end freadb;

  function fread(pBlob in out nocopy blob, pHandle in out number, pLength in out number) return varchar2 is
  begin
    return utl_raw.cast_to_varchar2(freadb(pBlob, pHandle, pLength));
  end fread;

  procedure fread_blob(pBlob in out nocopy blob, pHandle in out number,
                       pLength in out number, pDestBlob in out nocopy blob ) is
  begin
    dbms_lob.trim( pDestBlob, 0);
    dbms_lob.copy( pDestBlob, pBlob, pLength, 1, pHandle );
    pHandle := pHandle + pLength;
  end fread_blob;

  ---------------------------------------------------------------------------------------------

begin
  dbms_lob.createtemporary(chunk_content, true );
  dbms_lob.open(chunk_content,dbms_lob.LOB_READWRITE);
  --we use the package level imgBlob variable so the temp blob will persist throughout pdf creation.
  dbms_lob.createtemporary(imgBlob, true );
  myImgInfo.data := imgBlob;
  dbms_lob.open(myImgInfo.data,dbms_lob.LOB_READWRITE);

  -- Fetch and parse image using native BLOB handling
  myImg := getImageFromUrl(pFile);
  myblob := myImg.image_blob;  -- Use BLOB field directly
  myImgInfo.i := 1;
    -- reading the blob

    --Check signature
    if(fread(myblob, f, signature_len) != png_signature ) then
        Error('Not a PNG file: ' || pFile);
    end if;

  -- Use width and height parsed from header
  myImgInfo.w := myImg.width;
  myImgInfo.h := myImg.height;

    -- scan chunks looking for palette, transparency and image data
    loop
    
        chunkdata_len := utl_raw.cast_to_binary_integer(freadb(myblob, f, chunklength_len));
        myType := fread(myblob, f, chunktype_len);
    --read chunk contents into separate blob
    if( chunkdata_len > 0 ) then
      fread_blob(myblob,f,chunkdata_len,chunk_content);
      f_chunk := 1;
    end if;
    chunk_num := chunk_num + 1;
    --discard the crc
    buf := fread(myblob, f, crc_len);
    if( chunk_num = 1 and myType != 'IHDR' ) then
      Error('Incorrect PNG file: ' || pFile);
    elsif(myType = 'IHDR') then
      -- ^^^ I have already get width and height, so go forward (read 4 Bytes twice)
      buf := fread(chunk_content, f_chunk, widthheight_len);

      myImgInfo.bpc := ascii(fread(chunk_content, f_chunk, hdrflag_len));    
      if( myImgInfo.bpc > 8) then
        Error('16-bit depth not supported: ' || pFile);    
      end if;  
      
      ct := ascii(fread(chunk_content, f_chunk, hdrflag_len));    
      if( ct = 0 ) then
        myImgInfo.cs := 'DeviceGray';
      elsif( ct = 2 ) then
        myImgInfo.cs := 'DeviceRGB';
      elsif( ct = 3 ) then
        myImgInfo.cs := 'Indexed';
      else
        Error('Alpha channel not supported: ' || pFile);
        end if;
      if( ascii(fread(chunk_content, f_chunk, hdrflag_len)) != 0 ) then
        Error('Unknown compression method: ' || pFile);
      end if;
      if( ascii(fread(chunk_content, f_chunk, hdrflag_len)) != 0 ) then
        Error('Unknown filter method: ' || pFile);
      end if;
      if( ascii(fread(chunk_content, f_chunk, hdrflag_len)) != 0 ) then
        Error('Interlacing not supported: ' || pFile);
      end if;
      if (ct = 2 ) then
        colors := 3;
      else
        colors := 1;
      end if;
      
      myImgInfo.parms := '/DecodeParms <</Predictor 15 /Colors ' || to_char(colors) || ' /BitsPerComponent ' || myImgInfo.bpc || ' /Columns ' || myImgInfo.w || '>>';
          
        elsif(myType = 'PLTE') then
            -- Read palette
            myImgInfo.pal := fread(chunk_content, f_chunk, chunkdata_len ) ;
        elsif(myType = 'tRNS') then
            --   Read transparency info
            buf := fread(chunk_content, f_chunk, chunkdata_len ) ;
            if(ct = 0) then
                myImgInfo.trns(1) := ascii(substr(buf,1,1));
            elsif( ct = 2) then
               myImgInfo.trns(1) := ascii(substr(buf,1,1));
               myImgInfo.trns(2) := ascii(substr(buf,3,1));
               myImgInfo.trns(3) := ascii(substr(buf,5,1));
            else
                if(instr(buf,chr(0)) > 0) then
                    myImgInfo.trns(1) := instr(buf,chr(0));
                end if;
            end if;
        elsif(myType = 'IDAT') then
            -- Read image data block after the loop, just mark the begin of data
            dbms_lob.append(myImgInfo.data,chunk_content);
        elsif(myType = 'IEND') then
            exit;
        end if;
    end loop;
    
    if( myImgInfo.cs = 'Indexed' and myImgInfo.pal is null) then
        Error('Missing palette in '|| pFile);
    end if;
  myImgInfo.f := 'FlateDecode';
  dbms_lob.close(chunk_content);
  dbms_lob.close(myImgInfo.data);
  dbms_lob.freetemporary(chunk_content);
  return myImgInfo;
exception
  when others then
    Error('p_parseImage : '||SQLERRM);
    return myImgInfo;
end p_parseImage;

/*******************************************************************************
*                                                                              *
*                               Public methods                                 *
*                                                                              *
********************************************************************************/

----------------------------------------------------------------------------------------
-- Methods added to FPDF primary class
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- SetDash Ecrire en pointillés
----------------------------------------------------------------------------------------
procedure SetDash(pblack in number default 0, pwhite in number default 0) is
  s txt;
begin
    if(pblack != 0 or pwhite != 0) then
        s := '['||tochar(pblack*k, 3)||' '||tochar( pwhite*k, 3)||'] 0 d';
    else
        s := '[] 0 d';
	end if;
    p_out(s);
end SetDash;
  
----------------------------------------------------------------------------------------
-- Methods from FPDF primary class
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
procedure Error(pmsg in varchar2) is
  v_clob_content varchar2(32767);
begin
    if gb_mode_debug then
	  print('<pre>');
	  -- Task 1.7: Print CLOB content for debug (up to 32KB)
	  -- flush protegido: aqui ja estamos tratando um erro, nao pode mascara-lo
	  begin
	    p_flush_doc_buf;
	  exception
	    when others then null;
	  end;
	  if pdfDoc is not null and dbms_lob.getlength(pdfDoc) > 0 then
	    v_clob_content := dbms_lob.substr(pdfDoc, 32767, 1);
	    -- '&' seguido de letra e variavel de substituicao no SQL*Plus: um
	    -- script com a entidade HTML literal PARA e pede um valor, e o
	    -- fonte inteiro vira entrada interativa. Partindo a string, o
	    -- texto que sai e o mesmo. Vale para comentario tambem: o
	    -- SQL*Plus varre o arquivo antes de o PL/SQL ver.
	    print(replace(replace(v_clob_content,'>','&' || 'gt;'),
	                  '<','&' || 'lt;'));
	  end if;
	  print('</pre>');
	end if;
	-- Erro fatal.
	--
	-- Ha 60+ handlers 'when others then error(...)' no package. Sem o backtrace,
	-- o erro chegava ao chamador como texto solto, sem a linha de origem; e sem
	-- keeperrorstack a pilha original era descartada. Com os dois, o erro real
	-- (ex.: ORA-06502 numa fonte especifica) continua rastreavel.
	declare
	  l_backtrace varchar2(4000);
	  l_msg       varchar2(2000);
	begin
	  begin
	    l_backtrace := dbms_utility.format_error_backtrace;
	  exception
	    when others then l_backtrace := null;   -- diagnostico nunca mascara o erro
	  end;

	  l_msg := 'PL_FPDF: ' || pmsg;
	  if l_backtrace is not null then
	    l_msg := l_msg || chr(10) || '== origem ==' || chr(10) || l_backtrace;
	  end if;

	  -- 2048 e o limite da mensagem; keeperrorstack preserva a pilha original
	  raise_application_error(-20100, substr(l_msg, 1, 1900), true);
	end;
end Error;

----------------------------------------------------------------------------------------
function GetCurrentFontSize return number is
begin
	-- Get fontsizePt
	return fontsizePt;
end GetCurrentFontSize;

----------------------------------------------------------------------------------------
function GetCurrentFontStyle return varchar2 is
begin
	-- Get fontStyle
	return fontStyle;
end GetCurrentFontStyle;

----------------------------------------------------------------------------------------
function GetCurrentFontFamily return varchar2 is
begin
	-- Get fontStyle
	return FontFamily;
end GetCurrentFontFamily;

----------------------------------------------------------------------------------------
procedure Ln(h number default null) is
begin
	-- Line feed; default value is last cell height
	x :=lMargin;
	if(nao_e_numero(h)) then
		y:= y + lasth;
	else
		y:= y + h;
    end if; 
end Ln;

----------------------------------------------------------------------------------------
function GetX return number is
begin
	-- Get x position
	return x;
end GetX;

----------------------------------------------------------------------------------------
procedure SetX(px in number) is
begin
	-- Set x position
	if(px>=0) then 
		x:=px;
	else
		x:=w+px;
	end if; 
end SetX;

----------------------------------------------------------------------------------------
function GetY return number is
begin
	-- Get y position
	return y;
end GetY;

----------------------------------------------------------------------------------------
procedure SetY(py in number) is 
begin
	-- Set y position and reset x
	x:=lMargin;
	if(py>=0) then
		y:=py;
	else
		y:=h+py;
	end if; 
end SetY;

----------------------------------------------------------------------------------------
procedure SetXY(x in number,y in number) is 
begin
	-- Set x and y positions
	SetY(y);
	SetX(x);
end SetXY;

----------------------------------------------------------------------------------------
-- SetHeaderProc : setting header Callback
----------------------------------------------------------------------------------------
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam) is
begin
   -- Valida agora (erro aparece na configuracao, nao no meio do relatorio) e
   -- monta o bloco uma unica vez, em vez de remonta-lo a cada pagina.
   MyHeader_Proc := p_assert_callback_name(headerprocname);
   MyHeader_ProcParam := paramTable;
   if MyHeader_Proc is not null then
     MyHeader_Stmt := buildPlsqlStatment(MyHeader_Proc, MyHeader_ProcParam);
   else
     MyHeader_Stmt := null;
   end if;
end;

----------------------------------------------------------------------------------------
-- SetFooterProc : setting footer Callback
----------------------------------------------------------------------------------------
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam) is
begin
   MyFooter_Proc := p_assert_callback_name(footerprocname);
   MyFooter_ProcParam := paramTable;
   if MyFooter_Proc is not null then
     MyFooter_Stmt := buildPlsqlStatment(MyFooter_Proc, MyFooter_ProcParam);
   else
     MyFooter_Stmt := null;
   end if;
end;

----------------------------------------------------------------------------------------
procedure SetMargins(left in number, top in number, right in number default -1) is 
myright margin := right;
begin
	-- Set left, top and right margins
	lMargin:=left;
	tMargin:=top;
	if(myright=-1) then
		myright:=left;
	end if; 
	rMargin:=myright;
end SetMargins;

----------------------------------------------------------------------------------------
procedure SetLeftMargin(pMargin in number) is
begin
	-- Set left margin
	lMargin:=pMargin;
	if(page > 0 and  x < pMargin) then
		x:= pMargin;
	end if; 
end SetLeftMargin;

----------------------------------------------------------------------------------------
procedure SetTopMargin(pMargin in number) is
begin
	-- Set top margin
	tMargin := pMargin;
end SetTopMargin;

----------------------------------------------------------------------------------------
procedure SetRightMargin(pMargin in number) is 
begin
	-- Set right margin
	rMargin := pMargin;
end SetRightMargin;

----------------------------------------------------------------------------------------
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0) is  
begin
	-- Set auto page break mode and triggering margin
	AutoPageBreak := pauto;
	bMargin := pMargin;
	pageBreakTrigger:=h-pMargin;
end SetAutoPageBreak;

----------------------------------------------------------------------------------------
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous') is
begin
	-- Set display mode in viewer
	if(zoom in ('fullpage', 'fullwidth', 'real', 'default') or not nao_e_numero(zoom)) then
		ZoomMode:= zoom;
	else
		Error('Incorrect zoom display mode: ' || zoom);
	end if; 
	if(layout in ('single', 'continuous', 'two', 'default')) then
		LayoutMode := layout;
	else
		Error('Incorrect layout display mode: ' || layout);
	end if; 
end SetDisplayMode;

----------------------------------------------------------------------------------------
procedure SetCompression(p_compress in boolean default false) is
begin
	-- Ate agosto/2026 isto era um no-op: perguntava por uma funcao de zlib que
	-- o Oracle nao tem e desligava a compressao sempre. Agora o deflate esta
	-- escrito no proprio package (PL_FPDF_UTIL.deflate), entao a opcao vale.
	b_compress := nvl(p_compress, false);
end SetCompression;

----------------------------------------------------------------------------------------
procedure SetTitle(ptitle in varchar2) is
begin
	-- Title of document
	title:=ptitle;
end SetTitle;

----------------------------------------------------------------------------------------
procedure SetSubject(psubject in varchar2) is
begin
	-- Subject of document
	subject:= psubject;
end SetSubject;

----------------------------------------------------------------------------------------
procedure SetAuthor(pauthor in varchar2) is
begin
	-- Author of document
	author:=pauthor;
end SetAuthor;

----------------------------------------------------------------------------------------
procedure SetKeywords(pkeywords in varchar2) is
begin
	-- Keywords of document
	keywords:=pkeywords;
end SetKeywords;

----------------------------------------------------------------------------------------
procedure SetCreator(pcreator in varchar2) is
begin
	-- Creator of document
	creator:=pcreator;
end SetCreator;

----------------------------------------------------------------------------------------
procedure SetAliasNbPages(palias in varchar2 default '{nb}') is
begin
	-- Define an alias for total number of pages
	AliasNbPages:=palias;
end SetAliasNbPages;

----------------------------------------------------------------------------------------
-- buildPlsqlStatment : building the pl/lsq stmt for header or Footer hooked custom proc
--                      Binding parameters and values.
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- p_assert_callback_name : valida o nome de uma rotina de callback.
--
-- O nome vai concatenado num bloco PL/SQL executado dinamicamente. Cada parte
-- ('esquema', 'pacote', 'procedure') e validada como identificador SQL simples,
-- o que barra espacos, aspas, ';' e qualquer tentativa de injecao. A validacao
-- acontece em SetHeaderProc/SetFooterProc, ou seja, o erro aparece na configuracao
-- e nao no meio da geracao de um relatorio.
----------------------------------------------------------------------------------------
function p_assert_callback_name(p_name in varchar2) return varchar2 is
  l_rest  varchar2(4000) := trim(p_name);
  l_pos   pls_integer;
  l_part  varchar2(4000);
  l_out   varchar2(4000);
begin
  if l_rest is null then
    return null;
  end if;
  loop
    l_pos := instr(l_rest, '.');
    if l_pos = 0 then
      l_part := l_rest;
      l_rest := null;
    else
      l_part := substr(l_rest, 1, l_pos - 1);
      l_rest := substr(l_rest, l_pos + 1);
    end if;
    -- levanta ORA-44003 se nao for um identificador SQL valido
    l_out := l_out || case when l_out is null then '' else '.' end
                   || sys.dbms_assert.simple_sql_name(l_part);
    exit when l_rest is null;
  end loop;
  return l_out;
exception
  when others then
    error('Nome de callback invalido: ' || p_name);
    return null;
end p_assert_callback_name;

----------------------------------------------------------------------------------------
function buildPlsqlStatment(callbackProc in varchar2,
                            tParam in tv4000a default noParam) return varchar2 is
    plsqStmt bigtext;
    paramName word;
begin
    if (tParam.first is not null) then
        -- retrieving values of parameters to build plssql statment.
        plsqStmt := 'Begin '||callbackProc||'(';
        paramName := tParam.first;
        while (paramName is not null) loop
            if (paramName != tParam.first) then
                plsqStmt := plsqStmt || ', ';
            end if;
            -- nome do parametro validado como identificador; valor escapado
            plsqStmt := plsqStmt || sys.dbms_assert.simple_sql_name(paramName) ||'=>'''||
                                    replace(tParam(paramName), '''', '''''')||'''';
            paramName := tParam.next(paramName);
        end loop;
        plsqStmt := plsqStmt||'); end;';
    else
        plsqStmt := 'Begin '||callbackProc||'; end;';
    end if;
    return plsqStmt;
end buildPlsqlStatment;

----------------------------------------------------------------------------------------
-- Header : Procedure that hook the callback procedure for the repetitive header on each page;
----------------------------------------------------------------------------------------
procedure Header is
    plsqStmt bigtext;
begin
	-- MyHeader_Proc defined in Declaration
	if (MyHeader_Stmt is not null) then
        -- bloco ja montado e validado em SetHeaderProc
        plsqStmt := MyHeader_Stmt;
        execute immediate plsqStmt;
	end if; 
exception
    when others then
        error('Header : '||sqlerrm||' statment : '||plsqStmt);
end Header;

----------------------------------------------------------------------------------------
-- Footer : Procedure that hook the callback procedure for the repetitive footer on each page;
----------------------------------------------------------------------------------------
procedure Footer is
    plsqStmt bigtext;
begin
	-- MyFooter_Proc defined in Declaration
	if (MyFooter_Stmt is not null) then
        -- bloco ja montado e validado em SetFooterProc
        plsqStmt := MyFooter_Stmt;
	   execute immediate plsqStmt;
	end if; 
exception
    when others then
        error('Footer : '||sqlerrm||' statment : '||plsqStmt);
end Footer;

----------------------------------------------------------------------------------------
function PageNo return number is 
begin
	-- Get current page number
	return page;
end PageNo;

----------------------------------------------------------------------------------------
procedure SetDrawColor(r in number, g in number default -1, b in number default -1) is
begin
	--------------------------------------------------------------------------------
	-- TASK 2.3: Input Validation
	-- TASK 3.1: Using constants for RGB range
	--------------------------------------------------------------------------------
	-- Validate RGB values (0-255 range)
	if r < c_MIN_COLOR_VALUE or r > c_MAX_COLOR_VALUE then
		raise_application_error(-20501, 'Invalid red value: ' || r || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if g <> -1 and (g < c_MIN_COLOR_VALUE or g > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid green value: ' || g || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if b <> -1 and (b < c_MIN_COLOR_VALUE or b > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid blue value: ' || b || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	-- Set color for all stroking operations
	if((r=0 and g=0 and b=0) or g=-1)  then
		DrawColor:=tochar(r/255,3)||' G';
	else
		DrawColor:=tochar(r/255,3) || ' ' || tochar(g/255,3) || ' ' || tochar(b/255,3) || ' RG';
	end if;
	if(page>0) then
		p_out(DrawColor);
	end if;
end SetDrawColor;

----------------------------------------------------------------------------------------
procedure SetFillColor (r in number, g in number default -1, b in number default -1) is
begin
	--------------------------------------------------------------------------------
	-- TASK 2.3: Input Validation
	-- TASK 3.1: Using constants for RGB range
	--------------------------------------------------------------------------------
	-- Validate RGB values (0-255 range)
	if r < c_MIN_COLOR_VALUE or r > c_MAX_COLOR_VALUE then
		raise_application_error(-20501, 'Invalid red value: ' || r || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if g <> -1 and (g < c_MIN_COLOR_VALUE or g > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid green value: ' || g || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if b <> -1 and (b < c_MIN_COLOR_VALUE or b > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid blue value: ' || b || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	-- Set color for all filling operations
	if((r=0 and g=0 and b=0) or g=-1) then
		FillColor:=tochar(r/255,3) || ' g';
	else
		FillColor:=tochar(r/255,3) ||' '|| tochar(g/255,3) ||' '|| tochar(b/255,3) || ' rg';
	end if;
	if (FillColor!=TextColor) then
	  ColorFlag:=true;
	else
	  ColorFlag:=false;
	end if;
	if(page>0) then
		p_out(FillColor);
	end if;
end SetFillColor;

----------------------------------------------------------------------------------------
procedure SetTextColor (r in number, g in number default -1, b in number default -1) is
begin
	--------------------------------------------------------------------------------
	-- TASK 2.3: Input Validation
	-- TASK 3.1: Using constants for RGB range
	--------------------------------------------------------------------------------
	-- Validate RGB values (0-255 range)
	if r < c_MIN_COLOR_VALUE or r > c_MAX_COLOR_VALUE then
		raise_application_error(-20501, 'Invalid red value: ' || r || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if g <> -1 and (g < c_MIN_COLOR_VALUE or g > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid green value: ' || g || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if b <> -1 and (b < c_MIN_COLOR_VALUE or b > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid blue value: ' || b || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	-- Set color for text
	if((r=0 and g=0 and b=0) or g=-1) then
		TextColor:=tochar(r/255,3) || ' g';
	else
		TextColor:=tochar(r/255,3) ||' '|| tochar(g/255,3) ||' '|| tochar(b/255,3) || ' rg';
	end if;
	if (FillColor!=TextColor) then
	  ColorFlag:=true;
	else
	  ColorFlag:=false;
	end if;
end SetTextColor;

----------------------------------------------------------------------------------------
procedure SetLineWidth(width in number) is
begin
	--------------------------------------------------------------------------------
	-- TASK 2.3: Input Validation
	--------------------------------------------------------------------------------
	-- Validate line width (must be positive)
	if width <= 0 then
		raise_application_error(-20502, 'Invalid line width: ' || width || '. Must be positive');
	end if;

	-- Set line width
	LineWidth:=width;
	if(page>0) then
		p_out(tochar(width*k,2) ||' w');
	end if;
end SetLineWidth;

----------------------------------------------------------------------------------------
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number) is 
begin
	-- Draw a line
	p_out( tochar(x1*k,2) || 
		   ' ' || tochar((h-y1)*k,2) || 
		   ' m ' || tochar(x2*k,2) || 
		   ' ' || tochar((h-y2)*k,2) || ' l S');
end Line;

----------------------------------------------------------------------------------------
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '') is
op word;
begin
	-- Draw a rectangle
	if(pstyle='F') then
		op:='f';
	elsif(pstyle='FD' or pstyle='DF') then
		op:='B';
	else
		op:='S';
	end if; 
	p_out(tochar(px*k,2) || ' ' || tochar((h-py)*k,2) || ' ' || tochar(pw*k,2) || ' ' || tochar(-ph*k,2) || ' re ' || op);
end Rect;

----------------------------------------------------------------------------------------
-- Triangulo isosceles: base 2*psize, altura psize, com a ponta apontando para
-- porientation. (px, py) e o canto superior esquerdo da caixa que o envolve.
--
-- O porientation era ACEITO E IGNORADO: qualquer valor desenhava a mesma forma,
-- com a ponta para a direita. A spec ja prometia as quatro direcoes, entao quem
-- passasse 'up' recebia um triangulo apontando para a direita, sem erro nenhum.
-- Aceita a palavra inteira ou a inicial, em qualquer caixa.
procedure Triangle(px in number, py in number, psize in number,
                   porientation in varchar2 default 'left', pstyle varchar2 default '') is
point_1 point;
point_2 point;
point_3 point;
points tab_points;
myOri varchar2(10) := lower(nvl(porientation, 'left'));
begin
    if(myOri in ('r', 'right')) then
        point_1.x := px;              point_1.y := py;
        point_2.x := px + psize;      point_2.y := py + psize;
        point_3.x := px;              point_3.y := py + 2 * psize;
    elsif(myOri in ('l', 'left')) then
        point_1.x := px + psize;      point_1.y := py;
        point_2.x := px;              point_2.y := py + psize;
        point_3.x := px + psize;      point_3.y := py + 2 * psize;
    elsif(myOri in ('d', 'down')) then
        point_1.x := px;              point_1.y := py;
        point_2.x := px + 2 * psize;  point_2.y := py;
        point_3.x := px + psize;      point_3.y := py + psize;
    elsif(myOri in ('u', 'up')) then
        point_1.x := px;              point_1.y := py + psize;
        point_2.x := px + 2 * psize;  point_2.y := py + psize;
        point_3.x := px + psize;      point_3.y := py;
    else
        raise_application_error(-20821,
          'Triangle: orientacao ' || porientation || ' invalida. Use '
          || '''up'', ''down'', ''left'' ou ''right'' (ou U, D, L, R)');
    end if;

    points(0) := point_1;
    points(1) := point_2;
    points(2) := point_3;

    Poly(points, true, pstyle);
end;

----------------------------------------------------------------------------------------
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '') is
op word;
pdf_cmd varchar2(1000);
begin
	if(pstyle='F') then
		op:='f';
	elsif(pstyle='FD' or pstyle='DF') then
		op:='B';
	else
		op:='S';
	end if;
    
    pdf_cmd := tochar(points(0).x *k, 2) || ' ' || tochar((h - points(0).y) *k, 2) || ' m' || CHR(10);
    
    for i in 1..points.last loop
        pdf_cmd := pdf_cmd || tochar(points(i).x*k, 2) || ' ' || tochar((h - points(i).y) * k, 2) || ' l' || CHR(10);
    end loop;
    
    if(pclose) then
        pdf_cmd := pdf_cmd || ' h' || CHR(10);
    end if;
    
    pdf_cmd := pdf_cmd || ' ' || op || CHR(10);
    
    --htp.p(pdf_cmd);
    p_out(pdf_cmd);
end;

----------------------------------------------------------------------------------------
procedure SetLineDashPattern(pdash in varchar2 default '[] 0') is
begin
    p_out(pdash || ' d');
end;

----------------------------------------------------------------------------------------
function AddLink return number is
nb_link number := links.count + 1;
begin
	-- Create a new internal link
	links(nb_link).zero := 0;
	links(nb_link).un := 0;
	return nb_link;
end AddLink;

----------------------------------------------------------------------------------------
procedure SetLink(plink in number, py in number default 0, ppage in number default -1) is
mypy number := py;
myppage number := ppage;
begin
	-- Set destination of internal link
	if(mypy=-1) then
		mypy:=y;
	end if; 
	if(myppage=-1) then
		myppage:=page;
	end if; 
	links(plink).zero:=myppage;
	links(plink).un:=mypy;
end SetLink;

----------------------------------------------------------------------------------------
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2) is
  v_last_plink integer;
  v_ntoextend integer;
  v_rec rec5;
begin
	-- Put a link on the page
  -- Init PageLinks, if not exists
  begin
     v_last_plink := PageLinks.count;
  exception
     when others then
        PageLinks := linksArray(v_rec);
  end;
  -- extend, so PageLinks(page) exists
  v_last_plink := PageLinks.last;
  v_ntoextend := page-v_last_plink;
  if v_ntoextend > 0 then
     PageLinks.extend(v_ntoextend);
  end if;
  -- set values
	PageLinks(page).zero:=px*k;
	PageLinks(page).un:=hPt-py*k;
	PageLinks(page).deux:=pw*k;
	PageLinks(page).trois:=ph*k;
	PageLinks(page).quatre:=plink;
end Link;

----------------------------------------------------------------------------------------
procedure Text(px in number, py in number, ptxt in varchar2) is
s varchar2(2000);
begin
	-- Output a string
	s:='BT '|| tochar(px*k,2) ||' '|| tochar((h-py)*k,2) ||' Td ('||p_escapa_pdf(ptxt)||') Tj ET';
	if(underline and ptxt is not null) then
		s := s || ' ' || p_dounderline(px,py,ptxt);
	end if; 
	if(ColorFlag) then
		s := 'q '|| TextColor ||' ' || s || ' Q';
	end if; 
	p_out(s);
end Text;

----------------------------------------------------------------------------------------
function AcceptPageBreak return boolean is
begin
	-- Accept automatic page break or not
	return AutoPageBreak;
end AcceptPageBreak;

----------------------------------------------------------------------------------------
procedure OpenPDF is
begin
	-- Begin document
	state:=1;
end OpenPDF;

----------------------------------------------------------------------------------------
procedure ClosePDF is
begin

	-- Terminate document
	if(state=3) then
		return;
	end if; 
    
	if(page=0) then
		AddPage();
	end if; 
    
	-- Page footer
	InFooter:=true;
	Footer();
	InFooter:=false;
    
	-- Close page
	p_endpage();
    
	-- Close document
	p_enddoc();
    
end ClosePDF;

----------------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Internal legacy AddPage implementation (renamed to avoid overload ambiguity)
-- This is called by the modern AddPage() which is the public API
--------------------------------------------------------------------------------
procedure p_addpage_internal(orientation in varchar2 default '') is
myFamily txt;
myStyle txt;
mySize number := fontsizePt;
lw phrase := LineWidth;
dc phrase := DrawColor;
fc phrase := FillColor;
tc phrase := TextColor;
cf flag := ColorFlag;

begin
	-- Start a new page
	if(state=0) then
		OpenPDF();
	end if;
	myFamily:= FontFamily;
	if (underline) then
	   myStyle := FontStyle || 'U';
	end if;
	if(page>0) then
		-- Page footer
		InFooter:=true;
		Footer();
		InFooter:=false;
		-- Close page
		p_endpage();
	end if;
	-- Start new page
	p_beginpage(orientation);
	-- Set line cap style to square
	p_out('2 J');
	-- Set line width
	LineWidth:=lw;
	p_out(tochar(lw*k)||' w');
	-- Set font
	if(myFamily is not null) then
		SetFont(myFamily,myStyle,mySize);
	end if;
	-- Set colors
	DrawColor:=dc;
	if(dc!='0 G') then
		p_out(dc);
	end if;
	FillColor:=fc;
	if(fc!='0 g') then
		p_out(fc);
	end if;
	TextColor:= tc;
	ColorFlag:= cf;
	-- Page header
	header();
	-- Restore line width
	if(LineWidth!=lw) then
		LineWidth:=lw;
		p_out(tochar(lw*k)||' w');
	end if;
	-- Restore font

	if myFamily is null then
		SetFont(myFamily,myStyle,mySize);
	end if;
	-- Restore colors
	if(DrawColor!=dc) then
		DrawColor:=dc;
		p_out(dc);
	end if;
	if(FillColor!=fc) then
		FillColor:=fc;
		p_out(fc);
	end if;
	TextColor:=tc;
	ColorFlag:=cf;
end p_addpage_internal;

----------------------------------------------------------------------------------------
procedure update_line_spacing is
begin
	Linespacing := (fontsizePt / k);	-- minimum line spacing in multicell
end;

--------------------------------------------------------------------------------
-- Date: 2025-12-15
--------------------------------------------------------------------------------
/*******************************************************************************
* Procedure: Init
* Description: Modern initialization with validation and UTF-8 support
*******************************************************************************/
procedure Init(
  p_orientation varchar2 default 'P',
  p_unit varchar2 default 'mm',
  p_format varchar2 default 'A4',
  p_encoding varchar2 default 'UTF-8'
) is
  l_orientation varchar2(1);
  l_unit varchar2(10);
  l_format varchar2(20);
begin
  log_message(3, 'Initializing PL_FPDF v2.0...');

  -- ========================================================================
  -- 1. VALIDATE PARAMETERS
  -- ========================================================================

  -- Validate orientation (handle NULL by using default)
  l_orientation := upper(substr(nvl(p_orientation, 'P'), 1, 1));
  if l_orientation not in ('P', 'L') then
    raise_application_error(
      -20001,
      'Invalid orientation: ' || p_orientation || '. Must be P or L.'
    );
  end if;

  -- Validate unit (validate BEFORE assignment to avoid buffer overflow, handle NULL)
  if lower(nvl(p_unit, 'mm')) not in ('mm', 'cm', 'in', 'pt') then
    raise_application_error(
      -20002,
      'Invalid unit: ' || p_unit || '. Must be mm, cm, in, or pt.'
    );
  end if;
  l_unit := lower(nvl(p_unit, 'mm'));

  -- Validate encoding (handle NULL by using default)
  if upper(nvl(p_encoding, 'UTF-8')) not in ('UTF-8', 'UTF8', 'AL32UTF8', 'ISO-8859-1', 'WINDOWS-1252') then
    raise_application_error(
      -20003,
      'Unsupported encoding: ' || p_encoding
    );
  end if;

  -- ========================================================================
  -- 2. RESET IF ALREADY INITIALIZED (re-initialization)
  -- ========================================================================

  if g_initialized then
    log_message(3, 'Re-initializing - resetting existing state...');
    Reset();
  end if;

  -- ========================================================================
  -- 3. SET DEFAULT ORIENTATION AND FORMAT (Task 1.2)
  -- ========================================================================

  g_default_orientation := l_orientation;
  g_default_format := get_page_format(upper(nvl(p_format, 'A4')));
  log_message(4, 'Defaults: orientation=' || g_default_orientation ||
    ', format=' || upper(nvl(p_format, 'A4')) || ' (' ||
    g_default_format.width || 'x' || g_default_format.height || 'mm)');

  -- ========================================================================
  -- 4. SET ENCODING
  -- ========================================================================

  g_encoding := upper(nvl(p_encoding, 'UTF-8'));
  log_message(4, 'Encoding set to: ' || g_encoding);

  -- ========================================================================
  -- 5. CONFIGURE SESSION FOR UTF-8 (best effort)
  -- ========================================================================

  -- A sessao do chamador nao e mais alterada: tochar/tonumber convertem com NLS
  -- explicito (co_nls_num), o que torna a saida independente da configuracao.
  log_message(4, 'Numeric conversion uses explicit NLS (session untouched)');

  -- ========================================================================
  -- 6. CALL LEGACY fpdf() CONSTRUCTOR
  --    (maintains compatibility with existing code)
  -- ========================================================================

  l_format := upper(p_format);
  fpdf(l_orientation, l_unit, l_format);

  -- ========================================================================
  -- 7. MARK AS INITIALIZED
  -- ========================================================================

  g_initialized := true;

  log_message(3,
    'PL_FPDF initialized successfully: ' ||
    'orientation=' || l_orientation ||
    ', unit=' || l_unit ||
    ', format=' || l_format ||
    ', encoding=' || g_encoding
  );

exception
  when others then
    g_initialized := false;
    log_message(1, 'Initialization failed: ' || sqlerrm);
    raise;
end Init;

/*******************************************************************************
* Procedure: Reset
* Description: Resets the PDF engine, freeing resources
*******************************************************************************/
procedure Reset is
begin
  log_message(3, 'Resetting PL_FPDF engine...');

  -- Clear arrays and CLOB (using existing structures)
  begin
    -- Task 1.7: Free CLOB buffer
    if dbms_lob.istemporary(pdfDoc) = 1 then
      dbms_lob.freetemporary(pdfDoc);
    end if;

    p_free_pages;   -- libera CLOBs temporarios e descarta a colecao
    fonts.delete;
    FontFiles.delete;
    images.delete;
    if PageLinks is not null then
      PageLinks.delete;
    end if;
    if links is not null then
      links.delete;
    end if;
  exception
    when others then
      log_message(2, 'Warning during cleanup: ' || sqlerrm);
  end;

  -- Reset state variables
  g_initialized := false;
  state := 0;
  page := 0;
  n := 2;

  -- Callbacks de header/rodape: sem isso um callback configurado sobrevivia ao
  -- Reset (e ao Init, que chama Reset), e um nome invalido deixava a sessao
  -- inutilizavel — todo AddPage seguinte falhava ao executar o bloco dinamico.
  MyHeader_Proc := NULL;
  MyHeader_Stmt := NULL;
  MyHeader_ProcParam.delete;
  MyFooter_Proc := NULL;
  MyFooter_Stmt := NULL;
  MyFooter_ProcParam.delete;

  -- Reset encryption variables
  g_encrypt_method := NULL;
  g_user_password := NULL;
  g_owner_password := NULL;
  g_sec_permissions := -1;
  g_encrypt_obj_num := NULL;
  g_file_id := NULL;
  g_o_value := NULL;
  g_u_value := NULL;
  g_encryption_key := NULL;

  -- Metadados do documento.
  --
  -- Ficavam de fora, e o package tem estado de SESSAO: o /Keywords de um
  -- documento reaparecia em TODOS os seguintes, ate a sessao morrer. Nao e
  -- so inchaco — e metadado de um PDF vazando para outro, que num sistema
  -- que gera documento de clientes diferentes na mesma sessao e pior que
  -- desperdicio.
  --
  -- Apareceu com um SetKeywords de 32.000 caracteres num teste: dali em
  -- diante todo PDF da rodada nasceu com 32 KB a mais, e a cifragem passou a
  -- recusar todos eles, porque o literal do /Info estourava o teto do escape.
  -- O sintoma nao apontava para ca em momento nenhum.
  title    := NULL;
  subject  := NULL;
  author   := NULL;
  keywords := NULL;
  creator  := NULL;

  log_message(3, 'PL_FPDF reset complete');

exception
  when others then
    log_message(1, 'Error during reset: ' || sqlerrm);
    raise;
end Reset;

/*******************************************************************************
* Function: IsInitialized
* Description: Checks initialization state
*******************************************************************************/
function IsInitialized return boolean is
begin
  return g_initialized;
end IsInitialized;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-15
--------------------------------------------------------------------------------
-- NOTE: init_page_formats() and get_page_format() have been moved earlier
--       in the file (after log_message) so they can be called by Init()

/*******************************************************************************
* Function: GetCurrentPage
* Description: Returns the current page number
*******************************************************************************/
function GetCurrentPage return pls_integer is
begin
  return g_current_page;
end GetCurrentPage;

/*******************************************************************************
* Procedure: SetPage
* Description: Sets the current active page for content manipulation
*******************************************************************************/
procedure SetPage(p_page_number pls_integer) is
begin
  -- Validate initialization
  if not g_initialized then
    raise_application_error(-20005,
      'PL_FPDF not initialized. Call Init() first.');
  end if;

  -- Validate page exists
  if not g_pages.exists(p_page_number) then
    raise_application_error(-20106,
      'Page ' || p_page_number || ' does not exist. Total pages: ' || g_current_page);
  end if;

  -- Close current page if different
  if g_current_page > 0 and g_current_page != p_page_number then
    -- Note: p_endpage() will be called by legacy code if needed
    null;
  end if;

  -- Switch to specified page
  g_current_page := p_page_number;
  page := p_page_number;  -- Update legacy variable for compatibility

  -- Update global dimensions to match this page
  w := g_pages(p_page_number).format.width;
  h := g_pages(p_page_number).format.height;

  log_message(4, 'Switched to page ' || p_page_number ||
    ' (' || w || 'x' || h || 'mm)');

exception
  when others then
    log_message(1, 'Error in SetPage: ' || sqlerrm);
    raise;
end SetPage;

/*******************************************************************************
* Procedure: AddPage (Modern version with BLOB streaming)
* Description: Adds a new page with specified orientation, format, and rotation.
*              This is the modernized version declared in the package spec.
*              Calls the legacy AddPage internally for compatibility.
*******************************************************************************/
procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
) is
  l_orientation varchar2(1);
  l_format recPageFormat;
begin
  -- Validate initialization
  if not g_initialized then
    raise_application_error(-20005,
      'PL_FPDF not initialized. Call Init() first.');
  end if;

  -- Determine orientation
  if p_orientation is null then
    l_orientation := g_default_orientation;  -- Use default from Init
  else
    l_orientation := upper(substr(p_orientation, 1, 1));
    if l_orientation not in ('P', 'L') then
      raise_application_error(-20107,
        'Invalid orientation: ' || p_orientation || '. Use P (Portrait) or L (Landscape)');
    end if;
  end if;

  -- Get page format
  if p_format is not null then
    -- Check for custom format (e.g., "100,200" or "100x200")
    -- Try to parse as custom format if it contains separators
    if instr(p_format, ',') > 0 or instr(p_format, 'x') > 0 or instr(p_format, 'X') > 0 then
      -- Attempt to parse custom format: "width,height" or "widthxheight"
      declare
        l_separator varchar2(1);
        l_pos pls_integer;
        l_width varchar2(20);
        l_height varchar2(20);
        l_is_custom boolean := false;
      begin
        -- Determine separator
        if instr(p_format, ',') > 0 then
          l_separator := ',';
          l_pos := instr(p_format, ',');
        elsif instr(p_format, 'x') > 0 then
          l_separator := 'x';
          l_pos := instr(p_format, 'x');
        else
          l_separator := 'X';
          l_pos := instr(p_format, 'X');
        end if;

        -- Extract width and height
        l_width := trim(substr(p_format, 1, l_pos - 1));
        l_height := trim(substr(p_format, l_pos + 1));

        -- Try to convert to numbers
        begin
          l_format.width := to_number(l_width);
          l_format.height := to_number(l_height);

          -- Validate dimensions
          if l_format.width <= 0 or l_format.height <= 0 then
            raise_application_error(-20101,
              'Invalid custom format dimensions: ' || p_format || '. Width and height must be positive.');
          end if;

          l_is_custom := true;
          log_message(4, 'Custom page format: ' || l_format.width || 'x' || l_format.height || 'mm');

        exception
          when value_error then
            -- Not a valid custom format, try as named format
            l_is_custom := false;
        end;

        -- If not parsed as custom, try named format lookup
        if not l_is_custom then
          l_format := get_page_format(p_format);
        end if;
      end;
    else
      -- Named format (A4, Letter, etc.)
      l_format := get_page_format(p_format);
    end if;
  else
    l_format := g_default_format;  -- Use default from Init
  end if;

  -- Validate rotation
  if p_rotation not in (0, 90, 180, 270) then
    raise_application_error(-20104,
      'Invalid rotation: ' || p_rotation || '. Must be 0, 90, 180, or 270 degrees.');
  end if;

  -- Call internal legacy AddPage implementation for actual page setup
  -- This will increment the legacy 'page' variable
  p_addpage_internal(l_orientation);

  -- Sync modern page counter with legacy
  g_current_page := page;

  -- Store page metadata AFTER page creation
  g_pages(g_current_page).number_val := g_current_page;
  g_pages(g_current_page).orientation := l_orientation;
  g_pages(g_current_page).format := l_format;
  g_pages(g_current_page).rotation := p_rotation;

  dbms_lob.createtemporary(g_pages(g_current_page).content_clob, true, dbms_lob.session);

  log_message(4, 'AddPage (modern): page ' || g_current_page ||
    ', orientation=' || l_orientation || ', format=' || p_format ||
    ', rotation=' || p_rotation);

exception
  when others then
    log_message(1, 'Error in AddPage (modern): ' || sqlerrm);
    raise;
end AddPage;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-15
--------------------------------------------------------------------------------

/*******************************************************************************
* Function: parse_ttf_header (Internal)
* Description: Parses TTF/OTF header and extracts basic metrics
*******************************************************************************/
function parse_ttf_header(p_font_blob blob, p_font_name varchar2) return recTTFFont is
  l_font recTTFFont;
  l_magic_number raw(4);
  l_valid_ttf boolean := false;
  c_ttf_magic constant raw(4) := hextoraw('00010000');
  c_otf_magic constant raw(4) := hextoraw('4F54544F');
  c_ttc_magic constant raw(4) := hextoraw('74746366');
begin
  if p_font_blob is null or dbms_lob.getlength(p_font_blob) < 12 then
    raise_application_error(-20202, 'Invalid font BLOB: NULL or too small (<12 bytes)');
  end if;
  l_magic_number := dbms_lob.substr(p_font_blob, 4, 1);
  if l_magic_number = c_ttf_magic then
    l_valid_ttf := true;
    log_message(4, 'Detected TrueType font (version 1.0)');
  elsif l_magic_number = c_otf_magic then
    l_valid_ttf := true;
    log_message(4, 'Detected OpenType font with CFF outlines');
  elsif l_magic_number = c_ttc_magic then
    raise_application_error(-20202, 'TrueType Collections (.ttc) not yet supported');
  else
    raise_application_error(-20202, 'Invalid TTF/OTF magic number: ' || rawtohex(l_magic_number));
  end if;
  l_font.font_name := upper(p_font_name);
  l_font.font_blob := p_font_blob;
  l_font.encoding := 'UTF-8';
  l_font.units_per_em := 1000;
  l_font.ascent := 800;
  l_font.descent := -200;
  l_font.line_gap := 0;
  l_font.cap_height := 700;
  l_font.x_height := 500;
  l_font.is_bold := false;
  l_font.is_italic := false;
  l_font.is_embedded := true;
  l_font.loaded_at := systimestamp;
  log_message(4, 'TTF header parsed for font: ' || p_font_name || ', size: ' || dbms_lob.getlength(p_font_blob) || ' bytes');
  return l_font;
exception
  when others then
    log_message(1, 'Error parsing TTF header for ' || p_font_name || ': ' || sqlerrm);
    raise_application_error(-20202, 'Error parsing TTF header: ' || sqlerrm);
end parse_ttf_header;

function IsTTFFontLoaded(p_font_name varchar2) return boolean is
  l_font_name_upper varchar2(100) := upper(p_font_name);
begin
  return g_ttf_fonts.exists(l_font_name_upper);
exception
  when others then
    log_message(1, 'Error in IsTTFFontLoaded: ' || sqlerrm);
    return false;
end IsTTFFontLoaded;

procedure AddTTFFont(p_font_name varchar2, p_font_blob blob, p_encoding varchar2 default 'UTF-8', p_embed boolean default true) is
  l_font recTTFFont;
  l_font_name_upper varchar2(100);
begin
  if p_font_name is null or length(trim(p_font_name)) = 0 then
    raise_application_error(-20210, 'Font name cannot be NULL or empty');
  end if;
  if p_font_blob is null then
    raise_application_error(-20211, 'Font BLOB cannot be NULL');
  end if;
  l_font_name_upper := upper(trim(p_font_name));
  if IsTTFFontLoaded(l_font_name_upper) then
    log_message(2, 'WARNING: Font ' || l_font_name_upper || ' already loaded. Replacing with new version.');
  end if;
  log_message(3, 'Loading TrueType font: ' || l_font_name_upper || ', size: ' || dbms_lob.getlength(p_font_blob) || ' bytes');
  l_font := parse_ttf_header(p_font_blob, l_font_name_upper);
  if p_encoding is not null then
    l_font.encoding := upper(p_encoding);
  end if;
  l_font.is_embedded := p_embed;
  g_ttf_fonts(l_font_name_upper) := l_font;
  g_ttf_fonts_count := g_ttf_fonts.count;
  log_message(3, 'TrueType font loaded successfully: ' || l_font_name_upper || ', encoding: ' || l_font.encoding || ', embedded: ' || case when p_embed then 'YES' else 'NO' end);
exception
  when others then
    log_message(1, 'Error in AddTTFFont for ' || p_font_name || ': ' || sqlerrm);
    raise;
end AddTTFFont;

procedure LoadTTFFromFile(p_font_name varchar2, p_file_path varchar2, p_directory varchar2 default 'FONTS_DIR', p_encoding varchar2 default 'UTF-8') is
  l_font_blob blob;
  l_file utl_file.file_type;
  l_buffer raw(32767);
  l_amount pls_integer := 32767;
  l_file_exists boolean;
  l_file_length number;
  l_block_size number;
begin
  log_message(3, 'Loading TTF from file: ' || p_file_path || ' in directory: ' || p_directory);
  begin
    utl_file.fgetattr(p_directory, p_file_path, l_file_exists, l_file_length, l_block_size);
    if not l_file_exists then
      raise_application_error(-20202, 'File not found: ' || p_file_path || ' in directory ' || p_directory);
    end if;
    log_message(4, 'File found: ' || p_file_path || ', size: ' || l_file_length || ' bytes');
  exception
    when others then
      if sqlcode = -29280 then
        raise_application_error(-20401, 'Invalid or non-existent directory: ' || p_directory);
      elsif sqlcode = -29283 then
        raise_application_error(-20402, 'Permission denied accessing: ' || p_directory);
      else
        raise;
      end if;
  end;
  dbms_lob.createtemporary(l_font_blob, true, dbms_lob.session);
  begin
    l_file := utl_file.fopen(p_directory, p_file_path, 'rb', 32767);
    loop
      begin
        utl_file.get_raw(l_file, l_buffer, l_amount);
        dbms_lob.writeappend(l_font_blob, utl_raw.length(l_buffer), l_buffer);
      exception
        when no_data_found then
          exit;
      end;
    end loop;
    utl_file.fclose(l_file);
    log_message(4, 'File read successfully: ' || dbms_lob.getlength(l_font_blob) || ' bytes');
  exception
    when others then
      if utl_file.is_open(l_file) then
        utl_file.fclose(l_file);
      end if;
      if dbms_lob.istemporary(l_font_blob) = 1 then
        dbms_lob.freetemporary(l_font_blob);
      end if;
      log_message(1, 'Error reading file: ' || sqlerrm);
      raise;
  end;
  AddTTFFont(p_font_name, l_font_blob, p_encoding, true);
  log_message(3, 'TrueType font loaded from file: ' || p_file_path);
exception
  when others then
    log_message(1, 'Error in LoadTTFFromFile: ' || sqlerrm);
    raise;
end LoadTTFFromFile;

function GetTTFFontInfo(p_font_name varchar2) return recTTFFont is
  l_font_name_upper varchar2(100) := upper(trim(p_font_name));
begin
  if not g_ttf_fonts.exists(l_font_name_upper) then
    raise_application_error(-20206, 'Font not found: ' || p_font_name || '. Call AddTTFFont() or LoadTTFFromFile() first.');
  end if;
  return g_ttf_fonts(l_font_name_upper);
exception
  when others then
    log_message(1, 'Error in GetTTFFontInfo: ' || sqlerrm);
    raise;
end GetTTFFontInfo;

procedure ClearTTFFontCache is
  l_font_name varchar2(100);
begin
  log_message(3, 'Clearing TTF font cache (' || g_ttf_fonts_count || ' fonts)');
  l_font_name := g_ttf_fonts.first;
  while l_font_name is not null loop
    if dbms_lob.istemporary(g_ttf_fonts(l_font_name).font_blob) = 1 then
      dbms_lob.freetemporary(g_ttf_fonts(l_font_name).font_blob);
    end if;
    l_font_name := g_ttf_fonts.next(l_font_name);
  end loop;
  g_ttf_fonts.delete;
  g_ttf_fonts_count := 0;
  log_message(3, 'TTF font cache cleared');
exception
  when others then
    log_message(1, 'Error in ClearTTFFontCache: ' || sqlerrm);
    raise;
end ClearTTFFontCache;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-17
--------------------------------------------------------------------------------

/*******************************************************************************
* Function: UTF8ToPDFString
* Description: Converts UTF-8 text to PDF-compatible string format
*******************************************************************************/
function UTF8ToPDFString(p_text varchar2, p_escape boolean default true) return varchar2 is
  l_result varchar2(32767);
begin
  if p_text is null then
    return null;
  end if;

  -- UTF-8 encoding (Oracle VARCHAR2 stores in database charset, typically AL32UTF8)
  -- For PDF output: standard fonts use internal handling, TTF fonts use Unicode encoding
  l_result := p_text;

  -- Escape PDF special characters if requested: \, (, )
  if p_escape then
    l_result := p_escapa_pdf(l_result);
  end if;

  -- Note: Full Unicode support with glyph mapping requires TTF font embedding
  -- This basic implementation allows UTF-8 text to flow through to PDF
  -- Advanced features (CMAP tables, glyph substitution) in Phase 3

  return l_result;

exception
  when others then
    log_message(1, 'Error in UTF8ToPDFString: ' || sqlerrm);
    -- Fallback: return text with basic escaping
    if p_escape then
      return p_escapa_pdf(p_text);
    else
      return p_text;
    end if;
end UTF8ToPDFString;

/*******************************************************************************
* Function: IsUTF8Enabled
*******************************************************************************/
function IsUTF8Enabled return boolean is
begin
  return g_utf8_enabled;
end IsUTF8Enabled;

/*******************************************************************************
* Procedure: SetUTF8Enabled
*******************************************************************************/
procedure SetUTF8Enabled(p_enabled boolean default true) is
begin
  log_message(3, 'Setting UTF-8 encoding to: ' || case when p_enabled then 'ENABLED' else 'DISABLED' end);
  g_utf8_enabled := p_enabled;
end SetUTF8Enabled;

--------------------------------------------------------------------------------
-- End of TASK 2.1 implementations
--------------------------------------------------------------------------------

----------------------------------------------------------------------------------------
procedure fpdf
  (orientation varchar2 default 'P',
   unit varchar2 default 'mm',
   format varchar2 default 'A4') is
   myorientation word := orientation;
   myformat word := format;
   mymargin margin;
begin
	-- Some checks
	p_dochecks();
	-- Initialization of properties
	page:=0;
	n:=2;
	-- Open the final structure for the PDF document.
  -- Task 1.7: Initialize CLOB buffer instead of VARCHAR2 array
  if dbms_lob.istemporary(pdfDoc) = 1 then
    dbms_lob.freetemporary(pdfDoc);
  end if;
  dbms_lob.createtemporary(pdfDoc, true, dbms_lob.session);
  p_free_pages;   -- libera CLOBs de paginas de um documento anterior
	state:=0;
	InFooter:=false;
	lasth:=0;
	--FontFamily:='';
	FontFamily:='helvetica';
	fontstyle:='';
	fontsizePt:=12;
	underline:=false;
	DrawColor:='0 G';
	FillColor:='0 g';
	TextColor:='0 g';
	ColorFlag:=false;
	ws:=0;

	-- Standard fonts
	CoreFonts('courier') := 'Courier';
	CoreFonts('courierB') := 'Courier-Bold';
	CoreFonts('courierI') := 'Courier-Oblique';
	CoreFonts('courierBI') := 'Courier-BoldOblique';
	CoreFonts('helvetica') := 'Helvetica';
	CoreFonts('helveticaB') := 'Helvetica-Bold';
	CoreFonts('helveticaI') := 'Helvetica-Oblique';
	CoreFonts('helveticaBI') := 'Helvetica-BoldOblique';
	CoreFonts('times') := 'Times-Roman';
	CoreFonts('timesB') := 'Times-Bold';
	CoreFonts('timesI') := 'Times-Italic';
	CoreFonts('timesBI') := 'Times-BoldItalic';
	CoreFonts('symbol') := 'Symbol';
	CoreFonts('zapfdingbats') := 'ZapfDingbats';
	
	-- Scale factor 
	if(unit='pt') then
		k:=1;
	elsif(unit='mm') then
		k:=72/25.4;
	elsif(unit='cm') then
		k:=72/2.54;
	elsif(unit='in') then
		k:=72;
	else
		Error('Incorrect unit: ' || unit);
	end if; 
	
	-- Others added properties
    update_line_spacing;
	
	-- Page format
	if(nao_e_numero(myformat)) then
		myformat:=lower(myformat);
		if(myformat='a3') then
			formatArray.largeur := 841.89;
			formatArray.hauteur := 1190.55;
		elsif(myformat='a4') then
			formatArray.largeur := 595.28;
			formatArray.hauteur := 841.89;
		elsif(myformat='a5') then
			formatArray.largeur := 420.94;
			formatArray.hauteur := 595.28;
		elsif(myformat='letter') then
			formatArray.largeur := 612;
			formatArray.hauteur := 792;
		elsif(myformat='legal') then
			formatArray.largeur := 612;
			formatArray.hauteur := 1008;
		else
			Error('Unknown page format: '|| myformat);
		end if; 
		fwPt:=formatArray.largeur;
		fhPt:=formatArray.hauteur;
	else
		fwPt:=formatArray.largeur*k;
		fhPt:=formatArray.hauteur*k;
	end if; 
	fw:=fwPt/k;
	fh:=fhPt/k;
	-- Page orientation
	myorientation:=lower(myorientation);
	if(myorientation='p' or  myorientation='portrait') then
		DefOrientation:='P';
		wPt:=fwPt;
		hPt:=fhPt;
	elsif(myorientation='l' or myorientation='landscape') then
		DefOrientation:='L';
		wPt:=fhPt;
		hPt:=fwPt;
	else
		Error('Incorrect orientation: ' || myorientation);
	end if; 
	CurOrientation:=DefOrientation;
	w:=wPt/k;
	h:=hPt/k;
	-- Page margins (1 cm) 
	mymargin:=28.35/k;
	SetMargins(mymargin,mymargin);
	-- Interior cell margin (1 mm) 
	cMargin:=mymargin/10;
	-- Line width (0.2 mm)
	LineWidth:=.567/k;
	-- Automatic page break
	SetAutoPageBreak(true,2*mymargin);
	-- Full width display mode
	SetDisplayMode('fullwidth');
	-- Disable compression
	SetCompression(false);
	-- Set default PDF version number
	PDFVersion:='1.4';
	-- fpdf() e o construtor legado (Init() o chama por dentro): depois dele o
	-- package esta pronto. Sem marcar aqui, quem chamasse fpdf() direto ficava
	-- com g_initialized = false e as validacoes de uso davam falso negativo.
	g_initialized := true;
end fpdf;

----------------------------------------------------------------------------------------
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '') is
  myfamily word := family;
  mystyle  word := style;
  myfile   word := filename;
  fontkey word;
  fontCount number;
  i pls_integer;
  d pls_integer;
  nb pls_integer;
  myDiff varchar2(2000);
  myType varchar2(256); -- ????????? Cette variable est peut-être globale ????????????
  -- tabNull tv4000;
begin
	-- Add a TrueType or Type1 font
	myfamily:=lower(myfamily);
	if myfile is null then
		myfile:=replace(myfamily, ' ', '') || lower(mystyle) || '.php';
	end if; 
	if(myfamily='arial') then
		myfamily:='helvetica';
	end if; 
	mystyle:=upper(mystyle);
	if(mystyle='IB')  then
		mystyle:='BI';
	end if; 
	
	fontkey:=myfamily || mystyle;
	if(fonts.exists(fontkey)) then
		Error('Font already added: ' || myfamily || ' ' || mystyle);
	end if; 

	p_includeFont(fontkey);

	fontCount:=nvl(fonts.count, 0) + 1;

	fonts(fontkey).i := fontCount;
	fonts(fontkey).type := 'core';
	fonts(fontkey).name := coreFonts(fontkey);
	fonts(fontkey).up := -100;
	fonts(fontkey).ut := 50;
	fonts(fontkey).cw := fpdf_charWidths(fontkey);
	fonts(fontkey).file := myfile;
	
	if(myDiff is not null) then
		-- Search existing encodings
		d:=0;
		nb:=diffs.count;
		for i in 1..nb
		loop
			if(diffs(i) = myDiff) then
				d:=i;
				exit;
			end if; 
		end loop;
		if(d=0) then
			d:=nb+1;
			diffs(d):=myDiff;
		end if; 
		fonts(fontkey).diff:=d;
	end if; 

	if(myfile is not null) then
		if(myType = 'TrueType') then
		    FontFiles(myfile).length1 := originalsize;
		else
		    FontFiles(myfile).length1 := size1;
		    FontFiles(myfile).length2 := size2;
		end if; 
	end if; 
end AddFont;

----------------------------------------------------------------------------------------
procedure SetFont(pfamily in varchar2, pstyle in varchar2 default '', psize in number default 0) is
myfamily word;
mystyle	 word;
mysize	 number;
FontCount number := 0;
myFontFile word;
fontkey  word;
l_clean_style varchar2(10);  -- For validation
-- tabnull tv4000;
begin
	--------------------------------------------------------------------------------
	-- TASK 2.3: Input Validation - BEFORE any variable assignments
	-- TASK 3.1: Using constants instead of magic numbers
	--------------------------------------------------------------------------------
	-- Validate font family (before assignment to avoid buffer overflow)
	if pfamily is not null and length(pfamily) > c_MAX_FONT_NAME_LENGTH then
		raise_application_error(-20100, 'Font family name too long (max ' || c_MAX_FONT_NAME_LENGTH || ' characters)');
	end if;

	-- Validate font style (allow empty, N, B, I, BI, IB, U or combinations)
	-- Convert to uppercase FIRST, then remove 'U' (underline) for validation
	if pstyle is not null and length(pstyle) > 0 then
		-- Uppercase first, then remove U
		l_clean_style := replace(upper(pstyle), 'U', '');

		-- N = Normal, B = Bold, I = Italic, BI/IB = Bold+Italic
		-- After removing U, only these are valid (or empty string)
		-- Use nested structure to ensure proper evaluation
		if length(l_clean_style) > 0 then
			if l_clean_style not in ('N', 'B', 'I', 'BI', 'IB') then
				raise_application_error(-20100, 'Invalid font style: ''' || pstyle || '''. Valid: N, B, I, BI, IB (with optional U)');
			end if;
		end if;
	end if;

	-- Validate font size
	if psize is not null and (psize < c_MIN_FONT_SIZE or psize > c_MAX_FONT_SIZE) then
		raise_application_error(-20100, 'Invalid font size: ' || psize || '. Must be ' || c_MIN_FONT_SIZE || '-' || c_MAX_FONT_SIZE || ' points');
	end if;

	-- Now safe to assign to local variables
	myfamily := pfamily;
	mystyle := pstyle;
	mysize := psize;

	-- Select a font; size given in points
	myfamily:=lower(myfamily);

	if myfamily is null then
		myfamily:=FontFamily;
	end if;

	if(myfamily='arial') then
		myfamily:='helvetica';
	elsif(myfamily='symbol' or  myfamily='zapfdingbats') then
		mystyle:='';
	end if;
	mystyle:=upper(mystyle);

	-- Normalize 'N' (Normal) to empty string for font key lookup
	if mystyle = 'N' then
		mystyle := '';
	end if;
	
	if(instr(mystyle,'U') > 0) then
		underline:=true;
		mystyle:=replace(mystyle, 'U', '');
	else
		underline:=false;
	end if; 
	if(mystyle='IB') then
		mystyle:='BI';
	end if; 
	if(mysize=0) then
		mysize:=fontsizePt;
	end if; 

	-- Test if font is already selected
	if(FontFamily=myfamily and fontstyle=mystyle and fontsizePt=mysize) then
		return;
	end if; 
	
	-- Uso antes de Init: AddPage e SetPage ja recusavam com -20005; SetFont
	-- seguia em frente e o erro so aparecia depois, longe da causa.
	if not g_initialized then
	  raise_application_error(-20005,
	    'PL_FPDF not initialized. Call Init() first.');
	end if;

	-- Test if used for the first time	
	fontkey:=nvl(myfamily || mystyle, '');

	--if(not fontsExists(fontkey)) then
	if(not fonts.exists(fontkey)) then
		-- Check if one of the standard fonts
		
		if(CoreFonts.exists(fontkey)) then
			--if(not fpdf_charwidthsExists(fontkey)) then
			if(not fpdf_charwidths.exists(fontkey)) then
				-- Load metric file
				
				myFontFile:=myfamily;
				if(myfamily='times' or myfamily='helvetica') then
					myFontFile:=myFontFile || lower(mystyle);
				end if; 
				-- 
				p_includeFont(fontkey);
				-- 
				if(not fpdf_charwidthsExists(fontkey)) then
					Error('Could not include font metric file');
				end if; 
			end if; 
			FontCount:=nvl(fonts.count,0) + 1;
			fonts(fontkey).i := FontCount;
	 		fonts(fontkey).type := 'core';
			fonts(fontkey).name := CoreFonts(fontkey); 
			fonts(fontkey).up  := -100;  
			fonts(fontkey).ut := 50;   
			fonts(fontkey).cw  := fpdf_charwidths(fontkey);  
		else
			raise_application_error(-20201, 'Undefined font: ' || myfamily || ' ' || mystyle);
		end if; 
	end if; 
	-- Select it
	FontFamily:=myfamily;
	fontstyle:=mystyle;
	fontsizePt:=mysize;
	fontsize:=mysize/k;
	-- if(fontsExists(fontkey)) then
	    CurrentFont:= fonts(fontkey);
	-- end if;
	if(page>0) then
		p_out('BT /F'||CurrentFont.i||' '||tochar(fontsizePt,2)||' Tf ET');
	end if; 
    
    --We've change the font size so we need to update line spacing
    update_line_spacing;
end SetFont;

----------------------------------------------------------------------------------------
function GetStringWidth(pstr in varchar2) return number is
charSetWidth CharSet;
w number;
lg number;
wdth number;
c car;
begin
	-- Get width of a string in the current font
	charSetWidth := CurrentFont.cw;
	w:=0;
	lg := length(pstr);
	for i in 1..lg
	loop
		c := substr(pstr,i,1);
	    --if (charSetWidth.exists(c)) then
		  wdth := charSetWidth(c);
		--end if;
		w:= w + wdth;
	end loop;
	return w * fontsize/1000;
end GetStringWidth;

----------------------------------------------------------------------------------------
procedure SetFontSize(psize in number) is
begin
	-- Set font size in points
	if(fontsizePt=psize) then
		return;
	end if; 
	fontsizePt:=psize;
	fontsize:=psize/k;
	if(page>0) then
		p_out('BT /F'||CurrentFont.i||' '||tochar(fontsizePt,2)||' Tf ET');
	end if; 
end SetFontSize;

----------------------------------------------------------------------------------------
procedure Cell
		 (pw in number,
		  ph in number default 0,
		  ptxt in varchar2 default '',
		  pborder in varchar2 default '0',
		  pln in number default 0,
		  palign in varchar2 default '',
		  pfill in number default 0,
		  plink in varchar2 default '') is
 myPW number := pw;
 myK k%type := k;
 myX x%type := x;
 myY y%type := y;
 myWS ws%type := ws;
 myS txt;
 myOP txt;
 myDX number;
 myTXT2 txt;
begin
  null;
	-- Output a cell 
	if( ( y + ph > pageBreakTrigger) and  not InFooter and AcceptPageBreak()) then
		-- Automatic page break
		if(myWS > 0) then
			ws:=0;
			p_out('0 Tw');
		end if; 
		AddPage(CurOrientation);
		x:=myX;
		if(myWS > 0) then
			ws := myWS;
			p_out(tochar(myWS * myK,3) ||' Tw');
		end if; 
	end if; 

	if(myPW = 0) then
		myPW := w - rMargin - x;
	end if; 
	myS := '';
	if(pfill = 1 or pborder = '1') then
		if(pfill = 1) then 
		  if (pborder = '1') then 
		    myOP :=  'B';
		  else
		    myOP := 'f';
		  end if; 
		else
			myOP := 'S';
		end if; 
		myS := tochar(x*myK,2)||' '||tochar((h-y)*myK,2)||' '||tochar(myPW*myK,2)||' '||tochar(-ph*myK,2)||' re '||myOP||' ';
	end if; 
	
	if(nao_e_numero(pborder)) then
		myX := x;
		myY := y;
		if(instr(pborder,'L') > 0) then
			myS := myS || tochar(myX*myK,2) ||' '||tochar((h-myY)*myK,2)||' m '||tochar(myX*myK,2)||' '||tochar((h-(myY+ph))*myK,2)||' l S ';
		end if; 
		if(instr(pborder,'T') > 0) then
			myS := myS || tochar(myX*myK,2)||' '||tochar((h-myY)*myK,2)||' m '||tochar((myX+myPW)*myK,2)||' '||tochar((h-myY)*myK,2)||' l S ';
		end if; 
		if(instr(pborder,'R') > 0) then
			myS := myS || tochar((myX+myPW)*myK,2)||' '||tochar((h-myY)*myK,2)||' m '||tochar((myX+myPW)*myK,2)||' '||tochar((h-(myY+ph))*myK,2)||' l S ';
		end if; 
		if(instr(pborder,'B') > 0) then
			myS := myS || tochar(myX*myK,2)||' '||tochar((h-(myY+ph))*myK,2)||' m '||tochar((myX+myPW)*myK,2)||' '||tochar((h-(myY+ph))*myK,2)||' l S ';
		end if; 
	end if; 
	if ptxt is not null then
		if(palign='R') then
			myDX := myPW - cMargin - GetStringWidth(ptxt);
		elsif(palign='C') then
			myDX := (myPW - GetStringWidth(ptxt))/2;
		else
			myDX := cMargin;
		end if; 
		if(ColorFlag) then
			myS := myS || 'q ' || TextColor || ' ';
	    end if; 
		
        myTXT2 := p_escapa_pdf(ptxt);
    myS := myS || 'BT '||tochar((x+myDX)*myK,2)||' '||tochar((h-(y+.5*ph+.3*fontsize))*myK,2)||' Td ('||myTXT2||') Tj ET';
		if(underline) then
			myS := myS || ' ' || p_dounderline(x+myDX,y+.5*ph+.3*fontsize,ptxt);
		end if; 
		if(ColorFlag) then
			myS := myS || ' Q';
		end if; 
		if(plink is not null) then
			Link(x + myDX,y + .5*ph - .5*fontsize, GetStringWidth(ptxt), fontsize, plink);
	    end if; 
	end if; 
	if(myS is not null) then
		p_out(myS);
	end if; 

	lasth := ph;
	if( pln>0 ) then
		-- Go to next line
		y := y + ph;
		if(pln=1) then
			x := lMargin;
		end if; 
	else
		x := x + myPW;
	end if; 
exception 
  when others then
   error('Cell : '||sqlerrm);
end Cell;
    
----------------------------------------------------------------------------------------
-- MultiCell : Output text with automatic or explicit line breaks
-- param phMax : give the max height for the multicell. (0 if non applicable)
-- if ph is null : the minimum height is the value of the property LineSpacing
----------------------------------------------------------------------------------------
function MultiCell
  ( pw in number,
    ph in number default 0,
	ptxt in varchar2,
	pborder in varchar2 default '0',
	palign in varchar2 default 'J',
	pfill in number default 0,
	phMax in number default 0) return number is
	
  charSetWidth CharSet;
  myPW number := pw;
  myBorder word := pborder;
  myS txt;
  myNB number;
  wmax number;
  myB txt;
  myB2 txt;
  sep number := -1;
--  i number := 0;
--  j number := 0;
  i number := 1;
  j number := 1;
  l number := 0;
  ns number := 0;
  nl number := 1;
  carac word;
  lb_skip boolean := false;
  ls number;
  cumulativeHeight number := 0;
  myH number := pH;
begin
	-- Output text with automatic or explicit line breaks
	
	-- see if we need to set Height to the minimum linespace
	if (myH = 0) then
	  myH := getLineSpacing;
	end if;
	
	charSetWidth := CurrentFont.cw;
	if(myPW = 0) then
		myPW:=w - rMargin - x;
	end if; 
	wmax := (myPW - 2 * cMargin) * 1000 / fontsize;
	myS := replace(ptxt, CHR(13), '');
	myNB := length(myS);
	if(myNB > 0 and substr(myS,-1) = CHR(10) ) then
		myNB := myNB - 1;
	end if; 
	myB := 0;

	if (myBorder is not null) then
		if(myBorder = '1') then
			myBorder :='LTRB';
			myB := 'LRT';
			myB2 := 'LR';
		else
			myB2 := '';
			if(instr(myBorder,'L') > 0) then
				myB2 := myB2 || 'L';
			end if; 
			if(instr(myBorder,'R') > 0) then
				myB2 := myB2 || 'R';
			end if; 
			if (instr(myBorder,'T') > 0) then 
			  myB := myB2 || 'T';
			else
			  myB := myB2;
			end if; 
		end if; 
	end if; 

	while(i <= myNB)
	loop
	    lb_skip := false;
		-- Get next character
		carac := substr(myS,i,1);
		if(carac = CHR(10)) then
			-- Explicit line break
			if(ws > 0) then
				ws := 0;
				p_out('0 Tw');
			end if; 
			Cell(myPW,myH,substr(myS,j,i-j),myB,2,palign,pfill);
			cumulativeHeight := cumulativeHeight + myH;
			i := i + 1;
			sep := -1;
			j := i;
			l := 0;
			ns := 0;
			nl := nl + 1;
			if(myBorder is not null and nl = 2) then
				myB := myB2;
			end if; 
			-- si on passe là on continue à la prochaine itération de la boucle 
			-- en PHP il y avait l'instruction "continue" .
			lb_skip := true;
		end if; 
		
		if (not lb_skip) then 
			if(carac =' ') then
				sep := i;
				ls := l;
				ns := ns + 1;
			end if; 
			l := l + charSetWidth (carac);
			if( l > wmax) then
				-- Automatic line break
				if(sep=-1) then
					if(i=j) then
						i := i + 1;
					end if; 
					if(ws > 0) then
						ws := 0;
						p_out('0 Tw');
					end if; 

                    Cell(myPW,myH,substr(myS,j,i-j),myB,2,palign,pfill);
				else
					if(palign = 'J') then
					    if (ns > 1) then 
						  ws := (wmax - ls)/1000*fontsize/(ns-1);
						else
						  ws := 0;
						end if; 
						p_out(''|| tochar(ws*k,3) ||' Tw');
					end if; 
                    
                    Cell(myPW,myH,substr(myS,j,sep-j),myB,2,palign,pfill);
					i := sep + 1;
				end if; 
				cumulativeHeight := cumulativeHeight + myH;
				sep := -1;
				j := i;
				l := 0;
				ns := 0;
				nl := nl + 1;
				if(myBorder is not null and nl = 2) then
					myB := myB2;
				end if; 
			else
			  i := i + 1;
			end if; 
		end if; 
	end loop;

	-- Last chunk
	if(ws > 0) then
		ws := 0;
		p_out('0 Tw');
	end if; 
	
	if(myBorder is not null and instr(myBorder,'B') > 0) then
	  if (phMax > 0) then
	    if (cumulativeHeight >= phMax) then
		  myB := myB || 'B';
		end if;
	  else
	    myB := myB || 'B';
	  end if;
	end if; 
	Cell(myPW,myH,substr(myS,j,i-j),myB,2,palign,pfill);
	cumulativeHeight := cumulativeHeight + myH;
	
    -- add an empty cell if phMax is not reached.
	if (phMax > 0) then
	    if ( cumulativeHeight < phMax ) then
		    -- dealing with the bottom border.
			if(myBorder is not null and instr(myBorder,'B') > 0) then
				myB := myB || 'B';
			end if; 
	        Cell(myPW,phMax-cumulativeHeight,null,myB,2,palign,pfill);
	    end if;
	end if;

	x := lMargin;
    
    return nl;

exception 
  when others then
   error('MultiCell : '||sqlerrm);
end MultiCell;

----------------------------------------------------------------------------------------
-- MultiCell : Output text with automatic or explicit line breaks
-- param phMax : give the max height for the multicell. (0 if non applicable)
-- if ph is null : the minimum height is the value of the property LineSpacing
----------------------------------------------------------------------------------------
procedure MultiCell
  ( pwidth in number,
    pheight in number default 0,
    ptext in varchar2,
    pbrdr in varchar2 default '0',
    palignment in varchar2 default 'J',
    pfillin in number default 0,
    phMaximum in number default 0) is
    
   ln_ignore number;
begin
    ln_ignore := MultiCell  ( pw => pwidth, ph => pheight, ptxt => ptext, pborder => pbrdr,
                              palign => palignment, pfill => pfillin, phMax => phMaximum);
end multicell;

----------------------------------------------------------------------------------------
procedure image ( pFile in varchar2, 
		  		  pX in number, 
				  pY in number, 
				  pWidth in number default 0,
				  pHeight in number default 0,
				  pType in varchar2 default null,
				  pLink in varchar2 default null) is
				  
   myFile varchar2(2000) := pFile;
   -- myType varchar2(256) := pType;
   myW number := pWidth;
   myH number := pHeight;
   -- pos number;
   info recImage;
begin
    --Put an image on the page
	if ( not imageExists(myFile) ) then
		--First use of image, get info
		info := p_parseImage(myFile);
		info.i := nvl(images.count, 0) + 1;
		images(lower(myFile)) := info;
	else
		info := images(lower(myFile));
	end if;
	--Automatic width and height calculation if needed
	if(myW = 0 and myH = 0) then
		--Put image at 72 dpi
		myW := info.w / k;
		myH := info.h / k;
	end if;
	if (myW = 0) then
		myW := myH * info.w / info.h;
    end if;
	if (myH = 0) then
		myH := myW * info.h / info.w;
	end if;
	p_out('q '||tochar(myW * k, 2)||' 0 0 '||tochar(myH * k, 2)||' '||tochar(pX * k, 2)||' '||tochar((h - ( pY + myH)) * k, 2)||' cm /I'||to_char(info.i)||' Do Q');
	if(pLink is not null) then
		Link(pX,pY,myW,myH,pLink);
	end if;
exception 
  when others then
   error('image : '||sqlerrm);
end image;

/* THIS PROCEDURE HANGS UP ........... */
----------------------------------------------------------------------------------------
procedure Write(pH varchar2,ptxt varchar2,plink varchar2 default null) is
   charSetWidth CharSet;
   myW number;     -- remaining width from actual position in user units
   myWmax number;  -- remaining cellspace
   s bigtext;
   c word;
   nb pls_integer;
   sep pls_integer;
   i pls_integer;
   j pls_integer;
   l pls_integer;
   lsep pls_integer;
   lastl pls_integer;
begin
	-- Output text in flowing mode
	charSetWidth := CurrentFont.cw;
	myW := w - rMargin - x;
	myWmax := (myW - 2 * cMargin) * 1000 / FontSize;
	s := replace(ptxt, chr(13), '');
	nb := length(s);
	sep := -1;   -- no blank space encountered, position of last blank
  i := 1;      -- running position
  j := 1;      -- last remembered position , start for next output
	l := 0;      -- string length since last written
  lsep := 0;   -- position of last blank
  lastl := 0;  -- length till that blank
  -- Loop over all characters
	while i <= nb  loop
		-- Get next character
		c := substr(s, i, 1);
    
    -- Explicit line break
		if(c = chr(10)) then
			Cell(myW, pH, substr(s,j,i-j), 0, 1, '', 0, plink);   
      -- positioned at beginning of new line
			i := i + 1;
			sep := -1;
			j := i;
			l := 0;
      myW := w - rMargin - x;
			myWmax := (myW - 2 * cMargin) * 1000 / FontSize;  -- whole line
		
    else 
			if c = ' ' then
				 sep := i;
         lsep := 0;
         lastl := l;
      else
         lsep := lsep + charSetWidth(c);
			end if; 
			l := l + charSetWidth(c);
			if l > myWmax then
				-- Automatic line break
				if sep = -1 then  -- forced
          Cell(myW, pH, substr(s,j,i-j+1), 0, 1, '', 0, plink);
					i := i + 1;
          j := i;
          l := 0;
				else  -- wrap at last blank
					Cell(myW, pH, substr(s,j,sep-j), 0, 1, '', 0, plink);
					i := sep + 1;
          j := i;
          sep := -1;
          l := lsep-(myWmax-lastl);  -- rest remaining space from previous line
                                     -- WHY ????   
				end if;
        myW := w - rMargin - x;
				myWmax := (myW - 2 * cMargin) * 1000 / FontSize;
			else
				i := i + 1;
			end if;
		end if;
	end loop;
	-- Last chunk
	if( i != j ) then
		 Cell((l+2*cMargin) / 1000 * FontSize, pH, substr(s,j), 0, 0, '', 0, plink);
  end if;
exception 
   when others then
      error('write : '||sqlerrm);
end write;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

/*******************************************************************************
* Function: OutputBlob
* Description: Returns PDF document as BLOB (no OWA dependencies)
* Returns: BLOB containing complete PDF
*******************************************************************************/
function OutputBlob return blob is
  v_doc blob;
  -- usadas em dbms_lob.convertToBlob logo abaixo; os avisos de "declarada e
  -- nunca usada" com estes nomes eram de ReturnBlob, nao daqui
  v_in pls_integer;
  v_out pls_integer;
  v_lang pls_integer;
  v_warning pls_integer;
  v_len pls_integer;
begin
  -- Uso antes de Init: AddPage, SetPage e SetFont ja recusavam com -20005.
  -- OutputBlob seguia em frente e devolvia um PDF vazio, sem apontar a causa.
  if not g_initialized then
    raise_application_error(-20005,
      'PL_FPDF not initialized. Call Init() first.');
  end if;

  -- Finish document if necessary
  if state < 3 then
    ClosePDF();
  end if;

  -- Create temporary BLOB
  dbms_lob.createtemporary(v_doc, false, dbms_lob.session);

  -- Descarrega o que restou no acumulador antes de converter para BLOB
  p_flush_doc_buf;

  if pdfDoc is not null and dbms_lob.getlength(pdfDoc) > 0 then
    v_in := 1;
    v_out := 1;
    v_lang := 0;
    v_warning := 0;
    v_len := dbms_lob.getlength(pdfDoc);
    dbms_lob.convertToBlob(v_doc, pdfDoc, v_len,
      v_in, v_out, dbms_lob.default_csid, v_lang, v_warning);
  end if;

  log_message(3, 'OutputBlob: Generated BLOB of ' || dbms_lob.getlength(v_doc) || ' bytes');

  return v_doc;
exception
  when others then
    -- erros do proprio package (-20000..-20999) ja tem codigo e mensagem
    -- proprios; envolve-los em -20100 escondia a causa, como o -20005 de
    -- 'nao inicializado' que este mesmo handler engolia
    if sqlcode between -20999 and -20000 then
      raise;
    end if;
    log_message(1, 'Error in OutputBlob: ' || sqlerrm);
    error('OutputBlob: ' || sqlerrm);
    return null;
end OutputBlob;

/*******************************************************************************
* Procedure: OutputFile
* Description: Saves PDF to filesystem using UTL_FILE (no OWA dependencies)
* Parameters:
*   p_filename - Name of the PDF file to create
*   p_directory - Oracle directory object (default: 'PDF_DIR')
*******************************************************************************/
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR') is
  v_pdf_blob blob;
  v_file utl_file.file_type;
  v_buffer raw(32767);
  v_amount pls_integer := 32767;
  v_pos pls_integer := 1;
  v_blob_len pls_integer;
begin
  -- Get PDF as BLOB
  v_pdf_blob := OutputBlob();
  v_blob_len := dbms_lob.getlength(v_pdf_blob);

  log_message(3, 'OutputFile: Saving ' || v_blob_len || ' bytes to ' || p_filename ||
              ' in directory ' || p_directory);

  -- Open file for writing
  begin
    v_file := utl_file.fopen(p_directory, p_filename, 'wb', 32767);
  exception
    when others then
      if sqlcode = -29280 then
        raise_application_error(-20401,
          'Invalid or non-existent directory: ' || p_directory);
      elsif sqlcode = -29283 then
        raise_application_error(-20402,
          'Permission denied accessing directory: ' || p_directory);
      else
        raise_application_error(-20403,
          'Error opening file: ' || sqlerrm);
      end if;
  end;

  -- Write BLOB to file in chunks
  begin
    while v_pos < v_blob_len loop
      v_amount := least(32767, v_blob_len - v_pos + 1);
      v_buffer := dbms_lob.substr(v_pdf_blob, v_amount, v_pos);
      utl_file.put_raw(v_file, v_buffer, true);
      v_pos := v_pos + v_amount;
    end loop;

    utl_file.fclose(v_file);

    log_message(3, 'OutputFile: Successfully saved ' || p_filename);
  exception
    when others then
      if utl_file.is_open(v_file) then
        utl_file.fclose(v_file);
      end if;
      log_message(1, 'Error writing file: ' || sqlerrm);
      raise_application_error(-20403, 'Error writing file: ' || sqlerrm);
  end;

  -- Free temporary BLOB
  if dbms_lob.istemporary(v_pdf_blob) = 1 then
    dbms_lob.freetemporary(v_pdf_blob);
  end if;

exception
  when others then
    log_message(1, 'Error in OutputFile: ' || sqlerrm);
    error('OutputFile: ' || sqlerrm);
    raise;
end OutputFile;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: Output (Legacy - OWA dependencies removed)
* Description: Legacy output procedure - now delegates to modern methods
* Parameters:
*   pname - Filename (required for 'F' mode)
*   pdest - Destination: 'F' = File (only supported mode)
* Note: 'I', 'D', 'S' modes removed (used OWA/HTP)
*       Use OutputBlob() or OutputFile() directly for new code
*******************************************************************************/
procedure Output(pname varchar2 default null, pdest varchar2 default null) is
  myName word := pname;
  myDest word := pdest;
begin
  -- Finish document if necessary
  if state < 3 then
    ClosePDF();
  end if;

  myDest := upper(myDest);

  -- Default destination is 'F' (File)
  if myDest is null then
    if myName is null then
      myName := 'doc.pdf';
    end if;
    myDest := 'F';
  end if;

  -- Only 'F' (File) mode is supported
  if myDest = 'F' then
    if myName is null then
      raise_application_error(-20100,
        'Filename required for Output with pdest=''F''. Example: Output(''report.pdf'', ''F'')');
    end if;

    -- Delegate to OutputFile
    OutputFile(myName, 'PDF_DIR');
    log_message(3, 'Output: Saved to file ' || myName);

  elsif myDest in ('I', 'D', 'S') then
    -- Estes modos mandavam os cabecalhos HTTP por conta propria. Sem eles, a
    -- entrega passou a ser da aplicacao — e esquecer o Content-Type produz um
    -- sintoma que nao parece o que e: o navegador trata a resposta como HTML e
    -- mostra o FONTE do PDF na tela. Parece corrupcao de caracteres, e o
    -- arquivo esta perfeito. Por isso a mensagem aponta o cabecalho, e nao so
    -- a API substituta.
    raise_application_error(-20306,
      'Output mode ''' || myDest || ''' is no longer supported (OWA/HTP removed). ' ||
      'Use OutputBlob() to get the PDF as a BLOB, then deliver it yourself ' ||
      'with owa_util.mime_header(''application/pdf'', FALSE) and ' ||
      'wpg_docload.download_file() — without the Content-Type header the ' ||
      'browser may render the PDF source as a web page. See "Entregar o PDF a ' ||
      'um navegador" in docs/DOCUMENTATION.md. Or use OutputFile() to save to ' ||
      'the filesystem.');

  else
    raise_application_error(-20100,
      'Invalid output destination: ' || myDest || '. Use ''F'' for file output, ' ||
      'or call OutputBlob()/OutputFile() directly.');
  end if;

exception
  when others then
    log_message(1, 'Error in Output: ' || sqlerrm);
    error('Output: ' || sqlerrm);
end Output;

function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null)
return blob is
myName word := pname;
myDest word := pdest;
v_doc blob; -- finally complete document
v_blob blob;
v_clob clob;
v_in pls_integer;
v_out pls_integer;
v_lang pls_integer;
v_warning pls_integer;
v_len pls_integer;
begin
dbms_lob.createtemporary(v_blob, false, dbms_lob.session);
dbms_lob.createtemporary(v_doc, false, dbms_lob.session);
-- Output PDF to some destination
-- Finish document if necessary
if state < 3 then
ClosePDF();
end if;
myDest := upper(myDest);
if(myDest is null) then
if(myName is null) then
myName := 'doc.pdf';
myDest := 'I';
else
myDest := 'D';
end if;
end if;

  -- Task 1.7: Removed dead code (pdfDoc array loop was never used)
  -- Simply delegate to OutputBlob (Task 1.5 - OWA removed)
  return OutputBlob();
exception
  when others then
    log_message(1, 'Error in ReturnBlob: ' || sqlerrm);
    error('ReturnBlob: ' || sqlerrm);
    return null;
end ReturnBlob;
 

--------------------------------------------------------------------------------
-- Date: 2025-12-16
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: CellRotated
* Description: Modern Cell with text rotation support
*******************************************************************************/
procedure CellRotated(
  p_width number,
  p_height number default 0,
  p_text varchar2 default '',
  p_border varchar2 default '0',
  p_ln number default 0,
  p_align varchar2 default '',
  p_fill number default 0,
  p_link varchar2 default '',
  p_rotation pls_integer default 0
) is
  l_angle number;
  l_x number;
  l_y number;
  l_cos number;
  l_sin number;
begin
  -- Validate rotation
  if p_rotation not in (0, 90, 180, 270) then
    raise_application_error(-20110,
      'Invalid text rotation: ' || p_rotation || '. Must be 0, 90, 180, or 270 degrees.');
  end if;

  -- If no rotation, use legacy Cell implementation
  if p_rotation = 0 then
    Cell(p_width, p_height, p_text, p_border, p_ln, p_align, p_fill, p_link);
    return;
  end if;

  -- Apply rotation transformation
  l_x := x;
  l_y := y;
  l_angle := p_rotation * 3.14159265359 / 180;  -- Convert to radians
  l_cos := cos(l_angle);
  l_sin := sin(l_angle);

  -- Save graphics state and apply combined rotation transformation
  -- Single matrix for rotating around point (l_x, l_y)
  p_out('q');  -- Save graphics state
  p_out(tochar(l_cos, 5) || ' ' || tochar(l_sin, 5) || ' ' ||
        tochar(-l_sin, 5) || ' ' || tochar(l_cos, 5) || ' ' ||
        tochar(l_x * k * (1 - l_cos) + (h - l_y) * k * l_sin, 2) || ' ' ||
        tochar((h - l_y) * k * (1 - l_cos) - l_x * k * l_sin, 2) || ' cm');

  -- Call legacy Cell implementation
  Cell(p_width, p_height, p_text, p_border, p_ln, p_align, p_fill, p_link);

  -- Restore graphics state
  p_out('Q');

  log_message(4, 'CellRotated: text="' || substr(p_text, 1, 50) || '", rotation=' || p_rotation);

exception
  when others then
    log_message(1, 'Error in CellRotated: ' || sqlerrm);
    raise;
end CellRotated;

/*******************************************************************************
* Procedure: WriteRotated
* Description: Modern Write with text rotation support
* NOTE: Currently only 0° rotation is fully supported due to limitations
*       with the legacy Write() procedure's internal positioning calculations.
*       For non-zero rotations, use CellRotated() instead.
*******************************************************************************/
procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
) is
begin
  -- Validate rotation
  if p_rotation not in (0, 90, 180, 270) then
    raise_application_error(-20110,
      'Invalid text rotation: ' || p_rotation || '. Must be 0, 90, 180, or 270 degrees.');
  end if;

  -- Currently only 0° rotation is supported for Write
  -- For rotated text, use CellRotated instead
  if p_rotation <> 0 then
    raise_application_error(-20111,
      'WriteRotated currently only supports 0° rotation. ' ||
      'Use CellRotated() for rotated text output.');
  end if;

  -- Call legacy Write implementation
  Write(p_height, p_text, p_link);

  log_message(4, 'WriteRotated: text="' || substr(p_text, 1, 50) || '", rotation=' || p_rotation);

exception
  when others then
    log_message(1, 'Error in WriteRotated: ' || sqlerrm);
    raise;
end WriteRotated;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Date: 2025-12-18
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: SetDocumentConfig
* Description: Configure PDF document using JSON_OBJECT_T
*******************************************************************************/
procedure SetDocumentConfig(p_config JSON_OBJECT_T) is
  l_keys JSON_KEY_LIST;
  l_key VARCHAR2(100);
  l_value VARCHAR2(4000);
begin
  -- Handle NULL config gracefully
  if p_config is null then
    log_message(c_LOG_WARN, 'SetDocumentConfig: NULL config provided, ignoring');
    return;
  end if;

  log_message(c_LOG_INFO, 'SetDocumentConfig: Processing JSON configuration');

  l_keys := p_config.get_keys;

  -- Process each configuration key
  for i in 1..l_keys.count loop
    l_key := l_keys(i);

    begin
      case upper(l_key)
        -- Document metadata
        when 'TITLE' then
          title := p_config.get_String(l_key);
          log_message(c_LOG_DEBUG, 'Set title: ' || title);

        when 'AUTHOR' then
          author := p_config.get_String(l_key);
          log_message(c_LOG_DEBUG, 'Set author: ' || author);

        when 'SUBJECT' then
          subject := p_config.get_String(l_key);
          log_message(c_LOG_DEBUG, 'Set subject: ' || subject);

        when 'KEYWORDS' then
          keywords := p_config.get_String(l_key);
          log_message(c_LOG_DEBUG, 'Set keywords: ' || keywords);

        when 'CREATOR' then
          creator := p_config.get_String(l_key);
          log_message(c_LOG_DEBUG, 'Set creator: ' || creator);

        -- Page configuration
        when 'ORIENTATION' then
          l_value := p_config.get_String(l_key);
          -- ALWAYS validate orientation
          if upper(substr(l_value, 1, 1)) not in ('P', 'L') then
            raise_application_error(-20001,
              'Invalid orientation: ' || l_value || '. Must be P or L.');
          end if;
          -- Set based on initialization state
          if not g_initialized then
            g_default_orientation := upper(substr(l_value, 1, 1));
          else
            -- Already initialized - orientation cannot be changed
            log_message(c_LOG_WARN, 'Cannot change orientation after initialization');
          end if;
          log_message(c_LOG_DEBUG, 'Set orientation: ' || l_value);

        when 'UNIT' then
          l_value := lower(p_config.get_String(l_key));
          -- ALWAYS validate unit
          if l_value not in ('mm', 'cm', 'in', 'pt') then
            raise_application_error(-20002,
              'Invalid unit: ' || l_value || '. Must be mm, cm, in, or pt.');
          end if;
          -- Unit can only be set during Init()
          if not g_initialized then
            log_message(c_LOG_INFO, 'Unit will be set during Init() call');
          else
            log_message(c_LOG_WARN, 'Cannot change unit after initialization');
          end if;

        when 'FORMAT' then
          l_value := upper(p_config.get_String(l_key));
          if not g_initialized then
            g_default_format := get_page_format(l_value);
          end if;
          log_message(c_LOG_DEBUG, 'Set format: ' || l_value);

        -- Font configuration
        when 'FONTFAMILY' then
          l_value := p_config.get_String(l_key);
          if g_initialized then
            SetFont(l_value, fontstyle, fontsizePt);
          end if;
          log_message(c_LOG_DEBUG, 'Set font family: ' || l_value);

        when 'FONTSIZE' then
          if g_initialized then
            SetFont(FontFamily, fontstyle, p_config.get_Number(l_key));
          end if;
          log_message(c_LOG_DEBUG, 'Set font size: ' || p_config.get_Number(l_key));

        when 'FONTSTYLE' then
          l_value := p_config.get_String(l_key);
          if g_initialized then
            SetFont(FontFamily, l_value, fontsizePt);
          end if;
          log_message(c_LOG_DEBUG, 'Set font style: ' || l_value);

        -- Margin configuration
        when 'LEFTMARGIN' then
          SetLeftMargin(p_config.get_Number(l_key));
          log_message(c_LOG_DEBUG, 'Set left margin: ' || p_config.get_Number(l_key));

        when 'TOPMARGIN' then
          SetTopMargin(p_config.get_Number(l_key));
          log_message(c_LOG_DEBUG, 'Set top margin: ' || p_config.get_Number(l_key));

        when 'RIGHTMARGIN' then
          rMargin := p_config.get_Number(l_key);
          log_message(c_LOG_DEBUG, 'Set right margin: ' || p_config.get_Number(l_key));

        else
          log_message(c_LOG_WARN, 'Unknown configuration key: ' || l_key);
      end case;

    exception
      when others then
        log_message(c_LOG_ERROR, 'Error processing key "' || l_key || '": ' || sqlerrm);
        raise;
    end;
  end loop;

  log_message(c_LOG_INFO, 'SetDocumentConfig: Configuration applied successfully');

exception
  when others then
    log_message(c_LOG_ERROR, 'Error in SetDocumentConfig: ' || sqlerrm);
    raise;
end SetDocumentConfig;

/*******************************************************************************
* Function: GetDocumentMetadata
* Description: Returns document metadata and statistics as JSON
*******************************************************************************/
function GetDocumentMetadata return JSON_OBJECT_T is
  l_metadata JSON_OBJECT_T;
  l_unit VARCHAR2(10);
begin
  l_metadata := JSON_OBJECT_T();

  -- Document information
  l_metadata.put('initialized', g_initialized);
  l_metadata.put('pageCount', g_current_page);

  -- Document metadata
  if title is not null then
    l_metadata.put('title', title);
  end if;

  if author is not null then
    l_metadata.put('author', author);
  end if;

  if subject is not null then
    l_metadata.put('subject', subject);
  end if;

  if keywords is not null then
    l_metadata.put('keywords', keywords);
  end if;

  if creator is not null then
    l_metadata.put('creator', creator);
  end if;

  -- Page configuration
  l_metadata.put('orientation', case g_default_orientation
    when 'P' then 'Portrait'
    when 'L' then 'Landscape'
    else 'Unknown'
  end);

  -- Determine unit from scale factor k
  if k = c_SCALE_PT then
    l_unit := 'pt';
  elsif k = c_SCALE_MM then
    l_unit := 'mm';
  elsif k = c_SCALE_CM then
    l_unit := 'cm';
  elsif k = c_SCALE_IN then
    l_unit := 'in';
  else
    l_unit := 'unknown';
  end if;
  l_metadata.put('unit', l_unit);

  -- Try to determine format from default format
  if g_formats_initialized and g_default_format.width is not null then
    -- Match against known formats
    if g_default_format.width = 210 and g_default_format.height = 297 then
      l_metadata.put('format', 'A4');
    elsif g_default_format.width = 216 and g_default_format.height = 279 then
      l_metadata.put('format', 'Letter');
    elsif g_default_format.width = 216 and g_default_format.height = 356 then
      l_metadata.put('format', 'Legal');
    elsif g_default_format.width = 297 and g_default_format.height = 420 then
      l_metadata.put('format', 'A3');
    elsif g_default_format.width = 148 and g_default_format.height = 210 then
      l_metadata.put('format', 'A5');
    else
      l_metadata.put('format', 'Custom');
      l_metadata.put('formatWidth', g_default_format.width);
      l_metadata.put('formatHeight', g_default_format.height);
    end if;
  end if;

  -- PDF version
  l_metadata.put('pdfVersion', c_PDF_VERSION);
  l_metadata.put('fpdfVersion', co_version);

  log_message(c_LOG_DEBUG, 'GetDocumentMetadata: Returned metadata for ' || g_current_page || ' pages');

  return l_metadata;

exception
  when others then
    log_message(c_LOG_ERROR, 'Error in GetDocumentMetadata: ' || sqlerrm);
    raise;
end GetDocumentMetadata;

--------------------------------------------------------------------------------
-- read_blob_chunk: Read chunk of BLOB as text
--------------------------------------------------------------------------------
FUNCTION read_blob_chunk(
  p_blob BLOB,
  p_offset PLS_INTEGER,
  p_length PLS_INTEGER
) RETURN VARCHAR2 IS
  l_raw RAW(32767);
BEGIN
  l_raw := DBMS_LOB.SUBSTR(p_blob, LEAST(p_length, 32767), p_offset);
  RETURN UTL_RAW.CAST_TO_VARCHAR2(l_raw);
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END read_blob_chunk;

--------------------------------------------------------------------------------
-- get_pdf_object: Load object by ID
--------------------------------------------------------------------------------
FUNCTION get_pdf_object(p_obj_id PLS_INTEGER) RETURN CLOB IS
  l_offset PLS_INTEGER;
  l_obj_text VARCHAR2(32767);
  l_end_pos PLS_INTEGER;
  l_obj_content CLOB;
BEGIN
  -- Check cache
  IF g_object_cache.EXISTS(p_obj_id) THEN
    RETURN g_object_cache(p_obj_id);
  END IF;

  -- Objeto de dentro de um object stream: nao ha offset no arquivo, o corpo
  -- ja foi materializado na carga da xref.
  IF g_objstm_body.EXISTS(p_obj_id) THEN
    g_object_cache(p_obj_id) := g_objstm_body(p_obj_id);
    RETURN g_object_cache(p_obj_id);
  END IF;

  -- Check if object exists
  IF NOT g_xref_table.EXISTS(p_obj_id) THEN
    raise_application_error(-20805, 'Object ' || p_obj_id || ' not in xref table');
  END IF;

  l_offset := g_xref_table(p_obj_id).offset;
  IF l_offset IS NULL THEN
    raise_application_error(-20847,
      'Objeto ' || p_obj_id || ' esta num object stream que nao foi carregado.');
  END IF;
  log_message(4, 'get_pdf_object(' || p_obj_id || '): offset=' || l_offset);

  -- Read object
  l_obj_text := read_blob_chunk(g_loaded_pdf, l_offset + 1, 32767);
  log_message(4, 'get_pdf_object(' || p_obj_id || '): raw text (first 200)=' ||
              SUBSTR(l_obj_text, 1, 200));

  -- Find end of object
  l_end_pos := INSTR(l_obj_text, 'endobj');

  IF l_end_pos = 0 THEN
    raise_application_error(-20806, 'endobj not found for object ' || p_obj_id);
  END IF;

  -- Extract content
  l_obj_content := SUBSTR(l_obj_text, 1, l_end_pos + 5);

  -- Cache
  g_object_cache(p_obj_id) := l_obj_content;

  RETURN l_obj_content;
END get_pdf_object;

--------------------------------------------------------------------------------
-- parse_page_tree: Parse page tree and populate page info table
--------------------------------------------------------------------------------
PROCEDURE parse_page_tree IS
  l_catalog CLOB;
  l_pages_id PLS_INTEGER;
  l_pages_obj CLOB;
  l_kids_array VARCHAR2(4000);
  l_page_obj_id PLS_INTEGER;
  l_page_num PLS_INTEGER := 1;
  l_pos PLS_INTEGER;
  l_end_pos PLS_INTEGER;
BEGIN
  g_page_info_table.DELETE;

  -- Get Catalog
  l_catalog := get_pdf_object(g_root_obj_id);
  log_message(3, 'Catalog (Root=' || g_root_obj_id || '): ' || SUBSTR(l_catalog, 1, 300));

  -- Extract Pages object ID
  l_pages_id := TO_NUMBER(
    REGEXP_SUBSTR(l_catalog, '/Pages\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_pages_id IS NULL THEN
    log_message(1, 'Catalog object: ' || SUBSTR(l_catalog, 1, 500));
    raise_application_error(-20810, 'Pages not found in Catalog');
  END IF;

  -- Store Pages object ID for inherited properties lookup
  g_pages_obj_id := l_pages_id;
  log_message(3, 'Pages object ID: ' || l_pages_id);

  -- Get Pages object
  l_pages_obj := get_pdf_object(l_pages_id);
  log_message(3, 'Pages object content (first 300 chars): ' || SUBSTR(l_pages_obj, 1, 300));

  -- Extract Kids array: /Kids [4 0 R 5 0 R 6 0 R]
  -- Using INSTR/SUBSTR instead of REGEXP for better Oracle compatibility
  DECLARE
    l_kids_start PLS_INTEGER;
    l_kids_end PLS_INTEGER;
  BEGIN
    -- Find /Kids position
    l_kids_start := INSTR(l_pages_obj, '/Kids');

    IF l_kids_start > 0 THEN
      -- Find opening bracket after /Kids
      l_kids_start := INSTR(l_pages_obj, '[', l_kids_start);

      IF l_kids_start > 0 THEN
        -- Find closing bracket
        l_kids_end := INSTR(l_pages_obj, ']', l_kids_start);

        IF l_kids_end > l_kids_start THEN
          -- Extract content between brackets
          l_kids_array := SUBSTR(l_pages_obj, l_kids_start + 1, l_kids_end - l_kids_start - 1);
          log_message(3, 'Kids array extracted via INSTR: ' || l_kids_array);
        END IF;
      END IF;
    END IF;
  END;

  -- Fallback error if not found
  IF l_kids_array IS NULL THEN
    log_message(1, 'ERROR: Kids array not found. Pages object content:');
    log_message(1, SUBSTR(l_pages_obj, 1, 500));
    log_message(1, 'Object length: ' || LENGTH(l_pages_obj));
    raise_application_error(-20811, 'Kids array not found in Pages object');
  END IF;

  log_message(3, 'Kids array extracted: ' || l_kids_array);

  -- Parse each page object reference
  l_pos := 1;
  LOOP
    -- Find next number in Kids array
    l_page_obj_id := TO_NUMBER(
      REGEXP_SUBSTR(l_kids_array, '([0-9]+)\s+0\s+R', 1, l_pos, NULL, 1)
    );

    EXIT WHEN l_page_obj_id IS NULL;

    -- Store page object ID
    g_page_info_table(l_page_num).page_obj_id := l_page_obj_id;

    l_page_num := l_page_num + 1;
    l_pos := l_pos + 1;
  END LOOP;

  log_message(3, 'Parsed page tree: ' || g_page_info_table.COUNT || ' pages');
END parse_page_tree;

--------------------------------------------------------------------------------
-- get_page_object_id: Get object ID for specific page number
--------------------------------------------------------------------------------
FUNCTION get_page_object_id(p_page_number PLS_INTEGER) RETURN PLS_INTEGER IS
BEGIN
  -- Ensure page tree is parsed
  IF g_page_info_table.COUNT = 0 THEN
    parse_page_tree();
  END IF;

  -- Validate page number
  IF p_page_number < 1 OR p_page_number > g_page_info_table.COUNT THEN
    raise_application_error(-20812,
      'Invalid page number: ' || p_page_number ||
      '. Valid range: 1-' || g_page_info_table.COUNT);
  END IF;

  RETURN g_page_info_table(p_page_number).page_obj_id;
END get_page_object_id;

--------------------------------------------------------------------------------
-- extract_page_info: Extract detailed page information
--------------------------------------------------------------------------------
PROCEDURE extract_page_info(p_page_number PLS_INTEGER) IS
  l_page_obj_id PLS_INTEGER;
  l_page_obj CLOB;
  l_media_box VARCHAR2(100);
  l_rotate NUMBER;
  l_resources_id PLS_INTEGER;
  l_contents_id PLS_INTEGER;
BEGIN
  l_page_obj_id := get_page_object_id(p_page_number);

  -- Check if already parsed
  IF g_page_info_table(p_page_number).media_box IS NOT NULL THEN
    RETURN;  -- Already parsed
  END IF;

  -- Get page object
  l_page_obj := get_pdf_object(l_page_obj_id);

  -- Extract MediaBox: /MediaBox [0 0 612 792]
  -- Using INSTR/SUBSTR for Oracle compatibility (REGEXP_SUBSTR fails in some Oracle versions)
  DECLARE
    l_start PLS_INTEGER;
    l_end PLS_INTEGER;
    l_tmp VARCHAR2(100);
  BEGIN
    l_start := INSTR(l_page_obj, '/MediaBox');
    IF l_start > 0 THEN
      l_start := INSTR(l_page_obj, '[', l_start);
      IF l_start > 0 THEN
        l_end := INSTR(l_page_obj, ']', l_start);
        IF l_end > l_start THEN
          l_media_box := TRIM(SUBSTR(l_page_obj, l_start + 1, l_end - l_start - 1));
        END IF;
      END IF;
    END IF;

    -- Extract Rotate: /Rotate 90
    l_start := INSTR(l_page_obj, '/Rotate');
    IF l_start > 0 THEN
      l_tmp := SUBSTR(l_page_obj, l_start + 7, 10);
      l_tmp := TRIM(REGEXP_REPLACE(l_tmp, '[^0-9].*', ''));
      IF l_tmp IS NOT NULL THEN
        l_rotate := TO_NUMBER(l_tmp);
      END IF;
    END IF;

    -- Extract Resources object ID: /Resources 2 0 R
    l_start := INSTR(l_page_obj, '/Resources');
    IF l_start > 0 THEN
      l_tmp := SUBSTR(l_page_obj, l_start + 10, 20);
      l_tmp := TRIM(REGEXP_REPLACE(l_tmp, '[^0-9].*', ''));
      IF l_tmp IS NOT NULL THEN
        l_resources_id := TO_NUMBER(l_tmp);
      END IF;
    END IF;

    -- Extract Contents object ID: /Contents 4 0 R
    l_start := INSTR(l_page_obj, '/Contents');
    IF l_start > 0 THEN
      l_tmp := SUBSTR(l_page_obj, l_start + 9, 20);
      l_tmp := TRIM(REGEXP_REPLACE(l_tmp, '[^0-9].*', ''));
      IF l_tmp IS NOT NULL THEN
        l_contents_id := TO_NUMBER(l_tmp);
      END IF;
    END IF;
  END;

  -- If MediaBox not found in Page object, check parent Pages object (inheritance)
  IF l_media_box IS NULL AND g_pages_obj_id IS NOT NULL THEN
    DECLARE
      l_pages_obj CLOB;
      l_start PLS_INTEGER;
      l_end PLS_INTEGER;
    BEGIN
      l_pages_obj := get_pdf_object(g_pages_obj_id);
      l_start := INSTR(l_pages_obj, '/MediaBox');
      IF l_start > 0 THEN
        l_start := INSTR(l_pages_obj, '[', l_start);
        IF l_start > 0 THEN
          l_end := INSTR(l_pages_obj, ']', l_start);
          IF l_end > l_start THEN
            l_media_box := TRIM(SUBSTR(l_pages_obj, l_start + 1, l_end - l_start - 1));
            log_message(3, 'MediaBox inherited from parent Pages: ' || l_media_box);
          END IF;
        END IF;
      END IF;
    END;
  END IF;

  -- Default MediaBox to Letter size if still not found
  IF l_media_box IS NULL THEN
    l_media_box := '0 0 612 792';
    log_message(3, 'MediaBox defaulting to Letter size: ' || l_media_box);
  END IF;

  IF l_rotate IS NULL THEN
    l_rotate := 0;  -- Default: no rotation
  END IF;

  -- Store extracted info
  g_page_info_table(p_page_number).media_box := l_media_box;
  g_page_info_table(p_page_number).rotate := l_rotate;
  g_page_info_table(p_page_number).resources_id := l_resources_id;
  g_page_info_table(p_page_number).contents_id := l_contents_id;

  log_message(3, 'Extracted page ' || p_page_number || ' info: MediaBox=' || l_media_box);
END extract_page_info;
/*******************************************************************************
* Function: GetPageInfo
* Description: Returns information about a specific page as JSON
*******************************************************************************/
function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T is
  l_page_info JSON_OBJECT_T;
  l_page_num pls_integer;
  l_unit VARCHAR2(10);
begin
  l_page_info := JSON_OBJECT_T();

  -- If a PDF is loaded (Phase 4 parser mode), return loaded PDF page info
  IF g_loaded_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(g_loaded_pdf) > 0 THEN
    l_page_num := NVL(p_page_number, 1);

    -- Validate page number for loaded PDF
    IF l_page_num < 1 OR l_page_num > g_loaded_page_count THEN
      raise_application_error(-20812,
        'Invalid page number: ' || l_page_num || '. Valid range: 1-' || g_loaded_page_count);
    END IF;

    -- Extract page info if not already done
    extract_page_info(l_page_num);

    -- Build JSON response for loaded PDF
    l_page_info.put('pageNumber', l_page_num);
    l_page_info.put('pageObjectId', g_page_info_table(l_page_num).page_obj_id);
    l_page_info.put('mediaBox', g_page_info_table(l_page_num).media_box);
    l_page_info.put('rotation', NVL(g_page_info_table(l_page_num).rotate, 0));
    l_page_info.put('resourcesObjectId', g_page_info_table(l_page_num).resources_id);
    l_page_info.put('contentsObjectId', g_page_info_table(l_page_num).contents_id);

    log_message(c_LOG_DEBUG, 'GetPageInfo: Returned loaded PDF info for page ' || l_page_num);
    RETURN l_page_info;
  END IF;

  -- Generation mode: return info about page being generated
  -- Determine which page to query
  if p_page_number is null then
    l_page_num := g_current_page;
  else
    l_page_num := p_page_number;
  end if;

  -- Validate page number
  if l_page_num < 1 or l_page_num > g_current_page then
    raise_application_error(-20106,
      'Invalid page number: ' || l_page_num || '. Must be between 1 and ' || g_current_page);
  end if;

  -- Check if page exists in modern collection
  if not g_pages.exists(l_page_num) then
    raise_application_error(-20106,
      'Page ' || l_page_num || ' not found in page collection');
  end if;

  -- Page number
  l_page_info.put('number', l_page_num);

  -- Page format
  l_page_info.put('width', g_pages(l_page_num).format.width);
  l_page_info.put('height', g_pages(l_page_num).format.height);

  -- Orientation
  l_page_info.put('orientation', case g_pages(l_page_num).orientation
    when 'P' then 'Portrait'
    when 'L' then 'Landscape'
    else 'Unknown'
  end);

  -- Rotation
  l_page_info.put('rotation', g_pages(l_page_num).rotation);

  -- Format name (if standard)
  if g_pages(l_page_num).format.width = 210 and g_pages(l_page_num).format.height = 297 then
    l_page_info.put('format', 'A4');
  elsif g_pages(l_page_num).format.width = 216 and g_pages(l_page_num).format.height = 279 then
    l_page_info.put('format', 'Letter');
  elsif g_pages(l_page_num).format.width = 216 and g_pages(l_page_num).format.height = 356 then
    l_page_info.put('format', 'Legal');
  elsif g_pages(l_page_num).format.width = 297 and g_pages(l_page_num).format.height = 420 then
    l_page_info.put('format', 'A3');
  elsif g_pages(l_page_num).format.width = 148 and g_pages(l_page_num).format.height = 210 then
    l_page_info.put('format', 'A5');
  else
    l_page_info.put('format', 'Custom');
  end if;

  -- Unit
  if k = c_SCALE_PT then
    l_unit := 'pt';
  elsif k = c_SCALE_MM then
    l_unit := 'mm';
  elsif k = c_SCALE_CM then
    l_unit := 'cm';
  elsif k = c_SCALE_IN then
    l_unit := 'in';
  else
    l_unit := 'unknown';
  end if;
  l_page_info.put('unit', l_unit);

  log_message(c_LOG_DEBUG, 'GetPageInfo: Returned info for page ' || l_page_num);

  return l_page_info;

exception
  when others then
    log_message(c_LOG_ERROR, 'Error in GetPageInfo: ' || sqlerrm);
    raise;
end GetPageInfo;
procedure AddQRCode(
  p_x number,
  p_y number,
  p_size number,
  p_data varchar2,
  p_format varchar2 default 'TEXT',
  p_error_correction varchar2 default 'M'
) is
  -- A construcao da matriz mora em PL_FPDF_UTIL.qr_matriz: la nao se desenha
  -- nada, e o que sai e uma matriz de 0 e 1. Aqui so se pinta o quadradinho.
  l_mat  PL_FPDF_UTIL.tqr;
  l_n    pls_integer;
  l_ver  pls_integer;
  l_mask pls_integer;
  l_mod  number;
begin
  if p_size is null or p_size <= 0 then
    raise_application_error(-20871, 'AddQRCode: tamanho deve ser maior que zero.');
  end if;

  -- p_format nao altera a codificacao (todo conteudo vai em modo byte); serve
  -- para documentar a intencao e e registrado no log.
  PL_FPDF_UTIL.qr_matriz(p_data, p_error_correction, l_mat, l_n, l_ver, l_mask);

  -- desenha: um retangulo preenchido por modulo escuro
  l_mod := p_size / l_n;
  SetFillColor(0, 0, 0);
  for r in 0..l_n-1 loop
    for c in 0..l_n-1 loop
      if l_mat(r * l_n + c) = 1 then
        Rect(p_x + c * l_mod, p_y + r * l_mod, l_mod, l_mod, 'F');
      end if;
    end loop;
  end loop;

  log_message(c_LOG_INFO,
    'QR Code ' || upper(nvl(p_format,'TEXT')) || ' v' || l_ver ||
    ' mascara ' || l_mask || ' (' || l_n || 'x' || l_n || ' modulos) em (' ||
    p_x || ',' || p_y || ')');
exception
  when others then
    log_message(c_LOG_ERROR, 'Erro ao gerar QR Code: ' || sqlerrm);
    raise;
end AddQRCode;
procedure AddBarcode(
  p_x number,
  p_y number,
  p_width number,
  p_height number,
  p_code varchar2,
  p_type varchar2 default 'CODE128',
  p_show_text boolean default true
) is
  l_type varchar2(20) := upper(trim(nvl(p_type, 'CODE128')));
  l_mods varchar2(32767);
  l_n    pls_integer;
  l_mw   number;
  l_ini  pls_integer;
  l_i    pls_integer;
  l_old_family word;
  l_old_style  word;
  l_old_size   number;
begin
  if p_code is null then
    raise_application_error(-20880, 'AddBarcode: codigo vazio.');
  end if;
  if nvl(p_width, 0) <= 0 or nvl(p_height, 0) <= 0 then
    raise_application_error(-20881, 'AddBarcode: largura e altura devem ser positivas.');
  end if;

  -- o padrao vem pronto do utilitario; aqui so se desenha
  l_mods := PL_FPDF_UTIL.bc_padrao(p_code, l_type);

  l_n  := length(l_mods);
  l_mw := p_width / l_n;

  SetFillColor(0, 0, 0);
  -- agrupa modulos escuros consecutivos num unico retangulo
  l_i := 1;
  while l_i <= l_n loop
    if substr(l_mods, l_i, 1) = '1' then
      l_ini := l_i;
      while l_i <= l_n and substr(l_mods, l_i, 1) = '1' loop
        l_i := l_i + 1;
      end loop;
      Rect(p_x + (l_ini - 1) * l_mw, p_y, (l_i - l_ini) * l_mw, p_height, 'F');
    else
      l_i := l_i + 1;
    end if;
  end loop;

  if p_show_text then
    l_old_family := FontFamily;
    l_old_style  := FontStyle;
    l_old_size   := FontSizePt;
    SetFont('Arial', '', 8);
    Text(p_x, p_y + p_height + 3, p_code);
    if l_old_family is not null then
      SetFont(l_old_family, l_old_style, l_old_size);
    end if;
  end if;

  log_message(c_LOG_INFO,
    'Codigo de barras ' || l_type || ' (' || l_n || ' modulos) em (' ||
    p_x || ',' || p_y || ')');
exception
  when others then
    log_message(c_LOG_ERROR, 'Erro ao gerar codigo de barras: ' || sqlerrm);
    raise;
end AddBarcode;

--------------------------------------------------------------------------------
-- PHASE 4: PDF PARSER - Helper Functions and Core Implementation
--------------------------------------------------------------------------------

/*******************************************************************************
 * HELPER FUNCTIONS - PDF PARSING
 ******************************************************************************/

--------------------------------------------------------------------------------
-- extract_number_after_pattern: Extract number after pattern
--------------------------------------------------------------------------------
FUNCTION extract_number_after_pattern(
  p_text VARCHAR2,
  p_pattern VARCHAR2
) RETURN PLS_INTEGER IS
  l_pos PLS_INTEGER;
  l_num_str VARCHAR2(20);
BEGIN
  l_pos := INSTR(p_text, p_pattern);

  IF l_pos = 0 THEN
    RETURN NULL;
  END IF;

  -- Extract digits after pattern
  l_num_str := REGEXP_SUBSTR(
    SUBSTR(p_text, l_pos + LENGTH(p_pattern)),
    '^\s*([0-9]+)',
    1, 1, NULL, 1
  );

  RETURN TO_NUMBER(l_num_str);
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END extract_number_after_pattern;

/*******************************************************************************
 * PHASE 4.1: PDF READING - BASIC PARSING
 ******************************************************************************/

--------------------------------------------------------------------------------
-- parse_pdf_header: Extract PDF version
--------------------------------------------------------------------------------
FUNCTION parse_pdf_header(p_pdf BLOB) RETURN VARCHAR2 IS
  l_header VARCHAR2(50);
  l_pos PLS_INTEGER;
  l_version VARCHAR2(10);
BEGIN
  l_header := read_blob_chunk(p_pdf, 1, 50);

  -- Validate header %PDF-
  IF NOT l_header LIKE '%PDF-%' THEN
    raise_application_error(-20801,
      'Invalid PDF header. Expected %PDF-x.x, got: ' || SUBSTR(l_header, 1, 20));
  END IF;

  -- Extract version (e.g., "1.7" from "%PDF-1.7")
  -- Using INSTR/SUBSTR instead of REGEXP for better Oracle compatibility
  l_pos := INSTR(l_header, '%PDF-');
  IF l_pos > 0 THEN
    l_version := SUBSTR(l_header, l_pos + 5, 3);  -- Extract "1.7" after "%PDF-"
    -- Validate version format (digit.digit)
    IF SUBSTR(l_version, 1, 1) BETWEEN '0' AND '9'
       AND SUBSTR(l_version, 2, 1) = '.'
       AND SUBSTR(l_version, 3, 1) BETWEEN '0' AND '9' THEN
      RETURN l_version;
    END IF;
  END IF;

  -- Fallback: return default version if parsing fails
  RETURN '1.4';
END parse_pdf_header;

--------------------------------------------------------------------------------
-- find_startxref: Locate xref table offset
--------------------------------------------------------------------------------
FUNCTION find_startxref(p_pdf BLOB) RETURN PLS_INTEGER IS
  l_file_size PLS_INTEGER;
  l_tail VARCHAR2(2048);
  l_offset PLS_INTEGER;
BEGIN
  l_file_size := DBMS_LOB.GETLENGTH(p_pdf);

  -- Read last 2KB of file
  l_tail := read_blob_chunk(p_pdf, GREATEST(1, l_file_size - 2047), 2048);

  -- Extract number after "startxref"
  l_offset := extract_number_after_pattern(l_tail, 'startxref');

  IF l_offset IS NULL THEN
    raise_application_error(-20802, 'startxref not found in PDF');
  END IF;

  RETURN l_offset;
END find_startxref;

--------------------------------------------------------------------------------
-- parse_xref_table: Parse cross-reference table
--------------------------------------------------------------------------------
PROCEDURE parse_xref_table(p_pdf BLOB, p_xref_offset PLS_INTEGER) IS
  l_xref_section VARCHAR2(32767);
  l_line VARCHAR2(100);
  l_obj_start PLS_INTEGER;
  l_obj_count PLS_INTEGER;
  l_obj_id PLS_INTEGER;
  l_offset PLS_INTEGER;
  l_generation PLS_INTEGER;
  l_flag CHAR(1);
  l_pos PLS_INTEGER := 1;
  l_line_end PLS_INTEGER;
  l_actual_offset PLS_INTEGER := p_xref_offset;
  l_search_chunk VARCHAR2(32767);
  l_xref_pos PLS_INTEGER;
BEGIN
  g_xref_table.DELETE;
  g_objstm_body.DELETE;

  -- Read xref section at reported offset
  l_xref_section := read_blob_chunk(p_pdf, p_xref_offset + 1, 32767);

  -- PDF 1.5+: o que startxref aponta nao e a tabela de texto, e um objeto
  -- /Type /XRef comprimido. Este parser — o antigo, que le UMA subsecao e nao
  -- segue /Prev — nao tem como ler isso. Quem sabe e o pdf_src_load, que ja
  -- percorre a cadeia inteira, entende o hibrido e materializa os objetos de
  -- dentro dos object streams. Delegar evita uma segunda implementacao do mesmo
  -- formato, que e como as duas acabariam divergindo.
  IF l_xref_section IS NULL OR NOT l_xref_section LIKE 'xref%' THEN
    DECLARE
      l_src pdf_source_rec;
    BEGIN
      l_src := pdf_src_load(p_pdf);
      g_xref_table  := l_src.xref;
      g_objstm_body := l_src.objstm;
      log_message(3, 'xref em stream: ' || g_xref_table.COUNT
                     || ' objetos, ' || g_objstm_body.COUNT
                     || ' vindos de object stream');
      RETURN;
    EXCEPTION
      WHEN OTHERS THEN
        -- Malformado de verdade sobe: a mensagem diz o que esta errado, e
        -- deixar cair no caminho antigo trocaria isso por 'Invalid xref table'.
        IF SQLCODE IN (-20843, -20847, -20848) THEN
          RAISE;
        END IF;
        -- Nao era xref em stream (startxref errado, arquivo truncado): segue
        -- para a busca do 'xref' logo abaixo, que e o que existia antes.
        g_xref_table.DELETE;
        g_objstm_body.DELETE;
        log_message(3, 'nao e xref em stream (' || SQLERRM
                       || '); tentando achar a tabela classica');
    END;
  END IF;

  -- If xref not found at exact position, search nearby
  IF l_xref_section IS NULL OR NOT l_xref_section LIKE 'xref%' THEN
    -- Search backward from end of file for 'xref' keyword
    DECLARE
      l_file_size PLS_INTEGER := DBMS_LOB.GETLENGTH(p_pdf);
      l_search_start PLS_INTEGER;
      l_chunk_size PLS_INTEGER := LEAST(l_file_size, 32767);
    BEGIN
      l_search_start := GREATEST(1, l_file_size - l_chunk_size + 1);
      l_search_chunk := read_blob_chunk(p_pdf, l_search_start, l_chunk_size);

      -- Find last occurrence of 'xref' followed by newline
      l_xref_pos := 0;
      DECLARE
        l_tmp PLS_INTEGER;
      BEGIN
        l_tmp := INSTR(l_search_chunk, 'xref' || CHR(10));
        WHILE l_tmp > 0 LOOP
          -- Make sure this is a standalone 'xref', not part of 'startxref'
          IF l_tmp = 1 OR SUBSTR(l_search_chunk, l_tmp - 1, 1) = CHR(10) THEN
            l_xref_pos := l_tmp;
          END IF;
          l_tmp := INSTR(l_search_chunk, 'xref' || CHR(10), l_tmp + 1);
        END LOOP;
      END;

      IF l_xref_pos > 0 THEN
        l_actual_offset := l_search_start + l_xref_pos - 2; -- Convert to 0-based
        l_xref_section := read_blob_chunk(p_pdf, l_actual_offset + 1, 32767);
        -- Update global offset so parse_trailer uses correct position
        g_xref_offset := l_actual_offset;
        log_message(2, 'xref found at offset ' || l_actual_offset ||
                       ' (startxref said ' || p_xref_offset || ')');
      END IF;
    END;

    IF l_xref_section IS NULL OR NOT l_xref_section LIKE 'xref%' THEN
      raise_application_error(-20803, 'Invalid xref table at offset ' || p_xref_offset);
    END IF;
  END IF;

  -- A secao xref classica cabe na janela?
  --
  -- read_blob_chunk entrega no maximo 32767 bytes e TRUNCA calado. Cada
  -- entrada ocupa 20 bytes, entao acima de ~1638 objetos o resto da tabela
  -- sumia: os objetos que faltavam nunca entravam no g_xref_table, e o erro
  -- que chegava ao chamador era '-20804 Root object not found in trailer' —
  -- que manda procurar defeito no Catalog de um PDF intacto.
  --
  -- A guarda fica AQUI, e nao junto de cada leitura, porque este e o ponto
  -- onde os dois caminhos (offset do startxref e busca para tras) convergem
  -- com a secao ja em maos. A primeira tentativa de conserto ficou so no
  -- caminho de busca, que num PDF bem formado nunca e alcancado — e o teste
  -- de regressao continuou falhando com o mesmo -20804.
  --
  -- Num arquivo bem formado o 'trailer' vem logo depois da tabela. Nao
  -- encontra-lo, havendo mais bytes no arquivo do que a janela leu, so pode
  -- ser truncamento.
  IF INSTR(l_xref_section, 'trailer') = 0
     AND DBMS_LOB.GETLENGTH(p_pdf) - l_actual_offset > 32767 THEN
    raise_application_error(-20841,
      'Secao xref classica em ' || l_actual_offset || ': o trailer nao cabe ' ||
      'nos 32767 bytes que se le de uma vez (mais de ~1638 entradas, ' ||
      (DBMS_LOB.GETLENGTH(p_pdf) - l_actual_offset) || ' bytes ate o fim do ' ||
      'arquivo). Este PDF nao e suportado pela leitura de xref classica.');
  END IF;

  -- Normalize line endings: remove CR, keep LF only
  l_xref_section := REPLACE(l_xref_section, CHR(13), '');

  -- Skip line "xref"
  l_pos := INSTR(l_xref_section, CHR(10)) + 1;

  -- Line 2: subsection header "0 N" where N = number of objects
  l_line_end := INSTR(l_xref_section, CHR(10), l_pos);
  l_line := TRIM(SUBSTR(l_xref_section, l_pos, l_line_end - l_pos));
  l_obj_start := TO_NUMBER(REGEXP_SUBSTR(l_line, '^[0-9]+'));
  l_obj_count := TO_NUMBER(REGEXP_SUBSTR(l_line, '[0-9]+$'));
  l_pos := l_line_end + 1;

  -- Process xref entries
  l_obj_id := l_obj_start;

  FOR idx IN 1..l_obj_count LOOP
    EXIT WHEN l_pos > LENGTH(l_xref_section);

    l_line_end := INSTR(l_xref_section, CHR(10), l_pos);
    IF l_line_end = 0 THEN
      l_line_end := LENGTH(l_xref_section) + 1;
    END IF;

    l_line := SUBSTR(l_xref_section, l_pos, l_line_end - l_pos);
    EXIT WHEN l_line LIKE 'trailer%';

    -- Format: "NNNNNNNNNN GGGGG f/n"
    -- Example: "0000000015 00000 n"
    IF LENGTH(l_line) >= 18 THEN
      l_offset := TO_NUMBER(TRIM(SUBSTR(l_line, 1, 10)));
      l_generation := TO_NUMBER(TRIM(SUBSTR(l_line, 12, 5)));
      l_flag := SUBSTR(l_line, 18, 1);

      -- Store only objects in use ('n')
      IF l_flag = 'n' THEN
        g_xref_table(l_obj_id).offset := l_offset;
        g_xref_table(l_obj_id).generation := l_generation;
        g_xref_table(l_obj_id).in_use := TRUE;
      END IF;
    END IF;

    l_obj_id := l_obj_id + 1;
    l_pos := l_line_end + 1;
  END LOOP;

  log_message(3, 'Parsed xref table: ' || g_xref_table.COUNT || ' objects');
END parse_xref_table;

--------------------------------------------------------------------------------
-- parse_trailer: Extract trailer information
--------------------------------------------------------------------------------
PROCEDURE parse_trailer(p_pdf BLOB, p_xref_offset PLS_INTEGER) IS
  l_trailer VARCHAR2(4000);
  l_root_id PLS_INTEGER;
BEGIN
  -- Read trailer (after xref)
  l_trailer := read_blob_chunk(p_pdf, p_xref_offset + 1, 4000);

  -- Extract /Root object ID
  l_root_id := TO_NUMBER(
    REGEXP_SUBSTR(l_trailer, '/Root\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_root_id IS NULL THEN
    raise_application_error(-20804, 'Root object not found in trailer');
  END IF;

  g_root_obj_id := l_root_id;

  log_message(3, 'Trailer parsed: Root=' || g_root_obj_id);
END parse_trailer;

--------------------------------------------------------------------------------
-- count_pages: Count pages in PDF
--------------------------------------------------------------------------------
FUNCTION count_pages RETURN PLS_INTEGER IS
  l_catalog CLOB;
  l_pages_id PLS_INTEGER;
  l_pages_obj CLOB;
  l_count PLS_INTEGER;
BEGIN
  -- 1. Get Catalog
  l_catalog := get_pdf_object(g_root_obj_id);

  -- 2. Extract Pages object ID
  l_pages_id := TO_NUMBER(
    REGEXP_SUBSTR(l_catalog, '/Pages\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_pages_id IS NULL THEN
    raise_application_error(-20807, 'Pages not found in Catalog');
  END IF;

  -- 3. Get Pages object
  l_pages_obj := get_pdf_object(l_pages_id);

  -- 4. Extract /Count
  l_count := TO_NUMBER(
    REGEXP_SUBSTR(l_pages_obj, '/Count\s+([0-9]+)', 1, 1, NULL, 1)
  );

  IF l_count IS NULL THEN
    raise_application_error(-20808, 'Count not found in Pages object');
  END IF;

  RETURN l_count;
END count_pages;

/*******************************************************************************
 * PUBLIC APIs - PHASE 4
 ******************************************************************************/

--------------------------------------------------------------------------------
-- LoadPDF: Load existing PDF into memory
--------------------------------------------------------------------------------
PROCEDURE LoadPDF(p_pdf_blob BLOB) IS
BEGIN
  log_message(3, 'Loading PDF...');

  -- Validate
  IF p_pdf_blob IS NULL OR DBMS_LOB.GETLENGTH(p_pdf_blob) < 100 THEN
    raise_application_error(-20800, 'Invalid PDF: NULL or too small');
  END IF;

  -- Clear previous state
  g_loaded_pdf := p_pdf_blob;
  g_object_cache.DELETE;
  g_xref_table.DELETE;

  -- Parse header
  g_pdf_version := parse_pdf_header(p_pdf_blob);
  log_message(3, 'PDF version: ' || g_pdf_version);

  -- Find xref
  g_xref_offset := find_startxref(p_pdf_blob);
  log_message(3, 'startxref value: ' || g_xref_offset);

  -- Parse xref table (may correct g_xref_offset if startxref was inaccurate)
  parse_xref_table(p_pdf_blob, g_xref_offset);

  -- Parse trailer (search from the actual xref position)
  parse_trailer(p_pdf_blob, g_xref_offset);

  -- Count pages
  g_loaded_page_count := count_pages();

  -- Parse page tree
  parse_page_tree();

  log_message(2, 'PDF loaded successfully: ' || g_loaded_page_count || ' pages, version ' || g_pdf_version);

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error loading PDF: ' || SQLERRM);
    RAISE;
END LoadPDF;

--------------------------------------------------------------------------------
-- GetPageCount: Get number of pages in loaded PDF
--------------------------------------------------------------------------------
FUNCTION GetPageCount RETURN PLS_INTEGER IS
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  RETURN g_loaded_page_count;
END GetPageCount;

--------------------------------------------------------------------------------
-- GetPDFInfo: Get information about loaded PDF
--------------------------------------------------------------------------------
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T IS
  l_info JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  l_info.put('version', g_pdf_version);
  l_info.put('pageCount', g_loaded_page_count);
  l_info.put('fileSize', DBMS_LOB.GETLENGTH(g_loaded_pdf));
  l_info.put('objectCount', g_xref_table.COUNT);
  l_info.put('rootObjectId', g_root_obj_id);

  RETURN l_info;
END GetPDFInfo;

--------------------------------------------------------------------------------
-- RotatePage: Rotate a specific page
--------------------------------------------------------------------------------
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER) IS
  l_valid_rotations VARCHAR2(20) := '0,90,180,270';
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Validate rotation value
  IF INSTR(l_valid_rotations, TO_CHAR(p_rotation)) = 0 THEN
    raise_application_error(-20813,
      'Invalid rotation: ' || p_rotation || '. Valid values: 0, 90, 180, 270');
  END IF;

  -- Extract page info if not already done
  extract_page_info(p_page_number);

  -- Update rotation in cache
  g_page_info_table(p_page_number).rotate := p_rotation;

  log_message(3, 'Page ' || p_page_number || ' rotation set to ' || p_rotation || ' degrees');

  -- Mark PDF as modified
  g_pdf_modified := TRUE;
END RotatePage;

--------------------------------------------------------------------------------
-- RemovePage: Mark a page for removal
--------------------------------------------------------------------------------
PROCEDURE RemovePage(p_page_number PLS_INTEGER) IS
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Validate page number
  IF p_page_number < 1 OR p_page_number > g_loaded_page_count THEN
    raise_application_error(-20812,
      'Invalid page number: ' || p_page_number ||
      '. Valid range: 1-' || g_loaded_page_count);
  END IF;

  -- Check if already removed
  IF g_removed_pages.EXISTS(p_page_number) AND g_removed_pages(p_page_number) THEN
    raise_application_error(-20814,
      'Page ' || p_page_number || ' is already marked for removal');
  END IF;

  -- Mark page as removed
  g_removed_pages(p_page_number) := TRUE;
  g_pdf_modified := TRUE;

  log_message(3, 'Page ' || p_page_number || ' marked for removal');
END RemovePage;

--------------------------------------------------------------------------------
-- GetActivePageCount: Get count of non-removed pages
--------------------------------------------------------------------------------
FUNCTION GetActivePageCount RETURN PLS_INTEGER IS
  l_count PLS_INTEGER := 0;
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Count pages that are not marked for removal
  FOR i IN 1..g_loaded_page_count LOOP
    IF NOT (g_removed_pages.EXISTS(i) AND g_removed_pages(i)) THEN
      l_count := l_count + 1;
    END IF;
  END LOOP;

  RETURN l_count;
END GetActivePageCount;

--------------------------------------------------------------------------------
-- IsPageRemoved: Check if page is marked for removal
--------------------------------------------------------------------------------
FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN IS
BEGIN
  IF g_removed_pages.EXISTS(p_page_number) THEN
    RETURN g_removed_pages(p_page_number);
  END IF;
  RETURN FALSE;
END IsPageRemoved;

--------------------------------------------------------------------------------
-- IsPDFModified: Check if PDF has been modified
--------------------------------------------------------------------------------
FUNCTION IsPDFModified RETURN BOOLEAN IS
BEGIN
  RETURN g_pdf_modified;
END IsPDFModified;

--------------------------------------------------------------------------------
-- split_string: Split a string by delimiter into a collection (pure PL/SQL)
-- Replaces apex_string.split for Oracle environments without APEX
--------------------------------------------------------------------------------
FUNCTION split_string(
  p_string VARCHAR2,
  p_delimiter VARCHAR2 DEFAULT ','
) RETURN tv4000 IS
  l_result tv4000;
  l_str VARCHAR2(4000);
  l_idx PLS_INTEGER := 1;
  l_delim_pos PLS_INTEGER;
BEGIN
  IF p_string IS NULL THEN
    RETURN l_result;
  END IF;

  l_str := p_string;

  LOOP
    l_delim_pos := INSTR(l_str, p_delimiter);

    IF l_delim_pos > 0 THEN
      l_result(l_idx) := SUBSTR(l_str, 1, l_delim_pos - 1);
      l_str := SUBSTR(l_str, l_delim_pos + LENGTH(p_delimiter));
      l_idx := l_idx + 1;
    ELSE
      l_result(l_idx) := l_str;
      EXIT;
    END IF;
  END LOOP;

  RETURN l_result;
END split_string;

--------------------------------------------------------------------------------
-- parse_page_range: Parse page range string to determine applicable pages
--------------------------------------------------------------------------------
FUNCTION parse_page_range(
  p_range VARCHAR2,
  p_total_pages PLS_INTEGER
) RETURN VARCHAR2 IS
  l_result VARCHAR2(4000);
  l_range VARCHAR2(100);
  l_parts tv4000;
  l_item VARCHAR2(50);
  l_from PLS_INTEGER;
  l_to PLS_INTEGER;
  l_dash_pos PLS_INTEGER;
BEGIN
  l_range := UPPER(TRIM(p_range));

  -- Handle 'ALL'
  IF l_range = 'ALL' THEN
    FOR i IN 1..p_total_pages LOOP
      l_result := l_result || i || ',';
    END LOOP;
    RETURN RTRIM(l_result, ',');
  END IF;

  -- Handle comma-separated list: '1,3,5' or ranges '1-5,7,9-12'
  l_parts := split_string(l_range, ',');

  FOR i IN 1..l_parts.COUNT LOOP
    l_item := TRIM(l_parts(i));
    l_dash_pos := INSTR(l_item, '-');

    IF l_dash_pos > 0 THEN
      -- Range: '1-5'
      l_from := TO_NUMBER(SUBSTR(l_item, 1, l_dash_pos - 1));
      l_to := TO_NUMBER(SUBSTR(l_item, l_dash_pos + 1));

      -- Validate range
      IF l_from < 1 OR l_to > p_total_pages OR l_from > l_to THEN
        raise_application_error(-20815,
          'Invalid page range: ' || l_item || '. Valid pages: 1-' || p_total_pages);
      END IF;

      -- Add all pages in range
      FOR j IN l_from..l_to LOOP
        l_result := l_result || j || ',';
      END LOOP;
    ELSE
      -- Single page: '3'
      l_from := TO_NUMBER(l_item);

      IF l_from < 1 OR l_from > p_total_pages THEN
        raise_application_error(-20815,
          'Invalid page number: ' || l_from || '. Valid pages: 1-' || p_total_pages);
      END IF;

      l_result := l_result || l_from || ',';
    END IF;
  END LOOP;

  RETURN RTRIM(l_result, ',');
EXCEPTION
  WHEN VALUE_ERROR THEN
    raise_application_error(-20815,
      'Invalid page range format: ' || p_range);
END parse_page_range;

--------------------------------------------------------------------------------
-- is_page_in_range: Check if page is in parsed range
--------------------------------------------------------------------------------
FUNCTION is_page_in_range(
  p_page_number PLS_INTEGER,
  p_parsed_range VARCHAR2
) RETURN BOOLEAN IS
  l_page_str VARCHAR2(20);
BEGIN
  l_page_str := ',' || p_parsed_range || ',';
  RETURN INSTR(l_page_str, ',' || p_page_number || ',') > 0;
END is_page_in_range;

--------------------------------------------------------------------------------
-- AddWatermark: Add watermark to specified pages
--------------------------------------------------------------------------------
PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_pages VARCHAR2 DEFAULT 'ALL',
  p_font VARCHAR2 DEFAULT 'Helvetica',
  p_size NUMBER DEFAULT 48,
  p_color VARCHAR2 DEFAULT 'gray'
) IS
  l_watermark watermark_rec;
  l_parsed_range VARCHAR2(4000);
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Validate parameters
  IF p_text IS NULL OR LENGTH(TRIM(p_text)) = 0 THEN
    raise_application_error(-20816, 'Watermark text cannot be empty');
  END IF;

  IF p_opacity < 0 OR p_opacity > 1 THEN
    raise_application_error(-20817,
      'Opacity must be between 0 and 1. Got: ' || p_opacity);
  END IF;

  IF p_rotation NOT IN (0, 45, 90, 135, 180, 225, 270, 315) THEN
    raise_application_error(-20818,
      'Rotation must be 0, 45, 90, 135, 180, 225, 270, or 315 degrees');
  END IF;

  -- Parse page range
  l_parsed_range := parse_page_range(p_pages, g_loaded_page_count);

  -- Create watermark record
  g_watermark_count := g_watermark_count + 1;
  l_watermark.text := p_text;
  l_watermark.opacity := p_opacity;
  l_watermark.rotation := p_rotation;
  l_watermark.page_range := l_parsed_range;
  l_watermark.font_name := p_font;
  l_watermark.font_size := p_size;
  l_watermark.color := p_color;

  -- Store watermark
  g_watermarks(g_watermark_count) := l_watermark;

  -- Mark PDF as modified
  g_pdf_modified := TRUE;

  log_message(3, 'Watermark added: "' || p_text || '" on pages: ' || p_pages);
END AddWatermark;

--------------------------------------------------------------------------------
-- GetWatermarks: Get list of applied watermarks as JSON
--------------------------------------------------------------------------------
FUNCTION GetWatermarks RETURN JSON_ARRAY_T IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_watermark JSON_OBJECT_T;
  l_idx PLS_INTEGER;
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Build JSON array of watermarks
  l_idx := g_watermarks.FIRST;
  WHILE l_idx IS NOT NULL LOOP
    l_watermark := JSON_OBJECT_T();
    l_watermark.put('id', l_idx);
    l_watermark.put('text', g_watermarks(l_idx).text);
    l_watermark.put('opacity', g_watermarks(l_idx).opacity);
    l_watermark.put('rotation', g_watermarks(l_idx).rotation);
    l_watermark.put('pageRange', g_watermarks(l_idx).page_range);
    l_watermark.put('font', g_watermarks(l_idx).font_name);
    l_watermark.put('fontSize', g_watermarks(l_idx).font_size);
    l_watermark.put('color', g_watermarks(l_idx).color);

    l_result.append(l_watermark);
    l_idx := g_watermarks.NEXT(l_idx);
  END LOOP;

  RETURN l_result;
END GetWatermarks;

--------------------------------------------------------------------------------
-- OutputModifiedPDF: gera o PDF com as alteracoes aplicadas
--
-- Usa o copiador de objetos: as paginas mantidas chegam intactas (conteudo,
-- fontes, imagens, anotacoes), sem re-renderizacao. Aplica remocao de paginas
-- (RemovePage) e rotacao (RotatePage).
--
-- Marcas d'agua e overlays sao desenhados no fluxo de conteudo: cada pagina que
-- os tem ganha um objeto de stream com os operadores e um /Resources proprio.
-- Ver ovl_* e scripts/pdfoverlay_reference/ (validado contra o MuPDF).
--------------------------------------------------------------------------------
FUNCTION OutputModifiedPDF RETURN BLOB IS
  l_srcs   pdf_source_list;
  l_sel    tpi2;
  l_sel1   tpi;
  l_result BLOB;
  l_oid    PLS_INTEGER;
  l_kept   PLS_INTEGER := 0;
  l_ops    VARCHAR2(32767);
  l_gs     VARCHAR2(4000);
  l_fontes VARCHAR2(4000);
  l_vistos tbool;                  -- opacidades ja declaradas nesta pagina
  TYPE tbool_v IS TABLE OF BOOLEAN INDEX BY VARCHAR2(20);
  l_fontes_vistas tbool_v;         -- fontes ja declaradas nesta pagina
  l_larg   NUMBER;
  l_alt    NUMBER;
  l_idx    PLS_INTEGER;
  l_chave  VARCHAR2(50);
  l_r      NUMBER;
  l_g      NUMBER;
  l_b      NUMBER;

  -- Converte a cor pedida em RGB de 0 a 1. AddWatermark aceita nome ('gray'),
  -- OverlayText aceita hexadecimal ('FF0000'); os dois passam por aqui.
  -- O buffer acompanha o parametro. Era VARCHAR2(10), e uma cor de 11
  -- caracteres ('lightsteelblue', qualquer nome que o chamador invente)
  -- estourava ORA-06502 NA DECLARACAO — antes do CASE, que trataria o
  -- desconhecido caindo no padrao. Derrubava o OutputModifiedPDF inteiro.
  PROCEDURE cor(p_cor IN VARCHAR2, p_pad IN NUMBER DEFAULT 0.5) IS
    l_h VARCHAR2(32767) := UPPER(TRIM(p_cor));
  BEGIN
    l_r := p_pad; l_g := p_pad; l_b := p_pad;
    CASE l_h
      WHEN 'BLACK'  THEN l_r := 0;   l_g := 0;   l_b := 0;
      WHEN 'GRAY'   THEN l_r := 0.5; l_g := 0.5; l_b := 0.5;
      WHEN 'GREY'   THEN l_r := 0.5; l_g := 0.5; l_b := 0.5;
      WHEN 'RED'    THEN l_r := 1;   l_g := 0;   l_b := 0;
      WHEN 'GREEN'  THEN l_r := 0;   l_g := 0.5; l_b := 0;
      WHEN 'BLUE'   THEN l_r := 0;   l_g := 0;   l_b := 1;
      ELSE
        IF REGEXP_LIKE(l_h, '^[0-9A-F]{6}$') THEN
          l_r := TO_NUMBER(SUBSTR(l_h, 1, 2), 'XX') / 255;
          l_g := TO_NUMBER(SUBSTR(l_h, 3, 2), 'XX') / 255;
          l_b := TO_NUMBER(SUBSTR(l_h, 5, 2), 'XX') / 255;
        END IF;
    END CASE;
  END cor;

  -- Largura e altura a partir do /MediaBox.
  --
  -- Nao usa get_page_dimensions de proposito: aquela faz TO_NUMBER sem
  -- co_nls_num — numa sessao com virgula decimal, '595.28' rebentaria — e toma
  -- os elementos 3 e 4 como se a caixa comecasse sempre em 0 0, o que nao vale
  -- para PDFs com caixa deslocada.
  PROCEDURE medidas(p_mb IN VARCHAR2) IS
    l_p tv4000;
    FUNCTION n(p IN VARCHAR2) RETURN NUMBER IS
    BEGIN
      RETURN TO_NUMBER(TRIM(p), 'TM9', co_nls_num);
    EXCEPTION
      WHEN OTHERS THEN RETURN NULL;
    END;
  BEGIN
    l_larg := 612; l_alt := 792;                     -- Letter, como ultimo caso
    l_p := split_string(TRIM(REGEXP_REPLACE(
             REPLACE(REPLACE(NVL(p_mb, ''), '['), ']'), '\s+', ' ')), ' ');
    IF l_p.COUNT >= 4 AND n(l_p(1)) IS NOT NULL AND n(l_p(3)) IS NOT NULL THEN
      l_larg := ABS(n(l_p(3)) - n(l_p(1)));
      l_alt  := ABS(n(l_p(4)) - n(l_p(2)));
    END IF;
    IF NVL(l_larg, 0) <= 0 THEN l_larg := 612; END IF;
    IF NVL(l_alt, 0)  <= 0 THEN l_alt  := 792; END IF;
  END medidas;

  -- Cada opacidade distinta vira um /ExtGState proprio; sem isso o carimbo
  -- opaco herdaria a transparencia da marca d'agua desenhada antes dele.
  PROCEDURE usar_opacidade(p_opac IN NUMBER) IS
    l_k PLS_INTEGER := ROUND(LEAST(GREATEST(NVL(p_opac, 1), 0), 1) * 100);
  BEGIN
    IF NOT l_vistos.EXISTS(l_k) THEN
      l_vistos(l_k) := TRUE;
      l_gs := l_gs || ' ' || ovl_gs_entrada(p_opac);
    END IF;
  END usar_opacidade;

  -- O /Font da pagina declara so as fontes que a pagina realmente usa. Declarar
  -- as seis combinacoes sempre funcionaria, mas encheria o /Resources de fontes
  -- mortas em todo documento com um carimbo.
  PROCEDURE usar_fonte(p_fonte IN VARCHAR2, p_bold IN BOOLEAN) IS
    l_n VARCHAR2(20) := ovl_fonte_nome(p_fonte, p_bold);
  BEGIN
    IF NOT l_fontes_vistas.EXISTS(l_n) THEN
      l_fontes_vistas(l_n) := TRUE;
      l_fontes := l_fontes || ' ' || ovl_fonte_entrada(p_fonte, p_bold);
    END IF;
  END usar_fonte;
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  IF NOT g_pdf_modified THEN
    raise_application_error(-20819,
      'PDF has not been modified. No changes to output.');
  END IF;

  log_message(2, 'Generating modified PDF...');

  l_srcs(1) := pdf_src_load(g_loaded_pdf);

  IF l_srcs(1).pages.COUNT != g_loaded_page_count THEN
    log_message(3, 'Recontagem de paginas: ' || l_srcs(1).pages.COUNT ||
                ' (cache: ' || g_loaded_page_count || ')');
  END IF;

  -- paginas mantidas, na ordem original
  FOR i IN 1 .. l_srcs(1).pages.COUNT LOOP
    IF NOT IsPageRemoved(i) THEN
      l_kept := l_kept + 1;
      l_sel1(l_kept) := i;
    END IF;
  END LOOP;

  IF l_kept = 0 THEN
    raise_application_error(-20820,
      'Cannot generate PDF: All pages have been removed');
  END IF;
  l_sel(1) := l_sel1;

  -- rotacoes pedidas por RotatePage
  FOR i IN 1 .. l_srcs(1).pages.COUNT LOOP
    IF g_page_info_table.EXISTS(i) AND g_page_info_table(i).rotate IS NOT NULL THEN
      l_oid := l_srcs(1).pages(i);
      l_srcs(1).rot_force(l_oid) :=
        TO_CHAR(MOD(NVL(g_page_info_table(i).rotate, 0), 360), 'TM9', co_nls_num);
    END IF;
  END LOOP;

  -- ── marcas d'agua e overlays ───────────────────────────────────────────────
  -- Os operadores sao montados por pagina e entregues ao pdf_assemble, que cria
  -- o objeto do fluxo e o /Resources proprio da pagina.
  FOR i IN 1 .. l_srcs(1).pages.COUNT LOOP
    IF NOT IsPageRemoved(i) THEN
      l_oid := l_srcs(1).pages(i);
      l_ops := NULL;
      l_gs  := NULL;
      l_fontes := NULL;
      l_vistos.DELETE;
      l_fontes_vistas.DELETE;
      medidas(CASE WHEN l_srcs(1).media.EXISTS(l_oid)
                   THEN l_srcs(1).media(l_oid) END);

      l_idx := g_watermarks.FIRST;
      WHILE l_idx IS NOT NULL LOOP
        IF is_page_in_range(i, g_watermarks(l_idx).page_range) THEN
          cor(g_watermarks(l_idx).color, 0.5);
          usar_opacidade(g_watermarks(l_idx).opacity);
          l_ops := l_ops || ovl_marca_dagua(
                     g_watermarks(l_idx).text, l_larg, l_alt,
                     NVL(g_watermarks(l_idx).rotation, 45),
                     NVL(g_watermarks(l_idx).font_size, 48),
                     NVL(g_watermarks(l_idx).opacity, 0.3), l_r, l_g, l_b);
          usar_fonte('Helvetica', FALSE);   -- a marca d'agua sai sempre nela
        END IF;
        l_idx := g_watermarks.NEXT(l_idx);
      END LOOP;

      -- zOrder: quem tem valor maior fica POR CIMA, e no PDF isso significa
      -- ser desenhado por ULTIMO. Antes a ordem era a da tabela indexada por
      -- VARCHAR2, ou seja, alfabetica pelo id gerado — o zOrder era aceito e
      -- ignorado. Ordenacao por insercao: sao poucos overlays por pagina.
      DECLARE
        l_ord tv32k;
        l_tmp VARCHAR2(50);
      BEGIN
        l_chave := g_overlays.FIRST;
        WHILE l_chave IS NOT NULL LOOP
          IF g_overlays(l_chave).page_number = i THEN
            l_ord(l_ord.COUNT + 1) := l_chave;
          END IF;
          l_chave := g_overlays.NEXT(l_chave);
        END LOOP;
        FOR a IN 1 .. l_ord.COUNT - 1 LOOP
          FOR b IN 1 .. l_ord.COUNT - a LOOP
            IF NVL(g_overlays(l_ord(b)).z_order, 100)
               > NVL(g_overlays(l_ord(b + 1)).z_order, 100) THEN
              l_tmp := l_ord(b);
              l_ord(b) := l_ord(b + 1);
              l_ord(b + 1) := l_tmp;
            END IF;
          END LOOP;
        END LOOP;

        FOR k IN 1 .. l_ord.COUNT LOOP
          l_chave := l_ord(k);
          usar_opacidade(g_overlays(l_chave).opacity);
          IF g_overlays(l_chave).overlay_type = 'TEXT' THEN
            cor(g_overlays(l_chave).color, 0);
            l_ops := l_ops || ovl_texto(
                       g_overlays(l_chave).x, g_overlays(l_chave).y,
                       -- content e CLOB: SUBSTRB nele da ORA-22998 num banco
                       -- com charset multibyte (AL32UTF8, o caso normal).
                       -- DBMS_LOB.SUBSTR trabalha em caracteres e devolve
                       -- VARCHAR2, que e o que os operadores precisam.
                       DBMS_LOB.SUBSTR(g_overlays(l_chave).content, 3000, 1),
                       NVL(g_overlays(l_chave).font_size, 12),
                       NVL(g_overlays(l_chave).rotation, 0),
                       NVL(g_overlays(l_chave).opacity, 1), l_r, l_g, l_b,
                       g_overlays(l_chave).font_name,
                       NVL(g_overlays(l_chave).bold, FALSE),
                       g_overlays(l_chave).align,
                       g_overlays(l_chave).width);
            usar_fonte(g_overlays(l_chave).font_name,
                       NVL(g_overlays(l_chave).bold, FALSE));
          ELSE
            DECLARE
              l_i    PLS_INTEGER := NVL(l_srcs(1).ovl_img_dic.LAST, 0) + 1;
              l_dic  VARCHAR2(32767);
              l_dat  BLOB;
              l_mdic VARCHAR2(32767);
              l_mdat BLOB;
              l_pw   NUMBER;
              l_ph   NUMBER;
              l_w    NUMBER := g_overlays(l_chave).width;
              l_h    NUMBER := g_overlays(l_chave).height;
            BEGIN
              DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);
              ovl_img_xobject(g_overlays(l_chave).image_blob,
                              l_dic, l_dat, l_pw, l_ph, l_mdic, l_mdat);

              -- Sem largura/altura vale o tamanho em pixels a 72 dpi; com uma
              -- so, a outra sai da proporcao — desenhar 100x100 fixo, como
              -- fazia o gerador antigo, deformava qualquer imagem.
              IF l_w IS NULL AND l_h IS NULL THEN
                l_w := l_pw; l_h := l_ph;
              ELSIF l_w IS NULL THEN
                l_w := l_h * l_pw / GREATEST(l_ph, 1);
              ELSIF l_h IS NULL THEN
                l_h := l_w * l_ph / GREATEST(l_pw, 1);
              ELSIF NVL(g_overlays(l_chave).maintain_aspect, FALSE) THEN
                -- cabe na caixa pedida sem distorcer
                DECLARE
                  l_f NUMBER := LEAST(l_w / GREATEST(l_pw, 1),
                                      l_h / GREATEST(l_ph, 1));
                BEGIN
                  l_w := l_pw * l_f; l_h := l_ph * l_f;
                END;
              END IF;

              l_srcs(1).ovl_img_dic(l_i) := l_dic;
              l_srcs(1).ovl_img_dat(l_i) := l_dat;
              l_srcs(1).ovl_img_pag(l_i) := l_oid;
              IF l_mdic IS NOT NULL THEN
                l_srcs(1).ovl_msk_dic(l_i) := l_mdic;
                l_srcs(1).ovl_msk_dat(l_i) := l_mdat;
              END IF;
              l_ops := l_ops || ovl_imagem(
                         g_overlays(l_chave).x, g_overlays(l_chave).y,
                         l_w, l_h, 'ImgPLFPDF' || l_i,
                         NVL(g_overlays(l_chave).rotation, 0),
                         NVL(g_overlays(l_chave).opacity, 1));
            END;
          END IF;
        END LOOP;
      END;

      IF l_ops IS NOT NULL THEN
        l_srcs(1).ovl_ops(l_oid) := l_ops;
        l_srcs(1).ovl_res(l_oid) := ovl_recursos_texto(l_gs, l_fontes);
      END IF;
    END IF;
  END LOOP;

  log_message(3, 'Active pages: ' || l_kept || ' of ' || l_srcs(1).pages.COUNT);

  l_result := pdf_assemble(l_srcs, l_sel);

  log_message(2, 'Modified PDF generated: ' || DBMS_LOB.GETLENGTH(l_result) || ' bytes');
  RETURN l_result;
EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error generating modified PDF: ' || SQLERRM);
    RAISE;
END OutputModifiedPDF;

/*******************************************************************************
* FlateDecode: descomprime um stream /FlateDecode do PDF
*
* Publica porque e util por si — quem tem um stream comprimido de qualquer
* origem consegue le-lo — e porque torna o inflate testavel sem gancho de
* teste na API.
*******************************************************************************/
FUNCTION FlateDecode(
  p_stream    IN BLOB,
  p_max_bytes IN PLS_INTEGER DEFAULT 8388608
) RETURN BLOB IS
  l_out BLOB;
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_out, TRUE);
  PL_FPDF_UTIL.inflate(p_stream, l_out, p_max_bytes);
  RETURN l_out;
EXCEPTION
  WHEN OTHERS THEN
    IF l_out IS NOT NULL THEN
      BEGIN DBMS_LOB.FREETEMPORARY(l_out); EXCEPTION WHEN OTHERS THEN NULL; END;
    END IF;
    RAISE;
END FlateDecode;

--------------------------------------------------------------------------------
-- FlateEncode: o outro lado do FlateDecode
--
-- Chega aqui um BLOB e sai um fluxo zlib que qualquer leitor de PDF aceita.
-- Quem faz o trabalho e PL_FPDF_UTIL.deflate, junto do inflate; esta e so a porta.
--------------------------------------------------------------------------------
FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB IS
  l_saida BLOB;
  l_ent   BLOB := p_data;
  l_vazio BOOLEAN := p_data IS NULL;
BEGIN
  -- NVL(p_data, EMPTY_BLOB()) NAO compila: o NVL do PL/SQL nao tem sobrecarga
  -- para LOB (PLS-00306). Entrada nula vira um LOB temporario vazio na mao.
  IF l_vazio THEN
    DBMS_LOB.CREATETEMPORARY(l_ent, TRUE);
  END IF;
  DBMS_LOB.CREATETEMPORARY(l_saida, TRUE);
  PL_FPDF_UTIL.deflate(l_ent, l_saida);
  IF l_vazio THEN
    DBMS_LOB.FREETEMPORARY(l_ent);
  END IF;
  RETURN l_saida;
END FlateEncode;

--------------------------------------------------------------------------------
-- ClearPDFCache: Clear loaded PDF and free memory
--------------------------------------------------------------------------------
PROCEDURE ClearPDFCache IS
BEGIN
  g_loaded_pdf := NULL;
  g_object_cache.DELETE;
  g_xref_table.DELETE;
  -- Junto com a xref, sempre: um corpo materializado que sobrevivesse ao
  -- documento faria get_pdf_object devolver o objeto do PDF ANTERIOR, com um
  -- dicionario perfeitamente valido e nenhum erro.
  g_objstm_body.DELETE;
  g_page_info_table.DELETE;
  g_removed_pages.DELETE;
  g_watermarks.DELETE;
  g_overlays.DELETE;
  g_pdf_version := NULL;
  g_xref_offset := NULL;
  g_root_obj_id := NULL;
  g_loaded_page_count := 0;
  g_watermark_count := 0;
  g_overlay_count := 0;
  g_pdf_modified := FALSE;

  -- Documentos carregados por LoadPDFWithID: sem isto, ClearPDFCache limpava o
  -- PDF unico (LoadPDF) mas deixava a colecao multi-documento intacta, e
  -- GetLoadedPDFs continuava listando tudo depois de "limpar o cache".
  g_loaded_pdfs.DELETE;
  g_loaded_pdf_count := 0;

  log_message(3, 'PDF cache cleared (including overlays and loaded PDFs)');
END ClearPDFCache;

--------------------------------------------------------------------------------
-- PHASE 4.5: TEXT & IMAGE OVERLAY IMPLEMENTATION
--------------------------------------------------------------------------------

/*******************************************************************************
* OverlayText: Add text overlay at specific position
*******************************************************************************/
PROCEDURE OverlayText(
  p_page_number IN PLS_INTEGER,
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) IS
  l_overlay overlay_rec;
  l_overlay_id VARCHAR2(50);
  l_page_height NUMBER;
  l_page_info JSON_OBJECT_T;
BEGIN
  -- Validate PDF loaded
  IF g_loaded_pdf IS NULL OR DBMS_LOB.GETLENGTH(g_loaded_pdf) = 0 THEN
    
    RAISE_APPLICATION_ERROR(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Validate page number
  IF p_page_number < 1 OR p_page_number > g_loaded_page_count THEN
    RAISE_APPLICATION_ERROR(-20810, 'Invalid page number: ' || p_page_number ||
                        '. PDF has ' || g_loaded_page_count || ' pages.');
  END IF;

  -- Validate coordinates
  IF p_x < 0 OR p_y < 0 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid position coordinates. X and Y must be >= 0.');
  END IF;

  -- Generate overlay ID
  g_overlay_count := g_overlay_count + 1;
  l_overlay_id := 'OVL_TEXT_' || LPAD(g_overlay_count, 5, '0');

  -- Initialize overlay record
  l_overlay.overlay_id := l_overlay_id;
  l_overlay.overlay_type := 'TEXT';
  l_overlay.page_number := p_page_number;
  l_overlay.x := p_x;
  l_overlay.y := p_y;
  l_overlay.content := p_text;
  l_overlay.created_date := SYSTIMESTAMP;

  -- Parse options or set defaults
  IF p_options IS NOT NULL THEN
    l_overlay.font_name := NVL(p_options.get_string('font'), 'Helvetica');
    l_overlay.font_size := NVL(p_options.get_number('fontSize'), 12);
    l_overlay.color := NVL(p_options.get_string('color'), '000000');
    l_overlay.opacity := NVL(p_options.get_number('opacity'), 1.0);
    l_overlay.rotation := NVL(p_options.get_number('rotation'), 0);
    l_overlay.align := NVL(p_options.get_string('align'), 'left');
    l_overlay.bold := NVL(p_options.get_boolean('bold'), FALSE);
    l_overlay.z_order := NVL(p_options.get_number('zOrder'), 100);
    l_overlay.width := p_options.get_number('width'); -- Can be NULL
  ELSE
    l_overlay.font_name := 'Helvetica';
    l_overlay.font_size := 12;
    l_overlay.color := '000000';
    l_overlay.opacity := 1.0;
    l_overlay.rotation := 0;
    l_overlay.align := 'left';
    l_overlay.bold := FALSE;
    l_overlay.z_order := 100;
    l_overlay.width := NULL;
  END IF;

  -- Validate opacity
  IF l_overlay.opacity < 0 OR l_overlay.opacity > 1 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid opacity. Must be between 0.0 and 1.0.');
  END IF;

  -- Store overlay
  g_overlays(l_overlay_id) := l_overlay;
  g_pdf_modified := TRUE;

  log_message(3, 'Text overlay added: ' || l_overlay_id || ' on page ' || p_page_number);
END OverlayText;

/*******************************************************************************
* OverlayImage: Add image overlay at specific position
*******************************************************************************/
PROCEDURE OverlayImage(
  p_page_number IN PLS_INTEGER,
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER DEFAULT NULL,
  p_height IN NUMBER DEFAULT NULL,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) IS
  l_overlay overlay_rec;
  l_overlay_id VARCHAR2(50);
  l_img_signature RAW(8);
BEGIN
  -- Validate PDF loaded
  IF g_loaded_pdf IS NULL OR DBMS_LOB.GETLENGTH(g_loaded_pdf) = 0 THEN
    RAISE_APPLICATION_ERROR(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Validate page number
  IF p_page_number < 1 OR p_page_number > g_loaded_page_count THEN
    RAISE_APPLICATION_ERROR(-20810, 'Invalid page number: ' || p_page_number);
  END IF;

  -- Validate coordinates
  IF p_x < 0 OR p_y < 0 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid position coordinates. X and Y must be >= 0.');
  END IF;

  -- Validate image blob
  IF p_image_blob IS NULL OR DBMS_LOB.GETLENGTH(p_image_blob) = 0 THEN
    RAISE_APPLICATION_ERROR(-20823, 'Invalid image: image blob is empty or NULL.');
  END IF;

  -- Validate image format (JPEG or PNG)
  l_img_signature := DBMS_LOB.SUBSTR(p_image_blob, 8, 1);
  IF l_img_signature != c_PNG_SIGNATURE AND
     DBMS_LOB.SUBSTR(p_image_blob, 2, 1) != c_JPEG_SOI THEN
    RAISE_APPLICATION_ERROR(-20823, 'Invalid image format. Only JPEG and PNG are supported.');
  END IF;

  -- Validate dimensions
  IF p_width IS NOT NULL AND p_width <= 0 THEN
    RAISE_APPLICATION_ERROR(-20824, 'Invalid width. Must be > 0 or NULL for original size.');
  END IF;
  IF p_height IS NOT NULL AND p_height <= 0 THEN
    RAISE_APPLICATION_ERROR(-20824, 'Invalid height. Must be > 0 or NULL for original size.');
  END IF;

  -- Generate overlay ID
  g_overlay_count := g_overlay_count + 1;
  l_overlay_id := 'OVL_IMG_' || LPAD(g_overlay_count, 5, '0');

  -- Initialize overlay record
  l_overlay.overlay_id := l_overlay_id;
  l_overlay.overlay_type := 'IMAGE';
  l_overlay.page_number := p_page_number;
  l_overlay.x := p_x;
  l_overlay.y := p_y;
  l_overlay.width := p_width;
  l_overlay.height := p_height;
  l_overlay.image_blob := p_image_blob;
  l_overlay.created_date := SYSTIMESTAMP;

  -- Parse options or set defaults
  IF p_options IS NOT NULL THEN
    l_overlay.opacity := NVL(p_options.get_number('opacity'), 1.0);
    l_overlay.rotation := NVL(p_options.get_number('rotation'), 0);
    l_overlay.maintain_aspect := NVL(p_options.get_boolean('maintainAspect'), TRUE);
    l_overlay.scale_to_fit := NVL(p_options.get_boolean('scaleToFit'), FALSE);
    l_overlay.z_order := NVL(p_options.get_number('zOrder'), 100);
  ELSE
    l_overlay.opacity := 1.0;
    l_overlay.rotation := 0;
    l_overlay.maintain_aspect := TRUE;
    l_overlay.scale_to_fit := FALSE;
    l_overlay.z_order := 100;
  END IF;

  -- Validate opacity
  IF l_overlay.opacity < 0 OR l_overlay.opacity > 1 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid opacity. Must be between 0.0 and 1.0.');
  END IF;

  -- Store overlay
  g_overlays(l_overlay_id) := l_overlay;
  g_pdf_modified := TRUE;

  log_message(3, 'Image overlay added: ' || l_overlay_id || ' on page ' || p_page_number);
END OverlayImage;

/*******************************************************************************
* GetOverlays: Get list of applied overlays
*******************************************************************************/
FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T
IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_overlay_obj JSON_OBJECT_T;
  l_overlay overlay_rec;
  l_key VARCHAR2(50);
BEGIN
  -- Validate PDF loaded
  IF g_loaded_pdf IS NULL OR DBMS_LOB.GETLENGTH(g_loaded_pdf) = 0 THEN
    RAISE_APPLICATION_ERROR(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  -- Iterate through overlays
  l_key := g_overlays.FIRST;
  WHILE l_key IS NOT NULL LOOP
    l_overlay := g_overlays(l_key);

    -- Filter by page if specified
    IF p_page_number IS NULL OR l_overlay.page_number = p_page_number THEN
      l_overlay_obj := JSON_OBJECT_T();
      l_overlay_obj.put('overlayId', l_overlay.overlay_id);
      l_overlay_obj.put('overlayType', l_overlay.overlay_type);
      l_overlay_obj.put('pageNumber', l_overlay.page_number);
      l_overlay_obj.put('x', l_overlay.x);
      l_overlay_obj.put('y', l_overlay.y);
      l_overlay_obj.put('opacity', l_overlay.opacity);
      l_overlay_obj.put('rotation', l_overlay.rotation);
      l_overlay_obj.put('zOrder', l_overlay.z_order);

      IF l_overlay.overlay_type = 'TEXT' THEN
        l_overlay_obj.put('content', l_overlay.content);
        l_overlay_obj.put('fontName', l_overlay.font_name);
        l_overlay_obj.put('fontSize', l_overlay.font_size);
        l_overlay_obj.put('color', l_overlay.color);
        l_overlay_obj.put('align', l_overlay.align);
        IF l_overlay.width IS NOT NULL THEN
          l_overlay_obj.put('width', l_overlay.width);
        END IF;
      ELSIF l_overlay.overlay_type = 'IMAGE' THEN
        IF l_overlay.width IS NOT NULL THEN
          l_overlay_obj.put('width', l_overlay.width);
        END IF;
        IF l_overlay.height IS NOT NULL THEN
          l_overlay_obj.put('height', l_overlay.height);
        END IF;
        l_overlay_obj.put('maintainAspect', l_overlay.maintain_aspect);
        l_overlay_obj.put('scaleToFit', l_overlay.scale_to_fit);
        l_overlay_obj.put('imageSize', DBMS_LOB.GETLENGTH(l_overlay.image_blob));
      END IF;

      l_result.append(l_overlay_obj);
    END IF;

    l_key := g_overlays.NEXT(l_key);
  END LOOP;

  RETURN l_result;
END GetOverlays;

/*******************************************************************************
* RemoveOverlay: Remove specific overlay by ID
*******************************************************************************/
PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2) IS
BEGIN
  IF NOT g_overlays.EXISTS(p_overlay_id) THEN
    RAISE_APPLICATION_ERROR(-20825, 'Overlay not found: ' || p_overlay_id);
  END IF;

  g_overlays.DELETE(p_overlay_id);
  log_message(3, 'Overlay removed: ' || p_overlay_id);
END RemoveOverlay;

/*******************************************************************************
* ClearOverlays: Clear all overlays (optionally for specific page)
*******************************************************************************/
PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL) IS
  l_key VARCHAR2(50);
  l_overlay overlay_rec;
  TYPE key_list IS TABLE OF VARCHAR2(50);
  l_keys_to_delete key_list := key_list();
BEGIN
  IF p_page_number IS NULL THEN
    -- Clear all overlays
    g_overlays.DELETE;
    g_overlay_count := 0;
    log_message(3, 'All overlays cleared');
  ELSE
    -- Clear overlays for specific page
    l_key := g_overlays.FIRST;
    WHILE l_key IS NOT NULL LOOP
      l_overlay := g_overlays(l_key);
      IF l_overlay.page_number = p_page_number THEN
        l_keys_to_delete.EXTEND;
        l_keys_to_delete(l_keys_to_delete.COUNT) := l_key;
      END IF;
      l_key := g_overlays.NEXT(l_key);
    END LOOP;

    -- Delete collected keys
    FOR i IN 1..l_keys_to_delete.COUNT LOOP
      g_overlays.DELETE(l_keys_to_delete(i));
    END LOOP;

    log_message(3, 'Overlays cleared for page ' || p_page_number ||
                   ': ' || l_keys_to_delete.COUNT || ' overlays removed');
  END IF;
END ClearOverlays;

--------------------------------------------------------------------------------
-- PHASE 4.6: PDF MERGE & SPLIT IMPLEMENTATION
--------------------------------------------------------------------------------

/*******************************************************************************
* LoadPDFWithID: Load PDF with identifier for multi-document operations
*******************************************************************************/
PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
) IS
  l_doc pdf_document_rec;
BEGIN
  -- Validate PDF ID
  IF p_pdf_id IS NULL OR LENGTH(TRIM(p_pdf_id)) = 0 THEN
    RAISE_APPLICATION_ERROR(-20830, 'Invalid PDF ID: cannot be empty or NULL');
  END IF;

  IF LENGTH(p_pdf_id) > 50 THEN
    RAISE_APPLICATION_ERROR(-20830, 'Invalid PDF ID: maximum length is 50 characters');
  END IF;

  -- Check if already loaded
  IF g_loaded_pdfs.EXISTS(p_pdf_id) THEN
    RAISE_APPLICATION_ERROR(-20828, 'PDF ID already loaded: ' || p_pdf_id);
  END IF;

  -- Check max PDFs limit
  IF g_loaded_pdf_count >= c_max_loaded_pdfs THEN
    RAISE_APPLICATION_ERROR(-20829, 'Maximum loaded PDFs exceeded. Limit is ' ||
                c_max_loaded_pdfs || ' PDFs. Unload some PDFs first.');
  END IF;

  -- Validate BLOB
  IF p_pdf_blob IS NULL OR DBMS_LOB.GETLENGTH(p_pdf_blob) = 0 THEN
    RAISE_APPLICATION_ERROR(-20830, 'Invalid PDF: blob is empty or NULL');
  END IF;

  -- Initialize document record
  l_doc.pdf_id := p_pdf_id;
  l_doc.pdf_blob := p_pdf_blob;
  l_doc.file_size := DBMS_LOB.GETLENGTH(p_pdf_blob);
  l_doc.loaded_date := SYSTIMESTAMP;

  -- Parse PDF to get page count
  BEGIN
    -- Save current state
    DECLARE
      l_saved_blob BLOB := g_loaded_pdf;
      l_saved_count PLS_INTEGER := g_loaded_page_count;
    BEGIN
      -- Parse this PDF
      LoadPDF(p_pdf_blob);
      l_doc.page_count := g_loaded_page_count;
      l_doc.pdf_version := g_pdf_version;

      -- Restore previous state if needed
      IF l_saved_blob IS NOT NULL THEN
        g_loaded_pdf := l_saved_blob;
        g_loaded_page_count := l_saved_count;
      END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      log_message(2, 'Warning: Could not parse PDF ' || p_pdf_id || ': ' || SQLERRM);
      l_doc.page_count := 0;
  END;

  -- Store document
  g_loaded_pdfs(p_pdf_id) := l_doc;
  g_loaded_pdf_count := g_loaded_pdf_count + 1;

  log_message(3, 'PDF loaded with ID: ' || p_pdf_id ||
              ' (' || l_doc.page_count || ' pages, ' ||
              ROUND(l_doc.file_size/1024, 1) || ' KB)');
END LoadPDFWithID;

/*******************************************************************************
* GetLoadedPDFs: List all loaded PDFs
*******************************************************************************/
FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_pdf_obj JSON_OBJECT_T;
  l_doc pdf_document_rec;
  l_key VARCHAR2(50);
BEGIN
  -- Iterate through loaded PDFs
  l_key := g_loaded_pdfs.FIRST;
  WHILE l_key IS NOT NULL LOOP
    l_doc := g_loaded_pdfs(l_key);

    l_pdf_obj := JSON_OBJECT_T();
    l_pdf_obj.put('pdfId', l_doc.pdf_id);
    l_pdf_obj.put('pageCount', l_doc.page_count);
    l_pdf_obj.put('fileSize', l_doc.file_size);
    l_pdf_obj.put('loadedDate', TO_CHAR(l_doc.loaded_date, 'YYYY-MM-DD"T"HH24:MI:SS'));

    IF l_doc.pdf_version IS NOT NULL THEN
      l_pdf_obj.put('pdfVersion', l_doc.pdf_version);
    END IF;

    l_result.append(l_pdf_obj);
    l_key := g_loaded_pdfs.NEXT(l_key);
  END LOOP;

  RETURN l_result;
END GetLoadedPDFs;

/*******************************************************************************
* UnloadPDF: Remove PDF from memory
*******************************************************************************/
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2) IS
BEGIN
  IF NOT g_loaded_pdfs.EXISTS(p_pdf_id) THEN
    RAISE_APPLICATION_ERROR(-20831, 'PDF ID not found: ' || p_pdf_id);
  END IF;

  g_loaded_pdfs.DELETE(p_pdf_id);
  g_loaded_pdf_count := g_loaded_pdf_count - 1;

  log_message(3, 'PDF unloaded: ' || p_pdf_id);
END UnloadPDF;

--------------------------------------------------------------------------------
--                    COPIADOR DE OBJETOS PDF (nivel de bytes)                 --
--                                                                             --
-- Base comum de MergePDFs, SplitPDF, ExtractPages e OutputModifiedPDF.        --
-- Referencia validada contra o MuPDF: scripts/pdfmerge_reference/             --
--------------------------------------------------------------------------------

-- Declaracao antecipada: a varredura da arvore de paginas e recursiva
PROCEDURE pdf_walk_pages(
  p_src   IN OUT NOCOPY pdf_source_rec,
  p_oid   IN PLS_INTEGER,
  p_media IN VARCHAR2,
  p_res   IN VARCHAR2,
  p_crop  IN VARCHAR2,
  p_rot   IN VARCHAR2,
  p_depth IN PLS_INTEGER
);

--------------------------------------------------------------------------------
-- pdf_is_ws / pdf_is_alnum: classificacao de um unico byte ASCII
--------------------------------------------------------------------------------
FUNCTION pdf_is_ws(p_c IN VARCHAR2) RETURN BOOLEAN IS
BEGIN
  RETURN p_c IN (' ', CHR(9), CHR(10), CHR(13), CHR(12), CHR(0));
END pdf_is_ws;

FUNCTION pdf_is_alnum(p_c IN VARCHAR2) RETURN BOOLEAN IS
BEGIN
  RETURN p_c BETWEEN '0' AND '9'
      OR p_c BETWEEN 'A' AND 'Z'
      OR p_c BETWEEN 'a' AND 'z';
END pdf_is_alnum;

--------------------------------------------------------------------------------
-- pdf_app: acrescenta texto ASCII ao BLOB de saida
--------------------------------------------------------------------------------
PROCEDURE pdf_app(p_out IN OUT NOCOPY BLOB, p_txt IN VARCHAR2) IS
  l_raw RAW(32767);
BEGIN
  IF p_txt IS NULL OR LENGTHB(p_txt) = 0 THEN
    RETURN;
  END IF;
  l_raw := UTL_RAW.CAST_TO_RAW(p_txt);
  DBMS_LOB.WRITEAPPEND(p_out, UTL_RAW.LENGTH(l_raw), l_raw);
END pdf_app;

--------------------------------------------------------------------------------
-- pdf_app_clob: acrescenta um CLOB ASCII ao BLOB de saida, em blocos
--------------------------------------------------------------------------------
PROCEDURE pdf_app_clob(p_out IN OUT NOCOPY BLOB, p_src IN CLOB) IS
  l_len PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_pos PLS_INTEGER := 1;
  l_amt PLS_INTEGER;
BEGIN
  WHILE l_pos <= l_len LOOP
    l_amt := LEAST(16000, l_len - l_pos + 1);
    pdf_app(p_out, DBMS_LOB.SUBSTR(p_src, l_amt, l_pos));
    l_pos := l_pos + l_amt;
  END LOOP;
END pdf_app_clob;

--------------------------------------------------------------------------------
-- pdf_read: le bytes do PDF de origem preservando-os 1:1 no VARCHAR2
--
-- p_off e um offset de 0 (como na xref); DBMS_LOB conta a partir de 1.
-- UTL_RAW.CAST_TO_VARCHAR2 nao converte charset: os bytes ficam intactos.
-- Por isso toda a analise usa SUBSTRB/INSTRB/LENGTHB (semantica de bytes).
--------------------------------------------------------------------------------
FUNCTION pdf_read(p_doc IN BLOB, p_off IN PLS_INTEGER, p_len IN PLS_INTEGER)
  RETURN VARCHAR2 IS
BEGIN
  IF p_len <= 0 THEN
    RETURN NULL;
  END IF;
  RETURN UTL_RAW.CAST_TO_VARCHAR2(
           DBMS_LOB.SUBSTR(p_doc, LEAST(p_len, 32767), p_off + 1));
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END pdf_read;

--------------------------------------------------------------------------------
-- pdf_scan_refs: percorre o texto ASCII procurando referencias indiretas 'N G R'
--
-- p_collect = TRUE  -> apenas coleta os ids em p_ids (na ordem de ocorrencia)
-- p_collect = FALSE -> devolve o texto com todo id somado de p_shift
--
-- A varredura e feita byte a byte (e nao por REGEXP) para nao depender do
-- charset da sessao: bytes altos vindos de strings literais no dicionario nunca
-- casam com ASCII e sao repassados intactos.
--------------------------------------------------------------------------------
FUNCTION pdf_scan_refs(
  p_text    IN VARCHAR2,
  p_shift   IN PLS_INTEGER,
  p_ids     IN OUT NOCOPY tpi,
  p_collect IN BOOLEAN
) RETURN VARCHAR2 IS
  l_out  VARCHAR2(32767);
  l_n    PLS_INTEGER := NVL(LENGTHB(p_text), 0);
  l_i    PLS_INTEGER := 1;
  l_keep PLS_INTEGER := 1;   -- inicio do trecho ainda nao copiado para l_out
  l_j    PLS_INTEGER;
  l_k    PLS_INTEGER;
  l_d1e  PLS_INTEGER;        -- fim do 1o numero (id)
  l_d2s  PLS_INTEGER;        -- inicio do 2o numero (geracao)
  l_d2e  PLS_INTEGER;
  l_id   PLS_INTEGER;
BEGIN
  WHILE l_i <= l_n LOOP
    IF SUBSTRB(p_text, l_i, 1) BETWEEN '0' AND '9'
       AND (l_i = 1 OR NOT pdf_is_alnum(SUBSTRB(p_text, l_i - 1, 1))) THEN

      -- 1o numero
      l_j := l_i;
      WHILE l_j <= l_n AND SUBSTRB(p_text, l_j, 1) BETWEEN '0' AND '9' LOOP
        l_j := l_j + 1;
      END LOOP;
      l_d1e := l_j - 1;

      -- brancos, 2o numero, brancos, 'R' e um delimitador
      l_d2s := l_j;
      WHILE l_d2s <= l_n AND pdf_is_ws(SUBSTRB(p_text, l_d2s, 1)) LOOP
        l_d2s := l_d2s + 1;
      END LOOP;
      IF l_d2s > l_j AND l_d1e - l_i + 1 <= 9 THEN
        l_j := l_d2s;
        WHILE l_j <= l_n AND SUBSTRB(p_text, l_j, 1) BETWEEN '0' AND '9' LOOP
          l_j := l_j + 1;
        END LOOP;
        l_d2e := l_j - 1;
        IF l_d2e >= l_d2s THEN
          l_k := l_j;
          WHILE l_k <= l_n AND pdf_is_ws(SUBSTRB(p_text, l_k, 1)) LOOP
            l_k := l_k + 1;
          END LOOP;
          IF l_k > l_j AND SUBSTRB(p_text, l_k, 1) = 'R'
             AND (l_k = l_n OR NOT pdf_is_alnum(SUBSTRB(p_text, l_k + 1, 1))) THEN
            l_id := TO_NUMBER(SUBSTRB(p_text, l_i, l_d1e - l_i + 1));
            IF p_collect THEN
              p_ids(p_ids.COUNT + 1) := l_id;
            ELSE
              l_out := l_out
                    || SUBSTRB(p_text, l_keep, l_i - l_keep)
                    || TO_CHAR(l_id + p_shift)
                    || ' ' || SUBSTRB(p_text, l_d2s, l_d2e - l_d2s + 1) || ' R';
            END IF;
            l_keep := l_k + 1;   -- o WHILE volta ao topo usando l_keep como l_i
            l_i    := l_keep;
            CONTINUE;
          END IF;
        END IF;
      END IF;

      l_i := l_d1e + 1;   -- nao era referencia: pula o numero inteiro
    ELSE
      l_i := l_i + 1;
    END IF;
  END LOOP;

  IF p_collect THEN
    RETURN NULL;
  END IF;
  RETURN l_out || SUBSTRB(p_text, l_keep);
END pdf_scan_refs;

--------------------------------------------------------------------------------
-- pdf_collect_refs: so coleta os ids referenciados em p_text (ordem de ocorrencia)
--------------------------------------------------------------------------------
PROCEDURE pdf_collect_refs(p_text IN VARCHAR2, p_ids IN OUT NOCOPY tpi) IS
BEGIN
  -- pdf_scan_refs devolve NULL no modo coleta; o resultado util sai em p_ids
  IF pdf_scan_refs(p_text, 0, p_ids, TRUE) IS NOT NULL THEN
    NULL;
  END IF;
END pdf_collect_refs;

--------------------------------------------------------------------------------
-- pdf_key_pos: posicao da chave no dicionario, respeitando fronteira de nome
--   ('/Type' nao casa dentro de '/TypeX')
--------------------------------------------------------------------------------
FUNCTION pdf_key_pos(p_dict IN VARCHAR2, p_key IN VARCHAR2) RETURN PLS_INTEGER IS
  l_i PLS_INTEGER := INSTRB(p_dict, p_key);
BEGIN
  WHILE NVL(l_i, 0) > 0
        AND pdf_is_alnum(SUBSTRB(p_dict, l_i + LENGTHB(p_key), 1)) LOOP
    l_i := INSTRB(p_dict, p_key, l_i + 1);
  END LOOP;
  RETURN NVL(l_i, 0);
END pdf_key_pos;

--------------------------------------------------------------------------------
-- pdf_dict_value: valor bruto de uma chave (array, sub-dicionario, referencia,
--                 nome, numero ou palavra reservada). NULL se ausente.
--------------------------------------------------------------------------------
FUNCTION pdf_dict_value(p_dict IN VARCHAR2, p_key IN VARCHAR2) RETURN VARCHAR2 IS
  l_n     PLS_INTEGER := NVL(LENGTHB(p_dict), 0);
  l_i     PLS_INTEGER := pdf_key_pos(p_dict, p_key);
  l_j     PLS_INTEGER;
  l_k     PLS_INTEGER;
  l_end   PLS_INTEGER;
  l_depth PLS_INTEGER := 0;
  l_c     VARCHAR2(2 BYTE);
BEGIN
  IF l_i = 0 THEN
    RETURN NULL;
  END IF;

  l_j := l_i + LENGTHB(p_key);
  WHILE l_j <= l_n AND pdf_is_ws(SUBSTRB(p_dict, l_j, 1)) LOOP
    l_j := l_j + 1;
  END LOOP;

  -- array
  IF SUBSTRB(p_dict, l_j, 1) = '[' THEN
    l_k := l_j;
    WHILE l_k <= l_n LOOP
      l_c := SUBSTRB(p_dict, l_k, 1);
      IF l_c = '[' THEN
        l_depth := l_depth + 1;
      ELSIF l_c = ']' THEN
        l_depth := l_depth - 1;
        IF l_depth = 0 THEN
          RETURN SUBSTRB(p_dict, l_j, l_k - l_j + 1);
        END IF;
      END IF;
      l_k := l_k + 1;
    END LOOP;
    RETURN NULL;
  END IF;

  -- sub-dicionario
  IF SUBSTRB(p_dict, l_j, 2) = '<<' THEN
    l_k := l_j;
    WHILE l_k < l_n LOOP
      l_c := SUBSTRB(p_dict, l_k, 2);
      IF l_c = '<<' THEN
        l_depth := l_depth + 1;
        l_k := l_k + 2;
      ELSIF l_c = '>>' THEN
        l_depth := l_depth - 1;
        l_k := l_k + 2;
        IF l_depth = 0 THEN
          RETURN SUBSTRB(p_dict, l_j, l_k - l_j);
        END IF;
      ELSE
        l_k := l_k + 1;
      END IF;
    END LOOP;
    RETURN NULL;
  END IF;

  -- nome
  IF SUBSTRB(p_dict, l_j, 1) = '/' THEN
    l_k := l_j + 1;
    WHILE l_k <= l_n
          AND NOT pdf_is_ws(SUBSTRB(p_dict, l_k, 1))
          AND SUBSTRB(p_dict, l_k, 1) NOT IN ('/', '[', ']', '<', '>', '(', ')') LOOP
      l_k := l_k + 1;
    END LOOP;
    RETURN SUBSTRB(p_dict, l_j, l_k - l_j);
  END IF;

  -- numero, possivelmente o inicio de uma referencia 'N G R'
  l_k := l_j;
  WHILE l_k <= l_n
        AND (SUBSTRB(p_dict, l_k, 1) BETWEEN '0' AND '9'
             OR SUBSTRB(p_dict, l_k, 1) IN ('+', '-', '.')) LOOP
    l_k := l_k + 1;
  END LOOP;
  IF l_k > l_j THEN
    l_end := l_k - 1;
    l_i := l_k;
    WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(p_dict, l_i, 1)) LOOP
      l_i := l_i + 1;
    END LOOP;
    l_k := l_i;
    WHILE l_k <= l_n AND SUBSTRB(p_dict, l_k, 1) BETWEEN '0' AND '9' LOOP
      l_k := l_k + 1;
    END LOOP;
    IF l_k > l_i THEN
      l_j := l_k;
      WHILE l_k <= l_n AND pdf_is_ws(SUBSTRB(p_dict, l_k, 1)) LOOP
        l_k := l_k + 1;
      END LOOP;
      IF l_k > l_j AND SUBSTRB(p_dict, l_k, 1) = 'R' THEN
        l_end := l_k;
      END IF;
    END IF;
    l_j := pdf_key_pos(p_dict, p_key) + LENGTHB(p_key);
    WHILE l_j <= l_n AND pdf_is_ws(SUBSTRB(p_dict, l_j, 1)) LOOP
      l_j := l_j + 1;
    END LOOP;
    RETURN SUBSTRB(p_dict, l_j, l_end - l_j + 1);
  END IF;

  -- true / false / null
  l_k := l_j;
  WHILE l_k <= l_n AND pdf_is_alnum(SUBSTRB(p_dict, l_k, 1)) LOOP
    l_k := l_k + 1;
  END LOOP;
  IF l_k > l_j THEN
    RETURN SUBSTRB(p_dict, l_j, l_k - l_j);
  END IF;
  RETURN NULL;
END pdf_dict_value;

--------------------------------------------------------------------------------
-- pdf_strip_key: remove a chave e seu valor do dicionario
--------------------------------------------------------------------------------
FUNCTION pdf_strip_key(p_dict IN VARCHAR2, p_key IN VARCHAR2) RETURN VARCHAR2 IS
  l_val VARCHAR2(32767) := pdf_dict_value(p_dict, p_key);
  l_i   PLS_INTEGER;
  l_j   PLS_INTEGER;
BEGIN
  IF l_val IS NULL THEN
    RETURN p_dict;
  END IF;
  l_i := pdf_key_pos(p_dict, p_key);
  l_j := INSTRB(p_dict, l_val, l_i + LENGTHB(p_key));
  IF l_j = 0 THEN
    RETURN p_dict;
  END IF;
  RETURN SUBSTRB(p_dict, 1, l_i - 1) || SUBSTRB(p_dict, l_j + LENGTHB(l_val));
END pdf_strip_key;

--------------------------------------------------------------------------------
-- pdf_obj_extent: limites do objeto em bytes (offsets de base 0)
--
--   o_start    inicio do objeto ('N G obj')
--   o_dict_end fim da porcao ASCII = inicio do payload do stream (== o_end
--              quando o objeto nao tem stream)
--   o_end      fim do objeto (logo apos 'endobj')
--
-- O tamanho do stream vem de /Length, que pode ser uma referencia indireta;
-- e so entao 'endobj' e procurado, para nunca casar dentro de dados binarios.
--------------------------------------------------------------------------------
PROCEDURE pdf_obj_extent(
  p_src      IN pdf_source_rec,
  p_oid      IN PLS_INTEGER,
  o_start    OUT PLS_INTEGER,
  o_end      OUT PLS_INTEGER,
  o_dict_end OUT PLS_INTEGER,
  o_len      OUT PLS_INTEGER   -- bytes do payload (0 se nao houver stream)
) IS
  l_off    PLS_INTEGER;
  l_head   VARCHAR2(32767);
  l_ps     PLS_INTEGER;
  l_pe     PLS_INTEGER;
  l_len    PLS_INTEGER;
  l_lenval VARCHAR2(200);
  l_lid    PLS_INTEGER;
  l_ls     PLS_INTEGER;
  l_le     PLS_INTEGER;
  l_ld     PLS_INTEGER;
  l_data   PLS_INTEGER;
  l_after  PLS_INTEGER;
  l_lz     PLS_INTEGER;   -- tamanho do stream do objeto de /Length indireto
  l_ids    tpi;
BEGIN
  -- Objeto que mora dentro de um object stream: nao tem posicao no arquivo, e
  -- nem pode ter stream (a especificacao proibe). Os quatro limites zerados
  -- dizem ao copiador "nada a copiar byte a byte"; o corpo sai de
  -- pdf_obj_body, que le p_src.objstm.
  IF p_src.objstm.EXISTS(p_oid) THEN
    o_start := 0; o_end := 0; o_dict_end := 0; o_len := 0;
    RETURN;
  END IF;
  IF NOT p_src.xref.EXISTS(p_oid) THEN
    RAISE_APPLICATION_ERROR(-20805, 'Objeto ' || p_oid || ' ausente na xref');
  END IF;

  l_off  := p_src.xref(p_oid).offset;
  IF l_off IS NULL THEN
    RAISE_APPLICATION_ERROR(-20847,
      'Objeto ' || p_oid || ' esta num object stream que nao foi carregado.');
  END IF;
  o_start := l_off;
  l_head := pdf_read(p_src.doc, l_off, 32767);
  l_ps   := INSTRB(l_head, 'stream');
  l_pe   := INSTRB(l_head, 'endobj');

  -- objeto sem stream: termina no 'endobj'
  IF l_ps = 0 OR (l_pe > 0 AND l_pe < l_ps) THEN
    IF l_pe = 0 THEN
      RAISE_APPLICATION_ERROR(-20806, 'endobj nao encontrado no objeto ' || p_oid);
    END IF;
    o_end      := l_off + l_pe + 5;
    o_dict_end := o_end;
    o_len      := 0;
    RETURN;
  END IF;

  -- objeto com stream: pula o payload usando /Length
  l_lenval := pdf_dict_value(SUBSTRB(l_head, 1, l_ps - 1), '/Length');
  IF l_lenval IS NULL THEN
    RAISE_APPLICATION_ERROR(-20840, '/Length ausente no objeto ' || p_oid);
  END IF;
  IF INSTRB(l_lenval, 'R') > 0 THEN                 -- /Length indireto
    l_ids.DELETE;
    pdf_collect_refs(l_lenval, l_ids);
    l_lid := l_ids(1);
    IF NOT p_src.xref.EXISTS(l_lid) THEN
      RAISE_APPLICATION_ERROR(-20840,
        '/Length indireto aponta para objeto ausente (' || l_lid || ')');
    END IF;
    IF p_src.objstm.EXISTS(l_lid) THEN
      l_lenval := p_src.objstm(l_lid);      -- /Length dentro de um ObjStm
    ELSE
      pdf_obj_extent(p_src, l_lid, l_ls, l_le, l_ld, l_lz);
      l_lenval := pdf_read(p_src.doc, l_ls, l_ld - l_ls);
      l_lenval := SUBSTRB(l_lenval, INSTRB(l_lenval, 'obj') + 3);
    END IF;
    l_len := TO_NUMBER(TRIM(TRANSLATE(l_lenval, CHR(10) || CHR(13) || CHR(9) || 'endobj',
                                      '   ')));
  ELSE
    l_len := TO_NUMBER(TRIM(l_lenval));
  END IF;

  l_data := l_off + l_ps + 5;                        -- logo apos 'stream'
  IF pdf_read(p_src.doc, l_data, 2) = CHR(13) || CHR(10) THEN
    l_data := l_data + 2;
  ELSIF pdf_read(p_src.doc, l_data, 1) IN (CHR(10), CHR(13)) THEN
    l_data := l_data + 1;
  END IF;

  l_after := DBMS_LOB.INSTR(p_src.doc, UTL_RAW.CAST_TO_RAW('endobj'),
                            l_data + l_len + 1, 1);
  IF l_after = 0 THEN
    RAISE_APPLICATION_ERROR(-20806,
      'endobj nao encontrado apos o stream do objeto ' || p_oid);
  END IF;
  o_end      := l_after + 5;
  -- INICIO do payload, nao o fim: o copiador le [start, dict_end) como texto e
  -- copia [dict_end, end) byte a byte. Com o fim aqui, o payload entrava no
  -- VARCHAR2 e passava por pdf_scan_refs — corrompendo stream binario (imagem,
  -- Flate) e fazendo pdf_obj_body recusar qualquer objeto com stream acima de
  -- co_pdf_dict_limit. Os testes nao pegaram porque usam PDFs pequenos, de
  -- texto e sem compressao.
  o_dict_end := l_data;
  o_len      := l_len;
END pdf_obj_extent;

--------------------------------------------------------------------------------
-- pdf_obj_body: porcao ASCII do objeto, ja sem o cabecalho 'N G obj'
--------------------------------------------------------------------------------
FUNCTION pdf_obj_body(p_src IN pdf_source_rec, p_oid IN PLS_INTEGER)
  RETURN VARCHAR2 IS
  l_start PLS_INTEGER;
  l_end   PLS_INTEGER;
  l_dend  PLS_INTEGER;
  l_slen  PLS_INTEGER;
  l_raw   VARCHAR2(32767);
  l_i     PLS_INTEGER := 1;
  l_n     PLS_INTEGER;
BEGIN
  -- Objeto de object stream: o corpo ja foi materializado na carga, e nao ha
  -- cabecalho 'N G obj' a pular — a especificacao proibe que ele apareca la
  -- dentro.
  IF p_src.objstm.EXISTS(p_oid) THEN
    RETURN p_src.objstm(p_oid);
  END IF;
  pdf_obj_extent(p_src, p_oid, l_start, l_end, l_dend, l_slen);
  IF l_dend - l_start > co_pdf_dict_limit THEN
    RAISE_APPLICATION_ERROR(-20841,
      'Dicionario do objeto ' || p_oid || ' excede ' || co_pdf_dict_limit ||
      ' bytes; nao e possivel renumerar as referencias.');
  END IF;
  l_raw := pdf_read(p_src.doc, l_start, l_dend - l_start);
  l_n   := NVL(LENGTHB(l_raw), 0);

  -- pula '\s* N \s+ G \s+ obj'
  WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(l_raw, l_i, 1)) LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND SUBSTRB(l_raw, l_i, 1) BETWEEN '0' AND '9' LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(l_raw, l_i, 1)) LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND SUBSTRB(l_raw, l_i, 1) BETWEEN '0' AND '9' LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(l_raw, l_i, 1)) LOOP l_i := l_i + 1; END LOOP;
  IF SUBSTRB(l_raw, l_i, 3) = 'obj' THEN
    l_i := l_i + 3;
  ELSE
    l_i := 1;                                        -- cabecalho inesperado
  END IF;
  RETURN SUBSTRB(l_raw, l_i);
END pdf_obj_body;

--------------------------------------------------------------------------------
-- pdf_page_body: dicionario final da pagina
--
-- /Parent e removido (a arvore sera reconstruida) e a heranca de /MediaBox,
-- /Resources, /CropBox e /Rotate e materializada. A referencia ao novo no
-- /Pages nao entra aqui: ela e inserida DEPOIS da renumeracao, senao o proprio
-- '2 0 R' seria deslocado junto.
--------------------------------------------------------------------------------
FUNCTION pdf_page_body(
  p_src IN pdf_source_rec,
  p_oid IN PLS_INTEGER
) RETURN VARCHAR2 IS
  l_d VARCHAR2(32767);

  PROCEDURE inject(p_key IN VARCHAR2, p_val IN VARCHAR2) IS
    l_p PLS_INTEGER;
  BEGIN
    IF p_val IS NULL OR pdf_dict_value(l_d, p_key) IS NOT NULL THEN
      RETURN;
    END IF;
    l_p := INSTRB(l_d, '<<');
    IF l_p > 0 THEN
      l_d := SUBSTRB(l_d, 1, l_p + 1) || p_key || ' ' || p_val || ' '
          || SUBSTRB(l_d, l_p + 2);
    END IF;
  END inject;
BEGIN
  l_d := pdf_strip_key(pdf_obj_body(p_src, p_oid), '/Parent');
  IF p_src.rot_force.EXISTS(p_oid) AND p_src.rot_force(p_oid) IS NOT NULL THEN
    l_d := pdf_strip_key(l_d, '/Rotate');
    inject('/Rotate', p_src.rot_force(p_oid));
  END IF;
  inject('/MediaBox',  p_src.media(p_oid));
  inject('/Resources', p_src.resources(p_oid));
  inject('/CropBox',   p_src.cropbox(p_oid));
  inject('/Rotate',    p_src.rotate(p_oid));
  RETURN l_d;
END pdf_page_body;

--------------------------------------------------------------------------------
-- pdf_walk_pages: achata a arvore de paginas resolvendo os atributos herdados
--------------------------------------------------------------------------------
PROCEDURE pdf_walk_pages(
  p_src   IN OUT NOCOPY pdf_source_rec,
  p_oid   IN PLS_INTEGER,
  p_media IN VARCHAR2,
  p_res   IN VARCHAR2,
  p_crop  IN VARCHAR2,
  p_rot   IN VARCHAR2,
  p_depth IN PLS_INTEGER
) IS
  l_d     VARCHAR2(32767);
  l_kids  VARCHAR2(32767);
  l_media VARCHAR2(32767);
  l_res   VARCHAR2(32767);
  l_crop  VARCHAR2(32767);
  l_rot   VARCHAR2(32767);
  l_ids   tpi;
  l_n     PLS_INTEGER;
BEGIN
  IF p_depth > 32 THEN
    RAISE_APPLICATION_ERROR(-20842, 'Arvore de paginas profunda demais (>32)');
  END IF;
  IF NOT p_src.xref.EXISTS(p_oid) THEN
    RAISE_APPLICATION_ERROR(-20805, 'No da arvore de paginas ausente: ' || p_oid);
  END IF;

  l_d     := pdf_obj_body(p_src, p_oid);
  l_media := NVL(pdf_dict_value(l_d, '/MediaBox'),  p_media);
  l_res   := NVL(pdf_dict_value(l_d, '/Resources'), p_res);
  l_crop  := NVL(pdf_dict_value(l_d, '/CropBox'),   p_crop);
  l_rot   := NVL(pdf_dict_value(l_d, '/Rotate'),    p_rot);

  l_kids := pdf_dict_value(l_d, '/Kids');

  -- folha: sem /Kids e uma pagina (mais confiavel que confiar na ordem de /Type)
  IF l_kids IS NULL THEN
    l_n := p_src.pages.COUNT + 1;
    p_src.pages(l_n)         := p_oid;
    p_src.media(p_oid)       := l_media;
    p_src.resources(p_oid)   := l_res;
    p_src.cropbox(p_oid)     := l_crop;
    p_src.rotate(p_oid)      := l_rot;
    RETURN;
  END IF;

  pdf_collect_refs(l_kids, l_ids);
  FOR i IN 1 .. l_ids.COUNT LOOP
    pdf_walk_pages(p_src, l_ids(i), l_media, l_res, l_crop, l_rot, p_depth + 1);
  END LOOP;
END pdf_walk_pages;

--------------------------------------------------------------------------------
-- xref em stream e object streams (PDF 1.5+)
--
-- Portado de scripts/pdfxref_reference/, validado contra o MuPDF (43/43).
--
-- A partir do PDF 1.5 a xref deixou de ser tabela de texto e virou um objeto
-- com stream (/Type /XRef), comprimido; e os objetos sem stream foram para
-- dentro de object streams (/Type /ObjStm), tambem comprimidos. Nesses
-- arquivos um objeto nao fica num offset do arquivo: fica dentro do stream de
-- outro objeto. Era o que o ORA-20843 recusava, e com ele iam merge, extract,
-- marca d'agua e overlay sobre documento de terceiro.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- pdf_be: inteiro big-endian de p_len bytes lidos de p_dados (offset base 0)
--
-- NUMBER, e nao PLS_INTEGER: /W admite campo de 8 bytes, e mesmo o offset de um
-- arquivo grande passa de 2147483647 em teoria.
--------------------------------------------------------------------------------
FUNCTION pdf_be(p_dados IN BLOB, p_off IN PLS_INTEGER, p_len IN PLS_INTEGER)
  RETURN NUMBER IS
BEGIN
  IF p_len <= 0 THEN
    RETURN 0;
  END IF;
  RETURN TO_NUMBER(RAWTOHEX(DBMS_LOB.SUBSTR(p_dados, p_len, p_off + 1)),
                   RPAD('X', p_len * 2, 'X'));
END pdf_be;

--------------------------------------------------------------------------------
-- pdf_ints: todos os inteiros de um texto ('[0 11 20 3]', '5 0 8 42')
--------------------------------------------------------------------------------
PROCEDURE pdf_ints(p_txt IN VARCHAR2, o_out IN OUT NOCOPY tpi) IS
  l_n PLS_INTEGER := NVL(LENGTHB(p_txt), 0);
  l_i PLS_INTEGER := 1;
  l_j PLS_INTEGER;
BEGIN
  o_out.DELETE;
  WHILE l_i <= l_n LOOP
    IF SUBSTRB(p_txt, l_i, 1) BETWEEN '0' AND '9' THEN
      l_j := l_i;
      WHILE l_j <= l_n AND SUBSTRB(p_txt, l_j, 1) BETWEEN '0' AND '9' LOOP
        l_j := l_j + 1;
      END LOOP;
      o_out(o_out.COUNT + 1) := TO_NUMBER(SUBSTRB(p_txt, l_i, l_j - l_i));
      l_i := l_j;
    ELSE
      l_i := l_i + 1;
    END IF;
  END LOOP;
END pdf_ints;

--------------------------------------------------------------------------------
-- pdf_undo_pred: desfaz o predictor do /DecodeParms
--
-- O predictor NAO e compressao: e uma transformacao aplicada antes do deflate
-- para que colunas parecidas virem zeros. Sem desfaze-la o inflate devolve
-- bytes limpos e ERRADOS — offsets plausiveis apontando para o lugar errado.
-- Mesmo genero do inflate com os bits ao contrario: nao quebra, mente.
--
-- O numero no dicionario (12, quase sempre) e so o padrao que o compressor
-- usou; quem manda e o byte de filtro no inicio de CADA linha. Por isso os
-- cinco filtros do PNG precisam existir aqui.
--------------------------------------------------------------------------------
PROCEDURE pdf_undo_pred(
  p_dados IN OUT NOCOPY BLOB,
  p_pred  IN            PLS_INTEGER,
  p_cores IN            PLS_INTEGER,
  p_bpc   IN            PLS_INTEGER,
  p_cols  IN            PLS_INTEGER
) IS
  l_linha PLS_INTEGER;
  l_bpp   PLS_INTEGER;
  l_tot   PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_dados), 0);
  l_p     PLS_INTEGER := 1;          -- base 1, para DBMS_LOB
  l_hex   VARCHAR2(32767);
  l_filtro PLS_INTEGER;
  l_cur   tpi;
  l_ant   tpi;
  l_esq   PLS_INTEGER;
  l_cima  PLS_INTEGER;
  l_diag  PLS_INTEGER;
  l_pp    PLS_INTEGER;
  l_pa    PLS_INTEGER;
  l_pb    PLS_INTEGER;
  l_pc    PLS_INTEGER;
  l_pred  PLS_INTEGER;
  l_out   BLOB;
  l_saida VARCHAR2(32767);
BEGIN
  IF p_pred IS NULL OR p_pred = 1 THEN
    RETURN;
  END IF;
  IF p_pred < 10 THEN
    -- 2 e o preditor TIFF, definido para imagem. Trata-lo como 1 devolveria
    -- offsets errados sem nenhum sinal; recusar sai mais barato.
    RAISE_APPLICATION_ERROR(-20848,
      'xref em stream: /Predictor ' || p_pred || ' (TIFF) nao suportado.');
  END IF;

  l_bpp   := GREATEST(1, CEIL(p_cores * p_bpc / 8));
  l_linha := CEIL(p_cols * p_cores * p_bpc / 8);
  IF l_linha < 1 OR l_linha > 16000 THEN
    -- Serve a xref em stream E ao PNG: a linha vira hexadecimal num VARCHAR2,
    -- que so tem 32767 caracteres.
    RAISE_APPLICATION_ERROR(-20848,
      'Linha de predictor de ' || l_linha || ' bytes (teto 16000).');
  END IF;
  IF MOD(l_tot, l_linha + 1) != 0 THEN
    RAISE_APPLICATION_ERROR(-20848,
      'xref em stream: ' || l_tot || ' bytes nao dividem pela linha de '
      || (l_linha + 1) || ' do predictor.');
  END IF;

  FOR i IN 1 .. l_linha LOOP
    l_ant(i) := 0;
  END LOOP;

  DBMS_LOB.CREATETEMPORARY(l_out, TRUE);
  WHILE l_p <= l_tot LOOP
    l_hex := RAWTOHEX(DBMS_LOB.SUBSTR(p_dados, l_linha + 1, l_p));
    l_p   := l_p + l_linha + 1;
    l_filtro := TO_NUMBER(SUBSTR(l_hex, 1, 2), 'XX');
    FOR i IN 1 .. l_linha LOOP
      l_cur(i) := TO_NUMBER(SUBSTR(l_hex, i * 2 + 1, 2), 'XX');
    END LOOP;

    FOR i IN 1 .. l_linha LOOP
      l_esq  := CASE WHEN i > l_bpp THEN l_cur(i - l_bpp) ELSE 0 END;
      l_cima := l_ant(i);
      l_diag := CASE WHEN i > l_bpp THEN l_ant(i - l_bpp) ELSE 0 END;
      CASE l_filtro
        WHEN 0 THEN l_pred := 0;                          -- None
        WHEN 1 THEN l_pred := l_esq;                      -- Sub
        WHEN 2 THEN l_pred := l_cima;                     -- Up
        WHEN 3 THEN l_pred := FLOOR((l_esq + l_cima) / 2); -- Average
        WHEN 4 THEN                                       -- Paeth
          l_pp := l_esq + l_cima - l_diag;
          l_pa := ABS(l_pp - l_esq);
          l_pb := ABS(l_pp - l_cima);
          l_pc := ABS(l_pp - l_diag);
          IF l_pa <= l_pb AND l_pa <= l_pc THEN
            l_pred := l_esq;
          ELSIF l_pb <= l_pc THEN
            l_pred := l_cima;
          ELSE
            l_pred := l_diag;
          END IF;
        ELSE
          RAISE_APPLICATION_ERROR(-20848,
            'xref em stream: filtro PNG ' || l_filtro || ' invalido.');
      END CASE;
      l_cur(i) := MOD(l_cur(i) + l_pred, 256);
    END LOOP;

    l_saida := NULL;
    FOR i IN 1 .. l_linha LOOP
      l_saida := l_saida || PL_FPDF_UTIL.hex_do_byte(l_cur(i));
      l_ant(i) := l_cur(i);
    END LOOP;
    DBMS_LOB.WRITEAPPEND(l_out, l_linha, HEXTORAW(l_saida));
  END LOOP;

  IF NVL(DBMS_LOB.GETLENGTH(p_dados), 0) > 0 THEN
    DBMS_LOB.TRIM(p_dados, 0);
  END IF;
  IF DBMS_LOB.GETLENGTH(l_out) > 0 THEN
    DBMS_LOB.COPY(p_dados, l_out, DBMS_LOB.GETLENGTH(l_out), 1, 1);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_out);
END pdf_undo_pred;

--------------------------------------------------------------------------------
-- pdf_stream_data: dicionario e payload JA descomprimido do objeto em p_off
--
-- Espelha pdf_obj_extent, mas para um offset conhecido e sem consultar a xref:
-- aqui ela ainda nao existe — e justamente o que se esta montando. Por isso
-- /Length indireto e recusado: o leitor precisaria da xref para achar o
-- /Length que da a xref. Nenhum produtor grava assim.
--------------------------------------------------------------------------------
PROCEDURE pdf_stream_data(
  p_doc   IN            BLOB,
  p_off   IN            PLS_INTEGER,
  o_dic   OUT           VARCHAR2,
  o_dados IN OUT NOCOPY BLOB,
  -- Decifragem opcional do payload. Vale so para o object stream: num PDF
  -- cifrado ele vem cifrado, e inflar sem decifrar devolve erro ou lixo. A
  -- ordem importa e e esta — decifrar, depois inflar, depois o predictor —
  -- porque a cifra e aplicada por ultimo na gravacao.
  p_chave IN            RAW DEFAULT NULL,
  p_aes   IN            BOOLEAN DEFAULT FALSE,
  p_r6    IN            BOOLEAN DEFAULT FALSE,
  p_oid   IN            PLS_INTEGER DEFAULT NULL
) IS
  l_head VARCHAR2(32767);
  l_ps   PLS_INTEGER;
  l_len  PLS_INTEGER;
  l_val  VARCHAR2(200);
  l_ini  PLS_INTEGER;
  l_cru  BLOB;
  l_filt VARCHAR2(200);
  l_parm VARCHAR2(4000);
  l_pred VARCHAR2(50);
  l_ok   RAW(32);
  l_lim  BLOB;
BEGIN
  l_head := pdf_read(p_doc, p_off, 32767);
  l_ps   := INSTRB(l_head, 'stream');
  IF l_ps = 0 THEN
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: objeto em ' || p_off || ' nao tem stream.');
  END IF;
  o_dic := SUBSTRB(l_head, 1, l_ps - 1);

  l_val := pdf_dict_value(o_dic, '/Length');
  IF l_val IS NULL THEN
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: /Length ausente no objeto em ' || p_off || '.');
  END IF;
  IF INSTRB(l_val, 'R') > 0 THEN
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: /Length indireto no objeto em ' || p_off
      || ' — seria preciso a xref para ler a propria xref.');
  END IF;
  l_len := TO_NUMBER(TRIM(l_val));

  l_ini := p_off + l_ps + 5;                     -- logo apos 'stream'
  IF pdf_read(p_doc, l_ini, 2) = CHR(13) || CHR(10) THEN
    l_ini := l_ini + 2;
  ELSIF pdf_read(p_doc, l_ini, 1) IN (CHR(10), CHR(13)) THEN
    l_ini := l_ini + 1;
  END IF;

  IF NVL(DBMS_LOB.GETLENGTH(o_dados), 0) > 0 THEN
    DBMS_LOB.TRIM(o_dados, 0);
  END IF;

  -- payload cru, ja decifrado se for o caso
  DBMS_LOB.CREATETEMPORARY(l_cru, TRUE);
  IF l_len > 0 THEN
    IF p_chave IS NULL THEN
      DBMS_LOB.COPY(l_cru, p_doc, l_len, 1, l_ini + 1);
    ELSE
      -- No R6 (AES-256) NAO ha chave por objeto: a do arquivo e usada direto.
      l_ok := CASE WHEN p_r6 THEN p_chave
                   WHEN p_aes THEN PL_FPDF_UTIL.aes_chave_objeto(p_chave, p_oid, 0)
                   ELSE compute_object_key(p_chave, p_oid, 0,
                                           UTL_RAW.LENGTH(p_chave) * 8) END;
      DBMS_LOB.CREATETEMPORARY(l_lim, TRUE);
      DBMS_LOB.COPY(l_lim, p_doc, l_len, 1, l_ini + 1);
      IF p_aes OR p_r6 THEN
        PL_FPDF_UTIL.aes_cbc_decifrar(l_ok, l_lim, l_cru);
      ELSE
        PL_FPDF_UTIL.crypto_rc4_blob(l_lim, l_ok, l_cru);
      END IF;
      DBMS_LOB.FREETEMPORARY(l_lim);
    END IF;
  END IF;

  l_filt := pdf_dict_value(o_dic, '/Filter');
  IF l_filt IS NULL THEN
    IF DBMS_LOB.GETLENGTH(l_cru) > 0 THEN
      DBMS_LOB.COPY(o_dados, l_cru, DBMS_LOB.GETLENGTH(l_cru), 1, 1);
    END IF;
    DBMS_LOB.FREETEMPORARY(l_cru);
  ELSIF INSTRB(l_filt, '/FlateDecode') > 0 AND INSTRB(l_filt, '/', 1, 2) = 0 THEN
    PL_FPDF_UTIL.inflate(l_cru, o_dados);
    DBMS_LOB.FREETEMPORARY(l_cru);
  ELSE
    DBMS_LOB.FREETEMPORARY(l_cru);
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: /Filter ' || l_filt || ' nao suportado (so FlateDecode).');
  END IF;

  l_parm := pdf_dict_value(o_dic, '/DecodeParms');
  IF l_parm IS NOT NULL AND l_parm != 'null' THEN
    l_pred := pdf_dict_value(l_parm, '/Predictor');
    IF l_pred IS NOT NULL THEN
      pdf_undo_pred(o_dados, TO_NUMBER(TRIM(l_pred)),
        NVL(TO_NUMBER(TRIM(pdf_dict_value(l_parm, '/Colors'))), 1),
        NVL(TO_NUMBER(TRIM(pdf_dict_value(l_parm, '/BitsPerComponent'))), 8),
        NVL(TO_NUMBER(TRIM(pdf_dict_value(l_parm, '/Columns'))), 1));
    END IF;
  END IF;
END pdf_stream_data;

--------------------------------------------------------------------------------
-- pdf_xref_stream: le uma secao de xref que e um objeto /Type /XRef
--
-- Os tres tipos de entrada:
--   0  objeto livre — ignorado
--   1  objeto no arquivo: campo2 = offset, campo3 = geracao
--   2  objeto DENTRO de um object stream: campo2 = id do stream,
--      campo3 = indice dentro dele
--
-- O trailer devolvido e o proprio dicionario do objeto: e la que estao /Root,
-- /Prev e /Encrypt.
--------------------------------------------------------------------------------
PROCEDURE pdf_xref_stream(
  p_doc     IN            BLOB,
  p_off     IN            PLS_INTEGER,
  p_src     IN OUT NOCOPY pdf_source_rec,
  p_stm     IN OUT NOCOPY tpi,       -- id do objeto => id do object stream
  o_trailer OUT           VARCHAR2
) IS
  l_dados BLOB;
  l_w     tpi;
  l_ind   tpi;
  l_larg  PLS_INTEGER;
  l_tot   PLS_INTEGER;
  l_p     PLS_INTEGER := 0;          -- base 0, dentro do stream ja aberto
  l_ini   PLS_INTEGER;
  l_qtd   PLS_INTEGER;
  l_oid   PLS_INTEGER;
  l_tipo  PLS_INTEGER;
  l_a     NUMBER;
  l_b     NUMBER;
  l_ent   xref_entry_rec;
  l_size  VARCHAR2(50);
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_dados, TRUE);
  pdf_stream_data(p_doc, p_off, o_trailer, l_dados);

  -- NVL de proposito: /Type ausente devolve NULL, `NULL != '/XRef'` e NULL, e
  -- um IF com NULL nao dispara — a verificacao passaria em branco.
  IF NVL(pdf_dict_value(o_trailer, '/Type'), 'x') != '/XRef' THEN
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: objeto em ' || p_off || ' nao e /Type /XRef.');
  END IF;

  pdf_ints(pdf_dict_value(o_trailer, '/W'), l_w);
  IF l_w.COUNT < 3 THEN
    RAISE_APPLICATION_ERROR(-20843, 'xref em stream: /W invalido.');
  END IF;
  IF l_w(1) > 8 OR l_w(2) > 8 OR l_w(3) > 8 THEN
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: campo de /W acima de 8 bytes.');
  END IF;
  l_larg := l_w(1) + l_w(2) + l_w(3);
  IF l_larg = 0 THEN
    RAISE_APPLICATION_ERROR(-20843, 'xref em stream: /W todo zerado.');
  END IF;
  l_tot := NVL(DBMS_LOB.GETLENGTH(l_dados), 0);
  IF MOD(l_tot, l_larg) != 0 THEN
    RAISE_APPLICATION_ERROR(-20843,
      'xref em stream: ' || l_tot || ' bytes nao dividem por /W = ' || l_larg
      || '. Predictor nao desfeito, ou stream truncado.');
  END IF;

  pdf_ints(pdf_dict_value(o_trailer, '/Index'), l_ind);
  IF l_ind.COUNT = 0 THEN
    l_size := pdf_dict_value(o_trailer, '/Size');
    IF l_size IS NULL THEN
      RAISE_APPLICATION_ERROR(-20843,
        'xref em stream: nem /Index nem /Size.');
    END IF;
    l_ind(1) := 0;
    l_ind(2) := TO_NUMBER(TRIM(l_size));
  END IF;

  l_ent.in_use := TRUE;
  FOR f IN 1 .. FLOOR(l_ind.COUNT / 2) LOOP
    l_ini := l_ind(f * 2 - 1);
    l_qtd := l_ind(f * 2);
    FOR i IN 0 .. l_qtd - 1 LOOP
      IF l_p + l_larg > l_tot THEN
        RAISE_APPLICATION_ERROR(-20843,
          'xref em stream: mais curta que o /Index declara.');
      END IF;
      -- Campo de largura zero nao ocupa espaco: vale o default. Para o campo
      -- do TIPO o default e 1, nao 0 — trocar isso faz o arquivo inteiro virar
      -- "objetos livres" em silencio.
      IF l_w(1) = 0 THEN
        l_tipo := 1;
      ELSE
        l_tipo := pdf_be(l_dados, l_p, l_w(1));
      END IF;
      l_a := CASE WHEN l_w(2) = 0 THEN 0
                  ELSE pdf_be(l_dados, l_p + l_w(1), l_w(2)) END;
      l_b := CASE WHEN l_w(3) = 0 THEN 0
                  ELSE pdf_be(l_dados, l_p + l_w(1) + l_w(2), l_w(3)) END;
      l_p := l_p + l_larg;
      l_oid := l_ini + i;

      -- a secao mais recente vence: nao sobrescreve o que ja foi lido
      IF NOT p_src.xref.EXISTS(l_oid) THEN
        IF l_tipo = 1 THEN
          l_ent.offset     := l_a;
          l_ent.generation := l_b;
          p_src.xref(l_oid) := l_ent;
        ELSIF l_tipo = 2 THEN
          -- Sem offset no arquivo: o corpo sera materializado depois, quando o
          -- object stream for aberto. O id entra na xref assim mesmo para que
          -- os xref.EXISTS() do copiador continuem valendo.
          l_ent.offset     := NULL;
          l_ent.generation := 0;
          p_src.xref(l_oid) := l_ent;
          p_stm(l_oid) := l_a;
        END IF;
      END IF;
    END LOOP;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(l_dados);
END pdf_xref_stream;

--------------------------------------------------------------------------------
-- pdf_objstm_load: materializa os objetos de um /Type /ObjStm
--
-- /N pares de inteiros (id offset) no inicio, corpo a partir de /First, offsets
-- relativos a ele. Nenhum objeto de dentro pode ter stream — a especificacao
-- proibe —, entao o que sai daqui e texto, exatamente o que pdf_obj_body
-- devolveria se ele estivesse solto no arquivo.
--
-- Um ObjStm e aberto UMA vez, mesmo guardando cinquenta objetos:
-- descomprimir por objeto seria o custo dominante da carga em PL/SQL.
--------------------------------------------------------------------------------
PROCEDURE pdf_objstm_load(
  p_src     IN OUT NOCOPY pdf_source_rec,
  p_stm_oid IN            PLS_INTEGER,
  p_stm     IN            tpi,
  p_chave   IN            RAW DEFAULT NULL,
  p_aes     IN            BOOLEAN DEFAULT FALSE,
  p_r6      IN            BOOLEAN DEFAULT FALSE
) IS
  l_dic   VARCHAR2(32767);
  l_dados BLOB;
  l_n     PLS_INTEGER;
  l_first PLS_INTEGER;
  l_tot   PLS_INTEGER;
  l_pares tpi;
  l_oid   PLS_INTEGER;
  l_ini   PLS_INTEGER;
  l_fim   PLS_INTEGER;
BEGIN
  IF NOT p_src.xref.EXISTS(p_stm_oid)
     OR p_src.xref(p_stm_oid).offset IS NULL THEN
    RAISE_APPLICATION_ERROR(-20847,
      'object stream ' || p_stm_oid || ' ausente da xref.');
  END IF;

  DBMS_LOB.CREATETEMPORARY(l_dados, TRUE);
  pdf_stream_data(p_src.doc, p_src.xref(p_stm_oid).offset, l_dic, l_dados,
                  p_chave, p_aes, p_r6, p_stm_oid);
  IF NVL(pdf_dict_value(l_dic, '/Type'), 'x') != '/ObjStm' THEN
    RAISE_APPLICATION_ERROR(-20847,
      'objeto ' || p_stm_oid || ' nao e /Type /ObjStm.');
  END IF;

  l_n     := TO_NUMBER(TRIM(pdf_dict_value(l_dic, '/N')));
  l_first := TO_NUMBER(TRIM(pdf_dict_value(l_dic, '/First')));
  IF l_n IS NULL OR l_first IS NULL THEN
    RAISE_APPLICATION_ERROR(-20847,
      'object stream ' || p_stm_oid || ' sem /N ou /First.');
  END IF;
  l_tot := NVL(DBMS_LOB.GETLENGTH(l_dados), 0);
  IF l_first > 32767 THEN
    RAISE_APPLICATION_ERROR(-20847,
      'object stream ' || p_stm_oid || ': tabela de ' || l_first
      || ' bytes nao cabe num VARCHAR2.');
  END IF;

  pdf_ints(pdf_read(l_dados, 0, l_first), l_pares);
  IF l_pares.COUNT < l_n * 2 THEN
    RAISE_APPLICATION_ERROR(-20847,
      'object stream ' || p_stm_oid || ': ' || FLOOR(l_pares.COUNT / 2)
      || ' pares, esperado ' || l_n || '.');
  END IF;

  FOR i IN 1 .. l_n LOOP
    l_oid := l_pares(i * 2 - 1);
    l_ini := l_first + l_pares(i * 2);
    l_fim := CASE WHEN i < l_n THEN l_first + l_pares(i * 2 + 2) ELSE l_tot END;
    IF l_ini > l_tot OR l_fim > l_tot OR l_fim < l_ini THEN
      RAISE_APPLICATION_ERROR(-20847,
        'object stream ' || p_stm_oid || ': offset fora do stream (objeto '
        || l_oid || ').');
    END IF;
    IF l_fim - l_ini > co_pdf_dict_limit THEN
      RAISE_APPLICATION_ERROR(-20841,
        'Dicionario do objeto ' || l_oid || ' excede ' || co_pdf_dict_limit
        || ' bytes; nao e possivel renumerar as referencias.');
    END IF;
    -- so materializa o que a xref realmente aponta para ESTE stream: um ObjStm
    -- de uma revisao antiga pode conter um objeto que ja foi substituido
    IF p_stm.EXISTS(l_oid) AND p_stm(l_oid) = p_stm_oid THEN
      -- O 'endobj' entra aqui de proposito: para um objeto solto no arquivo,
      -- pdf_obj_body devolve o texto ATE o endobj (o extent vai ate depois
      -- dele), e o copiador conta com isso — ele escreve 'N 0 obj', o corpo, e
      -- mais nada. Sem esta linha todo objeto vindo de ObjStm sairia sem
      -- fechamento, e o PDF montado nao abriria.
      -- LTRIM/RTRIM com conjunto, e nao TRANSLATE: os objetos dentro do stream
      -- sao separados por brancos que sobram nas pontas, mas trocar CHR(10) por
      -- espaco no corpo inteiro estragaria uma string literal com quebra de
      -- linha dentro.
      p_src.objstm(l_oid) :=
        LTRIM(RTRIM(pdf_read(l_dados, l_ini, l_fim - l_ini),
                    ' ' || CHR(10) || CHR(13) || CHR(9)),
              ' ' || CHR(10) || CHR(13) || CHR(9))
        || CHR(10) || 'endobj';
    END IF;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(l_dados);
END pdf_objstm_load;

--------------------------------------------------------------------------------
-- pdf_src_load: indexa um PDF de origem (xref encadeada + arvore de paginas)
--------------------------------------------------------------------------------
FUNCTION pdf_src_load(
  p_doc          IN BLOB,
  -- Chave do documento, quando a origem esta CIFRADA. So o object stream
  -- precisa dela: a xref em stream nunca e cifrada.
  p_chave        IN RAW     DEFAULT NULL,
  p_aes          IN BOOLEAN DEFAULT FALSE,
  p_r6           IN BOOLEAN DEFAULT FALSE,
  -- FALSE para a xref e NAO abrir os object streams. Existe por causa de um
  -- ovo-e-galinha: num PDF cifrado a chave sai do /Encrypt, que sai do
  -- trailer — mas abrir os object streams para chegar la exigiria a chave que
  -- ainda nao se tem.
  p_materializar IN BOOLEAN DEFAULT TRUE
) RETURN pdf_source_rec IS
  l_src     pdf_source_rec;
  l_size    PLS_INTEGER;
  l_tail    VARCHAR2(32767);
  l_sec     VARCHAR2(32767);
  l_off     PLS_INTEGER;
  l_pos     PLS_INTEGER;
  l_n       PLS_INTEGER;
  l_start   PLS_INTEGER;
  l_count   PLS_INTEGER;
  l_eoff    PLS_INTEGER;
  l_gen     PLS_INTEGER;
  l_type    VARCHAR2(1 BYTE);
  l_t       PLS_INTEGER;
  l_trailer VARCHAR2(32767);   -- o dicionario de uma xref em stream passa de 4000
  l_prev    VARCHAR2(200);
  l_root    PLS_INTEGER;
  l_rootval VARCHAR2(200);
  l_ent     xref_entry_rec;
  l_pages   PLS_INTEGER;
  l_ids     tpi;
  l_seen    tbool;
  l_guard   PLS_INTEGER := 0;
  l_stm     tpi;      -- objeto => object stream em que ele mora
  l_quais   tbool;    -- object streams distintos, para abrir cada um uma vez
  l_hib     VARCHAR2(200);
  l_lixo    VARCHAR2(32767);

  -- le o proximo inteiro de l_sec a partir de l_pos, avancando l_pos
  FUNCTION nx RETURN PLS_INTEGER IS
    l_a PLS_INTEGER;
  BEGIN
    WHILE l_pos <= l_n AND pdf_is_ws(SUBSTRB(l_sec, l_pos, 1)) LOOP
      l_pos := l_pos + 1;
    END LOOP;
    l_a := l_pos;
    WHILE l_pos <= l_n AND SUBSTRB(l_sec, l_pos, 1) BETWEEN '0' AND '9' LOOP
      l_pos := l_pos + 1;
    END LOOP;
    IF l_pos = l_a THEN
      RETURN NULL;
    END IF;
    RETURN TO_NUMBER(SUBSTRB(l_sec, l_a, l_pos - l_a));
  END nx;
BEGIN
  l_src.doc := p_doc;
  l_size := NVL(DBMS_LOB.GETLENGTH(p_doc), 0);
  IF l_size = 0 THEN
    RAISE_APPLICATION_ERROR(-20801, 'PDF vazio');
  END IF;
  IF pdf_read(p_doc, 0, 5) != '%PDF-' THEN
    RAISE_APPLICATION_ERROR(-20801, 'Cabecalho %PDF- ausente');
  END IF;

  -- ultimo 'startxref' do arquivo
  l_tail := pdf_read(p_doc, GREATEST(0, l_size - 2048), 2048);
  l_n    := NVL(LENGTHB(l_tail), 0);
  l_pos  := 0;
  l_t    := INSTRB(l_tail, 'startxref');
  WHILE l_t > 0 LOOP
    l_pos := l_t;
    l_t   := INSTRB(l_tail, 'startxref', l_t + 1);
  END LOOP;
  IF l_pos = 0 THEN
    RAISE_APPLICATION_ERROR(-20802, 'startxref nao encontrado');
  END IF;
  l_sec := l_tail;
  l_pos := l_pos + 9;
  l_off := nx;
  IF l_off IS NULL THEN
    RAISE_APPLICATION_ERROR(-20802, 'startxref sem offset');
  END IF;

  -- percorre a cadeia de secoes xref (/Prev)
  WHILE l_off IS NOT NULL AND NOT l_seen.EXISTS(l_off) LOOP
    l_seen(l_off) := TRUE;
    l_guard := l_guard + 1;
    EXIT WHEN l_guard > 64;

    l_sec := pdf_read(p_doc, l_off, 32767);
    l_n   := NVL(LENGTHB(l_sec), 0);

    -- Uma secao que nao comeca em 'xref' e um objeto /Type /XRef: a xref em
    -- stream do PDF 1.5+. O trailer dela e o proprio dicionario do objeto.
    IF SUBSTRB(l_sec, 1, 4) != 'xref' THEN
      pdf_xref_stream(p_doc, l_off, l_src, l_stm, l_trailer);
      IF l_rootval IS NULL THEN
        l_rootval := pdf_dict_value(l_trailer, '/Root');
      END IF;
      l_prev := pdf_dict_value(l_trailer, '/Prev');
      EXIT WHEN l_prev IS NULL;
      l_off := TO_NUMBER(TRIM(l_prev));
      CONTINUE;
    END IF;
    l_pos := 5;

    LOOP
      WHILE l_pos <= l_n AND pdf_is_ws(SUBSTRB(l_sec, l_pos, 1)) LOOP
        l_pos := l_pos + 1;
      END LOOP;
      EXIT WHEN l_pos > l_n OR SUBSTRB(l_sec, l_pos, 7) = 'trailer';
      l_start := nx;
      l_count := nx;
      EXIT WHEN l_start IS NULL OR l_count IS NULL;
      FOR i IN 0 .. l_count - 1 LOOP
        l_eoff := nx;
        l_gen  := nx;
        WHILE l_pos <= l_n AND pdf_is_ws(SUBSTRB(l_sec, l_pos, 1)) LOOP
          l_pos := l_pos + 1;
        END LOOP;
        l_type := SUBSTRB(l_sec, l_pos, 1);
        l_pos  := l_pos + 1;
        EXIT WHEN l_eoff IS NULL;
        -- a secao mais recente vence: nao sobrescreve o que ja foi lido
        IF l_type = 'n' AND NOT l_src.xref.EXISTS(l_start + i) THEN
          l_ent.offset     := l_eoff;
          l_ent.generation := l_gen;
          l_ent.in_use     := TRUE;
          l_src.xref(l_start + i) := l_ent;   -- atribuicao do registro inteiro
        END IF;
      END LOOP;
    END LOOP;

    l_t := INSTRB(l_sec, 'trailer');
    -- Sem 'trailer' na janela E com a janela cheia, a secao xref nao coube nos
    -- 32767 bytes que o pdf_read entrega: acima de ~1638 entradas (20 bytes
    -- cada) o resto da tabela foi cortado calado. Antes disto o laco saia aqui,
    -- l_rootval ficava NULL e o erro que chegava ao chamador era um
    -- '-20803 /Root nao encontrado no trailer' — que aponta para o lugar
    -- errado e manda procurar defeito num PDF que esta intacto.
    IF l_t = 0 AND l_n >= 32767 THEN
      RAISE_APPLICATION_ERROR(-20841,
        'Secao xref classica em ' || l_off || ' excede os 32767 bytes que se ' ||
        'consegue ler de uma vez (mais de ~1638 entradas). Este PDF nao e ' ||
        'suportado pela leitura de xref classica.');
    END IF;
    EXIT WHEN l_t = 0;
    l_trailer := SUBSTRB(l_sec, l_t, 4000);

    -- Hibrido: o trailer classico traz /XRefStm apontando para uma xref em
    -- stream com o que o leitor antigo nao enxerga. E raro, mas o Acrobat
    -- gera, e ignora-lo perde objetos EM SILENCIO — a tabela classica marca
    -- como livres justamente os que so o /XRefStm tem. Lido depois da tabela,
    -- como manda a especificacao, e antes do /Prev; a regra "quem chegou
    -- primeiro vence" cuida do resto.
    l_hib := pdf_dict_value(l_trailer, '/XRefStm');
    IF l_hib IS NOT NULL THEN
      pdf_xref_stream(p_doc, TO_NUMBER(TRIM(l_hib)), l_src, l_stm, l_lixo);
    END IF;

    IF l_rootval IS NULL THEN
      l_rootval := pdf_dict_value(l_trailer, '/Root');
    END IF;
    l_prev := pdf_dict_value(l_trailer, '/Prev');
    EXIT WHEN l_prev IS NULL;
    l_off := TO_NUMBER(TRIM(l_prev));
  END LOOP;

  -- Materializa os objetos que moram dentro de object streams. Cada ObjStm e
  -- aberto uma vez so, mesmo guardando dezenas de objetos: descomprimir por
  -- objeto seria o custo dominante da carga.
  l_pos := l_stm.FIRST;
  WHILE l_pos IS NOT NULL LOOP
    l_quais(l_stm(l_pos)) := TRUE;
    l_pos := l_stm.NEXT(l_pos);
  END LOOP;
  IF p_materializar THEN
    l_pos := l_quais.FIRST;
    WHILE l_pos IS NOT NULL LOOP
      pdf_objstm_load(l_src, l_pos, l_stm, p_chave, p_aes, p_r6);
      l_pos := l_quais.NEXT(l_pos);
    END LOOP;
  END IF;

  IF l_rootval IS NULL THEN
    RAISE_APPLICATION_ERROR(-20803, '/Root nao encontrado no trailer');
  END IF;
  l_ids.DELETE;
  pdf_collect_refs(l_rootval, l_ids);
  IF l_ids.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20803, '/Root nao e uma referencia indireta');
  END IF;
  l_root := l_ids(1);
  l_src.root := l_root;

  l_ids.DELETE;
  pdf_collect_refs(pdf_dict_value(l_trailer, '/Info'), l_ids);
  IF l_ids.COUNT > 0 THEN
    l_src.info := l_ids(1);
  END IF;

  -- Sem materializar nao ha como andar a arvore de paginas: o Catalog e as
  -- proprias paginas costumam morar dentro do object stream. Quem pediu isso
  -- queria a xref e o trailer, e e o que leva.
  IF NOT p_materializar THEN
    RETURN l_src;
  END IF;

  l_ids.DELETE;
  pdf_collect_refs(pdf_dict_value(pdf_obj_body(l_src, l_root), '/Pages'), l_ids);
  IF l_ids.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20804, '/Pages nao encontrado no Catalog');
  END IF;
  l_pages := l_ids(1);

  pdf_walk_pages(l_src, l_pages, NULL, NULL, NULL, NULL, 0);
  IF l_src.pages.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20804, 'Nenhuma pagina encontrada no PDF');
  END IF;
  RETURN l_src;
END pdf_src_load;

--------------------------------------------------------------------------------
-- pdf_parse_pages: '1,3,5-7' ou 'ALL' => indices de pagina, na ordem pedida
--------------------------------------------------------------------------------
FUNCTION pdf_parse_pages(p_spec IN VARCHAR2, p_total IN PLS_INTEGER) RETURN tpi IS
  l_out  tpi;
  l_spec VARCHAR2(32767) := TRIM(p_spec);
  l_part VARCHAR2(200);
  l_dash PLS_INTEGER;
  l_a    PLS_INTEGER;
  l_b    PLS_INTEGER;
  l_i    PLS_INTEGER := 1;
  l_c    PLS_INTEGER;

  FUNCTION as_int(p_t IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    IF p_t IS NULL OR LTRIM(p_t, '0123456789') IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20838,
        'Especificacao de paginas invalida: ' || p_spec);
    END IF;
    RETURN TO_NUMBER(p_t);
  END as_int;
BEGIN
  IF l_spec IS NULL THEN
    RAISE_APPLICATION_ERROR(-20838, 'Especificacao de paginas vazia');
  END IF;
  IF UPPER(l_spec) = 'ALL' THEN
    FOR i IN 1 .. p_total LOOP
      l_out(i) := i;
    END LOOP;
    RETURN l_out;
  END IF;

  LOOP
    l_c := INSTR(l_spec, ',', l_i);
    IF l_c = 0 THEN
      l_part := TRIM(SUBSTR(l_spec, l_i));
      l_i := LENGTH(l_spec) + 2;
    ELSE
      l_part := TRIM(SUBSTR(l_spec, l_i, l_c - l_i));
      l_i := l_c + 1;
    END IF;

    l_dash := INSTR(l_part, '-');
    IF l_dash > 0 THEN
      l_a := as_int(TRIM(SUBSTR(l_part, 1, l_dash - 1)));
      l_b := as_int(TRIM(SUBSTR(l_part, l_dash + 1)));
    ELSE
      l_a := as_int(l_part);
      l_b := l_a;
    END IF;

    IF l_a < 1 OR l_b < l_a THEN
      RAISE_APPLICATION_ERROR(-20838,
        'Intervalo de paginas invalido: ' || l_part);
    END IF;
    IF l_b > p_total THEN
      RAISE_APPLICATION_ERROR(-20839,
        'Pagina ' || l_b || ' fora do intervalo 1..' || p_total);
    END IF;
    FOR p IN l_a .. l_b LOOP
      l_out(l_out.COUNT + 1) := p;
    END LOOP;

    EXIT WHEN l_i > LENGTH(l_spec) + 1;
  END LOOP;

  IF l_out.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20838, 'Nenhuma pagina selecionada: ' || p_spec);
  END IF;
  RETURN l_out;
END pdf_parse_pages;
FUNCTION ovl_num(p_v IN NUMBER) RETURN VARCHAR2 IS
BEGIN
  RETURN TO_CHAR(ROUND(NVL(p_v, 0), 4), 'TM9', co_nls_num);
END ovl_num;

-- ovl_escape: escapa uma string literal do PDF
FUNCTION ovl_escape(p_txt IN VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  RETURN p_escapa_pdf(p_txt);
END ovl_escape;

-- ovl_familia / ovl_fonte_nome / ovl_fonte_base: as tres familias suportadas
--
-- 'Arial' e sinonimo de Helvetica no PDF, como no resto do package. Qualquer
-- outro nome cai em Helvetica em vez de levantar erro: o overlay ja foi aceito
-- por OverlayText, e recusar so na hora de desenhar deixaria o chamador sem
-- saida — o pedido ja esta registrado.
FUNCTION ovl_familia(p_fonte IN VARCHAR2) RETURN VARCHAR2 IS
  l_f VARCHAR2(50) := LOWER(TRIM(NVL(p_fonte, 'helvetica')));
BEGIN
  RETURN CASE
           WHEN l_f IN ('times', 'times-roman', 'timesnewroman') THEN 'T'
           WHEN l_f IN ('courier', 'couriernew', 'mono')         THEN 'C'
           ELSE 'H'                       -- helvetica, arial, sans e o resto
         END;
END ovl_familia;

-- nome do recurso no /Font da pagina, um por combinacao de familia e peso
FUNCTION ovl_fonte_nome(p_fonte IN VARCHAR2, p_bold IN BOOLEAN)
  RETURN VARCHAR2 IS
BEGIN
  RETURN 'Fwm' || ovl_familia(p_fonte)
      || CASE WHEN NVL(p_bold, FALSE) THEN 'B' END;
END ovl_fonte_nome;

-- /BaseFont correspondente
FUNCTION ovl_fonte_base(p_fonte IN VARCHAR2, p_bold IN BOOLEAN)
  RETURN VARCHAR2 IS
  l_fam VARCHAR2(1) := ovl_familia(p_fonte);
  l_b   BOOLEAN := NVL(p_bold, FALSE);
BEGIN
  RETURN CASE l_fam
           -- Times nao segue o padrao dos outros: o normal e 'Times-Roman',
           -- nao 'Times'. Um /BaseFont /Times faz o leitor cair na fonte
           -- substituta e o texto sai com a metrica errada.
           WHEN 'T' THEN CASE WHEN l_b THEN 'Times-Bold' ELSE 'Times-Roman' END
           WHEN 'C' THEN 'Courier' || CASE WHEN l_b THEN '-Bold' END
           ELSE          'Helvetica' || CASE WHEN l_b THEN '-Bold' END
         END;
END ovl_fonte_base;

-- ovl_largura: largura do texto em pontos, na fonte pedida
--
-- Usa a metrica do proprio package, mas NAO GetStringWidth: aquela depende da
-- fonte corrente (CurrentFont/fontsize), e aqui nao ha documento em edicao —
-- OutputModifiedPDF trabalha sobre um PDF carregado.
FUNCTION ovl_largura(
  p_txt   IN VARCHAR2,
  p_corpo IN NUMBER,
  p_fonte IN VARCHAR2 DEFAULT NULL,
  p_bold  IN BOOLEAN DEFAULT FALSE
) RETURN NUMBER IS
  l_fam VARCHAR2(1) := ovl_familia(p_fonte);
  l_b   BOOLEAN := NVL(p_bold, FALSE);
  l_cw  charSet;
  l_w   NUMBER := 0;
  l_c   VARCHAR2(1 CHAR);
BEGIN
  -- Mesma fonte de metrica que o resto do package: p_larguras_da_fonte, com a
  -- chave 'familia+estilo'. Antes isto chamava as getFontXxx direto — e quando
  -- elas sairam, esta linha ficou apontando para o nada.
  l_cw := p_larguras_da_fonte(
            CASE l_fam
              WHEN 'T' THEN CASE WHEN l_b THEN 'timesB' ELSE 'times' END
              WHEN 'C' THEN 'courier'   -- monoespacada: mesma metrica
              ELSE CASE WHEN l_b THEN 'helveticaB' ELSE 'helvetica' END
            END);
  FOR i IN 1 .. NVL(LENGTH(p_txt), 0) LOOP
    l_c := SUBSTR(p_txt, i, 1);
    BEGIN
      l_w := l_w + l_cw(l_c);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN l_w := l_w + 556;   -- largura media
    END;
  END LOOP;
  RETURN l_w * p_corpo / 1000;
END ovl_largura;

-- ovl_gs_nome: nome do /ExtGState de uma opacidade
--
-- Um nome por opacidade, e nao um /GSwm unico: uma pagina pode ter marca
-- d'agua a 30% e um carimbo opaco, e com um so estado grafico o segundo
-- herdaria a transparencia do primeiro.
FUNCTION ovl_gs_nome(p_opac IN NUMBER) RETURN VARCHAR2 IS
BEGIN
  RETURN 'GSwm' || LPAD(TO_CHAR(ROUND(LEAST(GREATEST(NVL(p_opac, 1), 0), 1)
                                      * 100)), 3, '0');
END ovl_gs_nome;

-- ovl_matriz: matriz de rotacao com translacao para (x, y)
FUNCTION ovl_matriz(p_rot IN NUMBER, p_x IN NUMBER, p_y IN NUMBER)
  RETURN VARCHAR2 IS
  l_r   NUMBER := NVL(p_rot, 0) * 3.14159265358979 / 180;
  l_cos NUMBER := ROUND(COS(l_r), 6);
  l_sin NUMBER := ROUND(SIN(l_r), 6);
BEGIN
  RETURN ovl_num(l_cos) || ' ' || ovl_num(l_sin) || ' '
      || ovl_num(-l_sin) || ' ' || ovl_num(l_cos) || ' '
      || ovl_num(p_x) || ' ' || ovl_num(p_y);
END ovl_matriz;

-- ovl_marca_dagua: texto centralizado e girado em torno do centro da pagina
FUNCTION ovl_marca_dagua(
  p_texto  IN VARCHAR2,
  p_larg   IN NUMBER,
  p_alt    IN NUMBER,
  p_rot    IN NUMBER,
  p_corpo  IN NUMBER,
  p_opac   IN NUMBER,
  p_r      IN NUMBER,
  p_g      IN NUMBER,
  p_b      IN NUMBER
) RETURN VARCHAR2 IS
  l_r  NUMBER := NVL(p_rot, 0) * 3.14159265358979 / 180;
  l_dx NUMBER := -ovl_largura(p_texto, p_corpo, 'Helvetica', FALSE) / 2;
  l_dy NUMBER := -p_corpo * 0.35;
  l_tx NUMBER;
  l_ty NUMBER;
BEGIN
  -- O Tm posiciona a ORIGEM do texto, nao o centro dele: para o texto ficar
  -- centrado e preciso recuar metade da largura e um pouco da altura — e esse
  -- recuo tem de ser girado junto, senao a marca sai deslocada quanto maior o
  -- angulo.
  l_tx := p_larg / 2 + l_dx * COS(l_r) - l_dy * SIN(l_r);
  l_ty := p_alt  / 2 + l_dx * SIN(l_r) + l_dy * COS(l_r);
  RETURN 'q /' || ovl_gs_nome(p_opac) || ' gs '
      || ovl_num(p_r) || ' ' || ovl_num(p_g) || ' ' || ovl_num(p_b) || ' rg'
      -- O nome do recurso TEM de sair de ovl_fonte_nome: aqui havia um
      -- '/FwmPLFPDF' fixo, que nao e declarado no /Font de pagina nenhuma —
      -- o Tf ficava sem fonte e a marca d'agua nao desenhava. A largura acima
      -- e medida com Helvetica nao-negrito, entao e essa que se declara.
      || CHR(10) || 'BT /' || ovl_fonte_nome('Helvetica', FALSE) || ' '
      || ovl_num(p_corpo) || ' Tf' || CHR(10)
      || ovl_matriz(p_rot, l_tx, l_ty) || ' Tm' || CHR(10)
      || '(' || ovl_escape(p_texto) || ') Tj' || CHR(10) || 'ET Q' || CHR(10);
END ovl_marca_dagua;

-- ovl_texto: texto numa posicao da pagina, com alinhamento e quebra de linha
--
-- p_larg define a CAIXA em que o texto vive:
--   * com caixa, o texto quebra em varias linhas e o alinhamento e relativo a
--     [x, x + largura];
--   * sem caixa, nao ha o que quebrar e o alinhamento passa a ser relativo ao
--     proprio ponto: 'left' comeca em x, 'center' o centraliza em x, 'right'
--     termina em x.
-- Tratar os dois casos igual faria 'center' sem largura desenhar exatamente
-- como 'left', que e como a versao anterior se comportava para tudo.
FUNCTION ovl_texto(
  p_x     IN NUMBER,
  p_y     IN NUMBER,
  p_texto IN VARCHAR2,
  p_corpo IN NUMBER,
  p_rot   IN NUMBER,
  p_opac  IN NUMBER,
  p_r     IN NUMBER,
  p_g     IN NUMBER,
  p_b     IN NUMBER,
  p_fonte IN VARCHAR2 DEFAULT NULL,
  p_bold  IN BOOLEAN  DEFAULT FALSE,
  p_align IN VARCHAR2 DEFAULT 'left',
  p_larg  IN NUMBER   DEFAULT NULL
) RETURN VARCHAR2 IS
  co_entre CONSTANT NUMBER := 1.15;      -- entrelinha, em multiplos do corpo
  l_fonte  VARCHAR2(20) := ovl_fonte_nome(p_fonte, p_bold);
  l_align  VARCHAR2(10) := LOWER(NVL(p_align, 'left'));
  l_linhas tv32k;
  l_out    VARCHAR2(32767);
  l_dx     NUMBER;
  l_ly     NUMBER;
  l_lw     NUMBER;

  -- quebra em palavras, sem cortar no meio de uma. Uma palavra sozinha mais
  -- larga que a caixa fica na propria linha e transborda: cortar caractere a
  -- caractere estragaria URLs e codigos, que e justamente o que costuma
  -- aparecer em carimbo.
  PROCEDURE quebrar IS
    l_resto VARCHAR2(32767) := p_texto;
    l_esp   PLS_INTEGER;
    l_linha VARCHAR2(32767);
    l_prox  VARCHAR2(32767);
  BEGIN
    IF p_larg IS NULL OR p_larg <= 0 THEN
      l_linhas(1) := p_texto;
      RETURN;
    END IF;
    WHILE l_resto IS NOT NULL LOOP
      l_linha := NULL;
      LOOP
        l_esp := INSTR(l_resto, ' ');
        l_prox := CASE WHEN l_esp = 0 THEN l_resto
                       ELSE SUBSTR(l_resto, 1, l_esp - 1) END;
        EXIT WHEN l_linha IS NOT NULL
              AND ovl_largura(l_linha || ' ' || l_prox, p_corpo, p_fonte, p_bold)
                  > p_larg;
        l_linha := CASE WHEN l_linha IS NULL THEN l_prox
                        ELSE l_linha || ' ' || l_prox END;
        l_resto := CASE WHEN l_esp = 0 THEN NULL
                        ELSE SUBSTR(l_resto, l_esp + 1) END;
        EXIT WHEN l_resto IS NULL;
      END LOOP;
      l_linhas(l_linhas.COUNT + 1) := l_linha;
      EXIT WHEN l_resto IS NULL;
    END LOOP;
  END quebrar;
BEGIN
  quebrar;
  l_out := 'q /' || ovl_gs_nome(p_opac) || ' gs '
        || ovl_num(p_r) || ' ' || ovl_num(p_g) || ' ' || ovl_num(p_b) || ' rg'
        || CHR(10) || 'BT /' || l_fonte || ' ' || ovl_num(p_corpo) || ' Tf'
        || CHR(10);

  FOR i IN 1 .. l_linhas.COUNT LOOP
    l_lw := ovl_largura(l_linhas(i), p_corpo, p_fonte, p_bold);
    IF p_larg IS NOT NULL AND p_larg > 0 THEN
      l_dx := CASE l_align WHEN 'center' THEN (p_larg - l_lw) / 2
                           WHEN 'right'  THEN p_larg - l_lw
                           ELSE 0 END;
    ELSE
      l_dx := CASE l_align WHEN 'center' THEN -l_lw / 2
                           WHEN 'right'  THEN -l_lw
                           ELSE 0 END;
    END IF;
    l_ly := -(i - 1) * p_corpo * co_entre;   -- linhas descem

    -- O deslocamento entra ANTES da rotacao, para acompanhar o texto girado:
    -- somar em x depois de girar jogaria as linhas para fora do carimbo.
    l_out := l_out
          || ovl_matriz(p_rot,
               p_x + l_dx * COS(NVL(p_rot, 0) * 3.14159265358979 / 180)
                   - l_ly * SIN(NVL(p_rot, 0) * 3.14159265358979 / 180),
               p_y + l_dx * SIN(NVL(p_rot, 0) * 3.14159265358979 / 180)
                   + l_ly * COS(NVL(p_rot, 0) * 3.14159265358979 / 180))
          || ' Tm' || CHR(10)
          || '(' || ovl_escape(l_linhas(i)) || ') Tj' || CHR(10);
  END LOOP;

  RETURN l_out || 'ET Q' || CHR(10);
END ovl_texto;

-- ovl_imagem: imagem posicionada e escalada
--
-- Sao dois 'cm': primeiro a posicao/rotacao, depois a escala. Juntar os dois
-- numa matriz so faria a rotacao deformar o desenho, porque a escala entraria
-- antes de girar.
FUNCTION ovl_imagem(
  p_x    IN NUMBER,
  p_y    IN NUMBER,
  p_larg IN NUMBER,
  p_alt  IN NUMBER,
  p_nome IN VARCHAR2,
  p_rot  IN NUMBER,
  p_opac IN NUMBER
) RETURN VARCHAR2 IS
BEGIN
  RETURN 'q /' || ovl_gs_nome(p_opac) || ' gs '
      || ovl_matriz(p_rot, p_x, p_y) || ' cm' || CHR(10)
      || ovl_num(p_larg) || ' 0 0 ' || ovl_num(p_alt) || ' 0 0 cm' || CHR(10)
      || '/' || p_nome || ' Do' || CHR(10) || 'Q' || CHR(10);
END ovl_imagem;

--------------------------------------------------------------------------------
-- ovl_recursos_texto: entradas de /Resources para os desenhos de texto
--
-- Vao como dicionarios diretos, que sao legais dentro de /Resources e poupam
-- dois objetos indiretos por pagina.
--------------------------------------------------------------------------------
FUNCTION ovl_recursos_texto(p_gs IN VARCHAR2, p_fontes IN VARCHAR2)
  RETURN VARCHAR2 IS
BEGIN
  RETURN '/Font << ' || p_fontes || ' >>'
      || ' /ExtGState << ' || p_gs || ' >>';
END ovl_recursos_texto;

-- ovl_fonte_entrada: o dicionario de uma fonte, para entrar no /Font da pagina
FUNCTION ovl_fonte_entrada(p_fonte IN VARCHAR2, p_bold IN BOOLEAN)
  RETURN VARCHAR2 IS
BEGIN
  RETURN '/' || ovl_fonte_nome(p_fonte, p_bold)
      || ' << /Type /Font /Subtype /Type1 /BaseFont /'
      || ovl_fonte_base(p_fonte, p_bold)
      || ' /Encoding /WinAnsiEncoding >>';
END ovl_fonte_entrada;

-- ovl_gs_entrada: o /ExtGState de uma opacidade
FUNCTION ovl_gs_entrada(p_opac IN NUMBER) RETURN VARCHAR2 IS
  l_o VARCHAR2(20) := ovl_num(LEAST(GREATEST(NVL(p_opac, 1), 0), 1));
BEGIN
  RETURN '/' || ovl_gs_nome(p_opac) || ' << /Type /ExtGState'
      || ' /ca ' || l_o || ' /CA ' || l_o || ' >>';
END ovl_gs_entrada;

--------------------------------------------------------------------------------
-- PNG que precisa de reprocessamento de pixels
--
-- Portado de scripts/pdfimage_reference/, validado nos PIXELS que o MuPDF
-- desenha (25/25). Ate agosto/2026 estes casos eram recusados com ORA-20823
-- por falta de um inflate em PL/SQL; ele existe desde a xref em stream, e o
-- desfazer do filtro por linha e o mesmo pdf_undo_pred do /Predictor do PDF.
--
-- O que NAO existe e um deflate, entao o que sai deste caminho vai SEM
-- compressao. E maior no arquivo e e honesto; comprimir de volta exigiria
-- escrever um deflate, que e outro trabalho inteiro.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ovl_png_desentrelacar: Adam7 -> raster continuo
--
-- As sete passagens sao imagens INDEPENDENTES, cada uma com a sua largura, a
-- sua altura e a sua filtragem por linha. Desfiltrar o bloco inteiro de uma vez,
-- como se fosse uma imagem so, produz ruido.
--
-- A montagem e por LINHA de destino, e nao por pixel de origem: escrever no
-- meio de um raster exigiria acesso aleatorio, que em PL/SQL sai caro de
-- qualquer forma que se faca. Percorrendo o destino em ordem, cada linha e
-- montada por concatenacao — que e barata — puxando de uma linha ja carregada
-- da passagem que possui aquele x.
--------------------------------------------------------------------------------
PROCEDURE ovl_png_desentrelacar(
  p_dados  IN            BLOB,
  p_larg   IN            PLS_INTEGER,
  p_alt    IN            PLS_INTEGER,
  p_canais IN            PLS_INTEGER,
  p_bits   IN            PLS_INTEGER,
  o_raster IN OUT NOCOPY BLOB
) IS
  l_x0    tpi;
  l_y0    tpi;
  l_dx    tpi;
  l_dy    tpi;
  l_pl    tpi;             -- largura da passagem
  l_pa    tpi;             -- altura da passagem
  l_bloco tblob;           -- passagem ja desfiltrada
  l_hexp  tv32k;           -- linha corrente de cada passagem, em hexadecimal
  l_passo PLS_INTEGER := p_canais * p_bits / 8;   -- bytes por pixel
  l_pos   PLS_INTEGER := 1;
  l_linha PLS_INTEGER;
  l_tam   PLS_INTEGER;
  l_tmp   BLOB;
  l_hex   VARCHAR2(32767);
  l_j     PLS_INTEGER;
  l_i     PLS_INTEGER;
  l_dono  PLS_INTEGER;
BEGIN
  IF p_bits < 8 THEN
    RAISE_APPLICATION_ERROR(-20823,
      'PNG entrelacado com menos de 8 bits por componente nao suportado: '
      || 'exigiria empacotar bit a bit.');
  END IF;

  -- as sete passagens do Adam7: x inicial, y inicial, passo em x, passo em y
  l_x0(1) := 0; l_y0(1) := 0; l_dx(1) := 8; l_dy(1) := 8;
  l_x0(2) := 4; l_y0(2) := 0; l_dx(2) := 8; l_dy(2) := 8;
  l_x0(3) := 0; l_y0(3) := 4; l_dx(3) := 4; l_dy(3) := 8;
  l_x0(4) := 2; l_y0(4) := 0; l_dx(4) := 4; l_dy(4) := 4;
  l_x0(5) := 0; l_y0(5) := 2; l_dx(5) := 2; l_dy(5) := 4;
  l_x0(6) := 1; l_y0(6) := 0; l_dx(6) := 2; l_dy(6) := 2;
  l_x0(7) := 0; l_y0(7) := 1; l_dx(7) := 1; l_dy(7) := 2;

  -- desfiltra cada passagem, uma de cada vez
  FOR p IN 1 .. 7 LOOP
    l_pl(p) := FLOOR((p_larg - l_x0(p) + l_dx(p) - 1) / l_dx(p));
    l_pa(p) := FLOOR((p_alt  - l_y0(p) + l_dy(p) - 1) / l_dy(p));
    IF l_pl(p) <= 0 OR l_pa(p) <= 0 THEN
      l_pl(p) := 0; l_pa(p) := 0;
      CONTINUE;
    END IF;
    l_linha := CEIL(l_pl(p) * p_canais * p_bits / 8);
    l_tam   := (l_linha + 1) * l_pa(p);
    DBMS_LOB.CREATETEMPORARY(l_tmp, TRUE);
    DBMS_LOB.COPY(l_tmp, p_dados, l_tam, 1, l_pos);
    pdf_undo_pred(l_tmp, 12, p_canais, p_bits, l_pl(p));
    l_bloco(p) := l_tmp;
    l_tmp := NULL;                     -- a tabela e a dona do LOB agora
    l_pos := l_pos + l_tam;
  END LOOP;

  -- monta o destino, linha a linha
  FOR y IN 0 .. p_alt - 1 LOOP
    l_hexp.DELETE;
    FOR p IN 1 .. 7 LOOP
      IF l_pl(p) > 0 AND MOD(y - l_y0(p), l_dy(p)) = 0 AND y >= l_y0(p) THEN
        l_j := FLOOR((y - l_y0(p)) / l_dy(p));
        l_hexp(p) := RAWTOHEX(DBMS_LOB.SUBSTR(
                       l_bloco(p), l_pl(p) * l_passo,
                       l_j * l_pl(p) * l_passo + 1));
      END IF;
    END LOOP;

    l_hex := NULL;
    FOR x IN 0 .. p_larg - 1 LOOP
      l_dono := NULL;
      FOR p IN 1 .. 7 LOOP
        IF l_hexp.EXISTS(p) AND x >= l_x0(p)
           AND MOD(x - l_x0(p), l_dx(p)) = 0 THEN
          l_dono := p;
          EXIT;
        END IF;
      END LOOP;
      IF l_dono IS NULL THEN
        RAISE_APPLICATION_ERROR(-20823,
          'PNG entrelacado: pixel (' || x || ',' || y || ') sem passagem.');
      END IF;
      l_i := FLOOR((x - l_x0(l_dono)) / l_dx(l_dono));
      l_hex := l_hex || SUBSTR(l_hexp(l_dono), l_i * l_passo * 2 + 1,
                               l_passo * 2);
      IF LENGTH(l_hex) >= 32000 THEN
        DBMS_LOB.WRITEAPPEND(o_raster, LENGTH(l_hex) / 2, HEXTORAW(l_hex));
        l_hex := NULL;
      END IF;
    END LOOP;
    IF l_hex IS NOT NULL THEN
      DBMS_LOB.WRITEAPPEND(o_raster, LENGTH(l_hex) / 2, HEXTORAW(l_hex));
    END IF;
  END LOOP;

  FOR p IN 1 .. 7 LOOP
    IF l_bloco.EXISTS(p) THEN
      DBMS_LOB.FREETEMPORARY(l_bloco(p));
    END IF;
  END LOOP;
END ovl_png_desentrelacar;

--------------------------------------------------------------------------------
-- ovl_png_separar_alfa: parte o raster em cor e transparencia
--
-- O PDF NAO tem alfa dentro do pixel: a transparencia e um segundo objeto de
-- imagem, em /DeviceGray, apontado por /SMask. Um PNG RGBA vira dois objetos.
--------------------------------------------------------------------------------
PROCEDURE ovl_png_separar_alfa(
  p_raster IN            BLOB,
  p_larg   IN            PLS_INTEGER,
  p_alt    IN            PLS_INTEGER,
  p_cores  IN            PLS_INTEGER,     -- canais de COR (1 ou 3)
  p_bits   IN            PLS_INTEGER,
  o_cor    IN OUT NOCOPY BLOB,
  o_alfa   IN OUT NOCOPY BLOB
) IS
  l_b     PLS_INTEGER := p_bits / 8;              -- bytes por componente
  l_passo PLS_INTEGER := (p_cores + 1) * l_b;     -- bytes por pixel, com alfa
  l_lote  PLS_INTEGER;                            -- pixels por leitura
  l_pos   PLS_INTEGER := 1;
  l_n     PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_raster), 0);
  l_hex   VARCHAR2(32767);
  l_hc    VARCHAR2(32767);
  l_ha    VARCHAR2(32767);
  l_qtd   PLS_INTEGER;
BEGIN
  -- em lotes: uma chamada de DBMS_LOB por pixel seria o custo dominante
  l_lote := GREATEST(1, FLOOR(16000 / l_passo));
  WHILE l_pos <= l_n LOOP
    l_qtd := LEAST(l_lote, FLOOR((l_n - l_pos + 1) / l_passo));
    EXIT WHEN l_qtd <= 0;
    l_hex := RAWTOHEX(DBMS_LOB.SUBSTR(p_raster, l_qtd * l_passo, l_pos));
    l_hc := NULL;
    l_ha := NULL;
    FOR k IN 0 .. l_qtd - 1 LOOP
      l_hc := l_hc || SUBSTR(l_hex, k * l_passo * 2 + 1, p_cores * l_b * 2);
      l_ha := l_ha || SUBSTR(l_hex, (k * l_passo + p_cores * l_b) * 2 + 1,
                             l_b * 2);
    END LOOP;
    DBMS_LOB.WRITEAPPEND(o_cor,  LENGTH(l_hc) / 2, HEXTORAW(l_hc));
    DBMS_LOB.WRITEAPPEND(o_alfa, LENGTH(l_ha) / 2, HEXTORAW(l_ha));
    l_pos := l_pos + l_qtd * l_passo;
  END LOOP;
END ovl_png_separar_alfa;

--------------------------------------------------------------------------------
-- ovl_img_xobject: converte o BLOB de uma imagem no /XObject do PDF
--
-- Portado de scripts/pdfimage_reference/, validado contra o MuPDF: cada caso e
-- desenhado e os pixels sao conferidos, porque um /DecodeParms errado ou um
-- /ColorSpace trocado produzem um arquivo valido que desenha ruido.
--
-- Nenhum dos dois formatos precisa ser descomprimido aqui:
--   JPEG entra inteiro, com /DCTDecode;
--   PNG guarda os dados em IDAT ja em zlib, que e o /FlateDecode do PDF —
--   basta concatenar os IDAT e declarar /Predictor 15, porque o PNG filtra
--   cada linha e o leitor sabe desfazer isso.
--
-- p_parseImage, que ja existe no package, nao serve: le de ARQUIVO
-- (getImageFromUrl) e so trata PNG.
--------------------------------------------------------------------------------
PROCEDURE ovl_img_xobject(
  p_img     IN            BLOB,
  o_dic     OUT           VARCHAR2,
  o_dados   IN OUT NOCOPY BLOB,
  o_larg    OUT           NUMBER,
  o_alt     OUT           NUMBER,
  -- Segundo objeto de imagem, so quando o PNG tem canal alfa: o PDF nao guarda
  -- a transparencia dentro do pixel. Fica NULL nos demais casos.
  o_msk_dic OUT           VARCHAR2,
  o_msk_dat IN OUT NOCOPY BLOB
) IS
  l_n    PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_img), 0);

  -- inteiro sem sinal de p_tam bytes, big-endian, na posicao p_pos (base 1)
  FUNCTION u(p_pos IN PLS_INTEGER, p_tam IN PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN
    RETURN TO_NUMBER(RAWTOHEX(DBMS_LOB.SUBSTR(p_img, p_tam, p_pos)),
                     RPAD('X', p_tam * 2, 'X'));
  END u;
BEGIN
  IF l_n < 12 THEN
    RAISE_APPLICATION_ERROR(-20823,
      'Imagem invalida: menos de 12 bytes');
  END IF;

  -- ── JPEG ──────────────────────────────────────────────────────────────────
  IF DBMS_LOB.SUBSTR(p_img, 3, 1) = HEXTORAW('FFD8FF') THEN
    DECLARE
      l_i     PLS_INTEGER := 3;
      l_marca PLS_INTEGER;
      l_tam   PLS_INTEGER;
      l_comp  PLS_INTEGER;
      l_bits  PLS_INTEGER;
      l_cs    VARCHAR2(20);
    BEGIN
      WHILE l_i < l_n LOOP
        IF u(l_i, 1) != 255 THEN
          l_i := l_i + 1;
          CONTINUE;
        END IF;
        l_marca := u(l_i + 1, 1);
        -- padding, RSTn e SOI nao tem tamanho
        IF l_marca IN (216, 1) OR l_marca BETWEEN 208 AND 215 THEN
          l_i := l_i + 2;
          CONTINUE;
        END IF;
        EXIT WHEN l_marca IN (217, 218);          -- EOI, ou inicio do scan
        l_tam := u(l_i + 2, 2);

        -- Somente os SOF carregam as dimensoes. C4 (DHT), C8 (JPG) e CC (DAC)
        -- caem no meio da faixa mas NAO sao quadros: le-los como tal devolve
        -- lixo no lugar da largura.
        IF l_marca IN (192, 193, 194, 195, 197, 198, 199,
                       201, 202, 203, 205, 206, 207) THEN
          l_bits := u(l_i + 4, 1);
          o_alt  := u(l_i + 5, 2);
          o_larg := u(l_i + 7, 2);
          l_comp := u(l_i + 9, 1);
          l_cs := CASE l_comp WHEN 1 THEN '/DeviceGray'
                              WHEN 3 THEN '/DeviceRGB'
                              WHEN 4 THEN '/DeviceCMYK' END;
          IF l_cs IS NULL THEN
            RAISE_APPLICATION_ERROR(-20823,
              'JPEG com ' || l_comp || ' componentes nao suportado');
          END IF;
          o_dic := '<< /Type /XObject /Subtype /Image'
                || ' /Width ' || ovl_num(o_larg) || ' /Height ' || ovl_num(o_alt)
                || ' /ColorSpace ' || l_cs
                || ' /BitsPerComponent ' || l_bits
                || ' /Filter /DCTDecode'
                -- JPEG CMYK gravado pelo Adobe vem invertido; sem o /Decode as
                -- cores saem em negativo
                || CASE WHEN l_comp = 4 THEN ' /Decode [1 0 1 0 1 0 1 0]' END
                || ' /Length ' || l_n || ' >>';
          DBMS_LOB.COPY(o_dados, p_img, l_n, 1, 1);
          RETURN;
        END IF;
        l_i := l_i + 2 + l_tam;
      END LOOP;
      RAISE_APPLICATION_ERROR(-20823,
        'JPEG sem marcador SOF: dimensoes nao encontradas');
    END;
  END IF;

  -- ── PNG ───────────────────────────────────────────────────────────────────
  IF DBMS_LOB.SUBSTR(p_img, 8, 1) = HEXTORAW('89504E470D0A1A0A') THEN
    DECLARE
      l_i     PLS_INTEGER := 9;
      l_tam   PLS_INTEGER;
      l_tipo  VARCHAR2(4);
      l_bits  PLS_INTEGER;
      l_ct    PLS_INTEGER;
      l_pal   VARCHAR2(32767);
      l_cores PLS_INTEGER;
      l_cs    VARCHAR2(32767);
      l_idat  PLS_INTEGER := 0;
      l_entre PLS_INTEGER := 0;
      l_alfa  BOOLEAN;
      l_canais PLS_INTEGER;
      l_linha PLS_INTEGER;
      l_cru   BLOB;
      l_ras   BLOB;
    BEGIN
      WHILE l_i + 8 <= l_n + 1 LOOP
        l_tam  := u(l_i, 4);
        l_tipo := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(p_img, 4, l_i + 4));

        IF l_tipo = 'IHDR' THEN
          o_larg := u(l_i + 8, 4);
          o_alt  := u(l_i + 12, 4);
          l_bits := u(l_i + 16, 1);
          l_ct   := u(l_i + 17, 1);
          IF l_ct NOT IN (0, 2, 3, 4, 6) THEN
            RAISE_APPLICATION_ERROR(-20823,
              'PNG com color type ' || l_ct || ' nao suportado');
          END IF;
          IF u(l_i + 18, 1) != 0 OR u(l_i + 19, 1) != 0 THEN
            RAISE_APPLICATION_ERROR(-20823,
              'PNG com compressao ou filtro desconhecido');
          END IF;
          l_entre := u(l_i + 20, 1);

        ELSIF l_tipo = 'PLTE' THEN
          IF l_tam > 16000 THEN                   -- 768 bytes e o maximo real
            RAISE_APPLICATION_ERROR(-20823, 'Paleta PNG grande demais');
          END IF;
          l_pal := RAWTOHEX(DBMS_LOB.SUBSTR(p_img, l_tam, l_i + 8));

        ELSIF l_tipo = 'IDAT' THEN
          DBMS_LOB.COPY(o_dados, p_img, l_tam,
                        NVL(DBMS_LOB.GETLENGTH(o_dados), 0) + 1, l_i + 8);
          l_idat := l_idat + l_tam;

        ELSIF l_tipo = 'IEND' THEN
          EXIT;
        END IF;

        l_i := l_i + 12 + l_tam;                  -- 4 tam + 4 tipo + dados + 4 crc
      END LOOP;

      IF o_larg IS NULL THEN
        RAISE_APPLICATION_ERROR(-20823, 'PNG sem IHDR');
      END IF;
      IF l_ct = 3 AND l_pal IS NULL THEN
        RAISE_APPLICATION_ERROR(-20823, 'PNG indexado sem paleta');
      END IF;

      l_alfa   := l_ct IN (4, 6);
      l_cores  := CASE WHEN l_ct IN (2, 6) THEN 3 ELSE 1 END;
      l_canais := l_cores + CASE WHEN l_alfa THEN 1 ELSE 0 END;
      l_cs := CASE
                WHEN l_ct = 3 THEN '[/Indexed /DeviceRGB '
                                || (LENGTH(l_pal) / 6 - 1) || ' <' || l_pal || '>]'
                WHEN l_cores = 3 THEN '/DeviceRGB'
                ELSE '/DeviceGray' END;

      -- ── passagem direta ────────────────────────────────────────────────
      -- Sem alfa e sem entrelacamento nada e descomprimido: os IDAT ja sao
      -- zlib, que e o /FlateDecode do PDF. Vale para 1, 2, 4, 8 E 16 bits — o
      -- PDF aceita /BitsPerComponent 16, e o predictor tambem. O 16 estava
      -- recusado por engano, junto com os casos que de fato precisam de
      -- reprocessamento.
      IF NOT l_alfa AND l_entre = 0 THEN
        o_dic := '<< /Type /XObject /Subtype /Image'
              || ' /Width ' || ovl_num(o_larg) || ' /Height ' || ovl_num(o_alt)
              || ' /ColorSpace ' || l_cs
              || ' /BitsPerComponent ' || l_bits
              || ' /Filter /FlateDecode'
              -- o PNG filtra cada linha antes de comprimir; o Predictor 15
              -- manda o leitor desfazer isso. Sem ele a imagem sai como ruido.
              || ' /DecodeParms << /Predictor 15 /Colors ' || l_cores
              || ' /BitsPerComponent ' || l_bits
              || ' /Columns ' || ovl_num(o_larg) || ' >>'
              || ' /Length ' || l_idat || ' >>';
        RETURN;
      END IF;

      -- ── reprocessamento ────────────────────────────────────────────────
      IF l_ct = 3 THEN
        RAISE_APPLICATION_ERROR(-20823,
          'PNG indexado e entrelacado nao suportado.');
      END IF;
      IF l_bits < 8 THEN
        RAISE_APPLICATION_ERROR(-20823,
          'PNG com alfa ou entrelacado e menos de 8 bits por componente nao '
          || 'suportado: exigiria empacotar bit a bit.');
      END IF;
      IF o_larg * o_alt > co_img_max_px THEN
        RAISE_APPLICATION_ERROR(-20823,
          'Imagem de ' || o_larg || 'x' || o_alt || ' com canal alfa ou '
          || 'entrelacada passa do teto de ' || co_img_max_px || ' pixels. '
          || 'Este caminho reprocessa pixel a pixel em PL/SQL. Regrave a '
          || 'imagem sem alfa (ou achatada sobre um fundo) e sem entrelacar.');
      END IF;

      l_linha := CEIL(o_larg * l_canais * l_bits / 8);
      DBMS_LOB.CREATETEMPORARY(l_cru, TRUE);
      -- o teto do inflate e o tamanho que o raster TEM de ter, com folga para
      -- o byte de filtro de cada linha; um IDAT que produza mais que isso esta
      -- corrompido, ou nao e a imagem que o IHDR anuncia
      PL_FPDF_UTIL.inflate(o_dados, l_cru, (l_linha + 1) * o_alt + 1024);
      DBMS_LOB.TRIM(o_dados, 0);

      DBMS_LOB.CREATETEMPORARY(l_ras, TRUE);
      IF l_entre != 0 THEN
        ovl_png_desentrelacar(l_cru, o_larg, o_alt, l_canais, l_bits, l_ras);
      ELSE
        pdf_undo_pred(l_cru, 12, l_canais, l_bits, o_larg);
        DBMS_LOB.COPY(l_ras, l_cru, DBMS_LOB.GETLENGTH(l_cru), 1, 1);
      END IF;
      DBMS_LOB.FREETEMPORARY(l_cru);

      IF l_alfa THEN
        DBMS_LOB.CREATETEMPORARY(o_msk_dat, TRUE);
        ovl_png_separar_alfa(l_ras, o_larg, o_alt, l_cores, l_bits,
                             o_dados, o_msk_dat);
        o_msk_dic := '<< /Type /XObject /Subtype /Image'
                  || ' /Width ' || ovl_num(o_larg)
                  || ' /Height ' || ovl_num(o_alt)
                  || ' /ColorSpace /DeviceGray'
                  || ' /BitsPerComponent ' || l_bits
                  || ' /Length ' || DBMS_LOB.GETLENGTH(o_msk_dat) || ' >>';
      ELSE
        DBMS_LOB.COPY(o_dados, l_ras, DBMS_LOB.GETLENGTH(l_ras), 1, 1);
      END IF;
      DBMS_LOB.FREETEMPORARY(l_ras);

      -- sem /Filter: o package tem inflate, nao tem deflate. O arquivo fica
      -- maior, e e o preco honesto de reprocessar os pixels.
      o_dic := '<< /Type /XObject /Subtype /Image'
            || ' /Width ' || ovl_num(o_larg) || ' /Height ' || ovl_num(o_alt)
            || ' /ColorSpace ' || l_cs
            || ' /BitsPerComponent ' || l_bits
            || ' /Length ' || DBMS_LOB.GETLENGTH(o_dados) || ' >>';
      RETURN;
    END;
  END IF;

  RAISE_APPLICATION_ERROR(-20823,
    'Formato de imagem nao reconhecido (use JPEG ou PNG)');
END ovl_img_xobject;

--------------------------------------------------------------------------------
-- ovl_mesclar: junta as entradas novas num /Resources existente
--
-- Para cada chave (/Font, /ExtGState, /XObject), se ela ja existe como
-- dicionario direto as entradas entram nele; se nao existe, a chave e criada.
-- Uma chave INDIRETA e recusada: reescrever o objeto apontado espalharia a
-- alteracao por todas as paginas que o compartilham, que e exatamente o que
-- este caminho existe para evitar.
--------------------------------------------------------------------------------
FUNCTION ovl_mesclar(p_res IN VARCHAR2, p_novas IN VARCHAR2) RETURN VARCHAR2 IS
  l_out  VARCHAR2(32767) := NVL(TRIM(p_res), '<< >>');
  l_i    PLS_INTEGER := 1;
  l_n    PLS_INTEGER := NVL(LENGTHB(p_novas), 0);
  l_ini  PLS_INTEGER;
  l_chave VARCHAR2(50);
  l_ent  VARCHAR2(32767);
  l_atual VARCHAR2(32767);
  l_p    PLS_INTEGER;
BEGIN
  IF INSTRB(l_out, '<<') = 0 THEN
    l_out := '<< >>';
  END IF;

  -- p_novas e uma sequencia '/Chave << ... >> /Chave << ... >>'
  WHILE l_i <= l_n LOOP
    WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(p_novas, l_i, 1)) LOOP
      l_i := l_i + 1;
    END LOOP;
    EXIT WHEN l_i > l_n OR SUBSTRB(p_novas, l_i, 1) != '/';

    l_ini := l_i;
    l_i := l_i + 1;
    WHILE l_i <= l_n AND pdf_is_alnum(SUBSTRB(p_novas, l_i, 1)) LOOP
      l_i := l_i + 1;
    END LOOP;
    l_chave := SUBSTRB(p_novas, l_ini, l_i - l_ini);
    l_ent   := pdf_dict_value(SUBSTRB(p_novas, l_ini), l_chave);
    EXIT WHEN l_ent IS NULL;
    l_i := l_ini + INSTRB(SUBSTRB(p_novas, l_ini), l_ent) - 1 + LENGTHB(l_ent);

    -- so o miolo do sub-dicionario entra na mesclagem
    l_ent := TRIM(SUBSTRB(l_ent, 3, LENGTHB(l_ent) - 4));

    l_atual := pdf_dict_value(l_out, l_chave);
    IF l_atual IS NOT NULL AND SUBSTRB(l_atual, 1, 2) = '<<' THEN
      l_p := INSTRB(l_out, l_atual);
      l_out := SUBSTRB(l_out, 1, l_p + 1) || ' ' || l_ent || ' '
            || SUBSTRB(l_out, l_p + 2);
    ELSIF l_atual IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20846,
        'Nao e possivel sobrepor: ' || l_chave || ' do /Resources da pagina e '
        || 'uma referencia indireta compartilhada.');
    ELSE
      l_p := INSTRB(l_out, '<<');
      l_out := SUBSTRB(l_out, 1, l_p + 1) || ' ' || l_chave || ' << ' || l_ent
            || ' >> ' || SUBSTRB(l_out, l_p + 2);
    END IF;
  END LOOP;

  RETURN l_out;
END ovl_mesclar;

--------------------------------------------------------------------------------
-- pdf_assemble: monta um novo PDF com as paginas escolhidas de cada origem
--
-- Para cada origem: fecho transitivo das referencias a partir das paginas
-- (objetos nao alcancados ficam de fora), copia dos objetos com os ids
-- deslocados de um valor fixo, e por fim um Catalog (1) e um /Pages (2) novos.
--------------------------------------------------------------------------------
FUNCTION pdf_assemble(
  p_srcs IN OUT NOCOPY pdf_source_list,
  p_sel  IN OUT NOCOPY tpi2
) RETURN BLOB IS
  l_out      BLOB;
  l_kids     CLOB;
  l_offsets  tpi;
  l_needed   tbool;
  l_pageset  tbool;
  l_queue    tpi;
  l_refs     tpi;
  l_qn       PLS_INTEGER;
  l_next_id  PLS_INTEGER := 3;      -- 1 = Catalog, 2 = Pages
  l_shift    PLS_INTEGER;
  l_oid      PLS_INTEGER;
  l_new      PLS_INTEGER;
  l_start    PLS_INTEGER;
  l_end      PLS_INTEGER;
  l_dend     PLS_INTEGER;
  l_slen     PLS_INTEGER;
  l_body     VARCHAR2(32767);
  l_buf      VARCHAR2(32767);
  l_p        PLS_INTEGER;
  l_kidcount PLS_INTEGER := 0;
  l_size     PLS_INTEGER;
  l_xref_off PLS_INTEGER;
  -- sobreposicao (marca d'agua / overlay)
  l_extra    PLS_INTEGER;      -- proximo id livre depois de todas as origens
  l_mid      PLS_INTEGER;      -- id do /SMask da imagem corrente
  l_idic     VARCHAR2(32767);  -- dicionario da imagem, ja com o /SMask
  l_sid      PLS_INTEGER;      -- objeto do fluxo de desenho
  l_rid      PLS_INTEGER;      -- /Resources proprio da pagina
  l_pgraw    VARCHAR2(32767);
  l_ops      VARCHAR2(32767);
  l_resval   VARCHAR2(32767);
  l_resbody  VARCHAR2(32767);
  l_cont     VARCHAR2(32767);
  l_refs2    tpi;
  l_xobj     VARCHAR2(32767);   -- entradas /XObject das imagens desta pagina
  l_img_id   tpi;               -- i da imagem -> id do objeto
  l_img_n    PLS_INTEGER;
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_out, TRUE);
  DBMS_LOB.CREATETEMPORARY(l_kids, TRUE);

  -- Os objetos da sobreposicao entram DEPOIS dos ids de todas as origens, e as
  -- paginas precisam referencia-los enquanto ainda estao sendo escritas. Como o
  -- deslocamento de cada origem so depende do maior id dela, da para saber de
  -- antemao onde comeca a faixa livre.
  l_extra := 3;
  FOR s IN 1 .. p_srcs.COUNT LOOP
    l_extra := l_extra + NVL(p_srcs(s).xref.LAST, 0);
  END LOOP;

  pdf_app(l_out, '%PDF-1.7' || CHR(10));
  -- comentario com bytes altos: marca o arquivo como binario para os leitores
  DBMS_LOB.WRITEAPPEND(l_out, 6, HEXTORAW('25E2E3CFD30A'));

  FOR s IN 1 .. p_srcs.COUNT LOOP
    l_shift   := l_next_id - 1;
    l_next_id := l_next_id + NVL(p_srcs(s).xref.LAST, 0);

    l_needed.DELETE;
    l_pageset.DELETE;
    l_queue.DELETE;
    l_qn := 0;

    -- paginas escolhidas
    FOR i IN 1 .. p_sel(s).COUNT LOOP
      l_oid := p_srcs(s).pages(p_sel(s)(i));
      l_pageset(l_oid) := TRUE;
      IF NOT l_needed.EXISTS(l_oid) THEN
        l_needed(l_oid) := TRUE;
        l_qn := l_qn + 1;
        l_queue(l_qn) := l_oid;
      END IF;
    END LOOP;

    -- fecho transitivo das referencias (/Parent ja foi removido das paginas)
    WHILE l_qn > 0 LOOP
      l_oid := l_queue(l_qn);
      l_qn  := l_qn - 1;
      IF p_srcs(s).xref.EXISTS(l_oid) THEN
        IF l_pageset.EXISTS(l_oid) THEN
          l_body := pdf_page_body(p_srcs(s), l_oid);
        ELSE
          l_body := pdf_obj_body(p_srcs(s), l_oid);
        END IF;
        l_refs.DELETE;
        pdf_collect_refs(l_body, l_refs);
        FOR r IN 1 .. l_refs.COUNT LOOP
          IF NOT l_needed.EXISTS(l_refs(r)) AND p_srcs(s).xref.EXISTS(l_refs(r)) THEN
            l_needed(l_refs(r)) := TRUE;
            l_qn := l_qn + 1;
            l_queue(l_qn) := l_refs(r);
          END IF;
        END LOOP;
      END IF;
    END LOOP;

    -- copia dos objetos alcancados
    l_oid := l_needed.FIRST;
    WHILE l_oid IS NOT NULL LOOP
      pdf_obj_extent(p_srcs(s), l_oid, l_start, l_end, l_dend, l_slen);
      l_refs.DELETE;
      l_sid := NULL;         -- objetos extras deste objeto, se houver desenho
      IF l_pageset.EXISTS(l_oid) THEN
        l_pgraw := pdf_page_body(p_srcs(s), l_oid);
        l_body  := pdf_scan_refs(l_pgraw, l_shift, l_refs, FALSE);
        l_p := INSTRB(l_body, '<<');
        IF l_p = 0 THEN
          RAISE_APPLICATION_ERROR(-20844,
            'Objeto de pagina ' || l_oid || ' nao e um dicionario');
        END IF;
        l_body := SUBSTRB(l_body, 1, l_p + 1) || '/Parent 2 0 R '
               || SUBSTRB(l_body, l_p + 2);

        -- ── sobreposicao: desenho no fluxo de conteudo ──────────────────────
        l_sid := NULL;
        IF p_srcs(s).ovl_ops.EXISTS(l_oid)
           AND p_srcs(s).ovl_ops(l_oid) IS NOT NULL THEN
          l_ops := p_srcs(s).ovl_ops(l_oid);
          l_sid := l_extra;     l_extra := l_extra + 1;
          l_rid := l_extra;     l_extra := l_extra + 1;

          -- /Resources proprio da pagina. No PDF que o proprio PL_FPDF gera
          -- todas as paginas apontam para o MESMO objeto de recursos; mesclar
          -- ali espalharia a fonte da marca d'agua — ou um /XObject — por todo
          -- o documento.
          l_resval := pdf_dict_value(l_pgraw, '/Resources');
          IF l_resval IS NULL THEN
            l_resbody := '<< >>';
          ELSIF SUBSTRB(l_resval, 1, 2) = '<<' THEN
            l_resbody := l_resval;
          ELSE
            l_refs2.DELETE;
            pdf_collect_refs(l_resval, l_refs2);
            IF l_refs2.COUNT = 0 OR NOT p_srcs(s).xref.EXISTS(l_refs2(1)) THEN
              RAISE_APPLICATION_ERROR(-20846,
                'Pagina ' || l_oid || ': /Resources aponta para um objeto '
                || 'inexistente; nao da para sobrepor.');
            END IF;
            l_resbody := pdf_obj_body(p_srcs(s), l_refs2(1));
            -- pdf_obj_body devolve o objeto ATE o 'endobj' — o extent vai ate
            -- depois dele —, e quem emite este objeto acrescenta outro. O
            -- resultado era 'endobjendobj', que nao invalida o arquivo e nao
            -- muda o desenho: o MuPDF abre, so avisa. Um leitor mais rigido
            -- pode recusar, e nenhuma checagem pegava porque a pagina continua
            -- correta. Apareceu ao conferir os avisos do MuPDF nas amostras.
            l_resbody := REGEXP_REPLACE(l_resbody, 'endobj\s*$', '');
          END IF;
          -- imagens desta pagina: cada uma vira um /XObject proprio, com id
          -- reservado na mesma faixa livre
          l_xobj := NULL;
          l_img_id.DELETE;
          l_img_n := p_srcs(s).ovl_img_pag.FIRST;
          WHILE l_img_n IS NOT NULL LOOP
            IF p_srcs(s).ovl_img_pag(l_img_n) = l_oid THEN
              l_img_id(l_img_n) := l_extra;
              l_extra := l_extra + 1;
              l_xobj := l_xobj || ' /ImgPLFPDF' || l_img_n || ' '
                     || l_img_id(l_img_n) || ' 0 R';
            END IF;
            l_img_n := p_srcs(s).ovl_img_pag.NEXT(l_img_n);
          END LOOP;

          -- as referencias de dentro dos recursos (fontes, imagens) precisam do
          -- mesmo deslocamento; as entradas novas entram DEPOIS, senao o id do
          -- proprio objeto seria deslocado junto
          l_refs2.DELETE;
          l_resbody := ovl_mesclar(
                         pdf_scan_refs(l_resbody, l_shift, l_refs2, FALSE),
                         p_srcs(s).ovl_res(l_oid)
                         || CASE WHEN l_xobj IS NOT NULL
                                 THEN ' /XObject <<' || l_xobj || ' >>' END);

          l_body := pdf_strip_key(l_body, '/Resources');
          l_p := INSTRB(l_body, '<<');
          l_body := SUBSTRB(l_body, 1, l_p + 1) || '/Resources ' || l_rid
                 || ' 0 R ' || SUBSTRB(l_body, l_p + 2);

          -- /Contents vira array, com o desenho por ultimo: fica por cima
          l_cont := pdf_dict_value(l_body, '/Contents');
          IF l_cont IS NULL THEN
            RAISE_APPLICATION_ERROR(-20846,
              'Pagina ' || l_oid || ' nao tem /Contents; nao da para sobrepor.');
          END IF;
          IF SUBSTRB(l_cont, 1, 1) = '[' THEN
            l_cont := SUBSTRB(l_cont, 1, LENGTHB(l_cont) - 1)
                   || ' ' || l_sid || ' 0 R]';
          ELSE
            l_cont := '[' || l_cont || ' ' || l_sid || ' 0 R]';
          END IF;
          l_body := pdf_strip_key(l_body, '/Contents');
          l_p := INSTRB(l_body, '<<');
          l_body := SUBSTRB(l_body, 1, l_p + 1) || '/Contents ' || l_cont || ' '
                 || SUBSTRB(l_body, l_p + 2);
        END IF;
      ELSE
        l_body := pdf_scan_refs(pdf_obj_body(p_srcs(s), l_oid),
                                l_shift, l_refs, FALSE);
      END IF;

      l_new := l_oid + l_shift;
      l_offsets(l_new) := DBMS_LOB.GETLENGTH(l_out);
      pdf_app(l_out, l_new || ' 0 obj');
      pdf_app(l_out, l_body);
      IF l_end > l_dend THEN
        -- payload do stream + 'endstream endobj', copiados byte a byte
        DBMS_LOB.COPY(l_out, p_srcs(s).doc, l_end - l_dend,
                      DBMS_LOB.GETLENGTH(l_out) + 1, l_dend + 1);
      END IF;
      pdf_app(l_out, CHR(10));

      -- os dois objetos da sobreposicao, logo apos a pagina que os usa
      IF l_sid IS NOT NULL THEN
        l_offsets(l_sid) := DBMS_LOB.GETLENGTH(l_out);
        pdf_app(l_out, l_sid || ' 0 obj<< /Length ' || LENGTHB(l_ops)
                    || ' >>stream' || CHR(10) || l_ops || CHR(10)
                    || 'endstream endobj' || CHR(10));
        l_offsets(l_rid) := DBMS_LOB.GETLENGTH(l_out);
        pdf_app(l_out, l_rid || ' 0 obj' || l_resbody || 'endobj' || CHR(10));

        -- as imagens, byte a byte: o payload e binario e nao pode passar por
        -- VARCHAR2 em momento nenhum
        l_img_n := l_img_id.FIRST;
        WHILE l_img_n IS NOT NULL LOOP
          -- O /SMask e um objeto de imagem SEPARADO, com id proprio, e o
          -- dicionario da imagem passa a apontar para ele. Emitido antes, para
          -- que o id ja exista quando a imagem o citar.
          l_mid  := NULL;
          l_idic := p_srcs(s).ovl_img_dic(l_img_n);
          IF p_srcs(s).ovl_msk_dic.EXISTS(l_img_n) THEN
            l_mid := l_extra;  l_extra := l_extra + 1;
            l_offsets(l_mid) := DBMS_LOB.GETLENGTH(l_out);
            pdf_app(l_out, l_mid || ' 0 obj'
                        || p_srcs(s).ovl_msk_dic(l_img_n) || 'stream' || CHR(10));
            DBMS_LOB.COPY(l_out, p_srcs(s).ovl_msk_dat(l_img_n),
                          DBMS_LOB.GETLENGTH(p_srcs(s).ovl_msk_dat(l_img_n)),
                          DBMS_LOB.GETLENGTH(l_out) + 1, 1);
            pdf_app(l_out, CHR(10) || 'endstream endobj' || CHR(10));
            l_idic := RTRIM(l_idic);
            l_idic := SUBSTRB(l_idic, 1, LENGTHB(l_idic) - 2)
                   || ' /SMask ' || l_mid || ' 0 R >>';
          END IF;

          l_offsets(l_img_id(l_img_n)) := DBMS_LOB.GETLENGTH(l_out);
          pdf_app(l_out, l_img_id(l_img_n) || ' 0 obj'
                      || l_idic || 'stream' || CHR(10));
          DBMS_LOB.COPY(l_out, p_srcs(s).ovl_img_dat(l_img_n),
                        DBMS_LOB.GETLENGTH(p_srcs(s).ovl_img_dat(l_img_n)),
                        DBMS_LOB.GETLENGTH(l_out) + 1, 1);
          pdf_app(l_out, CHR(10) || 'endstream endobj' || CHR(10));
          l_img_n := l_img_id.NEXT(l_img_n);
        END LOOP;
      END IF;
      l_oid := l_needed.NEXT(l_oid);
    END LOOP;

    -- /Kids na ordem pedida (uma pagina pode repetir)
    FOR i IN 1 .. p_sel(s).COUNT LOOP
      l_kidcount := l_kidcount + 1;
      IF l_kidcount > 1 THEN
        l_buf := ' ';
      ELSE
        l_buf := NULL;
      END IF;
      l_buf := l_buf || (p_srcs(s).pages(p_sel(s)(i)) + l_shift) || ' 0 R';
      DBMS_LOB.WRITEAPPEND(l_kids, LENGTH(l_buf), l_buf);
    END LOOP;
  END LOOP;

  -- Catalog e no /Pages novos
  l_offsets(1) := DBMS_LOB.GETLENGTH(l_out);
  pdf_app(l_out, '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' || CHR(10));
  l_offsets(2) := DBMS_LOB.GETLENGTH(l_out);
  pdf_app(l_out, '2 0 obj<</Type/Pages/Count ' || l_kidcount || '/Kids[');
  pdf_app_clob(l_out, l_kids);
  pdf_app(l_out, ']>>endobj' || CHR(10));

  -- xref: entradas livres para os ids que nao foram copiados
  l_size     := l_offsets.LAST + 1;
  l_xref_off := DBMS_LOB.GETLENGTH(l_out);
  pdf_app(l_out, 'xref' || CHR(10) || '0 ' || l_size || CHR(10)
               || '0000000000 65535 f ' || CHR(10));
  l_buf := NULL;
  FOR i IN 1 .. l_size - 1 LOOP
    IF l_offsets.EXISTS(i) THEN
      l_buf := l_buf || LPAD(l_offsets(i), 10, '0') || ' 00000 n ' || CHR(10);
    ELSE
      l_buf := l_buf || '0000000000 65535 f ' || CHR(10);
    END IF;
    IF LENGTHB(l_buf) > co_pdf_dict_limit THEN
      pdf_app(l_out, l_buf);
      l_buf := NULL;
    END IF;
  END LOOP;
  pdf_app(l_out, l_buf);

  pdf_app(l_out, 'trailer<</Size ' || l_size || '/Root 1 0 R>>' || CHR(10)
               || 'startxref' || CHR(10) || l_xref_off || CHR(10)
               || '%%EOF' || CHR(10));

  DBMS_LOB.FREETEMPORARY(l_kids);
  RETURN l_out;
EXCEPTION
  WHEN OTHERS THEN
    IF l_kids IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_kids) = 1 THEN
      DBMS_LOB.FREETEMPORARY(l_kids);
    END IF;
    IF l_out IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_out) = 1 THEN
      DBMS_LOB.FREETEMPORARY(l_out);
    END IF;
    RAISE;
END pdf_assemble;

--------------------------------------------------------------------------------
-- blob_to_base64: base64 de um BLOB de qualquer tamanho
--   (UTL_ENCODE.BASE64_ENCODE trabalha com RAW; o corte tem de ser multiplo de 3)
--------------------------------------------------------------------------------
FUNCTION blob_to_base64(p_blob IN BLOB) RETURN CLOB IS
  co_chunk CONSTANT PLS_INTEGER := 22500;   -- multiplo de 3, RAW cabe em 32767
  l_out CLOB;
  l_len PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_blob), 0);
  l_pos PLS_INTEGER := 1;
  l_amt PLS_INTEGER;
  l_txt VARCHAR2(32767);
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_out, TRUE);
  WHILE l_pos <= l_len LOOP
    l_amt := LEAST(co_chunk, l_len - l_pos + 1);
    l_txt := UTL_RAW.CAST_TO_VARCHAR2(
               UTL_ENCODE.BASE64_ENCODE(DBMS_LOB.SUBSTR(p_blob, l_amt, l_pos)));
    -- BASE64_ENCODE quebra a saida em linhas de 64; o PDF em base64 nao precisa
    l_txt := REPLACE(REPLACE(l_txt, CHR(13)), CHR(10));
    DBMS_LOB.WRITEAPPEND(l_out, LENGTH(l_txt), l_txt);
    l_pos := l_pos + l_amt;
  END LOOP;
  RETURN l_out;
END blob_to_base64;

/*******************************************************************************
* MergePDFs: junta os PDFs carregados, na ordem dada, num unico documento
*
* Copia de verdade os objetos de cada origem (paginas, fontes, imagens,
* anotacoes), renumerando as referencias indiretas, e monta uma nova arvore
* de paginas. Nada e re-renderizado: o conteudo original chega intacto.
*******************************************************************************/
FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB IS
  l_srcs   pdf_source_list;
  l_sel    tpi2;
  l_pdf_id VARCHAR2(50);
  l_pages  PLS_INTEGER := 0;
  l_result BLOB;
BEGIN
  IF p_pdf_ids IS NULL OR p_pdf_ids.get_size() = 0 THEN
    RAISE_APPLICATION_ERROR(-20832, 'No PDF IDs provided for merge');
  END IF;

  FOR i IN 0 .. p_pdf_ids.get_size() - 1 LOOP
    l_pdf_id := p_pdf_ids.get_string(i);
    IF l_pdf_id IS NULL OR NOT g_loaded_pdfs.EXISTS(l_pdf_id) THEN
      RAISE_APPLICATION_ERROR(-20833, 'PDF ID not loaded: ' || l_pdf_id);
    END IF;
    l_srcs(i + 1) := pdf_src_load(g_loaded_pdfs(l_pdf_id).pdf_blob);
    l_sel(i + 1)  := pdf_parse_pages('ALL', l_srcs(i + 1).pages.COUNT);
    l_pages := l_pages + l_srcs(i + 1).pages.COUNT;
  END LOOP;

  log_message(2, 'Merging ' || p_pdf_ids.get_size() || ' PDFs (' ||
              l_pages || ' pages total)...');

  l_result := pdf_assemble(l_srcs, l_sel);

  log_message(2, 'Merged PDF: ' || DBMS_LOB.GETLENGTH(l_result) || ' bytes');
  RETURN l_result;
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      log_message(1, 'Merge error: ' || SQLERRM);
      RAISE_APPLICATION_ERROR(-20834, 'Merge failed: ' || SQLERRM);
    END IF;
END MergePDFs;

/*******************************************************************************
* SplitPDF: divide o PDF carregado nos intervalos pedidos
*
* Devolve um array JSON com cada parte em base64. O PDF de origem e indexado
* uma unica vez; cada parte leva so os objetos alcancaveis a partir das suas
* paginas.
*******************************************************************************/
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_srcs   pdf_source_list;
  l_sel    tpi2;
  l_src    pdf_source_rec;
  l_range  VARCHAR2(200);
  l_part   BLOB;
  l_b64    CLOB;
  l_used   tbool;
BEGIN
  IF NOT g_loaded_pdfs.EXISTS(p_pdf_id) THEN
    RAISE_APPLICATION_ERROR(-20831, 'PDF ID not found: ' || p_pdf_id);
  END IF;
  IF p_page_ranges IS NULL OR p_page_ranges.get_size() = 0 THEN
    RAISE_APPLICATION_ERROR(-20835, 'No page ranges provided');
  END IF;

  log_message(2, 'Splitting PDF ' || p_pdf_id || '...');
  l_src := pdf_src_load(g_loaded_pdfs(p_pdf_id).pdf_blob);

  FOR i IN 0 .. p_page_ranges.get_size() - 1 LOOP
    l_range := p_page_ranges.get_string(i);
    l_srcs.DELETE;
    l_sel.DELETE;
    l_srcs(1) := l_src;
    l_sel(1)  := pdf_parse_pages(l_range, l_src.pages.COUNT);

    -- intervalos sobrepostos entre as partes indicam engano do chamador
    FOR k IN 1 .. l_sel(1).COUNT LOOP
      IF l_used.EXISTS(l_sel(1)(k)) THEN
        RAISE_APPLICATION_ERROR(-20836,
          'Intervalos sobrepostos: a pagina ' || l_sel(1)(k) ||
          ' aparece em mais de uma parte');
      END IF;
      l_used(l_sel(1)(k)) := TRUE;
    END LOOP;

    l_part := pdf_assemble(l_srcs, l_sel);
    l_b64  := blob_to_base64(l_part);
    l_result.append(l_b64);

    log_message(3, 'Split part ' || (i + 1) || ': ' || l_range || ' (' ||
                DBMS_LOB.GETLENGTH(l_part) || ' bytes)');
    DBMS_LOB.FREETEMPORARY(l_part);
    -- blob_to_base64 devolve CLOB temporario, e o append ja copiou o valor
    -- para o JSON. Sem isto vaza um LOB de duracao de SESSAO por intervalo:
    -- reatribuir l_b64 na volta do laco nao libera o anterior.
    IF l_b64 IS NOT NULL THEN
      DBMS_LOB.FREETEMPORARY(l_b64);
    END IF;
  END LOOP;

  RETURN l_result;
END SplitPDF;

/*******************************************************************************
* ExtractPages: cria um novo PDF com as paginas escolhidas
*
* p_pages aceita '1', '1,3,5-7', '5,1' (a ordem pedida e respeitada) ou 'ALL'.
*******************************************************************************/
FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB IS
  l_srcs   pdf_source_list;
  l_sel    tpi2;
  l_result BLOB;
BEGIN
  IF NOT g_loaded_pdfs.EXISTS(p_pdf_id) THEN
    RAISE_APPLICATION_ERROR(-20831, 'PDF ID not found: ' || p_pdf_id);
  END IF;
  IF p_pages IS NULL OR LENGTH(TRIM(p_pages)) = 0 THEN
    RAISE_APPLICATION_ERROR(-20838, 'Invalid page specification');
  END IF;

  log_message(2, 'Extracting pages ' || p_pages || ' from ' || p_pdf_id);

  l_srcs(1) := pdf_src_load(g_loaded_pdfs(p_pdf_id).pdf_blob);
  l_sel(1)  := pdf_parse_pages(p_pages, l_srcs(1).pages.COUNT);
  l_result  := pdf_assemble(l_srcs, l_sel);

  log_message(3, 'Extracted ' || l_sel(1).COUNT || ' page(s), ' ||
              DBMS_LOB.GETLENGTH(l_result) || ' bytes');
  RETURN l_result;
END ExtractPages;

--------------------------------------------------------------------------------
-- PHASE 5: SECURITY / SEGURANÇA (v3.3.0)
--------------------------------------------------------------------------------

/*******************************************************************************
* PL_FPDF_UTIL.crypto_md5 / PL_FPDF_UTIL.crypto_rc4: MD5 e RC4 sem depender de DBMS_CRYPTO
*
* PT: O PDF com revisao 2/3 usa MD5 e RC4 (ambos obsoletos como seguranca, mas
*     e o que a especificacao manda para esse nivel — nao e escolha daqui).
*
*     MD5 sai de STANDARD_HASH, funcao SQL nativa desde o 12c: nao precisa de
*     GRANT nenhum. RC4 sao poucas linhas e esta implementado abaixo.
*
*     Antes isto dependia de EXECUTE em SYS.DBMS_CRYPTO, o que na pratica levava
*     quem nao tinha o privilegio a criar um substituto no proprio schema — e um
*     substituto que "cifra" com XOR simples, ou que devolve a entrada, faz o PDF
*     sair marcado como protegido com o /O em TEXTO CLARO e QUALQUER senha ser
*     aceita, sem erro nenhum. Sem dependencia externa esse risco desaparece.
* EN: MD5 comes from STANDARD_HASH (native SQL function, no grant required) and
*     RC4 is implemented here, so PDF encryption no longer depends on
*     DBMS_CRYPTO — and cannot silently degrade to a stub that does not encrypt.
*******************************************************************************/
FUNCTION rc4_crypt(p_data RAW, p_key RAW) RETURN RAW IS
BEGIN
  RETURN PL_FPDF_UTIL.crypto_rc4(p_data, p_key);
END rc4_crypt;
FUNCTION pdf_pad_password(p_pwd VARCHAR2) RETURN RAW IS
  l_raw RAW(32);
  l_len PLS_INTEGER;
BEGIN
  l_raw := UTL_RAW.CAST_TO_RAW(SUBSTR(NVL(p_pwd, ''), 1, 32));
  l_len := NVL(UTL_RAW.LENGTH(l_raw), 0);
  IF l_len >= 32 THEN
    RETURN UTL_RAW.SUBSTR(l_raw, 1, 32);
  ELSIF l_len = 0 THEN
    RETURN c_PDF_PADDING;
  END IF;
  RETURN UTL_RAW.CONCAT(l_raw, UTL_RAW.SUBSTR(c_PDF_PADDING, 1, 32 - l_len));
END pdf_pad_password;

/*******************************************************************************
* PL_FPDF_UTIL.crypto_autoteste: confere MD5 e RC4 contra vetores publicos conhecidos
*
* Barato (roda uma vez por sessao) e evita a pior falha possivel aqui: gerar um
* PDF marcado como protegido cuja cifragem nao cifra nada. Com um RC4 que fosse
* identidade, o /O sairia em texto claro e QUALQUER senha seria aceita, sem erro
* nenhum.
*
* Vetores: MD5('abc') e o RC4 de 'Plaintext' com a chave 'Key'.
*******************************************************************************/
FUNCTION rc4_key_xor(p_key RAW, p_i PLS_INTEGER) RETURN RAW IS
  l_out RAW(32);
  l_idx RAW(1);
  l_b   RAW(1);
BEGIN
  l_idx := UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(p_i), 4, 1);
  FOR j IN 1 .. UTL_RAW.LENGTH(p_key) LOOP
    l_b := UTL_RAW.BIT_XOR(UTL_RAW.SUBSTR(p_key, j, 1), l_idx);
    IF l_out IS NULL THEN
      l_out := l_b;
    ELSE
      l_out := UTL_RAW.CONCAT(l_out, l_b);
    END IF;
  END LOOP;
  RETURN l_out;
END rc4_key_xor;

/*******************************************************************************
* compute_object_key: Compute encryption key for specific object (Algorithm 1)
*******************************************************************************/
FUNCTION compute_object_key(
  p_enc_key RAW,
  p_obj_num PLS_INTEGER,
  p_gen_num PLS_INTEGER DEFAULT 0,
  p_key_length PLS_INTEGER DEFAULT 128
) RETURN RAW IS
  l_input RAW(100);
  l_hash RAW(16);
  l_key_len PLS_INTEGER;
BEGIN
  -- obj_key = MD5(encryption_key + obj_num(3 bytes LE) + gen_num(2 bytes LE))
  l_input := UTL_RAW.CONCAT(
    p_enc_key,
    UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(p_obj_num, UTL_RAW.LITTLE_ENDIAN), 1, 3),
    UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(p_gen_num, UTL_RAW.LITTLE_ENDIAN), 1, 2)
  );

  l_hash := PL_FPDF_UTIL.crypto_md5(l_input);

  -- Key length is min(n+5, 16) bytes
  l_key_len := LEAST((p_key_length / 8) + 5, 16);

  RETURN UTL_RAW.SUBSTR(l_hash, 1, l_key_len);
END compute_object_key;

/*******************************************************************************
* compute_owner_key: Compute owner password hash (Algorithm 3 from PDF spec)
*******************************************************************************/
FUNCTION compute_owner_key(
  p_owner_pwd VARCHAR2,
  p_user_pwd VARCHAR2,
  p_key_length PLS_INTEGER
) RETURN RAW IS
  l_pwd_to_use VARCHAR2(100);
  l_padded RAW(32);
  l_hash RAW(32);
  l_key_len PLS_INTEGER;
BEGIN
  -- Use owner password or user password if owner is empty
  l_pwd_to_use := NVL(p_owner_pwd, p_user_pwd);

  -- Pad password to 32 bytes (senha + inicio da string de preenchimento)
  l_padded := pdf_pad_password(l_pwd_to_use);

  -- MD5 hash
  l_hash := PL_FPDF_UTIL.crypto_md5(l_padded);

  -- For 128-bit, hash 50 more times
  IF p_key_length > 40 THEN
    FOR i IN 1..50 LOOP
      l_hash := PL_FPDF_UTIL.crypto_md5(l_hash);
    END LOOP;
  END IF;

  -- Return first n bytes as key
  l_key_len := p_key_length / 8;
  RETURN UTL_RAW.SUBSTR(l_hash, 1, l_key_len);
END compute_owner_key;

/*******************************************************************************
* compute_owner_value: Compute /O value (Algorithm 3 from PDF spec)
*******************************************************************************/
FUNCTION compute_owner_value(
  p_owner_pwd VARCHAR2,
  p_user_pwd VARCHAR2,
  p_key_length PLS_INTEGER
) RETURN RAW IS
  l_key RAW(16);
  l_user_padded RAW(32);
  l_result RAW(32);
BEGIN
  -- Get owner key
  l_key := compute_owner_key(p_owner_pwd, p_user_pwd, p_key_length);

  -- Pad user password (senha + inicio da string de preenchimento)
  l_user_padded := pdf_pad_password(p_user_pwd);

  -- RC4 encrypt
  l_result := PL_FPDF_UTIL.crypto_rc4(l_user_padded, l_key);

  -- Algoritmo 3, passo f: para revisao 3+ sao mais 19 rodadas com K XOR i.
  -- Sem isto a cifragem fazia UMA rodada e verify_password desfazia VINTE:
  -- a senha de proprietario nunca conferia ('Invalid password'), e o /O gerado
  -- nao era aceito por leitores que seguem a especificacao.
  IF p_key_length > 40 THEN
    FOR i IN 1 .. 19 LOOP
      l_result := PL_FPDF_UTIL.crypto_rc4(l_result, rc4_key_xor(l_key, i));
    END LOOP;
  END IF;

  RETURN l_result;
END compute_owner_value;

/*******************************************************************************
* compute_encryption_key: Compute document encryption key (Algorithm 2)
*******************************************************************************/
--------------------------------------------------------------------------------
-- compute_encryption_key_raw: algoritmo 2 a partir da senha JA preenchida (RAW)
--
-- Existe porque verify_password, no caminho da senha de proprietario, obtem a
-- senha de usuario decifrando /O: sao 32 bytes quaisquer, nao um texto. Passa-
-- los por VARCHAR2 para o RPAD/SUBSTR corrompia o preenchimento — os dois
-- contam CARACTERES, e bytes arbitrarios em charset multibyte nao sao 32
-- caracteres de 1 byte. A chave saia errada e a senha nunca conferia.
--------------------------------------------------------------------------------
FUNCTION compute_encryption_key_raw(
  p_user_padded RAW,
  p_o_value RAW,
  p_permissions PLS_INTEGER,
  p_file_id RAW,
  p_key_length PLS_INTEGER
) RETURN RAW IS
  l_input RAW(2000);
  l_user_padded RAW(32) := p_user_padded;
  l_perm_bytes RAW(4);
  l_hash RAW(16);
  l_key_len PLS_INTEGER;
BEGIN
  -- Convert permissions to little-endian bytes
  l_perm_bytes := UTL_RAW.CAST_FROM_BINARY_INTEGER(p_permissions, UTL_RAW.LITTLE_ENDIAN);

  -- Concatenate: padded password + O value + permissions + file ID
  l_input := UTL_RAW.CONCAT(l_user_padded, p_o_value);
  l_input := UTL_RAW.CONCAT(l_input, l_perm_bytes);
  l_input := UTL_RAW.CONCAT(l_input, p_file_id);

  -- MD5 hash
  l_hash := PL_FPDF_UTIL.crypto_md5(l_input);

  -- For 128-bit, hash 50 more times
  IF p_key_length > 40 THEN
    l_key_len := p_key_length / 8;
    FOR i IN 1..50 LOOP
      l_hash := PL_FPDF_UTIL.crypto_md5(UTL_RAW.SUBSTR(l_hash, 1, l_key_len));
    END LOOP;
  END IF;

  -- Return first n bytes
  l_key_len := p_key_length / 8;
  RETURN UTL_RAW.SUBSTR(l_hash, 1, l_key_len);
END compute_encryption_key_raw;

/*******************************************************************************
* compute_encryption_key: Compute document encryption key (Algorithm 2)
*   Recebe a senha como texto, preenche ate 32 bytes e delega.
*******************************************************************************/
FUNCTION compute_encryption_key(
  p_user_pwd VARCHAR2,
  p_o_value RAW,
  p_permissions PLS_INTEGER,
  p_file_id RAW,
  p_key_length PLS_INTEGER
) RETURN RAW IS
BEGIN
  RETURN compute_encryption_key_raw(pdf_pad_password(p_user_pwd),
           p_o_value, p_permissions, p_file_id, p_key_length);
END compute_encryption_key;

/*******************************************************************************
* compute_user_value: Compute /U value (Algorithm 4/5 from PDF spec)
*******************************************************************************/
FUNCTION compute_user_value(
  p_encryption_key RAW,
  p_file_id RAW,
  p_key_length PLS_INTEGER
) RETURN RAW IS
  l_result RAW(32);
  l_hash RAW(16);
BEGIN
  IF p_key_length <= 40 THEN
    -- Algorithm 4: RC4 encrypt padding
    l_result := PL_FPDF_UTIL.crypto_rc4(c_PDF_PADDING, p_encryption_key);
  ELSE
    -- Algorithm 5: MD5 hash of padding + file ID
    l_hash := PL_FPDF_UTIL.crypto_md5(UTL_RAW.CONCAT(c_PDF_PADDING, p_file_id));

    -- RC4 encrypt
    l_result := PL_FPDF_UTIL.crypto_rc4(l_hash, p_encryption_key);

    -- Algoritmo 5, passo (e): mais 19 rodadas com a chave sofrendo XOR pelo
    -- numero da rodada. Sem isto o /U nao bate com o que qualquer leitor
    -- conforme calcula, e o PDF cifrado nao abre em lugar nenhum.
    FOR i IN 1 .. 19 LOOP
      l_result := PL_FPDF_UTIL.crypto_rc4(l_result, rc4_key_xor(p_encryption_key, i));
    END LOOP;

    -- Pad to 32 bytes
    l_result := UTL_RAW.CONCAT(l_result, HEXTORAW('00000000000000000000000000000000'));
    l_result := UTL_RAW.SUBSTR(l_result, 1, 32);
  END IF;

  RETURN l_result;
END compute_user_value;

/*******************************************************************************
* generate_file_id: Generate unique file ID
*******************************************************************************/
FUNCTION generate_file_id RETURN RAW IS
BEGIN
  RETURN PL_FPDF_UTIL.crypto_md5(
    UTL_RAW.CAST_TO_RAW(
      TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF9') || SYS_GUID()
    )
  );
END generate_file_id;

--------------------------------------------------------------------------------
-- sec_cifrar_strings: cifra as strings literais (entre parenteses) de um dicionario
--
-- Cada string do PDF e cifrada com a chave do objeto, como os streams. O
-- escape tem de ser refeito depois: bytes ( ) \ e as quebras de linha nao
-- podem sair crus dentro de uma string literal.
--
-- TUDO EM RAW, de proposito. A versao anterior percorria o dicionario com
-- SUBSTRB(p_dic, k, 1) e remontava o conteudo da string byte a byte num
-- VARCHAR2. Num banco AL32UTF8 isso nao e seguro: extrair UM byte do meio de
-- um caractere multibyte nao devolve aquele byte, e a cifra produz metade dos
-- bytes acima de 127. Os bytes ASCII atravessavam intactos e os altos voltavam
-- alterados.
--
-- O sintoma era caracteristico e demorou a ser lido: como o RC4 e cifra de
-- FLUXO, corromper o byte i da cifra corrompe so o byte i do texto — o titulo
-- voltava com a maioria das letras certas e algumas trocadas, em vez de virar
-- lixo inteiro. Com AES o mesmo estrago aparecia como preenchimento invalido.
--
-- RAW nao tem charset. UTL_RAW.CAST_TO_RAW e UTL_RAW.CAST_TO_VARCHAR2 sao
-- inversas exatas e nao convertem nada — sao as mesmas que pdf_read e pdf_app
-- usam para atravessar o arquivo byte a byte.
--------------------------------------------------------------------------------
FUNCTION sec_cifrar_strings(
  p_dic      IN VARCHAR2,
  p_ok       IN RAW,
  p_aes      IN BOOLEAN DEFAULT FALSE,
  p_decifrar IN BOOLEAN DEFAULT FALSE
) RETURN VARCHAR2 IS
  co_abre  CONSTANT PLS_INTEGER := 40;    -- (
  co_fecha CONSTANT PLS_INTEGER := 41;    -- )
  co_barra CONSTANT PLS_INTEGER := 92;    -- \

  -- Sem inicializador: a guarda de tamanho tem de rodar ANTES do
  -- CAST_TO_RAW, e RAISE_APPLICATION_ERROR e PROCEDURE — nao cabe numa
  -- expressao de declaracao. Ver o bloco no inicio do BEGIN.
  l_raw   RAW(32767);
  l_n     PLS_INTEGER;
  l_out   RAW(32767);
  l_i     PLS_INTEGER := 1;
  l_ini   PLS_INTEGER;
  l_j     PLS_INTEGER;
  l_prof  PLS_INTEGER;
  l_texto RAW(32767);
  l_cif   RAW(32767);
  l_hex   VARCHAR2(32767);
  l_b     PLS_INTEGER;

  -- valor do byte na posicao p (base 1)
  FUNCTION b_em(p IN PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN
    RETURN TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_raw, p, 1)), 'XX');
  END b_em;

  -- A saida nao cabe sempre que a entrada coube.
  --
  -- p_dic vem do pdf_read, que ja para em 32767, entao l_raw NUNCA estoura na
  -- entrada. O que cresce e a SAIDA: cada string cifrada vira hexadecimal, e o
  -- AES ainda soma 16 bytes de IV mais o preenchimento. Um dicionario com
  -- muitas strings longas passa dos 32767 aqui, no CONCAT.
  --
  -- Nao da para prever isso pelo tamanho da ENTRADA — a primeira tentativa de
  -- guarda recusava tudo acima de 16000 bytes e derrubou 27 verificacoes de
  -- cifragem que passavam, com dicionarios de 32092 bytes e strings curtas.
  -- O teste tem de ficar onde o estouro acontece.
  PROCEDURE juntar(p_pedaco IN RAW) IS
  BEGIN
    IF NVL(UTL_RAW.LENGTH(p_pedaco), 0) > 0 THEN
      IF NVL(UTL_RAW.LENGTH(l_out), 0)
         + UTL_RAW.LENGTH(p_pedaco) > 32767 THEN
        RAISE_APPLICATION_ERROR(-20841,
          'A cifragem das strings deste objeto passa de 32767 bytes: o texto '
          || 'cifrado vira hexadecimal e o AES soma IV e preenchimento. '
          || 'Dicionario de entrada: ' || l_n || ' bytes. Este PDF nao pode '
          || 'ser cifrado sem truncar o objeto.');
      END IF;
      l_out := CASE WHEN l_out IS NULL THEN p_pedaco
                    ELSE UTL_RAW.CONCAT(l_out, p_pedaco) END;
    END IF;
  END juntar;
BEGIN
  l_raw := UTL_RAW.CAST_TO_RAW(p_dic);
  l_n   := NVL(UTL_RAW.LENGTH(l_raw), 0);

  WHILE l_i <= l_n LOOP
    IF b_em(l_i) != co_abre THEN
      -- trecho fora de string: copia ate o proximo '(' de uma vez so
      l_j := l_i;
      WHILE l_j <= l_n AND b_em(l_j) != co_abre LOOP
        l_j := l_j + 1;
      END LOOP;
      juntar(UTL_RAW.SUBSTR(l_raw, l_i, l_j - l_i));
      l_i := l_j;
      CONTINUE;
    END IF;

    -- le ate o ')' correspondente, respeitando escape e aninhamento
    l_ini  := l_i + 1;
    l_prof := 1;
    l_j    := l_ini;
    WHILE l_j <= l_n AND l_prof > 0 LOOP
      l_b := b_em(l_j);
      IF l_b = co_barra THEN
        l_j := l_j + 1;                          -- pula o caractere escapado
      ELSIF l_b = co_abre THEN
        l_prof := l_prof + 1;
      ELSIF l_b = co_fecha THEN
        l_prof := l_prof - 1;
        EXIT WHEN l_prof = 0;
      END IF;
      l_j := l_j + 1;
    END LOOP;

    -- Sem ')' correspondente, este '(' NAO abre string.
    --
    -- Era o defeito: a varredura acima ia ate o fim do dicionario, e o resto
    -- inteiro virava "uma string". O l_hex abaixo guarda DOIS caracteres por
    -- byte, entao qualquer pseudo-string acima de ~16 KB estourava o
    -- VARCHAR2(32767) — ORA-06502, que o EncryptPDF rebatizava como
    -- '-20852 Encryption failed'. Um parenteses solto em dado binario lido
    -- como ASCII basta para disparar, e era o que derrubava a cifragem das
    -- amostras.
    --
    -- Um leitor de PDF tolerante trata esse '(' como byte comum e segue. E o
    -- que se faz aqui: emite o byte e avanca um, sem consumir o resto.
    IF l_prof > 0 THEN
      juntar(UTL_RAW.SUBSTR(l_raw, l_i, 1));
      l_i := l_i + 1;
      CONTINUE;
    END IF;

    -- desfaz o escape do conteudo original
    l_hex := NULL;
    DECLARE
      l_k PLS_INTEGER := l_ini;
    BEGIN
      -- l_k <= l_n tambem: uma barra invertida solta no fim empurraria l_j
      -- para alem do ultimo byte, e UTL_RAW.SUBSTR fora da faixa levanta
      WHILE l_k < l_j AND l_k <= l_n LOOP
        l_b := b_em(l_k);
        IF l_b = co_barra AND l_k + 1 < l_j THEN
          l_b := b_em(l_k + 1);
          l_hex := l_hex || CASE l_b
                              WHEN 110 THEN '0A'   -- \n
                              WHEN 114 THEN '0D'   -- \r
                              WHEN 116 THEN '09'   -- \t
                              ELSE LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0') END;
          l_k := l_k + 2;
        ELSE
          l_hex := l_hex || LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0');
          l_k := l_k + 1;
        END IF;
        -- Simetrica ao teto de 16000 que ja existia na SAIDA: aqui o l_hex
        -- guarda dois caracteres por byte, entao 16000 bytes de string ja
        -- ocupam 32000 dos 32767. Sem isto o estouro chega como ORA-06502 sem
        -- dizer de onde.
        IF LENGTH(l_hex) > 32000 THEN
          RAISE_APPLICATION_ERROR(-20866,
            'String literal com mais de 16000 bytes nao cabe no escape.');
        END IF;
      END LOOP;
    END;
    l_texto := CASE WHEN l_hex IS NOT NULL THEN HEXTORAW(l_hex) END;

    -- cifra e reescreve, escapando de novo
    l_hex := NULL;
    IF l_texto IS NOT NULL THEN
      -- No AES o resultado e MAIOR que a entrada (IV mais preenchimento);
      -- como a string e reescapada de qualquer forma, isso nao incomoda aqui —
      -- ao contrario do /Length dos streams, que precisa mudar. O RC4 e
      -- simetrico; o AES-CBC nao e, entao a volta tem caminho proprio.
      l_cif := CASE
                 WHEN p_aes AND p_decifrar
                   THEN PL_FPDF_UTIL.aes_cbc_decifrar_raw(p_ok, l_texto)
                 WHEN p_aes
                   THEN PL_FPDF_UTIL.aes_cbc_cifrar_raw(p_ok, l_texto)
                 ELSE PL_FPDF_UTIL.crypto_rc4(l_texto, p_ok) END;
      IF UTL_RAW.LENGTH(l_cif) > 16000 THEN
        RAISE_APPLICATION_ERROR(-20866,
          'String literal de ' || UTL_RAW.LENGTH(l_cif)
          || ' bytes nao cabe no escape (teto 16000).');
      END IF;
      FOR b IN 1 .. UTL_RAW.LENGTH(l_cif) LOOP
        l_b := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_cif, b, 1)), 'XX');
        l_hex := l_hex || CASE
                   WHEN l_b IN (co_abre, co_fecha, co_barra)
                     THEN '5C' || LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0')
                   WHEN l_b = 13 THEN '5C72'      -- \r
                   WHEN l_b = 10 THEN '5C6E'      -- \n
                   ELSE LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0') END;
      END LOOP;
    END IF;

    juntar(HEXTORAW('28'));                       -- (
    IF l_hex IS NOT NULL THEN
      juntar(HEXTORAW(l_hex));
    END IF;
    juntar(HEXTORAW('29'));                       -- )
    l_i := l_j + 1;
  END LOOP;

  RETURN CASE WHEN l_out IS NOT NULL
              THEN UTL_RAW.CAST_TO_VARCHAR2(l_out) END;
END sec_cifrar_strings;

--------------------------------------------------------------------------------
-- sec_e_estrutura: o objeto descreve a estrutura do arquivo de ORIGEM?
--
-- /Type /ObjStm e /Type /XRef existem para dizer como aquele arquivo esta
-- organizado. A saida da cifragem leva xref classica e nao tem object stream
-- nenhum, entao copia-los produziria um arquivo que se descreve de duas formas
-- contraditorias — e a que o leitor escolher nao e a nossa.
--------------------------------------------------------------------------------
FUNCTION sec_e_estrutura(p_src IN pdf_source_rec, p_oid IN PLS_INTEGER)
  RETURN BOOLEAN IS
BEGIN
  -- pdf_obj_body, e nao uma janela de tamanho fixo a partir do offset: a
  -- janela ATRAVESSA o fim do objeto e alcanca o dicionario do seguinte. Num
  -- arquivo em que o object stream vem logo depois do fluxo de conteudo, o
  -- /Type /ObjStm dele era encontrado ao examinar o fluxo — que era entao
  -- descartado como se fosse estrutura, deixando a pagina sem /Contents. O
  -- arquivo continuava abrindo, com a pagina em branco.
  RETURN NVL(pdf_dict_value(pdf_obj_body(p_src, p_oid), '/Type'), 'x')
         IN ('/ObjStm', '/XRef');
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END sec_e_estrutura;

--------------------------------------------------------------------------------
-- sec_cifrar_objetos: aplica RC4 a cada stream e string do documento
--
-- Algoritmo 1 da especificacao: cada objeto e cifrado com uma chave propria,
-- MD5(chave + numero(3 bytes LE) + geracao(2 bytes LE)). O dicionario /Encrypt
-- fica de fora — seus /O e /U ja sao resultado dos algoritmos 3 e 5.
--
-- RC4 e cifra de fluxo: o tamanho do payload nao muda, entao /Length continua
-- valendo. As strings, porem, podem crescer ao serem reescapadas, e por isso os
-- offsets sao devolvidos em o_offsets para o chamador montar a xref depois de
-- acrescentar o objeto /Encrypt.
--
-- Serve tambem para DECIFRAR: RC4 e simetrico e o tratamento das strings
-- (desescapa, RC4, reescapa) e o seu proprio inverso. Na decifragem o objeto
-- /Encrypt precisa sair do arquivo, e p_pular diz qual e — ele nao e emitido e
-- nao ganha entrada na xref.
--------------------------------------------------------------------------------
PROCEDURE sec_cifrar_objetos(
  p_pdf      IN     BLOB,
  p_key      IN     RAW,
  p_key_bits IN     PLS_INTEGER,
  o_pdf      IN OUT NOCOPY BLOB,
  o_offsets  IN OUT NOCOPY tpi,
  o_max      OUT    PLS_INTEGER,
  o_root     OUT    PLS_INTEGER,
  o_info     OUT    PLS_INTEGER,
  p_pular    IN     PLS_INTEGER DEFAULT NULL,
  p_aes      IN     BOOLEAN DEFAULT FALSE,
  p_r6       IN     BOOLEAN DEFAULT FALSE,
  p_decifrar IN     BOOLEAN DEFAULT FALSE
) IS
  l_src    pdf_source_rec;
  l_ordem  tpi;
  l_oid    PLS_INTEGER;
  l_start  PLS_INTEGER;
  l_end    PLS_INTEGER;
  l_dend   PLS_INTEGER;
  l_slen   PLS_INTEGER;
  l_ok     RAW(32);
  l_dic    VARCHAR2(32767);
  l_tmp    PLS_INTEGER;
  l_ent    BLOB;
  l_cif    BLOB;
  l_novo   PLS_INTEGER;
BEGIN
  -- Na DECIFRAGEM a origem esta cifrada, e o object stream vem cifrado junto:
  -- a chave precisa entrar aqui, senao ele nao infla. Na cifragem a origem
  -- esta em claro e nao ha chave a passar.
  l_src := pdf_src_load(p_pdf,
             p_chave => CASE WHEN p_decifrar THEN p_key END,
             p_aes   => p_aes,
             p_r6    => p_r6);
  o_max := 0;
  o_root := l_src.root;
  o_info := l_src.info;

  -- Achatar: os objetos que moram dentro de um object stream saem de la e
  -- viram objetos de primeiro nivel; os proprios ObjStm e XRef nao sao
  -- copiados, porque descrevem uma estrutura que o arquivo de saida nao vai
  -- ter — ele leva xref classica.
  l_oid := l_src.xref.FIRST;
  WHILE l_oid IS NOT NULL LOOP
    IF (p_pular IS NULL OR l_oid != p_pular)
       AND NOT sec_e_estrutura(l_src, l_oid) THEN
      l_ordem(l_ordem.COUNT + 1) := l_oid;
      IF l_oid > o_max THEN
        o_max := l_oid;
      END IF;
    END IF;
    l_oid := l_src.xref.NEXT(l_oid);
  END LOOP;

  -- ordena por offset: a xref e indexada por id, e os objetos nao aparecem no
  -- arquivo necessariamente nessa ordem. Quem veio de object stream nao tem
  -- offset — vai para o fim, na ordem do id.
  FOR i IN 1 .. l_ordem.COUNT - 1 LOOP
    FOR j IN 1 .. l_ordem.COUNT - i LOOP
      IF NVL(l_src.xref(l_ordem(j)).offset, 2147483647)
         > NVL(l_src.xref(l_ordem(j + 1)).offset, 2147483647) THEN
        l_tmp := l_ordem(j); l_ordem(j) := l_ordem(j + 1); l_ordem(j + 1) := l_tmp;
      END IF;
    END LOOP;
  END LOOP;

  -- A versao do arquivo tem de acompanhar a cifra: AESV2 pede 1.6 e AESV3
  -- pede 1.7. Escrever 1.4 num arquivo com AES e afirmar o que nao e.
  pdf_app(o_pdf, CASE WHEN p_decifrar THEN '%PDF-1.4'
                      WHEN p_r6       THEN '%PDF-1.7'
                      WHEN p_aes      THEN '%PDF-1.6'
                      ELSE '%PDF-1.4' END || CHR(10));

  FOR i IN 1 .. l_ordem.COUNT LOOP
    l_oid := l_ordem(i);
    o_offsets(l_oid) := DBMS_LOB.GETLENGTH(o_pdf);

    -- ── objeto que veio de dentro de um object stream ────────────────────
    -- Ele nao tem posicao no arquivo e nao pode ter stream (a especificacao
    -- proibe): o corpo ja esta materializado, e o que resta e a assimetria
    -- das strings, logo abaixo.
    IF l_src.objstm.EXISTS(l_oid) THEN
      l_ok := CASE WHEN p_r6 THEN p_key
                   WHEN p_aes THEN PL_FPDF_UTIL.aes_chave_objeto(p_key, l_oid, 0)
                   ELSE compute_object_key(p_key, l_oid, 0, p_key_bits) END;
      l_dic := l_src.objstm(l_oid);
      -- Dentro de um object stream as strings NAO sao cifradas uma a uma: o
      -- que se cifra e o stream inteiro (PDF 32000-1, 7.5.7).
      --   cifrando   -> agora que o objeto e de primeiro nivel, as strings
      --                 passam a precisar de cifra propria
      --   decifrando -> elas ja sairam em claro junto com o stream; passa-las
      --                 pela decifragem de novo as transforma em lixo
      -- Errar isso nao quebra o arquivo: ele abre, as paginas aparecem, e so o
      -- titulo ou o texto de uma anotacao sai embaralhado.
      IF NOT p_decifrar THEN
        l_dic := sec_cifrar_strings(l_dic, l_ok, p_aes, FALSE);
      END IF;
      -- Em pedacos, nao concatenado: l_dic e VARCHAR2(32767) e pode estar
      -- cheio. 'l_oid || '' 0 obj'' || l_dic || CHR(10)' monta um VARCHAR2
      -- MAIOR que l_dic e estoura ORA-06502 antes de o pdf_app ser chamado —
      -- e o erro sai do EncryptPDF sem dizer que foi aqui.
      pdf_app(o_pdf, l_oid || ' 0 obj');
      pdf_app(o_pdf, l_dic);
      pdf_app(o_pdf, CHR(10));
      CONTINUE;
    END IF;

    pdf_obj_extent(l_src, l_oid, l_start, l_end, l_dend, l_slen);
    -- A chave depende da revisao: no R6 (AES-256) NAO ha chave por objeto — a
    -- do arquivo e usada direto. No V4 (AES-128) e a mesma do RC4 mais os
    -- quatro bytes 'sAlT'.
    l_ok := CASE WHEN p_r6 THEN p_key
                 WHEN p_aes THEN PL_FPDF_UTIL.aes_chave_objeto(p_key, l_oid, 0)
                 ELSE compute_object_key(p_key, l_oid, 0, p_key_bits) END;

    -- pdf_read faz LEAST(p_len, 32767) e trunca CALADO. Um dicionario maior
    -- que isso — /W de fonte CID, /Annots longo, /Names grande — era escrito
    -- pela metade e o EncryptPDF/DecryptPDF devolvia um arquivo estruturalmente
    -- quebrado REPORTANDO SUCESSO. Recusar e melhor que entregar errado.
    IF l_dend - l_start > 32767 THEN
      RAISE_APPLICATION_ERROR(-20841,
        'Objeto ' || l_oid || ' tem dicionario de ' || (l_dend - l_start) ||
        ' bytes; o limite de leitura e 32767. Cifrar/decifrar este PDF ' ||
        'truncaria o objeto em silencio.');
    END IF;
    l_dic := pdf_read(l_src.doc, l_start, l_dend - l_start);

    IF l_slen > 0 AND p_aes THEN
      -- O AES muda o tamanho do payload (16 bytes de IV mais o preenchimento),
      -- ao contrario do RC4, que e cifra de fluxo: o /Length TEM de ser
      -- reescrito nos DOIS sentidos — para mais ao cifrar, para menos ao
      -- decifrar. Deixa-lo como esta faz o leitor parar no meio do bloco.
      DBMS_LOB.CREATETEMPORARY(l_ent, TRUE);
      DBMS_LOB.CREATETEMPORARY(l_cif, TRUE);
      DBMS_LOB.COPY(l_ent, p_pdf, l_slen, 1, l_dend + 1);
      IF p_decifrar THEN
        PL_FPDF_UTIL.aes_cbc_decifrar(l_ok, l_ent, l_cif);
      ELSE
        PL_FPDF_UTIL.aes_cbc_cifrar(l_ok, l_ent, l_cif);
      END IF;
      l_novo := DBMS_LOB.GETLENGTH(l_cif);

      l_dic := REGEXP_REPLACE(l_dic, '/Length\s+\d+', '/Length ' || l_novo, 1, 1);
      pdf_app(o_pdf, sec_cifrar_strings(l_dic, l_ok, TRUE, p_decifrar));
      DBMS_LOB.COPY(o_pdf, l_cif, l_novo, DBMS_LOB.GETLENGTH(o_pdf) + 1, 1);
      DBMS_LOB.COPY(o_pdf, p_pdf, l_end - (l_dend + l_slen),
                    DBMS_LOB.GETLENGTH(o_pdf) + 1, l_dend + l_slen + 1);
      DBMS_LOB.FREETEMPORARY(l_ent);
      DBMS_LOB.FREETEMPORARY(l_cif);

    ELSIF l_slen > 0 THEN
      pdf_app(o_pdf, sec_cifrar_strings(l_dic, l_ok));
      -- RC4 nao muda o tamanho, entao o /Length segue valendo. O fluxo vai por
      -- PL_FPDF_UTIL.crypto_rc4_blob, que agenda a chave uma vez e carrega o estado da cifra
      -- entre os pedacos: fatiar com PL_FPDF_UTIL.crypto_rc4 reiniciaria a cifra em cada
      -- pedaco e produziria lixo.
      DBMS_LOB.CREATETEMPORARY(l_ent, TRUE);
      DBMS_LOB.CREATETEMPORARY(l_cif, TRUE);
      DBMS_LOB.COPY(l_ent, p_pdf, l_slen, 1, l_dend + 1);
      PL_FPDF_UTIL.crypto_rc4_blob(l_ent, l_ok, l_cif);
      DBMS_LOB.COPY(o_pdf, l_cif, l_slen, DBMS_LOB.GETLENGTH(o_pdf) + 1, 1);
      DBMS_LOB.FREETEMPORARY(l_ent);
      DBMS_LOB.FREETEMPORARY(l_cif);
      DBMS_LOB.COPY(o_pdf, p_pdf, l_end - (l_dend + l_slen),
                    DBMS_LOB.GETLENGTH(o_pdf) + 1, l_dend + l_slen + 1);

    ELSE
      pdf_app(o_pdf, sec_cifrar_strings(l_dic, l_ok, p_aes, p_decifrar));
    END IF;
    pdf_app(o_pdf, CHR(10));
  END LOOP;
END sec_cifrar_objetos;

/*******************************************************************************
* EncryptPDF: Encrypt existing PDF with password protection
* Supports RC4-40 and RC4-128 encryption methods.
* Modifies the PDF by:
*   1. Adding /Encrypt dictionary
*   2. Adding /ID to trailer
*   3. Encrypting all string and stream objects
*******************************************************************************/
FUNCTION EncryptPDF(
  p_pdf IN BLOB,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL,
  p_permissions IN JSON_OBJECT_T DEFAULT NULL,
  p_encryption IN VARCHAR2 DEFAULT 'RC4-128'
) RETURN BLOB IS
  l_result BLOB;
  l_temp_clob CLOB;
  l_pdf_content VARCHAR2(32767);
  l_key_length PLS_INTEGER;
  l_permissions PLS_INTEGER;
  l_file_id RAW(16);
  l_o_value RAW(48);          -- 48 bytes no R6
  l_u_value RAW(48);
  l_enc_key RAW(32);          -- 32 bytes no AES-256
  l_oe_value RAW(32);
  l_ue_value RAW(32);
  l_perms_c RAW(16);
  l_aes     BOOLEAN;
  l_r6      BOOLEAN;
  l_v_value PLS_INTEGER;
  l_r_value PLS_INTEGER;
  l_offsets tpi;   -- id do objeto -> offset no PDF cifrado
  l_trailer_pos PLS_INTEGER;
  l_xref_pos PLS_INTEGER;
  l_root_ref VARCHAR2(50);
  l_info_ref VARCHAR2(50);
  l_size_val PLS_INTEGER;
  l_new_obj_num PLS_INTEGER;
  l_root_num PLS_INTEGER;
  l_info_num PLS_INTEGER;
  l_id_hex VARCHAR2(100);
  l_pdf_size PLS_INTEGER;
  l_owner_pwd VARCHAR2(100);
BEGIN
  -- Validate encryption method
  IF p_encryption NOT IN ('RC4-40', 'RC4-128', 'AES-128', 'AES-256') THEN
    RAISE_APPLICATION_ERROR(-20850, 'Invalid encryption method: ' || p_encryption ||
      '. Valid: RC4-40, RC4-128, AES-128, AES-256');
  END IF;

  -- Validate password
  IF p_user_password IS NULL THEN
    RAISE_APPLICATION_ERROR(-20851, 'User password is required');
  END IF;

  -- Recusa cedo se o package de criptografia nao cifra de verdade
  PL_FPDF_UTIL.crypto_autoteste;

  -- Check if already encrypted
  IF IsEncrypted(p_pdf) THEN
    RAISE_APPLICATION_ERROR(-20859, 'PDF is already encrypted. Decrypt first.');
  END IF;

  -- Set key length based on method
  CASE p_encryption
    WHEN 'RC4-40' THEN l_key_length := 40; l_v_value := 1; l_r_value := 2;
    WHEN 'RC4-128' THEN l_key_length := 128; l_v_value := 2; l_r_value := 3;
    -- R6, e nao R5: o R5 foi uma extensao da Adobe que a ISO NAO adotou, e
    -- leitores conformes ao PDF 2.0 so reconhecem o R6.
    WHEN 'AES-128' THEN l_key_length := 128; l_v_value := 4; l_r_value := 4;
    WHEN 'AES-256' THEN l_key_length := 256; l_v_value := 5; l_r_value := 6;
  END CASE;

  l_aes := p_encryption IN ('AES-128', 'AES-256');
  l_r6  := p_encryption = 'AES-256';
  IF l_aes THEN
    PL_FPDF_UTIL.aes_autoteste;   -- vetores do FIPS-197; ver PL_FPDF_UTIL.aes_autoteste
  END IF;

  l_owner_pwd := NVL(p_owner_password, p_user_password);

  -- Calculate permissions
  l_permissions := -4;  -- Default: all permissions

  IF p_permissions IS NOT NULL THEN
    l_permissions := -3904;  -- Base: restricted (bits 1-2 must be 0, 7-8 reserved)
    IF NVL(p_permissions.get_boolean('print'), FALSE) THEN l_permissions := l_permissions + 4; END IF;
    IF NVL(p_permissions.get_boolean('modify'), FALSE) THEN l_permissions := l_permissions + 8; END IF;
    IF NVL(p_permissions.get_boolean('copy'), FALSE) THEN l_permissions := l_permissions + 16; END IF;
    IF NVL(p_permissions.get_boolean('annotate'), FALSE) THEN l_permissions := l_permissions + 32; END IF;
    IF NVL(p_permissions.get_boolean('fillForms'), FALSE) THEN l_permissions := l_permissions + 256; END IF;
    IF NVL(p_permissions.get_boolean('extract'), FALSE) THEN l_permissions := l_permissions + 512; END IF;
    IF NVL(p_permissions.get_boolean('assemble'), FALSE) THEN l_permissions := l_permissions + 1024; END IF;
    IF NVL(p_permissions.get_boolean('printHighQuality'), FALSE) THEN l_permissions := l_permissions + 2048; END IF;
  END IF;

  -- Generate file ID
  l_file_id := generate_file_id();

  IF l_r6 THEN
    -- AES-256 (R6): a chave do arquivo e ALEATORIA e nao deriva da senha —
    -- ela fica embrulhada em /UE e /OE, cada uma com uma chave derivada da
    -- senha correspondente. E por isso que o R6 permite trocar a senha sem
    -- recifrar o documento.
    l_enc_key := UTL_RAW.CONCAT(PL_FPDF_UTIL.aes_iv, PL_FPDF_UTIL.aes_iv);
    PL_FPDF_UTIL.aes_valores_r6(p_senha_usr  => p_user_password,
                   p_senha_dono => l_owner_pwd,
                   p_chave      => l_enc_key,
                   p_perms      => l_permissions,
                   o_u          => l_u_value,
                   o_ue         => l_ue_value,
                   o_o          => l_o_value,
                   o_oe         => l_oe_value,
                   o_perms      => l_perms_c);
  ELSE
    -- Compute O value (owner password hash)
    l_o_value := compute_owner_value(l_owner_pwd, p_user_password, l_key_length);

    -- Compute encryption key
    l_enc_key := compute_encryption_key(p_user_password, l_o_value, l_permissions, l_file_id, l_key_length);

    -- Compute U value (user password verification)
    l_u_value := compute_user_value(l_enc_key, l_file_id, l_key_length);
  END IF;

  -- ==========================================================================
  -- Cifragem: cada stream e cada string recebe a cifra com a chave do proprio
  -- objeto (algoritmo 1) — ou, no R6, com a chave do arquivo direto. Ate a
  -- versao anterior o PDF saia apenas MARCADO como protegido, com o conteudo
  -- legivel em qualquer editor de texto.
  -- ==========================================================================
  DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
  sec_cifrar_objetos(p_pdf, l_enc_key, l_key_length,
                     l_result, l_offsets, l_new_obj_num, l_root_num, l_info_num,
                     p_aes => l_aes, p_r6 => l_r6);

  -- o dicionario /Encrypt entra como objeto novo e NAO e cifrado: seus /O e /U
  -- ja sao o resultado dos algoritmos 3 e 5
  l_new_obj_num := l_new_obj_num + 1;
  l_offsets(l_new_obj_num) := DBMS_LOB.GETLENGTH(l_result);
  pdf_app(l_result,
    l_new_obj_num || ' 0 obj' || CHR(10)
    || '<< /Filter /Standard'
    || ' /V ' || l_v_value
    || ' /R ' || l_r_value
    || ' /Length ' || l_key_length
    || ' /P ' || l_permissions
    -- No AES o filtro de fluxo e de string sai do /CF; sem /StmF e /StrF o
    -- leitor supoe /Identity e mostra o conteudo cifrado como se fosse texto.
    || CASE WHEN l_aes THEN
         ' /CF << /StdCF << /CFM /' || CASE WHEN l_r6 THEN 'AESV3' ELSE 'AESV2' END
         || ' /AuthEvent /DocOpen /Length ' || (l_key_length / 8) || ' >> >>'
         || ' /StmF /StdCF /StrF /StdCF' END
    || ' /O <' || RAWTOHEX(l_o_value) || '>'
    || ' /U <' || RAWTOHEX(l_u_value) || '>'
    || CASE WHEN l_r6 THEN
         ' /OE <' || RAWTOHEX(l_oe_value) || '>'
         || ' /UE <' || RAWTOHEX(l_ue_value) || '>'
         || ' /Perms <' || RAWTOHEX(l_perms_c) || '>' END
    || ' >>' || CHR(10)
    || 'endobj' || CHR(10));

  -- /Root e /Info do documento original: os ids nao sao renumerados, entao as
  -- referencias continuam valendo. Fixar '/Root 1 0 R' quebrava o documento —
  -- no PDF gerado pelo PL_FPDF o Catalog costuma ser o ultimo objeto, nao o 1,
  -- e o leitor abria com a senha mas nao encontrava pagina alguma.
  --
  -- Os dois vem do trailer JA LIDO pelo pdf_src_load. A versao anterior os
  -- procurava com uma regex nos ultimos 4000 bytes — funciona por acidente, e
  -- falha num arquivo com atualizacao incremental, onde o trailer que vale nao
  -- e o que esta no fim. Num PDF 1.5+ ela dependia ainda de o dicionario da
  -- xref em stream calhar de estar dentro dessa janela.
  IF l_root_num IS NULL THEN
    RAISE_APPLICATION_ERROR(-20860,
      'PDF invalido: /Root nao encontrado no trailer');
  END IF;
  l_root_ref := l_root_num || ' 0 R';
  l_info_ref := CASE WHEN l_info_num IS NOT NULL
                     THEN l_info_num || ' 0 R' END;
  l_pdf_content := NULL;

  -- xref e trailer novos. O /ID entra em claro, como manda a especificacao:
  -- ele participa do calculo da chave e precisa ser legivel sem a senha.
  l_id_hex := RAWTOHEX(l_file_id);
  l_size_val := l_new_obj_num + 1;
  l_xref_pos := DBMS_LOB.GETLENGTH(l_result);
  pdf_app(l_result, 'xref' || CHR(10) || '0 ' || l_size_val || CHR(10)
                 || '0000000000 65535 f ' || CHR(10));
  l_pdf_content := NULL;
  FOR i IN 1 .. l_size_val - 1 LOOP
    IF l_offsets.EXISTS(i) THEN
      l_pdf_content := l_pdf_content
        || LPAD(l_offsets(i), 10, '0') || ' 00000 n ' || CHR(10);
    ELSE
      l_pdf_content := l_pdf_content || '0000000000 65535 f ' || CHR(10);
    END IF;
    IF LENGTHB(l_pdf_content) > co_pdf_dict_limit THEN
      pdf_app(l_result, l_pdf_content);
      l_pdf_content := NULL;
    END IF;
  END LOOP;
  pdf_app(l_result, l_pdf_content);

  pdf_app(l_result,
    'trailer' || CHR(10)
    || '<< /Size ' || l_size_val
    || ' /Root ' || l_root_ref
    || CASE WHEN l_info_ref IS NOT NULL THEN ' /Info ' || l_info_ref END
    || ' /Encrypt ' || l_new_obj_num || ' 0 R'
    || ' /ID [<' || l_id_hex || '><' || l_id_hex || '>] >>' || CHR(10)
    || 'startxref' || CHR(10) || l_xref_pos || CHR(10)
    || '%%EOF' || CHR(10));

  log_message(2, 'PDF encrypted with ' || p_encryption || ', key=' || l_key_length || 'bit, permissions=' || l_permissions);

  RETURN l_result;
EXCEPTION
  WHEN OTHERS THEN
    IF l_result IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_result); END IF;
    IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE;
    ELSE
      -- O BACKTRACE vai junto. Sem ele, um ORA-06502 vindo daqui de dentro
      -- chega como 'Encryption failed: buffer too small' e nao diz DE ONDE:
      -- a cifragem tem varios buffers de 32767, e sem a linha cada rodada
      -- contra o banco vira um palpite sobre qual deles estourou. Custou
      -- duas rodadas em agosto/2026.
      RAISE_APPLICATION_ERROR(-20852, 'Encryption failed: ' || SQLERRM ||
        ' [em: ' || REPLACE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, CHR(10), ' ')
        || ']');
    END IF;
END EncryptPDF;

/*******************************************************************************
* verify_password: Verify user or owner password against PDF encryption
* Returns TRUE if password is valid, FALSE otherwise
*******************************************************************************/
FUNCTION verify_password(
  p_password IN VARCHAR2,
  p_o_value IN RAW,
  p_u_value IN RAW,
  p_permissions IN PLS_INTEGER,
  p_file_id IN RAW,
  p_key_length IN PLS_INTEGER,
  p_is_owner OUT BOOLEAN,
  -- a chave do documento sai junto: quem verifica a senha e quem precisa
  -- decifrar sao o mesmo chamador, e recalcula-la fora daqui obrigaria a
  -- repetir o caminho do proprietario (algoritmo 7) inteiro.
  p_enc_key OUT RAW
) RETURN BOOLEAN IS
  l_enc_key RAW(16);
  l_computed_u RAW(32);
  l_owner_key RAW(16);
  l_decrypted RAW(32);
BEGIN
  p_is_owner := FALSE;
  p_enc_key  := NULL;

  -- Sem /U nao existe base de comparacao: recusar em vez de seguir e deixar as
  -- comparacoes com NULL decidirem (NULL = NULL nao e TRUE, mas tambem nao e
  -- FALSE, e o resultado da funcao acabava indefinido).
  IF p_u_value IS NULL THEN
    RETURN FALSE;
  END IF;

  -- First try as user password
  l_enc_key := compute_encryption_key(p_password, p_o_value, p_permissions, p_file_id, p_key_length);
  l_computed_u := compute_user_value(l_enc_key, p_file_id, p_key_length);

  -- Compare U values (first 16 bytes for R3+, all 32 for R2)
  log_message(c_LOG_DEBUG, 'verify_password/user: U esperado=' ||
    SUBSTR(RAWTOHEX(NVL(p_u_value, HEXTORAW('00'))), 1, 32) ||
    ' calculado=' || SUBSTR(RAWTOHEX(NVL(l_computed_u, HEXTORAW('00'))), 1, 32));
  IF p_key_length <= 40 THEN
    IF l_computed_u = p_u_value THEN
      p_enc_key := l_enc_key;
      log_message(c_LOG_DEBUG, 'verify_password: aceita como usuario (R2)');
      RETURN TRUE;
    END IF;
  ELSE
    IF UTL_RAW.SUBSTR(l_computed_u, 1, 16) = UTL_RAW.SUBSTR(p_u_value, 1, 16) THEN
      p_enc_key := l_enc_key;
      log_message(c_LOG_DEBUG, 'verify_password: aceita como usuario (R3+)');
      RETURN TRUE;
    END IF;
  END IF;

  -- Try as owner password (algoritmo 7): desfaz o algoritmo 3 na ordem inversa.
  -- Cifragem: RC4 com K, depois K XOR 1 .. K XOR 19.
  -- Decifragem: K XOR 19 .. K XOR 1, e por ultimo K.
  l_owner_key := compute_owner_key(p_password, '', p_key_length);
  IF p_key_length <= 40 THEN
    l_decrypted := rc4_crypt(p_o_value, l_owner_key);
  ELSE
    l_decrypted := p_o_value;
    FOR i IN REVERSE 1 .. 19 LOOP
      l_decrypted := rc4_crypt(l_decrypted, rc4_key_xor(l_owner_key, i));
    END LOOP;
    l_decrypted := rc4_crypt(l_decrypted, l_owner_key);
  END IF;

  -- l_decrypted should now be the user password if owner password was correct
  -- Verify by computing U
  -- l_decrypted JA e a senha de usuario preenchida em 32 bytes: usa-la como
  -- RAW evita o round-trip por VARCHAR2, que corrompia o preenchimento.
  l_enc_key := compute_encryption_key_raw(
    l_decrypted, p_o_value, p_permissions, p_file_id, p_key_length
  );
  l_computed_u := compute_user_value(l_enc_key, p_file_id, p_key_length);

  log_message(c_LOG_DEBUG, 'verify_password/owner: U esperado=' ||
    SUBSTR(RAWTOHEX(NVL(p_u_value, HEXTORAW('00'))), 1, 32) ||
    ' calculado=' || SUBSTR(RAWTOHEX(NVL(l_computed_u, HEXTORAW('00'))), 1, 32));
  IF p_key_length <= 40 THEN
    IF l_computed_u = p_u_value THEN
      p_is_owner := TRUE;
      p_enc_key  := l_enc_key;
      log_message(c_LOG_DEBUG, 'verify_password: aceita como proprietario (R2)');
      RETURN TRUE;
    END IF;
  ELSE
    IF UTL_RAW.SUBSTR(l_computed_u, 1, 16) = UTL_RAW.SUBSTR(p_u_value, 1, 16) THEN
      p_is_owner := TRUE;
      p_enc_key  := l_enc_key;
      log_message(c_LOG_DEBUG, 'verify_password: aceita como proprietario (R3+)');
      RETURN TRUE;
    END IF;
  END IF;

  log_message(c_LOG_DEBUG, 'verify_password: senha recusada');
  RETURN FALSE;
END verify_password;

--------------------------------------------------------------------------------
-- sec_encrypt_dict: texto do objeto apontado por /Encrypt no trailer
--
-- GetSecurityInfo lia /V, /R, /Length e /P dos primeiros 32 KB do PDF INTEIRO,
-- e o REGEXP casava a primeira ocorrencia em qualquer objeto: o /Length de um
-- content stream virava o tamanho da chave (keyLength 260 num RC4-128). Aqui o
-- dicionario de criptografia e localizado de verdade, e a busca fica restrita
-- a ele.
--------------------------------------------------------------------------------
FUNCTION sec_encrypt_dict(p_pdf IN BLOB) RETURN VARCHAR2 IS
  l_len  PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_pdf), 0);
  l_txt  VARCHAR2(32767);
  l_ini  PLS_INTEGER;
  l_obj  PLS_INTEGER;
  l_pos  PLS_INTEGER;
  l_fim  PLS_INTEGER;
  l_ids  tpi;
BEGIN
  IF l_len = 0 THEN
    RETURN NULL;
  END IF;

  -- /Encrypt N 0 R fica no trailer, no fim do arquivo
  l_txt := pdf_read(p_pdf, GREATEST(0, l_len - 4000), LEAST(l_len, 4000));
  l_ini := INSTRB(l_txt, '/Encrypt');
  IF NVL(l_ini, 0) = 0 THEN
    l_pos := DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW('/Encrypt'), 1, 1);
    IF l_pos = 0 THEN
      RETURN NULL;
    END IF;
    l_txt := pdf_read(p_pdf, l_pos - 1, 200);
    l_ini := 1;
  END IF;

  l_ids.DELETE;
  pdf_collect_refs(SUBSTRB(l_txt, l_ini, 60), l_ids);
  IF l_ids.COUNT = 0 THEN
    RETURN NULL;
  END IF;
  l_obj := l_ids(1);

  l_pos := DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW(l_obj || ' 0 obj'), 1, 1);
  IF l_pos = 0 THEN
    RETURN NULL;
  END IF;
  l_fim := DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW('endobj'), l_pos, 1);
  IF l_fim = 0 THEN
    l_fim := LEAST(l_pos + 2000, l_len);
  END IF;
  RETURN pdf_read(p_pdf, l_pos - 1, LEAST(l_fim - l_pos + 6, 32767));
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END sec_encrypt_dict;

/*******************************************************************************
* DecryptPDF: Remove encryption from PDF
* Verifies password, then removes /Encrypt dictionary and /ID from trailer
*******************************************************************************/
FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB IS
  l_result BLOB;
  l_content VARCHAR2(32767);
  l_pdf_size PLS_INTEGER;
  l_key_length PLS_INTEGER;
  l_permissions PLS_INTEGER;
  l_o_value RAW(48);       -- 48 bytes no R6
  l_u_value RAW(48);
  l_oe_value RAW(32);
  l_ue_value RAW(32);
  l_file_id RAW(16);
  l_is_owner BOOLEAN;
  l_root_ref VARCHAR2(50);
  l_info_ref VARCHAR2(50);
  l_root_num PLS_INTEGER;
  l_info_num PLS_INTEGER;
  l_size_val PLS_INTEGER;
  l_tail VARCHAR2(4000);   -- fim do arquivo: /ID, /Root, /Info, /Size
  l_enc_key RAW(32);       -- 32 bytes no AES-256
  l_cfm VARCHAR2(20);
  l_aes BOOLEAN;
  l_r6  BOOLEAN;
  l_enc_obj PLS_INTEGER;
  l_offsets tpi;
  l_max_obj PLS_INTEGER;
  l_xref_pos PLS_INTEGER;
  l_linhas VARCHAR2(32767);
BEGIN
  IF NOT IsEncrypted(p_pdf) THEN
    RAISE_APPLICATION_ERROR(-20853, 'PDF is not encrypted');
  END IF;

  IF p_password IS NULL THEN
    RAISE_APPLICATION_ERROR(-20854, 'Password is required');
  END IF;

  -- Sem RC4 de verdade a verificacao de senha nao significa nada
  PL_FPDF_UTIL.crypto_autoteste;

  l_pdf_size := DBMS_LOB.GETLENGTH(p_pdf);

  -- Dois escopos distintos, e confundi-los era a causa do ORA-06502:
  --   l_content = dicionario /Encrypt  -> /V /R /Length /P /O /U
  --   l_tail    = fim do arquivo       -> /ID /Root /Info /Size (ficam no trailer)
  -- Lendo /Length do PDF inteiro, o primeiro casado era o de um content stream
  -- (ex.: 260). Com isso compute_encryption_key devolvia 260/8 = 32 bytes para
  -- um RAW(16), e a decriptacao morria com 'numeric or value error'.
  l_content := sec_encrypt_dict(p_pdf);
  IF l_content IS NULL THEN
    RAISE_APPLICATION_ERROR(-20861,
      'Dicionario /Encrypt nao encontrado no PDF');
  END IF;
  l_tail := UTL_RAW.CAST_TO_VARCHAR2(
    DBMS_LOB.SUBSTR(p_pdf, LEAST(l_pdf_size, 4000),
                    GREATEST(1, l_pdf_size - 3999)));

  -- Extract encryption parameters
  BEGIN
    -- /V e /R nao sao mais lidos aqui: o filtro vem do /CFM, que e o que
    -- distingue AESV2 de AESV3 e de RC4. Ler os dois so para descartar dava a
    -- impressao de que a decisao dependia deles.
    l_key_length := NVL(TO_NUMBER(REGEXP_SUBSTR(l_content, '/Length\s+(\d+)', 1, 1, NULL, 1)), 40);
    l_permissions := TO_NUMBER(REGEXP_SUBSTR(l_content, '/P\s+(-?\d+)', 1, 1, NULL, 1));

    -- Extract O value
    DECLARE
      l_o_hex VARCHAR2(100);
    BEGIN
      l_o_hex := REGEXP_SUBSTR(l_content, '/O\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_o_hex IS NOT NULL THEN
        l_o_value := HEXTORAW(l_o_hex);
      END IF;
    END;

    -- Extract U value
    DECLARE
      l_u_hex VARCHAR2(100);
    BEGIN
      l_u_hex := REGEXP_SUBSTR(l_content, '/U\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_u_hex IS NOT NULL THEN
        l_u_value := HEXTORAW(l_u_hex);
      END IF;
    END;

    -- Extract file ID
    DECLARE
      l_id_hex VARCHAR2(100);
    BEGIN
      l_id_hex := REGEXP_SUBSTR(l_tail, '/ID\s*\[\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_id_hex IS NOT NULL THEN
        l_file_id := HEXTORAW(l_id_hex);
      END IF;
    END;

  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20861, 'Failed to parse encryption parameters: ' || SQLERRM);
  END;

  -- Qual cifra o documento usa. Sem /CFM o filtro e o RC4 classico.
  l_cfm := REGEXP_SUBSTR(l_content, '/CFM\s*/(\w+)', 1, 1, NULL, 1);
  l_aes := l_cfm IN ('AESV2', 'AESV3');
  l_r6  := l_cfm = 'AESV3';
  IF l_aes THEN
    PL_FPDF_UTIL.aes_autoteste;
  END IF;

  -- Verify password
  -- NVL de proposito: uma funcao BOOLEAN em PL/SQL pode devolver NULL, e
  -- 'IF NOT NULL THEN' nao dispara — uma senha errada seguia adiante sem erro.
  -- Na duvida, recusa.
  IF l_r6 THEN
    -- No R6 a verificacao e outra: nada de MD5, nem de /P e /ID no calculo. A
    -- chave do arquivo nao deriva da senha — vem desembrulhada de /UE ou /OE,
    -- e por isso precisa desses dois valores.
    DECLARE
      l_hex VARCHAR2(200);
    BEGIN
      l_hex := REGEXP_SUBSTR(l_content, '/UE\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_hex IS NOT NULL THEN l_ue_value := HEXTORAW(l_hex); END IF;
      l_hex := REGEXP_SUBSTR(l_content, '/OE\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_hex IS NOT NULL THEN l_oe_value := HEXTORAW(l_hex); END IF;
    END;
    IF l_ue_value IS NULL THEN
      RAISE_APPLICATION_ERROR(-20861,
        'PDF com AESV3 sem /UE: dicionario /Encrypt incompleto.');
    END IF;
    IF NVL(PL_FPDF_UTIL.aes_verificar_r6(p_password, l_u_value, l_ue_value,
                            l_o_value, l_oe_value, l_enc_key, l_is_owner),
           FALSE) = FALSE THEN
      RAISE_APPLICATION_ERROR(-20854, 'Invalid password');
    END IF;
  ELSE
    -- AES-128 (R4) usa os MESMOS algoritmos 2, 3 e 5 do RC4 para /O, /U e para
    -- a chave do documento; so a cifra muda. Por isso verify_password serve aos
    -- dois — e era exatamente por isso que a recusa anterior tinha de ficar
    -- ANTES desta chamada: sem ela, a senha certa seria aceita e os streams
    -- sairiam decifrados com RC4, ou seja, lixo, sem erro nenhum.
    IF NVL(verify_password(p_password, l_o_value, l_u_value, l_permissions,
                           l_file_id, l_key_length, l_is_owner, l_enc_key),
           FALSE) = FALSE THEN
      RAISE_APPLICATION_ERROR(-20854, 'Invalid password');
    END IF;
  END IF;

  -- /Root e /Info sairao do trailer lido pelo pdf_src_load, dentro do
  -- sec_cifrar_objetos — nao de uma regex no fim do arquivo.

  -- numero do objeto que carrega o dicionario /Encrypt: sec_encrypt_dict devolve
  -- o objeto inteiro, comecando por 'N 0 obj'
  l_enc_obj := TO_NUMBER(REGEXP_SUBSTR(l_content, '^\s*(\d+)\s+\d+\s+obj',
                                       1, 1, NULL, 1));

  -- ==========================================================================
  -- Decifragem de verdade. Antes daqui a funcao apenas apagava '/Encrypt N 0 R'
  -- do trailer: o leitor parava de pedir senha e encontrava o conteudo cifrado,
  -- ou seja, o documento nao voltava ao original. RC4 e simetrico, entao o
  -- mesmo percurso da cifragem desfaz o trabalho — sem o objeto /Encrypt, que
  -- e descartado (p_pular) porque /O e /U nao fazem mais sentido.
  -- ==========================================================================
  DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
  sec_cifrar_objetos(p_pdf      => p_pdf,
                     p_key      => l_enc_key,
                     p_key_bits => l_key_length,
                     o_pdf      => l_result,
                     o_offsets  => l_offsets,
                     o_max      => l_max_obj,
                     o_root     => l_root_num,
                     o_info     => l_info_num,
                     p_pular    => l_enc_obj,
                     p_aes      => l_aes,
                     p_r6       => l_r6,
                     p_decifrar => TRUE);

  -- xref e trailer novos, sem /Encrypt e sem /ID (que so servia ao calculo da
  -- chave). Os ids nao sao renumerados: /Root e /Info continuam valendo.
  IF l_root_num IS NULL THEN
    RAISE_APPLICATION_ERROR(-20861,
      'PDF invalido: /Root nao encontrado no trailer');
  END IF;
  l_root_ref := l_root_num || ' 0 R';
  l_info_ref := CASE WHEN l_info_num IS NOT NULL
                     THEN l_info_num || ' 0 R' END;
  l_size_val := l_max_obj + 1;
  l_xref_pos := DBMS_LOB.GETLENGTH(l_result);
  pdf_app(l_result, 'xref' || CHR(10) || '0 ' || l_size_val || CHR(10)
                 || '0000000000 65535 f ' || CHR(10));
  l_linhas := NULL;
  FOR i IN 1 .. l_size_val - 1 LOOP
    IF l_offsets.EXISTS(i) THEN
      l_linhas := l_linhas || LPAD(l_offsets(i), 10, '0') || ' 00000 n ' || CHR(10);
    ELSE
      l_linhas := l_linhas || '0000000000 65535 f ' || CHR(10);
    END IF;
    IF LENGTHB(l_linhas) > co_pdf_dict_limit THEN
      pdf_app(l_result, l_linhas);
      l_linhas := NULL;
    END IF;
  END LOOP;
  pdf_app(l_result, l_linhas);

  pdf_app(l_result,
    'trailer' || CHR(10)
    || '<< /Size ' || l_size_val
    || ' /Root ' || l_root_ref
    || CASE WHEN l_info_ref IS NOT NULL THEN ' /Info ' || l_info_ref END
    || ' >>' || CHR(10)
    || 'startxref' || CHR(10) || l_xref_pos || CHR(10)
    || '%%EOF' || CHR(10));

  log_message(2, 'PDF decrypted successfully. Owner password: ' ||
    CASE WHEN l_is_owner THEN 'YES' ELSE 'NO' END);

  RETURN l_result;
EXCEPTION
  WHEN OTHERS THEN
    IF l_result IS NOT NULL THEN
      BEGIN DBMS_LOB.FREETEMPORARY(l_result); EXCEPTION WHEN OTHERS THEN NULL; END;
    END IF;
    IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE;
    ELSE RAISE_APPLICATION_ERROR(-20855, 'Decryption failed: ' || SQLERRM);
    END IF;
END DecryptPDF;

/*******************************************************************************
* IsEncrypted: Check if PDF is encrypted
*******************************************************************************/
FUNCTION IsEncrypted(p_pdf IN BLOB) RETURN BOOLEAN IS
  l_len PLS_INTEGER;
BEGIN
  IF p_pdf IS NULL THEN
    RETURN FALSE;
  END IF;
  l_len := NVL(DBMS_LOB.GETLENGTH(p_pdf), 0);
  IF l_len = 0 THEN
    RETURN FALSE;
  END IF;

  -- /Encrypt fica no TRAILER, no fim do arquivo. A versao anterior lia os
  -- PRIMEIROS 32767 bytes: funcionava por acidente em documentos pequenos, que
  -- cabem inteiros nessa janela, e mentia em qualquer PDF cifrado maior que
  -- isso. As consequencias iam alem de recusar a decifragem — EncryptPDF usa
  -- esta funcao para barrar dupla cifragem, e passava a cifrar de novo um
  -- documento grande que ja estava cifrado.
  --
  -- DBMS_LOB.INSTR percorre o BLOB inteiro, sem a janela de 32767 e sem passar
  -- por VARCHAR2.
  RETURN DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW('/Encrypt'),
                        GREATEST(1, l_len - 4000), 1) > 0
      OR DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW('/Encrypt'), 1, 1) > 0;
END IsEncrypted;

/*******************************************************************************
* parse_permissions: Parse permission integer into individual flags
*******************************************************************************/
FUNCTION parse_permissions(p_perm_value PLS_INTEGER) RETURN JSON_OBJECT_T IS
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
  -- NUMBER, e nao PLS_INTEGER: /P e um inteiro de 32 bits com sinal e quase
  -- sempre negativo, e converte-lo para sem sinal passa de 2^31-1 (com todas
  -- as permissoes, -4 vira 4294967292). Em PLS_INTEGER isso estourava, o
  -- handler de GetSecurityInfo engolia o erro e TODAS as permissoes saiam
  -- falsas — o que fazia os testes que esperavam FALSE passarem por engano.
  l_perm NUMBER;
BEGIN
  -- Handle negative values (two's complement)
  IF p_perm_value < 0 THEN
    l_perm := p_perm_value + 4294967296;  -- Convert to unsigned
  ELSE
    l_perm := p_perm_value;
  END IF;

  -- Bit 3: Print (low quality for R3+)
  l_perms.put('print', BITAND(l_perm, 4) = 4);

  -- Bit 4: Modify contents
  l_perms.put('modify', BITAND(l_perm, 8) = 8);

  -- Bit 5: Copy or extract text/graphics
  l_perms.put('copy', BITAND(l_perm, 16) = 16);

  -- Bit 6: Add or modify annotations, fill forms
  l_perms.put('annotate', BITAND(l_perm, 32) = 32);

  -- Bit 9: Fill form fields (R3+)
  l_perms.put('fillForms', BITAND(l_perm, 256) = 256);

  -- Bit 10: Extract for accessibility (R3+)
  l_perms.put('extract', BITAND(l_perm, 512) = 512);

  -- Bit 11: Assemble document (R3+)
  l_perms.put('assemble', BITAND(l_perm, 1024) = 1024);

  -- Bit 12: Print high quality (R3+)
  l_perms.put('printHighQuality', BITAND(l_perm, 2048) = 2048);

  RETURN l_perms;
END parse_permissions;

/*******************************************************************************
* GetSecurityInfo: Get security information from PDF
* Returns detailed encryption info including method, key length, and permissions
*******************************************************************************/
FUNCTION GetSecurityInfo(p_pdf IN BLOB) RETURN JSON_OBJECT_T IS
  l_result JSON_OBJECT_T := JSON_OBJECT_T();
  l_perms JSON_OBJECT_T;
  l_content VARCHAR2(32767);
  l_v_value PLS_INTEGER;
  l_r_value PLS_INTEGER;
  l_key_length PLS_INTEGER;
  l_perm_value PLS_INTEGER;
  l_method VARCHAR2(20);
BEGIN
  IF p_pdf IS NULL OR NOT IsEncrypted(p_pdf) THEN
    l_result.put('encrypted', FALSE);
    RETURN l_result;
  END IF;

  -- so o dicionario /Encrypt: buscar no PDF inteiro fazia o /Length de um
  -- content stream virar o tamanho da chave
  l_content := sec_encrypt_dict(p_pdf);
  IF l_content IS NULL THEN
    l_content := UTL_RAW.CAST_TO_VARCHAR2(
      DBMS_LOB.SUBSTR(p_pdf, LEAST(DBMS_LOB.GETLENGTH(p_pdf), 32767), 1));
  END IF;

  l_result.put('encrypted', TRUE);

  -- Extract V value (encryption version)
  BEGIN
    l_v_value := TO_NUMBER(REGEXP_SUBSTR(l_content, '/V\s+(\d+)', 1, 1, NULL, 1));
    l_result.put('version', l_v_value);

    CASE l_v_value
      WHEN 1 THEN l_method := 'RC4-40';
      WHEN 2 THEN l_method := 'RC4-128';
      WHEN 4 THEN l_method := 'AES-128';
      WHEN 5 THEN l_method := 'AES-256';
      ELSE l_method := 'Unknown';
    END CASE;
    l_result.put('method', l_method);
  EXCEPTION WHEN OTHERS THEN
    l_result.put('method', 'Unknown');
    l_result.put('version', 0);
  END;

  -- Extract R value (revision)
  BEGIN
    l_r_value := TO_NUMBER(REGEXP_SUBSTR(l_content, '/R\s+(\d+)', 1, 1, NULL, 1));
    l_result.put('revision', l_r_value);
  EXCEPTION WHEN OTHERS THEN
    l_result.put('revision', 0);
  END;

  -- Extract key length
  BEGIN
    -- Corta antes do /CF: o sub-dicionario do filtro tem um /Length PROPRIO, em
    -- BYTES (16 ou 32), e o primeiro casamento do REGEXP pegaria esse se a
    -- ordem das chaves mudasse. E a mesma armadilha que ja fez o keyLength sair
    -- 260 num RC4-128, quando a busca era no PDF inteiro.
    l_key_length := TO_NUMBER(REGEXP_SUBSTR(
      CASE WHEN INSTR(l_content, '/CF') > 0
           THEN SUBSTR(l_content, 1, INSTR(l_content, '/CF') - 1)
           ELSE l_content END,
      '/Length\s+(\d+)', 1, 1, NULL, 1));
    IF l_key_length IS NULL THEN
      l_key_length := CASE l_v_value WHEN 1 THEN 40 ELSE 128 END;
    END IF;
    l_result.put('keyLength', l_key_length);
  EXCEPTION WHEN OTHERS THEN
    l_result.put('keyLength', 40);
  END;

  -- Extract and parse permissions
  BEGIN
    l_perm_value := TO_NUMBER(REGEXP_SUBSTR(l_content, '/P\s+(-?\d+)', 1, 1, NULL, 1));
    l_result.put('permissionValue', l_perm_value);
    l_perms := parse_permissions(l_perm_value);
    l_result.put('permissions', l_perms);
  EXCEPTION WHEN OTHERS THEN
    -- Default permissions (all restricted)
    l_perms := JSON_OBJECT_T();
    l_perms.put('print', FALSE);
    l_perms.put('modify', FALSE);
    l_perms.put('copy', FALSE);
    l_perms.put('annotate', FALSE);
    l_perms.put('fillForms', FALSE);
    l_perms.put('extract', FALSE);
    l_perms.put('assemble', FALSE);
    l_perms.put('printHighQuality', FALSE);
    l_result.put('permissions', l_perms);
  END;

  -- Check for O and U values (indicates password protection)
  l_result.put('hasUserPassword', INSTR(l_content, '/U ') > 0 OR INSTR(l_content, '/U<') > 0);
  l_result.put('hasOwnerPassword', INSTR(l_content, '/O ') > 0 OR INSTR(l_content, '/O<') > 0);

  RETURN l_result;
END GetSecurityInfo;

/*******************************************************************************
* SetEncryption: Set encryption for PDF being generated
* Also sets appropriate PDF version based on encryption method:
*   - RC4-40/RC4-128: PDF 1.4
*   - AES-128: PDF 1.5
*   - AES-256: PDF 1.7
*******************************************************************************/
PROCEDURE SetEncryption(
  p_encryption IN VARCHAR2,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL
) IS
BEGIN
  IF p_encryption NOT IN ('RC4-40', 'RC4-128', 'AES-128', 'AES-256') THEN
    RAISE_APPLICATION_ERROR(-20850, 'Invalid encryption method: ' || p_encryption);
  END IF;
  IF p_user_password IS NULL THEN
    RAISE_APPLICATION_ERROR(-20851, 'User password is required');
  END IF;

  g_encrypt_method := p_encryption;
  g_user_password := p_user_password;
  g_owner_password := NVL(p_owner_password, p_user_password);

  -- Set PDF version based on encryption method
  CASE p_encryption
    WHEN 'RC4-40' THEN PDFVersion := '1.4';   -- Minimum for security
    WHEN 'RC4-128' THEN PDFVersion := '1.4';  -- PDF 1.4 standard
    WHEN 'AES-128' THEN PDFVersion := '1.5';  -- Requires PDF 1.5+
    WHEN 'AES-256' THEN PDFVersion := '1.7';  -- Requires PDF 1.7+
  END CASE;

  log_message(3, 'Encryption set: ' || p_encryption || ', PDF version: ' || PDFVersion);
END SetEncryption;

/*******************************************************************************
* SetPDFVersion: Set PDF version for generated documents
*******************************************************************************/
PROCEDURE SetPDFVersion(p_version IN VARCHAR2) IS
BEGIN
  IF p_version NOT IN ('1.4', '1.5', '1.6', '1.7', '2.0') THEN
    RAISE_APPLICATION_ERROR(-20857, 'Invalid PDF version: ' || p_version ||
      '. Valid versions: 1.4, 1.5, 1.6, 1.7, 2.0');
  END IF;

  -- Validate encryption compatibility
  IF g_encrypt_method IS NOT NULL THEN
    CASE g_encrypt_method
      WHEN 'AES-128' THEN
        IF p_version < '1.5' THEN
          RAISE_APPLICATION_ERROR(-20858,
            'AES-128 encryption requires PDF 1.5 or higher');
        END IF;
      WHEN 'AES-256' THEN
        IF p_version < '1.7' THEN
          RAISE_APPLICATION_ERROR(-20858,
            'AES-256 encryption requires PDF 1.7 or higher');
        END IF;
      ELSE NULL;
    END CASE;
  END IF;

  PDFVersion := p_version;
  log_message(3, 'PDF version set to: ' || p_version);
END SetPDFVersion;

/*******************************************************************************
* GetPDFVersion: Get current PDF version setting
*******************************************************************************/
FUNCTION GetPDFVersion RETURN VARCHAR2 IS
BEGIN
  RETURN NVL(PDFVersion, '1.4');
END GetPDFVersion;

/*******************************************************************************
* SetPermissions: Set document permissions
*******************************************************************************/
PROCEDURE SetPermissions(
  p_print IN BOOLEAN DEFAULT TRUE,
  p_modify IN BOOLEAN DEFAULT FALSE,
  p_copy IN BOOLEAN DEFAULT FALSE,
  p_annotate IN BOOLEAN DEFAULT TRUE,
  p_fill_forms IN BOOLEAN DEFAULT TRUE,
  p_extract IN BOOLEAN DEFAULT FALSE,
  p_assemble IN BOOLEAN DEFAULT FALSE,
  p_print_high IN BOOLEAN DEFAULT TRUE
) IS
BEGIN
  IF g_encrypt_method IS NULL THEN
    RAISE_APPLICATION_ERROR(-20856, 'SetEncryption must be called before SetPermissions');
  END IF;

  g_sec_permissions := -3904;
  IF p_print THEN g_sec_permissions := g_sec_permissions + 4; END IF;
  IF p_modify THEN g_sec_permissions := g_sec_permissions + 8; END IF;
  IF p_copy THEN g_sec_permissions := g_sec_permissions + 16; END IF;
  IF p_annotate THEN g_sec_permissions := g_sec_permissions + 32; END IF;
  IF p_fill_forms THEN g_sec_permissions := g_sec_permissions + 256; END IF;
  IF p_extract THEN g_sec_permissions := g_sec_permissions + 512; END IF;
  IF p_assemble THEN g_sec_permissions := g_sec_permissions + 1024; END IF;
  IF p_print_high THEN g_sec_permissions := g_sec_permissions + 2048; END IF;
  log_message(3, 'Permissions set: ' || g_sec_permissions);
END SetPermissions;

END PL_FPDF;
/

----------------------------------------------------------------------------
-- Conferência: os quatro objetos precisam sair VALID.
----------------------------------------------------------------------------
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
 ORDER BY object_name, object_type;
