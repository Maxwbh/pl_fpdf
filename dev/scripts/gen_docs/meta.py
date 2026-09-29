# -*- coding: utf-8 -*-
"""
O que a referência da API tem e a spec não: categoria e "veja também".

DOCUMENTO DE MANUTENÇÃO.

A página de referência é **gerada** do Javadoc da spec — descrição, sintaxe,
parâmetros, retorno, erros e exemplo saem de lá, e é por isso que ela não pode
divergir. Duas coisas, porém, são editoriais e não cabem num bloco de
comentário:

* **em que grupo a API aparece**, que é uma decisão de quem organiza a leitura
  e não do subprograma;
* **o "veja também"**, que liga APIs que se usam juntas.

Estes dois vivem aqui. Foram extraídos da página escrita à mão quando ela
passou a ser gerada, então nada do que estava escrito se perdeu: 16 grupos,
119 APIs e 116 remissões.

Uma API que entrar na spec e não estiver em nenhum grupo aqui é recusada pelo
gerador — sem isso ela sairia no fim da página, num grupo "outros" que ninguém
lê, e a omissão passaria batida.
"""

# grupo -> APIs, na ordem em que aparecem na página
CATEGORIAS = [
    ('Ciclo de vida',
     ['fpdf', 'Init', 'IsInitialized', 'Reset']),
    ('Páginas e posicionamento',
     ['AcceptPageBreak', 'AddPage', 'GetCurrentPage', 'GetX', 'GetY', 'Ln', 'PageNo', 'SetAutoPageBreak', 'SetLeftMargin', 'SetMargins', 'SetPage', 'SetRightMargin', 'SetTopMargin', 'SetX', 'SetXY', 'SetY']),
    ('Fontes e UTF-8',
     ['AddFont', 'AddTTFFont', 'ClearTTFFontCache', 'GetTTFFontInfo', 'IsTTFFontLoaded', 'LoadTTFFromFile', 'SetFont', 'SetFontSize', 'UTF8ToPDFString']),
    ('Escrita de texto',
     ['Cell', 'CellRotated', 'GetCurrentFontFamily', 'GetCurrentFontSize', 'GetCurrentFontStyle', 'GetLineSpacing', 'GetStringWidth', 'MultiCell', 'SetLineSpacing', 'Text', 'Write', 'WriteRotated']),
    ('Cores e desenho',
     ['Line', 'Poly', 'Rect', 'SetDash', 'SetDrawColor', 'SetFillColor', 'SetLineDashPattern', 'SetLineWidth', 'SetTextColor', 'Triangle']),
    ('Imagens',
     ['getImageFromUrl', 'image', 'ImageFromBlob']),
    ('Links',
     ['AddLink', 'Link', 'SetLink']),
    ('Cabeçalho e rodapé',
     ['Footer', 'Header', 'SetAliasNbPages', 'SetFooterProc', 'SetHeaderProc']),
    ('QR Code e código de barras',
     ['AddBarcode', 'AddQRCode']),
    ('Metadados e configuração',
     ['GetDocumentMetadata', 'GetPageInfo', 'SetAuthor', 'SetCompression', 'SetCreator', 'SetDisplayMode', 'SetDocumentConfig', 'SetKeywords', 'SetSubject', 'SetTitle']),
    ('Saída do documento',
     ['ClosePDF', 'OpenPDF', 'Output', 'OutputBlob', 'OutputFile', 'ReturnBlob']),
    ('Manipulação de PDF existente',
     ['AddWatermark', 'ClearPDFCache', 'FlateDecode', 'FlateEncode', 'GetActivePageCount', 'GetPageCount', 'GetPDFInfo', 'GetWatermarks', 'IsPageRemoved', 'IsPDFModified', 'LoadPDF', 'OutputModifiedPDF', 'RemovePage', 'RotatePage']),
    ('Overlays',
     ['ClearOverlays', 'GetOverlays', 'OverlayImage', 'OverlayText', 'RemoveOverlay']),
    ('Multi-PDF (merge, split, extract)',
     ['ExtractPages', 'GetLoadedPDFs', 'LoadPDFWithID', 'MergePDFs', 'SplitPDF', 'UnloadPDF']),
    ('Segurança e criptografia',
     ['DecryptPDF', 'EncryptPDF', 'GetPDFVersion', 'GetSecurityInfo', 'IsEncrypted', 'SetEncryption', 'SetPDFVersion', 'SetPermissions']),
    ('Diagnóstico e utilidades',
     ['DebugDisabled', 'DebugEnabled', 'Error', 'GetLogLevel', 'GetScaleFactor', 'SetLogLevel']),
]

# grupo -> âncora do título dentro da página.
#
# Existe porque o `id` é endereço público: quem linkou `reference.html#grp-meta`
# de fora continua caindo no mesmo lugar. Gerar o slug do nome quebraria todos
# eles na primeira vez que um grupo fosse renomeado.
SLUG_GRUPO = {
    'Ciclo de vida': 'grp-lifecycle',
    'Páginas e posicionamento': 'grp-pages',
    'Fontes e UTF-8': 'grp-fonts',
    'Escrita de texto': 'grp-text',
    'Cores e desenho': 'grp-draw',
    'Imagens': 'grp-images',
    'Links': 'grp-links',
    'Cabeçalho e rodapé': 'grp-headfoot',
    'QR Code e código de barras': 'grp-codes',
    'Metadados e configuração': 'grp-meta',
    'Saída do documento': 'grp-output',
    'Manipulação de PDF existente': 'grp-manip',
    'Overlays': 'grp-overlay',
    'Multi-PDF (merge, split, extract)': 'grp-multi',
    'Segurança e criptografia': 'grp-security',
    'Diagnóstico e utilidades': 'grp-diag',
}

# APIs que existem na spec e NÃO entram na referência de uso.
#
# A regra do projeto é "duas documentações, dois públicos": o que vai para quem
# **usa** a biblioteca fala só de PDF. O `PL_FPDF_UTIL` é a metade que não é
# PDF -- QR Code, código de barras, DEFLATE e criptografia --, e quem gera um
# documento nunca o chama: nos `examples/` e em `dev/tests/` ele aparece ZERO
# vezes. As 69 chamadas estão dentro do `src/`, do `PL_FPDF` para ele. No
# README ele só aparece na ordem de instalação, que é outra coisa.
#
# A lista existe para a omissão ser DECLARADA. O gerador recusa API que não
# esteja nem num grupo nem aqui: assim uma API nova não some da página em
# silêncio, alguém tem de decidir.
FORA_DA_REFERENCIA = [
    # PL_FPDF_UTIL: chamado pelo PL_FPDF, não por quem gera PDF
    'qr_matriz',
    'bc_padrao',
    'inflate',
    'deflate',
    'hex_do_byte',
    'crypto_md5',
    'crypto_rc4',
    'crypto_rc4_blob',
    'crypto_autoteste',
    'aes_cbc_cifrar',
    'aes_cbc_cifrar_raw',
    'aes_cbc_decifrar',
    'aes_cbc_decifrar_raw',
    'aes_chave_objeto',
    'aes_iv',
    'aes_valores_r6',
    'aes_verificar_r6',
    'aes_autoteste',
]

# API -> APIs que se usam junto
VEJA_TAMBEM = {
    'AcceptPageBreak': ['SetAutoPageBreak'],
    'AddBarcode': ['AddQRCode'],
    'AddFont': ['AddTTFFont', 'SetFont'],
    'AddLink': ['SetLink', 'Link'],
    'AddPage': ['Init', 'SetPage', 'GetCurrentPage'],
    'AddQRCode': ['AddBarcode'],
    'AddTTFFont': ['LoadTTFFromFile', 'IsTTFFontLoaded', 'SetFont'],
    'AddWatermark': ['GetWatermarks', 'OverlayText', 'OutputModifiedPDF'],
    'Cell': ['MultiCell', 'Write', 'CellRotated', 'SetFillColor'],
    'CellRotated': ['Cell', 'WriteRotated'],
    'ClearOverlays': ['RemoveOverlay', 'GetOverlays'],
    'ClearPDFCache': ['LoadPDF', 'UnloadPDF'],
    'ClearTTFFontCache': ['AddTTFFont'],
    'ClosePDF': ['OutputBlob'],
    'DebugDisabled': ['SetLogLevel'],
    'DebugEnabled': ['SetLogLevel'],
    'DecryptPDF': ['EncryptPDF', 'IsEncrypted'],
    'EncryptPDF': ['DecryptPDF', 'IsEncrypted', 'SetEncryption', 'SetPermissions'],
    'ExtractPages': ['SplitPDF', 'MergePDFs'],
    'FlateDecode': ['LoadPDF'],
    'FlateEncode': ['FlateDecode', 'SetCompression'],
    'Footer': ['SetFooterProc'],
    'GetActivePageCount': ['RemovePage', 'GetPageCount'],
    'GetCurrentFontFamily': ['SetFont'],
    'GetCurrentFontSize': ['SetFont'],
    'GetCurrentFontStyle': ['SetFont'],
    'GetCurrentPage': ['SetPage', 'PageNo'],
    'GetDocumentMetadata': ['SetDocumentConfig'],
    'GetLineSpacing': ['SetLineSpacing'],
    'GetLoadedPDFs': ['LoadPDFWithID', 'UnloadPDF'],
    'GetLogLevel': ['SetLogLevel'],
    'GetOverlays': ['OverlayText', 'RemoveOverlay'],
    'GetPDFInfo': ['LoadPDF', 'GetPageInfo'],
    'GetPDFVersion': ['SetPDFVersion'],
    'GetPageCount': ['LoadPDF', 'GetActivePageCount'],
    'GetPageInfo': ['GetCurrentPage', 'GetPDFInfo'],
    'GetScaleFactor': ['Init'],
    'GetSecurityInfo': ['IsEncrypted', 'EncryptPDF'],
    'GetStringWidth': ['SetFont', 'Cell'],
    'GetTTFFontInfo': ['AddTTFFont'],
    'GetWatermarks': ['AddWatermark'],
    'GetX': ['SetX', 'SetXY'],
    'GetY': ['SetY'],
    'Header': ['SetHeaderProc'],
    'ImageFromBlob': ['image', 'OverlayImage'],
    'Init': ['Reset', 'IsInitialized', 'AddPage'],
    'IsEncrypted': ['GetSecurityInfo', 'DecryptPDF'],
    'IsInitialized': ['Init'],
    'IsPDFModified': ['OutputModifiedPDF'],
    'IsPageRemoved': ['RemovePage'],
    'IsTTFFontLoaded': ['AddTTFFont', 'ClearTTFFontCache'],
    'Line': ['SetDrawColor', 'SetLineWidth'],
    'Link': ['AddLink', 'SetLink'],
    'Ln': ['SetXY'],
    'LoadPDF': ['LoadPDFWithID', 'GetPageCount', 'OutputModifiedPDF', 'ClearPDFCache'],
    'LoadPDFWithID': ['MergePDFs', 'SplitPDF', 'ExtractPages', 'UnloadPDF', 'GetLoadedPDFs'],
    'LoadTTFFromFile': ['AddTTFFont'],
    'MergePDFs': ['LoadPDFWithID', 'SplitPDF', 'ExtractPages'],
    'MultiCell': ['Cell', 'Write'],
    'OpenPDF': ['Init'],
    'Output': ['OutputBlob', 'OutputFile'],
    'OutputBlob': ['OutputBlob'],
    'OutputFile': ['OutputBlob'],
    'OutputModifiedPDF': ['LoadPDF', 'ClearPDFCache'],
    'OverlayImage': ['OverlayText', 'Image', 'GetOverlays'],
    'OverlayText': ['OverlayImage', 'GetOverlays', 'AddWatermark'],
    'PageNo': ['SetAliasNbPages', 'SetFooterProc'],
    'Poly': ['Line', 'Triangle'],
    'Rect': ['SetDrawColor', 'SetFillColor'],
    'RemoveOverlay': ['GetOverlays', 'ClearOverlays'],
    'RemovePage': ['IsPageRemoved', 'GetActivePageCount', 'OutputModifiedPDF'],
    'Reset': ['Init', 'ClearPDFCache'],
    'ReturnBlob': ['OutputBlob'],
    'RotatePage': ['LoadPDF', 'RemovePage', 'OutputModifiedPDF'],
    'SetAliasNbPages': ['PageNo'],
    'SetAuthor': ['SetDocumentConfig'],
    'SetAutoPageBreak': ['AcceptPageBreak', 'SetMargins'],
    'SetCompression': ['FlateEncode', 'FlateDecode'],
    'SetCreator': ['SetDocumentConfig'],
    'SetDash': ['SetLineDashPattern'],
    'SetDocumentConfig': ['GetDocumentMetadata', 'SetTitle'],
    'SetDrawColor': ['SetFillColor', 'SetTextColor', 'SetLineWidth'],
    'SetEncryption': ['SetPermissions', 'EncryptPDF'],
    'SetFillColor': ['Cell', 'Rect'],
    'SetFont': ['SetFontSize', 'AddTTFFont', 'GetStringWidth'],
    'SetFontSize': ['SetFont'],
    'SetFooterProc': ['SetHeaderProc', 'SetAliasNbPages', 'Footer'],
    'SetHeaderProc': ['SetFooterProc', 'Header'],
    'SetKeywords': ['SetDocumentConfig'],
    'SetLeftMargin': ['SetMargins'],
    'SetLineDashPattern': ['SetDash'],
    'SetLineSpacing': ['GetLineSpacing'],
    'SetLineWidth': ['Line', 'Rect'],
    'SetLink': ['AddLink'],
    'SetLogLevel': ['GetLogLevel', 'DebugEnabled'],
    'SetMargins': ['SetLeftMargin', 'SetTopMargin', 'SetRightMargin', 'SetAutoPageBreak'],
    'SetPDFVersion': ['GetPDFVersion'],
    'SetPage': ['AddPage', 'GetCurrentPage'],
    'SetPermissions': ['SetEncryption', 'EncryptPDF'],
    'SetRightMargin': ['SetMargins'],
    'SetSubject': ['SetDocumentConfig'],
    'SetTextColor': ['SetFont', 'Cell'],
    'SetTitle': ['SetDocumentConfig'],
    'SetTopMargin': ['SetMargins'],
    'SetX': ['GetX'],
    'SetXY': ['SetX', 'SetY'],
    'SetY': ['GetY', 'SetXY'],
    'SplitPDF': ['ExtractPages', 'MergePDFs'],
    'Text': ['Cell', 'Write'],
    'Triangle': ['Poly', 'Rect'],
    'UnloadPDF': ['LoadPDFWithID', 'ClearPDFCache'],
    'Write': ['Cell', 'MultiCell', 'WriteRotated'],
    'WriteRotated': ['Write', 'CellRotated'],
    'fpdf': ['Init'],
    'getImageFromUrl': ['Image'],
    'image': ['getImageFromUrl', 'OverlayImage'],
}
