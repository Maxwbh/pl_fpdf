# PL_FPDF Roadmap

**Versao Atual:** 3.3.0 | **Atualizado:** 2026-08-28

Revisado em 28/08/2026 conferindo cada afirmacao contra o codigo. As correcoes
estao marcadas ao longo do documento; a mais importante e que **v3.0.0 dava
marcas d'agua e overlays como prontos desde fevereiro, e eles nao desenhavam
nada** — so passaram a desenhar agora.

---

## Versoes Lancadas

### v2.0.0 - Foundation (Dez 2025) ✅

| Feature | Status |
|---------|--------|
| Init/Reset/IsInitialized | ✅ |
| Multi-page documents | ✅ |
| CLOB buffer (unlimited) | ✅ |
| UTF-8 encoding | ✅ |
| TrueType fonts | ✅ |
| PNG/JPEG images | ✅ |
| Text rotation | ✅ |
| Native compilation | ✅ |
| QR Code / Barcode | ✅ |
| PIX QR Code (extension) | ✅ |
| Boleto barcode (extension) | ✅ |

> **Nota da revisao.** QR Code e codigos de barras estavam marcados como
> prontos, mas ate a validacao de agosto/2026 o QR preenchia a area de dados com
> um padrao derivado de `dbms_utility.get_hash_value` — desenhava um simbolo que
> nenhum leitor decodificava. Hoje o codificador e o real (ISO/IEC 18004) e o CI
> confere as tabelas contra referencias validadas no zxing-cpp.

### v3.0.0 - PDF Manipulation (Fev 2026)

| Feature | Status |
|---------|--------|
| LoadPDF - Carregar PDF existente | ✅ |
| GetPageCount / GetPageInfo | ✅ |
| RotatePage (0, 90, 180, 270) | ✅ |
| RemovePage | ✅ |
| AddWatermark (texto com opacidade) | ✅ *(so desenha desde ago/2026)* |
| OverlayText | ✅ *(so desenha desde ago/2026; ver pendencia das opcoes)* |
| OverlayImage | ✅ *(so desenha desde ago/2026)* |
| OutputModifiedPDF | ✅ |
| MergePDFs | ✅ |
| SplitPDF | ✅ |
| ExtractPages | ✅ |

> **Correcao da revisao.** Ate agosto/2026 as tres ultimas linhas de sobreposicao
> registravam o pedido em memoria e **nada era desenhado**; `OutputModifiedPDF`
> recusava gerar com `ORA-20845`. Marca-las como prontas em fevereiro foi erro
> do roadmap, nao do codigo — o codigo era honesto ao recusar.

### v3.2.0 - Security RC4 (Mar 2026)

| Feature | Status |
|---------|--------|
| RC4 40-bit encryption | ✅ *(so cifra desde ago/2026)* |
| RC4 128-bit encryption | ✅ *(idem)* |
| Password protection (user/owner) | ✅ |
| Permission controls (8 flags) | ✅ |
| DecryptPDF | ✅ *(so decifra desde ago/2026)* |
| GetSecurityInfo | ✅ |
| SetPDFVersion | ✅ |

> **Correcao da revisao.** Mesmo padrao: o dicionario `/Encrypt`, as senhas e as
> permissoes estavam corretos, mas os fluxos de conteudo saiam **em claro** — o
> PDF ficava marcado como protegido sem estar. `DecryptPDF`, por sua vez, apenas
> apagava `/Encrypt` do trailer.

---

## Pendencias conhecidas

Levantadas na validacao de agosto/2026, quando a suite passou a ser executada de
verdade contra um banco — **todas as verificacoes passando** — e os PDFs gerados
passaram a ser conferidos por decodificadores reais.

> O numero exato de verificacoes sai desatualizado a cada teste novo e ja errou
> mais vezes do que acertou neste documento; quem quiser o total do momento roda
> `python dev/scripts/run_tests.py`.

| Item | Situacao |
|------|----------|
| ~~**`EncryptPDF` nao cifra os fluxos de conteudo**~~ | **Resolvido.** `sec_cifrar_objetos` aplica RC4 com a chave de cada objeto aos streams e as strings; `DecryptPDF` desfaz. Referencia em `dev/scripts/pdfcrypt_reference/`, validada no MuPDF. |
| ~~**Marcas d'agua e overlays de texto nao sao rasterizados**~~ | **Resolvido.** Cada pagina afetada ganha um objeto de conteudo proprio e um `/Resources` proprio — no PDF do PL_FPDF o `/Resources` e compartilhado por todas as paginas, e mescla-lo espalharia a fonte da marca por todo o documento. Referencia em `dev/scripts/pdfoverlay_reference/`. |
| ~~**Overlay de imagem nao e rasterizado**~~ | **Resolvido.** JPEG entra inteiro como `/DCTDecode`; os IDAT do PNG ja sao zlib, que e o `/FlateDecode` do PDF, entao sao concatenados e declarados com `/Predictor 15`. Referencia em `dev/scripts/pdfimage_reference/`, validada pelos pixels desenhados. |
| ~~**AES**~~ | **Resolvido.** `EncryptPDF` gera e `DecryptPDF` desfaz AES-128 (V4/R4, `AESV2`) e AES-256 (V5/R6, `AESV3`), com as senhas de usuario e de proprietario. O filtro e lido do `/CFM`, nao presumido. Referencia em `dev/scripts/pdfaes_reference/`, validada nos vetores do FIPS-197 e no MuPDF (29/29). |
| ~~**`IsEncrypted` mentia acima de 32 KB**~~ | **Resolvido.** Lia os PRIMEIROS 32767 bytes procurando `/Encrypt`, que fica no trailer. Alem de fazer `DecryptPDF` recusar PDF valido, deixava `EncryptPDF` cifrar de novo um documento grande ja cifrado, sem erro. Passa a usar `DBMS_LOB.INSTR` no BLOB inteiro, comecando pelo fim. Encontrado ao testar o RC4 em fluxo grande. |
| ~~**RC4 nao cifra fluxo grande**~~ | **Resolvido.** O limite real era **16383 bytes**, e nao 32767: `crypto_rc4` monta o resultado em hexadecimal, dois caracteres por byte, e o acumulador de 32767 caracteres estourava com `ORA-06502` sem explicacao. `crypto_rc4_blob` agenda a chave uma vez e carrega S, i e j entre os pedacos — fatiar com `crypto_rc4` reiniciaria a cifra em cada pedaco e produziria lixo. `crypto_rc4` passou a recusar acima do seu teto com `ORA-20864`, em vez de estourar. |
| ~~**Codigos de erro colidem entre dominios**~~ | **Resolvido.** O QR passou para `-20870..-20879` e os codigos de barras para `-20880..-20889`; a manipulacao e a seguranca ficaram onde estavam. Moveu-se o lado que nunca havia sido publicado — a referencia da API nao documentava erro algum para `AddQRCode` e `AddBarcode`, e agora documenta. `check_error_codes.py` roda no CI e falha se um codigo sair da faixa do seu assunto, ou se alguem de fora invadir essas faixas. Tabela de-para no `CHANGELOG.md`. |
| ~~**Opcoes de `OverlayText` parcialmente honradas**~~ | **Resolvido.** `font` (Helvetica/Arial, Times, Courier) e `bold` escolhem o `/BaseFont`, e a pagina declara so as fontes que usa; `width` define a caixa, com quebra de linha dentro dela; `align` e relativo a caixa quando ha `width`, e ao proprio ponto quando nao ha; `zOrder` ordena a emissao, e maior fica por cima. Conferido no MuPDF pela POSICAO do texto — a amostra `overlay_opcoes` distingue 9/9 com alinhamento de 6/9 sem. |
| ~~**Strings literais corrompidas ao cifrar**~~ | **Resolvido, e nao tinha a ver com object streams:** atingia qualquer PDF com titulo, produtor ou texto de anotacao desde que `EncryptPDF` passou a cifrar de verdade. Duas confusoes entre byte e caractere na mesma funcao — `CHR(n)` na escrita e `SUBSTRB(x, k, 1)` na leitura. Ficou porque os fluxos de conteudo sao copiados byte a byte e nao passam por ali, e **nenhuma amostra conferia uma string literal**; as duas amostras novas conferem, e foi assim que apareceu. `sec_cifrar_strings` passou a trabalhar inteiramente em RAW. (`check_byte_chars.py`) |
| ~~**Codigo de barras de boleto**~~ | **Resolvido.** `AddBarcodeBoleto` da extensao passava os 44 digitos do boleto para `'ITF14'`, que exige 13 ou 14 — levantava `ORA-20887` **sempre**, ou seja, nenhum boleto chegou a sair com codigo de barras. `AddBarcode` ganhou a simbologia `'ITF'` (Interleaved 2 of 5 puro, qualquer quantidade PAR de digitos, sem verificador de simbologia — o de controle do boleto fica dentro dos 44, na posicao 5). O `ITF14` passou a ser construido sobre ela. Validado no zxing-cpp, 45/45; o simbolo sai com 114 grupos de barras, o mesmo de um boleto Itau de verdade. O que o `PL_FPDF` passou a cobrir e o **desenho**: a amostra `boleto` recebe os 44 digitos prontos e o zxing os le do PDF renderizado. **Montar** esses digitos e regra de cobranca, e saiu do escopo deste projeto — a extensao `PL_FPDF_BOLETO` fica onde esta, sem cobertura aqui, ate migrar para um projeto proprio. |
| ~~**Imagens que exigem reprocessar pixels**~~ | **Resolvido.** O que destravou foi o inflate, escrito para a xref em stream, mais o `pdf_undo_pred`, que ja desfazia os cinco filtros do PNG. **Canal alfa** (color type 4 e 6): o PDF nao guarda a transparencia dentro do pixel, entao ela vira um segundo objeto de imagem apontado por `/SMask`. **Entrelacado** (Adam7): as sete passagens sao desfiltradas separadamente e o raster e remontado linha a linha. **16 bits** nunca precisou de nada — o PDF aceita `/BitsPerComponent 16` e o predictor tambem; estava recusado por engano. O caminho que reprocessa sai **sem compressao**, porque ha inflate e nao ha deflate, e tem teto de `co_img_max_px` (4 megapixels) porque e O(pixels) em PL/SQL. Referencia em `dev/scripts/pdfimage_reference/`, validada nos PIXELS que o MuPDF desenha (25/25). |
| ~~**xref em stream (PDF 1.5+)**~~ | **Resolvido.** O `UTL_COMPRESS` nao serve (dois diagnosticos), entao o INFLATE (RFC 1951) foi escrito no package e esta provado no banco (`dev/tests/diag_inflate.sql`, 4/4 contra vetores do zlib), exposto por `FlateDecode` com teto de saida contra zip bomb. Sobre ele, `pdf_src_load` passou a ler a **xref em stream** (`/Type /XRef`, com `/W`, `/Index`, `/Prev` e os tres tipos de entrada), os **object streams** (`/Type /ObjStm` — o objeto nao fica num offset do arquivo, e o corpo e materializado na carga) e o **hibrido** (`/XRefStm`), alem do **predictor PNG** nos cinco filtros. Referencia em `dev/scripts/pdfxref_reference/`, validada contra o MuPDF (43/43). **Provado no banco**: `dev/tests/diag_xrefstm.sql` passa 12/12 e a suite inteira fecha sem falha, com as amostras `objstm` e `xref_predictor` conferidas pelo MuPDF. A **cifragem** tambem fechou: `EncryptPDF`/`DecryptPDF` achatam a origem e a saida leva xref classica (`dev/scripts/pdfobjstm_crypt_reference/`, 25/25 no MuPDF). |
| ~~**Quebra automatica virava pagina nova em silencio**~~ | **Resolvido.** A `Cell` do PL_FPDF abre PAGINA NOVA quando `y + altura` passa de 277 (A4 menos a margem inferior de 20 mm). Nao e erro, e comportamento: o rodape do ingresso, posto em 276 com celula de 9 mm, transformava dois ingressos em **seis paginas**, e o sintoma aparecia longe da causa ("6 paginas, esperado 2"). O gatilho virou parte do modelo em `dev/scripts/pdflayout.py` e as duas reguas conferem que nenhuma celula o cruza. |
| ~~**Exemplo e amostra podiam divergir**~~ | **Resolvido.** O mesmo desenho vive no `examples/*.sql` (documentacao) e na amostra do runner (o que roda contra o banco). O conserto do rodape teve de ser aplicado nos dois arquivos, e nada garantia que fosse — um exemplo que desenha diferente do que o teste cobre e pior que exemplo nenhum, porque parece verificado. `check_examples_sync.py` compara as chamadas de desenho por instrucao (quebrar linha nao e divergencia) e roda no CI. |
| ~~**`Triangle` ignorava a orientacao**~~ | **Resolvido.** O `porientation` era aceito e IGNORADO — qualquer valor desenhava a ponta para a direita, e a referencia da API ja prometia as quatro direcoes. Agora up/down/left/right (ou U/D/L/R) apontam para onde dizem, e valor invalido levanta `ORA-20821` em vez de desenhar errado calado. A amostra `formas` confere os **vertices** de cada triangulo, e nao a contagem de operadores: quatro triangulos iguais emitiriam quatro caminhos de tres linhas, exatamente como quatro diferentes. Mudanca incompativel para quem passava `left` — o desenho antigo agora se pede com `right`. A documentacao tambem dizia "equilatero" e "a partir do centro", e nenhuma das duas era verdade. |
| ~~**`SetCompression` era um no-op**~~ | **Resolvido.** Ele perguntava por uma funcao de zlib que o Oracle nao tem (`function_exists('gzcompress')`, que devolvia FALSE sempre) e desligava a compressao — todo PDF saia cru, e o ramo que declarava `/FlateDecode` sem comprimir nada teria produzido arquivo quebrado se alguem o ligasse. Agora ha um DEFLATE (RFC 1951) no package: um bloco com Huffman FIXA e LZ77 guloso, com escape para bloco armazenado quando nao compensa, entao a saida nunca fica maior que a entrada. Referencia em `dev/scripts/pdfdeflate_reference/`, validada contra o zlib (32/32), e `dev/tests/diag_deflate.sql` compara o que o banco produz com ela **byte a byte** — descomprimir e voltar nao bastaria, porque o inflate desta mesma casa toleraria escolhas diferentes. O fluxo sai em HEXADECIMAL, com `/Filter [/ASCIIHexDecode /FlateDecode]`: o documento e montado num CLOB e so vira BLOB no fim, com conversao de charset, e byte binario nao sobrevive a isso. O hexadecimal dobra o comprimido, entao a compressao so e usada quando ainda assim encolhe. |
| ~~**`NVL` onde o PL/SQL nao perdoa**~~ | **Resolvido, e virou lint.** Duas regras. Sobre tabela indexada, `NVL(tab(i), -1)` NAO evita `NO_DATA_FOUND`: o indice e lido primeiro e a excecao sobe antes de o NVL ver qualquer coisa — a linha parece defensiva e falha na primeira posicao nao visitada. Sobre LOB, `NVL(p_data, EMPTY_BLOB())` nem COMPILA (`PLS-00306`), e a mensagem fala de "wrong number or types of arguments" sem dizer que o problema e o tipo. A primeira eu peguei antes de ir ao banco; a segunda custou uma rodada de compilacao. (`check_assoc_nvl.py`) |
| ~~**Adler-32 estourava o `PLS_INTEGER`**~~ | **Resolvido, e virou lint.** `l_b * 65536` com `l_b` ate 65520 da 4 293 918 720 e passa de 2147483647 — `ORA-01426`, em EXECUCAO, sem nome de variavel e embrulhado no `WHEN OTHERS` de quem chamou (apareceu como `p_enddoc: p_putpages: ORA-01426`, tres niveis longe da linha). E a mesma armadilha do `/P` das permissoes, so que la o valor sem sinal vinha de fora e aqui era montado em casa. (`check_pls_overflow.py`) |
| ~~**Separar o package**~~ | **Resolvido.** O body tinha 14.520 linhas e um quinto disso nao era PDF. Saiu `PL_FPDF_UTIL` com **57 subprogramas e 2.609 linhas**: QR Code, codigos de barras, DEFLATE/INFLATE e criptografia. A fronteira foi MEDIDA antes: uma unica chamada para fora (tres linhas de log, que sairam) e um unico estado compartilhado (a tabela byte->hexadecimal, hoje `hex_do_byte`). A API publica do utilitario tem 18 pontos, e dois deles nasceram da separacao — `qr_matriz` e `bc_padrao`, que tiraram do `AddQRCode`/`AddBarcode` a parte que nao desenha. Ordem de instalacao passa a importar (utilitario primeiro) e **isso nao reduz o `ORA-04068`**, como ja estava previsto: recompilar o utilitario invalida o `PL_FPDF`. O que se ganhou foi o arquivo de 14 mil linhas virar 11.868 e 3.021. |
| ~~**Desenho conferido so por conteudo**~~ | **Resolvido.** A amostra `boleto` passava inteira enquanto o valor podia transbordar a caixa, o rotulo sair no corpo errado, a coluna do dinheiro ficar desalinhada e dois textos sairem **um por cima do outro** — nada disso aparece em `get_text()`. A geometria virou regua em `dev/scripts/boleto_reference/`: caixas, corpos, pesos, alinhamentos e a linha de base da `Cell` (`y + 0,5*altura + 0,3*corpo`, mais a margem interna de 1 mm). A regua fecha sozinha contra as metricas reais do Helvetica (nenhum texto mais largo que sua caixa) e a **mesma** funcao `conferir()` e aplicada ao PDF de referencia e ao PDF que sai do banco, campo a campo, nas duas vias — 580 verificacoes. Foi assim que apareceu o nome do pagador e o endereco empilhados: cabiam nas caixas, e so a distancia entre linhas de base denunciou. |
| ~~**Antecipacao de subprograma publico**~~ | **Resolvido, e virou lint.** `PLS-00305`: tres declaracoes antecipadas vieram junto com o codigo para o `PL_FPDF_UTIL` e passaram a apontar para subprogramas que a spec nova declara. A spec ja declara; repetir no body e redeclarar no mesmo escopo. Antecipacao so serve para subprograma PRIVADO chamado antes de ser definido. (`check_spec_body.py`) |
| ~~**Tipo que ficou no outro package**~~ | **Resolvido, e virou lint.** `PLS-00201`: o `PL_FPDF_UTIL` usava `tpi` e `tv4000`, que ficaram no `PL_FPDF` — um package nao herda tipo do outro. Como o `PLS-00371`, este erro **aborta a analise da unidade inteira**, entao ele escondeu o proprio: foram duas rodadas para dois erros que estavam no arquivo ao mesmo tempo. A regra entrou no `check_spec_body.py`: todo tipo usado no body tem de estar declarado no body, na spec, ou ser nativo. |
| ~~**Tipo declarado na spec e no body**~~ | **Resolvido, e virou lint.** O body herda o que a spec declara; redeclarar da `PLS-00371` e **aborta a analise da unidade inteira**, com a mensagem apontando a linha de um vizinho qualquer. Custou uma rodada na separacao do `PL_FPDF_UTIL`: o tipo `tqr` veio junto na mudanca e ja estava na spec nova. A regra entrou no `check_spec_body.py`, que ja lia o par spec/body — sem etapa nova no CI. |

---

## Versoes Planejadas

### v3.2.1 - Security AES ✅ (ago/2026)

Motivacao: o RC4 esta quebrado ha anos e o **PDF 2.0 o removeu da
especificacao**; leitores novos avisam ou recusam. Concluida e verificada
contra o banco.

| Feature | Status |
|---------|--------|
| Referencia Python validada (FIPS-197 + MuPDF) | ✅ 29/29 |
| AES-128 CBC (V4/R4, `AESV2`) — cifragem | ✅ |
| AES-256 CBC (V5/R6, `AESV3`) — cifragem | ✅ |
| IV aleatorio e preenchimento PKCS#5 | ✅ |
| Autoteste do FIPS-197 na sessao (`aes_autoteste`) | ✅ |
| Decifragem de AES em `DecryptPDF` | ✅ |
| Verificacao de senha do R6 (algoritmo 2.B, `/UE` e `/OE`) | ✅ |
| Auto-ajuste da versao do PDF | ✅ (`SetPDFVersion` ja recusa AES abaixo de 1.5/1.7) |

**Pontos que a porta precisou acertar** (todos verificados na referencia antes
da porta, e nenhum deles apareceu como defeito no banco):

- o ramo `nk > 6 and i mod nk = 4` da expansao de chave **so existe no
  AES-256**; sem ele a cifra continua funcionando *consigo mesma* e nenhum outro
  programa a decifra — por isso os vetores do FIPS-197 sao obrigatorios;
- preenchimento PKCS#5 num dado ja multiplo de 16 leva um bloco **inteiro** de
  preenchimento;
- o criterio de parada do algoritmo 2.B (R6) olha o **ultimo byte** do resultado
  da rodada, depois de no minimo 64 voltas;
- **o AES muda o tamanho do stream** (IV + preenchimento), ao contrario do RC4:
  o `/Length` de cada objeto cifrado tem de ser reescrito.

**Custo conhecido:** AES em PL/SQL puro e trabalho de CPU. Mesmo com as tabelas
de multiplicacao pre-calculadas, um bloco de 16 bytes custa cerca de mil
operacoes. Para relatorios comuns nao incomoda; para documentos grandes,
incomoda — e isso precisa estar na documentacao, nao ser descoberto em producao.

---

### xref em stream: o que o item custou

Os experimentos com o `UTL_COMPRESS` fecharam uma porta, mas tambem **reduziram
o escopo** — e foi isso que tornou o item viavel:

O copiador de objetos **nao precisa descomprimir fluxo de conteudo**. Merge,
extract, marca d'agua e overlay copiam os streams byte a byte e acrescentam
conteudo novo; nada disso le o que ja esta la dentro. O inflate seria necessario
so para as estruturas: a **xref em stream** e os **object streams**, que
escondem dicionarios como o Catalog e as paginas.

Essas estruturas sao pequenas — a xref de um documento de cem paginas tem alguns
KB — enquanto um fluxo de conteudo passa facil de centenas. Ou seja, o custo de
CPU do inflate em PL/SQL, que seria proibitivo para conteudo, e aceitavel aqui.

Feito em duas etapas, cada uma com referencia antes da porta. Primeiro o inflate
(leitor de bits, os tres tipos de bloco, Huffman e LZ77 com janela de 32 KB),
validado contra o `zlib`. Depois a leitura das estruturas, validada contra o
MuPDF.

O que a segunda etapa ensinou, e que uma porta feita direto teria custado caro:

- **O predictor nao e compressao.** E uma transformacao aplicada ANTES do
  deflate, e sem desfaze-la o inflate devolve bytes limpos e **errados** —
  offsets plausiveis apontando para o lugar errado. O MuPDF grava xref em stream
  *sem* predictor; Acrobat e Ghostscript gravam com `/Predictor 12`. Validar so
  contra o que o MuPDF gera deixaria justamente o caso comum sem cobertura.
- **O numero no dicionario e so o padrao do compressor.** Quem manda e o byte de
  filtro no inicio de cada linha, entao os cinco filtros do PNG precisam existir
  mesmo com `12` escrito la.
- **Campo de largura zero em `/W` vale o default, e o do TIPO e 1, nao 0.**
  Errar isso faz o arquivo inteiro virar "objetos livres" em silencio.
- **O hibrido (`/XRefStm`) perde objetos sem avisar.** A tabela classica marca
  como LIVRES justamente os objetos que so a xref em stream ao lado enxerga, e o
  arquivo abre assim mesmo.

A porta coube sem um segundo caminho de bytes no copiador porque a especificacao
proibe que um objeto de dentro de um object stream tenha stream: o que sai de la
e **texto**, que e o que `pdf_obj_body` ja devolve.

---

### v3.3.0 - Bookmarks & Links (Q3 2026)

**Prioridade:** Media

| Feature | Status |
|---------|--------|
| `AddLink` / `SetLink` / `Link` em documentos gerados | ✅ **ja existe** |
| Link para URL externo (`/A << /S /URI >>`) | ✅ **ja existe** |
| AddBookmark (outline entries) | Pendente |
| Nested bookmarks | Pendente |
| Named destinations | Pendente |
| GetBookmarks (parse existing) | Pendente |
| Links sobre PDFs **carregados** (via overlay) | Pendente |

> **Correcao da revisao.** As tres primeiras linhas estavam marcadas como
> pendentes, mas `AddLink`, `SetLink` e `Link` existem, e o gerador ja emite
> `/Annots` com `/Subtype /Link` e `/A << /S /URI >>`. O que falta de verdade
> sao os bookmarks (nao ha nada de outline no package) e levar links para
> documentos carregados, que hoje o caminho de overlay nao faz.

---

### v3.4.0 - PDF 1.5/1.6 (Q4 2026)

**Prioridade:** Media

| Feature | Status | Observacao |
|---------|--------|------------|
| Cross-Reference Streams | ✅ (ago/2026) | Leitura completa: `/W`, `/Index`, `/Prev`, os tres tipos de entrada e o predictor PNG nos cinco filtros |
| Object Streams | ✅ (ago/2026) | Leitura completa; o corpo e materializado na carga, porque o objeto nao tem offset no arquivo |
| Hibrido `/XRefStm` | ✅ (ago/2026) | Nao estava previsto e precisava estar: ignora-lo perde objetos **em silencio** |
| `FlateDecode` (descomprimir) | ✅ (ago/2026) | INFLATE (RFC 1951) escrito no package, com teto de saida contra zip bomb |
| Cifrar PDF com object streams | ✅ (ago/2026) | `EncryptPDF` e `DecryptPDF` **achatam** a origem: os objetos de dentro dos object streams viram objetos de primeiro nivel, os `ObjStm`/`XRef` sao descartados e a saida leva xref classica. Na decifragem o object stream e decifrado ANTES de inflado. Referencia em `dev/scripts/pdfobjstm_crypt_reference/`, validada contra o MuPDF (25/25); **provado no banco**, com as amostras `objstm_cifrado` (AES-128) e `objstm_ida_volta` (RC4), que conferem o TITULO — a string que mora dentro do object stream |
| `FlateDecode` (comprimir) | ✅ (ago/2026) | DEFLATE com Huffman fixa e LZ77 guloso, escrito no package; `SetCompression` deixou de ser no-op |
| Tagged PDF (basic) | Pendente | Independente dos anteriores |

> **Nota da revisao.** A versao anterior deste roadmap estimava as tres
> primeiras linhas em "1 semana" cada, ignorando que a raiz e a mesma e que o
> trabalho real era um inflate escrito a mao. O que fechou o item foram tres
> etapas, nessa ordem: **provar que o `UTL_COMPRESS` nao serve** (dois
> diagnosticos), **escrever o inflate** com referencia validada no zlib, e so
> entao **ler as estruturas**, com referencia validada no MuPDF. Nenhuma das
> tres cabia em uma semana, e pular a primeira teria custado as outras duas.

---

### v3.5.0 - AcroForms (Q1 2027)

**Prioridade:** Media

| Feature | Status |
|---------|--------|
| Text fields | Pendente |
| Checkboxes | Pendente |
| Radio buttons | Pendente |
| Dropdown lists | Pendente |
| Form field validation | Pendente |
| Fill existing forms | Pendente |

---

### v4.0.0 - PDF 2.0 (2028)

**Prioridade:** Futura

| Feature | Status |
|---------|--------|
| PDF 2.0 header nativo | Pendente |
| AES-256 sem extensions | Depende de v3.2.1 |
| Digital signatures (PKCS#7) | Pendente |
| PAdES compliance | Pendente |
| PDF/A output | Pendente |
| PDF/UA accessibility | Pendente |
| ZUGFeRD / Factur-X | Pendente |

---

## Documentação da API — mantida à mão

A referência da API (`docs/API_REFERENCE.md`, `docs/API_REFERENCE_EN.md`,
`site/reference.html` e `site/en/reference.html`) já foi gerada por um script que
extraía as assinaturas do `.pks` e as combinava com um arquivo de metadados
curados. O gerador saiu do repositório em agosto/2026: **a documentação é
escrita, não é saída de ferramenta**, e passou a ser mantida à mão como as
demais páginas do site.

O que continua automático é a **conferência**, que é onde o CI ajuda de verdade:

| Verificação | O que cobra |
|-------------|-------------|
| `check_refs.py` | Toda referência `PL_FPDF.*` citada na documentação existe no package |
| `check_links.py` | Todo link e imagem relativa aponta para arquivo que existe |
| `check_paridade.py` | As páginas inglesas acompanham as portuguesas, e nenhuma frase ficou por traduzir |

Duas consequências que valem registro:

- **`parse_spec.py` ficou.** Ele não era do gerador: lê as assinaturas do
  `src/PL_FPDF.pks` e quem o consome é o `check_test_calls.py`. Removê-lo
  derrubaria aquele lint.
- **O `check_error_codes.py` perdeu meia regra.** A segunda regra dele conferia
  os códigos citados no `meta.py`; sem o arquivo, ela simplesmente não roda.

### Divergências encontradas nas revisões

| Item | Situação |
|------|----------|
| `dev/tests/validate_phase_4_complete.sql` chamava `IsPDFLoaded`, `RemoveWatermark` e `ClearWatermarks`, que não existem no package | ✅ Resolvido: o teste passou a usar `GetPageCount` (que levanta `-20809` sem PDF carregado) e a documentar por que as outras duas não existem |
| Verificação automática de referências (`dev/scripts/gen_docs/check_refs.py`) no CI | ✅ Concluído |
| Paridade PT/EN das páginas escritas à mão (`check_paridade.py`) no CI | ✅ Concluído |
| Códigos `ORA-208xx` reutilizados entre QR/barcode e manipulação/segurança | Pendente — ver "Pendencias conhecidas" |

---

## Verificações automáticas no CI

Cada uma nasceu de um erro que custou uma rodada de compilação ou uma execução
no banco, e existe para que ele não volte:

| Verificação | O que pega |
|-------------|------------|
| `check_declarations.py` | Global declarada depois do primeiro subprograma (`PLS-00103`) |
| `check_spec_body.py` | Subprograma da spec sem corpo (`PLS-00323`) — um `/*` órfão já engoliu `AddQRCode` e `AddBarcode` inteiros, 892 linhas de comentário acidental |
| `check_call_order.py` | Chamada a subprograma definido mais abaixo (`PLS-00313`) |
| `check_clob_bytes.py` | `SUBSTRB`/`LENGTHB`/`INSTRB` em CLOB (`ORA-22998` só em execução) e LOB passado a `STANDARD_HASH` (`ORA-00902`, sem dizer qual argumento). Roda em `src/` **e em `dev/tests/`**: o mesmo erro reapareceu num diagnóstico porque a verificação só olhava `src/` |
| `check_error_codes.py` | Código `ORA-208xx` fora da faixa do seu assunto — `ORA-20843` já significava "QR vazio" **e** "xref em stream" |
| `check_dead_code.py` | Declaração privada que ninguém usa — a limpeza de ago/2026 tirou **778 linhas**: 12 subprogramas, 18 constantes e quatro corpos comentados, entre eles o `p_parseImage` antigo (178 linhas) e o fonte **PHP** do `SetLineStyle`, que veio junto na porta do FPDF |
| `check_byte_chars.py` | `CHR(n)` aplicado a um byte — não devolve um byte, devolve o caractere daquele ponto de código, e em AL32UTF8 os valores de 128 a 255 saem com **dois**. Uma string literal de 33 bytes ia para o arquivo com 53, e só o título saía embaralhado. Na mesma família, e mais difícil de ver: dado binário remontado byte a byte com `SUBSTRB(..., 1)` num VARCHAR2 e devolvido a `UTL_RAW.CAST_TO_RAW` |
| avisos do MuPDF (no `run_tests.py`) | Arquivo **malformado que abre assim mesmo**. O MuPDF é tolerante e só avisa; um `endobj` duplicado atravessou texto, pixels, contagem de páginas e estrutura, e só apareceu quando os avisos passaram a contar como falha |

> Nenhum lint pega consumo de memória nem laço infinito: o inflate compilou, passou nos sete, e estourou a PGA três vezes. A causa final não era o inflate — era um `EXIT WHEN INSTR(...) = 0` que nunca dispara quando `INSTR` devolve NULL, num parser de tabela constante de doze linhas. Só a execução revela.
| `check_tables.py` | Tabelas do QR e dos códigos de barras contra as referências validadas — uma linha do `co_bc128` perdeu o separador e só um vetor de teste no banco revelou |
| `check_test_calls.py` | Chamada errada nos testes (`ORA-06550` derruba o arquivo inteiro, não só o caso) |
| `build_run_all.py --check` | `dev/tests/run_all_tests.sql` desatualizado |
| `build_release.py --check` | `dist/pl_fpdf_install.sql` — o arquivo que se baixa por link direto — atrasado em relação a `src/`. Quem instala receberia a versão anterior **sem nenhum sinal**. O gerador recusa também comando de SQL\*Plus (a SQL Window para neles) e `&` seguido de letra, que vira variável de substituição e transforma o instalador em entrada interativa |
| `check_refs.py` + gerador | Documentação divergente do `.pks` |
| `check_links.py` | Link **ou imagem** relativa da documentação apontando para arquivo inexistente — o `CHANGELOG` apontava para um `docs/api/API_REFERENCE.md` que sumiu quando a pasta foi achatada, e as capturas dos exemplos nos READMEs (`<img src>`, não `![]()`) ficaram para trás quando o site saiu da raiz para `site/`: o README continua válido, a imagem é que não aparece |
| `pdfxref_reference/validate.py` | Leitura da xref em stream divergente do MuPDF — o erro que interessa aqui não estoura: um offset lido errado devolve **outro objeto**, com dicionário perfeitamente válido |
| `pdfinflate_reference/validate.py` | INFLATE divergente do `zlib` |

---

## Backlog (Sem Versao Definida)

| Feature | Complexidade | Valor |
|---------|--------------|-------|
| HTML to PDF (subset) | Alta | Alto |
| Table auto-pagination | Media | Alto |
| Annotations (comments) | Media | Baixo |
| JavaScript actions | Alta | Baixo |
| Layers (OCG) | Media | Baixo |

> **Correcao da revisao.** "Headers/Footers automaticos" saiu do backlog:
> `SetHeaderProc` e `SetFooterProc` existem, sao chamados na quebra de pagina e
> tem teste em `dev/tests/test_core.sql`, inclusive para nome de procedimento
> invalido e para tentativa de injecao no callback.

---

## Principios

1. **Oracle 19c sempre suportado** - Nunca quebrar compatibilidade
2. **Package-only** - Sem tabelas, types ou sequences externas
3. **Backward compatible** - APIs existentes nao mudam
4. **Testes primeiro** - Toda feature com testes
5. **Referencia antes da porta** - Para qualquer coisa que um leitor externo
   precise entender (QR, codigo de barras, criptografia, estrutura do PDF),
   primeiro uma referencia em Python **validada contra um decodificador
   independente** (zxing-cpp, MuPDF, vetores do FIPS), e so entao a porta para
   PL/SQL. Foi o que separou "desenha um simbolo" de "um leitor decodifica" e
   "marcado como protegido" de "protegido".
6. **Recusar em vez de entregar errado** - Quando algo nao e suportado, levantar
   erro com mensagem clara. Um PDF marcado como protegido que nao esta, ou uma
   imagem que sai como ruido, custa mais caro que uma excecao.

---

## Como Contribuir

1. Escolha um item do roadmap
2. Abra issue para discussao
3. Implemente com testes
4. Envie Pull Request

**Contato:** @maxwbh | maxwbh@gmail.com
