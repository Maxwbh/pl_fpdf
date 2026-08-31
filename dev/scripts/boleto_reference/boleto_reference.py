# -*- coding: utf-8 -*-
"""Layout da ficha de compensação — a régua do desenho, em milímetros.

DOCUMENTO DE MANUTENÇÃO. Não é documentação da biblioteca.

Por que existe
--------------
"Tem o texto certo" não é o mesmo que "está desenhado certo". Um boleto tem
hierarquia — rótulo miúdo, valor maior, o que decide em negrito, a coluna do
dinheiro alinhada à direita — e nada disso aparece em `get_text()`. Valor que
transborda a caixa, rótulo que invade o campo vizinho e coluna desalinhada
passam por qualquer verificação de conteúdo.

Este módulo é a **fonte da verdade da geometria**: as caixas, os corpos de
fonte, os pesos e os alinhamentos. Ele é conferido sozinho (`validate.py`) com
as métricas reais do Helvetica — nenhum texto pode ser mais largo que a caixa
que o abriga — e é o mesmo módulo que o runner usa para conferir, campo a
campo, o PDF que o BANCO gerou. Assim o número mora num lugar só: se o PL/SQL
divergir da régua, o runner acusa.

As medidas seguem a ficha de compensação da FEBRABAN: 177 mm de largura, coluna
de valores com 40 mm à direita, e o código de barras com 103 x 13 mm.
"""
import os
import sys
from collections import namedtuple

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pdflayout import (MM, PAD_X, BASE_FONT, FITZ_FONT,   # noqa: F401,E402
                       linha_base, largura_do_texto, escrever,
                       spans_da_pagina, dentro, confere_texto,
                       sem_empilhamento)

# ── a folha e a ficha ────────────────────────────────────────────────────────
LARGURA_PAGINA = 210.0
LARGURA = 177.0                     # largura da ficha (FEBRABAN)
X0 = round((LARGURA_PAGINA - LARGURA) / 2, 1)    # 16.5 — centralizada em A4
COL_DIR = 40.0                      # coluna de valores, à direita
XD = X0 + LARGURA - COL_DIR         # onde ela começa
LARG_ESQ = LARGURA - COL_DIR        # 137

# ── corpos de fonte ──────────────────────────────────────────────────────────
# Um boleto de verdade tem três tamanhos e não mais: o rótulo, o valor e a
# linha digitável. O que foge disso é o cabeçalho do banco.
CORPO_ROTULO = 6.0
CORPO_VALOR = 9.0
CORPO_LINHA_DIG = 11.0
CORPO_LOGO = 15.0
CORPO_CODIGO = 13.0
CORPO_MIUDO = 7.0                   # endereço do pagador, instruções, rodapé

# ── alturas ──────────────────────────────────────────────────────────────────
H_CABECALHO = 8.0
H_LINHA = 8.0
H_INSTRUCOES = 28.0
H_PAGADOR = 11.0   # dois textos empilhados: nome em 9pt e endereço em 7pt
H_RODAPE = 5.0
H_VIA = H_CABECALHO + 4 * H_LINHA + H_INSTRUCOES + H_PAGADOR + H_LINHA + H_RODAPE

# ── código de barras (FEBRABAN: 103 x 13 mm) ─────────────────────────────────
BC_LARGURA = 103.0
BC_ALTURA = 13.0
BC_FOLGA = 3.0                      # respiro entre o rodapé da via e o símbolo

# ── como o PL_FPDF posiciona texto ───────────────────────────────────────────
# A `Cell` tem margem interna de 1 mm (cMargin) nos dois lados: o texto à
# esquerda começa 1 mm depois da borda, e o alinhado à direita termina 1 mm
# antes dela. Por isso a régua usa a caixa INTEIRA como largura da célula — o
# recuo vem de graça, e é o mesmo dos dois lados.
PAD_ROTULO = 0.7                    # topo da célula do rótulo, dentro da caixa
PAD_VALOR = 3.2                     # topo da célula do valor
H_CEL_ROTULO = 2.4
H_CEL_VALOR = 3.4
H_CEL_MIUDO = 3.0


Campo = namedtuple('Campo', 'x y w h rotulo valor corpo negrito alinhar')
Texto = namedtuple('Texto', 'x y w h texto corpo estilo alinhar')
Regua = namedtuple('Regua', 'x1 y1 x2 y2 espessura')


def _c(x, y, w, h, rotulo, valor, negrito=False, alinhar='L',
       corpo=CORPO_VALOR):
    return Campo(x, y, w, h, rotulo, valor, corpo, negrito, alinhar)


def campos(y0, completa=True):
    """Os campos de uma via, com as coordenadas já absolutas.

    `completa` é a ficha de compensação (com instruções e código de barras);
    False é o recibo do pagador, que tem a mesma grade e a caixa de instruções
    vazia — é assim no boleto de verdade.
    """
    y = y0 + H_CABECALHO
    fora = []

    # linha 1 — local de pagamento | vencimento
    fora += [
        _c(X0, y, LARG_ESQ, H_LINHA, 'Local de pagamento',
           'Ate o vencimento, pagavel em qualquer banco'),
        _c(XD, y, COL_DIR, H_LINHA, 'Vencimento', '31/12/2026',
           negrito=True, alinhar='R'),
    ]
    y += H_LINHA

    # linha 2 — beneficiário | agência/código
    fora += [
        _c(X0, y, LARG_ESQ, H_LINHA, 'Beneficiario',
           'M&S DO BRASIL LTDA - 05.230.380/0001-74'),
        _c(XD, y, COL_DIR, H_LINHA, 'Agencia/Codigo beneficiario',
           '3073 / 12345-1', alinhar='R'),
    ]
    y += H_LINHA

    # linha 3 — cinco campos miúdos | nosso número
    larguras3 = [(26.0, 'Data do documento', '01/12/2026'),
                 (34.0, 'N. do documento', '000000123'),
                 (20.0, 'Especie doc.', 'DM'),
                 (14.0, 'Aceite', 'N'),
                 (43.0, 'Data do processamento', '01/12/2026')]
    x = X0
    for w, rot, val in larguras3:
        fora.append(_c(x, y, w, H_LINHA, rot, val))
        x += w
    fora.append(_c(XD, y, COL_DIR, H_LINHA, 'Nosso numero',
                   '109/00000123-2', alinhar='R'))
    y += H_LINHA

    # linha 4 — uso do banco ... valor | (=) valor do documento
    larguras4 = [(26.0, 'Uso do banco', ''),
                 (20.0, 'Carteira', '109'),
                 (16.0, 'Especie', 'R$'),
                 (30.0, 'Quantidade', '1'),
                 (45.0, 'Valor', '150,00')]
    x = X0
    for w, rot, val in larguras4:
        fora.append(_c(x, y, w, H_LINHA, rot, val))
        x += w
    fora.append(_c(XD, y, COL_DIR, H_LINHA, '(=) Valor do documento',
                   '150,00', negrito=True, alinhar='R'))
    y += H_LINHA

    # linha 5 — instruções (caixa alta) | cinco campos de acréscimo/desconto
    fora.append(_c(X0, y, LARG_ESQ, H_INSTRUCOES,
                   'Instrucoes (Texto de responsabilidade do beneficiario)',
                   ''))
    h5 = H_INSTRUCOES / 5
    for i, rot in enumerate(['(-) Desconto / Abatimento',
                             '(-) Outras deducoes',
                             '(+) Mora / Multa',
                             '(+) Outros acrescimos',
                             '(=) Valor cobrado']):
        fora.append(_c(XD, y + i * h5, COL_DIR, h5, rot, '', alinhar='R'))
    y += H_INSTRUCOES

    # linha 6 — pagador (largura inteira)
    fora.append(_c(X0, y, LARGURA, H_PAGADOR, 'Pagador',
                   'Joao da Silva - 529.982.247-25', negrito=True))
    y += H_PAGADOR

    # linha 7 — sacador/avalista | código de baixa
    fora += [
        _c(X0, y, LARG_ESQ, H_LINHA, 'Sacador/Avalista', ''),
        _c(XD, y, COL_DIR, H_LINHA, 'Codigo de baixa', '', alinhar='R'),
    ]
    return fora


def instrucoes(y0):
    """As três linhas dentro da caixa de instruções, em itálico."""
    y = y0 + H_CABECALHO + 4 * H_LINHA
    linhas = ['Apos o vencimento cobrar multa de 2%',
              'Juros de mora de 1% ao mes',
              'Nao receber apos 30 dias do vencimento']
    return [Texto(X0, y + PAD_VALOR + 0.8 + i * 4.0, LARG_ESQ, H_CEL_MIUDO,
                  t, CORPO_MIUDO, 'I', 'L')
            for i, t in enumerate(linhas)]


def cabecalho(y0, linha_digitavel):
    """Logo, código do banco e linha digitável — mais as réguas que os separam.

    O cabeçalho é o único lugar com corpo grande, e a linha digitável é o
    texto mais largo da ficha: se ela couber, o resto cabe.
    """
    x_barra1, x_barra2 = X0 + 26.0, X0 + 46.0
    h = H_CABECALHO - 1.0
    textos = [
        Texto(X0, y0, 26.0, h, 'Itau', CORPO_LOGO, 'B', 'L'),
        Texto(x_barra1, y0, 20.0, h, '341-7', CORPO_CODIGO, 'B', 'C'),
        Texto(x_barra2, y0, X0 + LARGURA - x_barra2, h,
              linha_digitavel, CORPO_LINHA_DIG, 'B', 'R'),
    ]
    reguas = [
        Regua(x_barra1, y0, x_barra1, y0 + H_CABECALHO - 1.0, 0.5),
        Regua(x_barra2, y0, x_barra2, y0 + H_CABECALHO - 1.0, 0.5),
        Regua(X0, y0 + H_CABECALHO - 0.5, X0 + LARGURA,
              y0 + H_CABECALHO - 0.5, 0.5),
    ]
    return textos, reguas


def rodape(y0, rotulo):
    """A autenticação mecânica, alinhada à direita, embaixo da via."""
    y = y0 + H_VIA - H_RODAPE + 0.5
    return Texto(X0, y, LARGURA, H_CEL_MIUDO,
                 'Autenticacao mecanica - ' + rotulo, CORPO_MIUDO, 'I', 'R')


def barcode_rect(y0):
    """(x, y, largura, altura) do código de barras da ficha, em mm."""
    return (X0, y0 + H_VIA + BC_FOLGA, BC_LARGURA, BC_ALTURA)


def endereco_pagador(y0):
    """A segunda linha da caixa do pagador — endereço, miúdo, sob o nome."""
    y = y0 + H_CABECALHO + 4 * H_LINHA + H_INSTRUCOES
    # 6.6 mm abaixo do topo da caixa, e não 5.5: a linha de base do nome fica
    # em 6.4, e menos que isso empilha o endereço por cima dele — foi o que a
    # checagem de colisão pegou
    return Texto(X0, y + 6.6, LARGURA, H_CEL_MIUDO,
                 'Rua das Flores, 100 - Sete Lagoas/MG - 35700-000',
                 CORPO_MIUDO, '', 'L')


# ── conferência do desenho ───────────────────────────────────────────────────
# A MESMA função confere o PDF de referência (validate.py) e o PDF que o banco
# gerou (scripts/run_tests.py). É isso que impede o PL/SQL de sair da régua sem
# ninguém perceber: não há dois conjuntos de expectativas para divergirem.

def conferir(pagina, y_recibo, y_ficha, linha_digitavel):
    """Confere uma página inteira contra a régua. Gera (passou, ok, falha)."""
    spans = list(spans_da_pagina(pagina))

    fontes = {s['font'] for s in spans}
    # o boleto usa três variantes e só elas — negrito-itálico não aparece
    esperadas = {BASE_FONT[''], BASE_FONT['B'], BASE_FONT['I']}
    yield (fontes == esperadas,
           f'as três variantes do Helvetica, e só elas: {sorted(fontes)}',
           f'fontes na página: {sorted(fontes)}, esperadas '
           f'{sorted(esperadas)}')

    previstos = sorted({CORPO_ROTULO, CORPO_VALOR, CORPO_MIUDO,
                        CORPO_LINHA_DIG, CORPO_LOGO, CORPO_CODIGO})
    corpos = sorted({round(s['size'], 1) for s in spans})
    yield (corpos == previstos,
           f'só os corpos previstos: {corpos}',
           f'corpos na página: {corpos}, previstos {previstos}')

    for y0, completa, rot in ((y_recibo, False, 'Recibo do Pagador'),
                              (y_ficha, True, 'Ficha de Compensacao')):
        via = 'ficha' if completa else 'recibo'
        for c in campos(y0, completa):
            caixa = (c.x, c.y, c.w, c.h)
            onde = f'{via}/{c.rotulo[:22]}'
            yield from confere_texto(spans, c.rotulo, c.x, c.y + PAD_ROTULO,
                                     c.w, H_CEL_ROTULO, CORPO_ROTULO, '',
                                     'L', caixa, onde + ' [rotulo]')
            if c.valor:
                yield from confere_texto(
                    spans, c.valor, c.x, c.y + PAD_VALOR, c.w, H_CEL_VALOR,
                    c.corpo, 'B' if c.negrito else '', c.alinhar, caixa,
                    onde + ' [valor]')

        textos, _ = cabecalho(y0, linha_digitavel)
        miudos = [endereco_pagador(y0), rodape(y0, rot)]
        if completa:
            miudos += instrucoes(y0)
        for t in textos + miudos:
            yield from confere_texto(
                spans, t.texto, t.x, t.y, t.w, t.h, t.corpo, t.estilo,
                t.alinhar, (t.x, t.y - 1.0, t.w, t.h + 2.0),
                f'{via}/{t.texto[:22]}')

    yield sem_empilhamento(spans)
