# -*- coding: utf-8 -*-
"""
O texto em inglês da referência da API, pareado com o português que ele traduz.

DOCUMENTO DE MANUTENÇÃO.

Por que existe
--------------
A spec é só PT-BR, por decisão: o comentário vive junto do código e quem o
mantém escreve em português. A página em inglês, porém, é publicada e tem
leitor -- `site/en/reference.html` e `docs/API_REFERENCE_EN.md`.

Enquanto as duas páginas eram escritas à mão, o inglês divergia do português
sem que nada acusasse: a versão EN não listava os códigos de erro que a spec
levanta, e o `pborder` continuava descrito como "'0', '1' ou uma combinação de
'L','T','R','B'" depois de o texto em PT ter sido reescrito justamente por ser
incompreensível.

Gerar as duas da mesma estrutura resolve metade: assinatura, tipo, default,
grupo, exemplo e código de erro passam a sair da spec nas duas línguas. A outra
metade é a prosa, que alguém tem de escrever -- e é o que está aqui.

O pareamento é o que protege
----------------------------
Cada entrada guarda o **par**: o português de quando o inglês foi escrito, e o
inglês. O gerador compara o PT guardado com o PT que está na spec hoje; se
mudou, ele **para** e diz qual texto ficou para trás. Sem isso a página em
inglês envelheceria em silêncio, que foi exatamente como ela envelheceu.

Como atualizar
--------------
Mudou o Javadoc em PT? O `generate.py` falha apontando a entrada. Corrija aqui
o par (`pt` novo, `en` novo) e rode de novo. Uma API nova entra com todos os
seus textos; sem eles o gerador recusa em vez de publicar página pela metade.
"""


import re

# nome do grupo em inglês (o `id` da âncora não muda: é endereço
# público, e as duas páginas apontam para o mesmo lugar)
CATEGORIAS_EN = {
    "Ciclo de vida": "Lifecycle",
    "Páginas e posicionamento": "Pages and positioning",
    "Fontes e UTF-8": "Fonts and UTF-8",
    "Escrita de texto": "Writing text",
    "Cores e desenho": "Colours and drawing",
    "Imagens": "Images",
    "Links": "Links",
    "Cabeçalho e rodapé": "Header and footer",
    "QR Code e código de barras": "QR codes and barcodes",
    "Metadados e configuração": "Metadata and document setup",
    "Saída do documento": "Document output",
    "Manipulação de PDF existente": "Manipulating an existing PDF",
    "Overlays": "Overlays",
    "Multi-PDF (merge, split, extract)": "Multi-PDF (merge, split, extract)",
    "Segurança e criptografia": "Security and encryption",
    "Diagnóstico e utilidades": "Diagnostics and utilities",
}

# (código, texto em PT) -> texto em inglês. A chave leva o texto
# porque o mesmo código descreve situações diferentes conforme a
# API: -20100 é "qualquer falha na escrita" no Cell e "sempre; é
# o que esta rotina faz" no Error.
ERROS = {
    ("20001", "orientação inválida"):
        "invalid orientation",
    ("20001", "orientação inválida; só P ou L"):
        "invalid orientation; only P or L",
    ("20002", "unidade de medida inválida"):
        "invalid unit of measurement",
    ("20002", "unidade inválida; só mm, cm, in ou pt"):
        "invalid unit; only mm, cm, in or pt",
    ("20003", "codificação não suportada"):
        "unsupported encoding",
    ("20005", "Init ainda não foi chamado"):
        "Init has not been called yet",
    ("20005", "Init ainda não foi chamado. Antes de agosto/2026 esta chamada seguia em frente e devolvia um PDF vazio, sem apontar a causa."):
        "Init has not been called yet. Before August 2026 this call carried on and returned an empty PDF, without pointing to the cause.",
    ("20100", "destino desconhecido, ou falha na gravação"):
        "unknown destination, or a failure while writing",
    ("20100", "estilo inválido"):
        "invalid style",
    ("20100", "falha ao buscar ou interpretar a imagem, com a pilha original preservada"):
        "failure fetching or parsing the image, with the original stack preserved",
    ("20100", "falha ao fechar ou montar o documento, com a pilha original preservada"):
        "failure closing or assembling the document, with the original stack preserved",
    ("20100", "modo de zoom ou de layout desconhecido"):
        "unknown zoom or layout mode",
    ("20100", "nível fora da faixa 0..4"):
        "level outside the 0..4 range",
    ("20100", "qualquer falha na escrita da célula. O Cell embrulha o erro original neste código, mas preserva a pilha (keeperrorstack), de modo que a causa -- um ORA-20203 de caractere fora do WinAnsi, por exemplo -- continua visível no rastro."):
        "any failure while writing the cell. Cell wraps the original error in this code, but keeps the stack (keeperrorstack), so the cause -- an ORA-20203 for a character outside WinAnsi, for instance -- stays visible in the trace.",
    ("20100", "qualquer falha na escrita, com a pilha original preservada"):
        "any failure while writing, with the original stack preserved",
    ("20100", "sempre; é o que esta rotina faz"):
        "always; that is what this routine does",
    ("20101", "dimensões inválidas no formato livre"):
        "invalid dimensions in the free-form format",
    ("20103", "formato desconhecido"):
        "unknown page format",
    ("20104", "giro inválido"):
        "invalid rotation",
    ("20106", "a página não existe"):
        "the page does not exist",
    ("20107", "orientação inválida"):
        "invalid orientation",
    ("20110", "giro inválido"):
        "invalid rotation",
    ("20111", "só o giro de 0 grau é suportado; use CellRotated"):
        "only 0-degree rotation is supported; use CellRotated",
    ("20201", "fonte não encontrada -- nem entre as padrão, nem no registro de TrueType"):
        "font not found -- neither among the core fonts nor in the TrueType registry",
    ("20202", "arquivo de fonte inválido"):
        "invalid font file",
    ("20203", "caractere fora do WinAnsi"):
        "character outside WinAnsi",
    ("20206", "fonte não carregada"):
        "font not loaded",
    ("20210", "nome da fonte vazio"):
        "font name is empty",
    ("20211", "BLOB da fonte nulo"):
        "font BLOB is null",
    ("20301", "cabeçalho de imagem inválido"):
        "invalid image header",
    ("20301", "cabeçalho inválido, BLOB vazio ou nome ausente"):
        "invalid header, empty BLOB or missing name",
    ("20302", "não foi possível buscar a imagem"):
        "the image could not be fetched",
    ("20303", "formato não suportado"):
        "unsupported format",
    ("20306", "modo de entrega ao navegador não é mais suportado; a mensagem aponta OutputBlob e o cabeçalho Content-Type"):
        "delivering straight to the browser is no longer supported; the message points to OutputBlob and the Content-Type header",
    ("20401", "diretório inválido"):
        "invalid directory",
    ("20402", "sem permissão de escrita"):
        "no write permission",
    ("20402", "sem permissão de leitura"):
        "no read permission",
    ("20403", "falha ao gravar"):
        "write failure",
    ("20501", "componente fora de 0..255"):
        "component outside 0..255",
    ("20502", "espessura zero ou negativa"):
        "zero or negative line width",
    ("20601", "destino não é URL -- link interno ou NULL"):
        "destination is not a URL -- internal link or NULL",
    ("20601", "link interno não implementado"):
        "internal link is not implemented",
    ("20800", "PDF nulo ou pequeno demais para ser válido"):
        "PDF is null or too small to be valid",
    ("20800", "PDF nulo, ou pequeno demais para ter cabeçalho e trailer"):
        "PDF is null, or too small to hold a header and a trailer",
    ("20801", "Cabeçalho PDF inválido"):
        "invalid PDF header",
    ("20801", "cabeçalho %PDF-x.x ausente ou malformado"):
        "%PDF-x.x header missing or malformed",
    ("20802", "startxref não encontrado"):
        "startxref not found",
    ("20803", "Tabela xref inválida"):
        "invalid xref table",
    ("20804", "Objeto Root não encontrado"):
        "Root object not found",
    ("20809", "Nenhum PDF carregado"):
        "no PDF loaded",
    ("20809", "nenhum PDF carregado -- chame LoadPDF antes"):
        "no PDF loaded -- call LoadPDF first",
    ("20810", "/Pages não encontrado no catálogo do PDF"):
        "/Pages not found in the PDF catalog",
    ("20810", "Número de página inválido"):
        "invalid page number",
    ("20812", "número de página fora da faixa"):
        "page number out of range",
    ("20813", "giro inválido; só 0, 90, 180 ou 270"):
        "invalid rotation; only 0, 90, 180 or 270",
    ("20814", "a página já estava marcada para remoção"):
        "the page was already marked for removal",
    ("20816", "texto da marca vazio"):
        "watermark text is empty",
    ("20817", "opacidade fora de 0..1"):
        "opacity outside 0..1",
    ("20818", "rotação fora de 0, 45, 90, 135, 180, 225, 270, 315"):
        "rotation outside 0, 45, 90, 135, 180, 225, 270, 315",
    ("20819", "o PDF não foi modificado (sem alterações para aplicar)"):
        "the PDF has not been modified (no changes to apply)",
    ("20820", "todas as páginas foram removidas (não dá para gerar PDF vazio)"):
        "every page was removed (an empty PDF cannot be generated)",
    ("20821", "Coordenadas de posição inválidas"):
        "invalid position coordinates",
    ("20821", "Coordenadas de posição inválidas, ou opacidade fora de 0.0..1.0"):
        "invalid position coordinates, or opacity outside 0.0..1.0",
    ("20821", "orientação inválida"):
        "invalid orientation",
    ("20823", "formato de imagem inválido -- só JPEG ou PNG"):
        "invalid image format -- only JPEG or PNG",
    ("20823", "imagem inválida ou não suportada. PNG com alfa e entrelaçado são suportados; recusados são o entrelaçado abaixo de 8 bits por componente, o indexado E entrelaçado, e imagens acima de 4 megapixels no caminho que reprocessa pixels"):
        "invalid or unsupported image. PNG with alpha and interlaced PNG are supported; refused are interlaced below 8 bits per component, indexed AND interlaced, and images above 4 megapixels on the path that reprocesses pixels",
    ("20824", "Dimensões da imagem inválidas"):
        "invalid image dimensions",
    ("20825", "Sobreposição não encontrada"):
        "overlay not found",
    ("20828", "ID do PDF já carregado"):
        "PDF id already loaded",
    ("20829", "Máximo de PDFs excedido (10 max)"):
        "maximum number of loaded PDFs exceeded (10)",
    ("20830", "identificador vazio ou longo demais"):
        "identifier empty or too long",
    ("20831", "ID do PDF não encontrado"):
        "PDF id not found",
    ("20832", "Nenhum ID de PDF fornecido"):
        "no PDF id was given",
    ("20833", "ID de PDF na lista não carregado"):
        "a PDF id in the list is not loaded",
    ("20834", "Mesclagem falhou"):
        "merge failed",
    ("20835", "Nenhum intervalo fornecido"):
        "no range was given",
    ("20836", "Intervalos sobrepostos"):
        "overlapping ranges",
    ("20838", "Especificação de páginas inválida"):
        "invalid page specification",
    ("20839", "Número de página fora do intervalo"):
        "page number out of range",
    ("20841", "Dicionário de objeto grande demais para renumerar"):
        "object dictionary too large to renumber",
    ("20841", "dicionário de objeto grande demais para renumerar"):
        "object dictionary too large to renumber",
    ("20843", "xref em stream malformada"):
        "malformed cross-reference stream",
    ("20846", "o /Resources da página não pode ser sobreposto (subdicionário indireto compartilhado)"):
        "the page /Resources cannot be overlaid (shared indirect sub-dictionary)",
    ("20847", "object stream malformado"):
        "malformed object stream",
    ("20848", "predictor não suportado na xref em stream"):
        "unsupported predictor in the cross-reference stream",
    ("20850", "Método de criptografia inválido"):
        "invalid encryption method",
    ("20850", "método de cifragem não suportado"):
        "unsupported encryption method",
    ("20851", "Senha obrigatória"):
        "a password is required",
    ("20851", "senha inválida"):
        "invalid password",
    ("20852", "Falha na criptografia"):
        "encryption failed",
    ("20853", "PDF não está criptografado"):
        "the PDF is not encrypted",
    ("20854", "Senha inválida"):
        "invalid password",
    ("20855", "Falha na descriptografia"):
        "decryption failed",
    ("20856", "SetEncryption tem de ser chamada antes"):
        "SetEncryption must be called first",
    ("20857", "versão de PDF inválida"):
        "invalid PDF version",
    ("20857", "versão de PDF inválida; só 1.4, 1.5, 1.6, 1.7 ou 2.0"):
        "invalid PDF version; only 1.4, 1.5, 1.6, 1.7 or 2.0",
    ("20858", "AES-128 exige PDF 1.5 ou maior, e AES-256 exige 1.7"):
        "AES-128 requires PDF 1.5 or higher, and AES-256 requires 1.7",
    ("20859", "o PDF já está cifrado; decifre antes"):
        "the PDF is already encrypted; decrypt it first",
    ("20860", "PDF inválido: /Root não encontrado no trailer"):
        "invalid PDF: /Root not found in the trailer",
    ("20861", "dicionário /Encrypt não encontrado no PDF"):
        "/Encrypt dictionary not found in the PDF",
    ("20863", "chave RC4 vazia"):
        "empty RC4 key",
    ("20864", "conteúdo acima do limite que o RC4 desta base trata"):
        "content above the limit this RC4 implementation handles",
    ("20870", "conteúdo vazio"):
        "empty content",
    ("20871", "tamanho não positivo"):
        "size is not positive",
    ("20872", "nível de correção inválido"):
        "invalid error-correction level",
    ("20873", "conteúdo além da capacidade do QR Code"):
        "content beyond the QR Code capacity",
    ("20880", "código vazio"):
        "empty code",
    ("20881", "largura ou altura não positiva"):
        "width or height is not positive",
    ("20882", "simbologia não suportada"):
        "unsupported symbology",
    ("20883", "CODE39 não aceita o caractere informado"):
        "CODE39 does not accept the given character",
    ("20884", "CODE128 aceita só ASCII de 32 a 126"):
        "CODE128 accepts only ASCII 32 to 126",
    ("20885", "EAN com quantidade de dígitos errada"):
        "EAN with the wrong number of digits",
    ("20886", "EAN com dígito verificador inválido"):
        "EAN with an invalid check digit",
    ("20887", "ITF14 exige 13 dígitos (verificador calculado) ou 14"):
        "ITF14 requires 13 digits (check digit computed) or 14",
    ("20888", "ITF sem nenhum dígito no conteúdo"):
        "ITF with no digit in the content",
    ("20890", "Stream truncado"):
        "truncated stream",
    ("20891", "Dados DEFLATE malformados"):
        "malformed DEFLATE data",
    ("20892", "Cabeçalho zlib inválido"):
        "invalid zlib header",
    ("20893", "Saída passou de p_max_bytes"):
        "output exceeded p_max_bytes",
}

# API -> textos, cada um no par (português de origem, inglês)
TEXTOS = {
    "Init": {
        "descricao": ("Prepara o gerador para um documento novo. Substitui o construtor legado fpdf(), acrescentando validação dos argumentos e os buffers em CLOB. Chamar de novo com um documento em andamento descarta o anterior.",
                      "Initialises a new PDF document. This must be the first call of any generation; it sets the orientation, unit of measurement, page format and encoding used by every other API."),
        "params": {
            "p_orientation": ("orientação da página: 'P' (Portrait, retrato) ou 'L' (Landscape, paisagem)",
                             "Default page orientation. 'P' (portrait, the default) or 'L' (landscape)"),
            "p_unit": ("unidade de medida ('mm', 'cm', 'in', 'pt')",
                      "Unit of measurement for every coordinate and dimension in the document. 'mm' (default), 'cm', 'pt' or 'in'"),
            "p_format": ("formato da página ('A4', 'Letter', 'Legal')",
                        "Default page format. 'A3', 'A4' (default), 'A5', 'Letter' or 'Legal'"),
            "p_encoding": ("codificação de entrada",
                          "Character encoding of the text. 'UTF-8' (default) or 'WINDOWS-1252'"),
        },
    },
    "Reset": {
        "descricao": ("Devolve o package ao estado inicial: libera os CLOBs temporários e esvazia todas as tabelas de estado (fontes, imagens, links, metadados, mudanças de orientação). O package tem estado de sessão, e quem gera documentos em lote precisa chamar isto entre um e outro — sem isso, a configuração de um vaza para o seguinte.",
                      "Returns the PDF engine to its initial state, freeing temporary CLOBs and clearing every internal array. Use it between documents generated in the same job, or at the end of long routines."),
    },
    "IsInitialized": {
        "descricao": ("Diz se Init (ou fpdf) já foi chamado nesta sessão.",
                      "Tells whether a document is currently being built in this session."),
        "retorno": ("BOOLEAN - TRUE se inicializado",
                    "BOOLEAN — TRUE if Init has been called and the document has not been finalised."),
    },
    "AddTTFFont": {
        "descricao": ("Registra uma fonte TrueType a partir de um BLOB e a deixa disponível para o SetFont, pelo nome dado aqui. As tabelas do arquivo são lidas de verdade -- head, hhea, hmtx, cmap, OS/2 e post --, e a fonte vai embutida no PDF como /FontFile2. O arquivo cresce: o programa da fonte sai em hexadecimal, então ocupa o DOBRO do tamanho dela, e ainda não há subset — a fonte inteira vai embutida, mesmo que o documento use dez glifos. Para texto em português com acento não é preciso embutir nada: as fontes padrão escrevem acentuado desde a 3.4.0.",
                      "Registers a TrueType font from a BLOB and makes it available to `SetFont`. The file's tables are really parsed, and the font is embedded in the PDF as `/FontFile2`."),
        "params": {
            "p_font_name": ("nome pelo qual SetFont a chamará",
                           "Name by which the font will be referenced in SetFont. Free text, e.g. 'Roboto'"),
            "p_font_blob": ("o arquivo.ttf",
                           "Binary content of the .ttf file. Non-null BLOB holding a valid TrueType font"),
            "p_encoding": ("codificação da fonte",
                          "Font encoding. 'UTF-8' (default) or 'WINDOWS-1252'"),
            "p_embed": ("embutir no PDF",
                       "Embeds the font program in the PDF. TRUE or FALSE; TRUE is the default"),
        },
    },
    "LoadTTFFromFile": {
        "descricao": ("Lê um .ttf de um DIRECTORY do banco e o registra como o AddTTFFont. Exige READ no diretório concedido ao schema; sem isso, AddTTFFont recebe os bytes direto, sem concessão nenhuma.",
                      "Loads a TrueType font from a file inside an Oracle DIRECTORY."),
        "params": {
            "p_font_name": ("nome pelo qual SetFont a chamará",
                           "Name to use in SetFont. Free text"),
            "p_file_path": ("nome do arquivo",
                           "Name of the .ttf file inside the directory. E.g. 'Roboto-Regular.ttf'"),
            "p_directory": ("DIRECTORY do banco",
                           "Oracle DIRECTORY with read permission. Default: 'FONTS_DIR'"),
            "p_encoding": ("codificação da fonte",
                          "Font encoding. 'UTF-8' (default) or 'WINDOWS-1252'"),
        },
    },
    "IsTTFFontLoaded": {
        "descricao": ("Diz se a fonte está registrada nesta sessão, e portanto disponível para o SetFont. O nome não diferencia maiúsculas de minúsculas.",
                      "Checks whether a TrueType font has already been loaded in this session."),
        "params": {
            "p_font_name": ("nome da fonte",
                           "Font name. The same one used when loading"),
        },
        "retorno": ("BOOLEAN - TRUE se carregada",
                    "BOOLEAN — TRUE if the font is in the cache. **See also:** [AddTTFFont](#addttffont), [ClearTTFFontCache](#clearttffontcache)"),
    },
    "GetTTFFontInfo": {
        "descricao": ("Devolve o registro da fonte: os bytes guardados e as métricas lidas do arquivo -- unidades por em, ascendente, descendente, altura de caixa alta, a caixa e o ângulo do itálico. Tudo já reescalado para as 1000 unidades por em do PDF, menos o units_per_em, que é o do arquivo.",
                      "Returns a TrueType font's record: the stored bytes and the metrics parsed from the file, rescaled to the PDF's 1000 units per em."),
        "params": {
            "p_font_name": ("nome da fonte",
                           "Font name. The same one used when loading"),
        },
        "retorno": ("recTTFFont - as métricas da fonte",
                    "recTTFFont — record with the font's metrics and information. **See also:** [AddTTFFont](#addttffont)"),
    },
    "ClearTTFFontCache": {
        "descricao": ("Descarrega as fontes TrueType e libera os LOBs temporários delas. Vale chamar ao fim de um lote: cada fonte embutida ocupa centenas de KB na sessão.",
                      "Discards every loaded TrueType font, freeing session memory."),
    },
    "UTF8ToPDFString": {
        "descricao": ("Escapa os caracteres que a sintaxe de string do PDF reserva -- o parêntese e a barra invertida. NÃO converte codificação: quem escreve texto pelas rotinas normais (Cell, Write, Text) não precisa chamar isto, porque a conversão para WinAnsi já acontece lá dentro.",
                      "Converts UTF-8 text to the PDF's internal representation. Called internally; useful when debugging accented characters."),
        "params": {
            "p_text": ("o texto",
                      "Text to convert. Any VARCHAR2 in UTF-8"),
            "p_escape": ("escapar os caracteres reservados",
                        "Escapes the PDF special characters (parentheses and backslash). TRUE or FALSE"),
        },
        "retorno": ("VARCHAR2 - o texto pronto para ir entre parênteses num objeto PDF",
                    "VARCHAR2 — the converted text."),
    },
    "GetCurrentFontSize": {
        "descricao": ("Devolve o corpo da fonte em uso, em pontos.",
                      "Returns the size of the current font."),
        "retorno": ("NUMBER - o tamanho em pontos",
                    "NUMBER — size in points. **See also:** [SetFont](#setfont)"),
    },
    "GetCurrentFontStyle": {
        "descricao": ("Devolve o estilo em uso: '' (normal), 'B' (Bold, negrito), 'I' (Italic, itálico), 'U' (Underline, sublinhado) ou a combinação. Sempre em MAIÚSCULA: o SetFont normaliza, então 'b' entra e 'B' volta.",
                      "Returns the style of the current font."),
        "retorno": ("VARCHAR2 - o estilo corrente",
                    "VARCHAR2 — '', 'B', 'I', 'BI' or 'U', always **uppercase**. > `SetFont` normalises it: `'b'` goes in and `'B'` comes back. **See also:** [SetFont](#setfont)"),
    },
    "GetCurrentFontFamily": {
        "descricao": ("Devolve o nome da família em uso. Sempre em MINÚSCULA: o SetFont normaliza, então 'Times' entra e 'times' volta. Comparar com 'Times' nunca casa -- use LOWER() dos dois lados.",
                      "Returns the family of the current font."),
        "retorno": ("VARCHAR2 - a família corrente",
                    "VARCHAR2 — the family name. **See also:** [SetFont](#setfont)"),
    },
    "SetDash": {
        "descricao": ("Passa a desenhar linha tracejada, com o comprimento do traço e o do intervalo na unidade corrente. Os dois em zero voltam à linha cheia. Vale para tudo o que for desenhado depois, até ser trocado.",
                      "Sets a simple dashed-line pattern."),
        "params": {
            "pblack": ("comprimento do traço",
                      "Length of the dash. Number in the unit set by Init (mm, cm, pt or in); 0 (default) goes back to a solid line"),
            "pwhite": ("comprimento do intervalo",
                      "Length of the gap. Number in the unit set by Init (mm, cm, pt or in); 0 (default) goes back to a solid line"),
        },
    },
    "GetLineSpacing": {
        "descricao": ("Devolve a entrelinha usada pelo MultiCell quando a altura da linha vai em branco.",
                      "Returns the current line spacing."),
        "retorno": ("NUMBER - a entrelinha, na unidade corrente",
                    "NUMBER — the configured spacing. **See also:** [SetLineSpacing](#setlinespacing)"),
    },
    "SetLineSpacing": {
        "descricao": ("Define a entrelinha do MultiCell para quando a altura da linha não for informada.",
                      "Sets the line spacing used by Write and MultiCell."),
        "params": {
            "pls": ("a entrelinha, na unidade corrente",
                   "Spacing factor or height. Number > 0"),
        },
    },
    "Poly": {
        "descricao": ("Desenha um polígono ligando os pontos na ordem da tabela, que precisa começar no índice 0. Fechado, o último ponto liga de volta ao primeiro.",
                      "Draws a polygon from a collection of points."),
        "params": {
            "points": ("os vértices, indexados a partir de 0",
                      "Points of the polygon. tab_points collection with X/Y pairs in the document's unit"),
            "pclose": ("fechar o contorno",
                      "Closes the polygon, joining the last point to the first. TRUE or FALSE"),
            "pstyle": ("'' desenha o contorno (padrão), 'F' preenche (Fill), 'FD' ou 'DF' preenche e contorna (Fill and Draw)",
                      "Rendering style. '' or 'D' (outline), 'F' (filled), 'DF' (both)"),
        },
    },
    "Triangle": {
        "descricao": ("Desenha um triângulo isósceles de base 2*psize e altura psize, com a ponta virada para porientation. (px, py) é o canto superior esquerdo da caixa que envolve o triângulo, e não o vértice.",
                      "Draws an isosceles triangle with a base of 2xpsize and a height of psize, pointing in the direction given."),
        "params": {
            "px": ("canto superior esquerdo da caixa",
                  "X of the top-left corner of the triangle's bounding box. Number in the unit set by Init (mm, cm, pt or in)"),
            "py": ("canto superior esquerdo da caixa",
                  "Y of the top-left corner of the triangle's bounding box. Number in the unit set by Init (mm, cm, pt or in)"),
            "psize": ("metade da base, e a altura",
                     "Height of the triangle; the base is twice that. Number in the unit set by Init (mm, cm, pt or in)"),
            "porientation": ("para onde aponta: 'up'/'U', 'down'/'D', 'left'/'L', 'right'/'R'",
                            "Direction the tip points to. 'up', 'down', 'left' or 'right' — or the initials 'U', 'D', 'L', 'R'"),
            "pstyle": ("'' contorna, 'F' preenche (Fill), 'FD'/'DF' os dois",
                      "Rendering style. '' or 'D' (outline), 'F' (filled), 'DF' (both)"),
        },
    },
    "SetLineDashPattern": {
        "descricao": ("Escreve o operador 'd' do PDF direto no fluxo de conteúdo, para quem precisa de um padrão que o SetDash não monta. O texto vai como está, e um padrão malformado só aparece no leitor. Prefira SetDash.",
                      "Sets the dash pattern using the PDF's own syntax, for fine control."),
        "params": {
            "pdash": ("o padrão, na sintaxe do PDF ('[] 0' = linha cheia)",
                     "Pattern in PDF format. '[] 0' (solid, the default), '[3 2] 0' (3 on, 2 off), '[1 2 3 2] 0' and so on"),
        },
    },
    "Ln": {
        "descricao": ("Vai para a linha seguinte: leva o x de volta à margem esquerda e desce o y. Sem altura, desce o da última célula escrita.",
                      "Moves the cursor to the next line, back at the left margin."),
        "params": {
            "h": ("quanto descer, na unidade corrente",
                 "Height of the jump. Number in the unit set by Init (mm, cm, pt or in); NULL (default) uses the height of the last cell written"),
        },
    },
    "GetX": {
        "descricao": ("Devolve a abscissa corrente, na unidade em uso.",
                      "Returns the current X position of the cursor."),
        "retorno": ("NUMBER - o x corrente",
                    "NUMBER — X coordinate. **See also:** [SetX](#setx), [SetXY](#setxy)"),
    },
    "SetX": {
        "descricao": ("Move a abscissa. Valor negativo conta a partir da borda direita: SetX(-30) põe o cursor a 30 da direita.",
                      "Sets the X position of the cursor."),
        "params": {
            "px": ("a nova abscissa",
                  "New X coordinate. Number in the unit set by Init (mm, cm, pt or in); negative values count from the right edge"),
        },
    },
    "GetY": {
        "descricao": ("Devolve a ordenada corrente, contada do topo da página.",
                      "Returns the current Y position of the cursor."),
        "retorno": ("NUMBER - o y corrente",
                    "NUMBER — Y coordinate. **See also:** [SetY](#sety)"),
    },
    "SetY": {
        "descricao": ("Move a ordenada E devolve o x à margem esquerda -- é o efeito que surpreende quem só queria descer. Para mover os dois sem esse efeito, use SetXY. Valor negativo conta a partir do pé da página.",
                      "Sets the Y position of the cursor, and moves X back to the left margin."),
        "params": {
            "py": ("a nova ordenada",
                  "New Y coordinate. Number in the unit set by Init (mm, cm, pt or in); negative values count from the bottom edge — e.g. -15 for a footer"),
        },
    },
    "SetXY": {
        "descricao": ("Move as duas coordenadas. Ao contrário do SetY sozinho, o x informado é respeitado.",
                      "Sets both X and Y of the cursor in a single call."),
        "params": {
            "x": ("a abscissa",
                 "X coordinate. Number in the unit set by Init (mm, cm, pt or in)"),
            "y": ("a ordenada",
                 "Y coordinate. Number in the unit set by Init (mm, cm, pt or in)"),
        },
    },
    "SetHeaderProc": {
        "descricao": ("Registra o NOME de uma rotina que será executada no início de cada página. O nome e os nomes dos parâmetros são validados como identificadores SQL (DBMS_ASSERT) aqui, na configuração -- e não no meio do relatório, que é onde um nome inválido apareceria. O bloco é montado uma vez só, e não a cada página.",
                      "Registers a procedure of yours to run automatically at the top of every page."),
        "params": {
            "headerprocname": ("nome da rotina (NULL desliga)",
                              "Qualified name of the procedure. 'package.procedure' or 'procedure'; it must be reachable by the database user"),
            "paramTable": ("parâmetros nomeados",
                          "Parameters passed on to the procedure, by name. PL_FPDF.tv4000a — an associative array INDEXED BY THE NAME of your procedure's parameter: l_p('p_title') := 'Report'. There is no tv4000a(...) constructor: declare a variable and fill it by key. noParam (default) = called with no parameters"),
        },
    },
    "SetFooterProc": {
        "descricao": ("Como SetHeaderProc, para o rodapé: a rotina é executada ao fechar cada página, e é onde costuma entrar o \"página N de {nb}\".",
                      "Registers a procedure of yours to run automatically in the footer of every page."),
        "params": {
            "footerprocname": ("nome da rotina (NULL desliga)",
                              "Qualified name of the procedure. 'package.procedure' or 'procedure'"),
            "paramTable": ("parâmetros nomeados",
                          "Parameters passed on to the procedure, by name. PL_FPDF.tv4000a — an associative array INDEXED BY THE NAME of your procedure's parameter: l_p('p_title') := 'Report'. There is no tv4000a(...) constructor: declare a variable and fill it by key. noParam (default) = called with no parameters"),
        },
    },
    "SetMargins": {
        "descricao": ("Define as margens esquerda, superior e direita. A direita em branco fica igual à esquerda.",
                      "Sets the left, top and right margins of the document. The bottom margin is controlled by SetAutoPageBreak."),
        "params": {
            "left": ("margem esquerda",
                    "Left margin. Number in the unit set by Init (mm, cm, pt or in)"),
            "top": ("margem superior",
                   "Top margin. Number in the unit set by Init (mm, cm, pt or in)"),
            "right": ("margem direita (- 1 = igual à esquerda)",
                     "Right margin. Number in the unit set by Init (mm, cm, pt or in); -1 (default) reuses the left margin value"),
        },
    },
    "SetLeftMargin": {
        "descricao": ("Define a margem esquerda. Com página já aberta e o cursor à esquerda da margem nova, o cursor é trazido para ela.",
                      "Sets the left margin only."),
        "params": {
            "pMargin": ("a margem, na unidade corrente",
                       "Left margin. Number in the unit set by Init (mm, cm, pt or in)"),
        },
    },
    "SetTopMargin": {
        "descricao": ("Define a margem superior, usada pelas páginas seguintes.",
                      "Sets the top margin only."),
        "params": {
            "pMargin": ("a margem, na unidade corrente",
                       "Top margin. Number in the unit set by Init (mm, cm, pt or in)"),
        },
    },
    "SetRightMargin": {
        "descricao": ("Define a margem direita, que é o que limita a largura de uma célula pedida com largura 0.",
                      "Sets the right margin only."),
        "params": {
            "pMargin": ("a margem, na unidade corrente",
                       "Right margin. Number in the unit set by Init (mm, cm, pt or in)"),
        },
    },
    "SetAutoPageBreak": {
        "descricao": ("Liga ou desliga a quebra automática e define a margem de rodapé que a dispara. Desligada, o conteúdo que passar do fim da página é escrito fora dela e some -- sem erro nenhum.",
                      "Turns the automatic page break on or off and sets how far from the bottom edge it happens."),
        "params": {
            "pauto": ("ligar a quebra automática",
                     "Enables the automatic page break. TRUE or FALSE"),
            "pMargin": ("margem de rodapé que dispara",
                       "Bottom margin that triggers the break. Number in the unit set by Init (mm, cm, pt or in); 0 is the default"),
        },
    },
    "SetDisplayMode": {
        "descricao": ("Diz ao leitor de PDF como abrir o documento. É preferência de apresentação: o leitor pode ignorar.",
                      "Tells the PDF reader how to display the document when it opens."),
        "params": {
            "zoom": ("'fullpage' (página inteira), 'fullwidth' (largura da página), 'real' (tamanho real), 'default' (padrão do leitor), ou um número que é o percentual de ampliação",
                    "Initial zoom level. 'fullpage' (whole page), 'fullwidth' (page width), 'real' (100%), 'default', or a number standing for the percentage"),
            "layout": ("'single' (uma página), 'continuous' (contínuo), 'two' (duas colunas), 'default' (padrão do leitor)",
                      "Page layout. 'continuous' (default), 'single', 'two' or 'default'"),
        },
    },
    "SetCompression": {
        "descricao": ("Liga a compressão dos fluxos de conteúdo. Até agosto/2026 isto não fazia nada -- procurava uma rotina de zlib que o Oracle não tem e desligava sempre. Hoje o deflate está escrito no próprio pacote (PL_FPDF_UTIL.deflate) e a opção vale.",
                      "Turns compression of the page content stream on or off. When on, each page comes out with /Filter [/ASCIIHexDecode /FlateDecode] — a deflate written inside the package itself, in hexadecimal because the document is assembled as text. Hexadecimal doubles the compressed size, so compression is only applied when the stream still ends up smaller than the original; a page that does not benefit comes out unfiltered. Text usually drops below a fifth."),
        "params": {
            "p_compress": ("comprimir os fluxos",
                          "Enables compression. TRUE or FALSE; FALSE is the default"),
        },
    },
    "SetTitle": {
        "descricao": ("Grava o título nos metadados do PDF -- o que o leitor mostra na barra de título e o que o buscador indexa.",
                      "Sets the document title, shown in the PDF reader's title bar."),
        "params": {
            "ptitle": ("o título",
                      "Title. Any VARCHAR2"),
        },
    },
    "SetSubject": {
        "descricao": ("Grava o assunto nos metadados do PDF.",
                      "Sets the document subject in the metadata."),
        "params": {
            "psubject": ("o assunto",
                        "Subject. Any VARCHAR2"),
        },
    },
    "SetAuthor": {
        "descricao": ("Grava o autor nos metadados do PDF.",
                      "Sets the document author in the metadata."),
        "params": {
            "pauthor": ("o autor",
                       "Author. Any VARCHAR2"),
        },
    },
    "SetKeywords": {
        "descricao": ("Grava as palavras-chave nos metadados do PDF, separadas por espaço.",
                      "Sets the document keywords, which help search and indexing."),
        "params": {
            "pkeywords": ("as palavras-chave",
                         "Keywords. Free text, usually comma separated"),
        },
    },
    "SetCreator": {
        "descricao": ("Grava, nos metadados, o nome do sistema que gerou o documento.",
                      "Sets the creating application in the document metadata."),
        "params": {
            "pcreator": ("o sistema gerador",
                        "Name of the generating system. Any VARCHAR2"),
        },
    },
    "SetAliasNbPages": {
        "descricao": ("Define o texto que será trocado pelo total de páginas na hora de fechar o documento. É como se escreve \"página 3 de 12\" sem saber o 12 enquanto se escreve a página 3.",
                      "Sets the placeholder that will be replaced by the total page count when the document is finalised — so you can write 'Page 2 of 10' without knowing the total in advance."),
        "params": {
            "palias": ("o marcador",
                      "Placeholder to replace. Any text; '{nb}' is the default"),
        },
    },
    "Header": {
        "descricao": ("Executa a rotina registrada em SetHeaderProc. É chamada sozinha ao abrir cada página; não se chama à mão.",
                      "Header extension point, called internally on every new page."),
    },
    "Footer": {
        "descricao": ("Executa a rotina registrada em SetFooterProc. É chamada sozinha ao fechar cada página; não se chama à mão.",
                      "Footer extension point, called internally as each page is closed."),
    },
    "PageNo": {
        "descricao": ("Devolve o número da página que está sendo escrita, começando em 1.",
                      "Returns the current page number during generation; typically used in footers."),
        "retorno": ("NUMBER - a página corrente",
                    "NUMBER — number of the current page."),
    },
    "SetDrawColor": {
        "descricao": ("Define a cor com que se desenham linhas, contornos e bordas de célula. Com um argumento só, é tom de cinza (0 preto, 255 branco); com três, é RGB. Vale do ponto em que é chamada em diante.",
                      "Sets the colour of the lines and outlines drawn next."),
        "params": {
            "r": ("vermelho, ou o nível de cinza (0..255)",
                 "Red component, or the grey level when g and b are omitted. 0 to 255"),
            "g": ("verde (0..255)",
                 "Green component. 0 to 255; -1 (default) means greyscale, using r"),
            "b": ("azul (0..255)",
                 "Blue component. 0 to 255; -1 (default) means greyscale, using r"),
        },
    },
    "SetFillColor": {
        "descricao": ("Define a cor de fundo das células preenchidas e das formas com estilo 'F'. Um argumento é cinza, três são RGB.",
                      "Sets the fill colour of cells (pfill = 1), rectangles and shapes."),
        "params": {
            "r": ("vermelho, ou o nível de cinza (0..255)",
                 "Red component, or the grey level. 0 to 255"),
            "g": ("verde (0..255)",
                 "Green component. 0 to 255; -1 = greyscale"),
            "b": ("azul (0..255)",
                 "Blue component. 0 to 255; -1 = greyscale"),
        },
    },
    "SetTextColor": {
        "descricao": ("Define a cor do texto. Um argumento é cinza, três são RGB.",
                      "Sets the colour of the text written next."),
        "params": {
            "r": ("vermelho, ou o nível de cinza (0..255)",
                 "Red component, or the grey level. 0 to 255"),
            "g": ("verde (0..255)",
                 "Green component. 0 to 255; -1 = greyscale"),
            "b": ("azul (0..255)",
                 "Blue component. 0 to 255; -1 = greyscale"),
        },
    },
    "SetLineWidth": {
        "descricao": ("Define a espessura do traço, na unidade corrente.",
                      "Sets the thickness of the lines drawn next."),
        "params": {
            "width": ("a espessura, maior que zero",
                     "Line thickness. Number in the unit set by Init (mm, cm, pt or in); the PDF default is about 0.2 mm"),
        },
    },
    "Line": {
        "descricao": ("Desenha um segmento de reta entre dois pontos, com a cor e a espessura correntes.",
                      "Draws a straight line between two points."),
        "params": {
            "x1": ("ponto inicial",
                  "X of the start point. Number in the unit set by Init (mm, cm, pt or in)"),
            "y1": ("ponto inicial",
                  "Y of the start point. Number in the unit set by Init (mm, cm, pt or in)"),
            "x2": ("ponto final",
                  "X of the end point. Number in the unit set by Init (mm, cm, pt or in)"),
            "y2": ("ponto final",
                  "Y of the end point. Number in the unit set by Init (mm, cm, pt or in)"),
        },
    },
    "Rect": {
        "descricao": ("Desenha um retângulo a partir do canto superior esquerdo.",
                      "Draws a rectangle: outlined, filled, or both."),
        "params": {
            "px": ("canto superior esquerdo",
                  "X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "py": ("canto superior esquerdo",
                  "Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "pw": ("largura",
                  "Width. Number in the unit set by Init (mm, cm, pt or in)"),
            "ph": ("altura",
                  "Height. Number in the unit set by Init (mm, cm, pt or in)"),
            "pstyle": ("'' contorna (padrão), 'F' preenche (Fill), 'FD' ou 'DF' preenche e contorna (Fill and Draw)",
                      "Rendering style. '' or 'D' (outline only, the default), 'F' (fill only), 'DF'/'FD' (outline + fill)"),
        },
    },
    "AddLink": {
        "descricao": ("RECUSA com -20601. Criaria um link interno, e link interno não está implementado: o /Dest nunca chegou a ser escrito no arquivo, então o identificador que esta função devolveria não levaria a lugar nenhum -- e o Link o recusa. Até setembro/2026 a chamada levantava ORA-06531, \"reference to uninitialized collection\", porque a coleção interna nunca foi inicializada: nunca funcionou, em nenhuma versão. Passa a recusar com mensagem que diz o que usar no lugar.",
                      "Creates an internal link, still without a destination, and returns its identifier."),
        "retorno": ("NUMBER - nunca devolve: levanta antes",
                    "NUMBER — the link identifier."),
    },
    "SetLink": {
        "descricao": ("RECUSA com -20601, pelo mesmo motivo do AddLink: guardar o destino não adiantaria, porque o /Dest não é emitido e ninguém o lê. Até setembro/2026 levantava ORA-06531.",
                      "Sets the destination of an internal link created by AddLink."),
        "params": {
            "plink": ("identificador devolvido por AddLink",
                     "Link identifier. The value returned by AddLink"),
            "py": ("ordenada de chegada (- 1 = a posição corrente)",
                  "Vertical destination on the page. Number in the unit set by Init (mm, cm, pt or in); 0 (default) = top of the page"),
            "ppage": ("página de chegada (- 1 = a página corrente)",
                     "Destination page. Page number; -1 (default) = the current page"),
        },
    },
    "Link": {
        "descricao": ("Marca uma área retangular como clicável, levando a uma URL.",
                      "Creates a clickable rectangle anywhere on the page."),
        "params": {
            "px": ("canto superior esquerdo da área",
                  "X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "py": ("canto superior esquerdo da área",
                  "Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "pw": ("largura",
                  "Width of the area. Number in the unit set by Init (mm, cm, pt or in)"),
            "ph": ("altura",
                  "Height of the area. Number in the unit set by Init (mm, cm, pt or in)"),
            "plink": ("a URL",
                     "Destination. URL ('https://...'); an AddLink identifier is refused with ORA-20601"),
        },
        "notas": [
            ("1. Uma área por página. Uma segunda chamada na mesma página substitui a primeira, em silêncio -- a estrutura guarda um registro por página. Documentado por ser assim, não por ser o desejável. 2. Link interno não é suportado, e é RECUSADO com -20601. O ramo que escreveria o /Dest saiu comentado no porte original e nunca voltou; emiti-lo assim produzia um /Annot com o dicionário aberto, isto é, arquivo malformado. Desde setembro/2026 a chamada levanta erro em vez de gravar o arquivo quebrado. Use URL.",
             "1. One area per page. A second call on the same page silently replaces the first -- the structure keeps one record per page. Documented because that is how it behaves, not because it is desirable. 2. Internal links are not supported, and are REFUSED with -20601. The branch that would write the /Dest was left commented out in the original port and never came back; emitting it as it stood produced an /Annot with an open dictionary, that is, a malformed file. Since September 2026 the call raises an error instead of writing the broken file. Use a URL."),
        ],
    },
    "Text": {
        "descricao": ("Escreve texto num ponto exato, sem célula, sem quebra e sem mover o cursor. (px, py) é a LINHA DE BASE do texto, não o topo dele.",
                      "Writes text at absolute coordinates, without moving the cursor or breaking lines."),
        "params": {
            "px": ("a linha de base",
                  "X coordinate where the text starts. Number in the unit set by Init (mm, cm, pt or in)"),
            "py": ("a linha de base",
                  "Y coordinate of the baseline. Number in the unit set by Init (mm, cm, pt or in)"),
            "ptxt": ("o texto",
                    "Text to write. Any VARCHAR2"),
        },
    },
    "AcceptPageBreak": {
        "descricao": ("Diz se a quebra automática está ligada. É consultada pelo Cell antes de decidir abrir página nova.",
                      "Reports whether an automatic page break should happen at the current point. The engine calls it internally; you can read it for your own pagination logic."),
        "retorno": ("BOOLEAN - TRUE se a quebra automática está ligada",
                    "BOOLEAN — TRUE if the automatic page break is enabled. **See also:** [SetAutoPageBreak](#setautopagebreak)"),
    },
    "AddFont": {
        "descricao": ("Registra uma fonte para uso pelo SetFont. Para as 14 fontes padrão do PDF não é preciso chamar isto -- elas já estão disponíveis, e escrevem acentuado desde a 3.4.0.",
                      "Registers an additional font (FPDF compatibility). For TrueType with UTF-8, prefer AddTTFFont."),
        "params": {
            "family": ("nome da família",
                      "Family name to register. Free text; used later in SetFont"),
            "style": ("'' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'BI' os dois",
                     "Style tied to the file. '', 'B', 'I' or 'BI'"),
            "filename": ("arquivo de métricas da fonte",
                        "Font definition file. File name; empty uses the standard FPDF convention"),
        },
    },
    "SetFont": {
        "descricao": ("Escolhe a fonte, o estilo e o corpo do texto que vier depois. Corpo zero mantém o que já estava. As fontes padrão -- Helvetica, Times, Courier, Symbol e ZapfDingbats -- não precisam ser carregadas.",
                      "Sets the font family, style and size used by the next text writes."),
        "params": {
            "pfamily": ("família ('Helvetica', 'Times', 'Courier'...)",
                       "Font family. 'Arial'/'Helvetica', 'Times', 'Courier', 'Symbol', 'ZapfDingbats' or the name of a TrueType font loaded with AddTTFFont/LoadTTFFromFile"),
            "pstyle": ("'' normal, 'B' negrito (Bold), 'I' itálico (Italic), 'U' sublinhado (Underline), ou a combinação",
                      "Text style. '' (regular), 'B' (bold), 'I' (italic), 'BI' (bold italic) or 'U' (underlined)"),
            "psize": ("corpo em pontos ( 0 = mantém)",
                     "Size in points. Number > 0; 0 (default) keeps the current size"),
        },
        "notas": [
            ("A família é guardada em minúscula e o estilo em maiúscula. É o que os getters devolvem, e não o texto que entrou aqui.",
             "The family is stored in lower case and the style in upper case. That is what the getters return, not the text given here."),
        ],
    },
    "GetStringWidth": {
        "descricao": ("Mede quanto o texto ocupa na fonte e no corpo correntes, na unidade em uso. É o que permite alinhar, centralizar e decidir onde quebrar. Caractere acentuado mede o mesmo que o caractere base -- nas 14 fontes padrão do PDF o glifo acentuado tem a mesma largura de avanço.",
                      "Measures how wide a piece of text will be in the current font and size — use it to centre by hand, size columns, or decide where to break."),
        "params": {
            "pstr": ("o texto a medir",
                    "Text to measure. Any VARCHAR2"),
        },
        "retorno": ("NUMBER - a largura, na unidade corrente",
                    "NUMBER — width in the document's unit."),
    },
    "SetFontSize": {
        "descricao": ("Troca só o corpo, mantendo família e estilo.",
                      "Changes only the size of the current font."),
        "params": {
            "psize": ("corpo em pontos",
                     "Size in points. Number > 0"),
        },
    },
    "Cell": {
        "descricao": ("Escreve uma célula retangular: opcionalmente com borda, com fundo e com texto dentro, e move o cursor conforme pln. É a rotina mais usada da biblioteca. Se a célula não couber no que resta da página e a quebra automática estiver ligada, a página é trocada antes de escrever.",
                      "Writes a rectangular block of text, with optional borders, alignment, fill and link. It is the API most used to build reports and tables."),
        "params": {
            "pw": ("largura; 0 vai até a margem direita",
                  "Cell width. Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin"),
            "ph": ("altura",
                  "Cell height. Number in the unit set by Init (mm, cm, pt or in); 0 is the default"),
            "ptxt": ("o texto",
                    "Text to write. Any VARCHAR2; empty draws the cell alone"),
            "pborder": ("'0' sem borda, '1' moldura inteira, ou as letras dos lados que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas laterais; 'TB', só topo e base",
                       "'0' for no border, '1' for the whole frame, or the letters of the sides you want, combined: 'L' (Left), 'T' (Top), 'R' (Right) and 'B' (Bottom). 'LR' draws only the two sides; 'TB', only top and bottom"),
            "pln": ("para onde vai o cursor: 0 = à direita da célula 1 = próxima linha, na margem esquerda 2 = abaixo, mantendo o x",
                   "Where the cursor goes afterwards. 0 = to the right of the cell (default), 1 = start of the next line, 2 = below the cell"),
            "palign": ("'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right, direita)",
                      "Text alignment. 'L' (left), 'C' (centre), 'R' (right) or '' (default, left)"),
            "pfill": ("1 pinta o fundo com a cor de SetFillColor, 0 não",
                     "Fills the background with the SetFillColor colour. 0 = transparent (default), 1 = filled"),
            "plink": ("URL ou identificador de link interno",
                     "Makes the cell clickable. URL ('https://...'); an AddLink identifier is refused with ORA-20601"),
        },
    },
    "MultiCell": {
        "descricao": ("Escreve um bloco de texto que quebra sozinho na largura pedida, uma célula por linha, e devolve quantas linhas saíram. A quebra respeita o espaço entre palavras e a quebra explícita (CHR(10)). Esta é a versão FUNCTION, para quem precisa saber quantas linhas foram gastas -- para calcular a altura de uma tabela, tipicamente.",
                      "Writes a paragraph with automatic line breaking inside a given width. It exists as a function, returning the number of lines, and as a procedure."),
        "params": {
            "pw": ("largura do bloco; 0 vai até a margem direita",
                  "Block width. Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin"),
            "ph": ("altura de cada linha; em branco usa a entrelinha de SetLineSpacing",
                  "Height of each line. Number in the unit set by Init (mm, cm, pt or in)"),
            "ptxt": ("o texto",
                    "Paragraph text; line breaks are honoured. Any VARCHAR2"),
            "pborder": ("'0' sem borda, '1' moldura inteira, ou as letras dos lados que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas laterais; 'TB', só topo e base",
                       "'0' for no border, '1' for the whole frame, or the letters of the sides you want, combined: 'L' (Left), 'T' (Top), 'R' (Right) and 'B' (Bottom). 'LR' draws only the two sides; 'TB', only top and bottom"),
            "palign": ("'J' justificado (Justified, o padrão), 'L' (Left, esquerda), 'C' (Center, centro) ou 'R' (Right, direita)",
                      "Alignment. 'J' (justified, default), 'L', 'C' or 'R'"),
            "pfill": ("1 pinta o fundo, 0 não",
                     "Fills the background. 0 (default) or 1"),
            "phMax": ("altura máxima do bloco; 0 sem limite",
                     "Maximum block height; text beyond it is truncated. Number; 0 (default) = no limit"),
        },
        "retorno": ("NUMBER - quantas linhas foram escritas",
                    "NUMBER (function version) — how many lines were produced."),
    },
    "Write": {
        "descricao": ("Escreve texto corrido a partir de onde o cursor está, indo até a margem direita e continuando na linha seguinte -- como um parágrafo de processador de texto. Diferente do MultiCell, começa no meio da linha onde o cursor parou, o que é o que se quer para emendar texto de formatações diferentes.",
                      "Writes text as a flow, continuing where the previous one stopped and breaking lines automatically — which lets you switch fonts and styles in the middle of a sentence."),
        "params": {
            "pH": ("altura da linha, na unidade corrente",
                  "Line height. Number in the unit set by Init (mm, cm, pt or in)"),
            "ptxt": ("o texto",
                    "Text to write. Any VARCHAR2"),
            "plink": ("URL ou identificador de link interno",
                     "Optional link applied to the text. URL; NULL (default) = no link. An AddLink identifier is refused with ORA-20601"),
        },
    },
    "CellRotated": {
        "descricao": ("O mesmo que Cell, com o texto girado dentro da célula. Serve para cabeçalho de coluna estreita e para carimbo na lateral da página.",
                      "Cell with the text rotated — useful for vertical table headers and labels."),
        "params": {
            "p_width": ("largura; 0 vai até a margem direita",
                       "Cell width. Number in the unit set by Init (mm, cm, pt or in); 0 stretches to the right margin"),
            "p_height": ("altura",
                        "Cell height. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_text": ("o texto",
                      "Text to write. Any VARCHAR2"),
            "p_border": ("'0' sem borda, '1' moldura inteira, ou as letras dos lados que se quer, combinadas: 'L' (Left, esquerda), 'T' (Top, topo), 'R' (Right, direita) e 'B' (Bottom, base). 'LR' desenha só as duas laterais; 'TB', só topo e base",
                        "'0' for no border, '1' for the whole frame, or the letters of the sides you want, combined: 'L' (Left), 'T' (Top), 'R' (Right) and 'B' (Bottom). 'LR' draws only the two sides; 'TB', only top and bottom"),
            "p_ln": ("0 à direita, 1 próxima linha na margem esquerda, 2 abaixo mantendo o x",
                    "Cursor position afterwards. 0 = to the right, 1 = next line, 2 = below"),
            "p_align": ("'L' (Left, esquerda), 'C' (Center, centro), 'R' (Right, direita)",
                       "Alignment. 'L', 'C' or 'R'"),
            "p_fill": ("1 pinta o fundo, 0 não",
                      "Fill. 0 or 1"),
            "p_link": ("URL ou link interno",
                      "Optional link. URL; an AddLink identifier is refused with ORA-20601"),
            "p_rotation": ("giro do texto em graus (0, 90, 180, 270)",
                          "Rotation angle of the text. 0 (default), 90, 180 or 270 — any other value raises an error"),
        },
    },
    "WriteRotated": {
        "descricao": ("O mesmo que Write, com o texto girado.",
                      "Write with the text rotated."),
        "params": {
            "p_height": ("altura da linha",
                        "Line height. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_text": ("o texto",
                      "Text to write. Any VARCHAR2"),
            "p_link": ("URL ou link interno",
                      "Optional link. URL; NULL = no link. An AddLink identifier is refused with ORA-20601"),
            "p_rotation": ("giro em graus (0, 90, 180, 270)",
                          "Rotation angle. 0 (default), 90, 180 or 270"),
        },
    },
    "image": {
        "descricao": ("Coloca uma imagem buscada por URL. A busca sai pela rede e exige ACL concedida ao schema -- quando a imagem já está numa tabela ou numa variável, ImageFromBlob faz o mesmo sem rede e sem permissão. Largura e altura em zero saem da própria imagem, a 72 dpi; com uma das duas em zero, ela é derivada da outra, mantendo a proporção.",
                      "Places a PNG or JPEG image on the current page, with optional proportional scaling."),
        "params": {
            "pFile": ("URL da imagem",
                     "Source of the image. File name in an Oracle DIRECTORY, or the identifier returned by getImageFromUrl"),
            "pX": ("canto superior esquerdo",
                  "X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "pY": ("canto superior esquerdo",
                  "Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "pWidth": ("largura ( 0 = derivada)",
                      "Desired width. Number in the unit set by Init (mm, cm, pt or in); 0 (default) derives it from the height"),
            "pHeight": ("altura ( 0 = derivada)",
                       "Desired height. Number in the unit set by Init (mm, cm, pt or in); 0 (default) derives it from the width, keeping the aspect ratio"),
            "pType": ("formato, quando não se quer deduzir do arquivo",
                     "Image format. 'PNG', 'JPG'/'JPEG', or NULL (default) to detect it automatically"),
            "pLink": ("URL ou identificador de link interno sobre a imagem",
                     "Makes the image clickable. URL; NULL = no link. An AddLink identifier is refused with ORA-20601"),
        },
    },
    "ImageFromBlob": {
        "descricao": ("Coloca uma imagem que o chamador já tem em mãos, sem passar por URL. O Image() busca pela rede e exige ACL concedida ao schema; quando a imagem já está numa tabela ou numa variável, esta entrada dispensa a rede e a permissão. O formato é reconhecido pelos primeiros bytes do arquivo, não pela extensão: PNG e JPEG; qualquer outra coisa é recusada.",
                      "Places an image you already hold — from a table, a BFILE or a variable — without going through a URL. `Image` fetches over the network, which needs an ACL granted to the schema; when the bytes are already in the database, this entry point needs neither the network nor the permission."),
        "params": {
            "p_blob": ("bytes da imagem (PNG ou JPEG)",
                      "Image bytes. PNG or JPEG"),
            "p_name": ("chave no cache de imagens. Um BLOB não tem nome, então o chamador escolhe: nomes distintos para imagens distintas, e o mesmo nome reaproveita o objeto já emitido no documento",
                      "Key in the image cache. A BLOB has no filename, so you pick one: distinct names for distinct images, and the same name reuses the object already emitted instead of writing the same bytes again. Any non-null text"),
            "pX": ("posição, na unidade corrente",
                  "X of the top-left corner. Number in the unit set in Init (mm, cm, pt or in)"),
            "pY": ("posição, na unidade corrente",
                  "Y of the top-left corner. Number in the unit set in Init (mm, cm, pt or in)"),
            "pWidth": ("largura ( 0 = derivada)",
                      "Requested width. Number in the unit set in Init; 0 (default) derives it from the height"),
            "pHeight": ("altura ( 0 = derivada)",
                       "Requested height. Number in the unit set in Init; 0 (default) derives it from the width, keeping the aspect ratio"),
            "pLink": ("link opcional sobre a área da imagem",
                     "Makes the image clickable. URL; NULL = no link. An AddLink identifier is refused with ORA-20601"),
        },
    },
    "Output": {
        "descricao": ("Fecha o documento e grava em arquivo, no DIRECTORY PDF_DIR. É a forma legada: os modos de entrega ao navegador ('I', 'D', 'S') saíram junto com o OWA/HTP e hoje recusam com -20306, dizendo o que usar no lugar. Para receber os bytes, use OutputBlob.",
                      "Classic FPDF-style output (compatibility). Prefer OutputBlob or OutputFile."),
        "params": {
            "pname": ("nome do arquivo (NULL grava 'doc.pdf')",
                     "File or document name. Any VARCHAR2"),
            "pdest": ("destino: 'F' (File, arquivo) é o único suportado",
                     "Destination. 'S', 'D', 'I' or 'F'"),
        },
    },
    "ReturnBlob": {
        "descricao": ("Fecha o documento e devolve os bytes. Existe por compatibilidade: os dois parâmetros são ACEITOS E IGNORADOS, e a chamada é repassada ao OutputBlob. Em código novo, chame OutputBlob direto.",
                      "Returns the PDF as a BLOB (legacy compatibility). Prefer OutputBlob."),
        "params": {
            "pname": ("ignorado",
                     "Logical name of the document. Any VARCHAR2; NULL = no name"),
            "pdest": ("ignorado",
                     "FPDF-style destination. 'S' (string/BLOB), 'D' (download), 'I' (inline), 'F' (file)"),
        },
        "retorno": ("BLOB - o PDF",
                    "BLOB — the PDF content. **See also:** [OutputBlob](#outputblob)"),
    },
    "OutputBlob": {
        "descricao": ("Fecha o documento e devolve os bytes do PDF. É a saída principal da biblioteca: quem grava em tabela, quem anexa a e-mail e quem entrega por HTTP começa aqui.",
                      "Synonym of OutputBlob: finalises the document and returns the PDF as a BLOB."),
        "retorno": ("BLOB - o PDF pronto",
                    "BLOB — the PDF content. **See also:** [OutputBlob](#outputblob)"),
    },
    "OutputFile": {
        "descricao": ("Fecha o documento e grava num DIRECTORY do banco. Exige WRITE no diretório concedido ao schema.",
                      "Finalises the document and writes the PDF straight to a file on the database server."),
        "params": {
            "p_filename": ("nome do arquivo",
                          "Name of the output file. E.g. 'report.pdf'"),
            "p_directory": ("DIRECTORY do banco",
                           "Oracle DIRECTORY with write permission. Default: 'PDF_DIR'"),
        },
    },
    "OpenPDF": {
        "descricao": ("Marca o documento como aberto. O AddPage já faz isto quando preciso; chamar à mão é raro.",
                      "Explicitly opens the document structure (advanced use; Init already does it)."),
    },
    "ClosePDF": {
        "descricao": ("Fecha o documento: escreve o rodapé da última página, monta a estrutura do arquivo e troca o marcador do total de páginas. Sem nenhuma página, uma é criada em branco. As rotinas de saída chamam isto sozinhas.",
                      "Closes the document structure (advanced use; the output APIs already do it)."),
    },
    "AddPage": {
        "descricao": ("Fecha a página corrente, executando o rodapé, e abre outra, executando o cabeçalho. Orientação e formato em branco repetem os da página anterior. Além dos formatos com nome, aceita 'largura,altura' na unidade corrente.",
                      "Adds a new page to the document and makes it the current one. NULL parameters inherit the values set in Init, which lets you mix orientations and formats within the same PDF."),
        "params": {
            "p_orientation": ("'P' (Portrait, retrato) ou 'L' (Landscape, paisagem); NULL mantém a da página anterior",
                             "Orientation for this page only. 'P', 'L' or NULL (inherits from Init)"),
            "p_format": ("'A4', 'Letter', 'Legal', ou 'largura,altura'; NULL mantém o anterior",
                        "Page format for this page only. 'A3', 'A4', 'A5', 'Letter', 'Legal' or NULL (inherits from Init)"),
            "p_rotation": ("giro da página em graus (0, 90, 180, 270)",
                          "Display rotation applied by the PDF reader. 0 (default), 90, 180 or 270"),
        },
        "notas": [
            ("O NOME do primeiro parâmetro mudou entre versões -- era 'orientation' na 2.0.0 e hoje é 'p_orientation'. Quem chama por posição (AddPage('L')) não sente nada; quem chama por nome (AddPage(orientation => 'L')) precisa acertar o nome. Não há como aceitar os dois: sobrecargas que diferem só pelo nome do parâmetro deixam a chamada ambígua, e o Oracle recusa com PLS-00307. Quem chama por posição não é afetado.",
             "The NAME of the first parameter changed between versions -- it was 'orientation' in 2.0.0 and today it is 'p_orientation'. Callers that pass by position (AddPage('L')) are unaffected; callers that pass by name (AddPage(orientation => 'L')) have to use the new name. There is no way to accept both: overloads differing only in parameter name make the call ambiguous, and Oracle refuses them with PLS-00307."),
        ],
    },
    "SetPage": {
        "descricao": ("Torna corrente uma página já criada, para escrever nela de novo. Serve para preencher depois um espaço que só se sabe no fim -- um total, por exemplo.",
                      "Chooses which existing page receives the content of the next calls, so you can go back to an earlier page — to fill in a table of contents once the final page numbers are known, for instance."),
        "params": {
            "p_page_number": ("a página, que precisa existir",
                             "Page that becomes the current one. Integer >= 1, up to GetPageCount"),
        },
    },
    "GetCurrentPage": {
        "descricao": ("Devolve o número da página em que se está escrevendo.",
                      "Returns the number of the current page — the one receiving content."),
        "retorno": ("PLS_INTEGER - a página corrente",
                    "PLS_INTEGER — number of the active page. **See also:** [SetPage](#setpage), [PageNo](#pageno)"),
    },
    "fpdf": {
        "descricao": ("Construtor herdado do FPDF original. Continua valendo, e o código escrito para as versões 0.9.4 e 2.0.0 segue rodando com ele. Em código novo prefira Init, que valida os argumentos e levanta erro nomeado em vez de seguir com um valor inesperado.",
                      "Initialises the document in the classic FPDF style. Kept for compatibility with v0.9.4; use Init in new code."),
        "params": {
            "orientation": ("'P' (Portrait, retrato) ou 'L' (Landscape, paisagem)",
                           "Orientation. 'P' (default) or 'L'"),
            "unit": ("unidade de medida ('mm','cm','in','pt')",
                    "Unit of measurement. 'mm' (default), 'cm', 'pt' or 'in'"),
            "format": ("formato da página ('A4', 'Letter'...)",
                      "Page format. 'A3', 'A4' (default), 'A5', 'Letter' or 'Legal'"),
        },
    },
    "Error": {
        "descricao": ("Levanta ORA-20100 com a mensagem dada, acrescentando o rastro da origem e preservando a pilha original (keeperrorstack) -- é isso que mantém rastreável o erro de verdade por trás do -20100. É o caminho interno de erro da biblioteca; está público por herança.",
                      "Raises a standard PL_FPDF error. For internal use and for extensions."),
        "params": {
            "pmsg": ("a mensagem",
                    "Error message. Any VARCHAR2"),
        },
    },
    "DebugEnabled": {
        "descricao": ("Liga a saída de diagnóstico do tratamento de erro. Serve para depuração; num processo em produção deixa o erro mais verboso.",
                      "Turns the package's debug messages on."),
    },
    "DebugDisabled": {
        "descricao": ("Desliga a saída de diagnóstico. É o estado padrão.",
                      "Turns the debug messages off."),
    },
    "GetScaleFactor": {
        "descricao": ("Devolve quantos pontos PDF valem uma unidade corrente -- 2,8346 para milímetro, 1 para ponto. É o número que converte entre a unidade do chamador e a do arquivo.",
                      "Returns the conversion factor between the document's unit and PDF points."),
        "retorno": ("NUMBER - pontos por unidade",
                    "NUMBER — the scale factor, e.g. 2.8346 for millimetres. **See also:** [Init](#init)"),
    },
    "getImageFromUrl": {
        "descricao": ("Busca uma imagem pela rede e devolve os bytes com o cabeçalho já interpretado. Exige ACL de rede concedida ao schema. Substitui a implementação sobre OrdImage, que saiu de linha.",
                      "Downloads an image from a URL through UTL_HTTP for use in the document. The database needs a network ACL for this."),
        "params": {
            "p_Url": ("a URL da imagem (http/https)",
                     "Address of the image. http:// or https:// URL reachable from the database"),
        },
        "retorno": ("recImageBlob - os bytes e os metadados",
                    "recImageBlob — record with the image's content and metadata. **See also:** [Image](#image)"),
        "notas": [
            ("Formatos aceitos: PNG, JPEG/JPG",
             "Accepted formats: PNG, JPEG/JPG"),
        ],
    },
    "SetLogLevel": {
        "descricao": ("Define quanta informação a biblioteca escreve no DBMS_OUTPUT.",
                      "Sets how detailed the package's log messages are."),
        "params": {
            "p_level": ("0 desligado (OFF), 1 erro (ERROR), 2 aviso (WARN), 3 informação (INFO), 4 depuração (DEBUG)",
                       "Log level. 0 (off), 1 (error), 2 (warning), 3 (info) or 4 (debug)"),
        },
    },
    "GetLogLevel": {
        "descricao": ("Devolve o nível de registro em uso.",
                      "Returns the configured log level."),
        "retorno": ("PLS_INTEGER - o nível corrente (0-4)",
                    "PLS_INTEGER — the current level (0 to 4). **See also:** [SetLogLevel](#setloglevel)"),
    },
    "SetDocumentConfig": {
        "descricao": ("Configura o documento inteiro a partir de um objeto JSON -- metadados, orientação, formato, fonte e margens numa chamada só. Serve a quem recebe a configuração de fora, de uma tabela ou de um serviço.",
                      "Sets several document metadata fields and options at once, from a JSON object."),
        "params": {
            "p_config": ("o objeto JSON com as opções",
                        "Document configuration. JSON_OBJECT_T with the optional keys: title, subject, author, keywords, creator, compression (boolean)"),
        },
        "notas": [
            ("Chaves JSON: - title, author, subject, keywords, creator (metadados do documento) - orientation ('P' ou 'L'), unit ('mm','cm','in','pt'), format (formato da página) - fontFamily, fontSize, fontStyle (fonte padrão) - leftMargin, topMargin, rightMargin (margens, na unidade corrente)",
             "JSON keys: - title, author, subject, keywords, creator (document metadata) - orientation ('P' or 'L'), unit ('mm','cm','in','pt'), format (page format) - fontFamily, fontSize, fontStyle (default font) - leftMargin, topMargin, rightMargin (margins, in the current unit)"),
        ],
    },
    "GetDocumentMetadata": {
        "descricao": ("Devolve, em JSON, o que está configurado no documento em andamento e quantas páginas ele já tem.",
                      "Returns the metadata currently set on the document."),
        "retorno": ("JSON_OBJECT_T - os metadados",
                    "JSON_OBJECT_T — object with title, subject, author, keywords, creator and the remaining options. **See also:** [SetDocumentConfig](#setdocumentconfig)"),
        "notas": [
            ("Estrutura do JSON: { \"pageCount\": <number>, \"title\": \"<string>\", \"author\": \"<string>\", \"subject\": \"<string>\", \"keywords\": \"<string>\", \"format\": \"<string>\", \"orientation\": \"<string>\", \"unit\": \"<string>\", \"initialized\": <boolean> }",
             "JSON structure: { \"pageCount\": <number>, \"title\": \"<string>\", \"author\": \"<string>\", \"subject\": \"<string>\", \"keywords\": \"<string>\", \"format\": \"<string>\", \"orientation\": \"<string>\", \"unit\": \"<string>\", \"initialized\": <boolean> }"),
        ],
    },
    "GetPageInfo": {
        "descricao": ("Devolve, em JSON, o formato, a orientação e as medidas de uma página do documento em andamento.",
                      "Returns information about a page of the document being built."),
        "params": {
            "p_page_number": ("a página ( NULL = a corrente)",
                             "Page to query. Integer >= 1, up to GetPageCount; NULL (default) = the current page"),
        },
        "retorno": ("JSON_OBJECT_T - os dados da página",
                    "JSON_OBJECT_T — width, height, orientation and rotation of the page. **See also:** [GetCurrentPage](#getcurrentpage), [GetPDFInfo](#getpdfinfo)"),
        "notas": [
            ("Estrutura do JSON: { \"number\": <number>, \"format\": \"<string>\", \"orientation\": \"<string>\", \"width\": <number>, \"height\": <number>, \"unit\": \"<string>\" }",
             "JSON structure: { \"number\": <number>, \"format\": \"<string>\", \"orientation\": \"<string>\", \"width\": <number>, \"height\": <number>, \"unit\": \"<string>\" }"),
        ],
    },
    "AddQRCode": {
        "descricao": ("Desenha um QR Code na página corrente. O codificador é o do PL_FPDF_UTIL, validado contra o zxing-cpp -- o critério aqui não é \"desenha um símbolo\", é \"um leitor decodifica\".",
                      "Draws a QR code on the current page, with a configurable content format and error-correction level."),
        "params": {
            "p_x": ("canto superior esquerdo, na unidade corrente",
                   "X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_y": ("canto superior esquerdo, na unidade corrente",
                   "Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_size": ("o lado do símbolo",
                      "Side of the QR code (width = height). Number in the unit set by Init (mm, cm, pt or in)"),
            "p_data": ("o conteúdo a codificar",
                      "Content to encode. Up to 2953 bytes in binary mode; the content must follow the format chosen in p_format"),
            "p_format": ("'TEXT', 'URL', 'PIX', 'VCARD', 'WIFI', 'EMAIL'",
                        "Content format, which tells readers how to interpret the code. 'TEXT' (default, free text), 'URL', 'PIX', 'VCARD', 'WIFI' or 'EMAIL'"),
            "p_error_correction": ("quanto do símbolo pode ser perdido e ainda assim ler: 'L' (Low, 7%), 'M' (Medium, 15%), 'Q' (Quartile, 25%) ou 'H' (High, 30%). Quanto maior, mais módulos o símbolo ocupa",
                                  "Error-correction level: the higher it is, the better the code survives dirt and creases, and the less data fits. 'L' (7%), 'M' (15%, default), 'Q' (25%) or 'H' (30%)"),
        },
    },
    "AddBarcode": {
        "descricao": ("Desenha um código de barras linear na página corrente. O codificador é o do PL_FPDF_UTIL, validado contra o zxing-cpp.",
                      "Draws a linear barcode on the current page, with an optional human-readable caption."),
        "params": {
            "p_x": ("canto superior esquerdo",
                   "X of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_y": ("canto superior esquerdo",
                   "Y of the top-left corner. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_width": ("largura",
                       "Total width of the code. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_height": ("altura",
                        "Height of the bars. Number in the unit set by Init (mm, cm, pt or in)"),
            "p_code": ("o conteúdo a codificar",
                      "Data to encode. It must match the chosen symbology: EAN13 = 13 digits, EAN8 = 8 digits, ITF = any even number of digits (a Brazilian bank slip uses 44), ITF14 = 14 digits, CODE39 = uppercase alphanumeric, CODE128 = ASCII"),
            "p_type": ("simbologia: 'CODE128', 'CODE39', 'EAN13', 'EAN8', 'ITF14', ou 'ITF' (Interleaved 2 of 5, qualquer quantidade par de dígitos -- o código de barras do boleto bancário tem 44)",
                      "Barcode symbology. 'CODE128' (default), 'CODE39', 'EAN13', 'EAN8', 'ITF' or 'ITF14'"),
            "p_show_text": ("escrever o código embaixo, legível",
                           "Prints the readable value below the bars. TRUE or FALSE; TRUE is the default"),
        },
    },
    "LoadPDF": {
        "descricao": ("Carregar documento PDF existente na memória para leitura e modificação",
                      "Loads an existing PDF into session memory for reading and modification. It is the starting point of the whole manipulation flow, which ends at OutputModifiedPDF."),
        "params": {
            "p_pdf_blob": ("Documento PDF como BLOB",
                          "PDF document to load. Non-null BLOB with a valid %PDF header"),
        },
    },
    "GetPageCount": {
        "descricao": ("Obter o número total de páginas no documento PDF carregado",
                      "Returns the total page count of the loaded PDF, including the pages marked for removal."),
        "retorno": ("Número de páginas",
                    "PLS_INTEGER — number of pages."),
    },
    "GetPDFInfo": {
        "descricao": ("Obter metadados e informações sobre o documento PDF carregado",
                      "Returns information about the loaded PDF: version, metadata and page count."),
        "retorno": ("com: - version: versão do PDF (por exemplo \"1.4\") - pageCount: Número de páginas - fileSize: Tamanho em bytes - objectCount: Número de objetos na xref - rootObjectId: ID do objeto Catalog",
                    "JSON_OBJECT_T — PDF version, title, author, page count and the remaining metadata."),
    },
    "RotatePage": {
        "descricao": ("Rotacionar uma página específica (armazenado em memória, aplicado na saída)",
                      "Rotates a page of the loaded PDF."),
        "params": {
            "p_page_number": ("Número da página para rotacionar",
                             "Page to rotate. Integer >= 1, up to GetPageCount"),
            "p_rotation": ("Ângulo de rotação (0, 90, 180, 270)",
                          "Rotation angle applied. 0, 90, 180 or 270"),
        },
        "notas": [
            ("Mudanças armazenadas em memória. Use OutputModifiedPDF() para gerar PDF",
             "Changes are kept in memory. Use OutputModifiedPDF() to produce the PDF"),
        ],
    },
    "RemovePage": {
        "descricao": ("Marcar uma página para remoção do PDF",
                      "Marks a page of the loaded PDF for removal. The deletion is logical: it is only applied by OutputModifiedPDF."),
        "params": {
            "p_page_number": ("Número da página para remover",
                             "Page to remove. Integer >= 1, up to GetPageCount"),
        },
        "notas": [
            ("Página marcada para remoção. Use OutputModifiedPDF() para gerar PDF modificado",
             "The page is marked for removal. Use OutputModifiedPDF() to produce the modified PDF"),
        ],
    },
    "GetActivePageCount": {
        "descricao": ("Obter contagem de páginas não marcadas para remoção",
                      "Returns how many pages will remain once the pending removals are applied."),
        "retorno": ("Número de páginas ativas",
                    "PLS_INTEGER — pages not marked for removal. **See also:** [RemovePage](#removepage), [GetPageCount](#getpagecount)"),
        "notas": [
            ("Difere de GetPageCount() que retorna a contagem original",
             "Differs from GetPageCount(), which returns the original count"),
        ],
    },
    "IsPageRemoved": {
        "descricao": ("Verificar se uma página está marcada para remoção",
                      "Tells whether a page is marked for removal."),
        "params": {
            "p_page_number": ("Número da página para verificar",
                             "Page to query. Integer >= 1, up to GetPageCount"),
        },
        "retorno": ("caso contrário",
                    "BOOLEAN — TRUE if the page will be removed from the output. **See also:** [RemovePage](#removepage)"),
    },
    "IsPDFModified": {
        "descricao": ("Verificar se o PDF carregado foi modificado",
                      "Tells whether there are pending changes — rotation, removal, watermark, overlay — on the loaded PDF."),
        "retorno": ("TRUE se modificado, FALSE caso contrário",
                    "BOOLEAN — TRUE if there are changes not yet applied. **See also:** [OutputModifiedPDF](#outputmodifiedpdf)"),
        "notas": [
            ("Use para determinar se OutputModifiedPDF() precisa ser chamado",
             "Use it to decide whether OutputModifiedPDF() has to be called"),
        ],
    },
    "AddWatermark": {
        "descricao": ("Acrescenta marca d'água de texto às páginas indicadas",
                      "Registers a text watermark, drawn by OutputModifiedPDF() into the page content stream: every affected page gets a content object and a /Resources of its own, so a /Resources shared between pages is never contaminated. The mark is centred and rotated about the centre of the page, always in Helvetica."),
        "params": {
            "p_text": ("Texto da marca d'água",
                      "Watermark text. Any VARCHAR2, e.g. 'CONFIDENTIAL'"),
            "p_opacity": ("Opacidade (0.0 a 1.0), padrão 0.3",
                         "Opacity of the mark. 0.0 (invisible) to 1.0 (opaque); 0.3 is the default"),
            "p_rotation": ("Ângulo de rotação (0, 45, 90, 135, 180, 225, 270, 315), default 45",
                          "Text angle in degrees. 0 to 360; 45 (diagonal) is the default"),
            "p_pages": ("Range de páginas: 'ALL', '1-5', '1,3,5', default 'ALL'",
                       "Pages that receive the mark. 'ALL' (default), or a list/ranges such as '1', '1,3,5', '2-8', '1,3-5,10'"),
            "p_font": ("Nome da fonte, default 'Helvetica'",
                      "Font used. 'Helvetica' (default), 'Arial', 'Times' or 'Courier'"),
            "p_size": ("Tamanho da fonte em pontos, default 48",
                      "Font size in points. Number > 0; 48 is the default"),
            "p_color": ("Nome da cor ('gray', 'red', 'blue'), default 'gray'",
                       "Colour of the watermark. 'gray' (default), 'red', 'blue', 'green', 'black', or an RGB hex value such as 'FF0000'"),
        },
        "notas": [
            ("Desenhada por OutputModifiedPDF() no fluxo de conteúdo: cada página afetada ganha um objeto de conteúdo próprio e um /Resources próprio, de modo que um /Resources compartilhado entre páginas nunca é contaminado. Centralizada e girada em torno do centro da página; a fonte é sempre Helvetica.",
             "Drawn by OutputModifiedPDF() into the content stream: each affected page gets a content object of its own and a /Resources of its own, so a /Resources shared between pages is never contaminated. Centred and rotated around the centre of the page; the font is always Helvetica."),
        ],
    },
    "GetWatermarks": {
        "descricao": ("Obter lista de todas as marcas d'água aplicadas como array JSON",
                      "Lists every watermark applied to the loaded PDF."),
        "retorno": ("JSON_ARRAY_T - array com os objetos de marca d'água e suas propriedades: - id: ID da marca d'água - text: Texto da marca d'água - opacity: Valor de opacidade (0.0-1.0) (0.0-1.0) - rotation: Ângulo de rotação em graus - pageRange: faixa de páginas (separada por vírgulas) - font: Nome da fonte - fontSize: Tamanho da fonte em pontos - color: Nome da cor",
                    "JSON_ARRAY_T — objects with id, text, opacity, rotation, pageRange, font, fontSize and color."),
    },
    "OutputModifiedPDF": {
        "descricao": ("Gerar o PDF modificado copiando as páginas mantidas objeto a objeto. Conteúdo, fontes, imagens e anotações são copiados sem alteração: nada é re-renderizado. Aplica RemovePage e RotatePage.",
                      "Produces the PDF with the changes applied, copying the kept pages object by object: content, fonts, images and annotations arrive intact, with no re-rendering. It applies RemovePage and RotatePage, and draws watermarks and text and image overlays into the content stream: every affected page gets a content object and a /Resources of its own."),
        "retorno": ("Documento PDF modificado",
                    "BLOB — the modified PDF."),
        "notas": [
            ("1. Valida se PDF está carregado e modificado 2. Indexa a origem (cadeia de xref + árvore de páginas achatada) 3. Seleciona as páginas não marcadas por RemovePage, na ordem original 4. Copia todo objeto alcançável a partir dessas páginas, renumerando as referências indiretas; o payload dos streams é copiado byte a byte 5. Emite um novo Catalog, um novo nó /Pages, xref e trailer",
             "1. Checks that a PDF is loaded and modified 2. Indexes the source (xref chain + flattened page tree) 3. Selects the pages not marked by RemovePage, in the original order 4. Copies every object reachable from those pages, renumbering the indirect references; stream payloads are copied byte for byte 5. Emits a new Catalog, a new /Pages node, xref and trailer"),
            ("Marcas d'água e overlays de texto e de imagem são todos desenhados. xref em stream e object streams (PDF 1.5+) são lidos, inclusive com o predictor PNG; um malformado levanta -20843/-20847/-20848.",
             "Watermarks and both text and image overlays are all drawn. Cross-reference streams and object streams (PDF 1.5+) are read, including with the PNG predictor; a malformed one raises -20843/-20847/-20848."),
        ],
    },
    "ClearPDFCache": {
        "descricao": ("Limpar PDF carregado da memória e liberar todos os recursos em cache",
                      "Discards the loaded PDFs and frees the memory used by manipulation."),
        "notas": [
            ("Sempre chame isso após processar um PDF para liberar recursos de memória. Limpa: PDF carregado, info páginas, rotações, páginas removidas, marcas d'água.",
             "Always call it after processing a PDF to release memory. It clears: the loaded PDF, page info, rotations, removed pages and watermarks."),
        ],
    },
    "FlateDecode": {
        "descricao": ("Descomprime um stream /FlateDecode do PDF (zlib, RFC 1950). Implementado em PL/SQL puro: o UTL_COMPRESS não serve porque só aceita rodapé gzip com CRC-32 correto, e esse CRC é do conteúdo DESCOMPRIMIDO — para saber o CRC seria preciso descomprimir antes.",
                      "Decompresses a PDF /FlateDecode stream (zlib, RFC 1950). Implemented in pure PL/SQL, because UTL_COMPRESS will not do: it only accepts a gzip trailer with a correct CRC-32, and that CRC is of the DECOMPRESSED content — to know it you would have to decompress first. Useful in its own right, and it is what lets the copier read cross-reference streams and object streams."),
        "params": {
            "p_stream": ("Stream comprimido (BLOB)",
                        "Compressed stream. BLOB with zlib data — what the PDF marks as /FlateDecode"),
            "p_max_bytes": ("Teto da saída, 8 MB por padrão. Um stream comprimido é entrada não confiável: alguns KB podem virar gigabytes (zip bomb) e derrubar a sessão. Levanta -20893 em vez disso.",
                           "Output ceiling, in bytes. Number > 0; 8388608 (8 MB) is the default. A compressed stream is UNTRUSTED input: a few KB can expand into gigabytes (a zip bomb) and bring the session down with ORA-04036. With the ceiling it raises -20893 and says where it stopped"),
        },
        "retorno": ("Conteúdo descomprimido",
                    "BLOB — the decompressed content."),
    },
    "FlateEncode": {
        "descricao": ("Comprime dados num stream /FlateDecode do PDF (zlib, RFC 1950). Escrito em PL/SQL puro: um bloco único com Huffman fixa e LZ77 guloso. Comprime menos que a Huffman dinâmica do zlib e muito mais que nada, e nunca devolve mais que a entrada somada ao custo do bloco armazenado.",
                      "Compresses data into a PDF /FlateDecode stream (zlib, RFC 1950). Written in pure PL/SQL: a single block with FIXED Huffman and greedy LZ77 — it compresses less than zlib's dynamic Huffman, and far more than nothing. When the data is incompressible it falls back to a stored block, so the output never exceeds the input plus the block overhead."),
        "params": {
            "p_data": ("conteúdo a comprimir (BLOB)",
                      "Content to compress. BLOB of any size; NULL is treated as empty"),
        },
        "retorno": ("BLOB - stream zlib: cabeçalho, DEFLATE e Adler-32",
                    "BLOB — zlib stream: header, DEFLATE and Adler-32. **See also:** [FlateDecode](#flatedecode), [SetCompression](#setcompression)"),
    },
    "OverlayText": {
        "descricao": ("Adicionar sobreposição de texto em posição específica com controle completo de formatação Desenhada por OutputModifiedPDF() no fluxo de conteúdo. x e y vão em pontos PDF, a partir do canto inferior esquerdo. Quando width é informado ele define a CAIXA do texto: as linhas quebram dentro dela e o align é relativo a [x, x+width]. Sem width não há o que quebrar, e o align passa a ser relativo ao próprio ponto — 'center' centraliza o texto em x, 'right' o termina em x.",
                      "Places text at an exact position on a page of the loaded PDF — stamps, protocol numbers, signatures. Coordinates are in PDF points, with Y growing upwards from the bottom. Drawn by OutputModifiedPDF() into the content stream. When width is given it defines the text BOX: lines wrap inside it and align is relative to [x, x+width]. Without width there is nothing to wrap, and align becomes relative to the point itself — 'center' centres the text on x, 'right' ends it at x."),
        "params": {
            "p_page_number": ("Número da página (base 1)",
                             "Page that receives the text. Integer >= 1, up to GetPageCount"),
            "p_text": ("Conteúdo do texto",
                      "Text to overlay. Any VARCHAR2"),
            "p_x": ("Posição X (1 point = 1/72 inch, from left)",
                   "X position in PDF points (1 pt = 1/72 in), from the left. 0 to 612 on A4 portrait"),
            "p_y": ("Posição Y (de baixo) (from bottom)",
                   "Y position in PDF points, from the bottom of the page. 0 to 792 on A4 portrait"),
            "p_options": ("Configuração JSON (opcional)",
                         "Visual settings of the text. JSON_OBJECT_T with the optional keys: font ('Helvetica'/'Arial', 'Times' or 'Courier'; any other name falls back to Helvetica), fontSize (number, 12), color (RGB hex, '000000'), opacity (0.0-1.0), rotation (0-360), align ('left', 'center', 'right'), width (box width in points: sets the line breaking and the reference for align), bold (true/false), zOrder (integer; higher goes on top, being drawn last)"),
        },
        "notas": [
            ("Opções (JSON_OBJECT_T): { \"font\": \"Helvetica\", // Nome da fonte \"fontSize\": 12, // Tamanho da fonte \"color\": \"000000\", // Cor RGB hexadecimal \"opacity\": 1.0, // Opacidade 0.0 a 1.0 \"rotation\": 0, // ângulo de rotação (0-360) \"align\": \"left\", // esquerda, centro, direita \"width\": null, // largura máxima (quebra sozinho) \"bold\": false, // Texto em negrito \"zOrder\": 100 // ordem da camada (maior fica por cima) }",
             "Options (JSON_OBJECT_T): { \"font\": \"Helvetica\", // Font name \"fontSize\": 12, // Font size \"color\": \"000000\", // RGB colour in hex \"opacity\": 1.0, // Opacity 0.0 to 1.0 \"rotation\": 0, // Rotation angle (0-360) \"align\": \"left\", // left, center, right \"width\": null, // maximum width (wraps on its own) \"bold\": false, // Bold text \"zOrder\": 100 // layer order (higher goes on top) }"),
        ],
    },
    "OverlayImage": {
        "descricao": ("Adicionar sobreposição de imagem em posição específica com controle de tamanho Desenhada por OutputModifiedPDF() no fluxo de conteúdo. No caminho comum nada é descomprimido: o JPEG entra inteiro como /DCTDecode, e os blocos IDAT do PNG já são zlib, que é o /FlateDecode do PDF — são concatenados e declarados com /Predictor 15, o que vale de 1 a 16 bits por componente. PNG com canal alfa (color types 4 e 6) e entrelaçado (Adam7) também são desenhados, por um caminho que reprocessa pixel a pixel — e por isso sai sem compressão, já que não há deflate neste trecho. Recusados com -20823, em vez de desenhados errado: entrelaçado com menos de 8 bits por componente, indexado E entrelaçado, e imagem acima do teto de pixels do caminho que reprocessa.",
                      "Places an image at an exact position on a page of the loaded PDF — logos, scanned signatures, seals. Drawn by OutputModifiedPDF() into the content stream. Neither format is decompressed: JPEG goes in whole as /DCTDecode, and a PNG's IDAT blocks are already zlib, which is the PDF's /FlateDecode. Not supported, and refused with -20823 rather than drawn wrong: PNG with an alpha channel, interlaced PNG (Adam7) and 16-bit depth."),
        "params": {
            "p_page_number": ("Número da página (base 1)",
                             "Page that receives the image. Integer >= 1, up to GetPageCount"),
            "p_image_blob": ("os bytes da imagem, em JPEG ou PNG",
                            "Image content. BLOB in JPEG or PNG format"),
            "p_x": ("Posição X em pontos PDF",
                   "X position in PDF points. 0 to 612 on A4 portrait"),
            "p_y": ("Posição Y (de baixo) (from bottom)",
                   "Y position in PDF points, from the bottom. 0 to 792 on A4 portrait"),
            "p_width": ("Largura em pontos ( NULL = original)",
                       "Width in points. Number > 0; NULL (default) uses the original width"),
            "p_height": ("Altura em pontos ( NULL = original)",
                        "Height in points. Number > 0; NULL (default) uses the original height, or keeps the aspect ratio"),
            "p_options": ("Configuração JSON (opcional)",
                         "Image settings. JSON_OBJECT_T with the optional keys: opacity (0.0-1.0), rotation (0-360), maintainAspect (true/false), scaleToFit (true/false), zOrder (integer)"),
        },
        "notas": [
            ("Opções (JSON_OBJECT_T): { \"opacity\": 1.0, // Opacidade 0.0 a 1.0 \"rotation\": 0, // Ângulo de rotação \"maintainAspect\": true, // Manter proporção \"scaleToFit\": false, // Escalar para caber \"zOrder\": 100 // Ordem da camada }",
             "Options (JSON_OBJECT_T): { \"opacity\": 1.0, // Opacity 0.0 to 1.0 \"rotation\": 0, // Rotation angle \"maintainAspect\": true, // Keep the aspect ratio \"scaleToFit\": false, // Scale to fit \"zOrder\": 100 // Layer order }"),
        ],
    },
    "GetOverlays": {
        "descricao": ("Obter lista de todas as sobreposições aplicadas como array JSON",
                      "Lists the overlays applied, optionally filtered by page."),
        "params": {
            "p_page_number": ("filtrar por página ( NULL = todas)",
                             "Page filter. Integer >= 1, up to GetPageCount; NULL (default) returns the overlays of every page"),
        },
        "retorno": ("JSON_ARRAY_T - Array de objetos de sobreposição [{ \"overlayId\": \"OVL_001\", \"overlayType\": \"TEXT\" | \"IMAGE\", \"pageNumber\": 1, \"x\": 100, \"y\": 700, \"content\": \"APPROVED\", // só para sobreposição de texto \"opacity\": 0.8, \"rotation\": 45, \"zOrder\": 100 }, ...]",
                    "JSON_ARRAY_T — objects with overlayId, overlayType ('TEXT' or 'IMAGE'), pageNumber, x, y, content, opacity, rotation and zOrder."),
    },
    "RemoveOverlay": {
        "descricao": ("Remover sobreposição específica por ID",
                      "Removes one specific overlay by its identifier."),
        "params": {
            "p_overlay_id": ("ID da sobreposição ()",
                            "Overlay identifier. The overlayId value returned by GetOverlays, e.g. 'OVL_001'"),
        },
    },
    "ClearOverlays": {
        "descricao": ("Limpar todas as sobreposições de todas ou de página específica",
                      "Removes every overlay, from one page or from the whole document."),
        "params": {
            "p_page_number": ("limpar da página ( NULL = todas)",
                             "Page to clear. Integer >= 1, up to GetPageCount; NULL (default) clears every page"),
        },
    },
    "LoadPDFWithID": {
        "descricao": ("Carregar PDF em memória com identificador único para operações multi-documento",
                      "Loads a PDF into memory under an identifier, so several documents can be held open at once to merge, split or extract pages."),
        "params": {
            "p_pdf_id": ("Identificador único (max 50 chars)",
                        "Identifier of the document within the session. Unique text, e.g. 'cover', 'annex1'"),
            "p_pdf_blob": ("Documento PDF como BLOB",
                          "Document to load. BLOB with a valid PDF"),
        },
        "notas": [
            ("Máximo de 10 PDFs podem ser carregados simultaneamente",
             "At most 10 PDFs can be loaded at the same time"),
        ],
    },
    "GetLoadedPDFs": {
        "descricao": ("Obter lista de todos os IDs de PDF carregados e seus metadados",
                      "Lists the documents currently loaded under an identifier."),
        "retorno": ("JSON_ARRAY_T - Array de objetos PDF [{ \"pdfId\": \"report_jan\", \"pageCount\": 5, \"fileSize\": 125678, \"loadedDate\": \"2026-01-25T10:30:00\" }, ...]",
                    "JSON_ARRAY_T — objects with the id and the information of each loaded PDF. **See also:** [LoadPDFWithID](#loadpdfwithid), [UnloadPDF](#unloadpdf)"),
    },
    "UnloadPDF": {
        "descricao": ("Remover PDF específico da memória para liberar recursos",
                      "Drops from memory a document loaded by LoadPDFWithID."),
        "params": {
            "p_pdf_id": ("Identificador do PDF",
                        "Document identifier. The same one used in LoadPDFWithID"),
        },
    },
    "MergePDFs": {
        "descricao": ("Mesclar múltiplos PDFs carregados em um único documento, na ordem dada. Todos os objetos de cada origem são copiados (páginas, fontes, imagens, anotações) com as referências indiretas renumeradas, e uma nova árvore de páginas é montada. Nada é re-renderizado: o conteúdo original chega intacto. O mesmo ID pode aparecer mais de uma vez.",
                      "Merges several loaded PDFs into a single document, in the order given. The objects of each source — pages, fonts, images, annotations — are copied with their indirect references renumbered: nothing is re-rendered and the original content arrives intact. The same identifier may appear more than once."),
        "params": {
            "p_pdf_ids": ("Array JSON de IDs de PDF Example: JSON_ARRAY_T('[\"pdf1\",\"pdf2\",\"pdf3\"]')",
                         "Identifiers of the documents, in the desired order. JSON_ARRAY_T of strings, e.g. JSON_ARRAY_T('[\"cover\",\"body\",\"annex\"]')"),
            "p_options": ("Configuração opcional (future use)",
                         "Merge options. Optional JSON_OBJECT_T; keys reserved for future use"),
        },
        "retorno": ("Documento PDF mesclado",
                    "BLOB — the merged PDF."),
    },
    "SplitPDF": {
        "descricao": ("Dividir o PDF carregado em vários documentos, um por intervalo. Cada parte leva apenas os objetos alcançáveis a partir das suas páginas, e por isso fica bem menor que a origem. Os intervalos não podem se sobrepor.",
                      "Splits a loaded PDF into several documents, following the ranges given. Each part carries only the objects reachable from its own pages, which is why it ends up far smaller than the source. The ranges may not overlap."),
        "params": {
            "p_pdf_id": ("Identificador do PDF",
                        "Identifier of the document to split. The same one used in LoadPDFWithID"),
            "p_page_ranges": ("Array de intervalos Examples: '1-5', '6-10', '11', '1,3,5', 'ALL'",
                             "Ranges defining each part produced. JSON_ARRAY_T of strings: '1-10', '11-20', '5' (a single page), '1,3,5' (a list) or 'ALL'"),
        },
        "retorno": ("Array com PDFs em base64, um por intervalo, sem quebras de linha",
                    "JSON_ARRAY_T — one entry per range, with the part's PDF in base64, without line breaks."),
    },
    "ExtractPages": {
        "descricao": ("Extrair as páginas indicadas de um PDF carregado para um novo documento. A ordem pedida é respeitada ('5,1' devolve a página 5 e depois a 1) e uma página pode repetir. Só os objetos alcançáveis a partir das páginas escolhidas são copiados, então o resultado fica menor que a origem.",
                      "Creates a new PDF holding only the selected pages of a loaded document. The requested order is honoured and a page may repeat; only the objects reachable from the chosen pages are copied, so the result is smaller than the source."),
        "params": {
            "p_pdf_id": ("Identificador do PDF",
                        "Identifier of the source document. The same one used in LoadPDFWithID"),
            "p_pages": ("Especificação: '1', '1,3,5-7,10', '5,1' ou 'ALL'",
                       "Pages to extract. Comma-separated list and ranges, e.g. '1', '1,5,9', '1,5-10,15', '5,1' (reversed order) or 'ALL'"),
            "p_options": ("Configuração opcional (future use)",
                         "Extraction options. Optional JSON_OBJECT_T; keys reserved for future use"),
        },
        "retorno": ("Novo PDF com páginas extraídas",
                    "BLOB — PDF with the extracted pages."),
    },
    "EncryptPDF": {
        "descricao": ("Criptografar PDF com proteção por senha seguindo especificação PDF",
                      "Encrypts an existing PDF, applying passwords and permissions. This is the recommended way to protect documents you generate or receive. A PDF 1.5+ source (cross-reference streams, object streams) is flattened: the objects inside object streams become top-level objects, and the output carries a classic cross-reference table."),
        "params": {
            "p_pdf": ("PDF blob para criptografar",
                     "Document to protect. BLOB with a valid, unencrypted PDF"),
            "p_user_password": ("Senha para abrir documento",
                               "Password asked for when opening the document. Text; empty allows opening without a password while keeping the restrictions"),
            "p_owner_password": ("senha de acesso total (opcional)",
                                "Owner password, which allows changing permissions. Text; NULL (default) reuses the user password"),
            "p_permissions": ("JSON com flags de permissão",
                             "Permissions granted to the reader. JSON_OBJECT_T with the boolean keys: print, modify, copy, annotate, fill_forms, extract, assemble, print_high. Missing keys take the restrictive default"),
            "p_encryption": ("Encryption method: 'RC4-40','RC4-128','AES-128','AES-256'",
                            "Encryption algorithm. 'AES-256' and 'AES-128' (recommended), 'RC4-128' (the default, kept for compatibility) or 'RC4-40' (legacy). RC4 has been broken for years and PDF 2.0 dropped it from the specification; recent readers warn about it or refuse it"),
        },
        "retorno": ("PDF criptografado",
                    "BLOB — the encrypted PDF."),
        "notas": [
            ("Origem em PDF 1.5+ (xref em stream, object streams) é achatada: os objetos de dentro dos object streams viram objetos de primeiro nível e a saída leva xref clássica.",
             "A PDF 1.5+ source (cross-reference streams, object streams) is flattened: the objects inside the object streams become top-level objects and the output carries a classic xref."),
        ],
    },
    "DecryptPDF": {
        "descricao": ("Remover criptografia do PDF usando senha",
                      "Removes the protection from an encrypted PDF, given the right password. It supports RC4-40, RC4-128, AES-128 (AESV2) and AES-256 (AESV3), with either the user or the owner password. The filter is read from the document's /CFM, not assumed. A PDF 1.5+ source is flattened, and object streams are decrypted before being decompressed."),
        "params": {
            "p_pdf": ("PDF blob criptografado",
                     "Encrypted document. BLOB with a protected PDF"),
            "p_password": ("Senha de usuário ou owner",
                          "User or owner password. Text matching one of the document's passwords"),
        },
        "retorno": ("PDF descriptografado",
                    "BLOB — the PDF without encryption."),
        "notas": [
            ("Origem em PDF 1.5+ é achatada, e os object streams são decifrados antes de descomprimidos.",
             "A PDF 1.5+ source is flattened, and the object streams are decrypted before being decompressed."),
        ],
    },
    "IsEncrypted": {
        "descricao": ("Verificar se PDF está criptografado",
                      "Checks whether a PDF is encrypted."),
        "params": {
            "p_pdf": ("PDF blob para verificar",
                     "Document to check. BLOB with a valid PDF"),
        },
        "retorno": ("TRUE se criptografado",
                    "BOOLEAN — TRUE if the document carries encryption. **See also:** [GetSecurityInfo](#getsecurityinfo), [DecryptPDF](#decryptpdf)"),
    },
    "GetSecurityInfo": {
        "descricao": ("Obter informações de segurança do PDF",
                      "Returns the security details of an encrypted PDF."),
        "params": {
            "p_pdf": ("PDF blob",
                     "Document to inspect. BLOB with a valid PDF"),
        },
        "retorno": ("JSON_OBJECT_T - Security info including: - encrypted: boolean - method: string (RC4-40, RC4-128, AES-128, AES-256) - permissions: object with print, copy, modify, etc. - hasUserPassword: boolean - hasOwnerPassword: boolean",
                    "JSON_OBJECT_T — algorithm, key length and the permissions granted. **See also:** [IsEncrypted](#isencrypted), [EncryptPDF](#encryptpdf)"),
    },
    "SetEncryption": {
        "descricao": ("Definir criptografia para PDF em geração (usar antes do Output)",
                      "Sets the encryption of a document being built; it is applied when the PDF is finalised by OutputBlob."),
        "params": {
            "p_encryption": ("Method: 'RC4-40','RC4-128','AES-128','AES-256'",
                            "Encryption algorithm. 'RC4-128' or 'RC4-40'"),
            "p_user_password": ("Senha para abrir",
                               "Opening password. Text"),
            "p_owner_password": ("Senha acesso total",
                                "Owner password. Text; NULL (default) = same as the user password"),
        },
        "notas": [
            ("Mapeamento de Versão: RC4-40/RC4-128 -> PDF 1.4 AES-128 -> PDF 1.5 AES-256 -> PDF 1.7",
             "Version mapping: RC4-40/RC4-128 -> PDF 1.4 AES-128 -> PDF 1.5 AES-256 -> PDF 1.7"),
        ],
    },
    "SetPDFVersion": {
        "descricao": ("Definir a versão do PDF para documentos gerados",
                      "Sets the version declared in the header of the generated PDF."),
        "params": {
            "p_version": ("PDF version: '1.4', '1.5', '1.6', '1.7', '2.0'",
                         "PDF file version. '1.4', '1.5', '1.6' or '1.7'"),
        },
        "notas": [
            ("Recursos por Versão: 1.4: cifra RC4 de 128 bits, transparência 1.5: AES de 128 bits, object streams, cross-reference streams 1.6: AES de 128 bits, fontes OpenType 1.7: AES de 256 bits, formulários XFA 2.0: só AES de 256 bits, sem RC4",
             "Features by version: 1.4: 128-bit RC4 encryption, transparency 1.5: 128-bit AES, object streams, cross-reference streams 1.6: 128-bit AES, OpenType fonts 1.7: 256-bit AES, XFA forms 2.0: 256-bit AES only, no RC4"),
        ],
    },
    "GetPDFVersion": {
        "descricao": ("Obter a configuração atual de versão do PDF",
                      "Returns the PDF version configured for the output."),
        "retorno": ("VARCHAR2 - a versão de PDF corrente (por exemplo '1.4')",
                    "VARCHAR2 — the version, e.g. '1.7'. **See also:** [SetPDFVersion](#setpdfversion)"),
    },
    "SetPermissions": {
        "descricao": ("Definir permissões do documento (requer SetEncryption antes)",
                      "Sets the permissions of the document being built, applied together with the encryption defined in SetEncryption."),
        "params": {
            "p_print": ("Permitir impressão",
                       "Allows printing. TRUE or FALSE; TRUE is the default"),
            "p_modify": ("Permitir modificação",
                        "Allows changing the content. TRUE or FALSE; FALSE is the default"),
            "p_copy": ("Permitir cópia/extração",
                      "Allows copying text and images. TRUE or FALSE; FALSE is the default"),
            "p_annotate": ("Permitir anotações",
                          "Allows adding comments and annotations. TRUE or FALSE; TRUE is the default"),
            "p_fill_forms": ("Permitir preenchimento de formulários",
                            "Allows filling in form fields. TRUE or FALSE; TRUE is the default"),
            "p_extract": ("Permitir extração de conteúdo",
                         "Allows extracting content for accessibility. TRUE or FALSE; FALSE is the default"),
            "p_assemble": ("Permitir montagem de documento",
                          "Allows inserting, removing and rotating pages. TRUE or FALSE; FALSE is the default"),
            "p_print_high": ("Permitir impressão alta qualidade",
                            "Allows high-resolution printing. TRUE or FALSE; TRUE is the default"),
        },
    },
}


def _sem_traducao(faltas):
    raise SystemExit(
        'a referência em inglês está atrás da spec — '
        + str(len(faltas)) + ' texto(s) sem par em textos_en.py:\n  '
        + '\n  '.join(faltas[:40])
        + ('\n  ...' if len(faltas) > 40 else '')
        + '\n\nCorrija o par (pt, en) em dev/scripts/gen_docs/textos_en.py.')


def traduzir(api, subitens):
    """A mesma estrutura da API, com o texto em inglês no lugar do português.

    `subitens` reparte a enumeração de um `@param` (`0 = ...`, `1 = ...`) da
    mesma forma que o `parse_javadoc` faz no português, para que a tabela saia
    com as opções uma por linha nas duas línguas.

    Para em vez de publicar pela metade: texto sem par, ou com o português
    diferente do que está na spec hoje, é falha -- é o único jeito de a página
    em inglês não envelhecer em silêncio, como envelheceu antes.
    """
    faltas, saida = [], []

    def par(onde, campo, pt, entrada):
        if entrada is None:
            faltas.append(f'{onde}: {campo} sem tradução — PT: {pt[:70]}')
            return ''
        if entrada[0] != pt:
            faltas.append(f'{onde}: {campo} mudou em PT desde a tradução\n'
                          f'      spec: {pt[:90]}\n'
                          f'      aqui: {entrada[0][:90]}')
            return ''
        return entrada[1]

    for a in api:
        t = TEXTOS.get(a['nome'])
        if t is None:
            faltas.append(f'{a["nome"]}: API sem entrada em TEXTOS')
            continue
        b = dict(a)
        b['descricao'] = par(a['nome'], 'descrição', a['descricao'],
                             t.get('descricao'))
        ps = t.get('params', {})
        novos = []
        for p in a['params']:
            pt = ' '.join([p['texto']] + p.get('itens', [])).strip()
            en = par(a['nome'], f'@param {p["nome"]}', pt, ps.get(p['nome']))
            texto, itens = subitens(en)
            novos.append({'nome': p['nome'], 'texto': texto, 'itens': itens})
        b['params'] = novos
        if a['retorno']:
            b['retorno'] = par(a['nome'], '@return', a['retorno'],
                               t.get('retorno'))
        ns = t.get('notas', [])
        b['notas'] = [
            {'tipo': n['tipo'],
             'texto': par(a['nome'], f'@{n["tipo"]}', n['texto'],
                          ns[i] if i < len(ns) else None)}
            for i, n in enumerate(a['notas'])]
        b['exemplo'] = exemplo_em_ingles(a['nome'], a['exemplo'], faltas)
        b['erros'] = [
            {'codigo': e['codigo'],
             'texto': ERROS.get((e['codigo'].lstrip('-'), e['texto']))
             or (faltas.append(f'{a["nome"]}: ORA{e["codigo"]} sem tradução '
                               f'— PT: {e["texto"][:70]}') or '')}
            for e in a['erros']]
        saida.append(b)
    if faltas:
        _sem_traducao(faltas)
    return saida


# O exemplo é CÓDIGO, e sai igual nas duas páginas -- menos o comentário e o
# literal, que são texto corrido em português. Aqui está a linha vertida, e a
# chave é a linha inteira como está na spec: mudou o exemplo, a entrada não
# casa e o gerador para.
EXEMPLOS = {
 ('SetDash', '  PL_FPDF.SetDash;                -- volta à linha cheia'):
     '  PL_FPDF.SetDash;                -- back to the solid line',
 ('SetY', '  PL_FPDF.SetY(-20);   -- 20 acima do pé'):
     '  PL_FPDF.SetY(-20);   -- 20 above the foot of the page',
 ('SetTitle', "  PL_FPDF.SetTitle('Relatório de Produção');"):
     "  PL_FPDF.SetTitle('Production Report');",
 ('SetCreator', "  PL_FPDF.SetCreator('ERP - modulo de faturamento');"):
     "  PL_FPDF.SetCreator('ERP - billing module');",
 ('SetAliasNbPages',
  "  PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo || ' de {nb}');"):
     "  PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo || ' of {nb}');",
 ('Header',
  "  PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');   -- e o resto é automático"):
     "  PL_FPDF.SetHeaderProc('MY_PKG.HEADER');       -- the rest is automatic",
 ('Footer',
  "  PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');      -- e o resto é automático"):
     "  PL_FPDF.SetFooterProc('MY_PKG.FOOTER');       -- the rest is automatic",
 ('PageNo', "  PL_FPDF.Cell(0, 10, 'Pagina ' || PL_FPDF.PageNo);"):
     "  PL_FPDF.Cell(0, 10, 'Page ' || PL_FPDF.PageNo);",
 ('Text', "  PL_FPDF.Text(20, 50, 'Endereço de cobrança');"):
     "  PL_FPDF.Text(20, 50, 'Billing address');",
 ('GetStringWidth', "  l_larg := PL_FPDF.GetStringWidth('São Paulo');"):
     "  l_larg := PL_FPDF.GetStringWidth('São Paulo');",  # nome próprio
 ('Cell', '  -- moldura inteira em volta da célula'):
     '  -- the whole frame around the cell',
 ('Cell', '  -- só a base, para sublinhar o título de uma coluna'):
     '  -- only the bottom, to underline a column heading',
 ('Cell', "  -- corpo de tabela: cada célula desenha só as laterais ('LR'), e uma"):
     "  -- table body: each cell draws only the sides ('LR'), and an empty",
 ('Cell', "  -- célula vazia com o topo ('T') fecha a tabela embaixo. Sem isso, usar"):
     "  -- cell with the top ('T') closes the table underneath. Without that,",
 ('Cell', "  -- '1' em todas daria traço duplo entre as linhas."):
     "  -- '1' on every cell would give a double rule between the rows.",
 ('Cell', "  PL_FPDF.Cell(60, 8, 'Licença anual', 'LR', 0, 'L');"):
     "  PL_FPDF.Cell(60, 8, 'Annual licence', 'LR', 0, 'L');",
 ('MultiCell', '  -- parágrafo justificado, com moldura inteira'):
     '  -- justified paragraph, with the whole frame',
 ('MultiCell', '  -- sem borda nenhuma, que é o caso comum em corpo de texto'):
     '  -- no border at all, which is the usual case in body text',
 ('MultiCell', '  -- só as laterais, para um bloco dentro de uma tabela'):
     '  -- only the sides, for a block inside a table',
 ('Error', "  PL_FPDF.Error('nao foi possivel montar o documento');"):
     "  PL_FPDF.Error('could not assemble the document');",
 ('LoadPDF', "    DBMS_OUTPUT.PUT_LINE('Páginas:' || PL_FPDF.GetPageCount());"):
     "    DBMS_OUTPUT.PUT_LINE('Pages:' || PL_FPDF.GetPageCount());",
 ('GetPageCount', "  DBMS_OUTPUT.PUT_LINE('Total de páginas:' || l_pages);"):
     "  DBMS_OUTPUT.PUT_LINE('Total pages:' || l_pages);",
 ('GetPDFInfo',
  "    DBMS_OUTPUT.PUT_LINE('Versão:' || l_info.get_string('version'));"):
     "    DBMS_OUTPUT.PUT_LINE('Version:' || l_info.get_string('version'));",
 ('GetPDFInfo',
  "    DBMS_OUTPUT.PUT_LINE('Páginas:' || l_info.get_number('pageCount'));"):
     "    DBMS_OUTPUT.PUT_LINE('Pages:' || l_info.get_number('pageCount'));",
 ('RotatePage', '  PL_FPDF.RotatePage(1, 90);    -- Rotacionar página 1'):
     '  PL_FPDF.RotatePage(1, 90);    -- rotate page 1',
 ('RotatePage', '  PL_FPDF.RotatePage(2, 180);   -- Rotacionar página 2'):
     '  PL_FPDF.RotatePage(2, 180);   -- rotate page 2',
 ('RemovePage', '  PL_FPDF.RemovePage(2);  -- Remover página 2'):
     '  PL_FPDF.RemovePage(2);  -- remove page 2',
 ('RemovePage', '  PL_FPDF.RemovePage(5);  -- Remover página 5'):
     '  PL_FPDF.RemovePage(5);  -- remove page 5',
 ('IsPageRemoved', "    DBMS_OUTPUT.PUT_LINE('Página 2 removida');"):
     "    DBMS_OUTPUT.PUT_LINE('Page 2 removed');",
 ('AddWatermark', '  -- Todas as páginas'):
     '  -- every page',
 ('AddWatermark', '  -- Páginas específicas'):
     '  -- specific pages',
 ('GetWatermarks', "      DBMS_OUTPUT.PUT_LINE('Marca d''água:' ||"):
     "      DBMS_OUTPUT.PUT_LINE('Watermark:' ||",
 ('OutputModifiedPDF', '    -- Aplicar modificações'):
     '    -- apply the changes',
 ('ClearPDFCache', '  -- Limpar memória'):
     '  -- release the memory',
 ('OverlayText', '    -- Sobreposição simples'):
     '    -- a plain overlay',
 ('OverlayText', '    -- Texto formatado'):
     '    -- formatted text',
 ('OverlayImage', '    -- Adicionar logo no canto superior direito'):
     '    -- add a logo in the top right corner',
 ('OverlayImage', "    -- Marca d'água com transparência"):
     '    -- a watermark with transparency',
 ('ClearOverlays', '  -- Limpar todas as sobreposições'):
     '  -- clear every overlay',
 ('ClearOverlays', '  -- Limpar apenas da página 1'):
     '  -- clear only those on page 1',
 ('SplitPDF', '      -- Processar cada parte'):
     '      -- process each part',
 ('ExtractPages', '    -- Extrair páginas 1, 5-10 e 15'):
     '    -- extract pages 1, 5-10 and 15',
 # literais em português dentro do exemplo: o código é o mesmo, o texto do
 # documento é que muda de língua
 ('UTF8ToPDFString', "  l_txt := PL_FPDF.UTF8ToPDFString('Total (liquido)');"):
     "  l_txt := PL_FPDF.UTF8ToPDFString('Total (net)');",
 ('Ln', "  PL_FPDF.Cell(40, 10, 'Primeira');"):
     "  PL_FPDF.Cell(40, 10, 'First');",
 ('SetHeaderProc', "  PL_FPDF.SetHeaderProc('MEU_PKG.CABECALHO');"):
     "  PL_FPDF.SetHeaderProc('MY_PKG.HEADER');",
 ('SetFooterProc', "  PL_FPDF.SetFooterProc('MEU_PKG.RODAPE');"):
     "  PL_FPDF.SetFooterProc('MY_PKG.FOOTER');",
 ('SetSubject', "  PL_FPDF.SetSubject('Fechamento mensal');"):
     "  PL_FPDF.SetSubject('Monthly close');",
 ('SetAuthor', "  PL_FPDF.SetAuthor('Departamento Financeiro');"):
     "  PL_FPDF.SetAuthor('Finance Department');",
 ('SetKeywords', "  PL_FPDF.SetKeywords('relatorio producao 2026');"):
     "  PL_FPDF.SetKeywords('production report 2026');",
 ('SetFillColor', "  PL_FPDF.Cell(40, 8, 'Cabecalho', '1', 0, 'C', 1);"):
     "  PL_FPDF.Cell(40, 8, 'Heading', '1', 0, 'C', 1);",
 ('Cell', "  PL_FPDF.Cell(100, 8, 'Produto', 'B', 1, 'L');"):
     "  PL_FPDF.Cell(100, 8, 'Product', 'B', 1, 'L');",
 ('Cell', "  PL_FPDF.Cell(60, 8, 'Suporte 8x5',   'LR', 0, 'L');"):
     "  PL_FPDF.Cell(60, 8, 'Support 8x5',   'LR', 0, 'L');",
 ('MultiCell',
  "  l_linhas := PL_FPDF.MultiCell(120, 5, l_observacao, 'LR', 'L');"):
     "  l_linhas := PL_FPDF.MultiCell(120, 5, l_observacao, 'LR', 'L');",
 ('CellRotated',
  "  PL_FPDF.CellRotated(10, 40, 'Janeiro', '1', 0, 'C', 0, '', 90);"):
     "  PL_FPDF.CellRotated(10, 40, 'January', '1', 0, 'C', 0, '', 90);",
 ('WriteRotated', "  PL_FPDF.WriteRotated(5, 'CONFIDENCIAL', NULL, 90);"):
     "  PL_FPDF.WriteRotated(5, 'CONFIDENTIAL', NULL, 90);",
 ('Output', "  PL_FPDF.Output('relatorio.pdf', 'F');"):
     "  PL_FPDF.Output('report.pdf', 'F');",
 ('OutputFile', "  PL_FPDF.OutputFile('relatorio.pdf', 'PDF_DIR');"):
     "  PL_FPDF.OutputFile('report.pdf', 'PDF_DIR');",
}

# O que denuncia português numa linha de exemplo. NÃO é um detector de idioma:
# aqui só existem duas línguas, e o que se procura é acento ou palavra de
# ligação que o inglês não tem. A URL sai antes de olhar, senão o `.com` de
# `example.com` casaria com a preposição "com".
_URL = re.compile(r'https?://\S+')
# `de`, `do`, `na`, `no` e `em` ficam DE FORA: colidem com palavra inglesa
# ("no border", "do not") e dariam falso alarme em linha já vertida. A rede é
# de segurança, não prova de idioma -- o que garante a tradução é a entrada em
# EXEMPLOS, e uma linha que tenha entrada não é examinada: quem a escreveu já
# decidiu, e é assim que 'São Paulo' continua São Paulo.
_PORTUGUES = re.compile(
    r'[ãõçáéíóúâêôÃÕÇÁÉÍÓÚÂÊÔ]|\b(não|nao|para|uma|dos|das|pagina|texto|'
    r'linha|até|ate|só|sem|cada|todo|toda|seu|sua|aqui|depois|antes|apos|'
    r'entre|onde|quando|mais|menos|deve|pode|faz|vai|fica|volta|inteira|'
    r'resto|acima|com|que)\b', re.I)


def exemplo_em_ingles(nome, linhas, faltas):
    """As linhas do exemplo, com comentário e literal vertidos.

    Uma linha que continue com marca de português depois da troca é falha, e
    não um detalhe: é o leitor de língua inglesa lendo `-- Limpar memória`.
    """
    saida = []
    for l in linhas:
        if (nome, l) in EXEMPLOS:
            saida.append(EXEMPLOS[(nome, l)])
            continue
        en = l
        if _PORTUGUES.search(_URL.sub('', en)):
            faltas.append(f'{nome}: linha de @example ainda em português — '
                          f'{l.strip()[:70]}')
        saida.append(en)
    return saida
