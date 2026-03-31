# Arquitetura para HTML to PDF e Features Avancadas

**Version:** 3.3.0+
**Date:** 2026-03
**Status:** Proposta

---

## Objetivo

Arquitetura que **facilita o desenvolvimento** de:
- v3.3.0: HTML to PDF
- v3.4.0: PDF 1.5/1.6
- v3.5.0: PDF 1.7 (Forms, Bookmarks)
- v4.0.0: PDF 2.0 (Signatures, PDF/A)

**Principio:** Usar tabelas e tipos para **simplificar** codigo complexo.

---

## Arquitetura Proposta

```
┌─────────────────────────────────────────────────────────────────┐
│                         PL_FPDF (API)                           │
│            Facade - mantém compatibilidade v3.0                 │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  PL_FPDF_HTML │     │  PL_FPDF_FORM │     │  PL_FPDF_NAV  │
│  HTML Parser  │     │  AcroForms    │     │  Bookmarks    │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TABELAS DE SUPORTE                           │
├─────────────────────────────────────────────────────────────────┤
│  FPDF_HTML_ELEMENTS  │  FPDF_CSS_RULES  │  FPDF_TEMPLATES      │
│  FPDF_FORM_FIELDS    │  FPDF_BOOKMARKS  │  FPDF_FONTS          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OBJECT TYPES                                 │
├─────────────────────────────────────────────────────────────────┤
│  T_HTML_ELEMENT  │  T_CSS_STYLE  │  T_FORM_FIELD  │  T_BOOKMARK │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Object Types para HTML

### T_HTML_ELEMENT - Elemento HTML

```sql
CREATE OR REPLACE TYPE T_HTML_ELEMENT AS OBJECT (
  element_id      NUMBER,
  tag_name        VARCHAR2(50),      -- div, p, table, tr, td, etc.
  parent_id       NUMBER,
  position        NUMBER,            -- ordem no parent
  attributes      JSON,              -- {"class": "...", "id": "...", "style": "..."}
  text_content    CLOB,
  computed_style  JSON,              -- estilos calculados

  -- Dimensoes calculadas
  x               NUMBER,
  y               NUMBER,
  width           NUMBER,
  height          NUMBER,

  -- Metodos
  MEMBER FUNCTION GetAttribute(p_name VARCHAR2) RETURN VARCHAR2,
  MEMBER FUNCTION GetStyle(p_property VARCHAR2) RETURN VARCHAR2,
  MEMBER FUNCTION GetChildren RETURN T_HTML_ELEMENT_LIST,
  MEMBER FUNCTION IsBlock RETURN BOOLEAN,
  MEMBER FUNCTION IsInline RETURN BOOLEAN,
  MEMBER PROCEDURE Render(p_pdf IN OUT NOCOPY BLOB)
);
/

CREATE OR REPLACE TYPE T_HTML_ELEMENT_LIST AS TABLE OF T_HTML_ELEMENT;
/
```

### T_CSS_STYLE - Estilo CSS

```sql
CREATE OR REPLACE TYPE T_CSS_STYLE AS OBJECT (
  -- Text
  font_family     VARCHAR2(100),
  font_size       NUMBER,            -- em points
  font_weight     VARCHAR2(20),      -- normal, bold
  font_style      VARCHAR2(20),      -- normal, italic
  color           VARCHAR2(20),      -- #RRGGBB
  text_align      VARCHAR2(20),      -- left, center, right, justify
  text_decoration VARCHAR2(50),      -- none, underline, line-through
  line_height     NUMBER,

  -- Box Model
  margin_top      NUMBER,
  margin_right    NUMBER,
  margin_bottom   NUMBER,
  margin_left     NUMBER,
  padding_top     NUMBER,
  padding_right   NUMBER,
  padding_bottom  NUMBER,
  padding_left    NUMBER,

  -- Border
  border_width    NUMBER,
  border_style    VARCHAR2(20),      -- none, solid, dashed
  border_color    VARCHAR2(20),

  -- Background
  background_color VARCHAR2(20),

  -- Layout
  width           VARCHAR2(50),      -- auto, 100px, 50%
  height          VARCHAR2(50),
  display         VARCHAR2(20),      -- block, inline, none

  -- Metodos
  MEMBER FUNCTION Merge(p_other T_CSS_STYLE) RETURN T_CSS_STYLE,
  MEMBER FUNCTION ToJSON RETURN JSON_OBJECT_T,
  STATIC FUNCTION Parse(p_css VARCHAR2) RETURN T_CSS_STYLE,
  STATIC FUNCTION FromJSON(p_json JSON_OBJECT_T) RETURN T_CSS_STYLE
);
/
```

### T_TABLE_CELL - Celula de Tabela

```sql
CREATE OR REPLACE TYPE T_TABLE_CELL AS OBJECT (
  row_index       NUMBER,
  col_index       NUMBER,
  rowspan         NUMBER DEFAULT 1,
  colspan         NUMBER DEFAULT 1,
  content         CLOB,
  style           T_CSS_STYLE,
  is_header       CHAR(1) DEFAULT 'N',

  -- Dimensoes calculadas
  x               NUMBER,
  y               NUMBER,
  width           NUMBER,
  height          NUMBER,

  MEMBER PROCEDURE Render(p_pdf IN OUT NOCOPY BLOB)
);
/

CREATE OR REPLACE TYPE T_TABLE_CELL_LIST AS TABLE OF T_TABLE_CELL;
/

CREATE OR REPLACE TYPE T_TABLE_ROW AS OBJECT (
  row_index       NUMBER,
  cells           T_TABLE_CELL_LIST,
  height          NUMBER,

  MEMBER FUNCTION GetCell(p_col NUMBER) RETURN T_TABLE_CELL
);
/

CREATE OR REPLACE TYPE T_TABLE_ROW_LIST AS TABLE OF T_TABLE_ROW;
/
```

---

## 2. Tabelas de Suporte

### FPDF_HTML_ELEMENTS - Cache de Parsing

```sql
CREATE TABLE FPDF_HTML_ELEMENTS (
  element_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id      VARCHAR2(100) NOT NULL,
  doc_id          VARCHAR2(50) NOT NULL,
  parent_id       NUMBER,
  tag_name        VARCHAR2(50) NOT NULL,
  position        NUMBER,
  attributes      JSON,
  text_content    CLOB,
  computed_style  JSON,
  x               NUMBER,
  y               NUMBER,
  width           NUMBER,
  height          NUMBER,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP,

  CONSTRAINT fk_html_parent FOREIGN KEY (parent_id)
    REFERENCES FPDF_HTML_ELEMENTS(element_id) ON DELETE CASCADE
);

CREATE INDEX idx_html_session ON FPDF_HTML_ELEMENTS(session_id, doc_id);
CREATE INDEX idx_html_parent ON FPDF_HTML_ELEMENTS(parent_id);

-- Cleanup automatico
CREATE OR REPLACE TRIGGER trg_html_cleanup
AFTER INSERT ON FPDF_HTML_ELEMENTS
BEGIN
  -- Limpar elementos com mais de 1 hora
  DELETE FROM FPDF_HTML_ELEMENTS
  WHERE created_at < SYSTIMESTAMP - INTERVAL '1' HOUR;
END;
/
```

### FPDF_CSS_RULES - Regras CSS

```sql
CREATE TABLE FPDF_CSS_RULES (
  rule_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id      VARCHAR2(100),
  selector        VARCHAR2(500),     -- .class, #id, tag, tag.class
  specificity     NUMBER,            -- para cascading
  properties      JSON,              -- {"color": "#000", "font-size": "12pt"}
  source          VARCHAR2(20),      -- inline, internal, external
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE INDEX idx_css_session ON FPDF_CSS_RULES(session_id);
CREATE INDEX idx_css_selector ON FPDF_CSS_RULES(selector);
```

### FPDF_TEMPLATES - Templates HTML

```sql
CREATE TABLE FPDF_TEMPLATES (
  template_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  template_name   VARCHAR2(200) NOT NULL,
  template_type   VARCHAR2(50),      -- invoice, report, letter, etc.
  html_content    CLOB NOT NULL,
  css_content     CLOB,
  variables       JSON,              -- [{"name": "customer", "type": "string"}, ...]
  default_options JSON,              -- {"pageSize": "A4", "margins": {...}}
  is_active       CHAR(1) DEFAULT 'Y',
  created_by      VARCHAR2(100),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP,
  updated_at      TIMESTAMP,

  CONSTRAINT uk_template_name UNIQUE (template_name)
);

-- Templates pre-definidos
INSERT INTO FPDF_TEMPLATES (template_name, template_type, html_content, variables) VALUES
('invoice_simple', 'invoice', '
<html>
<head>
  <style>
    body { font-family: Arial; font-size: 10pt; }
    .header { font-size: 18pt; font-weight: bold; margin-bottom: 20px; }
    .info { margin-bottom: 10px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #ccc; padding: 5px; }
    th { background-color: #f0f0f0; }
    .total { font-weight: bold; text-align: right; }
  </style>
</head>
<body>
  <div class="header">FATURA #{{invoice_number}}</div>
  <div class="info">
    <strong>Cliente:</strong> {{customer_name}}<br>
    <strong>Data:</strong> {{invoice_date}}
  </div>
  <table>
    <thead>
      <tr><th>Item</th><th>Qtd</th><th>Valor</th><th>Total</th></tr>
    </thead>
    <tbody>
      {{#items}}
      <tr>
        <td>{{description}}</td>
        <td>{{quantity}}</td>
        <td>{{unit_price}}</td>
        <td>{{line_total}}</td>
      </tr>
      {{/items}}
    </tbody>
    <tfoot>
      <tr class="total">
        <td colspan="3">TOTAL</td>
        <td>{{total}}</td>
      </tr>
    </tfoot>
  </table>
</body>
</html>
', '[
  {"name": "invoice_number", "type": "string"},
  {"name": "customer_name", "type": "string"},
  {"name": "invoice_date", "type": "date"},
  {"name": "items", "type": "array"},
  {"name": "total", "type": "number"}
]');
```

### FPDF_TAG_MAPPINGS - Mapeamento Tag -> PDF

```sql
CREATE TABLE FPDF_TAG_MAPPINGS (
  tag_name        VARCHAR2(50) PRIMARY KEY,
  pdf_action      VARCHAR2(100),     -- SetFont, Cell, MultiCell, Ln, Line, etc.
  default_style   JSON,
  is_block        CHAR(1) DEFAULT 'Y',
  is_container    CHAR(1) DEFAULT 'N',
  render_proc     VARCHAR2(100)      -- Procedure customizada
);

-- Mapeamentos padrao
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('h1', 'SetFont+Cell', '{"font_size": 24, "font_weight": "bold", "margin_bottom": 10}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('h2', 'SetFont+Cell', '{"font_size": 20, "font_weight": "bold", "margin_bottom": 8}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('h3', 'SetFont+Cell', '{"font_size": 16, "font_weight": "bold", "margin_bottom": 6}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('h4', 'SetFont+Cell', '{"font_size": 14, "font_weight": "bold", "margin_bottom": 5}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('h5', 'SetFont+Cell', '{"font_size": 12, "font_weight": "bold", "margin_bottom": 4}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('h6', 'SetFont+Cell', '{"font_size": 10, "font_weight": "bold", "margin_bottom": 3}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('p', 'MultiCell', '{"margin_bottom": 5}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('br', 'Ln', '{}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('hr', 'Line', '{"margin_top": 5, "margin_bottom": 5}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('div', 'Container', '{}', 'Y', 'Y', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('span', 'Inline', '{}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('b', 'SetFont', '{"font_weight": "bold"}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('strong', 'SetFont', '{"font_weight": "bold"}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('i', 'SetFont', '{"font_style": "italic"}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('em', 'SetFont', '{"font_style": "italic"}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('u', 'SetFont', '{"text_decoration": "underline"}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('table', 'Table', '{"border": 1}', 'Y', 'Y', 'RENDER_TABLE');
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('tr', 'TableRow', '{}', 'Y', 'Y', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('td', 'TableCell', '{}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('th', 'TableCell', '{"font_weight": "bold", "background_color": "#f0f0f0"}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('ul', 'List', '{"list_style": "disc"}', 'Y', 'Y', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('ol', 'List', '{"list_style": "decimal"}', 'Y', 'Y', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('li', 'ListItem', '{"margin_left": 10}', 'Y', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('a', 'Link', '{"color": "#0000FF", "text_decoration": "underline"}', 'N', 'N', NULL);
INSERT INTO FPDF_TAG_MAPPINGS VALUES ('img', 'Image', '{}', 'N', 'N', 'RENDER_IMAGE');
```

---

## 3. Package PL_FPDF_HTML

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_HTML AS
  /*
   * HTML to PDF Converter
   * Uses tables for parsing and rendering
   */

  -- Conversion principal
  FUNCTION HTMLToPDF(
    p_html    CLOB,
    p_options JSON_OBJECT_T DEFAULT NULL
  ) RETURN BLOB;

  -- Render HTML into current PDF
  PROCEDURE RenderHTML(
    p_html    CLOB,
    p_x       NUMBER DEFAULT NULL,
    p_y       NUMBER DEFAULT NULL,
    p_width   NUMBER DEFAULT NULL
  );

  -- Template-based rendering
  FUNCTION RenderTemplate(
    p_template_name VARCHAR2,
    p_data          JSON_OBJECT_T
  ) RETURN BLOB;

  -- Parse HTML to elements (for debugging/inspection)
  FUNCTION ParseHTML(
    p_html    CLOB,
    p_doc_id  VARCHAR2 DEFAULT NULL
  ) RETURN T_HTML_ELEMENT_LIST PIPELINED;

  -- Parse CSS
  PROCEDURE ParseCSS(
    p_css       CLOB,
    p_session_id VARCHAR2
  );

  -- Get computed style for element
  FUNCTION GetComputedStyle(
    p_element_id NUMBER
  ) RETURN T_CSS_STYLE;

  -- Clear session cache
  PROCEDURE ClearCache(p_session_id VARCHAR2 DEFAULT NULL);

  -- Template management
  PROCEDURE CreateTemplate(
    p_name      VARCHAR2,
    p_html      CLOB,
    p_css       CLOB DEFAULT NULL,
    p_variables JSON DEFAULT NULL
  );

  PROCEDURE UpdateTemplate(
    p_name      VARCHAR2,
    p_html      CLOB,
    p_css       CLOB DEFAULT NULL
  );

  PROCEDURE DeleteTemplate(p_name VARCHAR2);

  FUNCTION ListTemplates RETURN SYS_REFCURSOR;

END PL_FPDF_HTML;
/

CREATE OR REPLACE PACKAGE BODY PL_FPDF_HTML AS

  -- Session ID for caching
  g_session_id VARCHAR2(100);

  -- Current document ID
  g_doc_id VARCHAR2(50);

  -- Initialize session
  PROCEDURE init_session IS
  BEGIN
    IF g_session_id IS NULL THEN
      g_session_id := SYS_GUID();
    END IF;
  END;

  -- Tokenize HTML
  PROCEDURE tokenize_html(
    p_html    CLOB,
    p_doc_id  VARCHAR2
  ) IS
    l_pos       PLS_INTEGER := 1;
    l_len       PLS_INTEGER;
    l_char      VARCHAR2(1);
    l_tag       VARCHAR2(100);
    l_attrs     VARCHAR2(4000);
    l_text      CLOB;
    l_in_tag    BOOLEAN := FALSE;
    l_parent_id NUMBER;
    l_elem_id   NUMBER;
    l_stack     JSON_ARRAY_T := JSON_ARRAY_T();
  BEGIN
    l_len := DBMS_LOB.GETLENGTH(p_html);
    g_doc_id := p_doc_id;

    -- Root element
    INSERT INTO FPDF_HTML_ELEMENTS (session_id, doc_id, tag_name, position)
    VALUES (g_session_id, g_doc_id, 'root', 0)
    RETURNING element_id INTO l_parent_id;

    l_stack.append(l_parent_id);

    WHILE l_pos <= l_len LOOP
      l_char := DBMS_LOB.SUBSTR(p_html, 1, l_pos);

      IF l_char = '<' THEN
        -- Save any pending text
        IF DBMS_LOB.GETLENGTH(l_text) > 0 THEN
          UPDATE FPDF_HTML_ELEMENTS
          SET text_content = l_text
          WHERE element_id = l_parent_id;
          DBMS_LOB.FREETEMPORARY(l_text);
        END IF;

        -- Parse tag
        l_tag := '';
        l_pos := l_pos + 1;

        -- Check for closing tag
        IF DBMS_LOB.SUBSTR(p_html, 1, l_pos) = '/' THEN
          -- Closing tag - pop from stack
          l_pos := l_pos + 1;
          WHILE l_pos <= l_len AND DBMS_LOB.SUBSTR(p_html, 1, l_pos) != '>' LOOP
            l_pos := l_pos + 1;
          END LOOP;

          IF l_stack.get_size > 1 THEN
            l_stack.remove(l_stack.get_size - 1);
            l_parent_id := l_stack.get_Number(l_stack.get_size - 1);
          END IF;
        ELSE
          -- Opening tag
          WHILE l_pos <= l_len AND DBMS_LOB.SUBSTR(p_html, 1, l_pos) NOT IN (' ', '>', '/') LOOP
            l_tag := l_tag || DBMS_LOB.SUBSTR(p_html, 1, l_pos);
            l_pos := l_pos + 1;
          END LOOP;

          -- Parse attributes
          l_attrs := '';
          WHILE l_pos <= l_len AND DBMS_LOB.SUBSTR(p_html, 1, l_pos) != '>' LOOP
            l_attrs := l_attrs || DBMS_LOB.SUBSTR(p_html, 1, l_pos);
            l_pos := l_pos + 1;
          END LOOP;

          -- Insert element
          INSERT INTO FPDF_HTML_ELEMENTS (
            session_id, doc_id, parent_id, tag_name,
            position, attributes
          ) VALUES (
            g_session_id, g_doc_id, l_parent_id, LOWER(l_tag),
            (SELECT NVL(MAX(position), 0) + 1
             FROM FPDF_HTML_ELEMENTS
             WHERE parent_id = l_parent_id),
            parse_attributes(l_attrs)
          ) RETURNING element_id INTO l_elem_id;

          -- Push to stack if container
          IF is_container_tag(LOWER(l_tag)) THEN
            l_stack.append(l_elem_id);
            l_parent_id := l_elem_id;
          END IF;
        END IF;

        l_in_tag := FALSE;
      ELSE
        -- Text content
        IF l_text IS NULL THEN
          DBMS_LOB.CREATETEMPORARY(l_text, TRUE);
        END IF;
        DBMS_LOB.WRITEAPPEND(l_text, 1, l_char);
      END IF;

      l_pos := l_pos + 1;
    END LOOP;
  END tokenize_html;

  -- Parse attributes string to JSON
  FUNCTION parse_attributes(p_attrs VARCHAR2) RETURN JSON IS
    l_result JSON_OBJECT_T := JSON_OBJECT_T();
    l_pairs  APEX_T_VARCHAR2;
    l_name   VARCHAR2(100);
    l_value  VARCHAR2(4000);
  BEGIN
    IF p_attrs IS NULL OR TRIM(p_attrs) IS NULL THEN
      RETURN l_result.to_JSON;
    END IF;

    -- Simple attribute parsing
    -- TODO: Handle quoted values properly
    l_pairs := APEX_STRING.SPLIT(TRIM(p_attrs), ' ');

    FOR i IN 1..l_pairs.COUNT LOOP
      IF INSTR(l_pairs(i), '=') > 0 THEN
        l_name := SUBSTR(l_pairs(i), 1, INSTR(l_pairs(i), '=') - 1);
        l_value := REPLACE(REPLACE(
          SUBSTR(l_pairs(i), INSTR(l_pairs(i), '=') + 1),
          '"', ''), '''', '');
        l_result.put(LOWER(l_name), l_value);
      END IF;
    END LOOP;

    RETURN l_result.to_JSON;
  END parse_attributes;

  -- Check if tag is container
  FUNCTION is_container_tag(p_tag VARCHAR2) RETURN BOOLEAN IS
    l_is_container CHAR(1);
  BEGIN
    SELECT is_container INTO l_is_container
    FROM FPDF_TAG_MAPPINGS
    WHERE tag_name = p_tag;

    RETURN l_is_container = 'Y';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END is_container_tag;

  -- Calculate layout
  PROCEDURE calculate_layout(
    p_doc_id    VARCHAR2,
    p_width     NUMBER,
    p_start_x   NUMBER DEFAULT 10,
    p_start_y   NUMBER DEFAULT 10
  ) IS
    l_x         NUMBER := p_start_x;
    l_y         NUMBER := p_start_y;
    l_max_width NUMBER := p_width;
  BEGIN
    -- Recursive layout calculation
    FOR elem IN (
      SELECT element_id, tag_name, text_content, attributes, parent_id
      FROM FPDF_HTML_ELEMENTS
      WHERE session_id = g_session_id AND doc_id = p_doc_id
      START WITH parent_id IS NULL OR tag_name = 'root'
      CONNECT BY PRIOR element_id = parent_id
      ORDER SIBLINGS BY position
    ) LOOP
      -- Get computed style
      -- Calculate dimensions based on content and style
      -- Update element position

      UPDATE FPDF_HTML_ELEMENTS
      SET x = l_x, y = l_y
      WHERE element_id = elem.element_id;

      -- Advance position based on element type
      IF is_block_tag(elem.tag_name) THEN
        l_y := l_y + get_element_height(elem.element_id);
        l_x := p_start_x;
      ELSE
        l_x := l_x + get_element_width(elem.element_id);
      END IF;
    END LOOP;
  END calculate_layout;

  -- Render elements to PDF
  PROCEDURE render_elements(
    p_doc_id VARCHAR2
  ) IS
  BEGIN
    FOR elem IN (
      SELECT e.*, m.pdf_action, m.render_proc
      FROM FPDF_HTML_ELEMENTS e
      LEFT JOIN FPDF_TAG_MAPPINGS m ON e.tag_name = m.tag_name
      WHERE e.session_id = g_session_id AND e.doc_id = p_doc_id
      START WITH e.parent_id IS NULL OR e.tag_name = 'root'
      CONNECT BY PRIOR e.element_id = e.parent_id
      ORDER SIBLINGS BY e.position
    ) LOOP
      -- Apply style
      apply_style(elem.computed_style);

      -- Render based on action
      CASE elem.pdf_action
        WHEN 'SetFont+Cell' THEN
          render_heading(elem);
        WHEN 'MultiCell' THEN
          render_paragraph(elem);
        WHEN 'Ln' THEN
          PL_FPDF.Ln();
        WHEN 'Line' THEN
          render_hr(elem);
        WHEN 'Table' THEN
          render_table(elem);
        WHEN 'Link' THEN
          render_link(elem);
        ELSE
          -- Custom render procedure
          IF elem.render_proc IS NOT NULL THEN
            EXECUTE IMMEDIATE 'BEGIN ' || elem.render_proc || '(:1); END;'
              USING elem.element_id;
          ELSIF elem.text_content IS NOT NULL THEN
            PL_FPDF.Write(5, elem.text_content);
          END IF;
      END CASE;
    END LOOP;
  END render_elements;

  -- Render table (complex)
  PROCEDURE render_table(p_elem FPDF_HTML_ELEMENTS%ROWTYPE) IS
    l_rows      T_TABLE_ROW_LIST := T_TABLE_ROW_LIST();
    l_cols      PLS_INTEGER := 0;
    l_col_widths JSON_ARRAY_T;
    l_row_idx   PLS_INTEGER := 0;
  BEGIN
    -- Collect rows and cells
    FOR tr IN (
      SELECT element_id, position
      FROM FPDF_HTML_ELEMENTS
      WHERE parent_id = p_elem.element_id AND tag_name IN ('tr', 'thead', 'tbody', 'tfoot')
      ORDER BY position
    ) LOOP
      l_row_idx := l_row_idx + 1;

      FOR td IN (
        SELECT element_id, tag_name, text_content, attributes, computed_style
        FROM FPDF_HTML_ELEMENTS
        WHERE parent_id = tr.element_id AND tag_name IN ('td', 'th')
        ORDER BY position
      ) LOOP
        -- Add cell to row
        -- Calculate colspan, rowspan
        NULL;
      END LOOP;
    END LOOP;

    -- Calculate column widths
    l_col_widths := calculate_column_widths(l_rows, p_elem.width);

    -- Render table using PL_FPDF
    FOR i IN 1..l_rows.COUNT LOOP
      FOR j IN 1..l_rows(i).cells.COUNT LOOP
        PL_FPDF.Cell(
          l_col_widths.get_Number(j - 1),
          l_rows(i).height,
          l_rows(i).cells(j).content,
          '1',  -- border
          0,    -- ln
          'L'   -- align
        );
      END LOOP;
      PL_FPDF.Ln();
    END LOOP;
  END render_table;

  -- Main conversion function
  FUNCTION HTMLToPDF(
    p_html    CLOB,
    p_options JSON_OBJECT_T DEFAULT NULL
  ) RETURN BLOB IS
    l_doc_id    VARCHAR2(50) := SYS_GUID();
    l_page_size VARCHAR2(20) := 'A4';
    l_orient    VARCHAR2(1) := 'P';
    l_margins   JSON_OBJECT_T;
    l_width     NUMBER := 190;  -- A4 width minus margins
  BEGIN
    init_session();

    -- Parse options
    IF p_options IS NOT NULL THEN
      l_page_size := NVL(p_options.get_String('pageSize'), 'A4');
      l_orient := NVL(p_options.get_String('orientation'), 'P');
      l_margins := p_options.get_Object('margins');
    END IF;

    -- Initialize PDF
    PL_FPDF.Init(l_orient, 'mm', l_page_size);
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', '', 10);

    -- Parse HTML
    tokenize_html(p_html, l_doc_id);

    -- Calculate layout
    calculate_layout(l_doc_id, l_width);

    -- Render to PDF
    render_elements(l_doc_id);

    -- Cleanup
    DELETE FROM FPDF_HTML_ELEMENTS
    WHERE session_id = g_session_id AND doc_id = l_doc_id;

    -- Return PDF
    RETURN PL_FPDF.OutputBlob();
  END HTMLToPDF;

  -- Template rendering
  FUNCTION RenderTemplate(
    p_template_name VARCHAR2,
    p_data          JSON_OBJECT_T
  ) RETURN BLOB IS
    l_html      CLOB;
    l_css       CLOB;
    l_options   JSON_OBJECT_T;
    l_var_name  VARCHAR2(100);
    l_var_value VARCHAR2(4000);
    l_keys      JSON_KEY_LIST;
  BEGIN
    -- Get template
    SELECT html_content, css_content, default_options
    INTO l_html, l_css, l_options
    FROM FPDF_TEMPLATES
    WHERE template_name = p_template_name AND is_active = 'Y';

    -- Replace variables
    l_keys := p_data.get_keys;
    FOR i IN 1..l_keys.COUNT LOOP
      l_var_name := l_keys(i);
      l_var_value := p_data.get_String(l_var_name);
      l_html := REPLACE(l_html, '{{' || l_var_name || '}}', l_var_value);
    END LOOP;

    -- Handle arrays (simple loop)
    -- {{#items}}...{{/items}} pattern
    -- TODO: Implement proper template engine

    -- Combine CSS
    IF l_css IS NOT NULL THEN
      l_html := '<style>' || l_css || '</style>' || l_html;
    END IF;

    -- Convert to PDF
    RETURN HTMLToPDF(l_html, l_options);
  END RenderTemplate;

  -- Other implementations...

END PL_FPDF_HTML;
/
```

---

## 4. Package PL_FPDF_FORM (AcroForms)

### Tabelas

```sql
CREATE TABLE FPDF_FORM_FIELDS (
  field_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id      VARCHAR2(100) NOT NULL,
  doc_id          VARCHAR2(50) NOT NULL,
  field_name      VARCHAR2(200) NOT NULL,
  field_type      VARCHAR2(20) NOT NULL,  -- text, checkbox, radio, dropdown, signature
  page_number     NUMBER,
  x               NUMBER,
  y               NUMBER,
  width           NUMBER,
  height          NUMBER,
  default_value   VARCHAR2(4000),
  options         JSON,                    -- para dropdown: [{"value": "SP", "label": "Sao Paulo"}]
  validation      JSON,                    -- {"required": true, "maxLength": 100}
  appearance      JSON,                    -- {"font": "Arial", "size": 10, "color": "#000"}
  flags           NUMBER DEFAULT 0,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP,

  CONSTRAINT uk_form_field UNIQUE (session_id, doc_id, field_name)
);
```

### Package

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_FORM AS
  /*
   * AcroForms Generator
   */

  -- Begin form definition
  PROCEDURE BeginForm;

  -- Field types
  PROCEDURE AddTextField(
    p_name      VARCHAR2,
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER,
    p_default   VARCHAR2 DEFAULT NULL,
    p_multiline BOOLEAN DEFAULT FALSE,
    p_required  BOOLEAN DEFAULT FALSE,
    p_max_length NUMBER DEFAULT NULL
  );

  PROCEDURE AddCheckbox(
    p_name      VARCHAR2,
    p_x         NUMBER,
    p_y         NUMBER,
    p_size      NUMBER DEFAULT 10,
    p_checked   BOOLEAN DEFAULT FALSE,
    p_label     VARCHAR2 DEFAULT NULL
  );

  PROCEDURE AddRadioGroup(
    p_name      VARCHAR2,
    p_options   JSON_ARRAY_T,  -- [{"value": "opt1", "x": 10, "y": 100, "label": "Option 1"}]
    p_default   VARCHAR2 DEFAULT NULL
  );

  PROCEDURE AddDropdown(
    p_name      VARCHAR2,
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER,
    p_options   JSON_ARRAY_T,  -- [{"value": "SP", "label": "Sao Paulo"}]
    p_default   VARCHAR2 DEFAULT NULL,
    p_editable  BOOLEAN DEFAULT FALSE
  );

  PROCEDURE AddSignatureField(
    p_name      VARCHAR2,
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER
  );

  PROCEDURE AddButton(
    p_name      VARCHAR2,
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER,
    p_label     VARCHAR2,
    p_action    VARCHAR2  -- submit, reset, javascript
  );

  -- End form and generate AcroForm dictionary
  PROCEDURE EndForm;

  -- Get form data from filled PDF
  FUNCTION ExtractFormData(p_pdf BLOB) RETURN JSON_OBJECT_T;

  -- Fill form with data
  FUNCTION FillForm(
    p_pdf  BLOB,
    p_data JSON_OBJECT_T
  ) RETURN BLOB;

  -- Flatten form (convert to static content)
  FUNCTION FlattenForm(p_pdf BLOB) RETURN BLOB;

END PL_FPDF_FORM;
/
```

---

## 5. Package PL_FPDF_NAV (Bookmarks/Links)

### Tabelas

```sql
CREATE TABLE FPDF_BOOKMARKS (
  bookmark_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id      VARCHAR2(100) NOT NULL,
  doc_id          VARCHAR2(50) NOT NULL,
  title           VARCHAR2(500) NOT NULL,
  parent_id       NUMBER,
  page_number     NUMBER,
  y_position      NUMBER,
  is_open         CHAR(1) DEFAULT 'Y',
  position        NUMBER,

  CONSTRAINT fk_bookmark_parent FOREIGN KEY (parent_id)
    REFERENCES FPDF_BOOKMARKS(bookmark_id) ON DELETE CASCADE
);

CREATE TABLE FPDF_LINKS (
  link_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id      VARCHAR2(100) NOT NULL,
  doc_id          VARCHAR2(50) NOT NULL,
  page_number     NUMBER,
  x               NUMBER,
  y               NUMBER,
  width           NUMBER,
  height          NUMBER,
  link_type       VARCHAR2(20),  -- url, internal, named
  destination     VARCHAR2(4000),
  border_style    VARCHAR2(20) DEFAULT 'none'
);
```

### Package

```sql
CREATE OR REPLACE PACKAGE PL_FPDF_NAV AS
  /*
   * Navigation: Bookmarks, Links, Named Destinations
   */

  -- Bookmarks
  PROCEDURE AddBookmark(
    p_title     VARCHAR2,
    p_page      NUMBER DEFAULT NULL,  -- NULL = current page
    p_y         NUMBER DEFAULT 0,
    p_parent    VARCHAR2 DEFAULT NULL,
    p_is_open   BOOLEAN DEFAULT TRUE
  );

  FUNCTION GetBookmarkId(p_title VARCHAR2) RETURN NUMBER;

  -- Links
  PROCEDURE AddURLLink(
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER,
    p_url       VARCHAR2
  );

  PROCEDURE AddInternalLink(
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER,
    p_page      NUMBER,
    p_y_dest    NUMBER DEFAULT 0
  );

  PROCEDURE AddNamedDestination(
    p_name      VARCHAR2,
    p_page      NUMBER DEFAULT NULL,
    p_y         NUMBER DEFAULT 0
  );

  PROCEDURE LinkToDestination(
    p_x         NUMBER,
    p_y         NUMBER,
    p_width     NUMBER,
    p_height    NUMBER,
    p_dest_name VARCHAR2
  );

  -- Generate outline dictionary
  FUNCTION GenerateOutlines RETURN CLOB;

  -- Generate link annotations
  FUNCTION GenerateLinkAnnotations(p_page NUMBER) RETURN CLOB;

END PL_FPDF_NAV;
/
```

---

## 6. Deploy Script

```sql
-- install_html_forms.sql
SET SERVEROUTPUT ON

PROMPT ================================================================================
PROMPT Installing PL_FPDF HTML & Forms Extension
PROMPT ================================================================================

-- 1. Types
PROMPT Creating Object Types...
@@types/T_CSS_STYLE.sql
@@types/T_HTML_ELEMENT.sql
@@types/T_TABLE_CELL.sql
@@types/T_FORM_FIELD.sql

-- 2. Tables
PROMPT Creating Tables...
@@tables/FPDF_HTML_ELEMENTS.sql
@@tables/FPDF_CSS_RULES.sql
@@tables/FPDF_TEMPLATES.sql
@@tables/FPDF_TAG_MAPPINGS.sql
@@tables/FPDF_FORM_FIELDS.sql
@@tables/FPDF_BOOKMARKS.sql
@@tables/FPDF_LINKS.sql

-- 3. Load default data
PROMPT Loading Default Data...
@@data/tag_mappings.sql
@@data/default_templates.sql

-- 4. Packages
PROMPT Creating Packages...
@@packages/PL_FPDF_HTML.pks
@@packages/PL_FPDF_HTML.pkb
@@packages/PL_FPDF_FORM.pks
@@packages/PL_FPDF_FORM.pkb
@@packages/PL_FPDF_NAV.pks
@@packages/PL_FPDF_NAV.pkb

-- 5. Update main PL_FPDF to use extensions
PROMPT Updating PL_FPDF API...
@@packages/PL_FPDF_EXT.pks
@@packages/PL_FPDF_EXT.pkb

PROMPT ================================================================================
PROMPT Installation Complete!
PROMPT
PROMPT New functions available:
PROMPT   - PL_FPDF.HTMLToPDF(html, options)
PROMPT   - PL_FPDF.RenderTemplate(name, data)
PROMPT   - PL_FPDF.AddBookmark(title, page)
PROMPT   - PL_FPDF.AddTextField(name, x, y, w, h)
PROMPT   - PL_FPDF.AddCheckbox(name, x, y)
PROMPT   - PL_FPDF.AddDropdown(name, x, y, w, h, options)
PROMPT ================================================================================
```

---

## 7. Exemplos de Uso

### HTML to PDF

```sql
DECLARE
  l_pdf BLOB;
BEGIN
  -- Simple conversion
  l_pdf := PL_FPDF.HTMLToPDF('
    <h1>Relatorio Mensal</h1>
    <p>Este e o relatorio do mes de marco.</p>
    <table>
      <tr><th>Produto</th><th>Vendas</th></tr>
      <tr><td>Widget A</td><td>150</td></tr>
      <tr><td>Widget B</td><td>230</td></tr>
    </table>
  ');

  -- Save to table
  INSERT INTO documents (name, content) VALUES ('report.pdf', l_pdf);
END;
```

### Template

```sql
DECLARE
  l_pdf  BLOB;
  l_data JSON_OBJECT_T := JSON_OBJECT_T();
  l_items JSON_ARRAY_T := JSON_ARRAY_T();
BEGIN
  -- Build data
  l_data.put('invoice_number', 'INV-2026-001');
  l_data.put('customer_name', 'Empresa ABC Ltda');
  l_data.put('invoice_date', TO_CHAR(SYSDATE, 'DD/MM/YYYY'));

  -- Add items
  l_items.append(JSON_OBJECT_T('{"description":"Consultoria","quantity":10,"unit_price":"150.00","line_total":"1500.00"}'));
  l_items.append(JSON_OBJECT_T('{"description":"Desenvolvimento","quantity":40,"unit_price":"120.00","line_total":"4800.00"}'));
  l_data.put('items', l_items);
  l_data.put('total', 'R$ 6.300,00');

  -- Render
  l_pdf := PL_FPDF.RenderTemplate('invoice_simple', l_data);
END;
```

### Forms

```sql
BEGIN
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage();

  -- Title
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Formulario de Cadastro', '0', 1, 'C');

  -- Begin form
  PL_FPDF.BeginForm();

  -- Text fields
  PL_FPDF.SetFont('Arial', '', 10);
  PL_FPDF.Text(10, 30, 'Nome:');
  PL_FPDF.AddTextField('nome', 40, 25, 100, 8, p_required => TRUE);

  PL_FPDF.Text(10, 45, 'Email:');
  PL_FPDF.AddTextField('email', 40, 40, 100, 8);

  -- Checkbox
  PL_FPDF.Text(10, 60, 'Aceito os termos:');
  PL_FPDF.AddCheckbox('aceito', 60, 56);

  -- Dropdown
  PL_FPDF.Text(10, 75, 'Estado:');
  PL_FPDF.AddDropdown('estado', 40, 70, 50, 8,
    JSON_ARRAY_T('[
      {"value":"SP","label":"Sao Paulo"},
      {"value":"RJ","label":"Rio de Janeiro"},
      {"value":"MG","label":"Minas Gerais"}
    ]'),
    'SP'
  );

  -- End form
  PL_FPDF.EndForm();

  -- Save
  l_pdf := PL_FPDF.OutputBlob();
END;
```

### Bookmarks

```sql
BEGIN
  PL_FPDF.Init();

  -- Chapter 1
  PL_FPDF.AddPage();
  PL_FPDF.AddBookmark('Capitulo 1 - Introducao');
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Capitulo 1 - Introducao');

  -- Section 1.1
  PL_FPDF.Ln(15);
  PL_FPDF.AddBookmark('1.1 Objetivo', p_parent => 'Capitulo 1 - Introducao');
  PL_FPDF.SetFont('Arial', 'B', 12);
  PL_FPDF.Cell(0, 10, '1.1 Objetivo');

  -- Chapter 2
  PL_FPDF.AddPage();
  PL_FPDF.AddBookmark('Capitulo 2 - Desenvolvimento');
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'Capitulo 2 - Desenvolvimento');

  l_pdf := PL_FPDF.OutputBlob();
END;
```

---

## Beneficios desta Arquitetura

| Aspecto | Package-Only | Esta Arquitetura |
|---------|-------------|------------------|
| Parsing HTML | Complexo em memoria | Tabela + recursao SQL |
| Layout calculation | Manual, propenso a erros | SQL hierarchical queries |
| Templates | Nao suportado | Persistentes, reutilizaveis |
| Forms | Nao suportado | Estrutura clara em tabela |
| Bookmarks | Manual | Automatico com hierarquia |
| Debug | Dificil | Query nas tabelas |
| Cache | Sessao apenas | Persistente + sessao |
| Extensibilidade | Modificar package | Adicionar registros |
