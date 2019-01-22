	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 0

	.bank 0

;;$00 through $0F for local vars

	.org $0010
buttons:
	.ds 1
PlayerVelX:
	.ds 1
PlayerVelY:
	.ds 1
PlayerWalkTimer:
	.ds 1
PlayerGravTimer:
	.ds 1
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
	LDA #$78
	STA $0204
	STA $0207
	LDA #%00000010
	STA $0206
	LDA #$20
	STA $0205

	LDA #$01
	STA PlayerVelX
	LDA #$00
	STA PlayerVelY

Forever:
	JMP Forever

NMI:
	LDA #0
	STA PlayerVelX
	JSR ReadJoy
	LDA #$01
	BIT buttons
	BNE GoRight
	LDA #$02
	BIT buttons
	BNE GoLeft
	JMP InputDone
GoRight:
	INC PlayerVelX
	JMP InputDone
GoLeft:
	DEC PlayerVelX
InputDone:
	LDA PlayerVelX
	BEQ StandAnim
	BMI FlipPlayerSprite
	LDA $0206
	AND #%10111111
	JMP AfterFlipCheck
FlipPlayerSprite:
	LDA $0206
	ORA #%01000000
AfterFlipCheck:
	STA $0206
	INC PlayerWalkTimer
	LDA #$08
	AND PlayerWalkTimer
	LSR A
	LSR A
	LSR A
	CLC
	STA $00
	ADC #$21
	JMP DoneAnim
StandAnim:
	LDA #$04
	BIT buttons
	BNE CrouchAnim
	LDA #$20
	JMP DoneAnim
CrouchAnim:
	LDA #$23
DoneAnim:
	STA $0205

	LDA $0204
	STA $01
	LDA PlayerVelX
	BMI MovingLeft
	CLC
	ADC #$07
MovingLeft:
	CLC
	ADC $0207
	STA $00
	JSR CheckCollision
	BNE HHit
	CLC
	LDA $0204
	ADC #$07
	STA $01
	JSR CheckCollision
	BNE HHit
	;no hit occured, finalize horizontal move
	LDA $0207
	CLC
	ADC PlayerVelX
	STA $0207
HHit:
	
	LDA $0207
	STA $00
	LDA PlayerVelY
	BMI MovingUp
	CLC
	ADC #$07
MovingUp:
	CLC
	ADC $0204
	STA $01
	JSR CheckCollision
	BNE VHit
	CLC
	LDA $0207
	ADC #$07
	STA $00
	JSR CheckCollision
	BNE VHit
	LDA $0204
	CLC
	ADC PlayerVelY
	STA $0204
	LDA #$06
	CMP PlayerVelY
	BEQ NoVHit
	CLC
	LDA PlayerGravTimer
	ADC #$20
	STA PlayerGravTimer
	LDA PlayerVelY
	ADC #$00
	STA PlayerVelY
	JMP NoVHit
VHit:
	LDX #$0
	STX PlayerGravTimer
	LDA PlayerVelY
	BMI NoJump
	LDA #$80
	BIT buttons
	BEQ NoJump
	LDX #$FC
NoJump:
	STX PlayerVelY
NoVHit:

	DEC $0204

	LDA #$00
	STA $2003
	LDA #02
	STA $4014

	INC $0204
	RTI

;;;;;;;;;;;;;subroutines
;;Load a RLE-compressed tilemap from the address stored at $00 and $01
;;also uses $02, $03,$04,$05 as local var
current_byte = $04
current_bit = $05
LoadRLETiles:
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00 ; start at the first tile row
	STA $2006

	STA current_byte ; initialize collision byte and bit counters
	STA current_bit

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
	LDY current_bit
	LDX Demux, y
	TXA
	LDX current_byte
	ORA CollisionMap, x
	STA CollisionMap, x
RLENoCol:
	INC current_bit
	LDA current_bit
	AND #$07
	STA current_bit
	BNE IncColByte
	INC current_byte ;increment col byte counter only when bit counter cycles to zero
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
sprite_x = $00
sprite_y = $01
CheckCollision:
	LDA sprite_y
	LSR a
	AND #$FC
	STA $02
	LDA sprite_x
	LSR a
	LSR a
	LSR a
	LSR a
	LSR a
	LSR a
	ORA $02
	TAX
	LDA sprite_x
	LSR a
	LSR a
	LSR a
	AND #$07
	TAY
	LDA CollisionMap, x
	AND Demux, y
	;;zero flag set if no collision
	RTS

JOYPAD1 = $4016
ReadJoy:
	LDA #$01
	STA JOYPAD1 ;set strobe bit on joypad
	STA buttons
	LSR a
	STA JOYPAD1 ;reset strobe bit on joypad, locking inputs in place
ReadJoyLoop:
	LDA JOYPAD1
	LSR A
	ROL buttons
	BCC ReadJoyLoop
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
	.db $FF,$00,$21,$00,$0C,$30,$45,$00,$03,$30,$80,$00,$03,$30,$9F,$00,$04,$30,$11,$00,$04,$30,$1A,$00,$06,$30,$18,$00,$08,$30,$11,$00,$0F,$30,$11,$00,$A0,$30,$00
	;.db $FF,$00,$FF,$00,$10,$30,$EF,$00,$A3,$30, $60, %00000000, $00
TileCollisions:
	.incbin "colmap.bin"
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	.bank 2
	.org $0000
	.incbin "graphics.chr"