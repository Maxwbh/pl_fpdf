# -*- coding: utf-8 -*-
"""
A página inicial, PT e EN, a partir de `conteudo_index.py`.

DOCUMENTO DE MANUTENÇÃO.

O desenho — CSS, SEO, a folha de PDF decorativa, o rodapé — fica em
`index_molde.html` e `index_molde_en.html`. Daqui sai o que é conteúdo: a
chamada, os números, os cartões, os exemplos, os passos da instalação e o
fechamento.

A **versão entra por `{versao}`**, lida do package. Era exatamente onde a
página escrita à mão tinha divergido: a vitrine dizia 3.4.0 e o comando de
download, logo abaixo, buscava a v3.3.0.
"""
import io
import os
import re

import gerar_api
import gerar_html
from gerar_html import esc

AQUI = os.path.dirname(os.path.abspath(__file__))
MOLDE = os.path.join(AQUI, 'index_molde.html')
MOLDE_EN = os.path.join(AQUI, 'index_molde_en.html')

GITHUB_SVG = (
    '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 '
    '8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-'
    '2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-'
    '.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-'
    '1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 '
    '0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 '
    '2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-'
    '3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8'
    '.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>')


def botao(b, k):
    """`(classe, href, (rótulo pt, rótulo en))` -> o anchor.

    O ícone do GitHub acompanha o botão primário que aponta para o repositório,
    como na página escrita à mão.
    """
    classe, href, rotulo = b
    icone = (f'\n          {GITHUB_SVG}\n          '
             if href == 'https://github.com/Maxwbh/pl_fpdf' else '')
    return (f'<a class="btn {classe}" href="{href}">{icone}'
            f'{esc(rotulo[k])}</a>')


def janela(titulo, codigo, k):
    return ('<div class="window">\n'
            '        <div class="win-bar"><span class="r"></span>'
            '<span class="y"></span><span class="g"></span>\n'
            f'          <span class="win-title">{esc(titulo[k])}</span></div>\n'
            '        <pre>' + gerar_api.realcar('\n'.join(codigo[k]))
            + '</pre>\n      </div>')


def conferir(conteudo_index):
    """O exemplo é o mesmo código nas duas línguas.

    Fora comentário, literal e nome de variável local, que mudam de língua por
    direito. O que mais muda -- o nome de uma tabela de exemplo, por exemplo --
    entra DECLARADO, no `traduz` da janela: assim a troca é uma decisão escrita,
    e não um buraco na verificação.
    """
    falhas = []
    pares = [('hero', conteudo_index.HERO['codigo'], {})]
    for b in conteudo_index.EXEMPLOS['blocos']:
        if b[0] == 'grade':
            for j in b[1]:
                pares.append((j['titulo'][0], j['codigo'], j.get('traduz', {})))
    for nome, (pt, en), traduz in pares:
        if len(pt) != len(en):
            falhas.append(f'{nome}: {len(pt)} linhas em PT e {len(en)} em EN')
            continue
        a = gerar_api._sem_prosa(pt)
        for de, para in traduz.items():
            a = [re.sub(r'\b%s\b' % re.escape(de), para, l) for l in a]
        b_ = gerar_api._sem_prosa(en)
        if a != b_:
            dif = [(x, y) for x, y in zip(a, b_) if x != y]
            falhas.append(f'{nome}: o CÓDIGO difere entre as línguas '
                          f'(fora comentário, literal e o `traduz`): {dif[:2]}')
    if falhas:
        raise SystemExit('conteudo_index.py não fecha:\n  '
                         + '\n  '.join(falhas))


def pagina(c, k, versao):
    conferir(c)
    partes = {}
    partes['HERO_H1'] = c.HERO['h1'][k]
    partes['HERO_SUB'] = c.HERO['sub'][k]
    # o primeiro chip leva o pontinho que pisca, como na página escrita à mão
    ponto = '<span class="dot"></span>'
    partes['CHIPS'] = '\n        '.join(
        '<span class="chip">' + (ponto if i == 0 else '')
        + esc(x[k].format(versao=versao)) + '</span>'
        for i, x in enumerate(c.HERO['chips']))
    partes['HERO_BOTOES'] = '\n        '.join(botao(b, k)
                                              for b in c.HERO['botoes'])
    partes['HERO_JANELA'] = janela(c.HERO['janela'], c.HERO['codigo'], k)
    partes['FORK'] = c.FORK[k]
    partes['STATS'] = '\n    '.join(
        f'<div class="stat"><b>{v.format(versao=versao)}</b>'
        f'<span>{esc(r[k])}</span></div>' for v, r in c.STATS)

    cards = []
    for x in c.RECURSOS['cards']:
        cards.append('      <div class="card">\n'
                     f'        <div class="icon">{x["icone"]}</div>\n'
                     f'        <h3>{esc(x["titulo"][k])}</h3>\n'
                     f'        <p>{x["texto"][k]}</p>\n'
                     '      </div>')
    partes['RECURSOS'] = (
        f'    <p class="kicker">{esc(c.RECURSOS["kicker"][k])}</p>\n'
        f'    <h2>{c.RECURSOS["h2"][k]}</h2>\n'
        f'    <p class="lead">{c.RECURSOS["lead"][k]}</p>\n\n'
        '    <div class="grid">\n' + '\n'.join(cards) + '\n    </div>')

    blocos = [f'    <p class="kicker">{esc(c.EXEMPLOS["kicker"][k])}</p>',
              f'    <h2>{c.EXEMPLOS["h2"][k]}</h2>']
    for b in c.EXEMPLOS['blocos']:
        if b[0] == 'lead':
            blocos.append(f'    <p class="lead">{b[2 + k]}</p>')
        elif b[0] == 'h3':
            blocos.append(f'    <h3 {b[1]}>{b[2 + k]}</h3>')
        elif b[0] == 'imagem':
            blocos.append('    <p style="text-align:center;margin:24px 0 8px">'
                          f'\n      {b[2 + k]}\n    </p>')
        elif b[0] == 'legenda':
            blocos.append(f'    <p class="lead" {b[1]}>\n      {b[2 + k]}\n'
                          '    </p>')
        else:
            blocos.append('    <div class="ex-grid">\n      '
                          + '\n      '.join(janela(j['titulo'], j['codigo'], k)
                                            for j in b[1])
                          + '\n    </div>')
    partes['EXEMPLOS'] = '\n'.join(blocos)

    passos = []
    for p in c.INSTALACAO['passos']:
        depois = (f'\n        <p style="margin-top:.5rem;font-size:.85em;'
                  f'opacity:.75">{esc(p["depois"][k])}</p>'
                  if p.get('depois') else '')
        passos.append('      <div class="step">\n'
                      f'        <h3>{esc(p["titulo"][k])}</h3>\n'
                      f'        <p>{p["texto"][k]}</p>\n'
                      '        <code class="block">'
                      + p['codigo'].format(versao=versao)
                      + '</code>' + depois + '\n      </div>')
    partes['INSTALACAO'] = (
        f'    <p class="kicker">{esc(c.INSTALACAO["kicker"][k])}</p>\n'
        f'    <h2>{c.INSTALACAO["h2"][k]}</h2>\n'
        f'    <p class="lead">{c.INSTALACAO["lead"][k]}</p>\n\n'
        '    <div class="steps">\n' + '\n'.join(passos) + '\n    </div>\n\n'
        '    <p class="note" style="margin-top:26px">'
        + c.INSTALACAO['nota'][k] + '</p>\n\n'
        '    <code class="block">'
        + esc(c.INSTALACAO['curl'].format(versao=versao)) + '</code>')

    partes['FINAL'] = (
        f'    <h2>{c.FINAL["h2"][k]}</h2>\n'
        f'    <p>{c.FINAL["texto"][k]}</p>\n'
        '    <div class="cta" style="justify-content:center">\n      '
        + '\n      '.join(botao(b, k) for b in c.FINAL['botoes'])
        + '\n    </div>')

    molde = io.open(MOLDE if k == 0 else MOLDE_EN, encoding='utf-8').read()
    for marca in partes:
        if '{{%s}}' % marca not in molde:
            raise SystemExit(f'o molde de index.html perdeu o marcador '
                             f'{{{{{marca}}}}}')
        molde = molde.replace('{{%s}}' % marca, partes[marca])
    saida = molde.replace('{{VERSAO}}', versao)
    gerar_html.conferir_tags(saida, 'index.html')
    return saida
