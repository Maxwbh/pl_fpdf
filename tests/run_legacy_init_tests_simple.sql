/*******************************************************************************
* Script: run_legacy_init_tests_simple.sql
* Description: Regression tests for the legacy fpdf() constructor, which must
*              leave the package usable on its own.
*              Does not require utPLSQL - uses basic PL/SQL.
*
* Usage:
*   PL/SQL Developer: open in a SQL Window and press F8.
*   SQL*Plus:         SET SERVEROUTPUT ON, then run the script.
*
*   The script contains no SQL*Plus commands, so it runs unchanged in both.
*   Anonymous blocks are separated by '/' on its own line.
*
* Why every block sets the package state before testing it:
*   Package state is per session and persists. Once anything has called Init(),
*   the initialization flag stays set for the rest of the session and the
*   defect stops reproducing. Blocks 1, 2 and 4 clear it with Reset() first, so
*   they start from the same state whether or not the session has been used
*   before. Block 3 does the opposite on purpose: it initializes first, because
*   what it checks is that Reset() clears the flag.
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2026-09-09
*******************************************************************************/


/*******************************************************************************
* 1. The legacy constructor leaves the package usable
*
* fpdf() is declared in the specification under "Legacy compatibility
* (maintained for backward compatibility)". Code written before Init() existed
* calls it directly, and so does this package's own helloworld.
*
* Without the fix, fpdf() builds the document but does not set the
* initialization flag, and the AddPage that follows raises ORA-20005 telling
* the caller to initialize something that is already initialized.
*******************************************************************************/
declare
  l_pdf  blob;
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 1. Legacy fpdf() constructor');

  PL_FPDF.Reset;
  PL_FPDF.fpdf('P', 'cm', 'A4');

  if PL_FPDF.IsInitialized then
    dbms_output.put_line('   [OK]   fpdf() leaves the package initialized');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] fpdf() did not set the initialization flag');
    l_fail := l_fail + 1;
  end if;

  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 1.2, 'Legacy', 0, 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  if l_pdf is not null and dbms_lob.getlength(l_pdf) > 0 then
    dbms_output.put_line('   [OK]   document built through fpdf(), '
                         || dbms_lob.getlength(l_pdf) || ' bytes');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] OutputBlob returned an empty LOB');
    l_fail := l_fail + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    if instr(sqlerrm, 'ORA-20005') > 0 then
      dbms_output.put_line('   [FAIL] ORA-20005 after fpdf() - the legacy '
                           || 'constructor still does not initialize');
    else
      dbms_output.put_line('   [FAIL] ' || sqlerrm);
    end if;
end;
/


/*******************************************************************************
* 2. Init() still works, and stays idempotent with the constructor
*
* Init() calls fpdf() internally. Now that fpdf() also sets the flag, that path
* sets it twice; this checks the result is the same and nothing regressed.
*******************************************************************************/
declare
  l_pdf  blob;
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 2. Init()');

  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');

  if PL_FPDF.IsInitialized then
    dbms_output.put_line('   [OK]   Init() leaves the package initialized');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] Init() did not set the initialization flag');
    l_fail := l_fail + 1;
  end if;

  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', 'B', 14);
  PL_FPDF.Cell(0, 10, 'Init', 0, 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  if l_pdf is not null and dbms_lob.getlength(l_pdf) > 0 then
    dbms_output.put_line('   [OK]   document built through Init(), '
                         || dbms_lob.getlength(l_pdf) || ' bytes');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] OutputBlob returned an empty LOB');
    l_fail := l_fail + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/


/*******************************************************************************
* 3. Reset() still clears the state
*
* The guard only means anything if Reset() puts the package back. This also
* protects the two blocks above, which rely on Reset() for a clean start.
*******************************************************************************/
declare
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 3. Reset()');

  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.Reset;

  if PL_FPDF.IsInitialized then
    dbms_output.put_line('   [FAIL] Reset() left the package initialized');
    l_fail := l_fail + 1;
  else
    dbms_output.put_line('   [OK]   Reset() cleared the initialization flag');
    l_ok := l_ok + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/


/*******************************************************************************
* 4. The reported scenario, call for call
*
* The sequence below is the one in helloworld, the sample procedure this
* package ships, reproduced call for call with a single substitution:
* OutputBlob() in place of Output(), because Output() writes through the
* PDF_DIR directory object and a plain schema does not necessarily have one.
* The substitution changes nothing about what is being tested, since the
* failure happens earlier, at AddPage.
*
* Without the fix, AddPage raises
*   ORA-20005: PL_FPDF not initialized. Call Init() first.
*
* This is not a hypothetical caller. MIGRATION_GUIDE.md lists fpdf() under
* "Deprecated Features (Still Supported)", with the move to Init() marked
* "Recommended", and names "Missing Init() or fpdf() call" as the cause of
* that very error - so the documentation states that fpdf() alone is enough.
* Code that still calls it is following what it was told.
*******************************************************************************/
declare
  l_pdf  blob;
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 4. helloworld sequence');

  PL_FPDF.Reset;

  PL_FPDF.fpdf('P', 'cm', 'A4');
  PL_FPDF.openpdf;
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 1.2, 'Hello World', 0, 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  if l_pdf is not null and dbms_lob.getlength(l_pdf) > 0 then
    dbms_output.put_line('   [OK]   the helloworld sequence completes, '
                         || dbms_lob.getlength(l_pdf) || ' bytes');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] sequence completed but produced no document');
    l_fail := l_fail + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    if instr(sqlerrm, 'ORA-20005') > 0 then
      dbms_output.put_line('   [FAIL] ORA-20005 - this is the reported defect, '
                           || 'still present');
    else
      dbms_output.put_line('   [FAIL] ' || sqlerrm);
    end if;
end;
/
