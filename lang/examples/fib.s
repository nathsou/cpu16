set r1 1
set r2 1
set r4 1000

loop:
    jge end r1 r4
    add r3 r1 r2
    move r1 r2
    move r2 r3
    jmp loop

end:
    halt
