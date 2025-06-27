# ========================================================================
# vetores.s
#
# !! IMPORTANTE !!
# Este arquivo DEVE ser o PRIMEIRO na ordem de compilação do Altera Monitor.
# Ele define os vetores de Reset (0x00) e Exceção (0x20) para
# garantir o layout de memória correto.
# ========================================================================

.section .vectors, "ax" # Usamos uma seção customizada "vectors"

# ------------------------------------------------------------------------
# Vetor de Reset no endereço 0x00
# O processador começa aqui quando é ligado ou resetado.
# ------------------------------------------------------------------------
.org 0x00
RESET_VECTOR:
    br      _start              # Pula para o início do programa principal (em main.s)

# ------------------------------------------------------------------------
# Vetor de Exceção no endereço 0x20
# O processador pula para cá em qualquer exceção ou interrupção de HW.
# ------------------------------------------------------------------------
.org 0x20
EXCEPTION_VECTOR:
    br      INTERRUPCAO_HANDLER # Pula para a rotina de tratamento (em interrupcoes.s)


# Declara os símbolos como externos para que o linker possa encontrá-los
# nos outros arquivos durante a linkagem.
.extern _start
.extern INTERRUPCAO_HANDLER 