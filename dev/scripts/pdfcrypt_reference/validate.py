# -*- coding: utf-8 -*-
"""
Valida a referência da criptografia contra o MuPDF.

O teste que importa não é "o PDF tem um dicionário /Encrypt" — é:

  1. o MuPDF reconhece o arquivo como protegido;
  2. **sem** a senha, não consegue ler o conteúdo;
  3. **com** a senha de usuário, abre e devolve o texto original;
  4. com a senha de proprietário, idem;
  5. com senha errada, continua recusando;
  6. o texto original não aparece em claro nos bytes do arquivo.

O item 6 é o que separa "marcado como protegido" de "protegido": hoje o
PL_FPDF passa nos cinco primeiros e falha no sexto.

Uso:  python scripts/pdfcrypt_reference/validate.py
"""
import io
import os
import re
import sys

sys.path.insert(0, 'dev/scripts/pdfcrypt_reference')
import pymupdf                                                    # noqa: E402
from pdfcrypt_reference import (PADDING, encryption_key,          # noqa: E402
                                owner_value, user_value,
                                cifrar_documento, rc4, object_key)

FALHAS = []


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


def pdf_simples(texto='Conteudo secreto do documento'):
    """PDF de 2 páginas montado à mão, sem compressão.

    Construído aqui em vez de pelo MuPDF porque ele comprime o content stream
    mesmo com deflate=False, e o teste precisa do texto legível nos bytes para
    depois provar que a cifragem o removeu.
    """
    objs = {}
    conteudos = []
    for i in range(2):
        fluxo = ('BT /F1 14 Tf 72 742 Td (%s %d) Tj ET\n' % (texto, i + 1)).encode()
        conteudos.append(fluxo)

    objs[1] = b'<</Type/Catalog/Pages 2 0 R>>'
    objs[3] = b'<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>'
    pags = []
    n = 4
    for fluxo in conteudos:
        cid = n; n += 1
        objs[cid] = b'<</Length %d>>stream\n' % len(fluxo) + fluxo + b'\nendstream'
        pid = n; n += 1
        objs[pid] = (b'<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]'
                     b'/Resources<</Font<</F1 3 0 R>>>>/Contents %d 0 R>>' % cid)
        pags.append(pid)
    objs[2] = (b'<</Type/Pages/Count %d/Kids[' % len(pags)
               + b' '.join(b'%d 0 R' % p for p in pags) + b']>>')

    out = bytearray(b'%PDF-1.4\n')
    offs = {}
    for oid in sorted(objs):
        offs[oid] = len(out)
        out += b'%d 0 obj' % oid + objs[oid] + b'endobj\n'
    tam = max(objs) + 1
    xref = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % tam
    for i in range(1, tam):
        out += (b'%010d 00000 n \n' % offs[i]) if i in offs else b'0000000000 65535 f \n'
    out += b'trailer<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n' % (tam, xref)
    return bytes(out)


def cifrar(pdf, user_pwd, owner_pwd=None, n=16, rev=3):
    """Aplica /Encrypt ao PDF e cifra os objetos. Devolve os bytes finais."""
    owner_pwd = owner_pwd or user_pwd
    perms = -4                                    # tudo permitido
    file_id = bytes.fromhex('66558CAA72D688ABFC0BA7F184887ED9')

    o_val = owner_value(owner_pwd.encode(), user_pwd.encode(), n, rev)
    key = encryption_key(user_pwd.encode(), o_val, perms, file_id, n, rev)
    u_val = user_value(key, file_id, rev)

    # novo objeto para o dicionário /Encrypt
    num_enc = max(int(m) for m in re.findall(rb'(\d+)\s+\d+\s+obj', pdf)) + 1
    corpo = pdf[:pdf.rfind(b'startxref')]
    corpo = cifrar_documento(corpo, key, num_enc)

    dic = (b'\n%d 0 obj\n<< /Filter /Standard /V %d /R %d /Length %d /P %d'
           b' /O <%s> /U <%s> >>\nendobj\n'
           % (num_enc, 2 if n == 16 else 1, rev, n * 8, perms,
              o_val.hex().upper().encode(), u_val.hex().upper().encode()))

    saida = corpo + dic
    xref = len(saida)
    saida += (b'trailer\n<< /Size %d /Root 1 0 R /Encrypt %d 0 R'
              b' /ID [<%s><%s>] >>\nstartxref\n%d\n%%%%EOF\n'
              % (num_enc + 1, num_enc, file_id.hex().upper().encode(),
                 file_id.hex().upper().encode(), xref))
    return saida


def abre_com(dados, senha):
    """(abriu?, texto) — usando o MuPDF como leitor independente."""
    try:
        doc = pymupdf.open(stream=dados, filetype='pdf')
    except Exception:                                             # noqa: BLE001
        return False, ''
    if doc.needs_pass:
        if not doc.authenticate(senha or ''):
            doc.close()
            return False, ''
    txt = ' '.join(p.get_text() for p in doc)
    doc.close()
    return True, txt


def rc4_em_lotes(key, dados, lote):
    """RC4 fatiado, carregando o estado entre os pedaços.

    Espelha crypto_rc4_blob do PL/SQL: a chave é agendada UMA vez e S, i e j
    atravessam os lotes. É o ponto que faz o RC4 não poder ser simplesmente
    fatiado — reiniciar a cifra em cada pedaço produz lixo.
    """
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) % 256
        s[i], s[j] = s[j], s[i]
    out = bytearray()
    i = j = 0
    for ini in range(0, len(dados), lote):
        for c in dados[ini:ini + lote]:
            i = (i + 1) % 256
            j = (j + s[i]) % 256
            s[i], s[j] = s[j], s[i]
            out.append(c ^ s[(s[i] + s[j]) % 256])
    return bytes(out)


def main():
    ALVO = 'Conteudo secreto do documento'
    limpo = pdf_simples(ALVO)
    print(f'PDF de origem: {len(limpo)} bytes')

    # o texto ESTÁ em claro antes de cifrar — é o que se quer eliminar
    check(ALVO.encode() in limpo, 'origem: o texto aparece em claro (esperado)')

    for rev, n, rotulo in ((3, 16, 'RC4-128 (R3)'), (2, 5, 'RC4-40 (R2)')):
        print(f'\n== {rotulo}')
        cif = cifrar(limpo, 'correct', 'ownerpass', n=n, rev=rev)
        open(f'/tmp/cif_{rev}.pdf', 'wb').write(cif)

        doc = pymupdf.open(stream=cif, filetype='pdf')
        check(doc.needs_pass, f'{rotulo}: MuPDF reconhece como protegido')
        doc.close()

        ok, _ = abre_com(cif, '')
        check(not ok, f'{rotulo}: sem senha, nao abre')

        ok, txt = abre_com(cif, 'correct')
        check(ok and ALVO in txt, f'{rotulo}: com a senha de usuario, abre e le o texto')

        ok, txt = abre_com(cif, 'ownerpass')
        check(ok and ALVO in txt, f'{rotulo}: com a senha de proprietario, abre e le o texto')

        ok, _ = abre_com(cif, 'errada')
        check(not ok, f'{rotulo}: com senha errada, nao abre')

        check(ALVO.encode() not in cif,
              f'{rotulo}: o texto NAO aparece em claro nos bytes do arquivo')

    # ── RC4 em lotes ─────────────────────────────────────────────────────────
    print('\n== RC4 fatiado carrega o estado da cifra')
    import os as _os
    chave = b'ChaveDeTeste'
    for tam in (1, 8000, 8001, 16383, 16384, 50000):
        dados = _os.urandom(tam)
        um_so = rc4(chave, dados)
        check(rc4_em_lotes(chave, dados, 8000) == um_so,
              f'{tam} bytes em lotes de 8000 == uma passada so')
    # e a prova do contrario: reiniciar a cifra a cada lote NAO da o mesmo
    partido = b''.join(rc4(chave, dados[i:i + 8000])
                       for i in range(0, len(dados), 8000))
    check(partido != rc4(chave, dados),
          'reiniciar a cifra a cada lote produz resultado DIFERENTE '
          '(por isso o estado precisa atravessar)')

    print('\n' + ('TODOS OS TESTES PASSARAM' if not FALHAS else
                  f'{len(FALHAS)} FALHA(S):\n  ' + '\n  '.join(FALHAS)))
    return 1 if FALHAS else 0


if __name__ == '__main__':
    sys.exit(main())
