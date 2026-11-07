# -*- coding: utf-8 -*-
"""
Os links da documentação para os releases, o instalador e o site respondem.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O `check_links.py` confere os links RELATIVOS e, de propósito, não sai na rede:
um teste que depende da internet a cada push troca um problema barato por um CI
instável. Só que os links que mais importam para quem instala são externos — o
`pl_fpdf_install.sql` de um release, o `SHA256.txt` ao lado, a página da tag,
o `dist/` cru da `master`. Um release renomeado, uma tag apagada e recriada, um
asset que não subiu: o README continua "válido", e quem segue a instrução de
instalação recebe um 404.

Por isso este roda **fora** do push: toda semana e a cada release publicado
(`.github/workflows/links-externos.yml`), e à mão quando se quiser.

O que confere
-------------
Os links para o PRÓPRIO projeto — os que este repositório controla e pode
consertar:

- `github.com/Maxwbh/pl_fpdf/releases/...` (página da tag e download de asset)
- `raw.githubusercontent.com/Maxwbh/pl_fpdf/...`
- `maxwbh.github.io/pl_fpdf/...`

Link para terceiros fica de fora: quebrar não é defeito daqui, e não haveria o
que consertar.

Cada URL é pedida com GET de um byte só (`Range: bytes=0-0`), seguindo os
redirecionamentos — o download de um asset passa por dois —, com três
tentativas. Vale 200 ou 206.

Uso:  python dev/scripts/gen_docs/check_links_externos.py
"""
import glob
import io
import os
import re
import sys
import time
import urllib.error
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
ARQUIVOS = ('*.md', 'docs/*.md', 'extensions/**/*.md', 'site/*.html', 'site/**/*.html')
PROPRIOS = re.compile(
    r'https://(?:github\.com/Maxwbh/pl_fpdf/releases/[^\s)"\'<>`]+'
    r'|raw\.githubusercontent\.com/Maxwbh/pl_fpdf/[^\s)"\'<>`]+'
    r'|maxwbh\.github\.io/pl_fpdf/?[^\s)"\'<>`]*)', re.I)


def urls():
    achadas = {}
    for padrao in ARQUIVOS:
        for caminho in sorted(glob.glob(os.path.join(RAIZ, padrao), recursive=True)):
            with io.open(caminho, encoding='utf-8') as f:
                for n, linha in enumerate(f, 1):
                    for u in PROPRIOS.findall(linha):
                        u = u.rstrip('.,;:*_')
                        achadas.setdefault(u, f'{os.path.relpath(caminho, RAIZ)}:{n}')
    return achadas


def responde(url):
    req = urllib.request.Request(url, headers={
        'Range': 'bytes=0-0', 'User-Agent': 'pl_fpdf-link-check'})
    ultimo = None
    for tentativa in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.status in (200, 206), r.status
        except urllib.error.HTTPError as e:
            ultimo = e.code
            if e.code in (404, 410):
                return False, e.code
        except (urllib.error.URLError, OSError) as e:
            ultimo = getattr(e, 'reason', e)
        time.sleep(2 ** tentativa)
    return False, ultimo


def main():
    todas = urls()
    quebradas = []
    for url, onde in sorted(todas.items()):
        ok, status = responde(url)
        if not ok:
            quebradas.append((url, onde, status))
    if quebradas:
        print('ERRO: links do projeto que não respondem:')
        for url, onde, status in quebradas:
            print(f'  {onde}: {url} -> {status}')
        return 1
    print(f'OK — {len(todas)} links externos do projeto respondem')
    return 0


if __name__ == '__main__':
    sys.exit(main())
