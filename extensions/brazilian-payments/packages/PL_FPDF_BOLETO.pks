--------------------------------------------------------------------------------
-- Package: PL_FPDF_BOLETO
-- Description: Boleto Bancário (Brazilian Bank Slip) utility functions
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Version: 1.0.0
--------------------------------------------------------------------------------
-- This package provides functions for generating and validating Boleto Bancário
-- barcodes according to FEBRABAN standards.
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE PL_FPDF_BOLETO AS

/*******************************************************************************
* Function: CalculateFatorVencimento
* Description: Calculates due date factor for Boleto (days since 1997-10-07)
* Parameters:
*   p_data - Due date
* Returns: 4-digit factor string (0000-9999)
* Raises:
*   -20802: Invalid date (NULL, before 1997-10-07, or too far in future)
* Example:
*   -- Returns: '9948' (approximate)
*   l_fator := PL_FPDF_BOLETO.CalculateFatorVencimento(TO_DATE('2025-01-01','YYYY-MM-DD'));
*******************************************************************************/
FUNCTION CalculateFatorVencimento(
  p_data DATE
) RETURN VARCHAR2 DETERMINISTIC;

/*******************************************************************************
* Function: CalculateDVBoleto
* Description: Calculates check digit for Boleto barcode (módulo 11)
* Parameters:
*   p_codigo - 43-character code (without DV at position 5)
* Returns: Single check digit character ('0'-'9' or '1' for special cases)
* Raises:
*   -20803: Invalid code length or non-numeric characters
* Example:
*   l_dv := PL_FPDF_BOLETO.CalculateDVBoleto('0019000000...');
*******************************************************************************/
FUNCTION CalculateDVBoleto(
  p_codigo VARCHAR2
) RETURN CHAR DETERMINISTIC;

/*******************************************************************************
* Function: ValidateCodigoBarras
* Description: Validates a 44-position Boleto barcode
* Parameters:
*   p_codigo - 44-character barcode
* Returns: TRUE if valid, FALSE otherwise
* Example:
*   IF PL_FPDF_BOLETO.ValidateCodigoBarras('00191234500001234567890...') THEN
*     DBMS_OUTPUT.PUT_LINE('Valid barcode');
*   END IF;
*******************************************************************************/
FUNCTION ValidateCodigoBarras(
  p_codigo VARCHAR2
) RETURN BOOLEAN DETERMINISTIC;

/*******************************************************************************
* Function: GetCodigoBarras
* Description: Generates 44-position Boleto barcode
* Parameters:
*   p_boleto_data - JSON object with configuration:
*     Required fields:
*       - banco: Bank code (3 digits)
*       - vencimento: Due date (DATE or 'YYYY-MM-DD' string)
*       - valor: Amount (NUMBER)
*       - campoLivre: Free field (25 digits)
*     Optional fields:
*       - moeda: Currency code (default '9' for Real)
* Returns: 44-character barcode string
* Raises:
*   -20801: Missing or invalid required field
*   -20802: Invalid due date
* Structure: BBBMDVFFFFVVVVVVVVVVCCCCCCCCCCCCCCCCCCCCCCCCC
*   BBB = Bank code (3 digits)
*   M = Currency (1 digit, 9=Real)
*   DV = Check digit (módulo 11)
*   FFFF = Due date factor
*   VVVVVVVVVV = Amount (10 digits, no decimal)
*   CCC... = Free field (25 digits, bank-defined)
* Example:
*   DECLARE
*     l_boleto JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     l_boleto.put('banco', '001');
*     l_boleto.put('vencimento', TO_DATE('2025-12-31','YYYY-MM-DD'));
*     l_boleto.put('valor', 1500.00);
*     l_boleto.put('campoLivre', '1234567890123456789012345');
*     DBMS_OUTPUT.PUT_LINE(PL_FPDF_BOLETO.GetCodigoBarras(l_boleto));
*   END;
*******************************************************************************/
FUNCTION GetCodigoBarras(
  p_boleto_data JSON_OBJECT_T
) RETURN VARCHAR2;

/*******************************************************************************
* Function: GetLinhaDigitavel
* Description: Generates 47-digit formatted linha digitável from Boleto data
* Parameters:
*   p_boleto_data - JSON object with Boleto configuration (see GetCodigoBarras)
* Returns: Formatted linha digitável string with dots and spaces
* Structure: AAABC.CCCCX DDDDD.DDDDDDY EEEEE.EEEEEZ K UUUUVVVVVVVVVV
*   Where X, Y, Z are check digits (módulo 10) and K is the main check digit
* Example:
*   l_linha := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data);
*   -- Returns: "00190.00009 01234.567890 12345.678901 2 12340000150000"
*******************************************************************************/
FUNCTION GetLinhaDigitavel(
  p_boleto_data JSON_OBJECT_T
) RETURN VARCHAR2;

/*******************************************************************************
* Function: ParseLinhaDigitavel
* Description: Extracts barcode from linha digitável
* Parameters:
*   p_linha - Linha digitável (with or without formatting)
* Returns: 44-character barcode
* Raises:
*   -20803: Invalid linha digitável format or check digits
* Example:
*   l_barcode := PL_FPDF_BOLETO.ParseLinhaDigitavel('00190.00009 01234.567890...');
*******************************************************************************/
FUNCTION ParseLinhaDigitavel(
  p_linha VARCHAR2
) RETURN VARCHAR2;

--------------------------------------------------------------------------------
-- PDF Rendering Procedures (require PL_FPDF package)
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddBarcodeBoleto
* Description: Adds a Boleto barcode (ITF14) to the current PDF page
* Parameters:
*   p_x - X position in mm
*   p_y - Y position in mm
*   p_width - Barcode width in mm (minimum 100mm)
*   p_height - Barcode height in mm (minimum 13mm)
*   p_boleto_data - JSON object with Boleto configuration (see GetCodigoBarras)
* Requires: PL_FPDF package must be initialized with Init() and AddPage()
* Raises:
*   -20803: Negative position
*   -20804: Barcode dimensions too small
* Example:
*   DECLARE
*     l_boleto JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     PL_FPDF.Init();
*     PL_FPDF.AddPage();
*     l_boleto.put('banco', '237');
*     l_boleto.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
*     l_boleto.put('valor', 1500.00);
*     l_boleto.put('campoLivre', '1234567890123456789012345');
*     PL_FPDF_BOLETO.AddBarcodeBoleto(10, 100, 180, 13, l_boleto);
*   END;
*******************************************************************************/
PROCEDURE AddBarcodeBoleto(
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_boleto_data JSON_OBJECT_T
);

/*******************************************************************************
* Procedure: AddBarcodeJSON
* Description: Adds a barcode to PDF from JSON configuration
* Parameters:
*   p_x - X position in mm
*   p_y - Y position in mm
*   p_width - Barcode width in mm
*   p_height - Barcode height in mm
*   p_config - JSON object with configuration:
*     Required fields:
*       - type: 'BOLETO', 'ITF14', 'CODE128', 'CODE39', 'EAN13', 'EAN8'
*     For BOLETO type:
*       - boletoData: JSON object (see GetCodigoBarras)
*     For other types:
*       - code: Barcode data string
*     Optional:
*       - showText: BOOLEAN (default true)
* Requires: PL_FPDF package must be initialized
* Raises:
*   -20805: Missing required field
* Example:
*   DECLARE
*     l_config JSON_OBJECT_T := JSON_OBJECT_T();
*     l_boleto JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     PL_FPDF.Init();
*     PL_FPDF.AddPage();
*     l_boleto.put('banco', '001');
*     l_boleto.put('vencimento', SYSDATE + 30);
*     l_boleto.put('valor', 2000.00);
*     l_boleto.put('campoLivre', '9999999999999999999999999');
*     l_config.put('type', 'BOLETO');
*     l_config.put('boletoData', l_boleto);
*     PL_FPDF_BOLETO.AddBarcodeJSON(10, 150, 180, 13, l_config);
*   END;
*******************************************************************************/
PROCEDURE AddBarcodeJSON(
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_config JSON_OBJECT_T
);

END PL_FPDF_BOLETO;
/
