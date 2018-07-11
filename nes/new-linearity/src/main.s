.include "nes.inc"
.include "global.inc"

OAM = $0200

.zeropage
nmis: .res 1

.code

.proc main
  ; set palette to know it booted
  lda #$3F
  sta PPUADDR
  ldx #$00
  stx PPUADDR
  lda #$2A
  sta PPUDATA
  stx PPUDATA
  stx PPUDATA
  lda #$30
  sta PPUDATA

  ; load tiles
  lda #$55
  ldy #$55
  ldx #$00
  jsr ppu_clear_nt

  ; load tilemap
  lda #$00
  ldy #$00
  ldx #$24
  jsr ppu_clear_nt
  ldx #$00
  ldy #$00
  lda #VBLANK_NMI|BG_0000
  jsr ppu_screen_on
forever:
  jmp forever
.endproc
