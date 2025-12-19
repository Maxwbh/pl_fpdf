CREATE OR REPLACE PACKAGE test_pl_fpdf_images AS
/*******************************************************************************
* Package: test_pl_fpdf_images
* Description: utPLSQL test suite for PL_FPDF image handling
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-19
* Task: 3.4 - Unit Tests with utPLSQL
*
* Test Coverage:
*   - PNG image parsing (Task 1.6)
*   - JPEG image parsing (Task 1.6)
*   - Image dimension extraction
*   - Image embedding in PDF
*   - Native BLOB-based image handling
*
* Groups:
*   - png: PNG format tests
*   - jpeg: JPEG format tests
*   - parsing: Image header parsing
*   - embedding: Image embedding in PDF
*   - smoke: Quick smoke tests
*******************************************************************************/

  --%suite(PL_FPDF Image Handling Tests)
  --%suitepath(pl_fpdf)

  --%beforeall
  PROCEDURE setup_suite;

  --%afterall
  PROCEDURE teardown_suite;

  --%beforeeach
  PROCEDURE setup_test;

  --%aftereach
  PROCEDURE teardown_test;

  ------------------------------------------------------------------------------
  -- Group 1: PNG Images
  ------------------------------------------------------------------------------
  --%test(PNG parsing extracts dimensions)
  --%tags(png, parsing, smoke)
  PROCEDURE test_png_dimensions;

  --%test(PNG parsing detects color type)
  --%tags(png, parsing)
  PROCEDURE test_png_color_type;

  --%test(PNG parsing detects transparency)
  --%tags(png, parsing)
  PROCEDURE test_png_transparency;

  --%test(Invalid PNG blob rejected)
  --%tags(png)
  --%throws(-20301)
  PROCEDURE test_invalid_png;

  ------------------------------------------------------------------------------
  -- Group 2: JPEG Images
  ------------------------------------------------------------------------------
  --%test(JPEG parsing extracts dimensions)
  --%tags(jpeg, parsing, smoke)
  PROCEDURE test_jpeg_dimensions;

  --%test(JPEG parsing detects format)
  --%tags(jpeg, parsing)
  PROCEDURE test_jpeg_format;

  --%test(Invalid JPEG blob rejected)
  --%tags(jpeg)
  --%throws(-20301)
  PROCEDURE test_invalid_jpeg;

  ------------------------------------------------------------------------------
  -- Group 3: Image Embedding
  ------------------------------------------------------------------------------
  --%test(Image can be added to PDF)
  --%tags(embedding, smoke)
  PROCEDURE test_add_image;

  --%test(Multiple images in same PDF)
  --%tags(embedding)
  PROCEDURE test_multiple_images;

  --%test(Image positioning works correctly)
  --%tags(embedding)
  PROCEDURE test_image_position;

  --%test(Image scaling works correctly)
  --%tags(embedding)
  PROCEDURE test_image_scaling;

  ------------------------------------------------------------------------------
  -- Group 4: recImageBlob Type
  ------------------------------------------------------------------------------
  --%test(recImageBlob stores PNG metadata)
  --%tags(parsing)
  PROCEDURE test_rec_image_blob_png;

  --%test(recImageBlob stores JPEG metadata)
  --%tags(parsing)
  PROCEDURE test_rec_image_blob_jpeg;

  ------------------------------------------------------------------------------
  -- Smoke Tests
  ------------------------------------------------------------------------------
  --%test(Quick smoke test - basic image operations)
  --%tags(smoke)
  PROCEDURE smoke_test_images;

END test_pl_fpdf_images;
/
