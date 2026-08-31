# Referência: marcas d'água e overlays

Referência em Python da rasterização de marcas d'água e overlays, validada
contra o MuPDF, para ser portada a `PL_FPDF.OutputModifiedPDF`.

## Por que existe

`AddWatermark`, `OverlayText` e `OverlayImage` registram o pedido em memória,
mas nada é desenhado: `OutputModifiedPDF` recusa com **ORA-20845** quando há
marca d'água ou overlay, para não descartá-los em silêncio.

As funções `generate_watermark_stream` / `generate_text_overlay_stream` do
package chegam a montar um texto de operadores, mas ele não é PDF válido —
`TO_CHAR(rotacao) || ' rotate'` não existe como operador (rotação é matriz em
`Tm`/`cm`) e a cor da marca d'água está fixa em cinza.

## Os três problemas que a referência resolve

1. **Operadores.** `q … gs`, `BT /Fonte corpo Tf`, matriz de rotação em `Tm`,
   `Tj`, `ET`, `Q`. Para imagem, `cm` de posição seguido de `cm` de escala —
   nessa ordem, senão a rotação deforma o desenho.

2. **Fluxo de conteúdo.** O desenho vira um objeto de stream novo, acrescentado
   ao `/Contents` da página. `/Contents` pode ser uma referência única ou um
   array; os dois casos viram array, com o desenho por último (fica por cima).

3. **Recursos.** A fonte, o `/ExtGState` da opacidade e o `/XObject` da imagem
   precisam estar no `/Resources` da página. No PDF do próprio PL_FPDF o
   `/Resources` é **indireto e compartilhado por todas as páginas**
   (`/Resources 2 0 R`): mesclar nele espalharia a fonte da marca d'água — ou
   um `/XObject` — por todo o documento. A saída é dar à página um
   `/Resources` próprio, cópia do original com as chaves novas mescladas.

## Validação

```
python scripts/pdfoverlay_reference/validate.py
```

18 verificações, todas contra o MuPDF como leitor independente:

- o arquivo abre e mantém a contagem de páginas;
- o conteúdo original continua lá (o desenho **acrescenta**, não substitui);
- a marca d'água aparece na extração de texto das páginas pedidas;
- e **não** aparece nas outras — é o teste que pega o vazamento pelo
  `/Resources` compartilhado;
- a marca cai perto do centro e a caixa dela é quadrada, provando a rotação;
- a imagem é reconhecida como imagem da página, não vaza para as vizinhas, e o
  pixel no ponto pedido tem a cor certa.

O PDF de base do teste é montado à mão com `/Resources` indireto compartilhado
justamente porque esse é o caso difícil — e é o que o PL_FPDF gera.

## Estratégia de porta

A referência aplica tudo como atualização incremental (objetos novos no fim do
arquivo + xref com `/Prev`). No PL/SQL o caminho é outro: `pdf_assemble` já
remonta o arquivo inteiro e é código provado, então o que se porta daqui é a
lógica de operadores, de `/Contents` e de `/Resources` — não a montagem.

Cuidado que já custou uma rodada: quem acrescenta um `/XObject` de imagem
precisa reservar o id **antes**, porque a alocação parte do maior id existente.
No arranjo do teste isso sobrescreveu o objeto do fluxo de desenho, e o MuPDF
acusou `syntax error in content stream`.
