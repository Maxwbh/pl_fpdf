CREATE OR REPLACE PACKAGE BODY test_pl_fpdf_output AS

  PROCEDURE setup_test IS
  BEGIN
    PL_FPDF.Init();
  END setup_test;

  PROCEDURE teardown_test IS
  BEGIN
    PL_FPDF.Reset();
  END teardown_test;

  PROCEDURE test_output_blob IS
    l_blob BLOB;
  BEGIN
    PL_FPDF.AddPage();
    l_blob := PL_FPDF.OutputBlob();

    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(100);
  END test_output_blob;

  PROCEDURE test_pdf_signature IS
    l_blob BLOB;
    l_header RAW(10);
  BEGIN
    PL_FPDF.AddPage();
    l_blob := PL_FPDF.OutputBlob();

    -- Read first 4 bytes
    l_header := DBMS_LOB.SUBSTR(l_blob, 4, 1);

    -- PDF signature should be '%PDF'
    ut.expect(UTL_RAW.CAST_TO_VARCHAR2(l_header)).to_equal('%PDF');
  END test_pdf_signature;

  PROCEDURE test_multipage IS
    l_blob BLOB;
  BEGIN
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();

    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(500);
  END test_multipage;

  PROCEDURE test_pdf_with_text IS
    l_blob BLOB;
  BEGIN
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 12);
    PL_FPDF.Cell(0, 10, 'Test PDF Generation');
    PL_FPDF.Ln();
    PL_FPDF.Write(10, 'This is a test document');

    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(500);
  END test_pdf_with_text;

  PROCEDURE test_pdf_with_graphics IS
    l_blob BLOB;
  BEGIN
    PL_FPDF.AddPage();
    PL_FPDF.SetDrawColor(255, 0, 0);
    PL_FPDF.SetLineWidth(2);
    PL_FPDF.Line(10, 10, 100, 10);
    PL_FPDF.Rect(10, 20, 50, 30);

    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(300);
  END test_pdf_with_graphics;

  PROCEDURE test_json_config IS
    l_config JSON_OBJECT_T;
    l_blob BLOB;
  BEGIN
    l_config := JSON_OBJECT_T();
    l_config.put('title', 'Test Document');
    l_config.put('author', 'Maxwell Oliveira');
    l_config.put('subject', 'utPLSQL Testing');

    PL_FPDF.SetDocumentConfig(l_config);
    PL_FPDF.AddPage();

    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(100);
  END test_json_config;

  PROCEDURE test_metadata IS
    l_metadata JSON_OBJECT_T;
  BEGIN
    PL_FPDF.AddPage();
    PL_FPDF.AddPage();

    l_metadata := PL_FPDF.GetDocumentMetadata();

    ut.expect(l_metadata).to_be_not_null();
    ut.expect(l_metadata.get_Number('pageCount')).to_equal(2);
  END test_metadata;

END test_pl_fpdf_output;
/
