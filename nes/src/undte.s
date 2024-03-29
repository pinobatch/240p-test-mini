.include "global.inc"

; BPE (Byte Pair Encoding) or DTE (Digram Tree Encoding)
; Code units 0-127 map to literal ASCII characters.
; Code units 128-135 map to extra characters (arrows and the like).
; Code units 136-255 map to pairs of code units.  The second
; is added to a stack, and the first is interpreted as above.

DTE_MIN_CODEUNIT = 136
FIRST_PRINTABLE_CU = 32

.import dte_replacements

.segment "LIBCODE"

;;
; Decompress a line of digram tree encoded text to help_line_buffer.
; @param AY pointer to start of compressed text, ending with code
;   unit less than FIRST_PRINTABLE_CU
; @return $00: initial AY value; A: compressed bytes read;
;   Y: decompressed bytes written; CF true
.proc undte_line
srcaddr = $00
  sty srcaddr
  sta srcaddr+1
.endproc
.proc undte_line0
srcaddr = $00
ysave = $02

  ; Copy the compressed data to the END of help_line_buffer.
  ; First calculate compressed data length
  ldy #0
strlenloop:
  lda (srcaddr),y
  iny
  cpy #HELP_LINE_LEN
  bcs have_strlen
  cmp #FIRST_PRINTABLE_CU
  bcs strlenloop
have_strlen:
  tya
  pha  ; Save compressed byte count

  ; Now copy backward
  ldx #HELP_LINE_LEN
poolypoc:
  dey
  dex
  lda (srcaddr),y
  sta help_line_buffer,x
  cpy #0
  bne poolypoc

  ; at this point, Y = 0, pointing to the decompressed data,
  ; and X points to the remaining compressed data
decomploop:
  lda help_line_buffer,x
decomp_code:
  cmp #DTE_MIN_CODEUNIT
  bcs handle_bytepair
  sta help_line_buffer,y
  iny
  inx
  cpx #HELP_LINE_LEN
  bcc decomploop

  pla
  rts

handle_bytepair:
  ; For a bytepair, stack the second byte on the compressed data
  ; and reprocess the first byte
  sty ysave
  asl a
  tay
  lda dte_replacements-(DTE_MIN_CODEUNIT-128)*2+1,y
  sta help_line_buffer,x
  dex
  lda dte_replacements-(DTE_MIN_CODEUNIT-128)*2,y
  ldy ysave
  jmp decomp_code
.endproc
