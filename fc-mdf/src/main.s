.include "nes.inc"
.include "global.inc"
.export main, irq_handler

.segment "LOWCODE"

.proc irq_handler
  rti
.endproc

.code

.proc main
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
  lda #0
  sta PPUADDR
  sta PPUADDR


forever:
  jmp forever
.endproc
