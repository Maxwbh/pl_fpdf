# Extensão de Sistemas de Pagamento Brasileiros para PL_FPDF

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Oracle](https://img.shields.io/badge/Oracle-19c%2B-red.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> **Extensão opcional para PL_FPDF - Suporte a PIX e Boleto Bancário**

> [!IMPORTANT]
> **Fora do escopo do PL_FPDF, e fora do CI dele.**
> O PL_FPDF é uma biblioteca de **desenho de PDF**: ela posiciona texto, formas,
> QR Code e código de barras. **Regra de cobrança** — montar o código de barras
> a partir de banco, vencimento, valor e campo livre, dígito verificador, fator
> de vencimento, as regras de cada banco — é assunto de um projeto próprio.
>
> Esta extensão continua aqui, mas **não é instalada nem exercitada pela suíte**
> do PL_FPDF, e deve migrar para um projeto separado. Ela tem as suas próprias
> três suítes, em `tests/`, que se rodam à mão: passaram inteiras (58 testes) no
> Oracle 26ai em 07/11/2026.
> Para o **layout** de um boleto, que é o que a biblioteca faz, veja
> [`examples/boleto.sql`](../../examples/boleto.sql).

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
- Código de barras Interleaved 2 of 5 (ITF), 44 dígitos
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

### O que os testes cobrem

| Suíte | Testes | Última rodada |
|-------|--------|---------------|
| `validate_pix_package.sql` | 24 | 24/24 — Oracle 26ai, 07/11/2026 |
| `validate_boleto_package.sql` | 24 | 24/24 — Oracle 26ai, 07/11/2026 |
| `validate_pdf_integration.sql` | 10 | 10/10 — Oracle 26ai, 07/11/2026 |

Cobertura de linhas não é medida. Os scripts usam `SET` e `PROMPT`: rode no
SQL\*Plus, no SQLcl ou na Command Window do PL/SQL Developer.

---

## 📚 Referência da API

### Funções PL_FPDF_PIX

```sql
-- Validar o formato de uma chave PIX ('CPF', 'CNPJ', 'EMAIL', 'PHONE', 'RANDOM')
FUNCTION ValidatePixKey(p_key VARCHAR2, p_type VARCHAR2) RETURN BOOLEAN;

-- CRC16-CCITT (0x1021) de um payload, em 4 dígitos hexadecimais
FUNCTION CalculateCRC16(p_payload VARCHAR2) RETURN VARCHAR2;

-- Montar o payload EMV do PIX (o "copia e cola")
FUNCTION GetPixPayload(p_pix_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Formatar a chave para exibição
FUNCTION FormatPixKey(p_key VARCHAR2, p_type VARCHAR2) RETURN VARCHAR2;

-- Desenhar o QR Code PIX na página atual
PROCEDURE AddQRCodePIX(p_x NUMBER, p_y NUMBER, p_size NUMBER, p_pix_data JSON_OBJECT_T);

-- Desenhar QR Code a partir de uma configuração JSON
PROCEDURE AddQRCodeJSON(p_x NUMBER, p_y NUMBER, p_size NUMBER, p_config JSON_OBJECT_T);
```

### Funções PL_FPDF_BOLETO

```sql
-- Fator de vencimento, em 4 dígitos: dias desde 07/10/1997, e de 22/02/2025
-- em diante recomeçando em 1000 (regra da FEBRABAN)
FUNCTION CalculateFatorVencimento(p_data DATE) RETURN VARCHAR2;

-- Dígito verificador geral do código de barras (módulo 11)
FUNCTION CalculateDVBoleto(p_codigo VARCHAR2) RETURN CHAR;

-- Conferir um código de barras de 44 posições
FUNCTION ValidateCodigoBarras(p_codigo VARCHAR2) RETURN BOOLEAN;

-- Montar o código de barras (44 posições)
FUNCTION GetCodigoBarras(p_boleto_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Montar a linha digitável (47 dígitos, formatada)
FUNCTION GetLinhaDigitavel(p_boleto_data JSON_OBJECT_T) RETURN VARCHAR2;

-- Linha digitável de volta para o código de barras
FUNCTION ParseLinhaDigitavel(p_linha VARCHAR2) RETURN VARCHAR2;

-- Desenhar o código de barras do boleto na página atual
PROCEDURE AddBarcodeBoleto(p_x NUMBER, p_y NUMBER, p_width NUMBER, p_height NUMBER,
                           p_boleto_data JSON_OBJECT_T);

-- Desenhar código de barras a partir de uma configuração JSON
PROCEDURE AddBarcodeJSON(p_x NUMBER, p_y NUMBER, p_width NUMBER, p_height NUMBER,
                         p_config JSON_OBJECT_T);
```

As assinaturas acima são as de `packages/*.pks`; os parâmetros JSON aceitos
estão documentados lá, em cada função.

---

## 🔍 Padrões implementados

A extensão **implementa os algoritmos** destes padrões, e os testes conferem o
cálculo — o código de barras, o DV e a linha digitável também foram refeitos
por fora e lidos de volta com um decodificador independente. Isso **não é
homologação**: nenhum banco nem o BCB certificou esta extensão. Antes de
produção, homologue o boleto com o seu banco e o PIX com o seu PSP.

### PIX (Padrões BCB)
- **Especificação EMV® QRCode**: Merchant-Presented Mode
- **Banco Central do Brasil**: Manual do PIX v2.x
- **CRC-16/CCITT-FALSE**: Polinômio 0x1021

### Boleto Bancário (FEBRABAN)
- **FEBRABAN**: Especificações Layout Padrão Boleto
- **Código de Barras**: Interleaved 2 of 5 (ITF), 44 dígitos — não confundir com o ITF-14, que é o código de 14 dígitos de embalagens
- **Fator de vencimento**: 4 dígitos, recomeçando em 1000 a partir de 22/02/2025
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

Licença **MIT**, a mesma do repositório — veja o [`LICENSE`](../../LICENSE) na
raiz. (Versões antigas deste texto diziam GPL v2: era a licença do porte de
2017, antes de o projeto passar para MIT.)

O software é fornecido "no estado em que se encontra", sem garantia de nenhum
tipo — os termos completos estão no `LICENSE`.

---

## 🔗 Links

- **Projeto Core PL_FPDF**: [Repositório GitHub](https://github.com/maxwbh/pl_fpdf)
- **Banco Central do Brasil (PIX)**: https://www.bcb.gov.br/estabilidadefinanceira/pix
- **FEBRABAN (Boleto)**: https://portal.febraban.org.br/

---

**Última Atualização**: 19 de dezembro de 2025
**Versão**: 1.0.0
**Status**: Pronto para Produção ✅
