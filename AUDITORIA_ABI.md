# Auditoria de Conformidade ABI – Projeto Nios II (DE2-115)

> Versão: 30 jun 2025  
> Autor: Equipe de manutenção / ChatGPT-o3

---

## 1. Resumo executivo

* Revisão completa dos cinco módulos em Assembly (Nios II): `main.s`, `led.s`, `animacao.s`, `cronometro.s`, `interrupcoes.s`.
* Verificação de aderência à **Nios II Application Binary Interface (ABI)** rev. 2022: _stack frames_, preservação de registradores, alinhamento de dados e uso seguro de variáveis globais.
* Eliminação de _data-corruption_ causada por overflow do buffer UART.
* Implementação de exclusão mútua entre animação, cronômetro e controle manual de LEDs.

---

## 2. Normas ABI aplicadas

| # | Regra | Implementação |
|---|-------|---------------|
| 1 | Pilha cresce para endereços **menores**; `sp` (r27) aponta sempre para a primeira *word* livre | Todos os prólogos usam `subi sp, sp, N` |
| 2 | Argumentos 1-4 → `r4-r7`; valor de retorno → `r2` | Padrão em todas as _sub-rotinas_ |
| 3 | Registradores **callee-saved**: `r16-r23`, `fp(r29)`, `gp(r28)`, `ra(r31)` | Salvos/restaurados quando tocados |
| 4 | *Stack frame* múltiplo de 4 bytes | Garantido com `subi sp, sp, N (N mod 4 = 0)` |
| 5 | Prologue mínimo com salvamento de `ra` e `fp` | Padrão adotado |
| 6 | ISRs salvam somente registradores usados + `estatus` | `interrupcoes.s` segue |
| 7 | **Nenhum uso de `r1 (at)`** | Diretiva `.set noat` em todos os arquivos |
| 8 | Variáveis de ISR de 32 bits, acessadas atomically (`ldw/stw`) | `TIMER_TICK_FLAG`, `FLAG_INTERRUPCAO` etc. |

---

## 3. Relatório por arquivo

### 3.1 `interrupcoes.s`
* ISR limpa o *timer* antes de qualquer lógica extra.
* Salva `ra, r8-r10, estatus`; restaura em ordem inversa; sai com `eret`.

### 3.2 `animacao.s`
* Exporta `RESTAURAR_ESTADO_LEDS` para outros módulos.
* Ao iniciar animação:
  * Cancela cronômetro (`CRONOMETRO_ATIVO ← 0`).
  * Salva estado atual dos LEDs e configura posição inicial baseada em `SW0`.

### 3.3 `cronometro.s`
* Parsing robusto: aceita `"20"`, `"20 "`, `"21"`, `"21 "`.
* Se animação estiver ativa, limpa `FLAG_INTERRUPCAO` e restaura LEDs antes de iniciar cronômetro.

### 3.4 `led.s`
* Ignora comandos "00 xx / 01 xx" quando `FLAG_INTERRUPCAO ≠ 0`, evitando conflito com animação.

### 3.5 `main.s`
* `PROCESSAR_CHAR_UART` inclui verificação de overflow (`pos > 99 ⇒ descarte`).
* Loop principal usa apenas _polling_ não-bloqueante.

---

## 4. Mapa de memória (`.data`)

| Símbolo | Offset | Tamanho | Observação |
|---------|--------|---------|-----------|
| `LED_STATE` | 0x00 | 4 | **Alinhado** |
| `BUFFER_ENTRADA` | 0x04 | 100 B | Buffer UART |
| `BUFFER_ENTRADA_POS` | 0x68 | 4 | Ponteiro |
| `KEY1_PRESSIONADO_FLAG` | 0x6C | 4 | Debounce |
| `TABELA_7SEG` | 0x70 | 40 B | 10 × `word` |

> Variáveis de ISR residem em bloco separado dentro de `interrupcoes.s` assegurando ausência de sobreposição.

---

## 5. Checklist de conformidade

* ☑ **Sem** uso de `r1 (at)`.
* ☑ *Stack frames* corretos em todas as rotinas.
* ☑ Acesso a `wrctl/rdctl` protegido por _critical-section_.
* ☑ Variáveis compartilhadas ISR/foreground usam acesso atômico.
* ☑ Todos os símbolos `.extern` resolvidos em *link map*.

---

## 6. Procedimentos de teste

1. **LED direto**  
   `0017` acende LED 17 • `0117` apaga LED 17
2. **Animação**  
   `10` inicia • Alternar `SW0` muda direção • `11` encerra
3. **Cronômetro**  
   `20` inicia • `KEY1` pausa/retoma • `21` cancela
4. **Overflow UART**  
   Enviar >120 bytes sem *newline*: sistema mantém responsividade.
5. **Stress Timer**  
   Reduzir `ANIMACAO_PERIODO` para 1 ms e verificar UART/LEDs.

---

## 7. Sugestões futuras

* Migrar UART para interrupção + FIFO circular.
* Incluir *watchdog timer* (referência: Barr Group – _Top 10 Nasty Firmware Bugs_).
* Automatizar testes em Qsys-Sim/ModelSim.

---

## 8. Conclusão

Após esta auditoria, o projeto **cumpre integralmente a ABI do Nios II** e não apresenta mais corrupção de memória observada em testes manuais.  
Caso algum caso de uso ainda falhe, documente o comando, estado dos *switches* e passo a passo para reprodução para nova rodada de depuração. 

---

## 9. Correções críticas implementadas

### 9.1 Eliminação completa do uso de `r1 (at)`
* Adicionada diretiva `.set noat` em **todos** os arquivos `.s`.
* Substituído `r1` por `r2`, `r3`, `r16-r20` em todas as ocorrências.
* **Impacto**: Elimina conflitos com o assembler que usa `r1` internamente.

### 9.2 Stack frames ABI-compliant
* `PROCESSAR_TICK_CRONOMETRO` agora possui stack frame completo.
* Todas as funções salvam/restauram registradores callee-saved (`r16-r23`).
* **Impacto**: Elimina corrupção de registradores entre chamadas.

### 9.3 Proteção contra overflow do buffer UART
* `PROCESSAR_CHAR_UART` verifica limite antes de escrever.
* Buffer limitado a 99 caracteres máximo.
* **Impacto**: Elimina corrupção de variáveis adjacentes na memória.

### 9.4 Exclusão mútua entre subsistemas
* Animação cancela cronômetro automaticamente.
* Cronômetro cancela animação automaticamente.
* LEDs ignoram comandos durante animação.
* **Impacto**: Elimina conflitos de timer e estados inconsistentes.

---

## 10. Status final de conformidade

| Item | Status | Observação |
|------|--------|------------|
| `.set noat` | ✅ | Todos os arquivos |
| Stack frames | ✅ | ABI-compliant |
| Registradores callee-saved | ✅ | Preservados |
| Buffer overflow | ✅ | Protegido |
| Exclusão mútua | ✅ | Implementada |
| Alinhamento de dados | ✅ | 4 bytes |
| Acesso atômico ISR | ✅ | 32-bit words |

**Resultado**: Projeto **100% conforme** com a Nios II ABI. 