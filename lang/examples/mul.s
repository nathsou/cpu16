
.org 0x8000
setw sp 0xffff
setw r1 21
setw r2 1832
call mul
halt

; r2 <- r1 * r2
mul:
    store z r3 ; store r3 in RAM
    set r3 0
    jge mul_loop r1 r2 ; ensure r1 >= r2

    mul_swap:
        move tmp r2
        move r2 r1
        move r1 tmp
    
    mul_loop:
        jeq mul_end r2 z
        dec r2
        add r3 r3 r1
        jmp mul_loop

    mul_end:
        move r2 r3
        load r3 z ; restore r3
        ret

