# -*- coding: utf-8 -*-
"""
Valida a referência do INFLATE contra o zlib.

O zlib é o oráculo: para cada entrada, o que esta implementação devolve tem de
ser byte a byte igual ao que o `zlib.decompress` devolve. Uma implementação
errada de inflate não "quase funciona" — ela produz alguns bytes plausíveis e
depois lixo, então comparar o resultado inteiro é o que vale.

Três coisas que este arquivo faz questão de cobrir, porque um corpus ingênuo
deixa todas de fora:

  1. **Os três tipos de bloco.** Dado aleatório vira bloco ARMAZENADO (o
     compressor desiste); dado pequeno vira Huffman FIXO; dado repetitivo vira
     Huffman DINÂMICO. Testar só com texto exercita um caminho e deixa dois
     sem cobertura. O teste conta os tipos e falha se algum não apareceu.

  2. **Cópia sobreposta.** Com distância 1 e comprimento 100, o mesmo byte se
     repete cem vezes: a origem da cópia avança junto com o destino. Copiar a
     fatia de uma vez, em vez de byte a byte, dá resultado errado — e só
     aparece em dado muito repetitivo.

  3. **Um PDF de verdade.** O caso de uso é xref em stream e object stream; o
     teste monta um com o próprio zlib, no mesmo formato que um produtor
     moderno geraria.

Uso:  python scripts/pdfinflate_reference/validate.py
"""
import os
import random
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pdfinflate_reference import (ErroInflate, Fluxo, Huffman,  # noqa: E402
                                  inflate, inflate_zlib)

FALHAS = []


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


def tipos_de_bloco(cru):
    """Quais tipos de bloco o DEFLATE cru usa: 0 armazenado, 1 fixo, 2 dinâmico."""
    f = Fluxo(cru)
    vistos = set()
    while True:
        final = f.bits(1)
        tipo = f.bits(2)
        vistos.add(tipo)
        if tipo == 0:
            f.alinhar()
            tam = f.dados[f.pos] | (f.dados[f.pos + 1] << 8)
            f.pos += 4 + tam
        else:
            # não vale a pena reimplementar: para saber os tipos basta o
            # primeiro bloco de cada fluxo dos testes, que é o caso aqui
            return vistos
        if final:
            return vistos


def main():
    random.seed(20260828)

    print('== ida e volta contra o zlib')
    casos = [
        ('vazio', b''),
        ('um byte', b'A'),
        ('texto curto', b'PL_FPDF inflate'),
        ('texto longo', b'o rato roeu a roupa do rei de roma. ' * 400),
        ('repetitivo', b'ABCABCABC' * 500),
        ('um byte repetido 5000x', b'\x00' * 5000),
        ('aleatorio 3 KB', bytes(random.randrange(256) for _ in range(3000))),
        ('aleatorio 40 KB', bytes(random.randrange(256) for _ in range(40000))),
        ('xref sintetica',
         b''.join(bytes([1, (i >> 8) & 0xFF, i & 0xFF, 0, 0])
                  for i in range(1, 2001))),
        ('binario com padrao', bytes(range(256)) * 60),
    ]
    for nome, dados in casos:
        for nivel in (0, 1, 6, 9):
            z = zlib.compress(dados, nivel)
            try:
                obtido = inflate_zlib(z)
            except ErroInflate as e:                          # noqa: BLE001
                check(False, f'{nome} (nivel {nivel}): erro {e}')
                continue
            check(obtido == dados,
                  f'{nome} (nivel {nivel}): {len(dados)} bytes conferem')

    print('\n== os tres tipos de bloco sao exercitados')
    vistos = set()
    for nome, dados in casos:
        for nivel in (0, 1, 6, 9):
            cru = zlib.compress(dados, nivel)[2:-4]
            try:
                vistos |= tipos_de_bloco(cru)
            except Exception:                                 # noqa: BLE001
                pass
    for tipo, rotulo in ((0, 'armazenado'), (1, 'Huffman fixo'),
                         (2, 'Huffman dinamico')):
        check(tipo in vistos, f'bloco {rotulo} aparece no corpus')

    print('\n== copia sobreposta (a armadilha do LZ77)')
    # distância 1: a origem avança junto com o destino
    for padrao, rep in ((b'x', 300), (b'ab', 400), (b'abc', 500)):
        dados = padrao * rep
        check(inflate_zlib(zlib.compress(dados, 9)) == dados,
              f'{padrao!r} repetido {rep}x volta identico')

    print('\n== stream de um PDF real (xref em stream)')
    # /W [1 2 1]: tipo, offset de 2 bytes, geracao — o formato tipico
    entradas = b''.join(bytes([1, (o >> 8) & 0xFF, o & 0xFF, 0])
                        for o in range(0, 4000, 7))
    z = zlib.compress(entradas, 6)
    check(inflate_zlib(z) == entradas,
          f'xref em stream de {len(entradas)} bytes ({len(z)} comprimidos)')

    obj_stm = (b'1 0 2 52 3 120 '
               + b'<</Type/Catalog/Pages 2 0 R>> '
               + b'<</Type/Pages/Count 1/Kids[3 0 R]>> '
               + b'<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]>>')
    check(inflate_zlib(zlib.compress(obj_stm, 9)) == obj_stm,
          'object stream com Catalog, Pages e Page')

    print('\n== dado invalido e recusado, nao decodificado errado')
    for rotulo, ruim in (
        ('tipo de bloco 3 (reservado)', bytes([0b00000111]) + b'\x00' * 8),
        ('fluxo truncado', zlib.compress(b'x' * 500, 9)[2:-4][:5]),
        ('cabecalho zlib invalido', b'\x00\x00' + b'\x00' * 8),
    ):
        try:
            (inflate_zlib if 'zlib' in rotulo else inflate)(ruim)
            check(False, f'{rotulo}: deveria ser recusado')
        except ErroInflate as e:                              # noqa: BLE001
            check(True, f'{rotulo}: recusado — {e}')

    print('\n' + ('TODOS OS TESTES PASSARAM' if not FALHAS else
                  f'{len(FALHAS)} FALHA(S):\n  ' + '\n  '.join(FALHAS)))
    return 1 if FALHAS else 0


if __name__ == '__main__':
    sys.exit(main())
