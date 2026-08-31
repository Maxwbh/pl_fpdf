# Referência dos códigos de barras

`AddBarcode` no `PL_FPDF` implementa **CODE39**, **CODE128** (Code B e Code C),
**EAN-13**, **EAN-8** e **ITF-14**. Como não há como decodificar um código de
barras dentro do banco, o algoritmo é provado aqui fora:

- **`barcode_reference.py`** — mesmas tabelas e mesma ordem de operações do PL/SQL.
- **`validate.py`** — gera os códigos e os lê com o **zxing-cpp**.

```bash
pip install zxing-cpp numpy
python scripts/barcode_reference/validate.py         # 38/38 códigos decodificados
python scripts/barcode_reference/validate.py vetores # vetores para o teste PL/SQL
```

`tests/test_core.sql` compara o desenho gerado **pelo banco** com esses vetores:
cada grupo de módulos escuros consecutivos vira um `re f` no fluxo do PDF, então
a contagem dessa marca identifica as barras produzidas pelo PL/SQL.

Observação: EAN e ITF aceitam o código **sem** o dígito verificador — ele é
calculado — ou com ele, caso em que é conferido.
