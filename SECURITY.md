# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in PL_FPDF, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Send an email to: **maxwbh@gmail.com**
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Response Time**: Within 48 hours
- **Updates**: Regular updates on the status
- **Credit**: Recognition in release notes (unless you prefer anonymity)

### Security Best Practices for PL_FPDF Users

1. **Keep Updated**: Always use the latest version
2. **Validate Input**: Sanitize user input before passing to PL_FPDF
3. **File Permissions**: Secure Oracle directory objects used for file output
4. **Database Privileges**: Grant only necessary privileges to PL_FPDF users

## Security Features in v2.0.0

- Input validation on all public procedures
- Custom exception handling with meaningful error codes
- Secure file I/O with validation
- No dynamic SQL execution from user input

---

**Thank you for helping keep PL_FPDF secure!**
