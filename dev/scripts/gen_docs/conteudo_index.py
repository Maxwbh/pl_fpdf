# -*- coding: utf-8 -*-
"""
O conteúdo da página inicial — `site/index.html` e `site/en/index.html`.

DOCUMENTO DE MANUTENÇÃO.

Mesma razão do `conteudo_api.py`: as duas páginas eram escritas à mão, uma de
cada lado, com o mesmo material repetido -- 6 cartões, 4 números, 7 janelas de
código, 3 passos de instalação. O que dói nesse arranjo não é o trabalho
dobrado, é a divergência calada: o comando de download dizia **v3.3.0** três
parágrafos abaixo da vitrine que anunciava 3.4.0.

Por isso a versão **não está escrita aqui**. Ela é lida de `src/PL_FPDF.pks` na
hora de gerar e entra por `{versao}`: o número da vitrine, o do exemplo de
`co_version` e o do link do release não têm como discordar do package.

Cada texto é um par `(português, inglês)`. O ícone do cartão e a imagem do
exemplo são os mesmos nas duas línguas -- o que muda neles é só o `alt`.
"""

HERO = {
    'h1': ("PDF <span class=\"grad\">100% em PL/SQL</span>, direto no Oracle Database",
           "PDF <span class=\"grad\">100% in PL/SQL</span>, right inside Oracle Database"),
    'sub': ("Gere, modifique, mescle e criptografe PDFs <b>sem sair do banco</b> —\nsem Java, sem middleware, sem dependências externas. Dois arquivos, um deploy.",
            "Generate, edit, merge and encrypt PDFs <b>without leaving the database</b> —\nno Java, no middleware, no external dependencies. Two files, one deploy."),
    # o primeiro é a versão, e vem do package
    'chips': [
        ("v{versao}", "v{versao}"),
        ("Oracle 19c+", "Oracle 19c+"),
        ("Licença MIT", "MIT licence"),
        ("CI automatizado", "Automated CI"),
        ("PIX & Boleto", "PIX & Boleto"),
    ],
    'botoes': [
        ("primary", "https://github.com/Maxwbh/pl_fpdf", ("Ver no GitHub", "View on GitHub")),
        ("ghost", "#instalacao", ("Como instalar", "How to install")),
    ],
    'janela': ("relatorio.sql — SQL*Plus", "report.sql — SQL*Plus"),
    'codigo': ([
        "DECLARE",
        "  l_pdf BLOB;",
        "BEGIN",
        "  -- cria o documento dentro do banco",
        "  PL_FPDF.Init('P', 'mm', 'A4');",
        "  PL_FPDF.AddPage();",
        "  PL_FPDF.SetFont('Arial', 'B', 16);",
        "  PL_FPDF.Cell(0, 10, 'Olá, Mundo!', '0', 1, 'C');",
        "",
        "  -- proteção com senha e permissões",
        "  l_pdf := PL_FPDF.EncryptPDF(",
        "    p_pdf        => PL_FPDF.OutputBlob(),",
        "    p_encryption => 'AES-256');",
        "END;",
    ], [
        "DECLARE",
        "  l_pdf BLOB;",
        "BEGIN",
        "  -- create the document inside the database",
        "  PL_FPDF.Init('P', 'mm', 'A4');",
        "  PL_FPDF.AddPage();",
        "  PL_FPDF.SetFont('Arial', 'B', 16);",
        "  PL_FPDF.Cell(0, 10, 'Hello, World!', '0', 1, 'C');",
        "",
        "  -- password protection and permissions",
        "  l_pdf := PL_FPDF.EncryptPDF(",
        "    p_pdf        => PL_FPDF.OutputBlob(),",
        "    p_encryption => 'AES-256');",
        "END;",
    ]),
}

FORK = ("<b>Linhagem.</b> A base de geração descende do porte PL/SQL de\n<a href=\"https://github.com/Pilooz/pl_fpdf\">Pierre-Gilles Levallois</a>, que trouxe para o\nOracle a <a href=\"http://www.fpdf.org/\">FPDF</a> de Olivier Plathey — daí vem a API que\ntalvez você já conheça. Sobre ela, <a href=\"https://github.com/Maxwbh\">@Maxwbh</a> mantém\ndesde 2019 um projeto próprio: manipulação de PDF, leitura de PDF 1.5+, criptografia\nAES-256, DEFLATE e INFLATE em PL/SQL e a extensão PIX/Boleto.",
        "<b>Lineage.</b> The generation core descends from the PL/SQL port by\n<a href=\"https://github.com/Pilooz/pl_fpdf\">Pierre-Gilles Levallois</a>, who brought Olivier\nPlathey's <a href=\"http://www.fpdf.org/\">FPDF</a> to Oracle — that is where the API you may\nalready know comes from. On top of it, <a href=\"https://github.com/Maxwbh\">@Maxwbh</a> has\nmaintained a project of its own since 2019: PDF manipulation, PDF 1.5+ reading, AES-256\nencryption, DEFLATE and INFLATE written in PL/SQL, and the PIX/Boleto extension.")

STATS = [
    ("<em>{versao}</em>", ("versão atual", "current version")),
    ("170", ("verificações automatizadas", "automated checks")),
    ("2", ("arquivos para o deploy", "files to deploy")),
    ("0", ("dependências externas", "external dependencies")),
]

RECURSOS = {
    "kicker": ("Recursos",
               "Features"),
    "h2": ("Tudo que seu relatório precisa, dentro do banco",
           "Everything your report needs, inside the database"),
    "lead": ("Da geração à proteção do documento — cada etapa executa como PL/SQL puro,\npronto para triggers, jobs, APEX e APIs.",
             "From generating the document to protecting it — every step runs as pure\nPL/SQL, ready for triggers, jobs, APEX and APIs."),
    'cards': [
        {
            'icone': "<svg viewBox=\"0 0 24 24\"><ellipse cx=\"12\" cy=\"5.5\" rx=\"8\" ry=\"3\"/><path d=\"M4 5.5v6c0 1.66 3.58 3 8 3s8-1.34 8-3v-6M4 11.5v6c0 1.66 3.58 3 8 3s8-1.34 8-3v-6\"/></svg>",
            'titulo': ("Roda dentro do banco", "Runs inside the database"),
            'texto': ("Sem servidor de aplicação, sem Java Stored Procedures — gere o PDF na própria trigger, job ou API PL/SQL.",
                      "No application server, no Java Stored Procedures — build the PDF in the trigger, job or PL/SQL API itself."),
        },
        {
            'icone': "<svg viewBox=\"0 0 24 24\"><path d=\"M6 3h9l4 4v14H6z\"/><path d=\"M15 3v4h4M9 12h6M9 16h4\"/></svg>",
            'titulo': ("Manipula PDFs existentes", "Edits existing PDFs"),
            'texto': ("Carregar, rotacionar, marcar d'água, mesclar e dividir arquivos PDF já prontos — inclusive PDF 1.5+, de qualquer produtor. Tudo por código.",
                      "Load, rotate, watermark, merge and split finished PDF files — including PDF 1.5+, from any producer. All in code."),
        },
        {
            'icone': "<svg viewBox=\"0 0 24 24\"><rect x=\"4\" y=\"10\" width=\"16\" height=\"10\" rx=\"2\"/><path d=\"M8 10V7a4 4 0 0 1 8 0v3M12 14v3\"/></svg>",
            'titulo': ("Segurança AES-256", "AES-256 security"),
            'texto': ("Criptografia AES-256, AES-128 ou RC4, com senha de usuário/proprietário e controle de permissões: imprimir, copiar, editar.",
                      "AES-256, AES-128 or RC4 encryption, with user/owner passwords and permission control: print, copy, edit."),
        },
        {
            'icone': "<svg viewBox=\"0 0 24 24\"><rect x=\"3\" y=\"3\" width=\"7\" height=\"7\" rx=\"1\"/><rect x=\"14\" y=\"3\" width=\"7\" height=\"7\" rx=\"1\"/><rect x=\"3\" y=\"14\" width=\"7\" height=\"7\" rx=\"1\"/><path d=\"M14 14h3v3h-3zM19 19h2v2h-2zM14 21h2\"/></svg>",
            'titulo': ("PIX e Boleto", "PIX and Boleto"),
            'texto': ("Extensão opcional para gerar QR Code PIX (EMV) e Boleto Bancário no padrão FEBRABAN.",
                      "Optional extension for PIX QR Codes (EMV) and FEBRABAN Boleto slips — the two Brazilian payment standards."),
        },
        {
            'icone': "<svg viewBox=\"0 0 24 24\"><path d=\"M20 7 12 3 4 7m16 0v10l-8 4m8-14-8 4M4 7v10l8 4m0-10v10\"/></svg>",
            'titulo': ("Zero dependências", "Zero dependencies"),
            'texto': ("Sem OWA, sem OrdImage, sem libs de terceiros. Apenas dois arquivos: <code>.pks</code> + <code>.pkb</code>.",
                      "No OWA, no OrdImage, no third-party libraries. Just two files: <code>.pks</code> + <code>.pkb</code>."),
        },
        {
            'icone': "<svg viewBox=\"0 0 24 24\"><path d=\"m8 9-4 3 4 3m8-6 4 3-4 3M13 6l-2 12\"/></svg>",
            'titulo': ("Open source (MIT)", "Open source (MIT)"),
            'texto': ("Código aberto, com CI automatizado, releases versionadas e histórico documentado.",
                      "Open code, with automated CI, versioned releases and a documented history."),
        },
    ],
}

# blocos na ordem em que saem: `lead` (parágrafo), `h3` (título dentro da
# seção, com o estilo que ele tinha), `imagem` (a tag <img> inteira -- o
# desenho é o mesmo, o `alt` muda de língua), `legenda` (parágrafo miúdo sob a
# imagem, onde também vive o link "ver o exemplo completo") e `grade` (duas
# janelas de código lado a lado)
EXEMPLOS = {
    "kicker": ("Exemplos", "Examples"),
    "h2": ("Do zero ao PDF em meia dúzia de linhas", "From nothing to a PDF in half a dozen lines"),
    'blocos': [
        ("lead", "",
         "A mesma API cobre a criação de documentos novos e a edição de arquivos existentes.",
         "The same API covers creating new documents and editing existing files."),
        ('grade', [
            {'titulo': ("criar_pdf.sql", "create_pdf.sql"),
             # a tabela de exemplo muda de nome na versão em inglês
             'traduz': {'documentos': 'documents'},
             'codigo': ([
                 "DECLARE",
                 "  l_pdf BLOB;",
                 "BEGIN",
                 "  PL_FPDF.Init('P', 'mm', 'A4');",
                 "  PL_FPDF.AddPage();",
                 "  PL_FPDF.SetFont('Arial', 'B', 16);",
                 "  PL_FPDF.Cell(0, 10, 'Olá, Mundo!',",
                 "               '0', 1, 'C');",
                 "",
                 "  l_pdf := PL_FPDF.OutputBlob();",
                 "  -- e agora é seu: grave, envie, devolva",
                 "  INSERT INTO documentos (pdf) VALUES (l_pdf);",
                 "END;",
             ], [
                 "DECLARE",
                 "  l_pdf BLOB;",
                 "BEGIN",
                 "  PL_FPDF.Init('P', 'mm', 'A4');",
                 "  PL_FPDF.AddPage();",
                 "  PL_FPDF.SetFont('Arial', 'B', 16);",
                 "  PL_FPDF.Cell(0, 10, 'Hello, World!',",
                 "               '0', 1, 'C');",
                 "",
                 "  l_pdf := PL_FPDF.OutputBlob();",
                 "  -- and it is yours: store it, send it, return it",
                 "  INSERT INTO documents (pdf) VALUES (l_pdf);",
                 "END;",
             ])},
            {'titulo': ("editar_pdf.sql", "edit_pdf.sql"),
             # a tabela de exemplo muda de nome na versão em inglês
             'traduz': {'documentos': 'documents'},
             'codigo': ([
                 "DECLARE",
                 "  l_pdf BLOB;",
                 "BEGIN",
                 "  SELECT pdf_blob INTO l_pdf",
                 "    FROM documentos WHERE id = 1;",
                 "",
                 "  PL_FPDF.LoadPDF(l_pdf);",
                 "  PL_FPDF.RotatePage(1, 90);",
                 "  PL_FPDF.AddWatermark('CONFIDENCIAL', 0.3);",
                 "  l_pdf := PL_FPDF.OutputModifiedPDF();",
                 "END;",
             ], [
                 "DECLARE",
                 "  l_pdf BLOB;",
                 "BEGIN",
                 "  SELECT pdf_blob INTO l_pdf",
                 "    FROM documents WHERE id = 1;",
                 "",
                 "  PL_FPDF.LoadPDF(l_pdf);",
                 "  PL_FPDF.RotatePage(1, 90);",
                 "  PL_FPDF.AddWatermark('CONFIDENTIAL', 0.3);",
                 "  l_pdf := PL_FPDF.OutputModifiedPDF();",
                 "END;",
             ])},
        ]),
        ("h3", "style=\"margin-top:36px\"",
         "E quando o documento é difícil: o layout de um boleto",
         "And when the document is hard: the layout of a Boleto"),
        ("lead", "",
         "Página A4, três variantes de Helvetica em quatro corpos, 50 caixas\nposicionadas ao milímetro em duas vias, a coluna do dinheiro alinhada à direita e o\ncódigo de barras ITF de 44 dígitos que um leitor de banco lê. <b>Sem imagem nenhuma</b>\n— logotipo, réguas e barras são desenho vetorial, como num boleto de verdade.",
         "An A4 page, three Helvetica variants in four sizes, 50 boxes positioned to\nthe millimetre across two copies, the money column right-aligned, and the 44-digit ITF\nbarcode a bank scanner actually reads. <b>Not a single image</b> — logo, rules and bars\nare vector drawing, the way a real Boleto is made. (A Boleto is the Brazilian bank\npayment slip.)"),
        ("imagem", "",
         "<img src=\"assets/exemplo-boleto.png\" width=\"560\"\nstyle=\"max-width:100%;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.35)\"\nalt=\"Boleto bancário gerado pelo PL_FPDF: duas vias, grade de campos e código de barras ITF\">",
         "<img src=\"../assets/exemplo-boleto.png\" width=\"560\"\nstyle=\"max-width:100%;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.35)\"\nalt=\"Bank Boleto generated by PL_FPDF: two copies, a grid of fields and an ITF barcode\">"),
        ("legenda", "style=\"text-align:center;font-size:.9em;opacity:.75\"",
         "Saída real do <code>examples/boleto.sql</code>, gerada dentro do Oracle.\nOs 44 dígitos do código de barras chegam prontos — o PL_FPDF desenha,\ncálculo de cobrança é outro assunto.",
         "Real output of <code>examples/boleto.sql</code>, produced inside Oracle.\nThe 44 barcode digits arrive ready-made — PL_FPDF draws;\ncomputing the charge is somebody else's job."),
        ('grade', [
            {'titulo': ("boleto.sql", "boleto.sql"),
             'codigo': ([
                 "-- rótulo miúdo em cima, valor embaixo",
                 "PL_FPDF.Rect(px, py, pw, ph, 'D');",
                 "PL_FPDF.SetFont('Arial', '', 6);",
                 "PL_FPDF.SetXY(px, py + 0.7);",
                 "PL_FPDF.Cell(pw, 2.4, protulo, '0', 0, 'L');",
                 "",
                 "PL_FPDF.SetFont('Arial', 'B', 9);",
                 "PL_FPDF.SetXY(px, py + 3.2);",
                 "PL_FPDF.Cell(pw, 3.4, pvalor, '0', 0, 'R');",
             ], [
                 "-- tiny label on top, value underneath",
                 "PL_FPDF.Rect(px, py, pw, ph, 'D');",
                 "PL_FPDF.SetFont('Arial', '', 6);",
                 "PL_FPDF.SetXY(px, py + 0.7);",
                 "PL_FPDF.Cell(pw, 2.4, protulo, '0', 0, 'L');",
                 "",
                 "PL_FPDF.SetFont('Arial', 'B', 9);",
                 "PL_FPDF.SetXY(px, py + 3.2);",
                 "PL_FPDF.Cell(pw, 3.4, pvalor, '0', 0, 'R');",
             ])},
            {'titulo': ("codigo_de_barras.sql", "barcode.sql"),
             'codigo': ([
                 "-- 103 x 13 mm, como manda a FEBRABAN",
                 "PL_FPDF.AddBarcode(",
                 "  16.5, 233, 103, 13,",
                 "  '34197167700000150001' ||",
                 "  '090000012323073123451000',",
                 "  'ITF', FALSE);",
                 "",
                 "-- e o PDF sai daqui, do próprio banco",
                 "l_pdf := PL_FPDF.OutputBlob();",
             ], [
                 "-- 103 x 13 mm, as FEBRABAN requires",
                 "PL_FPDF.AddBarcode(",
                 "  16.5, 233, 103, 13,",
                 "  '34197167700000150001' ||",
                 "  '090000012323073123451000',",
                 "  'ITF', FALSE);",
                 "",
                 "-- and the PDF comes out here, from the database",
                 "l_pdf := PL_FPDF.OutputBlob();",
             ])},
        ]),
        ("legenda", "style=\"margin-top:18px\"",
         "<a class=\"btn ghost\" href=\"https://github.com/Maxwbh/pl_fpdf/blob/master/examples/boleto.sql\">\nVer o exemplo completo</a>",
         "<a class=\"btn ghost\" href=\"https://github.com/Maxwbh/pl_fpdf/blob/master/examples/boleto.sql\">\nSee the full example</a>"),
        ("h3", "style=\"margin-top:44px\"",
         "E o irmão colorido: um ingresso de evento",
         "And its colourful sibling: an event ticket"),
        ("lead", "",
         "O boleto prova grade. O ingresso prova o resto: <b>cor</b> —\nfaixa preenchida com texto branco por cima, painéis cinzas —, <b>QR Code e\nCode 39 na mesma página</b> dizendo o mesmo código, <b>uma página por\ningresso</b> e uma forma que não é retângulo, o rabinho do balão. Também\nsem imagem nenhuma.",
         "The Boleto proves the grid. The ticket proves the rest: <b>colour</b> —\na filled band with white text over it, grey panels —, <b>a QR Code and a Code 39 on the\nsame page</b> saying the same code, <b>one page per ticket</b>, and a shape that is not a\nrectangle: the little tail of the speech bubble. Again, not a single image."),
        ("imagem", "",
         "<img src=\"assets/exemplo-ticket.png\" width=\"470\"\nstyle=\"max-width:100%;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.35)\"\nalt=\"Ingresso de evento gerado pelo PL_FPDF: cabeçalho colorido, QR Code e código de barras\">",
         "<img src=\"../assets/exemplo-ticket.png\" width=\"470\"\nstyle=\"max-width:100%;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.35)\"\nalt=\"Event ticket generated by PL_FPDF: colourful header, QR Code and barcode\">"),
        ("legenda", "style=\"text-align:center;font-size:.9em;opacity:.75\"",
         "Saída real do <code>examples/ticket.sql</code>, gerada dentro do Oracle.",
         "Real output of <code>examples/ticket.sql</code>, produced inside Oracle."),
        ('grade', [
            {'titulo': ("cores.sql", "colours.sql"),
             'codigo': ([
                 "-- painel colorido, e o título em branco",
                 "PL_FPDF.SetFillColor(13, 25, 44);",
                 "PL_FPDF.Rect(12, 13.5, 186, 36, 'F');",
                 "",
                 "PL_FPDF.SetTextColor(255, 255, 255);",
                 "PL_FPDF.SetFont('Arial', 'B', 17);",
                 "PL_FPDF.SetXY(16, 18);",
                 "PL_FPDF.Cell(178, 9, l_titulo, '0', 0, 'L');",
             ], [
                 "-- colourful panel, and the title in white",
                 "PL_FPDF.SetFillColor(13, 25, 44);",
                 "PL_FPDF.Rect(12, 13.5, 186, 36, 'F');",
                 "",
                 "PL_FPDF.SetTextColor(255, 255, 255);",
                 "PL_FPDF.SetFont('Arial', 'B', 17);",
                 "PL_FPDF.SetXY(16, 18);",
                 "PL_FPDF.Cell(178, 9, l_title, '0', 0, 'L');",
             ])},
            {'titulo': ("simbolos.sql", "symbols.sql"),
             'codigo': ([
                 "-- o mesmo código em duas simbologias,",
                 "-- para leitura na portaria",
                 "PL_FPDF.AddQRCode(",
                 "  p_x => 156, p_y => 58,",
                 "  p_size => 32, p_data => l_codigo);",
                 "",
                 "PL_FPDF.AddBarcode(",
                 "  45, 117, 120, 10,",
                 "  l_codigo, 'CODE39', FALSE);",
             ], [
                 "-- the same code in two symbologies,",
                 "-- to be scanned at the gate",
                 "PL_FPDF.AddQRCode(",
                 "  p_x => 156, p_y => 58,",
                 "  p_size => 32, p_data => l_code);",
                 "",
                 "PL_FPDF.AddBarcode(",
                 "  45, 117, 120, 10,",
                 "  l_code, 'CODE39', FALSE);",
             ])},
        ]),
        ("legenda", "style=\"margin-top:18px\"",
         "<a class=\"btn ghost\" href=\"https://github.com/Maxwbh/pl_fpdf/blob/master/examples/ticket.sql\">\nVer o exemplo do ingresso</a>",
         "<a class=\"btn ghost\" href=\"https://github.com/Maxwbh/pl_fpdf/blob/master/examples/ticket.sql\">\nSee the ticket example</a>"),
    ],
}

INSTALACAO = {
    "kicker": ("Instalação",
               "Install"),
    "h2": ("Três passos e está no ar",
           "Three steps and it is running"),
    "lead": ("Compatível com Oracle 19c ou superior. Nenhum objeto além dos packages é criado.",
             "Works on Oracle 19c or later. No object other than the packages is created."),
    'passos': [
        {
            'titulo': ("Baixe um arquivo", "Download one file"),
            'texto': ("Sem clone: o instalador completo em um <code>.sql</code>, com o SHA-256 ao lado.",
                      "No clone: the whole installer in a single <code>.sql</code>, with its SHA-256 beside it."),
            'codigo': "<a href=\"https://github.com/Maxwbh/pl_fpdf/releases/latest/download/pl_fpdf_install.sql\">pl_fpdf_install.sql</a>",
            'depois': ("Sempre a última versão publicada.", "Always the latest published version."),
        },
        {
            'titulo': ("Execute", "Run it"),
            'texto': ("Abra na SQL Window (F8) ou rode no SQL*Plus. Só SQL — nenhum comando de ferramenta.",
                      "Open it in a SQL Window (F8) or run it in SQL*Plus. Plain SQL — no tool-specific command."),
            'codigo': "@pl_fpdf_install.sql",
        },
        {
            'titulo': ("Confirme a versão", "Check the version"),
            'texto': ("Pronto para gerar o primeiro PDF.",
                      "Ready to produce the first PDF."),
            'codigo': "SELECT PL_FPDF.co_version FROM DUAL;\n-- {versao}",
        },
    ],
    'nota': ("<b>Para produção, fixe a versão.</b>\nO link acima serve sempre a mais nova — bom para experimentar, ruim para um\nchamado de mudança. Cada versão tem URL própria e imutável na\n<a href=\"https://github.com/Maxwbh/pl_fpdf/releases\">página de releases</a>, com o\n<code>SHA256.txt</code> ao lado para conferir o que foi baixado:",
             "<b>Pin the version for production.</b>\nThe link above always serves the newest one — fine to try it out, wrong for a\nchange ticket. Every version has its own immutable URL on the\n<a href=\"https://github.com/Maxwbh/pl_fpdf/releases\">releases page</a>, with a\n<code>SHA256.txt</code> beside it to verify what you downloaded:"),
    'curl': "curl -LO https://github.com/Maxwbh/pl_fpdf/releases/download/v{versao}/pl_fpdf_install.sql\ncurl -LO https://github.com/Maxwbh/pl_fpdf/releases/download/v{versao}/SHA256.txt\nsha256sum -c <(echo \"$(cat SHA256.txt)  pl_fpdf_install.sql\")",
}

FINAL = {
    'h2': ("Achou útil? Deixe uma estrela ⭐", "Found it useful? Leave a star ⭐"),
    'texto': ("Estrelas aumentam a visibilidade do projeto para outros desenvolvedores Oracle —\ne são o melhor jeito de apoiar o trabalho.",
              "Stars make the project easier to find for other Oracle developers —\nand they are the best way to support the work."),
    'botoes': [
        ("primary", "https://github.com/Maxwbh/pl_fpdf/stargazers", ("Dar estrela no GitHub", "Star it on GitHub")),
        ("ghost", "https://github.com/Maxwbh/pl_fpdf/discussions", ("Tirar dúvidas nas Discussions", "Ask a question in Discussions")),
    ],
}
