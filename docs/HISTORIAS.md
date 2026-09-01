# Historias de desenvolvimento — lacunas priorizadas

**DOCUMENTO DE MANUTENCAO.** Nao e documentacao de quem usa a biblioteca.
Quem usa quer saber o que a API faz, e isso esta em `docs/API_REFERENCE.md` e
em `docs/DOCUMENTATION.md`.

Aqui esta o **como**: uma historia por lacuna, com a logica definida, o caso
de uso que a justifica e o criterio que diz quando acabou. O **o que** e o
**em que ordem** ficam em `docs/ROADMAP.md`, secao "Lacunas priorizadas por
uso medido" — inclusive o peso de cada item e a medicao que o sustenta.

Cada historia se pretende auto-suficiente: quem pegar uma nao deveria precisar
reconstruir o raciocinio, so ler e executar.

---

## Ordem e dependencias

```
HU-00 (medicao, 1 dia)
   |
   +--> HU-01 WinAnsi ---> HU-03 Sumario e marcadores
   |         (o /Title do marcador tem o mesmo defeito de acento)
   |
   +--> HU-02 Subset de TTF   (independente; pode ir em paralelo)

HU-04  fora da fila — reavaliar so com norma citavel
```

HU-00 vem antes porque pode **mudar o tamanho** da HU-01: se a tabela de
larguras tambem estiver errada, a HU-01 cresce e deixa de ser so conversao de
saida.

---

## HU-00 — Medir a tabela de larguras antes de mexer em qualquer coisa

**Tipo:** investigacao (spike). Nao entrega funcionalidade; entrega uma
resposta que decide o tamanho da HU-01.

**Como** mantenedor,
**quero** saber se `GetStringWidth` erra a largura de caractere acentuado,
**para** dimensionar a HU-01 antes de comecar, em vez de descobrir no meio.

### A duvida, precisamente

`p_larguras_de` (`src/PL_FPDF.pkb:693`) monta a tabela de larguras assim:

```sql
for i in 0..255 loop
  mySet(chr(i)) := to_number(substr(p_tabela, i * 4 + 1, 4));
end loop;
```

A chave e `chr(i)`. O `CLAUDE.md` desta base ja documenta que **`CHR(n)` nao
devolve um byte**: devolve o caractere daquele ponto de codigo no charset do
banco, e em AL32UTF8 todo valor de 128 a 255 sai com dois bytes — ou nem sai,
porque 0x80..0xFF sozinho nao e UTF-8 valido.

Se as 128 chaves altas saem invalidas, colididas ou iguais entre si, entao
`GetStringWidth` de qualquer texto acentuado devolve numero errado. E largura
errada nao erra so a largura: **alinhamento a direita, centralizacao,
`MultiCell` e quebra de linha** saem todos do lugar, porque todos dependem
dela.

### Como medir

Bloco anonimo na SQL Window, alcancavel pelo runner Python, comparando o que
`GetStringWidth` devolve com o valor que a tabela deveria ter para as 128
posicoes de 128 a 255. Os valores de referencia saem dos AFM da Adobe, que
`dev/scripts/font_reference/` ja usa.

Tres perguntas a responder, nessa ordem:

1. `chr(i)` para `i` de 128 a 255 devolve 128 valores **distintos**?
   (`SELECT COUNT(DISTINCT chr(i))` sobre a faixa.)
2. `GetStringWidth` de cada caractere acentuado do portugues bate com o AFM?
3. Se nao bate: erra por colisao de chave, ou por `NO_DATA_FOUND` silenciado
   em algum lugar?

### Criterio de aceite

- [ ] Um `dev/tests/diag_larguras.sql` que imprime a resposta das tres
      perguntas e roda pelo `run_tests.py`
- [ ] O resultado registrado na HU-01, que passa a ter escopo definido
- [ ] Se houver defeito: teste de regressao antes do conserto

**Estimativa:** 1 dia. E barato e evita comecar a HU-01 pelo lado errado.

---

## HU-01 — Texto com acento sai correto nas fontes core

**Peso: o mais alto da fila.** Nao e funcionalidade que falta — e defeito na
superficie mais usada da biblioteca.

**Como** desenvolvedor que gera boleto, nota e relatorio em portugues,
**quero** que `Cell`, `MultiCell`, `Write`, `Text` e os overlays escrevam
acento corretamente com as fontes padrao,
**para** nao precisar embutir uma fonte TrueType de 380 KB so para escrever
"Endereco de cobranca".

### O defeito

O dicionario da fonte declara `/Encoding /WinAnsiEncoding`
(`src/PL_FPDF.pkb:1821`, `1838`, `9165`), mas **nada converte o texto** de
AL32UTF8 para WinAnsi antes de escrever no stream de conteudo.

O `a` com acento agudo e U+00E1. Em AL32UTF8 ele sai do banco como **dois
bytes**, C3 A1. Esses dois bytes vao crus para o PDF. O leitor, que foi
avisado de que aquele stream esta em WinAnsi, resolve C3 como `A` com til e
A1 como `¡` — e desenha **dois glifos errados** no lugar de um certo.

Esta mascarado hoje porque os exemplos da base evitam acento.

### Casos de uso

1. **Boleto brasileiro.** "Nome do Sacado", "Instrucoes", "Nao receber apos o
   vencimento" — endereco com acento e o caso comum, nao o excepcional.
2. **Relatorio administrativo.** Cabecalho "Relatorio de Producao — Marco" com
   `Cell` centralizada: hoje sai com dois glifos errados **e** desalinhada, se
   a HU-00 confirmar o defeito de largura.
3. **Recusa explicita.** Um titulo que traga travessao `—` ou aspas curvas
   `""` — caracteres que **nao existem** no cp1252 na posicao esperada. O
   sistema deve **avisar**, nao desenhar lixo em silencio.

### Definicao da logica

**Passo 1 — referencia em Python antes da porta.** E o metodo desta base, e
foi o que separou "desenha um simbolo" de "um leitor decodifica" no QR Code.

Em `dev/scripts/winansi_reference/`:
- tabela Unicode -> WinAnsi (cp1252) das 224 posicoes imprimiveis, gerada de
  fonte primaria, nao digitada a mao;
- um PDF de prova produzido por biblioteca externa, com as 224 posicoes;
- leitura de volta com **MuPDF** conferindo caractere a caractere.

So depois disso a tabela vai para o PL/SQL, e vai **gerada**, com o cabecalho
"NAO EDITE A MAO" que as tabelas de fonte desta base ja usam.

**Passo 2 — a conversao, em RAW.**

```
p_para_winansi(p_texto in varchar2) return raw
```

Trabalhar em RAW do inicio ao fim: `UTL_RAW.CAST_TO_RAW` na entrada,
`UTL_RAW.CONCAT` para montar. Nao remontar byte a byte num VARCHAR2 — a
armadilha ja paga desta base: `SUBSTRB(x, k, 1)` extrai um byte, e um byte do
meio de um caractere multibyte nao volta como ele.

**Passo 3 — a recusa.** Caractere sem correspondente no cp1252 levanta erro
proprio, com o caractere e a posicao na mensagem. Nao trocar por `?` nem
descartar. E o principio 2 da base: recusar em vez de entregar errado. Um
travessao virando `?` em silencio e o tipo de defeito que so aparece quando o
documento ja foi assinado.

**Passo 4 — onde chamar.** Na saida de texto, e **so quando a fonte for
core**. Fonte TrueType embutida tem a propria codificacao e nao passa por
aqui — passar quebraria o que hoje funciona.

**Passo 5 — `SetUTF8Enabled` passa a significar alguma coisa.** Hoje
`g_utf8_enabled` (`src/PL_FPDF.pkb:303`) e escrito pelo setter, lido pelo
getter, e **nada mais o consulta**: o ajuste nao tem efeito nenhum. Duas
saidas honestas — ou ele governa esta conversao, ou sai da spec. Nao deixar
como esta, que e o pior dos tres.

**Passo 6 — lint que impeca a volta.** Nenhuma escrita de texto com fonte core
sem passar pela conversao. Em `dev/scripts/plsql_lint/`, no padrao dos outros:
cabecalho explicando o defeito que ele guarda.

### Criterio de aceite

- [ ] Referencia Python validada contra MuPDF, 224/224 posicoes
- [ ] Tabela no PL/SQL gerada, nao digitada
- [ ] `Cell`, `MultiCell`, `Write`, `Text` e overlays convertem com fonte core
- [ ] Fonte TrueType embutida **nao** passa pela conversao (nao regride)
- [ ] Caractere fora do cp1252 levanta erro proprio com posicao na mensagem
- [ ] `SetUTF8Enabled` governa a conversao, ou saiu da spec
- [ ] Lint no CI
- [ ] `CHANGELOG` com uma linha; o relato longo no comentario do codigo

### Como testar

- PDF com as 224 posicoes do cp1252, extraido e comparado caractere a
  caractere com o esperado
- Um caso que confirme a **recusa** do caractere fora da tabela — e que falhe
  se voltar `ORA-06502` em vez do erro proprio
- Regressao: um documento com fonte TrueType embutida continua identico

**Estimativa:** 3 a 5 dias, mais o que a HU-00 acrescentar.

---

## HU-02 — Fonte embutida sem carregar a fonte inteira

**Peso: alto, e o unico item da fila com impacto medido em numero.**

**Como** desenvolvedor que embute uma fonte para ter a tipografia da marca,
**quero** que so os glifos usados entrem no PDF,
**para** que o arquivo nao fique 27 vezes maior por causa de uma fonte da qual
uso 106 caracteres.

### A medida

`fontTools`, sobre os 106 caracteres distintos que os exemplos desta base de
fato usam:

| Fonte | Inteira | Subset | Reducao | Dentro do PDF (deflate) |
|-------|--------:|-------:|--------:|------------------------:|
| DejaVuSans     | 759.720 B | 20.700 B | **97,3%** | 381.835 -> **14.343 B** |
| LiberationSans | 410.820 B | 24.312 B | **94,1%** | 210.802 -> **15.421 B** |

Um boleto desta base tem 14 KB; um ingresso, 22 KB. Embutir DejaVuSans hoje
soma **382 KB** — a fonte vira 95% do arquivo. Com subset, 14 KB.

### Casos de uso

1. **Boleto com a fonte da instituicao.** Emissao em lote de milhares por dia:
   382 KB por boleto sao centenas de MB de rede e de armazenamento que nao
   precisavam existir.
2. **Anexo de e-mail.** Muito servidor corporativo corta anexo em 10 MB. Com a
   fonte inteira, vinte e seis documentos estouram; com subset, mais de
   setecentos.
3. **Documento com tipografia propria e pouco texto.** Um certificado de uma
   pagina, com trinta caracteres distintos, carregando 380 KB de fonte.

### Definicao da logica

**Passo 1 — nao escrever leitor novo.** O parse das tabelas TrueType ja existe
nesta base. O subset acrescenta a **poda**; nao comece do zero.

**Passo 2 — referencia em Python.** Montar o subset com `fontTools`, gravar
num PDF, e confirmar com **MuPDF** que os mesmos glifos saem do arquivo
podado. E o mesmo procedimento do QR Code e do AES: validar contra
decodificador independente antes da porta.

**Passo 3 — o subset minimo util**, na ordem em que as tabelas dependem umas
das outras:

1. `glyf` e `loca`: manter so os glifos usados, mais o `.notdef`, que nao pode
   faltar. Glifo composto referencia outros — **inclua os componentes**, ou o
   caractere sai vazio.
2. `cmap`: remapear para os glifos que sobraram.
3. `hmtx` e `hhea.numberOfHMetrics`: recalcular, porque contam entradas.
4. `head.checkSumAdjustment`: **regravar**. Leitor rigoroso recusa a fonte
   com a soma errada, e o sintoma e "a fonte nao carrega", que nao aponta
   para aqui.

**Passo 4 — duas armadilhas que esta base ja pagou noutro contexto.**

- `checkSumAdjustment` e conta de **32 bits sem sinal** e estoura
  `PLS_INTEGER` (`ORA-01426`, erro de execucao, sem nome de variavel). Faca em
  `NUMBER`. Foi exatamente assim com o Adler-32 do deflate.
- Corte de tabela e binario: trabalhe em **RAW**, nunca VARCHAR2.

**Passo 5 — saber quais glifos entram.** Exige conhecer o texto **antes** de
fechar o documento. Como o `Output` desta base ja monta no fim, da para
acumular um conjunto de caracteres por fonte durante a escrita e podar so na
hora de emitir o `/FontFile2`. Nao exija que o chamador declare os glifos —
isso e o tipo de API que ninguem usa certo.

**Passo 6 — poder desligar.** Um `SetFontSubset(FALSE)` para o caso raro de
alguem precisar da fonte inteira (formulario preenchivel por outro programa,
por exemplo). Padrao ligado.

### Criterio de aceite

- [ ] Referencia Python validada contra MuPDF
- [ ] Glifo composto traz os componentes (teste com caractere acentuado de
      fonte que use composicao)
- [ ] `checkSumAdjustment` recalculado, em `NUMBER`
- [ ] Texto extraido do PDF com subset **identico** ao sem subset
- [ ] Reducao na ordem medida acima, verificada no teste
- [ ] `SetFontSubset` documentado

### Como testar

- Mesmo documento com e sem subset: texto extraido identico, arquivo
  encolhido na ordem esperada
- Um caractere acentuado de fonte com glifo composto, conferido visualmente e
  por extracao
- Abrir em mais de um leitor: o `checkSumAdjustment` errado so aparece nos
  rigorosos

**Estimativa:** 5 a 8 dias. E a mais tecnica da fila.

---

## HU-03 — Sumario e marcadores de navegacao

**Peso: medio-alto.** 9 casos na fonte A, e a unica estrutura da fila que o
PDF resolve com dicionario simples — sem binario, sem codificacao.

**Como** leitor de um relatorio de oitenta paginas,
**quero** o painel de marcadores do leitor de PDF preenchido,
**para** ir direto ao capitulo em vez de rolar procurando.

### Casos de uso

1. **Relatorio gerencial longo.** Capitulos e secoes no painel lateral.
2. **Manual ou contrato.** Clausulas como marcadores de segundo nivel.
3. **Lote consolidado.** Varios documentos mesclados num PDF so, com um
   marcador por documento — encaixa no `MergePDFs` que ja existe.

### Definicao da logica

**Passo 1 — a estrutura.** `/Outlines` do ISO 32000 e uma **lista duplamente
encadeada** de dicionarios. Cada item tem `/Title`, `/Parent`, `/Prev`,
`/Next`, `/First`, `/Last`, `/Count` e um `/Dest` apontando para a pagina. O
catalogo ganha `/Outlines` e, se quiser que o leitor abra com o painel
visivel, `/PageMode /UseOutlines`.

**Passo 2 — a API**, no estilo que a base ja usa:

```
AddBookmark(p_titulo  in varchar2,
            p_nivel   in pls_integer default 1,
            p_pagina  in pls_integer default null)   -- null = pagina corrente
```

**Passo 3 — encadear so na emissao.** Guarde os itens numa tabela indexada
durante a escrita e monte `/Prev`, `/Next`, `/First`, `/Last` e `/Count` **no
fim**, quando todos os destinos ja sao conhecidos. Tentar encadear na hora da
chamada obriga a reescrever objeto ja emitido.

**Passo 4 — o acento do titulo.** `/Title` e string PDF e sofre do **mesmo**
defeito da HU-01: ou converte para WinAnsi, ou emite em UTF-16BE com BOM. Por
isso esta HU vem **depois** da HU-01 — feita antes, nasce com o mesmo defeito
que a outra esta consertando.

**Passo 5 — o sumario visivel e outro problema, e o mais chato.** A pagina com
os titulos e os numeros exige saber o numero da pagina de cada capitulo, que
so se sabe depois de paginar tudo. O caminho conhecido e o que o `{nb}` desta
base ja usa: escrever um marcador no lugar e substituir na emissao. **Sugestao
de escopo:** entregar os marcadores primeiro (que sao baratos e ja resolvem
navegacao) e tratar o sumario visivel como historia separada.

### Criterio de aceite

- [ ] Tres niveis de hierarquia, encadeamento correto nos dois sentidos
- [ ] `/Dest` aponta para a pagina certa, conferido reabrindo o arquivo
- [ ] `/Count` com o sinal certo (negativo = no fechado)
- [ ] Titulo com acento correto (depende da HU-01)
- [ ] Documento sem nenhum marcador continua sem `/Outlines` no catalogo
- [ ] Marcador sobrevive ao `MergePDFs`, ou a limitacao esta documentada

### Como testar

Gerar com tres niveis, reabrir, conferir a arvore e o destino de cada item.
Um caso com zero marcadores confirmando que nada e emitido a toa.

**Estimativa:** 3 a 4 dias para os marcadores. O sumario visivel e outra
historia, de tamanho parecido.

---

## HU-04 — PDF marcado (tagged / PDF-UA) — fora da fila

**Nao esta priorizada.** Registrada para nao se perder, e para que a proxima
pessoa a levantar o assunto encontre a analise em vez de refaze-la.

**Por que saiu:** era o terceiro item por argumento de licitacao publica. A
medicao o poe em **1 caso de 174** na fonte A — penultimo, empatado com o
ultimo. E a norma nao sustentou o argumento: a Lei Brasileira de Inclusao
(art. 63), o eMAG e o Decreto 5.296 obrigam acessibilidade de **sitio web**;
nao se localizou exigencia de PDF/UA em documento de licitacao.

**O que seria preciso**, para quando houver demanda: arvore de estrutura
(`/StructTreeRoot`), marcacao do conteudo com `BDC`/`EMC` por bloco, `/Lang`,
`/MarkInfo`, ordem de leitura explicita e texto alternativo de imagem. E
trabalho grande e **espalhado por todo o gerador de conteudo** — nao e um
modulo que se acrescenta ao lado, e essa e a diferenca entre ele e os outros
tres.

**Gatilho para reavaliar:** exigencia contratual concreta, ou norma que se
possa citar. Nesse caso ele sobe direto, porque nenhuma biblioteca PL/SQL
livre faz isso — deixa de ser paridade e vira diferencial.

---

## HU-05 — Metade da API publica nao tem chamador

**Achado da propria medicao, nao veio de fora.**

69 das 138 APIs publicas sao exercitadas por `examples/` e `dev/tests/`. As
outras 69 compilam, e ninguem as chama neste repositorio.

Nao e o mesmo que estarem quebradas. Mas e **exatamente a situacao** em que
`AddWatermark` passou meses marcado como pronto sem desenhar nada: sem
chamador, nao ha como saber.

**Como** mantenedor,
**quero** saber quais APIs publicas nao tem nenhum chamador,
**para** decidir entre testar, documentar como experimental, ou remover.

**Logica:** um lint que cruze os identificadores das specs com as chamadas em
`examples/` e `dev/tests/`, e liste o que sobrar. A base ja tem
`check_dead_code.py`, que resolve o problema vizinho — provavelmente e
extensao dele, nao script novo.

**Criterio de aceite:** a lista existe, e cada item nela foi classificado em
testar / experimental / remover. Nao e preciso testar todos de uma vez; e
preciso **saber quais sao**.

**Estimativa:** 2 dias para o levantamento. O que fazer com o resultado e
decisao, nao implementacao.
