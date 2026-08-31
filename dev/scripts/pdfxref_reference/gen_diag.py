# -*- coding: utf-8 -*-
"""
Gera `tests/diag_xrefstm.sql` a partir dos mesmos construtores que a referência
valida.

Por que gerado
--------------
O diagnóstico precisa de doze PDFs embutidos em hexadecimal, e escrevê-los à
mão seria transcrição — o gênero de tarefa em que um dígito trocado produz um
teste que falha por motivo errado. Os arquivos saem de `validate.py`, que já os
confere contra o MuPDF; aqui eles só viram literal.

O que o diagnóstico prova, e a validação em Python não
------------------------------------------------------
A referência prova o algoritmo. Este arquivo prova a **porta**: que o PL/SQL
compila, que `pdf_src_load` lê as duas estruturas dentro do banco, e que o
copiador consegue montar um PDF a partir de objetos que não têm offset no
arquivo. São coisas diferentes, e o inflate já mostrou que a segunda pode falhar
com a primeira certa.

Uso:  python scripts/pdfxref_reference/gen_diag.py
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from validate import (monta_pdf_hibrido, monta_pdf_xrefstream,  # noqa: E402
                      pdf_com_objstm_bytes)

SAIDA = os.path.join(AQUI, '..', '..', 'tests', 'diag_xrefstm.sql')
TMP = os.path.join(AQUI, 'amostras')

CABECALHO = """\
--------------------------------------------------------------------------------
-- Diagnóstico: o package lê xref em stream e object streams (PDF 1.5+)?
--
-- Doze PDFs embutidos, cada um exercitando um pedaço do formato que o
-- `pdf_src_load` passou a entender. Todos foram conferidos contra o MuPDF em
-- `scripts/pdfxref_reference/validate.py` antes de virarem literal aqui, e este
-- arquivo é GERADO por `scripts/pdfxref_reference/gen_diag.py` — não edite à
-- mão.
--
-- O que cada caso prova, e por que não dá para provar com menos:
--
--   sem predictor ......... o caminho básico: /W, /Index, /Size, os tipos 0 e 1
--   predictor 12, 5 filtros o número no dicionário é só o padrão do compressor;
--                           quem manda é o byte no início de CADA linha
--   /W [1 2 1] ............ offset em dois bytes, não quatro
--   /W [0 4 1] ............ campo de largura zero vale o default, e o do TIPO
--                           é 1, não 0 — errar isso faz o arquivo inteiro virar
--                           "objetos livres" em silêncio
--   /Index com 3 faixas ... o que uma atualização incremental gera
--   híbrido /XRefStm ...... a tabela clássica marca a FONTE como livre; só a
--                           xref em stream ao lado a enxerga. A marca procurada
--                           é justamente '/Helvetica': se o /XRefStm for
--                           ignorado, a referência fica pendurada e NÃO dá erro
--   object streams ........ documento do MuPDF com use_objstms=1: Catalog,
--                           Pages e as páginas moram dentro de um /ObjStm, e
--                           não têm offset no arquivo. GetPageCount = 3 só sai
--                           se eles tiverem sido materializados
--   /Predictor 2 .......... o preditor TIFF, que precisa ser RECUSADO
--                           (ORA-20848) e não tratado como 1 — tratá-lo como 1
--                           devolveria offsets errados sem nenhum sinal
--
-- A verificação é sempre pelo ARQUIVO PRODUZIDO, não pelo "não deu erro": uma
-- xref lida errado não estoura, ela devolve outro objeto, com um dicionário
-- perfeitamente válido. Por isso cada caso procura uma marca que só existe se o
-- objeto certo tiver sido copiado.
--
-- Execute na SQL Window do PL/SQL Developer (F8).
--------------------------------------------------------------------------------

DECLARE
  l_ok  PLS_INTEGER := 0;
  l_mau PLS_INTEGER := 0;

  FUNCTION doc(p_hex VARCHAR2) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_b, TRUE);
    DBMS_LOB.WRITEAPPEND(l_b, LENGTH(p_hex) / 2, HEXTORAW(p_hex));
    RETURN l_b;
  END doc;

  --------------------------------------------------------------------------
  -- extrair: carrega, confere a contagem de páginas e extrai TUDO; a marca
  -- tem de aparecer no arquivo produzido.
  --------------------------------------------------------------------------
  PROCEDURE extrair(p_nome VARCHAR2, p_hex VARCHAR2, p_pags PLS_INTEGER,
                    p_marca VARCHAR2) IS
    l_pdf BLOB := doc(p_hex);
    l_out BLOB;
    l_n   PLS_INTEGER;
  BEGIN
    PL_FPDF.ClearPDFCache;
    PL_FPDF.LoadPDF(l_pdf);
    l_n := PL_FPDF.GetPageCount;
    IF l_n != p_pags THEN
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': ' || l_n
                           || ' pagina(s), esperado ' || p_pags);
      PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
      DBMS_LOB.FREETEMPORARY(l_pdf);
      RETURN;
    END IF;

    PL_FPDF.LoadPDFWithID('d', l_pdf);
    l_out := PL_FPDF.ExtractPages('d', 'ALL', NULL);
    IF DBMS_LOB.INSTR(l_out, UTL_RAW.CAST_TO_RAW(p_marca)) = 0 THEN
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': ' || p_pags
                           || ' pagina(s) OK, mas ' || p_marca
                           || ' nao esta no arquivo produzido ('
                           || NVL(DBMS_LOB.GETLENGTH(l_out), 0) || ' bytes)');
    ELSE
      l_ok := l_ok + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_nome || ': ' || p_pags
                           || ' pagina(s), ' || p_marca || ' no arquivo de '
                           || DBMS_LOB.GETLENGTH(l_out) || ' bytes');
    END IF;
    PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
    DBMS_LOB.FREETEMPORARY(l_pdf);
  EXCEPTION
    WHEN OTHERS THEN
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': ' || SQLERRM);
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END extrair;

  --------------------------------------------------------------------------
  -- sobrepor: o desenho é o que prova que a PÁGINA foi encontrada — e as
  -- páginas deste arquivo moram dentro de um object stream.
  --------------------------------------------------------------------------
  PROCEDURE sobrepor(p_nome VARCHAR2, p_hex VARCHAR2, p_pags PLS_INTEGER,
                     p_pag PLS_INTEGER, p_carimbo VARCHAR2) IS
    l_pdf BLOB := doc(p_hex);
    l_out BLOB;
    l_n   PLS_INTEGER;
  BEGIN
    PL_FPDF.ClearPDFCache;
    PL_FPDF.LoadPDF(l_pdf);
    l_n := PL_FPDF.GetPageCount;
    IF l_n != p_pags THEN
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': ' || l_n
                           || ' pagina(s), esperado ' || p_pags);
      PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
      DBMS_LOB.FREETEMPORARY(l_pdf);
      RETURN;
    END IF;

    PL_FPDF.OverlayText(p_page_number => p_pag, p_text => p_carimbo,
                        p_x => 72, p_y => 400);
    l_out := PL_FPDF.OutputModifiedPDF();
    IF DBMS_LOB.INSTR(l_out, UTL_RAW.CAST_TO_RAW(p_carimbo)) = 0 THEN
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome
                           || ': o carimbo nao saiu no arquivo produzido');
    ELSE
      l_ok := l_ok + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_nome || ': ' || p_pags
                           || ' pagina(s) lidas de dentro do object stream, '
                           || 'carimbo na ' || p_pag || ', arquivo de '
                           || DBMS_LOB.GETLENGTH(l_out) || ' bytes');
    END IF;
    PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
    DBMS_LOB.FREETEMPORARY(l_pdf);
  EXCEPTION
    WHEN OTHERS THEN
      l_mau := l_mau + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': ' || SQLERRM);
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END sobrepor;

  --------------------------------------------------------------------------
  -- recusar: entregar errado custa mais caro que uma exceção. Aqui a exceção
  -- CERTA é o resultado esperado.
  --------------------------------------------------------------------------
  PROCEDURE recusar(p_nome VARCHAR2, p_hex VARCHAR2, p_codigo PLS_INTEGER) IS
    l_pdf BLOB := doc(p_hex);
  BEGIN
    PL_FPDF.ClearPDFCache;
    PL_FPDF.LoadPDF(l_pdf);
    l_mau := l_mau + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': aceitou, esperado ORA'
                         || p_codigo);
    PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
    DBMS_LOB.FREETEMPORARY(l_pdf);
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = p_codigo THEN
        l_ok := l_ok + 1;
        DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_nome || ': recusado com ORA'
                             || p_codigo);
      ELSE
        l_mau := l_mau + 1;
        DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_nome || ': esperado ORA'
                             || p_codigo || ', veio ' || SQLERRM);
      END IF;
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END recusar;

BEGIN
  DBMS_OUTPUT.PUT_LINE('==== xref em stream e object streams (PDF 1.5+) ====');
"""

RODAPE = """
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(l_ok || ' passou | ' || l_mau || ' falhou');
END;
/
"""


def bloco_hex(dados):
    hexa = dados.hex().upper()
    partes = [hexa[i:i + 70] for i in range(0, len(hexa), 70)]
    saida = "    '%s'" % partes[0]
    for p in partes[1:]:
        saida += "\n    || '%s'" % p
    return saida


def main():
    if not os.path.isdir(TMP):
        os.makedirs(TMP)

    casos = []                      # (chamada, nome, args extras, bytes)

    p = os.path.join(TMP, 'diag_sem_pred.pdf')
    monta_pdf_xrefstream(p)
    casos.append(('extrair', 'sem predictor', "1, '(xref em stream)'",
                  open(p, 'rb').read()))

    for f, nome in ((0, 'None'), (1, 'Sub'), (2, 'Up'), (3, 'Average'),
                    (4, 'Paeth')):
        p = os.path.join(TMP, 'diag_pred%d.pdf' % f)
        monta_pdf_xrefstream(p, predictor=12, filtro=f)
        casos.append(('extrair', 'predictor 12, filtro ' + nome,
                      "1, '(xref em stream)'", open(p, 'rb').read()))

    p = os.path.join(TMP, 'diag_w121.pdf')
    monta_pdf_xrefstream(p, w=(1, 2, 1))
    casos.append(('extrair', '/W [1 2 1]', "1, '(xref em stream)'",
                  open(p, 'rb').read()))

    p = os.path.join(TMP, 'diag_w041.pdf')
    monta_pdf_xrefstream(p, w=(0, 4, 1), indices=[(1, 6)])
    casos.append(('extrair', '/W [0 4 1] (tipo ausente vale 1)',
                  "1, '(xref em stream)'", open(p, 'rb').read()))

    p = os.path.join(TMP, 'diag_faixas.pdf')
    monta_pdf_xrefstream(p, indices=[(0, 1), (1, 3), (4, 3)])
    casos.append(('extrair', '/Index com tres faixas',
                  "1, '(xref em stream)'", open(p, 'rb').read()))

    p = os.path.join(TMP, 'diag_hibrido.pdf')
    monta_pdf_hibrido(p)
    casos.append(('extrair', 'hibrido /XRefStm (a fonte so existe nele)',
                  "1, '/Helvetica'", open(p, 'rb').read()))

    casos.append(('sobrepor', 'object streams do MuPDF',
                  "3, 2, 'Carimbo na 2'",
                  pdf_com_objstm_bytes(['objstm um', 'objstm dois',
                                        'objstm tres'])))

    # /Predictor 2 é o preditor TIFF. A troca é feita no dicionário do objeto,
    # que não é comprimido, e com o MESMO número de bytes — assim nenhum offset
    # do arquivo se desloca e o único que muda é o que se quer testar.
    p = os.path.join(TMP, 'diag_pred12.pdf')
    monta_pdf_xrefstream(p, predictor=12, filtro=2)
    bruto = open(p, 'rb').read()
    assert bruto.count(b'/Predictor 12') == 1
    casos.append(('recusar', '/Predictor 2 (TIFF) recusado', '-20848',
                  bruto.replace(b'/Predictor 12', b'/Predictor 2 ')))

    corpo = []
    for chamada, nome, extra, dados in casos:
        corpo.append('\n  %s(%s,\n%s,\n    %s);'
                     % (chamada, "'%s'" % nome, bloco_hex(dados), extra))

    io_out = CABECALHO + ''.join(corpo) + RODAPE
    with open(SAIDA, 'w', encoding='utf-8') as fh:
        fh.write(io_out)
    print('%s: %d casos, %d linhas'
          % (os.path.normpath(SAIDA), len(casos), io_out.count('\n') + 1))


if __name__ == '__main__':
    main()
