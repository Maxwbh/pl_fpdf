# Referência: cifragem sobre object streams (PDF 1.5+)

Como cifrar e decifrar um PDF em que os objetos moram dentro de *object
streams*, escrita em Python e validada contra o MuPDF, para ser portada.

## O que falta no package

`EncryptPDF` e `DecryptPDF` reescrevem o arquivo **objeto a objeto, por
offset**, e montam uma xref clássica nova. Num PDF 1.5+ isso não fecha: os
objetos de dentro de um object stream não têm offset, e os próprios `/ObjStm` e
`/XRef` não podem ser copiados — eles descrevem uma estrutura que o arquivo de
saída não vai mais ter. Hoje o package recusa com `ORA-20849`, o que é honesto
e insuficiente.

A saída é **achatar**: desmontar os object streams, emitir cada objeto de dentro
como objeto de primeiro nível, descartar os `ObjStm`/`XRef` e escrever uma xref
clássica com os buracos declarados como livres. É o mesmo movimento que o
copiador já faz para merge e extract, com a cifragem no meio.

## A assimetria que decide o resultado

Dentro de um object stream as strings **não são cifradas individualmente**: o
que se cifra é o stream inteiro, de uma vez (PDF 32000-1, 7.5.7). Fora dele,
cada string é cifrada com a chave do seu próprio objeto. Ao achatar:

| | o que acontece com as strings que vieram do ObjStm |
|---|---|
| **cifrando** um PDF em claro | passam a precisar de cifragem própria, que antes não existia |
| **decifrando** um PDF cifrado | já estão em claro; decifrá-las de novo as transforma em lixo |

Errar isso **não quebra o arquivo**: ele abre, as páginas aparecem, e só o
título ou o texto de uma anotação sai embaralhado. É o gênero de defeito que
passa por um teste que só conta páginas — por isso o teste aqui liga a mutação
de propósito e exige que o resultado saia errado.

## O ovo e a galinha do /Encrypt

Num PDF cifrado a chave sai do dicionário `/Encrypt`, que sai do trailer — mas
abrir os object streams para chegar ao trailer exigiria a chave que ainda não se
tem. O que desata o nó é a regra da especificação: **a xref em stream nunca é
cifrada**, justamente porque o leitor precisa dela para achar o `/Encrypt`. Daí
o `materializar=False` do `indexar`: lê a xref, para antes dos object streams.

E, ao abri-los depois, o payload é **decifrado antes de inflado** — é um stream
como outro qualquer.

## Validação

```
python scripts/pdfobjstm_crypt_reference/validate.py
```

O MuPDF é o oráculo em dois níveis: abre o arquivo (com a senha, quando é o
caso) e **lê o conteúdo** — o texto das páginas e o título nos metadados.

O fixture cifrado é montado à mão porque o MuPDF, ao gravar PDF cifrado com
object stream, deixa o `/Info` — o objeto com strings — **fora** dele; e é
justamente a string de dentro que interessa. O MuPDF é chamado primeiro para
confirmar que o fixture é um PDF cifrado de verdade.

## O que a referência pegou antes da porta

- **Parênteses balanceados dentro de uma string.** `(Titulo (2026) final)` é uma
  string só, e a regex ingênua `\(...\)` que estava no
  `pdfcrypt_reference.py` casava `(2026)` e deixava o resto de fora — o arquivo
  saía com um pedaço cifrado no meio de texto em claro, e o leitor, que decifra
  a string inteira, mostrava lixo. O `sec_cifrar_strings` do PL/SQL sempre
  contou profundidade; era a **referência** que discordava dele, e foi ela que
  mudou.
- **O ovo e a galinha acima**, que só aparece quando se tenta decifrar de
  verdade.
