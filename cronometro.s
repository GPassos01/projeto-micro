#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: cronometro.s
# Descrição: Sistema de Cronômetro com Displays 7-Segmentos
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
# Funcionalidades: Iniciar (20), Cancelar (21), Pausar/Retomar (KEY1)
#========================================================================================================================================

.set noat                               # CRÍTICO: Impede uso automático de r1 (at)

.global _cronometro

# Referências para símbolos globais definidos em interrupcoes.s
.extern CRONOMETRO_SEGUNDOS
.extern CRONOMETRO_PAUSADO
.extern CRONOMETRO_ATIVO
.extern CRONOMETRO_TICK_FLAG
.extern CONFIGURAR_TIMER
.extern PARAR_TIMER
# Para interação com animação
.extern FLAG_INTERRUPCAO
.extern RESTAURAR_ESTADO_LEDS

#========================================================================================================================================
# Definições e Constantes
#========================================================================================================================================
.equ HEX_BASE,              0x10000020      # Displays 7-segmentos (HEX3-0)
.equ KEY_BASE,              0x10000050      # Botões (KEY3-0)
.equ TIMER_BASE,            0x10002000      # Timer do sistema

# Configurações de timing
.equ CRONOMETRO_PERIODO,    50000000        # 1s a 50MHz (50M ciclos)

# Limites do cronômetro
.equ CRONOMETRO_MAX,        5999            # 99:59 (99*60 + 59 = 5999 segundos)

# Operações do cronômetro
.equ OP_INICIAR,            0               # Comando 20
.equ OP_CANCELAR,           1               # Comando 21

# Códigos ASCII
.equ ASCII_ZERO,            0x30            # '0'

# Offsets dos displays
.equ HEX0_OFFSET,           0               # Unidades de segundos
.equ HEX1_OFFSET,           4               # Dezenas de segundos  
.equ HEX2_OFFSET,           8               # Unidades de minutos
.equ HEX3_OFFSET,           12              # Dezenas de minutos

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DO CRONÔMETRO - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando (formato: "20" ou "21")
# Saída: nenhuma
#========================================================================================================================================
_cronometro:
    # --- Stack Frame Prologue (ABI Compliant) ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         fp, 0(sp)
    mov         fp, sp

    # Registradores usados (Caller-Saved):
    # r4: string de comando
    # r8: operação (0 ou 1)

    # Parseia a operação considerando espaço opcional
    # Primeiro assume que o formato é "2x" (sem espaço)
    ldb         r8, 1(r4)                  # Segundo caractere
    movi        r9, ' '                    # ASCII espaço (0x20)
    bne         r8, r9, PARSE_OP_OK        # Se não é espaço, ok

    # Se o segundo caractere é espaço, pega o terceiro
    ldb         r8, 2(r4)

PARSE_OP_OK:
    subi        r8, r8, ASCII_ZERO         # Converte '0'/'1' em 0/1

    # Executa a operação
    beq         r8, r0, INICIAR_CRONOMETRO
    br          CANCELAR_CRONOMETRO

#========================================================================================================================================
# OPERAÇÕES DO CRONÔMETRO
#========================================================================================================================================

INICIAR_CRONOMETRO:
    movia       r8, CRONOMETRO_ATIVO
    ldw         r9, (r8)
    bne         r9, r0, CRONOMETRO_JA_ATIVO

    # Se uma animação estiver ativa, desativa-a antes de iniciar o cronômetro
    movia       r10, FLAG_INTERRUPCAO
    ldw         r11, (r10)
    beq         r11, r0, CONTINUAR_INICIO_CRONO   # Nenhuma animação ativa

    # Limpa flag e restaura LEDs salvos pela animação
    stw         r0, (r10)
    call        RESTAURAR_ESTADO_LEDS

CONTINUAR_INICIO_CRONO:
    call        INICIALIZAR_ESTADO_CRONOMETRO
    # Configura e inicia timer do cronômetro
    movia       r4, CRONOMETRO_PERIODO
    call        CONFIGURAR_TIMER
    call        CONFIGURAR_KEY1_INTERRUPCAO
    movia       r8, CRONOMETRO_ATIVO
    movi        r9, 1
    stw         r9, (r8)
    call        ATUALIZAR_DISPLAY_CRONOMETRO
    br          FIM_CRONOMETRO

CANCELAR_CRONOMETRO:
    call        PARAR_TIMER
    movia       r8, CRONOMETRO_ATIVO
    stw         r0, (r8)
    movia       r8, CRONOMETRO_SEGUNDOS
    stw         r0, (r8)
    movia       r8, CRONOMETRO_PAUSADO
    stw         r0, (r8)
    call        LIMPAR_DISPLAYS

CRONOMETRO_JA_ATIVO:
    # Cronômetro já estava ativo, não faz nada
    
FIM_CRONOMETRO:
    # --- Stack Frame Epilogue (ABI Standard) ---
    # Restaura registradores na ordem inversa
    ldw         ra, 4(fp)
    ldw         fp, 0(fp)
    addi        sp, sp, 8
    ret

#========================================================================================================================================
# FUNÇÕES DE ESTADO DO CRONÔMETRO - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Inicializa estado do cronômetro
#------------------------------------------------------------------------
INICIALIZAR_ESTADO_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Zera contador de segundos
    movia       r16, CRONOMETRO_SEGUNDOS
    stw         r0, (r16)
    
    # Zera flag de pausado
    movia       r16, CRONOMETRO_PAUSADO
    stw         r0, (r16)
    
    # Limpa flag de tick
    movia       r16, CRONOMETRO_TICK_FLAG
    stw         r0, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#========================================================================================================================================
# FUNÇÕES DE DISPLAY - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Atualiza displays 7-segmentos com tempo do cronômetro
# Formato: MM:SS (HEX3 HEX2 : HEX1 HEX0)
#------------------------------------------------------------------------
ATUALIZAR_DISPLAY_CRONOMETRO:
    subi        sp, sp, 24
    stw         ra, 20(sp)
    stw         r16, 16(sp)
    stw         r17, 12(sp)
    stw         r18, 8(sp)
    stw         r19, 4(sp)
    stw         r20, 0(sp)
    movia       r8, CRONOMETRO_SEGUNDOS
    ldw         r16, (r8)
    movia       r19, HEX_BASE
    movi        r8, 60
    div         r17, r16, r8
    mul         r9, r17, r8
    sub         r18, r16, r9
    movi        r8, 10
    div         r20, r17, r8
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX3_OFFSET(r19)
    movi        r8, 10
    div         r9, r17, r8
    mul         r9, r9, r8
    sub         r20, r17, r9
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX2_OFFSET(r19)
    movi        r8, 10
    div         r20, r18, r8
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX1_OFFSET(r19)
    movi        r8, 10
    div         r9, r18, r8
    mul         r9, r9, r8
    sub         r20, r18, r9
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX0_OFFSET(r19)
    ldw         r20, 0(sp)
    ldw         r19, 4(sp)
    ldw         r18, 8(sp)
    ldw         r17, 12(sp)
    ldw         r16, 16(sp)
    ldw         ra, 20(sp)
    addi        sp, sp, 24
    ret

#------------------------------------------------------------------------
# Limpa todos os displays 7-segmentos
#------------------------------------------------------------------------
LIMPAR_DISPLAYS:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    movia       r16, HEX_BASE
    
    # Limpa todos os displays
    stwio       r0, HEX0_OFFSET(r16)     # HEX0
    stwio       r0, HEX1_OFFSET(r16)     # HEX1
    stwio       r0, HEX2_OFFSET(r16)     # HEX2
    stwio       r0, HEX3_OFFSET(r16)     # HEX3
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Codifica dígito para display 7-segmentos
# Entrada: r4 = dígito (0-9)
# Saída: r2 = código 7-segmentos
#------------------------------------------------------------------------
CODIFICAR_7SEG:
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    movi        r8, 9
    bgt         r4, r8, DIGITO_INVALIDO_7SEG
    blt         r4, r0, DIGITO_INVALIDO_7SEG
    movia       r16, TABELA_7SEG
    slli        r8, r4, 2
    add         r16, r16, r8
    ldw         r2, (r16)
    br          CODIF_7SEG_EXIT
DIGITO_INVALIDO_7SEG:
    movi        r2, 0x00
CODIF_7SEG_EXIT:
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#========================================================================================================================================
# CONFIGURAÇÃO DE INTERRUPÇÕES - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Configura interrupção do KEY1 para pause/resume
# TODO: Esta função seria implementada se houvesse suporte completo a múltiplas IRQs
#------------------------------------------------------------------------
CONFIGURAR_KEY1_INTERRUPCAO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 4
    stw         ra, 0(sp)
    
    # NOTA: Implementação simplificada
    # Em um sistema completo, configuraria IRQ1 para KEY1
    # Por enquanto, o controle de pause/resume seria feito via polling
    
    # --- Stack Frame Epilogue ---
    ldw         ra, 0(sp)
    addi        sp, sp, 4
    ret

# Referência para tabela 7-segmentos definida em main.s
.extern TABELA_7SEG
