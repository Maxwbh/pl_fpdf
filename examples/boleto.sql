--------------------------------------------------------------------------------
-- PL_FPDF — exemplo: o LAYOUT de um boleto (ficha de compensacao)
--
-- Um documento dificil de verdade, desenhado inteiramente em PL/SQL: A4, tres
-- variantes de Helvetica em quatro corpos, 50 caixas numa grade fechada, duas
-- vias com linha de corte e o codigo de barras ITF de 44 digitos que um leitor
-- de banco consegue ler.
--
-- Nao ha imagem nenhuma: o logotipo, as reguas e as barras sao desenho
-- vetorial, que e como um boleto de verdade e feito.
--
-- Medidas da ficha de compensacao (FEBRABAN): 177 mm de largura centralizada
-- em A4, coluna de valores com 40 mm a direita, codigo de barras 103 x 13 mm.
--
-- Como rodar: abra na SQL Window do PL/SQL Developer e execute com F8. O PDF
-- fica no BLOB `l_pdf` — grave numa tabela, devolva por uma funcao ou escreva
-- com UTL_FILE, conforme o seu caso.
--
-- O PL_FPDF DESENHA; ele nao calcula cobranca. Os 44 digitos do codigo de
-- barras e a linha digitavel entram prontos, como qualquer outro dado que o
-- chamador passa — monta-los a partir de banco, vencimento, valor e campo
-- livre (verificador, fator de vencimento, regra de cada banco) e assunto de
-- um projeto de cobranca, nao de uma biblioteca de PDF.
--
-- Os dados aqui sao ficticios. Troque-os pelos seus e o desenho nao muda: e a
-- mesma grade que serve para nota fiscal, guia de recolhimento ou qualquer
-- formulario de campos fechados.
--------------------------------------------------------------------------------

DECLARE
  l_pdf   BLOB;
  co_x0   CONSTANT NUMBER := 16.5;                    -- ficha em A4
  co_larg CONSTANT NUMBER := 177;                     -- FEBRABAN
  co_dir  CONSTANT NUMBER := 40;                      -- coluna direita
  co_xd   CONSTANT NUMBER := co_x0 + co_larg - co_dir;
  co_esq  CONSTANT NUMBER := co_larg - co_dir;
  co_ld   CONSTANT VARCHAR2(60) :=
    '34191.09008 00012.323077 31234.510001 7 16770000015000';
  co_cb   CONSTANT VARCHAR2(44) :=
            '34197167700000150001090000012323073123451000';

  -- Uma caixa com rotulo miudo em cima e valor embaixo. A Cell ja tem
  -- margem interna de 1 mm dos dois lados, entao a largura passada e a
  -- da caixa INTEIRA: o recuo vem de graca, igual nos dois lados, e o
  -- alinhado a direita encosta a 1 mm da borda.
  PROCEDURE campo(px NUMBER, py NUMBER, pw NUMBER, ph NUMBER,
                  protulo VARCHAR2, pvalor VARCHAR2 DEFAULT NULL,
                  pneg BOOLEAN DEFAULT FALSE,
                  palin VARCHAR2 DEFAULT 'L') IS
  BEGIN
    PL_FPDF.Rect(px, py, pw, ph, 'D');
    PL_FPDF.SetFont('Arial', '', 6);
    PL_FPDF.SetXY(px, py + 0.7);
    PL_FPDF.Cell(pw, 2.4, protulo, '0', 0, 'L');
    IF pvalor IS NOT NULL THEN
      PL_FPDF.SetFont('Arial', CASE WHEN pneg THEN 'B' END, 9);
      PL_FPDF.SetXY(px, py + 3.2);
      PL_FPDF.Cell(pw, 3.4, pvalor, '0', 0, palin);
    END IF;
  END campo;

  -- texto de 7 pt: instrucoes, endereco do pagador e rodape
  PROCEDURE miudo(px NUMBER, py NUMBER, pw NUMBER, ptxt VARCHAR2,
                  pest VARCHAR2 DEFAULT NULL,
                  palin VARCHAR2 DEFAULT 'L') IS
  BEGIN
    PL_FPDF.SetFont('Arial', pest, 7);
    PL_FPDF.SetXY(px, py);
    PL_FPDF.Cell(pw, 3, ptxt, '0', 0, palin);
  END miudo;

  -- uma via: recibo do pagador ou ficha de compensacao
  PROCEDURE via(py NUMBER, protulo VARCHAR2, pcompleta BOOLEAN) IS
    y NUMBER := py + 8;
  BEGIN
    -- cabecalho: logotipo, codigo do banco e linha digitavel
    PL_FPDF.SetLineWidth(0.5);
    PL_FPDF.SetFont('Arial', 'B', 15);
    PL_FPDF.SetXY(co_x0, py);
    PL_FPDF.Cell(26, 7, 'Itau', '0', 0, 'L');
    PL_FPDF.Line(co_x0 + 26, py, co_x0 + 26, py + 7);
    PL_FPDF.SetFont('Arial', 'B', 13);
    PL_FPDF.SetXY(co_x0 + 26, py);
    PL_FPDF.Cell(20, 7, '341-7', '0', 0, 'C');
    PL_FPDF.Line(co_x0 + 46, py, co_x0 + 46, py + 7);
    PL_FPDF.SetFont('Arial', 'B', 11);
    PL_FPDF.SetXY(co_x0 + 46, py);
    PL_FPDF.Cell(co_larg - 46, 7, co_ld, '0', 0, 'R');
    PL_FPDF.Line(co_x0, py + 7.5, co_x0 + co_larg, py + 7.5);
    PL_FPDF.SetLineWidth(0.2);

    campo(co_x0, y, co_esq, 8, 'Local de pagamento',
          'Ate o vencimento, pagavel em qualquer banco');
    campo(co_xd, y, co_dir, 8, 'Vencimento', '31/12/2026', TRUE, 'R');
    y := y + 8;

    campo(co_x0, y, co_esq, 8, 'Beneficiario',
          'M&S DO BRASIL LTDA - 05.230.380/0001-74');
    campo(co_xd, y, co_dir, 8, 'Agencia/Codigo beneficiario',
          '3073 / 12345-1', FALSE, 'R');
    y := y + 8;

    campo(co_x0,        y, 26, 8, 'Data do documento', '01/12/2026');
    campo(co_x0 +  26,  y, 34, 8, 'N. do documento', '000000123');
    campo(co_x0 +  60,  y, 20, 8, 'Especie doc.', 'DM');
    campo(co_x0 +  80,  y, 14, 8, 'Aceite', 'N');
    campo(co_x0 +  94,  y, 43, 8, 'Data do processamento',
          '01/12/2026');
    campo(co_xd, y, co_dir, 8, 'Nosso numero', '109/00000123-2',
          FALSE, 'R');
    y := y + 8;

    campo(co_x0,        y, 26, 8, 'Uso do banco');
    campo(co_x0 +  26,  y, 20, 8, 'Carteira', '109');
    campo(co_x0 +  46,  y, 16, 8, 'Especie', 'R$');
    campo(co_x0 +  62,  y, 30, 8, 'Quantidade', '1');
    campo(co_x0 +  92,  y, 45, 8, 'Valor', '150,00');
    campo(co_xd, y, co_dir, 8, '(=) Valor do documento', '150,00',
          TRUE, 'R');
    y := y + 8;

    campo(co_x0, y, co_esq, 28,
          'Instrucoes (Texto de responsabilidade do beneficiario)');
    IF pcompleta THEN
      miudo(co_x0, y + 4, co_esq,
            'Apos o vencimento cobrar multa de 2%', 'I');
      miudo(co_x0, y + 8, co_esq,
            'Juros de mora de 1% ao mes', 'I');
      miudo(co_x0, y + 12, co_esq,
            'Nao receber apos 30 dias do vencimento', 'I');
    END IF;
    campo(co_xd, y,        co_dir, 5.6, '(-) Desconto / Abatimento',
          NULL, FALSE, 'R');
    campo(co_xd, y +  5.6, co_dir, 5.6, '(-) Outras deducoes',
          NULL, FALSE, 'R');
    campo(co_xd, y + 11.2, co_dir, 5.6, '(+) Mora / Multa',
          NULL, FALSE, 'R');
    campo(co_xd, y + 16.8, co_dir, 5.6, '(+) Outros acrescimos',
          NULL, FALSE, 'R');
    campo(co_xd, y + 22.4, co_dir, 5.6, '(=) Valor cobrado',
          NULL, FALSE, 'R');
    y := y + 28;

    -- o nome vai na linha do valor e o endereco 6,6 mm abaixo do topo
    -- da caixa: menos que isso empilha um texto sobre o outro
    campo(co_x0, y, co_larg, 11, 'Pagador',
          'Joao da Silva - 529.982.247-25', TRUE);
    miudo(co_x0, y + 6.6, co_larg,
          'Rua das Flores, 100 - Sete Lagoas/MG - 35700-000');
    y := y + 11;

    campo(co_x0, y, co_esq, 8, 'Sacador/Avalista');
    campo(co_xd, y, co_dir, 8, 'Codigo de baixa', NULL, FALSE, 'R');
    y := y + 8;

    miudo(co_x0, y + 0.5, co_larg,
          'Autenticacao mecanica - ' || protulo, 'I', 'R');
  END via;
BEGIN
  PL_FPDF.ClearPDFCache;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetTitle('Boleto de cobranca 109/00000123-2');
  PL_FPDF.SetAuthor('M&S do Brasil');
  PL_FPDF.AddPage();
  PL_FPDF.SetDrawColor(0, 0, 0);
  PL_FPDF.SetLineWidth(0.2);

  via(20, 'Recibo do Pagador', FALSE);

  -- linha de corte, no meio do vao entre as duas vias
  FOR i IN 0 .. 43 LOOP
    PL_FPDF.Line(co_x0 + i * 4, 125, co_x0 + i * 4 + 2.4, 125);
  END LOOP;

  via(138, 'Ficha de Compensacao', TRUE);

  -- codigo de barras do boleto: ITF de 44 digitos, sem verificador de
  -- simbologia (o de controle do boleto fica DENTRO dos 44)
  PL_FPDF.AddBarcode(co_x0, 233, 103, 13, co_cb, 'ITF', FALSE);

  l_pdf := PL_FPDF.OutputBlob();
  DBMS_OUTPUT.PUT_LINE('boleto gerado: ' || DBMS_LOB.GETLENGTH(l_pdf)
                       || ' bytes');

  PL_FPDF.ClearPDFCache;
  PL_FPDF.Reset;
END;
/
