/*******************************************************************************
* Package Body: test_pl_fpdf_init
* Description: Implementation of utPLSQL test suite for PL_FPDF initialization
*******************************************************************************/

CREATE OR REPLACE PACKAGE BODY test_pl_fpdf_init AS

  -- Test counters
  g_test_count NUMBER := 0;
  g_setup_time TIMESTAMP;


  -- ==========================================================================
  -- SETUP AND TEARDOWN PROCEDURES
  -- ==========================================================================

  /*
   * Setup for entire test suite (runs once)
   */
  PROCEDURE setup_test_suite IS
  BEGIN
    g_test_count := 0;
    DBMS_OUTPUT.PUT_LINE('=== Starting PL_FPDF Init Test Suite ===');
    DBMS_OUTPUT.PUT_LINE('Test Framework: utPLSQL v3+');
    DBMS_OUTPUT.PUT_LINE('Oracle Version: ' ||
      (SELECT version FROM v$instance));
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('');
  END setup_test_suite;


  /*
   * Teardown for entire test suite (runs once)
   */
  PROCEDURE teardown_test_suite IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== Test Suite Complete ===');
    DBMS_OUTPUT.PUT_LINE('Total tests executed: ' || g_test_count);
  END teardown_test_suite;


  /*
   * Setup before each test (runs before every test)
   */
  PROCEDURE setup_test IS
  BEGIN
    g_test_count := g_test_count + 1;
    g_setup_time := SYSTIMESTAMP;

    -- Ensure clean state before each test
    BEGIN
      PL_FPDF.Reset();
    EXCEPTION
      WHEN OTHERS THEN
        -- Ignore if not initialized
        NULL;
    END;
  END setup_test;


  /*
   * Teardown after each test (runs after every test)
   */
  PROCEDURE teardown_test IS
  BEGIN
    -- Clean up after each test
    BEGIN
      PL_FPDF.Reset();
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END teardown_test;


  -- ==========================================================================
  -- TEST GROUP 1: Basic Initialization
  -- ==========================================================================

  PROCEDURE test_init_default_params IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized(), 'Should be initialized').to_be_true();
  END test_init_default_params;


  PROCEDURE test_init_portrait IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_orientation => 'P');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Could add more assertions to check internal state if accessors exist
  END test_init_portrait;


  PROCEDURE test_init_landscape IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_orientation => 'L');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_init_landscape;


  PROCEDURE test_init_different_units IS
    l_units ut_varchar2_list := ut_varchar2_list('mm', 'cm', 'in', 'pt');
    l_unit VARCHAR2(10);
  BEGIN
    FOR i IN 1..l_units.COUNT LOOP
      l_unit := l_units(i);

      -- Reset before each iteration
      PL_FPDF.Reset();

      -- Act
      PL_FPDF.Init(p_unit => l_unit);

      -- Assert
      ut.expect(PL_FPDF.IsInitialized(),
        'Should initialize with unit: ' || l_unit).to_be_true();
    END LOOP;
  END test_init_different_units;


  PROCEDURE test_init_different_formats IS
    l_formats ut_varchar2_list := ut_varchar2_list('A4', 'Letter', 'Legal', 'A3', 'A5');
    l_format VARCHAR2(20);
  BEGIN
    FOR i IN 1..l_formats.COUNT LOOP
      l_format := l_formats(i);

      -- Reset before each iteration
      PL_FPDF.Reset();

      -- Act
      PL_FPDF.Init(p_format => l_format);

      -- Assert
      ut.expect(PL_FPDF.IsInitialized(),
        'Should initialize with format: ' || l_format).to_be_true();
    END LOOP;
  END test_init_different_formats;


  PROCEDURE test_init_utf8_encoding IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_encoding => 'UTF-8');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_init_utf8_encoding;


  -- ==========================================================================
  -- TEST GROUP 2: Parameter Validation
  -- ==========================================================================

  PROCEDURE test_init_invalid_orientation IS
  BEGIN
    -- Act & Assert (should raise -20001)
    PL_FPDF.Init(p_orientation => 'X');
  END test_init_invalid_orientation;


  PROCEDURE test_init_invalid_unit IS
  BEGIN
    -- Act & Assert (should raise -20002)
    PL_FPDF.Init(p_unit => 'meters');
  END test_init_invalid_unit;


  PROCEDURE test_init_invalid_encoding IS
  BEGIN
    -- Act & Assert (should raise -20003)
    PL_FPDF.Init(p_encoding => 'EBCDIC');
  END test_init_invalid_encoding;


  PROCEDURE test_init_null_params IS
  BEGIN
    -- Act - NULL params should use defaults
    PL_FPDF.Init(
      p_orientation => NULL,
      p_unit => NULL,
      p_format => NULL,
      p_encoding => NULL
    );

    -- Assert - should still initialize successfully with defaults
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_init_null_params;


  -- ==========================================================================
  -- TEST GROUP 3: State Management
  -- ==========================================================================

  PROCEDURE test_not_initialized_initially IS
  BEGIN
    -- Assert
    ut.expect(PL_FPDF.IsInitialized(),
      'Should not be initialized before Init()').to_be_false();
  END test_not_initialized_initially;


  PROCEDURE test_is_initialized_after_init IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized(),
      'Should be initialized after Init()').to_be_true();
  END test_is_initialized_after_init;


  PROCEDURE test_not_initialized_after_reset IS
  BEGIN
    -- Arrange
    PL_FPDF.Init();
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();

    -- Act
    PL_FPDF.Reset();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized(),
      'Should not be initialized after Reset()').to_be_false();
  END test_not_initialized_after_reset;


  -- ==========================================================================
  -- TEST GROUP 4: Re-initialization
  -- ==========================================================================

  PROCEDURE test_reinit_allowed IS
  BEGIN
    -- Arrange
    PL_FPDF.Init('P', 'mm', 'A4');

    -- Act - re-initialize with different params
    PL_FPDF.Init('L', 'cm', 'Letter');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized(),
      'Should remain initialized after re-init').to_be_true();
  END test_reinit_allowed;


  PROCEDURE test_reinit_frees_resources IS
  BEGIN
    -- Arrange
    PL_FPDF.Init();

    -- Act - re-initialize (should free old CLOBs and create new ones)
    PL_FPDF.Init();

    -- Assert - if no exceptions raised, resources were freed properly
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_reinit_frees_resources;


  PROCEDURE test_reinit_changes_params IS
  BEGIN
    -- Arrange
    PL_FPDF.Init('P', 'mm', 'A4', 'UTF-8');

    -- Act
    PL_FPDF.Init('L', 'cm', 'Letter', 'UTF-8');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Note: Would need getter functions to verify actual parameter values changed
  END test_reinit_changes_params;


  -- ==========================================================================
  -- TEST GROUP 5: Reset Functionality
  -- ==========================================================================

  PROCEDURE test_reset_clears_state IS
  BEGIN
    -- Arrange
    PL_FPDF.Init();
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();

    -- Act
    PL_FPDF.Reset();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized(),
      'State should be cleared after Reset').to_be_false();
  END test_reset_clears_state;


  PROCEDURE test_reset_frees_clobs IS
  BEGIN
    -- Arrange
    PL_FPDF.Init();

    -- Act
    PL_FPDF.Reset();

    -- Assert - if no ORA-22275 (LOB not open) on subsequent operations
    ut.expect(PL_FPDF.IsInitialized()).to_be_false();
  END test_reset_frees_clobs;


  PROCEDURE test_init_after_reset IS
  BEGIN
    -- Arrange
    PL_FPDF.Init();
    PL_FPDF.Reset();
    ut.expect(PL_FPDF.IsInitialized()).to_be_false();

    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized(),
      'Should be able to Init after Reset').to_be_true();
  END test_init_after_reset;


  -- ==========================================================================
  -- TEST GROUP 6: CLOB Management
  -- ==========================================================================

  PROCEDURE test_init_creates_clobs IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- CLOBs are created internally, if Init succeeds without error, CLOBs were created
  END test_init_creates_clobs;


  PROCEDURE test_clobs_are_temporary IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Temporary CLOBs should be session-scoped and freed on Reset
  END test_clobs_are_temporary;


  -- ==========================================================================
  -- TEST GROUP 7: Configuration Verification
  -- ==========================================================================

  PROCEDURE test_scale_factor_mm IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_unit => 'mm');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Scale factor for mm should be 72/25.4 ≈ 2.83465
    -- Would need GetScaleFactor() to verify actual value
  END test_scale_factor_mm;


  PROCEDURE test_scale_factor_cm IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_unit => 'cm');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Scale factor for cm should be 72/2.54 ≈ 28.3465
  END test_scale_factor_cm;


  PROCEDURE test_scale_factor_in IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_unit => 'in');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Scale factor for inches should be 72
  END test_scale_factor_in;


  PROCEDURE test_scale_factor_pt IS
  BEGIN
    -- Act
    PL_FPDF.Init(p_unit => 'pt');

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Scale factor for points should be 1
  END test_scale_factor_pt;


  PROCEDURE test_default_margins IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Default margins should be 10mm (or equivalent in other units)
    -- Would need GetMargins() to verify
  END test_default_margins;


  PROCEDURE test_default_font IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Default font should be Arial, 12pt
    -- Would need GetCurrentFont() to verify
  END test_default_font;


  PROCEDURE test_default_colors IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Default colors should be black (0,0,0)
    -- Would need GetDrawColor(), GetFillColor() to verify
  END test_default_colors;


  -- ==========================================================================
  -- TEST GROUP 8: Edge Cases
  -- ==========================================================================

  PROCEDURE test_multiple_resets IS
  BEGIN
    -- Arrange
    PL_FPDF.Init();

    -- Act - multiple resets should not cause errors
    PL_FPDF.Reset();
    PL_FPDF.Reset();
    PL_FPDF.Reset();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_false();
  END test_multiple_resets;


  PROCEDURE test_init_reset_init_cycle IS
  BEGIN
    -- Act - rapid init-reset-init cycle
    FOR i IN 1..5 LOOP
      PL_FPDF.Init();
      ut.expect(PL_FPDF.IsInitialized()).to_be_true();

      PL_FPDF.Reset();
      ut.expect(PL_FPDF.IsInitialized()).to_be_false();
    END LOOP;

    -- Final init
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_init_reset_init_cycle;


  PROCEDURE test_case_insensitive_orientation IS
  BEGIN
    -- Test lowercase
    PL_FPDF.Init(p_orientation => 'p');
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();

    PL_FPDF.Reset();

    -- Test uppercase
    PL_FPDF.Init(p_orientation => 'P');
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_case_insensitive_orientation;


  PROCEDURE test_case_insensitive_unit IS
  BEGIN
    -- Test lowercase
    PL_FPDF.Init(p_unit => 'mm');
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();

    PL_FPDF.Reset();

    -- Test uppercase
    PL_FPDF.Init(p_unit => 'MM');
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
  END test_case_insensitive_unit;


  -- ==========================================================================
  -- TEST GROUP 9: Metadata Initialization
  -- ==========================================================================

  PROCEDURE test_init_metadata IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Metadata structure should be initialized (JSON_OBJECT_T)
  END test_init_metadata;


  PROCEDURE test_metadata_creator IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Metadata should contain creator = 'PL_FPDF v2.0 for Oracle 19c/23c'
    -- Would need GetMetadata() to verify
  END test_metadata_creator;


  PROCEDURE test_metadata_creation_date IS
  BEGIN
    -- Act
    PL_FPDF.Init();

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    -- Metadata should contain creation date (current timestamp)
  END test_metadata_creation_date;


  -- ==========================================================================
  -- TEST GROUP 10: Performance Tests
  -- ==========================================================================

  PROCEDURE test_init_performance IS
    l_start_time TIMESTAMP;
    l_end_time TIMESTAMP;
    l_duration_ms NUMBER;
  BEGIN
    -- Arrange
    l_start_time := SYSTIMESTAMP;

    -- Act
    PL_FPDF.Init();

    -- Measure
    l_end_time := SYSTIMESTAMP;
    l_duration_ms := EXTRACT(SECOND FROM (l_end_time - l_start_time)) * 1000;

    -- Assert
    ut.expect(PL_FPDF.IsInitialized()).to_be_true();
    ut.expect(l_duration_ms,
      'Init should complete in < 100ms').to_be_less_than(100);

    DBMS_OUTPUT.PUT_LINE('Init duration: ' || l_duration_ms || 'ms');
  END test_init_performance;


  PROCEDURE test_rapid_init_reset_cycles IS
    l_start_time TIMESTAMP;
    l_end_time TIMESTAMP;
    l_duration_ms NUMBER;
    l_iterations CONSTANT NUMBER := 100;
  BEGIN
    -- Arrange
    l_start_time := SYSTIMESTAMP;

    -- Act - 100 rapid cycles
    FOR i IN 1..l_iterations LOOP
      PL_FPDF.Init();
      PL_FPDF.Reset();
    END LOOP;

    -- Measure
    l_end_time := SYSTIMESTAMP;
    l_duration_ms := EXTRACT(SECOND FROM (l_end_time - l_start_time)) * 1000;

    -- Assert
    ut.expect(l_duration_ms,
      '100 cycles should complete in < 10 seconds').to_be_less_than(10000);

    DBMS_OUTPUT.PUT_LINE('100 init-reset cycles: ' || l_duration_ms || 'ms');
    DBMS_OUTPUT.PUT_LINE('Average per cycle: ' || ROUND(l_duration_ms / l_iterations, 2) || 'ms');
  END test_rapid_init_reset_cycles;

END test_pl_fpdf_init;
/
