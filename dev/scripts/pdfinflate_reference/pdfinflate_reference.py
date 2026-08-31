# -*- coding: utf-8 -*-
"""
Referência do INFLATE (RFC 1951), a ser portada para o PL_FPDF.

Por que escrita à mão
---------------------
O PL/SQL não tem zlib, e os dois experimentos em `tests/diag_utl_compress*.sql`
fecharam a porta do `UTL_COMPRESS`: ele só descomprime quando o CRC-32 e o
tamanho do rodapé gzip estão corretos, e o CRC é do conteúdo **descomprimido** —
conhecê-lo exigiria descomprimir. Circular.

Sem inflate, o copiador de objetos recusa (`ORA-20843`) qualquer PDF com **xref
em stream** ou **object streams**, que é o que todo produtor moderno gera. Isso
barra merge, extract, marca d'água e overlay sobre documento de terceiro.

O escopo é menor do que parece: o copiador **não** descomprime fluxo de
conteúdo — ele copia os streams byte a byte e acrescenta conteúdo novo. O
inflate é necessário só para as estruturas (xref em stream e object streams),
que têm alguns KB, não as centenas de um fluxo de conteúdo. É o que torna o
custo de CPU aceitável em PL/SQL.

Como está escrita
-----------------
Segue a forma do `puff` (a implementação de referência do próprio zlib): tabelas
de Huffman representadas por dois vetores — quantos códigos há de cada
comprimento, e os símbolos em ordem — e decodificação bit a bit. É a forma mais
fácil de portar para PL/SQL, porque não exige tabela de lookup grande nem
aritmética de ponteiro; e é lenta no lugar certo, já que os dados aqui são
pequenos.

A ordem dos bits do DEFLATE é do menos significativo para o mais significativo
dentro de cada byte — mas os códigos de Huffman são lidos do mais significativo
para o menos. Confundir os dois é o erro clássico, e produz saída plausível por
alguns bytes antes de degringolar.
"""

# ─────────────────────── tabelas fixas da especificação ──────────────────────
# comprimentos: código 257..285
COMP_BASE = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43,
             51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
COMP_EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
              4, 4, 4, 4, 5, 5, 5, 5, 0]
# distâncias: código 0..29
DIST_BASE = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257,
             385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289,
             16385, 24577]
DIST_EXTRA = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
              9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
# ordem em que os comprimentos do alfabeto de comprimentos aparecem
ORDEM_CL = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

MAX_BITS = 15


class ErroInflate(Exception):
    pass


class Huffman:
    """Árvore canônica como dois vetores, no formato do puff.

    `contagem[c]` = quantos códigos têm c bits; `simbolos` = os símbolos
    ordenados por (comprimento, valor). Decodificar é caminhar bit a bit
    somando contagens — sem tabela grande, que é o que interessa para o PL/SQL.
    """

    __slots__ = ('contagem', 'simbolos')

    def __init__(self, comprimentos):
        self.contagem = [0] * (MAX_BITS + 1)
        for c in comprimentos:
            self.contagem[c] += 1
        if self.contagem[0] == len(comprimentos):
            raise ErroInflate('nenhum código no alfabeto')

        # incompleto é permitido só no caso de um único código (distâncias)
        sobra = 1
        for c in range(1, MAX_BITS + 1):
            sobra <<= 1
            sobra -= self.contagem[c]
            if sobra < 0:
                raise ErroInflate(f'código de Huffman inválido em {c} bits')

        offs = [0, 0]
        for c in range(1, MAX_BITS):
            offs.append(offs[c] + self.contagem[c])
        self.simbolos = [0] * len(comprimentos)
        for sim, c in enumerate(comprimentos):
            if c:
                self.simbolos[offs[c]] = sim
                offs[c] += 1


class Fluxo:
    """Leitor de bits, do menos significativo para o mais significativo."""

    def __init__(self, dados):
        self.dados = dados
        self.pos = 0          # próximo byte
        self.acum = 0         # bits já lidos e não consumidos
        self.n = 0            # quantos bits há em acum

    def bits(self, quantos):
        while self.n < quantos:
            if self.pos >= len(self.dados):
                raise ErroInflate('dados terminaram no meio de um bloco')
            self.acum |= self.dados[self.pos] << self.n
            self.pos += 1
            self.n += 8
        valor = self.acum & ((1 << quantos) - 1)
        self.acum >>= quantos
        self.n -= quantos
        return valor

    def alinhar(self):
        """Descarta o resto do byte corrente (blocos armazenados)."""
        self.acum = 0
        self.n = 0

    def decodificar(self, huff):
        """Um símbolo. Os códigos vêm do bit MAIS significativo para o menos,
        ao contrário dos campos de tamanho fixo — daí o `código` crescer por
        deslocamento à esquerda enquanto os bits chegam um a um."""
        codigo = primeiro = indice = 0
        for c in range(1, MAX_BITS + 1):
            codigo |= self.bits(1)
            quantos = huff.contagem[c]
            if codigo - primeiro < quantos:
                return huff.simbolos[indice + (codigo - primeiro)]
            indice += quantos
            primeiro = (primeiro + quantos) << 1
            codigo <<= 1
        raise ErroInflate('código de Huffman não encontrado')


def _huff_fixos():
    lit = [8] * 144 + [9] * 112 + [7] * 24 + [8] * 8      # 0..287
    dist = [5] * 30
    return Huffman(lit), Huffman(dist)


HUFF_FIXO_LIT, HUFF_FIXO_DIST = _huff_fixos()


def _dinamicos(f):
    hlit = f.bits(5) + 257
    hdist = f.bits(5) + 1
    hclen = f.bits(4) + 4
    if hlit > 286 or hdist > 30:
        raise ErroInflate('contagem de códigos fora da especificação')

    cl = [0] * 19
    for i in range(hclen):
        cl[ORDEM_CL[i]] = f.bits(3)
    huff_cl = Huffman(cl)

    comps = []
    while len(comps) < hlit + hdist:
        sim = f.decodificar(huff_cl)
        if sim < 16:
            comps.append(sim)
        elif sim == 16:
            if not comps:
                raise ErroInflate('repetição sem comprimento anterior')
            comps += [comps[-1]] * (3 + f.bits(2))
        elif sim == 17:
            comps += [0] * (3 + f.bits(3))
        else:
            comps += [0] * (11 + f.bits(7))
    if len(comps) > hlit + hdist:
        raise ErroInflate('comprimentos passaram do alfabeto')

    return Huffman(comps[:hlit]), Huffman(comps[hlit:])


def inflate(dados, limite=None):
    """DEFLATE cru (RFC 1951) -> bytes. `dados` NÃO leva casca zlib nem gzip."""
    f = Fluxo(dados)
    saida = bytearray()
    while True:
        final = f.bits(1)
        tipo = f.bits(2)

        if tipo == 0:                                   # armazenado
            f.alinhar()
            if f.pos + 4 > len(f.dados):
                raise ErroInflate('bloco armazenado truncado')
            tam = f.dados[f.pos] | (f.dados[f.pos + 1] << 8)
            ntam = f.dados[f.pos + 2] | (f.dados[f.pos + 3] << 8)
            f.pos += 4
            if tam != (~ntam & 0xFFFF):
                raise ErroInflate('LEN e NLEN não são complementares')
            if f.pos + tam > len(f.dados):
                raise ErroInflate('bloco armazenado passa do fim')
            saida += f.dados[f.pos:f.pos + tam]
            f.pos += tam

        elif tipo in (1, 2):
            if tipo == 1:
                hlit, hdist = HUFF_FIXO_LIT, HUFF_FIXO_DIST
            else:
                hlit, hdist = _dinamicos(f)

            while True:
                sim = f.decodificar(hlit)
                if sim < 256:
                    saida.append(sim)
                elif sim == 256:
                    break
                else:
                    i = sim - 257
                    if i >= len(COMP_BASE):
                        raise ErroInflate(f'código de comprimento {sim} inválido')
                    comp = COMP_BASE[i] + f.bits(COMP_EXTRA[i])
                    d = f.decodificar(hdist)
                    if d >= len(DIST_BASE):
                        raise ErroInflate(f'código de distância {d} inválido')
                    dist = DIST_BASE[d] + f.bits(DIST_EXTRA[d])
                    if dist > len(saida):
                        raise ErroInflate('distância aponta antes do início')
                    # a cópia PODE se sobrepor: com distância 1 e comprimento
                    # 100, o mesmo byte se repete cem vezes. Copiar byte a byte
                    # é obrigatório; uma fatia de uma vez daria resultado errado.
                    ini = len(saida) - dist
                    for k in range(comp):
                        saida.append(saida[ini + k])
                if limite is not None and len(saida) > limite:
                    raise ErroInflate('saída passou do limite pedido')
        else:
            raise ErroInflate('tipo de bloco 3 é reservado')

        if final:
            break
    return bytes(saida)


def inflate_zlib(dados):
    """Tira a casca zlib (RFC 1950) — que é o que o /FlateDecode do PDF traz."""
    if len(dados) < 6:
        raise ErroInflate('stream zlib curto demais')
    cmf, flg = dados[0], dados[1]
    if (cmf & 0x0F) != 8:
        raise ErroInflate(f'método de compressão {cmf & 0x0F} não é deflate')
    if ((cmf << 8) | flg) % 31 != 0:
        raise ErroInflate('cabeçalho zlib com verificação inválida')
    if flg & 0x20:
        raise ErroInflate('zlib com dicionario predefinido nao suportado')
    return inflate(dados[2:-4])
