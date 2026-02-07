# Guia de Validação - PL_FPDF Modernização Fase 3

## Arquitetura de Pacotes

```
┌─────────────────────────────────────────────────────────────┐
│                      ARQUITETURA                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐                                          │
│  │   PL_FPDF    │  ← Base independente                     │
│  │              │                                           │
│  │ • AddQRCode  │                                           │
│  │ • AddBarcode │                                           │
│  └──────┬───────┘                                           │
│         ↑                                                   │
│         │ usa                                               │
│    ┌────┴────────────────┐                                 │
│    │                     │                                  │
│ ┌──┴──────────┐   ┌─────┴──────────┐                      │
│ │ PL_FPDF_PIX │   │ PL_FPDF_BOLETO │                      │
│ │             │   │                │                       │
│ │ Utilitários:│   │  Utilitários:  │                      │
│ │ • ValidatePix│  │ • CalculateDV  │                      │
│ │ • GetPayload │   │ • GetCodigo   │                      │
│ │             │   │                │                       │
│ │ Renderização:│  │  Renderização: │                      │
│ │ • AddQRCode  │   │ • AddBarcode  │                      │
│ │   PIX        │   │   Boleto      │                      │
│ └─────────────┘   └────────────────┘                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Scripts de Validação

### 1. Validação de Pacotes Independentes

#### `validate_pix_package.sql`
Testa o pacote **PL_FPDF_PIX** de forma independente.

**24 testes divididos em 8 grupos:**
- Validação de chave PIX (CPF, CNPJ, Email, Phone, Random)
- Formatação de chaves PIX
- Cálculo CRC16-CCITT
- Geração de payload EMV QR Code

**Como executar:**
```sql
@validate_pix_package.sql
```

**Exemplo de uso independente:**
```sql
DECLARE
  l_pix JSON_OBJECT_T := JSON_OBJECT_T();
  l_payload VARCHAR2(32767);
BEGIN
  l_pix.put('pixKey', '12345678901');
  l_pix.put('pixKeyType', 'CPF');
  l_pix.put('merchantName', 'Minha Loja');
  l_pix.put('merchantCity', 'São Paulo');
  l_pix.put('amount', 150.00);

  l_payload := PL_FPDF_PIX.GetPixPayload(l_pix);
  DBMS_OUTPUT.PUT_LINE('Payload: ' || l_payload);
END;
```

#### `validate_boleto_package.sql`
Testa o pacote **PL_FPDF_BOLETO** de forma independente.

**24 testes divididos em 6 grupos:**
- Cálculo do fator de vencimento
- Cálculo do dígito verificador (módulo 11)
- Validação de código de barras
- Geração de código de barras (44 posições)
- Geração de linha digitável (47 dígitos)
- Parse de linha digitável

**Como executar:**
```sql
@validate_boleto_package.sql
```

**Exemplo de uso independente:**
```sql
DECLARE
  l_boleto JSON_OBJECT_T := JSON_OBJECT_T();
  l_codigo VARCHAR2(44);
  l_linha VARCHAR2(54);
BEGIN
  l_boleto.put('banco', '237');
  l_boleto.put('moeda', '9');
  l_boleto.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
  l_boleto.put('valor', 1500.00);
  l_boleto.put('campoLivre', '1234567890123456789012345');

  l_codigo := PL_FPDF_BOLETO.GetCodigoBarras(l_boleto);
  l_linha := PL_FPDF_BOLETO.GetLinhaDigitavel(l_boleto);

  DBMS_OUTPUT.PUT_LINE('Código: ' || l_codigo);
  DBMS_OUTPUT.PUT_LINE('Linha: ' || l_linha);
END;
```

### 2. Validação de Integração

#### `validate_pdf_integration.sql`
Testa a integração completa dos três pacotes.

**10 testes divididos em 4 grupos:**
1. **Independência de Pacotes** (3 testes)
   - PL_FPDF funciona sem PIX/BOLETO
   - PL_FPDF_PIX funciona independentemente
   - PL_FPDF_BOLETO funciona independentemente

2. **Integração PIX** (3 testes)
   - QR Code genérico no PDF
   - QR Code PIX no PDF
   - Múltiplos QR Codes PIX no mesmo PDF

3. **Integração Boleto** (2 testes)
   - Código de barras genérico no PDF
   - Código de barras Boleto no PDF

4. **Integração Completa** (2 testes)
   - PDF com PIX e Boleto na mesma página
   - PDF multi-página com PIX e Boleto em páginas diferentes

**Como executar:**
```sql
@validate_pdf_integration.sql
```

**Exemplo de uso integrado:**
```sql
DECLARE
  l_pix JSON_OBJECT_T := JSON_OBJECT_T();
  l_boleto JSON_OBJECT_T := JSON_OBJECT_T();
  l_pdf BLOB;
BEGIN
  -- Inicializar PDF
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Adicionar título
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Text(10, 10, 'Fatura #12345');

  -- Opção 1: PIX
  PL_FPDF.SetFont('Arial', '', 12);
  PL_FPDF.Text(10, 25, 'Opção 1: Pague com PIX');

  l_pix.put('pixKey', 'payment@store.com');
  l_pix.put('pixKeyType', 'EMAIL');
  l_pix.put('merchantName', 'Minha Loja');
  l_pix.put('merchantCity', 'São Paulo');
  l_pix.put('amount', 2500.00);

  PL_FPDF_PIX.AddQRCodePIX(10, 35, 50, l_pix);

  -- Opção 2: Boleto
  PL_FPDF.Text(10, 100, 'Opção 2: Pague com Boleto');

  l_boleto.put('banco', '341');
  l_boleto.put('moeda', '9');
  l_boleto.put('vencimento', TO_DATE('2025-12-31', 'YYYY-MM-DD'));
  l_boleto.put('valor', 2500.00);
  l_boleto.put('campoLivre', '9999999990000000001234567');

  PL_FPDF_BOLETO.AddBarcodeBoleto(10, 110, 180, 13, l_boleto);

  -- Gerar PDF
  l_pdf := PL_FPDF.OutputBlob();

  -- Salvar ou enviar PDF...
END;
```

### 3. Validação Legacy (Tarefas Anteriores)

#### `validate_task_3_7.sql` *(DEPRECATED)*
Script antigo que testava funções PIX através do PL_FPDF.
**Substituído por:** `validate_pix_package.sql`

#### `validate_task_3_8.sql` *(DEPRECATED)*
Script antigo que testava funções Boleto através do PL_FPDF.
**Substituído por:** `validate_boleto_package.sql`

## Ordem de Execução Recomendada

### Para validação completa:

1. **Compilar pacotes** (na ordem correta):
   ```sql
   @deploy_all.sql
   ```

2. **Validar pacotes independentes:**
   ```sql
   @validate_pix_package.sql
   @validate_boleto_package.sql
   ```

3. **Validar integração:**
   ```sql
   @validate_pdf_integration.sql
   ```

### Para desenvolvimento:

- Alterou **PL_FPDF_PIX**? Execute: `@validate_pix_package.sql`
- Alterou **PL_FPDF_BOLETO**? Execute: `@validate_boleto_package.sql`
- Alterou **PL_FPDF** base? Execute: `@validate_pdf_integration.sql`

## Dependências entre Pacotes

```
PL_FPDF (independente)
  └─ Não depende de nenhum outro pacote

PL_FPDF_PIX (depende de PL_FPDF)
  ├─ Funções independentes: ValidatePixKey, GetPixPayload, etc.
  └─ AddQRCodePIX() → chama PL_FPDF.AddQRCode()

PL_FPDF_BOLETO (depende de PL_FPDF)
  ├─ Funções independentes: GetCodigoBarras, GetLinhaDigitavel, etc.
  └─ AddBarcodeBoleto() → chama PL_FPDF.AddBarcode()
```

## Padrões e Especificações

### PIX (PL_FPDF_PIX)
- **Padrão:** EMV QR Code Merchant-Presented Mode
- **Regulamentação:** Banco Central do Brasil
- **Tipos de chave:** CPF, CNPJ, EMAIL, PHONE, RANDOM (EVP)
- **Checksum:** CRC16-CCITT

### Boleto (PL_FPDF_BOLETO)
- **Padrão:** FEBRABAN 44 posições
- **Código de barras:** Interbank 2 of 5 (ITF-14)
- **Dígito verificador:** Módulo 11
- **Fator vencimento:** Dias desde 07/10/1997
- **Linha digitável:** 47 dígitos formatados

## Compatibilidade

- **Oracle 19c:** Totalmente compatível
- **Oracle 23c:** Totalmente compatível
- **Oracle 21c+:** Usa funcionalidades nativas quando disponível

## Status da Implementação

✅ Fase 1: Funcionalidades básicas PDF
✅ Fase 2: Funcionalidades avançadas
✅ Fase 3: QR Code PIX e Boleto Bancário
  - ✅ Task 3.7: QR Code com suporte PIX
  - ✅ Task 3.8: Código de barras com suporte Boleto
  - ✅ Separação de pacotes (PIX, BOLETO independentes)
  - ✅ Scripts de validação separados

## Próximos Passos

- Executar validações em ambiente Oracle
- Testes de performance com grande volume
- Documentação de uso para desenvolvedores
- Exemplos práticos de integração

---

**Última atualização:** 2025-12-18
**Autor:** Maxwell Oliveira (@maxwbh)
**Projeto:** PL_FPDF Modernização - Fase 3
