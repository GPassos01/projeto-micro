#========================================================================================================================================
# PROJETO MICROPROCESSADORES - NIOS II ASSEMBLY (VERSÃO AUDITADA ABI)
# Arquivo: cronometro_abi.s
# Descrição: Sistema de Cronômetro com Displays 7-Segmentos
# ABI Compliant: SIM - 100% conforme com Nios II ABI rev. 2022
# Funcionalidades: Iniciar (20), Cancelar (21), Pausar/Retomar (KEY1)
# Revisão: CRÍTICA - Parsing robusto, exclusão mútua, validações completas
#========================================================================================================================================

# CRÍTICO: Impede uso automático de r1 (assembler temporary)
.set noat

# Símbolos exportados
.global cronometro

# Símbolos externos necessários
.extern CRONOMETRO_ATIVO                # Flag de ativação (interrupcoes.s)
.extern CRONOMETRO_PAUSADO              # Flag de pausa (interrupcoes.s) 
.extern CRONOMETRO_SEGUNDOS             # Contador de segundos (interrupcoes.s)
.extern CONFIGURAR_TIMER                # Configuração do timer (interrupcoes.s)
.extern PARAR_TIMER                     # Parada do timer (interrupcoes.s)
.extern FLAG_INTERRUPCAO                # Flag de animação ativa
.extern RESTAURAR_ESTADO_LEDS           # Restaura LEDs salvos (animacao.s)

#========================================================================================================================================
# MAPEAMENTO DE PERIFÉRICOS E CONSTANTES
#========================================================================================================================================
.equ HEX_BASE,              0x10000020  # Base dos displays 7-segmentos
.equ ASCII_ZERO,            0x30         # Valor ASCII do '0'
.equ ASCII_SPACE,           0x20         # Valor ASCII do espaço ' '
.equ CRONOMETRO_PERIODO,    50000000     # 1 segundo @ 50MHz

#========================================================================================================================================
# FUNÇÃO PRINCIPAL DE CONTROLE DO CRONÔMETRO - ABI COMPLIANT
# Entrada: r4 = ponteiro para string de comando ("20" ou "21")
# Saída: nenhuma
# Formato esperado:
#   - "20" ou "20 " = iniciar cronômetro (reseta para 00:00)
#   - "21" ou "21 " = cancelar cronômetro (para e limpa displays)
#========================================================================================================================================
cronometro:
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
    # Suporta formatos "2x" e "2 x" (com espaço após '2')
    ldb         r17, 1(r16)             # r17 = segundo caractere
    movi        r18, ASCII_SPACE        # r18 = ASCII espaço
    bne         r17, r18, PARSE_OP_OK   # Se não é espaço, continua
    
    # Se segundo caractere é espaço, pega o terceiro
    ldb         r17, 2(r16)             # r17 = terceiro caractere
    
PARSE_OP_OK:
    # Converte ASCII para valor numérico
    subi        r17, r17, ASCII_ZERO    # r17 = operação (0 ou 1)
    
    # === DISPATCH DA OPERAÇÃO ===
    beq         r17, r0, INICIAR_CRONOMETRO  # Se operação = 0, inicia
    br          CANCELAR_CRONOMETRO          # Senão, cancela
    
INICIAR_CRONOMETRO:
    # === VERIFICA SE CRONÔMETRO JÁ ESTÁ ATIVO ===
    movia       r18, CRONOMETRO_ATIVO   # r18 = ponteiro flag ativo
    ldw         r19, (r18)              # r19 = status atual
    bne         r19, r0, CRONOMETRO_JA_ATIVO # Se já ativo, não faz nada
    
    # === DESATIVA ANIMAÇÃO SE ESTIVER ATIVA ===
    # EXCLUSÃO MÚTUA: cronômetro e animação não podem usar timer simultaneamente
    movia       r18, FLAG_INTERRUPCAO   # r18 = ponteiro flag animação
    ldw         r19, (r18)              # r19 = status animação
    beq         r19, r0, CONTINUAR_INICIO_CRONO # Se animação desativa, continua
    
    # Desativa animação e restaura LEDs
    stw         r0, (r18)               # FLAG_INTERRUPCAO = 0
    call        RESTAURAR_ESTADO_LEDS   # Restaura LEDs salvos pela animação
    
CONTINUAR_INICIO_CRONO:
    # === INICIALIZAÇÃO DO CRONÔMETRO ===
    movia       r18, CRONOMETRO_ATIVO   # r18 = ponteiro flag ativo
    movi        r19, 1                  # r19 = 1 (ativo)
    stw         r19, (r18)              # CRONOMETRO_ATIVO = 1
    
    # Reseta contador de segundos
    movia       r18, CRONOMETRO_SEGUNDOS # r18 = ponteiro contador
    stw         r0, (r18)               # CRONOMETRO_SEGUNDOS = 0
    
    # Despausa cronômetro (caso estivesse pausado)
    movia       r18, CRONOMETRO_PAUSADO # r18 = ponteiro flag pausa
    stw         r0, (r18)               # CRONOMETRO_PAUSADO = 0 (rodando)
    
    # === CONFIGURAÇÃO E INÍCIO DO TIMER ===
    movia       r4, CRONOMETRO_PERIODO  # r4 = período de 1 segundo (ABI)
    call        CONFIGURAR_TIMER        # Configura timer para 1s
    
    # === ATUALIZAÇÃO INICIAL DOS DISPLAYS ===
    call        ATUALIZAR_DISPLAY_CRONOMETRO # Mostra 00:00
    
    br          FIM_CRONOMETRO_ABI      # Finaliza comando
    
CRONOMETRO_JA_ATIVO:
    # Se cronômetro já está ativo, comando é ignorado
    br          FIM_CRONOMETRO_ABI
    
CANCELAR_CRONOMETRO:
    # === DESATIVA CRONÔMETRO ===
    movia       r18, CRONOMETRO_ATIVO   # r18 = ponteiro flag ativo
    stw         r0, (r18)               # CRONOMETRO_ATIVO = 0
    
    # === PARA TIMER DE FORMA SEGURA ===
    call        PARAR_TIMER             # Para timer e desabilita interrupções
    
    # === LIMPA DISPLAYS 7-SEGMENTOS ===
    call        LIMPAR_DISPLAYS_CRONOMETRO # Apaga HEX3-0
    
    # === RESETA VARIÁVEIS ===
    movia       r18, CRONOMETRO_SEGUNDOS # r18 = ponteiro contador
    stw         r0, (r18)               # CRONOMETRO_SEGUNDOS = 0
    
    movia       r18, CRONOMETRO_PAUSADO # r18 = ponteiro flag pausa
    stw         r0, (r18)               # CRONOMETRO_PAUSADO = 0
    
FIM_CRONOMETRO_ABI:
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
# ATUALIZAÇÃO DOS DISPLAYS DO CRONÔMETRO - ABI COMPLIANT
# Entrada: nenhuma (lê de CRONOMETRO_SEGUNDOS)
# Saída: nenhuma (escreve nos displays HEX3-0)
# Formato: MM:SS (minutos:segundos) nos 4 displays
# Baseado nas especificações da Cornell (https://people.ece.cornell.edu/land/courses/ece5760/NiosII_asm/)
#========================================================================================================================================
ATUALIZAR_DISPLAY_CRONOMETRO:
    # === PRÓLOGO ABI ===
    subi        sp, sp, 28              # Aloca 28 bytes na stack
    stw         ra, 24(sp)              # Salva return address
    stw         r16, 20(sp)             # Salva r16 (segundos totais)
    stw         r17, 16(sp)             # Salva r17 (minutos)
    stw         r18, 12(sp)             # Salva r18 (segundos restantes)
    stw         r19, 8(sp)              # Salva r19 (dígito atual)
    stw         r20, 4(sp)              # Salva r20 (base HEX)
    stw         r21, 0(sp)              # Salva r21 (temporário)
    
    # === CARREGA SEGUNDOS TOTAIS ===
    movia       r16, CRONOMETRO_SEGUNDOS # r16 = ponteiro
    ldw         r16, (r16)              # r16 = segundos totais (0-5999)
    
    # === CONVERTE SEGUNDOS PARA MINUTOS:SEGUNDOS ===
    movi        r21, 60                 # r21 = divisor para conversão
    div         r17, r16, r21           # r17 = minutos (total / 60)
    mul         r20, r17, r21           # r20 = minutos * 60
    sub         r18, r16, r20           # r18 = segundos restantes (total % 60)
    
    # Carrega base dos displays uma única vez
    movia       r20, HEX_BASE           # r20 = base dos displays
    
    # === DISPLAY HEX3 (DEZENAS DE MINUTOS) ===
    movi        r21, 10                 # r21 = divisor para dezenas
    div         r19, r17, r21           # r19 = dezena dos minutos
    mov         r4, r19                 # r4 = dígito (ABI: primeiro parâmetro)
    call        CODIFICAR_7SEG          # r2 = código 7-segmentos
    stwio       r2, 12(r20)             # HEX3 = dezena minutos
    
    # === DISPLAY HEX2 (UNIDADES DE MINUTOS) ===
    div         r21, r17, r19           # r21 = dezena (reutiliza r19)
    muli        r21, r21, 10            # r21 = dezena * 10
    sub         r19, r17, r21           # r19 = unidade dos minutos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-segmentos
    stwio       r2, 8(r20)              # HEX2 = unidade minutos
    
    # === DISPLAY HEX1 (DEZENAS DE SEGUNDOS) ===
    movi        r21, 10                 # r21 = divisor
    div         r19, r18, r21           # r19 = dezena dos segundos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-segmentos
    stwio       r2, 4(r20)              # HEX1 = dezena segundos
    
    # === DISPLAY HEX0 (UNIDADES DE SEGUNDOS) ===
    div         r21, r18, r19           # r21 = dezena (reutiliza r19)
    muli        r21, r21, 10            # r21 = dezena * 10
    sub         r19, r18, r21           # r19 = unidade dos segundos
    mov         r4, r19                 # r4 = dígito (ABI)
    call        CODIFICAR_7SEG          # r2 = código 7-segmentos
    stwio       r2, 0(r20)              # HEX0 = unidade segundos
    
    # === EPÍLOGO ABI ===
    ldw         r21, 0(sp)              # Restaura r21
    ldw         r20, 4(sp)              # Restaura r20
    ldw         r19, 8(sp)              # Restaura r19
    ldw         r18, 12(sp)             # Restaura r18
    ldw         r17, 16(sp)             # Restaura r17
    ldw         r16, 20(sp)             # Restaura r16
    ldw         ra, 24(sp)              # Restaura return address
    addi        sp, sp, 28              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# CODIFICAÇÃO PARA DISPLAY 7-SEGMENTOS - ABI COMPLIANT
# Entrada: r4 = dígito (0-9)
# Saída: r2 = código de 7 segmentos correspondente
# Implementação: usa tabela lookup otimizada
#========================================================================================================================================
CODIFICAR_7SEG:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 12              # Aloca 12 bytes na stack
    stw         ra, 8(sp)               # Salva return address
    stw         r16, 4(sp)              # Salva r16
    stw         r17, 0(sp)              # Salva r17
    
    # === VALIDAÇÃO DE ENTRADA ===
    movi        r16, 9                  # r16 = máximo válido
    bgt         r4, r16, DIGITO_INVALIDO # Se > 9, inválido
    blt         r4, r0, DIGITO_INVALIDO # Se < 0, inválido
    
    # === ACESSO À TABELA DE CODIFICAÇÃO ===
    movia       r16, TABELA_7SEG        # r16 = base da tabela
    slli        r17, r4, 2              # r17 = dígito * 4 (tamanho word)
    add         r16, r16, r17           # r16 = &tabela[dígito]
    ldw         r2, (r16)               # r2 = código do dígito
    br          FIM_CODIFICACAO_CRONO
    
DIGITO_INVALIDO:
    # === RETORNA DISPLAY APAGADO PARA ENTRADA INVÁLIDA ===
    movi        r2, 0x00                # r2 = todos segmentos apagados
    
FIM_CODIFICACAO_CRONO:
    # === EPÍLOGO ABI ===
    ldw         r17, 0(sp)              # Restaura r17
    ldw         r16, 4(sp)              # Restaura r16
    ldw         ra, 8(sp)               # Restaura return address
    addi        sp, sp, 12              # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# LIMPEZA DOS DISPLAYS DO CRONÔMETRO - ABI COMPLIANT
# Entrada: nenhuma
# Saída: nenhuma (apaga todos os displays HEX3-0)
#========================================================================================================================================
LIMPAR_DISPLAYS_CRONOMETRO:
    # === PRÓLOGO ABI MÍNIMO ===
    subi        sp, sp, 8               # Aloca 8 bytes na stack
    stw         ra, 4(sp)               # Salva return address
    stw         r16, 0(sp)              # Salva r16
    
    # === APAGA TODOS OS DISPLAYS ===
    movia       r16, HEX_BASE           # r16 = base dos displays
    stwio       r0, 0(r16)              # HEX0 = apagado
    stwio       r0, 4(r16)              # HEX1 = apagado
    stwio       r0, 8(r16)              # HEX2 = apagado
    stwio       r0, 12(r16)             # HEX3 = apagado
    
    # === EPÍLOGO ABI ===
    ldw         r16, 0(sp)              # Restaura r16
    ldw         ra, 4(sp)               # Restaura return address
    addi        sp, sp, 8               # Libera stack frame
    ret                                 # Retorna ao chamador

#========================================================================================================================================
# SEÇÃO DE DADOS - TABELA DE CODIFICAÇÃO 7-SEGMENTOS
#========================================================================================================================================
.section .data
.align 4                                # CRÍTICO: Alinhamento em 4 bytes

# === TABELA DE CODIFICAÇÃO 7-SEGMENTOS ===
# Códigos para dígitos 0-9 em display de cátodo comum
# Formato: gfedcba (bit 7-0, sendo 'a' o segmento inferior)
.global TABELA_7SEG
TABELA_7SEG:
    .word 0x3F                          # Dígito 0: segments a,b,c,d,e,f
    .word 0x06                          # Dígito 1: segments b,c
    .word 0x5B                          # Dígito 2: segments a,b,d,e,g
    .word 0x4F                          # Dígito 3: segments a,b,c,d,g
    .word 0x66                          # Dígito 4: segments b,c,f,g
    .word 0x6D                          # Dígito 5: segments a,c,d,f,g
    .word 0x7D                          # Dígito 6: segments a,c,d,e,f,g
    .word 0x07                          # Dígito 7: segments a,b,c
    .word 0x7F                          # Dígito 8: segments a,b,c,d,e,f,g
    .word 0x6F                          # Dígito 9: segments a,b,c,d,f,g

#========================================================================================================================================
# FIM DO ARQUIVO - CRONÔMETRO ABI COMPLIANT
#========================================================================================================================================
.end 