# Referência: DEFLATE na direção de comprimir

**Documento de manutenção.** Não é documentação da biblioteca.

Referência em Python do DEFLATE (RFC 1951) e do envelope zlib (RFC 1950),
validada contra o `zlib` do Python, portada para o `pdf_deflate` do package.

## Por que existe

O `FlateDecode` já descomprimia: o INFLATE foi escrito em PL/SQL porque o
`UTL_COMPRESS` não serve — ele só aceita rodapé gzip com CRC-32 do conteúdo
**descomprimido**, que só se conhece descomprimindo. Faltava o outro lado. Sem
um deflate, `SetCompression(TRUE)` era um no-op: perguntava por uma função de
zlib que o Oracle não tem, desligava a compressão e seguia.

## O subconjunto que se emite

Escrever é mais fácil que ler. O leitor precisa aceitar tudo o que a
especificação permite; o escritor só precisa emitir **um** caminho válido:

| | |
|---|---|
| blocos | um só, `BFINAL=1`, `BTYPE=01` — Huffman **fixa** |
| casamento | LZ77 **guloso**, janela de 32 KB, mínimo 3 bytes, máximo 258 |
| busca | dispersão de 3 bytes em 15 bits, corrente de até 16 candidatos |
| desempate | o primeiro achado, que é o mais próximo — distância menor custa menos bits |
| escape | se não compensar, bloco **armazenado** (`BTYPE=00`) |

Sem árvore para transmitir some a metade complicada do formato. O preço é o
teto de compressão: onde a economia viria de dar códigos curtos aos símbolos
frequentes, a Huffman fixa não compete com a dinâmica do zlib.

| Caso | Referência | zlib nível 6 |
|---|---|---|
| texto de página repetido | 4% | 4% |
| acentos em latin-1 | 3% | 3% |
| fluxo de coordenadas | 56% | 39% |
| dado aleatório | 100% (armazenado) | 100% |

O bloco armazenado é o que impede o resultado de ficar **maior** que a entrada:
dado incompressível cresce ~5% com Huffman fixa, e num PDF isso é regressão —
o arquivo aumenta e ainda ganha um filtro para o leitor desfazer.

## A regra do jogo: byte a byte

O PL/SQL porta este módulo **decisão por decisão** — mesma dispersão, mesmo
limite de corrente, mesmo desempate, mesmo teto de tamanho. Não é capricho:
`tests/diag_deflate.sql` compara o que o banco produz com o que esta referência
produz para a mesma entrada, **byte a byte**.

Um deflate "equivalente mas diferente" só poderia ser conferido
descomprimindo — e aí um erro de escrita que o inflate desta mesma casa tolera
passaria despercebido, para quebrar em outro leitor.

## Uma consequência da arquitetura, e não uma escolha estética

O documento gerado é montado num **CLOB** e só vira BLOB no fim, com conversão
de charset. Byte binário não sobrevive a isso: em AL32UTF8, todo valor de 128 a
255 vira **dois** bytes. É a mesma armadilha do `CHR(n)`, que o
`check_byte_chars.py` vigia.

Por isso o fluxo comprimido sai em **hexadecimal**, com
`/Filter [/ASCIIHexDecode /FlateDecode]`. O hexadecimal dobra o tamanho do
comprimido, então a compressão só é usada quando **ainda assim** o resultado
fica menor que o conteúdo cru — decisão tomada página a página.

## Uso

```bash
pip install pymupdf
python scripts/pdfdeflate_reference/validate.py
python scripts/pdfdeflate_reference/validate.py vetores   # para o diagnóstico
```
