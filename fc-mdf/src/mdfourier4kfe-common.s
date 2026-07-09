.include "nes.inc"
.include "global.inc"

; Aims to support use with mapper 0, 1, 2, 4, 7, or 218
; Mapper 7 is the most emulator compatible
MAPPERNUM = 7

; Rumor has it that PPU A13 passes through the audio inverter
; and can affect noise
MDF_PA13_HIGH = 1

test_good_phase := test_state+6

; FDS code and mapper configuration by Persune 2023
; with code from Brad Smith 2021
; https://github.com/bbbradsmith/NES-ca65-example/tree/fds

.ifdef FDSHEADER

  .segment "ZEROPAGE"
  coldboot_check: .res 1

  .segment "FDSHEADER"
  .byte 'F','D','S',$1A
  .byte 1 ; side count

  FILE_COUNT = 4 + 1

  YEAR  = $35 ; 2023 - 1988 (heisei era)
  MONTH = $12 ; december
  DATE  = $01 ; 1

  .segment "SIDE1A"
  ; block 1
  .byte $01
  .byte "*NINTENDO-HVC*"
  .byte $00 ; manufacturer
  .byte "240"
  .byte $20 ; normal disk
  .byte $00 ; game version
  .byte $00 ; side
  .byte $00 ; disk
  .byte $00 ; disk type
  .byte $00 ; unknown
  .byte FILE_COUNT ; boot file count
  .byte $FF,$FF,$FF,$FF,$FF
  .byte YEAR
  .byte MONTH
  .byte DATE
  .byte $49 ; country
  .byte $61, $00, $00, $02, $00, $00, $00, $00, $00 ; unknown
  .byte YEAR
  .byte MONTH
  .byte DATE
  .byte $00, $80 ; unknown
  .byte $00, $00 ; disk writer serial number
  .byte $07 ; unknown
  .byte $00 ; disk write count
  .byte $00 ; actual disk side
  .byte $00 ; unknown
  .byte $00 ; price
  ; block 2
  .byte $02
  .byte FILE_COUNT

  .segment "FILE0_HDR"
  ; block 3
  .import __FILE0_DAT_RUN__
  .import __FILE0_DAT_SIZE__
  .byte $03
  .byte 0,0
  .byte "FILE0..."
  .word __FILE0_DAT_RUN__
  .word __FILE0_DAT_SIZE__
  .byte 0 ; PRG

  ; block 4
  .byte $04
  ;.segment "FILE0_DAT"
  ;.incbin "" ; this is code below

  .segment "FILE1_HDR"
  ; block 3
  .import __FILE1_DAT_RUN__
  .import __FILE1_DAT_SIZE__
  .byte $03
  .byte 1,1
  .byte "FILE1..."
  .word __FILE1_DAT_RUN__
  .word __FILE1_DAT_SIZE__
  .byte 0 ; PRG
  ; block 4
  .byte $04
  ;.segment "FILE1_DAT"
  ;.incbin "" ; this is code below

  .segment "FILE2_HDR"
  ; block 3
  .import __FILE2_DAT_SIZE__
  .import __FILE2_DAT_RUN__
  .byte $03
  .byte 2,2
  .byte "FILE2..."
  .word __FILE2_DAT_RUN__
  .word __FILE2_DAT_SIZE__
  .byte 1 ; CHR
  ; block 4
  .byte $04
  .segment "FILE2_DAT"
  .incbin "obj/nes/mdf4k_chr.chr"

  ; This block is the last to load, and enables NMI by "loading" the NMI enable value
  ; directly into the PPU control register at $2000.
  ; While the disk loader continues searching for one more boot file,
  ; eventually an NMI fires, allowing us to take control of the CPU before the
  ; license screen is displayed.
  .segment "FILE3_HDR"
  ; block 3
  .import __FILE3_DAT_SIZE__
  .import __FILE3_DAT_RUN__
  .byte $03
  .byte 4,4
  .byte "FILE3..."
  .word $2000
  .word __FILE3_DAT_SIZE__
  .byte 0 ; PRG (CPU:$2000)
  ; block 4
  .byte $04
  .segment "FILE3_DAT"
  .byte $90 ; enable NMI byte sent to $2000

  ; FDS vectors
  .segment "FILE1_DAT"
  .word nmi_handler
  .word nmi_handler
  .word bypass

  .word reset_handler
  .word irq_handler

  .segment "FILE0_DAT"
  ; this routine is entered by interrupting the last boot file load
  ; by forcing an NMI not expected by the BIOS, allowing the license
  ; screen to be skipped entirely.
  ;
  ; The last file writes $90 to $2000, enabling NMI during the file load.
  ; The "extra" file in the FILE_COUNT causes the disk to keep seeking
  ; past the last file, giving enough delay for an NMI to fire and interrupt
  ; the process.
  bypass:
    ; disable NMI
    lda #0
    sta $2000
    ; replace NMI 3 "bypass" vector at $DFFA
    lda #<nmi_handler
    sta $DFFA
    lda #>nmi_handler
    sta $DFFB
    ; tell the FDS reset routine that the BIOS initialized correctly
    lda #$35
    sta $0102
    lda #$AC
    sta $0103
    ; we can't use $0103 for cold boot check because this routine clobbers it
    lda #1
    sta coldboot_check
    ; reset the FDS to begin our program properly
    jmp ($FFFC)

.else

  .segment "INESHDR"
  .if MAPPERNUM = 218
    MIRRORING = 9
  .else
    MIRRORING = 1
  .endif
  .ifdef CHRROM
    CHRBANKS = 1
  .else
    CHRBANKS = 0
  .endif

  .byte "NES", $1A, 1, CHRBANKS
  .byte (MAPPERNUM << 4) & $F0 | MIRRORING
  .byte MAPPERNUM & $F0

  ; Space for you to patch in whatever initialization your mapper needs
  .segment "STUB15"
  stub15start:
  .repeat 96 - 9
    nop
  .endrepeat
  jmp reset_handler
  .addr nmi_handler, stub15start, irq_handler
  .assert *-stub15start = 96, error, "mapper init area not 96 bytes!"

  .ifdef CHRROM
  .segment "CHR"
  .else
  .rodata
  .endif
  chrdata: .incbin "obj/nes/mdf4k_chr.chr"
  chrdata_end:
.endif

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.rodata
.endif
uipalette: .byte $0F, $20, $0F, $20, $0F, $0F, $10, $10
uipalette_end:

warmbootsig: .byte "MDF", 0
WARMBOOTSIGLEN = * - warmbootsig

.segment "ZEROPAGE"
nmis: .res 1
cur_keys: .res 2
new_keys: .res 2
test_state: .res SIZEOF_TEST_STATE

.segment "BSS"
; Default crt0 clears ZP but not BSS
; Currently used only by multicarts
is_warm_boot:  .res WARMBOOTSIGLEN
mdfourier_good_phase: .res 1

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.code
.endif
; Bare minimum NMI handler allows sync to vblank in a 6-cycle window
; using a CMP/BEQ loop.  Even if the NMI handler isn't this trivial,
; the sync can't be improved by much because 6-cycle instructions
; such as JSR aaaa or STA (dd),Y aren't interruptible.
nmi_handler:
  inc nmis
irq_handler:
  rti

.proc reset_handler
.ifdef FDSHEADER
	; set FDS to use vertical mirroring
	lda $FA
	and #%11110111
	sta $4025
.endif
  sei
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  bit $4015  ; ack some IRQs
  lda #$40
  sta $4017  ; disable frame counter IRQ

.ifndef FDSHEADER
  bit PPUSTATUS  ; ack vblank NMI
  vwait1:
    bit PPUSTATUS  ; wait for first warmup vblank
    bpl vwait1
.endif

  txa
  :
    sta $00,x  ; clear zero page
.ifdef FDSHEADER
    inx
    cpx #$10
    bne :+
    inx
:		cpx #$F9 ; $F9-FF used by FDS BIOS
		bcc :--

    ; also clear FDS RAM
		WIPE_ADDR = __FILE0_DAT_RUN__ + __FILE0_DAT_SIZE__
		WIPE_SIZE = __FILE1_DAT_RUN__ - WIPE_ADDR
		lda #<WIPE_ADDR
		sta $00
		lda #>WIPE_ADDR
		sta $01
		lda #$FF
		tay
		ldx #>WIPE_SIZE
		beq :++
		: ; 256 byte blocks
			sta ($00), Y
			iny
			bne :-
			inc $01
			dex
			bne :-
		: ; leftover
		ldy #<WIPE_SIZE
		beq :++
		:
			dey
			sta ($00), Y
			bne :-
		:
		sta $00
		sta $01
.else
    inx
    bne :-
.endif

.ifndef FDSHEADER
  vwait2:
    bit PPUSTATUS  ; wait for second warmup vblank
    bpl vwait2
.endif


  ; Check for a warm boot
  lda #INITIAL_GOOD_PHASE
  sta mdfourier_good_phase

.if .defined(FDSHEADER) || ::IS_MULTICART
    ldy #0
    ldx #WARMBOOTSIGLEN - 1
    warmbootcheckloop:
      lda warmbootsig,x
      cmp is_warm_boot,x
      sta is_warm_boot,x
      beq :+
        iny
      :
      dex
      bpl warmbootcheckloop
    ; At this point, X=$FF, and Y=0 if warm boot.
    tya
    bne :+
      ; On a warm boot, phase is also good
      stx mdfourier_good_phase
    :
.endif
  lda #VBLANK_NMI
  sta PPUCTRL
  jsr mdfourier_ready_tone
  ; fall through
restart:
  jsr mdfourier_init_apu
  jsr mdfourier_push_apu
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  tay
  sta PPUMASK

.if .not(.defined(CHRROM) .or .defined(FDSHEADER))
  ; Copy tiles to CHR RAM
  sty PPUADDR
  sty PPUADDR
  lda #<chrdata
  sta $00
  lda #>chrdata
  sta $01
  ldx #>(chrdata_end-chrdata)
  :
    lda ($00),y
    sta PPUDATA
    iny
    bne :-
    inc $01
    dex
    bne :-
.endif

  ; Clear nametable
  lda #$20
  sta PPUADDR
  tya
  sta PPUADDR
  ldy #$FC
  jsr write_4y_of_a
  lda #$55
  ldy #4
  jsr write_4y_of_a
  
  ; Write copyright notice at very bottom of title safe area
  ; $2343 = (24, 208)
  lda #$23
  sta PPUADDR
  lda #$43
  sta PPUADDR
  ldx #1
  ldy #27
  jsr write_x_thru_xpym1
  
  ; Write title
  lda #$21
  sta PPUADDR
  lda #$03
  sta PPUADDR
  ldx #1
  ldy #17
  jsr write_x_thru_xpym1

  ; Write triangle phase
  lda #$21
  sta PPUADDR
  lda #$43
  sta PPUADDR
  ldy #2  ; Width of triangle wave icon
  jsr write_x_thru_xpym1
  ldy #2  ; Width of "OK" = 2
  lda mdfourier_good_phase
  bne have_phase_xy
  iny  ; Width of "Done" = 3
  ldx #22
  lda test_good_phase
  bne have_phase_xy
  iny  ; Width of "Trash" = 4
  ldx #25
have_phase_xy:
  jsr write_x_thru_xpym1

  ; Write palette and turn on display
  jsr vsync
  lda #$3F
  sta PPUADDR
  sty PPUADDR
  :
    lda uipalette,y
    sta PPUDATA
    iny
    cpy #uipalette_end-uipalette
    bne :-
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  sta PPUSCROLL
  sta PPUSCROLL
  lda #BG_ON
  sta PPUMASK

  ; Wait for A press
  keywait:
    jsr read_pads
    jsr vsync
    lda new_keys
    bpl keywait

  ; reduce interference from the PPU as far as we possibly can
  ldy #$3F
  lda #$00
  ldx #$0D
  sta PPUMASK
  sty PPUADDR
  sta PPUADDR
  stx PPUDATA
  sta PPUADDR
  sta PPUADDR

  .if ::MDF_PA13_HIGH
    ldx #$20
    stx PPUADDR
    sta PPUADDR
  .endif

  jsr mdfourier_run
  jmp restart
.endproc

.proc write_4y_of_a
  :
    .repeat 4
      sta PPUDATA
    .endrepeat
    dey
    bne :-
  rts
.endproc

.proc write_x_thru_xpym1
  :
    stx PPUDATA
    inx
    dey
    bne :-
  rts
.endproc

.proc mdfourier_present
  bit new_keys
  bvc no_B_press
    lda mdfourier_good_phase
    sta test_good_phase
    rts
  no_B_press:
  jsr vsync
  jsr mdfourier_push_apu
  jmp read_pads
.endproc

.proc vsync
  lda nmis
  :
    cmp nmis
    beq :-
  rts
.endproc
