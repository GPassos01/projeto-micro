.set noat

.global INTERRUPCAO_HANDLER

# CORRIGIDO: Variáveis movidas para cá (interrupcoes.s compilado primeiro)
.equ TIMER_BASE,	0x10002000
.equ SW_BASE,		0x10000040
.equ LED_BASE,         0x10000000

#========================================================================================================================================
# Vetor de Exceções - CORRIGIDO: Agora no mesmo arquivo da ISR
#========================================================================================================================================
.section .exceptions.entry, "xa"
.org 0x20
EXCEPTION_ENTRY:
    # Salto direto para o handler (sem br adicional)
    br      INTERRUPCAO_HANDLER

# Retorna à seção de texto
.section .text

# Rotina de tratamento de exceções - VERSÃO MINIMALISTA E ROBUSTA
INTERRUPCAO_HANDLER:
    # Salva APENAS registradores essenciais - Intel Best Practice
    subi    sp, sp, 32
    stw     ra, 0(sp)
    stw     r8, 4(sp)
    stw     r9, 8(sp)
    stw     r10, 12(sp)
    stw     r11, 16(sp)
    stw     r12, 20(sp)
    stw     ea, 24(sp)
    rdctl   r12, estatus
    stw     r12, 28(sp)

    # Verifica se é interrupção de hardware
    rdctl   r8, ipending
    beq     r8, r0, OTHER_EXCEPTIONS

    # É interrupção de HW - ajusta ea
    subi    ea, ea, 4

    # Verifica se é timer (IRQ0)
    andi    r9, r8, 1
    beq     r9, r0, OTHER_INTERRUPTS
    
    # TIMER ISR INLINE - MINIMALISTA
    movia   r8, TIMER_BASE
    movi    r9, 1
    stwio   r9, 0(r8)                # Limpa flag TO - UMA VEZ APENAS!
    
    # Verifica se animação está ativa
    movia   r8, FLAG_INTERRUPCAO
    ldw     r9, (r8)
    movi    r10, 1
    bne     r9, r10, END_HANDLER     # Se não for animação, sai
    
    # ANIMAÇÃO MINIMALISTA
    movia   r8, ANIMATION_STATE
    ldw     r9, (r8)                 # Estado atual
    
    # Lê direção do SW0
    movia   r10, SW_BASE
    ldwio   r11, (r10)
    andi    r11, r11, 1
    
    # Movimento baseado na direção
    beq     r11, r0, MOVE_LEFT_RIGHT
    
MOVE_RIGHT_LEFT:
    srli    r9, r9, 1               # Direita->Esquerda
    bne     r9, r0, UPDATE_LEDS
    movia   r9, 0x20000             # Reset no LED 17
    br      UPDATE_LEDS
    
MOVE_LEFT_RIGHT:
    slli    r9, r9, 1               # Esquerda->Direita  
    movia   r10, 0x40000
    bne     r9, r10, UPDATE_LEDS
    movi    r9, 1                   # Reset no LED 0
    
UPDATE_LEDS:
    stw     r9, (r8)                # Salva novo estado
    movia   r12, LED_BASE           # ✅ USA r12, não sobrescreve r8!
    stwio   r9, (r12)               # Atualiza LEDs
    br      END_HANDLER

OTHER_INTERRUPTS:
OTHER_EXCEPTIONS:
    # Tratamento mínimo para outras exceções

END_HANDLER:
    # Restaura contexto
    ldw     r12, 28(sp)
    wrctl   estatus, r12
    ldw     ea, 24(sp)
    ldw     r12, 20(sp)
    ldw     r11, 16(sp)
    ldw     r10, 12(sp)
    ldw     r9, 8(sp)
    ldw     r8, 4(sp)
    ldw     ra, 0(sp)
    addi    sp, sp, 32

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
    .word 0
