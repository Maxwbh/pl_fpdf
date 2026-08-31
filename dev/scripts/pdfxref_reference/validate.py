# -*- coding: utf-8 -*-
"""
Valida a referência da xref em stream contra o MuPDF.

O MuPDF é o oráculo, em dois níveis:

  1. **Ele abre o arquivo.** Se um PDF construído à mão aqui não abrir no
     MuPDF, o teste não vale nada — estaria validando a leitura de um arquivo
     que não é um PDF.
  2. **Ele diz o que cada objeto é.** Para cada objeto do documento, o corpo
     que esta referência devolve tem de bater, chave a chave, com o que o
     `xref_object` do MuPDF devolve. É a comparação que pega o erro que
     interessa: uma xref lida errado não estoura — ela devolve um offset
     plausível, e o objeto que sai de lá é *outro objeto*, com um dicionário
     perfeitamente válido.

O que um corpus ingênuo deixaria de fora, e que este arquivo cobre de propósito:

  - **O predictor.** O MuPDF grava xref em stream *sem* predictor; Acrobat,
    Ghostscript e as bibliotecas em geral gravam com `/Predictor 12`. Testar só
    com o que o MuPDF gera deixaria justamente o caso comum sem cobertura, e o
    predictor errado não quebra: devolve offsets limpos e falsos. Por isso há
    aqui um construtor de xref em stream com predictor, e o MuPDF é chamado
    para abrir o resultado.
  - **Os cinco filtros do PNG.** O número no dicionário (12) é só o padrão do
    compressor; quem manda é o byte no início de cada linha. Um arquivo pode
    trazer os cinco.
  - **`/W` com campo de largura zero.** `/W [0 4 2]` significa "todo objeto é
    do tipo 1" — o default do campo de tipo é 1, não 0. Errar isso faz o
    arquivo inteiro virar objetos livres, em silêncio.
  - **`/Index` com várias faixas**, que é o que uma atualização incremental
    gera.
  - **Híbrido (`/XRefStm`)**, onde a tabela clássica é uma fachada e os objetos
    de verdade estão na xref em stream ao lado.

Uso:  python scripts/pdfxref_reference/validate.py
"""
import os
import re
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pdfxref_reference import (ErroXref, Entrada, corpo, corpo_do_objeto,  # noqa: E402
                               desfazer_predictor, dict_value, indexar,
                               ler_object_stream, ler_xref_stream)

try:
    import pymupdf
except ImportError:                                    # nome antigo
    import fitz as pymupdf

FALHAS = []


def check(cond, msg):
    print(('  ok    ' if cond else '  FALHA ') + msg)
    if not cond:
        FALHAS.append(msg)


# ─────────────────────────── comparação com o MuPDF ──────────────────────────

def normalizar(txt):
    """Texto de objeto em tokens comparáveis entre implementações.

    O MuPDF reescreve o objeto ao imprimi-lo: espaço a mais, espaço a menos,
    `/Type/Page` colado. Comparar byte a byte acusaria diferença em todo objeto;
    comparar tokens acusa só o que importa.
    """
    if isinstance(txt, bytes):
        txt = txt.decode('latin-1')
    txt = re.sub(r'(<<|>>|\[|\]|/)', r' \1 ', txt)
    return ' '.join(txt.split())


def chaves(dic):
    """{chave: valor normalizado} do dicionário de nível mais alto."""
    if isinstance(dic, str):
        dic = dic.encode('latin-1')
    i = dic.find(b'<<')
    if i < 0:
        return None
    out, p = {}, i + 2
    prof = 1
    while p < len(dic) and prof > 0:
        c = dic[p:p + 1]
        if dic[p:p + 2] == b'<<':
            prof += 1
            p += 2
        elif dic[p:p + 2] == b'>>':
            prof -= 1
            p += 2
        elif c == b'/' and prof == 1:
            k = p + 1
            while k < len(dic) and dic[k:k + 1] not in b' \t\r\n/[]<>()':
                k += 1
            nome = dic[p:k]
            val = dict_value(dic[i:], nome)
            out[nome.decode('latin-1')] = normalizar(val or b'')
            p = k
        else:
            p += 1
    return out


def confere_documento(caminho, rotulo):
    """Todo objeto do documento tem de bater com o que o MuPDF vê."""
    doc = open(caminho, 'rb').read()
    d = pymupdf.open(caminho)
    try:
        idx = indexar(doc)
    except ErroXref as e:
        check(False, '%s: indexar levantou %s' % (rotulo, e))
        return None

    divergencias = []
    conferidos = 0
    for oid in range(1, d.xref_length()):
        if not d.xref_is_stream(oid) and d.xref_object(oid) == 'null':
            continue                              # objeto livre
        try:
            nosso = corpo(doc, idx, oid)
        except ErroXref as e:
            divergencias.append('obj %d: %s' % (oid, e))
            continue
        deles = d.xref_object(oid, compressed=True)
        a, b = chaves(nosso), chaves(deles)
        if a is None or b is None:                # não é dicionário
            if normalizar(nosso) != normalizar(deles):
                divergencias.append('obj %d: %r != %r'
                                    % (oid, normalizar(nosso)[:60],
                                       normalizar(deles)[:60]))
        else:
            # /Length pode ser indireto num e resolvido no outro; o MuPDF
            # também normaliza /Filter de array para nome. Nem um nem outro é
            # divergência de leitura da xref.
            for k in set(a) | set(b):
                if k in ('/Length', '/Filter', '/DecodeParms'):
                    continue
                if a.get(k) != b.get(k):
                    divergencias.append('obj %d %s: %r != %r'
                                        % (oid, k, a.get(k), b.get(k)))
        conferidos += 1

    d.close()
    check(not divergencias,
          '%s: %d objeto(s) conferem com o MuPDF%s'
          % (rotulo, conferidos,
             '' if not divergencias else ' — ' + '; '.join(divergencias[:3])))
    return idx


# ──────────────────────── construtores de PDF de teste ───────────────────────

def aplica_uma_linha(cur, ant, filtro):
    """Codifica uma linha com um dos cinco filtros do PNG (bpp = 1)."""
    n = len(cur)
    saida = bytearray(n)
    for i in range(n):
        esq = cur[i - 1] if i >= 1 else 0
        cima = ant[i]
        diag = ant[i - 1] if i >= 1 else 0
        if filtro == 0:
            pred = 0
        elif filtro == 1:
            pred = esq
        elif filtro == 2:
            pred = cima
        elif filtro == 3:
            pred = (esq + cima) >> 1
        else:
            pp = esq + cima - diag
            pa, pb, pc = abs(pp - esq), abs(pp - cima), abs(pp - diag)
            pred = esq if (pa <= pb and pa <= pc) else (cima if pb <= pc else diag)
        saida[i] = (cur[i] - pred) & 0xFF
    return bytes([filtro]) + bytes(saida)


def aplica_predictor(dados, colunas, filtro):
    """Aplica o filtro PNG dado a todas as linhas (o inverso do que se testa)."""
    ant = bytearray(colunas)
    out = bytearray()
    for p in range(0, len(dados), colunas):
        cur = bytearray(dados[p:p + colunas])
        out += aplica_uma_linha(cur, ant, filtro)
        ant = cur
    return bytes(out)


def monta_pdf_xrefstream(caminho, predictor=None, filtro=2, w=(1, 4, 2),
                         indices=None):
    """PDF mínimo cuja única referência cruzada é uma xref em stream.

    Construído à mão de propósito: é a única forma de escolher o `/W`, o
    `/Index` e o predictor, que é justamente o que o MuPDF nunca gera.
    """
    objs = {
        1: b'<< /Type /Catalog /Pages 2 0 R >>',
        2: b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        3: b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] '
           b'/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
        5: b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    }
    fluxo = b'BT /F1 12 Tf 20 40 Td (xref em stream) Tj ET'

    buf = bytearray(b'%PDF-1.5\n%\xe2\xe3\xcf\xd3\n')
    offs = {}
    for oid in sorted(objs):
        offs[oid] = len(buf)
        buf += b'%d 0 obj\n' % oid + objs[oid] + b'\nendobj\n'
    offs[4] = len(buf)
    buf += (b'4 0 obj\n<< /Length %d >>\nstream\n' % len(fluxo) + fluxo
            + b'\nendstream\nendobj\n')

    size = 7                                   # 0..6, sendo 6 a própria xref
    offs[6] = len(buf)

    def campo(v, larg):
        return v.to_bytes(larg, 'big') if larg else b''

    faixas = indices or [(0, size)]
    linhas = bytearray()
    for inicio, quantos in faixas:
        for oid in range(inicio, inicio + quantos):
            if oid == 0:
                t, a, b = 0, 0, 0            # livre; a geracao nao e lida
            else:
                t, a, b = 1, offs[oid], 0
            if w[0] == 0 and t != 1:
                continue                        # /W [0 ...] só cabe tipo 1
            linhas += campo(t, w[0]) + campo(a, w[1]) + campo(b, w[2])

    largura = sum(w)
    if predictor:
        dados = zlib.compress(aplica_predictor(bytes(linhas), largura, filtro))
        parms = (b' /DecodeParms << /Predictor %d /Colors 1 '
                 b'/BitsPerComponent 8 /Columns %d >>' % (predictor, largura))
    else:
        dados = zlib.compress(bytes(linhas))
        parms = b''

    ind = b' /Index [' + b' '.join(b'%d %d' % f for f in faixas) + b']'
    dic = (b'<< /Type /XRef /Size %d /W [%d %d %d]%s /Root 1 0 R '
           b'/Filter /FlateDecode%s /Length %d >>'
           % (size, w[0], w[1], w[2], ind, parms, len(dados)))
    buf += (b'6 0 obj\n' + dic + b'\nstream\n' + dados
            + b'\nendstream\nendobj\n')
    buf += b'startxref\n%d\n%%%%EOF\n' % offs[6]
    open(caminho, 'wb').write(bytes(buf))
    return offs


def pdf_com_objstm_bytes(textos):
    """PDF com object streams e xref em stream, gravado pelo próprio MuPDF.

    Fica aqui, e não em quem usa, porque é o mesmo arquivo em três lugares: a
    validação desta referência, a amostra do `run_tests.py` e o diagnóstico
    `tests/diag_xrefstm.sql`. Três cópias do construtor seriam três chances de
    testar coisas sutilmente diferentes.

    O `/ID` é normalizado para que o arquivo saia **igual a cada chamada**. O
    MuPDF gera um `/ID` novo toda vez, e um fixture que muda sozinho tem dois
    problemas: a falha deixa de ser reproduzível, e o runner progressivo,
    que decide o que pular pela impressão digital das entradas da etapa, nunca
    consegue pular esta amostra — a impressão mudava sem que nada da definição
    tivesse mudado.

    A troca preserva o COMPRIMENTO dos dois hexadecimais, senão todos os
    offsets depois deles saem do lugar e a xref em stream passa a apontar para
    o vazio.
    """
    d = pymupdf.open()
    for i, t in enumerate(textos):
        pg = d.new_page()
        pg.insert_text((72, 100 + 20 * i), t, fontsize=16)
    dados = d.tobytes(use_objstms=1, deflate=True, garbage=4)
    d.close()
    return re.sub(rb'<([0-9A-Fa-f]{4,})>',
                  lambda m: b'<' + (b'AB' * len(m.group(1)))[:len(m.group(1))]
                            + b'>',
                  dados)


def monta_pdf_hibrido(caminho):
    """Tabela clássica cujo trailer aponta, via /XRefStm, para a xref real.

    O objeto 5 (a fonte) existe SÓ na xref em stream: a tabela clássica o marca
    como livre. Um leitor que ignore o /XRefStm perde a fonte e não percebe.
    """
    objs = {
        1: b'<< /Type /Catalog /Pages 2 0 R >>',
        2: b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        3: b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] '
           b'/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
        5: b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    }
    fluxo = b'BT /F1 12 Tf 20 40 Td (hibrido) Tj ET'

    buf = bytearray(b'%PDF-1.5\n%\xe2\xe3\xcf\xd3\n')
    offs = {}
    for oid in sorted(objs):
        offs[oid] = len(buf)
        buf += b'%d 0 obj\n' % oid + objs[oid] + b'\nendobj\n'
    offs[4] = len(buf)
    buf += (b'4 0 obj\n<< /Length %d >>\nstream\n' % len(fluxo) + fluxo
            + b'\nendstream\nendobj\n')

    # a xref em stream, com TODOS os objetos
    offs[6] = len(buf)
    linhas = bytearray()
    for oid in range(0, 7):
        if oid == 0:
            linhas += bytes([0]) + (0).to_bytes(4, 'big') + (65535).to_bytes(2, 'big')
        else:
            linhas += bytes([1]) + offs[oid].to_bytes(4, 'big') + (0).to_bytes(2, 'big')
    dados = zlib.compress(bytes(linhas))
    buf += (b'6 0 obj\n<< /Type /XRef /Size 7 /W [1 4 2] /Root 1 0 R '
            b'/Filter /FlateDecode /Length %d >>\nstream\n' % len(dados)
            + dados + b'\nendstream\nendobj\n')

    # a tabela clássica: o objeto 5 aparece como LIVRE
    tab = len(buf)
    linhas_t = [b'0000000000 65535 f \n']
    for oid in range(1, 7):
        if oid == 5:
            linhas_t.append(b'0000000000 65535 f \n')
        else:
            linhas_t.append(b'%010d 00000 n \n' % offs[oid])
    buf += b'xref\n0 7\n' + b''.join(linhas_t)
    buf += (b'trailer\n<< /Size 7 /Root 1 0 R /XRefStm %d >>\n' % offs[6])
    buf += b'startxref\n%d\n%%%%EOF\n' % tab
    open(caminho, 'wb').write(bytes(buf))
    return offs


# ─────────────────────────────────── testes ──────────────────────────────────

def main():
    aqui = os.path.dirname(os.path.abspath(__file__))
    tmp = os.path.join(aqui, 'amostras')
    if not os.path.isdir(tmp):
        os.makedirs(tmp)

    print('== predictor PNG: os cinco filtros ==')
    dados = bytes((i * 37 + (i // 7) * 11) % 256 for i in range(6 * 8))
    for f in range(5):
        cod = aplica_predictor(dados, 8, f)
        check(desfazer_predictor(cod, 12, 1, 8, 8) == dados,
              'filtro %d desfeito byte a byte' % f)
    # Cada linha com um filtro diferente — o dicionário diz 12 e o stream usa os
    # cinco. É o caso que uma implementação "só o filtro 2, que é o do /Predictor
    # 12" atravessa sem reclamar e decodifica errado.
    misto = bytearray()
    ant = bytearray(8)
    for lin in range(6):
        cur = dados[lin * 8:(lin + 1) * 8]
        f = lin % 5
        misto += aplica_uma_linha(cur, ant, f)
        ant = bytearray(cur)
    check(desfazer_predictor(bytes(misto), 12, 1, 8, 8) == dados,
          'linhas com filtros diferentes no mesmo stream')
    check(desfazer_predictor(dados, 1, 1, 8, 8) == dados,
          'predictor 1 e identidade')
    check(desfazer_predictor(dados, None, 1, 8, 8) == dados,
          'predictor ausente e identidade')

    print('== recusas ==')
    for f, msg in ((lambda: desfazer_predictor(dados, 2, 1, 8, 8),
                    'predictor 2 (TIFF) e recusado, nao tratado como 1'),
                   (lambda: desfazer_predictor(dados[:-1], 12, 1, 8, 8),
                    'dados que nao dividem pela linha sao recusados'),
                   (lambda: ler_xref_stream(b'<< /W [0 0 0] /Size 3 >>', b''),
                    '/W todo zerado e recusado'),
                   (lambda: ler_xref_stream(b'<< /W [1 2 1] /Size 3 >>', b'\x01\x00'),
                    'stream mais curto que o /W e recusado'),
                   (lambda: ler_object_stream(b'<< /Type /ObjStm /First 4 >>', b'1 0 '),
                    'object stream sem /N e recusado')):
        try:
            f()
            check(False, msg)
        except ErroXref:
            check(True, msg)

    print('== xref em stream construida a mao ==')
    p = os.path.join(tmp, 'xrefstm.pdf')
    offs = monta_pdf_xrefstream(p)
    d = pymupdf.open(p)
    check(d.page_count == 1 and 'xref em stream' in d[0].get_text(),
          'o MuPDF abre e le o texto do arquivo montado aqui')
    d.close()
    idx = indexar(open(p, 'rb').read())
    check(all(idx.xref[o] == Entrada(1, offs[o], 0) for o in offs),
          'offsets lidos batem com os que o construtor gravou')
    check(idx.root == 1, '/Root vem do dicionario da propria xref em stream')
    confere_documento(p, 'xrefstm')

    print('== o mesmo arquivo com /Predictor 12 ==')
    for filtro, nome in ((0, 'None'), (1, 'Sub'), (2, 'Up'), (3, 'Average'),
                         (4, 'Paeth')):
        pp = os.path.join(tmp, 'pred%d.pdf' % filtro)
        offs = monta_pdf_xrefstream(pp, predictor=12, filtro=filtro)
        d = pymupdf.open(pp)
        ok_mupdf = d.page_count == 1 and 'xref em stream' in d[0].get_text()
        d.close()
        idx = indexar(open(pp, 'rb').read())
        check(ok_mupdf and all(idx.xref[o] == Entrada(1, offs[o], 0)
                               for o in offs),
              'predictor 12 / filtro %s: MuPDF abre e os offsets conferem'
              % nome)

    print('== variacoes de /W e /Index ==')
    p = os.path.join(tmp, 'w121.pdf')
    offs = monta_pdf_xrefstream(p, w=(1, 2, 1))
    idx = indexar(open(p, 'rb').read())
    check(all(idx.xref[o] == Entrada(1, offs[o], 0) for o in offs),
          '/W [1 2 1]: offset em dois bytes')
    p = os.path.join(tmp, 'w041.pdf')
    offs = monta_pdf_xrefstream(p, w=(0, 4, 1), indices=[(1, 6)])
    idx = indexar(open(p, 'rb').read())
    check(all(idx.xref[o] == Entrada(1, offs[o], 0) for o in offs),
          '/W [0 4 1]: campo de tipo ausente vale 1, nao 0')
    p = os.path.join(tmp, 'faixas.pdf')
    offs = monta_pdf_xrefstream(p, indices=[(0, 1), (1, 3), (4, 3)])
    idx = indexar(open(p, 'rb').read())
    check(all(idx.xref[o] == Entrada(1, offs[o], 0) for o in offs),
          '/Index com tres faixas')

    print('== hibrido: tabela classica + /XRefStm ==')
    p = os.path.join(tmp, 'hibrido.pdf')
    offs = monta_pdf_hibrido(p)
    d = pymupdf.open(p)
    check(d.page_count == 1 and 'hibrido' in d[0].get_text(),
          'o MuPDF abre o hibrido')
    d.close()
    idx = indexar(open(p, 'rb').read())
    check(5 in idx.xref and idx.xref[5] == Entrada(1, offs[5], 0),
          'o objeto que so existe no /XRefStm foi encontrado')

    print('== documento do MuPDF com object streams ==')
    p = os.path.join(tmp, 'objstm.pdf')
    d = pymupdf.open()
    for i, txt in enumerate(('primeira pagina', 'segunda pagina',
                             'terceira pagina')):
        pg = d.new_page()
        pg.insert_text((72, 72 + 20 * i), txt)
    d.save(p, use_objstms=1, deflate=True, garbage=4)
    d.close()
    bruto = open(p, 'rb').read()
    check(b'/ObjStm' in bruto and b'/XRef' in bruto,
          'o MuPDF gravou object stream e xref em stream')
    idx = indexar(bruto)
    tipo2 = [o for o, e in idx.xref.items() if e.tipo == 2]
    check(len(tipo2) >= 3,
          '%d objeto(s) morando dentro de object stream' % len(tipo2))
    check(all(o in idx.corpos for o in tipo2),
          'todo objeto do tipo 2 tem corpo materializado')
    confere_documento(p, 'objstm')

    print('== documento grande, para exercitar o encadeamento ==')
    p = os.path.join(tmp, 'grande.pdf')
    d = pymupdf.open()
    for i in range(40):
        pg = d.new_page()
        pg.insert_text((72, 72), 'pagina %d' % i)
    d.save(p, use_objstms=1, deflate=True, garbage=4)
    d.close()
    idx = confere_documento(p, 'grande')
    if idx:
        check(len(idx.corpos) > 40,
              '%d objetos materializados de object stream' % len(idx.corpos))

    print('== atualizacao incremental (cadeia /Prev) ==')
    p = os.path.join(tmp, 'incremental.pdf')
    d = pymupdf.open()
    d.new_page().insert_text((72, 72), 'original')
    d.save(p, use_objstms=1)
    d.close()
    d = pymupdf.open(p)
    d[0].insert_text((72, 100), 'acrescentado')
    d.save(p, incremental=True, encryption=pymupdf.PDF_ENCRYPT_KEEP)
    d.close()
    bruto = open(p, 'rb').read()
    idx = indexar(bruto)
    check(len(idx.secoes) >= 2,
          '%d secoes de xref percorridas pela cadeia /Prev' % len(idx.secoes))
    confere_documento(p, 'incremental')

    print('== o oraculo morde? (mutacao deliberada) ==')
    # Um teste que passa com a implementação certa não prova nada se também
    # passasse com a errada. Aqui a xref é estragada de propósito, das duas
    # formas que um erro de leitura produziria — offset deslocado e tipo trocado
    # — e o que se verifica é que a comparação com o MuPDF ACUSA.
    bruto = open(os.path.join(tmp, 'objstm.pdf'), 'rb').read()
    idx = indexar(bruto)
    alvo = min(o for o, e in idx.xref.items() if e.tipo == 1 and o > 0)
    guardado = idx.xref[alvo]
    idx.xref[alvo] = Entrada(1, guardado.a + 1, guardado.b)
    try:
        mudou = normalizar(corpo(bruto, idx, alvo)) != normalizar(
            pymupdf.open(os.path.join(tmp, 'objstm.pdf')).xref_object(alvo))
    except (ErroXref, ValueError, IndexError):
        mudou = True
    check(mudou, 'offset deslocado de um byte produz corpo diferente do MuPDF')
    idx.xref[alvo] = guardado

    dic = b'<< /Type /XRef /Size 3 /W [1 4 2] /Index [0 3] >>'
    linhas = (bytes([1]) + (10).to_bytes(4, 'big') + (0).to_bytes(2, 'big')) * 3
    certo = ler_xref_stream(dic, linhas)
    torto = ler_xref_stream(b'<< /Type /XRef /Size 3 /W [1 2 4] /Index [0 3] >>',
                            linhas)
    check(certo != torto, '/W trocado de [1 4 2] para [1 2 4] muda o resultado')

    print('== xref classica continua funcionando ==')
    p = os.path.join(tmp, 'classica.pdf')
    d = pymupdf.open()
    d.new_page().insert_text((72, 72), 'classica')
    d.save(p, use_objstms=0, deflate=False)
    d.close()
    idx = indexar(open(p, 'rb').read())
    check(idx.secoes and idx.secoes[0][0] == 'tabela',
          'a secao foi lida como tabela classica')
    check(not idx.corpos, 'nenhum object stream num arquivo classico')
    confere_documento(p, 'classica')

    print('')
    if FALHAS:
        print('%d falha(s):' % len(FALHAS))
        for f in FALHAS:
            print('  - ' + f)
        return 1
    print('tudo certo')
    return 0


if __name__ == '__main__':
    sys.exit(main())
