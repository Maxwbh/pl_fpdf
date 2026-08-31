# -*- coding: utf-8 -*-
"""
Referencia do copiador de objetos PDF em nivel de bytes que sera portado para
PL/SQL (PL_FPDF.MergePDFs / SplitPDF / ExtractPages / OutputModifiedPDF).

Escrito com as mesmas operacoes disponiveis no PL/SQL:
  - leitura do PDF de origem apenas por offsets de bytes (DBMS_LOB.SUBSTR)
  - busca de literais ASCII no BLOB (DBMS_LOB.INSTR)
  - o payload de stream e copiado byte a byte, sem passar por VARCHAR2
  - so a porcao ASCII do dicionario e reescrita (renumeracao de referencias)

Algoritmo:
  1. le a xref de cada origem  -> id do objeto => offset
  2. para cada pagina escolhida, faz o fecho transitivo das referencias
     (ignorando /Parent, que sera reescrito)
  3. copia os objetos necessarios deslocando os ids por um offset fixo
     por documento de origem
  4. emite Catalog (1 0 obj) + Pages (2 0 obj) novos, xref e trailer
"""
import re

EOL = b'\n'


# ───────────────────────────────── leitura da origem ─────────────────────────
class Source:
    """Um PDF de origem ja carregado em memoria (equivale ao BLOB no PL/SQL)."""

    def __init__(self, data: bytes):
        self.b = data
        self.xref = {}          # id -> offset (0-based, como DBMS_LOB e 1-based no PL/SQL)
        self.trailer = b''
        self._parse_xref()
        self.root = self._trailer_ref(b'/Root')
        self.pages = []         # ids dos objetos /Type /Page, em ordem
        self.inherited = {}     # page_id -> {b'/MediaBox': ..., b'/Resources': ...}
        self._walk_pages()

    # -- xref ---------------------------------------------------------------
    def _parse_xref(self):
        tail = self.b[-2048:]
        m = None
        for m in re.finditer(rb'startxref\s+(\d+)', tail):
            pass
        if not m:
            raise ValueError('startxref nao encontrado')
        off = int(m.group(1))
        seen = set()
        while off and off not in seen:
            seen.add(off)
            off = self._parse_xref_section(off)

    def _parse_xref_section(self, off):
        """Le uma secao xref classica; devolve o offset de /Prev (ou None)."""
        sec = self.b[off:off + 32767]
        if not sec.startswith(b'xref'):
            raise ValueError('xref stream nao suportado (PDF 1.5 comprimido)')
        pos = 4
        while True:
            m = re.compile(rb'\s*(\d+)\s+(\d+)\s*').match(sec, pos)
            if not m:
                break
            start, count = int(m.group(1)), int(m.group(2))
            pos = m.end()
            for i in range(count):
                entry = sec[pos:pos + 20]
                pos += 20
                if len(entry) < 18:
                    break
                if entry[17:18] == b'n' or entry[18:19] == b'n':
                    oid = start + i
                    if oid not in self.xref:      # xref mais recente vence
                        self.xref[oid] = int(entry[0:10])
        t = sec.find(b'trailer', pos - 20 if pos > 20 else 0)
        if t < 0:
            return None
        if not self.trailer:
            self.trailer = sec[t:t + 2048]
        prev = re.search(rb'/Prev\s+(\d+)', sec[t:t + 2048])
        return int(prev.group(1)) if prev else None

    def _trailer_ref(self, key):
        m = re.search(re.escape(key) + rb'\s+(\d+)\s+(\d+)\s+R', self.trailer)
        if not m:
            raise ValueError(f'{key.decode()} nao encontrado no trailer')
        return int(m.group(1))

    # -- objetos ------------------------------------------------------------
    def obj_extent(self, oid):
        """(inicio, fim, fim_do_dicionario) do objeto, em bytes.

        fim_do_dicionario e onde comeca o payload do stream (ou == fim).
        """
        off = self.xref[oid]
        head = self.b[off:off + 32767]
        p_stream = head.find(b'stream')
        p_endobj = head.find(b'endobj')
        if p_stream < 0 or (0 <= p_endobj < p_stream):
            if p_endobj < 0:
                raise ValueError(f'endobj nao encontrado no objeto {oid}')
            return off, off + p_endobj + 6, off + p_endobj + 6
        # objeto com stream: pula o payload usando /Length
        length = self._length(head[:p_stream], oid)
        data = off + p_stream + 6
        if self.b[data:data + 2] == b'\r\n':
            data += 2
        elif self.b[data:data + 1] in (b'\n', b'\r'):
            data += 1
        after = self.b.find(b'endobj', data + length)
        if after < 0:
            raise ValueError(f'endobj nao encontrado apos o stream do objeto {oid}')
        return off, after + 6, data + length

    def _length(self, dict_bytes, oid):
        m = re.search(rb'/Length\s+(\d+)\s+(\d+)\s+R', dict_bytes)
        if m:                                    # /Length indireto
            lid = int(m.group(1))
            s, e, _ = self.obj_extent(lid)
            v = re.search(rb'obj\s*(\d+)', self.b[s:e])
            if not v:
                raise ValueError(f'/Length indireto invalido no objeto {oid}')
            return int(v.group(1))
        m = re.search(rb'/Length\s+(\d+)', dict_bytes)
        if not m:
            raise ValueError(f'/Length ausente no objeto {oid}')
        return int(m.group(1))

    def obj_dict(self, oid):
        """Porcao ASCII do objeto, sem o cabecalho 'N G obj'."""
        start, _, dict_end = self.obj_extent(oid)
        raw = self.b[start:dict_end]
        m = re.match(rb'\s*\d+\s+\d+\s+obj', raw)
        return raw[m.end():] if m else raw

    # -- arvore de paginas --------------------------------------------------
    def _walk_pages(self):
        root = self.obj_dict(self.root)
        m = re.search(rb'/Pages\s+(\d+)\s+\d+\s+R', root)
        if not m:
            raise ValueError('/Pages nao encontrado no Catalog')
        self._walk_node(int(m.group(1)), {})

    def _walk_node(self, oid, inherited, depth=0):
        if depth > 32:
            raise ValueError('arvore de paginas profunda demais')
        d = self.obj_dict(oid)
        inh = dict(inherited)
        for key in (b'/MediaBox', b'/Resources', b'/CropBox', b'/Rotate'):
            v = dict_value(d, key)
            if v is not None:
                inh[key] = v
        if re.search(rb'/Type\s*/Page\b(?!s)', d):
            self.pages.append(oid)
            self.inherited[oid] = inh
            return
        kids = dict_value(d, b'/Kids')
        if kids is None:
            raise ValueError(f'no {oid} sem /Kids e sem /Type /Page')
        for k in re.finditer(rb'(\d+)\s+\d+\s+R', kids):
            self._walk_node(int(k.group(1)), inh, depth + 1)


def dict_value(d, key):
    """Valor bruto de uma chave do dicionario (array, nome, numero ou ref)."""
    i = d.find(key)
    while i >= 0:
        nxt = d[i + len(key):i + len(key) + 1]
        if not nxt.isalpha():
            break
        i = d.find(key, i + 1)
    if i < 0:
        return None
    j = i + len(key)
    while j < len(d) and d[j:j + 1].isspace():
        j += 1
    if d[j:j + 1] == b'[':
        depth, k = 0, j
        while k < len(d):
            if d[k:k + 1] == b'[':
                depth += 1
            elif d[k:k + 1] == b']':
                depth -= 1
                if depth == 0:
                    return d[j:k + 1]
            k += 1
        return None
    if d[j:j + 1] == b'<' and d[j + 1:j + 2] == b'<':
        depth, k = 0, j
        while k < len(d) - 1:
            if d[k:k + 2] == b'<<':
                depth += 1
                k += 2
                continue
            if d[k:k + 2] == b'>>':
                depth -= 1
                k += 2
                if depth == 0:
                    return d[j:k]
                continue
            k += 1
        return None
    m = re.compile(rb'(\d+\s+\d+\s+R|/[^\s/\[\]<>()]+|[-+.\d]+|true|false|null)').match(d, j)
    return m.group(0) if m else None


# ─────────────────────────── renumeracao de referencias ──────────────────────
REF = re.compile(rb'(\d+)([ \t\r\n]+)(\d+)([ \t\r\n]+)R(?![A-Za-z0-9])')


def shift_refs(text: bytes, shift: int) -> bytes:
    """Soma `shift` ao id de toda referencia indireta 'N G R' do texto ASCII."""
    return REF.sub(lambda m: b'%d %s R' % (int(m.group(1)) + shift, m.group(3)), text)


def collect_refs(text: bytes):
    return [int(m.group(1)) for m in REF.finditer(text)]


# ────────────────────────────────── montagem ─────────────────────────────────
def strip_key(d: bytes, key: bytes) -> bytes:
    """Remove `key` e seu valor do dicionario."""
    v = dict_value(d, key)
    if v is None:
        return d
    i = d.find(key)
    j = d.find(v, i + len(key)) + len(v)
    return d[:i] + d[j:]


def page_body(src, oid):
    """Dicionario final da pagina: /Parent removido e heranca materializada.

    A referencia ao novo no /Pages nao entra aqui: ela e inserida depois da
    renumeracao, senao o proprio '2 0 R' seria deslocado junto.
    """
    body = strip_key(src.obj_dict(oid), b'/Parent')
    for key, val in src.inherited[oid].items():
        if val is not None and dict_value(body, key) is None:
            body = body.replace(b'<<', b'<<' + key + b' ' + val + b' ', 1)
    return body


def assemble(selection):
    """selection = [(Source, [indices de pagina 0-based]), ...] -> bytes do PDF."""
    out = bytearray(b'%PDF-1.7\n%\xe2\xe3\xcf\xd3\n')
    offsets = {}                                 # novo id -> offset
    next_id = 3                                  # 1 = Catalog, 2 = Pages
    kids = []

    for src, page_idx in selection:
        shift = next_id - 1                      # id antigo N -> N + shift
        max_id = max(src.xref) if src.xref else 0
        next_id += max_id

        # 1. fecho transitivo a partir das paginas escolhidas
        page_ids = [src.pages[i] for i in page_idx]
        needed, queue = set(page_ids), list(page_ids)
        page_set = set(page_ids)
        while queue:
            oid = queue.pop()
            if oid not in src.xref:
                continue
            d = page_body(src, oid) if oid in page_set else src.obj_dict(oid)
            for r in collect_refs(d):
                if r not in needed and r in src.xref:
                    needed.add(r)
                    queue.append(r)

        # 2. copia os objetos necessarios
        for oid in sorted(needed):
            start, end, dict_end = src.obj_extent(oid)
            raw = src.b[start:dict_end]
            m = re.match(rb'\s*\d+\s+\d+\s+obj', raw)
            body = raw[m.end():] if m else raw
            if oid in page_set:
                body = shift_refs(page_body(src, oid), shift)
                body = body.replace(b'<<', b'<</Parent 2 0 R ', 1)
            else:
                body = shift_refs(body, shift)
            new_id = oid + shift
            offsets[new_id] = len(out)
            out += b'%d 0 obj' % new_id + body
            out += src.b[dict_end:end]           # payload do stream + endobj
            out += EOL
            if oid in page_set:
                pass
        kids += [oid + shift for oid in page_ids]

    # 3. Catalog e Pages novos
    offsets[1] = len(out)
    out += b'1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
    offsets[2] = len(out)
    out += b'2 0 obj<</Type/Pages/Count %d/Kids[' % len(kids)
    out += b' '.join(b'%d 0 R' % k for k in kids)
    out += b']>>endobj\n'

    # 4. xref + trailer
    size = max(offsets) + 1
    xref_off = len(out)
    out += b'xref\n0 %d\n' % size
    out += b'0000000000 65535 f \n'
    for i in range(1, size):
        if i in offsets:
            out += b'%010d 00000 n \n' % offsets[i]
        else:
            out += b'0000000000 65535 f \n'
    out += b'trailer<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n' % (size, xref_off)
    return bytes(out)


# ──────────────────────────────────── api ────────────────────────────────────
def merge(datas):
    sel = []
    for d in datas:
        s = Source(d)
        sel.append((s, list(range(len(s.pages)))))
    return assemble(sel)


def parse_pages(spec: str, total: int):
    """'1,3,5-7' ou 'ALL' -> lista de indices 0-based, na ordem pedida."""
    if spec.strip().upper() == 'ALL':
        return list(range(total))
    out = []
    for part in spec.split(','):
        part = part.strip()
        if not part:
            raise ValueError(f'especificacao de paginas invalida: {spec!r}')
        if '-' in part:
            a, b = part.split('-', 1)
            a, b = int(a), int(b)
        else:
            a = b = int(part)
        if a < 1 or b < a or b > total:
            raise ValueError(f'pagina fora do intervalo 1..{total}: {part!r}')
        out += list(range(a - 1, b))
    return out


def extract(data, spec):
    s = Source(data)
    return assemble([(s, parse_pages(spec, len(s.pages)))])


def split(data, specs):
    s = Source(data)
    return [assemble([(s, parse_pages(spec, len(s.pages)))]) for spec in specs]
