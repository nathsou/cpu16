
setw sp 0xffff
setw r1 1621
setw r2 17
call div
halt

; r1 <- r1 % r2
; r2 <- r1 / r2
div:
    push r3
    set r3 0
    divloop:
        inc r3
        sub r1 r1 r2
        jgt divloop r1 r2

    move r2 r3
    pop r3
    ret
