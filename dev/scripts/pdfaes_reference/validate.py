# -*- coding: utf-8 -*-
"""
Valida a referência do AES contra os vetores oficiais e contra o MuPDF.

Duas camadas, porque elas pegam coisas diferentes:

  1. **FIPS-197** — os vetores oficiais do AES. Uma expansão de chave errada
     produz uma cifra que parece funcionar (cifra e decifra consigo mesma) e que
     nenhum outro programa entende. Só o vetor conhecido pega isso.

  2. **MuPDF** — leitor independente. Monta o PDF cifrado, e confere que ele é
     reconhecido como protegido, abre com a senha de usuário, abre com a de
     proprietário, recusa a errada, devolve o texto original, e que o texto NÃO
     aparece em claro nos bytes.

Uso:  python scripts/pdfaes_reference/validate.py
"""
import hashlib
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', 'pdfcrypt_reference'))
import pymupdf                                                    # noqa: E402
import pdfaes_reference as A                                      # noqa: E402
from pdfcrypt_reference import (encryption_key, owner_value,      # noqa: E402
                                user_value)

FALHAS = []


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


# ─────────────────────────── PDF de teste, sem compressão ────────────────────
def pdf_simples(texto):
    objs = {}
    fluxo = ('BT /F1 14 Tf 72 742 Td (%s) Tj ET\n' % texto).encode()
    objs[1] = b'<</Type/Catalog/Pages 2 0 R>>'
    objs[3] = b'<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>'
    objs[4] = b'<</Length %d>>stream\n' % len(fluxo) + fluxo + b'\nendstream'
    objs[5] = (b'<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]'
               b'/Resources<</Font<</F1 3 0 R>>>>/Contents 4 0 R>>')
    objs[2] = b'<</Type/Pages/Count 1/Kids[5 0 R]>>'
    out = bytearray(b'%PDF-1.6\n')
    offs = {}
    for oid in sorted(objs):
        offs[oid] = len(out)
        out += b'%d 0 obj' % oid + objs[oid] + b'endobj\n'
    tam = max(objs) + 1
    xref = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % tam
    for i in range(1, tam):
        out += b'%010d 00000 n \n' % offs[i]
    out += b'trailer<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n' % (tam, xref)
    return bytes(out)


def cifrar_objetos(pdf, chave_de_objeto, obj_encrypt):
    """Cifra o payload de cada stream com AES-CBC. Só streams: basta para o
    teste, e é o que carrega o texto."""
    import re
    saida = bytearray()
    pos = 0
    for m in re.finditer(rb'(\d+)\s+(\d+)\s+obj', pdf):
        num, gen = int(m.group(1)), int(m.group(2))
        fim = pdf.find(b'endobj', m.end())
        if fim < 0 or num == obj_encrypt:
            continue
        corpo = pdf[m.end():fim]
        p = corpo.find(b'stream')
        if p < 0:
            continue
        ini = p + 6
        if corpo[ini:ini + 2] == b'\r\n':
            ini += 2
        elif corpo[ini:ini + 1] in (b'\n', b'\r'):
            ini += 1
        fim_s = corpo.rfind(b'endstream')
        dados = A.aes_cbc_cifrar(chave_de_objeto(num, gen), corpo[ini:fim_s])
        # AES muda o tamanho (IV + preenchimento): o /Length TEM de ser refeito
        cabeca = re.sub(rb'/Length\s+\d+', b'/Length %d' % len(dados),
                        corpo[:p])
        saida += pdf[pos:m.end()] + cabeca + corpo[p:ini] + dados + corpo[fim_s:]
        pos = fim
    saida += pdf[pos:]
    return bytes(saida)


def remontar(corpo, dic_encrypt, num_enc, id_arq, extra_trailer=b''):
    """Acrescenta o dicionário /Encrypt e refaz xref e trailer."""
    import re
    saida = bytearray(corpo[:corpo.rfind(b'xref')])
    saida += b'%d 0 obj\n' % num_enc + dic_encrypt + b'\nendobj\n'
    pos = {}
    for m in re.finditer(rb'(\d+)\s+\d+\s+obj', bytes(saida)):
        pos[int(m.group(1))] = m.start()
    tam = max(pos) + 1
    xref = len(saida)
    saida += b'xref\n0 %d\n0000000000 65535 f \n' % tam
    for i in range(1, tam):
        saida += (b'%010d 00000 n \n' % pos[i]) if i in pos else \
                 b'0000000000 65535 f \n'
    saida += (b'trailer\n<< /Size %d /Root 1 0 R /Encrypt %d 0 R'
              b' /ID [<%s><%s>] %s>>\nstartxref\n%d\n%%%%EOF\n'
              % (tam, num_enc, id_arq.hex().upper().encode(),
                 id_arq.hex().upper().encode(), extra_trailer, xref))
    return bytes(saida)


# ────────────────────────────── AES-128 (V4/R4) ──────────────────────────────
def cifrar_aes128(pdf, senha_usuario, senha_dono):
    perms = -4
    id_arq = os.urandom(16)
    o = owner_value(senha_dono.encode(), senha_usuario.encode(), 16, 4)
    chave = encryption_key(senha_usuario.encode(), o, perms, id_arq, 16, 4)
    u = user_value(chave, id_arq, 4)

    import re
    num_enc = max(int(m) for m in re.findall(rb'(\d+)\s+\d+\s+obj', pdf)) + 1
    corpo = cifrar_objetos(pdf, lambda n, g: A.chave_do_objeto_aes(chave, n, g),
                           num_enc)
    dic = (b'<< /Filter /Standard /V 4 /R 4 /Length 128 /P %d'
           b' /CF << /StdCF << /CFM /AESV2 /AuthEvent /DocOpen /Length 16 >> >>'
           b' /StmF /StdCF /StrF /StdCF'
           b' /O <%s> /U <%s> >>'
           % (perms, o.hex().upper().encode(), u.hex().upper().encode()))
    return remontar(corpo, dic, num_enc, id_arq)


# ────────────────────────────── AES-256 (V5/R6) ──────────────────────────────
def cifrar_aes256(pdf, senha_usuario, senha_dono):
    perms = -4
    id_arq = os.urandom(16)
    chave = os.urandom(32)                 # no R6 a chave do arquivo é aleatória
    u, ue, o, oe, permsc = A.valores_r6(senha_usuario.encode(),
                                        senha_dono.encode(), chave, perms)

    import re
    num_enc = max(int(m) for m in re.findall(rb'(\d+)\s+\d+\s+obj', pdf)) + 1
    # No R6 não há chave por objeto: a do arquivo é usada direto
    corpo = cifrar_objetos(pdf, lambda n, g: chave, num_enc)
    dic = (b'<< /Filter /Standard /V 5 /R 6 /Length 256 /P %d'
           b' /CF << /StdCF << /CFM /AESV3 /AuthEvent /DocOpen /Length 32 >> >>'
           b' /StmF /StdCF /StrF /StdCF'
           b' /O <%s> /U <%s> /OE <%s> /UE <%s> /Perms <%s> >>'
           % (perms, o.hex().upper().encode(), u.hex().upper().encode(),
              oe.hex().upper().encode(), ue.hex().upper().encode(),
              permsc.hex().upper().encode()))
    return remontar(corpo, dic, num_enc, id_arq)


def abre_com(dados, senha):
    try:
        doc = pymupdf.open(stream=dados, filetype='pdf')
    except Exception:                                             # noqa: BLE001
        return False, ''
    if doc.needs_pass and not doc.authenticate(senha or ''):
        doc.close()
        return False, ''
    txt = ' '.join(p.get_text() for p in doc)
    doc.close()
    return True, txt


def main():
    print('== AES contra os vetores oficiais (FIPS-197)')
    for chave, esperado in ((bytes(range(16)), '69c4e0d86a7b0430d8cdb78070b4c55a'),
                            (bytes(range(32)), '8ea2b7ca516745bfeafc49904b496089')):
        w, nr = A.expandir_chave(chave)
        claro = bytes.fromhex('00112233445566778899aabbccddeeff')
        obtido = A._bloco_cifra(claro, w, nr).hex()
        check(obtido == esperado, f'AES-{len(chave) * 8}: bloco cifrado confere')
        check(A._bloco_decifra(bytes.fromhex(esperado), w, nr) == claro,
              f'AES-{len(chave) * 8}: decifra volta ao original')

    print('\n== CBC e preenchimento')
    for tam in (0, 1, 15, 16, 17, 100):
        d = os.urandom(tam)
        c = A.aes_cbc_cifrar(bytes(range(16)), d)
        check(A.aes_cbc_decifrar(bytes(range(16)), c) == d,
              f'ida e volta com {tam} bytes '
              f'({len(c)} cifrados: 16 de IV + preenchimento)')
    # o caso que costuma passar despercebido
    d = b'A' * 16
    check(len(A.aes_cbc_cifrar(bytes(range(16)), d)) == 48,
          'dado múltiplo de 16 ganha um bloco INTEIRO de preenchimento')

    ALVO = 'Conteudo secreto do documento'
    limpo = pdf_simples(ALVO)
    check(ALVO.encode() in limpo, 'origem: o texto aparece em claro (esperado)')

    for rotulo, cifrar in (('AES-128 (V4/R4)', cifrar_aes128),
                           ('AES-256 (V5/R6)', cifrar_aes256)):
        print(f'\n== {rotulo}')
        cif = cifrar(limpo, 'correct', 'ownerpass')
        open(f'/tmp/aes_{rotulo[4:7]}.pdf', 'wb').write(cif)

        doc = pymupdf.open(stream=cif, filetype='pdf')
        check(doc.needs_pass, f'{rotulo}: MuPDF reconhece como protegido')
        doc.close()

        ok, _ = abre_com(cif, '')
        check(not ok, f'{rotulo}: sem senha, nao abre')
        ok, txt = abre_com(cif, 'correct')
        check(ok and ALVO in txt, f'{rotulo}: senha de usuario abre e le o texto')
        ok, txt = abre_com(cif, 'ownerpass')
        check(ok and ALVO in txt, f'{rotulo}: senha de proprietario abre e le')
        ok, _ = abre_com(cif, 'errada')
        check(not ok, f'{rotulo}: senha errada e recusada')
        check(ALVO.encode() not in cif,
              f'{rotulo}: o texto NAO aparece em claro nos bytes')

    print('\n== verificacao de senha do R6 (o que DecryptPDF precisa fazer)')
    chave = os.urandom(32)
    u, ue, o, oe, _ = A.valores_r6(b'usuario', b'dono', chave, -4)
    dono, k = A.verificar_r6(b'usuario', u, ue, o, oe)
    check(dono is False and k == chave,
          'senha de usuario: aceita, NAO como dono, e devolve a chave')
    dono, k = A.verificar_r6(b'dono', u, ue, o, oe)
    check(dono is True and k == chave,
          'senha de proprietario: aceita como dono e devolve a mesma chave')
    dono, k = A.verificar_r6(b'errada', u, ue, o, oe)
    check(dono is None and k is None, 'senha errada: recusada')
    # a mesma senha para as duas coisas tem de abrir como USUARIO
    u2, ue2, o2, oe2, _ = A.valores_r6(b'igual', b'igual', chave, -4)
    dono, _ = A.verificar_r6(b'igual', u2, ue2, o2, oe2)
    check(dono is False,
          'senha que serve as duas: abre como usuario, nao como dono')

    print('\n' + ('TODOS OS TESTES PASSARAM' if not FALHAS else
                  f'{len(FALHAS)} FALHA(S):\n  ' + '\n  '.join(FALHAS)))
    return 1 if FALHAS else 0


if __name__ == '__main__':
    sys.exit(main())
