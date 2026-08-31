# -*- coding: utf-8 -*-
"""
Garante que cada faixa de ORA-208xx pertence a um assunto só.

Por que existe
-------------
Os códigos cresceram por acréscimo, sem dono, e acabaram colidindo entre
domínios que não têm nada a ver um com o outro:

    ORA-20843  "AddQRCode: conteudo vazio"     E  "xref em stream nao suportada"
    ORA-20844  "AddQRCode: tamanho invalido"   E  "objeto de pagina nao e dicionario"
    ORA-20846  "CODE128 aceita ASCII 32..126"  E  tres erros de /Resources
    ORA-20850  "AddBarcode: codigo vazio"      E  "metodo de criptografia invalido"
    ORA-20851  "AddBarcode: largura/altura"    E  "senha de usuario obrigatoria"
    ORA-20852  "Simbologia nao suportada"      E  "falha na criptografia"

Quem trata a exceção pelo código não conseguia distinguir, e a documentação
listava só um dos significados. Em agosto/2026 o QR e os códigos de barras
foram movidos para faixas próprias — o lado que ninguém tinha publicado, já que
`meta.py` não documentava erro algum para `AddQRCode` e `AddBarcode`.

Este verificador existe para que a separação não se desfaça no próximo
acréscimo.

Regra 1 — cada faixa tem um dono
--------------------------------
O dono do código é o subprograma que o levanta:

    qr_*, AddQRCode        ->  -20870 .. -20879
    bc_*, AddBarcode       ->  -20880 .. -20889
    qualquer outro         ->  fora dessas duas faixas

Regra 2 — código documentado é código que existe
------------------------------------------------
A revisão de agosto/2026 achou **seis** códigos anunciados na spec e em
`meta.py` que nenhum subprograma levanta: -20102, -20105, -20220, -20221,
-20222 e -20822. Prometer um erro que nunca chega é pior que não documentá-lo —
quem trata a exceção escreve um `WHEN` que nunca dispara e acredita estar
coberto. Aconteceu por deriva: o código foi renumerado ou o caminho que o
levantava saiu, e a documentação ficou.

O contrário (levantar sem documentar) NÃO é acusado aqui: nem todo erro interno
precisa ir para a referência da API.

Uso:  python scripts/plsql_lint/check_error_codes.py src/PL_FPDF.pkb
      (a segunda regra só roda quando o .pks e o meta.py são alcançáveis)
"""
import io
import os
import re
import sys

# Ancorado na RAIZ a partir deste arquivo. Era caminho relativo ao diretorio
# atual, e o `except IOError: continue` abaixo transformava "rodei de outro
# lugar" em "nao ha nada a conferir" — passava sem olhar. E o mesmo defeito que
# o check_links.py ja tinha pago.
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))

CABECALHO = re.compile(r'^[ \t]{0,2}(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9]*)',
                       re.I | re.M)
RAISE = re.compile(r'raise_application_error\s*\(\s*(-\d+)\s*,\s*(.{0,60})',
                   re.I | re.S)

FAIXAS = [
    ('QR Code',         (-20879, -20870), ('qr_', 'addqrcode')),
    ('codigo de barras', (-20889, -20880), ('bc_', 'addbarcode')),
]


def dono_de(marcas, pos):
    """Subprograma que contém a posição."""
    nome = '(nivel do package)'
    for ini, n in marcas:
        if ini <= pos:
            nome = n
        else:
            break
    return nome


def dominio(sub):
    for rotulo, _, prefixos in FAIXAS:
        if sub.startswith(prefixos):
            return rotulo
    return None


CITADO_PKS = re.compile(r'^\*\s+(-\d{5}):', re.M)

# RAISE_APPLICATION_ERROR e PROCEDURE: nao pode aparecer dentro de expressao.
# Escrever `l_x := CASE WHEN ... THEN RAISE_APPLICATION_ERROR(...) ELSE y END`
# nao compila, e o erro chega como PLS-00306 apontando a linha da declaracao —
# longe da ideia errada. Custou uma rodada em agosto/2026, numa guarda de
# tamanho que eu quis enfiar no inicializador de uma variavel.
EM_EXPRESSAO = re.compile(
    r'(?::=|\bTHEN\b|\bELSE\b|\bRETURN\b)[^;\n]*\bRAISE_APPLICATION_ERROR\s*\(',
    re.I)
CITADO_META = re.compile(r"\('(-\d{5})'\s*,")


def codigos_fantasma(textos):
    """[(codigo, [arquivos])] documentados e nunca levantados.

    Recebe TODOS os bodies: desde que o utilitario saiu do PL_FPDF, um codigo
    documentado pode ser levantado no outro arquivo. Olhar um so acusaria como
    fantasma metade dos codigos reais.
    """
    levantados = {int(m.group(1)) for texto in textos
                  for m in RAISE.finditer(texto)}
    # O meta.py saiu do repositorio junto com o gerador da referencia; a fonte
    # de codigos documentados passou a ser so o cabecalho da spec.
    fontes = {'src/PL_FPDF.pks': CITADO_PKS}
    citados, lidas = {}, []
    for caminho, padrao in fontes.items():
        completo = os.path.join(RAIZ, caminho)
        if not os.path.exists(completo):
            raise SystemExit(
                f'{caminho} nao existe — esta regra confere os codigos '
                f'DOCUMENTADOS contra os levantados, e sem a fonte ela nao '
                f'confere nada. Passar assim seria aprovar sem olhar.')
        t = io.open(completo, encoding='utf-8').read()
        lidas.append(caminho)
        for m in padrao.finditer(t):
            citados.setdefault(int(m.group(1)), []).append(caminho)
    return lidas, sorted((c, onde) for c, onde in citados.items()
                         if c not in levantados)


def raise_em_expressao(caminho, texto):
    """RAISE_APPLICATION_ERROR usado onde so cabe expressao."""
    fora = []
    for n, linha in enumerate(texto.split('\n'), 1):
        limpo = re.sub(r'--.*$', '', linha)
        # `THEN raise_application_error(...)` como COMANDO e correto e comum;
        # o defeito e quando ha atribuicao ou RETURN antes, na mesma linha.
        if re.search(r'(?::=|\bRETURN\b)[^;]*\bRAISE_APPLICATION_ERROR\s*\(',
                     limpo, re.I):
            fora.append(f'{caminho}:{n}: RAISE_APPLICATION_ERROR dentro de '
                        f'expressao — e PROCEDURE, nao funcao')
    return fora


def main(caminhos):
    if isinstance(caminhos, str):
        caminhos = [caminhos]
    textos = [io.open(c, encoding='utf-8').read() for c in caminhos]
    problemas_todos, total_todos = [], 0
    for caminho, texto in zip(caminhos, textos):
        p, n = confere_faixas(caminho, texto)
        problemas_todos += p
        problemas_todos += raise_em_expressao(caminho, texto)
        total_todos += n

    lidas, fantasmas = codigos_fantasma(textos)
    if problemas_todos or fantasmas:
        for linha in problemas_todos:
            print(linha)
        if fantasmas:
            print(f'{len(fantasmas)} codigo(s) documentado(s) que ninguem '
                  f'levanta:')
            for cod, onde in fantasmas:
                print(f'  {cod} — citado em {", ".join(onde)}, sem '
                      f'raise_application_error correspondente')
        return 1
    print(f'OK — {total_todos} raise_application_error em '
          f'{len(caminhos)} arquivo(s), cada faixa com um assunto so, e todo '
          f'codigo documentado em {", ".join(lidas)} existe')
    return 0


def confere_faixas(caminho, texto):
    """(problemas, total) das faixas de um arquivo."""
    marcas = [(m.start(), m.group(1).lower())
              for m in CABECALHO.finditer(texto)]
    problemas = []
    total = 0
    for m in RAISE.finditer(texto):
        cod = int(m.group(1))
        sub = dono_de(marcas, m.start())
        msg = re.sub(r'\s+', ' ', m.group(2)).strip().strip("'")[:52]
        linha = texto.count('\n', 0, m.start()) + 1
        total += 1

        dom = dominio(sub)
        for rotulo, (lo, hi), _ in FAIXAS:
            dentro = lo <= cod <= hi
            if dom == rotulo and not dentro:
                problemas.append(
                    f'  linha {linha}: {cod} em {sub} — {rotulo} usa '
                    f'{hi}..{lo}. ({msg})')
                break
            if dom != rotulo and dentro:
                problemas.append(
                    f'  linha {linha}: {cod} em {sub} — essa faixa e de '
                    f'{rotulo}. ({msg})')
                break

    if problemas:
        problemas = [f'{caminho}: {len(problemas)} codigo(s) fora da faixa do '
                     f'seu assunto:'] + problemas
    return problemas, total


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:] or ['src/PL_FPDF.pkb', 'src/PL_FPDF_UTIL.pkb']))
