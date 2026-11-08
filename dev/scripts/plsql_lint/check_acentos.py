# -*- coding: utf-8 -*-
"""
Português do Brasil, com acento: nos .md e nos comentários do código.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Duas vezes uma leva inteira entrou sem acento — na 3.3.0 e na 3.4.0 —, e uma
terceira, menor, em novembro de 2026. O padrão das três é o mesmo: o texto
nasce sem acento onde ninguém lê como texto (comentário de PL/SQL, comentário
de teste, mensagem de commit) e de lá migra para o que se lê — o ROADMAP, o
HISTORIAS, o CHANGELOG. Quem edita imita o estilo do trecho vizinho, e o
vizinho estava sem acento. A revisão de novembro achou 5.222 palavras sem
acento em 134 arquivos, metade delas no corpo do package.

E nada reclamava: os lints conferem que o comentário é "PT-BR", mas não que
ele tem acento — a heurística que detecta prosa inglesa chegava a tratar
`so`, sem acento, como palavra portuguesa válida. Esta verificação fecha isso.

Como funciona
-------------
Uma palavra é acusada quando **não existe** no dicionário de português e a
forma acentuada dela **existe**: `nao` (não), `versao` (versão), `codigo`
(código). Mais a regra brasileira -cao/-coes → -ção/-ções, que o dicionário,
de Portugal ("secção"), não cobre. Não acusa o que tem duas formas válidas
("e"/"é", "esta"/"está", "pagina" verbo/"página") — isso pede contexto, e fica
para a revisão.

Onde olha: o texto dos .md em português (fora de código, links e URLs), o
texto visível das páginas em português do site, e os comentários — `--` e `/* */` no SQL, `#` e docstrings no Python, `#` no YAML,
`<!-- -->` e `/* */` nos moldes HTML. Código, strings e identificadores não
entram. Fica de fora o que é em inglês, o que é gerado e as impressões
digitais do fonte original.

Uso:  pip install pyspellchecker==0.9.1
      python dev/scripts/plsql_lint/check_acentos.py
"""
import ast
import io
import os
import re
import subprocess
import sys
import tokenize
import unicodedata

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

EXTENSOES = ('.md', '.sql', '.pks', '.pkb', '.py', '.yml', '.html', '.sh')
# em inglês, gerado, ou fonte de terceiro
FORA = re.compile(
    r'(_EN\.md$|^SECURITY\.md$|^CODE_OF_CONDUCT|^\.github/(ISSUE_TEMPLATE|PULL_REQUEST)'
    r'|^extensions/brazilian-payments/README\.md$|^dev/scripts/docx_to_plfpdf/'
    r'|^docs/API_REFERENCE|^docs/TRACEABILITY\.md$|^site/|^dist/|heranca'
    r'|run_all_tests\.sql$|^dev/tests/diag_xrefstm\.sql$)')
# termos técnicos, nomes próprios e inglês que o dicionário "acentuaria"
TECNICOS = {'helvetica', 'cache', 're', 'util', 'index', 'has', 'pure', 'medium',
            'ajax', 'ca', 'pre', 'pos', 'logotipo', 'agua', 'alias', 'estas', 'aria'}
PALAVRA = re.compile(r"(?<![\w./`$@#<'-])([A-Za-z]+)(?![\w`$@(]|\.\w)")


def regioes_sql(t):
    i, n, out, q = 0, len(t), [], False
    while i < n:
        c = t[i]
        if q:
            if c == "'":
                if t[i + 1:i + 2] == "'":
                    i += 2
                    continue
                q = False
            i += 1
            continue
        if c == "'":
            q = True
        elif t.startswith('--', i):
            j = t.find('\n', i)
            j = n if j < 0 else j
            out.append((i + 2, j))
            i = j
            continue
        elif t.startswith('/*', i):
            j = t.find('*/', i + 2)
            j = n if j < 0 else j
            out.append((i + 2, j))
            i = j + 2
            continue
        i += 1
    return out


def regioes_py(t):
    out, off = [], [0]
    for l in t.splitlines(True):
        off.append(off[-1] + len(l))
    pos = lambda r, c: off[r - 1] + c  # noqa: E731
    try:
        for tok in tokenize.generate_tokens(io.StringIO(t).readline):
            if tok.type == tokenize.COMMENT:
                out.append((pos(*tok.start) + 1, pos(*tok.end)))
        arv = ast.parse(t)
        for no in [arv] + [x for x in ast.walk(arv) if isinstance(
                x, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))]:
            d = no.body[0] if no.body else None
            if isinstance(d, ast.Expr) and isinstance(getattr(d, 'value', None), ast.Constant) \
                    and isinstance(d.value.value, str):
                out.append((pos(d.lineno, d.col_offset), pos(d.end_lineno, d.end_col_offset)))
    except (SyntaxError, tokenize.TokenError):
        pass
    return out


def regioes_hash(t):
    out, p = [], 0
    for l in t.splitlines(True):
        m = re.match(r'^(\s*)#', l) or re.search(r'(\s)#\s', l)
        if m and l.count('"', 0, m.end()) % 2 == 0 and l.count("'", 0, m.end()) % 2 == 0:
            out.append((p + m.end(), p + len(l)))
        p += len(l)
    return out


def regioes_md(t):
    fora = [(m.start(), m.end()) for m in re.finditer(
        r'```.*?```|`[^`\n]*`|\]\([^)]*\)|https?://[^\s)>"]+|<[a-zA-Z/][^>]*>', t, re.S)]
    out, p = [], 0
    for a, b in sorted(fora):
        if a > p:
            out.append((p, a))
        p = max(p, b)
    out.append((p, len(t)))
    return out


def regioes(rel, t):
    ext = os.path.splitext(rel)[1]
    if ext == '.md':
        return regioes_md(t)
    if ext in ('.sql', '.pks', '.pkb'):
        return regioes_sql(t)
    if ext == '.py':
        return regioes_py(t)
    if ext == '.yml':
        # os comentários, e os nomes de workflow, job e passo: aparecem na tela
        # do Actions, e entraram sem acento justamente por não serem comentário
        return regioes_hash(t) + [(m.start(1), m.end(1)) for m in
                                  re.finditer(r'(?m)^\s*(?:- )?name:\s*(.+)$', t)]
    if ext == '.sh':
        return regioes_hash(t)
    if ext == '.html':
        return [(m.start(1), m.end(1)) for m in re.finditer(r'<!--(.*?)-->|/\*(.*?)\*/', t, re.S)
                if m.group(1) is not None] + \
               [(m.start(2), m.end(2)) for m in re.finditer(r'<!--(.*?)-->|/\*(.*?)\*/', t, re.S)
                if m.group(2) is not None]
    return []


SITE_PT = ('site/index.html', 'site/api.html', 'site/reference.html')


def texto_visivel(pagina):
    """O texto que o visitante lê numa página do site: fora de código, script e
    estilo, mais os atributos que viram texto (alt, title, aria-label). O site
    sai de strings Python e dos moldes, e não de comentários -- sem esta
    passada, o texto mais lido do projeto era o único que nada conferia."""
    import html.parser

    class P(html.parser.HTMLParser):
        def __init__(s):
            super().__init__()
            s.pula, s.partes = 0, []

        def handle_starttag(s, tag, attrs):
            if tag in ('code', 'pre', 'script', 'style', 'svg', 'kbd'):
                s.pula += 1
            s.partes += [v for k, v in attrs if k in ('alt', 'title', 'aria-label') and v]

        def handle_endtag(s, tag):
            if tag in ('code', 'pre', 'script', 'style', 'svg', 'kbd'):
                s.pula -= 1

        def handle_data(s, d):
            if not s.pula:
                s.partes.append(d)
    p = P()
    p.feed(pagina)
    return ' '.join(p.partes)


def main():
    try:
        from spellchecker import SpellChecker
    except ImportError:
        print('falta o dicionário: pip install pyspellchecker==0.9.1')
        return 2
    freq = SpellChecker(language='pt').word_frequency.dictionary

    def sem(w):
        return ''.join(c for c in unicodedata.normalize('NFD', w)
                       if unicodedata.category(c) != 'Mn')
    acentuada = {}
    for w, f in freq.items():
        k = sem(w)
        if k != w and (k not in acentuada or f > freq[acentuada[k]]):
            acentuada[k] = w

    def sugestao(tok):
        w = tok.lower()
        if w in freq or w in TECNICOS or (tok.isupper() and len(tok) <= 2):
            return None
        if w in acentuada:
            return acentuada[w]
        if len(w) >= 5 and w.endswith('cao'):
            return w[:-3] + 'ção'
        if len(w) >= 6 and w.endswith('coes'):
            return w[:-4] + 'ções'
        return None

    arqs = subprocess.run(['git', 'ls-files'], cwd=RAIZ, capture_output=True,
                          text=True).stdout.split()
    erros, n_arqs = [], 0
    for rel in arqs:
        if not rel.endswith(EXTENSOES) or FORA.search(rel):
            continue
        t = io.open(os.path.join(RAIZ, rel), encoding='utf-8').read()
        regs = regioes(rel, t)
        if rel == 'src/PL_FPDF.pkb' and '-- <larguras-das-fontes' in t:
            a = t.index('-- <larguras-das-fontes')
            b = t.index('-- </larguras-das-fontes>')
            regs = [(x, y) for x, y in regs if y <= a or x >= b]
        n_arqs += 1
        for a, b in regs:
            for m in PALAVRA.finditer(t, a, b):
                s = sugestao(m.group(1))
                if s:
                    linha = t.count('\n', 0, m.start()) + 1
                    erros.append(f'{rel}:{linha}: "{m.group(1)}" -> "{s}"')
    for rel in SITE_PT:
        caminho = os.path.join(RAIZ, rel)
        if not os.path.exists(caminho):
            continue
        n_arqs += 1
        texto = texto_visivel(io.open(caminho, encoding='utf-8').read())
        for m in PALAVRA.finditer(texto):
            s = sugestao(m.group(1))
            if s:
                erros.append(f'{rel} (texto visível): "{m.group(1)}" -> "{s}" '
                             f'em "...{texto[max(0, m.start() - 30):m.end() + 30].strip()}..."')
    if erros:
        print(f'ERRO: {len(erros)} palavra(s) sem acento (português do Brasil):')
        for e in erros[:200]:
            print('  ' + e)
        if len(erros) > 200:
            print(f'  ... e mais {len(erros) - 200}')
        print('Termo técnico ou palavra estrangeira acusada por engano entra em '
              'TECNICOS, no topo deste arquivo.')
        return 1
    print(f'OK — {n_arqs} arquivos, .md em português e comentários do código, '
          f'sem palavra sem acento')
    return 0


if __name__ == '__main__':
    sys.exit(main())
