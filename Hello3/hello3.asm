	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 0

	.bank 0

;;$00 through $0F for local vars

	.org $0010
PlayerVelX:
	.db $00
PlayerVelY:
	.db $00
CollisionMap:
	.ds $80
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




	;;Set the parameters for LoadRLETiles then call it
	LDA #LOW(HelloWorld)
	STA $00
	LDA #HIGH(HelloWorld)
	STA $01
	JSR LoadRLETiles


	;;Reset scroll
	LDA #0
	STA $2005
	STA $2005

	;;Enable the PPU NMI, sprites, background rendering
	LDA #%10000000
	STA $2000
	LDA #%00011110
	STA $2001

	;;Set up the sprite for the guy
	;;I'm setting it up as sprite 1 in case I wanna use sprite 0 for scroll effects
	LDA #$80
	STA $0204
	STA $0207
	LDA #%00000010
	STA $0206
	LDA #$20
	STA $0205


Forever:
	JMP Forever

NMI:

	LDA #$00
	STA $2003
	LDA #02
	STA $4014
	RTI

;;;;;;;;;;;;;subroutines
;;Load a RLE-compressed tilemap from the address stored at $00 and $01
LoadRLETiles:
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00 ; start at the first tile row
	STA $2006
	LDX #$00 ; initialize index registers
	LDY #$00
NextRun:
	;at this point the byte at [$10], y should represent a Run Length
	LDA [$00], y
	BEQ DoneLoadingRLETiles ;run length is zero? we are done.
	TAX
	INY
	LDA [$00], y ;get the byte that we are repeating
RLELoop:
	STA $2007
	DEX
	BNE RLELoop
	INY
	BNE NextRun
	LDA $01
	CLC
	ADC #$01
	STA $01
	JMP NextRun
DoneLoadingRLETiles:
	RTS

;;Load collisions from RLE tilemap
LoadRLECollisions:
	RTS

;;;;Set the attribute table to some stuff I guess
SetAttributes:
	LDA $2002
	LDA #$23
	STA $2006
	LDA #$C0
	STA $2006
	LDX #$40
SetAttributesLoop:
	STX $2007
	DEX
	BNE SetAttributesLoop
	RTS


;;check pixel at ($00, $01)
CheckCollision:
	RTS

	.bank 1
	.org $E000 ;start putting stuff at E000 now in bank 1

PaletteData:
	.incbin "pal.dat"
	;.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
	;.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data

HelloWorld:
	.db $FF,$00,$FF,$00,$FF,$00,$03,$00,$A0,$30,$00
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	.bank 2
	.org $0000
	.incbin "graphics.chr"