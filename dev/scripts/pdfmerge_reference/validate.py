# -*- coding: utf-8 -*-
"""
Valida o copiador de objetos (pdfmerge_reference.py) contra o MuPDF.

Gera PDFs de origem variados (com stream comprimido, /Length indireto,
arvore de paginas aninhada com heranca de /MediaBox e /Resources, imagem
compartilhada entre paginas) e confere merge / extract / split:

  - o MuPDF abre o resultado sem erro
  - a contagem de paginas bate
  - o texto de cada pagina bate com o da pagina de origem correspondente
  - a caixa da pagina (heranca preservada) bate
  - as imagens referenciadas continuam presentes

Uso:  python scripts/pdfmerge_reference/validate.py
"""
import sys
import zlib

sys.path.insert(0, 'dev/scripts/pdfmerge_reference')
import fitz                                            # noqa: E402
from pdfmerge_reference import Source, merge, extract, split, parse_pages  # noqa: E402


# ─────────────────────────── geradores de PDF de origem ──────────────────────
def build_pdf(pages, *, nested=False, indirect_length=False, compress=False,
              shared_image=False):
    """Monta um PDF de teste a mao. pages = [(texto, largura, altura), ...]."""
    objs = {}                                          # id -> bytes do corpo
    nid = 3                                            # 1 Catalog, 2 Pages raiz

    font_id = nid; nid += 1
    objs[font_id] = b'<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>'

    img_id = None
    if shared_image:
        img_id = nid; nid += 1
        px = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0])   # 2x2 RGB
        objs[img_id] = (b'<</Type/XObject/Subtype/Image/Width 2/Height 2'
                        b'/ColorSpace/DeviceRGB/BitsPerComponent 8/Length %d>>stream\n'
                        % len(px)) + px + b'\nendstream'

    res = b'<</Font<</F1 %d 0 R>>' % font_id
    if img_id:
        res += b'/XObject<</Im1 %d 0 R>>' % img_id
    res += b'>>'
    res_id = nid; nid += 1
    objs[res_id] = res

    page_ids, extra = [], []
    for text, w, h in pages:
        content = b'BT /F1 24 Tf 72 %d Td (%s) Tj ET\n' % (h - 100, text.encode())
        if img_id:
            content += b'q 100 0 0 100 72 72 cm /Im1 Do Q\n'
        if compress:
            payload, filt = zlib.compress(content), b'/Filter/FlateDecode'
        else:
            payload, filt = content, b''
        cid = nid; nid += 1
        if indirect_length:
            lid = nid; nid += 1
            objs[lid] = b'\n%d\n' % len(payload)
            head = b'<</Length %d 0 R%s>>stream\n' % (lid, filt)
        else:
            head = b'<</Length %d%s>>stream\n' % (len(payload), filt)
        objs[cid] = head + payload + b'\nendstream'
        pid = nid; nid += 1
        body = b'<</Type/Page/Parent 2 0 R/Contents %d 0 R' % cid
        if not nested:                                 # sem heranca: tudo na pagina
            body += b'/MediaBox[0 0 %d %d]/Resources %d 0 R' % (w, h, res_id)
        body += b'>>'
        objs[pid] = body
        page_ids.append(pid)
        extra.append((w, h))

    if nested:
        # duas paginas por no intermediario; MediaBox e Resources herdados da raiz
        mids, i = [], 0
        while i < len(page_ids):
            grp = page_ids[i:i + 2]
            mid = nid; nid += 1
            objs[mid] = (b'<</Type/Pages/Parent 2 0 R/Count %d/Kids[' % len(grp)
                         + b' '.join(b'%d 0 R' % p for p in grp) + b']>>')
            for p in grp:
                objs[p] = objs[p].replace(b'/Parent 2 0 R', b'/Parent %d 0 R' % mid)
            mids.append(mid)
            i += 2
        w, h = extra[0]
        objs[2] = (b'<</Type/Pages/Count %d/MediaBox[0 0 %d %d]/Resources %d 0 R/Kids['
                   % (len(page_ids), w, h, res_id)
                   + b' '.join(b'%d 0 R' % m for m in mids) + b']>>')
    else:
        objs[2] = (b'<</Type/Pages/Count %d/Kids[' % len(page_ids)
                   + b' '.join(b'%d 0 R' % p for p in page_ids) + b']>>')
    objs[1] = b'<</Type/Catalog/Pages 2 0 R>>'

    out = bytearray(b'%PDF-1.7\n%\xe2\xe3\xcf\xd3\n')
    offsets = {}
    for oid in sorted(objs):
        offsets[oid] = len(out)
        out += b'%d 0 obj' % oid + objs[oid] + b'endobj\n'
    size = max(objs) + 1
    xref = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % size
    for i in range(1, size):
        out += (b'%010d 00000 n \n' % offsets[i]) if i in offsets else b'0000000000 65535 f \n'
    out += b'trailer<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n' % (size, xref)
    return bytes(out)


# ──────────────────────────────── verificacoes ───────────────────────────────
FAIL = []


def check(cond, msg):
    if cond:
        print(f'  ok    {msg}')
    else:
        print(f'  FALHA {msg}')
        FAIL.append(msg)


def page_facts(data):
    """(texto, (largura, altura), n_imagens) de cada pagina, pelo MuPDF."""
    doc = fitz.open(stream=data, filetype='pdf')
    facts = []
    for p in doc:
        facts.append((p.get_text().strip(),
                      (round(p.rect.width), round(p.rect.height)),
                      len(p.get_images(full=True))))
    doc.close()
    return facts


def compare(label, produced, expected):
    try:
        got = page_facts(produced)
    except Exception as e:                              # noqa: BLE001
        check(False, f'{label}: MuPDF nao abriu o resultado ({e})')
        return
    check(len(got) == len(expected), f'{label}: {len(got)} paginas (esperado {len(expected)})')
    for i, (g, e) in enumerate(zip(got, expected), 1):
        check(g == e, f'{label}: pagina {i} {g} == {e}')


def main():
    a = build_pdf([('Alpha um', 612, 792), ('Alpha dois', 612, 792)])
    b = build_pdf([('Beta um', 595, 842), ('Beta dois', 595, 842),
                   ('Beta tres', 595, 842)], compress=True, indirect_length=True)
    c = build_pdf([('Gama %d' % i, 400, 600) for i in range(1, 6)],
                  nested=True, shared_image=True, compress=True)

    fa, fb, fc = page_facts(a), page_facts(b), page_facts(c)

    print('origens')
    check(len(fa) == 2 and len(fb) == 3 and len(fc) == 5,
          f'paginas nas origens: {len(fa)}/{len(fb)}/{len(fc)}')
    check(all(f[2] == 1 for f in fc), 'origem C tem imagem em todas as paginas')
    check(all(f[1] == (400, 600) for f in fc), 'origem C herda MediaBox da raiz')

    print('\nparser proprio (sem MuPDF)')
    for name, data, n in (('A', a, 2), ('B', b, 3), ('C', c, 5)):
        s = Source(data)
        check(len(s.pages) == n, f'origem {name}: {len(s.pages)} paginas na arvore')

    print('\nmerge A+B')
    compare('merge A+B', merge([a, b]), fa + fb)

    print('\nmerge C+A+B (arvore aninhada primeiro)')
    compare('merge C+A+B', merge([c, a, b]), fc + fa + fb)

    print('\nmerge do mesmo documento duas vezes')
    compare('merge C+C', merge([c, c]), fc + fc)

    print('\nextract')
    compare('extract C ALL', extract(c, 'ALL'), fc)
    compare('extract C 1,3,5', extract(c, '1,3,5'), [fc[0], fc[2], fc[4]])
    compare('extract C 2-4', extract(c, '2-4'), fc[1:4])
    compare('extract C 5,1', extract(c, '5,1'), [fc[4], fc[0]])
    compare('extract B 2', extract(b, '2'), [fb[1]])

    print('\nsplit')
    parts = split(c, ['1-2', '3', '4-5'])
    compare('split parte 1', parts[0], fc[0:2])
    compare('split parte 2', parts[1], [fc[2]])
    compare('split parte 3', parts[2], fc[3:5])

    print('\nfecho transitivo descarta objetos nao usados')
    full, one = len(c), len(extract(c, '1'))
    check(one < full, f'extract de 1 pagina ({one} B) menor que a origem ({full} B)')

    print('\nintervalos invalidos')
    for spec in ('0', '6', '3-2', 'x', ''):
        try:
            parse_pages(spec, 5)
            check(False, f'intervalo {spec!r} deveria falhar')
        except ValueError:
            check(True, f'intervalo {spec!r} rejeitado')

    print('\n' + ('TODOS OS TESTES PASSARAM' if not FAIL else
                  f'{len(FAIL)} FALHA(S):\n  ' + '\n  '.join(FAIL)))
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
