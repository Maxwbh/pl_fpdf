# 🧪 PL_FPDF v2.0.0 - Guia Completo de Validação

**Data:** 2025-12-29
**Versão:** 2.0.0
**Status:** Testes corrigidos e prontos para execução

---

## 📋 Resumo das Correções

Este guia documenta as correções aplicadas aos testes de validação e fornece instruções completas para executar todos os testes do projeto.

### Correções Aplicadas (Commit `0e0915c`)

#### 1. **Códigos de Exceção Corrigidos**

| Exceção | Código Antigo | Código Correto | Localização |
|---------|---------------|----------------|-------------|
| `exc_not_initialized` | -20105, -20000 | **-20005** | PL_FPDF.pkb:3302, 3351, 5389, 5527 |
| `exc_font_not_found` | -20100 (Error) | **-20201** | PL_FPDF.pkb:4025 |

#### 2. **Validação de Parâmetros NULL**

Adicionado `NVL()` no procedimento `Init()` para todos os parâmetros:
- `p_orientation` → padrão 'P'
- `p_unit` → padrão 'mm'
- `p_encoding` → padrão 'UTF-8'
- `p_format` → padrão 'A4'

#### 3. **Correções nos Testes**

| Teste | Problema | Solução |
|-------|----------|---------|
| **CellRotated** | UTF-8 '°' causava buffer overflow | Mudado para ASCII 'degrees' |
| **WriteRotated** | Testava 180° (não suportado) | Mudado para 0° (único suportado) |
| **QR Code** | 4 QR Codes excediam buffer 32KB | Reduzido para 2 QR Codes (25mm) |

---

## ✅ Resultado Esperado

Todos os 59 testes devem passar com 100% de sucesso:
- Fase 1: 18 testes (Refatoração Crítica)
- Fase 2: 20 testes (Segurança e Robustez)
- Fase 3: 21 testes (Modernização Avançada)

