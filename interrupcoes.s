.org 0x20

.global INTERRUPCAO_HANDLER
.global TIMER_TICK_FLAG

# CORRIGIDO: Variáveis movidas para cá (interrupcoes.s compilado primeiro)
.equ TIMER_BASE,	0x10002000
.equ SW_BASE,		0x10000040
.equ LED_BASE,         0x10000000

# O VETOR DE EXCEÇÕES FOI MOVIDO PARA O ARQUIVO 'vetores.s'
# Este arquivo agora contém apenas a lógica da ISR e variáveis.

# Rotina de tratamento de exceções - VERSÃO MÍNIMA E SEGURA
INTERRUPCAO_HANDLER:
    # --- Prólogo ---
    # Salva apenas o contexto mínimo necessário para esta ISR.
    subi    sp, sp, 16
    stw     ra, 0(sp)
    stw     r8, 4(sp)
    stw     r9, 8(sp)
    rdctl   r8, estatus
    stw     r8, 12(sp)

    # Apenas para interrupções de hardware, decrementa 'ea'
    subi    ea, ea, 4

    # --- Lógica da ISR ---
    # 1. Limpa a flag de interrupção do timer
    movia   r8, TIMER_BASE
    movi    r9, 1
    stwio   r9, 0(r8)

    # 2. Sinaliza para o main loop que um "tick" do timer ocorreu
    movia   r8, TIMER_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)
    
    # --- Epílogo ---
    # Restaura o contexto e retorna
    ldw     r8, 12(sp)
    wrctl   estatus, r8
    ldw     r9, 8(sp)
    ldw     r8, 4(sp)
    ldw     ra, 0(sp)
    addi    sp, sp, 16
    eret

#========================================================================================================================================
# Variáveis Globais - MOVIDAS para cá (primeiro arquivo compilado)
#========================================================================================================================================
.section .data
.align 4

# Flag para comunicação entre ISR e código principal
.global FLAG_INTERRUPCAO
FLAG_INTERRUPCAO:
    .word 0

# Estado da animação dos LEDs
.global ANIMATION_STATE
ANIMATION_STATE:
    .word 1

# Nova flag para comunicação entre ISR e Main Loop
.global TIMER_TICK_FLAG
TIMER_TICK_FLAG:
    .word 0
