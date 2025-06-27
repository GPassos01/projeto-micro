.global _led

# Referência para símbolo global definido em main.s
.extern LED_STATE

# Definição de constante
.equ LED_BASE, 0x10000000

_led:
    # --- Stack Frame Prologue (ABI Compliant) ---
    # Aloca espaço na pilha para salvar os registradores 'ra' e 's0' (r16)
    subi        sp, sp, 8
    stw         ra, 4(sp)       # Salva o endereço de retorno
    stw         r16, 0(sp)      # Salva r16 (s0), um registrador callee-saved

    # A partir daqui, r16 pode ser usado livremente.
    
    addi        r9,     r9,  1 #0p 00
    
    ldb         r10,    (r9) #guarda opção -> acende: 0x30 | apaga: 0x31
    subi		r10,	r10, 0x30

    #Tratar número do LED
    addi        r9,     r9,  2 #00 p0

    ldb         r11,    (r9)  
    subi        r11,    r11, 0x30 #(n + 30) - 30

    slli        r12,    r11, 3 #8*n

    slli        r13,    r11, 1 #2*n

    add		    r14,	r12, r13 #10*n -> dezena

    addi        r9,     r9,  1 #00 0p

    ldb         r11,    (r9)
    subi        r11,    r11, 0x30 #unidade

    add         r14,    r14, r11 #x = [dezena][unidade]   
    
    # Valida se o LED está na faixa válida (0-17)
    movi        r12, 17
    bgt         r14, r12, FIM_LED   # Se LED > 17, sai sem fazer nada
    blt         r14, r0, FIM_LED    # Se LED < 0, sai sem fazer nada
    
    movi        r12, 1
    sll         r14,    r12, r14 #posicao do led a apagar/acender

    movia       r13,    LED_STATE     # r16 = estado atual dos leds
    ldw         r16,    (r13)

    beq         r10,    r0, ACENDER_LED 

    #APAGAR_LED
    nor         r14, r14, r14    #invertendo o r14
    and         r16, r16, r14    #Excluir utilizando and

    br    ATUALIZAR_LED



ACENDER_LED:
    or     r16, r16, r14            # seto o bit para acender


ATUALIZAR_LED:
    movia       r11,    LED_BASE    # Usa constante definida
    stwio       r16,    (r11)       # escreve nos LEDs
    stw		    r16,    (r13)       # salva na memória estado atual

FIM_LED:
    # --- Stack Frame Epilogue ---
    # Restaura os registradores salvos e desaloca a pilha
    ldw         r16, 0(sp)      # Restaura o valor original de r16 (s0)
    ldw         ra, 4(sp)       # Restaura o endereço de retorno
    addi        sp, sp, 8
    ret
