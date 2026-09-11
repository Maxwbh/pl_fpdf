# -*- coding: utf-8 -*-
"""
Gera tests/run_all_tests.sql concatenando os blocos anônimos dos testes.

Por que gerar: a versão anterior usava `@@arquivo.sql` e `PROMPT`, que são
comandos do SQL*Plus. A **SQL Window** do PL/SQL Developer não os aceita — e é
onde os testes precisam rodar. Um único arquivo com todos os blocos anônimos,
cada um terminado por `/`, roda com "Execute" (F8) sem nenhum comando de
cliente.

Uso:
  python scripts/build_run_all.py          # regenera
  python scripts/build_run_all.py --check  # falha se estiver desatualizado
"""
import io
import os
import sys

# Ancorado na RAIZ do repositorio, calculada a partir deste arquivo. Caminho
# relativo ao diretorio atual funciona enquanto todo mundo roda da raiz, e
# quebra no primeiro que nao roda.
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


SAIDA = do_repo('dev', 'tests', 'run_all_tests.sql')

# Ordem de execução, por assunto: primeiro gerar, depois ler e manipular o
# que veio de fora, depois a segurança, e por fim o que guarda regressão.
# Ate setembro/2026 a ordem e os nomes eram por 'fase' de um roadmap de
# fevereiro que nao existe mais -- 'test_phase_4_1b' tinha ate a letra de
# uma subdivisao. Assunto envelhece menos que cronograma.
TESTES = [
    # Geração: do documento em branco ao arquivo pronto
    ('test_geracao_basica.sql',        'Geração: páginas, texto, desenho, imagem'),
    ('test_winansi.sql',               'Texto acentuado (WinAnsi)'),
    ('test_stream_imagem.sql',         'Escrita do stream de imagem'),
    ('test_core.sql',                  'Núcleo: buffers, NLS, QR, código de barras'),

    # Leitura e manipulação de um PDF que veio de fora
    ('test_leitura_pdf.sql',           'Leitura: cabeçalho, xref, trailer'),
    ('test_leitura_paginas.sql',       'Leitura: informações de página'),
    ('test_paginas_girar_remover.sql', 'Páginas: girar e remover'),
    ('test_marca_dagua.sql',           'Marca d\'água'),
    ('test_sobreposicao.sql',          'Sobreposição de texto e imagem'),
    ('test_mesclar_dividir.sql',       'Mesclar, dividir e extrair'),
    ('test_saida_modificada.sql',      'OutputModifiedPDF'),
    ('test_manipulacao_completa.sql',  'Manipulação: o caminho inteiro'),

    # Segurança do documento
    ('test_seguranca.sql',             'Criptografia, senhas e permissões'),

    # O que guarda o que já quebrou, e o que ninguém chamava
    ('test_regressoes_revisao.sql',    'Regressões das revisões de ago e set/2026'),
    ('test_compat_legado.sql',         'Compatibilidade com 0.9.4 e 2.0.0'),
    ('test_api_sem_chamador.sql',      'APIs públicas que ninguém chamava'),
]

CABECALHO = """--------------------------------------------------------------------------------
-- PL_FPDF - Suíte de testes completa
--
-- ARQUIVO GERADO por scripts/build_run_all.py — não edite à mão.
-- Para alterar um teste, edite o arquivo original em tests/ e rode:
--     python scripts/build_run_all.py
--
-- Como executar
-- -------------
-- PL/SQL Developer, SQL Window: abra este arquivo e execute (F8). Não há
-- comandos de cliente (SET, PROMPT, @) — só blocos anônimos PL/SQL. O
-- resultado aparece na aba Output.
--
-- SQL*Plus / SQLcl: rode `SET SERVEROUTPUT ON SIZE UNLIMITED` antes, já que
-- fora do PL/SQL Developer o DBMS_OUTPUT não vem habilitado.
--
-- IMPORTANTE: reconecte a sessão depois de recompilar o package. O PL_FPDF tem
-- estado (variáveis de package), e uma sessão que já o carregou passa a falhar
-- com ORA-04068 ou ORA-06508 ("não foi localizada a unidade de programa") em
-- TODAS as chamadas seguintes. O sintoma engana: parece package quebrado, mas
-- basta abrir uma sessão nova.
--
-- Cada bloco é independente: se um falhar, os seguintes continuam.
--------------------------------------------------------------------------------

"""


def montar():
    partes = [CABECALHO]
    for arquivo, titulo in TESTES:
        corpo = io.open(do_repo('dev', 'tests', '') + arquivo, encoding='utf-8').read().strip()
        partes.append(
            '--------------------------------------------------------------------------------\n'
            f'-- {titulo}\n'
            f'-- origem: tests/{arquivo}\n'
            '--------------------------------------------------------------------------------\n'
            + corpo + '\n\n')
    return ''.join(partes)


def main():
    novo = montar()
    if '--check' in sys.argv:
        try:
            atual = io.open(SAIDA, encoding='utf-8').read()
        except FileNotFoundError:
            atual = None
        if atual != novo:
            print(f'{SAIDA} está desatualizado. Rode: python scripts/build_run_all.py')
            return 1
        print(f'{SAIDA} está atualizado ({len(TESTES)} testes)')
        return 0
    io.open(SAIDA, 'w', encoding='utf-8').write(novo)
    print(f'{SAIDA} gerado com {len(TESTES)} testes '
          f'({novo.count(chr(10))} linhas)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
