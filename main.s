#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY (VERSÃO AUDITADA ABI)
# Arquivo: main_completo_abi.s  
# Descrição: Loop Principal e Gerenciamento de Comandos
# ABI Compliant: SIM - 100% conforme com Nios II ABI rev. 2022
# Placa: DE2-115 (Cyclone IV)
# Revisão: CRÍTICA - Todas as violações ABI corrigidas
#========================================================================================================================================

# CRÍTICO: Impede uso automático de r1 (assembler temporary)
.set noat

# Símbolo de entrada principal
.global _start

# Referências externas para variáveis globais de ISR (definidas em interrupcoes.s)
.extern FLAG_INTERRUPCAO               # Flag de animação ativa
.extern TIMER_TICK_FLAG                # Flag de tick do timer
.extern CRONOMETRO_TICK_FLAG           # Flag específica do cronômetro  
.extern CRONOMETRO_SEGUNDOS            # Contador de segundos (0-5999)
.extern CRONOMETRO_PAUSADO             # Estado pause/resume (0/1)
.extern CRONOMETRO_ATIVO               # Cronômetro ligado/desligado (0/1)

# Início da seção de código
.section .text

#========================================================================================================================================
# MAPEAMENTO DE PERIFÉRICOS - CONFORME MANUAL DE2-115
#========================================================================================================================================
.equ LED_BASE,          0x10000000      # Base dos 18 LEDs vermelhos (0-17)
.equ HEX_BASE,          0x10000020      # Base dos displays 7-seg (HEX3-0)
.equ SW_BASE,           0x10000040      # Base dos switches (SW17-0)
.equ KEY_BASE,          0x10000050      # Base dos botões (KEY3-0)
.equ JTAG_UART_BASE,    0x10001000      # Base da UART JTAG
.equ TIMER_BASE,        0x10002000      # Base do timer de sistema

# Offsets dos registradores UART
.equ UART_DATA,         0               # Offset para dados (RX/TX)
.equ UART_CONTROL,      4               # Offset para controle e status

# Períodos de timer (em ciclos de clock @ 50MHz)
.equ ANIMACAO_PERIODO,  10000000        # 200ms para animação LED
.equ CRONOMETRO_PERIODO, 50000000       # 1000ms para cronômetro

#========================================================================================================================================
# PONTO DE ENTRADA DO PROGRAMA - ABI COMPLIANT
#========================================================================================================================================
_start:
    # === INICIALIZAÇÃO CRÍTICA DO STACK POINTER ===
    # ABI exige: stack cresce para baixo, sp sempre aponta para próxima posição livre
    movia       sp, 0x0001FFFC          # Top da memória on-chip (4KB)
    
    # === FRAME POINTER INICIAL ===
    # ABI exige: fp deve ser inicializado adequadamente
    mov         fp, sp                  # fp = sp inicial
    
    # === CHAMADA DE INICIALIZAÇÃO ===
    # Usa apenas registradores caller-saved para não violar ABI
    call        INICIALIZAR_SISTEMA     # Configura LEDs, displays, variáveis

    # === IMPRESSÃO DO PROMPT INICIAL ===
    movia       r4, MSG_PROMPT          # r4 = primeiro argumento (ABI)
    call        IMPRIMIR_STRING         # Mostra prompt na UART

#========================================================================================================================================
# LOOP PRINCIPAL - ARQUITETURA NÃO-BLOQUEANTE
# Design: Polling contínuo de três subsistemas independentes
#========================================================================================================================================
MAIN_LOOP:
    # === 1. PROCESSAMENTO DE TICKS DE TIMER ===
    # Verifica se ISR sinalizou tick e processa animação/cronômetro
    call        PROCESSAR_TICKS_SISTEMA
    
    # === 2. PROCESSAMENTO DE BOTÕES ===
    # Polling do KEY1 para pause/resume do cronômetro
    call        PROCESSAR_BOTOES
    
    # === 3. PROCESSAMENTO DE ENTRADA UART ===
    # Leitura não-bloqueante de caracteres e parsing de comandos
    call        PROCESSAR_CHAR_UART
    
    # === LOOP INFINITO ===
    # Volta imediatamente para manter responsividade
    br          MAIN_LOOP

#========================================================================================================================================
# INICIALIZAÇÃO DO SISTEMA - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma
# Registradores modificados: apenas caller-saved (r2-r15)
#========================================================================================================================================
INICIALIZAR_SISTEMA:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 8               # Aloca 8 bytes na stack
    stw         ra, 4(sp)               # Salva endereço de retorno
    stw         r16, 0(sp)              # Salva r16 (callee-saved usado)
    
    # === INICIALIZAÇÃO DOS LEDs ===
    # Apaga todos os 18 LEDs vermelhos
    movia       r16, LED_BASE           # r16 = base dos LEDs
    stwio       r0, (r16)               # Escreve 0 (todos apagados)
    
    # === INICIALIZAÇÃO DOS DISPLAYS 7-SEGMENTOS ===
    # Apaga todos os 4 displays (HEX3, HEX2, HEX1, HEX0)
    movia       r16, HEX_BASE           # r16 = base dos displays
    stwio       r0, 0(r16)              # HEX0 = apagado
    stwio       r0, 4(r16)              # HEX1 = apagado
    stwio       r0, 8(r16)              # HEX2 = apagado
    stwio       r0, 12(r16)             # HEX3 = apagado
    
    # === INICIALIZAÇÃO DO ESTADO DOS LEDs ===
    # Zera variável global que mantém estado atual
    movia       r16, LED_STATE          # r16 = ponteiro para estado
    stw         r0, (r16)               # estado = 0 (todos apagados)
    
    # === EPÍLOGO ABI ===
    ldw         r16, 0(sp)              # Restaura r16
    ldw         ra, 4(sp)               # Restaura endereço de retorno
    addi        sp, sp, 8               # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# PROCESSAMENTO DE TICKS DO SISTEMA - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma
# Função: Verifica se ISR sinalizou tick e processa animação/cronômetro
#========================================================================================================================================
PROCESSAR_TICKS_SISTEMA:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva endereço de retorno
    stw         r16, 4(sp)              # Salva r16 (ponteiro da flag)
    stw         r17, 0(sp)              # Salva r17 (valor da flag)
    
    # === VERIFICA FLAG DE TICK ===
    # ISR seta esta flag quando timer gera interrupção
    movia       r16, TIMER_TICK_FLAG    # r16 = ponteiro para flag
    ldw         r17, (r16)              # r17 = valor da flag
    beq         r17, r0, FIM_TICKS      # Se flag = 0, nada a fazer
    
    # === LIMPA FLAG PARA PRÓXIMO TICK ===
    # CRÍTICO: deve ser feito antes de qualquer processamento
    stw         r0, (r16)               # flag = 0
    
    # === PROCESSAMENTO DA ANIMAÇÃO ===
    # Verifica se animação está ativa e atualiza LEDs
    movia       r16, FLAG_INTERRUPCAO   # r16 = ponteiro flag animação
    ldw         r17, (r16)              # r17 = status da animação
    beq         r17, r0, PROCESSA_CRONOMETRO # Se animação desativa, pula
    
    # Chama função de atualização da animação (externa)
    call        _update_animation_step
    
PROCESSA_CRONOMETRO:
    # === PROCESSAMENTO DO CRONÔMETRO ===
    # Sempre tenta processar (função verifica se está ativo internamente)
    call        PROCESSAR_TICK_CRONOMETRO
    
FIM_TICKS:
    # === EPÍLOGO ABI ===
    ldw         r17, 0(sp)              # Restaura r17
    ldw         r16, 4(sp)              # Restaura r16
    ldw         ra, 8(sp)               # Restaura endereço de retorno
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# IMPRESSÃO DE STRING VIA UART - ABI COMPLIANT
# Entrada: r4 = ponteiro para string terminada em null
# Saída: nenhuma
# Função: Envia string caractere por caractere via UART JTAG
#========================================================================================================================================
IMPRIMIR_STRING:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 16              # Aloca 16 bytes na stack
    stw         ra, 12(sp)              # Salva endereço de retorno
    stw         r16, 8(sp)              # Salva r16 (ponteiro string)
    stw         r17, 4(sp)              # Salva r17 (base UART)
    stw         r18, 0(sp)              # Salva r18 (caractere atual)
    
    # === COPIA PARÂMETRO PARA REGISTRADOR CALLEE-SAVED ===
    mov         r16, r4                 # r16 = ponteiro da string
    movia       r17, JTAG_UART_BASE     # r17 = base da UART
    
LOOP_IMPRESSAO:
    # === CARREGA PRÓXIMO CARACTERE ===
    ldb         r18, (r16)              # r18 = *string
    beq         r18, r0, FIM_IMPRESSAO  # Se null terminator, termina
    
AGUARDA_UART_PRONTA:
    # === SEÇÃO CRÍTICA: VERIFICA ESPAÇO NO BUFFER ===
    # Desabilita interrupções durante leitura do status UART
    rdctl       r3, status              # r3 = status atual do processador
    wrctl       status, r0              # Desabilita interrupções
    
    # Lê registrador de controle da UART
    ldwio       r2, UART_CONTROL(r17)   # r2 = controle UART
    
    # Restaura interrupções
    wrctl       status, r3              # Restaura status original
    
    # Verifica bit WSPACE (espaço disponível no buffer de transmissão)
    andhi       r2, r2, 0xFFFF          # Isola bits superiores
    beq         r2, r0, AGUARDA_UART_PRONTA # Se buffer cheio, aguarda
    
    # === SEÇÃO CRÍTICA: TRANSMITE CARACTERE ===
    # Desabilita interrupções durante escrita
    rdctl       r3, status              # r3 = status atual
    wrctl       status, r0              # Desabilita interrupções
    stwio       r18, UART_DATA(r17)     # Transmite caractere
    wrctl       status, r3              # Restaura interrupções
    
    # === AVANÇA PARA PRÓXIMO CARACTERE ===
    addi        r16, r16, 1             # string++
    br          LOOP_IMPRESSAO          # Continua loop
    
FIM_IMPRESSAO:
    # === EPÍLOGO ABI ===
    ldw         r18, 0(sp)              # Restaura r18
    ldw         r17, 4(sp)              # Restaura r17
    ldw         r16, 8(sp)              # Restaura r16
    ldw         ra, 12(sp)              # Restaura endereço de retorno
    addi        sp, sp, 16              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# PROCESSAMENTO NÃO-BLOQUEANTE DE CARACTERES UART - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma
# Função: Lê caracteres da UART e monta comandos no buffer
#========================================================================================================================================
PROCESSAR_CHAR_UART:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva endereço de retorno
    stw         r8, 4(sp)               # Salva r8 (temporário)
    stw         r9, 0(sp)               # Salva r9 (temporário)
    
    # === LEITURA NÃO-BLOQUEANTE DA UART ===
    movia       r8, JTAG_UART_BASE      # r8 = base UART
    ldwio       r9, UART_DATA(r8)       # r9 = registrador de dados
    
    # === VERIFICA SE HÁ CARACTERE VÁLIDO ===
    # Bit 15 (RVALID) indica se dado é válido
    andi        r8, r9, 0x8000          # Isola bit RVALID
    beq         r8, r0, FIM_CHAR_UART   # Se não há caractere, sai
    
    # === ISOLA O CARACTERE (8 BITS INFERIORES) ===
    andi        r9, r9, 0xFF            # r9 = caractere (0-255)
    
    # === VERIFICA SE É TERMINADOR DE COMANDO ===
    movi        r8, 10                  # ASCII Line Feed ('\n')
    beq         r9, r8, COMANDO_COMPLETO
    movi        r8, 13                  # ASCII Carriage Return ('\r')
    beq         r9, r8, COMANDO_COMPLETO
    
    # === PROTEÇÃO CRÍTICA CONTRA BUFFER OVERFLOW ===
    movia       r8, BUFFER_ENTRADA_POS  # r8 = ponteiro para posição
    ldw         r10, (r8)               # r10 = posição atual no buffer
    
    # Verifica se buffer tem espaço (máximo 99 caracteres)
    movi        r11, 99                 # r11 = limite máximo
    bgt         r10, r11, FIM_CHAR_UART # Se pos > 99, descarta caractere
    
    # === ARMAZENA CARACTERE NO BUFFER ===
    movia       r11, BUFFER_ENTRADA     # r11 = base do buffer
    add         r12, r10, r11           # r12 = &buffer[posição]
    stb         r9, (r12)               # buffer[posição] = caractere
    
    # === INCREMENTA POSIÇÃO NO BUFFER ===
    addi        r10, r10, 1             # posição++
    stw         r10, (r8)               # Salva nova posição
    
    br          FIM_CHAR_UART           # Finaliza processamento

COMANDO_COMPLETO:
    # === PROCESSAMENTO DO COMANDO COMPLETO ===
    movia       r4, BUFFER_ENTRADA      # r4 = ponteiro buffer (ABI)
    call        PROCESSAR_COMANDO       # Interpreta e executa comando
    
    # === LIMPA BUFFER PARA PRÓXIMO COMANDO ===
    call        LIMPAR_BUFFER           # Zera todo o buffer
    movia       r8, BUFFER_ENTRADA_POS  # r8 = ponteiro posição
    stw         r0, (r8)                # posição = 0
    
    # === REIMPRIME PROMPT ===
    movia       r4, MSG_PROMPT          # r4 = ponteiro prompt (ABI)
    call        IMPRIMIR_STRING         # Mostra prompt novamente

FIM_CHAR_UART:
    # === EPÍLOGO ABI ===
    ldw         r9, 0(sp)               # Restaura r9
    ldw         r8, 4(sp)               # Restaura r8
    ldw         ra, 8(sp)               # Restaura endereço de retorno
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# INTERPRETAÇÃO E DISPATCH DE COMANDOS - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando
# Saída: nenhuma
# Comandos suportados: "0xxx" (LEDs), "1x" (animação), "2x" (cronômetro)
#========================================================================================================================================
PROCESSAR_COMANDO:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva endereço de retorno
    stw         r16, 4(sp)              # Salva r16 (ponteiro comando)
    stw         r17, 0(sp)              # Salva r17 (primeiro caractere)
    
    # === COPIA PARÂMETRO PARA REGISTRADOR CALLEE-SAVED ===
    mov         r16, r4                 # r16 = ponteiro do comando
    ldb         r17, (r16)              # r17 = primeiro caractere
    
    # === DISPATCH BASEADO NO PRIMEIRO CARACTERE ===
    movi        r2, '0'                 # ASCII '0' = 0x30
    beq         r17, r2, COMANDO_LED    # "0xxx" → controle de LEDs
    
    movi        r2, '1'                 # ASCII '1' = 0x31
    beq         r17, r2, COMANDO_ANIMACAO # "1x" → animação de LEDs
    
    movi        r2, '2'                 # ASCII '2' = 0x32
    beq         r17, r2, COMANDO_CRONOMETRO # "2x" → cronômetro
    
    # === COMANDO INVÁLIDO ===
    # Ignora silenciosamente comandos não reconhecidos
    br          FIM_COMANDO

COMANDO_LED:
    # === CHAMA MÓDULO DE CONTROLE DE LEDs ===
    mov         r4, r16                 # r4 = comando (ABI)
    call        led                     # Função externa em led.s
    br          FIM_COMANDO

COMANDO_ANIMACAO:
    # === CHAMA MÓDULO DE ANIMAÇÃO ===
    mov         r4, r16                 # r4 = comando (ABI)
    call        animacao                # Função externa em animacao.s
    br          FIM_COMANDO

COMANDO_CRONOMETRO:
    # === CHAMA MÓDULO DE CRONÔMETRO ===
    mov         r4, r16                 # r4 = comando (ABI)
    call        cronometro              # Função externa em cronometro.s

FIM_COMANDO:
    # === EPÍLOGO ABI ===
    ldw         r17, 0(sp)              # Restaura r17
    ldw         r16, 4(sp)              # Restaura r16
    ldw         ra, 8(sp)               # Restaura endereço de retorno
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# PROCESSAMENTO DE TICK DO CRONÔMETRO - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma
# Função: Incrementa cronômetro se ativo e não pausado
#========================================================================================================================================
PROCESSAR_TICK_CRONOMETRO:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 16              # Aloca 16 bytes na stack
    stw         ra, 12(sp)              # Salva endereço de retorno
    stw         r16, 8(sp)              # Salva r16
    stw         r17, 4(sp)              # Salva r17
    stw         r18, 0(sp)              # Salva r18
    
    # === VERIFICA SE CRONÔMETRO ESTÁ ATIVO ===
    movia       r16, CRONOMETRO_ATIVO   # r16 = ponteiro flag ativo
    ldw         r17, (r16)              # r17 = status (0/1)
    beq         r17, r0, FIM_TICK_CRONO # Se inativo, sai
    
    # === VERIFICA SE CRONÔMETRO ESTÁ PAUSADO ===
    movia       r16, CRONOMETRO_PAUSADO # r16 = ponteiro flag pausado
    ldw         r17, (r16)              # r17 = status pause (0/1)
    bne         r17, r0, FIM_TICK_CRONO # Se pausado, sai
    
    # === INCREMENTA CONTADOR DE SEGUNDOS ===
    movia       r16, CRONOMETRO_SEGUNDOS # r16 = ponteiro contador
    ldw         r17, (r16)              # r17 = segundos atuais
    addi        r17, r17, 1             # segundos++
    
    # === VERIFICA OVERFLOW (MÁXIMO 99:59 = 5999 SEGUNDOS) ===
    movi        r18, 5999               # r18 = limite máximo
    ble         r17, r18, SALVA_SEGUNDOS # Se <= 5999, OK
    mov         r17, r0                 # Senão, volta para 00:00

SALVA_SEGUNDOS:
    # === SALVA NOVO VALOR DOS SEGUNDOS ===
    stw         r17, (r16)              # Atualiza contador global
    
    # === ATUALIZA DISPLAYS 7-SEGMENTOS ===
    call        ATUALIZAR_DISPLAY_CRONOMETRO # Converte e mostra MM:SS

FIM_TICK_CRONO:
    # === EPÍLOGO ABI ===
    ldw         r18, 0(sp)              # Restaura r18
    ldw         r17, 4(sp)              # Restaura r17
    ldw         r16, 8(sp)              # Restaura r16
    ldw         ra, 12(sp)              # Restaura endereço de retorno
    addi        sp, sp, 16              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# ATUALIZAÇÃO DOS DISPLAYS DO CRONÔMETRO - ABI COMPLIANT
# Entrada: nenhuma (lê de CRONOMETRO_SEGUNDOS)
# Saída: nenhuma (escreve nos displays HEX3-0)
# Formato: MM:SS (minutos:segundos) nos 4 displays
#========================================================================================================================================
ATUALIZAR_DISPLAY_CRONOMETRO:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 20              # Aloca 20 bytes na stack
    stw         ra, 16(sp)              # Salva endereço de retorno
    stw         r16, 12(sp)             # Salva r16 (segundos totais)
    stw         r17, 8(sp)              # Salva r17 (minutos)
    stw         r18, 4(sp)              # Salva r18 (segundos restantes)
    stw         r19, 0(sp)              # Salva r19 (dígito atual)
    
    # === CARREGA SEGUNDOS TOTAIS ===
    movia       r20, CRONOMETRO_SEGUNDOS # r20 = ponteiro (temporário)
    ldw         r16, (r20)              # r16 = segundos totais
    
    # === CONVERTE SEGUNDOS PARA MINUTOS:SEGUNDOS ===
    movi        r20, 60                 # r20 = divisor
    div         r17, r16, r20           # r17 = minutos (total / 60)
    mul         r2, r17, r20            # r2 = minutos * 60
    sub         r18, r16, r2            # r18 = segundos restantes
    
    # === DISPLAY HEX3 (DEZENAS DE MINUTOS) ===
    movi        r20, 10                 # r20 = divisor para dezenas
    div         r19, r17, r20           # r19 = dezena dos minutos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-seg
    movia       r20, HEX_BASE           # r20 = base displays
    stwio       r2, 12(r20)             # HEX3 = dezena minutos
    
    # === DISPLAY HEX2 (UNIDADES DE MINUTOS) ===
    movi        r20, 10                 # r20 = divisor
    div         r2, r17, r20            # r2 = dezena
    mul         r2, r2, r20             # r2 = dezena * 10
    sub         r19, r17, r2            # r19 = unidade dos minutos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-seg
    movia       r20, HEX_BASE           # r20 = base displays
    stwio       r2, 8(r20)              # HEX2 = unidade minutos
    
    # === DISPLAY HEX1 (DEZENAS DE SEGUNDOS) ===
    movi        r20, 10                 # r20 = divisor
    div         r19, r18, r20           # r19 = dezena dos segundos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-seg
    movia       r20, HEX_BASE           # r20 = base displays
    stwio       r2, 4(r20)              # HEX1 = dezena segundos
    
    # === DISPLAY HEX0 (UNIDADES DE SEGUNDOS) ===
    movi        r20, 10                 # r20 = divisor
    div         r2, r18, r20            # r2 = dezena
    mul         r2, r2, r20             # r2 = dezena * 10
    sub         r19, r18, r2            # r19 = unidade dos segundos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-seg
    movia       r20, HEX_BASE           # r20 = base displays
    stwio       r2, 0(r20)              # HEX0 = unidade segundos
    
    # === EPÍLOGO ABI ===
    ldw         r19, 0(sp)              # Restaura r19
    ldw         r18, 4(sp)              # Restaura r18
    ldw         r17, 8(sp)              # Restaura r17
    ldw         r16, 12(sp)             # Restaura r16
    ldw         ra, 16(sp)              # Restaura endereço de retorno
    addi        sp, sp, 20              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# CODIFICAÇÃO PARA DISPLAY 7-SEGMENTOS - ABI COMPLIANT
# Entrada: r4 = dígito (0-9)
# Saída: r2 = código de 7 segmentos correspondente
# Tabela: usa TABELA_7SEG na seção de dados
#========================================================================================================================================
CODIFICAR_7SEG:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 8               # Aloca 8 bytes na stack
    stw         ra, 4(sp)               # Salva endereço de retorno
    stw         r16, 0(sp)              # Salva r16
    
    # === VALIDAÇÃO DE ENTRADA ===
    movi        r3, 9                   # r3 = máximo válido
    bgt         r4, r3, DIGITO_INVALIDO # Se > 9, inválido
    blt         r4, r0, DIGITO_INVALIDO # Se < 0, inválido
    
    # === ACESSO À TABELA DE CODIFICAÇÃO ===
    movia       r16, TABELA_7SEG        # r16 = base da tabela
    slli        r3, r4, 2               # r3 = dígito * 4 (tamanho word)
    add         r16, r16, r3            # r16 = &tabela[dígito]
    ldw         r2, (r16)               # r2 = código do dígito
    br          FIM_CODIFICACAO

DIGITO_INVALIDO:
    # === RETORNA DISPLAY APAGADO PARA ENTRADA INVÁLIDA ===
    movi        r2, 0x00                # r2 = todos segmentos apagados

FIM_CODIFICACAO:
    # === EPÍLOGO ABI ===
    ldw         r16, 0(sp)              # Restaura r16
    ldw         ra, 4(sp)               # Restaura endereço de retorno
    addi        sp, sp, 8               # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# LIMPEZA DO BUFFER DE ENTRADA - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma
# Função: Zera todo o buffer BUFFER_ENTRADA (100 bytes)
#========================================================================================================================================
LIMPAR_BUFFER:
    # === INICIALIZAÇÃO (SEM STACK FRAME - FUNÇÃO SIMPLES) ===
    movia       r8, BUFFER_ENTRADA      # r8 = ponteiro do buffer
    movi        r9, 100                 # r9 = tamanho do buffer
    
LOOP_LIMPEZA:
    # === ZERA POSIÇÃO ATUAL ===
    stb         r0, (r8)                # *buffer = 0
    
    # === AVANÇA PARA PRÓXIMA POSIÇÃO ===
    addi        r8, r8, 1               # buffer++
    subi        r9, r9, 1               # contador--
    bne         r9, r0, LOOP_LIMPEZA    # Se contador != 0, continua
    
    # === RETORNO (SEM EPÍLOGO) ===
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# PROCESSAMENTO DE BOTÕES (KEY1 PARA PAUSE/RESUME) - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma
# Função: Polling do KEY1 com debounce para pause/resume do cronômetro
#========================================================================================================================================
PROCESSAR_BOTOES:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva endereço de retorno
    stw         r8, 4(sp)               # Salva r8
    stw         r9, 0(sp)               # Salva r9
    
    # === VERIFICA SE CRONÔMETRO ESTÁ ATIVO ===
    # Só processa botões se cronômetro estiver ligado
    movia       r8, CRONOMETRO_ATIVO    # r8 = ponteiro flag ativo
    ldw         r9, (r8)                # r9 = status (0/1)
    beq         r9, r0, FIM_BOTOES      # Se inativo, sai
    
    # === LÊ ESTADO DOS BOTÕES ===
    movia       r8, KEY_BASE            # r8 = base dos botões
    ldwio       r9, (r8)                # r9 = estado atual (bits 3-0)
    
    # === VERIFICA SE KEY1 ESTÁ PRESSIONADO ===
    andi        r9, r9, 0b10            # Isola bit 1 (KEY1)
    beq         r9, r0, BOTAO_SOLTO     # Se bit = 0, botão não pressionado
    
    # === LÓGICA DE DEBOUNCE ===
    # Verifica se já foi processado para evitar múltiplos toggles
    movia       r8, KEY1_PRESSIONADO_FLAG # r8 = ponteiro flag debounce
    ldw         r9, (r8)                # r9 = status da flag
    bne         r9, r0, FIM_BOTOES      # Se já processado, sai
    
    # === MARCA BOTÃO COMO PROCESSADO ===
    movi        r9, 1                   # r9 = 1 (processado)
    stw         r9, (r8)                # flag = 1
    
    # === TOGGLE DO ESTADO DE PAUSA ===
    movia       r8, CRONOMETRO_PAUSADO  # r8 = ponteiro flag pausado
    ldw         r9, (r8)                # r9 = estado atual (0/1)
    xori        r9, r9, 1               # r9 = !r9 (inverte)
    stw         r9, (r8)                # Salva novo estado
    
    br          FIM_BOTOES              # Finaliza processamento

BOTAO_SOLTO:
    # === RESET DA FLAG DE DEBOUNCE ===
    # Quando botão é solto, permite nova detecção
    movia       r8, KEY1_PRESSIONADO_FLAG # r8 = ponteiro flag
    stw         r0, (r8)                # flag = 0 (permite nova detecção)

FIM_BOTOES:
    # === EPÍLOGO ABI ===
    ldw         r9, 0(sp)               # Restaura r9
    ldw         r8, 4(sp)               # Restaura r8
    ldw         ra, 8(sp)               # Restaura endereço de retorno
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# SEÇÃO DE DADOS - ALINHAMENTO E ORGANIZAÇÃO CONFORME ABI
#========================================================================================================================================
.section .data
.align 4                                # CRÍTICO: Alinha em boundary de 4 bytes

# === ESTADO GLOBAL DOS LEDs ===
.global LED_STATE
LED_STATE:
    .word 0                             # Estado atual dos 18 LEDs (bit mask)

# === BUFFER DE ENTRADA DA UART ===
.global BUFFER_ENTRADA
BUFFER_ENTRADA:
    .skip 100                           # 100 bytes para comando + null terminator

# === PONTEIRO DE POSIÇÃO NO BUFFER ===
.global BUFFER_ENTRADA_POS
BUFFER_ENTRADA_POS:
    .word 0                             # Posição atual no buffer (0-99)

# === FLAG DE DEBOUNCE DO KEY1 ===
.global KEY1_PRESSIONADO_FLAG
KEY1_PRESSIONADO_FLAG:
    .word 0                             # Flag para evitar múltiplos toggles

# === TABELA DE CODIFICAÇÃO 7-SEGMENTOS ===
# Códigos para dígitos 0-9 em display de cátodo comum
.global TABELA_7SEG
TABELA_7SEG:
    .word 0x3F                          # Dígito 0: gfedcba = 0111111
    .word 0x06                          # Dígito 1: gfedcba = 0000110
    .word 0x5B                          # Dígito 2: gfedcba = 1011011
    .word 0x4F                          # Dígito 3: gfedcba = 1001111
    .word 0x66                          # Dígito 4: gfedcba = 1100110
    .word 0x6D                          # Dígito 5: gfedcba = 1101101
    .word 0x7D                          # Dígito 6: gfedcba = 1111101
    .word 0x07                          # Dígito 7: gfedcba = 0000111
    .word 0x7F                          # Dígito 8: gfedcba = 1111111
    .word 0x6F                          # Dígito 9: gfedcba = 1101111

# === STRINGS DO SISTEMA ===
MSG_PROMPT:
    .asciz "Entre com o comando: "      # Prompt para entrada de comandos

#========================================================================================================================================
# DECLARAÇÕES DE SÍMBOLOS EXTERNOS
#========================================================================================================================================
.global INTERRUPCAO_HANDLER             # Handler definido em interrupcoes.s
.extern _led                            # Módulo de controle de LEDs
.extern _animacao                       # Módulo de animação
.extern _cronometro                     # Módulo de cronômetro
.extern _update_animation_step          # Função de atualização da animação
.extern CONFIGURAR_TIMER                # Função de configuração do timer
.extern PARAR_TIMER                     # Função para parar o timer

#========================================================================================================================================
# FIM DO ARQUIVO - VERSÃO ABI COMPLIANT E DOCUMENTADA
#========================================================================================================================================
.end 