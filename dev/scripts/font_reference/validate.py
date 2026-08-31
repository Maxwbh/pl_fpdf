# -*- coding: utf-8 -*-
"""
Confere as tabelas de largura do package contra as fontes primárias.

DOCUMENTO DE MANUTENÇÃO.

Compara, posição a posição, o que o `PL_FPDF.pkb` tem hoje com o que sai do
`font_reference.py` — que deriva tudo do AFM da Adobe, da CP1252 e da Adobe
Glyph List. Uma divergência aqui é uma de duas coisas, e as duas interessam:
erro de mapeamento meu, ou erro de transcrição que atravessou o porte.

Uso:  python dev/scripts/font_reference/validate.py
"""
import io
import os
import re
import sys

import font_reference

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
PKB = os.path.join(RAIZ, 'src', 'PL_FPDF.pkb')

# As tabelas geradas vivem no p_digitos_da_familia, um ramo por familia, cada
# um com 256 campos de 4 digitos partidos em varios literais concatenados.
GERADA = re.compile(r"when\s+'(\w+)'\s+then\s+return\s+((?:\s*'[0-9]*'\s*\|?\|?)+);",
                    re.I)
LITERAL = re.compile(r"'([0-9]*)'")

# O mapa chave->familia, que antes existia duas vezes escrito a mao. Conferir
# que ele cobre as 14 chaves importa tanto quanto conferir as larguras: foi
# ali que o 'timesB' virou um segundo 'timesI' e o ramo do negrito sumiu.
MAPA = re.compile(r"when\s+'([a-z]+)'\s+then\s+'(\w+)'", re.I)
CHAVES_ESPERADAS = {
    'courier': 'Courier', 'courierb': 'Courier', 'courieri': 'Courier',
    'courierbi': 'Courier', 'helvetica': 'Helvetica',
    'helveticab': 'Helveticab', 'helveticai': 'Helveticai',
    'helveticabi': 'Helveticabi', 'times': 'Times', 'timesb': 'Timesb',
    'timesi': 'Timesi', 'timesbi': 'Timesbi', 'symbol': 'Symbol',
    'zapfdingbats': 'Zapfdingbats',
}


def tabelas_do_package():
    """{'Helvetica': {codigo: largura}} lido do body."""
    texto = io.open(PKB, encoding='utf-8').read()
    fora = {}
    for m in GERADA.finditer(texto):
        digitos = ''.join(LITERAL.findall(m.group(2)))
        if len(digitos) != 256 * 4:
            raise SystemExit(f'{m.group(1)}: esperava 1024 digitos, '
                             f'achei {len(digitos)}')
        fora[m.group(1)] = {c: int(digitos[c * 4:c * 4 + 4])
                            for c in range(256)}
    if not fora:
        raise SystemExit('nao achei nenhuma tabela gerada no .pkb — o bloco foi '
                         'editado a mao? Rode gerar.py')
    return fora


def conferir_mapa():
    """As 14 chaves resolvem para a familia certa, sem duplicata nem falta."""
    texto = io.open(PKB, encoding='utf-8').read()
    ini = texto.find('function p_larguras_da_fonte')
    if ini < 0:
        raise SystemExit('nao achei p_larguras_da_fonte no .pkb')
    corpo = texto[ini:texto.index('end p_larguras_da_fonte;', ini)]
    achado = MAPA.findall(corpo)

    chaves = [c.lower() for c, _ in achado]
    repetidas = {c for c in chaves if chaves.count(c) > 1}
    if repetidas:
        raise SystemExit(f'chave repetida no mapa: {sorted(repetidas)} — foi '
                         f'exatamente esse o bug do timesI duplicado')

    tem = {c.lower(): f for c, f in achado}
    if tem != CHAVES_ESPERADAS:
        faltam = set(CHAVES_ESPERADAS) - set(tem)
        sobram = set(tem) - set(CHAVES_ESPERADAS)
        erradas = {c for c in set(tem) & set(CHAVES_ESPERADAS)
                   if tem[c] != CHAVES_ESPERADAS[c]}
        raise SystemExit(f'mapa chave->familia divergente. '
                         f'faltam={sorted(faltam)} sobram={sorted(sobram)} '
                         f'erradas={sorted(erradas)}')
    return len(tem)


def main():
    n_chaves = conferir_mapa()
    print(f'  OK    mapa chave->família: {n_chaves} chaves, sem duplicata')
    do_pkb = tabelas_do_package()
    do_afm = font_reference.todas()

    faltando = set(do_afm) - set(do_pkb)
    if faltando:
        print(f'no package não achei: {sorted(faltando)}')
        return 1

    total_div = 0
    for familia in do_afm:
        ref, pkg = do_afm[familia], do_pkb[familia]
        divs = [(c, pkg.get(c), ref[c]) for c in range(256)
                if pkg.get(c) != ref[c]]
        marca = 'OK   ' if not divs else 'DIFERE'
        print(f'  {marca} {familia:<14} {len(pkg)} posições no package, '
              f'{len(divs)} divergência(s)')
        for c, tem, deveria in divs[:12]:
            try:
                vis = repr(bytes([c]).decode('cp1252'))
            except UnicodeDecodeError:
                vis = '(sem glifo na CP1252)'
            print(f'        código {c:>3} {vis:<10} package={tem} AFM={deveria}')
        if len(divs) > 12:
            print(f'        ... e mais {len(divs) - 12}')
        total_div += len(divs)

    print()
    if total_div:
        print(f'{total_div} divergência(s). Nenhuma tabela foi alterada: '
              f'decida caso a caso antes de gerar.')
        return 1
    print('OK — as 11 tabelas do package conferem com o AFM da Adobe, '
          'a CP1252 e a Adobe Glyph List.')
    return 0


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(main())
