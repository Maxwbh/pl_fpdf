# -*- coding: utf-8 -*-
"""
A suíte tem um vocabulário só, e nenhum arquivo fica de fora do gerador.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
**Um teste fora da lista não roda, e ninguém percebe.** O
`dev/scripts/build_run_all.py` tem a lista dos arquivos da suíte escrita à mão.
Acrescentar um `test_*.sql` e esquecer de citá-lo ali produz um arquivo que
existe, compila, tem asserção — e nunca é executado. Não há erro, não há aviso:
há um teste que se acredita ter. Em setembro de 2026 não havia deriva nenhuma,
e é exatamente por isso que a hora de travar é agora.

**E a suíte falava quatro dialetos.** Para a mesma asserção havia
`test_pass`/`test_fail`, `test_result(nome, condição)`, `run_test(...)` e
`passou`/`falhou`, cada arquivo redeclarando os seus. O runner não se importa —
ele lê `[PASS]`, `[FAIL]` e `[SKIP]` do DBMS_OUTPUT, e os quatro emitiam isso.
Quem se importa é quem lê: abrir dois arquivos vizinhos e achar vocabulários
diferentes custa atenção que devia ir para o que o teste afere.

O vocabulário
-------------
Cinco nomes, e o quinto é feito dos outros:

===================================== ======================================
`caso(nome)`                          abre um caso, com o cabeçalho
`passou(msg)` / `falhou(msg)`         a asserção, quando ela tem duas saídas
`pulou(msg)`                          o caso não pôde ser concluído
`confere(nome, condicao, msg_falha)`  a forma condensada, quando a condição
                                      cabe numa expressão
===================================== ======================================

O `confere` existe por medida, e não por gosto: **145 chamadas** estavam na
forma condensada. Reescrevê-las como `caso` mais `IF` seria 145 edições
estruturais, cada uma com a chance de inverter uma condição — e um teste com a
condição invertida passa a aprovar justamente o defeito que devia pegar. Um
nome a mais custa menos que esse risco, e ele é implementado sobre os outros
três, então a contagem e a saída continuam as mesmas.

O que se confere
----------------
1. todo `test_*.sql` do disco está na lista do gerador, e vice-versa;
2. nenhum arquivo declara os auxiliares antigos;
3. todo arquivo da suíte emite `[PASS]` e `[FAIL]` — o contrato com o runner;
4. um `diag_*.sql` ou emite `[PASS]` (e o runner o executa) ou se declara
   EXPERIMENTO no cabeçalho. Sem uma das duas coisas ele é um arquivo que
   ninguém roda e ninguém sabe por quê.

Uso:  python dev/scripts/plsql_lint/check_suite.py
"""
import glob
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))

ANTIGOS = ['test_start', 'test_pass', 'test_fail', 'test_skip',
           'test_result', 'run_test', 'section_start']
CANONICOS = ['caso', 'passou', 'falhou', 'pulou', 'confere']


def do_repo(*p):
    return os.path.join(RAIZ, *p)


def declarados(texto):
    """Os subprogramas que o arquivo declara."""
    return set(re.findall(r'\b(?:PROCEDURE|FUNCTION)\s+([a-z_][a-z_0-9]*)',
                          texto, re.I))


def main():
    gerador = io.open(do_repo('dev', 'scripts', 'build_run_all.py'),
                      encoding='utf-8').read()
    na_lista = set(re.findall(r"\('([a-z0-9_]+\.sql)'", gerador))

    no_disco, diagnosticos = set(), set()
    for f in sorted(glob.glob(do_repo('dev', 'tests', '*.sql'))):
        b = os.path.basename(f)
        if b == 'run_all_tests.sql':
            continue
        if re.search(r'_(BACKUP|LOCAL|REMOTE|BASE)_\d+\.sql$', b, re.I):
            continue
        (diagnosticos if b.startswith('diag_') else no_disco).add(b)

    falhas = []

    for b in sorted(no_disco - na_lista):
        falhas.append(f'{b}: existe e NAO esta na lista do build_run_all.py — '
                      f'nao entra na suite, e nada avisa')
    for b in sorted(na_lista - no_disco):
        falhas.append(f'{b}: esta na lista do build_run_all.py e NAO existe '
                      f'no disco')

    for b in sorted(no_disco):
        t = io.open(do_repo('dev', 'tests', b), encoding='utf-8').read()
        velhos = sorted(declarados(t) & set(ANTIGOS))
        for v in velhos:
            falhas.append(f'{b}: declara "{v}", do vocabulario antigo. '
                          f'O canonico e: {", ".join(CANONICOS)}')
        for marca in ('[PASS]', '[FAIL]'):
            if marca not in t:
                falhas.append(f'{b}: nao emite {marca} — o runner conta as '
                              f'verificacoes por essas marcas')

    for f in sorted(diagnosticos):
        t = io.open(do_repo('dev', 'tests', f), encoding='utf-8').read()
        if '[PASS]' not in t and 'EXPERIMENTO' not in t.upper():
            falhas.append(f'{f}: nao emite [PASS] e nao se declara '
                          f'EXPERIMENTO no cabecalho — o runner nao o executa, '
                          f'e nao ha como saber se e de proposito')

    if falhas:
        print('a suite nao esta consistente:')
        for x in falhas:
            print(f'  {x}')
        return 1

    print(f'OK — {len(no_disco)} arquivo(s) de suite, todos na lista do '
          f'gerador e no vocabulario canonico; {len(diagnosticos)} '
          f'diagnostico(s)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
