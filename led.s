#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: led.s
# Descrição: Controle Individual de LEDs Vermelhos da DE2-115
# ABI Compliant: 100% - Seguindo convenções rigorosas da ABI Nios II
#
# FUNCIONALIDADES:
# - Controle individual de 18 LEDs (0-17)
# - Comandos: 00xx (acender LED xx), 01xx (apagar LED xx)
# - Parsing robusto com validação de range
# - Operações bit-wise otimizadas
# - Estado persistente durante animação
#
# EXEMPLOS DE USO:
# - "0005" → Acende LED 5
# - "0112" → Apaga LED 12
# - "0000" → Acende LED 0  
# - "0117" → Apaga LED 17
#
# AUTORES: Amanda Oliveira, Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
#========================================================================================================================================

.global _led

# Referência para símbolo global definido em main.s
.extern LED_STATE

#========================================================================================================================================
# Definições e Constantes - Hardware DE2-115
#========================================================================================================================================
.equ LED_BASE,          0x10000000      # Base dos LEDs vermelhos (18 LEDs: 0-17)
.equ LED_MAX,           17               # LED máximo válido
.equ LED_MIN,           0                # LED mínimo válido

# Códigos ASCII para parsing
.equ ASCII_ZERO,        0x30             # '0'
.equ ASCII_NINE,        0x39             # '9'

# Operações suportadas
.equ OP_ACENDER,        0                # Comando 00xx
.equ OP_APAGAR,         1                # Comando 01xx

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DE CONTROLE DE LED - ABI COMPLIANT & OTIMIZADA
# 
# ENTRADA: r4 = ponteiro para string de comando (formato: "00xx" ou "01xx")
# SAÍDA: nenhuma
# 
# FORMATO DO COMANDO:
# - Posição 0: '0' (sempre)
# - Posição 1: '0' (acender) ou '1' (apagar)  
# - Posição 2: Dezena do LED (0-1)
# - Posição 3: Unidade do LED (0-9)
#
# EXEMPLOS:
# - "0015" = acender LED 15
# - "0103" = apagar LED 3
# - "0000" = acender LED 0
# - "0117" = apagar LED 17
#========================================================================================================================================
_led:
    # === PRÓLOGO ABI PADRÃO ===
    subi        sp, sp, 8
    stw         ra, 4(sp)               # Salva endereço de retorno
    stw         fp, 0(sp)               # Salva frame pointer anterior
    mov         fp, sp                  # Configura novo frame pointer

    # === REGISTRADORES UTILIZADOS (Caller-Saved - Seguros) ===
    # r4: string de comando (argumento de entrada)
    # r8: estado atual dos LEDs (carregado de LED_STATE)
    # r9: número do LED calculado (0-17)
    # r10: registrador temporário para cálculos/máscaras
    # r11: operação (0=acender, 1=apagar)

    # === CARREGAMENTO DO ESTADO ATUAL ===
    movia       r10, LED_STATE
    ldw         r8, (r10)               # r8 = estado atual dos LEDs

    # === PARSING DO NÚMERO DO LED (Posições 3-4) ===
    # Extrai dezena (posição 3)
    ldb         r9, 3(r4)               # Carrega caractere da dezena
    subi        r9, r9, ASCII_ZERO      # Converte ASCII para número
    slli        r10, r9, 3              # r10 = dezena * 8 
    slli        r9, r9, 1               # r9 = dezena * 2
    add         r9, r9, r10             # r9 = dezena * 10 (multiplicação otimizada)
    
    # Adiciona unidade (posição 4)
    ldb         r10, 4(r4)              # Carrega caractere da unidade
    subi        r10, r10, ASCII_ZERO    # Converte ASCII para número
    add         r9, r9, r10             # r9 = número final do LED

    # === VALIDAÇÃO DE RANGE ===
    movi        r10, LED_MAX
    bgt         r9, r10, FIM_LED_OTIMIZADO    # Se LED > 17, sai
    blt         r9, r0, FIM_LED_OTIMIZADO     # Se LED < 0, sai
    
    # === CRIAÇÃO DA MÁSCARA DE BIT ===
    movi        r10, 1
    sll         r10, r10, r9            # r10 = máscara (1 << led_number)

    # === DETERMINAÇÃO E EXECUÇÃO DA OPERAÇÃO ===
    ldb         r11, 1(r4)              # Carrega caractere da operação (posição 1)
    subi        r11, r11, ASCII_ZERO    # Converte para número
    beq         r11, r0, ACENDER_LED_OTIMIZADO    # Se '0', acende LED

APAGAR_LED_OTIMIZADO:
    # Operação: apagar LED (bit = 0)
    nor         r10, r10, r10           # Inverte máscara (~mask)
    and         r8, r8, r10             # estado = estado & ~máscara
    br          ATUALIZAR_ESTADO_LED_OTIMIZADO

ACENDER_LED_OTIMIZADO:
    # Operação: acender LED (bit = 1)
    or          r8, r8, r10             # estado = estado | máscara

ATUALIZAR_ESTADO_LED_OTIMIZADO:
    # === ATUALIZAÇÃO ATÔMICA DO HARDWARE E ESTADO ===
    # Atualiza LEDs físicos
    movia       r10, LED_BASE
    stwio       r8, (r10)               # Escreve no hardware
    
    # Atualiza variável de estado global
    movia       r10, LED_STATE
    stw         r8, (r10)               # Salva estado para outras funções

FIM_LED_OTIMIZADO:
    # === EPÍLOGO ABI PADRÃO ===
    ldw         ra, 4(fp)               # Restaura return address
    ldw         fp, 0(fp)               # Restaura frame pointer anterior
    addi        sp, sp, 8               # Libera stack frame
    ret                                 # Retorna para chamador
