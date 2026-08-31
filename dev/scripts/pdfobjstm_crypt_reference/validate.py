# -*- coding: utf-8 -*-
"""
Valida a cifragem sobre object streams contra o MuPDF.

O oráculo é o MuPDF em dois níveis: ele **abre** o arquivo produzido (com a
senha, quando é o caso) e ele **lê o conteúdo** — o texto das páginas e o título
nos metadados. Contar páginas não bastaria: o defeito que este arquivo existe
para pegar deixa o documento perfeitamente abrível e só embaralha uma string.

A assimetria, que é o ponto
---------------------------
Dentro de um object stream as strings não são cifradas individualmente — o que
se cifra é o stream inteiro. Fora dele, cada string é cifrada com a chave do seu
objeto. Ao achatar, isso vira:

  cifrando   → as strings que vieram do ObjStm PASSAM a precisar de cifragem
  decifrando → as strings que vieram do ObjStm JÁ estão em claro

Para provar que a regra importa, `decifrar()` aceita o parâmetro
`decifrar_strings_do_objstm`, que faz o que uma porta desatenta faria. O teste
liga esse parâmetro e exige que o resultado **saia errado**. Um teste que passa
dos dois jeitos não estaria testando nada.

O fixture é montado à mão
-------------------------
O MuPDF grava PDF cifrado com object stream, mas deixa o `/Info` — o objeto com
strings — FORA dele. Como é justamente a string de dentro do ObjStm que
interessa, o arquivo é construído aqui, com o `/Info` lá dentro, e o MuPDF é
chamado para confirmar que o fixture é um PDF cifrado de verdade antes de
qualquer outra coisa.

Uso:  python scripts/pdfobjstm_crypt_reference/validate.py
"""
import os
import sys
import zlib

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join(AQUI, '..', 'pdfcrypt_reference'))
sys.path.insert(0, os.path.join(AQUI, '..', 'pdfxref_reference'))

import pdfcrypt_reference as rc4ref                        # noqa: E402
import pdfobjstm_crypt_reference as m                      # noqa: E402

try:
    import pymupdf
except ImportError:
    import fitz as pymupdf

FALHAS = []
TITULO = 'Titulo (com parenteses) dentro do ObjStm'


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


# ───────────────────────── fixtures ──────────────────────────────────────────

def pdf_claro_com_objstm(titulo=TITULO):
    """PDF 1.5 em claro: Catalog, Pages, Page, Font e Info dentro do ObjStm."""
    fluxo = b'BT /F1 14 Tf 40 60 Td (texto da pagina) Tj ET'
    dentro = {
        1: b'<< /Type /Catalog /Pages 2 0 R >>',
        2: b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        3: b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 120] '
           b'/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
        5: b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        6: b'<< /Title (' + titulo.encode('latin-1') + b') >>',
    }
    return _montar_objstm(dentro, fluxo, None)


def pdf_cifrado_com_objstm(senha='senha123', dono='dono', titulo=TITULO):
    """O mesmo arquivo, cifrado como um produtor de verdade cifraria.

    O ObjStm vai cifrado INTEIRO e as strings de dentro seguem em claro; o
    fluxo de conteúdo é cifrado com a chave do seu objeto; a xref em stream
    **não** é cifrada, porque o leitor precisa dela para achar o /Encrypt.
    """
    fluxo = b'BT /F1 14 Tf 40 60 Td (texto da pagina) Tj ET'
    dentro = {
        1: b'<< /Type /Catalog /Pages 2 0 R >>',
        2: b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        3: b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 120] '
           b'/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
        5: b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        6: b'<< /Title (' + titulo.encode('latin-1') + b') >>',
    }
    file_id = b'\x02' * 16
    perms = -4
    o_val = rc4ref.owner_value(dono.encode(), senha.encode(), 16, 4)
    chave = rc4ref.encryption_key(senha.encode(), o_val, perms, file_id, 16, 4)
    u_val = rc4ref.user_value(chave, file_id, 4)
    enc = (b'<< /Filter /Standard /V 4 /R 4 /Length 128 /P %d'
           b' /CF << /StdCF << /CFM /V2 /AuthEvent /DocOpen /Length 16 >> >>'
           b' /StmF /StdCF /StrF /StdCF'
           b' /O <%s> /U <%s> >>'
           % (perms, o_val.hex().upper().encode(),
              u_val.hex().upper().encode()))
    return _montar_objstm(dentro, fluxo, (chave, enc, file_id))


def _montar_objstm(dentro, fluxo, cripto):
    """Monta o PDF; `cripto` = (chave, dic_encrypt, file_id) ou None."""
    chave = cripto[0] if cripto else None

    pares, corpo = b'', b''
    for oid in sorted(dentro):
        pares += b'%d %d ' % (oid, len(corpo))
        corpo += dentro[oid] + b'\n'
    objstm_dados = zlib.compress(pares + corpo)
    stm_oid, xref_oid, enc_oid = 7, 8, 9

    buf = bytearray(b'%PDF-1.5\n%\xe2\xe3\xcf\xd3\n')
    offs = {}

    # objeto 4: o fluxo de conteúdo, cifrado com a chave do PRÓPRIO objeto
    dados4 = rc4ref.rc4(rc4ref.object_key(chave, 4, 0), fluxo) if chave else fluxo
    offs[4] = len(buf)
    buf += (b'4 0 obj\n<< /Length %d >>\nstream\n' % len(dados4) + dados4
            + b'\nendstream\nendobj\n')

    # objeto 7: o object stream. Cifrado INTEIRO; as strings de dentro não.
    dados7 = rc4ref.rc4(rc4ref.object_key(chave, stm_oid, 0),
                        objstm_dados) if chave else objstm_dados
    offs[stm_oid] = len(buf)
    buf += (b'%d 0 obj\n<< /Type /ObjStm /N %d /First %d /Filter /FlateDecode '
            b'/Length %d >>\nstream\n'
            % (stm_oid, len(dentro), len(pares), len(dados7))
            + dados7 + b'\nendstream\nendobj\n')

    if cripto:
        offs[enc_oid] = len(buf)
        buf += b'%d 0 obj\n' % enc_oid + cripto[1] + b'\nendobj\n'

    # objeto 8: a xref em stream — nunca cifrada
    offs[xref_oid] = len(buf)
    size = (enc_oid if cripto else xref_oid) + 1
    linhas = bytearray()
    for oid in range(size):
        if oid == 0:
            linhas += bytes([0]) + (0).to_bytes(4, 'big') + (0).to_bytes(2, 'big')
        elif oid in offs:
            linhas += bytes([1]) + offs[oid].to_bytes(4, 'big') \
                + (0).to_bytes(2, 'big')
        elif oid in dentro:
            idx = sorted(dentro).index(oid)
            linhas += bytes([2]) + stm_oid.to_bytes(4, 'big') \
                + idx.to_bytes(2, 'big')
        else:
            linhas += bytes([0]) + (0).to_bytes(4, 'big') + (0).to_bytes(2, 'big')
    dadosx = zlib.compress(bytes(linhas))
    extra = b''
    if cripto:
        idhex = cripto[2].hex().upper().encode()
        extra = (b' /Encrypt %d 0 R /ID [<%s><%s>]' % (enc_oid, idhex, idhex))
    buf += (b'%d 0 obj\n<< /Type /XRef /Size %d /W [1 4 2] /Root 1 0 R '
            b'/Info 6 0 R%s /Filter /FlateDecode /Length %d >>\nstream\n'
            % (xref_oid, size, extra, len(dadosx))
            + dadosx + b'\nendstream\nendobj\n')
    buf += b'startxref\n%d\n%%%%EOF\n' % offs[xref_oid]
    return bytes(buf)


# ──────────────────────────────── testes ─────────────────────────────────────

def abre(dados, senha=None):
    d = pymupdf.open(stream=dados, filetype='pdf')
    if senha:
        d.authenticate(senha)
    return d


def main():
    tmp = os.path.join(AQUI, 'amostras')
    if not os.path.isdir(tmp):
        os.makedirs(tmp)

    print('== o fixture em claro é um PDF de verdade ==')
    claro = pdf_claro_com_objstm()
    open(os.path.join(tmp, 'claro.pdf'), 'wb').write(claro)
    d = abre(claro)
    check(d.page_count == 1 and 'texto da pagina' in d[0].get_text(),
          'MuPDF abre e lê o texto')
    check(d.metadata.get('title') == TITULO,
          'o título vem de dentro do object stream: %r'
          % d.metadata.get('title'))
    d.close()

    print('== achatar preserva o documento ==')
    objetos, root, info = m.achatar(claro)
    achatado = m.montar(objetos, root, info)
    open(os.path.join(tmp, 'achatado.pdf'), 'wb').write(achatado)
    d = abre(achatado)
    check(d.page_count == 1 and 'texto da pagina' in d[0].get_text(),
          'o arquivo achatado abre e tem o mesmo texto')
    check(d.metadata.get('title') == TITULO, 'e o mesmo título')
    d.close()
    check(b'/ObjStm' not in achatado and b'/XRef' not in achatado,
          'nenhum ObjStm nem XRef sobrou na saída')
    check(sum(1 for o in objetos if o.de_objstm) == 5,
          '5 objetos foram desmontados do object stream')

    print('== cifrar um PDF 1.5+ em claro ==')
    for aes, nome in ((False, 'RC4-128'), (True, 'AES-128')):
        cif = m.cifrar(claro, 'senha123', 'dono', aes=aes)
        open(os.path.join(tmp, 'cifrado_%s.pdf' % nome), 'wb').write(cif)
        d = pymupdf.open(stream=cif, filetype='pdf')
        protegido = d.needs_pass
        entrou = d.authenticate('senha123')
        texto = d[0].get_text() if d.page_count else ''
        titulo = d.metadata.get('title')
        d.close()
        d2 = pymupdf.open(stream=cif, filetype='pdf')
        recusa = not d2.authenticate('errada')
        d2.close()
        check(protegido and entrou and 'texto da pagina' in texto,
              '%s: protegido, abre com a senha e o texto está lá' % nome)
        check(titulo == TITULO,
              '%s: a string que veio do ObjStm sobreviveu — %r' % (nome, titulo))
        check(recusa, '%s: senha errada é recusada' % nome)
        check(b'texto da pagina' not in cif and TITULO.encode() not in cif,
              '%s: nem o texto nem o título estão em claro no arquivo' % nome)

    print('== decifrar um PDF 1.5+ cifrado (ObjStm cifrado na origem) ==')
    cif = pdf_cifrado_com_objstm()
    open(os.path.join(tmp, 'origem_cifrada.pdf'), 'wb').write(cif)
    d = pymupdf.open(stream=cif, filetype='pdf')
    fixture_ok = d.needs_pass and d.authenticate('senha123')
    fixture_txt = d[0].get_text() if d.page_count else ''
    fixture_tit = d.metadata.get('title')
    d.close()
    check(fixture_ok and 'texto da pagina' in fixture_txt,
          'o fixture cifrado é aceito pelo MuPDF com a senha')
    check(fixture_tit == TITULO,
          'e o MuPDF lê o título de dentro do ObjStm cifrado')

    claro2 = m.decifrar(cif, 'senha123')
    open(os.path.join(tmp, 'decifrado.pdf'), 'wb').write(claro2)
    d = pymupdf.open(stream=claro2, filetype='pdf')
    check(not d.needs_pass, 'o resultado abre SEM senha')
    check(d.page_count == 1 and 'texto da pagina' in d[0].get_text(),
          'e traz o texto da página')
    tit = d.metadata.get('title')
    d.close()
    check(tit == TITULO, 'e o título intacto — %r' % tit)
    check(b'/Encrypt' not in claro2, 'o /Encrypt saiu do arquivo')

    print('== a assimetria importa? (mutação deliberada) ==')
    # Uma porta desatenta decifraria também as strings que vieram do ObjStm.
    # O arquivo continua abrindo — é justamente esse o perigo.
    errado = m.decifrar(cif, 'senha123', decifrar_strings_do_objstm=True)
    d = pymupdf.open(stream=errado, filetype='pdf')
    tit_errado = d.metadata.get('title')
    abre_assim_mesmo = d.page_count == 1
    d.close()
    check(abre_assim_mesmo,
          'o arquivo errado ABRE do mesmo jeito — por isso contar páginas não '
          'bastaria')
    check(tit_errado != TITULO,
          'e o título sai embaralhado, como tem de sair: %r' % tit_errado)

    print('== senha de proprietário ==')
    cif = m.cifrar(claro, 'usuario', 'dono')
    d = pymupdf.open(stream=cif, filetype='pdf')
    check(d.authenticate('dono'), 'a senha de proprietário também abre')
    d.close()

    print('== recusas ==')
    try:
        m.decifrar(claro, 'qualquer')
        check(False, 'decifrar um PDF em claro é recusado')
    except m.ErroCrypt:
        check(True, 'decifrar um PDF em claro é recusado')

    print('')
    if FALHAS:
        print('%d falha(s):' % len(FALHAS))
        for f in FALHAS:
            print('  - ' + f)
        return 1
    print('tudo certo')
    return 0


if __name__ == '__main__':
    sys.exit(main())
