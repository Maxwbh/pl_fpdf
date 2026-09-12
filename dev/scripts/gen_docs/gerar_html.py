# -*- coding: utf-8 -*-
"""
A página `site/reference.html` a partir do Javadoc da spec.

DOCUMENTO DE MANUTENÇÃO.

O **desenho** da página — cabeçalho, SEO, CSS, navegação, rodapé e o script do
índice lateral — fica em `reference_molde.html` e continua editável à mão: são
210 linhas que não têm nada a ver com a API e que ninguém quer gerar. Daqui
saem as 2.013 que são projeção da spec: a barra lateral e um `<article>` por
subprograma.

O molde tem dois marcadores, `{{LATERAL}}` e `{{ARTIGOS}}`. Mexer no desenho é
editar o molde; mexer no conteúdo é editar o Javadoc.

O realce do SQL é feito aqui, e não no navegador: a página é lida por quem
busca uma assinatura no meio de uma consulta, e depender de JavaScript para
colorir é uma dependência a mais por nada.
"""
import io
import os
import re

MOLDE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     'reference_molde.html')

CHAVE = set("""procedure function return begin end declare is as in out nocopy
varchar2 number pls_integer boolean blob clob raw date default null true false
loop for if then else elsif exception when others raise select into from where
type record table index by constant""".split())


def esc(s):
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            .replace("'", '&#x27;').replace('"', '&quot;'))


def realcar(codigo):
    """Realce do SQL: palavra reservada, literal e comentário.

    A ordem importa: o comentário sai primeiro, senão um `--` dentro dele
    seria varrido de novo; e o literal antes da palavra reservada, senão um
    `'end'` entre aspas viraria palavra-chave.
    """
    saida = []
    for linha in codigo.split('\n'):
        com = ''
        m = re.search(r'--.*$', linha)
        if m:
            com = '<span class="c">' + esc(m.group(0)) + '</span>'
            linha = linha[:m.start()]
        pedacos = re.split(r"('(?:[^']|'')*')", linha)
        fora = ''
        for i, p in enumerate(pedacos):
            if i % 2:
                fora += '<span class="s">' + esc(p) + '</span>'
            else:
                fora += re.sub(
                    r'\b([A-Za-z_]\w*)\b',
                    lambda mm: ('<span class="k">' + esc(mm.group(1))
                                + '</span>') if mm.group(1).lower() in CHAVE
                    else esc(mm.group(1)), p)
        saida.append(fora + com)
    return '\n'.join(saida)


def artigo(a, sintaxe, veja_tambem):
    nome = a['nome']
    tipo = 'Function' if a['tipo'] == 'function' else 'Procedure'
    alvo = nome.lower()
    o = [f'<article class="api" id="{alvo}">',
         f'<h3>{esc(nome)} <span class="kind">{tipo}</span>'
         f'<a class="anchor" href="#{alvo}" aria-label="link">#</a></h3>',
         f'<p class="d">{esc(a["descricao"])}</p>',
         '<h5>Sintaxe</h5>',
         '<div class="code"><pre>' + realcar(sintaxe(a)) + '</pre></div>']
    if a['params']:
        tp = {p['name'].lower(): p for p in a['assinatura']['params']}
        o.append('<h5>Parâmetros</h5><div class="tbl"><table><thead><tr>'
                 '<th>Parâmetro</th><th>Tipo</th><th>Padrão</th>'
                 '<th>Descrição</th></tr></thead><tbody>')
        for p in a['params']:
            s = tp.get(p['nome'].lower(), {})
            ti = (s.get('type') or '').upper() or '—'
            de = (f'<code>{esc(s["default"])}</code>' if s.get('default')
                  else '—')
            desc = esc(p['texto'])
            if p.get('itens'):
                desc += '<br>' + '<br>'.join(esc(x) for x in p['itens'])
            o.append(f'<tr><td class="pname">{esc(p["nome"])}</td>'
                     f'<td class="ptype">{ti}</td><td>{de}</td>'
                     f'<td>{desc}</td></tr>')
        o.append('</tbody></table></div>')
    if a['retorno']:
        o.append(f'<h5>Retorno</h5><p class="d">{esc(a["retorno"])}</p>')
    for n in a['notas']:
        rot = 'Nota' if n['tipo'] == 'note' else n['tipo'].capitalize()
        o.append(f'<h5>{rot}</h5><p class="d">{esc(n["texto"])}</p>')
    if a['erros']:
        o.append('<h5>Erros</h5><div class="tbl"><table><thead><tr>'
                 '<th>Código</th><th>Quando</th></tr></thead><tbody>')
        for e in a['erros']:
            o.append(f'<tr><td class="pname">ORA{esc(e["codigo"])}</td>'
                     f'<td>{esc(e["texto"])}</td></tr>')
        o.append('</tbody></table></div>')
    if a['exemplo']:
        rec = min(len(x) - len(x.lstrip()) for x in a['exemplo'])
        o.append('<h5>Exemplo</h5><div class="code"><pre>'
                 + realcar('\n'.join(x[rec:] for x in a['exemplo']))
                 + '</pre></div>')
    vt = veja_tambem.get(nome)
    if vt:
        o.append('<p class="see"><b>Veja também:</b> ' + ', '.join(
            f'<a href="#{x.lower()}">{esc(x)}</a>' for x in vt) + '</p>')
    o.append('</article>')
    return '\n'.join(o)


def pagina(api, categorias, veja_tambem, sintaxe):
    porNome = {a['nome']: a for a in api if not a['sobrecarga']}
    lateral = []
    for cat, apis in categorias:
        lateral.append(f'<div class="side-group"><h4>{esc(cat)}</h4><ul>')
        for n in apis:
            lateral.append(f'<li><a href="#{n.lower()}">{esc(n)}</a></li>')
        lateral.append('</ul></div>')
    artigos = [artigo(porNome[n], sintaxe, veja_tambem)
               for _, apis in categorias for n in apis]
    molde = io.open(MOLDE, encoding='utf-8').read()
    for marca in ('{{LATERAL}}', '{{ARTIGOS}}'):
        if marca not in molde:
            raise SystemExit(f'reference_molde.html perdeu o marcador {marca}')
    pagina = (molde.replace('{{LATERAL}}', '\n'.join(lateral))
                   .replace('{{ARTIGOS}}', '\n'.join(artigos)))
    conferir_estrutura(pagina, len(artigos))
    return pagina


def conferir_estrutura(t, n_artigos):
    """A pagina fecha o que abre, e todo link do indice tem destino.

    Existe porque a primeira versao do molde foi extraida cortando do ultimo
    grupo da lateral direto para o `<main>`, e com isso o `</div></aside>` que
    fechava a barra ficou de fora. O HTML continuou "valido" para o navegador
    -- ele fecha sozinho -- mas a navegacao saiu do lugar, e nada acusou.
    """
    saldo = {}
    for m in re.finditer(r'<(/?)(aside|div|main|nav|article|ul|table|header|'
                         r'footer|tbody|thead|tr|pre)\b', t):
        saldo[m.group(2)] = saldo.get(m.group(2), 0) + (-1 if m.group(1) else 1)
    abertas = {k: v for k, v in saldo.items() if v}
    if abertas:
        raise SystemExit(f'reference.html com tag desbalanceada: {abertas}')

    ids = set(re.findall(r'<article class="api" id="([^"]+)"', t))
    if len(ids) != n_artigos:
        raise SystemExit(f'{n_artigos} artigos e {len(ids)} ids distintos')
    destinos = set(re.findall(r'<a href="#([^"]+)"', t))
    orfaos = sorted(d for d in destinos if d not in ids and d != '')
    if orfaos:
        raise SystemExit(f'link do indice sem artigo: {orfaos[:6]}')
