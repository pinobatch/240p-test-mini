.include "nes.inc"
.include "global.inc"
.importzp IU53_BANK
.import iu53_files, unpb53_xtiles
.export load_iu53_file_cb

.macro ciGetBit
.local havebit
  asl ciBits
  bne havebit
    jsr ciGetByte
  havebit:
.endmacro

; The bits of the most recently retrieved byte, followed by a 1 then 0s
ciBits = $00

; The size remaining on the current row of the nametable
widcd = $01

; The size of the nametable
uniu_width = $04
uniu_height = $05

; The index to add to all tile IDs, assuming that blank tiles
; precede this index in CHR RAM.
uniu_first_nonblank = $06

; The number of already seen tiles, used as the next item in the
; incrementing sequence.  Usually at the start of a decode, this is 
; 0, but there may be tiles reserved for CHR rotation.
uniu_seen_tiles = $07

.segment "PB53CODE"

;;
; Read a byte and return its first bit.
; @param ciSrc+y address of new bytes
; @param C must be set
; @return ciSrc+y and ciBits updated; new bit in C
.proc ciGetByte
  pha
  lda (ciSrc),y
  rol a
  sta ciBits
  pla
  iny
  bne :+
    inc ciSrc+1
  :
  rts
.endproc

;;
; Decompresses a nametable fragment using incrementing uniques.
;
; Each image has a width and height because some images have a
; blank margin, and coding all the blank tiles individually would
; waste space.  Blank tiles and tiles outside the rectangle are
; left untouched; if you want them zeroed, call ppu_clear_nt first.
; @param ciSrc pointer to compressed data
; @param ciDst pointer to top left of destination
; @param uniu_width width in tiles of image
; @param uniu_height height in tiles of image
; @param uniu_first_nonblank tile number of first nonblank tile
; @return ciDst: below first tile of last row; ciSrc: at end of
;   source data; uniu_height: 0; uniu_width: unchanged;
;   uniu_seen_tiles: number of unique nonblank tiles used
.proc uniu

  ; Initialize the bit iterator to the empty state
  lda #$80
  sta ciBits
  asl a
  sta uniu_seen_tiles

  ; Page-align ciSrc
  ldy ciSrc+0
  sta ciSrc+0

  rowloop:
    ; Seek to start of row
    lda ciDst+1
    sta PPUADDR
    lda ciDst+0
    sta PPUADDR
    clc
    adc #32
    sta ciDst+0
    bcc :+
      inc ciDst+1
    :
    lda uniu_width
    sta widcd
.out .sprintf("%d bytes in before byteloop", *-::ciGetByte)
    byteloop:
      ciGetBit
      bcs not_blank_tile
        ; 0: Skip an empty tile
        bit PPUDATA
        bcc bytedone
      not_blank_tile:
      ciGetBit
      bcs is_previous_tile
        ; 10: Write the next tile in sequence
        lda uniu_seen_tiles
        inc uniu_seen_tiles
        bcc have_nonblank_tile
      is_previous_tile:
        ; 11xxxxxx with same number of x bits as last tile in
        ; sequence: Write byte
        ; First count bits in last new tile.
        ; sec  ; carry set by bcs
        lda uniu_seen_tiles
        beq have_nonblank_tile
        sbc #1
        beq have_nonblank_tile
        ldx #0
        pt_log2loop:
          inx
          lsr a
          bne pt_log2loop
        ; Load that many bits from the compressed data
        pt_fetchloop:
          ciGetBit
          rol a
          dex
          bne pt_fetchloop

      have_nonblank_tile:
        adc uniu_first_nonblank
        sta PPUDATA
      bytedone:
      dec widcd
      bne byteloop
    dec uniu_height
    bne rowloop
  sty ciSrc+0
  rts
.endproc

.proc add_a_to_ciSrc
  clc
  adc ciSrc
  sta ciSrc
  bcc :+
    inc ciSrc+1
  :
  rts
.endproc

.proc load_iu53_file_cb
  asl a
  tax
  lda #IU53_BANK
  .ifdef ::USE_MMC
    jsr mmc_bank_a
  .else
    sta *-1
  .endif
  ldy iu53_files+0,x
  lda iu53_files+1,x
.endproc
.proc uniu_file_ay
  sta ciSrc+1
  sty ciSrc
.endproc
.proc uniu_file
  ; Header before the PB53 tile data:
  ; Tile number of first nonblank tile, number of PB53 tiles

  ; Get the address of the first nonblank tile
  ldy #0
  lda (ciSrc),y
  pha  ; Stack: first nonblank tile, ...
  asl a  ; multiply by 16
  sta ciDst
  tya
  rol a
  asl ciDst
  rol a
  asl ciDst
  rol a
  asl ciDst
  rol a
  sta PPUADDR
  lda ciDst
  sta PPUADDR

  ; Get the pb53 tile count
  iny
  lda (ciSrc),y
  tax

  ; Skip the header so far
  lda #2
  jsr add_a_to_ciSrc
  jsr unpb53_xtiles
  pla
  sta uniu_first_nonblank

  ; Header after PB53 tile data:
  ; starting NT address (2 bytes), width, height
  ldy #0
  lda (ciSrc),y
  sta ciDst+0
  iny
  lda (ciSrc),y
  pha  ; save address which has flags in bits 7-6
  and #$2F
  sta ciDst+1
  iny
  lda (ciSrc),y
  sta uniu_width
  iny
  lda (ciSrc),y
  sta uniu_height
  lda #4
  jsr add_a_to_ciSrc
  jsr uniu
  pla  ; A = flags saved earlier

  ; Optionally, attributes and palette can follow
  asl a
  bcc no_attributes
    pha  ; save other flag
    lda ciDst+1
    ora #$03  ; skip to attribute table
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #64/16
    jsr unpb53_xtiles
    pla
  no_attributes:

  ldy #$00
  asl a
  bcc no_palette
    lda #$3F
    sta PPUADDR
    sty PPUADDR
    palloop:
      lda (ciSrc),y
      sta PPUDATA
      iny
      cpy #16
      bcc palloop
  no_palette:

  rts
.endproc
