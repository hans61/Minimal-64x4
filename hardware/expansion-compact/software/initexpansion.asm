#org 0x2000
start:
	MIB 0x03,outPort2		; LEDs on
	LDI 159 JAS wrSN76489	; OFF TONE 1 0x9f
	LDI 191 JAS wrSN76489	; OFF TONE 2 0xbf
	LDI 223 JAS wrSN76489	; OFF TONE 3 0xdf
	LDI 255 JAS wrSN76489	; TURN OFF NOISE 0xff

	LDI 100 JAS delay_ms
	MIB 0x00,outPort2		; LEDs off
	LDI 100 JAS delay_ms
	MIB 0x03,outPort2		; LEDs on
	LDI 100 JAS delay_ms
	MIB 0x00,outPort2		; LEDs off
	LDI 100 JAS delay_ms
	MIB 0x03,outPort2		; LEDs on
	LDI 100 JAS delay_ms
	MIB 0x00,outPort2		; LEDs off
	;LDI 100 JAS delay_ms
	;MIB 0x03,outPort2		; LEDs on
	;LDI 100 JAS delay_ms
	;MIB 0x00,outPort2		; LEDs off

	RTS
	;JPA _Prompt

wrSN76489:
	STB outPort1
	MIB 0x02,outPort2	; CLB rwLow
	NOP NOP NOP NOP	; (NOP = 2µS) the SN764898 requires 8µs at 4Mhz (16µs at 2Mhz)
	MIB 0x00,outPort2	; CLB rwHigh
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

#mute
#org 0x0000
Z0: 0x00

#org 0xfee0 outPort1:	; SN76489 data port (4HC574)
#org 0xfee1 inPort1:	; 4HC574 input Kempston Joystick
#org 0xfee2 outPort2:	; 74HC74 port bit0 0x01=CS SD card bit1 0x02 WR SN76489

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
#org 0xf048 _PrintHex:
#org 0xf04b _Pixel:
#org 0xf04e _Line:
#org 0xf051 _Rect:
#org 0x00c0 _XPos:
#org 0x00c1 _YPos:
#org 0x00c2 _RandomState:
#org 0x00c6 _ReadNum:
#org 0x00c9 _ReadPtr:
#org 0x00cd _ReadBuffer: