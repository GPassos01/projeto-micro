#========================================================================================================================================
# Projeto Microprocessadores: Nios II Assembly
# Placa: DE2 - 115
# Grupo: Gabriel Passos e Lucas Ferrarotto
# 1 Semestre de 2025 - Integral
#========================================================================================================================================

.global _start
.global UART_BASE, LED_BASE, HEX_BASE, SW_BASE, KEY_BASE

#========================================================================================================================================
# Definição dos endereços e constantes
#========================================================================================================================================

# Endereços I/O
.equ LED_BASE,      0x10000000    # LEDs vermelhos (18 LEDs: 0-17)
.equ HEX_BASE,      0x10000020    # Displays 7-segmentos (HEX3-HEX0)
.equ SW_BASE,       0x10000040    # Chaves (SW17-SW0)
.equ KEY_BASE,      0x10000050    # Botões (KEY3-KEY0)
.equ UART_BASE,     0x10001000    # UART - ENDEREÇO CORRIGIDO

# Offsets UART - CORRIGIDOS
.equ UART_DATA,     0x0000        # Registrador de dados
.equ UART_CONTROL,  0x0004        # Registrador de controle

# Máscaras UART
.equ UART_WSPACE,   0xFFFF0000    # Write space available (bits 31-16)
.equ UART_RVALID,   0x00008000    # Read valid (bit 15)
.equ UART_DATA_MASK,0x000000FF    # Máscara para dados (bits 7-0)

# Constantes
.equ ENTER_CHAR,    10            # Caractere Enter (LF)
.equ ASCII_0,       0x30          # '0' em ASCII
.equ MAX_CMD_LEN,   10            # Tamanho máximo do comando

# Estados do sistema
.equ STOPPED,		0
.equ STARTED,		1

#========================================================================================================================================
# Programa Principal
#========================================================================================================================================

_start:
    # Inicialização do sistema
    call    init_system
    
    # Configurar sistema de interrupções
    #call    init_interrupts
    
main_loop:
    # Mostrar prompt
    movia   r4, MSG_PROMPT        # r4 = parâmetro para print_string
    call    print_string
    
    # Ler comando
    movia   r4, CMD_BUFFER        # r4 = buffer para comando
    movi    r5, MAX_CMD_LEN       # r5 = tamanho máximo
    call    read_command
    
    # Processar comando
    movia   r4, CMD_BUFFER        # r4 = buffer do comando
    call    parse_command
    
    br      main_loop

#========================================================================================================================================
# Inicialização do Sistema
#========================================================================================================================================
init_system:
    # Preservar registradores (Stack Frame)
    addi    sp, sp, -16
    stw     ra, 12(sp) # ra = return address (r31)
    stw     r16, 8(sp)
    stw     r17, 4(sp)
    stw     r18, 0(sp)
    
    # Inicializar LEDs (todos apagados)
    movia   r16, LED_BASE
    stwio   r0, 0(r16)
    
    # Inicializar displays 7-seg (todos apagados)
    movia   r17, HEX_BASE
    stwio   r0, 0(r17)          # HEX3-HEX0
    
    # Limpar buffer de comando
    movia   r18, CMD_BUFFER
    movi    r16, MAX_CMD_LEN
clear_buffer:
    stb     r0, 0(r18)
    addi    r18, r18, 1
    subi    r16, r16, 1
    bne     r16, r0, clear_buffer
    
    # Restaurar registradores
    ldw     r18, 0(sp)
    ldw     r17, 4(sp)
    ldw     r16, 8(sp)
    ldw     ra, 12(sp)
    addi    sp, sp, 16
    ret

#========================================================================================================================================
# Inicialização do Sistema de Interrupções
#========================================================================================================================================
init_interrupts:
    # Preservar registradores
    addi    sp, sp, -12
    stw     ra, 8(sp)
    stw     r16, 4(sp)
    stw     r17, 0(sp)
    
    # Configurar botões para interrupção
    call    _interrupts
    
    # Restaurar registradores
    ldw     r17, 0(sp)
    ldw     r16, 4(sp)
    ldw     ra, 8(sp)
    addi    sp, sp, 12
    ret

#========================================================================================================================================
# Função: print_string - Enviar string via UART
# Parâmetros: 
#       r4 = ponteiro para string (null-terminated)
#========================================================================================================================================
print_string:
    # Preservar registradores (Stack Frame)
    addi    sp, sp, -16
    stw     ra, 12(sp)
    stw     r16, 8(sp)
    stw     r17, 4(sp)
    stw     r18, 0(sp)
    
    mov     r16, r4             # r16 = ponteiro para string
    movia   r17, UART_BASE      # r17 = base UART
    
print_loop:
    ldb     r18, 0(r16)         # Carregar próximo caractere
    beq     r18, r0, print_done # Se '\0', terminar
    
    # Aguardar espaço no buffer de transmissão
wait_tx_ready:
    ldwio   r16, UART_CONTROL(r17)
    andhi   r16, r16, UART_WSPACE      # Verificar bits 31-16 (write space)
    beq     r16, r0, wait_tx_ready
    
    # Enviar caractere
    stwio   r18, UART_DATA(r17)
    
    addi    r16, r16, 1         # Próximo caractere
    br      print_loop
    
print_done:
    # Restaurar registradores (Stack Frame)
    ldw     r18, 0(sp)
    ldw     r17, 4(sp)
    ldw     r16, 8(sp)
    ldw     ra, 12(sp)
    addi    sp, sp, 16
    ret

#========================================================================================================================================
# Função: read_command - Ler comando via UART
# Parâmetros: 
#       r4 = buffer
#       r5 = tamanho máximo
#========================================================================================================================================
read_command:
    # Preservar registradores (Stack Frame)
    addi    sp, sp, -20
    stw     ra, 16(sp)
    stw     r16, 12(sp)         # Buffer de entrada (parâmetro r4)
    stw     r17, 8(sp)          # Tamanho máximo (parâmetro r5)  
    stw     r18, 4(sp)          # Base UART
    stw     r19, 0(sp)          # Índice atual
    
    mov     r16, r4             # r16 = buffer de entrada
    mov     r17, r5             # r17 = tamanho máximo
    movia   r18, UART_BASE      # r18 = base UART
    mov     r19, r0             # r19 = índice atual
    
read_loop:
    # Aguardar dados disponíveis
wait_rx_ready:
    ldwio   r4, UART_DATA(r18)
    andi    r5, r4, UART_RVALID
    beq     r5, r0, wait_rx_ready
    
    # Extrair dados (bits 7-0)
    andi    r4, r4, UART_DATA_MASK
    
    # Verificar se é Enter
    movi    r5, ENTER_CHAR
    beq     r4, r5, read_done
    
    # Verificar limites do buffer
    bge     r19, r17, read_loop # Ignorar se buffer cheio
    
    # Armazenar caractere no buffer
    add     r5, r16, r19        # Calcular endereço correto: buffer + índice
    stb     r4, 0(r5)           # Armazenar caractere
    addi    r19, r19, 1         # Incrementar índice
    
    br      read_loop
    
read_done:
    # Adicionar terminador null
    add     r4, r16, r19        # Calcular endereço: buffer + índice final
    stb     r0, 0(r4)           # Adicionar '\0'
    
    # Restaurar registradores
    ldw     r19, 0(sp)
    ldw     r18, 4(sp)
    ldw     r17, 8(sp)
    ldw     r16, 12(sp)
    ldw     ra, 16(sp)
    addi    sp, sp, 20
    ret

#========================================================================================================================================
# Função: parse_command - Analisar e executar comando
# Parâmetros: r4 = buffer do comando
#========================================================================================================================================
parse_command:
    # Preservar registradores (Stack Frame)
    addi    sp, sp, -20
    stw     ra, 16(sp)
    stw     r16, 12(sp)
    stw     r17, 8(sp)
    stw     r18, 4(sp)
    stw     r19, 0(sp)
    
    mov     r16, r4             # r16 = buffer do comando
    
    # Verificar se comando tem pelo menos 2 caracteres
    ldb     r17, 0(r16)         # Primeiro dígito
    beq     r17, r0, invalid_cmd
    ldb     r18, 1(r16)         # Segundo dígito
    beq     r18, r0, invalid_cmd
    
    # Validar caracteres ASCII ANTES da conversão (0x30-0x32 = '0'-'2') 
    # Deve ser: 00, 01, 10, 11, 20, 21.
    movi    r19, ASCII_0        # '0' = 0x30
    bltu    r17, r19, invalid_cmd   # Se < '0', inválido
    bltu    r18, r19, invalid_cmd   # Se < '0', inválido
    
    movi    r19, 0x32           # '2' = 0x32
    bgtu    r17, r19, invalid_cmd   # Se > '2', inválido
    movi    r19, 0x31           # '1' = 0x31
    bgtu    r18, r19, invalid_cmd   # Se > '1', inválido
    
    # Converter dígitos para número 
    subi    r17, r17, ASCII_0   # Converter de ASCII
    subi    r18, r18, ASCII_0
    
    # Calcular código do comando (dezena * 10 + unidade)
    # Multiplicar r17 por 10 usando shifts: 10 = 8 + 2
    slli    r19, r17, 3         # r19 = r17 * 8
    slli    r17, r17, 1         # r17 = r17 * 2
    add     r17, r19, r17       # r17 = r17*8 + r17*2 = r17*10
    add     r17, r17, r18       # r17 = dezena*10 + unidade
    
    # Processar comando baseado no código
    beq     r17, r0, cmd_led_control    # 00 - Controle de LED
    movi    r18, 1
    beq     r17, r18, cmd_led_control   # 01 - Controle de LED
    movi    r18, 10
    beq     r17, r18, cmd_animation     # 10 - Animação
    movi    r18, 11
    beq     r17, r18, cmd_animation     # 11 - Animação
    movi    r18, 20
    beq     r17, r18, cmd_timer         # 20 - Cronômetro
    movi    r18, 21
    beq     r17, r18, cmd_timer         # 21 - Cronômetro
    
    br      invalid_cmd
    
cmd_led_control:
    mov     r4, r16             # Passar buffer completo
    call    handle_led_command
    br      parse_done
    
cmd_animation:
    mov     r4, r16             # Passar buffer completo
    call    handle_animation_command
    br      parse_done
    
cmd_timer:
    mov     r4, r16             # Passar buffer completo
    call    handle_timer_command
    br      parse_done
    
invalid_cmd:
    movia   r4, MSG_INVALID
    call    print_string
    
parse_done:
    # Restaurar registradores
    ldw     r19, 0(sp)
    ldw     r18, 4(sp)
    ldw     r17, 8(sp)
    ldw     r16, 12(sp)
    ldw     ra, 16(sp)
    addi    sp, sp, 20
    ret

#========================================================================================================================================
# Handlers de Comando - Stubs que chamam as funções específicas
#========================================================================================================================================

handle_led_command:
    addi    sp, sp, -8
    stw     ra, 4(sp)
    stw     r16, 0(sp)
    
    call    _led
    
    ldw     r16, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 8
    ret

handle_animation_command:
    addi    sp, sp, -8
    stw     ra, 4(sp)
    stw     r16, 0(sp)
    
    call    _animacao
    
    ldw     r16, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 8
    ret

handle_timer_command:
    addi    sp, sp, -8
    stw     ra, 4(sp)
    stw     r16, 0(sp)
    
    call    _cronometro
    
    ldw     r16, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 8
    ret

#========================================================================================================================================
# Dados e Mensagens
#========================================================================================================================================

.org    0x1000
MSG_PROMPT:  
.asciz "Entre com o comando: "

MSG_INVALID:
.asciz "Comando invalido!\r\n"

# Buffer para comando
.align 4
CMD_BUFFER:
.skip 16

.end