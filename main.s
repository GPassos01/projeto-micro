#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY
# Arquivo: main.s  
# Descrição: Loop Principal e Gerenciamento de Comandos
# ABI Compliant: Sim - Seguindo convenções rigorosas da ABI Nios II
# Placa: DE2-115 (Cyclone IV)
# Grupo: Gabriel Passos e Lucas Ferrarotto - 1º Semestre 2025
#========================================================================================================================================

.global _start

# Referências para variáveis definidas em interrupcoes.s (compilado primeiro)
.extern FLAG_INTERRUPCAO
.extern TIMER_TICK_FLAG
.extern CRONOMETRO_TICK_FLAG
.extern CRONOMETRO_SEGUNDOS
.extern CRONOMETRO_PAUSADO
.extern CRONOMETRO_ATIVO

# Vetor de exceções movido para interrupcoes.s para melhor organização
.section .text

#========================================================================================================================================
# Definição de Endereços e Constantes - Conforme Manual DE2-115
#========================================================================================================================================

# --- Endereços de Periféricos (Memory-Mapped I/O) ---
.equ LED_BASE,          0x10000000      # LEDs vermelhos (18 LEDs: 0-17)
.equ HEX_BASE,          0x10000020      # Displays 7-segmentos (HEX3-0)
.equ SW_BASE,           0x10000040      # Switches (SW17-0)
.equ KEY_BASE,          0x10000050      # Botões (KEY3-0)
.equ JTAG_UART_BASE,    0x10001000      # JTAG UART
.equ TIMER_BASE,        0x10002000      # Timer do sistema

# --- Offsets para Registradores da JTAG UART ---
.equ UART_DATA,         0               # Registrador de dados
.equ UART_CONTROL,      4               # Registrador de controle

# --- Estados do Sistema ---
.equ PARADO,            0
.equ ATIVO,             1

# --- Configurações de Timing ---
.equ ANIMACAO_PERIODO,  10000000        # 200ms a 50MHz (10M ciclos)
.equ CRONOMETRO_PERIODO, 50000000       # 1s a 50MHz (50M ciclos)

#========================================================================================================================================
# Início do Programa
#========================================================================================================================================
_start:
    # --- INICIALIZAÇÃO SISTEMA (ABI Compliant) ---
    # Stack pointer para topo da memória (ABI requirement)
    movia       sp, 0x07FFFFFFC          # Stack cresce para baixo
    
    # Frame pointer inicial (ABI requirement)
    mov         fp, sp
    
    # Inicialização usando registradores caller-saved (r1-r15)
    call        INICIALIZAR_SISTEMA
    
    # Configura vetor de exceções (endereço 0x20)
    movia       r1, INTERRUPCAO_HANDLER

#========================================================================================================================================
# Loop Principal: Imprimir Prompt, Ler e Processar Comando
#========================================================================================================================================
MAIN_LOOP:
    # --- Verifica e processa ticks de interrupção ---
    call        PROCESSAR_TICKS_SISTEMA
    
    # --- Limpa buffer para garantir entrada limpa ---
    call        LIMPAR_BUFFER
    
    # --- Imprime prompt usando registradores ABI compliant ---
    movia       r4, MSG_PROMPT           # r4 = argumento 1 (ABI)
    call        IMPRIMIR_STRING
    
    # --- Lê comando do usuário ---
    movia       r4, BUFFER_ENTRADA       # r4 = buffer destino (ABI)
    movi        r5, 100                  # r5 = tamanho máximo (ABI)
    call        LER_COMANDO_UART
    
    # --- Processa comando recebido ---
    movia       r4, BUFFER_ENTRADA       # r4 = comando para processar (ABI)
    call        PROCESSAR_COMANDO
    
    # Retorna ao início do loop
    br          MAIN_LOOP

#========================================================================================================================================
# Seção de Chamada das Sub-rotinas
#========================================================================================================================================

CALL_LED:
    call        _led
    call        LIMPAR_BUFFER
    br          MAIN_LOOP

CALL_ANIMATION:
    call        _animacao
    call        LIMPAR_BUFFER
    br          MAIN_LOOP

CALL_CRONOMETER:
    call        _cronometro
    call        LIMPAR_BUFFER
    br          MAIN_LOOP

#========================================================================================================================================
# NOVA ROTINA: Verifica e processa o tick da animação
#========================================================================================================================================
CHECK_ANIMATION_TICK:
    # Verifica se a animação está ligada
    movia       r8, FLAG_INTERRUPCAO
    ldw         r9, (r8)
    beq         r9, r0, NO_ANIMATION_TICK # Se FLAG_INTERRUPCAO é 0, não faz nada

    # Animação está ligada, verifica se o timer deu um tick
    movia       r8, TIMER_TICK_FLAG
    ldw         r9, (r8)
    beq         r9, r0, NO_ANIMATION_TICK # Se TIMER_TICK_FLAG é 0, não faz nada

    # Tick do timer ocorreu!
    # 1. Limpa a flag para o próximo tick
    stw         r0, (r8)

    # 2. Executa um passo da animação
    call        _update_animation_step

NO_ANIMATION_TICK:
    ret

#========================================================================================================================================
# Rotina para Limpar o Buffer
#========================================================================================================================================
LIMPAR_BUFFER:
    movia       r8, BUFFER_ENTRADA
    movi        r9, 100              # Tamanho do buffer
LIMPAR_LOOP:
    stb         r0, (r8)            # Escreve 0 na posição atual
    addi        r8, r8, 1           # Avança para próxima posição
    subi        r9, r9, 1           # Decrementa contador
    bne         r9, r0, LIMPAR_LOOP # Continua se não zerou
    ret

#========================================================================================================================================
# Rotina de Inicialização do Timer
#========================================================================================================================================
INICIALIZAR_INTERRUPCAO_TEMPORIZADOR:
    # r8: Endereço base do Timer
    # r9, r10: Usados para configurar o período
    # r15: Usado para configurar os bits de controle

    # Define o período do timer para 10.000.000 ciclos (50 MHz * 0.2s = 200 ms).
    movia       r8, TIMER_BASE
    movia       r9, 10000000

    # Escreve os 16 bits inferiores do período no registrador 'periodl'.
    andi        r10, r9, 0xFFFF
    stwio       r10, 8(r8)

    # Escreve os 16 bits superiores do período no registrador 'periodh'.
    srli        r9, r9, 16
    stwio       r9, 12(r8)

    # Configura o registrador de controle do timer:
    # Bit 0 (START=1): Inicia o timer.
    # Bit 1 (CONT=1):  Modo contínuo. O timer reinicia após atingir o período.
    # Bit 2 (ITO=1):   Habilita a interrupção do timer.
    movi        r9, 0b111
    stwio       r9, 4(r8)

    # Habilita as interrupções na CPU:
    # 'ienable' (Interrupt-Enable Register) habilita a linha de interrupção específica (IRQ0 para o timer).
    # 'status' (Status Register) habilita globalmente as interrupções no processador (bit PIE).
    movi        r15, 0b1
    wrctl		ienable, r15
    wrctl       status, r15

    ret

#========================================================================================================================================
# Seção de Dados
#========================================================================================================================================

# Primeiro, alinhamos e definimos as variáveis word
.align 4

# Variável global para o estado dos LEDs (exemplo, pode ser usada por _led.s).
.global LED_STATE
LED_STATE:
    .word 0

# Variáveis FLAG_INTERRUPCAO e ANIMATION_STATE movidas para interrupcoes.s

# Buffer para armazenar a entrada do usuário.
BUFFER_ENTRADA:
    .skip 100

# Mensagem de prompt a ser exibida para o usuário (no final para evitar problemas de alinhamento).
MSG_PROMPT:
    .asciz "Entre com o comando: "

# Declaração do handler de interrupção para que o linker possa encontrá-lo.
.global INTERRUPCAO_HANDLER
.extern _update_animation_step

.end
