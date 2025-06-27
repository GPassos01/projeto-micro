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
    
    # Atualiza display inicial
    call        ATUALIZAR_DISPLAY_CRONOMETRO
    
    br          FIM_CRONOMETRO

CANCELAR_CRONOMETRO:
    # Para timer do cronômetro
    call        PARAR_TIMER_CRONOMETRO
    
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

#------------------------------------------------------------------------
# Atualiza displays 7-segmentos com tempo do cronômetro
# Formato: MM:SS (HEX3 HEX2 : HEX1 HEX0)
#------------------------------------------------------------------------
ATUALIZAR_DISPLAY_CRONOMETRO:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 24
    stw         ra, 20(sp)
    stw         r16, 16(sp)             # Segundos totais
    stw         r17, 12(sp)             # Minutos
    stw         r18, 8(sp)              # Segundos restantes
    stw         r19, 4(sp)              # HEX base
    stw         r20, 0(sp)              # Dígito temporário
    
    # Carrega segundos totais
    movia       r1, CRONOMETRO_SEGUNDOS
    ldw         r16, (r1)
    
    movia       r19, HEX_BASE
    
    # Calcula minutos e segundos
    movi        r1, 60
    div         r17, r16, r1             # r17 = minutos
    mul         r2, r17, r1              # r2 = minutos * 60
    sub         r18, r16, r2             # r18 = segundos restantes
    
    # HEX3 (dezenas de minutos)
    movi        r1, 10
    div         r20, r17, r1             # r20 = dezenas de minutos
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX3_OFFSET(r19)     # HEX3
    
    # HEX2 (unidades de minutos)
    movi        r1, 10
    div         r2, r17, r1              # r2 = dezenas
    mul         r2, r2, r1               # r2 = dezenas * 10
    sub         r20, r17, r2             # r20 = unidades de minutos
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX2_OFFSET(r19)     # HEX2
    
    # HEX1 (dezenas de segundos)
    movi        r1, 10
    div         r20, r18, r1             # r20 = dezenas de segundos
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX1_OFFSET(r19)     # HEX1
    
    # HEX0 (unidades de segundos)
    movi        r1, 10
    div         r2, r18, r1              # r2 = dezenas
    mul         r2, r2, r1               # r2 = dezenas * 10  
    sub         r20, r18, r2             # r20 = unidades de segundos
    mov         r4, r20
    call        CODIFICAR_7SEG
    stwio       r2, HEX0_OFFSET(r19)     # HEX0
    
    # --- Stack Frame Epilogue ---
    ldw         r20, 0(sp)
    ldw         r19, 4(sp)
    ldw         r18, 8(sp)
    ldw         r17, 12(sp)
    ldw         r16, 16(sp)
    ldw         ra, 20(sp)
    addi        sp, sp, 24
    ret

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

#------------------------------------------------------------------------
# Codifica dígito para display 7-segmentos
# Entrada: r4 = dígito (0-9)
# Saída: r2 = código 7-segmentos
#------------------------------------------------------------------------
CODIFICAR_7SEG:
    # --- Stack Frame Prologue ---
    subi        sp, sp, 8
    stw         ra, 4(sp)
    stw         r16, 0(sp)
    
    # Validação de entrada
    movi        r1, 9
    bgt         r4, r1, DIGITO_INVALIDO_7SEG
    blt         r4, r0, DIGITO_INVALIDO_7SEG
    
    # Carrega código da tabela (usa a tabela global do main.s)
    movia       r16, TABELA_7SEG
    slli        r1, r4, 2                # Multiplica por 4 (word)
    add         r16, r16, r1
    ldw         r2, (r16)                # Carrega código
    br          CODIF_7SEG_EXIT
    
DIGITO_INVALIDO_7SEG:
    movi        r2, 0x00                 # Display apagado
    
CODIF_7SEG_EXIT:
    # --- Stack Frame Epilogue ---
    ldw         r16, 0(sp)
    ldw         ra, 4(sp)
    addi        sp, sp, 8
    ret

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
