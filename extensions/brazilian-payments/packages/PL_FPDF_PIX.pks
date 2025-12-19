--------------------------------------------------------------------------------
-- Package: PL_FPDF_PIX
-- Description: PIX (Brazilian Instant Payment) utility functions
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Version: 1.0.0
--------------------------------------------------------------------------------
-- This package provides functions for generating and validating PIX payloads
-- according to Banco Central do Brasil and EMV QR Code standards.
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE PL_FPDF_PIX AS

/*******************************************************************************
* Function: ValidatePixKey
* Description: Validates a PIX key according to its type
* Parameters:
*   p_key - PIX key value
*   p_type - Key type: 'CPF', 'CNPJ', 'EMAIL', 'PHONE', 'RANDOM'
* Returns: TRUE if valid, FALSE otherwise
* Example:
*   IF PL_FPDF_PIX.ValidatePixKey('12345678901', 'CPF') THEN
*     DBMS_OUTPUT.PUT_LINE('Valid CPF');
*   END IF;
*******************************************************************************/
FUNCTION ValidatePixKey(
  p_key VARCHAR2,
  p_type VARCHAR2
) RETURN BOOLEAN DETERMINISTIC;

/*******************************************************************************
* Function: CalculateCRC16
* Description: Calculates CRC16-CCITT checksum for PIX payload
* Parameters:
*   p_payload - PIX payload string (without CRC)
* Returns: 4-character hexadecimal CRC
* Example:
*   l_crc := PL_FPDF_PIX.CalculateCRC16('00020126580014br.gov.bcb.pix...');
*******************************************************************************/
FUNCTION CalculateCRC16(
  p_payload VARCHAR2
) RETURN VARCHAR2 DETERMINISTIC;

/*******************************************************************************
* Function: GetPixPayload
* Description: Generates PIX EMV QR Code payload (copy-paste string)
* Parameters:
*   p_pix_data - JSON object with PIX configuration:
*     Required fields:
*       - pixKey: PIX key value
*       - pixKeyType: Key type (CPF, CNPJ, EMAIL, PHONE, RANDOM)
*       - merchantName: Merchant name (max 25 chars)
*       - merchantCity: City (max 15 chars)
*     Optional fields:
*       - amount: Transaction amount (NUMBER)
*       - txid: Transaction ID (max 25 chars)
*       - merchantCategoryCode: MCC (default '0000')
*       - countryCode: Country (default 'BR')
* Returns: EMV-formatted PIX payload with CRC16
* Raises:
*   -20701: Missing required field or invalid PIX key
*   -20702: Missing merchant city
* Example:
*   DECLARE
*     l_pix JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     l_pix.put('pixKey', 'user@example.com');
*     l_pix.put('pixKeyType', 'EMAIL');
*     l_pix.put('merchantName', 'My Store');
*     l_pix.put('merchantCity', 'Sao Paulo');
*     l_pix.put('amount', 99.90);
*     DBMS_OUTPUT.PUT_LINE(PL_FPDF_PIX.GetPixPayload(l_pix));
*   END;
*******************************************************************************/
FUNCTION GetPixPayload(
  p_pix_data JSON_OBJECT_T
) RETURN VARCHAR2;

/*******************************************************************************
* Function: FormatPixKey
* Description: Formats a PIX key for display (adds masks for CPF/CNPJ/Phone)
* Parameters:
*   p_key - PIX key value
*   p_type - Key type
* Returns: Formatted key string
* Example:
*   -- Returns: '123.456.789-01'
*   l_formatted := PL_FPDF_PIX.FormatPixKey('12345678901', 'CPF');
*******************************************************************************/
FUNCTION FormatPixKey(
  p_key VARCHAR2,
  p_type VARCHAR2
) RETURN VARCHAR2 DETERMINISTIC;

--------------------------------------------------------------------------------
-- PDF Rendering Procedures (require PL_FPDF package)
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddQRCodePIX
* Description: Adds a PIX QR Code to the current PDF page
* Parameters:
*   p_x - X position in mm
*   p_y - Y position in mm
*   p_size - QR Code size in mm (minimum 5mm)
*   p_pix_data - JSON object with PIX configuration (see GetPixPayload)
* Requires: PL_FPDF package must be initialized with Init() and AddPage()
* Raises:
*   -20703: Negative position
*   -20704: Size too small
* Example:
*   DECLARE
*     l_pix JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     PL_FPDF.Init();
*     PL_FPDF.AddPage();
*     l_pix.put('pixKey', 'user@example.com');
*     l_pix.put('pixKeyType', 'EMAIL');
*     l_pix.put('merchantName', 'My Store');
*     l_pix.put('merchantCity', 'Sao Paulo');
*     l_pix.put('amount', 99.90);
*     PL_FPDF_PIX.AddQRCodePIX(80, 50, 50, l_pix);
*   END;
*******************************************************************************/
PROCEDURE AddQRCodePIX(
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_pix_data JSON_OBJECT_T
);

/*******************************************************************************
* Procedure: AddQRCodeJSON
* Description: Adds a QR Code to PDF from JSON configuration
* Parameters:
*   p_x - X position in mm
*   p_y - Y position in mm
*   p_size - QR Code size in mm
*   p_config - JSON object with configuration:
*     Required fields:
*       - format: 'PIX', 'TEXT', 'URL', 'VCARD', 'WIFI', 'EMAIL'
*     For PIX format:
*       - pixData: JSON object (see GetPixPayload)
*     For other formats:
*       - data: String data
*     Optional:
*       - errorCorrection: 'L', 'M', 'Q', 'H' (default 'M')
* Requires: PL_FPDF package must be initialized
* Raises:
*   -20706: Missing required field
* Example:
*   DECLARE
*     l_config JSON_OBJECT_T := JSON_OBJECT_T();
*     l_pix JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     PL_FPDF.Init();
*     PL_FPDF.AddPage();
*     l_pix.put('pixKey', '12345678901');
*     l_pix.put('pixKeyType', 'CPF');
*     l_pix.put('merchantName', 'Store');
*     l_pix.put('merchantCity', 'SP');
*     l_config.put('format', 'PIX');
*     l_config.put('pixData', l_pix);
*     PL_FPDF_PIX.AddQRCodeJSON(100, 100, 50, l_config);
*   END;
*******************************************************************************/
PROCEDURE AddQRCodeJSON(
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_config JSON_OBJECT_T
);

END PL_FPDF_PIX;
/
