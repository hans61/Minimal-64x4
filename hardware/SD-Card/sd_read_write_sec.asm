; this guide uses http://www.rjhcoding.com/avrc-sd-interface-1.php
; 
#org 0x2000
    LDI 0xfe STB 0xffff ; SP initialize
    ; test subroutines
main:
    JPS _Clear
    LDI 10 JAS delay_ms     ; give card time to power up
    
    ; Puffer füllen
    MIV sBuf, sdBufPtr
    MIV 512, Z1                         ; 512 byte block
clr1:
    LDI 0x69 STT sdBufPtr
    ;LDZ Z1 STT sdBufPtr
    INV sdBufPtr DEV Z1
    BNE clr1
    CZZ Z1, Z1+1
    BNE clr1
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
loop:
    JPS _Print
    "Read/write sector SD card to 0x3000", 10, "SD init...", 10, 0

    JPS SD_init
    CPI 0x00
    BEQ next1
    JPS _Print "Error initializaing SD CARD", 10, 0
    JPA _Prompt

next1:
    
    CLL int32+0                         ; read sector = 0 (int32 = [31..0])
    ;MIB 0x20,int32+3                   ; sector = 0x00000020 (lba)
    MIB 0x01,int32+2                    ; sector = 0x00000100
    MIV sBuf, sdBufPtr
    ;JPS SD_readSingleBlock
    JPS SD_writeSingleBlock
    
    JAS _PrintHex
    JPS _Print " = return, token:", 0
    LDB token JAS _PrintHex
    JPS _Print 10, 0
    JPA _Prompt
; ################################## Subroutines ###################################
; ----------------------------------------------
; Input: int32 = Sectornumber
;        sdBufPtr = Pointer to 512 byte data buffer
; Return:
; token = 0x00 - busy timeout
; token = 0x05 - data accepted
; token = 0xFF - response timeout
SD_writeSingleBlock:

    MIB 0xff, token                     ; token = 0xff
    MIB 0xff,spi NOP                    ; enable /CS sd card
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    
    JPS SD_CMD24                        ; send CMD24
    JPS SD_readRes1                     ; read result
    CPI 0x00
    BNE SD_writeSingleBlockE            ; no result end

    MIB 0xfe,spi NOP                    ; send start token

    MIV 512, Z1                         ; read 512 byte block
SD_writeSingleBlock3:
    LDT sdBufPtr STB spi NOP ;LDB spi
    INV sdBufPtr DEV Z1
    BNE SD_writeSingleBlock3
    CZZ Z1, Z1+1
    BNE SD_writeSingleBlock3
    ; fertig block schreiben
    
    ; wait for a response (timeout = 250ms)
    MIV 45455, Z1                       ; SD_MAX_READ_ATTEMPTS 250ms -> 250 / 0,0055 = 45455
SD_writeSingleBlock1:
    MIB 0xff,spi NOP LDB spi            ; 6 + 16 + 5 = 27 (52)
    CPI 0xff                            ; 3
    BNE SD_writeSingleBlock2            ; 4/3 -> 3 (Answer is there)
    DEV Z1                              ; 7
    BNE SD_writeSingleBlock1            ; 4/3 -> 4 + 7 + 3 + 3 + 27 = 44 * 0,125µs = 5,5 µs
    CZZ Z1, Z1+1
    BNE SD_writeSingleBlock1
    ; time exceeded
    LDI 0xff STB buffer+0
    JPA SD_writeSingleBlockE    

SD_writeSingleBlock2:
    ANI 0x1f CPI 0x05                   ; if data accepted
    STB token
    BNE SD_writeSingleBlockE            ; no
    
    ; wait for a response (timeout = 250ms), data accepted wait for write to finish
    MIV 45455, Z1                       ; SD_MAX_READ_ATTEMPTS 250ms -> 250 / 0,0055 = 45455
SD_writeSingleBlock4:
    MIB 0xff,spi NOP LDB spi            ; 6 + 16 + 5 = 27
    CPI 0x00                            ; 3
    BNE SD_writeSingleBlock5            ; 4/3 -> 3 (Answer is there)
    DEV Z1                              ; 7
    BNE SD_writeSingleBlock4            ; 4/3 -> 4 + 7 + 3 + 3 + 27 = 44 * 0,125µs = 5,5 µs
    CZZ Z1, Z1+1
    BNE SD_writeSingleBlock4
    LDI 0x00 STB token                  ; busy timeout
    JPA SD_writeSingleBlockE    
SD_writeSingleBlock5:
SD_writeSingleBlockE:
    PHS
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    PLS

    RTS
; ----------------------------------------------
; Input: int32 = Sectornumber
;        sdBufPtr = Pointer to 512 byte data buffer
; Return:
; token = 0xFE - Successful read
; token = 0x0X - Data error
; token = 0xFF - timeout

SD_readSingleBlock:
    MIB 0xff, token                     ; token = 0xff
    MIB 0xff,spi NOP                    ; enable /CS sd card
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    
    JPS SD_CMD17                        ; send CMD17
    JPS SD_readRes1                     ; read result
    CPI 0xff
    BEQ SD_readSingleBlockE             ; no result end
    
    ; wait maximum 100ms for data start
    MIV 18182, Z1                       ; SD_MAX_READ_ATTEMPTS 100ms -> 100 / 0,0055 = 18182
SD_readSingleBlock1:
    MIB 0xff,spi NOP LDB spi            ; 6 + 16 + 5 = 27
    CPI 0xff                            ; 3
    BNE SD_readSingleBlock2             ; 4/3 -> 3 (Answer is there)
    DEV Z1                              ; 7
    BNE SD_readSingleBlock1             ; 4/3 4 + 7 + 3 + 3 + 27 = 44 * 0,125µs = 5,5 µs
    CZZ Z1, Z1+1
    BNE SD_readSingleBlock1
    LDI 0xff STB buffer+0
    JPA SD_readSingleBlockE 

SD_readSingleBlock2:
    CPI 0xfe                            ; 0xfe for data start
    BNE SD_readSingleBlockE
    STB token
    MIV 512, Z1                         ; read 512 byte block
SD_readSingleBlock3:
    MIB 0xff,spi NOP LDB spi
    STT sdBufPtr
    INV sdBufPtr DEV Z1
    BNE SD_readSingleBlock3
    CZZ Z1, Z1+1
    BNE SD_readSingleBlock3
    
    MIB 0xff,spi NOP                    ; read 16-bit CRC
    LDB spi STB crc16+1
    MIB 0xff,spi NOP
    LDB spi STB crc16+0
    
    LDB buffer+0                        ; return value
SD_readSingleBlockE:
    PHS
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    PLS
    RTS
; ----------------------------------------------
SD_init:
    JPS SD_powerUpSeq
    
    MIZ 10,Z2
SD_init1:   
    JPS SD_goIdleState              ; CMD0
    LDB buffer+0 CPI 0x01
    BEQ SD_init2
    DEZ Z2
    BNE SD_init1
SD_Err: 
    LDI 1                           ; SD_ERROR
    RTS
SD_init2:
    JPS SD_sendIfCond               ; CMD8
    LDB buffer+0 CPI 0x01
    BNE SD_Err
    LDB buffer+4
    CPI 0xaa
    BNE SD_Err
    
    MIZ 100,Z2                      ; attempt to initialize card
SD_init3:
    JPS SD_sendApp                  ; CMD55
    LDB buffer+0 ANI 0xfe CPI 0x00  ; 0x00 or 0x01 is successful
    BNE SD_init4
    JPS SD_sendOpCond               ; ACMD41
SD_init4:
    LDI 10 JAS delay_ms             ; wait 10ms
    LDB buffer+0 CPI 0x00
    BEQ SD_init5
    DEZ Z2
    BNE SD_init3                    ; Next try
    JPA SD_Err
SD_init5:
    JPS SD_readOCR                  ; CMD58
    LDB buffer+1 ANI 0x80 CPI 0x00
    BEQ SD_Err
    LDI 0x00                        ; sd card successfully initialized
    RTS
; ----------------------------------------------
printBuf:
    MIV buffer, PtrD
    MIZ 5, Z0
    JPS _Print " read: ", 0
pBuf1:
    LDT PtrD JAS _PrintHex
    INV PtrD
    DEZ Z0
    BNE pBuf1
    JPS _Print 10, 0
    RTS
; ----------------------------------------------
SD_printR1:
    LDB buffer+0
    PHS
    JAS _PrintHex
    JPS _Print 10, 0
    PLS
    CPI 0x00
    BNE SD_printR1a
    JPS _Print " Card Ready", 10, 0
    RTS
SD_printR1a:
    PHS
    ANI 0x80 CPI 0x00
    PLS
    BEQ SD_printR1b
    JPS _Print " Error: MSB = 1", 10, 0
    RTS
SD_printR1b:    
    PHS
    ANI 0x40 CPI 0x00
    PLS
    BEQ SD_printR1c
    JPS _Print " Parameter Error", 10, 0
SD_printR1c:    
    PHS
    ANI 0x20 CPI 0x00
    PLS
    BEQ SD_printR1d
    JPS _Print " Address Error", 10, 0
SD_printR1d:    
    PHS
    ANI 0x10 CPI 0x00
    PLS
    BEQ SD_printR1e
    JPS _Print " Erase Sequence Error", 10, 0
SD_printR1e:
    PHS
    ANI 0x08 CPI 0x00
    PLS
    BEQ SD_printR1f
    JPS _Print " CRC Error", 10, 0
SD_printR1f:
    PHS
    ANI 0x04 CPI 0x00
    PLS
    BEQ SD_printR1g
    JPS _Print " Illegal Command", 10, 0
SD_printR1g:
    PHS
    ANI 0x02 CPI 0x00
    PLS
    BEQ SD_printR1h
    JPS _Print " Erase Reset Error", 10, 0
SD_printR1h:
    ANI 0x01 CPI 0x00
    BEQ SD_printR1i
    JPS _Print " In Idle State", 10, 0
SD_printR1i:
    RTS
; ----------------------------------------------
printR3:
    JPS SD_printR1
    LDB buffer+0 ANI 0xfe CPI 0x00
    BEQ printR3a
    RTS
printR3a:
    JPS _Print " Card Power Up Status: ", 0
    LDB buffer+1 ANI 0x40 CPI 0x00
    BEQ printR3b
    JPS _Print "READY", 10, 0
    JPA printR3c
printR3b:
    JPS _Print "BUSY", 10, 0
printR3c:
    JPS _Print " VDD Window: ", 0
    LDB buffer+3 ANI 0x80 CPI 0x00
    BEQ printR3d
    JPS _Print "2.7-2.8, ", 0
printR3d:
    LDB buffer+2 ANI 0x01 CPI 0x00
    BEQ printR3e
    JPS _Print "2.8-2.9, ", 0
printR3e:
    LDB buffer+2 ANI 0x02 CPI 0x00
    BEQ printR3f
    JPS _Print "2.9-3.0, ", 0
printR3f:
    LDB buffer+2 ANI 0x04 CPI 0x00
    BEQ printR3g
    JPS _Print "3.0-3.1, ", 0
printR3g:
    LDB buffer+2 ANI 0x10 CPI 0x00
    BEQ printR3h
    JPS _Print "3.1-3.2, ", 0
printR3h:
    LDB buffer+2 ANI 0x20 CPI 0x00
    BEQ printR3i
    JPS _Print "3.2-3.3, ", 0
printR3i:
    LDB buffer+2 ANI 0x40 CPI 0x00
    BEQ printR3j
    JPS _Print "3.3-3.4, ", 0
printR3j:
    LDB buffer+2 ANI 0x40 CPI 0x00
    BEQ printR3k
    JPS _Print "3.5-3.6, ", 0
printR3k:
    JPS _Print 10, 0
    RTS
; ----------------------------------------------
SD_printR7:
    JPS SD_printR1
    LDB buffer+0 ANI 0xfe CPI 0x00
    BEQ SD_printR7a
    RTS
SD_printR7a:
    JPS _Print " Command Version: ", 0
    LDB buffer+1 LL4 JAS _PrintHex JPS _Print 10, 0
    JPS _Print " Voltage Accepted: ", 0
    LDB buffer+3 ANI 0x1f
    CPI 0x01
    BNE SD_printR7b
    JPS _Print "2.7-3.6V", 10, 0
    JPA SD_printR7f
SD_printR7b:
    CPI 0x02
    BNE SD_printR7c
    JPS _Print "LOW VOLTAGE", 10, 0
    JPA SD_printR7f
SD_printR7c:
    CPI 0x04
    BNE SD_printR7d
    JPS _Print "RESERVED", 10, 0
    JPA SD_printR7f
SD_printR7d:
    CPI 0x08
    BNE SD_printR7e
    JPS _Print "RESERVED", 10, 0
    JPA SD_printR7f
SD_printR7e:
    JPS _Print "NOT DEFINED", 10, 0
SD_printR7f:
    JPS _Print " Echo: ", 0
    LDB buffer+4 JAS _PrintHex JPS _Print 10, 0 
    RTS
; ----------------------------------------------
SD_readRes1:
    MIZ 8, Z0
SD_read1:
    MIB 0xff,spi NOP LDB spi
    CPI 0xff
    BNE SD_read2
    DEZ Z0
    BNE SD_read1
    LDI 0xff
SD_read2:   
    STB buffer+0
    RTS
; ----------------------------------------------
SD_readRes7:
    JPS SD_readRes1
    LDB buffer+0 ANI 0xfe CPI 0x00
    BNE SD_readRes7a
    MIB 0xff,spi NOP LDB spi STB buffer+1
    MIB 0xff,spi NOP LDB spi STB buffer+2
    MIB 0xff,spi NOP LDB spi STB buffer+3
    MIB 0xff,spi NOP LDB spi STB buffer+4
SD_readRes7a:   
    RTS
; ----------------------------------------------
SD_CMD0:
    MIV cmd0, PtrD JPA SD_command
SD_CMD8:
    MIV cmd8, PtrD JPA SD_command
SD_CMD58:
    MIV cmd58, PtrD JPA SD_command
SD_CMD55:
    MIV cmd55, PtrD JPA SD_command
SD_ACMD41:
    MIV ACMD41, PtrD JPA SD_command
SD_CMD16:
    MIV cmd16, PtrD JPA SD_command
; ----------------------------------------------
; *PtrD Command 6 byte (1 byte CMD, 4 byte Argument, 1 byte CRC)
SD_command:
    MIZ 6, Z0
sCMD1:
    LDT PtrD
    STB spi NOP
    INV PtrD
    DEZ Z0
    BNE sCMD1
    RTS
; ----------------------------------------------
SD_CMD17:
    LDI 0x51 STB spi NOP
    ; Sector Number
    LDB int32+0 STB spi NOP
    LDB int32+1 STB spi NOP
    LDB int32+2 STB spi NOP
    LDB int32+3 STB spi NOP
    LDI 0x01 STB spi NOP
    RTS
; ----------------------------------------------
SD_CMD24:
    LDI 0x58 STB spi NOP
    ; Sector Number
    LDB int32+0 STB spi NOP
    LDB int32+1 STB spi NOP
    LDB int32+2 STB spi NOP
    LDB int32+3 STB spi NOP
    LDI 0x01 STB spi NOP
    RTS
; ----------------------------------------------
SD_goIdleState:
    MIB 0xff,spi NOP
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    JPS SD_CMD0
    JPS SD_readRes1
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    RTS
; ----------------------------------------------
; CMD55 initiates an application-specific command
SD_sendApp:
    MIB 0xff,spi NOP
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    JPS SD_CMD55
    JPS SD_readRes1
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    RTS
; ----------------------------------------------
; ACMD41 - SD_SEND_OP_COND (send operating condition)
SD_sendOpCond:
    MIB 0xff,spi NOP
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    JPS SD_ACMD41
    JPS SD_readRes1
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    RTS
; ----------------------------------------------
; CMD58 - read OCR (operation conditions register)
SD_readOCR:
    MIB 0xff,spi NOP
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    JPS SD_CMD58
    JPS SD_readRes7
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    RTS
; ----------------------------------------------
; CMD8 - SEND_IF_COND (send interface condition)
SD_sendIfCond:
    MIB 0xff,spi NOP
    MIB 0x01,cs1
    MIB 0xff,spi NOP
    JPS SD_CMD8
    JPS SD_readRes7
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
    RTS
; ----------------------------------------------
; Put SD card into SPI mode
SD_powerUpSeq:
    MIB 0x00,cs1        ; make sure card is deselected
    LDI 1 JAS delay_ms  ; give SD card time to power up
    MIZ 10, Z0          ; send 80 clock cycles to synchronize (8 bits times 10)
SD_power1:  
    MIB 0xff,spi NOP
    DEZ Z0
    BNE SD_power1
    MIB 0x01,cs1        ; deselect SD card
    MIB 0xff,spi NOP
    RTS
; ----------------------------------------------
; delay A * 1 ms
delay_ms:
    PHS             ; 8
    MIZ 194,Z0      ; 4 ( + 8 ) = 12 * 0,125 = 1,5 µs 
delay1:             ; n * 0,125 * (32+5+4) = n * 5,125 µs
    NOP NOP         ; 32
    DEZ Z0          ; 5
    BNE delay1      ; 4/3 -> 194 * 5,125 = 994,25 - 0,125 = 994,125 µs
    PLS             ; 6
    DEC             ; 3
    BNE delay_ms    ; 4/3
    RTS             ; 10 ( + 3 + 3 + 6 ) = 22 * 0,125 = 2,75 + 1,5 µs = 4,25 µs + 994,125 µs + 2 µs (call) = 1000,375s

; ----------------------------------------------
; buffer for writing and reading commands from the SD card
buffer: 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
int32:  0x00, 0x00, 0x00, 0x00
token:  0x00
crc16:  0x00, 0x00
; command pattern
; CMD = number | 0x40
; last byte CRC7 | 0x01
cmd0:   0x40, 0x00, 0x00, 0x00, 0x00, 0x95
cmd8:   0x48, 0x00, 0x00, 0x01, 0xaa, 0x87
cmd58:  0x7a, 0x00, 0x00, 0x00, 0x00, 0x75
cmd55:  0x77, 0x00, 0x00, 0x00, 0x00, 0x01
ACMD41: 0x69, 0x40, 0x00, 0x00, 0x00, 0x01
cmd16:  0x50, 0x00, 0x00, 0x02, 0x00, 0x01

#mute
#org 0x3000 sBuf:   ; 512 

#org 0x0000
regA:   0x00,
regB:   0x00,
Z0:     0x00,
Z1:     0x0000,
Z2:     0x00,
Z3:     0x00,
PtrD:   0x0000,
sdBufPtr:   0x0000,

#org 0xfe80 spi:    ; address for reading and writing the spi shift register, writing starts the beat
#org 0xfe90 cs1:    ; bit 0 = 1 -> /CS = 0 | bit 0 = 0 -> /CS = 1

; MinOS API definitions generated by 'asm os.asm -s_'
#org 0xf000 _Start:
#org 0xf003 _Prompt:
#org 0xf006 _MemMove:
#org 0xf009 _Random:
#org 0xf00c _ScanPS2:
#org 0xf00f _ResetPS2:
#org 0xf012 _ReadInput:
#org 0xf015 _WaitInput:
#org 0xf018 _ReadLine:
#org 0xf01b _SkipSpace:
#org 0xf01e _ReadHex:
#org 0xf021 _SerialWait:
#org 0xf024 _SerialPrint:
#org 0xf027 _FindFile:
#org 0xf02a _LoadFile:
#org 0xf02d _SaveFile:
#org 0xf030 _ClearVRAM:
#org 0xf033 _Clear:
#org 0xf036 _ClearRow:
#org 0xf039 _ScrollUp:
#org 0xf03c _ScrollDn:
#org 0xf03f _Char:
#org 0xf042 _PrintChar:
#org 0xf045 _Print:
#org 0xf048 _PrintPtr:
#org 0xf04b _PrintHex:
#org 0xf04e _SetPixel:
#org 0xf051 _Line:
#org 0xf054 _Rect:
#org 0x00c0 _XPos:
#org 0x00c1 _YPos:
#org 0x00c2 _RandomState:
#org 0x00c6 _ReadNum:
#org 0x00c9 _ReadPtr:
#org 0x00cd _ReadBuffer: