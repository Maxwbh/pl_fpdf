# Referência do copiador de objetos PDF

`MergePDFs`, `SplitPDF`, `ExtractPages` e `OutputModifiedPDF` têm uma raiz
comum: **copiar objetos de um PDF de origem para um novo documento,
renumerando as referências indiretas**. Nada é re-renderizado — texto, fontes,
imagens e anotações chegam ao destino byte a byte.

Este diretório contém a implementação de referência em Python usada para
projetar e validar esse algoritmo antes de portá-lo para PL/SQL
(`src/PL_FPDF.pkb`, seção *Copiador de objetos PDF*).

## Por que uma referência

O parser que já existia na biblioteca (`get_pdf_object`) lê objetos para um
`VARCHAR2(32767)`: corrompe streams binários e trunca objetos grandes. Copiar
objetos exige trabalhar em nível de bytes. A referência foi escrita com as
mesmas restrições do PL/SQL — leitura só por offsets, busca de literais ASCII,
payload de stream nunca convertido para texto — para que o porte fosse
mecânico.

## Algoritmo

1. **xref encadeada** — lê `startxref`, percorre as seções seguindo `/Prev`;
   a seção mais recente vence. `id do objeto => offset em bytes`.
2. **Extensão do objeto** — a porção ASCII vai até `stream` (ou até `endobj`,
   se não houver stream). Com stream, o tamanho vem de `/Length` (que pode ser
   uma referência indireta) e só então `endobj` é procurado — assim a busca
   nunca casa dentro de dados binários.
3. **Árvore de páginas achatada** — `/MediaBox`, `/Resources`, `/CropBox` e
   `/Rotate` herdados dos nós intermediários são materializados em cada página,
   já que a árvore será reconstruída.
4. **Fecho transitivo** — a partir das páginas escolhidas, segue toda
   referência `N G R` encontrada na porção ASCII dos objetos (payloads de
   stream não referenciam objetos). `/Parent` é removido antes, senão o fecho
   arrastaria o documento inteiro. Objetos não alcançados ficam de fora.
5. **Renumeração** — cada origem recebe um deslocamento fixo de ids; o
   cabeçalho `N G obj` e toda referência `N G R` do dicionário são reescritos.
   O payload do stream é copiado sem tocar.
6. **Montagem** — `Catalog` (objeto 1) e `/Pages` (objeto 2) novos, xref
   clássica com entradas livres para os ids não copiados, trailer e `%%EOF`.

A ordem de `/Kids` é a ordem pedida: `ExtractPages(id, '5,1')` devolve a
página 5 seguida da 1.

## Validação

`validate.py` monta PDFs de origem à mão — com stream comprimido, `/Length`
indireto, árvore de páginas aninhada com herança de `/MediaBox` e
`/Resources`, e uma imagem compartilhada entre páginas — e confere o resultado
com o **MuPDF** (`pymupdf`), um decodificador independente:

- o MuPDF abre o documento sem erro;
- a contagem de páginas bate;
- o texto extraído de cada página bate com o da página de origem;
- a caixa da página (herança preservada) bate;
- as imagens referenciadas continuam presentes;
- extrair uma página produz um arquivo menor que o original (o fecho
  transitivo realmente descarta o que não é usado).

```bash
pip install pymupdf
python scripts/pdfmerge_reference/validate.py
```

Saída esperada: `TODOS OS TESTES PASSARAM` (67 verificações).

## Limitações conhecidas (idênticas no PL/SQL)

- **xref em stream** (PDF 1.5+ com xref comprimida) não é suportada —
  `ORA-20843`. PDFs assim precisam ser regravados com xref clássica.
- Objetos cuja porção ASCII passe de 32 000 bytes não podem ser renumerados —
  `ORA-20841`.
- PDFs criptografados não são decifrados antes da cópia.

O lado PL/SQL é exercitado por `tests/test_core.sql`, que gera documentos com
a própria biblioteca, aplica merge/split/extract e confere a contagem de
páginas pelo parser do package.
