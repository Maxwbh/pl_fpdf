# TODO v4.0.0 - PDF 2.0 Migration

**Target Release:** Q4 2028
**Total Tasks:** 121
**Status:** 📋 Planning

---

## Quick Stats

| Sprint | Tasks | Status |
|--------|-------|--------|
| 1. Core PDF 2.0 | 8 | ⬜ Pending |
| 2. Encryption V6 | 8 | ⬜ Pending |
| 3. Version Detection | 7 | ⬜ Pending |
| 4. Signatures Basic | 9 | ⬜ Pending |
| 5. Signatures PAdES | 7 | ⬜ Pending |
| 6. Signatures Advanced | 7 | ⬜ Pending |
| 7. LTV Signatures | 6 | ⬜ Pending |
| 8. PDF/A-1 & 2 | 9 | ⬜ Pending |
| 9. PDF/A-3 & Validator | 7 | ⬜ Pending |
| 10. PDF/A-4 | 5 | ⬜ Pending |
| 11. PDF/UA-1 | 9 | ⬜ Pending |
| 12. PDF/UA-2 | 5 | ⬜ Pending |
| 13. ZUGFeRD | 8 | ⬜ Pending |
| 14. E-Invoice Extended | 4 | ⬜ Pending |
| 15. Migration Basic | 7 | ⬜ Pending |
| 16. Migration Batch | 6 | ⬜ Pending |
| 17. Optimization | 4 | ⬜ Pending |
| 18. Performance | 5 | ⬜ Pending |

---

## Sprint 1: Core PDF 2.0 Foundation

**Duration:** 2 weeks
**Priority:** CRITICAL

- [ ] T001 - Implementar header %PDF-2.0
- [ ] T002 - Remover suporte a RC4 encryption
- [ ] T003 - Remover suporte a LZW compression
- [ ] T004 - Atualizar xref para formato 2.0
- [ ] T005 - Criar flag g_pdf_version global
- [ ] T006 - Implementar SetPDFVersion('2.0')
- [ ] T007 - Testes unitarios para header 2.0
- [ ] T008 - Documentar breaking changes

**Deliverables:**
- PL_FPDF gera %PDF-2.0 header
- Deprecated features removidas
- Tests passing

---

## Sprint 2: Encryption V6/R6

**Duration:** 2 weeks
**Priority:** CRITICAL

- [ ] T009 - Implementar /V 6 /R 6 encryption dict
- [ ] T010 - AES-256 nativo sem Extension Level
- [ ] T011 - SHA-256/384/512 key derivation
- [ ] T012 - Backward compatibility: detectar versao automaticamente
- [ ] T013 - Parametro p_encryption_version em SetProtection
- [ ] T014 - Migrar senha Unicode (SASLprep)
- [ ] T015 - Testes de compatibilidade com Adobe Reader
- [ ] T016 - Testes de compatibilidade com Foxit

**Deliverables:**
- AES-256 V6/R6 funcionando
- Compativel com Adobe/Foxit
- Upgrade automatico de senhas

---

## Sprint 3: Version Detection & Validation

**Duration:** 2 weeks
**Priority:** HIGH

- [ ] T017 - Parser para detectar versao de PDF existente
- [ ] T018 - Funcao GetPDFVersion(p_pdf BLOB) RETURN VARCHAR2
- [ ] T019 - Funcao GetMinimumRequiredVersion() RETURN VARCHAR2
- [ ] T020 - Validador de compliance por versao
- [ ] T021 - Report de features deprecadas usadas
- [ ] T022 - Warning system para features 1.4-only
- [ ] T023 - Migration advisor automatico

**Deliverables:**
- Detectar versao de qualquer PDF
- Validar se PDF esta em compliance
- Advisor para migracao

---

## Sprint 4: Digital Signatures - Basic

**Duration:** 3 weeks
**Priority:** CRITICAL

- [ ] T024 - Estrutura /Sig dictionary
- [ ] T025 - Criar signature field widget
- [ ] T026 - Calcular ByteRange corretamente
- [ ] T027 - Integrar com DBMS_CRYPTO para hash
- [ ] T028 - PKCS#7 signature container
- [ ] T029 - Inserir certificado X.509
- [ ] T030 - API SignDocument() basica
- [ ] T031 - Suporte a certificados A1 (arquivo)
- [ ] T032 - Testes com certificados de teste

**Deliverables:**
- SignDocument() funcional
- Certificados A1 suportados
- Validacao basica

---

## Sprint 5: Digital Signatures - PAdES

**Duration:** 2 weeks
**Priority:** HIGH

- [ ] T033 - PAdES-B (Basic) compliance
- [ ] T034 - PAdES-T (Timestamp) compliance
- [ ] T035 - Integracao com TSA (Timestamp Authority)
- [ ] T036 - HTTP client para TSA (UTL_HTTP)
- [ ] T037 - Parsing de TSA response
- [ ] T038 - Embedded timestamp no signature
- [ ] T039 - Testes com TSA publico (freetsa.org)

**Deliverables:**
- PAdES-B compliance
- PAdES-T com timestamp
- Testado com TSA real

---

## Sprint 6: Digital Signatures - Advanced

**Duration:** 2 weeks
**Priority:** MEDIUM

- [ ] T040 - Multiple signatures support
- [ ] T041 - Incremental updates para assinaturas
- [ ] T042 - Certificate chain embedding
- [ ] T043 - ValidateSignature() function
- [ ] T044 - Signature appearance (visual)
- [ ] T045 - Custom signature image
- [ ] T046 - Signature metadata (reason, location)

**Deliverables:**
- Multiplas assinaturas
- Validacao de assinaturas
- Aparencia visual customizada

---

## Sprint 7: LTV Signatures

**Duration:** 2 weeks
**Priority:** MEDIUM

- [ ] T047 - PAdES-LT compliance
- [ ] T048 - PAdES-LTA compliance
- [ ] T049 - CRL embedding
- [ ] T050 - OCSP response embedding
- [ ] T051 - Document Security Store (DSS)
- [ ] T052 - Validacao offline

**Deliverables:**
- Long-term validation
- CRL/OCSP embedded
- Validacao offline possivel

---

## Sprint 8: PDF/A-1 e PDF/A-2

**Duration:** 3 weeks
**Priority:** HIGH

- [ ] T053 - PDF/A-1b output mode
- [ ] T054 - PDF/A-2b output mode
- [ ] T055 - XMP metadata obrigatorio
- [ ] T056 - ICC color profile embedding
- [ ] T057 - Font embedding 100%
- [ ] T058 - Output intent dictionary
- [ ] T059 - Remove JavaScript
- [ ] T060 - Remove forms XFA
- [ ] T061 - PDF/A identifier metadata

**Deliverables:**
- SetPDFACompliance('PDF/A-1b')
- SetPDFACompliance('PDF/A-2b')
- Full compliance

---

## Sprint 9: PDF/A-3 e Validator

**Duration:** 2 weeks
**Priority:** HIGH

- [ ] T062 - PDF/A-3b output mode
- [ ] T063 - Associated files para PDF/A-3
- [ ] T064 - ZUGFeRD/Factur-X attachment
- [ ] T065 - ValidatePDFA() function
- [ ] T066 - Compliance report detalhado
- [ ] T067 - Lista de erros com localizacao
- [ ] T068 - Sugestoes de correcao

**Deliverables:**
- PDF/A-3b com attachments
- ZUGFeRD ready
- Validador completo

---

## Sprint 10: PDF/A-4

**Duration:** 2 weeks
**Priority:** MEDIUM

- [ ] T069 - PDF/A-4 output mode (PDF 2.0 based)
- [ ] T070 - Page-level output intents
- [ ] T071 - PDF/A-4e (engineering)
- [ ] T072 - PDF/A-4f (embedded files)
- [ ] T073 - Auto-fix para non-compliance

**Deliverables:**
- PDF/A-4 (PDF 2.0 based)
- Auto-fix capabilities

---

## Sprint 11: PDF/UA-1

**Duration:** 3 weeks
**Priority:** HIGH

- [ ] T074 - SetAccessible(TRUE) mode
- [ ] T075 - Automatic structure tags
- [ ] T076 - Document language /Lang
- [ ] T077 - Alt text para Image()
- [ ] T078 - Table header marking
- [ ] T079 - Reading order definition
- [ ] T080 - Bookmarks automaticos
- [ ] T081 - Link text descritivo
- [ ] T082 - PDF/UA identifier

**Deliverables:**
- Accessibility mode
- Screen reader compatible
- PDF/UA-1 compliance

---

## Sprint 12: PDF/UA-2

**Duration:** 2 weeks
**Priority:** MEDIUM

- [ ] T083 - PDF/UA-2 compliance (PDF 2.0)
- [ ] T084 - MathML structure
- [ ] T085 - Pronunciation hints
- [ ] T086 - Namespaced structure elements
- [ ] T087 - AccessibilityChecker()

**Deliverables:**
- PDF/UA-2 (PDF 2.0 based)
- MathML support
- Checker function

---

## Sprint 13: E-Invoice ZUGFeRD

**Duration:** 3 weeks
**Priority:** HIGH

- [ ] T088 - ZUGFeRD 2.1 MINIMUM profile
- [ ] T089 - ZUGFeRD 2.1 BASIC profile
- [ ] T090 - ZUGFeRD 2.1 COMFORT profile
- [ ] T091 - ZUGFeRD 2.1 EXTENDED profile
- [ ] T092 - Factur-X 1.0 compliance
- [ ] T093 - XML schema validation
- [ ] T094 - Invoice data model PL/SQL
- [ ] T095 - PDF visual + XML embedded

**Deliverables:**
- ZUGFeRD 2.1 all profiles
- Factur-X 1.0
- Ready for EU e-invoicing

---

## Sprint 14: E-Invoice Extended

**Duration:** 2 weeks
**Priority:** LOW

- [ ] T096 - XRechnung support
- [ ] T097 - UBL 2.1 XML generation
- [ ] T098 - Cross-Industry Invoice (CII)
- [ ] T099 - Country-specific variants

**Deliverables:**
- XRechnung (Germany)
- UBL 2.1 format

---

## Sprint 15: Migration Tools - Basic

**Duration:** 2 weeks
**Priority:** CRITICAL

- [ ] T100 - UpgradeVersion() function
- [ ] T101 - Parser para PDF existente
- [ ] T102 - Object extraction
- [ ] T103 - Stream decompression
- [ ] T104 - Re-encryption to AES-256
- [ ] T105 - Font re-embedding
- [ ] T106 - Remove deprecated objects

**Deliverables:**
- Upgrade PDF 1.4 -> 2.0
- Re-encrypt with AES-256
- Clean deprecated features

---

## Sprint 16: Migration Tools - Batch

**Duration:** 2 weeks
**Priority:** HIGH

- [ ] T107 - BatchUpgrade() procedure
- [ ] T108 - DBMS_PARALLEL_EXECUTE integration
- [ ] T109 - Progress tracking
- [ ] T110 - Error handling e retry
- [ ] T111 - Migration report JSON
- [ ] T112 - Rollback support

**Deliverables:**
- Batch migration millions of PDFs
- Parallel processing
- Full reporting

---

## Sprint 17: Optimization

**Duration:** 2 weeks
**Priority:** MEDIUM

- [ ] T113 - Incremental updates
- [ ] T114 - Linearization (Fast Web View)
- [ ] T115 - Hint tables
- [ ] T116 - Object reordering

**Deliverables:**
- Fast Web View
- Optimized for streaming

---

## Sprint 18: Performance

**Duration:** 2 weeks
**Priority:** HIGH

- [ ] T117 - Memory pooling
- [ ] T118 - Streaming output
- [ ] T119 - Lazy font loading
- [ ] T120 - Parallel image processing
- [ ] T121 - Benchmark suite

**Deliverables:**
- 20% faster than v3.x
- Lower memory usage
- Benchmarks documented

---

## Progress Tracking

### Completed: 0/121 (0%)

```
[                                                  ] 0%
```

### By Priority

| Priority | Total | Done | % |
|----------|-------|------|---|
| CRITICAL | 32 | 0 | 0% |
| HIGH | 51 | 0 | 0% |
| MEDIUM | 26 | 0 | 0% |
| LOW | 12 | 0 | 0% |

---

## Notes

- Sprint 1-3: Foundation must be completed before other sprints
- Sprint 4-7: Signatures can run parallel with PDF/A
- Sprint 8-12: PDF/A and PDF/UA can run in sequence
- Sprint 13-14: E-Invoice depends on PDF/A-3
- Sprint 15-16: Migration can start after Sprint 1-2
- Sprint 17-18: Optimization is last phase

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-28 | Initial TODO created |
