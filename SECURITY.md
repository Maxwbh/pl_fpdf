# Security Policy

## Supported Versions

| Version | Status | Security fixes |
| ------- | ------ | -------------- |
| 3.4.0-rc (pre-release) | Under test — not for production | Accepted; fixed before the final 3.4.0 |
| 3.3.x   | Latest stable release | :white_check_mark: |
| < 3.3   | Historical | :x: — upgrade to 3.3.x |

Only the latest stable line gets fixes. A pre-release (`-rc`) is published to be
tested: report what you find in it, but do not run it in production.

## Reporting a Vulnerability

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Send an email to: **maxwbh@gmail.com**
3. Include:
   - PL_FPDF version (`BEGIN DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version); END;`)
     and Oracle version
   - Description of the vulnerability and its potential impact
   - Steps to reproduce — for a parsing issue, the PDF that triggers it
   - Suggested fix (if any)

### What to Expect

- **Response Time**: Within 48 hours
- **Updates**: Regular updates on the status
- **Credit**: Recognition in release notes (unless you prefer anonymity)

## Scope

What counts as a vulnerability here, and what the library does and does not
promise:

### Encryption and passwords

- `EncryptPDF` / `SetEncryption` **protect** a file: who opens it, who prints,
  who copies. They do not sign it and do not detect tampering. There is no
  digital signature in PL_FPDF.
- **Prefer AES-256.** RC4 (40 and 128 bits) is broken and was removed by
  PDF 2.0; it is kept only for compatibility, and `'RC4-128'` is still the
  parameter default for the same reason. Pass `p_encryption => 'AES-256'`.
- Permissions (print, copy, modify…) are flags that **viewers are expected to
  honour**. Anyone with the owner password — or a non-compliant tool — can
  ignore them. This is how the PDF standard works, not a defect.
- In scope: wrong key derivation, a file that opens without the user password,
  a permission flag written differently from what was requested, password
  material leaking into the output or into log messages.

### Reading untrusted PDFs

`LoadPDF`, `DecryptPDF`, `IsEncrypted`, `GetSecurityInfo` and `FlateDecode`
parse input you may not control.

- Every FlateDecode stream is inflated with a **ceiling of 8 MB per stream**
  by default (`FlateDecode` takes `p_max_bytes`); a stream that expands past it
  raises `ORA-20893` instead of filling the session — the defence against
  compression bombs.
- The document as a whole is processed in session memory (PGA and temporary
  LOBs). Limit the size of what you accept **before** calling `LoadPDF`.
- In scope: a crafted PDF that makes the parser loop forever, exhaust memory
  past those ceilings, read outside the BLOB, or execute anything.

### Resource use in the database

PL_FPDF runs inside your session. A very large document — many pages, large
images, embedded fonts — uses PGA and temporary tablespace accordingly. Size
limits on user-supplied input are the caller's responsibility.

### Dynamic SQL

The library runs dynamic SQL in one place: `SetHeaderProc` / `SetFooterProc`
register a procedure **you** name, and the page header and footer call it with
`EXECUTE IMMEDIATE`. The procedure name is checked with `DBMS_ASSERT` and
parameter values are quoted. **Never pass end-user input as the procedure
name.** In scope: any way to inject SQL through those calls.

### File I/O

`OutputFile` writes and `LoadTTFFromFile` reads through Oracle `DIRECTORY`
objects. Grant `READ`/`WRITE` on a directory only to the schemas that need it.
`Image` with a URL fetches it over the network and needs a network ACL;
`ImageFromBlob` (3.4.0+) does not — prefer it when the image is already in the database.

## Best Practices for PL_FPDF Users

1. **Keep updated**: use the latest stable release
2. **Prefer AES-256** for encryption
3. **Bound your inputs**: size limits on PDFs and images that come from users
4. **Least privilege**: PL_FPDF needs only `CREATE PROCEDURE` in its schema —
   no `DBMS_CRYPTO`; a network ACL only if you load images by URL
5. **Directories**: secure the Oracle directory objects used for file output

---

**Thank you for helping keep PL_FPDF secure!**
