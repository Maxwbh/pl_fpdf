# Referência: xref em stream e object streams (PDF 1.5+)

Leitura das duas estruturas que todo produtor moderno grava e que o `pdf_src_load`
ainda não sabe ler, escrita em Python e validada contra o MuPDF, para ser
portada ao PL_FPDF.

## O que falta no package

`pdf_src_load` lê a xref clássica — a tabela de texto que começa em `xref` e
termina no `trailer`. A partir do PDF 1.5 a xref virou um **objeto com stream**
(`/Type /XRef`), comprimido, e os objetos sem stream foram para dentro de
**object streams** (`/Type /ObjStm`), também comprimidos. Nesses arquivos um
objeto não fica num offset do arquivo: fica dentro do stream de outro objeto.

Enquanto isso não existir, o copiador recusa com `ORA-20843` — e junto vão
merge, extract, marca d'água e overlay sobre documento de terceiro.

O inflate já está portado e provado no banco (`tests/diag_inflate.sql`, 4/4
contra vetores do zlib). O que falta é a leitura das duas estruturas, que é o
que está aqui.

## As três formas de entrada

| forma | como se reconhece | trailer |
|---|---|---|
| tabela clássica | os bytes em `startxref` são `xref` | o dicionário após `trailer` |
| xref em stream | é um objeto `N G obj` com `/Type /XRef` | o próprio dicionário do objeto |
| híbrido | tabela clássica cujo trailer tem `/XRefStm` | o clássico, mais o do stream |

O híbrido é raro, mas o Acrobat gera, e ignorá-lo **perde objetos em silêncio**:
a tabela clássica marca como livres justamente os objetos que só o `/XRefStm`
enxerga. É o modo de falhar mais caro, porque o arquivo abre.

## O predictor

A xref em stream quase sempre traz `/DecodeParms << /Predictor 12 ... >>`. O
predictor não é compressão: é uma transformação aplicada **antes** do deflate
para que colunas parecidas virem zeros. Sem desfazê-la, o inflate devolve bytes
limpos e **errados** — offsets plausíveis apontando para o lugar errado. É o
mesmo gênero de erro do inflate com os bits ao contrário: não quebra, mente.

O número no dicionário (12) é só o padrão que o compressor usou; quem manda é o
byte de filtro no início de **cada linha**. Por isso os cinco filtros do PNG
precisam existir, mesmo com `/Predictor 12` escrito lá.

`/Predictor 2` é o preditor TIFF, definido para imagem. Aqui ele é **recusado**,
não tratado como 1.

## Os três tipos de entrada

- **0** — objeto livre; ignorado.
- **1** — objeto no arquivo: offset e geração. É o que o package já sabe usar.
- **2** — objeto **dentro de um object stream**: id do stream e índice dentro
  dele. É o caso que não cabe no modelo "objeto = offset".

Um campo de largura zero em `/W` não ocupa espaço no stream: vale o default.
Para o campo de **tipo** o default é **1**, não 0 — errar isso faz o arquivo
inteiro virar "objetos livres", sem nenhum sinal.

## Por que a porta é viável

Nenhum objeto de dentro de um object stream pode ter stream (a especificação
proíbe). O que sai de lá é **texto** — exatamente o que `pdf_obj_body` devolve.
Então o copiador não precisa de um segundo caminho de bytes: basta uma tabela
`oid => corpo` ao lado da xref, e `pdf_obj_extent` responder "sem stream" para
esses objetos.

## Validação

```
python scripts/pdfxref_reference/validate.py
```

O MuPDF é o oráculo em dois níveis: ele **abre** cada arquivo montado à mão
aqui (sem isso o teste validaria a leitura de algo que não é um PDF), e ele diz
**o que cada objeto é** — o corpo devolvido tem de bater chave a chave com o do
`xref_object`. É a comparação que pega o erro que interessa: uma xref lida
errado não estoura, ela devolve outro objeto, com um dicionário perfeitamente
válido.

Coberto de propósito, porque um corpus ingênuo deixaria de fora:

- os cinco filtros do PNG, inclusive **misturados no mesmo stream**;
- `/W [1 2 1]` e `/W [0 4 1]` (campo de tipo ausente);
- `/Index` com três faixas, que é o que uma atualização incremental gera;
- híbrido com `/XRefStm`, onde um objeto só existe na xref em stream;
- cadeia `/Prev` de duas seções;
- documento de 40 páginas do próprio MuPDF, com object streams de verdade;
- xref clássica, que precisa continuar funcionando.

E cinco entradas inválidas que precisam ser **recusadas** em vez de decodificadas
errado.

## O oráculo morde?

Um teste que passa com a implementação certa não prova nada se passasse também
com a errada. Duas mutações deliberadas fecham isso: um offset deslocado de um
byte tem de produzir corpo diferente do que o MuPDF diz, e um `/W` trocado de
`[1 4 2]` para `[1 2 4]` tem de mudar o resultado.
