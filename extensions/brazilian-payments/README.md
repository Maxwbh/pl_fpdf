# Brazilian Payment Systems Extension for PL_FPDF

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2B-red.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> **Optional extension for PL_FPDF - Brazilian PIX and Boleto Bancário support**

> [!IMPORTANT]
> **Out of scope for PL_FPDF, and outside its CI.**
> PL_FPDF is a **PDF drawing** library: it places text, shapes, QR codes and
> barcodes. **Billing rules** — building the barcode from bank, due date,
> amount and free field, check digits, due-date factor, each bank's own rules —
> belong to a project of their own.
>
> This extension stays here, but it is **neither installed nor exercised by the
> PL_FPDF suite**, and should move to a separate project. It has its own three
> suites in `tests/`, run by hand: they passed in full (58 tests) on Oracle 26ai
> on 2026-11-07.
> For the **layout** of a bank slip, which is what the library does, see
> [`examples/boleto.sql`](../../examples/boleto.sql).

[**Português (Brasil)**](README_PT_BR.md)

---

## ⚠️ Important Notice

This is an **optional extension**. It lives in this repository and has the
same author, but sits **outside the PL_FPDF core package**:

| | Core package (`PL_FPDF`, `PL_FPDF_UTIL`) | This extension |
|---|---|---|
| Installer | `dist/pl_fpdf_install.sql` | separate: `deploy.sql` |
| Tests | in CI and in the runs against Oracle | its own suites in `tests/`, run by hand |
| Support | per [SECURITY.md](../../SECURITY.md) | best effort; issues are welcome |
| Future | stays here | should move to a project of its own |

These packages provide Brazilian-specific payment functionality:
- **PIX QR Codes** (EMV QR Code Merchant-Presented Mode)
- **Boleto Bancário** (FEBRABAN standard)

---

## 📦 What's Included

### PL_FPDF_PIX Package
Generate PIX QR Codes compliant with Brazilian Central Bank standards:
- All key types: CPF, CNPJ, Email, Phone, Random (EVP)
- Static and dynamic PIX
- CRC16-CCITT validation
- EMV QR Code standard compliance

### PL_FPDF_BOLETO Package
Generate Boleto Bancário barcodes and payment slips:
- Interleaved 2 of 5 (ITF) barcode, 44 digits
- Linha digitável (47-digit formatted line)
- Módulo 11 check digit
- Fator de vencimento calculation
- FEBRABAN standard compliance

---

## 📥 Installation

### Prerequisites
1. Install **PL_FPDF core package first** (from main project)
2. Ensure PL_FPDF is working correctly

### Install Extension

```bash
cd extensions/brazilian-payments
sqlplus user/password@database @deploy.sql
```

Or manually:

```sql
-- Install PIX package
@packages/PL_FPDF_PIX.pks
@packages/PL_FPDF_PIX.pkb

-- Install Boleto package
@packages/PL_FPDF_BOLETO.pks
@packages/PL_FPDF_BOLETO.pkb

-- Verify installation
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('PL_FPDF_PIX', 'PL_FPDF_BOLETO');
```

---

## 🚀 Quick Start

### PIX QR Code

```sql
DECLARE
  l_pix_data JSON_OBJECT_T;
  l_pdf BLOB;
BEGIN
  -- Initialize PDF
  PL_FPDF.Init();
  PL_FPDF.AddPage();

  -- Configure PIX data
  l_pix_data := JSON_OBJECT_T();
  l_pix_data.put('pixKey', 'payment@mystore.com');
  l_pix_data.put('pixKeyType', 'EMAIL');
  l_pix_data.put('merchantName', 'My Store');
  l_pix_data.put('merchantCity', 'Sao Paulo');
  l_pix_data.put('amount', 150.00);
  l_pix_data.put('txid', 'ORDER12345');

  -- Add QR Code to PDF
  PL_FPDF_PIX.AddQRCodePIX(50, 50, 50, l_pix_data);

  -- Add copy-paste code
  PL_FPDF.SetFont('Courier', '', 8);
  PL_FPDF.Text(50, 110, PL_FPDF_PIX.GetPixPayload(l_pix_data));

  -- Generate PDF
  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
/
```

### Boleto Bancário

```sql
DECLARE
  l_boleto_data JSON_OBJECT_T;
  l_pdf BLOB;
BEGIN
  -- Initialize PDF
  PL_FPDF.Init();
  PL_FPDF.AddPage();

  -- Configure Boleto data
  l_boleto_data := JSON_OBJECT_T();
  l_boleto_data.put('banco', '001');  -- Banco do Brasil
  l_boleto_data.put('moeda', '9');
  l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
  l_boleto_data.put('valor', 1500.00);
  l_boleto_data.put('campoLivre', '1234567890123456789012345');

  -- Add linha digitável
  PL_FPDF.SetFont('Arial', 'B', 12);
  PL_FPDF.Text(20, 190, PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data));

  -- Add barcode
  PL_FPDF_BOLETO.AddBarcodeBoleto(20, 200, 170, 15, l_boleto_data);

  -- Generate PDF
  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
/
```

---

## 🧪 Testing

### Run Validation Tests

```bash
cd tests
sqlplus user/pass@db @validate_pix_package.sql
sqlplus user/pass@db @validate_boleto_package.sql
sqlplus user/pass@db @validate_pdf_integration.sql
```

### What the tests cover

| Suite | Tests | Last run |
|-------|-------|----------|
| `validate_pix_package.sql` | 24 | 24/24 — Oracle 26ai, 2026-11-07 |
| `validate_boleto_package.sql` | 24 | 24/24 — Oracle 26ai, 2026-11-07 |
| `validate_pdf_integration.sql` | 10 | 10/10 — Oracle 26ai, 2026-11-07 |

Line coverage is not measured. The scripts use `SET` and `PROMPT`: run them in
SQL\*Plus, SQLcl or the PL/SQL Developer Command Window.

---

## 📚 API Reference

### PL_FPDF_PIX Functions

```sql
-- Validate a PIX key format ('CPF', 'CNPJ', 'EMAIL', 'PHONE', 'RANDOM')
FUNCTION ValidatePixKey(p_key VARCHAR2, p_type VARCHAR2) RETURN BOOLEAN;

-- CRC16-CCITT (0x1021) of a payload, as 4 hex digits
FUNCTION CalculateCRC16(p_payload VARCHAR2) RETURN VARCHAR2;

-- Build the PIX EMV payload (the "copia e cola" string)
FUNCTION GetPixPayload(p_pix_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Format a key for display
FUNCTION FormatPixKey(p_key VARCHAR2, p_type VARCHAR2) RETURN VARCHAR2;

-- Draw the PIX QR Code on the current page
PROCEDURE AddQRCodePIX(p_x NUMBER, p_y NUMBER, p_size NUMBER, p_pix_data JSON_OBJECT_T);

-- Draw a QR Code from a JSON configuration
PROCEDURE AddQRCodeJSON(p_x NUMBER, p_y NUMBER, p_size NUMBER, p_config JSON_OBJECT_T);
```

### PL_FPDF_BOLETO Functions

```sql
-- Due-date factor, 4 digits: days since 1997-10-07, restarting at 1000 from
-- 2025-02-22 on (FEBRABAN rule)
FUNCTION CalculateFatorVencimento(p_data DATE) RETURN VARCHAR2;

-- General check digit of the barcode (modulo 11)
FUNCTION CalculateDVBoleto(p_codigo VARCHAR2) RETURN CHAR;

-- Check a 44-position barcode
FUNCTION ValidateCodigoBarras(p_codigo VARCHAR2) RETURN BOOLEAN;

-- Build the barcode (44 positions)
FUNCTION GetCodigoBarras(p_boleto_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Build the linha digitável (47 digits, formatted)
FUNCTION GetLinhaDigitavel(p_boleto_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Linha digitável back to the barcode
FUNCTION ParseLinhaDigitavel(p_linha VARCHAR2) RETURN VARCHAR2;

-- Draw the boleto barcode on the current page
PROCEDURE AddBarcodeBoleto(p_x NUMBER, p_y NUMBER, p_width NUMBER, p_height NUMBER,
                           p_boleto_data JSON_OBJECT_T);

-- Draw a barcode from a JSON configuration
PROCEDURE AddBarcodeJSON(p_x NUMBER, p_y NUMBER, p_width NUMBER, p_height NUMBER,
                         p_config JSON_OBJECT_T);
```

The signatures above are the ones in `packages/*.pks`; the accepted JSON
fields are documented there, function by function.

---

## 🔍 Standards implemented

The extension **implements the algorithms** of these standards, and the tests
check the arithmetic — the barcode, check digit and linha digitável were also
recomputed independently and read back with an independent decoder. That is
**not certification**: no bank and not the BCB has certified this extension.
Before production, certify the boleto with your bank and PIX with your PSP.

### PIX (BCB Standards)
- **EMV® QRCode Specification**: Merchant-Presented Mode
- **Brazilian Central Bank**: Manual do PIX v2.x
- **CRC-16/CCITT-FALSE**: Polynomial 0x1021

### Boleto Bancário (FEBRABAN)
- **FEBRABAN**: Specs Layout Padrão Boleto
- **Barcode**: Interleaved 2 of 5 (ITF), 44 digits — not to be confused with ITF-14, the 14-digit packaging code
- **Due-date factor**: 4 digits, restarting at 1000 from 2025-02-22 on
- **Linha Digitável**: 47-digit format with check digits
- **Módulo 11**: Check digit calculation

---

## ⚠️ Important Notes

1. **Testing Required**: Always test in a development environment first
2. **Compliance**: Ensure your PIX keys and Boleto data comply with Brazilian regulations
3. **Validation**: Use provided validation tests before production deployment
4. **Updates**: Check for regulatory changes from BCB and FEBRABAN

---

## 🤝 Contributing

### Original Author
- **Maxwell da Silva Oliveira** (@maxwbh)
- **Email**: maxwbh@gmail.com
- **LinkedIn**: [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

### Contributions Welcome
- Bug reports
- Feature requests
- Compliance updates
- Documentation improvements

---

## 📄 License

**MIT** license, the same as the repository — see [`LICENSE`](../../LICENSE) at
the root. (Older versions of this text said GPL v2: that was the license of the
2017 port, before the project moved to MIT.)

The software is provided "as is", without warranty of any kind — the full terms
are in `LICENSE`.

---

## 🔗 Links

- **PL_FPDF Core Project**: [GitHub Repository](https://github.com/maxwbh/pl_fpdf)
- **Brazilian Central Bank (PIX)**: https://www.bcb.gov.br/estabilidadefinanceira/pix
- **FEBRABAN (Boleto)**: https://portal.febraban.org.br/

---

**Last Updated**: December 19, 2025
**Version**: 1.0.0
**Status**: Production Ready ✅
