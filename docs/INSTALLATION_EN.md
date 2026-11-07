# Installation and upgrade — PL_FPDF

[**Português**](INSTALLATION.md) · [Documentation index](README.md)

This guide covers installing, checking, granting access to other schemas,
upgrading, rolling back and uninstalling. For what comes next, see the
[usage guide](DOCUMENTATION_EN.md); for errors, [Troubleshooting](TROUBLESHOOTING_EN.md).

---

## 1. What gets installed

Two packages, and nothing else: `PL_FPDF` (the PDF) and `PL_FPDF_UTIL` (QR
codes, barcodes, compression and encryption, used by `PL_FPDF`). No table,
sequence, type, job or directory. A document's state lives in package
variables, inside the session.

## 2. Requirements

| | |
|---|---|
| Oracle | 19c or later — the status of each version is in [Compatibility](COMPATIBILITY_EN.md) |
| Privilege to install | `CREATE PROCEDURE` in the target schema |
| Dependencies | none: no `DBMS_CRYPTO`, no Java, no network ACL |

Optional, only if you use the feature:

| Feature | Needs |
|---|---|
| `OutputFile`, `LoadTTFFromFile` | a `DIRECTORY` with `READ`/`WRITE` **for the PL_FPDF owner** (see §6) |
| `Image` from a URL | a network ACL **for the PL_FPDF owner**. `ImageFromBlob` does not need one |

## 3. Which file to download

| For | File |
|-----|------|
| **Production** on Oracle 19c — the stable version, 3.3.0 | [v3.3.0 release `pl_fpdf_install.sql`](https://github.com/Maxwbh/pl_fpdf/releases/download/v3.3.0/pl_fpdf_install.sql) |
| **Oracle 26ai** | **no stable version works**: 3.3.0 raises `ORA-29275`. The only one that runs is the [v3.4.0-rc2](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2) candidate — see the [26ai policy](../SECURITY.md#oracle-26ai) |
| **Trying 3.4.0** — candidate | [v3.4.0-rc2 `pl_fpdf_install.sql`](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2) |
| **Exactly what this documentation describes** | the [`dist/pl_fpdf_install.sql`](../dist/pl_fpdf_install.sql) of the branch you are reading — the link follows the branch |
| **Following development** | [`dist/pl_fpdf_install.sql` on `master`](https://raw.githubusercontent.com/Maxwbh/pl_fpdf/master/dist/pl_fpdf_install.sql) |

For a change ticket, always use a **release** file: the URL is fixed, and the
`SHA256.txt` published next to it tells whether what you downloaded is what was
published. `master` changes on every merge.

### Checking the download

`SHA256.txt` uses `sha256sum`'s own format (since 3.4.0):

```bash
sha256sum -c SHA256.txt          # Linux / macOS (on macOS: shasum -a 256 -c)
```

```powershell
Get-FileHash pl_fpdf_install.sql -Algorithm SHA256   # Windows: compare with SHA256.txt
```

In the v3.3.0 release, `SHA256.txt` holds only the hash, without the file name:
compare by eye, or use
`sha256sum -c <(echo "$(cat SHA256.txt)  pl_fpdf_install.sql")`.

## 4. Installing

The installer is **plain SQL** — no SQL\*Plus commands — and runs the same in
any tool:

| Tool | How |
|---|---|
| PL/SQL Developer | open the file in a **SQL Window** and execute (F8) |
| SQL\*Plus / SQLcl | `@pl_fpdf_install.sql` |
| SQL Developer | open the file and run it as a script (F5) |

Connect as the **schema that will own** the packages. The order is already
right: `PL_FPDF_UTIL` first, because `PL_FPDF` depends on it.

**From a clone**, the order is the same — the utility first:

```sql
@src/PL_FPDF_UTIL.pks
@src/PL_FPDF_UTIL.pkb
@src/PL_FPDF.pks
@src/PL_FPDF.pkb
```

## 5. Checking

```sql
-- The version: shows in the Output tab (in SQL*Plus, turn on SET SERVEROUTPUT ON
-- first). Not in a SELECT: a package constant is only readable from PL/SQL, and
-- SELECT PL_FPDF.co_version FROM DUAL raises ORA-06553 PLS-221.
BEGIN
  DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version);
END;
/

-- The four objects must be VALID
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
 ORDER BY 1, 2;

-- And there must be no compilation error
SELECT name, type, line, position, text
  FROM user_errors
 WHERE name IN ('PL_FPDF', 'PL_FPDF_UTIL');
```

A smoke test, which builds a one-page PDF in memory:

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Helvetica', '', 12);
  PL_FPDF.Cell(0, 10, 'Installation checked — accents: ação, é, ü');
  l_pdf := PL_FPDF.OutputBlob;
  PL_FPDF.Reset;
  DBMS_OUTPUT.PUT_LINE('PDF of ' || DBMS_LOB.GETLENGTH(l_pdf) || ' bytes');
END;
/
```

## 6. Using it from another schema

The usual setup is to install into a library schema (here, `LIB_PDF`) and use
it from the applications (here, `APP`). `EXECUTE` on `PL_FPDF` is enough —
`PL_FPDF_UTIL` is called from inside and needs no grant for callers:

```sql
-- connected as LIB_PDF
GRANT EXECUTE ON PL_FPDF TO APP;

-- connected as APP (or a public synonym, created by whoever holds the privilege)
CREATE SYNONYM PL_FPDF FOR LIB_PDF.PL_FPDF;
```

The packages run with the **owner's privileges** (there is no
`AUTHID CURRENT_USER`). Three practical consequences, all checked on an Oracle
26ai with two schemas:

| Feature | What to do |
|---|---|
| `SetHeaderProc` / `SetFooterProc` | the header procedure is called **by the PL_FPDF owner**. The application runs `GRANT EXECUTE ON APP.MY_HEADER TO LIB_PDF` and passes the **qualified** name: `PL_FPDF.SetHeaderProc('APP.MY_HEADER')`. Without the grant, or with the bare name, you get `ORA-20100 ... PLS-00201` |
| `OutputFile`, `LoadTTFFromFile` | `READ`/`WRITE` on the `DIRECTORY` is granted to `LIB_PDF`, not to `APP` |
| `Image` from a URL | the network ACL is for `LIB_PDF` |

## 7. Upgrading

Run the new version's installer over the old one, in the same schema. It uses
`CREATE OR REPLACE`: grants and synonyms keep working. The steps below are what
a change ticket usually asks for.

**1. The version installed today**

```sql
BEGIN DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version); END;
/
```

**2. The Oracle version and character set** — check them against the new
version's [Compatibility](COMPATIBILITY_EN.md):

```sql
SELECT version_full FROM product_component_version WHERE product LIKE 'Oracle%';
SELECT value FROM nls_database_parameters WHERE parameter = 'NLS_CHARACTERSET';
```

**3. What depends on PL_FPDF** — what will recompile, and what to test
afterwards. Connected as the owner; with DBA privileges, swap `all_` for `dba_`
to see every schema:

```sql
SELECT owner, name, type
  FROM all_dependencies
 WHERE referenced_owner = USER
   AND referenced_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
 ORDER BY owner, name;
```

Also read the [migration guide](MIGRATION_EN.md) for the jump you are making —
from 3.3 to 3.4, for instance, a character outside WinAnsi is now refused
instead of coming out wrong.

**4. Run the installer and check the compilation.** Keep the run's output (in
SQL\*Plus, `SPOOL`; in PL/SQL Developer, the output tab) and run the queries
in [§5](#5-checking). Objects that depend on PL_FPDF may be `INVALID` for a
moment: they recompile by themselves on their next call, and a query on
`all_objects` with `status = 'INVALID'` shows whether any did not come back.

**5. Functional test.** The smoke test from [§5](#5-checking) and, above all, a
real document from your application — the one it issues the most.

**6. Rollback prepared beforehand.** Download and check the installer of the
**current** version before swapping (see [§8](#8-rolling-back)): if step 4 or
5 fails, going back means running that file.

**Open sessions.** Reinstalling discards the package state in sessions that
were using it. On their next call, those sessions get `ORA-04068: existing
state of packages has been discarded` — sometimes alongside `ORA-04061`,
`ORA-04065` or `ORA-06508`. The following call usually works, but the document
being built in that session **is lost**: the application should handle the
error by redoing the operation from `Init`, not by carrying on where it
stopped. In a connection pool (APEX, ORDS, an application server), every
pooled connection goes through this. Upgrade in a maintenance window, or
restart the pool afterwards.

Coming from a version **before 3.3**, `PL_FPDF_UTIL` does not exist yet: the
installer creates it.

## 8. Rolling back

Run the previous version's installer — every release has its own, at a fixed
URL. Going back to **before 3.3**, drop `PL_FPDF_UTIL` afterwards, since those
versions do not use it: `DROP PACKAGE PL_FPDF_UTIL;`.

## 9. Uninstalling

```sql
DROP PACKAGE PL_FPDF;
DROP PACKAGE PL_FPDF_UTIL;
```

Also remove what you created for the optional features: synonyms,
`DIRECTORY`, network ACL. PL_FPDF creates none of them.

## 10. Brazilian payments extension

The PIX/Boleto extension is installed separately, after PL_FPDF, and is not
part of the installer: see [`extensions/brazilian-payments`](../extensions/brazilian-payments/README.md).
