# -*- coding: utf-8 -*-
"""
Confere a tabela WinAnsi contra um decodificador independente: o MuPDF.

DOCUMENTO DE MANUTENÇÃO.

A tabela sai do codec cp1252 do Python. Isso a torna correta em relação à
Unicode Consortium, mas não prova que um **leitor de PDF** desenha o mesmo
glifo naquela posição — que é o que importa aqui, porque o destino do dado é um
stream declarado `/WinAnsiEncoding`.

Este validador fecha essa distância: monta um PDF mínimo, com Helvetica e
`/WinAnsiEncoding`, escreve cada byte definido da tabela, e pede ao MuPDF que
extraia o texto de volta. Se o caractere que volta for o que a tabela diz, a
tabela vale para o uso que ela tem.

Uso:  python dev/scripts/winansi_reference/validate.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import winansi_reference as ref


def pdf_com(bytes_winansi):
    """PDF mínimo de uma página, Helvetica/WinAnsi, com esses bytes escritos."""
    def escapa(bs):
        fora = bytearray()
        for b in bs:
            if b in (0x28, 0x29, 0x5C):        # ( ) \
                fora += b'\\'
            fora.append(b)
        return bytes(fora)

    # Uma linha por bloco de 40 bytes. Numa linha só, os 218 caracteres
    # passam de 1300 pontos e saem da página — e o MuPDF extrai o que está
    # DENTRO do papel, então o resto sumia sem erro nenhum. Descoberto medindo:
    # a extração parava no byte 0x85, que é onde a linha cruzava os 595 pt.
    linhas = [bytes_winansi[i:i + 40]
              for i in range(0, len(bytes_winansi), 40)]
    partes = [b'BT /F1 11 Tf 20 ' + str(800 - 20 * i).encode()
              + b' Td (' + escapa(l) + b') Tj ET'
              for i, l in enumerate(linhas)]
    conteudo = b'\n'.join(partes)
    objs = [
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        b'/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        b'/Encoding /WinAnsiEncoding >>',
        b'<< /Length ' + str(len(conteudo)).encode() + b' >>\nstream\n'
        + conteudo + b'\nendstream',
    ]
    fora = bytearray(b'%PDF-1.4\n')
    posicoes = []
    for i, o in enumerate(objs, 1):
        posicoes.append(len(fora))
        fora += str(i).encode() + b' 0 obj\n' + o + b'\nendobj\n'
    xref = len(fora)
    fora += b'xref\n0 ' + str(len(objs) + 1).encode() + b'\n0000000000 65535 f \n'
    for pos in posicoes:
        fora += f'{pos:010d} 00000 n \n'.encode()
    fora += (b'trailer\n<< /Size ' + str(len(objs) + 1).encode()
             + b' /Root 1 0 R >>\nstartxref\n'
             + str(xref).encode() + b'\n%%EOF\n')
    return bytes(fora)


def main():
    import pymupdf

    tab = ref.tabela_cp1252()
    # so o que e desenhavel: controle nao produz glifo, e espaco nao volta
    # distinguivel na extracao
    posicoes = sorted((b, cp) for cp, b in tab.items()
                      if b >= 0x21 and not (0x7F <= b <= 0x9F and b not in
                                            (0x80, 0x82, 0x83, 0x84, 0x85,
                                             0x86, 0x87, 0x88, 0x89, 0x8A,
                                             0x8B, 0x8C, 0x8E, 0x91, 0x92,
                                             0x93, 0x94, 0x95, 0x96, 0x97,
                                             0x98, 0x99, 0x9A, 0x9B, 0x9C,
                                             0x9E, 0x9F)))
    doc = pymupdf.open(stream=pdf_com(bytes(b for b, _ in posicoes)),
                       filetype='pdf')
    lido = doc[0].get_text().replace('\n', '').strip()
    doc.close()

    # As duas posicoes em que o PDF se afasta do cp1252, de proposito e por
    # escrito: o Anexo D trata 0xA0 como espaco e 0xAD como hifen. Nao sao
    # divergencia da tabela — sao o comportamento previsto, e o MuPDF as
    # devolve assim. Foram as UNICAS duas em 217, o que e a confirmacao de que
    # o resto da tabela vale para desenhar num leitor de verdade.
    EQUIVALENTES = {0xA0: 0x20, 0xAD: 0x2D}
    esperado = ''.join(chr(EQUIVALENTES.get(b, cp)) for b, cp in posicoes)
    if lido == esperado:
        print(f'OK — o MuPDF devolve os {len(posicoes)} caracteres esperados '
              f'das posições WinAnsi ({len(ref.indefinidos())} indefinidas '
              f'ficam fora; 0xA0 e 0xAD voltam como espaço e hífen, que é o '
              f'que o Anexo D do PDF manda)')
        return 0

    print(f'DIVERGE — {len(posicoes)} posições escritas, {len(lido)} lidas')
    for i, (esp, got) in enumerate(zip(esperado, lido)):
        if esp != got:
            b = posicoes[i][0]
            print(f'  byte 0x{b:02X}: a tabela diz {esp!r} (U+{ord(esp):04X}), '
                  f'o MuPDF leu {got!r} (U+{ord(got):04X})')
    return 1


if __name__ == '__main__':
    sys.exit(main())
