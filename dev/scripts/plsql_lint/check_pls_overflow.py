# -*- coding: utf-8 -*-
"""
Acusa multiplicação de `PLS_INTEGER` por constante grande — `ORA-01426`.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
`PLS_INTEGER` tem sinal e estoura em **2 147 483 647**. Valores de 32 bits SEM
sinal — que é o que os formatos binários usam o tempo todo — passam disso, e a
conta que os monta estoura antes de alguém perceber:

    l_res := l_b * 65536 + l_a;     -- Adler-32: l_b vai até 65520
                                    -- 65520 * 65536 = 4 293 918 720  ->  ORA-01426

O erro não aparece na compilação: é de **execução**, chega como
`ORA-01426: numeric overflow` sem nome de variável, e vem embrulhado no
`WHEN OTHERS` de quem chamou — no deflate, apareceu como
`p_enddoc: p_putpages: ORA-01426`, três níveis longe da linha.

É a mesma armadilha do `/P` das permissões: lá o
valor sem sinal vinha de fora, aqui era montado em casa. As duas se resolvem do
mesmo jeito — que a conta aconteça em `NUMBER`.

O que é acusado
---------------
Multiplicação em que um lado é variável declarada `PLS_INTEGER` (ou
`BINARY_INTEGER`) e o outro é um literal inteiro **>= 65536**. É a forma exata
de montar um valor de 32 bits, e a que estoura. Somar não é acusado: `a + b`
com os dois abaixo de 2^31 raramente passa do teto.

Uso:  python scripts/plsql_lint/check_pls_overflow.py src/PL_FPDF.pkb
"""
import io
import re
import sys

LIMITE = 65536

DECL = re.compile(r'^\s*([a-z_][a-z_0-9$#]*)\s+'
                  r'(?:IN\s+OUT\s+NOCOPY\s+|IN\s+OUT\s+|IN\s+|OUT\s+)?'
                  r'(?:PLS_INTEGER|BINARY_INTEGER)\b', re.I | re.M)

# var * literal   e   literal * var
MULT = re.compile(r'([a-z_][a-z_0-9$#]*)\s*\*\s*(\d+)'
                  r'|(\d+)\s*\*\s*([a-z_][a-z_0-9$#]*)', re.I)


def main(caminhos):
    problemas = []
    total = 0
    for caminho in caminhos:
        texto = io.open(caminho, encoding='utf-8').read()
        sem_comentario = re.sub(r'--[^\n]*', '', texto)
        inteiros = {m.group(1).lower() for m in DECL.finditer(sem_comentario)}
        total += len(inteiros)
        for m in MULT.finditer(sem_comentario):
            var = (m.group(1) or m.group(4) or '').lower()
            lit = m.group(2) or m.group(3)
            if var in inteiros and int(lit) >= LIMITE:
                linha = sem_comentario[:m.start()].count('\n') + 1
                problemas.append(
                    f'{caminho}:{linha}: {m.group(0).strip()} — {var} é '
                    f'PLS_INTEGER e o produto pode passar de 2147483647 '
                    f'(ORA-01426, em execução). Faça a conta em NUMBER.')

    if problemas:
        print('\n'.join(problemas))
        print(f'\n{len(problemas)} multiplicação(ões) que podem estourar o '
              f'PLS_INTEGER.')
        return 1

    print(f'OK — nenhuma multiplicação de PLS_INTEGER por constante grande '
          f'({total} variável(is) examinada(s))')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:] or ['src/PL_FPDF.pkb']))
