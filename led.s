#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: led.s
# Descrição: Controle Individual de LEDs Vermelhos
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
#========================================================================================================================================

.global _led

# Referência para símbolo global definido em main.s
.extern LED_STATE

#========================================================================================================================================
# Definições e Constantes
#========================================================================================================================================
.equ LED_BASE,          0x10000000      # Base dos LEDs vermelhos (18 LEDs: 0-17)
.equ LED_MAX,           17               # LED máximo válido
.equ LED_MIN,           0                # LED mínimo válido

# Códigos ASCII
.equ ASCII_ZERO,        0x30             # '0'
.equ ASCII_NINE,        0x39             # '9'

# Operações
.equ OP_ACENDER,        0                # Comando 00xx
.equ OP_APAGAR,         1                # Comando 01xx

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DE CONTROLE DE LED - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando (formato: "00xx" ou "01xx")
# Saída: nenhuma
# Exemplo: "0015" = acender LED 15, "0103" = apagar LED 3
#========================================================================================================================================
_led:
    # --- Stack Frame Prologue (ABI Standard) ---
    # Salva registradores callee-saved que serão usados
    subi        sp, sp, 24
    stw         fp, 20(sp)              # Frame pointer (callee-saved)
    stw         ra, 16(sp)              # Return address (callee-saved)
    stw         r16, 12(sp)             # s0 - Command pointer (callee-saved)
    stw         r17, 8(sp)              # s1 - Operation (callee-saved)
    stw         r18, 4(sp)              # s2 - LED number (callee-saved)
    stw         r19, 0(sp)              # s3 - Current LED state (callee-saved)
    
    # Configura frame pointer conforme ABI
    mov         fp, sp
    
    # Copia argumento para registrador callee-saved
    mov         r16, r4                 # r16 = comando string
    
    # Extrai operação do comando (segundo caractere)
    call        EXTRAIR_OPERACAO
    mov         r17, r2                 # r17 = operação (0=acender, 1=apagar)
    
    # Verifica se operação é válida
    movi        r1, 1
    bgt         r17, r1, LED_INVALIDO   # Se operação > 1, inválida
    blt         r17, r0, LED_INVALIDO   # Se operação < 0, inválida
    
    # Extrai número do LED do comando
    call        EXTRAIR_NUMERO_LED
    mov         r18, r2                 # r18 = número do LED
    
    # Valida número do LED
    movi        r1, LED_MAX
    bgt         r18, r1, LED_INVALIDO   # Se LED > 17, inválido
    movi        r1, LED_MIN
    blt         r18, r1, LED_INVALIDO   # Se LED < 0, inválido
    
    # Carrega estado atual dos LEDs
    call        CARREGAR_ESTADO_LEDS
    mov         r19, r2                 # r19 = estado atual
    
    # Executa operação baseada no comando
    beq         r17, r0, EXECUTAR_ACENDER
    br          EXECUTAR_APAGAR

#========================================================================================================================================
# OPERAÇÕES DE LED
#========================================================================================================================================

EXECUTAR_ACENDER:
    # Acende LED específico (OR com bit correspondente)
    movi        r1, 1
    sll         r1, r1, r18             # r1 = 2^LED_number
    or          r19, r19, r1            # Set bit para acender LED
    br          ATUALIZAR_LEDS

EXECUTAR_APAGAR:
    # Apaga LED específico (AND com NOT do bit correspondente)
    movi        r1, 1
    sll         r1, r1, r18             # r1 = 2^LED_number
    nor         r1, r1, r1              # r1 = ~(2^LED_number)
    and         r19, r19, r1            # Clear bit para apagar LED
    
ATUALIZAR_LEDS:
    # Atualiza LEDs físicos e salva estado
    call        SALVAR_ESTADO_LEDS
    br          FIM_LED

LED_INVALIDO:
    # Comando inválido - não faz nada
    
FIM_LED:
    # --- Stack Frame Epilogue (ABI Standard) ---
    # Restaura registradores na ordem inversa
    ldw         r19, 0(fp)
    ldw         r18, 4(fp)
    ldw         r17, 8(fp)
    ldw         r16, 12(fp)
    ldw         ra, 16(fp)
    ldw         fp, 20(fp)
    addi        sp, sp, 24
    ret

#========================================================================================================================================
# FUNÇÕES DE PARSING - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Extrai operação do comando (segundo caractere)
# Entrada: r16 = ponteiro para comando
# Saída: r2 = operação (0=acender, 1=apagar)
#------------------------------------------------------------------------
EXTRAIR_OPERACAO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # CORRIGIDO: Resetar ponteiro e navegar para posição 1
    mov         r16, r4                 # Reseta para início do comando
    addi        r16, r16, 1             # Aponta para posição 1 (0X00)
    ldb         r1, (r16)               # Carrega caractere
    
    # Converte ASCII para número
    subi        r2, r1, ASCII_ZERO      # r2 = operação
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Extrai número do LED do comando (posições 2 e 3)
# Entrada: r16 = ponteiro para comando
# Saída: r2 = número do LED (0-17)
#------------------------------------------------------------------------
EXTRAIR_NUMERO_LED:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    # CORRIGIDO: Resetar ponteiro e navegar para posição 2
    mov         r16, r4                 # Reseta para início do comando
    addi        r16, r16, 2             # Aponta para posição 2 (00XX)
    ldb         r1, (r16)               # Carrega dígito dezena
    call        VALIDAR_DIGITO_ASCII
    beq         r2, r0, NUMERO_INVALIDO # Se não é dígito, erro
    
    subi        r17, r1, ASCII_ZERO     # r17 = dezena
    movi        r1, 10
    mul         r17, r17, r1            # r17 = dezena * 10
    
    # Extrai unidade (posição 3)
    addi        r16, r16, 1             # Aponta para posição 3
    ldb         r1, (r16)               # Carrega dígito unidade
    call        VALIDAR_DIGITO_ASCII
    beq         r2, r0, NUMERO_INVALIDO # Se não é dígito, erro
    
    subi        r1, r1, ASCII_ZERO      # r1 = unidade
    add         r2, r17, r1             # r2 = dezena + unidade
    br          NUMERO_VALIDO

NUMERO_INVALIDO:
    movi        r2, -1                  # Retorna valor inválido

NUMERO_VALIDO:
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#------------------------------------------------------------------------
# Valida se caractere é dígito ASCII (0-9)
# Entrada: r1 = caractere ASCII
# Saída: r2 = 1 se válido, 0 se inválido
#------------------------------------------------------------------------
VALIDAR_DIGITO_ASCII:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 4
    stw         ra, 0(sp)
    
    # Verifica se está no range ASCII_ZERO a ASCII_NINE
    movi        r2, 0                   # Assume inválido
    
    movi        r3, ASCII_ZERO
    blt         r1, r3, DIGITO_INVALIDO # Se < '0', inválido
    
    movi        r3, ASCII_NINE
    bgt         r1, r3, DIGITO_INVALIDO # Se > '9', inválido
    
    movi        r2, 1                   # Válido
    
DIGITO_INVALIDO:
    # --- Stack Frame Epilogue ---
    ldw         ra, 0(sp)
    addi        sp, sp, 4
    ret

#========================================================================================================================================
# FUNÇÕES DE ESTADO DOS LEDS - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Carrega estado atual dos LEDs
# Saída: r2 = estado atual dos LEDs
#------------------------------------------------------------------------
CARREGAR_ESTADO_LEDS:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Carrega da variável de estado
    movia       r16, LED_STATE
    ldw         r2, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Salva estado dos LEDs na memória e atualiza hardware
# Entrada: r19 = novo estado dos LEDs
#------------------------------------------------------------------------
SALVAR_ESTADO_LEDS:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Salva na variável de estado
    movia       r16, LED_STATE
    stw         r19, (r16)
    
    # Atualiza LEDs físicos
    movia       r16, LED_BASE
    stwio       r19, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret
