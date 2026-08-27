"""
Valida que toda referência PL_FPDF.<nome> na documentação existe de fato em src/PL_FPDF.pks.

Docs (README, site, docs/) são bloqueantes: um exemplo que não compila é um bug de documentação.
Os testes entram como aviso — divergências ali estão registradas no ROADMAP.
"""
import glob
import json
import re
import subprocess
import sys

subprocess.run([sys.executable, 'scripts/gen_docs/parse_spec.py'], check=True, capture_output=True)
apis = {a['name'].lower() for a in json.load(open('scripts/gen_docs/parsed.json', encoding='utf-8'))}
apis |= {'co_version', 'tv4000a', 'noparam', 'tab_points', 'recttffont', 'recimageblob'}
apis |= {'pks', 'pkb'}  # nomes de arquivo (PL_FPDF.pks / PL_FPDF.pkb)

DOCS = ['README.md', 'README_EN.md', 'index.html', 'api.html', 'reference.html',
        'docs/DOCUMENTATION.md', 'docs/API_REFERENCE.md']
TESTS = sorted(glob.glob('tests/*.sql'))


def strip_comments(txt, path):
    if path.endswith('.sql'):
        txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
        txt = re.sub(r'--[^\n]*', '', txt)
    return txt


def scan(files):
    found = {}
    for f in files:
        try:
            txt = strip_comments(open(f, encoding='utf-8', errors='replace').read(), f)
        except FileNotFoundError:
            continue
        for m in re.finditer(r'PL_FPDF[._]([A-Za-z_][A-Za-z0-9_]*)', txt):
            if m.group(1).lower() not in apis:
                found.setdefault(f, set()).add(m.group(1))
    return found


bad_docs = scan(DOCS)
bad_tests = scan(TESTS)

for f, names in bad_tests.items():
    print(f"AVISO  {f}: referências a APIs inexistentes — {', '.join(sorted(names))}")

if bad_docs:
    print("\nERRO: a documentação referencia APIs que não existem no package:")
    for f, names in bad_docs.items():
        print(f"  {f}: {', '.join(sorted(names))}")
    sys.exit(1)

print(f"OK: documentação consistente com a API ({len(DOCS)} arquivos verificados, "
      f"{len(apis)} identificadores conhecidos)")
