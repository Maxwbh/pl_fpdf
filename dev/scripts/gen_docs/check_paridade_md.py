# -*- coding: utf-8 -*-
"""
Os guias em Markdown não divergem entre PT e EN em silêncio.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
O `check_paridade.py` cobre as páginas do site. Os `.md` ficavam de fora, e o
furo apareceu numa revisão de novembro de 2026: o `README_EN.md` não tinha a
seção de **Limitações** que o `README.md` tem — assinatura digital, formulário,
estado por sessão. Quem lia em inglês não ficava sabendo o que a biblioteca
NÃO faz, que é justamente o que se precisa saber antes de adotar. Nenhuma
verificação reclamou, porque nenhuma olhava.

O que cobra, par a par
----------------------
1. **Os mesmos títulos, nos mesmos níveis e na mesma ordem.** Uma seção que
   existe de um lado só é o defeito acima.
2. **O mesmo número de linhas de tabela em cada seção.** Uma linha de
   compatibilidade, um erro na tabela de problemas, uma API: acrescentada de
   um lado só, é pega aqui.
3. **Os mesmos blocos de código, chamando as mesmas APIs com os mesmos
   parâmetros nomeados.** Comentário, literal e nome de variável mudam de
   idioma; a API demonstrada, não.
4. **Nenhuma frase da página inglesa idêntica à portuguesa.** Seção copiada sem
   traduzir passa nas três regras acima, porque a estrutura é a mesma.

Os pares são os guias de quem usa. A referência da API não entra: ela sai do
gerador, nos dois idiomas, da mesma fonte.

Uso:  python dev/scripts/gen_docs/check_paridade_md.py
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

PARES = [('README.md', 'README_EN.md'),
         ('extensions/brazilian-payments/README_PT_BR.md',
          'extensions/brazilian-payments/README.md')]
PARES += [(f'docs/{n}.md', f'docs/{n}_EN.md') for n in
          ('DOCUMENTATION', 'INSTALLATION', 'COMPATIBILITY', 'MIGRATION',
           'TROUBLESHOOTING')]

CERCA = re.compile(r'^```')
API = re.compile(r'\b(PL_FPDF(?:_UTIL|_PIX|_BOLETO)?)\.(\w+)', re.I)
NOMEADO = re.compile(r'\b(p_\w+)\s*=>', re.I)


def ler(rel):
    with io.open(os.path.join(RAIZ, rel), encoding='utf-8') as f:
        return f.read().splitlines()


def analisar(linhas):
    """Títulos, linhas de tabela por seção, blocos de código e frases."""
    titulos, tabelas, blocos, frases = [], [], [], set()
    secao_tab = 0
    em_codigo, codigo = False, []
    for linha in linhas:
        if CERCA.match(linha):
            if em_codigo:
                texto = '\n'.join(codigo)
                apis = sorted({(p.upper(), n.lower()) for p, n in API.findall(texto)})
                nomeados = sorted({n.lower() for n in NOMEADO.findall(texto)})
                blocos.append((apis, nomeados))
                codigo = []
            em_codigo = not em_codigo
            continue
        if em_codigo:
            codigo.append(linha)
            continue
        m = re.match(r'^(#{1,6})\s', linha)
        if m:
            tabelas.append(secao_tab)
            secao_tab = 0
            titulos.append(len(m.group(1)))
            continue
        if linha.startswith('|'):
            secao_tab += 1
            continue
        # frase de prosa: tirando código em linha e links, sobra texto?
        prosa = re.sub(r'`[^`]*`|\[[^\]]*\]\([^)]*\)|<[^>]+>|https?://\S+', '', linha)
        prosa = prosa.strip(' >*-_|')
        if len(prosa) >= 40 and len(re.findall(r'[A-Za-zÀ-ÿ]{3,}', prosa)) >= 6:
            frases.add(linha.strip())
    tabelas.append(secao_tab)
    return titulos, tabelas, blocos, frases


def comparar(pt, en):
    erros = []
    tp, sp, bp, fp = analisar(ler(pt))
    te, se, be, fe = analisar(ler(en))
    if tp != te:
        erros.append(f'títulos diferentes: {len(tp)} em {pt}, {len(te)} em {en} '
                     f'(níveis {"".join(map(str, tp))} x {"".join(map(str, te))})')
    elif sp != se:
        for i, (a, b) in enumerate(zip(sp, se)):
            if a != b:
                erros.append(f'seção {i}: {a} linhas de tabela em {pt}, {b} em {en}')
    if len(bp) != len(be):
        erros.append(f'{len(bp)} blocos de código em {pt}, {len(be)} em {en}')
    else:
        for i, (a, b) in enumerate(zip(bp, be), 1):
            if a != b:
                erros.append(f'bloco de código {i}: APIs/parâmetros diferentes — '
                             f'{pt}: {a} | {en}: {b}')
    for frase in sorted(fp & fe):
        erros.append(f'frase idêntica nos dois idiomas (não traduzida?): {frase[:90]}')
    return erros


def main():
    erros = []
    for pt, en in PARES:
        erros += [f'{en}: {e}' for e in comparar(pt, en)]
    if erros:
        print('ERRO: guias em PT e EN divergem:')
        for e in erros:
            print('  ' + e)
        return 1
    print(f'OK — {len(PARES)} pares de guias PT/EN com a mesma estrutura')
    return 0


if __name__ == '__main__':
    sys.exit(main())
