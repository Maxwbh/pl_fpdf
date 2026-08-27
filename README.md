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

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Olá, Mundo!', '0', 1, 'C');
  l_pdf := PL_FPDF.OutputBlob();
END;
```

Manipular PDFs existentes, mesclar, dividir, criptografar, QR Code, marca d'água e
todo o restante da API estão na documentação:

- 📖 **[Referência completa de uso](docs/DOCUMENTATION.md)** — todas as APIs, parâmetros e exemplos
- 🌐 **[Índice de utilização no site](https://maxwbh.github.io/pl_fpdf/api.html)** — versão navegável

---

## Recursos

- **Geração**: multi-página, texto/formas/imagens (PNG, JPEG), fontes TrueType com UTF-8, tabelas com auto-paginação
- **Códigos**: QR Code (TEXT, URL, PIX, VCARD, WIFI, EMAIL) e barras (CODE128, CODE39, EAN13, EAN8, ITF14)
- **Manipulação**: carregar PDF existente, rotacionar/remover páginas, marca d'água, overlays, merge e split
- **Segurança (v3.2)**: criptografia RC4 40/128 bits, senhas de usuário/proprietário, controle de permissões
- **Extensão BR** (opcional): [PIX e Boleto Bancário](extensions/brazilian-payments/README_PT_BR.md)
- **Arquitetura**: PL/SQL puro, package-only, Oracle 19c+, compilação nativa

A lista completa, com assinatura e exemplo de cada API, está na
[referência de uso](docs/DOCUMENTATION.md).

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
├── tests/                        # Suíte de testes (runner único: run_all_tests.sql)
├── scripts/                      # Utilitários (gerador docx_to_plfpdf)
├── docs/                         # Documentação e roadmap
├── assets/ + index.html          # Site do projeto (GitHub Pages)
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
| [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md) | Referência completa de uso: todas as APIs com exemplos |
| [Índice da API no site](https://maxwbh.github.io/pl_fpdf/api.html) | Versão navegável da referência |
| [CHANGELOG.md](CHANGELOG.md) | Histórico de versões |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Planejamento de versões, TODOs, backlog |

---

## Como Contribuir

1. Faça um fork do repositório
2. Crie uma branch de feature (`git checkout -b feature/incrivel`)
3. Siga os [padrões de código](CONTRIBUTING.md)
4. Adicione testes
5. Envie um Pull Request

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes. Dúvidas de uso? Use as [Discussions](https://github.com/Maxwbh/pl_fpdf/discussions); bugs, abra uma [Issue](https://github.com/Maxwbh/pl_fpdf/issues/new/choose).

---

## 💼 Mantenedora

O desenvolvimento contínuo do PL_FPDF conta com o apoio financeiro e institucional da
**[M&S do Brasil LTDA](https://msbrasil.inf.br)**, empresa brasileira especializada em
soluções para o ecossistema Oracle. É esse patrocínio que garante ao desenvolvedor
**Maxwell da Silva Oliveira** ([@maxwbh](https://github.com/maxwbh)) o tempo e a
estrutura para evoluir a biblioteca com constância — novas versões, correções,
documentação e suporte à comunidade — mantendo o projeto **gratuito e open source
(MIT)** para todos.

Se o PL_FPDF é útil para a sua empresa e você precisa de consultoria, evolução sob
demanda ou suporte especializado em Oracle/PL/SQL, fale com a mantenedora:

- 🌐 **Site:** [msbrasil.inf.br](https://msbrasil.inf.br)
- 📧 **Contato:** [contato@msbrasil.inf.br](mailto:contato@msbrasil.inf.br)

---

## 🙏 Agradecimentos

Este projeto só existe porque outros o tornaram possível, e é justo nomeá-los:

- **[Olivier Plathey](http://www.fpdf.org/)**, autor do **FPDF** original em PHP — a
  biblioteca que definiu, há mais de duas décadas, o jeito simples e direto de gerar
  PDF por código e inspirou portes em dezenas de linguagens.
- **[Pierre-Gilles Levallois](https://github.com/Pilooz)** ([Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf)),
  que teve a visão pioneira de trazer o FPDF para dentro do Oracle Database, criando o
  porte PL/SQL sobre o qual todo este trabalho se apoia.
- **Anton Scheffer** e os demais contribuidores do porte original, cujo código e ideias
  seguem vivos em cada release.

A este alicerce, o fork acrescenta a modernização para Oracle 19c/23c e as versões
2.x/3.x — mas a fundação é de vocês. **Muito obrigado.**

---

## Créditos

- **FPDF (PHP):** [Olivier PLATHEY](http://www.fpdf.org/)
- **Port PL/SQL original:** [Pierre-Gilles Levallois](https://github.com/Pilooz) ([Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf)), Anton Scheffer
- **Este fork — Modernização e v2.x/v3.x:** Maxwell da Silva Oliveira ([@maxwbh](https://github.com/maxwbh))
- **Mantenedora:** [M&S do Brasil LTDA](https://msbrasil.inf.br) · [contato@msbrasil.inf.br](mailto:contato@msbrasil.inf.br)

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
