.org 0x20

.global INTERRUPCAO_HANDLER

# CORRIGIDO: Variáveis movidas para cá (interrupcoes.s compilado primeiro)
.equ TIMER_BASE,	0x10002000
.equ SW_BASE,		0x10000040
.equ LED_BASE,         0x10000000

# O VETOR DE EXCEÇÕES FOI MOVIDO PARA O ARQUIVO 'vetores.s'
# Este arquivo agora contém apenas a lógica da ISR e variáveis.

# Rotina de tratamento de exceções - VERSÃO ULTRA-RÁPIDA
INTERRUPCAO_HANDLER:
    # ✅ CONTEXTO MÍNIMO para máxima velocidade (compatível com UART)
    subi    sp, sp, 20
    stw     ra, 0(sp)
    stw     r8, 4(sp)
    stw     r9, 8(sp)
    stw     ea, 12(sp)
    rdctl   r8, estatus
    stw     r8, 16(sp)

    # ✅ ISR ULTRA-RÁPIDA - Usa apenas r8 e r9 para máxima velocidade
    rdctl   r8, ipending
    beq     r8, r0, REABILITAR_INTERRUPCOES

    # É interrupção de HW - ajusta ea
    subi    ea, ea, 4

    # Verifica se é timer (IRQ0) - apenas bit 0
    andi    r9, r8, 1
    beq     r9, r0, REABILITAR_INTERRUPCOES
    
    # TIMER ISR INLINE - ULTRA-MINIMALISTA
    movia   r8, TIMER_BASE
    movi    r9, 1
    stwio   r9, 0(r8)                # Limpa flag TO
    
    # Verifica se animação está ativa (rápido)
    movia   r8, FLAG_INTERRUPCAO
    ldw     r9, (r8)
    beq     r9, r0, REABILITAR_INTERRUPCOES  # Se não há animação, sai
    
    # ANIMAÇÃO ULTRA-RÁPIDA - apenas r8 e r9
    movia   r8, ANIMATION_STATE
    ldw     r9, (r8)                 # Estado atual
    
    # Movimento simples - sempre esquerda->direita por velocidade
    slli    r9, r9, 1               # Move para próximo LED
    
    # Verifica overflow (passou do LED 17)
    movia   r8, 0x40000             # 2^18 = limite
    blt     r9, r8, UPDATE_LEDS_FAST
    movi    r9, 1                   # Reset no LED 0
    
UPDATE_LEDS_FAST:
    # ✅ ULTRA-RÁPIDO: Salva estado e atualiza LEDs
    movia   r8, ANIMATION_STATE     # Recarrega endereço
    stw     r9, (r8)                # Salva novo estado
    movia   r8, LED_BASE            
    stwio   r9, (r8)                # Atualiza LEDs
    
    # ✅ CRÍTICO: Re-habilita interrupções (PIE=1)
    movi    r9, 1
    wrctl   status, r9              
    br      END_HANDLER

REABILITAR_INTERRUPCOES:
    # ✅ NÃO re-habilita interrupções se animação não está ativa
    # Isso evita interrupções residuais do timer
    # As interrupções serão re-habilitadas apenas quando a animação iniciar novamente

END_HANDLER:
    # ✅ RESTAURA CONTEXTO MÍNIMO - Ultra-rápido
    ldw     r8, 16(sp)
    wrctl   estatus, r8
    ldw     ea, 12(sp)
    ldw     r9, 8(sp)
    ldw     r8, 4(sp)
    ldw     ra, 0(sp)
    addi    sp, sp, 20

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
