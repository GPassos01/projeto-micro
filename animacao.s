#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY  
# Arquivo: animacao.s
# Descrição: Sistema de Animação Bidirecional de LEDs com Timer Inteligente
# ABI Compliant: 100% - Seguindo convenções rigorosas da ABI Nios II
#
# FUNCIONALIDADES PRINCIPAIS:
# - Animação bidirecional de LEDs (esquerda↔direita)
# - Controle de direção via SW0 em tempo real
# - Velocidade: 200ms por step (5 FPS)
# - Preservação de estado dos LEDs manuais
# - Timer compartilhado inteligente com cronômetro
# - Reconfiguração dinâmica de período
#
# COMANDOS:
# - "10" → Inicia animação (direção controlada por SW0)
# - "11" → Para animação e restaura LEDs anteriores
#
# CONTROLE DE DIREÇÃO:
# - SW0=0: Esquerda → Direita (LED 0→1→2→...→17→0)
# - SW0=1: Direita → Esquerda (LED 17→16→15→...→0→17)
#
# AUTORES: Amanda Oliveira, Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
#========================================================================================================================================

.global _animacao
.global _update_animation_step
.global INICIAR_ANIMACAO
.global PARAR_ANIMACAO
.global SALVAR_ESTADO_LEDS
.global RESTAURAR_ESTADO_LEDS
.global RECONFIGURAR_TIMER_PARA_CRONOMETRO

# Referências para símbolos globais definidos em interrupcoes.s
.extern FLAG_INTERRUPCAO
.extern ANIMATION_STATE  
.extern LED_STATE             # Definido em main.s
.extern CRONOMETRO_ATIVO      # Para verificar se cronômetro está ativo

#========================================================================================================================================
# Definições e Constantes - Hardware DE2-115
#========================================================================================================================================
.equ LED_BASE,              0x10000000      # LEDs vermelhos (18 LEDs: 0-17)
.equ SW_BASE,               0x10000040      # Switches para controle
.equ TIMER_BASE,            0x10002000      # Timer do sistema

# Configurações de timing otimizadas
.equ ANIMACAO_PERIODO,      10000000        # 200ms @ 50MHz (10M ciclos)

# Direções da animação (controladas por SW0)
.equ ESQUERDA_DIREITA,      0               # SW0=0: LED 0→1→2→...→17→0
.equ DIREITA_ESQUERDA,      1               # SW0=1: LED 17→16→15→...→0→17

# Limites dos LEDs
.equ LED_MIN,               0               # LED mínimo (primeiro)
.equ LED_MAX,               17              # LED máximo (último)

# Máscaras de bit para LEDs extremos
.equ LED_0_MASK,            0x00001         # 2^0 = LED 0
.equ LED_17_MASK,           0x20000         # 2^17 = LED 17
.equ LED_OVERFLOW_MASK,     0x40000         # 2^18 = overflow

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DE ANIMAÇÃO - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando (ABI padrão)
# Saída: nenhuma
#========================================================================================================================================
_animacao:
    # --- Stack Frame Prologue (ABI Standard) ---
    # Salva registradores callee-saved que serão usados
    subi        sp, sp, 20
    stw         fp, 16(sp)              # Frame pointer (callee-saved)
    stw         ra, 12(sp)              # Return address (callee-saved)
    stw         r16, 8(sp)              # s0 (callee-saved)
    stw         r17, 4(sp)              # s1 (callee-saved)
    stw         r18, 0(sp)              # s2 (callee-saved)
    
    # Configura frame pointer conforme ABI
    mov         fp, sp
    
    # Copia argumento para registrador callee-saved
    mov         r16, r4                 # r16 = comando string
    
    # Extrai sub-comando (segundo caractere)
    addi        r16, r16, 1             # Aponta para segundo caractere
    ldb         r17, (r16)              # r17 = sub-comando ('0' ou '1')
    
    # Compara sub-comando com '0' (ASCII 0x30)
    movi        r18, '0'
    beq         r17, r18, INICIAR_ANIMACAO

    # Se não for '0', assume comando para parar
    br          PARAR_ANIMACAO

#========================================================================================================================================
# INICIALIZAÇÃO DA ANIMAÇÃO
#========================================================================================================================================
INICIAR_ANIMACAO:
    # Verifica se animação já está ativa
    movia       r1, FLAG_INTERRUPCAO
    ldw         r2, (r1)
    bne         r2, r0, ANIM_JA_ATIVA    # Se já ativa, não faz nada
    
    # Salva estado atual dos LEDs antes de iniciar animação
    call        SALVAR_ESTADO_LEDS
    
    # Determina posição inicial baseada na direção do SW0
    call        DETERMINAR_POSICAO_INICIAL
    
    # Configura e inicia timer da animação
    call        CONFIGURAR_TIMER_ANIMACAO
    
    # Ativa flag de animação
    movia       r1, FLAG_INTERRUPCAO
    movi        r2, 1
    stw         r2, (r1)
    
    br          FIM_ANIMACAO

#========================================================================================================================================
# PARADA DA ANIMAÇÃO
#========================================================================================================================================
PARAR_ANIMACAO:
    # Verifica se cronômetro está ativo antes de parar timer
    movia       r1, CRONOMETRO_ATIVO
    ldw         r2, (r1)
    bne         r2, r0, PARAR_APENAS_ANIMACAO
    
    # Cronômetro não está ativo - pode parar timer completamente
    call        PARAR_TIMER_ANIMACAO
    br          FINALIZAR_PARADA_ANIMACAO
    
PARAR_APENAS_ANIMACAO:
    # Cronômetro está ativo - reconfigura timer para período do cronômetro
    call        RECONFIGURAR_TIMER_PARA_CRONOMETRO
    
FINALIZAR_PARADA_ANIMACAO:
    # Desativa flag de animação
    movia       r1, FLAG_INTERRUPCAO
    stw         r0, (r1)
    
    # Restaura estado anterior dos LEDs
    call        RESTAURAR_ESTADO_LEDS
    
    # Reseta estado da animação
    movia       r1, ANIMATION_STATE
    stw         r0, (r1)

ANIM_JA_ATIVA:
    # Animação já estava ativa, não faz nada

FIM_ANIMACAO:
    # --- Stack Frame Epilogue (ABI Standard) ---
    # Restaura registradores na ordem inversa
    ldw         r18, 0(fp)
    ldw         r17, 4(fp)
    ldw         r16, 8(fp)
    ldw         ra, 12(fp)
    ldw         fp, 16(fp)
    addi        sp, sp, 20
    ret

#========================================================================================================================================
# FUNÇÃO DE ATUALIZAÇÃO DA ANIMAÇÃO - ABI COMPLIANT  
# Chamada pelo main loop a cada tick do timer
# Entrada: nenhuma
# Saída: nenhuma
#========================================================================================================================================
_update_animation_step:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 16
    stw         fp, 12(sp)
    stw         ra, 8(sp)
    stw         r16, 4(sp)              # Estado atual
    stw         r17, 0(sp)              # Direção
    
    mov         fp, sp
    
    # Carrega estado atual da animação
    movia       r1, ANIMATION_STATE
    ldw         r16, (r1)
    
    # Lê direção do switch SW0
    call        LER_DIRECAO_SW0
    mov         r17, r2                 # r17 = direção (0 ou 1)
    
    # Processa movimento baseado na direção
    beq         r17, r0, MOVER_ESQUERDA_DIREITA
    
MOVER_DIREITA_ESQUERDA:
    # Move da direita para esquerda (LED 17→16→...→0→17)
    srli        r16, r16, 1             # Desloca bit para direita
    bne         r16, r0, ATUALIZAR_LEDS_ANIM
    
    # Se chegou em 0, volta para LED 17
    movia       r16, LED_17_MASK        # 2^17 = LED 17
    br          ATUALIZAR_LEDS_ANIM
    
MOVER_ESQUERDA_DIREITA:
    # Move da esquerda para direita (LED 0→1→...→17→0)
    slli        r16, r16, 1             # Desloca bit para esquerda
    movia       r1, LED_OVERFLOW_MASK   # 2^18 (overflow)
    bne         r16, r1, ATUALIZAR_LEDS_ANIM
    
    # Se passou do LED 17, volta para LED 0
    movia       r16, LED_0_MASK         # 2^0 = LED 0
    
ATUALIZAR_LEDS_ANIM:
    # Salva novo estado
    movia       r1, ANIMATION_STATE
    stw         r16, (r1)
    
    # Atualiza LEDs físicos
    movia       r1, LED_BASE
    stwio       r16, (r1)
    
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(fp)
    ldw         r16, 4(fp)
    ldw         ra, 8(fp)
    ldw         fp, 12(fp)
    addi        sp, sp, 16
    ret

#========================================================================================================================================
# FUNÇÕES DE SUPORTE - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Salva estado atual dos LEDs
#------------------------------------------------------------------------
SALVAR_ESTADO_LEDS:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Lê estado atual dos LEDs
    movia       r16, LED_BASE
    ldwio       r1, (r16)
    
    # Salva na variável LED_STATE
    movia       r16, LED_STATE
    stw         r1, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Restaura estado anterior dos LEDs
#------------------------------------------------------------------------
RESTAURAR_ESTADO_LEDS:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Carrega estado salvo
    movia       r16, LED_STATE
    ldw         r1, (r16)
    
    # Restaura nos LEDs físicos
    movia       r16, LED_BASE
    stwio       r1, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Determina posição inicial baseada no SW0
#------------------------------------------------------------------------
DETERMINAR_POSICAO_INICIAL:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Lê direção do SW0
    call        LER_DIRECAO_SW0
    mov         r16, r2                 # r16 = direção
    
    beq         r16, r0, INIT_ESQUERDA_DIREITA
    
INIT_DIREITA_ESQUERDA:
    # SW0=1: Inicia da direita (LED 17)
    movia       r1, LED_17_MASK         # 2^17 = LED 17
    br          SALVAR_POSICAO_INICIAL
    
INIT_ESQUERDA_DIREITA:
    # SW0=0: Inicia da esquerda (LED 0)
    movia       r1, LED_0_MASK          # 2^0 = LED 0
    
SALVAR_POSICAO_INICIAL:
    # Salva posição inicial
    movia       r16, ANIMATION_STATE
    stw         r1, (r16)
    
    # Acende LED inicial
    movia       r16, LED_BASE
    stwio       r1, (r16)
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Lê direção do switch SW0
# Saída: r2 = direção (0 = esq→dir, 1 = dir→esq)
#------------------------------------------------------------------------
LER_DIRECAO_SW0:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Lê estado dos switches
    movia       r16, SW_BASE
    ldwio       r1, (r16)
    
    # Isola SW0 (bit 0)
    andi        r2, r1, 1
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#========================================================================================================================================
# FUNÇÕES DE TIMER - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Configura e inicia timer para animação
#------------------------------------------------------------------------
CONFIGURAR_TIMER_ANIMACAO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    movia       r16, TIMER_BASE
    
    # Para timer primeiro (segurança)
    stwio       r0, 4(r16)              # Control = 0
    
    # Configura período (200ms = 10M ciclos a 50MHz)
    movia       r17, ANIMACAO_PERIODO
    
    # Bits baixos do período
    andi        r1, r17, 0xFFFF
    stwio       r1, 8(r16)              # periodl
    
    # Bits altos do período  
    srli        r17, r17, 16
    stwio       r17, 12(r16)            # periodh
    
    # Limpa flag de timeout pendente
    movi        r1, 1
    stwio       r1, 0(r16)              # status = 1 (limpa TO)
    
    # Habilita interrupções do timer
    movi        r1, 1                   # IRQ0 para timer
    wrctl       ienable, r1
    wrctl       status, r1              # Habilita PIE
    
    # Inicia timer: START=1, CONT=1, ITO=1
    movi        r1, 7                   # 0b111
    stwio       r1, 4(r16)              # control
    
    # --- Stack Frame Epilogue ---
    ldw         r17, 0(sp)
    ldw         r16, 4(sp)
    ldw         ra, 8(sp)
    addi        sp, sp, 12
    ret

#------------------------------------------------------------------------
# Para timer da animação de forma robusta
#------------------------------------------------------------------------
PARAR_TIMER_ANIMACAO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    movia       r16, TIMER_BASE
    
    # Para timer primeiro
    stwio       r0, 4(r16)              # control = 0
    
    # Limpa flag de timeout
    movi        r1, 1
    stwio       r1, 0(r16)              # status = 1
    
    # Desabilita interrupções do timer
    wrctl       ienable, r0             # Desabilita todas IRQs
    wrctl       status, r0              # Desabilita PIE
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

RECONFIGURAR_TIMER_PARA_CRONOMETRO:
    # Salva registradores
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Para o timer atual
    movia       r16, TIMER_BASE
    stwio       r0, 4(r16)         # Para o timer
    
    # Configura período para cronômetro (50.000.000 ciclos = 1s @ 50MHz)
    movia       r1, 0x02FAF080     # 50.000.000 em decimal
    stwio       r1, 8(r16)         # periodl
    srli        r1, r1, 16
    stwio       r1, 12(r16)        # periodh
    
    # Reinicia o timer
    movi        r1, 0x7            # START=1, CONT=1, ITO=1
    stwio       r1, 4(r16)
    
    # Restaura registradores
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret
