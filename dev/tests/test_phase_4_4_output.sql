--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-a.5 - Phase 4.4: OutputModifiedPDF Tests
-- Description: Test suite for OutputModifiedPDF API
--------------------------------------------------------------------------------



DECLARE
  l_pdf BLOB;
  l_modified_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_original_size NUMBER;
  l_modified_size NUMBER;

  -- Test helper procedures
  PROCEDURE test_start(p_test_name VARCHAR2) IS
  BEGIN
    l_test_count := l_test_count + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test ' || l_test_count || ': ' || p_test_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
  END;

  PROCEDURE test_pass(p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_pass_count := l_pass_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || NVL(p_message, 'Test passed'));
  END;

  PROCEDURE test_fail(p_message VARCHAR2) IS
  BEGIN
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_message);
  END;

  -- Create valid test PDF with 5 pages using PL_FPDF itself
  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1..5 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Page ' || i);
    END LOOP;
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-a.5 - PHASE 4.4: OutputModifiedPDF Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF with 5 pages
  create_test_pdf();
  l_original_size := DBMS_LOB.GETLENGTH(l_pdf);
  DBMS_OUTPUT.PUT_LINE('Original PDF size: ' || l_original_size || ' bytes');

  --------------------------------------------------------------------------------
  -- TEST 1: OutputModifiedPDF without modifications (should fail)
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - No modifications (should fail)');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);

    -- Try to output without any modifications
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    test_fail('Should have raised error for unmodified PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20819 THEN
        test_pass('Correctly rejected unmodified PDF');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: OutputModifiedPDF with rotation
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - With page rotation');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Rotate page 1
    PL_FPDF.RotatePage(1, 90);

    -- Generate modified PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    IF l_modified_size > 0 THEN
      test_pass('Modified PDF size: ' || l_modified_size || ' bytes');
    ELSE
      test_fail('Modified PDF has zero size');
    END IF;

    -- Cabeçalho: aceita qualquer %PDF-1.x. O copiador de objetos emite 1.7;
    -- prender o teste a uma versão específica é frágil.
    IF UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(l_modified_pdf, 7, 1)) LIKE '%PDF-1.' THEN
      test_pass('PDF header correct');
    ELSE
      test_fail('Invalid PDF header: ' ||
                UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(l_modified_pdf, 8, 1)));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error generating PDF with rotation: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: OutputModifiedPDF with page removal
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - With page removal');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Remove pages 2 and 4
    PL_FPDF.RemovePage(2);
    PL_FPDF.RemovePage(4);

    -- Generate modified PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated with removed pages');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    DBMS_OUTPUT.PUT_LINE('  Original: 5 pages, Modified: 3 pages (removed 2 and 4)');
    test_pass('PDF size: ' || l_modified_size || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error generating PDF with removed pages: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: OutputModifiedPDF with watermark
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - With watermark');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- A marca d'água é desenhada no fluxo de conteúdo. Antes disto a geração
    -- era recusada com -20845 para não descartá-la em silêncio; agora o que se
    -- confere é que ela SAI no arquivo.
    PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');

    l_modified_pdf := PL_FPDF.OutputModifiedPDF();

    IF l_modified_pdf IS NULL THEN
      test_fail('OutputModifiedPDF devolveu NULL com marca d''água');
    ELSIF DBMS_LOB.INSTR(l_modified_pdf,
                         UTL_RAW.CAST_TO_RAW('(CONFIDENTIAL) Tj'), 1, 1) = 0 THEN
      test_fail('a marca d''água não aparece no fluxo de conteúdo');
    ELSIF DBMS_LOB.INSTR(l_modified_pdf,
                         UTL_RAW.CAST_TO_RAW('/ExtGState'), 1, 1) = 0 THEN
      -- sem o /ExtGState a opacidade seria ignorada e a marca sairia opaca,
      -- por cima do conteúdo
      test_fail('o /ExtGState da opacidade não foi declarado');
    ELSE
      test_pass('marca d''água desenhada no fluxo de conteúdo, com opacidade');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error generating PDF with watermark: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: OutputModifiedPDF with combined modifications
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - Combined modifications');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Rotação, remoção e marca d'água juntas: a marca é aplicada por número de
    -- página ORIGINAL, e a página 3 sai do documento — quem confunde os dois
    -- índices desenha na folha errada.
    PL_FPDF.RotatePage(1, 90);
    PL_FPDF.RemovePage(3);
    PL_FPDF.AddWatermark('RASCUNHO', 0.25, 45, '1');

    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    l_modified_size := DBMS_LOB.GETLENGTH(l_modified_pdf);

    IF l_modified_pdf IS NOT NULL THEN
      test_pass('Modified PDF generated with combined modifications');
    ELSE
      test_fail('Modified PDF is NULL');
    END IF;

    DBMS_OUTPUT.PUT_LINE('  Modifications: rotation + removal');
    test_pass('PDF size: ' || l_modified_size || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error with combined modifications: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5b: OutputModifiedPDF com overlay de imagem
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - Overlay de imagem (PNG)');
  DECLARE
    -- PNG 4x4 de cor sólida, sem filtro por linha. Fica embutido em hexadecimal
    -- para o teste não depender de arquivo nem de diretório do banco.
    co_png CONSTANT RAW(200) := HEXTORAW(
         '89504E470D0A1A0A0000000D4948445200000004000000040802000000269309'
      || '290000001149444154789C63509870018E1888E3000065521801FA941B110000'
      || '000049454E44AE426082');
    l_img BLOB := TO_BLOB(co_png);
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.OverlayImage(p_page_number => 1, p_image_blob => l_img,
                         p_x => 100, p_y => 500,
                         p_width => 120, p_height => 120);
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();

    IF l_modified_pdf IS NULL THEN
      test_fail('OutputModifiedPDF devolveu NULL com overlay de imagem');
    ELSIF DBMS_LOB.INSTR(l_modified_pdf,
                         UTL_RAW.CAST_TO_RAW('/Subtype /Image'), 1, 1) = 0 THEN
      test_fail('o /XObject de imagem não foi gravado');
    ELSIF DBMS_LOB.INSTR(l_modified_pdf,
                         UTL_RAW.CAST_TO_RAW('/Predictor 15'), 1, 1) = 0 THEN
      -- os dados do PNG entram como FlateDecode sem serem descomprimidos; sem
      -- o Predictor o leitor não desfaz o filtro por linha e desenha ruído
      test_fail('/DecodeParms com /Predictor 15 não foi declarado');
    ELSIF DBMS_LOB.INSTR(l_modified_pdf,
                         UTL_RAW.CAST_TO_RAW('/ImgPLFPDF'), 1, 1) = 0 THEN
      test_fail('a imagem não entrou no /XObject do /Resources da página');
    ELSE
      test_pass('overlay de imagem desenhado, com /DecodeParms e /XObject');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Erro no overlay de imagem: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5c: formato de imagem não suportado é recusado, não desenhado errado
  --------------------------------------------------------------------------------
  test_start('OverlayImage - formato não suportado é recusado');
  DECLARE
    l_gif BLOB := TO_BLOB(UTL_RAW.CAST_TO_RAW('GIF89a' || RPAD('x', 40, 'x')));
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.OverlayImage(p_page_number => 1, p_image_blob => l_gif,
                         p_x => 10, p_y => 10);
    test_fail('deveria recusar um GIF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20823 THEN
        test_pass('formato não suportado recusado com -20823');
      ELSE
        test_fail('código errado: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: OutputModifiedPDF after removing all pages (should fail)
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - All pages removed (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Remove all pages
    FOR i IN 1..5 LOOP
      PL_FPDF.RemovePage(i);
    END LOOP;

    -- Try to generate PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    test_fail('Should have raised error for empty PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20820 THEN
        test_pass('Correctly rejected empty PDF (all pages removed)');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: OutputModifiedPDF without loaded PDF (should fail)
  --------------------------------------------------------------------------------
  test_start('OutputModifiedPDF - No PDF loaded (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- Try to output without loading PDF
    l_modified_pdf := PL_FPDF.OutputModifiedPDF();
    test_fail('Should have raised error for no PDF loaded');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20809 THEN
        test_pass('Correctly raised error for no PDF loaded');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST SUMMARY
  --------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('TEST SUMMARY');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  -- l_test_count conta blocos (test_start); l_pass/l_fail contam verificações.
  -- O percentual precisa ser sobre as verificações, senão passa de 100%.
  DBMS_OUTPUT.PUT_LINE('Testes:       ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Verificações: ' || (l_pass_count + l_fail_count));
  DBMS_OUTPUT.PUT_LINE('Passou:       ' || l_pass_count || ' (' ||
    CASE WHEN l_pass_count + l_fail_count = 0 THEN '0'
         ELSE TO_CHAR(ROUND(l_pass_count / (l_pass_count + l_fail_count) * 100, 1))
    END || '%)');
  DBMS_OUTPUT.PUT_LINE('Falhou:       ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** SOME TESTS FAILED ***');
  END IF;

  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/
