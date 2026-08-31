# -*- coding: utf-8 -*-
"""
As páginas escritas à mão não divergem entre PT e EN em silêncio.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
`reference.html` é gerado nos dois idiomas de uma fonte só, e o
`check_traducao.py` cobre essa fonte. As outras páginas do site — `api.html`,
`index.html` — são escritas à mão, e aí a tradução vira um segundo arquivo que
alguém precisa lembrar de editar junto.

Ninguém lembra. É o defeito que esta base já pagou três vezes em outros pares
mantidos à mão, e aqui ele é pior que um bug: uma seção que existe só em
português numa página inglesa não parece quebrada, parece abandonada.

O que cobra
-----------
1. **As mesmas seções, na mesma ordem.** Os `id=` de `<section>` são âncoras:
   se a EN perder uma, o índice dela aponta para o vazio.
2. **O mesmo índice.** Cada cartão do topo aponta para uma seção que existe.
3. **O mesmo número de linhas de tabela por seção.** Uma API acrescentada de um
   lado só é exatamente o que se quer pegar.
4. **Os mesmos blocos de código, chamando as mesmas APIs com os mesmos
   parâmetros nomeados.** Comentário, literal e nome de variável local são
   conteúdo e mudam de idioma; a API demonstrada, não. Quem acrescentar um
   parâmetro no exemplo português e esquecer o inglês é pego na hora.
5. **Nenhuma frase da página inglesa idêntica à portuguesa.** É a que mais
   vale, e ela nasceu de um furo real: as quatro primeiras comparam
   *estrutura*, e uma seção acrescentada só no português entrava inteira, em
   português, na página inglesa — com as estruturas batendo perfeitamente,
   porque era o mesmo conteúdo. As quatro aprovavam.

   Tentei primeiro varrer a saída por acento e por palavra portuguesa comum, e
   não funcionou: "Assina o documento com certificado ICP-Brasil" não tem um
   acento, e enumerar palavras de um idioma é uma lista sem fim. O sinal certo
   não é "isto parece português", é "isto está **idêntico** ao original" — o
   mesmo que o `check_traducao.py` usa no `meta_en.py`.

   Compara-se só a **prosa**: parágrafo, título e a coluna de descrição das
   tabelas. Ficam de fora o `<pre>` e a primeira coluna de cada linha, que são
   código e assinatura de API — iguais nos dois idiomas por obrigação, e é
   deles que vinham 237 dos 242 falsos positivos da primeira tentativa.

O que NÃO cobra
---------------
A qualidade da tradução — isso é revisão humana. Um texto inglês ruim passa;
um texto português esquecido, não.

As páginas são escritas à mão, nos dois idiomas, de propósito: são documentação,
não saída de gerador. Este script não escreve nada — só recusa o par que saiu
do lugar.

Uso:  python dev/scripts/gen_docs/check_paridade.py
"""
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))

# (portugues, ingles) — relativos à raiz do repositório. Uma página entra aqui
# no mesmo commit em que a sua tradução nasce.
PARES = [
    (os.path.join('site', 'api.html'), os.path.join('site', 'en', 'api.html')),
    (os.path.join('site', 'index.html'), os.path.join('site', 'en', 'index.html')),
]

# Prosa que é a mesma nos dois idiomas por natureza: lista de simbologias,
# chaves de JSON, a tarja de versão. Entrar aqui é decisão consciente — é o
# que separa "igual porque tem de ser" de "igual porque ninguém traduziu".
#
# O número de versão vira `<versao>` antes da comparação. A primeira versão
# desta lista trazia 'v3.2.0 · Oracle 19c+' cravado, e o primeiro bump quebrou
# a verificação: uma lista de exceções que precisa ser editada a cada release
# é uma que alguém vai editar errado com pressa.
IGUAIS_OK = {
    'CODE128, CODE39, EAN13, EAN8, ITF14',
    'JPEG/PNG; opacity, rotation, maintainAspect, scaleToFit',
    'v<versao> · Oracle 19c+',
    'Oracle 19c+',
    'PIX &amp; Boleto',
    # ficou igual quando a licenca deixou de ser "em revisao"/"under review":
    # "Open source (MIT)" e a mesma frase nos dois idiomas.
    'Open source (MIT)',
}


def secoes(texto):
    """Os id= das <section>, na ordem em que aparecem."""
    return re.findall(r'<section id="([^"]+)"', texto)


def indice(texto):
    """Os alvos dos cartões do índice do topo (href="#alvo")."""
    bloco = re.search(r'<div class="toc">(.*?)</div>', texto, re.S)
    return re.findall(r'href="#([^"]+)"', bloco.group(1)) if bloco else []


def linhas_por_secao(texto):
    """Quantas <tr> de corpo cada seção tem."""
    fora = {}
    for m in re.finditer(r'<section id="([^"]+)"(.*?)</section>', texto, re.S):
        fora[m.group(1)] = len(re.findall(r'<tr><td>', m.group(2)))
    return fora


def esqueleto(bloco):
    """As APIs chamadas e os parâmetros nomeados de um <pre>, em ordem.

    Comparar o SQL inteiro seria forte demais e daria falso positivo em tudo:
    num exemplo, o comentário, o literal ('Olá, Mundo!' → 'Hello, World!') e o
    nome da variável local (l_linhas → l_lines) SÃO conteúdo e mudam de idioma
    com razão.

    O que não muda é o que o exemplo demonstra: quais APIs ele chama e com que
    parâmetros. É esse esqueleto que se compara — e é ele que quebra quando
    alguém acrescenta um parâmetro no exemplo português e esquece o inglês, que
    é o defeito real, porque o exemplo é a parte que mais se mexe.
    """
    b = re.sub(r'<span class="c">.*?</span>', '', bloco, flags=re.S)  # comentários
    b = re.sub(r'<[^>]+>', '', b)                                     # marcação
    b = (b.replace('&gt;', '>').replace('&lt;', '<')
          .replace('&amp;', '&').replace('&quot;', '"'))
    b = re.sub(r"'(?:[^']|'')*'", "''", b)      # literais viram um só marcador
    chamadas = re.findall(r'PL_FPDF\.(\w+)\s*\(', b, re.I)
    nomeados = re.findall(r'(\w+)\s*=>', b)
    return [c.lower() for c in chamadas], [n.lower() for n in nomeados]


def blocos(texto):
    return re.findall(r'<pre>(.*?)</pre>', texto, re.S)


def prosa(html):
    """As frases que uma pessoa escreveu, normalizadas.

    Fora: <pre> (código), e o primeiro <td> de cada linha (assinatura de API).
    Os dois são iguais nos dois idiomas por obrigação e só produziriam ruído.
    O corte de 6 letras e um espaço descarta rótulo de uma palavra — 'Reset',
    'GitHub' —, que também é igual por natureza.
    """
    h = re.sub(r'<style>.*?</style>|<svg.*?</svg>|<!--.*?-->|<pre>.*?</pre>',
               '', html, flags=re.S)
    h = re.sub(r'<tr><td>[^<]*</td>', '<tr>', h)
    saida = []
    for m in re.finditer(r'<(p|h1|h2|h3|li|span|td)\b[^>]*>(.*?)</\1>', h, re.S):
        t = re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', m.group(2))).strip()
        t = re.sub(r'\bv\d+\.\d+\.\d+\b', 'v<versao>', t)
        if len(re.findall(r'[A-Za-zÀ-ÿ]', t)) >= 6 and ' ' in t:
            saida.append(t)
    return saida


def confere(rel_pt, rel_en):
    cam_pt, cam_en = os.path.join(RAIZ, rel_pt), os.path.join(RAIZ, rel_en)
    for c in (cam_pt, cam_en):
        if not os.path.exists(c):
            return [f'{os.path.relpath(c, RAIZ)}: não existe']
    pt = open(cam_pt, encoding='utf-8').read()
    en = open(cam_en, encoding='utf-8').read()
    faltas = []

    s_pt, s_en = secoes(pt), secoes(en)
    if s_pt != s_en:
        so_pt = [x for x in s_pt if x not in s_en]
        so_en = [x for x in s_en if x not in s_pt]
        if so_pt:
            faltas.append(f'{rel_en}: sem as seções {so_pt}')
        if so_en:
            faltas.append(f'{rel_pt}: sem as seções {so_en}')
        if not so_pt and not so_en:
            faltas.append(f'{rel_en}: mesmas seções, em outra ordem')

    for rel, texto, marcadas in ((rel_pt, pt, s_pt), (rel_en, en, s_en)):
        for alvo in indice(texto):
            if alvo not in marcadas:
                faltas.append(f'{rel}: o índice aponta para "#{alvo}", '
                              f'que não é seção da página')

    l_pt, l_en = linhas_por_secao(pt), linhas_por_secao(en)
    for sid in s_pt:
        if sid in l_en and l_pt[sid] != l_en[sid]:
            faltas.append(f'seção "{sid}": {l_pt[sid]} linha(s) de tabela em '
                          f'{rel_pt} e {l_en[sid]} em {rel_en}')

    b_pt, b_en = blocos(pt), blocos(en)
    if len(b_pt) != len(b_en):
        faltas.append(f'{len(b_pt)} bloco(s) de código em {rel_pt} e '
                      f'{len(b_en)} em {rel_en}')
    else:
        for i, (a, b) in enumerate(zip(b_pt, b_en), 1):
            ca, na = esqueleto(a)
            cb, nb = esqueleto(b)
            if ca != cb:
                faltas.append(f'bloco de código nº {i}: chama {ca} em '
                              f'{rel_pt} e {cb} em {rel_en}')
            elif na != nb:
                faltas.append(f'bloco de código nº {i}: os parâmetros nomeados '
                              f'diferem — {na} em {rel_pt}, {nb} em {rel_en}')

    em_en = set(prosa(en))
    for frase in prosa(pt):
        if frase in em_en and frase not in IGUAIS_OK:
            faltas.append(f'{rel_en}: a frase abaixo está igual à portuguesa — '
                          f'conteúdo novo que ninguém traduziu?\n'
                          f'      "{frase[:120]}"')
    return faltas


def main():
    todas, blocos_vistos = [], 0
    for rel_pt, rel_en in PARES:
        todas += confere(rel_pt, rel_en)
        cam = os.path.join(RAIZ, rel_pt)
        if os.path.exists(cam):
            blocos_vistos += len(blocos(open(cam, encoding='utf-8').read()))

    if todas:
        print(f'{len(todas)} divergência(s) entre as versões PT e EN:')
        for f in todas:
            print(f'  {f}')
        print('\nO português é canônico: edite a página PT e reflita na EN.')
        return 1

    print(f'OK — {len(PARES)} par(es) de página em paridade, '
          f'{blocos_vistos} bloco(s) de código demonstrando as mesmas APIs, '
          f'nenhuma frase por traduzir')
    return 0


if __name__ == '__main__':
    sys.exit(main())
