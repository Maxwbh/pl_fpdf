# -*- coding: utf-8 -*-
"""
Acha item declarado DEPOIS do primeiro subprograma local, em bloco anônimo.

Por que existe
--------------
É a mesma regra que o `check_declarations.py` guarda no package body, e a
mesma mensagem inútil — só que do lado dos testes, onde não havia rede
nenhuma. Num `DECLARE`, uma vez que aparece o corpo de um subprograma local,
não se declara mais nada: o Oracle responde

    ORA-06550: line 88, column 3:
    PLS-00103: Encontrado o símbolo "BLOB" quando um dos seguintes símbolos
    era esperado: begin function pragma procedure subtype type ...

e a linha apontada é a da declaração, não a do subprograma que a tornou
inválida — então quem lê procura o defeito no lugar errado.

Custou uma rodada inteira contra o banco em `test_stream_imagem.sql`: os
auxiliares `blob_de`, `ida_e_volta` e `acha` foram escritos primeiro e as
variáveis do bloco ficaram embaixo deles. O arquivo passou por todos os lints
que existiam, porque nenhum olhava para `dev/tests/*.sql`, e só quebrou no
`ORA-06550` depois de conectar. Os arquivos mais antigos desta pasta já
declaram na ordem certa; o que faltava era a regra que impede a volta.

Como funciona
-------------
Dentro do `DECLARE` mais externo — até o `BEGIN` na coluna 0 —, olha só as
linhas no nível do bloco (dois espaços, que é o padrão desta pasta). Depois do
primeiro `PROCEDURE`/`FUNCTION` nesse nível, qualquer declaração no mesmo
nível é o erro. O que está dentro dos subprogramas vem mais indentado e não é
considerado.

Limite conhecido: quem indentar o `DECLARE` de outro jeito escapa. É rede de
segurança para o padrão da pasta, não um parser de PL/SQL — mesma escolha do
`check_declarations.py`.

Uso:
  python dev/scripts/plsql_lint/check_block_declarations.py dev/tests/*.sql
"""
import glob
import io
import os
import re
import sys

NIVEL = '  '          # indentação dos itens do bloco anônimo nesta pasta
ABRE = re.compile(r'^\s*DECLARE\s*$', re.I)
FECHA = re.compile(r'^BEGIN\s*$', re.I)
SUBPROG = re.compile(r'^  (PROCEDURE|FUNCTION)\s+([a-z_0-9$#]+)', re.I)
# '  l_pdf    BLOB;' / '  l_n  PLS_INTEGER := 0;' / '  r_x tipo%ROWTYPE;'
DECLARACAO = re.compile(
    r'^  ([a-z_][a-z_0-9$#]*)\s+'
    r'(?!IS\b|AS\b)'
    r'[a-z_0-9$#.%]+\s*(\(|:=|;|\bNOT\b|\bDEFAULT\b)', re.I)
# Palavra reservada abrindo a linha nao e declaracao. O caso que motivou a
# lista: 'END nome;' fecha um subprograma no mesmo nivel de indentacao dos
# itens do bloco, e casa com o padrao acima — 'END' seguido do nome e do ponto
# e virgula. Sem isso o lint acusaria todo arquivo da pasta.
PALAVRAS = {
    'end', 'begin', 'exception', 'return', 'raise', 'null', 'if', 'elsif',
    'else', 'for', 'while', 'loop', 'case', 'when', 'exit', 'goto', 'open',
    'close', 'fetch', 'commit', 'rollback', 'savepoint', 'pragma', 'declare',
    'select', 'insert', 'update', 'delete', 'merge', 'execute', 'cursor',
}


def sem_comentario(texto):
    texto = re.sub(r'/\*.*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group(0)),
                   texto, flags=re.S)
    return re.sub(r'--[^\n]*', lambda m: ' ' * len(m.group(0)), texto)


def main(caminho):
    linhas = sem_comentario(
        io.open(caminho, encoding='utf-8').read()).split('\n')

    problemas = []
    dentro = False
    subprog = None          # (linha, nome) do primeiro subprograma do bloco
    for i, linha in enumerate(linhas, 1):
        if not dentro:
            if ABRE.match(linha):
                dentro, subprog = True, None
            continue
        if FECHA.match(linha):
            dentro = False
            continue

        m = SUBPROG.match(linha)
        if m:
            if subprog is None:
                subprog = (i, m.group(2))
            continue

        if subprog is not None:
            d = DECLARACAO.match(linha)
            if d and d.group(1).lower() not in PALAVRAS:
                problemas.append((i, d.group(1), subprog))

    if problemas:
        print(f'{caminho}: {len(problemas)} declaração(ões) depois do primeiro '
              f'subprograma local:')
        for linha, nome, (l_sub, n_sub) in problemas:
            print(f'  linha {linha}: {nome} — declarado depois do corpo de '
                  f'{n_sub} (linha {l_sub}). Em bloco anônimo isso dá '
                  f'PLS-00103, e a mensagem aponta esta linha, não a causa. '
                  f'Suba as declarações para antes dos subprogramas locais.')
        return 1

    return 0


if __name__ == '__main__':
    alvos = sys.argv[1:] or sorted(glob.glob(os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        '..', '..', 'tests', '*.sql')))
    if not alvos:
        print('nenhum arquivo para verificar', file=sys.stderr)
        sys.exit(1)
    saida = max(main(c) for c in alvos)
    if saida == 0:
        print(f'OK — nenhuma declaração fora de lugar em bloco anônimo '
              f'({len(alvos)} arquivo(s) verificado(s))')
    sys.exit(saida)
