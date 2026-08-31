# -*- coding: utf-8 -*-
"""
Confere a régua do ingresso — e desenha por ela, para ver se o que sai fecha.

DOCUMENTO DE MANUTENÇÃO.

Quatro perguntas, nesta ordem:

1. **A régua é consistente sozinha?** Nenhum texto mais largo que a caixa que o
   abriga (métricas reais do Helvetica), painéis dentro da folha, e o texto
   claro só onde há fundo escuro por baixo.
2. **Quem desenha por ela produz o que ela diz?** O desenho de referência é
   feito em PyMuPDF com os MESMOS números, o PDF é lido de volta, e cada texto
   aparece com fonte, corpo, linha de base, alinhamento e **cor** previstos.
3. **Os símbolos são legíveis?** QR Code e Code 39, os dois com o mesmo
   conteúdo, lidos pelo zxing na página renderizada a 300 dpi.
4. **As duas páginas são diferentes?** Cada uma com o seu participante e o seu
   código — é o que separa "gerou duas páginas" de "gerou a mesma duas vezes".

O que passa aqui é o que o runner cobra do PDF que o BANCO gera: o mesmo módulo
confere os dois lados.

Uso:
    pip install pymupdf zxing-cpp pillow
    python scripts/ticket_reference/validate.py
    python scripts/ticket_reference/validate.py --png /tmp/ticket.png
"""
import sys

sys.path.insert(0, __file__.rsplit('/', 1)[0])
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/barcode_reference')
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/qr_reference')

import ticket_reference as tk    # noqa: E402
import barcode_reference as bc   # noqa: E402
import qr_reference as qr        # noqa: E402
from pdflayout import (MM, escrever, largura_do_texto, PAD_X,   # noqa: E402
                       cabe_antes_da_quebra, gatilho_de_quebra)

import pymupdf                   # noqa: E402

VIAS = [('Maria Aparecida de Souza', 'UDV2259QK5'),
        ('Joao Pedro Nogueira', 'PLF7731ZT2')]

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
def checar_regua():
    print('Régua: nada mais largo que a caixa, nada fora da folha')
    for participante, codigo in VIAS:
        for t in tk.textos(participante, codigo):
            util = t.w - 2 * PAD_X
            larg = largura_do_texto(t.texto, t.estilo, t.corpo)
            conf(larg <= util,
                 f'{t.texto[:26]!r}: {larg:.1f} <= {util:.1f} mm')

    for p in tk.paineis():
        conf(p.x >= tk.X0 - 1e-6 and p.x + p.w <= tk.XF + 1e-6,
             f'painel em y={p.y:.0f} dentro dos {tk.LARGURA:.0f} mm')
        conf(p.y + p.h <= 297.0 - 10.0,
             f'painel em y={p.y:.0f} cabe no A4')

    # texto claro só sobre fundo escuro: é o defeito que não dá erro nenhum
    escuros = [p for p in tk.paineis()
               if sum(p.cor) < 400]
    for t in tk.textos(*VIAS[0]):
        if t.cor != tk.BRANCO:
            continue
        sobre = [p for p in escuros
                 if p.x <= t.x and t.y >= p.y and t.y + t.h <= p.y + p.h]
        conf(bool(sobre), f'{t.texto[:26]!r} em branco, sobre painel escuro')

    # Nenhuma célula pode cruzar o gatilho da quebra automática: passar dele
    # não dá erro, abre PÁGINA NOVA. Foi assim que dois ingressos viraram seis
    # páginas, com o sintoma ('6 páginas, esperado 2') longe da causa.
    for t in tk.textos(*VIAS[0]):
        conf(cabe_antes_da_quebra(t.y, t.h),
             f'{t.texto[:26]!r}: {t.y + t.h:.1f} <= {gatilho_de_quebra():.0f} '
             f'mm (gatilho da quebra)')

    x, y, lado = tk.qr_rect()
    conf(x >= tk.X_QR and x + lado <= tk.X_QR + tk.LARG_QR,
         f'QR de {lado:.0f} mm dentro do painel da direita')
    bx, by, bw, bh = tk.barcode_rect()
    conf(bx >= tk.X0 and bx + bw <= tk.XF, f'Code 39 de {bw:.0f} mm na faixa')


# ───────────────────────── 2. desenhar pela régua ────────────────────────────
def _barras(pag, padrao, x, y, w, h):
    passo = w / len(padrao)
    i = 0
    while i < len(padrao):
        j = i
        while j < len(padrao) and padrao[j] == padrao[i]:
            j += 1
        if padrao[i] == '1':
            pag.draw_rect(pymupdf.Rect((x + i * passo) * MM, y * MM,
                                       (x + j * passo) * MM, (y + h) * MM),
                          color=None, fill=(0, 0, 0))
        i = j


def desenhar():
    doc = pymupdf.open()
    for participante, codigo in VIAS:
        pag = doc.new_page(width=210 * MM, height=297 * MM)

        for p in tk.paineis():
            pag.draw_rect(pymupdf.Rect(p.x * MM, p.y * MM,
                                       (p.x + p.w) * MM, (p.y + p.h) * MM),
                          color=None, fill=[c / 255 for c in p.cor])

        pag.draw_polyline([(x * MM, y * MM) for x, y in tk.rabinho()],
                          color=None, fill=[c / 255 for c in tk.CINZA_CLARO],
                          closePath=True)

        mx, my, mw, mh = tk.moldura_mensagem()
        pag.draw_rect(pymupdf.Rect(mx * MM, my * MM,
                                   (mx + mw) * MM, (my + mh) * MM),
                      color=[c / 255 for c in tk.CINZA], width=0.2 * MM)

        for t in tk.textos(participante, codigo):
            escrever(pag, t.x, t.y, t.w, t.h, t.texto, t.corpo, t.estilo,
                     t.alinhar, t.cor)

        # QR Code: a matriz vem da referência que o zxing já valida
        x, y, lado = tk.qr_rect()
        matriz, _versao, _mascara = qr.make_qr(codigo, ecl='M')
        n = len(matriz)
        modulo = lado / n
        for li in range(n):
            for co in range(n):
                if matriz[li][co]:
                    pag.draw_rect(
                        pymupdf.Rect((x + co * modulo) * MM,
                                     (y + li * modulo) * MM,
                                     (x + (co + 1) * modulo) * MM,
                                     (y + (li + 1) * modulo) * MM),
                        color=None, fill=(0, 0, 0))

        bx, by, bw, bh = tk.barcode_rect()
        _barras(pag, bc.code39(codigo), bx, by, bw, bh)
    return doc


def checar_desenho(doc):
    print('\nDesenho: painéis, cor do texto, corpo, linha de base, alinhamento')
    conf(doc.page_count == len(VIAS), f'{doc.page_count} página(s)')
    for i, (participante, codigo) in enumerate(VIAS):
        for passou, ok_msg, falha_msg in tk.conferir(doc[i], participante,
                                                     codigo):
            conf(passou, ok_msg if passou else falha_msg)


def checar_simbolos(doc):
    print('\nSímbolos: o QR e o Code 39 dizem a mesma coisa, e um leitor lê')
    try:
        import zxingcpp
        from PIL import Image
    except ImportError:
        conf(False, 'sem o leitor: pip install zxing-cpp pillow')
        return
    for i, (_, codigo) in enumerate(VIAS):
        pix = doc[i].get_pixmap(dpi=300)
        img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
        lidos = {(r.format.name, r.text) for r in zxingcpp.read_barcodes(img)}
        formatos = {f for f, _ in lidos}
        conf(('QRCode' in formatos or 'QR_CODE' in formatos)
             and any('39' in f for f in formatos),
             f'página {i + 1}: QR e Code 39 lidos ({sorted(formatos)})')
        conf({t for _, t in lidos} == {codigo},
             f'página {i + 1}: os dois símbolos dizem {codigo!r} '
             f'(lidos: {sorted(t for _, t in lidos)})')


def main():
    checar_regua()
    doc = desenhar()
    checar_desenho(doc)
    checar_simbolos(doc)
    for flag, metodo in (('--png', lambda d, alvo:
                          d[0].get_pixmap(dpi=150).save(alvo)),
                         ('--pdf', lambda d, alvo: d.save(alvo))):
        if flag in sys.argv:
            alvo = sys.argv[sys.argv.index(flag) + 1]
            metodo(doc, alvo)
            print(f'\nprévia: {alvo}')
    print(f'\n{ok} ok, {falhas} falha(s)')
    return 1 if falhas else 0


if __name__ == '__main__':
    raise SystemExit(main())
