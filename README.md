# PL_FPDF

<p align="center">
  <img src="https://img.shields.io/badge/versão-3.2.0-blue.svg" alt="Versão">
  <img src="https://img.shields.io/badge/oracle-19c%2B-red.svg" alt="Oracle">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licença-MIT-green.svg" alt="Licença"></a>
  <img src="https://img.shields.io/badge/segurança-RC4-brightgreen.svg" alt="Segurança">
  <a href="https://github.com/Maxwbh/pl_fpdf/actions/workflows/ci.yml"><img src="https://github.com/Maxwbh/pl_fpdf/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/releases"><img src="https://img.shields.io/github/v/release/Maxwbh/pl_fpdf?label=release" alt="Release"></a>
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers"><img src="https://img.shields.io/github/stars/Maxwbh/pl_fpdf?style=social" alt="Stars"></a>
</p>

<p align="center">
  <b>Biblioteca 100% PL/SQL para Geração e Manipulação de PDF direto no Oracle Database</b>
</p>

<p align="center">
  <a href="#por-que-pl_fpdf">Por que usar</a> •
  <a href="#instalação">Instalação</a> •
  <a href="#início-rápido">Início Rápido</a> •
  <a href="#recursos">Recursos</a> •
  <a href="#documentação">Docs</a> •
  <a href="README_EN.md">🇺🇸 English</a>
</p>

> **📌 Sobre este projeto:** Este é um **fork** do [Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf) —
> o porte PL/SQL original da lib [FPDF](http://www.fpdf.org/) (PHP), criado por Pierre-Gilles Levallois —
> que estava sem atualizações há anos. Desde então este fork é **mantido, modernizado e ampliado
> ativamente** por [@maxwbh](https://github.com/maxwbh): suporte a Oracle 19c/23c, UTF-8/TrueType,
> manipulação de PDF (v3.0), criptografia RC4 (v3.2), gerador DOCX→PL/SQL e extensão PIX/Boleto.

---

## Por que PL_FPDF?

Gere e manipule PDFs **diretamente dentro do Oracle Database** — sem Java, sem serviços externos, sem middleware, sem sair do banco.

| Necessidade | Como o PL_FPDF resolve |
|-------------|-------------------------|
| Relatórios gerados pelo Oracle (boletos, notas, contratos) | PL/SQL puro — roda dentro do próprio banco, sem servidor de aplicação |
| Modificar PDFs existentes | Carregar, rotacionar, marcar d'água, mesclar, dividir — tudo em PL/SQL |
| Proteger documentos sensíveis | Criptografia RC4 com senha de usuário/proprietário e permissões |
| Zero dependências externas | Sem OWA, sem OrdImage, sem Java Stored Procedures, sem libs de terceiros |
| Deploy simples | Apenas 2 arquivos: `.pks` + `.pkb` |
| Mercado brasileiro | Extensão opcional pronta para **PIX** (QR Code EMV) e **Boleto Bancário** (FEBRABAN) |

**Quando faz sentido usar:** ERPs e sistemas legados 100% PL/SQL, ambientes Oracle EBS/Forms sem camada Java, geração de relatório fiscal/contábil direto de trigger ou job, ou qualquer cenário onde instalar uma lib externa (iText, wkhtmltopdf, etc.) não é viável.

---

## Instalação

```sql
-- Opção 1: rodar o script de deploy completo
@deploy_all.sql

-- Opção 2: instalar manualmente
@src/PL_FPDF.pks
@src/PL_FPDF.pkb

-- Verificar instalação
SELECT PL_FPDF.co_version FROM DUAL;
-- Retorna: 3.2.0
```

**Requisitos:** Oracle 19c+ | Sem dependências externas

---

## Início Rápido

### Criar um PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Olá, Mundo!', '0', 1, 'C');
  l_pdf := PL_FPDF.Output_Blob();
END;
```

### Modificar um PDF existente

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  SELECT pdf_blob INTO l_pdf FROM documentos WHERE id = 1;

  PL_FPDF.LoadPDF(l_pdf);
  PL_FPDF.RotatePage(1, 90);
  PL_FPDF.AddWatermark('CONFIDENCIAL', 0.3);
  PL_FPDF.RemovePage(3);

  l_pdf := PL_FPDF.OutputModifiedPDF();
END;
```

### Criptografar um PDF

```sql
DECLARE
  l_pdf BLOB;
  l_perms JSON_OBJECT_T := JSON_OBJECT_T();
BEGIN
  l_perms.put('print', TRUE);
  l_perms.put('copy', FALSE);

  l_pdf := PL_FPDF.EncryptPDF(
    p_pdf            => l_original,
    p_user_password  => 'senha123',
    p_owner_password => 'senhaAdmin456',
    p_permissions    => l_perms,
    p_encryption     => 'RC4-128'
  );
END;
```

### Mesclar PDFs

```sql
DECLARE
  l_merged BLOB;
BEGIN
  PL_FPDF.LoadPDFWithID(l_pdf1, 'doc1');
  PL_FPDF.LoadPDFWithID(l_pdf2, 'doc2');
  l_merged := PL_FPDF.MergePDFs('doc1,doc2');
END;
```

---

## Recursos

### Geração de PDF
- Documentos multi-página (páginas ilimitadas)
- Texto, formas, imagens (PNG, JPEG)
- Fontes TrueType com suporte a UTF-8
- Códigos de barras (Code39, EAN-13, QR Code)
- Tabelas com auto-paginação

### Manipulação de PDF
- Carregar e interpretar PDFs existentes
- Rotacionar páginas (0, 90, 180, 270)
- Remover páginas
- Adicionar marcas d'água (texto/imagem)
- Overlay de texto e imagem
- Mesclar múltiplos PDFs
- Dividir PDF por intervalo de páginas

### Segurança (v3.2.0)
- Criptografia RC4 de 40 bits (legado)
- Criptografia RC4 de 128 bits (padrão)
- Proteção por senha (usuário/proprietário)
- Controle de permissões (imprimir, copiar, modificar etc.)
- Descriptografia de PDF

### Extensão de Pagamentos Brasileiros (opcional)
- QR Code PIX (padrão EMV Merchant-Presented)
- Boleto Bancário (padrão FEBRABAN)
- Veja [extensions/brazilian-payments](extensions/brazilian-payments/README_PT_BR.md)

### Arquitetura
- PL/SQL puro (sem dependências externas)
- Somente packages (sem tabelas, types ou sequences)
- Compatível com Oracle 19c (garantido)
- Suporte a compilação nativa (2-3x mais rápido)

---

## Estrutura do Projeto

```
pl_fpdf/
│
├── src/                          # Código-fonte
│   ├── PL_FPDF.pks              # Especificação do package
│   └── PL_FPDF.pkb              # Corpo do package
│
├── extensions/                   # Extensões opcionais
│   └── brazilian-payments/      # PIX QR Code & Boleto
│
├── tests/                        # Suíte de testes (25+ testes)
├── scripts/                       # Utilitários (incl. gerador docx_to_plfpdf)
├── docs/                          # Documentação
├── README.md                     # Este arquivo (português)
├── README_EN.md                  # Versão em inglês
├── CHANGELOG.md                  # Histórico de versões
├── CONTRIBUTING.md               # Como contribuir
├── SECURITY.md                   # Política de segurança
└── deploy_all.sql                # Script de deploy
```

---

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md) | Referência de API, arquitetura, migração |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Planejamento de versões, TODOs, backlog |

---

## Histórico de Versões

| Versão | Data | Destaques |
|--------|------|-----------|
| **3.2.0** | Jul 2026 | Segurança: criptografia RC4, permissões, descriptografia • Gerador DOCX→PL/SQL |
| 3.0.0 | Fev 2026 | Manipulação de PDF: carregar, modificar, mesclar, dividir |
| 2.0.0 | Dez 2025 | Base: UTF-8, TrueType, códigos de barras, QR |

Veja o [CHANGELOG.md](CHANGELOG.md) para o histórico completo.

---

## Como Contribuir

1. Faça um fork do repositório
2. Crie uma branch de feature (`git checkout -b feature/incrivel`)
3. Siga os [padrões de código](CONTRIBUTING.md)
4. Adicione testes
5. Envie um Pull Request

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes. Dúvidas de uso? Use as [Discussions](https://github.com/Maxwbh/pl_fpdf/discussions); bugs, abra uma [Issue](https://github.com/Maxwbh/pl_fpdf/issues/new/choose).

---

## Créditos

- **FPDF (PHP):** [Olivier PLATHEY](http://www.fpdf.org/)
- **Port PL/SQL original:** [Pierre-Gilles Levallois](https://github.com/Pilooz) ([Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf)), Anton Scheffer
- **Este fork — Modernização e v2.x/v3.x:** Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))

---

## Licença

MIT License - veja [LICENSE](LICENSE)

---

<p align="center">
  ⭐ <a href="https://github.com/Maxwbh/pl_fpdf/stargazers"><b>Deixe uma estrela</b></a> se este projeto te ajudou —
  isso aumenta a visibilidade dele para outros devs Oracle •
  <a href="https://github.com/Maxwbh/pl_fpdf/issues">Reportar Issue</a> •
  <a href="mailto:maxwbh@gmail.com">Contato</a>
</p>
