# -*- coding: utf-8 -*-
"""
Embutir uma fonte TrueType num PDF: o que ler do arquivo e o que emitir.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
`AddTTFFont` guardava a fonte num cache que **nada consumia**: o `SetFont` não
o consultava e os bytes nunca iam para o PDF. Ligar as duas pontas exige ler o
arquivo de fonte de verdade — e ler formato de terceiro em PL/SQL sem uma
referência é como o QR Code era antes de agosto: desenha algo, e nenhum leitor
aceita.

Este módulo é a referência. Ele lê a TTF com `fontTools`, monta o PDF à mão
(sem biblioteca de PDF, para que a estrutura seja exatamente a que o PL/SQL vai
emitir) e o `validate.py` confere o resultado no MuPDF: o texto tem de sair, a
fonte tem de estar embutida, e as larguras têm de bater.

As decisões, e por quê
----------------------
**Fonte simples, `/Subtype /TrueType`, com `/WinAnsiEncoding`.** Não é
`/Type0`/CID. Desde a 3.4.0 o texto sai do package convertido para WinAnsi, em
escape octal — uma fonte simples com essa mesma codificação encaixa sem tocar
no caminho de texto. CID daria Unicode inteiro e exigiria reescrever a saída de
texto, o `/W`, o `CIDToGIDMap` e o mapa reverso; é outro trabalho.

**O programa da fonte sai em hexadecimal, com `/ASCIIHexDecode`.** É a mesma
razão da imagem: o documento é montado num CLOB e convertido no fim por
`DBMS_LOB.CONVERTTOBLOB`, que recodifica qualquer byte acima de `0x7F`. Byte
cru não atravessa. O custo é dobrar o tamanho do programa da fonte dentro do
arquivo — e é por isso que o subset (HU-02) importa tanto aqui.

**Sem subset.** A fonte inteira entra. Medido na HU-02: DejaVuSans são 759.720
bytes, que viram 1,5 MB de hexadecimal. Quem precisa de tipografia própria paga
isso até a HU-02 sair; quem só precisa de acento não precisa de fonte embutida
nenhuma desde a 3.4.0.

O que se lê do arquivo
----------------------
| tabela | o que sai dela |
|--------|----------------|
| `head` | `unitsPerEm`, a caixa (`xMin`..`yMax`), `indexToLocFormat` |
| `hhea` | `ascender`, `descender`, `numberOfHMetrics` |
| `hmtx` | a largura de avanço de cada glifo |
| `cmap` | ponto de código -> glifo (formato 4, plataforma 3/1) |
| `OS/2` | `sCapHeight`, `fsSelection` (itálico/negrito), `usWeightClass` |
| `post` | `italicAngle`, `isFixedPitch` |

Tudo em unidades da fonte, que o PDF quer reescaladas para 1000 por em.
"""
import io
import os

from fontTools.ttLib import TTFont

# WinAnsi: o que o package já usa na saída de texto. 32..255, e as 27 posições
# de 0x80 a 0x9F que não são Latin-1 vêm da tabela do cp1252.
PRIMEIRO, ULTIMO = 32, 255


def ponto_de_codigo(byte):
    """byte WinAnsi -> ponto de código Unicode."""
    try:
        return ord(bytes([byte]).decode('cp1252'))
    except UnicodeDecodeError:
        return None          # as 5 posições indefinidas do cp1252


def ler_fonte(caminho):
    """O que o PDF precisa saber sobre a fonte, já reescalado para 1000/em."""
    f = TTFont(caminho, fontNumber=0)
    upm = f['head'].unitsPerEm
    esc = lambda v: round(v * 1000 / upm)            # noqa: E731

    cmap = f.getBestCmap()
    hmtx = f['hmtx']
    ordem = f.getGlyphOrder()

    larguras, glifos = [], {}
    for b in range(PRIMEIRO, ULTIMO + 1):
        cp = ponto_de_codigo(b)
        nome = cmap.get(cp) if cp is not None else None
        if nome is None or nome not in hmtx.metrics:
            larguras.append(0)
        else:
            larguras.append(esc(hmtx.metrics[nome][0]))
            glifos[b] = ordem.index(nome)

    os2 = f['OS/2'] if 'OS/2' in f else None
    post = f['post'] if 'post' in f else None

    italico = bool(os2 and (os2.fsSelection & 0x01))
    negrito = bool(os2 and (os2.fsSelection & 0x20))
    fixa = bool(post and post.isFixedPitch)

    # /Flags do FontDescriptor (ISO 32000, tabela 123): bit 1 fixed pitch,
    # bit 3 serif, bit 6 nonsymbolic, bit 7 italic. Serif não se decide pelo
    # arquivo sem heurística, e errar nele não muda o desenho: fica fora.
    flags = 32                                        # nonsymbolic
    if fixa:
        flags |= 1
    if italico:
        flags |= 64

    return {
        'nome_ps': f['name'].getDebugName(6) or os.path.basename(caminho),
        'upm': upm,
        'bbox': [esc(f['head'].xMin), esc(f['head'].yMin),
                 esc(f['head'].xMax), esc(f['head'].yMax)],
        'ascent': esc(f['hhea'].ascender),
        'descent': esc(f['hhea'].descender),
        'cap_height': esc(os2.sCapHeight) if os2 and getattr(
            os2, 'sCapHeight', None) is not None else esc(f['hhea'].ascender),
        'italic_angle': float(post.italicAngle) if post else 0.0,
        'flags': flags,
        'negrito': negrito,
        'larguras': larguras,
        'glifos': glifos,
        'bytes': io.open(caminho, 'rb').read(),
    }


# ---------------------------------------------------------------- o PDF ----
def _obj(n, corpo):
    return f'{n} 0 obj\n{corpo}\nendobj\n'.encode('latin-1')


def montar_pdf(fonte, texto, tamanho=24):
    """Um PDF de uma página com o texto escrito na fonte embutida.

    A estrutura é montada à mão de propósito: é a mesma que o `p_putfonts` vai
    emitir, objeto por objeto, e serve de gabarito para a porta.
    """
    hexa = fonte['bytes'].hex().upper().encode('ascii')
    programa = hexa + b'>'                            # o '>' fecha o ASCIIHex

    # o texto vai em WinAnsi, com o escape octal que o package usa
    cru = texto.encode('cp1252')
    escapado = b''.join(
        b'\\%03o' % b if b > 0x7F or b in b'()\\' else bytes([b]) for b in cru)

    conteudo = (b'BT /F1 ' + str(tamanho).encode() + b' Tf 50 700 Td ('
                + escapado + b') Tj ET')

    objetos = [
        _obj(1, '<< /Type /Catalog /Pages 2 0 R >>'),
        _obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 '
                '/MediaBox [0 0 595.28 841.89] >>'),
        _obj(3, '<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R '
                '>> >> /Contents 5 0 R >>'),
        _obj(4, '<< /Type /Font /Subtype /TrueType /BaseFont /'
                + fonte['nome_ps'] + ' /FirstChar ' + str(PRIMEIRO)
                + ' /LastChar ' + str(ULTIMO) + ' /Widths ['
                + ' '.join(str(w) for w in fonte['larguras'])
                + '] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>'),
        (b'5 0 obj\n<< /Length ' + str(len(conteudo)).encode()
         + b' >>\nstream\n' + conteudo + b'\nendstream\nendobj\n'),
        _obj(6, '<< /Type /FontDescriptor /FontName /' + fonte['nome_ps']
                + ' /Flags ' + str(fonte['flags'])
                + ' /FontBBox [' + ' '.join(str(v) for v in fonte['bbox'])
                + '] /ItalicAngle ' + str(fonte['italic_angle'])
                + ' /Ascent ' + str(fonte['ascent'])
                + ' /Descent ' + str(fonte['descent'])
                + ' /CapHeight ' + str(fonte['cap_height'])
                + ' /StemV 80 /FontFile2 7 0 R >>'),
        (b'7 0 obj\n<< /Filter /ASCIIHexDecode /Length '
         + str(len(programa)).encode() + b' /Length1 '
         + str(len(fonte['bytes'])).encode() + b' >>\nstream\n'
         + programa + b'\nendstream\nendobj\n'),
    ]

    saida = bytearray(b'%PDF-1.4\n')
    deslocamentos = []
    for o in objetos:
        deslocamentos.append(len(saida))
        saida += o

    inicio_xref = len(saida)
    saida += b'xref\n0 ' + str(len(objetos) + 1).encode() + b'\n'
    saida += b'0000000000 65535 f \n'
    for d in deslocamentos:
        saida += b'%010d 00000 n \n' % d
    saida += (b'trailer\n<< /Size ' + str(len(objetos) + 1).encode()
              + b' /Root 1 0 R >>\nstartxref\n'
              + str(inicio_xref).encode() + b'\n%%EOF\n')
    return bytes(saida)
