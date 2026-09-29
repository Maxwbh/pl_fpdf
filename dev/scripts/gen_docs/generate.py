# -*- coding: utf-8 -*-
"""
Gera as oito páginas: a referência da API (PT e EN), o índice de uso e a
página inicial.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
`docs/API_REFERENCE.md` e `site/reference.html` eram escritos à mão: 5.737
linhas dizendo o mesmo que os 137 blocos Javadoc da spec. Nada comparava as
duas fontes, e elas divergiram sem que nada quebrasse:

* **38 APIs** levantavam erro que a referência não listava — `Init` não citava
  `-20001`, `SetFont` não citava `-20005` nem `-20201`, `Cell` não citava
  `-20100`. Quem lesse a página para saber o que capturar recebia lista
  incompleta;
* **18 APIs** do `PL_FPDF_UTIL` não tinham seção nenhuma.

Gerado, isso não acontece: a página passa a ser uma projeção da spec, que o
`check_spec_comments.py` já guarda — todo `@param` bate com a assinatura nos
dois sentidos e na ordem, toda function tem `@return`, e todo código que o
corpo levanta está documentado.

O que gerar NÃO garante
-----------------------
Que o texto esteja **certo**. Um `@param` errado vira uma página errada, só que
consistente. O que protege disso é a revisão humana e o cruzamento entre o
`@raises` e o `raise_application_error` do corpo — não este script.

O que sai de onde
-----------------
| Página | Origem |
|---|---|
| `docs/API_REFERENCE.md`, `site/reference.html` | Javadoc de `src/*.pks` |
| as duas em `_EN`/`site/en/` | idem, com a prosa de `textos_en.py` |
| `site/api.html` e a gêmea em `en/` | `conteudo_api.py` |
| `site/index.html` e a gêmea em `en/` | `conteudo_index.py` |

A spec é só PT-BR, por decisão. O inglês da referência não tem de onde sair
sozinho: vive em `textos_en.py` **pareado** com o português que traduz, e o
gerador para quando o português muda e a tradução fica para trás.

Uma diferença em relação à referência escrita à mão: a tabela de parâmetros tem
**4 colunas, não 5**. A escrita à mão separava "Descrição" de "Valores
possíveis"; na spec as duas são uma frase só em 256 dos 287 parâmetros, e
inventar o corte perderia texto. Os valores continuam ali, dentro da descrição.

Uso:
  python dev/scripts/gen_docs/generate.py           # escreve as oito
  python dev/scripts/gen_docs/generate.py --check   # falha se estiverem fora
                                                    # de dia (é o do CI)
"""
import io
import json
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import conteudo_api  # noqa: E402
import conteudo_index  # noqa: E402
import gerar_api  # noqa: E402
import gerar_index  # noqa: E402
import gerar_html  # noqa: E402
import meta  # noqa: E402
import parse_javadoc  # noqa: E402
import textos_en  # noqa: E402


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


MD = do_repo('docs', 'API_REFERENCE.md')
HTML = do_repo('site', 'reference.html')
API_HTML = do_repo('site', 'api.html')
INDEX = do_repo('site', 'index.html')
INDEX_EN = do_repo('site', 'en', 'index.html')
API_HTML_EN = do_repo('site', 'en', 'api.html')
MD_EN = do_repo('docs', 'API_REFERENCE_EN.md')
HTML_EN = do_repo('site', 'en', 'reference.html')
MOLDE_EN = do_repo('dev', 'scripts', 'gen_docs', 'reference_molde_en.html')


def ler_api():
    """Javadoc (texto) casado com parse_spec (tipos e defaults)."""
    def roda(script):
        r = subprocess.run([sys.executable, do_repo('dev', 'scripts',
                                                    'gen_docs', script)],
                           capture_output=True, text=True, encoding='utf-8')
        if r.returncode:
            raise SystemExit(f'{script} falhou:\n{r.stderr}')
        return r.stdout
    doc = json.loads(roda('parse_javadoc.py'))
    roda('parse_spec.py')
    sig = {}
    for a in json.load(io.open(do_repo('dev', 'scripts', 'gen_docs',
                                       'parsed.json'), encoding='utf-8')):
        sig.setdefault(a['name'].lower(), []).append(a)
    for a in doc:
        cands = sig.get(a['nome'].lower(), [])
        # casa pelos nomes da ASSINATURA, nao pelos do @param: a sobrecarga
        # compartilha o bloco (e portanto os @param) mas tem nomes proprios --
        # o MultiCell procedure e pwidth/ptext onde a function e pw/ptxt. Pelo
        # @param as duas casavam com a mesma assinatura, e a pagina mostrava a
        # primeira duas vezes.
        nomes = [p.lower() for p in a['assinatura_params']]
        a['assinatura'] = next(
            (c for c in cands
             if [p['name'].lower() for p in c['params']] == nomes),
            cands[0] if cands else {'params': [], 'returns': None,
                                    'kind': a['tipo']})
    return doc


def versao():
    t = io.open(do_repo('src', 'PL_FPDF.pks'), encoding='utf-8').read()
    m = re.search(r"co_version\s+CONSTANT\s+VARCHAR2\(\d+\)\s*:=\s*'([^']+)'",
                  t, re.I)
    return m.group(1) if m else '?'


def sintaxe(a):
    s = a['assinatura']
    pref = 'FUNCTION' if a['tipo'] == 'function' else 'PROCEDURE'
    pacote = 'PL_FPDF_UTIL' if a['arquivo'].endswith('UTIL.pks') else 'PL_FPDF'
    if not s['params']:
        linha = f'{pref} {pacote}.{a["nome"]}'
        if s.get('returns'):
            linha += f' RETURN {s["returns"].upper()}'
        return linha + ';'
    larg = max(len(p['name']) for p in s['params'])
    linhas = [f'{pref} {pacote}.{a["nome"]}(']
    for i, p in enumerate(s['params']):
        modo = '' if p['mode'] == 'IN' else p['mode'] + ' '
        txt = f'    {p["name"].ljust(larg)} {modo}{p["type"]}'
        if p.get('default'):
            txt += f' DEFAULT {p["default"]}'
        txt += ',' if i < len(s['params']) - 1 else ')'
        linhas.append(txt)
    if s.get('returns'):
        linhas[-1] += f' RETURN {s["returns"].upper()}'
    linhas[-1] += ';'
    return '\n'.join(linhas)


def tabela_params(a, rot):
    if not a['params']:
        return ''
    tipo = {p['name'].lower(): p for p in a['assinatura']['params']}
    out = [f'| {rot["col_param"]} | {rot["col_tipo"]} | {rot["col_padrao"]} '
           f'| {rot["col_desc"]} |',
           '|-----------|------|--------|-----------|']
    for p in a['params']:
        s = tipo.get(p['nome'].lower(), {})
        t = (s.get('type') or '').upper() or '—'
        d = f'`{s["default"]}`' if s.get('default') else '—'
        desc = p['texto']
        if p.get('itens'):
            desc += ' ' + '; '.join(p['itens'])
        out.append(f'| `{p["nome"]}` | {t} | {d} | {desc} |')
    return '\n'.join(out)


def secao_md(a, sobrecargas=(), rot=gerar_html.ROTULOS_PT):
    fora = []
    fora.append(f'### {a["nome"]}\n')
    fora.append(a['descricao'] + '\n')
    fora.append(f'#### {rot["sintaxe"]}\n')
    fora.append('```sql\n' + sintaxe(a) + '\n```\n')
    for s in sobrecargas:
        fora.append('```sql\n' + sintaxe(s) + '\n```\n')
    if a['params']:
        fora.append(f'#### {rot["parametros"]}\n')
        fora.append(tabela_params(a, rot) + '\n')
        for s in sobrecargas:
            if sobrecarga_compativel(a, s):
                fora.append(rot['sobrecarga_mesma']
                            + ', '.join(f'`{p["name"]}`'
                                        for p in s['assinatura']['params'])
                            + '.\n')
            else:
                fora.append(rot['sobrecarga_outra'] + '\n')
    if a['retorno']:
        fora.append(f'#### {rot["retorno"]}\n')
        fora.append(a['retorno'] + '\n')
    for n in a['notas']:
        fora.append('#### ' + rot['nota'].get(n['tipo'],
                                              n['tipo'].capitalize()) + '\n')
        fora.append(n['texto'] + '\n')
    if a['erros']:
        fora.append(f'#### {rot["erros"]}\n')
        fora.append(f'| {rot["col_codigo"]} | {rot["col_quando"]} |'
                    '\n|--------|--------|')
        for e in a['erros']:
            fora.append(f'| `ORA{e["codigo"]}` | {e["texto"]} |')
        fora.append('')
    if a['exemplo']:
        fora.append(f'#### {rot["exemplo"]}\n')
        rec = min(len(x) - len(x.lstrip())
                  for x in a['exemplo'] if x.strip())
        fora.append('```sql\n' + '\n'.join(x[rec:] for x in a['exemplo'])
                    + '\n```\n')
    vt = meta.VEJA_TAMBEM.get(a['nome'])
    if vt:
        fora.append(f'**{rot["veja"]}:** '
                    + ' · '.join(f'[{x}](#{x.lower()})' for x in vt) + '\n')
    return '\n'.join(fora)


def agrupar(api):
    """{nome: [entrada principal, sobrecargas...]} -- a sobrecarga compartilha
    o texto do bloco, mas tem assinatura propria e precisa aparecer."""
    d = {}
    for a in api:
        d.setdefault(a['nome'], []).append(a)
    return d


def sobrecarga_compativel(base, outra):
    """A sobrecarga pode reusar o texto dos @param da principal?

    So quando a aridade e os tipos batem posicao a posicao. O MultiCell tem
    duas assinaturas com os MESMOS tipos e nomes diferentes (pw/pwidth,
    ptxt/ptext), e ai o texto vale para as duas. Se um dia surgir sobrecarga
    com aridade diferente, ela sai sem tabela em vez de sair com a tabela
    errada.
    """
    a = [p['type'].lower() for p in base['assinatura']['params']]
    b = [p['type'].lower() for p in outra['assinatura']['params']]
    return a == b


def conferir_meta(api):
    """meta.py e a spec dizem a mesma coisa sobre o que entra na página."""
    porNome = {a['nome']: a for a in api if not a['sobrecarga']}
    nos_grupos = {x for _, v in meta.CATEGORIAS for x in v}
    fora = set(meta.FORA_DA_REFERENCIA)
    faltam = [n for n in nos_grupos if n not in porNome]
    # API que nao esta em grupo nenhum E nao foi declarada fora: alguem tem de
    # decidir. Sem isto ela sumiria da pagina em silencio, que foi como as 18
    # do PL_FPDF_UTIL entraram sem ninguem perguntar para quem a pagina e.
    sobram = [n for n in porNome if n not in nos_grupos and n not in fora]
    ambos = sorted(nos_grupos & fora)
    if faltam or sobram or ambos:
        raise SystemExit(
            'meta.py e a spec não batem.\n'
            f'  em meta.py e não na spec: {sorted(faltam)}\n'
            f'  na spec e em nenhum grupo nem em FORA_DA_REFERENCIA: '
            f'{sorted(sobram)}\n'
            f'  em um grupo E em FORA_DA_REFERENCIA: {ambos}')


CABECA_PT = """# PL_FPDF — Referência da API

**Versão:** {v} | **Oracle:** 19c+ | **Licença:** MIT

Documentação de cada função e procedure pública: sintaxe, parâmetros, retorno,
erros levantados e exemplo.

> **Página gerada** do Javadoc de `src/PL_FPDF.pks`.
> Não edite aqui: corrija o bloco na spec e rode o gerador.

> Guia de uso por tarefa: [DOCUMENTATION.md](DOCUMENTATION.md) · \
API Reference (English): [API_REFERENCE_EN.md](API_REFERENCE_EN.md)

## Índice
"""

CABECA_EN = """# PL_FPDF — API Reference

**Version:** {v} | **Oracle:** 19c+ | **License:** MIT

Documentation of every public function and procedure: syntax, parameters,
return, errors raised and an example.

> **Generated page**, from the Javadoc in `src/PL_FPDF.pks` and the English
> text in `dev/scripts/gen_docs/textos_en.py`. Do not edit it here.

> Task-oriented guide: [DOCUMENTATION_EN.md](DOCUMENTATION_EN.md) · \
Referência da API (português): [API_REFERENCE.md](API_REFERENCE.md)

## Index
"""


def gerar_md(api, rot=gerar_html.ROTULOS_PT, cabeca=CABECA_PT,
             titulo_grupo=None):
    porNome = {a['nome']: a for a in api if not a['sobrecarga']}

    def grupo(cat):
        return titulo_grupo(cat) if titulo_grupo else cat

    t = [cabeca.format(v=versao())]
    for cat, apis in meta.CATEGORIAS:
        t.append(f'**{grupo(cat)}** — ' + ' · '.join(
            f'[{n}](#{n.lower()})' for n in apis) + '  ')
    t.append('\n---\n')
    grupos = agrupar(api)
    for cat, apis in meta.CATEGORIAS:
        t.append(f'## {grupo(cat)}\n')
        for n in apis:
            t.append(secao_md(porNome[n],
                              [x for x in grupos[n] if x['sobrecarga']], rot))
            t.append('---\n')
    return '\n'.join(t).replace('\n\n\n', '\n\n') + '\n'


def main():
    api = ler_api()
    conferir_meta(api)
    # o que a PAGINA tem, nao o que a spec tem: as APIs declaradas em
    # FORA_DA_REFERENCIA sao lidas e nao entram
    na_pagina = {x for _, v in meta.CATEGORIAS for x in v}
    n_api = len(na_pagina)
    # a traducao so ve o que sai na pagina: pedir ingles para o que nao e
    # publicado seria trabalho por nada, e o gerador recusa texto sem par
    api_en = textos_en.traduzir([a for a in api if a['nome'] in na_pagina],
                                parse_javadoc.repartir_subitens)

    def em_ingles(cat):
        en = textos_en.CATEGORIAS_EN.get(cat)
        if not en:
            raise SystemExit(f'grupo sem nome em inglês em textos_en.py: '
                             f'{cat}')
        return en

    saidas = [(MD, gerar_md(api)),
              (HTML, gerar_html.pagina(api, meta.CATEGORIAS,
                                       meta.VEJA_TAMBEM, sintaxe,
                                       sobrecarga_compativel,
                                       slug=meta.SLUG_GRUPO)),
              (MD_EN, gerar_md(api_en, gerar_html.ROTULOS_EN, CABECA_EN,
                               em_ingles)),
              (HTML_EN, gerar_html.pagina(api_en, meta.CATEGORIAS,
                                          meta.VEJA_TAMBEM, sintaxe,
                                          sobrecarga_compativel,
                                          gerar_html.ROTULOS_EN, MOLDE_EN,
                                          meta.SLUG_GRUPO, em_ingles)),
              (API_HTML, gerar_api.pagina(conteudo_api.SECOES,
                                          conteudo_api.NOTA_TOPO, 0)),
              (API_HTML_EN, gerar_api.pagina(conteudo_api.SECOES,
                                             conteudo_api.NOTA_TOPO, 1)),
              (INDEX, gerar_index.pagina(conteudo_index, 0, versao())),
              (INDEX_EN, gerar_index.pagina(conteudo_index, 1, versao()))]
    if '--check' in sys.argv:
        fora = [os.path.relpath(c, RAIZ) for c, novo in saidas
                if io.open(c, encoding='utf-8').read() != novo]
        if fora:
            print(', '.join(fora) + ' fora de dia. '
                  'Rode: python dev/scripts/gen_docs/generate.py')
            return 1
        print(f'OK — a referência da API está em dia com o Javadoc da spec '
              f'({n_api} APIs)')
        return 0
    for c, novo in saidas:
        io.open(c, 'w', encoding='utf-8').write(novo)
        print(f'{os.path.relpath(c, RAIZ)}: {n_api} APIs, '
              f'{len(novo.splitlines())} linhas')
    return 0


if __name__ == '__main__':
    sys.exit(main())
