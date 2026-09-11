# -*- coding: utf-8 -*-
"""
Gera uma fonte TrueType mínima, válida, para o teste usar SEM arquivo em disco.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
`AddTTFFont` recebe um BLOB e `LoadTTFFromFile` lê de um DIRECTORY. A segunda
exige `READ` concedido ao schema, e **este projeto não depende de concessão
extra** — então o caminho que se testa é o do BLOB. Só que um BLOB de fonte
precisa vir de algum lugar, e ler de arquivo é justamente o que se quer evitar.

A saída daqui é uma constante hexadecimal que o teste embute, no mesmo padrão
que `test_stream_imagem.sql` já usa para o PNG. Sem disco, sem rede, sem grant.

Por que uma fonte DE VERDADE, e com métricas incomuns
-----------------------------------------------------
Até setembro de 2026 o `parse_ttf_header` conferia o *magic number* e
**inventava o resto**: `units_per_em := 1000`, `ascent := 800`,
`descent := -200` eram literais no código. Um `HEXTORAW('00010000')` seguido de
lixo passava.

Agora o parser lê as tabelas, e é por isso que esta fonte usa **2048 por em** e
métricas que não coincidem com nenhum valor redondo: assim cada número que o
package devolve só pode ter vindo do arquivo. Uma fonte com upm 1000 e
ascendente 800 não distinguiria "leu" de "chutou o de sempre".

O que a fonte tem: `.notdef` e a letra A, as tabelas obrigatórias, e nada mais.

Uso:
  python dev/scripts/ttf_reference/gerar.py            # imprime o bloco PL/SQL
  python dev/scripts/ttf_reference/gerar.py --check    # confere o que o teste tem
"""
import io
import os
import re
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))
TESTE = os.path.join(RAIZ, 'dev', 'tests', 'test_api_sem_chamador.sql')

# 2048 de proposito, e nao 1000: ate setembro/2026 o parser INVENTAVA as
# metricas -- upm 1000, ascent 800, descent -200 eram literais no codigo. Uma
# fonte com esses mesmos valores nao distinguiria "leu do arquivo" de "chutou o
# de sempre". Com 2048 e as metricas abaixo, cada numero que o package devolve
# so pode ter vindo do arquivo.
UPM = 2048
NOME = 'PLFPDFTeste'


def montar():
    """Os bytes de uma TTF mínima e válida."""
    fb = FontBuilder(UPM, isTTF=True)
    ordem = ['.notdef', 'A']
    fb.setupGlyphOrder(ordem)
    fb.setupCharacterMap({ord('A'): 'A'})

    caneta = TTGlyphPen(None)
    caneta.moveTo((120, 0))
    caneta.lineTo((980, 0))
    caneta.lineTo((550, 1430))
    caneta.closePath()
    glifo_a = caneta.glyph()

    vazio = TTGlyphPen(None).glyph()
    fb.setupGlyf({'.notdef': vazio, 'A': glifo_a})
    fb.setupHorizontalMetrics({'.notdef': (1024, 0), 'A': (1234, 120)})
    fb.setupHorizontalHeader(ascent=1900, descent=-500, lineGap=0)
    fb.setupNameTable({'familyName': NOME, 'styleName': 'Regular',
                       'psName': NOME + '-Regular'})
    fb.setupOS2(sTypoAscender=1900, sTypoDescender=-500, sCapHeight=1430,
                sxHeight=1000)
    fb.setupPost()

    buf = io.BytesIO()
    fb.save(buf)
    return buf.getvalue()


def conferir(bytes_):
    """Reabre com o fontTools. Uma fonte que ele recusa nao serve de amostra."""
    f = TTFont(io.BytesIO(bytes_))
    assert f['head'].unitsPerEm == UPM, f['head'].unitsPerEm
    assert f['hhea'].ascent == 1900, f['hhea'].ascent
    assert f['hhea'].descent == -500, f['hhea'].descent
    assert 'A' in f.getGlyphOrder(), f.getGlyphOrder()
    assert bytes_[:4] == b'\x00\x01\x00\x00', bytes_[:4].hex()
    return {'tamanho': len(bytes_), 'upm': f['head'].unitsPerEm,
            'ascent': f['hhea'].ascent, 'descent': f['hhea'].descent,
            'glifos': f.getGlyphOrder()}


def em_pedacos(hexa, por_linha=64):
    return [hexa[i:i + por_linha] for i in range(0, len(hexa), por_linha)]


def bloco_plsql(hexa):
    """O hexadecimal como UMA atribuicao, com as continuacoes concatenadas.

    A primeira versao disto emitia `l_hex := '...'` em TODA linha, sem
    terminador em nenhuma menos a ultima -- nao era PL/SQL, e so apareceu na
    primeira execucao contra o banco, com ORA-06550. Nenhum verificador daqui
    analisa sintaxe de PL/SQL, entao a rodada no banco e o que pega isto.
    """
    linhas = em_pedacos(hexa)
    saida = ["    l_hex := '" + linhas[0] + "'"]
    for l in linhas[1:]:
        saida.append("           || '" + l + "'")
    saida[-1] = saida[-1] + ';'
    return '\n'.join(saida)


def hex_do_teste():
    """O hexadecimal que o arquivo de teste tem hoje, concatenado."""
    try:
        t = io.open(TESTE, encoding='utf-8').read()
    except FileNotFoundError:
        return None
    m = re.search(r'-- TTF-INICIO(.*?)-- TTF-FIM', t, re.S)
    if not m:
        return None
    return ''.join(re.findall(r"'([0-9A-Fa-f]+)'", m.group(1)))


def main():
    bytes_ = montar()
    info = conferir(bytes_)
    hexa = bytes_.hex().upper()

    if '--check' in sys.argv:
        atual = hex_do_teste()
        if atual is None:
            print('nao achei o bloco TTF-INICIO/TTF-FIM em '
                  + os.path.relpath(TESTE, RAIZ))
            return 1
        # A fonte e gerada de novo a cada rodada e o fontTools pode mudar de
        # versao, entao o que se confere e que o teste tem uma fonte VALIDA --
        # nao que ela seja byte a byte esta.
        try:
            conferir(bytes.fromhex(atual))
        except Exception as e:                                  # noqa: BLE001
            print(f'a fonte embutida no teste nao e valida: {e}')
            return 1

        # A FORMA tambem, e nao so o conteudo: foi uma forma errada -- uma
        # atribuicao por linha, sem terminador -- que derrubou a compilacao do
        # bloco inteiro na primeira rodada contra o banco.
        esperado = bloco_plsql(atual.upper())
        t = io.open(TESTE, encoding='utf-8').read()
        if esperado not in t:
            print('o bloco embutido nao tem a forma que este gerador produz. '
                  'Rode sem --check e substitua o trecho entre TTF-INICIO e '
                  'TTF-FIM.')
            return 1
        print(f'OK — o teste tem uma TTF valida de {len(atual) // 2} bytes, '
              f'na forma que o gerador produz')
        return 0

    print(f'-- fonte gerada por dev/scripts/ttf_reference/gerar.py')
    print(f'-- {info["tamanho"]} bytes, upm {info["upm"]}, '
          f'ascent {info["ascent"]}, descent {info["descent"]}, '
          f'glifos {info["glifos"]}')
    print(bloco_plsql(hexa))
    return 0


if __name__ == '__main__':
    sys.exit(main())
