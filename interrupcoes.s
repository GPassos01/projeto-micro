.org		0x20
.equ SW_BASE,		0x10000040

# EXCEPTIONS HANDLER
    rdctl		et,		ipending                    # verifica se houve interrupcao externa
    beq         et,     r0,     OTHER_EXCEPTIONS    # se 0, checa excecoes
    subi        ea,     ea,     4                   # interrupcao de hardware, decrementa ea

    andi        r13,    et,     1                   # checa se irq1 ta acionado
    beq         r13,    r0,     CHECK_BUTTON        # se não, checa outras interrupcoes externas
    call		TIMER                               # se sim, vai para IRQ1
    

CHECK_BUTTON:
    andi        r13,    et,     2                   # checa se irq2
    beq         r13,    r0,     OTHER_INTERRUPTS    # se não, checa outras interrupcoes externas
    call        BUTTON


OTHER_INTERRUPTS:
    br          END_HANDLER
OTHER_EXCEPTIONS:
END_HANDLER:
    eret
    
.org		    0x100

TIMER:
    movi    r15,    1
    movia   r14,    FLAG_INTERRUPCAO    
    ldw		r14,	(r14)
    beq     r14,    r15, TRATAR_ANIMACAO   

    addi    r15,    r15, 1
    beq     r14,    r15, TRATAR_CRONOMETRO
    br FIM_TIMER

        TRATAR_ANIMACAO:
        #Saber se é esquerda direita ou direita esquerda
        movia       r10,    SW_BASE
        ldwio       r11,    (r10)
        andi        r11,    r11,     1
        beq         r11,    r0,     DIREITA_ESQUERDA

        #ESQUERDA_DIREITA
        br FIM_TIMER

        DIREITA_ESQUERDA:         

        
        
        br FIM_TIMER

        TRATAR_CRONOMETRO:    

        FIM_TIMER:
        movia r13, 0x10002000
        stwio r0, (r13)

        ret

BUTTON:

    ret