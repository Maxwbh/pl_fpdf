# -*- coding: utf-8 -*-
"""
A tabela de verificações do ROADMAP diz o que roda no CI. Confere se é verdade.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O `docs/ROADMAP.md` tem uma seção "Verificações automáticas no CI" que se
apresenta como o registro do que guarda o código. Na revisão de setembro de
2026 ela tinha **21 entradas no CI e 16 na tabela**: `check_escape_pdf`,
`check_heranca`, `check_lob_temp`, `check_undeclared` e `check_v_estatico`
rodavam a cada push e não constavam de lugar nenhum.

Isso é pior do que parece. Quem lê a tabela para saber se um defeito já tem
rede acredita que não tem, e escreve a verificação de novo — ou, o contrário,
remove um passo do CI achando que ninguém depende dele.

A deriva é silenciosa por construção: acrescentar um passo no `ci.yml` faz o
CI passar a guardar mais, e nada obriga a tabela a acompanhar. Nenhum teste
falha, nenhum lint acusa, e a distância só aparece quando alguém compara os
dois à mão — que foi como apareceu.

Como funciona
-------------
Extrai os nomes `check_*.py` citados no `ci.yml` e os citados entre crases no
`ROADMAP.md`, e compara os dois conjuntos **nos dois sentidos**:

- o que roda e não consta: a tabela promete menos do que existe;
- o que consta e não roda: a tabela promete uma rede que não está lá, que é o
  erro mais caro dos dois.

Uso:  python dev/scripts/plsql_lint/check_roadmap_ci.py
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


def main():
    ci = io.open(do_repo('.github', 'workflows', 'ci.yml'),
                 encoding='utf-8').read()
    roadmap = io.open(do_repo('docs', 'ROADMAP.md'), encoding='utf-8').read()

    no_ci = set(re.findall(r'check_[a-z_0-9]+\.py', ci))
    na_tabela = set(re.findall(r'`(check_[a-z_0-9]+\.py)`', roadmap))

    faltam = sorted(no_ci - na_tabela)
    sobram = sorted(na_tabela - no_ci)

    if faltam or sobram:
        print('a tabela do ROADMAP não corresponde ao ci.yml:')
        for n in faltam:
            print(f'  {n}: roda no CI e NÃO está na tabela — quem ler a tabela '
                  f'vai achar que este defeito não tem rede')
        for n in sobram:
            print(f'  {n}: está na tabela e NÃO roda no CI — a tabela promete '
                  f'uma rede que não existe')
        return 1

    print(f'OK — as {len(no_ci)} verificações do ci.yml estão todas na tabela '
          f'do ROADMAP, e a tabela não promete nenhuma a mais')
    return 0


if __name__ == '__main__':
    sys.exit(main())
