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
.equ UART_BASE,     0x10001000
.equ TIMER_BASE,	ox10002000

# Offset UART
.equ UART_DADOS,    0
.equ UART_CONTROL,	4

# Estados do sistema
.equ STOPPED,		0
.equ STARTED,		1



_start:
    call inicializar_sistema
    movia		r8,	    0x10000000

    movia       r9,     MSG_PROMPT
    
    stwio		r9,		UART_BASE(r8)
    

    #call envia_msg_uart
    
    #main_loop:
    #    call ler_comando_uart

.org    0x500
MSG_PROMPT:  
.ascii "Entre com o comando: "

.end