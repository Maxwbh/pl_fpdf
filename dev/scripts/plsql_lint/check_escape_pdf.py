# -*- coding: utf-8 -*-
"""
Só uma rotina escapa string literal de PDF, e ela está certa.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Dentro de `( ... )` num fluxo de conteúdo PDF, a barra invertida inicia
sequência de escape. Ela e os dois parênteses precisam de barra na frente, e a
barra tem de ser tratada **primeiro** — senão as barras que o escape dos
parênteses introduz seriam escapadas de novo.

Essa operação de três linhas estava escrita **cinco vezes** no `PL_FPDF.pkb`, e
**três estavam erradas**:

    replace(replace(replace(p, '\\\\', '\\\\\\\\'), '(', '\\('), ')', '\\)')
                              ^^^^^^  ^^^^^^^^^^

Em PL/SQL não há escape em literal: `'\\\\'` são **duas** barras e `'\\\\\\\\'` são
**quatro**. Aquilo procura duas barras e troca por quatro — e uma barra
sozinha, que é o caso comum (`C:\\temp\\arq.pdf`), passava intacta para o
arquivo. O comentário dizia "Add \\ before \\, ( and )": a intenção estava certa.

Pegava a API pública `Text` e os metadados do documento — título, autor,
assunto, palavras-chave, criador — que passam pelo `p_textstring`.

As duas formas conviviam no mesmo arquivo, a certa em `Cell` e em
`ovl_escape`, a errada nas outras três. Ninguém as viu lado a lado até alguém
percorrer o arquivo procurando por escape.

O que este script cobra
-----------------------
Que exista **uma** implementação (`p_escapa_pdf`) e que nenhuma outra linha
monte o escape à mão. Não é questão de estilo: é que a mesma coisa escrita em
cinco lugares diverge, e a versão errada não faz barulho — o PDF continua
abrindo, e só o texto com barra sai trocado.

Uso:  python dev/scripts/plsql_lint/check_escape_pdf.py src/PL_FPDF.pkb
"""
import io
import re
import sys

CANONICA = 'p_escapa_pdf'

# Qualquer replace que ponha barra na frente de '(' ou ')' — a assinatura da
# operação, escrita de qualquer jeito.
ADHOC = re.compile(r"""replace\s*\(.*?['"]\\\(['"]""", re.I | re.S)

# A forma errada, especificamente: procura por duas barras.
ERRADA = re.compile(r"""replace\s*\([^,]+,\s*'\\\\'\s*,\s*'\\\\\\\\'""", re.I)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    problemas = []
    total_canonica = 0

    for caminho in argv[1:]:
        texto = io.open(caminho, encoding='utf-8', errors='replace').read()
        linhas = texto.splitlines()

        # onde a canônica é DEFINIDA — a única linha autorizada a escapar
        definicao = None
        for n, l in enumerate(linhas, 1):
            if re.match(r'\s*function\s+' + CANONICA + r'\b', l, re.I):
                definicao = n
        if definicao is None and CANONICA in texto:
            problemas.append(f'{caminho}: usa {CANONICA} mas não a define')

        for n, l in enumerate(linhas, 1):
            if l.strip().startswith('--'):
                continue
            if ERRADA.search(l):
                problemas.append(
                    f"{caminho}:{n}: escape ERRADO — procura DUAS barras "
                    f"('\\\\') e troca por quatro. Uma barra sozinha passa "
                    f"intacta.\n      {l.strip()[:90]}")
            elif ADHOC.search(l) and not (definicao and
                                          definicao <= n <= definicao + 4):
                problemas.append(
                    f'{caminho}:{n}: escape de string PDF montado à mão. '
                    f'Chame {CANONICA}.\n      {l.strip()[:90]}')
            elif CANONICA + '(' in l:
                total_canonica += 1

    if problemas:
        print(f'{len(problemas)} problema(s) no escape de string PDF:')
        for p in problemas:
            print('  ' + p)
        return 1

    print(f'OK — uma só rotina escapa string de PDF ({CANONICA}), '
          f'com {total_canonica} chamada(s)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
