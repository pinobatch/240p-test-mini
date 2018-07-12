.include "nes.inc"
.include "global.inc"

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
.code

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

.proc uniu

  ; Initialize the bit iterator to the empty state
  lda #$80
  sta ciBits

  ; Page-align ciSrc
  asl a
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
        ; First count bits in last new tile
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