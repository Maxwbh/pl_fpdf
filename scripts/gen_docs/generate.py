# -*- coding: utf-8 -*-
"""
Gera a referência da API do PL_FPDF no estilo da documentação Oracle APEX:
uma entrada por função com Descrição, Sintaxe, Parâmetros (com valores possíveis),
Retorno, Erros e Exemplo.

Fontes:
  - src/PL_FPDF.pks        → assinaturas reais (parse_spec.py)
  - scripts/gen_docs/meta.py → descrições, valores possíveis, erros e exemplos

Saídas:
  - docs/API_REFERENCE.md  → referência em Markdown
  - reference.html         → referência navegável no site

Uso:
  python scripts/gen_docs/generate.py
"""
import html
import json
import subprocess
import sys
from collections import OrderedDict

sys.path.insert(0, 'scripts/gen_docs')
from meta import META, GROUPS, SKIP  # noqa: E402

VERSION = '3.2.0'


# ──────────────────────────────── coleta ────────────────────────────────────
def load_apis():
    subprocess.run([sys.executable, 'scripts/gen_docs/parse_spec.py'],
                   check=True, capture_output=True)
    parsed = json.load(open('scripts/gen_docs/parsed.json', encoding='utf-8'))

    merged = OrderedDict()
    for api in parsed:
        key = api['name'].lower()
        if key in SKIP:
            continue
        if key in merged:                       # sobrecarga: acumula assinaturas
            merged[key]['overloads'].append(api)
        else:
            api = dict(api)
            api['overloads'] = [api]
            merged[key] = api

    for key, api in merged.items():
        m = META.get(key, {})
        api['group'] = m.get('group', 'diag')
        api['desc'] = m.get('desc', '')
        api['meta_params'] = m.get('params', {})
        api['returns_desc'] = m.get('returns')
        api['raises'] = m.get('raises', [])
        api['example'] = m.get('example')
        api['see'] = m.get('see', [])
    return merged


def signature(api, overload):
    """Monta a sintaxe formatada da declaração."""
    head = f"PL_FPDF.{api['name']}"
    if not overload['params']:
        line = f"{head};" if overload['kind'] == 'procedure' else f"{head}"
        if overload['returns']:
            line = f"FUNCTION {head}\n    RETURN {overload['returns']};"
        else:
            line = f"PROCEDURE {head};"
        return line
    width = max(len(p['name']) for p in overload['params'])
    lines = []
    for i, p in enumerate(overload['params']):
        default = f" DEFAULT {p['default']}" if p['default'] else ''
        mode = '' if p['mode'] == 'IN' else f"{p['mode']} "
        sep = ',' if i < len(overload['params']) - 1 else ''
        lines.append(f"    {p['name'].ljust(width)} {mode}{p['type']}{default}{sep}")
    kw = 'FUNCTION' if overload['returns'] else 'PROCEDURE'
    out = f"{kw} {head}(\n" + "\n".join(lines) + ")"
    out += f"\n    RETURN {overload['returns']};" if overload['returns'] else ";"
    return out


def param_rows(api):
    """Linhas da tabela de parâmetros: nome, tipo, descrição, valores possíveis, default."""
    rows, seen = [], set()
    for ov in api['overloads']:
        for p in ov['params']:
            if p['name'].lower() in seen:
                continue
            seen.add(p['name'].lower())
            desc, values = api['meta_params'].get(p['name'], ('', ''))
            rows.append({
                'name': p['name'], 'type': p['type'].upper(), 'mode': p['mode'],
                'desc': desc, 'values': values,
                'default': p['default'] or ('—' if p['mode'] == 'IN' else ''),
            })
    return rows


# ──────────────────────────────── markdown ──────────────────────────────────
def gen_markdown(apis):
    groups = OrderedDict((gid, {'title': t, 'apis': []}) for gid, t in GROUPS)
    for key, api in apis.items():
        groups[api['group']]['apis'].append(api)
    for g in groups.values():
        g['apis'].sort(key=lambda a: a['name'].lower())

    out = [f"""# PL_FPDF — Referência da API

**Versão:** {VERSION} | **Oracle:** 19c+ | **Licença:** MIT

Documentação detalhada de cada função e procedure pública do package `PL_FPDF`:
sintaxe, parâmetros com valores possíveis, retorno, erros levantados e exemplo.

> Guia de uso por tarefa: [DOCUMENTATION.md](DOCUMENTATION.md) ·
> Versão navegável: [maxwbh.github.io/pl_fpdf/reference.html](https://maxwbh.github.io/pl_fpdf/reference.html)

## Índice
"""]
    for gid, g in groups.items():
        if not g['apis']:
            continue
        out.append(f"\n**{g['title']}** — " + " · ".join(
            f"[{a['name']}](#{a['name'].lower()})" for a in g['apis']))
    out.append("\n\n---\n")

    for gid, g in groups.items():
        if not g['apis']:
            continue
        out.append(f"\n## {g['title']}\n")
        for api in g['apis']:
            out.append(f"\n### {api['name']}\n")
            if api['desc']:
                out.append(f"\n{api['desc']}\n")
            out.append("\n#### Sintaxe\n")
            for ov in api['overloads']:
                out.append(f"\n```sql\n{signature(api, ov)}\n```\n")
            rows = param_rows(api)
            if rows:
                out.append("\n#### Parâmetros\n")
                out.append("\n| Parâmetro | Tipo | Descrição | Valores possíveis | Padrão |")
                out.append("\n|-----------|------|-----------|-------------------|--------|")
                for r in rows:
                    out.append(f"\n| `{r['name']}` | {r['type']} | {r['desc'] or '—'} | "
                               f"{r['values'] or '—'} | {'`' + r['default'] + '`' if r['default'] not in ('—', '') else '—'} |")
                out.append("\n")
            if api['returns_desc']:
                out.append(f"\n#### Retorno\n\n{api['returns_desc']}\n")
            elif api['returns']:
                out.append(f"\n#### Retorno\n\n{api['returns']}\n")
            if api['raises']:
                out.append("\n#### Erros\n")
                out.append("\n| Código | Condição |")
                out.append("\n|--------|----------|")
                for code, cond in api['raises']:
                    out.append(f"\n| `{code}` | {cond} |")
                out.append("\n")
            if api['example']:
                out.append(f"\n#### Exemplo\n\n```sql\n{api['example']}\n```\n")
            if api['see']:
                out.append("\n**Veja também:** " + ", ".join(
                    f"[{s}](#{s.lower()})" for s in api['see']) + "\n")
            out.append("\n---\n")

    open('docs/API_REFERENCE.md', 'w', encoding='utf-8').write("".join(out))
    return sum(len(g['apis']) for g in groups.values())


# ────────────────────────────────── html ────────────────────────────────────
def sql_html(code):
    """Realce simples de PL/SQL para os blocos de código."""
    import re
    code = html.escape(code)
    kws = (r'\b(DECLARE|BEGIN|END|PROCEDURE|FUNCTION|RETURN|IF|THEN|ELSE|LOOP|FOR|IN|OUT|'
           r'SELECT|INTO|FROM|WHERE|VALUES|INSERT|DEFAULT|IS|NOT|NULL|TRUE|FALSE|BOOLEAN|'
           r'NUMBER|VARCHAR2|BLOB|CLOB|PLS_INTEGER|JSON_OBJECT_T|JSON_ARRAY_T|DATE)\b')
    code = re.sub(r'(--[^\n]*)', r'<span class="c">\1</span>', code)
    code = re.sub(kws, r'<span class="k">\1</span>', code, flags=re.I)
    code = re.sub(r'(&#x27;[^&]*?&#x27;)', r'<span class="s">\1</span>', code)
    return code


def gen_html(apis):
    groups = OrderedDict((gid, {'title': t, 'apis': []}) for gid, t in GROUPS)
    for key, api in apis.items():
        groups[api['group']]['apis'].append(api)
    for g in groups.values():
        g['apis'].sort(key=lambda a: a['name'].lower())

    head = open('scripts/gen_docs/template_head.html', encoding='utf-8').read()
    parts = [head]

    # índice lateral
    parts.append('<aside class="sidebar"><div class="side-in"><input class="filter" '
                 'type="search" placeholder="Filtrar API…" aria-label="Filtrar API">')
    for gid, g in groups.items():
        if not g['apis']:
            continue
        parts.append(f'<div class="side-group"><h4>{g["title"]}</h4><ul>')
        for a in g['apis']:
            parts.append(f'<li><a href="#{a["name"].lower()}">{html.escape(a["name"])}</a></li>')
        parts.append('</ul></div>')
    parts.append('</div></aside>')

    parts.append('<main class="content">')
    parts.append(f'''<header class="page">
      <p class="kicker">v{VERSION} · Oracle 19c+</p>
      <h1>Referência da API</h1>
      <p class="lead">Documentação detalhada de cada função e procedure pública do package
      <code>PL_FPDF</code>: sintaxe, parâmetros com valores possíveis, retorno, erros e exemplo.
      Para um guia por tarefa, veja o <a href="api.html">índice de utilização</a>.</p>
    </header>''')

    for gid, g in groups.items():
        if not g['apis']:
            continue
        parts.append(f'<h2 class="grp" id="grp-{gid}">{g["title"]}</h2>')
        for api in g['apis']:
            aid = api['name'].lower()
            parts.append(f'<article class="api" id="{aid}">')
            kind = 'Function' if api['returns'] else 'Procedure'
            parts.append(f'<h3>{html.escape(api["name"])} <span class="kind">{kind}</span>'
                         f'<a class="anchor" href="#{aid}" aria-label="link">#</a></h3>')
            if api['desc']:
                parts.append(f'<p class="d">{html.escape(api["desc"])}</p>')

            parts.append('<h5>Sintaxe</h5>')
            for ov in api['overloads']:
                parts.append(f'<div class="code"><pre>{sql_html(signature(api, ov))}</pre></div>')

            rows = param_rows(api)
            if rows:
                parts.append('<h5>Parâmetros</h5><div class="tbl"><table><thead><tr>'
                             '<th>Parâmetro</th><th>Tipo</th><th>Descrição</th>'
                             '<th>Valores possíveis</th><th>Padrão</th></tr></thead><tbody>')
                for r in rows:
                    dflt = f'<code>{html.escape(r["default"])}</code>' if r['default'] not in ('—', '') else '—'
                    parts.append(
                        f'<tr><td class="pname">{html.escape(r["name"])}</td>'
                        f'<td class="ptype">{html.escape(r["type"])}</td>'
                        f'<td>{html.escape(r["desc"]) or "—"}</td>'
                        f'<td class="pval">{html.escape(r["values"]) or "—"}</td>'
                        f'<td>{dflt}</td></tr>')
                parts.append('</tbody></table></div>')

            ret = api['returns_desc'] or api['returns']
            if ret:
                parts.append(f'<h5>Retorno</h5><p class="d">{html.escape(ret)}</p>')

            if api['raises']:
                parts.append('<h5>Erros</h5><div class="tbl"><table><thead><tr>'
                             '<th>Código</th><th>Condição</th></tr></thead><tbody>')
                for code, cond in api['raises']:
                    parts.append(f'<tr><td class="pname">{code}</td><td>{html.escape(cond)}</td></tr>')
                parts.append('</tbody></table></div>')

            if api['example']:
                parts.append(f'<h5>Exemplo</h5><div class="code"><pre>{sql_html(api["example"])}</pre></div>')

            if api['see']:
                links = ", ".join(f'<a href="#{s.lower()}">{html.escape(s)}</a>' for s in api['see'])
                parts.append(f'<p class="see"><b>Veja também:</b> {links}</p>')
            parts.append('</article>')

    parts.append('</main>')
    parts.append(open('scripts/gen_docs/template_foot.html', encoding='utf-8').read())
    open('reference.html', 'w', encoding='utf-8').write("\n".join(parts))


if __name__ == '__main__':
    apis = load_apis()
    n = gen_markdown(apis)
    gen_html(apis)
    documented = sum(1 for k in apis if k in META)
    print(f"APIs publicadas: {n} | com metadados curados: {documented} | "
          f"sem metadados: {n - documented}")
