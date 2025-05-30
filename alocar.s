    .section .text
    .globl  iniciaAlocador
    .type   iniciaAlocador,@function
iniciaAlocador:
    mov     $0, %rdi            # coloca 0 em rdi
    mov     $12, %rax           # numero do syscall = 12 em rax
    syscall                     # salta para o kernel, que retorna em rax o endereço atual do "break" do heap
    mov     %rax, topoInicialHeap(%rip) # inicio da lista
    mov     %rax, topoHeap(%rip)        # fim atual do heap
    ret                         # preserva rax e limpa o frame

    .globl  main
    .type   main,@function
main:
    call    iniciaAlocador

    mov     topoInicialHeap(%rip), %rax
    mov     topoHeap       (%rip), %rbx
    cmp     %rax, %rbx      # subtrai rax e rbx
    je      .Lok            # se rax e rbx forem iguais pula pra .Lok

    # falha
    lea     falha_msg(%rip), %rsi   # apota para mensagem de falha
    mov     $falha_len,     %rdx   # rdx = comprimento
    jmp     .Lwrite

.Lok:
    # certo
    lea     certo_msg(%rip),   %rsi   # apota para mensagem de acerto
    mov     $certo_len,       %rdx   # rdx = comprimento

.Lwrite:
    mov     $1, %rax        # 1 para write
    mov     $1, %rdi        # carrega o primeiro argumento do syscall = 1
    syscall

    # exit(0)
    mov     $60, %rax       # 60 para saida do syscall
    mov     $0, %rdi        # coloca 0 para definir corretamente o parametro de entrada do syscall
    syscall

    # declara duas variaveis 8-byte inicializadas a zero
    .section .data
    .align 8
topoInicialHeap:
    .quad 0
topoHeap:
    .quad 0

certo_msg:
    .ascii "certo\n"
certo_len = . - certo_msg

falha_msg:
    .ascii "falha\n"
falha_len = . - falha_msg
