# Extensão de Sistemas de Pagamento Brasileiros para PL_FPDF

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2F23c-red.svg)
![License](https://img.shields.io/badge/license-GPL%20v2-green.svg)

> **Extensão opcional para PL_FPDF - Suporte a PIX e Boleto Bancário**

[**English**](README.md)

---

## ⚠️ Aviso Importante

Esta é uma **extensão opcional** para PL_FPDF e **NÃO faz parte do projeto oficial PL_FPDF**.

Estes pacotes fornecem funcionalidade específica para pagamentos brasileiros:
- **QR Codes PIX** (EMV QR Code Merchant-Presented Mode)
- **Boleto Bancário** (padrão FEBRABAN)

---

## 📦 O que está Incluído

### Pacote PL_FPDF_PIX
Geração de QR Codes PIX em conformidade com os padrões do Banco Central do Brasil:
- Todos os tipos de chave: CPF, CNPJ, Email, Telefone, Aleatória (EVP)
- PIX estático e dinâmico
- Validação CRC16-CCITT
- Conformidade com padrão EMV QR Code

### Pacote PL_FPDF_BOLETO
Geração de códigos de barras e fichas de compensação de Boleto Bancário:
- Código de barras Interbancário 2 de 5 (ITF-14)
- Linha digitável (47 dígitos formatados)
- Dígito verificador Módulo 11
- Cálculo do fator de vencimento
- Conformidade com padrão FEBRABAN

---

## 📥 Instalação

### Pré-requisitos
1. Instale primeiro o **pacote core PL_FPDF** (do projeto principal)
2. Certifique-se de que o PL_FPDF está funcionando corretamente

### Instalar Extensão

```bash
cd extensions/brazilian-payments
sqlplus usuario/senha@banco @deploy.sql
```

Ou manualmente:

```sql
-- Instalar pacote PIX
@packages/PL_FPDF_PIX.pks
@packages/PL_FPDF_PIX.pkb

-- Instalar pacote Boleto
@packages/PL_FPDF_BOLETO.pks
@packages/PL_FPDF_BOLETO.pkb

-- Verificar instalação
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('PL_FPDF_PIX', 'PL_FPDF_BOLETO');
```

---

## 🚀 Início Rápido

### QR Code PIX

```sql
DECLARE
  l_pix_data JSON_OBJECT_T;
  l_pdf BLOB;
BEGIN
  -- Inicializar PDF
  PL_FPDF.Init();
  PL_FPDF.AddPage();

  -- Configurar dados do PIX
  l_pix_data := JSON_OBJECT_T();
  l_pix_data.put('pixKey', 'pagamento@minhaloja.com.br');
  l_pix_data.put('pixKeyType', 'EMAIL');
  l_pix_data.put('merchantName', 'Minha Loja');
  l_pix_data.put('merchantCity', 'Sao Paulo');
  l_pix_data.put('amount', 150.00);
  l_pix_data.put('txid', 'PEDIDO12345');

  -- Adicionar QR Code ao PDF
  PL_FPDF_PIX.AddQRCodePIX(50, 50, 50, l_pix_data);

  -- Adicionar código copia e cola
  PL_FPDF.SetFont('Courier', '', 8);
  PL_FPDF.Text(50, 110, PL_FPDF_PIX.GetPixPayload(l_pix_data));

  -- Gerar PDF
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
  -- Inicializar PDF
  PL_FPDF.Init();
  PL_FPDF.AddPage();

  -- Configurar dados do Boleto
  l_boleto_data := JSON_OBJECT_T();
  l_boleto_data.put('banco', '001');  -- Banco do Brasil
  l_boleto_data.put('moeda', '9');
  l_boleto_data.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
  l_boleto_data.put('valor', 1500.00);
  l_boleto_data.put('campoLivre', '1234567890123456789012345');

  -- Adicionar linha digitável
  PL_FPDF.SetFont('Arial', 'B', 12);
  PL_FPDF.Text(20, 190, PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto_data));

  -- Adicionar código de barras
  PL_FPDF_BOLETO.AddBarcodeBoleto(20, 200, 170, 15, l_boleto_data);

  -- Gerar PDF
  l_pdf := PL_FPDF.OutputBlob();
  PL_FPDF.Reset();
END;
/
```

---

## 🧪 Testes

### Executar Testes de Validação

```bash
cd tests
sqlplus usuario/senha@banco @validate_pix_package.sql
sqlplus usuario/senha@banco @validate_boleto_package.sql
sqlplus usuario/senha@banco @validate_pdf_integration.sql
```

### Cobertura de Testes

| Pacote | Testes | Cobertura |
|---------|-------|----------|
| PL_FPDF_PIX | 24 | >85% |
| PL_FPDF_BOLETO | 24 | >85% |
| Integração | 10 | >80% |
| **Total** | **58** | **>83%** |

---

## 📚 Referência da API

### Funções PL_FPDF_PIX

```sql
-- Gerar string de payload EMV do PIX
FUNCTION GetPixPayload(p_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Adicionar QR Code PIX à página atual do PDF
PROCEDURE AddQRCodePIX(
  p_x NUMBER,
  p_y NUMBER,
  p_size NUMBER,
  p_data JSON_OBJECT_T
);

-- Validar formato da chave PIX
FUNCTION ValidatePixKey(
  p_key VARCHAR2,
  p_type VARCHAR2
) RETURN BOOLEAN;
```

### Funções PL_FPDF_BOLETO

```sql
-- Gerar linha digitável (47 dígitos)
FUNCTION GetLinhaDigitavel(p_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Gerar string numérica do código de barras
FUNCTION GetCodigoBarras(p_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Adicionar código de barras do Boleto à página atual do PDF
PROCEDURE AddBarcodeBoleto(
  p_x NUMBER,
  p_y NUMBER,
  p_width NUMBER,
  p_height NUMBER,
  p_data JSON_OBJECT_T
);

-- Calcular fator de vencimento
FUNCTION CalcularFatorVencimento(p_date DATE) RETURN NUMBER;
```

---

## 🔍 Conformidade com Padrões

### PIX (Padrões BCB)
- **Especificação EMV® QRCode**: Merchant-Presented Mode
- **Banco Central do Brasil**: Manual do PIX v2.x
- **CRC-16/CCITT-FALSE**: Polinômio 0x1021

### Boleto Bancário (FEBRABAN)
- **FEBRABAN**: Especificações Layout Padrão Boleto
- **Código de Barras**: ITF-14 (Interbancário 2 de 5)
- **Linha Digitável**: Formato de 47 dígitos com dígitos verificadores
- **Módulo 11**: Cálculo do dígito verificador

---

## ⚠️ Notas Importantes

1. **Testes Obrigatórios**: Sempre teste em ambiente de desenvolvimento primeiro
2. **Conformidade**: Certifique-se de que suas chaves PIX e dados do Boleto estejam em conformidade com as regulamentações brasileiras
3. **Validação**: Use os testes de validação fornecidos antes da implantação em produção
4. **Atualizações**: Verifique mudanças regulatórias do BCB e FEBRABAN

---

## 🤝 Contribuindo

### Autor Original
- **Maxwell da Silva Oliveira** (@maxwbh)
- **Email**: maxwbh@gmail.com
- **LinkedIn**: [linkedin.com/in/maxwbh](https://linkedin.com/in/maxwbh)

### Contribuições São Bem-Vindas
- Relatórios de bugs
- Solicitações de recursos
- Atualizações de conformidade
- Melhorias na documentação

---

## 📄 Licença

Esta extensão é distribuída sob a **GNU General Public License v2**, a mesma do PL_FPDF core.

Este programa é distribuído na esperança de que seja útil, mas SEM QUALQUER GARANTIA; sem mesmo a garantia implícita de COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM PROPÓSITO ESPECÍFICO.

---

## 🔗 Links

- **Projeto Core PL_FPDF**: [Repositório GitHub](https://github.com/maxwbh/pl_fpdf)
- **Banco Central do Brasil (PIX)**: https://www.bcb.gov.br/estabilidadefinanceira/pix
- **FEBRABAN (Boleto)**: https://portal.febraban.org.br/

---

**Última Atualização**: 19 de dezembro de 2025
**Versão**: 1.0.0
**Status**: Pronto para Produção ✅
