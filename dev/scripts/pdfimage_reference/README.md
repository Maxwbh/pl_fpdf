# Referência: imagem como /XObject do PDF

Referência em Python da conversão de um JPEG ou PNG em objeto de imagem do PDF,
validada contra o MuPDF, portada para o overlay de imagem do PL_FPDF.

## Por que existe

`OverlayImage` guardava o BLOB em memória e `OutputModifiedPDF` recusava gerar
(**ORA-20845**) em vez de escrever uma página que referencia um objeto
inexistente. A metade difícil do desenho — fluxo de conteúdo, `/Contents`,
`/Resources` próprio — já estava pronta (ver `scripts/pdfoverlay_reference/`);
faltava transformar os bytes da imagem num `/XObject`.

O `p_parseImage` que já existe no package não servia: lê de **arquivo**
(`getImageFromUrl`) e trata só PNG. Aqui a entrada é o BLOB que o chamador
passou.

## Dois caminhos, e a escolha decide o tamanho do arquivo

**Passagem direta** — sem alfa e sem entrelaçamento. Nada é descomprimido:

- **JPEG** entra inteiro, com `/Filter /DCTDecode` — quem decodifica é o leitor.
- **PNG** guarda os dados em blocos IDAT **já em zlib**, que é exatamente o
  `/Filter /FlateDecode` do PDF. Basta concatenar os IDAT e declarar
  `/DecodeParms << /Predictor 15 … >>`, porque o PNG filtra cada linha antes de
  comprimir e o leitor sabe desfazer isso. Vale para 1, 2, 4, 8 **e 16** bits.

Sem o `/Predictor 15` o arquivo continua válido — e desenha ruído.

**Reprocessamento** — com canal alfa (color type 4 ou 6) ou entrelaçado
(Adam7). Aí não tem jeito: inflar, desfazer o filtro por linha e, no
entrelaçado, remontar as sete passagens.

A saída desse caminho vai **sem compressão**, porque o package tem inflate mas
não tem deflate. É maior no arquivo e é honesto; comprimir de volta exigiria
escrever um deflate, que é outro trabalho inteiro.

## O que o canal alfa exige

O PDF **não tem alfa dentro do pixel**. A transparência é um segundo objeto de
imagem, em `/DeviceGray`, apontado por `/SMask`. Então um PNG RGBA vira dois
objetos: a cor num e o alfa no outro.

## 16 bits nunca precisou de reprocessamento

Estava recusado junto com os outros dois, e não devia: o PDF aceita
`/BitsPerComponent 16`, e o predictor também. Passa direto, comprimido.

## O que segue recusado

Com `ORA-20823`, em vez de desenhado errado: PNG entrelaçado com menos de 8
bits por componente (exigiria empacotar bit a bit), PNG indexado **e**
entrelaçado, e color type que não existe.

## Validação

```
python scripts/pdfimage_reference/validate.py
```

O que importa não é "o PDF tem um objeto de imagem" — é que o MuPDF
**rasterize o pixel certo**, porque um `/DecodeParms` errado, um `/ColorSpace`
trocado ou uma paleta mal montada produzem um arquivo válido que desenha lixo, e
nenhuma checagem estrutural pega isso. Cada caso monta a imagem com uma cor
conhecida, gera o PDF, deixa o MuPDF desenhar e compara o pixel.

Cobre PNG RGB, cinza, indexado (a cor tem de vir da paleta), JPEG RGB, RGBA,
cinza + alfa, entrelaçado, 16 bits, e as recusas.

Três coisas que este arquivo faz questão de não terceirizar:

1. **A transparência é verificada por composição.** A imagem com alfa é
   desenhada sobre um fundo de cor conhecida, e o que se confere é a cor
   **misturada**. "O arquivo tem dois objetos de imagem" não prova nada.
2. **E há a prova ao contrário**: a mesma imagem montada **sem** o `/SMask` tem
   de dar pixel diferente. Sem isso, a checagem acima passaria mesmo que o
   leitor ignorasse a transparência.
3. **O fixture entrelaçado é conferido pelo Pillow antes de ser usado.** O
   Pillow não grava PNG entrelaçado, então o arquivo é montado aqui — e montar
   o fixture com o mesmo raciocínio do decodificador seria ser juiz e réu. O
   Pillow lê o arquivo, e só depois o `desentrelacar` é comparado com o raster
   que ele devolveu.

## Detalhe que já custou uma leitura errada

Nem todo marcador entre `0xC0` e `0xCF` do JPEG é um quadro: `C4` (DHT), `C8`
(JPG) e `CC` (DAC) caem no meio da faixa e não carregam dimensões. Lê-los como
SOF devolve lixo no lugar da largura.
