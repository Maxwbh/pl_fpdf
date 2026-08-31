# -*- coding: utf-8 -*-
"""
Confere as chamadas a PL_FPDF.* nos testes contra as assinaturas reais da spec.

Pega duas classes de erro que só apareciam ao executar cada arquivo no banco,
uma de cada vez:

  PLS-00306  número errado de argumentos
             (ex.: SplitPDF('pdf1', l_ranges, NULL) — a função tem 2 parâmetros)
  PLS-00382  tipo incorreto na atribuição
             (ex.: l_info JSON_OBJECT_T := PL_FPDF.GetPageCount, que devolve
             PLS_INTEGER; ou GetOverlays/GetLoadedPDFs, que devolvem
             JSON_ARRAY_T)

E também chaves de JSON que o package nunca emite. Essas não quebram a
compilação: `get_string('overlay_id')` devolve NULL em silêncio quando a chave
real é 'overlayId', e o erro só aparece adiante — RemoveOverlay recebia string
vazia e falhava com ORA-20825.

Como ORA-06550 é erro de compilação do bloco anônimo, um único caso desses
derruba o arquivo de teste inteiro — daí valer a verificação estática.

Uso:
  python scripts/plsql_lint/check_test_calls.py
"""
import glob
import io
import os
import json
import re
import subprocess
import sys

# Ancorado na RAIZ do repositorio, calculada a partir deste arquivo. Caminho
# relativo ao diretorio atual funciona enquanto todo mundo roda da raiz, e
# quebra no primeiro que nao roda.
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


# tipos considerados compatíveis entre si na atribuição
FAMILIA = {
    'pls_integer': 'num', 'integer': 'num', 'number': 'num', 'binary_integer': 'num',
    'varchar2': 'txt', 'char': 'txt', 'clob': 'lob_c',
    'blob': 'lob_b', 'raw': 'raw', 'boolean': 'bool', 'date': 'date',
    'json_object_t': 'jobj', 'json_array_t': 'jarr',
}


def familia(t):
    if not t:
        return None
    t = re.sub(r'\(.*', '', t.strip().lower())
    return FAMILIA.get(t, t)


def strip_literals(src):
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


def carrega_api():
    subprocess.run([sys.executable, do_repo('dev', 'scripts', 'gen_docs', 'parse_spec.py')],
                   check=True, capture_output=True)
    api = {}
    for d in json.load(open(do_repo('dev', 'scripts', 'gen_docs', 'parsed.json'), encoding='utf-8')):
        nome = d['name'].lower()
        obrig = sum(1 for p in d['params'] if not p['default'])
        total = len(d['params'])
        info = api.setdefault(nome, {'ret': set(), 'aridades': [], 'tipos': []})
        info['ret'].add(familia(d.get('returns')))
        info['aridades'].append((obrig, total))
        info['tipos'].append([(p['name'].lower(), (p['type'] or '').upper())
                              for p in d['params']])
    return api


CALL = re.compile(r'PL_FPDF\.([a-z_0-9]+)\s*(\()?', re.I)
DECL = re.compile(r'^\s*([a-z_][a-z_0-9]*)\s+([a-z_0-9]+(?:\s*\([^)]*\))?)\s*(?::=|;)',
                  re.I | re.M)   # sem re.M, '^' só casaria no início do arquivo


def conta_args(src, pos):
    """Conta argumentos de nível 1 a partir do '(' em pos."""
    depth, args, viu = 0, 1, False
    i = pos
    while i < len(src):
        c = src[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return args if viu else 0
        elif c == ',' and depth == 1:
            args += 1
        elif depth == 1 and not c.isspace():
            viu = True
        i += 1
    return None


def args_de(src, pos):
    """O texto de cada argumento de nivel 1, a partir do '(' em pos."""
    depth, atual, fora, i = 0, [], [], pos
    while i < len(src):
        c = src[i]
        if c == "'":                       # literal: copia inteiro
            j = i + 1
            while j < len(src) and src[j] != "'":
                j += 1
            atual.append(src[i:j + 1])
            i = j + 1
            continue
        if c == '(':
            depth += 1
            if depth == 1:
                i += 1
                continue
        elif c == ')':
            depth -= 1
            if depth == 0:
                fora.append(''.join(atual).strip())
                return [a for a in fora if a != ''] if any(fora) else []
        elif c == ',' and depth == 1:
            fora.append(''.join(atual).strip())
            atual = []
            i += 1
            continue
        atual.append(c)
        i += 1
    return None


# Familias que nunca aceitam um literal de texto nem de numero. Nao se tenta
# inferir tipo de VARIAVEL — so de literal, que e onde a resposta e certa.
NAO_ACEITA_TEXTO = ('BLOB', 'CLOB', 'NUMBER', 'PLS_INTEGER', 'INTEGER',
                    'BOOLEAN', 'JSON_OBJECT_T', 'JSON_ARRAY_T', 'DATE')
NAO_ACEITA_NUMERO = ('BLOB', 'CLOB', 'BOOLEAN', 'JSON_OBJECT_T',
                     'JSON_ARRAY_T', 'DATE')

LITERAL_TEXTO = re.compile(r"^'(?:[^']|'')*'$")
LITERAL_NUM = re.compile(r'^-?\d+(?:\.\d+)?$')


def confere_tipos_posicionais(nome, args, info):
    """Literal de texto num parametro BLOB (e vizinhos) — PLS-00306.

    Por que existe: o `check_test_calls` conferia ARIDADE e nada mais, e por
    isso aprovou `LoadPDFWithID(l_pdf, 'reg_split')`. A assinatura e
    (p_pdf_id VARCHAR2, p_pdf_blob BLOB): o ID vem PRIMEIRO. Dois argumentos,
    aridade certa, tipos trocados — PLS-00306 em tempo de COMPILACAO, e o
    bloco de teste inteiro nao executou.

    So se olha LITERAL, nunca variavel: de um literal o tipo se sabe com
    certeza, e uma regra que chuta tipo de variavel produziria ruido.
    """
    if any('=>' in a for a in args):
        return []                      # nomeada: a ordem nao importa
    cands = [t for t in info['tipos'] if len(t) >= len(args)]
    if len(cands) != 1:
        return []                      # sobrecarga ambigua: nao arrisca
    faltas = []
    for i, arg in enumerate(args):
        pnome, ptipo = cands[0][i]
        base = ptipo.split('(')[0].strip()
        if LITERAL_TEXTO.match(arg) and base in NAO_ACEITA_TEXTO:
            # o conteudo do literal ja veio apagado por quem preparou o
            # fonte (e o que impede virgula dentro de string de bagunçar a
            # contagem), entao a mensagem diz o TIPO, nao o valor
            faltas.append(f'{nome}: argumento {i + 1} e um literal de texto, '
                          f'mas {pnome} e {base}')
        elif LITERAL_NUM.match(arg) and base in NAO_ACEITA_NUMERO:
            faltas.append(f'{nome}: argumento {i + 1} e o literal numerico '
                          f'{arg}, mas {pnome} e {base}')
    return faltas


def chaves_json_do_package():
    """Chaves que o package realmente escreve em objetos JSON."""
    pkb = io.open(do_repo('src', 'PL_FPDF.pkb'), encoding='utf-8').read()
    return set(re.findall(r"\.put\(\s*'([^']+)'", pkb))


JSON_GET = re.compile(
    r"\.(?:get_string|get_number|get_boolean|get_date|has|get)\(\s*'([^']+)'")


# Linha que emite [PASS] e [FAIL] de uma vez: e resumo, e o runner conta as
# OCORRENCIAS dos marcadores na saida — um resumo assim vira um teste fantasma
# que passou e um que falhou. Aconteceu no diag_deflate: o arquivo dizia
# "5 [PASS], 0 [FAIL]" e a rodada acusou "6 passou | 1 falhou".
RESUMO = re.compile(r"PUT_LINE\s*\((?:[^;]*?\[PASS\][^;]*?\[FAIL\]"
                    r"|[^;]*?\[FAIL\][^;]*?\[PASS\])[^;]*?\)", re.I | re.S)


def resumos_ambiguos(caminho, bruto):
    """Linhas de saida que repetem os dois marcadores na mesma instrucao."""
    fora = []
    for m in RESUMO.finditer(bruto):
        linha = bruto[:m.start()].count('\n') + 1
        fora.append((caminho, linha,
                     'o resumo repete [PASS] e [FAIL] na mesma linha — o '
                     'runner conta as ocorrencias e isso vira um teste '
                     'fantasma que passou e um que falhou'))
    return fora


def main():
    api = carrega_api()
    chaves = chaves_json_do_package()
    problemas = []
    # os exemplos entram junto: um exemplo que nao compila e pior que um teste
    # que nao compila — ele e a primeira coisa que quem chega copia e cola
    for f in sorted(glob.glob(do_repo('dev', 'tests', '*.sql')) + glob.glob(do_repo('examples', '*.sql'))):
        if f.endswith('run_all_tests.sql'):
            continue
        bruto = io.open(f, encoding='utf-8').read()
        problemas += resumos_ambiguos(f, bruto)
        src = strip_literals(bruto)
        tipos = {m.group(1).lower(): familia(m.group(2))
                 for m in DECL.finditer(src)}

        # sobre o texto SEM comentários mas COM as strings: strip_literals apaga
        # o conteúdo das strings, e é justamente ele que se quer conferir aqui
        sem_comentario = re.sub(r'--[^\n]*', '', bruto)
        for m in JSON_GET.finditer(sem_comentario):
            if m.group(1) not in chaves:
                ln = sem_comentario[:m.start()].count('\n') + 1
                problemas.append((f, ln, f"chave JSON '{m.group(1)}' não é emitida "
                                         f"pelo package (devolveria NULL em silêncio)"))
        for m in CALL.finditer(src):
            nome = m.group(1).lower()
            if nome not in api:
                continue
            ln = src[:m.start()].count('\n') + 1
            info = api[nome]

            if m.group(2):
                n = conta_args(src, m.end() - 1)
                if n is not None and not any(lo <= n <= hi for lo, hi in info['aridades']):
                    faixas = ' ou '.join(f'{lo}..{hi}' for lo, hi in info['aridades'])
                    problemas.append((f, ln, f'{nome}: {n} argumento(s), a assinatura aceita {faixas}'))
                args = args_de(src, m.end() - 1)
                if args:
                    for msg in confere_tipos_posicionais(nome, args, info):
                        problemas.append((f, ln, msg))

            # atribuição: <var> := PL_FPDF.Func(...)
            antes = src[max(0, m.start() - 120):m.start()]
            a = re.search(r'([a-z_][a-z_0-9]*)\s*:=\s*$', antes, re.I)
            if a:
                var = a.group(1).lower()
                if var in tipos and tipos[var] and None not in info['ret']:
                    rets = {r for r in info['ret'] if r}
                    if rets and tipos[var] not in rets:
                        problemas.append(
                            (f, ln, f'{nome} devolve {"/".join(sorted(rets))}, '
                                    f'mas {var} é {tipos[var]}'))

    if problemas:
        print(f'{len(problemas)} chamada(s) incompatível(is) com a spec:')
        for f, ln, msg in problemas:
            print(f'  {f}:{ln}: {msg}')
        print('\n  ORA-06550 é erro de compilação: um caso derruba o arquivo inteiro.')
        print('  Chaves JSON erradas não quebram a compilação: devolvem NULL.')
        return 1
    print('OK — chamadas a PL_FPDF.* nos testes e exemplos batem com a spec')
    return 0


if __name__ == '__main__':
    sys.exit(main())
