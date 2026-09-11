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
   versões que divergem. **Comentário de uma linha sobre subprograma público é
   recusado**: com uma linha só não há como acrescentar o *porquê*, então ele
   só pode estar repetindo a descrição. Eram 35, e 22 repetiam mais de metade
   do bloco da spec;
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
   qual se validou;
5. **cabeçalho que nomeia um subprograma fica acima dele**. Um `-- xpto : ...`
   seguido de outro subprograma é comentário órfão, e ele mente em silêncio: o
   leitor lê a descrição de `xpto` e o corpo de outra coisa. Foi o que a
   separação dos packages deixou para trás — `AddQRCode`, `AddBarcode` e
   `ovl_num` foram para o `PL_FPDF` e os cabeçalhos ficaram no
   `PL_FPDF_UTIL`, acima de `bc_ean_check`, de `inf_init` e de `crypto_md5`.

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
# Duas listas, e as duas precisam existir. FUNC pega a prosa por palavra
# funcional; VERBO pega o titulo curto, que nao tem funcional nenhuma --
# `Parse PNG header to extract metadata` tem so um "to" e passava batido.
FUNC = set('''the of and to in with is are be by from on it its or not an
that this which when will can must should would could has have had into only
both all any more than then there here'''.split())
VERBO = set('''parse extract check build write read create remove append
insert returns returning compute calculate convert render draw store holds
needs uses using called given based found missing supported unsupported
invalid empty current first last only must should when this that these those
with into from through after before while each every both either whether
which what where why many much more most less least does did doing gets got
sets puts make makes made take takes'''.split())
LITERAL = re.compile(r"'(?:[^']|'')*'")
ACENTO = re.compile(r'[áéíóúâêôàãõçÁÉÍÓÚÂÊÔÀÃÕÇ]')
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
    # `.first`, `.last`, `.count`: metodo de colecao do PL/SQL, nao prosa.
    t = re.sub(r'\.\w+', ' ', t)
    # Identificador nao e prosa: `pdf_is_ws / pdf_is_alnum` daria dois "is",
    # e `Parametro IN (nao IN OUT)` daria dois "in" -- os dois marcavam
    # portugues como ingles. Token com `_` e token TODO EM MAIUSCULA (palavra
    # reservada do PL/SQL, nome de tipo) ficam de fora da conta.
    p = [w for w in re.findall(r'[A-Za-zÀ-ÿ_]+', t)
         if '_' not in w and not w.isupper()]
    p = [w.lower() for w in p]
    if any(sum(1 for k in range(j, min(j + 4, len(p)))
               if p[k] in FUNC) >= 2 for j in range(len(p))):
        return True
    # sem acento e com dois verbos ingleses: e titulo em ingles
    return (len(p) >= 3 and not ACENTO.search(' '.join(p))
            and sum(1 for w in p if w in VERBO) >= 2)


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


CABECALHO = re.compile(r'^\s*(?:--+|\*)\s*(\w+)\s*:')


def cabecalhos_orfaos(linhas, nomes):
    """Cabeçalho `-- xpto :` que não tem `xpto` logo abaixo.

    Só conta quando `xpto` É um subprograma de um dos dois packages: assim uma
    continuação de prosa (`-- Nota:`, `-- phMax:`) não vira falso positivo.
    """
    out = []
    for n, l in enumerate(linhas):
        m = CABECALHO.match(l)
        if not m or m.group(1).lower() not in nomes:
            continue
        k = n + 1
        while k < len(linhas) and (not linhas[k].strip()
                                   or linhas[k].strip().startswith(('--', '*'))
                                   or linhas[k].strip().endswith('*/')):
            k += 1
        if k >= len(linhas):
            continue
        d = DEF.match(linhas[k])
        if d and d.group(2).lower() != m.group(1).lower():
            out.append((n + 1, m.group(1), d.group(2)))
    return out


def conferir(pks, pkb):
    publicos = {m.group(2).lower() for m in
                re.finditer(r'^\s{0,2}(procedure|function)\s+(\w+)',
                            io.open(do_repo(pks), encoding='utf-8').read(),
                            re.I | re.M)}
    linhas = io.open(do_repo(pkb), encoding='utf-8').read().split('\n')
    falhas = []

    # texto do bloco Javadoc de cada publico, para cruzar com o do body
    esp = io.open(do_repo(pks), encoding='utf-8').read().split('\n')
    bloco_spec = {}
    for i, l in enumerate(esp):
        m = re.match(r'^\s{0,2}(procedure|function)\s+(\w+)', l, re.I)
        if not m:
            continue
        k = i - 1
        while k >= 0 and not esp[k].strip():
            k -= 1
        if k >= 0 and esp[k].strip() == '*/':
            j = k
            while j >= 0 and not esp[j].strip().startswith('/**'):
                j -= 1
            bloco_spec.setdefault(m.group(2).lower(),
                                  ' '.join(x.strip(' *')
                                           for x in esp[j + 1:k]).lower())

    # nomes dos dois packages: um cabecalho pode ter ficado para tras na
    # separacao e nomear subprograma que hoje mora no outro arquivo
    nomes = set()
    for _, outro in PARES:
        nomes |= {m.group(2).lower() for m in
                  re.finditer(r'^\s{0,2}(procedure|function)\s+(\w+)',
                              io.open(do_repo(outro), encoding='utf-8').read(),
                              re.I | re.M)}
    for n, diz, e in cabecalhos_orfaos(linhas, nomes):
        falhas.append((n, f'cabeçalho diz "{diz}" e o subprograma abaixo é '
                          f'"{e}" — comentário órfão'))

    for n, nome in corpos(linhas):
        if nome.lower() in publicos:
            # publico com comentario de UMA linha: so pode estar repetindo a
            # spec, que ja descreve o que ele faz
            k, bloco = n - 2, []
            while k >= 0 and (linhas[k].strip().startswith(('--', '*'))
                              or linhas[k].strip().endswith('*/')):
                bloco.insert(0, linhas[k])
                k -= 1
                if len(bloco) > 30:
                    break
            util = [b for b in bloco if b.strip(' -*/')
                    and not re.match(r'^\s*(-{15,}|\*{15,})\s*$', b)]
            # O que se recusa nao e o TAMANHO, e a REPETICAO: uma linha pode
            # acrescentar (`inflate: tira a casca zlib (RFC 1950)` diz o que a
            # spec nao diz). O que nao pode e repetir a descricao, criando duas
            # versoes que divergem.
            # Curto E repetindo. Um comentario LONGO que divide vocabulario
            # com a spec ainda acrescenta profundidade -- o do ImageFromBlob
            # conta a ACL de rede, o formato lido pela assinatura e a chave do
            # cache, nada disso na spec.
            if util and len(util) <= 2:
                palavras = re.findall(r'\w{5,}', ' '.join(util).lower())
                repete = sum(1 for w in palavras
                             if w in bloco_spec.get(nome.lower(), ''))
                if palavras and repete / len(palavras) > 0.6:
                    falhas.append((n, f'{nome} é público e o comentário do '
                                      f'body repete a descrição da spec — duas '
                                      f'versões que divergem'))
            continue
        # Regua nao e documentacao -- ela comeca com `--` e passava por
        # comentario --, mas tambem nao interrompe a busca: o padrao herdado
        # do porte e `regua / texto / regua / subprograma`, e parar na
        # primeira daria "sem comentario" para quem tem.
        k = n - 2
        while k >= 0 and (not linhas[k].strip()
                          or re.match(r'^\s*(-{20,}|\*{20,})\s*$', linhas[k])):
            k -= 1
        anterior = linhas[k].strip() if k >= 0 else ''
        if not (anterior.startswith('--') or anterior.endswith('*/')
                or anterior.startswith('*')):
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
