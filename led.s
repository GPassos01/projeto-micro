#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: led.s
# Descrição: Controle Individual de LEDs Vermelhos
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
#========================================================================================================================================

.global _led

# Referência para símbolo global definido em main.s
.extern LED_STATE
.extern FLAG_INTERRUPCAO

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
    # --- Stack Frame Prologue (ABI Compliant) ---
    subi        sp, sp, 8
    stw         ra, 4(sp)               # Salva endereço de retorno
    stw         fp, 0(sp)               # Salva o frame pointer antigo
    mov         fp, sp                  # Aponta o fp para o novo frame

    # Se animação está ativa, não altera LEDs para evitar conflito
    movia       r12, FLAG_INTERRUPCAO
    ldw         r13, (r12)
    bne         r13, r0, FIM_LED_ABI

    # Registradores usados (Todos Caller-Saved, seguros para uso temporário):
    # r4: string de comando (argumento)
    # r8: estado atual dos LEDs
    # r9: número do LED (calculado)
    # r10: temporário para máscara/cálculos
    # r11: operação (acender/apagar)

    # --- PARSING E LÓGICA 100% ABI-COMPLIANT ---
    
    # Carrega o estado atual dos LEDs da nossa variável de controle
    movia       r10, LED_STATE
    ldw         r8, (r10)               # r8 = current_state

    # 1. Parseia o número do LED (xx)
    # Extrai a dezena (char na posição 3, pulando o espaço)
    ldb         r9, 3(r4)
    subi        r9, r9, ASCII_ZERO
    slli        r10, r9, 3              # r10 = dezena * 8 
    slli        r9, r9, 1               # r9 = dezena * 2
    add         r9, r9, r10             # r9 = dezena * 10
    
    # Adiciona a unidade (char na posição 4)
    ldb         r10, 4(r4)
    subi        r10, r10, ASCII_ZERO
    add         r9, r9, r10             # r9 = led_number

    # 2. Valida o número do LED
    movi        r10, LED_MAX
    bgt         r9, r10, FIM_LED_ABI    # Se LED > 17, sai
    blt         r9, r0, FIM_LED_ABI     # Se LED < 0, sai
    
    # 3. Cria a máscara de bit
    movi        r10, 1
    sll         r10, r10, r9            # r10 = bit mask

    # 4. Determina a operação e a executa
    ldb         r11, 1(r4)              # r11 = operation char
    subi        r11, r11, ASCII_ZERO    # r11 = operation num
    beq         r11, r0, ACENDER_LED_OP_ABI # Se for '0', vai para ACENDER

APAGAR_LED_OP_ABI:
    nor         r10, r10, r10           # Inverte a máscara
    and         r8, r8, r10             # state = state & ~mask
    br          ATUALIZAR_ESTADO_LED_ABI

ACENDER_LED_OP_ABI:
    or          r8, r8, r10             # state = state | mask

ATUALIZAR_ESTADO_LED_ABI:
    # Atualiza tanto os LEDs físicos quanto a nossa variável de estado
    movia       r10, LED_BASE
    stwio       r8, (r10)
    movia       r10, LED_STATE
    stw         r8, (r10)

FIM_LED_ABI:
    # --- Stack Frame Epilogue ---
    ldw         ra, 4(fp)
    ldw         fp, 0(fp)
    addi        sp, sp, 8
    ret
