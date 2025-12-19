--------------------------------------------------------------------------------
-- Package Body: PL_FPDF_PIX
-- Description: PIX (Brazilian Instant Payment) utility functions
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Version: 1.0.0
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY PL_FPDF_PIX AS

/*******************************************************************************
* Function: ValidatePixKey
* Description: Validates a PIX key according to its type
*******************************************************************************/
FUNCTION ValidatePixKey(
  p_key VARCHAR2,
  p_type VARCHAR2
) RETURN BOOLEAN DETERMINISTIC IS
  l_type_upper VARCHAR2(20);
  l_key_clean VARCHAR2(4000);
BEGIN
  IF p_key IS NULL OR p_type IS NULL THEN
    RETURN FALSE;
  END IF;

  l_type_upper := UPPER(p_type);
  l_key_clean := p_key;

  CASE l_type_upper
    WHEN 'CPF' THEN
      -- CPF: 11 numeric digits
      l_key_clean := REGEXP_REPLACE(l_key_clean, '[^0-9]', '');
      RETURN LENGTH(l_key_clean) = 11 AND REGEXP_LIKE(l_key_clean, '^[0-9]{11}$');

    WHEN 'CNPJ' THEN
      -- CNPJ: 14 numeric digits
      l_key_clean := REGEXP_REPLACE(l_key_clean, '[^0-9]', '');
      RETURN LENGTH(l_key_clean) = 14 AND REGEXP_LIKE(l_key_clean, '^[0-9]{14}$');

    WHEN 'EMAIL' THEN
      -- Email: basic validation (has @ and domain)
      RETURN REGEXP_LIKE(p_key, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

    WHEN 'PHONE' THEN
      -- Phone: +55 followed by 10-11 digits, or just 12-13 digits
      l_key_clean := REGEXP_REPLACE(l_key_clean, '[^0-9+]', '');
      IF SUBSTR(l_key_clean, 1, 1) = '+' THEN
        l_key_clean := SUBSTR(l_key_clean, 2);
      END IF;
      RETURN LENGTH(l_key_clean) BETWEEN 12 AND 13 AND REGEXP_LIKE(l_key_clean, '^[0-9]{12,13}$');

    WHEN 'RANDOM' THEN
      -- Random key (EVP): UUID format or at least 32 characters
      l_key_clean := REGEXP_REPLACE(l_key_clean, '[^A-Za-z0-9-]', '');
      RETURN LENGTH(l_key_clean) >= 32;

    ELSE
      RETURN FALSE;
  END CASE;

EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END ValidatePixKey;

/*******************************************************************************
* Function: CalculateCRC16
* Description: Calculates CRC16-CCITT checksum for PIX payload
*******************************************************************************/
FUNCTION CalculateCRC16(
  p_payload VARCHAR2
) RETURN VARCHAR2 DETERMINISTIC IS
  l_crc PLS_INTEGER := 65535;  -- 0xFFFF
  l_byte PLS_INTEGER;
  l_i PLS_INTEGER;
  l_j PLS_INTEGER;
  l_polynomial CONSTANT PLS_INTEGER := 4129;  -- 0x1021 (CRC16-CCITT polynomial)

  -- Helper function for XOR (Oracle 19c doesn't have BITXOR)
  FUNCTION xor_bits(p_a PLS_INTEGER, p_b PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN
    RETURN (p_a + p_b) - 2 * BITAND(p_a, p_b);
  END;

BEGIN
  -- Process each character
  FOR l_i IN 1..LENGTH(p_payload) LOOP
    l_byte := ASCII(SUBSTR(p_payload, l_i, 1));
    l_crc := BITAND(l_crc, 65535);  -- Keep 16 bits

    -- XOR byte into CRC
    l_crc := xor_bits(l_crc, l_byte * 256);  -- Shift byte left 8 bits

    -- Process 8 bits
    FOR l_j IN 1..8 LOOP
      IF BITAND(l_crc, 32768) != 0 THEN  -- Check MSB (0x8000)
        l_crc := BITAND(xor_bits(l_crc * 2, l_polynomial), 65535);
      ELSE
        l_crc := BITAND(l_crc * 2, 65535);
      END IF;
    END LOOP;
  END LOOP;

  -- Return as 4-character uppercase hex
  RETURN UPPER(LPAD(TRIM(TO_CHAR(l_crc, 'XXXX')), 4, '0'));

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20700, 'Failed to calculate CRC16: ' || SQLERRM);
END CalculateCRC16;

/*******************************************************************************
* Function: GetPixPayload
* Description: Generates PIX EMV QR Code payload
*******************************************************************************/
FUNCTION GetPixPayload(
  p_pix_data JSON_OBJECT_T
) RETURN VARCHAR2 IS
  l_payload VARCHAR2(32767);
  l_pix_key VARCHAR2(4000);
  l_pix_key_type VARCHAR2(50);
  l_merchant_name VARCHAR2(4000);
  l_merchant_city VARCHAR2(4000);
  l_amount NUMBER;
  l_txid VARCHAR2(4000);
  l_amount_str VARCHAR2(50);
  l_crc VARCHAR2(4);
  l_mcc VARCHAR2(4);
  l_country VARCHAR2(2);

  -- Helper function to format EMV TLV (Tag-Length-Value)
  FUNCTION emv_tlv(p_id VARCHAR2, p_value VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_value IS NULL THEN
      RETURN '';
    END IF;
    RETURN p_id || LPAD(LENGTH(p_value), 2, '0') || p_value;
  END;

BEGIN
  -- Validate required fields
  IF NOT p_pix_data.has('pixKey') THEN
    RAISE_APPLICATION_ERROR(-20701, 'PIX key is required (pixKey field)');
  END IF;
  IF NOT p_pix_data.has('pixKeyType') THEN
    RAISE_APPLICATION_ERROR(-20701, 'PIX key type is required (pixKeyType field)');
  END IF;
  IF NOT p_pix_data.has('merchantName') THEN
    RAISE_APPLICATION_ERROR(-20701, 'Merchant name is required (merchantName field)');
  END IF;
  IF NOT p_pix_data.has('merchantCity') THEN
    RAISE_APPLICATION_ERROR(-20702, 'Merchant city is required (merchantCity field)');
  END IF;

  -- Get required fields
  l_pix_key := p_pix_data.get_String('pixKey');
  l_pix_key_type := UPPER(p_pix_data.get_String('pixKeyType'));
  l_merchant_name := p_pix_data.get_String('merchantName');
  l_merchant_city := p_pix_data.get_String('merchantCity');

  -- Validate PIX key
  IF NOT ValidatePixKey(l_pix_key, l_pix_key_type) THEN
    RAISE_APPLICATION_ERROR(-20701,
      'Invalid PIX key: ' || l_pix_key || ' for type ' || l_pix_key_type);
  END IF;

  -- Get optional fields
  IF p_pix_data.has('amount') THEN
    l_amount := p_pix_data.get_Number('amount');
    l_amount_str := TRIM(TO_CHAR(l_amount, '999999990.99'));
  END IF;

  IF p_pix_data.has('txid') THEN
    l_txid := p_pix_data.get_String('txid');
  END IF;

  IF p_pix_data.has('merchantCategoryCode') THEN
    l_mcc := p_pix_data.get_String('merchantCategoryCode');
  ELSE
    l_mcc := '0000';
  END IF;

  IF p_pix_data.has('countryCode') THEN
    l_country := p_pix_data.get_String('countryCode');
  ELSE
    l_country := 'BR';
  END IF;

  -- Build EMV QR Code payload
  l_payload := '';

  -- Payload Format Indicator (ID 00)
  l_payload := l_payload || emv_tlv('00', '01');

  -- Merchant Account Information (ID 26 = br.gov.bcb.pix)
  DECLARE
    l_mai VARCHAR2(1000);
  BEGIN
    l_mai := emv_tlv('00', 'br.gov.bcb.pix');  -- GUI
    l_mai := l_mai || emv_tlv('01', l_pix_key);  -- PIX key
    IF l_txid IS NOT NULL THEN
      l_mai := l_mai || emv_tlv('02', l_txid);  -- Transaction ID
    END IF;
    l_payload := l_payload || emv_tlv('26', l_mai);
  END;

  -- Merchant Category Code (ID 52)
  l_payload := l_payload || emv_tlv('52', l_mcc);

  -- Transaction Currency (ID 53) - 986 = BRL (Brazilian Real)
  l_payload := l_payload || emv_tlv('53', '986');

  -- Transaction Amount (ID 54) - Optional
  IF l_amount_str IS NOT NULL THEN
    l_payload := l_payload || emv_tlv('54', l_amount_str);
  END IF;

  -- Country Code (ID 58)
  l_payload := l_payload || emv_tlv('58', l_country);

  -- Merchant Name (ID 59)
  l_payload := l_payload || emv_tlv('59', SUBSTR(l_merchant_name, 1, 25));

  -- Merchant City (ID 60)
  l_payload := l_payload || emv_tlv('60', SUBSTR(l_merchant_city, 1, 15));

  -- Additional Data (ID 62) - Optional with txid
  IF l_txid IS NOT NULL THEN
    DECLARE
      l_additional VARCHAR2(1000);
    BEGIN
      l_additional := emv_tlv('05', SUBSTR(l_txid, 1, 25));  -- Reference Label
      l_payload := l_payload || emv_tlv('62', l_additional);
    END;
  END IF;

  -- CRC16 placeholder (ID 63) - will be calculated and replaced
  l_payload := l_payload || '6304';

  -- Calculate CRC16 over payload (including '6304')
  l_crc := CalculateCRC16(l_payload);

  -- Append CRC
  l_payload := l_payload || l_crc;

  RETURN l_payload;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20799 AND -20700 THEN
      RAISE;  -- Re-raise our own errors
    ELSE
      RAISE_APPLICATION_ERROR(-20700, 'Error generating PIX payload: ' || SQLERRM);
    END IF;
END GetPixPayload;

/*******************************************************************************
* Function: FormatPixKey
* Description: Formats a PIX key for display
*******************************************************************************/
FUNCTION FormatPixKey(
  p_key VARCHAR2,
  p_type VARCHAR2
) RETURN VARCHAR2 DETERMINISTIC IS
  l_type_upper VARCHAR2(20);
  l_key_clean VARCHAR2(4000);
BEGIN
  IF p_key IS NULL THEN
    RETURN NULL;
  END IF;

  l_type_upper := UPPER(p_type);
  l_key_clean := REGEXP_REPLACE(p_key, '[^0-9]', '');

  CASE l_type_upper
    WHEN 'CPF' THEN
      -- Format: 123.456.789-01
      IF LENGTH(l_key_clean) = 11 THEN
        RETURN SUBSTR(l_key_clean, 1, 3) || '.' ||
               SUBSTR(l_key_clean, 4, 3) || '.' ||
               SUBSTR(l_key_clean, 7, 3) || '-' ||
               SUBSTR(l_key_clean, 10, 2);
      END IF;

    WHEN 'CNPJ' THEN
      -- Format: 12.345.678/0001-95
      IF LENGTH(l_key_clean) = 14 THEN
        RETURN SUBSTR(l_key_clean, 1, 2) || '.' ||
               SUBSTR(l_key_clean, 3, 3) || '.' ||
               SUBSTR(l_key_clean, 6, 3) || '/' ||
               SUBSTR(l_key_clean, 9, 4) || '-' ||
               SUBSTR(l_key_clean, 13, 2);
      END IF;

    WHEN 'PHONE' THEN
      -- Format: +55 (11) 98765-4321
      l_key_clean := REGEXP_REPLACE(p_key, '[^0-9+]', '');
      IF SUBSTR(l_key_clean, 1, 1) != '+' THEN
        l_key_clean := '+' || l_key_clean;
      END IF;
      IF LENGTH(l_key_clean) = 14 THEN  -- +55 11 987654321
        RETURN SUBSTR(l_key_clean, 1, 3) || ' (' ||
               SUBSTR(l_key_clean, 4, 2) || ') ' ||
               SUBSTR(l_key_clean, 6, 5) || '-' ||
               SUBSTR(l_key_clean, 11, 4);
      END IF;

    ELSE
      -- EMAIL and RANDOM: return as-is
      RETURN p_key;
  END CASE;

  -- If format doesn't match, return original
  RETURN p_key;

EXCEPTION
  WHEN OTHERS THEN
    RETURN p_key;
END FormatPixKey;

--------------------------------------------------------------------------------
-- PDF Rendering Procedures
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddQRCodePIX
* Description: Adds a PIX QR Code to the current PDF page
*******************************************************************************/
PROCEDURE AddQRCodePIX(
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_pix_data JSON_OBJECT_T
) IS
  l_payload VARCHAR2(32767);
BEGIN
  -- Validate parameters
  IF p_x < 0 OR p_y < 0 THEN
    RAISE_APPLICATION_ERROR(-20703, 'Position cannot be negative');
  END IF;

  IF p_size < 5 THEN
    RAISE_APPLICATION_ERROR(-20704, 'QR Code size must be at least 5mm');
  END IF;

  -- Generate PIX payload using internal function
  l_payload := GetPixPayload(p_pix_data);

  -- Call PL_FPDF generic QR Code function
  PL_FPDF.AddQRCode(p_x, p_y, p_size, l_payload, 'PIX', 'M');

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END AddQRCodePIX;

/*******************************************************************************
* Procedure: AddQRCodeJSON
* Description: Adds a QR Code to PDF from JSON configuration
*******************************************************************************/
PROCEDURE AddQRCodeJSON(
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_config JSON_OBJECT_T
) IS
  l_format VARCHAR2(20);
  l_data VARCHAR2(32767);
  l_pix_data JSON_OBJECT_T;
  l_error_correction VARCHAR2(1);
BEGIN
  -- Get format
  IF NOT p_config.has('format') THEN
    RAISE_APPLICATION_ERROR(-20706, 'QR Code format is required (format field)');
  END IF;

  l_format := UPPER(p_config.get_String('format'));

  -- Get error correction (optional, default 'M')
  IF p_config.has('errorCorrection') THEN
    l_error_correction := UPPER(SUBSTR(p_config.get_String('errorCorrection'), 1, 1));
  ELSE
    l_error_correction := 'M';
  END IF;

  -- Handle based on format
  IF l_format = 'PIX' THEN
    IF NOT p_config.has('pixData') THEN
      RAISE_APPLICATION_ERROR(-20706, 'PIX data is required (pixData field) for PIX format');
    END IF;
    l_pix_data := TREAT(p_config.get('pixData') AS JSON_OBJECT_T);
    AddQRCodePIX(p_x, p_y, p_size, l_pix_data);
  ELSE
    -- TEXT, URL, VCARD, WIFI, EMAIL formats
    IF NOT p_config.has('data') THEN
      RAISE_APPLICATION_ERROR(-20706, 'Data is required (data field) for ' || l_format || ' format');
    END IF;
    l_data := p_config.get_String('data');
    PL_FPDF.AddQRCode(p_x, p_y, p_size, l_data, l_format, l_error_correction);
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END AddQRCodeJSON;

END PL_FPDF_PIX;
/
