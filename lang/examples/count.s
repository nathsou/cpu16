
.org 0x8000
set r1 0
set r2 0xf

loop:
  inc r1
  jne loop r1 r2
