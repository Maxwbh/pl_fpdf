# -*- coding: utf-8 -*-
"""
Acusa dois usos de `NVL` que o PL/SQL não perdoa: sobre tabela indexada e
sobre LOB.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Ler um índice que não existe numa tabela indexada (associative array) levanta
`NO_DATA_FOUND`. Envolver em `NVL` **não protege**: o índice é lido primeiro, a
exceção sobe, e o `NVL` nunca chega a ver valor nenhum.

    l_cand := NVL(g_def_cab(l_h), -1);          -- ORA-01403 quando falta
    l_cand := CASE WHEN g_def_cab.EXISTS(l_h)   -- assim, sim
                   THEN g_def_cab(l_h) ELSE -1 END;

O engano é convidativo porque `NVL` protege contra NULL em quase todo lugar, e
porque a linha *parece* defensiva. O sintoma é pior ainda: o código funciona
enquanto a tabela está cheia e falha na primeira posição não visitada — no
deflate, isso é o primeiro byte de um conteúdo novo.

É primo da armadilha de atribuir a `l_pts(0).x`
antes de o elemento existir.

A segunda regra: `NVL` sobre LOB
--------------------------------
`NVL(p_data, EMPTY_BLOB())` **não compila**: `PLS-00306`. O `NVL` do PL/SQL não
tem sobrecarga para `BLOB`/`CLOB` — o que existe é o `NVL` do SQL, e a chamada
dentro de PL/SQL resolve pela lista interna, que não cobre LOB.

Custa uma ida ao banco inteira, porque o erro só aparece na compilação e a
mensagem fala de "wrong number or types of arguments", sem dizer que o problema
é o tipo do argumento. Aconteceu no `FlateEncode`. O certo é testar
`IS NULL` e montar um LOB temporário vazio.

O que é acusado
---------------
`NVL(x(...))` onde `x` foi declarado com um dos tipos de tabela indexada do
package, e `NVL(y, ...)` onde `y` foi declarado `BLOB` ou `CLOB`. Nos dois
casos o nome precisa constar das declarações, então chamada de função com o
mesmo formato não é acusada.

Uso:  python scripts/plsql_lint/check_assoc_nvl.py src/PL_FPDF.pkb
"""
import io
import re
import sys

# tipos de tabela indexada declarados no package
TIPOS = r'(?:tpi|tv32k|tv4000|tv4000a|tv255|tblob|tab_points|charSet)'
DECL = re.compile(r'^\s*([a-z_][a-z_0-9$#]*)\s+' + TIPOS + r'\s*[;:]',
                  re.I | re.M)
USO = re.compile(r'NVL\s*\(\s*([a-z_][a-z_0-9$#]*)\s*\(', re.I)

# variáveis e parâmetros declarados BLOB ou CLOB
DECL_LOB = re.compile(r'^\s*([a-z_][a-z_0-9$#]*)\s+(?:IN\s+OUT\s+NOCOPY\s+|'
                      r'IN\s+OUT\s+|IN\s+|OUT\s+)?(?:BLOB|CLOB)\b',
                      re.I | re.M)
USO_LOB = re.compile(r'NVL\s*\(\s*([a-z_][a-z_0-9$#]*)\s*,', re.I)


def main(caminhos):
    problemas = []
    total = 0
    for caminho in caminhos:
        texto = io.open(caminho, encoding='utf-8').read()
        sem_comentario = re.sub(r'--[^\n]*', '', texto)
        tabelas = {m.group(1).lower() for m in DECL.finditer(sem_comentario)}
        lobs = {m.group(1).lower() for m in DECL_LOB.finditer(sem_comentario)}
        total += len(tabelas) + len(lobs)
        for m in USO.finditer(sem_comentario):
            if m.group(1).lower() in tabelas:
                linha = sem_comentario[:m.start()].count('\n') + 1
                problemas.append(
                    f'{caminho}:{linha}: NVL({m.group(1)}(...)) não evita '
                    f'NO_DATA_FOUND — o índice é lido antes. Use '
                    f'{m.group(1)}.EXISTS(i) primeiro.')
        for m in USO_LOB.finditer(sem_comentario):
            if m.group(1).lower() in lobs:
                linha = sem_comentario[:m.start()].count('\n') + 1
                problemas.append(
                    f'{caminho}:{linha}: NVL({m.group(1)}, ...) sobre LOB não '
                    f'compila (PLS-00306) — o NVL do PL/SQL não tem sobrecarga '
                    f'para BLOB/CLOB. Teste IS NULL.')

    if problemas:
        print('\n'.join(problemas))
        print(f'\n{len(problemas)} uso(s) de NVL que o PL/SQL não perdoa.')
        return 1

    print(f'OK — nenhum NVL sobre tabela indexada nem sobre LOB '
          f'({total} declaração(ões) examinada(s))')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:] or ['src/PL_FPDF.pkb']))
