# -*- coding: utf-8 -*-
"""
Confere que todo `examples/*.sql` é exercitado pelo runner — e vem dali.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O exemplo é a **fonte**: é o que se publica, o que alguém copia e cola, e é
exatamente ele que o `scripts/run_tests.py` carrega e executa contra o banco.
Enquanto houve duas cópias do mesmo desenho — uma no exemplo e outra dentro do
runner —, elas divergiram: o conserto do rodapé do ingresso teve de ser
aplicado nos dois arquivos, e nada garantia que fosse.

Agora há uma fonte só, e esta verificação guarda as duas pontas disso:

1. **Todo exemplo é exercitado.** Um `.sql` em `examples/` sem amostra
   correspondente é documentação que nunca rodou contra o banco.
2. **A amostra vem do arquivo.** Se alguém colar de volta um bloco PL/SQL
   dentro do runner, a cópia volta a existir — e volta a poder divergir.

Uso:
    python scripts/plsql_lint/check_examples_sync.py
"""
import glob
import importlib.util
import io
import os
import sys

# Ancorado na RAIZ do repositorio, calculada a partir deste arquivo. Caminho
# relativo ao diretorio atual funciona enquanto todo mundo roda da raiz, e
# quebra no primeiro que nao roda.
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


def _raiz():
    """A raiz do repositorio, achada subindo ate encontrar o src/.

    Contar diretorios com dirname aninhado quebrou quando os scripts foram para
    dev/scripts/: o numero de niveis mudou e o erro so aparece em execucao.
    """
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.isdir(os.path.join(d, 'src')):
            return d
        d = os.path.dirname(d)
    raise SystemExit('nao achei a raiz do repositorio (procurando por src/)')


RAIZ = _raiz()


def runner():
    caminho = os.path.join(RAIZ, 'dev', 'scripts', 'run_tests.py')
    spec = importlib.util.spec_from_file_location('run_tests_lint', caminho)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    os.chdir(RAIZ)
    mod = runner()
    amostras = {nome: plsql for nome, plsql, _ in mod.AMOSTRAS}
    problemas = []
    conferidos = 0

    for caminho in sorted(glob.glob(do_repo('examples', '*.sql'))):
        nome = os.path.basename(caminho)[:-4]
        if nome not in amostras:
            problemas.append(
                f"{caminho}: não há amostra '{nome}' em scripts/run_tests.py — "
                f'o exemplo nunca roda contra o banco')
            continue
        if amostras[nome] != mod.exemplo(nome):
            problemas.append(
                f"{caminho}: a amostra '{nome}' NÃO vem deste arquivo. Use "
                f"exemplo('{nome}') em vez de colar o bloco no runner — duas "
                f'cópias do mesmo desenho divergem em silêncio')
            continue
        conferidos += 1

    if problemas:
        print('\n'.join(problemas))
        print(f'\n{len(problemas)} problema(s).')
        return 1

    print(f'OK — {conferidos} exemplo(s) em examples/ são carregados e '
          f'executados pelo runner')
    return 0


if __name__ == '__main__':
    sys.exit(main())
