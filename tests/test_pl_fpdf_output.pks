CREATE OR REPLACE PACKAGE test_pl_fpdf_output AS
/*******************************************************************************
* Package: test_pl_fpdf_output
* Description: utPLSQL test suite for PL_FPDF PDF generation and output
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-19
* Task: 3.4 - Unit Tests with utPLSQL
*******************************************************************************/

  --%suite(PL_FPDF Output and PDF Generation Tests)
  --%suitepath(pl_fpdf)

  --%beforeeach
  PROCEDURE setup_test;

  --%aftereach
  PROCEDURE teardown_test;

  --%test(OutputBlob generates valid PDF)
  --%tags(output, smoke)
  PROCEDURE test_output_blob;

  --%test(PDF has correct header signature)
  --%tags(output)
  PROCEDURE test_pdf_signature;

  --%test(Multi-page PDF generation)
  --%tags(output)
  PROCEDURE test_multipage;

  --%test(PDF with text content)
  --%tags(output, smoke)
  PROCEDURE test_pdf_with_text;

  --%test(PDF with graphics)
  --%tags(output)
  PROCEDURE test_pdf_with_graphics;

  --%test(JSON document configuration)
  --%tags(output, json)
  PROCEDURE test_json_config;

  --%test(Document metadata)
  --%tags(output, metadata)
  PROCEDURE test_metadata;

END test_pl_fpdf_output;
/
