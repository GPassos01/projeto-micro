#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: cronometro.s
# Descrição: Sistema de Cronômetro Digital MM:SS com Displays 7-Segmentos
# ABI Compliant: 100% - Seguindo convenções rigorosas da ABI Nios II
#
# FUNCIONALIDADES PRINCIPAIS:
# - Cronômetro digital formato MM:SS (00:00 até 99:59)
# - Displays 7-segmentos dedicados (HEX3-HEX0)
# - Controle via comandos UART e botão físico KEY1
# - Função pause/resume em tempo real
# - Timer compartilhado inteligente com animação
# - Overflow automático em 99:59 → 00:00
#
# COMANDOS SUPORTADOS:
# - "20" → Inicia cronômetro (00:00)
# - "21" → Cancela cronômetro e zera displays
# - KEY1 → Pausa/Resume cronômetro (quando ativo)
#
# FORMATO DE DISPLAY:
# - HEX3: Dezenas de minutos (0-9)
# - HEX2: Unidades de minutos (0-9)  
# - HEX1: Dezenas de segundos (0-5)
# - HEX0: Unidades de segundos (0-9)
#
# AUTORES: Amanda Oliveira, Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
#========================================================================================================================================

.global _cronometro

# Referências para símbolos globais definidos em interrupcoes.s
.extern CRONOMETRO_SEGUNDOS
.extern CRONOMETRO_PAUSADO
.extern CRONOMETRO_ATIVO
.extern CRONOMETRO_TICK_FLAG
.extern ANIMATION_STATE
.extern CRONOMETRO_CONTADOR_TICKS
.extern FLAG_INTERRUPCAO

#========================================================================================================================================
# Definições e Constantes - Hardware DE2-115
#========================================================================================================================================
.equ HEX_BASE,              0x10000020      # Displays 7-segmentos (HEX3-0)
.equ KEY_BASE,              0x10000050      # Botões (KEY3-0)
.equ TIMER_BASE,            0x10002000      # Timer do sistema

# Configurações de timing do sistema
.equ CRONOMETRO_PERIODO,    50000000        # 1s @ 50MHz (50M ciclos)
.equ ANIMACAO_PERIODO,       10000000       # 200ms @ 50MHz (10M ciclos)

# Limites e constantes do cronômetro
.equ CRONOMETRO_MAX,        5999            # 99:59 (99*60 + 59 = 5999 segundos)
.equ MINUTOS_POR_HORA,      60              # Divisor para cálculo de minutos
.equ DEZENAS,               10              # Divisor para separar dezenas/unidades

# Operações do cronômetro
.equ OP_INICIAR,            0               # Comando 20
.equ OP_CANCELAR,           1               # Comando 21

# Códigos ASCII para parsing
.equ ASCII_ZERO,            0x30            # '0'

# Máscaras para displays 7-segmentos (32 bits)
.equ HEX3_SHIFT,            24              # Bits 31-24: HEX3 (dezenas minutos)
.equ HEX2_SHIFT,            16              # Bits 23-16: HEX2 (unidades minutos)
.equ HEX1_SHIFT,            8               # Bits 15-8:  HEX1 (dezenas segundos)
.equ HEX0_SHIFT,            0               # Bits 7-0:   HEX0 (unidades segundos)

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DO CRONÔMETRO - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando (formato: "20" ou "21")
# Saída: nenhuma
#========================================================================================================================================
_cronometro:
    # --- Stack Frame Prologue (ABI Standard) ---
    # Salva registradores callee-saved que serão usados
    subi        sp, sp, 28
    stw         fp, 24(sp)              # Frame pointer (callee-saved)
    stw         ra, 20(sp)              # Return address (callee-saved)
    stw         r16, 16(sp)             # s0 - Command pointer (callee-saved)
    stw         r17, 12(sp)             # s1 - Operation (callee-saved)
    stw         r18, 8(sp)              # s2 - Temp 1 (callee-saved)
    stw         r19, 4(sp)              # s3 - Temp 2 (callee-saved)
    stw         r20, 0(sp)              # s4 - Spare (callee-saved)
    
    # Configura frame pointer conforme ABI
    mov         fp, sp
    
    # Copia argumento para registrador callee-saved
    mov         r16, r4                 # r16 = comando string
    
    # Extrai operação do comando (segundo caractere)
    call        EXTRAIR_OPERACAO_CRONOMETRO
    mov         r17, r2                 # r17 = operação (0=iniciar, 1=cancelar)
    
    # Executa operação baseada no comando
    beq         r17, r0, INICIAR_CRONOMETRO
    br          CANCELAR_CRONOMETRO

#========================================================================================================================================
# OPERAÇÕES DO CRONÔMETRO
#========================================================================================================================================

INICIAR_CRONOMETRO:
    # Verifica se cronômetro já está ativo
    movia       r18, CRONOMETRO_ATIVO
    ldw         r19, (r18)
    bne         r19, r0, CRONOMETRO_JA_ATIVO
    
    # PARA QUALQUER TIMER ATIVO PRIMEIRO (CRÍTICO!)
    call        PARAR_TIMER_SISTEMA
    
    # Inicializa estado do cronômetro
    call        INICIALIZAR_ESTADO_CRONOMETRO
    
    # Configura e inicia timer do cronômetro
    call        CONFIGURAR_TIMER_CRONOMETRO
    
    # Configura interrupção do KEY1 para pause/resume
    call        CONFIGURAR_KEY1_INTERRUPCAO
    
    # Ativa cronômetro
    movia       r18, CRONOMETRO_ATIVO
    movi        r19, 1
    stw         r19, (r18)
    
    # Mensagem de confirmação
    movia       r4, MSG_CRONOMETRO_INICIADO
    call        IMPRIMIR_STRING
    
    # Atualiza display inicial
    call        ATUALIZAR_DISPLAY_CRONOMETRO
    
    br          FIM_CRONOMETRO

CANCELAR_CRONOMETRO:
    # Verifica se animação está ativa antes de parar timer
    movia       r18, FLAG_INTERRUPCAO
    ldw         r19, (r18)
    bne         r19, r0, CANCELAR_APENAS_CRONOMETRO
    
    # Animação não está ativa - pode parar timer completamente
    call        PARAR_TIMER_SISTEMA
    br          FINALIZAR_CANCELAMENTO_CRONOMETRO
    
CANCELAR_APENAS_CRONOMETRO:
    # Animação está ativa - reconfigura timer para período da animação
    call        RECONFIGURAR_TIMER_PARA_ANIMACAO
    
FINALIZAR_CANCELAMENTO_CRONOMETRO:
    # Desativa cronômetro
    movia       r18, CRONOMETRO_ATIVO
    stw         r0, (r18)
    
    # Zera flag de tick do cronômetro
    movia       r18, CRONOMETRO_TICK_FLAG
    stw         r0, (r18)
    
    # Zera contador de ticks
    movia       r18, CRONOMETRO_CONTADOR_TICKS
    stw         r0, (r18)
    
    # Zera cronômetro
    movia       r18, CRONOMETRO_SEGUNDOS
    stw         r0, (r18)
    
    # Limpa displays
    movia       r18, HEX_BASE
    stwio       r0, (r18)
    
    # Mensagem de confirmação
    movia       r4, MSG_CRONOMETRO_CANCELADO
    call        IMPRIMIR_STRING
    
CRONOMETRO_JA_ATIVO:
    # Cronômetro já estava ativo, não faz nada
    
FIM_CRONOMETRO:
    # --- Stack Frame Epilogue (ABI Standard) ---
    # Restaura registradores na ordem inversa
    ldw         r20, 0(fp)
    ldw         r19, 4(fp)
    ldw         r18, 8(fp)
    ldw         r17, 12(fp)
    ldw         r16, 16(fp)
    ldw         ra, 20(fp)
    ldw         fp, 24(fp)
    addi        sp, sp, 28
    ret

#========================================================================================================================================
# FUNÇÕES DE PARSING - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Extrai operação do comando do cronômetro (segundo caractere)
# Entrada: r16 = ponteiro para comando
# Saída: r2 = operação (0=iniciar, 1=cancelar)
#------------------------------------------------------------------------
EXTRAIR_OPERACAO_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 16
    stw         ra, 12(sp)
    stw         r16, 8(sp)
    stw         r17, 4(sp)
    stw         r18, 0(sp)
    
    # Lê segundo caractere (posição 1)
    addi        r16, r16, 1             # Aponta para posição 1
    ldb         r17, (r16)              # Carrega caractere
    
    # Converte ASCII para número usando registrador callee-saved
    subi        r18, r17, ASCII_ZERO    # r18 = operação
    
    # Move resultado para registrador de retorno
    mov         r2, r18
    
    # --- Stack Frame Epilogue ---
    ldw         r18, 0(sp)
    ldw         r17, 4(sp)
    ldw         r16, 8(sp)
    ldw         ra, 12(sp)
    addi        sp, sp, 16
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
# FUNÇÕES DE TIMER - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Para o timer do sistema de forma robusta (para prevenir conflitos)
#------------------------------------------------------------------------
PARAR_TIMER_SISTEMA:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    movia       r16, TIMER_BASE
    
    # Para timer primeiro
    stwio       r0, 4(r16)              # control = 0
    
    # Limpa flag de timeout
    movi        r17, 1
    stwio       r17, 0(r16)             # status = 1
    
    # Desabilita interrupções do timer temporariamente
    wrctl       ienable, r0             # Desabilita todas IRQs
    
    # Pequeno delay para garantir que timer parou
    movi        r17, 1000
DELAY_PARAR:
    subi        r17, r17, 1
    bne         r17, r0, DELAY_PARAR
    
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#------------------------------------------------------------------------
# Configura e inicia timer para cronômetro
#------------------------------------------------------------------------
CONFIGURAR_TIMER_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 20
    stw         ra, 16(sp)
    stw         r16, 12(sp)
    stw         r17, 8(sp)
    stw         r18, 4(sp)
    stw         r19, 0(sp)
    
    movia       r16, TIMER_BASE
    
    # Para timer primeiro (segurança)
    stwio       r0, 4(r16)              # Control = 0
    
    # Verifica se animação está ativa para escolher período
    movia       r18, FLAG_INTERRUPCAO
    ldw         r19, (r18)
    bne         r19, r0, USAR_PERIODO_ANIMACAO
    
    # Apenas cronômetro - usa período de 1s
    movia       r17, CRONOMETRO_PERIODO
    br          CONFIGURAR_PERIODO
    
USAR_PERIODO_ANIMACAO:
    # Animação ativa - usa período de 200ms (animação)
    movia       r17, ANIMACAO_PERIODO
    
    # Zera contador de ticks do cronômetro
    movia       r18, CRONOMETRO_CONTADOR_TICKS
    stw         r0, (r18)
    
CONFIGURAR_PERIODO:
    # Bits baixos do período
    andi        r18, r17, 0xFFFF
    stwio       r18, 8(r16)             # periodl
    
    # Bits altos do período  
    srli        r17, r17, 16
    stwio       r17, 12(r16)            # periodh
    
    # Limpa flag de timeout pendente
    movi        r18, 1
    stwio       r18, 0(r16)             # status = 1 (limpa TO)
    
    # Habilita interrupções do timer
    movi        r18, 1                  # IRQ0 para timer
    wrctl       ienable, r18
    wrctl       status, r18             # Habilita PIE
    
    # Inicia timer: START=1, CONT=1, ITO=1
    movi        r18, 7                  # 0b111
    stwio       r18, 4(r16)             # control
    
    # --- Stack Frame Epilogue ---
    ldw         r19, 0(sp)
    ldw         r18, 4(sp)
    ldw         r17, 8(sp)
    ldw         r16, 12(sp)
    ldw         ra, 16(sp)
    addi        sp, sp, 20
    ret

#------------------------------------------------------------------------
# Para timer do cronômetro de forma robusta
#------------------------------------------------------------------------
PARAR_TIMER_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    movia       r16, TIMER_BASE
    
    # Para timer primeiro
    stwio       r0, 4(r16)              # control = 0
    
    # Limpa flag de timeout
    movi        r17, 1
    stwio       r17, 0(r16)             # status = 1
    
    # Desabilita interrupções do timer
    wrctl       ienable, r0             # Desabilita todas IRQs
    wrctl       status, r0              # Desabilita PIE
    
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#========================================================================================================================================
# FUNÇÕES DE DISPLAY - ABI COMPLIANT
#========================================================================================================================================

# Função ATUALIZAR_DISPLAY_CRONOMETRO removida - usando a do main.s

#------------------------------------------------------------------------
# Limpa todos os displays 7-segmentos
#------------------------------------------------------------------------
LIMPAR_DISPLAYS:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    movia       r16, HEX_BASE
    
    # Limpa todos os displays de uma vez (32 bits)
    stwio       r0, (r16)               # Escreve 0x00000000 em todos displays
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

# Função CODIFICAR_7SEG removida - usando a do main.s

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

# Referências para funções e mensagens do main.s
.extern IMPRIMIR_STRING
.extern MSG_CRONOMETRO_INICIADO
.extern MSG_CRONOMETRO_CANCELADO
.extern ATUALIZAR_DISPLAY_CRONOMETRO
.extern CODIFICAR_7SEG

RECONFIGURAR_TIMER_PARA_ANIMACAO:
    # Salva registradores
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    # Para o timer atual
    movia       r16, TIMER_BASE
    stwio       r0, 4(r16)         # Para o timer
    
    # Configura período para animação (10.000.000 ciclos = 200ms @ 50MHz)
    movia       r17, 0x00989680    # 10.000.000 em decimal
    stwio       r17, 8(r16)        # periodl
    srli        r17, r17, 16
    stwio       r17, 12(r16)       # periodh
    
    # Reinicia o timer
    movi        r17, 0x7           # START=1, CONT=1, ITO=1
    stwio       r17, 4(r16)
    
    # Restaura registradores
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

.global INICIAR_CRONOMETRO
.global CANCELAR_CRONOMETRO
.global PROCESSAR_TICK_CRONOMETRO
.global RECONFIGURAR_TIMER_PARA_ANIMACAO

