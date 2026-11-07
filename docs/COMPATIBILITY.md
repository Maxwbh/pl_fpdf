# Compatibilidade — PL_FPDF

[**English**](COMPATIBILITY_EN.md) · [Índice da documentação](README.md)

O que foi **medido** e em quê. Onde não há medição, a tabela diz "não testado",
e não "compatível".

---

## 1. Versões do Oracle

| Oracle | 3.3.0 (estável) | 3.4.0 (candidata) |
|--------|-----------------|-------------------|
| 19c, AL32UTF8 | funciona | a suíte inteira roda a cada mudança |
| 26ai (23.26), AL32UTF8 | **não funciona**: todo `SetFont` de fonte padrão levanta `ORA-29275` | a suíte inteira passou: 346 testes, 0 falhas (07/11/2026, v3.4.0-rc2) |
| 21c; 23ai anteriores ao 26ai | não testado | não testado |
| 18c e anteriores | não suportado | não suportado |

**Por que a 3.3.0 quebra no 26ai.** Ela monta a tabela de larguras das fontes
com `CHR(i)` para i de 0 a 255. O `CHR` devolve o caractere cujo **byte** é i
no charset do banco, e no 26ai com AL32UTF8 os bytes que abrem uma sequência
UTF-8 (194 a 244) levantam `ORA-29275: partial multibyte character` — no 19c,
o mesmo `CHR` devolve o byte cru e não reclama. A 3.4.0 indexa a tabela pelo
byte, sem `CHR`. Medido nos dois bancos, com o instalador de cada versão.

**Em resumo:** no 26ai, use a 3.4.0 (hoje, a v3.4.0-rc2).

## 2. Charset do banco

| Charset | Situação |
|---------|----------|
| AL32UTF8 | testado no 19c e no 26ai |
| De um byte (WE8MSWIN1252, WE8ISO8859P1…) | fora das rodadas regulares: não testado na 3.4.0 |

O charset do banco não limita o que sai no PDF: o texto é convertido para a
codificação da fonte na hora de escrever.

## 3. Texto e fontes

| Fonte | O que escreve |
|-------|---------------|
| As 14 fontes padrão do PDF (Helvetica, Times, Courier, Symbol, ZapfDingbats) | o repertório WinAnsi (cp1252): português, espanhol, francês, alemão e as demais línguas da Europa Ocidental |
| TrueType embutida (`AddTTFFont`, `LoadTTFFromFile`) | o que a fonte tiver |

Caractere fora do WinAnsi numa fonte padrão — ideograma, cirílico, emoji — é
**recusado** com `ORA-20203` e a posição (3.4.0). Para essas escritas, embuta
uma fonte TrueType.

## 4. O PDF gerado

| | |
|---|---|
| Versão padrão | 1.4 |
| Versões que `SetPDFVersion` aceita | 1.4, 1.5, 1.6, 1.7, 2.0 |
| Cifra × versão mínima | RC4 → 1.4 · AES-128 → 1.5 · AES-256 → 1.7 · PDF 2.0 só aceita AES-256 |
| Compressão | DEFLATE próprio, lido por qualquer leitor (o resultado é conferido com o zlib) |
| Conferido com | MuPDF, e zxing-cpp nos códigos — ver [MANUTENCAO.md](MANUTENCAO.md) |

## 5. O PDF lido (`LoadPDF` e manipulação)

| Entrada | Situação |
|---------|----------|
| xref clássica (PDF 1.0–1.4) | lê |
| xref em stream e object streams (PDF 1.5+) | lê; na saída, os objetos são achatados e a xref volta a ser clássica |
| PDF cifrado | o `LoadPDF` **aceita sem avisar e não decifra**: a saída tem a página vazia. Passe antes pelo `DecryptPDF`, que exige a senha |
| Streams comprimidos | FlateDecode, com teto de 8 MB por stream |
| Formulários (AcroForm), assinatura digital | não são tratados — ver as limitações no [README](../README.md#limitações) |

## 6. O que só existe na 3.4.0

Se você está na 3.3.0 estável, isto ainda não está disponível:

| Recurso | Na 3.3.0 |
|---------|----------|
| Acentuação correta nas fontes padrão (conversão para WinAnsi) | o acento sai como dois glifos trocados |
| `GetStringWidth`, centralizar e alinhar à direita com acento | `ORA-06502` |
| Fonte TrueType de fato embutida (`/FontFile2`) | a fonte registrada não é usada |
| `ImageFromBlob` (imagem de um BLOB, sem ACL de rede) | só `Image` por URL |
| Funcionar no Oracle 26ai | não funciona (§1) |

A lista completa, com causa e conserto, está no [CHANGELOG](../CHANGELOG.md).

## 7. O que a suíte cobre

Cada conjunto abaixo é um arquivo de `dev/tests/`, e todos passaram na 3.4.0,
no 19c e no 26ai. Os PDFs gerados são lidos de volta por leitores
independentes — não basta "não deu erro".

| Conjunto | Arquivos |
|----------|----------|
| Instalação, ciclo de vida e saída | `test_core`, `test_ciclo_saida`, `test_compat_legado` |
| Geração: texto, fontes, desenho | `test_geracao_basica`, `test_fonte_texto`, `test_winansi`, `test_desenho`, `test_cursor_margens`, `test_sublinhado` |
| Imagens | `test_stream_imagem` |
| TrueType | `test_fontes_truetype` |
| Manipulação de PDF existente | `test_manipulacao_completa`, `test_paginas_girar_remover`, `test_marca_dagua`, `test_sobreposicao`, `test_saida_modificada`, `test_mesclar_dividir` |
| Leitura de PDF | `test_leitura_pdf`, `test_leitura_paginas` |
| Criptografia | `test_seguranca` |
| Metadados | `test_metadados_config` |
| Regressões | `test_regressoes_revisao` |

Como rodar: [MANUTENCAO.md](MANUTENCAO.md). A extensão de pagamentos tem as
suítes dela, à parte: ver o [README da extensão](../extensions/brazilian-payments/README_PT_BR.md).
