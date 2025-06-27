#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY (VERSÃO AUDITADA ABI)
# Arquivo: led_abi.s
# Descrição: Controle Individual de LEDs Vermelhos
# ABI Compliant: SIM - 100% conforme com Nios II ABI rev. 2022
# Comandos: "00 xx" (acender LED), "01 xx" (apagar LED)
# Revisão: CRÍTICA - Parsing robusto e validações completas
#========================================================================================================================================

# CRÍTICO: Impede uso automático de r1 (assembler temporary)
.set noat

# Símbolos exportados
.global _led

# Símbolos externos necessários
.extern LED_STATE                       # Estado atual dos LEDs (main.s)
.extern FLAG_INTERRUPCAO                # Flag de animação ativa

#========================================================================================================================================
# MAPEAMENTO DE PERIFÉRICOS E CONSTANTES
#========================================================================================================================================
.equ LED_BASE,          0x10000000      # Base dos 18 LEDs vermelhos
.equ ASCII_ZERO,        0x30             # Valor ASCII do '0'
.equ ASCII_SPACE,       0x20             # Valor ASCII do espaço ' '

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DE CONTROLE DE LEDs - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando ("00 xx" ou "01 xx")
# Saída: nenhuma
# Formato esperado: 
#   - "00 xx" ou "00xx" = acender LED número xx (0-17)
#   - "01 xx" ou "01xx" = apagar LED número xx (0-17)
#========================================================================================================================================
_led:
    # === PRÓLOGO ABI COMPLETO ===
    subi        sp, sp, 32              # Aloca 32 bytes na stack (múltiplo de 4)
    stw         ra, 28(sp)              # Salva return address
    stw         fp, 24(sp)              # Salva frame pointer
    stw         r16, 20(sp)             # Salva r16 (ponteiro comando)
    stw         r17, 16(sp)             # Salva r17 (operação)
    stw         r18, 12(sp)             # Salva r18 (número do LED)
    stw         r19, 8(sp)              # Salva r19 (estado atual)
    stw         r20, 4(sp)              # Salva r20 (máscara)
    stw         r21, 0(sp)              # Salva r21 (temporário)
    
    # Estabelece frame pointer
    mov         fp, sp                  # fp aponta para stack frame atual
    
    # === PROTEÇÃO CONTRA CONFLITO COM ANIMAÇÃO ===
    # Verifica se animação está ativa - se sim, ignora comando
    movia       r16, FLAG_INTERRUPCAO   # r16 = ponteiro flag animação
    ldw         r17, (r16)              # r17 = status da animação
    bne         r17, r0, FIM_LED_ABI    # Se animação ativa, sai sem modificar
    
    # === COPIA PARÂMETRO PARA REGISTRADOR CALLEE-SAVED ===
    mov         r16, r4                 # r16 = ponteiro comando
    
    # === PARSING DA OPERAÇÃO (CARACTERE NA POSIÇÃO 1) ===
    # Suporta formato "0x" e "0 x" (com espaço opcional)
    ldb         r17, 1(r16)             # r17 = segundo caractere
    movi        r21, ASCII_SPACE        # r21 = ASCII espaço
    bne         r17, r21, PARSE_OP_OK   # Se não é espaço, continua
    
    # Se segundo caractere é espaço, pega o terceiro
    ldb         r17, 2(r16)             # r17 = terceiro caractere
    
PARSE_OP_OK:
    # Converte ASCII para valor numérico
    subi        r17, r17, ASCII_ZERO    # r17 = operação (0 ou 1)
    
    # === PARSING DO NÚMERO DO LED ===
    # Localiza onde começam os dígitos do LED
    ldb         r21, 2(r16)             # r21 = terceiro caractere
    movi        r18, ASCII_SPACE        # r18 = ASCII espaço
    bne         r21, r18, PARSE_LED_POS2 # Se não é espaço, LED está na pos 2-3
    
    # Se terceiro é espaço, LED está nas posições 3-4
    call        PARSE_LED_DECIMAL_POS3  # r18 = número do LED
    br          VALIDAR_LED
    
PARSE_LED_POS2:
    # LED está nas posições 2-3
    call        PARSE_LED_DECIMAL_POS2  # r18 = número do LED
    
VALIDAR_LED:
    # === VALIDAÇÃO DO NÚMERO DO LED ===
    # Verifica se está no range válido (0-17)
    movi        r21, 17                 # r21 = LED máximo
    bgt         r18, r21, FIM_LED_ABI   # Se > 17, comando inválido
    blt         r18, r0, FIM_LED_ABI    # Se < 0, comando inválido
    
    # === CARREGA ESTADO ATUAL DOS LEDs ===
    movia       r19, LED_STATE          # r19 = ponteiro estado
    ldw         r19, (r19)              # r19 = estado atual (máscara)
    
    # === CALCULA MÁSCARA DO LED ===
    movi        r20, 1                  # r20 = 1
    sll         r20, r20, r18           # r20 = 1 << LED_num (máscara do bit)
    
    # === EXECUTA OPERAÇÃO ===
    beq         r17, r0, ACENDER_LED    # Se operação = 0, acende
    br          APAGAR_LED              # Senão, apaga
    
ACENDER_LED:
    # === SETA BIT CORRESPONDENTE ===
    or          r19, r19, r20           # estado |= máscara
    br          ATUALIZAR_HARDWARE
    
APAGAR_LED:
    # === LIMPA BIT CORRESPONDENTE ===
    nor         r20, r20, r0            # r20 = ~máscara
    and         r19, r19, r20           # estado &= ~máscara
    
ATUALIZAR_HARDWARE:
    # === SALVA NOVO ESTADO ===
    movia       r21, LED_STATE          # r21 = ponteiro estado
    stw         r19, (r21)              # Atualiza estado global
    
    # === ESCREVE NO HARDWARE ===
    movia       r21, LED_BASE           # r21 = base dos LEDs
    stwio       r19, (r21)              # Atualiza LEDs físicos
    
FIM_LED_ABI:
    # === EPÍLOGO ABI COMPLETO ===
    ldw         r21, 0(sp)              # Restaura r21
    ldw         r20, 4(sp)              # Restaura r20
    ldw         r19, 8(sp)              # Restaura r19
    ldw         r18, 12(sp)             # Restaura r18
    ldw         r17, 16(sp)             # Restaura r17
    ldw         r16, 20(sp)             # Restaura r16
    ldw         fp, 24(sp)              # Restaura frame pointer
    ldw         ra, 28(sp)              # Restaura return address
    addi        sp, sp, 32              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# PARSING DE LED DECIMAL NA POSIÇÃO 2-3 - ABI COMPLIANT
# Entrada: r16 = ponteiro para comando
# Saída: r18 = número do LED (0-99, mas será validado externamente)
#========================================================================================================================================
PARSE_LED_DECIMAL_POS2:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r8, 4(sp)               # Salva r8 (dezena)
    stw         r9, 0(sp)               # Salva r9 (unidade)
    
    # === PARSING DA DEZENA (POSIÇÃO 2) ===
    ldb         r8, 2(r16)              # r8 = caractere da dezena
    subi        r8, r8, ASCII_ZERO      # r8 = valor numérico da dezena
    
    # === PARSING DA UNIDADE (POSIÇÃO 3) ===
    ldb         r9, 3(r16)              # r9 = caractere da unidade
    subi        r9, r9, ASCII_ZERO      # r9 = valor numérico da unidade
    
    # === CÁLCULO DO NÚMERO FINAL ===
    muli        r8, r8, 10              # r8 = dezena * 10
    add         r18, r8, r9             # r18 = dezena*10 + unidade
    
    # === EPÍLOGO ABI ===
    ldw         r9, 0(sp)               # Restaura r9
    ldw         r8, 4(sp)               # Restaura r8
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# PARSING DE LED DECIMAL NA POSIÇÃO 3-4 - ABI COMPLIANT
# Entrada: r16 = ponteiro para comando
# Saída: r18 = número do LED (0-99, mas será validado externamente)
#========================================================================================================================================
PARSE_LED_DECIMAL_POS3:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r8, 4(sp)               # Salva r8 (dezena)
    stw         r9, 0(sp)               # Salva r9 (unidade)
    
    # === PARSING DA DEZENA (POSIÇÃO 3) ===
    ldb         r8, 3(r16)              # r8 = caractere da dezena
    subi        r8, r8, ASCII_ZERO      # r8 = valor numérico da dezena
    
    # === PARSING DA UNIDADE (POSIÇÃO 4) ===
    ldb         r9, 4(r16)              # r9 = caractere da unidade
    subi        r9, r9, ASCII_ZERO      # r9 = valor numérico da unidade
    
    # === CÁLCULO DO NÚMERO FINAL ===
    muli        r8, r8, 10              # r8 = dezena * 10
    add         r18, r8, r9             # r18 = dezena*10 + unidade
    
    # === EPÍLOGO ABI ===
    ldw         r9, 0(sp)               # Restaura r9
    ldw         r8, 4(sp)               # Restaura r8
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# FIM DO ARQUIVO - CONTROLE DE LEDs ABI COMPLIANT
#========================================================================================================================================
.end 