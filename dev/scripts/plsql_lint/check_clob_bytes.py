# -*- coding: utf-8 -*-
"""
Procura duas coisas que o PL/SQL aceita mal com LOB.

1. Funções de semântica de BYTE aplicadas a CLOB.
2. LOB passado a STANDARD_HASH.

Por que existe
-------------
`SUBSTRB`, `LENGTHB` e `INSTRB` não valem para CLOB quando o charset do banco é
multibyte — e AL32UTF8 é o caso normal. O Oracle não reclama na compilação:
o erro só aparece em execução, e com uma mensagem que não diz onde está:

    ORA-22998: CLOB or NCLOB in multibyte character set not supported

Foi assim que a amostra `marca_dagua` quebrou: `overlay_rec.content` é CLOB, e
o overlay de texto fazia `SUBSTRB(g_overlays(k).content, 1, 3000)` para limitar
o tamanho. O conserto é `DBMS_LOB.SUBSTR`, que trabalha em caracteres e devolve
VARCHAR2.

**STANDARD_HASH não aceita LOB.** Só tipos escalares; com CLOB ou BLOB o
compilador acusa

    PL/SQL: ORA-00902: invalid datatype

e não diz qual argumento. Custou uma rodada no `aes_hash_r6`, que passava o E do
algoritmo 2.B em BLOB — sem precisar, porque o valor cabe em RAW (a senha do R6
vai a 127 bytes, o K a 64 e o extra a 48: 64 × 239 = 15296).

Como funciona
-------------
Colhe os identificadores declarados como CLOB e sinaliza toda chamada a
SUBSTRB/LENGTHB/INSTRB cujo primeiro argumento seja um deles.

O escopo importa: há um `l_out CLOB` num subprograma e um `l_out VARCHAR2`
noutro, e olhar só o nome acusaria sete usos legítimos. Por isso as variáveis
locais valem apenas dentro do subprograma que as declara, e os campos de record
só quando o acesso é qualificado (`r.campo`, `t(i).campo`).

Aceita vários arquivos, e o CI passa também os testes: o mesmo ORA-00902 do
`aes_hash_r6` reapareceu num `tests/diag_*.sql` justamente porque este
verificador só olhava `src/`. Um bug que já foi corrigido uma vez e volta noutro
arquivo é sinal de cobertura estreita, não de descuido isolado.

Uso:  python scripts/plsql_lint/check_clob_bytes.py src/PL_FPDF.pkb tests/*.sql
"""
import io
import re
import sys

BYTE_FN = re.compile(r'\b(SUBSTRB|LENGTHB|INSTRB)\s*\(', re.I)
# 'nome ... clob' numa linha de declaração (var, campo de record ou parâmetro)
# 'nome [IN|OUT|IN OUT] [NOCOPY] clob' — SEM âncora de início de linha, porque
# o parâmetro pode vir no próprio cabeçalho: `FUNCTION f(p_src IN BLOB, ...)`.
# Foi por estar ancorado que a primeira versão deste lint deixou passar
# exatamente o erro que ele existe para pegar.
DECL = re.compile(r'\b([a-z_][a-z_0-9]*)\s+(?:in\s+out\s+|in\s+|out\s+)?'
                  r'(?:nocopy\s+)?clob\b', re.I)
# STANDARD_HASH recusa CLOB *e* BLOB, então este caminho precisa dos dois
DECL_LOB = re.compile(r'\b([a-z_][a-z_0-9]*)\s+(?:in\s+out\s+|in\s+|out\s+)?'
                      r'(?:nocopy\s+)?[bc]lob\b', re.I)
HASH_FN = re.compile(r'\bSTANDARD_HASH\s*\(', re.I)


CABECALHO = re.compile(r'^[ \t]{0,2}(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9]*)',
                       re.I | re.M)
RECORD = re.compile(r'\bTYPE\s+[a-z_0-9]+\s+IS\s+RECORD\s*\((.*?)\)\s*;',
                    re.I | re.S)


IGNORAR = {'return', 'is', 'as', 'of', 'table', 'type', 'empty_blob',
           'empty_clob', 'to_blob', 'to_clob'}


def clobs_de(texto, padrao=DECL):
    """Identificadores declarados como CLOB (ou LOB) no trecho."""
    achados = set()
    for linha in texto.splitlines():
        if linha.lstrip().startswith('--'):        # comentário não conta
            continue
        for m in padrao.finditer(linha):
            if m.group(1).lower() not in IGNORAR:
                achados.add(m.group(1).lower())
    return achados


def campos_clob(texto):
    """Campos CLOB de qualquer TYPE ... IS RECORD do arquivo."""
    achados = set()
    for m in RECORD.finditer(texto):
        for campo in m.group(1).split(','):
            d = DECL.search(campo.strip())
            if d and d.group(1).lower() not in IGNORAR:
                achados.add(d.group(1).lower())
    return achados


def blocos(texto):
    """(inicio, fim, conjunto de CLOBs locais) de cada subprograma do package."""
    marcas = [m.start() for m in CABECALHO.finditer(texto)] or [0]
    marcas.append(len(texto))
    return [(marcas[i], marcas[i + 1],
             clobs_de(texto[marcas[i]:marcas[i + 1]]),
             clobs_de(texto[marcas[i]:marcas[i + 1]], DECL_LOB))
            for i in range(len(marcas) - 1)]


def primeiro_arg(texto, i):
    """Texto do primeiro argumento da chamada que abre em `i` (o parêntese)."""
    prof, j = 0, i
    while j < len(texto):
        c = texto[j]
        if c == '(':
            prof += 1
        elif c == ')':
            prof -= 1
            if prof == 0:
                return texto[i + 1:j]
        elif c == ',' and prof == 1:
            return texto[i + 1:j]
        j += 1
    return ''


def main(caminho):
    texto = io.open(caminho, encoding='utf-8').read()
    campos = campos_clob(texto)
    escopos = blocos(texto)
    locais = sum(len(c) for _, _, c, _ in escopos)
    lobs   = sum(len(l) for _, _, _, l in escopos)
    # Desistir aqui olhando SÓ os CLOBs deixava passar um arquivo que declara
    # apenas BLOBs — e é exatamente esse que cai no STANDARD_HASH. Foi assim que
    # o ORA-00902 do diag_inflate.sql escapou depois de o lint já cobrir o caso.
    if not campos and not locais and not lobs:
        print(f'{caminho}: nenhum LOB declarado — nada a checar')
        return 0

    problemas = []
    for m in BYTE_FN.finditer(texto):
        arg = primeiro_arg(texto, m.end() - 1).strip()
        # t(i).campo -> ('t', 'campo'); r.x -> ('r', 'x'); x -> ('x',)
        partes = [p.strip().lower()
                  for p in re.sub(r'\(.*\)', '', arg).split('.')]
        alvo = partes[-1]
        if len(partes) > 1:
            suspeito = alvo in campos                # acesso qualificado
        else:
            suspeito = any(ini <= m.start() < fim and alvo in cl
                           for ini, fim, cl, _ in escopos)
        if suspeito:
            problemas.append((texto.count('\n', 0, m.start()) + 1,
                              m.group(1), arg))

    # STANDARD_HASH com LOB: o compilador acusa ORA-00902 sem dizer o argumento
    for m in HASH_FN.finditer(texto):
        arg = primeiro_arg(texto, m.end() - 1).strip()
        partes = [p.strip().lower()
                  for p in re.sub(r'\(.*\)', '', arg).split('.')]
        alvo = partes[-1]
        if any(ini <= m.start() < fim and alvo in lb
               for ini, fim, _, lb in escopos):
            problemas.append((texto.count('\n', 0, m.start()) + 1,
                              'STANDARD_HASH', arg))

    if problemas:
        print(f'{caminho}: {len(problemas)} uso(s) problemático(s) de LOB '
              f'(ORA-22998 / ORA-00902):')
        for linha, fn, arg in problemas:
            if fn.upper() == 'STANDARD_HASH':
                print(f'  linha {linha}: STANDARD_HASH({arg} ...) — não aceita '
                      f'LOB (ORA-00902); passe RAW/VARCHAR2')
            else:
                print(f'  linha {linha}: {fn}({arg} ...) — use DBMS_LOB.SUBSTR '
                      f'/ DBMS_LOB.GETLENGTH / DBMS_LOB.INSTR')
        return 1

    print(f'{caminho}: OK — nenhuma função de byte em CLOB nem LOB em '
          f'STANDARD_HASH ({locais} CLOB e {lobs} LOB em {len(escopos)} '
          f'subprogramas, {len(campos)} campos de record)')
    return 0


if __name__ == '__main__':
    alvos = sys.argv[1:] or ['src/PL_FPDF.pkb']
    sys.exit(max(main(a) for a in alvos))
