	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 1

	.bank 0

jump_str = $FD
grav_str = $20

;;$00 through $0F for local vars

	.org $0010
buttons:
	.ds 1
oldbuttons:
	.ds 1
ScreenScrollX:
	.ds 2
PlayerVelX:
	.ds 1
PlayerVelY:
	.ds 1
PlayerWalkTimer:
	.ds 1
PlayerGravTimer:
	.ds 1

	.org $0400
WaitForFrame:
	.ds 1
CollisionMap:
	.ds $100
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
	LDA #$00
	STA nametable_offset
	JSR LoadRLETiles

	LDA #LOW(Map2)
	STA $00
	LDA #HIGH(Map2)
	STA $01
	LDA #$04
	STA nametable_offset
	JSR LoadRLETiles

	;;Reset scroll
	LDA ScreenScrollX
	STA $2005
	LDA #0
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
	LDA WaitForFrame
	BNE Forever

	LDA #0
	STA PlayerVelX
	JSR ReadJoy
	LDA oldbuttons
	EOR buttons
	STA oldbuttons
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
	LDA PlayerVelY
	BNE AirAnim
	LDA #$04
	BIT buttons
	BNE CrouchAnim
	LDA #$20
	JMP DoneAnim
CrouchAnim:
	LDA #$23
	JMP DoneAnim
AirAnim:
	LDA #$21
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
	CMP #$C0
	BCS FollowPlayer
	CMP #$40
	BCC FollowPlayer
	STA $0207
	JMP HHit
FollowPlayer:
	CLC
	LDA PlayerVelX
	BPL PosScroll
	DEC ScreenScrollX+1
PosScroll:
	ADC ScreenScrollX
	STA ScreenScrollX
	BCC ScrollNoc
	INC ScreenScrollX+1
ScrollNoc:

HHit:
	
	LDA $0207
	STA $00
	LDA PlayerVelY
	SEC
	BMI MovingUp
	BEQ ZeroYVel
	CLC
ZeroYVel:
	ADC #$07
MovingUp:
	CLC
	ADC $0204
	STA $01
	JSR CheckCollision
	BNE VHit
	CLC
	LDA $00
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
	ADC #grav_str
	STA PlayerGravTimer
	LDA PlayerVelY
	ADC #$00
	STA PlayerVelY
	JMP NoVHit
VHit:	
	LDX #$0
	LDY #$FF
	LDA PlayerVelY
	BMI NoJump
	LDA #$80
	AND oldbuttons
	BIT buttons
	BEQ NoJump
	LDX #jump_str
	LDY #$0
NoJump:
	STY PlayerGravTimer
	STX PlayerVelY
NoVHit:
	INC WaitForFrame

	JMP Forever

NMI:
	PHA
	TXA 
	PHA
	TYA 
	PHA

	LDA ScreenScrollX+1
	AND #$01
	ORA #%10000000
	STA $2000

	DEC $0204

	LDA #$00
	STA $2003
	LDA #02
	STA $4014

	INC $0204

	LDA buttons
	STA oldbuttons

	LDA ScreenScrollX
	STA $2005
	LDA #0
	STA $2005

	STA WaitForFrame

	PLA
	TAY
	PLA
	TAX
	PLA

	RTI

;;;;;;;;;;;;;subroutines
;;Load a RLE-compressed tilemap from the address stored at $00 and $01
;;also uses $02, $03,$04,$05,$06 as local var
current_byte = $04
current_bit = $05
nametable_offset = $06
LoadRLETiles:
	LDA $2002
	LDA nametable_offset
	ORA #$20
	STA $2006
	LDA #$00 ; start at the first tile row
	STA $2006

	STA current_bit

	LDX #$00
	LDA nametable_offset
	BEQ FirstColMap
	LDX #$80
FirstColMap:
	STX current_byte ; initialize collision byte and bit counters

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
	LDX #$00
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
	LDA #$00
	STA $04
	LDA sprite_y
	LSR a
	AND #$FC
	STA $02
	LDA sprite_x
	CLC
	ADC ScreenScrollX
	BCC ColFirstTable
	LDX #$80
	STX $04
ColFirstTable:
	LSR a
	LSR a
	LSR a
	LSR a
	LSR a
	LSR a
	ORA $02
	ORA $04
	STA $03
	LDA ScreenScrollX+1
	AND #$01
	BEQ ColSkipFlip
	LDA $03
	EOR #$80
	STA $03
ColSkipFlip:
	LDX $03
	LDA sprite_x
	CLC
	ADC ScreenScrollX
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
	.db $4D,$00,$01,$09,$01,$06,$02,$0D,$01,$10,$1B,$00,$01,$18,$01,$10,$01,$13,$01,$0D,$01,$05,$AE,$00,$0C,$30,$12,$00,$02,$30,$31,$00,$03,$30,$80,$00,$03,$30,$9F,$00,$04,$30,$11,$00,$04,$30,$1A,$00,$06,$30,$18,$00,$08,$30,$16,$00,$0A,$30,$11,$00,$A0,$30,$00
	;.db $FF,$00,$FF,$00,$10,$30,$EF,$00,$A3,$30, $60, %00000000, $00
Map2:
	;.db $FF,$00,$21,$00,$03,$30,$01,$00,$01,$30,$01,$00,$01,$30,$01,$00,$02,$30,$02,$00,$03,$30,$02,$00,$02,$30,$01,$00,$01,$30,$01,$00,$01,$30,$01,$00,$08,$30,$FF,$00,$E1,$00,$0A,$30,$09,$00,$18,$30,$02,$00,$01,$11,$01,$0A,$01,$15,$02,$00,$6E,$30,$00
	.db $03,$00,$01,$30,$0A,$00,$02,$31,$13,$00,$01,$30,$05,$00,$12,$31,$08,$00,$05,$30,$1A,$00,$05,$30,$1C,$00,$0D,$30,$88,$00,$05,$30,$03,$00,$0F,$30,$02,$31,$02,$30,$02,$31,$02,$30,$01,$1C,$04,$00,$04,$30,$0A,$00,$01,$18,$01,$02,$01,$15,$01,$04,$01,$09,$01,$15,$01,$09,$01,$06,$01,$08,$01,$02,$01,$11,$01,$18,$01,$02,$01,$15,$01,$04,$01,$09,$01,$15,$01,$09,$01,$06,$01,$08,$01,$02,$01,$11,$FF,$00,$05,$00,$02,$31,$1E,$00,$0A,$31,$16,$00,$10,$31,$10,$00,$0A,$31,$02,$00,$04,$31,$01,$30,$0E,$00,$11,$31,$01,$30,$0E,$00,$01,$31,$04,$00,$06,$31,$01,$00,$01,$31,$02,$00,$02,$31,$01,$30,$0B,$00,$01,$30,$01,$00,$02,$31,$0B,$00,$01,$31,$02,$00,$03,$30,$07,$00,$07,$30,$09,$00,$08,$31,$02,$30,$06,$00,$08,$30,$09,$31,$03,$30,$05,$31,$36,$30,$04,$31,$11,$30,$00
TileCollisions:
	.incbin "colmap.bin"
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	.bank 2
	.org $0000
	.incbin "graphics.chr"