--------------------------------------------------------------------------------
-- PL_FPDF v2.0.0 - Executar Todas as Validações
-- Este script executa todos os testes de validação das 3 fases
--------------------------------------------------------------------------------

PROMPT ========================================================================
PROMPT PL_FPDF v2.0.0 - Suite Completa de Validação
PROMPT ========================================================================
PROMPT

-- Configurar ambiente
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT Fase 1: Refatoração Crítica (18 testes)
PROMPT ========================================================================
@@tests/validate_phase_1.sql

PROMPT
PROMPT

PROMPT Fase 2: Segurança e Robustez (20 testes)  
PROMPT ========================================================================
@@tests/validate_phase_2.sql

PROMPT
PROMPT

PROMPT Fase 3: Modernização Avançada (21 testes)
PROMPT ========================================================================
@@tests/validate_phase_3.sql

PROMPT
PROMPT
PROMPT ========================================================================
PROMPT VALIDAÇÃO COMPLETA
PROMPT ========================================================================
PROMPT Total de Testes: 59 (18 + 20 + 21)
PROMPT 
PROMPT Se todos os testes mostrarem [PASS], o PL_FPDF v2.0.0 está funcionando
PROMPT perfeitamente e pronto para uso em produção!
PROMPT ========================================================================
PROMPT

