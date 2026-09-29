# -*- coding: utf-8 -*-
"""
Monta os dois packages da issue 16 do projeto de origem, e o patch para lá.

DOCUMENTO DE MANUTENÇÃO. Nada aqui vai para quem usa a biblioteca.

A issue 16 (`Pilooz/pl_fpdf`) relata `ORA-29275` na primeira chamada, num banco
AL32UTF8. O conserto é de LÁ, na 2.0.0, e o que se valida aqui é justamente
isso: que o defeito existe nesta instância e que o conserto o fecha.

**A fonte é a tag `2.0.0` deste repositório**, lida pelo Git — não há cópia da
2.0.0 versionada aqui, que envelheceria em silêncio.

Saem daqui duas coisas:

1. `--patch`: o diff unificado contra o `PL_FPDF.pkb` da 2.0.0, que é o que se
   leva para o projeto de origem;
2. sem argumento: quatro arquivos em `build/`, com o package RENOMEADO para
   `PL_FPDF_I16_ANTES` e `PL_FPDF_I16_DEPOIS`. O nome é o ponto: instalar a
   2.0.0 como `PL_FPDF` derrubaria a 3.4.0 do schema, e ninguém quer descobrir
   isso depois.

O conserto é descrito uma vez só, em `consertar()`, e as duas saídas vêm dele.
Manter o patch à mão, ao lado do código que ele altera, é como as duas versões
divergem.
"""
import io
import os
import re
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
BUILD = os.path.join(AQUI, 'build')
TAG = '2.0.0'
CR = '\r\n'


def fonte(arquivo, base=TAG):
    """O arquivo como ele está na referência dada, com as quebras intactas.

    A referência padrão é a tag `2.0.0`, que é a mesma da origem. `--base`
    troca -- e o caso que importa é `origin/upstream-fix-2.0.0`, a branch de
    onde o PR sai: validar o que VAI subir vale mais do que validar um primo
    dele.

    Sem decodificar pelo Python: a 2.0.0 é CRLF de ponta a ponta, e deixar a
    normalização acontecer faria o patch trocar as 5.599 linhas do arquivo.
    """
    bruto = subprocess.run(['git', '-C', RAIZ, 'show', f'{base}:{arquivo}'],
                           capture_output=True, check=True).stdout
    return bruto.decode('utf-8')


def crlf(texto):
    return texto.replace('\n', CR)


AUXILIARES = crlf("""----------------------------------------------------------------------------------
-- Character-width tables: keyed by the WinAnsi BYTE, and never by CHR.
--
-- CHR(n) does not return "the character at position n": it returns the
-- character whose BYTE is n in the DATABASE character set. On a single-byte
-- database (WE8MSWIN1252, WE8ISO8859P1) every value from 0 to 255 is a valid
-- one-byte character, so the tables below built fine and this package always
-- worked. On AL32UTF8 they do not: 128-191 are UTF-8 continuation bytes, and
-- from 192 on the byte opens a multi-byte sequence that never completes --
-- ORA-29275, "partial multibyte character", raised while loading the metrics
-- of the very first font, which is why it shows up on the first AddPage.
--
-- UTL_RAW.CAST_TO_VARCHAR2 does not validate the character set, so the byte
-- survives on any database, and it is ONE byte, which fits `car`.
----------------------------------------------------------------------------------
function winAnsiKey(pbyte in pls_integer) return varchar2 is
begin
\treturn utl_raw.cast_to_varchar2(hextoraw(to_char(pbyte, 'FM0X')));
end winAnsiKey;

----------------------------------------------------------------------------------
-- The width of ONE character, in the table of the current font.
--
-- The table is keyed by the WinAnsi byte -- the encoding the font dictionary
-- declares -- and whoever measures text holds a CHARACTER. This is the
-- conversion, and it was missing: taking SUBSTR straight from the text and
-- looking it up works only while the text is ASCII. On AL32UTF8 an accented
-- character is TWO bytes, the key does not exist, and the lookup raises
-- NO_DATA_FOUND on the first accented word.
--
-- A character with no place in WinAnsi has no glyph in the standard fonts
-- either, so it measures 0 instead of raising.
----------------------------------------------------------------------------------
function charWidth(pcw in charSet, pchar in varchar2) return pls_integer is
\tk car;
begin
\tk := convert(pchar, 'WE8MSWIN1252');
\tif (pcw.exists(k)) then
\t\treturn pcw(k);
\tend if;
\treturn 0;
end charWidth;

""")


def pre_requisitos(corpo):
    """O mínimo para a 2.0.0 COMPILAR, aplicado às duas versões.

    Medido no banco: a 2.0.0 como está na tag não compila. O body redeclara
    duas constantes que a spec já declara, e o Oracle recusa com

        PLS-00371: at most one declaration for 'CO_PL_FPDF_VERSION' is permitted

    Sem isto não há ANTES para comparar, e o validador mediria o nada. Entra
    nas DUAS versões de propósito: o que se quer isolar é o conserto da issue
    16, e diferença que aparece nos dois lados não polui a comparação.

    Some a declaração do BODY, não a da spec: a spec é a interface publicada, e
    é dela que sai o `co_fpdf_version` de verdade -- '1.53', a versão do FPDF
    original, que a cópia do body tinha trocado por '2.0.0'.

    Isto NÃO entra no patch da issue 16: lá é outro assunto, e já existe
    trabalho separado sobre ele.
    """
    de = crlf(" co_fpdf_version CONSTANT VARCHAR2(10) := '2.0.0';\n"
              " co_pl_fpdf_version CONSTANT VARCHAR2(10) := '2.0.0';")
    para = crlf(" -- as duas constantes vivem na spec, e o body as herda;"
                " redeclarar aqui\n"
                " -- e PLS-00371, e a 2.0.0 nao compila por causa disto")
    if corpo.count(de) == 0:
        return corpo        # esta base ja corrigiu -- e o caso da upstream-fix
    if corpo.count(de) != 1:
        raise SystemExit('a 2.0.0 mudou: nao achei as constantes duplicadas')
    return corpo.replace(de, para)


def consertar(corpo):
    """O conserto da issue 16, aplicado ao `PL_FPDF.pkb` da 2.0.0.

    São TRÊS defeitos, e o relato alcança só o primeiro. Consertar apenas ele
    faria o erro andar do `AddPage` para o `Output`, na mesma rodada.
    """
    trocas = 0

    def troca(de, para, vezes=1):
        nonlocal corpo, trocas
        if corpo.count(de) != vezes:
            raise SystemExit(f'a 2.0.0 mudou: esperava {vezes} ocorrência(s) '
                             f'de {de[:60]!r}, achei {corpo.count(de)}')
        corpo = corpo.replace(de, para)
        trocas += vezes

    # 1. os auxiliares, antes da primeira tabela de fonte
    banner = CR.join(['-' * 82, '-- Setting metric for courier Font', '-' * 82])
    troca(banner, AUXILIARES + banner)

    # 2. as tabelas: a chave deixa de vir do CHR
    n_tab = len(re.findall(r'mySet\(chr\(', corpo))
    if n_tab == 0:
        raise SystemExit('a 2.0.0 mudou: nenhuma entrada mySet(chr( encontrada')
    corpo = re.sub(r'mySet\(chr\(', 'mySet(winAnsiKey(', corpo)
    trocas += n_tab

    # 3. o /Widths do dicionário da fonte, que tem o MESMO chr(i) de 32 a 255:
    #    sem isto o erro apenas troca de lugar, e passa a estourar no Output
    troca("\t\t\t\ts := s || cw(chr(i)) || ' ';",
          "\t\t\t\ts := s || cw(winAnsiKey(i)) || ' ';")

    # 4. GetStringWidth: a variável de UM BYTE some, e a consulta passa pelo
    #    charWidth. O `.exists` comentado voltava como NO_DATA_FOUND
    troca(crlf("""function GetStringWidth(pstr in varchar2) return number is
charSetWidth CharSet;
w number;
lg number;
wdth number;
c car;
begin"""),
          crlf("""function GetStringWidth(pstr in varchar2) return number is
charSetWidth CharSet;
w number;
lg number;
wdth number;
begin"""))
    troca(crlf("""\t\tc := substr(pstr,i,1);
\t    --if (charSetWidth.exists(c)) then
\t\t  wdth := charSetWidth(c);
\t\t--end if;
\t\tw:= w + wdth;"""),
          crlf("""\t\t-- NOT into a `car` variable: that subtype holds ONE BYTE, and on
\t\t-- AL32UTF8 an accented character has two, so the assignment itself
\t\t-- raised ORA-06502 before the table was ever reached.
\t\twdth := charWidth(charSetWidth, substr(pstr,i,1));
\t\tw:= w + wdth;"""))

    # 5. MultiCell e Write mediam com o caractere cru
    troca("\t\t\tl := l + charSetWidth (carac);",
          "\t\t\tl := l + charWidth(charSetWidth, carac);")
    troca("         lsep := lsep + charSetWidth(c);",
          "         lsep := lsep + charWidth(charSetWidth, c);")
    troca("\t\t\tl := l + charSetWidth(c);",
          "\t\t\tl := l + charWidth(charSetWidth, c);")

    return corpo, trocas


def renomear(texto, novo):
    """Troca o nome do package -- só onde ele é ESTRUTURA, não no comentário.

    São três pontos: o CREATE da spec, o CREATE do body (que tem um bando de
    espaços no meio, e vem assim da origem) e o END de cada um.
    """
    texto = re.sub(r'(create or replace\s+PACKAGE\s+BODY\s+)PL_FPDF(\s+AS)',
                   rf'\1{novo}\2', texto, flags=re.I)
    texto = re.sub(r'(create or replace\s+PACKAGE\s+)PL_FPDF(\s+AS)',
                   rf'\1{novo}\2', texto, flags=re.I)
    texto = re.sub(r'(?m)^(END\s+)PL_FPDF(;)', rf'\1{novo}\2', texto,
                   flags=re.I)
    return texto


def main():
    base = TAG
    if '--base' in sys.argv:
        base = sys.argv[sys.argv.index('--base') + 1]
    print(f'base: {base}')
    spec = fonte('PL_FPDF.pks', base)
    # o pre-requisito vale para as DUAS versoes; o patch para a origem sai do
    # corpo ORIGINAL, que e o que eles tem la
    original = fonte('PL_FPDF.pkb', base)
    corpo = pre_requisitos(original)
    consertado, trocas = consertar(corpo)

    if '--patch' in sys.argv:
        import difflib
        destino = os.path.join(AQUI, 'fix16.patch')
        # o diff e contra o arquivo da origem, SEM o pre-requisito: la o
        # PLS-00371 e outro assunto, e misturar os dois num patch so faria o
        # revisor ter de separar
        so_issue16, _ = consertar(original)
        diff = difflib.unified_diff(
            original.splitlines(keepends=True),
            so_issue16.splitlines(keepends=True),
            fromfile='PL_FPDF.pkb', tofile='PL_FPDF.pkb')
        io.open(destino, 'w', encoding='utf-8', newline='').writelines(diff)
        print(f'{destino}: patch com {trocas} troca(s)')
        return 0

    os.makedirs(BUILD, exist_ok=True)
    for rotulo, texto_corpo in (('ANTES', corpo), ('DEPOIS', consertado)):
        nome = f'PL_FPDF_I16_{rotulo}'
        for ext, texto in (('pks', spec), ('pkb', texto_corpo)):
            caminho = os.path.join(BUILD, f'{nome}.{ext}')
            io.open(caminho, 'w', encoding='utf-8', newline='').write(
                renomear(texto, nome))
            print(f'   {caminho}')
    print(f'ok: {trocas} troca(s) no corpo consertado')
    return 0


if __name__ == '__main__':
    sys.exit(main())
