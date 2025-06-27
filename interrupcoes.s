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

#========================================================================================================================================
# ROTINA DE TRATAMENTO DE INTERRUPÇÕES - ABI COMPLIANT
# Segue rigorosamente as convenções da ABI do Nios II
#========================================================================================================================================
INTERRUPCAO_HANDLER:
    # --- PRÓLOGO: Salvar Contexto Completo (ABI Compliant) ---
    # Salva TODOS os registradores caller-saved conforme ABI
    subi    sp, sp, 60                # Aloca espaço para 15 registradores
    stw     r1, 0(sp)                 # Salva registradores de argumentos/retorno
    stw     r2, 4(sp)
    stw     r3, 8(sp)
    stw     r4, 12(sp)                # Salva registradores de argumentos
    stw     r5, 16(sp)
    stw     r6, 20(sp)
    stw     r7, 24(sp)
    stw     r8, 28(sp)                # Salva registradores temporários
    stw     r9, 32(sp)
    stw     r10, 36(sp)
    stw     r11, 40(sp)
    stw     r12, 44(sp)
    stw     r13, 48(sp)
    stw     r14, 52(sp)
    stw     r15, 56(sp)
    
    # Salva registradores de controle
    rdctl   r1, estatus               # Salva status em r1 temporariamente
    
    # Para interrupções de hardware, ajusta ea
    subi    ea, ea, 4

    # --- LÓGICA DA ISR ---
    # Identifica fonte da interrupção lendo status do timer
    movia   r2, TIMER_BASE
    ldwio   r3, 0(r2)                 # Lê status do timer
    andi    r4, r3, 1                 # Isola bit TO (timeout)
    
    beq     r4, r0, ISR_EXIT          # Se não é timeout do timer, sai
    
    # Limpa flag de timeout do timer
    movi    r5, 1
    stwio   r5, 0(r2)                 # Escreve 1 para limpar TO
    
    # Verifica qual timer está ativo baseado na configuração
    ldwio   r6, 4(r2)                 # Lê controle do timer
    andi    r7, r6, 4                 # Isola bit ITO
    beq     r7, r0, ISR_EXIT          # Se ITO=0, timer não está configurado
    
    # Determina tipo de interrupção baseado no período configurado
    ldwio   r8, 8(r2)                 # Lê periodl
    ldwio   r9, 12(r2)                # Lê periodh
    
    # Reconstrói período de 32 bits
    slli    r9, r9, 16                # Shift periodh para posição alta
    or      r10, r8, r9               # Combina em r10
    
    # Verifica se é animação (10M ciclos = 200ms) ou cronômetro (50M ciclos = 1s)
    movia   r11, 10000000             # Período da animação
    beq     r10, r11, TIMER_ANIMACAO
    
    movia   r11, 50000000             # Período do cronômetro
    beq     r10, r11, TIMER_CRONOMETRO
    
    br      ISR_EXIT                  # Período desconhecido, sai

TIMER_ANIMACAO:
    # Sinaliza tick da animação
    movia   r12, TIMER_TICK_FLAG
    movi    r13, 1
    stw     r13, (r12)
    br      ISR_EXIT

TIMER_CRONOMETRO:
    # Sinaliza tick do cronômetro
    movia   r12, CRONOMETRO_TICK_FLAG
    movi    r13, 1
    stw     r13, (r12)
    
ISR_EXIT:
    # --- EPÍLOGO: Restaurar Contexto Completo ---
    # Restaura registradores de controle
    wrctl   estatus, r1               # Restaura status
    
    # Restaura todos os registradores na ordem inversa
    ldw     r15, 56(sp)
    ldw     r14, 52(sp)
    ldw     r13, 48(sp)
    ldw     r12, 44(sp)
    ldw     r11, 40(sp)
    ldw     r10, 36(sp)
    ldw     r9, 32(sp)
    ldw     r8, 28(sp)
    ldw     r7, 24(sp)
    ldw     r6, 20(sp)
    ldw     r5, 16(sp)
    ldw     r4, 12(sp)
    ldw     r3, 8(sp)
    ldw     r2, 4(sp)
    ldw     r1, 0(sp)
    addi    sp, sp, 60                # Restaura stack pointer
    
    # Retorna da interrupção
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
