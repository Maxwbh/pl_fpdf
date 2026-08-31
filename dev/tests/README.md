# PL_FPDF — Suíte de testes

> **Material de manutenção.** Quem usa a biblioteca não precisa de nada deste
> diretório: a documentação de uso é o [`README.md`](../../README.md) e a
> [referência de uso](../../docs/DOCUMENTATION.md). O ponto de entrada da
> manutenção é [`docs/MANUTENCAO.md`](../../docs/MANUTENCAO.md).

## Como executar

Os testes são **blocos anônimos PL/SQL puros** — sem `SET`, `PROMPT` ou `@`.
Isso permite executá-los na **SQL Window do PL/SQL Developer**, que não aceita
comandos de cliente do SQL*Plus.

> **Reconecte a sessão depois de recompilar o package.** O PL_FPDF tem estado
> (variáveis de package): uma sessão que já o carregou passa a falhar com
> `ORA-04068` ou `ORA-06508` — *"não foi localizada a unidade de programa"* — em
> todas as chamadas seguintes. O sintoma engana (parece package quebrado), mas
> basta abrir uma sessão nova.

### Runner Python — o caminho principal

`dev/scripts/run_tests.py` compila, executa e **valida os PDFs gerados com
decodificadores reais** — o que os testes PL/SQL não conseguem fazer sozinhos.
Nesta branch ele é o caminho que se prioriza: todo teste novo tem de ser
alcançável por ele. Rodar na SQL Window continua sendo requisito, não
alternativa.

```bash
pip install -r dev/scripts/requirements.txt

# Autonomous Database: aponte o wallet e use o alias do tnsnames.ora
set TNS_ADMIN=C:\app\maxwb\product\19.0.0\client_1\network\admin
python dev/scripts/run_tests.py --dsn devimesclaudo_high --user MEU_USER
```

O que ele faz, nesta ordem:

1. **Compila** `PL_FPDF.pks` e `.pkb` na ordem certa e consulta `USER_ERRORS` —
   nada de erro de compilação passar despercebido.
2. **Reconecta**, porque o package tem estado e uma sessão que já o carregou
   falha com `ORA-04068`/`ORA-06508` depois da recompilação.
3. **Roda** a suíte (`test_*.sql`, `validate_*.sql`) e também os
   diagnósticos (`diag_*.sql` que sigam a convenção `[PASS]`/`[FAIL]`),
   capturando o `DBMS_OUTPUT` e somando os resultados. Os diagnósticos nasceram
   para a SQL Window, mas deixá-los fora do runner faria com que só fossem
   executados quando alguém lembrasse.
4. **Gera amostras** no banco (documento simples, QR Code PIX, CODE128,
   EAN-13, merge e extract), traz os BLOBs e salva em `dev/amostras/`.
5. **Valida** cada uma: o MuPDF abre e confere páginas e texto; o **zxing-cpp
   decodifica** o QR e os códigos de barras e compara com o conteúdo original.

O passo 5 é o que os testes no banco não alcançam: eles contam os retângulos
que o símbolo emite no fluxo do PDF, o que pega regressão mas não prova
legibilidade. Aqui um leitor de verdade lê o símbolo.

Etapas isoladas: `--compile`, `--tests`, `--validate`.

#### O runner é progressivo

Rodar tudo a cada mexida custa minutos e, pior, esconde a etapa que interessa no
meio de cem linhas que já passavam. O que passou fica registrado em
`.plfpdf_estado.json` (por banco e usuário, fora do Git) e é pulado na rodada
seguinte.

```bash
python dev/scripts/run_tests.py --status    # o que está concluído (não conecta)
python dev/scripts/run_tests.py --reset     # zera o progresso e roda do zero
python dev/scripts/run_tests.py --full      # roda tudo sem apagar o progresso
```

Pular **não** é "passou uma vez". É "passou uma vez **e** nada de que essa etapa
depende mudou desde então" — senão o runner passaria a mentir, que é o modo de
falhar mais caro que um teste pode ter. Duas travas:

1. **Cada etapa guarda a impressão digital das suas próprias entradas** — o
   arquivo de teste, ou o bloco e as expectativas da amostra. Editou, volta a
   rodar.
2. **O package é olhado subprograma a subprograma.** Mexer no corpo de alguns
   preserva o progresso; mudança **profunda** zera tudo, porque aí qualquer
   etapa pode ter regredido:

   | O que mudou | Por que zera |
   |---|---|
   | a spec (`.pks`) | a API não é mais a mesma |
   | a parte declarativa do body | tipos, globais e constantes valem para o package inteiro |
   | subprograma criado ou removido | isso é feature, não ajuste |
   | mais de 5 subprogramas alterados | refatoração, não conserto |

A compilação tem uma trava a mais: ela só é pulada se, **além** de a fonte estar
inalterada, o `PL_FPDF` estiver de fato `VALID` no schema. Só o arquivo de
estado deixaria um schema novo — ou um `DROP` — passar batido e fazer todo o
resto falhar em seguida.

### PL/SQL Developer (SQL Window)

Abra o arquivo e execute (F8). O resultado aparece na aba **Output**.

- Suíte completa: `dev/tests/run_all_tests.sql`
- Uma área só: qualquer `dev/tests/test_*.sql` ou `dev/tests/validate_*.sql`
- **Um assunto só, sem depender da suíte:** os `dev/tests/diag_*.sql`. São blocos
  independentes, com os vetores embutidos, para provar um caminho recém-portado
  antes de rodar tudo:

  | Arquivo | O que prova |
  |---------|-------------|
  | `diag_inflate.sql` | O INFLATE do package contra vetores do zlib — os três tipos de bloco do DEFLATE e a cópia sobreposta do LZ77 |
  | `diag_xrefstm.sql` | Leitura de **xref em stream** e **object streams** (PDF 1.5+): predictor PNG nos cinco filtros, `/W` com campo de largura zero, `/Index` com várias faixas, híbrido `/XRefStm` e a recusa do predictor TIFF |
  | `diag_password.sql` | Derivação de chave e verificação de senha |
  | `diag_utl_compress*.sql` | Por que o `UTL_COMPRESS` **não** serve como inflate (o resultado está no cabeçalho de cada um) |

  `diag_xrefstm.sql` é **gerado** por `dev/scripts/pdfxref_reference/gen_diag.py` a
  partir dos mesmos construtores que a referência confere contra o MuPDF — não
  edite os literais à mão.

### SQL*Plus / SQLcl

Habilite a saída antes, já que fora do PL/SQL Developer o `DBMS_OUTPUT` não vem
ligado:

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
@dev/tests/run_all_tests.sql
```

> `dev/tests/run_all_tests.sql` é **gerado** por `dev/scripts/build_run_all.py`, que
> concatena os blocos dos testes individuais na ordem de execução. Para alterar
> um teste, edite o arquivo original e rode o script; o CI confere que o
> arquivo gerado está atualizado.

---

## Estrutura

Um runner, uma validação por área — sem duplicatas:

```
dev/tests/
├── run_all_tests.sql              # Único runner: executa tudo abaixo, em ordem
├── validate_phases_1_3.sql        # Geração de PDF (init, fontes, imagens, UTF-8)
├── test_phase_4_parser_basic.sql  # Parser de PDF existente
├── test_phase_4_1b_pages.sql      # Leitura de páginas
├── test_phase_4_2_page_mgmt.sql   # Rotação / remoção de páginas
├── test_phase_4_3_watermark.sql   # Marca d'água
├── test_phase_4_4_output.sql      # OutputModifiedPDF
├── test_phase_4_5_overlay.sql     # Overlay de texto/imagem
├── test_phase_4_6_merge_split.sql # Merge e split
├── validate_phase_4_complete.sql  # Integração da manipulação de PDF
├── test_phase_security.sql        # Criptografia: RC4, AES-128 e AES-256
│
├── diag_inflate.sql               # INFLATE contra vetores do zlib
├── diag_xrefstm.sql               # xref em stream e object streams (gerado)
├── diag_password.sql              # Derivação de chave e verificação de senha
└── diag_utl_compress*.sql         # Por que o UTL_COMPRESS não serve (registro)
```

Os testes da extensão PIX/Boleto ficam em
[`extensions/brazilian-payments/tests/`](../../extensions/brazilian-payments/tests/).

---

## Requisitos

- Oracle 19c+ com o `PL_FPDF` instalado (`@dist/pl_fpdf_install.sql`)
- `SERVEROUTPUT` ligado fora do PL/SQL Developer
- Nenhum framework: blocos anônimos com saída `[PASS]`/`[FAIL]`
- Para o runner Python: `pip install -r dev/scripts/requirements.txt`
