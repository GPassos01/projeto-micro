.org		0x20
# EXCEPTIONS HANDLER
    rdctl		et,		ipending                    # verifica se houve interrupcao externa
    beq         et,     r0,     OTHER_EXCEPTIONS    # se 0, checa excecoes
    subi        ea,     ea,     4                   # interrupcao de hardware, decrementa ea

    andi        r13,    et,     2                   # checa se irq1 ta acionado
    beq         r13,    r0,     OTHER_INTERRUPTS    # se não, checa outras interrupcoes externas
    call		ANIMACAO                          # se sim, vai para IRQ1

OTHER_INTERRUPTS:
    br          END_HANDLER
OTHER_EXCEPTIONS:
END_HANDLER:
    eret
    
.org		    0x100

ANIMACAO:
    
    ret

.global _animacao
_animacao:
    addi        r9,     r9,  1 #0p 00

    ldb         r10,    (r9) #guarda opção -> inicia animação: 0x30 | para animação: 0x31
    subi		r10,	r10, 0x30

    beq         r10,    r0,  INICIAR_ANIMACAO

    #PARAR ANIMACAO

    INICIAR_ANIMACAO:

    #interrup mask
    movia       r8,             0x10000050      # interruptmask register
    movi        r15,            0b10            # define a mascara
    movia       r16,            0x10000058
    stwio       r15,            (r16)           # seta o bit do key1

    #ienable (bit 1)
    wrctl		ienable,		r15              # seta enable com a mascara do bit do botton
    
    #bit PIE
    movi        r15,            1               #mascara do bit PIE
    wrctl       status,         r15

ret