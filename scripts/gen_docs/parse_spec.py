"""Extrai as declarações públicas de src/PL_FPDF.pks (nome, params, tipos, defaults, retorno)."""
import re, json, sys

SRC = 'src/PL_FPDF.pks'

def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'--[^\n]*', '', text)
    return text

def split_params(s):
    """divide por vírgulas de nível 0 (respeita parênteses e aspas)"""
    out, depth, cur, q = [], 0, '', False
    for ch in s:
        if ch == "'": q = not q
        if not q:
            if ch == '(': depth += 1
            elif ch == ')': depth -= 1
            elif ch == ',' and depth == 0:
                out.append(cur); cur = ''; continue
        cur += ch
    if cur.strip(): out.append(cur)
    return [p.strip() for p in out if p.strip()]

def parse_param(p):
    m = re.match(r'^(\w+)\s+(?:(IN\s+OUT|IN|OUT)\s+)?(.*)$', p, re.I | re.S)
    if not m: return None
    name, mode, rest = m.group(1), (m.group(2) or 'IN').upper(), m.group(3).strip()
    dm = re.search(r'\b(?:DEFAULT|:=)\s+(.*)$', rest, re.I | re.S)
    default = dm.group(1).strip() if dm else None
    typ = rest[:dm.start()].strip() if dm else rest
    typ = re.sub(r'\s+', ' ', typ).strip()
    return {'name': name, 'mode': mode, 'type': typ, 'default': default}

def parse():
    text = strip_comments(open(SRC, encoding='utf-8', errors='replace').read())
    # remove o cabeçalho PACKAGE ... AS
    pat = re.compile(r'\b(procedure|function)\s+(\w+)\s*(\(((?:[^()]|\([^()]*\))*)\))?\s*'
                     r'(?:return\s+([\w\.%]+))?\s*(?:deterministic|parallel_enable|result_cache|pipelined|\s)*;',
                     re.I | re.S)
    out = []
    for m in pat.finditer(text):
        kind, name, _, params, ret = m.group(1).lower(), m.group(2), m.group(3), m.group(4), m.group(5)
        plist = [parse_param(p) for p in split_params(params or '')]
        plist = [p for p in plist if p]
        out.append({'kind': kind, 'name': name, 'params': plist,
                    'returns': (ret or '').upper() or None})
    return out

if __name__ == '__main__':
    apis = parse()
    json.dump(apis, open('scripts/gen_docs/parsed.json', 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print(f"declarações extraídas: {len(apis)}")
    dup = {}
    for a in apis: dup[a['name'].lower()] = dup.get(a['name'].lower(), 0) + 1
    print("sobrecargas:", {k: v for k, v in dup.items() if v > 1})
