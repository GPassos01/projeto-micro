.set noat

.global INTERRUPCAO_HANDLER

# Referências para símbolos globais definidos em main.s
.extern FLAG_INTERRUPCAO
.extern ANIMATION_STATE

.equ TIMER_BASE,	0x10002000
.equ SW_BASE,		0x10000040
.equ LED_BASE,         0x10000000

# Rotina de tratamento de exceções
INTERRUPCAO_HANDLER:
    # Salva o contexto dos registradores na pilha
    subi    sp, sp, 128
    stw     ra, 0(sp)
    stw     fp, 4(sp)
    stw     r1, 8(sp)
    stw     r2, 12(sp)
    stw     r3, 16(sp)
    stw     r4, 20(sp)
    stw     r5, 24(sp)
    stw     r6, 28(sp)
    stw     r7, 32(sp)
    stw     r8, 36(sp)
    stw     r9, 40(sp)
    stw     r10, 44(sp)
    stw     r11, 48(sp)
    stw     r12, 52(sp)
    stw     r13, 56(sp)
    stw     r14, 60(sp)
    stw     r15, 64(sp)
    rdctl   r16, estatus
    stw     r16, 68(sp)
    stw     ea, 72(sp)


    rdctl		et, ipending                    # Verifica se houve interrupcao externa
    beq         et, r0, OTHER_EXCEPTIONS        # Se 0, não é interrupção de HW

    # É uma interrupção de hardware, decrementa o endereço de retorno
    subi        ea, ea, 4

CHECK_TIMER:
    andi        r13, et, 1                   # Verifica se a IRQ0 (timer) está ativa
    beq         r13, r0, CHECK_BUTTON        # Se não, checa outras interrupções
    call		TIMER_ISR                    # Se sim, chama a ISR do Timer
    br          END_HANDLER                  # Finaliza o tratamento

CHECK_BUTTON:
    andi        r13, et, 2                   # Verifica se a IRQ1 (botão) está ativa
    beq         r13, r0, OTHER_INTERRUPTS    # Se não, checa outras interrupções
    call        BUTTON_ISR                   # Se sim, chama a ISR do Botão
    br          END_HANDLER                  # Finaliza o tratamento


OTHER_INTERRUPTS:
    br          END_HANDLER

OTHER_EXCEPTIONS:
    # Aqui você poderia tratar outras exceções (e.g. syscall, instrução ilegal)
    br          END_HANDLER

END_HANDLER:
    # Restaura o contexto da pilha
    ldw     r16, 68(sp)
    wrctl   estatus, r16
    ldw     ea, 72(sp)
    ldw     ra, 0(sp)
    ldw     fp, 4(sp)
    ldw     r1, 8(sp)
    ldw     r2, 12(sp)
    ldw     r3, 16(sp)
    ldw     r4, 20(sp)
    ldw     r5, 24(sp)
    ldw     r6, 28(sp)
    ldw     r7, 32(sp)
    ldw     r8, 36(sp)
    ldw     r9, 40(sp)
    ldw     r10, 44(sp)
    ldw     r11, 48(sp)
    ldw     r12, 52(sp)
    ldw     r13, 56(sp)
    ldw     r14, 60(sp)
    ldw     r15, 64(sp)
    addi    sp, sp, 128

    eret

# ISR do Timer
TIMER_ISR:
    # Limpa o flag de interrupção do timer escrevendo 1 no bit TO do registrador de status
    movia   r13, TIMER_BASE
    movi    r14, 1
    stwio   r14, 0(r13)

    # Lógica da ISR do Timer
    movia   r14, FLAG_INTERRUPCAO
    ldw		r15, (r14)
    movi    r14, 1
    beq     r15, r14, TRATAR_ANIMACAO

    movi    r14, 2
    beq     r15, r14, TRATAR_CRONOMETRO
    br      FIM_TIMER_ISR

TRATAR_ANIMACAO:
    # --- Lógica da Animação dos LEDs ---
    # r10, r11, r12: Usados para a lógica.

    # Carrega o estado atual da animação.
    movia       r10, ANIMATION_STATE
    ldw         r11, (r10)

    # 1. Verifica a direção (baseado no Switch 0)
    movia       r12, SW_BASE
    ldwio       r13, (r12)
    andi        r13, r13, 1         # Isola o bit 0 do switch
    bne         r13, r0, DIREITA_ESQUERDA


ESQUERDA_DIREITA:
    # Desloca o bit para a esquerda (efeito visual: LED move da esquerda para direita).
    slli        r11, r11, 1

    # Verifica se passou do LED 17 (0x20000 = 2^17)
    movia       r12, 0x40000       # Posição após LED17 (2^18)
    bne         r11, r12, SALVAR_ESTADO_LED
    movi        r11, 1             # Reinicia no LED 0
    br          SALVAR_ESTADO_LED

DIREITA_ESQUERDA:
    # Desloca o bit para a direita (efeito visual: LED move da direita para esquerda).
    srli        r11, r11, 1

    # Se chegou a zero, reinicia no LED 17
    bne         r11, r0, SALVAR_ESTADO_LED
    movia       r11, 0x20000       # Reinicia no LED 17 (2^17)

SALVAR_ESTADO_LED:
    # Salva o novo estado da animação.
    stw         r11, (r10)
    # Atualiza os LEDs físicos.
    movia       r12, LED_BASE
    stwio       r11, (r12)
    br          FIM_TIMER_ISR

TRATAR_CRONOMETRO:
    # Lógica para o cronômetro vai aqui
    br FIM_TIMER_ISR

FIM_TIMER_ISR:
    movia r13, TIMER_BASE
    stwio r0, (r13)
    ret

# ISR do Botão
BUTTON_ISR:
    # Lógica da ISR do Botão vai aqui
    ret
