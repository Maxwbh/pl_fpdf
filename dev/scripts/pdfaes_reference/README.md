# Referência: criptografia AES do PDF

Referência em Python do AES-128 e AES-256 do PDF, validada contra os vetores
oficiais do FIPS-197 e contra o MuPDF, para ser portada a `PL_FPDF.EncryptPDF`.

## Por que existe

`EncryptPDF` aceita `'AES-128'` e `'AES-256'` na validação de parâmetros e
recusa na hora de usar, com **ORA-20852**. O RC4 já funciona de verdade
(`scripts/pdfcrypt_reference/`), mas está quebrado há anos e o **PDF 2.0 o
removeu da especificação** — leitores novos avisam ou recusam.

O AES vai escrito à mão (S-box, expansão de chave, rodadas) porque é isso que
precisa ser portado: no PL/SQL não há `DBMS_CRYPTO`, eliminado de propósito
nesta base, e o `STANDARD_HASH` cobre só os hashes.

## As duas revisões são bem diferentes

**AES-128 (V4 / R4, `AESV2`)** — a chave do documento sai dos mesmos algoritmos
2, 3 e 5 do RC4 (MD5, `/O`, `/U`). O que muda é a cifra: a chave por objeto
ganha os quatro bytes `sAlT` no fim do MD5, e cada stream é AES-128-CBC com o IV
nos 16 primeiros bytes do próprio dado.

**AES-256 (V5 / R6, `AESV3`)** — outro esquema. Não há chave derivada por
objeto: a chave do arquivo é usada direto, e é aleatória. `/U` e `/O` passam a
ter 48 bytes (hash de 32 + validation salt de 8 + key salt de 8), a chave fica
embrulhada em `/UE`/`/OE`, e `/Perms` carrega as permissões cifradas em ECB —
para que adulterar o `/P`, que vai em claro, seja detectável.

## Validação

```
python scripts/pdfaes_reference/validate.py
```

29 verificações, em duas camadas que pegam coisas diferentes:

1. **FIPS-197** — os vetores oficiais. Uma expansão de chave errada produz uma
   cifra que *parece* funcionar, porque decifra consigo mesma, e que nenhum
   outro programa entende. Só o vetor conhecido pega isso.
2. **MuPDF** — leitor independente: reconhece como protegido, abre com a senha
   de usuário, abre com a de proprietário, recusa a errada, devolve o texto
   original, e o texto não aparece em claro nos bytes.

Mais a ida e volta do CBC com 0, 1, 15, 16, 17 e 100 bytes, e a verificação de
senha do R6 — que é o que o `DecryptPDF` precisa fazer: aceitar a senha de
usuário, aceitar a de proprietário por outro caminho (os 48 bytes do `/U` entram
no hash e a chave vem de `/OE`, não de `/UE`), recusar a errada, e — quando a
mesma senha serve às duas coisas — abrir como **usuário**, nunca como
proprietário: assumir o contrário daria ao leitor poderes que o documento não
concedeu.

## Três detalhes que a implementação ingênua erra

- **`nk > 6 and i % nk == 4`** na expansão de chave. Esse ramo só existe para
  AES-256; sem ele a expansão sai errada da 7ª palavra em diante — e, de novo, a
  cifra continua "funcionando" consigo mesma.
- **Preenchimento PKCS#5 num dado múltiplo de 16**: entra um bloco INTEIRO de
  preenchimento. Omiti-lo faz o decifrador comer 16 bytes de dado real.
- **Critério de parada do algoritmo 2.B (R6)**: o laço olha o ÚLTIMO byte do
  resultado da rodada e o compara com o número da rodada, depois de no mínimo
  64 voltas. É o ponto que quase todo mundo erra na primeira tentativa.

## Um ponto que a porta precisa lembrar

O AES **muda o tamanho** do stream (16 bytes de IV mais o preenchimento), ao
contrário do RC4, que é cifra de fluxo. O `/Length` de cada objeto cifrado tem
de ser reescrito — no RC4 ele continuava valendo.
