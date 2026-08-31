# -*- coding: utf-8 -*-
"""
Nenhuma view V$/GV$/DBA_ referenciada em SQL ESTATICO dentro de PL/SQL.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Custou uma rodada em agosto/2026. O `test_regressoes_revisao.sql` media o
vazamento de LOB temporario com um `SELECT ... FROM v$temporary_lobs` estatico,
e tinha um `EXCEPTION WHEN OTHERS` logo abaixo para pular o caso quando faltasse
privilegio.

O `EXCEPTION` nunca teve chance. **Role nao vale dentro de PL/SQL**: o acesso a
V$ costuma vir por `SELECT_CATALOG_ROLE` ou `SELECT ANY DICTIONARY`, e em SQL
estatico o PL/SQL resolve o nome em tempo de COMPILACAO. Sem o privilegio
concedido DIRETO ao usuario, o resultado e `PLS-00201` — que chega como
`ORA-06550` e derruba o bloco inteiro **antes de executar**. Nao ha excecao a
capturar, porque nenhuma linha rodou.

O sintoma engana duas vezes: o teste falha inteiro em vez de pular, e a mensagem
aponta a linha da view — nao o desenho errado, que era supor que um handler de
execucao pega um erro de compilacao.

A saida e SQL dinamico: `EXECUTE IMMEDIATE` resolve o nome em execucao, entao a
falta de privilegio vira `ORA-00942`, que um `EXCEPTION` captura de verdade.

O que cobra
-----------
Referencia a `V$...`, `GV$...` ou `DBA_...` fora de literal de string. Dentro de
aspas esta tudo bem: e exatamente o `EXECUTE IMMEDIATE` que se quer.

`USER_*` e `ALL_*` NAO entram: sao acessiveis por padrao e nao dependem de role.

Uso:  python dev/scripts/plsql_lint/check_v_estatico.py dev/tests/*.sql
"""
import glob
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))

# Fora de aspas, precedido de FROM/JOIN/, — e onde uma view entra numa consulta.
DEPENDE_DE_ROLE = re.compile(
    r'\b(?:from|join|,)\s+((?:g?v\$|dba_)[a-z0-9_$]+)', re.I)


def sem_literais(texto):
    """Troca o conteudo de cada literal por espacos, preservando as linhas.

    Preservar o comprimento e a quebra de linha e o que deixa o numero da linha
    continuar batendo com o arquivo — sem isso o aviso aponta para o lugar
    errado, que e pior que nao avisar.
    """
    fora, dentro, i = [], False, 0
    while i < len(texto):
        c = texto[i]
        if c == "'":
            dentro = not dentro
            fora.append("'")
        elif dentro and c != '\n':
            fora.append(' ')
        else:
            fora.append(c)
        i += 1
    return ''.join(fora)


def sem_comentarios(texto):
    texto = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group().count('\n'),
                   texto, flags=re.S)
    return re.sub(r'--[^\n]*', '', texto)


def confere(caminho):
    bruto = io.open(caminho, encoding='utf-8', errors='replace').read()
    limpo = sem_literais(sem_comentarios(bruto))
    achados = []
    for m in DEPENDE_DE_ROLE.finditer(limpo):
        linha = limpo.count('\n', 0, m.start()) + 1
        achados.append((linha, m.group(1)))
    return achados


def main(alvos):
    if not alvos:
        alvos = sorted(glob.glob(os.path.join(RAIZ, 'dev', 'tests', '*.sql')))
    if not alvos:
        print('nenhum arquivo casou com os padroes — passar assim seria '
              'aprovar sem verificar')
        return 1

    problemas, vistos = [], 0
    for a in alvos:
        if not os.path.exists(a):
            print(f'{a}: nao existe')
            return 1
        vistos += 1
        for linha, view in confere(a):
            problemas.append(
                f'  {os.path.relpath(a, RAIZ)}:{linha} -> {view} em SQL estatico')

    if problemas:
        print(f'{len(problemas)} referencia(s) a view dependente de role em '
              f'SQL estatico:')
        for p in problemas:
            print(p)
        print('\nRole nao vale dentro de PL/SQL: em SQL estatico isto e '
              'PLS-00201 em tempo de\nCOMPILACAO (chega como ORA-06550) e '
              'derruba o bloco inteiro — nenhum EXCEPTION\npega, porque nada '
              'executou. Use EXECUTE IMMEDIATE: a falta de privilegio passa\n'
              'a ser ORA-00942 em execucao, que da para tratar.')
        return 1

    print(f'OK — {vistos} arquivo(s) sem V$/GV$/DBA_ em SQL estatico')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
