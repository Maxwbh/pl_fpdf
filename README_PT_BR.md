# PL_FPDF

<p align="center">
  <img src="https://img.shields.io/badge/versao-3.0.0--beta-blue.svg" alt="Versao">
  <img src="https://img.shields.io/badge/oracle-19c%2B-red.svg" alt="Oracle">
  <img src="https://img.shields.io/badge/licenca-MIT-green.svg" alt="Licenca">
  <img src="https://img.shields.io/badge/testes-150%2B-brightgreen.svg" alt="Testes">
</p>

<p align="center">
  <b>Biblioteca PL/SQL Pura para Geracao e Manipulacao de PDF</b>
</p>

<p align="center">
  <a href="#instalacao">Instalacao</a> •
  <a href="#inicio-rapido">Inicio Rapido</a> •
  <a href="#recursos">Recursos</a> •
  <a href="#documentacao">Docs</a> •
  <a href="README.md">English</a>
</p>

---

## Por que PL_FPDF?

Gere e manipule PDFs **diretamente no Oracle Database** - sem Java, sem servicos externos, sem middleware.

| Necessidade | Solucao |
|-------------|---------|
| Criar relatorios do Oracle | PL/SQL puro - roda dentro do banco |
| Modificar PDFs existentes | Carregar, editar, mesclar, dividir - tudo em PL/SQL |
| Zero dependencias | Sem OWA, sem OrdImage, sem libs externas |
| Deploy simples | Apenas 2 arquivos: `.pks` + `.pkb` |

---

## Instalacao

```sql
-- Instalar
@PL_FPDF.pks
@PL_FPDF.pkb

-- Verificar
SELECT PL_FPDF.GetVersion() FROM DUAL;
```

**Requisitos:** Oracle 19c+ | Sem dependencias externas

---

## Inicio Rapido

### Criar PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Ola Mundo!', '0', 1, 'C');
  l_pdf := PL_FPDF.Output_Blob();
END;
```

### Modificar PDF Existente

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

### Geracao de PDF
- Documentos multi-pagina (paginas ilimitadas)
- Texto, formas, imagens (PNG, JPEG)
- Fontes TrueType com UTF-8
- Codigos de barras (Code128, QR Code)
- Tabelas com auto-paginacao

### Manipulacao de PDF
- Carregar e parsear PDFs existentes
- Rotacionar paginas (0, 90, 180, 270)
- Remover paginas
- Adicionar marcas d'agua
- Overlay de texto e imagem
- Mesclar multiplos PDFs
- Dividir PDF por intervalo de paginas

### Arquitetura
- PL/SQL puro (sem dependencias externas)
- Apenas packages (sem tabelas, types ou sequences)
- Compativel com Oracle 19c (garantido)
- Suporte a compilacao nativa (2-3x mais rapido)

---

## Documentacao

| Documento | Descricao |
|-----------|-----------|
| [Referencia API](docs/api/API_REFERENCE.md) | Documentacao completa da API |
| [Guia Fase 4](docs/guides/PHASE_4_GUIDE.md) | Guia de manipulacao de PDF |
| [Performance](docs/guides/PERFORMANCE_TUNING.md) | Dicas de otimizacao |
| [Migracao](docs/guides/MIGRATION_GUIDE.md) | Upgrade de versoes anteriores |
| [Roadmap](docs/ROADMAP.md) | Features futuras |

---

## Estrutura do Projeto

```
pl_fpdf/
├── PL_FPDF.pks          # Especificacao do package
├── PL_FPDF.pkb          # Corpo do package
├── docs/                # Documentacao
├── tests/               # Suite de testes
├── scripts/             # Scripts utilitarios
└── extensions/          # Extensoes opcionais (PIX, Boleto)
```

---

## Contribuindo

1. Fork o repositorio
2. Crie branch de feature (`git checkout -b feature/incrivel`)
3. Siga os [padroes de codigo](CONTRIBUTING.md)
4. Adicione testes
5. Envie Pull Request

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes.

---

## Creditos

- **FPDF (PHP):** Olivier PLATHEY
- **Port PL/SQL:** Anton Scheffer, Pierre-Gilles Levallois
- **Modernizacao:** Maxwell Oliveira ([@maxwbh](https://github.com/maxwbh))

---

## Licenca

MIT License - veja [LICENSE](LICENSE)

---

<p align="center">
  <a href="https://github.com/Maxwbh/pl_fpdf/stargazers">Star no GitHub</a> •
  <a href="https://github.com/Maxwbh/pl_fpdf/issues">Reportar Issue</a> •
  <a href="mailto:maxwbh@gmail.com">Contato</a>
</p>
