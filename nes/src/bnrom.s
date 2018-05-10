;
; BNROM driver for NES
; Copyright 2011-2016 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.import reset_handler
.importzp nmis
.import unpb53_some, unpb53_file_cb, load_sb53_file_cb
.export unpb53_gate, unpb53_file, load_sb53_file

.segment "INESHDR"
  .byt "NES",$1A  ; magic signature
  .byt 4          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $21        ; lower mapper nibble, vertical mirroring
  .byt $20        ; upper mapper nibble

; Fixed code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macro resetstub_in segname, scopename
.segment segname
.proc scopename

; Call gates
zerobyte: .byte $00
unpb53_gate:
  lsr zerobyte
  jsr unpb53_some
rtl:
  ldx #$FF
  stx resetstub_entry+2
  rts

load_sb53_file:
  lsr zerobyte
  jsr load_sb53_file_cb
  jmp rtl

unpb53_file:
  lsr zerobyte
  jsr unpb53_file_cb
  jmp rtl

nmi_handler:
  inc nmis
irq_handler:
  rti  
resetstub_entry:
  sei
  ldx #$FF
  txs
  stx resetstub_entry+2
  jmp reset_handler
  .res ::scopename + $3A - *
  .addr nmi_handler, resetstub_entry, irq_handler
.endproc
.endmacro

resetstub_in "STUB0",stub0
resetstub_in "STUB1",stub1
unpb53_gate = stub1::unpb53_gate
unpb53_file = stub1::unpb53_file
load_sb53_file = stub1::load_sb53_file


