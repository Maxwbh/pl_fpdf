# -*- coding: utf-8 -*-
"""
Confere que todo subprograma do package body só é chamado depois de estar
visível — definido antes, ou com declaração antecipada (forward declaration).

É o erro PLS-00313 ("'X' não declarado nesta abrangência").

Cobre chamadas COM e SEM parênteses: `aes_init;` é uma chamada tão válida
quanto `f(x)`, e a primeira versão deste verificador só olhava as com
parênteses — deixou passar exatamente esse caso, que só apareceu ao compilar. O PL/SQL resolve
nomes de cima para baixo no corpo do package: chamar algo definido mais abaixo,
sem forward declaration, não compila. O compilador para no primeiro caso, então
sem esta verificação cada rodada de compilação revela só uma dependência.

Escopo: só subprogramas do nível do package (declarados na coluna 0). Funções
locais aninhadas seguem outras regras e ficam de fora.

Subprogramas declarados na spec são visíveis em todo o corpo do package, então
a spec entra na verificação para não gerar falso positivo.

Uso:
  python scripts/plsql_lint/check_call_order.py src/PL_FPDF.pks src/PL_FPDF.pkb
"""
import re
import sys


def strip_literals(src):
    """Remove comentários e strings. Comentários primeiro: uma apóstrofe solta
    num comentário (d'agua) não deve abrir string."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith('--', i):
            j = src.find('\n', i)
            out.append(' ')
            i = n if j < 0 else j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append('\n' * src[i:j].count('\n'))
            i = j
        elif src[i] == "'":
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
        else:
            out.append(src[i])
            i += 1
    return ''.join(out)


# cabeçalho na coluna 0 = subprograma do nível do package
HEAD = re.compile(r'^(procedure|function)\s+([a-z_0-9$#]+)', re.I | re.M)
IDENT = re.compile(r'\b([a-z_][a-z_0-9$#]*)\s*\(', re.I)
# Chamada SEM parênteses: `aes_init;` é uma chamada tão válida quanto `f(x)`, e
# a primeira versão deste lint só olhava as com parênteses — deixou passar
# exatamente um PLS-00313 (pdf_inflate chamando aes_init) que foi parar no
# banco. `END nome;` é removido antes, senão o fim de todo corpo viraria
# "chamada".
FIM = re.compile(r'\bend\s+[a-z_][a-z_0-9$#]*\s*;', re.I)
IDENT_NU = re.compile(r'(?<![.\w])([a-z_][a-z_0-9$#]*)\s*;', re.I)


def main(spec_path, path):
    # tudo que a spec declara é visível em qualquer ponto do corpo
    spec = strip_literals(open(spec_path, encoding='utf-8').read())
    public = {m.group(2).lower() for m in HEAD.finditer(spec)}

    src = strip_literals(open(path, encoding='utf-8').read())
    lines = src.split('\n')

    # 1) mapeia cabeçalhos: nome -> [(linha, é_corpo)]
    heads = []
    for m in HEAD.finditer(src):
        ln = src[:m.start()].count('\n') + 1
        # olha adiante até ';' ou 'is'/'as' para saber se é corpo ou forward decl
        tail = src[m.end():m.end() + 4000]
        depth, is_body = 0, None
        k = 0
        while k < len(tail):
            c = tail[k]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            elif depth == 0:
                if c == ';':
                    is_body = False
                    break
                mm = re.match(r'\b(is|as)\b', tail[k:], re.I)
                if mm and (k == 0 or not tail[k-1].isalnum()):
                    is_body = True
                    break
            k += 1
        if is_body is not None:
            heads.append((ln, m.group(2).lower(), is_body))

    visible = {}     # nome -> linha em que passou a ser visível
    bodies = {}      # nome -> linha do corpo
    for ln, name, is_body in heads:
        if name not in visible:
            visible[name] = ln
        if is_body and name not in bodies:
            bodies[name] = ln
    known = set(bodies) | set(visible)

    # 2) para cada corpo, checa as chamadas a outros subprogramas do package
    ordered = sorted(bodies.items(), key=lambda kv: kv[1])
    problems = []
    for idx, (name, start) in enumerate(ordered):
        end = ordered[idx + 1][1] if idx + 1 < len(ordered) else len(lines)
        for ln in range(start, min(end, len(lines))):
            linha = lines[ln - 1] if ln <= len(lines) else ''
            achados = [m.group(1) for m in IDENT.finditer(linha)]
            achados += [m.group(1) for m in IDENT_NU.finditer(FIM.sub(' ', linha))]
            for bruto in achados:
                callee = bruto.lower()
                if callee == name or callee not in known or callee in public:
                    continue
                if visible[callee] > ln:
                    problems.append((ln, name, callee, visible[callee],
                                     linha.strip()[:80]))

    print(f'{len(bodies)} subprogramas com corpo no nível do package')
    if problems:
        seen = set()
        uniq = []
        for p in problems:
            key = (p[1], p[2])
            if key not in seen:
                seen.add(key)
                uniq.append(p)
        print(f'\n{len(uniq)} chamada(s) a subprograma definido MAIS ABAIXO '
              f'sem declaração antecipada — PLS-00313:')
        for ln, caller, callee, dln, txt in uniq:
            print(f'  {path}:{ln}: {caller} chama {callee} (definido na linha {dln})')
            print(f'      {txt}')
        print('\n  Reordene as definições ou acrescente uma declaração '
              'antecipada antes do primeiro uso.')
        return 1
    print('OK — nenhuma chamada a subprograma definido mais abaixo')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
