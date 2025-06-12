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

    # Define esse novo nó como livre
    movq $1, (%r10)

    # Define o tamanho desse novo nó criado com o tamanho solicitado
    movq %r9, 8(%r10)

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

    # checa se tam solicitado é 0
    movq 16(%rbp), %rax
    cmpq $0, %rax
    je .erroTamanhoZero     # se tam = 0, vai para o tratamento do erro

    # se chegou aqui, tamanho é diferente de 0
    # procura blocos livres adequados
    pushq %rax               # empilha param. tamanho_solicitado
    call procuraLivre
    addq $8, %rsp               # desempilha param. da pilha

    # ponteiro ao payload do bloco livre
    movq %rax, %rbx
    # Definindo nó como ocupado
    movq $1, -16(%rbx)      # flag = 1


    movq -8(%rbx), %r14     # tamanho bloco livre
    movq 16(%rbp), %r12     # tamanho solicitado 

    # calcula sobra apos alocar
    movq %r14, %r15     # r15 = size do bloco livre
    subq %r12, %r15     # sobra = size livre - solicitado

    ########## Logica Split ###########
    # se sobra >= 17 faz Split
    cmpq $17, %r15
    jl .fimAlocaMem # não há espaço para split do bloco livre, então não há alteração no tamanho do bloco
    # se chegou aqui, precisa fazer split
    
    movq %r12, -8(%rbx)     # tamanho solicitado
    # split
    addq %r12, %rbx         # rbx já está no endereço da flag de ocupado do novo nó resultante do split
    movq $0, (%rbx)         # define nó como livre (flag 0)
    subq $16, %r15          # calcula novo tamanho do nó resultante do split: novo_tam = sobra - 16
    movq %r15, 8(%rbx)      # define o tamanho do nó resultante do split

    ##### finalizar a alocação
    jmp .fimAlocaMem

# se tentar alocar 0 bytes retorna ponteiro NULL, igual em c
.erroTamanhoZero:
    movq $0, %rax
    jmp .fimAlocaMem

# fim do procedimento
.fimAlocaMem:
    popq %rbp
    ret

# ==========================================================================
# desalocaMem =============================================================
# Recebe um ponteiro de dados e marca o nó como livre
# Entrada: 16(%rbp) = ponteiro de dados do nó a ser desalocado
desalocaMem:
    pushq %rbp
    movq %rsp, %rbp

    movq TOPO_HEAP(%rip), %r10
    movq 16(%rbp), %r8  # armazena o endereço do ponteiro a ser desalocado
    movq $0, -16(%r8)   # define o nó como livre

    movq -8(%r8), %r9   # armazena em r9 o tamanho do nó a ser desalocado

    # checa se o próximo endereço também é livre para fusão
    movq %r8, %rax
    addq %r9, %rax      # rax agora possui o primeiro endereço do próximo nó
    addq $16, %rax      # agora rax possui o primeiro endereço do bloco de dados do próximo nó

    cmpq %r10, %rax
    jge .fimDesalocaMem # checa se o próximo nó, na verdade é o topo da Heap
    # se chegou aqui, esse não é o último nó da heap

    cmpq $0, -16(%rax)     # checa se o próximo nó é livre
    je .fusaoLivres
    # se chegou aqui, então o próximo nó está ocupado, então não há fusão

    jmp .fimDesalocaMem

.fusaoLivres:
    # r9 possui o tamanho do nó atual
    movq -8(%r8), %r9       # soma o tamanho do próximo nó ao tamanho do nó atual (armazenado em r9) 
    addq -8(%rax), %r9       # soma o tamanho do próximo nó ao tamanho do nó atual (armazenado em r9) 
    addq $16, %r9           # soma 16 bytes (tamanho do gerenciamento) à soma dos tamanhos dos nós livres (armazenado em r9)

    movq %r9, -8(%r8)      # armazena a soma dos tamanhos no espaço de tamanho do nó atual

.fimDesalocaMem:
    popq %rbp
    ret

# ==========================================================================
# Main =====================================================================
.globl  _start
_start:
    call iniciaAlocador
    call imprimeMapa              # imprime estado inicial da heap (vazia)
    # Saída esperada:
    # Imagem da heap: 

    # Aloca 30 e armazena em 'A'
    movq $30, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, A
    call imprimeMapa              # após alocar A
    # Saída esperada:
    # Imagem da heap: ################++++++++

    # Aloca 30 e armazena em 'B'
    movq $10, TAMANHO
    pushq TAMANHO
    call alocaMem
    addq $8, %rsp

    movq %rax, B
    call imprimeMapa              # após alocar A
    # Saída esperada:
    # Imagem da heap: ################++++++++

    # desaloca o ponteiro 'A'
    pushq B
    call desalocaMem
    addq $8, %rsp

    call imprimeMapa              # após desalocar A
    # Saída esperada:
    # Imagem da heap: ################--------################+++

    # desaloca o ponteiro 'A'
    pushq A
    call desalocaMem
    addq $8, %rsp

    call imprimeMapa              # após desalocar A
    # Saída esperada:
    # Imagem da heap: ################--------################+++

    # exit(0)
    movq $0, %rdi
    movq $60, %rax
    syscall

erroMemoria:
    # exit(1) ERRO em expandir %brk
    movq $1, %rdi
    movq $60, %rax
    syscall
