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

END PL_FPDF_PIX;
/
