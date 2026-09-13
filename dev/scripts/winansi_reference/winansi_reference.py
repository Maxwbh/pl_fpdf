# -*- coding: utf-8 -*-
"""
A tabela WinAnsi (cp1252) — de fonte primária, não digitada à mão.

DOCUMENTO DE MANUTENÇÃO.

O dicionário da fonte no PDF declara `/Encoding /WinAnsiEncoding`, que é o
cp1252 da Microsoft com pequenas diferenças documentadas na especificação do
PDF. O texto sai do banco em AL32UTF8 e precisa ser traduzido antes de entrar
no stream de conteúdo, senão cada acentuado vira dois glifos.

A fonte primária aqui é o codec `cp1252` do próprio Python, que implementa a
tabela publicada pela Unicode Consortium. Nada é digitado: a tabela é obtida
decodificando os 256 bytes, um a um.

As cinco posições que o PDF define e o cp1252 não
------------------------------------------------
A especificação do PDF (Anexo D, WinAnsiEncoding) atribui glifo a cinco
posições que o cp1252 deixa indefinidas. Estão listadas explicitamente porque
a diferença é real e um leitor as desenha:

    0x81, 0x8D, 0x8F, 0x90, 0x9D  — indefinidos no cp1252

São cinco, medidos e não supostos: `indefinidos()` os devolve. Restam **251**
posições utilizáveis, não 224 como estimei quando abri o relato.

O que o PDF acrescenta é tratar 0xA0 como espaço e 0xAD como hífen, o que não
muda o mapeamento de entrada — só o desenho.
"""


def tabela_cp1252():
    """{ponto de código Unicode: byte cp1252} para as posições definidas."""
    fora = {}
    for b in range(256):
        try:
            ch = bytes([b]).decode('cp1252')
        except UnicodeDecodeError:
            continue          # posição indefinida no cp1252
        fora[ord(ch)] = b
    return fora


def indefinidos():
    """Os bytes que o cp1252 não define — para documentar, não para usar."""
    fora = []
    for b in range(256):
        try:
            bytes([b]).decode('cp1252')
        except UnicodeDecodeError:
            fora.append(b)
    return fora


def para_winansi(texto):
    """Converte texto Unicode para bytes WinAnsi.

    Levanta ValueError na primeira posição que não existe na tabela, com o
    índice e o caractere — em vez de trocar por '?' em silêncio, que é o que
    faz um documento sair errado sem ninguém perceber.
    """
    tab = tabela_cp1252()
    fora = bytearray()
    for i, ch in enumerate(texto, 1):
        b = tab.get(ord(ch))
        if b is None:
            raise ValueError(
                f'posição {i}: {ch!r} (U+{ord(ch):04X}) não existe em '
                f'WinAnsi')
        fora.append(b)
    return bytes(fora)
