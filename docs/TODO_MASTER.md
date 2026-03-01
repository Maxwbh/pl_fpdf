# PL_FPDF - Master TODO List

**Last Updated:** 2026-03-01
**Status:** Consolidated from all project TODOs

---

## Quick Stats

| Version | Status | Tasks | Priority |
|---------|--------|-------|----------|
| v3.1.0 | Planned | 7 | HIGH |
| v3.2.0 | In Progress | 18 | CRITICAL |
| v3.3.0 | Proposed | 25 | MEDIUM |
| v3.4.0 | Planned | 32 | MEDIUM |
| v3.5.0 | Planned | 30 | LOW |
| v4.0.0 | Planned | 121 | FUTURE |
| **TOTAL** | | **233** | |

---

## Implementation Order (Recommended)

### Phase 1: Complete Current (v3.2.0) - Q2 2026

**Priority: CRITICAL - Security Release**

```
Week 1-2: AES Encryption
Week 3-4: Decryption & Testing
```

| # | Task | Status | Est. |
|---|------|--------|------|
| 1 | AES 128-bit CBC mode implementation | Pending | 3d |
| 2 | AES 256-bit CBC mode (PDF 1.7) | Pending | 2d |
| 3 | Initialization vectors (IV) handling | Pending | 1d |
| 4 | PKCS#7 padding | Pending | 1d |
| 5 | PDF version auto-upgrade for AES | Pending | 1d |
| 6 | Password validation for decrypt | Pending | 2d |
| 7 | Object decryption | Pending | 3d |
| 8 | Remove encryption dictionary | Pending | 1d |
| 9 | Test suite for all encryption | Pending | 2d |

**Blockers:** None
**Dependencies:** DBMS_CRYPTO

---

### Phase 2: Page Operations (v3.1.0) - Q2 2026

**Priority: HIGH - User Requested Features**

| # | Task | Status | Est. |
|---|------|--------|------|
| 1 | InsertPagesFrom(src_pdf, pages, position) | Planned | 2d |
| 2 | PrependPages(pages) | Planned | 1d |
| 3 | AppendPages(pages) | Planned | 1d |
| 4 | DeletePages(page_list) | Planned | 2d |
| 5 | ReorderPages(order_array) | Planned | 2d |
| 6 | RotatePages(pages, angle) | Planned | 1d |
| 7 | ExtractPages(pages) RETURN BLOB | Planned | 2d |

**Dependencies:** v3.2.0 encryption must work with page ops

---

### Phase 3: HTML to PDF (v3.3.0) - Q4 2026

**Priority: MEDIUM - New Feature**

```
Sprint 1: HTML Parser
Sprint 2: Basic Tags
Sprint 3: Tables
Sprint 4: Styles
Sprint 5: Advanced Elements
```

| Sprint | Tasks | Est. |
|--------|-------|------|
| 1 | HTML Tokenizer, DOM tree, Entity handling | 2w |
| 2 | h1-h6, p, br, hr, div, span | 1w |
| 3 | table, tr, td, th, colspan/rowspan | 2w |
| 4 | CSS inline parser, colors, fonts, align | 2w |
| 5 | Lists, links, images, bold/italic | 1w |

---

### Phase 4: PDF 1.5/1.6 (v3.4.0) - Q1 2027

**Priority: MEDIUM - Standards Compliance**

| Category | Tasks | Est. |
|----------|-------|------|
| Structure | Object Streams, XRef Streams, Incremental | 3w |
| Graphics | Transparency, Blend Modes, Soft Masks | 2w |
| Fonts | OpenType CFF, ToUnicode CMap | 2w |
| Tagged PDF | Structure Tree, Standard Tags, Content Marking | 2w |
| Interactivity | OCG Layers, Embedded Files, Annotations | 2w |

---

### Phase 5: PDF 1.7 Complete (v3.5.0) - Q2 2027

**Priority: MEDIUM - Standards Compliance**

| Category | Tasks | Est. |
|----------|-------|------|
| Security | AES-256, SHA-256 Key Derivation, Unicode Passwords | 2w |
| Forms | AcroForms, Field Types, Validation | 3w |
| Bookmarks | Document Outline, Nested Bookmarks | 1w |
| Hyperlinks | URL Links, Internal Links, Named Destinations | 1w |
| Annotations | Markup, Stamps, File Attachments | 2w |
| Actions | GoTo, URI, JavaScript placeholders | 2w |

---

### Phase 6: PDF 2.0 Migration (v4.0.0) - 2028

**Priority: FUTURE - Major Version**

See [TODO_V4.md](TODO_V4.md) for detailed breakdown.

| Category | Sprints | Tasks |
|----------|---------|-------|
| Core PDF 2.0 | 1-3 | 23 |
| Digital Signatures | 4-7 | 29 |
| PDF/A Compliance | 8-10 | 21 |
| PDF/UA Accessibility | 11-12 | 14 |
| E-Invoice (ZUGFeRD) | 13-14 | 12 |
| Migration Tools | 15-16 | 13 |
| Optimization | 17-18 | 9 |
| **Total** | 18 | 121 |

---

## Task Priority Matrix

```
                    IMPACT
                 Low    High
            ┌─────────┬─────────┐
        Low │ v3.5.0  │ v3.3.0  │
   EFFORT   │ PDF 1.7 │ HTML→PDF│
            ├─────────┼─────────┤
       High │ v3.4.0  │ v4.0.0  │
            │ PDF 1.5 │ PDF 2.0 │
            └─────────┴─────────┘
```

### Quick Wins (Do First)
1. Complete AES encryption (v3.2.0) - 80% done
2. Page operations (v3.1.0) - Building on existing merge/split
3. Decryption support - Enables PDF editing workflows

### Strategic Investment (Plan Carefully)
1. HTML to PDF - High user value, complex implementation
2. PDF 2.0 migration - Future-proofing, long timeline

### Technical Debt (Schedule)
1. Object streams for smaller PDFs
2. XRef streams for modern format
3. Tagged PDF for accessibility

---

## Dependencies Graph

```
v3.2.0 Security ──────┬───> v3.1.0 Page Ops
       (AES)          │           │
                      │           v
                      └───> v3.3.0 HTML→PDF
                                  │
                                  v
                            v3.4.0 PDF 1.5
                                  │
                                  v
                            v3.5.0 PDF 1.7
                                  │
                                  v
                            v4.0.0 PDF 2.0
```

---

## Architecture Checklist

Before implementing any feature, verify:

- [ ] **Package-Only:** No external tables, types, or sequences
- [ ] **Oracle 19c Compatible:** Works without 23ai features
- [ ] **Self-Contained:** No external dependencies
- [ ] **Session-Isolated:** Each session has own state
- [ ] **Performance:** No regression from current version
- [ ] **Tests:** Unit tests for new functionality
- [ ] **Documentation:** API docs updated

See [PACKAGE_ONLY_ARCHITECTURE.md](architecture/PACKAGE_ONLY_ARCHITECTURE.md)

---

## Modernization Checklist

For architecture improvements:

- [ ] JSON config for new features
- [ ] PL_FPDF_CRYPTO package usage
- [ ] Result Cache for fonts
- [ ] Conditional Compilation for PDF versions
- [ ] Object Types for encoders

See [ARCHITECTURE_MODERN.md](ARCHITECTURE_MODERN.md)

---

## Release Checklist

Before each release:

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] Version bumped in package
- [ ] README examples tested
- [ ] Oracle 19c compatibility verified
- [ ] Performance benchmarked

---

## Progress Tracking

### v3.2.0 Progress

```
Security Features: [████████░░] 80%
├─ RC4 40-bit:     [██████████] 100%
├─ RC4 128-bit:    [██████████] 100%
├─ AES 128-bit:    [░░░░░░░░░░] 0%
├─ AES 256-bit:    [░░░░░░░░░░] 0%
├─ Permissions:    [██████████] 100%
└─ Decryption:     [████░░░░░░] 40%
```

### Overall Project Progress

```
v2.0.0 Foundation: [██████████] 100% ✅
v3.0.0 Manipulation:[██████████] 100% ✅
v3.1.0 Page Ops:   [░░░░░░░░░░] 0%
v3.2.0 Security:   [████████░░] 80%
v3.3.0 HTML→PDF:   [░░░░░░░░░░] 0%
v3.4.0 PDF 1.5:    [░░░░░░░░░░] 0%
v3.5.0 PDF 1.7:    [░░░░░░░░░░] 0%
v4.0.0 PDF 2.0:    [░░░░░░░░░░] 0%
```

---

## Notes

### Why This Order?

1. **v3.2.0 First:** Security is critical for production use
2. **v3.1.0 Second:** Page operations build on existing code
3. **v3.3.0 Third:** HTML to PDF has high user demand
4. **v3.4.0/v3.5.0:** Standards compliance, incremental
5. **v4.0.0 Last:** Major version, requires planning

### Risk Factors

| Risk | Mitigation |
|------|------------|
| AES complexity | Use DBMS_CRYPTO |
| HTML parsing edge cases | Tolerant parser |
| PDF 2.0 breaking changes | Backward compat mode |
| Performance degradation | Benchmark each release |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-03-01 | Consolidated all TODOs into master list |
| 2026-02-28 | Added v4.0.0 PDF 2.0 TODO |
| 2026-02-28 | Initial ROADMAP created |
