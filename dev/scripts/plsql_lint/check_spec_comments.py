# -*- coding: utf-8 -*-
"""
Toda API pública tem bloco Javadoc, no mesmo formato, em PT-BR.

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

Por que Javadoc, e não mais o banner
------------------------------------
Até outubro de 2026 o formato era um banner de asteriscos com rótulos
bilíngues (`Descrição / Description:`, `Parâmetros / Parameters:`). O conteúdo
era o certo; a notação é que saiu do padrão. A Trivadis PL/SQL Guidelines 4.4,
seção *Comentários*, prescreve o bloco Javadoc-like — descrição, depois
`@param` e `@raises` —, e é o padrão que o resto do código desta casa segue.

A troca não foi só de aparência. O banner escrevia o parâmetro como texto
solto (`pw     - largura; 0 vai até...`), e por isso **nenhum verificador
conseguia dizer se a documentação batia com a assinatura**: acrescentar um
parâmetro, renomear ou remover um passava sem ninguém reparar. O `@param`
nomeia, e a regra 6 abaixo confere — é a única checagem realmente nova, e é a
que pega a deriva que acontece de verdade, porque mexer na assinatura é comum
e voltar no comentário é o que se esquece.

Por que só PT-BR
----------------
Até outubro de 2026 a descrição era bilíngue, com o inglês em seguida. Saiu:
o texto da spec é em português, e o que fica em inglês é **nome próprio e
jargão** -- Portrait, Landscape, WinAnsi, stream, xref, deflate, BLOB,
FlateDecode --, que não têm substituto e cuja tradução inventada faria o leitor
procurar no PDF um termo que não existe. É a mesma regra que esta casa já
aplica às siglas: `'P' (Portrait, retrato)` mostra de onde a letra vem.

A referência pública em inglês não depende disto: `gen_docs/parse_spec.py` tira
os comentários e lê só as assinaturas.

E a linha de título (`* Procedure: Cell / Célula`) **caiu**: o nome repete a
assinatura logo abaixo, e "comentário que repete o código" é antipattern
nomeado na própria Guideline. O apelido em português que ela carregava já
estava na primeira frase da descrição em todos os 137 blocos — conferido palavra
a palavra na conversão.

Duas decisões de projeto, e este verificador guarda as duas:

1. **O texto é em PT-BR.** O que fica em inglês é nome próprio e jargão, que
   não têm substituto. O comentário no meio do código segue a mesma regra.
2. **Bloco faltando é defeito.** Não documentar `Cell` é pior do que não
   documentar `SplitPDF`: o primeiro é chamado cem vezes por relatório.

A deriva é silenciosa por construção — acrescentar um subprograma na spec
compila igual com ou sem bloco, e nenhum teste repara. Só aparece quando
alguém lê o arquivo inteiro, que foi como apareceu.

O formato
---------
::

    /**
     * Escreve uma célula retangular: opcionalmente com borda, com fundo e
     * com texto dentro.
     *
     * @param pw largura; 0 vai até a margem direita
     * @return NUMBER - ...                 (quando é function)
     * @raises -20100 ...                   (quando levanta)
     * @example
     *   PL_FPDF.Cell(40, 10, 'Total', '1', 1, 'R');
     */

Tag é palavra-chave, e palavra-chave fica em inglês nesta base — daí `@note`,
`@limitation`, `@process` e `@options` para os rótulos opcionais.

O que se confere
----------------
1. todo subprograma público tem bloco imediatamente acima (sobrecargas
   compartilham o bloco da primeira);
2. o bloco é Javadoc (`/**`), e não sobrou nada do banner antigo;
3. o bloco abre com descrição, e não sobrou marcador ``PT:``/``EN:`` nem par
   bilíngue ``<português> / <english>`` do formato antigo;
4. só se usam as tags da tabela TAGS — pega `@throws`, `@returns`, `@params`;
5. function documenta ``@return``;
6. **todo parâmetro da assinatura tem `@param`, e todo `@param` corresponde a
   um parâmetro** — nos dois sentidos, e na ordem da assinatura;
7. **nenhum bloco aponta para arquivo do repositório**. Quem lê a spec está no
   PL/SQL Developer, muitas vezes sem o repositório à mão: mandá-lo abrir
   `docs/ROADMAP.md` troca a explicação por um endereço que ele não pode
   seguir. O que se cita é o que não se pode embutir — a norma, o formato, o
   decodificador contra o qual se validou.

O que NÃO se confere, de propósito: se o texto está certo. Isso é revisão
humana. Aqui só se garante que existe, que está no formato, que é português e
que a lista de parâmetros bate.

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

TAGS = {'@param', '@return', '@raises', '@note', '@example', '@limitation',
        '@process', '@options'}

# tag errada -> a certa. Sao os enganos que a mao comete sozinha.
ENGANOS = {'@returns': '@return', '@throws': '@raises', '@throw': '@raises',
           '@params': '@param', '@exception': '@raises', '@arg': '@param',
           '@ret': '@return'}

DECL = re.compile(r'^\s{0,2}(procedure|function)\s+([A-Za-z_][A-Za-z_0-9]*)',
                  re.I)
TAG = re.compile(r'^\s*\*\s*(@[A-Za-z_]+)')

# uma ` / ` dentro de literal ou de caminho nao e par bilingue: 'up'/'U',
# OS/2, docs/ROADMAP.md, http/https
LIVRE = re.compile(r"'[^']*'\s*/|/\s*'[^']*'|\w/\w|@example|@note \w")

# Palavra funcional inglesa que NAO existe em portugues. `for`, `so`, `no`,
# `a` e `as` ficaram de fora de proposito: sao palavras dos dois idiomas
# (`for` e verbo, `so` e "so" sem acento) e marcavam prosa portuguesa como
# inglesa.
FUNC = set('''the of and to in with is are be by from on it its or not an
that this which when will can must should would could has have had into only
both all any more than then there here'''.split())
# linha de codigo de exemplo: `IF ... THEN`, `SELECT ... INTO`, chamada, JSON
CODIGO = re.compile(r'^\s*\*\s+(IF|BEGIN|END|DECLARE|SELECT|INSERT|UPDATE|'
                    r'FOR|LOOP|EXIT|PL_FPDF|DBMS_|l_|:=|\{|\}|"|--|/\*)',
                    re.I)
LITERAL = re.compile(r"'(?:[^']|'')*'")
# Caminho de arquivo do repositorio dentro do bloco. Proibido: o comentario
# tem de se bastar -- endereco envelhece, e ponteiro quebrado em comentario
# nao quebra nada, entao ninguem descobre.
CAMINHO = re.compile(r'\b((?:dev|docs|src|examples|site|extensions|\.github)'
                     r'/[\w./*-]+)')


def ingles(linha):
    """A linha e prosa inglesa? Codigo de exemplo e literal nao contam."""
    if CODIGO.match(linha):
        return False
    texto = LITERAL.sub(' ', re.sub(r'^\s*\*\s?', '', linha))
    # Identificador nao e prosa: `pdf_is_ws / pdf_is_alnum` daria dois "is",
    # e `Parametro IN (nao IN OUT)` daria dois "in" -- os dois marcavam
    # portugues como ingles. Token com `_` e token TODO EM MAIUSCULA (palavra
    # reservada do PL/SQL, nome de tipo) ficam de fora da conta.
    p = [w.lower() for w in re.findall(r'[A-Za-zÀ-ÿ_]+', texto)
         if '_' not in w and not w.isupper()]
    return any(sum(1 for k in range(j, min(j + 4, len(p)))
                   if p[k] in FUNC) >= 2 for j in range(len(p)))


# o que sobrou do banner antigo, se a conversao passou por cima de alguem
BANNER = re.compile(r'^\s*\*\s*(Procedure|Function|Descrição / Description|'
                    r'Parâmetros / Parameters|Retorna / Returns|'
                    r'Erros / Raises):')


def parametros(linhas, n):
    """Os nomes dos parametros da declaracao que comeca na linha n.

    Percorre ate fechar o parentese, contando profundidade e respeitando
    literal -- um default como `'[] 0'` tem espaco dentro, e `noParam` tem
    parentese em outros casos.
    """
    texto = ''
    i, prof, achou, fim = n, 0, False, False
    while i < len(linhas) and i < n + 60 and not fim:
        literal = False
        for c in linhas[i]:
            if literal:
                if c == "'":
                    literal = False
                if prof >= 1:
                    texto += c
                continue
            if c == "'":
                literal = True
            elif c == '(':
                prof += 1
                achou = True
                if prof == 1:
                    continue
            elif c == ')':
                prof -= 1
                if prof == 0:
                    fim = True
                    break
            elif c == ';' and prof == 0:
                # `procedure Header;` nao tem parametro nenhum. Sem esta
                # parada o laco seguia varrendo e achava o parentese do
                # comentario do subprograma de baixo -- foi assim que o
                # IsInitialized "ganhou" os parametros width e height.
                fim = True
                break
            if prof >= 1:
                texto += c
        texto += ' '
        i += 1
    if not achou:
        return []

    nomes, atual, prof, literal = [], '', 0, False
    for c in texto:
        if literal:
            if c == "'":
                literal = False
            continue
        if c == "'":
            literal = True
        elif c == '(':
            prof += 1
        elif c == ')':
            prof -= 1
        elif c == ',' and prof == 0:
            nomes.append(atual)
            atual = ''
            continue
        atual += c
    nomes.append(atual)
    return [p.split()[0] for p in nomes if p.split()]


def blocos_de(linhas):
    """{linha do fim do bloco: [linhas do bloco]}"""
    fim = {}
    i = 0
    while i < len(linhas):
        s = linhas[i].strip()
        if s.startswith('/**') or s.startswith('/***'):
            j = i
            while j < len(linhas) and not linhas[j].rstrip().endswith('*/'):
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

        def falha(motivo):
            falhas.append((n + 1, nome, motivo))

        if bloco is None:
            if nome.lower() == (anterior or '').lower():
                continue          # sobrecarga: usa o bloco da primeira
            falha('sem bloco de documentação')
            anterior = nome
            continue
        anterior = nome

        if not bloco[0].strip().startswith('/**') or \
                bloco[0].strip().startswith('/****'):
            falha('o bloco não abre com "/**" — o formato é Javadoc')

        for b in bloco:
            mb = BANNER.match(b)
            if mb:
                falha(f'sobrou o rótulo do formato antigo "{mb.group(1)}:"')
                break

        achadas = []
        for b in bloco:
            mt = TAG.match(b)
            if not mt:
                continue
            t = mt.group(1)
            achadas.append(t)
            if t.lower() in ENGANOS:
                falha(f'tag "{t}" não existe aqui — é '
                      f'"{ENGANOS[t.lower()]}"')
            elif t not in TAGS:
                falha(f'tag "{t}" fora do conjunto conhecido')

        corpo = [b for b in bloco[1:-1] if b.strip().strip('*').strip()]
        if not corpo or TAG.match(corpo[0]):
            falha('o bloco não abre com a descrição')

        for b in bloco:
            if re.match(r'^\s*\*\s+(PT|EN):', b):
                falha('sobrou o marcador "PT:"/"EN:" do formato bilíngue')
                break

        for b in bloco:
            if ' / ' in b and not LIVRE.search(b):
                falha('linha com par bilíngue "<português> / <english>": '
                      + b.strip()[:56])
                break

        for b in bloco:
            if ingles(b):
                falha('linha com cara de prosa inglesa: ' + b.strip()[:56])
                break

        for b in bloco:
            m2 = CAMINHO.search(b)
            if m2:
                falha(f'aponta para "{m2.group(1).rstrip(".,")}" — o bloco não '
                      f'remete a documento, ele diz a coisa')
                break

        if tipo == 'function' and '@return' not in achadas:
            falha('function sem "@return"')

        esperados = parametros(linhas, n)
        documentados = [re.match(r'^\s*\*\s*@param\s+(\S+)', b).group(1)
                        for b in bloco
                        if re.match(r'^\s*\*\s*@param\s+\S', b)]
        faltam = [p for p in esperados
                  if p.lower() not in [d.lower() for d in documentados]]
        sobram = [d for d in documentados
                  if d.lower() not in [p.lower() for p in esperados]]
        if faltam:
            falha('parâmetro sem "@param": ' + ', '.join(faltam))
        if sobram:
            falha('"@param" para o que não é parâmetro: ' + ', '.join(sobram))
        if not faltam and not sobram and \
                [d.lower() for d in documentados] != \
                [p.lower() for p in esperados]:
            falha('os "@param" estão fora da ordem da assinatura: '
                  + ', '.join(documentados) + ' contra ' + ', '.join(esperados))
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
    print(f'OK — os blocos de {len(arquivos)} spec(s) estão em Javadoc, em '
          f'PT-BR, com os @param batendo com a assinatura')
    return 0


if __name__ == '__main__':
    sys.exit(main())
