.segment "ZEROPAGE"
nmis: .res 1

.segment "INESHDR"
  .byte "NES", $1A, 1, 1, 0, 0

.segment "VECTORS"
  .addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
nam: .incbin "obj/nes/palpar.nam"
palette: .byte $0F,$26,$10
palette_end:

.segment "CODE"
nmi_handler:
  inc nmis
  rti
irq_handler:
  bit $4015
  rti
reset_handler:
  sei
  ldx #$FF
  txs
  inx
  stx $2000
  stx $2001
  bit $4015
  bit $2002
  @vwait1:
    bit $2002
    bpl @vwait1
  cld
  @vwait2:
    bit $2002
    bpl @vwait2
  lda #$3F
  ldx #$00
  sta $2006
  stx $2006
  @palloop:
    lda palette,x
    sta $2007
    inx
    cpx #palette_end-palette
    bcc @palloop
  lda #<nam
  sta $00
  lda #>nam
  sta $01
  ldx #$20
  ldy #$00
  stx $2006
  sty $2006
  ldx #4
  @ntloop:
    lda ($00),y
    sta $2007
    iny
    bne @ntloop
    inc $01
    dex
    bne @ntloop
  lda #$80
  sta $2000
  lda nmis
  @vwait3:
    cmp nmis
    beq @vwait3
  lda #%00001010
  sta $2001
forever:
  jmp forever

.segment "CHR"
.incbin "obj/nes/palpar.chr"
