# -*- coding: utf-8 -*-
"""
O que o site anuncia bate com o que o código é e com o que está publicado.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Três fontes dizem "qual é a versão", e cada uma é editada num momento
diferente: o `co_version` da spec (o código), as constantes `ULTIMO_RELEASE` e
`ULTIMA_CANDIDATA` do `conteudo_index.py` (a estratégia de distribuição), e os
releases do GitHub (o que de fato se baixa). A revisão de novembro de 2026
achou o site dizendo "3.4.0 — versão atual" enquanto o link de download
entregava a 3.3.0 e a 3.4.0 era só candidata: cada peça certa sozinha, o
conjunto enganando quem lia.

O que cobra
-----------
Sem rede (no CI, a cada push):

1. A estratégia fecha com o código: havendo candidata, ela é do `co_version`
   (`v3.4.0-rc2` para 3.4.0) e a estável é anterior; não havendo, a estável É o
   `co_version` — senão o site descreve uma versão que ninguém pode baixar.
2. O site gerado anuncia o que a estratégia diz: o chip do topo, o destaque da
   versão estável, o dado estruturado (`softwareVersion` = a estável) e o aviso
   de candidata, presente só quando ela existe.
3. Os selos de versão dos READMEs dizem o mesmo que o chip.
4. O sitemap lista toda página do site, e nenhuma que não exista, e o
   `lastmod` de cada uma não é anterior ao último commit que a mudou. O
   `generate.py` já põe a data ao reescrever uma página; isto pega a página
   mexida por outro caminho. Precisa do histórico (`fetch-depth: 0`). E o
   formato que o Google aceita: a ordem do esquema do sitemaps.org (os
   `xhtml:link` depois de `priority`), data W3C, URLs debaixo do diretório do
   sitemap, e hreflang recíproco e igual ao que cada página declara no `<head>`.

Com rede (`--online`: antes de publicar o site, e no workflow semanal):

5. O release estável existe, não é pré-lançamento, traz `pl_fpdf_install.sql`
   e `SHA256.txt`, e é ele que o "latest" do GitHub entrega — é o link do botão
   de download.
6. A candidata existe, é pré-lançamento e traz os mesmos dois arquivos.

Uso:  python dev/scripts/gen_docs/check_publicacao.py [--online]
"""
import io
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
sys.path.insert(0, AQUI)
import conteudo_index as c  # noqa: E402

API = 'https://api.github.com/repos/Maxwbh/pl_fpdf/releases/'
ASSETS = {'pl_fpdf_install.sql', 'SHA256.txt'}


def ler(*p):
    with io.open(os.path.join(RAIZ, *p), encoding='utf-8') as f:
        return f.read()


def tupla(v):
    return tuple(int(x) for x in re.findall(r'\d+', v)[:3])


def estaticas(versao):
    erros = []
    rel, cand = c.ULTIMO_RELEASE, c.ULTIMA_CANDIDATA
    if cand:
        if not re.fullmatch(rf'v{re.escape(versao)}-rc\d+', cand):
            erros.append(f'ULTIMA_CANDIDATA = {cand!r} não é candidata do co_version {versao}')
        if tupla(rel) >= tupla(versao):
            erros.append(f'ULTIMO_RELEASE {rel} não é anterior ao co_version {versao}, '
                         f'e há candidata {cand}')
    elif rel != versao:
        erros.append(f'o site descreve a {versao} (co_version), mas ULTIMO_RELEASE é {rel} '
                     f'e não há candidata: ninguém consegue baixar o que a página '
                     f'descreve. Publique uma candidata ou o release.')

    for k, arq in ((0, ('site', 'index.html')), (1, ('site', 'en', 'index.html'))):
        html = ler(*arq)
        nome = '/'.join(arq)
        chip = c.rotulo_chip(versao, k)
        if f'<span class="dot"></span>{chip}</span>' not in html:
            erros.append(f'{nome}: o chip do topo não diz {chip!r}')
        if f'"softwareVersion": "{rel}"' not in html:
            erros.append(f'{nome}: softwareVersion não é a estável {rel}')
        tem_aviso = 'class="note"><b>' + ('Estável × candidata' if k == 0 else 'Stable vs candidate') in html
        if bool(cand) != tem_aviso:
            erros.append(f'{nome}: aviso de candidata {"ausente" if cand else "sobrando"}')
        if 'releases/latest/download/pl_fpdf_install.sql' not in html:
            erros.append(f'{nome}: o botão de download não usa o "latest"')

    alvo = (cand.lstrip('v').replace('-', '--') if cand else versao)
    for arq, selo in (('README.md', 'badge/versão-'), ('README_EN.md', 'badge/version-')):
        m = re.search(re.escape(selo) + r'([^"]+?)-[a-z]+\.svg', ler(arq))
        if not m or not m.group(1).startswith(alvo):
            erros.append(f'{arq}: o selo de versão não diz {alvo!r} '
                         f'({m.group(1) if m else "selo ausente"})')
    return erros + sitemap()


def sitemap():
    """Cada página do site está no sitemap, e o lastmod dela não é anterior ao
    último commit que a mudou. Com lastmod atrasado o Google aprende a ignorar o
    campo: em novembro de 2026 ele dizia 25/10 para páginas reescritas em 7 e
    8/11. Precisa do histórico -- em clone raso o único commit "mudou" tudo."""
    erros = []
    raso = subprocess.run(['git', 'rev-parse', '--is-shallow-repository'], cwd=RAIZ,
                          capture_output=True, text=True).stdout.strip()
    if raso != 'false':
        return ['site/sitemap.xml: o lastmod é conferido contra o histórico do git, '
                'e este clone é raso — no workflow, actions/checkout com fetch-depth: 0']
    xml = ler('site', 'sitemap.xml')
    datas = dict(re.findall(r'<loc>([^<]+)</loc>.*?<lastmod>([^<]+)</lastmod>', xml, re.S))
    base = 'https://maxwbh.github.io/pl_fpdf/'
    paginas = sorted(os.path.relpath(os.path.join(d, f), os.path.join(RAIZ, 'site'))
                     .replace(os.sep, '/')
                     for d, _, fs in os.walk(os.path.join(RAIZ, 'site'))
                     for f in fs if f.endswith('.html') and not f.startswith('google'))
    urls = set()
    for p in paginas:
        url = base + re.sub(r'(^|/)index\.html$', r'\1', p)
        urls.add(url)
        if url not in datas:
            erros.append(f'site/sitemap.xml: falta {url}')
            continue
        mudou = subprocess.run(['git', 'log', '-1', '--format=%cs', '--', f'site/{p}'],
                               cwd=RAIZ, capture_output=True, text=True).stdout.strip()
        if mudou and datas[url] < mudou:
            erros.append(f'site/sitemap.xml: lastmod {datas[url]} de {url}, e a página '
                         f'mudou em {mudou} — ponha {mudou} no lastmod')
    for url in sorted(set(datas) - urls):
        erros.append(f'site/sitemap.xml: {url} não é página do site')
    return erros + formato_sitemap(base)


NS_SM = '{http://www.sitemaps.org/schemas/sitemap/0.9}'
NS_XHTML = '{http://www.w3.org/1999/xhtml}'


def formato_sitemap(base):
    """O sitemap no formato que o Google aceita, sem depender de rede nem de XSD.

    A ordem dos filhos de <url> é a do esquema do sitemaps.org: loc, lastmod,
    changefreq, priority, e só DEPOIS os elementos de outro namespace. O
    arquivo trazia os xhtml:link logo depois do loc e não validava contra o
    sitemap.xsd. O resto é regra do Google: toda URL debaixo do diretório do
    sitemap, data W3C, e hreflang recíproco, com a própria página, x-default, e
    o mesmo conjunto que a página declara no <head>, com canonical para si."""
    import xml.etree.ElementTree as ET
    erros = []
    bruto = io.open(os.path.join(RAIZ, 'site', 'sitemap.xml'), 'rb').read()
    if bruto.startswith(b'\xef\xbb\xbf') or not bruto.startswith(
            b'<?xml version="1.0" encoding="UTF-8"?>'):
        erros.append('site/sitemap.xml: deve começar por <?xml version="1.0" '
                     'encoding="UTF-8"?>, sem BOM')
    try:
        raiz = ET.fromstring(bruto)
    except ET.ParseError as e:
        return erros + [f'site/sitemap.xml: XML inválido — {e}']
    if raiz.tag != NS_SM + 'urlset':
        return erros + ['site/sitemap.xml: a raiz não é <urlset> do sitemaps.org']
    ordem = ['loc', 'lastmod', 'changefreq', 'priority']
    alternativas = {}
    for u in raiz.findall(NS_SM + 'url'):
        loc = (u.findtext(NS_SM + 'loc') or '').strip()
        nomes = [f.tag.replace(NS_SM, '') if f.tag.startswith(NS_SM) else None for f in u]
        do_sm = [n for n in nomes if n]
        if do_sm != [n for n in ordem if n in do_sm] or not do_sm or do_sm[0] != 'loc' \
                or (None in nomes and any(nomes[nomes.index(None):])):
            erros.append(f'site/sitemap.xml: {loc}: os filhos de <url> fora da ordem do '
                         f'esquema (loc, lastmod, changefreq, priority, e depois xhtml:link)')
        if not loc.startswith(base):
            erros.append(f'site/sitemap.xml: {loc} fora de {base}, onde o sitemap está')
        lm = u.findtext(NS_SM + 'lastmod')
        if lm and not re.fullmatch(r'\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?'
                                   r'(Z|[+-]\d{2}:\d{2}))?', lm):
            erros.append(f'site/sitemap.xml: {loc}: lastmod {lm!r} não é data W3C')
        cf = u.findtext(NS_SM + 'changefreq')
        if cf and cf not in ('always', 'hourly', 'daily', 'weekly', 'monthly',
                             'yearly', 'never'):
            erros.append(f'site/sitemap.xml: {loc}: changefreq {cf!r} inválido')
        pr = u.findtext(NS_SM + 'priority')
        if pr and not (re.fullmatch(r'\d(\.\d+)?', pr) and 0 <= float(pr) <= 1):
            erros.append(f'site/sitemap.xml: {loc}: priority {pr!r} fora de 0.0 a 1.0')
        links = {}
        for l in u.findall(NS_XHTML + 'link'):
            if l.get('rel') != 'alternate' or not l.get('hreflang') or not l.get('href'):
                erros.append(f'site/sitemap.xml: {loc}: xhtml:link sem rel="alternate", '
                             f'hreflang ou href')
                continue
            links[l.get('hreflang')] = l.get('href')
        if links:
            if loc not in [h for k, h in links.items() if k != 'x-default']:
                erros.append(f'site/sitemap.xml: {loc}: o hreflang não inclui a própria página')
            if 'x-default' not in links:
                erros.append(f'site/sitemap.xml: {loc}: hreflang sem x-default')
        alternativas[loc] = links
    for loc, links in alternativas.items():
        for k, h in links.items():
            if h not in alternativas:
                erros.append(f'site/sitemap.xml: {loc}: hreflang {k} aponta para {h}, '
                             f'que não está no sitemap')
            elif alternativas[h] != links:
                erros.append(f'site/sitemap.xml: {loc} e {h} não declaram o mesmo '
                             f'conjunto de hreflang — tem de ser recíproco')
        # o que a página declara no <head> bate com o sitemap
        rel = loc[len(base):]
        arq = os.path.join(RAIZ, 'site', *(rel + 'index.html' if rel.endswith('/') or not rel
                                            else rel).split('/'))
        if not os.path.exists(arq):
            continue
        html = io.open(arq, encoding='utf-8').read()
        canon = re.search(r'<link rel="canonical" href="([^"]+)"', html)
        if not canon or canon.group(1) != loc:
            erros.append(f'site/sitemap.xml: {loc}: a página não tem canonical para si mesma')
        no_head = dict(re.findall(r'<link rel="alternate" hreflang="([^"]+)" href="([^"]+)"',
                                  html))
        if no_head != links:
            erros.append(f'site/sitemap.xml: {loc}: o hreflang do sitemap difere do que '
                         f'a página declara no <head>')
        if re.search(r'<meta[^>]+name="robots"[^>]+noindex', html, re.I):
            erros.append(f'site/sitemap.xml: {loc}: a página tem noindex e está no sitemap')
    if len(bruto) > 50 * 1024 * 1024 or len(alternativas) > 50000:
        erros.append('site/sitemap.xml: acima do limite do Google (50 MB ou 50.000 URLs)')
    return erros


def release(caminho):
    req = urllib.request.Request(API + caminho, headers={
        'User-Agent': 'pl_fpdf-check', 'Accept': 'application/vnd.github+json'})
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {'_erro': e.code}


def online():
    erros = []
    rel, cand = c.ULTIMO_RELEASE, c.ULTIMA_CANDIDATA
    for tag, pre in ((f'v{rel}', False), (cand, True)):
        if not tag:
            continue
        d = release(f'tags/{tag}')
        if '_erro' in d:
            erros.append(f'release {tag}: não encontrado (HTTP {d["_erro"]})')
            continue
        if d.get('prerelease') != pre:
            erros.append(f'release {tag}: prerelease={d.get("prerelease")}, '
                         f'esperado {pre}')
        faltam = ASSETS - {a['name'] for a in d.get('assets', [])}
        if faltam:
            erros.append(f'release {tag}: sem {", ".join(sorted(faltam))}')
    d = release('latest')
    if d.get('tag_name') != f'v{rel}':
        erros.append(f'o "latest" do GitHub é {d.get("tag_name")}, e o site anuncia '
                     f'v{rel} como a estável que o botão de download entrega')
    return erros


def main():
    versao = c.versao_do_package()
    erros = estaticas(versao)
    if '--online' in sys.argv:
        erros += online()
    if erros:
        print('ERRO: o site anuncia uma coisa e o código ou os releases dizem outra:')
        for e in erros:
            print('  ' + e)
        return 1
    cand = f', candidata {c.ULTIMA_CANDIDATA}' if c.ULTIMA_CANDIDATA else ''
    print(f'OK — código {versao}, estável {c.ULTIMO_RELEASE}{cand}: o site e os '
          f'READMEs anunciam isso' + (', e os releases existem como anunciado'
                                       if '--online' in sys.argv else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
