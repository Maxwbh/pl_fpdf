# -*- coding: utf-8 -*-
"""
Valida a referência de marcas d'água e overlays contra o MuPDF.

O teste que importa não é "o PDF tem um objeto de stream a mais" — é:

  1. o MuPDF abre o arquivo e continua com as mesmas páginas;
  2. o texto original continua lá (o desenho ACRESCENTA, não substitui);
  3. o texto da marca d'água aparece na página, na extração de texto;
  4. a marca cai onde foi pedida — perto do centro, girada;
  5. o overlay só aparece na página pedida;
  6. as páginas que compartilhavam /Resources com a alterada não são afetadas;
  7. a imagem sobreposta é reconhecida como imagem da página.

O item 6 é o que separa "funciona no exemplo" de "funciona": no PDF gerado pelo
PL_FPDF todas as páginas apontam para o MESMO /Resources, e mesclar nele
espalharia a fonte da marca d'água — ou pior, um /XObject — por todas.

Uso:  python scripts/pdfoverlay_reference/validate.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pymupdf                                                    # noqa: E402
from pdfoverlay_reference import (aplicar, ops_marca_dagua,       # noqa: E402
                                  ops_imagem, ops_texto,
                                  recursos_texto, largura_texto)

FALHAS = []


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


def pdf_base(paginas=3):
    """PDF sem compressão, com /Resources indireto COMPARTILHADO — igual ao que
    o PL_FPDF gera, que é o caso difícil."""
    objs, kids, n = {}, [], 4
    for i in range(paginas):
        fluxo = ('BT /F1 14 Tf 72 742 Td (Conteudo original %d) Tj ET\n'
                 % (i + 1)).encode()
        cid = n; n += 1
        objs[cid] = b'<</Length %d>>stream\n' % len(fluxo) + fluxo + b'\nendstream'
        pid = n; n += 1
        objs[pid] = (b'<</Type /Page /Parent 2 0 R /MediaBox [0 0 595 842]'
                     b' /Resources 3 0 R /Contents %d 0 R>>' % cid)
        kids.append(pid)
    objs[1] = b'<</Type /Catalog /Pages 2 0 R>>'
    objs[2] = (b'<</Type /Pages /Count %d /Kids[' % len(kids)
               + b' '.join(b'%d 0 R' % p for p in kids) + b']>>')
    objs[3] = (b'<< /ProcSet [/PDF /Text] /Font << /F1 << /Type /Font'
               b' /Subtype /Type1 /BaseFont /Helvetica >> >> >>')

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


def png_vermelho(lado=8):
    """PNG mínimo, para o overlay de imagem."""
    import struct
    import zlib
    cru = b''.join(b'\x00' + b'\xff\x00\x00' * lado for _ in range(lado))

    def bloco(tipo, dados):
        c = tipo + dados
        return struct.pack('>I', len(dados)) + c + struct.pack('>I', zlib.crc32(c))

    return (b'\x89PNG\r\n\x1a\n'
            + bloco(b'IHDR', struct.pack('>IIBBBBB', lado, lado, 8, 2, 0, 0, 0))
            + bloco(b'IDAT', zlib.compress(cru))
            + bloco(b'IEND', b''))


def main():
    MARCA = 'CONFIDENCIAL'
    base = pdf_base(3)
    print(f'PDF de origem: {len(base)} bytes, 3 páginas com /Resources 3 0 R')

    # ── marca d'água na 1 e na 3, overlay de texto só na 2 ───────────────────
    pedido = {
        1: {'ops': ops_marca_dagua(MARCA, 595, 842, opacidade=0.3, rotacao=45),
            'recursos': recursos_texto(0.3)},
        3: {'ops': ops_marca_dagua(MARCA, 595, 842, opacidade=0.3, rotacao=45),
            'recursos': recursos_texto(0.3)},
        2: {'ops': ops_texto(72, 400, 'Carimbo da pagina 2', corpo=20,
                             cor=(0.8, 0, 0)),
            'recursos': recursos_texto(1.0)},
    }
    saida = aplicar(base, pedido)
    open('/tmp/overlay.pdf', 'wb').write(saida)

    doc = pymupdf.open(stream=saida, filetype='pdf')
    check(doc.page_count == 3, f'MuPDF abre com 3 páginas (deu {doc.page_count})')

    textos = [p.get_text() for p in doc]
    for i in range(3):
        check(f'Conteudo original {i + 1}' in textos[i],
              f'página {i + 1}: o conteúdo original continua lá')

    check(MARCA in textos[0], 'página 1: a marca d\'água aparece no texto')
    check(MARCA in textos[2], 'página 3: a marca d\'água aparece no texto')
    check(MARCA not in textos[1],
          'página 2: a marca d\'água NÃO vaza para quem não a pediu')
    check('Carimbo da pagina 2' in textos[1], 'página 2: o overlay de texto aparece')
    check('Carimbo da pagina 2' not in textos[0] + textos[2],
          'o overlay de texto não vaza para as outras páginas')

    # posição: a marca tem de estar em torno do centro da página
    cx, cy = 595 / 2, 842 / 2
    achou = [b for b in doc[0].get_text('words') if MARCA in b[4]]
    if not achou:
        check(False, 'página 1: a marca d\'água tem posição localizável')
    else:
        x0, y0, x1, y1 = achou[0][:4]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        check(abs(mx - cx) < 60 and abs(my - cy) < 60,
              f'página 1: a marca fica perto do centro '
              f'(centro do texto: {mx:.0f},{my:.0f}; página: {cx:.0f},{cy:.0f})')
        check(x1 - x0 > 100 and y1 - y0 > 100,
              f'página 1: a marca está girada (caixa {x1-x0:.0f}x{y1-y0:.0f}, '
              f'uma linha reta teria altura ~ o corpo)')

    # /Resources: a página 2 não pode ter herdado a fonte da marca d'água
    fontes = {i + 1: {f[3] for f in doc[i].get_fonts()} for i in range(3)}
    check(any('Helvetica' in f for f in fontes[2]),
          'página 2: as fontes originais continuam')
    doc.close()

    # ── imagem sobreposta ────────────────────────────────────────────────────
    print('\n== overlay de imagem')
    from pdfoverlay_reference import _atualizacao_incremental, _objetos
    base2 = pdf_base(2)

    # O XObject da imagem tem de ser objeto indireto e entrar ANTES: aplicar()
    # aloca a partir do maior id existente, então gravá-lo depois sobrescreveria
    # o objeto do fluxo de desenho — foi exatamente o que aconteceu na primeira
    # tentativa, e o MuPDF acusou "syntax error in content stream".
    cru = b'\xff\x00\x00' * 64                       # 8x8 RGB, sem filtro
    id_img = max(_objetos(base2)) + 1
    base2 = _atualizacao_incremental(base2, [(id_img,
        b'<< /Type /XObject /Subtype /Image /Width 8 /Height 8'
        b' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length %d >>stream\n'
        % len(cru) + cru + b'\nendstream')], {})

    recursos = recursos_texto(1.0)
    recursos[b'/XObject'] = b'/ImgPLFPDF %d 0 R' % id_img
    saida2 = aplicar(base2, {
        1: {'ops': ops_imagem(100, 500, 120, 120, 'ImgPLFPDF'),
            'recursos': recursos}})
    open('/tmp/overlay_img.pdf', 'wb').write(saida2)

    d2 = pymupdf.open(stream=saida2, filetype='pdf')
    check(d2.page_count == 2, f'MuPDF abre com 2 páginas (deu {d2.page_count})')
    check('Conteudo original 1' in d2[0].get_text(),
          'página 1: o conteúdo original continua lá')
    imgs = d2[0].get_images(full=True)
    check(len(imgs) == 1, f'página 1: 1 imagem reconhecida (deu {len(imgs)})')
    check(len(d2[1].get_images(full=True)) == 0,
          'página 2: nenhuma imagem — o /XObject não vazou pelo /Resources '
          'compartilhado')
    pix = d2[0].get_pixmap(dpi=72)
    # o pixel no meio de onde a imagem foi posta tem de ser vermelho
    px = pix.pixel(int(100 + 60), int(842 - 500 - 60))
    check(px[0] > 200 and px[1] < 60 and px[2] < 60,
          f'página 1: a imagem foi desenhada onde se pediu (pixel {px})')
    d2.close()

    print('\n' + ('TODOS OS TESTES PASSARAM' if not FALHAS else
                  f'{len(FALHAS)} FALHA(S):\n  ' + '\n  '.join(FALHAS)))
    return 1 if FALHAS else 0


if __name__ == '__main__':
    sys.exit(main())
