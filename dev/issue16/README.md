# Issue 16 do projeto de origem — medição e conserto

> **DOCUMENTO DE MANUTENÇÃO.** Nada nesta pasta vai para quem usa a biblioteca,
> e nada daqui é publicado. O que sai para o `Pilooz/pl_fpdf` é **um patch**, e
> só depois que a medição abaixo passar.

A [issue 16](https://github.com/Pilooz/pl_fpdf/issues/16) relata `ORA-29275:
partial multibyte character` na primeira chamada, logo depois do `AddPage`, num
banco **AL32UTF8** — e o mesmo código sempre funcionou em WE8MSWIN1252.

## O defeito

`CHR(n)` não devolve "o caractere da posição n": devolve o caractere cujo
**byte** é `n` no charset do banco. Num banco de um byte, todo valor de 0 a 255
é caractere válido. Em AL32UTF8 não é: de 128 a 191 são bytes de continuação do
UTF-8, e **de 192 em diante** o byte abre uma sequência multibyte que nunca se
completa.

A pilha do relato aponta a linha da tabela de larguras da Helvetica onde o
`chr(192)` aparece, alcançada por `AddPage → SetFont → p_includeFont →
getFontHelvetica`.

São **três** defeitos, não um. Consertar só o primeiro faz o erro andar do
`AddPage` para o `Output`, na mesma rodada:

| # | Onde | Sintoma em AL32UTF8 |
|---|---|---|
| 1 | as 11 tabelas `getFontXxx`, com `mySet(chr(n))` | `ORA-29275` no primeiro `AddPage` |
| 2 | o `/Widths` do dicionário da fonte, com `cw(chr(i))` de 32 a 255 | o mesmo erro, ao fechar o arquivo |
| 3 | `GetStringWidth`, `MultiCell` e `Write` | `ORA-06502` (`c car` guarda um byte, o acentuado tem dois) e, passando disso, `NO_DATA_FOUND` |

## Um pré-requisito, medido no banco

**A 2.0.0, como está na tag, não compila.** O body redeclara duas constantes
que a spec já declara, e o Oracle recusa:

```
PLS-00371: at most one declaration for 'CO_PL_FPDF_VERSION' is permitted
```

Sem isso não há ANTES para comparar. O `montar.py` remove a declaração **do
body** — a spec é a interface publicada — e aplica isso às **duas** versões, de
propósito: o que se quer isolar é o conserto da issue 16, e diferença que
aparece nos dois lados não polui a comparação.

Esse remendo **não entra no patch** que vai para a origem: lá é outro assunto,
e misturar os dois num patch só faria o revisor ter de separar.

## Como rodar

```bash
python dev/issue16/montar.py                              # gera os packages
python dev/issue16/validar.py --dsn <alias> --user <usuario>
```

A senha vem de `PLFPDF_PASSWORD` ou do prompt, nunca da linha de comando — como
no `run_tests.py`.

O `validar.py` instala a 2.0.0 **duas vezes** no seu schema, com nome próprio:
`PL_FPDF_I16_ANTES` (como está na origem) e `PL_FPDF_I16_DEPOIS` (com o
conserto). Instalar como `PL_FPDF` derrubaria a 3.4.0 do schema — o nome existe
para isso, e os dois são removidos no fim (`--manter` segura).

## O que a medição prova, e o que não prova

**A comparação é o teste.** Caso que passa nas duas versões não prova nada:
prova que esta instância não alcança aquele defeito. O que vale é a diferença —
o que levanta ANTES e responde DEPOIS.

Isso importa aqui por um motivo medido: neste banco AL32UTF8,
`DUMP(CHR(192))` devolve `Typ=1 Len=1: 192`, o byte cru, **sem levantar**. A
documentação da Oracle diz que ponto de código inválido "não é validado, e o
resultado é indeterminado" — então o mesmo código derruba uma instância e, em
outra, monta em silêncio uma tabela de chaves inválidas. O caso 1 pode passar
aqui e falhar no banco de quem relatou; os casos 2 e 3 não dependem disso.

Se nada falhar no ANTES, o validador diz **INCONCLUSIVO** em vez de dizer OK: o
conserto não quebrou nada, mas quem prova que ele resolve é outro banco.

## Resultado medido

Rodado em **29/09/2026**, contra um Oracle 19c **AL32UTF8**:

| caso | ANTES | DEPOIS |
|---|---|---|
| Init + AddPage (o relato da issue) | ok | ok |
| GetStringWidth com acento | **ORA-06502** | ok — 45,1781 |
| MultiCell com acento | **ORA-20100 / ORA-01403** | ok |
| documento inteiro, do Cell ao OutputBlob | ok | ok — 1035 bytes nos dois |

Dois defeitos reproduzidos e fechados, nenhuma regressão. O documento sai com
**o mesmo tamanho** nas duas versões, que é o que se espera: nenhuma largura
mudou de valor.

Os dois casos que passam nos dois lados são os que dependem do `CHR` acima de
191 — e nesta instância o `CHR(192)` devolve o byte cru sem levantar. **O
relato da issue não se reproduz aqui**, e isso não enfraquece o conserto: a
pilha do relato aponta a linha exata do `chr(192)`, e a documentação da Oracle
diz que o resultado é indeterminado. O que esta medição prova é o que ela pode
provar — que a mesma raiz derruba outras duas chamadas, aqui, e que o conserto
as fecha.

## O que sai daqui para a origem

```bash
python dev/issue16/montar.py --patch     # dev/issue16/fix16.patch
```

O patch é o diff contra o `PL_FPDF.pkb` da tag `2.0.0` **deste** repositório,
que é a mesma 2.0.0 da origem. O conserto é descrito uma vez só, em
`consertar()`, e tanto o patch quanto os packages de teste saem dele — patch
mantido à mão, ao lado do código que ele altera, é como as duas versões
divergem.

`build/` e `fix16.patch` são gerados e ficam fora do Git, pelo mesmo motivo.

**Abrir PR ou comentar na origem é do @maxwbh.** Daqui sai o texto pronto e o
comando pronto.

## Promover para a origem, passo a passo

A base do PR **não é a tag `2.0.0`**: é a `upstream-fix-2.0.0`, que descende da
história da origem e já carrega o conserto do `PLS-00371`. O `--base` existe
para isso — validar o que VAI subir vale mais do que validar um primo dele.

**1. Gerar o patch a partir da base do PR, e guardá-lo fora da árvore.**
O arquivo é ignorado pelo Git, então trocar de branch não o apaga; copiar para
fora tira a dúvida de vez.

```bash
cd "/c/Projetos/M&S/pl_fpdf"
git fetch origin issue-16 upstream-fix-2.0.0
git checkout issue-16

python dev/issue16/montar.py --patch --base origin/upstream-fix-2.0.0
cp dev/issue16/fix16.patch /tmp/fix16.patch
```

**2. Validar exatamente o que vai subir.** Os packages saem da mesma base do
PR, e não da tag:

```bash
python dev/issue16/montar.py --base origin/upstream-fix-2.0.0
python dev/issue16/validar.py --dsn <alias> --user <usuario>
```

Só siga se o resumo disser **OK**, com pelo menos um `CONSERTADO` e nenhuma
`REGRESSÃO`.

**3. A branch do PR, com o commit assinado.**

```bash
git checkout -B issue-16-upstream origin/upstream-fix-2.0.0
git apply /tmp/fix16.patch
git add PL_FPDF.pkb
git commit -S -m "fix: ORA-29275 on AL32UTF8 -- the width tables are keyed by CHR(n)"
git push -u origin issue-16-upstream
```

O `-S` importa: é a sua chave que assina, e o selo *Verified* só sai daí.

**4. Conferir antes de abrir o PR:**

```bash
git show --stat            # um arquivo, PL_FPDF.pkb
git log --format='%G? %an %s' -1   # G de good, e o seu nome
```

**5. Abrir o PR na origem e comentar a issue 16.** É do @maxwbh — o texto do
corpo e o do comentário saem prontos da sessão que preparou o conserto.

Se o `git apply` reclamar, é porque a base andou: regere o patch com o
`--base` da referência nova. Nunca edite o `fix16.patch` à mão — ele é gerado,
e o conserto é descrito uma vez só, no `consertar()`.
