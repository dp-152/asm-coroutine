format ELF64

STDERR_FILENO   =   1

SYS_write       =   1
SYS_exit        =   60

COROUT_MAX      =   10
STACK_MAX       =   4 * 1024

section '.text'
public corout_go
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

public corout_init
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

public corout_yield
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

exit:
  mov     rax, SYS_exit
  syscall

syswrite:
  mov     rax,                    SYS_write
  syscall
  ret

section '.data'
msg:                db  "Hello, world!", 0, 10
msg_len             =   $-msg                     ; = curr addr - sizeof msg

oflow_fail_msg:     db  "Coroutine overflow", 0, 10
oflow_fail_msg_len  =   $-oflow_fail_msg

ok_msg:             db  "OK!", 0, 10
ok_msg_len          =   $-ok_msg

corout_ret_msg:     db  "Coroutine returned", 0, 10
corout_ret_msg_len  =   $-corout_ret_msg    

ctx_cur:            dq  0
ctx_sp:             dq  ctx_st+COROUT_MAX*STACK_MAX

section '.bss'
ctx_st:             rb  COROUT_MAX*STACK_MAX
ctx_rsp:            rq  COROUT_MAX
ctx_rbp:            rq  COROUT_MAX
ctx_rip:            rq  COROUT_MAX
ctx_ct:             rq  1
