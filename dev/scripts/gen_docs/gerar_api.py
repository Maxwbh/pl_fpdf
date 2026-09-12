# -*- coding: utf-8 -*-
"""
As páginas do índice de utilização, PT e EN, a partir de `conteudo_api.py`.

DOCUMENTO DE MANUTENÇÃO.

O **desenho** — cabeçalho, SEO, CSS, navegação e rodapé — fica em
`api_molde.html` e `api_molde_en.html`, com três marcadores: `{{INDICE}}`,
`{{NOTA}}` e `{{SECOES}}`. Mexer no desenho é editar o molde; mexer no conteúdo
é editar `conteudo_api.py`.

O realce do SQL é o mesmo da referência (`gerar_html.realcar`), com um acréscimo
que só esta página usava: o **número** sai em destaque próprio. Sem isso, a
página gerada perderia um realce que a escrita à mão tinha.
"""
import io
import os
import re

import gerar_html
from gerar_html import esc

AQUI = os.path.dirname(os.path.abspath(__file__))
MOLDE = os.path.join(AQUI, 'api_molde.html')
MOLDE_EN = os.path.join(AQUI, 'api_molde_en.html')

# `'texto'` e `-- comentário` saem antes, senão um número dentro deles também
# viraria <span class="n">
NUMERO = re.compile(r'(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])')


def realcar(codigo):
    """Realce da referência, mais o número."""
    saida = []
    for linha in gerar_html.realcar(codigo).split('\n'):
        pedacos = re.split(r'(<span class="[ksc]">.*?</span>)', linha)
        saida.append(''.join(
            p if p.startswith('<span') else NUMERO.sub(
                r'<span class="n">\1</span>', p) for p in pedacos))
    return '\n'.join(saida)


def _sem_prosa(linhas):
    """O código sem o que muda de língua por direito.

    Sai o comentário, sai o literal de texto e sai o NOME DA VARIÁVEL LOCAL:
    `l_paragrafo` vira `l_paragraph` e `l_capa` vira `l_cover` na versão em
    inglês, e isso é tradução, não divergência.

    O que sobra tem de ser idêntico: `Cell(0, 10, 'Olá')` e
    `Cell(0, 10, 'Hello')` são o mesmo exemplo; `Cell(0, 12, ...)` não é, nem
    `MultiCell` no lugar de `Cell`, nem um parâmetro a mais.
    """
    fora = []
    for l in linhas:
        l = re.sub(r'--.*$', '', l)
        l = re.sub(r"'(?:[^']|'')*'", "''", l)
        l = re.sub(r'\bl_\w+', 'l_', l)
        fora.append(re.sub(r'\s+', ' ', l).strip())
    return fora


def conferir(secoes):
    falhas = []
    for s in secoes:
        for i, b in enumerate(s['blocos']):
            onde = f"{s['id']} bloco {i} ({b[0]})"
            if b[0] == 'tabela':
                for pt, en in b[1]:
                    if not pt[1] or not en[1]:
                        falhas.append(f'{onde}: linha sem texto nas duas línguas')
            elif b[0] == 'janela':
                if len(b[2]) != len(b[3]):
                    falhas.append(f'{onde}: o exemplo tem {len(b[2])} linhas em '
                                  f'PT e {len(b[3])} em EN')
                elif _sem_prosa(b[2]) != _sem_prosa(b[3]):
                    dif = [(x, y) for x, y in zip(_sem_prosa(b[2]),
                                                  _sem_prosa(b[3])) if x != y]
                    falhas.append(f'{onde}: o CÓDIGO difere entre as línguas '
                                  f'(fora comentário e literal): {dif[:2]}')
    if falhas:
        raise SystemExit('conteudo_api.py não fecha:\n  ' + '\n  '.join(falhas))


def secao(s, k):
    o = [f'<section id="{s["id"]}">',
         f'  <h2><span class="n">{s["n"]}</span> {esc(s["titulo"][k])}</h2>']
    # a segunda coluna é "O que faz" em 13 das 14 tabelas, e "Quando usar" na
    # da Saída -- um bloco `cabecalho` antes da tabela troca o rótulo
    coluna = ('O que faz', 'What it does')
    for b in s['blocos']:
        if b[0] == 'cabecalho':
            coluna = (b[1], b[2])
        elif b[0] == 'desc':
            o.append(f'  <p class="desc">{b[1 + k]}</p>')
        elif b[0] == 'nota':
            o.append(f'  <p class="note">{b[1 + k]}</p>')
        elif b[0] == 'tabela':
            o.append('  <div class="tbl"><table><thead><tr><th>API</th>'
                     f'<th>{esc(coluna[k])}</th></tr></thead><tbody>')
            for api, faz in b[1]:
                o.append(f'    <tr><td>{esc(api[k])}</td>'
                         f'<td>{esc(faz[k])}</td></tr>')
            o.append('  </tbody></table></div>')
        else:
            arquivo = b[1][k]
            codigo = b[2 + k]
            o.append('<div class="window"><div class="win-bar">'
                     '<i style="background:#ff5f57"></i>'
                     '<i style="background:#febc2e"></i>'
                     '<i style="background:#28c840"></i>'
                     f'<span class="win-t">{esc(arquivo)}</span></div>')
            o.append('<pre>' + realcar('\n'.join(codigo)) + '</pre></div>')
    o.append('</section>')
    return '\n'.join(o)


def pagina(secoes, nota_topo, k):
    conferir(secoes)
    indice = ['<div class="toc">']
    for s in secoes:
        indice.append(f'    <a href="#{s["id"]}"><span class="n">{s["n"]}'
                      f'</span> {esc(s["curto"][k])}</a>')
    indice.append('  </div>')
    corpo = '\n\n'.join(secao(s, k) for s in secoes)
    molde = io.open(MOLDE if k == 0 else MOLDE_EN, encoding='utf-8').read()
    for marca in ('{{INDICE}}', '{{NOTA}}', '{{SECOES}}'):
        if marca not in molde:
            raise SystemExit(f'o molde de api.html perdeu o marcador {marca}')
    saida = (molde.replace('{{INDICE}}', '\n'.join(indice))
                  .replace('{{NOTA}}', f'<p class="note">{nota_topo[k]}</p>')
                  .replace('{{SECOES}}', corpo))
    gerar_html.conferir_tags(saida, 'api.html')
    n = len(re.findall(r'<section id="', saida))
    if n != len(secoes):
        raise SystemExit(f'{len(secoes)} seções e {n} na página')
    ids = re.findall(r'<section id="([^"]+)"', saida)
    destinos = [d for d in re.findall(r'<a href="#([^"]+)"', saida) if d]
    orfaos = sorted(set(d for d in destinos if d not in ids))
    if orfaos:
        raise SystemExit(f'link do índice sem seção: {orfaos}')
    return saida
