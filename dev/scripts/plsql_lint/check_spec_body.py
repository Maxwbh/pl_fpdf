# -*- coding: utf-8 -*-
"""
Confere que todo subprograma declarado na spec tem corpo no package body.

É o erro PLS-00323 ("o subprograma está declarado em uma especificação de
pacote e deve ser definido no texto do pacote"). Ele apareceu no PL_FPDF de um
jeito que nenhuma leitura do código revelava: um `/*` órfão numa linha de
asteriscos abriu um comentário de bloco que só fechou 892 linhas adiante,
engolindo `AddQRCode` e `AddBarcode` inteiros. O texto continuava lá, indentado
e com aparência normal — mas o compilador via comentário.

A verificação remove comentários e strings do body antes de procurar cada
cabeçalho, então um subprograma comentado por acidente é detectado.

Uso:
  python scripts/plsql_lint/check_spec_body.py src/PL_FPDF.pks src/PL_FPDF.pkb
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


DECL = re.compile(r'^\s*(procedure|function)\s+([a-z_0-9$#]+)', re.I | re.M)


def main(spec_path, body_path):
    spec = strip_literals(open(spec_path, encoding='utf-8').read())
    body = strip_literals(open(body_path, encoding='utf-8').read())

    declared = []
    seen = set()
    for m in DECL.finditer(spec):
        name = m.group(2).lower()
        if name not in seen:
            seen.add(name)
            declared.append((name, spec[:m.start()].count('\n') + 1))

    defined = {m.group(2).lower() for m in DECL.finditer(body)}

    missing = [(n, ln) for n, ln in declared if n not in defined]
    repetidos = redeclarados(spec, body)
    indefinidos = tipos_indefinidos(spec, body)
    antecipadas = antecipadas_de_publico(spec, body)

    print(f'spec: {len(declared)} subprogramas declarados | '
          f'body: {len(defined)} com corpo')
    if missing:
        print(f'\n{len(missing)} subprograma(s) SEM corpo no body — PLS-00323:')
        for name, ln in missing:
            print(f'  {spec_path}:{ln}: {name}')
        print('\n  Verifique se o corpo existe e se não caiu dentro de um '
              'comentário de bloco (/* ... */) aberto por engano.')
        return 1
    if repetidos:
        print(f'\n{len(repetidos)} tipo(s)/constante(s) declarado(s) NOS DOIS '
              f'— PLS-00371:')
        for nome, ln in repetidos:
            print(f'  {body_path}:{ln}: {nome} já está na spec')
        print('\n  O body herda o que a spec declara. Redeclarar aborta a '
              'compilação da unidade inteira, e a mensagem aponta uma linha '
              'qualquer depois da segunda declaração.')
        return 1
    if indefinidos:
        print(f'\n{len(indefinidos)} tipo(s) usado(s) e NÃO declarado(s) — '
              f'PLS-00201:')
        for nome, ln in indefinidos:
            print(f'  {body_path}:{ln}: {nome}')
        print('\n  Declare no body (se for privado) ou na spec (se atravessar '
              'a fronteira). Um tipo que ficou no outro package não é herdado.')
        return 1
    if antecipadas:
        print(f'\n{len(antecipadas)} declaração(ões) antecipada(s) de '
              f'subprograma PÚBLICO — PLS-00305:')
        for nome, ln in antecipadas:
            print(f'  {body_path}:{ln}: {nome} já está na spec')
        print('\n  A spec já declara; repetir no body é redeclarar no mesmo '
              'escopo. Declaração antecipada só é necessária para subprograma '
              'PRIVADO chamado antes de ser definido.')
        return 1
    print('OK — todo subprograma da spec tem corpo no body, nada está '
          'declarado duas vezes, todo tipo usado existe e nenhum público tem '
          'declaração antecipada')
    return 0


# TYPE/SUBTYPE/CONSTANT declarados no topo, como instrucao completa. O ', ' no
# fim evita casar com fragmentos como 'type word,' dentro de uma lista.
DUPLA = re.compile(r'^[ \t]*(?:(TYPE|SUBTYPE)\s+([a-z_][a-z_0-9$#]*)\s+IS\b'
                   r'|([a-z_][a-z_0-9$#]*)\s+CONSTANT\s+\w)',
                   re.I | re.M)


def redeclarados(spec, body):
    """[(nome, linha)] declarados na spec E no body — PLS-00371.

    O body herda tudo o que a spec declara. Redeclarar um tipo ou uma constante
    nao e aviso: aborta a analise da unidade inteira, e a linha apontada e a de
    um vizinho qualquer. Aconteceu na separacao do PL_FPDF_UTIL: o tipo tqr
    veio junto na mudanca e ja estava na spec nova.
    """
    def itens(texto):
        return {(m.group(2) or m.group(3)).lower(): m.start()
                for m in DUPLA.finditer(texto)}
    na_spec = itens(spec)
    no_body = itens(body)
    return sorted((n, body[:p].count('\n') + 1)
                  for n, p in no_body.items() if n in na_spec)


# Tipos que o PL/SQL conhece sozinho. O que não estiver aqui nem declarado
# precisa vir de algum lugar.
NATIVOS = {
    'number', 'varchar2', 'varchar', 'char', 'nchar', 'nvarchar2', 'raw',
    'blob', 'clob', 'nclob', 'bfile', 'date', 'timestamp', 'interval',
    'pls_integer', 'binary_integer', 'simple_integer', 'natural', 'positive',
    'integer', 'int', 'smallint', 'decimal', 'numeric', 'real', 'float',
    'double', 'binary_float', 'binary_double', 'boolean', 'long', 'rowid',
    'urowid', 'xmltype', 'json_object_t', 'json_array_t', 'json_element_t',
    'sys_refcursor', 'exception', 'record', 'table', 'ref',
    # tipos do Oracle que aparecem nesta base sem qualificacao
    'uritype', 'json_key_list', 'anydata', 'dbms_lob',
}
# uma declaração de variável ou parâmetro: nome, tipo e o que a fecha
USO_TIPO = re.compile(
    r'^[ \t]*([a-z_][a-z_0-9$#]*)[ \t]+'
    r'(?:CONSTANT[ \t]+)?'
    r'(?:IN[ \t]+OUT[ \t]+NOCOPY[ \t]+|IN[ \t]+OUT[ \t]+|IN[ \t]+|OUT[ \t]+)?'
    r'([a-z_][a-z_0-9$#]*)[ \t]*(?:;|:=|,[ \t]*$|\)[ \t]*(?:IS|AS|;|$))',
    re.I | re.M)
# palavras que abrem instrução e enganam o padrão acima
ABERTURA = {'end', 'begin', 'if', 'elsif', 'else', 'loop', 'while', 'for',
            'exit', 'return', 'raise', 'null', 'exception', 'when', 'then',
            'case', 'declare', 'open', 'close', 'fetch', 'commit', 'rollback',
            'goto', 'continue', 'pragma', 'procedure', 'function', 'type',
            'subtype', 'cursor'}


def tipos_indefinidos(spec, body):
    """[(tipo, linha)] usados no body sem declaração em lugar nenhum.

    O `PLS-00201` chega como "identifier 'X' must be declared" e **aborta a
    analise da unidade inteira** — como o PLS-00371, ele esconde tudo o que vem
    depois. Custou uma rodada na separacao do PL_FPDF_UTIL: os tipos `tpi` e
    `tv4000` ficaram no PL_FPDF, e um package nao herda tipo do outro.
    """
    declarados = {m.group(2).lower()
                  for m in re.finditer(r'^\s*(?:TYPE|SUBTYPE)\s+'
                                       r'([a-z_0-9]+)|^\s*(?:TYPE|SUBTYPE)\s+'
                                       r'([a-z_0-9]+)', spec + body, re.I | re.M)
                  if m.group(2)}
    declarados |= {m.group(1).lower()
                   for m in re.finditer(r'^\s*(?:TYPE|SUBTYPE)\s+([a-z_0-9]+)',
                                        spec + body, re.I | re.M)}
    sem_comentario = re.sub(r'--[^\n]*', '', body)
    fora = {}
    for m in USO_TIPO.finditer(sem_comentario):
        nome, tipo = m.group(1).lower(), m.group(2).lower()
        if nome in ABERTURA or tipo in ABERTURA:
            continue
        if tipo in NATIVOS or tipo in declarados:
            continue
        fora.setdefault(tipo, sem_comentario[:m.start()].count('\n') + 1)
    return sorted(fora.items(), key=lambda x: x[1])


# assinatura terminada em ';' e sem IS/AS: e declaracao antecipada
ANTECIPADA = re.compile(
    r'^[ \t]*(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9$#]*)((?:[^;]|\n)*?);',
    re.I | re.M)


def antecipadas_de_publico(spec, body):
    """[(nome, linha)] antecipacoes no body de subprogramas que a spec declara.

    A spec ja declara; repetir no body e redeclarar no MESMO escopo, e o Oracle
    responde `PLS-00305: previous use of X conflicts with this use` — que, como
    os outros erros de declaracao, aborta a analise da unidade inteira. Custou
    uma rodada na separacao do PL_FPDF_UTIL: tres antecipacoes vieram junto com
    o codigo e passaram a apontar para subprogramas que viraram publicos.
    """
    publicos = {m.group(1).lower()
                for m in re.finditer(r'^\s*(?:FUNCTION|PROCEDURE)\s+'
                                     r'([a-z_0-9]+)', spec, re.I | re.M)}
    sem_comentario = re.sub(r'--[^\n]*', '', body)
    fora = []
    for m in ANTECIPADA.finditer(sem_comentario):
        if re.search(r'\b(IS|AS)\b', m.group(2), re.I):
            continue                       # e um corpo, nao uma antecipacao
        nome = m.group(1).lower()
        if nome in publicos:
            fora.append((nome, sem_comentario[:m.start()].count('\n') + 1))
    return sorted(set(fora), key=lambda x: x[1])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
