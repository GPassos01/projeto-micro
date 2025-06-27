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
    subi        sp, sp, 20
    stw         fp, 16(sp)
    stw         ra, 12(sp)
    stw         r16, 8(sp)              # s0 - LED state
    stw         r17, 4(sp)              # s1 - LED number
    stw         r18, 0(sp)              # s2 - Operation
    
    mov         fp, sp
    
    # --- PARSING OTIMIZADO (In-line) ---
    
    # Extrai Operação (char na posição 1, ex: "01xx")
    ldb         r18, 1(r4)              # Carrega '1'
    subi        r18, r18, ASCII_ZERO    # r18 = 1 (operação)

    # Extrai Dezena do LED (char na posição 2, ex: "01xx")
    ldb         r17, 2(r4)              # Carrega 'x' dezena
    subi        r17, r17, ASCII_ZERO    
    movi        r1, 10
    mul         r17, r17, r1            # r17 = dezena * 10

    # Extrai Unidade do LED (char na posição 3, ex: "01xx")
    ldb         r1, 3(r4)               # Carrega 'x' unidade
    subi        r1, r1, ASCII_ZERO
    add         r17, r17, r1            # r17 = (dezena * 10) + unidade
    
    # --- VALIDAÇÃO ---
    movi        r1, LED_MAX
    bgt         r17, r1, FIM_LED        # Se LED > 17, sai
    blt         r17, r0, FIM_LED        # Se LED < 0, sai
    
    # --- LÓGICA ---
    movia       r1, LED_STATE
    ldw         r16, (r1)               # Carrega estado atual
    
    beq         r18, r0, ACENDER_LED_OP
    br          APAGAR_LED_OP

ACENDER_LED_OP:
    movi        r1, 1
    sll         r1, r1, r17             # r1 = 1 << numero_do_led
    or          r16, r16, r1            # Acende o bit
    br          ATUALIZAR_ESTADO_LED

APAGAR_LED_OP:
    movi        r1, 1
    sll         r1, r1, r17
    nor         r1, r1, r1
    and         r16, r16, r1            # Apaga o bit

ATUALIZAR_ESTADO_LED:
    movia       r1, LED_BASE
    stwio       r16, (r1)
    movia       r1, LED_STATE
    stw         r16, (r1)

FIM_LED:
    # --- Stack Frame Epilogue (ABI Standard) ---
    ldw         r18, 0(fp)
    ldw         r17, 4(fp)
    ldw         r16, 8(fp)
    ldw         ra, 12(fp)
    ldw         fp, 16(fp)
    addi        sp, sp, 20
    ret
