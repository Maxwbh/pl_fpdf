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


"""Rótulos fixos da página, por idioma.

O texto das APIs vem do Javadoc (PT) ou de `textos_en.py` (EN); o que está aqui
é só a moldura -- cabeçalho de seção e de coluna. Ficam juntos para que a
página em inglês não seja um segundo gerador, e sim o mesmo com outro pacote de
rótulos.
"""
ROTULOS_PT = {
    'sintaxe': 'Sintaxe', 'parametros': 'Parâmetros', 'retorno': 'Retorno',
    'erros': 'Erros', 'exemplo': 'Exemplo', 'veja': 'Veja também',
    'col_param': 'Parâmetro', 'col_tipo': 'Tipo', 'col_padrao': 'Padrão',
    'col_desc': 'Descrição', 'col_codigo': 'Código', 'col_quando': 'Quando',
    'nota': {'note': 'Nota', 'limitation': 'Limitação',
             'process': 'Processo', 'options': 'Opções'},
    'sobrecarga_mesma': ('Na sobrecarga acima os parâmetros são os mesmos, na '
                         'mesma ordem, com outros nomes: '),
    'sobrecarga_outra': ('A sobrecarga acima tem assinatura própria; o bloco '
                         'de documentação é o da primeira.'),
}

ROTULOS_EN = {
    'sintaxe': 'Syntax', 'parametros': 'Parameters', 'retorno': 'Returns',
    'erros': 'Errors', 'exemplo': 'Example', 'veja': 'See also',
    'col_param': 'Parameter', 'col_tipo': 'Type', 'col_padrao': 'Default',
    'col_desc': 'Description', 'col_codigo': 'Code', 'col_quando': 'When',
    'nota': {'note': 'Note', 'limitation': 'Limitation',
             'process': 'Process', 'options': 'Options'},
    'sobrecarga_mesma': ('In the overload above the parameters are the same, '
                         'in the same order, under other names: '),
    'sobrecarga_outra': ('The overload above has a signature of its own; the '
                         'documentation block is the first one’s.'),
}


def artigo(a, sintaxe, veja_tambem, sobrecargas=(), compativel=None,
           rot=ROTULOS_PT):
    nome = a['nome']
    tipo = 'Function' if a['tipo'] == 'function' else 'Procedure'
    alvo = nome.lower()
    o = [f'<article class="api" id="{alvo}">',
         f'<h3>{esc(nome)} <span class="kind">{tipo}</span>'
         f'<a class="anchor" href="#{alvo}" aria-label="link">#</a></h3>',
         f'<p class="d">{esc(a["descricao"])}</p>',
         f'<h5>{rot["sintaxe"]}</h5>',
         '<div class="code"><pre>' + realcar(sintaxe(a)) + '</pre></div>']
    for s in sobrecargas:
        o.append('<div class="code"><pre>' + realcar(sintaxe(s))
                 + '</pre></div>')
    if a['params']:
        tp = {p['name'].lower(): p for p in a['assinatura']['params']}
        o.append(f'<h5>{rot["parametros"]}</h5><div class="tbl"><table>'
                 f'<thead><tr><th>{rot["col_param"]}</th>'
                 f'<th>{rot["col_tipo"]}</th><th>{rot["col_padrao"]}</th>'
                 f'<th>{rot["col_desc"]}</th></tr></thead><tbody>')
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
        for s in sobrecargas:
            if compativel and compativel(a, s):
                o.append('<p class="d">' + rot['sobrecarga_mesma']
                         + ', '.join(f'<code>{esc(p["name"])}</code>'
                                     for p in s['assinatura']['params'])
                         + '.</p>')
            else:
                o.append(f'<p class="d">{rot["sobrecarga_outra"]}</p>')
    if a['retorno']:
        o.append(f'<h5>{rot["retorno"]}</h5>'
                 f'<p class="d">{esc(a["retorno"])}</p>')
    for n in a['notas']:
        titulo = rot['nota'].get(n['tipo'], n['tipo'].capitalize())
        o.append(f'<h5>{titulo}</h5><p class="d">{esc(n["texto"])}</p>')
    if a['erros']:
        o.append(f'<h5>{rot["erros"]}</h5><div class="tbl"><table><thead><tr>'
                 f'<th>{rot["col_codigo"]}</th>'
                 f'<th>{rot["col_quando"]}</th></tr></thead><tbody>')
        for e in a['erros']:
            o.append(f'<tr><td class="pname">ORA{esc(e["codigo"])}</td>'
                     f'<td>{esc(e["texto"])}</td></tr>')
        o.append('</tbody></table></div>')
    if a['exemplo']:
        rec = min(len(x) - len(x.lstrip())
                  for x in a['exemplo'] if x.strip())
        o.append(f'<h5>{rot["exemplo"]}</h5><div class="code"><pre>'
                 + realcar('\n'.join(x[rec:] for x in a['exemplo']))
                 + '</pre></div>')
    vt = veja_tambem.get(nome)
    if vt:
        o.append(f'<p class="see"><b>{rot["veja"]}:</b> ' + ', '.join(
            f'<a href="#{x.lower()}">{esc(x)}</a>' for x in vt) + '</p>')
    o.append('</article>')
    return '\n'.join(o)


def pagina(api, categorias, veja_tambem, sintaxe, compativel=None,
           rot=ROTULOS_PT, molde_arq=None, slug=None, titulo_grupo=None):
    """A página inteira: barra lateral, título de grupo e um artigo por API.

    `titulo_grupo` traduz o nome do grupo (o `slug` NÃO muda com o idioma: o
    `id` é endereço público e as duas páginas apontam para o mesmo lugar).
    """
    slug = slug or {}
    porNome = {a['nome']: a for a in api if not a['sobrecarga']}
    extras = {}
    for a in api:
        if a['sobrecarga']:
            extras.setdefault(a['nome'], []).append(a)

    def rotulo_grupo(cat):
        return titulo_grupo(cat) if titulo_grupo else cat

    lateral = []
    for cat, apis in categorias:
        lateral.append('<div class="side-group"><h4>'
                       + esc(rotulo_grupo(cat)) + '</h4><ul>')
        for n in apis:
            lateral.append(f'<li><a href="#{n.lower()}">{esc(n)}</a></li>')
        lateral.append('</ul></div>')

    # o titulo do grupo sai AQUI, um por categoria. Ja saiu do molde uma vez,
    # e como o molde trazia o primeiro ("Ciclo de vida") escrito a mao, a
    # pagina gerada ficou com UM titulo e 15 grupos sem nenhum -- os artigos
    # seguiam em fila, e so a barra lateral dizia onde um grupo acabava.
    artigos = []
    for cat, apis in categorias:
        ident = slug.get(cat, 'grp-' + re.sub(r'[^a-z0-9]+', '-',
                                              cat.lower()).strip('-'))
        artigos.append(f'<h2 class="grp" id="{ident}">'
                       f'{esc(rotulo_grupo(cat))}</h2>')
        artigos += [artigo(porNome[n], sintaxe, veja_tambem,
                           extras.get(n, []), compativel, rot) for n in apis]
    n_artigos = sum(len(apis) for _, apis in categorias)
    molde = io.open(molde_arq or MOLDE, encoding='utf-8').read()
    for marca in ('{{LATERAL}}', '{{ARTIGOS}}'):
        if marca not in molde:
            raise SystemExit(f'{os.path.basename(molde_arq or MOLDE)} perdeu '
                             f'o marcador {marca}')
    pagina = (molde.replace('{{LATERAL}}', '\n'.join(lateral))
                   .replace('{{ARTIGOS}}', '\n'.join(artigos)))
    conferir_estrutura(pagina, n_artigos, len(categorias))
    return pagina


def conferir_tags(t, onde='a página'):
    """Fecha o que abre. Vale para qualquer página gerada aqui."""
    saldo = {}
    for m in re.finditer(r'<(/?)(aside|div|main|nav|article|section|ul|table|'
                         r'header|footer|tbody|thead|tr|pre)\b', t):
        saldo[m.group(2)] = saldo.get(m.group(2), 0) + (-1 if m.group(1) else 1)
    abertas = {k: v for k, v in saldo.items() if v}
    if abertas:
        raise SystemExit(f'{onde} com tag desbalanceada: {abertas}')


def conferir_estrutura(t, n_artigos, n_grupos=None):
    """A pagina fecha o que abre, e todo link do indice tem destino.

    Existe porque a primeira versao do molde foi extraida cortando do ultimo
    grupo da lateral direto para o `<main>`, e com isso o `</div></aside>` que
    fechava a barra ficou de fora. O HTML continuou "valido" para o navegador
    -- ele fecha sozinho -- mas a navegacao saiu do lugar, e nada acusou.
    """
    conferir_tags(t)

    ids = set(re.findall(r'<article class="api" id="([^"]+)"', t))
    if len(ids) != n_artigos:
        raise SystemExit(f'{n_artigos} artigos e {len(ids)} ids distintos')
    destinos = set(re.findall(r'<a href="#([^"]+)"', t))
    orfaos = sorted(d for d in destinos if d not in ids and d != '')
    if orfaos:
        raise SystemExit(f'link do indice sem artigo: {orfaos[:6]}')

    # um titulo por grupo. A pagina gerada ja saiu com 1 de 16, e nada acusou:
    # o HTML estava valido e os 119 artigos estavam la, so que em fila unica.
    if n_grupos is not None:
        titulos = re.findall(r'<h2 class="grp" id="([^"]+)"', t)
        if len(titulos) != n_grupos or len(set(titulos)) != n_grupos:
            raise SystemExit(f'{n_grupos} grupos e {len(titulos)} títulos '
                             f'<h2 class="grp"> ({len(set(titulos))} ids '
                             f'distintos)')
