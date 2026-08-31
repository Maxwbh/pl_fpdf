# -*- coding: utf-8 -*-
"""Layout de um ingresso de evento — a régua do desenho, em milímetros.

DOCUMENTO DE MANUTENÇÃO. Não é documentação da biblioteca.

Por que existe, e por que não basta o boleto
--------------------------------------------
O boleto prova grade: 50 caixas ao milímetro, três variantes de Helvetica,
alinhamento. Ele é **preto no branco**, tem **uma página** e um código de
barras só. Um ingresso exercita o que ficou de fora:

* **cor** — faixa de cabeçalho preenchida, texto branco sobre ela, painéis
  cinzas com miolo branco. Um painel que saiu branco continua "desenhado", e
  texto claro sobre fundo claro some sem que nada acuse;
* **QR Code e Code 39 na mesma página**, os dois com o mesmo conteúdo, cada um
  lido por um decodificador externo;
* **mais de uma página**, cada uma com o seu participante e o seu código;
* **forma fora do retângulo** — o rabinho do balão, desenhado com `Poly`;

Como no boleto, esta régua é a fonte da verdade da geometria e a **mesma**
função `conferir()` é aplicada ao desenho de referência e ao PDF que sai do
banco. Se o PL/SQL sair da régua, a rodada acusa qual elemento e quanto desviou.

O que ela NÃO faz: regra de negócio. O código do ingresso chega pronto, como
qualquer outro dado que o chamador passa.
"""
import os
import sys
from collections import namedtuple

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pdflayout import (MM, PAD_X, BASE_FONT, FITZ_FONT,   # noqa: F401,E402
                       linha_base, largura_do_texto, escrever,
                       spans_da_pagina, dentro, confere_texto,
                       sem_empilhamento, confere_preenchimento,
                       cabe_antes_da_quebra, gatilho_de_quebra)

# ── a folha ──────────────────────────────────────────────────────────────────
X0, LARGURA = 12.0, 186.0           # margem de 12 mm num A4
XF = X0 + LARGURA                   # 198

# ── paleta ───────────────────────────────────────────────────────────────────
# As cores do próprio projeto: o azul-marinho do banner e o laranja da marca.
AZUL = (13, 25, 44)
LARANJA = (232, 80, 58)
CINZA = (216, 216, 216)             # moldura dos painéis
CINZA_CLARO = (240, 241, 241)       # balão de aviso
BRANCO = (255, 255, 255)
PRETO = (0, 0, 0)
GRAFITE = (68, 68, 68)

# ── corpos ───────────────────────────────────────────────────────────────────
CORPO_TITULO = 17.0
CORPO_LINHA = 8.0
CORPO_MIUDO = 7.0
CORPO_ROTULO = 10.0                 # 'Ingresso', 'Participante'
CORPO_DESTAQUE = 14.0               # lote e preço
CORPO_NOME = 16.0
CORPO_CODIGO = 12.0

# alturas de célula (o texto é posicionado como a `Cell` posiciona)
H_CEL = 5.0
H_CEL_MIUDO = 4.0
H_CEL_TITULO = 9.0
H_CEL_NOME = 7.0        # 16 pt não cabe numa célula de 5: a caixa do span vai
                        # do ascendente ao descendente da fonte, e estoura

# ── blocos ───────────────────────────────────────────────────────────────────
Y_CAB, H_CAB = 13.5, 36.0           # faixa colorida
Y_PAINEL = 52.0
H_INGRESSO = 32.0
LARG_ESQ = 130.0                    # painéis da esquerda
X_QR = X0 + LARG_ESQ + 4.0          # 146
LARG_QR = XF - X_QR                 # 52
H_QR = 57.5
Y_PARTICIPANTE = Y_PAINEL + H_INGRESSO + 3.0     # 87
H_PARTICIPANTE = 22.5
Y_BARRAS = Y_PARTICIPANTE + H_PARTICIPANTE + 3.0  # 112.5
H_BARRAS = 19.0
Y_BALAO = Y_BARRAS + H_BARRAS + 7.0              # 138.5
H_BALAO = 17.0
X_BALAO, LARG_BALAO = 32.0, 142.0
Y_ABA = Y_BALAO + H_BALAO + 10.0                 # 165.5
H_ABA = 8.5
X_ABA, LARG_ABA = 72.5, 65.0
Y_MENSAGEM = Y_ABA + H_ABA                       # 174
H_MENSAGEM = 60.0
# 262, e não 276: a `Cell` do PL_FPDF abre página nova quando y + altura passa
# de 277 (A4 menos a margem inferior de 20 mm). Com o rodapé em 276 e célula de
# 9 mm, cada linha do rodapé abria uma página — dois ingressos viravam SEIS
# páginas, e o sintoma aparecia longe da causa.
Y_RODAPE = 262.0

PAD_PAINEL = 2.8                    # moldura cinza em volta do miolo branco

Painel = namedtuple('Painel', 'x y w h cor')
Texto = namedtuple('Texto', 'x y w h texto corpo estilo alinhar cor')


def _t(x, y, w, texto, corpo, estilo='', alinhar='L', cor=PRETO, h=H_CEL):
    return Texto(x, y, w, h, texto, corpo, estilo, alinhar, cor)


def paineis():
    """Os retângulos preenchidos, na ordem em que são desenhados.

    Ordem importa: o miolo branco vai POR CIMA da moldura cinza, e é isso que
    cria a borda sem precisar de duas linhas.
    """
    return [
        Painel(X0, Y_CAB, LARGURA, H_CAB, AZUL),
        # ingresso: moldura cinza + miolo branco
        Painel(X0, Y_PAINEL, LARG_ESQ, H_INGRESSO, CINZA),
        Painel(X0 + PAD_PAINEL, Y_PAINEL + 6.4,
               LARG_ESQ - 2 * PAD_PAINEL, H_INGRESSO - 9.2, BRANCO),
        # participante
        Painel(X0, Y_PARTICIPANTE, LARG_ESQ, H_PARTICIPANTE, CINZA),
        Painel(X0 + PAD_PAINEL, Y_PARTICIPANTE + 6.4,
               LARG_ESQ - 2 * PAD_PAINEL, H_PARTICIPANTE - 9.2, BRANCO),
        # QR
        Painel(X_QR, Y_PAINEL, LARG_QR, H_QR, CINZA),
        Painel(X_QR + PAD_PAINEL, Y_PAINEL + PAD_PAINEL,
               LARG_QR - 2 * PAD_PAINEL, H_QR - 2 * PAD_PAINEL, BRANCO),
        # faixa do código de barras
        Painel(X0, Y_BARRAS, LARGURA, H_BARRAS, CINZA),
        Painel(X0 + PAD_PAINEL, Y_BARRAS + PAD_PAINEL,
               LARGURA - 2 * PAD_PAINEL, H_BARRAS - 2 * PAD_PAINEL, BRANCO),
        # balão de aviso
        Painel(X_BALAO, Y_BALAO, LARG_BALAO, H_BALAO, CINZA_CLARO),
        # aba da mensagem
        Painel(X_ABA, Y_ABA, LARG_ABA, H_ABA, CINZA_CLARO),
    ]


def rabinho():
    """Os três pontos do rabinho do balão — a única forma que não é retângulo.

    Aponta para baixo, à esquerda, como no balão de fala de um aplicativo.
    """
    x, y = X_BALAO + 6.0, Y_BALAO + H_BALAO
    return [(x, y), (x, y + 4.5), (x + 6.0, y)]


def evento():
    """Os dados do evento — fictícios, e só isso: a régua não calcula nada."""
    return {
        'titulo': 'Orquestra Sinfonica - Concerto de Gala',
        'quando': '19 out. 2026 - 20h as 22h',
        'local': 'Teatro Municipal',
        'endereco': 'Avenida Afonso Pena, 1321, Centro - Belo Horizonte, MG',
        'lote': '1o LOTE - INTEIRA',
        'preco': 'R$ 120,00',
        'compra': 'Comprado dia 18 out. 2026 - 18h26',
        'aviso': 'Apresente este ingresso na entrada, impresso ou na tela do '
                 'celular.',
        'mensagem': 'Obrigado por vir. A casa abre as 19h, e a entrada com '
                    'bebida nao e permitida no teatro.',
        'organizador': 'M&S Eventos',
        'site': 'exemplo.com.br',
    }


def textos(participante, codigo):
    """Todos os textos de uma via, com a caixa de cada um já resolvida."""
    ev = evento()
    xi = X0 + PAD_PAINEL
    wi = LARG_ESQ - 2 * PAD_PAINEL
    return [
        # cabeçalho, em branco sobre o azul
        _t(X0 + 4, Y_CAB + 4.5, LARGURA - 8, ev['titulo'], CORPO_TITULO, 'B',
           'L', BRANCO, h=H_CEL_TITULO),
        _t(X0 + 4, Y_CAB + 17.0, LARGURA - 8, ev['quando'], CORPO_LINHA, '',
           'L', BRANCO),
        _t(X0 + 4, Y_CAB + 23.0, LARGURA - 8, ev['local'], CORPO_LINHA, 'B',
           'L', BRANCO),
        _t(X0 + 4, Y_CAB + 28.0, LARGURA - 8, ev['endereco'], CORPO_MIUDO, '',
           'L', BRANCO, h=H_CEL_MIUDO),

        # painel do ingresso
        _t(X0, Y_PAINEL + 1.0, LARG_ESQ, 'Ingresso', CORPO_ROTULO, '', 'L',
           GRAFITE, h=H_CEL),
        _t(xi, Y_PAINEL + 7.6, wi, ev['lote'], CORPO_DESTAQUE, 'B'),
        _t(xi, Y_PAINEL + 14.6, wi, ev['preco'], CORPO_DESTAQUE, 'B'),
        _t(xi, Y_PAINEL + 22.0, wi, ev['compra'], CORPO_MIUDO, '', 'R',
           GRAFITE, h=H_CEL_MIUDO),

        # painel do participante
        _t(X0, Y_PARTICIPANTE + 1.0, LARG_ESQ, 'Participante', CORPO_ROTULO,
           '', 'L', GRAFITE),
        _t(xi, Y_PARTICIPANTE + 8.0, wi, participante, CORPO_NOME, 'B',
           h=H_CEL_NOME),

        # o código, embaixo do QR
        _t(X_QR, Y_PAINEL + H_QR - 12.0, LARG_QR, codigo, CORPO_CODIGO, 'B',
           'C'),

        # balão de aviso e mensagem da organização
        _t(X_BALAO, Y_BALAO + 5.0, LARG_BALAO, ev['aviso'], CORPO_LINHA, '',
           'C'),
        _t(X_ABA, Y_ABA + 1.5, LARG_ABA, 'Mensagem da organizacao',
           CORPO_MIUDO, '', 'C', GRAFITE, h=H_CEL_MIUDO),
        _t(X0 + 2, Y_MENSAGEM + 4.0, LARGURA - 4, ev['mensagem'], CORPO_LINHA),

        # rodapé
        _t(X0, Y_RODAPE, LARGURA, ev['organizador'], CORPO_DESTAQUE, 'B', 'C',
           LARANJA, h=H_CEL_TITULO),
        _t(X0, Y_RODAPE + 8.0, LARGURA, ev['site'], CORPO_MIUDO, '', 'C',
           GRAFITE, h=H_CEL_MIUDO),
    ]


def qr_rect():
    """(x, y, lado) do QR Code, centralizado no painel branco da direita."""
    lado = 32.0
    return (X_QR + (LARG_QR - lado) / 2, Y_PAINEL + 6.0, lado)


def barcode_rect():
    """(x, y, largura, altura) do Code 39 dentro da faixa branca."""
    larg = 120.0
    return (X0 + (LARGURA - larg) / 2, Y_BARRAS + 4.5, larg, 10.0)


def moldura_mensagem():
    """(x, y, w, h) da caixa da mensagem — só contorno, sem preenchimento."""
    return (X0, Y_MENSAGEM, LARGURA, H_MENSAGEM)


# ── conferência ──────────────────────────────────────────────────────────────
def conferir(pagina, participante, codigo):
    """Confere uma página inteira contra a régua. Gera (passou, ok, falha)."""
    spans = list(spans_da_pagina(pagina))

    fontes = {s['font'] for s in spans}
    esperadas = {BASE_FONT[''], BASE_FONT['B']}
    yield (fontes == esperadas,
           f'só Helvetica normal e negrito: {sorted(fontes)}',
           f'fontes na página: {sorted(fontes)}, esperadas {sorted(esperadas)}')

    for p in paineis():
        if p.cor == BRANCO:
            continue        # miolo branco sobre papel branco não prova nada
        yield confere_preenchimento(pagina, p.x, p.y, p.w, p.h, p.cor,
                                    f'painel em y={p.y:.0f}')

    for t in textos(participante, codigo):
        caixa = (t.x, t.y - 1.0, t.w, t.h + 2.0)
        yield from confere_texto(spans, t.texto, t.x, t.y, t.w, t.h, t.corpo,
                                 t.estilo, t.alinhar, caixa,
                                 f'{t.texto[:20]}', cor=t.cor)

    yield sem_empilhamento(spans)
