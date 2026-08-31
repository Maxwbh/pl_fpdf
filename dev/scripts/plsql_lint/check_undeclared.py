# -*- coding: utf-8 -*-
"""
Nada é chamado sem existir (PLS-00201).

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Havia guarda para os dois vizinhos deste erro e não para ele:

    check_call_order  chamada a subprograma definido MAIS ABAIXO   (PLS-00313)
    check_dead_code   declarado e NUNCA usado
    este              usado e NUNCA declarado                      (PLS-00201)

O caso que o originou: a etapa que unificou as métricas removeu as onze funções
`getFontXxx` e trocou os chamadores por `p_larguras_da_fonte`. Um chamador
ficou para trás, 7900 linhas abaixo dos outros, dentro do `ovl_largura`. Os
onze lints passaram, o CI ficou verde nas três vagas, e o erro só apareceu no
`COMPILE` contra o banco — que é o lugar mais caro de descobrir.

E o `PLS-00201` é dos que **abortam a análise da unidade inteira**: o Oracle
relata aquele e para, então cada rodada de compilação revela um só.

Como decide
-----------
Monta o conjunto do que EXISTE — subprogramas da spec e do body, variáveis,
constantes, tipos, cursores, parâmetros e variáveis de laço — e depois procura
identificadores em posição de chamada (`nome(`) que não estejam nele.

Fora da conta, porque não são deste package: nome qualificado (`DBMS_LOB.READ`,
`PL_FPDF_UTIL.inflate`), palavra reservada do PL/SQL, e as funções nativas do
Oracle, na lista `NATIVAS`. Uma nativa que falte ali vira falso positivo —
acrescente e siga; é o preço de não precisar de um parser de verdade.

Uso:  python dev/scripts/plsql_lint/check_undeclared.py src/PL_FPDF.pks src/PL_FPDF.pkb
"""
import io
import re
import sys

NATIVAS = {
    # cadeia e conversão
    'substr', 'substrb', 'instr', 'instrb', 'length', 'lengthb', 'lower',
    'upper', 'initcap', 'replace', 'translate', 'lpad', 'rpad', 'ltrim',
    'rtrim', 'trim', 'concat', 'ascii', 'chr', 'to_char', 'to_number',
    'to_date', 'to_timestamp', 'to_blob', 'to_clob', 'cast', 'convert',
    'regexp_replace', 'regexp_substr', 'regexp_instr', 'regexp_count',
    'regexp_like', 'validate_conversion', 'standard_hash', 'soundex',
    # numérico
    'abs', 'ceil', 'floor', 'round', 'trunc', 'mod', 'remainder', 'power',
    'sqrt', 'exp', 'ln', 'log', 'sign', 'sin', 'cos', 'tan', 'asin', 'acos',
    'atan', 'atan2', 'bitand', 'greatest', 'least', 'width_bucket',
    # nulo e condicional
    'nvl', 'nvl2', 'coalesce', 'nullif', 'decode', 'case', 'lnnvl',
    # data
    'sysdate', 'systimestamp', 'add_months', 'months_between', 'last_day',
    'next_day', 'extract', 'numtodsinterval', 'numtoyminterval',
    # coleção e diversos
    'exists', 'count', 'first', 'last', 'next', 'prior', 'delete', 'trim',
    'extend', 'raise_application_error', 'sqlerrm', 'sqlcode', 'dbms_output',
    'empty_blob', 'empty_clob', 'sys_guid', 'user', 'userenv', 'rawtohex',
    'hextoraw', 'dump', 'vsize', 'sys_context', 'json_object_t', 'json_array_t',
    # controle que casa com 'nome('
    'if', 'elsif', 'while', 'loop', 'return', 'and', 'or', 'not', 'in', 'out',
    'then', 'else', 'when', 'is', 'as', 'begin', 'end', 'null', 'values',
    'set', 'select', 'from', 'where', 'into', 'using', 'open', 'fetch',
    'close', 'commit', 'rollback', 'raise', 'exception', 'others', 'type',
    'record', 'table', 'index', 'by', 'of', 'constant', 'default', 'pragma',
    'exit', 'goto', 'declare', 'function', 'procedure', 'package', 'body',
    'for', 'all', 'between', 'like', 'order', 'group', 'having', 'union',
    # tipos e pragmas, que também casam com 'nome('
    'char', 'varchar', 'varchar2', 'nchar', 'nvarchar2', 'number', 'numeric',
    'decimal', 'integer', 'int', 'pls_integer', 'binary_integer', 'raw',
    'long', 'blob', 'clob', 'nclob', 'bfile', 'date', 'timestamp', 'interval',
    'boolean', 'exception_init', 'restrict_references', 'autonomous_transaction',
    'inline', 'udf', 'deterministic', 'parallel_enable', 'result_cache',
}

# [ \t]* e nao \s*: com re.M o \s inclui a quebra de linha, e uma
# correspondencia iniciada linhas acima engole a declaracao seguinte. Foi o
# que escondeu 'l_ord tv32k;' na primeira versao deste script.
DEFINE_SUB = re.compile(
    r'^[ \t]*(?:procedure|function)\s+([a-z_][a-z0-9_]*)', re.I | re.M)
# declarações: 'nome tipo;' / 'nome constant tipo := ...' / 'nome tipo := ...'
# Nao basta ancorar no inicio da linha: duas declaracoes cabem numa
# ('g_inf_cl_c tpi;  g_inf_cl_s tpi;') e uma pode vir logo apos DECLARE
# ('declare l_ng tqr;'). Aceita tambem depois de ';' e de 'declare'.
DEFINE_VAR = re.compile(
    r'(?:^|;)[ \t]*([a-z_][a-z0-9_]*)[ \t]+'
    r'(?:constant[ \t]+)?[a-z_][a-z0-9_.%]*',
    re.I | re.M)
# 'declare l_ng tqr;' precisa de regra propria: na de cima o ^ vence, captura
# 'declare' como se fosse o nome e engole 'l_ng' como se fosse o tipo.
DEFINE_DECLARE = re.compile(r'\bdeclare[ \t]+([a-z_][a-z0-9_]*)[ \t]+[a-z_]',
                            re.I)
DEFINE_TIPO = re.compile(r'^[ \t]*(?:type|subtype)\s+([a-z_][a-z0-9_]*)',
                         re.I | re.M)
# parâmetros, dentro dos parênteses da assinatura
PARAM = re.compile(r'([a-z_][a-z0-9_]*)\s+(?:in\s+out|in|out)?\s*[a-z_]',
                   re.I)
LACO = re.compile(r'\bfor\s+([a-z_][a-z0-9_]*)\s+in\b', re.I)

# uso em posição de chamada, não qualificado por ponto
USO = re.compile(r'(?<![.\w])([a-z_][a-z0-9_]*)\s*\(', re.I)


def sem_comentarios(texto):
    """Tira comentários E literais, preservando as quebras de linha.

    Os literais importam tanto quanto os comentários: 'imagem sem alfa (ou
    achatada...)' tem a forma exata de uma chamada a `alfa`. Sem tirá-los, a
    verificação acusa dezenas de palavras de mensagem de erro.
    """
    def espacos(m):
        return re.sub(r'[^\n]', ' ', m.group(0))

    texto = re.sub(r'/\*.*?\*/', espacos, texto, flags=re.S)
    texto = re.sub(r'--[^\n]*', espacos, texto)
    # literal do PL/SQL, com '' escapando a aspa; e a forma q'[...]'
    texto = re.sub(r"q'\[.*?\]'", espacos, texto, flags=re.S)
    return re.sub(r"'(?:''|[^'])*'", espacos, texto)


def definidos(textos):
    nomes = set()
    for t in textos:
        limpo = sem_comentarios(t)
        for rx in (DEFINE_SUB, DEFINE_TIPO, DEFINE_VAR,
                   DEFINE_DECLARE, LACO):
            nomes.update(m.lower() for m in rx.findall(limpo))
        # parâmetros: o miolo de cada assinatura
        for m in re.finditer(r'(?:procedure|function)\s+\w+\s*\((.*?)\)',
                             limpo, re.S | re.I):
            nomes.update(p.lower() for p in PARAM.findall(m.group(1)))
    return nomes


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    textos = [io.open(c, encoding='utf-8', errors='replace').read()
              for c in argv[1:]]
    existem = definidos(textos) | NATIVAS

    faltando = {}
    for caminho, texto in zip(argv[1:], textos):
        limpo = sem_comentarios(texto)
        # mantém a numeração: só o que foi apagado vira espaço
        for n, linha in enumerate(limpo.splitlines(), 1):
            for nome in USO.findall(linha):
                if nome.lower() not in existem:
                    faltando.setdefault(nome.lower(), []).append(
                        (caminho, n, linha.strip()[:88]))

    if faltando:
        print(f'{len(faltando)} identificador(es) chamados e nunca declarados '
              f'(PLS-00201):')
        for nome, ocorr in sorted(faltando.items()):
            caminho, n, linha = ocorr[0]
            extra = f' (e mais {len(ocorr) - 1})' if len(ocorr) > 1 else ''
            print(f'  {nome}{extra}\n      {caminho}:{n}: {linha}')
        return 1

    print(f'OK — nada é chamado sem existir ({len(existem) - len(NATIVAS)} '
          f'nomes próprios declarados)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
