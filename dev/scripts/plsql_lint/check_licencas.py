# -*- coding: utf-8 -*-
"""
Toda declaração de licença do repositório diz a mesma coisa: MIT.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O porte de 2017 saiu sob GPL, e o autor autorizou o relicenciamento sob MIT —
é o que o `LICENSE` registra. Mas texto antigo sobrevive: a revisão de
novembro de 2026 achou o README da extensão PIX/Boleto dizendo que ela era
"distribuída sob a GNU General Public License v2, a mesma do PL_FPDF core",
com selo de licença GPL no topo. Para quem decide se pode usar a biblioteca
numa empresa, isso não é detalhe: é o que faz o jurídico vetar.

O que cobra
-----------
1. O `LICENSE` é MIT.
2. Selo de licença (`img.shields.io/badge/licen...`) só diz MIT.
3. Toda menção a GPL está num contexto **histórico** — o porte de 2017, o
   relicenciamento, "versões antigas deste texto" —, e não como a licença de
   alguma coisa daqui. O contexto é procurado na própria linha e nas duas
   vizinhas.

Uso:  python dev/scripts/plsql_lint/check_licencas.py
"""
import io
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
EXTENSOES = ('.md', '.sql', '.pks', '.pkb', '.html', '.py', '.yml', '.txt')
# as impressoes digitais do fonte original e este proprio arquivo
FORA = ('dev/scripts/plsql_lint/heranca/', 'dev/scripts/plsql_lint/check_licencas.py')

GPL = re.compile(r'\bGPL\b|General Public License', re.I)
HISTORICO = re.compile(r'2017|porte|\bport\b|relicen|vers(õ|o)es antigas|older versions|'
                       r'descende|fonte original|original source', re.I)
SELO = re.compile(r'img\.shields\.io/badge/licen[cs]a?e?-([A-Za-z0-9%. ]+?)-', re.I)


def arquivos():
    try:
        saida = subprocess.run(['git', 'ls-files'], cwd=RAIZ, capture_output=True,
                               text=True, check=True).stdout.split('\n')
    except (OSError, subprocess.CalledProcessError):
        saida = [os.path.relpath(os.path.join(d, f), RAIZ)
                 for d, _, fs in os.walk(RAIZ) if '.git' not in d for f in fs]
    return sorted(f for f in saida if f.endswith(EXTENSOES) and not f.startswith(FORA))


def main():
    erros = []
    with io.open(os.path.join(RAIZ, 'LICENSE'), encoding='utf-8') as f:
        if not f.readline().strip().startswith('MIT License'):
            erros.append('LICENSE: a primeira linha não é "MIT License"')

    for rel in arquivos():
        try:
            with io.open(os.path.join(RAIZ, rel), encoding='utf-8') as f:
                linhas = f.read().splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for n, linha in enumerate(linhas):
            for m in SELO.finditer(linha):
                if m.group(1).strip().upper() != 'MIT':
                    erros.append(f'{rel}:{n + 1}: selo de licença "{m.group(1)}" — '
                                 f'a licença é MIT')
            if GPL.search(linha):
                janela = ' '.join(linhas[max(0, n - 2):n + 3])
                if not HISTORICO.search(janela):
                    erros.append(f'{rel}:{n + 1}: GPL fora de contexto histórico — '
                                 f'{linha.strip()[:90]}')
    if erros:
        print('ERRO: declaração de licença divergente:')
        for e in erros:
            print('  ' + e)
        return 1
    print('OK — LICENSE é MIT, os selos dizem MIT, e GPL só aparece como '
          'história do porte de 2017')
    return 0


if __name__ == '__main__':
    sys.exit(main())
