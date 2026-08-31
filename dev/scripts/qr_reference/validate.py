# -*- coding: utf-8 -*-
"""
Valida o codificador QR de referência contra um decodificador real.

O PL_FPDF implementa o mesmo algoritmo em PL/SQL (procedure AddQRCode). Esta
referência existe para provar o algoritmo e para gerar os vetores usados em
tests/test_core.sql — a suíte PL/SQL compara a matriz gerada no banco com os
números produzidos aqui.

Uso:
    pip install zxing-cpp numpy
    python scripts/qr_reference/validate.py
"""
import random
import string
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit('/', 1)[0])
import qr_reference as qr  # noqa: E402

try:
    import zxingcpp
except ImportError:
    print('Instale o decodificador: pip install zxing-cpp')
    raise SystemExit(1)


def render(matrix, scale=8, quiet=4):
    n = len(matrix)
    size = (n + 2 * quiet) * scale
    img = np.ones((size, size), dtype=np.uint8) * 255
    for i in range(n):
        for j in range(n):
            if matrix[i][j]:
                y, x = (i + quiet) * scale, (j + quiet) * scale
                img[y:y + scale, x:x + scale] = 0
    return img


PIX = ('00020126360014BR.GOV.BCB.PIX0114+5531999999995204000053039865802BR'
       '5913M&S do Brasil6008BRASILIA62070503***63041D3D')

CASOS = [('PL_FPDF', 'M'), ('https://msbrasil.inf.br', 'M'), (PIX, 'M'),
         ('teste com acento: ção', 'L'), ('X', 'H'), ('teste', 'H'),
         ('1234567890', 'L'), ('B' * 100, 'Q'), ('C' * 300, 'M')]

random.seed(11)
alfabeto = string.ascii_letters + string.digits + ' .:/-+'
for _ in range(15):
    n = random.randint(1, 400)
    CASOS.append((''.join(random.choice(alfabeto) for _ in range(n)),
                  random.choice('LMQH')))


def main():
    ok = 0
    for texto, nivel in CASOS:
        matriz, versao, mascara = qr.make_qr(texto, nivel)
        lido = zxingcpp.read_barcode(render(matriz))
        if lido and lido.text == texto:
            ok += 1
        else:
            print(f'  FALHA v{versao} {nivel} {len(texto)}ch mascara={mascara}')
    print(f'{ok}/{len(CASOS)} simbolos decodificados corretamente')
    return 0 if ok == len(CASOS) else 1


def vetores():
    """Imprime os vetores usados em tests/test_core.sql."""
    for texto, nivel in [('PL_FPDF', 'M'), ('https://msbrasil.inf.br', 'M'),
                         (PIX, 'M'), ('teste', 'H'), ('1234567890', 'L')]:
        m, v, _ = qr.make_qr(texto, nivel)
        escuros = sum(sum(linha) for linha in m)
        print(f"add('{texto}', '{nivel}', {escuros});   -- v{v}, {len(m)}x{len(m)}")


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'vetores':
        vetores()
    else:
        raise SystemExit(main())
