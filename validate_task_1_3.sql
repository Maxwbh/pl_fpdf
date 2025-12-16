/*******************************************************************************
* Validation Script for Task 1.3: TrueType/Unicode Font Support
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*
* This script validates the implementation of Task 1.3 enhancements:
* - AddTTFFont() from BLOB
* - LoadTTFFromFile() from filesystem
* - IsTTFFontLoaded() checking
* - GetTTFFontInfo() metadata retrieval
* - ClearTTFFontCache() cleanup
* - TTF/OTF header parsing
* - Font caching mechanism
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

PROMPT ======================================================================
PROMPT Task 1.3 Validation: TrueType/Unicode Font Support
PROMPT ======================================================================
PROMPT

DECLARE
  l_test_count pls_integer := 0;
  l_pass_count pls_integer := 0;
  l_test_passed boolean := true;

  -- Test font BLOB (minimal valid TTF header)
  l_test_font_blob blob;
  l_font_info PL_FPDF.recTTFFont;
  l_is_loaded boolean;

  procedure test_result(p_test_name varchar2, p_passed boolean) is
  begin
    l_test_count := l_test_count + 1;
    if p_passed then
      l_pass_count := l_pass_count + 1;
      dbms_output.put_line('[PASS] Test ' || l_test_count || ': ' || p_test_name);
    else
      dbms_output.put_line('[FAIL] Test ' || l_test_count || ': ' || p_test_name);
      l_test_passed := false;
    end if;
  end;

  procedure create_mock_ttf_blob(p_blob in out blob) is
    -- Create a minimal valid TTF file header
    l_ttf_header raw(32767);
  begin
    -- TrueType magic number (version 1.0): 0x00010000
    l_ttf_header := hextoraw('00010000');

    -- Number of tables: 1 (uint16)
    l_ttf_header := utl_raw.concat(l_ttf_header, hextoraw('0001'));

    -- searchRange, entrySelector, rangeShift (dummy values)
    l_ttf_header := utl_raw.concat(l_ttf_header, hextoraw('000000000000'));

    -- Add 'head' table directory entry (minimal)
    -- Tag: 'head' (0x68656164)
    l_ttf_header := utl_raw.concat(l_ttf_header, hextoraw('68656164'));
    -- Checksum (dummy)
    l_ttf_header := utl_raw.concat(l_ttf_header, hextoraw('00000000'));
    -- Offset (dummy)
    l_ttf_header := utl_raw.concat(l_ttf_header, hextoraw('00000000'));
    -- Length (dummy)
    l_ttf_header := utl_raw.concat(l_ttf_header, hextoraw('00000000'));

    -- Create BLOB and write header
    dbms_lob.createtemporary(p_blob, true, dbms_lob.session);
    dbms_lob.writeappend(p_blob, utl_raw.length(l_ttf_header), l_ttf_header);

    dbms_output.put_line('  Created mock TTF BLOB: ' ||
      dbms_lob.getlength(p_blob) || ' bytes');
  end;

BEGIN
  dbms_output.put_line('=== Task 1.3 Validation Tests ===');
  dbms_output.put_line('');

  -- Initialize PDF engine first
  begin
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');
    test_result('Initialize PDF engine', PL_FPDF.IsInitialized());
  exception
    when others then
      test_result('Initialize PDF engine', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 1: Font Cache Operations
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 1: Font Cache Operations ---');

  -- Test 1: IsTTFFontLoaded before loading
  begin
    l_is_loaded := PL_FPDF.IsTTFFontLoaded('TestFont');
    test_result('IsTTFFontLoaded returns FALSE initially', not l_is_loaded);
  exception
    when others then
      test_result('IsTTFFontLoaded initially', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 2: ClearTTFFontCache (on empty cache)
  begin
    PL_FPDF.ClearTTFFontCache();
    test_result('ClearTTFFontCache on empty cache', true);
  exception
    when others then
      test_result('ClearTTFFontCache empty', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 2: AddTTFFont from BLOB
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 2: AddTTFFont from BLOB ---');

  -- Create mock TTF BLOB for testing
  create_mock_ttf_blob(l_test_font_blob);

  -- Test 3: AddTTFFont with valid BLOB
  begin
    PL_FPDF.AddTTFFont('TestFont', l_test_font_blob, 'UTF-8', true);
    test_result('AddTTFFont with valid BLOB', true);
  exception
    when others then
      test_result('AddTTFFont valid BLOB', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 4: IsTTFFontLoaded after loading
  begin
    l_is_loaded := PL_FPDF.IsTTFFontLoaded('TestFont');
    test_result('IsTTFFontLoaded returns TRUE after load', l_is_loaded);
  exception
    when others then
      test_result('IsTTFFontLoaded after load', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 5: GetTTFFontInfo retrieves metadata
  begin
    l_font_info := PL_FPDF.GetTTFFontInfo('TestFont');
    test_result('GetTTFFontInfo retrieves font',
      l_font_info.font_name = 'TESTFONT' and
      l_font_info.encoding = 'UTF-8' and
      l_font_info.units_per_em > 0);
    dbms_output.put_line('  Font: ' || l_font_info.font_name ||
      ', Encoding: ' || l_font_info.encoding ||
      ', UnitsPerEM: ' || l_font_info.units_per_em);
  exception
    when others then
      test_result('GetTTFFontInfo', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 6: AddTTFFont replaces existing font (warning)
  begin
    PL_FPDF.AddTTFFont('TestFont', l_test_font_blob, 'ISO-8859-1', false);
    l_font_info := PL_FPDF.GetTTFFontInfo('TestFont');
    test_result('AddTTFFont replaces existing',
      l_font_info.encoding = 'ISO-8859-1' and
      not l_font_info.is_embedded);
  exception
    when others then
      test_result('AddTTFFont replace', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 7: AddTTFFont with case-insensitive name
  begin
    PL_FPDF.AddTTFFont('lowercase', l_test_font_blob, 'UTF-8', true);
    l_is_loaded := PL_FPDF.IsTTFFontLoaded('LOWERCASE');
    test_result('Font names are case-insensitive', l_is_loaded);
  exception
    when others then
      test_result('Case-insensitive names', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 3: Parameter Validation
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 3: Parameter Validation ---');

  -- Test 8: AddTTFFont with NULL name (should fail)
  begin
    PL_FPDF.AddTTFFont(null, l_test_font_blob, 'UTF-8', true);
    test_result('NULL font name should raise error', false);
  exception
    when others then
      if sqlcode = -20210 then
        test_result('NULL font name raises -20210', true);
      else
        test_result('NULL font name error code', false);
        dbms_output.put_line('  Expected: -20210, Got: ' || sqlcode);
      end if;
  end;

  -- Test 9: AddTTFFont with NULL BLOB (should fail)
  begin
    PL_FPDF.AddTTFFont('NullBlobFont', null, 'UTF-8', true);
    test_result('NULL BLOB should raise error', false);
  exception
    when others then
      if sqlcode = -20211 then
        test_result('NULL BLOB raises -20211', true);
      else
        test_result('NULL BLOB error code', false);
        dbms_output.put_line('  Expected: -20211, Got: ' || sqlcode);
      end if;
  end;

  -- Test 10: AddTTFFont with invalid TTF header (should fail)
  declare
    l_bad_blob blob;
  begin
    dbms_lob.createtemporary(l_bad_blob, true, dbms_lob.session);
    dbms_lob.writeappend(l_bad_blob, 4, hextoraw('DEADBEEF'));  -- Invalid magic
    PL_FPDF.AddTTFFont('BadFont', l_bad_blob, 'UTF-8', true);
    test_result('Invalid TTF header should raise error', false);
    dbms_lob.freetemporary(l_bad_blob);
  exception
    when others then
      if sqlcode = -20200 or sqlcode = -20202 then
        test_result('Invalid TTF header raises error', true);
      else
        test_result('Invalid TTF header error', false);
        dbms_output.put_line('  Expected: -20200 or -20202, Got: ' || sqlcode);
      end if;
      if l_bad_blob is not null and dbms_lob.istemporary(l_bad_blob) = 1 then
        dbms_lob.freetemporary(l_bad_blob);
      end if;
  end;

  -- Test 11: GetTTFFontInfo for non-existent font (should fail)
  begin
    l_font_info := PL_FPDF.GetTTFFontInfo('NonExistentFont');
    test_result('GetTTFFontInfo non-existent should fail', false);
  exception
    when others then
      if sqlcode = -20206 then
        test_result('GetTTFFontInfo non-existent raises -20206', true);
      else
        test_result('GetTTFFontInfo error code', false);
        dbms_output.put_line('  Expected: -20206, Got: ' || sqlcode);
      end if;
  end;

  -------------------------------------------------------------------------
  -- Test Group 4: Multiple Fonts
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 4: Multiple Fonts ---');

  -- Test 12: Load multiple fonts
  begin
    PL_FPDF.AddTTFFont('Font1', l_test_font_blob, 'UTF-8', true);
    PL_FPDF.AddTTFFont('Font2', l_test_font_blob, 'UTF-8', true);
    PL_FPDF.AddTTFFont('Font3', l_test_font_blob, 'ISO-8859-1', false);

    test_result('Load multiple fonts',
      PL_FPDF.IsTTFFontLoaded('Font1') and
      PL_FPDF.IsTTFFontLoaded('Font2') and
      PL_FPDF.IsTTFFontLoaded('Font3'));
  exception
    when others then
      test_result('Multiple fonts', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 13: Retrieve each font's info
  begin
    l_font_info := PL_FPDF.GetTTFFontInfo('Font1');
    test_result('Retrieve Font1 info', l_font_info.font_name = 'FONT1');

    l_font_info := PL_FPDF.GetTTFFontInfo('Font2');
    test_result('Retrieve Font2 info', l_font_info.font_name = 'FONT2');

    l_font_info := PL_FPDF.GetTTFFontInfo('Font3');
    test_result('Retrieve Font3 info',
      l_font_info.font_name = 'FONT3' and
      l_font_info.encoding = 'ISO-8859-1' and
      not l_font_info.is_embedded);
  exception
    when others then
      test_result('Retrieve multiple fonts info', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 5: Cache Management
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 5: Cache Management ---');

  -- Test 16: Clear cache
  begin
    PL_FPDF.ClearTTFFontCache();
    test_result('ClearTTFFontCache clears all fonts', true);
  exception
    when others then
      test_result('ClearTTFFontCache', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -- Test 17: Verify cache is empty
  begin
    l_is_loaded := PL_FPDF.IsTTFFontLoaded('Font1') or
                   PL_FPDF.IsTTFFontLoaded('Font2') or
                   PL_FPDF.IsTTFFontLoaded('Font3');
    test_result('All fonts removed from cache', not l_is_loaded);
  exception
    when others then
      test_result('Verify cache empty', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Test Group 6: OpenType (OTF) Support
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Test Group 6: OpenType Support ---');

  -- Test 18: Load OpenType font (with 'OTTO' magic)
  declare
    l_otf_blob blob;
    l_otf_header raw(32767);
  begin
    -- Create OTF header with 'OTTO' magic
    l_otf_header := hextoraw('4F54544F');  -- 'OTTO'
    l_otf_header := utl_raw.concat(l_otf_header, hextoraw('0001'));  -- 1 table
    l_otf_header := utl_raw.concat(l_otf_header, hextoraw('000000000000'));  -- padding

    dbms_lob.createtemporary(l_otf_blob, true, dbms_lob.session);
    dbms_lob.writeappend(l_otf_blob, utl_raw.length(l_otf_header), l_otf_header);

    PL_FPDF.AddTTFFont('OpenTypeFont', l_otf_blob, 'UTF-8', true);
    test_result('Load OpenType (OTF) font', PL_FPDF.IsTTFFontLoaded('OpenTypeFont'));

    dbms_lob.freetemporary(l_otf_blob);
  exception
    when others then
      test_result('OpenType font', false);
      dbms_output.put_line('  Error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Cleanup
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('--- Cleanup ---');

  -- Free test BLOB
  if dbms_lob.istemporary(l_test_font_blob) = 1 then
    dbms_lob.freetemporary(l_test_font_blob);
  end if;

  -- Clear font cache
  PL_FPDF.ClearTTFFontCache();

  -- Reset PDF engine
  PL_FPDF.Reset();

  -------------------------------------------------------------------------
  -- Summary
  -------------------------------------------------------------------------
  dbms_output.put_line('');
  dbms_output.put_line('=======================================================================');
  dbms_output.put_line('SUMMARY: ' || l_pass_count || '/' || l_test_count || ' tests passed');

  if l_test_passed then
    dbms_output.put_line('STATUS: ✓ ALL TESTS PASSED');
  else
    dbms_output.put_line('STATUS: ✗ SOME TESTS FAILED');
  end if;

  dbms_output.put_line('=======================================================================');

  if not l_test_passed then
    raise_application_error(-20999, 'Task 1.3 validation failed');
  end if;

END;
/

PROMPT
PROMPT Validation complete!
PROMPT
PROMPT NOTE: LoadTTFFromFile() requires:
PROMPT   1. Oracle directory object (CREATE DIRECTORY fonts_dir AS '/path/to/fonts')
PROMPT   2. Actual TTF files on server filesystem
PROMPT   3. Appropriate file system permissions
PROMPT
PROMPT To test LoadTTFFromFile manually:
PROMPT   BEGIN
PROMPT     PL_FPDF.LoadTTFFromFile('Arial', 'arial.ttf', 'FONTS_DIR', 'UTF-8');
PROMPT   END;
PROMPT   /
PROMPT
