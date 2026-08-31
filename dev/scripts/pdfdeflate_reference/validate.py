# -*- coding: utf-8 -*-
"""
Valida o DEFLATE de referência contra o zlib — o decodificador independente.

DOCUMENTO DE MANUTENÇÃO.

Quatro perguntas:

1. **O que sai volta?** Cada caso é comprimido aqui e descomprimido pelo
   `zlib` do Python. Byte a byte.
2. **Comprime, e nunca cresce?** Dado real tem de encolher; dado incompressível
   não pode ficar maior que a entrada mais o custo do bloco armazenado.
3. **Um leitor de PDF aceita?** Um PDF com o fluxo de conteúdo comprimido por
   esta referência é aberto pelo MuPDF, e o texto sai.
4. **Os vetores conferem?** Os mesmos casos que `tests/diag_deflate.sql` roda
   no banco saem daqui — é o que permite comparar o PL/SQL byte a byte com a
   referência, e não apenas "descomprimiu, então deve estar certo".

Uso:
    pip install pymupdf
    python scripts/pdfdeflate_reference/validate.py
    python scripts/pdfdeflate_reference/validate.py vetores
"""
import random
import sys
import zlib

sys.path.insert(0, __file__.rsplit('/', 1)[0])

import pdfdeflate_reference as df   # noqa: E402

ok = falhas = 0


def conf(cond, msg):
    global ok, falhas
    if cond:
        ok += 1
        print(f'  ok    {msg}')
    else:
        falhas += 1
        print(f'  FALHA {msg}')


def casos():
    rnd = random.Random(7)
    return [
        ('vazio', b''),
        ('um byte', b'A'),
        ('dois bytes', b'AB'),
        ('casamento minimo', b'abcabc'),
        ('tudo igual', b'A' * 5000),
        ('texto de pagina',
         b'BT /F1 12 Tf 20 800 Td (Ola mundo, isto e um teste) Tj ET\n' * 40),
        ('fluxo de conteudo',
         b''.join(b'%d %d m %d %d l S\n' % (i, i * 2, i + 5, i * 3)
                  for i in range(400))),
        ('acentos em latin1', 'ação, coração, ãéíõü'.encode('latin-1') * 60),
        ('aleatorio', bytes(rnd.randrange(256) for _ in range(3000))),
        ('quase aleatorio', bytes(rnd.randrange(4) for _ in range(3000))),
        ('janela cheia', (b'0123456789' * 4000)[:40000]),
        ('casamento longo', b'x' * 300 + b'y' + b'x' * 300),
    ]


def checar_ida_e_volta():
    print('Ida e volta: o zlib descomprime o que esta referencia comprime')
    for nome, dados in casos():
        fluxo = df.zlib_stream(dados)
        try:
            volta = zlib.decompress(fluxo)
        except zlib.error as e:
            conf(False, f'{nome}: o zlib recusou o fluxo ({e})')
            continue
        conf(volta == dados, f'{nome}: {len(dados)} bytes voltam iguais')


def checar_tamanho():
    print('\nTamanho: comprime o que dá, e nunca cresce mais que o armazenado')
    for nome, dados in casos():
        fluxo = df.zlib_stream(dados)
        # 2 do cabeçalho + 4 do Adler + 5 por bloco armazenado
        teto = len(dados) + 6 + 5 * (len(dados) // 65535 + 1)
        conf(len(fluxo) <= teto,
             f'{nome}: {len(dados)} -> {len(fluxo)} (teto {teto})')

    # Teto por caso, e não um número redondo para todos. Onde há repetição
    # longa, a Huffman FIXA chega perto do zlib; onde a economia viria de dar
    # códigos curtos aos símbolos frequentes, ela não tem como competir — é o
    # preço de não transmitir árvore, e está medido, não estimado.
    tetos = {'tudo igual': 5, 'texto de pagina': 10, 'janela cheia': 5,
             'casamento longo': 10, 'acentos em latin1': 10,
             'quase aleatorio': 60, 'fluxo de conteudo': 70}
    for nome, dados in casos():
        if nome not in tetos:
            continue
        fluxo = df.zlib_stream(dados)
        pct = 100 * len(fluxo) / len(dados)
        pct_zlib = 100 * len(zlib.compress(dados, 6)) / len(dados)
        conf(pct <= tetos[nome],
             f'{nome}: encolheu para {pct:.0f}% (teto {tetos[nome]}%, '
             f'zlib nivel 6: {pct_zlib:.0f}%)')


def checar_no_pdf():
    print('\nNo PDF: um leitor de verdade abre o fluxo comprimido')
    try:
        import pymupdf
    except ImportError:
        conf(False, 'sem o MuPDF: pip install pymupdf')
        return

    conteudo = (b'BT /F1 24 Tf 72 700 Td (Comprimido pelo deflate da casa) Tj '
                b'ET\n')
    fluxo = df.zlib_stream(conteudo)
    objetos = [
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        b'/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
        b'<< /Length ' + str(len(fluxo)).encode() +
        b' /Filter /FlateDecode >>\nstream\n' + fluxo + b'\nendstream',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ]
    pdf = bytearray(b'%PDF-1.4\n')
    offsets = []
    for i, obj in enumerate(objetos, start=1):
        offsets.append(len(pdf))
        pdf += b'%d 0 obj\n' % i + obj + b'\nendobj\n'
    inicio = len(pdf)
    pdf += b'xref\n0 %d\n' % (len(objetos) + 1)
    pdf += b'0000000000 65535 f \n'
    for off in offsets:
        pdf += b'%010d 00000 n \n' % off
    pdf += (b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n'
            % (len(objetos) + 1, inicio))

    doc = pymupdf.open(stream=bytes(pdf), filetype='pdf')
    texto = doc[0].get_text().strip()
    conf(texto == 'Comprimido pelo deflate da casa',
         f'o MuPDF leu {texto!r} do fluxo /FlateDecode')
    doc.close()


def vetores():
    """Os mesmos casos, em hexadecimal, para o diagnóstico no banco."""
    print('-- gerado por scripts/pdfdeflate_reference/validate.py vetores')
    for nome, dados in casos():
        if len(dados) > 200:
            continue
        print(f"  -- {nome}")
        print(f"  entrada  := '{dados.hex().upper()}';")
        print(f"  esperado := '{df.zlib_stream(dados).hex().upper()}';")


def main():
    if 'vetores' in sys.argv:
        vetores()
        return 0
    checar_ida_e_volta()
    checar_tamanho()
    checar_no_pdf()
    print(f'\n{ok} ok, {falhas} falha(s)')
    return 1 if falhas else 0


if __name__ == '__main__':
    raise SystemExit(main())
