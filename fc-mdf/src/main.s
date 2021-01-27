.include "nes.inc"
.include "global.inc"
.export main, irq_handler

.segment "LOWCODE"

.proc irq_handler
  rti
.endproc

.code

.proc main
  lda #VBLANK_NMI
  sta PPUCTRL
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda mapper_type
  asl a
  beq :+
    ora #$10
  :
  sta PPUDATA
  adc #$10
  sta PPUDATA
  lda #$20
  sta PPUDATA

  jsr ppu_cls
  lda #>hello_str
  ldy #<hello_str
  jsr ppu_puts_ay
  lda mapper_type
  asl a
  tax
  ldy mapper_names+0,x
  lda mapper_names+1,x
  jsr ppu_puts_ay

forever:
  jsr ppu_wait_vblank
  jmp forever
.endproc

.rodata
LF=$0A
COPR=$7F
hello_str:
  .byte "MDFourier Terminal Emulator",LF
  .byte COPR," 2021 Damian Yerrick",LF,LF
  .byte "Expansion audio test coming",LF
  .byte "soon.",LF
  .byte "Detected ",$00

mapper_names:
  .addr unknown_mapper_name, mmc5_name, fme7_name, vrc7_name
  .addr vrc6_name, vrc6ed2_name, n163_name
unknown_mapper_name: .byte "unknown mapper",0
mmc5_name:           .byte "Nintendo MMC5",0
fme7_name:           .byte "Sunsoft FME-7/5B",0
vrc7_name:           .byte "Konami VRC7",0
vrc6_name:           .byte "Konami VRC6 (AD)",0
vrc6ed2_name:        .byte "Konami VRC6 (ED2)",0
n163_name:           .byte "Namco 163",0

