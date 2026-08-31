# -*- coding: utf-8 -*-
"""
Referência da conversão de uma imagem (JPEG ou PNG) em /XObject do PDF, a ser
portada para o overlay de imagem do PL_FPDF.

O que falta no package hoje
--------------------------
`OverlayImage` guarda o BLOB em memória, e `OutputModifiedPDF` recusa gerar
(`ORA-20845`) em vez de escrever uma página que referencia um objeto
inexistente. A metade difícil do desenho — fluxo de conteúdo, `/Contents`,
`/Resources` próprio — já está pronta e provada; falta transformar os bytes da
imagem num objeto de imagem do PDF.

O `p_parseImage` que já existe no package não serve como está: ele lê de
ARQUIVO (`getImageFromUrl`) e trata só PNG. Aqui a entrada é o BLOB que o
chamador passou.

O ponto que faz isso ser barato
-------------------------------
Nenhum dos dois formatos precisa ser descomprimido em PL/SQL:

  * **JPEG** entra inteiro, com `/Filter /DCTDecode` — o leitor de PDF decodifica.
  * **PNG** guarda os dados em blocos IDAT já em zlib, que é exatamente o
    `/Filter /FlateDecode` do PDF. Basta concatenar os IDAT e declarar o
    `/DecodeParms` com `/Predictor 15`, porque o PNG filtra cada linha e o PDF
    sabe desfazer isso.

O que NÃO passa direto, e por isso é recusado com mensagem clara: PNG com canal
alfa (color type 4 e 6), PNG entrelaçado (Adam7) e profundidade de 16 bits.
Todos exigiriam descompactar e reprocessar os pixels.
"""
import re
import struct
import zlib

# ────────────────────────────────── JPEG ─────────────────────────────────────
# Marcadores SOF que carregam as dimensões. SOF0/1/2 e 9..15 são variantes que
# o DCTDecode aceita; os que ficam de fora (C4 DHT, C8 JPG, CC DAC) não são
# quadros e não podem ser lidos como tal — foi por confundir isso que uma
# primeira versão leu lixo como largura.
SOF = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
       0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}


def parse_jpeg(dados):
    """(largura, altura, colorspace, bits) de um JPEG."""
    if dados[:3] != b'\xff\xd8\xff':
        raise ValueError('não é JPEG')
    i = 2
    n = len(dados)
    while i < n - 1:
        if dados[i] != 0xFF:
            i += 1
            continue
        marca = dados[i + 1]
        if marca in (0xD8, 0x01) or 0xD0 <= marca <= 0xD7:
            i += 2
            continue
        if marca == 0xD9 or marca == 0xDA:        # fim, ou início do scan
            break
        tam = struct.unpack('>H', dados[i + 2:i + 4])[0]
        if marca in SOF:
            bits = dados[i + 4]
            alt, larg = struct.unpack('>HH', dados[i + 5:i + 9])
            comp = dados[i + 9]
            cs = {1: '/DeviceGray', 3: '/DeviceRGB', 4: '/DeviceCMYK'}.get(comp)
            if cs is None:
                raise ValueError(f'JPEG com {comp} componentes não suportado')
            return larg, alt, cs, bits
        i += 2 + tam
    raise ValueError('JPEG sem marcador SOF: dimensões não encontradas')


def xobject_jpeg(dados):
    """(dicionário, payload) do /XObject de um JPEG."""
    larg, alt, cs, bits = parse_jpeg(dados)
    dic = (f'<< /Type /XObject /Subtype /Image /Width {larg} /Height {alt}'
           f' /ColorSpace {cs} /BitsPerComponent {bits} /Filter /DCTDecode')
    if cs == '/DeviceCMYK':
        # JPEG CMYK gravado por Adobe vem invertido; sem o /Decode as cores
        # saem em negativo
        dic += ' /Decode [1 0 1 0 1 0 1 0]'
    return dic + f' /Length {len(dados)} >>', dados


# ─────────────────────────────────── PNG ─────────────────────────────────────
ASSINATURA_PNG = b'\x89PNG\r\n\x1a\n'


def blocos_png(dados):
    """Percorre os chunks: (tipo, conteúdo)."""
    i = len(ASSINATURA_PNG)
    while i + 8 <= len(dados):
        tam = struct.unpack('>I', dados[i:i + 4])[0]
        tipo = dados[i + 4:i + 8]
        yield tipo, dados[i + 8:i + 8 + tam]
        i += 12 + tam                       # 4 tam + 4 tipo + dados + 4 crc
        if tipo == b'IEND':
            break


# ─────────────────── PNG que precisa de reprocessamento de pixels ────────────
#
# Três casos não passam direto para o PDF, e até agosto/2026 eram recusados com
# ORA-20823 por falta de um inflate em PL/SQL:
#
#   canal alfa (color type 4 e 6)  o PDF NÃO tem alfa entrelaçado no pixel; a
#                                  transparência é um segundo objeto de imagem,
#                                  apontado por /SMask
#   entrelaçado (Adam7)            os pixels vêm em sete passagens, cada uma
#                                  com a sua própria filtragem por linha
#   16 bits                        este passa direto: o PDF aceita
#                                  /BitsPerComponent 16, e o predictor também
#
# O inflate existe desde a xref em stream, e o desfazer do filtro por linha é o
# mesmo código do /Predictor do PDF. O que NÃO existe é um deflate — então o
# que sai daqui vai **sem compressão**. É maior no arquivo e é honesto; a
# alternativa seria escrever um deflate para não perder bytes, o que é outro
# trabalho inteiro.

PASSOS_ADAM7 = (
    # (x inicial, y inicial, passo x, passo y)
    (0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
    (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2),
)


def desfiltrar(dados, larg, alt, canais, bits):
    """Desfaz o filtro por linha do PNG. Devolve o raster cru.

    É o mesmo algoritmo do `/Predictor` do PDF — no package, `pdf_undo_pred`.
    Cada linha começa com um byte que diz qual dos cinco filtros ela usou; o
    número no cabeçalho não manda, quem manda é esse byte.
    """
    bpp = max(1, (canais * bits + 7) // 8)
    linha = (larg * canais * bits + 7) // 8
    esperado = (linha + 1) * alt
    if len(dados) < esperado:
        raise ValueError(f'PNG truncado: {len(dados)} bytes, '
                         f'esperado {esperado}')

    ant = bytearray(linha)
    out = bytearray()
    p = 0
    for _ in range(alt):
        filtro = dados[p]
        cur = bytearray(dados[p + 1:p + 1 + linha])
        p += 1 + linha
        for i in range(linha):
            a = cur[i - bpp] if i >= bpp else 0
            b = ant[i]
            c = ant[i - bpp] if i >= bpp else 0
            if filtro == 0:
                pred = 0
            elif filtro == 1:
                pred = a
            elif filtro == 2:
                pred = b
            elif filtro == 3:
                pred = (a + b) >> 1
            elif filtro == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
            else:
                raise ValueError(f'filtro PNG {filtro} inválido')
            cur[i] = (cur[i] + pred) & 0xFF
        out += cur
        ant = cur
    return bytes(out)


def desentrelacar(dados, larg, alt, canais, bits):
    """Adam7 → raster contínuo.

    As sete passagens são imagens independentes, cada uma com a sua largura, a
    sua altura e a sua filtragem por linha — desfiltrar o bloco inteiro de uma
    vez, como se fosse uma imagem só, produz ruído. Só depois de montado o
    raster é que os pixels ficam onde deveriam.

    Só o caso de 8 bits ou mais é tratado; sub-byte (1, 2, 4 bits) entrelaçado
    exigiria empacotar bit a bit e é recusado, em vez de sair errado.
    """
    if bits < 8:
        raise ValueError('PNG entrelaçado com menos de 8 bits por componente '
                         'não suportado')
    passo_px = canais * bits // 8
    raster = bytearray(larg * alt * passo_px)
    pos = 0
    for x0, y0, dx, dy in PASSOS_ADAM7:
        pl = (larg - x0 + dx - 1) // dx
        pa = (alt - y0 + dy - 1) // dy
        if pl == 0 or pa == 0:
            continue
        linha = (pl * canais * bits + 7) // 8
        tam = (linha + 1) * pa
        bloco = desfiltrar(dados[pos:pos + tam], pl, pa, canais, bits)
        pos += tam
        for j in range(pa):
            for i in range(pl):
                orig = (j * pl + i) * passo_px
                dest = ((y0 + j * dy) * larg + (x0 + i * dx)) * passo_px
                raster[dest:dest + passo_px] = bloco[orig:orig + passo_px]
    return bytes(raster)


def separar_alfa(raster, larg, alt, canais_cor, bits):
    """(cor, alfa) a partir de um raster com alfa entrelaçado no pixel.

    O PDF quer os dois separados: a cor no próprio objeto de imagem e o alfa
    num segundo objeto, em /DeviceGray, apontado por /SMask.
    """
    b = bits // 8                       # bytes por componente (1 ou 2)
    passo = (canais_cor + 1) * b
    cor = bytearray()
    alfa = bytearray()
    for p in range(0, larg * alt * passo, passo):
        cor += raster[p:p + canais_cor * b]
        alfa += raster[p + canais_cor * b:p + passo]
    return bytes(cor), bytes(alfa)


def xobject_png(dados):
    """(dicionário, payload, extras) do /XObject de um PNG.

    Dois caminhos, e a escolha entre eles é o que decide o tamanho do arquivo:

    **Passagem direta** — sem alfa e sem entrelaçamento. Os IDAT já são zlib,
    que é o `/FlateDecode` do PDF; basta concatená-los e declarar
    `/Predictor 15`. Nada é descomprimido. Vale para 1, 2, 4, 8 **e 16** bits:
    o PDF aceita `/BitsPerComponent 16`, e o predictor também.

    **Reprocessamento** — com alfa (color type 4 ou 6) ou entrelaçado. Aí não
    tem jeito: inflar, desfazer o filtro por linha, e — no entrelaçado —
    remontar as sete passagens. O resultado sai **sem compressão**, porque não
    há um deflate deste lado. Com alfa, `extras['smask']` traz o segundo objeto
    de imagem, que o PDF exige para a transparência.
    """
    if dados[:8] != ASSINATURA_PNG:
        raise ValueError('não é PNG')

    larg = alt = bits = ct = None
    entrelace = 0
    idat = bytearray()
    paleta = None
    trns = None
    for tipo, conteudo in blocos_png(dados):
        if tipo == b'IHDR':
            larg, alt, bits, ct, comp, filtro, entrelace = struct.unpack(
                '>IIBBBBB', conteudo[:13])
            if ct not in (0, 2, 3, 4, 6):
                raise ValueError(f'PNG com color type {ct} não suportado')
            if comp != 0 or filtro != 0:
                raise ValueError('PNG com compressão ou filtro desconhecido')
        elif tipo == b'PLTE':
            paleta = conteudo
        elif tipo == b'tRNS':
            trns = conteudo
        elif tipo == b'IDAT':
            idat += conteudo
        elif tipo == b'IEND':
            break

    if larg is None:
        raise ValueError('PNG sem IHDR')
    if ct == 3 and paleta is None:
        raise ValueError('PNG indexado sem paleta')

    com_alfa = ct in (4, 6)
    cores_cor = 3 if ct in (2, 6) else 1
    canais = cores_cor + (1 if com_alfa else 0)
    if ct == 3:
        cs = (f'[/Indexed /DeviceRGB {len(paleta) // 3 - 1} '
              f'<{paleta.hex().upper()}>]')
    else:
        cs = '/DeviceRGB' if cores_cor == 3 else '/DeviceGray'

    def dicionario(w, h, espaco, bpc, tam, filtro_extra=''):
        return (f'<< /Type /XObject /Subtype /Image /Width {w} /Height {h}'
                f' /ColorSpace {espaco} /BitsPerComponent {bpc}'
                f'{filtro_extra} /Length {tam} >>')

    # ── passagem direta ──────────────────────────────────────────────────────
    if not com_alfa and entrelace == 0:
        flate = (f' /Filter /FlateDecode'
                 # o PNG filtra cada linha antes de comprimir; o Predictor 15
                 # diz ao leitor para desfazer isso — sem ele sai ruído
                 f' /DecodeParms << /Predictor 15 /Colors {cores_cor}'
                 f' /BitsPerComponent {bits} /Columns {larg} >>')
        return (dicionario(larg, alt, cs, bits, len(idat), flate),
                bytes(idat), {'trns': trns})

    # ── reprocessamento ──────────────────────────────────────────────────────
    if ct == 3:
        raise ValueError('PNG indexado e entrelaçado não suportado')
    cru = zlib.decompress(bytes(idat))
    if entrelace:
        raster = desentrelacar(cru, larg, alt, canais, bits)
    else:
        raster = desfiltrar(cru, larg, alt, canais, bits)

    extras = {'trns': trns}
    if com_alfa:
        if bits < 8:
            raise ValueError('PNG com alfa e menos de 8 bits por componente '
                             'não suportado')
        cor, alfa = separar_alfa(raster, larg, alt, cores_cor, bits)
        extras['smask'] = (dicionario(larg, alt, '/DeviceGray', bits,
                                      len(alfa)), alfa)
        raster = cor

    return dicionario(larg, alt, cs, bits, len(raster)), raster, extras


def xobject(dados):
    """Despacha pelo formato. (dicionário, payload)."""
    if dados[:3] == b'\xff\xd8\xff':
        return xobject_jpeg(dados)
    if dados[:8] == ASSINATURA_PNG:
        dic, payload, _ = xobject_png(dados)
        return dic, payload
    raise ValueError('formato de imagem não reconhecido (use JPEG ou PNG)')


def dimensoes(dados):
    """(largura, altura) em pixels, para quem precisa manter a proporção."""
    if dados[:3] == b'\xff\xd8\xff':
        larg, alt, _, _ = parse_jpeg(dados)
        return larg, alt
    if dados[:8] == ASSINATURA_PNG:
        for tipo, conteudo in blocos_png(dados):
            if tipo == b'IHDR':
                return struct.unpack('>II', conteudo[:8])
    raise ValueError('formato de imagem não reconhecido')
