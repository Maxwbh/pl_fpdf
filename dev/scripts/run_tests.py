# -*- coding: utf-8 -*-
"""
Compila o PL_FPDF no banco, roda a suíte e valida os PDFs gerados com
decodificadores reais.

Por que existe
-------------
Os testes PL/SQL conferem o desenho *indiretamente*: contam os retângulos
(`re f`) que o QR Code e os códigos de barras emitem no fluxo do PDF. Isso pega
regressão, mas não prova que um leitor consegue ler o símbolo. Este runner
fecha o ciclo: traz o BLOB do banco, abre com o MuPDF e **decodifica** o QR e o
código de barras com o zxing-cpp, comparando com o conteúdo original.

Também elimina a confusão de compilação que aparecia a cada rodada: instala a
spec e o body na ordem certa, consulta `USER_ERRORS` e só então executa —
e reconecta antes dos testes, porque o PL_FPDF tem estado de package e uma
sessão que já o carregou falha com ORA-04068/ORA-06508 depois de recompilar.

Os exemplos de `examples/*.sql` são **carregados e executados** por este
runner, e não copiados para dentro dele: o arquivo publicado é o mesmo que roda
contra o banco. Duas cópias do mesmo desenho já divergiram uma vez.

O que este runner NÃO cobre: regra de cobrança. Montar o código de barras a
partir de banco, vencimento e valor é assunto de outro projeto — aqui se
verifica DESENHO, e os 44 dígitos do boleto entram prontos, como qualquer outro
dado que o chamador passa.

Uso
---
    pip install -r dev/scripts/requirements.txt

    # credenciais por argumento ou pelas variáveis PLFPDF_USER/PASSWORD/DSN
    python dev/scripts/run_tests.py --dsn devimesclaudo_high --user MEU_USER

    python dev/scripts/run_tests.py --compile          # só instala e checa erros
    python dev/scripts/run_tests.py --tests            # só roda a suíte
    python dev/scripts/run_tests.py --validate         # só valida os PDFs gerados
    python dev/scripts/run_tests.py --out dev/amostras # onde salvar os PDFs

Progresso entre rodadas
-----------------------
Rodar tudo a cada mexida custa minutos e esconde a etapa que interessa no meio
do que já passava. As etapas concluídas ficam registradas em
`.plfpdf_estado.json` e são puladas na rodada seguinte.

Pular não é "passou uma vez" — é "passou uma vez **e** nada de que essa etapa
depende mudou desde então". Cada etapa guarda a impressão digital das suas
entradas, e o package é olhado subprograma a subprograma: mexer no corpo de
alguns preserva o progresso, mas mudança **profunda** zera tudo, porque aí
qualquer etapa pode ter regredido — a spec mudou, a parte declarativa do body
mudou, um subprograma foi criado ou removido, ou muitos foram alterados.

    python dev/scripts/run_tests.py --status           # o que está concluído
    python dev/scripts/run_tests.py --reset            # zera e roda do zero
    python dev/scripts/run_tests.py --full             # roda tudo sem zerar

Para o Autonomous Database, aponte TNS_ADMIN (ou --wallet) para o diretório do
wallet; o alias (`devimesclaudo_high`) vem do tnsnames.ora.
"""
import argparse
import datetime
import getpass
import glob
import io
import os
import re
import sys

# Tudo ancorado na RAIZ do repositorio, calculada a partir deste arquivo, e
# nao no diretorio de onde se chamou. Caminho relativo ao CWD funciona enquanto
# todo mundo roda da raiz e quebra no primeiro que nao roda — foi o que
# aconteceu: 'examples/boleto.sql' nao existe se voce chamar o runner de dentro
# de dev/scripts. O erro sai como FileNotFoundError no meio da lista de
# amostras, longe da causa.
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def do_repo(*partes):
    return os.path.join(RAIZ, *partes)


PKS = do_repo('src', 'PL_FPDF.pks')
PKB = do_repo('src', 'PL_FPDF.pkb')
# O utilitario vem PRIMEIRO: o PL_FPDF o chama. Instalar ao contrario deixa o
# PL_FPDF invalido ate o utilitario existir.
UTIL_PKS = do_repo('src', 'PL_FPDF_UTIL.pks')
UTIL_PKB = do_repo('src', 'PL_FPDF_UTIL.pkb')
FONTES = (UTIL_PKS, UTIL_PKB, PKS, PKB)
OBJETOS = ('PL_FPDF_UTIL', 'PL_FPDF')


# ────────────────────────────── conexão ──────────────────────────────────────
def conectar(args):
    import oracledb
    if args.wallet:
        os.environ['TNS_ADMIN'] = args.wallet
    senha = args.password or os.environ.get('PLFPDF_PASSWORD')
    if not senha:
        senha = getpass.getpass(f'Senha de {args.user}@{args.dsn}: ')
    return oracledb.connect(user=args.user, password=senha, dsn=args.dsn,
                            config_dir=os.environ.get('TNS_ADMIN'))


LOTE_SAIDA = 100


def saida_do_servidor(con):
    """Lê o que o bloco escreveu com DBMS_OUTPUT.

    get_lines recebe um array PL/SQL (DBMSOUTPUT_LINESARRAY), não um var
    escalar: é preciso cursor.arrayvar, senão o Oracle recusa a chamada com
    PLS-00306 ('wrong number or types of arguments').
    """
    linhas = []
    with con.cursor() as cur:
        lote = cur.arrayvar(str, LOTE_SAIDA, 32767)
        n = cur.var(int)
        while True:
            n.setvalue(0, LOTE_SAIDA)
            cur.callproc('dbms_output.get_lines', (lote, n))
            qtd = n.getvalue()
            linhas.extend(lote.getvalue()[:qtd])
            if qtd < LOTE_SAIDA:
                break
    return [l if l is not None else '' for l in linhas]


# ────────────────────────────── compilação ───────────────────────────────────
def compilar(con):
    """Instala os dois packages, na ordem, e devolve os erros de USER_ERRORS."""
    print('== Compilando')
    for caminho in FONTES:
        fonte = io.open(caminho, encoding='utf-8').read()
        # o arquivo termina com '/' na própria linha; o driver não o aceita
        fonte = re.sub(r'\n/\s*$', '', fonte.rstrip())
        with con.cursor() as cur:
            cur.execute(fonte)
        print(f'   {caminho}: enviado')

    erros = []
    with con.cursor() as cur:
        cur.execute("""
            SELECT name, type, line, position, text
              FROM user_errors
             WHERE name IN ('PL_FPDF', 'PL_FPDF_UTIL')
             ORDER BY name, type, sequence""")
        for nome, tipo, linha, pos, texto in cur:
            erros.append((f'{nome} {tipo}', linha, pos, texto.strip()))

    if erros:
        print(f'   {len(erros)} erro(s) de compilação:')
        for onde, linha, pos, texto in erros[:40]:
            # a linha e a da fonte ARMAZENADA, que comeca no CREATE: some o
            # cabecalho de comentario do arquivo. Sem o nome do objeto, com
            # dois packages, nao da para saber nem em qual arquivo procurar.
            print(f'     {onde} {linha}:{pos}  {texto}')
        if len(erros) > 40:
            print(f'     ... e mais {len(erros) - 40}')
    else:
        print('   sem erros de compilação')
    return erros


# ──────────────────────────────── testes ─────────────────────────────────────
def blocos_do_arquivo(caminho):
    """Blocos anônimos de um arquivo de teste, separados por '/' na própria linha.

    Descarta os pedaços que só têm comentário — vários arquivos terminam com um
    rodapé comentado depois do último '/', e mandá-lo ao banco daria ORA-00900.
    """
    texto = io.open(caminho, encoding='utf-8').read()
    blocos = []
    for parte in re.split(r'^/\s*$', texto, flags=re.M):
        sem_comentario = re.sub(r'--[^\n]*', '', parte)
        sem_comentario = re.sub(r'/\*.*?\*/', '', sem_comentario, flags=re.S)
        if sem_comentario.strip():
            blocos.append(parte.strip())
    return blocos


def rodar_testes(con, arquivos, verboso=False):
    """Executa a suíte. Por padrão mostra uma linha por arquivo; o detalhe só
    aparece com --verbose ou quando o arquivo tem falha."""
    print('\n== Suíte de testes')
    total = {'PASS': 0, 'FAIL': 0, 'SKIP': 0}
    falhas = []
    situacao = {}          # basename => passou?
    for caminho in arquivos:
        nome = os.path.basename(caminho)
        linhas_arq, do_arq = [], {'PASS': 0, 'FAIL': 0, 'SKIP': 0}
        for i, bloco in enumerate(blocos_do_arquivo(caminho), 1):
            with con.cursor() as cur:
                cur.callproc('dbms_output.enable', (None,))
                try:
                    cur.execute(bloco)
                except Exception as e:                       # noqa: BLE001
                    msg = str(e).splitlines()[0]
                    do_arq['FAIL'] += 1
                    falhas.append((nome, f'bloco {i} não executou: {msg}'))
                    linhas_arq.append(f'*** bloco {i} não executou: {msg}')
                    continue
            linhas = saida_do_servidor(con)
            linhas_arq.extend(linhas)
            for l in linhas:
                for marca in do_arq:
                    if f'[{marca}]' in l:
                        do_arq[marca] += 1
                if '[FAIL]' in l:
                    falhas.append((nome, l.strip()))

        for marca in total:
            total[marca] += do_arq[marca]
        situacao[nome] = do_arq['FAIL'] == 0
        verif = do_arq['PASS'] + do_arq['FAIL']
        sit = ('FALHA' if do_arq['FAIL'] else 'ok')
        extra = f" | {do_arq['SKIP']} pulado(s)" if do_arq['SKIP'] else ''
        print(f"   {sit:<5} {nome:<34} {do_arq['PASS']}/{verif}{extra}")

        # o detalhe só interessa quando algo falhou (ou se pedirem tudo)
        if verboso or do_arq['FAIL']:
            for l in linhas_arq:
                if verboso or '[FAIL]' in l or l.startswith('***'):
                    print('         ' + l.strip())
    return total, falhas, situacao


# ───────────────────── amostras: gerar no banco e validar ────────────────────
# O título tem parênteses BALANCEADOS de propósito: `(Titulo (2026) final)` é
# uma string só, e a varredura que não conta profundidade cifra só o miolo — o
# leitor decifra a string inteira e mostra lixo.
TITULO_OBJSTM = 'Relatorio (2026) dentro do ObjStm'

# Código de barras de um boleto Itaú de verdade: 44 dígitos, sem verificador de
# simbologia. Ele chega PRONTO, como qualquer outro dado que o chamador passa —
# calcular esses dígitos é regra de cobrança, e regra de cobrança não é assunto
# de uma biblioteca de PDF.
CODIGO_BARRAS_BOLETO = '34197167700000150001090000012323073123451000'


def exemplo(nome):
    """O bloco PL/SQL de `examples/<nome>.sql`, pronto para o runner.

    O exemplo é a FONTE: é o que se publica, o que alguém copia e cola, e é
    exatamente ele que roda contra o banco. Não existe uma segunda cópia do
    desenho aqui dentro para divergir — já divergiu uma vez, quando um conserto
    de posição teve de ser aplicado nos dois lugares e nada garantia que fosse.

    A adaptação é mínima e verificada: tira o cabeçalho de comentário e o `/`
    final, que são do arquivo e não do bloco, e acrescenta UMA linha devolvendo
    o BLOB no bind de saída. Se o exemplo deixar de terminar como se espera, o
    erro estoura aqui, e não numa validação seis passos adiante.
    """
    caminho = do_repo('examples', nome + '.sql')
    texto = io.open(caminho, encoding='utf-8').read()
    corpo = re.sub(r'^(\s*--[^\n]*\n)+', '', texto)      # cabeçalho do arquivo
    corpo = re.sub(r'\n/\s*$', '', corpo.strip())         # o '/' que o SQL exige
    saida = 'l_pdf := PL_FPDF.OutputBlob();'
    if corpo.count(saida) != 1:
        raise SystemExit(f'{caminho}: esperava exatamente um {saida!r} '
                         f'para devolver o PDF ao runner')
    return corpo.replace(saida, saida + '\n  :saida := l_pdf;')


AMOSTRAS = [
    ('simples', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',16);
          FOR i IN 1..3 LOOP
            PL_FPDF.AddPage();
            PL_FPDF.Cell(100,10,'Pagina numero '||i,'1',1);
          END LOOP;
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := l_pdf;
        END;""",
     {'paginas': 3, 'textos': ['Pagina numero 1', 'Pagina numero 2', 'Pagina numero 3']}),

    ('qrcode_pix', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.AddPage();
          PL_FPDF.AddQRCode(20, 20, 80, :conteudo, 'TEXT', 'M');
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := l_pdf;
        END;""",
     {'paginas': 1, 'decodificar': 'QRCode'}),

    ('barcode_code128', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(20, 40, 120, 30, :conteudo, 'CODE128', TRUE);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := l_pdf;
        END;""",
     {'paginas': 1, 'decodificar': 'Code128'}),

    ('barcode_ean13', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.AddPage();
          PL_FPDF.AddBarcode(20, 40, 120, 30, :conteudo, 'EAN13', TRUE);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := l_pdf;
        END;""",
     {'paginas': 1, 'decodificar': 'EAN-13'}),

    ('cifrado', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.AddPage();
          PL_FPDF.Cell(150,10,:conteudo,'0',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := PL_FPDF.EncryptPDF(p_pdf => l_pdf,
                                       p_user_password => 'senha123',
                                       p_encryption => 'RC4-128');
        END;""",
     {'paginas': 1, 'senha': 'senha123', 'textos': ['Conteudo protegido']}),

    # ida e volta: só prova que DecryptPDF decifra de verdade se um leitor
    # externo abrir o resultado SEM senha e ainda achar o texto
    ('decifrado', """
        DECLARE l_pdf BLOB; l_cif BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.AddPage();
          PL_FPDF.Cell(150,10,:conteudo,'0',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          l_cif := PL_FPDF.EncryptPDF(p_pdf => l_pdf,
                                      p_user_password => 'senha123',
                                      p_encryption => 'RC4-128');
          :saida := PL_FPDF.DecryptPDF(l_cif, 'senha123');
        END;""",
     {'paginas': 1, 'sem_senha': True, 'textos': ['Documento decifrado']}),

    ('merge', """
        DECLARE
          l_a BLOB; l_b BLOB;
          FUNCTION doc(p_n PLS_INTEGER, p_tag VARCHAR2) RETURN BLOB IS
          BEGIN
            PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
            FOR i IN 1..p_n LOOP
              PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,p_tag||' '||i,'1',1);
            END LOOP;
            RETURN PL_FPDF.OutputBlob();
          END;
        BEGIN
          PL_FPDF.ClearPDFCache;
          l_a := doc(2,'Alfa'); l_b := doc(3,'Beta');
          PL_FPDF.LoadPDFWithID('a', l_a);
          PL_FPDF.LoadPDFWithID('b', l_b);
          :saida := PL_FPDF.MergePDFs(JSON_ARRAY_T('["a","b"]'), NULL);
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 5, 'textos': ['Alfa 1', 'Alfa 2', 'Beta 1', 'Beta 2', 'Beta 3']}),

    ('extract', """
        DECLARE
          l_a BLOB;
          FUNCTION doc RETURN BLOB IS
          BEGIN
            PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
            FOR i IN 1..5 LOOP
              PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Folha '||i,'1',1);
            END LOOP;
            RETURN PL_FPDF.OutputBlob();
          END;
        BEGIN
          PL_FPDF.ClearPDFCache;
          l_a := doc;
          PL_FPDF.LoadPDFWithID('x', l_a);
          :saida := PL_FPDF.ExtractPages('x', '5,1', NULL);
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 2, 'textos': ['Folha 5', 'Folha 1']}),

    # Marca d'água em duas das três páginas, mais um carimbo opaco só na 2.
    # O que se quer provar é que o desenho SAI no arquivo (era o ORA-20845) e
    # que não vaza para a página que não pediu — no PDF do PL_FPDF todas as
    # páginas compartilham o mesmo /Resources.
    ('marca_dagua', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
          FOR i IN 1..3 LOOP
            PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Folha '||i,'1',1);
          END LOOP;
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;

          PL_FPDF.LoadPDF(l_pdf);
          PL_FPDF.AddWatermark(p_text => :conteudo, p_opacity => 0.3,
                               p_rotation => 45, p_pages => '1,3');
          PL_FPDF.OverlayText(p_page_number => 2, p_text => 'Carimbo da 2',
                              p_x => 72, p_y => 400);
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 3,
      'textos': ['Folha 1', 'Folha 2', 'Folha 3'],
      'so_nas_paginas': {'CONFIDENCIAL': [1, 3], 'Carimbo da 2': [2]}}),

    # Overlay de imagem: o que prova que funcionou é o MuPDF rasterizar o PIXEL
    # certo. Um /DecodeParms errado ou um /ColorSpace trocado produzem um
    # arquivo válido que desenha ruído, e nenhuma checagem estrutural pega isso.
    ('overlay_img', """
        DECLARE
          l_pdf BLOB;
          l_img BLOB := TO_BLOB(:img);
        BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
          FOR i IN 1..2 LOOP
            PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Folha '||i,'1',1);
          END LOOP;
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;

          PL_FPDF.LoadPDF(l_pdf);
          PL_FPDF.OverlayImage(p_page_number => 1, p_image_blob => l_img,
                               p_x => 100, p_y => 500,
                               p_width => 120, p_height => 120);
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 2,
      'textos': ['Folha 1', 'Folha 2'],
      'imagens': {1: 1, 2: 0},
      'pixel': (1, 160, 560, (32, 144, 208))}),

    # Anexar um PNG de verdade: o banner do projeto, 1280x640 e 326 KB.
    #
    # É a única amostra com imagem grande, e por isso a única que exercita o
    # bind como BLOB — acima de 32767 bytes o driver recusa passar como RAW. As
    # outras usam PNG minúsculos, montados no teste, que cabem na via curta e
    # não provam esse caminho.
    ('png_grande', """
        DECLARE l_pdf BLOB; l_img BLOB := :img; BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
          PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Banner do projeto','1',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;

          PL_FPDF.LoadPDF(l_pdf);
          PL_FPDF.OverlayImage(p_page_number => 1, p_image_blob => l_img,
                               p_x => 60, p_y => 420,
                               p_width => 480, p_height => 240);
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1, 'textos': ['Banner do projeto'], 'imagens': {1: 1},
      # o azul-escuro do fundo do banner, no centro da área desenhada —
      # conferido no PNG de origem, em (640, 320) de 1280x640
      'pixel': (1, 300, 540, (13, 25, 44))}),

    # ── documento de complexidade real: um boleto bancário ───────────────────
    #
    # O PL/SQL não está aqui: está em `examples/boleto.sql`, que é o arquivo
    # publicado, e é ELE que o runner carrega e executa. Uma fonte só.
    #
    # A régua também não está aqui: está em `scripts/boleto_reference/`, e é a
    # mesma que o validador aplica ao PDF que sai do banco. Caixa, corpo de
    # fonte, peso, alinhamento e linha de base moram lá. Se o PL/SQL sair da
    # régua, o runner acusa campo a campo.
    #
    # Medidas da ficha de compensação da FEBRABAN: 177 mm de largura,
    # centralizada em A4 (x = 16,5), coluna de valores com 40 mm à direita e
    # código de barras de 103 x 13 mm.
    #
    # Note o que ele NÃO tem: imagem nenhuma. O logotipo de um boleto é
    # desenho vetorial, e é assim que o de verdade é feito.
    ('boleto', exemplo('boleto'),
     {'paginas': 1,
      # uma página só: os textos são todos da página 1
      'textos': [['Recibo do Pagador', 'Ficha de Compensacao',
                  'M&S DO BRASIL LTDA', 'Joao da Silva', '150,00',
                  '31/12/2026', 'Apos o vencimento cobrar multa de 2%']],
      'metadados': {'title': 'Boleto de cobranca 109/00000123-2'},
      'imagens': {1: 0},          # como o de verdade: nenhuma
      'simbolos': {1: [CODIGO_BARRAS_BOLETO]},
      'formatos': {1: ['ITF']},
      # 50 caixas nas duas vias + 114 grupos de barras = 164 're'; 6 réguas de
      # cabeçalho + 44 tracinhos de corte = 50 'l'. Conferido no desenho de
      # referência, que emite exatamente os mesmos operadores.
      'desenhos': {'re': 150, 'l': 45},
      # confere o DESENHO contra a régua: caixa, fonte, corpo, linha de base,
      # alinhamento e empilhamento, campo a campo, nas duas vias
      'layout_boleto': (20.0, 138.0)}),

    # ── ingresso de evento: cor, dois símbolos e duas páginas ────────────────
    #
    # Como o boleto, o PL/SQL vem de `examples/ticket.sql`.
    #
    # O que esta amostra tem e o boleto não: **cor** (faixa preenchida, texto
    # branco sobre ela, painéis cinzas), **QR Code e Code 39 na mesma página**
    # dizendo a mesma coisa, **duas páginas** com participantes diferentes e uma
    # forma que não é retângulo (o rabinho do balão, via `Poly`).
    #
    # A régua está em `scripts/ticket_reference/` e é a mesma que confere o
    # desenho de referência — inclusive a COR de cada texto, que é o defeito
    # que não dá erro nenhum: texto claro sobre fundo claro simplesmente some.
    ('ticket', exemplo('ticket'),
     {'paginas': 2,
      'textos': [['Orquestra Sinfonica', 'Maria Aparecida de Souza',
                  'R$ 120,00', 'UDV2259QK5'],
                 ['Joao Pedro Nogueira', 'PLF7731ZT2']],
      'metadados': {'title': 'Ingressos - Concerto de Gala'},
      'imagens': {1: 0, 2: 0},     # nada de imagem: é tudo desenho
      # cada página tem os DOIS símbolos, e os dois dizem o mesmo
      'simbolos': {1: ['UDV2259QK5'], 2: ['PLF7731ZT2']},
      'formatos': {1: ['QRCode', 'Code39'], 2: ['QRCode', 'Code39']},
      'so_nas_paginas': {'Maria Aparecida de Souza': [1],
                         'Joao Pedro Nogueira': [2]},
      # confere painéis, cor do texto, corpo, linha de base e alinhamento
      'layout_ticket': [('Maria Aparecida de Souza', 'UDV2259QK5'),
                        ('Joao Pedro Nogueira', 'PLF7731ZT2')]}),

    # ── as quatro orientações do Triangle ────────────────────────────────────
    #
    # O `porientation` era aceito e IGNORADO: qualquer valor desenhava a mesma
    # forma, com a ponta para a direita, e a spec já prometia as quatro
    # direções. Quem passasse 'up' recebia um triângulo para a direita, sem
    # erro nenhum — o tipo de defeito que só aparece quando alguém olha o
    # desenho.
    #
    # A amostra desenha as quatro e o validador confere os VÉRTICES de cada
    # uma, não a contagem de operadores: quatro triângulos iguais também
    # emitiriam quatro caminhos de três linhas.
    ('formas', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.AddPage();
          PL_FPDF.SetFillColor(0, 0, 0);
          PL_FPDF.SetFont('Arial','B',12);
          PL_FPDF.SetXY(20, 15); PL_FPDF.Cell(100, 8, 'Triangle', '0', 0, 'L');

          PL_FPDF.Triangle(20,  30, 10, 'right', 'F');
          PL_FPDF.Triangle(60,  30, 10, 'left',  'F');
          PL_FPDF.Triangle(100, 30, 10, 'up',    'F');
          PL_FPDF.Triangle(140, 30, 10, 'down',  'F');

          -- a inicial vale tanto quanto a palavra inteira
          PL_FPDF.Triangle(20,  80, 8, 'U', 'F');
          PL_FPDF.Triangle(60,  80, 8, 'D', 'F');

          :saida := PL_FPDF.OutputBlob();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1,
      'textos': [['Triangle']],
      # (x, y, tamanho, orientação) — os vértices são calculados a partir disso
      'triangulos': [(20.0, 30.0, 10.0, 'right'), (60.0, 30.0, 10.0, 'left'),
                     (100.0, 30.0, 10.0, 'up'), (140.0, 30.0, 10.0, 'down'),
                     (20.0, 80.0, 8.0, 'up'), (60.0, 80.0, 8.0, 'down')]}),

    # ── compressão do fluxo de conteúdo ─────────────────────────────────────
    #
    # `SetCompression(TRUE)` era um NO-OP: perguntava por uma função de zlib que
    # o Oracle não tem e desligava a compressão sempre. Agora o deflate está
    # escrito no próprio package.
    #
    # O fluxo sai deflatado e em HEXADECIMAL, com os dois filtros. O hexadecimal
    # não é enfeite: o documento é montado num CLOB e só vira BLOB no fim, com
    # conversão de charset, e byte binário não sobrevive a isso. Dobra o
    # tamanho do comprimido, e ainda assim o arquivo encolhe muito — o que a
    # amostra mede.
    ('comprimido', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetCompression(TRUE);
          PL_FPDF.SetFont('Arial','',11);
          FOR p IN 1..8 LOOP
            PL_FPDF.AddPage();
            FOR i IN 1..40 LOOP
              PL_FPDF.SetXY(15, 10 + i * 6);
              PL_FPDF.Cell(180, 5,
                'Linha ' || i || ' da pagina ' || p
                || ' - texto repetido para o deflate ter o que casar',
                '0', 0, 'L');
            END LOOP;
          END LOOP;
          :saida := PL_FPDF.OutputBlob();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 8,
      'textos': [['Linha 1 da pagina 1'], ['Linha 1 da pagina 2']],
      # o que prova que a compressão saiu: os dois filtros, na ordem em que o
      # leitor tem de desfazê-los
      'filtros': {1: ['ASCIIHexDecode', 'FlateDecode'],
                  8: ['ASCIIHexDecode', 'FlateDecode']},
      # sem compressão este documento passa de 90 KB; com ela fica em ~12 KB.
      # O teto pega o caso em que o filtro é declarado mas nada foi comprimido
      'tamanho_max': 40000}),

    # ── PDF 1.5+: xref em stream e object streams ────────────────────────────
    # Estas duas amostras são as únicas que partem de um PDF que o package NÃO
    # gerou: o PL_FPDF grava xref clássica, então nenhuma amostra montada aqui
    # dentro exercitaria o caminho novo. Até esta rodada, `LoadPDF` recusava
    # estes dois arquivos com ORA-20843.
    #
    # O documento vem do MuPDF com use_objstms=1: Catalog, Pages e as páginas
    # ficam dentro de um /Type /ObjStm, e a referência cruzada é um /Type /XRef
    # comprimido. Se a leitura do object stream errar, não há página nenhuma
    # para o overlay achar.
    ('objstm', """
        DECLARE l_org BLOB := TO_BLOB(:origem); BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.LoadPDF(l_org);
          PL_FPDF.OverlayText(p_page_number => 2, p_text => 'Carimbo na 2',
                              p_x => 72, p_y => 400);
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 3,
      'textos': ['objstm um', 'objstm dois', 'objstm tres'],
      'so_nas_paginas': {'Carimbo na 2': [2]}}),

    # O MuPDF grava a xref em stream SEM predictor; Acrobat e Ghostscript
    # gravam com /Predictor 12, que é o caso comum. Por isso este arquivo é
    # montado à mão, pelo mesmo construtor que a referência valida. Um
    # predictor não desfeito não estoura: devolve offsets limpos e falsos, e o
    # objeto que sai de lá é outro objeto.
    ('xref_predictor', """
        DECLARE l_org BLOB := TO_BLOB(:origem); BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.LoadPDFWithID('p', l_org);
          :saida := PL_FPDF.ExtractPages('p', '1', NULL);
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1, 'textos': ['xref em stream']}),

    # PNG com canal alfa: o PDF não guarda a transparência dentro do pixel — ela
    # é um segundo objeto de imagem, apontado por /SMask. A prova não é "saiu
    # uma imagem": é o MuPDF COMPOR a imagem com o fundo. A página tem fundo
    # branco, então metade de opacidade sobre (200,60,40) dá ~(228,158,148).
    ('png_alfa', """
        DECLARE l_pdf BLOB; l_img BLOB := TO_BLOB(:img); BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
          PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Folha com alfa','1',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;

          PL_FPDF.LoadPDF(l_pdf);
          PL_FPDF.OverlayImage(p_page_number => 1, p_image_blob => l_img,
                               p_x => 100, p_y => 500,
                               p_width => 120, p_height => 120);
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1, 'textos': ['Folha com alfa'],
      # Uma imagem só na página: o /SMask NÃO é recurso dela — é referenciado
      # de dentro do dicionário da imagem, e get_images() não o conta.
      'imagens': {1: 1},
      'com_smask': [1],
      'pixel': (1, 160, 560, (228, 158, 148))}),

    # PNG entrelaçado (Adam7): as sete passagens têm de ser remontadas na ordem
    # certa. A imagem é metade vermelha e metade azul — um de-entrelaçamento
    # errado embaralha as colunas, e dois pixels distantes revelam isso.
    ('png_entrelacado', """
        DECLARE l_pdf BLOB; l_img BLOB := TO_BLOB(:img); BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
          PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Folha entrelacada','1',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;

          PL_FPDF.LoadPDF(l_pdf);
          PL_FPDF.OverlayImage(p_page_number => 1, p_image_blob => l_img,
                               p_x => 100, p_y => 500,
                               p_width => 160, p_height => 160);
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1, 'textos': ['Folha entrelacada'], 'imagens': {1: 1},
      'pixels': [(1, 140, 580, (220, 40, 40)),
                 (1, 220, 580, (40, 60, 220))]}),

    # Cifrar um PDF 1.5+ EM CLARO: a origem tem object streams, e cifrar exige
    # achatá-los. O que se verifica não é só "abriu com a senha" — é o TÍTULO,
    # que mora dentro do object stream. Dentro dele as strings não são cifradas
    # uma a uma; ao virar objeto de primeiro nível elas passam a precisar de
    # cifra própria. Errar isso deixa o arquivo abrindo e o título embaralhado.
    ('objstm_cifrado', """
        DECLARE l_org BLOB := TO_BLOB(:origem); BEGIN
          PL_FPDF.ClearPDFCache;
          :saida := PL_FPDF.EncryptPDF(p_pdf => l_org,
                                       p_user_password => 'senha123',
                                       p_encryption => 'AES-128');
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1, 'senha': 'senha123', 'textos': ['texto da pagina'],
      'metadados': {'title': TITULO_OBJSTM}}),

    # Ida e volta sobre PDF 1.5+: cifra e decifra. O resultado tem de abrir SEM
    # senha, com o texto e com o título intactos — a volta NÃO pode decifrar de
    # novo as strings que vieram do object stream.
    ('objstm_ida_volta', """
        DECLARE l_org BLOB := TO_BLOB(:origem); l_cif BLOB; BEGIN
          PL_FPDF.ClearPDFCache;
          l_cif := PL_FPDF.EncryptPDF(p_pdf => l_org,
                                      p_user_password => 'senha123',
                                      p_encryption => 'RC4-128');
          :saida := PL_FPDF.DecryptPDF(l_cif, 'senha123');
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1, 'sem_senha': True, 'textos': ['texto da pagina'],
      'metadados': {'title': TITULO_OBJSTM}}),

    # AES nas duas revisões. O que prova que funcionou é o MuPDF — leitor
    # independente — abrir com a senha e devolver o texto: um /CF errado ou um
    # /Length não reescrito produzem um arquivo que "parece" cifrado.
    ('aes128', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.AddPage();
          PL_FPDF.Cell(150,10,:conteudo,'0',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := PL_FPDF.EncryptPDF(p_pdf => l_pdf,
                                       p_user_password => 'senha123',
                                       p_encryption => 'AES-128');
        END;""",
     {'paginas': 1, 'senha': 'senha123', 'textos': ['Conteudo protegido']}),

    ('aes256', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.AddPage();
          PL_FPDF.Cell(150,10,:conteudo,'0',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          :saida := PL_FPDF.EncryptPDF(p_pdf => l_pdf,
                                       p_user_password => 'senha123',
                                       p_encryption => 'AES-256');
        END;""",
     {'paginas': 1, 'senha': 'senha123', 'textos': ['Conteudo protegido']}),

    # Ida e volta do AES-128: o resultado tem de abrir SEM senha e trazer o texto
    # legivel. E a unica prova de que DecryptPDF decifra em vez de desmarcar.
    ('aes128_ida_volta', """
        DECLARE l_pdf BLOB; l_cif BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.AddPage();
          PL_FPDF.Cell(150,10,:conteudo,'0',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          l_cif := PL_FPDF.EncryptPDF(p_pdf => l_pdf,
                                      p_user_password => 'senha123',
                                      p_encryption => 'AES-128');
          :saida := PL_FPDF.DecryptPDF(l_cif, 'senha123');
        END;""",
     {'paginas': 1, 'sem_senha': True, 'textos': ['Documento decifrado']}),

    # Ida e volta do AES-256: o resultado tem de abrir SEM senha e trazer o texto
    # legivel. E a unica prova de que DecryptPDF decifra em vez de desmarcar.
    ('aes256_ida_volta', """
        DECLARE l_pdf BLOB; l_cif BLOB; BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.AddPage();
          PL_FPDF.Cell(150,10,:conteudo,'0',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;
          l_cif := PL_FPDF.EncryptPDF(p_pdf => l_pdf,
                                      p_user_password => 'senha123',
                                      p_encryption => 'AES-256');
          :saida := PL_FPDF.DecryptPDF(l_cif, 'senha123');
        END;""",
     {'paginas': 1, 'sem_senha': True, 'textos': ['Documento decifrado']}),

    # Opções do OverlayText: font, bold, align, width e zOrder. O que prova que
    # funcionaram é a POSIÇÃO e a FONTE que o MuPDF extrai — não a presença do
    # texto, que já apareceria mesmo com tudo ignorado.
    ('overlay_opcoes', """
        DECLARE l_pdf BLOB; BEGIN
          PL_FPDF.ClearPDFCache;
          PL_FPDF.Init('P','mm','A4'); PL_FPDF.SetFont('Arial','B',16);
          PL_FPDF.AddPage(); PL_FPDF.Cell(100,10,'Base','1',1);
          l_pdf := PL_FPDF.OutputBlob(); PL_FPDF.Reset;

          PL_FPDF.LoadPDF(l_pdf);
          -- mesma caixa de 400pt, começando em x=100: só o align muda
          PL_FPDF.OverlayText(1, 'AEsquerda', 100, 700,
            JSON_OBJECT_T(\'{"width":400,"align":"left","fontSize":14}\'));
          PL_FPDF.OverlayText(1, 'AoCentro', 100, 660,
            JSON_OBJECT_T(\'{"width":400,"align":"center","fontSize":14}\'));
          PL_FPDF.OverlayText(1, 'ADireita', 100, 620,
            JSON_OBJECT_T(\'{"width":400,"align":"right","fontSize":14}\'));
          -- fonte e negrito
          PL_FPDF.OverlayText(1, 'EmTimes', 100, 560,
            JSON_OBJECT_T(\'{"font":"Times","fontSize":14}\'));
          PL_FPDF.OverlayText(1, 'EmCourierNegrito', 100, 520,
            JSON_OBJECT_T(\'{"font":"Courier","bold":true,"fontSize":14}\'));
          -- quebra automática dentro da largura
          PL_FPDF.OverlayText(1,
            \'palavra1 palavra2 palavra3 palavra4 palavra5 palavra6 palavra7\',
            100, 460, JSON_OBJECT_T(\'{"width":120,"fontSize":12}\'));
          :saida := PL_FPDF.OutputModifiedPDF();
          PL_FPDF.ClearPDFCache; PL_FPDF.Reset;
        END;""",
     {'paginas': 1,
      'textos': ['Base'],
      'alinhamento': {'caixa': (100, 400),
                      'esquerda': 'AEsquerda',
                      'centro': 'AoCentro',
                      'direita': 'ADireita'},
      'fontes': ['Times-Roman', 'Courier-Bold', 'Helvetica'],
      'quebra': ('palavra1', 3)}),

    # ── documento complexo ───────────────────────────────────────────────────
    # As outras amostras exercitam um recurso de cada vez. Esta junta tudo num
    # documento só — metadados, três famílias de fonte, cores, traços, tabela
    # com preenchimento alternado, parágrafo justificado, QR e dois códigos de
    # barras na mesma página, e um anexo em paisagem — porque a regressão que
    # mais escapa é a interação entre recursos: a fonte que não volta ao normal
    # depois do MultiCell, a cor de preenchimento que vaza para a página
    # seguinte, o AddPage('L') que não troca o /MediaBox.
    ('complexo', """
        DECLARE
          l_pdf BLOB;
          l_lin PLS_INTEGER;
        BEGIN
          PL_FPDF.Init('P','mm','A4');
          PL_FPDF.SetTitle('Relatorio complexo PL_FPDF');
          PL_FPDF.SetAuthor('Maxwell da Silva Oliveira');
          PL_FPDF.SetSubject('Amostra de regressao com varios recursos');
          PL_FPDF.SetKeywords('pdf,plsql,qrcode,barcode');
          PL_FPDF.SetCreator('PL_FPDF');
          PL_FPDF.SetMargins(15, 15, 15);
          PL_FPDF.SetAutoPageBreak(TRUE, 20);

          -- página 1: capa com faixa preenchida, texto invertido e parágrafo
          PL_FPDF.AddPage();
          PL_FPDF.SetFillColor(30, 60, 120);
          PL_FPDF.Rect(0, 0, 210, 45, 'F');
          PL_FPDF.SetTextColor(255, 255, 255);
          PL_FPDF.SetFont('Arial','B',26);
          PL_FPDF.SetXY(15, 16);
          PL_FPDF.Cell(180, 14, 'Capa do relatorio', '0', 1, 'L');
          PL_FPDF.SetTextColor(0, 0, 0);
          PL_FPDF.SetFont('Arial','I',12);
          PL_FPDF.SetXY(15, 55);
          PL_FPDF.Cell(180, 8, 'Documento de amostra do PL_FPDF', '0', 1);
          PL_FPDF.SetLineWidth(0.8);
          PL_FPDF.SetDrawColor(200, 30, 30);
          PL_FPDF.Line(15, 70, 195, 70);
          PL_FPDF.SetFont('Times','',11);
          PL_FPDF.SetXY(15, 78);
          l_lin := PL_FPDF.MultiCell(180, 6,
            'Este paragrafo existe para exercitar a quebra automatica de '
            || 'linha e o alinhamento justificado do MultiCell, com uma '
            || 'fonte diferente da usada no titulo. Depois dele a pagina '
            || 'continua com o mesmo estado de fonte e de cor.', '1', 'J');

          -- página 2: tabela com cabeçalho e linhas alternadas
          PL_FPDF.AddPage();
          PL_FPDF.SetFont('Arial','B',12);
          PL_FPDF.Cell(180, 10, 'Tabela de itens', '0', 1);
          PL_FPDF.SetFont('Arial','B',10);
          PL_FPDF.SetFillColor(210, 210, 210);
          PL_FPDF.Cell(20, 7, 'Item',      '1', 0, 'C', 1);
          PL_FPDF.Cell(85, 7, 'Descricao', '1', 0, 'C', 1);
          PL_FPDF.Cell(35, 7, 'Quantidade','1', 0, 'C', 1);
          PL_FPDF.Cell(40, 7, 'Valor',     '1', 1, 'R', 1);
          PL_FPDF.SetFont('Courier','',10);
          PL_FPDF.SetFillColor(242, 242, 242);
          FOR i IN 1 .. 25 LOOP
            PL_FPDF.Cell(20, 6, TO_CHAR(i, 'FM000'), '1', 0, 'C',
                         CASE WHEN MOD(i, 2) = 0 THEN 1 ELSE 0 END);
            PL_FPDF.Cell(85, 6, 'Produto de teste numero ' || i, '1', 0, 'L',
                         CASE WHEN MOD(i, 2) = 0 THEN 1 ELSE 0 END);
            PL_FPDF.Cell(35, 6, TO_CHAR(i * 3), '1', 0, 'C',
                         CASE WHEN MOD(i, 2) = 0 THEN 1 ELSE 0 END);
            PL_FPDF.Cell(40, 6, TO_CHAR(i * 17.5, 'FM9990D00'), '1', 1, 'R',
                         CASE WHEN MOD(i, 2) = 0 THEN 1 ELSE 0 END);
          END LOOP;

          -- página 3: três símbolos na mesma página
          PL_FPDF.AddPage();
          PL_FPDF.SetFont('Arial','B',12);
          PL_FPDF.Cell(180, 10, 'Codigos', '0', 1);
          PL_FPDF.AddQRCode(20, 35, 70, :qr, 'TEXT', 'M');
          PL_FPDF.AddBarcode(20, 125, 120, 25, :bc,  'CODE128', TRUE);
          PL_FPDF.AddBarcode(20, 175, 120, 25, :ean, 'EAN13',   TRUE);

          -- página 4: anexo em paisagem (troca de /MediaBox no meio do doc)
          PL_FPDF.AddPage('L', 'A4');
          PL_FPDF.SetFont('Arial','B',14);
          PL_FPDF.Cell(0, 10, 'Anexo em paisagem', '0', 1);
          PL_FPDF.SetFont('Arial','',10);
          FOR i IN 1 .. 6 LOOP
            PL_FPDF.Cell(45, 7, 'coluna ' || i, '1', 0, 'C');
          END LOOP;
          PL_FPDF.Ln();

          l_pdf := PL_FPDF.OutputBlob();
          PL_FPDF.Reset;
          :saida := l_pdf;
        END;""",
     {'paginas': 4,
      'textos': ['Capa do relatorio', 'Tabela de itens', 'Codigos',
                 'Anexo em paisagem'],
      'metadados': {'title': 'Relatorio complexo PL_FPDF',
                    'author': 'Maxwell da Silva Oliveira'},
      'paisagem': [4],
      'simbolos': {3: ['PL-FPDF|COMPLEXO|2026', 'PLFPDF2026',
                       '7891234567895']},
      # o traço vermelho é definido UMA vez, na página 1, e tem de continuar
      # valendo na 4 — cor de traço é estado do documento, não da página, e o
      # AddPage('L') não pode zerá-la. Sem isto a checagem ficava na imagem.
      'cores': {1: {'fill': [(30, 60, 120)]},
                2: {'fill': [(210, 210, 210), (242, 242, 242)]},
                4: {'stroke': [(200, 30, 30)]}}}),
]

def png_alfa(lado, rgba):
    """PNG RGBA gravado pelo Pillow — produtor de verdade, não construtor daqui."""
    from PIL import Image
    buf = io.BytesIO()
    Image.new('RGBA', (lado, lado), rgba).save(buf, 'PNG')
    return buf.getvalue()


def png_entrelacado(lado):
    """PNG Adam7, metade vermelha e metade azul.

    Vem do construtor da referência, que é conferido pelo Pillow antes de ser
    usado — o Pillow não grava entrelaçado, então o arquivo é montado à mão, e
    montá-lo com o mesmo raciocínio do decodificador seria ser juiz e réu.
    """
    pixels = bytearray()
    for _ in range(lado):
        for x in range(lado):
            pixels += bytes((220, 40, 40) if x < lado // 2 else (40, 60, 220))
    return _referencia('pdfimage_reference').png_entrelacado(
        lado, lado, bytes(pixels))


def png_solido(lado, rgb):
    """PNG mínimo de cor sólida, para o overlay de imagem.

    Sem filtro por linha (tipo 0), que é o caso que o /Predictor 15 cobre.
    """
    import struct
    import zlib

    def bloco(tipo, dados):
        c = tipo + dados
        return struct.pack('>I', len(dados)) + c + struct.pack('>I', zlib.crc32(c))

    cru = b''.join(b'\x00' + bytes(rgb) * lado for _ in range(lado))
    return (b'\x89PNG\r\n\x1a\n'
            + bloco(b'IHDR', struct.pack('>IIBBBBB', lado, lado, 8, 2, 0, 0, 0))
            + bloco(b'IDAT', zlib.compress(cru))
            + bloco(b'IEND', b''))


def _referencia(pasta, modulo='validate'):
    """Carrega um módulo de uma referência (por padrão o `validate.py`).

    Por caminho, e com nome próprio no `sys.modules`: as referências têm todas
    um módulo chamado `validate`, e um `import validate` devolveria a primeira
    que tivesse sido carregada — silenciosamente, e com os construtores
    errados.

    Os construtores de PDF vivem junto do teste que os confere contra o MuPDF;
    importá-los daqui evita ter uma segunda versão que possa divergir dela.
    """
    import importlib.util                             # noqa: PLC0415
    aqui = os.path.dirname(os.path.abspath(__file__))
    if aqui not in sys.path:
        sys.path.insert(0, aqui)
    ref = os.path.join(aqui, pasta)
    if ref not in sys.path:
        sys.path.insert(0, ref)
    nome = modulo + '_' + pasta
    if nome in sys.modules:
        return sys.modules[nome]
    spec = importlib.util.spec_from_file_location(
        nome, os.path.join(ref, modulo + '.py'))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[nome] = mod
    spec.loader.exec_module(mod)
    return mod


def pdf_objstm_com_titulo():
    """PDF 1.5+ em claro com uma STRING dentro do object stream.

    Vem do construtor da referência: o MuPDF, ao gravar com object stream,
    deixa o /Info — o objeto que tem strings — fora dele, e é justamente a
    string de dentro que este teste existe para verificar.
    """
    return _referencia('pdfobjstm_crypt_reference').pdf_claro_com_objstm(
        TITULO_OBJSTM)


def pdf_com_predictor():
    """PDF cuja xref em stream usa /Predictor 12 — o MuPDF não grava predictor,
    e é o caso comum lá fora."""
    import tempfile
    caminho = os.path.join(tempfile.mkdtemp(), 'pred.pdf')
    _referencia('pdfxref_reference').monta_pdf_xrefstream(
        caminho, predictor=12, filtro=2)
    return open(caminho, 'rb').read()


PIX = ('00020126360014BR.GOV.BCB.PIX0114+5531999999995204000053039865802BR'
       '5913M&S do Brasil6008BRASILIA62070503***63041D3D')
# O EAN-13 com 12 dígitos tem o verificador calculado pela biblioteca, e é o
# código de 13 que o leitor devolve — por isso o conteúdo aqui já vai completo.
CONTEUDOS = {'qrcode_pix': PIX, 'barcode_code128': 'PL-FPDF-2026',
             'barcode_ean13': '7891234567895',
             'cifrado': 'Conteudo protegido por senha',
             'aes128': 'Conteudo protegido com AES 128',
             'aes256': 'Conteudo protegido com AES 256',
             'aes128_ida_volta': 'Documento decifrado do AES 128',
             'aes256_ida_volta': 'Documento decifrado do AES 256',
             'decifrado': 'Documento decifrado ida e volta',
             # um dicionário vira vários binds — a amostra complexa precisa de
             # três conteúdos diferentes no mesmo bloco
             'marca_dagua': 'CONFIDENCIAL',
             'overlay_img': {'img': png_solido(8, (32, 144, 208))},
             'png_alfa': {'img': png_alfa(8, (200, 60, 40, 128))},
             'png_entrelacado': {'img': png_entrelacado(16)},
             # o banner do próprio projeto: 1280x640, 326 KB — a única
             # amostra com imagem grande, que exige bind como BLOB
             'png_grande': {'img': open(do_repo('site', 'assets', 'social-preview.png'),
                                        'rb').read()},
             'objstm': {'origem': _referencia(
                 'pdfxref_reference').pdf_com_objstm_bytes(
                     ['objstm um', 'objstm dois', 'objstm tres'])},
             'xref_predictor': {'origem': pdf_com_predictor()},
             'objstm_cifrado': {'origem': pdf_objstm_com_titulo()},
             'objstm_ida_volta': {'origem': pdf_objstm_com_titulo()},
             'complexo': {'qr': 'PL-FPDF|COMPLEXO|2026',
                          'bc': 'PLFPDF2026',
                          'ean': '7891234567895'}}


def gerar_amostras(con, destino, quais=None):
    """Gera os PDFs no banco. `quais` limita às amostras ainda pendentes."""
    import oracledb
    os.makedirs(destino, exist_ok=True)
    geradas = {}
    print('\n== Gerando amostras no banco')
    for nome, plsql, _ in AMOSTRAS:
        if quais is not None and nome not in quais:
            continue
        with con.cursor() as cur:
            saida = cur.var(oracledb.DB_TYPE_BLOB)
            binds = {'saida': saida}
            valor = CONTEUDOS.get(nome)
            if isinstance(valor, dict):
                binds.update(valor)
            elif ':conteudo' in plsql:
                binds['conteudo'] = valor
            # Acima de 32767 bytes o driver recusa o bind como RAW
            # ('bind data too large'); imagem de verdade passa disso fácil.
            # Declarar BLOB faz o driver criar um LOB temporário.
            grandes = {k: oracledb.DB_TYPE_BLOB for k, v in binds.items()
                       if isinstance(v, bytes) and len(v) > 30000}
            if grandes:
                cur.setinputsizes(**grandes)
            try:
                cur.execute(plsql, binds)
            except Exception as e:                           # noqa: BLE001
                print(f'   {nome}: ERRO {str(e).splitlines()[0]}')
                continue
            lob = saida.getvalue()
            dados = lob.read() if lob is not None else None
        if not dados:
            print(f'   {nome}: vazio')
            continue
        caminho = os.path.join(destino, nome + '.pdf')
        open(caminho, 'wb').write(dados)
        geradas[nome] = dados
        print(f'   {nome}: {len(dados)} bytes -> {caminho}')
    return geradas


def _sem_avisos(dados, senha=None):
    """(passou?, ok, falha) — o MuPDF lê o arquivo inteiro sem reclamar?

    O MuPDF é tolerante: ele ABRE arquivo malformado e só avisa. Um `endobj`
    duplicado atravessou todas as outras checagens — as páginas continuavam
    corretas, o texto saía, os pixels batiam — e só apareceu ao olhar os
    avisos. Um leitor mais rígido pode recusar o que ele aceita.

    **Documento próprio, de propósito.** Ler as páginas para provocar os avisos
    num documento que as outras checagens também usam estraga as outras: num
    PDF cifrado, forçar a leitura logo depois do `authenticate` faz o MuPDF ler
    o fluxo sem decifrar, e as checagens de texto seguintes passam a ver página
    vazia. Aqui o documento é aberto, lido e fechado sem tocar em mais nada.

    O `reset` também importa: sem ele o aviso de uma amostra vaza para a
    seguinte, e o relatório acusa quem está correto.
    """
    import pymupdf                                     # noqa: PLC0415
    pymupdf.TOOLS.reset_mupdf_warnings()
    d = pymupdf.open(stream=dados, filetype='pdf')
    try:
        if senha:
            d.authenticate(senha)
        # o MuPDF só reclama de um objeto quando precisa dele: abrir não basta
        for pg in d:
            pg.get_text()
            pg.get_pixmap(dpi=36)
        reparado = d.is_repaired
    finally:
        d.close()
    avisos = pymupdf.TOOLS.mupdf_warnings()
    return (not avisos and not reparado,
            'o MuPDF lê o arquivo inteiro sem avisos',
            f'o MuPDF avisou ao ler: {avisos.strip()[:120]!r}'
            + (' (e teve de REPARAR o arquivo)' if reparado else ''))


MM_PT = 72.0 / 25.4          # milímetro -> ponto PostScript


def _vertices_do_triangulo(x, y, tam, ori):
    """Os três vértices que o `Triangle` deve emitir, em mm.

    Mesma regra do package: base 2*tam, altura tam, (x, y) no canto superior
    esquerdo da caixa, ponta para `ori`. Estar escrito aqui é o que permite
    conferir a FORMA, e não só que algo foi desenhado.
    """
    ori = ori.lower()
    if ori in ('r', 'right'):
        return [(x, y), (x + tam, y + tam), (x, y + 2 * tam)]
    if ori in ('l', 'left'):
        return [(x + tam, y), (x, y + tam), (x + tam, y + 2 * tam)]
    if ori in ('d', 'down'):
        return [(x, y), (x + 2 * tam, y), (x + tam, y + tam)]
    if ori in ('u', 'up'):
        return [(x, y + tam), (x + 2 * tam, y + tam), (x + tam, y)]
    raise SystemExit(f'orientação desconhecida na amostra: {ori!r}')


def _marca_em_claro(nome, exp):
    """Texto que prova, olhando os BYTES, se o conteúdo está cifrado.

    Na maioria das amostras é o próprio conteúdo passado ao bloco. Quando o
    conteúdo é um dicionário de binds — o caso das que partem de um PDF pronto
    — não há string a usar, e a marca vem de `em_claro` ou do primeiro texto
    esperado.
    """
    valor = CONTEUDOS.get(nome)
    if isinstance(valor, str):
        return valor
    if 'em_claro' in exp:
        return exp['em_claro']
    return exp['textos'][0]


def validar_amostras(geradas, verboso=False):
    """MuPDF abre e extrai; zxing-cpp decodifica os símbolos de verdade.

    Devolve a lista de falhas (amostra, motivo). Cada amostra imprime uma linha
    só; o detalhe do que passou fica para o --verbose, e o do que falhou vem
    logo abaixo da linha da amostra.
    """
    import pymupdf
    import zxingcpp
    print('\n== Validando os PDFs gerados')
    falhas = []
    esperado = {nome: exp for nome, _, exp in AMOSTRAS}

    for nome, dados in geradas.items():
        exp = esperado[nome]
        checagens = []      # (passou?, descrição)

        def conf(cond, ok_msg, falha_msg):
            checagens.append((bool(cond), ok_msg if cond else falha_msg))

        try:
            doc = pymupdf.open(stream=dados, filetype='pdf')
        except Exception as e:                               # noqa: BLE001
            print(f'   FALHA {nome:<20} MuPDF não abriu o arquivo')
            print(f'         {e}')
            falhas.append((nome, f'MuPDF não abriu ({e})'))
            continue

        if 'senha' in exp:
            # o que separa "marcado como protegido" de protegido de verdade
            if not doc.needs_pass:
                conf(False, '', 'MuPDF não vê o PDF como protegido')
            else:
                conf(doc.authenticate(exp['senha']),
                     'protegido; abre com a senha correta',
                     'a senha correta não abre o documento')
            d2 = pymupdf.open(stream=dados, filetype='pdf')
            conf(not d2.authenticate('errada'),
                 'senha errada recusada', 'senha errada foi aceita')
            d2.close()
            marca = _marca_em_claro(nome, exp)
            conf(marca.encode() not in dados,
                 'o texto não aparece em claro nos bytes',
                 'o texto aparece EM CLARO nos bytes — está apenas marcado '
                 'como protegido')

        conf(*_sem_avisos(dados, exp.get('senha')))

        if exp.get('sem_senha'):
            conf(not doc.needs_pass,
                 'abre sem senha depois de decifrado',
                 'continua pedindo senha depois de DecryptPDF')
            conf(_marca_em_claro(nome, exp).encode() in dados,
                 'o texto voltou legível nos bytes do arquivo',
                 'o texto continua cifrado nos bytes — DecryptPDF só tirou a '
                 'marca /Encrypt')

        conf(doc.page_count == exp['paginas'],
             f'{doc.page_count} página(s)',
             f'{doc.page_count} páginas, esperado {exp["paginas"]}')

        # `textos` é POR PÁGINA: a entrada i é conferida na página i+1. Uma
        # entrada pode ser uma string ou uma lista de strings, e nesse caso
        # todas são procuradas na mesma página — que é o caso de um documento
        # denso de uma página só, como o boleto.
        for i, alvo in enumerate(exp.get('textos', [])):
            # sem esta guarda um documento com menos páginas que o esperado
            # estourava IndexError e abortava o runner, escondendo as
            # verificações seguintes
            if i >= doc.page_count:
                conf(False, '', f'esperava texto na página {i + 1}, mas o '
                                f'documento tem {doc.page_count}')
                break
            texto = doc[i].get_text().replace('\n', ' ')
            for um in ([alvo] if isinstance(alvo, str) else alvo):
                conf(um in texto,
                     f'página {i + 1} contém {um!r}',
                     f'página {i + 1} não contém {um!r} '
                     f'(texto: {texto.strip()[:60]!r})')

        for chave, esperada in exp.get('metadados', {}).items():
            obtido = (doc.metadata or {}).get(chave)
            conf(obtido == esperada,
                 f'metadado {chave} = {esperada!r}',
                 f'metadado {chave} = {obtido!r}, esperado {esperada!r}')

        for pag in exp.get('paisagem', []):
            if pag > doc.page_count:
                conf(False, '', f'não há página {pag} para conferir a orientação')
                continue
            r = doc[pag - 1].rect
            conf(r.width > r.height,
                 f'página {pag} em paisagem ({r.width:.0f}x{r.height:.0f})',
                 f'página {pag} não está em paisagem '
                 f'({r.width:.0f}x{r.height:.0f})')

        # O /SMask não aparece na CONTAGEM de get_images(): ele é apontado de
        # dentro do dicionário da imagem, não do /Resources da página. O que o
        # revela é o segundo campo da tupla, que traz o xref dele.
        for pag in exp.get('com_smask', []):
            imgs = doc[pag - 1].get_images(full=True)
            com = [i for i in imgs if i[1]]
            conf(imgs and len(com) == len(imgs),
                 f'página {pag}: as {len(imgs)} imagem(ns) têm /SMask',
                 f'página {pag}: {len(com)} de {len(imgs)} imagem(ns) com '
                 f'/SMask — sem ele a transparência é ignorada e a imagem sai '
                 f'opaca')

        for pag, quantas in exp.get('imagens', {}).items():
            vistas = len(doc[pag - 1].get_images(full=True)) \
                if pag <= doc.page_count else -1
            conf(vistas == quantas,
                 f'página {pag}: {quantas} imagem(ns)',
                 f'página {pag}: {vistas} imagem(ns), esperado {quantas}'
                 + (' — vazou pelo /Resources compartilhado?'
                    if vistas > quantas else ''))

        # Um documento denso — um boleto tem ~45 caixas, ~19 linhas e mais de
        # cem barras — não é provado por "abriu e tem texto". O que separa o
        # desenho vetorial de uma página em branco com legendas é a CONTAGEM
        # de operadores que o MuPDF vê no fluxo de conteúdo.
        if 'desenhos' in exp:
            tipos = {}
            for dr in doc[0].get_drawings():
                for it in dr['items']:
                    tipos[it[0]] = tipos.get(it[0], 0) + 1
            for op, minimo in exp['desenhos'].items():
                conf(tipos.get(op, 0) >= minimo,
                     f"{tipos.get(op, 0)} operador(es) '{op}' no desenho "
                     f'(mínimo {minimo})',
                     f"só {tipos.get(op, 0)} operador(es) '{op}', esperado ao "
                     f'menos {minimo} — o desenho vetorial não saiu')

        # ── o desenho contra a régua ─────────────────────────────────────────
        # Texto certo não é desenho certo. Um valor que transborda a caixa, um
        # rótulo no corpo errado, a coluna do dinheiro desalinhada ou dois
        # textos empilhados passam por qualquer conferência de conteúdo. Quem
        # sabe onde cada coisa devia estar é `scripts/boleto_reference/`, e é a
        # MESMA função que confere o desenho de referência e este PDF, vindo do
        # banco: não há duas listas de expectativas para divergirem.
        if 'layout_boleto' in exp:
            bl = _referencia('boleto_reference', 'boleto_reference')
            y_recibo, y_ficha = exp['layout_boleto']
            ld = '34191.09008 00012.323077 31234.510001 7 16770000015000'
            for passou, ok_msg, falha_msg in bl.conferir(doc[0], y_recibo,
                                                         y_ficha, ld):
                conf(passou, ok_msg, falha_msg)

        # O ingresso acrescenta ao que o boleto confere: a COR de cada texto e
        # o preenchimento de cada painel. É o defeito silencioso desta classe —
        # um painel que saiu branco continua "desenhado", e texto claro sobre
        # fundo claro simplesmente some, sem erro nenhum.
        if 'layout_ticket' in exp:
            tk = _referencia('ticket_reference', 'ticket_reference')
            for pag, (participante, codigo) in enumerate(exp['layout_ticket']):
                if pag >= doc.page_count:
                    conf(False, '', f'não há página {pag + 1} para conferir '
                                    f'o layout')
                    continue
                for passou, ok_msg, falha_msg in tk.conferir(
                        doc[pag], participante, codigo):
                    conf(passou, f'p{pag + 1} {ok_msg}',
                         f'p{pag + 1} {falha_msg}')

        # Quatro triângulos iguais emitiriam quatro caminhos de três linhas,
        # exatamente como quatro triângulos diferentes: contar operadores não
        # distingue. O que distingue são os VÉRTICES.
        for x, y, tam, ori in exp.get('triangulos', []):
            esperados = _vertices_do_triangulo(x, y, tam, ori)
            achados = 0
            for dr in doc[0].get_drawings():
                pontos = set()
                for it in dr['items']:
                    for ponto in it[1:]:
                        if hasattr(ponto, 'x'):
                            pontos.add((round(ponto.x / MM_PT, 1),
                                        round(ponto.y / MM_PT, 1)))
                if len(pontos) == 3 and all(
                        any(abs(a - b) < 0.3 and abs(c - d) < 0.3
                            for b, d in pontos) for a, c in esperados):
                    achados += 1
            conf(achados >= 1,
                 f'triângulo {ori!r} em ({x:.0f}, {y:.0f}) com os vértices '
                 f'certos',
                 f'nenhum triângulo com os vértices de {ori!r} em '
                 f'({x:.0f}, {y:.0f}): esperados {esperados}')

        # Filtro declarado é promessa: o leitor VAI tentar desfazê-lo. Se o
        # dado não estiver comprimido, o PDF não abre — e se estiver comprimido
        # sem o filtro, sai lixo. Só olhar o texto não distingue os dois casos
        # de um arquivo simplesmente maior.
        for pag, esperados in exp.get('filtros', {}).items():
            if pag > doc.page_count:
                conf(False, '', f'não há página {pag} para ler o filtro')
                continue
            achados = []
            for xref in doc[pag - 1].get_contents():
                achados.append(doc.xref_get_key(xref, 'Filter')[1])
            texto = ' '.join(achados)
            conf(all(f'/{e}' in texto for e in esperados),
                 f'página {pag}: filtros {esperados}',
                 f'página {pag}: /Filter é {texto!r}, esperados {esperados}')

        if 'tamanho_max' in exp:
            conf(len(dados) <= exp['tamanho_max'],
                 f'{len(dados)} bytes (teto {exp["tamanho_max"]})',
                 f'{len(dados)} bytes, acima do teto de '
                 f'{exp["tamanho_max"]} — a compressão não encolheu nada')

        # 'pixel' é um ponto; 'pixels' é uma lista deles — um ponto só não
        # distingue um de-entrelaçamento errado, que embaralha as colunas.
        for pag, px, py, rgb in ([exp['pixel']] if 'pixel' in exp else []) \
                + exp.get('pixels', []):
            p = doc[pag - 1]
            # y do PDF sobe a partir da base; o pixmap desce do topo
            pix = p.get_pixmap(dpi=72)
            lido = pix.pixel(int(px), int(p.rect.height - py))
            conf(all(abs(a - b) <= 12 for a, b in zip(lido[:3], rgb)),
                 f'página {pag}: pixel em ({px},{py}) é {rgb}',
                 f'página {pag}: pixel em ({px},{py}) leu {lido[:3]}, '
                 f'esperado {rgb} — /DecodeParms ou /ColorSpace errado '
                 f'desenha ruído sem invalidar o arquivo')

        for alvo, paginas in exp.get('so_nas_paginas', {}).items():
            onde = [i + 1 for i in range(doc.page_count)
                    if alvo in doc[i].get_text()]
            conf(onde == paginas,
                 f'{alvo!r} só nas páginas {paginas}',
                 f'{alvo!r} apareceu nas páginas {onde}, esperado {paginas} '
                 f'— vazamento pelo /Resources compartilhado?')

        if 'alinhamento' in exp:
            # o que prova o align não é o texto estar lá — é ONDE ele está.
            # Com tudo ignorado os três sairiam na mesma coluna.
            al = exp['alinhamento']
            x0, larg = al['caixa']
            cx = {}
            for palavra in doc[0].get_text('words'):
                for chave in ('esquerda', 'centro', 'direita'):
                    if al[chave] in palavra[4]:
                        cx[chave] = (palavra[0], palavra[2])   # x0, x1
            faltando = [k for k in ('esquerda', 'centro', 'direita')
                        if k not in cx]
            if faltando:
                conf(False, '', f'align: texto não localizado para {faltando}')
            else:
                conf(abs(cx['esquerda'][0] - x0) < 4,
                     f"align left começa na borda da caixa ({cx['esquerda'][0]:.0f})",
                     f"align left começa em {cx['esquerda'][0]:.0f}, "
                     f'esperado ~{x0}')
                meio = (cx['centro'][0] + cx['centro'][1]) / 2
                conf(abs(meio - (x0 + larg / 2)) < 6,
                     f'align center centralizado na caixa ({meio:.0f})',
                     f'align center centrado em {meio:.0f}, '
                     f'esperado ~{x0 + larg / 2}')
                conf(abs(cx['direita'][1] - (x0 + larg)) < 6,
                     f"align right termina na borda ({cx['direita'][1]:.0f})",
                     f"align right termina em {cx['direita'][1]:.0f}, "
                     f'esperado ~{x0 + larg}')
                conf(cx['esquerda'][0] < cx['centro'][0] < cx['direita'][0],
                     'as três âncoras estão em colunas distintas',
                     f'os três alinhamentos coincidem — o align foi ignorado? '
                     f'({cx})')

        for base in exp.get('fontes', []):
            usadas = {f[3] for f in doc[0].get_fonts(full=True)}
            conf(any(base in u for u in usadas),
                 f'fonte {base} declarada na página',
                 f'fonte {base} não está em {sorted(usadas)}')

        if 'quebra' in exp:
            marca, minimo = exp['quebra']
            ys = {round(p[1]) for p in doc[0].get_text('words')
                  if p[4].startswith('palavra')}
            conf(len(ys) >= minimo,
                 f'texto quebrado em {len(ys)} linhas dentro da largura',
                 f'texto ficou em {len(ys)} linha(s); com width definido '
                 f'deveria quebrar em pelo menos {minimo}')

        for pag, quais in exp.get('cores', {}).items():
            if pag > doc.page_count:
                conf(False, '', f'não há página {pag} para conferir as cores')
                continue
            usadas = {'fill': set(), 'stroke': set()}
            for des in doc[pag - 1].get_drawings():
                for chave, campo in (('fill', 'fill'), ('stroke', 'color')):
                    if des.get(campo):
                        usadas[chave].add(tuple(round(c * 255) for c in des[campo]))
            for chave, cores in quais.items():
                for cor in cores:
                    conf(cor in usadas[chave],
                         f'página {pag}: {chave} {cor} presente',
                         f'página {pag}: {chave} {cor} não aparece '
                         f'(usadas: {sorted(usadas[chave])})')

        # símbolos: 'decodificar' diz para procurar, na página 1, o próprio
        # conteúdo que o bloco recebeu por bind; 'simbolos' lista o que se
        # espera ler em cada página, que é o caso de quem traz o dado dentro
        # do próprio exemplo.
        if 'decodificar' in exp:
            alvos = {1: [CONTEUDOS[nome]]}
        else:
            alvos = exp.get('simbolos', {})
        for pag, conteudos in alvos.items():
            if pag > doc.page_count:
                conf(False, '', f'não há página {pag} para ler os símbolos')
                continue
            pix = doc[pag - 1].get_pixmap(dpi=300)
            from PIL import Image
            img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
            simbolos = {(r.format.name, r.text)
                        for r in zxingcpp.read_barcodes(img)}
            lidos = {texto for _, texto in simbolos}
            for alvo in conteudos:
                conf(alvo in lidos,
                     f'página {pag}: {alvo!r} decodificado',
                     f'página {pag}: {alvo!r} não foi decodificado '
                     f'(lidos: {sorted(lidos)})')
            # quando a página tem mais de uma simbologia, ler UMA delas não
            # prova nada sobre a outra: o ingresso leva QR e Code 39 lado a
            # lado, dizendo a mesma coisa
            for formato in exp.get('formatos', {}).get(pag, []):
                conf(formato in {f for f, _ in simbolos},
                     f'página {pag}: {formato} presente',
                     f'página {pag}: nenhum {formato} lido '
                     f'(lidos: {sorted(f for f, _ in simbolos)})')
        doc.close()

        ruins = [m for bom, m in checagens if not bom]
        sit = 'FALHA' if ruins else 'ok'
        print(f'   {sit:<5} {nome:<20} {len(checagens) - len(ruins)}'
              f'/{len(checagens)} verificações')
        for m in ruins:
            print(f'         - {m}')
            falhas.append((nome, m))
        if verboso:
            for bom, m in checagens:
                if bom:
                    print(f'         · {m}')
    return falhas


# ──────────────────────────────── principal ──────────────────────────────────
# ─────────────────────────── progresso entre rodadas ─────────────────────────
#
# Rodar tudo a cada mexida custa minutos e, pior, esconde a etapa que interessa
# no meio de cem linhas que já passavam. O estado do que passou fica em
# `.plfpdf_estado.json` e as etapas concluídas são puladas na rodada seguinte.
#
# O risco óbvio de um teste progressivo é ele mentir: dizer "concluído" sobre
# código que mudou depois. Por isso a decisão de pular NÃO é "passou uma vez",
# e sim "passou uma vez E nada do que essa etapa depende mudou desde então":
#
#   - a etapa guarda a impressão digital das SUAS entradas (o arquivo de teste,
#     ou a definição da amostra). Editou o arquivo, a etapa volta a rodar;
#   - e o package é olhado à parte, subprograma a subprograma. Mudança rasa —
#     mexer no corpo de um punhado deles — preserva o progresso. Mudança
#     PROFUNDA zera tudo, porque aí qualquer etapa pode ter regredido:
#
#         * a spec (.pks) mudou            -> a API mudou
#         * a parte declarativa do body    -> tipos, globais e constantes valem
#           mudou                             para o package inteiro
#         * subprograma criado ou removido -> não é ajuste, é feature
#         * mais de LIMIAR_PROFUNDO        -> refatoração, não conserto
#           subprogramas alterados
#
# `--reset` zera o estado à mão; `--full` roda tudo uma vez sem apagá-lo.

ESTADO = do_repo('.plfpdf_estado.json')
LIMIAR_PROFUNDO = 5

# o mesmo cabeçalho que os lints usam para achar subprograma de nível de package
CABECALHO_SUB = re.compile(r'^[ \t]{0,2}(?:FUNCTION|PROCEDURE)\s+([a-z_][a-z_0-9$#]*)',
                           re.I | re.M)


def _sha(texto):
    import hashlib
    if isinstance(texto, str):
        texto = texto.encode('utf-8')
    return hashlib.sha1(texto).hexdigest()[:16]


def impressao_do_package():
    """{'spec', 'cabecalho', 'subprogramas': {nome: hash}} das fontes em disco.

    O body é fatiado nos mesmos pontos que o `check_declarations.py` usa, para
    que "mudou o subprograma X" queira dizer a mesma coisa nos dois lugares.
    """
    spec = (io.open(PKS, encoding='utf-8').read()
            + io.open(UTIL_PKS, encoding='utf-8').read())
    body = (io.open(PKB, encoding='utf-8').read()
            + io.open(UTIL_PKB, encoding='utf-8').read())
    marcas = [(m.start(), m.group(1).lower())
              for m in CABECALHO_SUB.finditer(body)]
    subs = {}
    for i, (ini, nome) in enumerate(marcas):
        fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(body)
        # um nome pode aparecer duas vezes (sobrecarga): o hash acumula
        subs[nome] = _sha(subs.get(nome, '') + body[ini:fim])
    return {'spec': _sha(spec),
            'cabecalho': _sha(body[:marcas[0][0]] if marcas else body),
            'subprogramas': subs}


def mudanca_profunda(antes, agora):
    """(precisa_rodar_tudo, motivo em uma linha)."""
    if not antes:
        return True, 'primeira rodada com estado'
    if antes.get('spec') != agora['spec']:
        return True, 'a spec (PL_FPDF.pks) mudou — a API não é mais a mesma'
    if antes.get('cabecalho') != agora['cabecalho']:
        return True, ('a parte declarativa do body mudou — tipos, globais e '
                      'constantes valem para o package inteiro')

    a, b = antes.get('subprogramas', {}), agora['subprogramas']
    novos = sorted(set(b) - set(a))
    sumidos = sorted(set(a) - set(b))
    if novos or sumidos:
        detalhe = ', '.join((novos + sumidos)[:4])
        return True, (f'{len(novos)} subprograma(s) criado(s) e '
                      f'{len(sumidos)} removido(s) ({detalhe}) — '
                      f'isso é feature, não ajuste')

    alterados = sorted(n for n in b if a[n] != b[n])
    if len(alterados) > LIMIAR_PROFUNDO:
        return True, (f'{len(alterados)} subprogramas alterados (limiar '
                      f'{LIMIAR_PROFUNDO}) — refatoração, não conserto')
    if alterados:
        return False, ('alterado(s): ' + ', '.join(alterados))
    return False, None


def ler_estado(alvo):
    import json
    try:
        with io.open(ESTADO, encoding='utf-8') as fh:
            e = json.load(fh)
    except (IOError, ValueError):
        return None
    if e.get('versao') != 1 or e.get('alvo') != alvo:
        # outro banco ou outro usuário: o que passou lá não vale aqui
        return None
    return e


def gravar_estado(estado):
    import json
    with io.open(ESTADO, 'w', encoding='utf-8') as fh:
        fh.write(json.dumps(estado, indent=2, ensure_ascii=False,
                            sort_keys=True))


class Progresso(object):
    """Quais etapas pular, e o registro do que passou."""

    def __init__(self, alvo, args):
        self.alvo = alvo
        self.ativo = not args.full
        self.impressao = impressao_do_package()
        antes = None if args.reset else ler_estado(alvo)
        if args.reset and os.path.exists(ESTADO):
            os.remove(ESTADO)

        self.tudo, self.motivo = mudanca_profunda(
            (antes or {}).get('fontes'), self.impressao)
        if args.reset:
            self.tudo, self.motivo = True, '--reset: começando do zero'
        elif args.full:
            self.tudo, self.motivo = True, '--full: rodando tudo nesta rodada'

        self.etapas = {} if (self.tudo or not antes) else antes['etapas']
        self.puladas = []

    def pular(self, chave, impressao):
        """A etapa já passou e nada de que ela depende mudou?"""
        if self.tudo or not self.ativo:
            return False
        e = self.etapas.get(chave)
        if e and e.get('situacao') == 'ok' and e.get('impressao') == impressao:
            self.puladas.append(chave)
            return True
        return False

    def marcar(self, chave, impressao, passou):
        import datetime
        self.etapas[chave] = {
            'situacao': 'ok' if passou else 'falhou',
            'impressao': impressao,
            'quando': datetime.datetime.now().isoformat(timespec='seconds')}

    def salvar(self):
        gravar_estado({'versao': 1, 'alvo': self.alvo,
                       'fontes': self.impressao, 'etapas': self.etapas})

    def anunciar(self):
        if self.tudo:
            print(f'== Progresso: rodando TUDO — {self.motivo}')
        else:
            feitas = sum(1 for e in self.etapas.values()
                         if e.get('situacao') == 'ok')
            print(f'== Progresso: {feitas} etapa(s) concluída(s) em rodadas '
                  f'anteriores serão puladas'
                  + (f' ({self.motivo})' if self.motivo else ''))
            print('   --reset zera o progresso | --full roda tudo sem zerar')

    def resumo(self):
        if self.puladas:
            print(f'PULADAS {len(self.puladas)} etapa(s) já concluídas: '
                  + ', '.join(self.puladas[:6])
                  + (' ...' if len(self.puladas) > 6 else ''))


def impressao_amostra(nome, plsql, esperado):
    """Tudo que define a amostra: o bloco, o que se espera e o conteúdo."""
    return _sha(repr((nome, plsql, esperado, CONTEUDOS.get(nome))))


def package_valido(con):
    """O PL_FPDF está instalado e VALID neste schema?

    Pular a compilação só é seguro se o banco tiver a versão que o estado diz
    ter compilado. Num schema novo o arquivo de estado de outra máquina — ou o
    de um DROP — faria o runner pular a instalação e falhar tudo em seguida.
    """
    with con.cursor() as cur:
        cur.execute("""SELECT status FROM user_objects
                        WHERE object_name IN ('PL_FPDF', 'PL_FPDF_UTIL')
                          AND object_type IN ('PACKAGE', 'PACKAGE BODY')""")
        situacoes = [r[0] for r in cur]
    return len(situacoes) == 4 and all(s == 'VALID' for s in situacoes)



def arquivos_de_teste():
    """(suíte, diagnósticos) — os dois conjuntos que o runner executa.

    Os `diag_*.sql` nasceram para a SQL Window, mas nesta branch o caminho
    principal é o Python: deixá-los fora daqui faria com que só fossem rodados
    quando alguém lembrasse. Entram os que seguem a convenção [PASS]/[FAIL];
    os `diag_utl_compress*.sql` são experimentos com o resultado registrado no
    próprio cabeçalho, não testes, e ficam de fora por não ter o que aferir.
    """
    suite, diag = [], []
    for f in sorted(glob.glob(do_repo('dev', 'tests', '*.sql'))):
        base = os.path.basename(f)
        if base == 'run_all_tests.sql':
            continue
        # Lixo de conflito de merge: o Git cria copias com estes sufixos e o
        # numero do processo. Nao sao testes — sao versoes velhas e misturadas
        # do mesmo arquivo, e rodar isso produz falha que nao existe no codigo.
        # Aconteceu: um run_all_tests_REMOTE_276.sql acusou 27 falhas de
        # cifragem que a suite de verdade nao tinha.
        if re.search(r'_(BACKUP|LOCAL|REMOTE|BASE)_\d+\.sql$', base, re.I):
            print(f'  ignorando {base}: sobra de conflito de merge, '
                  f'nao e um teste')
            continue
        if base.startswith('diag_'):
            if '[PASS]' in io.open(f, encoding='utf-8').read():
                diag.append(f)
        else:
            suite.append(f)
    return suite, diag


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--user', default=os.environ.get('PLFPDF_USER'))
    ap.add_argument('--password', default=None)
    ap.add_argument('--dsn', default=os.environ.get('PLFPDF_DSN'))
    ap.add_argument('--wallet', default=None, help='diretório do wallet (TNS_ADMIN)')
    ap.add_argument('--out', default=do_repo('dev', 'amostras'), help='onde salvar os PDFs gerados')
    ap.add_argument('--compile', action='store_true', dest='so_compilar')
    ap.add_argument('--tests', action='store_true', dest='so_testes')
    ap.add_argument('--validate', action='store_true', dest='so_validar')
    ap.add_argument('--reset', action='store_true',
                    help='zera o progresso e roda tudo do zero')
    ap.add_argument('--full', action='store_true',
                    help='roda tudo nesta rodada, sem apagar o progresso')
    ap.add_argument('--status', action='store_true',
                    help='mostra o progresso guardado e sai (não conecta)')
    ap.add_argument('-v', '--verbose', action='store_true', dest='verboso',
                    help='mostra a saída completa de cada teste, não só as falhas')
    args = ap.parse_args()

    if args.status:
        return mostrar_status()

    if not args.user or not args.dsn:
        ap.error('informe --user e --dsn (ou PLFPDF_USER e PLFPDF_DSN)')

    tudo = not (args.so_compilar or args.so_testes or args.so_validar)
    todas_falhas = []      # (origem, motivo) — consolidado no fim
    total = None

    prog = Progresso(f'{args.user}@{args.dsn}', args)
    prog.anunciar()

    con = conectar(args)
    print(f'Conectado: {args.user}@{args.dsn}')
    compilou = False

    # ── compilação ───────────────────────────────────────────────────────────
    # Pular a instalação exige as duas coisas: o estado dizer que aquela fonte
    # já compilou, E o banco realmente ter o package válido. Só o primeiro
    # deixaria um schema novo (ou um DROP) passar batido e falhar tudo adiante.
    if tudo or args.so_compilar:
        imp = _sha(repr(prog.impressao))
        if prog.pular('compilar', imp) and package_valido(con):
            print('== Compilando: pulado (fonte inalterada e package VALID)')
        else:
            if compilar(con):
                prog.marcar('compilar', imp, False)
                prog.salvar()
                print('\nCompilação falhou — o resto não faz sentido sem isso.')
                con.close()
                return 1
            prog.marcar('compilar', imp, True)
            compilou = True

    if compilou:
        # o PL_FPDF tem estado: uma sessão que já o carregou falha com
        # ORA-04068/ORA-06508 depois da recompilação
        con.close()
        con = conectar(args)
        print('   sessão reconectada (o package tem estado)')

    # ── suíte e diagnósticos ─────────────────────────────────────────────────
    if tudo or args.so_testes:
        suite, diag = arquivos_de_teste()
        for rotulo, lista in (('teste', suite), ('diag', diag)):
            pendentes = []
            for f in lista:
                imp = _sha(io.open(f, encoding='utf-8').read())
                if not prog.pular(f'{rotulo}:{os.path.basename(f)}', imp):
                    pendentes.append(f)
            if not pendentes:
                continue
            parcial, falhas, situacao = rodar_testes(con, pendentes, args.verboso)
            for f in pendentes:
                base = os.path.basename(f)
                prog.marcar(f'{rotulo}:{base}',
                            _sha(io.open(f, encoding='utf-8').read()),
                            situacao.get(base, False))
            if total is None:
                total = parcial
            else:
                for k in total:
                    total[k] += parcial[k]
            todas_falhas += falhas
            prog.salvar()
        if total:
            print(f'   {"-" * 60}')
            print(f'   {total["PASS"]} passou | {total["FAIL"]} falhou'
                  f' | {total["SKIP"]} pulado')

    # ── amostras ─────────────────────────────────────────────────────────────
    if tudo or args.so_validar:
        pendentes = [nome for nome, plsql, exp in AMOSTRAS
                     if not prog.pular('amostra:' + nome,
                                       impressao_amostra(nome, plsql, exp))]
        if pendentes:
            geradas = gerar_amostras(con, args.out, pendentes)
            falhas = validar_amostras(geradas, args.verboso)
            com_falha = {origem for origem, _ in falhas}
            for nome, plsql, exp in AMOSTRAS:
                if nome in pendentes:
                    prog.marcar('amostra:' + nome,
                                impressao_amostra(nome, plsql, exp),
                                nome in geradas and nome not in com_falha)
            todas_falhas += falhas
            prog.salvar()

    con.close()
    prog.salvar()

    # ── consolidado: o que está OK de um lado, o que quebrou do outro ────────
    print('\n' + '=' * 72)
    if total:
        print(f'OK      {total["PASS"]} verificação(ões) desta rodada passaram'
              + (f' | {total["SKIP"]} pulada(s)' if total['SKIP'] else ''))
    prog.resumo()
    if not todas_falhas:
        print('OK      nenhuma falha')
        print('=' * 72)
        print('\nTUDO OK')
        return 0

    print(f'FALHAS  {len(todas_falhas)}')
    origem_ant = None
    for origem, motivo in todas_falhas:
        if origem != origem_ant:
            print(f'\n  {origem}')
            origem_ant = origem
        print(f'    - {motivo}')
    print('\n' + '=' * 72)
    print('\nHOUVE FALHAS')
    return 1


def mostrar_status():
    """O que está concluído, sem conectar no banco."""
    import json
    try:
        with io.open(ESTADO, encoding='utf-8') as fh:
            e = json.load(fh)
    except (IOError, ValueError):
        print(f'Nenhum progresso guardado ({ESTADO} não existe).')
        return 0

    profunda, motivo = mudanca_profunda(e.get('fontes'), impressao_do_package())
    print(f'Alvo: {e.get("alvo")}')
    etapas = e.get('etapas', {})
    for chave in sorted(etapas):
        d = etapas[chave]
        print(f'  {"OK   " if d.get("situacao") == "ok" else "FALHOU"} '
              f'{chave:<40} {d.get("quando", "")}')
    feitas = sum(1 for d in etapas.values() if d.get('situacao') == 'ok')
    print(f'\n{feitas} de {len(etapas)} etapa(s) concluída(s).')
    if profunda:
        print(f'A próxima rodada vai executar TUDO: {motivo}')
    else:
        print('A próxima rodada pula as concluídas'
              + (f' ({motivo})' if motivo else '')
              + '. --reset zera, --full roda tudo sem zerar.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
