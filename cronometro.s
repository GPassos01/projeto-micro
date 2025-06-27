#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: cronometro.s
# Descrição: Sistema de Cronômetro com Displays 7-Segmentos
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
# Funcionalidades: Iniciar (20), Cancelar (21), Pausar/Retomar (KEY1)
#========================================================================================================================================

.global _cronometro

# Referências para símbolos globais definidos em interrupcoes.s
.extern CRONOMETRO_SEGUNDOS
.extern CRONOMETRO_PAUSADO
.extern CRONOMETRO_ATIVO
.extern CRONOMETRO_TICK_FLAG

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
    # --- Stack Frame Prologue (ABI Standard) ---
    # Salva registradores callee-saved que serão usados
    subi        sp, sp, 20
    stw         fp, 16(sp)              # Frame pointer (callee-saved)
    stw         ra, 12(sp)              # Return address (callee-saved)
    stw         r16, 8(sp)              # s0 - Command pointer (callee-saved)
    stw         r17, 4(sp)              # s1 - Operation (callee-saved)
    stw         r18, 0(sp)              # s2 - Spare (callee-saved)
    
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
    movia       r1, CRONOMETRO_ATIVO
    ldw         r2, (r1)
    bne         r2, r0, CRONOMETRO_JA_ATIVO
    
    # PARA QUALQUER TIMER ATIVO PRIMEIRO (CRÍTICO!)
    call        PARAR_TIMER_SISTEMA
    
    # Inicializa estado do cronômetro
    call        INICIALIZAR_ESTADO_CRONOMETRO
    
    # Configura e inicia timer do cronômetro
    call        CONFIGURAR_TIMER_CRONOMETRO
    
    # Configura interrupção do KEY1 para pause/resume
    call        CONFIGURAR_KEY1_INTERRUPCAO
    
    # Ativa cronômetro
    movia       r1, CRONOMETRO_ATIVO
    movi        r2, 1
    stw         r2, (r1)
    
    # Mensagem de confirmação
    movia       r4, MSG_CRONOMETRO_INICIADO
    call        IMPRIMIR_STRING
    
    # Atualiza display inicial
    call        ATUALIZAR_DISPLAY_CRONOMETRO
    
    br          FIM_CRONOMETRO

CANCELAR_CRONOMETRO:
    # Para timer do cronômetro
    call        PARAR_TIMER_SISTEMA
    
    # Desativa cronômetro
    movia       r1, CRONOMETRO_ATIVO
    stw         r0, (r1)
    
    # Zera contador
    movia       r1, CRONOMETRO_SEGUNDOS
    stw         r0, (r1)
    
    # Limpa pausado
    movia       r1, CRONOMETRO_PAUSADO
    stw         r0, (r1)
    
    # Limpa displays
    call        LIMPAR_DISPLAYS
    
    # Mensagem de confirmação
    movia       r4, MSG_CRONOMETRO_CANCELADO
    call        IMPRIMIR_STRING
    
CRONOMETRO_JA_ATIVO:
    # Cronômetro já estava ativo, não faz nada
    
FIM_CRONOMETRO:
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
# FUNÇÕES DE PARSING - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Extrai operação do comando do cronômetro (segundo caractere)
# Entrada: r16 = ponteiro para comando
# Saída: r2 = operação (0=iniciar, 1=cancelar)
#------------------------------------------------------------------------
EXTRAIR_OPERACAO_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Lê segundo caractere (posição 1)
    addi        r16, r16, 1             # Aponta para posição 1
    ldb         r1, (r16)               # Carrega caractere
    
    # Converte ASCII para número
    subi        r2, r1, ASCII_ZERO      # r2 = operação
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
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
# FUNÇÕES DE TIMER - ABI COMPLIANT
#========================================================================================================================================

#------------------------------------------------------------------------
# Para o timer do sistema de forma robusta (para prevenir conflitos)
#------------------------------------------------------------------------
PARAR_TIMER_SISTEMA:
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
    
    # Desabilita interrupções do timer temporariamente
    wrctl       ienable, r0             # Desabilita todas IRQs
    
    # Pequeno delay para garantir que timer parou
    movi        r1, 1000
DELAY_PARAR:
    subi        r1, r1, 1
    bne         r1, r0, DELAY_PARAR
    
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

#------------------------------------------------------------------------
# Configura e inicia timer para cronômetro
#------------------------------------------------------------------------
CONFIGURAR_TIMER_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 12
    stw         ra, 8(sp)
    stw         r16, 4(sp)
    stw         r17, 0(sp)
    
    movia       r16, TIMER_BASE
    
    # Para timer primeiro (segurança)
    stwio       r0, 4(r16)              # Control = 0
    
    # Configura período (1s = 50M ciclos a 50MHz)
    movia       r17, CRONOMETRO_PERIODO
    
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
# Para timer do cronômetro de forma robusta
#------------------------------------------------------------------------
PARAR_TIMER_CRONOMETRO:
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

