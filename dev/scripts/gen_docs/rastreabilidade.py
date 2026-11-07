# -*- coding: utf-8 -*-
"""
Gera docs/TRACEABILITY.md: cada API pública, e o que a exercita.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
A documentação declara o que a biblioteca faz, e a suíte prova uma parte. Sem
um cruzamento explícito, "declarado" e "provado" se afastam em silêncio — e já
se afastaram: a revisão de agosto de 2026 achou que **metade da API pública não
tinha chamador** em teste nenhum, e o `AddLink` levantava `ORA-06531` na
própria declaração havia anos, porque ninguém o chamava.

Este gerador lê as APIs das duas specs e, para cada uma, aponta:

- os arquivos de `dev/tests/` que a chamam (a suíte e os diagnósticos);
- as amostras do `run_tests.py` que a chamam — os PDFs que saem do banco e são
  lidos de volta pelo MuPDF e pelo zxing-cpp.

API sem nenhum dos dois aparece na lista "sem teste". Ela não reprova o CI: é
o retrato honesto, e entrar ou sair da lista muda o arquivo gerado — o que
aparece no diff de quem mexeu.

Confere também que a tabela "O que a suíte cobre" do `COMPATIBILITY.md` (PT e
EN) cita **todo** `test_*.sql` e nenhum que não exista: um arquivo de teste
novo fora da tabela é cobertura que o usuário não fica sabendo que existe.

Tudo estático — lê os fontes, não conecta em banco, não importa o runner.

Uso:  python dev/scripts/gen_docs/rastreabilidade.py           # gera
      python dev/scripts/gen_docs/rastreabilidade.py --check   # CI
"""
import glob
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SAIDA = os.path.join(RAIZ, 'docs', 'TRACEABILITY.md')
PACOTES = ('PL_FPDF', 'PL_FPDF_UTIL')


def ler(*partes):
    with io.open(os.path.join(RAIZ, *partes), encoding='utf-8') as f:
        return f.read()


def sem_comentarios(texto):
    texto = re.sub(r'/\*.*?\*/', '', texto, flags=re.S)
    return re.sub(r'--[^\n]*', '', texto)


def apis(pacote):
    """Nomes públicos da spec, na ordem em que aparecem (sobrecarga vira um)."""
    texto = sem_comentarios(ler('src', pacote + '.pks'))
    vistos = []
    for nome in re.findall(r'(?im)^\s*(?:procedure|function)\s+(\w+)', texto):
        if nome.lower() not in [v.lower() for v in vistos]:
            vistos.append(nome)
    return vistos


def chamadas(texto):
    """{(PACOTE, api_minúscula)} chamadas no texto."""
    return {(p.upper(), n.lower()) for p, n in
            re.findall(r'\b(PL_FPDF_UTIL|PL_FPDF)\s*\.\s*(\w+)', texto, re.I)}


def amostras():
    """{nome_da_amostra: texto} das AMOSTRAS do run_tests.py, lidas do fonte."""
    fonte = ler('dev', 'scripts', 'run_tests.py')
    ini = fonte.index('\nAMOSTRAS = [')
    fim = fonte.index('\n]', ini)
    corpo = fonte[ini:fim]
    partes = re.split(r"\n    \('(\w+)',", corpo)
    saida = {}
    for nome, texto in zip(partes[1::2], partes[2::2]):
        m = re.match(r"\s*exemplo\('(\w+)'\)", texto)
        if m:                          # o desenho mora em examples/<nome>.sql
            texto = ler('examples', m.group(1) + '.sql')
        saida[nome] = texto
    return saida


def testes():
    arqs = sorted(glob.glob(os.path.join(RAIZ, 'dev', 'tests', 'test_*.sql')) +
                  glob.glob(os.path.join(RAIZ, 'dev', 'tests', 'diag_*.sql')))
    return {os.path.basename(a)[:-4]: sem_comentarios(io.open(a, encoding='utf-8').read())
            for a in arqs}


def montar():
    ts = {n: chamadas(t) for n, t in testes().items()}
    am = {n: chamadas(t) for n, t in amostras().items()}
    # O utilitario e chamado por DENTRO do PL_FPDF: a AES e exercitada pelo
    # EncryptPDF, o inflate pelo LoadPDF. Sem esta coluna, a lista "sem teste"
    # misturaria o que nao tem teste nenhum com o que so nao tem teste DIRETO.
    via = chamadas(sem_comentarios(ler('src', 'PL_FPDF.pkb')))
    linhas = ["""# Rastreabilidade: API × testes · Traceability: API × tests

> **Gerado** por `dev/scripts/gen_docs/rastreabilidade.py` — não edite à mão.
> **Generated** by `dev/scripts/gen_docs/rastreabilidade.py` — do not edit.

Para cada API pública, o que a exercita: os arquivos de `dev/tests/` que a
chamam, e as amostras do `run_tests.py` — PDFs gerados no banco e lidos de
volta por leitores independentes. Contar uma chamada não prova que todo
comportamento foi testado; prova que a API não está **sem** nenhum teste.

For each public API, what exercises it: the `dev/tests/` files that call it,
and the `run_tests.py` samples — PDFs generated in the database and read back
by independent readers. Counting a call does not prove every behaviour is
tested; it proves the API is not **without** any test.
"""]
    resumo, sem, indiretas = [], [], []
    for pacote in PACOTES:
        lista = apis(pacote)
        corpo = []
        cobertas = so_via = 0
        for api in lista:
            chave = (pacote, api.lower())
            t = [n for n in sorted(ts) if chave in ts[n]]
            a = [n for n in sorted(am) if chave in am[n]]
            if t or a:
                cobertas += 1
            elif pacote != 'PL_FPDF' and chave in via:
                so_via += 1
                indiretas.append(f'{pacote}.{api}')
                t = ['só via `PL_FPDF` · only through `PL_FPDF`']
            else:
                sem.append(f'{pacote}.{api}')
            corpo.append(f"| `{api}` | {', '.join(x if x.startswith('só') else f'`{x}`' for x in t) or '—'} | "
                         f"{', '.join(f'`{x}`' for x in a) or '—'} |")
        resumo.append(f'| `{pacote}` | {len(lista)} | {cobertas} | {so_via} | '
                      f'{len(lista) - cobertas - so_via} |')
        linhas.append(f'\n## {pacote}\n\n| API | Testes · Tests | Amostras · Samples |\n'
                      f'|-----|----------------|--------------------|\n' + '\n'.join(corpo))
    linhas.insert(1, '\n## Resumo · Summary\n\n'
                     '| Package | APIs | Teste direto · Direct test | Só via PL_FPDF · Only through PL_FPDF | Sem teste · Untested |\n'
                     '|---------|-----:|---------------------------:|--------------------------------------:|---------------------:|\n'
                     + '\n'.join(resumo) + '\n')
    linhas.append('\n## Sem teste · Untested\n\n' +
                  ('\n'.join(f'- `{s}`' for s in sem) if sem else
                   'Nenhuma: toda API pública tem ao menos um teste ou uma amostra. · '
                   'None: every public API has at least one test or sample.'))
    return '\n'.join(linhas) + '\n'


def conferir_tabela_de_cobertura():
    """A tabela do COMPATIBILITY cita todo test_*.sql, e só os que existem."""
    erros = []
    existentes = {n for n in testes() if n.startswith('test_')}
    for doc in ('COMPATIBILITY.md', 'COMPATIBILITY_EN.md'):
        texto = ler('docs', doc)
        citados = set(re.findall(r'`(test_\w+)`', texto))
        for n in sorted(existentes - citados):
            erros.append(f'docs/{doc}: {n}.sql existe e não está na tabela de cobertura')
        for n in sorted(citados - existentes):
            erros.append(f'docs/{doc}: cita {n}, que não existe em dev/tests/')
    return erros


def main():
    novo = montar()
    erros = conferir_tabela_de_cobertura()
    if '--check' in sys.argv:
        atual = io.open(SAIDA, encoding='utf-8').read() if os.path.exists(SAIDA) else ''
        if atual != novo:
            erros.append('docs/TRACEABILITY.md desatualizado. Rode: '
                         'python dev/scripts/gen_docs/rastreabilidade.py')
        if erros:
            print('ERRO:')
            for e in erros:
                print('  ' + e)
            return 1
        print('OK — rastreabilidade em dia, e a tabela de cobertura cita todo test_*.sql')
        return 0
    io.open(SAIDA, 'w', encoding='utf-8').write(novo)
    print(f'docs/TRACEABILITY.md gerado')
    for e in erros:
        print('AVISO: ' + e)
    return 1 if erros else 0


if __name__ == '__main__':
    sys.exit(main())
