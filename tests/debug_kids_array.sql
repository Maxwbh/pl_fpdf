/*******************************************************************************
* Debug Script: Kids Array Parsing Issue
* Purpose: Identify why /Kids array is not being found in Pages object
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

DECLARE
  l_pdf BLOB;
  l_pdf_text VARCHAR2(32767);
  l_pages_obj VARCHAR2(4000);
  l_kids_result VARCHAR2(500);
  l_instr_result PLS_INTEGER;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Kids Array Debug ===');
  DBMS_OUTPUT.PUT_LINE('');

  -- Step 1: Generate a simple PDF
  DBMS_OUTPUT.PUT_LINE('Step 1: Generating PDF...');
  PL_FPDF.Init('P', 'mm', 'Letter');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Cell(0, 10, 'Test Page');
  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();

  DBMS_OUTPUT.PUT_LINE('  PDF size: ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');

  -- Step 2: Read PDF as text (last 2000 bytes where xref and trailer are)
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Step 2: Reading PDF tail (last 2000 bytes)...');

  DECLARE
    l_len PLS_INTEGER := DBMS_LOB.GETLENGTH(l_pdf);
    l_start PLS_INTEGER := GREATEST(1, l_len - 1999);
    l_amount PLS_INTEGER := LEAST(2000, l_len);
    l_raw RAW(32767);
  BEGIN
    DBMS_LOB.READ(l_pdf, l_amount, l_start, l_raw);
    l_pdf_text := UTL_RAW.CAST_TO_VARCHAR2(l_raw);

    -- Show xref and trailer
    DBMS_OUTPUT.PUT_LINE('  PDF tail (from byte ' || l_start || '):');
    DBMS_OUTPUT.PUT_LINE('  ---');
    -- Print last 500 chars which should have xref and trailer
    DBMS_OUTPUT.PUT_LINE(SUBSTR(l_pdf_text, GREATEST(1, LENGTH(l_pdf_text) - 500)));
    DBMS_OUTPUT.PUT_LINE('  ---');
  END;

  -- Step 3: Read beginning of PDF (first 1500 bytes where object 1 should be)
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Step 3: Reading PDF head (first 1500 bytes)...');

  DECLARE
    l_amount PLS_INTEGER := LEAST(1500, DBMS_LOB.GETLENGTH(l_pdf));
    l_raw RAW(32767);
  BEGIN
    DBMS_LOB.READ(l_pdf, l_amount, 1, l_raw);
    l_pdf_text := UTL_RAW.CAST_TO_VARCHAR2(l_raw);

    DBMS_OUTPUT.PUT_LINE('  PDF head:');
    DBMS_OUTPUT.PUT_LINE('  ---');
    DBMS_OUTPUT.PUT_LINE(l_pdf_text);
    DBMS_OUTPUT.PUT_LINE('  ---');

    -- Find /Kids in the text
    l_instr_result := INSTR(l_pdf_text, '/Kids');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 4: Searching for /Kids...');
    DBMS_OUTPUT.PUT_LINE('  INSTR result for /Kids: ' || l_instr_result);

    IF l_instr_result > 0 THEN
      -- Extract 50 chars around /Kids
      l_pages_obj := SUBSTR(l_pdf_text, GREATEST(1, l_instr_result - 20), 70);
      DBMS_OUTPUT.PUT_LINE('  Context around /Kids: ' || l_pages_obj);

      -- Try regex
      l_kids_result := REGEXP_SUBSTR(l_pdf_text, '/Kids\s*\[([^\]]+)\]', 1, 1, NULL, 1);
      DBMS_OUTPUT.PUT_LINE('  REGEXP_SUBSTR result: ' || NVL(l_kids_result, 'NULL'));
    ELSE
      DBMS_OUTPUT.PUT_LINE('  /Kids NOT FOUND in PDF head!');

      -- Try to find it anywhere
      l_instr_result := INSTR(l_pdf_text, 'Kids');
      DBMS_OUTPUT.PUT_LINE('  INSTR for "Kids" (without slash): ' || l_instr_result);
    END IF;
  END;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Debug Complete ===');

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/
