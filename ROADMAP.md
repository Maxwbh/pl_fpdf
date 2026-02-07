# PL_FPDF Roadmap

Features planejadas para versoes futuras.

---

## v2.1.0 - Seguranca

### PDF com Senha
Protecao de documentos com senha de usuario e proprietario.

```sql
PL_FPDF.SetProtection(
  p_user_password  => 'senha123',
  p_owner_password => 'admin456',
  p_permissions    => 'print'
);
```

**Funcionalidades:**
- Senha para abrir documento
- Senha de proprietario (editar/imprimir)
- Permissoes: print, copy, edit, annotations
- Criptografia RC4 40-bit ou AES 128/256-bit

---

## v2.2.0 - Navegacao

### Hyperlinks
Links para URLs externas e navegacao interna.

```sql
PL_FPDF.AddLink('https://example.com', 10, 50, 80, 10, 'Visite nosso site');
PL_FPDF.AddInternalLink(2, 10, 70, 50, 10, 'Ir para pagina 2');
```

### Bookmarks
Indice de navegacao (outline).

```sql
PL_FPDF.AddBookmark('Capitulo 1', 0, 1);
PL_FPDF.AddBookmark('Secao 1.1', 1, 1);
```

---

## v2.3.0 - Arquivamento

### PDF/A Compliance
Documentos para arquivamento de longo prazo (ISO 19005).

```sql
PL_FPDF.Init('P', 'mm', 'A4', p_pdfa => TRUE);
```

---

## v3.0.0 - Assinatura Digital

### Certificados X.509
Assinatura digital com certificados.

```sql
PL_FPDF.AddSignature(
  p_certificate => l_cert_blob,
  p_reason      => 'Aprovacao',
  p_location    => 'Sao Paulo'
);
```

---

## Backlog

| Feature | Prioridade | Versao Alvo |
|---------|------------|-------------|
| Senha PDF | Alta | v2.1.0 |
| Hyperlinks | Media | v2.2.0 |
| Bookmarks | Media | v2.2.0 |
| PDF/A | Media | v2.3.0 |
| Assinatura Digital | Alta | v3.0.0 |
| Watermarks | Baixa | TBD |
| Annotations | Baixa | TBD |

---

## Contribuicoes

Quer ajudar? Veja [CONTRIBUTING.md](CONTRIBUTING.md)

**Contato:** maxwbh@gmail.com
