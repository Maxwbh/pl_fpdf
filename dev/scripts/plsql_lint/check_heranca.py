# -*- coding: utf-8 -*-
"""
Mede quanto do fonte original de 2017 ainda vive em `src/`, e trava o número.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O `PL_FPDF` descende de um porte PL/SQL publicado sob **GPL**, e o projeto se
declara MIT. Enquanto houver código daquele fonte aqui dentro, as duas coisas
não fecham. Reimplementar o que restava foi o caminho tentado, e ele precisava
de um número que andasse só para um lado.

Esse esforço chegou ao fim útil (vide "Este número tem PISO"), mas o número
continua valendo — agora como trava, não como meta.

Este script é esse número. Ele não julga se a reescrita ficou boa; ele responde
"quantas linhas ainda são idênticas às de lá" e **falha se subir**. Sem isso, um
copiar-e-colar bem-intencionado devolve em uma tarde o que se ganhou num mês, e
ninguém percebe: o código compila, os testes passam, a régua fecha.

Este número tem PISO, e zero não é a meta
------------------------------------------
Quatro etapas levaram 1091 -> 818. O que sobra não desce por reescrita, e é
importante saber por quê antes de alguém tentar:

  - assinatura de API pública (`procedure SetY(py in number) is`). A superfície
    da API É a do FPDF; essa é a promessa de compatibilidade do projeto.
    Mudá-la quebra todo usuário.
  - operador do PDF (`p_out('/ProcSet [/PDF /Text /ImageB /ImageC /ImageI]')`).
    Não há escolha de autor: é o token que a especificação exige.
  - o modelo documentado do FPDF (`wmax := (myPW - 2*cMargin) * 1000 / fontsize`,
    a regra da quebra automática, centralizar dividindo por dois). Dois autores
    independentes escrevem isso igual, por convergência e não por cópia.

Mexer nessas linhas só para o número descer seria PARAFRASEAR — que continua
produzindo obra derivada, com a agravante de dar a impressão contrária. Por
isso: use este script como TRAVA CONTRA REGRESSÃO, não como meta rumo a zero.

Como compara sem trazer o código de terceiro
--------------------------------------------
`heranca/impressao_original.txt` guarda **hashes** das linhas significativas do
original, não as linhas. Isso evita versionar a obra alheia aqui dentro, e
funciona em clone raso — o CI não precisa do histórico.

O que conta como "linha significativa": mais de 25 caracteres, fora comentário.
Linha curta (`END;`, `BEGIN`, `l_i := l_i + 1;`) coincide por ser PL/SQL, não
por ter vindo de lá, e contá-la só produziria ruído.

O QUE ESTE NÚMERO NÃO DIZ
--------------------------
Ele mostra a linha saindo da contagem; não garante independência. Parafrasear
o original até o hash mudar continua produzindo obra derivada — muda a
aparência. Quando houve reimplementação de verdade nas quatro etapas, ela veio
da fonte primária: os AFM da Adobe para as métricas, a `WinAnsiEncoding` para o
mapeamento, a especificação do PDF para o resto.

E ele não decide nada sobre licença. Se o que sobrou é ou não protegível é
julgamento jurídico, e este arquivo não o substitui.

Uso:
    python dev/scripts/plsql_lint/check_heranca.py             # mede e confere
    python dev/scripts/plsql_lint/check_heranca.py --registrar # baixa o teto
"""
import hashlib
import io
import json
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
IMPRESSOES = os.path.join(AQUI, 'heranca', 'impressao_original.txt')
TETO = os.path.join(AQUI, 'heranca', 'teto.json')

FONTES = ['src/PL_FPDF.pks', 'src/PL_FPDF.pkb',
          'src/PL_FPDF_UTIL.pks', 'src/PL_FPDF_UTIL.pkb']


def impressoes():
    fp = set()
    for l in io.open(IMPRESSOES, encoding='utf-8'):
        l = l.strip()
        if l and not l.startswith('#'):
            fp.add(l)
    return fp


def significativas(caminho):
    """(linha, texto) do que é comparável — vide o critério no cabeçalho."""
    fora = []
    for n, l in enumerate(io.open(caminho, encoding='utf-8',
                                  errors='replace'), 1):
        s = re.sub(r'\s+', ' ', l).strip()
        if len(s) > 25 and not s.startswith('--') and not s.startswith('*'):
            fora.append((n, s))
    return fora


def dono_de_cada_linha(caminho):
    """Em que subprograma cada linha está — para dizer ONDE está a herança."""
    dono, atual = {}, '(nível do package)'
    for n, l in enumerate(io.open(caminho, encoding='utf-8',
                                  errors='replace'), 1):
        m = re.match(r'\s*(PROCEDURE|FUNCTION)\s+([A-Za-z_][A-Za-z0-9_]*)',
                     l, re.I)
        if m:
            atual = m.group(2)
        dono[n] = atual
    return dono


def medir():
    fp = impressoes()
    total = herdadas = 0
    por_rotina = {}
    for rel in FONTES:
        caminho = os.path.join(RAIZ, rel)
        dono = dono_de_cada_linha(caminho)
        for n, s in significativas(caminho):
            total += 1
            h = hashlib.sha256(s.encode('utf-8')).hexdigest()[:16]
            if h in fp:
                herdadas += 1
                chave = f'{os.path.basename(rel)}:{dono[n]}'
                por_rotina[chave] = por_rotina.get(chave, 0) + 1
    return total, herdadas, por_rotina


def main():
    total, herdadas, por_rotina = medir()
    proprias = total - herdadas

    teto = json.load(io.open(TETO, encoding='utf-8'))['herdadas'] \
        if os.path.exists(TETO) else None

    print(f'linhas significativas em src/: {total}')
    print(f'  escritas neste projeto:      {proprias}  '
          f'({100 * proprias / total:.1f}%)')
    print(f'  ainda idênticas ao original: {herdadas}  '
          f'({100 * herdadas / total:.1f}%)')

    if '--registrar' in sys.argv:
        io.open(TETO, 'w', encoding='utf-8').write(
            json.dumps({'herdadas': herdadas}, indent=2) + '\n')
        print(f'\nteto registrado em {herdadas}.')
        return 0

    if teto is None:
        print('\nsem teto registrado. Rode com --registrar.')
        return 1

    if herdadas > teto:
        print(f'\nSUBIU: o teto era {teto} e agora são {herdadas} '
              f'(+{herdadas - teto}).')
        print('Alguma linha do original voltou para src/. As dez rotinas com '
              'mais herança hoje:')
        for k, v in sorted(por_rotina.items(), key=lambda kv: -kv[1])[:10]:
            print(f'  {v:>4}  {k}')
        return 1

    if herdadas < teto:
        print(f'\n{teto - herdadas} linha(s) reconquistada(s) desde o último '
              f'registro. Rode com --registrar para travar o novo patamar.')
        return 0

    print(f'\nno teto ({teto}), sem regressão. Este número tem piso — veja o '
          f'cabeçalho deste arquivo antes de tentar baixá-lo.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
