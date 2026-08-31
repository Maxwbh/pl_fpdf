# PL_FPDF — Manutenção do código

> **Este documento é da equipe que mantém o PL_FPDF, não de quem o usa.**
>
> Quem vai gerar PDF a partir do banco não precisa de nada daqui: a documentação
> de uso é o [`README.md`](../README.md) e a
> [referência de uso](DOCUMENTATION.md), e elas falam só de PDF.
>
> Aqui estão os testes, as verificações do CI, as referências em Python e o
> método de trabalho. É o que se lê antes de mexer no `src/`.

---

## O que é entrega e o que é apoio

A separação vale para ler e para empacotar: só a primeira linha vai para o banco
de quem usa a biblioteca.

| Diretório | Papel | Vai para produção? |
|-----------|-------|--------------------|
| `src/` | Os **dois** packages: `PL_FPDF` (PDF) e `PL_FPDF_UTIL` (QR, barcode, deflate, cripto). É o produto. | **Sim** |
| `extensions/` | Extensões opcionais (PIX, Boleto). **Fora do escopo**: regra de cobrança vai para projeto separado; não são testadas aqui | Sim, se a instalação usar |
| `examples/` | Exemplos prontos para rodar, para quem usa a biblioteca | Não (é documentação) |
| `dev/tests/` | Suíte, validações e diagnósticos | Não |
| `dev/scripts/` | Runner, verificadores do CI, referências em Python, geradores | Não |
| `docs/ROADMAP.md`, este arquivo | Planejamento e método | Não |

| `dist/pl_fpdf_install.sql` | Os quatro fontes num arquivo só, **gerado** de `src/`. É o que se baixa por link direto, sem clone | **Sim** |
| `site/` | A página publicada pelo GitHub Pages (workflow `pages.yml`) | Não |

A instalação de quem usa é o `dist/pl_fpdf_install.sql`, e nada mais.

---

## Atualizar a cópia que roda os testes

**Nesta branch, use `fetch` + `reset`. Nunca `pull`.**

A `melhorias` é mantida como **um commit único**: cada mudança entra por
`git commit --amend` e sobe com `--force-with-lease`, então o SHA muda a cada
envio. Um `git pull` tenta *mesclar* a história nova com a cópia local da
antiga, as duas mexeram nos mesmos arquivos, e o resultado é conflito — toda
vez, sem exceção. Foi assim que apareceram `run_all_tests_BACKUP_276.sql` e
`run_all_tests_REMOTE_276.sql`, sobras de merge que o runner ainda tentou
executar como se fossem teste.

No Git Bash do Windows, o caminho vai entre aspas e com barra normal — `\` é
escape e `&` corta o comando:

```bash
cd "/c/Projetos/M&S/pl_fpdf"
git merge --abort            # se um merge ficou pela metade
git fetch origin melhorias
git reset --hard origin/melhorias
```

**Não use `git clean`.** Foi recomendado uma vez e deu errado: a cópia local
guarda pastas órfãs do layout antigo (`scripts/`, `tests/`, `assets/`, de antes
da reestruturação), o `clean` tenta apagá-las, e o Windows recusa com
`Permission denied` quando algum processo tem arquivo aberto ali. Brigar com
isso não traz nada — as pastas velhas não atrapalham o runner, e as sobras de
merge ele já ignora sozinho.

**`reset --hard` descarta alteração local não enviada.** Na máquina que só
executa teste isso é seguro por construção — não há desenvolvimento ali. Se um
dia houver, rode `git status` antes.

### Quando a cópia local ficar confusa demais

Clone ao lado, em vez de consertar no lugar. É mais rápido, não briga com
arquivo travado, e não arrisca nada — a máquina de teste não tem trabalho a
perder:

```bash
cd "/c/Projetos/M&S"
git clone -b melhorias https://github.com/Maxwbh/pl_fpdf.git pl_fpdf_novo
```

O que fica para trás é reconstruível: `dev/amostras/` e o
`.plfpdf_estado.json` (o progresso entre rodadas, que numa cópia nova começa
zerado — e é o que se quer para uma rodada completa).

## Rodar os testes

O caminho principal é o **runner em Python**. Ele compila, executa a suíte e os
diagnósticos, gera PDFs no banco e os confere com decodificadores reais — MuPDF
para abrir e extrair texto, zxing-cpp para **ler** o QR Code e os códigos de
barras.

```bash
pip install -r dev/scripts/requirements.txt
python dev/scripts/run_tests.py --dsn <alias> --user <usuario>
python dev/scripts/run_tests.py -v            # saída completa, não só as falhas
```

Rodar na **SQL Window do PL/SQL Developer** continua sendo requisito, não
alternativa: todo teste é bloco anônimo puro, sem `SET`, `SPOOL` ou `@`. Abra o
arquivo e execute com F8. Ver [`dev/tests/README.md`](../dev/tests/README.md).

### O runner é progressivo

Rodar tudo a cada mexida custa minutos e esconde a etapa que interessa no meio
do que já passava. O que passou fica em `.plfpdf_estado.json` (por banco e
usuário, fora do Git) e é pulado na rodada seguinte.

```bash
python dev/scripts/run_tests.py --status    # o que está concluído (não conecta)
python dev/scripts/run_tests.py --reset     # zera o progresso e roda do zero
python dev/scripts/run_tests.py --full      # roda tudo sem apagar o progresso
```

Pular **não** é "passou uma vez" — é "passou uma vez **e** nada de que essa
etapa depende mudou". Cada etapa guarda a impressão digital das suas entradas, e
o package é olhado subprograma a subprograma; mudança **profunda** zera tudo:

| O que mudou | Por que zera |
|---|---|
| a spec (`.pks`) | a API não é mais a mesma |
| a parte declarativa do body | tipos, globais e constantes valem para o package inteiro |
| subprograma criado ou removido | é feature, não ajuste |
| mais de 5 subprogramas alterados | refatoração, não conserto |

A compilação tem trava a mais: só é pulada se, além da fonte inalterada, o
`PL_FPDF` estiver `VALID` no schema.

### Dois packages, e a ordem importa

O `src/` tem dois packages desde a separação:

| | |
|---|---|
| `PL_FPDF` | tudo que é PDF: páginas, fontes, desenho, manipulação, segurança do documento |
| `PL_FPDF_UTIL` | o que não é PDF: QR Code, códigos de barras, DEFLATE/INFLATE e criptografia |

**Instale o utilitário primeiro.** O `PL_FPDF` o chama; na ordem inversa, ele
fica inválido até o utilitário existir. O `dist/pl_fpdf_install.sql` e o runner
já fazem isso.

E **recompilar o utilitário invalida o `PL_FPDF`** — o Oracle marca o
dependente como inválido, e a próxima chamada o recompila sozinha ou falha com
`ORA-04068` numa sessão que já o tinha carregado. A separação não reduz isso; o
que ela resolve é outra coisa: 2.600 linhas que não têm nada de PDF saíram de
um arquivo de 14 mil.

A fronteira foi medida antes de ser feita: 57 subprogramas, **uma** chamada
para fora (três linhas de log, que saíram) e **um** estado compartilhado — a
tabela byte→hexadecimal, hoje exposta por `PL_FPDF_UTIL.hex_do_byte`.

### Os exemplos são a fonte, e o runner os executa

Os arquivos de [`examples/`](../examples) não são só documentação: o runner
**carrega e executa** cada um deles contra o banco, e confere o PDF que sai
contra a régua correspondente. Não existe uma segunda cópia do desenho dentro
do `dev/scripts/run_tests.py`.

A adaptação é mínima: tira o cabeçalho de comentário e o `/` final, que são do
arquivo e não do bloco, e acrescenta uma linha devolvendo o BLOB no bind de
saída. Se o exemplo deixar de terminar com `l_pdf := PL_FPDF.OutputBlob();`, o
erro estoura na carga, com o nome do arquivo.

> **Por que assim.** Enquanto houve duas cópias — uma no exemplo, outra no
> runner —, elas divergiram: o conserto do rodapé do ingresso teve de ser
> aplicado nos dois arquivos, e nada garantia que fosse. Um exemplo que desenha
> diferente do que o teste cobre é pior que exemplo nenhum, porque parece
> verificado. `check_examples_sync.py` roda no CI e falha se algum exemplo
> deixar de ser exercitado, ou se alguém colar um bloco de volta no runner.

### O que o runner não cobre: regra de cobrança

O `PL_FPDF` **desenha**. Montar o código de barras de um boleto a partir de
banco, vencimento, valor e campo livre — dígito verificador, fator de
vencimento, as faixas de cada banco — é regra de cobrança, e isso é assunto de
outro projeto.

Por isso a extensão [`extensions/brazilian-payments`](../extensions/brazilian-payments)
está **fora do escopo do runner**: ela não é instalada nem exercitada aqui. A
amostra `boleto` recebe os 44 dígitos prontos, como qualquer outro dado que o
chamador passa, e o que se verifica dela é o **desenho** — caixa, fonte, corpo,
linha de base e alinhamento, campo a campo, contra
[`dev/scripts/boleto_reference/`](../dev/scripts/boleto_reference/README.md).

> **Fixture que muda sozinho nunca é pulado.** A impressão digital de uma
> amostra inclui os bytes do PDF de origem, quando ela parte de um. Se o
> construtor gerar um arquivo diferente a cada chamada — o MuPDF grava um `/ID`
> novo toda vez — a impressão muda sem que nada da definição tenha mudado, e a
> etapa volta a rodar para sempre. Os construtores normalizam o `/ID`
> preservando o comprimento, o que também torna a falha reproduzível.

> **Reconecte depois de recompilar.** O package tem estado; uma sessão que já o
> carregou passa a falhar com `ORA-04068`/`ORA-06508`. O runner reconecta
> sozinho; na SQL Window, abra sessão nova.

---

## Verificações que rodam sem banco (as mesmas do CI)

```bash
python dev/scripts/plsql_lint/check_declarations.py src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_spec_body.py    src/PL_FPDF.pks src/PL_FPDF.pkb
python dev/scripts/plsql_lint/check_spec_body.py    src/PL_FPDF_UTIL.pks src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_call_order.py   src/PL_FPDF.pks src/PL_FPDF.pkb
python dev/scripts/plsql_lint/check_call_order.py   src/PL_FPDF_UTIL.pks src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_clob_bytes.py   src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb src/PL_FPDF.pks dev/tests/*.sql
python dev/scripts/plsql_lint/check_error_codes.py  src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_byte_chars.py   src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_assoc_nvl.py   src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_pls_overflow.py   src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_dead_code.py    src/PL_FPDF.pks src/PL_FPDF.pkb
python dev/scripts/plsql_lint/check_dead_code.py    src/PL_FPDF_UTIL.pks src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_tables.py
python dev/scripts/plsql_lint/check_test_calls.py
python dev/scripts/plsql_lint/check_examples_sync.py
python dev/scripts/build_run_all.py --check
python dev/scripts/gen_docs/check_refs.py
python dev/scripts/gen_docs/check_links.py
python dev/scripts/gen_docs/check_paridade.py
```

Cada um existe porque um erro específico custou uma rodada de compilação ou uma
ida ao banco. A tabela com o que cada um pega está no
[roadmap](ROADMAP.md#verificações-automáticas-no-ci).

---

## Referências validadas contra decodificadores externos

Nada que um leitor externo precise entender é escrito direto em PL/SQL. Primeiro
uma referência em Python, validada contra um decodificador **independente**, e
só então a porta. Foi o que separou "desenha um símbolo" de "um leitor
decodifica", e "marcado como protegido" de "protegido".

```bash
python dev/scripts/qr_reference/validate.py          # zxing-cpp
python dev/scripts/barcode_reference/validate.py     # zxing-cpp
python dev/scripts/pdfmerge_reference/validate.py    # MuPDF
python dev/scripts/pdfcrypt_reference/validate.py    # MuPDF
python dev/scripts/pdfoverlay_reference/validate.py  # MuPDF
python dev/scripts/pdfimage_reference/validate.py    # pixels desenhados
python dev/scripts/pdfaes_reference/validate.py      # vetores do FIPS-197 + MuPDF
python dev/scripts/pdfinflate_reference/validate.py  # zlib
python dev/scripts/pdfdeflate_reference/validate.py  # zlib
python dev/scripts/pdfxref_reference/validate.py     # MuPDF
python dev/scripts/pdfobjstm_crypt_reference/validate.py  # MuPDF
python dev/scripts/boleto_reference/validate.py           # métricas + zxing
python dev/scripts/ticket_reference/validate.py           # cor + QR + Code 39
```

---

## Arquivos gerados — não edite à mão

| Gerado | Gerador | Fonte de verdade |
|--------|---------|------------------|
| `dev/tests/run_all_tests.sql` | `dev/scripts/build_run_all.py` | `dev/tests/test_*.sql` |
| `dist/pl_fpdf_install.sql` | `dev/scripts/build_release.py` | `src/*.pks`, `src/*.pkb` |
| `dev/tests/diag_xrefstm.sql` | `dev/scripts/pdfxref_reference/gen_diag.py` | os construtores de `validate.py` |

O CI falha se algum deles estiver desatualizado.

---

## Método

1. **Referência antes da porta** — ver acima.
2. **Recusar em vez de entregar errado.** Quando algo não é suportado, levantar
   erro com mensagem clara. Um PDF marcado como protegido que não está, ou uma
   imagem que sai como ruído, custa mais caro que uma exceção.
3. **Cada erro que custou uma rodada vira lint no CI.**

## Armadilhas do PL/SQL já pagas nesta base

- Itens declarados **depois** do primeiro corpo de subprograma → `PLS-00103`.
  Todas as globais ficam no início do package.
- Chamada a subprograma definido mais abaixo → `PLS-00313`. Use as declarações
  antecipadas do início do body.
- Um `/*` órfão já engoliu `AddQRCode` e `AddBarcode` inteiros — 892 linhas
  viraram comentário e o Oracle acusou `PLS-00323`.
- `SUBSTRB`/`LENGTHB`/`INSTRB` em CLOB compilam e quebram em execução com
  `ORA-22998` em banco multibyte. Use `DBMS_LOB.*`.
- `STANDARD_HASH` não aceita LOB: `ORA-00902`, sem dizer qual argumento.
- O PL/SQL não tem operador de ou-exclusivo: `a + b - 2 * BITAND(a, b)`.
- Uma função BOOLEAN pode devolver NULL, e `IF NOT f() THEN` não dispara.
  Envolva em `NVL(..., FALSE)`. **Mesma família, e mais cara:** `SUBSTR` que
  devolve vazio é NULL, `INSTR(NULL, ...)` é NULL, e um `EXIT WHEN l_p = 0` com
  `l_p` nulo **não sai** — comparação com NULL dá NULL. Um laço assim estoura a
  PGA (`ORA-04036`) e o stack aponta para o laço, não para a causa.
- **`CHR(n)` não devolve um byte** — devolve o caractere daquele ponto de
  código, no charset do banco. Em AL32UTF8 todo valor de 128 a 255 sai com
  **dois** bytes. Montar string binária byte a byte com `CHR` produz um
  resultado mais longo e diferente. Use `UTL_RAW.CAST_TO_VARCHAR2`, que não
  converte charset — a mesma função que o `pdf_read` usa.
  (`check_byte_chars.py`)
- **A mesma confusão pelo outro lado:** `SUBSTRB(x, k, 1)` extrai um byte, e um
  byte do meio de um caractere multibyte **não volta como ele**. Remontar dado
  binário byte a byte num VARCHAR2 e devolvê-lo a `UTL_RAW.CAST_TO_RAW` não
  recupera o binário. Trabalhe em RAW. O sintoma engana: com cifra de fluxo
  (RC4), corromper o byte *i* corrompe **só** o byte *i*, então o texto volta
  com a maioria das letras certas — não vira lixo, que é o que se esperaria de
  chave errada. (`check_byte_chars.py`)
- **`NVL` não serve para duas coisas.** Sobre elemento de tabela indexada não
  evita `NO_DATA_FOUND` — o índice é lido primeiro e a exceção sobe antes; use
  `.EXISTS(i)`. E sobre `BLOB`/`CLOB` **não compila** (`PLS-00306`): o `NVL` do
  PL/SQL não tem sobrecarga para LOB, e a mensagem fala de "wrong number or
  types of arguments" sem dizer qual é o problema. Teste `IS NULL`.
  (`check_assoc_nvl.py`)
- `PLS_INTEGER` estoura em 2147483647 — `/P` convertido para sem sinal passa
  disso. Use `NUMBER`.
- Não há `DBMS_CRYPTO` nesta base, por decisão. MD5 e SHA saem do
  `STANDARD_HASH`; RC4 e AES são implementados no próprio package.

---

Planejamento, pendências e o que cada verificação do CI pega: [`ROADMAP.md`](ROADMAP.md).
