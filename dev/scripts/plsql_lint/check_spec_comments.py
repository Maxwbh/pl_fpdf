# -*- coding: utf-8 -*-
"""
Toda API pública tem bloco de documentação, no mesmo formato, com o PT-BR na
frente.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
A spec é a documentação que se lê sem sair do banco: quem abre o package no
PL/SQL Developer vê o bloco antes da assinatura, e é dali que decide como
chamar. Na revisão de setembro de 2026 ela não cumpria esse papel.

**Metade da API não tinha bloco nenhum.** 56 subprogramas documentados, **64
sem uma linha** — e os 64 eram justamente os mais usados: `Cell`, `SetFont`,
`Text`, `Line`, `Rect`, `Output`, `MultiCell`. O que tinha bloco era a parte
nova (leitura e manipulação de PDF); o que não tinha era o núcleo herdado do
FPDF, que ninguém reescreveu porque "todo mundo já sabe o que faz".

**E o que tinha bloco vinha em três dialetos.** A parte antiga em inglês só; a
Fase 4 bilíngue com `EN:` antes de `PT:`; o `ImageFromBlob` com rótulo em
inglês e texto em português. Quem lia a spec de cima a baixo trocava de idioma
três vezes.

Duas decisões de projeto, e este verificador guarda as duas:

1. **Descrição de subprograma é bilíngue, PT-BR primeiro e inglês em seguida.**
   O público principal escreve em português; o inglês fica para quem chega de
   fora. O comentário no meio do código, esse é só PT-BR — não é a mesma coisa
   e não se confere aqui.
2. **Bloco faltando é defeito.** Não documentar `Cell` é pior do que não
   documentar `SplitPDF`: o primeiro é chamado cem vezes por relatório.

A deriva é silenciosa por construção — acrescentar um subprograma na spec
compila igual com ou sem bloco, e nenhum teste repara. Só aparece quando
alguém lê o arquivo inteiro, que foi como apareceu.

O formato
---------
::

    /*********************************************************************
    * Procedure: Cell / Célula
    *
    * Descrição / Description:
    *   PT: ...
    *   EN: ...
    *
    * Parâmetros / Parameters:      (quando há parâmetros)
    *   pw - ... / ...
    *
    * Retorna / Returns:            (quando é function)
    *   ...
    *
    * Erros / Raises:               (quando levanta)
    *   -20100: ... / ...
    *
    * Exemplo / Example:
    *   PL_FPDF.Cell(40, 10, 'Total', '1', 1, 'R');
    *********************************************************************/

O que se confere
----------------
1. todo subprograma público tem bloco imediatamente acima (sobrecargas
   compartilham o bloco da primeira);
2. o título é ``Procedure:``/``Function:`` com o nome do subprograma;
3. os rótulos são os bilíngues da tabela ROTULOS, e não a versão só em inglês;
4. ``Descrição / Description`` está presente, e a linha ``PT:`` vem antes da
   ``EN:``;
5. function documenta ``Retorna / Returns``; subprograma com parâmetro
   documenta ``Parâmetros / Parameters``.

O que NÃO se confere, de propósito: se o texto está certo. Isso é revisão
humana. Aqui só se garante que existe, que está no formato e que o português
vem primeiro.

Uso:  python dev/scripts/plsql_lint/check_spec_comments.py
      python dev/scripts/plsql_lint/check_spec_comments.py src/PL_FPDF.pks
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


PADRAO = ['src/PL_FPDF.pks', 'src/PL_FPDF_UTIL.pks']

# rótulo bilíngue esperado -> versão só em inglês que ficou para trás
ROTULOS = {
    'Descrição / Description': 'Description',
    'Parâmetros / Parameters': 'Parameters',
    'Retorna / Returns': 'Returns',
    'Erros / Raises': 'Raises',
    'Nota / Note': 'Note',
    'Exemplo / Example': 'Example',
}
SO_INGLES = {v: k for k, v in ROTULOS.items()}

DECL = re.compile(r'^\s{0,2}(procedure|function)\s+([A-Za-z_][A-Za-z_0-9]*)',
                  re.I)
TITULO = re.compile(r'^\*\s*(Procedure|Function):\s*([A-Za-z_][A-Za-z_0-9]*)',
                    re.M)
ROTULO = re.compile(r'^\*\s{1,3}([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ ()/]*?):')


def blocos_de(linhas):
    """{linha do fim do bloco: [linhas do bloco]}"""
    fim = {}
    i = 0
    while i < len(linhas):
        if linhas[i].startswith('/****'):
            j = i
            while j < len(linhas) and not linhas[j].rstrip().endswith('****/'):
                j += 1
            fim[j] = linhas[i:j + 1]
            i = j
        i += 1
    return fim


def conferir(caminho):
    linhas = io.open(do_repo(caminho), encoding='utf-8').read().split('\n')
    fim = blocos_de(linhas)
    falhas = []
    anterior = None      # nome do subprograma anterior (sobrecarga)

    for n, l in enumerate(linhas):
        m = DECL.match(l)
        if not m:
            continue
        tipo, nome = m.group(1).lower(), m.group(2)

        k = n - 1
        while k >= 0 and linhas[k].strip() == '':
            k -= 1
        bloco = fim.get(k)

        if bloco is None:
            if nome.lower() == (anterior or '').lower():
                continue          # sobrecarga: usa o bloco da primeira
            falhas.append((n + 1, nome, 'sem bloco de documentação'))
            anterior = nome
            continue
        anterior = nome

        texto = '\n'.join(bloco)
        mt = TITULO.search(texto)
        if not mt:
            falhas.append((n + 1, nome,
                           'o bloco não começa com "Procedure:"/"Function:"'))
        else:
            if mt.group(2).lower() != nome.lower():
                falhas.append((n + 1, nome,
                               f'o título do bloco diz "{mt.group(2)}"'))
            esperado = 'Function' if tipo == 'function' else 'Procedure'
            if mt.group(1) != esperado:
                falhas.append((n + 1, nome,
                               f'o bloco diz "{mt.group(1)}:" e isto é '
                               f'{esperado.lower()}'))

        achados = [ROTULO.match(b).group(1).strip()
                   for b in bloco if ROTULO.match(b)]
        achados = [a for a in achados if a not in ('Procedure', 'Function')]

        for a in achados:
            if a in SO_INGLES:
                falhas.append((n + 1, nome,
                               f'rótulo "{a}:" só em inglês — o padrão é '
                               f'"{SO_INGLES[a]}:"'))

        if 'Descrição / Description' not in achados:
            falhas.append((n + 1, nome, 'sem "Descrição / Description:"'))
        else:
            pt = next((i for i, b in enumerate(bloco)
                       if re.match(r'^\*\s+PT:', b)), None)
            en = next((i for i, b in enumerate(bloco)
                       if re.match(r'^\*\s+EN:', b)), None)
            if pt is None or en is None:
                falhas.append((n + 1, nome,
                               'a descrição não tem as duas linhas "PT:" e '
                               '"EN:"'))
            elif pt > en:
                falhas.append((n + 1, nome,
                               'o "EN:" vem antes do "PT:" — o padrão é o '
                               'português na frente'))

        if tipo == 'function' and 'Retorna / Returns' not in achados:
            falhas.append((n + 1, nome, 'function sem "Retorna / Returns:"'))

        tem_param = '(' in l or (n + 1 < len(linhas)
                                 and linhas[n + 1].lstrip().startswith('('))
        if tem_param and 'Parâmetros / Parameters' not in achados:
            falhas.append((n + 1, nome,
                           'tem parâmetro e não tem "Parâmetros / '
                           'Parameters:"'))
    return falhas


def main():
    arquivos = sys.argv[1:] or PADRAO
    total = 0
    for caminho in arquivos:
        falhas = conferir(caminho)
        total += len(falhas)
        if falhas:
            print(f'{caminho}:')
            for linha, nome, motivo in falhas:
                print(f'  linha {linha}: {nome} — {motivo}')
    if total:
        print(f'\n{total} problema(s) no formato dos blocos da spec. '
              f'O padrão está em docs/MANUTENCAO.md, seção "Comentário de '
              f'API".')
        return 1
    print(f'OK — os blocos de {len(arquivos)} spec(s) estão no formato, com o '
          f'português na frente')
    return 0


if __name__ == '__main__':
    sys.exit(main())
