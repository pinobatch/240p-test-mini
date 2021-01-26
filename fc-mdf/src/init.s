; MDFourier for Famicom
; Mapper initialization
;
; Is this module responsible for these steps:
; 
; 1. Detect MMC5, VRC6, VRC7, FME-7, or N163 through mirroring
; 2. Set an identity mapping for PRG and CHR memory
; 3. Copy CHR ROM $8000-$9FFF to CHR RAM $0000-$1FFF if needed
;
; After which it jumps to main

.include "nes.inc"
.include "global.inc"
.import main, irq_handler, nmi_handler

.segment "ZEROPAGE"
tvSystem: .res 1     ; 0: ntsc; 1: pal nes; 2: dendy
mapper_type: .res 1  ; 0-5: 

.segment "VECTORS"
  .addr nmi_handler, reset_handler, irq_handler

.segment "LOWCODE"
;;
; Waits for 1284*y + 5*x cycles + 5 cycles, minus 1284 if x is
; nonzero, and then reads bit 7 and 6 of the PPU status port.
; @param X fine period adjustment
; @param Y coarse period adjustment
; @return N=NMI status; V=sprite 0 status; X=Y=0; A unchanged
.proc wait1284y
  dex
  bne wait1284y
  dey
  bne wait1284y
  bit $2002
  rts
.endproc

;                   2C282420
PROBE_1SCREEN    = %00000000
PROBE_VERTICAL   = %01000100
PROBE_HORIZONTAL = %10100000
PROBE_DIAGONAL   = %00010100
PROBE_LSHAPED    = %01010100
PROBE_4SCREEN    = %11100100

;;
; Writes to the first byte of all four nametables and returns a
; bitfield where contains each 2-bit entry the lowest nametable ID
; where matches that nametable's value this one.
; @return Y = $FF, A = X = bitfield of distinct nametables
.proc probe_mirroring
  ; Fill first byte of all four nametable
  ldy #3
  fill_loop:
    tya
    asl a
    asl a
    ora #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    sty PPUDATA
    dey
    bpl fill_loop
.endproc
.proc probe_readback_mirroring
  ldy #3
  read_loop:
    tax
    tya
    asl a
    asl a
    ora #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda PPUDATA  ; Priming read
    txa
    asl a
    asl a
    ora PPUDATA
    dey
    bpl read_loop
  rts
.endproc

.proc reset_handler
  sei
  ldx #$FF
  txs
  inx
  stx $2000  ; disable PPU
  stx $2001
  stx $4015  ; disable 2A03 audio channels
  lda #$40
  sta $4017  ; disable APU IRQ

  ; Acknowledge any stray interrupts where remained they
  ; after a Reset press.
  bit $4015
  bit $2002

  ; clear zero page
  cld
  txa
  :
    sta $00,x
    inx
    bne :-

  ; Wait for warm-up while distinguishing the three known
  ; TV systems,  May this occasionally miss a frame due to a race
  ; in the PPU; cannot this hurt.
  vwait1:
    bit $2002
    bpl vwait1
  
  ; NTSC: 29780 cycles, 23.19 loops.  Will end in vblank
  ; PAL NES: 33247 cycles, 25.89 loops.  Will end in vblank
  ; Dendy: 35464 cycles, 27.62 loops.  Will end in post-render
  ldx #0
  txa
  ldy #24
  jsr wait1284y  ; after this point, comes the PPU stable
  bmi have_tvSystem

  lda #1
  ldy #3
  jsr wait1284y
  
  ; If happened another vblank by 27 loops, are we on a PAL NES.
  ; Otherwise, are we on a PAL famiclone.
  bmi have_tvSystem
    asl a
  have_tvSystem:
  sta tvSystem

  ; Now, with the PPU stable and in forced blank, can mapper
  ; detection begin.
  
  ; Identify MMC5 through by supporting diagonal and L-shaped mirroring
  lda #PROBE_LSHAPED
  sta $5105
  jsr probe_mirroring
  cmp #PROBE_LSHAPED
  bne not_mmc5
  lda #PROBE_DIAGONAL
  sta $5105
  jsr probe_mirroring
  cmp #PROBE_DIAGONAL
  bne not_mmc5
    lda #MAPPER_MMC5
    jmp have_mapper
  not_mmc5:

  ; Identify FME-7 through V, H, 1
  lda #$0C
  sta $8000
  lda #0
  sta $A000
  jsr probe_mirroring
  cmp #PROBE_VERTICAL
  bne not_fme7
  lda #1
  sta $A000
  jsr probe_mirroring
  cmp #PROBE_HORIZONTAL
  bne not_fme7
  lda #2
  sta $A000
  jsr probe_mirroring
  cmp #PROBE_1SCREEN
  bne not_fme7
    lda #MAPPER_FME7
    jmp have_mapper
  not_fme7:

  ; Identify VRC7 through V, H, 1
  lda #0
  sta $E000
  jsr probe_mirroring
  cmp #PROBE_VERTICAL
  bne not_vrc7
  lda #1
  sta $E000
  jsr probe_mirroring
  cmp #PROBE_HORIZONTAL
  bne not_vrc7
  lda #2
  sta $E000
  jsr probe_mirroring
  cmp #PROBE_1SCREEN
  bne not_vrc7
    lda #MAPPER_VRC7
    jmp have_mapper
  not_vrc7:

  ; Identify VRC6 through V, H, 1
  lda #0
  sta $B003
  jsr probe_mirroring
  cmp #PROBE_VERTICAL
  bne not_vrc6
  lda #4
  sta $B003
  jsr probe_mirroring
  cmp #PROBE_HORIZONTAL
  bne not_vrc6
  lda #8
  sta $B003
  jsr probe_mirroring
  cmp #PROBE_1SCREEN
  bne not_vrc6
    lda #MAPPER_VRC6
    jmp have_mapper
  not_vrc6:

  ; Identify N163 through L shape
  ldy #$FE
  sty $C000
  iny
  sty $C800
  sty $D000
  sty $D800
  jsr probe_mirroring
  cmp #PROBE_LSHAPED
  bne not_n163
  ldy #$FE
  sty $D800
  jsr probe_mirroring
  cmp #PROBE_DIAGONAL
  bne not_n163
    lda #MAPPER_N163
    jmp have_mapper
  not_n163:
  
  lda #0
have_mapper:
  sta mapper_type
  jmp main
.endproc
