#========================================================================================================================================
# Controle de Interrupcoes - Nios II Assembly
# Descrição: 
#   A interrupcao deve ser controlada pelo botão KEY1: 
#   se botão pressionado, interrupcao deve ser iniciada.
#
#========================================================================================================================================

.global _interrupcoes
.org		0x20

_interrupcoes:
    # Preservar registradores
    addi    sp, sp, -12
    stw     ra, 4(sp)
    stw     r13, 0(sp)

    # EXCEPTIONS HANDLER
    rdctl		et,		ipending                    # verifica se houve interrupcao externa
    beq         et,     r0,     OTHER_EXCEPTIONS    # se 0, checa excecoes
    subi        ea,     ea,     4                   # interrupcao de hardware, decrementa ea
    andi        r13,    et,     2                   # checa se irq1 ta acionado
    beq         r13,    r0,     OTHER_INTERRUPTS    # se não, checa outras interrupcoes externas
    
    #call		                          # se sim, vai para funcao

    OTHER_INTERRUPTS:
    # INSTRUCOES PARA CHECAR OUTRAS INTERRUPCOES DE HARDWARE
    nop
    br          END_HANDLER

    OTHER_EXCEPTIONS:
    # INTRUCOES PARA CHECAR POR INTERRUPCOES DE OUTRO TIPO
    nop

    # Restaurar registradores
    ldw     r13, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 12
    END_HANDLER:
    eret
ret