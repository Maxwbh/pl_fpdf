# -*- coding: utf-8 -*-
"""
Lê os blocos Javadoc da spec e devolve a documentação da API em JSON.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
`parse_spec.py` lê só a **assinatura** — nome, parâmetros, tipos, defaults — e
joga fora o comentário. Enquanto a documentação da API vivia à mão em
`docs/API_REFERENCE.md` e em `site/reference.html`, isso bastava: o que aqueles
arquivos diziam não tinha de onde ser conferido.

Só que agora a descrição, os parâmetros, os erros e o exemplo estão **na spec**,
em Javadoc, e conferidos pelo `check_spec_comments.py`. São 9.252 linhas de
referência escritas à mão contra 137 blocos que já dizem a mesma coisa e que o
CI já guarda. Duas fontes para o mesmo fato divergem — é a regra que esta base
aplica ao comentário do body, e vale igual aqui.

Este módulo é a **leitura**: transforma o bloco em estrutura. Quem escreve a
página é outro passo, e ele só pode existir depois que a leitura estiver
provada — daí o `--verificar`, que confere a extração dos 137 blocos contra a
assinatura e falha quando algum não se deixa ler.

O que se extrai de cada subprograma
-----------------------------------
``nome``, ``tipo`` (procedure/function), ``descricao``, ``params``
(nome e texto, na ordem da assinatura), ``retorno``, ``erros`` (código e
texto), ``exemplo`` (linhas literais) e ``notas`` (``@note``, ``@limitation``,
``@process``).

Sobrecargas compartilham o bloco da primeira, como na spec.

Uso:
  python dev/scripts/gen_docs/parse_javadoc.py              # JSON na saída
  python dev/scripts/gen_docs/parse_javadoc.py --verificar  # confere a leitura
"""
import io
import json
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


SPECS = ['src/PL_FPDF.pks', 'src/PL_FPDF_UTIL.pks']

DECL = re.compile(r'^\s{0,2}(procedure|function)\s+([A-Za-z_][A-Za-z_0-9]*)',
                  re.I)
TAG = re.compile(r'^\s*\*\s*(@[a-z]+)\s?(.*)$')
CONT = re.compile(r'^\s*\*\s{2,}(\S.*)$')
LINHA = re.compile(r'^\s*\*\s?(.*)$')
# `0 = `, `'up' = `: abre enumeracao dentro de um @param
SUBITEM = re.compile(r"\b(\d+|'[^']*'|[A-Za-z_]\w*)\s*=\s")


def parametros_da_assinatura(linhas, n):
    """Os nomes dos parâmetros da declaração que começa na linha n, em ordem.

    Mesma varredura do `check_spec_comments.py`: conta profundidade de
    parêntese e respeita literal, e para no `;` de nível zero — sem isso, um
    `procedure Header;` varreria o comentário do subprograma seguinte.
    """
    texto, i, prof, achou, fim = '', n, 0, False, False
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


def repartir_subitens(texto):
    """(cabeça, itens) de um texto de `@param` que enumera opções.

    O sub-item (`0 = ...`, `1 = ...`) sai em item próprio: na spec ele está em
    linha própria, e colado num parágrafo só ninguém lê onde acaba uma opção e
    começa a outra.

    Também serve à página em inglês, que reparte pela mesma regra para as duas
    tabelas saírem com o mesmo desenho.
    """
    texto = (texto or '').strip()
    corte = SUBITEM.search(texto)
    if not corte:
        return texto, []
    # a vírgula que separava as opções na frase corrida some: repartida, cada
    # item vira uma linha, e o `(default),` ficava com a pontuação do meio da
    # frase pendurada no fim
    itens = [x.strip().rstrip(',;') for x in
             re.split(r'(?=\b\w{1,8}\s*=\s)', texto[corte.start():])
             if x.strip()]
    return texto[:corte.start()].strip().rstrip(',;'), itens


def ler_bloco(bloco):
    """O bloco Javadoc (lista de linhas) como estrutura."""
    doc = {'descricao': '', 'params': [], 'retorno': '', 'erros': [],
           'exemplo': [], 'notas': []}
    tag, buf = None, []

    def fechar():
        if tag is None or not buf:
            return
        texto = ' '.join(x.strip() for x in buf if x.strip())
        texto = re.sub(r'\s+', ' ', texto).strip()
        if tag == '@param':
            m = re.match(r'^(\S+)\s*(.*)$', texto)
            if m:
                resto, itens = repartir_subitens(m.group(2))
                doc['params'].append({'nome': m.group(1), 'texto': resto,
                                      'itens': itens})
        elif tag == '@return':
            doc['retorno'] = texto
        elif tag == '@raises':
            m = re.match(r'^(-?\d+)\s*(.*)$', texto)
            doc['erros'].append({'codigo': m.group(1) if m else '',
                                 'texto': (m.group(2) if m else texto).strip()})
        elif tag in ('@note', '@limitation', '@process', '@options'):
            doc['notas'].append({'tipo': tag[1:], 'texto': texto})

    for l in bloco[1:-1]:
        m = TAG.match(l)
        if m:
            fechar()
            tag, buf = m.group(1), [m.group(2)]
            continue
        if tag == '@example':
            # exemplo e CODIGO: sai literal, sem reenrolar. A linha EM BRANCO
            # fica: e ela que separa um caso do outro, e sem ela os tres casos
            # de borda do Cell viravam um bloco so.
            mm = LINHA.match(l)
            if mm:
                doc['exemplo'].append(mm.group(1).rstrip())
            continue
        if tag is None:
            mm = LINHA.match(l)
            if mm:
                doc['descricao'] += ' ' + mm.group(1).strip()
            continue
        mm = CONT.match(l) or LINHA.match(l)
        if mm:
            buf.append(mm.group(1))
    fechar()
    doc['descricao'] = re.sub(r'\s+', ' ', doc['descricao']).strip()
    while doc['exemplo'] and not doc['exemplo'][0].strip():
        doc['exemplo'].pop(0)
    while doc['exemplo'] and not doc['exemplo'][-1].strip():
        doc['exemplo'].pop()
    return doc


def ler(caminho):
    linhas = io.open(do_repo(caminho), encoding='utf-8').read().split('\n')
    fim, i = {}, 0
    while i < len(linhas):
        if linhas[i].strip().startswith('/**'):
            j = i
            while j < len(linhas) and not linhas[j].rstrip().endswith('*/'):
                j += 1
            fim[j] = linhas[i:j + 1]
            i = j
        i += 1

    saida, anterior = [], None
    for n, l in enumerate(linhas):
        m = DECL.match(l)
        if not m:
            continue
        tipo, nome = m.group(1).lower(), m.group(2)
        k = n - 1
        while k >= 0 and not linhas[k].strip():
            k -= 1
        bloco = fim.get(k)
        if bloco is None:
            # sobrecarga: compartilha o bloco da primeira, como na spec
            if anterior and anterior['nome'].lower() == nome.lower():
                # herda o TEXTO do bloco, mas nao a assinatura: a sobrecarga
                # pode ser procedure onde a primeira e function, e tem nomes
                # de parametro proprios
                saida.append(dict(anterior, tipo=tipo, nome=nome, linha=n + 1,
                                  assinatura_params=
                                  parametros_da_assinatura(linhas, n),
                                  sobrecarga=True))
            continue
        doc = ler_bloco(bloco)
        doc.update({'nome': nome, 'tipo': tipo, 'arquivo': caminho,
                    'linha': n + 1, 'sobrecarga': False,
                    'assinatura_params': parametros_da_assinatura(linhas, n)})
        saida.append(doc)
        anterior = doc
    return saida


def verificar(api):
    """A leitura serve para gerar a página? Falha quando algum bloco não se
    deixa ler — é o que impede publicar uma referência com buraco."""
    falhas = []
    for a in api:
        onde = f"{a['arquivo']}:{a['linha']} {a['nome']}"
        if a['sobrecarga']:
            continue
        if not a['descricao']:
            falhas.append(f'{onde}: sem descrição')
        doc = [p['nome'].lower() for p in a['params']]
        sig = [p.lower() for p in a['assinatura_params']]
        if doc != sig:
            falhas.append(f'{onde}: @param {doc} não bate com a assinatura '
                          f'{sig}')
        if any(not p['texto'] for p in a['params']):
            falhas.append(f'{onde}: @param sem texto')
        if a['tipo'] == 'function' and not a['retorno']:
            falhas.append(f'{onde}: function sem @return')
        if any(not e['codigo'] for e in a['erros']):
            falhas.append(f'{onde}: @raises sem código')
    return falhas


def main():
    api = []
    for s in SPECS:
        api += ler(s)
    if '--verificar' in sys.argv:
        falhas = verificar(api)
        for f in falhas:
            print('  ' + f)
        if falhas:
            print(f'\n{len(falhas)} bloco(s) que a leitura não resolve.')
            return 1
        unicos = [a for a in api if not a['sobrecarga']]
        print(f'OK — {len(api)} entradas lidas ({len(unicos)} blocos, '
              f'{len(api) - len(unicos)} sobrecargas), descrição, @param na '
              f'ordem da assinatura, @return e @raises todos extraídos')
        return 0
    print(json.dumps(api, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
