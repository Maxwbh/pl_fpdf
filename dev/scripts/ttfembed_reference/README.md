# Referência da fonte TrueType embutida

**Documento de manutenção.**

`AddTTFFont` guardava a fonte num cache que **nada consumia**: o `SetFont` não o
consultava e os bytes nunca iam para o PDF. Ligar as duas pontas exige ler o
arquivo de fonte de verdade, e ler formato de terceiro em PL/SQL sem referência
é como o QR Code era antes de agosto — desenha algo, e nenhum leitor aceita.

## O que se decidiu, e por quê

| decisão | motivo |
|---|---|
| fonte **simples**, `/Subtype /TrueType`, com `/WinAnsiEncoding` | desde a 3.4.0 o texto sai convertido para WinAnsi em escape octal; uma fonte simples com a mesma codificação encaixa sem tocar no caminho de texto |
| programa da fonte em **hexadecimal**, com `/ASCIIHexDecode` | o documento é montado num CLOB e convertido por `CONVERTTOBLOB`, que recodifica qualquer byte acima de `0x7F`. Byte cru não atravessa — é a mesma razão da imagem |
| **sem subset** | é a HU-02, e é outro trabalho. Enquanto isso a fonte inteira entra, e dobra em hexadecimal |

Consequência medida: LiberationSans são 410.820 bytes, que viram **821.641** de
hexadecimal dentro do arquivo. Quem precisa só de acento **não precisa de fonte
embutida** desde a 3.4.0 — as fontes padrão escrevem acentuado.

## O que se lê do arquivo

| tabela | o que sai dela |
|--------|----------------|
| `head` | `unitsPerEm`, a caixa (`xMin`..`yMax`), `indexToLocFormat` |
| `hhea` | `ascender`, `descender`, `numberOfHMetrics` |
| `hmtx` | a largura de avanço de cada glifo |
| `cmap` | ponto de código → glifo (formato 4, plataforma 3/1) |
| `OS/2` | `sCapHeight`, `fsSelection`, `usWeightClass` |
| `post` | `italicAngle`, `isFixedPitch` |

Tudo em unidades da fonte, reescalado para as 1000 por em que o PDF quer.

## O que o MuPDF confere

1. o **texto sai** inteiro, inclusive acentuado — que é o motivo de embutir;
2. a fonte está **embutida**, e com o nome certo;
3. a largura que o leitor **mede** bate com a que o `/Widths` declara.

O terceiro é o que pega o erro que interessa na porta: ler `hmtx` com o
`numberOfHMetrics` errado, ou esquecer de reescalar de `unitsPerEm` para 1000,
produz exatamente isso — e o arquivo abre perfeitamente, com o texto espaçado
como o de outra fonte.

## Rodar

```bash
python dev/scripts/ttfembed_reference/validate.py
```
