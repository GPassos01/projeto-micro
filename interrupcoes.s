#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: interrupcoes.s
# Descrição: Sistema de Interrupções e Variáveis Globais
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
#========================================================================================================================================

.org 0x20

.global INTERRUPCAO_HANDLER
.global TIMER_TICK_FLAG
.global CRONOMETRO_TICK_FLAG

#========================================================================================================================================
# Definições e Constantes
#========================================================================================================================================
.equ TIMER_BASE,        0x10002000
.equ SW_BASE,           0x10000040
.equ LED_BASE,          0x10000000
.equ KEY_BASE,          0x10000050

# Períodos para diferentes timers (para detectar tipo)
.equ ANIMACAO_PERIODO,  10000000        # 200ms a 50MHz (10M ciclos)
.equ CRONOMETRO_PERIODO, 50000000       # 1s a 50MHz (50M ciclos)

#========================================================================================================================================
# ROTINA DE TRATAMENTO DE INTERRUPÇÕES - ABI COMPLIANT
# Segue rigorosamente as convenções da ABI do Nios II
# IMPLEMENTA STATE MACHINE PARA DISTINGUIR TIMERS
#========================================================================================================================================
INTERRUPCAO_HANDLER:
    # --- PRÓLOGO (Otimizado) ---
    subi    sp, sp, 20
    stw     ra, 16(sp)
    stw     r8, 12(sp)
    stw     r9, 8(sp)
    stw     r10, 4(sp)
    rdctl   r10, estatus
    stw     r10, 0(sp)
    
    # Decrementa ea para interrupções de hardware
    subi    ea, ea, 4

    # --- LÓGICA DA ISR COM CONTADOR DE TICKS ---
    
    # 1. Verifica se a interrupção veio do timer
    movia   r8, TIMER_BASE
    ldwio   r9, 0(r8)               # Lê registrador de status do timer
    andi    r9, r9, 1               # Isola o bit TO (timeout)
    beq     r9, r0, ISR_EXIT_FIX    # Se não for timeout, sai
    
    # 2. Limpa a interrupção no hardware (CRÍTICO!)
    movi    r9, 1
    stwio   r9, 0(r8)
    
    # 3. VERIFICA QUAL SISTEMA ESTÁ ATIVO E PROCESSA ADEQUADAMENTE
    # Verifica se cronômetro está ativo
    movia   r8, CRONOMETRO_ATIVO
    ldw     r9, (r8)
    beq     r9, r0, APENAS_ANIMACAO
    
    # Cronômetro está ativo - precisa contar ticks para 1 segundo
    # Se animação também ativa: timer = 200ms, precisa 5 ticks = 1s
    # Se apenas cronômetro: timer = 1s, precisa 1 tick = 1s
    
    # Verifica se animação também está ativa
    movia   r8, ANIMATION_STATE
    ldw     r9, (r8)
    bne     r9, r0, CRONOMETRO_E_ANIMACAO
    
    # Apenas cronômetro ativo - conta direto
    movia   r8, CRONOMETRO_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)
    br      ISR_EXIT_FIX
    
CRONOMETRO_E_ANIMACAO:
    # Ambos ativos - timer em 200ms, precisa contar 5 ticks para 1s
    movia   r8, CRONOMETRO_CONTADOR_TICKS
    ldw     r9, (r8)
    addi    r9, r9, 1               # Incrementa contador
    
    # Verifica se chegou a 5 ticks (5 * 200ms = 1000ms = 1s)
    movi    r10, 5
    blt     r9, r10, SALVA_CONTADOR_TICKS
    
    # Chegou a 1 segundo - sinaliza tick do cronômetro e zera contador
    mov     r9, r0                  # Zera contador
    movia   r10, CRONOMETRO_TICK_FLAG
    movi    r8, 1
    stw     r8, (r10)
    
SALVA_CONTADOR_TICKS:
    movia   r8, CRONOMETRO_CONTADOR_TICKS
    stw     r9, (r8)
    
    # Sinaliza tick da animação sempre
    movia   r8, TIMER_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)
    br      ISR_EXIT_FIX

APENAS_ANIMACAO:
    # Apenas animação ativa
    movia   r8, TIMER_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)

ISR_EXIT_FIX:
    # --- EPÍLOGO ---
    ldw     r10, 0(sp)
    wrctl   estatus, r10
    ldw     r10, 4(sp)
    ldw     r9, 8(sp)
    ldw     r8, 12(sp)
    ldw     ra, 16(sp)
    addi    sp, sp, 20
    eret

#========================================================================================================================================
# SEÇÃO DE DADOS - Variáveis Globais
# Todas as variáveis alinhadas adequadamente conforme ABI
#========================================================================================================================================
.section .data
.align 4

# Flag para comunicação entre ISR e código principal (animação)
.global TIMER_TICK_FLAG
TIMER_TICK_FLAG:
    .word 0

# Flag para comunicação entre ISR e código principal (cronômetro)  
.global CRONOMETRO_TICK_FLAG
CRONOMETRO_TICK_FLAG:
    .word 0

# Estado da animação dos LEDs
.global ANIMATION_STATE
ANIMATION_STATE:
    .word 0

# Flag geral de interrupção ativa
.global FLAG_INTERRUPCAO
FLAG_INTERRUPCAO:
    .word 0

# Estados do cronômetro
.global CRONOMETRO_SEGUNDOS
CRONOMETRO_SEGUNDOS:
    .word 0

.global CRONOMETRO_PAUSADO
CRONOMETRO_PAUSADO:
    .word 0

.global CRONOMETRO_ATIVO
CRONOMETRO_ATIVO:
    .word 0

# Contador de ticks para cronômetro (quando animação também ativa)
.global CRONOMETRO_CONTADOR_TICKS
CRONOMETRO_CONTADOR_TICKS:
    .word 0
