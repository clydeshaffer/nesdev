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


	JSR ClearColMap

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
;;also uses $02, $03,$04,$05 as local var
LoadRLETiles:
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00 ; start at the first tile row
	STA $2006

	STA $04 ; initialize collision byte and bit counters
	STA $05

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
	STA $2007 ;;put the current byte into the PPU
	STA $02 ;;put that byte aside for a moment
	;;stow the A, X and Y registers
	PHA
	TXA 
	PHA
	TYA 
	PHA

	LDY $02
	TYA
	AND #$07
	TAY
	LDX Demux, y
	STX $03 ;;now $03 is the bitmask
	LDA $02
	LSR a
	LSR a
	LSR a
	TAY
	LDA TileCollisions, y
	AND $03 ;;zero if no collision on this tile
	BEQ RLENoCol
	LDY $05
	LDX Demux, y
	TXA
	LDX $04
	ORA CollisionMap, x
	STA CollisionMap, x
RLENoCol:
	INC $05
	LDA $05
	AND #$07
	STA $05
	BNE IncColByte
	INC $04 ;increment col byte counter only when bit counter cycles to zero
IncColByte:
	;;restore the X and Y registers
	PLA
	TAY
	PLA
	TAX
	PLA
	;;decrement X and check if the run is done
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

ClearColMap:
	LDA #0
	LDX #$80
ClearColMapLoop:
	DEX
	STA CollisionMap, x
	BNE ClearColMapLoop
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

Demux:
	.db $1, $2, $4, $8, $10, $20, $40, $80

HelloWorld:
	.db $FF,$00,$FF,$00,$FF,$00,$03,$00,$A0,$30, $60, %00000000, $00
TileCollisions:
	.incbin "colmap.bin"
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	.bank 2
	.org $0000
	.incbin "graphics.chr"