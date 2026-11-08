# -*- coding: utf-8 -*-
"""
Todo LOB temporário que uma função devolve e liberado por quem a chama.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O `SplitPDF` chamava `blob_to_base64` uma vez por intervalo, guardava o
resultado numa variável, copiava o valor para o JSON e nunca liberava. O
`blob_to_base64` faz `DBMS_LOB.CREATETEMPORARY`, e reatribuir a variável na
volta do laço **não libera** o anterior: cada intervalo deixava para trás um
LOB de duração de SESSÃO.

A primeira tentativa de cobrir isso foi um caso de teste medindo
`V$TEMPORARY_LOBS` antes e depois. Não serve: V$ não esta no schema de quem
roda os testes, e um teste que exige `GRANT` de DBA vira um [SKIP] permanente —
cobertura de mentira. Pior, o vazamento **não e observável** de dentro do
próprio schema: `USER_*` não expõe contagem de LOB temporário, e as instâncias
vazadas não tem locator que se possa passar ao `DBMS_LOB.ISTEMPORARY`.

O que não da para observar em execução da para ler no fonte. Esta verificação
roda sem banco, sem privilégio e sem rede.

O que cobra
-----------
1. Descobre as funções **produtoras**: as que fazem `DBMS_LOB.CREATETEMPORARY`
   sobre a variável que devolvem.
2. Em cada `l_x := produtora(...)`, exige um `DBMS_LOB.FREETEMPORARY(l_x)` no
   mesmo subprograma.

O que NÃO cobra
---------------
Variável DEVOLVIDA pela função: ali o LOB passa a ser do chamador, e liberar
entregaria um locator morto. E o caso do `MergePDFs` e do `ExtractPages`.

Caminho de exceção: se o `FREETEMPORARY` existe mas fica depois de um `RAISE`,
isto aprova. Fluxo completo e analise que esta verificação não faz — ela pega
o esquecimento, que e o caso comum.

Uso:  python dev/scripts/plsql_lint/check_lob_temp.py src/PL_FPDF.pkb
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))

CABECA = re.compile(
    r'^[ \t]*(?:FUNCTION|PROCEDURE)\s+([A-Za-z_][A-Za-z0-9_]*)', re.I | re.M)


def sem_comentarios(texto):
    texto = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group().count('\n'),
                   texto, flags=re.S)
    return re.sub(r'--[^\n]*', '', texto)


def subprogramas(texto):
    """(nome, início, fim) de cada subprograma, pelo próximo cabeçalho."""
    marcas = [(m.start(), m.group(1).lower()) for m in CABECA.finditer(texto)]
    fora = []
    for i, (ini, nome) in enumerate(marcas):
        fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(texto)
        fora.append((nome, ini, fim, texto[ini:fim]))
    return fora


def produtoras(subs):
    """Funções que criam LOB temporário e o devolvem."""
    nomes = set()
    for nome, _i, _f, corpo in subs:
        if not re.search(r'^\s*FUNCTION\b', corpo, re.I | re.M):
            continue
        # O RETURN tem de ser BLOB ou CLOB. Sem esta exigência a regra pegava
        # o getImageFromUrl, que devolve um RECORD com um BLOB dentro: ali o
        # que se libera e o CAMPO (myImg.image_blob), não a variável, e cobrar
        # FREETEMPORARY(myImg) seria pedir código que nem compila.
        tipo = re.search(r'\)\s*RETURN\s+(\w+)\s+IS\b|'
                         r'^\s*FUNCTION\s+\w+\s+RETURN\s+(\w+)\s+IS\b',
                         corpo, re.I | re.M)
        if not tipo:
            continue
        devolve = (tipo.group(1) or tipo.group(2) or '').upper()
        if devolve not in ('BLOB', 'CLOB'):
            continue
        cria = re.search(r'DBMS_LOB\.CREATETEMPORARY\s*\(\s*([A-Za-z_]\w*)',
                         corpo, re.I)
        if cria and re.search(r'\bRETURN\s+' + cria.group(1) + r'\s*;',
                              corpo, re.I):
            nomes.add(nome)
    return nomes


def confere(caminho):
    texto = sem_comentarios(
        io.open(caminho, encoding='utf-8', errors='replace').read())
    subs = subprogramas(texto)
    prods = produtoras(subs)
    if not prods:
        return prods, []

    alvo = re.compile(
        r'\b([A-Za-z_]\w*)\s*:=\s*(?:PL_FPDF\.)?(' + '|'.join(prods) + r')\s*\(',
        re.I)
    faltas = []
    for nome, ini, _f, corpo in subs:
        if nome in prods:
            continue                    # a produtora devolve o seu; não libera
        for m in alvo.finditer(corpo):
            var, prod = m.group(1), m.group(2).lower()
            livre = re.search(r'DBMS_LOB\.FREETEMPORARY\s*\(\s*' + var + r'\s*\)',
                              corpo, re.I)
            # Variável DEVOLVIDA não se libera: o LOB passa a ser do chamador,
            # e um FREETEMPORARY aqui entregaria um locator morto. Sem esta
            # exceção a regra acusava MergePDFs e ExtractPages, que estão
            # certos — e uma lint que grita em código correto e ignorada.
            devolvida = re.search(r'\bRETURN\s+' + var + r'\s*;', corpo, re.I)
            if not livre and not devolvida:
                linha = texto.count('\n', 0, ini + m.start()) + 1
                faltas.append(
                    f'  {os.path.relpath(caminho, RAIZ)}:{linha} '
                    f'em {nome}: {var} recebe o LOB temporario de {prod} '
                    f'e nunca passa por FREETEMPORARY')
    return prods, faltas


def main(alvos):
    if not alvos:
        alvos = [os.path.join(RAIZ, 'src', 'PL_FPDF.pkb'),
                 os.path.join(RAIZ, 'src', 'PL_FPDF_UTIL.pkb')]
    todas, vistas = [], set()
    for a in alvos:
        if not os.path.exists(a):
            print(f'{a}: nao existe')
            return 1
        prods, faltas = confere(a)
        vistas |= prods
        todas += faltas

    if todas:
        print(f'{len(todas)} LOB(s) temporario(s) sem liberacao:')
        for t in todas:
            print(t)
        print('\n  Reatribuir a variavel na volta do laco NAO libera o anterior:')
        print('  o LOB fica ate o fim da SESSAO. Chame '
              'DBMS_LOB.FREETEMPORARY apos usar.')
        return 1

    print(f'OK — {len(vistas)} funcao(oes) que devolve(m) LOB temporario '
          f'({", ".join(sorted(vistas))}), todas as chamadas liberam')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
