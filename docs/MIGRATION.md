# Migração entre versões — PL_FPDF

[**English**](MIGRATION_EN.md) · [Índice da documentação](README.md)

O que muda para quem **já usa** o PL_FPDF, salto a salto, da versão mais nova
para a mais antiga. Para trocar os packages no banco, veja
[Instalação → Atualizar](INSTALLATION.md#7-atualizar).

Em cada salto, primeiro o que **não compila mais** ou **levanta erro** (você
descobre na primeira execução), depois o que **muda o resultado** sem erro
nenhum (você só descobre olhando o PDF).

Os números da superfície pública saem de comparar o `.pks` de cada tag, nome a
nome:

| | 0.9.4 | 2.0.0 | 3.0.0 | 3.2.0 | 3.3.0 | 3.4.0 |
|---|---|---|---|---|---|---|
| Subprogramas públicos do `PL_FPDF` | 70 | 94 | 125 | 125 | 120 | 119 |

---

## 3.3 → 3.4

### Não compila ou levanta erro

| Antes | Agora | O que fazer |
|-------|-------|-------------|
| `SetUTF8Enabled`, `IsUTF8Enabled` | removidas | apague as chamadas. Elas não faziam nada: a variável era escrita e lida, e nenhum outro ponto a consultava |
| Caractere fora do WinAnsi numa fonte padrão (ideograma, cirílico, emoji) saía como `?` ou glifo trocado | `ORA-20203`, com a posição | embuta uma fonte TrueType (`AddTTFFont`), ou trate a exceção `PL_FPDF.exc_fora_de_winansi` |
| `AddLink`, `SetLink`, `Link` com destino numérico | `ORA-20601` (`PL_FPDF.exc_link_nao_suportado`) | use só link para URL. O link interno nunca funcionou: o `/Dest` não era escrito e o arquivo saía malformado |

### Muda o resultado

- **Acentuação nas fontes padrão.** Antes, `ação` saía com dois glifos trocados
  no lugar de cada acento; agora sai certo. Se o seu código contornava isso —
  convertendo o texto antes de passar, ou tirando os acentos —, retire o
  contorno: a 3.4.0 converte sozinha, e um texto já convertido sai trocado de
  novo.
- **Larguras com acento.** `GetStringWidth`, `MultiCell`, `Write` e o
  alinhamento à direita ou centralizado mediam errado (ou levantavam
  `ORA-06502`) com acento. Um layout que foi ajustado na mão para compensar
  pode mudar de lugar.
- **Fonte TrueType.** A fonte registrada passa a ser de fato embutida e usada
  pelo `SetFont`, com as métricas do arquivo. O texto muda de desenho e de
  largura: confira os layouts que usam TrueType.
- **PNG em banco AL32UTF8.** O `Image` recusava todo PNG com "Not a PNG file";
  agora funciona.
- **Oracle 26ai.** A 3.3.0 não funciona no 26ai com AL32UTF8 — ver
  [Compatibilidade](COMPATIBILITY.md#1-versões-do-oracle). A 3.4.0 funciona.

### Novo

`ImageFromBlob` — imagem a partir de um BLOB, sem ACL de rede.

---

## 3.2 → 3.3

### Não compila ou levanta erro

| Antes | Agora | O que fazer |
|-------|-------|-------------|
| `helloworld`, `test`, `testImg`, `testHeader`, `MyRepetitiveHeader`, `MyRepetitiveFooter`, `lpc_footer` | removidas | eram as demonstrações do porte de 2017, públicas por acidente. Se algum código chamava, ele rodava o exemplo, não a biblioteca |
| Conteúdo que estourava um buffer interno era truncado em silêncio | `ORA-20841` / `ORA-20866` | o documento estava saindo incompleto; o erro só deixou isso visível |

### Muda o resultado

- **`Triangle`** passa a honrar o `porientation`, que antes era aceito e
  ignorado: o triângulo pode apontar para outro lado. É a única mudança
  incompatível de comportamento do salto.

### Instalação

A biblioteca passa a ter **dois** packages: `PL_FPDF_UTIL` (QR Code, códigos de
barras, compressão, criptografia) e `PL_FPDF`. O instalador cria os dois, na
ordem certa. Quem usa de outro schema continua precisando só do `EXECUTE` no
`PL_FPDF`.

### Novo

Instalação em um arquivo (`dist/pl_fpdf_install.sql`), leitura de PDF 1.5+ (xref
em stream e object streams), `FlateDecode`/`FlateEncode` com DEFLATE próprio, e
licença MIT.

---

## 3.0 → 3.2 e 2.0 → 3.0

Só acréscimos: nenhum subprograma público saiu, nenhuma assinatura mudou. A 3.0
trouxe a manipulação de PDF existente (`LoadPDF`, páginas, marca d'água,
overlays, merge e split) e a criptografia (`EncryptPDF`, `DecryptPDF`,
`SetEncryption`); o detalhe está no [CHANGELOG](../CHANGELOG.md).

---

## 0.9.4 → 2.0

O salto do porte original de 2017 para a modernização.

```sql
-- ANTES (v0.9.4)                    -- AGORA (v2.0+)
PL_FPDF.fpdf('P','mm','A4');         PL_FPDF.Init('P','mm','A4');
l_pdf := PL_FPDF.Output('S');        l_pdf := PL_FPDF.OutputBlob;
PL_FPDF.Output('F', caminho);        PL_FPDF.OutputFile(nome, directory);
```

| v0.9.4 | v2.0+ |
|--------|-------|
| `fpdf()` | `Init()` (o `fpdf()` segue disponível por compatibilidade) |
| `Output('S')` | `OutputBlob` |
| `Output` com destino `'I'`, `'D'` ou `'S'` (os dois primeiros mandavam os cabeçalhos HTTP) | levanta `ORA-20306`: devolva o BLOB e entregue você mesmo — ver [Entregar o PDF a um navegador](DOCUMENTATION.md#entregar-o-pdf-a-um-navegador) |
| UTF-8 limitado | UTF-8 completo + TrueType |
| Sem criptografia | AES-256, AES-128 e RC4 (3.x) |

### O que de fato quebra

**Sumiram sete nomes** da 0.9.4 até hoje, e os sete são as rotinas de
demonstração listadas no salto 3.2 → 3.3. Nenhuma é API.

**Das 133 assinaturas em comum, uma mudou**, e foi na 2.0.0: o parâmetro do `AddPage` passou de `orientation` para
`p_orientation`.

```sql
PL_FPDF.AddPage('L');                    -- posicional: continua valendo
PL_FPDF.AddPage(orientation   => 'L');   -- 0.9.4: não compila mais
PL_FPDF.AddPage(p_orientation => 'L');   -- hoje
```

A forma **posicional** — que é a dos exemplos de 2017 — atravessa sem mudança.
Só a **nomeada** exige trocar uma palavra.

> **Por que não manter os dois nomes?** Sobrecarga em PL/SQL resolve por tipo e
> posição, nunca por nome de parâmetro, e um parâmetro só pode ter um nome.
> Duas `AddPage` cujo primeiro parâmetro é `VARCHAR2` são indistinguíveis:
> `AddPage('L')` casaria com as duas e o Oracle recusa com `PLS-00307`.

### As entradas legadas continuam de pé

O construtor e o fluxo do porte de 2017 seguem valendo, e há teste que executa
a sequência do `helloworld` original chamada a chamada:

```sql
PL_FPDF.FPDF('P', 'cm', 'A4');   -- o construtor legado deixa o package pronto
PL_FPDF.openpdf;                 -- aceito; hoje o AddPage o chama sozinho
PL_FPDF.AddPage();
PL_FPDF.SetFont('Arial', 'B', 16);
PL_FPDF.Cell(0, 1.2, 'Hello World', 0, 1, 'C');
l_pdf := PL_FPDF.ReturnBlob;     -- da 0.9.4, continua
```

`SetHeaderProc` e `SetFooterProc`, o mecanismo de cabeçalho e rodapé por nome
de procedure, também continuam.
