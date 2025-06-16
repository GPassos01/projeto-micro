.global _animacao
_animacao:
    addi        r9,     r9,  1 #0p 00

    ldb         r10,    (r9) #guarda opção -> inicia animação: 0x30 | para animação: 0x31
    subi		r10,	r10, 0x30

    beq         r10,    r0,  INICIAR_ANIMACAO

#PARAR ANIMACAO

INICIAR_ANIMACAO:

    movia		r10,	FLAG_INTERRUPCAO 
    movi		r11,		1    
    stw		    r11,	(r10)
ret