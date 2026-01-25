# Phase 4.5 Implementation Plan - Text & Image Overlay
# Plano de Implementação Fase 4.5 - Sobreposição de Texto e Imagem

**Version / Versão:** 3.0.0-a.6 (Phase 4.5)
**Status:** Planning / Planejamento 📋
**Start Date / Data Início:** 2026-01-25

[🇬🇧 English](#english) | [🇧🇷 Português](#português)

---

## English

### 🎯 Phase 4.5 Overview

Phase 4.5 extends Phase 4 with precise text and image overlay capabilities, enabling users to:
- **Add text overlays** at specific coordinates with full formatting control
- **Add image overlays** at specific positions with sizing and transparency
- **Layer content** on existing PDF pages without modifying original content
- **Position control** with precise x, y, width, height parameters
- **Multiple overlays** per page with z-order management

This phase bridges the gap between basic watermarks (Phase 4.3) and advanced content manipulation.

### ✨ Key Features

| Feature | Description | API |
|---------|-------------|-----|
| **Text Overlay** | Add formatted text at specific position | `OverlayText()` |
| **Image Overlay** | Add image (JPEG/PNG) at specific position | `OverlayImage()` |
| **Positioning** | Precise x, y coordinates in PDF units | All overlay APIs |
| **Sizing** | Control width, height, scaling | All overlay APIs |
| **Transparency** | Opacity control for overlays | All overlay APIs |
| **Layering** | Multiple overlays per page | All overlay APIs |

### 🏗️ Architecture

Phase 4.5 builds on Phase 4's PDF manipulation infrastructure:

```
Phase 4 Foundation:
├── LoadPDF() - Load and parse PDF
├── GetPageInfo() - Extract page details
├── AddWatermark() - Basic watermark support
└── OutputModifiedPDF() - Generate modified PDF

Phase 4.5 Extensions:
├── Precise positioning system (x, y coordinates)
├── Content stream manipulation
├── Graphics state management (opacity, transformations)
├── Image embedding and scaling
└── Text rendering with font control
```

### 📋 Implementation Details

#### **New Global Structures:**

```sql
-- Overlay type definition
TYPE t_overlay IS RECORD (
  overlay_id     VARCHAR2(50),      -- Unique overlay ID
  overlay_type   VARCHAR2(20),      -- 'TEXT' or 'IMAGE'
  page_number    PLS_INTEGER,       -- Target page
  x              NUMBER,             -- X position (PDF units)
  y              NUMBER,             -- Y position (PDF units)
  width          NUMBER,             -- Width (NULL = auto)
  height         NUMBER,             -- Height (NULL = auto)
  content        CLOB,               -- Text content or image reference
  opacity        NUMBER,             -- 0.0 to 1.0
  rotation       NUMBER,             -- Rotation angle
  font_name      VARCHAR2(100),     -- For text overlays
  font_size      NUMBER,            -- For text overlays
  color          VARCHAR2(50),      -- Color specification
  z_order        PLS_INTEGER,       -- Layer order (higher = on top)
  created_date   TIMESTAMP          -- Creation timestamp
);

TYPE t_overlays IS TABLE OF t_overlay INDEX BY VARCHAR2(50);
g_overlays t_overlays;  -- Global overlay cache
```

#### **Coordinate System:**

PDF uses bottom-left origin (0,0):
```
Top-Left (0, page_height)     Top-Right (page_width, page_height)
        +-----------------------------+
        |                             |
        |         PDF Page            |
        |                             |
        |      (x, y)                 |
        |        +----+               |
        |        |    | overlay       |
        |        +----+               |
        +-----------------------------+
Bottom-Left (0, 0)            Bottom-Right (page_width, 0)
```

---

### 📝 Phase 4.5 API Specification

#### **OverlayText() - Add Text at Specific Position**

```sql
/*******************************************************************************
* Procedure: OverlayText / Sobrepor Texto
*
* Description / Descrição:
*   EN: Add text overlay at specific position on PDF page with full formatting
*   PT: Adicionar sobreposição de texto em posição específica com formatação completa
*
* Parameters / Parâmetros:
*   p_page_number - Page number (1-based) / Número da página (base 1)
*   p_text - Text content / Conteúdo do texto
*   p_x - X position in PDF units (points, 1 point = 1/72 inch) / Posição X
*   p_y - Y position in PDF units (from bottom) / Posição Y (de baixo)
*   p_options - JSON configuration (optional) / Configuração JSON (opcional)
*
* Options (JSON_OBJECT_T) / Opções:
*   {
*     "font": "Helvetica",           // Font name / Nome da fonte
*     "fontSize": 12,                // Font size in points / Tamanho da fonte
*     "color": "000000",             // RGB hex color / Cor RGB hexadecimal
*     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
*     "rotation": 0,                 // Rotation angle / Ângulo de rotação
*     "align": "left",               // left, center, right / esquerda, centro, direita
*     "width": null,                 // Max width (auto-wrap) / Largura máxima
*     "bold": false,                 // Bold text / Texto em negrito
*     "italic": false,               // Italic text / Texto em itálico
*     "underline": false,            // Underline text / Texto sublinhado
*     "zOrder": 100                  // Layer order / Ordem da camada
*   }
*
* Raises / Erros:
*   -20809: No PDF loaded / Nenhum PDF carregado
*   -20810: Invalid page number / Número de página inválido
*   -20821: Invalid position coordinates / Coordenadas de posição inválidas
*   -20822: Invalid font specification / Especificação de fonte inválida
*
* Example / Exemplo:
*   DECLARE
*     l_options JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     PL_FPDF.LoadPDF(l_pdf);
*
*     -- Simple text overlay / Sobreposição simples
*     PL_FPDF.OverlayText(1, 'APPROVED', 100, 700, NULL);
*
*     -- Formatted text / Texto formatado
*     l_options.put('font', 'Helvetica');
*     l_options.put('fontSize', 24);
*     l_options.put('color', 'FF0000');  -- Red / Vermelho
*     l_options.put('opacity', 0.8);
*     l_options.put('rotation', 45);
*     l_options.put('bold', TRUE);
*     PL_FPDF.OverlayText(1, 'CONFIDENTIAL', 200, 400, l_options);
*
*     -- Generate modified PDF / Gerar PDF modificado
*     l_result := PL_FPDF.OutputModifiedPDF();
*   END;
*******************************************************************************/
PROCEDURE OverlayText(
  p_page_number IN PLS_INTEGER,
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);
```

#### **OverlayImage() - Add Image at Specific Position**

```sql
/*******************************************************************************
* Procedure: OverlayImage / Sobrepor Imagem
*
* Description / Descrição:
*   EN: Add image overlay at specific position on PDF page with sizing control
*   PT: Adicionar sobreposição de imagem em posição específica com controle de tamanho
*
* Parameters / Parâmetros:
*   p_page_number - Page number (1-based) / Número da página (base 1)
*   p_image_blob - Image data (JPEG or PNG) / Dados da imagem (JPEG ou PNG)
*   p_x - X position in PDF units / Posição X em unidades PDF
*   p_y - Y position in PDF units (from bottom) / Posição Y (de baixo)
*   p_width - Image width in PDF units (NULL = original) / Largura da imagem
*   p_height - Image height in PDF units (NULL = original) / Altura da imagem
*   p_options - JSON configuration (optional) / Configuração JSON (opcional)
*
* Options (JSON_OBJECT_T) / Opções:
*   {
*     "opacity": 1.0,                // 0.0 to 1.0 / Opacidade 0.0 a 1.0
*     "rotation": 0,                 // Rotation angle / Ângulo de rotação
*     "maintainAspect": true,        // Keep aspect ratio / Manter proporção
*     "scaleToFit": false,           // Scale to fit in width/height / Escalar para caber
*     "zOrder": 100                  // Layer order / Ordem da camada
*   }
*
* Raises / Erros:
*   -20809: No PDF loaded / Nenhum PDF carregado
*   -20810: Invalid page number / Número de página inválido
*   -20821: Invalid position coordinates / Coordenadas de posição inválidas
*   -20823: Invalid image format / Formato de imagem inválido
*   -20824: Image dimensions invalid / Dimensões da imagem inválidas
*
* Example / Exemplo:
*   DECLARE
*     l_logo BLOB;
*     l_options JSON_OBJECT_T := JSON_OBJECT_T();
*   BEGIN
*     -- Load logo / Carregar logo
*     SELECT logo_blob INTO l_logo FROM company_assets WHERE id = 1;
*
*     PL_FPDF.LoadPDF(l_pdf);
*
*     -- Add logo at top-right / Adicionar logo no canto superior direito
*     PL_FPDF.OverlayImage(1, l_logo, 450, 750, 100, 50, NULL);
*
*     -- Add watermark image with transparency / Adicionar marca d'água com transparência
*     l_options.put('opacity', 0.3);
*     l_options.put('rotation', 45);
*     l_options.put('maintainAspect', TRUE);
*     PL_FPDF.OverlayImage(1, l_watermark, 200, 400, 300, NULL, l_options);
*
*     -- Generate modified PDF / Gerar PDF modificado
*     l_result := PL_FPDF.OutputModifiedPDF();
*   END;
*******************************************************************************/
PROCEDURE OverlayImage(
  p_page_number IN PLS_INTEGER,
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER DEFAULT NULL,
  p_height IN NUMBER DEFAULT NULL,
  p_options IN JSON_OBJECT_T DEFAULT NULL
);
```

#### **GetOverlays() - List All Overlays**

```sql
/*******************************************************************************
* Function: GetOverlays / Obter Sobreposições
*
* Description / Descrição:
*   EN: Get list of all applied overlays as JSON array
*   PT: Obter lista de todas as sobreposições aplicadas como array JSON
*
* Parameters / Parâmetros:
*   p_page_number - Filter by page (NULL = all pages) / Filtrar por página
*
* Returns / Retorna:
*   JSON_ARRAY_T - Array of overlay objects / Array de objetos de sobreposição
*
* Example / Exemplo:
*   DECLARE
*     l_overlays JSON_ARRAY_T;
*     l_overlay JSON_OBJECT_T;
*   BEGIN
*     l_overlays := PL_FPDF.GetOverlays(1);  -- Page 1 overlays
*     FOR i IN 0..l_overlays.get_size() - 1 LOOP
*       l_overlay := TREAT(l_overlays.get(i) AS JSON_OBJECT_T);
*       DBMS_OUTPUT.PUT_LINE('Type: ' || l_overlay.get_string('overlay_type'));
*     END LOOP;
*   END;
*******************************************************************************/
FUNCTION GetOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL)
  RETURN JSON_ARRAY_T;
```

#### **RemoveOverlay() - Remove Specific Overlay**

```sql
/*******************************************************************************
* Procedure: RemoveOverlay / Remover Sobreposição
*
* Description / Descrição:
*   EN: Remove specific overlay by ID
*   PT: Remover sobreposição específica por ID
*
* Parameters / Parâmetros:
*   p_overlay_id - Overlay ID returned by GetOverlays() / ID da sobreposição
*
* Raises / Erros:
*   -20825: Overlay not found / Sobreposição não encontrada
*******************************************************************************/
PROCEDURE RemoveOverlay(p_overlay_id IN VARCHAR2);
```

#### **ClearOverlays() - Clear All Overlays**

```sql
/*******************************************************************************
* Procedure: ClearOverlays / Limpar Sobreposições
*
* Description / Descrição:
*   EN: Clear all overlays from all pages or specific page
*   PT: Limpar todas as sobreposições de todas ou de página específica
*
* Parameters / Parâmetros:
*   p_page_number - Clear overlays from page (NULL = all pages) / Limpar de página
*******************************************************************************/
PROCEDURE ClearOverlays(p_page_number IN PLS_INTEGER DEFAULT NULL);
```

---

### 🔧 Technical Implementation

#### **Text Overlay Implementation**

Text overlays require manipulating PDF content streams:

```sql
FUNCTION generate_text_overlay_stream(
  p_text IN VARCHAR2,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_font IN VARCHAR2,
  p_size IN NUMBER,
  p_color IN VARCHAR2,
  p_opacity IN NUMBER,
  p_rotation IN NUMBER
) RETURN CLOB IS
  l_stream CLOB;
BEGIN
  -- Build PDF content stream
  l_stream := 'q' || CHR(10);  -- Save graphics state

  -- Set opacity (ExtGState)
  IF p_opacity < 1.0 THEN
    l_stream := l_stream || '/GS1 gs' || CHR(10);
  END IF;

  -- Set color (RGB)
  l_stream := l_stream || parse_color(p_color) || ' rg' || CHR(10);

  -- Begin text
  l_stream := l_stream || 'BT' || CHR(10);

  -- Set font and size
  l_stream := l_stream || '/' || p_font || ' ' || p_size || ' Tf' || CHR(10);

  -- Apply rotation if needed
  IF p_rotation != 0 THEN
    l_stream := l_stream || build_rotation_matrix(p_rotation, p_x, p_y) || ' Tm' || CHR(10);
  ELSE
    l_stream := l_stream || '1 0 0 1 ' || p_x || ' ' || p_y || ' Tm' || CHR(10);
  END IF;

  -- Show text
  l_stream := l_stream || '(' || escape_pdf_string(p_text) || ') Tj' || CHR(10);

  -- End text
  l_stream := l_stream || 'ET' || CHR(10);

  l_stream := l_stream || 'Q' || CHR(10);  -- Restore graphics state

  RETURN l_stream;
END;
```

#### **Image Overlay Implementation**

Image overlays require embedding images and creating XObject references:

```sql
FUNCTION generate_image_overlay_stream(
  p_image_blob IN BLOB,
  p_x IN NUMBER,
  p_y IN NUMBER,
  p_width IN NUMBER,
  p_height IN NUMBER,
  p_opacity IN NUMBER,
  p_rotation IN NUMBER
) RETURN CLOB IS
  l_stream CLOB;
  l_image_ref VARCHAR2(50);
BEGIN
  -- Embed image and get reference
  l_image_ref := embed_image(p_image_blob);

  -- Build PDF content stream
  l_stream := 'q' || CHR(10);  -- Save graphics state

  -- Set opacity
  IF p_opacity < 1.0 THEN
    l_stream := l_stream || '/GS1 gs' || CHR(10);
  END IF;

  -- Apply transformation matrix (position, size, rotation)
  l_stream := l_stream || build_image_matrix(
    p_x, p_y, p_width, p_height, p_rotation
  ) || ' cm' || CHR(10);

  -- Draw image
  l_stream := l_stream || '/' || l_image_ref || ' Do' || CHR(10);

  l_stream := l_stream || 'Q' || CHR(10);  -- Restore graphics state

  RETURN l_stream;
END;
```

#### **Content Stream Injection**

Overlays are injected into existing page content streams:

```sql
FUNCTION inject_overlays_into_page(
  p_page_number IN PLS_INTEGER,
  p_original_content IN CLOB
) RETURN CLOB IS
  l_new_content CLOB;
  l_overlays t_overlays;
BEGIN
  -- Get overlays for page, sorted by z-order
  l_overlays := get_page_overlays_sorted(p_page_number);

  -- Start with original content
  l_new_content := p_original_content;

  -- Append each overlay stream
  FOR i IN 1..l_overlays.COUNT LOOP
    IF l_overlays(i).overlay_type = 'TEXT' THEN
      l_new_content := l_new_content || generate_text_overlay_stream(...);
    ELSIF l_overlays(i).overlay_type = 'IMAGE' THEN
      l_new_content := l_new_content || generate_image_overlay_stream(...);
    END IF;
  END LOOP;

  RETURN l_new_content;
END;
```

---

### 🧪 Testing Strategy

#### **Test Cases:**

```sql
-- tests/test_phase_4_5_overlay.sql

-- Test 1: Simple text overlay
-- Test 2: Text overlay with rotation
-- Test 3: Text overlay with opacity
-- Test 4: Text overlay with custom font
-- Test 5: Multiple text overlays on same page
-- Test 6: Simple image overlay
-- Test 7: Image overlay with scaling
-- Test 8: Image overlay with opacity
-- Test 9: Image overlay with rotation
-- Test 10: Mixed text and image overlays
-- Test 11: Overlay on multiple pages
-- Test 12: Remove specific overlay
-- Test 13: Clear all overlays
-- Test 14: GetOverlays() listing
-- Test 15: Invalid coordinates (should error)
-- Test 16: Invalid page number (should error)
-- Test 17: Invalid image format (should error)
-- Test 18: Z-order layering
```

---

### 📊 Error Codes

New error codes for Phase 4.5:

| Code | Error | Description |
|------|-------|-------------|
| -20821 | INVALID_COORDINATES | Invalid x, y position coordinates |
| -20822 | INVALID_FONT | Invalid font specification |
| -20823 | INVALID_IMAGE_FORMAT | Image must be JPEG or PNG |
| -20824 | INVALID_DIMENSIONS | Invalid width or height |
| -20825 | OVERLAY_NOT_FOUND | Overlay ID not found |
| -20826 | OVERLAY_POSITION_OUT_OF_BOUNDS | Position outside page boundaries |
| -20827 | CONTENT_STREAM_ERROR | Error manipulating content stream |

---

### 💼 Use Cases

#### **Use Case 1: Document Stamping**
```sql
-- Add "APPROVED" stamp to document
BEGIN
  PL_FPDF.LoadPDF(l_contract);

  l_options := JSON_OBJECT_T();
  l_options.put('font', 'Helvetica-Bold');
  l_options.put('fontSize', 36);
  l_options.put('color', '00AA00');
  l_options.put('opacity', 0.7);
  l_options.put('rotation', -15);

  PL_FPDF.OverlayText(1, 'APPROVED', 200, 600, l_options);
  l_result := PL_FPDF.OutputModifiedPDF();
END;
```

#### **Use Case 2: Logo Addition**
```sql
-- Add company logo to all pages
BEGIN
  PL_FPDF.LoadPDF(l_report);

  l_page_count := PL_FPDF.GetPageCount();
  FOR i IN 1..l_page_count LOOP
    PL_FPDF.OverlayImage(i, l_logo, 500, 750, 72, 36, NULL);
  END LOOP;

  l_result := PL_FPDF.OutputModifiedPDF();
END;
```

#### **Use Case 3: Dynamic Form Filling**
```sql
-- Fill form fields with data
BEGIN
  PL_FPDF.LoadPDF(l_form_template);

  -- Fill name field
  PL_FPDF.OverlayText(1, l_customer_name, 150, 700, NULL);

  -- Fill date field
  PL_FPDF.OverlayText(1, TO_CHAR(SYSDATE, 'DD/MM/YYYY'), 150, 650, NULL);

  -- Fill amount field
  PL_FPDF.OverlayText(1, TO_CHAR(l_amount, 'L999G999D99'), 150, 600, NULL);

  -- Add signature image
  PL_FPDF.OverlayImage(1, l_signature, 150, 100, 200, 50, NULL);

  l_result := PL_FPDF.OutputModifiedPDF();
END;
```

---

## Português

### 🎯 Visão Geral da Fase 4.5

A Fase 4.5 estende a Fase 4 com capacidades precisas de sobreposição de texto e imagem:
- **Adicionar sobreposições de texto** em coordenadas específicas com controle completo de formatação
- **Adicionar sobreposições de imagem** em posições específicas com dimensionamento e transparência
- **Camadas de conteúdo** em páginas PDF existentes sem modificar conteúdo original
- **Controle de posicionamento** com parâmetros precisos x, y, largura, altura
- **Múltiplas sobreposições** por página com gerenciamento de ordem Z

### 📝 APIs da Fase 4.5

1. **OverlayText()** - Adicionar texto em posição específica
2. **OverlayImage()** - Adicionar imagem em posição específica
3. **GetOverlays()** - Listar todas as sobreposições
4. **RemoveOverlay()** - Remover sobreposição específica
5. **ClearOverlays()** - Limpar todas as sobreposições

### 💼 Casos de Uso

1. **Carimbo de Documentos** - Adicionar "APROVADO" em contratos
2. **Adição de Logo** - Adicionar logo da empresa em todas as páginas
3. **Preenchimento Dinâmico de Formulários** - Preencher campos de formulário com dados

---

## 🚀 Implementation Plan

**Duration:** 3-4 days

**Tasks:**
1. ✅ Day 1: Define API specification and data structures
2. ⏳ Day 2: Implement text overlay functionality
3. ⏳ Day 3: Implement image overlay functionality
4. ⏳ Day 4: Testing, documentation, and integration

---

**Prepared by:** Claude Code
**Date:** 2026-01-25
**Target Version:** 3.0.0-a.6
