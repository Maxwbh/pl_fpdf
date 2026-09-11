CREATE OR REPLACE PACKAGE PL_FPDF_UTIL AS
co_version CONSTANT VARCHAR2(10) := '3.4.0';
TYPE tqr IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

PROCEDURE qr_matriz(p_dados   IN  VARCHAR2,
                    p_ec      IN  VARCHAR2 DEFAULT 'M',
                    o_mat     OUT NOCOPY tqr,
                    o_lado    OUT PLS_INTEGER,
                    o_versao  OUT PLS_INTEGER,
                    o_mascara OUT PLS_INTEGER);

FUNCTION bc_padrao(p_codigo IN VARCHAR2,
                   p_tipo   IN VARCHAR2 DEFAULT 'CODE128',
                   p_ratio  IN NUMBER   DEFAULT 3) RETURN VARCHAR2;

PROCEDURE inflate(p_src IN            BLOB,
                  o_dst IN OUT NOCOPY BLOB,
                  p_max IN            PLS_INTEGER DEFAULT 8388608);

PROCEDURE deflate(p_src IN BLOB, o_dst IN OUT NOCOPY BLOB);

FUNCTION hex_do_byte(p_b IN PLS_INTEGER) RETURN VARCHAR2;

FUNCTION  crypto_md5(p_src IN RAW) RETURN RAW;

FUNCTION  crypto_rc4(p_src IN RAW, p_key IN RAW) RETURN RAW;

PROCEDURE crypto_rc4_blob(p_src IN BLOB, p_key IN RAW,
                          o_dst IN OUT NOCOPY BLOB);

PROCEDURE crypto_autoteste;

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

PROCEDURE aes_autoteste;
END PL_FPDF_UTIL;
/
