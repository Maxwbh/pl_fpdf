--------------------------------------------------------------------------------
-- PL_FPDF — exemplo: o LAYOUT de um ingresso de evento
--
-- O irmao colorido do examples/boleto.sql. O boleto prova grade: 50 caixas ao
-- milimetro, preto no branco, uma pagina. Este prova o resto:
--
--   * COR — faixa de cabecalho preenchida, texto branco sobre ela, paineis
--     cinzas com miolo branco (SetFillColor + Rect 'F' + SetTextColor);
--   * QR CODE e CODE 39 na mesma pagina, os dois dizendo o mesmo codigo;
--   * DUAS PAGINAS, cada uma com o seu participante e o seu codigo;
--   * uma forma que NAO e retangulo — o rabinho do balao, com Poly.
--
-- Sem imagem nenhuma: e tudo desenho vetorial e texto.
--
-- Como rodar: abra na SQL Window do PL/SQL Developer e execute com F8. O PDF
-- fica no BLOB `l_pdf` — grave numa tabela, devolva por uma funcao ou escreva
-- com UTL_FILE, conforme o seu caso.
--
-- O PL_FPDF DESENHA. O codigo do ingresso chega pronto, como qualquer outro
-- dado que o chamador passa: emitir, reservar assento e validar entrada sao
-- regras de negocio, e nao de uma biblioteca de PDF.
--------------------------------------------------------------------------------

DECLARE
  l_pdf   BLOB;
  -- Cores: o azul-marinho e o laranja do proprio projeto.
  co_az_r CONSTANT NUMBER := 13;   co_az_g CONSTANT NUMBER := 25;
  co_az_b CONSTANT NUMBER := 44;
  co_lj_r CONSTANT NUMBER := 232;  co_lj_g CONSTANT NUMBER := 80;
  co_lj_b CONSTANT NUMBER := 58;
  co_cinza     CONSTANT NUMBER := 216;
  co_cinza_c   CONSTANT NUMBER := 240;
  co_grafite   CONSTANT NUMBER := 68;

  co_x0    CONSTANT NUMBER := 12;    -- margem esquerda
  co_larg  CONSTANT NUMBER := 186;   -- largura util
  co_esq   CONSTANT NUMBER := 130;   -- painel da esquerda
  co_xqr   CONSTANT NUMBER := 146;   -- painel do QR
  co_lqr   CONSTANT NUMBER := 52;

  PROCEDURE painel(px NUMBER, py NUMBER, pw NUMBER, ph NUMBER,
                   pr NUMBER, pg NUMBER := NULL, pb NUMBER := NULL) IS
  BEGIN
    PL_FPDF.SetFillColor(pr, NVL(pg, pr), NVL(pb, pr));
    PL_FPDF.Rect(px, py, pw, ph, 'F');
  END painel;

  -- Escreve uma linha. A Cell ja tem margem interna de 1 mm dos dois lados,
  -- entao a largura passada e a da caixa inteira.
  PROCEDURE linha(px NUMBER, py NUMBER, pw NUMBER, ph NUMBER, ptxt VARCHAR2,
                  pcorpo NUMBER, pest VARCHAR2 := NULL,
                  palin VARCHAR2 := 'L', pr NUMBER := 0,
                  pg NUMBER := NULL, pb NUMBER := NULL) IS
  BEGIN
    PL_FPDF.SetTextColor(pr, NVL(pg, pr), NVL(pb, pr));
    PL_FPDF.SetFont('Arial', pest, pcorpo);
    PL_FPDF.SetXY(px, py);
    PL_FPDF.Cell(pw, ph, ptxt, '0', 0, palin);
  END linha;

  PROCEDURE ingresso(pnome VARCHAR2, pcodigo VARCHAR2) IS
    l_pts PL_FPDF.tab_points;
    l_pt  PL_FPDF.point;
  BEGIN
    PL_FPDF.AddPage();

    -- faixa do cabecalho, e o texto em branco sobre ela
    painel(co_x0, 13.5, co_larg, 36, co_az_r, co_az_g, co_az_b);
    linha(16, 18,   178, 9, 'Orquestra Sinfonica - Concerto de Gala', 17, 'B',
          'L', 255);
    linha(16, 30.5, 178, 5, '19 out. 2026 - 20h as 22h', 8, NULL, 'L', 255);
    linha(16, 36.5, 178, 5, 'Teatro Municipal', 8, 'B', 'L', 255);
    linha(16, 41.5, 178, 4,
          'Avenida Afonso Pena, 1321, Centro - Belo Horizonte, MG', 7, NULL,
          'L', 255);

    -- painel do ingresso: moldura cinza com miolo branco por cima
    painel(co_x0, 52,   co_esq, 32,   co_cinza);
    painel(14.8,  58.4, 124.4,  22.8, 255);
    linha(co_x0, 53,   co_esq, 5, 'Ingresso', 10, NULL, 'L', co_grafite);
    linha(14.8,  59.6, 124.4, 5, '1o LOTE - INTEIRA', 14, 'B');
    linha(14.8,  66.6, 124.4, 5, 'R$ 120,00', 14, 'B');
    linha(14.8,  74,   124.4, 4, 'Comprado dia 18 out. 2026 - 18h26', 7, NULL,
          'R', co_grafite);

    -- painel do participante
    painel(co_x0, 87,   co_esq, 22.5, co_cinza);
    painel(14.8,  93.4, 124.4,  13.3, 255);
    linha(co_x0, 88, co_esq, 5, 'Participante', 10, NULL, 'L', co_grafite);
    linha(14.8,  95, 124.4, 7, pnome, 16, 'B');

    -- painel do QR, com o codigo embaixo
    painel(co_xqr, 52,   co_lqr, 57.5, co_cinza);
    painel(148.8,  54.8, 46.4,   51.9, 255);
    PL_FPDF.AddQRCode(p_x => 156, p_y => 58, p_size => 32,
                      p_data => pcodigo, p_format => 'TEXT',
                      p_error_correction => 'M');
    linha(co_xqr, 97.5, co_lqr, 5, pcodigo, 12, 'B', 'C');

    -- faixa do codigo de barras
    painel(co_x0, 112.5, co_larg, 19,   co_cinza);
    painel(14.8,  115.3, 180.4,   13.4, 255);
    PL_FPDF.AddBarcode(45, 117, 120, 10, pcodigo, 'CODE39', FALSE);

    -- balao de aviso: retangulo mais o rabinho, que nao e retangulo
    painel(32, 138.5, 142, 17, co_cinza_c, 241, 241);
    -- o registro vai montado: atribuir l_pts(0).x num elemento que ainda
    -- nao existe levanta ORA-01403 em tempo de execucao
    l_pt.x := 38;  l_pt.y := 155.5;  l_pts(0) := l_pt;
    l_pt.x := 38;  l_pt.y := 160;    l_pts(1) := l_pt;
    l_pt.x := 44;  l_pt.y := 155.5;  l_pts(2) := l_pt;
    PL_FPDF.Poly(l_pts, TRUE, 'F');
    linha(32, 143.5, 142, 5,
          'Apresente este ingresso na entrada, impresso ou na tela do celular.',
          8, NULL, 'C');

    -- aba e caixa da mensagem da organizacao
    painel(72.5, 165.5, 65, 8.5, co_cinza_c, 241, 241);
    linha(72.5, 167, 65, 4, 'Mensagem da organizacao', 7, NULL, 'C',
          co_grafite);
    PL_FPDF.SetDrawColor(co_cinza, co_cinza, co_cinza);
    PL_FPDF.Rect(co_x0, 174, co_larg, 60, 'D');
    linha(14, 178, 182, 5,
          'Obrigado por vir. A casa abre as 19h, e a entrada com bebida nao e '
          || 'permitida no teatro.', 8);

    -- Rodape em 262, e nao em 276: a Cell abre PAGINA NOVA quando y + altura
    -- passa de 277 (A4 menos a margem inferior de 20 mm). Nao e erro, e quebra
    -- automatica — dois ingressos viravam seis paginas, e o sintoma aparecia
    -- longe da causa.
    linha(co_x0, 262, co_larg, 9, 'M&S Eventos', 14, 'B', 'C',
          co_lj_r, co_lj_g, co_lj_b);
    linha(co_x0, 270, co_larg, 4, 'exemplo.com.br', 7, NULL, 'C', co_grafite);
  END ingresso;
BEGIN
  PL_FPDF.ClearPDFCache;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.SetTitle('Ingressos - Concerto de Gala');
  PL_FPDF.SetAuthor('M&S Eventos');
  PL_FPDF.SetLineWidth(0.2);

  -- um ingresso por pagina, cada um com o seu participante e o seu codigo
  ingresso('Maria Aparecida de Souza', 'UDV2259QK5');
  ingresso('Joao Pedro Nogueira',      'PLF7731ZT2');

  l_pdf := PL_FPDF.OutputBlob();
  DBMS_OUTPUT.PUT_LINE('ingressos gerados: ' || DBMS_LOB.GETLENGTH(l_pdf)
                       || ' bytes');

  PL_FPDF.ClearPDFCache;
  PL_FPDF.Reset;
END;
/
