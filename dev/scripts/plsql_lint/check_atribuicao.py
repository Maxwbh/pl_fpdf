# -*- coding: utf-8 -*-
"""
Atribuição que começa antes de a anterior terminar: o bloco inteiro não compila.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Um gerador desta base emitia o hexadecimal de uma fonte assim::

    l_hex := '0001...'
    l_hex := l_hex || '000C...'
    l_hex := l_hex || '30F5...';

Cada linha abre uma atribuição nova e **nenhuma termina**, menos a última. Não
é PL/SQL. O Oracle recusa o bloco anônimo INTEIRO com `ORA-06550`, apontando a
linha da segunda atribuição — e o que está errado é a primeira, que ficou sem o
`;`. Sessenta casos que passavam deixaram de rodar por causa de uma linha.

O preço foi uma rodada contra o banco. Nenhuma das outras verificações daqui
analisa sintaxe de PL/SQL — elas olham declaração, ordem de chamada, byte
contra caractere —, então nada pegava isto sem conectar.

O que se confere
----------------
Uma linha que **começa** uma atribuição (`algo :=`) logo depois de uma linha
que não terminou. "Terminou" é: acabar em `;`, ou ser uma abertura de bloco —
`BEGIN`, `THEN`, `ELSE`, `LOOP`, `DECLARE`, `IS`, `AS` —, que é o que
legitimamente precede uma atribuição sem ponto e vírgula antes.

Comentário de fim de linha é retirado antes da comparação: `x := 1;  -- nota`
terminou, e sem isso os quatro arquivos que escrevem assim acusariam à toa.

O que este verificador NÃO faz: analisar PL/SQL. Ele pega **esta** forma, que
custou uma rodada. Continuação legítima de expressão — uma linha que termina em
`||` ou em `(` e segue na próxima — não começa com `algo :=`, então não entra.

Uso:
  python dev/scripts/plsql_lint/check_atribuicao.py dev/tests/*.sql
  python dev/scripts/plsql_lint/check_atribuicao.py        # tests e examples
"""
import glob
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))

ATRIB = re.compile(r'^[A-Za-z_][A-Za-z_0-9.()]*\s*:=')
FIM_OK = re.compile(
    r'(;|\bbegin\b|\bthen\b|\belse\b|\bloop\b|\bdeclare\b|\bis\b|\bas\b)\s*$',
    re.I)


def sem_comentario(linha):
    """Tira o comentário de fim de linha, respeitando o que está entre aspas."""
    fora, i = True, 0
    while i < len(linha) - 1:
        if linha[i] == "'":
            fora = not fora
        elif fora and linha[i] == '-' and linha[i + 1] == '-':
            return linha[:i].rstrip()
        i += 1
    return linha.rstrip()


def conferir(caminho):
    achados = []
    anterior = None
    for n, bruta in enumerate(
            io.open(caminho, encoding='utf-8', errors='replace').read()
            .split('\n'), 1):
        linha = sem_comentario(bruta.strip())
        if not linha:
            continue
        if ATRIB.match(linha) and anterior and not FIM_OK.search(anterior):
            achados.append((n, anterior, linha))
        anterior = linha
    return achados


def main():
    alvos = sys.argv[1:]
    if not alvos:
        alvos = (sorted(glob.glob(os.path.join(RAIZ, 'dev', 'tests', '*.sql')))
                 + sorted(glob.glob(os.path.join(RAIZ, 'examples', '*.sql'))))
        alvos = [a for a in alvos if not a.endswith('run_all_tests.sql')]

    total = 0
    for caminho in alvos:
        for n, anterior, linha in conferir(caminho):
            total += 1
            rel = os.path.relpath(caminho, RAIZ)
            print(f'{rel}:{n}: atribuicao comeca e a linha anterior nao '
                  f'terminou — falta o ";"')
            print(f'    anterior: {anterior[:72]}')
            print(f'    esta:     {linha[:72]}')

    if total:
        print(f'\n{total} atribuicao(oes) sem terminador. O Oracle recusa o '
              f'BLOCO INTEIRO com ORA-06550, e aponta a linha de baixo.')
        return 1
    print(f'OK — nenhuma atribuicao comecando antes de a anterior terminar '
          f'({len(alvos)} arquivo(s))')
    return 0


if __name__ == '__main__':
    sys.exit(main())
