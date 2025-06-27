#========================================================================================================================================
# Projeto Microprocessadores: Nios II Assembly
# Placa: DE2 - 115
# Grupo: Gabriel Passos e Lucas Ferrarotto
# 1 Semestre de 2025
#========================================================================================================================================

.global _start

#========================================================================================================================================
# Vetor de Exceções - Deve estar no endereço 0x20
#========================================================================================================================================
.section .exceptions.entry, "xa"
.org 0x20
EXCEPTION_ENTRY:
    # Salto para o handler de interrupção
    br      INTERRUPCAO_HANDLER

# Retorna à seção de texto principal
.section .text

#========================================================================================================================================
# Definição de Endereços e Constantes
#========================================================================================================================================

# --- Endereços de Periféricos (I/O) ---
.equ LED_BASE,      0x10000000      # Endereço base dos LEDs
.equ HEX_BASE,      0x10000020      # Endereço base dos displays de 7 segmentos
.equ SW_BASE,		0x10000040      # Endereço base dos switches
.equ KEY_BASE,		0x10000050      # Endereço base dos botões (keys)
.equ JTAG_UART_BASE,0x10001000      # Endereço base da JTAG UART
.equ TIMER_BASE,	0x10002000      # Endereço base do Timer

# --- Offsets para Registradores da JTAG UART ---
.equ UART_DATA,     0               # Offset para o registrador de dados da UART
.equ UART_CONTROL,  4               # Offset para o registrador de controle da UART

# --- Estados do Sistema  ---
.equ STOPPED,		0
.equ STARTED,		1

#========================================================================================================================================
# Início do Programa
#========================================================================================================================================
_start:
    # --- Configuração Inicial ---
    # Inicializa o ponteiro de pilha (stack pointer) para o topo da memória.
    # A pilha cresce para baixo, então começamos do endereço mais alto.
    movia       sp, 0x07FFFFFFC

    # O vetor de exceções está configurado no endereço 0x20.
    # A rotina INTERRUPCAO_HANDLER será chamada através do EXCEPTION_ENTRY.

    # Inicializa e habilita o timer para gerar interrupções periódicas.
    call        INICIALIZAR_INTERRUPCAO_TEMPORIZADOR

#========================================================================================================================================
# Loop Principal: Imprimir Prompt, Ler e Processar Comando
#========================================================================================================================================
MAIN_LOOP:
    # --- 1. Imprime a mensagem de prompt na UART ---
    movia       r8, JTAG_UART_BASE      # r8 aponta para a base da JTAG UART
    movia       r9, MSG_PROMPT          # r9 aponta para o início da string do prompt
    movi        r10, BUFFER_ESCRITA     # r10 aponta para o buffer onde a entrada do usuário será guardada

PRINTF_LOOP:
    # Carrega o próximo caractere da mensagem.
    ldb		    r11, 0(r9)

    # Se o caractere for nulo (fim da string), para de imprimir e vai ler a entrada.
    beq         r11, r0, POLLING_INPUT_LOOP

POLLING_WRITE:
    # Lê o registrador de controle da UART para verificar o espaço disponível para escrita (WSPACE).
    ldwio       r12, UART_CONTROL(r8)

    # A informação de WSPACE está nos 16 bits superiores do registrador de controle.
    # A instrução 'andhi' realiza uma operação AND com uma máscara nos 16 bits superiores.
    # (Ex: andhi r12, r12, 0xFFFF faz r12 = r12 & 0xFFFF0000).
    # Se o resultado for 0, o buffer de escrita da UART está cheio.
    andhi       r12, r12, 0xFFFF

    # Continua no loop de espera (polling) até que WSPACE seja diferente de zero.
    beq		    r12, r0, POLLING_WRITE

    # UART está pronta. Escreve o caractere (em r11) no registrador de dados da UART.
    stwio		r11, UART_DATA(r8)

    # Avança para o próximo caractere na string do prompt.
    addi        r9, r9, 1
    br          PRINTF_LOOP

# --- 2. Aguarda e lê a entrada do usuário via UART ---
POLLING_INPUT_LOOP:
    # Lê o registrador de dados da UART. Os 16 bits superiores contêm o status.
    ldwio       r9, UART_DATA(r8)

    # Isola o bit 15 (RVALID). Se for 1, há um dado válido para leitura.
    andi        r11, r9, 0x8000

    # Se RVALID for 0, não há dados. Continua esperando.
    beq		    r11, r0, POLLING_INPUT_LOOP

    # Dado é válido. Isola os 8 bits inferiores, que contêm o caractere recebido.
    andi        r11, r9, 0xFF

    # Compara o caractere com o código ASCII para 'Enter' (Newline, \n, valor 10).
    movi		r12, 10
    beq         r11, r12, FINISH_READ   # Se for Enter, finaliza a leitura.

    # Armazena o caractere lido no buffer de escrita.
    stb         r11, (r10)
    # Avança para a próxima posição no buffer.
    addi        r10, r10, 1

    br          POLLING_INPUT_LOOP

# --- 3. Processa o comando recebido ---
FINISH_READ:
    # Carrega o primeiro caractere digitado pelo usuário.
    movi        r9, BUFFER_ESCRITA
    ldb         r11, (r9)

    # Compara com os comandos conhecidos ('0', '1', '2').
    movi        r10, '0'        # '0' na tabela ASCII
    beq         r11, r10, CALL_LED

    movi        r10, '1'        # '1' na tabela ASCII
    beq         r11, r10, CALL_ANIMATION

    movi        r10, '2'        # '2' na tabela ASCII
    beq         r11, r10, CALL_CRONOMETER

    # Se o comando for desconhecido, reinicia o loop principal.
    br          MAIN_LOOP

#========================================================================================================================================
# Seção de Chamada das Sub-rotinas
#========================================================================================================================================

CALL_LED:
    call        _led
    br          MAIN_LOOP

CALL_ANIMATION:
    call        _animacao
    br          MAIN_LOOP

CALL_CRONOMETER:
    call        _cronometro
    br          MAIN_LOOP

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

# Flag para comunicação entre a ISR e o código principal.
.global FLAG_INTERRUPCAO
FLAG_INTERRUPCAO:
    .word 0

# Variável para guardar o estado da animação dos LEDs.
.global ANIMATION_STATE
ANIMATION_STATE:
    .word 0x01

# Buffer para armazenar a entrada do usuário.
BUFFER_ESCRITA:
    .skip 100

# Mensagem de prompt a ser exibida para o usuário (no final para evitar problemas de alinhamento).
MSG_PROMPT:
    .asciz "Entre com o comando: "

# Declaração do handler de interrupção para que o linker possa encontrá-lo.
.global INTERRUPCAO_HANDLER

.end
