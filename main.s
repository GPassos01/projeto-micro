#========================================================================================================================================
# Projeto Microprocessadores: Nios II Assembly
# Placa: DE2 - 115
# Grupo: Gabriel Passos e Lucas Ferrarotto
# 1 Semestre de 2025
#========================================================================================================================================

.global _start

#========================================================================================================================================
# Definição dos endereços e constantes
#========================================================================================================================================

# Endereços I/O
.equ LED_BASE,      0x10000000
.equ HEX_BASE,      0x10000020
.equ SW_BASE,		0x10000040
.equ KEY_BASE,		0x10000050
.equ UART_BASE,     0x1000
.equ TIMER_BASE,	0x10002000

# Offset UART
.equ UART_DADOS,    0
.equ UART_CONTROL,	0x1004

# Estados do sistema
.equ STOPPED,		0
.equ STARTED,		1

_start:
    movia		r8,	    0x10000000

    movia       r9,     MSG_PROMPT

    movi        r10,    BUFFER_ESCRITA

    PRINTF:

    ldb		    r11,	 0(r9)
    
    beq         r11,     r0,  POLLING_ENTRADA #verifica se a mensagem inicial chegou no fim

    POLLING_ESCRITA:

    ldwio       r12,     UART_CONTROL(r8)

    andhi       r12,     r12,  0xffff

    beq		    r12,     r0,   POLLING_ESCRITA
    
    stwio		r11,	UART_BASE(r8) 

    addi        r9,     r9,   1

    br PRINTF

    POLLING_ENTRADA:

    ldwio       r9,     UART_BASE(r8)

    andi        r11,     r9,  0x8000 #aplica a máscara para RVALID

    beq		    r11,     r0,  POLLING_ENTRADA #verifica se o dado é válido

    andi        r11,     r9,  0xFF   #aplica a máscara para o data    

    movi		r12,    10   #Enter 

    beq         r11,    r12, FINISH_READ #verifica se o caractere é enter

    stb         r11,    (r10)  #armazena caractere no vetor

    addi        r10,    r10, 1 #vai para o próximo endereço no vetor      

    br POLLING_ENTRADA

    FINISH_READ:

    movi        r9,     BUFFER_ESCRITA

    movi        r10,    0x30 #0 na tabela ASCII

    ldb         r11,    (r9) 

    beq         r11,    r10, CALL_LED

    addi        r10,    r10, 1 

    beq         r11,    r10, CALL_ANIMATION 

    addi        r10,    r10, 1

    beq         r11,    r10, CALL_CRONOMETER

    br _start

    CALL_LED:
        call _led
    br _start

    CALL_ANIMATION:
        call _animacao
    br _start

    CALL_CRONOMETER:
        call _cronometro
    br _start

.org    0x500
MSG_PROMPT:  
.asciz "Entre com o comando: "
BUFFER_ESCRITA:
.skip 100
.end