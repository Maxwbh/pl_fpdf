# -*- coding: utf-8 -*-
"""
Confere que todo link relativo da documentação aponta para um arquivo que existe.

Por que existe
--------------
Link quebrado em documentação não dá erro em lugar nenhum: o arquivo continua
válido, o site continua no ar, e quem clica é que descobre. A revisão de
agosto/2026 achou um `docs/api/API_REFERENCE.md` no `CHANGELOG.md` — um caminho
que deixou de existir quando a pasta `api/` foi achatada, e que ficou apontando
para o nada desde então.

Imagem entra junto, e por um motivo próprio: o README do GitHub aceita HTML, e
as capturas dos exemplos são `<img src="...">` dentro de um `<p align="center">`
— nenhum `![]()` para o padrão do Markdown pegar. Quando o site saiu da raiz
para `site/`, foram exatamente essas quatro linhas que ficaram apontando para o
nada, e o README continuou "válido": a imagem simplesmente não aparece.

As páginas do `site/` entram pelo mesmo motivo, e a tradução mostrou por quê:
`<a class="brand" href="index.html">` ficou fixo no molde, e a versão inglesa
saiu apontando para um `site/en/index.html` que não existe. A página abria
normalmente — só o link da marca levava a lugar nenhum, que é exatamente o tipo
de defeito que ninguém vê revisando o diff.

O que NÃO é verificado: `http`, `https` e `mailto`. Sair na rede a cada rodada
de CI trocaria um problema barato por um teste instável.

Uso:  python dev/scripts/gen_docs/check_links.py
"""
import glob
import io
import os
import re
import sys

LINK = re.compile(r'\]\((?!https?:|mailto:)([^)#]+)')
IMG = re.compile(r'<img\s[^>]*src="(?!https?:|data:)([^"#]+)', re.I)
# href/src de HTML. O (?!#) descarta a ancora pura (href="#init"), que e um
# alvo dentro da propria pagina e nao um arquivo.
HREF = re.compile(r'(?:href|src)="(?!https?:|mailto:|data:|#)([^"#]+)', re.I)
# Ancorado na RAIZ, calculada deste arquivo: com padrao relativo ao diretorio
# atual, rodar de outro lugar nao dava erro — dava "0 links em 0 arquivos", e
# passava. Verificacao que aprova sem olhar nada e pior que verificacao que
# falha, porque ninguem desconfia.
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
ARQUIVOS = [os.path.join(RAIZ, p) for p in
            ('*.md', 'docs/*.md', 'dev/tests/*.md', 'extensions/**/*.md',
             'site/*.html', 'site/**/*.html')]


def main():
    quebrados = []
    total = 0
    vistos = set()
    for padrao in ARQUIVOS:
        for caminho in sorted(glob.glob(padrao, recursive=True)):
            if caminho in vistos:
                continue
            vistos.add(caminho)
            base = os.path.dirname(caminho)
            texto = io.open(caminho, encoding='utf-8').read()
            padroes = ([HREF] if caminho.endswith('.html') else [LINK, IMG])
            for m in [x for p in padroes for x in p.finditer(texto)]:
                total += 1
                alvo = os.path.normpath(os.path.join(base, m.group(1).strip()))
                if not os.path.exists(alvo):
                    linha = texto.count('\n', 0, m.start()) + 1
                    quebrados.append(
                        f'  {os.path.relpath(caminho, RAIZ)}:{linha} '
                        f'-> {m.group(1)}')

    if not vistos:
        print('nenhum arquivo encontrado — os padroes nao casaram com '
              'nada, e passar assim seria aprovar sem verificar')
        return 1

    if quebrados:
        print(f'{len(quebrados)} link(s) relativo(s) apontando para arquivo '
              f'inexistente:')
        for q in quebrados:
            print(q)
        return 1

    print(f'OK — {total} links e imagens relativos em {len(vistos)} arquivos, '
          f'todos apontam para arquivo existente')
    return 0


if __name__ == '__main__':
    sys.exit(main())
