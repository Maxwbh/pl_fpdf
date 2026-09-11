--------------------------------------------------------------------------------
-- PL_FPDF 3.4.0 — instalação completa
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
CREATE OR REPLACE PACKAGE PL_FPDF_UTIL AS
co_version CONSTANT VARCHAR2(10) := '3.4.0';
TYPE tqr IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

/**
 * PT: Codifica o conteúdo e devolve a matriz de módulos com a máscara de menor
 *     penalidade já aplicada. Não desenha nada: quem desenha é o AddQRCode do
 *     PL_FPDF. O critério da referência não é "produz um símbolo", é "um
 *     leitor decodifica".
 *
 * EN: Encodes the content and returns the module matrix with the
 *     lowest-penalty mask already applied. It draws nothing: PL_FPDF's
 *     AddQRCode does that. The reference's bar is not "it produces a symbol",
 *     it is "a reader decodes it".
 *
 * @param p_dados o conteúdo a codificar / the content to encode
 * @param p_ec nível de correção de erro / error correction level: 'L' (7%),
 *        'M' (15%), 'Q' (25%), 'H' (30%)
 * @param o_mat a matriz / the matrix
 * @param o_lado o lado em módulos / the side, in modules
 * @param o_versao a versão do símbolo / the symbol version (1..20)
 * @param o_mascara a máscara escolhida / the chosen mask (0..7)
 * @raises -20870 conteúdo vazio / empty content
 * @raises -20872 nível de correção inválido / invalid correction level
 * @example
 *   PL_FPDF_UTIL.qr_matriz('https://example.com', 'M',
 *                          l_mat, l_lado, l_versao, l_mascara);
 */
PROCEDURE qr_matriz(p_dados   IN  VARCHAR2,
                    p_ec      IN  VARCHAR2 DEFAULT 'M',
                    o_mat     OUT NOCOPY tqr,
                    o_lado    OUT PLS_INTEGER,
                    o_versao  OUT PLS_INTEGER,
                    o_mascara OUT PLS_INTEGER);

/**
 * PT: Devolve o padrão de barras como texto de '0' e '1', um caractere por
 *     módulo. Não desenha: quem desenha é o AddBarcode do PL_FPDF.
 *
 * EN: Returns the bar pattern as a string of '0' and '1', one character per
 *     module. It draws nothing: PL_FPDF's AddBarcode does that.
 *
 * @param p_codigo o conteúdo a codificar / the content to encode
 * @param p_tipo simbologia / symbology: 'CODE128', 'CODE39', 'EAN13', 'EAN8',
 *        'ITF', 'ITF14'
 * @param p_ratio razão entre barra larga e estreita, onde a simbologia usa /
 *        wide-to-narrow ratio, where the symbology has one
 * @return VARCHAR2 - o padrão de módulos / the module pattern
 * @raises -20880 código vazio / empty code
 * @raises -20882 simbologia não suportada / unsupported symbology
 * @example
 *   l_padrao := PL_FPDF_UTIL.bc_padrao('ABC123456', 'CODE128');
 */
FUNCTION bc_padrao(p_codigo IN VARCHAR2,
                   p_tipo   IN VARCHAR2 DEFAULT 'CODE128',
                   p_ratio  IN NUMBER   DEFAULT 3) RETURN VARCHAR2;

/**
 * PT: Descomprime um fluxo zlib. O teto existe porque stream de terceiro é
 *     entrada NÃO CONFIÁVEL: alguns KB podem virar gigabytes (zip bomb) e
 *     derrubar a sessão.
 *
 * EN: Decompresses a zlib stream. The ceiling exists because a third-party
 *     stream is UNTRUSTED input: a few KB can expand to gigabytes (a zip bomb)
 *     and take the session down.
 *
 * @param p_src o fluxo comprimido / the compressed stream
 * @param o_dst o conteúdo descomprimido / the decompressed content
 * @param p_max teto da saída, em bytes / output ceiling, in bytes
 * @raises -20890 fluxo truncado / truncated stream
 * @raises -20891 dados DEFLATE malformados / malformed DEFLATE data
 * @raises -20892 cabeçalho zlib inválido / invalid zlib header
 * @raises -20893 a saída passou do teto / output exceeded the ceiling
 * @raises -20894 tabela interna inconsistente / inconsistent internal table
 * @example
 *   PL_FPDF_UTIL.inflate(l_comprimido, l_claro);
 */
PROCEDURE inflate(p_src IN            BLOB,
                  o_dst IN OUT NOCOPY BLOB,
                  p_max IN            PLS_INTEGER DEFAULT 8388608);

/**
 * PT: Comprime num fluxo zlib: um bloco com Huffman FIXA e LZ77 guloso, com
 *     escape para bloco armazenado quando não compensa — a saída nunca fica
 *     maior que a entrada mais o custo do bloco.
 *
 * EN: Compresses into a zlib stream: one FIXED-Huffman block with greedy LZ77,
 *     falling back to a stored block when it does not pay — the output is
 *     never larger than the input plus the block overhead.
 *
 * @param p_src o conteúdo a comprimir / the content to compress
 * @param o_dst o fluxo zlib / the zlib stream
 * @example
 *   PL_FPDF_UTIL.deflate(l_claro, l_comprimido);
 */
PROCEDURE deflate(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB);

/**
 * PT: Os dois dígitos hexadecimais de um byte. Existe para remontar RAW sem
 *     passar por CHR(n), que não devolve um byte e sim o caractere daquele
 *     ponto de código — em AL32UTF8, todo valor de 128 a 255 sai com DOIS
 *     bytes.
 *
 * EN: The two hex digits of a byte. It exists so RAW can be rebuilt without
 *     CHR(n), which returns not a byte but the character at that code point —
 *     in AL32UTF8 every value from 128 to 255 comes out as TWO bytes.
 *
 * @param p_b o byte / the byte (0..255)
 * @return VARCHAR2 - os dois dígitos / the two digits
 * @example
 *   l_hex := PL_FPDF_UTIL.hex_do_byte(231);      -- 'E7'
 */
FUNCTION hex_do_byte(p_b IN PLS_INTEGER) RETURN VARCHAR2;

/**
 * PT: MD5 de um RAW. O PDF exige MD5 no algoritmo de chave até o
 *     revisionamento 4; não serve para nada que dependa de resistência a
 *     colisão.
 *
 * EN: MD5 of a RAW. The PDF key algorithm requires MD5 up to revision 4; it is
 *     not fit for anything relying on collision resistance.
 *
 * @param p_src a entrada / the input
 * @return RAW - os 16 bytes do resumo / the 16-byte digest
 * @example
 *   l_md5 := PL_FPDF_UTIL.crypto_md5(UTL_RAW.CAST_TO_RAW('abc'));
 */
FUNCTION  crypto_md5(p_src IN RAW) RETURN RAW;

/**
 * PT: Cifra ou decifra um RAW com RC4 — a mesma operação nos dois sentidos,
 *     por ser cifra de fluxo. É o que o PDF usa nos revisionamentos 2 e 3.
 *
 * EN: Encrypts or decrypts a RAW with RC4 — the same operation either way,
 *     being a stream cipher. It is what PDF uses in revisions 2 and 3.
 *
 * @param p_src os dados / the data
 * @param p_key a chave / the key
 * @return RAW - o resultado / the result
 * @example
 *   l_cifrado := PL_FPDF_UTIL.crypto_rc4(l_claro, l_chave);
 */
FUNCTION  crypto_rc4(p_src IN RAW, p_key IN RAW) RETURN RAW;

/**
 * PT: O mesmo que crypto_rc4, para conteúdo que não cabe num RAW.
 *
 * EN: The same as crypto_rc4, for content that does not fit in a RAW.
 *
 * @param p_src os dados / the data
 * @param p_key a chave / the key
 * @param o_dst o resultado / the result
 * @example
 *   PL_FPDF_UTIL.crypto_rc4_blob(l_claro, l_chave, l_cifrado);
 */
PROCEDURE crypto_rc4_blob(p_src IN BLOB, p_key IN RAW,
                          o_dst IN OUT NOCOPY BLOB);

/**
 * PT: Confere MD5 e RC4 contra vetores públicos e levanta se divergir. Vale
 *     rodar depois de instalar: uma tabela transcrita errada compila e só
 *     aparece no arquivo que o leitor recusa.
 *
 * EN: Checks MD5 and RC4 against public vectors and raises on any divergence.
 *     Worth running after installing: a mistyped table compiles fine and only
 *     shows up in a file the reader refuses.
 *
 * @example
 *   PL_FPDF_UTIL.crypto_autoteste;
 */
PROCEDURE crypto_autoteste;

/**
 * PT: Cifra um BLOB em AES-CBC com preenchimento PKCS#5, como o PDF pede. O
 *     tamanho da chave decide entre AES-128 e AES-256.
 *
 * EN: Encrypts a BLOB with AES-CBC and PKCS#5 padding, as PDF requires. The
 *     key length decides between AES-128 and AES-256.
 *
 * @param p_chave a chave / the key (16 ou 32 bytes)
 * @param p_dados o conteúdo / the content
 * @param o_saida o resultado, com o IV na frente / the result, IV first
 * @param p_iv o IV; em branco, um aleatório / the IV; empty means random
 * @example
 *   PL_FPDF_UTIL.aes_cbc_cifrar(l_chave, l_claro, l_cifrado);
 */
PROCEDURE aes_cbc_cifrar(p_chave IN            RAW,
                         p_dados IN            BLOB,
                         o_saida IN OUT NOCOPY BLOB,
                         p_iv    IN            RAW DEFAULT NULL);

/**
 * PT: O mesmo que aes_cbc_cifrar, para conteúdo que cabe num RAW.
 *
 * EN: The same as aes_cbc_cifrar, for content that fits in a RAW.
 *
 * @param p_chave a chave / the key
 * @param p_dados o conteúdo / the content
 * @return RAW - o resultado, com o IV na frente / the result, IV first
 * @example
 *   l_cifrado := PL_FPDF_UTIL.aes_cbc_cifrar_raw(l_chave, l_claro);
 */
FUNCTION  aes_cbc_cifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW;

/**
 * PT: Decifra um BLOB cifrado em AES-CBC, tomando os primeiros 16 bytes como
 *     IV e removendo o preenchimento.
 *
 * EN: Decrypts an AES-CBC BLOB, taking the first 16 bytes as the IV and
 *     stripping the padding.
 *
 * @param p_chave a chave / the key
 * @param p_dados o conteúdo cifrado / the encrypted content
 * @param o_saida o conteúdo claro / the plaintext
 * @example
 *   PL_FPDF_UTIL.aes_cbc_decifrar(l_chave, l_cifrado, l_claro);
 */
PROCEDURE aes_cbc_decifrar(p_chave IN            RAW,
                           p_dados IN            BLOB,
                           o_saida IN OUT NOCOPY BLOB);

/**
 * PT: O mesmo que aes_cbc_decifrar, para conteúdo que cabe num RAW.
 *
 * EN: The same as aes_cbc_decifrar, for content that fits in a RAW.
 *
 * @param p_chave a chave / the key
 * @param p_dados o conteúdo cifrado / the encrypted content
 * @return RAW - o conteúdo claro / the plaintext
 * @example
 *   l_claro := PL_FPDF_UTIL.aes_cbc_decifrar_raw(l_chave, l_cifrado);
 */
FUNCTION  aes_cbc_decifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW;

/**
 * PT: Deriva a chave de um objeto a partir da chave do documento e da
 *     numeração dele, como manda o algoritmo 1 do PDF. Cada objeto é cifrado
 *     com uma chave própria: é isso que impede trocar um objeto de lugar.
 *
 * EN: Derives an object's key from the document key and the object's
 *     numbering, as PDF's algorithm 1 requires. Each object is encrypted under
 *     its own key, which is what stops objects being swapped around.
 *
 * @param p_chave a chave do documento / the document key
 * @param p_obj_num o número do objeto / the object number
 * @param p_gen_num o número de geração / the generation number
 * @return RAW - a chave do objeto / the object key
 * @example
 *   l_chave_obj := PL_FPDF_UTIL.aes_chave_objeto(l_chave, 12);
 */
FUNCTION  aes_chave_objeto(p_chave   IN RAW,
                           p_obj_num IN PLS_INTEGER,
                           p_gen_num IN PLS_INTEGER DEFAULT 0) RETURN RAW;

/**
 * PT: Devolve 16 bytes aleatórios para servir de IV.
 *
 * EN: Returns 16 random bytes to serve as an IV.
 *
 * @return RAW - os 16 bytes / the 16 bytes
 * @example
 *   l_iv := PL_FPDF_UTIL.aes_iv;
 */
FUNCTION  aes_iv RETURN RAW;

/**
 * PT: Monta as entradas /U, /UE, /O, /OE e /Perms do dicionário de
 *     criptografia do revisionamento 6 (AES-256, PDF 2.0), que é onde a senha
 *     passa por SHA-256 endurecido em vez de MD5.
 *
 * EN: Builds the /U, /UE, /O, /OE and /Perms entries of the revision 6
 *     encryption dictionary (AES-256, PDF 2.0), where the password goes
 *     through hardened SHA-256 instead of MD5.
 *
 * @param p_senha_usr senha de usuário / user password
 * @param p_senha_dono senha de dono / owner password
 * @param p_chave a chave do documento / the document key
 * @param p_perms as permissões, como número / the permissions, as a number
 * @param o_u entradas /U e /UE / the /U and /UE entries
 * @param o_ue entradas /U e /UE / the /U and /UE entries
 * @param o_o entradas /O e /OE / the /O and /OE entries
 * @param o_oe entradas /O e /OE / the /O and /OE entries
 * @param o_perms a entrada /Perms / the /Perms entry
 * @example
 *   PL_FPDF_UTIL.aes_valores_r6('usuario', 'dono', l_chave, -4,
 *                               l_u, l_ue, l_o, l_oe, l_perms);
 */
PROCEDURE aes_valores_r6(p_senha_usr  IN  VARCHAR2,
                         p_senha_dono IN  VARCHAR2,
                         p_chave      IN  RAW,
                         p_perms      IN  NUMBER,
                         o_u          OUT RAW,
                         o_ue         OUT RAW,
                         o_o          OUT RAW,
                         o_oe         OUT RAW,
                         o_perms      OUT RAW);

/**
 * PT: Confere a senha contra as entradas do dicionário e, acertando, devolve a
 *     chave do documento e diz se era a senha de dono.
 *
 * EN: Checks the password against the dictionary entries and, on a match,
 *     returns the document key and says whether it was the owner password.
 *
 * @param p_senha a senha a conferir / the password to check
 * @param p_u as entradas do dicionário / the dictionary entries
 * @param p_ue as entradas do dicionário / the dictionary entries
 * @param p_o as entradas do dicionário / the dictionary entries
 * @param p_oe as entradas do dicionário / the dictionary entries
 * @param o_chave a chave do documento, quando confere / the document key on a
 *        match
 * @param o_dono TRUE se era a senha de dono / TRUE when it was the owner one
 * @return BOOLEAN - TRUE se a senha confere / TRUE when the password matches
 * @example
 *   IF PL_FPDF_UTIL.aes_verificar_r6(l_senha, l_u, l_ue, l_o, l_oe,
 *                                    l_chave, l_dono) THEN ...
 */
FUNCTION  aes_verificar_r6(p_senha IN  VARCHAR2,
                           p_u     IN  RAW,
                           p_ue    IN  RAW,
                           p_o     IN  RAW,
                           p_oe    IN  RAW,
                           o_chave OUT RAW,
                           o_dono  OUT BOOLEAN) RETURN BOOLEAN;

/**
 * PT: Confere o AES contra os vetores do FIPS-197 e levanta se divergir.
 *
 * EN: Checks AES against the FIPS-197 vectors and raises on any divergence.
 *
 * @example
 *   PL_FPDF_UTIL.aes_autoteste;
 */
PROCEDURE aes_autoteste;
END PL_FPDF_UTIL;
/

--------------------------------------------------------------------------------
-- PACKAGE BODY PL_FPDF_UTIL
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PL_FPDF_UTIL AS

type tpi    is table of pls_integer index by pls_integer;
type tv4000 is table of varchar2(4000) index by pls_integer;

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
g_qr_exp tqr;
g_qr_log tqr;
g_qr_gf_ready boolean := false;

g_crypto_ok boolean := false;

co_aes_sbox CONSTANT VARCHAR2(512) :=
  '637C777BF26B6FC53001672BFED7AB76' || 'CA82C97DFA5947F0ADD4A2AF9CA472C0' ||
  'B7FD9326363FF7CC34A5E5F171D83115' || '04C723C31896059A071280E2EB27B275' ||
  '09832C1A1B6E5AA0523BD6B329E32F84' || '53D100ED20FCB15B6ACBBE394A4C58CF' ||
  'D0EFAAFB434D338545F9027F503C9FA8' || '51A3408F929D38F5BCB6DA2110FFF3D2' ||
  'CD0C13EC5F974417C4A77E3D645D1973' || '60814FDC222A908846EEB814DE5E0BDB' ||
  'E0323A0A4906245CC2D3AC629195E479' || 'E7C8376D8DD54EA96C56F4EA657AAE08' ||
  'BA78252E1CA6B4C6E8DD741F4BBD8B8A' || '703EB5664803F60E613557B986C11D9E' ||
  'E1F8981169D98E949B1E87E9CE5528DF' || '8CA1890DBFE6426841992D0FB054BB16';
g_aes_pronto BOOLEAN := FALSE;
g_aes_ok     BOOLEAN := FALSE;
g_aes_sbox   tpi;
g_aes_inv    tpi;
g_aes_m2     tpi;
g_aes_m3     tpi;
g_aes_m9     tpi;
g_aes_m11    tpi;
g_aes_m13    tpi;
g_aes_m14    tpi;
g_aes_hex    tv4000;

co_inf_max_bits CONSTANT PLS_INTEGER := 15;

co_inf_cbase CONSTANT VARCHAR2(200) :=
  '3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,'
  || '163,195,227,258';
co_inf_cextra CONSTANT VARCHAR2(100) :=
  '0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0';

co_inf_dbase CONSTANT VARCHAR2(200) :=
  '1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,'
  || '2049,3073,4097,6145,8193,12289,16385,24577';
co_inf_dextra CONSTANT VARCHAR2(100) :=
  '0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13';

co_inf_ordem CONSTANT VARCHAR2(100) :=
  '16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15';

co_def_janela  CONSTANT PLS_INTEGER := 32768;
co_def_cas_min CONSTANT PLS_INTEGER := 3;
co_def_cas_max CONSTANT PLS_INTEGER := 258;
co_def_hash    CONSTANT PLS_INTEGER := 32767;
co_def_corrente CONSTANT PLS_INTEGER := 16;

co_def_max_comp CONSTANT PLS_INTEGER := 262144;
g_def_hex   VARCHAR2(32767);
g_def_acum  PLS_INTEGER;
g_def_nbits PLS_INTEGER;
g_def_ent   tpi;
g_def_cab   tpi;
g_def_ant   tpi;
g_inf_pronto BOOLEAN := FALSE;
g_inf_cbase  tpi;
g_inf_cextra tpi;
g_inf_dbase  tpi;
g_inf_dextra tpi;
g_inf_ordem  tpi;

g_inf_lit_c  tpi;  g_inf_lit_s  tpi;
g_inf_dst_c  tpi;  g_inf_dst_s  tpi;
g_inf_cl_c   tpi;  g_inf_cl_s   tpi;

co_inf_janela CONSTANT PLS_INTEGER := 32768;
g_inf_jan     tpi;

g_inf_src   BLOB;
g_inf_len   PLS_INTEGER := 0;
g_inf_pos   PLS_INTEGER := 1;
g_inf_acum  NUMBER := 0;
g_inf_nbits PLS_INTEGER := 0;

procedure aes_init;

function qr_xor(a pls_integer, b pls_integer) return pls_integer is
begin
  return a + b - 2 * bitand(a, b);
end qr_xor;

procedure qr_init_gf is
  x pls_integer := 1;
begin
  if g_qr_gf_ready then return; end if;
  for i in 0..254 loop
    g_qr_exp(i) := x;
    g_qr_log(x) := i;
    x := x * 2;
    if x >= 256 then x := qr_xor(x, 285); end if;
  end loop;
  for i in 255..511 loop
    g_qr_exp(i) := g_qr_exp(i - 255);
  end loop;
  g_qr_gf_ready := true;
end qr_init_gf;

function qr_gf_mul(a pls_integer, b pls_integer) return pls_integer is
begin
  if a = 0 or b = 0 then return 0; end if;
  return g_qr_exp(g_qr_log(a) + g_qr_log(b));
end qr_gf_mul;

function qr_field(p_list varchar2, p_pos pls_integer, p_sep varchar2 default ',')
  return varchar2 is
  l_ini pls_integer := 1;
  l_fim pls_integer;
begin

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

procedure qr_encode(p_text varchar2, p_ecl varchar2,
                    o_cw out tqr, o_ver out pls_integer, o_len out pls_integer) is
  l_raw   raw(32767);
  l_nb    pls_integer;
  l_ec pls_integer; l_g1 pls_integer; l_d1 pls_integer;
  l_g2 pls_integer; l_d2 pls_integer;
  l_total pls_integer;
  l_bits  tqr;  l_nbits pls_integer := 0;
  l_data  tqr;  l_ndata pls_integer := 0;
  l_blocks tqr;
  l_sizes  tqr;
  l_eccs   tqr;
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

  put_bits(4, 4);
  put_bits(l_nb, case when o_ver <= 9 then 8 else 16 end);
  for i in 1..l_nb loop
    put_bits(to_number(rawtohex(utl_raw.substr(l_raw, i, 1)), 'XX'), 8);
  end loop;

  for i in 1..least(4, l_total * 8 - l_nbits) loop
    l_nbits := l_nbits + 1; l_bits(l_nbits) := 0;
  end loop;
  while mod(l_nbits, 8) != 0 loop
    l_nbits := l_nbits + 1; l_bits(l_nbits) := 0;
  end loop;

  for i in 0..(l_nbits / 8) - 1 loop
    l_ndata := l_ndata + 1;
    l_data(l_ndata) := 0;
    for j in 1..8 loop
      l_data(l_ndata) := l_data(l_ndata) * 2 + l_bits(i * 8 + j);
    end loop;
  end loop;

  while l_ndata < l_total loop
    l_ndata := l_ndata + 1;
    l_data(l_ndata) := case when mod(l_pad, 2) = 0 then 236 else 17 end;
    l_pad := l_pad + 1;
  end loop;

  for g in 1..2 loop
    for b in 1..(case g when 1 then l_g1 else l_g2 end) loop
      declare
        l_sz pls_integer := case g when 1 then l_d1 else l_d2 end;
      begin
        l_nblk := l_nblk + 1;
        l_blocks(l_nblk) := l_pos;
        l_sizes(l_nblk)  := l_sz;

        declare
          l_gen tqr; l_res tqr; l_f pls_integer;
        begin
          l_gen(0) := 1;
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

  for i in 8..n-9 loop
    if not isres(6, i) then setm(6, i, case when mod(i,2)=0 then 1 else 0 end, 1); end if;
    if not isres(i, 6) then setm(i, 6, case when mod(i,2)=0 then 1 else 0 end, 1); end if;
  end loop;

  l_al := qr_field(co_qr_align, p_ver, '|');
  l_np := case when l_al is null then 0
               else length(l_al) - length(replace(l_al, ',')) + 1 end;
  for a in 1..l_np loop
    for b in 1..l_np loop
      declare
        r pls_integer := to_number(qr_field(l_al, a));
        c pls_integer := to_number(qr_field(l_al, b));
      begin

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

  setm(n-8, 8, 1, 1);

  for i in 0..8 loop
    if not isres(8, i) then setm(8, i, 0, 1); end if;
    if not isres(i, 8) then setm(i, 8, 0, 1); end if;
  end loop;
  for i in 0..7 loop
    if not isres(8, n-1-i) then setm(8, n-1-i, 0, 1); end if;
    if not isres(n-1-i, 8) then setm(n-1-i, 8, 0, 1); end if;
  end loop;

  if p_ver >= 7 then
    for i in 0..5 loop
      for j in 0..2 loop
        setm(n-11+j, i, 0, 1);
        setm(i, n-11+j, 0, 1);
      end loop;
    end loop;
  end if;

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

function qr_bch_format(p_fmt pls_integer) return pls_integer is
  v pls_integer := p_fmt * 1024;
begin
  for i in reverse 0..4 loop
    if bitand(v, power(2, i + 10)) > 0 then
      v := qr_xor(v, 1335 * power(2, i));
    end if;
  end loop;
  return qr_xor(p_fmt * 1024 + v, 21522);
end qr_bch_format;

function qr_bch_version(p_ver pls_integer) return pls_integer is
  v pls_integer := p_ver * 4096;
begin
  for i in reverse 0..5 loop
    if bitand(v, power(2, i + 12)) > 0 then
      v := qr_xor(v, 7973 * power(2, i));
    end if;
  end loop;
  return p_ver * 4096 + v;
end qr_bch_version;

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
  p_m((p_n - 8) * p_n + 8) := 1;
end qr_place_format;

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
  for r in 0..p_n-1 loop
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
  for c in 0..p_n-1 loop
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

  for r in 0..p_n-2 loop
    for c in 0..p_n-2 loop
      if px(r,c) = px(r,c+1) and px(r,c) = px(r+1,c) and px(r,c) = px(r+1,c+1) then
        s := s + 3;
      end if;
    end loop;
  end loop;

  for r in 0..p_n-1 loop
    for c in 0..p_n-11 loop
      if run3(r, c, true) then s := s + 40; end if;
    end loop;
  end loop;
  for c in 0..p_n-1 loop
    for r in 0..p_n-11 loop
      if run3(r, c, false) then s := s + 40; end if;
    end loop;
  end loop;

  for i in 0..p_n*p_n-1 loop
    dark := dark + p_m(i);
  end loop;
  ratio := trunc(dark * 100 / (p_n * p_n));
  s := s + 10 * trunc(abs(ratio - 50) / 5);
  return s;
end qr_penalty;

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

function bc_only_digits(p_str varchar2) return varchar2 is
begin
  return regexp_replace(p_str, '[^0-9]', '');
end bc_only_digits;

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
      l_out := l_out || '0';
    end if;
  end loop;
  return l_out;
end bc_code39;

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
    l_n := 1; l_codes(1) := 105;
    for i in 1..length(p_data)/2 loop
      l_n := l_n + 1;
      l_codes(l_n) := to_number(substr(p_data, (i-1)*2 + 1, 2));
    end loop;
  else
    l_n := 1; l_codes(1) := 104;
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
  l_n := l_n + 1; l_codes(l_n) := 106;

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

  l_out := '101';
  if p_len = 13 then
    l_par := substr(co_bc_ean_par, to_number(substr(l_d, 1, 1)) * 6 + 1, 6);
    for i in 1..6 loop
      l_dig := to_number(substr(l_d, i + 1, 1));
      l_out := l_out || case when substr(l_par, i, 1) = 'L'
                             then substr(co_bc_ean_l, l_dig * 7 + 1, 7)
                             else substr(co_bc_ean_g, l_dig * 7 + 1, 7) end;
    end loop;
    l_out := l_out || '01010';
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
  return l_out || '101';
end bc_ean;

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
    l_d := '0' || l_d;
  end if;

  l_out := '1010';
  for i in 1 .. length(l_d) / 2 loop
    l_a := substr(co_bc_itf, to_number(substr(l_d, (i-1)*2 + 1, 1)) * 5 + 1, 5);
    l_b := substr(co_bc_itf, to_number(substr(l_d, (i-1)*2 + 2, 1)) * 5 + 1, 5);
    for j in 1..5 loop
      l_out := l_out || rpad('1', case when substr(l_a, j, 1) = 'w' then p_ratio else 1 end, '1');
      l_out := l_out || rpad('0', case when substr(l_b, j, 1) = 'w' then p_ratio else 1 end, '0');
    end loop;
  end loop;
  return l_out || rpad('1', p_ratio, '1') || '0' || '1';
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

PROCEDURE inf_init IS

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
  carrega(co_inf_cbase,  g_inf_cbase,  29);
  carrega(co_inf_cextra, g_inf_cextra, 29);
  carrega(co_inf_dbase,  g_inf_dbase,  30);
  carrega(co_inf_dextra, g_inf_dextra, 30);
  carrega(co_inf_ordem,  g_inf_ordem,  19);
  g_inf_pronto := TRUE;
END inf_init;

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
  l_qtd   PLS_INTEGER := 0;

  PROCEDURE descarregar IS
  BEGIN
    IF l_hex IS NOT NULL THEN
      DBMS_LOB.WRITEAPPEND(o_dst, LENGTH(l_hex) / 2, HEXTORAW(l_hex));
      l_hex := NULL;
    END IF;
  END descarregar;

  PROCEDURE emitir(p_b IN PLS_INTEGER) IS
  BEGIN

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
  aes_init;
  g_inf_jan.DELETE;
  g_inf_src   := p_src;
  g_inf_len   := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  g_inf_pos   := 1;
  g_inf_acum  := 0;
  g_inf_nbits := 0;

  LOOP
    l_final := inf_bits(1);
    l_tipo  := inf_bits(2);

    IF l_tipo = 0 THEN
      g_inf_acum  := 0;
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
  g_inf_jan.DELETE;
  g_inf_src := NULL;
END pdf_inflate;

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

  DBMS_LOB.CREATETEMPORARY(l_cru, TRUE);
  DBMS_LOB.COPY(l_cru, p_src, l_n - 6, 1, 3);
  pdf_inflate(l_cru, o_dst, p_max);
  DBMS_LOB.FREETEMPORARY(l_cru);
END inflate;

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

PROCEDURE def_codigo(p_v IN PLS_INTEGER, p_n IN PLS_INTEGER,
                     o_dst IN OUT NOCOPY BLOB) IS
BEGIN
  FOR i IN REVERSE 0 .. p_n - 1 LOOP
    def_bits(MOD(TRUNC(p_v / POWER(2, i)), 2), 1, o_dst);
  END LOOP;
END def_codigo;

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

PROCEDURE def_armazenado(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB) IS
  l_n    PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_pos  PLS_INTEGER := 1;
  l_tam  PLS_INTEGER;
  l_fim  PLS_INTEGER;
BEGIN
  LOOP
    l_tam := LEAST(65535, l_n - l_pos + 1);
    l_fim := CASE WHEN l_pos + l_tam > l_n THEN 1 ELSE 0 END;
    def_byte(l_fim, o_dst);
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

PROCEDURE def_comprimido(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB) IS
  l_n    PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_i    PLS_INTEGER;
  l_h    PLS_INTEGER;
  l_cand PLS_INTEGER;
  l_vis  PLS_INTEGER;
  l_tam  PLS_INTEGER;
  l_lim  PLS_INTEGER;
  l_mt   PLS_INTEGER;
  l_md   PLS_INTEGER;
  l_k    PLS_INTEGER;
  l_cod  PLS_INTEGER;
  l_hex  VARCHAR2(32767);
  l_pos  PLS_INTEGER;

  FUNCTION disp(p_i IN PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN

    RETURN BITAND(g_def_ent(p_i) * 1024
                  + g_def_ent(p_i + 1) * 32 + g_def_ent(p_i + 2),
                  co_def_hash);
  END disp;
BEGIN

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

  def_bits(1, 1, o_dst);
  def_bits(1, 2, o_dst);

  l_i := 0;
  WHILE l_i < l_n LOOP
    l_mt := 0;
    l_md := 0;
    IF l_i + co_def_cas_min <= l_n THEN
      l_h    := disp(l_i);

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

      l_cod := 0;
      FOR c IN 0 .. 28 LOOP
        EXIT WHEN g_inf_cbase(c) > l_mt;
        l_cod := c;
      END LOOP;
      def_lit(257 + l_cod, o_dst);
      IF g_inf_cextra(l_cod) > 0 THEN
        def_bits(l_mt - g_inf_cbase(l_cod), g_inf_cextra(l_cod), o_dst);
      END IF;

      l_cod := 0;
      FOR c IN 0 .. 29 LOOP
        EXIT WHEN g_inf_dbase(c) > l_md;
        l_cod := c;
      END LOOP;
      def_codigo(l_cod, 5, o_dst);
      IF g_inf_dextra(l_cod) > 0 THEN
        def_bits(l_md - g_inf_dbase(l_cod), g_inf_dextra(l_cod), o_dst);
      END IF;

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

  def_lit(256, o_dst);
  IF g_def_nbits > 0 THEN
    def_byte(MOD(g_def_acum, 256), o_dst);
    g_def_acum  := 0;
    g_def_nbits := 0;
  END IF;
  def_descarregar(o_dst);
  g_def_ent.DELETE; g_def_cab.DELETE; g_def_ant.DELETE;
END def_comprimido;

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

  l_res := l_b;
  RETURN l_res * 65536 + l_a;
END def_adler;

PROCEDURE deflate(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB) IS
  l_n     PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_src), 0);
  l_comp  BLOB;
  l_arm   BLOB;
  l_som   NUMBER;
BEGIN
  inf_init;
  aes_init;
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

FUNCTION crypto_md5(p_src IN RAW) RETURN RAW IS
  l_hash RAW(16);
BEGIN
  IF p_src IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT STANDARD_HASH(p_src, 'MD5') INTO l_hash FROM dual;
  RETURN l_hash;
END crypto_md5;

FUNCTION crypto_rc4(p_src IN RAW, p_key IN RAW) RETURN RAW IS

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

  FOR x IN 0 .. 255 LOOP
    l_s(x) := x;
  END LOOP;
  FOR x IN 0 .. 255 LOOP
    l_j := MOD(l_j + l_s(x)
               + TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(p_key, MOD(x, l_klen) + 1, 1)), 'XX'),
               256);
    l_t := l_s(x); l_s(x) := l_s(l_j); l_s(l_j) := l_t;
  END LOOP;

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

PROCEDURE crypto_rc4_blob(
  p_src IN            BLOB,
  p_key IN            RAW,
  o_dst IN OUT NOCOPY BLOB
) IS
  co_lote CONSTANT PLS_INTEGER := 8000;
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

PROCEDURE aes_init IS
  l_b PLS_INTEGER;

  FUNCTION xtime(p IN PLS_INTEGER) RETURN PLS_INTEGER IS
    l PLS_INTEGER := p * 2;
  BEGIN

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
    g_aes_hex(i)  := SUBSTR(co_aes_sbox, i * 2 + 1, 2);
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

FUNCTION aes_expandir(p_chave IN RAW, o_nr OUT PLS_INTEGER) RETURN RAW IS
  co_rcon CONSTANT VARCHAR2(28) := '01020408102040801B366CD8AB4D';
  l_nk  PLS_INTEGER := UTL_RAW.LENGTH(p_chave) / 4;
  l_w   tpi;
  l_t   tpi;
  l_hex VARCHAR2(32767);
BEGIN
  aes_init;
  IF l_nk NOT IN (4, 8) THEN

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
        l_t(0) := g_aes_sbox(l_t(1));
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

    FOR c IN 0 .. 3 LOOP
      FOR i IN 0 .. 3 LOOP
        l_t(c * 4 + i) := g_aes_sbox(l_s(MOD(c + i, 4) * 4 + i));
      END LOOP;
    END LOOP;

    IF r != p_nr THEN
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

    FOR c IN 0 .. 3 LOOP
      FOR i IN 0 .. 3 LOOP
        l_t(c * 4 + i) := g_aes_inv(l_s(MOD(c - i + 4, 4) * 4 + i));
      END LOOP;
    END LOOP;
    FOR i IN 0 .. 15 LOOP
      l_s(i) := l_t(i);
    END LOOP;
    add_round_key(r);

    IF r != 0 THEN
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

FUNCTION aes_iv RETURN RAW IS
BEGIN
  RETURN UTL_RAW.SUBSTR(crypto_md5(UTL_RAW.CONCAT(SYS_GUID(),
           UTL_RAW.CAST_TO_RAW(TO_CHAR(SYSTIMESTAMP,
                               'YYYYMMDDHH24MISSFF9')))), 1, 16);
END aes_iv;

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

      l_bloco := UTL_RAW.CONCAT(
        DBMS_LOB.SUBSTR(p_dados, l_n - l_pos + 1, l_pos),
        UTL_RAW.COPIES(HEXTORAW(g_aes_hex(l_pad)), l_pad));
    ELSE

      l_bloco := UTL_RAW.COPIES(HEXTORAW(g_aes_hex(16)), 16);
    END IF;
    l_ant := aes_bloco(UTL_RAW.BIT_XOR(l_bloco, l_ant), l_w, l_nr);
    DBMS_LOB.WRITEAPPEND(o_saida, 16, l_ant);
    l_pos := l_pos + 16;
  END LOOP;
END aes_cbc_cifrar;

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
  l_pos   PLS_INTEGER := 17;
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

      l_pad := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_claro, 16, 1)), 'XX');
      IF l_pad BETWEEN 1 AND 15 THEN
        DBMS_LOB.WRITEAPPEND(o_saida, 16 - l_pad,
                             UTL_RAW.SUBSTR(l_claro, 1, 16 - l_pad));
      ELSIF l_pad != 16 THEN
        RAISE_APPLICATION_ERROR(-20857,
          'Preenchimento AES invalido (' || l_pad || '): senha errada ou '
          || 'fluxo corrompido.');
      END IF;

    ELSE
      DBMS_LOB.WRITEAPPEND(o_saida, 16, l_claro);
    END IF;
    l_ant := l_c;
    l_pos := l_pos + 16;
  END LOOP;
END aes_cbc_decifrar;

FUNCTION aes_cbc_decifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW IS
  l_ent BLOB;
  l_sai BLOB;
  l_out RAW(32767);
  l_n   PLS_INTEGER;
BEGIN
  IF NVL(UTL_RAW.LENGTH(p_dados), 0) < 32 THEN
    RETURN p_dados;
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

FUNCTION aes_chave_objeto(
  p_chave   IN RAW,
  p_obj_num IN PLS_INTEGER,
  p_gen_num IN PLS_INTEGER DEFAULT 0
) RETURN RAW IS
  co_salt CONSTANT RAW(4) := HEXTORAW('73416C54');
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

  l_k := aes_sha(UTL_RAW.CONCAT(p_senha, p_sal, NVL(p_extra, HEXTORAW(''))),
                 256);

  LOOP
    l_um  := UTL_RAW.CONCAT(p_senha, l_k, NVL(p_extra, HEXTORAW('')));
    l_k1  := UTL_RAW.COPIES(l_um, 64);
    l_len := UTL_RAW.LENGTH(l_k1);

    l_w   := aes_expandir(UTL_RAW.SUBSTR(l_k, 1, 16), l_nr);
    l_ant := UTL_RAW.SUBSTR(l_k, 17, 16);
    l_e   := NULL;
    FOR b IN 0 .. l_len / 16 - 1 LOOP
      l_ant := aes_bloco(
                 UTL_RAW.BIT_XOR(UTL_RAW.SUBSTR(l_k1, b * 16 + 1, 16), l_ant),
                 l_w, l_nr);
      l_e := UTL_RAW.CONCAT(l_e, l_ant);
    END LOOP;

    l_soma := 0;
    FOR b IN 1 .. 16 LOOP
      l_soma := l_soma + TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_e, b, 1)), 'XX');
    END LOOP;
    l_ult := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_e, l_len, 1)), 'XX');

    l_k := aes_sha(l_e, CASE MOD(l_soma, 3) WHEN 0 THEN 256
                                            WHEN 1 THEN 384
                                            ELSE 512 END);

    l_i := l_i + 1;

    EXIT WHEN l_i >= 64 AND l_ult <= l_i - 32;
  END LOOP;

  RETURN UTL_RAW.SUBSTR(l_k, 1, 32);
END aes_hash_r6;

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

  l_p32 := UTL_RAW.CONCAT(
    UTL_RAW.CAST_FROM_BINARY_INTEGER(p_perms, UTL_RAW.LITTLE_ENDIAN),
    HEXTORAW('FFFFFFFF'),
    UTL_RAW.CAST_TO_RAW('Tadb'),
    HEXTORAW('00000000'));
  o_perms := aes_ecb_cifrar(p_chave, l_p32);
END aes_valores_r6;

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
subtype word is varchar2(80);
type tv4000a is table of varchar2(4000) index by word;
type point is record (x number, y number);
type tab_points is table of point index by pls_integer;
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
co_version CONSTANT VARCHAR2(10) := '3.4.0';
noParam tv4000a;

/**
 * PT: Prepara o gerador para um documento novo. Substitui o construtor legado
 *     fpdf(), acrescentando validação dos argumentos e os buffers em CLOB.
 *     Chamar de novo com um documento em andamento descarta o anterior.
 *
 * EN: Prepares the engine for a new document. Replaces the legacy fpdf()
 *     constructor, adding argument validation and the CLOB buffers. Calling it
 *     again discards the document in progress.
 *
 * @param p_orientation orientação da página / page orientation: 'P' (Portrait,
 *        retrato) ou 'L' (Landscape, paisagem)
 * @param p_unit unidade de medida / measurement unit ('mm', 'cm', 'in', 'pt')
 * @param p_format formato da página / page format ('A4', 'Letter', 'Legal')
 * @param p_encoding codificação de entrada / input encoding
 * @raises -20001 orientação inválida / invalid orientation
 * @raises -20002 unidade de medida inválida / invalid measurement unit
 * @raises -20003 codificação não suportada / unsupported encoding
 * @example
 *   PL_FPDF.Init('P', 'mm', 'A4');
 */
procedure Init(
  p_orientation varchar2 default 'P',
  p_unit varchar2 default 'mm',
  p_format varchar2 default 'A4',
  p_encoding varchar2 default 'UTF-8'
);

/**
 * PT: Devolve o package ao estado inicial: libera os CLOBs temporários e
 *     esvazia todas as tabelas de estado (fontes, imagens, links, metadados,
 *     mudanças de orientação). O package tem estado de sessão, e quem gera
 *     documentos em lote precisa chamar isto entre um e outro — sem isso, a
 *     configuração de um vaza para o seguinte.
 *
 * EN: Returns the package to its initial state: frees the temporary CLOBs and
 *     empties every state table (fonts, images, links, metadata, orientation
 *     changes). Package state is per session, so batch callers must call this
 *     between documents or one leaks into the next.
 *
 * @example
 *   PL_FPDF.Reset;
 */
procedure Reset;

/**
 * PT: Diz se Init (ou fpdf) já foi chamado nesta sessão.
 *
 * EN: Tells whether Init (or fpdf) has already been called in this session.
 *
 * @return BOOLEAN - TRUE se inicializado / TRUE when initialized
 * @example
 *   IF NOT PL_FPDF.IsInitialized THEN PL_FPDF.Init; END IF;
 */
function IsInitialized return boolean
  DETERMINISTIC;
type recPageFormat is record (
  width number(10,5),
  height number(10,5)
);
type recPage is record (
  number_val pls_integer,
  orientation varchar2(1),
  format recPageFormat,
  rotation pls_integer default 0,
  content_clob clob,
  created_at timestamp default systimestamp
);
type tPages is table of recPage index by pls_integer;
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
  loaded_at timestamp default systimestamp,
  bbox_xmin number default 0,
  bbox_ymin number default 0,
  bbox_xmax number default 0,
  bbox_ymax number default 0,
  italic_angle number default 0,
  flags pls_integer default 32,
  larguras varchar2(1024)
);
type tTTFFonts is table of recTTFFont index by varchar2(100);

/**
 * PT: Registra uma fonte TrueType a partir de um BLOB e a deixa disponível
 *     para o SetFont, pelo nome dado aqui. As tabelas do arquivo são lidas de
 *     verdade -- head, hhea, hmtx, cmap, OS/2 e post --, e a fonte vai
 *     embutida no PDF como /FontFile2. O arquivo cresce: o programa da fonte
 *     sai em hexadecimal, então ocupa o DOBRO do tamanho dela, e ainda não há
 *     subset (ver docs/ROADMAP.md). Para texto em português com acento não é
 *     preciso embutir nada: as fontes padrão escrevem acentuado desde a 3.4.0.
 *
 * EN: Registers a TrueType font from a BLOB and makes it available to SetFont
 *     under the name given here. The file's tables are really parsed -- head,
 *     hhea, hmtx, cmap, OS/2 and post -- and the font is embedded in the PDF
 *     as /FontFile2. The file grows: the font program goes out as hexadecimal,
 *     so it takes TWICE its size, and there is no subsetting yet (see
 *     docs/ROADMAP.md). Accented Portuguese needs no embedded font: the core
 *     fonts handle it since 3.4.0.
 *
 * @param p_font_name nome pelo qual SetFont a chamará / name used by SetFont
 * @param p_font_blob o arquivo .ttf / the .ttf file
 * @param p_encoding codificação da fonte / font encoding
 * @param p_embed embutir no PDF / embed in the PDF
 * @raises -20210 nome da fonte vazio / font name is null or empty
 * @raises -20211 BLOB da fonte nulo / font BLOB is null
 * @example
 *   SELECT arquivo INTO l_ttf FROM fontes WHERE nome = 'Roboto';
 *   PL_FPDF.AddTTFFont('Roboto', l_ttf);
 */
procedure AddTTFFont(
  p_font_name varchar2,
  p_font_blob blob,
  p_encoding varchar2 default 'UTF-8',
  p_embed boolean default true
);

/**
 * PT: Lê um .ttf de um DIRECTORY do banco e o registra como o AddTTFFont.
 *     Exige READ no diretório concedido ao schema; sem isso, AddTTFFont recebe
 *     os bytes direto, sem concessão nenhuma.
 *
 * EN: Reads a .ttf from a database DIRECTORY and registers it like AddTTFFont.
 *     Requires READ on that directory; without it, AddTTFFont takes the bytes
 *     directly, with no grant at all.
 *
 * @param p_font_name nome pelo qual SetFont a chamará / name used by SetFont
 * @param p_file_path nome do arquivo / file name
 * @param p_directory DIRECTORY do banco / database DIRECTORY object
 * @param p_encoding codificação da fonte / font encoding
 * @raises -20202 arquivo de fonte inválido / invalid font file
 * @raises -20401 diretório inválido / invalid directory
 * @raises -20402 sem permissão de leitura / read access denied
 * @example
 *   PL_FPDF.LoadTTFFromFile('Roboto', 'Roboto-Regular.ttf', 'FONTS_DIR');
 */
procedure LoadTTFFromFile(
  p_font_name varchar2,
  p_file_path varchar2,
  p_directory varchar2 default 'FONTS_DIR',
  p_encoding varchar2 default 'UTF-8'
);

/**
 * PT: Diz se a fonte está registrada nesta sessão, e portanto disponível para
 *     o SetFont. O nome não diferencia maiúsculas de minúsculas.
 *
 * EN: Tells whether the font is registered in this session, and therefore
 *     available to SetFont. The name is case-insensitive.
 *
 * @param p_font_name nome da fonte / font name
 * @return BOOLEAN - TRUE se carregada / TRUE when loaded
 * @example
 *   IF NOT PL_FPDF.IsTTFFontLoaded('Roboto') THEN ... END IF;
 */
function IsTTFFontLoaded(p_font_name varchar2) return boolean;

/**
 * PT: Devolve o registro da fonte: os bytes guardados e as métricas lidas do
 *     arquivo -- unidades por em, ascendente, descendente, altura de caixa
 *     alta, a caixa e o ângulo do itálico. Tudo já reescalado para as 1000
 *     unidades por em do PDF, menos o units_per_em, que é o do arquivo.
 *
 * EN: Returns the font record: the stored bytes and the metrics parsed from
 *     the file -- units per em, ascent, descent, cap height, the box and the
 *     italic angle. All rescaled to the PDF's 1000 units per em, except
 *     units_per_em itself, which is the file's.
 *
 * @param p_font_name nome da fonte / font name
 * @return recTTFFont - as métricas da fonte / the font metrics
 * @raises -20206 fonte não carregada / font not loaded
 * @example
 *   l_fonte := PL_FPDF.GetTTFFontInfo('Roboto');
 */
function GetTTFFontInfo(p_font_name varchar2) return recTTFFont;

/**
 * PT: Descarrega as fontes TrueType e libera os LOBs temporários delas. Vale
 *     chamar ao fim de um lote: cada fonte embutida ocupa centenas de KB na
 *     sessão.
 *
 * EN: Unloads the TrueType fonts and frees their temporary LOBs. Worth calling
 *     at the end of a batch: each embedded font holds hundreds of KB in the
 *     session.
 *
 * @example
 *   PL_FPDF.ClearTTFFontCache;
 */
procedure ClearTTFFontCache;

/**
 * PT: Escapa os caracteres que a sintaxe de string do PDF reserva -- o
 *     parêntese e a barra invertida. NÃO converte codificação: quem escreve
 *     texto pelas rotinas normais (Cell, Write, Text) não precisa chamar isto,
 *     porque a conversão para WinAnsi já acontece lá dentro.
 *
 * EN: Escapes the characters reserved by the PDF string syntax -- parenthesis
 *     and backslash. It does NOT convert encoding: callers of the normal text
 *     routines (Cell, Write, Text) need not call this, since the WinAnsi
 *     conversion already happens inside them.
 *
 * @param p_text o texto / the text
 * @param p_escape escapar os caracteres reservados / escape reserved
 *        characters
 * @return VARCHAR2 - o texto pronto para ir entre parênteses num objeto PDF /
 *         text ready to sit inside parentheses in a PDF object
 * @example
 *   l_txt := PL_FPDF.UTF8ToPDFString('Total (liquido)');
 */
function UTF8ToPDFString(
  p_text varchar2,
  p_escape boolean default true
) return varchar2;
exc_invalid_orientation EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_orientation, -20001);
exc_invalid_unit EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_unit, -20002);
exc_invalid_encoding EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_encoding, -20003);
exc_not_initialized EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_not_initialized, -20005);
exc_invalid_page_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_page_format, -20101);
exc_page_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_page_not_found, -20106);
exc_font_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_font_not_found, -20201);
exc_invalid_font_file EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_file, -20202);
exc_invalid_font_name EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_name, -20210);
exc_invalid_font_blob EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_font_blob, -20211);
exc_fora_de_winansi EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_fora_de_winansi, -20203);
exc_invalid_image EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_image, -20301);
exc_image_not_found EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_image_not_found, -20302);
exc_unsupported_image_format EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_unsupported_image_format, -20303);
exc_invalid_directory EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_directory, -20401);
exc_file_access_denied EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_access_denied, -20402);
exc_file_write_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_file_write_error, -20403);
exc_link_nao_suportado EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_link_nao_suportado, -20601);
exc_invalid_color EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_color, -20501);
exc_invalid_line_width EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_invalid_line_width, -20502);
exc_general_error EXCEPTION;
PRAGMA EXCEPTION_INIT(exc_general_error, -20100);

/**
 * PT: Devolve o corpo da fonte em uso, em pontos.
 *
 * EN: Returns the current font size, in points.
 *
 * @return NUMBER - o tamanho em pontos / size in points
 * @example
 *   l_corpo := PL_FPDF.GetCurrentFontSize;
 */
function GetCurrentFontSize return number;

/**
 * PT: Devolve o estilo em uso: '' (normal), 'B' (Bold, negrito), 'I' (Italic,
 *     itálico), 'U' (Underline, sublinhado) ou a combinação. Sempre em
 *     MAIÚSCULA: o SetFont normaliza, então 'b' entra e 'B' volta.
 *
 * EN: Returns the current style: '' (regular), 'B' (bold), 'I' (italic), 'U'
 *     (underline), or a combination. Always UPPERCASE: SetFont normalises it,
 *     so 'b' goes in and 'B' comes back.
 *
 * @return VARCHAR2 - o estilo corrente / the current style
 * @example
 *   l_estilo := PL_FPDF.GetCurrentFontStyle;
 */
function GetCurrentFontStyle return varchar2;

/**
 * PT: Devolve o nome da família em uso. Sempre em MINÚSCULA: o SetFont
 *     normaliza, então 'Times' entra e 'times' volta. Comparar com 'Times'
 *     nunca casa -- use LOWER() dos dois lados.
 *
 * EN: Returns the current font family. Always LOWERCASE: SetFont normalises
 *     it, so 'Times' goes in and 'times' comes back. Comparing against 'Times'
 *     never matches -- use LOWER() on both sides.
 *
 * @return VARCHAR2 - a família corrente / the current family
 * @example
 *   l_familia := PL_FPDF.GetCurrentFontFamily;
 */
function GetCurrentFontFamily return varchar2;

/**
 * PT: Passa a desenhar linha tracejada, com o comprimento do traço e o do
 *     intervalo na unidade corrente. Os dois em zero voltam à linha cheia.
 *     Vale para tudo o que for desenhado depois, até ser trocado.
 *
 * EN: Switches to a dashed line, giving the dash and gap lengths in the
 *     current unit. Both at zero restores a solid line. It applies to
 *     everything drawn afterwards, until changed.
 *
 * @param pblack comprimento do traço / dash length
 * @param pwhite comprimento do intervalo / gap length
 * @example
 *   PL_FPDF.SetDash(2, 2);          -- tracejado / dashed
 *   PL_FPDF.Line(10, 50, 200, 50);
 *   PL_FPDF.SetDash;                -- volta à linha cheia / back to solid
 */
procedure SetDash(pblack in number default 0, pwhite in number default 0);

/**
 * PT: Devolve a entrelinha usada pelo MultiCell quando a altura da linha vai
 *     em branco.
 *
 * EN: Returns the line spacing MultiCell uses when the line height is left
 *     empty.
 *
 * @return NUMBER - a entrelinha, na unidade corrente / line spacing, current
 *         unit
 * @example
 *   l_entre := PL_FPDF.GetLineSpacing;
 */
function GetLineSpacing return number;

/**
 * PT: Define a entrelinha do MultiCell para quando a altura da linha não for
 *     informada.
 *
 * EN: Sets the line spacing MultiCell uses when no line height is given.
 *
 * @param pls a entrelinha, na unidade corrente / line spacing, current unit
 * @example
 *   PL_FPDF.SetLineSpacing(5);
 */
Procedure SetLineSpacing (pls in number);

/**
 * PT: Desenha um polígono ligando os pontos na ordem da tabela, que precisa
 *     começar no índice 0. Fechado, o último ponto liga de volta ao primeiro.
 *
 * EN: Draws a polygon joining the points in table order; the table must start
 *     at index 0. When closed, the last point joins back to the first.
 *
 * @param points os vértices, indexados a partir de 0 / vertices, indexed from
 *        0
 * @param pclose fechar o contorno / close the outline
 * @param pstyle '' desenha o contorno (padrão), 'F' preenche (Fill), 'FD' ou
 *        'DF' preenche e contorna (Fill and Draw) / '' outlines (default), 'F'
 *        fills, 'FD'/'DF' fills and outlines
 * @example
 *   l_pontos(0).x := 10; l_pontos(0).y := 10;
 *   l_pontos(1).x := 50; l_pontos(1).y := 10;
 *   l_pontos(2).x := 30; l_pontos(2).y := 40;
 *   PL_FPDF.Poly(l_pontos, TRUE, 'F');
 */
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');

/**
 * PT: Desenha um triângulo isósceles de base 2*psize e altura psize, com a
 *     ponta virada para porientation. (px, py) é o canto superior esquerdo da
 *     caixa que envolve o triângulo, e não o vértice.
 *
 * EN: Draws an isosceles triangle with base 2*psize and height psize, apex
 *     pointing towards porientation. (px, py) is the top-left corner of the
 *     bounding box, not the apex.
 *
 * @param px canto superior esquerdo da caixa / top-left of bounding box
 * @param py canto superior esquerdo da caixa / top-left of bounding box
 * @param psize metade da base, e a altura / half the base, and the height
 * @param porientation para onde aponta / where the apex points: 'up'/'U',
 *        'down'/'D', 'left'/'L', 'right'/'R'
 * @param pstyle '' contorna, 'F' preenche (Fill), 'FD'/'DF' os dois / ''
 *        outlines, 'F' fills, 'FD'/'DF' both
 * @raises -20821 orientação inválida / invalid orientation
 * @example
 *   PL_FPDF.Triangle(20, 20, 5, 'right', 'F');
 */
procedure Triangle(px in number, py in number, psize in number,
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

/**
 * PT: Escreve o operador 'd' do PDF direto no fluxo de conteúdo, para quem
 *     precisa de um padrão que o SetDash não monta. O texto vai como está, e
 *     um padrão malformado só aparece no leitor. Prefira SetDash.
 *
 * EN: Writes the PDF 'd' operator straight into the content stream, for
 *     patterns SetDash cannot build. The text goes through verbatim, and a
 *     malformed pattern only shows up in the reader. Prefer SetDash.
 *
 * @param pdash o padrão, na sintaxe do PDF / the pattern in PDF syntax ('[] 0'
 *        = linha cheia / solid)
 * @example
 *   PL_FPDF.SetLineDashPattern('[3 2] 0');
 */
procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

/**
 * PT: Vai para a linha seguinte: leva o x de volta à margem esquerda e desce o
 *     y. Sem altura, desce o da última célula escrita.
 *
 * EN: Moves to the next line: x goes back to the left margin and y moves down.
 *     With no height given, it uses the last cell's height.
 *
 * @param h quanto descer, na unidade corrente / how far down, in the current
 *        unit
 * @example
 *   PL_FPDF.Cell(40, 10, 'Primeira');
 *   PL_FPDF.Ln;
 */
procedure Ln(h number default null);

/**
 * PT: Devolve a abscissa corrente, na unidade em uso.
 *
 * EN: Returns the current abscissa, in the current unit.
 *
 * @return NUMBER - o x corrente / the current x
 * @example
 *   l_x := PL_FPDF.GetX;
 */
function  GetX return number;

/**
 * PT: Move a abscissa. Valor negativo conta a partir da borda direita:
 *     SetX(-30) põe o cursor a 30 da direita.
 *
 * EN: Moves the abscissa. A negative value counts from the right edge:
 *     SetX(-30) puts the cursor 30 from the right.
 *
 * @param px a nova abscissa / the new abscissa
 * @example
 *   PL_FPDF.SetX(-40);
 */
procedure SetX(px in number);

/**
 * PT: Devolve a ordenada corrente, contada do topo da página.
 *
 * EN: Returns the current ordinate, measured from the top of the page.
 *
 * @return NUMBER - o y corrente / the current y
 * @example
 *   l_y := PL_FPDF.GetY;
 */
function  GetY return number;

/**
 * PT: Move a ordenada E devolve o x à margem esquerda -- é o efeito que
 *     surpreende quem só queria descer. Para mover os dois sem esse efeito,
 *     use SetXY. Valor negativo conta a partir do pé da página.
 *
 * EN: Moves the ordinate AND resets x to the left margin -- the surprise for
 *     callers who only meant to move down. To move both without that, use
 *     SetXY. A negative value counts from the bottom of the page.
 *
 * @param py a nova ordenada / the new ordinate
 * @example
 *   PL_FPDF.SetY(-20);   -- 20 acima do pé / 20 above the bottom
 */
procedure SetY(py in number);

/**
 * PT: Move as duas coordenadas. Ao contrário do SetY sozinho, o x informado é
 *     respeitado.
 *
 * EN: Moves both coordinates. Unlike SetY on its own, the x given here is
 *     honoured.
 *
 * @param x a abscissa / the abscissa
 * @param y a ordenada / the ordinate
 * @example
 *   PL_FPDF.SetXY(20, 50);
 */
procedure SetXY(x in number,y in number);

/**
 * PT: Registra o NOME de uma rotina que será executada no início de cada
 *     página. O nome e os nomes dos parâmetros são validados como
 *     identificadores SQL (DBMS_ASSERT) aqui, na configuração -- e não no meio
 *     do relatório, que é onde um nome inválido apareceria. O bloco é montado
 *     uma vez só, e não a cada página.
 *
 * EN: Registers the NAME of a routine to run at the start of every page. The
 *     name and the parameter names are validated as SQL identifiers
 *     (DBMS_ASSERT) here, at configuration time, rather than halfway through
 *     the report. The block is built once, not per page.
 *
 * @param headerprocname nome da rotina / routine name (NULL desliga /
 *        disables)
 * @param paramTable parâmetros nomeados / named parameters
 * @example
 *   PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');
 */
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam);

/**
 * PT: Como SetHeaderProc, para o rodapé: a rotina é executada ao fechar cada
 *     página, e é onde costuma entrar o "página N de {nb}".
 *
 * EN: Like SetHeaderProc, for the footer: the routine runs as each page is
 *     closed, and is where "page N of {nb}" usually goes.
 *
 * @param footerprocname nome da rotina / routine name (NULL desliga /
 *        disables)
 * @param paramTable parâmetros nomeados / named parameters
 * @example
 *   PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');
 */
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam);

/**
 * PT: Define as margens esquerda, superior e direita. A direita em branco fica
 *     igual à esquerda.
 *
 * EN: Sets the left, top and right margins. Leaving the right one out makes it
 *     equal to the left.
 *
 * @param left margem esquerda / left margin
 * @param top margem superior / top margin
 * @param right margem direita / right margin (-1 = igual à esquerda / same as
 *        left)
 * @example
 *   PL_FPDF.SetMargins(20, 15);
 */
procedure SetMargins(left in number, top in number, right in number default -1);

/**
 * PT: Define a margem esquerda. Com página já aberta e o cursor à esquerda da
 *     margem nova, o cursor é trazido para ela.
 *
 * EN: Sets the left margin. With a page already open and the cursor to the
 *     left of the new margin, the cursor is moved onto it.
 *
 * @param pMargin a margem, na unidade corrente / the margin, in the current
 *        unit
 * @example
 *   PL_FPDF.SetLeftMargin(25);
 */
procedure SetLeftMargin(pMargin in number);

/**
 * PT: Define a margem superior, usada pelas páginas seguintes.
 *
 * EN: Sets the top margin, used by the pages that follow.
 *
 * @param pMargin a margem, na unidade corrente / the margin, in the current
 *        unit
 * @example
 *   PL_FPDF.SetTopMargin(15);
 */
procedure SetTopMargin(pMargin in number);

/**
 * PT: Define a margem direita, que é o que limita a largura de uma célula
 *     pedida com largura 0.
 *
 * EN: Sets the right margin, which is what bounds a cell asked for with width
 *     0.
 *
 * @param pMargin a margem, na unidade corrente / the margin, in the current
 *        unit
 * @example
 *   PL_FPDF.SetRightMargin(20);
 */
procedure SetRightMargin(pMargin in number);

/**
 * PT: Liga ou desliga a quebra automática e define a margem de rodapé que a
 *     dispara. Desligada, o conteúdo que passar do fim da página é escrito
 *     fora dela e some -- sem erro nenhum.
 *
 * EN: Turns automatic page breaking on or off and sets the bottom margin that
 *     triggers it. With it off, content past the end of the page is written
 *     outside it and disappears -- with no error at all.
 *
 * @param pauto ligar a quebra automática / enable automatic breaking
 * @param pMargin margem de rodapé que dispara / bottom margin that triggers it
 * @example
 *   PL_FPDF.SetAutoPageBreak(TRUE, 20);
 */
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0);

/**
 * PT: Diz ao leitor de PDF como abrir o documento. É preferência de
 *     apresentação: o leitor pode ignorar.
 *
 * EN: Tells the PDF reader how to open the document. It is a presentation
 *     hint: the reader may ignore it.
 *
 * @param zoom 'fullpage' (página inteira), 'fullwidth' (largura da página),
 *        'real' (tamanho real), 'default' (padrão do leitor), ou um número que
 *        é o percentual de ampliação / 'fullpage', 'fullwidth', 'real',
 *        'default', or a number taken as a zoom percentage
 * @param layout 'single' (uma página), 'continuous' (contínuo), 'two' (duas
 *        colunas), 'default' (padrão do leitor) / 'single', 'continuous',
 *        'two', 'default'
 * @raises -20100 modo de zoom ou de layout desconhecido / unknown zoom or
 *         layout mode
 * @example
 *   PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
 */
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous');

/**
 * PT: Liga a compressão dos fluxos de conteúdo. Até agosto/2026 isto não fazia
 *     nada -- procurava uma rotina de zlib que o Oracle não tem e desligava
 *     sempre. Hoje o deflate está escrito no próprio pacote
 *     (PL_FPDF_UTIL.deflate) e a opção vale.
 *
 * EN: Turns on content-stream compression. Until August 2026 this did nothing
 *     -- it looked for a zlib routine Oracle does not have and always turned
 *     compression off. Deflate now lives in the package itself
 *     (PL_FPDF_UTIL.deflate) and the setting has effect.
 *
 * @param p_compress comprimir os fluxos / compress the streams
 * @example
 *   PL_FPDF.SetCompression(TRUE);
 */
procedure SetCompression(p_compress in boolean default false);

/**
 * PT: Grava o título nos metadados do PDF -- o que o leitor mostra na barra de
 *     título e o que o buscador indexa.
 *
 * EN: Records the title in the PDF metadata -- what the reader shows in its
 *     title bar and what search engines index.
 *
 * @param ptitle o título / the title
 * @example
 *   PL_FPDF.SetTitle('Relatório de Produção');
 */
procedure SetTitle(ptitle in varchar2);

/**
 * PT: Grava o assunto nos metadados do PDF.
 *
 * EN: Records the subject in the PDF metadata.
 *
 * @param psubject o assunto / the subject
 * @example
 *   PL_FPDF.SetSubject('Fechamento mensal');
 */
procedure SetSubject(psubject in varchar2);

/**
 * PT: Grava o autor nos metadados do PDF.
 *
 * EN: Records the author in the PDF metadata.
 *
 * @param pauthor o autor / the author
 * @example
 *   PL_FPDF.SetAuthor('Departamento Financeiro');
 */
procedure SetAuthor(pauthor in varchar2);

/**
 * PT: Grava as palavras-chave nos metadados do PDF, separadas por espaço.
 *
 * EN: Records the keywords in the PDF metadata, separated by spaces.
 *
 * @param pkeywords as palavras-chave / the keywords
 * @example
 *   PL_FPDF.SetKeywords('relatorio producao 2026');
 */
procedure SetKeywords(pkeywords in varchar2);

/**
 * PT: Grava, nos metadados, o nome do sistema que gerou o documento.
 *
 * EN: Records, in the metadata, the name of the system that produced the
 *     document.
 *
 * @param pcreator o sistema gerador / the producing system
 * @example
 *   PL_FPDF.SetCreator('ERP - modulo de faturamento');
 */
procedure SetCreator(pcreator in varchar2);

/**
 * PT: Define o texto que será trocado pelo total de páginas na hora de fechar
 *     o documento. É como se escreve "página 3 de 12" sem saber o 12 enquanto
 *     se escreve a página 3.
 *
 * EN: Sets the placeholder to be replaced by the page count when the document
 *     is closed. It is how "page 3 of 12" gets written without knowing the 12
 *     while page 3 is being written.
 *
 * @param palias o marcador / the placeholder
 * @example
 *   PL_FPDF.SetAliasNbPages;
 *   PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo || ' de {nb}');
 */
procedure SetAliasNbPages(palias in varchar2 default '{nb}');

/**
 * PT: Executa a rotina registrada em SetHeaderProc. É chamada sozinha ao abrir
 *     cada página; não se chama à mão.
 *
 * EN: Runs the routine registered with SetHeaderProc. It is called on its own
 *     as each page opens; it is not meant to be called by hand.
 *
 * @example
 *   PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');   -- e o resto é automático
 */
procedure Header;

/**
 * PT: Executa a rotina registrada em SetFooterProc. É chamada sozinha ao
 *     fechar cada página; não se chama à mão.
 *
 * EN: Runs the routine registered with SetFooterProc. It is called on its own
 *     as each page closes; it is not meant to be called by hand.
 *
 * @example
 *   PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');      -- e o resto é automático
 */
procedure Footer;

/**
 * PT: Devolve o número da página que está sendo escrita, começando em 1.
 *
 * EN: Returns the number of the page being written, starting at 1.
 *
 * @return NUMBER - a página corrente / the current page
 * @example
 *   PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo);
 */
function  PageNo return number;

/**
 * PT: Define a cor com que se desenham linhas, contornos e bordas de célula.
 *     Com um argumento só, é tom de cinza (0 preto, 255 branco); com três, é
 *     RGB. Vale do ponto em que é chamada em diante.
 *
 * EN: Sets the colour used for lines, outlines and cell borders. With one
 *     argument it is a grey level (0 black, 255 white); with three it is RGB.
 *     It applies from the call onwards.
 *
 * @param r vermelho, ou o nível de cinza / red, or the grey level (0..255)
 * @param g verde / green (0..255)
 * @param b azul / blue (0..255)
 * @raises -20501 componente fora de 0..255 / component outside 0..255
 * @example
 *   PL_FPDF.SetDrawColor(200);            -- cinza claro / light grey
 *   PL_FPDF.SetDrawColor(0, 90, 160);     -- azul / blue
 */
procedure SetDrawColor(r in number, g in number default -1, b in number default -1);

/**
 * PT: Define a cor de fundo das células preenchidas e das formas com estilo
 *     'F'. Um argumento é cinza, três são RGB.
 *
 * EN: Sets the background colour of filled cells and of shapes drawn with
 *     style 'F'. One argument is grey, three are RGB.
 *
 * @param r vermelho, ou o nível de cinza / red, or the grey level (0..255)
 * @param g verde / green (0..255)
 * @param b azul / blue (0..255)
 * @raises -20501 componente fora de 0..255 / component outside 0..255
 * @example
 *   PL_FPDF.SetFillColor(230, 230, 230);
 *   PL_FPDF.Cell(40, 8, 'Cabecalho', '1', 0, 'C', 1);
 */
procedure SetFillColor (r in number, g in number default -1, b in number default -1);

/**
 * PT: Define a cor do texto. Um argumento é cinza, três são RGB.
 *
 * EN: Sets the text colour. One argument is grey, three are RGB.
 *
 * @param r vermelho, ou o nível de cinza / red, or the grey level (0..255)
 * @param g verde / green (0..255)
 * @param b azul / blue (0..255)
 * @raises -20501 componente fora de 0..255 / component outside 0..255
 * @example
 *   PL_FPDF.SetTextColor(180, 0, 0);
 */
procedure SetTextColor (r in number, g in number default -1, b in number default -1);

/**
 * PT: Define a espessura do traço, na unidade corrente.
 *
 * EN: Sets the line width, in the current unit.
 *
 * @param width a espessura, maior que zero / the width, greater than zero
 * @raises -20502 espessura zero ou negativa / width is zero or negative
 * @example
 *   PL_FPDF.SetLineWidth(0.5);
 */
procedure SetLineWidth(width in number);

/**
 * PT: Desenha um segmento de reta entre dois pontos, com a cor e a espessura
 *     correntes.
 *
 * EN: Draws a straight segment between two points, using the current colour
 *     and width.
 *
 * @param x1 ponto inicial / start point
 * @param y1 ponto inicial / start point
 * @param x2 ponto final / end point
 * @param y2 ponto final / end point
 * @example
 *   PL_FPDF.Line(20, 60, 190, 60);
 */
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number);

/**
 * PT: Desenha um retângulo a partir do canto superior esquerdo.
 *
 * EN: Draws a rectangle from its top-left corner.
 *
 * @param px canto superior esquerdo / top-left corner
 * @param py canto superior esquerdo / top-left corner
 * @param pw largura / width
 * @param ph altura / height
 * @param pstyle '' contorna (padrão), 'F' preenche (Fill), 'FD' ou 'DF'
 *        preenche e contorna (Fill and Draw) / '' outlines (default), 'F'
 *        fills, 'FD'/'DF' fills and outlines
 * @example
 *   PL_FPDF.Rect(20, 40, 60, 25, 'FD');
 */
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '');

/**
 * PT: RECUSA com -20601. Criaria um link interno, e link interno não está
 *     implementado: o /Dest nunca chegou a ser escrito no arquivo, então o
 *     identificador que esta função devolveria não levaria a lugar nenhum -- e
 *     o Link o recusa. Até setembro/2026 a chamada levantava ORA-06531,
 *     "reference to uninitialized collection", porque a coleção interna nunca
 *     foi inicializada: nunca funcionou, em nenhuma versão. Passa a recusar
 *     com mensagem que diz o que usar no lugar.
 *
 * EN: REFUSES with -20601. It would create an internal link, and internal
 *     links are not implemented: the /Dest was never written to the file, so
 *     the identifier this function would return leads nowhere -- and Link
 *     refuses it. Until September 2026 the call raised ORA-06531, "reference
 *     to uninitialized collection", because the internal collection was never
 *     initialised: it never worked, in any version. It now refuses with a
 *     message that says what to use instead.
 *
 * @return NUMBER - nunca devolve: levanta antes / never returns: it raises
 *         first
 * @raises -20601 link interno não implementado / internal links not
 *         implemented
 * @example
 *   -- Use URL / use a URL:
 *   PL_FPDF.Cell(60, 8, 'Site', plink => 'https://example.com');
 */
function  AddLink return number;

/**
 * PT: RECUSA com -20601, pelo mesmo motivo do AddLink: guardar o destino não
 *     adiantaria, porque o /Dest não é emitido e ninguém o lê. Até
 *     setembro/2026 levantava ORA-06531.
 *
 * EN: REFUSES with -20601, for the same reason as AddLink: storing the
 *     destination would achieve nothing, since the /Dest is never emitted and
 *     nobody reads it. Until September 2026 it raised ORA-06531.
 *
 * @param plink identificador devolvido por AddLink / identifier from AddLink
 * @param py ordenada de chegada / destination ordinate (-1 = a posição
 *        corrente / the current position)
 * @param ppage página de chegada / destination page (-1 = a página corrente /
 *        the current page)
 * @raises -20601 link interno não implementado / internal links not
 *         implemented
 * @example
 *   -- Use URL / use a URL:
 *   PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
 */
procedure SetLink(plink in number, py in number default 0, ppage in number default -1);

/**
 * PT: Marca uma área retangular como clicável, levando a uma URL.
 *
 * EN: Marks a rectangular area as clickable, pointing at a URL.
 *
 * @param px canto superior esquerdo da área / top-left of the area
 * @param py canto superior esquerdo da área / top-left of the area
 * @param pw largura / width
 * @param ph altura / height
 * @param plink a URL / the URL
 * @limitation PT: 1. Uma área por página. Uma segunda chamada na mesma página
 *             substitui a primeira, em silêncio -- a estrutura guarda um
 *             registro por página. Documentado por ser assim, não por ser o
 *             desejável. 2. Link interno não é suportado, e é RECUSADO com
 *             -20601. O ramo que escreveria o /Dest saiu comentado no porte
 *             original e nunca voltou; emiti-lo assim produzia um /Annot com o
 *             dicionário aberto, isto é, arquivo malformado. Desde
 *             setembro/2026 a chamada levanta erro em vez de gravar o arquivo
 *             quebrado. Use URL.
 * @limitation EN: 1. One area per page. A second call on the same page
 *             silently replaces the first -- the structure holds one record
 *             per page. Documented because that is how it behaves, not because
 *             it is desirable. 2. Internal links are not supported and are
 *             REFUSED with -20601. The branch that would write the /Dest was
 *             commented out in the original port and never came back; emitting
 *             it as it stood produced an /Annot with an open dictionary, i.e.
 *             a malformed file. Since September 2026 the call raises instead
 *             of writing the broken file. Use a URL.
 * @example
 *   PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
 * @raises -20601 destino não é URL -- link interno ou NULL / destination is
 *         not a URL -- internal link or NULL
 */
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2);

/**
 * PT: Escreve texto num ponto exato, sem célula, sem quebra e sem mover o
 *     cursor. (px, py) é a LINHA DE BASE do texto, não o topo dele.
 *
 * EN: Writes text at an exact point, with no cell, no wrapping and no cursor
 *     movement. (px, py) is the text BASELINE, not its top.
 *
 * @param px a linha de base / the baseline
 * @param py a linha de base / the baseline
 * @param ptxt o texto / the text
 * @raises -20203 caractere fora do WinAnsi / character outside WinAnsi
 * @example
 *   PL_FPDF.Text(20, 50, 'Endereço de cobrança');
 */
procedure Text(px in number, py in number, ptxt in varchar2);

/**
 * PT: Diz se a quebra automática está ligada. É consultada pelo Cell antes de
 *     decidir abrir página nova.
 *
 * EN: Tells whether automatic page breaking is on. Cell consults it before
 *     deciding to start a new page.
 *
 * @return BOOLEAN - TRUE se a quebra automática está ligada / TRUE when
 *         automatic breaking is on
 * @example
 *   IF PL_FPDF.AcceptPageBreak THEN ... END IF;
 */
function  AcceptPageBreak return boolean;

/**
 * PT: Registra uma fonte para uso pelo SetFont. Para as 14 fontes padrão do
 *     PDF não é preciso chamar isto -- elas já estão disponíveis, e escrevem
 *     acentuado desde a 3.4.0.
 *
 * EN: Registers a font for SetFont to use. The 14 standard PDF fonts need no
 *     such call -- they are always available, and write accented text since
 *     3.4.0.
 *
 * @param family nome da família / family name
 * @param style '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'BI' os
 *        dois / '' regular, 'B' bold, 'I' italic, 'BI' both
 * @param filename arquivo de métricas da fonte / the font metrics file
 * @example
 *   PL_FPDF.AddFont('Arial', 'B');
 */
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '');

/**
 * PT: Escolhe a fonte, o estilo e o corpo do texto que vier depois. Corpo zero
 *     mantém o que já estava. As fontes padrão -- Helvetica, Times, Courier,
 *     Symbol e ZapfDingbats -- não precisam ser carregadas.
 *
 * EN: Chooses the font, style and size for the text that follows. A size of
 *     zero keeps the current one. The standard fonts -- Helvetica, Times,
 *     Courier, Symbol and ZapfDingbats -- need no loading.
 *
 * @param pfamily família / family ('Helvetica', 'Times', 'Courier'...)
 * @param pstyle '' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'U'
 *        sublinhado (Underline), ou a combinação / '' regular, 'B' bold, 'I'
 *        italic, 'U' underline, or a mix
 * @param psize corpo em pontos / size in points (0 = mantém / keep current)
 * @note PT: A família é guardada em minúscula e o estilo em maiúscula. É o que
 *       os getters devolvem, e não o texto que entrou aqui.
 * @note EN: The family is stored lowercase and the style uppercase. That is
 *       what the getters return -- not the text passed in here.
 * @raises -20005 Init ainda não foi chamado / Init has not been called
 * @raises -20201 fonte não encontrada -- nem entre as padrão, nem no registro
 *         de TrueType / font not found -- neither a core font nor a registered
 *         TrueType one
 * @raises -20100 estilo inválido / invalid style
 * @example
 *   PL_FPDF.SetFont('Helvetica', 'B', 12);
 */
procedure SetFont(pfamily in varchar2,pstyle in varchar2 default '', psize in number default 0);

/**
 * PT: Mede quanto o texto ocupa na fonte e no corpo correntes, na unidade em
 *     uso. É o que permite alinhar, centralizar e decidir onde quebrar.
 *     Caractere acentuado mede o mesmo que o caractere base -- nas 14 fontes
 *     padrão do PDF o glifo acentuado tem a mesma largura de avanço.
 *
 * EN: Measures how much room the text takes in the current font and size, in
 *     the current unit. It is what makes alignment, centring and line breaking
 *     possible. An accented character measures the same as its base: in the 14
 *     standard PDF fonts the accented glyph has the same advance width.
 *
 * @param pstr o texto a medir / the text to measure
 * @return NUMBER - a largura, na unidade corrente / the width, in the current
 *         unit
 * @raises -20203 caractere fora do WinAnsi / character outside WinAnsi
 * @example
 *   l_larg := PL_FPDF.GetStringWidth('São Paulo');
 */
function GetStringWidth(pstr in varchar2) return number;

/**
 * PT: Troca só o corpo, mantendo família e estilo.
 *
 * EN: Changes the size alone, keeping family and style.
 *
 * @param psize corpo em pontos / size in points
 * @example
 *   PL_FPDF.SetFontSize(8);
 */
procedure SetFontSize(psize in number);

/**
 * PT: Escreve uma célula retangular: opcionalmente com borda, com fundo e com
 *     texto dentro, e move o cursor conforme pln. É a rotina mais usada da
 *     biblioteca. Se a célula não couber no que resta da página e a quebra
 *     automática estiver ligada, a página é trocada antes de escrever.
 *
 * EN: Writes a rectangular cell: optionally bordered, filled and with text
 *     inside, then moves the cursor according to pln. It is the library's most
 *     used routine. If the cell does not fit in what is left of the page and
 *     automatic breaking is on, the page is turned first.
 *
 * @param pw largura; 0 vai até a margem direita / width; 0 spans to the right
 *        margin
 * @param ph altura / height
 * @param ptxt o texto / the text
 * @param pborder '0' sem borda, '1' moldura inteira, ou a combinação de 'L'
 *        (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B'
 *        (Bottom, base) / '0' none, '1' full frame, or a mix of 'L', 'T', 'R',
 *        'B'
 * @param pln para onde vai o cursor / where the cursor goes:
 *        0 = à direita da célula / to the right of the cell
 *        1 = próxima linha, na margem esquerda / next line, at the left margin
 *        2 = abaixo, mantendo o x / below, keeping x
 * @param palign 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right,
 *        direita)
 * @param pfill 1 pinta o fundo com a cor de SetFillColor, 0 não / 1 paints the
 *        background with SetFillColor's colour, 0 does not
 * @param plink URL ou identificador de link interno / URL or internal link id
 * @raises -20100 qualquer falha na escrita da célula. O Cell embrulha o erro
 *         original neste código, mas preserva a pilha (keeperrorstack), de
 *         modo que a causa -- um ORA-20203 de caractere fora do WinAnsi, por
 *         exemplo -- continua visível no rastro. / any failure while writing
 *         the cell. Cell wraps the original error in this code but keeps the
 *         stack (keeperrorstack), so the cause -- an ORA-20203 for a character
 *         outside WinAnsi, say -- stays visible in the backtrace.
 * @example
 *   PL_FPDF.Cell(40, 8, 'Total', '1', 0, 'L');
 *   PL_FPDF.Cell(30, 8, '1.234,56', '1', 1, 'R');
 */
procedure Cell
  (pw in number,
    ph in number default 0,
    ptxt in varchar2 default '',
    pborder in varchar2 default '0',
    pln in number default 0,
    palign in varchar2 default '',
    pfill in number default 0,
    plink in varchar2 default '');

/**
 * PT: Escreve um bloco de texto que quebra sozinho na largura pedida, uma
 *     célula por linha, e devolve quantas linhas saíram. A quebra respeita o
 *     espaço entre palavras e a quebra explícita (CHR(10)). Esta é a versão
 *     FUNCTION, para quem precisa saber quantas linhas foram gastas -- para
 *     calcular a altura de uma tabela, tipicamente.
 *
 * EN: Writes a block of text that wraps by itself to the given width, one cell
 *     per line, and returns how many lines it produced. Wrapping respects word
 *     spaces and explicit breaks (CHR(10)). This is the FUNCTION form, for
 *     callers who need the line count -- to work out the height of a table
 *     row, typically.
 *
 * @param pw largura do bloco; 0 vai até a margem direita / block width; 0
 *        spans to the right margin
 * @param ph altura de cada linha; em branco usa a entrelinha de SetLineSpacing
 *        / height of each line; empty uses SetLineSpacing
 * @param ptxt o texto / the text
 * @param pborder '0' sem borda, '1' moldura, ou 'L','T','R','B' / '0' none,
 *        '1' frame, or 'L','T','R','B'
 * @param palign 'J' justificado (Justified, padrão), 'L' (Left, esquerda), 'C'
 *        (Center, centro), 'R' (Right, direita) / 'J' justified (default),
 *        'L', 'C', 'R'
 * @param pfill 1 pinta o fundo, 0 não / 1 paints the background, 0 does not
 * @param phMax altura máxima do bloco; 0 sem limite / maximum block height; 0
 *        for no limit
 * @return NUMBER - quantas linhas foram escritas / how many lines were written
 * @raises -20100 qualquer falha na escrita, com a pilha original preservada /
 *         any failure while writing, with the original stack preserved
 * @example
 *   l_linhas := PL_FPDF.MultiCell(120, 5, l_texto_longo, '1', 'J');
 */
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

/**
 * PT: Escreve texto corrido a partir de onde o cursor está, indo até a margem
 *     direita e continuando na linha seguinte -- como um parágrafo de
 *     processador de texto. Diferente do MultiCell, começa no meio da linha
 *     onde o cursor parou, o que é o que se quer para emendar texto de
 *     formatações diferentes.
 *
 * EN: Writes flowing text from wherever the cursor is, out to the right margin
 *     and on to the next line -- like a word-processor paragraph. Unlike
 *     MultiCell, it starts partway along the line where the cursor stopped,
 *     which is what you want when joining differently formatted runs of text.
 *
 * @param pH altura da linha, na unidade corrente / line height, current unit
 * @param ptxt o texto / the text
 * @param plink URL ou identificador de link interno / URL or internal link id
 * @raises -20100 qualquer falha na escrita, com a pilha original preservada /
 *         any failure while writing, with the original stack preserved
 * @example
 *   PL_FPDF.SetFont('Helvetica', '', 10);
 *   PL_FPDF.Write(5, 'Consulte o ');
 *   PL_FPDF.SetFont('Helvetica', 'U', 10);
 *   PL_FPDF.Write(5, 'manual', 'https://example.com/manual');
 */
procedure Write(pH in varchar2, ptxt in varchar2, plink in varchar2 default null);

/**
 * PT: O mesmo que Cell, com o texto girado dentro da célula. Serve para
 *     cabeçalho de coluna estreita e para carimbo na lateral da página.
 *
 * EN: The same as Cell, with the text rotated inside the cell. Useful for
 *     narrow column headings and for a stamp down the side of the page.
 *
 * @param p_width largura; 0 vai até a margem direita / width; 0 spans to the
 *        right margin
 * @param p_height altura / height
 * @param p_text o texto / the text
 * @param p_border '0' sem borda, '1' moldura, ou 'L','T','R','B' / '0' none,
 *        '1' frame, or 'L','T','R','B'
 * @param p_ln 0 à direita, 1 próxima linha na margem esquerda, 2 abaixo
 *        mantendo o x / 0 to the right, 1 next line at the left margin, 2
 *        below keeping x
 * @param p_align 'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right,
 *        direita)
 * @param p_fill 1 pinta o fundo, 0 não / 1 fills the background, 0 does not
 * @param p_link URL ou link interno / URL or internal link
 * @param p_rotation giro do texto em graus / text rotation in degrees (0, 90,
 *        180, 270)
 * @raises -20110 giro inválido / invalid rotation value
 * @example
 *   PL_FPDF.CellRotated(10, 40, 'Janeiro', '1', 0, 'C', 0, '', 90);
 */
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

/**
 * PT: O mesmo que Write, com o texto girado.
 *
 * EN: The same as Write, with the text rotated.
 *
 * @param p_height altura da linha / line height
 * @param p_text o texto / the text
 * @param p_link URL ou link interno / URL or internal link
 * @param p_rotation giro em graus / rotation in degrees (0, 90, 180, 270)
 * @raises -20110 giro inválido / invalid rotation value
 * @example
 *   PL_FPDF.WriteRotated(5, 'CONFIDENCIAL', NULL, 90);
 */
procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
);

/**
 * PT: Coloca uma imagem buscada por URL. A busca sai pela rede e exige ACL
 *     concedida ao schema -- quando a imagem já está numa tabela ou numa
 *     variável, ImageFromBlob faz o mesmo sem rede e sem permissão. Largura e
 *     altura em zero saem da própria imagem, a 72 dpi; com uma das duas em
 *     zero, ela é derivada da outra, mantendo a proporção.
 *
 * EN: Places an image fetched by URL. The fetch goes over the network and
 *     needs an ACL granted to the schema -- when the image already sits in a
 *     table or a variable, ImageFromBlob does the same with no network and no
 *     permission. Width and height at zero come from the image itself at 72
 *     dpi; with one of them at zero, it is derived from the other, keeping the
 *     aspect ratio.
 *
 * @param pFile URL da imagem / image URL
 * @param pX canto superior esquerdo / top-left corner
 * @param pY canto superior esquerdo / top-left corner
 * @param pWidth largura / width (0 = derivada / derived)
 * @param pHeight altura / height (0 = derivada / derived)
 * @param pType formato, quando não se quer deduzir do arquivo / format, when
 *        it should not be inferred from the file
 * @param pLink URL ou identificador de link interno sobre a imagem / URL or
 *        internal link id over the image
 * @raises -20100 falha ao buscar ou interpretar a imagem, com a pilha original
 *         preservada / failure fetching or parsing the image, original stack
 *         preserved
 * @example
 *   PL_FPDF.Image('https://example.com/logo.png', 10, 10, 40);
 */
procedure image ( pFile   in varchar2,
                  pX      in number,
                  pY      in number,
                  pWidth  in number default 0,
                  pHeight in number default 0,
                  pType   in varchar2 default null,
                  pLink   in varchar2 default null);

/**
 * PT: Coloca uma imagem que o chamador já tem em mãos, sem passar por URL. O
 *     Image() busca pela rede e exige ACL concedida ao schema; quando a imagem
 *     já está numa tabela ou numa variável, esta entrada dispensa a rede e a
 *     permissão. O formato é reconhecido pelos primeiros bytes do arquivo, não
 *     pela extensão: PNG e JPEG; qualquer outra coisa é recusada.
 *
 * EN: Places an image the caller already has, with no URL involved. Image()
 *     fetches over the network and needs an ACL granted to the schema; when
 *     the image already sits in a table or a variable, this entry point needs
 *     neither. The format is recognised from the file's first bytes, not from
 *     an extension: PNG and JPEG; anything else is refused.
 *
 * @param p_blob bytes da imagem / the image bytes (PNG ou JPEG)
 * @param p_name chave no cache de imagens. Um BLOB não tem nome, então o
 *        chamador escolhe: nomes distintos para imagens distintas, e o mesmo
 *        nome reaproveita o objeto já emitido no documento / key in the image
 *        cache. A BLOB has no name, so the caller picks one: distinct names
 *        for distinct images, and the same name reuses the object already
 *        written to the document
 * @param pX posição, na unidade corrente / position, in the current unit
 * @param pY posição, na unidade corrente / position, in the current unit
 * @param pWidth largura / width (0 = derivada / derived)
 * @param pHeight altura / height (0 = derivada / derived)
 * @param pLink link opcional sobre a área da imagem / optional link over the
 *        image area
 * @raises -20301 cabeçalho inválido, BLOB vazio ou nome ausente / invalid
 *         header, empty BLOB or missing name
 * @raises -20303 formato não suportado / unsupported format
 * @example
 *   SELECT logo INTO l_logo FROM empresa WHERE id = 1;
 *   PL_FPDF.ImageFromBlob(l_logo, 'LOGO', 10, 10, 40);
 */
procedure ImageFromBlob( p_blob  in blob,
                         p_name  in varchar2,
                         pX      in number,
                         pY      in number,
                         pWidth  in number default 0,
                         pHeight in number default 0,
                         pLink   in varchar2 default null);

/**
 * PT: Fecha o documento e grava em arquivo, no DIRECTORY PDF_DIR. É a forma
 *     legada: os modos de entrega ao navegador ('I', 'D', 'S') saíram junto
 *     com o OWA/HTP e hoje recusam com -20306, dizendo o que usar no lugar.
 *     Para receber os bytes, use OutputBlob.
 *
 * EN: Closes the document and writes it to a file, in the PDF_DIR DIRECTORY.
 *     This is the legacy form: the browser delivery modes ('I', 'D', 'S') went
 *     away with OWA/HTP and now refuse with -20306, saying what to use
 *     instead. To get the bytes, use OutputBlob.
 *
 * @param pname nome do arquivo / file name (NULL grava 'doc.pdf')
 * @param pdest destino / destination: 'F' (File, arquivo) é o único suportado
 *        / 'F' is the only supported one
 * @raises -20100 destino desconhecido, ou falha na gravação / unknown
 *         destination, or a failure while writing
 * @raises -20306 modo de entrega ao navegador não é mais suportado; a mensagem
 *         aponta OutputBlob e o cabeçalho Content-Type / browser delivery mode
 *         no longer supported; the message points to OutputBlob and the
 *         Content-Type header
 * @example
 *   PL_FPDF.Output('relatorio.pdf', 'F');
 */
procedure Output(pname in varchar2 default null, pdest in varchar2 default null);

/**
 * PT: Fecha o documento e devolve os bytes. Existe por compatibilidade: os
 *     dois parâmetros são ACEITOS E IGNORADOS, e a chamada é repassada ao
 *     OutputBlob. Em código novo, chame OutputBlob direto.
 *
 * EN: Closes the document and returns its bytes. It exists for compatibility:
 *     both parameters are ACCEPTED AND IGNORED, and the call is handed to
 *     OutputBlob. In new code, call OutputBlob directly.
 *
 * @param pname ignorado / ignored
 * @param pdest ignorado / ignored
 * @return BLOB - o PDF / the PDF
 * @raises -20100 falha ao fechar ou montar o documento, com a pilha original
 *         preservada / failure closing or assembling the document, with the
 *         original stack preserved
 * @example
 *   l_pdf := PL_FPDF.OutputBlob;    -- prefira esta / prefer this one
 */
function ReturnBlob(pname in varchar2 default null, pdest in varchar2 default null) return blob;

/**
 * PT: Fecha o documento e devolve os bytes do PDF. É a saída principal da
 *     biblioteca: quem grava em tabela, quem anexa a e-mail e quem entrega por
 *     HTTP começa aqui.
 *
 * EN: Closes the document and returns the PDF bytes. It is the library's main
 *     output: storing in a table, attaching to an e-mail and serving over HTTP
 *     all start here.
 *
 * @return BLOB - o PDF pronto / the finished PDF
 * @raises -20005 Init ainda não foi chamado. Antes de agosto/2026 esta chamada
 *         seguia em frente e devolvia um PDF vazio, sem apontar a causa. /
 *         Init has not been called. Before August 2026 this call went ahead
 *         and returned an empty PDF, with nothing pointing at the cause.
 * @example
 *   l_pdf := PL_FPDF.OutputBlob;
 *   INSERT INTO documentos (id, arquivo) VALUES (1, l_pdf);
 */
function OutputBlob return blob;

/**
 * PT: Fecha o documento e grava num DIRECTORY do banco. Exige WRITE no
 *     diretório concedido ao schema.
 *
 * EN: Closes the document and writes it to a database DIRECTORY. Requires
 *     WRITE on that directory.
 *
 * @param p_filename nome do arquivo / file name
 * @param p_directory DIRECTORY do banco / database DIRECTORY object
 * @raises -20401 diretório inválido / invalid directory
 * @raises -20402 sem permissão de escrita / write access denied
 * @raises -20403 falha ao gravar / write failure
 * @example
 *   PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');
 */
procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR');

/**
 * PT: Marca o documento como aberto. O AddPage já faz isto quando preciso;
 *     chamar à mão é raro.
 *
 * EN: Marks the document as open. AddPage already does it when needed; calling
 *     it by hand is rare.
 *
 * @example
 *   PL_FPDF.OpenPDF;
 */
procedure OpenPDF;

/**
 * PT: Fecha o documento: escreve o rodapé da última página, monta a estrutura
 *     do arquivo e troca o marcador do total de páginas. Sem nenhuma página,
 *     uma é criada em branco. As rotinas de saída chamam isto sozinhas.
 *
 * EN: Closes the document: writes the last page's footer, assembles the file
 *     structure and replaces the page-count placeholder. With no page at all,
 *     a blank one is created. The output routines call it themselves.
 *
 * @example
 *   PL_FPDF.ClosePDF;
 */
procedure ClosePDF;

/**
 * PT: Fecha a página corrente, executando o rodapé, e abre outra, executando o
 *     cabeçalho. Orientação e formato em branco repetem os da página anterior.
 *     Além dos formatos com nome, aceita 'largura,altura' na unidade corrente.
 *
 * EN: Closes the current page, running the footer, and opens another, running
 *     the header. Orientation and format left empty repeat the previous
 *     page's. Besides the named formats, it accepts 'width,height' in the
 *     current unit.
 *
 * @param p_orientation 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem);
 *        NULL mantém a da página anterior / NULL keeps the previous page's
 * @param p_format 'A4', 'Letter', 'Legal', ou 'largura,altura'; NULL mantém o
 *        anterior / or 'width,height'; NULL keeps the previous
 * @param p_rotation giro da página em graus / page rotation in degrees (0, 90,
 *        180, 270)
 * @raises -20005 Init ainda não foi chamado / Init has not been called
 * @raises -20107 orientação inválida / invalid orientation
 * @raises -20103 formato desconhecido / unknown page format
 * @raises -20101 dimensões inválidas no formato livre / invalid dimensions in
 *         the custom format
 * @raises -20104 giro inválido / invalid rotation value
 * @note PT: O NOME do primeiro parâmetro mudou entre versões -- era
 *       'orientation' na 2.0.0 e hoje é 'p_orientation'. Quem chama por
 *       posição (AddPage('L')) não sente nada; quem chama por nome
 *       (AddPage(orientation => 'L')) precisa acertar o nome. Não há como
 *       aceitar os dois: sobrecargas que diferem só pelo nome do parâmetro
 *       deixam a chamada ambígua, e o Oracle recusa com PLS-00307. Ver a seção
 *       de migração em docs/DOCUMENTATION.md.
 * @note EN: The first parameter's NAME changed between versions -- it was
 *       'orientation' in 2.0.0 and is 'p_orientation' today. Positional
 *       callers (AddPage('L')) are unaffected; named callers
 *       (AddPage(orientation => 'L')) must use the new name. Accepting both is
 *       not possible: overloads differing only by parameter name make the call
 *       ambiguous and Oracle refuses with PLS-00307. See the migration section
 *       in docs/DOCUMENTATION.md.
 * @example
 *   PL_FPDF.AddPage;
 *   PL_FPDF.AddPage('L');
 *   PL_FPDF.AddPage('P', '210,297', 90);
 */
procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
);

/**
 * PT: Torna corrente uma página já criada, para escrever nela de novo. Serve
 *     para preencher depois um espaço que só se sabe no fim -- um total, por
 *     exemplo.
 *
 * EN: Makes an existing page current again, to write on it once more. Useful
 *     for filling in later something only known at the end -- a total, say.
 *
 * @param p_page_number a página, que precisa existir / the page, which must
 *        exist
 * @raises -20005 Init ainda não foi chamado / Init has not been called
 * @raises -20106 a página não existe / the page does not exist
 * @example
 *   PL_FPDF.SetPage(1);
 */
procedure SetPage(p_page_number pls_integer);

/**
 * PT: Devolve o número da página em que se está escrevendo.
 *
 * EN: Returns the number of the page being written.
 *
 * @return PLS_INTEGER - a página corrente / the current page
 * @example
 *   l_pagina := PL_FPDF.GetCurrentPage;
 */
function GetCurrentPage return pls_integer
  DETERMINISTIC;

/**
 * PT: Construtor herdado do FPDF original. Continua valendo, e o código
 *     escrito para as versões 0.9.4 e 2.0.0 segue rodando com ele. Em código
 *     novo prefira Init, que valida os argumentos e levanta erro nomeado em
 *     vez de seguir com um valor inesperado.
 *
 * EN: The constructor inherited from the original FPDF. It still works, and
 *     code written for versions 0.9.4 and 2.0.0 keeps running with it. In new
 *     code prefer Init, which validates its arguments and raises a named error
 *     instead of carrying on with an unexpected value.
 *
 * @param orientation 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem)
 * @param unit unidade de medida / measurement unit ('mm','cm','in','pt')
 * @param format formato da página / page format ('A4', 'Letter'...)
 * @example
 *   PL_FPDF.fpdf('L', 'mm', 'A4');
 */
procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');

/**
 * PT: Levanta ORA-20100 com a mensagem dada, acrescentando o rastro da origem
 *     e preservando a pilha original (keeperrorstack) -- é isso que mantém
 *     rastreável o erro de verdade por trás do -20100. É o caminho interno de
 *     erro da biblioteca; está público por herança.
 *
 * EN: Raises ORA-20100 with the given message, adding the origin backtrace and
 *     keeping the original stack (keeperrorstack) -- which is what keeps the
 *     real error behind the -20100 traceable. It is the library's internal
 *     error path, public by inheritance.
 *
 * @param pmsg a mensagem / the message
 * @raises -20100 sempre; é o que esta rotina faz / always; that is what it
 *         does
 * @example
 *   PL_FPDF.Error('nao foi possivel montar o documento');
 */
procedure Error(pmsg in varchar2);

/**
 * PT: Liga a saída de diagnóstico do tratamento de erro. Serve para depuração;
 *     num processo em produção deixa o erro mais verboso.
 *
 * EN: Turns on the error handler's diagnostic output. Useful while debugging;
 *     in production it only makes errors noisier.
 *
 * @example
 *   PL_FPDF.DebugEnabled;
 */
procedure DebugEnabled;

/**
 * PT: Desliga a saída de diagnóstico. É o estado padrão.
 *
 * EN: Turns the diagnostic output off. This is the default state.
 *
 * @example
 *   PL_FPDF.DebugDisabled;
 */
procedure DebugDisabled;

/**
 * PT: Devolve quantos pontos PDF valem uma unidade corrente -- 2,8346 para
 *     milímetro, 1 para ponto. É o número que converte entre a unidade do
 *     chamador e a do arquivo.
 *
 * EN: Returns how many PDF points make one current unit -- 2.8346 for
 *     millimetres, 1 for points. It is the number that converts between the
 *     caller's unit and the file's.
 *
 * @return NUMBER - pontos por unidade / points per unit
 * @example
 *   l_pontos := 10 * PL_FPDF.GetScaleFactor;
 */
function GetScaleFactor return number;

/**
 * PT: Busca uma imagem pela rede e devolve os bytes com o cabeçalho já
 *     interpretado. Exige ACL de rede concedida ao schema. Substitui a
 *     implementação sobre OrdImage, que saiu de linha.
 *
 * EN: Fetches an image over the network and returns its bytes with the header
 *     already parsed. Requires a network ACL granted to the schema. Replaces
 *     the OrdImage-based implementation, which is deprecated.
 *
 * @param p_Url a URL da imagem / the image URL (http/https)
 * @return recImageBlob - os bytes e os metadados / the bytes and the metadata
 * @note Formatos aceitos / Supported formats:
 *   PNG, JPEG/JPG
 * @raises -20301 cabeçalho de imagem inválido / invalid image header
 * @raises -20302 não foi possível buscar a imagem / could not fetch the image
 * @raises -20303 formato não suportado / unsupported format
 * @example
 *   l_img := PL_FPDF.getImageFromUrl('https://example.com/logo.png');
 */
function getImageFromUrl(p_Url in varchar2) return recImageBlob;

/**
 * PT: Define quanta informação a biblioteca escreve no DBMS_OUTPUT.
 *
 * EN: Sets how much the library writes to DBMS_OUTPUT.
 *
 * @param p_level 0 desligado (OFF), 1 erro (ERROR), 2 aviso (WARN), 3
 *        informação (INFO), 4 depuração (DEBUG) / 0 OFF, 1 ERROR, 2 WARN, 3
 *        INFO, 4 DEBUG
 * @example
 *   PL_FPDF.SetLogLevel(3);
 */
procedure SetLogLevel(p_level pls_integer);

/**
 * PT: Devolve o nível de registro em uso.
 *
 * EN: Returns the logging level in use.
 *
 * @return PLS_INTEGER - o nível corrente / the current level (0-4)
 * @example
 *   l_nivel := PL_FPDF.GetLogLevel;
 */
function GetLogLevel return pls_integer
  DETERMINISTIC;

/**
 * PT: Configura o documento inteiro a partir de um objeto JSON -- metadados,
 *     orientação, formato, fonte e margens numa chamada só. Serve a quem
 *     recebe a configuração de fora, de uma tabela ou de um serviço.
 *
 * EN: Configures the whole document from a JSON object -- metadata,
 *     orientation, format, font and margins in a single call. Useful when the
 *     configuration arrives from outside, from a table or a service.
 *
 * @param p_config o objeto JSON com as opções / the JSON object with the
 *        options
 * @note Chaves JSON / Supported JSON keys:
 *   - title, author, subject, keywords, creator (document metadata)
 *   - orientation ('P' or 'L'), unit ('mm','cm','in','pt'), format (page format)
 *   - fontFamily, fontSize, fontStyle (default font configuration)
 *   - leftMargin, topMargin, rightMargin (page margins in current unit)
 * @example
 *   DECLARE
 *     l_config JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     l_config.put('title', 'Monthly Report');
 *     l_config.put('author', 'Maxwell Oliveira');
 *     l_config.put('orientation', 'P');
 *     l_config.put('format', 'A4');
 *     PL_FPDF.SetDocumentConfig(l_config);
 *   END;
 */
procedure SetDocumentConfig(p_config JSON_OBJECT_T);

/**
 * PT: Devolve, em JSON, o que está configurado no documento em andamento e
 *     quantas páginas ele já tem.
 *
 * EN: Returns, as JSON, what is configured on the document in progress and how
 *     many pages it already has.
 *
 * @return JSON_OBJECT_T - os metadados / the metadata
 * @note Estrutura do JSON / JSON structure:
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
 * @example
 *   DECLARE
 *     l_meta JSON_OBJECT_T;
 *   BEGIN
 *     l_meta := PL_FPDF.GetDocumentMetadata();
 *     DBMS_OUTPUT.PUT_LINE('Pages: ' || l_meta.get_Number('pageCount'));
 *   END;
 */
function GetDocumentMetadata return JSON_OBJECT_T;

/**
 * PT: Devolve, em JSON, o formato, a orientação e as medidas de uma página do
 *     documento em andamento.
 *
 * EN: Returns, as JSON, the format, orientation and measurements of one page
 *     of the document in progress.
 *
 * @param p_page_number a página / the page (NULL = a corrente / the current
 *        one)
 * @return JSON_OBJECT_T - os dados da página / the page data
 * @note Estrutura do JSON / JSON structure:
 *   {
 *     "number": <number>,
 *     "format": "<string>",
 *     "orientation": "<string>",
 *     "width": <number>,
 *     "height": <number>,
 *     "unit": "<string>"
 *   }
 * @example
 *   DECLARE
 *     l_page_info JSON_OBJECT_T;
 *   BEGIN
 *     l_page_info := PL_FPDF.GetPageInfo(1);
 *     DBMS_OUTPUT.PUT_LINE('Width: ' || l_page_info.get_Number('width'));
 *   END;
 */
function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T;

/**
 * PT: Desenha um QR Code na página corrente. O codificador é o do
 *     PL_FPDF_UTIL, validado contra o zxing-cpp -- o critério aqui não é
 *     "desenha um símbolo", é "um leitor decodifica".
 *
 * EN: Draws a QR Code on the current page. The encoder is PL_FPDF_UTIL's,
 *     validated against zxing-cpp -- the bar here is not "it draws a symbol",
 *     it is "a reader decodes it".
 *
 * @param p_x canto superior esquerdo, na unidade corrente / top-left corner,
 *        in the current unit
 * @param p_y canto superior esquerdo, na unidade corrente / top-left corner,
 *        in the current unit
 * @param p_size o lado do símbolo / the symbol's side
 * @param p_data o conteúdo a codificar / the content to encode
 * @param p_format 'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'
 * @param p_error_correction nível de correção de erro / error correction
 *        level: 'L' (7%), 'M' (15%), 'Q' (25%), 'H' (30%)
 * @raises -20870 conteúdo vazio / empty content
 * @raises -20872 nível de correção inválido / invalid correction level
 * @example
 *   PL_FPDF.AddQRCode(50, 50, 40, 'https://example.com', 'URL', 'M');
 */
procedure AddQRCode(
  p_x number,
  p_y number,
  p_size number,
  p_data varchar2,
  p_format varchar2 default 'TEXT',
  p_error_correction varchar2 default 'M'
);

/**
 * PT: Desenha um código de barras linear na página corrente. O codificador é o
 *     do PL_FPDF_UTIL, validado contra o zxing-cpp.
 *
 * EN: Draws a linear barcode on the current page. The encoder is
 *     PL_FPDF_UTIL's, validated against zxing-cpp.
 *
 * @param p_x canto superior esquerdo / top-left corner
 * @param p_y canto superior esquerdo / top-left corner
 * @param p_width largura / width
 * @param p_height altura / height
 * @param p_code o conteúdo a codificar / the content to encode
 * @param p_type simbologia / symbology: 'CODE128', 'CODE39', 'EAN13', 'EAN8',
 *        'ITF14', ou 'ITF' (Interleaved 2 of 5, qualquer quantidade par de
 *        dígitos -- o código de barras do boleto bancário tem 44) / or 'ITF'
 *        (any even digit count -- the Brazilian bank slip barcode has 44)
 * @param p_show_text escrever o código embaixo, legível / print the
 *        human-readable code underneath
 * @raises -20880 código vazio / empty code
 * @raises -20882 simbologia não suportada / unsupported symbology
 * @example
 *   PL_FPDF.AddBarcode(30, 50, 150, 20, 'ABC123456', 'CODE128', TRUE);
 */
procedure AddBarcode(
  p_x number,
  p_y number,
  p_width number,
  p_height number,
  p_code varchar2,
  p_type varchar2 default 'CODE128',
  p_show_text boolean default true
);

/**
 * PT: Carregar documento PDF existente na memória para leitura e modificação
 *
 * EN: Load an existing PDF document into memory for reading and modification
 *
 * @param p_pdf_blob PDF document as BLOB / Documento PDF como BLOB
 * @raises -20800 Invalid PDF (NULL or too small) / PDF inválido (NULL ou
 *         pequeno)
 * @raises -20801 Invalid PDF header / Cabeçalho PDF inválido
 * @raises -20802 startxref not found / startxref não encontrado
 * @raises -20803 Invalid xref table / Tabela xref inválida
 * @raises -20804 Root object not found in trailer / Objeto Root não encontrado
 * @example
 *   DECLARE
 *     l_pdf BLOB;
 *   BEGIN
 *     SELECT pdf_content INTO l_pdf FROM documents WHERE id = 123;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || PL_FPDF.GetPageCount());
 *   END;
 */
PROCEDURE LoadPDF(p_pdf_blob BLOB);

/**
 * PT: Obter o número total de páginas no documento PDF carregado
 *
 * EN: Get the total number of pages in the loaded PDF document
 *
 * @return PLS_INTEGER - Number of pages / Número de páginas
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @example
 *   l_pages := PL_FPDF.GetPageCount();
 *   DBMS_OUTPUT.PUT_LINE('Total pages / Total de páginas: ' || l_pages);
 */
FUNCTION GetPageCount RETURN PLS_INTEGER;

/**
 * PT: Obter metadados e informações sobre o documento PDF carregado
 *
 * EN: Get metadata and information about the loaded PDF document
 *
 * @return
 *   JSON_OBJECT_T with / com:
 *   - version: PDF version (e.g., "1.4") / Versão do PDF
 *   - pageCount: Number of pages / Número de páginas
 *   - fileSize: Size in bytes / Tamanho em bytes
 *   - objectCount: Number of objects in xref / Número de objetos na xref
 *   - rootObjectId: Catalog object ID / ID do objeto Catalog
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @example
 *   DECLARE
 *     l_info JSON_OBJECT_T;
 *   BEGIN
 *     l_info := PL_FPDF.GetPDFInfo();
 *     DBMS_OUTPUT.PUT_LINE('Version / Versão: ' || l_info.get_string('version'));
 *     DBMS_OUTPUT.PUT_LINE('Pages / Páginas: ' || l_info.get_number('pageCount'));
 *   END;
 */
FUNCTION GetPDFInfo RETURN JSON_OBJECT_T;

/**
 * PT: Rotacionar uma página específica (armazenado em memória, aplicado na
 *     saída)
 *
 * EN: Rotate a specific page (stored in memory, applied on output)
 *
 * @param p_page_number Page number to rotate / Número da página para
 *        rotacionar
 * @param p_rotation Rotation angle / Ângulo de rotação (0, 90, 180, 270)
 * @note PT: Mudanças armazenadas em memória. Use OutputModifiedPDF() para
 *       gerar PDF
 * @note EN: Changes stored in memory. Use OutputModifiedPDF() to generate PDF
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   PL_FPDF.RotatePage(1, 90);    -- Rotate page 1 / Rotacionar página 1
 *   PL_FPDF.RotatePage(2, 180);   -- Rotate page 2 / Rotacionar página 2
 */
PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER);

/**
 * PT: Marcar uma página para remoção do PDF
 *
 * EN: Mark a page for removal from the PDF
 *
 * @param p_page_number Page number to remove / Número da página para remover
 * @note PT: Página marcada para remoção. Use OutputModifiedPDF() para gerar
 *       PDF modificado
 * @note EN: Page marked for removal. Use OutputModifiedPDF() to generate
 *       modified PDF
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   PL_FPDF.RemovePage(2);  -- Remove page 2 / Remover página 2
 *   PL_FPDF.RemovePage(5);  -- Remove page 5 / Remover página 5
 */
PROCEDURE RemovePage(p_page_number PLS_INTEGER);

/**
 * PT: Obter contagem de páginas não marcadas para remoção
 *
 * EN: Get count of pages not marked for removal
 *
 * @return PLS_INTEGER - Number of active pages / Número de páginas ativas
 * @note PT: Difere de GetPageCount() que retorna a contagem original
 * @note EN: Differs from GetPageCount() which returns original count
 * @example
 *   l_total := PL_FPDF.GetPageCount();        -- Original: 10
 *   PL_FPDF.RemovePage(2);
 *   l_active := PL_FPDF.GetActivePageCount(); -- Active / Ativas: 9
 */
FUNCTION GetActivePageCount RETURN PLS_INTEGER;

/**
 * PT: Verificar se uma página está marcada para remoção
 *
 * EN: Check if a page is marked for removal
 *
 * @param p_page_number Page number to check / Número da página para verificar
 * @return BOOLEAN - TRUE if removed / TRUE se removida, FALSE otherwise / caso
 *         contrário
 * @example
 *   IF PL_FPDF.IsPageRemoved(2) THEN
 *     DBMS_OUTPUT.PUT_LINE('Page 2 removed / Página 2 removida');
 *   END IF;
 */
FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN;

/**
 * PT: Verificar se o PDF carregado foi modificado
 *
 * EN: Check if the loaded PDF has been modified
 *
 * @return BOOLEAN - TRUE if modified / TRUE se modificado, FALSE otherwise /
 *         caso contrário
 * @note PT: Use para determinar se OutputModifiedPDF() precisa ser chamado
 * @note EN: Use to determine if OutputModifiedPDF() needs to be called
 * @example
 *   IF PL_FPDF.IsPDFModified() THEN
 *     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
 *   END IF;
 */
FUNCTION IsPDFModified RETURN BOOLEAN;

/**
 * PT: Acrescenta marca d'água de texto às páginas indicadas
 *
 * EN: Adds a text watermark to the given pages
 *
 * @param p_text Watermark text / Texto da marca d'água
 * @param p_opacity Opacity (0.0 to 1.0) / Opacidade (0.0 a 1.0), default 0.3
 * @param p_rotation Rotation angle / Ângulo de rotação (0, 45, 90, 135, 180,
 *        225, 270, 315), default 45
 * @param p_pages Page range / Range de páginas: 'ALL', '1-5', '1,3,5', default
 *        'ALL'
 * @param p_font Font name / Nome da fonte, default 'Helvetica'
 * @param p_size Font size in points / Tamanho da fonte em pontos, default 48
 * @param p_color Color name / Nome da cor ('gray', 'red', 'blue'), default
 *        'gray'
 * @note PT: Desenhada por OutputModifiedPDF() no fluxo de conteúdo: cada
 *       página afetada ganha um objeto de conteúdo próprio e um /Resources
 *       próprio, de modo que um /Resources compartilhado entre páginas nunca é
 *       contaminado. Centralizada e girada em torno do centro da página; a
 *       fonte é sempre Helvetica.
 * @note EN: Rendered by OutputModifiedPDF() into the page content stream: each
 *       affected page gets its own content object and its own /Resources, so a
 *       /Resources shared between pages is never contaminated. Centred and
 *       rotated about the page centre; the font is always Helvetica.
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   -- All pages / Todas as páginas
 *   PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
 *   -- Specific pages / Páginas específicas
 *   PL_FPDF.AddWatermark('DRAFT', 0.3, 45, '1-5,10');
 *   -- Custom style / Estilo personalizado
 *   PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1', 'Helvetica', 72, 'green');
 */
PROCEDURE AddWatermark(
  p_text VARCHAR2,
  p_opacity NUMBER DEFAULT 0.3,
  p_rotation NUMBER DEFAULT 45,
  p_pages VARCHAR2 DEFAULT 'ALL',
  p_font VARCHAR2 DEFAULT 'Helvetica',
  p_size NUMBER DEFAULT 48,
  p_color VARCHAR2 DEFAULT 'gray'
);

/**
 * PT: Obter lista de todas as marcas d'água aplicadas como array JSON
 *
 * EN: Get list of all applied watermarks as JSON array
 *
 * @return
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
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @example
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
 */
FUNCTION GetWatermarks RETURN JSON_ARRAY_T;

/**
 * PT: Gerar o PDF modificado copiando as páginas mantidas objeto a objeto.
 *     Conteúdo, fontes, imagens e anotações são copiados sem alteração: nada é
 *     re-renderizado. Aplica RemovePage e RotatePage.
 *
 * EN: Generate the modified PDF, copying the kept pages object by object.
 *     Content, fonts, images and annotations are copied verbatim: nothing is
 *     re-rendered. Applies RemovePage and RotatePage.
 *
 * @return BLOB - Modified PDF document / Documento PDF modificado
 * @process PT: 1. Valida se PDF está carregado e modificado 2. Indexa a origem
 *          (cadeia de xref + árvore de páginas achatada) 3. Seleciona as
 *          páginas não marcadas por RemovePage, na ordem original 4. Copia
 *          todo objeto alcançável a partir dessas páginas, renumerando as
 *          referências indiretas; o payload dos streams é copiado byte a byte
 *          5. Emite um novo Catalog, um novo nó /Pages, xref e trailer
 * @process EN: 1. Validates PDF is loaded and modified 2. Indexes the source
 *          (xref chain + flattened page tree) 3. Selects the pages not marked
 *          by RemovePage, in the original order 4. Copies every object
 *          reachable from those pages, renumbering the indirect references;
 *          stream payloads are copied byte for byte 5. Emits a new Catalog, a
 *          new /Pages node, xref and trailer
 * @limitation PT: Marcas d'água e overlays de texto e de imagem são todos
 *             desenhados. xref em stream e object streams (PDF 1.5+) são
 *             lidos, inclusive com o predictor PNG; um malformado levanta
 *             -20843/-20847/-20848.
 * @limitation EN: Watermarks and text and image overlays are all rendered. PDF
 *             1.5+ cross-reference streams and object streams are read (the
 *             PNG predictor included); a malformed one raises
 *             -20843/-20847/-20848.
 * @raises -20809 No PDF loaded (call LoadPDF first) / Nenhum PDF carregado
 * @raises -20819 PDF has not been modified (no changes to apply) / PDF não foi
 *         modificado (sem alterações para aplicar)
 * @raises -20820 All pages have been removed (cannot generate empty PDF) /
 *         Todas as páginas foram removidas (não pode gerar PDF vazio)
 * @raises -20841 Object dictionary too large to renumber / Dicionário de
 *         objeto grande demais para renumerar
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @raises -20823 Invalid or unsupported image / Imagem inválida ou não
 *         suportada PT: PNG com alfa e entrelaçado são suportados; recusados
 *         são o entrelaçado abaixo de 8 bits por componente, o indexado E
 *         entrelaçado, e imagens acima de 4 megapixels no caminho que
 *         reprocessa pixels EN: alpha and interlaced PNG are supported;
 *         refused are interlaced below 8 bits per component, indexed AND
 *         interlaced, and images above 4 megapixels on the pixel-reprocessing
 *         path
 * @raises -20846 Page /Resources cannot be overlaid (shared indirect
 *         sub-dictionary) / /Resources da página não permite sobreposição
 *         (sub-dicionário indireto compartilhado)
 * @example
 *   DECLARE
 *     l_pdf BLOB;
 *     l_modified_pdf BLOB;
 *   BEGIN
 *     -- Load PDF / Carregar PDF
 *     SELECT pdf_blob INTO l_pdf FROM docs WHERE id = 1;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Apply modifications / Aplicar modificações
 *     PL_FPDF.RotatePage(1, 90);
 *     PL_FPDF.RemovePage(3);
 *     -- Generate modified PDF / Gerar PDF modificado
 *     l_modified_pdf := PL_FPDF.OutputModifiedPDF();
 *     -- Save modified PDF / Salvar PDF modificado
 *     UPDATE docs SET pdf_blob = l_modified_pdf WHERE id = 1;
 *     PL_FPDF.ClearPDFCache();
 *   END;
 */
FUNCTION OutputModifiedPDF RETURN BLOB;

/**
 * PT: Limpar PDF carregado da memória e liberar todos os recursos em cache
 *
 * EN: Clear loaded PDF from memory and free all cached resources
 *
 * @note PT: Sempre chame isso após processar um PDF para liberar recursos de
 *       memória. Limpa: PDF carregado, info páginas, rotações, páginas
 *       removidas, marcas d'água.
 * @note EN: Always call this after processing a PDF to free memory resources.
 *       Clears: loaded PDF, page info, rotations, removed pages, watermarks.
 * @example
 *   PL_FPDF.LoadPDF(l_pdf);
 *   -- Process PDF / Processar PDF
 *   l_modified := PL_FPDF.OutputModifiedPDF();
 *   -- Clear memory / Limpar memória
 *   PL_FPDF.ClearPDFCache();
 */
PROCEDURE ClearPDFCache;

/**
 * PT: Descomprime um stream /FlateDecode do PDF (zlib, RFC 1950). Implementado
 *     em PL/SQL puro: o UTL_COMPRESS não serve porque só aceita rodapé gzip
 *     com CRC-32 correto, e esse CRC é do conteúdo DESCOMPRIMIDO — para saber
 *     o CRC seria preciso descomprimir antes.
 *
 * EN: Decompress a PDF /FlateDecode stream (zlib, RFC 1950). Implemented in
 *     pure PL/SQL: UTL_COMPRESS cannot be used here because it only accepts a
 *     gzip trailer with a correct CRC-32, and that CRC is of the DECOMPRESSED
 *     data — knowing it would require decompressing first.
 *
 * @param p_stream Compressed stream / Stream comprimido (BLOB)
 * @param p_max_bytes Output ceiling, 8 MB by default. A compressed stream is
 *        untrusted input: a few KB can expand to gigabytes (zip bomb) and take
 *        the session down. Raises -20893 instead. / Teto da saída, 8 MB por
 *        padrão. Um stream comprimido é entrada não confiável: alguns KB podem
 *        virar gigabytes (zip bomb) e derrubar a sessão. Levanta -20893 em vez
 *        disso.
 * @return BLOB - Decompressed content / Conteúdo descomprimido
 * @raises -20890 Truncated stream / Stream truncado
 * @raises -20891 Malformed DEFLATE data / Dados DEFLATE malformados
 * @raises -20892 Invalid zlib header / Cabeçalho zlib inválido
 * @raises -20893 Output exceeded p_max_bytes / Saída passou de p_max_bytes
 * @example
 *     l_claro := PL_FPDF.FlateDecode(l_comprimido);
 *   Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
 */
FUNCTION FlateDecode(
  p_stream    IN BLOB,
  p_max_bytes IN PLS_INTEGER DEFAULT 8388608
) RETURN BLOB;

/**
 * PT: Comprime dados num stream /FlateDecode do PDF (zlib, RFC 1950). Escrito
 *     em PL/SQL puro: um bloco único com Huffman fixa e LZ77 guloso. Comprime
 *     menos que a Huffman dinâmica do zlib e muito mais que nada, e nunca
 *     devolve mais que a entrada somada ao custo do bloco armazenado.
 *
 * EN: Compresses data into a PDF /FlateDecode stream (zlib, RFC 1950). Written
 *     in pure PL/SQL: a single fixed-Huffman block with greedy LZ77. It
 *     compresses less than zlib's dynamic Huffman and far more than nothing,
 *     and never returns more than the input plus the stored-block overhead.
 *
 * @param p_data conteúdo a comprimir / content to compress (BLOB)
 * @return BLOB - stream zlib: cabeçalho, DEFLATE e Adler-32 / zlib stream:
 *         header, DEFLATE and Adler-32
 * @example
 *     l_comprimido := PL_FPDF.FlateEncode(l_claro);
 *   Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
 */
FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB;

/**
 * PT: Adicionar sobreposição de texto em posição específica com controle
 *     completo de formatação Desenhada por OutputModifiedPDF() no fluxo de
 *     conteúdo. x e y vão em pontos PDF, a partir do canto inferior esquerdo.
 *     Quando width é informado ele define a CAIXA do texto: as linhas quebram
 *     dentro dela e o align é relativo a [x, x+width]. Sem width não há o que
 *     quebrar, e o align passa a ser relativo ao próprio ponto — 'center'
 *     centraliza o texto em x, 'right' o termina em x.
 *
 * EN: Add text overlay at specific position on PDF page with full formatting
 *     control Rendered by OutputModifiedPDF() into the page content stream. x
 *     and y are in PDF points, from the bottom-left. When width is given it
 *     defines the text BOX: lines wrap inside it and align is relative to [x,
 *     x+width]. Without width there is nothing to wrap, and align becomes
 *     relative to the point itself — 'center' centres the text on x, 'right'
 *     ends it at x.
 *
 * @param p_page_number Page number (1-based) / Número da página (base 1)
 * @param p_text Text content / Conteúdo do texto
 * @param p_x X position in PDF points (1 point = 1/72 inch, from left) /
 *        Posição X
 * @param p_y Y position in PDF points (from bottom) / Posição Y (de baixo)
 * @param p_options JSON configuration (optional) / Configuração JSON
 *        (opcional)
 * @note Opções / Options (JSON_OBJECT_T):
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
 * @raises -20809 No PDF loaded / Nenhum PDF carregado
 * @raises -20810 Invalid page number / Número de página inválido
 * @raises -20821 Invalid position coordinates or opacity out of 0.0..1.0 /
 *         Coordenadas de posição inválidas, ou opacidade fora de 0.0..1.0
 * @example
 *   DECLARE
 *     l_options JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Simple text overlay / Sobreposição simples
 *     PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
 *     -- Formatted text / Texto formatado
 *     l_options.put('font', 'Helvetica-Bold');
 *     l_options.put('fontSize', 24);
 *     l_options.put('color', 'FF0000');  -- Red / Vermelho
 *     l_options.put('opacity', 0.8);
 *     l_options.put('rotation', 45);
 *     PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
 *     l_modified := PL_FPDF.OutputModifiedPDF();
 *   END;
 */
PROCEDURE OverlayText(
  p_page_number IN PLS_INTEGER,
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

/**
 * PT: Adicionar sobreposição de imagem em posição específica com controle de
 *     tamanho Desenhada por OutputModifiedPDF() no fluxo de conteúdo. No
 *     caminho comum nada é descomprimido: o JPEG entra inteiro como
 *     /DCTDecode, e os blocos IDAT do PNG já são zlib, que é o /FlateDecode do
 *     PDF — são concatenados e declarados com /Predictor 15, o que vale de 1 a
 *     16 bits por componente. PNG com canal alfa (color types 4 e 6) e
 *     entrelaçado (Adam7) também são desenhados, por um caminho que reprocessa
 *     pixel a pixel — e por isso sai sem compressão, já que não há deflate
 *     neste trecho. Recusados com -20823, em vez de desenhados errado:
 *     entrelaçado com menos de 8 bits por componente, indexado E entrelaçado,
 *     e imagem acima do teto de pixels do caminho que reprocessa.
 *
 * EN: Add image overlay at specific position on PDF page with sizing control
 *     Rendered by OutputModifiedPDF() into the page content stream. On the
 *     common path nothing is decompressed: JPEG goes in whole as /DCTDecode,
 *     and a PNG's IDAT blocks are already zlib, which is the PDF's
 *     /FlateDecode — they are concatenated and declared with /Predictor 15,
 *     which holds from 1 to 16 bits per component. PNG with an alpha channel
 *     (color types 4 and 6) and interlaced PNG (Adam7) are drawn too, by a
 *     path that reprocesses pixel by pixel — and therefore comes out
 *     uncompressed, there being no deflate on that path. Refused with -20823
 *     rather than drawn wrong: interlaced below 8 bits per component, indexed
 *     AND interlaced, and images above the pixel ceiling of the reprocessing
 *     path.
 *
 * @param p_page_number Page number (1-based) / Número da página (base 1)
 * @param p_image_blob Image data (JPEG or PNG) / Dados da imagem (JPEG ou PNG)
 * @param p_x X position in PDF points / Posição X em pontos PDF
 * @param p_y Y position in PDF points (from bottom) / Posição Y (de baixo)
 * @param p_width Image width in points (NULL = original) / Largura em pontos
 * @param p_height Image height in points (NULL = original) / Altura em pontos
 * @param p_options JSON configuration (optional) / Configuração JSON
 *        (opcional)
 * @note Opções / Options (JSON_OBJECT_T):
 *   {
 *     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
 *     "rotation": 0,                 // Rotation angle / Ângulo de rotação
 *     "maintainAspect": true,        // Keep aspect ratio / Manter proporção
 *     "scaleToFit": false,           // Scale to fit in width/height / Escalar para caber
 *     "zOrder": 100                  // Layer order / Ordem da camada
 *   }
 * @raises -20809 No PDF loaded / Nenhum PDF carregado
 * @raises -20810 Invalid page number / Número de página inválido
 * @raises -20821 Invalid position coordinates / Coordenadas de posição
 *         inválidas
 * @raises -20823 Invalid image format (must be JPEG or PNG) / Formato de
 *         imagem inválido
 * @raises -20824 Image dimensions invalid / Dimensões da imagem inválidas
 * @example
 *   DECLARE
 *     l_logo BLOB;
 *     l_options JSON_OBJECT_T := JSON_OBJECT_T();
 *   BEGIN
 *     SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
 *     PL_FPDF.LoadPDF(l_pdf);
 *     -- Add logo at top-right / Adicionar logo no canto superior direito
 *     PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
 *     -- Watermark image with transparency / Marca d'água com transparência
 *     l_options.put('opacity', 0.3);
 *     l_options.put('rotation', 45);
 *     PL_FPDF.OverlayImage(1, l_watermark, 200, 400, 300, NULL, l_options);
 *     l_modified := PL_FPDF.OutputModifiedPDF();
 *   END;
 */
PROCEDURE OverlayImage(
  p_page_number IN PLS_INTEGER,
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER DEFAULT NULL,
  p_height IN NUMBER DEFAULT NULL,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);

/**
 * PT: Obter lista de todas as sobreposições aplicadas como array JSON
 *
 * EN: Get list of all applied overlays as JSON array for specific page or all
 *     pages
 *
 * @param p_page_number Filter by page (NULL = all pages) / Filtrar por página
 * @return
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
 * @raises -20809 No PDF loaded / Nenhum PDF carregado
 * @example
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
 */
FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T;

/**
 * PT: Remover sobreposição específica por ID
 *
 * EN: Remove specific overlay by ID
 *
 * @param p_overlay_id Overlay ID from GetOverlays() / ID da sobreposição
 * @raises -20825 Overlay not found / Sobreposição não encontrada
 * @example
 *   PL_FPDF.RemoveOverlay('OVL_001');
 */
PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2);

/**
 * PT: Limpar todas as sobreposições de todas ou de página específica
 *
 * EN: Clear all overlays from all pages or specific page
 *
 * @param p_page_number Clear from page (NULL = all pages) / Limpar de página
 * @example
 *   -- Clear all overlays / Limpar todas as sobreposições
 *   PL_FPDF.ClearOverlays();
 *   -- Clear overlays from page 1 only / Limpar apenas da página 1
 *   PL_FPDF.ClearOverlays(1);
 */
PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL);

/**
 * PT: Carregar PDF em memória com identificador único para operações
 *     multi-documento
 *
 * EN: Load PDF into memory with unique identifier for multi-document
 *     operations
 *
 * @param p_pdf_id Unique identifier (max 50 chars) / Identificador único
 * @param p_pdf_blob PDF document as BLOB / Documento PDF como BLOB
 * @note PT: Máximo de 10 PDFs podem ser carregados simultaneamente
 * @note EN: Maximum 10 PDFs can be loaded simultaneously
 * @raises -20828 PDF ID already loaded / ID do PDF já carregado
 * @raises -20829 Maximum PDFs exceeded (10 max) / Máximo de PDFs excedido
 * @raises -20830 Invalid PDF ID (empty or too long) / ID de PDF inválido
 * @example
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('report_jan', l_jan_pdf);
 *     PL_FPDF.LoadPDFWithID('report_feb', l_feb_pdf);
 *     PL_FPDF.LoadPDFWithID('report_mar', l_mar_pdf);
 *   END;
 */
PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
);

/**
 * PT: Obter lista de todos os IDs de PDF carregados e seus metadados
 *
 * EN: Get list of all loaded PDF IDs and their metadata as JSON array
 *
 * @return
 *   JSON_ARRAY_T - Array of PDF objects / Array de objetos PDF
 *     [{
 *       "pdfId": "report_jan",
 *       "pageCount": 5,
 *       "fileSize": 125678,
 *       "loadedDate": "2026-01-25T10:30:00"
 *     }, ...]
 * @example
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
 */
FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T;

/**
 * PT: Remover PDF específico da memória para liberar recursos
 *
 * EN: Remove specific PDF from memory to free resources
 *
 * @param p_pdf_id PDF identifier to unload / Identificador do PDF
 * @raises -20831 PDF ID not found / ID do PDF não encontrado
 * @example
 *   PL_FPDF.UnloadPDF('report_jan');
 */
PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2);

/**
 * PT: Mesclar múltiplos PDFs carregados em um único documento, na ordem dada.
 *     Todos os objetos de cada origem são copiados (páginas, fontes, imagens,
 *     anotações) com as referências indiretas renumeradas, e uma nova árvore
 *     de páginas é montada. Nada é re-renderizado: o conteúdo original chega
 *     intacto. O mesmo ID pode aparecer mais de uma vez.
 *
 * EN: Merge multiple loaded PDFs into a single document, in the given order.
 *     Every object of every source is copied (pages, fonts, images,
 *     annotations) with its indirect references renumbered, and a new page
 *     tree is built. Nothing is re-rendered: the original content arrives
 *     intact. The same ID may appear more than once.
 *
 * @param p_pdf_ids JSON array of PDF IDs to merge / Array JSON de IDs de PDF
 *        Example: JSON_ARRAY_T('["pdf1","pdf2","pdf3"]')
 * @param p_options Optional configuration / Configuração opcional (future use)
 * @return BLOB - Merged PDF document / Documento PDF mesclado
 * @raises -20832 No PDF IDs provided / Nenhum ID de PDF fornecido
 * @raises -20833 PDF ID in list not loaded / ID de PDF na lista não carregado
 * @raises -20834 Merge failed / Mesclagem falhou
 * @raises -20841 Object dictionary too large to renumber / Dicionário de
 *         objeto grande demais para renumerar
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @example
 *   DECLARE
 *     l_merged BLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('jan', l_jan_pdf);
 *     PL_FPDF.LoadPDFWithID('feb', l_feb_pdf);
 *     PL_FPDF.LoadPDFWithID('mar', l_mar_pdf);
 *     l_merged := PL_FPDF.MergePDFs(
 *       JSON_ARRAY_T('["jan","feb","mar"]'),
 *       NULL
 *     );
 *     INSERT INTO reports VALUES ('Q1_2026', l_merged);
 *   END;
 */
FUNCTION MergePDFs(
  p_pdf_ids IN JSON_ARRAY_T,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

/**
 * PT: Dividir o PDF carregado em vários documentos, um por intervalo. Cada
 *     parte leva apenas os objetos alcançáveis a partir das suas páginas, e
 *     por isso fica bem menor que a origem. Os intervalos não podem se
 *     sobrepor.
 *
 * EN: Split the loaded PDF into several documents, one per page range. Each
 *     part carries only the objects reachable from its own pages, so the parts
 *     are much smaller than the source. Ranges must not overlap.
 *
 * @param p_pdf_id PDF identifier to split / Identificador do PDF
 * @param p_page_ranges JSON array of page range strings / Array de intervalos
 *        Examples: '1-5', '6-10', '11', '1,3,5', 'ALL'
 * @return JSON_ARRAY_T - Array with base64 encoded PDFs, one per range,
 *         without line breaks / Array com PDFs em base64, um por intervalo,
 *         sem quebras de linha
 * @raises -20831 PDF ID not found / ID do PDF não encontrado
 * @raises -20835 No page ranges provided / Nenhum intervalo fornecido
 * @raises -20836 Overlapping page ranges / Intervalos sobrepostos
 * @raises -20838 Invalid page specification / Especificação de páginas
 *         inválida
 * @raises -20839 Page number out of range / Número de página fora do intervalo
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @example
 *   DECLARE
 *     l_split_pdfs JSON_ARRAY_T;
 *     l_part CLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('contract', l_contract_pdf);
 *     l_split_pdfs := PL_FPDF.SplitPDF('contract',
 *       JSON_ARRAY_T('["1-5", "6-10", "11-15"]')
 *     );
 *     FOR i IN 0..l_split_pdfs.get_size() - 1 LOOP
 *       l_part := l_split_pdfs.get_string(i);
 *       -- Process each part / Processar cada parte
 *     END LOOP;
 *   END;
 */
FUNCTION SplitPDF(
  p_pdf_id IN VARCHAR2,
  p_page_ranges IN JSON_ARRAY_T
) RETURN JSON_ARRAY_T;

/**
 * PT: Extrair as páginas indicadas de um PDF carregado para um novo documento.
 *     A ordem pedida é respeitada ('5,1' devolve a página 5 e depois a 1) e
 *     uma página pode repetir. Só os objetos alcançáveis a partir das páginas
 *     escolhidas são copiados, então o resultado fica menor que a origem.
 *
 * EN: Extract the given pages from a loaded PDF into a new document. The
 *     requested order is kept ('5,1' returns page 5 then page 1) and a page
 *     may repeat. Only the objects reachable from the selected pages are
 *     copied, so the result is smaller than the source.
 *
 * @param p_pdf_id PDF identifier / Identificador do PDF
 * @param p_pages Page specification: '1', '1,3,5-7,10', '5,1' or 'ALL' /
 *        Especificação: '1', '1,3,5-7,10', '5,1' ou 'ALL'
 * @param p_options Optional configuration / Configuração opcional (future use)
 * @return BLOB - New PDF with extracted pages / Novo PDF com páginas extraídas
 * @raises -20831 PDF ID not found / ID do PDF não encontrado
 * @raises -20838 Invalid page specification / Especificação de páginas
 *         inválida
 * @raises -20839 Page number out of range / Número de página fora do intervalo
 * @raises -20841 Object dictionary too large to renumber / Dicionário de
 *         objeto grande demais para renumerar
 * @raises -20843 Malformed cross-reference stream / xref em stream malformada
 * @raises -20847 Malformed object stream / object stream malformado
 * @raises -20848 Unsupported predictor in the xref stream / predictor não
 *         suportado na xref em stream
 * @example
 *   DECLARE
 *     l_extracted BLOB;
 *   BEGIN
 *     PL_FPDF.LoadPDFWithID('manual', l_manual_pdf);
 *     -- Extract pages 1, 5-10, and 15 / Extrair páginas 1, 5-10 e 15
 *     l_extracted := PL_FPDF.ExtractPages('manual', '1,5-10,15', NULL);
 *     INSERT INTO documents VALUES ('Summary', l_extracted);
 *   END;
 */
FUNCTION ExtractPages(
  p_pdf_id IN VARCHAR2,
  p_pages IN VARCHAR2,
  p_options IN JSON_OBJECT_T DEFAULT NULL
) RETURN BLOB;

/**
 * PT: Criptografar PDF com proteção por senha seguindo especificação PDF
 *
 * EN: Encrypt PDF with password protection following PDF specification
 *
 * @param p_pdf PDF blob to encrypt / PDF blob para criptografar
 * @param p_user_password Password to open document / Senha para abrir
 *        documento
 * @param p_owner_password Password for full access (optional) / Senha acesso
 *        total
 * @param p_permissions JSON with permission flags / JSON com flags de
 *        permissão
 * @param p_encryption Encryption method:
 *        'RC4-40','RC4-128','AES-128','AES-256'
 * @return BLOB - Encrypted PDF / PDF criptografado
 * @raises -20850 Invalid encryption method / Método de criptografia inválido
 * @raises -20851 Password required / Senha obrigatória
 * @raises -20852 Encryption failed / Falha na criptografia
 * @note PT: Origem em PDF 1.5+ (xref em stream, object streams) é achatada: os
 *       objetos de dentro dos object streams viram objetos de primeiro nível e
 *       a saída leva xref clássica.
 * @note EN: A PDF 1.5+ source (cross-reference stream, object streams) is
 *       flattened: objects living inside object streams become top-level
 *       objects and the output carries a classic cross-reference table.
 * @example
 *   l_encrypted := PL_FPDF.EncryptPDF(
 *     p_pdf => l_pdf,
 *     p_user_password => 'user123',
 *     p_owner_password => 'owner456',
 *     p_permissions => JSON_OBJECT_T('{"print":true,"copy":false}'),
 *     p_encryption => 'AES-128'
 *   );
 */
FUNCTION EncryptPDF(
  p_pdf IN BLOB,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL,
  p_permissions IN JSON_OBJECT_T DEFAULT NULL,
  p_encryption IN VARCHAR2 DEFAULT 'RC4-128'
) RETURN BLOB;

/**
 * PT: Remover criptografia do PDF usando senha
 *
 * EN: Remove encryption from PDF using password
 *
 * @param p_pdf Encrypted PDF blob / PDF blob criptografado
 * @param p_password User or owner password / Senha de usuário ou owner
 * @return BLOB - Decrypted PDF / PDF descriptografado
 * @raises -20853 PDF is not encrypted / PDF não está criptografado
 * @raises -20854 Invalid password / Senha inválida
 * @raises -20855 Decryption failed / Falha na descriptografia
 * @note PT: Origem em PDF 1.5+ é achatada, e os object streams são decifrados
 *       antes de descomprimidos.
 * @note EN: A PDF 1.5+ source is flattened, and the object streams are
 *       decrypted before being decompressed.
 * @example
 *   l_decrypted := PL_FPDF.DecryptPDF(l_encrypted_pdf, 'password123');
 */
FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB;

/**
 * PT: Verificar se PDF está criptografado
 *
 * EN: Check if PDF is encrypted
 *
 * @param p_pdf PDF blob to check / PDF blob para verificar
 * @return BOOLEAN - TRUE if encrypted / TRUE se criptografado
 * @example
 *   IF PL_FPDF.IsEncrypted(l_pdf) THEN ...
 */
FUNCTION IsEncrypted(p_pdf IN BLOB) RETURN BOOLEAN;

/**
 * PT: Obter informações de segurança do PDF
 *
 * EN: Get security information from PDF
 *
 * @param p_pdf PDF blob / PDF blob
 * @return
 *   JSON_OBJECT_T - Security info including:
 *     - encrypted: boolean
 *     - method: string (RC4-40, RC4-128, AES-128, AES-256)
 *     - permissions: object with print, copy, modify, etc.
 *     - hasUserPassword: boolean
 *     - hasOwnerPassword: boolean
 * @example
 *   l_info := PL_FPDF.GetSecurityInfo(l_pdf);
 *   IF l_info.get_boolean('encrypted') THEN ...
 */
FUNCTION GetSecurityInfo(p_pdf IN BLOB) RETURN JSON_OBJECT_T;

/**
 * PT: Definir criptografia para PDF em geração (usar antes do Output)
 *
 * EN: Set encryption for PDF being generated (use before Output)
 *
 * @param p_encryption Method: 'RC4-40','RC4-128','AES-128','AES-256'
 * @param p_user_password Password to open / Senha para abrir
 * @param p_owner_password Password for full access / Senha acesso total
 * @example
 *   PL_FPDF.Init;
 *   PL_FPDF.SetEncryption('AES-128', 'user123', 'owner456');
 *   PL_FPDF.AddPage;
 *   l_pdf := PL_FPDF.OutputBlob;
 * @note Mapeamento de Versão / PDF Version Mapping:
 *   RC4-40/RC4-128 -> PDF 1.4
 *   AES-128 -> PDF 1.5
 *   AES-256 -> PDF 1.7
 */
PROCEDURE SetEncryption(
  p_encryption IN VARCHAR2,
  p_user_password IN VARCHAR2,
  p_owner_password IN VARCHAR2 DEFAULT NULL
);

/**
 * PT: Definir a versão do PDF para documentos gerados
 *
 * EN: Set the PDF version for generated documents
 *
 * @param p_version PDF version: '1.4', '1.5', '1.6', '1.7', '2.0'
 * @note Recursos por Versão / Version Features:
 *   1.4: RC4 128-bit encryption, transparency
 *   1.5: AES 128-bit, object streams, cross-reference streams
 *   1.6: AES 128-bit, OpenType fonts
 *   1.7: AES 256-bit, XFA forms
 *   2.0: AES 256-bit only, no RC4
 * @example
 *   PL_FPDF.SetPDFVersion('1.5');
 */
PROCEDURE SetPDFVersion(p_version IN VARCHAR2);

/**
 * PT: Obter a configuração atual de versão do PDF
 *
 * EN: Get the current PDF version setting
 *
 * @return VARCHAR2 - Current PDF version (e.g., '1.4')
 */
FUNCTION GetPDFVersion RETURN VARCHAR2;

/**
 * PT: Definir permissões do documento (requer SetEncryption antes)
 *
 * EN: Set document permissions (requires SetEncryption first)
 *
 * @param p_print Allow printing / Permitir impressão
 * @param p_modify Allow modification / Permitir modificação
 * @param p_copy Allow copy/extract / Permitir cópia/extração
 * @param p_annotate Allow annotations / Permitir anotações
 * @param p_fill_forms Allow form filling / Permitir preenchimento de
 *        formulários
 * @param p_extract Allow content extraction / Permitir extração de conteúdo
 * @param p_assemble Allow document assembly / Permitir montagem de documento
 * @param p_print_high Allow high quality print / Permitir impressão alta
 *        qualidade
 * @example
 *   PL_FPDF.SetEncryption('AES-128', 'user', 'owner');
 *   PL_FPDF.SetPermissions(p_print => TRUE, p_copy => FALSE, p_modify => FALSE);
 */
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
END PL_FPDF;
/

--------------------------------------------------------------------------------
-- PACKAGE BODY PL_FPDF
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PL_FPDF AS

subtype flag is boolean;
subtype car is varchar2(1);
subtype phrase is varchar2(255);

subtype txt is varchar2(32767);
subtype bigtext is varchar2(32767);
subtype margin is number;

type tbool is table of boolean index by pls_integer;
type tn is table of number index by pls_integer;
type tv4000 is table of varchar2(4000) index by pls_integer;
type tv32k is table of varchar2(32767) index by pls_integer;
type tclob is table of clob index by pls_integer;
type tblob is table of blob index by pls_integer;
type tpi is table of pls_integer index by pls_integer;

type tTTFObjs is table of pls_integer index by varchar2(100);
type tpi2 is table of tpi index by pls_integer;

co_pdf_dict_limit constant pls_integer := 32000;

co_img_max_px constant pls_integer := 4000000;

co_nls_num constant varchar2(40) := 'NLS_NUMERIC_CHARACTERS=''.,''';

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

type recImage is record ( n number,
	 		  	 		  i number,
	 		  	 		  w number,
	 		  	 		  h number,
						  cs txt,
						  bpc txt,
	 		  	 		  f txt,
						  parms txt,
						  pal raw(8192),

						  trns tn,
						  data blob
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

 page number;
 n number;
 offsets tv4000;

 pdfDoc CLOB;
 imgBlob blob;
 pages tclob;

 g_page_buf varchar2(32767);
 g_doc_buf varchar2(32767);
 g_page_buf_page pls_integer;
 co_page_buf_limit constant pls_integer := 32000;
 state word;
 b_compress flag := false;
 DefOrientation car;
 CurOrientation car;
 OrientationChanges tbool;
 k number;
 fwPt number;
 fhPt number;
 fw number;
 fh number;
 wPt number;
 hPt number;
 w number;
 h number;
 lMargin margin;
 tMargin margin;
 rMargin margin;
 bMargin margin;
 cMargin margin;
 x number;
 y number;
 lasth number;
 LineWidth number;
 CoreFonts tv4000a;
 fonts fontsArray;
 FontFiles fontsArray;
 diffs tv4000;
 images imagesArray;
 PageLinks LinksArray;
 links Array2dim;
 FontFamily word;
 FontStyle word;
 underline flag;
 CurrentFont recFont;
 FontSizePt number;
 FontSize number;
 DrawColor phrase;
 FillColor phrase;
 TextColor phrase;
 ColorFlag flag;
 ws word;
 AutoPageBreak flag;
 PageBreakTrigger number;
 InFooter flag;
 ZoomMode word;
 LayoutMode word;
 title txt;
 subject txt;
 author txt;
 keywords txt;
 creator txt;
 AliasNbPages word;
 PDFVersion word;

 fpdf_charwidths ArrayCharWidths;
 MyHeader_Proc txt;
 MyHeader_ProcParam tv4000a;
 MyHeader_Stmt txt;
 MyFooter_Stmt txt;
 MyFooter_Proc txt;
 MyFooter_ProcParam tv4000a;
 formatArray recFormat;
 gb_mode_debug boolean := false;
 Linespacing number;

 originalsize word;
 size1 word;
 size2 word;

 g_initialized boolean := false;
 g_encoding varchar2(20) := 'UTF-8';
 g_log_level pls_integer := 2;

 type tPageFormats is table of recPageFormat index by varchar2(20);

 g_pages tPages;
 g_current_page pls_integer := 0;
 g_page_formats tPageFormats;
 g_default_format recPageFormat;
 g_default_orientation varchar2(1) := 'P';
 g_formats_initialized boolean := false;

 g_ttf_fonts tTTFFonts;
 g_ttf_fonts_count pls_integer := 0;

 g_ttf_obj tTTFObjs;

 c_PDF_VERSION CONSTANT VARCHAR2(10) := '1.4';

 c_MIN_FONT_SIZE CONSTANT NUMBER := 1;
 c_MAX_FONT_SIZE CONSTANT NUMBER := 999;

 c_MAX_FONT_NAME_LENGTH CONSTANT NUMBER := 80;

 c_MIN_COLOR_VALUE CONSTANT NUMBER := 0;
 c_MAX_COLOR_VALUE CONSTANT NUMBER := 255;

 c_LOG_OFF CONSTANT PLS_INTEGER := 0;
 c_LOG_ERROR CONSTANT PLS_INTEGER := 1;
 c_LOG_WARN CONSTANT PLS_INTEGER := 2;
 c_LOG_INFO CONSTANT PLS_INTEGER := 3;
 c_LOG_DEBUG CONSTANT PLS_INTEGER := 4;

 c_SCALE_PT CONSTANT NUMBER := 1;
 c_SCALE_MM CONSTANT NUMBER := 72/25.4;
 c_SCALE_CM CONSTANT NUMBER := 72/2.54;
 c_SCALE_IN CONSTANT NUMBER := 72;

 c_PNG_SIGNATURE CONSTANT RAW(8) := HEXTORAW('89504E470D0A1A0A');
 c_JPEG_SOI CONSTANT RAW(2) := HEXTORAW('FFD8');

g_loaded_pdf BLOB;

g_pdf_version VARCHAR2(10);
g_xref_offset PLS_INTEGER;
g_root_obj_id PLS_INTEGER;
g_pages_obj_id PLS_INTEGER;
g_loaded_page_count PLS_INTEGER := 0;

TYPE xref_entry_rec IS RECORD (
  offset PLS_INTEGER,
  generation PLS_INTEGER,
  in_use BOOLEAN
);
TYPE xref_table_type IS TABLE OF xref_entry_rec INDEX BY PLS_INTEGER;
g_xref_table xref_table_type;

g_objstm_body tv32k;

TYPE object_cache_type IS TABLE OF CLOB INDEX BY PLS_INTEGER;
g_object_cache object_cache_type;

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

g_pdf_modified BOOLEAN := FALSE;
TYPE page_removal_list IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
g_removed_pages page_removal_list;

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

TYPE overlay_rec IS RECORD (
  overlay_id VARCHAR2(50),
  overlay_type VARCHAR2(20),
  page_number PLS_INTEGER,
  x NUMBER,
  y NUMBER,
  width NUMBER,
  height NUMBER,
  content CLOB,
  image_blob BLOB,
  opacity NUMBER,
  rotation NUMBER,
  font_name VARCHAR2(100),
  font_size NUMBER,
  color VARCHAR2(50),
  align VARCHAR2(20),
  bold BOOLEAN,
  z_order PLS_INTEGER,
  maintain_aspect BOOLEAN,
  scale_to_fit BOOLEAN,
  created_date TIMESTAMP
);
TYPE overlay_list IS TABLE OF overlay_rec INDEX BY VARCHAR2(50);
g_overlays overlay_list;
g_overlay_count PLS_INTEGER := 0;

TYPE pdf_document_rec IS RECORD (
  pdf_id VARCHAR2(50),
  pdf_blob BLOB,
  page_count PLS_INTEGER,
  file_size NUMBER,
  pdf_version VARCHAR2(10),
  xref_offset PLS_INTEGER,
  root_obj_id PLS_INTEGER,

  pages JSON_ARRAY_T,
  objects JSON_OBJECT_T,
  xref_table JSON_OBJECT_T,
  trailer JSON_OBJECT_T,
  loaded_date TIMESTAMP
);

TYPE pdf_collection IS TABLE OF pdf_document_rec INDEX BY VARCHAR2(50);
g_loaded_pdfs pdf_collection;
g_loaded_pdf_count PLS_INTEGER := 0;

c_max_loaded_pdfs CONSTANT PLS_INTEGER := 10;

TYPE pdf_source_rec IS RECORD (
  doc       BLOB,
  xref      xref_table_type,

  objstm    tv32k,

  root      PLS_INTEGER,
  info      PLS_INTEGER,
  pages     tpi,
  media     tv32k,
  resources tv32k,
  cropbox   tv32k,
  rotate    tv32k,
  rot_force tv32k,

  ovl_ops   tv32k,
  ovl_res   tv32k,

  ovl_img_dic tv32k,
  ovl_img_dat tblob,

  ovl_msk_dic tv32k,
  ovl_msk_dat tblob,
  ovl_img_pag tpi
);
TYPE pdf_source_list IS TABLE OF pdf_source_rec INDEX BY PLS_INTEGER;

g_encrypt_method VARCHAR2(20) := NULL;
g_user_password VARCHAR2(100) := NULL;
g_owner_password VARCHAR2(100) := NULL;
g_sec_permissions PLS_INTEGER := -1;
g_encrypt_obj_num PLS_INTEGER := NULL;
g_file_id RAW(16) := NULL;
g_o_value RAW(32) := NULL;
g_u_value RAW(32) := NULL;
g_encryption_key RAW(16) := NULL;

c_PDF_PADDING CONSTANT RAW(32) := HEXTORAW(
  '28BF4E5E4E758A4164004E56FFFA0108' ||
  '2E2E00B6D0683E802F0CA9FE6453697A'
);

procedure p_flush_doc_buf;
procedure p_flush_page_buf;
procedure p_ensure_page_clob(p_page in pls_integer);
procedure p_free_pages;

function p_assert_callback_name(p_name in varchar2) return varchar2;
function buildPlsqlStatment(callbackProc in varchar2,
                            tParam in tv4000a default noParam) return varchar2;

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

procedure print (pstr in varchar2) is
begin

  htp.p(pstr);

end print;

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

function getPDFDocLength return pls_integer is
begin
  p_flush_doc_buf;
  return nvl(dbms_lob.getlength(pdfDoc), 0);
exception
  when others then
   error('getPDFDocLength : '||sqlerrm);
   return -1;
end getPDFDocLength;

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

procedure p_includeFont (pfontname in varchar2) is
  mySet charSet;
begin
  if pfontname is null then
    return;
  end if;
  mySet := p_larguras_da_fonte(pfontname);

  if mySet.count > 0 then
    fpdf_charwidths(pfontname) := mySet;
  end if;
end p_includeFont;

function p_getFontMetrics(pFontName in varchar2) return charSet is
begin
  return p_larguras_da_fonte(pFontName);
end p_getFontMetrics;

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

    dbms_output.put_line(l_log_text);

    begin
      dbms_application_info.set_client_info(substr(l_log_text, 1, 64));
    exception
      when others then
        null;
    end;
  end if;
end log_message;

procedure SetLogLevel(p_level pls_integer) is
begin

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

function GetLogLevel return pls_integer is
begin
  return g_log_level;
end GetLogLevel;

procedure init_page_formats is
begin
  if g_formats_initialized then
    return;
  end if;

  g_page_formats('A3').width := 297;
  g_page_formats('A3').height := 420;

  g_page_formats('A4').width := 210;
  g_page_formats('A4').height := 297;

  g_page_formats('A5').width := 148;
  g_page_formats('A5').height := 210;

  g_page_formats('LETTER').width := 215.9;
  g_page_formats('LETTER').height := 279.4;

  g_page_formats('LEGAL').width := 215.9;
  g_page_formats('LEGAL').height := 355.6;

  g_page_formats('LEDGER').width := 279.4;
  g_page_formats('LEDGER').height := 431.8;

  g_page_formats('TABLOID').width := 279.4;
  g_page_formats('TABLOID').height := 431.8;

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

function get_page_format(p_format_name varchar2) return recPageFormat is
  l_format recPageFormat;
  l_format_upper varchar2(20) := upper(p_format_name);
begin

  if not g_formats_initialized then
    init_page_formats();
  end if;

  if g_page_formats.exists(l_format_upper) then
    l_format := g_page_formats(l_format_upper);
  else

    raise_application_error(-20103,
      'Unknown page format: ' || p_format_name || '. Use A3, A4, A5, Letter, Legal, Ledger, Executive, Folio, B5, or custom format like "100,200"');
  end if;

  return l_format;
end get_page_format;

function parse_png_header(p_blob blob, p_img in out recImageBlob) return boolean is
  l_signature raw(8);
  l_chunk_length raw(4);
  l_chunk_type raw(4);
  l_ihdr_data raw(13);
  l_pos integer := 1;
  c_png_signature constant raw(8) := hextoraw('89504E470D0A1A0A');
begin

  if dbms_lob.getlength(p_blob) < 33 then
    return false;
  end if;

  l_signature := dbms_lob.substr(p_blob, 8, 1);
  if l_signature != c_png_signature then
    return false;
  end if;

  l_pos := 9;
  l_chunk_length := dbms_lob.substr(p_blob, 4, l_pos);
  l_pos := l_pos + 4;
  l_chunk_type := dbms_lob.substr(p_blob, 4, l_pos);
  l_pos := l_pos + 4;

  if l_chunk_type != hextoraw('49484452') then
    return false;
  end if;

  l_ihdr_data := dbms_lob.substr(p_blob, 13, l_pos);

  p_img.width := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 1, 4), utl_raw.big_endian);

  p_img.height := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 5, 4), utl_raw.big_endian);

  p_img.bit_depth := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 9, 1));

  p_img.color_type := utl_raw.cast_to_binary_integer(utl_raw.substr(l_ihdr_data, 10, 1));

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

function parse_jpeg_header(p_blob blob, p_img in out recImageBlob) return boolean is
  l_marker raw(2);
  l_pos integer := 1;
  l_length integer;
  l_seg_length raw(2);
  l_seg_len integer;
  l_data raw(32767);
  c_soi constant raw(2) := hextoraw('FFD8');
  c_sof0 constant raw(2) := hextoraw('FFC0');
  c_sof2 constant raw(2) := hextoraw('FFC2');
begin
  l_length := dbms_lob.getlength(p_blob);

  if l_length < 4 then
    return false;
  end if;

  l_marker := dbms_lob.substr(p_blob, 2, 1);
  if l_marker != c_soi then
    return false;
  end if;

  l_pos := 3;

  while l_pos < l_length - 10 loop
    l_marker := dbms_lob.substr(p_blob, 2, l_pos);

    if l_marker = c_sof0 or l_marker = c_sof2 then

      l_seg_length := dbms_lob.substr(p_blob, 2, l_pos + 2);
      l_seg_len := utl_raw.cast_to_binary_integer(l_seg_length, utl_raw.big_endian);

      l_data := dbms_lob.substr(p_blob, 9, l_pos + 2);

      p_img.bit_depth := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 3, 1));

      p_img.height := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 4, 2), utl_raw.big_endian);

      p_img.width := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 6, 2), utl_raw.big_endian);

      p_img.color_type := utl_raw.cast_to_binary_integer(utl_raw.substr(l_data, 8, 1));

      p_img.has_transparency := false;
      p_img.file_format := 'JPEG';
      p_img.mime_type := 'image/jpeg';

      log_message(4, 'JPEG parsed: ' || p_img.width || 'x' || p_img.height ||
                  ', bit_depth=' || p_img.bit_depth || ', components=' || p_img.color_type);

      return true;
    end if;

    if utl_raw.substr(l_marker, 1, 1) = hextoraw('FF') then

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

function getImageFromUrl(p_Url in varchar2) return recImageBlob is
  l_img recImageBlob;
  lv_url varchar2(2000) := p_Url;
  urityp URIType;
  l_parsed boolean := false;
begin

  dbms_lob.createtemporary(l_img.image_blob, true, dbms_lob.session);

  if instr(lv_url, 'http') = 0 then
    lv_url := 'http://' || owa_util.get_cgi_env('SERVER_NAME') || '/' || lv_url;
  end if;

  log_message(4, 'Fetching image from URL: ' || lv_url);

  begin

    urityp := URIFactory.getURI(lv_url);
    l_img.image_blob := urityp.getBlob();
    l_img.mime_type := urityp.getContentType();

    log_message(4, 'Image fetched, MIME type: ' || l_img.mime_type ||
                ', size: ' || dbms_lob.getlength(l_img.image_blob) || ' bytes');

  exception
    when others then
      raise_application_error(-20302, 'Unable to fetch image from URL: ' || p_Url || ' - ' || sqlerrm);
  end;

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

procedure DebugEnabled is
begin
  gb_mode_debug := true;
end DebugEnabled;

procedure DebugDisabled is
begin
  gb_mode_debug := false;
end DebugDisabled;

function GetScaleFactor return number is
begin

	return k;
end GetScaleFactor;

function GetLineSpacing return number is
begin

	return LineSpacing;
end GetLineSpacing;

Procedure SetLineSpacing (pls in number) is
begin

    LineSpacing := pls;
end SetLineSpacing;

function nao_e_numero(p_txt in varchar2) return boolean is
begin
  return p_txt is not null
     and to_number(p_txt default null on conversion error) is null;
end nao_e_numero;

function tonumber(v_str in varchar2) return number is
   v_num number;
   v_str2 varchar2(255);
begin

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

procedure p_dochecks is
begin

  null;
end p_dochecks;

procedure p_ensure_page_clob(p_page in pls_integer) is
begin
  if not pages.exists(p_page) then
    pages(p_page) := null;
  end if;
  if pages(p_page) is null then
    dbms_lob.createtemporary(pages(p_page), true, dbms_lob.session);
  end if;
end p_ensure_page_clob;

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

procedure p_flush_doc_buf is
  l_len pls_integer;
begin
  l_len := nvl(length(g_doc_buf), 0);
  if l_len > 0 then
    dbms_lob.writeappend(pdfDoc, l_len, g_doc_buf);
  end if;
  g_doc_buf := null;
end p_flush_doc_buf;

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

procedure p_out(pstr in varchar2 default null, pCRLF in boolean default true) is
lv_CRLF varchar2(2);
  lv_output varchar2(32767);
begin

  if (pCRLF) then
    lv_CRLF := chr(10);
  end if;

  lv_output := pstr || lv_CRLF;

  if(state = 2) then

    if g_page_buf_page is not null and g_page_buf_page != page then
      p_flush_page_buf;
    end if;
    if nvl(lengthb(g_page_buf), 0) + nvl(lengthb(lv_output), 0) > co_page_buf_limit then
      p_flush_page_buf;
    end if;
    g_page_buf_page := page;
    g_page_buf := g_page_buf || lv_output;
  else

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

procedure p_newobj is
begin

	n := n + 1;
	offsets(n) := getPDFDocLength();
	p_out(n || ' 0 obj');
exception
  when others then
   error('p_newobj : '||sqlerrm);
end p_newobj;

function p_winansi_byte(p_car in varchar2) return pls_integer is
  l_asc varchar2(24);
  l_cp  pls_integer;
begin
  if p_car is null then
    return null;
  end if;

  l_asc := asciistr(p_car);
  if l_asc = '\\' then
    l_cp := 92;
  elsif substr(l_asc, 1, 1) = '\' then
    l_cp := to_number(substr(l_asc, 2, 4), 'XXXX');
  else
    l_cp := ascii(p_car);
  end if;

  case l_cp
    when 8364 then return 128;
    when 8218 then return 130;
    when 402 then return 131;
    when 8222 then return 132;
    when 8230 then return 133;
    when 8224 then return 134;
    when 8225 then return 135;
    when 710 then return 136;
    when 8240 then return 137;
    when 352 then return 138;
    when 8249 then return 139;
    when 338 then return 140;
    when 381 then return 142;
    when 8216 then return 145;
    when 8217 then return 146;
    when 8220 then return 147;
    when 8221 then return 148;
    when 8226 then return 149;
    when 8211 then return 150;
    when 8212 then return 151;
    when 732 then return 152;
    when 8482 then return 153;
    when 353 then return 154;
    when 8250 then return 155;
    when 339 then return 156;
    when 382 then return 158;
    when 376 then return 159;
    else
      if l_cp between 0 and 127 or l_cp between 160 and 255 then
        return l_cp;
      end if;
      return null;
  end case;
end p_winansi_byte;

function p_texto_pdf(p_txt in varchar2) return varchar2 is
  l_saida varchar2(32767);
  l_car   varchar2(4);
  l_byte  pls_integer;
begin
  if p_txt is null then
    return null;
  end if;

  for i in 1 .. length(p_txt) loop
    l_car  := substr(p_txt, i, 1);
    l_byte := p_winansi_byte(l_car);

    if l_byte is null then
      raise_application_error(-20203,
        'Caractere fora de WinAnsi na posicao ' || i || ': ' || l_car
        || '. As fontes padrao do PDF so alcancam WinAnsi; para outras '
        || 'escritas, embuta uma fonte TrueType.');
    end if;

    if l_byte in (40, 41, 92) then
      l_saida := l_saida || '\' || chr(l_byte);
    elsif l_byte between 32 and 126 then
      l_saida := l_saida || chr(l_byte);
    else

      l_saida := l_saida
                 || '\' || to_char(trunc(l_byte / 64))
                 || to_char(trunc(mod(l_byte, 64) / 8))
                 || to_char(mod(l_byte, 8));
    end if;
  end loop;

  return l_saida;
end p_texto_pdf;

function p_escapa_pdf(p_txt in varchar2) return varchar2 is
begin
  return replace(replace(replace(p_txt, '\', '\\'), '(', '\('), ')', '\)');
end p_escapa_pdf;

function p_textstring(pstr in varchar2) return varchar2 is
begin

	return '(' || UTF8ToPDFString(pstr, true) || ')';
end p_textstring;

procedure p_putstream_clob(pdata in clob) is
  l_off   pls_integer := 1;
  l_size  pls_integer := 8000;
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

procedure p_putstream(pstr in varchar2) is
begin
	p_out('stream');
	p_out(pstr);
	p_out('endstream');
exception
  when others then
   error('p_putstream : '||sqlerrm);
end p_putstream;

procedure p_putstream(pData in out NOCOPY blob) is
	lv_content_length number := dbms_lob.getlength(pdata);
	offset integer := 1;
	buf_size integer;
	buf raw(2000);
begin
	p_out('stream');

	while offset <= lv_content_length loop

	  buf_size := 2000;
	  dbms_lob.read(pData,buf_size,offset,buf);
	  p_out(rawtohex(buf), false);
	  offset := offset + buf_size;
	end loop;

	p_out('>');
	p_out('endstream');
exception
  when others then
   error('p_putstream : '||sqlerrm);
end p_putstream;

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

procedure p_putfonts is
nf number := n;
i pls_integer;
l_chave car;
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

begin
    null;
	i := diffs.first;
	while (i is not null)
	loop

		p_newobj();
		p_out('<</Type /Encoding /BaseEncoding /WinAnsiEncoding /Differences ['|| diffs(i) ||']>>');
		p_out('endobj');
	    i:= diffs.next(i);
	end loop;

	g_ttf_obj.delete;
	k := fonts.first;
	while k is not null loop
	  if lower(fonts(k).type) = 'truetype'
	     and fonts(k).file is not null
	     and g_ttf_fonts.exists(fonts(k).file)
	     and not g_ttf_obj.exists(fonts(k).file) then
	    declare
	      l_prog blob := g_ttf_fonts(fonts(k).file).font_blob;
	      l_tam  number := dbms_lob.getlength(l_prog);
	      l_off  number := 1;
	    begin
	      p_newobj();
	      g_ttf_obj(fonts(k).file) := n;
	      p_out('<</Filter /ASCIIHexDecode /Length ' || (l_tam * 2 + 1)
	            || ' /Length1 ' || l_tam || '>>');
	      p_out('stream');
	      while l_off <= l_tam loop
	        p_out(rawtohex(dbms_lob.substr(l_prog, 2000, l_off)), false);
	        l_off := l_off + 2000;
	      end loop;
	      p_out('>');
	      p_out('endstream');
	      p_out('endobj');
	    end;
	  end if;
	  k := fonts.next(k);
	end loop;

	v := FontFiles.first;
	while (v is not null)
	loop

		p_newobj();
		FontFiles(v).n:= n;
		myFont := null;

		mySet := p_getFontMetrics(FontFiles(v).file);

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

				myFont := substr(myFont,6);
			end if;

			if(myHeader and ascii(substr(myFont,(FontFiles(v).length1), 1)) = 128) then

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

		fonts(k).n := n+1;
		myType := fonts(k).type;
		myName := fonts(k).name;
		if(myType = 'core') then

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

			p_newobj();

			cw := fonts(k).cw;
			s := '[';
			for i in 32..255 loop
				s := s || cw(chr(i)) || ' ';
		    end loop;
			p_out(s || ']');
			p_out('endobj');

			p_newobj();
			s := '<</Type /FontDescriptor /FontName /' || myName;

			if fonts(k).dsc.count > 0 then
			  for l in fonts(k).dsc.first..fonts(k).dsc.last loop
				s := s || ' /' || l || ' ' || fonts(k).dsc(l);
			  end loop;
			end if;

			myFile := fonts(k).file;
			if (myFile is not null and g_ttf_obj.exists(myFile)) then

			  s := s || ' /Flags ' || g_ttf_fonts(myFile).flags
			        || ' /FontBBox [' || tochar(g_ttf_fonts(myFile).bbox_xmin)
			        || ' ' || tochar(g_ttf_fonts(myFile).bbox_ymin)
			        || ' ' || tochar(g_ttf_fonts(myFile).bbox_xmax)
			        || ' ' || tochar(g_ttf_fonts(myFile).bbox_ymax) || ']'
			        || ' /ItalicAngle ' || tochar(g_ttf_fonts(myFile).italic_angle)
			        || ' /Ascent ' || tochar(g_ttf_fonts(myFile).ascent)
			        || ' /Descent ' || tochar(g_ttf_fonts(myFile).descent)
			        || ' /CapHeight ' || tochar(g_ttf_fonts(myFile).cap_height)

			        || ' /StemV 80'
			        || ' /FontFile2 ' || g_ttf_obj(myFile) || ' 0 R';
			elsif (myFile is not null) then
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

			methode := 'p_put' || lower(myType);

			if(not methode_exists(methode)) then
				Error('Unsupported font type: ' || myType);

			end if;
		end if;

		k := fonts.next(k);
	end loop;
exception
  when others then
   error('p_putfonts : '||sqlerrm);
end p_putfonts;

procedure p_putimages is
  info recImage;
  v txt;
  trns txt;
  pal  raw(8192);
begin

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
			p_out('/ColorSpace [/Indexed /DeviceRGB ' || to_char(utl_raw.length(info.pal) / 3 - 1) || ' ' || to_char(n+1) || ' 0 R]');
		else
			p_out('/ColorSpace /' || info.cs);
			if(info.cs = 'DeviceCMYK') then
				p_out('/Decode (1 0 1 0 1 0 1 0)');
			end if;
		end if;

		p_out('/BitsPerComponent ' || info.bpc);

		if(info.f is not null) then
			p_out('/Filter [/ASCIIHexDecode /' || info.f || ']');
		else
			p_out('/Filter /ASCIIHexDecode');
		end if;
		if(info.parms is not null) then

			if(info.f is not null) then
				p_out(replace(info.parms, '/DecodeParms ', '/DecodeParms [null ')
				      || ']');
			else
				p_out(info.parms);
			end if;
		end if;

		if(info.trns.first is not null ) then
			 trns := '';
			for i in info.trns.first..info.trns.count  loop
				 trns := trns || info.trns(i) || ' ' || info.trns(i) || ' ';
			end loop;
			p_out('/Mask (' || trns || ')');
		end if;

		p_out('/Length ' || (dbms_lob.getlength(info.data) * 2 + 1) || '>>');
		p_putstream(info.data);
		images(v).data := null;
		p_out('endobj');

		if(info.cs = 'Indexed') then
			p_newobj();

			 pal := info.pal;

			p_out('<</Filter /ASCIIHexDecode /Length '
			      || (utl_raw.length(pal) * 2 + 1) || '>>');
			p_out('stream');
			p_out(rawtohex(pal), false);
			p_out('>');
			p_out('endstream');
			p_out('endobj');
		end if;
		v := images.next(v);
	end loop;
exception
  when others then
    error('p_putimages : '||sqlerrm);
end p_putimages;

procedure p_putresources is
begin
	p_putfonts();
	p_putimages();

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

procedure p_putheader is
begin
	p_out('%PDF-' || PDFVersion);
end p_putheader;

procedure p_puttrailer is
  l_id_hex VARCHAR2(100);
begin
  p_out('/Size ' || (n+1));
  p_out('/Root ' || n || ' 0 R');
  p_out('/Info ' || (n-1) || ' 0 R');

  IF g_encrypt_obj_num IS NOT NULL THEN
    p_out('/Encrypt ' || g_encrypt_obj_num || ' 0 R');
  END IF;

  IF g_file_id IS NOT NULL THEN
    l_id_hex := RAWTOHEX(g_file_id);
    p_out('/ID [<' || l_id_hex || '><' || l_id_hex || '>]');
  END IF;
end p_puttrailer;

FUNCTION generate_file_id RETURN RAW;
FUNCTION compute_owner_key(p_owner_pwd VARCHAR2, p_user_pwd VARCHAR2, p_key_length PLS_INTEGER) RETURN RAW;
FUNCTION compute_owner_value(p_owner_pwd VARCHAR2, p_user_pwd VARCHAR2, p_key_length PLS_INTEGER) RETURN RAW;
FUNCTION compute_encryption_key(p_user_pwd VARCHAR2, p_o_value RAW, p_permissions PLS_INTEGER, p_file_id RAW, p_key_length PLS_INTEGER) RETURN RAW;
FUNCTION compute_user_value(p_encryption_key RAW, p_file_id RAW, p_key_length PLS_INTEGER) RETURN RAW;

procedure p_putencrypt is
  l_v_value PLS_INTEGER;
  l_r_value PLS_INTEGER;
  l_key_length PLS_INTEGER;
begin
  IF g_encrypt_method IS NULL THEN
    RETURN;
  END IF;

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

  IF g_file_id IS NULL THEN
    g_file_id := generate_file_id();
  END IF;

  g_o_value := compute_owner_value(g_owner_password, g_user_password, l_key_length);
  g_encryption_key := compute_encryption_key(g_user_password, g_o_value, g_sec_permissions, g_file_id, l_key_length);
  g_u_value := compute_user_value(g_encryption_key, g_file_id, l_key_length);

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

procedure p_endpage is
begin

	state:=1;
end p_endpage;

procedure p_putpages is
   nb number := page;
   filter varchar2(200);

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

   p_flush_page_buf;

	 if AliasNbPages is not null then
		   for i in 1..nb loop
		      if pages.exists(i) and dbms_lob.getlength(pages(i)) > 0 then
		         declare
		           l_new    clob;
		           l_off    pls_integer := 1;
		           l_size   pls_integer := 8000;
		           l_carry  varchar2(32767);
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

	 filter := '';

   for i in 1..nb loop

		  p_newobj();
		  p_out('<</Type /Page');
		  p_out('/Parent 1 0 R');
		  if(OrientationChanges.exists(i)) then
			   p_out('/MediaBox [0 0 '||tochar(hPt)||' '||tochar(wPt)||']');
	    end if;
		  p_out('/Resources 2 0 R');

      if(PageLinks.exists(i) and PageLinks(i).quatre is not null) then

			   annots := '/Annots [';

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

         end if;

			   p_out(annots || ']');
      end if;

		  p_out('/Contents ' || to_char(n+1) || ' 0 R>>');
		  p_out('endobj');

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
        l_tam := dbms_lob.getlength(l_z) * 2 + 1;
        if l_tam >= dbms_lob.getlength(pages(i)) then
          l_tam := 0;
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

	 offsets(1):=getPDFDocLength();
	 p_out('1 0 obj');
	 p_out('<</Type /Pages');
	 kids := '/Kids [';

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

procedure p_enddoc is
o number;
begin

	p_putheader();

	p_putpages();

	p_putresources();

	p_newobj();
	p_out('<<');
	p_putinfo();
	p_out('>>');
	p_out('endobj');

	p_newobj();
	p_out('<<');
	p_putcatalog();
	p_out('>>');
	p_out('endobj');

	IF g_encrypt_method IS NOT NULL THEN
	  p_putencrypt();
	END IF;

	o := getPDFDocLength();
	p_out('xref');
	p_out('0 ' || (n+1));
	p_out('0000000000 65535 f ');

	for i in 1..n
	loop
	  p_out(substr('0000000000', 1, 10 - length(offsets(i)) ) ||offsets(i) || ' 00000 n ');
	end loop;

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

procedure p_beginpage(orientation in varchar2) is
Myorientation word := orientation;
begin
	p_flush_page_buf;
	page := page + 1;
	p_ensure_page_clob(page);
	dbms_lob.trim(pages(page), 0);
	state:=2;
	x:=lMargin;
	y:=tMargin;
	FontFamily:='';

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

function p_parseImage(pFile in varchar2,
                      p_blob in blob default null) return recImage is
  myImg recImageBlob;
  myImgInfo recImage;
  myblob blob;
  chunk_content blob;

  signature_len integer := 8;
  chunklength_len integer := 4;
  chunktype_len integer := 4;
  chunkdata_len integer;
  widthheight_len integer := 8;
  hdrflag_len integer := 1;
  crc_len integer := 4;
  chunk_num integer := 0;

  f number default 1;
  f_chunk number default 1;
  bufRaw raw(32000);
  ct word;
  colors pls_integer;
  myType word;

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

begin
  dbms_lob.createtemporary(chunk_content, true );
  dbms_lob.open(chunk_content,dbms_lob.LOB_READWRITE);

  dbms_lob.createtemporary(imgBlob, true );
  myImgInfo.data := imgBlob;
  dbms_lob.open(myImgInfo.data,dbms_lob.LOB_READWRITE);

  if p_blob is null then
    myImg := getImageFromUrl(pFile);
  else

    myImg.image_blob := p_blob;
    if not parse_png_header(p_blob, myImg) then
      raise_application_error(-20301, 'Invalid PNG header in image: ' || pFile);
    end if;
  end if;
  myblob := myImg.image_blob;
  myImgInfo.i := 1;

    if(utl_raw.compare(freadb(myblob, f, signature_len), c_PNG_SIGNATURE) != 0) then
        Error('Not a PNG file: ' || pFile);
    end if;

  myImgInfo.w := myImg.width;
  myImgInfo.h := myImg.height;

    loop

        chunkdata_len := utl_raw.cast_to_binary_integer(freadb(myblob, f, chunklength_len));
        myType := fread(myblob, f, chunktype_len);

    if( chunkdata_len > 0 ) then
      fread_blob(myblob,f,chunkdata_len,chunk_content);
      f_chunk := 1;
    end if;
    chunk_num := chunk_num + 1;

    bufRaw := freadb(myblob, f, crc_len);
    if( chunk_num = 1 and myType != 'IHDR' ) then
      Error('Incorrect PNG file: ' || pFile);
    elsif(myType = 'IHDR') then

      bufRaw := freadb(chunk_content, f_chunk, widthheight_len);

      myImgInfo.bpc := to_number(rawtohex(freadb(chunk_content, f_chunk, hdrflag_len)), 'XX');
      if( myImgInfo.bpc > 8) then
        Error('16-bit depth not supported: ' || pFile);
      end if;

      ct := to_number(rawtohex(freadb(chunk_content, f_chunk, hdrflag_len)), 'XX');
      if( ct = 0 ) then
        myImgInfo.cs := 'DeviceGray';
      elsif( ct = 2 ) then
        myImgInfo.cs := 'DeviceRGB';
      elsif( ct = 3 ) then
        myImgInfo.cs := 'Indexed';
      else
        Error('Alpha channel not supported: ' || pFile);
        end if;
      if( to_number(rawtohex(freadb(chunk_content, f_chunk, hdrflag_len)), 'XX') != 0 ) then
        Error('Unknown compression method: ' || pFile);
      end if;
      if( to_number(rawtohex(freadb(chunk_content, f_chunk, hdrflag_len)), 'XX') != 0 ) then
        Error('Unknown filter method: ' || pFile);
      end if;
      if( to_number(rawtohex(freadb(chunk_content, f_chunk, hdrflag_len)), 'XX') != 0 ) then
        Error('Interlacing not supported: ' || pFile);
      end if;
      if (ct = 2 ) then
        colors := 3;
      else
        colors := 1;
      end if;

      myImgInfo.parms := '/DecodeParms <</Predictor 15 /Colors ' || to_char(colors) || ' /BitsPerComponent ' || myImgInfo.bpc || ' /Columns ' || myImgInfo.w || '>>';

        elsif(myType = 'PLTE') then

            myImgInfo.pal := freadb(chunk_content, f_chunk, chunkdata_len);
        elsif(myType = 'tRNS') then

            bufRaw := freadb(chunk_content, f_chunk, chunkdata_len);
            if(ct = 0) then
                myImgInfo.trns(1) := to_number(rawtohex(utl_raw.substr(bufRaw,1,1)),'XX');
            elsif( ct = 2) then
               myImgInfo.trns(1) := to_number(rawtohex(utl_raw.substr(bufRaw,1,1)),'XX');
               myImgInfo.trns(2) := to_number(rawtohex(utl_raw.substr(bufRaw,3,1)),'XX');
               myImgInfo.trns(3) := to_number(rawtohex(utl_raw.substr(bufRaw,5,1)),'XX');
            else

                for k in 1..utl_raw.length(bufRaw) loop
                  if utl_raw.substr(bufRaw,k,1) = hextoraw('00') then
                    myImgInfo.trns(1) := k;
                    exit;
                  end if;
                end loop;
            end if;
        elsif(myType = 'IDAT') then

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

procedure Error(pmsg in varchar2) is
  v_clob_content varchar2(32767);
begin
    if gb_mode_debug then
	  print('<pre>');

	  begin
	    p_flush_doc_buf;
	  exception
	    when others then null;
	  end;
	  if pdfDoc is not null and dbms_lob.getlength(pdfDoc) > 0 then
	    v_clob_content := dbms_lob.substr(pdfDoc, 32767, 1);

	    print(replace(replace(v_clob_content,'>','&' || 'gt;'),
	                  '<','&' || 'lt;'));
	  end if;
	  print('</pre>');
	end if;

	declare
	  l_backtrace varchar2(4000);
	  l_msg       varchar2(2000);
	begin
	  begin
	    l_backtrace := dbms_utility.format_error_backtrace;
	  exception
	    when others then l_backtrace := null;
	  end;

	  l_msg := 'PL_FPDF: ' || pmsg;
	  if l_backtrace is not null then
	    l_msg := l_msg || chr(10) || '== origem ==' || chr(10) || l_backtrace;
	  end if;

	  raise_application_error(-20100, substr(l_msg, 1, 1900), true);
	end;
end Error;

function GetCurrentFontSize return number is
begin

	return fontsizePt;
end GetCurrentFontSize;

function GetCurrentFontStyle return varchar2 is
begin

	return fontStyle;
end GetCurrentFontStyle;

function GetCurrentFontFamily return varchar2 is
begin

	return FontFamily;
end GetCurrentFontFamily;

procedure Ln(h number default null) is
begin

	x :=lMargin;
	if(nao_e_numero(h)) then
		y:= y + lasth;
	else
		y:= y + h;
    end if;
end Ln;

function GetX return number is
begin

	return x;
end GetX;

procedure SetX(px in number) is
begin

	if(px>=0) then
		x:=px;
	else
		x:=w+px;
	end if;
end SetX;

function GetY return number is
begin

	return y;
end GetY;

procedure SetY(py in number) is
begin

	x:=lMargin;
	if(py>=0) then
		y:=py;
	else
		y:=h+py;
	end if;
end SetY;

procedure SetXY(x in number,y in number) is
begin

	SetY(y);
	SetX(x);
end SetXY;

procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam) is
begin

   MyHeader_Proc := p_assert_callback_name(headerprocname);
   MyHeader_ProcParam := paramTable;
   if MyHeader_Proc is not null then
     MyHeader_Stmt := buildPlsqlStatment(MyHeader_Proc, MyHeader_ProcParam);
   else
     MyHeader_Stmt := null;
   end if;
end;

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

procedure SetMargins(left in number, top in number, right in number default -1) is
myright margin := right;
begin

	lMargin:=left;
	tMargin:=top;
	if(myright=-1) then
		myright:=left;
	end if;
	rMargin:=myright;
end SetMargins;

procedure SetLeftMargin(pMargin in number) is
begin

	lMargin:=pMargin;
	if(page > 0 and  x < pMargin) then
		x:= pMargin;
	end if;
end SetLeftMargin;

procedure SetTopMargin(pMargin in number) is
begin

	tMargin := pMargin;
end SetTopMargin;

procedure SetRightMargin(pMargin in number) is
begin

	rMargin := pMargin;
end SetRightMargin;

procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0) is
begin

	AutoPageBreak := pauto;
	bMargin := pMargin;
	pageBreakTrigger:=h-pMargin;
end SetAutoPageBreak;

procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous') is
begin

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

procedure SetCompression(p_compress in boolean default false) is
begin

	b_compress := nvl(p_compress, false);
end SetCompression;

procedure SetTitle(ptitle in varchar2) is
begin

	title:=ptitle;
end SetTitle;

procedure SetSubject(psubject in varchar2) is
begin

	subject:= psubject;
end SetSubject;

procedure SetAuthor(pauthor in varchar2) is
begin

	author:=pauthor;
end SetAuthor;

procedure SetKeywords(pkeywords in varchar2) is
begin

	keywords:=pkeywords;
end SetKeywords;

procedure SetCreator(pcreator in varchar2) is
begin

	creator:=pcreator;
end SetCreator;

procedure SetAliasNbPages(palias in varchar2 default '{nb}') is
begin

	AliasNbPages:=palias;
end SetAliasNbPages;

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

function buildPlsqlStatment(callbackProc in varchar2,
                            tParam in tv4000a default noParam) return varchar2 is
    plsqStmt bigtext;
    paramName word;
begin
    if (tParam.first is not null) then

        plsqStmt := 'Begin '||callbackProc||'(';
        paramName := tParam.first;
        while (paramName is not null) loop
            if (paramName != tParam.first) then
                plsqStmt := plsqStmt || ', ';
            end if;

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

procedure Header is
    plsqStmt bigtext;
begin

	if (MyHeader_Stmt is not null) then

        plsqStmt := MyHeader_Stmt;
        execute immediate plsqStmt;
	end if;
exception
    when others then
        error('Header : '||sqlerrm||' statment : '||plsqStmt);
end Header;

procedure Footer is
    plsqStmt bigtext;
begin

	if (MyFooter_Stmt is not null) then

        plsqStmt := MyFooter_Stmt;
	   execute immediate plsqStmt;
	end if;
exception
    when others then
        error('Footer : '||sqlerrm||' statment : '||plsqStmt);
end Footer;

function PageNo return number is
begin

	return page;
end PageNo;

procedure SetDrawColor(r in number, g in number default -1, b in number default -1) is
begin

	if r < c_MIN_COLOR_VALUE or r > c_MAX_COLOR_VALUE then
		raise_application_error(-20501, 'Invalid red value: ' || r || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if g <> -1 and (g < c_MIN_COLOR_VALUE or g > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid green value: ' || g || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if b <> -1 and (b < c_MIN_COLOR_VALUE or b > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid blue value: ' || b || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if((r=0 and g=0 and b=0) or g=-1)  then
		DrawColor:=tochar(r/255,3)||' G';
	else
		DrawColor:=tochar(r/255,3) || ' ' || tochar(g/255,3) || ' ' || tochar(b/255,3) || ' RG';
	end if;
	if(page>0) then
		p_out(DrawColor);
	end if;
end SetDrawColor;

procedure SetFillColor (r in number, g in number default -1, b in number default -1) is
begin

	if r < c_MIN_COLOR_VALUE or r > c_MAX_COLOR_VALUE then
		raise_application_error(-20501, 'Invalid red value: ' || r || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if g <> -1 and (g < c_MIN_COLOR_VALUE or g > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid green value: ' || g || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if b <> -1 and (b < c_MIN_COLOR_VALUE or b > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid blue value: ' || b || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

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

procedure SetTextColor (r in number, g in number default -1, b in number default -1) is
begin

	if r < c_MIN_COLOR_VALUE or r > c_MAX_COLOR_VALUE then
		raise_application_error(-20501, 'Invalid red value: ' || r || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if g <> -1 and (g < c_MIN_COLOR_VALUE or g > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid green value: ' || g || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

	if b <> -1 and (b < c_MIN_COLOR_VALUE or b > c_MAX_COLOR_VALUE) then
		raise_application_error(-20501, 'Invalid blue value: ' || b || '. Must be ' || c_MIN_COLOR_VALUE || '-' || c_MAX_COLOR_VALUE);
	end if;

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

procedure SetLineWidth(width in number) is
begin

	if width <= 0 then
		raise_application_error(-20502, 'Invalid line width: ' || width || '. Must be positive');
	end if;

	LineWidth:=width;
	if(page>0) then
		p_out(tochar(width*k,2) ||' w');
	end if;
end SetLineWidth;

procedure Line(x1 in number, y1 in number, x2 in number, y2 in number) is
begin

	p_out( tochar(x1*k,2) ||
		   ' ' || tochar((h-y1)*k,2) ||
		   ' m ' || tochar(x2*k,2) ||
		   ' ' || tochar((h-y2)*k,2) || ' l S');
end Line;

procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '') is
op word;
begin

	if(pstyle='F') then
		op:='f';
	elsif(pstyle='FD' or pstyle='DF') then
		op:='B';
	else
		op:='S';
	end if;
	p_out(tochar(px*k,2) || ' ' || tochar((h-py)*k,2) || ' ' || tochar(pw*k,2) || ' ' || tochar(-ph*k,2) || ' re ' || op);
end Rect;

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

    p_out(pdf_cmd);
end;

procedure SetLineDashPattern(pdash in varchar2 default '[] 0') is
begin
    p_out(pdash || ' d');
end;

function AddLink return number is
begin

  raise_application_error(-20601,
    'AddLink: link interno NAO esta implementado. O /Dest nunca e escrito no ' ||
    'arquivo, e o Link recusa o identificador que esta funcao devolveria. ' ||
    'Use Link(x, y, w, h, ''https://...'') ou o parametro plink das rotinas ' ||
    'de texto com uma URL. Ver docs/ROADMAP.md, pendencias.');
  return null;
end AddLink;

procedure SetLink(plink in number, py in number default 0, ppage in number default -1) is
begin

  raise_application_error(-20601,
    'SetLink: link interno NAO esta implementado. O destino nao chega ao ' ||
    'arquivo: o /Dest nunca e escrito e o Link recusa o identificador. ' ||
    'Use uma URL. Ver docs/ROADMAP.md, pendencias.');
end SetLink;

procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2) is
begin

  if not nvl(nao_e_numero(plink), false) then
    raise_application_error(-20601,
      'Link: destino invalido (' ||
      nvl(plink, 'NULL') ||
      '). So URL e suportada. O link interno de AddLink/SetLink NAO esta ' ||
      'implementado: o /Dest nunca e escrito e o PDF sairia malformado. ' ||
      'Use Link(x, y, w, h, ''https://...''). Ver docs/ROADMAP.md, pendencias.');
  end if;

  if PageLinks is null then
     PageLinks := linksArray();
  end if;
  if PageLinks.count < page then
     PageLinks.extend(page - PageLinks.count);
  end if;

	PageLinks(page).zero:=px*k;
	PageLinks(page).un:=hPt-py*k;
	PageLinks(page).deux:=pw*k;
	PageLinks(page).trois:=ph*k;
	PageLinks(page).quatre:=plink;
end Link;

procedure Text(px in number, py in number, ptxt in varchar2) is
s varchar2(2000);
begin

	s:='BT '|| tochar(px*k,2) ||' '|| tochar((h-py)*k,2) ||' Td ('||p_texto_pdf(ptxt)||') Tj ET';
	if(underline and ptxt is not null) then
		s := s || ' ' || p_dounderline(px,py,ptxt);
	end if;
	if(ColorFlag) then
		s := 'q '|| TextColor ||' ' || s || ' Q';
	end if;
	p_out(s);
end Text;

function AcceptPageBreak return boolean is
begin

	return AutoPageBreak;
end AcceptPageBreak;

procedure OpenPDF is
begin

	state:=1;
end OpenPDF;

procedure ClosePDF is
begin

	if(state=3) then
		return;
	end if;

	if(page=0) then
		AddPage();
	end if;

	InFooter:=true;
	Footer();
	InFooter:=false;

	p_endpage();

	p_enddoc();

end ClosePDF;

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

	if(state=0) then
		OpenPDF();
	end if;
	myFamily:= FontFamily;
	if (underline) then
	   myStyle := FontStyle || 'U';
	end if;
	if(page>0) then

		InFooter:=true;
		Footer();
		InFooter:=false;

		p_endpage();
	end if;

	p_beginpage(orientation);

	p_out('2 J');

	LineWidth:=lw;
	p_out(tochar(lw*k)||' w');

	if(myFamily is not null) then
		SetFont(myFamily,myStyle,mySize);
	end if;

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

	header();

	if(LineWidth!=lw) then
		LineWidth:=lw;
		p_out(tochar(lw*k)||' w');
	end if;

	if myFamily is null then
		SetFont(myFamily,myStyle,mySize);
	end if;

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

procedure update_line_spacing is
begin
	Linespacing := (fontsizePt / k);
end;

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

  l_orientation := upper(substr(nvl(p_orientation, 'P'), 1, 1));
  if l_orientation not in ('P', 'L') then
    raise_application_error(
      -20001,
      'Invalid orientation: ' || p_orientation || '. Must be P or L.'
    );
  end if;

  if lower(nvl(p_unit, 'mm')) not in ('mm', 'cm', 'in', 'pt') then
    raise_application_error(
      -20002,
      'Invalid unit: ' || p_unit || '. Must be mm, cm, in, or pt.'
    );
  end if;
  l_unit := lower(nvl(p_unit, 'mm'));

  if upper(nvl(p_encoding, 'UTF-8')) not in ('UTF-8', 'UTF8', 'AL32UTF8', 'ISO-8859-1', 'WINDOWS-1252') then
    raise_application_error(
      -20003,
      'Unsupported encoding: ' || p_encoding
    );
  end if;

  if g_initialized then
    log_message(3, 'Re-initializing - resetting existing state...');
    Reset();
  end if;

  g_default_orientation := l_orientation;
  g_default_format := get_page_format(upper(nvl(p_format, 'A4')));
  log_message(4, 'Defaults: orientation=' || g_default_orientation ||
    ', format=' || upper(nvl(p_format, 'A4')) || ' (' ||
    g_default_format.width || 'x' || g_default_format.height || 'mm)');

  g_encoding := upper(nvl(p_encoding, 'UTF-8'));
  log_message(4, 'Encoding set to: ' || g_encoding);

  log_message(4, 'Numeric conversion uses explicit NLS (session untouched)');

  l_format := upper(p_format);
  fpdf(l_orientation, l_unit, l_format);

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

procedure Reset is
begin
  log_message(3, 'Resetting PL_FPDF engine...');

  begin

    if dbms_lob.istemporary(pdfDoc) = 1 then
      dbms_lob.freetemporary(pdfDoc);
    end if;

    p_free_pages;
    fonts.delete;
    FontFiles.delete;
    images.delete;

    OrientationChanges.delete;
    if PageLinks is not null then
      PageLinks.delete;
    end if;
    if links is not null then
      links.delete;
    end if;

    g_ttf_obj.delete;
  exception
    when others then
      log_message(2, 'Warning during cleanup: ' || sqlerrm);
  end;

  g_initialized := false;
  state := 0;
  page := 0;
  n := 2;

  MyHeader_Proc := NULL;
  MyHeader_Stmt := NULL;
  MyHeader_ProcParam.delete;
  MyFooter_Proc := NULL;
  MyFooter_Stmt := NULL;
  MyFooter_ProcParam.delete;

  g_encrypt_method := NULL;
  g_user_password := NULL;
  g_owner_password := NULL;
  g_sec_permissions := -1;
  g_encrypt_obj_num := NULL;
  g_file_id := NULL;
  g_o_value := NULL;
  g_u_value := NULL;
  g_encryption_key := NULL;

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

function IsInitialized return boolean is
begin
  return g_initialized;
end IsInitialized;

function GetCurrentPage return pls_integer is
begin
  return g_current_page;
end GetCurrentPage;

procedure SetPage(p_page_number pls_integer) is
begin

  if not g_initialized then
    raise_application_error(-20005,
      'PL_FPDF not initialized. Call Init() first.');
  end if;

  if not g_pages.exists(p_page_number) then
    raise_application_error(-20106,
      'Page ' || p_page_number || ' does not exist. Total pages: ' || g_current_page);
  end if;

  if g_current_page > 0 and g_current_page != p_page_number then

    null;
  end if;

  g_current_page := p_page_number;
  page := p_page_number;

  w := g_pages(p_page_number).format.width;
  h := g_pages(p_page_number).format.height;

  log_message(4, 'Switched to page ' || p_page_number ||
    ' (' || w || 'x' || h || 'mm)');

exception
  when others then
    log_message(1, 'Error in SetPage: ' || sqlerrm);
    raise;
end SetPage;

procedure AddPage(
  p_orientation varchar2 default null,
  p_format varchar2 default null,
  p_rotation pls_integer default 0
) is
  l_orientation varchar2(1);
  l_format recPageFormat;
begin

  if not g_initialized then
    raise_application_error(-20005,
      'PL_FPDF not initialized. Call Init() first.');
  end if;

  if p_orientation is null then
    l_orientation := g_default_orientation;
  else
    l_orientation := upper(substr(p_orientation, 1, 1));
    if l_orientation not in ('P', 'L') then
      raise_application_error(-20107,
        'Invalid orientation: ' || p_orientation || '. Use P (Portrait) or L (Landscape)');
    end if;
  end if;

  if p_format is not null then

    if instr(p_format, ',') > 0 or instr(p_format, 'x') > 0 or instr(p_format, 'X') > 0 then

      declare
        l_separator varchar2(1);
        l_pos pls_integer;
        l_width varchar2(20);
        l_height varchar2(20);
        l_is_custom boolean := false;
      begin

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

        l_width := trim(substr(p_format, 1, l_pos - 1));
        l_height := trim(substr(p_format, l_pos + 1));

        begin
          l_format.width := to_number(l_width);
          l_format.height := to_number(l_height);

          if l_format.width <= 0 or l_format.height <= 0 then
            raise_application_error(-20101,
              'Invalid custom format dimensions: ' || p_format || '. Width and height must be positive.');
          end if;

          l_is_custom := true;
          log_message(4, 'Custom page format: ' || l_format.width || 'x' || l_format.height || 'mm');

        exception
          when value_error then

            l_is_custom := false;
        end;

        if not l_is_custom then
          l_format := get_page_format(p_format);
        end if;
      end;
    else

      l_format := get_page_format(p_format);
    end if;
  else
    l_format := g_default_format;
  end if;

  if p_rotation not in (0, 90, 180, 270) then
    raise_application_error(-20104,
      'Invalid rotation: ' || p_rotation || '. Must be 0, 90, 180, or 270 degrees.');
  end if;

  p_addpage_internal(l_orientation);

  g_current_page := page;

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

function ttf_u16(p_b in blob, p_pos in number) return pls_integer is
begin
  return to_number(rawtohex(dbms_lob.substr(p_b, 2, p_pos + 1)), 'XXXX');
end ttf_u16;

function ttf_s16(p_b in blob, p_pos in number) return pls_integer is
  l_v pls_integer := ttf_u16(p_b, p_pos);
begin

  return case when l_v > 32767 then l_v - 65536 else l_v end;
end ttf_s16;

function ttf_u32(p_b in blob, p_pos in number) return number is
begin

  return to_number(rawtohex(dbms_lob.substr(p_b, 4, p_pos + 1)), 'XXXXXXXX');
end ttf_u32;

procedure ttf_tabela(p_b   in  blob,
                     p_tag in  varchar2,
                     o_off out number,
                     o_len out number) is
  l_qtd pls_integer;
  l_p   number;
begin
  o_off := null;
  o_len := null;
  l_qtd := ttf_u16(p_b, 4);
  for i in 0 .. l_qtd - 1 loop
    l_p := 12 + i * 16;
    if dbms_lob.substr(p_b, 4, l_p + 1) = utl_raw.cast_to_raw(p_tag) then
      o_off := ttf_u32(p_b, l_p + 8);
      o_len := ttf_u32(p_b, l_p + 12);
      return;
    end if;
  end loop;
end ttf_tabela;

function ttf_cmap_sub(p_b in blob, p_cmap in number) return number is
  l_qtd  pls_integer;
  l_p    number;
  l_pid  pls_integer;
  l_eid  pls_integer;
  l_off  number;
  l_esc  number := null;
  l_peso pls_integer := 0;
  l_p2   pls_integer;
begin
  l_qtd := ttf_u16(p_b, p_cmap + 2);
  for i in 0 .. l_qtd - 1 loop
    l_p   := p_cmap + 4 + i * 8;
    l_pid := ttf_u16(p_b, l_p);
    l_eid := ttf_u16(p_b, l_p + 2);
    l_off := ttf_u32(p_b, l_p + 4);
    l_p2  := case when l_pid = 3 and l_eid = 1 then 3
                  when l_pid = 3 and l_eid = 0 then 2
                  when l_pid = 0               then 1
                  else 0 end;
    if l_p2 > l_peso and ttf_u16(p_b, p_cmap + l_off) = 4 then
      l_peso := l_p2;
      l_esc  := p_cmap + l_off;
    end if;
  end loop;
  return l_esc;
end ttf_cmap_sub;

function ttf_glifo(p_b in blob, p_sub in number, p_cp in pls_integer)
  return pls_integer is
  l_seg   pls_integer;
  l_fim   pls_integer;
  l_ini   pls_integer;
  l_delta pls_integer;
  l_ro    pls_integer;
  l_pos   number;
  l_g     pls_integer;
begin
  if p_sub is null or p_cp is null then
    return 0;
  end if;
  l_seg := ttf_u16(p_b, p_sub + 6) / 2;
  for i in 0 .. l_seg - 1 loop
    l_fim := ttf_u16(p_b, p_sub + 14 + i * 2);
    if l_fim >= p_cp then
      l_ini := ttf_u16(p_b, p_sub + 16 + l_seg * 2 + i * 2);
      if l_ini > p_cp then
        return 0;
      end if;
      l_delta := ttf_s16(p_b, p_sub + 16 + l_seg * 4 + i * 2);
      l_ro    := ttf_u16(p_b, p_sub + 16 + l_seg * 6 + i * 2);
      if l_ro = 0 then
        return mod(p_cp + l_delta + 65536, 65536);
      end if;
      l_pos := p_sub + 16 + l_seg * 6 + i * 2 + l_ro + (p_cp - l_ini) * 2;
      l_g := ttf_u16(p_b, l_pos);
      if l_g = 0 then
        return 0;
      end if;
      return mod(l_g + l_delta + 65536, 65536);
    end if;
  end loop;
  return 0;
end ttf_glifo;

function ttf_avanco(p_b in blob, p_hmtx in number, p_nhm in pls_integer,
                    p_glifo in pls_integer) return pls_integer is
begin
  if p_glifo < p_nhm then
    return ttf_u16(p_b, p_hmtx + p_glifo * 4);
  end if;
  return ttf_u16(p_b, p_hmtx + (p_nhm - 1) * 4);
end ttf_avanco;

function p_winansi_cp(p_byte in pls_integer) return pls_integer is
begin
  case p_byte
    when 128 then return 8364;
    when 130 then return 8218;
    when 131 then return 402;
    when 132 then return 8222;
    when 133 then return 8230;
    when 134 then return 8224;
    when 135 then return 8225;
    when 136 then return 710;
    when 137 then return 8240;
    when 138 then return 352;
    when 139 then return 8249;
    when 140 then return 338;
    when 142 then return 381;
    when 145 then return 8216;
    when 146 then return 8217;
    when 147 then return 8220;
    when 148 then return 8221;
    when 149 then return 8226;
    when 150 then return 8211;
    when 151 then return 8212;
    when 152 then return 732;
    when 153 then return 8482;
    when 154 then return 353;
    when 155 then return 8250;
    when 156 then return 339;
    when 158 then return 382;
    when 159 then return 376;
    when 129 then return null;
    when 141 then return null;
    when 143 then return null;
    when 144 then return null;
    when 157 then return null;
    else return p_byte;
  end case;
end p_winansi_cp;

function parse_ttf_header(p_font_blob blob, p_font_name varchar2) return recTTFFont is
  l_font recTTFFont;
  l_magic_number raw(4);
  c_ttf_magic constant raw(4) := hextoraw('00010000');
  c_otf_magic constant raw(4) := hextoraw('4F54544F');
  c_ttc_magic constant raw(4) := hextoraw('74746366');
  c_true      constant raw(4) := hextoraw('74727565');

  l_head number;  l_head_len number;
  l_hhea number;  l_hhea_len number;
  l_hmtx number;  l_hmtx_len number;
  l_cmap number;  l_cmap_len number;
  l_os2  number;  l_os2_len  number;
  l_post number;  l_post_len number;

  l_upm   pls_integer;
  l_nhm   pls_integer;
  l_sub   number;
  l_cp    pls_integer;
  l_glifo pls_integer;
  l_larg  pls_integer;
  l_lista varchar2(1024);
  l_ang   number;
  l_sel   pls_integer;

  function mil(p_v in number) return pls_integer is
  begin
    return round(p_v * 1000 / l_upm);
  end mil;
begin
  if p_font_blob is null or dbms_lob.getlength(p_font_blob) < 12 then
    raise_application_error(-20202, 'Invalid font BLOB: NULL or too small (<12 bytes)');
  end if;

  l_magic_number := dbms_lob.substr(p_font_blob, 4, 1);
  if l_magic_number = c_ttc_magic then
    raise_application_error(-20202, 'TrueType Collections (.ttc) not yet supported');
  elsif l_magic_number not in (c_ttf_magic, c_otf_magic, c_true) then
    raise_application_error(-20202,
      'Invalid TTF/OTF magic number: ' || rawtohex(l_magic_number));
  end if;

  l_font.font_name := upper(p_font_name);
  l_font.font_blob := p_font_blob;
  l_font.encoding := 'UTF-8';
  l_font.loaded_at := systimestamp;
  l_font.is_embedded := true;

  ttf_tabela(p_font_blob, 'head', l_head, l_head_len);
  ttf_tabela(p_font_blob, 'hhea', l_hhea, l_hhea_len);
  ttf_tabela(p_font_blob, 'hmtx', l_hmtx, l_hmtx_len);
  ttf_tabela(p_font_blob, 'cmap', l_cmap, l_cmap_len);
  ttf_tabela(p_font_blob, 'OS/2', l_os2,  l_os2_len);
  ttf_tabela(p_font_blob, 'post', l_post, l_post_len);

  if l_head is null or l_hhea is null or l_hmtx is null or l_cmap is null then
    raise_application_error(-20202,
      'Fonte sem tabela obrigatoria (head/hhea/hmtx/cmap): ' || p_font_name);
  end if;

  l_upm := ttf_u16(p_font_blob, l_head + 18);
  if l_upm is null or l_upm = 0 then
    raise_application_error(-20202, 'unitsPerEm invalido em ' || p_font_name);
  end if;
  l_font.units_per_em := l_upm;

  l_font.bbox_xmin := mil(ttf_s16(p_font_blob, l_head + 36));
  l_font.bbox_ymin := mil(ttf_s16(p_font_blob, l_head + 38));
  l_font.bbox_xmax := mil(ttf_s16(p_font_blob, l_head + 40));
  l_font.bbox_ymax := mil(ttf_s16(p_font_blob, l_head + 42));

  l_font.ascent   := mil(ttf_s16(p_font_blob, l_hhea + 4));
  l_font.descent  := mil(ttf_s16(p_font_blob, l_hhea + 6));
  l_font.line_gap := mil(ttf_s16(p_font_blob, l_hhea + 8));
  l_nhm := ttf_u16(p_font_blob, l_hhea + 34);
  if l_nhm is null or l_nhm = 0 then
    raise_application_error(-20202,
      'numberOfHMetrics zerado em ' || p_font_name);
  end if;

  l_font.cap_height := l_font.ascent;
  l_font.x_height   := 0;
  l_font.is_bold    := false;
  l_font.is_italic  := false;
  l_font.italic_angle := 0;
  if l_os2 is not null and l_os2_len >= 64 then
    l_sel := ttf_u16(p_font_blob, l_os2 + 62);
    l_font.is_italic := bitand(l_sel, 1) = 1;
    l_font.is_bold   := bitand(l_sel, 32) = 32;
    if ttf_u16(p_font_blob, l_os2) >= 2 and l_os2_len >= 90 then
      l_font.cap_height := mil(ttf_s16(p_font_blob, l_os2 + 88));
      l_font.x_height   := mil(ttf_s16(p_font_blob, l_os2 + 86));
    end if;
  end if;
  if l_post is not null and l_post_len >= 8 then

    l_ang := ttf_s16(p_font_blob, l_post + 4)
             + ttf_u16(p_font_blob, l_post + 6) / 65536;
    l_font.italic_angle := round(l_ang, 2);
  end if;

  l_font.flags := 32;
  if l_post is not null and l_post_len >= 20
     and ttf_u32(p_font_blob, l_post + 16) != 0 then
    l_font.flags := l_font.flags + 1;
  end if;
  if l_font.is_italic then
    l_font.flags := l_font.flags + 64;
  end if;

  l_sub := ttf_cmap_sub(p_font_blob, l_cmap);
  if l_sub is null then
    raise_application_error(-20202,
      'Fonte sem cmap no formato 4 (Unicode BMP): ' || p_font_name);
  end if;

  l_lista := null;
  for b in 0 .. 255 loop
    l_larg := 0;
    if b >= 32 then
      l_cp := p_winansi_cp(b);
      if l_cp is not null then
        l_glifo := ttf_glifo(p_font_blob, l_sub, l_cp);
        if l_glifo > 0 then
          l_larg := mil(ttf_avanco(p_font_blob, l_hmtx, l_nhm, l_glifo));
        end if;
      end if;
    end if;
    l_lista := l_lista || lpad(to_char(least(greatest(l_larg, 0), 9999)), 4, '0');
  end loop;
  l_font.larguras := l_lista;

  log_message(4, 'TTF lida: ' || p_font_name || ', upm ' || l_upm
              || ', ascent ' || l_font.ascent || ', descent ' || l_font.descent
              || ', ' || dbms_lob.getlength(p_font_blob) || ' bytes');
  return l_font;
exception
  when others then
    if sqlcode = -20202 then
      raise;
    end if;
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

function UTF8ToPDFString(p_text varchar2, p_escape boolean default true) return varchar2 is
  l_result varchar2(32767);
begin
  if p_text is null then
    return null;
  end if;

  l_result := p_text;

  if p_escape then
    l_result := p_escapa_pdf(l_result);
  end if;

  return l_result;

exception
  when others then
    log_message(1, 'Error in UTF8ToPDFString: ' || sqlerrm);

    if p_escape then
      return p_escapa_pdf(p_text);
    else
      return p_text;
    end if;
end UTF8ToPDFString;

procedure fpdf
  (orientation varchar2 default 'P',
   unit varchar2 default 'mm',
   format varchar2 default 'A4') is
   myorientation word := orientation;
   myformat word := format;
   mymargin margin;
begin

	p_dochecks();

	page:=0;
	n:=2;

  if dbms_lob.istemporary(pdfDoc) = 1 then
    dbms_lob.freetemporary(pdfDoc);
  end if;
  dbms_lob.createtemporary(pdfDoc, true, dbms_lob.session);
  p_free_pages;
	state:=0;
	InFooter:=false;
	lasth:=0;

	FontFamily:='helvetica';
	fontstyle:='';
	fontsizePt:=12;
	underline:=false;
	DrawColor:='0 G';
	FillColor:='0 g';
	TextColor:='0 g';
	ColorFlag:=false;
	ws:=0;

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

    update_line_spacing;

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

	mymargin:=28.35/k;
	SetMargins(mymargin,mymargin);

	cMargin:=mymargin/10;

	LineWidth:=.567/k;

	SetAutoPageBreak(true,2*mymargin);

	SetDisplayMode('fullwidth');

	SetCompression(false);

	PDFVersion:='1.4';

	g_initialized := true;
end fpdf;

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
  myType varchar2(256);

begin

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

procedure SetFont(pfamily in varchar2, pstyle in varchar2 default '', psize in number default 0) is
myfamily word;
mystyle	 word;
mysize	 number;
FontCount number := 0;
myFontFile word;
fontkey  word;
l_clean_style varchar2(10);

begin

	if pfamily is not null and length(pfamily) > c_MAX_FONT_NAME_LENGTH then
		raise_application_error(-20100, 'Font family name too long (max ' || c_MAX_FONT_NAME_LENGTH || ' characters)');
	end if;

	if pstyle is not null and length(pstyle) > 0 then

		l_clean_style := replace(upper(pstyle), 'U', '');

		if length(l_clean_style) > 0 then
			if l_clean_style not in ('N', 'B', 'I', 'BI', 'IB') then
				raise_application_error(-20100, 'Invalid font style: ''' || pstyle || '''. Valid: N, B, I, BI, IB (with optional U)');
			end if;
		end if;
	end if;

	if psize is not null and (psize < c_MIN_FONT_SIZE or psize > c_MAX_FONT_SIZE) then
		raise_application_error(-20100, 'Invalid font size: ' || psize || '. Must be ' || c_MIN_FONT_SIZE || '-' || c_MAX_FONT_SIZE || ' points');
	end if;

	myfamily := pfamily;
	mystyle := pstyle;
	mysize := psize;

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

	if(FontFamily=myfamily and fontstyle=mystyle and fontsizePt=mysize) then
		return;
	end if;

	if not g_initialized then
	  raise_application_error(-20005,
	    'PL_FPDF not initialized. Call Init() first.');
	end if;

	fontkey:=nvl(myfamily || mystyle, '');

	if(not fonts.exists(fontkey)) then

		if(CoreFonts.exists(fontkey)) then

			if(not fpdf_charwidths.exists(fontkey)) then

				myFontFile:=myfamily;
				if(myfamily='times' or myfamily='helvetica') then
					myFontFile:=myFontFile || lower(mystyle);
				end if;

				p_includeFont(fontkey);

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
		elsif g_ttf_fonts.exists(upper(myfamily)) then

			FontCount := nvl(fonts.count, 0) + 1;
			fonts(fontkey).i    := FontCount;
			fonts(fontkey).type := 'TrueType';
			fonts(fontkey).name := replace(upper(myfamily), ' ', '');
			fonts(fontkey).up   := -100;
			fonts(fontkey).ut   := 50;
			fonts(fontkey).cw   := p_larguras_de(
			                         g_ttf_fonts(upper(myfamily)).larguras);
			fonts(fontkey).enc  := 'WinAnsiEncoding';

			fonts(fontkey).file := upper(myfamily);
		else
			raise_application_error(-20201, 'Undefined font: ' || myfamily || ' ' || mystyle);
		end if;
	end if;

	FontFamily:=myfamily;
	fontstyle:=mystyle;
	fontsizePt:=mysize;
	fontsize:=mysize/k;

	    CurrentFont:= fonts(fontkey);

	if(page>0) then
		p_out('BT /F'||CurrentFont.i||' '||tochar(fontsizePt,2)||' Tf ET');
	end if;

    update_line_spacing;
end SetFont;

function GetStringWidth(pstr in varchar2) return number is
charSetWidth CharSet;
w number;
lg number;
wdth number;
c car;
l_byte pls_integer;
begin

	charSetWidth := CurrentFont.cw;
	w:=0;
	lg := length(pstr);
	for i in 1..lg
	loop
		l_byte := p_winansi_byte(substr(pstr,i,1));
		if l_byte is null then
			raise_application_error(-20203,
				'Caractere fora de WinAnsi na posicao ' || i
				|| ' ao medir a largura: ' || substr(pstr,i,1));
		end if;
		c := chr(l_byte);
		if charSetWidth.exists(c) then
			wdth := charSetWidth(c);
		else
			wdth := 0;
		end if;
		w:= w + wdth;
	end loop;
	return w * fontsize/1000;
end GetStringWidth;

procedure SetFontSize(psize in number) is
begin

	if(fontsizePt=psize) then
		return;
	end if;
	fontsizePt:=psize;
	fontsize:=psize/k;
	if(page>0) then
		p_out('BT /F'||CurrentFont.i||' '||tochar(fontsizePt,2)||' Tf ET');
	end if;
end SetFontSize;

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

	if( ( y + ph > pageBreakTrigger) and  not InFooter and AcceptPageBreak()) then

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

        myTXT2 := p_texto_pdf(ptxt);
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

		carac := substr(myS,i,1);
		if(carac = CHR(10)) then

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

	if (phMax > 0) then
	    if ( cumulativeHeight < phMax ) then

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

function p_jpegImage(p_blob in blob, p_name in varchar2) return recImage is
  l_img  recImageBlob;
  l_info recImage;
begin
  if not parse_jpeg_header(p_blob, l_img) then
    raise_application_error(-20301, 'Invalid JPEG header in image: ' || p_name);
  end if;

  l_info.i   := 1;
  l_info.w   := l_img.width;
  l_info.h   := l_img.height;
  l_info.bpc := nvl(l_img.bit_depth, 8);
  l_info.f   := 'DCTDecode';

  if l_img.color_type = 1 then
    l_info.cs := 'DeviceGray';
  elsif l_img.color_type = 3 then
    l_info.cs := 'DeviceRGB';
  elsif l_img.color_type = 4 then
    l_info.cs := 'DeviceCMYK';
  else
    raise_application_error(-20303,
      'Unsupported JPEG component count (' || l_img.color_type || '): ' || p_name);
  end if;

  dbms_lob.createtemporary(imgBlob, true);
  dbms_lob.copy(imgBlob, p_blob, dbms_lob.getlength(p_blob), 1, 1);
  l_info.data := imgBlob;

  return l_info;
end p_jpegImage;

procedure image ( pFile in varchar2,
		  		  pX in number,
				  pY in number,
				  pWidth in number default 0,
				  pHeight in number default 0,
				  pType in varchar2 default null,
				  pLink in varchar2 default null) is

   myFile varchar2(2000) := pFile;

   myW number := pWidth;
   myH number := pHeight;

   info recImage;
begin

	if ( not imageExists(myFile) ) then

		info := p_parseImage(myFile);
		info.i := nvl(images.count, 0) + 1;
		images(lower(myFile)) := info;
	else
		info := images(lower(myFile));
	end if;

	if(myW = 0 and myH = 0) then

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

procedure ImageFromBlob( p_blob  in blob,
                         p_name  in varchar2,
                         pX      in number,
                         pY      in number,
                         pWidth  in number default 0,
                         pHeight in number default 0,
                         pLink   in varchar2 default null) is
  myW  number := pWidth;
  myH  number := pHeight;
  info recImage;
  l_sig raw(8);
begin
  if p_blob is null or dbms_lob.getlength(p_blob) = 0 then
    raise_application_error(-20301, 'Empty image blob: ' || nvl(p_name, '(sem nome)'));
  end if;
  if p_name is null then
    raise_application_error(-20301,
      'ImageFromBlob requires a name: it is the key of the image cache');
  end if;

  if ( not imageExists(p_name) ) then
    l_sig := dbms_lob.substr(p_blob, 8, 1);
    if utl_raw.compare(l_sig, c_PNG_SIGNATURE) = 0 then
      info := p_parseImage(p_name, p_blob);
    elsif utl_raw.compare(utl_raw.substr(l_sig, 1, 2), c_JPEG_SOI) = 0 then
      info := p_jpegImage(p_blob, p_name);
    else
      raise_application_error(-20303,
        'Unsupported image format (only PNG and JPEG supported): ' || p_name);
    end if;
    info.i := nvl(images.count, 0) + 1;
    images(lower(p_name)) := info;
  else
    info := images(lower(p_name));
  end if;

  if (myW = 0 and myH = 0) then
    myW := info.w / k;
    myH := info.h / k;
  end if;
  if (myW = 0) then
    myW := myH * info.w / info.h;
  end if;
  if (myH = 0) then
    myH := myW * info.h / info.w;
  end if;

  p_out('q '||tochar(myW * k, 2)||' 0 0 '||tochar(myH * k, 2)||' '
        ||tochar(pX * k, 2)||' '||tochar((h - ( pY + myH)) * k, 2)
        ||' cm /I'||to_char(info.i)||' Do Q');
  if (pLink is not null) then
    Link(pX, pY, myW, myH, pLink);
  end if;
end ImageFromBlob;

procedure Write(pH varchar2,ptxt varchar2,plink varchar2 default null) is
   charSetWidth CharSet;
   myW number;
   myWmax number;
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

	charSetWidth := CurrentFont.cw;
	myW := w - rMargin - x;
	myWmax := (myW - 2 * cMargin) * 1000 / FontSize;
	s := replace(ptxt, chr(13), '');
	nb := length(s);
	sep := -1;
  i := 1;
  j := 1;
	l := 0;
  lsep := 0;
  lastl := 0;

	while i <= nb  loop

		c := substr(s, i, 1);

		if(c = chr(10)) then
			Cell(myW, pH, substr(s,j,i-j), 0, 1, '', 0, plink);

			i := i + 1;
			sep := -1;
			j := i;
			l := 0;
      myW := w - rMargin - x;
			myWmax := (myW - 2 * cMargin) * 1000 / FontSize;

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

				if sep = -1 then
          Cell(myW, pH, substr(s,j,i-j+1), 0, 1, '', 0, plink);
					i := i + 1;
          j := i;
          l := 0;
				else
					Cell(myW, pH, substr(s,j,sep-j), 0, 1, '', 0, plink);
					i := sep + 1;
          j := i;
          sep := -1;
          l := lsep-(myWmax-lastl);

				end if;
        myW := w - rMargin - x;
				myWmax := (myW - 2 * cMargin) * 1000 / FontSize;
			else
				i := i + 1;
			end if;
		end if;
	end loop;

	if( i != j ) then
		 Cell((l+2*cMargin) / 1000 * FontSize, pH, substr(s,j), 0, 0, '', 0, plink);
  end if;
exception
   when others then
      error('write : '||sqlerrm);
end write;

function OutputBlob return blob is
  v_doc blob;

  v_in pls_integer;
  v_out pls_integer;
  v_lang pls_integer;
  v_warning pls_integer;
  v_len pls_integer;
begin

  if not g_initialized then
    raise_application_error(-20005,
      'PL_FPDF not initialized. Call Init() first.');
  end if;

  if state < 3 then
    ClosePDF();
  end if;

  dbms_lob.createtemporary(v_doc, false, dbms_lob.session);

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

    if sqlcode between -20999 and -20000 then
      raise;
    end if;
    log_message(1, 'Error in OutputBlob: ' || sqlerrm);
    error('OutputBlob: ' || sqlerrm);
    return null;
end OutputBlob;

procedure OutputFile(p_filename varchar2, p_directory varchar2 default 'PDF_DIR') is
  v_pdf_blob blob;
  v_file utl_file.file_type;
  v_buffer raw(32767);
  v_amount pls_integer := 32767;
  v_pos pls_integer := 1;
  v_blob_len pls_integer;
begin

  v_pdf_blob := OutputBlob();
  v_blob_len := dbms_lob.getlength(v_pdf_blob);

  log_message(3, 'OutputFile: Saving ' || v_blob_len || ' bytes to ' || p_filename ||
              ' in directory ' || p_directory);

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

  if dbms_lob.istemporary(v_pdf_blob) = 1 then
    dbms_lob.freetemporary(v_pdf_blob);
  end if;

exception
  when others then
    log_message(1, 'Error in OutputFile: ' || sqlerrm);
    error('OutputFile: ' || sqlerrm);
    raise;
end OutputFile;

procedure Output(pname varchar2 default null, pdest varchar2 default null) is
  myName word := pname;
  myDest word := pdest;
begin

  if state < 3 then
    ClosePDF();
  end if;

  myDest := upper(myDest);

  if myDest is null then
    if myName is null then
      myName := 'doc.pdf';
    end if;
    myDest := 'F';
  end if;

  if myDest = 'F' then
    if myName is null then
      raise_application_error(-20100,
        'Filename required for Output with pdest=''F''. Example: Output(''report.pdf'', ''F'')');
    end if;

    OutputFile(myName, 'PDF_DIR');
    log_message(3, 'Output: Saved to file ' || myName);

  elsif myDest in ('I', 'D', 'S') then

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
v_doc blob;
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

  return OutputBlob();
exception
  when others then
    log_message(1, 'Error in ReturnBlob: ' || sqlerrm);
    error('ReturnBlob: ' || sqlerrm);
    return null;
end ReturnBlob;

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

  if p_rotation not in (0, 90, 180, 270) then
    raise_application_error(-20110,
      'Invalid text rotation: ' || p_rotation || '. Must be 0, 90, 180, or 270 degrees.');
  end if;

  if p_rotation = 0 then
    Cell(p_width, p_height, p_text, p_border, p_ln, p_align, p_fill, p_link);
    return;
  end if;

  l_x := x;
  l_y := y;
  l_angle := p_rotation * 3.14159265359 / 180;
  l_cos := cos(l_angle);
  l_sin := sin(l_angle);

  p_out('q');
  p_out(tochar(l_cos, 5) || ' ' || tochar(l_sin, 5) || ' ' ||
        tochar(-l_sin, 5) || ' ' || tochar(l_cos, 5) || ' ' ||
        tochar(l_x * k * (1 - l_cos) + (h - l_y) * k * l_sin, 2) || ' ' ||
        tochar((h - l_y) * k * (1 - l_cos) - l_x * k * l_sin, 2) || ' cm');

  Cell(p_width, p_height, p_text, p_border, p_ln, p_align, p_fill, p_link);

  p_out('Q');

  log_message(4, 'CellRotated: text="' || substr(p_text, 1, 50) || '", rotation=' || p_rotation);

exception
  when others then
    log_message(1, 'Error in CellRotated: ' || sqlerrm);
    raise;
end CellRotated;

procedure WriteRotated(
  p_height number,
  p_text varchar2,
  p_link varchar2 default null,
  p_rotation pls_integer default 0
) is
begin

  if p_rotation not in (0, 90, 180, 270) then
    raise_application_error(-20110,
      'Invalid text rotation: ' || p_rotation || '. Must be 0, 90, 180, or 270 degrees.');
  end if;

  if p_rotation <> 0 then
    raise_application_error(-20111,
      'WriteRotated currently only supports 0° rotation. ' ||
      'Use CellRotated() for rotated text output.');
  end if;

  Write(p_height, p_text, p_link);

  log_message(4, 'WriteRotated: text="' || substr(p_text, 1, 50) || '", rotation=' || p_rotation);

exception
  when others then
    log_message(1, 'Error in WriteRotated: ' || sqlerrm);
    raise;
end WriteRotated;

procedure SetDocumentConfig(p_config JSON_OBJECT_T) is
  l_keys JSON_KEY_LIST;
  l_key VARCHAR2(100);
  l_value VARCHAR2(4000);
begin

  if p_config is null then
    log_message(c_LOG_WARN, 'SetDocumentConfig: NULL config provided, ignoring');
    return;
  end if;

  log_message(c_LOG_INFO, 'SetDocumentConfig: Processing JSON configuration');

  l_keys := p_config.get_keys;

  for i in 1..l_keys.count loop
    l_key := l_keys(i);

    begin
      case upper(l_key)

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

        when 'ORIENTATION' then
          l_value := p_config.get_String(l_key);

          if upper(substr(l_value, 1, 1)) not in ('P', 'L') then
            raise_application_error(-20001,
              'Invalid orientation: ' || l_value || '. Must be P or L.');
          end if;

          if not g_initialized then
            g_default_orientation := upper(substr(l_value, 1, 1));
          else

            log_message(c_LOG_WARN, 'Cannot change orientation after initialization');
          end if;
          log_message(c_LOG_DEBUG, 'Set orientation: ' || l_value);

        when 'UNIT' then
          l_value := lower(p_config.get_String(l_key));

          if l_value not in ('mm', 'cm', 'in', 'pt') then
            raise_application_error(-20002,
              'Invalid unit: ' || l_value || '. Must be mm, cm, in, or pt.');
          end if;

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

function GetDocumentMetadata return JSON_OBJECT_T is
  l_metadata JSON_OBJECT_T;
  l_unit VARCHAR2(10);
begin
  l_metadata := JSON_OBJECT_T();

  l_metadata.put('initialized', g_initialized);
  l_metadata.put('pageCount', g_current_page);

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

  l_metadata.put('orientation', case g_default_orientation
    when 'P' then 'Portrait'
    when 'L' then 'Landscape'
    else 'Unknown'
  end);

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

  if g_formats_initialized and g_default_format.width is not null then

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

  l_metadata.put('pdfVersion', c_PDF_VERSION);
  l_metadata.put('fpdfVersion', co_version);

  log_message(c_LOG_DEBUG, 'GetDocumentMetadata: Returned metadata for ' || g_current_page || ' pages');

  return l_metadata;

exception
  when others then
    log_message(c_LOG_ERROR, 'Error in GetDocumentMetadata: ' || sqlerrm);
    raise;
end GetDocumentMetadata;

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

FUNCTION get_pdf_object(p_obj_id PLS_INTEGER) RETURN CLOB IS
  l_offset PLS_INTEGER;
  l_obj_text VARCHAR2(32767);
  l_end_pos PLS_INTEGER;
  l_obj_content CLOB;
BEGIN

  IF g_object_cache.EXISTS(p_obj_id) THEN
    RETURN g_object_cache(p_obj_id);
  END IF;

  IF g_objstm_body.EXISTS(p_obj_id) THEN
    g_object_cache(p_obj_id) := g_objstm_body(p_obj_id);
    RETURN g_object_cache(p_obj_id);
  END IF;

  IF NOT g_xref_table.EXISTS(p_obj_id) THEN
    raise_application_error(-20805, 'Object ' || p_obj_id || ' not in xref table');
  END IF;

  l_offset := g_xref_table(p_obj_id).offset;
  IF l_offset IS NULL THEN
    raise_application_error(-20847,
      'Objeto ' || p_obj_id || ' esta num object stream que nao foi carregado.');
  END IF;
  log_message(4, 'get_pdf_object(' || p_obj_id || '): offset=' || l_offset);

  l_obj_text := read_blob_chunk(g_loaded_pdf, l_offset + 1, 32767);
  log_message(4, 'get_pdf_object(' || p_obj_id || '): raw text (first 200)=' ||
              SUBSTR(l_obj_text, 1, 200));

  l_end_pos := INSTR(l_obj_text, 'endobj');

  IF l_end_pos = 0 THEN
    raise_application_error(-20806, 'endobj not found for object ' || p_obj_id);
  END IF;

  l_obj_content := SUBSTR(l_obj_text, 1, l_end_pos + 5);

  g_object_cache(p_obj_id) := l_obj_content;

  RETURN l_obj_content;
END get_pdf_object;

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

  l_catalog := get_pdf_object(g_root_obj_id);
  log_message(3, 'Catalog (Root=' || g_root_obj_id || '): ' || SUBSTR(l_catalog, 1, 300));

  l_pages_id := TO_NUMBER(
    REGEXP_SUBSTR(l_catalog, '/Pages\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_pages_id IS NULL THEN
    log_message(1, 'Catalog object: ' || SUBSTR(l_catalog, 1, 500));
    raise_application_error(-20810, 'Pages not found in Catalog');
  END IF;

  g_pages_obj_id := l_pages_id;
  log_message(3, 'Pages object ID: ' || l_pages_id);

  l_pages_obj := get_pdf_object(l_pages_id);
  log_message(3, 'Pages object content (first 300 chars): ' || SUBSTR(l_pages_obj, 1, 300));

  DECLARE
    l_kids_start PLS_INTEGER;
    l_kids_end PLS_INTEGER;
  BEGIN

    l_kids_start := INSTR(l_pages_obj, '/Kids');

    IF l_kids_start > 0 THEN

      l_kids_start := INSTR(l_pages_obj, '[', l_kids_start);

      IF l_kids_start > 0 THEN

        l_kids_end := INSTR(l_pages_obj, ']', l_kids_start);

        IF l_kids_end > l_kids_start THEN

          l_kids_array := SUBSTR(l_pages_obj, l_kids_start + 1, l_kids_end - l_kids_start - 1);
          log_message(3, 'Kids array extracted via INSTR: ' || l_kids_array);
        END IF;
      END IF;
    END IF;
  END;

  IF l_kids_array IS NULL THEN
    log_message(1, 'ERROR: Kids array not found. Pages object content:');
    log_message(1, SUBSTR(l_pages_obj, 1, 500));
    log_message(1, 'Object length: ' || LENGTH(l_pages_obj));
    raise_application_error(-20811, 'Kids array not found in Pages object');
  END IF;

  log_message(3, 'Kids array extracted: ' || l_kids_array);

  l_pos := 1;
  LOOP

    l_page_obj_id := TO_NUMBER(
      REGEXP_SUBSTR(l_kids_array, '([0-9]+)\s+0\s+R', 1, l_pos, NULL, 1)
    );

    EXIT WHEN l_page_obj_id IS NULL;

    g_page_info_table(l_page_num).page_obj_id := l_page_obj_id;

    l_page_num := l_page_num + 1;
    l_pos := l_pos + 1;
  END LOOP;

  log_message(3, 'Parsed page tree: ' || g_page_info_table.COUNT || ' pages');
END parse_page_tree;

FUNCTION get_page_object_id(p_page_number PLS_INTEGER) RETURN PLS_INTEGER IS
BEGIN

  IF g_page_info_table.COUNT = 0 THEN
    parse_page_tree();
  END IF;

  IF p_page_number < 1 OR p_page_number > g_page_info_table.COUNT THEN
    raise_application_error(-20812,
      'Invalid page number: ' || p_page_number ||
      '. Valid range: 1-' || g_page_info_table.COUNT);
  END IF;

  RETURN g_page_info_table(p_page_number).page_obj_id;
END get_page_object_id;

PROCEDURE extract_page_info(p_page_number PLS_INTEGER) IS
  l_page_obj_id PLS_INTEGER;
  l_page_obj CLOB;
  l_media_box VARCHAR2(100);
  l_rotate NUMBER;
  l_resources_id PLS_INTEGER;
  l_contents_id PLS_INTEGER;
BEGIN
  l_page_obj_id := get_page_object_id(p_page_number);

  IF g_page_info_table(p_page_number).media_box IS NOT NULL THEN
    RETURN;
  END IF;

  l_page_obj := get_pdf_object(l_page_obj_id);

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

    l_start := INSTR(l_page_obj, '/Rotate');
    IF l_start > 0 THEN
      l_tmp := SUBSTR(l_page_obj, l_start + 7, 10);
      l_tmp := TRIM(REGEXP_REPLACE(l_tmp, '[^0-9].*', ''));
      IF l_tmp IS NOT NULL THEN
        l_rotate := TO_NUMBER(l_tmp);
      END IF;
    END IF;

    l_start := INSTR(l_page_obj, '/Resources');
    IF l_start > 0 THEN
      l_tmp := SUBSTR(l_page_obj, l_start + 10, 20);
      l_tmp := TRIM(REGEXP_REPLACE(l_tmp, '[^0-9].*', ''));
      IF l_tmp IS NOT NULL THEN
        l_resources_id := TO_NUMBER(l_tmp);
      END IF;
    END IF;

    l_start := INSTR(l_page_obj, '/Contents');
    IF l_start > 0 THEN
      l_tmp := SUBSTR(l_page_obj, l_start + 9, 20);
      l_tmp := TRIM(REGEXP_REPLACE(l_tmp, '[^0-9].*', ''));
      IF l_tmp IS NOT NULL THEN
        l_contents_id := TO_NUMBER(l_tmp);
      END IF;
    END IF;
  END;

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

  IF l_media_box IS NULL THEN
    l_media_box := '0 0 612 792';
    log_message(3, 'MediaBox defaulting to Letter size: ' || l_media_box);
  END IF;

  IF l_rotate IS NULL THEN
    l_rotate := 0;
  END IF;

  g_page_info_table(p_page_number).media_box := l_media_box;
  g_page_info_table(p_page_number).rotate := l_rotate;
  g_page_info_table(p_page_number).resources_id := l_resources_id;
  g_page_info_table(p_page_number).contents_id := l_contents_id;

  log_message(3, 'Extracted page ' || p_page_number || ' info: MediaBox=' || l_media_box);
END extract_page_info;

function GetPageInfo(p_page_number pls_integer default null) return JSON_OBJECT_T is
  l_page_info JSON_OBJECT_T;
  l_page_num pls_integer;
  l_unit VARCHAR2(10);
begin
  l_page_info := JSON_OBJECT_T();

  IF g_loaded_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(g_loaded_pdf) > 0 THEN
    l_page_num := NVL(p_page_number, 1);

    IF l_page_num < 1 OR l_page_num > g_loaded_page_count THEN
      raise_application_error(-20812,
        'Invalid page number: ' || l_page_num || '. Valid range: 1-' || g_loaded_page_count);
    END IF;

    extract_page_info(l_page_num);

    l_page_info.put('pageNumber', l_page_num);
    l_page_info.put('pageObjectId', g_page_info_table(l_page_num).page_obj_id);
    l_page_info.put('mediaBox', g_page_info_table(l_page_num).media_box);
    l_page_info.put('rotation', NVL(g_page_info_table(l_page_num).rotate, 0));
    l_page_info.put('resourcesObjectId', g_page_info_table(l_page_num).resources_id);
    l_page_info.put('contentsObjectId', g_page_info_table(l_page_num).contents_id);

    log_message(c_LOG_DEBUG, 'GetPageInfo: Returned loaded PDF info for page ' || l_page_num);
    RETURN l_page_info;
  END IF;

  if p_page_number is null then
    l_page_num := g_current_page;
  else
    l_page_num := p_page_number;
  end if;

  if l_page_num < 1 or l_page_num > g_current_page then
    raise_application_error(-20106,
      'Invalid page number: ' || l_page_num || '. Must be between 1 and ' || g_current_page);
  end if;

  if not g_pages.exists(l_page_num) then
    raise_application_error(-20106,
      'Page ' || l_page_num || ' not found in page collection');
  end if;

  l_page_info.put('number', l_page_num);

  l_page_info.put('width', g_pages(l_page_num).format.width);
  l_page_info.put('height', g_pages(l_page_num).format.height);

  l_page_info.put('orientation', case g_pages(l_page_num).orientation
    when 'P' then 'Portrait'
    when 'L' then 'Landscape'
    else 'Unknown'
  end);

  l_page_info.put('rotation', g_pages(l_page_num).rotation);

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

  l_mat  PL_FPDF_UTIL.tqr;
  l_n    pls_integer;
  l_ver  pls_integer;
  l_mask pls_integer;
  l_mod  number;
begin
  if p_size is null or p_size <= 0 then
    raise_application_error(-20871, 'AddQRCode: tamanho deve ser maior que zero.');
  end if;

  PL_FPDF_UTIL.qr_matriz(p_data, p_error_correction, l_mat, l_n, l_ver, l_mask);

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

  l_mods := PL_FPDF_UTIL.bc_padrao(p_code, l_type);

  l_n  := length(l_mods);
  l_mw := p_width / l_n;

  SetFillColor(0, 0, 0);

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

FUNCTION parse_pdf_header(p_pdf BLOB) RETURN VARCHAR2 IS
  l_header VARCHAR2(50);
  l_pos PLS_INTEGER;
  l_version VARCHAR2(10);
BEGIN
  l_header := read_blob_chunk(p_pdf, 1, 50);

  IF NOT l_header LIKE '%PDF-%' THEN
    raise_application_error(-20801,
      'Invalid PDF header. Expected %PDF-x.x, got: ' || SUBSTR(l_header, 1, 20));
  END IF;

  l_pos := INSTR(l_header, '%PDF-');
  IF l_pos > 0 THEN
    l_version := SUBSTR(l_header, l_pos + 5, 3);

    IF SUBSTR(l_version, 1, 1) BETWEEN '0' AND '9'
       AND SUBSTR(l_version, 2, 1) = '.'
       AND SUBSTR(l_version, 3, 1) BETWEEN '0' AND '9' THEN
      RETURN l_version;
    END IF;
  END IF;

  RETURN '1.4';
END parse_pdf_header;

FUNCTION find_startxref(p_pdf BLOB) RETURN PLS_INTEGER IS
  l_file_size PLS_INTEGER;
  l_tail VARCHAR2(2048);
  l_offset PLS_INTEGER;
BEGIN
  l_file_size := DBMS_LOB.GETLENGTH(p_pdf);

  l_tail := read_blob_chunk(p_pdf, GREATEST(1, l_file_size - 2047), 2048);

  l_offset := extract_number_after_pattern(l_tail, 'startxref');

  IF l_offset IS NULL THEN
    raise_application_error(-20802, 'startxref not found in PDF');
  END IF;

  RETURN l_offset;
END find_startxref;

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

  l_xref_section := read_blob_chunk(p_pdf, p_xref_offset + 1, 32767);

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

        IF SQLCODE IN (-20843, -20847, -20848) THEN
          RAISE;
        END IF;

        g_xref_table.DELETE;
        g_objstm_body.DELETE;
        log_message(3, 'nao e xref em stream (' || SQLERRM
                       || '); tentando achar a tabela classica');
    END;
  END IF;

  IF l_xref_section IS NULL OR NOT l_xref_section LIKE 'xref%' THEN

    DECLARE
      l_file_size PLS_INTEGER := DBMS_LOB.GETLENGTH(p_pdf);
      l_search_start PLS_INTEGER;
      l_chunk_size PLS_INTEGER := LEAST(l_file_size, 32767);
    BEGIN
      l_search_start := GREATEST(1, l_file_size - l_chunk_size + 1);
      l_search_chunk := read_blob_chunk(p_pdf, l_search_start, l_chunk_size);

      l_xref_pos := 0;
      DECLARE
        l_tmp PLS_INTEGER;
      BEGIN
        l_tmp := INSTR(l_search_chunk, 'xref' || CHR(10));
        WHILE l_tmp > 0 LOOP

          IF l_tmp = 1 OR SUBSTR(l_search_chunk, l_tmp - 1, 1) = CHR(10) THEN
            l_xref_pos := l_tmp;
          END IF;
          l_tmp := INSTR(l_search_chunk, 'xref' || CHR(10), l_tmp + 1);
        END LOOP;
      END;

      IF l_xref_pos > 0 THEN
        l_actual_offset := l_search_start + l_xref_pos - 2;
        l_xref_section := read_blob_chunk(p_pdf, l_actual_offset + 1, 32767);

        g_xref_offset := l_actual_offset;
        log_message(2, 'xref found at offset ' || l_actual_offset ||
                       ' (startxref said ' || p_xref_offset || ')');
      END IF;
    END;

    IF l_xref_section IS NULL OR NOT l_xref_section LIKE 'xref%' THEN
      raise_application_error(-20803, 'Invalid xref table at offset ' || p_xref_offset);
    END IF;
  END IF;

  IF INSTR(l_xref_section, 'trailer') = 0
     AND DBMS_LOB.GETLENGTH(p_pdf) - l_actual_offset > 32767 THEN
    raise_application_error(-20841,
      'Secao xref classica em ' || l_actual_offset || ': o trailer nao cabe ' ||
      'nos 32767 bytes que se le de uma vez (mais de ~1638 entradas, ' ||
      (DBMS_LOB.GETLENGTH(p_pdf) - l_actual_offset) || ' bytes ate o fim do ' ||
      'arquivo). Este PDF nao e suportado pela leitura de xref classica.');
  END IF;

  l_xref_section := REPLACE(l_xref_section, CHR(13), '');

  l_pos := INSTR(l_xref_section, CHR(10)) + 1;

  l_line_end := INSTR(l_xref_section, CHR(10), l_pos);
  l_line := TRIM(SUBSTR(l_xref_section, l_pos, l_line_end - l_pos));
  l_obj_start := TO_NUMBER(REGEXP_SUBSTR(l_line, '^[0-9]+'));
  l_obj_count := TO_NUMBER(REGEXP_SUBSTR(l_line, '[0-9]+$'));
  l_pos := l_line_end + 1;

  l_obj_id := l_obj_start;

  FOR idx IN 1..l_obj_count LOOP
    EXIT WHEN l_pos > LENGTH(l_xref_section);

    l_line_end := INSTR(l_xref_section, CHR(10), l_pos);
    IF l_line_end = 0 THEN
      l_line_end := LENGTH(l_xref_section) + 1;
    END IF;

    l_line := SUBSTR(l_xref_section, l_pos, l_line_end - l_pos);
    EXIT WHEN l_line LIKE 'trailer%';

    IF LENGTH(l_line) >= 18 THEN
      l_offset := TO_NUMBER(TRIM(SUBSTR(l_line, 1, 10)));
      l_generation := TO_NUMBER(TRIM(SUBSTR(l_line, 12, 5)));
      l_flag := SUBSTR(l_line, 18, 1);

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

PROCEDURE parse_trailer(p_pdf BLOB, p_xref_offset PLS_INTEGER) IS
  l_trailer VARCHAR2(4000);
  l_root_id PLS_INTEGER;
BEGIN

  l_trailer := read_blob_chunk(p_pdf, p_xref_offset + 1, 4000);

  l_root_id := TO_NUMBER(
    REGEXP_SUBSTR(l_trailer, '/Root\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_root_id IS NULL THEN
    raise_application_error(-20804, 'Root object not found in trailer');
  END IF;

  g_root_obj_id := l_root_id;

  log_message(3, 'Trailer parsed: Root=' || g_root_obj_id);
END parse_trailer;

FUNCTION count_pages RETURN PLS_INTEGER IS
  l_catalog CLOB;
  l_pages_id PLS_INTEGER;
  l_pages_obj CLOB;
  l_count PLS_INTEGER;
BEGIN

  l_catalog := get_pdf_object(g_root_obj_id);

  l_pages_id := TO_NUMBER(
    REGEXP_SUBSTR(l_catalog, '/Pages\s+([0-9]+)\s+0\s+R', 1, 1, NULL, 1)
  );

  IF l_pages_id IS NULL THEN
    raise_application_error(-20807, 'Pages not found in Catalog');
  END IF;

  l_pages_obj := get_pdf_object(l_pages_id);

  l_count := TO_NUMBER(
    REGEXP_SUBSTR(l_pages_obj, '/Count\s+([0-9]+)', 1, 1, NULL, 1)
  );

  IF l_count IS NULL THEN
    raise_application_error(-20808, 'Count not found in Pages object');
  END IF;

  RETURN l_count;
END count_pages;

PROCEDURE LoadPDF(p_pdf_blob BLOB) IS
BEGIN
  log_message(3, 'Loading PDF...');

  IF p_pdf_blob IS NULL OR DBMS_LOB.GETLENGTH(p_pdf_blob) < 100 THEN
    raise_application_error(-20800, 'Invalid PDF: NULL or too small');
  END IF;

  g_loaded_pdf := p_pdf_blob;
  g_object_cache.DELETE;
  g_xref_table.DELETE;

  g_pdf_version := parse_pdf_header(p_pdf_blob);
  log_message(3, 'PDF version: ' || g_pdf_version);

  g_xref_offset := find_startxref(p_pdf_blob);
  log_message(3, 'startxref value: ' || g_xref_offset);

  parse_xref_table(p_pdf_blob, g_xref_offset);

  parse_trailer(p_pdf_blob, g_xref_offset);

  g_loaded_page_count := count_pages();

  parse_page_tree();

  log_message(2, 'PDF loaded successfully: ' || g_loaded_page_count || ' pages, version ' || g_pdf_version);

EXCEPTION
  WHEN OTHERS THEN
    log_message(1, 'Error loading PDF: ' || SQLERRM);
    RAISE;
END LoadPDF;

FUNCTION GetPageCount RETURN PLS_INTEGER IS
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  RETURN g_loaded_page_count;
END GetPageCount;

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

PROCEDURE RotatePage(p_page_number PLS_INTEGER, p_rotation NUMBER) IS
  l_valid_rotations VARCHAR2(20) := '0,90,180,270';
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  IF INSTR(l_valid_rotations, TO_CHAR(p_rotation)) = 0 THEN
    raise_application_error(-20813,
      'Invalid rotation: ' || p_rotation || '. Valid values: 0, 90, 180, 270');
  END IF;

  extract_page_info(p_page_number);

  g_page_info_table(p_page_number).rotate := p_rotation;

  log_message(3, 'Page ' || p_page_number || ' rotation set to ' || p_rotation || ' degrees');

  g_pdf_modified := TRUE;
END RotatePage;

PROCEDURE RemovePage(p_page_number PLS_INTEGER) IS
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  IF p_page_number < 1 OR p_page_number > g_loaded_page_count THEN
    raise_application_error(-20812,
      'Invalid page number: ' || p_page_number ||
      '. Valid range: 1-' || g_loaded_page_count);
  END IF;

  IF g_removed_pages.EXISTS(p_page_number) AND g_removed_pages(p_page_number) THEN
    raise_application_error(-20814,
      'Page ' || p_page_number || ' is already marked for removal');
  END IF;

  g_removed_pages(p_page_number) := TRUE;
  g_pdf_modified := TRUE;

  log_message(3, 'Page ' || p_page_number || ' marked for removal');
END RemovePage;

FUNCTION GetActivePageCount RETURN PLS_INTEGER IS
  l_count PLS_INTEGER := 0;
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  FOR i IN 1..g_loaded_page_count LOOP
    IF NOT (g_removed_pages.EXISTS(i) AND g_removed_pages(i)) THEN
      l_count := l_count + 1;
    END IF;
  END LOOP;

  RETURN l_count;
END GetActivePageCount;

FUNCTION IsPageRemoved(p_page_number PLS_INTEGER) RETURN BOOLEAN IS
BEGIN
  IF g_removed_pages.EXISTS(p_page_number) THEN
    RETURN g_removed_pages(p_page_number);
  END IF;
  RETURN FALSE;
END IsPageRemoved;

FUNCTION IsPDFModified RETURN BOOLEAN IS
BEGIN
  RETURN g_pdf_modified;
END IsPDFModified;

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

  IF l_range = 'ALL' THEN
    FOR i IN 1..p_total_pages LOOP
      l_result := l_result || i || ',';
    END LOOP;
    RETURN RTRIM(l_result, ',');
  END IF;

  l_parts := split_string(l_range, ',');

  FOR i IN 1..l_parts.COUNT LOOP
    l_item := TRIM(l_parts(i));
    l_dash_pos := INSTR(l_item, '-');

    IF l_dash_pos > 0 THEN

      l_from := TO_NUMBER(SUBSTR(l_item, 1, l_dash_pos - 1));
      l_to := TO_NUMBER(SUBSTR(l_item, l_dash_pos + 1));

      IF l_from < 1 OR l_to > p_total_pages OR l_from > l_to THEN
        raise_application_error(-20815,
          'Invalid page range: ' || l_item || '. Valid pages: 1-' || p_total_pages);
      END IF;

      FOR j IN l_from..l_to LOOP
        l_result := l_result || j || ',';
      END LOOP;
    ELSE

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

FUNCTION is_page_in_range(
  p_page_number PLS_INTEGER,
  p_parsed_range VARCHAR2
) RETURN BOOLEAN IS
  l_page_str VARCHAR2(20);
BEGIN
  l_page_str := ',' || p_parsed_range || ',';
  RETURN INSTR(l_page_str, ',' || p_page_number || ',') > 0;
END is_page_in_range;

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

  l_parsed_range := parse_page_range(p_pages, g_loaded_page_count);

  g_watermark_count := g_watermark_count + 1;
  l_watermark.text := p_text;
  l_watermark.opacity := p_opacity;
  l_watermark.rotation := p_rotation;
  l_watermark.page_range := l_parsed_range;
  l_watermark.font_name := p_font;
  l_watermark.font_size := p_size;
  l_watermark.color := p_color;

  g_watermarks(g_watermark_count) := l_watermark;

  g_pdf_modified := TRUE;

  log_message(3, 'Watermark added: "' || p_text || '" on pages: ' || p_pages);
END AddWatermark;

FUNCTION GetWatermarks RETURN JSON_ARRAY_T IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_watermark JSON_OBJECT_T;
  l_idx PLS_INTEGER;
BEGIN
  IF g_loaded_pdf IS NULL THEN
    raise_application_error(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

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
  l_vistos tbool;
  TYPE tbool_v IS TABLE OF BOOLEAN INDEX BY VARCHAR2(20);
  l_fontes_vistas tbool_v;
  l_larg   NUMBER;
  l_alt    NUMBER;
  l_idx    PLS_INTEGER;
  l_chave  VARCHAR2(50);
  l_r      NUMBER;
  l_g      NUMBER;
  l_b      NUMBER;

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

  PROCEDURE medidas(p_mb IN VARCHAR2) IS
    l_p tv4000;
    FUNCTION n(p IN VARCHAR2) RETURN NUMBER IS
    BEGIN
      RETURN TO_NUMBER(TRIM(p), 'TM9', co_nls_num);
    EXCEPTION
      WHEN OTHERS THEN RETURN NULL;
    END;
  BEGIN
    l_larg := 612; l_alt := 792;
    l_p := split_string(TRIM(REGEXP_REPLACE(
             REPLACE(REPLACE(NVL(p_mb, ''), '['), ']'), '\s+', ' ')), ' ');
    IF l_p.COUNT >= 4 AND n(l_p(1)) IS NOT NULL AND n(l_p(3)) IS NOT NULL THEN
      l_larg := ABS(n(l_p(3)) - n(l_p(1)));
      l_alt  := ABS(n(l_p(4)) - n(l_p(2)));
    END IF;
    IF NVL(l_larg, 0) <= 0 THEN l_larg := 612; END IF;
    IF NVL(l_alt, 0)  <= 0 THEN l_alt  := 792; END IF;
  END medidas;

  PROCEDURE usar_opacidade(p_opac IN NUMBER) IS
    l_k PLS_INTEGER := ROUND(LEAST(GREATEST(NVL(p_opac, 1), 0), 1) * 100);
  BEGIN
    IF NOT l_vistos.EXISTS(l_k) THEN
      l_vistos(l_k) := TRUE;
      l_gs := l_gs || ' ' || ovl_gs_entrada(p_opac);
    END IF;
  END usar_opacidade;

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

  FOR i IN 1 .. l_srcs(1).pages.COUNT LOOP
    IF g_page_info_table.EXISTS(i) AND g_page_info_table(i).rotate IS NOT NULL THEN
      l_oid := l_srcs(1).pages(i);
      l_srcs(1).rot_force(l_oid) :=
        TO_CHAR(MOD(NVL(g_page_info_table(i).rotate, 0), 360), 'TM9', co_nls_num);
    END IF;
  END LOOP;

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
          usar_fonte('Helvetica', FALSE);
        END IF;
        l_idx := g_watermarks.NEXT(l_idx);
      END LOOP;

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

              IF l_w IS NULL AND l_h IS NULL THEN
                l_w := l_pw; l_h := l_ph;
              ELSIF l_w IS NULL THEN
                l_w := l_h * l_pw / GREATEST(l_ph, 1);
              ELSIF l_h IS NULL THEN
                l_h := l_w * l_ph / GREATEST(l_pw, 1);
              ELSIF NVL(g_overlays(l_chave).maintain_aspect, FALSE) THEN

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

FUNCTION FlateEncode(
  p_data IN BLOB
) RETURN BLOB IS
  l_saida BLOB;
  l_ent   BLOB := p_data;
  l_vazio BOOLEAN := p_data IS NULL;
BEGIN

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

PROCEDURE ClearPDFCache IS
BEGIN
  g_loaded_pdf := NULL;
  g_object_cache.DELETE;
  g_xref_table.DELETE;

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

  g_loaded_pdfs.DELETE;
  g_loaded_pdf_count := 0;

  log_message(3, 'PDF cache cleared (including overlays and loaded PDFs)');
END ClearPDFCache;

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

  IF g_loaded_pdf IS NULL OR DBMS_LOB.GETLENGTH(g_loaded_pdf) = 0 THEN

    RAISE_APPLICATION_ERROR(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  IF p_page_number < 1 OR p_page_number > g_loaded_page_count THEN
    RAISE_APPLICATION_ERROR(-20810, 'Invalid page number: ' || p_page_number ||
                        '. PDF has ' || g_loaded_page_count || ' pages.');
  END IF;

  IF p_x < 0 OR p_y < 0 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid position coordinates. X and Y must be >= 0.');
  END IF;

  g_overlay_count := g_overlay_count + 1;
  l_overlay_id := 'OVL_TEXT_' || LPAD(g_overlay_count, 5, '0');

  l_overlay.overlay_id := l_overlay_id;
  l_overlay.overlay_type := 'TEXT';
  l_overlay.page_number := p_page_number;
  l_overlay.x := p_x;
  l_overlay.y := p_y;
  l_overlay.content := p_text;
  l_overlay.created_date := SYSTIMESTAMP;

  IF p_options IS NOT NULL THEN
    l_overlay.font_name := NVL(p_options.get_string('font'), 'Helvetica');
    l_overlay.font_size := NVL(p_options.get_number('fontSize'), 12);
    l_overlay.color := NVL(p_options.get_string('color'), '000000');
    l_overlay.opacity := NVL(p_options.get_number('opacity'), 1.0);
    l_overlay.rotation := NVL(p_options.get_number('rotation'), 0);
    l_overlay.align := NVL(p_options.get_string('align'), 'left');
    l_overlay.bold := NVL(p_options.get_boolean('bold'), FALSE);
    l_overlay.z_order := NVL(p_options.get_number('zOrder'), 100);
    l_overlay.width := p_options.get_number('width');
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

  IF l_overlay.opacity < 0 OR l_overlay.opacity > 1 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid opacity. Must be between 0.0 and 1.0.');
  END IF;

  g_overlays(l_overlay_id) := l_overlay;
  g_pdf_modified := TRUE;

  log_message(3, 'Text overlay added: ' || l_overlay_id || ' on page ' || p_page_number);
END OverlayText;

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

  IF g_loaded_pdf IS NULL OR DBMS_LOB.GETLENGTH(g_loaded_pdf) = 0 THEN
    RAISE_APPLICATION_ERROR(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  IF p_page_number < 1 OR p_page_number > g_loaded_page_count THEN
    RAISE_APPLICATION_ERROR(-20810, 'Invalid page number: ' || p_page_number);
  END IF;

  IF p_x < 0 OR p_y < 0 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid position coordinates. X and Y must be >= 0.');
  END IF;

  IF p_image_blob IS NULL OR DBMS_LOB.GETLENGTH(p_image_blob) = 0 THEN
    RAISE_APPLICATION_ERROR(-20823, 'Invalid image: image blob is empty or NULL.');
  END IF;

  l_img_signature := DBMS_LOB.SUBSTR(p_image_blob, 8, 1);
  IF l_img_signature != c_PNG_SIGNATURE AND
     DBMS_LOB.SUBSTR(p_image_blob, 2, 1) != c_JPEG_SOI THEN
    RAISE_APPLICATION_ERROR(-20823, 'Invalid image format. Only JPEG and PNG are supported.');
  END IF;

  IF p_width IS NOT NULL AND p_width <= 0 THEN
    RAISE_APPLICATION_ERROR(-20824, 'Invalid width. Must be > 0 or NULL for original size.');
  END IF;
  IF p_height IS NOT NULL AND p_height <= 0 THEN
    RAISE_APPLICATION_ERROR(-20824, 'Invalid height. Must be > 0 or NULL for original size.');
  END IF;

  g_overlay_count := g_overlay_count + 1;
  l_overlay_id := 'OVL_IMG_' || LPAD(g_overlay_count, 5, '0');

  l_overlay.overlay_id := l_overlay_id;
  l_overlay.overlay_type := 'IMAGE';
  l_overlay.page_number := p_page_number;
  l_overlay.x := p_x;
  l_overlay.y := p_y;
  l_overlay.width := p_width;
  l_overlay.height := p_height;
  l_overlay.image_blob := p_image_blob;
  l_overlay.created_date := SYSTIMESTAMP;

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

  IF l_overlay.opacity < 0 OR l_overlay.opacity > 1 THEN
    RAISE_APPLICATION_ERROR(-20821, 'Invalid opacity. Must be between 0.0 and 1.0.');
  END IF;

  g_overlays(l_overlay_id) := l_overlay;
  g_pdf_modified := TRUE;

  log_message(3, 'Image overlay added: ' || l_overlay_id || ' on page ' || p_page_number);
END OverlayImage;

FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T
IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_overlay_obj JSON_OBJECT_T;
  l_overlay overlay_rec;
  l_key VARCHAR2(50);
BEGIN

  IF g_loaded_pdf IS NULL OR DBMS_LOB.GETLENGTH(g_loaded_pdf) = 0 THEN
    RAISE_APPLICATION_ERROR(-20809, 'No PDF loaded. Call LoadPDF() first.');
  END IF;

  l_key := g_overlays.FIRST;
  WHILE l_key IS NOT NULL LOOP
    l_overlay := g_overlays(l_key);

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

PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2) IS
BEGIN
  IF NOT g_overlays.EXISTS(p_overlay_id) THEN
    RAISE_APPLICATION_ERROR(-20825, 'Overlay not found: ' || p_overlay_id);
  END IF;

  g_overlays.DELETE(p_overlay_id);
  log_message(3, 'Overlay removed: ' || p_overlay_id);
END RemoveOverlay;

PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL) IS
  l_key VARCHAR2(50);
  l_overlay overlay_rec;
  TYPE key_list IS TABLE OF VARCHAR2(50);
  l_keys_to_delete key_list := key_list();
BEGIN
  IF p_page_number IS NULL THEN

    g_overlays.DELETE;
    g_overlay_count := 0;
    log_message(3, 'All overlays cleared');
  ELSE

    l_key := g_overlays.FIRST;
    WHILE l_key IS NOT NULL LOOP
      l_overlay := g_overlays(l_key);
      IF l_overlay.page_number = p_page_number THEN
        l_keys_to_delete.EXTEND;
        l_keys_to_delete(l_keys_to_delete.COUNT) := l_key;
      END IF;
      l_key := g_overlays.NEXT(l_key);
    END LOOP;

    FOR i IN 1..l_keys_to_delete.COUNT LOOP
      g_overlays.DELETE(l_keys_to_delete(i));
    END LOOP;

    log_message(3, 'Overlays cleared for page ' || p_page_number ||
                   ': ' || l_keys_to_delete.COUNT || ' overlays removed');
  END IF;
END ClearOverlays;

PROCEDURE LoadPDFWithID(
  p_pdf_id IN VARCHAR2,
  p_pdf_blob IN BLOB
) IS
  l_doc pdf_document_rec;
BEGIN

  IF p_pdf_id IS NULL OR LENGTH(TRIM(p_pdf_id)) = 0 THEN
    RAISE_APPLICATION_ERROR(-20830, 'Invalid PDF ID: cannot be empty or NULL');
  END IF;

  IF LENGTH(p_pdf_id) > 50 THEN
    RAISE_APPLICATION_ERROR(-20830, 'Invalid PDF ID: maximum length is 50 characters');
  END IF;

  IF g_loaded_pdfs.EXISTS(p_pdf_id) THEN
    RAISE_APPLICATION_ERROR(-20828, 'PDF ID already loaded: ' || p_pdf_id);
  END IF;

  IF g_loaded_pdf_count >= c_max_loaded_pdfs THEN
    RAISE_APPLICATION_ERROR(-20829, 'Maximum loaded PDFs exceeded. Limit is ' ||
                c_max_loaded_pdfs || ' PDFs. Unload some PDFs first.');
  END IF;

  IF p_pdf_blob IS NULL OR DBMS_LOB.GETLENGTH(p_pdf_blob) = 0 THEN
    RAISE_APPLICATION_ERROR(-20830, 'Invalid PDF: blob is empty or NULL');
  END IF;

  l_doc.pdf_id := p_pdf_id;
  l_doc.pdf_blob := p_pdf_blob;
  l_doc.file_size := DBMS_LOB.GETLENGTH(p_pdf_blob);
  l_doc.loaded_date := SYSTIMESTAMP;

  BEGIN

    DECLARE
      l_saved_blob BLOB := g_loaded_pdf;
      l_saved_count PLS_INTEGER := g_loaded_page_count;
    BEGIN

      LoadPDF(p_pdf_blob);
      l_doc.page_count := g_loaded_page_count;
      l_doc.pdf_version := g_pdf_version;

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

  g_loaded_pdfs(p_pdf_id) := l_doc;
  g_loaded_pdf_count := g_loaded_pdf_count + 1;

  log_message(3, 'PDF loaded with ID: ' || p_pdf_id ||
              ' (' || l_doc.page_count || ' pages, ' ||
              ROUND(l_doc.file_size/1024, 1) || ' KB)');
END LoadPDFWithID;

FUNCTION GetLoadedPDFs RETURN JSON_ARRAY_T IS
  l_result JSON_ARRAY_T := JSON_ARRAY_T();
  l_pdf_obj JSON_OBJECT_T;
  l_doc pdf_document_rec;
  l_key VARCHAR2(50);
BEGIN

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

PROCEDURE UnloadPDF(p_pdf_id IN VARCHAR2) IS
BEGIN
  IF NOT g_loaded_pdfs.EXISTS(p_pdf_id) THEN
    RAISE_APPLICATION_ERROR(-20831, 'PDF ID not found: ' || p_pdf_id);
  END IF;

  g_loaded_pdfs.DELETE(p_pdf_id);
  g_loaded_pdf_count := g_loaded_pdf_count - 1;

  log_message(3, 'PDF unloaded: ' || p_pdf_id);
END UnloadPDF;

PROCEDURE pdf_walk_pages(
  p_src   IN OUT NOCOPY pdf_source_rec,
  p_oid   IN PLS_INTEGER,
  p_media IN VARCHAR2,
  p_res   IN VARCHAR2,
  p_crop  IN VARCHAR2,
  p_rot   IN VARCHAR2,
  p_depth IN PLS_INTEGER
);

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

PROCEDURE pdf_app(p_out IN OUT NOCOPY BLOB, p_txt IN VARCHAR2) IS
  l_raw RAW(32767);
BEGIN
  IF p_txt IS NULL OR LENGTHB(p_txt) = 0 THEN
    RETURN;
  END IF;
  l_raw := UTL_RAW.CAST_TO_RAW(p_txt);
  DBMS_LOB.WRITEAPPEND(p_out, UTL_RAW.LENGTH(l_raw), l_raw);
END pdf_app;

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

FUNCTION pdf_scan_refs(
  p_text    IN VARCHAR2,
  p_shift   IN PLS_INTEGER,
  p_ids     IN OUT NOCOPY tpi,
  p_collect IN BOOLEAN
) RETURN VARCHAR2 IS
  l_out  VARCHAR2(32767);
  l_n    PLS_INTEGER := NVL(LENGTHB(p_text), 0);
  l_i    PLS_INTEGER := 1;
  l_keep PLS_INTEGER := 1;
  l_j    PLS_INTEGER;
  l_k    PLS_INTEGER;
  l_d1e  PLS_INTEGER;
  l_d2s  PLS_INTEGER;
  l_d2e  PLS_INTEGER;
  l_id   PLS_INTEGER;
BEGIN
  WHILE l_i <= l_n LOOP
    IF SUBSTRB(p_text, l_i, 1) BETWEEN '0' AND '9'
       AND (l_i = 1 OR NOT pdf_is_alnum(SUBSTRB(p_text, l_i - 1, 1))) THEN

      l_j := l_i;
      WHILE l_j <= l_n AND SUBSTRB(p_text, l_j, 1) BETWEEN '0' AND '9' LOOP
        l_j := l_j + 1;
      END LOOP;
      l_d1e := l_j - 1;

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
            l_keep := l_k + 1;
            l_i    := l_keep;
            CONTINUE;
          END IF;
        END IF;
      END IF;

      l_i := l_d1e + 1;
    ELSE
      l_i := l_i + 1;
    END IF;
  END LOOP;

  IF p_collect THEN
    RETURN NULL;
  END IF;
  RETURN l_out || SUBSTRB(p_text, l_keep);
END pdf_scan_refs;

PROCEDURE pdf_collect_refs(p_text IN VARCHAR2, p_ids IN OUT NOCOPY tpi) IS
BEGIN

  IF pdf_scan_refs(p_text, 0, p_ids, TRUE) IS NOT NULL THEN
    NULL;
  END IF;
END pdf_collect_refs;

FUNCTION pdf_key_pos(p_dict IN VARCHAR2, p_key IN VARCHAR2) RETURN PLS_INTEGER IS
  l_i PLS_INTEGER := INSTRB(p_dict, p_key);
BEGIN
  WHILE NVL(l_i, 0) > 0
        AND pdf_is_alnum(SUBSTRB(p_dict, l_i + LENGTHB(p_key), 1)) LOOP
    l_i := INSTRB(p_dict, p_key, l_i + 1);
  END LOOP;
  RETURN NVL(l_i, 0);
END pdf_key_pos;

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

  IF SUBSTRB(p_dict, l_j, 1) = '/' THEN
    l_k := l_j + 1;
    WHILE l_k <= l_n
          AND NOT pdf_is_ws(SUBSTRB(p_dict, l_k, 1))
          AND SUBSTRB(p_dict, l_k, 1) NOT IN ('/', '[', ']', '<', '>', '(', ')') LOOP
      l_k := l_k + 1;
    END LOOP;
    RETURN SUBSTRB(p_dict, l_j, l_k - l_j);
  END IF;

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

  l_k := l_j;
  WHILE l_k <= l_n AND pdf_is_alnum(SUBSTRB(p_dict, l_k, 1)) LOOP
    l_k := l_k + 1;
  END LOOP;
  IF l_k > l_j THEN
    RETURN SUBSTRB(p_dict, l_j, l_k - l_j);
  END IF;
  RETURN NULL;
END pdf_dict_value;

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

PROCEDURE pdf_obj_extent(
  p_src      IN pdf_source_rec,
  p_oid      IN PLS_INTEGER,
  o_start    OUT PLS_INTEGER,
  o_end      OUT PLS_INTEGER,
  o_dict_end OUT PLS_INTEGER,
  o_len      OUT PLS_INTEGER
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
  l_lz     PLS_INTEGER;
  l_ids    tpi;
BEGIN

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

  IF l_ps = 0 OR (l_pe > 0 AND l_pe < l_ps) THEN
    IF l_pe = 0 THEN
      RAISE_APPLICATION_ERROR(-20806, 'endobj nao encontrado no objeto ' || p_oid);
    END IF;
    o_end      := l_off + l_pe + 5;
    o_dict_end := o_end;
    o_len      := 0;
    RETURN;
  END IF;

  l_lenval := pdf_dict_value(SUBSTRB(l_head, 1, l_ps - 1), '/Length');
  IF l_lenval IS NULL THEN
    RAISE_APPLICATION_ERROR(-20840, '/Length ausente no objeto ' || p_oid);
  END IF;
  IF INSTRB(l_lenval, 'R') > 0 THEN
    l_ids.DELETE;
    pdf_collect_refs(l_lenval, l_ids);
    l_lid := l_ids(1);
    IF NOT p_src.xref.EXISTS(l_lid) THEN
      RAISE_APPLICATION_ERROR(-20840,
        '/Length indireto aponta para objeto ausente (' || l_lid || ')');
    END IF;
    IF p_src.objstm.EXISTS(l_lid) THEN
      l_lenval := p_src.objstm(l_lid);
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

  l_data := l_off + l_ps + 5;
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

  o_dict_end := l_data;
  o_len      := l_len;
END pdf_obj_extent;

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

  WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(l_raw, l_i, 1)) LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND SUBSTRB(l_raw, l_i, 1) BETWEEN '0' AND '9' LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(l_raw, l_i, 1)) LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND SUBSTRB(l_raw, l_i, 1) BETWEEN '0' AND '9' LOOP l_i := l_i + 1; END LOOP;
  WHILE l_i <= l_n AND pdf_is_ws(SUBSTRB(l_raw, l_i, 1)) LOOP l_i := l_i + 1; END LOOP;
  IF SUBSTRB(l_raw, l_i, 3) = 'obj' THEN
    l_i := l_i + 3;
  ELSE
    l_i := 1;
  END IF;
  RETURN SUBSTRB(l_raw, l_i);
END pdf_obj_body;

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

FUNCTION pdf_be(p_dados IN BLOB, p_off IN PLS_INTEGER, p_len IN PLS_INTEGER)
  RETURN NUMBER IS
BEGIN
  IF p_len <= 0 THEN
    RETURN 0;
  END IF;
  RETURN TO_NUMBER(RAWTOHEX(DBMS_LOB.SUBSTR(p_dados, p_len, p_off + 1)),
                   RPAD('X', p_len * 2, 'X'));
END pdf_be;

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
  l_p     PLS_INTEGER := 1;
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

    RAISE_APPLICATION_ERROR(-20848,
      'xref em stream: /Predictor ' || p_pred || ' (TIFF) nao suportado.');
  END IF;

  l_bpp   := GREATEST(1, CEIL(p_cores * p_bpc / 8));
  l_linha := CEIL(p_cols * p_cores * p_bpc / 8);
  IF l_linha < 1 OR l_linha > 16000 THEN

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
        WHEN 0 THEN l_pred := 0;
        WHEN 1 THEN l_pred := l_esq;
        WHEN 2 THEN l_pred := l_cima;
        WHEN 3 THEN l_pred := FLOOR((l_esq + l_cima) / 2);
        WHEN 4 THEN
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

PROCEDURE pdf_stream_data(
  p_doc   IN            BLOB,
  p_off   IN            PLS_INTEGER,
  o_dic   OUT           VARCHAR2,
  o_dados IN OUT NOCOPY BLOB,

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

  l_ini := p_off + l_ps + 5;
  IF pdf_read(p_doc, l_ini, 2) = CHR(13) || CHR(10) THEN
    l_ini := l_ini + 2;
  ELSIF pdf_read(p_doc, l_ini, 1) IN (CHR(10), CHR(13)) THEN
    l_ini := l_ini + 1;
  END IF;

  IF NVL(DBMS_LOB.GETLENGTH(o_dados), 0) > 0 THEN
    DBMS_LOB.TRIM(o_dados, 0);
  END IF;

  DBMS_LOB.CREATETEMPORARY(l_cru, TRUE);
  IF l_len > 0 THEN
    IF p_chave IS NULL THEN
      DBMS_LOB.COPY(l_cru, p_doc, l_len, 1, l_ini + 1);
    ELSE

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

PROCEDURE pdf_xref_stream(
  p_doc     IN            BLOB,
  p_off     IN            PLS_INTEGER,
  p_src     IN OUT NOCOPY pdf_source_rec,
  p_stm     IN OUT NOCOPY tpi,
  o_trailer OUT           VARCHAR2
) IS
  l_dados BLOB;
  l_w     tpi;
  l_ind   tpi;
  l_larg  PLS_INTEGER;
  l_tot   PLS_INTEGER;
  l_p     PLS_INTEGER := 0;
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

      IF NOT p_src.xref.EXISTS(l_oid) THEN
        IF l_tipo = 1 THEN
          l_ent.offset     := l_a;
          l_ent.generation := l_b;
          p_src.xref(l_oid) := l_ent;
        ELSIF l_tipo = 2 THEN

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

    IF p_stm.EXISTS(l_oid) AND p_stm(l_oid) = p_stm_oid THEN

      p_src.objstm(l_oid) :=
        LTRIM(RTRIM(pdf_read(l_dados, l_ini, l_fim - l_ini),
                    ' ' || CHR(10) || CHR(13) || CHR(9)),
              ' ' || CHR(10) || CHR(13) || CHR(9))
        || CHR(10) || 'endobj';
    END IF;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(l_dados);
END pdf_objstm_load;

FUNCTION pdf_src_load(
  p_doc          IN BLOB,

  p_chave        IN RAW     DEFAULT NULL,
  p_aes          IN BOOLEAN DEFAULT FALSE,
  p_r6           IN BOOLEAN DEFAULT FALSE,

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
  l_trailer VARCHAR2(32767);
  l_prev    VARCHAR2(200);
  l_root    PLS_INTEGER;
  l_rootval VARCHAR2(200);
  l_ent     xref_entry_rec;
  l_pages   PLS_INTEGER;
  l_ids     tpi;
  l_seen    tbool;
  l_guard   PLS_INTEGER := 0;
  l_stm     tpi;
  l_quais   tbool;
  l_hib     VARCHAR2(200);
  l_lixo    VARCHAR2(32767);

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

  WHILE l_off IS NOT NULL AND NOT l_seen.EXISTS(l_off) LOOP
    l_seen(l_off) := TRUE;
    l_guard := l_guard + 1;
    EXIT WHEN l_guard > 64;

    l_sec := pdf_read(p_doc, l_off, 32767);
    l_n   := NVL(LENGTHB(l_sec), 0);

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

        IF l_type = 'n' AND NOT l_src.xref.EXISTS(l_start + i) THEN
          l_ent.offset     := l_eoff;
          l_ent.generation := l_gen;
          l_ent.in_use     := TRUE;
          l_src.xref(l_start + i) := l_ent;
        END IF;
      END LOOP;
    END LOOP;

    l_t := INSTRB(l_sec, 'trailer');

    IF l_t = 0 AND l_n >= 32767 THEN
      RAISE_APPLICATION_ERROR(-20841,
        'Secao xref classica em ' || l_off || ' excede os 32767 bytes que se ' ||
        'consegue ler de uma vez (mais de ~1638 entradas). Este PDF nao e ' ||
        'suportado pela leitura de xref classica.');
    END IF;
    EXIT WHEN l_t = 0;
    l_trailer := SUBSTRB(l_sec, l_t, 4000);

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

FUNCTION ovl_escape(p_txt IN VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  RETURN p_texto_pdf(p_txt);
END ovl_escape;

FUNCTION ovl_familia(p_fonte IN VARCHAR2) RETURN VARCHAR2 IS
  l_f VARCHAR2(50) := LOWER(TRIM(NVL(p_fonte, 'helvetica')));
BEGIN
  RETURN CASE
           WHEN l_f IN ('times', 'times-roman', 'timesnewroman') THEN 'T'
           WHEN l_f IN ('courier', 'couriernew', 'mono')         THEN 'C'
           ELSE 'H'
         END;
END ovl_familia;

FUNCTION ovl_fonte_nome(p_fonte IN VARCHAR2, p_bold IN BOOLEAN)
  RETURN VARCHAR2 IS
BEGIN
  RETURN 'Fwm' || ovl_familia(p_fonte)
      || CASE WHEN NVL(p_bold, FALSE) THEN 'B' END;
END ovl_fonte_nome;

FUNCTION ovl_fonte_base(p_fonte IN VARCHAR2, p_bold IN BOOLEAN)
  RETURN VARCHAR2 IS
  l_fam VARCHAR2(1) := ovl_familia(p_fonte);
  l_b   BOOLEAN := NVL(p_bold, FALSE);
BEGIN
  RETURN CASE l_fam

           WHEN 'T' THEN CASE WHEN l_b THEN 'Times-Bold' ELSE 'Times-Roman' END
           WHEN 'C' THEN 'Courier' || CASE WHEN l_b THEN '-Bold' END
           ELSE          'Helvetica' || CASE WHEN l_b THEN '-Bold' END
         END;
END ovl_fonte_base;

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

  l_cw := p_larguras_da_fonte(
            CASE l_fam
              WHEN 'T' THEN CASE WHEN l_b THEN 'timesB' ELSE 'times' END
              WHEN 'C' THEN 'courier'
              ELSE CASE WHEN l_b THEN 'helveticaB' ELSE 'helvetica' END
            END);
  FOR i IN 1 .. NVL(LENGTH(p_txt), 0) LOOP
    l_c := SUBSTR(p_txt, i, 1);
    BEGIN
      l_w := l_w + l_cw(l_c);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN l_w := l_w + 556;
    END;
  END LOOP;
  RETURN l_w * p_corpo / 1000;
END ovl_largura;

FUNCTION ovl_gs_nome(p_opac IN NUMBER) RETURN VARCHAR2 IS
BEGIN
  RETURN 'GSwm' || LPAD(TO_CHAR(ROUND(LEAST(GREATEST(NVL(p_opac, 1), 0), 1)
                                      * 100)), 3, '0');
END ovl_gs_nome;

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

  l_tx := p_larg / 2 + l_dx * COS(l_r) - l_dy * SIN(l_r);
  l_ty := p_alt  / 2 + l_dx * SIN(l_r) + l_dy * COS(l_r);
  RETURN 'q /' || ovl_gs_nome(p_opac) || ' gs '
      || ovl_num(p_r) || ' ' || ovl_num(p_g) || ' ' || ovl_num(p_b) || ' rg'

      || CHR(10) || 'BT /' || ovl_fonte_nome('Helvetica', FALSE) || ' '
      || ovl_num(p_corpo) || ' Tf' || CHR(10)
      || ovl_matriz(p_rot, l_tx, l_ty) || ' Tm' || CHR(10)
      || '(' || ovl_escape(p_texto) || ') Tj' || CHR(10) || 'ET Q' || CHR(10);
END ovl_marca_dagua;

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
  co_entre CONSTANT NUMBER := 1.15;
  l_fonte  VARCHAR2(20) := ovl_fonte_nome(p_fonte, p_bold);
  l_align  VARCHAR2(10) := LOWER(NVL(p_align, 'left'));
  l_linhas tv32k;
  l_out    VARCHAR2(32767);
  l_dx     NUMBER;
  l_ly     NUMBER;
  l_lw     NUMBER;

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
    l_ly := -(i - 1) * p_corpo * co_entre;

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

FUNCTION ovl_recursos_texto(p_gs IN VARCHAR2, p_fontes IN VARCHAR2)
  RETURN VARCHAR2 IS
BEGIN
  RETURN '/Font << ' || p_fontes || ' >>'
      || ' /ExtGState << ' || p_gs || ' >>';
END ovl_recursos_texto;

FUNCTION ovl_fonte_entrada(p_fonte IN VARCHAR2, p_bold IN BOOLEAN)
  RETURN VARCHAR2 IS
BEGIN
  RETURN '/' || ovl_fonte_nome(p_fonte, p_bold)
      || ' << /Type /Font /Subtype /Type1 /BaseFont /'
      || ovl_fonte_base(p_fonte, p_bold)
      || ' /Encoding /WinAnsiEncoding >>';
END ovl_fonte_entrada;

FUNCTION ovl_gs_entrada(p_opac IN NUMBER) RETURN VARCHAR2 IS
  l_o VARCHAR2(20) := ovl_num(LEAST(GREATEST(NVL(p_opac, 1), 0), 1));
BEGIN
  RETURN '/' || ovl_gs_nome(p_opac) || ' << /Type /ExtGState'
      || ' /ca ' || l_o || ' /CA ' || l_o || ' >>';
END ovl_gs_entrada;

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
  l_pl    tpi;
  l_pa    tpi;
  l_bloco tblob;
  l_hexp  tv32k;
  l_passo PLS_INTEGER := p_canais * p_bits / 8;
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

  l_x0(1) := 0; l_y0(1) := 0; l_dx(1) := 8; l_dy(1) := 8;
  l_x0(2) := 4; l_y0(2) := 0; l_dx(2) := 8; l_dy(2) := 8;
  l_x0(3) := 0; l_y0(3) := 4; l_dx(3) := 4; l_dy(3) := 8;
  l_x0(4) := 2; l_y0(4) := 0; l_dx(4) := 4; l_dy(4) := 4;
  l_x0(5) := 0; l_y0(5) := 2; l_dx(5) := 2; l_dy(5) := 4;
  l_x0(6) := 1; l_y0(6) := 0; l_dx(6) := 2; l_dy(6) := 2;
  l_x0(7) := 0; l_y0(7) := 1; l_dx(7) := 1; l_dy(7) := 2;

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
    l_tmp := NULL;
    l_pos := l_pos + l_tam;
  END LOOP;

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

PROCEDURE ovl_png_separar_alfa(
  p_raster IN            BLOB,
  p_larg   IN            PLS_INTEGER,
  p_alt    IN            PLS_INTEGER,
  p_cores  IN            PLS_INTEGER,
  p_bits   IN            PLS_INTEGER,
  o_cor    IN OUT NOCOPY BLOB,
  o_alfa   IN OUT NOCOPY BLOB
) IS
  l_b     PLS_INTEGER := p_bits / 8;
  l_passo PLS_INTEGER := (p_cores + 1) * l_b;
  l_lote  PLS_INTEGER;
  l_pos   PLS_INTEGER := 1;
  l_n     PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_raster), 0);
  l_hex   VARCHAR2(32767);
  l_hc    VARCHAR2(32767);
  l_ha    VARCHAR2(32767);
  l_qtd   PLS_INTEGER;
BEGIN

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

PROCEDURE ovl_img_xobject(
  p_img     IN            BLOB,
  o_dic     OUT           VARCHAR2,
  o_dados   IN OUT NOCOPY BLOB,
  o_larg    OUT           NUMBER,
  o_alt     OUT           NUMBER,

  o_msk_dic OUT           VARCHAR2,
  o_msk_dat IN OUT NOCOPY BLOB
) IS
  l_n    PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_img), 0);

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

        IF l_marca IN (216, 1) OR l_marca BETWEEN 208 AND 215 THEN
          l_i := l_i + 2;
          CONTINUE;
        END IF;
        EXIT WHEN l_marca IN (217, 218);
        l_tam := u(l_i + 2, 2);

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
          IF l_tam > 16000 THEN
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

        l_i := l_i + 12 + l_tam;
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

      IF NOT l_alfa AND l_entre = 0 THEN
        o_dic := '<< /Type /XObject /Subtype /Image'
              || ' /Width ' || ovl_num(o_larg) || ' /Height ' || ovl_num(o_alt)
              || ' /ColorSpace ' || l_cs
              || ' /BitsPerComponent ' || l_bits
              || ' /Filter /FlateDecode'

              || ' /DecodeParms << /Predictor 15 /Colors ' || l_cores
              || ' /BitsPerComponent ' || l_bits
              || ' /Columns ' || ovl_num(o_larg) || ' >>'
              || ' /Length ' || l_idat || ' >>';
        RETURN;
      END IF;

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
  l_next_id  PLS_INTEGER := 3;
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

  l_extra    PLS_INTEGER;
  l_mid      PLS_INTEGER;
  l_idic     VARCHAR2(32767);
  l_sid      PLS_INTEGER;
  l_rid      PLS_INTEGER;
  l_pgraw    VARCHAR2(32767);
  l_ops      VARCHAR2(32767);
  l_resval   VARCHAR2(32767);
  l_resbody  VARCHAR2(32767);
  l_cont     VARCHAR2(32767);
  l_refs2    tpi;
  l_xobj     VARCHAR2(32767);
  l_img_id   tpi;
  l_img_n    PLS_INTEGER;
BEGIN
  DBMS_LOB.CREATETEMPORARY(l_out, TRUE);
  DBMS_LOB.CREATETEMPORARY(l_kids, TRUE);

  l_extra := 3;
  FOR s IN 1 .. p_srcs.COUNT LOOP
    l_extra := l_extra + NVL(p_srcs(s).xref.LAST, 0);
  END LOOP;

  pdf_app(l_out, '%PDF-1.7' || CHR(10));

  DBMS_LOB.WRITEAPPEND(l_out, 6, HEXTORAW('25E2E3CFD30A'));

  FOR s IN 1 .. p_srcs.COUNT LOOP
    l_shift   := l_next_id - 1;
    l_next_id := l_next_id + NVL(p_srcs(s).xref.LAST, 0);

    l_needed.DELETE;
    l_pageset.DELETE;
    l_queue.DELETE;
    l_qn := 0;

    FOR i IN 1 .. p_sel(s).COUNT LOOP
      l_oid := p_srcs(s).pages(p_sel(s)(i));
      l_pageset(l_oid) := TRUE;
      IF NOT l_needed.EXISTS(l_oid) THEN
        l_needed(l_oid) := TRUE;
        l_qn := l_qn + 1;
        l_queue(l_qn) := l_oid;
      END IF;
    END LOOP;

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

    l_oid := l_needed.FIRST;
    WHILE l_oid IS NOT NULL LOOP
      pdf_obj_extent(p_srcs(s), l_oid, l_start, l_end, l_dend, l_slen);
      l_refs.DELETE;
      l_sid := NULL;
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

        l_sid := NULL;
        IF p_srcs(s).ovl_ops.EXISTS(l_oid)
           AND p_srcs(s).ovl_ops(l_oid) IS NOT NULL THEN
          l_ops := p_srcs(s).ovl_ops(l_oid);
          l_sid := l_extra;     l_extra := l_extra + 1;
          l_rid := l_extra;     l_extra := l_extra + 1;

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

            l_resbody := REGEXP_REPLACE(l_resbody, 'endobj\s*$', '');
          END IF;

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

        DBMS_LOB.COPY(l_out, p_srcs(s).doc, l_end - l_dend,
                      DBMS_LOB.GETLENGTH(l_out) + 1, l_dend + 1);
      END IF;
      pdf_app(l_out, CHR(10));

      IF l_sid IS NOT NULL THEN
        l_offsets(l_sid) := DBMS_LOB.GETLENGTH(l_out);
        pdf_app(l_out, l_sid || ' 0 obj<< /Length ' || LENGTHB(l_ops)
                    || ' >>stream' || CHR(10) || l_ops || CHR(10)
                    || 'endstream endobj' || CHR(10));
        l_offsets(l_rid) := DBMS_LOB.GETLENGTH(l_out);
        pdf_app(l_out, l_rid || ' 0 obj' || l_resbody || 'endobj' || CHR(10));

        l_img_n := l_img_id.FIRST;
        WHILE l_img_n IS NOT NULL LOOP

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

  l_offsets(1) := DBMS_LOB.GETLENGTH(l_out);
  pdf_app(l_out, '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' || CHR(10));
  l_offsets(2) := DBMS_LOB.GETLENGTH(l_out);
  pdf_app(l_out, '2 0 obj<</Type/Pages/Count ' || l_kidcount || '/Kids[');
  pdf_app_clob(l_out, l_kids);
  pdf_app(l_out, ']>>endobj' || CHR(10));

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

FUNCTION blob_to_base64(p_blob IN BLOB) RETURN CLOB IS
  co_chunk CONSTANT PLS_INTEGER := 22500;
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

    l_txt := REPLACE(REPLACE(l_txt, CHR(13)), CHR(10));
    DBMS_LOB.WRITEAPPEND(l_out, LENGTH(l_txt), l_txt);
    l_pos := l_pos + l_amt;
  END LOOP;
  RETURN l_out;
END blob_to_base64;

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

    IF l_b64 IS NOT NULL THEN
      DBMS_LOB.FREETEMPORARY(l_b64);
    END IF;
  END LOOP;

  RETURN l_result;
END SplitPDF;

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

  l_input := UTL_RAW.CONCAT(
    p_enc_key,
    UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(p_obj_num, UTL_RAW.LITTLE_ENDIAN), 1, 3),
    UTL_RAW.SUBSTR(UTL_RAW.CAST_FROM_BINARY_INTEGER(p_gen_num, UTL_RAW.LITTLE_ENDIAN), 1, 2)
  );

  l_hash := PL_FPDF_UTIL.crypto_md5(l_input);

  l_key_len := LEAST((p_key_length / 8) + 5, 16);

  RETURN UTL_RAW.SUBSTR(l_hash, 1, l_key_len);
END compute_object_key;

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

  l_pwd_to_use := NVL(p_owner_pwd, p_user_pwd);

  l_padded := pdf_pad_password(l_pwd_to_use);

  l_hash := PL_FPDF_UTIL.crypto_md5(l_padded);

  IF p_key_length > 40 THEN
    FOR i IN 1..50 LOOP
      l_hash := PL_FPDF_UTIL.crypto_md5(l_hash);
    END LOOP;
  END IF;

  l_key_len := p_key_length / 8;
  RETURN UTL_RAW.SUBSTR(l_hash, 1, l_key_len);
END compute_owner_key;

FUNCTION compute_owner_value(
  p_owner_pwd VARCHAR2,
  p_user_pwd VARCHAR2,
  p_key_length PLS_INTEGER
) RETURN RAW IS
  l_key RAW(16);
  l_user_padded RAW(32);
  l_result RAW(32);
BEGIN

  l_key := compute_owner_key(p_owner_pwd, p_user_pwd, p_key_length);

  l_user_padded := pdf_pad_password(p_user_pwd);

  l_result := PL_FPDF_UTIL.crypto_rc4(l_user_padded, l_key);

  IF p_key_length > 40 THEN
    FOR i IN 1 .. 19 LOOP
      l_result := PL_FPDF_UTIL.crypto_rc4(l_result, rc4_key_xor(l_key, i));
    END LOOP;
  END IF;

  RETURN l_result;
END compute_owner_value;

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

  l_perm_bytes := UTL_RAW.CAST_FROM_BINARY_INTEGER(p_permissions, UTL_RAW.LITTLE_ENDIAN);

  l_input := UTL_RAW.CONCAT(l_user_padded, p_o_value);
  l_input := UTL_RAW.CONCAT(l_input, l_perm_bytes);
  l_input := UTL_RAW.CONCAT(l_input, p_file_id);

  l_hash := PL_FPDF_UTIL.crypto_md5(l_input);

  IF p_key_length > 40 THEN
    l_key_len := p_key_length / 8;
    FOR i IN 1..50 LOOP
      l_hash := PL_FPDF_UTIL.crypto_md5(UTL_RAW.SUBSTR(l_hash, 1, l_key_len));
    END LOOP;
  END IF;

  l_key_len := p_key_length / 8;
  RETURN UTL_RAW.SUBSTR(l_hash, 1, l_key_len);
END compute_encryption_key_raw;

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

FUNCTION compute_user_value(
  p_encryption_key RAW,
  p_file_id RAW,
  p_key_length PLS_INTEGER
) RETURN RAW IS
  l_result RAW(32);
  l_hash RAW(16);
BEGIN
  IF p_key_length <= 40 THEN

    l_result := PL_FPDF_UTIL.crypto_rc4(c_PDF_PADDING, p_encryption_key);
  ELSE

    l_hash := PL_FPDF_UTIL.crypto_md5(UTL_RAW.CONCAT(c_PDF_PADDING, p_file_id));

    l_result := PL_FPDF_UTIL.crypto_rc4(l_hash, p_encryption_key);

    FOR i IN 1 .. 19 LOOP
      l_result := PL_FPDF_UTIL.crypto_rc4(l_result, rc4_key_xor(p_encryption_key, i));
    END LOOP;

    l_result := UTL_RAW.CONCAT(l_result, HEXTORAW('00000000000000000000000000000000'));
    l_result := UTL_RAW.SUBSTR(l_result, 1, 32);
  END IF;

  RETURN l_result;
END compute_user_value;

FUNCTION generate_file_id RETURN RAW IS
BEGIN
  RETURN PL_FPDF_UTIL.crypto_md5(
    UTL_RAW.CAST_TO_RAW(
      TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF9') || SYS_GUID()
    )
  );
END generate_file_id;

FUNCTION sec_cifrar_strings(
  p_dic      IN VARCHAR2,
  p_ok       IN RAW,
  p_aes      IN BOOLEAN DEFAULT FALSE,
  p_decifrar IN BOOLEAN DEFAULT FALSE
) RETURN VARCHAR2 IS
  co_abre  CONSTANT PLS_INTEGER := 40;
  co_fecha CONSTANT PLS_INTEGER := 41;
  co_barra CONSTANT PLS_INTEGER := 92;

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

  FUNCTION b_em(p IN PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN
    RETURN TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(l_raw, p, 1)), 'XX');
  END b_em;

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

      l_j := l_i;
      WHILE l_j <= l_n AND b_em(l_j) != co_abre LOOP
        l_j := l_j + 1;
      END LOOP;
      juntar(UTL_RAW.SUBSTR(l_raw, l_i, l_j - l_i));
      l_i := l_j;
      CONTINUE;
    END IF;

    l_ini  := l_i + 1;
    l_prof := 1;
    l_j    := l_ini;
    WHILE l_j <= l_n AND l_prof > 0 LOOP
      l_b := b_em(l_j);
      IF l_b = co_barra THEN
        l_j := l_j + 1;
      ELSIF l_b = co_abre THEN
        l_prof := l_prof + 1;
      ELSIF l_b = co_fecha THEN
        l_prof := l_prof - 1;
        EXIT WHEN l_prof = 0;
      END IF;
      l_j := l_j + 1;
    END LOOP;

    IF l_prof > 0 THEN
      juntar(UTL_RAW.SUBSTR(l_raw, l_i, 1));
      l_i := l_i + 1;
      CONTINUE;
    END IF;

    l_hex := NULL;
    DECLARE
      l_k PLS_INTEGER := l_ini;
    BEGIN

      WHILE l_k < l_j AND l_k <= l_n LOOP
        l_b := b_em(l_k);
        IF l_b = co_barra AND l_k + 1 < l_j THEN
          l_b := b_em(l_k + 1);
          l_hex := l_hex || CASE l_b
                              WHEN 110 THEN '0A'
                              WHEN 114 THEN '0D'
                              WHEN 116 THEN '09'
                              ELSE LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0') END;
          l_k := l_k + 2;
        ELSE
          l_hex := l_hex || LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0');
          l_k := l_k + 1;
        END IF;

        IF LENGTH(l_hex) > 32000 THEN
          RAISE_APPLICATION_ERROR(-20866,
            'String literal com mais de 16000 bytes nao cabe no escape.');
        END IF;
      END LOOP;
    END;
    l_texto := CASE WHEN l_hex IS NOT NULL THEN HEXTORAW(l_hex) END;

    l_hex := NULL;
    IF l_texto IS NOT NULL THEN

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
                   WHEN l_b = 13 THEN '5C72'
                   WHEN l_b = 10 THEN '5C6E'
                   ELSE LPAD(TO_CHAR(l_b, 'FMXX'), 2, '0') END;
      END LOOP;
    END IF;

    juntar(HEXTORAW('28'));
    IF l_hex IS NOT NULL THEN
      juntar(HEXTORAW(l_hex));
    END IF;
    juntar(HEXTORAW('29'));
    l_i := l_j + 1;
  END LOOP;

  RETURN CASE WHEN l_out IS NOT NULL
              THEN UTL_RAW.CAST_TO_VARCHAR2(l_out) END;
END sec_cifrar_strings;

FUNCTION sec_e_estrutura(p_src IN pdf_source_rec, p_oid IN PLS_INTEGER)
  RETURN BOOLEAN IS
BEGIN

  RETURN NVL(pdf_dict_value(pdf_obj_body(p_src, p_oid), '/Type'), 'x')
         IN ('/ObjStm', '/XRef');
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END sec_e_estrutura;

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

  l_src := pdf_src_load(p_pdf,
             p_chave => CASE WHEN p_decifrar THEN p_key END,
             p_aes   => p_aes,
             p_r6    => p_r6);
  o_max := 0;
  o_root := l_src.root;
  o_info := l_src.info;

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

  FOR i IN 1 .. l_ordem.COUNT - 1 LOOP
    FOR j IN 1 .. l_ordem.COUNT - i LOOP
      IF NVL(l_src.xref(l_ordem(j)).offset, 2147483647)
         > NVL(l_src.xref(l_ordem(j + 1)).offset, 2147483647) THEN
        l_tmp := l_ordem(j); l_ordem(j) := l_ordem(j + 1); l_ordem(j + 1) := l_tmp;
      END IF;
    END LOOP;
  END LOOP;

  pdf_app(o_pdf, CASE WHEN p_decifrar THEN '%PDF-1.4'
                      WHEN p_r6       THEN '%PDF-1.7'
                      WHEN p_aes      THEN '%PDF-1.6'
                      ELSE '%PDF-1.4' END || CHR(10));

  FOR i IN 1 .. l_ordem.COUNT LOOP
    l_oid := l_ordem(i);
    o_offsets(l_oid) := DBMS_LOB.GETLENGTH(o_pdf);

    IF l_src.objstm.EXISTS(l_oid) THEN
      l_ok := CASE WHEN p_r6 THEN p_key
                   WHEN p_aes THEN PL_FPDF_UTIL.aes_chave_objeto(p_key, l_oid, 0)
                   ELSE compute_object_key(p_key, l_oid, 0, p_key_bits) END;
      l_dic := l_src.objstm(l_oid);

      IF NOT p_decifrar THEN
        l_dic := sec_cifrar_strings(l_dic, l_ok, p_aes, FALSE);
      END IF;

      pdf_app(o_pdf, l_oid || ' 0 obj');
      pdf_app(o_pdf, l_dic);
      pdf_app(o_pdf, CHR(10));
      CONTINUE;
    END IF;

    pdf_obj_extent(l_src, l_oid, l_start, l_end, l_dend, l_slen);

    l_ok := CASE WHEN p_r6 THEN p_key
                 WHEN p_aes THEN PL_FPDF_UTIL.aes_chave_objeto(p_key, l_oid, 0)
                 ELSE compute_object_key(p_key, l_oid, 0, p_key_bits) END;

    IF l_dend - l_start > 32767 THEN
      RAISE_APPLICATION_ERROR(-20841,
        'Objeto ' || l_oid || ' tem dicionario de ' || (l_dend - l_start) ||
        ' bytes; o limite de leitura e 32767. Cifrar/decifrar este PDF ' ||
        'truncaria o objeto em silencio.');
    END IF;
    l_dic := pdf_read(l_src.doc, l_start, l_dend - l_start);

    IF l_slen > 0 AND p_aes THEN

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
  l_o_value RAW(48);
  l_u_value RAW(48);
  l_enc_key RAW(32);
  l_oe_value RAW(32);
  l_ue_value RAW(32);
  l_perms_c RAW(16);
  l_aes     BOOLEAN;
  l_r6      BOOLEAN;
  l_v_value PLS_INTEGER;
  l_r_value PLS_INTEGER;
  l_offsets tpi;
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

  IF p_encryption NOT IN ('RC4-40', 'RC4-128', 'AES-128', 'AES-256') THEN
    RAISE_APPLICATION_ERROR(-20850, 'Invalid encryption method: ' || p_encryption ||
      '. Valid: RC4-40, RC4-128, AES-128, AES-256');
  END IF;

  IF p_user_password IS NULL THEN
    RAISE_APPLICATION_ERROR(-20851, 'User password is required');
  END IF;

  PL_FPDF_UTIL.crypto_autoteste;

  IF IsEncrypted(p_pdf) THEN
    RAISE_APPLICATION_ERROR(-20859, 'PDF is already encrypted. Decrypt first.');
  END IF;

  CASE p_encryption
    WHEN 'RC4-40' THEN l_key_length := 40; l_v_value := 1; l_r_value := 2;
    WHEN 'RC4-128' THEN l_key_length := 128; l_v_value := 2; l_r_value := 3;

    WHEN 'AES-128' THEN l_key_length := 128; l_v_value := 4; l_r_value := 4;
    WHEN 'AES-256' THEN l_key_length := 256; l_v_value := 5; l_r_value := 6;
  END CASE;

  l_aes := p_encryption IN ('AES-128', 'AES-256');
  l_r6  := p_encryption = 'AES-256';
  IF l_aes THEN
    PL_FPDF_UTIL.aes_autoteste;
  END IF;

  l_owner_pwd := NVL(p_owner_password, p_user_password);

  l_permissions := -4;

  IF p_permissions IS NOT NULL THEN
    l_permissions := -3904;
    IF NVL(p_permissions.get_boolean('print'), FALSE) THEN l_permissions := l_permissions + 4; END IF;
    IF NVL(p_permissions.get_boolean('modify'), FALSE) THEN l_permissions := l_permissions + 8; END IF;
    IF NVL(p_permissions.get_boolean('copy'), FALSE) THEN l_permissions := l_permissions + 16; END IF;
    IF NVL(p_permissions.get_boolean('annotate'), FALSE) THEN l_permissions := l_permissions + 32; END IF;
    IF NVL(p_permissions.get_boolean('fillForms'), FALSE) THEN l_permissions := l_permissions + 256; END IF;
    IF NVL(p_permissions.get_boolean('extract'), FALSE) THEN l_permissions := l_permissions + 512; END IF;
    IF NVL(p_permissions.get_boolean('assemble'), FALSE) THEN l_permissions := l_permissions + 1024; END IF;
    IF NVL(p_permissions.get_boolean('printHighQuality'), FALSE) THEN l_permissions := l_permissions + 2048; END IF;
  END IF;

  l_file_id := generate_file_id();

  IF l_r6 THEN

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

    l_o_value := compute_owner_value(l_owner_pwd, p_user_password, l_key_length);

    l_enc_key := compute_encryption_key(p_user_password, l_o_value, l_permissions, l_file_id, l_key_length);

    l_u_value := compute_user_value(l_enc_key, l_file_id, l_key_length);
  END IF;

  DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
  sec_cifrar_objetos(p_pdf, l_enc_key, l_key_length,
                     l_result, l_offsets, l_new_obj_num, l_root_num, l_info_num,
                     p_aes => l_aes, p_r6 => l_r6);

  l_new_obj_num := l_new_obj_num + 1;
  l_offsets(l_new_obj_num) := DBMS_LOB.GETLENGTH(l_result);
  pdf_app(l_result,
    l_new_obj_num || ' 0 obj' || CHR(10)
    || '<< /Filter /Standard'
    || ' /V ' || l_v_value
    || ' /R ' || l_r_value
    || ' /Length ' || l_key_length
    || ' /P ' || l_permissions

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

  IF l_root_num IS NULL THEN
    RAISE_APPLICATION_ERROR(-20860,
      'PDF invalido: /Root nao encontrado no trailer');
  END IF;
  l_root_ref := l_root_num || ' 0 R';
  l_info_ref := CASE WHEN l_info_num IS NOT NULL
                     THEN l_info_num || ' 0 R' END;
  l_pdf_content := NULL;

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

      RAISE_APPLICATION_ERROR(-20852, 'Encryption failed: ' || SQLERRM ||
        ' [em: ' || REPLACE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, CHR(10), ' ')
        || ']');
    END IF;
END EncryptPDF;

FUNCTION verify_password(
  p_password IN VARCHAR2,
  p_o_value IN RAW,
  p_u_value IN RAW,
  p_permissions IN PLS_INTEGER,
  p_file_id IN RAW,
  p_key_length IN PLS_INTEGER,
  p_is_owner OUT BOOLEAN,

  p_enc_key OUT RAW
) RETURN BOOLEAN IS
  l_enc_key RAW(16);
  l_computed_u RAW(32);
  l_owner_key RAW(16);
  l_decrypted RAW(32);
BEGIN
  p_is_owner := FALSE;
  p_enc_key  := NULL;

  IF p_u_value IS NULL THEN
    RETURN FALSE;
  END IF;

  l_enc_key := compute_encryption_key(p_password, p_o_value, p_permissions, p_file_id, p_key_length);
  l_computed_u := compute_user_value(l_enc_key, p_file_id, p_key_length);

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

FUNCTION DecryptPDF(
  p_pdf IN BLOB,
  p_password IN VARCHAR2
) RETURN BLOB IS
  l_result BLOB;
  l_content VARCHAR2(32767);
  l_pdf_size PLS_INTEGER;
  l_key_length PLS_INTEGER;
  l_permissions PLS_INTEGER;
  l_o_value RAW(48);
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
  l_tail VARCHAR2(4000);
  l_enc_key RAW(32);
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

  PL_FPDF_UTIL.crypto_autoteste;

  l_pdf_size := DBMS_LOB.GETLENGTH(p_pdf);

  l_content := sec_encrypt_dict(p_pdf);
  IF l_content IS NULL THEN
    RAISE_APPLICATION_ERROR(-20861,
      'Dicionario /Encrypt nao encontrado no PDF');
  END IF;
  l_tail := UTL_RAW.CAST_TO_VARCHAR2(
    DBMS_LOB.SUBSTR(p_pdf, LEAST(l_pdf_size, 4000),
                    GREATEST(1, l_pdf_size - 3999)));

  BEGIN

    l_key_length := NVL(TO_NUMBER(REGEXP_SUBSTR(l_content, '/Length\s+(\d+)', 1, 1, NULL, 1)), 40);
    l_permissions := TO_NUMBER(REGEXP_SUBSTR(l_content, '/P\s+(-?\d+)', 1, 1, NULL, 1));

    DECLARE
      l_o_hex VARCHAR2(100);
    BEGIN
      l_o_hex := REGEXP_SUBSTR(l_content, '/O\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_o_hex IS NOT NULL THEN
        l_o_value := HEXTORAW(l_o_hex);
      END IF;
    END;

    DECLARE
      l_u_hex VARCHAR2(100);
    BEGIN
      l_u_hex := REGEXP_SUBSTR(l_content, '/U\s*<([0-9A-Fa-f]+)>', 1, 1, NULL, 1);
      IF l_u_hex IS NOT NULL THEN
        l_u_value := HEXTORAW(l_u_hex);
      END IF;
    END;

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

  l_cfm := REGEXP_SUBSTR(l_content, '/CFM\s*/(\w+)', 1, 1, NULL, 1);
  l_aes := l_cfm IN ('AESV2', 'AESV3');
  l_r6  := l_cfm = 'AESV3';
  IF l_aes THEN
    PL_FPDF_UTIL.aes_autoteste;
  END IF;

  IF l_r6 THEN

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

    IF NVL(verify_password(p_password, l_o_value, l_u_value, l_permissions,
                           l_file_id, l_key_length, l_is_owner, l_enc_key),
           FALSE) = FALSE THEN
      RAISE_APPLICATION_ERROR(-20854, 'Invalid password');
    END IF;
  END IF;

  l_enc_obj := TO_NUMBER(REGEXP_SUBSTR(l_content, '^\s*(\d+)\s+\d+\s+obj',
                                       1, 1, NULL, 1));

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

  RETURN DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW('/Encrypt'),
                        GREATEST(1, l_len - 4000), 1) > 0
      OR DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW('/Encrypt'), 1, 1) > 0;
END IsEncrypted;

FUNCTION parse_permissions(p_perm_value PLS_INTEGER) RETURN JSON_OBJECT_T IS
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();

  l_perm NUMBER;
BEGIN

  IF p_perm_value < 0 THEN
    l_perm := p_perm_value + 4294967296;
  ELSE
    l_perm := p_perm_value;
  END IF;

  l_perms.put('print', BITAND(l_perm, 4) = 4);

  l_perms.put('modify', BITAND(l_perm, 8) = 8);

  l_perms.put('copy', BITAND(l_perm, 16) = 16);

  l_perms.put('annotate', BITAND(l_perm, 32) = 32);

  l_perms.put('fillForms', BITAND(l_perm, 256) = 256);

  l_perms.put('extract', BITAND(l_perm, 512) = 512);

  l_perms.put('assemble', BITAND(l_perm, 1024) = 1024);

  l_perms.put('printHighQuality', BITAND(l_perm, 2048) = 2048);

  RETURN l_perms;
END parse_permissions;

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

  l_content := sec_encrypt_dict(p_pdf);
  IF l_content IS NULL THEN
    l_content := UTL_RAW.CAST_TO_VARCHAR2(
      DBMS_LOB.SUBSTR(p_pdf, LEAST(DBMS_LOB.GETLENGTH(p_pdf), 32767), 1));
  END IF;

  l_result.put('encrypted', TRUE);

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

  BEGIN
    l_r_value := TO_NUMBER(REGEXP_SUBSTR(l_content, '/R\s+(\d+)', 1, 1, NULL, 1));
    l_result.put('revision', l_r_value);
  EXCEPTION WHEN OTHERS THEN
    l_result.put('revision', 0);
  END;

  BEGIN

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

  BEGIN
    l_perm_value := TO_NUMBER(REGEXP_SUBSTR(l_content, '/P\s+(-?\d+)', 1, 1, NULL, 1));
    l_result.put('permissionValue', l_perm_value);
    l_perms := parse_permissions(l_perm_value);
    l_result.put('permissions', l_perms);
  EXCEPTION WHEN OTHERS THEN

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

  l_result.put('hasUserPassword', INSTR(l_content, '/U ') > 0 OR INSTR(l_content, '/U<') > 0);
  l_result.put('hasOwnerPassword', INSTR(l_content, '/O ') > 0 OR INSTR(l_content, '/O<') > 0);

  RETURN l_result;
END GetSecurityInfo;

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

  CASE p_encryption
    WHEN 'RC4-40' THEN PDFVersion := '1.4';
    WHEN 'RC4-128' THEN PDFVersion := '1.4';
    WHEN 'AES-128' THEN PDFVersion := '1.5';
    WHEN 'AES-256' THEN PDFVersion := '1.7';
  END CASE;

  log_message(3, 'Encryption set: ' || p_encryption || ', PDF version: ' || PDFVersion);
END SetEncryption;

PROCEDURE SetPDFVersion(p_version IN VARCHAR2) IS
BEGIN
  IF p_version NOT IN ('1.4', '1.5', '1.6', '1.7', '2.0') THEN
    RAISE_APPLICATION_ERROR(-20857, 'Invalid PDF version: ' || p_version ||
      '. Valid versions: 1.4, 1.5, 1.6, 1.7, 2.0');
  END IF;

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

FUNCTION GetPDFVersion RETURN VARCHAR2 IS
BEGIN
  RETURN NVL(PDFVersion, '1.4');
END GetPDFVersion;

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
