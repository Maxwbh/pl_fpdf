# Referência: a régua do ingresso de evento

**Documento de manutenção.** Não é documentação da biblioteca.

Régua em Python da geometria de um ingresso — painéis, cores, corpos de fonte,
alinhamentos e linhas de base — usada pelo runner para verificar, elemento a
elemento, o PDF que o **banco** gerou.

## Por que existe, se já há a do boleto

A régua do boleto prova **grade**: 50 caixas ao milímetro, três variantes de
Helvetica, alinhamento à direita. Só que o boleto é **preto no branco**, tem
**uma página** e um código de barras só. Fica de fora justamente o que costuma
quebrar em silêncio:

| O que o ingresso acrescenta | Por que importa |
|---|---|
| **Cor de painel** | Um painel que saiu branco continua "desenhado": não há erro, não há operador faltando, e a contagem de `re` bate. O que revela é o `fill` comparado com a cor esperada. |
| **Cor de texto** | Texto claro sobre fundo claro **some**. Nada acusa — o texto está lá, extraível, invisível. |
| **Dois símbolos na mesma página** | Ler *um* deles não prova nada sobre o outro. QR e Code 39 levam o mesmo código, e os dois são conferidos. |
| **Duas páginas** | É o que separa "gerou duas páginas" de "gerou a mesma duas vezes": cada uma com o seu participante e o seu código. |
| **Forma fora do retângulo** | O rabinho do balão sai por `Poly`, que nenhuma outra amostra exercitava. |

## O que a régua sabe

| | |
|---|---|
| folha | A4 com margem de 12 mm — 186 mm úteis |
| paleta | azul-marinho `(13, 25, 44)` e laranja `(232, 80, 58)` do próprio projeto, cinzas `(216)` e `(240)` nos painéis |
| corpos | título 17, destaque 14, nome 16, rótulo 10, linha 8, miúdo 7 |
| símbolos | QR de 32 mm no painel da direita, Code 39 de 120 mm na faixa |

E, como a do boleto, **como o `PL_FPDF` posiciona texto**: margem interna de
1 mm da `Cell` e linha de base em `y + 0,5 x altura + 0,3 x corpo`. Esse modelo
mora em [`scripts/pdflayout.py`](../pdflayout.py), compartilhado pelas duas
réguas — não há duas cópias para divergirem.

## Uma armadilha já paga

Um nome em **16 pt numa célula de 5 mm** não cabe: a caixa que o MuPDF devolve
para o span vai do ascendente ao descendente da fonte, e estoura a caixa por
uma fração de milímetro. A conferência acusou, e a célula do nome passou a ter
7 mm. Sem isso, o teste ficaria falhando por 0,15 mm sem ninguém entender.

## Uso

```bash
pip install pymupdf zxing-cpp pillow
python scripts/ticket_reference/validate.py
python scripts/ticket_reference/validate.py --png /tmp/ticket.png
python scripts/ticket_reference/validate.py --pdf /tmp/ticket.pdf
```

O exemplo equivalente, pronto para rodar no banco, é
[`examples/ticket.sql`](../../examples/ticket.sql).
