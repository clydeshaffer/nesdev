	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 1

	.bank 0
	.org $0010
ColumnSrc:
	.ds 2
ColumnDest:
	.ds 2
ColumnRun:
	.ds 1
ColumnRLEPtr:
	.ds 2
	.org $0400 ; RAM section for non speed critical global vars
ScrollX:
	.ds 2
LoadedTo:
	.ds 2
WaitForRender:
	.ds 1
	.org $C000 ;code section start

RESET:
	SEI ; no interrupts
	CLD ; decimal mode off
LoadPalettes:
	LDA $2002 ;set up palette address
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006

	LDX #$00 ;set up X as iterator
LoadPalettesLoop:
	LDA PaletteData, x;
	STA $2007
	INX
	CPX #$20
	BNE LoadPalettesLoop ;;AKA for(x = 0; x < 20; x++)

	;;Enable the PPU NMI, sprites, background rendering
	LDA #%00000100	
	STA $2000
	LDA #%00011110
	STA $2001

	LDA #0
	STA ColumnRun
	LDA #LOW(MapCols)
	STA ColumnRLEPtr
	LDA #HIGH(MapCols)
	STA ColumnRLEPtr+1

	LDY #$0
	LDA [ColumnRLEPtr], y
	STA ColumnRun
	INY
	LDA [ColumnRLEPtr], y
	STA ColumnSrc
	INY
	LDA [ColumnRLEPtr], y
	STA ColumnSrc+1

	LDA #$00
	STA ColumnDest
	LDA #$20
	STA ColumnDest+1

	LDA #$20
	STA $00
FirstScreenLoop:
	JSR LoadNextColumn
	DEC $00
	BNE FirstScreenLoop

	LDA #0
	STA $2005
	STA $2005
	STA LoadedTo
	STA LoadedTo+1

	LDA #%10000100	
	STA $2000

FOREVER:
	LDA WaitForRender
	BNE SkipFrameUpdate
	LDA ScrollX
	CLC
	ADC #$01
	STA ScrollX
	LDA ScrollX+1
	ADC #$00
	STA ScrollX+1
	INC WaitForRender
SkipFrameUpdate:
	JMP FOREVER

NMI:
	PHA
	TXA
	PHA
	TYA
	PHA

CheckMoreCols:
	LDA ScrollX+1
	CMP LoadedTo+1
	BCC NoMoreCols
	BNE LoadMoreCols
	LDA LoadedTo
	CMP ScrollX
	BCC LoadMoreCols
	JMP NoMoreCols
LoadMoreCols:
	JSR LoadNextColumn
	JMP CheckMoreCols
NoMoreCols:
	LDA ScrollX+1
	AND #$03
	ORA #%10000100
	STA $2000
	LDA ScrollX
	STA $2005
	LDA #0
	STA $2005
	LDA #0
	STA WaitForRender

	PLA
	TAY
	PLA
	TAX
	PLA
	RTI

LoadNextColumn:
	JSR LoadSingleColumn
	LDA ColumnDest
	CLC
	ADC #$01
	STA ColumnDest
	CMP #$20
	BNE SkipColInc
	LDA #0
	STA ColumnDest
	LDA	ColumnDest+1
	EOR #$04
	STA ColumnDest+1
SkipColInc:
	DEC ColumnRun
	BNE ContinueColRun
	LDA ColumnRLEPtr
	CLC
	ADC #$03
	STA ColumnRLEPtr
	LDA ColumnRLEPtr+1
	ADC #$00
	STA ColumnRLEPtr+1
	LDY #0
	LDA [ColumnRLEPtr], y
	STA ColumnRun
	INY
	LDA [ColumnRLEPtr], y
	STA ColumnSrc
	INY
	LDA [ColumnRLEPtr], y
	STA ColumnSrc+1
ContinueColRun:
	LDA LoadedTo
	CLC
	ADC #$08
	STA LoadedTo
	LDA LoadedTo+1
	ADC #$00
	STA LoadedTo+1
	RTS

LoadSingleColumn:
	LDA $2002
	LDA ColumnDest+1
	STA $2006
	LDA ColumnDest
	STA $2006

	LDX #0
	LDY #0
NextRun:
	LDA [ColumnSrc], y
	BEQ ColumnDone
	TAX
	INY
	LDA [ColumnSrc], y
TileLoop:
	STA $2007
	DEX
	BNE TileLoop
	INY
	JMP NextRun
ColumnDone:
	RTS	



	; data section
	.bank 1
	.org $E000
ColumnLib:
	.db $1A, $00, $03, $30, $01, $00, $00
	.db $0F, $00, $01, $30, $0A, $00, $03, $30, $01, $00, $00
PaletteData:
	.incbin "pal.dat"

Demux:
	.db $1, $2, $4, $8, $10, $20, $40, $80

MapCols:
	.db $0E, $00, $E0
	.db $02, $07, $E0
	.db $04, $00, $E0
	.db $05, $07, $E0
	.db $FF, $00, $E0
	.db $FF, $07, $E0

	; set up interrupt handlers
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	; CHR ROM
	.bank 2
	.org $0000
	.incbin "graphics.chr"