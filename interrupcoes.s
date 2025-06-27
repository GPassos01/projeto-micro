#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: interrupcoes.s
# Descrição: Sistema de Interrupções e Variáveis Globais
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
#========================================================================================================================================

.org 0x20

.global INTERRUPCAO_HANDLER
.global TIMER_TICK_FLAG
.global CRONOMETRO_TICK_FLAG

#========================================================================================================================================
# Definições e Constantes
#========================================================================================================================================
.equ TIMER_BASE,        0x10002000
.equ SW_BASE,           0x10000040
.equ LED_BASE,          0x10000000
.equ KEY_BASE,          0x10000050

#========================================================================================================================================
# ROTINA DE TRATAMENTO DE INTERRUPÇÕES (VERSÃO FINAL E ROBUSTA)
INTERRUPCAO_HANDLER:
    # --- Prólogo Mínimo e Rápido ---
    # Salva apenas os registradores que serão modificados nesta ISR
    subi sp, sp, 12
    stw  ra, 8(sp)
    stw  r8, 4(sp)
    stw  r9, 0(sp)
    
    # --- Lógica Principal da ISR ---

    # 1. Limpa a interrupção de hardware IMEDIATAMENTE.
    # Esta é a operação mais crítica. Escreve 1 no bit TO (timeout) do
    # registrador de status do timer para zerá-lo.
    movia r8, TIMER_BASE
    movi  r9, 1
    stwio r9, 0(r8) 

    # 2. Sinaliza para o main loop que um tick ocorreu.
    # Apenas a flag genérica é necessária, o main loop sabe o que fazer.
    movia r8, TIMER_TICK_FLAG
    stw   r9, (r8)
    
    # 3. Decrementa o Endereço da Exceção para retornar ao fluxo correto.
    subi ea, ea, 4
    
    # --- Epílogo Mínimo ---
    ldw  r9, 0(sp)
    ldw  r8, 4(sp)
    ldw  ra, 8(sp)
    addi sp, sp, 12
    eret

#========================================================================================================================================
# SEÇÃO DE DADOS - Variáveis Globais
# Todas as variáveis alinhadas adequadamente conforme ABI
#========================================================================================================================================
.section .data
.align 4

# Flag para comunicação entre ISR e código principal (animação)
.global TIMER_TICK_FLAG
TIMER_TICK_FLAG:
    .word 0

# Flag para comunicação entre ISR e código principal (cronômetro)  
.global CRONOMETRO_TICK_FLAG
CRONOMETRO_TICK_FLAG:
    .word 0

# Estado da animação dos LEDs
.global ANIMATION_STATE
ANIMATION_STATE:
    .word 0

# Flag geral de interrupção ativa
.global FLAG_INTERRUPCAO
FLAG_INTERRUPCAO:
    .word 0

# Estados do cronômetro
.global CRONOMETRO_SEGUNDOS
CRONOMETRO_SEGUNDOS:
    .word 0

.global CRONOMETRO_PAUSADO
CRONOMETRO_PAUSADO:
    .word 0

.global CRONOMETRO_ATIVO
CRONOMETRO_ATIVO:
    .word 0
