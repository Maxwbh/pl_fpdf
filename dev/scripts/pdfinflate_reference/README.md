# Referência: INFLATE (RFC 1951)

Implementação de inflate escrita à mão em Python, validada contra o `zlib`,
para ser portada ao PL_FPDF.

## Por que escrita à mão

O PL/SQL não tem zlib, e os dois experimentos em `tests/diag_utl_compress*.sql`
fecharam a porta do `UTL_COMPRESS`: ele só descomprime quando o **CRC-32 e o
tamanho** do rodapé gzip estão corretos — os dois são conferidos, e a API por
partes falha antes de entregar qualquer byte. Como o CRC é do conteúdo
**descomprimido**, conhecê-lo exigiria descomprimir. Circular.

Sem inflate, o copiador recusa (`ORA-20843`) qualquer PDF com **xref em stream**
ou **object streams** — o que todo produtor moderno gera —, barrando merge,
extract, marca d'água e overlay sobre documento de terceiro.

## O escopo é menor do que parece

O copiador **não** descomprime fluxo de conteúdo: ele copia os streams byte a
byte e acrescenta conteúdo novo. O inflate é necessário só para as estruturas —
xref em stream e object streams —, que têm alguns KB, contra as centenas de um
fluxo de conteúdo. É o que torna o custo de CPU aceitável em PL/SQL.

## Forma da implementação

Segue o `puff`, a implementação de referência do próprio zlib: tabelas de
Huffman como dois vetores (quantos códigos de cada comprimento, e os símbolos em
ordem) e decodificação bit a bit. Sem tabela de lookup grande nem aritmética de
ponteiro — que é o que a torna portável para PL/SQL.

## Validação

```
python scripts/pdfinflate_reference/validate.py
```

O `zlib` é o oráculo: o resultado tem de ser byte a byte igual ao dele. Uma
implementação errada de inflate não "quase funciona" — produz alguns bytes
plausíveis e depois lixo.

Três coisas que um corpus ingênuo deixaria de fora, e que o teste cobre:

1. **Os três tipos de bloco.** Dado aleatório vira ARMAZENADO (o compressor
   desiste), dado pequeno vira Huffman FIXO, dado repetitivo vira DINÂMICO.
   Testar só com texto exercita um caminho e deixa dois sem cobertura — o teste
   conta os tipos e falha se algum não apareceu.
2. **Cópia sobreposta.** Com distância 1 e comprimento 100 o mesmo byte se
   repete cem vezes: a origem avança junto com o destino. Copiar a fatia de uma
   vez dá resultado errado, e só aparece em dado muito repetitivo.
3. **Streams de PDF de verdade** — uma xref em stream com `/W [1 2 1]` e um
   object stream com Catalog, Pages e Page.

Mais três entradas inválidas, que precisam ser **recusadas** em vez de
decodificadas errado.

## O que a porta para PL/SQL exigiu além do algoritmo

O algoritmo transcrito direto **funcionava e estourava a PGA** (`ORA-04036`)
descomprimindo 688 bytes. Duas causas, ambas de memória, nenhuma de lógica —
confirmado transcrevendo a porta de volta para Python, que produziu o resultado
certo:

1. **Huffman num record devolvido e passado adiante.** Um record com duas
   coleções é copiado a cada chamada, e `inf_sim` é chamada uma vez por símbolo.
   As tabelas foram para variáveis de pacote, com um parâmetro escolhendo qual.
2. **Janela guardada como saída inteira.** A versão anterior acumulava tudo numa
   associative array e apagava elemento a elemento — e `DELETE` numa associative
   array **não devolve memória**, então o consumo crescia com o total
   descomprimido. Virou uma tabela **circular** de 32768 posições, indexada por
   `MOD(posição, 32768)`: é o alcance máximo de uma referência LZ77, então é só
   isso que precisa ficar vivo, e o consumo passa a ser constante.

## A armadilha que a implementação ingênua cai

A ordem dos bits do DEFLATE é do **menos** significativo para o mais, dentro de
cada byte — mas os códigos de Huffman são lidos do **mais** significativo para o
menos. Confundir os dois produz saída plausível por alguns bytes antes de
degringolar, que é o pior tipo de erro para depurar.
