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
| **Production** — the stable version, 3.3.0 | [v3.3.0 release `pl_fpdf_install.sql`](https://github.com/Maxwbh/pl_fpdf/releases/download/v3.3.0/pl_fpdf_install.sql) |
| **Trying 3.4.0** — candidate | [v3.4.0-rc2 `pl_fpdf_install.sql`](https://github.com/Maxwbh/pl_fpdf/releases/tag/v3.4.0-rc2) |
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
`CREATE OR REPLACE`: grants and synonyms keep working, and code that calls
`PL_FPDF` recompiles by itself on its next run.

Two things to plan for:

- **Open sessions.** Every session that had already used `PL_FPDF` gets, on its
  first call after the swap, `ORA-04068: existing state of packages has been
  discarded` — once; the next call works. In a connection pool (APEX, ORDS, an
  application server), this happens once per pooled connection. Upgrade in a
  maintenance window, or restart the pool afterwards.
- **What changed between versions.** Read the [migration guide](MIGRATION_EN.md)
  first — from 3.3 to 3.4, for instance, a character outside WinAnsi is now
  refused instead of coming out wrong.

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
