# -*- coding: utf-8 -*-
"""
Monta `dist/pl_fpdf_install.sql`: um arquivo, e nada mais para instalar.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
Até aqui, instalar exigia **clonar o repositório**: o antigo `deploy_all.sql`
usava `@@src/...`, que só resolve com a árvore ao lado. Quem só quer usar a
biblioteca tinha de baixar tudo — testes, referências em Python, o site — para
executar quatro arquivos na ordem certa. Este arquivo substituiu aquele.

O resultado é um `.sql` autocontido: baixa, abre na SQL Window ou no SQL*Plus,
executa. Os quatro fontes entram já na ordem de dependência, cada um terminado
pelo `/` que o SQL exige.

O arquivo NÃO usa `PROMPT` nem `SHOW ERRORS`: são comandos do SQL*Plus, e a SQL
Window do PL/SQL Developer — que é onde este projeto exige que tudo rode — para
neles. A conferência final é um `SELECT` sobre `user_objects`, que roda em
qualquer ferramenta e mostra o mesmo: quem ficou `INVALID`.

A ordem NÃO é detalhe: o `PL_FPDF` chama o `PL_FPDF_UTIL`, e instalar ao
contrário deixa o primeiro inválido até o segundo existir.

O arquivo é versionado no Git de propósito — é ele que se baixa por link direto
do GitHub, sem release nem clone. Por isso o CI confere se está atualizado, do
mesmo jeito que confere o `run_all_tests.sql` e a referência da API.

Uso:
    python dev/scripts/build_release.py            # gera
    python dev/scripts/build_release.py --check    # só confere se está em dia
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, 'dist', 'pl_fpdf_install.sql')

# ordem de dependência: o utilitário primeiro
FONTES = [
    ('src/PL_FPDF_UTIL.pks', 'PACKAGE PL_FPDF_UTIL',
     'utilitário: QR Code, códigos de barras, DEFLATE e criptografia'),
    ('src/PL_FPDF_UTIL.pkb', 'PACKAGE BODY PL_FPDF_UTIL', None),
    ('src/PL_FPDF.pks', 'PACKAGE PL_FPDF',
     'a biblioteca de PDF'),
    ('src/PL_FPDF.pkb', 'PACKAGE BODY PL_FPDF', None),
]


def versao():
    """A versão declarada na spec — o `co_version`, que é a fonte da verdade."""
    spec = io.open(os.path.join(RAIZ, 'src', 'PL_FPDF.pks'),
                   encoding='utf-8').read()
    m = re.search(r"co_version\s+CONSTANT\s+VARCHAR2\(\d+\)\s*:=\s*'([^']+)'",
                  spec, re.I)
    if not m:
        raise SystemExit('não achei co_version em src/PL_FPDF.pks')
    return m.group(1)


def montar():
    v = versao()
    partes = [f"""--------------------------------------------------------------------------------
-- PL_FPDF {v} — instalação completa
--
-- Gerado por dev/scripts/build_release.py. NÃO EDITE ESTE ARQUIVO: mexa em
-- src/ e gere de novo.
--
-- Como usar: abra na SQL Window do PL/SQL Developer e execute (F8), ou rode no
-- SQL*Plus / SQLcl com @pl_fpdf_install.sql. Não cria tabela, sequência nem
-- diretório — só os dois packages.
--
-- Só há SQL aqui: nenhum comando de SQL*Plus, para o arquivo rodar igual em
-- qualquer ferramenta. O SELECT do fim diz se ficou tudo VALID.
--
-- Requisitos: Oracle 19c ou superior. Nenhuma dependência externa — nem para
-- criptografia (MD5 e SHA saem do STANDARD_HASH; RC4 e AES são implementados
-- no próprio package).
--
-- Licença MIT. https://github.com/Maxwbh/pl_fpdf
--------------------------------------------------------------------------------
"""]
    for caminho, objeto, nota in FONTES:
        texto = io.open(os.path.join(RAIZ, caminho), encoding='utf-8').read()
        # o arquivo já termina com '/' na própria linha; mantém como está
        if not re.search(r'\n/\s*$', texto):
            raise SystemExit(f'{caminho}: esperava terminar com / na própria '
                             f'linha, que é o que faz o SQL*Plus compilar')
        # '&' seguido de letra é variável de substituição no SQL*Plus: o script
        # PARA e pede um valor, e o instalador vira entrada interativa. O
        # SQL*Plus varre até comentário e literal, então não há esconderijo.
        for n, linha in enumerate(texto.splitlines(), 1):
            if re.search(r'&[A-Za-z]', linha):
                raise SystemExit(
                    f'{caminho}:{n}: "&" seguido de letra vira variável de '
                    f'substituição no SQL*Plus e trava a instalação. Parta a '
                    f"string: '&' || 'gt;'\n  {linha.strip()}")
        cabeca = f'-- {objeto}'
        if nota:
            cabeca += f' — {nota}'
        partes.append('\n'
                      '----------------------------------------'
                      '----------------------------------------\n'
                      f'{cabeca}\n'
                      '----------------------------------------'
                      '----------------------------------------\n')
        partes.append(texto.rstrip() + '\n')

    partes.append("""
----------------------------------------------------------------------------
-- Conferência: os quatro objetos precisam sair VALID.
----------------------------------------------------------------------------
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
 ORDER BY object_name, object_type;
""")
    return ''.join(partes)


def main():
    novo = montar()
    checar = '--check' in sys.argv
    atual = io.open(SAIDA, encoding='utf-8').read() if os.path.exists(SAIDA) \
        else None

    if checar:
        if atual == novo:
            print(f'dist/pl_fpdf_install.sql está atualizado '
                  f'({len(novo.splitlines())} linhas)')
            return 0
        print('dist/pl_fpdf_install.sql está DESATUALIZADO em relação a src/.')
        print('Rode: python dev/scripts/build_release.py')
        return 1

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    io.open(SAIDA, 'w', encoding='utf-8').write(novo)
    print(f'dist/pl_fpdf_install.sql: {len(novo.splitlines())} linhas, '
          f'{len(novo.encode("utf-8")) // 1024} KB (versão {versao()})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
