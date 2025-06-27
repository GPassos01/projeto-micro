#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY  
# Arquivo: animacao.s
# Descrição: Sistema de Animação de LEDs com Timer
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
#========================================================================================================================================

.global _animacao
.global _update_animation_step
.extern FLAG_INTERRUPCAO
.extern ANIMATION_STATE  
.extern LED_STATE             # Definido em main.s
.extern _update_animation_step
.extern CONFIGURAR_TIMER
.extern PARAR_TIMER

#========================================================================================================================================
# Definições e Constantes
#========================================================================================================================================
.equ LED_BASE,              0x10000000
.equ SW_BASE,               0x10000040
.equ TIMER_BASE,            0x10002000

# Configurações de timing
.equ ANIMACAO_PERIODO,      10000000        # 200ms a 50MHz (10M ciclos)

# Direções da animação
.equ ESQUERDA_DIREITA,      0               # SW0=0: LED 0->1->2...->17->0
.equ DIREITA_ESQUERDA,      1               # SW0=1: LED 17->16->15...->0->17

# Posições dos LEDs
.equ LED_MIN,               0               # LED mínimo
.equ LED_MAX,               17              # LED máximo

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
    movia       r4, ANIMACAO_PERIODO  # Argumento para a função
    call        CONFIGURAR_TIMER
    
    # Ativa flag de animação
    movia       r8, FLAG_INTERRUPCAO
    movi        r9, 1
    stw         r9, (r8)
    
    br          FIM_ANIMACAO

#========================================================================================================================================
# PARADA DA ANIMAÇÃO
#========================================================================================================================================
PARAR_ANIMACAO:
    # Para timer de forma robusta
    call        PARAR_TIMER
    
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
    # Move da direita para esquerda (LED 17->16->...->0->17)
    srli        r16, r16, 1             # Desloca bit para direita
    bne         r16, r0, ATUALIZAR_LEDS_ANIM
    
    # Se chegou em 0, volta para LED 17
    movia       r16, 0x20000            # 2^17 = LED 17
    br          ATUALIZAR_LEDS_ANIM
    
MOVER_ESQUERDA_DIREITA:
    # Move da esquerda para direita (LED 0->1->...->17->0)
    slli        r16, r16, 1             # Desloca bit para esquerda
    movia       r1, 0x40000             # 2^18 (overflow)
    bne         r16, r1, ATUALIZAR_LEDS_ANIM
    
    # Se passou do LED 17, volta para LED 0
    movi        r16, 1                  # 2^0 = LED 0
    
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
# FUNÇÕES DE SUPORTE - ABI COMPLIANT (E SEGURAS)
#========================================================================================================================================

#------------------------------------------------------------------------
# Salva estado atual dos LEDs
#------------------------------------------------------------------------
SALVAR_ESTADO_LEDS:
    subi sp, sp, 8
    stw  ra, 4(sp)
    stw  r8, 0(sp)
    movia r8, LED_BASE
    ldwio r8, (r8)
    movia r9, LED_STATE
    stw   r8, (r9)
    ldw   r8, 0(sp)
    ldw   ra, 4(sp)
    addi  sp, sp, 8
    ret

#------------------------------------------------------------------------
# Restaura estado anterior dos LEDs
#------------------------------------------------------------------------
RESTAURAR_ESTADO_LEDS:
    subi sp, sp, 8
    stw  ra, 4(sp)
    stw  r8, 0(sp)
    movia r8, LED_STATE
    ldw   r8, (r8)
    movia r9, LED_BASE
    stwio r8, (r9)
    ldw   r8, 0(sp)
    ldw   ra, 4(sp)
    addi  sp, sp, 8
    ret

#------------------------------------------------------------------------
# Determina posição inicial baseada no SW0
#------------------------------------------------------------------------
DETERMINAR_POSICAO_INICIAL:
    subi sp, sp, 8
    stw  ra, 4(sp)
    stw  r8, 0(sp)
    call LER_DIRECAO_SW0
    beq  r2, r0, INIT_ESQUERDA_DIREITA
INIT_DIREITA_ESQUERDA:
    movia r8, 0x20000
    br    SALVAR_POSICAO_INICIAL
INIT_ESQUERDA_DIREITA:
    movi r8, 1
SALVAR_POSICAO_INICIAL:
    movia r9, ANIMATION_STATE
    stw   r8, (r9)
    movia r9, LED_BASE
    stwio r8, (r9)
    ldw   r8, 0(sp)
    ldw   ra, 4(sp)
    addi  sp, sp, 8
    ret

#------------------------------------------------------------------------
# Lê direção do switch SW0
# Saída: r2 = direção (0 = esq->dir, 1 = dir->esq)
#------------------------------------------------------------------------
LER_DIRECAO_SW0:
    subi sp, sp, 4
    stw  ra, 0(sp)
    movia r8, SW_BASE
    ldwio r2, (r8)
    andi  r2, r2, 1
    ldw   ra, 0(sp)
    addi  sp, sp, 4
    ret
