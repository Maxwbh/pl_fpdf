# -*- coding: utf-8 -*-
"""
A referência da API no README da extensão bate com a spec da extensão.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
A referência do PL_FPDF sai da spec por gerador, e não tem como divergir. A da
extensão PIX/Boleto é escrita à mão nos dois READMEs dela, e divergiu: a
revisão de novembro de 2026 achou documentado `CalcularFatorVencimento(p_date
DATE) RETURN NUMBER`, quando a spec declara `CalculateFatorVencimento(p_data
DATE) RETURN VARCHAR2` — outro nome, outro parâmetro, outro tipo. E seis das
catorze rotinas nem apareciam. Quem copiasse o exemplo não compilava.

O que cobra
-----------
Para cada README da extensão, nos blocos de código das seções de referência:

1. toda rotina documentada existe na spec do package, com **os mesmos
   parâmetros, na mesma ordem**, e o mesmo tipo de retorno;
2. toda rotina pública da spec está documentada — a lacuna das seis.

Uso:  python dev/scripts/gen_docs/check_extensao_api.py
"""
import glob
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
EXT = os.path.join(RAIZ, 'extensions', 'brazilian-payments')
READMES = ['README.md', 'README_PT_BR.md']

DECL = re.compile(
    r'\b(FUNCTION|PROCEDURE)\s+(\w+)\s*(\((?:[^()]|\([^()]*\))*\))?'
    r'(?:\s*RETURN\s+(\w+))?', re.I)


def assinaturas(texto):
    """{nome: (parâmetros em ordem, retorno)} das declarações do texto."""
    texto = re.sub(r'/\*.*?\*/', '', texto, flags=re.S)
    texto = re.sub(r'--[^\n]*', '', texto)
    achadas = {}
    for tipo, nome, params, ret in DECL.findall(texto):
        nomes = [p.strip().split()[0].lower()
                 for p in params.strip('()').split(',') if p.strip()] if params else []
        achadas[nome.lower()] = (nomes, ret.upper() if ret else None, tipo.upper())
    return achadas


def spec():
    tudo = {}
    for pks in sorted(glob.glob(os.path.join(EXT, 'packages', '*.pks'))):
        with io.open(pks, encoding='utf-8') as f:
            tudo.update(assinaturas(f.read()))
    return tudo


def documentadas(readme):
    with io.open(os.path.join(EXT, readme), encoding='utf-8') as f:
        texto = f.read()
    # só a seção de referência ("## ... Referência da API" / "API Reference"),
    # até o "---" que a fecha. Ancorar num "### ... PL_FPDF_PIX" pegava antes o
    # "Pacote PL_FPDF_PIX" da descrição, que não tem código nenhum.
    m = re.search(r'\n## [^\n]*(?:Referência da API|API Reference)[^\n]*\n(.*?)\n---\n',
                  texto, re.S)
    if not m:
        return None
    blocos = re.findall(r'```sql\n(.*?)```', m.group(1), re.S)
    return assinaturas('\n'.join(blocos))


def main():
    s = spec()
    erros = []
    for readme in READMES:
        d = documentadas(readme)
        if d is None:
            erros.append(f'{readme}: seção de referência da API não encontrada')
            continue
        for nome, (params, ret, tipo) in sorted(d.items()):
            if nome not in s:
                erros.append(f'{readme}: {tipo} {nome} não existe na spec da extensão')
                continue
            sp, sr, st = s[nome]
            if (params, ret, tipo) != (sp, sr, st):
                erros.append(f'{readme}: {nome} documentada como {tipo}({", ".join(params)})'
                             f'{" RETURN " + ret if ret else ""}; a spec diz '
                             f'{st}({", ".join(sp)}){" RETURN " + sr if sr else ""}')
        for nome in sorted(set(s) - set(d)):
            erros.append(f'{readme}: {nome} está na spec e não está documentada')
    if erros:
        print('ERRO: a referência da extensão diverge da spec:')
        for e in erros:
            print('  ' + e)
        return 1
    print(f'OK — {len(s)} rotinas da extensão documentadas como na spec, '
          f'nos {len(READMES)} READMEs')
    return 0


if __name__ == '__main__':
    sys.exit(main())
