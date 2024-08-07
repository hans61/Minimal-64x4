; Minimal 64x4 I/O Test 82C55 03.03.2024 OK
; Port B output on LED
; Port A input D0..D2

#org 0x2000
    MIB 0xfe,0xffff
start:
    MIB 0x90,strW

readKey:
    LDB portA
    ANI 0x07
    LAB ptrTable
    STZ pointer
    LAB data
    STZ counter
next:
    INZ pointer
    LZB pointer,data
    STB portB
    JPS sleep
    DEZ counter
    BNE next
    JPA readKey
       
sleep: MIZ 0x00,regB
slp1:  MIZ 0x00,regA
slp2:  NOP 
       DEZ regA BNE slp2 
       DEZ regB BNE slp1 
       RTS


ptrTable:
    <data,<dat1,<dat2,<dat3,<dat4,<dat1,<dat2,<dat3,

; Running light data, 1st byte is the count of data bytes, that are output on 8 LEDs
#org 0x2100
data: 6,0x81,0x42,0x24,0x18,0x24,0x42,
dat1: 28,0x01,0x03,0x07,0x0f,0x1f,0x3f,0x7f,0xff,0xfe,0xfc,0xf8,0xf0,0xe0,0xc0,0x80,0xc0,0xe0,0xf0,0xf8,0xfc,0xfe,0xff,0x7f,0x3f,0x1f,0x0f,0x07,0x03,
dat2: 14,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x40,0x20,0x10,0x08,0x04,0x02,
dat3: 14,0x7f,0xbf,0xdf,0xef,0xf7,0xfb,0xfd,0xfe,0xfd,0xfb,0xf7,0xef,0xdf,0xbf,
dat4: 6,0x7e,0xbd,0xdb,0xe7,0xdb,0xbd,

#mute
#org 0x0000
regA: 0x00,
regB: 0x00,
pointer: 0x00,
counter: 0x00,

#org 0xfec0 portA:
#org 0xfec1 portB:
#org 0xfec2 portC:
#org 0xfec3 strW: 