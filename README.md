# Projeto de Microprocessadores - Cronograma 3 Semanas
## Placa FPGA DE2-115 - 1º Semestre 2025

---

## **📅 CRONOGRAMA DE 3 SEMANAS**

### **SEMANA 1: Configuração e Funcionalidades Básicas**
**Setup e UART**
- Configuração do ambiente (Quartus II, Altera Monitor)
- Implementação básica da comunicação UART
- Teste de recepção de comandos
- Interface console ("Entre com o comando:")

**Controle de LEDs**
- Comandos 00 xx (acender LED) e 01 xx (apagar LED)
- Mapeamento dos registradores dos LEDs vermelhos
- Validação básica de entrada

**Parser e Estrutura Base**
- Parser completo de comandos
- Estrutura principal do programa
- Testes dos comandos básicos de LED
- **Funcionando:** LEDs controlados via UART

### **SEMANA 2: Funcionalidades Avançadas**
**Sistema de Animação**
- Comando 10 (iniciar animação)
- Leitura da chave SW0
- Implementação da animação com timing de 200ms
- Comando 11 (parar animação)

**Cronômetro Base**
- Comando 20 (iniciar cronômetro)
- Configuração dos displays de 7 segmentos
- Contagem básica de segundos

**Cronômetro Completo**
- Integração com botão KEY1 (pause/resume)
- Comando 21 (cancelar cronômetro)
- **Funcionando:** Todas funcionalidades implementadas

### **SEMANA 3: Integração, Testes e Documentação**
**Integração e Testes**
- Integração de todos os módulos
- Testes de sistema completo
- Correção de bugs e otimizações

**Documentação**
- Comentários detalhados no código
- Estruturação final do código
- Início do relatório

**Finalização**
- Relatório final
- Testes finais
- **Entrega Final**

---

## **💻 PSEUDOCÓDIGO DO PROJETO**

### **Estrutura Principal**

```
PROGRAMA PRINCIPAL:
    INICIALIZAR_SISTEMA()
    MOSTRAR_PROMPT("Entre com o comando:")
    
    ENQUANTO (verdadeiro):
        comando = LER_COMANDO_UART()
        PROCESSAR_COMANDO(comando)
        SE (comando_valido):
            MOSTRAR_PROMPT("Entre com o comando:")
```

### **Inicialização do Sistema**

```
FUNÇÃO INICIALIZAR_SISTEMA():
    // Configurar UART
    UART_BASE = 0x10001000
    ESCREVER_REGISTRADOR(UART_BASE + CONTROLE, CONFIG_UART)
    
    // Configurar LEDs
    LED_BASE = 0x10000000
    ESCREVER_REGISTRADOR(LED_BASE, 0x00000000)  // Todos LEDs apagados
    
    // Configurar Displays 7-seg
    HEX_BASE = 0x10000020
    LIMPAR_DISPLAYS()
    
    // Inicializar variáveis globais
    estado_animacao = PARADO
    estado_cronometro = PARADO
    leds_salvos = 0x00000000
    cronometro_segundos = 0
    cronometro_pausado = FALSO
```

### **Processamento de Comandos**

```
FUNÇÃO PROCESSAR_COMANDO(comando):
    codigo = EXTRAIR_CODIGO(comando)
    parametro = EXTRAIR_PARAMETRO(comando)
    
    ESCOLHER (codigo):
        CASO 00:
            ACENDER_LED(parametro)
        CASO 01:
            APAGAR_LED(parametro)
        CASO 10:
            INICIAR_ANIMACAO()
        CASO 11:
            PARAR_ANIMACAO()
        CASO 20:
            INICIAR_CRONOMETRO()
        CASO 21:
            CANCELAR_CRONOMETRO()
        PADRÃO:
            ENVIAR_UART("Comando inválido")
```

### **Controle de LEDs**

```
FUNÇÃO ACENDER_LED(numero_led):
    SE (numero_led >= 0 E numero_led <= 17):
        SE (estado_animacao == PARADO):
            estado_atual = LER_REGISTRADOR(LED_BASE)
            novo_estado = estado_atual OU (1 << numero_led)
            ESCREVER_REGISTRADOR(LED_BASE, novo_estado)
        SENÃO:
            leds_salvos = leds_salvos OU (1 << numero_led)

FUNÇÃO APAGAR_LED(numero_led):
    SE (numero_led >= 0 E numero_led <= 17):
        SE (estado_animacao == PARADO):
            estado_atual = LER_REGISTRADOR(LED_BASE)
            novo_estado = estado_atual E NÃO(1 << numero_led)
            ESCREVER_REGISTRADOR(LED_BASE, novo_estado)
        SENÃO:
            leds_salvos = leds_salvos E NÃO(1 << numero_led)
```

### **Sistema de Animação**

```
FUNÇÃO INICIAR_ANIMACAO():
    SE (estado_animacao == PARADO):
        // Salvar estado atual dos LEDs
        leds_salvos = LER_REGISTRADOR(LED_BASE)
        ESCREVER_REGISTRADOR(LED_BASE, 0x00000000)  // Apagar todos
        
        estado_animacao = ATIVO
        posicao_atual = 0
        direcao = LER_CHAVE_SW0()
        CONFIGURAR_TIMER_ANIMACAO(200)  // 200ms
        
        // Acender primeiro LED
        SE (direcao == DIREITA_ESQUERDA):
            posicao_atual = 17
        SENÃO:
            posicao_atual = 0
        ESCREVER_REGISTRADOR(LED_BASE, 1 << posicao_atual)

FUNÇÃO PARAR_ANIMACAO():
    estado_animacao = PARADO
    PARAR_TIMER_ANIMACAO()
    // Restaurar LEDs salvos
    ESCREVER_REGISTRADOR(LED_BASE, leds_salvos)

FUNÇÃO ATUALIZAR_ANIMACAO():  // Chamada pelo timer a cada 200ms
    SE (estado_animacao == ATIVO):
        direcao = LER_CHAVE_SW0()
        
        SE (direcao == DIREITA_ESQUERDA):
            posicao_atual = posicao_atual - 1
            SE (posicao_atual < 0):
                posicao_atual = 17
        SENÃO:
            posicao_atual = posicao_atual + 1
            SE (posicao_atual > 17):
                posicao_atual = 0
        
        ESCREVER_REGISTRADOR(LED_BASE, 1 << posicao_atual)
```

### **Sistema de Cronômetro**

```
FUNÇÃO INICIAR_CRONOMETRO():
    SE (estado_cronometro != ATIVO):
        estado_cronometro = ATIVO
        cronometro_segundos = 0
        cronometro_pausado = FALSO
        CONFIGURAR_TIMER_CRONOMETRO(1000)  // 1 segundo
        ATUALIZAR_DISPLAY_CRONOMETRO()

FUNÇÃO CANCELAR_CRONOMETRO():
    estado_cronometro = PARADO
    PARAR_TIMER_CRONOMETRO()
    cronometro_segundos = 0
    LIMPAR_DISPLAYS()

FUNÇÃO ATUALIZAR_CRONOMETRO():  // Chamada pelo timer a cada 1s
    SE (estado_cronometro == ATIVO E NÃO cronometro_pausado):
        cronometro_segundos = cronometro_segundos + 1
        SE (cronometro_segundos > 5999):  // 99:59 máximo
            cronometro_segundos = 0
        ATUALIZAR_DISPLAY_CRONOMETRO()

FUNÇÃO PAUSAR_RESUMIR_CRONOMETRO():  // Chamada pela interrupção do KEY1
    SE (estado_cronometro == ATIVO):
        cronometro_pausado = NÃO cronometro_pausado

FUNÇÃO ATUALIZAR_DISPLAY_CRONOMETRO():
    minutos = cronometro_segundos / 60
    segundos = cronometro_segundos % 60
    
    dig3 = minutos / 10      // Dezenas de minutos
    dig2 = minutos % 10      // Unidades de minutos
    dig1 = segundos / 10     // Dezenas de segundos
    dig0 = segundos % 10     // Unidades de segundos
    
    ESCREVER_DISPLAY(HEX3, CODIFICAR_7SEG(dig3))
    ESCREVER_DISPLAY(HEX2, CODIFICAR_7SEG(dig2))
    ESCREVER_DISPLAY(HEX1, CODIFICAR_7SEG(dig1))
    ESCREVER_DISPLAY(HEX0, CODIFICAR_7SEG(dig0))
```

### **Funções de Suporte**

```
FUNÇÃO LER_COMANDO_UART():
    comando = ""
    ENQUANTO (verdadeiro):
        SE (UART_TEM_DADOS()):
            char = LER_UART()
            SE (char == '\n' OU char == '\r'):
                RETORNAR CONVERTER_PARA_INTEIROS(comando)
            SENÃO:
                comando = comando + char

FUNÇÃO EXTRAIR_CODIGO(comando):
    RETORNAR comando / 100

FUNÇÃO EXTRAIR_PARAMETRO(comando):
    RETORNAR comando % 100

FUNÇÃO CODIFICAR_7SEG(digito):
    tabela_7seg = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 
                   0x6D, 0x7D, 0x07, 0x7F, 0x6F]
    SE (digito >= 0 E digito <= 9):
        RETORNAR tabela_7seg[digito]
    SENÃO:
        RETORNAR 0x00  // Display apagado

FUNÇÃO LER_CHAVE_SW0():
    valor_chaves = LER_REGISTRADOR(SWITCH_BASE)
    RETORNAR (valor_chaves E 0x01)
```

### **Tratamento de Interrupções**

```
ROTINA_INTERRUPCAO():
    fonte = IDENTIFICAR_FONTE_INTERRUPCAO()
    
    ESCOLHER (fonte):
        CASO TIMER_ANIMACAO:
            ATUALIZAR_ANIMACAO()
        CASO TIMER_CRONOMETRO:
            ATUALIZAR_CRONOMETRO()
        CASO KEY1:
            PAUSAR_RESUMIR_CRONOMETRO()
    
    LIMPAR_INTERRUPCAO(fonte)
```

---

## **🎯 PONTOS CRÍTICOS PARA IMPLEMENTAÇÃO**

### **Decisões de Design:**
1. **Conflito LED + Animação:** Salvar estado dos LEDs antes da animação e restaurar após
2. **Simultaneidade:** Cronômetro e animação podem funcionar simultaneamente
3. **Validação:** Comandos inválidos retornam mensagem de erro
4. **Limites:** LEDs 0-17, cronômetro até 99:59

### **Registradores Importantes (DE2-115):**
- **LEDs:** 0x10000000
- **Displays 7-seg:** 0x10000020 (HEX3-0)
- **Chaves:** 0x10000040
- **Botões:** 0x10000050
- **UART:** 0x10001000

### **Prioridades por Semana:**
- **Semana 1:** Funcionalidade básica funcionando
- **Semana 2:** Todas as features implementadas
- **Semana 3:** Sistema robusto e bem documentado