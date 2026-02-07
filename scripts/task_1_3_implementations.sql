--------------------------------------------------------------------------------
-- TASK 1.3: TrueType/Unicode Font Support - Implementations
-- Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
-- Date: 2025-12-15
--
-- NOTE: This file contains the implementations to be inserted into PL_FPDF.pkb
-- after line 2970 (after "End of Task 1.2 helper implementations")
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TASK 1.3 IMPLEMENTATIONS
--------------------------------------------------------------------------------

/*******************************************************************************
* Function: parse_ttf_header (Internal)
* Description: Parses TTF/OTF header and extracts basic metrics
* Note: Simplified parser - full TTF parsing is extremely complex
*******************************************************************************/
function parse_ttf_header(p_font_blob blob, p_font_name varchar2) return recTTFFont is
  l_font recTTFFont;
  l_magic_number raw(4);
  l_version raw(4);
  l_valid_ttf boolean := false;

  -- TTF magic numbers
  c_ttf_magic constant raw(4) := hextoraw('00010000');  -- TrueType 1.0
  c_otf_magic constant raw(4) := hextoraw('4F54544F');  -- 'OTTO' OpenType/CFF
  c_ttc_magic constant raw(4) := hextoraw('74746366');  -- 'ttcf' TrueType Collection

begin
  -- Validate BLOB
  if p_font_blob is null or dbms_lob.getlength(p_font_blob) < 12 then
    raise_application_error(-20200,
      'Invalid font BLOB: NULL or too small (<12 bytes)');
  end if;

  -- Read magic number (first 4 bytes)
  l_magic_number := dbms_lob.substr(p_font_blob, 4, 1);

  -- Validate TTF/OTF signature
  if l_magic_number = c_ttf_magic then
    l_valid_ttf := true;
    log_message(4, 'Detected TrueType font (version 1.0)');
  elsif l_magic_number = c_otf_magic then
    l_valid_ttf := true;
    log_message(4, 'Detected OpenType font with CFF outlines');
  elsif l_magic_number = c_ttc_magic then
    raise_application_error(-20200,
      'TrueType Collections (.ttc) not yet supported');
  else
    raise_application_error(-20200,
      'Invalid TTF/OTF magic number: ' || rawtohex(l_magic_number));
  end if;

  -- Initialize font record with defaults
  l_font.font_name := upper(p_font_name);
  l_font.font_blob := p_font_blob;
  l_font.encoding := 'UTF-8';

  -- Set reasonable defaults (would be extracted from actual TTF tables in full implementation)
  l_font.units_per_em := 1000;  -- Standard for many fonts
  l_font.ascent := 800;          -- ~80% of em
  l_font.descent := -200;        -- ~20% below baseline
  l_font.line_gap := 0;
  l_font.cap_height := 700;
  l_font.x_height := 500;
  l_font.is_bold := false;
  l_font.is_italic := false;
  l_font.is_embedded := true;
  l_font.loaded_at := systimestamp;

  log_message(4, 'TTF header parsed for font: ' || p_font_name ||
    ', size: ' || dbms_lob.getlength(p_font_blob) || ' bytes');

  return l_font;

exception
  when others then
    log_message(1, 'Error parsing TTF header for ' || p_font_name || ': ' || sqlerrm);
    raise_application_error(-20202,
      'Error parsing TTF header: ' || sqlerrm);
end parse_ttf_header;


/*******************************************************************************
* Function: IsTTFFontLoaded
* Description: Checks if a TrueType font has been loaded
*******************************************************************************/
function IsTTFFontLoaded(p_font_name varchar2) return boolean is
  l_font_name_upper varchar2(100) := upper(p_font_name);
begin
  return g_ttf_fonts.exists(l_font_name_upper);
exception
  when others then
    log_message(1, 'Error in IsTTFFontLoaded: ' || sqlerrm);
    return false;
end IsTTFFontLoaded;


/*******************************************************************************
* Procedure: AddTTFFont
* Description: Adds a TrueType/OpenType font from BLOB
*******************************************************************************/
procedure AddTTFFont(
  p_font_name varchar2,
  p_font_blob blob,
  p_encoding varchar2 default 'UTF-8',
  p_embed boolean default true
) is
  l_font recTTFFont;
  l_font_name_upper varchar2(100);
begin
  -- Validate parameters
  if p_font_name is null or length(trim(p_font_name)) = 0 then
    raise_application_error(-20210,
      'Font name cannot be NULL or empty');
  end if;

  if p_font_blob is null then
    raise_application_error(-20211,
      'Font BLOB cannot be NULL');
  end if;

  l_font_name_upper := upper(trim(p_font_name));

  -- Check if font already loaded
  if IsTTFFontLoaded(l_font_name_upper) then
    log_message(2, 'WARNING: Font ' || l_font_name_upper ||
      ' already loaded. Replacing with new version.');
  end if;

  log_message(3, 'Loading TrueType font: ' || l_font_name_upper ||
    ', size: ' || dbms_lob.getlength(p_font_blob) || ' bytes');

  -- Parse TTF header
  l_font := parse_ttf_header(p_font_blob, l_font_name_upper);

  -- Override encoding if specified
  if p_encoding is not null then
    l_font.encoding := upper(p_encoding);
  end if;

  l_font.is_embedded := p_embed;

  -- Add to cache
  g_ttf_fonts(l_font_name_upper) := l_font;
  g_ttf_fonts_count := g_ttf_fonts.count;

  log_message(3, 'TrueType font loaded successfully: ' || l_font_name_upper ||
    ', encoding: ' || l_font.encoding ||
    ', embedded: ' || case when p_embed then 'YES' else 'NO' end);

exception
  when others then
    log_message(1, 'Error in AddTTFFont for ' || p_font_name || ': ' || sqlerrm);
    raise;
end AddTTFFont;


/*******************************************************************************
* Procedure: LoadTTFFromFile
* Description: Loads a TrueType font from server filesystem
*******************************************************************************/
procedure LoadTTFFromFile(
  p_font_name varchar2,
  p_file_path varchar2,
  p_directory varchar2 default 'FONTS_DIR',
  p_encoding varchar2 default 'UTF-8'
) is
  l_font_blob blob;
  l_file utl_file.file_type;
  l_buffer raw(32767);
  l_amount pls_integer := 32767;
  l_pos pls_integer := 1;
  l_file_exists boolean;
  l_file_length number;
  l_block_size number;
begin
  log_message(3, 'Loading TTF from file: ' || p_file_path ||
    ' in directory: ' || p_directory);

  -- Check if directory exists
  begin
    utl_file.fgetattr(p_directory, p_file_path, l_file_exists,
      l_file_length, l_block_size);

    if not l_file_exists then
      raise_application_error(-20204,
        'File not found: ' || p_file_path || ' in directory ' || p_directory);
    end if;

    log_message(4, 'File found: ' || p_file_path ||
      ', size: ' || l_file_length || ' bytes');

  exception
    when others then
      if sqlcode = -29280 then  -- Invalid directory
        raise_application_error(-20203,
          'Invalid or non-existent directory: ' || p_directory);
      elsif sqlcode = -29283 then  -- Invalid operation
        raise_application_error(-20205,
          'Permission denied accessing: ' || p_directory);
      else
        raise;
      end if;
  end;

  -- Create temporary BLOB
  dbms_lob.createtemporary(l_font_blob, true, dbms_lob.session);

  -- Open file for reading (binary mode)
  begin
    l_file := utl_file.fopen(p_directory, p_file_path, 'rb', 32767);

    -- Read file in chunks
    loop
      begin
        utl_file.get_raw(l_file, l_buffer, l_amount);
        dbms_lob.writeappend(l_font_blob, utl_raw.length(l_buffer), l_buffer);
      exception
        when no_data_found then
          exit;  -- End of file
      end;
    end loop;

    utl_file.fclose(l_file);

    log_message(4, 'File read successfully: ' ||
      dbms_lob.getlength(l_font_blob) || ' bytes');

  exception
    when others then
      if utl_file.is_open(l_file) then
        utl_file.fclose(l_file);
      end if;
      if dbms_lob.istemporary(l_font_blob) = 1 then
        dbms_lob.freetemporary(l_font_blob);
      end if;
      log_message(1, 'Error reading file: ' || sqlerrm);
      raise;
  end;

  -- Add font from BLOB
  AddTTFFont(p_font_name, l_font_blob, p_encoding, true);

  -- Note: BLOB is now stored in g_ttf_fonts cache, so it persists
  -- The temporary BLOB reference is copied into the cache

  log_message(3, 'TrueType font loaded from file: ' || p_file_path);

exception
  when others then
    log_message(1, 'Error in LoadTTFFromFile: ' || sqlerrm);
    raise;
end LoadTTFFromFile;


/*******************************************************************************
* Function: GetTTFFontInfo
* Description: Returns metadata about a loaded TrueType font
*******************************************************************************/
function GetTTFFontInfo(p_font_name varchar2) return recTTFFont is
  l_font_name_upper varchar2(100) := upper(trim(p_font_name));
begin
  if not g_ttf_fonts.exists(l_font_name_upper) then
    raise_application_error(-20206,
      'Font not found: ' || p_font_name ||
      '. Call AddTTFFont() or LoadTTFFromFile() first.');
  end if;

  return g_ttf_fonts(l_font_name_upper);

exception
  when others then
    log_message(1, 'Error in GetTTFFontInfo: ' || sqlerrm);
    raise;
end GetTTFFontInfo;


/*******************************************************************************
* Procedure: ClearTTFFontCache
* Description: Clears all loaded TrueType fonts from cache
*******************************************************************************/
procedure ClearTTFFontCache is
  l_font_name varchar2(100);
begin
  log_message(3, 'Clearing TTF font cache (' || g_ttf_fonts_count || ' fonts)');

  -- Free BLOBs if they are temporary
  l_font_name := g_ttf_fonts.first;
  while l_font_name is not null loop
    if dbms_lob.istemporary(g_ttf_fonts(l_font_name).font_blob) = 1 then
      dbms_lob.freetemporary(g_ttf_fonts(l_font_name).font_blob);
    end if;
    l_font_name := g_ttf_fonts.next(l_font_name);
  end loop;

  -- Clear collection
  g_ttf_fonts.delete;
  g_ttf_fonts_count := 0;

  log_message(3, 'TTF font cache cleared');

exception
  when others then
    log_message(1, 'Error in ClearTTFFontCache: ' || sqlerrm);
    raise;
end ClearTTFFontCache;

--------------------------------------------------------------------------------
-- End of Task 1.3 implementations
--------------------------------------------------------------------------------
