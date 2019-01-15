	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 0

	.bank 0

	.org $C000 ;tell the assembler to start putting this stuff at $C000

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


LoadTiles:
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00 ; start at the first tile row
	STA $2006

	LDA #LOW(HelloWorld)
	STA $10
	LDA #HIGH(HelloWorld)
	STA $11
FILL:
	LDY #0
LoadTilesInnerLoop:
	LDA [$10], y
	BEQ DoneLoadingTiles ;we're done when we load a zero byte
	STA $2007
	INY
	BNE LoadTilesInnerLoop
	LDA $11
	CLC
	ADC #$01
	STA $11
	JMP FILL
DoneLoadingTiles:

SetAttributes:
	LDA $2002
	LDA #$23
	STA $2006
	LDA #$C0
	STA $2006
	LDX #$40
SetAttributesLoop:
	;STX $2007
	DEX
	BNE SetAttributesLoop

	LDA #0
	STA $2005
	STA $2005

	LDA #%10000000
	STA $2000

	LDA #%00011110
	STA $2001

	LDA #$80
	STA $30

Forever:
	JMP Forever

NMI:
	INC $30
	LDA #$00
	LDY #$00
WaveOuterLoop:
	LDX $30
WaveInnerLoop:
	INX
	BNE WaveInnerLoop
	STY $2005
	STY $2005
	INY
	BNE WaveOuterLoop
	RTI


	.bank 1
	.org $E000 ;start putting stuff at E000 now in bank 1

PaletteData:
	.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
	.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data

HelloWorld:
	.incbin "longlorem-nospace.dat"
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	.bank 2
	.org $0000
	.incbin "yychr2.chr"