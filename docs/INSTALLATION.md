# Instalação e atualização — PL_FPDF

[**English**](INSTALLATION_EN.md) · [Índice da documentação](README.md)

Este guia cobre instalar, conferir, dar acesso a outros schemas, atualizar,
voltar uma versão e desinstalar. Para o que fazer depois, veja o
[guia de uso](DOCUMENTATION.md); para erros, [Problemas comuns](TROUBLESHOOTING.md).

---

## 1. O que é instalado

Dois packages, e nada mais: `PL_FPDF` (o PDF) e `PL_FPDF_UTIL` (QR Code,
códigos de barras, compressão e criptografia, que o `PL_FPDF` usa). Nenhuma
tabela, sequência, tipo, job ou diretório. O estado de um documento vive nas
variáveis do package, dentro da sessão.

## 2. Requisitos

| | |
|---|---|
| Oracle | 19c ou superior — a situação de cada versão está em [Compatibilidade](COMPATIBILITY.md) |
| Privilégio para instalar | `CREATE PROCEDURE` no schema de destino |
| Dependências | nenhuma: nem `DBMS_CRYPTO`, nem Java, nem ACL de rede |

Opcionais, só se você usar o recurso:

| Recurso | Precisa de |
|---|---|
| `OutputFile`, `LoadTTFFromFile` | um `DIRECTORY` com `READ`/`WRITE` **para o dono do PL_FPDF** (ver §6) |
| `Image` por URL | ACL de rede **para o dono do PL_FPDF**. `ImageFromBlob` não precisa |

## 3. Qual arquivo baixar

| Para | Arquivo |
|------|---------|
| **Produção** em Oracle 19c — a versão estável, 3.3.0 | [`pl_fpdf_install.sql` do release v3.3.0](https://github.com/Maxwbh/pl_fpdf/releases/download/v3.3.0/pl_fpdf_install.sql) |
| **Oracle 26ai** | **não há versão estável que funcione**: a 3.3.0 levanta `ORA-29275`. A única que roda é a candidata [v3.4.0-rc2](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2) — ver a [política para o 26ai](../SECURITY.md#oracle-26ai) |
| **Testar a 3.4.0** — candidata | [`pl_fpdf_install.sql` do v3.4.0-rc2](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2) |
| **Exatamente o que esta documentação descreve** | o [`dist/pl_fpdf_install.sql`](../dist/pl_fpdf_install.sql) da branch que você está lendo — o link segue a branch |
| **Acompanhar o desenvolvimento** | [`dist/pl_fpdf_install.sql` da `master`](https://raw.githubusercontent.com/Maxwbh/pl_fpdf/master/dist/pl_fpdf_install.sql) |

Para um chamado de mudança, use sempre o arquivo de um **release**: a URL é
fixa, e o `SHA256.txt` publicado ao lado diz se o que você baixou é o que foi
publicado. A `master` muda a cada merge.

### Conferir o download

O `SHA256.txt` tem o formato do próprio `sha256sum` (desde a 3.4.0):

```bash
sha256sum -c SHA256.txt          # Linux / macOS (no macOS: shasum -a 256 -c)
```

```powershell
Get-FileHash pl_fpdf_install.sql -Algorithm SHA256   # Windows: compare com o SHA256.txt
```

No release v3.3.0, o `SHA256.txt` traz só a soma, sem o nome do arquivo:
compare o valor a olho, ou use
`sha256sum -c <(echo "$(cat SHA256.txt)  pl_fpdf_install.sql")`.

## 4. Instalar

O instalador é **só SQL** — nenhum comando de SQL\*Plus —, e roda igual em
qualquer ferramenta:

| Ferramenta | Como |
|---|---|
| PL/SQL Developer | abra o arquivo numa **SQL Window** e execute (F8) |
| SQL\*Plus / SQLcl | `@pl_fpdf_install.sql` |
| SQL Developer | abra o arquivo e rode como script (F5) |

Conecte como o **schema que vai ser dono** dos packages. A ordem já vem certa:
`PL_FPDF_UTIL` primeiro, porque o `PL_FPDF` depende dele.

**A partir de um clone**, a ordem é a mesma — o utilitário primeiro:

```sql
@src/PL_FPDF_UTIL.pks
@src/PL_FPDF_UTIL.pkb
@src/PL_FPDF.pks
@src/PL_FPDF.pkb
```

## 5. Conferir

```sql
-- A versão: sai na aba Output (no SQL*Plus, ligue antes o SET SERVEROUTPUT ON).
-- Num SELECT não dá: constante de package só se lê em PL/SQL, e o
-- SELECT PL_FPDF.co_version FROM DUAL levanta ORA-06553 PLS-221.
BEGIN
  DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version);
END;
/

-- Os quatro objetos precisam estar VALID
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
 ORDER BY 1, 2;

-- E não pode haver erro de compilação
SELECT name, type, line, position, text
  FROM user_errors
 WHERE name IN ('PL_FPDF', 'PL_FPDF_UTIL');
```

Um teste de fumaça, que gera um PDF de uma página em memória:

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);
  PL_FPDF.Cell(0, 10, 'Instalação conferida — acentuação: ação, é, ü');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  DBMS_OUTPUT.PUT_LINE('PDF de ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
END;
/
```

## 6. Usar a partir de outro schema

O mais comum é instalar num schema de biblioteca (aqui, `LIB_PDF`) e usar das
aplicações (aqui, `APP`). Basta o `EXECUTE` no `PL_FPDF` — o `PL_FPDF_UTIL` é
chamado por dentro e não precisa de grant para quem usa:

```sql
-- conectado como LIB_PDF
GRANT EXECUTE ON PL_FPDF TO APP;

-- conectado como APP (ou um sinônimo público, criado por quem tem o privilégio)
CREATE SYNONYM PL_FPDF FOR LIB_PDF.PL_FPDF;
```

Os packages rodam com os **privilégios do dono** (não há `AUTHID CURRENT_USER`).
Três consequências práticas, todas conferidas num Oracle 26ai com dois schemas:

| Recurso | O que fazer |
|---|---|
| `SetHeaderProc` / `SetFooterProc` | a procedure de cabeçalho é chamada **pelo dono do PL_FPDF**. A aplicação dá `GRANT EXECUTE ON APP.CABECALHO TO LIB_PDF`, e passa o nome **qualificado**: `PL_FPDF.SetHeaderProc('APP.CABECALHO')`. Sem o grant, ou com o nome simples, sai `ORA-20100 ... PLS-00201` |
| `OutputFile`, `LoadTTFFromFile` | o `READ`/`WRITE` no `DIRECTORY` é dado a `LIB_PDF`, não a `APP` |
| `Image` por URL | a ACL de rede é para `LIB_PDF` |

## 7. Atualizar

Rode o instalador da versão nova por cima, no mesmo schema. Ele usa
`CREATE OR REPLACE`: grants e sinônimos continuam valendo. O roteiro abaixo é o
que um chamado de mudança costuma pedir.

**1. A versão instalada hoje**

```sql
BEGIN DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version); END;
/
```

**2. A versão do Oracle e o charset** — confira-os contra a
[Compatibilidade](COMPATIBILITY.md) da versão nova:

```sql
SELECT version_full FROM product_component_version WHERE product LIKE 'Oracle%';
SELECT value FROM nls_database_parameters WHERE parameter = 'NLS_CHARACTERSET';
```

**3. Quem depende do PL_FPDF** — o que vai recompilar, e o que testar depois.
Conectado como o dono; com privilégio de DBA, troque `all_` por `dba_` para
ver todos os schemas:

```sql
SELECT owner, name, type
  FROM all_dependencies
 WHERE referenced_owner = USER
   AND referenced_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
 ORDER BY owner, name;
```

Leia também o [guia de migração](MIGRATION.md) para o salto que você vai dar —
da 3.3 para a 3.4, por exemplo, caractere fora do WinAnsi passa a ser recusado
em vez de sair trocado.

**4. Rodar o instalador e conferir a compilação.** Guarde a saída da execução
(no SQL\*Plus, `SPOOL`; no PL/SQL Developer, a aba de saída) e confira as
consultas da [§5](#5-conferir). Os objetos que dependem do PL_FPDF podem ficar
`INVALID` por um momento: recompilam sozinhos na próxima chamada, e uma
consulta a `all_objects` com `status = 'INVALID'` mostra se algum não voltou.

**5. Teste funcional.** O teste de fumaça da [§5](#5-conferir) e, sobretudo, um
documento real da sua aplicação — o que ela mais emite.

**6. Reversão preparada antes.** Baixe e confira o instalador da versão **atual**
antes de trocar (ver [§8](#8-voltar-uma-versão)): se o passo 4 ou o 5 falhar,
voltar é rodar esse arquivo.

**Sessões abertas.** Reinstalar descarta o estado do package nas sessões que já
o usavam. Na próxima chamada, essas sessões recebem `ORA-04068: existing state
of packages has been discarded` — às vezes acompanhado de `ORA-04061`,
`ORA-04065` ou `ORA-06508`. Em geral a chamada seguinte já funciona, mas o
documento que estava sendo montado naquela sessão **se perdeu**: a aplicação
deve tratar o erro refazendo a operação desde o `Init`, e não continuando de
onde parou. Em pool de conexões (APEX, ORDS, servidor de aplicação), cada
conexão do pool passa por isso. Atualize numa janela de manutenção, ou
reinicie o pool depois.

Vindo de uma versão **anterior à 3.3**, o `PL_FPDF_UTIL` ainda não existe: o
instalador o cria.

## 8. Voltar uma versão

Rode o instalador da versão anterior — cada release tem o seu, em URL fixa.
Voltando para **antes da 3.3**, apague depois o `PL_FPDF_UTIL`, que aquelas
versões não usam: `DROP PACKAGE PL_FPDF_UTIL;`.

## 9. Desinstalar

```sql
DROP PACKAGE PL_FPDF;
DROP PACKAGE PL_FPDF_UTIL;
```

Remova também o que você criou para os recursos opcionais: sinônimos,
`DIRECTORY`, ACL de rede. O PL_FPDF não cria nenhum deles.

## 10. Extensão de pagamentos brasileiros

A extensão PIX/Boleto é instalada à parte, depois do PL_FPDF, e não faz parte
do instalador: veja [`extensions/brazilian-payments`](../extensions/brazilian-payments/README_PT_BR.md).
