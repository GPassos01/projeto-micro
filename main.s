#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: main.s  
# Descrição: Loop Principal e Gerenciamento de Comandos UART
# ABI Compliant: 100% - Seguindo convenções rigorosas da ABI Nios II
# 
# FUNCIONALIDADES PRINCIPAIS:
# - Loop principal não-bloqueante com polling eficiente
# - Interface UART robusta com buffer de entrada
# - Processamento de comandos modular (LED/Animação/Cronômetro)  
# - Controle de botões com edge detection
# - Displays 7-segmentos MM:SS para cronômetro
# - Funções de suporte ABI-compliant
#
# PLACA: DE2-115 (Cyclone IV FPGA)
# AUTORES: Amanda Oliveira, Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
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
.equ HEX_BASE,          0x10000020      # Displays 7-segmentos (HEX3-0) em 32 bits
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

# --- Constantes para Cronômetro ---
.equ CRONOMETRO_MAX_SEGUNDOS, 5999      # 99:59 (99*60 + 59 = 5999 segundos)

#========================================================================================================================================
# PONTO DE ENTRADA DO PROGRAMA - ABI COMPLIANT
#========================================================================================================================================
_start:
    # === INICIALIZAÇÃO CRÍTICA DO SISTEMA ===
    # Stack pointer para topo da memória on-chip (ABI requirement)
    movia       sp, 0x0001FFFC          # 128KB on-chip RAM, stack cresce para baixo
    
    # Frame pointer inicial (ABI requirement)
    mov         fp, sp
    
    # Inicialização completa do sistema
    call        INICIALIZAR_SISTEMA
    
    # Imprime prompt inicial para o usuário
    movia       r4, MSG_PROMPT
    call        IMPRIMIR_STRING

#========================================================================================================================================
# LOOP PRINCIPAL OTIMIZADO - Polling Não-Bloqueante de Alta Performance
# 
# ESTRATÉGIA:
# 1. Processa ticks de interrupção (animação/cronômetro)
# 2. Processa entrada UART (comandos do usuário)
# 3. Processa botões físicos (KEY1 para cronômetro)
# 4. Retorna imediatamente ao início para máxima responsividade
#========================================================================================================================================
MAIN_LOOP:
    # --- 1. PROCESSA TICKS DE INTERRUPÇÃO (ALTA PRIORIDADE) ---
    call        PROCESSAR_TICKS_SISTEMA
    
    # --- 2. PROCESSA ENTRADA DA UART (COMANDOS USUÁRIO) ---
    call        PROCESSAR_CHAR_UART
    
    # --- 3. PROCESSA BOTÕES FÍSICOS (CONTROLE MANUAL) ---
    call        PROCESSAR_BOTOES
    
    # Loop infinito otimizado - máxima responsividade
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
    stwio       r0, (r16)                # Limpa todos os 4 displays (0x00000000)
    
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
    
    # Limpa a flag e chama a função de atualização correta
    stw         r0, (r16)
    call        _update_animation_step
    # Se animação processada, NÃO processa cronômetro (timer único)
    br          TICKS_EXIT_FIX
    
CHECK_CRONOMETRO_TICK_FIX:
    # --- Verifica tick do cronômetro (apenas se animação não processada) ---
    movia       r16, CRONOMETRO_TICK_FLAG
    ldw         r17, (r16)
    beq         r17, r0, TICKS_EXIT_FIX
    
    # Limpa flag e processa cronômetro
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
    subi        sp, sp, 24
    stw         ra, 20(sp)
    stw         r16, 16(sp)              # String pointer
    stw         r17, 12(sp)              # UART base
    stw         r18, 8(sp)               # Char atual
    stw         r19, 4(sp)               # Status temp
    stw         r20, 0(sp)               # UART control temp
    
    mov         r16, r4                  # Copia argumento para callee-saved
    movia       r17, JTAG_UART_BASE
    
PRINT_LOOP:
    # Carrega próximo caractere
    ldb         r18, (r16)
    beq         r18, r0, PRINT_EXIT      # Se null terminator, sai
    
WAIT_UART_READY:
    # Polling UART robusto com seções críticas
    rdctl       r19, status              # Salva status (usando callee-saved)
    wrctl       status, r0               # Desabilita interrupções
    
    ldwio       r20, UART_CONTROL(r17)   # Lê controle UART
    
    wrctl       status, r19              # Restaura interrupções
    
    andhi       r20, r20, 0xFFFF         # Verifica WSPACE
    beq         r20, r0, WAIT_UART_READY # Se buffer cheio, espera
    
    # Escreve caractere atomicamente
    rdctl       r19, status
    wrctl       status, r0
    stwio       r18, UART_DATA(r17)
    wrctl       status, r19
    
    addi        r16, r16, 1              # Próximo caractere
    br          PRINT_LOOP
    
PRINT_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r20, 0(sp)
    ldw         r19, 4(sp)
    ldw         r18, 8(sp)
    ldw         r17, 12(sp)
    ldw         r16, 16(sp)
    ldw         ra, 20(sp)
    addi        sp, sp, 24
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

    # Armazena caractere no buffer
    movia       r8, BUFFER_ENTRADA_POS
    ldw         r10, (r8)               # Carrega ponteiro da posição atual
    movia       r11, BUFFER_ENTRADA
    add         r10, r10, r11           # Calcula endereço de armazenamento
    stb         r9, (r10)               # Salva o caractere

    # Incrementa a posição no buffer
    movia       r8, BUFFER_ENTRADA_POS
    ldw         r10, (r8)
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
# PROCESSAMENTO DE BOTÕES - ABI COMPLIANT
#========================================================================================================================================
PROCESSAR_BOTOES:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 24
    stw         ra, 20(sp)
    stw         r16, 16(sp)              # Estado atual dos botões
    stw         r17, 12(sp)              # Estado anterior dos botões
    stw         r18, 8(sp)               # Botão pressionado (edge detection)
    stw         r19, 4(sp)               # Temp para endereços
    stw         r20, 0(sp)               # Temp para bit mask
    
    # Lê estado atual dos botões
    movia       r19, KEY_BASE
    ldwio       r16, (r19)              # r16 = estado atual
    
    # Carrega estado anterior dos botões
    movia       r19, BOTOES_ESTADO_ANTERIOR
    ldw         r17, (r19)              # r17 = estado anterior
    
    # Detecta bordas de descida (botão pressionado)
    # Botão pressionado = anterior era 1 e atual é 0
    xor         r18, r16, r17           # XOR para detectar mudanças
    and         r18, r18, r17           # AND com anterior para pegar descidas
    
    # Salva estado atual como anterior para próxima iteração
    stw         r16, (r19)
    
    # Verifica se KEY1 foi pressionado (bit 1)
    andi        r20, r18, 0x02          # Isola bit 1 (KEY1)
    beq         r20, r0, BOTOES_EXIT    # Se não foi pressionado, sai
    
    # KEY1 foi pressionado - controla cronômetro
    call        PROCESSAR_KEY1_CRONOMETRO
    
BOTOES_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r20, 0(sp)
    ldw         r19, 4(sp)
    ldw         r18, 8(sp)
    ldw         r17, 12(sp)
    ldw         r16, 16(sp)
    ldw         ra, 20(sp)
    addi        sp, sp, 24
    ret

#========================================================================================================================================
# PROCESSAMENTO DO KEY1 PARA CRONÔMETRO
#========================================================================================================================================
PROCESSAR_KEY1_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    # Verifica se cronômetro está ativo
    movia       r16, CRONOMETRO_ATIVO
    ldw         r17, (r16)
    beq         r17, r0, KEY1_EXIT      # Se não ativo, não faz nada
    
    # Cronômetro está ativo - alterna estado pausado/rodando
    movia       r16, CRONOMETRO_PAUSADO
    ldw         r17, (r16)
    
    # Inverte o estado
    xori        r17, r17, 1             # 0 vira 1, 1 vira 0
    stw         r17, (r16)
    
    # Mensagem de feedback
    beq         r17, r0, CRONOMETRO_RETOMADO
    
    # Cronômetro pausado
    movia       r4, MSG_CRONOMETRO_PAUSADO
    call        IMPRIMIR_STRING
    br          KEY1_EXIT
    
CRONOMETRO_RETOMADO:
    # Cronômetro retomado
    movia       r4, MSG_CRONOMETRO_RETOMADO
    call        IMPRIMIR_STRING
    
KEY1_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#========================================================================================================================================
# PROCESSAMENTO DE COMANDOS - ABI COMPLIANT
#========================================================================================================================================
PROCESSAR_COMANDO:
    # --- Stack Frame Prologue ---
    # r4 = ponteiro para comando
    subi        sp, sp, 16
    stw         ra, 12(sp)
    stw         r16, 8(sp)               # Command pointer
    stw         r17, 4(sp)               # First char
    stw         r18, 0(sp)               # Temp para comparações
    
    mov         r16, r4
    ldb         r17, (r16)               # Primeiro caractere
    
    # Compara com comandos conhecidos
    movi        r18, '0'
    beq         r17, r18, CMD_LED
    movi        r18, '1'  
    beq         r17, r18, CMD_ANIMATION
    movi        r18, '2'
    beq         r17, r18, CMD_CRONOMETER
    
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
    ldw         r18, 0(sp)
    ldw         r17, 4(sp)
    ldw         r16, 8(sp)
    ldw         ra, 12(sp)
    addi        sp, sp, 16
    ret

#========================================================================================================================================
# ROTINAS DE SUPORTE PARA TICKS
#========================================================================================================================================
PROCESSAR_TICK_CRONOMETRO:
    # --- Stack Frame Prologue (CRÍTICO!) ---
    subi        sp, sp, 16
    stw         ra, 12(sp)               # Salva return address
    stw         r16, 8(sp)               # Registrador temporário
    stw         r17, 4(sp)               # Registrador temporário
    stw         r18, 0(sp)               # Registrador temporário
    
    # Verifica se cronômetro está ativo
    movia       r16, CRONOMETRO_ATIVO
    ldw         r17, (r16)
    beq         r17, r0, TICK_CRONO_EXIT
    
    # Verifica se está pausado
    movia       r16, CRONOMETRO_PAUSADO
    ldw         r17, (r16)
    bne         r17, r0, TICK_CRONO_EXIT
    
    # Incrementa segundos
    movia       r16, CRONOMETRO_SEGUNDOS
    ldw         r17, (r16)
    addi        r17, r17, 1
    
    # Verifica overflow (99:59 = 5999 segundos)
    movi        r18, CRONOMETRO_MAX_SEGUNDOS
    ble         r17, r18, STORE_SECONDS
    mov         r17, r0                   # Reset para 00:00
    
STORE_SECONDS:
    stw         r17, (r16)
    
    # Atualiza displays
    call        ATUALIZAR_DISPLAY_CRONOMETRO
    
TICK_CRONO_EXIT:
    # --- Stack Frame Epilogue (CRÍTICO!) ---
    ldw         r18, 0(sp)               # Restaura registradores
    ldw         r17, 4(sp)
    ldw         r16, 8(sp)
    ldw         ra, 12(sp)               # Restaura return address
    addi        sp, sp, 16               # Libera stack
    ret

#========================================================================================================================================
# ATUALIZAÇÃO DE DISPLAY DO CRONÔMETRO
#========================================================================================================================================
ATUALIZAR_DISPLAY_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 36
    stw         ra, 32(sp)
    stw         r16, 28(sp)              # Segundos totais
    stw         r17, 24(sp)              # Minutos
    stw         r18, 20(sp)              # Segundos restantes
    stw         r19, 16(sp)              # Valor final dos displays
    stw         r20, 12(sp)              # Temp para cálculos
    stw         r21, 8(sp)               # Temp para dígitos
    stw         r22, 4(sp)               # Temp para shifts
    stw         r23, 0(sp)               # Temp para constantes
    
    # Carrega segundos totais do cronômetro
    movia       r23, CRONOMETRO_SEGUNDOS
    ldw         r16, (r23)
    
    # === DIVISÃO MANUAL POR 60 PARA CALCULAR MINUTOS ===
    mov         r17, r0                  # r17 = minutos (quociente)
    mov         r18, r16                 # r18 = segundos restantes (dividendo)
    
    # Loop: subtrai 60 até não poder mais
DIVISAO_60_LOOP:
    movi        r23, 60
    blt         r18, r23, DIVISAO_60_FIM # Se < 60, termina
    sub         r18, r18, r23            # Subtrai 60
    addi        r17, r17, 1              # Incrementa minutos
    br          DIVISAO_60_LOOP
    
DIVISAO_60_FIM:
    # r17 = minutos, r18 = segundos restantes
    
    mov         r19, r0                  # Valor final = 0
    
    # === HEX3: DEZENAS DE MINUTOS (bits 31-24) ===
    mov         r20, r0                  # Dezenas de minutos
    mov         r21, r17                 # Copia minutos
DEZENAS_MIN_LOOP:
    movi        r23, 10
    blt         r21, r23, DEZENAS_MIN_FIM
    sub         r21, r21, r23
    addi        r20, r20, 1
    br          DEZENAS_MIN_LOOP
DEZENAS_MIN_FIM:
    mov         r4, r20
    call        CODIFICAR_7SEG
    slli        r22, r2, 24
    or          r19, r19, r22
    
    # === HEX2: UNIDADES DE MINUTOS (bits 23-16) ===
    mov         r4, r21                  # r21 já tem unidades de minutos
    call        CODIFICAR_7SEG
    slli        r22, r2, 16
    or          r19, r19, r22
    
    # === HEX1: DEZENAS DE SEGUNDOS (bits 15-8) ===
    mov         r20, r0                  # Dezenas de segundos
    mov         r21, r18                 # Copia segundos restantes
DEZENAS_SEG_LOOP:
    movi        r23, 10
    blt         r21, r23, DEZENAS_SEG_FIM
    sub         r21, r21, r23
    addi        r20, r20, 1
    br          DEZENAS_SEG_LOOP
DEZENAS_SEG_FIM:
    mov         r4, r20
    call        CODIFICAR_7SEG
    slli        r22, r2, 8
    or          r19, r19, r22
    
    # === HEX0: UNIDADES DE SEGUNDOS (bits 7-0) ===
    mov         r4, r21                  # r21 já tem unidades de segundos
    call        CODIFICAR_7SEG
    or          r19, r19, r2
    
    # === ESCREVE NO HARDWARE ===
    movia       r23, HEX_BASE
    stwio       r19, (r23)              # Escreve todos os displays
    
    # --- Stack Frame Epilogue ---
    ldw         r23, 0(sp)
    ldw         r22, 4(sp)
    ldw         r21, 8(sp)
    ldw         r20, 12(sp)
    ldw         r19, 16(sp)
    ldw         r18, 20(sp)
    ldw         r17, 24(sp)
    ldw         r16, 28(sp)
    ldw         ra, 32(sp)
    addi        sp, sp, 36
    ret

#========================================================================================================================================
# CODIFICAÇÃO PARA DISPLAY 7-SEGMENTOS
#========================================================================================================================================
CODIFICAR_7SEG:
    # r4 = dígito (0-9), retorna em r2
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    # Validação de entrada
    movi        r17, 9
    bgt         r4, r17, INVALID_DIGIT
    blt         r4, r0, INVALID_DIGIT
    
    # Tabela de codificação 7-segmentos
    movia       r16, TABELA_7SEG
    slli        r17, r4, 2               # Multiplica por 4 (word)
    add         r16, r16, r17
    ldw         r2, (r16)                # Carrega código
    br          CODIF_EXIT
    
INVALID_DIGIT:
    movi        r2, 0x00                 # Display apagado
    
CODIF_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
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

# Buffer para entrada do usuário
.global BUFFER_ENTRADA  
BUFFER_ENTRADA:
    .skip 100

# Ponteiro para a posição atual no buffer de entrada
.global BUFFER_ENTRADA_POS
BUFFER_ENTRADA_POS:
    .word 0

# Estado anterior dos botões (para detecção de borda)
.global BOTOES_ESTADO_ANTERIOR
BOTOES_ESTADO_ANTERIOR:
    .word 0x0F                           # Inicializa com todos os botões em estado "não pressionado"

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

MSG_CRONOMETRO_INICIADO:
    .asciz "Cronometro iniciado!\n"

MSG_CRONOMETRO_CANCELADO:
    .asciz "Cronometro cancelado!\n"

MSG_CRONOMETRO_PAUSADO:
    .asciz "Cronometro pausado!\n"

MSG_CRONOMETRO_RETOMADO:
    .asciz "Cronometro retomado!\n"

MSG_DEBUG_TEMPO:
    .asciz "Tempo: %d segundos\n"

# Declarações externas
.global INTERRUPCAO_HANDLER
.global IMPRIMIR_STRING
.global MSG_CRONOMETRO_INICIADO
.global MSG_CRONOMETRO_CANCELADO
.global MSG_CRONOMETRO_PAUSADO
.global MSG_CRONOMETRO_RETOMADO
.global ATUALIZAR_DISPLAY_CRONOMETRO
.global CODIFICAR_7SEG
.extern _led
.extern _animacao  
.extern _cronometro
.extern _update_animation_step

.end
