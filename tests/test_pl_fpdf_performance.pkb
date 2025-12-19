CREATE OR REPLACE PACKAGE BODY test_pl_fpdf_performance AS

  PROCEDURE test_init_performance IS
    l_start TIMESTAMP;
    l_end TIMESTAMP;
    l_duration NUMBER;
  BEGIN
    l_start := SYSTIMESTAMP;

    PL_FPDF.Init();

    l_end := SYSTIMESTAMP;
    l_duration := EXTRACT(SECOND FROM (l_end - l_start)) * 1000; -- milliseconds

    PL_FPDF.Reset();

    -- Init should complete in < 100ms
    ut.expect(l_duration).to_be_less_than(100);
  END test_init_performance;

  PROCEDURE test_large_document IS
    l_start TIMESTAMP;
    l_end TIMESTAMP;
    l_duration NUMBER;
    l_blob BLOB;
  BEGIN
    l_start := SYSTIMESTAMP;

    PL_FPDF.Init();
    PL_FPDF.SetFont('Arial', '', 12);

    -- Create 100-page document
    FOR i IN 1..100 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Page ' || i || ' of 100');
    END LOOP;

    l_blob := PL_FPDF.OutputBlob();

    l_end := SYSTIMESTAMP;
    l_duration := EXTRACT(SECOND FROM (l_end - l_start));

    PL_FPDF.Reset();

    -- 100 pages should complete in < 5 seconds
    ut.expect(l_duration).to_be_less_than(5);
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(5000);
  END test_large_document;

  PROCEDURE test_init_reset_cycle IS
    l_start TIMESTAMP;
    l_end TIMESTAMP;
    l_duration NUMBER;
  BEGIN
    l_start := SYSTIMESTAMP;

    -- 100 init-reset cycles
    FOR i IN 1..100 LOOP
      PL_FPDF.Init();
      PL_FPDF.AddPage();
      PL_FPDF.Reset();
    END LOOP;

    l_end := SYSTIMESTAMP;
    l_duration := EXTRACT(SECOND FROM (l_end - l_start));

    -- 100 cycles should complete in < 10 seconds
    ut.expect(l_duration).to_be_less_than(10);
  END test_init_reset_cycle;

  PROCEDURE test_clob_performance IS
    l_start TIMESTAMP;
    l_end TIMESTAMP;
    l_duration NUMBER;
  BEGIN
    l_start := SYSTIMESTAMP;

    PL_FPDF.Init();
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);

    -- Write lots of text (tests CLOB buffer WRITEAPPEND)
    FOR i IN 1..1000 LOOP
      PL_FPDF.Cell(0, 5, 'Line ' || i || ': Testing CLOB buffer performance');
      PL_FPDF.Ln();
    END LOOP;

    l_end := SYSTIMESTAMP;
    l_duration := EXTRACT(SECOND FROM (l_end - l_start));

    PL_FPDF.Reset();

    -- 1000 lines should complete in < 3 seconds
    ut.expect(l_duration).to_be_less_than(3);
  END test_clob_performance;

  PROCEDURE test_output_performance IS
    l_start TIMESTAMP;
    l_end TIMESTAMP;
    l_duration NUMBER;
    l_blob BLOB;
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.SetFont('Arial', '', 12);

    -- Create 50-page document
    FOR i IN 1..50 LOOP
      PL_FPDF.AddPage();
      PL_FPDF.Cell(0, 10, 'Performance test page ' || i);
    END LOOP;

    l_start := SYSTIMESTAMP;
    l_blob := PL_FPDF.OutputBlob();
    l_end := SYSTIMESTAMP;

    l_duration := EXTRACT(SECOND FROM (l_end - l_start)) * 1000; -- milliseconds

    PL_FPDF.Reset();

    -- OutputBlob should complete in < 500ms for 50 pages
    ut.expect(l_duration).to_be_less_than(500);
  END test_output_performance;

END test_pl_fpdf_performance;
/
