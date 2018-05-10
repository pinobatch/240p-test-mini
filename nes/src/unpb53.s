;
; PB53 unpacker for 6502 systems
; Copyright 2012 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;
.include "nes.inc"
.export unpb53_some, unpb53_file_cb, load_sb53_file_cb
.import unpb53_files, sb53_files
.export PB53_outbuf
.exportzp ciSrc, ciSrc, ciBufStart, ciBufEnd
.importzp nmis

.segment "ZEROPAGE"
ciSrc: .res 2
ciDst: .res 2
ciBufStart: .res 1
ciBufEnd: .res 1
PB53_outbuf = $0100

.segment "PB53CODE"
.proc unpb53_some
ctrlbyte = 0
bytesLeft = 1
  ldx ciBufStart
loop:
  ldy #0
  lda (ciSrc),y
  inc ciSrc
  bne :+
  inc ciSrc+1
:
  cmp #$82
  bcc twoPlanes
  beq copyLastTile
  cmp #$84
  bcs solidColor

  ; at this point we're copying from the first stream to this one
  ; assuming that we're decoding two streams in parallel and the
  ; first stream's decompression buffer is PB53_outbuf[0:ciBufStart]
  txa
  sec
  sbc ciBufStart
  tay
copyTile_ytox:
  lda #16
  sta bytesLeft
prevStreamLoop:
  lda PB53_outbuf,y
  sta PB53_outbuf,x
  inx
  iny
  dec bytesLeft
  bne prevStreamLoop
tileDone:
  cpx ciBufEnd
  bcc loop
  rts

copyLastTile:
  txa
  cmp ciBufStart
  bne notAtStart
  lda ciBufEnd
notAtStart:
  sec
  sbc #16
  tay
  jmp copyTile_ytox

solidColor:
  pha
  jsr solidPlane
  pla
  lsr a
  jsr solidPlane
  jmp tileDone
  
twoPlanes:
  jsr onePlane
  ldy #0
  lda (ciSrc),y
  inc ciSrc
  bne :+
  inc ciSrc+1
:
  cmp #$82
  bcs copyPlane0to1
  jsr onePlane
  jmp tileDone

copyPlane0to1:
  ldy #8
  and #$01
  beq noInvertPlane0
  lda #$FF
noInvertPlane0:
  sta ctrlbyte
copyPlaneLoop:
  lda a:PB53_outbuf-8,x
  eor ctrlbyte
  sta PB53_outbuf,x
  inx
  dey
  bne copyPlaneLoop
  jmp tileDone

onePlane:
  ora #$00
  bpl pb8Plane
solidPlane:
  ldy #8
  and #$01
  beq solidLoop
  lda #$FF
solidLoop:
  sta PB53_outbuf,x
  inx
  dey
  bne solidLoop
  rts

pb8Plane:
  sec
  rol a
  sta ctrlbyte
  lda #$00
pb8loop:

  ; at this point:
  ; A: previous byte in this plane
  ; C = 0: copy byte from bitstream
  ; C = 1: repeat previous byte
  bcs noNewByte
  lda (ciSrc),y
  iny
noNewByte:
  sta PB53_outbuf,x
  inx
  asl ctrlbyte
  bne pb8loop
  clc
  tya
  adc ciSrc
  sta ciSrc
  bcc :+
  inc ciSrc+1
:
  rts
.endproc

unpb53_tiles_left = 2

.proc unpb53_xtiles
  stx unpb53_tiles_left
.endproc
.proc unpb53_tiles
  ldx #0
  stx ciBufStart
  ldx #16
  stx ciBufEnd
loop:
  jsr unpb53_some
  ldx #0
copyloop:
  lda PB53_outbuf,x
  sta $2007
  inx
  cpx #16
  bcc copyloop
  dec unpb53_tiles_left
  bne loop
  rts
.endproc

; pb53 files: load individual files ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Decompresses compressed pb53 file A to PPU address XXYY.
.proc unpb53_file_cb
  stx PPUADDR
  sty PPUADDR
  asl a
  asl a
  tay
  lda unpb53_files,y
  sta ciSrc
  lda unpb53_files+1,y
  sta ciSrc+1
  lda unpb53_files+2,y
  sta unpb53_files+2,y
  ldx unpb53_files+3,y
  jmp unpb53_xtiles
.endproc

; sb53: a whole screen packed with pb53 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Loads an SB53 file to the pattern table and nametable.
; Leaves ciSrc at the start of the palette and the VRAM address
; at the end of the background palette.
.proc load_sb53_file_cb
  asl a
  asl a
  tay
  lda sb53_files,y
  sta ciSrc
  lda sb53_files+1,y
  sta ciSrc+1
  lda sb53_files+2,y
  sta sb53_files+2,y  ; switch bank
  ldx sb53_files+3,y
.endproc
.proc load_sb53

  ; Seek to the start of the pattern table
  lda #VBLANK_NMI
  ldy #0
  sta PPUCTRL
  sty PPUMASK
  txa
  pha
  and #$10
  sta PPUADDR
  sty PPUADDR

  ; Read the number of used tiles and decompress that many tiles
anotherpattable:
  lda (ciSrc),y
  inc ciSrc
  bne :+
    inc ciSrc+1
  :
  tax
  jsr unpb53_xtiles
  pla
  bpl have_all_pat
  and #$7F
  pha
  bpl anotherpattable
have_all_pat:

  ; Decompress the nametable
  ldx #1024/16  ; Calculate number of NTs to decompress
  cmp #$40
  bcc onlyonent
    ldx #2048/16
  onlyonent:
  and #$0C
  ora #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR
  jsr unpb53_xtiles

  ; Load the palette
  lda nmis
:
  cmp nmis
  beq :-
  lda #$3F
  sta PPUADDR
  ldy #$00
  sty PPUADDR
palloop:
  lda (ciSrc),y
  sta PPUDATA
  sta PB53_outbuf,y
  iny
  cpy #16
  bcc palloop
  rts
.endproc

