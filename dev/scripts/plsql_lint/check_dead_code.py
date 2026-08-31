# -*- coding: utf-8 -*-
"""
Acha o que o package declara e ninguém usa.

Por que existe
-------------
O body passou de 13 mil linhas por acréscimo, e acréscimo deixa restos: rotina
que foi substituída e continuou compilando, constante de uma tabela que mudou de
forma, variável global de um desenho que foi refeito. Nada disso quebra — e é
justamente por isso que fica. O custo aparece depois, em quem lê o arquivo
procurando entender qual das duas rotinas parecidas é a que vale.

O que ele NÃO propõe apagar
---------------------------
Tudo que está na spec é API pública: sumiu, quebra chamador. Este verificador
ignora a spec de propósito e olha só o que é privado do body.

Falsos positivos que ele evita
------------------------------
- **Declaração antecipada não é uso.** O bloco de forward declarations do início
  do body cita quase todo mundo; contá-lo faria o verificador achar que nada é
  morto. As linhas antes do primeiro corpo são descartadas.
- **O próprio cabeçalho e o `END nome;`** não contam como uso.
- **Recursão não é uso.** Uma rotina que só chama a si mesma continua morta.
- **Sobrecarga.** Dois subprogramas com o mesmo nome contam como um só: uma
  chamada mantém os dois vivos, porque daqui não dá para saber qual foi.
- **Chamada montada em texto.** `buildPlsqlStatment` monta chamadas por nome em
  tempo de execução; qualquer identificador que apareça dentro de literal de
  string é considerado usado.
- **Subprograma aninhado.** Os declarados dentro de outro (indentados) não são
  avaliados: eles vivem no escopo de quem os contém, e o compilador já avisa
  quando um deles não é usado. O que importa aqui é não parti-los fora do dono.

Uso:  python scripts/plsql_lint/check_dead_code.py src/PL_FPDF.pks src/PL_FPDF.pkb
"""
import io
import re
import sys

# Coluna zero, sem tolerância de indentação: é o que separa o subprograma de
# NÍVEL DE PACKAGE do aninhado. Os outros lints usam `[ \t]{0,2}` porque para
# eles tanto faz; aqui não — tratar um `PROCEDURE carrega` aninhado como se
# fosse de package parte o corpo de quem o contém em dois, e aí quem o chama
# fica noutro bloco e ele aparece como morto. Aconteceu na primeira rodada,
# com dez falsos positivos.
CABECALHO = re.compile(r'^(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9$#]*)',
                       re.I | re.M)
SPEC_SUB = re.compile(r'^\s*(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9$#]*)',
                      re.I | re.M)
FIM = re.compile(r'\bend\s+([a-z_][a-z_0-9$#]*)\s*;', re.I)
IDENT = re.compile(r'(?<![.\w$#])([a-z_][a-z_0-9$#]*)', re.I)

# Declarações de nível de package: constantes, variáveis e tipos.
DECL_CONST = re.compile(
    r'^\s*([a-z_][a-z_0-9$#]*)\s+CONSTANT\b', re.I | re.M)
DECL_VAR = re.compile(
    r'^\s*(g_[a-z_0-9$#]*)\s+(?!CONSTANT)[a-z]', re.I | re.M)
DECL_TIPO = re.compile(r'^\s*TYPE\s+([a-z_][a-z_0-9$#]*)\s+IS\b', re.I | re.M)


def sem_comentario(texto):
    """Comentário virando espaço, MANTENDO o tamanho e as quebras de linha.

    Preservar o comprimento importa porque as posições achadas aqui são usadas
    para fatiar o texto original. E apagar comentário antes de procurar
    subprograma não é detalhe: há uma `function getImageFromDatabase` inteira
    dentro de um `/* */` no meio do arquivo, e a primeira versão deste
    verificador a listou como código morto — estava certa quanto ao morto e
    errada quanto ao código.

    Literais de string ficam INTACTOS de propósito: `buildPlsqlStatment` monta
    chamadas por nome em tempo de execução, e o nome só aparece dentro de uma
    string.
    """
    def branco(m):
        return re.sub(r'[^\n]', ' ', m.group(0))
    texto = re.sub(r'/\*.*?\*/', branco, texto, flags=re.S)
    texto = re.sub(r'--[^\n]*', branco, texto)
    return texto


def corpos(body):
    """[(nome, inicio, fim)] dos subprogramas de nível de package, na ordem.

    Recebe o texto já sem comentários — ver sem_comentario().
    """
    marcas = [(m.start(), m.group(1).lower()) for m in CABECALHO.finditer(body)]
    saida = []
    for i, (ini, nome) in enumerate(marcas):
        fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(body)
        saida.append((nome, ini, fim))
    return saida


def usos(body, blocos):
    """{identificador: quantas vezes aparece fora do próprio dono}."""
    conta = {}
    for nome, ini, fim in blocos:
        trecho = body[ini:fim]
        # tira o cabeçalho da própria rotina e os 'END nome;'
        trecho = CABECALHO.sub(' ', trecho, count=1)
        trecho = FIM.sub(' ', trecho)
        vistos = {}
        for m in IDENT.finditer(trecho):
            ident = m.group(1).lower()
            vistos[ident] = vistos.get(ident, 0) + 1
        for ident, n in vistos.items():
            if ident == nome:          # recursão não mantém ninguém vivo
                continue
            conta[ident] = conta.get(ident, 0) + n
    return conta


def declaracoes_globais(body, primeiro_corpo):
    """Constantes, variáveis e tipos declarados antes do primeiro subprograma."""
    cab = body[:primeiro_corpo]
    return ({m.group(1).lower() for m in DECL_CONST.finditer(cab)},
            {m.group(1).lower() for m in DECL_VAR.finditer(cab)},
            {m.group(1).lower() for m in DECL_TIPO.finditer(cab)})


def main(caminho_spec, caminho_body):
    spec = sem_comentario(io.open(caminho_spec, encoding='utf-8').read())
    body = sem_comentario(io.open(caminho_body, encoding='utf-8').read())

    publicos = {m.group(1).lower() for m in SPEC_SUB.finditer(spec)}
    blocos = corpos(body)
    if not blocos:
        print('nenhum subprograma encontrado — verifique o arquivo')
        return 1
    conta = usos(body, blocos)
    consts, vars_, tipos = declaracoes_globais(body, blocos[0][1])

    # a parte declarativa também usa coisas (um tipo usado por outro tipo, uma
    # constante que inicializa outra)
    cab = body[:blocos[0][1]]
    for m in IDENT.finditer(cab):
        ident = m.group(1).lower()
        conta[ident] = conta.get(ident, 0) + 1

    privados = []
    vistos = set()
    for nome, _, _ in blocos:
        if nome in vistos or nome in publicos:
            continue
        vistos.add(nome)
        # a declaração no cabeçalho conta 1 por si; exigir > esse piso
        if conta.get(nome, 0) == 0:
            privados.append(nome)

    def mortos(conjunto, piso):
        return sorted(n for n in conjunto if conta.get(n, 0) <= piso)

    # constantes/variáveis/tipos aparecem 1x na própria declaração
    c_mortas = mortos(consts, 1)
    v_mortas = mortos(vars_, 1)
    t_mortos = mortos(tipos, 1)

    achados = (len(privados) + len(c_mortas) + len(v_mortas) + len(t_mortos))
    if achados:
        print(f'{caminho_body}: {achados} declaração(ões) sem uso:')
        for rotulo, lista in (('subprograma privado', privados),
                              ('constante', c_mortas),
                              ('variável global', v_mortas),
                              ('tipo', t_mortos)):
            for n in lista:
                print(f'  {rotulo:<20} {n}')
        return 1

    print(f'{caminho_body}: OK — nada declarado sem uso '
          f'({len(vistos)} subprogramas privados, {len(consts)} constantes, '
          f'{len(vars_)} globais, {len(tipos)} tipos)')
    return 0


if __name__ == '__main__':
    a = sys.argv[1:] or ['src/PL_FPDF.pks', 'src/PL_FPDF.pkb']
    sys.exit(main(a[0], a[1]))
