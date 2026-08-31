# Referência: a régua do desenho da ficha de compensação

**Documento de manutenção.** Não é documentação da biblioteca.

Régua em Python da geometria de um boleto — caixas, corpos de fonte, pesos,
alinhamentos e linhas de base — conferida com as métricas reais do Helvetica e
usada pelo runner para verificar, campo a campo, o PDF que o **banco** gerou.

## Por que existe

As outras referências desta pasta provam **conteúdo**: o zxing lê o código de
barras, o MuPDF decifra a string, o pixel bate. Nenhuma delas prova **desenho**.
E a amostra `boleto` do runner passava inteira enquanto:

- o valor podia transbordar a caixa que o abriga;
- o rótulo podia sair no corpo errado;
- a coluna do dinheiro podia não estar alinhada à direita;
- dois textos podiam sair **um por cima do outro**.

O último não é hipótese: o nome do pagador em 9 pt e o endereço em 7 pt cabiam
nas suas caixas, e ainda assim saíam empilhados. Só apareceu quando a
verificação passou a comparar as **linhas de base**.

## O que a régua sabe

Medidas da ficha de compensação da FEBRABAN:

| | |
|---|---|
| largura da ficha | 177 mm, centralizada em A4 (x = 16,5) |
| coluna de valores | 40 mm à direita, começando em x = 153,5 |
| código de barras | 103 x 13 mm |
| corpos | rótulo 6 pt, valor 9 pt, miúdo 7 pt, linha digitável 11 pt |
| pesos | negrito no vencimento, no valor do documento e no pagador |

E, principalmente, **como o `PL_FPDF` posiciona texto**: a `Cell` tem margem
interna de 1 mm nos dois lados e põe a linha de base em
`y + 0,5 x altura + 0,3 x corpo`. É por saber disso que a conferência compara
posição absoluta, e não "o texto está por aí".

## Três perguntas, nesta ordem

1. **A régua fecha sozinha?** Nenhum texto mais largo que sua caixa (métricas
   reais, não estimativa), nenhuma caixa sobre outra, as linhas de campos
   miúdos somando exatamente a coluna esquerda, e tudo dentro do A4.
2. **Quem desenha por ela produz o que ela diz?** O desenho de referência é
   feito em PyMuPDF com os mesmos números, o PDF é lido de volta e cada texto
   tem de aparecer com a fonte, o corpo, a linha de base e o alinhamento
   previstos — e nenhum empilhado sobre outro.
3. **O código de barras é legível?** Renderizado a 300 dpi e lido pelo zxing.

## O que impede a divergência silenciosa

`conferir()` é **a mesma função** aplicada aos dois lados: ao PDF de referência
(aqui) e ao PDF que sai do Oracle (`scripts/run_tests.py`, amostra `boleto`,
chave `layout_boleto`). Não existem duas listas de expectativas, então o PL/SQL
não pode sair da régua sem que a rodada acuse — campo a campo, dizendo qual
campo, qual via e quanto desviou.

## Uso

```bash
pip install pymupdf zxing-cpp pillow
python scripts/boleto_reference/validate.py
python scripts/boleto_reference/validate.py --png /tmp/boleto.png
python scripts/boleto_reference/validate.py --pdf /tmp/boleto.pdf
```
