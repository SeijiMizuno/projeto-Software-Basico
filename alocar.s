.section .data
    INICIO_HEAP: .quad 0
    TOPO_HEAP: .quad 0

    # strings de impressão
    MSG_IMAGEM_HEAP:            .ascii "Imagem da heap: "
    .equ MSG_IMAGEM_HEAP_LEN, . - MSG_IMAGEM_HEAP           # Comprimento da string

    CHAR_OCUPADO:       .ascii "+"
    CHAR_LIVRE:         .ascii "-"
    CHAR_NODEMANAGER:   .ascii "#"

    CHAR_NEWLINE:       .byte 10        # em ASCII, byte 10 = '/n'

    A:          .quad 0
    B:          .quad 0
    C:          .quad 0

    TAMANHO:    .quad 0                 # variável global que armazena o tamanho do bloco a ser alocado

.section .text

# ==========================================================================
# Função iniciaAlocador ====================================================
# Inicia os valores de início e topo da Heap
.globl  iniciaAlocador
.type   iniciaAlocador,@function
iniciaAlocador:
    movq     $0, %rdi            # coloca 0 em rdi
    movq     $12, %rax           # numero do syscall = 12 em rax
    syscall                      # salta para o kernel, que retorna em rax o endereço atual do "break" do heap
    movq     %rax, INICIO_HEAP(%rip)  # inicio da lista
    movq     %rax, TOPO_HEAP(%rip)    # fim atual do heap
    ret                         # preserva rax e limpa o frame

# ==========================================================================
# Procedimento imprimeMapa =================================================
# Imprime a região da heap (e.g.: 4 bytes ocupados -> ################++++)
imprimeMapa:
    # === escreve "Imagem da heap: " ===
    movq $1, %rax           # syscall write
    movq $1, %rdi           # stdout
    movq $MSG_IMAGEM_HEAP, %rsi
    movq $MSG_IMAGEM_HEAP_LEN, %rdx
    syscall

    movq INICIO_HEAP(%rip), %rbx   # move o endereço de INICIO_HEAP para %rbx
.whileImprime:
    cmpq TOPO_HEAP(%rip), %rbx     # Compara endereço rbx (INICIO_HEAP) com rax TOPO_HEAP
    jge .endWhileImprime     # Se rbx >= TOPO_HEAP, então dá um jump para .endWhileImprime (chegou ao fim da Heap)

    movq $16, %r8          # armazena 16 no contador %r8
.imprimeNodeManager:         # impressão dos caracteres '#'
    cmpq $0, %r8
    je .fimImprimeNodeManager

    # printa um "#"
    movq $1, %rax           # syscall write
    movq $1, %rdi           # stdout
    movq $CHAR_NODEMANAGER, %rsi
    movq $1, %rdx
    syscall

    subq $1, %r8            # decrementa %r8
    jmp .imprimeNodeManager   # repete o loop

.fimImprimeNodeManager:
    # armazena o tamanho do nó em %r8
    movq 8(%rbx), %r8

    # decisão se irá imprimir '+' ou '-'
    cmpq $1, (%rbx)
    je .setOcupado
    # se chegou aqui, então o nó está livre (%rax = 0)
    movq $CHAR_LIVRE, %rsi
    jmp .whilePrintBloco
.setOcupado:
    movq $CHAR_OCUPADO, %rsi

.whilePrintBloco:
    cmpq $0, %r8
    je .nextWhilePrintBloco            # se r8 == 0, pula impressão

    movq $1, %rax
    movq $1, %rdi
    movq $1, %rdx
    syscall
    subq $1, %r8
    jmp .whilePrintBloco

.nextWhilePrintBloco:
    # Avança ponteiro: 16 (node_manager) + tamanho do bloco
    movq 8(%rbx), %r8
    addq $16, %r8
    addq %r8, %rbx
    jmp .whileImprime

.endWhileImprime:
    movq $1, %rax           # syscall write
    movq $1, %rdi           # stdout
    movq $CHAR_NEWLINE, %rsi
    movq $1, %rdx
    syscall
    ret

# ==========================================================================
# procuraLivre =============================================================
# Params: 16(%rbp) = tamanho do bloco a ser alocado ========================
procuraLivre:
    pushq %rbp
    movq %rsp, %rbp

    movq INICIO_HEAP(%rip), %rbx
    movq TOPO_HEAP(%rip), %r10

.whileProcura:
    cmpq %r10, %rbx
    jge .expandeHeap

    cmpq $1, (%rbx)           # checa se o nó está ocupado
    je .nextWhileProcura    # se sim, pula para o próximo nó

    # se chegou aqui é porque o nó é livre
    movq 8(%rbx), %rcx
    cmpq 16(%rbp), %rcx     # compara o tamanho desejado com o tamanho do nó
    jl .nextWhileProcura           # se for menor que o tamanho solicitado, pula para o próximo nó   

    # se chegou aqui é porque nó_size >= tamanho solicitado
    # colocando o endereço do nó livre encontrado em %rax

    addq $16, %rbx  # pula para o endereço do conteúdo do nó
    movq %rbx, %rax
    jmp .fimProcuraLivre    

.nextWhileProcura:
    # Avança ponteiro: 16 (node_manager) + tamanho do bloco
    movq 8(%rbx), %r13
    addq $16, %r13
    addq %r13, %rbx
    jmp .whileProcura

# "joga" %rbk mais para frente
.expandeHeap:
    movq 16(%rbp), %r9               # 16(%rbp) = tamanho pedido (sem node_manager)

    addq $16, %r9                # tamanho total com node_manager
    addq %r10, %r9             # novo topo desejado

    movq %r9, %rdi               # rdi = novo endereço para o brk
    movq $12, %rax                # syscall brk
    syscall

    # Verifica se brk falhou
    cmpq %rdi, %rax
    jne erroMemoria

    # Atualiza TOPO_HEAP
    movq %rax, TOPO_HEAP(%rip)

    # coloca o endereço do novo bloco em %rax para retorno da procedure
    addq $16, %r10          # %r10 ainda contém o valor antigo do topo da heap
    movq %r10, %rax     
    jmp .fimProcuraLivre

.fimProcuraLivre:
    # fim do procedimento
    popq %rbp
    ret


# ==========================================================================
# alocaMem ============================================================
# Params: 16(%rbp) = tamanho do nó a ser alocado ========================
alocaMem:
    pushq %rbp
    movq %rsp, %rbp

# TO DO =======================
# Proteger de tentativa de alocação de tamanho ZERO, abortar ou só devolver a pilha como está
# TO DO =======================

    movq 16(%rbp), %rax
    pushq %rax               # empilha param. tamanho_solicitado
    call procuraLivre
    addq $8, %rsp               # desempilha param. tamanho_solicitado

# TO DO =======================
# Processo agora é:
    # 1. checar se o tamanho solicitado vai deixar uma "sobra" de espaço livre
        # 1.1 se sim, checar se o espaço livre possui no mínimo 17 bytes [8][8][1]
            # 1.1.1 se sim, separa o nó em dois, a primeira parte será ocupada pelo tamanho solicitado
            # 1.1.2 se não, não faz nada e só ocupa todo o nó mesmo (não terá "sobra" suficiente para alocar um novo nó)
        # 1.2 se não, o tamanho é perfeito (tamanho solicitado == tamanho livre), alocação normal.  
# TO DO =======================

    # ponteiro inicial do nó alocado
    movq %rax, %rbx

    # marca como OCUPADO
    movq $1, -16(%rbx)

    # salva o TAMANHO do nó (sem os 16 bytes de node_manager)
    movq 16(%rbp), %r12
    movq %r12, -8(%rbx)

    # retorna ponteiro de dados (16 bytes depois do node_manager)
    movq %rbx, %rax
    jmp .fimAlocaMem

# fim do procedimento
.fimAlocaMem:
    popq %rbp
    ret

# ==========================================================================
# desalocaMem =============================================================
# Recebe um ponteiro de dados e marca o nó como livre
# Entrada: %rdi = ponteiro de dados (retornado por alocaMem)
desalocaMem:
    subq $16, %rdi         # volta 16 bytes para acessar o início do nó (node_manager)
    movq $0, (%rdi)        # marca como livre (0)
    ret

# ==========================================================================
# Main =====================================================================
.globl  _start
_start:
    call iniciaAlocador
    call imprimeMapa              # imprime estado inicial da heap (vazia)
    # Saída esperada:
    # Imagem da heap: 

    # Aloca 8 e armazena em 'A'
    movq $8, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, A
    call imprimeMapa              # após alocar A
    # Saída esperada:
    # Imagem da heap: ################++++++++

    # Aloca 3 e armazena em 'B'
    movq $3, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, B
    call imprimeMapa              # após alocar B
    # Saída esperada:
    # Imagem da heap: ################++++++++################+++

    # desaloca o ponteiro 'A'
    movq A, %rdi
    call desalocaMem
    call imprimeMapa              # após desalocar A
    # Saída esperada:
    # Imagem da heap: ################--------################+++

    # Aloca 10 e armazena em 'C'
    movq $10, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, C
    call imprimeMapa              # após alocar C
    # Saída esperada:
    # Imagem da heap: ################--------################+++################++++++++++

    # desaloca o ponteiro 'B'
    movq B, %rdi
    call desalocaMem
    call imprimeMapa              # após desalocar B
    # Saída esperada:
    # Imagem da heap: ################--------################---################++++++++++

    # desaloca o ponteiro 'C'
    movq C, %rdi
    call desalocaMem
    call imprimeMapa              # após desalocar C
    # Saída esperada:
    # Imagem da heap: ################--------################---################----------

    # Aloca 8 e armazena em 'A'
    movq $8, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, A
    call imprimeMapa              # após alocar A
    # Saída esperada:
    # Imagem da heap: ################++++++++################---################----------

    # Aloca 10 e armazena em 'C'
    movq $10, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, C
    call imprimeMapa              # após alocar C
    # Saída esperada:
    # Imagem da heap: ################++++++++################---################++++++++++

    # Aloca 3 e armazena em 'B'
    movq $3, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, B
    call imprimeMapa              # após alocar B
    # Saída esperada:
    # Imagem da heap: ################++++++++################+++################++++++++++

    # exit(0)
    movq $0, %rdi
    movq $60, %rax
    syscall

erroMemoria:
    # exit(1) ERRO em expandir %brk
    movq $1, %rdi
    movq $60, %rax
    syscall
