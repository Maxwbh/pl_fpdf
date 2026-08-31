# -*- coding: utf-8 -*-
"""
Valida a referência do /XObject de imagem contra o MuPDF.

O teste que importa não é "o PDF tem um objeto de imagem" — é que o leitor
**renderize os pixels certos**. Um /DecodeParms errado, um /ColorSpace trocado
ou uma paleta mal montada produzem um arquivo perfeitamente válido que desenha
ruído, e nenhuma checagem estrutural pega isso.

Por isso cada caso monta a imagem com cores conhecidas, gera o PDF, deixa o
MuPDF rasterizar e compara pixel a pixel.

Uso:  python scripts/pdfimage_reference/validate.py
"""
import io
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pymupdf                                                    # noqa: E402
from pdfimage_reference import (PASSOS_ADAM7, desentrelacar,      # noqa: E402
                                desfiltrar, dimensoes, parse_jpeg,
                                xobject, xobject_png)

FALHAS = []


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


# ───────────────────────────── imagens de teste ──────────────────────────────
def bloco_png(tipo, dados):
    c = tipo + dados
    return struct.pack('>I', len(dados)) + c + struct.pack('>I', zlib.crc32(c))


def png(largura, altura, pixels, ct=2, bits=8, paleta=None):
    """PNG sem filtro por linha (tipo 0), que é o caso que o Predictor 15 cobre."""
    cru = b''
    passo = {0: 1, 2: 3, 3: 1}[ct] * largura
    for y in range(altura):
        cru += b'\x00' + pixels[y * passo:(y + 1) * passo]
    saida = (b'\x89PNG\r\n\x1a\n'
             + bloco_png(b'IHDR', struct.pack('>IIBBBBB', largura, altura,
                                              bits, ct, 0, 0, 0)))
    if paleta is not None:
        saida += bloco_png(b'PLTE', paleta)
    return saida + bloco_png(b'IDAT', zlib.compress(cru)) + bloco_png(b'IEND', b'')


def png_pillow(modo, tamanho, cor):
    """PNG gravado pelo Pillow — produtor de verdade, não um construtor daqui.

    É de onde vêm os fixtures com canal alfa (`RGBA` = color type 6, `LA` = 4)
    e o de 16 bits (`I;16`), que este arquivo não teria como montar à mão sem
    virar juiz da própria causa.
    """
    from PIL import Image
    buf = io.BytesIO()
    Image.new(modo, tamanho, cor).save(buf, 'PNG')
    return buf.getvalue()


def png_entrelacado(largura, altura, pixels_rgb):
    """PNG Adam7, montado aqui porque o Pillow não grava entrelaçado.

    Montar o fixture com o mesmo raciocínio que o decodificador usa seria juiz
    e réu; por isso o teste confere o arquivo com o **Pillow** antes de usá-lo.
    Se o Pillow ler os pixels certos, o fixture é um PNG entrelaçado válido, e
    aí sim ele serve para exercitar o `desentrelacar`.
    """
    saida = bytearray()
    for x0, y0, dx, dy in PASSOS_ADAM7:
        pl = (largura - x0 + dx - 1) // dx
        pa = (altura - y0 + dy - 1) // dy
        if pl == 0 or pa == 0:
            continue
        for j in range(pa):
            saida += b'\x00'                     # filtro 0 nesta linha
            for i in range(pl):
                p = ((y0 + j * dy) * largura + (x0 + i * dx)) * 3
                saida += pixels_rgb[p:p + 3]
    return (b'\x89PNG\r\n\x1a\n'
            + bloco_png(b'IHDR', struct.pack('>IIBBBBB', largura, altura,
                                             8, 2, 0, 0, 1))
            + bloco_png(b'IDAT', zlib.compress(bytes(saida)))
            + bloco_png(b'IEND', b''))


def jpeg(largura, altura, cor):
    """JPEG de cor sólida, produzido pelo Pillow."""
    from PIL import Image
    buf = io.BytesIO()
    Image.new('RGB', (largura, altura), cor).save(buf, 'JPEG', quality=95)
    return buf.getvalue()


def pdf_com_imagem(dados_img, larg_pt=200, alt_pt=200, fundo=None):
    """PDF de uma página com a imagem desenhada em (50, 500).

    `fundo` pinta um retângulo (r, g, b) sob a imagem — é o que torna a
    transparência VERIFICÁVEL: com o /SMask certo o MuPDF compõe as duas cores,
    e sem ele desenha a imagem opaca por cima.
    """
    dic, payload, extras = (xobject_png(dados_img)
                            if dados_img[:8] == b'\x89PNG\r\n\x1a\n'
                            else xobject(dados_img) + ({},))
    desenho = ''
    if fundo:
        r, g, b = (c / 255 for c in fundo)
        desenho += f'{r:.3f} {g:.3f} {b:.3f} rg 50 500 {larg_pt} {alt_pt} re f\n'
    desenho += f'q {larg_pt} 0 0 {alt_pt} 50 500 cm\n/Im1 Do\nQ\n'
    fluxo = desenho.encode()

    objs = {
        1: b'<</Type /Catalog /Pages 2 0 R>>',
        2: b'<</Type /Pages /Count 1 /Kids[3 0 R]>>',
        3: (b'<</Type /Page /Parent 2 0 R /MediaBox [0 0 595 842]'
            b' /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R>>'),
        4: b'<</Length %d>>stream\n' % len(fluxo) + fluxo + b'\nendstream',
    }
    if extras.get('smask'):
        # O PDF não tem alfa dentro do pixel: a transparência é um SEGUNDO
        # objeto de imagem, em /DeviceGray, apontado por /SMask.
        sdic, sdados = extras['smask']
        objs[6] = sdic.encode() + b'stream\n' + sdados + b'\nendstream'
        dic = dic.rstrip()[:-2] + ' /SMask 6 0 R >>'
    objs[5] = dic.encode() + b'stream\n' + payload + b'\nendstream'

    out = bytearray(b'%PDF-1.4\n')
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


def pdf_com_imagem_bruto(dic, payload, extras, larg_pt=200, alt_pt=200,
                         fundo=None):
    """Como pdf_com_imagem, mas recebendo o /XObject já resolvido.

    Serve para montar deliberadamente o caso ERRADO — a imagem com alfa e sem
    o /SMask — e provar que a checagem do caso certo distingue os dois.
    """
    desenho = ''
    if fundo:
        r, g, b = (c / 255 for c in fundo)
        desenho += f'{r:.3f} {g:.3f} {b:.3f} rg 50 500 {larg_pt} {alt_pt} re f\n'
    desenho += f'q {larg_pt} 0 0 {alt_pt} 50 500 cm\n/Im1 Do\nQ\n'
    fluxo = desenho.encode()
    objs = {
        1: b'<</Type /Catalog /Pages 2 0 R>>',
        2: b'<</Type /Pages /Count 1 /Kids[3 0 R]>>',
        3: (b'<</Type /Page /Parent 2 0 R /MediaBox [0 0 595 842]'
            b' /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R>>'),
        4: b'<</Length %d>>stream\n' % len(fluxo) + fluxo + b'\nendstream',
        5: dic.encode() + b'stream\n' + payload + b'\nendstream',
    }
    out = bytearray(b'%PDF-1.4\n')
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


def cor_no_centro(pdf):
    """Cor que o MuPDF desenha no centro de onde a imagem foi posta."""
    doc = pymupdf.open(stream=pdf, filetype='pdf')
    pix = doc[0].get_pixmap(dpi=72)
    px = pix.pixel(50 + 100, 842 - 500 - 100)
    n = len(doc[0].get_images(full=True))
    doc.close()
    return px, n


def perto(a, b, tol=12):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


def main():
    # ── PNG RGB ──────────────────────────────────────────────────────────────
    print('== PNG DeviceRGB')
    dados = png(4, 4, b'\x20\x90\xd0' * 16)
    check(dimensoes(dados) == (4, 4), f'dimensões lidas: {dimensoes(dados)}')
    px, n = cor_no_centro(pdf_com_imagem(dados))
    check(n == 1, f'MuPDF vê 1 imagem na página (viu {n})')
    check(perto(px[:3], (0x20, 0x90, 0xd0)),
          f'pixels corretos — Predictor 15 e DeviceRGB (leu {px[:3]})')

    # ── PNG cinza ────────────────────────────────────────────────────────────
    print('\n== PNG DeviceGray')
    dados = png(4, 4, b'\x40' * 16, ct=0)
    px, _ = cor_no_centro(pdf_com_imagem(dados))
    check(perto(px[:3], (0x40, 0x40, 0x40)), f'pixels corretos (leu {px[:3]})')

    # ── PNG indexado ─────────────────────────────────────────────────────────
    print('\n== PNG indexado (paleta)')
    paleta = b'\xff\x00\x00\x00\xff\x00\x00\x00\xff'      # vermelho, verde, azul
    dados = png(4, 4, b'\x01' * 16, ct=3, paleta=paleta)
    dic, _, _ = xobject_png(dados)
    check('/Indexed /DeviceRGB 2' in dic,
          f'/ColorSpace indexado com o índice máximo certo')
    px, _ = cor_no_centro(pdf_com_imagem(dados))
    check(perto(px[:3], (0x00, 0xff, 0x00)),
          f'a cor vem da paleta, índice 1 = verde (leu {px[:3]})')

    # ── JPEG ─────────────────────────────────────────────────────────────────
    print('\n== JPEG DeviceRGB')
    dados = jpeg(16, 16, (200, 40, 60))
    larg, alt, cs, bits = parse_jpeg(dados)
    check((larg, alt, cs, bits) == (16, 16, '/DeviceRGB', 8),
          f'SOF lido: {larg}x{alt} {cs} {bits} bits')
    px, n = cor_no_centro(pdf_com_imagem(dados))
    check(n == 1, f'MuPDF vê 1 imagem na página (viu {n})')
    check(perto(px[:3], (200, 40, 60), tol=20),
          f'pixels corretos — DCTDecode passa direto (leu {px[:3]})')

    # ── canal alfa: RGBA e cinza+alfa ────────────────────────────────────────
    #
    # O PDF não tem alfa dentro do pixel. A prova de que o /SMask está certo
    # não é "o arquivo tem dois objetos de imagem" — é o MuPDF COMPOR a imagem
    # com o fundo. Sem SMask a imagem sai opaca e o pixel é a cor dela; com
    # SMask errado sai transparente demais ou de menos.
    print('\n== PNG com canal alfa (o PDF exige /SMask)')
    FUNDO = (255, 255, 255)
    for modo, cor, alvo, rotulo in (
        ('RGBA', (200, 60, 40, 128), (228, 158, 148), 'RGBA (color type 6)'),
        ('LA', (100, 128), (178, 178, 178), 'cinza + alfa (color type 4)'),
    ):
        dados = png_pillow(modo, (8, 8), cor)
        dic, payload, extras = xobject_png(dados)
        check('smask' in extras, f'{rotulo}: gerou o objeto do /SMask')
        check('/Filter' not in dic,
              f'{rotulo}: sai sem compressão — não há deflate deste lado')
        px, n = cor_no_centro(pdf_com_imagem(dados, fundo=FUNDO))
        check(perto(px[:3], alvo),
              f'{rotulo}: composto com o fundo branco = {px[:3]}, '
              f'esperado ~{alvo}')

    # a mesma imagem SEM o /SMask tem de sair diferente — senão o teste acima
    # passaria mesmo com a transparência ignorada
    dados = png_pillow('RGBA', (8, 8), (200, 60, 40, 128))
    dic, payload, extras = xobject_png(dados)
    sem = dict(extras)
    sem.pop('smask')
    px_sem, _ = cor_no_centro(pdf_com_imagem_bruto(dic, payload, {},
                                                  fundo=FUNDO))
    check(not perto(px_sem[:3], (228, 158, 148)),
          f'sem o /SMask o pixel muda ({px_sem[:3]}) — a checagem acima morde')

    # ── entrelaçado (Adam7) ──────────────────────────────────────────────────
    print('\n== PNG entrelaçado (Adam7)')
    LARG = ALT = 16
    pixels = bytearray()
    for y in range(ALT):
        for x in range(LARG):
            pixels += bytes((220, 40, 40) if x < LARG // 2 else (40, 60, 220))
    entre = png_entrelacado(LARG, ALT, bytes(pixels))

    # 1. o fixture é um PNG entrelaçado de verdade? quem diz é o Pillow
    from PIL import Image
    img = Image.open(io.BytesIO(entre)).convert('RGB')
    check(img.tobytes() == bytes(pixels),
          'o Pillow lê o fixture entrelaçado com os pixels certos')

    # 2. o desentrelacar concorda com o Pillow, que é decodificador independente
    cru = zlib.decompress(b''.join(
        c for t, c in __import__('pdfimage_reference').blocos_png(entre)
        if t == b'IDAT'))
    check(desentrelacar(cru, LARG, ALT, 3, 8) == img.tobytes(),
          'desentrelacar devolve o mesmo raster que o Pillow')

    # 3. e o MuPDF desenha as duas metades no lugar certo
    pdf = pdf_com_imagem(entre)
    doc = pymupdf.open(stream=pdf, filetype='pdf')
    pix = doc[0].get_pixmap(dpi=72)
    esq = pix.pixel(50 + 50, 842 - 500 - 100)
    dir_ = pix.pixel(50 + 150, 842 - 500 - 100)
    doc.close()
    check(perto(esq[:3], (220, 40, 40)) and perto(dir_[:3], (40, 60, 220)),
          f'MuPDF desenha as metades no lugar: esquerda {esq[:3]}, '
          f'direita {dir_[:3]}')

    # ── 16 bits por componente ───────────────────────────────────────────────
    #
    # Este NÃO precisa de reprocessamento: o PDF aceita /BitsPerComponent 16, e
    # o predictor também. Era recusado por engano, junto com os outros dois.
    print('\n== PNG de 16 bits')
    dados = png_pillow('I;16', (8, 8), 40000)
    dic, payload, extras = xobject_png(dados)
    check('/BitsPerComponent 16' in dic and '/Filter /FlateDecode' in dic,
          'passa direto, comprimido, com 16 bits declarados')
    px, n = cor_no_centro(pdf_com_imagem(dados))
    cinza = round(40000 / 65535 * 255)
    check(perto(px[:3], (cinza, cinza, cinza)),
          f'MuPDF desenha o cinza certo: {px[:3]}, esperado ~{cinza}')

    # ── o que segue recusado ─────────────────────────────────────────────────
    print('\n== o que precisa ser recusado, e não desenhado errado')
    for rotulo, construir in (
        ('PNG entrelaçado com 4 bits',
         lambda: b'\x89PNG\r\n\x1a\n' + bloco_png(
             b'IHDR', struct.pack('>IIBBBBB', 2, 2, 4, 0, 0, 0, 1))
         + bloco_png(b'IDAT', zlib.compress(b'\x00\x00')) ),
        ('PNG indexado e entrelaçado',
         lambda: b'\x89PNG\r\n\x1a\n' + bloco_png(
             b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 3, 0, 0, 1))
         + bloco_png(b'PLTE', b'\xff\x00\x00')
         + bloco_png(b'IDAT', zlib.compress(b'\x00\x00\x00')) ),
        ('color type inexistente',
         lambda: b'\x89PNG\r\n\x1a\n' + bloco_png(
             b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 5, 0, 0, 0))),
        ('formato desconhecido', lambda: b'GIF89a' + b'\x00' * 20),
    ):
        try:
            xobject(construir())
            check(False, f'{rotulo}: deveria ser recusado')
        except (ValueError, zlib.error) as e:
            check(True, f'{rotulo}: recusado — {e}')

    print('\n' + ('TODOS OS TESTES PASSARAM' if not FALHAS else
                  f'{len(FALHAS)} FALHA(S):\n  ' + '\n  '.join(FALHAS)))
    return 1 if FALHAS else 0


if __name__ == '__main__':
    sys.exit(main())
