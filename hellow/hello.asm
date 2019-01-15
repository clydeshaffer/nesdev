	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 0

	.bank 0

	.org $0000
MYVAR:
	.db $00
	.org $C000 ;tell the assembler to start putting this stuff at $C000

RESET:
	SEI ; no interrupts
	CLD ; decimal mode off

LoadPalettes:

	;0x2000 is a set of PPU control flags
	;0x2001 is a set of PPU rendering flags
	;0x2002 is PPU status register
	;0x2006 is PPU address register (alternates high/low byte on access)
	;0x2007 is PPU data register

	LDA $2002 ; trigger a read cycle on PPU status. at absolute address 0x2002. status byte loaded into register A
	; we want to set the two bytes of the address register, first low then high
	; reading the PPU status sets the high/low flag on the PPU to high

	LDA #$3F ; # means immediate value not memory location. so 0x3F is now loaded into register A
	STA $2006 ; contents of register A (0x3F) written to address 0x2006, saved as the high byte of the PPU address register
	; storing data at $2006 flips the high/low flag of the PPU, the next byte written will become the LOW byte of the PPU address reg

	LDA #$00 ; store zero in register A
	STA $2006 ; copy register A contents into LOW byte of PPU address register

	;we are now ready to begin writing the palette data


	LDX #$00 ; prepare to loop, use register X as iteration index

LoadPalettesLoop:
	LDA PaletteData, x ; PaletteData is address label, "PaletteData, x" address adds register x to address label to get a byte at PaletteData+x
	STA $2007 ; write register A (the palette byte) to the PPU data register. PPU address register will increment.
	INX ; increment register x
	CPX #$20 ; Compare register X to 0x20
	BNE LoadPalettesLoop ; check comparison flag set by previous instruction. if not equal then jump to label LoadPalettesLoop


; SPRITES NOTES
; Sprites are stored in the PPU as a 4-byte struct. {Y Pos, Tile Number, Attributes, X Pos}
; Tile number is an index into _____
; Attributes contains two bits for flipping the sprite, priority vs the background, and color palette index
; 64 sprites can be stored in the PPU memory at a time, as an array of consecutive 4-byte entries starting at 0x0200 (in Object Attribute Memory, accessed through system address $2004 or bulk written through $4014)

;	LDX #$00
;	LDY #$00
;LoadTextLoop:
	;TXA
	;ADC #$70
	;STA $0200, y
	;INY
	;LDA HelloWorld, x
	;STA $0200, y
	;INY
	;LDA #$00
	;STA $0200, y
	;INY
	;TXA
	;ASL A
	;ASL A
	;ASL A
	;ADC #$20
	;STA $0200, y
	;INY
	;INX
	;LDA HelloWorld, x
	;CMP #$00;
	;BNE LoadTextLoop


	LDA $2002
	LDA #$20
	STA $2006
	LDA #$20
	STA $2006 ; now we've stored the start of nametable space as the PPU address
	LDX #$00	
LoadTextBG:
	LDA HelloWorld, x
	CMP #$00
	BEQ DoneLoadingText
	STA $2007
	INX
	JMP LoadTextBG
DoneLoadingText:

	LDA $2002
	LDA #$00
	STA $2005
	STA $2005

	LDA #%10000000 ; % indicates a binary number
	STA $2000 ; setting the highest bit of the PPU status causes it to trigger a non maskable interupt at the start of VBLANK
	; it also seems we are using 8x8 sprites, background pattern table 0,  sprite pattern table 0, incrementing VRAM address by 1, and using nametable addresses from $2000

	LDA #%00011110 ; bit 7 intensifies blues, bit 4 enables sprite rendering
	STA $2001 ; store register A into the PPU rendering bitmask

Forever:
	JMP Forever ; don't do anything until NMI happens, I guess...

NMI:
	;this will get run when VBLANK happens
	;LDX $0203 ;;lets try grabbing the X coordinate, incrementing it, and putting it back
	;INX
	;STX $0203 ;; tee hee hee

	;LDA #$00
	;STA $2003
	;LDA #$02
	;STA $4014 ; set high byte of PPU address register BUT ALSO trigger a copy process from RAM to OAM RAM for 256 bytes
	; OAM is object attribute memory, where sprite data lives

	LDX MYVAR
	INX
	STX $2005
	STX MYVAR
	LDA #$00
	STA $2005

	RTI ; ReTurn from Interrupt

	.bank 1
	.org $E000 ;start putting stuff at E000 now in bank 1

PaletteData:
	.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
	.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data

HelloWorld:
	;.db $09, $06, $0D, $0D, $10, $01, $18, $10, $13, $0D, $05, $1C, $00; spells out hello world!. null terminated.
	;;.db $4, $0D, $1A, $5, $6, $01, $14, $9, $2, $7, $7, $6, $13, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $18, $16, $1B, $01, $9, $6, $13, $6, $00
	;;how about some lorem ipsum
	;;.incbin "lorem.dat"
	;or a quick fox
	.db $15, $09, $06, $01, $12, $16, $0A, $04, $0C, $01, $03, $13, $10, $18, $0F, $01, $07, $10, $19, $01, $0B, $16, $0E, $11, $14, $01, $01, $01, $01, $01, $01, $01, $10, $17, $06, $13, $01, $15, $09, $06, $01, $0D, $02, $1B, $1A, $01, $05, $10, $08, $00
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0

	.bank 2
	.org $0000
	.incbin "yychr2.chr"