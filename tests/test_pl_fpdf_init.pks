/*******************************************************************************
* Package: test_pl_fpdf_init
* Description: utPLSQL test suite for PL_FPDF initialization (Task 1.1)
*              Tests all aspects of Init(), Reset(), and IsInitialized()
*
* Test Coverage:
*   - Initialization with default parameters
*   - Initialization with custom parameters
*   - Parameter validation (orientation, unit, format, encoding)
*   - UTF-8 configuration
*   - CLOB creation
*   - Re-initialization
*   - Reset functionality
*   - State management
*
* Framework: utPLSQL v3+
* Oracle Version: 19c+
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2025-12-15
*
* Usage:
*   exec ut.run('test_pl_fpdf_init');
*******************************************************************************/

CREATE OR REPLACE PACKAGE test_pl_fpdf_init AS

  --%suite(PL_FPDF Initialization Tests)
  --%suitepath(pl_fpdf.init)

  --%beforeall
  PROCEDURE setup_test_suite;

  --%afterall
  PROCEDURE teardown_test_suite;

  --%beforeeach
  PROCEDURE setup_test;

  --%aftereach
  PROCEDURE teardown_test;


  -- =========================================================================
  -- TEST GROUP 1: Basic Initialization
  -- =========================================================================

  --%test(Should initialize with default parameters)
  --%tags(init, basic, smoke)
  PROCEDURE test_init_default_params;

  --%test(Should initialize with portrait orientation)
  --%tags(init, basic)
  PROCEDURE test_init_portrait;

  --%test(Should initialize with landscape orientation)
  --%tags(init, basic)
  PROCEDURE test_init_landscape;

  --%test(Should initialize with different units)
  --%tags(init, basic)
  PROCEDURE test_init_different_units;

  --%test(Should initialize with different formats)
  --%tags(init, basic)
  PROCEDURE test_init_different_formats;

  --%test(Should initialize with UTF-8 encoding)
  --%tags(init, encoding, utf8)
  PROCEDURE test_init_utf8_encoding;


  -- =========================================================================
  -- TEST GROUP 2: Parameter Validation
  -- =========================================================================

  --%test(Should reject invalid orientation)
  --%throws(-20001)
  --%tags(init, validation, negative)
  PROCEDURE test_init_invalid_orientation;

  --%test(Should reject invalid unit)
  --%throws(-20002)
  --%tags(init, validation, negative)
  PROCEDURE test_init_invalid_unit;

  --%test(Should reject invalid encoding)
  --%throws(-20003)
  --%tags(init, validation, negative)
  PROCEDURE test_init_invalid_encoding;

  --%test(Should reject null orientation if required)
  --%tags(init, validation)
  PROCEDURE test_init_null_params;


  -- =========================================================================
  -- TEST GROUP 3: State Management
  -- =========================================================================

  --%test(Should report not initialized before Init)
  --%tags(init, state)
  PROCEDURE test_not_initialized_initially;

  --%test(Should report initialized after Init)
  --%tags(init, state)
  PROCEDURE test_is_initialized_after_init;

  --%test(Should report not initialized after Reset)
  --%tags(init, state, reset)
  PROCEDURE test_not_initialized_after_reset;


  -- =========================================================================
  -- TEST GROUP 4: Re-initialization
  -- =========================================================================

  --%test(Should allow re-initialization)
  --%tags(init, reinit)
  PROCEDURE test_reinit_allowed;

  --%test(Should free resources on re-init)
  --%tags(init, reinit, resources)
  PROCEDURE test_reinit_frees_resources;

  --%test(Should change parameters on re-init)
  --%tags(init, reinit)
  PROCEDURE test_reinit_changes_params;


  -- =========================================================================
  -- TEST GROUP 5: Reset Functionality
  -- =========================================================================

  --%test(Should reset all state variables)
  --%tags(reset, cleanup)
  PROCEDURE test_reset_clears_state;

  --%test(Should free temporary CLOBs)
  --%tags(reset, cleanup, clob)
  PROCEDURE test_reset_frees_clobs;

  --%test(Should allow init after reset)
  --%tags(reset, init)
  PROCEDURE test_init_after_reset;


  -- =========================================================================
  -- TEST GROUP 6: CLOB Management
  -- =========================================================================

  --%test(Should create temporary CLOBs)
  --%tags(init, clob)
  PROCEDURE test_init_creates_clobs;

  --%test(Should create session-scoped CLOBs)
  --%tags(init, clob, scope)
  PROCEDURE test_clobs_are_temporary;


  -- =========================================================================
  -- TEST GROUP 7: Configuration Verification
  -- =========================================================================

  --%test(Should set correct scale factor for mm)
  --%tags(init, config, scale)
  PROCEDURE test_scale_factor_mm;

  --%test(Should set correct scale factor for cm)
  --%tags(init, config, scale)
  PROCEDURE test_scale_factor_cm;

  --%test(Should set correct scale factor for in)
  --%tags(init, config, scale)
  PROCEDURE test_scale_factor_in;

  --%test(Should set correct scale factor for pt)
  --%tags(init, config, scale)
  PROCEDURE test_scale_factor_pt;

  --%test(Should set default margins)
  --%tags(init, config, margins)
  PROCEDURE test_default_margins;

  --%test(Should set default font)
  --%tags(init, config, font)
  PROCEDURE test_default_font;

  --%test(Should set default colors)
  --%tags(init, config, colors)
  PROCEDURE test_default_colors;


  -- =========================================================================
  -- TEST GROUP 8: Edge Cases
  -- =========================================================================

  --%test(Should handle multiple resets)
  --%tags(reset, edge)
  PROCEDURE test_multiple_resets;

  --%test(Should handle init-reset-init cycle)
  --%tags(init, reset, edge)
  PROCEDURE test_init_reset_init_cycle;

  --%test(Should handle case-insensitive orientation)
  --%tags(init, edge, case)
  PROCEDURE test_case_insensitive_orientation;

  --%test(Should handle case-insensitive unit)
  --%tags(init, edge, case)
  PROCEDURE test_case_insensitive_unit;


  -- =========================================================================
  -- TEST GROUP 9: Metadata Initialization
  -- =========================================================================

  --%test(Should initialize metadata structure)
  --%tags(init, metadata)
  PROCEDURE test_init_metadata;

  --%test(Should set creator in metadata)
  --%tags(init, metadata)
  PROCEDURE test_metadata_creator;

  --%test(Should set creation date in metadata)
  --%tags(init, metadata)
  PROCEDURE test_metadata_creation_date;


  -- =========================================================================
  -- TEST GROUP 10: Performance Tests
  -- =========================================================================

  --%test(Should initialize quickly)
  --%tags(init, performance)
  PROCEDURE test_init_performance;

  --%test(Should handle rapid init-reset cycles)
  --%tags(init, reset, performance)
  PROCEDURE test_rapid_init_reset_cycles;

END test_pl_fpdf_init;
/
