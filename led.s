.global _led

_led:
    addi        r9,     r9,  1 #0p 00

    movi        r10,    0x30

    ldb         r11,    (r9) 

    beq         r11,    r10, ACENDER_LED 

    addi        r10,    r10, 1

    beq         r11,    r10, APAGAR_LED

    ACENDER_LED:
    addi        r9,     r9,  2 #00 p0

    ldb         r11,    (r9)   

    subi        r11,    r11, 0x30 #(n + 30) - 30

    slli        r12,    r11, 3 #8*n

    slli        r13,    r11, 1 #2*n

    add		    r14,	r12, r13 #10*n - dezena

    addi        r9,     r9,  1 #00 0p

    ldb         r11,    (r9)

    subi        r11,    r11, 0x30 #(n + 30) - 30 - unidade

    add         r14,    r14, r11 #x = [dezena][unidade]   

    br          END_LED 

    APAGAR_LED:     

END_LED:
ret