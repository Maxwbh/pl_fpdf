# -*- coding: utf-8 -*-
"""
Confere a régua do boleto — e desenha por ela, para ver se o que sai fecha.

DOCUMENTO DE MANUTENÇÃO.

Três perguntas, nesta ordem:

1. **A régua é consistente sozinha?** Nenhum texto pode ser mais largo que a
   caixa que o abriga (métricas reais do Helvetica, não estimativa), nenhuma
   caixa pode invadir a vizinha, e tudo tem de caber na ficha e na folha.
2. **Quem desenha por ela produz o que ela diz?** O desenho de referência é
   feito em PyMuPDF a partir dos MESMOS números, o PDF é lido de volta, e cada
   valor tem de aparecer com a fonte, o corpo e o alinhamento previstos.
3. **O código de barras é legível?** Renderizado a 300 dpi e lido pelo zxing.

O que passa aqui é o que o runner cobra do PDF que o BANCO gera: o mesmo módulo
de régua confere os dois lados, então PL/SQL e referência não podem divergir em
silêncio.

Uso:
    pip install pymupdf zxing-cpp pillow
    python scripts/boleto_reference/validate.py
    python scripts/boleto_reference/validate.py --png /tmp/boleto.png
"""
import sys

sys.path.insert(0, __file__.rsplit('/', 1)[0])
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/barcode_reference')

import boleto_reference as bl    # noqa: E402
from pdflayout import cabe_antes_da_quebra, gatilho_de_quebra   # noqa: E402
import barcode_reference as bc   # noqa: E402

import pymupdf                   # noqa: E402

LINHA_DIGITAVEL = '34191.09008 00012.323077 31234.510001 7 16770000015000'
CODIGO = '34197167700000150001090000012323073123451000'
Y_RECIBO, Y_FICHA = 20.0, 138.0

ok = falhas = 0


def conf(cond, msg):
    global ok, falhas
    if cond:
        ok += 1
        print(f'  ok    {msg}')
    else:
        falhas += 1
        print(f'  FALHA {msg}')


# ───────────────────────── 1. a régua sozinha ────────────────────────────────
def checar_metricas():
    print('Régua: nada mais largo que a caixa que o abriga')
    for y0, completa in ((Y_RECIBO, False), (Y_FICHA, True)):
        for c in bl.campos(y0, completa):
            util = c.w - 2 * bl.PAD_X
            lr = bl.largura_do_texto(c.rotulo, '', bl.CORPO_ROTULO)
            conf(lr <= util,
                 f'rótulo {c.rotulo[:28]!r}: {lr:.1f} <= {util:.1f} mm')
            if c.valor:
                est = 'B' if c.negrito else ''
                lv = bl.largura_do_texto(c.valor, est, c.corpo)
                conf(lv <= util,
                     f'valor  {c.valor[:28]!r}: {lv:.1f} <= {util:.1f} mm')

    txt, _ = bl.cabecalho(Y_FICHA, LINHA_DIGITAVEL)
    for t in txt:
        lt = bl.largura_do_texto(t.texto, t.estilo, t.corpo)
        util = t.w - 2 * bl.PAD_X
        conf(lt <= util, f'cabeçalho {t.texto[:24]!r}: {lt:.1f} <= {util:.1f} mm')

    for t in bl.instrucoes(Y_FICHA) + [bl.endereco_pagador(Y_FICHA),
                                       bl.rodape(Y_FICHA, 'Ficha')]:
        lt = bl.largura_do_texto(t.texto, t.estilo, t.corpo)
        util = t.w - 2 * bl.PAD_X
        conf(lt <= util, f'miúdo {t.texto[:24]!r}: {lt:.1f} <= {util:.1f} mm')


def _sobrepoe(a, b):
    return not (a.x + a.w <= b.x + 1e-6 or b.x + b.w <= a.x + 1e-6
                or a.y + a.h <= b.y + 1e-6 or b.y + b.h <= a.y + 1e-6)


def checar_grade():
    print('\nGrade: caixas encostam, não se atropelam, e cabem na folha')
    for y0, completa in ((Y_RECIBO, False), (Y_FICHA, True)):
        cs = bl.campos(y0, completa)
        colidem = [(a.rotulo, b.rotulo) for i, a in enumerate(cs)
                   for b in cs[i + 1:] if _sobrepoe(a, b)]
        conf(not colidem, f'y0={y0:.0f}: nenhuma caixa sobre outra'
                          + (f' ({colidem[:2]})' if colidem else ''))
        conf(all(a.x >= bl.X0 - 1e-6
                 and a.x + a.w <= bl.X0 + bl.LARGURA + 1e-6 for a in cs),
             f'y0={y0:.0f}: todas as caixas dentro dos {bl.LARGURA:.0f} mm')
        # as linhas de campos miúdos têm de fechar exatamente a coluna esquerda
        for y in sorted({a.y for a in cs}):
            da_linha = [a for a in cs if a.y == y and a.x < bl.XD - 1e-6]
            if len(da_linha) > 1:
                soma = sum(a.w for a in da_linha)
                conf(abs(soma - bl.LARG_ESQ) < 1e-6,
                     f'y0={y0:.0f}: linha em y={y:.1f} soma {soma:.1f} mm')
        conf(all(abs(a.x - bl.XD) < 1e-6 for a in cs if a.x >= bl.XD - 1e-6),
             f'y0={y0:.0f}: a coluna de valores começa toda em x={bl.XD:.1f}')

    # Nenhuma célula pode cruzar o gatilho da quebra automática: passar dele
    # não dá erro, abre PÁGINA NOVA e escreve lá em cima.
    for y0, completa in ((Y_RECIBO, False), (Y_FICHA, True)):
        for c in bl.campos(y0, completa):
            conf(cabe_antes_da_quebra(c.y + bl.PAD_VALOR, bl.H_CEL_VALOR),
                 f'{c.rotulo[:24]!r}: antes do gatilho da quebra '
                 f'({gatilho_de_quebra():.0f} mm)')

    bx, by, bw, bh = bl.barcode_rect(Y_FICHA)
    conf((bw, bh) == (103.0, 13.0), f'código de barras {bw:.0f}x{bh:.0f} mm')
    conf(by + bh <= 297.0 - 10.0,
         f'a ficha inteira cabe em A4 (termina em {by + bh:.1f} mm)')
    conf(Y_RECIBO + bl.H_VIA < Y_FICHA,
         f'as duas vias não se encostam ({Y_RECIBO + bl.H_VIA:.1f} < {Y_FICHA})')


# ───────────────────────── 2. desenhar pela régua ────────────────────────────
def _texto(pag, x, y, w, h, texto, corpo, estilo, alinhar):
    """Escreve como a `Cell` do PL_FPDF escreve.

    Mesma margem interna (1 mm dos dois lados) e mesma linha de base
    (`y + 0,5*h + 0,3*corpo`). Se este desenho e o do banco divergirem, é
    porque o PL/SQL saiu da régua — não porque os dois modelos diferem.
    """
    if not texto:
        return
    larg = bl.largura_do_texto(texto, estilo, corpo)
    if alinhar == 'R':
        dx = w - bl.PAD_X - larg
    elif alinhar == 'C':
        dx = (w - larg) / 2
    else:
        dx = bl.PAD_X
    pag.insert_text(((x + dx) * bl.MM, bl.linha_base(y, h, corpo) * bl.MM),
                    texto, fontname=bl.FITZ_FONT[estilo], fontsize=corpo)


def desenhar():
    doc = pymupdf.open()
    pag = doc.new_page(width=210 * bl.MM, height=297 * bl.MM)

    for y0, completa, rot in ((Y_RECIBO, False, 'Recibo do Pagador'),
                              (Y_FICHA, True, 'Ficha de Compensacao')):
        textos, reguas = bl.cabecalho(y0, LINHA_DIGITAVEL)
        for t in textos:
            _texto(pag, t.x, t.y, t.w, t.h, t.texto, t.corpo, t.estilo,
                   t.alinhar)
        for r in reguas:
            pag.draw_line((r.x1 * bl.MM, r.y1 * bl.MM),
                          (r.x2 * bl.MM, r.y2 * bl.MM),
                          width=r.espessura * bl.MM)

        for c in bl.campos(y0, completa):
            pag.draw_rect(pymupdf.Rect(c.x * bl.MM, c.y * bl.MM,
                                       (c.x + c.w) * bl.MM,
                                       (c.y + c.h) * bl.MM),
                          width=0.2 * bl.MM)
            _texto(pag, c.x, c.y + bl.PAD_ROTULO, c.w, bl.H_CEL_ROTULO,
                   c.rotulo, bl.CORPO_ROTULO, '', 'L')
            _texto(pag, c.x, c.y + bl.PAD_VALOR, c.w, bl.H_CEL_VALOR,
                   c.valor, c.corpo, 'B' if c.negrito else '', c.alinhar)

        if completa:
            for t in bl.instrucoes(y0):
                _texto(pag, t.x, t.y, t.w, t.h, t.texto, t.corpo, t.estilo,
                       t.alinhar)
        for t in (bl.endereco_pagador(y0), bl.rodape(y0, rot)):
            _texto(pag, t.x, t.y, t.w, t.h, t.texto, t.corpo, t.estilo,
                   t.alinhar)

    # linha de corte entre as vias
    ycorte = (Y_RECIBO + bl.H_VIA + Y_FICHA) / 2
    for i in range(44):
        x = bl.X0 + i * 4.0
        pag.draw_line((x * bl.MM, ycorte * bl.MM),
                      ((x + 2.4) * bl.MM, ycorte * bl.MM), width=0.2 * bl.MM)

    # código de barras: as barras da mesma referência que o zxing já valida
    bx, by, bw, bh = bl.barcode_rect(Y_FICHA)
    padrao = bc.itf(CODIGO)
    passo = bw / len(padrao)
    i = 0
    while i < len(padrao):
        j = i
        while j < len(padrao) and padrao[j] == padrao[i]:
            j += 1
        if padrao[i] == '1':
            pag.draw_rect(pymupdf.Rect((bx + i * passo) * bl.MM, by * bl.MM,
                                       (bx + j * passo) * bl.MM,
                                       (by + bh) * bl.MM),
                          color=None, fill=(0, 0, 0))
        i = j
    return doc


def checar_desenho(doc):
    """A conferência é a MESMA que o runner aplica ao PDF do banco."""
    print('\nDesenho: fonte, corpo, linha de base, alinhamento e empilhamento')
    for passou, ok_msg, falha_msg in bl.conferir(doc[0], Y_RECIBO, Y_FICHA,
                                                 LINHA_DIGITAVEL):
        conf(passou, ok_msg if passou else falha_msg)


def checar_barras(doc):
    print('\nCódigo de barras: um leitor externo lê os 44 dígitos')
    try:
        import zxingcpp
        from PIL import Image
    except ImportError:
        conf(False, 'sem o leitor: pip install zxing-cpp pillow')
        return
    pix = doc[0].get_pixmap(dpi=300)
    img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
    lidos = {r.text for r in zxingcpp.read_barcodes(img)}
    conf(CODIGO in lidos, f'zxing leu {CODIGO} (leu: {sorted(lidos)})')


def main():
    checar_metricas()
    checar_grade()
    doc = desenhar()
    checar_desenho(doc)
    checar_barras(doc)
    if '--png' in sys.argv:
        destino = sys.argv[sys.argv.index('--png') + 1]
        doc[0].get_pixmap(dpi=150).save(destino)
        print(f'\nprévia: {destino}')
    if '--pdf' in sys.argv:
        destino = sys.argv[sys.argv.index('--pdf') + 1]
        doc.save(destino)
        print(f'prévia: {destino}')
    print(f'\n{ok} ok, {falhas} falha(s)')
    return 1 if falhas else 0


if __name__ == '__main__':
    raise SystemExit(main())
