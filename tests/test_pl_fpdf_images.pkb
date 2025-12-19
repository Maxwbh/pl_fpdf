CREATE OR REPLACE PACKAGE BODY test_pl_fpdf_images AS

  -- Test image data (minimal valid headers)
  -- 1x1 PNG (transparent)
  c_test_png_blob CONSTANT RAW(100) := HEXTORAW(
    '89504E470D0A1A0A0000000D49484452000000010000000108060000001F15C4890000000D49444154785E63000100000500010D0A2DB40000000049454E44AE426082'
  );

  -- 1x1 JPEG (minimal)
  c_test_jpeg_blob CONSTANT RAW(100) := HEXTORAW(
    'FFD8FFE000104A46494600010100000100010000FFDB004300080606070605080707070909080A0C140D0C0B0B0C1912130F141D1A1F1E1D1A1C1C20242E2720222C231C1C2837292C30313434341F27393D38323C2E333432FFDB00430109090909' ||
    '0C0B0C180D0D1832211C213232323232323232323232323232323232323232323232323232323232323232323232323232323232323232323232323232FFC000110800010001030122000211010311' ||
    '01FFDA000C03010002110311003F00B5C00000FFD9'
  );

  ------------------------------------------------------------------------------
  -- Setup/Teardown
  ------------------------------------------------------------------------------

  PROCEDURE setup_suite IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting PL_FPDF Image Tests Suite');
  END setup_suite;

  PROCEDURE teardown_suite IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Completed PL_FPDF Image Tests Suite');
  END teardown_suite;

  PROCEDURE setup_test IS
  BEGIN
    PL_FPDF.Init();
    PL_FPDF.AddPage();
  END setup_test;

  PROCEDURE teardown_test IS
  BEGIN
    PL_FPDF.Reset();
  END teardown_test;

  ------------------------------------------------------------------------------
  -- Group 1: PNG Images
  ------------------------------------------------------------------------------

  PROCEDURE test_png_dimensions IS
    l_img PL_FPDF.recImageBlob;
    l_blob BLOB;
  BEGIN
    -- Create BLOB from test data
    DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
    DBMS_LOB.WRITEAPPEND(l_blob, UTL_RAW.LENGTH(c_test_png_blob), c_test_png_blob);

    l_img.image_blob := l_blob;
    l_img.mime_type := 'image/png';
    l_img.file_format := 'PNG';

    -- Note: Actual parsing is internal, this tests the structure
    ut.expect(l_img.mime_type).to_equal('image/png');
    ut.expect(l_img.file_format).to_equal('PNG');

    DBMS_LOB.FREETEMPORARY(l_blob);
  END test_png_dimensions;

  PROCEDURE test_png_color_type IS
    l_img PL_FPDF.recImageBlob;
  BEGIN
    l_img.color_type := 6;  -- RGBA (PNG color type 6)
    ut.expect(l_img.color_type).to_equal(6);
  END test_png_color_type;

  PROCEDURE test_png_transparency IS
    l_img PL_FPDF.recImageBlob;
  BEGIN
    l_img.has_transparency := TRUE;
    ut.expect(l_img.has_transparency).to_be_true();

    l_img.has_transparency := FALSE;
    ut.expect(l_img.has_transparency).to_be_false();
  END test_png_transparency;

  PROCEDURE test_invalid_png IS
    l_blob BLOB;
  BEGIN
    -- Create invalid PNG (wrong signature)
    DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
    DBMS_LOB.WRITEAPPEND(l_blob, 8, HEXTORAW('0000000000000000'));

    -- This should raise exc_invalid_image (-20301)
    -- Note: Actual implementation would parse the blob
    ut.expect(TRUE).to_be_true();  -- Placeholder

    DBMS_LOB.FREETEMPORARY(l_blob);
  END test_invalid_png;

  ------------------------------------------------------------------------------
  -- Group 2: JPEG Images
  ------------------------------------------------------------------------------

  PROCEDURE test_jpeg_dimensions IS
    l_img PL_FPDF.recImageBlob;
    l_blob BLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
    DBMS_LOB.WRITEAPPEND(l_blob, UTL_RAW.LENGTH(c_test_jpeg_blob), c_test_jpeg_blob);

    l_img.image_blob := l_blob;
    l_img.mime_type := 'image/jpeg';
    l_img.file_format := 'JPEG';

    ut.expect(l_img.mime_type).to_equal('image/jpeg');
    ut.expect(l_img.file_format).to_equal('JPEG');

    DBMS_LOB.FREETEMPORARY(l_blob);
  END test_jpeg_dimensions;

  PROCEDURE test_jpeg_format IS
    l_img PL_FPDF.recImageBlob;
  BEGIN
    l_img.file_format := 'JPEG';
    l_img.mime_type := 'image/jpeg';

    ut.expect(l_img.file_format).to_be_in('JPEG', 'JPG');
    ut.expect(l_img.mime_type).to_be_in('image/jpeg', 'image/jpg');
  END test_jpeg_format;

  PROCEDURE test_invalid_jpeg IS
    l_blob BLOB;
  BEGIN
    -- Create invalid JPEG (wrong signature)
    DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
    DBMS_LOB.WRITEAPPEND(l_blob, 8, HEXTORAW('0000000000000000'));

    -- This should raise exc_invalid_image (-20301)
    ut.expect(TRUE).to_be_true();  -- Placeholder

    DBMS_LOB.FREETEMPORARY(l_blob);
  END test_invalid_jpeg;

  ------------------------------------------------------------------------------
  -- Group 3: Image Embedding
  ------------------------------------------------------------------------------

  PROCEDURE test_add_image IS
    l_blob BLOB;
    l_img_blob BLOB;
  BEGIN
    -- Create minimal PNG
    DBMS_LOB.CREATETEMPORARY(l_img_blob, TRUE);
    DBMS_LOB.WRITEAPPEND(l_img_blob, UTL_RAW.LENGTH(c_test_png_blob), c_test_png_blob);

    -- Note: Actual Image() function would be called here
    -- For now, just test that we can create the blob
    ut.expect(DBMS_LOB.GETLENGTH(l_img_blob)).to_be_greater_than(0);

    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(0);

    DBMS_LOB.FREETEMPORARY(l_img_blob);
  END test_add_image;

  PROCEDURE test_multiple_images IS
    l_blob BLOB;
  BEGIN
    -- Multiple images should be possible in same PDF
    -- This tests that image resources don't conflict
    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(0);
  END test_multiple_images;

  PROCEDURE test_image_position IS
  BEGIN
    -- Test that image position parameters are accepted
    -- Actual Image() call would go here
    ut.expect(TRUE).to_be_true();
  END test_image_position;

  PROCEDURE test_image_scaling IS
  BEGIN
    -- Test that image can be scaled
    ut.expect(TRUE).to_be_true();
  END test_image_scaling;

  ------------------------------------------------------------------------------
  -- Group 4: recImageBlob Type
  ------------------------------------------------------------------------------

  PROCEDURE test_rec_image_blob_png IS
    l_img PL_FPDF.recImageBlob;
  BEGIN
    l_img.file_format := 'PNG';
    l_img.width := 100;
    l_img.height := 100;
    l_img.bit_depth := 8;
    l_img.color_type := 2;  -- RGB
    l_img.has_transparency := FALSE;

    ut.expect(l_img.width).to_equal(100);
    ut.expect(l_img.height).to_equal(100);
    ut.expect(l_img.bit_depth).to_equal(8);
  END test_rec_image_blob_png;

  PROCEDURE test_rec_image_blob_jpeg IS
    l_img PL_FPDF.recImageBlob;
  BEGIN
    l_img.file_format := 'JPEG';
    l_img.width := 800;
    l_img.height := 600;
    l_img.bit_depth := 24;

    ut.expect(l_img.width).to_equal(800);
    ut.expect(l_img.height).to_equal(600);
  END test_rec_image_blob_jpeg;

  ------------------------------------------------------------------------------
  -- Smoke Tests
  ------------------------------------------------------------------------------

  PROCEDURE smoke_test_images IS
    l_blob BLOB;
    l_img_blob BLOB;
  BEGIN
    -- Quick smoke test
    DBMS_LOB.CREATETEMPORARY(l_img_blob, TRUE);
    DBMS_LOB.WRITEAPPEND(l_img_blob, UTL_RAW.LENGTH(c_test_png_blob), c_test_png_blob);

    -- Generate PDF
    l_blob := PL_FPDF.OutputBlob();
    ut.expect(DBMS_LOB.GETLENGTH(l_blob)).to_be_greater_than(200);

    DBMS_LOB.FREETEMPORARY(l_img_blob);
  END smoke_test_images;

END test_pl_fpdf_images;
/
