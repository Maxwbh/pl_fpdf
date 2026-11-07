# Rastreabilidade: API × testes · Traceability: API × tests

> **Gerado** por `dev/scripts/gen_docs/rastreabilidade.py` — não edite à mão.
> **Generated** by `dev/scripts/gen_docs/rastreabilidade.py` — do not edit.

Para cada API pública, o que a exercita: os arquivos de `dev/tests/` que a
chamam, e as amostras do `run_tests.py` — PDFs gerados no banco e lidos de
volta por leitores independentes. Contar uma chamada não prova que todo
comportamento foi testado; prova que a API não está **sem** nenhum teste.

For each public API, what exercises it: the `dev/tests/` files that call it,
and the `run_tests.py` samples — PDFs generated in the database and read back
by independent readers. Counting a call does not prove every behaviour is
tested; it proves the API is not **without** any test.


## Resumo · Summary

| Package | APIs | Teste direto · Direct test | Só via PL_FPDF · Only through PL_FPDF | Sem teste · Untested |
|---------|-----:|---------------------------:|--------------------------------------:|---------------------:|
| `PL_FPDF` | 119 | 118 | 0 | 1 |
| `PL_FPDF_UTIL` | 18 | 0 | 18 | 0 |


## PL_FPDF

| API | Testes · Tests | Amostras · Samples |
|-----|----------------|--------------------|
| `Init` | `diag_password`, `diag_winansi`, `test_ciclo_saida`, `test_compat_legado`, `test_core`, `test_cursor_margens`, `test_desenho`, `test_fonte_texto`, `test_fontes_truetype`, `test_geracao_basica`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_metadados_config`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_seguranca`, `test_sobreposicao`, `test_stream_imagem`, `test_sublinhado`, `test_winansi` | `acentos`, `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `barcode_code128`, `barcode_ean13`, `boleto`, `cifrado`, `complexo`, `comprimido`, `decifrado`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `qrcode_pix`, `simples`, `ticket` |
| `Reset` | `diag_password`, `diag_winansi`, `diag_xrefstm`, `test_ciclo_saida`, `test_compat_legado`, `test_core`, `test_cursor_margens`, `test_desenho`, `test_fonte_texto`, `test_fontes_truetype`, `test_geracao_basica`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_metadados_config`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_seguranca`, `test_sobreposicao`, `test_stream_imagem`, `test_sublinhado`, `test_winansi` | `acentos`, `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `barcode_code128`, `barcode_ean13`, `boleto`, `cifrado`, `complexo`, `comprimido`, `decifrado`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `objstm`, `objstm_cifrado`, `objstm_ida_volta`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `qrcode_pix`, `simples`, `ticket`, `xref_predictor` |
| `IsInitialized` | `test_compat_legado`, `test_geracao_basica` | — |
| `AddTTFFont` | `test_fontes_truetype` | — |
| `LoadTTFFromFile` | `test_fontes_truetype` | — |
| `IsTTFFontLoaded` | `test_fontes_truetype` | — |
| `GetTTFFontInfo` | `test_fontes_truetype` | — |
| `ClearTTFFontCache` | `test_fontes_truetype` | — |
| `UTF8ToPDFString` | `test_fonte_texto` | — |
| `GetCurrentFontSize` | `test_fonte_texto` | — |
| `GetCurrentFontStyle` | `test_fonte_texto` | — |
| `GetCurrentFontFamily` | `test_fonte_texto`, `test_fontes_truetype` | — |
| `SetDash` | `test_desenho` | — |
| `GetLineSpacing` | `test_fonte_texto` | — |
| `SetLineSpacing` | `test_fonte_texto` | — |
| `Poly` | — | `ticket` |
| `Triangle` | `test_desenho` | `formas` |
| `SetLineDashPattern` | `test_desenho` | — |
| `Ln` | `test_cursor_margens`, `test_seguranca` | `complexo` |
| `GetX` | `test_cursor_margens`, `test_fonte_texto` | — |
| `SetX` | `test_cursor_margens` | — |
| `GetY` | `test_cursor_margens`, `test_fonte_texto` | — |
| `SetY` | `test_cursor_margens` | — |
| `SetXY` | `test_core`, `test_cursor_margens`, `test_fonte_texto` | `boleto`, `complexo`, `comprimido`, `formas`, `ticket` |
| `SetHeaderProc` | `test_compat_legado`, `test_core` | — |
| `SetFooterProc` | `test_compat_legado`, `test_core`, `test_regressoes_revisao` | — |
| `SetMargins` | `test_cursor_margens` | `complexo` |
| `SetLeftMargin` | `test_cursor_margens` | — |
| `SetTopMargin` | `test_cursor_margens` | — |
| `SetRightMargin` | `test_cursor_margens` | — |
| `SetAutoPageBreak` | `test_cursor_margens` | `complexo` |
| `SetDisplayMode` | `test_metadados_config` | — |
| `SetCompression` | `test_metadados_config` | `comprimido` |
| `SetTitle` | `test_metadados_config` | `boleto`, `complexo`, `ticket` |
| `SetSubject` | `test_metadados_config` | `complexo` |
| `SetAuthor` | `test_regressoes_revisao` | `boleto`, `complexo`, `ticket` |
| `SetKeywords` | `test_regressoes_revisao` | `complexo` |
| `SetCreator` | `test_metadados_config` | `complexo` |
| `SetAliasNbPages` | `test_core` | — |
| `Header` | `test_ciclo_saida` | — |
| `Footer` | `test_ciclo_saida` | — |
| `PageNo` | `test_cursor_margens` | — |
| `SetDrawColor` | `test_geracao_basica` | `boleto`, `complexo`, `ticket` |
| `SetFillColor` | `test_geracao_basica` | `complexo`, `formas`, `ticket` |
| `SetTextColor` | `test_geracao_basica` | `complexo`, `ticket` |
| `SetLineWidth` | — | `boleto`, `complexo`, `ticket` |
| `Line` | `test_core`, `test_desenho`, `test_geracao_basica` | `boleto`, `complexo` |
| `Rect` | `test_geracao_basica` | `boleto`, `complexo`, `ticket` |
| `AddLink` | `test_regressoes_revisao` | — |
| `SetLink` | `test_regressoes_revisao` | — |
| `Link` | `test_regressoes_revisao` | — |
| `Text` | `test_fonte_texto` | — |
| `AcceptPageBreak` | `test_cursor_margens` | — |
| `AddFont` | `test_fonte_texto` | — |
| `SetFont` | `diag_password`, `diag_winansi`, `test_ciclo_saida`, `test_compat_legado`, `test_core`, `test_cursor_margens`, `test_desenho`, `test_fonte_texto`, `test_fontes_truetype`, `test_geracao_basica`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_metadados_config`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_seguranca`, `test_sobreposicao`, `test_stream_imagem`, `test_sublinhado`, `test_winansi` | `acentos`, `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `boleto`, `cifrado`, `complexo`, `comprimido`, `decifrado`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `simples`, `ticket` |
| `GetStringWidth` | `diag_winansi`, `test_fontes_truetype`, `test_sublinhado`, `test_winansi` | — |
| `SetFontSize` | `test_fonte_texto` | — |
| `Cell` | `diag_password`, `diag_winansi`, `test_ciclo_saida`, `test_compat_legado`, `test_core`, `test_cursor_margens`, `test_fontes_truetype`, `test_geracao_basica`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_metadados_config`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_seguranca`, `test_sobreposicao`, `test_stream_imagem`, `test_sublinhado`, `test_winansi` | `acentos`, `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `boleto`, `cifrado`, `complexo`, `comprimido`, `decifrado`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `simples`, `ticket` |
| `MultiCell` | `test_geracao_basica`, `test_sublinhado`, `test_winansi` | `complexo` |
| `Write` | `test_geracao_basica`, `test_winansi` | — |
| `CellRotated` | `test_fonte_texto` | — |
| `WriteRotated` | `test_fonte_texto` | — |
| `image` | `test_ciclo_saida` | — |
| `ImageFromBlob` | `test_stream_imagem` | `imagem_blob` |
| `Output` | `test_ciclo_saida` | — |
| `ReturnBlob` | `test_compat_legado` | — |
| `OutputBlob` | `diag_password`, `diag_winansi`, `test_ciclo_saida`, `test_compat_legado`, `test_core`, `test_desenho`, `test_fonte_texto`, `test_fontes_truetype`, `test_geracao_basica`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_metadados_config`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_seguranca`, `test_sobreposicao`, `test_stream_imagem`, `test_sublinhado`, `test_winansi` | `acentos`, `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `barcode_code128`, `barcode_ean13`, `boleto`, `cifrado`, `complexo`, `comprimido`, `decifrado`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `qrcode_pix`, `simples`, `ticket` |
| `OutputFile` | `test_ciclo_saida` | — |
| `OpenPDF` | `test_compat_legado` | — |
| `ClosePDF` | `test_ciclo_saida` | — |
| `AddPage` | `diag_password`, `diag_winansi`, `test_ciclo_saida`, `test_compat_legado`, `test_core`, `test_cursor_margens`, `test_desenho`, `test_fonte_texto`, `test_fontes_truetype`, `test_geracao_basica`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_metadados_config`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_seguranca`, `test_sobreposicao`, `test_stream_imagem`, `test_sublinhado`, `test_winansi` | `acentos`, `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `barcode_code128`, `barcode_ean13`, `boleto`, `cifrado`, `complexo`, `comprimido`, `decifrado`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `qrcode_pix`, `simples`, `ticket` |
| `SetPage` | `test_core`, `test_geracao_basica` | — |
| `GetCurrentPage` | `test_geracao_basica` | — |
| `fpdf` | `test_compat_legado` | — |
| `Error` | `test_ciclo_saida` | — |
| `DebugEnabled` | `diag_password` | — |
| `DebugDisabled` | `diag_password` | — |
| `GetScaleFactor` | `test_cursor_margens`, `test_sublinhado` | — |
| `getImageFromUrl` | — | — |
| `SetLogLevel` | `diag_password`, `test_leitura_paginas`, `test_metadados_config` | — |
| `GetLogLevel` | `test_metadados_config` | — |
| `SetDocumentConfig` | `test_metadados_config` | — |
| `GetDocumentMetadata` | `test_metadados_config` | — |
| `GetPageInfo` | `test_leitura_paginas`, `test_manipulacao_completa` | — |
| `AddQRCode` | `test_core` | `complexo`, `qrcode_pix`, `ticket` |
| `AddBarcode` | `test_core` | `barcode_code128`, `barcode_ean13`, `boleto`, `complexo`, `ticket` |
| `LoadPDF` | `diag_xrefstm`, `test_core`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_marca_dagua`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_sobreposicao` | `marca_dagua`, `objstm`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande` |
| `GetPageCount` | `diag_xrefstm`, `test_core`, `test_leitura_paginas`, `test_leitura_pdf`, `test_manipulacao_completa`, `test_paginas_girar_remover` | — |
| `GetPDFInfo` | `test_leitura_pdf` | — |
| `RotatePage` | `test_core`, `test_leitura_paginas`, `test_manipulacao_completa`, `test_paginas_girar_remover`, `test_saida_modificada` | — |
| `RemovePage` | `test_core`, `test_manipulacao_completa`, `test_paginas_girar_remover`, `test_saida_modificada` | — |
| `GetActivePageCount` | `test_paginas_girar_remover` | — |
| `IsPageRemoved` | `test_manipulacao_completa`, `test_paginas_girar_remover` | — |
| `IsPDFModified` | `test_marca_dagua`, `test_paginas_girar_remover` | — |
| `AddWatermark` | `test_manipulacao_completa`, `test_marca_dagua`, `test_regressoes_revisao`, `test_saida_modificada` | `marca_dagua` |
| `GetWatermarks` | `test_manipulacao_completa`, `test_marca_dagua` | — |
| `OutputModifiedPDF` | `diag_xrefstm`, `test_core`, `test_manipulacao_completa`, `test_regressoes_revisao`, `test_saida_modificada` | `marca_dagua`, `objstm`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande` |
| `ClearPDFCache` | `diag_password`, `diag_xrefstm`, `test_core`, `test_leitura_paginas`, `test_manipulacao_completa`, `test_marca_dagua`, `test_mesclar_dividir`, `test_paginas_girar_remover`, `test_regressoes_revisao`, `test_saida_modificada`, `test_sobreposicao` | `acentos`, `boleto`, `comprimido`, `extract`, `formas`, `imagem_blob`, `marca_dagua`, `merge`, `objstm`, `objstm_cifrado`, `objstm_ida_volta`, `overlay_img`, `overlay_opcoes`, `png_alfa`, `png_entrelacado`, `png_grande`, `ticket`, `xref_predictor` |
| `FlateDecode` | `diag_inflate` | — |
| `FlateEncode` | `diag_deflate` | — |
| `OverlayText` | `diag_xrefstm`, `test_manipulacao_completa`, `test_sobreposicao` | `marca_dagua`, `objstm`, `overlay_opcoes` |
| `OverlayImage` | `test_manipulacao_completa`, `test_saida_modificada`, `test_sobreposicao` | `overlay_img`, `png_alfa`, `png_entrelacado`, `png_grande` |
| `GetOverlays` | `test_manipulacao_completa`, `test_sobreposicao` | — |
| `RemoveOverlay` | `test_manipulacao_completa`, `test_sobreposicao` | — |
| `ClearOverlays` | `test_manipulacao_completa`, `test_sobreposicao` | — |
| `LoadPDFWithID` | `diag_xrefstm`, `test_core`, `test_manipulacao_completa`, `test_mesclar_dividir` | `extract`, `merge`, `xref_predictor` |
| `GetLoadedPDFs` | `test_manipulacao_completa`, `test_mesclar_dividir` | — |
| `UnloadPDF` | `test_core`, `test_manipulacao_completa`, `test_mesclar_dividir` | — |
| `MergePDFs` | `test_core`, `test_manipulacao_completa`, `test_mesclar_dividir` | `merge` |
| `SplitPDF` | `test_core`, `test_manipulacao_completa`, `test_mesclar_dividir` | — |
| `ExtractPages` | `diag_xrefstm`, `test_core`, `test_manipulacao_completa`, `test_mesclar_dividir` | `extract`, `xref_predictor` |
| `EncryptPDF` | `diag_password`, `test_regressoes_revisao`, `test_seguranca` | `aes128`, `aes128_ida_volta`, `aes256`, `aes256_ida_volta`, `cifrado`, `decifrado`, `objstm_cifrado`, `objstm_ida_volta` |
| `DecryptPDF` | `diag_password`, `test_seguranca` | `aes128_ida_volta`, `aes256_ida_volta`, `decifrado`, `objstm_ida_volta` |
| `IsEncrypted` | `test_seguranca` | — |
| `GetSecurityInfo` | `diag_password`, `test_seguranca` | — |
| `SetEncryption` | `test_seguranca` | — |
| `SetPDFVersion` | `test_metadados_config` | — |
| `GetPDFVersion` | `test_metadados_config` | — |
| `SetPermissions` | `test_seguranca` | — |

## PL_FPDF_UTIL

| API | Testes · Tests | Amostras · Samples |
|-----|----------------|--------------------|
| `qr_matriz` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `bc_padrao` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `inflate` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `deflate` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `hex_do_byte` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `crypto_md5` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `crypto_rc4` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `crypto_rc4_blob` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `crypto_autoteste` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_cbc_cifrar` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_cbc_cifrar_raw` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_cbc_decifrar` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_cbc_decifrar_raw` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_chave_objeto` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_iv` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_valores_r6` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_verificar_r6` | só via `PL_FPDF` · only through `PL_FPDF` | — |
| `aes_autoteste` | só via `PL_FPDF` · only through `PL_FPDF` | — |

## Sem teste · Untested

- `PL_FPDF.getImageFromUrl`
