--==============================================================================
-- sample_output.sql
--
-- Exemplo enxuto, comentado, do PL/SQL que o docx_to_plfpdf.py emite a partir
-- de um .docx. Serve como referência didática: cada bloco é precedido pelo
-- elemento DOCX que o originou.
--
-- Esperado: ao executar contra Oracle 19c+ com o pacote PL_FPDF instalado,
-- produz um BLOB com o PDF correspondente em l_pdf.
--==============================================================================

DECLARE
  l_pdf BLOB;
  l_img BLOB;

  -- Helper interno: converte CLOB base64 -> BLOB binário.
  -- O gerador real inclui esta procedure só quando o docx tem imagens.
  PROCEDURE load_b64(p_b64 IN CLOB, p_blob OUT BLOB) IS
    l_dest INTEGER := 1; l_src INTEGER := 1;
    l_ctx  INTEGER := DBMS_LOB.default_lang_ctx; l_warn INTEGER;
    l_tmp  BLOB;
  BEGIN
    DBMS_LOB.createtemporary(p_blob, TRUE);
    DBMS_LOB.converttoblob(p_blob, p_b64, DBMS_LOB.lobmaxsize,
                           l_dest, l_src, NLS_CHARSET_ID('AL32UTF8'), l_ctx, l_warn);
    DBMS_LOB.createtemporary(l_tmp, TRUE);
    -- decodifica em blocos de 24k caracteres
    FOR i IN 0 .. CEIL(DBMS_LOB.getlength(p_blob) / 24000) - 1 LOOP
      DBMS_LOB.append(
        l_tmp,
        UTL_ENCODE.base64_decode(
          UTL_RAW.cast_to_raw(
            UTL_RAW.cast_to_varchar2(
              DBMS_LOB.substr(p_blob, 24000, i * 24000 + 1)))));
    END LOOP;
    DBMS_LOB.freetemporary(p_blob);
    p_blob := l_tmp;
  END load_b64;

BEGIN
  -------------------------------------------------------------------- preamble
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetMargins(15, 15, 15);
  PL_FPDF.AddPage();
  PL_FPDF.SetFont('Arial', '', 11);

  ----------------------------------------------------------- Heading nível 1
  -- DOCX: "Heading 1" -> Relatório Mensal
  PL_FPDF.Ln(4);
  PL_FPDF.SetFont('Arial', 'B', 20);
  PL_FPDF.Cell(0, 12, q'[Relatório Mensal]', '0', 1, 'L');
  PL_FPDF.Ln(2);

  ----------------------------------------------------------- Heading nível 2
  PL_FPDF.Ln(4);
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, q'[1. Visão geral]', '0', 1, 'L');
  PL_FPDF.Ln(2);

  ---------------------------------------- Parágrafo com runs (normal/bold/italic)
  -- DOCX: "Este é um " + <b>"resumo"</b> + " com trecho em " + <i>"itálico"</i>
  PL_FPDF.SetFont('Arial', '', 11);
  PL_FPDF.Write(6, q'[Este é um ]');
  PL_FPDF.SetFont('Arial', 'B', 11);
  PL_FPDF.Write(6, q'[resumo]');
  PL_FPDF.SetFont('Arial', '', 11);
  PL_FPDF.Write(6, q'[ com trecho em ]');
  PL_FPDF.SetFont('Arial', 'I', 11);
  PL_FPDF.Write(6, q'[itálico]');
  PL_FPDF.SetFont('Arial', '', 11);
  PL_FPDF.Write(6, q'[.]');
  PL_FPDF.Ln(8);

  -------------------------------------------------------- Lista com marcadores
  -- DOCX: List Bullet
  PL_FPDF.SetFont('Arial', '', 11);
  PL_FPDF.Write(6, q'[- Faturamento dentro do previsto.]');
  PL_FPDF.Ln(8);
  PL_FPDF.Write(6, q'[- Redução de 12% no backlog de tickets.]');
  PL_FPDF.Ln(8);
  PL_FPDF.Write(6, q'[- Entrega da integração EBS ↔ APEX.]');
  PL_FPDF.Ln(8);

  --------------------------------------------------------------------- Tabela
  -- DOCX: tabela 3x3, primeira linha cabeçalho
  PL_FPDF.Ln(2);
  PL_FPDF.SetFont('Arial', 'B', 10);
  PL_FPDF.Cell(60.00, 7, q'[Indicador]', '1', 0, 'L');
  PL_FPDF.Cell(60.00, 7, q'[Meta]',      '1', 0, 'L');
  PL_FPDF.Cell(60.00, 7, q'[Realizado]', '1', 0, 'L');
  PL_FPDF.Ln(7);
  PL_FPDF.SetFont('Arial', '', 10);
  PL_FPDF.Cell(60.00, 7, q'[SLA crítico]', '1', 0, 'L');
  PL_FPDF.Cell(60.00, 7, q'[99,5%]',       '1', 0, 'L');
  PL_FPDF.Cell(60.00, 7, q'[99,8%]',       '1', 0, 'L');
  PL_FPDF.Ln(7);
  PL_FPDF.Cell(60.00, 7, q'[Custo R$]',    '1', 0, 'L');
  PL_FPDF.Cell(60.00, 7, q'[120k]',        '1', 0, 'L');
  PL_FPDF.Cell(60.00, 7, q'[114k]',        '1', 0, 'L');
  PL_FPDF.Ln(7);
  PL_FPDF.Ln(2);

  ---------------------------------------------------------- Quebra de página
  PL_FPDF.AddPage();

  ----------------------------------------------------------- Imagem embutida
  -- O gerador embute a imagem como base64 dentro do próprio script.
  -- Aqui o CLOB foi reduzido a uma única linha placeholder a título de exemplo.
  DECLARE l_b64 CLOB; BEGIN
    DBMS_LOB.createtemporary(l_b64, TRUE);
    DBMS_LOB.append(l_b64, TO_CLOB('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgAAIAAAUAAen63NgAAAAASUVORK5CYII='));
    load_b64(l_b64, l_img);
    PL_FPDF.Image(p_image_blob => l_img, p_x => NULL, p_y => NULL,
                  p_w => 80, p_h => 0, p_type => 'PNG');
    DBMS_LOB.freetemporary(l_img);
    DBMS_LOB.freetemporary(l_b64);
  END;
  PL_FPDF.Ln(4);

  ------------------------------------------------------------------- output
  l_pdf := PL_FPDF.Output_Blob();
  DBMS_OUTPUT.put_line('PDF gerado, bytes=' || DBMS_LOB.getlength(l_pdf));
  -- Persistir conforme o caso de uso:
  --   INSERT INTO relatorios(id, pdf_blob) VALUES (seq.NEXTVAL, l_pdf);
END;
/
