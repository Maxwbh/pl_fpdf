# -*- coding: utf-8 -*-
"""
Deriva as larguras das 14 fontes padrão do PDF a partir das fontes primárias.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
As tabelas de largura viviam no `PL_FPDF.pkb` como 11 funções herdadas do porte
de 2017, transcritas à mão. São **dado**, não invenção: as larguras das 14
fontes padrão são publicadas pela Adobe, e a correspondência entre byte e glifo
é a `WinAnsiEncoding` do PDF. Reconstruí-las da fonte primária é mais correto
que copiá-las de outro programa — e é o que este arquivo faz.

Duas fontes, e elas se conferem
-------------------------------
Como manda o método da casa, o dado não vem de um lugar só:

    A) os AFM da Adobe, na distribuição URW que acompanha o matplotlib,
       metricamente idênticas às Core 14
    B) as tabelas do reportlab (`_fontdata_widths_*`), outra implementação
       independente das mesmas métricas

`conferir_fontes()` compara as duas glifo a glifo e **levanta erro** se
divergirem. Onde só uma tem o glifo, ela decide — e o caso real é o **Euro**: os
AFM da URW são anteriores à adição do glifo e não o trazem; o reportlab traz,
com 556 na Helvetica.

O mapeamento byte -> glifo é a `WinAnsiEncoding` publicada pelo reportlab, e
não uma reconstrução. A primeira tentativa foi reconstruí-la com CP1252 mais a
Adobe Glyph List do fontTools, e ela errava: o `AGL2UV` do fontTools é parcial
— não traz `twosuperior` nem o espaço inquebrável — e `²`, `³`, `¹` e o 160
caíam para um padrão em vez da largura certa.

Essa troca desfez uma conclusão errada minha, que vale registrar: eu tinha lido
o 350 das posições 127, 129 e 141 como "convenção do FPDF para posição sem
glifo". Não é. Na WinAnsi essas posições mapeiam para **bullet**, e 350 é a
largura do bullet na Helvetica. Era métrica o tempo todo.

Symbol e ZapfDingbats não passam por WinAnsi: têm codificação própria, e o
reportlab publica as duas (`SymbolEncoding`, `ZapfDingbatsEncoding`). Ler o
campo `C` do AFM parecia equivalente e não é — a codificação do AFM da URW não
cobre a faixa 128..160 que a do ZapfDingbats usa.
"""
import os
import re

import matplotlib
from reportlab.pdfbase._fontdata import encodings

AFM_DIR = os.path.join(os.path.dirname(matplotlib.__file__),
                       'mpl-data', 'fonts', 'afm')

# família -> (AFM da URW, módulo de larguras do reportlab)
FONTES = {
    'Courier':      ('pcrr8a.afm',  'courier'),
    'Helvetica':    ('phvr8a.afm',  'helvetica'),
    'Helveticab':   ('phvb8a.afm',  'helveticabold'),
    'Helveticai':   ('phvro8a.afm', 'helveticaoblique'),
    'Helveticabi':  ('phvbo8a.afm', 'helveticaboldoblique'),
    'Times':        ('ptmr8a.afm',  'timesroman'),
    'Timesb':       ('ptmb8a.afm',  'timesbold'),
    'Timesi':       ('ptmri8a.afm', 'timesitalic'),
    'Timesbi':      ('ptmbi8a.afm', 'timesbolditalic'),
    'Symbol':       ('psyr.afm',    'symbol'),
    'Zapfdingbats': ('pzdr.afm',    'zapfdingbats'),
}

# Posição sem glifo, e aqui as três famílias divergem:
#
#   latinas       largura do espaço em toda posição vazia
#   Symbol        largura do espaço na faixa de controle, zero acima de 127
#   ZapfDingbats  zero em qualquer posição vazia
#
# Não há razão para essa diferença — é o porte que tratou as fontes simbólicas
# de um jeito e as latinas de outro. Está preservada de propósito: uniformizar
# mudaria a medida de texto que hoje já é gerado, e o objetivo desta etapa é
# trocar a PROCEDÊNCIA do dado, não o comportamento. Registrada aqui para quem
# um dia quiser decidir a respeito com o caso na mão.
def vazio_de(familia, codigo, espaco):
    if familia == 'Zapfdingbats':
        return 0
    if familia == 'Symbol':
        return espaco if codigo < 32 else 0
    return espaco

CODIFICACAO = {
    'Symbol':       encodings['SymbolEncoding'],
    'Zapfdingbats': encodings['ZapfDingbatsEncoding'],
}
WINANSI = encodings['WinAnsiEncoding']


def ler_afm(arquivo):
    """(largura por nome de glifo, largura por código da codificação do AFM)."""
    por_nome, por_codigo = {}, {}
    dentro = False
    for linha in open(os.path.join(AFM_DIR, arquivo), encoding='latin-1'):
        if linha.startswith('StartCharMetrics'):
            dentro = True
            continue
        if linha.startswith('EndCharMetrics'):
            break
        if not dentro:
            continue
        c = re.search(r'\bC\s+(-?\d+)\s*;', linha)
        wx = re.search(r'\bWX\s+(-?\d+)\s*;', linha)
        n = re.search(r'\bN\s+(\S+)\s*;', linha)
        if not (wx and n):
            continue
        por_nome[n.group(1)] = int(wx.group(1))
        if c and int(c.group(1)) >= 0:
            por_codigo[int(c.group(1))] = int(wx.group(1))
    return por_nome, por_codigo


def ler_reportlab(modulo):
    mod = __import__(f'reportlab.pdfbase._fontdata_widths_{modulo}',
                     fromlist=['widths'])
    return dict(mod.widths)


def conferir_fontes():
    """As duas fontes primárias precisam concordar onde ambas conhecem o glifo."""
    divergencias = []
    for familia, (afm, rl) in FONTES.items():
        a, _ = ler_afm(afm)
        b = ler_reportlab(rl)
        for glifo in set(a) & set(b):
            if a[glifo] != b[glifo]:
                divergencias.append((familia, glifo, a[glifo], b[glifo]))
    if divergencias:
        raise SystemExit(
            'AFM e reportlab discordam — uma das duas está errada, e nenhuma '
            'tabela deve ser gerada até saber qual:\n' +
            '\n'.join(f'  {f} {g}: AFM={x} reportlab={y}'
                      for f, g, x, y in divergencias[:20]))
    return sum(len(set(ler_afm(a)[0]) & set(ler_reportlab(r)))
               for a, r in FONTES.values())


def larguras(familia):
    afm, rl = FONTES[familia]
    por_nome, por_codigo = ler_afm(afm)
    do_rl = ler_reportlab(rl)
    # o reportlab entra por último para cobrir o que o AFM da URW não tem
    conhecido = dict(por_nome)
    for glifo, w in do_rl.items():
        conhecido.setdefault(glifo, w)

    tabela = CODIFICACAO.get(familia, WINANSI)
    espaco = conhecido.get('space', 0)
    tab = {}
    for c in range(256):
        vazio = vazio_de(familia, c, espaco)
        glifo = tabela[c] if c < len(tabela) else None
        tab[c] = conhecido.get(glifo, vazio) if glifo else vazio
    return tab


def todas():
    return {f: larguras(f) for f in FONTES}


if __name__ == '__main__':
    n = conferir_fontes()
    print(f'AFM da Adobe e reportlab conferem em {n} glifos.\n')
    for familia, tab in todas().items():
        print(f'  {familia:<14} espaço={tab[32]:>4}  A={tab[65]:>4}  '
              f'euro={tab[128]:>4}  {len(set(tab.values())):>3} larguras distintas')
