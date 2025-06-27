.global _animacao

# Referências para símbolos globais definidos em main.s
.extern FLAG_INTERRUPCAO
.extern ANIMATION_STATE

.equ LED_BASE,         0x10000000

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
    # Zera a flag de interrupção para parar de chamar a lógica da animação.
    movia       r10, FLAG_INTERRUPCAO
    stw         r0, (r10)

    # Apaga todos os LEDs.
    movia       r10, LED_BASE
    stwio       r0, (r10)

    # Reseta o estado da animação para o início.
    movia       r10, ANIMATION_STATE
    movi        r11, 1
    stw         r11, (r10)
    br          FIM_ANIMACAO

INICIAR_ANIMACAO:
    # Reseta a animação para o estado inicial (primeiro LED aceso).
    movia		r10, ANIMATION_STATE
    movi        r11, 1
    stw         r11, (r10)
    movia       r12, LED_BASE
    stwio       r11, (r12)      # Acende o primeiro LED imediatamente

    # Define a flag para 1, ativando a animação na ISR do timer.
    movia		r10, FLAG_INTERRUPCAO
    movi		r11, 1
    stw		    r11, (r10)

FIM_ANIMACAO:
    ret
