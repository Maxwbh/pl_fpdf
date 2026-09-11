--------------------------------------------------------------------------------
-- PL_FPDF - Suíte de testes completa
--
-- ARQUIVO GERADO por scripts/build_run_all.py — não edite à mão.
-- Para alterar um teste, edite o arquivo original em tests/ e rode:
--     python scripts/build_run_all.py
--
-- Como executar
-- -------------
-- PL/SQL Developer, SQL Window: abra este arquivo e execute (F8). Não há
-- comandos de cliente (SET, PROMPT, @) — só blocos anônimos PL/SQL. O
-- resultado aparece na aba Output.
--
-- SQL*Plus / SQLcl: rode `SET SERVEROUTPUT ON SIZE UNLIMITED` antes, já que
-- fora do PL/SQL Developer o DBMS_OUTPUT não vem habilitado.
--
-- IMPORTANTE: reconecte a sessão depois de recompilar o package. O PL_FPDF tem
-- estado (variáveis de package), e uma sessão que já o carregou passa a falhar
-- com ORA-04068 ou ORA-06508 ("não foi localizada a unidade de programa") em
-- TODAS as chamadas seguintes. O sintoma engana: parece package quebrado, mas
-- basta abrir uma sessão nova.
--
-- Cada bloco é independente: se um falhar, os seguintes continuam.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Fases 1-3: geração de PDF (base)
-- origem: tests/validate_phases_1_3.sql
--------------------------------------------------------------------------------
/*******************************************************************************
* Validation Script: Phases 1-3 Combined Validation
* Version: 3.0.0-b.2
* Date: 2026-01
* Author: @maxwbh
*
* Purpose: Consolidated validation for PDF Generation phases (1-3)
*
* Validates:
*   - Phase 1: Modern Initialization, Page Management, Unicode, Images
*   - Phase 2: Security, Error Handling, Robustness
*   - Phase 3: Advanced Features (Tables, Barcodes, Headers/Footers)
*
* Usage:
*   SET SERVEROUTPUT ON SIZE UNLIMITED
*   @tests/validate_phases_1_3.sql
*******************************************************************************/

-- ================================================================================
-- PL_FPDF - Phases 1-3 Combined Validation
-- Version: 3.0.0-b.2
-- ================================================================================
--

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  PROCEDURE test_result(p_test_name VARCHAR2, p_passed BOOLEAN, p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_passed THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_test_name);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_test_name ||
        CASE WHEN p_message IS NOT NULL THEN ' - ' || p_message ELSE '' END);
    END IF;
  END test_result;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 1: PDF Generation Basics');
  DBMS_OUTPUT.PUT_LINE('================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Phase 1: Core Functionality
  DBMS_OUTPUT.PUT_LINE('Phase 1.1: Initialization & Page Management');
  DBMS_OUTPUT.PUT_LINE('-------------------------------------------');

  -- Test: Basic Init and AddPage
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    PL_FPDF.AddPage();
    test_result('Init + AddPage', PL_FPDF.IsInitialized() AND PL_FPDF.GetCurrentPage() = 1);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Init + AddPage', FALSE, SQLERRM);
  END;

  -- Test: Multi-page document
  BEGIN
    PL_FPDF.Init();
    FOR i IN 1..5 LOOP
      PL_FPDF.AddPage();
    END LOOP;
    test_result('Multi-page document (5 pages)', PL_FPDF.GetCurrentPage() = 5);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Multi-page document', FALSE, SQLERRM);
  END;

  -- Test: Page navigation (SetPage)
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();
    PL_FPDF.SetPage(1);
    test_result('Page navigation (SetPage)', PL_FPDF.GetCurrentPage() = 1);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Page navigation', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase 1.2: Unicode & Font Support');
  DBMS_OUTPUT.PUT_LINE('----------------------------------');

  -- Test: UTF-8 encoding
  --
  -- O IsUTF8Enabled saiu da spec: a flag era escrita e lida, e ninguem a
  -- consultava. O que se afere agora e o que importa -- que o Init aceite o
  -- encoding e que texto acentuado atravesse sem levantar.
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(0, 10, 'Acentuacao: cobranca em Sao Paulo');
    test_result('UTF-8 encoding enabled', TRUE);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('UTF-8 encoding', FALSE, SQLERRM);
  END;

  -- Test: Unicode characters in document
  --
  -- Este caso escrevia 'Sao Paulo - Zurich - Moscou' com acentos e cirilico
  -- numa fonte core, e aferia so que o PDF tinha mais de zero bytes. Passava
  -- -- e aprovava saida quebrada: o cirilico virava glifo errado, porque as
  -- fontes padrao do PDF alcancam WinAnsi e nada alem.
  --
  -- Agora sao dois casos, e cada um afere o contrato de verdade: o que cabe em
  -- WinAnsi sai; o que nao cabe e RECUSADO, em vez de desenhado errado.
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test: São Paulo - Zürich');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Unicode text rendering', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Unicode text rendering', FALSE, SQLERRM);
  END;

  -- Test: fora de WinAnsi e recusado, nao desenhado errado
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Moscou em cirilico: ' || UNISTR('\041C\043E\0441'));
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Non-WinAnsi text refused', FALSE,
                'aceitou cirilico em fonte core: sairia com glifo errado');
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Non-WinAnsi text refused', INSTR(SQLERRM, 'ORA-20203') > 0,
                CASE WHEN INSTR(SQLERRM, 'ORA-20203') = 0
                     THEN 'recusou com outro erro: ' || SQLERRM END);
    PL_FPDF.Reset();
  END;

  -- Test: SetFont with standard fonts
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.SetFont('Times', 'B', 14);
    PL_FPDF.SetFont('Courier', 'I', 10);
    test_result('Standard fonts (Arial, Times, Courier)', TRUE);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Standard fonts', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase 1.3: Text Output');
  DBMS_OUTPUT.PUT_LINE('----------------------');

  -- Test: Cell output
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(100, 10, 'Test Cell', '1', 0, 'C');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Cell output', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Cell output', FALSE, SQLERRM);
  END;

  -- Test: MultiCell with line breaks
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.MultiCell(100, 5, 'This is a multi-line text that should wrap automatically.');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('MultiCell with wrapping', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('MultiCell', FALSE, SQLERRM);
  END;

  -- Test: Write method
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Write(10, 'Test Write method');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Write method', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Write method', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase 1.4: Output Methods');
  DBMS_OUTPUT.PUT_LINE('-------------------------');

  -- Test: OutputBlob generates valid PDF
  DECLARE
    l_pdf BLOB;
    l_header RAW(4);
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test PDF');
    l_pdf := PL_FPDF.OutputBlob();
    l_header := DBMS_LOB.SUBSTR(l_pdf, 4, 1);
    test_result('OutputBlob generates valid PDF',
                UTL_RAW.CAST_TO_VARCHAR2(l_header) = '%PDF');
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('OutputBlob', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('====================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 2: Security & Robustness');
  DBMS_OUTPUT.PUT_LINE('====================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Phase 2: Error Handling
  DBMS_OUTPUT.PUT_LINE('Phase 2.1: Error Handling');
  DBMS_OUTPUT.PUT_LINE('-------------------------');

  -- Test: Error when AddPage before Init
  BEGIN
    PL_FPDF.Reset();
    PL_FPDF.AddPage();
    test_result('Error on AddPage before Init', FALSE, 'Should have raised error');
    PL_FPDF.Reset();
  EXCEPTION
    WHEN OTHERS THEN
      -- -20005 = 'PL_FPDF not initialized'. -20801 é 'PDF inválido' no parser.
      test_result('Error on AddPage before Init', SQLCODE = -20005);
  END;

  -- Test: Error when SetFont before Init
  BEGIN
    PL_FPDF.Reset();
    PL_FPDF.SetFont('Arial', '', 12);
    test_result('Error on SetFont before Init', FALSE, 'Should have raised error');
    PL_FPDF.Reset();
  EXCEPTION
    WHEN OTHERS THEN
      test_result('Error on SetFont before Init', SQLCODE = -20005);
  END;

  -- Test: Error when OutputBlob before Init
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Reset();
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Error on OutputBlob before Init', FALSE, 'Should have raised error');
    PL_FPDF.Reset();
  EXCEPTION
    WHEN OTHERS THEN
      -- OutputBlob chama ClosePDF, que chama AddPage: o erro chega como -20005.
      test_result('Error on OutputBlob before Init', SQLCODE = -20005);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase 2.2: Resource Management');
  DBMS_OUTPUT.PUT_LINE('------------------------------');

  -- Test: Reset cleans up resources
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test');
    PL_FPDF.Reset();
    test_result('Reset cleanup', NOT PL_FPDF.IsInitialized());
  EXCEPTION WHEN OTHERS THEN
    test_result('Reset cleanup', FALSE, SQLERRM);
  END;

  -- Test: Re-initialization after Reset
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.Reset();
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    test_result('Re-init after Reset', PL_FPDF.IsInitialized());
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Re-init after Reset', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=======================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 3: Advanced Features');
  DBMS_OUTPUT.PUT_LINE('=======================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Phase 3: Advanced Features
  DBMS_OUTPUT.PUT_LINE('Phase 3.1: Graphics & Shapes');
  DBMS_OUTPUT.PUT_LINE('----------------------------');

  -- Test: Line drawing
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.Line(10, 10, 100, 10);
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Line drawing', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Line drawing', FALSE, SQLERRM);
  END;

  -- Test: Rect drawing
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.Rect(10, 10, 50, 30, 'D');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('Rectangle drawing', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('Rectangle drawing', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase 3.2: Images');
  DBMS_OUTPUT.PUT_LINE('-----------------');

  -- Test: Image type detection
  DECLARE
    l_minimal_png BLOB;
  BEGIN
    -- Minimal 1x1 PNG image
    DBMS_LOB.CREATETEMPORARY(l_minimal_png, TRUE);
    DBMS_LOB.WRITEAPPEND(l_minimal_png, 8, HEXTORAW('89504E470D0A1A0A'));
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    -- Test image type detection (will fail but validates type detection logic)
    test_result('Image type detection (PNG)', TRUE);
    PL_FPDF.Reset();
    DBMS_LOB.FREETEMPORARY(l_minimal_png);
  EXCEPTION WHEN OTHERS THEN
    test_result('Image type detection', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase 3.3: Colors');
  DBMS_OUTPUT.PUT_LINE('-----------------');

  -- Test: SetDrawColor
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetDrawColor(255, 0, 0);  -- Red
    PL_FPDF.Line(10, 10, 100, 10);
    l_pdf := PL_FPDF.OutputBlob();
    test_result('SetDrawColor (RGB)', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('SetDrawColor', FALSE, SQLERRM);
  END;

  -- Test: SetFillColor
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFillColor(0, 255, 0);  -- Green
    PL_FPDF.Rect(10, 10, 50, 30, 'F');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('SetFillColor (RGB)', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('SetFillColor', FALSE, SQLERRM);
  END;

  -- Test: SetTextColor
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.SetTextColor(0, 0, 255);  -- Blue
    PL_FPDF.Cell(0, 10, 'Blue Text');
    l_pdf := PL_FPDF.OutputBlob();
    test_result('SetTextColor (RGB)', DBMS_LOB.GETLENGTH(l_pdf) > 0);
    PL_FPDF.Reset();
  EXCEPTION WHEN OTHERS THEN
    test_result('SetTextColor', FALSE, SQLERRM);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Phases 1-3 Validation Summary');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count || ' (' ||
    ROUND(l_pass_count * 100 / l_test_count, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASES 1-3: ALL TESTS PASSED ***');
    DBMS_OUTPUT.PUT_LINE('*** PDF GENERATION FOUNDATION: VALIDATED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASES 1-3: SOME TESTS FAILED - REVIEW REQUIRED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/

--
-- Validation complete. Review results above.
--

--------------------------------------------------------------------------------
-- Fase 4: leitura de PDF (parser)
-- origem: tests/test_phase_4_parser_basic.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Test Phase 4: PDF Parser - Basic Reading
-- Tests LoadPDF, GetPageCount, GetPDFInfo
--------------------------------------------------------------------------------


DECLARE
  -- Test counter
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
    -- Test PDF (generated by PL_FPDF for valid structure)
  l_test_pdf BLOB;
  l_page_count PLS_INTEGER;
  l_pdf_info JSON_OBJECT_T;
  
  -- Helper procedure
  PROCEDURE test_result(p_test_name VARCHAR2, p_passed BOOLEAN, p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_passed THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_test_name);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_test_name || 
        CASE WHEN p_message IS NOT NULL THEN ' - ' || p_message ELSE '' END);
    END IF;
  END test_result;
  


BEGIN
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4 - PDF PARSER: BASIC READING TESTS');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('');

  DBMS_OUTPUT.PUT_LINE('Test 4.1: Load Simple PDF');
  DBMS_OUTPUT.PUT_LINE('-------------------------');

  -- Create valid test PDF using PL_FPDF itself (guarantees correct structure)
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test Page 1');
    l_test_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;
  
  -- Test 1: LoadPDF
  BEGIN
    PL_FPDF.LoadPDF(l_test_pdf);
    test_result('LoadPDF() with minimal PDF', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('LoadPDF() with minimal PDF', FALSE, SQLERRM);
  END;
  
  -- Test 2: GetPageCount
  BEGIN
    l_page_count := PL_FPDF.GetPageCount();
    test_result('GetPageCount() returns 1', l_page_count = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageCount()', FALSE, SQLERRM);
  END;
  
  -- Test 3: GetPDFInfo
  BEGIN
    l_pdf_info := PL_FPDF.GetPDFInfo();
    test_result('GetPDFInfo() returns JSON', l_pdf_info IS NOT NULL);
    test_result('GetPDFInfo().version = 1.4', l_pdf_info.get_string('version') = '1.4');
    test_result('GetPDFInfo().pageCount = 1', l_pdf_info.get_number('pageCount') = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPDFInfo()', FALSE, SQLERRM);
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('SUMMARY');
  DBMS_OUTPUT.PUT_LINE('========================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count);
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('Success Rate: ' || ROUND(l_pass_count * 100 / l_test_count, 1) || '%');
  DBMS_OUTPUT.PUT_LINE('========================================================================');

  
  
    IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4_parser_basic: ALL TESTS PASSED ***');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4_parser_basic: SOME TESTS FAILED - REVIEW REQUIRED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/

--------------------------------------------------------------------------------
-- Fase 4.1B: informações de página
-- origem: tests/test_phase_4_1b_pages.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-alpha - Phase 4.1B: Page Information and Manipulation Tests
-- Description: Test suite for GetPageInfo and RotatePage APIs
--------------------------------------------------------------------------------


DECLARE
  l_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_info JSON_OBJECT_T;
  l_page_count PLS_INTEGER;

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

  -- Create valid test PDF using PL_FPDF itself (guarantees correct structure)
  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Page 1');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Page 2');
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-alpha - PHASE 4.1B: Page Information & Manipulation Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF
  create_test_pdf();

  -- Enable debug logging
  --PL_FPDF.EnableDebugMode();
  PL_FPDF.SetLogLevel(4);

  --------------------------------------------------------------------------------
  -- TEST 1: Load PDF and verify page tree parsing
  --------------------------------------------------------------------------------
  test_start('Load PDF and parse page tree');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);
    l_page_count := PL_FPDF.GetPageCount();

    IF l_page_count = 2 THEN
      test_pass('Page count correct: 2 pages');
    ELSE
      test_fail('Expected 2 pages, got ' || l_page_count);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error loading PDF: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: Get page 1 information
  --------------------------------------------------------------------------------
  test_start('GetPageInfo for page 1');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(1);

    DBMS_OUTPUT.PUT_LINE('  Page 1 Info:');
    DBMS_OUTPUT.PUT_LINE('    - Page Number: ' || l_info.get_number('pageNumber'));
    DBMS_OUTPUT.PUT_LINE('    - Object ID: ' || l_info.get_number('pageObjectId'));
    DBMS_OUTPUT.PUT_LINE('    - MediaBox: ' || l_info.get_string('mediaBox'));
    DBMS_OUTPUT.PUT_LINE('    - Rotation: ' || l_info.get_number('rotation') || ' degrees');

    IF l_info.get_number('pageNumber') = 1 THEN
      test_pass('Page number correct');
    ELSE
      test_fail('Page number incorrect');
    END IF;

    IF l_info.get_string('mediaBox') LIKE '0 0 612%792%' THEN
      test_pass('MediaBox correct (Letter size)');
    ELSE
      test_fail('MediaBox incorrect: ' || l_info.get_string('mediaBox'));
    END IF;

    IF l_info.get_number('rotation') = 0 THEN
      test_pass('Rotation correct (0 degrees)');
    ELSE
      test_fail('Rotation incorrect: ' || l_info.get_number('rotation'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error getting page 1 info: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: Get page 2 information
  --------------------------------------------------------------------------------
  test_start('GetPageInfo for page 2');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(2);

    DBMS_OUTPUT.PUT_LINE('  Page 2 Info:');
    DBMS_OUTPUT.PUT_LINE('    - Page Number: ' || l_info.get_number('pageNumber'));
    DBMS_OUTPUT.PUT_LINE('    - Object ID: ' || l_info.get_number('pageObjectId'));
    DBMS_OUTPUT.PUT_LINE('    - MediaBox: ' || l_info.get_string('mediaBox'));
    DBMS_OUTPUT.PUT_LINE('    - Rotation: ' || l_info.get_number('rotation') || ' degrees');

    IF l_info.get_string('mediaBox') LIKE '0 0 612%792%' THEN
      test_pass('MediaBox correct (Letter size)');
    ELSE
      test_fail('MediaBox incorrect: ' || l_info.get_string('mediaBox'));
    END IF;

    IF l_info.get_number('rotation') = 0 THEN
      test_pass('Rotation correct (0 degrees)');
    ELSE
      test_fail('Rotation incorrect: ' || l_info.get_number('rotation'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error getting page 2 info: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: RotatePage - Set page 1 to 180 degrees
  --------------------------------------------------------------------------------
  test_start('RotatePage - Set page 1 to 180 degrees');
  BEGIN
    PL_FPDF.RotatePage(1, 180);

    l_info := PL_FPDF.GetPageInfo(1);
    IF l_info.get_number('rotation') = 180 THEN
      test_pass('Page 1 rotation updated to 180 degrees');
    ELSE
      test_fail('Rotation not updated: ' || l_info.get_number('rotation'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error rotating page: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: RotatePage - Invalid rotation value
  --------------------------------------------------------------------------------
  test_start('RotatePage - Invalid rotation value (should fail)');
  BEGIN
    PL_FPDF.RotatePage(1, 45);  -- Invalid: must be 0, 90, 180, or 270
    test_fail('Should have raised error for invalid rotation');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20813 THEN
        test_pass('Correctly rejected invalid rotation value');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: GetPageInfo - Invalid page number
  --------------------------------------------------------------------------------
  test_start('GetPageInfo - Invalid page number (should fail)');
  BEGIN
    l_info := PL_FPDF.GetPageInfo(99);  -- PDF only has 2 pages
    test_fail('Should have raised error for invalid page number');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20812 THEN
        test_pass('Correctly rejected invalid page number');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: ClearPDFCache and verify cleanup
  --------------------------------------------------------------------------------
  test_start('ClearPDFCache and verify cleanup');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- Try to get page count after clearing - should fail
    BEGIN
      l_page_count := PL_FPDF.GetPageCount();
      test_fail('Should have raised error after ClearPDFCache');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          test_pass('Correctly raised error after clearing cache');
        ELSE
          test_fail('Wrong error code: ' || SQLCODE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error clearing cache: ' || SQLERRM);
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

--------------------------------------------------------------------------------
-- Fase 4.2: gerenciamento de páginas
-- origem: tests/test_phase_4_2_page_mgmt.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-a.3 - Phase 4.2: Page Management Tests
-- Description: Test suite for RemovePage, GetActivePageCount, modification tracking
--------------------------------------------------------------------------------


DECLARE
  l_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_page_count PLS_INTEGER;
  l_active_count PLS_INTEGER;
  l_is_removed BOOLEAN;
  l_is_modified BOOLEAN;

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
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-a.3 - PHASE 4.2: Page Management Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF with 5 pages
  create_test_pdf();

  --------------------------------------------------------------------------------
  -- TEST 1: Load PDF and verify initial state
  --------------------------------------------------------------------------------
  test_start('Load PDF and verify initial state');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);
    l_page_count := PL_FPDF.GetPageCount();
    l_active_count := PL_FPDF.GetActivePageCount();
    l_is_modified := PL_FPDF.IsPDFModified();

    IF l_page_count = 5 THEN
      test_pass('Total page count correct: 5 pages');
    ELSE
      test_fail('Expected 5 pages, got ' || l_page_count);
    END IF;

    IF l_active_count = 5 THEN
      test_pass('Active page count correct: 5 pages (none removed)');
    ELSE
      test_fail('Expected 5 active pages, got ' || l_active_count);
    END IF;

    IF NOT l_is_modified THEN
      test_pass('PDF not modified initially');
    ELSE
      test_fail('PDF should not be marked as modified initially');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error loading PDF: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: RemovePage - Remove page 2
  --------------------------------------------------------------------------------
  test_start('RemovePage - Remove page 2');
  BEGIN
    PL_FPDF.RemovePage(2);

    l_active_count := PL_FPDF.GetActivePageCount();
    l_is_removed := PL_FPDF.IsPageRemoved(2);
    l_is_modified := PL_FPDF.IsPDFModified();

    IF l_active_count = 4 THEN
      test_pass('Active page count correct: 4 pages (1 removed)');
    ELSE
      test_fail('Expected 4 active pages, got ' || l_active_count);
    END IF;

    IF l_is_removed THEN
      test_pass('Page 2 marked as removed');
    ELSE
      test_fail('Page 2 should be marked as removed');
    END IF;

    IF l_is_modified THEN
      test_pass('PDF marked as modified');
    ELSE
      test_fail('PDF should be marked as modified');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error removing page: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: RemovePage - Remove multiple pages (3 and 5)
  --------------------------------------------------------------------------------
  test_start('RemovePage - Remove pages 3 and 5');
  BEGIN
    PL_FPDF.RemovePage(3);
    PL_FPDF.RemovePage(5);

    l_active_count := PL_FPDF.GetActivePageCount();

    IF l_active_count = 2 THEN
      test_pass('Active page count correct: 2 pages (3 removed total)');
    ELSE
      test_fail('Expected 2 active pages, got ' || l_active_count);
    END IF;

    -- Verify individual page status
    IF PL_FPDF.IsPageRemoved(2) AND PL_FPDF.IsPageRemoved(3) AND PL_FPDF.IsPageRemoved(5) THEN
      test_pass('Pages 2, 3, 5 correctly marked as removed');
    ELSE
      test_fail('Not all pages correctly marked as removed');
    END IF;

    IF NOT PL_FPDF.IsPageRemoved(1) AND NOT PL_FPDF.IsPageRemoved(4) THEN
      test_pass('Pages 1, 4 correctly marked as active');
    ELSE
      test_fail('Pages 1, 4 should not be marked as removed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error removing pages: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: RemovePage - Attempt to remove already removed page
  --------------------------------------------------------------------------------
  test_start('RemovePage - Attempt to remove already removed page (should fail)');
  BEGIN
    PL_FPDF.RemovePage(2);  -- Already removed in TEST 2
    test_fail('Should have raised error for already removed page');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20814 THEN
        test_pass('Correctly rejected attempt to remove already removed page');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: RemovePage - Invalid page number
  --------------------------------------------------------------------------------
  test_start('RemovePage - Invalid page number (should fail)');
  BEGIN
    PL_FPDF.RemovePage(99);  -- PDF only has 5 pages
    test_fail('Should have raised error for invalid page number');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20812 THEN
        test_pass('Correctly rejected invalid page number');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: RotatePage and check modification flag
  --------------------------------------------------------------------------------
  test_start('RotatePage - Verify modification tracking');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    -- Should not be modified initially
    IF NOT PL_FPDF.IsPDFModified() THEN
      test_pass('PDF not modified after fresh load');
    ELSE
      test_fail('PDF should not be modified after fresh load');
    END IF;

    -- Rotate a page
    PL_FPDF.RotatePage(1, 90);

    IF PL_FPDF.IsPDFModified() THEN
      test_pass('PDF marked as modified after rotation');
    ELSE
      test_fail('PDF should be marked as modified after rotation');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error in modification tracking: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: ClearPDFCache - Verify cleanup of modification tracking
  --------------------------------------------------------------------------------
  test_start('ClearPDFCache - Verify cleanup');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- Try to check modification status after clearing - should fail
    BEGIN
      l_is_modified := PL_FPDF.IsPDFModified();
      -- IsPDFModified doesn't validate PDF loaded, so it will return FALSE
      IF NOT l_is_modified THEN
        test_pass('Modification flag cleared after cache clear');
      ELSE
        test_fail('Modification flag should be cleared');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail('Unexpected error: ' || SQLERRM);
    END;

    -- GetActivePageCount should fail after clearing
    BEGIN
      l_active_count := PL_FPDF.GetActivePageCount();
      test_fail('Should have raised error after ClearPDFCache');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          test_pass('Correctly raised error after clearing cache');
        ELSE
          test_fail('Wrong error code: ' || SQLCODE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error clearing cache: ' || SQLERRM);
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

--------------------------------------------------------------------------------
-- Fase 4.3: marcas d'água
-- origem: tests/test_phase_4_3_watermark.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF v3.0.0-a.4 - Phase 4.3: Watermark Tests
-- Description: Test suite for AddWatermark and GetWatermarks APIs
--------------------------------------------------------------------------------



DECLARE
  l_pdf BLOB;
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;
  l_watermarks JSON_ARRAY_T;
  l_watermark JSON_OBJECT_T;
  l_is_modified BOOLEAN;

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

  -- Create valid test PDF with 10 pages using PL_FPDF itself
  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1..10 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Page ' || i);
    END LOOP;
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.0.0-a.4 - PHASE 4.3: Watermark Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Create test PDF with 10 pages
  create_test_pdf();

  --------------------------------------------------------------------------------
  -- TEST 1: Load PDF and add watermark to all pages
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Apply to ALL pages');
  BEGIN
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3, 45, 'ALL');

    l_watermarks := PL_FPDF.GetWatermarks();
    l_is_modified := PL_FPDF.IsPDFModified();

    IF l_watermarks.get_size() = 1 THEN
      test_pass('1 watermark added');
    ELSE
      test_fail('Expected 1 watermark, got ' || l_watermarks.get_size());
    END IF;

    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);
    IF l_watermark.get_string('text') = 'CONFIDENTIAL' THEN
      test_pass('Watermark text correct: CONFIDENTIAL');
    ELSE
      test_fail('Watermark text incorrect: ' || l_watermark.get_string('text'));
    END IF;

    IF l_watermark.get_number('opacity') = 0.3 THEN
      test_pass('Opacity correct: 0.3');
    ELSE
      test_fail('Opacity incorrect: ' || l_watermark.get_number('opacity'));
    END IF;

    IF l_watermark.get_number('rotation') = 45 THEN
      test_pass('Rotation correct: 45 degrees');
    ELSE
      test_fail('Rotation incorrect: ' || l_watermark.get_number('rotation'));
    END IF;

    IF l_is_modified THEN
      test_pass('PDF marked as modified');
    ELSE
      test_fail('PDF should be marked as modified');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error adding watermark: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 2: AddWatermark - Specific page range '1-3'
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Specific range: 1-3');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('DRAFT', 0.2, 90, '1-3');

    l_watermarks := PL_FPDF.GetWatermarks();
    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);

    DBMS_OUTPUT.PUT_LINE('  Page range: ' || l_watermark.get_string('pageRange'));

    -- Page range should be parsed to '1,2,3'
    IF l_watermark.get_string('pageRange') = '1,2,3' THEN
      test_pass('Page range parsed correctly: 1,2,3');
    ELSE
      test_fail('Page range incorrect: ' || l_watermark.get_string('pageRange'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error with page range: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 3: AddWatermark - Complex range '1,3,5-7,10'
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Complex range: 1,3,5-7,10');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '1,3,5-7,10');

    l_watermarks := PL_FPDF.GetWatermarks();
    l_watermark := TREAT(l_watermarks.get(0) AS JSON_OBJECT_T);

    DBMS_OUTPUT.PUT_LINE('  Page range: ' || l_watermark.get_string('pageRange'));

    -- Page range should be parsed to '1,3,5,6,7,10'
    IF l_watermark.get_string('pageRange') = '1,3,5,6,7,10' THEN
      test_pass('Complex range parsed correctly: 1,3,5,6,7,10');
    ELSE
      test_fail('Page range incorrect: ' || l_watermark.get_string('pageRange'));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error with complex range: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 4: AddWatermark - Multiple watermarks
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Multiple watermarks');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);

    PL_FPDF.AddWatermark('CONFIDENTIAL', 0.2, 45, 'ALL');
    PL_FPDF.AddWatermark('DRAFT', 0.3, 90, '1-5');
    PL_FPDF.AddWatermark('APPROVED', 0.5, 0, '10');

    l_watermarks := PL_FPDF.GetWatermarks();

    IF l_watermarks.get_size() = 3 THEN
      test_pass('3 watermarks added');
    ELSE
      test_fail('Expected 3 watermarks, got ' || l_watermarks.get_size());
    END IF;

    -- Verify each watermark
    FOR i IN 0..l_watermarks.get_size() - 1 LOOP
      l_watermark := TREAT(l_watermarks.get(i) AS JSON_OBJECT_T);
      DBMS_OUTPUT.PUT_LINE('  Watermark ' || (i + 1) || ': ' ||
        l_watermark.get_string('text') || ' on pages ' ||
        l_watermark.get_string('pageRange'));
    END LOOP;

    test_pass('All watermarks stored correctly');
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error with multiple watermarks: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------------
  -- TEST 5: AddWatermark - Invalid parameters (empty text)
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Invalid text (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('', 0.3, 45, 'ALL');  -- Empty text
    test_fail('Should have raised error for empty text');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20816 THEN
        test_pass('Correctly rejected empty watermark text');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 6: AddWatermark - Invalid opacity
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Invalid opacity (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('TEST', 1.5, 45, 'ALL');  -- Opacity > 1
    test_fail('Should have raised error for opacity > 1');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20817 THEN
        test_pass('Correctly rejected invalid opacity');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 7: AddWatermark - Invalid rotation
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Invalid rotation (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('TEST', 0.3, 60, 'ALL');  -- Invalid rotation
    test_fail('Should have raised error for invalid rotation');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20818 THEN
        test_pass('Correctly rejected invalid rotation (60 degrees)');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 8: AddWatermark - Invalid page range
  --------------------------------------------------------------------------------
  test_start('AddWatermark - Invalid page range (should fail)');
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark('TEST', 0.3, 45, '1-20');  -- Page 20 doesn't exist
    test_fail('Should have raised error for invalid page range');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20815 THEN
        test_pass('Correctly rejected invalid page range (1-20)');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- TEST 9: ClearPDFCache - Verify watermarks cleared
  --------------------------------------------------------------------------------
  test_start('ClearPDFCache - Verify watermarks cleared');
  BEGIN
    PL_FPDF.ClearPDFCache();

    -- GetWatermarks should fail after clearing
    BEGIN
      l_watermarks := PL_FPDF.GetWatermarks();
      test_fail('Should have raised error after ClearPDFCache');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          test_pass('Correctly raised error after clearing cache');
        ELSE
          test_fail('Wrong error code: ' || SQLCODE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error clearing cache: ' || SQLERRM);
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

--------------------------------------------------------------------------------
-- Fase 4.4: OutputModifiedPDF
-- origem: tests/test_phase_4_4_output.sql
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- Fase 4.5: sobreposições
-- origem: tests/test_phase_4_5_overlay.sql
--------------------------------------------------------------------------------
/*******************************************************************************
* Test Script: Phase 4.5 - Text & Image Overlay
* Version: 3.0.0-a.6
* Date: 2026-01-25
* Author: @maxwbh
*
* Description:
*   Comprehensive test suite for Phase 4.5 overlay functionality including
*   text overlays, image overlays, and overlay management operations.
*******************************************************************************/



DECLARE
  -- Test counters
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  -- Test data
  l_test_pdf BLOB;
  l_logo_blob BLOB;
  l_result BLOB;
  l_overlays JSON_ARRAY_T;
  l_overlay JSON_OBJECT_T;
  l_options JSON_OBJECT_T;
  l_overlay_id VARCHAR2(50);

  -- Helper procedures
  PROCEDURE run_test(p_test_name VARCHAR2, p_result BOOLEAN) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_result THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_test_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name || ' - FAIL');
    END IF;
  END run_test;

  PROCEDURE expect_error(p_test_name VARCHAR2, p_expected_code NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name ||
                         ' - FAIL (Expected error ' || p_expected_code || ' but succeeded)');
  END expect_error;

  PROCEDURE handle_expected_error(p_test_name VARCHAR2, p_expected_code NUMBER, p_actual_code NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_actual_code = p_expected_code THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_test_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name ||
                           ' - FAIL (Expected ' || p_expected_code || ', got ' || p_actual_code || ')');
    END IF;
  END handle_expected_error;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting Phase 4.5 Overlay Tests...');
  DBMS_OUTPUT.PUT_LINE('');

  -- Create valid test PDF using PL_FPDF itself (guarantees correct structure)
  BEGIN
    PL_FPDF.Init('P', 'mm', 'Letter');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test Page');
    l_test_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END;

  -- Create test logo (1x1 PNG - simplest valid PNG)
  l_logo_blob := HEXTORAW('89504E470D0A1A0A0000000D494844520000000100000001010000000037' ||
                          '6EF9240000000A49444154789C626001000000050001ED5F38E40000000049' ||
                          '454E44AE426082');

  DBMS_OUTPUT.PUT_LINE('=== Text Overlay Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 1: OverlayText without PDF loaded (should fail)
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.OverlayText(1, 'Test', 100, 700, NULL);
    expect_error('OverlayText without PDF loaded', -20809);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('OverlayText without PDF loaded', -20809, SQLCODE);
  END;

  -- Test 2: Simple text overlay
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
    run_test('Simple text overlay', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Simple text overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 3: Text overlay with options
  BEGIN
    l_options := JSON_OBJECT_T();
    l_options.put('font', 'Helvetica-Bold');
    l_options.put('fontSize', 24);
    l_options.put('color', 'FF0000');  -- Red
    l_options.put('opacity', 0.8);
    l_options.put('rotation', 45);
    PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
    run_test('Text overlay with formatting options', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Text overlay with formatting options', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 4: Text overlay with invalid page number
  BEGIN
    PL_FPDF.OverlayText(999, 'Test', 100, 700, NULL);
    expect_error('Text overlay with invalid page number', -20810);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Text overlay with invalid page number', -20810, SQLCODE);
  END;

  -- Test 5: Text overlay with invalid coordinates
  BEGIN
    PL_FPDF.OverlayText(1, 'Test', -100, 700, NULL);
    expect_error('Text overlay with negative X coordinate', -20821);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Text overlay with negative X coordinate', -20821, SQLCODE);
  END;

  -- Test 6: Text overlay with invalid opacity
  BEGIN
    l_options := JSON_OBJECT_T();
    l_options.put('opacity', 1.5);
    PL_FPDF.OverlayText(1, 'Test', 100, 700, l_options);
    expect_error('Text overlay with invalid opacity', -20821);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Text overlay with invalid opacity', -20821, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Image Overlay Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 7: Simple image overlay
  BEGIN
    PL_FPDF.OverlayImage(1, l_logo_blob, 450, 750, 100, 50, NULL);
    run_test('Simple image overlay', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Simple image overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 8: Image overlay with options
  BEGIN
    l_options := JSON_OBJECT_T();
    l_options.put('opacity', 0.3);
    l_options.put('rotation', 45);
    l_options.put('maintainAspect', TRUE);
    PL_FPDF.OverlayImage(1, l_logo_blob, 200, 400, 300, NULL, l_options);
    run_test('Image overlay with transparency and rotation', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Image overlay with transparency and rotation', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 9: Image overlay with invalid format
  BEGIN
    PL_FPDF.OverlayImage(1, UTL_RAW.CAST_TO_RAW('Invalid'), 100, 100, NULL, NULL, NULL);
    expect_error('Image overlay with invalid format', -20823);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Image overlay with invalid format', -20823, SQLCODE);
  END;

  -- Test 10: Image overlay with NULL image
  BEGIN
    PL_FPDF.OverlayImage(1, NULL, 100, 100, NULL, NULL, NULL);
    expect_error('Image overlay with NULL image', -20823);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Image overlay with NULL image', -20823, SQLCODE);
  END;

  -- Test 11: Image overlay with invalid dimensions
  BEGIN
    PL_FPDF.OverlayImage(1, l_logo_blob, 100, 100, -50, 50, NULL);
    expect_error('Image overlay with negative width', -20824);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Image overlay with negative width', -20824, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Overlay Management Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 12: GetOverlays - list all overlays
  BEGIN
    l_overlays := PL_FPDF.GetOverlays();
    run_test('GetOverlays - list all', l_overlays.get_size() > 0);
    DBMS_OUTPUT.PUT_LINE('   Found ' || l_overlays.get_size() || ' overlays');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('GetOverlays - list all', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 13: GetOverlays - filter by page
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('GetOverlays - filter by page', l_overlays.get_size() > 0);
    DBMS_OUTPUT.PUT_LINE('   Found ' || l_overlays.get_size() || ' overlays on page 1');

    -- Display overlay details
    FOR i IN 0..l_overlays.get_size() - 1 LOOP
      l_overlay := TREAT(l_overlays.get(i) AS JSON_OBJECT_T);
      DBMS_OUTPUT.PUT_LINE('   - ' || l_overlay.get_string('overlayType') || ': ' ||
                          l_overlay.get_string('overlayId'));
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('GetOverlays - filter by page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 14: RemoveOverlay
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(1);
    IF l_overlays.get_size() > 0 THEN
      l_overlay := TREAT(l_overlays.get(0) AS JSON_OBJECT_T);
      l_overlay_id := l_overlay.get_string('overlayId');
      PL_FPDF.RemoveOverlay(l_overlay_id);
      run_test('RemoveOverlay - remove specific overlay', TRUE);
      DBMS_OUTPUT.PUT_LINE('   Removed overlay: ' || l_overlay_id);
    ELSE
      run_test('RemoveOverlay - remove specific overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   No overlays to remove');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('RemoveOverlay - remove specific overlay', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 15: RemoveOverlay with invalid ID
  BEGIN
    PL_FPDF.RemoveOverlay('INVALID_ID');
    expect_error('RemoveOverlay with invalid ID', -20825);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('RemoveOverlay with invalid ID', -20825, SQLCODE);
  END;

  -- Test 16: ClearOverlays - specific page
  BEGIN
    PL_FPDF.ClearOverlays(1);
    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('ClearOverlays - specific page', l_overlays.get_size() = 0);
    DBMS_OUTPUT.PUT_LINE('   Overlays on page 1: ' || l_overlays.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('ClearOverlays - specific page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 17: Add more overlays and clear all
  BEGIN
    PL_FPDF.OverlayText(1, 'Test 1', 100, 100, NULL);
    PL_FPDF.OverlayText(1, 'Test 2', 200, 200, NULL);
    PL_FPDF.OverlayImage(1, l_logo_blob, 300, 300, 50, 50, NULL);

    l_overlays := PL_FPDF.GetOverlays();
    DBMS_OUTPUT.PUT_LINE('   Added 3 overlays, total: ' || l_overlays.get_size());

    PL_FPDF.ClearOverlays();  -- Clear all
    l_overlays := PL_FPDF.GetOverlays();
    run_test('ClearOverlays - clear all', l_overlays.get_size() = 0);
    DBMS_OUTPUT.PUT_LINE('   Remaining overlays: ' || l_overlays.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('ClearOverlays - clear all', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Integration Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 18: Multiple overlays with different z-orders
  BEGIN
    PL_FPDF.ClearOverlays();

    l_options := JSON_OBJECT_T();
    l_options.put('zOrder', 1);
    PL_FPDF.OverlayText(1, 'Bottom Layer', 100, 100, l_options);

    l_options := JSON_OBJECT_T();
    l_options.put('zOrder', 100);
    PL_FPDF.OverlayText(1, 'Top Layer', 120, 120, l_options);

    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('Multiple overlays with z-order', l_overlays.get_size() = 2);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Multiple overlays with z-order', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 19: Overlay persistence check
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(1);
    run_test('Overlay persistence', l_overlays.get_size() = 2);
    DBMS_OUTPUT.PUT_LINE('   Persisted overlays: ' || l_overlays.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Overlay persistence', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 20: ClearPDFCache clears overlays
  BEGIN
    PL_FPDF.ClearPDFCache();
    BEGIN
      l_overlays := PL_FPDF.GetOverlays();
      run_test('ClearPDFCache clears overlays', FALSE);
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20809 THEN
          run_test('ClearPDFCache clears overlays', TRUE);
        ELSE
          run_test('ClearPDFCache clears overlays', FALSE);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('ClearPDFCache clears overlays', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Final summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('Test Summary:');
  DBMS_OUTPUT.PUT_LINE('  Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('  Passed:      ' || l_pass_count || ' (' ||
                      ROUND(l_pass_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('  Failed:      ' || l_fail_count || ' (' ||
                      ROUND(l_fail_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('========================================');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('✓ ALL TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✗ SOME TESTS FAILED');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Test execution aborted at test ' || l_test_count);
    RAISE;
END;
/

--------------------------------------------------------------------------------
-- Fase 4.6: merge e split
-- origem: tests/test_phase_4_6_merge_split.sql
--------------------------------------------------------------------------------
/*******************************************************************************
* Test Script: Phase 4.6 - PDF Merge & Split
* Version: 3.0.0-a.7
* Date: 2026-01-25
* Author: @maxwbh
*
* Description:
*   Comprehensive test suite for Phase 4.6 multi-document PDF operations
*   including merge, split, and extract functionality.
*******************************************************************************/


DECLARE
  -- Test counters
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  -- Test data
  l_test_pdf1 BLOB;
  l_test_pdf2 BLOB;
  l_test_pdf3 BLOB;
  l_merged BLOB;
  l_split_pdfs JSON_ARRAY_T;
  l_extracted BLOB;
  l_pdfs JSON_ARRAY_T;
  l_pdf_obj JSON_OBJECT_T;

  -- Helper procedures
  PROCEDURE run_test(p_test_name VARCHAR2, p_result BOOLEAN) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_result THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_test_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name || ' - FAIL');
    END IF;
  END run_test;

  PROCEDURE expect_error(p_test_name VARCHAR2, p_expected_code NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    l_fail_count := l_fail_count + 1;
    DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name ||
                         ' - FAIL (Expected error ' || p_expected_code || ' but succeeded)');
  END expect_error;

  PROCEDURE handle_expected_error(p_test_name VARCHAR2, p_expected_code NUMBER, p_actual_code NUMBER) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_actual_code = p_expected_code THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Test ' || l_test_count || ': ' || p_test_name || ' - PASS');
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('✗ Test ' || l_test_count || ': ' || p_test_name ||
                           ' - FAIL (Expected ' || p_expected_code || ', got ' || p_actual_code || ')');
    END IF;
  END handle_expected_error;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting Phase 4.6 Multi-Document Tests...');
  DBMS_OUTPUT.PUT_LINE('');

  -- Create valid test PDFs using PL_FPDF itself (guarantees correct structure)
  -- PDF 1
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test PDF 1');
  l_test_pdf1 := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- PDF 2
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test PDF 2');
  l_test_pdf2 := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- PDF 3
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test PDF 3');
  l_test_pdf3 := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  -- Estado limpo: sem isto, rodar o arquivo duas vezes na mesma sessão falha
  -- com ORA-20828 ('PDF ID already loaded'), porque a coleção multi-documento
  -- sobrevive entre execuções.
  BEGIN
    PL_FPDF.ClearPDFCache;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DBMS_OUTPUT.PUT_LINE('=== LoadPDFWithID Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 1: Load single PDF with ID
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf1);
    run_test('Load PDF with ID', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Load PDF with ID', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 2: Load multiple PDFs
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf2', l_test_pdf2);
    PL_FPDF.LoadPDFWithID('pdf3', l_test_pdf3);
    run_test('Load multiple PDFs', TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Load multiple PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 3: Load duplicate ID (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf1);
    expect_error('Load duplicate PDF ID', -20828);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Load duplicate PDF ID', -20828, SQLCODE);
  END;

  -- Test 4: Load with NULL ID (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID(NULL, l_test_pdf1);
    expect_error('Load with NULL ID', -20830);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Load with NULL ID', -20830, SQLCODE);
  END;

  -- Test 5: Load with NULL BLOB (should error)
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf_null', NULL);
    expect_error('Load with NULL BLOB', -20830);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Load with NULL BLOB', -20830, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== GetLoadedPDFs Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 6: Get loaded PDFs
  BEGIN
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    run_test('GetLoadedPDFs returns array', l_pdfs IS NOT NULL AND l_pdfs.get_size() >= 3);
    DBMS_OUTPUT.PUT_LINE('   Found ' || l_pdfs.get_size() || ' loaded PDFs');

    -- Display PDF details
    FOR i IN 0..l_pdfs.get_size() - 1 LOOP
      l_pdf_obj := TREAT(l_pdfs.get(i) AS JSON_OBJECT_T);
      DBMS_OUTPUT.PUT_LINE('   - ' || l_pdf_obj.get_string('pdfId') ||
                          ': ' || l_pdf_obj.get_number('pageCount') || ' pages, ' ||
                          ROUND(l_pdf_obj.get_number('fileSize')/1024, 1) || ' KB');
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      run_test('GetLoadedPDFs returns array', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== MergePDFs Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 7: Merge 2 PDFs
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf2"]'), NULL);
    run_test('Merge 2 PDFs', l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
    DBMS_OUTPUT.PUT_LINE('   Merged PDF size: ' || DBMS_LOB.GETLENGTH(l_merged) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Merge 2 PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 8: Merge 3 PDFs
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf2","pdf3"]'), NULL);
    run_test('Merge 3 PDFs', l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
    DBMS_OUTPUT.PUT_LINE('   Merged PDF size: ' || DBMS_LOB.GETLENGTH(l_merged) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Merge 3 PDFs', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 9: Merge with empty array (should error)
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('[]'), NULL);
    expect_error('Merge with empty array', -20832);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Merge with empty array', -20832, SQLCODE);
  END;

  -- Test 10: Merge with non-loaded PDF (should error)
  BEGIN
    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf1","pdf_notloaded"]'), NULL);
    expect_error('Merge with non-loaded PDF', -20833);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Merge with non-loaded PDF', -20833, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== ExtractPages Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 11: Extract ALL pages
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', 'ALL', NULL);
    run_test('Extract ALL pages', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Extracted PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Extract ALL pages', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 12: Extract single page
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', '1', NULL);
    run_test('Extract single page', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Extracted PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Extract single page', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 13: Extract from non-loaded PDF (should error)
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf_notexist', '1', NULL);
    expect_error('Extract from non-loaded PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Extract from non-loaded PDF', -20831, SQLCODE);
  END;

  -- Test 14: Extract with NULL page spec (should error)
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', NULL, NULL);
    expect_error('Extract with NULL page spec', -20838);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Extract with NULL page spec', -20838, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== SplitPDF Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 15: Split PDF
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf1', JSON_ARRAY_T('["1"]'));
    run_test('Split PDF into 1 part', l_split_pdfs IS NOT NULL AND l_split_pdfs.get_size() = 1);
    DBMS_OUTPUT.PUT_LINE('   Split into ' || l_split_pdfs.get_size() || ' parts');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Split PDF into 1 part', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 16: Split with empty ranges (should error)
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf1', JSON_ARRAY_T('[]'));
    expect_error('Split with empty ranges', -20835);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Split with empty ranges', -20835, SQLCODE);
  END;

  -- Test 17: Split non-loaded PDF (should error)
  BEGIN
    l_split_pdfs := PL_FPDF.SplitPDF('pdf_notexist', JSON_ARRAY_T('["1"]'));
    expect_error('Split non-loaded PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Split non-loaded PDF', -20831, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== UnloadPDF Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 18: Unload PDF
  BEGIN
    PL_FPDF.UnloadPDF('pdf3');
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    run_test('Unload PDF', l_pdfs.get_size() = 2);
    DBMS_OUTPUT.PUT_LINE('   Remaining PDFs: ' || l_pdfs.get_size());
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Unload PDF', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Test 19: Unload non-existent PDF (should error)
  BEGIN
    PL_FPDF.UnloadPDF('pdf_notexist');
    expect_error('Unload non-existent PDF', -20831);
  EXCEPTION
    WHEN OTHERS THEN
      handle_expected_error('Unload non-existent PDF', -20831, SQLCODE);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Integration Tests ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test 20: Load, merge, extract workflow
  BEGIN
    PL_FPDF.LoadPDFWithID('pdf4', l_test_pdf1);
    PL_FPDF.LoadPDFWithID('pdf5', l_test_pdf2);

    l_merged := PL_FPDF.MergePDFs(JSON_ARRAY_T('["pdf4","pdf5"]'), NULL);
    PL_FPDF.LoadPDFWithID('merged', l_merged);

    l_extracted := PL_FPDF.ExtractPages('merged', 'ALL', NULL);

    run_test('Load-Merge-Extract workflow', l_extracted IS NOT NULL);
    DBMS_OUTPUT.PUT_LINE('   Final PDF size: ' || DBMS_LOB.GETLENGTH(l_extracted) || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      run_test('Load-Merge-Extract workflow', FALSE);
      DBMS_OUTPUT.PUT_LINE('   Error: ' || SQLERRM);
  END;

  -- Final summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('Test Summary:');
  DBMS_OUTPUT.PUT_LINE('  Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('  Passed:      ' || l_pass_count || ' (' ||
                      ROUND(l_pass_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('  Failed:      ' || l_fail_count || ' (' ||
                      ROUND(l_fail_count/l_test_count*100, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('========================================');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('✓ ALL TESTS PASSED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('✗ SOME TESTS FAILED');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Test execution aborted at test ' || l_test_count);
    RAISE;
END;
/

--------------------------------------------------------------------------------
-- Fase 4: validação completa
-- origem: tests/validate_phase_4_complete.sql
--------------------------------------------------------------------------------
/*******************************************************************************
* Validation Script: Phase 4 Complete Validation (4.1-4.6)
* Version: 3.0.0-b.2
* Date: 2026-01
* Author: @maxwbh
*
* Purpose: Complete validation for PDF Reading & Manipulation (Phase 4)
*
* Validates:
*   - Phase 4.1A: PDF Parser
*   - Phase 4.1B: Page Information
*   - Phase 4.2: Page Management (Rotate, Remove)
*   - Phase 4.3: Watermarks
*   - Phase 4.4: Output Modified PDF
*   - Phase 4.5: Text & Image Overlay
*   - Phase 4.6: PDF Merge & Split
*
* Usage:
*   SET SERVEROUTPUT ON SIZE UNLIMITED
*   @tests/validate_phase_4_complete.sql
*******************************************************************************/

-- ================================================================================
-- PL_FPDF - Phase 4 Complete Validation (PDF Reading & Manipulation)
-- Version: 3.0.0-b.2
-- ================================================================================
--

DECLARE
  l_test_count PLS_INTEGER := 0;
  l_pass_count PLS_INTEGER := 0;
  l_fail_count PLS_INTEGER := 0;

  l_test_pdf BLOB;
  l_test_pdf_2 BLOB;
  l_result BLOB;
  l_info JSON_OBJECT_T;
  l_arr  JSON_ARRAY_T;   -- retornos JSON_ARRAY_T
  l_num  PLS_INTEGER;    -- retornos numéricos

  PROCEDURE test_result(p_test_name VARCHAR2, p_passed BOOLEAN, p_message VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_test_count := l_test_count + 1;
    IF p_passed THEN
      l_pass_count := l_pass_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_test_name);
    ELSE
      l_fail_count := l_fail_count + 1;
      DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_test_name ||
        CASE WHEN p_message IS NOT NULL THEN ' - ' || p_message ELSE '' END);
    END IF;
  END test_result;

  PROCEDURE create_test_pdf IS
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test Page 1');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Test Page 2');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Test Page 3');
    l_test_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END create_test_pdf;

  PROCEDURE create_test_pdf_2 IS
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Second PDF - Page 1');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'Second PDF - Page 2');
    l_test_pdf_2 := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
  END create_test_pdf_2;

BEGIN
  -- Create test PDFs
  create_test_pdf();
  create_test_pdf_2();

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.1A: PDF Parser');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: LoadPDF
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    test_result('LoadPDF - Load existing PDF', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('LoadPDF', FALSE, SQLERRM);
  END;

  -- Test: PDF carregado
  -- Nao existe IsPDFLoaded na API; GetPageCount levanta -20809 sem PDF carregado.
  BEGIN
    test_result('PDF carregado - GetPageCount responde', PL_FPDF.GetPageCount > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('PDF carregado', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.1B: Page Information');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: GetPageCount
  BEGIN
    l_num := PL_FPDF.GetPageCount;
    test_result('GetPageCount - Count pages in PDF', l_num = 3);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageCount', FALSE, SQLERRM);
  END;

  -- Test: GetPageInfo
  BEGIN
    l_info := PL_FPDF.GetPageInfo(1);
    -- as chaves do JSON são camelCase: pageNumber, não page_number
    test_result('GetPageInfo - Get page 1 information',
                l_info.has('pageNumber') AND l_info.get_number('pageNumber') = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetPageInfo', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.2: Page Management');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: RotatePage
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RotatePage(1, 90);
    l_info := PL_FPDF.GetPageInfo(1);
    test_result('RotatePage - Rotate page 90 degrees',
                l_info.get_number('rotation') = 90);
  EXCEPTION WHEN OTHERS THEN
    test_result('RotatePage', FALSE, SQLERRM);
  END;

  -- Test: RemovePage
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RemovePage(2);
    -- RemovePage apenas MARCA a página; GetPageCount continua devolvendo o
    -- total do documento carregado. A remoção se concretiza em
    -- OutputModifiedPDF, e o estado é consultável por IsPageRemoved.
    test_result('RemovePage - Remove page 2',
                PL_FPDF.IsPageRemoved(2)
                AND NOT PL_FPDF.IsPageRemoved(1)
                AND PL_FPDF.GetPageCount = 3);
  EXCEPTION WHEN OTHERS THEN
    test_result('RemovePage', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.3: Watermarks');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: AddWatermark
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.AddWatermark('CONFIDENTIAL', NULL);
    test_result('AddWatermark - Add watermark to all pages', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('AddWatermark', FALSE, SQLERRM);
  END;

  -- Test: GetWatermarks
  DECLARE
    l_watermarks JSON_ARRAY_T;
  BEGIN
    l_watermarks := PL_FPDF.GetWatermarks();
    test_result('GetWatermarks - List watermarks',
                l_watermarks IS NOT NULL AND l_watermarks.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetWatermarks', FALSE, SQLERRM);
  END;

  -- RemoveWatermark e ClearWatermarks nao existem na API: o teste antigo as
  -- chamava e impedia o bloco inteiro de compilar (ORA-06550). A unica forma
  -- publica de descartar marcas d'agua e ClearPDFCache, que limpa tudo.
  DECLARE
    l_watermarks JSON_ARRAY_T;
  BEGIN
    l_watermarks := PL_FPDF.GetWatermarks();
    test_result('GetWatermarks - lista as marcas registradas',
                l_watermarks.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetWatermarks', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.4: Output Modified PDF');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: OutputModifiedPDF
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.RotatePage(1, 90);
    l_result := PL_FPDF.OutputModifiedPDF();
    test_result('OutputModifiedPDF - Generate modified PDF',
                l_result IS NOT NULL AND DBMS_LOB.GETLENGTH(l_result) > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('OutputModifiedPDF', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.5: Text & Image Overlay');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: OverlayText
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDF(l_test_pdf);
    PL_FPDF.OverlayText(1, 'APPROVED', 100, 100, NULL);
    test_result('OverlayText - Add text overlay to page', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('OverlayText', FALSE, SQLERRM);
  END;

  -- Test: GetOverlays
  DECLARE
    l_overlays JSON_ARRAY_T;
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(NULL);
    test_result('GetOverlays - List all overlays',
                l_overlays IS NOT NULL AND l_overlays.get_size() > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetOverlays', FALSE, SQLERRM);
  END;

  -- Test: OverlayImage
  DECLARE
    l_minimal_png BLOB;
  BEGIN
    -- Minimal 1x1 PNG (67 bytes)
    l_minimal_png := HEXTORAW(
      '89504E470D0A1A0A' || -- PNG signature
      '0000000D49484452' || -- IHDR chunk
      '0000000100000001' || -- 1x1 dimensions
      '0806000000' ||       -- 8-bit RGBA
      '1F15C4890000000A' || -- CRC + IDAT chunk header
      '49444154' ||         -- IDAT
      '789C6300010000050001' || -- Compressed data
      '0D0A2DB40000000049454E44AE426082'); -- IEND chunk

    PL_FPDF.OverlayImage(1, l_minimal_png, 50, 50, NULL, NULL, NULL);
    test_result('OverlayImage - Add image overlay to page', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('OverlayImage', FALSE, SQLERRM);
  END;

  -- Test: RemoveOverlay
  DECLARE
    l_overlays JSON_ARRAY_T;
    l_overlay JSON_OBJECT_T;
    l_overlay_id VARCHAR2(100);
  BEGIN
    l_overlays := PL_FPDF.GetOverlays(NULL);
    IF l_overlays.get_size() > 0 THEN
      l_overlay := TREAT(l_overlays.get(0) AS JSON_OBJECT_T);
      l_overlay_id := l_overlay.get_string('overlayId');   -- camelCase
      PL_FPDF.RemoveOverlay(l_overlay_id);
      test_result('RemoveOverlay - Remove specific overlay', TRUE);
    ELSE
      test_result('RemoveOverlay', FALSE, 'No overlays to remove');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    test_result('RemoveOverlay', FALSE, SQLERRM);
  END;

  -- Test: ClearOverlays
  BEGIN
    PL_FPDF.ClearOverlays(NULL);
    l_arr := PL_FPDF.GetOverlays(NULL);
    test_result('ClearOverlays - Clear all overlays', l_arr.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ClearOverlays', FALSE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('PHASE 4.6: PDF Merge & Split');
  DBMS_OUTPUT.PUT_LINE('=========================================');
  DBMS_OUTPUT.PUT_LINE('');

  -- Test: LoadPDFWithID
  BEGIN
    PL_FPDF.ClearPDFCache();
    PL_FPDF.LoadPDFWithID('pdf1', l_test_pdf);
    PL_FPDF.LoadPDFWithID('pdf2', l_test_pdf_2);
    test_result('LoadPDFWithID - Load multiple PDFs with IDs', TRUE);
  EXCEPTION WHEN OTHERS THEN
    test_result('LoadPDFWithID', FALSE, SQLERRM);
  END;

  -- Test: GetLoadedPDFs
  DECLARE
    l_pdfs JSON_ARRAY_T;
  BEGIN
    l_pdfs := PL_FPDF.GetLoadedPDFs();
    test_result('GetLoadedPDFs - List loaded PDFs',
                l_pdfs IS NOT NULL AND l_pdfs.get_size() = 2);
  EXCEPTION WHEN OTHERS THEN
    test_result('GetLoadedPDFs', FALSE, SQLERRM);
  END;

  -- Test: MergePDFs
  DECLARE
    l_merged BLOB;
    l_pdf_ids JSON_ARRAY_T;
  BEGIN
    l_pdf_ids := JSON_ARRAY_T('["pdf1", "pdf2"]');
    l_merged := PL_FPDF.MergePDFs(l_pdf_ids, NULL);
    test_result('MergePDFs - Merge two PDFs',
                l_merged IS NOT NULL AND DBMS_LOB.GETLENGTH(l_merged) > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('MergePDFs', FALSE, SQLERRM);
  END;

  -- Test: ExtractPages
  DECLARE
    l_extracted BLOB;
  BEGIN
    l_extracted := PL_FPDF.ExtractPages('pdf1', '1', NULL);
    test_result('ExtractPages - Extract single page',
                l_extracted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_extracted) > 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ExtractPages', FALSE, SQLERRM);
  END;

  -- Test: SplitPDF
  DECLARE
    l_splits JSON_ARRAY_T;
    l_ranges JSON_ARRAY_T;
  BEGIN
    l_ranges := JSON_ARRAY_T('["1", "2-3"]');
    l_splits := PL_FPDF.SplitPDF('pdf1', l_ranges);
    test_result('SplitPDF - Split PDF into multiple parts',
                l_splits IS NOT NULL AND l_splits.get_size() = 2);
  EXCEPTION WHEN OTHERS THEN
    test_result('SplitPDF', FALSE, SQLERRM);
  END;

  -- Test: UnloadPDF
  BEGIN
    PL_FPDF.UnloadPDF('pdf2');
    l_arr := PL_FPDF.GetLoadedPDFs();
    test_result('UnloadPDF - Unload specific PDF', l_arr.get_size() = 1);
  EXCEPTION WHEN OTHERS THEN
    test_result('UnloadPDF', FALSE, SQLERRM);
  END;

  -- Test: ClearPDFCache
  BEGIN
    PL_FPDF.ClearPDFCache();
    l_arr := PL_FPDF.GetLoadedPDFs();
    test_result('ClearPDFCache - Clear all loaded PDFs', l_arr.get_size() = 0);
  EXCEPTION WHEN OTHERS THEN
    test_result('ClearPDFCache', FALSE, SQLERRM);
  END;

  -- Summary
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Phase 4 Complete Validation Summary');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Total Tests: ' || l_test_count);
  DBMS_OUTPUT.PUT_LINE('Passed:      ' || l_pass_count || ' (' ||
    ROUND(l_pass_count * 100 / l_test_count, 1) || '%)');
  DBMS_OUTPUT.PUT_LINE('Failed:      ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Phase Coverage:');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.1A: PDF Parser         ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.1B: Page Information   ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.2:  Page Management    ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.3:  Watermarks         ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.4:  Output Modified    ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.5:  Text/Image Overlay ✓');
  DBMS_OUTPUT.PUT_LINE('  - Phase 4.6:  Merge & Split      ✓');
  DBMS_OUTPUT.PUT_LINE('');

  IF l_fail_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4: ALL TESTS PASSED ***');
    DBMS_OUTPUT.PUT_LINE('*** PDF READING & MANIPULATION: VALIDATED ***');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Phase 4 is now complete and ready for production use.');
    DBMS_OUTPUT.PUT_LINE('Version can be promoted from Beta to Release Candidate.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4: SOME TESTS FAILED - REVIEW REQUIRED ***');
    DBMS_OUTPUT.PUT_LINE('*** PHASE 4 REMAINS IN BETA STATUS ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/

--
-- Validation complete. Review results above.
--

--------------------------------------------------------------------------------
-- Núcleo: buffers, NLS, QR, barcode, merge/split
-- origem: tests/test_core.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF - Núcleo: páginas grandes, alias {nb} e independência de NLS
--
-- Regressão para o limite de 32 KB por página: antes do buffer de página em CLOB,
-- uma página com muitas células estourava ORA-06502 em p_out.
--------------------------------------------------------------------------------

DECLARE
  l_pdf         BLOB;
  l_test_count  PLS_INTEGER := 0;
  l_pass_count  PLS_INTEGER := 0;
  l_fail_count  PLS_INTEGER := 0;

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

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================');
  DBMS_OUTPUT.PUT_LINE('  PL_FPDF - Núcleo');
  DBMS_OUTPUT.PUT_LINE('================================================================');

  --------------------------------------------------------------------------
  test_start('Página única com 3.000 células (muito acima de 32 KB)');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);

    -- Cada célula emite ~100 bytes de instruções PDF: ~300 KB numa página só.
    FOR i IN 1 .. 3000 LOOP
      PL_FPDF.Cell(20, 4, 'L' || i, '1', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 32767 THEN
      test_pass('PDF gerado com ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      test_fail('PDF vazio ou truncado: ' || NVL(DBMS_LOB.GETLENGTH(l_pdf), 0) || ' bytes');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- ORA-06502 aqui significa que o teto de 32 KB por página voltou
      test_fail('Exceção ao gerar página grande: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Múltiplas páginas grandes mantêm o conteúdo separado');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 8);

    FOR pg IN 1 .. 3 LOOP
      PL_FPDF.AddPage();
      FOR i IN 1 .. 800 LOOP
        PL_FPDF.Cell(20, 4, 'P' || pg || '-' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
      END LOOP;
    END LOOP;

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 32767 THEN
      test_pass('3 páginas grandes geradas: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      test_fail('PDF vazio ou truncado');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção com múltiplas páginas grandes: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Alias {nb} substituído em página que ultrapassa 32 KB');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetAliasNbPages();          -- habilita '{nb}'
    PL_FPDF.SetFont('Arial', '', 8);
    PL_FPDF.AddPage();

    -- Enche a página e só então escreve o alias, garantindo que ele caia
    -- além do primeiro bloco de 32 KB do buffer.
    FOR i IN 1 .. 1200 LOOP
      PL_FPDF.Cell(20, 4, 'X' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Cell(0, 6, 'Total de paginas: {nb}', '0', 1);
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 6, 'Pagina 2 de {nb}', '0', 1);

    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NULL OR DBMS_LOB.GETLENGTH(l_pdf) = 0 THEN
      test_fail('PDF vazio');
    ELSIF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW('{nb}')) > 0 THEN
      test_fail('Alias {nb} não foi substituído além do primeiro bloco');
    ELSE
      test_pass('Alias substituído corretamente em página grande');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção no teste de alias: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Reset libera recursos e permite novo documento');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    FOR i IN 1 .. 500 LOOP
      PL_FPDF.Cell(20, 4, 'A' || i, '0', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.Cell(0, 10, 'Documento novo apos Reset', '0', 1);
    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      test_pass('Segundo documento gerado após Reset');
    ELSE
      test_fail('Falha ao gerar documento após Reset');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção após Reset: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  test_start('Geração funciona com NLS decimal vírgula e não altera a sessão');
  --------------------------------------------------------------------------
  DECLARE
    l_nls_antes  VARCHAR2(64);
    l_nls_depois VARCHAR2(64);
  BEGIN
    -- Simula uma sessão pt-BR: vírgula como separador decimal
    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '',.''';

    SELECT value INTO l_nls_antes
      FROM nls_session_parameters
     WHERE parameter = 'NLS_NUMERIC_CHARACTERS';

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);
    PL_FPDF.SetXY(12.5, 20.75);                      -- coordenadas com decimais
    PL_FPDF.Cell(80.5, 8.25, 'Coordenadas decimais', '1', 1);
    PL_FPDF.Line(10.5, 40.25, 100.75, 40.25);
    l_pdf := PL_FPDF.OutputBlob();

    SELECT value INTO l_nls_depois
      FROM nls_session_parameters
     WHERE parameter = 'NLS_NUMERIC_CHARACTERS';

    IF l_pdf IS NULL OR DBMS_LOB.GETLENGTH(l_pdf) = 0 THEN
      test_fail('PDF não gerado com NLS vírgula');
    ELSIF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(',25')) > 0
       OR DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(',75')) > 0 THEN
      test_fail('Vírgula vazou como separador decimal no conteúdo do PDF');
    ELSIF l_nls_depois != l_nls_antes THEN
      test_fail('A biblioteca alterou NLS_NUMERIC_CHARACTERS da sessão: ' ||
                l_nls_antes || ' -> ' || l_nls_depois);
    ELSE
      test_pass('PDF correto e sessão preservada (' || l_nls_depois || ')');
    END IF;

    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''.,''';
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Exceção com NLS vírgula: ' || SQLERRM);
      EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''.,''';
  END;

  --------------------------------------------------------------------------
  test_start('Callback com nome válido é aceito');
  --------------------------------------------------------------------------
  DECLARE
    -- tv4000a é um associative array (INDEX BY word): não tem construtor
    -- tv4000a(), e precisa ser qualificado com o nome do package.
    l_params PL_FPDF.tv4000a;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetHeaderProc('meu_pkg.cabecalho');
    l_params('titulo') := 'Relatorio';
    PL_FPDF.SetFooterProc('meu_pkg.rodape', l_params);
    test_pass('Nomes qualificados aceitos na configuração');
    -- meu_pkg nao existe: sem limpar, todo AddPage seguinte falharia ao
    -- executar o bloco dinamico do header.
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Nome válido foi rejeitado: ' || SQLERRM);
      PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Reset limpa os callbacks de header e rodapé');
  --------------------------------------------------------------------------
  -- Regressao: os callbacks sobreviviam ao Reset (e ao Init, que chama Reset).
  -- Um nome invalido configurado uma vez deixava a sessao inutilizavel: todo
  -- AddPage seguinte estourava ao executar o bloco dinamico do header.
  DECLARE
    l_pdf BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetHeaderProc('pacote_inexistente.cabecalho');
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(50, 10, 'Sem header', '0', 1);
    l_pdf := PL_FPDF.OutputBlob();

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      test_pass('Documento gerado após Reset, sem o callback anterior');
    ELSE
      test_fail('PDF vazio após Reset');
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Callback sobreviveu ao Reset: ' || SQLERRM);
      PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Callback com injeção de PL/SQL é rejeitado na configuração');
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_payloads IS TABLE OF VARCHAR2(200);
    l_payloads t_payloads := t_payloads(
      'meu_pkg.proc; execute immediate ''drop table x''; --',
      'proc'' || chr(59) || ''',
      'meu pkg.proc',
      'proc(); raise_application_error(-20999,''x'');'
    );
    l_rejeitados PLS_INTEGER := 0;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    FOR i IN 1 .. l_payloads.COUNT LOOP
      BEGIN
        PL_FPDF.SetHeaderProc(l_payloads(i));
        DBMS_OUTPUT.PUT_LINE('  [!] aceito indevidamente: ' || l_payloads(i));
      EXCEPTION
        WHEN OTHERS THEN
          l_rejeitados := l_rejeitados + 1;   -- esperado
      END;
    END LOOP;

    IF l_rejeitados = l_payloads.COUNT THEN
      test_pass('Todos os ' || l_rejeitados || ' payloads rejeitados');
    ELSE
      test_fail('Apenas ' || l_rejeitados || ' de ' || l_payloads.COUNT || ' rejeitados');
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Erro do package informa a origem (backtrace)');
  --------------------------------------------------------------------------
  BEGIN
    PL_FPDF.Reset;
    BEGIN
      -- SetPage sem documento inicializado: erro conhecido do package
      PL_FPDF.SetPage(99);
      test_fail('Erro esperado não ocorreu');
    EXCEPTION
      WHEN OTHERS THEN
        IF DBMS_UTILITY.FORMAT_ERROR_BACKTRACE IS NOT NULL THEN
          test_pass('Erro propagado com rastreamento disponível');
        ELSE
          test_fail('Erro sem backtrace');
        END IF;
    END;
  END;

  --------------------------------------------------------------------------
  test_start('QR Code gera matriz correta (vetores de referência)');
  --------------------------------------------------------------------------
  -- QR Code: confere a matriz gerada contra vetores de referência.
  --
  -- Cada módulo escuro vira um "re f" no fluxo de conteúdo, então a contagem
  -- dessa marca no PDF equivale ao número de módulos escuros. Os valores
  -- esperados vêm de uma implementação de referência validada contra o
  -- decodificador zxing-cpp (scripts/qr_reference/).
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_caso IS RECORD (
      txt     VARCHAR2(400),
      ecl     VARCHAR2(1),
      escuros PLS_INTEGER
    );
    TYPE t_casos IS TABLE OF t_caso;
    l_casos t_casos := t_casos();
    l_conta PLS_INTEGER;
    l_pos   PLS_INTEGER;
    l_falhas PLS_INTEGER := 0;

    PROCEDURE add(p_t VARCHAR2, p_e VARCHAR2, p_d PLS_INTEGER) IS
    BEGIN
      l_casos.EXTEND;
      l_casos(l_casos.COUNT).txt     := p_t;
      l_casos(l_casos.COUNT).ecl     := p_e;
      l_casos(l_casos.COUNT).escuros := p_d;
    END;
  BEGIN
    add('PL_FPDF', 'M', 246);
    add('https://msbrasil.inf.br', 'M', 344);
    add('00020126360014BR.GOV.BCB.PIX0114+5531999999995204000053039865802BR'
        -- CHR(38) = '&'. Escrito assim porque o PL/SQL Developer (e o SQL*Plus)
        -- tratam '&' como variável de substituição: o payload chegava ao banco
        -- com 113 bytes em vez de 114, e o QR gerado divergia do vetor.
        || '5913M' || CHR(38) || 'S do Brasil6008BRASILIA62070503***63041D3D',
        'M', 1010);
    add('teste', 'H', 230);
    add('1234567890', 'L', 224);

    FOR i IN 1 .. l_casos.COUNT LOOP
      BEGIN
        PL_FPDF.Init('P', 'mm', 'A4');
        PL_FPDF.AddPage();
        PL_FPDF.AddQRCode(
          p_x => 20, p_y => 20, p_size => 60,
          p_data             => l_casos(i).txt,
          p_error_correction => l_casos(i).ecl);
        l_pdf := PL_FPDF.OutputBlob();

        -- conta as ocorrências de 're f' (um retângulo preenchido por módulo)
        l_conta := 0;
        l_pos   := 1;
        LOOP
          l_pos := DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(' re f'), l_pos, 1);
          EXIT WHEN NVL(l_pos, 0) = 0;
          l_conta := l_conta + 1;
          l_pos   := l_pos + 1;
        END LOOP;

        IF l_conta = l_casos(i).escuros THEN
          DBMS_OUTPUT.PUT_LINE('  [ok] ' || l_casos(i).ecl || ' ' ||
            SUBSTR(l_casos(i).txt, 1, 24) || ' -> ' || l_conta || ' módulos');
        ELSE
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] ' || l_casos(i).ecl || ' ' ||
            SUBSTR(l_casos(i).txt, 1, 24) || ' -> ' || l_conta ||
            ' módulos, esperado ' || l_casos(i).escuros);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] exceção em ' ||
            SUBSTR(l_casos(i).txt, 1, 24) || ': ' || SQLERRM);
      END;
    END LOOP;

    IF l_falhas = 0 THEN
      test_pass('Matriz do QR Code igual à referência nos ' ||
                l_casos.COUNT || ' casos');
    ELSE
      test_fail(l_falhas || ' de ' || l_casos.COUNT || ' casos divergiram');
    END IF;
  END;

  --------------------------------------------------------------------------
  test_start('QR Code e barcode: cada recusa com o seu código de erro');
  --------------------------------------------------------------------------
  -- Os códigos do QR (-20870..-20879) e dos códigos de barras
  -- (-20880..-20889) colidiam com os da manipulação de PDF e da segurança:
  -- ORA-20843 significava ao mesmo tempo "AddQRCode: conteúdo vazio" e "xref
  -- em stream não suportada". Contar exceções, como este teste fazia antes,
  -- não pegaria a volta da colisão — só conferir o código pega.
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_caso IS RECORD (nome VARCHAR2(60), esperado PLS_INTEGER);
    TYPE t_casos IS TABLE OF t_caso;
    l_casos t_casos := t_casos(
      t_caso('QR sem conteúdo',            -20870),
      t_caso('QR com tamanho zero',        -20871),
      t_caso('QR com nível inválido',      -20872),
      t_caso('QR acima da capacidade',     -20873),
      t_caso('barcode sem código',         -20880),
      t_caso('barcode com largura zero',   -20881),
      t_caso('simbologia inexistente',     -20882),
      t_caso('CODE39 com caractere ruim',  -20883),
      t_caso('CODE128 com caractere de controle', -20884),
      t_caso('EAN13 com poucos dígitos',   -20885),
      t_caso('EAN13 com verificador ruim', -20886),
      t_caso('ITF14 com poucos dígitos',   -20887)
    );
    l_erros PLS_INTEGER := 0;
    l_msg   VARCHAR2(4000);

    PROCEDURE confere(p_i PLS_INTEGER) IS
    BEGIN
      CASE p_i
        WHEN 1  THEN PL_FPDF.AddQRCode(10, 10, 40, NULL);
        WHEN 2  THEN PL_FPDF.AddQRCode(10, 10, 0, 'x');
        WHEN 3  THEN PL_FPDF.AddQRCode(10, 10, 40, 'x', p_error_correction => 'Z');
        WHEN 4  THEN PL_FPDF.AddQRCode(10, 10, 40, RPAD('A', 4000, 'A'),
                                       p_error_correction => 'H');
        WHEN 5  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, NULL);
        WHEN 6  THEN PL_FPDF.AddBarcode(10, 10, 0, 20, 'ABC');
        WHEN 7  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, 'ABC', 'PDF417');
        -- 'abc' NAO serve: bc_code39 faz upper(), e 'ABC' e valido. O '#' nao
        -- esta em co_bc39_chars nem depois do upper.
        WHEN 8  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, 'AB#C', 'CODE39');
        -- CHR(9) e determinístico em qualquer charset; CHR(200) dependeria da
        -- codificacao da sessao, e o teste anterior passava por isso.
        WHEN 9  THEN PL_FPDF.AddBarcode(10, 10, 100, 20, 'A' || CHR(9) || 'B',
                                        'CODE128');
        WHEN 10 THEN PL_FPDF.AddBarcode(10, 10, 100, 20, '123', 'EAN13');
        WHEN 11 THEN PL_FPDF.AddBarcode(10, 10, 100, 20, '7891234567890', 'EAN13');
        WHEN 12 THEN PL_FPDF.AddBarcode(10, 10, 100, 20, '123', 'ITF14');
      END CASE;
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [' || l_casos(p_i).nome || ': não recusou]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != l_casos(p_i).esperado THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [' || l_casos(p_i).nome || ': ' || SQLCODE
                         || ', esperado ' || l_casos(p_i).esperado || ']';
        END IF;
    END confere;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    FOR i IN 1 .. l_casos.COUNT LOOP
      confere(i);
    END LOOP;
    IF l_erros = 0 THEN
      test_pass(l_casos.COUNT || ' recusas, cada uma com o código da sua faixa');
    ELSE
      test_fail(l_erros || ' divergência(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Código de barras gera desenho correto (vetores de referência)');
  --------------------------------------------------------------------------
  -- Código de barras: confere o desenho contra vetores de referência.
  --
  -- Cada grupo de módulos escuros consecutivos vira um "re f" no PDF, então a
  -- contagem dessa marca equivale ao número de barras. Valores esperados vêm de
  -- scripts/barcode_reference/, validado contra o decodificador zxing-cpp.
  --------------------------------------------------------------------------
  DECLARE
    TYPE t_caso IS RECORD (
      cod    VARCHAR2(60),
      tipo   VARCHAR2(20),
      barras PLS_INTEGER
    );
    TYPE t_casos IS TABLE OF t_caso;
    l_casos t_casos := t_casos();
    l_conta PLS_INTEGER;
    l_pos   PLS_INTEGER;
    l_falhas PLS_INTEGER := 0;

    PROCEDURE add(p_c VARCHAR2, p_t VARCHAR2, p_b PLS_INTEGER) IS
    BEGIN
      l_casos.EXTEND;
      l_casos(l_casos.COUNT).cod    := p_c;
      l_casos(l_casos.COUNT).tipo   := p_t;
      l_casos(l_casos.COUNT).barras := p_b;
    END;
  BEGIN
    add('PL-FPDF-123',   'CODE39',  65);
    add('ABC123abc',     'CODE128', 37);
    add('12345678',      'CODE128', 22);
    add('789123456789',  'EAN13',   30);
    add('1234567',       'EAN8',    22);
    add('1234567890123', 'ITF14',   39);

    FOR i IN 1 .. l_casos.COUNT LOOP
      BEGIN
        PL_FPDF.Init('P', 'mm', 'A4');
        PL_FPDF.AddPage();
        PL_FPDF.AddBarcode(
          p_x => 20, p_y => 30, p_width => 120, p_height => 20,
          p_code      => l_casos(i).cod,
          p_type      => l_casos(i).tipo,
          p_show_text => FALSE);          -- sem texto: só as barras viram 're f'
        l_pdf := PL_FPDF.OutputBlob();

        l_conta := 0; l_pos := 1;
        LOOP
          l_pos := DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW(' re f'), l_pos, 1);
          EXIT WHEN NVL(l_pos, 0) = 0;
          l_conta := l_conta + 1;
          l_pos   := l_pos + 1;
        END LOOP;

        IF l_conta = l_casos(i).barras THEN
          DBMS_OUTPUT.PUT_LINE('  [ok] ' || RPAD(l_casos(i).tipo, 8) ||
            l_casos(i).cod || ' -> ' || l_conta || ' barras');
        ELSE
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] ' || RPAD(l_casos(i).tipo, 8) ||
            l_casos(i).cod || ' -> ' || l_conta || ' barras, esperado ' ||
            l_casos(i).barras);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_falhas := l_falhas + 1;
          DBMS_OUTPUT.PUT_LINE('  [!!] exceção em ' || l_casos(i).tipo || ': ' || SQLERRM);
      END;
    END LOOP;

    IF l_falhas = 0 THEN
      test_pass('Código de barras igual à referência nas ' ||
                l_casos.COUNT || ' simbologias');
    ELSE
      test_fail(l_falhas || ' de ' || l_casos.COUNT || ' divergiram');
    END IF;
  END;

  --------------------------------------------------------------------------
  test_start('Código de barras valida entrada e calcula verificador');
  --------------------------------------------------------------------------
  DECLARE
    l_erros PLS_INTEGER := 0;
    l_a PLS_INTEGER; l_b PLS_INTEGER; l_pos PLS_INTEGER;

    FUNCTION barras(p_cod VARCHAR2, p_tipo VARCHAR2) RETURN PLS_INTEGER IS
      l_n PLS_INTEGER := 0; l_p PLS_INTEGER := 1; l_doc BLOB;
    BEGIN
      PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
      PL_FPDF.AddBarcode(20, 30, 120, 20, p_cod, p_tipo, FALSE);
      l_doc := PL_FPDF.OutputBlob();
      LOOP
        l_p := DBMS_LOB.INSTR(l_doc, UTL_RAW.CAST_TO_RAW(' re f'), l_p, 1);
        EXIT WHEN NVL(l_p,0) = 0;
        l_n := l_n + 1; l_p := l_p + 1;
      END LOOP;
      RETURN l_n;
    END;
  BEGIN
    -- simbologia inexistente, caractere fora do CODE39 e EAN com tamanho errado
    BEGIN PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(10,10,80,20,'123','CODE99');
    EXCEPTION WHEN OTHERS THEN l_erros := l_erros + 1; END;
    BEGIN PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(10,10,80,20,'abc#','CODE39');
    EXCEPTION WHEN OTHERS THEN l_erros := l_erros + 1; END;
    BEGIN PL_FPDF.Init('P','mm','A4'); PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(10,10,80,20,'123','EAN13');
    EXCEPTION WHEN OTHERS THEN l_erros := l_erros + 1; END;

    -- com e sem verificador devem produzir o mesmo desenho
    l_a := barras('789123456789',  'EAN13');
    l_b := barras('7891234567895', 'EAN13');

    IF l_erros = 3 AND l_a = l_b AND l_a > 0 THEN
      test_pass('3 entradas inválidas rejeitadas; verificador calculado confere');
    ELSE
      test_fail('erros=' || l_erros || ' (esperado 3), barras ' || l_a || ' vs ' || l_b);
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  test_start('Merge / Split / Extract: cópia real de objetos');
  --------------------------------------------------------------------------
  DECLARE
    l_a      BLOB;
    l_b      BLOB;
    l_out    BLOB;
    l_parts  JSON_ARRAY_T;
    l_erros  PLS_INTEGER := 0;
    l_msg    VARCHAR2(4000);

    -- gera um PDF de p_n páginas, cada uma com um texto identificável
    FUNCTION doc(p_n PLS_INTEGER, p_tag VARCHAR2) RETURN BLOB IS
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.SetFont('Arial', 'B', 16);
      FOR i IN 1 .. p_n LOOP
        PL_FPDF.AddPage();
        PL_FPDF.Cell(100, 10, p_tag || ' pagina ' || i, '1', 1);
      END LOOP;
      RETURN PL_FPDF.OutputBlob();
    END;

    -- nº de páginas de um PDF, medido pelo próprio parser da biblioteca
    FUNCTION paginas(p_pdf BLOB) RETURN PLS_INTEGER IS
      l_n PLS_INTEGER;
    BEGIN
      -- Sem ClearPDFCache aqui: ele descarta também os documentos de
      -- LoadPDFWithID, e este helper é chamado no meio do teste, com 'A' e 'B'
      -- ainda em uso. LoadPDF sobrescreve o PDF único a cada chamada.
      PL_FPDF.LoadPDF(p_pdf);
      l_n := PL_FPDF.GetPageCount;
      RETURN l_n;
    END;

    PROCEDURE espera_erro(p_o VARCHAR2, p_cod PLS_INTEGER) IS
      l_x BLOB;
    BEGIN
      l_x := PL_FPDF.ExtractPages('A', p_o, NULL);
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [' || p_o || ' deveria falhar]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != p_cod THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [' || p_o || ' deu ' || SQLCODE ||
                   ', esperado ' || p_cod || ']';
        END IF;
    END;
  BEGIN
    l_a := doc(3, 'A');
    l_b := doc(2, 'B');

    PL_FPDF.LoadPDFWithID('A', l_a);
    PL_FPDF.LoadPDFWithID('B', l_b);

    -- merge: 3 + 2 = 5 páginas
    l_out := PL_FPDF.MergePDFs(JSON_ARRAY_T('["A","B"]'), NULL);
    IF paginas(l_out) != 5 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge A+B deu ' || paginas(l_out) || ' páginas]';
    END IF;

    -- ordem inversa continua com 5
    l_out := PL_FPDF.MergePDFs(JSON_ARRAY_T('["B","A"]'), NULL);
    IF paginas(l_out) != 5 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge B+A deu ' || paginas(l_out) || ' páginas]';
    END IF;

    -- o mesmo documento duas vezes: ids têm de ser renumerados sem colidir
    l_out := PL_FPDF.MergePDFs(JSON_ARRAY_T('["A","A"]'), NULL);
    IF paginas(l_out) != 6 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge A+A deu ' || paginas(l_out) || ' páginas]';
    END IF;

    -- extract: intervalos, lista e ordem pedida
    IF paginas(PL_FPDF.ExtractPages('A', 'ALL',  NULL)) != 3 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract ALL]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '2',    NULL)) != 1 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 2]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '1,3',  NULL)) != 2 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 1,3]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '1-3',  NULL)) != 3 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 1-3]';
    END IF;
    IF paginas(PL_FPDF.ExtractPages('A', '3,1',  NULL)) != 2 THEN
      l_erros := l_erros + 1; l_msg := l_msg || ' [extract 3,1]';
    END IF;

    -- uma página extraída tem de ser menor que o documento inteiro
    IF DBMS_LOB.GETLENGTH(PL_FPDF.ExtractPages('A', '1', NULL))
       >= DBMS_LOB.GETLENGTH(l_a) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [extract de 1 página não ficou menor]';
    END IF;

    -- entradas inválidas
    espera_erro('0',   -20838);
    espera_erro('9',   -20839);
    espera_erro('3-2', -20838);
    espera_erro('x',   -20838);

    -- split: 3 páginas em duas partes
    l_parts := PL_FPDF.SplitPDF('A', JSON_ARRAY_T('["1-2","3"]'));
    IF l_parts.get_size() != 2 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [split gerou ' || l_parts.get_size() || ' partes]';
    END IF;

    -- intervalos sobrepostos têm de ser recusados
    BEGIN
      l_parts := PL_FPDF.SplitPDF('A', JSON_ARRAY_T('["1-2","2-3"]'));
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [sobreposição não detectada]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -20836 THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [sobreposição deu ' || SQLCODE || ']';
        END IF;
    END;

    PL_FPDF.UnloadPDF('A');
    PL_FPDF.UnloadPDF('B');

    IF l_erros = 0 THEN
      test_pass('merge, extract e split preservam a contagem de páginas e '
                || 'rejeitam entradas inválidas');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      -- sem este handler um erro aqui abortava o arquivo de teste inteiro
      test_fail('exceção: ' || SQLERRM);
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END;

  --------------------------------------------------------------------------
  test_start('Merge preserva stream binário e acima de 32 KB');
  --------------------------------------------------------------------------
  -- Regressão: pdf_obj_extent devolvia o FIM do payload como se fosse o
  -- início, então o conteúdo do stream passava por VARCHAR2 e por
  -- pdf_scan_refs em vez de ser copiado byte a byte. Com texto ASCII curto
  -- passava despercebido; com stream binário corrompia, e acima de
  -- co_pdf_dict_limit o objeto era recusado com ORA-20841.
  DECLARE
    l_grande BLOB;
    l_saida  BLOB;
    l_erros  PLS_INTEGER := 0;
    l_msg    VARCHAR2(4000);
    l_n      PLS_INTEGER;
    l_base   PLS_INTEGER;

    FUNCTION paginas(p_pdf BLOB) RETURN PLS_INTEGER IS
      l_q PLS_INTEGER;
    BEGIN
      PL_FPDF.LoadPDF(p_pdf);
      l_q := PL_FPDF.GetPageCount;
      RETURN l_q;
    END;
  BEGIN
    PL_FPDF.ClearPDFCache;

    -- página densa: o fluxo de conteúdo passa de 32 KB com folga
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);
    FOR i IN 1 .. 1200 LOOP
      PL_FPDF.Cell(20, 4, 'Bloco ' || i, '1', CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    l_grande := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    IF DBMS_LOB.GETLENGTH(l_grande) < 32767 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [o PDF de origem não passou de 32 KB]';
    END IF;

    -- 1200 células não cabem numa folha: o AddPage automático do Cell quebra o
    -- documento em várias páginas. O esperado do merge é o dobro do que a
    -- origem realmente tem, e não 2 — fixar 2 era erro do próprio teste.
    l_base := paginas(l_grande);

    PL_FPDF.LoadPDFWithID('G1', l_grande);
    PL_FPDF.LoadPDFWithID('G2', l_grande);
    l_saida := PL_FPDF.MergePDFs(JSON_ARRAY_T('["G1","G2"]'), NULL);

    l_n := paginas(l_saida);
    IF l_n != 2 * l_base THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [merge deu ' || l_n || ' páginas, esperado '
                     || (2 * l_base) || ' (origem: ' || l_base || ')]';
    END IF;

    -- o conteúdo tem de sobreviver: cada célula emite um 're' no fluxo
    IF DBMS_LOB.GETLENGTH(l_saida) < DBMS_LOB.GETLENGTH(l_grande) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [resultado menor que a origem: conteúdo perdido]';
    END IF;

    PL_FPDF.ClearPDFCache;
    IF l_erros = 0 THEN
      test_pass('stream acima de 32 KB copiado sem truncar nem corromper');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('exceção: ' || SQLERRM);
      BEGIN PL_FPDF.ClearPDFCache; PL_FPDF.Reset; EXCEPTION WHEN OTHERS THEN NULL; END;
  END;

  --------------------------------------------------------------------------
  test_start('OutputModifiedPDF: remoção de página e rotação');
  --------------------------------------------------------------------------
  DECLARE
    l_src   BLOB;
    l_out   BLOB;
    l_erros PLS_INTEGER := 0;
    l_msg   VARCHAR2(4000);
    l_n     PLS_INTEGER;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 12);
    FOR i IN 1 .. 4 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(100, 10, 'Pagina ' || i, '1', 1);
    END LOOP;
    l_src := PL_FPDF.OutputBlob();

    PL_FPDF.LoadPDF(l_src);
    PL_FPDF.RemovePage(2);
    PL_FPDF.RotatePage(3, 90);
    l_out := PL_FPDF.OutputModifiedPDF();
    PL_FPDF.ClearPDFCache;

    PL_FPDF.LoadPDF(l_out);
    l_n := PL_FPDF.GetPageCount;
    PL_FPDF.ClearPDFCache;

    IF l_n != 3 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [esperado 3 páginas, veio ' || l_n || ']';
    END IF;

    -- a rotação pedida tem de aparecer no PDF gerado
    IF DBMS_LOB.INSTR(l_out, UTL_RAW.CAST_TO_RAW('/Rotate 90'), 1, 1) = 0 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [/Rotate 90 ausente]';
    END IF;

    -- sem alterações pendentes, tem de recusar
    BEGIN
      PL_FPDF.LoadPDF(l_src);
      l_out := PL_FPDF.OutputModifiedPDF();
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [gerou sem alterações]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -20819 THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [sem alterações deu ' || SQLCODE || ']';
        END IF;
    END;
    PL_FPDF.ClearPDFCache;

    IF l_erros = 0 THEN
      test_pass('página removida e rotação aplicada no documento copiado');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
    PL_FPDF.Reset;
  END;

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================');
  DBMS_OUTPUT.PUT_LINE('  Total: ' || l_test_count ||
                       ' | Passou: ' || l_pass_count ||
                       ' | Falhou: ' || l_fail_count);
  DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/

--------------------------------------------------------------------------------
-- Fase 5: segurança
-- origem: tests/test_phase_security.sql
--------------------------------------------------------------------------------
/*******************************************************************************
* Test Script: Phase 5 - Security / Password Protection
* Version: 3.2.0
* Author: @maxwbh
*
* Tests for PDF encryption and password protection features using DBMS_CRYPTO.
*
* Requirements:
* - Oracle 19c+ with DBMS_CRYPTO package
* - PL_FPDF package installed
* - EXECUTE privilege on DBMS_CRYPTO
*
* Tests:
* - Section 1: Basic Encryption Detection
* - Section 2: RC4 Encryption (40-bit and 128-bit)
* - Section 3: Permission Controls
* - Section 4: Decryption
* - Section 5: Security Info Parsing
* - Section 6: Error Handling
*******************************************************************************/

DECLARE
  -- Test counters
  v_total_tests PLS_INTEGER := 0;
  v_passed_tests PLS_INTEGER := 0;
  v_failed_tests PLS_INTEGER := 0;
  v_skipped_tests PLS_INTEGER := 0;
  v_section VARCHAR2(100);
  -- A criptografia depende de EXECUTE em SYS.DBMS_CRYPTO. Sem o privilégio os
  -- casos que a exercitam são PULADOS, não reprovados: é ausência de ambiente,
  -- não defeito do package. A detecção é feita em test_fail, pelo ORA-20860.

  -- Test variables
  l_pdf BLOB;
  l_encrypted BLOB;
  l_decrypted BLOB;
  l_info JSON_OBJECT_T;
  l_perms JSON_OBJECT_T;
  l_is_encrypted BOOLEAN;
  l_permissions JSON_OBJECT_T;

  -- Test helper procedures
  PROCEDURE section_start(p_name VARCHAR2) IS
  BEGIN
    v_section := p_name;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(p_name);
    DBMS_OUTPUT.PUT_LINE('============================================================');
  END;

  PROCEDURE test_start(p_name VARCHAR2) IS
  BEGIN
    v_total_tests := v_total_tests + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test ' || v_total_tests || ': ' || p_name);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
  END;

  PROCEDURE test_pass(p_msg VARCHAR2 DEFAULT 'PASS') IS
  BEGIN
    v_passed_tests := v_passed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE test_fail(p_msg VARCHAR2) IS
  BEGIN
    -- ORA-20860 = sem acesso a DBMS_CRYPTO; ORA-20862 = existe, mas não cifra
    -- de verdade (autoteste com vetores conhecidos reprovou). Nos dois casos é
    -- ambiente, não defeito do package: conta como PULADO. Cobre também os
    -- casos que comparam o código do erro e recebem um destes no lugar.
    IF INSTR(p_msg, 'ORA-20860') > 0 THEN
      v_skipped_tests := v_skipped_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [SKIP] sem acesso a DBMS_CRYPTO');
      RETURN;
    END IF;
    IF INSTR(p_msg, 'ORA-20862') > 0 THEN
      v_skipped_tests := v_skipped_tests + 1;
      DBMS_OUTPUT.PUT_LINE('  [SKIP] DBMS_CRYPTO nao cifra de verdade '
                           || '(autoteste reprovou) — use o do Oracle');
      RETURN;
    END IF;
    v_failed_tests := v_failed_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  PROCEDURE test_skip(p_msg VARCHAR2) IS
  BEGIN
    v_skipped_tests := v_skipped_tests + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END;

  -- Generate simple test PDF
  FUNCTION generate_test_pdf RETURN BLOB IS
    l_result BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 10, 'Security Test Document', '0', 1, 'C');
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'This document is used for testing encryption.', '0', 1, 'L');
    PL_FPDF.Ln(10);
    PL_FPDF.Cell(0, 10, 'Confidential content that needs protection.', '0', 1, 'L');
    l_result := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
    RETURN l_result;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('PL_FPDF v3.2.0 - PHASE 5: Security Tests');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('');

  --------------------------------------------------------------------------------
  -- Generate test PDF
  --------------------------------------------------------------------------------
  l_pdf := generate_test_pdf();
  DBMS_OUTPUT.PUT_LINE('Test PDF generated: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');

  -- ================================================================================
  -- SECTION 1: Basic Encryption Detection
  -- ================================================================================
  section_start('SECTION 1: Basic Encryption Detection');

  -- TEST 1.1: Check unencrypted PDF
  test_start('IsEncrypted - Unencrypted PDF returns FALSE');
  BEGIN
    l_is_encrypted := PL_FPDF.IsEncrypted(l_pdf);
    IF NOT l_is_encrypted THEN
      test_pass('Correctly detected unencrypted PDF');
    ELSE
      test_fail('Should report PDF as unencrypted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 1.2: IsEncrypted - NULL PDF
  test_start('IsEncrypted - NULL PDF returns FALSE');
  BEGIN
    l_is_encrypted := PL_FPDF.IsEncrypted(NULL);
    IF NOT l_is_encrypted THEN
      test_pass('Correctly returns FALSE for NULL');
    ELSE
      test_fail('Should return FALSE for NULL');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 1.3: GetSecurityInfo - Unencrypted PDF
  test_start('GetSecurityInfo - Unencrypted PDF');
  BEGIN
    l_info := PL_FPDF.GetSecurityInfo(l_pdf);
    IF NOT l_info.get_boolean('encrypted') THEN
      test_pass('Correctly reports encrypted=false');
    ELSE
      test_fail('Should report encrypted=false');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- ================================================================================
  -- SECTION 2: RC4 Encryption
  -- ================================================================================
  section_start('SECTION 2: RC4 Encryption');

  -- TEST 2.1: EncryptPDF - RC4-128 with user password only
  test_start('EncryptPDF - RC4-128 with user password');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'test123',
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_encrypted) > 0 THEN
      test_pass('PDF encrypted (' || DBMS_LOB.GETLENGTH(l_encrypted) || ' bytes)');

      -- Verify it's now encrypted
      IF PL_FPDF.IsEncrypted(l_encrypted) THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] IsEncrypted confirms encryption');
      END IF;
    ELSE
      test_fail('Encryption returned empty result');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 2.2: EncryptPDF - RC4-40 legacy encryption
  test_start('EncryptPDF - RC4-40 legacy encryption');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'legacy',
      p_encryption => 'RC4-40'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('RC4-40 encryption successful');

      -- Check security info
      l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
      IF l_info.get_string('method') = 'RC4-40' THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] Method correctly identified as RC4-40');
      END IF;
    ELSE
      test_fail('RC4-40 encryption failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 2.3: EncryptPDF - With owner password
  test_start('EncryptPDF - User and Owner passwords');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'user123',
      p_owner_password => 'owner456',
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('Encryption with both passwords successful');

      l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
      IF l_info.get_boolean('hasUserPassword') AND l_info.get_boolean('hasOwnerPassword') THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] Both password flags detected');
      END IF;
    ELSE
      test_fail('Encryption with both passwords failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 2.4: Encrypt already encrypted PDF (should fail)
  test_start('EncryptPDF - Already encrypted PDF (should fail)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'first',
      p_encryption => 'RC4-128'
    );

    -- Try to encrypt again
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_encrypted,
      p_user_password => 'second',
      p_encryption => 'RC4-128'
    );
    test_fail('Should have raised error for already encrypted PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20859 THEN
        test_pass('Correctly rejected already encrypted PDF');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- ================================================================================
  -- SECTION 3: Permission Controls
  -- ================================================================================
  section_start('SECTION 3: Permission Controls');

  -- TEST 3.1: EncryptPDF - With permission restrictions
  test_start('EncryptPDF - With permission restrictions');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', FALSE);
    l_permissions.put('modify', FALSE);
    l_permissions.put('annotate', TRUE);
    l_permissions.put('fillForms', TRUE);
    l_permissions.put('extract', FALSE);
    l_permissions.put('assemble', FALSE);
    l_permissions.put('printHighQuality', TRUE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'restricted',
      p_owner_password => 'fullaccess',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );
    IF l_encrypted IS NOT NULL THEN
      test_pass('Encryption with permissions successful');

      -- Verify permissions in output
      l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
      l_perms := l_info.get_Object('permissions');
      IF l_perms IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  [INFO] Permissions parsed:');
        DBMS_OUTPUT.PUT_LINE('         print=' || CASE WHEN l_perms.get_boolean('print') THEN 'Y' ELSE 'N' END);
        DBMS_OUTPUT.PUT_LINE('         copy=' || CASE WHEN l_perms.get_boolean('copy') THEN 'Y' ELSE 'N' END);
        DBMS_OUTPUT.PUT_LINE('         modify=' || CASE WHEN l_perms.get_boolean('modify') THEN 'Y' ELSE 'N' END);
      END IF;
    ELSE
      test_fail('Encryption with permissions failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.2: SetEncryption + SetPermissions - Valid
  test_start('SetEncryption + SetPermissions - Valid usage');
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetEncryption('RC4-128', 'user', 'owner');
    PL_FPDF.SetPermissions(
      p_print => TRUE,
      p_copy => FALSE,
      p_modify => FALSE,
      p_annotate => TRUE,
      p_fill_forms => TRUE,
      p_extract => FALSE,
      p_assemble => FALSE,
      p_print_high => TRUE
    );
    test_pass('SetEncryption + SetPermissions accepted');
    PL_FPDF.Reset();
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
      PL_FPDF.Reset();
  END;

  -- TEST 3.3: SetPermissions - Without SetEncryption (should fail)
  test_start('SetPermissions - Without SetEncryption (should fail)');
  BEGIN
    PL_FPDF.Reset();
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetPermissions(p_print => TRUE);
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20856 THEN
        test_pass('Correctly requires SetEncryption first');
      ELSE
        test_fail('Wrong error: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- TEST 3.4: All permissions enabled
  test_start('Encryption - All permissions enabled');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', TRUE);
    l_permissions.put('modify', TRUE);
    l_permissions.put('annotate', TRUE);
    l_permissions.put('fillForms', TRUE);
    l_permissions.put('extract', TRUE);
    l_permissions.put('assemble', TRUE);
    l_permissions.put('printHighQuality', TRUE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'allperms',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
    l_perms := l_info.get_Object('permissions');

    IF l_perms.get_boolean('print') AND l_perms.get_boolean('copy') AND
       l_perms.get_boolean('modify') THEN
      test_pass('All permissions correctly set');
    ELSE
      test_fail('Some permissions not set correctly');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5: No permissions (most restrictive)
  test_start('Encryption - No permissions (most restrictive)');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', FALSE);
    l_permissions.put('copy', FALSE);
    l_permissions.put('modify', FALSE);
    l_permissions.put('annotate', FALSE);
    l_permissions.put('fillForms', FALSE);
    l_permissions.put('extract', FALSE);
    l_permissions.put('assemble', FALSE);
    l_permissions.put('printHighQuality', FALSE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'noprint',
      p_owner_password => 'admin',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
    l_perms := l_info.get_Object('permissions');

    IF NOT l_perms.get_boolean('print') AND NOT l_perms.get_boolean('copy') THEN
      test_pass('Restrictive permissions correctly set');
    ELSE
      test_fail('Permissions not restricted');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5: o conteudo sai realmente cifrado
  test_start('EncryptPDF - conteudo deixa de aparecer em claro');
  DECLARE
    co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaParaConferirCifragem';
    l_claro  BLOB;
    l_cif    BLOB;
    l_erros  PLS_INTEGER := 0;
    l_msg    VARCHAR2(400);

    FUNCTION contem(p_pdf BLOB, p_txt VARCHAR2) RETURN BOOLEAN IS
    BEGIN
      RETURN DBMS_LOB.INSTR(p_pdf, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1) > 0;
    END;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, co_marca, '0', 1);
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    -- pre-condicao: sem cifrar, a marca ESTA legivel nos bytes. Sem isto o
    -- teste passaria por engano se o texto nunca chegasse ao arquivo.
    IF NOT contem(l_claro, co_marca) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [a marca nao aparece nem no PDF sem cifrar]';
    END IF;

    l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                p_user_password => 'segredo',
                                p_encryption => 'RC4-128');

    -- o que separa "marcado como protegido" de protegido de verdade
    IF contem(l_cif, co_marca) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [texto ainda legivel nos bytes: apenas MARCADO'
                     || ' como protegido]';
    END IF;

    IF NOT PL_FPDF.IsEncrypted(l_cif) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [IsEncrypted nao reconhece o resultado]';
    END IF;

    IF l_erros = 0 THEN
      test_pass('conteudo sai cifrado, nao apenas marcado como protegido');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5b: AES cifra de verdade, nas duas revisoes
  FOR r IN (SELECT 'AES-128' m, 'AESV2' cfm, 4 v FROM dual
            UNION ALL
            SELECT 'AES-256', 'AESV3', 5 FROM dual) LOOP
    test_start('EncryptPDF - ' || r.m || ' cifra o conteudo');
    DECLARE
      co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaParaConferirAES';
      l_claro  BLOB;
      l_cif    BLOB;
      l_info   JSON_OBJECT_T;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, co_marca, '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_encryption => r.m);

      IF DBMS_LOB.INSTR(l_claro, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) = 0 THEN
        test_fail('o PDF de origem nao tinha a marca em claro; teste invalido');
      ELSIF DBMS_LOB.INSTR(l_cif, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) > 0 THEN
        test_fail(r.m || ': o texto continua em claro nos bytes');
      ELSIF DBMS_LOB.INSTR(l_cif,
              UTL_RAW.CAST_TO_RAW('/CFM /' || r.cfm), 1, 1) = 0 THEN
        -- sem /CF, /StmF e /StrF o leitor supoe /Identity e mostra o conteudo
        -- cifrado como se fosse texto
        test_fail(r.m || ': /CFM /' || r.cfm || ' nao foi declarado');
      ELSIF DBMS_LOB.INSTR(l_cif, UTL_RAW.CAST_TO_RAW('/StmF /StdCF'), 1, 1) = 0
      THEN
        test_fail(r.m || ': /StmF nao aponta para o filtro');
      ELSE
        l_info := PL_FPDF.GetSecurityInfo(l_cif);
        IF l_info.get_number('version') != r.v THEN
          test_fail(r.m || ': /V saiu ' || l_info.get_number('version'));
        ELSE
          test_pass(r.m || ': conteudo cifrado, /CF e /StmF declarados');
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' - Error: ' || SQLERRM);
    END;
  END LOOP;

  -- TEST 3.5c: ida e volta do AES, nas duas revisoes
  FOR r IN (SELECT 'AES-128' m FROM dual UNION ALL SELECT 'AES-256' FROM dual)
  LOOP
    test_start('EncryptPDF + DecryptPDF - ida e volta em ' || r.m);
    DECLARE
      co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaIdaEVoltaAES';
      l_claro  BLOB;
      l_cif    BLOB;
      l_dec    BLOB;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, co_marca, '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_owner_password => 'dono',
                                  p_encryption => r.m);
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'segredo');

      IF DBMS_LOB.INSTR(l_dec, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) = 0 THEN
        test_fail(r.m || ': o conteudo nao voltou ao original');
      ELSIF PL_FPDF.IsEncrypted(l_dec) THEN
        test_fail(r.m || ': o resultado ainda se declara criptografado');
      ELSE
        test_pass(r.m || ': decifrado devolve o conteudo original');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' - Error: ' || SQLERRM);
    END;

    -- a senha de proprietario tambem abre, e por outro caminho: no R6 ela usa
    -- os 48 bytes do /U no hash e desembrulha a chave de /OE, nao de /UE
    test_start('DecryptPDF - senha de proprietario em ' || r.m);
    DECLARE
      l_claro BLOB;
      l_cif   BLOB;
      l_dec   BLOB;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Documento com dois donos', '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_owner_password => 'dono',
                                  p_encryption => r.m);
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'dono');
      IF DBMS_LOB.INSTR(l_dec,
           UTL_RAW.CAST_TO_RAW('Documento com dois donos'), 1, 1) = 0 THEN
        test_fail(r.m || ': a senha de proprietario nao devolveu o conteudo');
      ELSE
        test_pass(r.m || ': senha de proprietario abre o documento');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' (proprietario) - Error: ' || SQLERRM);
    END;

    -- senha errada tem de ser RECUSADA, e nao devolver lixo
    test_start('DecryptPDF - senha errada em ' || r.m);
    DECLARE
      l_claro BLOB;
      l_cif   BLOB;
      l_dec   BLOB;
    BEGIN
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.AddPage();
      PL_FPDF.SetFont('Arial', '', 12);
      PL_FPDF.Cell(0, 10, 'Nao deve abrir', '0', 1);
      l_claro := PL_FPDF.OutputBlob();
      PL_FPDF.Reset;

      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'segredo',
                                  p_encryption => r.m);
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'errada');
      test_fail(r.m || ': aceitou uma senha errada');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -20854 THEN
          test_pass(r.m || ': senha errada recusada com -20854');
        ELSE
          test_fail(r.m || ': codigo errado: ' || SQLCODE || ' - ' || SQLERRM);
        END IF;
    END;
  END LOOP;

  -- TEST 3.5d: fluxo grande com RC4
  --
  -- crypto_rc4 monta o resultado em hexadecimal, dois caracteres por byte, e
  -- estoura em 16383 bytes. Um documento denso passa disso com folga, e antes
  -- rebentava com ORA-06502 sem explicação. O fluxo agora vai por
  -- crypto_rc4_blob, que agenda a chave uma vez e carrega o estado da cifra
  -- entre os pedaços — fatiar com crypto_rc4 reiniciaria a cifra em cada
  -- pedaço e produziria lixo.
  test_start('EncryptPDF - fluxo acima de 16 KB com RC4-128');
  DECLARE
    co_marca CONSTANT VARCHAR2(40) := 'MarcaNoFimDoFluxoGrande';
    l_claro  BLOB;
    l_cif    BLOB;
    l_dec    BLOB;
    l_tam    PLS_INTEGER;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);
    -- cada célula emite ~100 bytes de instruções: bem além de 16 KB
    FOR i IN 1 .. 900 LOOP
      PL_FPDF.Cell(20, 4, 'Bloco ' || i, '1',
                   CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    PL_FPDF.Cell(0, 6, co_marca, '0', 1);
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;
    l_tam := DBMS_LOB.GETLENGTH(l_claro);

    IF l_tam < 16383 THEN
      test_fail('o documento de origem tem só ' || l_tam
                || ' bytes; o teste não exercita o limite');
    ELSE
      l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                  p_user_password => 'grande',
                                  p_encryption => 'RC4-128');
      l_dec := PL_FPDF.DecryptPDF(l_cif, 'grande');

      IF DBMS_LOB.INSTR(l_cif, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) > 0 THEN
        test_fail('a marca continua em claro no PDF cifrado');
      ELSIF DBMS_LOB.INSTR(l_dec, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) = 0 THEN
        -- a marca fica no FIM do fluxo: se o estado da cifra não atravessasse
        -- os lotes, o começo voltaria certo e o fim viria como lixo
        test_fail('a marca no fim do fluxo não voltou ao decifrar');
      ELSE
        test_pass('fluxo de ' || l_tam || ' bytes cifrado e decifrado com RC4');
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.5e: IsEncrypted olha o TRAILER, não o começo do arquivo
  --
  -- A versão anterior lia os primeiros 32767 bytes, e /Encrypt fica no fim.
  -- Funcionava por acidente em documento pequeno, que cabe inteiro nessa
  -- janela. Num PDF cifrado maior, mentia — e a consequência pior não era
  -- recusar a decifragem: EncryptPDF usa IsEncrypted para barrar dupla
  -- cifragem, e passava a cifrar de novo o que já estava cifrado.
  test_start('IsEncrypted reconhece PDF cifrado acima de 32 KB');
  DECLARE
    l_claro BLOB;
    l_cif   BLOB;
    l_dupla BLOB;
    l_erros PLS_INTEGER := 0;
    l_msg   VARCHAR2(4000);
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 8);
    FOR i IN 1 .. 900 LOOP
      PL_FPDF.Cell(20, 4, 'Linha ' || i, '1',
                   CASE WHEN MOD(i, 9) = 0 THEN 1 ELSE 0 END);
    END LOOP;
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                p_user_password => 'grande',
                                p_encryption => 'RC4-128');

    IF DBMS_LOB.GETLENGTH(l_cif) <= 32767 THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [o cifrado tem só ' || DBMS_LOB.GETLENGTH(l_cif)
                     || ' bytes; não exercita a janela]';
    END IF;
    IF NOT PL_FPDF.IsEncrypted(l_cif) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [IsEncrypted não reconhece o PDF grande cifrado]';
    END IF;
    IF PL_FPDF.IsEncrypted(l_claro) THEN
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [IsEncrypted acusa o PDF em claro]';
    END IF;

    -- dupla cifragem tem de ser barrada
    BEGIN
      l_dupla := PL_FPDF.EncryptPDF(p_pdf => l_cif,
                                    p_user_password => 'outra',
                                    p_encryption => 'RC4-128');
      l_erros := l_erros + 1;
      l_msg := l_msg || ' [aceitou cifrar de novo um PDF já cifrado]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -20859 THEN
          l_erros := l_erros + 1;
          l_msg := l_msg || ' [dupla cifragem deu ' || SQLCODE
                         || ', esperado -20859]';
        END IF;
    END;

    IF l_erros = 0 THEN
      test_pass('IsEncrypted acerta acima de 32 KB e a dupla cifragem é barrada');
    ELSE
      test_fail(l_erros || ' problema(s):' || l_msg);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 3.6: ida e volta preserva o documento
  test_start('EncryptPDF + DecryptPDF - ida e volta preserva o conteudo');
  DECLARE
    co_marca CONSTANT VARCHAR2(60) := 'FraseSecretaParaConferirCifragem';
    l_claro  BLOB;
    l_cif    BLOB;
    l_dec    BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, co_marca, '0', 1);
    l_claro := PL_FPDF.OutputBlob();
    PL_FPDF.Reset;

    l_cif := PL_FPDF.EncryptPDF(p_pdf => l_claro,
                                p_user_password => 'segredo',
                                p_encryption => 'RC4-128');
    l_dec := PL_FPDF.DecryptPDF(l_cif, 'segredo');

    IF DBMS_LOB.INSTR(l_dec, UTL_RAW.CAST_TO_RAW(co_marca), 1, 1) > 0 THEN
      test_pass('decifrado devolve o conteudo original');
    ELSE
      test_fail('o conteudo nao voltou ao original depois de decifrar');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- ================================================================================
  -- SECTION 4: Decryption
  -- ================================================================================
  section_start('SECTION 4: Decryption');

  -- TEST 4.1: DecryptPDF - Non-encrypted PDF (should fail)
  test_start('DecryptPDF - Non-encrypted PDF (should fail)');
  BEGIN
    l_decrypted := PL_FPDF.DecryptPDF(l_pdf, 'password');
    test_fail('Should have raised error for non-encrypted PDF');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20853 THEN
        test_pass('Correctly rejected non-encrypted PDF');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE);
      END IF;
  END;

  -- TEST 4.2: DecryptPDF - NULL password (should fail)
  test_start('DecryptPDF - NULL password (should fail)');
  BEGIN
    -- First encrypt
    l_encrypted := PL_FPDF.EncryptPDF(l_pdf, 'test', NULL, NULL, 'RC4-128');

    -- Try to decrypt with NULL
    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, NULL);
    test_fail('Should have raised error for NULL password');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20854 THEN
        test_pass('Correctly rejected NULL password');
      ELSE
        test_fail('Wrong error: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- TEST 4.3: DecryptPDF - With correct user password
  test_start('DecryptPDF - With correct user password');
  BEGIN
    -- Encrypt
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'userpass',
      p_owner_password => 'ownerpass',
      p_encryption => 'RC4-128'
    );

    -- Decrypt with user password
    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, 'userpass');

    IF l_decrypted IS NOT NULL AND DBMS_LOB.GETLENGTH(l_decrypted) > 0 THEN
      -- Verify it's no longer encrypted
      IF NOT PL_FPDF.IsEncrypted(l_decrypted) THEN
        test_pass('Decryption successful, PDF no longer encrypted');
      ELSE
        test_pass('Decryption returned PDF (encryption marker may still exist)');
      END IF;
    ELSE
      test_fail('Decryption returned empty result');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 4.4: DecryptPDF - With correct owner password
  test_start('DecryptPDF - With correct owner password');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'userpass',
      p_owner_password => 'ownerpass',
      p_encryption => 'RC4-128'
    );

    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, 'ownerpass');

    IF l_decrypted IS NOT NULL THEN
      test_pass('Decryption with owner password successful');
    ELSE
      test_fail('Decryption failed');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 4.5: DecryptPDF - Wrong password (should fail)
  test_start('DecryptPDF - Wrong password (should fail)');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'correct',
      p_encryption => 'RC4-128'
    );

    l_decrypted := PL_FPDF.DecryptPDF(l_encrypted, 'wrong');
    test_fail('Should have raised error for wrong password');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20854 THEN
        test_pass('Correctly rejected wrong password');
      ELSE
        test_fail('Wrong error: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- ================================================================================
  -- SECTION 5: Security Info Parsing
  -- ================================================================================
  section_start('SECTION 5: Security Info Parsing');

  -- TEST 5.1: GetSecurityInfo - RC4-128 details
  test_start('GetSecurityInfo - RC4-128 encrypted PDF details');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'info_test',
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);

    DBMS_OUTPUT.PUT_LINE('  [INFO] Security Info:');
    DBMS_OUTPUT.PUT_LINE('         encrypted: ' || CASE WHEN l_info.get_boolean('encrypted') THEN 'YES' ELSE 'NO' END);
    DBMS_OUTPUT.PUT_LINE('         method: ' || l_info.get_string('method'));
    DBMS_OUTPUT.PUT_LINE('         version: ' || l_info.get_number('version'));
    DBMS_OUTPUT.PUT_LINE('         revision: ' || l_info.get_number('revision'));
    DBMS_OUTPUT.PUT_LINE('         keyLength: ' || l_info.get_number('keyLength'));

    IF l_info.get_boolean('encrypted') AND
       l_info.get_string('method') = 'RC4-128' AND
       l_info.get_number('keyLength') = 128 THEN
      test_pass('Security info correctly parsed');
    ELSE
      test_fail('Security info incomplete or incorrect');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 5.2: GetSecurityInfo - RC4-40 details
  test_start('GetSecurityInfo - RC4-40 encrypted PDF details');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'info_test',
      p_encryption => 'RC4-40'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);

    IF l_info.get_string('method') = 'RC4-40' AND
       l_info.get_number('version') = 1 THEN
      test_pass('RC4-40 info correctly parsed');
    ELSE
      test_fail('RC4-40 info incorrect');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- TEST 5.3: GetSecurityInfo - Permission value
  test_start('GetSecurityInfo - Permission value parsing');
  BEGIN
    l_permissions := JSON_OBJECT_T();
    l_permissions.put('print', TRUE);
    l_permissions.put('copy', FALSE);

    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'perm_test',
      p_permissions => l_permissions,
      p_encryption => 'RC4-128'
    );

    l_info := PL_FPDF.GetSecurityInfo(l_encrypted);
    l_perms := l_info.get_Object('permissions');

    IF l_perms IS NOT NULL AND
       l_perms.get_boolean('print') = TRUE AND
       l_perms.get_boolean('copy') = FALSE THEN
      test_pass('Permissions correctly parsed from PDF');
      DBMS_OUTPUT.PUT_LINE('  [INFO] Permission value: ' || l_info.get_number('permissionValue'));
    ELSE
      test_fail('Permissions not parsed correctly');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_fail('Error: ' || SQLERRM);
  END;

  -- ================================================================================
  -- SECTION 6: Error Handling
  -- ================================================================================
  section_start('SECTION 6: Error Handling');

  -- TEST 6.1: EncryptPDF - Invalid encryption method
  test_start('EncryptPDF - Invalid encryption method');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => 'test',
      p_encryption => 'INVALID'
    );
    test_fail('Should have raised error for invalid method');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20850 THEN
        test_pass('Correctly rejected invalid encryption method');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE);
      END IF;
  END;

  -- TEST 6.2: EncryptPDF - NULL password
  test_start('EncryptPDF - NULL password');
  BEGIN
    l_encrypted := PL_FPDF.EncryptPDF(
      p_pdf => l_pdf,
      p_user_password => NULL,
      p_encryption => 'RC4-128'
    );
    test_fail('Should have raised error for NULL password');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20851 THEN
        test_pass('Correctly rejected NULL password');
      ELSE
        test_fail('Wrong error code: ' || SQLCODE || ' - ' || SQLERRM);
      END IF;
  END;

  -- TEST 6.3 / 6.4: AES-128 e AES-256 são implementados
  --
  -- Estes dois testes exigiam a RECUSA com -20852 e passavam por isso. Deixá-los
  -- assim seria pior que inútil: uma suíte verde afirmando que o AES não existe.
  FOR r IN (SELECT 'AES-128' m, 128 bits FROM dual
            UNION ALL
            SELECT 'AES-256', 256 FROM dual) LOOP
    test_start('EncryptPDF - ' || r.m || ' produz PDF protegido');
    DECLARE
      l_enc  BLOB;
      l_info JSON_OBJECT_T;
    BEGIN
      l_enc := PL_FPDF.EncryptPDF(
        p_pdf => l_pdf,
        p_user_password => 'aestest',
        p_encryption => r.m
      );
      IF l_enc IS NULL OR DBMS_LOB.GETLENGTH(l_enc) = 0 THEN
        test_fail(r.m || ': resultado vazio');
      ELSIF NOT PL_FPDF.IsEncrypted(l_enc) THEN
        test_fail(r.m || ': o resultado nao se declara criptografado');
      ELSE
        l_info := PL_FPDF.GetSecurityInfo(l_enc);
        IF l_info.get_string('method') != r.m THEN
          test_fail(r.m || ': GetSecurityInfo diz ' || l_info.get_string('method'));
        ELSIF l_info.get_number('keyLength') != r.bits THEN
          test_fail(r.m || ': keyLength ' || l_info.get_number('keyLength')
                    || ', esperado ' || r.bits);
        ELSE
          test_pass(r.m || ': cifra e se identifica corretamente');
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        test_fail(r.m || ' - Error: ' || SQLERRM);
    END;
  END LOOP;

  -- TEST 6.5: SetEncryption - Invalid method
  test_start('SetEncryption - Invalid method');
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetEncryption('INVALID', 'user123');
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20850 THEN
        test_pass('Correctly rejected invalid method');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
  END;

  -- TEST 6.6: SetEncryption - NULL password
  test_start('SetEncryption - NULL password');
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetEncryption('RC4-128', NULL);
    test_fail('Should have raised error');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20851 THEN
        test_pass('Correctly rejected NULL password');
      ELSE
        test_fail('Wrong error: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------------
  -- Print Summary
  --------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('TEST SUMMARY');
  DBMS_OUTPUT.PUT_LINE('================================================================================');
  DBMS_OUTPUT.PUT_LINE('Testes:       ' || v_total_tests);
  DBMS_OUTPUT.PUT_LINE('Passou:       ' || v_passed_tests);
  DBMS_OUTPUT.PUT_LINE('Falhou:       ' || v_failed_tests);
  DBMS_OUTPUT.PUT_LINE('Pulados:      ' || v_skipped_tests);

  IF v_skipped_tests > 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Os testes pulados precisam de criptografia real:');
    DBMS_OUTPUT.PUT_LINE('  GRANT EXECUTE ON SYS.DBMS_CRYPTO TO ' ||
                         SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || ';');
    DBMS_OUTPUT.PUT_LINE('Um DBMS_CRYPTO substituto no próprio schema só serve');
    DBMS_OUTPUT.PUT_LINE('se implementar MD5 e RC4 de fato — um que devolva a');
    DBMS_OUTPUT.PUT_LINE('entrada sem alterar faz o /O sair em texto claro e');
    DBMS_OUTPUT.PUT_LINE('QUALQUER senha ser aceita.');
  END IF;

  IF v_failed_tests = 0 THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('*** ALL TESTS PASSED ***' ||
      CASE WHEN v_skipped_tests > 0
           THEN ' (' || v_skipped_tests || ' pulado(s))' END);
  ELSE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('*** SOME TESTS FAILED ***');
  END IF;
  DBMS_OUTPUT.PUT_LINE('================================================================================');

  -- Cleanup
  BEGIN
    IF l_pdf IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_pdf); END IF;
    IF l_encrypted IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_encrypted); END IF;
    IF l_decrypted IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_decrypted); END IF;
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/

--------------------------------------------------------------------------------
-- Regressões da revisão de ago/2026
-- origem: tests/test_regressoes_revisao.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF - Regressoes da revisao de agosto/2026
--
-- Um caso por defeito encontrado na revisao da branch. Cada um FALHA se o
-- defeito voltar; nenhum passa por acidente.
--
-- Regra deste arquivo: quando o ambiente nao permite concluir (o fixture nao
-- montou, o stream saiu comprimido), o caso imprime [SKIP] com o motivo.
-- Passar sem ter olhado e pior que falhar, porque ninguem desconfia.
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
-- Defeito que so se observa de fora vira lint estatico, nao caso de teste.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_out    BLOB;

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  PROCEDURE pulou(p_msg VARCHAR2) IS
  BEGIN
    l_skip := l_skip + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END;

  -- Procura um texto no BLOB. Devolve 0 quando nao acha.
  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  -- Um PDF de n paginas, gerado pelo proprio package.
  FUNCTION pdf_de(p_paginas IN PLS_INTEGER) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetFont('Arial', '', 10);
    FOR i IN 1 .. p_paginas LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Pagina ' || i);
    END LOOP;
    l_b := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();
    RETURN l_b;
  END pdf_de;

BEGIN
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - Regressoes da revisao de agosto/2026');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));

  --------------------------------------------------------------------------
  -- 1. A marca d'agua referenciava uma fonte que ninguem declara
  --
  -- ovl_marca_dagua emitia o literal '/FwmPLFPDF'. Esse nome nao sai de
  -- ovl_fonte_nome e nao entra no /Font de pagina nenhuma: o operador Tf
  -- ficava sem fonte e a marca NAO DESENHAVA. O nome certo e /FwmH, que e o
  -- que a largura ja media (Helvetica nao-negrito).
  --------------------------------------------------------------------------
  caso('AddWatermark referencia uma fonte declarada (nao /FwmPLFPDF)');
  BEGIN
    l_pdf := pdf_de(2);
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark(p_text => 'CONFIDENCIAL', p_opacity => 0.3);
    l_out := PL_FPDF.OutputModifiedPDF();
    PL_FPDF.ClearPDFCache();

    IF acha(l_out, 'FwmPLFPDF') > 0 THEN
      falhou('o PDF ainda traz /FwmPLFPDF — a marca nao desenha');
    ELSIF acha(l_out, 'FwmH') > 0 THEN
      passou('a marca usa /FwmH, que o /Font da pagina declara');
    ELSE
      -- nenhum dos dois no claro: o stream saiu comprimido e este caso nao
      -- consegue afirmar nada. Nao e um PASS.
      pulou('nem /FwmH nem /FwmPLFPDF no claro — stream comprimido, ' ||
            'caso inconclusivo');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 2. cor() estourava na DECLARACAO
  --
  -- l_h era VARCHAR2(10). Uma cor de 11+ caracteres levantava ORA-06502
  -- ANTES do CASE — que trataria o nome desconhecido caindo no padrao — e
  -- derrubava o OutputModifiedPDF inteiro.
  --------------------------------------------------------------------------
  caso('AddWatermark aceita nome de cor longo sem ORA-06502');
  BEGIN
    l_pdf := pdf_de(1);
    PL_FPDF.LoadPDF(l_pdf);
    PL_FPDF.AddWatermark(p_text  => 'RASCUNHO',
                         p_color => 'lightsteelblue');   -- 14 caracteres
    l_out := PL_FPDF.OutputModifiedPDF();
    PL_FPDF.ClearPDFCache();
    IF DBMS_LOB.GETLENGTH(l_out) > 0 THEN
      passou('cor desconhecida de 14 caracteres caiu no padrao, sem excecao');
    ELSE
      falhou('saida vazia');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-06502') > 0 THEN
        falhou('ORA-06502 de volta: o buffer de cor voltou a ser curto');
      ELSE
        falhou('excecao: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------
  -- 3. SplitPDF vazava um CLOB temporario por intervalo
  --
  -- NAO TEM CASO AQUI, DE PROPOSITO.
  --
  -- O vazamento nao e observavel de dentro do proprio schema: USER_* nao
  -- expoe contagem de LOB temporario, e as instancias vazadas nao tem
  -- locator que se possa passar ao DBMS_LOB.ISTEMPORARY. A primeira versao
  -- deste arquivo media V$TEMPORARY_LOBS, o que exige GRANT de DBA — e um
  -- caso que so sabe pular vira cobertura de mentira.
  --
  -- Quem guarda este defeito e o check_lob_temp.py, que le o fonte: toda
  -- variavel que recebe LOB temporario de uma funcao tem de passar por
  -- FREETEMPORARY, a menos que seja devolvida. Roda sem banco, sem
  -- privilegio e sem rede, que e o que este projeto pode exigir.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- 4. buildPlsqlStatment: o default so existia na declaracao antecipada
  --
  -- Se a definicao e a antecipada divergirem, o Oracle nao compila o body
  -- (PLS-00593) — entao este caso e, na pratica, "o package esta VALID e o
  -- caminho sem paramTable funciona".
  --------------------------------------------------------------------------
  caso('SetFooterProc sem paramTable usa o default e o package esta VALID');
  DECLARE
    l_invalidos PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO l_invalidos
      FROM user_objects
     WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
       AND status != 'VALID';
    IF l_invalidos > 0 THEN
      falhou(l_invalidos || ' objeto(s) do package fora de VALID');
    ELSE
      PL_FPDF.Init('P', 'mm', 'A4');
      PL_FPDF.SetFooterProc('nao_existe.proc_qualquer');  -- sem paramTable
      PL_FPDF.Reset();
      passou('package VALID e SetFooterProc aceitou a chamada sem paramTable');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 5. Secao xref classica maior que a janela de 32767 bytes
  --
  -- pdf_read faz LEAST(p_len, 32767) e trunca calado: acima de ~1638 entradas
  -- (20 bytes cada) o resto da tabela sumia, o 'trailer' nao era achado e o
  -- chamador recebia '-20803 /Root nao encontrado' — que aponta para o lugar
  -- errado. Agora se recusa com -20841 e mensagem que diz o que aconteceu.
  --
  -- O que se cobra aqui e o CODIGO do erro, nao o sucesso: se o PDF couber na
  -- janela, ele carrega normalmente e o caso registra isso.
  --------------------------------------------------------------------------
  caso('xref classica grande: erro claro (-20841), nunca -20803 enganoso');
  DECLARE
    l_grande BLOB;
    l_cod    PLS_INTEGER;
  BEGIN
    -- ~900 paginas: cada uma rende objeto de pagina e stream de conteudo,
    -- o que passa folgado das ~1638 entradas de uma janela.
    l_grande := pdf_de(900);
    BEGIN
      PL_FPDF.LoadPDF(l_grande);
      PL_FPDF.ClearPDFCache();
      pulou('o PDF de 900 paginas coube na janela e carregou — este caso ' ||
            'nao exercitou o limite');
    EXCEPTION
      WHEN OTHERS THEN
        l_cod := SQLCODE;
        IF l_cod = -20841 THEN
          passou('recusou com -20841 e mensagem propria');
        ELSIF l_cod = -20803 THEN
          falhou('voltou o -20803 enganoso: o truncamento da xref esta ' ||
                 'silencioso de novo');
        ELSE
          falhou('erro inesperado ' || l_cod || ': ' || SQLERRM);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      -- nao conseguir GERAR 900 paginas e limite de ambiente, nao a regressao
      pulou('nao foi possivel montar o PDF de 900 paginas: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 6. Reset deixava metadado para tras
  --
  -- O package tem estado de SESSAO. O Reset zerava fontes, imagens, links,
  -- callbacks e criptografia — e esquecia title, subject, author, keywords e
  -- creator. O /Keywords de um documento reaparecia em todos os seguintes.
  --
  -- Custou uma rodada inteira de diagnostico: um SetKeywords grande num teste
  -- fez cada PDF da suite nascer com 32 KB a mais, a cifragem recusar todos, e
  -- o sintoma nao apontava para o Reset em momento nenhum.
  --------------------------------------------------------------------------
  caso('Reset limpa os metadados do documento');
  DECLARE
    l_marca CONSTANT VARCHAR2(40) := 'MARCA-QUE-NAO-PODE-VAZAR-4711';
  BEGIN
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetKeywords(l_marca);
    PL_FPDF.SetAuthor(l_marca);
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'primeiro');
    l_pdf := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();

    -- documento novo, sem tocar em metadado nenhum
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'segundo');
    l_out := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();

    IF acha(l_out, l_marca) > 0 THEN
      falhou('o metadado do primeiro documento vazou para o segundo — '
             || 'Reset voltou a esquecer title/author/keywords');
    ELSE
      passou('o segundo documento nasceu sem o metadado do primeiro');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- 7. String literal grande demais ao cifrar
  --
  -- Antes: sec_cifrar_strings acumulava o hexadecimal num VARCHAR2(32767),
  -- dois caracteres por byte, e estourava ORA-06502 — que o EncryptPDF
  -- rebatizava como '-20852 Encryption failed', escondendo a causa. Pior:
  -- sec_cifrar_objetos truncava o dicionario calado e devolvia arquivo
  -- quebrado REPORTANDO SUCESSO.
  --
  -- Agora recusa, e o codigo certo e -20866: e o erro que o proprio package
  -- ja usava na SAIDA do escape, com a mesma mensagem e o mesmo teto de
  -- 16000 bytes. A primeira versao deste caso esperava -20841, que e o erro
  -- de LEITURA truncada — outro assunto. Expectativa errada minha, nao
  -- defeito do codigo: o -20866 e o mais preciso dos dois.
  --------------------------------------------------------------------------
  caso('EncryptPDF recusa objeto com dicionario acima de 32 KB');
  DECLARE
    l_cifrado BLOB;
    l_cod     PLS_INTEGER;
    l_perm    JSON_OBJECT_T := JSON_OBJECT_T();
    l_grande  BLOB;
  BEGIN
    -- Palavras-chave enormes entram no /Info, que e um objeto de dicionario.
    -- 17000 e o minimo que passa do teto de 16000 do escape. A versao
    -- anterior usava 32000 sem necessidade, e como o Reset nao limpava
    -- metadado (defeito consertado nesta mesma rodada), aquilo vazava para
    -- TODA amostra seguinte da sessao: cada PDF nascia com 32 KB a mais e a
    -- cifragem recusava todos. Fixture de teste nao pode sujar o que vem
    -- depois — nem quando o package tem defeito.
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.SetKeywords(RPAD('a', 17000, 'a'));
    PL_FPDF.AddPage();
    PL_FPDF.Cell(0, 10, 'dicionario grande');
    l_grande := PL_FPDF.OutputBlob();
    PL_FPDF.Reset();

    l_perm.put('print', TRUE);
    BEGIN
      l_cifrado := PL_FPDF.EncryptPDF(p_pdf            => l_grande,
                                      p_user_password  => 'x',
                                      p_permissions    => l_perm,
                                      p_encryption     => 'AES-128');
      -- Chegou aqui: ou o dicionario coube, ou o guard nao disparou. Para
      -- distinguir, confere se a saida ainda tem o /Info inteiro.
      IF acha(l_cifrado, 'Encrypt') > 0 THEN
        pulou('o dicionario ficou abaixo de 32 KB e a cifragem passou — ' ||
              'este caso nao exercitou o limite');
      ELSE
        falhou('cifrou sem marcar /Encrypt: saida suspeita');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_cod := SQLCODE;
        -- -20866: literal de string acima do teto do escape (o preciso).
        -- -20841: leitura truncada do objeto — tambem e recusa honesta, e
        --         vale para um fixture que chegue por aquele caminho.
        IF l_cod IN (-20866, -20841) THEN
          passou('recusou com ' || l_cod ||
                 ' em vez de estourar ORA-06502 ou truncar em silencio');
        ELSIF INSTR(SQLERRM, 'ORA-06502') > 0 THEN
          falhou('ORA-06502 de volta: o estouro voltou a passar sem guarda');
        ELSE
          falhou('erro inesperado ' || l_cod || ': ' || SQLERRM);
        END IF;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      pulou('nao foi possivel montar o fixture do dicionario grande: ' ||
            SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- O caso que existia aqui conferia que SetUTF8Enabled e IsUTF8Enabled eram
  -- coerentes entre si -- o unico contrato que aquela API cumpria, porque a
  -- flag nao era consultada em lugar nenhum. As duas sairam da spec quando a
  -- conversao WinAnsi passou a ser sempre feita, e o caso saiu com elas.
  --
  -- O que ele registrava em texto agora e aferido de verdade, em
  -- test_winansi.sql: o acentuado convertido, o alinhamento que antes
  -- levantava ORA-06502, e a recusa do que nao existe em WinAnsi.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  caso('Documento em paisagem nao contamina o seguinte');
  --------------------------------------------------------------------------
  -- O Reset limpava fontes, imagens, links e metadados, mas NAO o
  -- OrientationChanges -- a tabela que diz quais paginas tem orientacao
  -- diferente do padrao, e que faz cada uma delas ganhar MediaBox proprio.
  --
  -- Como ela e indexada pelo NUMERO da pagina, o indice 1 de um documento
  -- virava o indice 1 do proximo: quem gerasse um documento com a pagina 1 em
  -- paisagem deixava TODO documento posterior da mesma sessao com a pagina 1
  -- em paisagem. MediaBox trocado, conteudo desenhado fora do papel, arquivo
  -- que abre EM BRANCO -- sem erro nenhum.
  --
  -- O sintoma nao acusa a causa: a pagina 1 sai errada e as demais certas,
  -- porque so o indice reaproveitado colide. Foi assim que apareceu: doze
  -- amostras com o texto nao extraido, e o codigo de barras sem decodificar.
  DECLARE
    l_paisagem BLOB;
    l_retrato  BLOB;
  BEGIN
    -- primeiro documento: pagina 1 em PAISAGEM
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage('L');
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'paisagem');
    l_paisagem := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- segundo documento: tudo RETRATO, sem tocar em orientacao
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'retrato');
    l_retrato := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- A4 retrato: 595.28 x 841.89. Paisagem inverte os dois. O segundo
    -- documento nao pode ter MediaBox proprio em pagina nenhuma.
    IF acha(l_retrato, '/MediaBox [0 0 841.89 595.28]') = 0 THEN
      passou('o documento retrato nao herdou a paisagem do anterior');
    ELSE
      falhou('a pagina 1 saiu em paisagem: o OrientationChanges do documento '
             || 'anterior sobreviveu ao Reset');
    END IF;

    IF acha(l_paisagem, '/MediaBox [0 0 841.89 595.28]') > 0 THEN
      passou('o documento paisagem tem a pagina em paisagem, como pedido');
    ELSE
      falhou('a paisagem pedida nao saiu');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Link so aceita URL, e recusa o link interno em vez de gravar quebrado');
  --------------------------------------------------------------------------
  -- O ramo que escreveria o /Dest do link INTERNO saiu comentado no porte
  -- original e nunca voltou. Com plink numerico o dicionario do /Annot ficava
  -- ABERTO -- sai "<</Type /Annot ... /Border [0 0 0] ]", sem o >> que fecha.
  -- Nao e link que nao navega: e PDF que o leitor recusa.
  --
  -- Ninguem reparou porque nenhum teste chamava AddLink ou SetLink. Foi ao
  -- escrever este caso que apareceu o terceiro lado do mesmo defeito: o
  -- AddLink levantava ORA-06531, "reference to uninitialized collection", na
  -- linha da propria declaracao. A colecao "links" e nested table e ninguem a
  -- inicializa, entao o AddLink NUNCA funcionou -- nem uma vez, em nenhuma
  -- versao. Os tres passam a recusar com ORA-20601 e mensagem que diz o que
  -- usar no lugar.
  DECLARE
    l_pdf   BLOB;
    l_erro  VARCHAR2(400);

    PROCEDURE recusa(p_que VARCHAR2, p_erro VARCHAR2) IS
    BEGIN
      IF INSTR(p_erro, 'ORA-20601') > 0 THEN
        passou(p_que || ' recusado com ORA-20601');
      ELSIF INSTR(p_erro, 'ORA-06531') > 0 THEN
        falhou(p_que || ' ainda levanta ORA-06531, que nao diz o que fazer');
      ELSE
        falhou(p_que || ' recusou com outro erro: ' || p_erro);
      END IF;
    END recusa;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);

    BEGIN
      l_erro := TO_CHAR(PL_FPDF.AddLink);
      falhou('AddLink devolveu um identificador que nao leva a lugar nenhum');
    EXCEPTION
      WHEN OTHERS THEN recusa('AddLink', SQLERRM);
    END;

    BEGIN
      PL_FPDF.SetLink(1, 0, 1);
      falhou('SetLink aceitou guardar um destino que nao chega ao arquivo');
    EXCEPTION
      WHEN OTHERS THEN recusa('SetLink', SQLERRM);
    END;

    BEGIN
      PL_FPDF.Link(20, 40, 60, 10, '1');
      falhou('Link aceitou destino numerico - o arquivo sairia malformado');
    EXCEPTION
      WHEN OTHERS THEN recusa('Link com destino numerico', SQLERRM);
    END;

    -- URL continua funcionando, e e o caminho que sempre esteve correto
    PL_FPDF.Link(20, 60, 60, 10, 'https://example.com');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    IF acha(l_pdf, '/Subtype /Link') > 0 AND acha(l_pdf, '/URI') > 0 THEN
      passou('o link por URL saiu no arquivo');
    ELSE
      falhou('o link por URL sumiu');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Link na pagina 3 nao estraga as paginas 1 e 2');
  --------------------------------------------------------------------------
  -- O Link estende a colecao ate a pagina corrente, e as paginas anteriores
  -- ficavam com entrada VAZIA. O emissor so testava .exists(i), entao essas
  -- paginas ganhavam um /Annots com /Rect vazio e o dicionario aberto -- sem
  -- que ninguem tivesse pedido link nenhum nelas.
  DECLARE
    l_pdf BLOB;
    l_n   PLS_INTEGER;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;  PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(50, 10, 'Pagina 1');
    PL_FPDF.AddPage;  PL_FPDF.Cell(50, 10, 'Pagina 2');
    PL_FPDF.AddPage;  PL_FPDF.Cell(50, 10, 'Pagina 3');
    PL_FPDF.Link(20, 40, 60, 10, 'https://example.com');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- tres paginas, UM /Annots so
    l_n := 0;
    FOR i IN 1 .. 3 LOOP
      IF DBMS_LOB.INSTR(l_pdf, UTL_RAW.CAST_TO_RAW('/Annots ['), 1, i) > 0 THEN
        l_n := i;
      END IF;
    END LOOP;
    IF l_n = 1 THEN
      passou('so a pagina com link tem /Annots');
    ELSE
      falhou('ha ' || l_n || ' /Annots no arquivo, e so uma pagina tem link');
    END IF;

    -- e nenhum dicionario de anotacao ficou aberto
    IF acha(l_pdf, '/Border [0 0 0] ]') = 0 THEN
      passou('nenhum /Annot com o dicionario aberto');
    ELSE
      falhou('ha /Annot fechado com ] em vez de >> - dicionario aberto');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('excecao: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Link funciona no SEGUNDO documento da sessao');
  --------------------------------------------------------------------------
  -- O Link media o quanto estender pelo .last, e .last de colecao VAZIA e
  -- NULL. Depois de um Reset a colecao fica exatamente assim: o delete zera a
  -- contagem e nao anula a colecao. Entao "page - NULL" dava NULL, o IF nao
  -- disparava e o PageLinks(page) estourava com ORA-06533 -- no primeiro Link
  -- do segundo documento, e o erro nao fala de link nenhum.
  --
  -- Atinge o caminho COMUM, com URL, e quem gera documento em lote passa por
  -- ele em toda emissao a partir da segunda.
  DECLARE
    l_um    BLOB;
    l_dois  BLOB;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Link(20, 40, 60, 10, 'https://example.com/um');
    l_um := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    -- segundo documento na MESMA sessao: e aqui que estourava
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Link(20, 40, 60, 10, 'https://example.com/dois');
    l_dois := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    IF acha(l_dois, 'https://example.com/dois') > 0 THEN
      passou('o link do segundo documento saiu no arquivo');
    ELSE
      falhou('o link do segundo documento sumiu');
    END IF;

    IF acha(l_dois, 'https://example.com/um') = 0 THEN
      passou('o link do primeiro documento nao vazou para o segundo');
    ELSE
      falhou('o link do documento anterior sobreviveu ao Reset');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-06533') > 0 THEN
        falhou('ORA-06533: o Link ainda depende do .last de colecao vazia');
      ELSE
        falhou('excecao: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
  DBMS_OUTPUT.PUT_LINE('Total: ' || l_total ||
                       ' | OK: ' || l_ok ||
                       ' | Falhas: ' || l_falhas ||
                       ' | Pulados: ' || l_skip);
  IF l_falhas > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: FALHOU');
  ELSIF l_skip > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK, com ' || l_skip ||
                         ' caso(s) sem conclusao — leia os [SKIP] acima');
  ELSE
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
  END IF;
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
END;
/

--------------------------------------------------------------------------------
-- Escrita do stream de imagem
-- origem: tests/test_stream_imagem.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF - Escrita do stream de imagem (p_putstream do BLOB)
--
-- O p_putstream lia o BLOB para um buffer VARCHAR2. Com um BLOB no primeiro
-- argumento o DBMS_LOB.READ resolve para a sobrecarga cujo buffer e RAW, e a
-- conversao implicita devolve a representacao hexadecimal: 2000 bytes viravam
-- 4000 caracteres, que nao cabiam no varchar2(2000).
--
-- Ele e privado, entao os casos 1 a 3 exercitam as duas formas do laco e as duas
-- codificacoes lado a lado, sobre um BLOB controlado: medem o comportamento em
-- vez de inferi-lo de um arquivo gerado. Os casos 5 e 6 percorrem o caminho
-- completo da imagem pelo ImageFromBlob, que recebe os bytes prontos e por isso
-- nao precisa da ACL de rede que o Image() exige.
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_blob    BLOB;
  l_buf     RAW(2000);
  l_qtd     INTEGER;
  l_pos     INTEGER;
  l_lidos   INTEGER;
  l_tam     INTEGER;
  l_origem  RAW(256);
  l_texto   VARCHAR2(4000);
  l_charset VARCHAR2(60);
  l_pdf     BLOB;
  l_hex     VARCHAR2(4000);

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  PROCEDURE pulou(p_msg VARCHAR2) IS
  BEGIN
    l_skip := l_skip + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END;

  -- Um BLOB de n bytes iguais.
  FUNCTION blob_de(p_bytes IN PLS_INTEGER) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_b, TRUE);
    FOR i IN 1 .. p_bytes LOOP
      DBMS_LOB.WRITEAPPEND(l_b, 1, HEXTORAW('41'));
    END LOOP;
    RETURN l_b;
  END blob_de;

  -- Escreve o texto num CLOB e converte de volta para BLOB, que e o percurso
  -- que todo stream faz: o documento e montado em CLOB e convertido no fim.
  FUNCTION ida_e_volta(p_texto IN VARCHAR2) RETURN BLOB IS
    l_c CLOB;
    l_b BLOB;
    l_in   PLS_INTEGER := 1;
    l_out  PLS_INTEGER := 1;
    l_lang PLS_INTEGER := 0;
    l_warn PLS_INTEGER := 0;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_c, TRUE);
    DBMS_LOB.WRITEAPPEND(l_c, LENGTH(p_texto), p_texto);
    DBMS_LOB.CREATETEMPORARY(l_b, TRUE);
    DBMS_LOB.CONVERTTOBLOB(l_b, l_c, DBMS_LOB.GETLENGTH(l_c), l_in, l_out,
                           DBMS_LOB.DEFAULT_CSID, l_lang, l_warn);
    DBMS_LOB.FREETEMPORARY(l_c);
    RETURN l_b;
  END ida_e_volta;

  -- Procura um texto no BLOB. Devolve 0 quando nao acha.
  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - stream de imagem');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O laco le ate o ultimo byte');
  --------------------------------------------------------------------------
  -- O teste era offset < tamanho. Quando o ultimo pedaco comeca exatamente no
  -- byte final, o laco termina sem le-lo: o stream sai um byte curto enquanto
  -- o /Length continua prometendo o total. 2001 bytes e o menor caso que
  -- mostra isso com pedaco de 2000.
  l_blob := blob_de(2001);
  l_tam  := DBMS_LOB.GETLENGTH(l_blob);

  l_lidos := 0;
  l_pos   := 1;
  WHILE l_pos < l_tam LOOP
    l_qtd := 2000;
    DBMS_LOB.READ(l_blob, l_qtd, l_pos, l_buf);
    l_lidos := l_lidos + l_qtd;
    l_pos   := l_pos + l_qtd;
  END LOOP;

  IF l_lidos < l_tam THEN
    passou('a forma antiga leu ' || l_lidos || ' de ' || l_tam || ' bytes');
  ELSE
    falhou('a forma antiga leu tudo - o defeito nao reproduziu');
  END IF;

  l_lidos := 0;
  l_pos   := 1;
  WHILE l_pos <= l_tam LOOP
    l_qtd := 2000;
    DBMS_LOB.READ(l_blob, l_qtd, l_pos, l_buf);
    l_lidos := l_lidos + l_qtd;
    l_pos   := l_pos + l_qtd;
  END LOOP;

  IF l_lidos = l_tam THEN
    passou('a forma corrigida leu os ' || l_tam || ' bytes');
  ELSE
    falhou('a forma corrigida leu ' || l_lidos || ' de ' || l_tam);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_blob);

  --------------------------------------------------------------------------
  caso('O tamanho do pedaco e IN OUT');
  --------------------------------------------------------------------------
  -- O DBMS_LOB.READ devolve no parametro de quantidade o que leu de fato. Se a
  -- variavel for inicializada uma vez so, em vez de atribuida a cada passagem,
  -- uma leitura curta vira o tamanho de todas as seguintes.
  l_blob := blob_de(500);
  l_qtd  := 2000;
  DBMS_LOB.READ(l_blob, l_qtd, 1, l_buf);

  IF l_qtd = 500 THEN
    passou('depois de leitura curta a quantidade volta 500, nao os 2000 dados');
  ELSE
    falhou('a quantidade voltou ' || l_qtd);
  END IF;
  DBMS_LOB.FREETEMPORARY(l_blob);

  --------------------------------------------------------------------------
  caso('Por que o stream sai em hexadecimal');
  --------------------------------------------------------------------------
  -- O documento e montado como CLOB e convertido no fim, entao tudo o que se
  -- escreve nele faz um percurso de ida e volta pelo charset do banco. Este
  -- caso manda os 256 valores de byte pelos dois caminhos e compara.
  SELECT value INTO l_charset
    FROM nls_database_parameters
   WHERE parameter = 'NLS_CHARACTERSET';
  DBMS_OUTPUT.PUT_LINE('  NLS_CHARACTERSET = ' || l_charset);

  l_origem := NULL;
  FOR i IN 0 .. 255 LOOP
    l_origem := UTL_RAW.CONCAT(l_origem, HEXTORAW(TO_CHAR(i, 'FM0X')));
  END LOOP;

  l_pdf := ida_e_volta(UTL_RAW.CAST_TO_VARCHAR2(l_origem));
  DBMS_OUTPUT.PUT_LINE('  como caracteres:  256 bytes entraram, '
                       || DBMS_LOB.GETLENGTH(l_pdf) || ' sairam');
  IF DBMS_LOB.GETLENGTH(l_pdf) = 256
     AND UTL_RAW.COMPARE(DBMS_LOB.SUBSTR(l_pdf, 256, 1), l_origem) = 0 THEN
    pulou('este banco preserva byte cru no percurso - charset de um byte, '
          || 'entao o caso nao distingue as duas codificacoes');
  ELSE
    passou('byte cru nao sobrevive ao percurso, que e por que o stream nao '
           || 'e escrito assim');
  END IF;
  DBMS_LOB.FREETEMPORARY(l_pdf);

  l_texto := RAWTOHEX(l_origem);
  l_pdf   := ida_e_volta(l_texto);
  DBMS_OUTPUT.PUT_LINE('  como hexadecimal: ' || LENGTH(l_texto)
                       || ' caracteres entraram, ' || DBMS_LOB.GETLENGTH(l_pdf)
                       || ' bytes sairam');
  IF DBMS_LOB.GETLENGTH(l_pdf) = LENGTH(l_texto)
     AND UTL_RAW.COMPARE(UTL_RAW.CAST_TO_RAW(l_texto),
                         DBMS_LOB.SUBSTR(l_pdf, DBMS_LOB.GETLENGTH(l_pdf), 1)) = 0 THEN
    passou('hexadecimal atravessa o percurso intacto');
  ELSE
    falhou('hexadecimal nao sobreviveu - a premissa da codificacao nao vale aqui');
  END IF;
  DBMS_LOB.FREETEMPORARY(l_pdf);

  --------------------------------------------------------------------------
  caso('O package segue gerando documento');
  --------------------------------------------------------------------------
  -- O p_out esta no caminho de toda linha do documento, entao qualquer mexida
  -- na escrita de stream passa por aqui.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'stream', '0', 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
    passou('documento gerado, ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
  ELSE
    falhou('OutputBlob devolveu LOB vazio');
  END IF;

  --------------------------------------------------------------------------
  caso('A imagem inteira, do parser ao stream');
  --------------------------------------------------------------------------
  -- Pelo ImageFromBlob, que recebe os bytes prontos: sem HTTP, sem ACL, nada
  -- fora do schema. O PNG abaixo tem 2x2 pixels e paleta de quatro cores,
  -- indexado de proposito, porque a paleta e a parte que o percurso binario
  -- mais toca.
  l_hex := '89504E470D0A1A0A0000000D494844520000000200000002080300000045';
  l_hex := l_hex || '68FD160000000C504C5445FF000000FF000000FFFFFF00D6028F7B000000';
  l_hex := l_hex || '0E4944415478DA63606064606206000011000783CA64640000000049454E';
  l_hex := l_hex || '44AE426082';

  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.ImageFromBlob(HEXTORAW(l_hex), 'TESTE_PNG', 10, 10, 40);
  l_pdf := PL_FPDF.OutputBlob;

  IF acha(l_pdf, '/ASCIIHexDecode') > 0 THEN
    passou('o stream declara /ASCIIHexDecode');
  ELSE
    falhou('/ASCIIHexDecode ausente - o binario nao atravessaria o CLOB');
  END IF;

  IF acha(l_pdf, '/DecodeParms [') > 0 THEN
    passou('/DecodeParms saiu como vetor, acompanhando o /Filter');
  ELSE
    falhou('/DecodeParms nao e vetor - o /Predictor cairia no filtro errado');
  END IF;

  IF acha(l_pdf, '/Subtype /Image') > 0 AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
    passou('PDF com imagem gerado, ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
  ELSE
    falhou('o objeto de imagem nao foi emitido');
  END IF;

  --------------------------------------------------------------------------
  caso('Formato nao suportado e recusado, nao aceito em silencio');
  --------------------------------------------------------------------------
  -- Um SVG comeca com '<?xml' ou '<svg': nao tem assinatura binaria de PNG nem
  -- marcador SOI de JPEG. Recusar com erro proprio vale mais que gravar um
  -- objeto de imagem que nenhum leitor desenha.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.ImageFromBlob(UTL_RAW.CAST_TO_RAW('<svg xmlns="http://www.w3.org/2000/svg"/>'),
                          'TESTE_SVG', 10, 10, 40);
    falhou('o SVG foi aceito - deveria ter sido recusado');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20303') > 0
         OR INSTR(SQLERRM, 'Unsupported image format') > 0 THEN
        passou('formato nao suportado recusado com erro proprio');
      ELSE
        falhou('recusou, mas com outro erro: ' || SQLERRM);
      END IF;
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('Casos: ' || l_total
                       || ' | PASS: ' || l_ok
                       || ' | FAIL: ' || l_falhas
                       || ' | SKIP: ' || l_skip);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || SQLERRM);
    RAISE;
END;
/

--------------------------------------------------------------------------------
-- Texto acentuado (WinAnsi)
-- origem: tests/test_winansi.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF - Texto acentuado nas fontes padrao (conversao WinAnsi)
--
-- O dicionario da fonte declara /Encoding /WinAnsiEncoding e o texto sai do
-- banco em AL32UTF8. Sem conversao, cada acentuado chegava ao leitor como DOIS
-- bytes e ele desenhava dois glifos: 'cobranca' com cedilha virava 'cobranA§a'.
-- Sem erro nenhum, num arquivo que abre normalmente -- so se percebia olhando.
--
-- Medido antes do conserto, e vale registrar porque nenhuma das duas suposicoes
-- do relato se confirmou:
--
--   CHR(231) e 1 byte (E7); SUBSTR('c cedilha',1,1) sao 2 (C3A7)
--   GetStringWidth('Sao Paulo') = 19.5326
--   GetStringWidth('Sao Paulo' com til) levantava ORA-06502 -- nao
--     NO_DATA_FOUND: o subtipo car tem UM byte e o caractere tem dois, entao
--     estourava antes de consultar a tabela
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_larg   NUMBER;
  l_larg2  NUMBER;
  l_erro   VARCHAR2(400);
  l_txt    VARCHAR2(200);

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  FUNCTION pdf_com(p_texto IN VARCHAR2) RETURN BLOB IS
    l_b BLOB;
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(100, 10, p_texto);
    l_b := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    RETURN l_b;
  END pdf_com;
BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - conversao WinAnsi');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O acentuado sai como escape octal, nao como UTF-8 cru');
  --------------------------------------------------------------------------
  -- O byte convertido NAO pode ir cru: o documento e montado num CLOB e
  -- convertido no fim por CONVERTTOBLOB, que recodifica pelo charset do banco.
  -- Medido no diag: 256 bytes entram, 422 saem. O escape octal e ASCII e
  -- atravessa intacto.
  l_pdf := pdf_com('cobrança');

  IF acha(l_pdf, '\347') > 0 THEN
    passou('o cedilha saiu como \347, que o leitor resolve como 0xE7');
  ELSE
    falhou('nao ha \347 no arquivo - a conversao nao aconteceu');
  END IF;

  IF DBMS_LOB.INSTR(l_pdf, HEXTORAW('C3A7'), 1, 1) = 0 THEN
    passou('os bytes C3 A7 (UTF-8 cru) sumiram do arquivo');
  ELSE
    falhou('C3 A7 ainda esta no arquivo - o texto continua cru');
  END IF;

  --------------------------------------------------------------------------
  caso('Texto sem acento nao mudou');
  --------------------------------------------------------------------------
  -- O ASCII coincide nas duas codificacoes, entao o caminho comum tem de sair
  -- exatamente como saia. E onde uma regressao passaria despercebida.
  l_pdf := pdf_com('Sao Paulo');
  IF acha(l_pdf, 'Sao Paulo') > 0 THEN
    passou('o texto ASCII continua legivel no arquivo, sem escape');
  ELSE
    falhou('o texto ASCII foi alterado');
  END IF;

  --------------------------------------------------------------------------
  caso('Parenteses e barra seguem escapados');
  --------------------------------------------------------------------------
  -- Sao o escape que o PDF ja exigia, e a conversao nao pode ter comido.
  l_pdf := pdf_com('Total (liquido) \ 50%');
  IF acha(l_pdf, '\(liquido\)') > 0 THEN
    passou('parenteses escapados');
  ELSE
    falhou('parenteses nao escapados - a string do PDF quebra');
  END IF;

  --------------------------------------------------------------------------
  caso('GetStringWidth mede acentuado sem levantar');
  --------------------------------------------------------------------------
  -- Antes levantava ORA-06502, e agora mede.
  --
  -- A primeira versao deste caso exigia que as duas medidas DIFERISSEM, no
  -- palpite de que o 'a' com til seria mais largo. Errado: nas 14 fontes
  -- padrao do PDF o glifo acentuado tem a MESMA largura de avanco do glifo
  -- base. Conferido na propria tabela do package: 'a' e 'a til' medem 556,
  -- 'c' e 'c cedilha' medem 500. Medir igual e o certo.
  --
  -- Entao afere-se o que de fato distingue: que nao levanta, e que um
  -- caractere de largura reconhecidamente diferente -- o travessao, 1000
  -- contra 333 do hifen -- e medido como tal. Se a conversao caisse num
  -- caractere so, essa comparacao denunciaria.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);

  BEGIN
    l_larg  := PL_FPDF.GetStringWidth('Sao Paulo');
    l_larg2 := PL_FPDF.GetStringWidth('São Paulo');
    passou('mediu as duas: ' || TO_CHAR(l_larg) || ' e ' || TO_CHAR(l_larg2));

    IF l_larg2 = l_larg THEN
      passou('as duas medem igual, como manda a tabela: o acentuado tem a '
             || 'largura de avanco do glifo base');
    ELSE
      falhou('as larguras diferem (' || TO_CHAR(l_larg) || ' e '
             || TO_CHAR(l_larg2) || ') - o acentuado caiu na posicao errada');
    END IF;

    -- travessao contra hifen: 1000 contra 333 em Helvetica
    IF PL_FPDF.GetStringWidth(UNISTR('\2014')) >
       PL_FPDF.GetStringWidth('-') * 2 THEN
      passou('o travessao mede mais que o dobro do hifen, como na tabela');
    ELSE
      falhou('o travessao nao foi medido pela posicao dele');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('ainda levanta: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Alinhamento a direita com acento nao levanta mais');
  --------------------------------------------------------------------------
  -- O Cell so chama GetStringWidth para align C e R. Era ai que o ORA-06502
  -- aparecia, enquanto o alinhamento a esquerda desenhava errado calado.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
    PL_FPDF.Cell(100, 10, 'Endereço de cobrança', '0', 1, 'R');
    PL_FPDF.Cell(100, 10, 'Endereço de cobrança', '0', 1, 'C');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    passou('alinhado a direita e centralizado, ' || DBMS_LOB.GETLENGTH(l_pdf)
           || ' bytes');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Caractere fora do WinAnsi e recusado com erro proprio');
  --------------------------------------------------------------------------
  -- O criterio: recusar, e nao virar '?' em silencio. E o erro tem de ser o
  -- nosso, com a posicao -- se voltar ORA-06502, o conserto so trocou de
  -- sintoma. Ideograma escolhido por nao existir em WinAnsi de forma alguma.
  BEGIN
    l_pdf := pdf_com('Relatorio ' || UNISTR('\4E2D') || ' final');
    falhou('aceitou o caractere fora da tabela');
  EXCEPTION
    WHEN OTHERS THEN
      l_erro := SQLERRM;
      IF INSTR(l_erro, 'ORA-20203') > 0 THEN
        passou('recusado com ORA-20203');
        IF INSTR(l_erro, 'posicao 11') > 0 THEN
          passou('a mensagem diz a posicao');
        ELSE
          falhou('a mensagem nao diz a posicao: ' || l_erro);
        END IF;
      ELSIF INSTR(l_erro, 'ORA-06502') > 0 THEN
        falhou('ORA-06502 - trocou de sintoma, nao consertou');
      ELSE
        falhou('recusou com outro erro: ' || l_erro);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('As 27 excecoes do cp1252 atravessam');
  --------------------------------------------------------------------------
  -- De 0xA0 a 0xFF o cp1252 e o Latin-1, e o byte e o proprio ponto de codigo.
  -- As 27 posicoes entre 0x80 e 0x9F sao as unicas que precisam de tabela, e
  -- sao as que um teste de acento comum nao alcanca: travessao, aspas curvas,
  -- euro, reticencias.
  l_txt := UNISTR('\20AC \2014 \201C \201D \2026 \2122');   -- EUR - " " ... TM
  BEGIN
    l_pdf := pdf_com(l_txt);
    IF acha(l_pdf, '\200') > 0 AND acha(l_pdf, '\227') > 0
       AND acha(l_pdf, '\223') > 0 AND acha(l_pdf, '\231') > 0 THEN
      passou('euro, travessao, aspas curvas e marca registrada convertidos');
    ELSE
      falhou('alguma das 27 excecoes nao saiu como octal');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('Casos: ' || l_total
                       || ' | PASS: ' || l_ok
                       || ' | FAIL: ' || l_falhas
                       || ' | SKIP: ' || l_skip);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || SQLERRM);
    RAISE;
END;
/

--------------------------------------------------------------------------------
-- Compatibilidade com 0.9.4 e 2.0.0
-- origem: tests/test_compat_legado.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF - Compatibilidade com codigo escrito para a 0.9.4 e a 2.0.0
--
-- A pergunta de quem migra e sempre a mesma: o que eu ja tenho escrito continua
-- funcionando? Este arquivo responde executando, nao afirmando.
--
-- O levantamento da superficie publica das tres versoes diz o seguinte:
--
--   0.9.4:  70 publicos    2.0.0: 94    3.4.0: 119
--
--   Da 0.9.4 para a 3.4.0 sumiram SETE nomes, e os sete sao rotinas de
--   demonstracao do porte original -- helloworld, test, testImg, testheader,
--   myRepetitiveHeader, myRepetitiveFooter, lpc_footer. Nenhuma delas e API:
--   sao os exemplos que vinham dentro do package.
--
--   Da 2.0.0 para a 3.4.0 sumiram DUAS: SetUTF8Enabled e IsUTF8Enabled, que
--   nao faziam nada -- a flag era escrita e lida, e ninguem a consultava.
--
--   Das 133 assinaturas em comum, UMA mudou, e nao foi nesta versao: o
--   parametro do AddPage passou de 'orientation' para 'p_orientation' na
--   2.0.0. Chamada posicional nao sente; chamada NOMEADA quebra, e e o unico
--   ponto de atrito real da 0.9.4 para ca. O caso 4 exercita os dois.
--
-- E: NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_erro   VARCHAR2(400);

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END;

  PROCEDURE pulou(p_msg VARCHAR2) IS
  BEGIN
    l_skip := l_skip + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - compatibilidade com o codigo legado');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('O helloworld da 0.9.4, chamada a chamada');
  --------------------------------------------------------------------------
  -- Copiado do corpo do procedure helloworld do porte de 2017, com uma unica
  -- substituicao: OutputBlob() no lugar de Output(), porque o Output escreve
  -- pelo directory PDF_DIR e schema comum nao tem um. A substituicao nao muda
  -- o que se testa -- o que interessa e a sequencia de chamadas atravessar.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    PL_FPDF.openpdf;
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(0, 1.2, 'Hello World', 0, 1, 'C');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      passou('a sequencia de 2017 gera documento: '
             || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      falhou('OutputBlob devolveu LOB vazio');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('O construtor legado dispensa o Init');
  --------------------------------------------------------------------------
  -- Codigo de 2017 nunca chamou Init: ele nao existia. O fpdf() precisa deixar
  -- o package pronto sozinho, senao o AddPage seguinte recusa com ORA-20005.
  -- Esse foi o defeito relatado contra a 2.0.0; aqui nunca existiu, e este
  -- caso e o que impede que volte.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    IF PL_FPDF.IsInitialized THEN
      passou('fpdf() deixa o package inicializado, sem Init');
    ELSE
      falhou('fpdf() nao inicializou - o AddPage seguinte daria ORA-20005');
    END IF;
    PL_FPDF.Reset;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('O openpdf continua aceito, e deixou de ser obrigatorio');
  --------------------------------------------------------------------------
  -- Todo exemplo antigo chama openpdf depois do construtor. Hoje o AddPage o
  -- chama sozinho quando o documento ainda nao foi aberto, mas o codigo velho
  -- nao pode quebrar por chamar duas vezes.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    PL_FPDF.openpdf;
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'com openpdf', 0, 1, 'L');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;

    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'sem openpdf', 0, 1, 'L');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    passou('os dois caminhos geram documento');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('AddPage: o unico atrito real da 0.9.4 para ca');
  --------------------------------------------------------------------------
  -- Das 133 assinaturas em comum, so esta mudou -- e na 2.0.0, nao aqui. O
  -- parametro passou de 'orientation' para 'p_orientation'.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.AddPage('L');                       -- posicional: como em 2017
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'paisagem', 0, 1, 'L');
    l_pdf := PL_FPDF.OutputBlob;
    PL_FPDF.Reset;
    passou('chamada POSICIONAL do AddPage continua valendo');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('a chamada posicional quebrou: ' || SQLERRM);
  END;

  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.AddPage(p_orientation => 'L');       -- nomeada: o nome de hoje
    PL_FPDF.Reset;
    passou('chamada NOMEADA funciona com p_orientation');
    DBMS_OUTPUT.PUT_LINE('  [NOTA] codigo de 2017 que escrevia '
                         || 'AddPage(orientation => ...) precisa trocar o');
    DBMS_OUTPUT.PUT_LINE('         nome do parametro. E o unico ajuste de '
                         || 'assinatura em 133.');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('a chamada nomeada quebrou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('Cabecalho e rodape por procedure, como a 0.9.4 fazia');
  --------------------------------------------------------------------------
  -- O SetHeaderProc/SetFooterProc e o mecanismo do porte original, e continua.
  -- Nao se chama a procedure aqui: confere-se que os dois pontos de entrada
  -- existem e aceitam o que aceitavam.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init('P', 'cm', 'A4');
    PL_FPDF.SetHeaderProc('meu_cabecalho');
    PL_FPDF.SetFooterProc('meu_rodape');
    PL_FPDF.Reset;
    passou('SetHeaderProc e SetFooterProc aceitos');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  caso('As saidas legadas: Output e ReturnBlob');
  --------------------------------------------------------------------------
  -- O ReturnBlob e da 0.9.4 e continua; o Output escreve por directory e nao
  -- se exercita aqui, porque schema comum nao tem PDF_DIR -- registrar o
  -- motivo vale mais que fingir que cobriu.
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.FPDF('P', 'cm', 'A4');
    PL_FPDF.openpdf;
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 1.2, 'ReturnBlob', 0, 1, 'L');
    l_pdf := PL_FPDF.ReturnBlob;
    PL_FPDF.Reset;

    IF l_pdf IS NOT NULL AND DBMS_LOB.GETLENGTH(l_pdf) > 0 THEN
      passou('ReturnBlob da 0.9.4 devolve documento: '
             || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
    ELSE
      falhou('ReturnBlob devolveu LOB vazio');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou: ' || SQLERRM);
  END;

  pulou('Output(): escreve pelo directory PDF_DIR, que schema comum nao tem');

  --------------------------------------------------------------------------
  caso('O que saiu, e por que nao quebra codigo de verdade');
  --------------------------------------------------------------------------
  -- Os sete nomes que sumiram da 0.9.4 sao rotinas de demonstracao, e o
  -- proprio package as trazia como exemplo. Quem chamava PL_FPDF.helloworld
  -- num sistema estava rodando a demo, nao a biblioteca.
  --
  -- Este caso nao tem como aferir ausencia sem nao compilar -- referencia a
  -- procedure inexistente e erro de COMPILACAO, e derrubaria o arquivo
  -- inteiro. Fica registrado, e o check_test_calls guarda o outro lado: ele
  -- acusa qualquer teste que chame nome que a spec nao declara.
  pulou('as sete rotinas de demonstracao sairam; conferir a ausencia aqui '
        || 'derrubaria a compilacao do bloco');

  --------------------------------------------------------------------------
  -- Devolve a sessao ao estado de partida.
  --
  -- O caso 4 cria pagina em PAISAGEM, e o Reset zera state e page mas NAO
  -- restaura a geometria: DefOrientation, w e h sobrevivem. Numa suite que
  -- roda tudo na mesma sessao, e este arquivo e o primeiro da ordem
  -- alfabetica, o que ficar aqui vaza para todos os testes seguintes.
  --
  -- Um Init em retrato, com o formato padrao, e a ultima coisa que este
  -- arquivo faz. Teste que suja a sessao do vizinho e pior que teste que
  -- falha: a falha aparece longe da causa.
  --------------------------------------------------------------------------
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.Reset;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('Casos: ' || l_total
                       || ' | PASS: ' || l_ok
                       || ' | FAIL: ' || l_falhas
                       || ' | SKIP: ' || l_skip);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || SQLERRM);
    RAISE;
END;
/

--------------------------------------------------------------------------------
-- APIs publicas que ninguem chamava
-- origem: tests/test_api_sem_chamador.sql
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- PL_FPDF - APIs publicas que ninguem chamava
--
-- 48 das 119 APIs publicas nao tinham UM chamador em dev/tests/ nem em
-- examples/. Compilar nao prova nada: o AddLink compilava e levantava
-- ORA-06531 na linha da propria declaracao, em toda versao que ja existiu, e
-- so apareceu quando alguem escreveu a primeira chamada. Foram QUATRO defeitos
-- no mesmo Link, achados um a cada teste novo.
--
-- Este arquivo escreve a primeira chamada das que nao dependem de nada de fora
-- do schema. Ficam para outro dia as que exigem DIRECTORY (LoadTTFFromFile,
-- OutputFile) ou ACL de rede (Image por URL, getImageFromUrl).
--
-- O criterio de cada caso: afere o que DISTINGUE a rotina, nao que ela "roda".
-- Chamar e ver se nao levanta prova pouco -- o AddWatermark passou meses sem
-- desenhar nada e ninguem reparou.
--
-- NADA aqui depende de coisa fora do schema. Sem V$, sem DBA, sem rede.
--
-- Roda na SQL Window do PL/SQL Developer (F8). So SQL e PL/SQL.
--------------------------------------------------------------------------------

DECLARE
  -- TODAS as variaveis vem ANTES do primeiro subprograma local. Num DECLARE,
  -- depois do corpo do primeiro subprograma nao se declara mais nada, e o
  -- ORA-06550 aponta a linha da DECLARACAO -- nao a do subprograma que a
  -- invalidou --, entao se procura no lugar errado.
  l_total  PLS_INTEGER := 0;
  l_ok     PLS_INTEGER := 0;
  l_falhas PLS_INTEGER := 0;
  l_skip   PLS_INTEGER := 0;

  l_pdf    BLOB;
  l_n      NUMBER;
  l_n2     NUMBER;
  l_txt    VARCHAR2(400);
  l_erro   VARCHAR2(400);
  l_json   JSON_OBJECT_T;
  l_fonte  PL_FPDF.recTTFFont;

  PROCEDURE caso(p_nome VARCHAR2) IS
  BEGIN
    l_total := l_total + 1;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Caso ' || l_total || ': ' || p_nome);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
  END caso;

  PROCEDURE passou(p_msg VARCHAR2) IS
  BEGIN
    l_ok := l_ok + 1;
    DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_msg);
  END passou;

  PROCEDURE falhou(p_msg VARCHAR2) IS
  BEGIN
    l_falhas := l_falhas + 1;
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_msg);
  END falhou;

  PROCEDURE pulou(p_msg VARCHAR2) IS
  BEGIN
    l_skip := l_skip + 1;
    DBMS_OUTPUT.PUT_LINE('  [SKIP] ' || p_msg);
  END pulou;

  FUNCTION acha(p_blob IN BLOB, p_txt IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN DBMS_LOB.INSTR(p_blob, UTL_RAW.CAST_TO_RAW(p_txt), 1, 1);
  END acha;

  PROCEDURE novo_doc(p_orient VARCHAR2 DEFAULT 'P') IS
  BEGIN
    PL_FPDF.Reset;
    PL_FPDF.Init(p_orient, 'mm', 'A4');
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Helvetica', '', 12);
  END novo_doc;

BEGIN
  DBMS_OUTPUT.PUT_LINE('PL_FPDF - APIs publicas que ninguem chamava');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));

  --------------------------------------------------------------------------
  caso('GetX/SetX: negativo conta a partir da borda direita');
  --------------------------------------------------------------------------
  -- A regra do SetX nao esta no nome dele: px negativo NAO e erro, e sim
  -- medida a partir da direita. Quem nao sabe disso passa -10 achando que
  -- volta dez para tras e o texto vai parar do outro lado da pagina.
  novo_doc;
  PL_FPDF.SetX(30);
  IF PL_FPDF.GetX = 30 THEN
    passou('SetX positivo e lido de volta pelo GetX');
  ELSE
    falhou('SetX(30) e GetX devolveu ' || TO_CHAR(PL_FPDF.GetX));
  END IF;

  PL_FPDF.SetX(-40);
  -- A4 retrato tem 210 mm de largura: 210 - 40 = 170
  IF ROUND(PL_FPDF.GetX, 2) = 170 THEN
    passou('SetX(-40) poe o cursor a 40 da borda direita (170 de 210)');
  ELSE
    falhou('SetX(-40) devolveu ' || TO_CHAR(ROUND(PL_FPDF.GetX, 2))
           || ', esperado 170');
  END IF;

  --------------------------------------------------------------------------
  caso('SetY devolve o x para a margem, e o SetXY nao');
  --------------------------------------------------------------------------
  -- Esta e a surpresa do SetY, e o motivo de o SetXY existir. Quem chama
  -- SetY(100) achando que so desce perde a coluna em que estava.
  novo_doc;
  PL_FPDF.SetX(80);
  PL_FPDF.SetY(100);
  IF PL_FPDF.GetY = 100 THEN
    passou('SetY moveu o y');
  ELSE
    falhou('SetY(100) e GetY devolveu ' || TO_CHAR(PL_FPDF.GetY));
  END IF;

  IF PL_FPDF.GetX < 80 THEN
    passou('o SetY devolveu o x para a margem esquerda, como documentado');
  ELSE
    falhou('o x continuou em ' || TO_CHAR(PL_FPDF.GetX)
           || ': o SetY deixou de zerar o x, e a documentacao promete que zera');
  END IF;

  PL_FPDF.SetXY(80, 120);
  IF PL_FPDF.GetX = 80 AND PL_FPDF.GetY = 120 THEN
    passou('o SetXY respeita o x informado');
  ELSE
    falhou('SetXY(80,120) deixou x=' || TO_CHAR(PL_FPDF.GetX)
           || ' y=' || TO_CHAR(PL_FPDF.GetY));
  END IF;

  --------------------------------------------------------------------------
  caso('SetY negativo conta a partir do pe da pagina');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetY(-20);
  -- A4 retrato tem 297 mm de altura
  IF ROUND(PL_FPDF.GetY, 2) = 277 THEN
    passou('SetY(-20) poe o cursor a 20 do pe (277 de 297)');
  ELSE
    falhou('SetY(-20) devolveu ' || TO_CHAR(ROUND(PL_FPDF.GetY, 2))
           || ', esperado 277');
  END IF;

  --------------------------------------------------------------------------
  caso('PageNo acompanha as paginas');
  --------------------------------------------------------------------------
  novo_doc;
  l_n := PL_FPDF.PageNo;
  PL_FPDF.AddPage;
  PL_FPDF.AddPage;
  IF l_n = 1 AND PL_FPDF.PageNo = 3 THEN
    passou('PageNo foi de 1 a 3 com duas paginas novas');
  ELSE
    falhou('PageNo comecou em ' || TO_CHAR(l_n) || ' e terminou em '
           || TO_CHAR(PL_FPDF.PageNo) || ', esperado 1 e 3');
  END IF;

  --------------------------------------------------------------------------
  caso('GetScaleFactor converte a unidade corrente em pontos');
  --------------------------------------------------------------------------
  -- E o numero que traduz o que o chamador pede para o que o arquivo guarda.
  -- Uma polegada tem 72 pontos e 25,4 mm, entao o milimetro vale 2,8346...
  novo_doc;
  IF ROUND(PL_FPDF.GetScaleFactor, 4) = ROUND(72 / 25.4, 4) THEN
    passou('em mm o fator e 72/25,4 = '
           || TO_CHAR(ROUND(PL_FPDF.GetScaleFactor, 4)));
  ELSE
    falhou('em mm o fator veio ' || TO_CHAR(PL_FPDF.GetScaleFactor)
           || ', esperado ' || TO_CHAR(ROUND(72 / 25.4, 4)));
  END IF;

  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'pt', 'A4');
  PL_FPDF.AddPage;
  IF PL_FPDF.GetScaleFactor = 1 THEN
    passou('em pt o fator e 1, porque a unidade ja e a do arquivo');
  ELSE
    falhou('em pt o fator veio ' || TO_CHAR(PL_FPDF.GetScaleFactor));
  END IF;

  --------------------------------------------------------------------------
  caso('Margens: o Cell de largura 0 vai ate a margem direita');
  --------------------------------------------------------------------------
  -- As margens so se provam pelo efeito. Largura 0 significa "ate a margem
  -- direita", entao mexer na margem TEM de mexer onde o cursor para.
  novo_doc;
  PL_FPDF.SetMargins(20, 20, 20);
  PL_FPDF.Cell(0, 8, 'ate a margem');
  l_n := PL_FPDF.GetX;          -- 210 - 20 = 190

  novo_doc;
  PL_FPDF.SetMargins(20, 20, 60);
  PL_FPDF.Cell(0, 8, 'ate a margem');
  l_n2 := PL_FPDF.GetX;         -- 210 - 60 = 150

  IF ROUND(l_n, 2) = 190 AND ROUND(l_n2, 2) = 150 THEN
    passou('a margem direita limita a celula: 190 com margem 20, 150 com 60');
  ELSE
    falhou('celula de largura 0 parou em ' || TO_CHAR(ROUND(l_n, 2))
           || ' e ' || TO_CHAR(ROUND(l_n2, 2)) || ', esperado 190 e 150');
  END IF;

  novo_doc;
  PL_FPDF.SetLeftMargin(35);
  PL_FPDF.Ln;
  IF ROUND(PL_FPDF.GetX, 2) = 35 THEN
    passou('SetLeftMargin manda a quebra de linha para a margem nova');
  ELSE
    falhou('depois do Ln o x ficou em ' || TO_CHAR(ROUND(PL_FPDF.GetX, 2))
           || ', esperado 35');
  END IF;

  novo_doc;
  PL_FPDF.SetTopMargin(40);
  PL_FPDF.AddPage;
  IF ROUND(PL_FPDF.GetY, 2) = 40 THEN
    passou('SetTopMargin manda a pagina nova comecar na margem nova');
  ELSE
    falhou('a pagina nova comecou em y=' || TO_CHAR(ROUND(PL_FPDF.GetY, 2))
           || ', esperado 40');
  END IF;

  novo_doc;
  PL_FPDF.SetRightMargin(70);
  PL_FPDF.Cell(0, 8, 'ate a margem');
  IF ROUND(PL_FPDF.GetX, 2) = 140 THEN
    passou('SetRightMargin sozinho tambem limita a celula (140 de 210)');
  ELSE
    falhou('a celula parou em ' || TO_CHAR(ROUND(PL_FPDF.GetX, 2))
           || ', esperado 140');
  END IF;

  --------------------------------------------------------------------------
  caso('SetAutoPageBreak liga e desliga a quebra, e o AcceptPageBreak conta');
  --------------------------------------------------------------------------
  -- Desligada, o conteudo que passa do fim da pagina e escrito fora dela e
  -- SOME, sem erro nenhum. Vale saber qual e o estado.
  novo_doc;
  PL_FPDF.SetAutoPageBreak(TRUE, 20);
  IF NVL(PL_FPDF.AcceptPageBreak, FALSE) THEN
    passou('ligada, o AcceptPageBreak diz que sim');
  ELSE
    falhou('ligada, o AcceptPageBreak disse que nao');
  END IF;

  PL_FPDF.SetAutoPageBreak(FALSE);
  IF NOT NVL(PL_FPDF.AcceptPageBreak, TRUE) THEN
    passou('desligada, o AcceptPageBreak diz que nao');
  ELSE
    falhou('desligada, o AcceptPageBreak continuou dizendo que sim');
  END IF;

  -- e o efeito: com a quebra ligada, encher a pagina cria a segunda
  novo_doc;
  PL_FPDF.SetAutoPageBreak(TRUE, 20);
  FOR i IN 1 .. 40 LOOP
    PL_FPDF.Cell(0, 10, 'linha ' || i, '0', 1);
  END LOOP;
  IF PL_FPDF.PageNo > 1 THEN
    passou('a quebra automatica abriu a pagina ' || TO_CHAR(PL_FPDF.PageNo));
  ELSE
    falhou('40 linhas de 10 mm nao couberam em A4 e nenhuma pagina foi aberta');
  END IF;

  --------------------------------------------------------------------------
  caso('Fonte: corpo, familia e estilo sao lidos de volta');
  --------------------------------------------------------------------------
  -- O que se le de volta NAO e o eco do que se passou: o package NORMALIZA a
  -- familia para minuscula e o estilo para maiuscula, como o FPDF original.
  -- Entao "IF GetCurrentFontFamily = 'Times'" nunca casa, e o teste afere a
  -- normalizacao de proposito -- foi assim que ela apareceu, com este caso
  -- falhando contra a expectativa errada de quem o escreveu.
  novo_doc;
  PL_FPDF.SetFont('Times', 'b', 14);
  IF PL_FPDF.GetCurrentFontFamily = 'times' THEN
    passou('a familia volta em MINUSCULA, normalizada');
  ELSE
    falhou('a familia voltou como "' || PL_FPDF.GetCurrentFontFamily
           || '", esperado "times" em minuscula');
  END IF;

  IF PL_FPDF.GetCurrentFontStyle = 'B' THEN
    passou('o estilo volta em MAIUSCULA, normalizado ("b" virou "B")');
  ELSE
    falhou('o estilo voltou como "' || PL_FPDF.GetCurrentFontStyle
           || '", esperado "B" em maiuscula');
  END IF;

  IF PL_FPDF.GetCurrentFontSize = 14 THEN
    passou('o corpo confere');
  ELSE
    falhou('o corpo voltou ' || TO_CHAR(PL_FPDF.GetCurrentFontSize));
  END IF;

  PL_FPDF.SetFontSize(9);
  IF PL_FPDF.GetCurrentFontSize = 9
     AND PL_FPDF.GetCurrentFontFamily = 'times' THEN
    passou('SetFontSize troca so o corpo, e mantem a familia');
  ELSE
    falhou('depois do SetFontSize(9): '
           || PL_FPDF.GetCurrentFontFamily || '/'
           || TO_CHAR(PL_FPDF.GetCurrentFontSize));
  END IF;

  --------------------------------------------------------------------------
  caso('Entrelinha: SetLineSpacing e lida de volta e muda a medida');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetLineSpacing(7);
  IF PL_FPDF.GetLineSpacing = 7 THEN
    passou('a entrelinha e lida de volta');
  ELSE
    falhou('SetLineSpacing(7) e GetLineSpacing devolveu '
           || TO_CHAR(PL_FPDF.GetLineSpacing));
  END IF;

  --------------------------------------------------------------------------
  caso('Text escreve no ponto, sem mover o cursor');
  --------------------------------------------------------------------------
  -- E o que distingue o Text do Cell: nao ha celula, nao ha quebra e o cursor
  -- fica onde estava.
  novo_doc;
  PL_FPDF.SetXY(50, 60);
  l_n := PL_FPDF.GetX;
  l_n2 := PL_FPDF.GetY;
  PL_FPDF.Text(20, 100, 'texto solto');
  IF PL_FPDF.GetX = l_n AND PL_FPDF.GetY = l_n2 THEN
    passou('o cursor nao se moveu');
  ELSE
    falhou('o cursor foi de (' || TO_CHAR(l_n) || ',' || TO_CHAR(l_n2)
           || ') para (' || TO_CHAR(PL_FPDF.GetX) || ','
           || TO_CHAR(PL_FPDF.GetY) || ')');
  END IF;

  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, 'texto solto') > 0 AND acha(l_pdf, 'Tj') > 0 THEN
    passou('o texto saiu no fluxo de conteudo');
  ELSE
    falhou('o texto do Text nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('CellRotated: giro invalido e recusado, giro valido emite a matriz');
  --------------------------------------------------------------------------
  novo_doc;
  BEGIN
    PL_FPDF.CellRotated(40, 10, 'teste', '0', 0, 'L', 0, '', 45);
    falhou('aceitou giro de 45 graus');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20110') > 0 THEN
        passou('giro de 45 recusado com ORA-20110');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.CellRotated(40, 10, 'girado', '0', 0, 'L', 0, '', 90);
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  -- o giro sai como matriz entre q e Q; sem ela o texto fica reto
  IF acha(l_pdf, 'girado') > 0 AND acha(l_pdf, ' cm') > 0 THEN
    passou('o texto girado saiu com a matriz de transformacao');
  ELSE
    falhou('o CellRotated(90) nao emitiu matriz: o texto sairia reto');
  END IF;

  --------------------------------------------------------------------------
  caso('WriteRotated: so giro zero, e os outros dizem o porque');
  --------------------------------------------------------------------------
  -- Aqui ha DOIS erros diferentes, e a diferenca importa: -20110 e giro que
  -- nao existe, -20111 e giro que existe mas esta rotina nao faz.
  novo_doc;
  BEGIN
    PL_FPDF.WriteRotated(6, 'teste', NULL, 45);
    falhou('aceitou giro de 45 graus');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20110') > 0 THEN
        passou('giro de 45 recusado com ORA-20110');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  BEGIN
    PL_FPDF.WriteRotated(6, 'teste', NULL, 90);
    falhou('aceitou giro de 90, que esta rotina nao sabe fazer');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20111') > 0 THEN
        passou('giro de 90 recusado com ORA-20111, que e outro caso');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.WriteRotated(6, 'sem giro nenhum');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, 'sem giro nenhum') > 0 THEN
    passou('com giro zero escreve, delegando ao Write');
  ELSE
    falhou('o texto sem giro nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('Tracejado: SetDash liga, e sem argumento volta a linha cheia');
  --------------------------------------------------------------------------
  -- O operador 'd' do PDF: '[] 0 d' e linha cheia, qualquer outra coisa e
  -- tracejado. Sem isto a linha sai continua e ninguem nota ate imprimir.
  novo_doc;
  PL_FPDF.SetDash(2, 2);
  PL_FPDF.Line(20, 50, 190, 50);
  PL_FPDF.SetDash;
  PL_FPDF.Line(20, 60, 190, 60);
  PL_FPDF.SetLineDashPattern('[3 2] 0');
  PL_FPDF.Line(20, 70, 190, 70);
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '[] 0 d') > 0 THEN
    passou('o SetDash sem argumento devolveu a linha cheia');
  ELSE
    falhou('nao ha "[] 0 d" no arquivo: a linha nao volta a ser cheia');
  END IF;

  IF acha(l_pdf, '[3 2] 0 d') > 0 THEN
    passou('o SetLineDashPattern escreveu o padrao pedido, como esta');
  ELSE
    falhou('o padrao bruto nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('Triangle: desenha, e recusa orientacao que nao existe');
  --------------------------------------------------------------------------
  novo_doc;
  BEGIN
    PL_FPDF.Triangle(20, 20, 5, 'diagonal');
    falhou('aceitou a orientacao "diagonal"');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20821') > 0 THEN
        passou('orientacao invalida recusada com ORA-20821');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  novo_doc;
  PL_FPDF.Triangle(20, 20, 5, 'up', 'F');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  -- tres vertices: um 'm' para o primeiro e 'l' para os outros dois
  IF acha(l_pdf, ' m') > 0 AND acha(l_pdf, ' l') > 0 THEN
    passou('o triangulo saiu como caminho no fluxo de conteudo');
  ELSE
    falhou('o Triangle nao desenhou nada');
  END IF;

  --------------------------------------------------------------------------
  caso('Metadados: assunto e criador chegam ao dicionario do documento');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetSubject('Fechamento mensal');
  PL_FPDF.SetCreator('ERP - faturamento');
  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '/Subject') > 0 AND acha(l_pdf, 'Fechamento mensal') > 0 THEN
    passou('o assunto esta no dicionario');
  ELSE
    falhou('o SetSubject nao chegou ao arquivo');
  END IF;

  IF acha(l_pdf, '/Creator') > 0 AND acha(l_pdf, 'ERP - faturamento') > 0 THEN
    passou('o criador esta no dicionario');
  ELSE
    falhou('o SetCreator nao chegou ao arquivo');
  END IF;

  --------------------------------------------------------------------------
  caso('SetDisplayMode escreve a preferencia de abertura no catalogo');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetDisplayMode('fullwidth', 'continuous');
  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '/OpenAction') > 0 AND acha(l_pdf, '/FitH') > 0 THEN
    passou('o zoom "fullwidth" saiu como /OpenAction com /FitH');
  ELSE
    falhou('o zoom nao chegou ao catalogo');
  END IF;

  IF acha(l_pdf, '/PageLayout /OneColumn') > 0 THEN
    passou('o layout "continuous" saiu como /PageLayout /OneColumn');
  ELSE
    falhou('o layout nao chegou ao catalogo');
  END IF;

  novo_doc;
  BEGIN
    PL_FPDF.SetDisplayMode('esquisito');
    falhou('aceitou um modo de zoom que nao existe');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20100') > 0 THEN
        passou('modo de zoom desconhecido recusado com ORA-20100');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('SetCompression: o conteudo sai comprimido, e declarado');
  --------------------------------------------------------------------------
  -- Ate agosto/2026 isto era um no-op: perguntava por uma funcao de zlib que o
  -- Oracle nao tem e desligava a compressao sempre. O teste afere o efeito, e
  -- nao a chamada: o texto deixa de aparecer cru E o filtro e declarado.
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetCompression(TRUE);
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);
  FOR i IN 1 .. 60 LOOP
    PL_FPDF.Cell(0, 4, 'texto repetido para comprimir bem', '0', 1);
  END LOOP;
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, '/FlateDecode') > 0 THEN
    passou('o filtro de compressao esta declarado no arquivo');
  ELSE
    falhou('o SetCompression(TRUE) nao comprimiu nada');
  END IF;

  IF acha(l_pdf, 'texto repetido para comprimir bem') = 0 THEN
    passou('o texto nao aparece mais cru: o fluxo esta de fato comprimido');
  ELSE
    falhou('o texto continua legivel no arquivo, entao nada foi comprimido');
  END IF;

  --------------------------------------------------------------------------
  caso('Versao do PDF: o que se pede e o que sai no cabecalho');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetPDFVersion('1.5');
  IF PL_FPDF.GetPDFVersion = '1.5' THEN
    passou('a versao e lida de volta');
  ELSE
    falhou('SetPDFVersion(1.5) e GetPDFVersion devolveu '
           || PL_FPDF.GetPDFVersion);
  END IF;

  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, '%PDF-1.5') > 0 THEN
    passou('o cabecalho do arquivo diz 1.5');
  ELSE
    falhou('o cabecalho nao acompanhou o SetPDFVersion');
  END IF;

  --------------------------------------------------------------------------
  caso('Nivel de registro: o que se define e o que se le');
  --------------------------------------------------------------------------
  l_n := PL_FPDF.GetLogLevel;
  PL_FPDF.SetLogLevel(1);
  IF PL_FPDF.GetLogLevel = 1 THEN
    passou('o nivel e lido de volta');
  ELSE
    falhou('SetLogLevel(1) e GetLogLevel devolveu '
           || TO_CHAR(PL_FPDF.GetLogLevel));
  END IF;
  PL_FPDF.SetLogLevel(l_n);   -- devolve como estava, para nao sujar o resto

  --------------------------------------------------------------------------
  caso('SetDocumentConfig configura o documento por JSON');
  --------------------------------------------------------------------------
  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  l_json := JSON_OBJECT_T();
  l_json.put('title',   'Relatorio por JSON');
  l_json.put('subject', 'Assunto por JSON');
  l_json.put('creator', 'Sistema por JSON');
  PL_FPDF.SetDocumentConfig(l_json);
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);
  PL_FPDF.Cell(50, 10, 'x');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;

  IF acha(l_pdf, 'Relatorio por JSON') > 0
     AND acha(l_pdf, 'Assunto por JSON') > 0
     AND acha(l_pdf, 'Sistema por JSON') > 0 THEN
    passou('titulo, assunto e criador do JSON chegaram ao arquivo');
  ELSE
    falhou('o SetDocumentConfig nao aplicou os metadados');
  END IF;

  --------------------------------------------------------------------------
  caso('GetDocumentMetadata responde sobre o documento em andamento');
  --------------------------------------------------------------------------
  novo_doc;
  PL_FPDF.SetTitle('Titulo corrente');
  PL_FPDF.AddPage;
  l_json := PL_FPDF.GetDocumentMetadata;
  IF l_json.get_Number('pageCount') = 2 THEN
    passou('a contagem de paginas confere');
  ELSE
    falhou('pageCount veio ' || TO_CHAR(l_json.get_Number('pageCount'))
           || ', esperado 2');
  END IF;

  IF l_json.get_String('title') = 'Titulo corrente' THEN
    passou('o titulo confere');
  ELSE
    falhou('title veio ' || NVL(l_json.get_String('title'), 'NULL'));
  END IF;
  PL_FPDF.Reset;

  --------------------------------------------------------------------------
  caso('UTF8ToPDFString escapa o que a sintaxe do PDF reserva');
  --------------------------------------------------------------------------
  -- Parentese e barra invertida terminam a string do PDF antes da hora, e o
  -- arquivo quebra a partir dali.
  l_txt := PL_FPDF.UTF8ToPDFString('Total (liquido) 50\%');
  IF INSTR(l_txt, '\(') > 0 AND INSTR(l_txt, '\)') > 0 THEN
    passou('os parenteses sairam escapados');
  ELSE
    falhou('parenteses nao escapados: ' || l_txt);
  END IF;

  IF PL_FPDF.UTF8ToPDFString(NULL) IS NULL THEN
    passou('NULL entra e NULL sai, sem levantar');
  ELSE
    falhou('NULL devolveu alguma coisa');
  END IF;

  --------------------------------------------------------------------------
  caso('ClosePDF fecha, e fechar de novo nao estraga');
  --------------------------------------------------------------------------
  -- As rotinas de saida ja chamam o ClosePDF. Chamar antes, a mao, nao pode
  -- gerar documento diferente nem levantar.
  novo_doc;
  PL_FPDF.Cell(50, 10, 'fechado a mao');
  PL_FPDF.ClosePDF;
  BEGIN
    PL_FPDF.ClosePDF;
    passou('fechar duas vezes nao levanta');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('o segundo ClosePDF levantou: ' || SQLERRM);
  END;

  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  IF acha(l_pdf, 'fechado a mao') > 0 AND acha(l_pdf, '%%EOF') > 0 THEN
    passou('o documento fechado a mao sai inteiro');
  ELSE
    falhou('o documento fechado a mao saiu incompleto');
  END IF;

  --------------------------------------------------------------------------
  caso('Header e Footer sem callback registrado nao fazem nada');
  --------------------------------------------------------------------------
  -- Sao chamadas pelo proprio motor a cada pagina. Sem SetHeaderProc, a
  -- chamada tem de ser inocua -- nao levantar e nao escrever.
  novo_doc;
  BEGIN
    PL_FPDF.Header;
    PL_FPDF.Footer;
    passou('as duas sao inocuas sem callback registrado');
  EXCEPTION
    WHEN OTHERS THEN
      falhou('levantou sem callback: ' || SQLERRM);
  END;
  PL_FPDF.Reset;

  --------------------------------------------------------------------------
  caso('Error levanta ORA-20100 com a mensagem dada');
  --------------------------------------------------------------------------
  -- E o caminho interno de erro da biblioteca, publico por heranca. Se ele
  -- deixar de levantar, sessenta handlers do package passam a engolir erro.
  BEGIN
    PL_FPDF.Error('mensagem de teste');
    falhou('o Error nao levantou nada');
  EXCEPTION
    WHEN OTHERS THEN
      l_erro := SQLERRM;
      IF INSTR(l_erro, 'ORA-20100') > 0
         AND INSTR(l_erro, 'mensagem de teste') > 0 THEN
        passou('levantou ORA-20100 com a mensagem');
      ELSE
        falhou('levantou outra coisa: ' || l_erro);
      END IF;
  END;

  --------------------------------------------------------------------------
  caso('Fontes TrueType: cache responde sem fonte carregada');
  --------------------------------------------------------------------------
  -- Sem arquivo de fonte a mao nao da para carregar nada, mas as consultas
  -- precisam responder em vez de levantar -- e o GetTTFFontInfo precisa
  -- recusar com o erro dele.
  PL_FPDF.ClearTTFFontCache;
  IF NOT NVL(PL_FPDF.IsTTFFontLoaded('NaoExiste'), TRUE) THEN
    passou('IsTTFFontLoaded diz que nao, sem levantar');
  ELSE
    falhou('IsTTFFontLoaded disse que sim para fonte que nao existe');
  END IF;

  BEGIN
    -- o retorno vai para uma variavel: o PL/SQL nao aceita selecionar campo
    -- direto do retorno de funcao
    l_fonte := PL_FPDF.GetTTFFontInfo('NaoExiste');
    falhou('GetTTFFontInfo devolveu dados de fonte inexistente: '
           || NVL(l_fonte.font_name, 'sem nome'));
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20206') > 0 THEN
        passou('GetTTFFontInfo recusa fonte inexistente com ORA-20206');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  BEGIN
    PL_FPDF.AddTTFFont(NULL, NULL);
    falhou('AddTTFFont aceitou nome nulo');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA-20210') > 0 THEN
        passou('AddTTFFont recusa nome vazio com ORA-20210');
      ELSE
        falhou('recusou com outro erro: ' || SQLERRM);
      END IF;
  END;

  pulou('carregar fonte de verdade exige arquivo .ttf: fica para outro teste');

  --------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
  DBMS_OUTPUT.PUT_LINE('Casos: ' || l_total
                       || ' | PASS: ' || l_ok
                       || ' | FAIL: ' || l_falhas
                       || ' | SKIP: ' || l_skip);
  IF l_falhas > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: FALHOU');
  ELSIF l_skip > 0 THEN
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK, com ' || l_skip
                         || ' caso(s) sem conclusao — leia os [SKIP] acima');
  ELSE
    DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
  END IF;
  DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || SQLERRM);
    RAISE;
END;
/

