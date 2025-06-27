.org 0x20

.global INTERRUPCAO_HANDLER

# CORRIGIDO: Variáveis movidas para cá (interrupcoes.s compilado primeiro)
.equ TIMER_BASE,	0x10002000
.equ SW_BASE,		0x10000040
.equ LED_BASE,         0x10000000

# O VETOR DE EXCEÇÕES FOI MOVIDO PARA O ARQUIVO 'vetores.s'
# Este arquivo agora contém apenas a lógica da ISR e variáveis.

# Rotina de tratamento de exceções - VERSÃO CORRIGIDA E ROBUSTA
INTERRUPCAO_HANDLER:
    # ✅ CONTEXTO CORRIGIDO: Salva r8-r12 para proteger contra `movia`
    subi    sp, sp, 32
    stw     ra, 0(sp)
    stw     r8, 4(sp)
    stw     r9, 8(sp)
    stw     r10, 12(sp)
    stw     r11, 16(sp)
    stw     r12, 20(sp)
    rdctl   r8, estatus
    stw     r8, 24(sp)
    # NÃO salvamos EA, ele será modificado diretamente.

    # É interrupção de HW, ajusta ea para retornar à instrução correta
    subi    ea, ea, 4

    # --- Início da lógica da ISR ---
    
    # Verifica se é timer (IRQ0)
    rdctl   r8, ipending
    andi    r9, r8, 1
    beq     r9, r0, END_HANDLER      # Se não for timer, apenas sai
    
    # É timer! Limpa flag TO - UMA VEZ APENAS!
    movia   r8, TIMER_BASE
    movi    r9, 1
    stwio   r9, 0(r8)
    
    # Verifica se animação está ativa
    movia   r8, FLAG_INTERRUPCAO
    ldw     r9, (r8)
    movi    r10, 1
    bne     r9, r10, END_HANDLER     # Se não for animação, sai
    
    # ANIMAÇÃO COM DIREÇÃO SW0
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
    movia   r12, LED_BASE
    stwio   r9, (r12)               # Atualiza LEDs
    
END_HANDLER:
    # ✅ CRÍTICO: Re-habilita interrupções ANTES de sair
    movi    r9, 1
    wrctl   status, r9

    # ✅ Restaura contexto CORRIGIDO
    ldw     r8, 24(sp)
    wrctl   estatus, r8
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
    .word 1  # ✅ CORREÇÃO: Inicia com LED 0 aceso
