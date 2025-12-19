CREATE OR REPLACE PACKAGE test_pl_fpdf_performance AS
/*******************************************************************************
* Package: test_pl_fpdf_performance
* Description: utPLSQL performance test suite for PL_FPDF
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-19
* Task: 3.4 - Unit Tests with utPLSQL
*******************************************************************************/

  --%suite(PL_FPDF Performance Tests)
  --%suitepath(pl_fpdf)

  --%test(Init performance < 100ms)
  --%tags(performance, smoke)
  PROCEDURE test_init_performance;

  --%test(100 page document < 5 seconds)
  --%tags(performance)
  PROCEDURE test_large_document;

  --%test(Init-Reset cycle performance)
  --%tags(performance)
  PROCEDURE test_init_reset_cycle;

  --%test(CLOB buffer performance)
  --%tags(performance)
  PROCEDURE test_clob_performance;

  --%test(OutputBlob performance)
  --%tags(performance)
  PROCEDURE test_output_performance;

END test_pl_fpdf_performance;
/
