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

    # --- LÓGICA DA ISR (INTELIGENTE COM DETECÇÃO DE TIMER) ---
    
    # 1. Verifica se a interrupção veio do timer
    movia   r8, TIMER_BASE
    ldwio   r9, 0(r8)               # Lê registrador de status do timer
    andi    r9, r9, 1               # Isola o bit TO (timeout)
    beq     r9, r0, ISR_EXIT_FIX    # Se não for timeout, é outra interrupção. Sai.
    
    # 2. Limpa a interrupção no hardware (CRÍTICO!)
    movi    r9, 1
    stwio   r9, 0(r8)
    
    # 3. DETECÇÃO INTELIGENTE DO TIPO DE TIMER
    # Lê o período configurado para determinar se é animação ou cronômetro
    ldwio   r10, 8(r8)              # periodl (16 bits baixos)
    ldwio   r9, 12(r8)              # periodh (16 bits altos)
    slli    r9, r9, 16              # Shift bits altos
    or      r9, r9, r10             # Combina período completo
    
    # Compara com período da animação (10M ciclos)
    movia   r10, ANIMACAO_PERIODO
    beq     r9, r10, TICK_ANIMACAO
    
    # Compara com período do cronômetro (50M ciclos)  
    movia   r10, CRONOMETRO_PERIODO
    beq     r9, r10, TICK_CRONOMETRO
    
    # Se não match, assume que é tick genérico
    br      ISR_EXIT_FIX

TICK_ANIMACAO:
    # Sinaliza tick da animação
    movia   r8, TIMER_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)
    br      ISR_EXIT_FIX

TICK_CRONOMETRO:
    # Sinaliza tick do cronômetro
    movia   r8, CRONOMETRO_TICK_FLAG
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
