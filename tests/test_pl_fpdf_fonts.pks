CREATE OR REPLACE PACKAGE test_pl_fpdf_fonts AS
/*******************************************************************************
* Package: test_pl_fpdf_fonts
* Description: utPLSQL test suite for PL_FPDF font handling
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-19
* Task: 3.4 - Unit Tests with utPLSQL
*
* Test Coverage:
*   - Standard font handling (Arial, Courier, Times)
*   - TrueType/OpenType font loading (Task 2.1)
*   - UTF-8 text encoding
*   - Font metrics and character widths
*   - Font embedding
*
* Groups:
*   - basic: Standard fonts
*   - truetype: TrueType/OpenType fonts
*   - encoding: UTF-8 and encoding tests
*   - metrics: Font metrics calculations
*   - smoke: Quick smoke tests
*******************************************************************************/

  -- utPLSQL annotations
  --%suite(PL_FPDF Font Handling Tests)
  --%suitepath(pl_fpdf)

  --%beforeall
  PROCEDURE setup_suite;

  --%afterall
  PROCEDURE teardown_suite;

  --%beforeeach
  PROCEDURE setup_test;

  --%aftereach
  PROCEDURE teardown_test;

  ------------------------------------------------------------------------------
  -- Group 1: Standard Fonts
  ------------------------------------------------------------------------------
  --%test(SetFont accepts Arial)
  --%tags(basic, smoke)
  PROCEDURE test_setfont_arial;

  --%test(SetFont accepts Courier)
  --%tags(basic, smoke)
  PROCEDURE test_setfont_courier;

  --%test(SetFont accepts Times)
  --%tags(basic, smoke)
  PROCEDURE test_setfont_times;

  --%test(SetFont accepts bold style)
  --%tags(basic)
  PROCEDURE test_setfont_bold;

  --%test(SetFont accepts italic style)
  --%tags(basic)
  PROCEDURE test_setfont_italic;

  --%test(SetFont accepts bold-italic style)
  --%tags(basic)
  PROCEDURE test_setfont_bold_italic;

  --%test(SetFont validates size range)
  --%tags(basic)
  PROCEDURE test_setfont_size_validation;

  --%test(SetFont rejects invalid font family)
  --%tags(basic)
  --%throws(-20201)
  PROCEDURE test_setfont_invalid_family;

  ------------------------------------------------------------------------------
  -- Group 2: TrueType Fonts
  ------------------------------------------------------------------------------
  --%test(AddTTFFont validates font blob)
  --%tags(truetype)
  PROCEDURE test_add_ttf_validates_blob;

  --%test(IsTTFFontLoaded detects loaded fonts)
  --%tags(truetype)
  PROCEDURE test_is_ttf_loaded;

  --%test(GetTTFFontInfo returns correct metadata)
  --%tags(truetype)
  PROCEDURE test_get_ttf_info;

  --%test(ClearTTFFontCache removes all fonts)
  --%tags(truetype)
  PROCEDURE test_clear_ttf_cache;

  ------------------------------------------------------------------------------
  -- Group 3: UTF-8 Encoding
  ------------------------------------------------------------------------------
  --%test(UTF8ToPDFString converts correctly)
  --%tags(encoding)
  PROCEDURE test_utf8_conversion;

  --%test(SetUTF8Enabled enables UTF-8 mode)
  --%tags(encoding)
  PROCEDURE test_set_utf8_enabled;

  --%test(UTF-8 text renders correctly)
  --%tags(encoding)
  PROCEDURE test_utf8_rendering;

  ------------------------------------------------------------------------------
  -- Group 4: Font Metrics
  ------------------------------------------------------------------------------
  --%test(GetStringWidth calculates correct width)
  --%tags(metrics)
  PROCEDURE test_get_string_width;

  --%test(Font size affects string width)
  --%tags(metrics)
  PROCEDURE test_font_size_width;

  ------------------------------------------------------------------------------
  -- Smoke Tests
  ------------------------------------------------------------------------------
  --%test(Quick smoke test - basic font operations)
  --%tags(smoke)
  PROCEDURE smoke_test_fonts;

END test_pl_fpdf_fonts;
/
