# -*- coding: utf-8 -*-
"""
Acha byte virando caractere: `CHR(x)` onde `x` é um byte.

Por que existe
--------------
`CHR(n)` **não devolve um byte**. Devolve o caractere daquele ponto de código,
codificado no charset do banco. Em AL32UTF8 — o caso normal — todo valor de 128
a 255 sai com **dois** bytes.

Quem monta uma string binária byte a byte com `CHR` acaba com um resultado mais
longo e diferente do pretendido. Foi o que aconteceu no `sec_cifrar_strings`: a
cifra produz metade dos bytes acima de 127, e uma string literal de 33 bytes ia
para o arquivo com 53. O PDF continuava válido e abria normalmente; só o
título, o produtor ou o texto de uma anotação saíam embaralhados. Nenhuma
amostra conferia uma string literal, então o defeito ficou.

O jeito certo é `UTL_RAW.CAST_TO_VARCHAR2`, que não converte charset — a mesma
função que o `pdf_read` usa para ler o arquivo byte a byte.

O parente já conhecido desta armadilha estava nos testes: `CHR(200)` como
"caractere fora do ASCII" depende do charset e não vale como vetor de teste.
Aqui é a mesma confusão, do lado do código.

Regra 1 — byte virando caractere com CHR
----------------------------------------
Acusa `CHR(v)` quando `v` é uma variável que, no mesmo subprograma, recebe
valor de `TO_NUMBER(RAWTOHEX(...))` — ou seja, quando `v` comprovadamente
carrega um byte lido de um RAW.

Deliberadamente estreita: `CHR(10)`, `CHR(13)` e companhia são legítimos e não
são acusados, e `CHR` de um valor que não veio de um byte também não. O que se
quer pegar é a viagem de ida e volta byte → número → caractere.

Regra 2 — dado binário remontado byte a byte num VARCHAR2
---------------------------------------------------------
O mesmo problema pelo outro lado, e mais difícil de ver. `SUBSTRB(x, k, 1)`
extrai **um byte**; num banco AL32UTF8 esse byte pode ser o pedaço do meio de
um caractere multibyte, e o que volta não é ele. Concatenar esses pedaços num
VARCHAR2 e devolvê-lo a `UTL_RAW.CAST_TO_RAW` não recupera o binário: os bytes
ASCII atravessam e os altos voltam alterados.

Foi o segundo defeito da mesma rodada, no `sec_cifrar_strings`. O sintoma
demorou a ser lido porque o RC4 é cifra de **fluxo**: corromper o byte i da
cifra corrompe só o byte i do texto, então o título voltava com a maioria das
letras certas e algumas trocadas — não virava lixo inteiro, que é o que se
espera de uma chave errada.

Acusa `UTL_RAW.CAST_TO_RAW(v)` quando, no mesmo subprograma, `v` é montado por
`v := v || w` e `w` recebe `SUBSTRB(..., 1)`.

Uso:  python scripts/plsql_lint/check_byte_chars.py src/PL_FPDF.pkb
"""
import io
import re
import sys

CABECALHO = re.compile(r'^[ \t]{0,2}(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9$#]*)',
                       re.I | re.M)
# 'l_b := TO_NUMBER(RAWTOHEX(' — a variável passa a carregar um byte
DE_BYTE = re.compile(r'\b([a-z_][a-z_0-9$#]*)\s*:=\s*TO_NUMBER\s*\(\s*RAWTOHEX',
                     re.I)
CHR_VAR = re.compile(r'\bCHR\s*\(\s*([a-z_][a-z_0-9$#]*)\s*\)', re.I)

# 'l_c := SUBSTRB(qualquer, qualquer, 1)' — a variável passa a carregar UM byte
DE_SUBSTRB1 = re.compile(
    r'\b([a-z_][a-z_0-9$#]*)\s*:=\s*SUBSTRB\s*\([^;]*?,\s*1\s*\)', re.I)
# 'l_texto := l_texto || l_c' — acumula esse byte num VARCHAR2
ACUMULA = re.compile(
    r'\b([a-z_][a-z_0-9$#]*)\s*:=\s*\1\s*\|\|\s*([a-z_][a-z_0-9$#]*)', re.I)
CAST_RAW = re.compile(
    r'\bUTL_RAW\.CAST_TO_RAW\s*\(\s*([a-z_][a-z_0-9$#]*)\s*\)', re.I)


def sem_comentario(texto):
    texto = re.sub(r'/\*.*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group(0)),
                   texto, flags=re.S)
    return re.sub(r'--[^\n]*', lambda m: ' ' * len(m.group(0)), texto)


def main(caminho):
    texto = sem_comentario(io.open(caminho, encoding='utf-8').read())
    marcas = [m.start() for m in CABECALHO.finditer(texto)] or [0]
    marcas.append(len(texto))

    problemas = []
    total = 0
    for i in range(len(marcas) - 1):
        trecho = texto[marcas[i]:marcas[i + 1]]
        # regra 2: quem acumula um byte extraído com SUBSTRB(..., 1)
        de_substrb = {m.group(1).lower() for m in DE_SUBSTRB1.finditer(trecho)}
        remontados = {m.group(1).lower() for m in ACUMULA.finditer(trecho)
                      if m.group(2).lower() in de_substrb}
        for m in CAST_RAW.finditer(trecho):
            if m.group(1).lower() in remontados:
                linha = texto.count('\n', 0, marcas[i] + m.start()) + 1
                problemas.append((linha, m.group(1), 'raw'))

        # regra 1: byte virando caractere com CHR
        bytes_ = {m.group(1).lower() for m in DE_BYTE.finditer(trecho)}
        if not bytes_:
            continue
        total += len(bytes_)
        for m in CHR_VAR.finditer(trecho):
            if m.group(1).lower() in bytes_:
                linha = texto.count('\n', 0, marcas[i] + m.start()) + 1
                problemas.append((linha, m.group(1), 'chr'))

    if problemas:
        print(f'{caminho}: {len(problemas)} confusão(ões) entre byte e '
              f'caractere:')
        for linha, var, tipo in sorted(problemas):
            if tipo == 'chr':
                print(f'  linha {linha}: CHR({var}) — {var} carrega um byte '
                      f'(TO_NUMBER(RAWTOHEX(...))). Em AL32UTF8 os valores de '
                      f'128 a 255 saem com DOIS bytes. Use '
                      f'UTL_RAW.CAST_TO_VARCHAR2(HEXTORAW(...)).')
            else:
                print(f'  linha {linha}: UTL_RAW.CAST_TO_RAW({var}) — {var} foi '
                      f'remontado byte a byte com SUBSTRB(..., 1). Em AL32UTF8 '
                      f'um byte do meio de um caractere multibyte nao volta '
                      f'como ele. Trabalhe em RAW.')
        return 1

    print(f'{caminho}: OK — nenhuma confusão entre byte e caractere '
          f'({total} variável(is) de byte examinada(s))')
    return 0


if __name__ == '__main__':
    # aceita varios arquivos: desde a separacao do utilitario, o codigo que
    # mexe em byte esta nos dois bodies
    caminhos = sys.argv[1:] or ['src/PL_FPDF.pkb']
    sys.exit(max(main(c) for c in caminhos))
