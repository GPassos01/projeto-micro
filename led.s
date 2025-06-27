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
    stw         r16, 8(sp)              # s0 - current LED state
    stw         r17, 4(sp)              # s1 - led number
    stw         r18, 0(sp)              # s2 - temp/mask
    mov         fp, sp

    # --- PARSING OTIMIZADO E LÓGICA ---
    
    # Carrega o estado atual dos LEDs da nossa variável de controle
    movia       r18, LED_STATE
    ldw         r16, (r18)

    # 1. Parseia o número do LED (xx)
    # Extrai a dezena (char na posição 2)
    ldb         r17, 2(r4)
    subi        r17, r17, ASCII_ZERO
    slli        r1, r17, 3              # r1 = dezena * 8
    slli        r17, r17, 1             # r17 = dezena * 2
    add         r17, r17, r1            # r17 = dezena * 10
    
    # Adiciona a unidade (char na posição 3)
    ldb         r1, 3(r4)
    subi        r1, r1, ASCII_ZERO
    add         r17, r17, r1            # r17 = (d*10) + u

    # 2. Valida o número do LED
    movi        r1, LED_MAX
    bgt         r17, r1, FIM_LED        # Se LED > 17, sai
    blt         r17, r0, FIM_LED        # Se LED < 0, sai
    
    # 3. Cria a máscara de bit (ex: 1 << 5 para o LED 5)
    movi        r18, 1
    sll         r18, r18, r17           # r18 = máscara de bit

    # 4. Determina a operação e a executa
    ldb         r1, 1(r4)               # Carrega o caractere da operação ('0' ou '1')
    subi        r1, r1, ASCII_ZERO
    beq         r1, r0, ACENDER_LED_OP  # Se for '0', vai para ACENDER

APAGAR_LED_OP:
    nor         r18, r18, r18           # Inverte a máscara para limpar o bit
    and         r16, r16, r18           # state = state & ~mask
    br          ATUALIZAR_ESTADO_LED

ACENDER_LED_OP:
    or          r16, r16, r18           # state = state | mask

ATUALIZAR_ESTADO_LED:
    # Atualiza tanto os LEDs físicos quanto a nossa variável de estado
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
