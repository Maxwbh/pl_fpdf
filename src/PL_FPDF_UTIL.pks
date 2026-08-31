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
