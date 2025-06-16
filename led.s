.global _led

# Incluir constantes do main.s
.equ LED_BASE,      0x10000000
.equ ASCII_0,       0x30

#========================================================================================================================================
# Função: _led - Controlar LEDs individuais
# Parâmetros: r4 = buffer do comando (ex: "00 05" ou "01 12")
# Formato: [operação][espaço][número do LED]
#   00 XX - Acender LED XX
#   01 XX - Apagar LED XX
#   XX = 00-17 (LEDs disponíveis na DE2-115)
#========================================================================================================================================

_led:
    # Preservar registradores (Stack Frame)
    addi    sp, sp, -28
    stw     ra, 24(sp)
    stw     r16, 20(sp)         # Buffer do comando
    stw     r17, 16(sp)         # Operação (0=acender, 1=apagar)
    stw     r18, 12(sp)         # Número do LED
    stw     r19, 8(sp)          # Registrador de trabalho
    stw     r20, 4(sp)          # Base dos LEDs
    stw     r21, 0(sp)          # Estado atual dos LEDs
    
    mov     r16, r4             # r16 = buffer do comando
    
    # Extrair operação (já validada no parser principal)
    ldb     r19, 1(r16)         # Segundo dígito da operação
    subi    r17, r19, ASCII_0   # r17 = operação (0 ou 1)
    
    # Pular espaço e ir para o número do LED
    # Formato esperado: "00 05" ou "01 12"
    addi    r16, r16, 3         # Pular "00 " ou "01 "
    
    # Extrair número do LED (formato: "05", "12", etc.)
    ldb     r19, 0(r16)         # Dezena
    subi    r19, r19, ASCII_0   # Converter de ASCII para número
    
    # Validar dígito da dezena
    bltu    r19, r0, led_error # Se for < 0, erro
    movi    r20, 1             # número máximo da dezena
    bgtu    r19, r20, led_error # Se for > 1, erro
    
    # Calcular dezena * 10 usando shifts: 10 = 8 + 2
    slli    r20, r19, 3         # r20 = r19 * 8
    slli    r19, r19, 1         # r19 = r19 * 2
    add     r19, r20, r19       # r19 = r19*8 + r19*2 = r19*10
    mov     r18, r19            # r18 = dezena * 10
    
    # Extrair unidade
    ldb     r19, 1(r16)         # Unidade
    subi    r19, r19, ASCII_0   # Converter de ASCII para número
    
    # Validar dígito da unidade
    bltu    r19, r0, led_error # Se for < 0, erro
    movi    r20, 9              # número máximo da unidade
    bgtu    r19, r20, led_error # Se for > 9, erro
    
    # Calcular número final do LED
    add     r18, r18, r19       # r18 = dezena*10 + unidade
    
    # Carregar base dos LEDs e estado atual
    movia   r20, LED_BASE
    ldwio   r21, 0(r20)         # r21 = estado atual dos LEDs
    
    # Criar máscara para o LED específico
    movi    r19, 1
    sll     r19, r19, r18       # r19 = máscara (1 << número_do_LED)
    
    # Verificar operação
    beq     r17, r0, led_on     # Se operação = 0, acender LED
    movi    r20, 1              # Usar r20 temporariamente para comparação
    beq     r17, r20, led_off   # Se operação = 1, apagar LED
    br      led_error
    
led_on:
    # Acender LED: estado_atual |= (1 << número_do_LED)
    or      r21, r21, r19
    br      led_update
    
led_off:
    # Apagar LED: estado_atual &= ~(1 << número_do_LED)
    nor     r19, r19, r0        # r19 = ~r19 (inverte todos os bits)
    and     r21, r21, r19       # Atualizar o estado do LED (apagar o LED)
    br      led_update

    
led_update:
    # Atualizar LEDs
    stwio   r21, 0(r20)
    br      led_done
    
led_error:
    # IMPLEMENTAR FUNÇÃO DE ERRO
    nop
    
led_done:
    # Restaurar registradores
    ldw     r21, 0(sp)
    ldw     r20, 4(sp)
    ldw     r19, 8(sp)
    ldw     r18, 12(sp)
    ldw     r17, 16(sp)
    ldw     r16, 20(sp)
    ldw     ra, 24(sp)
    addi    sp, sp, 28
    ret
