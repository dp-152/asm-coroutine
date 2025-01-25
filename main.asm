format ELF64 executable
entry main

STDOUT_FILENO   =   1
STDERR_FILENO   =   1

SYS_write       =   1
SYS_exit        =   60

COROUT_NUM      =   8

COROUT_MAX      =   10
STACK_MAX       =   4 * 1024

segment executable
printnum:
  mov     r9,                     -3689348814741910323
  sub     rsp,                    40
  mov     BYTE[rsp+31],           10
  lea     rcx,                    [rsp+30]
.L2:
  mov     rax,                    rdi
  lea     r8,                     [rsp+32]
  mul     r9
  mov     rax,                    rdi
  sub     r8,                     rcx
  shr     rdx,                    3
  lea     rsi,                    [rdx+rdx*4]
  add     rsi,                    rsi
  sub     rax,                    rsi
  add     eax,                    48
  mov     BYTE[rcx],              al
  mov     rax,                    rdi
  mov     rdi,                    rdx
  mov     rdx,                    rcx
  sub     rcx,                    1
  cmp     rax,                    9
  ja      .L2
  lea     rax,                    [rsp+32]
  mov     edi,                    1
  sub     rdx,                    rax
  xor     eax,                    eax
  lea     rsi,                    [rsp+32+rdx]
  mov     rdx,                    r8
  call    syswrite
  add     rsp,                    40
  ret

counter:
  push    rbp                                     ; push stack
  mov     rbp,                    rsp             ; offset base ptr
  sub     rsp,                    8               ; alloc 8bit

  mov     QWORD[rbp-8],           0               ; init ctr val
.loop:
  cmp     QWORD[rbp-8],           10              ; cmp max value
  jge     .end                                    ; jmp to end if gte max val

  mov     rdi,                    STDOUT_FILENO
  mov     rsi,                    corout_msg
  mov     rdx,                    corout_msg_len
  call    syswrite

  mov     rdi,                    [ctx_cur]
  call    printnum
  
  mov     rdi,                    [rbp-8]         ; put curr val into rdi (arg0)
  call    printnum                                ; call subroutine
  call    corout_yield                            ; yield

  inc     QWORD[rbp-8]                            ; increment ctr val
  jmp     .loop

.end:
  add     rsp,                    8               ; free 8bit
  pop     rbp                                     ; pop stack
  ret

; rdi - ptr to routine to start
corout_go:
  cmp     QWORD[ctx_ct],          COROUT_MAX
  jge     oflow_fail

  mov     rbx,                    [ctx_ct]        ; curr ctx idx
  inc     QWORD[ctx_ct]

  mov     rax,                    [ctx_sp]        ; prev corout rsp
  sub     QWORD[ctx_sp],          STACK_MAX       ; pushback ctx_sp ptr by sizeof stack (next page)

  sub     rax,                    8               ; pushback rax by 8
  mov     QWORD[rax],             corout_ret      ; save add of corout_ret (will become the ret addr of corout)
  mov     [ctx_rsp+rbx*8],        rax             ; save stack ptr
  mov     QWORD[ctx_rbp+rbx*8],   0               ; save stack base
  mov     [ctx_rip+rbx*8],        rdi             ; save instr ptr

  ret

corout_init:
  cmp     QWORD[ctx_ct],          COROUT_MAX
  jge     oflow_fail
  
  mov     rbx,                    [ctx_ct]        ; curr ctx idx
  inc     QWORD[ctx_ct]

  pop     rax                                     ; reset stack ptr, save in rax

  sub     QWORD[ctx_sp],          STACK_MAX       ; pushback ctx_sp ptr by sizeof stack (next page)
  mov     [ctx_rsp+rbx*8],        rsp             ; save stack ptr
  mov     [ctx_rbp+rbx*8],        rbp             ; save stack base
  mov     [ctx_rip+rbx*8],        rax             ; save instr ptr
  jmp     rax

corout_yield:
  mov     rbx,                    [ctx_cur]
  pop     rax                                     ; reset stack ptr

  mov     [ctx_rsp+rbx*8],        rsp             ; save curr ctx
  mov     [ctx_rbp+rbx*8],        rbp             ; save curr ctx
  mov     [ctx_rip+rbx*8],        rax             ; save curr ctx

  inc     rbx                                     ; incr ctx idx
  xor     rcx,                    rcx             ; set rcx to zero
  cmp     rbx,                    [ctx_ct]        ; wrap on oflw
  cmovge  rbx,                    rcx             ; 

  mov     [ctx_cur],              rbx             ; update ctx idx

  mov     rsp,                    [ctx_rsp+rbx*8] ; write new ctx
  mov     rbp,                    [ctx_rbp+rbx*8] ; write new ctx
  jmp     QWORD[ctx_rip+rbx*8]                    ; jmp to ctx instr

corout_ret:
  mov     rdi,                    STDERR_FILENO
  mov     rsi,                    corout_ret_msg
  mov     rdx,                    corout_ret_msg_len
  call    syswrite
  mov     rdi,                    127
  call    exit

oflow_fail:
  mov     rdi,                    STDERR_FILENO
  mov     rsi,                    oflow_fail_msg
  mov     rdx,                    oflow_fail_msg_len
  call    syswrite
  mov     rdi,                    127
  call    exit

main:
  call    corout_init

  mov     rax,                    ctx_st
  mov     rbx,                    [ctx_sp]

  mov     rcx,                    0

.init_loop:
  mov     rdi,                    counter
  call    corout_go
  inc     rcx
  cmp     rcx,                    COROUT_NUM
  jl      .init_loop

.inf:
  call    corout_yield
  mov     rdi,                    STDOUT_FILENO
  mov     rsi,                    main_msg
  mov     rdx,                    main_msg_len
  call    syswrite
  jmp     .inf

  mov     rdi,                    STDOUT_FILENO
  mov     rsi,                    ok_msg
  mov     rdx,                    ok_msg_len
  call    syswrite

  mov     rdi,                    [ctx_ct]
  call    printnum

  mov     rdi,                    0
  call    exit

exit:
  mov     rax, SYS_exit
  syscall

helloworld:
  mov     rdi,                    STDOUT_FILENO
  mov     rsi,                    msg
  mov     rdx,                    msg_len
  call    syswrite

syswrite:
  mov     rax,                    SYS_write
  syscall
  ret

segment readable
msg:                db "Hello, world!", 0, 10
msg_len             = $-msg                     ; = curr addr - sizeof msg

oflow_fail_msg:     db "Coroutine overflow", 0, 10
oflow_fail_msg_len  = $-oflow_fail_msg

ok_msg:             db "OK!", 0, 10
ok_msg_len          = $-ok_msg

corout_ret_msg:     db "Coroutine returned", 0, 10
corout_ret_msg_len  = $-corout_ret_msg

corout_msg:         db "At Coroutine "
corout_msg_len      = $-corout_msg

main_msg:           db "At Main", 0, 10
main_msg_len        = $-main_msg

segment readable writable
ctx_sp:   dq  ctx_st+COROUT_MAX*STACK_MAX
ctx_st:   rb  COROUT_MAX*STACK_MAX
ctx_rsp:  rq  COROUT_MAX
ctx_rbp:  rq  COROUT_MAX
ctx_rip:  rq  COROUT_MAX
ctx_ct:   rq  1
ctx_cur:  rq  1
