
.org 0x8000
setw sp 0xffff
setw r1 3
push r1
setw r1 7
push r1
call fn_add
halt

fn_add:
    pop r4 ; save return addr
    pop r1 ; first argument
    pop r2 ; second argument
    add r1 r1 r2
    push r1
    move pc r4 ; ret

