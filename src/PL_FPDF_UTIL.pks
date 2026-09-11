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
