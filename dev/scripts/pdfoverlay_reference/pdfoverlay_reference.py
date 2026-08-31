# -*- coding: utf-8 -*-
"""
Referência da rasterização de marcas d'água e overlays, a ser portada para
PL_FPDF.OutputModifiedPDF.

O que falta no package hoje
--------------------------
`AddWatermark`, `OverlayText` e `OverlayImage` registram o pedido em memória e
`generate_*_stream` até monta um texto de operadores — mas nada disso chega ao
arquivo: `OutputModifiedPDF` recusa com `ORA-20845` quando há marca d'água ou
overlay, justamente para não descartá-los em silêncio.

Três coisas precisam acontecer para o desenho aparecer, e é isso que esta
referência resolve:

  1. **os operadores certos.** O que está no package hoje não é PDF válido:
     `TO_CHAR(rotacao) || ' rotate'` não existe como operador (rotação é uma
     matriz em `Tm`/`cm`), e a cor é fixa em cinza.

  2. **o fluxo de conteúdo.** O desenho tem de virar um objeto de stream novo,
     acrescentado ao `/Contents` da página. `/Contents` pode ser uma referência
     única ou um array, e os dois casos precisam virar array.

  3. **os recursos.** A fonte da marca d'água, o `/ExtGState` da opacidade e o
     `/XObject` da imagem têm de estar no `/Resources` da página. E aí mora a
     parte chata: no PDF do próprio PL_FPDF o `/Resources` é uma referência
     indireta COMPARTILHADA por todas as páginas (`/Resources 2 0 R`), então
     mexer nele afetaria todas. A saída é dar à página um `/Resources` próprio,
     cópia do original com as chaves novas mescladas.

A referência aplica tudo como atualização incremental (objetos novos no fim do
arquivo + xref com `/Prev`), porque o que precisa ser validado aqui é a lógica
de operadores, `/Contents` e `/Resources` — a remontagem completa do arquivo já
é código provado do lado PL/SQL (`pdf_assemble`).
"""
import re

# Larguras do Helvetica em milésimos de em, para os caracteres imprimíveis do
# WinAnsi. Sem isto não dá para centralizar a marca d'água: o deslocamento é
# -largura/2, e chutar 0.5*corpo por caractere erra feio em texto maiúsculo.
_HELV = {
    ' ': 278, '!': 278, '"': 355, '#': 556, '$': 556, '%': 889, '&': 667,
    "'": 191, '(': 333, ')': 333, '*': 389, '+': 584, ',': 278, '-': 333,
    '.': 278, '/': 278, '0': 556, '1': 556, '2': 556, '3': 556, '4': 556,
    '5': 556, '6': 556, '7': 556, '8': 556, '9': 556, ':': 278, ';': 278,
    '<': 584, '=': 584, '>': 584, '?': 556, '@': 1015, 'A': 667, 'B': 667,
    'C': 722, 'D': 722, 'E': 667, 'F': 611, 'G': 778, 'H': 722, 'I': 278,
    'J': 500, 'K': 667, 'L': 556, 'M': 833, 'N': 722, 'O': 778, 'P': 667,
    'Q': 778, 'R': 722, 'S': 667, 'T': 611, 'U': 722, 'V': 667, 'W': 944,
    'X': 667, 'Y': 667, 'Z': 611, '[': 278, '\\': 278, ']': 278, '^': 469,
    '_': 556, '`': 333, 'a': 556, 'b': 556, 'c': 500, 'd': 556, 'e': 556,
    'f': 278, 'g': 556, 'h': 556, 'i': 222, 'j': 222, 'k': 500, 'l': 222,
    'm': 833, 'n': 556, 'o': 556, 'p': 556, 'q': 556, 'r': 333, 's': 500,
    't': 278, 'u': 556, 'v': 500, 'w': 722, 'x': 500, 'y': 500, 'z': 500,
    '{': 334, '|': 260, '}': 334, '~': 584,
}


def largura_texto(texto, corpo):
    """Largura do texto em pontos, no Helvetica."""
    return sum(_HELV.get(c, 556) for c in texto) * corpo / 1000.0


def escapar(texto):
    """Escapa uma string literal do PDF."""
    return texto.replace('\\', r'\\').replace('(', r'\(').replace(')', r'\)')


def _matriz(rotacao, x, y):
    """Matriz de rotação em torno de (x, y), no formato do PDF."""
    import math
    r = math.radians(rotacao)
    cos, sin = round(math.cos(r), 6), round(math.sin(r), 6)
    return f'{cos} {sin} {-sin} {cos} {_num(x)} {_num(y)}'


def _num(v):
    """Número sem notação científica e sem zeros à toa."""
    return f'{v:.4f}'.rstrip('0').rstrip('.') or '0'


# ─────────────────────────── operadores de desenho ───────────────────────────
def ops_marca_dagua(texto, largura_pag, altura_pag, opacidade=0.3, rotacao=45,
                    corpo=48, cor=(0.5, 0.5, 0.5), fonte='FwmPLFPDF',
                    gs='GSwmPLFPDF'):
    """Marca d'água centralizada na página, rotacionada em torno do centro."""
    cx, cy = largura_pag / 2.0, altura_pag / 2.0
    # o Tm posiciona a ORIGEM do texto; para o texto ficar centrado é preciso
    # recuar metade da largura e metade da altura do corpo, já no sistema
    # girado — daí o deslocamento entrar como translação depois da rotação
    import math
    r = math.radians(rotacao)
    dx, dy = -largura_texto(texto, corpo) / 2.0, -corpo * 0.35
    tx = cx + dx * math.cos(r) - dy * math.sin(r)
    ty = cy + dx * math.sin(r) + dy * math.cos(r)
    return (f'q /{gs} gs {_num(cor[0])} {_num(cor[1])} {_num(cor[2])} rg\n'
            f'BT /{fonte} {_num(corpo)} Tf\n'
            f'{_matriz(rotacao, tx, ty)} Tm\n'
            f'({escapar(texto)}) Tj\nET Q\n')


def ops_texto(x, y, texto, corpo=12, cor=(0, 0, 0), opacidade=1.0, rotacao=0,
              fonte='FwmPLFPDF', gs='GSwmPLFPDF'):
    """Texto solto numa posição da página."""
    abre = f'q /{gs} gs ' if opacidade < 1.0 else 'q '
    return (f'{abre}{_num(cor[0])} {_num(cor[1])} {_num(cor[2])} rg\n'
            f'BT /{fonte} {_num(corpo)} Tf\n'
            f'{_matriz(rotacao, x, y)} Tm\n'
            f'({escapar(texto)}) Tj\nET Q\n')


def ops_imagem(x, y, largura, altura, xobj, opacidade=1.0, rotacao=0,
               gs='GSwmPLFPDF'):
    """Imagem posicionada e escalada.

    O `cm` do PDF já multiplica a escala pela rotação, e a ordem importa:
    escalar depois de girar deforma o desenho. Aqui a escala entra primeiro,
    como um `cm` separado.
    """
    abre = f'q /{gs} gs ' if opacidade < 1.0 else 'q '
    return (f'{abre}{_matriz(rotacao, x, y)} cm\n'
            f'{_num(largura)} 0 0 {_num(altura)} 0 0 cm\n'
            f'/{xobj} Do\nQ\n')


# ───────────────────────── manipulação do documento ──────────────────────────
OBJ = re.compile(rb'(\d+)\s+(\d+)\s+obj', re.S)


def _objetos(pdf):
    """{id: (inicio_do_corpo, fim_do_corpo)} — varredura simples, boa para os
    arquivos que o PL_FPDF gera e para os desta referência."""
    fora = {}
    for m in OBJ.finditer(pdf):
        fim = pdf.find(b'endobj', m.end())
        if fim > 0:
            fora[int(m.group(1))] = (m.end(), fim)
    return fora


def _valor(dic, chave):
    """Valor bruto de uma chave no dicionário, com balanceamento de << >> e [ ]."""
    p = dic.find(chave)
    if p < 0:
        return None
    i = p + len(chave)
    while i < len(dic) and dic[i:i + 1].isspace():
        i += 1
    if dic[i:i + 2] == b'<<':
        prof, j = 0, i
        while j < len(dic):
            if dic[j:j + 2] == b'<<':
                prof += 1; j += 2
            elif dic[j:j + 2] == b'>>':
                prof -= 1; j += 2
                if prof == 0:
                    return dic[i:j]
            else:
                j += 1
        return None
    if dic[i:i + 1] == b'[':
        j = dic.find(b']', i)
        return dic[i:j + 1] if j > 0 else None
    j = i
    while j < len(dic) and not dic[j:j + 1].isspace() and dic[j:j + 1] not in b'/>[':
        j += 1
    # referência indireta ocupa três tokens
    m = re.match(rb'\s*(\d+)\s+(\d+)\s+R', dic[i:])
    if m:
        return m.group(0).strip()
    return dic[i:j]


def _sem_chave(dic, chave):
    """Remove a chave e seu valor do dicionário."""
    v = _valor(dic, chave)
    if v is None:
        return dic
    p = dic.find(chave)
    fim = dic.find(v, p) + len(v)
    return dic[:p] + dic[fim:]


def mesclar_recursos(recursos, novas):
    """Mescla sub-dicionários (/Font, /ExtGState, /XObject) num /Resources.

    `novas` é {b'/Font': b'/Fwm <<...>>', ...}. Se a chave já existe como
    dicionário direto, as entradas entram nele; senão, a chave é criada.
    """
    saida = recursos
    for chave, entradas in novas.items():
        atual = _valor(saida, chave)
        if atual is not None and atual.startswith(b'<<'):
            p = saida.find(atual)
            saida = saida[:p + 2] + b' ' + entradas + b' ' + saida[p + 2:]
        else:
            # chave ausente, ou indireta (que não dá para editar aqui): a
            # entrada nova entra num dicionário próprio. Uma /Font indireta
            # perderia as fontes originais, então esse caso é recusado.
            if atual is not None:
                raise ValueError(f'{chave.decode()} indireto em /Resources')
            saida = saida[:2] + b' ' + chave + b' << ' + entradas + b' >> ' + saida[2:]
    return saida


def aplicar(pdf, por_pagina):
    """Aplica os desenhos e devolve o PDF com uma atualização incremental.

    `por_pagina` é {numero_1based: {'ops': str, 'recursos': {chave: entradas}}}.
    """
    objs = _objetos(pdf)
    proximo = max(objs) + 1
    paginas = _ordem_das_paginas(pdf, objs)

    novos = []          # (id, corpo_bytes)
    trocados = {}       # id -> corpo novo (páginas e /Resources)

    for num, pedido in sorted(por_pagina.items()):
        oid = paginas[num - 1]
        ini, fim = objs[oid]
        pag = pdf[ini:fim]

        # 1. o desenho vira um objeto de stream
        fluxo = pedido['ops'].encode('latin-1')
        id_fluxo = proximo; proximo += 1
        novos.append((id_fluxo,
                      b'<< /Length %d >>\nstream\n' % len(fluxo) + fluxo
                      + b'\nendstream'))

        # 2. /Contents vira array, com o desenho por último (fica por cima)
        conteudo = _valor(pag, b'/Contents')
        if conteudo is None:
            raise ValueError(f'página {num} sem /Contents')
        if conteudo.startswith(b'['):
            novo_conteudo = conteudo[:-1] + b' %d 0 R]' % id_fluxo
        else:
            novo_conteudo = b'[%s %d 0 R]' % (conteudo, id_fluxo)
        pag = _sem_chave(pag, b'/Contents')
        pag = pag[:pag.find(b'<<') + 2] + b' /Contents ' + novo_conteudo + b' ' \
            + pag[pag.find(b'<<') + 2:]

        # 3. /Resources próprio da página, para não contaminar as vizinhas
        recursos = _valor(pag, b'/Resources')
        if recursos is None:
            base = b'<< >>'
        elif recursos.startswith(b'<<'):
            base = recursos
        else:                                     # indireto e compartilhado
            alvo = int(recursos.split()[0])
            i2, f2 = objs[alvo]
            base = pdf[i2:f2].strip()
        id_rec = proximo; proximo += 1
        novos.append((id_rec, mesclar_recursos(base, pedido['recursos'])))
        pag = _sem_chave(pag, b'/Resources')
        pag = pag[:pag.find(b'<<') + 2] + b' /Resources %d 0 R ' % id_rec \
            + pag[pag.find(b'<<') + 2:]

        trocados[oid] = pag

    return _atualizacao_incremental(pdf, novos, trocados)


def _ordem_das_paginas(pdf, objs):
    """Ids das páginas na ordem do /Kids da raiz."""
    for oid, (ini, fim) in objs.items():
        corpo = pdf[ini:fim]
        if b'/Type /Pages' in corpo or b'/Type/Pages' in corpo:
            kids = _valor(corpo, b'/Kids')
            return [int(x) for x in re.findall(rb'(\d+)\s+\d+\s+R', kids)]
    raise ValueError('/Pages não encontrado')


def _atualizacao_incremental(pdf, novos, trocados):
    saida = bytearray(pdf)
    if not saida.endswith(b'\n'):
        saida += b'\n'
    offs = {}
    for oid, corpo in list(trocados.items()) + novos:
        offs[oid] = len(saida)
        saida += b'%d 0 obj' % oid + corpo + b'endobj\n'

    antigo = int(re.findall(rb'startxref\s+(\d+)', pdf)[-1])
    xref = len(saida)
    saida += b'xref\n'
    for oid in sorted(offs):
        saida += b'%d 1\n%010d 00000 n \n' % (oid, offs[oid])
    tam = max(max(offs), max(int(m) for m in re.findall(rb'(\d+)\s+\d+\s+obj', pdf))) + 1
    raiz = re.findall(rb'/Root\s+(\d+\s+\d+\s+R)', pdf)[-1]
    saida += (b'trailer\n<< /Size %d /Root %s /Prev %d >>\nstartxref\n%d\n%%%%EOF\n'
              % (tam, raiz, antigo, xref))
    return bytes(saida)


# ─────────────────────────── recursos padrão ─────────────────────────────────
def recursos_texto(opacidade=1.0, fonte='FwmPLFPDF', gs='GSwmPLFPDF',
                   base='Helvetica'):
    """/Font e /ExtGState para os desenhos de texto.

    Vão como dicionários diretos: são legais dentro de /Resources e evitam dois
    objetos indiretos por página.
    """
    return {
        b'/Font': ('/%s << /Type /Font /Subtype /Type1 /BaseFont /%s '
                   '/Encoding /WinAnsiEncoding >>' % (fonte, base)).encode(),
        b'/ExtGState': ('/%s << /Type /ExtGState /ca %s /CA %s >>'
                        % (gs, _num(opacidade), _num(opacidade))).encode(),
    }
