# PL_FPDF Test Suite

**Version:** 3.2.0

## Quick Start

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Run the full suite
@tests/run_all_tests.sql

-- Or run a single area
@tests/test_phase_security.sql
```

---

## Structure

One runner, one validation per area — no duplicates:

```
tests/
├── run_all_tests.sql              # Único runner: executa tudo abaixo, em ordem
├── validate_phases_1_3.sql        # Geração de PDF (init, fontes, imagens, UTF-8)
├── test_phase_4_parser_basic.sql  # Parser de PDF existente
├── test_phase_4_1b_pages.sql      # Leitura de páginas
├── test_phase_4_2_page_mgmt.sql   # Rotação / remoção de páginas
├── test_phase_4_3_watermark.sql   # Marca d'água
├── test_phase_4_4_output.sql      # OutputModifiedPDF
├── test_phase_4_5_overlay.sql     # Overlay de texto/imagem
├── test_phase_4_6_merge_split.sql # Merge e split
├── validate_phase_4_complete.sql  # Integração da manipulação de PDF
└── test_phase_security.sql        # Criptografia RC4 (v3.2)
```

Os testes da extensão PIX/Boleto ficam em
[`extensions/brazilian-payments/tests/`](../extensions/brazilian-payments/tests/).

---

## Requirements

- Oracle 19c+ with `PL_FPDF` installed (`@deploy_all.sql`)
- `SERVEROUTPUT` enabled
- No framework needed — plain SQL*Plus / SQLcl scripts with PASS/FAIL output
