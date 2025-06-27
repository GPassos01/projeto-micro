#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY (VERSÃO AUDITADA ABI)
# Arquivo: interrupcoes_abi.s
# Descrição: Sistema de Interrupções e Variáveis Globais
# ABI Compliant: SIM - 100% conforme com Nios II ABI rev. 2022
# Revisão: CRÍTICA - Handler otimizado e variáveis isoladas
#========================================================================================================================================

# CRÍTICO: Impede uso automático de r1 (assembler temporary)
.set noat

# Posicionamento do handler na tabela de vetores
.org 0x20

# Símbolos globais exportados
.global INTERRUPCAO_HANDLER
.global TIMER_TICK_FLAG
.global CRONOMETRO_TICK_FLAG

#========================================================================================================================================
# MAPEAMENTO DE PERIFÉRICOS
#========================================================================================================================================
.equ TIMER_BASE,        0x10002000      # Base do timer do sistema
.equ SW_BASE,           0x10000040      # Base dos switches
.equ LED_BASE,          0x10000000      # Base dos LEDs
.equ KEY_BASE,          0x10000050      # Base dos botões

#========================================================================================================================================
# HANDLER DE INTERRUPÇÕES - OTIMIZADO E ABI COMPLIANT
# Entrada: Interrupção do timer ou outros periféricos
# Saída: nenhuma
# Função: Processa interrupção do timer de forma mínima e rápida
#========================================================================================================================================
INTERRUPCAO_HANDLER:
    # === PRÓLOGO CRÍTICO DA ISR ===
    # Salva APENAS os registradores que serão efetivamente usados
    # OTIMIZAÇÃO: Minimiza latência da interrupção
    subi        sp, sp, 20              # Aloca espaço na stack
    stw         ra, 16(sp)              # Salva return address
    stw         r8, 12(sp)              # Salva r8 (usado para endereços)
    stw         r9, 8(sp)               # Salva r9 (usado para valores)
    stw         r10, 4(sp)              # Salva r10 (backup do status)
    
    # === SALVA E LIMPA STATUS DO PROCESSADOR ===
    # CRÍTICO: Salva estatus antes de qualquer operação
    rdctl       r10, estatus            # r10 = status atual do processador
    stw         r10, 0(sp)              # Salva na stack
    
    # === AJUSTA ENDEREÇO DE RETORNO ===
    # OBRIGATÓRIO: Decrementa ea para retornar à instrução interrompida
    subi        ea, ea, 4               # ea = ea - 4
    
    # === PROCESSAMENTO DA INTERRUPÇÃO DO TIMER ===
    # OBJETIVO: Limpar flag de hardware e sinalizar para software
    
    # Limpa flag TO (timeout) do timer IMEDIATAMENTE
    movia       r8, TIMER_BASE          # r8 = base do timer
    movi        r9, 1                   # r9 = valor para limpar TO
    stwio       r9, 0(r8)               # STATUS[TO] = 0 (limpa interrupção)
    
    # === SINALIZAÇÃO PARA O CÓDIGO PRINCIPAL ===
    # Seta flag que será verificada pelo main loop
    movia       r8, TIMER_TICK_FLAG     # r8 = ponteiro da flag
    stw         r9, (r8)                # flag = 1 (sinaliza tick ocorrido)
    
    # OPCIONAL: Seta flag específica do cronômetro (se necessário)
    movia       r8, CRONOMETRO_TICK_FLAG # r8 = ponteiro flag cronômetro
    stw         r9, (r8)                # flag = 1 (sinaliza para cronômetro)
    
    # === EPÍLOGO CRÍTICO DA ISR ===
    # Restaura registradores na ordem INVERSA
    ldw         r10, 0(sp)              # Carrega status salvo
    wrctl       estatus, r10            # Restaura status do processador
    ldw         r10, 4(sp)              # Restaura r10
    ldw         r9, 8(sp)               # Restaura r9
    ldw         r8, 12(sp)              # Restaura r8
    ldw         ra, 16(sp)              # Restaura return address
    addi        sp, sp, 20              # Libera stack frame
    
    # === RETORNO DA INTERRUPÇÃO ===
    eret                                # Exception return (volta ao programa)

#========================================================================================================================================
# SEÇÃO DE DADOS - VARIÁVEIS GLOBAIS ISOLADAS
# ORGANIZAÇÃO: Todas as variáveis de ISR em bloco separado para evitar conflitos
#========================================================================================================================================
.section .data
.align 4                                # CRÍTICO: Alinhamento em 4 bytes

# === FLAGS DE COMUNICAÇÃO ISR ↔ MAIN LOOP ===
# IMPORTANTE: Acesso sempre via ldw/stw (operações atômicas de 32 bits)

# Flag principal para comunicação Timer ISR → Main Loop
.global TIMER_TICK_FLAG
TIMER_TICK_FLAG:
    .word 0                             # 0 = sem tick, 1 = tick ocorreu

# Flag específica para cronômetro
.global CRONOMETRO_TICK_FLAG
CRONOMETRO_TICK_FLAG:
    .word 0                             # 0 = sem tick, 1 = tick para cronômetro

# === ESTADOS DO SISTEMA ===

# Estado da animação dos LEDs (posição atual do LED ativo)
.global ANIMATION_STATE
ANIMATION_STATE:
    .word 0                             # Máscara de bits do LED atual (0-0x3FFFF)

# Flag geral de interrupção/animação ativa
.global FLAG_INTERRUPCAO
FLAG_INTERRUPCAO:
    .word 0                             # 0 = animação parada, 1 = animação ativa

# === VARIÁVEIS DO CRONÔMETRO ===

# Contador principal de segundos (0 a 5999 = 99:59)
.global CRONOMETRO_SEGUNDOS
CRONOMETRO_SEGUNDOS:
    .word 0                             # Segundos totais desde início

# Flag de pausa (controlada por KEY1)
.global CRONOMETRO_PAUSADO
CRONOMETRO_PAUSADO:
    .word 0                             # 0 = rodando, 1 = pausado

# Flag de ativação geral do cronômetro
.global CRONOMETRO_ATIVO
CRONOMETRO_ATIVO:
    .word 0                             # 0 = desligado, 1 = ligado

#========================================================================================================================================
# FUNÇÕES DE CONFIGURAÇÃO DO TIMER - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# CONFIGURAR_TIMER: Configura e inicia timer com período específico
# Entrada: r4 = período em ciclos de clock
# Saída: nenhuma
#------------------------------------------------------------------------
.global CONFIGURAR_TIMER
CONFIGURAR_TIMER:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r8, 4(sp)               # Salva r8
    stw         r9, 0(sp)               # Salva r9
    
    # === INICIALIZAÇÃO DO TIMER ===
    movia       r8, TIMER_BASE          # r8 = base do timer
    
    # Para o timer antes de reconfigurar (segurança)
    stwio       r0, 4(r8)               # CONTROL = 0 (para timer)
    
    # === CONFIGURAÇÃO DO PERÍODO ===
    # Timer de 32 bits: período baixo (bits 15-0) e alto (bits 31-16)
    andi        r9, r4, 0xFFFF          # r9 = 16 bits inferiores
    stwio       r9, 8(r8)               # PERIODL = bits 15-0
    
    srli        r9, r4, 16              # r9 = 16 bits superiores  
    stwio       r9, 12(r8)              # PERIODH = bits 31-16
    
    # === LIMPA FLAG E HABILITA INTERRUPÇÕES ===
    movi        r9, 1                   # r9 = 1
    stwio       r9, 0(r8)               # STATUS[TO] = 0 (limpa flag)
    
    # Habilita interrupções no processador
    wrctl       ienable, r9             # ienable[0] = 1 (timer)
    wrctl       status, r9              # status[PIE] = 1 (global enable)
    
    # === INICIA O TIMER ===
    # CONTROL = START(1) | CONT(1) | ITO(1) = 0b111 = 7
    movi        r9, 7                   # r9 = START|CONT|ITO
    stwio       r9, 4(r8)               # Inicia timer com interrupções
    
    # === EPÍLOGO ABI ===
    ldw         r9, 0(sp)               # Restaura r9
    ldw         r8, 4(sp)               # Restaura r8
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#------------------------------------------------------------------------
# PARAR_TIMER: Para timer de forma segura
# Entrada: nenhuma
# Saída: nenhuma
#------------------------------------------------------------------------
.global PARAR_TIMER
PARAR_TIMER:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 8               # Aloca 8 bytes na stack
    stw         ra, 4(sp)               # Salva return address
    stw         r8, 0(sp)               # Salva r8
    
    # === PARADA SEGURA DO TIMER ===
    movia       r8, TIMER_BASE          # r8 = base do timer
    
    # Para o timer (CONTROL = 0)
    stwio       r0, 4(r8)               # CONTROL = 0 (para timer)
    
    # Limpa flag de timeout pendente
    movi        r9, 1                   # r9 = 1
    stwio       r9, 0(r8)               # STATUS[TO] = 0
    
    # Desabilita interrupções do timer
    wrctl       ienable, r0             # ienable = 0 (desabilita timer)
    wrctl       status, r0              # status[PIE] = 0 (global disable)
    
    # === EPÍLOGO ABI ===
    ldw         r8, 0(sp)               # Restaura r8
    ldw         ra, 4(sp)               # Restaura return address
    addi        sp, sp, 8               # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# FIM DO ARQUIVO - SISTEMA DE INTERRUPÇÕES ABI COMPLIANT
#========================================================================================================================================
.end 