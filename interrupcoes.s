#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: interrupcoes.s
# Descrição: Sistema de Interrupções e Variáveis Globais
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
#========================================================================================================================================

.set noat                               # CRÍTICO: Impede uso automático de r1 (at)

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
# ROTINA DE TRATAMENTO DE INTERRUPÇÕES (VERSÃO FINAL E 100% SEGURA)
INTERRUPCAO_HANDLER:
    # --- Prólogo Completo e Seguro ---
    # Salva TODOS os registradores temporários que podem ser usados pela ISR
    # para garantir que o estado do programa principal NUNCA seja corrompido.
    subi sp, sp, 20
    stw  ra, 16(sp)              # Endereço de Retorno
    stw  r8, 12(sp)              # Temporários
    stw  r9, 8(sp)
    stw  r10, 4(sp)
    rdctl r10, estatus           # Registrador de Status
    stw  r10, 0(sp)
    
    # Decrementa o Endereço da Exceção para retornar ao fluxo correto
    subi ea, ea, 4

    # --- Lógica Principal da ISR ---

    # 1. Limpa a interrupção no hardware IMEDIATAMENTE.
    movia r8, TIMER_BASE
    movi  r9, 1
    stwio r9, 0(r8) 

    # 2. Sinaliza para o main loop que um tick ocorreu.
    movia r8, TIMER_TICK_FLAG
    stw   r9, (r8)
    
    # --- Epílogo Completo e Seguro ---
    # Restaura TODOS os registradores na ordem inversa
    ldw  r10, 0(sp)
    wrctl estatus, r10           # Restaura o status do processador
    ldw  r10, 4(sp)
    ldw  r9, 8(sp)
    ldw  r8, 12(sp)
    ldw  ra, 16(sp)
    addi sp, sp, 20
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
