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
    # --- 1. PROCESSA TICKS DE INTERRUPÇÃO (NÃO-BLOQUEANTE) ---
    call        PROCESSAR_TICKS_SISTEMA

    # --- 2. PROCESSA BOTÕES (PAUSE/RESUME) ---
    call        PROCESSAR_BOTOES
    
    # --- 3. PROCESSA ENTRADA DA UART (NÃO-BLOQUEANTE) ---
    call        PROCESSAR_CHAR_UART
    
    # Volta imediatamente para o início do loop para continuar o polling
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
    # --- Stack Frame ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    # Verifica a flag genérica do timer
    movia       r16, TIMER_TICK_FLAG
    ldw         r17, (r16)
    beq         r17, r0, FIM_TICKS # Se a flag não foi setada, não faz nada
    
    # Se chegou aqui, um tick ocorreu. Limpa a flag para o próximo.
    stw         r0, (r16)

    # Verifica se a ANIMAÇÃO está ativa
    movia       r16, FLAG_INTERRUPCAO
    ldw         r17, (r16)
    beq         r17, r0, PROCESSA_TICK_CRONOMETRO_ROBUSTO # Se não, pula para o cronômetro
    call        _update_animation_step

PROCESSA_TICK_CRONOMETRO_ROBUSTO:
    # Verifica se o CRONÔMETRO está ativo
    call        PROCESSAR_TICK_CRONOMETRO
    
FIM_TICKS:
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
# NOVA ROTINA DE PROCESSAMENTO DE CHAR (NÃO-BLOQUEANTE)
#========================================================================================================================================
PROCESSAR_CHAR_UART:
    # --- Stack Frame ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r8, 4(sp)
    stw         r9, 0(sp)
    
    movia       r8, JTAG_UART_BASE
    ldwio       r9, UART_DATA(r8)       # Lê registrador de dados da UART
    
    # Verifica se há um caractere válido (bit 15 RVALID)
    andi        r8, r9, 0x8000
    beq         r8, r0, FIM_PROCESSA_CHAR # Se não há caractere, retorna imediatamente

    # Isola o caractere (8 bits inferiores)
    andi        r9, r9, 0xFF

    # Verifica se é Enter ou CR para finalizar o comando
    movi        r8, 10                  # '\n'
    beq         r9, r8, COMANDO_RECEBIDO
    movi        r8, 13                  # '\r'
    beq         r9, r8, COMANDO_RECEBIDO

    # --- Armazena caractere de forma segura no buffer ---
    movia       r8, BUFFER_ENTRADA_POS
    ldw         r10, (r8)               # r10 = posição atual

    movi        r11, 99                 # Limite máximo (0-99)
    bgt         r10, r11, FIM_PROCESSA_CHAR  # Se buffer cheio, descarta caractere

    movia       r11, BUFFER_ENTRADA
    add         r12, r10, r11           # Endereço de armazenamento
    stb         r9, (r12)               # Salva o caractere

    # Incrementa a posição no buffer
    addi        r10, r10, 1
    stw         r10, (r8)

    br          FIM_PROCESSA_CHAR

COMANDO_RECEBIDO:
    # Comando finalizado, processa
    movia       r4, BUFFER_ENTRADA
    call        PROCESSAR_COMANDO
    
    # Limpa buffer e reseta posição para o próximo comando
    call        LIMPAR_BUFFER
    movia       r8, BUFFER_ENTRADA_POS
    stw         r0, (r8)
    
    # Re-imprime o prompt para o próximo comando
    movia       r4, MSG_PROMPT
    call        IMPRIMIR_STRING

FIM_PROCESSA_CHAR:
    # --- Epílogo ---
    ldw         r9, 0(sp)
    ldw         r8, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
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
# NOVA ROTINA DE POLLING DOS BOTÕES
#========================================================================================================================================
PROCESSAR_BOTOES:
    # --- Stack Frame ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r8, 4(sp)
    stw         r9, 0(sp)
    
    # Verifica se o cronômetro está ativo, se não, não faz nada
    movia       r8, CRONOMETRO_ATIVO
    ldw         r9, (r8)
    beq         r9, r0, FIM_PROCESSA_BOTAO

    # Lê o estado dos botões
    movia       r8, KEY_BASE
    ldwio       r9, (r8)
    
    # Isola KEY1 (bit 1)
    andi        r9, r9, 0b10
    beq         r9, r0, FIM_PROCESSA_BOTAO # Se não está pressionado, sai

    # --- Lógica de Debounce e Toggle ---
    # Para evitar múltiplos toggles, usamos uma flag estática
    movia       r8, KEY1_PRESSIONADO_FLAG
    ldw         r9, (r8)
    bne         r9, r0, FIM_PROCESSA_BOTAO # Se já foi tratado, sai

    # Marca que o botão foi tratado
    movi        r9, 1
    stw         r9, (r8)

    # Inverte o estado de pausa (toggle)
    movia       r8, CRONOMETRO_PAUSADO
    ldw         r9, (r8)
    xori        r9, r9, 1               # r9 = !r9
    stw         r9, (r8)
    
FIM_PROCESSA_BOTAO:
    # Lógica para resetar a flag de debounce quando o botão é solto
    movia       r8, KEY_BASE
    ldwio       r9, (r8)
    andi        r9, r9, 0b10
    bne         r9, r0, BOTAO_AINDA_PRESSIONADO
    
    # Botão foi solto, reseta a flag
    movia       r8, KEY1_PRESSIONADO_FLAG
    stw         r0, (r8)

BOTAO_AINDA_PRESSIONADO:
    # --- Epílogo ---
    ldw         r9, 0(sp)
    ldw         r8, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
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

# Buffer para entrada do usuário
.global BUFFER_ENTRADA  
BUFFER_ENTRADA:
    .skip 100

# Ponteiro para a posição atual no buffer de entrada
.global BUFFER_ENTRADA_POS
BUFFER_ENTRADA_POS:
    .word 0

# Flag para debounce do KEY1
.global KEY1_PRESSIONADO_FLAG
KEY1_PRESSIONADO_FLAG:
    .word 0

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

#========================================================================================================================================
# FUNÇÕES DE TIMER UNIFICADAS
#========================================================================================================================================
# Configura e inicia o timer com um período específico
# Entrada: r4 = período em ciclos
CONFIGURAR_TIMER:
    # --- Stack Frame ---
    subi  sp, sp, 12
    stw   ra, 8(sp)
    stw   r8, 4(sp)
    stw   r9, 0(sp)
    
    movia r8, TIMER_BASE
    
    # Para o timer antes de reconfigurar
    stwio r0, 4(r8)
    
    # Configura o período
    andi  r9, r4, 0xFFFF
    stwio r9, 8(r8)             # periodl
    srli  r4, r4, 16
    stwio r4, 12(r8)            # periodh
    
    # Limpa flag de timeout e habilita interrupções
    movi  r9, 1
    stwio r9, 0(r8)
    wrctl ienable, r9
    wrctl status, r9

    # Inicia o timer (START=1, CONT=1, ITO=1)
    movi  r9, 7
    stwio r9, 4(r8)
    
    # --- Epílogo ---
    ldw   r9, 0(sp)
    ldw   r8, 4(sp)
    ldw   ra, 8(sp)
    addi  sp, sp, 12
    ret

# Para o timer de forma segura
PARAR_TIMER:
    # --- Stack Frame ---
    subi sp, sp, 4
    stw  ra, 0(sp)
    
    movia r8, TIMER_BASE
    # Para o timer
    stwio r0, 4(r8)
    # Limpa a flag de hardware
    movi  r9, 1
    stwio r9, 0(r8)
    # Desabilita interrupções
    wrctl ienable, r0
    wrctl status, r0
    
    ldw  ra, 0(sp)
    addi sp, sp, 4
    ret

.end
