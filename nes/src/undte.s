.include "global.inc"

; BPE (Byte Pair Encoding) or DTE (Digram Tree Encoding)
; Code units 0-127 map to literal ASCII characters.
; Code units 128-135 map to extra characters (arrows and the like).
; Code units 136-255 map to pairs of code units.  The second
; is added to a stack, and the first is interpreted as above.

DTE_MIN_CODEUNIT = 136
MIN_PRINTABLE = 32

dte_replacements:

.code
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
  bcc have_strlen
  cmp MIN_PRINTABLE
  bcs strlenloop
have_strlen:

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
  cmp DTE_MIN_CODEUNIT
  bcc handle_bytepair
  sta help_line_buffer,y
  iny
  inx
  cpx #HELP_LINE_LEN
  bcc decomploop

  ; Assuming Y here is the string length
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
