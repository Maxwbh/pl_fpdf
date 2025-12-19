--------------------------------------------------------------------------------
-- Package Body: PL_FPDF_BOLETO
-- Description: Boleto Bancário (Brazilian Bank Slip) utility functions
-- Author: Maxwell Oliveira (@maxwbh)
-- Date: 2025-12-18
-- Version: 1.0.0
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY PL_FPDF_BOLETO AS

/*******************************************************************************
* Function: CalculateFatorVencimento
* Description: Calculates due date factor for Boleto (days since 1997-10-07)
*******************************************************************************/
FUNCTION CalculateFatorVencimento(
  p_data DATE
) RETURN VARCHAR2 DETERMINISTIC IS
  l_base_date CONSTANT DATE := TO_DATE('1997-10-07', 'YYYY-MM-DD');
  l_days PLS_INTEGER;
BEGIN
  IF p_data IS NULL THEN
    RAISE_APPLICATION_ERROR(-20802, 'Due date cannot be NULL');
  END IF;

  -- Calculate days since base date
  l_days := TRUNC(p_data) - TRUNC(l_base_date);

  IF l_days < 0 THEN
    RAISE_APPLICATION_ERROR(-20802,
      'Due date cannot be before 1997-10-07');
  END IF;

  IF l_days > 9999 THEN
    RAISE_APPLICATION_ERROR(-20802,
      'Due date too far in future (max factor 9999)');
  END IF;

  RETURN LPAD(TO_CHAR(l_days), 4, '0');

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20899 AND -20800 THEN
      RAISE;  -- Re-raise our own errors
    ELSE
      RAISE_APPLICATION_ERROR(-20802, 'Failed to calculate due date factor: ' || SQLERRM);
    END IF;
END CalculateFatorVencimento;

/*******************************************************************************
* Function: CalculateDVBoleto
* Description: Calculates check digit for Boleto barcode (módulo 11)
*******************************************************************************/
FUNCTION CalculateDVBoleto(
  p_codigo VARCHAR2
) RETURN CHAR DETERMINISTIC IS
  l_sum PLS_INTEGER := 0;
  l_multiplier PLS_INTEGER := 2;
  l_digit CHAR(1);
  l_remainder PLS_INTEGER;
  l_i PLS_INTEGER;
BEGIN
  IF p_codigo IS NULL OR LENGTH(p_codigo) != 43 THEN
    RAISE_APPLICATION_ERROR(-20803,
      'Invalid code length for DV calculation (must be 43 characters)');
  END IF;

  -- Módulo 11 calculation (from right to left)
  FOR l_i IN REVERSE 1..LENGTH(p_codigo) LOOP
    l_digit := SUBSTR(p_codigo, l_i, 1);

    IF NOT REGEXP_LIKE(l_digit, '[0-9]') THEN
      RAISE_APPLICATION_ERROR(-20803,
        'Invalid character in barcode: ' || l_digit);
    END IF;

    l_sum := l_sum + (TO_NUMBER(l_digit) * l_multiplier);

    l_multiplier := l_multiplier + 1;
    IF l_multiplier > 9 THEN
      l_multiplier := 2;
    END IF;
  END LOOP;

  -- Calculate remainder
  l_remainder := MOD(l_sum, 11);

  -- DV = 11 - remainder
  -- Special cases: if DV = 0, 10, or 11, use '1'
  IF l_remainder IN (0, 1, 10) THEN
    RETURN '1';
  ELSE
    RETURN TO_CHAR(11 - l_remainder);
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20899 AND -20800 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20803, 'Failed to calculate check digit: ' || SQLERRM);
    END IF;
END CalculateDVBoleto;

/*******************************************************************************
* Function: ValidateCodigoBarras
* Description: Validates a 44-position Boleto barcode
*******************************************************************************/
FUNCTION ValidateCodigoBarras(
  p_codigo VARCHAR2
) RETURN BOOLEAN DETERMINISTIC IS
  l_dv_calculated CHAR(1);
  l_dv_in_code CHAR(1);
  l_code_without_dv VARCHAR2(43);
BEGIN
  -- Check length
  IF p_codigo IS NULL OR LENGTH(p_codigo) != 44 THEN
    RETURN FALSE;
  END IF;

  -- Check if all numeric
  IF NOT REGEXP_LIKE(p_codigo, '^[0-9]{44}$') THEN
    RETURN FALSE;
  END IF;

  -- Extract DV (position 5)
  l_dv_in_code := SUBSTR(p_codigo, 5, 1);

  -- Build code without DV (positions 1-4 + 6-44)
  l_code_without_dv := SUBSTR(p_codigo, 1, 4) || SUBSTR(p_codigo, 6, 39);

  -- Calculate expected DV
  l_dv_calculated := CalculateDVBoleto(l_code_without_dv);

  -- Compare
  RETURN l_dv_calculated = l_dv_in_code;

EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END ValidateCodigoBarras;

/*******************************************************************************
* Function: GetCodigoBarras
* Description: Generates 44-position Boleto barcode
*******************************************************************************/
FUNCTION GetCodigoBarras(
  p_boleto_data JSON_OBJECT_T
) RETURN VARCHAR2 IS
  l_banco VARCHAR2(3);
  l_moeda VARCHAR2(1);
  l_fator VARCHAR2(4);
  l_valor VARCHAR2(10);
  l_campo_livre VARCHAR2(25);
  l_codigo_sem_dv VARCHAR2(43);
  l_dv CHAR(1);
  l_codigo_completo VARCHAR2(44);
  l_vencimento DATE;
  l_valor_num NUMBER;
BEGIN
  -- Validate and get required fields
  IF NOT p_boleto_data.has('banco') THEN
    RAISE_APPLICATION_ERROR(-20801, 'Bank code is required (banco field)');
  END IF;

  IF NOT p_boleto_data.has('vencimento') THEN
    RAISE_APPLICATION_ERROR(-20802, 'Due date is required (vencimento field)');
  END IF;

  IF NOT p_boleto_data.has('valor') THEN
    RAISE_APPLICATION_ERROR(-20801, 'Amount is required (valor field)');
  END IF;

  IF NOT p_boleto_data.has('campoLivre') THEN
    RAISE_APPLICATION_ERROR(-20801, 'Free field is required (campoLivre field)');
  END IF;

  -- Get values
  l_banco := LPAD(p_boleto_data.get_String('banco'), 3, '0');

  IF p_boleto_data.has('moeda') THEN
    l_moeda := p_boleto_data.get_String('moeda');
  ELSE
    l_moeda := '9';  -- Default: Real
  END IF;

  -- Get vencimento (can be string or date)
  BEGIN
    l_vencimento := TO_DATE(p_boleto_data.get_String('vencimento'), 'YYYY-MM-DD');
  EXCEPTION
    WHEN OTHERS THEN
      -- Try as date type
      l_vencimento := p_boleto_data.get_Date('vencimento');
  END;

  l_valor_num := p_boleto_data.get_Number('valor');
  l_campo_livre := p_boleto_data.get_String('campoLivre');

  -- Validate lengths
  IF LENGTH(l_banco) != 3 THEN
    RAISE_APPLICATION_ERROR(-20801, 'Bank code must be 3 digits');
  END IF;

  IF LENGTH(l_campo_livre) != 25 THEN
    RAISE_APPLICATION_ERROR(-20801,
      'Free field must be 25 digits, got ' || LENGTH(l_campo_livre));
  END IF;

  -- Calculate fator vencimento
  l_fator := CalculateFatorVencimento(l_vencimento);

  -- Format valor (10 digits, no decimal point)
  l_valor := LPAD(TO_CHAR(TRUNC(l_valor_num * 100)), 10, '0');

  -- Build code without DV (positions 1-4, 6-44)
  -- Structure: BBBMxxxxFFFFVVVVVVVVVVCCCCCCCCCCCCCCCCCCCCCCCCC
  -- B=Bank, M=Currency, F=Factor, V=Value, C=Free field
  -- Position 5 (DV) will be inserted after calculation

  l_codigo_sem_dv := l_banco || l_moeda || l_fator || l_valor || l_campo_livre;

  IF LENGTH(l_codigo_sem_dv) != 43 THEN
    RAISE_APPLICATION_ERROR(-20801,
      'Internal error: code length is ' || LENGTH(l_codigo_sem_dv) || ' instead of 43');
  END IF;

  -- Calculate DV
  l_dv := CalculateDVBoleto(l_codigo_sem_dv);

  -- Insert DV at position 5
  l_codigo_completo := SUBSTR(l_codigo_sem_dv, 1, 4) || l_dv || SUBSTR(l_codigo_sem_dv, 5, 39);

  RETURN l_codigo_completo;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20899 AND -20800 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20801, 'Error generating barcode: ' || SQLERRM);
    END IF;
END GetCodigoBarras;

/*******************************************************************************
* Function: GetLinhaDigitavel
* Description: Generates 47-digit formatted linha digitável from Boleto data
*******************************************************************************/
FUNCTION GetLinhaDigitavel(
  p_boleto_data JSON_OBJECT_T
) RETURN VARCHAR2 IS
  l_codigo VARCHAR2(44);
  l_campo1 VARCHAR2(10);
  l_campo2 VARCHAR2(11);
  l_campo3 VARCHAR2(11);
  l_campo4 VARCHAR2(1);
  l_campo5 VARCHAR2(14);
  l_linha VARCHAR2(54);

  -- Calculate DV módulo 10 for linha digitável fields
  FUNCTION calc_dv_mod10(p_campo VARCHAR2) RETURN CHAR IS
    l_sum PLS_INTEGER := 0;
    l_digit PLS_INTEGER;
    l_mult PLS_INTEGER := 2;
    l_prod PLS_INTEGER;
  BEGIN
    FOR l_i IN REVERSE 1..LENGTH(p_campo) LOOP
      l_digit := TO_NUMBER(SUBSTR(p_campo, l_i, 1));
      l_prod := l_digit * l_mult;

      -- If product >= 10, sum digits
      IF l_prod >= 10 THEN
        l_sum := l_sum + TRUNC(l_prod / 10) + MOD(l_prod, 10);
      ELSE
        l_sum := l_sum + l_prod;
      END IF;

      l_mult := CASE l_mult WHEN 2 THEN 1 ELSE 2 END;
    END LOOP;

    RETURN TO_CHAR(MOD(10 - MOD(l_sum, 10), 10));
  END;

BEGIN
  -- Generate barcode first
  l_codigo := GetCodigoBarras(p_boleto_data);

  -- Build linha digitável from barcode
  -- Structure: AAABC.CCCCX DDDDD.DDDDDDY EEEEE.EEEEEZ K UUUUVVVVVVVVVV

  -- Campo 1: Positions 1-4, 20-24 of barcode + DV
  l_campo1 := SUBSTR(l_codigo, 1, 4) || SUBSTR(l_codigo, 20, 5);
  l_campo1 := l_campo1 || calc_dv_mod10(l_campo1);

  -- Campo 2: Positions 25-34 of barcode + DV
  l_campo2 := SUBSTR(l_codigo, 25, 10);
  l_campo2 := l_campo2 || calc_dv_mod10(l_campo2);

  -- Campo 3: Positions 35-44 of barcode + DV
  l_campo3 := SUBSTR(l_codigo, 35, 10);
  l_campo3 := l_campo3 || calc_dv_mod10(l_campo3);

  -- Campo 4: Position 5 of barcode (main DV)
  l_campo4 := SUBSTR(l_codigo, 5, 1);

  -- Campo 5: Positions 6-19 of barcode (factor + value)
  l_campo5 := SUBSTR(l_codigo, 6, 14);

  -- Format linha digitável with dots and spaces
  l_linha := SUBSTR(l_campo1, 1, 5) || '.' || SUBSTR(l_campo1, 6, 5) || ' ' ||
             SUBSTR(l_campo2, 1, 5) || '.' || SUBSTR(l_campo2, 6, 6) || ' ' ||
             SUBSTR(l_campo3, 1, 5) || '.' || SUBSTR(l_campo3, 6, 6) || ' ' ||
             l_campo4 || ' ' ||
             l_campo5;

  RETURN l_linha;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20801, 'Error generating linha digitável: ' || SQLERRM);
END GetLinhaDigitavel;

/*******************************************************************************
* Function: ParseLinhaDigitavel
* Description: Extracts barcode from linha digitável
*******************************************************************************/
FUNCTION ParseLinhaDigitavel(
  p_linha VARCHAR2
) RETURN VARCHAR2 IS
  l_linha_clean VARCHAR2(100);
  l_campo1 VARCHAR2(10);
  l_campo2 VARCHAR2(11);
  l_campo3 VARCHAR2(11);
  l_campo4 VARCHAR2(1);
  l_campo5 VARCHAR2(14);
  l_barcode VARCHAR2(44);

  -- Calculate DV módulo 10 for validation
  FUNCTION calc_dv_mod10(p_campo VARCHAR2) RETURN CHAR IS
    l_sum PLS_INTEGER := 0;
    l_digit PLS_INTEGER;
    l_mult PLS_INTEGER := 2;
    l_prod PLS_INTEGER;
  BEGIN
    FOR l_i IN REVERSE 1..LENGTH(p_campo) LOOP
      l_digit := TO_NUMBER(SUBSTR(p_campo, l_i, 1));
      l_prod := l_digit * l_mult;
      IF l_prod >= 10 THEN
        l_sum := l_sum + TRUNC(l_prod / 10) + MOD(l_prod, 10);
      ELSE
        l_sum := l_sum + l_prod;
      END IF;
      l_mult := CASE l_mult WHEN 2 THEN 1 ELSE 2 END;
    END LOOP;
    RETURN TO_CHAR(MOD(10 - MOD(l_sum, 10), 10));
  END;

BEGIN
  -- Remove formatting (dots, spaces)
  l_linha_clean := REGEXP_REPLACE(p_linha, '[^0-9]', '');

  -- Must have exactly 47 digits
  IF LENGTH(l_linha_clean) != 47 THEN
    RAISE_APPLICATION_ERROR(-20803,
      'Invalid linha digitável length: ' || LENGTH(l_linha_clean) || ' (expected 47)');
  END IF;

  -- Extract fields
  l_campo1 := SUBSTR(l_linha_clean, 1, 10);   -- 9 digits + 1 DV
  l_campo2 := SUBSTR(l_linha_clean, 11, 11);  -- 10 digits + 1 DV
  l_campo3 := SUBSTR(l_linha_clean, 22, 11);  -- 10 digits + 1 DV
  l_campo4 := SUBSTR(l_linha_clean, 33, 1);   -- Main DV
  l_campo5 := SUBSTR(l_linha_clean, 34, 14);  -- Factor + Value

  -- Validate check digits
  IF SUBSTR(l_campo1, 10, 1) != calc_dv_mod10(SUBSTR(l_campo1, 1, 9)) THEN
    RAISE_APPLICATION_ERROR(-20803, 'Invalid check digit in field 1');
  END IF;

  IF SUBSTR(l_campo2, 11, 1) != calc_dv_mod10(SUBSTR(l_campo2, 1, 10)) THEN
    RAISE_APPLICATION_ERROR(-20803, 'Invalid check digit in field 2');
  END IF;

  IF SUBSTR(l_campo3, 11, 1) != calc_dv_mod10(SUBSTR(l_campo3, 1, 10)) THEN
    RAISE_APPLICATION_ERROR(-20803, 'Invalid check digit in field 3');
  END IF;

  -- Reconstruct barcode (44 positions)
  -- Positions: 1-4 from campo1, 5 from campo4, 6-19 from campo5,
  --            20-24 from campo1, 25-34 from campo2, 35-44 from campo3
  l_barcode := SUBSTR(l_campo1, 1, 4) ||           -- Bank + Currency
               l_campo4 ||                          -- DV
               l_campo5 ||                          -- Factor + Value
               SUBSTR(l_campo1, 5, 5) ||            -- Free field start
               SUBSTR(l_campo2, 1, 10) ||           -- Free field middle
               SUBSTR(l_campo3, 1, 10);             -- Free field end

  -- Validate reconstructed barcode
  IF NOT ValidateCodigoBarras(l_barcode) THEN
    RAISE_APPLICATION_ERROR(-20803, 'Reconstructed barcode failed validation');
  END IF;

  RETURN l_barcode;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20899 AND -20800 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20803, 'Error parsing linha digitável: ' || SQLERRM);
    END IF;
END ParseLinhaDigitavel;

--------------------------------------------------------------------------------
-- PDF Rendering Procedures
--------------------------------------------------------------------------------

/*******************************************************************************
* Procedure: AddBarcodeBoleto
* Description: Adds a Boleto barcode (ITF14) to the current PDF page
*******************************************************************************/
PROCEDURE AddBarcodeBoleto(
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_boleto_data JSON_OBJECT_T
) IS
  l_codigo VARCHAR2(44);
BEGIN
  -- Validate parameters
  IF p_x < 0 OR p_y < 0 THEN
    RAISE_APPLICATION_ERROR(-20803, 'Position cannot be negative');
  END IF;

  IF p_width < 100 OR p_height < 13 THEN
    RAISE_APPLICATION_ERROR(-20804,
      'Boleto barcode dimensions too small (min width=100mm, height=13mm)');
  END IF;

  -- Generate barcode using internal function
  l_codigo := GetCodigoBarras(p_boleto_data);

  -- Render using PL_FPDF generic barcode function (ITF14)
  PL_FPDF.AddBarcode(p_x, p_y, p_width, p_height, l_codigo, 'ITF14', FALSE);

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END AddBarcodeBoleto;

/*******************************************************************************
* Procedure: AddBarcodeJSON
* Description: Adds a barcode to PDF from JSON configuration
*******************************************************************************/
PROCEDURE AddBarcodeJSON(
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_config JSON_OBJECT_T
) IS
  l_type VARCHAR2(20);
  l_code VARCHAR2(4000);
  l_boleto_data JSON_OBJECT_T;
  l_show_text BOOLEAN;
BEGIN
  -- Get type
  IF NOT p_config.has('type') THEN
    RAISE_APPLICATION_ERROR(-20805, 'Barcode type is required (type field)');
  END IF;

  l_type := UPPER(p_config.get_String('type'));

  -- Get showText (optional, default true)
  IF p_config.has('showText') THEN
    l_show_text := p_config.get_Boolean('showText');
  ELSE
    l_show_text := TRUE;
  END IF;

  -- Handle based on type
  IF l_type = 'BOLETO' THEN
    IF NOT p_config.has('boletoData') THEN
      RAISE_APPLICATION_ERROR(-20805, 'Boleto data is required (boletoData field) for BOLETO type');
    END IF;
    l_boleto_data := TREAT(p_config.get('boletoData') AS JSON_OBJECT_T);
    AddBarcodeBoleto(p_x, p_y, p_width, p_height, l_boleto_data);
  ELSE
    -- Generic barcode types (ITF14, CODE128, etc.)
    IF NOT p_config.has('code') THEN
      RAISE_APPLICATION_ERROR(-20805,
        'Code is required (code field) for ' || l_type || ' barcode');
    END IF;
    l_code := p_config.get_String('code');
    PL_FPDF.AddBarcode(p_x, p_y, p_width, p_height, l_code, l_type, l_show_text);
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END AddBarcodeJSON;

END PL_FPDF_BOLETO;
/
