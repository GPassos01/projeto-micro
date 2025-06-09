#========================================================================================================================================
# Sistema de Animação - Nios II Assembly
# Comandos: 10 (iniciar animação), 11 (parar animação)
# Descrição: 
#   Animacao com os leds vermelhos dada pelo estado da chave SW0: 
#   se para baixo, sentido direita-esquerda; 
#   se para cima, sentido esquerda-direita. 
#   A animacao consiste em acender um led vermelho por 200ms, apaga-lo e entao acender seu vizinho
#   (direita ou esquerda, dependendo do estado da chave SW0). 
#   Este processo deve ser continuado repetidamente para todos os leds vermelhos.
#
#========================================================================================================================================

.global _animacao

# Incluir constantes do main.s
.equ LED_BASE,      0x10000000
.equ SW_BASE,       0x10000040
.equ TIMER_BASE,    0x10002000
.equ ASCII_0,       0x30

# Constantes da animação
.equ ANIM_DELAY,    200           # Delay em ms (200ms)
.equ NUM_LEDS,      18            # Número de LEDs (0-17)

# Variáveis globais da animação
.align 4
.global animation_status, led_position, animation_direction, saved_leds

animation_status:       .word 0   # 0 = parada, 1 = ativa
led_position:          .word 0    # Posição atual do LED (0-17)
animation_direction:   .word 0    # 0 = esquerda->direita, 1 = direita->esquerda
saved_leds:           .word 0     # Estado salvo dos LEDs

#========================================================================================================================================
# Função: _animacao - Controlar sistema de animação
# Parâmetros: r4 = buffer do comando ("10" para iniciar, "11" para parar)
#========================================================================================================================================

_animacao:
    # Preservar registradores (stack frame)
    addi    sp, sp, -20
    stw     ra, 16(sp)          # Retorno da função
    stw     r16, 12(sp)         # Buffer do comando
    stw     r17, 8(sp)          # Comando extraído
    stw     r18, 4(sp)          # Registrador de trabalho 1
    stw     r19, 0(sp)          # Registrador de trabalho
    
    mov     r16, r4             # r16 = buffer do comando
    
    ldw     r19, 0(sp)
    ldw     r18, 4(sp)
    ldw     r17, 8(sp)
    ldw     r16, 12(sp)
    ldw     ra, 16(sp)
    addi    sp, sp, 20
    ret