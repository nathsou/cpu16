
.org 0x1000
.ascii "yodl!"

.org 0x8000
setw sp 0x7fff ; init stack pointer
setw r1 0xfff0 ; r1 = PPU_CTRL
set r5 128
store r1 r5 ; disable background rendering

inc r1 ; r1 = PPU_ADDR
setw r2 0x8000
store r1 r2 ; PPU_ADDR = 0x8000 (start address of nametable)

inc r1 ; r1 = PPU_DATA
setw r3 0x1000 ; address of string
set r2 0 ; length counter

char_loop:
    set r5 5 ; length of string
    jeq char_loop_end r2 r5
    load r4 r3 ; load character
    store r1 r4 ; write low byte
    set r5 8
    shr r4 r4 r5
    store r1 r4 ; write high byte
    inc r3 ; next character address
    inc r2
    jmp char_loop
    char_loop_end:

set r5 2
sub r1 r1 r5 ; r1 = PPU_CTRL
store r1 z ; enable background rendering

halt
