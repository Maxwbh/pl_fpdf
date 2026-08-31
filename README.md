# PL_FPDF

<p align="center">
  <img src="https://img.shields.io/badge/versão-3.3.0-blue.svg" alt="Versão">
  <img src="https://img.shields.io/badge/oracle-19c%2B-red.svg" alt="Oracle">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licença-MIT-green.svg" alt="Licença"></a>
  <img src="https://img.shields.io/badge/segurança-AES--256-brightgreen.svg" alt="Segurança">
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

Uma biblioteca de PDF que roda **dentro do Oracle Database**: dois packages
PL/SQL, sem Java, sem serviço externo, sem objeto de banco além deles. Gera e
também **manipula** — carrega, mescla, divide, marca d'água e **protege com
senha e criptografia AES-256**.

A superfície pública está inteira em
[`docs/API_REFERENCE.md`](docs/API_REFERENCE.md), e é
mantida por [@Maxwbh](https://github.com/Maxwbh) desde 2019: manipulação de PDF
(v3.0), leitura de PDF 1.5+ com xref em stream e object streams,
AES-256/AES-128/RC4, QR Code e códigos de barras, DEFLATE e INFLATE escritos em
PL/SQL, UTF-8/TrueType e Oracle 19c/23c.

> **Linhagem.** A base de geração descende do porte PL/SQL de
> [Pierre-Gilles Levallois](https://github.com/Pilooz), que trouxe para o Oracle
> a [FPDF](http://www.fpdf.org/) de Olivier Plathey. Daí vem a API que talvez
> você já conheça — `Cell`, `AddPage`, `SetFont`, `MultiCell`. Sobre ela, este
> projeto acrescentou APIs novas sem remover nenhuma das originais. Os
> créditos completos estão no fim desta página.

---

## Por que PL_FPDF?

Gere e manipule PDFs **diretamente dentro do Oracle Database** — sem Java, sem serviços externos, sem middleware, sem sair do banco.

| Necessidade | Como o PL_FPDF resolve |
|-------------|-------------------------|
| Relatórios gerados pelo Oracle (boletos, notas, contratos) | PL/SQL puro — roda dentro do próprio banco, sem servidor de aplicação |
| Modificar PDFs existentes | Carregar, rotacionar, marcar d'água, mesclar, dividir — tudo em PL/SQL |
| Proteger documentos sensíveis | Criptografia AES-256, AES-128 ou RC4, com senha de usuário/proprietário e permissões |
| Zero dependências externas | Sem OWA, sem OrdImage, sem Java Stored Procedures, sem libs de terceiros |
| Deploy simples | Dois packages, sem objetos de banco: `PL_FPDF_UTIL` e `PL_FPDF` |
| Mercado brasileiro | Extensão opcional pronta para **PIX** (QR Code EMV) e **Boleto Bancário** (FEBRABAN) |

**Quando faz sentido usar:** ERPs e sistemas legados 100% PL/SQL, ambientes Oracle EBS/Forms sem camada Java, geração de relatório fiscal/contábil direto de trigger ou job, ou qualquer cenário onde instalar uma lib externa (iText, wkhtmltopdf, etc.) não é viável.

---

## Instalação

**Um arquivo, sem clonar nada.** Baixe
[`dist/pl_fpdf_install.sql`](dist/pl_fpdf_install.sql) — o link segue a branch
que você está vendo; a versão estável publicada é a da
[`master`](https://raw.githubusercontent.com/Maxwbh/pl_fpdf/master/dist/pl_fpdf_install.sql).
Abra na SQL Window do PL/SQL Developer (F8) — ou rode com
`@pl_fpdf_install.sql` no SQL\*Plus / SQLcl — e pronto. Ele traz os dois
packages já na ordem certa, e é só SQL: nenhum comando de ferramenta, nada de
tabela, sequência ou diretório para criar antes.

```sql
-- Se preferir instalar a partir do clone, o utilitário vem PRIMEIRO:
-- o PL_FPDF chama o PL_FPDF_UTIL, e a ordem inversa deixa o primeiro inválido.
@src/PL_FPDF_UTIL.pks
@src/PL_FPDF_UTIL.pkb
@src/PL_FPDF.pks
@src/PL_FPDF.pkb

-- Verificar instalação
SELECT PL_FPDF.co_version FROM DUAL;
-- Retorna: 3.2.0
```

**Requisitos:** Oracle 19c+, e `CREATE PROCEDURE` no schema onde os packages
vão morar. Nada além disso — em particular, **não** é preciso
`GRANT EXECUTE ON SYS.DBMS_CRYPTO`.

**Sem dependências externas, nem para criptografia.** `EncryptPDF`/`DecryptPDF` usam MD5 e SHA via `STANDARD_HASH` (função SQL nativa); o RC4 e o AES são implementados no próprio package.

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

  l_pdf := PL_FPDF.OutputBlob();          -- o PDF, em memória

  -- E agora é seu: grave, envie, devolva.
  INSERT INTO documentos (nome, pdf) VALUES ('ola.pdf', l_pdf);
  -- ou PL_FPDF.OutputFile('ola.pdf', 'PDF_DIR');   direto num DIRECTORY
  -- ou entregue ao navegador — veja "Entregar o PDF a um navegador"
  --    em docs/DOCUMENTATION.md
END;
```

**Arial mapeia para Helvetica**, como no FPDF: são o mesmo desenho para a
biblioteca. Os exemplos usam os dois nomes; escolha um e siga com ele.

### Exemplo em destaque: o layout de um boleto, inteiro em PL/SQL

<p align="center">
  <img src="site/assets/exemplo-boleto.png" alt="Boleto bancário gerado pelo PL_FPDF: duas vias, grade de campos e código de barras ITF" width="640">
</p>

<p align="center"><sub>
  Saída real do <code>examples/boleto.sql</code>, gerada dentro do Oracle e conferida
  aqui: o zxing lê os 44 dígitos do código de barras no PDF renderizado.
</sub></p>

Documento fácil é folha com um título. O que mostra do que a biblioteca é capaz é
o **layout de um boleto bancário** — e ele sai inteiro do banco, sem imagem nenhuma:

| Item | Detalhe |
|---|---|
| Página | A4 retrato, com a ficha de compensação de **177 mm** centralizada |
| Fontes | três variantes de Helvetica (normal, negrito, itálico) em quatro corpos |
| Grade | **50 caixas** posicionadas ao milímetro, em duas vias, com linha de corte |
| Alinhamento | coluna de valores de 40 mm, com o dinheiro **alinhado à direita** |
| Código de barras | **ITF de 44 dígitos** — o do boleto, que um leitor de banco lê |
| Imagens | **nenhuma**: logotipo, réguas e barras são desenho vetorial |

> **O PL_FPDF desenha; ele não calcula cobrança.** Os 44 dígitos do código de
> barras e a linha digitável chegam **prontos**, como qualquer outro dado que
> você passa. Montá-los a partir de banco, vencimento, valor e campo livre —
> dígito verificador, fator de vencimento, as regras de cada banco — é assunto
> de um projeto de cobrança, não de uma biblioteca de PDF.

```sql
-- uma caixa do boleto: rótulo miúdo em cima, valor embaixo.
-- A Cell já tem margem interna de 1 mm dos dois lados, então a largura
-- passada é a da caixa inteira — o alinhado à direita encosta a 1 mm da borda.
PROCEDURE campo(px NUMBER, py NUMBER, pw NUMBER, ph NUMBER,
                protulo VARCHAR2, pvalor VARCHAR2 DEFAULT NULL,
                pneg BOOLEAN DEFAULT FALSE, palin VARCHAR2 DEFAULT 'L') IS
BEGIN
  PL_FPDF.Rect(px, py, pw, ph, 'D');
  PL_FPDF.SetFont('Arial', '', 6);
  PL_FPDF.SetXY(px, py + 0.7);
  PL_FPDF.Cell(pw, 2.4, protulo, '0', 0, 'L');
  IF pvalor IS NOT NULL THEN
    PL_FPDF.SetFont('Arial', CASE WHEN pneg THEN 'B' END, 9);
    PL_FPDF.SetXY(px, py + 3.2);
    PL_FPDF.Cell(pw, 3.4, pvalor, '0', 0, palin);
  END IF;
END campo;

-- ...e o código de barras do boleto, 103 x 13 mm como manda a FEBRABAN
PL_FPDF.AddBarcode(16.5, 233, 103, 13,
                   '34197167700000150001090000012323073123451000',
                   'ITF', FALSE);
```

📄 **[Exemplo completo e pronto para rodar: `examples/boleto.sql`](examples/boleto.sql)**
— abra na SQL Window e execute.

O mesmo vale para qualquer formulário de grade fechada: nota fiscal, guia de
recolhimento, contrato com campos, ficha cadastral. O que o exemplo mostra é
**posicionamento ao milímetro** com as ferramentas da própria biblioteca.

### E o irmão colorido: um ingresso de evento

<p align="center">
  <img src="site/assets/exemplo-ticket.png" alt="Ingresso de evento gerado pelo PL_FPDF: cabeçalho colorido, QR Code, código de barras e painéis" width="560">
</p>

<p align="center"><sub>
  Saída real do <code>examples/ticket.sql</code>, gerada dentro do Oracle e
  conferida aqui: o zxing lê o QR e o Code 39, e os dois dizem o mesmo código.
</sub></p>

O boleto prova grade. O [`examples/ticket.sql`](examples/ticket.sql) prova o
resto — e nenhum dos dois usa imagem:

| Item | Detalhe |
|---|---|
| Cor | faixa de cabeçalho preenchida, **texto branco sobre ela**, painéis cinzas com miolo branco |
| Dois símbolos | **QR Code e Code 39 na mesma página**, dizendo o mesmo código |
| Multi-página | um ingresso por página, cada um com o seu participante e o seu código |
| Forma livre | o rabinho do balão de aviso, com `Poly` — nem tudo é retângulo |

```sql
-- painel colorido, e o título em branco por cima dele
PL_FPDF.SetFillColor(13, 25, 44);
PL_FPDF.Rect(12, 13.5, 186, 36, 'F');

PL_FPDF.SetTextColor(255, 255, 255);
PL_FPDF.SetFont('Arial', 'B', 17);
PL_FPDF.SetXY(16, 18);
PL_FPDF.Cell(178, 9, 'Orquestra Sinfônica - Concerto de Gala', '0', 0, 'L');

-- o mesmo código em duas simbologias, para leitura na portaria
PL_FPDF.AddQRCode(p_x => 156, p_y => 58, p_size => 32, p_data => l_codigo);
PL_FPDF.AddBarcode(45, 117, 120, 10, l_codigo, 'CODE39', FALSE);
```

---

Manipular PDFs existentes, mesclar, dividir, criptografar, QR Code, marca d'água e
todo o restante da API estão na documentação:

- 📖 **[Referência completa de uso](docs/DOCUMENTATION.md)** — todas as APIs, parâmetros e exemplos
- 🌐 **[Índice de utilização no site](https://maxwbh.github.io/pl_fpdf/api.html)** — versão navegável

---

## Recursos

- **Geração**: multi-página, texto/formas/imagens (PNG com canal alfa e entrelaçado, JPEG), fontes TrueType com UTF-8, tabelas com auto-paginação
- **Códigos**: QR Code (TEXT, URL, PIX, VCARD, WIFI, EMAIL) e barras (CODE128, CODE39, EAN13, EAN8, ITF, ITF14 — o ITF cobre o código de barras de boleto)
- **Manipulação**: carregar PDF existente, rotacionar/remover páginas, marca d'água, overlays, merge e split — inclusive em PDF 1.5+, com xref em stream e object streams
- **Segurança**: AES-256, AES-128 e RC4 40/128 bits, senhas de usuário/proprietário, controle de permissões
- **Extensão BR** (opcional): [PIX e Boleto Bancário](extensions/brazilian-payments/README_PT_BR.md)
- **Arquitetura**: PL/SQL puro, package-only, Oracle 19c+, compilação nativa

A lista completa, com assinatura e exemplo de cada API, está na
[referência de uso](docs/DOCUMENTATION.md).

---

## Estrutura do Projeto

**Sete arquivos são tudo o que você precisa conhecer:** o instalador, os quatro
fontes e os dois exemplos. O resto é ferramenta de quem mantém o projeto.

```
pl_fpdf/
│
│  ═══════════════ para quem usa a biblioteca ═══════════════
│
├── dist/
│   └── pl_fpdf_install.sql       # ← comece por aqui: baixe e execute
│                                 #   um arquivo, os dois packages na ordem
│                                 #   certa. Gerado de src/, só SQL
│
├── src/                          # os fontes, se preferir instalar do clone
│   ├── PL_FPDF_UTIL.pks          # ← utilitário: QR, barcode, deflate, cripto
│   ├── PL_FPDF_UTIL.pkb          #   INSTALE ESTE PRIMEIRO: o PL_FPDF o chama
│   ├── PL_FPDF.pks               # especificação — a referência da API sai daqui
│   └── PL_FPDF.pkb               # corpo
│
├── examples/                     # abra na SQL Window e execute
│   ├── boleto.sql                # boleto: grade de 50 caixas, ITF de 44 dígitos
│   └── ticket.sql                # ingresso: cor, QR + Code 39, várias páginas
│
├── docs/
│   ├── DOCUMENTATION.md          # referência de uso, com exemplo por API
│   ├── DOCUMENTATION_EN.md       # o mesmo guia em inglês
│   ├── API_REFERENCE.md          # assinatura, parâmetros e erros (gerada)
│   └── API_REFERENCE_EN.md       # a mesma referência em inglês (gerada)
│
├── extensions/                   # opcional, instale só se usar
│   └── brazilian-payments/       # PIX (QR EMV) e Boleto (FEBRABAN)
│
├── README.md  README_EN.md  CHANGELOG.md  LICENSE
│
│  ═══════ daqui para baixo nada vai para o banco ═══════
│
├── dev/                          # o lado de quem mantém — veja CONTRIBUTING.md
│   ├── tests/                    # suíte, validações e diagnósticos
│   └── scripts/                  # runner, geradores e as referências em Python
│
├── site/                         # a página em maxwbh.github.io/pl_fpdf
└── CONTRIBUTING.md  SECURITY.md  CODE_OF_CONDUCT.md
```

Três arquivos são **gerados** e não se edita à mão — o CI recusa qualquer um
deles desatualizado:

| Gerado | A partir de |
|--------|-------------|
| `dist/pl_fpdf_install.sql` | os quatro fontes de `src/` |
| `dev/tests/run_all_tests.sql` | `dev/tests/test_*.sql` |

---

## Limitações

O que a biblioteca **não** faz, para você não descobrir tarde:

| | |
|---|---|
| **Assinatura digital** | não há. Senha e AES-256 **protegem** o documento; assinar com certificado (PAdES, ICP-Brasil) é outra coisa e não está no escopo |
| **JavaScript no PDF** | não gera nem preserva |
| **Formulários (AcroForm)** | não preenche nem cria |
| **Estado por sessão** | o package guarda o documento em memória de sessão. Duas gerações simultâneas na **mesma** sessão se atropelam; use `Reset` entre documentos, e lembre que `ORA-04068` derruba o estado após recompilar |
| **Documento muito grande** | tudo é montado em memória e o custo é de CPU do banco. Milhares de páginas com imagem pesam; meça antes de prometer |
| **Imagem reprocessada** | PNG que exige refazer pixels tem teto de 4 megapixels e sai **sem compressão** |
| **Regra de negócio** | boleto, PIX e afins: a biblioteca **desenha**; calcular dígito, fator de vencimento ou payload é de um projeto de cobrança |

---

## Documentação

**Para quem usa a biblioteca** — falam só de gerar e manipular PDF:

| Documento | Descrição |
|-----------|-----------|
| [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md) | Referência completa de uso: todas as APIs com exemplos |
| [docs/DOCUMENTATION_EN.md](docs/DOCUMENTATION_EN.md) | O mesmo guia em inglês |
| [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | Assinatura, parâmetros e erros de cada API |
| [docs/API_REFERENCE_EN.md](docs/API_REFERENCE_EN.md) | A mesma referência em inglês (gerada) |
| [Índice da API no site](https://maxwbh.github.io/pl_fpdf/api.html) | Versão navegável da referência |
| [CHANGELOG.md](CHANGELOG.md) | Histórico de versões |

**Para quem mantém o código** — testes, CI e método de trabalho:

| Documento | Descrição |
|-----------|-----------|
| [docs/MANUTENCAO.md](docs/MANUTENCAO.md) | Como rodar os testes, o que o CI verifica, as referências validadas |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Planejamento, pendências conhecidas e o que cada verificação pega |

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
**Maxwell da Silva Oliveira** ([@Maxwbh](https://github.com/Maxwbh)) o tempo e a
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

A este alicerce, este projeto acrescentou a modernização para Oracle 19c/23c e as
versões 2.x/3.x — mas a fundação é de vocês. **Muito obrigado.**

O porte de 2017 saiu sob GPL, e Pierre-Gilles Levallois autorizou o
relicenciamento sob MIT. É essa autorização que sustenta a licença deste
repositório.

---

## Créditos

- **FPDF (PHP):** [Olivier PLATHEY](http://www.fpdf.org/)
- **Port PL/SQL original:** [Pierre-Gilles Levallois](https://github.com/Pilooz) ([Pilooz/pl_fpdf](https://github.com/Pilooz/pl_fpdf)), Anton Scheffer
- **Modernização e v2.x/v3.x:** Maxwell da Silva Oliveira ([@Maxwbh](https://github.com/Maxwbh))
- **Mantenedora:** [M&S do Brasil LTDA](https://msbrasil.inf.br) · [contato@msbrasil.inf.br](mailto:contato@msbrasil.inf.br)

---

## Licença

**MIT.** O arquivo [LICENSE](LICENSE) é a licença desta biblioteca: use,
modifique, distribua e embarque em produto comercial, mantendo o aviso de
copyright.

A base de geração descende de um porte PL/SQL de 2017; os créditos de linhagem
estão logo abaixo.

---

<p align="center">
  ⭐ <a href="https://github.com/Maxwbh/pl_fpdf/stargazers"><b>Deixe uma estrela</b></a> se este projeto te ajudou —
  isso aumenta a visibilidade dele para outros devs Oracle •
  <a href="https://github.com/Maxwbh/pl_fpdf/issues">Reportar Issue</a> •
  <a href="mailto:maxwbh@gmail.com">Contato</a>
</p>
