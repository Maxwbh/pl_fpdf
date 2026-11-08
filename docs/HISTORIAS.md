# Histórias de desenvolvimento — lacunas priorizadas

**DOCUMENTO DE MANUTENÇÃO.** Não é documentação de quem usa a biblioteca.
Quem usa quer saber o que a API faz, e isso está em `docs/API_REFERENCE.md` e
em `docs/DOCUMENTATION.md`.

Aqui está o **como**: uma história por lacuna, com a lógica definida, o caso
de uso que a justifica e o critério que diz quando acabou. O **o que** e o
**em que ordem** ficam em `docs/ROADMAP.md`, secao "Lacunas priorizadas por
uso medido" — inclusive o peso de cada item e a medição que o sustenta.

Cada história se pretende auto-suficiente: quem pegar uma não deveria precisar
reconstruir o raciocínio, só ler e executar.

---

## Ordem e dependências

```
HU-00 (medicao)      CONCLUIDA
   |
   +--> HU-01 WinAnsi   CONCLUIDA na 3.4.0 ---> HU-03 Sumario e marcadores
   |         (o /Title do marcador tem o mesmo defeito de acento)
   |
   +--> HU-02 Subset de TTF   (independente; pode ir em paralelo)

HU-04  fora da fila — reavaliar so com norma citavel
HU-05  levantamento; nao bloqueia ninguem
```

HU-00 vinha antes porque podia **mudar o tamanho** da HU-01: se a tabela de
larguras também estivesse errada, a HU-01 cresceria e deixaria de ser só
conversão de saída. A medição respondeu que não — a tabela estava intacta —, e
a HU-01 saiu no tamanho previsto.

**Registro de setembro/2026:** as duas primeiras histórias estão concluídas, e
vale dizer **como**: nenhuma das duas premissas que as originaram se
confirmou. A HU-00 supunha colisão de chaves na tabela de larguras, e não
havia; a HU-01 supunha `ORA-29275` na escrita do texto, e o erro era
`ORA-06502`, por outro motivo. As histórias continuam aqui inteiras, com o que
se mediu ao lado do que se supôs, porque é esse par que ensina alguma coisa —
apagar a suposição deixa só o resultado, que qualquer um refaz.

---

## HU-00 — Medir a tabela de larguras antes de mexer em qualquer coisa

**CONCLUÍDA.** Medida em setembro/2026, e o resultado **contradisse a
suposição**: a tabela de larguras estava correta. Ver "O que a medição
respondeu", no fim desta história.

**Tipo:** investigação (spike). Não entrega funcionalidade; entrega uma
resposta que decide o tamanho da HU-01.

**Como** mantenedor,
**quero** saber se `GetStringWidth` erra a largura de caractere acentuado,
**para** dimensionar a HU-01 antes de começar, em vez de descobrir no meio.

### A dúvida, precisamente

`p_larguras_de` (`src/PL_FPDF.pkb:693`) monta a tabela de larguras assim:

```sql
for i in 0..255 loop
  mySet(chr(i)) := to_number(substr(p_tabela, i * 4 + 1, 4));
end loop;
```

A chave e `chr(i)`. O `docs/MANUTENCAO.md` desta base já documenta que **`CHR(n)` não
devolve um byte**: devolve o caractere daquele ponto de código no charset do
banco, e em AL32UTF8 todo valor de 128 a 255 sai com dois bytes — ou nem sai,
porque 0x80..0xFF sozinho não e UTF-8 valido.

Se as 128 chaves altas saem invalidas, colididas ou iguais entre si, então
`GetStringWidth` de qualquer texto acentuado devolve número errado. E largura
errada não erra só a largura: **alinhamento a direita, centralização,
`MultiCell` e quebra de linha** saem todos do lugar, porque todos dependem
dela.

### Como medir

Bloco anônimo na SQL Window, alcançável pelo runner Python, comparando o que
`GetStringWidth` devolve com o valor que a tabela deveria ter para as 128
posições de 128 a 255. Os valores de referência saem dos AFM da Adobe, que
`dev/scripts/font_reference/` já usa.

Três perguntas a responder, nessa ordem:

1. `chr(i)` para `i` de 128 a 255 devolve 128 valores **distintos**?
   (`SELECT COUNT(DISTINCT chr(i))` sobre a faixa.)
2. `GetStringWidth` de cada caractere acentuado do português bate com o AFM?
3. Se não bate: erra por colisão de chave, ou por `NO_DATA_FOUND` silenciado
   em algum lugar?

### Critério de aceite

- [x] Um diagnóstico que imprime a resposta das três perguntas e roda pelo
      `run_tests.py` — saiu como `dev/tests/diag_winansi.sql`, que mede a
      conversão inteira e não só a tabela
- [x] O resultado registrado na HU-01, que passou a ter escopo definido
- [x] Havendo defeito: teste de regressão antes do conserto — `test_winansi.sql`

**Estimativa:** 1 dia. E barato e evita começar a HU-01 pelo lado errado.
**Real:** menos que isso, e pagou o preço previsto: a HU-01 não começou pelo
lado errado.

### O que a medição respondeu

As três perguntas, na ordem em que foram feitas:

1. **`chr(i)` de 128 a 255 devolve 128 valores distintos?** Sim. Os 256
   devolvem 256 chaves distintas, e nenhuma colide. A suposição de que
   `0x80..0xFF` sairia inválido em AL32UTF8 confundiu **byte** com **ponto de
   código**: `CHR(231)` não pede o byte `0xE7`, pede o caractere U+00E7, que
   existe e e um só. O que o `docs/MANUTENCAO.md` documenta e que ele não
   devolve *um byte* — não que devolva chave invalida.
2. **`GetStringWidth` do acentuado bate com o AFM?** Sim, quando chega a
   consultar. E o valor certo e o **mesmo do glifo base**: nas 14 fontes
   padrão o acentuado tem a largura de avanço do caractere que acentua — `a` e
   `a` com til medem 556, `c` e cedilha medem 500. Uma versão anterior do teste
   exigia que diferissem, no palpite de que o acentuado seria mais largo, e
   falhava por estar errada ela.
3. **Erra por colisão ou por `NO_DATA_FOUND` silenciado?** Por nenhum dos dois.
   `GetStringWidth('Sao Paulo')` com til levantava **`ORA-06502`**, e a causa
   estava três linhas antes da tabela: o `subtype car is varchar2(1)` guarda
   **um byte**, e o caractere tem dois em AL32UTF8. Estourava ao recortar a
   string, antes de qualquer consulta.

**O que isso mudou na HU-01:** nada a acrescentar, e uma armadilha a menos.
A HU-01 seguiu sendo conversão de saída, e o `subtype car` entrou junto no
conserto, por ser o mesmo defeito de origem — tratar byte e caractere como a
mesma coisa.

---

## HU-01 — Texto com acento sai correto nas fontes core

**CONCLUÍDA na 3.4.0.** Entregue em setembro/2026, com **uma diferença de
projeto** em relação ao que está escrito abaixo: a conversão não pode sair em
RAW, e o texto vai para o PDF em **escape octal**. Ver "Como ficou", no fim
desta história — o motivo foi medido, não escolhido.

**Peso: o mais alto da fila.** Não é funcionalidade que falta — é defeito na
superfície mais usada da biblioteca.

**Como** desenvolvedor que gera boleto, nota e relatório em português,
**quero** que `Cell`, `MultiCell`, `Write`, `Text` e os overlays escrevam
acento corretamente com as fontes padrão,
**para** não precisar embutir uma fonte TrueType de 380 KB só para escrever
"Endereço de cobrança".

### O defeito

O dicionário da fonte declara `/Encoding /WinAnsiEncoding`
(`src/PL_FPDF.pkb:1821`, `1838`, `9165`), mas **nada converte o texto** de
AL32UTF8 para WinAnsi antes de escrever no stream de conteúdo.

O `a` com acento agudo e U+00E1. Em AL32UTF8 ele sai do banco como **dois
bytes**, C3 A1. Esses dois bytes vão crus para o PDF. O leitor, que foi
avisado de que aquele stream esta em WinAnsi, resolve C3 como `A` com til e
A1 como `¡` — e desenha **dois glifos errados** no lugar de um certo.

Está mascarado hoje porque os exemplos da base evitam acento.

### Casos de uso

1. **Boleto brasileiro.** "Nome do Sacado", "Instruções", "Não receber após o
   vencimento" — endereço com acento e o caso comum, não o excepcional.
2. **Relatório administrativo.** Cabeçalho "Relatório de Produção — Marco" com
   `Cell` centralizada: hoje sai com dois glifos errados **e** desalinhada, se
   a HU-00 confirmar o defeito de largura.
3. **Recusa explicita.** Um título que traga travessão `—` ou aspas curvas
   `""` — caracteres que **não existem** no cp1252 na posição esperada. O
   sistema deve **avisar**, não desenhar lixo em silêncio.

### Definição da lógica

**Passo 1 — referência em Python antes da porta.** E o método desta base, e
foi o que separou "desenha um símbolo" de "um leitor decodifica" no QR Code.

Em `dev/scripts/winansi_reference/`:
- tabela Unicode -> WinAnsi (cp1252) das 224 posições imprimíveis, gerada de
  fonte primária, não digitada a mão;
- um PDF de prova produzido por biblioteca externa, com as 224 posições;
- leitura de volta com **MuPDF** conferindo caractere a caractere.

Só depois disso a tabela vai para o PL/SQL, e vai **gerada**, com o cabeçalho
"NÃO EDITE A MÃO" que as tabelas de fonte desta base já usam.

**Passo 2 — a conversão, em RAW.**

```
p_para_winansi(p_texto in varchar2) return raw
```

Trabalhar em RAW do início ao fim: `UTL_RAW.CAST_TO_RAW` na entrada,
`UTL_RAW.CONCAT` para montar. Não remontar byte a byte num VARCHAR2 — a
armadilha já paga desta base: `SUBSTRB(x, k, 1)` extrai um byte, e um byte do
meio de um caractere multibyte não volta como ele.

**Passo 3 — a recusa.** Caractere sem correspondente no cp1252 levanta erro
próprio, com o caractere e a posição na mensagem. Não trocar por `?` nem
descartar. E o princípio 2 da base: recusar em vez de entregar errado. Um
travessão virando `?` em silêncio e o tipo de defeito que só aparece quando o
documento já foi assinado.

**Passo 4 — onde chamar.** Na saída de texto, e **só quando a fonte for
core**. Fonte TrueType embutida tem a própria codificação e não passa por
aqui — passar quebraria o que hoje funciona.

**Passo 5 — `SetUTF8Enabled` passa a significar alguma coisa.** Hoje
`g_utf8_enabled` (`src/PL_FPDF.pkb:303`) e escrito pelo setter, lido pelo
getter, e **nada mais o consulta**: o ajuste não tem efeito nenhum. Duas
saídas honestas — ou ele governa esta conversão, ou sai da spec. Não deixar
como esta, que é o pior dos três.

**Passo 6 — lint que impeça a volta.** Nenhuma escrita de texto com fonte core
sem passar pela conversão. Em `dev/scripts/plsql_lint/`, no padrão dos outros:
cabeçalho explicando o defeito que ele guarda.

### Critério de aceite

- [x] Referência Python validada contra MuPDF — **217/217** posições, não 224;
      ver "Como ficou" para o motivo do número
- [x] Tabela no PL/SQL gerada, não digitada — `dev/scripts/winansi_reference/`
- [x] `Cell`, `MultiCell`, `Write`, `Text` e overlays convertem com fonte core
- [x] Fonte TrueType embutida **não** passa pela conversão (não regride)
- [x] Caractere fora do cp1252 levanta erro próprio com posição na mensagem
      (`ORA-20203`)
- [x] `SetUTF8Enabled` **saiu da spec** — das duas saídas honestas, a que
      corresponde ao que a biblioteca faz: a conversão não é opcional
- [x] Lint no CI — `check_byte_chars.py`, regras 3 e 4
- [x] `CHANGELOG` com uma linha; o relato longo no comentário do código

### Como testar

- PDF com as posições do cp1252, extraído e comparado caractere a caractere
  com o esperado
- Um caso que confirme a **recusa** do caractere fora da tabela — e que falhe
  se voltar `ORA-06502` em vez do erro próprio
- Regressão: um documento com fonte TrueType embutida continua idêntico

**Estimativa:** 3 a 5 dias, mais o que a HU-00 acrescentar. A HU-00 não
acrescentou nada.

### Como ficou

Três coisas saíram diferentes do que está escrito acima, e as três por
medição.

**1. A saída não e RAW — e escape octal.** O passo 2 mandava trabalhar em RAW
do início ao fim, e está certo *para a conversão*; errado para a **escrita**.
O documento desta base e montado num CLOB e convertido no fim por
`DBMS_LOB.CONVERTTOBLOB`, que recodifica pelo charset do banco: qualquer byte
acima de `0x7F` colocado ali e reescrito na saída. Medido no diagnóstico:
**256 bytes entram, 422 saem**. Então o byte convertido não pode ir cru. Vai
como `\ddd`, o escape octal que o próprio PDF define para string — que é ASCII
e atravessa o CLOB intacto. `p_texto_pdf` converte e escapa numa passagem só.

Isto vale para todo binário que sair por este caminho, não só para texto: e o
mesmo motivo pelo qual o stream de imagem sai em hexadecimal com
`/ASCIIHexDecode` declarado.

**2. São 27 exceções, não 224 posições.** O cp1252 tem **251** posições
definidas, não 224, e cinco indefinidas (`0x81`, `0x8D`, `0x8F`, `0x90`,
`0x9D`). De `0xA0` a `0xFF` ele coincide com o Latin-1, e ali o byte **e** o
ponto de código — não precisa de tabela, precisa de identidade. Só as 27
posições de `0x80` a `0x9F` exigem mapa: travessão, aspas curvas, euro,
reticencias. A tabela no PL/SQL e um `CASE` de 27 ramos mais a identidade, e
não um vetor de 224 entradas.

A validação contra MuPDF fechou **217/217**, com duas diferenças conhecidas e
esperadas: `0xA0` volta como espaço e `0xAD` como hífen, que e o que o Anexo D
do ISO 32000 manda.

**3. O `ORA-06502` da HU-00 entrou no mesmo conserto.** O `subtype car is
varchar2(1)` da tabela de larguras guarda um byte; a consulta passou a ser
feita por `chr(p_winansi_byte(...))`, que devolve o caractere de um só byte
que a tabela indexa. O `.exists` voltou, para que posição ausente não levante
`NO_DATA_FOUND` de dentro de uma medida.

**Onde esta:** `p_winansi_byte` e `p_texto_pdf` em `src/PL_FPDF.pkb`;
referência em `dev/scripts/winansi_reference/`; testes em
`dev/tests/test_winansi.sql` e `dev/tests/diag_winansi.sql`.

---

## HU-02 — Fonte embutida sem carregar a fonte inteira

**Peso: alto, e o único item da fila com impacto medido em número.**

**Como** desenvolvedor que embute uma fonte para ter a tipografia da marca,
**quero** que só os glifos usados entrem no PDF,
**para** que o arquivo não fique 27 vezes maior por causa de uma fonte da qual
uso 106 caracteres.

### A medida

`fontTools`, sobre os 106 caracteres distintos que os exemplos desta base de
fato usam:

| Fonte | Inteira | Subset | Redução | Dentro do PDF (deflate) |
|-------|--------:|-------:|--------:|------------------------:|
| DejaVuSans     | 759.720 B | 20.700 B | **97,3%** | 381.835 -> **14.343 B** |
| LiberationSans | 410.820 B | 24.312 B | **94,1%** | 210.802 -> **15.421 B** |

Um boleto desta base tem 14 KB; um ingresso, 22 KB. Embutir DejaVuSans hoje
soma **382 KB** — a fonte vira 95% do arquivo. Com subset, 14 KB.

### Casos de uso

1. **Boleto com a fonte da instituição.** Emissão em lote de milhares por dia:
   382 KB por boleto são centenas de MB de rede e de armazenamento que não
   precisavam existir.
2. **Anexo de e-mail.** Muito servidor corporativo corta anexo em 10 MB. Com a
   fonte inteira, vinte e seis documentos estouram; com subset, mais de
   setecentos.
3. **Documento com tipografia própria e pouco texto.** Um certificado de uma
   página, com trinta caracteres distintos, carregando 380 KB de fonte.

### Definição da lógica

**Passo 1 — não escrever leitor novo.** O parse das tabelas TrueType já existe
nesta base. O subset acrescenta a **poda**; não comece do zero.

**Passo 2 — referência em Python.** Montar o subset com `fontTools`, gravar
num PDF, e confirmar com **MuPDF** que os mesmos glifos saem do arquivo
podado. E o mesmo procedimento do QR Code e do AES: validar contra
decodificador independente antes da porta.

**Passo 3 — o subset mínimo util**, na ordem em que as tabelas dependem umas
das outras:

1. `glyf` e `loca`: manter só os glifos usados, mais o `.notdef`, que não pode
   faltar. Glifo composto referência outros — **inclua os componentes**, ou o
   caractere sai vazio.
2. `cmap`: remapear para os glifos que sobraram.
3. `hmtx` e `hhea.numberOfHMetrics`: recalcular, porque contam entradas.
4. `head.checkSumAdjustment`: **regravar**. Leitor rigoroso recusa a fonte
   com a soma errada, e o sintoma e "a fonte não carrega", que não aponta
   para aqui.

**Passo 4 — duas armadilhas que esta base já pagou noutro contexto.**

- `checkSumAdjustment` e conta de **32 bits sem sinal** e estoura
  `PLS_INTEGER` (`ORA-01426`, erro de execução, sem nome de variável). Faça em
  `NUMBER`. Foi exatamente assim com o Adler-32 do deflate.
- Corte de tabela e binário: trabalhe em **RAW**, nunca VARCHAR2.

**Passo 5 — saber quais glifos entram.** Exige conhecer o texto **antes** de
fechar o documento. Como o `Output` desta base já monta no fim, da para
acumular um conjunto de caracteres por fonte durante a escrita e podar só na
hora de emitir o `/FontFile2`. Não exija que o chamador declare os glifos —
isso e o tipo de API que ninguém usa certo.

**Passo 6 — poder desligar.** Um `SetFontSubset(FALSE)` para o caso raro de
alguém precisar da fonte inteira (formulário preenchivel por outro programa,
por exemplo). Padrão ligado.

### Critério de aceite

- [ ] Referência Python validada contra MuPDF
- [ ] Glifo composto traz os componentes (teste com caractere acentuado de
      fonte que use composição)
- [ ] `checkSumAdjustment` recalculado, em `NUMBER`
- [ ] Texto extraído do PDF com subset **idêntico** ao sem subset
- [ ] Redução na ordem medida acima, verificada no teste
- [ ] `SetFontSubset` documentado

### Como testar

- Mesmo documento com e sem subset: texto extraído idêntico, arquivo
  encolhido na ordem esperada
- Um caractere acentuado de fonte com glifo composto, conferido visualmente e
  por extração
- Abrir em mais de um leitor: o `checkSumAdjustment` errado só aparece nos
  rigorosos

**Estimativa:** 5 a 8 dias. E a mais técnica da fila.

---

## HU-03 — Sumario e marcadores de navegação

**Peso: médio-alto.** 9 casos na fonte A, e a única estrutura da fila que o
PDF resolve com dicionário simples — sem binário, sem codificação.

**Como** leitor de um relatório de oitenta páginas,
**quero** o painel de marcadores do leitor de PDF preenchido,
**para** ir direto ao capítulo em vez de rolar procurando.

### Casos de uso

1. **Relatório gerencial longo.** Capítulos e seções no painel lateral.
2. **Manual ou contrato.** Cláusulas como marcadores de segundo nível.
3. **Lote consolidado.** Vários documentos mesclados num PDF só, com um
   marcador por documento — encaixa no `MergePDFs` que já existe.

### Definição da lógica

**Passo 1 — a estrutura.** `/Outlines` do ISO 32000 e uma **lista duplamente
encadeada** de dicionários. Cada item tem `/Title`, `/Parent`, `/Prev`,
`/Next`, `/First`, `/Last`, `/Count` e um `/Dest` apontando para a página. O
catálogo ganha `/Outlines` e, se quiser que o leitor abra com o painel
visível, `/PageMode /UseOutlines`.

**Passo 2 — a API**, no estilo que a base já usa:

```
AddBookmark(p_titulo  in varchar2,
            p_nivel   in pls_integer default 1,
            p_pagina  in pls_integer default null)   -- null = pagina corrente
```

**Passo 3 — encadear só na emissão.** Guarde os itens numa tabela indexada
durante a escrita e monte `/Prev`, `/Next`, `/First`, `/Last` e `/Count` **no
fim**, quando todos os destinos já são conhecidos. Tentar encadear na hora da
chamada obriga a reescrever objeto já emitido.

**Passo 4 — o acento do título.** `/Title` e string PDF e sofre do **mesmo**
defeito da HU-01: ou converte para WinAnsi, ou emite em UTF-16BE com BOM. Por
isso esta HU vem **depois** da HU-01 — feita antes, nasce com o mesmo defeito
que a outra esta consertando.

Com a HU-01 concluída a dependência está paga, e o caminho ficou mais curto do
que se previa: o `p_texto_pdf` já converte e escapa qualquer string que vá para
o arquivo, então o `/Title` do marcador passa por ele e não precisa de
tratamento próprio.

**Passo 5 — o sumario visível e outro problema, e o mais chato.** A página com
os títulos e os números exige saber o número da página de cada capítulo, que
só se sabe depois de paginar tudo. O caminho conhecido e o que o `{nb}` desta
base já usa: escrever um marcador no lugar e substituir na emissão. **Sugestão
de escopo:** entregar os marcadores primeiro (que são baratos e já resolvem
navegação) e tratar o sumario visível como história separada.

### Critério de aceite

- [ ] Três níveis de hierarquia, encadeamento correto nos dois sentidos
- [ ] `/Dest` aponta para a página certa, conferido reabrindo o arquivo
- [ ] `/Count` com o sinal certo (negativo = no fechado)
- [ ] Título com acento correto (depende da HU-01)
- [ ] Documento sem nenhum marcador continua sem `/Outlines` no catálogo
- [ ] Marcador sobrevive ao `MergePDFs`, ou a limitação está documentada

### Como testar

Gerar com três níveis, reabrir, conferir a árvore e o destino de cada item.
Um caso com zero marcadores confirmando que nada é emitido à toa.

**Estimativa:** 3 a 4 dias para os marcadores. O sumario visível e outra
história, de tamanho parecido.

---

## HU-04 — PDF marcado (tagged / PDF-UA) — fora da fila

**Não está priorizada.** Registrada para não se perder, e para que a próxima
pessoa a levantar o assunto encontre a análise em vez de refazê-la.

**Por que saiu:** era o terceiro item por argumento de licitação pública. A
medição o põe em **1 caso de 174** na fonte A — penúltimo, empatado com o
ultimo. E a norma não sustentou o argumento: a Lei Brasileira de Inclusão
(art. 63), o eMAG e o Decreto 5.296 obrigam acessibilidade de **sítio web**;
não se localizou exigência de PDF/UA em documento de licitação.

**O que seria preciso**, para quando houver demanda: árvore de estrutura
(`/StructTreeRoot`), marcação do conteúdo com `BDC`/`EMC` por bloco, `/Lang`,
`/MarkInfo`, ordem de leitura explicita e texto alternativo de imagem. E
trabalho grande e **espalhado por todo o gerador de conteúdo** — não e um
módulo que se acrescenta ao lado, e essa e a diferença entre ele e os outros
três.

**Gatilho para reavaliar:** exigência contratual concreta, ou norma que se
possa citar. Nesse caso ele sobe direto, porque nenhuma biblioteca PL/SQL
livre faz isso — deixa de ser paridade e vira diferencial.

---

## HU-05 — Metade da API pública não tem chamador

**Achado da própria medição, não veio de fora.**

69 das 138 APIs públicas são exercitadas por `examples/` e `dev/tests/`. As
outras 69 compilam, e ninguém as chama neste repositório.

Não e o mesmo que estarem quebradas. Mas e **exatamente a situação** em que
`AddWatermark` passou meses marcado como pronto sem desenhar nada: sem
chamador, não há como saber.

**Como** mantenedor,
**quero** saber quais APIs públicas não tem nenhum chamador,
**para** decidir entre testar, documentar como experimental, ou remover.

**Lógica:** um lint que cruze os identificadores das specs com as chamadas em
`examples/` e `dev/tests/`, e liste o que sobrar. A base já tem
`check_dead_code.py`, que resolve o problema vizinho — provavelmente e
extensão dele, não script novo.

**Critério de aceite:** a lista existe, e cada item nela foi classificado em
testar / experimental / remover. Não é preciso testar todos de uma vez; e
preciso **saber quais são**.

### O que a lista produziu, em setembro/2026

A lista saiu, e a primeira API dela que ganhou teste devolveu **quatro
defeitos** no mesmo subprograma -- o `Link`, um por rodada:

1. o `/Dest` do link interno nunca foi escrito, e o `/Annot` saia com o
   dicionário ABERTO: arquivo malformado, não apenas link que não navega;
2. o `Link` estendia a coleção até a página corrente e deixava entrada vazia
   nas anteriores, que ganhavam `/Annots` quebrado sem terem pedido link;
3. o `AddLink` levantava `ORA-06531` na linha da própria declaração -- a
   coleção `links` e nested table e ninguém a inicializa. **Nunca funcionou**;
4. o `Link` media o quanto estender pelo `.last`, que é NULL em coleção vazia,
   então o primeiro `Link` do SEGUNDO documento da sessão estourava com
   `ORA-06533`.

Nenhum deles aparecia em revisão de código: os quatro foram achados
**escrevendo a chamada**. Vale como medida do que "compila e ninguém chama"
esconde.

Depois disso, `dev/tests/test_fontes_truetype.sql` escreveu a primeira chamada
de tudo o que não depende de recurso externo. **De 48 sem chamador para 6**, e
os 6 que sobram precisam de DIRECTORY (`LoadTTFFromFile`, `OutputFile`,
`Output`) ou de ACL de rede (`Image` por URL, `getImageFromUrl`), fora o
`AddFont`, que espera arquivo de métricas.

**Estimativa:** 2 dias para o levantamento. O que fazer com o resultado e
decisão, não implementação.
