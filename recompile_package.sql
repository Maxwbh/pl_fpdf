--------------------------------------------------------------------------------
-- Recompile PL_FPDF Package
-- Run this script whenever you modify the package files
--------------------------------------------------------------------------------

PROMPT Compiling PL_FPDF Package Specification...
@@PL_FPDF.pks

SHOW ERRORS PACKAGE PL_FPDF;

PROMPT
PROMPT Compiling PL_FPDF Package Body...
@@PL_FPDF.pkb

SHOW ERRORS PACKAGE BODY PL_FPDF;

PROMPT
PROMPT Checking for invalid objects...
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PL_FPDF';

PROMPT
PROMPT Done! If status is VALID, you can run the validation tests.
PROMPT If status is INVALID, check the errors above.
