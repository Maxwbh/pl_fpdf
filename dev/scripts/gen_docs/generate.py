# -*- coding: utf-8 -*-
"""
Gera a referência da API em PT a partir do Javadoc da spec.

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

Duas diferenças em relação à página escrita à mão
-------------------------------------------------
1. **A tabela tem 4 colunas, não 5.** A escrita à mão separava "Descrição" de
   "Valores possíveis"; na spec as duas são uma frase só em 256 dos 287
   parâmetros, e inventar o corte perderia texto. Os valores continuam ali,
   dentro da descrição.
2. **A EN não é gerada.** `docs/API_REFERENCE_EN.md` segue à mão, por decisão:
   a spec é só PT-BR desde outubro de 2026 e não há de onde tirar o inglês.

Uso:
  python dev/scripts/gen_docs/generate.py           # escreve as páginas
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

import gerar_html  # noqa: E402
import meta  # noqa: E402


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


MD = do_repo('docs', 'API_REFERENCE.md')
HTML = do_repo('site', 'reference.html')


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


def tabela_params(a):
    if not a['params']:
        return ''
    tipo = {p['name'].lower(): p for p in a['assinatura']['params']}
    out = ['| Parâmetro | Tipo | Padrão | Descrição |',
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


def secao_md(a, sobrecargas=()):
    fora = []
    fora.append(f'### {a["nome"]}\n')
    fora.append(a['descricao'] + '\n')
    fora.append('#### Sintaxe\n')
    fora.append('```sql\n' + sintaxe(a) + '\n```\n')
    for s in sobrecargas:
        fora.append('```sql\n' + sintaxe(s) + '\n```\n')
    if a['params']:
        fora.append('#### Parâmetros\n')
        fora.append(tabela_params(a) + '\n')
        for s in sobrecargas:
            if sobrecarga_compativel(a, s):
                fora.append('Na sobrecarga acima os parâmetros são os mesmos, '
                            'na mesma ordem, com outros nomes: '
                            + ', '.join(f'`{p["name"]}`'
                                        for p in s['assinatura']['params'])
                            + '.\n')
            else:
                fora.append('A sobrecarga acima tem assinatura própria; o '
                            'bloco de documentação é o da primeira.\n')
    if a['retorno']:
        fora.append('#### Retorno\n')
        fora.append(a['retorno'] + '\n')
    for n in a['notas']:
        fora.append('#### Nota\n' if n['tipo'] == 'note'
                    else f'#### {n["tipo"].capitalize()}\n')
        fora.append(n['texto'] + '\n')
    if a['erros']:
        fora.append('#### Erros\n')
        fora.append('| Código | Quando |\n|--------|--------|')
        for e in a['erros']:
            fora.append(f'| `ORA{e["codigo"]}` | {e["texto"]} |')
        fora.append('')
    if a['exemplo']:
        fora.append('#### Exemplo\n')
        rec = min(len(x) - len(x.lstrip()) for x in a['exemplo'])
        fora.append('```sql\n' + '\n'.join(x[rec:] for x in a['exemplo'])
                    + '\n```\n')
    vt = meta.VEJA_TAMBEM.get(a['nome'])
    if vt:
        fora.append('**Veja também:** '
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


def gerar_md(api):
    porNome = {a['nome']: a for a in api if not a['sobrecarga']}
    faltam = [n for _, v in meta.CATEGORIAS for n in v if n not in porNome]
    sobram = [n for n in porNome
              if n not in {x for _, v in meta.CATEGORIAS for x in v}]
    if faltam or sobram:
        raise SystemExit(
            'meta.py e a spec não batem.\n'
            f'  em meta.py e não na spec: {faltam}\n'
            f'  na spec e em nenhum grupo: {sobram}')

    t = [f'# PL_FPDF — Referência da API\n',
         f'**Versão:** {versao()} | **Oracle:** 19c+ | **Licença:** MIT\n',
         'Documentação de cada função e procedure pública: sintaxe, '
         'parâmetros, retorno,\nerros levantados e exemplo.\n',
         '> **Página gerada** do Javadoc de `src/PL_FPDF.pks` e '
         '`src/PL_FPDF_UTIL.pks`.\n'
         '> Não edite aqui: corrija o bloco na spec e rode o gerador.\n',
         '> Guia de uso por tarefa: [DOCUMENTATION.md](DOCUMENTATION.md) · '
         'API Reference (English): [API_REFERENCE_EN.md](API_REFERENCE_EN.md)\n',
         '## Índice\n']
    for cat, apis in meta.CATEGORIAS:
        t.append(f'**{cat}** — ' + ' · '.join(
            f'[{n}](#{n.lower()})' for n in apis) + '  ')
    t.append('\n---\n')
    for cat, apis in meta.CATEGORIAS:
        t.append(f'## {cat}\n')
        grupos = agrupar(api)
        for n in apis:
            t.append(secao_md(porNome[n],
                              [x for x in grupos[n] if x['sobrecarga']]))
            t.append('---\n')
    return '\n'.join(t).replace('\n\n\n', '\n\n') + '\n'


def main():
    api = ler_api()
    n_api = len([a for a in api if not a['sobrecarga']])
    saidas = [(MD, gerar_md(api)),
              (HTML, gerar_html.pagina(api, meta.CATEGORIAS,
                                       meta.VEJA_TAMBEM, sintaxe,
                                       sobrecarga_compativel))]
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
