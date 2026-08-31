# -*- coding: utf-8 -*-
"""O modelo de posicionamento do PL_FPDF, e como conferi-lo num PDF pronto.

DOCUMENTO DE MANUTENÇÃO. Não é documentação da biblioteca.

Por que existe
--------------
"Tem o texto certo" não é "está desenhado certo". Um formulário tem hierarquia
— rótulo miúdo, valor maior, o que decide em negrito, a coluna do dinheiro à
direita — e nada disso aparece em `get_text()`. Texto que transborda a caixa,
corpo trocado, coluna desalinhada e dois textos empilhados passam por qualquer
verificação de conteúdo.

Este módulo guarda o que vale para QUALQUER régua de layout desta base:

* como a `Cell` do PL_FPDF posiciona texto — margem interna de 1 mm nos dois
  lados e linha de base em `y + 0,5*altura + 0,3*corpo`;
* as métricas reais do Helvetica, para saber se um texto cabe na caixa;
* a conferência de um texto num PDF já pronto: existe, é único dentro da caixa,
  com a fonte, o corpo, a linha de base e o alinhamento previstos;
* a detecção de empilhamento, que é o defeito que a largura não pega.

Cada régua (`boleto_reference`, `ticket_reference`) descreve só a SUA geometria
e usa isto para conferir. É o mesmo código que confere o desenho de referência
e o PDF que sai do banco — não há duas listas de expectativas para divergirem.
"""

MM = 72.0 / 25.4              # milímetro -> ponto PostScript

# ── como o PL_FPDF posiciona texto ───────────────────────────────────────────
# A `Cell` tem margem interna de 1 mm (cMargin) nos dois lados: o texto à
# esquerda começa 1 mm depois da borda, e o alinhado à direita termina 1 mm
# antes dela. Por isso as réguas usam a caixa INTEIRA como largura da célula —
# o recuo vem de graça, e é o mesmo dos dois lados.
PAD_X = 1.0

# O que o PL_FPDF escreve como /BaseFont para cada variante de 'Arial'. É o
# nome que o MuPDF devolve no span, e é por ele que se confere o peso.
BASE_FONT = {'': 'Helvetica', 'B': 'Helvetica-Bold', 'I': 'Helvetica-Oblique',
             'BI': 'Helvetica-BoldOblique'}
FITZ_FONT = {'': 'helv', 'B': 'hebo', 'I': 'heit', 'BI': 'hebi'}


# ── a quebra automática de página ────────────────────────────────────────────
# O PL_FPDF liga a quebra automática com margem inferior de 20 mm, e a `Cell`
# quebra quando `y + altura > altura_da_pagina - 20`. Passar disso não é erro:
# a Cell abre uma PÁGINA NOVA e escreve lá em cima. Um rodapé posicionado 1 mm
# abaixo do gatilho transforma um documento de duas páginas num de seis, e o
# sintoma aparece longe da causa — "6 páginas, esperado 2".
MARGEM_INFERIOR = 20.0


def gatilho_de_quebra(altura_pagina=297.0):
    return altura_pagina - MARGEM_INFERIOR


def cabe_antes_da_quebra(y_topo, h_celula, altura_pagina=297.0):
    return y_topo + h_celula <= gatilho_de_quebra(altura_pagina)


def linha_base(y_topo, h_celula, corpo):
    """Onde a `Cell` põe a linha de base: y + 0,5*altura + 0,3*corpo.

    É a regra do FPDF, e o PL_FPDF a segue à risca. Ter isto aqui é o que
    permite conferir a POSIÇÃO do texto no PDF que o banco gerou, e não apenas
    que o texto existe.
    """
    return y_topo + 0.5 * h_celula + 0.3 * corpo / MM


def largura_do_texto(texto, estilo, corpo):
    """Largura em mm que o texto ocupa, pelas métricas reais do Helvetica."""
    import pymupdf
    return pymupdf.get_text_length(texto, fontname=FITZ_FONT[estilo],
                                   fontsize=corpo) / MM


def deslocamento(largura_caixa, largura_texto, alinhar):
    """Quanto a `Cell` desloca o texto dentro da caixa, conforme o alinhamento."""
    if alinhar == 'R':
        return largura_caixa - PAD_X - largura_texto
    if alinhar == 'C':
        return (largura_caixa - largura_texto) / 2
    return PAD_X


def escrever(pagina, x, y, w, h, texto, corpo, estilo='', alinhar='L',
             cor=(0, 0, 0)):
    """Escreve como a `Cell` do PL_FPDF escreve — mesma margem, mesma base.

    Se este desenho e o do banco divergirem, é porque o PL/SQL saiu da régua,
    não porque os dois modelos diferem.
    """
    if not texto:
        return
    dx = deslocamento(w, largura_do_texto(texto, estilo, corpo), alinhar)
    pagina.insert_text(((x + dx) * MM, linha_base(y, h, corpo) * MM), texto,
                       fontname=FITZ_FONT[estilo], fontsize=corpo,
                       color=[c / 255 for c in cor])


# ── conferência de um PDF pronto ─────────────────────────────────────────────
def spans_da_pagina(pagina):
    for b in pagina.get_text('dict')['blocks']:
        for l in b.get('lines', []):
            for s in l['spans']:
                if s['text'].strip():
                    yield s


def dentro(span, x, y, w, h, folga=0.7):
    """O span está dentro da caixa? (tudo em mm)"""
    x0, y0, x1, y1 = (v / MM for v in span['bbox'])
    return (x - folga <= x0 and x1 <= x + w + folga
            and y - folga <= y0 and y1 <= y + h + folga)


def confere_texto(spans, texto, x, y_topo, w, h_cel, corpo, estilo, alinhar,
                  caixa, onde, cor=None):
    """Gera (passou, ok, falha) de um texto: existe, único na caixa, e com a
    fonte, o corpo, a linha de base, o alinhamento — e a cor — previstos."""
    achados = [s for s in spans
               if s['text'].strip() == texto and dentro(s, *caixa)]
    yield (len(achados) == 1,
           f'{onde}: {texto[:26]!r} desenhado uma vez na caixa',
           f'{onde}: {texto[:26]!r} apareceu {len(achados)}x na caixa')
    if len(achados) != 1:
        return
    s = achados[0]
    yield (s['font'] == BASE_FONT[estilo],
           f'{onde}: fonte {BASE_FONT[estilo]}',
           f'{onde}: fonte {s["font"]}, esperada {BASE_FONT[estilo]}')
    yield (abs(s['size'] - corpo) < 0.05,
           f'{onde}: corpo {corpo:g}pt',
           f'{onde}: corpo {s["size"]:.1f}pt, esperado {corpo:g}pt')
    base = linha_base(y_topo, h_cel, corpo)
    yield (abs(s['origin'][1] / MM - base) < 0.25,
           f'{onde}: linha de base em {base:.1f} mm',
           f'{onde}: linha de base em {s["origin"][1] / MM:.1f} mm, '
           f'esperada {base:.1f}')
    x0, x1 = s['bbox'][0] / MM, s['bbox'][2] / MM
    if alinhar == 'R':
        yield (abs(x1 - (x + w - PAD_X)) < 0.6,
               f'{onde}: encosta à direita',
               f'{onde}: termina em {x1:.1f} mm, esperado {x + w - PAD_X:.1f}')
    elif alinhar == 'C':
        centro_texto, centro_caixa = (x0 + x1) / 2, x + w / 2
        yield (abs(centro_texto - centro_caixa) < 0.8,
               f'{onde}: centralizado na caixa',
               f'{onde}: centro em {centro_texto:.1f} mm, esperado '
               f'{centro_caixa:.1f}')
    else:
        yield (abs(x0 - (x + PAD_X)) < 0.6,
               f'{onde}: encosta à esquerda',
               f'{onde}: começa em {x0:.1f} mm, esperado {x + PAD_X:.1f}')
    if cor is not None:
        # o span traz a cor como inteiro 0xRRGGBB
        rgb = ((s['color'] >> 16) & 255, (s['color'] >> 8) & 255,
               s['color'] & 255)
        yield (max(abs(a - b) for a, b in zip(rgb, cor)) <= 2,
               f'{onde}: cor {rgb}',
               f'{onde}: cor {rgb}, esperada {tuple(cor)} — texto claro sobre '
               f'fundo claro some, e nada acusa')


def sem_empilhamento(spans, minimo=0.8):
    """(passou, ok, falha) — nenhum texto desenhado por cima de outro.

    Conferir só a LARGURA deixa passar o empilhamento: dois textos cabem nas
    suas caixas e ainda assim saem um sobre o outro. Comparar as CAIXAS também
    não serve — a caixa de um span vai do ascendente ao descendente da fonte, e
    duas linhas legítimas se tocam nas bordas. O que decide é a distância entre
    as linhas de base.
    """
    piores = []
    for i, a in enumerate(spans):
        for b in spans[i + 1:]:
            largura = (min(a['bbox'][2], b['bbox'][2])
                       - max(a['bbox'][0], b['bbox'][0]))
            if largura <= 1.0:
                continue
            folga = abs(a['origin'][1] - b['origin'][1])
            if folga < minimo * max(a['size'], b['size']):
                piores.append((a['text'][:18], b['text'][:18],
                               f'{folga:.1f}pt'))
    return (not piores,
            f'{len(spans)} textos, nenhum empilhado sobre outro',
            f'textos empilhados: {piores[:3]}')


def confere_preenchimento(pagina, x, y, w, h, cor, onde, folga=0.6):
    """(passou, ok, falha) — há um retângulo preenchido daquela cor ali?

    Cor de fundo não aparece em `get_text()` nem na contagem de operadores: um
    painel que saiu branco continua "desenhado". O que revela é o `fill` do
    desenho, comparado com a caixa esperada.
    """
    achados = []
    for dr in pagina.get_drawings():
        f = dr.get('fill')
        if not f:
            continue
        r = dr['rect']
        cx, cy = r.x0 / MM, r.y0 / MM
        cw, ch = r.width / MM, r.height / MM
        if (abs(cx - x) < folga and abs(cy - y) < folga
                and abs(cw - w) < folga and abs(ch - h) < folga):
            achados.append(tuple(round(c * 255) for c in f))
    if not achados:
        return (False, '', f'{onde}: nenhum preenchimento em '
                           f'({x:.1f}, {y:.1f}) {w:.1f}x{h:.1f} mm')
    perto = [a for a in achados
             if max(abs(p - q) for p, q in zip(a, cor)) <= 2]
    return (bool(perto),
            f'{onde}: painel {tuple(cor)} em ({x:.1f}, {y:.1f})',
            f'{onde}: painel em ({x:.1f}, {y:.1f}) saiu {achados[0]}, '
            f'esperado {tuple(cor)}')
