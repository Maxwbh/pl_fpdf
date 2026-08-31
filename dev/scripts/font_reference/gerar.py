# -*- coding: utf-8 -*-
"""
Gera, em PL/SQL, as 11 tabelas de largura — a partir das fontes primárias.

DOCUMENTO DE MANUTENÇÃO.

Substitui no `src/PL_FPDF.pkb` o bloco das `getFontXxx`, que vinha do porte de
2017 com as larguras escritas posição a posição. O `validate.py` já provou que
o que sai do `font_reference.py` bate com aquelas tabelas nas 2816 posições, de
modo que a troca não muda o comportamento — muda de onde o dado vem.

A forma também muda, e para melhor. Antes eram ~230 linhas de
`mySet(chr(n)) := w;`. Agora cada família é uma linha de dígitos, lida por um
decodificador só. A chave continua sendo `chr(i)`: o original usava literal
(`mySet(' ')`) até 126 e `chr(n)` acima, e as duas formas dão o mesmo
caractere, então o índice não muda.

Uso:  python dev/scripts/font_reference/gerar.py [--check]
"""
import io
import os
import re
import sys

import font_reference

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
PKB = os.path.join(RAIZ, 'src', 'PL_FPDF.pkb')

ABERTURA = '-- <larguras-das-fontes: gerado, nao edite>'
FECHO = '-- </larguras-das-fontes>'


# As 14 chaves que o package usa (familia + estilo) e a familia cuja metrica
# vale para cada uma. Este mapa e A CORRECAO desta etapa: antes ele existia
# duas vezes, escrito a mao, em dois CASE gemeos — e os dois divergiram.
# O p_getFontMetrics tinha 'timesI' DUAS vezes (a segunda devia ser 'timesB',
# e o ramo do Times negrito era inalcancavel) e nao tinha os estilos do
# Courier, que o p_includeFont tinha. Consertaram num e esqueceram o outro.
# Agora o mapa e um so, gerado, e divergir deixou de ser possivel.
CHAVES = [
    # Courier e monoespacada: os quatro estilos medem igual
    ('courier', 'Courier'), ('courierB', 'Courier'),
    ('courierI', 'Courier'), ('courierBI', 'Courier'),
    ('helvetica', 'Helvetica'), ('helveticaB', 'Helveticab'),
    ('helveticaI', 'Helveticai'), ('helveticaBI', 'Helveticabi'),
    ('times', 'Times'), ('timesB', 'Timesb'),
    ('timesI', 'Timesi'), ('timesBI', 'Timesbi'),
    ('symbol', 'Symbol'), ('zapfdingbats', 'Zapfdingbats'),
]


def bloco():
    tabelas = font_reference.todas()
    assert max(max(t.values()) for t in tabelas.values()) < 10000

    partes = [f"""{ABERTURA}
----------------------------------------------------------------------------------------
-- Larguras das 14 fontes padrao do PDF, em milesimos de em.
--
-- GERADO por dev/scripts/font_reference/gerar.py a partir das fontes
-- primarias: os AFM da Adobe, as tabelas do reportlab (que se conferem entre
-- si, glifo a glifo) e a WinAnsiEncoding. NAO EDITE A MAO: rode o gerador.
--
-- Cada familia e uma sequencia de 256 campos de 4 digitos, um por posicao da
-- codificacao. A chave da tabela indexada e chr(i).
----------------------------------------------------------------------------------------
function p_larguras_de(p_tabela in varchar2) return charSet is
  mySet charSet;
begin
  for i in 0..255 loop
    mySet(chr(i)) := to_number(substr(p_tabela, i * 4 + 1, 4));
  end loop;
  return mySet;
end p_larguras_de;

function p_digitos_da_familia(p_familia in varchar2) return varchar2 is
begin
  case p_familia
"""]

    for familia, tab in tabelas.items():
        digitos = ''.join(f'{tab[c]:04d}' for c in range(256))
        pedacos = [digitos[i:i + 76] for i in range(0, len(digitos), 76)]
        corpo = ("'" + pedacos[0] + "'" + ''.join(
            f" ||\n      '{p}'" for p in pedacos[1:]))
        partes.append(f"    when '{familia}' then return\n      {corpo};\n")

    partes.append("""  else return null;
  end case;
end p_digitos_da_familia;

----------------------------------------------------------------------------------------
-- A metrica de uma chave 'familia+estilo'. Devolve tabela VAZIA para chave
-- desconhecida — quem chama decide o que fazer com isso, e precisa checar
-- ANTES de percorrer: sobre tabela vazia, .first e .last sao nulos.
----------------------------------------------------------------------------------------
function p_larguras_da_fonte(p_chave in varchar2) return charSet is
  l_digitos varchar2(1100);
  l_vazia   charSet;
begin
  l_digitos := p_digitos_da_familia(
    case lower(p_chave)
""")
    for chave, familia in CHAVES:
        partes.append(f"      when '{chave.lower()}' then '{familia}'\n")
    partes.append("""    end);
  if l_digitos is null then
    return l_vazia;
  end if;
  return p_larguras_de(l_digitos);
end p_larguras_da_fonte;
""" + FECHO + '\n')
    return ''.join(partes)


def main():
    texto = io.open(PKB, encoding='utf-8').read()
    novo_bloco = bloco()

    if ABERTURA in texto:
        ini = texto.index(ABERTURA)
        fim = texto.index(FECHO) + len(FECHO) + 1
        atual = texto[ini:fim]
    else:
        # primeira vez: substitui o bloco herdado, da primeira getFont ate a
        # ultima. As ancoras sao os proprios subprogramas, nao numeros de linha.
        m = re.search(r'^function\s+p_larguras_de\b', texto, re.M | re.I)
        f = texto.index('end getFontZapfdingbats;')
        ini, fim = m.start(), f + len('end getFontZapfdingbats;') + 1
        atual = None

    if '--check' in sys.argv:
        if atual == novo_bloco:
            print('as tabelas de largura no .pkb estao em dia')
            return 0
        print('as tabelas de largura estao DESATUALIZADAS em relacao as fontes '
              'primarias. Rode: python dev/scripts/font_reference/gerar.py')
        return 1

    io.open(PKB, 'w', encoding='utf-8').write(
        texto[:ini] + novo_bloco + texto[fim:])
    antes = len(texto.splitlines())
    depois = antes - len((atual or texto[ini:fim]).splitlines()) \
        + len(novo_bloco.splitlines())
    print(f'11 tabelas geradas. PL_FPDF.pkb: {antes} -> {depois} linhas')
    return 0


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(main())
