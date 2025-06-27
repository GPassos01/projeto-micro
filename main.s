#========================================================================================================================================
# Projeto Microprocessadores: Nios II Assembly
# Placa: DE2 - 115
# Grupo: Gabriel Passos e Lucas Ferrarotto
# 1 Semestre de 2025
#========================================================================================================================================

.global _start

# Referências para variáveis definidas em interrupcoes.s (compilado primeiro)
.extern FLAG_INTERRUPCAO
.extern TIMER_TICK_FLAG

# Vetor de exceções movido para interrupcoes.s para melhor organização
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

    # Inicializa os LEDs (todos apagados)
    movia       r8, LED_BASE
    stwio       r0, (r8)

    # Limpa as variáveis de estado
    movia       r8, LED_STATE
    stw         r0, (r8)
    # FLAG_INTERRUPCAO já está inicializada em interrupcoes.s
    # Não precisa zerar aqui pois já está em 0

    # O vetor de exceções está configurado no endereço 0x20.
    # A rotina INTERRUPCAO_HANDLER será chamada através do EXCEPTION_ENTRY.

    # Timer será inicializado apenas quando necessário (animação/cronômetro)
    # call        INICIALIZAR_INTERRUPCAO_TEMPORIZADOR

#========================================================================================================================================
# Loop Principal: Imprimir Prompt, Ler e Processar Comando
#========================================================================================================================================
MAIN_LOOP:
    # --- NOVO: Polling do Timer Tick para Animação ---
    call        CHECK_ANIMATION_TICK

    # Limpa o buffer antes de cada iteração para garantir entrada limpa
    call        LIMPAR_BUFFER
    
    # --- 1. Imprime a mensagem de prompt na UART ---
    movia       r8, JTAG_UART_BASE      # r8 aponta para a base da JTAG UART
    movia       r9, MSG_PROMPT          # r9 aponta para o início da string do prompt
    movia       r10, BUFFER_ESCRITA     # r10 aponta para o buffer onde a entrada do usuário será guardada

PRINTF_LOOP:
    # Carrega o próximo caractere da mensagem.
    ldb		    r11, 0(r9)

    # Se o caractere for nulo (fim da string), para de imprimir e vai ler a entrada.
    beq         r11, r0, POLLING_INPUT_LOOP

POLLING_WRITE:
    # ✅ ESCRITA ROBUSTA: Desabilita interrupções durante operação crítica
    rdctl       r15, status          # Salva status atual
    wrctl       status, r0           # Desabilita PIE temporariamente
    
    # Lê o registrador de controle da UART para verificar o espaço disponível para escrita (WSPACE).
    ldwio       r12, UART_CONTROL(r8)
    
    # Re-habilita interrupções imediatamente após leitura
    wrctl       status, r15          # Restaura status original

    # A informação de WSPACE está nos 16 bits superiores do registrador de controle.
    # A instrução 'andhi' realiza uma operação AND com uma máscara nos 16 bits superiores.
    # (Ex: andhi r12, r12, 0xFFFF faz r12 = r12 & 0xFFFF0000).
    # Se o resultado for 0, o buffer de escrita da UART está cheio.
    andhi       r12, r12, 0xFFFF

    # Continua no loop de espera (polling) até que WSPACE seja diferente de zero.
    beq		    r12, r0, POLLING_WRITE

    # ✅ ESCRITA ATÔMICA: Desabilita interrupções para escrita crítica
    rdctl       r15, status          # Salva status atual
    wrctl       status, r0           # Desabilita PIE temporariamente
    
    # UART está pronta. Escreve o caractere (em r11) no registrador de dados da UART.
    stwio		r11, UART_DATA(r8)
    
    # Re-habilita interrupções imediatamente após escrita
    wrctl       status, r15          # Restaura status original

    # Avança para o próximo caractere na string do prompt.
    addi        r9, r9, 1
    br          PRINTF_LOOP

# --- 2. Aguarda e lê a entrada do usuário via UART (ULTRA-ROBUSTO) ---
POLLING_INPUT_LOOP:
    # ✅ SOLUÇÃO ULTRA-ROBUSTA: Desabilita interrupções temporariamente durante leitura crítica
    movi        r13, 10000          # Contador muito maior de tentativas
    
UART_RETRY_LOOP:
    # Desabilita interrupções por brevíssimo período para leitura atômica
    rdctl       r14, status          # Salva status atual
    wrctl       status, r0           # Desabilita PIE temporariamente
    
    # Lê o registrador de dados da UART de forma atômica
    ldwio       r9, UART_DATA(r8)
    
    # Re-habilita interrupções imediatamente
    wrctl       status, r14          # Restaura status original
    
    # Isola o bit 15 (RVALID). Se for 1, há um dado válido para leitura.
    andi        r11, r9, 0x8000

    # Se RVALID for 1, há dados válidos - processa imediatamente
    bne         r11, r0, PROCESS_CHAR

    # Não há dados - decrementa contador e tenta novamente
    subi        r13, r13, 1
    bne         r13, r0, UART_RETRY_LOOP
    
    # Timeout atingido, reinicia contador e continua tentando
    br          POLLING_INPUT_LOOP

PROCESS_CHAR:
    # Dado é válido. Isola os 8 bits inferiores, que contêm o caractere recebido.
    andi        r11, r9, 0xFF

    # Compara o caractere com o código ASCII para 'Enter' (Newline, \n, valor 10).
    movi		r12, 10
    beq         r11, r12, FINISH_READ   # Se for Enter, finaliza a leitura.

    # Compara também com '\r' (carriage return, valor 13)
    movi        r12, 13
    beq         r11, r12, FINISH_READ   # Se for CR, finaliza a leitura.

    # Armazena o caractere lido no buffer de escrita.
    stb         r11, (r10)
    # Avança para a próxima posição no buffer.
    addi        r10, r10, 1

    # Continua lendo próximo caractere
    br          POLLING_INPUT_LOOP

# --- 3. Processa o comando recebido ---
FINISH_READ:
    # Adiciona terminador nulo ao buffer
    stb         r0, (r10)
    
    # Carrega o primeiro caractere digitado pelo usuário.
    movia       r9, BUFFER_ESCRITA
    ldb         r11, (r9)

    # Compara com os comandos conhecidos ('0', '1', '2').
    movi        r10, '0'        # '0' na tabela ASCII
    beq         r11, r10, CALL_LED

    movi        r10, '1'        # '1' na tabela ASCII
    beq         r10, r11, CALL_ANIMATION

    movi        r10, '2'        # '2' na tabela ASCII
    beq         r11, r10, CALL_CRONOMETER

    # Se o comando for desconhecido, limpa o buffer e reinicia o loop principal.
    call        LIMPAR_BUFFER
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
    movia       r8, BUFFER_ESCRITA
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
BUFFER_ESCRITA:
    .skip 100

# Mensagem de prompt a ser exibida para o usuário (no final para evitar problemas de alinhamento).
MSG_PROMPT:
    .asciz "Entre com o comando: "

# Declaração do handler de interrupção para que o linker possa encontrá-lo.
.global INTERRUPCAO_HANDLER
.extern _update_animation_step

.end
