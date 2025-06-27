.global _animacao

# Referências para símbolos globais
.extern FLAG_INTERRUPCAO      # Definido em interrupcoes.s
.extern ANIMATION_STATE       # Definido em interrupcoes.s  
.extern LED_STATE             # Definido em main.s

.equ LED_BASE,         0x10000000
.equ SW_BASE,          0x10000040
.equ TIMER_BASE,       0x10002000

_animacao:
    # ✅ CORREÇÃO: Salva o endereço de retorno na pilha
    # _animacao é uma função "não-folha" (chama outras funções),
    # então precisa salvar 'ra' antes de fazer um 'call'.
    subi        sp, sp, 4
    stw         ra, 0(sp)

    # O registrador r9 ainda aponta para a string de comando.
    # Avança para o segundo caractere (a sub-opção '0' ou '1').
    addi        r9, r9, 1
    ldb         r10, (r9)       # r10 = sub-opção

    # Compara a sub-opção com '0' (ASCII 0x30).
    movi        r11, '0'
    beq         r10, r11, INICIAR_ANIMACAO

    # Se não for '0', assume que é para parar.
PARAR_ANIMACAO:
    # Para o timer de forma ROBUSTA
    call        PARAR_TIMER_SIMPLES
    
    # Zera a flag de interrupção
    movia       r10, FLAG_INTERRUPCAO
    stw         r0, (r10)

    # Restaura o estado anterior dos LEDs
    movia       r10, LED_STATE
    ldw         r11, (r10)
    movia       r12, LED_BASE
    stwio       r11, (r12)

    # Reseta o estado da animação
    movia       r10, ANIMATION_STATE
    stw         r0, (r10)
    br          FIM_ANIMACAO

INICIAR_ANIMACAO:
    # Salva o estado atual dos LEDs
    movia       r10, LED_BASE
    ldwio       r11, (r10)
    movia       r12, LED_STATE
    stw         r11, (r12)
    
    # Define posição inicial baseada na direção do SW0
    movia       r10, SW_BASE
    ldwio       r11, (r10)
    andi        r11, r11, 1        # Isola SW0
    
    movia       r10, ANIMATION_STATE
    beq         r11, r0, INIT_LEFT_RIGHT
    
INIT_RIGHT_LEFT:
    # SW0=1: Inicia da direita (LED 17)
    movia       r11, 0x20000      # LED 17 = 2^17
    br          SAVE_INITIAL
    
INIT_LEFT_RIGHT:
    # SW0=0: Inicia da esquerda (LED 0)
    movi        r11, 1            # LED 0 = 2^0

SAVE_INITIAL:
    stw         r11, (r10)        # Salva estado inicial
    movia       r12, LED_BASE
    stwio       r11, (r12)        # Acende LED inicial

    # Configura timer SIMPLES
    call        INICIAR_TIMER_SIMPLES
    
    # Ativa animação
    movia       r10, FLAG_INTERRUPCAO
    movi        r11, 1
    stw         r11, (r10)

FIM_ANIMACAO:
    # ✅ CORREÇÃO: Restaura o endereço de retorno da pilha
    # Agora 'ret' vai pular de volta para o 'main.s' corretamente.
    ldw         ra, 0(sp)
    addi        sp, sp, 4
    ret

#========================================================================================================================================
# Timer ULTRA-SIMPLES - Sem conflitos
#========================================================================================================================================
INICIAR_TIMER_SIMPLES:
    movia       r8, TIMER_BASE
    
    # Para timer primeiro
    stwio       r0, 4(r8)
    
    # Período conforme PDF: 200ms (10M ciclos em 50MHz)
    # Bits baixos
    movia       r9, 10000000
    andi        r10, r9, 0xFFFF
    stwio       r10, 8(r8)
    
    # Bits altos
    srli        r9, r9, 16
    stwio       r9, 12(r8)
    
    # Limpa flag pendente
    movi        r9, 1
    stwio       r9, 0(r8)
    
    # Habilita interrupções mínimas
    movi        r9, 1
    wrctl       ienable, r9
    wrctl       status, r9
    
    # Inicia timer: START=1, CONT=1, ITO=1
    movi        r9, 7
    stwio       r9, 4(r8)
    ret

PARAR_TIMER_SIMPLES:
    movia       r8, TIMER_BASE
    
    # Para timer completamente PRIMEIRO
    stwio       r0, 4(r8)
    
    # Limpa flag TO após parar
    movi        r9, 1
    stwio       r9, 0(r8)
    
    # ✅ CRÍTICO: Desabilita interrupções do timer (IRQ0)
    wrctl       ienable, r0         # Zera ienable (desabilita todas as IRQs)
    
    # Desabilita interrupções globais para garantir parada total
    wrctl       status, r0          # Zera PIE bit
    ret
