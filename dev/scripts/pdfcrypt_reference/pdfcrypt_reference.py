# -*- coding: utf-8 -*-
"""
Referência da criptografia RC4 do PDF (revisões 2 e 3), a ser portada para
PL_FPDF.EncryptPDF.

O que falta no package hoje
--------------------------
`EncryptPDF` monta o dicionário `/Encrypt` e calcula `/O`, `/U` e `/P`
corretamente, mas **não cifra os fluxos de conteúdo**: o PDF sai marcado como
protegido com o texto legível por qualquer um que abra o arquivo num editor.
Esta referência implementa a parte que falta e é validada contra o MuPDF —
que abre o resultado com a senha, e recusa sem ela.

Algoritmos da especificação (PDF 1.7, seção 7.6.3):
  2. chave de criptografia do documento, a partir da senha de usuário
  3. valor /O, a partir das senhas de proprietário e de usuário
  4. valor /U para revisão 2
  5. valor /U para revisão 3+
  1. chave por objeto: MD5(chave + num(3 bytes LE) + geração(2 bytes LE))

O ponto que o package ainda não faz é justamente o algoritmo 1 aplicado a cada
stream e a cada string do documento. RC4 é cifra de fluxo: o tamanho não muda,
então `/Length` continua valendo.
"""
import hashlib
import re
import struct

PADDING = bytes([
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56,
    0xFF, 0xFA, 0x01, 0x08, 0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
    0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A])


def rc4(key: bytes, data: bytes) -> bytes:
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) % 256
        s[i], s[j] = s[j], s[i]
    out = bytearray()
    i = j = 0
    for c in data:
        i = (i + 1) % 256
        j = (j + s[i]) % 256
        s[i], s[j] = s[j], s[i]
        out.append(c ^ s[(s[i] + s[j]) % 256])
    return bytes(out)


def pad_password(pwd: bytes) -> bytes:
    """Senha completada até 32 bytes com o INÍCIO da string de preenchimento."""
    pwd = pwd[:32]
    return pwd + PADDING[:32 - len(pwd)]


def owner_value(owner_pwd: bytes, user_pwd: bytes, n: int, rev: int) -> bytes:
    """Algoritmo 3: valor /O."""
    h = hashlib.md5(pad_password(owner_pwd or user_pwd)).digest()
    if rev >= 3:
        for _ in range(50):
            h = hashlib.md5(h).digest()
    key = h[:n]
    out = rc4(key, pad_password(user_pwd))
    if rev >= 3:
        for i in range(1, 20):
            out = rc4(bytes(b ^ i for b in key), out)
    return out


def encryption_key(user_pwd: bytes, o_value: bytes, perms: int,
                   file_id: bytes, n: int, rev: int) -> bytes:
    """Algoritmo 2: chave de criptografia do documento."""
    m = hashlib.md5()
    m.update(pad_password(user_pwd))
    m.update(o_value)
    m.update(struct.pack('<i', perms))      # 4 bytes, little-endian, com sinal
    m.update(file_id)
    h = m.digest()
    if rev >= 3:
        for _ in range(50):
            h = hashlib.md5(h[:n]).digest()
    return h[:n]


def user_value(key: bytes, file_id: bytes, rev: int) -> bytes:
    """Algoritmos 4 (rev 2) e 5 (rev 3+): valor /U."""
    if rev == 2:
        return rc4(key, PADDING)
    h = hashlib.md5(PADDING + file_id).digest()
    out = rc4(key, h)
    for i in range(1, 20):
        out = rc4(bytes(b ^ i for b in key), out)
    return out + b'\x00' * 16          # completado a 32 bytes


def object_key(key: bytes, num: int, gen: int) -> bytes:
    """Algoritmo 1: chave derivada para um objeto."""
    m = hashlib.md5()
    m.update(key)
    m.update(struct.pack('<I', num)[:3])   # 3 bytes menos significativos
    m.update(struct.pack('<I', gen)[:2])   # 2 bytes menos significativos
    return m.digest()[:min(len(key) + 5, 16)]


# ─────────────────────── cifragem do documento inteiro ───────────────────────
OBJ = re.compile(rb'(\d+)\s+(\d+)\s+obj', re.S)


def escapar_string_pdf(dados: bytes) -> bytes:
    """Escapa uma string literal do PDF: ( ) \\ e bytes de controle."""
    out = bytearray(b'(')
    for b in dados:
        if b in (0x28, 0x29, 0x5C):            # ( ) \
            out += b'\\' + bytes([b])
        elif b == 0x0D:
            out += b'\\r'
        elif b == 0x0A:
            out += b'\\n'
        else:
            out.append(b)
    out += b')'
    return bytes(out)


def desescapar_string_pdf(texto: bytes) -> bytes:
    """Inverso do anterior, para o conteúdo entre parênteses."""
    out = bytearray()
    i = 0
    while i < len(texto):
        c = texto[i:i + 1]
        if c == b'\\' and i + 1 < len(texto):
            p = texto[i + 1:i + 2]
            out += {b'r': b'\r', b'n': b'\n', b't': b'\t'}.get(p, p)
            i += 2
        else:
            out += c
            i += 1
    return bytes(out)


def cifrar_documento(pdf: bytes, key: bytes, obj_encrypt: int) -> bytes:
    """Cifra os streams e as strings de cada objeto, com a chave do objeto.

    O dicionário /Encrypt (obj_encrypt) fica de fora: seus valores /O e /U já
    são o resultado dos algoritmos 3 e 5 e não podem ser cifrados de novo.
    """
    saida = bytearray()
    pos = 0
    for m in OBJ.finditer(pdf):
        num, gen = int(m.group(1)), int(m.group(2))
        fim_obj = pdf.find(b'endobj', m.end())
        if fim_obj < 0:
            continue
        saida += pdf[pos:m.end()]
        corpo = pdf[m.end():fim_obj]
        if num != obj_encrypt:
            corpo = cifrar_objeto(corpo, object_key(key, num, gen))
        saida += corpo
        pos = fim_obj
    saida += pdf[pos:]
    return bytes(saida)


def cifrar_objeto(corpo: bytes, ok: bytes) -> bytes:
    """Cifra o payload do stream e as strings literais de um objeto."""
    p = corpo.find(b'stream')
    if p >= 0:
        ini = p + 6
        if corpo[ini:ini + 2] == b'\r\n':
            ini += 2
        elif corpo[ini:ini + 1] in (b'\n', b'\r'):
            ini += 1
        fim = corpo.rfind(b'endstream')
        cabeca = cifrar_strings(corpo[:p], ok) + corpo[p:ini]
        return cabeca + rc4(ok, corpo[ini:fim]) + corpo[fim:]
    return cifrar_strings(corpo, ok)


def percorrer_strings(dic: bytes, transforma) -> bytes:
    """Aplica `transforma(bytes_em_claro) -> bytes` a cada string literal.

    Varredura com **contagem de profundidade**, e não regex. Uma string do PDF
    pode conter parênteses BALANCEADOS sem escape: `(Titulo (2026) final)` é uma
    string só. A regex ingênua `\(...\)` que estava aqui casava `(2026)` e
    deixava o resto de fora — o arquivo saía com um pedaço cifrado no meio de
    texto em claro, e o leitor, que decifra a string INTEIRA, mostrava lixo.

    O `sec_cifrar_strings` do PL/SQL sempre contou profundidade; era a
    referência que discordava dele. Apareceu ao cifrar um documento cujo
    título tinha parênteses.
    """
    saida = bytearray()
    i, n = 0, len(dic)
    while i < n:
        if dic[i:i + 1] != b'(':
            saida += dic[i:i + 1]
            i += 1
            continue
        prof, j = 1, i + 1
        while j < n and prof > 0:
            c = dic[j:j + 1]
            if c == b'\\':
                j += 1
            elif c == b'(':
                prof += 1
            elif c == b')':
                prof -= 1
                if prof == 0:
                    break
            j += 1
        saida += escapar_string_pdf(transforma(desescapar_string_pdf(dic[i + 1:j])))
        i = j + 1
    return bytes(saida)


def cifrar_strings(dic: bytes, ok: bytes) -> bytes:
    return percorrer_strings(dic, lambda t: rc4(ok, t))
