# Como contribuir com o PL_FPDF

> **Documento de manutenção.** Aqui se fala de teste, lint e CI. Quem só quer
> gerar PDF não precisa de nada disto — o caminho é
> [`README.md`](README.md) e [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md).

O repositório tem dois lados, e vale saber de qual você está mexendo:

| Pasta | O que é | Vai para o banco? |
|-------|---------|-------------------|
| `src/` | Os dois packages: `PL_FPDF_UTIL` e `PL_FPDF` | **Sim** |
| `examples/` | Exemplos `.sql` prontos para rodar | Sim (o usuário roda) |
| `dist/` | `pl_fpdf_install.sql`, **gerado** de `src/` | Sim |
| `docs/`, `site/` | Documentação e a página publicada | Não |
| `dev/tests/` | Suíte, validações e diagnósticos | Não |
| `dev/scripts/` | Runner, verificações do CI, referências em Python | Não |

Três arquivos são **gerados** — edite a origem, nunca o resultado:

| Gerado | Origem | Comando |
|--------|--------|---------|
| `dist/pl_fpdf_install.sql` | `src/*.pks`, `src/*.pkb` | `python dev/scripts/build_release.py` |
| `dev/tests/run_all_tests.sql` | `dev/tests/test_*.sql` | `python dev/scripts/build_run_all.py` |

---

## O CHANGELOG é curto

**De 10 a 20 linhas por versão, no máximo.** Ele é para quem *usa* a
biblioteca: o que ganhou, o que quebrou, o que saiu. Uma linha por item,
agrupada em Adicionado / Corrigido / Alterado / Removido.

Defeito miúdo entra somado — "mais 14 defeitos, cada um com teste" — não um
parágrafo cada.

**O relato longo tem outro lugar.** Sintoma, causa e conserto ficam no
comentário do código e no cabeçalho da verificação que guarda aquele defeito,
em `dev/scripts/plsql_lint/`. É lá que serve, porque é lá que alguém está
quando precisa da história.

A entrada da 3.3.0 chegou a ter **966 linhas** — as outras versões têm de 17 a
58. Um changelog que ninguém termina de ler não avisa ninguém de nada.


## Os três passos, nesta ordem

A ordem existe para o erro aparecer barato. As verificações sem banco levam
segundos; a rodada contra o banco leva minutos.

### 1. Verificações sem banco — as mesmas do CI

```bash
pip install -r dev/scripts/requirements.txt
```

Elas pegam o que o Oracle só contaria em execução, ou contaria com uma mensagem
que aponta para o lugar errado:

```bash
python dev/scripts/plsql_lint/check_declarations.py src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_spec_body.py    src/PL_FPDF.pks src/PL_FPDF.pkb
python dev/scripts/plsql_lint/check_spec_body.py    src/PL_FPDF_UTIL.pks src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_call_order.py   src/PL_FPDF.pks src/PL_FPDF.pkb
python dev/scripts/plsql_lint/check_call_order.py   src/PL_FPDF_UTIL.pks src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_clob_bytes.py   src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb src/PL_FPDF.pks dev/tests/*.sql
python dev/scripts/plsql_lint/check_error_codes.py  src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_byte_chars.py   src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_assoc_nvl.py    src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_pls_overflow.py src/PL_FPDF.pkb src/PL_FPDF_UTIL.pkb
python dev/scripts/plsql_lint/check_dead_code.py    src/PL_FPDF.pks src/PL_FPDF.pkb
python dev/scripts/plsql_lint/check_tables.py
python dev/scripts/plsql_lint/check_test_calls.py
python dev/scripts/plsql_lint/check_examples_sync.py
python dev/scripts/build_run_all.py  --check
python dev/scripts/build_release.py  --check
python dev/scripts/gen_docs/check_refs.py
python dev/scripts/gen_docs/check_links.py
```

Cada uma dessas verificações nasceu de um erro que custou uma rodada inteira. O
que cada uma pega — e por que aquele erro foi caro — está na tabela de
[`docs/ROADMAP.md`](docs/ROADMAP.md), e o cabeçalho de cada script conta o caso
que o originou.

### 2. A suíte contra um banco

```bash
# credenciais por argumento ou pelas variáveis PLFPDF_USER / PLFPDF_PASSWORD / PLFPDF_DSN
python dev/scripts/run_tests.py --dsn <alias> --user <usuario>
python dev/scripts/run_tests.py -v          # saída completa, não só as falhas
```

Ele instala os packages, roda a suíte, gera os PDFs de amostra em
`dev/amostras/` e **valida o que saiu** — geometria, texto, códigos de barras
lidos por um decodificador externo. Não passe senha na linha de comando; use a
variável de ambiente.

O runner é progressivo: etapa que passou fica registrada em
`.plfpdf_estado.json` e é pulada na rodada seguinte, desde que nada de que ela
depende tenha mudado.

```bash
python dev/scripts/run_tests.py --status    # o que está concluído (não conecta)
python dev/scripts/run_tests.py --reset     # zera e roda do zero
python dev/scripts/run_tests.py --full      # roda tudo sem zerar
```

Tudo também roda na SQL Window do PL/SQL Developer: os `.sql` são blocos
anônimos separados por `/` na própria linha, sem nenhum comando de SQL\*Plus.

### 3. Um exemplo, se o recurso for visível

Recurso que muda o desenho da página entra em `examples/` — é o mesmo arquivo
que o runner carrega para testar, então exemplo e teste não podem divergir
(`check_examples_sync.py` garante).

---

## O método que a base adota

1. **Referência antes da porta.** Para qualquer coisa que um leitor externo
   precise entender (QR Code, código de barras, DEFLATE, criptografia), primeiro
   uma referência em Python **validada contra um decodificador independente** —
   zlib, zxing-cpp, MuPDF, vetores do FIPS — e só então a porta para PL/SQL. Foi
   isso que separou "desenha um símbolo" de "um leitor decodifica".
2. **Recusar em vez de entregar errado.** Quando algo não é suportado, levante
   erro com mensagem clara. Um PDF marcado como protegido que não está custa
   mais caro que uma exceção.
3. **Cada erro que custou uma rodada vira lint no CI.**

---

## Estilo e commits

- **Variáveis:** `l_` para locais, `p_` para parâmetros, `g_` para globais.
- **Comentários:** só quando a lógica não é evidente — e explicando *por quê*,
  não *o quê*.
- **Compatibilidade:** Oracle 19c. Sem objeto de banco além dos dois packages,
  e sem `DBMS_CRYPTO`.
- **Mensagens de commit:** [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`).

## Antes de abrir o Pull Request

- [ ] As verificações sem banco passam
- [ ] A suíte passa contra um banco
- [ ] Os arquivos gerados foram regerados (`--check` passa nos três)
- [ ] A documentação do lado certo foi atualizada — usuário e manutenção não se
      misturam

---

## Relatando um problema

Abra uma issue com a versão do Oracle, a versão do PL_FPDF
(`SELECT PL_FPDF.co_version FROM DUAL`), como reproduzir e a mensagem de erro
inteira.

## Contato

- **Autor:** Maxwell da Silva Oliveira (@maxwbh)
- **E-mail:** maxwbh@gmail.com
