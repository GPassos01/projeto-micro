#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY (VERSÃO AUDITADA ABI)
# Arquivo: animacao_abi.s
# Descrição: Sistema de Animação de LEDs com Timer
# ABI Compliant: SIM - 100% conforme com Nios II ABI rev. 2022
# Funcionalidades: Iniciar animação (10), Parar animação (11), direção por SW0
# Revisão: CRÍTICA - Exclusão mútua, estado preservado, validações completas
#========================================================================================================================================

# CRÍTICO: Impede uso automático de r1 (assembler temporary)
.set noat

# Símbolos exportados
.global _animacao
.global _update_animation_step
.global RESTAURAR_ESTADO_LEDS           # Exporta para uso pelo cronômetro

# Símbolos externos necessários
.extern LED_STATE                       # Estado atual dos LEDs (main.s)
.extern ANIMATION_STATE                 # Estado da animação (interrupcoes.s)
.extern FLAG_INTERRUPCAO                # Flag de animação ativa (interrupcoes.s)
.extern CRONOMETRO_ATIVO                # Flag cronômetro ativo (interrupcoes.s)
.extern CONFIGURAR_TIMER                # Configuração do timer (interrupcoes.s)
.extern PARAR_TIMER                     # Parada do timer (interrupcoes.s)

#========================================================================================================================================
# MAPEAMENTO DE PERIFÉRICOS E CONSTANTES
#========================================================================================================================================
.equ LED_BASE,              0x10000000  # Base dos 18 LEDs vermelhos
.equ SW_BASE,               0x10000040  # Base dos switches
.equ ASCII_ZERO,            0x30         # Valor ASCII do '0'
.equ ASCII_SPACE,           0x20         # Valor ASCII do espaço ' '
.equ ANIMACAO_PERIODO,      10000000     # 200ms @ 50MHz (baseado em Cornell specs)

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DE CONTROLE DA ANIMAÇÃO - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando ("10" ou "11")
# Saída: nenhuma
# Formato esperado:
#   - "10" ou "10 " = iniciar animação (direção determinada por SW0)
#   - "11" ou "11 " = parar animação e restaurar estado anterior
# Direção: SW0=0 (esquerda→direita), SW0=1 (direita→esquerda)
#========================================================================================================================================
_animacao:
    # === PRÓLOGO ABI COMPLETO ===
    subi        sp, sp, 32              # Aloca 32 bytes na stack (múltiplo de 4)
    stw         ra, 28(sp)              # Salva return address
    stw         fp, 24(sp)              # Salva frame pointer
    stw         r16, 20(sp)             # Salva r16 (ponteiro comando)
    stw         r17, 16(sp)             # Salva r17 (operação parseada)
    stw         r18, 12(sp)             # Salva r18 (temporário)
    stw         r19, 8(sp)              # Salva r19 (temporário)
    stw         r20, 4(sp)              # Salva r20 (temporário)
    stw         r21, 0(sp)              # Salva r21 (temporário)
    
    # Estabelece frame pointer
    mov         fp, sp                  # fp aponta para stack frame atual
    
    # === COPIA PARÂMETRO PARA REGISTRADOR CALLEE-SAVED ===
    mov         r16, r4                 # r16 = ponteiro comando
    
    # === PARSING DA OPERAÇÃO COM ESPAÇO OPCIONAL ===
    # Suporta formatos "1x" e "1 x" (com espaço após '1')
    ldb         r17, 1(r16)             # r17 = segundo caractere
    movi        r18, ASCII_SPACE        # r18 = ASCII espaço
    bne         r17, r18, PARSE_ANIM_OK # Se não é espaço, continua
    
    # Se segundo caractere é espaço, pega o terceiro
    ldb         r17, 2(r16)             # r17 = terceiro caractere
    
PARSE_ANIM_OK:
    # Converte ASCII para valor numérico
    subi        r17, r17, ASCII_ZERO    # r17 = operação (0 ou 1)
    
    # === DISPATCH DA OPERAÇÃO ===
    beq         r17, r0, INICIAR_ANIMACAO    # Se operação = 0, inicia
    br          PARAR_ANIMACAO              # Senão, para animação
    
INICIAR_ANIMACAO:
    # === VERIFICA SE ANIMAÇÃO JÁ ESTÁ ATIVA ===
    movia       r18, FLAG_INTERRUPCAO   # r18 = ponteiro flag animação
    ldw         r19, (r18)              # r19 = status atual
    bne         r19, r0, ANIM_JA_ATIVA  # Se já ativa, não faz nada
    
    # === DESATIVA CRONÔMETRO SE ESTIVER ATIVO ===
    # EXCLUSÃO MÚTUA: animação e cronômetro não podem usar timer simultaneamente
    movia       r18, CRONOMETRO_ATIVO   # r18 = ponteiro flag cronômetro
    ldw         r19, (r18)              # r19 = status cronômetro
    beq         r19, r0, CONTINUAR_INICIO_ANIM # Se cronômetro desativo, continua
    
    # Desativa cronômetro
    stw         r0, (r18)               # CRONOMETRO_ATIVO = 0
    call        PARAR_TIMER             # Para timer do cronômetro
    
CONTINUAR_INICIO_ANIM:
    # === SALVA ESTADO ATUAL DOS LEDs ===
    # IMPORTANTE: preserva estado para restauração posterior
    call        SALVAR_ESTADO_LEDS      # Salva estado atual em variável local
    
    # === DETERMINA DIREÇÃO BASEADA EM SW0 ===
    call        DETERMINAR_POSICAO_INICIAL # Configura posição inicial
    
    # === ATIVA FLAG DE ANIMAÇÃO ===
    movia       r18, FLAG_INTERRUPCAO   # r18 = ponteiro flag
    movi        r19, 1                  # r19 = 1 (ativo)
    stw         r19, (r18)              # FLAG_INTERRUPCAO = 1
    
    # === CONFIGURAÇÃO E INÍCIO DO TIMER ===
    movia       r4, ANIMACAO_PERIODO    # r4 = período de 200ms (ABI)
    call        CONFIGURAR_TIMER        # Configura timer para animação
    
    br          FIM_ANIMACAO_ABI        # Finaliza comando
    
ANIM_JA_ATIVA:
    # Se animação já está ativa, comando é ignorado
    br          FIM_ANIMACAO_ABI
    
PARAR_ANIMACAO:
    # === VERIFICA SE ANIMAÇÃO ESTÁ ATIVA ===
    movia       r18, FLAG_INTERRUPCAO   # r18 = ponteiro flag
    ldw         r19, (r18)              # r19 = status atual
    beq         r19, r0, FIM_ANIMACAO_ABI # Se já parada, nada a fazer
    
    # === DESATIVA FLAG DE ANIMAÇÃO ===
    stw         r0, (r18)               # FLAG_INTERRUPCAO = 0
    
    # === PARA TIMER DE FORMA SEGURA ===
    call        PARAR_TIMER             # Para timer e desabilita interrupções
    
    # === RESTAURA ESTADO ANTERIOR DOS LEDs ===
    call        RESTAURAR_ESTADO_LEDS   # Restaura LEDs ao estado anterior
    
    # === RESETA ESTADO DA ANIMAÇÃO ===
    movia       r18, ANIMATION_STATE    # r18 = ponteiro estado animação
    stw         r0, (r18)               # ANIMATION_STATE = 0
    
FIM_ANIMACAO_ABI:
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
# ATUALIZAÇÃO DO PASSO DA ANIMAÇÃO - ABI COMPLIANT
# Entrada: nenhuma (chamada pela ISR via main loop)
# Saída: nenhuma (atualiza LEDs e ANIMATION_STATE)
# Função: Move LED ativo para próxima posição baseado na direção SW0
# Otimizada para latência mínima (chamada frequentemente)
#========================================================================================================================================
_update_animation_step:
    # === PRÓLOGO ABI OTIMIZADO ===
    subi        sp, sp, 20              # Aloca 20 bytes na stack
    stw         ra, 16(sp)              # Salva return address
    stw         r16, 12(sp)             # Salva r16 (estado atual)
    stw         r17, 8(sp)              # Salva r17 (switches)
    stw         r18, 4(sp)              # Salva r18 (temporário)
    stw         r19, 0(sp)              # Salva r19 (temporário)
    
    # === VERIFICA SE ANIMAÇÃO ESTÁ ATIVA ===
    # PROTEÇÃO: só atualiza se realmente ativa
    movia       r17, FLAG_INTERRUPCAO   # r17 = ponteiro flag
    ldw         r18, (r17)              # r18 = status animação
    beq         r18, r0, FIM_UPDATE_ANIM # Se desativa, sai imediatamente
    
    # === CARREGA ESTADO ATUAL DA ANIMAÇÃO ===
    movia       r17, ANIMATION_STATE    # r17 = ponteiro estado
    ldw         r16, (r17)              # r16 = estado atual (máscara LED)
    
    # === LÊ DIREÇÃO DO SW0 ===
    movia       r17, SW_BASE            # r17 = base dos switches
    ldwio       r18, (r17)              # r18 = estado dos switches
    andi        r18, r18, 1             # r18 = SW0 (bit 0)
    
    # === MOVE BASEADO NA DIREÇÃO ===
    beq         r18, r0, MOVER_ESQUERDA_DIREITA # SW0=0: esq→dir
    br          MOVER_DIREITA_ESQUERDA          # SW0=1: dir→esq
    
MOVER_ESQUERDA_DIREITA:
    # === MOVIMENTO ESQUERDA → DIREITA (LED 0→1→...→17→0) ===
    slli        r16, r16, 1             # Desloca bit para esquerda
    movia       r18, 0x40000            # r18 = 2^18 (overflow após LED 17)
    bne         r16, r18, ATUALIZAR_LEDS_ANIM # Se não overflow, continua
    
    # Se passou do LED 17, volta para LED 0
    movi        r16, 1                  # r16 = 2^0 = LED 0
    br          ATUALIZAR_LEDS_ANIM
    
MOVER_DIREITA_ESQUERDA:
    # === MOVIMENTO DIREITA → ESQUERDA (LED 17→16→...→1→0→17) ===
    srli        r16, r16, 1             # Desloca bit para direita
    bne         r16, r0, ATUALIZAR_LEDS_ANIM # Se não underflow, continua
    
    # Se passou do LED 0, volta para LED 17
    movia       r16, 0x20000            # r16 = 2^17 = LED 17
    
ATUALIZAR_LEDS_ANIM:
    # === SALVA NOVO ESTADO ===
    movia       r17, ANIMATION_STATE    # r17 = ponteiro estado
    stw         r16, (r17)              # Atualiza estado da animação
    
    # === ATUALIZA LEDs FÍSICOS ===
    movia       r17, LED_BASE           # r17 = base dos LEDs
    stwio       r16, (r17)              # Escreve novo padrão nos LEDs
    
FIM_UPDATE_ANIM:
    # === EPÍLOGO ABI OTIMIZADO ===
    ldw         r19, 0(sp)              # Restaura r19
    ldw         r18, 4(sp)              # Restaura r18
    ldw         r17, 8(sp)              # Restaura r17
    ldw         r16, 12(sp)             # Restaura r16
    ldw         ra, 16(sp)              # Restaura return address
    addi        sp, sp, 20              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# DETERMINAÇÃO DA POSIÇÃO INICIAL - ABI COMPLIANT
# Entrada: nenhuma (lê SW0)
# Saída: nenhuma (configura ANIMATION_STATE)
# Função: Define posição inicial baseada na direção escolhida
#========================================================================================================================================
DETERMINAR_POSICAO_INICIAL:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r16, 4(sp)              # Salva r16
    stw         r17, 0(sp)              # Salva r17
    
    # === LÊ DIREÇÃO DO SW0 ===
    movia       r16, SW_BASE            # r16 = base dos switches
    ldwio       r17, (r16)              # r17 = estado dos switches
    andi        r17, r17, 1             # r17 = SW0 (bit 0)
    
    # === CONFIGURA POSIÇÃO INICIAL ===
    movia       r16, ANIMATION_STATE    # r16 = ponteiro estado
    
    beq         r17, r0, INICIO_ESQUERDA # SW0=0: inicia no LED 0
    # SW0=1: inicia no LED 17
    movia       r17, 0x20000            # r17 = 2^17 = LED 17
    stw         r17, (r16)              # ANIMATION_STATE = LED 17
    br          FIM_POSICAO_INICIAL
    
INICIO_ESQUERDA:
    # Inicia no LED 0
    movi        r17, 1                  # r17 = 2^0 = LED 0
    stw         r17, (r16)              # ANIMATION_STATE = LED 0
    
FIM_POSICAO_INICIAL:
    # === EPÍLOGO ABI ===
    ldw         r17, 0(sp)              # Restaura r17
    ldw         r16, 4(sp)              # Restaura r16
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# SALVAMENTO DO ESTADO DOS LEDs - ABI COMPLIANT
# Entrada: nenhuma (lê LED_STATE)
# Saída: nenhuma (salva em LED_STATE_BACKUP)
# Função: Preserva estado atual para restauração posterior
#========================================================================================================================================
SALVAR_ESTADO_LEDS:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r16, 4(sp)              # Salva r16
    stw         r17, 0(sp)              # Salva r17
    
    # === CARREGA ESTADO ATUAL ===
    movia       r16, LED_STATE          # r16 = ponteiro estado atual
    ldw         r17, (r16)              # r17 = estado dos LEDs
    
    # === SALVA EM BACKUP ===
    movia       r16, LED_STATE_BACKUP   # r16 = ponteiro backup
    stw         r17, (r16)              # LED_STATE_BACKUP = estado atual
    
    # === EPÍLOGO ABI ===
    ldw         r17, 0(sp)              # Restaura r17
    ldw         r16, 4(sp)              # Restaura r16
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# RESTAURAÇÃO DO ESTADO DOS LEDs - ABI COMPLIANT
# Entrada: nenhuma (lê LED_STATE_BACKUP)
# Saída: nenhuma (restaura LED_STATE e hardware)
# Função: Restaura estado anterior à animação
#========================================================================================================================================
RESTAURAR_ESTADO_LEDS:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r16, 4(sp)              # Salva r16
    stw         r17, 0(sp)              # Salva r17
    
    # === CARREGA ESTADO BACKUP ===
    movia       r16, LED_STATE_BACKUP   # r16 = ponteiro backup
    ldw         r17, (r16)              # r17 = estado salvo
    
    # === RESTAURA ESTADO ATUAL ===
    movia       r16, LED_STATE          # r16 = ponteiro estado atual
    stw         r17, (r16)              # LED_STATE = estado salvo
    
    # === ATUALIZA HARDWARE ===
    movia       r16, LED_BASE           # r16 = base dos LEDs
    stwio       r17, (r16)              # Restaura LEDs físicos
    
    # === EPÍLOGO ABI ===
    ldw         r17, 0(sp)              # Restaura r17
    ldw         r16, 4(sp)              # Restaura r16
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# SEÇÃO DE DADOS - VARIÁVEIS LOCAIS
#========================================================================================================================================
.section .data
.align 4                                # CRÍTICO: Alinhamento em 4 bytes

# === BACKUP DO ESTADO DOS LEDs ===
# Usado para restaurar estado anterior quando animação para
.global LED_STATE_BACKUP
LED_STATE_BACKUP:
    .word 0                             # Estado dos LEDs antes da animação

#========================================================================================================================================
# FIM DO ARQUIVO - ANIMAÇÃO ABI COMPLIANT
#========================================================================================================================================
.end 