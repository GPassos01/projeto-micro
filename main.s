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
    #Print da mensagem "Entre com o comando: "
    movia		r8,	    0x10000000

    movia       r9,     MSG_PROMPT

    PRINTF:

    ldb		    r10,	 0(r9)
    
    beq         r10,     r0,  END

    POLLING_ESCRITA:

    ldwio       r11,     UART_CONTROL(r8)

    andhi       r11,     r11,  0xffff

    beq		    r11,     r0,   POLLING_ESCRITA
    
    stwio		r10,	UART_BASE(r8) 

    addi        r9,     r9,   1

    br PRINTF

    #call envia_msg_uart
    
    #main_loop:
    #    call ler_comando_uart

END:
    br END

.org    0x500
MSG_PROMPT:  
.asciz "Entre com o comando: "

.end