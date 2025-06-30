#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: interrupcoes.s
# Descrição: Sistema de Interrupções e Variáveis Globais do Sistema
# ABI Compliant: Totalmente - Seguindo convenções rigorosas da ABI Nios II
# 
# FUNCIONALIDADES:
# - Rotina de Serviço de Interrupção (ISR) otimizada e robusta
# - Gerenciamento inteligente de timer compartilhado entre animação e cronômetro
# - Detecção automática do tipo de sistema ativo baseado em flags
# - Contagem de ticks sincronizada para cronômetro quando ambos sistemas ativos
# - Variáveis globais centralizadas e alinhadas para performance
#
# AUTORES: Amanda Oliveira, Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
# PLACA: DE2-115 (Cyclone IV FPGA)
#========================================================================================================================================

.org 0x20

.global INTERRUPCAO_HANDLER
.global TIMER_TICK_FLAG
.global CRONOMETRO_TICK_FLAG

#========================================================================================================================================
# Definições e Constantes - Endereços de Hardware
#========================================================================================================================================
.equ TIMER_BASE,        0x10002000      # Timer do sistema (único timer compartilhado)
.equ SW_BASE,           0x10000040      # Switches para controle de direção
.equ LED_BASE,          0x10000000      # LEDs vermelhos (18 LEDs: 0-17)
.equ KEY_BASE,          0x10000050      # Botões físicos (KEY3-0)

# Períodos de Timer (para detecção automática de tipo)
.equ ANIMACAO_PERIODO,  10000000        # 200ms @ 50MHz (10M ciclos)
.equ CRONOMETRO_PERIODO, 50000000       # 1s @ 50MHz (50M ciclos)

# Constantes para sincronização
.equ TICKS_POR_SEGUNDO, 5               # 5 ticks de 200ms = 1000ms (1s)

#========================================================================================================================================
# ROTINA DE TRATAMENTO DE INTERRUPÇÕES - ABI COMPLIANT & OTIMIZADA
# 
# ESTRATÉGIA DE FUNCIONAMENTO:
# 1. Timer único compartilhado entre animação (200ms) e cronômetro (1s)
# 2. Detecção automática de sistemas ativos via flags de estado
# 3. Sincronização inteligente: quando ambos ativos, conta 5 ticks de 200ms = 1s
# 4. Preservação completa de contexto conforme ABI Nios II
# 5. Atomicidade garantida para todas as operações críticas
#========================================================================================================================================
INTERRUPCAO_HANDLER:
    # === PRÓLOGO OTIMIZADO - Salva contexto mínimo necessário ===
    subi    sp, sp, 20                  # Aloca espaço para 5 registradores
    stw     ra, 16(sp)                  # Return address (sempre necessário)
    stw     r8, 12(sp)                  # Registrador de trabalho 1
    stw     r9, 8(sp)                   # Registrador de trabalho 2  
    stw     r10, 4(sp)                  # Registrador de trabalho 3
    rdctl   r10, estatus                # Salva status de interrupções: Exception Status Register → é um registrador de controle especial que armazena o status anterior de interrupções (interrupt enable bit).
    stw     r10, 0(sp)
    
    # Ajusta EA para interrupções de hardware (padrão Nios II)
    subi    ea, ea, 4

    # === VERIFICAÇÃO DE FONTE DE INTERRUPÇÃO ===
    movia   r8, TIMER_BASE
    ldwio   r9, 0(r8)                   # Lê status do timer
    andi    r9, r9, 1                   # Isola bit TO (timeout)
    beq     r9, r0, ISR_EXIT_OTIMIZADO  # Se não for timeout do timer, sai
    
    # === LIMPEZA ATÔMICA DA INTERRUPÇÃO ===
    movi    r9, 1
    stwio   r9, 0(r8)                   # Limpa flag TO no hardware
    
    # === LÓGICA DE PROCESSAMENTO INTELIGENTE ===
    # Verifica estado do cronômetro primeiro (prioridade)
    movia   r8, CRONOMETRO_ATIVO
    ldw     r9, (r8)
    beq     r9, r0, PROCESSAR_APENAS_ANIMACAO
    
    # Cronômetro está ativo - verifica se animação também está
    movia   r8, FLAG_INTERRUPCAO
    ldw     r9, (r8)
    bne     r9, r0, PROCESSAR_AMBOS_SISTEMAS
    
    # === APENAS CRONÔMETRO ATIVO ===
    movia   r8, CRONOMETRO_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)                    # Sinaliza tick direto do cronômetro
    br      ISR_EXIT_OTIMIZADO
    
PROCESSAR_AMBOS_SISTEMAS:
    # === AMBOS SISTEMAS ATIVOS - Sincronização de Ticks ===
    # Timer configurado em 200ms, precisa contar 5 ticks para 1 segundo
    movia   r8, CRONOMETRO_CONTADOR_TICKS
    ldw     r9, (r8)
    addi    r9, r9, 1                   # Incrementa contador
    
    # Verifica se completou 1 segundo (5 * 200ms = 1000ms)
    movi    r10, TICKS_POR_SEGUNDO
    blt     r9, r10, SALVAR_CONTADOR_E_ANIMAR
    
    # Completou 1 segundo - sinaliza cronômetro e reseta contador
    mov     r9, r0                      # Zera contador
    movia   r10, CRONOMETRO_TICK_FLAG
    movi    r8, 1
    stw     r8, (r10)                   # Sinaliza tick do cronômetro
    
SALVAR_CONTADOR_E_ANIMAR:
    movia   r8, CRONOMETRO_CONTADOR_TICKS
    stw     r9, (r8)                    # Salva contador atualizado
    
    # Sempre sinaliza tick da animação (200ms)
    movia   r8, TIMER_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)
    br      ISR_EXIT_OTIMIZADO

PROCESSAR_APENAS_ANIMACAO:
    # === APENAS ANIMAÇÃO ATIVA ===
    movia   r8, TIMER_TICK_FLAG
    movi    r9, 1
    stw     r9, (r8)                    # Sinaliza tick da animação

ISR_EXIT_OTIMIZADO:
    # === EPÍLOGO OTIMIZADO - Restaura contexto ===
    ldw     r10, 0(sp)                  # Restaura status de interrupções
    wrctl   estatus, r10
    ldw     r10, 4(sp)                  # Restaura registradores de trabalho
    ldw     r9, 8(sp)
    ldw     r8, 12(sp)
    ldw     ra, 16(sp)                  # Restaura return address
    addi    sp, sp, 20                  # Libera stack
    eret                                # Retorna da interrupção

#========================================================================================================================================
# SEÇÃO DE DADOS - Variáveis Globais Otimizadas e Alinhadas
# 
# ORGANIZAÇÃO:
# - Todas as variáveis alinhadas em 4 bytes para performance otimizada
# - Agrupamento lógico por funcionalidade para melhor cache locality
# - Documentação detalhada do propósito de cada variável
#========================================================================================================================================
.section .data
.align 4

# === FLAGS DE COMUNICAÇÃO ISR <-> MAIN LOOP ===
# Flags atômicas para comunicação entre ISR e código principal

.global TIMER_TICK_FLAG
TIMER_TICK_FLAG:
    .word 0                             # Flag: tick da animação disponível (200ms)

.global CRONOMETRO_TICK_FLAG  
CRONOMETRO_TICK_FLAG:
    .word 0                             # Flag: tick do cronômetro disponível (1s)

# === ESTADO DOS SISTEMAS ===
# Variáveis de controle de estado dos diferentes subsistemas

.global ANIMATION_STATE
ANIMATION_STATE:
    .word 0                             # Estado atual da animação (posição do LED ativo)

.global FLAG_INTERRUPCAO
FLAG_INTERRUPCAO:
    .word 0                             # Flag geral: animação ativa (1) ou inativa (0)

# === ESTADO DO CRONÔMETRO ===
# Conjunto completo de variáveis para controle do cronômetro

.global CRONOMETRO_SEGUNDOS
CRONOMETRO_SEGUNDOS:
    .word 0                             # Contador de segundos do cronômetro (0-5999)

.global CRONOMETRO_PAUSADO
CRONOMETRO_PAUSADO:
    .word 0                             # Estado de pausa: pausado (1) ou rodando (0)

.global CRONOMETRO_ATIVO
CRONOMETRO_ATIVO:
    .word 0                             # Sistema ativo: cronômetro ligado (1) ou desligado (0)

# === SINCRONIZAÇÃO DE TIMER ===
# Variável para sincronização quando ambos sistemas estão ativos

.global CRONOMETRO_CONTADOR_TICKS
CRONOMETRO_CONTADOR_TICKS:
    .word 0                             # Contador de ticks para sincronização (0-4)
