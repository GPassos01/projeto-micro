.global _animacao

# Referências para símbolos globais definidos em main.s
.extern FLAG_INTERRUPCAO
.extern ANIMATION_STATE
.extern LED_STATE

.equ LED_BASE,         0x10000000
.equ SW_BASE,          0x10000040

_animacao:
    # O registrador r9 ainda aponta para a string de comando.
    # Avança para o segundo caractere (a sub-opção '0' ou '1').
    addi        r9, r9, 1
    ldb         r10, (r9)       # r10 = sub-opção

    # Compara a sub-opção com '0' (ASCII 0x30).
    movi        r11, '0'
    beq         r10, r11, INICIAR_ANIMACAO

    # Se não for '0', assume que é para parar.
PARAR_ANIMACAO:
    # Para o timer para evitar interferência com UART
    call        PARAR_TIMER_ANIMACAO
    
    # Zera a flag de interrupção para parar de chamar a lógica da animação.
    movia       r10, FLAG_INTERRUPCAO
    stw         r0, (r10)

    # Restaura o estado anterior dos LEDs
    movia       r10, LED_STATE
    ldw         r11, (r10)
    movia       r12, LED_BASE
    stwio       r11, (r12)

    # Reseta o estado da animação para o início.
    movia       r10, ANIMATION_STATE
    stw         r0, (r10)
    br          FIM_ANIMACAO

INICIAR_ANIMACAO:
    # Salva o estado atual dos LEDs antes da animação
    movia       r10, LED_BASE
    ldwio       r11, (r10)
    movia       r12, LED_STATE
    stw         r11, (r12)
    
    # Verifica direção inicial baseada no SW0
    movia       r10, SW_BASE
    ldwio       r11, (r10)
    andi        r11, r11, 1        # Isola SW0
    
    # Define posição inicial baseada na direção
    movia       r10, ANIMATION_STATE
    beq         r11, r0, ESQUERDA_DIREITA_INIT
    
DIREITA_ESQUERDA_INIT:
    # SW0=1: Inicia da direita (LED 17)
    movia       r11, 0x20000      # LED 17 = bit 17 = 2^17
    br          SALVAR_ESTADO_INICIAL
    
ESQUERDA_DIREITA_INIT:
    # SW0=0: Inicia da esquerda (LED 0)
    movi        r11, 1            # LED 0 = bit 0 = 2^0

SALVAR_ESTADO_INICIAL:
    stw         r11, (r10)        # Salva estado inicial
    movia       r12, LED_BASE
    stwio       r11, (r12)        # Acende LED inicial

    # Inicia timer especificamente para animação
    call        INICIALIZAR_TIMER_ANIMACAO
    
    # Define a flag para 1, ativando a animação na ISR do timer.
    movia		r10, FLAG_INTERRUPCAO
    movi		r11, 1
    stw		    r11, (r10)

FIM_ANIMACAO:
    ret

#========================================================================================================================================
# Funções de Controle do Timer para Animação
#========================================================================================================================================
INICIALIZAR_TIMER_ANIMACAO:
    # Configura timer específico para animação (200ms)
    movia       r8, TIMER_BASE
    movia       r9, 10000000      # 200ms em 50MHz (10M ciclos)

    # Escreve os 16 bits inferiores do período
    andi        r10, r9, 0xFFFF
    stwio       r10, 8(r8)

    # Escreve os 16 bits superiores do período
    srli        r9, r9, 16
    stwio       r9, 12(r8)

    # Configura e inicia o timer: START=1, CONT=1, ITO=1
    movi        r9, 0b111
    stwio       r9, 4(r8)

    # Habilita interrupções
    movi        r15, 0b1
    wrctl       ienable, r15
    wrctl       status, r15
    ret

PARAR_TIMER_ANIMACAO:
    # Para o timer e desabilita interrupções
    movia       r8, TIMER_BASE
    stwio       r0, 4(r8)         # Para o timer (START=0)
    
    # Desabilita interrupções para evitar conflito com UART
    wrctl       ienable, r0
    wrctl       status, r0
    ret

.equ TIMER_BASE,    0x10002000
