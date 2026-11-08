# PL_FPDF Roadmap

**Versão Atual:** 3.4.0 | **Atualizado:** 2026-11-07

### Como ler este documento

| Você quer saber | Secao |
|-----------------|-------|
| O que **já foi entregue**, por versão | "Versões Lançadas" |
| Que defeitos existiram e como foram resolvidos | "Pendências resolvidas — histórico" |
| O que **ainda falta**, em ordem de prioridade | "Lacunas priorizadas por uso medido" e "Backlog" |
| O que está **planejado** com versão | "Versões Planejadas" |
| O que **não será feito**, e por que | "Fora de escopo — decidido, não esquecido" |
| O que o CI verifica | "Verificações automáticas no CI" |

Em novembro/2026: a suite passou inteira no Oracle 26ai; a 3.3.0 estável não
funciona lá (`ORA-29275` em todo `SetFont` de fonte padrão); a extensão de
boleto teve o fator de vencimento corrigido e as suites dela passaram a
compilar. Detalhe em `docs/COMPATIBILITY.md` e no `CHANGELOG.md`.


Revisado em 10/09/2026, e antes em 28/08/2026, conferindo cada afirmação contra
o código. As correções estão marcadas ao longo do documento; a mais importante
da primeira revisão e que **v3.0.0 dava marcas d'água e overlays como prontos
desde fevereiro, e eles não desenhavam nada** — só passaram a desenhar depois.

A revisão de setembro achou três inconsistências no próprio documento, e as
três estão corrigidas abaixo: as versões planejadas 3.3.0 e 3.4.0 descreviam
funcionalidades que **não são** as que saíram com esses números; cinco
verificações rodavam no CI sem constar da tabela que diz registrá-las; e as
quatro correções de setembro não estavam nas pendências.

A revisão trouxe também a secao **"Lacunas priorizadas por uso medido"** e o
**"Fora de escopo"**, que estavam num ramo a parte, com os números datados de
8/09/2026 para que ninguém os tome por medição corrente. O **como** de cada
lacuna — lógica, caso de uso e critério de aceite — esta em
`docs/HISTORIAS.md`, uma história por item, e as duas primeiras já saem de lá
concluídas.

---

## Versões Lançadas

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

> **Nota da revisão.** QR Code e códigos de barras estavam marcados como
> prontos, mas até a validação de agosto/2026 o QR preenchia a área de dados com
> um padrão derivado de `dbms_utility.get_hash_value` — desenhava um símbolo que
> nenhum leitor decodificava. Hoje o codificador e o real (ISO/IEC 18004) e o CI
> confere as tabelas contra referências validadas no zxing-cpp.

### v3.0.0 - PDF Manipulation (Fev 2026)

| Feature | Status |
|---------|--------|
| LoadPDF - Carregar PDF existente | ✅ |
| GetPageCount / GetPageInfo | ✅ |
| RotatePage (0, 90, 180, 270) | ✅ |
| RemovePage | ✅ |
| AddWatermark (texto com opacidade) | ✅ *(só desenha desde ago/2026)* |
| OverlayText | ✅ *(só desenha desde ago/2026; ver pendência das opções)* |
| OverlayImage | ✅ *(só desenha desde ago/2026)* |
| OutputModifiedPDF | ✅ |
| MergePDFs | ✅ |
| SplitPDF | ✅ |
| ExtractPages | ✅ |

> **Correção da revisão.** Até agosto/2026 as três últimas linhas de sobreposição
> registravam o pedido em memória e **nada era desenhado**; `OutputModifiedPDF`
> recusava gerar com `ORA-20845`. Marcá-las como prontas em fevereiro foi erro
> do roadmap, não do código — o código era honesto ao recusar.

### Criptografia — API desde a v3.0.0, cifragem de fato desde a v3.3.0

> **Correção (nov/2026).** Esta secao se chamava "v3.2.0 - Security RC4 (Mar
> 2026)". As tags dizem outra coisa: a API abaixo já estava na 3.0.0, e entre a
> 3.0.0 e a 3.2.0 o código só mudou o número de versão — a 3.2.0 (jul/2026)
> trouxe apenas o gerador `docx_to_plfpdf`. E "pronto" só passou a ser verdade
> na 3.3.0, como diz a correção no fim da tabela.

| Feature | Status |
|---------|--------|
| RC4 40-bit encryption | ✅ *(só cifra desde ago/2026)* |
| RC4 128-bit encryption | ✅ *(idem)* |
| Password protection (user/owner) | ✅ |
| Permission controls (8 flags) | ✅ |
| DecryptPDF | ✅ *(só decifra desde ago/2026)* |
| GetSecurityInfo | ✅ |
| SetPDFVersion | ✅ |

> **Correção da revisão.** Mesmo padrão: o dicionário `/Encrypt`, as senhas e as
> permissões estavam corretos, mas os fluxos de conteúdo saiam **em claro** — o
> PDF ficava marcado como protegido sem estar. `DecryptPDF`, por sua vez, apenas
> apagava `/Encrypt` do trailer.

---

### v3.2.1 - Security AES ✅ (ago/2026)

Motivação: o RC4 está quebrado há anos e o **PDF 2.0 o removeu da
especificação**; leitores novos avisam ou recusam. Concluída e verificada
contra o banco.

| Feature | Status |
|---------|--------|
| Referência Python validada (FIPS-197 + MuPDF) | ✅ 29/29 |
| AES-128 CBC (V4/R4, `AESV2`) — cifragem | ✅ |
| AES-256 CBC (V5/R6, `AESV3`) — cifragem | ✅ |
| IV aleatório e preenchimento PKCS#5 | ✅ |
| Autoteste do FIPS-197 na sessão (`aes_autoteste`) | ✅ |
| Decifragem de AES em `DecryptPDF` | ✅ |
| Verificação de senha do R6 (algoritmo 2.B, `/UE` e `/OE`) | ✅ |
| Auto-ajuste da versão do PDF | ✅ (`SetPDFVersion` já recusa AES abaixo de 1.5/1.7) |

**Pontos que a porta precisou acertar** (todos verificados na referência antes
da porta, e nenhum deles apareceu como defeito no banco):

- o ramo `nk > 6 and i mod nk = 4` da expansão de chave **só existe no
  AES-256**; sem ele a cifra continua funcionando *consigo mesma* e nenhum outro
  programa a decifra — por isso os vetores do FIPS-197 são obrigatórios;
- preenchimento PKCS#5 num dado já múltiplo de 16 leva um bloco **inteiro** de
  preenchimento;
- o critério de parada do algoritmo 2.B (R6) olha o **ultimo byte** do resultado
  da rodada, depois de no mínimo 64 voltas;
- **o AES muda o tamanho do stream** (IV + preenchimento), ao contrário do RC4:
  o `/Length` de cada objeto cifrado tem de ser reescrito.

**Custo conhecido:** AES em PL/SQL puro e trabalho de CPU. Mesmo com as tabelas
de multiplicação pre-calculadas, um bloco de 16 bytes custa cerca de mil
operações. Para relatórios comuns não incomoda; para documentos grandes,
incomoda — e isso precisa estar na documentação, não ser descoberto em produção.

---

### xref em stream: o que o item custou

Os experimentos com o `UTL_COMPRESS` fecharam uma porta, mas também **reduziram
o escopo** — e foi isso que tornou o item viável:

O copiador de objetos **não precisa descomprimir fluxo de conteúdo**. Merge,
extract, marca d'água e overlay copiam os streams byte a byte e acrescentam
conteúdo novo; nada disso lê o que já esta lá dentro. O inflate seria necessário
só para as estruturas: a **xref em stream** e os **object streams**, que
escondem dicionários como o Catalog e as páginas.

Essas estruturas são pequenas — a xref de um documento de cem páginas tem alguns
KB — enquanto um fluxo de conteúdo passa fácil de centenas. Ou seja, o custo de
CPU do inflate em PL/SQL, que seria proibitivo para conteúdo, e aceitável aqui.

Feito em duas etapas, cada uma com referência antes da porta. Primeiro o inflate
(leitor de bits, os três tipos de bloco, Huffman e LZ77 com janela de 32 KB),
validado contra o `zlib`. Depois a leitura das estruturas, validada contra o
MuPDF.

O que a segunda etapa ensinou, e que uma porta feita direto teria custado caro:

- **O predictor não é compressão.** É uma transformação aplicada ANTES do
  deflate, e sem desfazê-la o inflate devolve bytes limpos e **errados** —
  offsets plausíveis apontando para o lugar errado. O MuPDF grava xref em stream
  *sem* predictor; Acrobat e Ghostscript gravam com `/Predictor 12`. Validar só
  contra o que o MuPDF gera deixaria justamente o caso comum sem cobertura.
- **O número no dicionário e só o padrão do compressor.** Quem manda e o byte de
  filtro no início de cada linha, então os cinco filtros do PNG precisam existir
  mesmo com `12` escrito lá.
- **Campo de largura zero em `/W` vale o default, e o do TIPO e 1, não 0.**
  Errar isso faz o arquivo inteiro virar "objetos livres" em silêncio.
- **O híbrido (`/XRefStm`) perde objetos sem avisar.** A tabela clássica marca
  como LIVRES justamente os objetos que só a xref em stream ao lado enxerga, e o
  arquivo abre assim mesmo.

A porta coube sem um segundo caminho de bytes no copiador porque a especificação
proíbe que um objeto de dentro de um object stream tenha stream: o que sai de lá
e **texto**, que e o que `pdf_obj_body` já devolve.

---

### v3.3.0 - Instalação em um arquivo e PDF 1.5+ (ago/2026) ✅

Instalador único, `PL_FPDF_UTIL` separado, leitura de xref em stream e object
streams, DEFLATE/INFLATE próprios e licença MIT. Detalhe no `CHANGELOG.md`.

### v3.4.0 - Acentuação, TrueType embutida, Oracle 26ai (nov/2026) ✅

Candidatas v3.4.0-rc1 e rc2; final em 07/11/2026. Acentuação correta nas fontes padrão, TrueType de
fato embutida, `ImageFromBlob`, e a tabela de larguras sem `CHR(i)` — o que a
faz funcionar no Oracle 26ai, onde a 3.3.0 levanta `ORA-29275`. A suite passou
inteira no 19c e no 26ai; as evidências estão em `docs/COMPATIBILITY.md`.

---

## Pendências resolvidas — histórico

> **Tudo nesta tabela está resolvido.** Ela fica como registro do defeito, da
> causa e do conserto. O que **ainda falta** esta em "Lacunas priorizadas por
> uso medido" e no "Backlog"; o que **não será feito**, em "Fora de escopo".

Levantadas na validação de agosto/2026, quando a suite passou a ser executada de
verdade contra um banco — **todas as verificações passando** — e os PDFs gerados
passaram a ser conferidos por decodificadores reais.

> O número exato de verificações sai desatualizado a cada teste novo e já errou
> mais vezes do que acertou neste documento; quem quiser o total do momento roda
> `python dev/scripts/run_tests.py`.

| Item | Situação |
|------|----------|
| ~~**Fonte TrueType registrada não chega ao documento**~~ | **Resolvido em setembro/2026.** O cache `g_ttf_fonts` não tinha consumidor: o `SetFont` nunca o consultava e nada emitia os bytes no PDF. E o `parse_ttf_header` não interpretava o arquivo — `units_per_em := 1000`, `ascent := 800`, `descent := -200` eram literais no código, então um BLOB de 28 bytes devolvia as mesmas métricas de uma fonte real. Agora o parser lê `head`, `hhea`, `hmtx`, `cmap` (formato 4), `OS/2` e `post`; o `SetFont` registra a fonte do cache; o `GetStringWidth` mede pela tabela dela; e o `p_putfonts` emite `/Subtype /TrueType`, o `/FontDescriptor` e o `/FontFile2`. Fonte sem tabela obrigatória e recusada com **-20202**, em vez de inventada. Referência em `dev/scripts/ttfembed_reference/`, validada no MuPDF nos três lados que importam: o texto sai, a fonte está embutida, e a largura que o leitor MEDE bate com a que o `/Widths` declara. O teste usa uma TTF de 716 bytes gerada por `dev/scripts/ttf_reference/gerar.py`, com **2048 unidades por em** de propósito — com upm 1000 não se distinguiria "leu do arquivo" de "chutou a constante de sempre". **Falta o subset (HU-02):** a fonte inteira entra, em hexadecimal, e ocupa o dobro do tamanho dela. |
| ~~**Link interno produz PDF malformado**~~ | **Resolvido por recusa, em setembro/2026; achado na revisão dos comentários.** `Link` com `plink` numérico caia num ramo que **não existe**: o `else` que escreveria o `/Dest` saiu comentado no porte original e nunca voltou, e o dicionário do `/Annot` ficava **aberto** — `<</Type /Annot ... /Border [0 0 0] ]`, sem o `>>`. Não era "link que não navega": era arquivo estruturalmente inválido. E havia um segundo lado, que atingia o caso COMUM: o `Link` estende a coleção até a página corrente, e as páginas anteriores ficavam com entrada vazia; o emissor só testava `.exists(i)`, então um `Link` na página 3 punha `/Annots` quebrado nas páginas 1 e 2, que não pediram link nenhum. Agora `Link` recusa destino que não seja URL com **-20601**, e o emissor exige entrada COM destino. Recusar vale mais que gravar o arquivo que o leitor não abre. Ficou escondido porque **nenhum teste chamava `AddLink` ou `SetLink`** — a HU-05 em forma concreta; há caso de regressão para os dois lados em `dev/tests/test_regressoes_revisao.sql`. E há um TERCEIRO lado, achado ao escrever o teste: o `AddLink` levantava `ORA-06531` — *reference to uninitialized collection* — na linha da própria declaração, porque a coleção `links` e nested table e ninguém a inicializa. **Nunca funcionou, em nenhuma versão.** Os três — `AddLink`, `SetLink` e `Link` com destino numérico — passam a recusar com **-20601** e mensagem que diz o que usar. E um QUARTO, no caminho comum: o `Link` media o quanto estender pelo `.last`, e `.last` de coleção vazia e NULL. Depois de um `Reset` a coleção fica vazia — o `delete` zera a contagem e não anula a coleção —, então `page - NULL` dava NULL, o `IF` não disparava e o `PageLinks(page)` estourava com `ORA-06533` **no primeiro `Link` do segundo documento da sessão**, com URL e tudo. Passa a medir pelo `.count`, que conta zero em coleção vazia. Quem emite em lote passava por isso em toda emissão a partir da segunda. **Continua faltando** escrever o `/Dest` para que o link interno funcione de verdade. |
| ~~**`EncryptPDF` não cifra os fluxos de conteúdo**~~ | **Resolvido.** `sec_cifrar_objetos` aplica RC4 com a chave de cada objeto aos streams e as strings; `DecryptPDF` desfaz. Referência em `dev/scripts/pdfcrypt_reference/`, validada no MuPDF. |
| ~~**Marcas d'água e overlays de texto não são rasterizados**~~ | **Resolvido.** Cada página afetada ganha um objeto de conteúdo próprio e um `/Resources` próprio — no PDF do PL_FPDF o `/Resources` e compartilhado por todas as páginas, e mesclá-lo espalharia a fonte da marca por todo o documento. Referência em `dev/scripts/pdfoverlay_reference/`. |
| ~~**Overlay de imagem não e rasterizado**~~ | **Resolvido.** JPEG entra inteiro como `/DCTDecode`; os IDAT do PNG já são zlib, que é o `/FlateDecode` do PDF, então são concatenados e declarados com `/Predictor 15`. Referência em `dev/scripts/pdfimage_reference/`, validada pelos pixels desenhados. |
| ~~**AES**~~ | **Resolvido.** `EncryptPDF` gera e `DecryptPDF` desfaz AES-128 (V4/R4, `AESV2`) e AES-256 (V5/R6, `AESV3`), com as senhas de usuário e de proprietário. O filtro e lido do `/CFM`, não presumido. Referência em `dev/scripts/pdfaes_reference/`, validada nos vetores do FIPS-197 e no MuPDF (29/29). |
| ~~**`IsEncrypted` mentia acima de 32 KB**~~ | **Resolvido.** Lia os PRIMEIROS 32767 bytes procurando `/Encrypt`, que fica no trailer. Além de fazer `DecryptPDF` recusar PDF valido, deixava `EncryptPDF` cifrar de novo um documento grande já cifrado, sem erro. Passa a usar `DBMS_LOB.INSTR` no BLOB inteiro, começando pelo fim. Encontrado ao testar o RC4 em fluxo grande. |
| ~~**RC4 não cifra fluxo grande**~~ | **Resolvido.** O limite real era **16383 bytes**, e não 32767: `crypto_rc4` monta o resultado em hexadecimal, dois caracteres por byte, e o acumulador de 32767 caracteres estourava com `ORA-06502` sem explicação. `crypto_rc4_blob` agenda a chave uma vez e carrega S, i e j entre os pedaços — fatiar com `crypto_rc4` reiniciaria a cifra em cada pedaço e produziria lixo. `crypto_rc4` passou a recusar acima do seu teto com `ORA-20864`, em vez de estourar. |
| ~~**Códigos de erro colidem entre domínios**~~ | **Resolvido.** O QR passou para `-20870..-20879` e os códigos de barras para `-20880..-20889`; a manipulação e a segurança ficaram onde estavam. Moveu-se o lado que nunca havia sido publicado — a referência da API não documentava erro algum para `AddQRCode` e `AddBarcode`, e agora documenta. `check_error_codes.py` roda no CI e falha se um código sair da faixa do seu assunto, ou se alguém de fora invadir essas faixas. Tabela de-para no `CHANGELOG.md`. |
| ~~**Opções de `OverlayText` parcialmente honradas**~~ | **Resolvido.** `font` (Helvetica/Arial, Times, Courier) e `bold` escolhem o `/BaseFont`, e a página declara só as fontes que usa; `width` define a caixa, com quebra de linha dentro dela; `align` e relativo a caixa quando há `width`, e ao próprio ponto quando não há; `zOrder` ordena a emissão, e maior fica por cima. Conferido no MuPDF pela POSIÇÃO do texto — a amostra `overlay_opcoes` distingue 9/9 com alinhamento de 6/9 sem. |
| ~~**Strings literais corrompidas ao cifrar**~~ | **Resolvido, e não tinha a ver com object streams:** atingia qualquer PDF com título, produtor ou texto de anotação desde que `EncryptPDF` passou a cifrar de verdade. Duas confusões entre byte e caractere na mesma função — `CHR(n)` na escrita e `SUBSTRB(x, k, 1)` na leitura. Ficou porque os fluxos de conteúdo são copiados byte a byte e não passam por ali, e **nenhuma amostra conferia uma string literal**; as duas amostras novas conferem, e foi assim que apareceu. `sec_cifrar_strings` passou a trabalhar inteiramente em RAW. (`check_byte_chars.py`) |
| ~~**Código de barras de boleto**~~ | **Resolvido.** `AddBarcodeBoleto` da extensão passava os 44 dígitos do boleto para `'ITF14'`, que exige 13 ou 14 — levantava `ORA-20887` **sempre**, ou seja, nenhum boleto chegou a sair com código de barras. `AddBarcode` ganhou a simbologia `'ITF'` (Interleaved 2 of 5 puro, qualquer quantidade PAR de dígitos, sem verificador de simbologia — o de controle do boleto fica dentro dos 44, na posição 5). O `ITF14` passou a ser construído sobre ela. Validado no zxing-cpp, 45/45; o símbolo sai com 114 grupos de barras, o mesmo de um boleto Itau de verdade. O que o `PL_FPDF` passou a cobrir e o **desenho**: a amostra `boleto` recebe os 44 dígitos prontos e o zxing os lê do PDF renderizado. **Montar** esses dígitos e regra de cobrança, e saiu do escopo deste projeto — a extensão `PL_FPDF_BOLETO` fica onde esta, sem cobertura aqui, até migrar para um projeto próprio. |
| ~~**Imagens que exigem reprocessar pixels**~~ | **Resolvido.** O que destravou foi o inflate, escrito para a xref em stream, mais o `pdf_undo_pred`, que já desfazia os cinco filtros do PNG. **Canal alfa** (color type 4 e 6): o PDF não guarda a transparência dentro do pixel, então ela vira um segundo objeto de imagem apontado por `/SMask`. **Entrelaçado** (Adam7): as sete passagens são desfiltradas separadamente e o raster e remontado linha a linha. **16 bits** nunca precisou de nada — o PDF aceita `/BitsPerComponent 16` e o predictor também; estava recusado por engano. O caminho que reprocessa sai **sem compressão**, porque há inflate e não há deflate, e tem teto de `co_img_max_px` (4 megapixels) porque é O(pixels) em PL/SQL. Referência em `dev/scripts/pdfimage_reference/`, validada nos PIXELS que o MuPDF desenha (25/25). |
| ~~**xref em stream (PDF 1.5+)**~~ | **Resolvido.** O `UTL_COMPRESS` não serve (dois diagnósticos), então o INFLATE (RFC 1951) foi escrito no package e está provado no banco (`dev/tests/diag_inflate.sql`, 4/4 contra vetores do zlib), exposto por `FlateDecode` com teto de saída contra zip bomb. Sobre ele, `pdf_src_load` passou a ler a **xref em stream** (`/Type /XRef`, com `/W`, `/Index`, `/Prev` e os três tipos de entrada), os **object streams** (`/Type /ObjStm` — o objeto não fica num offset do arquivo, e o corpo e materializado na carga) e o **híbrido** (`/XRefStm`), além do **predictor PNG** nos cinco filtros. Referência em `dev/scripts/pdfxref_reference/`, validada contra o MuPDF (43/43). **Provado no banco**: `dev/tests/diag_xrefstm.sql` passa 12/12 e a suite inteira fecha sem falha, com as amostras `objstm` e `xref_predictor` conferidas pelo MuPDF. A **cifragem** também fechou: `EncryptPDF`/`DecryptPDF` achatam a origem e a saída leva xref clássica (`dev/scripts/pdfobjstm_crypt_reference/`, 25/25 no MuPDF). |
| ~~**Quebra automática virava página nova em silêncio**~~ | **Resolvido.** A `Cell` do PL_FPDF abre PÁGINA NOVA quando `y + altura` passa de 277 (A4 menos a margem inferior de 20 mm). Não e erro, e comportamento: o rodapé do ingresso, posto em 276 com célula de 9 mm, transformava dois ingressos em **seis páginas**, e o sintoma aparecia longe da causa ("6 páginas, esperado 2"). O gatilho virou parte do modelo em `dev/scripts/pdflayout.py` e as duas réguas conferem que nenhuma célula o cruza. |
| ~~**Exemplo e amostra podiam divergir**~~ | **Resolvido.** O mesmo desenho vive no `examples/*.sql` (documentação) e na amostra do runner (o que roda contra o banco). O conserto do rodapé teve de ser aplicado nos dois arquivos, e nada garantia que fosse — um exemplo que desenha diferente do que o teste cobre e pior que exemplo nenhum, porque parece verificado. `check_examples_sync.py` compara as chamadas de desenho por instrução (quebrar linha não é divergência) e roda no CI. |
| ~~**`Triangle` ignorava a orientação**~~ | **Resolvido.** O `porientation` era aceito e IGNORADO — qualquer valor desenhava a ponta para a direita, e a referência da API já prometia as quatro direções. Agora up/down/left/right (ou U/D/L/R) apontam para onde dizem, e valor inválido levanta `ORA-20821` em vez de desenhar errado calado. A amostra `formas` confere os **vértices** de cada triângulo, e não a contagem de operadores: quatro triângulos iguais emitiriam quatro caminhos de três linhas, exatamente como quatro diferentes. Mudança incompatível para quem passava `left` — o desenho antigo agora se pede com `right`. A documentação também dizia "equilátero" e "a partir do centro", e nenhuma das duas era verdade. |
| ~~**`SetCompression` era um no-op**~~ | **Resolvido.** Ele perguntava por uma função de zlib que o Oracle não tem (`function_exists('gzcompress')`, que devolvia FALSE sempre) e desligava a compressão — todo PDF saia cru, e o ramo que declarava `/FlateDecode` sem comprimir nada teria produzido arquivo quebrado se alguém o ligasse. Agora há um DEFLATE (RFC 1951) no package: um bloco com Huffman FIXA e LZ77 guloso, com escape para bloco armazenado quando não compensa, então a saída nunca fica maior que a entrada. Referência em `dev/scripts/pdfdeflate_reference/`, validada contra o zlib (32/32), e `dev/tests/diag_deflate.sql` compara o que o banco produz com ela **byte a byte** — descomprimir e voltar não bastaria, porque o inflate desta mesma casa toleraria escolhas diferentes. O fluxo sai em HEXADECIMAL, com `/Filter [/ASCIIHexDecode /FlateDecode]`: o documento e montado num CLOB e só vira BLOB no fim, com conversão de charset, e byte binário não sobrevive a isso. O hexadecimal dobra o comprimido, então a compressão só e usada quando ainda assim encolhe. |
| ~~**`NVL` onde o PL/SQL não perdoa**~~ | **Resolvido, e virou lint.** Duas regras. Sobre tabela indexada, `NVL(tab(i), -1)` NÃO evita `NO_DATA_FOUND`: o índice e lido primeiro e a exceção sobe antes de o NVL ver qualquer coisa — a linha parece defensiva e falha na primeira posição não visitada. Sobre LOB, `NVL(p_data, EMPTY_BLOB())` nem COMPILA (`PLS-00306`), e a mensagem fala de "wrong number or types of arguments" sem dizer que o problema e o tipo. A primeira eu peguei antes de ir ao banco; a segunda custou uma rodada de compilação. (`check_assoc_nvl.py`) |
| ~~**Adler-32 estourava o `PLS_INTEGER`**~~ | **Resolvido, e virou lint.** `l_b * 65536` com `l_b` até 65520 da 4 293 918 720 e passa de 2147483647 — `ORA-01426`, em EXECUÇÃO, sem nome de variável e embrulhado no `WHEN OTHERS` de quem chamou (apareceu como `p_enddoc: p_putpages: ORA-01426`, três níveis longe da linha). E a mesma armadilha do `/P` das permissões, só que lá o valor sem sinal vinha de fora e aqui era montado em casa. (`check_pls_overflow.py`) |
| ~~**Separar o package**~~ | **Resolvido.** O body tinha 14.520 linhas e um quinto disso não era PDF. Saiu `PL_FPDF_UTIL` com **57 subprogramas e 2.609 linhas**: QR Code, códigos de barras, DEFLATE/INFLATE e criptografia. A fronteira foi MEDIDA antes: uma única chamada para fora (três linhas de log, que saíram) e um único estado compartilhado (a tabela byte->hexadecimal, hoje `hex_do_byte`). A API pública do utilitário tem 18 pontos, e dois deles nasceram da separação — `qr_matriz` e `bc_padrao`, que tiraram do `AddQRCode`/`AddBarcode` a parte que não desenha. Ordem de instalação passa a importar (utilitário primeiro) e **isso não reduz o `ORA-04068`**, como já estava previsto: recompilar o utilitário invalida o `PL_FPDF`. O que se ganhou foi o arquivo de 14 mil linhas virar 11.868 e 3.021. |
| ~~**Desenho conferido só por conteúdo**~~ | **Resolvido.** A amostra `boleto` passava inteira enquanto o valor podia transbordar a caixa, o rótulo sair no corpo errado, a coluna do dinheiro ficar desalinhada e dois textos saírem **um por cima do outro** — nada disso aparece em `get_text()`. A geometria virou régua em `dev/scripts/boleto_reference/`: caixas, corpos, pesos, alinhamentos e a linha de base da `Cell` (`y + 0,5*altura + 0,3*corpo`, mais a margem interna de 1 mm). A régua fecha sozinha contra as métricas reais do Helvetica (nenhum texto mais largo que sua caixa) e a **mesma** função `conferir()` e aplicada ao PDF de referência e ao PDF que sai do banco, campo a campo, nas duas vias — 580 verificações. Foi assim que apareceu o nome do pagador e o endereço empilhados: cabiam nas caixas, e só a distância entre linhas de base denunciou. |
| ~~**Antecipação de subprograma publico**~~ | **Resolvido, e virou lint.** `PLS-00305`: três declarações antecipadas vieram junto com o código para o `PL_FPDF_UTIL` e passaram a apontar para subprogramas que a spec nova declara. A spec já declara; repetir no body e redeclarar no mesmo escopo. Antecipação só serve para subprograma PRIVADO chamado antes de ser definido. (`check_spec_body.py`) |
| ~~**Tipo que ficou no outro package**~~ | **Resolvido, e virou lint.** `PLS-00201`: o `PL_FPDF_UTIL` usava `tpi` e `tv4000`, que ficaram no `PL_FPDF` — um package não herda tipo do outro. Como o `PLS-00371`, este erro **aborta a análise da unidade inteira**, então ele escondeu o próprio: foram duas rodadas para dois erros que estavam no arquivo ao mesmo tempo. A regra entrou no `check_spec_body.py`: todo tipo usado no body tem de estar declarado no body, na spec, ou ser nativo. |
| ~~**Tipo declarado na spec e no body**~~ | **Resolvido, e virou lint.** O body herda o que a spec declara; redeclarar da `PLS-00371` e **aborta a análise da unidade inteira**, com a mensagem apontando a linha de um vizinho qualquer. Custou uma rodada na separação do `PL_FPDF_UTIL`: o tipo `tqr` veio junto na mudança e já estava na spec nova. A regra entrou no `check_spec_body.py`, que já lia o par spec/body — sem etapa nova no CI. |
| ~~**Texto acentuado saia com dois glifos**~~ | **Resolvido.** O dicionário da fonte declarava `/Encoding /WinAnsiEncoding` e o texto entrava cru, em AL32UTF8: cada acentuado chegava ao leitor como DOIS bytes e ele desenhava dois glifos — sem erro, num arquivo que abre. A medição derrubou as duas suposições do relato: a tabela de larguras estava **íntegra** (256 chaves distintas), e o sintoma não era medida errada e sim `ORA-06502`, porque `subtype car is varchar2(1)` e UM byte e o `a` com til tem dois. Como `Cell` só mede para `align` C e R, alinhado a esquerda desenhava errado calado e centralizado LEVANTAVA. A tabela cp1252 saiu do codec do Python e foi conferida no MuPDF (217 de 217 posições desenháveis); o byte sai como escape OCTAL, que é ASCII e atravessa o CLOB — a mesma lição do stream de imagem. `SetUTF8Enabled`/`IsUTF8Enabled` saíram da spec: não faziam nada. (`check_byte_chars.py`, regra 4) |
| ~~**`Image()` recusava todo PNG em AL32UTF8**~~ | **Resolvido.** Não era `ORA-29275`, como o relato supunha: o `UTL_RAW.CAST_TO_VARCHAR2` não levanta sobre binário. A assinatura era montada com `chr(137) \|\| 'PNG'`, que em AL32UTF8 nunca casa com os oito bytes do arquivo — e o parser recusava com `Not a PNG file`, uma mensagem que manda procurar defeito **no arquivo**. Todo o percurso binário do `p_parseImage` passou a RAW, com a assinatura vindo de `HEXTORAW`. |
| ~~**Stream de imagem em hexadecimal não declarado**~~ | **Resolvido.** O `p_putstream` lia o BLOB para buffer `VARCHAR2`: a sobrecarga de BLOB entrega RAW, e a conversão implícita devolve hexadecimal — 2000 bytes viravam 4000 caracteres. O hexadecimal era a codificação CERTA (o documento e montado num CLOB, e byte acima de 0x7F não sobrevive: medido, 256 entram e 422 saem), mas era acidental e sem `/ASCIIHexDecode`. Mais dois defeitos nas mesmas seis linhas: o laço parava um byte antes do fim, e o tamanho do pedaço era `IN OUT` e ficava preso na primeira leitura curta. (`check_byte_chars.py`, regra 3) |
| ~~**Documento em paisagem contaminava o seguinte**~~ | **Resolvido.** O `Reset` limpava fontes, imagens, links e metadados — e deixava de fora o `OrientationChanges`, que diz quais páginas ganham `/MediaBox` próprio. Como e indexado pelo NÚMERO da página, o índice 1 de um documento virava o índice 1 do próximo: quem gerasse um documento com a página 1 em paisagem deixava **todo documento posterior da mesma sessão** com a página 1 em paisagem. Conteúdo desenhado fora do papel, arquivo que abre EM BRANCO, sem erro nenhum. Doze amostras caíram juntas e o sintoma não acusava a causa — a página 1 saia errada e as demais certas, porque só o índice reaproveitado colide. O que fechou foi ler o arquivo gerado: `-30 bytes` por documento depois do conserto, exatamente o `/MediaBox` que sobrava. |

---

## Versões Planejadas

### Bookmarks & Links — sem versão definida

> **Corrigido na revisão de setembro.** Esta secao dizia "v3.3.0 (Q3 2026)", e
> a 3.3.0 **já saiu** — com instalação em um arquivo, separação do
> `PL_FPDF_UTIL` e documentação em inglês, nada disto aqui. Número de versão
> planejado que o lançamento não cumpre e pior que não ter número: quem lê
> acredita que os bookmarks vieram na 3.3.0.
>
> O item continua valendo, sem número, até ser agendado de novo.

**Prioridade:** Media

| Feature | Status |
|---------|--------|
| `AddLink` / `SetLink` / `Link` em documentos gerados | ✅ **já existe** |
| Link para URL externo (`/A << /S /URI >>`) | ✅ **já existe** |
| AddBookmark (outline entries) | Pendente |
| Nested bookmarks | Pendente |
| Named destinations | Pendente |
| GetBookmarks (parse existing) | Pendente |
| Links sobre PDFs **carregados** (via overlay) | Pendente |

> **Correção da revisão.** As três primeiras linhas estavam marcadas como
> pendentes, mas `AddLink`, `SetLink` e `Link` existem, e o gerador já emite
> `/Annots` com `/Subtype /Link` e `/A << /S /URI >>`. O que falta de verdade
> são os bookmarks (não há nada de outline no package) e levar links para
> documentos carregados, que hoje o caminho de overlay não faz.

---

### PDF 1.5/1.6 — leitura pronta, escrita sem versão definida

> **Corrigido na revisão de setembro.** Dizia "v3.4.0 (Q4 2026)", e a 3.4.0
> **já saiu** — com a conversão WinAnsi, o `ImageFromBlob` e o conserto do
> caminho de imagem. A parte de LEITURA desta secao, marcada abaixo, entrou na
> 3.2.1 de agosto; o que falta e a ESCRITA, e ela segue sem número.

**Prioridade:** Media

| Feature | Status | Observação |
|---------|--------|------------|
| Cross-Reference Streams | ✅ (ago/2026) | Leitura completa: `/W`, `/Index`, `/Prev`, os três tipos de entrada e o predictor PNG nos cinco filtros |
| Object Streams | ✅ (ago/2026) | Leitura completa; o corpo e materializado na carga, porque o objeto não tem offset no arquivo |
| Híbrido `/XRefStm` | ✅ (ago/2026) | Não estava previsto e precisava estar: ignorá-lo perde objetos **em silêncio** |
| `FlateDecode` (descomprimir) | ✅ (ago/2026) | INFLATE (RFC 1951) escrito no package, com teto de saída contra zip bomb |
| Cifrar PDF com object streams | ✅ (ago/2026) | `EncryptPDF` e `DecryptPDF` **achatam** a origem: os objetos de dentro dos object streams viram objetos de primeiro nível, os `ObjStm`/`XRef` são descartados e a saída leva xref clássica. Na decifragem o object stream e decifrado ANTES de inflado. Referência em `dev/scripts/pdfobjstm_crypt_reference/`, validada contra o MuPDF (25/25); **provado no banco**, com as amostras `objstm_cifrado` (AES-128) e `objstm_ida_volta` (RC4), que conferem o TÍTULO — a string que mora dentro do object stream |
| `FlateDecode` (comprimir) | ✅ (ago/2026) | DEFLATE com Huffman fixa e LZ77 guloso, escrito no package; `SetCompression` deixou de ser no-op |
| Tagged PDF (basic) | Pendente | Independente dos anteriores |

> **Nota da revisão.** A versão anterior deste roadmap estimava as três
> primeiras linhas em "1 semana" cada, ignorando que a raiz e a mesma e que o
> trabalho real era um inflate escrito a mão. O que fechou o item foram três
> etapas, nessa ordem: **provar que o `UTL_COMPRESS` não serve** (dois
> diagnósticos), **escrever o inflate** com referência validada no zlib, e só
> então **ler as estruturas**, com referência validada no MuPDF. Nenhuma das
> três cabia em uma semana, e pular a primeira teria custado as outras duas.

---

### v3.5.0 - AcroForms (Q1 2027)

**Prioridade:** Media

| Feature | Status |
|---------|--------|
| Text fields | Pendente |
| Checkboxes | Pendente |
| Rádio buttons | Pendente |
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

## Documentação da API — gerada de novo, e por outro motivo

**Esta seção dizia o contrário até outubro/2026**, e vale contar por quê: um
gerador antigo extraía as assinaturas do `.pks` e as combinava com metadados
curados; ele saiu do repositório em agosto/2026, sob o argumento de que
documentação se escreve, não sai de ferramenta.

O argumento estava certo sobre o **texto** e errado sobre o **fato**. Escritas
à mão, as páginas divergiram do package sem quebrar nada: **38 APIs** levantavam
erro que a referência não listava (`Init` sem `-20001`, `SetFont` sem `-20005`,
`Cell` sem `-20100`), as **18 APIs** do `PL_FPDF_UTIL` não tinham seção nenhuma,
e o comando de download da página inicial buscava a **v3.3.0** três parágrafos
abaixo da vitrine que anunciava 3.4.0.

A volta foi feita com a distinção que faltava:

* **o que é fato sai da spec** — assinatura, tipo, valor padrão, retorno e todo
  código de erro vêm do Javadoc de `src/*.pks`, que o `check_spec_comments.py`
  já cobra;
* **o que é editorial continua escrito**, só que **uma vez**: o grupo de cada
  API e o "veja também" em `meta.py`, o texto em inglês em `textos_en.py`, o
  índice de uso em `conteudo_api.py`, a página inicial em `conteudo_index.py`.
  O desenho de cada página fica num molde HTML, editável à mão.

São **oito** páginas geradas: `docs/API_REFERENCE.md` e `_EN.md`,
`site/reference.html`, `site/api.html`, `site/index.html` e as três
correspondentes em `site/en/`. O que o gerador cobra, além de estarem em dia:
que o inglês não tenha sido escrito contra um português que mudou depois, e que
o exemplo seja o mesmo código nas duas línguas — fora comentário, literal e nome
de variável local, que mudam por direito.

O que continua automático é a **conferência**, que é onde o CI ajuda de verdade:

| Verificação | O que cobra |
|-------------|-------------|
| `check_refs.py` | Toda referência `PL_FPDF.*` citada na documentação existe no package |
| `check_links.py` | Todo link e imagem relativa aponta para arquivo que existe |
| `check_escape_pdf.py` | Mais de uma rotina escapando string literal de PDF. Existiam cinco, e TRÊS estavam erradas — procuravam `'\\\\'` e trocavam por `'\\\\\\\\'`, ou seja, duas barras por quatro, e a barra sozinha, que é o caso comum, passava intacta |
| `check_heranca.py` | Mede quanto do fonte de 2017 ainda vive em `src/` e **trava o número**: a herança só pode diminuir |
| `check_lob_temp.py` | LOB temporário devolvido por função e não liberado por quem chama — vazamento que só aparece sob carga |
| `check_undeclared.py` | Chamada a subprograma que não existe (`PLS-00201`), que aborta a análise da unidade inteira e esconde o erro seguinte |
| `check_v_estatico.py` | `V$`/`GV$`/`DBA_` em SQL estático dentro de PL/SQL: compila no ambiente de quem tem o grant e falha no do usuário |
| `check_suite.py` | Arquivo de teste fora da lista do `build_run_all.py` — existe, compila, afere e **nunca roda** —, e dialeto fora do vocabulário canônico (`caso`, `passou`, `falhou`, `pulou`, `confere`). Achou dois arquivos que imprimiam `✓ Test 1: nome - PASS` em vez de `[PASS]`: o runner contava **zero** verificação para eles, e 65 aferições eram invisíveis |
| `check_atribuicao.py` | Atribuição que começa antes de a anterior terminar — falta o `;`. Um gerador emitia o hexadecimal de uma fonte com uma atribuição por linha e nenhum terminador: o Oracle recusa o **bloco anônimo inteiro** com `ORA-06550`, apontando a linha de baixo, e 60 casos que passavam deixaram de rodar. Nenhuma outra verificação daqui analisa sintaxe |
| `check_spec_comments.py` | API pública sem bloco de documentação na spec, ou com o bloco fora do formato. Na revisão de setembro **metade da API não tinha bloco** — 56 documentados contra 64 sem nenhum —, e os 64 eram os mais chamados: `Cell`, `SetFont`, `Text`, `Line`, `Output`. O que tinha vinha em três dialetos, e o leitor trocava de idioma três vezes descendo o arquivo |
| `check_body_comments.py` | Subprograma **privado** sem comentário — o body é o único lugar onde ele pode ser documentado, e 27 não tinham uma linha. Também pega comentário em inglês ou francês herdado do porte, código comentado (nove trechos, um deles o ramo do `/Dest` que nunca funcionou) e **comentário que aponta para arquivo do repositório**: o comentário vive sozinho, porque endereço envelhece — quando `scripts/` virou `dev/scripts/`, doze ficaram apontando para o nada. Pega também **cabeçalho órfão** — `-- xpto :` seguido de outro subprograma —, que é o rastro que a separação dos packages deixou: o código foi para o outro arquivo e a documentação ficou, então o leitor lê a descrição de `xpto` e o corpo de outra coisa |
| `generate.py --check` | Qualquer uma das **oito** páginas geradas fora de dia com a sua origem: as quatro da referência com o Javadoc da spec, as de uso e as iniciais com `conteudo_api.py` e `conteudo_index.py`. Enquanto foram escritas à mão divergiram sem quebrar nada: **38 APIs** levantavam erro que a página não listava — `Init` sem `-20001`, `SetFont` sem `-20005` —, as **18 APIs** do `PL_FPDF_UTIL` não tinham seção nenhuma, e o link de download da página inicial pedia a versão anterior à que a mesma página anunciava. Pega também o inglês escrito contra um português que mudou depois, e exemplo cujo código deixou de ser o mesmo nas duas línguas |
| `check_roadmap_ci.py` | Esta tabela prometendo mais, ou menos, do que o `ci.yml` roda. Na revisão de setembro eram 21 passos para 16 entradas — a deriva e silenciosa por construção: acrescentar um passo no CI não obriga a tabela a acompanhar |
| `check_paridade.py` | As páginas inglesas acompanham as portuguesas, e nenhuma frase ficou por traduzir |

Duas consequências que valem registro:

- **`parse_spec.py` sobreviveu aos dois movimentos.** Ele não era do gerador
  antigo: lê as assinaturas de `src/*.pks`, e quem o consome também é o
  `check_test_calls.py`. Removê-lo derrubaria aquele lint.
- **O `check_error_codes.py` recuperou a meia regra, em outro lugar.** A segunda
  regra dele conferia os códigos citados no `meta.py`; sem o arquivo ela parou
  de rodar. Hoje ela confere contra o `@raises` da **spec**, que é fonte melhor:
  o código documentado está ao lado do subprograma que o levanta.

### Divergências encontradas nas revisões

| Item | Situação |
|------|----------|
| `dev/tests/test_manipulacao_completa.sql` chamava `IsPDFLoaded`, `RemoveWatermark` e `ClearWatermarks`, que não existem no package | ✅ Resolvido: o teste passou a usar `GetPageCount` (que levanta `-20809` sem PDF carregado) e a documentar por que as outras duas não existem |
| Verificação automática de referências (`dev/scripts/gen_docs/check_refs.py`) no CI | ✅ Concluído |
| Paridade PT/EN das páginas (`check_paridade.py`) no CI | ✅ Concluído — e desde outubro/2026 as páginas saem do mesmo material, então a paridade passou a ser consequência, não vigilância |
| Códigos `ORA-208xx` reutilizados entre QR/barcode e manipulação/segurança | Pendente — ver "Pendências conhecidas" |

---

## Verificações automáticas no CI

Cada uma nasceu de um erro que custou uma rodada de compilação ou uma execução
no banco, e existe para que ele não volte:

| Verificação | O que pega |
|-------------|------------|
| `check_declarations.py` | Global declarada depois do primeiro subprograma (`PLS-00103`) |
| `check_block_declarations.py` | A mesma regra do lado dos testes: item declarado depois do primeiro subprograma local de um bloco anônimo. O `ORA-06550` aponta a linha da declaração, não a do subprograma que a invalidou — e nenhum lint olhava para `dev/tests/*.sql`, então só quebrou depois de conectar ao banco |
| `check_spec_body.py` | Subprograma da spec sem corpo (`PLS-00323`) — um `/*` órfão já engoliu `AddQRCode` e `AddBarcode` inteiros, 892 linhas de comentário acidental |
| `check_call_order.py` | Chamada a subprograma definido mais abaixo (`PLS-00313`) |
| `check_clob_bytes.py` | `SUBSTRB`/`LENGTHB`/`INSTRB` em CLOB (`ORA-22998` só em execução) e LOB passado a `STANDARD_HASH` (`ORA-00902`, sem dizer qual argumento). Roda em `src/` **e em `dev/tests/`**: o mesmo erro reapareceu num diagnóstico porque a verificação só olhava `src/` |
| `check_error_codes.py` | Código `ORA-208xx` fora da faixa do seu assunto — `ORA-20843` já significava "QR vazio" **e** "xref em stream" |
| `check_dead_code.py` | Declaração privada que ninguém usa — a limpeza de ago/2026 tirou **778 linhas**: 12 subprogramas, 18 constantes e quatro corpos comentados, entre eles o `p_parseImage` antigo (178 linhas) e o fonte **PHP** do `SetLineStyle`, que veio junto na porta do FPDF |
| `check_byte_chars.py` | `CHR(n)` aplicado a um byte — não devolve um byte, devolve o caractere daquele ponto de código, e em AL32UTF8 os valores de 128 a 255 saem com **dois**. Uma string literal de 33 bytes ia para o arquivo com 53, e só o título saía embaralhado. Na mesma família, e mais difícil de ver: dado binário remontado byte a byte com `SUBSTRB(..., 1)` num VARCHAR2 e devolvido a `UTL_RAW.CAST_TO_RAW`. E a terceira família da mesma confusão: buffer `VARCHAR2` alimentado por `DBMS_LOB.READ` sobre `BLOB` — a sobrecarga entrega `RAW` e a conversão implícita devolve hexadecimal —, mais assinatura binária montada com `CHR` de literal acima de 127, que fazia o parser recusar todo PNG com uma mensagem culpando o arquivo |
| avisos do MuPDF (no `run_tests.py`) | Arquivo **malformado que abre assim mesmo**. O MuPDF é tolerante e só avisa; um `endobj` duplicado atravessou texto, pixels, contagem de páginas e estrutura, e só apareceu quando os avisos passaram a contar como falha |

> Nenhum lint pega consumo de memória nem laço infinito: o inflate compilou, passou nos sete, e estourou a PGA três vezes. A causa final não era o inflate — era um `EXIT WHEN INSTR(...) = 0` que nunca dispara quando `INSTR` devolve NULL, num parser de tabela constante de doze linhas. Só a execução revela.
| `check_tables.py` | Tabelas do QR e dos códigos de barras contra as referências validadas — uma linha do `co_bc128` perdeu o separador e só um vetor de teste no banco revelou |
| `check_test_calls.py` | Chamada errada nos testes (`ORA-06550` derruba o arquivo inteiro, não só o caso) |
| `build_run_all.py --check` | `dev/tests/run_all_tests.sql` desatualizado |
| `build_release.py --check` | `dist/pl_fpdf_install.sql` — o arquivo que se baixa por link direto — atrasado em relação a `src/`. Quem instala receberia a versão anterior **sem nenhum sinal**. O gerador recusa também comando de SQL\*Plus (a SQL Window para neles) e `&` seguido de letra, que vira variável de substituição e transforma o instalador em entrada interativa |
| `check_refs.py` + gerador | Documentação divergente do `.pks` |
| `check_paridade_md.py` | Guia em inglês com seção, linha de tabela ou exemplo a menos que o português — o `README_EN` passou meses sem a seção de Limitações, e nada reclamava |
| `check_extensao_api.py` | Referência do README da extensão divergente da spec dela — documentava `CalcularFatorVencimento(p_date) RETURN NUMBER` para uma função que se chama `CalculateFatorVencimento(p_data) RETURN VARCHAR2`, e seis rotinas nem apareciam |
| `check_exemplos_doc.py` + fase `--docs` do `run_tests.py` | Exemplo da documentação que não compila ou levanta — o de `EncryptPDF` usava duas variáveis que não declarava. Sem banco, o CI confere que todo bloco que não tem como rodar sozinho (APEX, OWA, tabela do usuário) está marcado; o runner executa os outros contra o Oracle, com ROLLBACK |
| `rastreabilidade.py --check` | `docs/TRACEABILITY.md` desatualizado: cada API pública e o teste ou a amostra que a exercita. Confere também que a tabela de cobertura do `COMPATIBILITY.md` cita todo `test_*.sql` |
| `check_licencas.py` | Declaração de licença que não é MIT — o README da extensão PIX/Boleto dizia "GNU General Public License v2, a mesma do PL_FPDF core", com selo GPL no topo. GPL só passa como história do porte de 2017 |
| `check_publicacao.py` (sem rede no CI; `--online` antes de publicar o site e toda semana) | Site anunciando uma versão que o código ou os releases desmentem — dizia "3.4.0 — versão atual" com a 3.4.0 ainda candidata e o download entregando a 3.3.0. Cobra o chip, o destaque, o `softwareVersion`, o aviso de candidata e os selos dos READMEs contra o `co_version` e a estratégia do `conteudo_index`; com rede, que a estável existe e é o `latest`, e que a candidata existe como pré-lançamento |
| `check_acentos.py` | Português sem acento nos `.md` e nos comentários do código. Duas levas inteiras entraram assim, na 3.3.0 e na 3.4.0 — 5.222 palavras em 134 arquivos —: o texto nascia sem acento no comentário e na mensagem de commit e migrava para a documentação, e nenhum lint conferia acento |
| `check_spec_comments.py`, regra 8 | API pública sem `@since X.Y.Z`. Os valores saíram das tags do git, spec a spec; a referência mostra a versão de cada API e marca o que só existe na candidata |
| `check_links_externos.py` (semanal e a cada release, em workflow próprio) | Link da documentação para release, asset, `dist/` cru ou site que não responde — o README continua válido, e quem segue a instalação recebe 404. Fora do push de propósito: rede a cada commit deixaria o CI instável |
| `check_links.py` | Link **ou imagem** relativa da documentação apontando para arquivo inexistente — o `CHANGELOG` apontava para um `docs/api/API_REFERENCE.md` que sumiu quando a pasta foi achatada, e as capturas dos exemplos nos READMEs (`<img src>`, não `![]()`) ficaram para trás quando o site saiu da raiz para `site/`: o README continua válido, a imagem é que não aparece |
| `pdfxref_reference/validate.py` | Leitura da xref em stream divergente do MuPDF — o erro que interessa aqui não estoura: um offset lido errado devolve **outro objeto**, com dicionário perfeitamente válido |
| `pdfinflate_reference/validate.py` | INFLATE divergente do `zlib` |

---

## Lacunas priorizadas por uso medido

DOCUMENTO DE MANUTENÇÃO.

Esta secao existe para responder uma pergunta só: **entre o que falta, o que é
de fato usado?** A ordem abaixo não saiu de opinião — saiu de três medições
independentes, e ela **contradisse** a ordem que este mesmo documento teria
proposto por intuição. O item que a intuição punha em terceiro caiu para o
backlog quando o número apareceu.

O **como** de cada item — lógica, caso de uso, critério de aceite e as
armadilhas conhecidas — esta em `docs/HISTORIAS.md`, uma história por lacuna.
Esta secao fica com o **o que** e o **em que ordem**.

> **Os números de DEMANDA desta secao são de 8 de setembro de 2026, e não
> foram remedidos.** Servem para ordenar a fila, não como medição corrente:
> quem precisar deles para decidir alguma coisa hoje refaz a contagem antes. O
> que mudou desde então esta dito item a item — o item 1 saiu na 3.4.0.

> **O ESTADO de cada item foi reconferido no código em 13/09/2026**, e e o que
> está escrito abaixo. O que se olhou, e o que se achou:
>
> | Item | Como se conferiu | Estado |
> |---|---|---|
> | 1. WinAnsi | tabela cp1252 no `.pkb`, recusa `ORA-20203`, `test_winansi.sql` | **concluído** |
> | 2. Subset de TTF | `/FontFile2` sai, e o próprio código diz "sem subset: a fonte inteira vai" | ausente, como descrito |
> | 3. Sumario e marcadores | nenhuma ocorrência de `/Outlines` no gerador | ausente |
> | 4. PDF marcado | nenhuma ocorrência de `/StructTreeRoot` | ausente, e no backlog |
> | Achado da API | 118 das 119 públicas com chamador | praticamente fechado |
>
> Nenhum item mudou de estado sem estar dito aqui — reconferir e barato, e
> supor que a fila continua válida porque foi verdade em setembro não e.

### Como foi medido

**Fonte A — o que o mercado precisa ver demonstrado.** Levantamento de
demanda sobre um catálogo comercial de referência do mesmo nicho: 174 casos
de exemplo, agrupados por tema. Quem vende suporte escreve exemplo para o que
o cliente pergunta, então a distribuição dos exemplos e um retrato barato da
demanda atendida. O levantamento e **quantitativo e de superfície** — conta
casos por tema, nada além disso.

**Fonte B — o que esta base já exercita.** APIs distintas chamadas em
`examples/` e `dev/tests/`: **69 das 138 públicas**. Metade da superfície
pública não tem um só chamador no repositório — achado próprio, tratado
adiante.

**Fonte C — impacto medido, quando da para medir.** Para o subset de fonte,
`fontTools` sobre as fontes reais e o conjunto de caracteres que os exemplos
desta base de fato usam (106 distintos).

### O retrato da demanda (8/set/2026)

| Tema | Casos (fonte A) | Temos? |
|------|----------------:|--------|
| Célula / linha / tabela      | 31 | Parcial — `Cell` e `MultiCell`; sem tabela com quebra automática |
| XHTML -> PDF                 | 14 | *Fora de escopo — outro produto* |
| Código de barras             | 12 | **Sim** |
| Gráfico                      | 10 | *Fora de escopo — outro produto* |
| Assinatura digital / carimbo |  9 | *Fora de escopo — outro produto* |
| Sumario (TOC)                |  8 | Não |
| Desenho vetorial             |  7 | **Sim** |
| Formulário AcroForm          |  6 | Não |
| Template / carimbo / marca   |  6 | **Sim** |
| Fonte TTF                    |  5 | Parcial — sem subset |
| Anotação / anexo             |  5 | Não |
| Codificação e acento         |  4 | **Sim, desde a 3.4.0** |
| Marcadores (bookmarks)       |  1 | Não |
| PDF marcado (tagged/PDF-UA)  |  1 | Não |

> **Demanda alta não e o mesmo que escopo.** Os três itens marcados como fora
> de escopo somam 33 casos e ocupam o 2o, o 4o e o 5o lugares da medição —
> mais que o primeiro colocado sozinho. Saem assim mesmo, e a decisão está em
> "Fora de escopo", adiante. Medir a demanda e uma coisa; decidir que produto
> se esta construindo e outra.

> **A correção que o número impôs.** "PDF marcado" tinha sido proposto como o
> terceiro item, pelo argumento de licitação pública. Ele e o **penúltimo** da
> fonte A — 1 caso em 174, empatado com o ultimo. O argumento de licitação não
> se sustentou contra texto legal: a Lei Brasileira de Inclusão e o eMAG
> obrigam acessibilidade de **sítio web**; não se achou norma que exija PDF/UA
> em documento de licitação. Sem essa norma, o item não se sustenta como
> prioridade. Foi para o backlog.

> **O sinal mais alto não está entre os quatro.** Célula/linha/tabela tem 31
> casos — mais que o dobro do segundo. Já consta do backlog como "Table
> auto-pagination / Media / Alto". A medição diz que essa entrada está
> subestimada: e a superfície mais usada de qualquer biblioteca de PDF, e a
> única em que estamos parciais e não ausentes.

---

### 1. Conversão WinAnsi — CONCLUÍDA na 3.4.0

**Era o peso mais alto da fila.** Não era funcionalidade que faltava: era
defeito na superfície que a fonte A mede em 31 casos e a fonte B em 104
chamadas a `Cell`. O dicionário da fonte declarava `/Encoding
/WinAnsiEncoding` e nada convertia o texto de AL32UTF8 antes de escrever, e o
leitor desenhava **dois glifos errados** no lugar de cada acentuado. Estava
mascarado porque os exemplos evitavam acento.

Entregue em setembro/2026 com a tabela gerada de fonte primária e validada
contra o MuPDF, saída em escape octal (o CLOB de montagem recodifica qualquer
byte acima de `0x7F`), recusa com `ORA-20203` para o que não existe em cp1252,
e `check_byte_chars.py` guardando a volta.

**A hipótese que acompanhava o item não se confirmou.** Suspeitava-se de que
`p_larguras_de` montasse a tabela de larguras com chaves colididas, por causa
do `CHR(i)` em AL32UTF8. Medido: as 256 chaves são distintas e as larguras
estão certas. O que quebrava `GetStringWidth` do acentuado era outra coisa, no
mesmo tema — o `subtype car is varchar2(1)`, que guarda **um byte** e estoura
com `ORA-06502` diante de um caractere de dois. Vale como registro do método:
a medição barata (HU-00) evitou consertar o que não estava quebrado.

**Relato completo:** `docs/HISTORIAS.md`, HU-00 e HU-01.

---

### 2. Subset de fonte TTF — 27x no tamanho do arquivo

**Peso: alto, e o único dos quatro com impacto medido em número.** Com o item
1 concluído, e agora o primeiro da fila.

**A medida.** `fontTools`, com os 106 caracteres distintos que os exemplos
desta base usam:

| Fonte | Inteira | Subset | Redução | Dentro do PDF (deflate) |
|-------|--------:|-------:|--------:|------------------------:|
| DejaVuSans          | 759.720 B | 20.700 B | **97,3%** | 381.835 -> **14.343 B** |
| LiberationSans      | 410.820 B | 24.312 B | **94,1%** | 210.802 -> **15.421 B** |

Um boleto desta base tem 14 KB e um ingresso 22 KB. Embutir DejaVuSans hoje
soma **382 KB** — a fonte fica sendo 95% do arquivo. Com subset, 14 KB.

**O argumento mudou com a 3.4.0, e para melhor.** Até então embutir uma TTF
era a **única forma de acertar acento**, e isso inflava o número de quem
embutia por necessidade. Consertado o item 1, quem só precisa de português
fica nas fontes core e nem embute; quem embute, embute por tipografia — e
deve embutir barato. O item perde urgência e mantém o valor.

**Lógica, casos de uso e critério de aceite:** `docs/HISTORIAS.md`, HU-02.

---

### 3. Sumario e marcadores (`/Outlines`)

**Peso: médio-alto. Barato, muito visível.** 8 casos de TOC + 1 de marcadores
na fonte A. E a única estrutura desta lista que o PDF resolve com um
dicionário simples, sem codificação nem binário.

Dependia do item 1 pelo acento do `/Title`, e a dependência está paga.

**Lógica, casos de uso e critério de aceite:** `docs/HISTORIAS.md`, HU-03.

---

### 4. PDF marcado (tagged / PDF-UA) — rebaixado para backlog

**Peso: o mais baixo dos quatro, pela medida.** 1 caso em 174 na fonte A. A
justificativa era licitação pública; a norma que se achou (LBI art. 63, eMAG,
Decreto 5.296) obriga acessibilidade de **sítio web**, e não se localizou
exigência de PDF/UA em documento de licitação. Sem norma que obrigue, o item
não sustenta a prioridade que se imaginou.

Fica registrado o que seria preciso, para quando houver demanda concreta:
árvore de estrutura (`/StructTreeRoot`), marcação do conteúdo com `BDC`/`EMC`
por bloco, `/Lang`, `/MarkInfo`, ordem de leitura explicita e texto
alternativo de imagem. E trabalho grande, espalhado por todo o gerador de
conteúdo — não e um módulo que se acrescenta ao lado.

**Reavaliar se** aparecer exigência contratual real, ou norma que se possa
citar. Nesse caso ele sobe direto, porque nenhuma biblioteca PL/SQL livre faz
isso. Análise completa em `docs/HISTORIAS.md`, HU-04.

---

### Achado próprio: metade da API pública não tinha chamador — FECHADO

Quando a medição foi feita, 69 das 138 APIs públicas eram exercitadas por
`examples/` e `dev/tests/`. As outras 69 compilavam e ninguém as chamava neste
repositório — não havia como saber se funcionavam. Não e o mesmo que estarem
quebradas, e e exatamente a situação em que `AddWatermark` passou meses
marcado como pronto sem desenhar nada.

Antes de acrescentar superfície nova, vale medir a existente. Levantamento e
critério em `docs/HISTORIAS.md`, HU-05.

**Atualização de 11/09/2026.** A primeira API sem chamador que ganhou teste --
o `Link` -- devolveu **quatro defeitos**, um por rodada, todos achados ao
escrever a chamada e nenhum visível em revisão de código. Em seguida,
`dev/tests/test_fontes_truetype.sql` escreveu a primeira chamada de tudo o que
não depende de recurso externo: **de 48 APIs sem chamador para 6**.

**Medição de 13/09/2026: 118 das 119 APIs públicas do `PL_FPDF` tem chamador.**
Falta uma, o `getImageFromUrl`, que exige ACL de rede -- e o que há sobre ele e
o teste da **recusa**, que e o que se pode afirmar sem concessão no banco. As
outras cinco que a nota acima listava foram cobertas pela chamada que afere a
recusa com o erro próprio: `LoadTTFFromFile` sem DIRECTORY, `OutputFile` e
`Output` sem destino, `Image` sem ACL, `AddFont` sem arquivo. O
`check_test_calls.py` guarda o número no CI.

---

## Backlog (Sem Versão Definida)

Valor revisado em set/2026 pela medição da secao anterior; a coluna "casos"
traz a contagem da fonte A, que e o que sustenta a nota de valor.

| Feature | Complexidade | Valor | Casos |
|---------|--------------|-------|------:|
| Table auto-pagination | Media | **Alto** | 31 |
| Formulário AcroForm | Media | Médio † | 6 |
| Annotations (comments) | Media | Baixo † | 5 |
| PDF marcado (tagged/PDF-UA) | Alta | Baixo *(reavaliar com norma)* | 1 |
| JavaScript actions | Alta | Baixo | 0 |
| Layers (OCG) | Media | Baixo | 0 |
| Operações avançadas de página (inserir de outro PDF, reordenar, substituir, duplicar) | Media | *não medido* | — |

† **Itens separados, esforço conjunto.** Os dois são a **mesma maquina**:
anotação e campo de formulário são entradas do mesmo `/Annots`, e a base já o
monta — o array e aberto no `p_putpages` e a entrada de link já sai como
`<</Type /Annot /Subtype /Link /Rect [...`. Um campo de formulário e um
`/Subtype /Widget` no mesmo lugar.

Ficam separados na tabela porque são entregas distintas, com casos de uso e
critérios de aceite próprios — juntar as duas numa linha só esconderia que uma
pode ser entregue sem a outra. Mas quem pegar uma **deve pegar as duas na mesma
investida**: o caro aqui e entender e generalizar o `/Annots` (dicionário por
subtipo, `/Rect` em coordenadas de página, *appearance stream*, e o que
acontece com tudo isso no `MergePDFs` e no `RemovePage`). Feito esse trabalho,
o segundo subtipo custa uma fração do primeiro. Feitos em rodadas separadas,
paga-se o entendimento duas vezes — e a segunda passagem tende a refatorar o
que a primeira deixou rígido demais.

Fronteira interna, para não repetir a discussão: **criar** o campo, o `/Rect`,
o `/AP` e o valor inicial e nosso; **ler** o valor de um PDF carregado e nosso.
Ação JavaScript de validação e calculo não e — esta na linha própria do
backlog, e e outro domínio. Fluxo de aprovação e quem preenche o que, também
não.

> **Correção da revisão.** "Headers/Footers automáticos" saiu do backlog:
> `SetHeaderProc` e `SetFooterProc` existem, são chamados na quebra de página e
> tem teste em `dev/tests/test_core.sql`, inclusive para nome de procedimento
> inválido e para tentativa de injeção no callback.

### Fora de escopo — decidido, não esquecido

Três entradas com demanda **alta e medida** — 33 casos somados, mais que o
primeiro colocado sozinho — saíram do backlog em set/2026 por decisão de
escopo. Ficam registradas aqui de propósito: apagadas, alguém as re-deriva
da mesma medição daqui a seis meses e refaz a discussão.

| Item | Casos | Por que sai |
|------|------:|-------------|
| XHTML -> PDF | 14 | E **outro produto**, e a funcionalidade já existe pronta e fácil fora daqui. Reimplementar um subconjunto de HTML e CSS dentro do PL/SQL entrega uma versão pior de algo que a pessoa resolve melhor por outro caminho. |
| Gráfico (barra, linha, pizza) | 10 | E **outro produto**. Gráfico e visualização de dado — escala de eixo, legenda, posicionamento de rótulo, paleta —, um domínio inteiro que por acaso termina numa imagem. E o encaixe **já existe**: quem gera o gráfico onde for melhor coloca a imagem com `Image`, `ImageFromBlob` ou `OverlayImage`, que esta base já faz e já válida por pixel. Construir um motor de gráfico aqui competiria com ferramenta madura para entregar menos. |
| Assinatura digital | 9 | E **outro produto**. Assinatura e infraestrutura de certificado, cadeia, carimbo do tempo e política de assinatura — não é geração de PDF. Quem faz isso sério não quer que a biblioteca de desenho também assine. |

O critério e o mesmo que já tirou o `PL_FPDF_BOLETO` daqui: **montar** os 44
dígitos e regra de cobrança, não desenho de PDF; **desenhar** o código de
barras e. A pergunta que separa os dois lados e sempre a mesma — *isto e
desenhar um PDF, ou e outro domínio que por acaso termina num PDF?*

---

## Princípios

1. **Oracle 19c sempre suportado** - Nunca quebrar compatibilidade
2. **Package-only** - Sem tabelas, types ou sequences externas
3. **Backward compatible** - APIs existentes não mudam
4. **Testes primeiro** - Toda feature com testes
5. **Referência antes da porta** - Para qualquer coisa que um leitor externo
   precise entender (QR, código de barras, criptografia, estrutura do PDF),
   primeiro uma referência em Python **validada contra um decodificador
   independente** (zxing-cpp, MuPDF, vetores do FIPS), e só então a porta para
   PL/SQL. Foi o que separou "desenha um símbolo" de "um leitor decodifica" e
   "marcado como protegido" de "protegido".
6. **Recusar em vez de entregar errado** - Quando algo não e suportado, levantar
   erro com mensagem clara. Um PDF marcado como protegido que não esta, ou uma
   imagem que sai como ruído, custa mais caro que uma exceção.
7. **Desenhar PDF, não o domínio de quem chama** - A pergunta que decide o
   escopo e sempre a mesma: *isto e desenhar um PDF, ou e outro domínio que
   por acaso termina num PDF?* Montar os 44 dígitos do boleto e regra de
   cobrança; desenhar o código de barras e nosso. Assinatura digital e
   infraestrutura de certificado; XHTML -> PDF e um motor de layout; gráfico
   e visualização de dado — os três já existem prontos fora daqui, e para os
   dois últimos o encaixe e uma imagem, que esta base já coloca. Demanda
   medida alta não derruba este princípio — derruba só a dúvida sobre se
   alguém pediria.

---

## Como Contribuir

1. Escolha um item do roadmap
2. Abra issue para discussão
3. Implemente com testes
4. Envie Pull Request

**Contato:** @maxwbh | maxwbh@gmail.com
