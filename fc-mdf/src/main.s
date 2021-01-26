.include "nes.inc"
.include "global.inc"
.export main, irq_handler, nmi_handler

.zeropage
nmis:  .res 1

.segment "LOWCODE"

.proc nmi_handler
  inc nmis
  rti
.endproc

.proc irq_handler
  rti
.endproc

.proc main
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda mapper_type
  asl a
  ora #$10
  sta PPUDATA
  lda #0
  sta PPUADDR
  sta PPUADDR


forever:
  jmp forever
.endproc
