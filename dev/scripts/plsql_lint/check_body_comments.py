# -*- coding: utf-8 -*-
"""
O body documenta o que a spec não documenta, e em PT-BR.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
A spec documenta a API — quem chama, o que passa, que erro leva. Ela não
documenta **203 subprogramas privados**, porque eles não aparecem nela. O body
é o único lugar onde eles podem ser descritos, e em outubro de 2026 **27 não
tinham uma linha**: `ttf_u32`, `pdf_pad_password`, `gmul`, `xtime`,
`qr_bch_version`. Quem abrisse o arquivo achava o nome e o corpo, e tinha de
deduzir o papel.

E os dois comentários não são a mesma coisa. O da spec diz **o quê**; o do body
diz **por quê** — o sintoma, a causa e o conserto. É o registro mais caro desta
base: cada um desses comentários custou uma rodada contra o banco, e é o que a
Trivadis PL/SQL Guidelines 4.4 pede na seção *Comentários* ("explica por quê,
nunca o quê"), com o antipattern declarado logo abaixo: *comentário que repete
o código*.

O que se confere
----------------
1. **todo subprograma privado com corpo tem comentário imediatamente acima**;
   o público não precisa — está documentado na spec, e repetir aqui cria duas
   versões que divergem;
2. **o comentário é PT-BR**: sem marcador ``PT:``/``EN:``, sem par
   ``<português> / <english>`` e sem linha com cara de prosa inglesa. Nome
   próprio e jargão ficam em inglês e não contam — Portrait, WinAnsi, stream,
   xref, deflate, BLOB não têm substituto;
3. **não há código comentado**. O histórico é do Git; uma declaração comentada
   fica para trás sem ninguém reparar, e foi assim que um ``-- type tv1 is
   table of ...`` sobreviveu a três refatorações;
4. **nenhum comentário aponta para arquivo do repositório**. O comentário vive
   sozinho: quem o lê está dentro do código, e mandá-lo abrir outro arquivo
   troca a explicação por um endereço. Endereço envelhece — quando `scripts/`
   e `tests/` viraram `dev/scripts/` e `dev/tests/`, **doze** comentários
   ficaram apontando para o nada, e ponteiro quebrado em comentário não quebra
   nada, então ninguém soube. Consertar o caminho trata o sintoma; a regra
   trata a causa. O que se cita é o que não está no repositório e não se pode
   embutir: a RFC 1951, o FIPS-197, a ISO/IEC 18004, o decodificador contra o
   qual se validou.

O que NÃO se confere, de propósito: se o texto está certo, e se o comentário
diz por quê em vez de o quê. Isso é revisão humana; aqui só se garante que
existe, que é português, e que se basta.

O ``gc_nome_pacote`` da Guideline **não** entra, e a ausência é deliberada.
Ele existe para compor a mensagem de erro junto do ``lc_nome_unidade`` de cada
subprograma, e aqui o rastro vem do ``keeperrorstack``, que preserva a pilha
original e já aponta onde o erro nasceu. Declarar a constante sem ninguém a ler
seria código morto — e o ``check_dead_code.py`` acusaria, como acusou.

Uso:  python dev/scripts/plsql_lint/check_body_comments.py
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


PARES = [('src/PL_FPDF.pks', 'src/PL_FPDF.pkb'),
         ('src/PL_FPDF_UTIL.pks', 'src/PL_FPDF_UTIL.pkb')]

DEF = re.compile(r'^\s{0,2}(procedure|function)\s+(\w+)', re.I)

# Palavra funcional inglesa que NAO existe em portugues. `for`, `so`, `no`,
# `a` e `as` ficaram de fora de proposito: sao palavras dos dois idiomas
# (`for` e verbo, `so` e "so" sem acento) e marcavam prosa portuguesa como
# inglesa.
FUNC = set('''the of and to in with is are be by from on it its or not an
that this which when will can must should would could has have had into only
both all any more than then there here'''.split())
LITERAL = re.compile(r"'(?:[^']|'')*'")
# linha de exemplo/codigo dentro de comentario nao conta como prosa
CODIGO = re.compile(r'^\s*(IF|BEGIN|END|DECLARE|SELECT|INSERT|UPDATE|FOR|LOOP|'
                    r'EXIT|PL_FPDF|DBMS_|UTL_|l_|:=|\{|\}|")', re.I)
# um `/` sem espaco em volta e caminho ou sigla: OS/2, dev/scripts, http/https
BILINGUE = re.compile(r'\S+ / \S+')
# Declaracao ou comando comentado. Tem de TERMINAR em `;`: sem essa ancora,
# prosa legitima casava -- `com RAW: a conversao implicita produzia hexadecimal`
# virava "declaracao comentada" porque tem uma palavra, um tipo e dois-pontos.
COD_COMENTADO = re.compile(
    r'^\s*(procedure|function|type|subtype|cursor|pragma)\s+\w+.*;\s*$|'
    r'^\s*\w+\s+(constant\s+)?(varchar2|number|pls_integer|boolean|blob|clob|'
    r'raw|date)\s*(\([^)]*\))?\s*(:=[^;]*)?;\s*$|'
    r'^\s*(if|for|while|begin|end|select|insert|update|delete)\b[^.]*;\s*$',
    re.I)
# Caminho de arquivo do repositorio dentro de um comentario. Proibido: o
# comentario tem de se bastar.
CAMINHO = re.compile(r'\b((?:dev|docs|src|examples|site|extensions|\.github)'
                     r'/[\w./*-]+)')


def ingles(texto):
    if CODIGO.match(texto):
        return False
    t = LITERAL.sub(' ', texto)
    # Identificador nao e prosa: `pdf_is_ws / pdf_is_alnum` daria dois "is",
    # e `Parametro IN (nao IN OUT)` daria dois "in" -- os dois marcavam
    # portugues como ingles. Token com `_` e token TODO EM MAIUSCULA (palavra
    # reservada do PL/SQL, nome de tipo) ficam de fora da conta.
    p = [w for w in re.findall(r'[A-Za-zÀ-ÿ_]+', t)
         if '_' not in w and not w.isupper()]
    p = [w.lower() for w in p]
    return any(sum(1 for k in range(j, min(j + 4, len(p)))
                   if p[k] in FUNC) >= 2 for j in range(len(p)))


def comentarios(linhas):
    """[(n, texto)] de todo comentário, de linha ou de bloco."""
    out = []
    bloco = False
    for i, l in enumerate(linhas):
        s = l.strip()
        if bloco:
            out.append((i + 1, re.sub(r'^\*+/?|\*+/$', '', s).strip()))
            if '*/' in s:
                bloco = False
            continue
        if s.startswith('/*'):
            bloco = '*/' not in s
            out.append((i + 1, re.sub(r'^/\*+|\*+/$', '', s).strip()))
            continue
        m = re.search(r'--(.*)$', l)
        if m and l[:m.start()].count("'") % 2 == 0:
            out.append((i + 1, m.group(1).strip()))
    return out


def corpos(linhas):
    """[(n, nome)] dos subprogramas com CORPO (não das declarações
    antecipadas, que terminam em ';' antes do 'is'/'as')."""
    out = []
    for n, l in enumerate(linhas):
        m = DEF.match(l)
        if not m:
            continue
        buf, prof, eh = '', 0, None
        for j in range(n, min(n + 40, len(linhas))):
            for c in linhas[j]:
                if c == '(':
                    prof += 1
                elif c == ')':
                    prof -= 1
                elif prof == 0 and c == ';':
                    eh = False
                    break
                if prof == 0:
                    buf += c
            if eh is False:
                break
            if prof == 0 and re.search(r'\b(is|as)\s*$', buf.strip(), re.I):
                eh = True
                break
        if eh:
            out.append((n + 1, m.group(2)))
    return out


def conferir(pks, pkb):
    publicos = {m.group(2).lower() for m in
                re.finditer(r'^\s{0,2}(procedure|function)\s+(\w+)',
                            io.open(do_repo(pks), encoding='utf-8').read(),
                            re.I | re.M)}
    linhas = io.open(do_repo(pkb), encoding='utf-8').read().split('\n')
    falhas = []

    for n, nome in corpos(linhas):
        if nome.lower() in publicos:
            continue
        k = n - 2
        while k >= 0 and not linhas[k].strip():
            k -= 1
        anterior = linhas[k].strip() if k >= 0 else ''
        if not (anterior.startswith('--') or anterior.endswith('*/')):
            falhas.append((n, f'{nome} é privado e não tem comentário acima — '
                              f'a spec não o documenta, então este é o único '
                              f'lugar'))

    for n, texto in comentarios(linhas):
        if not texto:
            continue
        if re.match(r'^(PT|EN):', texto):
            falhas.append((n, 'marcador "PT:"/"EN:" do formato bilíngue'))
        elif BILINGUE.search(texto) and ingles(texto.split(' / ')[-1]):
            falhas.append((n, 'par bilíngue "<português> / <english>": '
                              + texto[:52]))
        elif ingles(texto):
            falhas.append((n, 'comentário com cara de prosa inglesa: '
                              + texto[:52]))
        if COD_COMENTADO.match(texto):
            falhas.append((n, 'código comentado (o histórico é do Git): '
                              + texto[:52]))
        for c in CAMINHO.findall(texto):
            falhas.append((n, f'aponta para "{c.rstrip(chr(46) + chr(44))}" — '
                              f'comentário não remete a documento, ele diz a '
                              f'coisa'))
    return falhas


def main():
    total = 0
    for pks, pkb in PARES:
        falhas = conferir(pks, pkb)
        total += len(falhas)
        if falhas:
            print(f'{pkb}:')
            for linha, motivo in sorted(falhas):
                print(f'  linha {linha}: {motivo}')
    if total:
        print(f'\n{total} problema(s) nos comentários do body. O padrão está '
              f'em docs/MANUTENCAO.md, seção "Comentário de API".')
        return 1
    print('OK — todo subprograma privado tem comentário, em PT-BR, sem código '
          'comentado e sem apontar para arquivo do repositório')
    return 0


if __name__ == '__main__':
    sys.exit(main())
