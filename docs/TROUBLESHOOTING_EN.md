# Troubleshooting — PL_FPDF

[**Português**](TROUBLESHOOTING.md) · [Documentation index](README.md)

Organized by what you **see**: the error message or the symptom. For the full
list of codes, by range, see the [error codes](DOCUMENTATION_EN.md#18-error-codes);
per API, the [reference](API_REFERENCE_EN.md).

First of all, the installed version — many symptoms below depend on it:

```sql
BEGIN DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version); END;
/
```

---

## Installation and access

| You see | Cause | What to do |
|---------|-------|------------|
| `ORA-01031: insufficient privileges` while installing | `CREATE PROCEDURE` is missing in the schema | ask the DBA for the grant |
| `INVALID` objects after installing | a compilation error | `SELECT * FROM user_errors WHERE name LIKE 'PL_FPDF%'`. Databases before 19c are not supported |
| `PLS-00201: identifier 'PL_FPDF_UTIL' must be declared` | installing from the clone in the wrong order | compile `PL_FPDF_UTIL` before `PL_FPDF` — or use `dist/pl_fpdf_install.sql`, which comes in the right order |
| `ORA-06553: PLS-221: 'CO_VERSION' is not a procedure` | `SELECT PL_FPDF.co_version FROM DUAL` | a package constant cannot be read from SQL. Use the block at the top of this page |
| `ORA-04068: existing state of packages has been discarded` (sometimes with `ORA-04061`, `ORA-04065` or `ORA-06508`) | the package was reinstalled or recompiled while the session was using it | expected after an upgrade, in every session that was using it — in a pool, in every connection. The document being built in that session is lost: redo the operation from `Init`. See [Installation §7](INSTALLATION_EN.md#7-upgrading) |
| `PLS-00201: identifier 'PL_FPDF' must be declared` in another schema | missing grant or synonym | `GRANT EXECUTE ON PL_FPDF TO app` and a synonym — see [Installation §6](INSTALLATION_EN.md#6-using-it-from-another-schema) |
| `ORA-29275: partial multibyte character` on the first `SetFont` | 3.3.0 (or 3.4.0-rc1) on an Oracle **26ai** with AL32UTF8 | install 3.4.0 (v3.4.0-rc2 or later) — see [Compatibility](COMPATIBILITY_EN.md#1-oracle-versions) |

## Building the document

| You see | Cause | What to do |
|---------|-------|------------|
| `ORA-20005: PL_FPDF not initialized. Call Init() first.` | a call before `Init` — or the document was started in another request | every document starts with `Init` and ends with `OutputBlob` and `Reset` **within the same database call**. In APEX and ORDS, each request may land on a different pooled session: never spread a document over two requests |
| An accent comes out as two odd characters (`Ã§` instead of `ç`) | 3.3.0 or earlier | upgrade to 3.4.0. If your code converted the text beforehand, remove the conversion — see [Migration 3.3 → 3.4](MIGRATION_EN.md#33--34) |
| `ORA-06502` in `GetStringWidth`, or when centring/right-aligning text with accents | 3.3.0 or earlier | upgrade to 3.4.0 |
| `ORA-20203` with a position | a character outside WinAnsi (ideogram, Cyrillic, emoji) in a standard font | embed a TrueType font with `AddTTFFont` |
| `ORA-20601` | `AddLink`, `SetLink` or a link with a numeric target | only URL links exist — internal links are not supported |
| `ORA-20100: PL_FPDF: Header : ... PLS-00201` | the header/footer procedure is in another schema, and it is called **by the PL_FPDF owner** | grant `EXECUTE` on the procedure to the PL_FPDF owner and pass the qualified name (`'APP.MY_HEADER'`) — see [Installation §6](INSTALLATION_EN.md#6-using-it-from-another-schema) |
| `Image` refuses a PNG with "Not a PNG file" | 3.3.0 or earlier on an AL32UTF8 database | upgrade to 3.4.0 |
| `ORA-24247: network access denied by access control list` in `Image` | `Image` from a URL with no network ACL for the PL_FPDF owner | read the file into a BLOB and use `ImageFromBlob` (3.4.0), or ask for the ACL |
| `ORA-29280` or `ORA-20401`…`ORA-20403` in `OutputFile` / `LoadTTFFromFile` | `DIRECTORY` missing, or without `READ`/`WRITE` for the PL_FPDF owner | check the `DIRECTORY` and the grants **of the package owner** |
| `ORA-20306` | `Output` with destination `'I'`, `'D'` or `'S'`, from classic FPDF | use `OutputBlob` and deliver the BLOB — see below |
| `ORA-04030: out of process memory` | a document too big for the session's PGA | call `Reset` between documents, free temporary BLOBs and generate in batches |

## Delivering the PDF

| You see | Cause | What to do |
|---------|-------|------------|
| The browser shows the PDF **source** (`%PDF-1.4`, `obj`, `stream`) | a response without `Content-Type: application/pdf` | send the header before the BLOB — see [Delivering the PDF to a browser](DOCUMENTATION_EN.md#delivering-the-pdf-to-a-browser) |
| Opens in one browser and not in another | most likely the same problem: browsers differ in how much they guess the type when `Content-Type` is missing or wrong, and that changes from version to version | the same fix. Check the response headers (F12 → Network) before suspecting the PDF |
| The downloaded file is corrupted | something was written to the HTTP buffer **before** the header (a debug `htp.p`, an exception message), or `Content-Length` does not match | build the whole PDF before writing any header; in APEX, finish with `apex_application.stop_apex_engine` |

## Reading and manipulating PDF

| You see | Cause | What to do |
|---------|-------|------------|
| `ORA-20800`…`ORA-20810` in `LoadPDF` | the BLOB is not a PDF, or its header, xref or trailer is corrupt | check the file in a viewer; if it opens there, open an issue with the PDF |
| `ORA-20867` in `LoadPDF` or `LoadPDFWithID` | the input PDF is encrypted, and `LoadPDF` does not decrypt | run it through `DecryptPDF` first, with the password. Up to 3.4.0-rc2 it was accepted with no error and the pages came out blank |
| `ORA-20893` | a decompressed stream went over the ceiling (8 MB per stream) | it is the defence against compression bombs. With `FlateDecode` called directly, the ceiling is `p_max_bytes` |
| `ORA-20858` | AES-128 needs PDF 1.5+, AES-256 needs 1.7+ | `SetPDFVersion('1.7')` before `SetEncryption` |

## PIX/Boleto extension

| You see | Cause | What to do |
|---------|-------|------------|
| `ORA-20802: Due date too far in future (max factor 9999)` | an extension older than the due-date factor fix; since 2025-02-22 the factor restarts at 1000 | reinstall the extension packages from this repository: the fix is from November 2026 |
| `ORA-20701: Invalid PIX key ... for type PHONE` | a phone key without the country code | the PIX phone key is `+55` + area code + number |

---

Did not find your case? Open an [issue](https://github.com/Maxwbh/pl_fpdf/issues)
with the PL_FPDF version, the Oracle version, the database character set
(`SELECT value FROM nls_database_parameters WHERE parameter = 'NLS_CHARACTERSET'`)
and the full error message.
