# Compatibilidade — PL_FPDF

[**English**](COMPATIBILITY_EN.md) · [Índice da documentação](README.md)

O que foi **medido** e em quê. Onde não há medição, a tabela diz "não testado",
e não "compatível".

---

## 1. Versões do Oracle

| Oracle | 3.3.0 (estável) | 3.4.0 (candidata) |
|--------|-----------------|-------------------|
| 19c, AL32UTF8 | funciona | a suíte inteira passou (rodada do mantenedor) |
| 26ai (23.26), AL32UTF8 | **não funciona**: todo `SetFont` de fonte padrão levanta `ORA-29275` | a suíte inteira passou — ver as evidências abaixo |
| 21c; 23ai anteriores ao 26ai | não testado | não testado |
| 18c e anteriores | não suportado | não suportado |

**Por que a 3.3.0 quebra no 26ai.** Ela monta a tabela de larguras das fontes
com `CHR(i)` para i de 0 a 255. O `CHR` devolve o caractere cujo **byte** é i
no charset do banco, e no 26ai com AL32UTF8 os bytes que abrem uma sequência
UTF-8 (194 a 244) levantam `ORA-29275: partial multibyte character` — no 19c,
o mesmo `CHR` devolve o byte cru e não reclama. A 3.4.0 indexa a tabela pelo
byte, sem `CHR`. Medido nos dois bancos, com o instalador de cada versão.

**Em resumo:** no 26ai, hoje **não há versão estável que funcione**. A única
que roda lá é a candidata v3.4.0-rc2 — use-a sabendo que é candidata, ou
aguarde a 3.4.0 final. A política para esse caso está no
[SECURITY.md](../SECURITY.md#oracle-26ai).

### Evidências da rodada no 26ai

| | |
|---|---|
| Banco | Oracle AI Database 26ai Free 23.26.3.0.0, imagem `gvenzl/oracle-free:23.26.3-faststart`, PDB `FREEPDB1`, charset AL32UTF8 |
| Código | o `src/` da tag `v3.4.0-rc2` (commit `0b3ca59`) — idêntico ao `src/` atual |
| Comando | `python dev/scripts/run_tests.py --full`, no schema de aplicação do container |
| Resultado | 346 verificações passaram, 0 falharam, 2 puladas; 29 PDFs gerados no banco e conferidos pelo MuPDF e pelo zxing-cpp |
| As 2 puladas | em `test_compat_legado`: o `Output` legado grava no `DIRECTORY PDF_DIR`, que o schema de teste não tem; e a ausência das rotinas de demonstração, conferida por outro caminho |
| Data | 07/11/2026 |

A rodada no 19c é a do mantenedor, no ambiente dele; o número de verificações
muda a cada teste acrescentado, por isso a tabela não o fixa.

## 2. Charset do banco

| Charset | Situação |
|---------|----------|
| AL32UTF8 | testado no 19c e no 26ai |
| De um byte (WE8MSWIN1252, WE8ISO8859P1…) | fora das rodadas regulares: não testado na 3.4.0 |

Em AL32UTF8, o texto é convertido para a codificação da fonte na hora de
escrever, e o limite é o da fonte (seção 3). Em outro charset, há um limite
antes desse: só chega ao PL_FPDF o que o banco consegue guardar num
`VARCHAR2` — e esse caminho não está coberto pelos testes.

## 3. Texto e fontes

| Fonte | Codificação | O que escreve |
|-------|-------------|---------------|
| Helvetica, Times, Courier, nos quatro estilos (Arial é Helvetica) | WinAnsi (cp1252), declarada no PDF | português, espanhol, francês, alemão e as demais línguas da Europa Ocidental |
| Symbol | a própria da fonte — o PDF **não** declara WinAnsi | letras gregas e símbolos matemáticos, escolhidos **pelo código** |
| ZapfDingbats | a própria da fonte — o PDF **não** declara WinAnsi | ornamentos e marcadores, escolhidos **pelo código** |
| TrueType embutida (`AddTTFFont`, `LoadTTFFromFile`) | conforme o mapeamento Unicode (`cmap`) da fonte | o que a fonte tiver |

Caractere fora do WinAnsi numa fonte padrão — ideograma, cirílico, emoji — é
**recusado** com `ORA-20203` e a posição (3.4.0). Para essas escritas, embuta
uma fonte TrueType.

**Symbol e ZapfDingbats escolhem o glifo pelo código, não pelo caractere.** O
texto passa pela mesma conversão das outras fontes, e o byte resultante indexa a
codificação própria da fonte. Medido no 26ai: no Symbol, `'abgp'` sai como
`αβγπ`; já `'α'`, passado como letra grega, levanta `ORA-20203`, porque não
existe em WinAnsi. No ZapfDingbats, `'3'` desenha a marca de verificação; `'✓'`
levanta `ORA-20203`. Consulte a tabela de códigos da fonte, e lembre que o
texto copiado do PDF não traz o símbolo — essas fontes saem sem mapa para
Unicode.

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
