# Referência da criptografia de PDF

`EncryptPDF` monta o dicionário `/Encrypt` e calcula `/O`, `/U` e `/P`
corretamente — mas **não cifra os fluxos de conteúdo**. O PDF sai marcado como
protegido com o texto legível para quem abrir o arquivo num editor qualquer.

Este diretório contém a implementação de referência da parte que falta, escrita
e validada em Python antes do porte para PL/SQL — o mesmo método usado no QR
Code, nos códigos de barras e no copiador de objetos.

## Algoritmos (PDF 1.7, seção 7.6.3)

| # | O quê | Situação no package |
|---|-------|---------------------|
| 2 | Chave de criptografia do documento | ✅ já implementado |
| 3 | Valor `/O` (senha de proprietário) | ✅ já implementado |
| 4 | Valor `/U`, revisão 2 | ✅ já implementado |
| 5 | Valor `/U`, revisão 3+ | ✅ já implementado |
| 1 | **Chave por objeto** e cifragem de streams e strings | ❌ **é o que falta** |

O algoritmo 1 deriva, para cada objeto, uma chave própria:
`MD5(chave + número(3 bytes LE) + geração(2 bytes LE))`, truncada em
`min(n+5, 16)` bytes. Com ela se cifra o payload de cada stream e cada string
literal do objeto. O dicionário `/Encrypt` fica de fora — seus `/O` e `/U` já
são resultado dos algoritmos 3 e 5.

RC4 é cifra de fluxo: **o tamanho não muda**, então `/Length` continua valendo
e o porte não precisa recalcular offsets de conteúdo.

## Validação

O teste não é "o PDF tem um `/Encrypt`". É o MuPDF, como leitor independente:

1. reconhece o arquivo como protegido;
2. **sem** a senha, não lê;
3. com a senha de usuário, abre e devolve o texto original;
4. com a senha de proprietário, idem;
5. com senha errada, recusa;
6. **o texto não aparece em claro nos bytes do arquivo**.

O item 6 é o que separa "marcado como protegido" de "protegido" — hoje o
package passa nos cinco primeiros e falha nele.

```bash
pip install pymupdf
python scripts/pdfcrypt_reference/validate.py
```

Saída esperada: `TODOS OS TESTES PASSARAM` (13 verificações, RC4-128 e RC4-40).

O PDF de origem é montado à mão em vez de pelo MuPDF: ele comprime o content
stream mesmo com `deflate=False`, e o teste precisa do texto legível nos bytes
para depois provar que a cifragem o removeu.
