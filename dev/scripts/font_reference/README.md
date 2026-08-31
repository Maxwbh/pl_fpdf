# Referência das larguras das fontes padrão

**Documento de manutenção.**

As tabelas de largura das 14 fontes padrão do PDF viviam no `PL_FPDF.pkb` como
11 funções herdadas do porte de 2017, com as larguras escritas posição a
posição. São **dado**, não invenção — e dado tem fonte primária.

## As duas fontes, e por que duas

| | de onde |
|---|---|
| largura de cada glifo | AFM da Adobe (as URW distribuídas com o matplotlib) |
| a mesma largura, de novo | tabelas do `reportlab` |
| byte → glifo | `WinAnsiEncoding`, `SymbolEncoding`, `ZapfDingbatsEncoding` |

`conferir_fontes()` compara as duas primeiras **glifo a glifo** e recusa gerar
qualquer coisa se discordarem. Hoje concordam em **2443 glifos**.

Uma fonte só não bastaria, e o Euro prova: os AFM da URW são anteriores à
adição do glifo e não o trazem. O reportlab traz — 556 na Helvetica.

## Rodar

```bash
python dev/scripts/font_reference/font_reference.py   # o que as fontes dizem
python dev/scripts/font_reference/validate.py         # confere contra o .pkb
python dev/scripts/font_reference/gerar.py            # gera o bloco no .pkb
python dev/scripts/font_reference/gerar.py --check    # só confere (é o do CI)
```

## O que a reconstrução ensinou

**O 350 não era convenção.** Eu tinha lido as posições 127, 129 e 141 da
Helvetica como "valor arbitrário para posição sem glifo". Não é: na WinAnsi
elas mapeiam para **bullet**, e 350 é a largura do bullet. Era métrica o tempo
todo.

**O `AGL2UV` do fontTools é parcial.** A primeira tentativa reconstruía a
WinAnsi com CP1252 mais a Adobe Glyph List, e errava `²`, `³`, `¹` e o espaço
inquebrável, porque aqueles nomes não estão naquele mapa. A `WinAnsiEncoding`
publicada pelo reportlab resolveu — e reconstruir o que já existe publicado era
trabalho a mais para ficar pior.

**Três convenções diferentes para posição vazia.** As latinas usam a largura do
espaço; o Symbol usa a largura do espaço até 31 e zero acima de 127; o
ZapfDingbats usa zero em tudo. Não há razão para a diferença — é o porte que
tratou as fontes de modos distintos. Está **preservada de propósito**:
uniformizar mudaria a medida de texto já gerado, e esta etapa troca a
procedência do dado, não o comportamento.

As 2816 posições das 11 tabelas conferem.
