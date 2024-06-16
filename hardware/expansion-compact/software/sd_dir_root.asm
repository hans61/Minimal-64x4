; this guide uses http://www.rjhcoding.com/avrc-sd-interface-1.php
; Use with test SD card with FAT32 a folder SUBFOLDR
; in which there is a file DEEPFILE.TXT
#org 0x2000
	MIB 0xfe,0xffff 						; SP initialize
    ; test subroutines
main:
    JPS _Clear
    LDI 10 JAS delay_ms     				; give card time to power up
    JPS _Print "SD init...", 10, 0
    JPS SD_init
    CPI 0x00
    BEQ next1
    JPS _Print "Error initializaing SD CARD", 10, 0
    JPA _Prompt
next1:
	JPS fat32_init
	BCC initsuccess
fat32error:
	LDB fat32_errorstage JAS _PrintHex
    JPS _Print " FAT32 Error", 10, 0
    JPA _Prompt
initsuccess:
	; Open root directory
    JPS _Print "Open Root", 10, 0
	JPS fat32_openroot
	; Find subdirectory by name
readEntry:
	JPS fat32_readdirent
	BCC nextEntry
	JPA _Prompt 
nextEntry:
	MIZ 11,Z0
	MIZ 14,Z1
	MVV zp_sd_address,zp_h_address
	AIV 11,zp_h_address
	LDT zp_h_address
	STB Attr
	MVV zp_sd_address,zp_h_address
	LDB Attr
	ANI 0x08			; Volume-Label
	CPI 0x00
	BNE printVolumeLabel
	LDB Attr
	ANI 0x04			; System
	CPI 0x00
	BNE readEntry
nextE1:	
	LDT zp_h_address
	CPI 0x20
	BEQ nextE3
	PHS
	CIZ 3,Z0
	BNE nextE2
	LDI 0x2e JAS _PrintChar
	DEZ Z1
nextE2:
	PLS
	JAS _PrintChar
	DEZ Z1
nextE3:
	INV zp_h_address
	DEZ Z0
	BNE nextE1
nextE4:
	CIZ 0x00,Z1
	BEQ nextE5
	LDI 0x20 JAS _PrintChar
	DEZ Z1
	JPA nextE4
nextE5:
	LDB Attr
	ANI 0x10			; Dir
	CPI 0x00
	BEQ nextE6
	JPS _Print "<DIR>",0
	JPA nextE9
nextE6:
	AIV 20,zp_h_address
	LDT zp_h_address JAS _PrintHex
	DEV zp_h_address
	LDT zp_h_address JAS _PrintHex
	DEV zp_h_address
	LDT zp_h_address JAS _PrintHex
	DEV zp_h_address
	LDT zp_h_address JAS _PrintHex
nextE9:
	LDI 10 JAS _PrintChar
	JPA readEntry
printVolumeLabel:
	JPS _Print "Volume-Label: ",0
	MIZ 11,Z0
printVL1:
	LDT zp_h_address
	JAS _PrintChar
	INV zp_h_address
	DEZ Z0
	BNE printVL1
	JPA nextE9
Attr:
	0x00
; ################################## Subroutines ###################################
cs1on:
    MIB 0xff,spi NOP
    MIB 0x01,cs1
    MIB 0xff,spi NOP
	RTS
cs1off:
    MIB 0xff,spi NOP
    MIB 0x00,cs1
    MIB 0xff,spi NOP
	RTS



; ----------------------------------------------
; |             Begin Init FAT32               |
; ----------------------------------------------
fat32_init:
	; Modul initialisieren - MBR usw. lesen, Partition suchen,
	; und Variablen für die Navigation im Dateisystem einrichten

	; MBR lesen und relevante Informationen extrahieren

	CLB fat32_errorstage

	; Lesen Sie den MBR und extrahieren Sie relevante Informationen
    CLQ zp_sd_currentsector+0                         	; Clear fast long, read sector = 0 (zp_sd_currentsector = [0..31]) 4 byte
    MIV fat32_readbuffer, zp_sd_address					; (zp_sd_address) = fat32_readbuffer = 0x3000
    JPS sd_readsector

	INB fat32_errorstage 		; stage 1 = boot sector signature check -> CMD17 error

	; signature check
	LDB fat32_readbuffer+510 	; Boot sector signature 55
	CPI 0x55
	BNE fail
	LDB fat32_readbuffer+511 	; Boot sector signature aa
	CPI 0xaa
	BNE fail

	INB fat32_errorstage 		; stage 2 = finding partition -> signature error

	; Find a FAT32 partition
	MIZ 0,RegX
	LZB RegX,fat32_readbuffer+0x1c2
	CPI 12						; check of FAT32
	BEQ foundpart
	MIZ 16,RegX
	LZB RegX,fat32_readbuffer+0x1c2
	CPI 12						; check of FAT32
	BEQ foundpart
	MIZ 32,RegX
	LZB RegX,fat32_readbuffer+0x1c2
	CPI 12						; check of FAT32
	BEQ foundpart
	MIZ 48,RegX
	LZB RegX,fat32_readbuffer+0x1c2
	CPI 12						; check of FAT32
	BEQ foundpart
fail:
	JPA error
foundpart:

	; Read the FAT32 BPB -> LBA Beginn -> "Volume ID" first sector of the partition
	; RegX offset partition 0..3
	LZB RegX,fat32_readbuffer+0x1c6
	STZ zp_sd_currentsector+0
	LZB RegX,fat32_readbuffer+0x1c7
	STZ zp_sd_currentsector+1
	LZB RegX,fat32_readbuffer+0x1c8
	STZ zp_sd_currentsector+2
	LZB RegX,fat32_readbuffer+0x1c9
	STZ zp_sd_currentsector+3

    MIV fat32_readbuffer, zp_sd_address
    JPS sd_readsector

	INB fat32_errorstage 		; stage 3 = BPB signature check LBA begin -> "Volume ID"

	LDB fat32_readbuffer+510 	; Boot sector signature 55
	CPI 0x55
	BNE fail
	LDB fat32_readbuffer+511 	; Boot sector signature aa
	CPI 0xaa
	BNE fail

	INB fat32_errorstage 		; stage 4 = RootEntCnt check

	LDB fat32_readbuffer+17 	; RootEntCnt should be 0 for FAT32
	ORB fat32_readbuffer+18
	CPI 0x00
	BNE fail

	INB fat32_errorstage 		; stage 5 = TotSec16 check

	LDB fat32_readbuffer+19		; TotSec16 should be 0 for FAT32
	ORB fat32_readbuffer+20
	CPI 0x00
	BNE fail

	INB fat32_errorstage 		; stage 6 = SectorsPerCluster check

	; Check bytes per filesystem sector, it should be 512 for any SD card that supports FAT32
	LDB fat32_readbuffer+11
	CPI 0x00
	BNE fail
	LDB fat32_readbuffer+12 	; high byte is 2 (512), 4, 8, or 16
	CPI 0x02
	BNE fail

	; Calculate the starting sector of the FAT
	LDZ zp_sd_currentsector
	ADB fat32_readbuffer+14		; reserved sectors lo
	STB fat32_fatstart
	STB fat32_datastart
	LDB zp_sd_currentsector+1
	ACB fat32_readbuffer+15    	; reserved sectors hi
	STB fat32_fatstart+1
	STB fat32_datastart+1
	LDB zp_sd_currentsector+2
	ACI 0x00
	STB fat32_fatstart+2
	STB fat32_datastart+2
	LDB zp_sd_currentsector+3
	ACI 0x00
	STB fat32_fatstart+3
	STB fat32_datastart+3

	; Calculate the starting sector of the data area
	LDB fat32_readbuffer+16 STZ Z0  ; number of FATs
skipfatsloop:
	LDB fat32_datastart
	ADB fat32_readbuffer+36 ; fatsize 0
	STB fat32_datastart
	LDB fat32_datastart+1
	ACB fat32_readbuffer+37 ; fatsize 1
	STB fat32_datastart+1
	LDB fat32_datastart+2
	ACB fat32_readbuffer+38 ; fatsize 2
	STB fat32_datastart+2
	LDB fat32_datastart+3
	ACB fat32_readbuffer+39 ; fatsize 3
	STB fat32_datastart+3
	DEZ Z0
	BNE skipfatsloop

	; Sectors-per-cluster is a power of two from 1 to 128
	LDB fat32_readbuffer+13
	STB fat32_sectorspercluster

	; Remember the root cluster
	LDB fat32_readbuffer+44
	STB fat32_rootcluster
	LDB fat32_readbuffer+45
	STB fat32_rootcluster+1
	LDB fat32_readbuffer+46
	STB fat32_rootcluster+2
	LDB fat32_readbuffer+47
	STB fat32_rootcluster+3

	CLC
	RTS

error:
	SEC
	RTS
; ----------------------------------------------
; *             Ende Init FAT32                *
; ----------------------------------------------
; ----------------------------------------------
printBuffer:
    MIV fat32_readbuffer,zp_sd_address
	JPA print256
printBuffer2:
    MIV buffer2, zp_sd_address
print256:
    ;MIV 0x0080, Z1
	LDB fat32_bytesremaining STZ Z1
	LDB fat32_bytesremaining+1 STZ Z1+1
p256a:
	LDT zp_sd_address
	JAS _PrintHex
    INV zp_sd_address
    DEV Z1
    BNE p256a
    CZZ Z1, Z1+1							
    BNE p256a
    JPS _Print 10, 0						; Print nl
	RTS
; ----------------------------------------------
; |             Begin Seekcluster              |
; ----------------------------------------------
fat32_seekcluster:
	; Gets ready to read fat32_nextcluster, and advances it according to the FAT

	; FAT sector = (cluster*4) / 512 = (cluster*2) / 256
	LDB fat32_nextcluster
	LL1
	LDB fat32_nextcluster+1
	RL1
	STB zp_sd_currentsector
	LDB fat32_nextcluster+2
	RL1
	STB zp_sd_currentsector+1
	LDB fat32_nextcluster+3
	RL1
	STB zp_sd_currentsector+2
	; note: cluster numbers never have the top bit set, so no carry can occur

	; Add FAT starting sector zp_sd_currentsector = zp_sd_currentsector + fat32_fatstart
	LDZ zp_sd_currentsector
	ADB fat32_fatstart
	STZ zp_sd_currentsector
	LDZ zp_sd_currentsector+1
	ACB fat32_fatstart+1
	STZ zp_sd_currentsector+1
	LDZ zp_sd_currentsector+2
	ACB fat32_fatstart+2
	STZ zp_sd_currentsector+2
	LDI 0x00
	ACB fat32_fatstart+3
	STZ zp_sd_currentsector+3

	; Target buffer
    MIV fat32_readbuffer, zp_sd_address
	; Read the sector from the FAT
	JPS sd_readsector

	; Before using this FAT data, set currentsector ready to read the cluster itself
	; We need to multiply the cluster number minus two by the number of sectors per 
	; cluster, then add the data region start sector

	; Subtract two from cluster number
	LDB fat32_nextcluster
	SUI 0x02						; Sub immediate from A: A = A - imm
	STZ zp_sd_currentsector
	LDB fat32_nextcluster+1
	SCI 0x00						; Sub imm from A with C: A = A - imm - 1 + C
	STZ zp_sd_currentsector+1
	LDB fat32_nextcluster+2
	SCI 0x00
	STZ zp_sd_currentsector+2
	LDB fat32_nextcluster+3
	SCI 0x00
	STZ zp_sd_currentsector+3

	; Multiply by sectors-per-cluster which is a power of two between 1 and 128
	LDB fat32_sectorspercluster
spcshiftloop:
	LR1
	BCS spcshiftloopdone
	PHS
	LLZ zp_sd_currentsector
	RLZ zp_sd_currentsector+1
	RLZ zp_sd_currentsector+2
	RLZ zp_sd_currentsector+3
	PLS
	JPA spcshiftloop

spcshiftloopdone:
	; Add the data region start sector
	LDZ zp_sd_currentsector
	ADB fat32_datastart
	STZ zp_sd_currentsector
	LDZ zp_sd_currentsector+1
	ACB fat32_datastart+1
	STZ zp_sd_currentsector+1
	LDZ zp_sd_currentsector+2
	ACB fat32_datastart+2
	STZ zp_sd_currentsector+2
	LDZ zp_sd_currentsector+3
	ACB fat32_datastart+3
	STZ zp_sd_currentsector+3

	; That's now ready for later code to read this sector in - tell it how many consecutive
	; sectors it can now read
	LDB fat32_sectorspercluster
	STB fat32_pendingsectors

	; Now go back to looking up the next cluster in the chain
	; Find the offset to this cluster's entry in the FAT sector we loaded earlier

	; Offset = (cluster*4) & 511 = (cluster & 127) * 4
	LDB fat32_nextcluster
	ANI 0x7f
	LL2
	STZ RegY		; Y = low byte of offset

	; Add the potentially carried bit to the high byte of the address
	LDZ zp_sd_address+1
	ACI 0x00
	STZ zp_sd_address+1

	; Copy out the next cluster in the chain for later use
	LZB RegY,zp_sd_address
	STB fat32_nextcluster
	INZ RegY
	LZB RegY,zp_sd_address
	STB fat32_nextcluster+1
	INZ RegY
	LZB RegY,zp_sd_address
	STB fat32_nextcluster+2
	INZ RegY
	LZB RegY,zp_sd_address
	ANI 0x0f
	STB fat32_nextcluster+3

	; See if it's the end of the chain
	ORI 0xf0
	ANB fat32_nextcluster+2
	ANB fat32_nextcluster+1
	CPI 0xff
	BNE notendofchain
	LDB fat32_nextcluster
	CPI 0xf8
	BCC notendofchain

	; It's the end of the chain, set the top bits so that we can tell this later on
	STB fat32_nextcluster+3
notendofchain:
	RTS
; ----------------------------------------------
; |              End Seekcluster               |
; ----------------------------------------------
; ----------------------------------------------
; |           Begin Readnextsector             |
; ----------------------------------------------
fat32_readnextsector:
	; Reads the next sector from a cluster chain into the buffer at fat32_address.
	;
	; Advances the current sector ready for the next read and looks up the next cluster
	; in the chain when necessary.
	;
	; On return, carry is clear if data was read, or set if the cluster chain has ended.

	; Maybe there are pending sectors in the current cluster
	LDB fat32_pendingsectors
	CPI 0x00
	BNE readsector

	; No pending sectors, check for end of cluster chain
	LDB fat32_nextcluster+3
	CPI 0x00
	BMI endofchain

	; Prepare to read the next cluster
	JPS fat32_seekcluster

readsector:
	DEB fat32_pendingsectors

	; Set up target address
	;LDB fat32_address
	;STZ zp_sd_address
	;LDB fat32_address+1
	;STZ zp_sd_address+1
	MWV fat32_address,zp_sd_address

	; Read the sector
	JPS sd_readsector

	; Advance to next sector
	INQ zp_sd_currentsector

	;INB zp_sd_currentsector
	;BNE sectorincrementdone
	;INB zp_sd_currentsector+1
	;BNE sectorincrementdone
	;INB zp_sd_currentsector+2
	;BNE sectorincrementdone
	;INB zp_sd_currentsector+3
sectorincrementdone:

	; Success - clear carry and return
	CLC
	RTS

endofchain:
	; End of chain - set carry and return
	SEC
	RTS
; ----------------------------------------------
; |             End Readnextsector             |
; ----------------------------------------------
; ----------------------------------------------
; |               Begin Openroot               |
; ----------------------------------------------
fat32_openroot:
	; Prepare to read the root directory

	LDB fat32_rootcluster
	STB fat32_nextcluster
	LDB fat32_rootcluster+1
	STB fat32_nextcluster+1
	LDB fat32_rootcluster+2
	STB fat32_nextcluster+2
	LDB fat32_rootcluster+3
	STB fat32_nextcluster+3

	JPS fat32_seekcluster

	; Set the pointer to a large value so we always read a sector the first time through
	MIZ 0xff,zp_sd_address+1

	RTS
; ----------------------------------------------
; |                End Openroot                |
; ----------------------------------------------
; ----------------------------------------------
; |              Begin Opendirent              |
; ----------------------------------------------
fat32_opendirent:
	; Prepare to read from a file or directory based on a dirent
	;
	; Point zp_sd_address at the dirent

	; Seek to first cluster
	MVV zp_sd_address,zp_h_address
	AIV 20,zp_h_address					; zp_sd_address+20
	LDT zp_h_address	
	STB fat32_nextcluster+2
	INV zp_h_address
	LDT zp_h_address
	STB fat32_nextcluster+3

	AIV 5,zp_h_address					; zp_sd_address+26
	LDT zp_h_address
	STB fat32_nextcluster
	INV zp_h_address
	LDT zp_h_address
	STB fat32_nextcluster+1

	; Remember file size in bytes remaining zp_sd_address+28
	INV zp_h_address
	LDT zp_h_address
	STB fat32_bytesremaining+0
	INV zp_h_address
	LDT zp_h_address
	STB fat32_bytesremaining+1
	INV zp_h_address
	LDT zp_h_address
	STB fat32_bytesremaining+2
	INV zp_h_address
	LDT zp_h_address
	STB fat32_bytesremaining+3

	; Begin Debug
	JPS _Print "File Size:",0
	LDB fat32_bytesremaining+3 JAS _PrintHex
	LDB fat32_bytesremaining+2 JAS _PrintHex
	LDB fat32_bytesremaining+1 JAS _PrintHex
	LDB fat32_bytesremaining+0 JAS _PrintHex
	JPS _Print 10,0
	; End Debug

	JPS fat32_seekcluster

	; Set the pointer to a large value so we always read a sector the first time through
	MIZ 0xff,zp_sd_address+1

	RTS
; ----------------------------------------------
; |               End Opendirent               |
; ----------------------------------------------
; ----------------------------------------------
; |              Begin Readdirent              |
; ----------------------------------------------
fat32_readdirent:
	; Read a directory entry from the open directory
	;
	; On exit the carry is set if there were no more directory entries.
	;
	; Otherwise, A is set to the file''s attribute byte and
	; zp_sd_address points at the returned directory entry.
	; LFNs and empty entries are ignored automatically.

	; Increment pointer by 32 to point to next entry
	; clc zp_sd_address = zp_sd_address + 32
	LDZ zp_sd_address
	ADI 32
	STZ zp_sd_address
	LDZ zp_sd_address+1
	ACI 0
	STZ zp_sd_address+1

	; If it''s not at the end of the buffer, we have data already
	CPI 0x32				;CPI >(fat32_readbuffer+0x0200) -> 0x3000+0x0200=0x3200  #org 0x3000 fat32_readbuffer:   ; 512
	BCC gotdata

	; Read another sector
	MIW fat32_readbuffer,fat32_address

	JPS fat32_readnextsector
	BCC gotdata

endofdirectory:
	SEC
	RTS

gotdata:
	; Check first character
	LDT zp_sd_address
	CPI 0x00
	; End of directory => abort
	BEQ endofdirectory

	; Empty entry => start again
	CPI 0xe5
	BEQ fat32_readdirent

	; Check attributes
	MVV zp_sd_address,zp_h_address
	AIV 11,zp_h_address
	LDT zp_h_address		;lda (zp_sd_address),y y=11
	ANI 0x3f
	CPI 0x0f 				; LFN => start again
	BEQ fat32_readdirent

	; Yield this result
	CLC
	RTS
; ----------------------------------------------
; |               End Readdirent               |
; ----------------------------------------------
; ----------------------------------------------
; |              Begin Finddirent              |
; ----------------------------------------------
fat32_finddirent:
	; Finds a particular directory entry.  X,Y point to the 11-character filename to seek.
	; The directory should already be open for iteration.

	; Form ZP pointer to user''s filename
	LDZ RegX STB fat32_filenamepointer		;stx fat32_filenamepointer
	LDZ RegY STB fat32_filenamepointer+1	;sty fat32_filenamepointer+1
	; Iterate until name is found or end of directory
direntloop:
	JPS fat32_readdirent
	BCC comparenameloop1
	RTS 												; with carry set
comparenameloop1:
	MZB zp_sd_address+0,comparenameloop+1 MZB zp_sd_address+1,comparenameloop+2
	MBB fat32_filenamepointer+0,comparenameloop+3 MBB fat32_filenamepointer+1,comparenameloop+4
	MIZ 10,RegY
comparenameloop:
	CBB 0x8000,0x9000
	BNE direntloop
	INW comparenameloop+1 	INW comparenameloop+3
	DEZ RegY 											;dey
	BPL comparenameloop
	; Found it
	CLC
	RTS
; ----------------------------------------------
; |               End Finddirent               |
; ----------------------------------------------
; ----------------------------------------------
; |            Begin File read Byte            |
; ----------------------------------------------
fat32_file_readbyte:
	; Read a byte from an open file
	; The byte is returned in A with C clear; or if end-of-file was reached, C is set instead

	; Is there any data to read at all?
	LDB fat32_bytesremaining
	ORB fat32_bytesremaining+1
	ORB fat32_bytesremaining+2
	ORB fat32_bytesremaining+3
	CPI 0x00
	BEQ rts1C

	; Decrement the remaining byte count fat32_bytesremaining--
	DEW fat32_bytesremaining
	LDB fat32_bytesremaining
	ORB fat32_bytesremaining+1
	CPI 0x00
	BNE continue
	LDB fat32_bytesremaining+2
	ORB fat32_bytesremaining+3
	BEQ continue
	DEW fat32_bytesremaining+2
continue:	
	; Need to read a new sector?
	LDZ zp_sd_address+1	;lda zp_sd_address+1
	CPI 0x32			;cmp #>(fat32_readbuffer+$200) CPI >(fat32_readbuffer+0x0200) -> #org 0x3000 fat32_readbuffer:   ; 512
	BCC gotdata1

	; Read another sector
	MIW fat32_readbuffer,fat32_address
	JPS fat32_readnextsector
	BCS rts1C                 ; this shouldn't happen

gotdata1:
	LDT zp_sd_address
	PHS INV zp_sd_address PLS
	CLC
	RTS
rts1C:
	SEC
	RTS
; ----------------------------------------------
; |             End File read Byte             |
; ----------------------------------------------
; ----------------------------------------------
; |              Begin File read               |
; ----------------------------------------------
fat32_file_read:
	; Read a whole file into memory.  It's assumed the file has just been opened 
	; and no data has been read yet.
	;
	; Also we read whole sectors, so data in the target region beyond the end of the 
	; file may get overwritten, up to the next 512-byte boundary.
	;
	; And we don't properly support 64k+ files, as it's unnecessary complication given
	; the 6502's small address space
	
	; Round the size up to the next whole sector
	LDB fat32_bytesremaining
	CPI 1							;cmp #1                      ; set carry if bottom 8 bits not zero
	LDB fat32_bytesremaining+1
	ACI 0							;adc #0                      ; add carry, if any
	LR1								;lsr                         ; divide by 2
	ACI 0							;adc #0                      ; round up
	; No data?
	BEQ done

    ; Store sector count - not a byte count any more
	STB sectorCNT
	; Read entire sectors to the user-supplied buffer
wholesectorreadloop:
	; Read a sector to fat32_address
	JPS fat32_readnextsector
	; Advance fat32_address by 512 bytes
	INB fat32_address+1
	INB fat32_address+1
	DEB sectorCNT    	; note - actually stores sectors remaining
	BNE wholesectorreadloop
done:
	RTS
sectorCNT: 0x00
; ----------------------------------------------
; |                End File read               |
; ----------------------------------------------
; ----------------------------------------------
; |           Begin writeSingleBlock           |
; ----------------------------------------------
; Input: zp_sd_currentsector = Sectornumber
;        zp_sd_address = Pointer to 512 byte data buffer
; Return:
; token = 0x00 - busy timeout
; token = 0x05 - data accepted
; token = 0xFF - response timeout
;SD_writeSingleBlock:
;
;    MIB 0xff,token                      ; token = 0xff
;    MIB 0xff,spi NOP                    ; enable /CS sd card
;    LDI 0x01 STB cs1
;    MIB 0xff,spi NOP
;
;    JPS SD_CMD24                        ; send CMD24
;    JPS SD_readRes1                     ; read result
;    CPI 0x00
;    BNE SD_writeSingleBlockE            ; no result end
;
;    MIB 0xfe,spi NOP                    ; send start token
;
;    MIV 512, Z1                         ; read 512 byte block
;SD_writeSingleBlock3:
;    LDT zp_sd_address STB spi NOP ;LDB spi
;    INV zp_sd_address DEV Z1
;    BNE SD_writeSingleBlock3
;    CZZ Z1, Z1+1
;    BNE SD_writeSingleBlock3
;    ; fertig block schreiben
;
;    ; wait for a response (timeout = 250ms)
;    MIV 45455, Z1                       ; SD_MAX_READ_ATTEMPTS 250ms -> 250 / 0,0055 = 45455
;SD_writeSingleBlock1:
;    MIB 0xff,spi NOP LDB spi            ; 6 + 16 + 5 = 27 (52)
;    CPI 0xff                            ; 3
;    BNE SD_writeSingleBlock2            ; 4/3 -> 3 (Answer is there)
;    DEV Z1                              ; 7
;    BNE SD_writeSingleBlock1            ; 4/3 -> 4 + 7 + 3 + 3 + 27 = 44 * 0,125µs = 5,5 µs
;    CZZ Z1, Z1+1
;    BNE SD_writeSingleBlock1
;    ; time exceeded
;    LDI 0xff STB buffer+0
;    JPA SD_writeSingleBlockE
;
;SD_writeSingleBlock2:
;    ANI 0x1f CPI 0x05                   ; if data accepted
;    STB token
;    BNE SD_writeSingleBlockE            ; no
;
;    ; wait for a response (timeout = 250ms), data accepted wait for write to finish
;    MIV 45455, Z1                       ; SD_MAX_READ_ATTEMPTS 250ms -> 250 / 0,0055 = 45455
;SD_writeSingleBlock4:
;    MIB 0xff,spi NOP LDB spi            ; 6 + 16 + 5 = 27
;    CPI 0x00                            ; 3
;    BNE SD_writeSingleBlock5            ; 4/3 -> 3 (Answer is there)
;    DEV Z1                              ; 7
;    BNE SD_writeSingleBlock4            ; 4/3 -> 4 + 7 + 3 + 3 + 27 = 44 * 0,125µs = 5,5 µs
;    CZZ Z1, Z1+1
;    BNE SD_writeSingleBlock4
;    LDI 0x00 STB token                  ; busy timeout
;    JPA SD_writeSingleBlockE
;SD_writeSingleBlock5:
;SD_writeSingleBlockE:
;    PHS
;    MIB 0xff,spi NOP
;    LDI 0x00 STB cs1
;    MIB 0xff,spi NOP
;    PLS
;
;    RTS
; ----------------------------------------------
; |            End writeSingleBlock            |
; ----------------------------------------------

; ----------------------------------------------
; |              Begin Readsector              |
; ----------------------------------------------
; Input: zp_sd_currentsector = Sectornumber
;        zp_sd_address = Pointer to 512 byte data buffer
; Return:
; token = 0xFE - Successful read
; token = 0x0X - Data error
; token = 0xFF - timeout

sd_readsector:
	;; debug ####
	;JPS _Print "Read Sector: ",0
    ;LDZ zp_sd_currentsector+3 JAS _PrintHex
    ;LDZ zp_sd_currentsector+2 JAS _PrintHex
    ;LDZ zp_sd_currentsector+1 JAS _PrintHex
    ;LDZ zp_sd_currentsector+0 JAS _PrintHex
	;;JPS _WaitInput
	;JPS _Print 10,0
	;; debug end
	
    MIB 0xff,token                      ; token = 0xff
	JPS cs1on
    JPS SD_CMD17                        ; send CMD17
    JPS SD_readRes1                     ; read result
    CPI 0xff
    BEQ SD_readSingleBlockErr1          ; no result end
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
	MVV zp_sd_address,save
SD_readSingleBlock3:
    MIB 0xff,spi NOP LDB spi
    STT zp_sd_address
    INV zp_sd_address DEV Z1
    BNE SD_readSingleBlock3
    CZZ Z1, Z1+1
    BNE SD_readSingleBlock3
	MVV save,zp_sd_address

    MIB 0xff,spi NOP                    ; read 16-bit CRC
    LDB spi STB crc16+1
    MIB 0xff,spi NOP
    LDB spi STB crc16+0

    LDB buffer+0                        ; return value
SD_readSingleBlockE:
    PHS JPS cs1off PLS
    RTS
SD_readSingleBlockErr1:
	PHS JAS _PrintHex JPS _Print " CMD17 Error", 10, 0 PLS
	JPA SD_readSingleBlockE
; ----------------------------------------------
; |                End Readsector              |
; ----------------------------------------------
; ----------------------------------------------
; |           Begin Init SPI SD Card           |
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
    LDB buffer+4 CPI 0xaa
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
; |            End Init SPI SD Card            |
; ----------------------------------------------
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
    MIV cmd0,zp_sd_address JPA SD_command
SD_CMD8:
    MIV cmd8,zp_sd_address JPA SD_command
SD_CMD58:
    MIV cmd58,zp_sd_address JPA SD_command
SD_CMD55:
    MIV cmd55,zp_sd_address JPA SD_command
SD_ACMD41:
    MIV ACMD41,zp_sd_address JPA SD_command
SD_CMD16:
    MIV cmd16,zp_sd_address JPA SD_command
; ----------------------------------------------
; *zp_sd_address Command 6 byte (1 byte CMD, 4 byte Argument, 1 byte CRC)
SD_command:
    MIZ 6, Z0
sCMD1:
    LDT zp_sd_address
    STB spi NOP
    INV zp_sd_address
    DEZ Z0
    BNE sCMD1
    RTS
; ----------------------------------------------
SD_CMD17:
    MIB 0x51,spi NOP
    ; Sector Number
    LDZ zp_sd_currentsector+3 STB spi NOP
    LDZ zp_sd_currentsector+2 STB spi NOP
    LDZ zp_sd_currentsector+1 STB spi NOP
    LDZ zp_sd_currentsector+0 STB spi NOP
    MIB 0x01,spi NOP
    RTS
; ----------------------------------------------
SD_CMD24:
    MIB 0x58,spi NOP
    ; Sector Number
    LDB zp_sd_currentsector+3 STB spi NOP
    LDB zp_sd_currentsector+2 STB spi NOP
    LDB zp_sd_currentsector+1 STB spi NOP
    LDB zp_sd_currentsector+0 STB spi NOP
    MIB 0x01,spi NOP
    RTS
; ----------------------------------------------
SD_goIdleState:
	JPS cs1on
    JPS SD_CMD0
    JPS SD_readRes1
	JPS cs1off
    RTS
; ----------------------------------------------
; CMD55 initiates an application-specific command
SD_sendApp:
	JPS cs1on
    JPS SD_CMD55
    JPS SD_readRes1
	JPS cs1off
    RTS
; ----------------------------------------------
; ACMD41 - SD_SEND_OP_COND (send operating condition)
SD_sendOpCond:
	JPS cs1on
    JPS SD_ACMD41
    JPS SD_readRes1
	JPS cs1off
    RTS
; ----------------------------------------------
; CMD58 - read OCR (operation conditions register)
SD_readOCR:
	JPS cs1on
    JPS SD_CMD58
    JPS SD_readRes7
	JPS cs1off
    RTS
; ----------------------------------------------
; CMD8 - SEND_IF_COND (send interface condition)
SD_sendIfCond:
	JPS cs1on
    JPS SD_CMD8
    JPS SD_readRes7
	JPS cs1off
    RTS
; ----------------------------------------------
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
; ----------------------------------------------
;printBuf:
;    MIV buffer, zp_sd_address
;    MIZ 5, Z0
;    JPS _Print " read: ", 0
;pBuf1:
;    LDT zp_sd_address JAS _PrintHex
;    INV zp_sd_address
;    DEZ Z0
;    BNE pBuf1
;    JPS _Print 10, 0
;    RTS
; ----------------------------------------------
; SD_printR1:
;     LDB buffer+0
;     PHS
;     JAS _PrintHex
;     JPS _Print 10, 0
;     PLS
;     CPI 0x00
;     BNE SD_printR1a
;     JPS _Print " Card Ready", 10, 0
;     RTS
; SD_printR1a:
;     PHS
;     ANI 0x80 CPI 0x00
;     PLS
;     BEQ SD_printR1b
;     JPS _Print " Error: MSB = 1", 10, 0
;     RTS
; SD_printR1b:
;     PHS
;     ANI 0x40 CPI 0x00
;     PLS
;     BEQ SD_printR1c
;     JPS _Print " Parameter Error", 10, 0
; SD_printR1c:
;     PHS
;     ANI 0x20 CPI 0x00
;     PLS
;     BEQ SD_printR1d
;     JPS _Print " Address Error", 10, 0
; SD_printR1d:
;     PHS
;     ANI 0x10 CPI 0x00
;     PLS
;     BEQ SD_printR1e
;     JPS _Print " Erase Sequence Error", 10, 0
; SD_printR1e:
;     PHS
;     ANI 0x08 CPI 0x00
;     PLS
;     BEQ SD_printR1f
;     JPS _Print " CRC Error", 10, 0
; SD_printR1f:
;     PHS
;     ANI 0x04 CPI 0x00
;     PLS
;     BEQ SD_printR1g
;     JPS _Print " Illegal Command", 10, 0
; SD_printR1g:
;     PHS
;     ANI 0x02 CPI 0x00
;     PLS
;     BEQ SD_printR1h
;     JPS _Print " Erase Reset Error", 10, 0
; SD_printR1h:
;     ANI 0x01 CPI 0x00
;     BEQ SD_printR1i
;     JPS _Print " In Idle State", 10, 0
; SD_printR1i:
;     RTS
; ; ----------------------------------------------
; printR3:
;     JPS SD_printR1
;     LDB buffer+0 ANI 0xfe CPI 0x00
;     BEQ printR3a
;     RTS
; printR3a:
;     JPS _Print " Card Power Up Status: ", 0
;     LDB buffer+1 ANI 0x40 CPI 0x00
;     BEQ printR3b
;     JPS _Print "READY", 10, 0
;     JPA printR3c
; printR3b:
;     JPS _Print "BUSY", 10, 0
; printR3c:
;     JPS _Print " VDD Window: ", 0
;     LDB buffer+3 ANI 0x80 CPI 0x00
;     BEQ printR3d
;     JPS _Print "2.7-2.8, ", 0
; printR3d:
;     LDB buffer+2 ANI 0x01 CPI 0x00
;     BEQ printR3e
;     JPS _Print "2.8-2.9, ", 0
; printR3e:
;     LDB buffer+2 ANI 0x02 CPI 0x00
;     BEQ printR3f
;     JPS _Print "2.9-3.0, ", 0
; printR3f:
;     LDB buffer+2 ANI 0x04 CPI 0x00
;     BEQ printR3g
;     JPS _Print "3.0-3.1, ", 0
; printR3g:
;     LDB buffer+2 ANI 0x10 CPI 0x00
;     BEQ printR3h
;     JPS _Print "3.1-3.2, ", 0
; printR3h:
;     LDB buffer+2 ANI 0x20 CPI 0x00
;     BEQ printR3i
;     JPS _Print "3.2-3.3, ", 0
; printR3i:
;     LDB buffer+2 ANI 0x40 CPI 0x00
;     BEQ printR3j
;     JPS _Print "3.3-3.4, ", 0
; printR3j:
;     LDB buffer+2 ANI 0x40 CPI 0x00
;     BEQ printR3k
;     JPS _Print "3.5-3.6, ", 0
; printR3k:
;     JPS _Print 10, 0
;     RTS
; ; ----------------------------------------------
; SD_printR7:
;     JPS SD_printR1
;     LDB buffer+0 ANI 0xfe CPI 0x00
;     BEQ SD_printR7a
;     RTS
; SD_printR7a:
;     JPS _Print " Command Version: ", 0
;     LDB buffer+1 LL4 JAS _PrintHex JPS _Print 10, 0
;     JPS _Print " Voltage Accepted: ", 0
;     LDB buffer+3 ANI 0x1f
;     CPI 0x01
;     BNE SD_printR7b
;     JPS _Print "2.7-3.6V", 10, 0
;     JPA SD_printR7f
; SD_printR7b:
;     CPI 0x02
;     BNE SD_printR7c
;     JPS _Print "LOW VOLTAGE", 10, 0
;     JPA SD_printR7f
; SD_printR7c:
;     CPI 0x04
;     BNE SD_printR7d
;     JPS _Print "RESERVED", 10, 0
;     JPA SD_printR7f
; SD_printR7d:
;     CPI 0x08
;     BNE SD_printR7e
;     JPS _Print "RESERVED", 10, 0
;     JPA SD_printR7f
; SD_printR7e:
;     JPS _Print "NOT DEFINED", 10, 0
; SD_printR7f:
;     JPS _Print " Echo: ", 0
;     LDB buffer+4 JAS _PrintHex JPS _Print 10, 0
;     RTS

; ----------------------------------------------
; buffer for writing and reading commands from the SD card
buffer: 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
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

fat32_fatstart: 0x00, 0x00, 0x00, 0x00			; 4 bytes
fat32_datastart: 0x00, 0x00, 0x00, 0x00     	; 4 bytes
fat32_rootcluster: 0x00, 0x00, 0x00, 0x00   	; 4 bytes
fat32_sectorspercluster: 0x00 					; 1 byte
fat32_pendingsectors: 0x00    					; 1 byte
fat32_address: 0x00, 0x00           			; 2 bytes
fat32_nextcluster: 0x00, 0x00, 0x00, 0x00   	; 4 bytes
fat32_errorstage:								; only used during initializatio
fat32_filenamepointer:							; only used when searching for a file
fat32_bytesremaining: 0x00, 0x00, 0x00, 0x00	; 4 bytes

#mute
#org 0x3000 sBuf:   ; 512
#org 0x3000 fat32_readbuffer:   ; 512
#org 0x3000 fat32_workspace:   ; 512
#org 0x8000 buffer2:

#org 0x0000
regA:   0x00,
regB:   0x00,
save:
RegX:   0x00,
RegY:   0x00,
Z0:     0x00,
Z1:     0x0000,
Z2:     0x00,
Z3:     0x00,
tmp:    0x00,


zp_sd_address: 0x00, 0x00						; 2 bytes
zp_sd_currentsector: 0x00, 0x00, 0x00, 0x00		; 4 bytes -> CMD17, CMD24
zp_h_address: 0x00, 0x00

;;#org 0xfe80 spi:    ; address for reading and writing the spi shift register, writing starts the beat
;;#org 0xfe90 cs1:    ; bit 0 = 1 -> /CS = 0 | bit 0 = 0 -> /CS = 1
#org 0xfee3 spi:    ; address for reading and writing the spi shift register, writing starts the beat
#org 0xfee2 cs1:    ; bit 0 = 1 -> /CS = 0 | bit 0 = 0 -> /CS = 1

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