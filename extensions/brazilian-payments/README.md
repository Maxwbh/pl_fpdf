# Brazilian Payment Systems Extension for PL_FPDF

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2F23c-red.svg)
![License](https://img.shields.io/badge/license-GPL%20v2-green.svg)

> **Optional extension for PL_FPDF - Brazilian PIX and Boleto Bancário support**

[**Português (Brasil)**](README_PT_BR.md)

---

## ⚠️ Important Notice

This is an **optional extension** for PL_FPDF and is **NOT part of the official PL_FPDF project**.

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
- Interbank 2 of 5 (ITF-14) barcode
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

### Test Coverage

| Package | Tests | Coverage |
|---------|-------|----------|
| PL_FPDF_PIX | 24 | >85% |
| PL_FPDF_BOLETO | 24 | >85% |
| Integration | 10 | >80% |
| **Total** | **58** | **>83%** |

---

## 📚 API Reference

### PL_FPDF_PIX Functions

```sql
-- Generate PIX EMV payload string
FUNCTION GetPixPayload(p_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Add PIX QR Code to current PDF page
PROCEDURE AddQRCodePIX(
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_data JSON_OBJECT_T
);

-- Validate PIX key format
FUNCTION ValidatePixKey(
  p_key VARCHAR2,
  p_type VARCHAR2
) RETURN BOOLEAN;
```

### PL_FPDF_BOLETO Functions

```sql
-- Generate linha digitável (47 digits)
FUNCTION GetLinhaDigitavel(p_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Generate barcode numeric string
FUNCTION GetCodigoBarras(p_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Add Boleto barcode to current PDF page
PROCEDURE AddBarcodeBoleto(
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_data JSON_OBJECT_T
);

-- Calculate fator de vencimento
FUNCTION CalcularFatorVencimento(p_date DATE) RETURN NUMBER;
```

---

## 🔍 Standards Compliance

### PIX (BCB Standards)
- **EMV® QRCode Specification**: Merchant-Presented Mode
- **Brazilian Central Bank**: Manual do PIX v2.x
- **CRC-16/CCITT-FALSE**: Polynomial 0x1021

### Boleto Bancário (FEBRABAN)
- **FEBRABAN**: Specs Layout Padrão Boleto
- **Código de Barras**: ITF-14 (Interbank 2 of 5)
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

This extension is distributed under the **GNU General Public License v2**, same as PL_FPDF core.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

---

## 🔗 Links

- **PL_FPDF Core Project**: [GitHub Repository](https://github.com/maxwbh/pl_fpdf)
- **Brazilian Central Bank (PIX)**: https://www.bcb.gov.br/estabilidadefinanceira/pix
- **FEBRABAN (Boleto)**: https://portal.febraban.org.br/

---

**Last Updated**: December 19, 2025
**Version**: 1.0.0
**Status**: Production Ready ✅
