# -*- coding: utf-8 -*-
"""
Referência da criptografia AES do PDF, a ser portada para PL_FPDF.EncryptPDF.

O que falta no package hoje
--------------------------
`EncryptPDF` aceita `'AES-128'` e `'AES-256'` na validação de parâmetros e
recusa na hora de usar, com `ORA-20852`. O RC4 já funciona de verdade
(`scripts/pdfcrypt_reference/`), mas está quebrado há anos e o **PDF 2.0 o
removeu da especificação** — leitores novos avisam ou recusam.

Duas revisões, e elas são bem diferentes
----------------------------------------
* **AES-128 (V4 / R4, "AESV2")** — a chave do documento sai dos mesmos
  algoritmos 2, 3 e 5 do RC4 (MD5, `/O`, `/U`), e o que muda é a cifra: a chave
  por objeto ganha os quatro bytes ``sAlT`` no fim do MD5, e cada stream é
  AES-128-CBC com o IV nos 16 primeiros bytes do próprio dado.

* **AES-256 (V5 / R6, "AESV3")** — outro esquema. Não há chave derivada por
  objeto: a chave do arquivo é usada direto. `/U` e `/O` passam a ter 48 bytes
  (hash de 32 + validation salt de 8 + key salt de 8), a chave fica embrulhada
  em `/UE`/`/OE`, e `/Perms` carrega as permissões cifradas para não poderem
  ser adulteradas fora do arquivo. O hash do R6 é o algoritmo 2.B, um laço de
  SHA-256/384/512 com AES-CBC no meio — feio, mas mecânico.

O AES em si vai escrito à mão (S-box, expansão de chave, rodadas), porque é
isso que precisa ser portado: no PL/SQL não há DBMS_CRYPTO — foi eliminado de
propósito nesta base, e o STANDARD_HASH cobre só os hashes.
"""
import hashlib
import os
import struct

# ─────────────────────────────────── AES ─────────────────────────────────────
SBOX = bytes.fromhex(
    '637c777bf26b6fc53001672bfed7ab76'
    'ca82c97dfa5947f0add4a2af9ca472c0'
    'b7fd9326363ff7cc34a5e5f171d83115'
    '04c723c31896059a071280e2eb27b275'
    '09832c1a1b6e5aa0523bd6b329e32f84'
    '53d100ed20fcb15b6acbbe394a4c58cf'
    'd0efaafb434d338545f9027f503c9fa8'
    '51a3408f929d38f5bcb6da2110fff3d2'
    'cd0c13ec5f974417c4a77e3d645d1973'
    '60814fdc222a908846eeb814de5e0bdb'
    'e0323a0a4906245cc2d3ac629195e479'
    'e7c8376d8dd54ea96c56f4ea657aae08'
    'ba78252e1ca6b4c6e8dd741f4bbd8b8a'
    '703eb5664803f60e613557b986c11d9e'
    'e1f8981169d98e949b1e87e9ce5528df'
    '8ca1890dbfe6426841992d0fb054bb16')
INV_SBOX = bytearray(256)
for i, v in enumerate(SBOX):
    INV_SBOX[v] = i
INV_SBOX = bytes(INV_SBOX)

RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36,
        0x6C, 0xD8, 0xAB, 0x4D]


def xtime(a):
    """Multiplicação por 2 no corpo de Galois GF(2^8)."""
    a <<= 1
    return (a ^ 0x11B) & 0xFF if a & 0x100 else a


def gmul(a, b):
    r = 0
    for _ in range(8):
        if b & 1:
            r ^= a
        b >>= 1
        a = xtime(a)
    return r


def expandir_chave(chave):
    """Sub-chaves de rodada. 44 palavras para 128 bits, 60 para 256."""
    nk = len(chave) // 4
    nr = nk + 6
    w = [list(chave[4 * i:4 * i + 4]) for i in range(nk)]
    for i in range(nk, 4 * (nr + 1)):
        t = list(w[i - 1])
        if i % nk == 0:
            t = t[1:] + t[:1]                      # RotWord
            t = [SBOX[b] for b in t]               # SubWord
            t[0] ^= RCON[i // nk - 1]
        elif nk > 6 and i % nk == 4:
            # Só existe para AES-256: sem este ramo a expansão de chave de 256
            # bits sai errada da 7ª palavra em diante, e a cifra "funciona"
            # produzindo bytes que nada decifra.
            t = [SBOX[b] for b in t]
        w.append([x ^ y for x, y in zip(w[i - nk], t)])
    return w, nr


def _bloco_cifra(bloco, w, nr):
    est = [[bloco[r + 4 * c] for c in range(4)] for r in range(4)]

    def add_round_key(rodada):
        for c in range(4):
            for r in range(4):
                est[r][c] ^= w[rodada * 4 + c][r]

    add_round_key(0)
    for rodada in range(1, nr + 1):
        for r in range(4):
            for c in range(4):
                est[r][c] = SBOX[est[r][c]]
        for r in range(1, 4):                      # ShiftRows
            est[r] = est[r][r:] + est[r][:r]
        if rodada != nr:                           # MixColumns
            for c in range(4):
                a = [est[r][c] for r in range(4)]
                est[0][c] = gmul(a[0], 2) ^ gmul(a[1], 3) ^ a[2] ^ a[3]
                est[1][c] = a[0] ^ gmul(a[1], 2) ^ gmul(a[2], 3) ^ a[3]
                est[2][c] = a[0] ^ a[1] ^ gmul(a[2], 2) ^ gmul(a[3], 3)
                est[3][c] = gmul(a[0], 3) ^ a[1] ^ a[2] ^ gmul(a[3], 2)
        add_round_key(rodada)
    return bytes(est[r][c] for c in range(4) for r in range(4))


def _bloco_decifra(bloco, w, nr):
    est = [[bloco[r + 4 * c] for c in range(4)] for r in range(4)]

    def add_round_key(rodada):
        for c in range(4):
            for r in range(4):
                est[r][c] ^= w[rodada * 4 + c][r]

    add_round_key(nr)
    for rodada in range(nr - 1, -1, -1):
        for r in range(1, 4):                      # InvShiftRows
            est[r] = est[r][-r:] + est[r][:-r]
        for r in range(4):
            for c in range(4):
                est[r][c] = INV_SBOX[est[r][c]]
        add_round_key(rodada)
        if rodada != 0:                            # InvMixColumns
            for c in range(4):
                a = [est[r][c] for r in range(4)]
                est[0][c] = (gmul(a[0], 14) ^ gmul(a[1], 11)
                             ^ gmul(a[2], 13) ^ gmul(a[3], 9))
                est[1][c] = (gmul(a[0], 9) ^ gmul(a[1], 14)
                             ^ gmul(a[2], 11) ^ gmul(a[3], 13))
                est[2][c] = (gmul(a[0], 13) ^ gmul(a[1], 9)
                             ^ gmul(a[2], 14) ^ gmul(a[3], 11))
                est[3][c] = (gmul(a[0], 11) ^ gmul(a[1], 13)
                             ^ gmul(a[2], 9) ^ gmul(a[3], 14))
    return bytes(est[r][c] for c in range(4) for r in range(4))


def aes_cbc_cifrar(chave, dados, iv=None, preencher=True):
    """AES-CBC. O IV vai no início do resultado, como manda o PDF."""
    w, nr = expandir_chave(chave)
    iv = iv if iv is not None else os.urandom(16)
    if preencher:
        # PKCS#5: quando o dado já é múltiplo de 16, entra um bloco INTEIRO de
        # preenchimento. Omiti-lo faz o decifrador comer 16 bytes de dado real.
        n = 16 - len(dados) % 16
        dados = dados + bytes([n]) * n
    saida = bytearray()
    ant = iv
    for i in range(0, len(dados), 16):
        b = bytes(x ^ y for x, y in zip(dados[i:i + 16], ant))
        ant = _bloco_cifra(b, w, nr)
        saida += ant
    return iv + bytes(saida)


def aes_cbc_decifrar(chave, dados, com_iv=True, tirar_preenchimento=True):
    w, nr = expandir_chave(chave)
    if com_iv:
        ant, dados = dados[:16], dados[16:]
    else:
        ant = b'\x00' * 16
    saida = bytearray()
    for i in range(0, len(dados), 16):
        c = dados[i:i + 16]
        saida += bytes(x ^ y for x, y in zip(_bloco_decifra(c, w, nr), ant))
        ant = c
    if tirar_preenchimento and saida:
        saida = saida[:-saida[-1]]
    return bytes(saida)


def aes_ecb_cifrar_sem_preenchimento(chave, dados):
    w, nr = expandir_chave(chave)
    return b''.join(_bloco_cifra(dados[i:i + 16], w, nr)
                    for i in range(0, len(dados), 16))


# ───────────────────── AES-128: V4 / R4 (/CF com AESV2) ──────────────────────
PADDING = bytes([
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56,
    0xFF, 0xFA, 0x01, 0x08, 0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
    0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A])

SAL_AES = b'sAlT'      # 0x73 0x41 0x6C 0x54, o "salt" do algoritmo 1 com AES


def chave_do_objeto_aes(chave, num, gen):
    """Algoritmo 1 com AES: os quatro bytes 'sAlT' entram no fim do MD5."""
    m = hashlib.md5()
    m.update(chave)
    m.update(struct.pack('<I', num)[:3])
    m.update(struct.pack('<I', gen)[:2])
    m.update(SAL_AES)
    return m.digest()[:min(len(chave) + 5, 16)]


# ───────────────────── AES-256: V5 / R6 (/CF com AESV3) ──────────────────────
def hash_r6(senha, sal, dados_extra=b''):
    """Algoritmo 2.B da especificação (PDF 2.0, 7.6.4.3.4).

    Laço que alterna SHA-256/384/512 com AES-CBC. O critério de parada olha o
    ÚLTIMO byte do resultado da rodada e o compara com o número da rodada — é o
    detalhe que quase todo mundo erra na primeira tentativa.
    """
    k = hashlib.sha256(senha + sal + dados_extra).digest()
    i = 0
    while True:
        k1 = (senha + k + dados_extra) * 64
        e = aes_cbc_cifrar(k[:16], k1, iv=k[16:32], preencher=False)[16:]
        soma = sum(e[:16]) % 3
        k = [hashlib.sha256, hashlib.sha384, hashlib.sha512][soma](e).digest()
        i += 1
        if i >= 64 and e[-1] <= i - 32:
            break
    return k[:32]


def valores_r6(senha_usuario, senha_proprietario, chave_arquivo, permissoes):
    """/U, /UE, /O, /OE e /Perms do AES-256."""
    u_vsal, u_ksal = os.urandom(8), os.urandom(8)
    u = hash_r6(senha_usuario, u_vsal) + u_vsal + u_ksal
    ue = aes_cbc_cifrar(hash_r6(senha_usuario, u_ksal), chave_arquivo,
                        iv=b'\x00' * 16, preencher=False)[16:]

    # O /O do R6 leva os 48 bytes do /U no hash: é o que amarra as duas senhas
    # ao mesmo documento.
    o_vsal, o_ksal = os.urandom(8), os.urandom(8)
    o = hash_r6(senha_proprietario, o_vsal, u) + o_vsal + o_ksal
    oe = aes_cbc_cifrar(hash_r6(senha_proprietario, o_ksal, u), chave_arquivo,
                        iv=b'\x00' * 16, preencher=False)[16:]

    # /Perms: permissões + 'adb' cifrados em ECB, para que adulterar o /P do
    # dicionário (que vai em claro) seja detectável.
    perms = (struct.pack('<i', permissoes) + b'\xff\xff\xff\xff'
             + b'T' + b'adb' + b'\x00\x00\x00\x00')
    return u, ue, o, oe, aes_ecb_cifrar_sem_preenchimento(chave_arquivo, perms)


def verificar_r6(senha, u, ue, o, oe):
    """Verifica a senha no R6 e devolve (é_dono, chave_do_arquivo) ou (None, None).

    A ordem importa: testa-se o USUÁRIO primeiro. Uma senha que sirva às duas
    coisas tem de abrir como usuário, não como dono — o caminho do dono existe
    para quem quer alterar permissões, e assumi-lo por engano daria ao leitor
    poderes que o documento não concedeu.

    Os 48 bytes de /U e /O são: hash de 32, validation salt de 8, key salt de 8.
    A chave sai desembrulhando /UE ou /OE com uma chave derivada do KEY salt —
    e o desembrulho é AES-CBC com IV de ZEROS e SEM preenchimento, ao contrário
    dos streams do documento.
    """
    if hash_r6(senha, u[32:40]) == u[:32]:
        chave = aes_cbc_decifrar(hash_r6(senha, u[40:48]), ue,
                                 com_iv=False, tirar_preenchimento=False)
        return False, chave
    # no caminho do dono, os 48 bytes do /U entram no hash
    if hash_r6(senha, o[32:40], u) == o[:32]:
        chave = aes_cbc_decifrar(hash_r6(senha, o[40:48], u), oe,
                                 com_iv=False, tirar_preenchimento=False)
        return True, chave
    return None, None
