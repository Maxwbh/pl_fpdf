/*******************************************************************************
* Test Runner: PL_FPDF Comprehensive Test Suite
* Version: 3.0.0-b.2
* Date: 2026-01
* Author: @maxwbh
*
* Purpose: Organized test runner for all PL_FPDF phases
*
* Test Execution Order:
*   1. Phase 1-3 Validation (Foundation)
*   2. Phase 4 Individual Tests (Detailed)
*   3. Phase 4 Complete Validation (Integration)
*
* Usage:
*   SET SERVEROUTPUT ON SIZE UNLIMITED
*   @tests/test_runner.sql
*
* Options:
*   - Run all tests (default)
*   - Comment out sections to skip specific phases
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET TIMING ON

PROMPT ################################################################################
PROMPT #                                                                              #
PROMPT #                      PL_FPDF Test Suite Runner                              #
PROMPT #                            Version 3.0.0-b.2                                 #
PROMPT #                                                                              #
PROMPT ################################################################################
PROMPT

-- Display current timestamp
SELECT 'Test Run Started: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS info FROM DUAL;

PROMPT
PROMPT ================================================================================
PROMPT SECTION 1: FOUNDATION VALIDATION (Phases 1-3)
PROMPT ================================================================================
PROMPT
PROMPT Running: validate_phases_1_3.sql
PROMPT This validates PDF generation foundation (Phases 1-3)
PROMPT --------------------------------------------------------------------------------
@@validate_phases_1_3.sql

PROMPT
PROMPT
PROMPT ================================================================================
PROMPT SECTION 2: PHASE 4 DETAILED TESTS
PROMPT ================================================================================
PROMPT

-- Phase 4.1A: PDF Parser
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.1A: PDF Parser Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_1a_parser.sql
@@test_phase_4_1a_parser.sql

-- Phase 4.1B: Page Information
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.1B: Page Information Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_1b_pages.sql
@@test_phase_4_1b_pages.sql

-- Phase 4.2: Page Management
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.2: Page Management Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_2_page_mgmt.sql
@@test_phase_4_2_page_mgmt.sql

-- Phase 4.3: Watermarks
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.3: Watermark Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_3_watermark.sql
@@test_phase_4_3_watermark.sql

-- Phase 4.4: Output Modified PDF
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.4: Output Modified PDF Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_4_output.sql
@@test_phase_4_4_output.sql

-- Phase 4.5: Text & Image Overlay
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.5: Text & Image Overlay Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_5_overlay.sql
@@test_phase_4_5_overlay.sql

-- Phase 4.6: PDF Merge & Split
PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT Phase 4.6: PDF Merge & Split Tests
PROMPT --------------------------------------------------------------------------------
PROMPT Running: test_phase_4_6_merge_split.sql
@@test_phase_4_6_merge_split.sql

PROMPT
PROMPT
PROMPT ================================================================================
PROMPT SECTION 3: PHASE 4 COMPLETE VALIDATION
PROMPT ================================================================================
PROMPT
PROMPT Running: validate_phase_4_complete.sql
PROMPT This validates all Phase 4 features together (Integration Test)
PROMPT --------------------------------------------------------------------------------
@@validate_phase_4_complete.sql

PROMPT
PROMPT
PROMPT ################################################################################
PROMPT #                                                                              #
PROMPT #                        TEST SUITE EXECUTION COMPLETE                        #
PROMPT #                                                                              #
PROMPT ################################################################################
PROMPT

-- Display completion timestamp
SELECT 'Test Run Completed: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS info FROM DUAL;

PROMPT
PROMPT ================================================================================
PROMPT Test Suite Summary
PROMPT ================================================================================
PROMPT
PROMPT Tests Executed:
PROMPT   1. validate_phases_1_3.sql       - Foundation validation
PROMPT   2. test_phase_4_1a_parser.sql    - PDF Parser tests
PROMPT   3. test_phase_4_1b_pages.sql     - Page Information tests
PROMPT   4. test_phase_4_2_page_mgmt.sql  - Page Management tests
PROMPT   5. test_phase_4_3_watermark.sql  - Watermark tests
PROMPT   6. test_phase_4_4_output.sql     - Output Modified PDF tests
PROMPT   7. test_phase_4_5_overlay.sql    - Text/Image Overlay tests (20 tests)
PROMPT   8. test_phase_4_6_merge_split.sql- Merge/Split tests (20 tests)
PROMPT   9. validate_phase_4_complete.sql - Phase 4 integration validation
PROMPT
PROMPT Total Test Files: 9
PROMPT Estimated Total Test Cases: ~150+
PROMPT
PROMPT Review the output above for any failures.
PROMPT
PROMPT ================================================================================
PROMPT Next Steps
PROMPT ================================================================================
PROMPT
PROMPT If all tests PASSED:
PROMPT   - Phase 4 is validated and ready for promotion
PROMPT   - Version can move from Beta (3.0.0-b.2) to Release Candidate (3.0.0-rc.1)
PROMPT   - Update version in PL_FPDF.pkb, README.md, and CHANGELOG.md
PROMPT
PROMPT If any tests FAILED:
PROMPT   - Review error messages in the output above
PROMPT   - Fix issues in PL_FPDF package
PROMPT   - Re-run affected test files
PROMPT   - Version remains in Beta status until all tests pass
PROMPT
PROMPT For individual test reruns:
PROMPT   @tests/validate_phases_1_3.sql
PROMPT   @tests/test_phase_4_5_overlay.sql
PROMPT   @tests/test_phase_4_6_merge_split.sql
PROMPT   @tests/validate_phase_4_complete.sql
PROMPT
PROMPT ================================================================================
PROMPT

SET TIMING OFF
SET FEEDBACK ON
SET VERIFY ON
