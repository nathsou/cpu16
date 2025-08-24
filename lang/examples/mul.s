
setw sp 0xffff
setw r1 21
setw r2 1832
call mul
halt

; r2 <- r1 * r2
mul:
    push r3
    set r3 0
    jge mulloop r1 r2 ; ensure r1 >= r2

    mulswap:
        move tmp r2
        move r2 r1
        move r1 tmp
    
    mulloop:
        jeq mulend r2 z
        dec r2
        add r3 r3 r1
        jmp mulloop

    mulend:
        move r2 r3
        pop r3
        ret

