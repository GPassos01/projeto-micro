#========================================================================================================================================
# Controle de Cronometro - Nios II Assembly
# Comandos: 20 (iniciar cronometro), 21 (cancela cronometro)
# Descrição: 
#   Inicia cronometro de segundos, utilizando 4 displays de 7 segmentos. 
#   Adicionalmente, o botao KEY1 deve controlar a pausa do cronometro: 
#   se contagem em andamento, deve ser pausada; se pausada, contagem deve ser resumida.
#
# Formato: 20 ou 21
#========================================================================================================================================

.global _cronometro

_cronometro:
    # Preservar registradores
    addi    sp, sp, -12
    stw     ra, 8(sp)
    stw     r16, 4(sp)
    stw     r17, 0(sp)

    
    # Restaurar registradores
    ldw     r17, 0(sp)
    ldw     r16, 4(sp)
    ldw     ra, 8(sp)
    addi    sp, sp, 12
    ret
ret