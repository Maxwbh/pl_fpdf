/*******************************************************************************
* Script: run_constants_tests_simple.sql
* Description: Regression tests for the duplicated version constants and for
*              document generation after the binary-path changes.
*              Does not require utPLSQL - uses basic PL/SQL.
*
* Usage:
*   PL/SQL Developer: open in a SQL Window and press F8.
*   SQL*Plus:         SET SERVEROUTPUT ON, then run the script.
*
*   The script itself contains no SQL*Plus commands, so it runs unchanged in
*   both. Anonymous blocks are separated by '/' on its own line.
*
* Note on coverage:
*   The image path is not covered here. In this version PL_FPDF.Image() fetches
*   through URIFactory - that is, HTTP - which needs a network ACL that a plain
*   schema does not have. A test that can never run is worse than a missing
*   one, because it counts as coverage, so no placeholder is left behind.
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2026-09-09
*******************************************************************************/


/*******************************************************************************
* 1. Version constants
*
* This block only compiles if the constants are public. That is the point:
* removing the duplication by commenting them out in the specification also
* makes the package compile, but turns them private, and every caller then
* fails with PLS-00302. The failure has to surface here, not in production.
*
* The values must come from the specification. co_fpdf_version is the version
* of the PHP FPDF class this is a port of - 1.53 - and it goes into the PDF
* /Producer string. Had the body's copy survived, it would read 2.0.0.
*******************************************************************************/
declare
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 1. Version constants');

  if PL_FPDF.co_fpdf_version = '1.53' then
    dbms_output.put_line('   [OK]   co_fpdf_version = 1.53 (the ported FPDF)');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] co_fpdf_version = '
                         || nvl(PL_FPDF.co_fpdf_version, '<null>')
                         || ', expected 1.53 - did the body copy survive?');
    l_fail := l_fail + 1;
  end if;

  if PL_FPDF.co_pl_fpdf_version = '2.0.0' then
    dbms_output.put_line('   [OK]   co_pl_fpdf_version = 2.0.0');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] co_pl_fpdf_version = '
                         || nvl(PL_FPDF.co_pl_fpdf_version, '<null>')
                         || ', expected 2.0.0');
    l_fail := l_fail + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
end;
/


/*******************************************************************************
* 2. Document generation, as a regression
*
* The binary-path changes touched p_putimages, which every document goes
* through. This checks that a document without images still comes out.
*
* Uses Init(), not the legacy fpdf() constructor: in this version fpdf() does
* not set the initialization flag, and the AddPage that follows raises
* ORA-20005.
*******************************************************************************/
declare
  l_pdf    blob;
  l_header varchar2(10);
  l_ok     pls_integer := 0;
  l_fail   pls_integer := 0;
begin
  dbms_output.put_line('== 2. Document generation');

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', 'B', 14);
  PL_FPDF.Cell(0, 10, 'Regression', 0, 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  if l_pdf is null or dbms_lob.getlength(l_pdf) = 0 then
    dbms_output.put_line('   [FAIL] OutputBlob returned an empty LOB');
    l_fail := l_fail + 1;
  else
    -- '%PDF' is ASCII, so the cast is safe in any character set.
    l_header := utl_raw.cast_to_varchar2(dbms_lob.substr(l_pdf, 4, 1));
    if l_header = '%PDF' then
      dbms_output.put_line('   [OK]   PDF generated, '
                           || dbms_lob.getlength(l_pdf) || ' bytes');
      l_ok := l_ok + 1;
    else
      dbms_output.put_line('   [FAIL] does not start with %PDF but with '
                           || l_header);
      l_fail := l_fail + 1;
    end if;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/


/*******************************************************************************
* 3. Image path, through ImageFromBlob
*
* The PNG below is a 2x2 indexed image with a 4-colour palette, built and
* verified with an independent reader. Indexed on purpose: the palette is the
* part the binary changes touched most.
*
* This goes through ImageFromBlob, not Image(), because Image() fetches over
* HTTP through URIFactory and that needs a network ACL. Nothing here reaches
* outside the schema.
*
* What is asserted:
*   - no ORA-29275 while walking the chunks;
*   - the stream carries /ASCIIHexDecode, which is how binary crosses the CLOB
*     the document is assembled in;
*   - /DecodeParms is an array. With /Filter as an array it must be, one entry
*     per filter. A bare dictionary applies /Predictor 15 to /ASCIIHexDecode
*     instead of /FlateDecode, and the image decodes misaligned: the file opens
*     without error and draws the colours in the wrong places.
*******************************************************************************/
declare
  l_hex  varchar2(4000);
  l_png  blob;
  l_pdf  blob;
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 3. Image through ImageFromBlob');

    l_hex := '89504E470D0A1A0A0000000D494844520000000200000002080300000045';
    l_hex := l_hex || '68FD160000000C504C5445FF000000FF000000FFFFFF00D6028F7B000000';
    l_hex := l_hex || '0E4944415478DA63606064606206000011000783CA64640000000049454E';
    l_hex := l_hex || '44AE426082';
  l_png := hextoraw(l_hex);

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.ImageFromBlob(l_png, 'TEST_PNG', 10, 10, 40);
  l_pdf := PL_FPDF.OutputBlob;

  if dbms_lob.instr(l_pdf, utl_raw.cast_to_raw('/ASCIIHexDecode')) > 0 then
    dbms_output.put_line('   [OK]   stream carries /ASCIIHexDecode');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] /ASCIIHexDecode missing - binary would not '
                         || 'survive the document CLOB');
    l_fail := l_fail + 1;
  end if;

  if dbms_lob.instr(l_pdf, utl_raw.cast_to_raw('/DecodeParms [')) > 0 then
    dbms_output.put_line('   [OK]   /DecodeParms is an array, matching /Filter');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] /DecodeParms is not an array - /Predictor '
                         || 'would land on the wrong filter');
    l_fail := l_fail + 1;
  end if;

  if dbms_lob.getlength(l_pdf) > 0 then
    dbms_output.put_line('   [OK]   PDF with image generated, '
                         || dbms_lob.getlength(l_pdf) || ' bytes');
    l_ok := l_ok + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    -- p_parseImage has a when others that rewraps everything as ORA-20100, so
    -- the cause only shows in the message text, never in SQLCODE.
    if instr(sqlerrm, 'ORA-29275') > 0 then
      dbms_output.put_line('   [FAIL] ORA-29275 - binary is still being read '
                           || 'through VARCHAR2');
    else
      dbms_output.put_line('   [FAIL] ' || sqlerrm);
    end if;
end;
/
