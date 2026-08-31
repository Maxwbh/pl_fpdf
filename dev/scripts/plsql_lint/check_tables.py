# -*- coding: utf-8 -*-
"""
Compara as tabelas constantes do PL_FPDF_UTIL.pkb com as referências Python
validadas contra decodificadores reais (zxing-cpp para QR e código de barras).

Motivo: as tabelas foram transcritas à mão da referência para constantes
`VARCHAR2` concatenadas com `||`. Uma linha do `co_bc128` ficou sem o espaço
final, então `...231212' || '112232...` virava `231212112232`: a tabela passou
a ter 89 campos em vez de 107, e o CODE128 estourava com ORA-06502 em tempo de
execução. O código compilava e as outras simbologias passavam — só um vetor de
teste no banco revelava.

Esta verificação roda sem banco e pega esse tipo de erro de transcrição na hora.

Uso:
  python scripts/plsql_lint/check_tables.py
"""
import io
import re
import os
import sys

# Ancorado neste arquivo, e nao no diretorio atual: com caminho relativo ao
# CWD o import so achava as referencias quando se rodava da raiz.
_REFS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = os.path.dirname(os.path.dirname(_REFS))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)

sys.path.insert(0, os.path.join(_REFS, 'barcode_reference'))
sys.path.insert(0, os.path.join(_REFS, 'qr_reference'))

from barcode_reference import C39, C128, EAN_L, EAN_G, EAN_R, EAN_PARITY, ITF  # noqa: E402
import qr_reference  # noqa: E402

# As tabelas do QR e dos codigos de barras sairam do PL_FPDF quando o
# utilitario foi separado: elas nao tem nada de PDF.
PKB = do_repo('src', 'PL_FPDF_UTIL.pkb')


def constante(src, nome):
    """Valor de uma constante VARCHAR2 declarada com literais concatenados."""
    m = re.search(
        r"  %s constant varchar2\(\d+\) :=\n((?:    '[^']*'(?: \|\|)?\n)*    '[^']*';)" % nome,
        src)
    if not m:
        raise AssertionError(f'constante {nome} não encontrada em {PKB}')
    return ''.join(re.findall(r"'([^']*)'", m.group(1)))


def main():
    src = io.open(PKB, encoding='utf-8').read()
    falhas = []

    def check(nome, obtido, esperado, desc=''):
        if obtido == esperado:
            print(f'  OK    {nome}{desc}')
        else:
            falhas.append(nome)
            print(f'  FALHA {nome}: {len(obtido)} vs {len(esperado)} esperado')
            for i, (a, b) in enumerate(zip(obtido, esperado)):
                if a != b:
                    print(f'        primeira divergência no índice {i}: '
                          f'{a!r} vs {b!r} (esperado)')
                    break

    print('Códigos de barras (referência validada em zxing-cpp, 38/38):')
    check('co_bc128', constante(src, 'co_bc128').split(), C128,
          f' ({len(C128)} padrões)')
    chars = constante(src, 'co_bc39_chars')
    check('co_bc39_chars', chars, ''.join(C39.keys()))
    check('co_bc39_pats', constante(src, 'co_bc39_pats'),
          ''.join(C39[c] for c in chars))
    check('co_bc_ean_l', constante(src, 'co_bc_ean_l'), ''.join(EAN_L))
    check('co_bc_ean_g', constante(src, 'co_bc_ean_g'), ''.join(EAN_G))
    check('co_bc_ean_r', constante(src, 'co_bc_ean_r'), ''.join(EAN_R))
    check('co_bc_ean_par', constante(src, 'co_bc_ean_par'), ''.join(EAN_PARITY))
    check('co_bc_itf', constante(src, 'co_bc_itf'), ''.join(ITF))

    print('\nQR Code (referência validada em zxing-cpp, 24/24):')
    for nivel, nome in (('L', 'co_qr_ecc_l'), ('M', 'co_qr_ecc_m'),
                        ('Q', 'co_qr_ecc_q'), ('H', 'co_qr_ecc_h')):
        linhas = constante(src, nome).split('|')
        esperado = [','.join(str(x) for x in qr_reference.ECC[nivel][v])
                    for v in range(1, 21)]
        check(nome, linhas, esperado, f' ({len(esperado)} versões)')
    al = constante(src, 'co_qr_align').split('|')
    check('co_qr_align', al,
          [','.join(str(x) for x in qr_reference.ALIGN[v]) for v in range(1, 21)])

    if falhas:
        print(f'\n{len(falhas)} tabela(s) divergem da referência: '
              + ', '.join(falhas))
        return 1
    print('\nOK — todas as tabelas conferem com as referências validadas')
    return 0


if __name__ == '__main__':
    sys.exit(main())
