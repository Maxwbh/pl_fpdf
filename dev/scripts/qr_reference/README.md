# Referência do codificador QR

`AddQRCode` no `PL_FPDF` implementa o QR Code (ISO/IEC 18004) em modo byte,
versões 1 a 20, níveis de correção L/M/Q/H. Como não há como decodificar um QR
dentro do banco, o algoritmo é provado aqui fora:

- **`qr_reference.py`** — mesma lógica do PL/SQL (mesmas tabelas, mesma ordem de
  operações), escrita de forma que a portabilidade seja verificável linha a linha.
- **`validate.py`** — gera símbolos e os lê com o **zxing-cpp**, um decodificador
  de referência. É a prova de que o algoritmo produz QR legível de verdade.

```bash
pip install zxing-cpp numpy
python scripts/qr_reference/validate.py            # 24/24 símbolos decodificados
python scripts/qr_reference/validate.py vetores    # vetores para o teste PL/SQL
```

`tests/test_core.sql` compara a matriz gerada **pelo banco** com esses vetores:
cada módulo escuro vira um `re f` no fluxo do PDF, então a contagem dessa marca
identifica a matriz produzida pelo PL/SQL.
