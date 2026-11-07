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

Com rede (`--online`: antes de publicar o site, e no workflow semanal):

4. O release estável existe, não é pré-lançamento, traz `pl_fpdf_install.sql`
   e `SHA256.txt`, e é ele que o "latest" do GitHub entrega — é o link do botão
   de download.
5. A candidata existe, é pré-lançamento e traz os mesmos dois arquivos.

Uso:  python dev/scripts/gen_docs/check_publicacao.py [--online]
"""
import io
import json
import os
import re
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
