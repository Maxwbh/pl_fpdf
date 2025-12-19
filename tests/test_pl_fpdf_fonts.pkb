CREATE OR REPLACE PACKAGE BODY test_pl_fpdf_fonts AS

  ------------------------------------------------------------------------------
  -- Setup/Teardown
  ------------------------------------------------------------------------------

  PROCEDURE setup_suite IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting PL_FPDF Font Tests Suite');
  END setup_suite;

  PROCEDURE teardown_suite IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Completed PL_FPDF Font Tests Suite');
  END teardown_suite;

  PROCEDURE setup_test IS
  BEGIN
    -- Initialize before each test
    PL_FPDF.Init();
    PL_FPDF.AddPage();
  END setup_test;

  PROCEDURE teardown_test IS
  BEGIN
    -- Clean up after each test
    PL_FPDF.Reset();
  END teardown_test;

  ------------------------------------------------------------------------------
  -- Group 1: Standard Fonts
  ------------------------------------------------------------------------------

  PROCEDURE test_setfont_arial IS
  BEGIN
    PL_FPDF.SetFont('Arial', '', 12);
    -- If no exception, test passes
    ut.expect(TRUE).to_be_true();
  END test_setfont_arial;

  PROCEDURE test_setfont_courier IS
  BEGIN
    PL_FPDF.SetFont('Courier', '', 12);
    ut.expect(TRUE).to_be_true();
  END test_setfont_courier;

  PROCEDURE test_setfont_times IS
  BEGIN
    PL_FPDF.SetFont('Times', '', 12);
    ut.expect(TRUE).to_be_true();
  END test_setfont_times;

  PROCEDURE test_setfont_bold IS
  BEGIN
    PL_FPDF.SetFont('Arial', 'B', 12);
    ut.expect(TRUE).to_be_true();
  END test_setfont_bold;

  PROCEDURE test_setfont_italic IS
  BEGIN
    PL_FPDF.SetFont('Arial', 'I', 12);
    ut.expect(TRUE).to_be_true();
  END test_setfont_italic;

  PROCEDURE test_setfont_bold_italic IS
  BEGIN
    PL_FPDF.SetFont('Arial', 'BI', 12);
    PL_FPDF.SetFont('Arial', 'IB', 12);  -- Both orders should work
    ut.expect(TRUE).to_be_true();
  END test_setfont_bold_italic;

  PROCEDURE test_setfont_size_validation IS
    l_failed BOOLEAN := FALSE;
  BEGIN
    -- Test valid sizes
    PL_FPDF.SetFont('Arial', '', 1);   -- Minimum
    PL_FPDF.SetFont('Arial', '', 72);  -- Normal
    PL_FPDF.SetFont('Arial', '', 200); -- Large

    -- Test invalid size (negative should fail)
    BEGIN
      PL_FPDF.SetFont('Arial', '', -10);
      l_failed := TRUE;  -- Should not reach here
    EXCEPTION
      WHEN OTHERS THEN
        NULL;  -- Expected to fail
    END;

    ut.expect(l_failed).to_be_false();
  END test_setfont_size_validation;

  PROCEDURE test_setfont_invalid_family IS
  BEGIN
    -- This should raise exc_font_not_found (-20201)
    PL_FPDF.SetFont('NonExistentFont', '', 12);
    ut.expect(TRUE).to_be_false();  -- Should not reach here
  END test_setfont_invalid_family;

  ------------------------------------------------------------------------------
  -- Group 2: TrueType Fonts
  ------------------------------------------------------------------------------

  PROCEDURE test_add_ttf_validates_blob IS
    l_failed BOOLEAN := FALSE;
  BEGIN
    -- Try to add NULL blob
    BEGIN
      PL_FPDF.AddTTFFont('TestFont', NULL);
      l_failed := TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        ut.expect(SQLCODE).to_equal(-20211);  -- exc_invalid_font_blob
    END;

    ut.expect(l_failed).to_be_false();
  END test_add_ttf_validates_blob;

  PROCEDURE test_is_ttf_loaded IS
    l_is_loaded BOOLEAN;
  BEGIN
    -- Test non-existent font
    l_is_loaded := PL_FPDF.IsTTFFontLoaded('NonExistentFont');
    ut.expect(l_is_loaded).to_be_false();
  END test_is_ttf_loaded;

  PROCEDURE test_get_ttf_info IS
    l_info PL_FPDF.recFontInfo;
  BEGIN
    -- Try to get info for non-existent font
    BEGIN
      l_info := PL_FPDF.GetTTFFontInfo('NonExistentFont');
      ut.expect(TRUE).to_be_false();  -- Should not reach here
    EXCEPTION
      WHEN OTHERS THEN
        ut.expect(SQLCODE).to_equal(-20201);  -- exc_font_not_found
    END;
  END test_get_ttf_info;

  PROCEDURE test_clear_ttf_cache IS
  BEGIN
    -- Clear cache should not fail even if empty
    PL_FPDF.ClearTTFFontCache();
    ut.expect(TRUE).to_be_true();
  END test_clear_ttf_cache;

  ------------------------------------------------------------------------------
  -- Group 3: UTF-8 Encoding
  ------------------------------------------------------------------------------

  PROCEDURE test_utf8_conversion IS
    l_result VARCHAR2(1000);
  BEGIN
    -- Test basic ASCII
    l_result := PL_FPDF.UTF8ToPDFString('Hello World');
    ut.expect(l_result).to_be_not_null();
    ut.expect(LENGTH(l_result)).to_be_greater_than(0);

    -- Test with special characters
    l_result := PL_FPDF.UTF8ToPDFString('Olá Mundo! São Paulo - R$123,45');
    ut.expect(l_result).to_be_not_null();
  END test_utf8_conversion;

  PROCEDURE test_set_utf8_enabled IS
  BEGIN
    -- Enable UTF-8
    PL_FPDF.SetUTF8Enabled(TRUE);
    ut.expect(TRUE).to_be_true();

    -- Disable UTF-8
    PL_FPDF.SetUTF8Enabled(FALSE);
    ut.expect(TRUE).to_be_true();
  END test_set_utf8_enabled;

  PROCEDURE test_utf8_rendering IS
    l_blob BLOB;
  BEGIN
    PL_FPDF.SetUTF8Enabled(TRUE);
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test UTF-8: Ação, Coração, São Paulo');
    l_blob := PL_FPDF.OutputBlob();

    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(0);
  END test_utf8_rendering;

  ------------------------------------------------------------------------------
  -- Group 4: Font Metrics
  ------------------------------------------------------------------------------

  PROCEDURE test_get_string_width IS
    l_width NUMBER;
  BEGIN
    PL_FPDF.SetFont('Arial', '', 12);
    l_width := PL_FPDF.GetStringWidth('Test');

    ut.expect(l_width).to_be_greater_than(0);
    ut.expect(l_width).to_be_less_than(100);  -- Reasonable width
  END test_get_string_width;

  PROCEDURE test_font_size_width IS
    l_width_12 NUMBER;
    l_width_24 NUMBER;
  BEGIN
    -- Measure at size 12
    PL_FPDF.SetFont('Arial', '', 12);
    l_width_12 := PL_FPDF.GetStringWidth('Test');

    -- Measure at size 24 (should be approximately 2x)
    PL_FPDF.SetFont('Arial', '', 24);
    l_width_24 := PL_FPDF.GetStringWidth('Test');

    ut.expect(l_width_24).to_be_greater_than(l_width_12);
    -- Should be approximately 2x (allow 10% margin)
    ut.expect(l_width_24).to_be_between(l_width_12 * 1.8, l_width_12 * 2.2);
  END test_font_size_width;

  ------------------------------------------------------------------------------
  -- Smoke Tests
  ------------------------------------------------------------------------------

  PROCEDURE smoke_test_fonts IS
    l_blob BLOB;
  BEGIN
    -- Quick test of common font operations
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Arial Regular');

    PL_FPDF.SetFont('Arial', 'B', 14);
    PL_FPDF.Cell(0, 10, 'Arial Bold');

    PL_FPDF.SetFont('Courier', '', 10);
    PL_FPDF.Cell(0, 10, 'Courier Regular');

    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(500);
  END smoke_test_fonts;

END test_pl_fpdf_fonts;
/
