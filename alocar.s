.section .data
    inicioHeap: .quad 0
    topoHeap: .quad 0

    # strings de impressão
    msgHeap:            .ascii "Imagem da heap: "
    .equ msgHeap_len, . - msgHeap           # equivalente ao comprimento da string

    charOcupado:        .ascii "+"
    charLivre:          .ascii "-"
    charNodeManager:    .ascii "#"

    newline:            .byte 10        # em ASCII, byte 10 = '/n'

    a:          .quad 0                 # ponteiro para bloco alocado de 10 bytes
    b:          .quad 0                 # ponteiro para bloco alocado de 4 bytes

.section .text

# ==========================================================================
# Função iniciaAlocador ====================================================
# Inicia os valores de início e topo da Heap
.globl  iniciaAlocador
.type   iniciaAlocador,@function
iniciaAlocador:
    mov     $0, %rdi            # coloca 0 em rdi
    mov     $12, %rax           # numero do syscall = 12 em rax
    syscall                     # salta para o kernel, que retorna em rax o endereço atual do "break" do heap
    mov     %rax, inicioHeap(%rip)  # inicio da lista
    mov     %rax, topoHeap(%rip)    # fim atual do heap
    ret                         # preserva rax e limpa o frame

# ==========================================================================
# Procedimento imprimeMapa =================================================
# Imprime a região da heap (e.g.: 4 bytes ocupados -> ################++++)
imprimeMapa:
    movq $0, %rdi   # coloca 0 em rdi para retornar o valor de brk (se não for zero, brk recebe o valor de rdi)
    movq $12, %rax  # 12 em rax = syscall altera valor rbk (rdi é 0, então ao invés de alterar, syscall apenas retorna rbk)
    syscall         # endereço de rbk é retornado em %rax
    movq %rax, topoHeap
    movq inicioHeap, %rbx   # move o endereço de inicioHeap para %rbx
    
    # === escreve "Imagem da heap: " ===
    movq $1, %rax           # syscall write
    movq $1, %rdi           # stdout
    movq $msgHeap, %rsi
    movq $msgHeap_len, %rdx
    syscall
    
whileImprime:
    cmpq topoHeap, %rbx     # Compara endereço rbx (inicioHeap) com topoHeap
    jge endWhileImprime     # Se rbx for maior que topoHeap, então dá um jump para endWhileImprime (chegou ao fim da Heap)

    movq $16, %r8          # armazena 16 no contador %r8
imprimeNodeManager:         # impressão dos caracteres '#'
    cmpq $0, %r8
    jl fimImprimeNodeManager

    movq $1, %rax           # syscall write
    movq $1, %rdi           # stdout
    movq $charNodeManager, %rsi
    movq $1, %rdx
    syscall
    subq $1, %r8            # decrementa rcx
    jmp imprimeNodeManager   # repete o loop

fimImprimeNodeManager:

    # checando se o nó está ocupado ou livre
    movq (%rbx), %rax

    # armazena o tamanho do nó em %r8
    movq 8(%rbx), %r8

    # decisão se irá imprimir '+' ou '-'
    cmpq $1, %rax
    je setOcupado
    # se chegou aqui, então o nó está livre (%rax = 0)
    movq $charLivre, %rsi
    jmp whilePrintBloco
setOcupado:
    movq $charOcupado, %rsi

whilePrintBloco:
    cmpq $0, %r8
    jle nextBloco            # se r8 == 0, pula impressão

    movq $1, %rax
    movq $1, %rdi
    movq $1, %rdx
    syscall
    subq $1, %r8
    jmp whilePrintBloco

nextBloco:
    # Avança ponteiro: 16 (controle) + tamanho do bloco
    movq 8(%rbx), %r8
    addq $16, %r8
    addq %r8, %rbx

    jmp whileImprime

endWhileImprime:
    movq $1, %rax           # syscall write
    movq $1, %rdi           # stdout
    movq $newline, %rsi
    movq $1, %rdx
    syscall
    ret


# ==========================================================================
# Main =====================================================================
.globl  main
.type   main,@function
main:


    # exit(0)
    mov     $60, %rax
    mov     $0, %rdi
    syscall
