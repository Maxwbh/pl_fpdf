# -*- coding: utf-8 -*-
"""
Os exemplos da documentação estão prontos para o runner — conferido sem banco.

DOCUMENTO DE MANUTENÇÃO.

Quem EXECUTA os exemplos é o `run_tests.py`, contra o Oracle, que o CI não tem.
Aqui se confere o que dá para conferir sem ele, para o runner não tropeçar no
que é previsível:

1. **Bloco que não tem como rodar sozinho tem a marca.** Bind (`:P10_ID`),
   APEX (`apex_*`) e gateway (`owa_util`, `htp`, `wpg_docload`) não existem no
   schema de teste; sem a marca `<!-- exemplo-ilustrativo: motivo -->`, o
   runner acusaria falha de um exemplo certo.
2. **Toda marca tem motivo e está logo acima de uma cerca ```sql.** Marca solta
   não marca nada, e o bloco que ela devia isentar roda — e falha.
3. **PT e EN têm o mesmo número de exemplos executáveis e ilustrativos.** Um
   exemplo marcado de um lado só some da execução daquele idioma.

A regra, e o formato da marca, estão em `dev/scripts/exemplos_doc.py`.

Uso:  python dev/scripts/gen_docs/check_exemplos_doc.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import exemplos_doc  # noqa: E402

# bind de APEX/ORDS (:P10_ID), mas não atribuição (:=) nem hora ('HH24:MI')
BIND = re.compile(r"(?<![\w'])\:(?!=)[A-Za-z_]\w*")
FORA_DO_SCHEMA = re.compile(r'\b(apex_\w+|owa_util|htp\s*\.|wpg_docload)', re.I)


def sem_strings(codigo):
    codigo = re.sub(r'--[^\n]*', '', codigo)
    return re.sub(r"'(?:[^']|'')*'", "''", codigo)


def main():
    erros = []
    por_doc = {}
    for rel in exemplos_doc.DOCS:
        total, soltas = exemplos_doc.marcas(rel)
        for n in soltas:
            erros.append(f'{rel}:{n}: marca "exemplo-ilustrativo" que não está '
                         f'logo acima de uma cerca ```sql')
        roda = ilustra = 0
        for b in exemplos_doc.blocos(rel):
            if b['motivo'] is not None:
                ilustra += 1
                if not b['motivo']:
                    erros.append(f'{rel}:{b["linha"]}: marca sem motivo')
                continue
            roda += 1
            codigo = sem_strings(b['codigo'])
            m = BIND.search(codigo) or FORA_DO_SCHEMA.search(codigo)
            if m:
                erros.append(f'{rel}:{b["linha"]}: usa {m.group(0)!r}, que o '
                             f'schema de teste não tem — marque o bloco com '
                             f'<!-- exemplo-ilustrativo: motivo -->')
        por_doc[rel] = (roda, ilustra)
    for rel, (roda, ilustra) in por_doc.items():
        if rel.endswith('_EN.md'):
            pt = rel[:-6] + '.md'
            if pt in por_doc and por_doc[pt] != (roda, ilustra):
                erros.append(f'{rel}: {roda} exemplo(s) executável(is) e {ilustra} '
                             f'ilustrativo(s); {pt} tem {por_doc[pt][0]} e '
                             f'{por_doc[pt][1]}')
    if erros:
        print('ERRO: exemplos da documentação:')
        for e in erros:
            print('  ' + e)
        return 1
    roda = sum(r for r, _ in por_doc.values())
    ilustra = sum(i for _, i in por_doc.values())
    print(f'OK — {roda} exemplo(s) prontos para o runner e {ilustra} '
          f'ilustrativo(s) com motivo, em {len(por_doc)} guias')
    return 0


if __name__ == '__main__':
    sys.exit(main())
