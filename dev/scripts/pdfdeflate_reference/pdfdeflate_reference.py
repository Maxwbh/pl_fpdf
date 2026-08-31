# -*- coding: utf-8 -*-
"""DEFLATE (RFC 1951) e zlib (RFC 1950) na direção de COMPRIMIR.

DOCUMENTO DE MANUTENÇÃO. Não é documentação da biblioteca.

Por que existe
--------------
O `FlateDecode` do package já descomprime — o INFLATE foi escrito em PL/SQL
porque o `UTL_COMPRESS` não serve (ele só aceita rodapé gzip com CRC-32 do dado
**descomprimido**, que só se conhece descomprimindo). Faltava o outro lado: sem
um deflate, `SetCompression(TRUE)` era um no-op e todo PDF saía sem compressão.

Escrever no formato é mais fácil que ler: o leitor precisa aceitar tudo o que a
especificação permite, o escritor só precisa emitir **um** subconjunto válido.
Esta referência emite o subconjunto:

* **um bloco só**, `BFINAL=1`, `BTYPE=01` — árvore de Huffman **fixa**. Não há
  árvore para transmitir, que é a metade complicada do formato;
* **LZ77 guloso** com janela de 32 KB, casamento mínimo de 3 bytes e busca por
  tabela de dispersão com corrente limitada.

Comprime menos que o zlib (que usa Huffman dinâmico e casamento preguiçoso) e
**muito** mais que nada. O que sai é um fluxo zlib legítimo: qualquer leitor de
PDF descomprime.

A regra do jogo
---------------
Este módulo é o que o PL/SQL porta, decisão por decisão — mesma dispersão,
mesmo limite de corrente, mesmo critério de desempate. Isso não é capricho: é o
que permite ao runner comparar **byte a byte** o que o banco produziu com o que
a referência produz para a mesma entrada. Um deflate "equivalente mas
diferente" só poderia ser conferido descomprimindo, e aí um erro de escrita que
o próprio inflate da casa tolera passaria despercebido.
"""

JANELA = 32768          # janela do LZ77 (RFC 1951: 32 KB)
CASAMENTO_MIN = 3
CASAMENTO_MAX = 258
HASH_BITS = 15
HASH_MASC = (1 << HASH_BITS) - 1
CORRENTE_MAX = 16       # candidatos examinados por posição
# Acima disto o PL/SQL vai de bloco armazenado: o LZ77 precisa de uma entrada
# posição->anterior por byte, e uma tabela indexada com milhões de entradas
# estoura a PGA. A referência respeita o mesmo teto — senão os dois deixariam
# de produzir os mesmos bytes justamente no caso grande.
MAX_COMPRIMIR = 262144

# ── tabelas de comprimento e distância (RFC 1951, seção 3.2.5) ───────────────
# (código, bits extras, base)
COMPRIMENTOS = [
    (257, 0, 3), (258, 0, 4), (259, 0, 5), (260, 0, 6), (261, 0, 7),
    (262, 0, 8), (263, 0, 9), (264, 0, 10), (265, 1, 11), (266, 1, 13),
    (267, 1, 15), (268, 1, 17), (269, 2, 19), (270, 2, 23), (271, 2, 27),
    (272, 2, 31), (273, 3, 35), (274, 3, 43), (275, 3, 51), (276, 3, 59),
    (277, 4, 67), (278, 4, 83), (279, 4, 99), (280, 4, 115), (281, 5, 131),
    (282, 5, 163), (283, 5, 195), (284, 5, 227), (285, 0, 258),
]
DISTANCIAS = [
    (0, 0, 1), (1, 0, 2), (2, 0, 3), (3, 0, 4), (4, 1, 5), (5, 1, 7),
    (6, 2, 9), (7, 2, 13), (8, 3, 17), (9, 3, 25), (10, 4, 33), (11, 4, 49),
    (12, 5, 65), (13, 5, 97), (14, 6, 129), (15, 6, 193), (16, 7, 257),
    (17, 7, 385), (18, 8, 513), (19, 8, 769), (20, 9, 1025), (21, 9, 1537),
    (22, 10, 2049), (23, 10, 3073), (24, 11, 4097), (25, 11, 6145),
    (26, 12, 8193), (27, 12, 12289), (28, 13, 16385), (29, 13, 24577),
]


def codigo_fixo(simbolo):
    """(código, quantidade de bits) do símbolo na árvore fixa de literais.

    RFC 1951, 3.2.6. São quatro faixas, e trocá-las produz um fluxo que o
    inflate aceita por alguns bytes e depois vira lixo.
    """
    if simbolo <= 143:
        return 0x30 + simbolo, 8
    if simbolo <= 255:
        return 0x190 + simbolo - 144, 9
    if simbolo <= 279:
        return simbolo - 256, 7
    return 0xC0 + simbolo - 280, 8


class Escritor:
    """Acumulador de bits do DEFLATE.

    O sentido dos bits é a armadilha clássica: dentro de cada byte o DEFLATE
    grava do bit MENOS significativo para o mais, mas os códigos de Huffman são
    formados do MAIS significativo para o menos. Por isso há dois métodos.
    """

    def __init__(self):
        self.bytes = bytearray()
        self.acum = 0
        self.nbits = 0

    def bits(self, valor, quantos):
        """Grava `quantos` bits de `valor`, do menos significativo para o mais."""
        self.acum |= (valor & ((1 << quantos) - 1)) << self.nbits
        self.nbits += quantos
        while self.nbits >= 8:
            self.bytes.append(self.acum & 0xFF)
            self.acum >>= 8
            self.nbits -= 8

    def codigo(self, valor, quantos):
        """Grava um código de Huffman: bit mais significativo primeiro."""
        for i in range(quantos - 1, -1, -1):
            self.bits((valor >> i) & 1, 1)

    def alinhar(self):
        if self.nbits:
            self.bytes.append(self.acum & 0xFF)
            self.acum = 0
            self.nbits = 0
        return bytes(self.bytes)


def _hash(dados, i):
    return (((dados[i] << 10) ^ (dados[i + 1] << 5) ^ dados[i + 2])
            & HASH_MASC)


def _tabela(codigos, valor):
    """A entrada (código, bits extras, base) que cobre `valor`."""
    escolhida = codigos[0]
    for entrada in codigos:
        if entrada[2] <= valor:
            escolhida = entrada
        else:
            break
    return escolhida


def deflate_armazenado(dados):
    """DEFLATE cru em blocos ARMAZENADOS (BTYPE=00), sem comprimir nada.

    Custa 5 bytes por bloco de até 65535, e é o que impede o resultado de
    ficar MAIOR que a entrada. Dado incompressível — imagem já comprimida,
    stream cifrado — cresce ~5% com Huffman fixa, e num PDF isso é regressão:
    o arquivo aumenta e ainda ganha um filtro para o leitor desfazer.
    """
    fora = bytearray()
    n = len(dados)
    i = 0
    while True:
        pedaco = dados[i:i + 65535]
        final = 1 if i + len(pedaco) >= n else 0
        fora.append(final)                       # BFINAL, BTYPE=00, alinhado
        tam = len(pedaco)
        fora += bytes([tam & 255, (tam >> 8) & 255,
                       (~tam) & 255, ((~tam) >> 8) & 255])
        fora += pedaco
        i += 65535
        if final:
            return bytes(fora)


def deflate_comprimido(dados):
    """DEFLATE cru: um bloco final com Huffman fixa e LZ77 guloso."""
    e = Escritor()
    e.bits(1, 1)          # BFINAL
    e.bits(1, 2)          # BTYPE = 01, Huffman fixa

    n = len(dados)
    cabeca = {}                     # hash -> última posição vista
    anterior = [-1] * max(n, 1)     # posição -> posição anterior com o mesmo hash
    i = 0
    while i < n:
        melhor_tam, melhor_dist = 0, 0
        if i + CASAMENTO_MIN <= n:
            h = _hash(dados, i)
            candidato = cabeca.get(h, -1)
            visitados = 0
            while (candidato >= 0 and visitados < CORRENTE_MAX
                   and i - candidato <= JANELA):
                visitados += 1
                # compara enquanto casar, com teto no fim dos dados
                tam = 0
                limite = min(CASAMENTO_MAX, n - i)
                while (tam < limite
                       and dados[candidato + tam] == dados[i + tam]):
                    tam += 1
                # desempate pelo primeiro encontrado: é o mais PRÓXIMO, e
                # distância menor custa menos bits
                if tam > melhor_tam:
                    melhor_tam, melhor_dist = tam, i - candidato
                    if tam >= CASAMENTO_MAX:
                        break
                candidato = anterior[candidato]

            # registra esta posição na corrente (sempre, casando ou não)
            anterior[i] = cabeca.get(h, -1)
            cabeca[h] = i

        if melhor_tam >= CASAMENTO_MIN:
            cod, extras, base = _tabela(COMPRIMENTOS, melhor_tam)
            c, bits = codigo_fixo(cod)
            e.codigo(c, bits)
            if extras:
                e.bits(melhor_tam - base, extras)
            cod, extras, base = _tabela(DISTANCIAS, melhor_dist)
            e.codigo(cod, 5)         # distâncias usam 5 bits fixos
            if extras:
                e.bits(melhor_dist - base, extras)

            # as posições cobertas pelo casamento também entram na corrente,
            # senão casamentos futuros perdem candidatos
            for k in range(i + 1, min(i + melhor_tam, n - CASAMENTO_MIN + 1)):
                h = _hash(dados, k)
                anterior[k] = cabeca.get(h, -1)
                cabeca[h] = k
            i += melhor_tam
        else:
            c, bits = codigo_fixo(dados[i])
            e.codigo(c, bits)
            i += 1

    c, bits = codigo_fixo(256)       # fim do bloco
    e.codigo(c, bits)
    return e.alinhar()


def deflate_bruto(dados):
    """O menor entre comprimir e armazenar — os dois são DEFLATE válidos.

    A escolha é determinística e olha só o tamanho, para que o PL/SQL a
    reproduza exatamente.
    """
    armazenado = deflate_armazenado(dados)
    if not dados or len(dados) > MAX_COMPRIMIR:
        return armazenado
    comprimido = deflate_comprimido(dados)
    return comprimido if len(comprimido) <= len(armazenado) else armazenado


def adler32(dados):
    a, b = 1, 0
    for x in dados:
        a = (a + x) % 65521
        b = (b + a) % 65521
    return (b << 16) | a


def zlib_stream(dados):
    """Fluxo zlib (RFC 1950) completo: cabeçalho, DEFLATE e Adler-32.

    0x78 0x9C é o par canônico: CMF = 0x78 (deflate, janela de 32 KB) e FLG
    escolhido para que (CMF*256 + FLG) seja múltiplo de 31, sem dicionário.
    """
    soma = adler32(dados)
    return (bytes([0x78, 0x9C]) + deflate_bruto(dados)
            + bytes([(soma >> 24) & 255, (soma >> 16) & 255,
                     (soma >> 8) & 255, soma & 255]))
