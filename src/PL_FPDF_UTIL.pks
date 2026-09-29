CREATE OR REPLACE PACKAGE PL_FPDF_UTIL AS
co_version CONSTANT VARCHAR2(10) := '3.4.0';
TYPE tqr IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

/**
 * Codifica o conteúdo e devolve a matriz de módulos com a máscara de menor
 * penalidade já aplicada. Não desenha nada: quem desenha é o AddQRCode do
 * PL_FPDF. O critério da referência não é "produz um símbolo", é "um leitor
 * decodifica".
 *
 * @param p_dados o conteúdo a codificar
 * @param p_ec quanto do símbolo pode ser perdido e ainda assim ler:
 *        'L' (Low, 7%), 'M' (Medium, 15%), 'Q' (Quartile, 25%) ou
 *        'H' (High, 30%)
 * @param o_mat a matriz
 * @param o_lado o lado em módulos
 * @param o_versao a versão do símbolo (1..20)
 * @param o_mascara a máscara escolhida (0..7)
 * @raises -20870 conteúdo vazio
 * @raises -20872 nível de correção inválido
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
 * Devolve o padrão de barras como texto de '0' e '1', um caractere por módulo.
 * Não desenha: quem desenha é o AddBarcode do PL_FPDF.
 *
 * @param p_codigo o conteúdo a codificar
 * @param p_tipo simbologia: 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF',
 *        'ITF14'
 * @param p_ratio razão entre barra larga e estreita, onde a simbologia usa
 * @return VARCHAR2 - o padrão de módulos
 * @raises -20880 código vazio
 * @raises -20882 simbologia não suportada
 * @example
 *   l_padrao := PL_FPDF_UTIL.bc_padrao('ABC123456', 'CODE128');
 */
FUNCTION bc_padrao(p_codigo IN VARCHAR2,
                   p_tipo   IN VARCHAR2 DEFAULT 'CODE128',
                   p_ratio  IN NUMBER   DEFAULT 3) RETURN VARCHAR2;

/**
 * Descomprime um fluxo zlib. O teto existe porque stream de terceiro é entrada
 * NÃO CONFIÁVEL: alguns KB podem virar gigabytes (zip bomb) e derrubar a
 * sessão.
 *
 * @param p_src o fluxo comprimido
 * @param o_dst o conteúdo descomprimido
 * @param p_max teto da saída, em bytes
 * @raises -20890 fluxo truncado
 * @raises -20891 dados DEFLATE malformados
 * @raises -20892 cabeçalho zlib inválido
 * @raises -20893 a saída passou do teto
 * @raises -20894 tabela interna inconsistente
 * @example
 *   PL_FPDF_UTIL.inflate(l_comprimido, l_claro);
 */
PROCEDURE inflate(p_src IN            BLOB,
                  o_dst IN OUT NOCOPY BLOB,
                  p_max IN            PLS_INTEGER DEFAULT 8388608);

/**
 * Comprime num fluxo zlib: um bloco com Huffman FIXA e LZ77 guloso, com escape
 * para bloco armazenado quando não compensa — a saída nunca fica maior que a
 * entrada mais o custo do bloco.
 *
 * @param p_src o conteúdo a comprimir
 * @param o_dst o fluxo zlib
 * @example
 *   PL_FPDF_UTIL.deflate(l_claro, l_comprimido);
 */
PROCEDURE deflate(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB);

/**
 * Os dois dígitos hexadecimais de um byte. Existe para remontar RAW sem passar
 * por CHR(n), que não devolve um byte e sim o caractere daquele ponto de
 * código — em AL32UTF8, todo valor de 128 a 255 sai com DOIS bytes.
 *
 * @param p_b o byte (0..255)
 * @return VARCHAR2 - os dois dígitos
 * @example
 *   l_hex := PL_FPDF_UTIL.hex_do_byte(231);      -- 'E7'
 */
FUNCTION hex_do_byte(p_b IN PLS_INTEGER) RETURN VARCHAR2;

/**
 * MD5 de um RAW. O PDF exige MD5 no algoritmo de chave até o revisionamento 4;
 * não serve para nada que dependa de resistência a colisão.
 *
 * @param p_src a entrada
 * @return RAW - os 16 bytes do resumo
 * @example
 *   l_md5 := PL_FPDF_UTIL.crypto_md5(UTL_RAW.CAST_TO_RAW('abc'));
 */
FUNCTION  crypto_md5(p_src IN RAW) RETURN RAW;

/**
 * Cifra ou decifra um RAW com RC4 — a mesma operação nos dois sentidos, por
 * ser cifra de fluxo. É o que o PDF usa nos revisionamentos 2 e 3.
 *
 * @param p_src os dados
 * @param p_key a chave
 * @return RAW - o resultado
 * @example
 *   l_cifrado := PL_FPDF_UTIL.crypto_rc4(l_claro, l_chave);
 */
FUNCTION  crypto_rc4(p_src IN RAW, p_key IN RAW) RETURN RAW;

/**
 * O mesmo que crypto_rc4, para conteúdo que não cabe num RAW.
 *
 * @param p_src os dados
 * @param p_key a chave
 * @param o_dst o resultado
 * @example
 *   PL_FPDF_UTIL.crypto_rc4_blob(l_claro, l_chave, l_cifrado);
 */
PROCEDURE crypto_rc4_blob(p_src IN BLOB, p_key IN RAW,
                          o_dst IN OUT NOCOPY BLOB);

/**
 * Confere MD5 e RC4 contra vetores públicos e levanta se divergir. Vale rodar
 * depois de instalar: uma tabela transcrita errada compila e só aparece no
 * arquivo que o leitor recusa.
 *
 * @example
 *   PL_FPDF_UTIL.crypto_autoteste;
 */
PROCEDURE crypto_autoteste;

/**
 * Cifra um BLOB em AES-CBC com preenchimento PKCS#5, como o PDF pede. O
 * tamanho da chave decide entre AES-128 e AES-256.
 *
 * @param p_chave a chave (16 ou 32 bytes)
 * @param p_dados o conteúdo
 * @param o_saida o resultado, com o IV na frente
 * @param p_iv o IV; em branco, um aleatório; empty means random
 * @example
 *   PL_FPDF_UTIL.aes_cbc_cifrar(l_chave, l_claro, l_cifrado);
 */
PROCEDURE aes_cbc_cifrar(p_chave IN            RAW,
                         p_dados IN            BLOB,
                         o_saida IN OUT NOCOPY BLOB,
                         p_iv    IN            RAW DEFAULT NULL);

/**
 * O mesmo que aes_cbc_cifrar, para conteúdo que cabe num RAW.
 *
 * @param p_chave a chave
 * @param p_dados o conteúdo
 * @return RAW - o resultado, com o IV na frente
 * @example
 *   l_cifrado := PL_FPDF_UTIL.aes_cbc_cifrar_raw(l_chave, l_claro);
 */
FUNCTION  aes_cbc_cifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW;

/**
 * Decifra um BLOB cifrado em AES-CBC, tomando os primeiros 16 bytes como IV e
 * removendo o preenchimento.
 *
 * @param p_chave a chave
 * @param p_dados o conteúdo cifrado
 * @param o_saida o conteúdo claro
 * @example
 *   PL_FPDF_UTIL.aes_cbc_decifrar(l_chave, l_cifrado, l_claro);
 */
PROCEDURE aes_cbc_decifrar(p_chave IN            RAW,
                           p_dados IN            BLOB,
                           o_saida IN OUT NOCOPY BLOB);

/**
 * O mesmo que aes_cbc_decifrar, para conteúdo que cabe num RAW.
 *
 * @param p_chave a chave
 * @param p_dados o conteúdo cifrado
 * @return RAW - o conteúdo claro
 * @example
 *   l_claro := PL_FPDF_UTIL.aes_cbc_decifrar_raw(l_chave, l_cifrado);
 */
FUNCTION  aes_cbc_decifrar_raw(p_chave IN RAW, p_dados IN RAW) RETURN RAW;

/**
 * Deriva a chave de um objeto a partir da chave do documento e da numeração
 * dele, como manda o algoritmo 1 do PDF. Cada objeto é cifrado com uma chave
 * própria: é isso que impede trocar um objeto de lugar.
 *
 * @param p_chave a chave do documento
 * @param p_obj_num o número do objeto
 * @param p_gen_num o número de geração
 * @return RAW - a chave do objeto
 * @example
 *   l_chave_obj := PL_FPDF_UTIL.aes_chave_objeto(l_chave, 12);
 */
FUNCTION  aes_chave_objeto(p_chave   IN RAW,
                           p_obj_num IN PLS_INTEGER,
                           p_gen_num IN PLS_INTEGER DEFAULT 0) RETURN RAW;

/**
 * Devolve 16 bytes aleatórios para servir de IV.
 *
 * @return RAW - os 16 bytes
 * @example
 *   l_iv := PL_FPDF_UTIL.aes_iv;
 */
FUNCTION  aes_iv RETURN RAW;

/**
 * Monta as entradas /U, /UE, /O, /OE e /Perms do dicionário de criptografia do
 * revisionamento 6 (AES-256, PDF 2.0), que é onde a senha passa por SHA-256
 * endurecido em vez de MD5.
 *
 * @param p_senha_usr senha de usuário
 * @param p_senha_dono senha de dono
 * @param p_chave a chave do documento
 * @param p_perms as permissões, como número
 * @param o_u entradas /U e /UE
 * @param o_ue entradas /U e /UE
 * @param o_o entradas /O e /OE
 * @param o_oe entradas /O e /OE
 * @param o_perms a entrada /Perms
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
 * Confere a senha contra as entradas do dicionário e, acertando, devolve a
 * chave do documento e diz se era a senha de dono.
 *
 * @param p_senha a senha a conferir
 * @param p_u as entradas do dicionário
 * @param p_ue as entradas do dicionário
 * @param p_o as entradas do dicionário
 * @param p_oe as entradas do dicionário
 * @param o_chave a chave do documento, quando confere
 * @param o_dono TRUE se era a senha de dono
 * @return BOOLEAN - TRUE se a senha confere
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
 * Confere o AES contra os vetores do FIPS-197 e levanta se divergir.
 *
 * @example
 *   PL_FPDF_UTIL.aes_autoteste;
 */
PROCEDURE aes_autoteste;
END PL_FPDF_UTIL;
/
