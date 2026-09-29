# -*- coding: utf-8 -*-
"""
Confere a fonte embutida contra o MuPDF: o texto sai, e sai com a fonte certa.

DOCUMENTO DE MANUTENÇÃO.

O critério aqui não é "o arquivo abre". É:

1. o MuPDF **extrai o texto** que se pediu, caractere a caractere -- inclusive
   os acentuados, que são o motivo de alguém embutir fonte;
2. o MuPDF diz que a fonte está **embutida**, e com o nome certo;
3. a largura que o MuPDF mede para cada caractere bate com a que o
   `/Widths` declara -- é isso que separa "a fonte está lá" de "o leitor usa a
   fonte que está lá". Um `/Widths` errado desenha o texto com espaçamento de
   outra fonte, e o arquivo abre perfeitamente.

O item 3 é o que pega o erro que interessa na porta para PL/SQL: ler `hmtx` com
o `numberOfHMetrics` errado, ou esquecer de reescalar de `unitsPerEm` para
1000, produz exatamente isso.

Uso:  python dev/scripts/ttfembed_reference/validate.py
"""
import io
import os
import sys

import pymupdf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ttfembed_reference as ref                                  # noqa: E402

FONTES = [
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',
]
TEXTO = 'Endereco de cobranca ABC xyz 0123'
TEXTO_ACENTO = 'Endereço de cobrança — São Paulo'


def conferir(caminho, texto):
    fonte = ref.ler_fonte(caminho)
    pdf = ref.montar_pdf(fonte, texto)

    doc = pymupdf.open(stream=pdf, filetype='pdf')
    pagina = doc[0]

    # 1. o texto sai inteiro
    saiu = pagina.get_text().strip()
    if saiu != texto:
        return False, f'texto extraido difere:\n  esperado {texto!r}\n  saiu    {saiu!r}'

    # 2. a fonte esta embutida
    fontes = pagina.get_fonts(full=True)
    if not fontes:
        return False, 'nenhuma fonte no recurso da pagina'
    xref, ext, tipo, nome_base, *_ = fontes[0]
    if ext in ('n/a', ''):
        return False, f'a fonte {nome_base} NAO esta embutida (ext={ext})'

    # 3. as larguras que o leitor usa sao as que o /Widths declara
    dados = doc.extract_font(xref)
    if not dados or not dados[3]:
        return False, 'o MuPDF nao devolveu o programa da fonte'

    divergentes = []
    for span in pagina.get_text('rawdict')['blocks'][0]['lines'][0]['spans']:
        for c in span['chars']:
            b = c['c'].encode('cp1252')[0]
            largura_pdf = fonte['larguras'][b - ref.PRIMEIRO] / 1000 * span['size']
            medida = c['bbox'][2] - c['bbox'][0]
            # o bbox do MuPDF e o avanco do glifo nesta fonte simples
            if abs(medida - largura_pdf) > 0.05:
                divergentes.append((c['c'], round(medida, 3),
                                    round(largura_pdf, 3)))
    if divergentes:
        return False, ('largura medida difere da declarada em '
                       + str(len(divergentes)) + ' caractere(s): '
                       + str(divergentes[:5]))

    return True, (f'{os.path.basename(caminho)}: {len(texto)} caracteres, '
                  f'fonte {nome_base} embutida ({ext}), '
                  f'{len(fonte["bytes"])} bytes -> '
                  f'{len(fonte["bytes"]) * 2 + 1} em hexadecimal')


def main():
    falhas = 0
    for caminho in FONTES:
        if not os.path.exists(caminho):
            print(f'  PULADO (nao instalada): {caminho}')
            continue
        for texto in (TEXTO, TEXTO_ACENTO):
            ok, msg = conferir(caminho, texto)
            print(('  OK   ' if ok else '  FALHA ') + msg)
            falhas += 0 if ok else 1
    if falhas:
        print(f'\n{falhas} divergencia(s)')
        return 1
    print('\nOK — a fonte embutida atravessa o MuPDF: texto, embutimento e '
          'larguras')
    return 0


if __name__ == '__main__':
    sys.exit(main())
