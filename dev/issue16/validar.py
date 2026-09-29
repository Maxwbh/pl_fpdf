# -*- coding: utf-8 -*-
"""
Valida no banco o conserto da issue 16 do projeto de origem.

DOCUMENTO DE MANUTENÇÃO. Nada aqui vai para quem usa a biblioteca, e nada aqui
vai para o projeto de origem: o que vai para lá é o patch, e só depois que esta
medição passar.

O QUE ELE FAZ, e por que assim
------------------------------
Instala a 2.0.0 DUAS vezes no seu schema, com nomes próprios --
`PL_FPDF_I16_ANTES` e `PL_FPDF_I16_DEPOIS` --, roda os mesmos quatro casos em
cada uma e compara. Instalar como `PL_FPDF` derrubaria a 3.4.0 do schema; o
nome existe para isso, e os dois packages são removidos no fim.

A COMPARAÇÃO É O TESTE. Um caso que passa nas duas não prova nada: prova que
esta instância não alcança aquele defeito. O que vale é a diferença -- o que
levanta ANTES e responde DEPOIS --, e é o que o resumo mostra.

Os quatro casos, e o defeito que cada um alcança:

  1. Init + AddPage          o relato da issue: ORA-29275 ao montar a tabela de
                             larguras, onde o CHR passa de 191
  2. GetStringWidth acentuado  ORA-06502: `c car` guarda UM byte e o acentuado
                             tem dois, em AL32UTF8
  3. MultiCell acentuado     NO_DATA_FOUND: consulta com o caractere cru, e a
                             chave da tabela é outra coisa
  4. documento inteiro       fecha o arquivo, o que passa pelo /Widths -- o
                             segundo lugar onde o mesmo CHR aparece

Uso:
  python dev/issue16/montar.py                       # gera os dois packages
  python dev/issue16/validar.py --dsn <alias> --user <usuario>
  python dev/issue16/validar.py ... --manter         # não remove no fim

A senha vem de PLFPDF_PASSWORD ou do prompt -- nunca da linha de comando.
"""
import argparse
import getpass
import io
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(AQUI, 'build')
ANTES = 'PL_FPDF_I16_ANTES'
DEPOIS = 'PL_FPDF_I16_DEPOIS'

# O texto acentuado é o mesmo do relato de quem usa a biblioteca em português:
# cedilha e til, que são justamente as posições acima de 127 do WinAnsi.
FRASE = 'cobrança em São Paulo'

# Cada caso escreve UMA linha, e a linha é o dado: nome|OK|detalhe ou
# nome|ERRO|mensagem. Interpretar em Python, e não no PL/SQL, deixa o bloco
# pequeno o bastante para caber na cabeça de quem lê.
BLOCO = """
DECLARE
  l_larg  NUMBER;
  l_pdf   BLOB;
  l_tam   PLS_INTEGER;

  PROCEDURE conta(p_caso VARCHAR2, p_ok BOOLEAN, p_detalhe VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(p_caso || '|' || CASE WHEN p_ok THEN 'OK' ELSE 'ERRO'
                         END || '|' || SUBSTR(p_detalhe, 1, 300));
  END;
BEGIN
  --------------------------------------------------------------------- 1
  BEGIN
    {PKG}.Reset;
    {PKG}.Init('P', 'mm', 'A4');
    {PKG}.AddPage;
    conta('addpage', TRUE, 'a primeira pagina abriu');
  EXCEPTION
    WHEN OTHERS THEN conta('addpage', FALSE, SQLERRM);
  END;

  --------------------------------------------------------------------- 2
  BEGIN
    {PKG}.Reset;
    {PKG}.Init('P', 'mm', 'A4');
    {PKG}.AddPage;
    {PKG}.SetFont('Helvetica', '', 12);
    l_larg := {PKG}.GetStringWidth('{FRASE}');
    conta('largura', TRUE, TO_CHAR(ROUND(l_larg, 4)));
  EXCEPTION
    WHEN OTHERS THEN conta('largura', FALSE, SQLERRM);
  END;

  --------------------------------------------------------------------- 3
  BEGIN
    {PKG}.Reset;
    {PKG}.Init('P', 'mm', 'A4');
    {PKG}.AddPage;
    {PKG}.SetFont('Helvetica', '', 12);
    {PKG}.MultiCell(60, 6, '{FRASE} com texto longo o bastante para quebrar');
    conta('multicell', TRUE, 'quebrou a linha sem levantar');
  EXCEPTION
    WHEN OTHERS THEN conta('multicell', FALSE, SQLERRM);
  END;

  --------------------------------------------------------------------- 4
  BEGIN
    {PKG}.Reset;
    {PKG}.Init('P', 'mm', 'A4');
    {PKG}.AddPage;
    {PKG}.SetFont('Helvetica', '', 12);
    {PKG}.Cell(100, 10, '{FRASE}');
    l_pdf := {PKG}.OutputBlob;
    l_tam := DBMS_LOB.GETLENGTH(l_pdf);
    conta('documento', l_tam > 0, l_tam || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN conta('documento', FALSE, SQLERRM);
  END;

  BEGIN {PKG}.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
END;
"""

ROTULOS = {
    'addpage':   'Init + AddPage (o relato da issue)',
    'largura':   'GetStringWidth com acento',
    'multicell': 'MultiCell com acento',
    'documento': 'documento inteiro, do Cell ao OutputBlob',
}


def conectar(args):
    import oracledb
    if args.wallet:
        os.environ['TNS_ADMIN'] = args.wallet
    senha = args.password or os.environ.get('PLFPDF_PASSWORD')
    if not senha:
        senha = getpass.getpass(f'Senha de {args.user}@{args.dsn}: ')
    return oracledb.connect(user=args.user, password=senha, dsn=args.dsn,
                            config_dir=os.environ.get('TNS_ADMIN'))


def saida_do_servidor(con):
    """O que o bloco escreveu com DBMS_OUTPUT.

    get_lines recebe um array PL/SQL, não um var escalar: sem o arrayvar o
    Oracle recusa com PLS-00306.
    """
    linhas = []
    with con.cursor() as cur:
        lote = cur.arrayvar(str, 100, 32767)
        n = cur.var(int)
        while True:
            n.setvalue(0, 100)
            cur.callproc('dbms_output.get_lines', (lote, n))
            qtd = n.getvalue()
            linhas.extend(lote.getvalue()[:qtd])
            if qtd < 100:
                break
    return [l or '' for l in linhas]


def instalar(con, nome):
    """Spec e body, nessa ordem, e o que o USER_ERRORS disser."""
    for ext in ('pks', 'pkb'):
        caminho = os.path.join(BUILD, f'{nome}.{ext}')
        if not os.path.exists(caminho):
            raise SystemExit(f'{caminho} não existe. Rode antes: '
                             f'python dev/issue16/montar.py')
        fonte = io.open(caminho, encoding='utf-8').read()
        # o arquivo da origem termina com '/' na própria linha; o driver não o
        # aceita, e o mesmo tratamento está no run_tests.py
        fonte = re.sub(r'\n/\s*$', '', fonte.rstrip())
        with con.cursor() as cur:
            cur.execute(fonte)

    erros = []
    with con.cursor() as cur:
        cur.execute("""
            SELECT type, line, position, text
              FROM user_errors
             WHERE name = :n
             ORDER BY type, sequence""", n=nome)
        for tipo, linha, pos, texto in cur:
            erros.append(f'{tipo} {linha}:{pos} {texto.strip()}')
    return erros


def medir(con, nome):
    """Roda os quatro casos contra um dos packages e devolve {caso: (ok, det)}."""
    with con.cursor() as cur:
        cur.callproc('dbms_output.enable', (None,))
        cur.execute(BLOCO.replace('{PKG}', nome).replace('{FRASE}', FRASE))
    fora = {}
    for linha in saida_do_servidor(con):
        partes = linha.split('|', 2)
        if len(partes) == 3:
            fora[partes[0]] = (partes[1] == 'OK', partes[2])
    return fora


def remover(con, nome):
    with con.cursor() as cur:
        for tipo in ('PACKAGE BODY', 'PACKAGE'):
            try:
                cur.execute(f'DROP {tipo} {nome}')
            except Exception:       # já não existe, e é o que se queria
                pass


def main():
    p = argparse.ArgumentParser(description='Valida o conserto da issue 16.')
    p.add_argument('--user', required=True)
    p.add_argument('--password')
    p.add_argument('--dsn', required=True)
    p.add_argument('--wallet')
    p.add_argument('--manter', action='store_true',
                   help='não remove os dois packages no fim')
    args = p.parse_args()

    con = conectar(args)
    print(f'Conectado: {args.user}@{args.dsn}')
    with con.cursor() as cur:
        cur.execute("""SELECT value FROM nls_database_parameters
                        WHERE parameter = 'NLS_CHARACTERSET'""")
        charset = cur.fetchone()[0]
    print(f'NLS_CHARACTERSET = {charset}')
    if charset != 'AL32UTF8':
        print('   AVISO: a issue 16 é de banco AL32UTF8. Num banco de um byte')
        print('          todos os casos passam nas duas versões, e a medição')
        print('          não prova nada.')

    resultado = {}
    for nome in (ANTES, DEPOIS):
        print(f'\n== {nome}')
        erros = instalar(con, nome)
        if erros:
            print(f'   {len(erros)} erro(s) de compilação:')
            for e in erros[:20]:
                print(f'     {e}')
            return 2
        print('   sem erros de compilação')
        resultado[nome] = medir(con, nome)
        for caso, rotulo in ROTULOS.items():
            ok, det = resultado[nome].get(caso, (False, 'não respondeu'))
            print(f"   {'ok   ' if ok else 'ERRO '} {rotulo}: {det}")

    print('\n' + '=' * 74)
    print(f"{'caso':42} {'ANTES':>12} {'DEPOIS':>12}")
    print('-' * 74)
    consertados, quebrados, mudos = [], [], []
    for caso, rotulo in ROTULOS.items():
        a_ok, a_det = resultado[ANTES].get(caso, (False, '?'))
        d_ok, d_det = resultado[DEPOIS].get(caso, (False, '?'))
        print(f'{rotulo:42} {"ok" if a_ok else "ERRO":>12} '
              f'{"ok" if d_ok else "ERRO":>12}')
        if not a_ok and d_ok:
            consertados.append((rotulo, a_det))
        elif a_ok and not d_ok:
            quebrados.append((rotulo, d_det))
        elif a_ok and d_ok:
            mudos.append(rotulo)
    print('=' * 74)

    for rotulo, erro in consertados:
        print(f'CONSERTADO  {rotulo}')
        print(f'            antes: {erro}')
    for rotulo in mudos:
        print(f'igual       {rotulo}: passa nas duas, esta instância não '
              f'alcança o defeito')
    for rotulo, erro in quebrados:
        print(f'REGRESSÃO   {rotulo}: {erro}')

    if not args.manter:
        for nome in (ANTES, DEPOIS):
            remover(con, nome)
        print('\nos dois packages foram removidos do schema')
    con.close()

    print()
    if quebrados:
        print('FALHOU: o conserto quebrou algo que funcionava.')
        return 1
    if not all(ok for ok, _ in resultado[DEPOIS].values()):
        print('FALHOU: o conserto não fechou todos os casos.')
        return 1
    if not consertados:
        print('INCONCLUSIVO: nada falhava ANTES nesta instância. O conserto '
              'não quebrou nada,')
        print('              mas quem prova que ele resolve é outro banco.')
        return 0
    print(f'OK: {len(consertados)} caso(s) que levantavam agora respondem, e '
          f'nenhum regrediu.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
