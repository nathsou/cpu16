
setw sp 0xffff
setw r1 1621
setw r2 17
jmp div

; r1 <- r1 % r2
; r2 <- r1 / r2
div:
    setw tmp 0x101
    store tmp r3
    set r3 0
    divloop:
        inc r3
        sub r1 r1 r2
        jgt divloop r1 r2

    move r2 r3
    setw tmp 0x101
    load r3 tmp

halt
