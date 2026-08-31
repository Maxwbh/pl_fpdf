# -*- coding: utf-8 -*-
"""
Valida os codigos de barras de referencia contra um decodificador real.

O PL_FPDF implementa as mesmas simbologias em PL/SQL (procedure AddBarcode).
Esta referencia prova o algoritmo e gera os vetores usados em
tests/test_core.sql.

Uso:
    pip install zxing-cpp numpy
    python scripts/barcode_reference/validate.py
    python scripts/barcode_reference/validate.py vetores
"""
import random
import re
import string
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit('/', 1)[0])
import barcode_reference as bc  # noqa: E402

try:
    import zxingcpp
except ImportError:
    print('Instale o decodificador: pip install zxing-cpp')
    raise SystemExit(1)


def render(modulos, altura=80, escala=3, silencio=12):
    largura = (len(modulos) + 2 * silencio) * escala
    img = np.ones((altura + 20, largura), dtype=np.uint8) * 255
    for i, m in enumerate(modulos):
        if m == '1':
            x = (silencio + i) * escala
            img[10:10 + altura, x:x + escala] = 0
    return img


FIXOS = [('PL-FPDF-123', 'CODE39'), ('PL FPDF 2026', 'CODE39'),
         ('ABC123abc', 'CODE128'), ('12345678', 'CODE128'),
         ('789123456789', 'EAN13'), ('7891234567895', 'EAN13'),
         ('1234567', 'EAN8'), ('1234567890123', 'ITF14'),
         # o codigo de barras do boleto: ITF puro, 44 digitos, sem verificador
         # de simbologia. E o caso que o ITF14 nao cobre — e o que o
         # AddBarcodeBoleto precisava.
         # 44 digitos exatos, montado da linha digitavel de um boleto Itau real
         ('34197167700000150001090000012323073123451000', 'ITF'),
         ('00190000090123456789012345678901234567890123', 'ITF')]


def casos():
    lista = list(FIXOS)
    random.seed(3)
    for _ in range(8):
        t = ''.join(random.choice(string.ascii_uppercase + string.digits + '-. ')
                    for _ in range(random.randint(1, 20))).strip() or 'A'
        lista.append((t, 'CODE39'))
    for _ in range(8):
        lista.append((''.join(random.choice(string.ascii_letters + string.digits + '-_.')
                              for _ in range(random.randint(1, 24))), 'CODE128'))
    for _ in range(5):
        lista.append((''.join(random.choice('0123456789') for _ in range(12)), 'EAN13'))
    for _ in range(4):
        lista.append((''.join(random.choice('0123456789') for _ in range(7)), 'EAN8'))
    for _ in range(5):
        lista.append((''.join(random.choice('0123456789') for _ in range(13)), 'ITF14'))
    for _ in range(5):
        lista.append((''.join(random.choice('0123456789') for _ in range(44)), 'ITF'))
    return lista


def main():
    ok = 0
    lista = casos()
    for dado, tipo in lista:
        modulos = bc.make(dado, tipo)
        lido = zxingcpp.read_barcode(render(modulos))
        texto = lido.text if lido else None
        # EAN e ITF devolvem o codigo com o digito verificador incluido
        if texto and (texto == dado or texto.startswith(dado)):
            ok += 1
        else:
            print(f'  FALHA {tipo} {dado!r} -> {texto!r}')
    print(f'{ok}/{len(lista)} codigos decodificados corretamente')
    return 0 if ok == len(lista) else 1


def vetores():
    """Vetores para tests/test_core.sql: numero de barras por codigo."""
    for dado, tipo in [('PL-FPDF-123', 'CODE39'), ('ABC123abc', 'CODE128'),
                       ('12345678', 'CODE128'), ('789123456789', 'EAN13'),
                       ('1234567', 'EAN8'), ('1234567890123', 'ITF14')]:
        m = bc.make(dado, tipo)
        barras = len(re.findall(r'1+', m))
        print(f"add('{dado}', '{tipo}', {barras});   -- {len(m)} modulos")


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'vetores':
        vetores()
    else:
        raise SystemExit(main())
