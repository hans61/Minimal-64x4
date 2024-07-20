#org 0x2000
    MIB 0xfe,0xffff
	JPS _SkipSpace
	CIT 39,_ReadPtr BLE failure ; wenn leerer Dateiname, dann fährt sich _LoadFile (OS_FindFile findet ein File -> _LoadFile versucht zu laden und überschreibt daten in der zero-page)
	JPS _LoadFile
	CPI 0
	BNE success
failure:
	JPS _Print
	'FILE NOT FOUND.',10,0,
halt:
	JPA _Prompt
success:	
	MIV soundData, ptrSound
	LDT ptrSound STZ counter
songLoop:	
	LDZ counter
	CPI 0xff
	BEQ finish
dataLoop:
	LDZ counter
	CPI 0x00
	BEQ noData
	DEZ counter
	INW ptrSound
	LDT ptrSound
	JAS wrSN76489
	JPA dataLoop
noData:
	JPS wait20ms
	INW ptrSound
	LDT ptrSound STZ counter
	JPA songLoop
finish:
	JPS SilenceAllChannels
	JPA _Prompt
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
wait20ms:
	MIZ 30,regB		; 50Hz -> 20ms
waitLoop:
	JPS wait1ms		; 997,25µS | 997,25+0,625+0,5+1,625=1000
	LR6				; 1,625µS
	DEZ regB		; 0,625µS
	BNE waitLoop		; 0,5µS/0,375µS -> 256 * 0,5+0,625+997,25=998,375 * 256 = 255,584mS
	RTS				; 1,25µ + JPS 1,375µS

wait1ms: MIZ 194,regA	; 4 (*0,125µS=0,5µS)			-> (0,5+999,25+2,625)µS | 195~1002,375 194~997,25µS
w1ms: NOP NOP DEZ regA BNE w1ms	; (32+5+4[3]) * 195 = 7994 = 999,25µS
	RTS						; 10 (+11 für JSR) = 2,625µS
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; write A to SN76489
wrSN76489:
	STB outPort1
	MIB 0x02,outPort2	; CLB rwLow
	NOP NOP NOP NOP	; (NOP = 2µS) the SN764898 requires 8µs at 4Mhz (16µs at 2Mhz)
	MIB 0x00,outPort2	; CLB rwHigh
	RTS
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SilenceAllChannels:
	LDI 0x9f JAS wrSN76489
	LDI 0xbf JAS wrSN76489
	LDI 0xdf JAS wrSN76489
	LDI 0xff JAS wrSN76489
	RTS
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#mute
#org 0x0000
regA: 0x00,
regB: 0x00,
Z0: 0x00,
PtrD: 0x0000,

ptrSound: 0x0000,
counter: 0x00,

#org 0x8000 soundData:

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