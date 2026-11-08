# -*- coding: utf-8 -*-
"""
Os exemplos PL/SQL da documentação, prontos para rodar contra o banco.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Exemplo de documentação que não compila é bug de documentação, e o pior tipo:
quem copia acredita no texto. A revisão de novembro de 2026 achou o exemplo de
`EncryptPDF` usando duas variáveis que ele não declarava, e o de boleto da
extensão falhando com o fator de vencimento — o primeiro só aparece ao
compilar, o segundo só ao executar.

Este módulo extrai, dos guias de quem usa, cada bloco anônimo completo
(`DECLARE`/`BEGIN`) dos trechos ```sql. O `run_tests.py` os executa num
schema de teste, um a um, e desfaz o que fizeram (`ROLLBACK`). O
`check_exemplos_doc.py`, no CI, confere sem banco que nenhum bloco que não tem
como rodar sozinho ficou sem a marca.

A marca
-------
Um bloco que depende do que o schema de teste não tem — uma tabela do usuário,
o gateway OWA, o APEX — é ilustrativo. Ele leva, na linha imediatamente acima
da cerca, um comentário HTML com o motivo:

    <!-- exemplo-ilustrativo: lê de uma tabela do usuário -->
    ```sql

O comentário não aparece na página renderizada. Bloco com marca não é
executado; bloco sem marca tem de rodar.

Uso:  python dev/scripts/exemplos_doc.py   # lista o que seria executado
"""
import io
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DOCS = ['README.md', 'README_EN.md'] + [
    f'docs/{n}{s}.md'
    for n in ('INSTALLATION', 'COMPATIBILITY', 'DOCUMENTATION', 'MIGRATION',
              'TROUBLESHOOTING')
    for s in ('', '_EN')]

MARCA = re.compile(r'^\s*<!--\s*exemplo-ilustrativo:\s*(.*?)\s*-->\s*$')
INICIO = re.compile(r'(?is)^(?:\s*--[^\n]*\n)*\s*(DECLARE|BEGIN)\b')


def blocos(rel):
    """[{arquivo, linha, código, motivo}] dos blocos anônimos de um guia.

    `motivo` é o texto da marca, ou None quando o bloco deve rodar. Um trecho
    ```sql com vários blocos separados por `/` dá um item por bloco.
    """
    with io.open(os.path.join(RAIZ, rel), encoding='utf-8') as f:
        linhas = f.read().splitlines()
    achados = []
    i = 0
    while i < len(linhas):
        if linhas[i].startswith('```sql'):
            anterior = linhas[i - 1] if i else ''
            m = MARCA.match(anterior)
            motivo = m.group(1) if m else None
            j = i + 1
            corpo, inicio = [], j + 1
            while j < len(linhas) and not linhas[j].startswith('```'):
                if re.match(r'^/\s*$', linhas[j]):
                    _guardar(achados, rel, inicio, corpo, motivo)
                    corpo, inicio = [], j + 2
                else:
                    corpo.append(linhas[j])
                j += 1
            _guardar(achados, rel, inicio, corpo, motivo)
            i = j
        i += 1
    return achados


def _guardar(achados, rel, linha, corpo, motivo):
    codigo = '\n'.join(corpo).strip()
    if INICIO.match(codigo):
        achados.append({'arquivo': rel, 'linha': linha, 'codigo': codigo,
                        'motivo': motivo})


def marcas(rel):
    """Quantas marcas o guia tem, e quais não estão acima de uma cerca ```sql."""
    with io.open(os.path.join(RAIZ, rel), encoding='utf-8') as f:
        linhas = f.read().splitlines()
    total, soltas = 0, []
    for n, l in enumerate(linhas):
        if MARCA.match(l):
            total += 1
            if n + 1 >= len(linhas) or not linhas[n + 1].startswith('```sql'):
                soltas.append(n + 1)
    return total, soltas


def todos():
    return [b for rel in DOCS for b in blocos(rel)]


if __name__ == '__main__':
    for b in todos():
        estado = f'ilustrativo ({b["motivo"]})' if b['motivo'] else 'roda'
        print(f'{b["arquivo"]}:{b["linha"]}: {estado}')
