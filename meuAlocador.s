.section .data
    INICIO_HEAP: .quad 0
    TOPO_HEAP: .quad 0
    INICIO_OCUPADOS: .quad 0
    INICIO_LIVRES: .quad 0

    # strings de impressão
    MSG_IMAGEM_HEAP:            .ascii "Imagem da heap: "
    .equ MSG_IMAGEM_HEAP_LEN, . - MSG_IMAGEM_HEAP           # Comprimento da string

    CHAR_OCUPADO:       .ascii "+"
    CHAR_LIVRE:         .ascii "-"
    CHAR_NODEMANAGER:   .ascii "#"

    CHAR_NEWLINE:       .byte 10        # em ASCII, byte 10 = '/n'

    TAMANHO:    .quad 0                 # variável global que armazena o tamanho do bloco a ser alocado
    
.section .text
    .global iniciaAlocador
    .global finalizaAlocador
    .global alocaMem
    .global liberaMem
    .global imprimeMapa

# ==========================================================================
# Função iniciaAlocador ====================================================
# Inicia os valores de início e topo da Heap
iniciaAlocador:
    pushq %rbp
    movq %rsp, %rbp

    movq     $0, %rdi            # coloca 0 em rdi
    movq     $12, %rax           # numero do syscall = 12 em rax
    syscall                      # salta para o kernel, que retorna em rax o endereço atual do "break" do heap
    movq     %rax, INICIO_HEAP(%rip)  # inicio da lista
    movq     %rax, TOPO_HEAP(%rip)    # fim atual do heap

    popq %rbp
    ret

# void finalizaAlocador()
finalizaAlocador:
    pushq %rbp
    movq %rsp, %rbp

    # syscall brk(topoInicialHeap)
    movq $12, %rax       # syscall brk
    movq INICIO_HEAP(%rip), %rdi
    syscall

    popq %rbp
    ret
# ==========================================================================
# Procedimento imprimeMapa =================================================
# Imprime a região da heap (e.g.: 4 bytes ocupados -> ################++++)
imprimeMapa:
    movq INICIO_HEAP(%rip), %rbx   # move o endereço de INICIO_HEAP para %rbx
.whileImprime:
    cmpq TOPO_HEAP(%rip), %rbx     # Compara endereço rbx (INICIO_HEAP) com rax TOPO_HEAP
    jge .endWhileImprime     # Se rbx >= TOPO_HEAP, então dá um jump para .endWhileImprime (chegou ao fim da Heap)

    movq $32, %r8          # armazena 16 no contador %r8
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
    addq $32, %r8
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

    movq TOPO_HEAP(%rip), %r10
    movq INICIO_LIVRES(%rip), %rbx          # rbx agora aponta para o conteúdo do primeiro nó livre

.whileProcura:
    # checa se a lista de livres é vazia
    cmpq $0, %rbx
    je .expandeHeapProcura
    cmpq %r10, %rbx
    jge .expandeHeapProcura

    # se chegou aqui é porque há um INICIO_LIVRES e ainda estamos localizados antes de %brk
    movq -24(%rbx), %rcx    # armazena o tamanho do nó atual
    cmpq 16(%rbp), %rcx     # compara o tamanho desejado com o tamanho do nó atual
    jl .nextWhileProcura           # se o tamanho do nó atual for menor que o tamanho solicitado, pula para o próximo nó   

    # se chegou aqui é porque nó_size >= tamanho solicitado
    # colocando o endereço do nó livre encontrado em %rax

    movq %rbx, %rax
    jmp .fimProcuraLivre    

.nextWhileProcura:
    # Faz %rbx apontar para o próximo nó da lista de nós livres
    movq -8(%rbx), %r13
    movq %r13, %rbx
    jmp .whileProcura

# "joga" %rbk mais para frente
.expandeHeapProcura:
    movq 16(%rbp), %r11               # 16(%rbp) = tamanho pedido (sem node_manager)

    addq $32, %r11                # tamanho total com node_manager (tamanho solicitado + 32 bytes)
    addq %r10, %r11                  # novo topo desejado

    movq %r11, %rdi               # rdi = novo endereço para o brk
    movq $12, %rax                # syscall brk
    syscall

    # Atualiza TOPO_HEAP
    movq %rax, TOPO_HEAP(%rip)

    # Define esse novo nó como livre
    movq $0, (%r10)

    # Armazena novamente o tamanho solicitado em r11
    movq 16(%rbp), %r11

    # Define o tamanho desse novo nó criado com o tamanho solicitado
    movq %r11, 8(%r10)

    # Define INICIO_OCUPADOS
    cmpq $0, INICIO_OCUPADOS(%rip)        # checa se esse é o primeiro nó a ser ocupado
    jne .fimExpandeHeap
    # Se chegou aqui, significa que esse é o primeiro nó a ser ocupado
    movq %r10, %r12
    addq $32, %r12
    movq %r12, INICIO_OCUPADOS(%rip)

# coloca o endereço do novo bloco em %rax para retorno da procedure
.fimExpandeHeap:
    addq $32, %r10          # %r10 ainda contém o valor antigo do topo da heap
    movq %r10, %rax     
    jmp .fimProcuraLivre

.fimProcuraLivre:
    # fim do procedimento
    popq %rbp
    ret


# ==========================================================================
# alocaMem ============================================================
# Params: %rdi = tamanho do nó a ser alocado ========================
alocaMem:
    # Registro de Ativação
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %rax     # Armazena o tamanho solicitado em %rax

    # checa se tam solicitado é 0
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
    movq $1, -32(%rbx)      # flag = 1

    movq -24(%rbx), %r14        # tamanho bloco livre
    movq %rdi, %r12         # tamanho solicitado 

    # calcula sobra apos alocar
    movq %r14, %r15     # r15 = size do bloco livre
    subq %r12, %r15     # sobra = size livre - solicitado

    ########## Logica Split ###########
    # se sobra >= 33 faz Split
    cmpq $33, %r15
    jl .retirarListaLivre # não há espaço para split do bloco livre, então não há alteração no tamanho do bloco
    # se chegou aqui, precisa fazer split
    
    movq %r12, -24(%rbx)     # tamanho solicitado
    # split #### consertar split, para remanejar os ponteiros
    addq %r12, %rbx         # Move rbx para o primeiro endereço do nó de sobra (endereço de flag de ocupado)
    movq $0, (%rbx)         # define nó como livre (flag 0)
    subq $32, %r15          # calcula novo tamanho do nó resultante do split: novo_tam = sobra - 32
    movq %r15, 8(%rbx)      # define o tamanho do nó resultante do split


    ##### retirar o nó livre encontrado da lista de nós livres
.retirarListaLivre:
    movq %rax, %rbx         # redefine %rbx como sendo o nó livre retornado pelo procuraLivre
    movq INICIO_LIVRES(%rip), %r13
    cmpq $0, %r13           # Checa se ainda não há livres na lista de livres
    je .adicionarListaOcupado
    # Se chegou aqui, é porque há nós na lista de livres
.whileRetirarListaLivre:
    cmpq %rbx, %r13         # Checa se o nó atual é o mesmo da lista de livres
    jne .nextWhileRetirarListaLivre
    # Se chegou aqui, então é porque r13 possui o mesmo endereço que está em rbx
    cmpq $0, -8(%r13)       # Checa se esse é o último nó da lista de livres
    je .lastNodo
    # Se chegou aqui, é porque esse não é o último nó
    cmpq $0, -16(%r13)      # Checa se esse é o primeiro nó da lista de livres
    je .firstNodo
    # Se chegou aqui, é porque não é nem primeiro e nem último
    jmp .middleNodo

.lastNodo:
    cmpq $0, -16(%r13)      # Checa se além do último nodo, esse também é o último (lista com um único nó livre)
    je .singleNodo
    # Se chegou aqui, é porque é só lastNodo mesmo
    movq -16(%r13), %r14    # Armazena o prev_nodo de %r13 em %r14
    movq $0, -8(%r14)       # Define o prox_nodo de %r14 como 0
    movq $0, -16(%r13)      # Define o prev_nodo de %r13 como 0
    jmp .adicionarListaOcupado

.firstNodo:
    movq -8(%r13), %r14     # Armazena o next_nodo de %r13 em %r14
    movq $0, -16(%r14)      # Define o prev_nodo de %r14 como 0
    movq $0, -8(%r13)       # Define o next_nodo de %r13 como 0
    movq %r14, INICIO_LIVRES(%rip)
    jmp .adicionarListaOcupado

.middleNodo:
    movq -8(%r13), %r14     # Armazena o next_nodo de %r13 em %r14
    movq -16(%r13), %r15    # Armazena o prev_nodo de %r13 em %r15
    movq %r15, -8(%r14)     # Define o next_nodo de %r14 como %r15
    movq %r14, -16(%r15)    # Define o prev_nodo de %r15 como %r14
    jmp .adicionarListaOcupado

.singleNodo:
    movq $0, INICIO_LIVRES(%rip)    # Define o INICIO_LIVRES como 0 (lista vazia)
    jmp .adicionarListaOcupado

.nextWhileRetirarListaLivre:
    movq -8(%r13), %r13
    jmp .whileRetirarListaLivre

    ##### adicionar o nó livre encontrado à lista de nós ocupados
.adicionarListaOcupado:
    movq INICIO_OCUPADOS(%rip), %r13
.whileListaOcupado:
    cmpq $0, -8(%r13)       # Checa se o endereço armazenado em next_nodo é 0
    jne .nextWhileListaOcupado
    # Se chegou aqui, então é porque esse é o último nó da lista de ocupados
    movq %r13, -16(%rbx)    # Armazena o endereço de r13 (último da lista) em prev_nodo
    movq %rbx, -8(%r13)     # Define o next_nodo de r13 para rbx
    movq $0, -8(%rbx)       # Armazena 0 em next_nodo
    jmp .fimAlocaMem
.nextWhileListaOcupado:
    movq -8(%r13), %r13
    jmp .whileListaOcupado

# se tentar alocar 0 bytes retorna ponteiro NULL, igual em c
.erroTamanhoZero:
    movq $0, %rax
    jmp .fimAlocaMem

# fim do procedimento
.fimAlocaMem:
    popq %rbp
    ret

# =========================================================================
# liberaMem =============================================================
# Recebe um ponteiro de dados e marca o nó como livre
# Entrada: %rdi = ponteiro de dados do nó a ser desalocado
liberaMem:
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %r8  # armazena o endereço do ponteiro a ser desalocado
    movq $0, -32(%r8)   # define o nó como livre

    movq -24(%r8), %rbx   # armazena em r9 o tamanho do nó a ser desalocado

    # retira nó ocupado da lista de ocupado
    cmpq $0, -16(%r8)
    je .primeiroLista
    
    cmpq $0, -8(%r8)
    je .ultimoLista

    jmp .meioLista

.primeiroLista:
    cmpq $0, -8(%r8)
    je .unicoLista
    movq -8(%r8), %r9
    movq $0, -16(%r9)
    movq $0, -8(%r8)
    movq %r9, INICIO_OCUPADOS(%rip)
    jmp .adicionaListaLivre

.ultimoLista:
    movq -16(%r8), %r9
    movq $0, -8(%r9)
    movq $0, -16(%r8)
    jmp .adicionaListaLivre

.meioLista:
    movq -16(%r8), %r9
    movq -8(%r8), %r10
    movq %r9, -16(%r10)
    movq %r10, -8(%r9)
    movq $0, -16(%r8)
    movq $0, -8(%r8)
    jmp .adicionaListaLivre

.unicoLista:
    movq $0, INICIO_OCUPADOS(%rip)

.adicionaListaLivre:
    cmpq $0, INICIO_LIVRES(%rip)
    je .adicionaPrimeiroLivre
    movq INICIO_LIVRES(%rip), %r11
.whilePercorreListaLivre:
    cmpq $0, -8(%r11)
    jne .nextNodoLivre
    # se chegou aqui, %r11 é o último nó da lista livre
    # Remanejar ponteiros
    movq %r11, -16(%r8)
    movq %r8, -8(%r11)
    jmp .fimLiberaMem

.nextNodoLivre:
    movq -8(%r11), %r11
    jmp .whilePercorreListaLivre

.adicionaPrimeiroLivre:
    movq %r8, INICIO_LIVRES(%rip)
    jmp .fimLiberaMem

.fimLiberaMem:
    popq %rbp
    ret