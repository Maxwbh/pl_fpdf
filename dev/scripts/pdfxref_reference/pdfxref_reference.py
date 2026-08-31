# -*- coding: utf-8 -*-
"""
Referência da xref em stream e dos object streams (PDF 1.5+), a ser portada.

O que falta no package
---------------------
`pdf_src_load` sabe ler a xref clássica — a tabela de texto que começa com
`xref` e termina no `trailer`. Todo produtor moderno grava outra coisa: a xref
vira um **objeto com stream** (`/Type /XRef`), comprimido, e os objetos sem
stream vão para dentro de **object streams** (`/Type /ObjStm`), também
comprimidos. Nesses arquivos um objeto não fica num offset do arquivo: fica
dentro do stream de outro objeto. Enquanto isso não existir, o copiador recusa
com `ORA-20843`, e junto vão merge, extract, marca d'água e overlay sobre
documento de terceiro.

O inflate já está portado e provado no banco (`tests/diag_inflate.sql`); o que
falta é a leitura das duas estruturas. Esta referência é essa leitura.

As três formas de entrada da xref
---------------------------------
1. **Tabela clássica** — `xref` ... `trailer`. Já suportada; aqui só para que a
   cadeia `/Prev` possa misturar as duas (arquivo híbrido, ou incremental sobre
   um PDF 1.4).
2. **Stream** — objeto `/Type /XRef` com `/W`, `/Index`, `/Size`, `/Prev`. As
   entradas são binárias, de largura fixa, e o *trailer* é o próprio dicionário
   do objeto.
3. **Híbrido** — tabela clássica cujo trailer tem `/XRefStm`, apontando para uma
   xref em stream com os objetos que o leitor antigo não enxerga. Raro, mas o
   Acrobat gera; ignorá-lo perde objetos silenciosamente, que é o pior modo de
   falhar.

O predictor
-----------
A xref em stream quase sempre vem com `/DecodeParms << /Predictor 12 ... >>`.
O predictor não é compressão: é uma transformação que o compressor aplica ANTES
do deflate para que colunas parecidas virem zeros. Sem desfazê-la o inflate
devolve bytes limpos e **errados** — offsets plausíveis, apontando para o lugar
errado. É o mesmo gênero de erro do inflate com os bits invertidos: não quebra,
mente.

`/Predictor 2` é o preditor TIFF, e não aparece em xref (a especificação o
define para imagens). Aqui ele é **recusado**, em vez de tratado como 1.

Os três tipos de entrada
------------------------
- **0** — objeto livre. `campo2` é o próximo id livre; ignorado.
- **1** — objeto no arquivo. `campo2` é o offset, `campo3` a geração.
- **2** — objeto **dentro de um object stream**. `campo2` é o id do object
  stream e `campo3` o índice dentro dele. Este é o caso que não cabe no modelo
  de "objeto = offset" que o package usa hoje.

Um campo de largura zero em `/W` não vem no stream: vale o default. Para o
tipo, o default é **1** (a especificação diz isso explicitamente, e é o que
permite `/W [0 4 2]` num arquivo só de objetos usados); para os outros, 0.

Object stream
-------------
`/N` pares de inteiros no início (`id offset`), o corpo começa em `/First`, e
os offsets são relativos a ele. Nenhum objeto de dentro pode ter stream nem ser
o próprio `/Length` de outro — a especificação proíbe —, então o que sai daqui é
**texto**, e é isso que torna a porta viável: o copiador do package copia bytes
para objetos com stream, e para estes basta o texto.
"""
import zlib

MAX_SECOES = 64          # mesma guarda da cadeia /Prev no package


class ErroXref(Exception):
    pass


# ───────────────────────── primitivas espelhando o package ───────────────────
# Estas quatro existem no PL/SQL como pdf_is_ws, pdf_is_alnum, pdf_key_pos e
# pdf_dict_value. Reescritas aqui com a mesma semântica para que a referência
# seja portável linha a linha, e não uma segunda implementação com outras
# manias.

def is_ws(c):
    return c in b' \t\n\r\f\x00'


def is_alnum(c):
    return (b'0' <= c <= b'9') or (b'A' <= c <= b'Z') or (b'a' <= c <= b'z')


def key_pos(dic, chave):
    """Posição da chave (base 0), pulando prefixos: /S não casa /Size."""
    i = dic.find(chave)
    while i >= 0 and i + len(chave) < len(dic) \
            and is_alnum(dic[i + len(chave):i + len(chave) + 1]):
        i = dic.find(chave, i + 1)
    return i


def dict_value(dic, chave):
    """Valor bruto da chave: array, sub-dicionário, referência, nome ou número."""
    i = key_pos(dic, chave)
    if i < 0:
        return None
    n = len(dic)
    j = i + len(chave)
    while j < n and is_ws(dic[j:j + 1]):
        j += 1
    if j >= n:
        return None

    if dic[j:j + 1] == b'[':
        prof, k = 0, j
        while k < n:
            if dic[k:k + 1] == b'[':
                prof += 1
            elif dic[k:k + 1] == b']':
                prof -= 1
                if prof == 0:
                    return dic[j:k + 1]
            k += 1
        return None

    if dic[j:j + 2] == b'<<':
        prof, k = 0, j
        while k < n:
            if dic[k:k + 2] == b'<<':
                prof += 1
                k += 2
            elif dic[k:k + 2] == b'>>':
                prof -= 1
                k += 2
                if prof == 0:
                    return dic[j:k]
            else:
                k += 1
        return None

    if dic[j:j + 1] == b'/':
        k = j + 1
        while k < n and not is_ws(dic[k:k + 1]) \
                and dic[k:k + 1] not in b'/[]<>()':
            k += 1
        return dic[j:k]

    k = j
    while k < n and (b'0' <= dic[k:k + 1] <= b'9' or dic[k:k + 1] in b'+-.'):
        k += 1
    if k > j:
        fim = k - 1
        p = k
        while p < n and is_ws(dic[p:p + 1]):
            p += 1
        q = p
        while q < n and b'0' <= dic[q:q + 1] <= b'9':
            q += 1
        if q > p:
            r = q
            while r < n and is_ws(dic[r:r + 1]):
                r += 1
            if r > q and dic[r:r + 1] == b'R':
                fim = r
        return dic[j:fim + 1]

    k = j
    while k < n and is_alnum(dic[k:k + 1]):
        k += 1
    if k > j:
        return dic[j:k]
    return None


def inteiros(txt):
    """Todos os inteiros de um array como '[0 11 20 3]'."""
    if txt is None:
        return []
    out, i, n = [], 0, len(txt)
    while i < n:
        if b'0' <= txt[i:i + 1] <= b'9':
            j = i
            while j < n and b'0' <= txt[j:j + 1] <= b'9':
                j += 1
            out.append(int(txt[i:j]))
            i = j
        else:
            i += 1
    return out


def refs(txt):
    """Ids das referências indiretas 'N G R' — espelha pdf_collect_refs."""
    if txt is None:
        return []
    out, i, n = [], 0, len(txt)
    while i < n:
        c = txt[i:i + 1]
        if b'0' <= c <= b'9' and (i == 0 or not is_alnum(txt[i - 1:i])):
            j = i
            while j < n and b'0' <= txt[j:j + 1] <= b'9':
                j += 1
            k = j
            while k < n and is_ws(txt[k:k + 1]):
                k += 1
            if k > j:
                p = k
                while p < n and b'0' <= txt[p:p + 1] <= b'9':
                    p += 1
                if p > k:
                    q = p
                    while q < n and is_ws(txt[q:q + 1]):
                        q += 1
                    if q > p and txt[q:q + 1] == b'R' \
                            and (q + 1 >= n or not is_alnum(txt[q + 1:q + 2])):
                        out.append(int(txt[i:j]))
                        i = q + 1
                        continue
            i = j
        else:
            i += 1
    return out


# ───────────────────────────────── predictor ─────────────────────────────────

def desfazer_predictor(dados, predictor, cores, bpc, colunas):
    """Desfaz o predictor do /DecodeParms. Devolve os dados originais.

    `predictor` 1 (ou ausente) é identidade. 10..15 é o conjunto do PNG: o
    número do dicionário só diz qual o compressor *usou como padrão* — quem
    manda é o byte de filtro no início de cada linha. Por isso todos os cinco
    filtros precisam existir, mesmo com /Predictor 12 no dicionário.
    """
    if predictor is None or predictor == 1:
        return dados
    if predictor < 10:
        # 2 é o preditor TIFF, definido para imagem. Tratar como 1 devolveria
        # offsets errados sem nenhum sinal — recusar é mais barato.
        raise ErroXref('predictor %d nao suportado' % predictor)

    bpp = max(1, (cores * bpc + 7) // 8)     # bytes por pixel, mínimo 1
    linha = (colunas * cores * bpc + 7) // 8
    if len(dados) % (linha + 1) != 0:
        raise ErroXref('dados do predictor nao sao multiplo de %d' % (linha + 1))

    ant = bytearray(linha)
    out = bytearray()
    p = 0
    while p < len(dados):
        filtro = dados[p]
        cur = bytearray(dados[p + 1:p + 1 + linha])
        p += 1 + linha
        if filtro == 0:                       # None
            pass
        elif filtro == 1:                     # Sub
            for i in range(bpp, linha):
                cur[i] = (cur[i] + cur[i - bpp]) & 0xFF
        elif filtro == 2:                     # Up
            for i in range(linha):
                cur[i] = (cur[i] + ant[i]) & 0xFF
        elif filtro == 3:                     # Average
            for i in range(linha):
                esq = cur[i - bpp] if i >= bpp else 0
                cur[i] = (cur[i] + ((esq + ant[i]) >> 1)) & 0xFF
        elif filtro == 4:                     # Paeth
            for i in range(linha):
                a = cur[i - bpp] if i >= bpp else 0
                b = ant[i]
                c = ant[i - bpp] if i >= bpp else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                cur[i] = (cur[i] + pred) & 0xFF
        else:
            raise ErroXref('filtro PNG %d invalido' % filtro)
        out += cur
        ant = cur
    return bytes(out)


# ────────────────────────────── leitura crua do PDF ──────────────────────────

class Entrada(object):
    """Uma linha da xref, nas duas formas que importam."""
    __slots__ = ('tipo', 'a', 'b')

    def __init__(self, tipo, a, b):
        self.tipo = tipo      # 1 = offset no arquivo, 2 = dentro de object stream
        self.a = a            # tipo 1: offset      | tipo 2: id do object stream
        self.b = b            # tipo 1: geração     | tipo 2: índice dentro dele

    def __repr__(self):
        return 'Entrada(%d, %d, %d)' % (self.tipo, self.a, self.b)

    def __eq__(self, o):
        return (self.tipo, self.a, self.b) == (o.tipo, o.a, o.b)


def corpo_do_objeto(doc, off):
    """(dicionário ASCII, payload do stream) do objeto que começa em `off`.

    Espelha pdf_obj_extent, mas para um offset conhecido e sem consultar a xref:
    aqui ela ainda não existe — é justamente o que se está montando. Por isso
    /Length indireto não é aceito num objeto de xref (e nenhum produtor grava
    assim: o leitor precisaria da xref para achar o /Length que dá a xref).
    """
    cab = doc[off:off + 65536]
    ps = cab.find(b'stream')
    pe = cab.find(b'endobj')
    if ps < 0 or (0 <= pe < ps):
        if pe < 0:
            raise ErroXref('endobj nao encontrado em %d' % off)
        return cab[:pe], b''

    dic = cab[:ps]
    lenval = dict_value(dic, b'/Length')
    if lenval is None:
        raise ErroXref('/Length ausente no objeto em %d' % off)
    if b'R' in lenval:
        raise ErroXref('/Length indireto num objeto de xref (%d)' % off)
    n = int(lenval)

    ini = off + ps + 6
    if doc[ini:ini + 2] == b'\r\n':
        ini += 2
    elif doc[ini:ini + 1] in (b'\n', b'\r'):
        ini += 1
    return dic, doc[ini:ini + n]


def descomprimir(dic, dados):
    """Aplica /Filter e /DecodeParms. Só FlateDecode — é o que a xref usa."""
    filtro = dict_value(dic, b'/Filter')
    if filtro is None:
        crus = dados
    elif filtro in (b'/FlateDecode', b'[/FlateDecode]', b'[ /FlateDecode ]'):
        crus = zlib.decompress(dados)
    else:
        raise ErroXref('filtro %s nao suportado na xref' % filtro)

    parms = dict_value(dic, b'/DecodeParms')
    if parms is None or parms == b'null':
        return crus
    if parms.startswith(b'['):                # array de um elemento só
        i = parms.find(b'<<')
        parms = dict_value(parms, b'/DecodeParms') if i < 0 else parms[i:-1]
    pred = dict_value(parms, b'/Predictor')
    if pred is None:
        return crus
    return desfazer_predictor(
        crus, int(pred),
        int(dict_value(parms, b'/Colors') or 1),
        int(dict_value(parms, b'/BitsPerComponent') or 8),
        int(dict_value(parms, b'/Columns') or 1))


# ─────────────────────────────── xref em stream ──────────────────────────────

def ler_xref_stream(dic, dados):
    """{oid: Entrada} de uma xref em stream já descomprimida e sem predictor."""
    w = inteiros(dict_value(dic, b'/W'))
    if len(w) < 3:
        raise ErroXref('/W invalido na xref em stream')
    larg = sum(w)
    if larg == 0:
        raise ErroXref('/W com todos os campos zerados')
    if len(dados) % larg != 0:
        raise ErroXref('xref em stream: %d bytes nao dividem por /W = %d'
                       % (len(dados), larg))

    idx = inteiros(dict_value(dic, b'/Index'))
    if not idx:
        tam = dict_value(dic, b'/Size')
        if tam is None:
            raise ErroXref('xref em stream sem /Size nem /Index')
        idx = [0, int(tam)]

    out = {}
    p = 0
    for k in range(0, len(idx) - 1, 2):
        inicio, quantos = idx[k], idx[k + 1]
        for i in range(quantos):
            if p + larg > len(dados):
                raise ErroXref('xref em stream mais curta que o /Index')
            campos = []
            for c in range(3):
                if w[c] == 0:
                    # Largura zero não ocupa espaço: vale o default. Para o
                    # campo do TIPO o default é 1, não 0 — trocar isso faz o
                    # arquivo inteiro virar "objetos livres" em silêncio.
                    campos.append(1 if c == 0 else 0)
                else:
                    v = 0
                    for _ in range(w[c]):
                        v = (v << 8) | dados[p]
                        p += 1
                    campos.append(v)
            tipo, a, b = campos
            if tipo in (1, 2) and (inicio + i) not in out:
                out[inicio + i] = Entrada(tipo, a, b)
    return out


# ────────────────────────────── object stream ────────────────────────────────

def ler_object_stream(dic, dados):
    """{oid: corpo} de um /Type /ObjStm já descomprimido.

    O corpo devolvido é o texto do objeto — o que `pdf_obj_body` devolveria se
    ele estivesse solto no arquivo. Nenhum objeto de dentro tem stream, então
    não há payload binário a preservar.
    """
    n = dict_value(dic, b'/N')
    first = dict_value(dic, b'/First')
    if n is None or first is None:
        raise ErroXref('object stream sem /N ou /First')
    n, first = int(n), int(first)

    pares = inteiros(dados[:first])
    if len(pares) < 2 * n:
        raise ErroXref('object stream: %d pares, esperado %d'
                       % (len(pares) // 2, n))

    out = {}
    for i in range(n):
        oid, off = pares[2 * i], pares[2 * i + 1]
        ini = first + off
        fim = first + pares[2 * i + 3] if i + 1 < n else len(dados)
        if ini > len(dados) or fim > len(dados) or fim < ini:
            raise ErroXref('object stream: offset fora do stream (obj %d)' % oid)
        out[oid] = dados[ini:fim].strip()
    return out


# ──────────────────────────────── índice inteiro ─────────────────────────────

class Indice(object):
    def __init__(self):
        self.xref = {}         # oid => Entrada
        self.corpos = {}       # oid => texto, só para os do tipo 2
        self.root = None
        self.encrypt = None
        self.secoes = []       # ('tabela'|'stream', offset), na ordem lida


def _ler_secao_tabela(doc, off, idx):
    """Lê uma xref clássica em `off`. Devolve o trailer."""
    fim = doc.find(b'trailer', off)
    if fim < 0:
        raise ErroXref('trailer ausente na xref em %d' % off)
    corpo = doc[off + 4:fim]
    n = len(corpo)
    pos = [0]

    def nx():
        """Próximo inteiro, avançando `pos` — espelha o `nx` de pdf_src_load."""
        while pos[0] < n and is_ws(corpo[pos[0]:pos[0] + 1]):
            pos[0] += 1
        a = pos[0]
        while pos[0] < n and b'0' <= corpo[pos[0]:pos[0] + 1] <= b'9':
            pos[0] += 1
        return int(corpo[a:pos[0]]) if pos[0] > a else None

    while True:
        inicio, quantos = nx(), nx()
        if inicio is None or quantos is None:
            break
        for i in range(quantos):
            eoff, gen = nx(), nx()
            if eoff is None or gen is None:
                break
            while pos[0] < n and is_ws(corpo[pos[0]:pos[0] + 1]):
                pos[0] += 1
            tipo = corpo[pos[0]:pos[0] + 1]
            pos[0] += 1
            if tipo == b'n' and (inicio + i) not in idx.xref:
                idx.xref[inicio + i] = Entrada(1, eoff, gen)

    # A tabela termina no 'trailer'; o dicionário vem logo depois.
    return doc[fim:fim + 4096]


def _ler_secao_stream(doc, off, idx):
    """Lê uma xref em stream em `off`. Devolve o dicionário, que é o trailer."""
    dic, dados = corpo_do_objeto(doc, off)
    if dict_value(dic, b'/Type') != b'/XRef':
        raise ErroXref('objeto em %d nao e /Type /XRef' % off)
    entradas = ler_xref_stream(dic, descomprimir(dic, dados))
    for oid, e in entradas.items():
        if oid not in idx.xref:
            idx.xref[oid] = e
    return dic


def indexar(doc, decifra=None, materializar=True):
    """Monta o índice de um PDF, com xref clássica, em stream ou híbrida.

    `materializar=False` para a xref e NÃO abre os object streams. Existe por
    causa de um ovo-e-galinha: num PDF cifrado a chave sai do dicionário
    /Encrypt, que sai do trailer — mas abrir os object streams para chegar ao
    trailer exigiria a chave que ainda não se tem. A xref em stream nunca é
    cifrada, então essa metade sempre pode ser lida.

    `decifra(oid, dados) -> bytes` é usado no payload dos **object streams**
    antes de descomprimir. Num PDF cifrado o ObjStm vem cifrado, e tentar
    inflar sem decifrar devolve erro ou lixo. A xref em stream **não** passa
    por aí: a especificação manda que ela nunca seja cifrada, justamente porque
    o leitor precisa dela para achar o dicionário /Encrypt.
    """
    if doc[:5] != b'%PDF-':
        raise ErroXref('cabecalho %PDF- ausente')

    cauda = doc[max(0, len(doc) - 2048):]
    p = cauda.rfind(b'startxref')
    if p < 0:
        raise ErroXref('startxref nao encontrado')
    off = inteiros(cauda[p + 9:p + 40])[0]

    idx = Indice()
    vistos = set()
    while off is not None and off not in vistos and len(vistos) < MAX_SECOES:
        vistos.add(off)
        if doc[off:off + 4] == b'xref':
            trailer = _ler_secao_tabela(doc, off, idx)
            idx.secoes.append(('tabela', off))
            # Híbrido: o trailer clássico traz /XRefStm com o que ele não vê.
            # Ler DEPOIS da tabela é o que a especificação manda, mas antes do
            # /Prev — e a regra "quem chegou primeiro vence" cuida do resto.
            hib = dict_value(trailer, b'/XRefStm')
            if hib is not None:
                _ler_secao_stream(doc, int(hib), idx)
                idx.secoes.append(('stream', int(hib)))
        else:
            trailer = _ler_secao_stream(doc, off, idx)
            idx.secoes.append(('stream', off))

        if idx.root is None:
            r = refs(dict_value(trailer, b'/Root'))
            idx.root = r[0] if r else None
        if idx.encrypt is None:
            idx.encrypt = dict_value(trailer, b'/Encrypt')
        prev = dict_value(trailer, b'/Prev')
        off = int(prev) if prev is not None else None

    if idx.root is None:
        raise ErroXref('/Root nao encontrado no trailer')

    # Materializa os objetos que moram dentro de object streams. Um ObjStm é
    # aberto uma vez só, mesmo que guarde cinquenta objetos — descomprimir por
    # objeto seria o custo dominante da carga em PL/SQL.
    if not materializar:
        return idx
    quais = sorted(set(e.a for e in idx.xref.values() if e.tipo == 2))
    for stm in quais:
        ent = idx.xref.get(stm)
        if ent is None or ent.tipo != 1:
            raise ErroXref('object stream %d ausente da xref' % stm)
        dic, dados = corpo_do_objeto(doc, ent.a)
        if dict_value(dic, b'/Type') != b'/ObjStm':
            raise ErroXref('objeto %d nao e /Type /ObjStm' % stm)
        if decifra is not None:
            dados = decifra(stm, dados)
        for oid, corpo in ler_object_stream(dic, descomprimir(dic, dados)).items():
            e = idx.xref.get(oid)
            if e is not None and e.tipo == 2 and e.a == stm:
                idx.corpos[oid] = corpo
    return idx


def corpo(doc, idx, oid):
    """Texto do objeto `oid`, esteja ele solto no arquivo ou num ObjStm."""
    if oid in idx.corpos:
        return idx.corpos[oid]
    e = idx.xref.get(oid)
    if e is None:
        raise ErroXref('objeto %d ausente da xref' % oid)
    if e.tipo != 1:
        raise ErroXref('objeto %d do tipo 2 sem corpo materializado' % oid)
    dic, _ = corpo_do_objeto(doc, e.a)
    i = dic.find(b'obj')
    return dic[i + 3:].strip() if i >= 0 else dic.strip()
