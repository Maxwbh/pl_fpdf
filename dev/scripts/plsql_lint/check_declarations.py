# -*- coding: utf-8 -*-
"""
Verifica a regra do PL/SQL que quebrou a compilação do PL_FPDF:

  Na parte declarativa de um package body, uma vez que aparece o CORPO de um
  subprograma, não se declaram mais itens (variáveis, constantes, tipos).
  Declarar depois disso dá PLS-00103, com uma mensagem que não diz o que está
  errado: "Encontrado o símbolo X quando um dos seguintes símbolos era
  esperado: begin end function pragma procedure".

Como funciona
-------------
Distinguir com precisão o nível do package do interior de um subprograma exige
parear BEGIN/END de verdade — o corpo legado do PL_FPDF encerra vários
subprogramas com `END;` sem nome, o que derruba qualquer heurística mais
simples. Em vez disso, esta verificação usa a **convenção de nomes** do
projeto (Trivadis 4.4): globais e constantes do package começam com `g_`,
`gc_`, `c_` ou `co_` e são declarados na coluna 0. Uma declaração assim depois
do primeiro subprograma é o erro que se quer pegar.

Limite conhecido: não detecta declarações fora de lugar que não sigam a
convenção de prefixo. É uma rede de segurança para o padrão do projeto, não um
parser de PL/SQL.

Uso:
  python scripts/plsql_lint/check_declarations.py src/PL_FPDF.pkb
"""
import re
import sys

# declaração de global/constante do package, na coluna 0
GLOBAL = re.compile(
    r'^(g_|gc_|c_|co_)[a-z_0-9$#]*\s+(constant\s+)?[a-z_0-9$#.%]+\s*(\(|:=|;|\bnot\b)',
    re.I)
# início de um subprograma na coluna 0 (cabeçalho de corpo ou de forward decl)
SUBPROG = re.compile(r'^(procedure|function)\s+([a-z_0-9$#]+)', re.I)


def strip_literals(src):
    """Remove strings e comentários, preservando a numeração de linhas."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "'":
            j = i + 1
            while j < n:
                if src[j] == "'":
                    if j + 1 < n and src[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            out.append("''" + '\n' * src[i:j + 1].count('\n'))
            i = j + 1
        elif src.startswith('--', i):
            j = src.find('\n', i)
            out.append(' ')
            i = n if j < 0 else j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append('\n' * src[i:j].count('\n'))
            i = j
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def check(path):
    raw = open(path, encoding='utf-8').read()
    lines = strip_literals(raw).split('\n')
    raw_lines = raw.split('\n')

    first_body = None
    problems = []
    pending = None

    for ln, line in enumerate(lines, 1):
        if not line or line[0] in ' \t':
            continue

        if pending is not None:
            if re.search(r'\b(is|as)\s*$', line, re.I):
                if first_body is None:
                    first_body = pending
                pending = None
            elif line.rstrip().endswith(';'):
                pending = None                  # declaração antecipada, não corpo
            continue

        m = SUBPROG.match(line)
        if m:
            pending = (ln, m.group(2))
            if re.search(r'\b(is|as)\s*$', line, re.I):
                if first_body is None:
                    first_body = pending
                pending = None
            elif line.rstrip().endswith(';'):
                pending = None
            continue

        if first_body and GLOBAL.match(line):
            problems.append((ln, raw_lines[ln - 1].strip()[:90]))

    return first_body, problems


def main():
    rc = 0
    for path in sys.argv[1:]:
        first_body, problems = check(path)
        if not first_body:
            print(f'{path}: nenhum corpo de subprograma encontrado — nada a checar')
            continue
        if problems:
            rc = 1
            print(f'\n{path}: {len(problems)} declaração(ões) de global DEPOIS do '
                  f'primeiro subprograma (linha {first_body[0]}, {first_body[1]}) '
                  f'— o Oracle rejeita com PLS-00103:')
            for ln, txt in problems:
                print(f'  {path}:{ln}: {txt}')
            print('\n  Mova essas declarações para junto das demais, antes do '
                  'primeiro subprograma do corpo do package.')
        else:
            print(f'{path}: OK — nenhuma global declarada após o primeiro subprograma')
    return rc


if __name__ == '__main__':
    sys.exit(main())
