#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: main.s  
# Descrição: Loop Principal e Gerenciamento de Comandos
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
# Placa: DE2-115 (Cyclone IV)
# Grupo: Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
#========================================================================================================================================

.global _start

# Referências para variáveis definidas em interrupcoes.s (compilado primeiro)
.extern FLAG_INTERRUPCAO
.extern TIMER_TICK_FLAG
.extern CRONOMETRO_TICK_FLAG
.extern CRONOMETRO_SEGUNDOS
.extern CRONOMETRO_PAUSADO
.extern CRONOMETRO_ATIVO
.section .text

#========================================================================================================================================
# Definição de Endereços e Constantes - Conforme Manual DE2-115
#========================================================================================================================================

# --- Endereços de Periféricos (Memory-Mapped I/O) ---
.equ LED_BASE,          0x10000000      # LEDs vermelhos (18 LEDs: 0-17)
.equ HEX_BASE,          0x10000020      # Displays 7-segmentos (HEX3-0)
.equ SW_BASE,           0x10000040      # Switches (SW17-0)
.equ KEY_BASE,          0x10000050      # Botões (KEY3-0)
.equ JTAG_UART_BASE,    0x10001000      # JTAG UART
.equ TIMER_BASE,        0x10002000      # Timer do sistema

# --- Offsets para Registradores da JTAG UART ---
.equ UART_DATA,         0               # Registrador de dados
.equ UART_CONTROL,      4               # Registrador de controle

# --- Estados do Sistema ---
.equ PARADO,            0
.equ ATIVO,             1

# --- Configurações de Timing ---
.equ ANIMACAO_PERIODO,  10000000        # 200ms a 50MHz (10M ciclos)
.equ CRONOMETRO_PERIODO, 50000000       # 1s a 50MHz (50M ciclos)

#========================================================================================================================================
# Início do Programa
#========================================================================================================================================
_start:
    # --- INICIALIZAÇÃO SISTEMA (ABI Compliant) ---
    # Stack pointer para topo da memória (ABI requirement)
    movia       sp, 0x0001FFFC          # Stack cresce para baixo
    
    # Frame pointer inicial (ABI requirement)
    mov         fp, sp
    
    # Inicialização usando registradores caller-saved (r1-r15)
    call        INICIALIZAR_SISTEMA

#========================================================================================================================================
# Loop Principal: Imprimir Prompt, Ler e Processar Comando
#========================================================================================================================================
MAIN_LOOP:
    # --- Verifica e processa ticks de interrupção ---
    call        PROCESSAR_TICKS_SISTEMA
    
    # --- Limpa buffer para garantir entrada limpa ---
    call        LIMPAR_BUFFER
    
    # --- Imprime prompt usando registradores ABI compliant ---
    movia       r4, MSG_PROMPT           # r4 = argumento 1 (ABI)
    call        IMPRIMIR_STRING
    
    # --- Lê comando do usuário ---
    movia       r4, BUFFER_ENTRADA       # r4 = buffer destino (ABI)
    movi        r5, 100                  # r5 = tamanho máximo (ABI)
    call        LER_COMANDO_UART
    
    # --- Processa comando recebido ---
    movia       r4, BUFFER_ENTRADA       # r4 = comando para processar (ABI)
    call        PROCESSAR_COMANDO
    
    # Retorna ao início do loop
    br          MAIN_LOOP

#========================================================================================================================================
# INICIALIZAÇÃO DO SISTEMA - ABI COMPLIANT
#========================================================================================================================================
INICIALIZAR_SISTEMA:
    # --- Stack Frame Prologue (ABI Standard) ---
    subi        sp, sp, 8
    stw         ra, 4(sp)                # Salva return address
    stw         r16, 0(sp)               # Salva r16 (callee-saved)
    
    # Inicializa LEDs (todos apagados)
    movia       r16, LED_BASE
    stwio       r0, (r16)
    
    # Inicializa displays 7-segmentos (todos apagados)
    movia       r16, HEX_BASE
    stwio       r0, 0(r16)               # HEX0
    stwio       r0, 4(r16)               # HEX1  
    stwio       r0, 8(r16)               # HEX2
    stwio       r0, 12(r16)              # HEX3
    
    # Inicializa estado dos LEDs
    movia       r16, LED_STATE
    stw         r0, (r16)
    
    # --- Stack Frame Epilogue (ABI Standard) ---
    ldw         r16, 0(sp)               # Restaura r16
    ldw         ra, 4(sp)                # Restaura return address
    addi        sp, sp, 8                # Libera stack
    ret

#========================================================================================================================================
# PROCESSAMENTO DE TICKS DO SISTEMA
#========================================================================================================================================
PROCESSAR_TICKS_SISTEMA:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    # --- Verifica tick da animação ---
    movia       r16, TIMER_TICK_FLAG
    ldw         r17, (r16)
    beq         r17, r0, CHECK_CRONOMETRO_TICK_FIX
    
    # CORRIGIDO: Limpa a flag e chama a função de atualização correta
    stw         r0, (r16)
    call        _update_animation_step
    
CHECK_CRONOMETRO_TICK_FIX:
    # --- Verifica tick do cronômetro ---
    movia       r16, CRONOMETRO_TICK_FLAG
    ldw         r17, (r16)
    beq         r17, r0, TICKS_EXIT_FIX
    
    # Limpa flag e processa cronômetro (função de suporte mantida por complexidade)
    stw         r0, (r16)
    call        PROCESSAR_TICK_CRONOMETRO
    
TICKS_EXIT_FIX:
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#========================================================================================================================================
# IMPRESSÃO DE STRING VIA UART - ABI COMPLIANT
#========================================================================================================================================
IMPRIMIR_STRING:
    # --- Stack Frame Prologue ---
    # r4 = ponteiro para string (argumento 1 conforme ABI)
    subi        sp, sp, 16
    stw         ra, 12(sp)
    stw         r16, 8(sp)               # String pointer
    stw         r17, 4(sp)               # UART base
    stw         r18, 0(sp)               # Char atual
    
    mov         r16, r4                  # Copia argumento para callee-saved
    movia       r17, JTAG_UART_BASE
    
PRINT_LOOP:
    # Carrega próximo caractere
    ldb         r18, (r16)
    beq         r18, r0, PRINT_EXIT      # Se null terminator, sai
    
WAIT_UART_READY:
    # Polling UART robusto com seções críticas
    rdctl       r1, status               # Salva status (usando caller-saved)
    wrctl       status, r0               # Desabilita interrupções
    
    ldwio       r2, UART_CONTROL(r17)    # Lê controle UART
    
    wrctl       status, r1               # Restaura interrupções
    
    andhi       r2, r2, 0xFFFF           # Verifica WSPACE
    beq         r2, r0, WAIT_UART_READY  # Se buffer cheio, espera
    
    # Escreve caractere atomicamente
    rdctl       r1, status
    wrctl       status, r0
    stwio       r18, UART_DATA(r17)
    wrctl       status, r1
    
    addi        r16, r16, 1              # Próximo caractere
    br          PRINT_LOOP
    
PRINT_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r18, 0(sp)
    ldw         r17, 4(sp)
    ldw         r16, 8(sp)
    ldw         ra, 12(sp)
    addi        sp, sp, 16
    ret

#========================================================================================================================================
# LEITURA DE COMANDO VIA UART - ABI COMPLIANT
#========================================================================================================================================
LER_COMANDO_UART:
    # --- Stack Frame Prologue ---
    # r4 = buffer destino, r5 = tamanho máximo
    subi        sp, sp, 20
    stw         ra, 16(sp)
    stw         r16, 12(sp)              # Buffer atual
    stw         r17, 8(sp)               # UART base
    stw         r18, 4(sp)               # Contador
    stw         r19, 0(sp)               # Char lido
    
    mov         r16, r4                  # Buffer destino
    mov         r18, r5                  # Tamanho máximo
    movia       r17, JTAG_UART_BASE
    
READ_CHAR_LOOP:
    # Limite de tentativas para robustez
    movi        r1, 10000
    
UART_POLL_LOOP:
    # Leitura atômica da UART
    rdctl       r2, status
    wrctl       status, r0
    ldwio       r3, UART_DATA(r17)
    wrctl       status, r2
    
    andi        r19, r3, 0x8000          # Verifica RVALID
    bne         r19, r0, CHAR_READY
    
    subi        r1, r1, 1
    bne         r1, r0, UART_POLL_LOOP
    br          READ_CHAR_LOOP           # Timeout, tenta novamente
    
CHAR_READY:
    andi        r19, r3, 0xFF            # Isola caractere
    
    # Verifica se é Enter ou CR
    movi        r1, 10                   # '\n'
    beq         r19, r1, READ_COMPLETE
    movi        r1, 13                   # '\r'  
    beq         r19, r1, READ_COMPLETE
    
    # Armazena caractere no buffer
    stb         r19, (r16)
    addi        r16, r16, 1
    subi        r18, r18, 1
    bne         r18, r0, READ_CHAR_LOOP  # Continua se há espaço
    
READ_COMPLETE:
    # Adiciona null terminator
    stb         r0, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r19, 0(sp)
    ldw         r18, 4(sp)
    ldw         r17, 8(sp)
    ldw         r16, 12(sp)
    ldw         ra, 16(sp)
    addi        sp, sp, 20
    ret

#========================================================================================================================================
# PROCESSAMENTO DE COMANDOS - ABI COMPLIANT
#========================================================================================================================================
PROCESSAR_COMANDO:
    # --- Stack Frame Prologue ---
    # r4 = ponteiro para comando
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)               # Command pointer
    stw         r17, 0(sp)               # First char
    
    mov         r16, r4
    ldb         r17, (r16)               # Primeiro caractere
    
    # Compara com comandos conhecidos
    movi        r1, '0'
    beq         r17, r1, CMD_LED
    movi        r1, '1'  
    beq         r17, r1, CMD_ANIMATION
    movi        r1, '2'
    beq         r17, r1, CMD_CRONOMETER
    
    # Comando inválido
    br          CMD_EXIT
    
CMD_LED:
    mov         r4, r16                  # Passa comando como argumento
    call        _led
    br          CMD_EXIT
    
CMD_ANIMATION:
    mov         r4, r16
    call        _animacao
    br          CMD_EXIT
    
CMD_CRONOMETER:
    mov         r4, r16
    call        _cronometro
    
CMD_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#========================================================================================================================================
# ROTINAS DE SUPORTE PARA TICKS
#========================================================================================================================================
PROCESSAR_TICK_CRONOMETRO:
    # Verifica se cronômetro está ativo
    movia       r1, CRONOMETRO_ATIVO
    ldw         r2, (r1)
    beq         r2, r0, TICK_CRONO_EXIT
    
    # Verifica se está pausado
    movia       r1, CRONOMETRO_PAUSADO
    ldw         r2, (r1)
    bne         r2, r0, TICK_CRONO_EXIT
    
    # Incrementa segundos
    movia       r1, CRONOMETRO_SEGUNDOS
    ldw         r2, (r1)
    addi        r2, r2, 1
    
    # Verifica overflow (99:59 = 5999 segundos)
    movi        r3, 5999
    ble         r2, r3, STORE_SECONDS
    mov         r2, r0                   # Reset para 00:00
    
STORE_SECONDS:
    stw         r2, (r1)
    
    # Atualiza displays
    call        ATUALIZAR_DISPLAY_CRONOMETRO
    
TICK_CRONO_EXIT:
    ret

#========================================================================================================================================
# ATUALIZAÇÃO DE DISPLAY DO CRONÔMETRO
#========================================================================================================================================
ATUALIZAR_DISPLAY_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 20
    stw         ra, 16(sp)
    stw         r16, 12(sp)              # Segundos totais
    stw         r17, 8(sp)               # Minutos
    stw         r18, 4(sp)               # Segundos
    stw         r19, 0(sp)               # Dígito atual
    
    # Carrega segundos totais
    movia       r1, CRONOMETRO_SEGUNDOS
    ldw         r16, (r1)
    
    # Calcula minutos e segundos
    movi        r1, 60
    div         r17, r16, r1             # Minutos
    mul         r2, r17, r1
    sub         r18, r16, r2             # Segundos restantes
    
    # Display HEX3 (dezenas de minutos)
    movi        r1, 10
    div         r19, r17, r1
    mov         r4, r19
    call        CODIFICAR_7SEG
    movia       r1, HEX_BASE
    stwio       r2, 12(r1)               # HEX3
    
    # Display HEX2 (unidades de minutos)
    movi        r1, 10
    div         r2, r17, r1
    mul         r2, r2, r1
    sub         r19, r17, r2
    mov         r4, r19
    call        CODIFICAR_7SEG
    movia       r1, HEX_BASE
    stwio       r2, 8(r1)                # HEX2
    
    # Display HEX1 (dezenas de segundos)
    movi        r1, 10
    div         r19, r18, r1
    mov         r4, r19
    call        CODIFICAR_7SEG
    movia       r1, HEX_BASE
    stwio       r2, 4(r1)                # HEX1
    
    # Display HEX0 (unidades de segundos)
    movi        r1, 10
    div         r2, r18, r1
    mul         r2, r2, r1
    sub         r19, r18, r2
    mov         r4, r19
    call        CODIFICAR_7SEG
    movia       r1, HEX_BASE
    stwio       r2, 0(r1)                # HEX0
    
    # --- Stack Frame Epilogue ---
    ldw         r19, 0(sp)
    ldw         r18, 4(sp)
    ldw         r17, 8(sp)
    ldw         r16, 12(sp)
    ldw         ra, 16(sp)
    addi        sp, sp, 20
    ret

#========================================================================================================================================
# CODIFICAÇÃO PARA DISPLAY 7-SEGMENTOS
#========================================================================================================================================
CODIFICAR_7SEG:
    # r4 = dígito (0-9), retorna em r2
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Validação de entrada
    movi        r1, 9
    bgt         r4, r1, INVALID_DIGIT
    blt         r4, r0, INVALID_DIGIT
    
    # Tabela de codificação 7-segmentos
    movia       r16, TABELA_7SEG
    slli        r1, r4, 2                # Multiplica por 4 (word)
    add         r16, r16, r1
    ldw         r2, (r16)                # Carrega código
    br          CODIF_EXIT
    
INVALID_DIGIT:
    movi        r2, 0x00                 # Display apagado
    
CODIF_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#========================================================================================================================================
# Rotina para Limpar o Buffer
#========================================================================================================================================
LIMPAR_BUFFER:
    movia       r8, BUFFER_ENTRADA
    movi        r9, 100              # Tamanho do buffer
LIMPAR_LOOP:
    stb         r0, (r8)            # Escreve 0 na posição atual
    addi        r8, r8, 1           # Avança para próxima posição
    subi        r9, r9, 1           # Decrementa contador
    bne         r9, r0, LIMPAR_LOOP # Continua se não zerou
    ret

#========================================================================================================================================
# Seção de Dados - ABI ALIGNED
#========================================================================================================================================
.section .data
.align 4

# Estado global dos LEDs
.global LED_STATE
LED_STATE:
    .word 0

# Buffer para armazenar a entrada do usuário.
.global BUFFER_ENTRADA  
BUFFER_ENTRADA:
    .skip 100

# Tabela de codificação para displays 7-segmentos
.global TABELA_7SEG
TABELA_7SEG:
    .word 0x3F    # 0
    .word 0x06    # 1
    .word 0x5B    # 2
    .word 0x4F    # 3
    .word 0x66    # 4
    .word 0x6D    # 5
    .word 0x7D    # 6
    .word 0x07    # 7
    .word 0x7F    # 8
    .word 0x6F    # 9

# Strings do sistema
MSG_PROMPT:
    .asciz "Entre com o comando: "

# Declarações externas
.global INTERRUPCAO_HANDLER
.extern _led
.extern _animacao  
.extern _cronometro
.extern _update_animation_step

.end
