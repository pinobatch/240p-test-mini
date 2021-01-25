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

.segment "ZEROPAGE"
tvSystem: .res 1     ; 0: MMC1
mapper_type: .res 1

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

;;
; Writes to the first byte of all four nametables and returns a
; bitfield where contains each 2-bit entry the lowest nametable ID
; where matches that nametable's value this one.
; @return Y = $FF, A = X = bitfield of distinct nametables
;    2C282420
;   %00000000 1-screen mirroring
;   %10100000 horizontal mirroring
;   %01000100 vertical mirroring
;   %01010100 L-shaped mirroring
;   %11100100 4-screen mirroring
;   %00010100 Diagonal mirroring
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
  
  ; If another vblank happened by 27 loops, we're on a PAL NES.
  ; Otherwise, we're on a Dendy (PAL famiclone).
  bmi have_tvSystem
    asl a
  have_tvSystem:
  sta tvSystem

  ; Now, with the PPU stable and in forced blank, can mapper
  ; detection begin.
  
  
  jmp main
.endproc
