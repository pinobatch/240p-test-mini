;
; UNROM driver for NES
; Copyright 2011-2015 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.import reset_handler
.importzp nmis

.segment "INESHDR"
  .byt "NES",$1A  ; magic signature
  .byt 4          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $21        ; lower mapper nibble, vertical mirroring
  .byt $00        ; upper mapper nibble

; Fixed code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macro resetstub_in segname
.segment segname
.scope
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
  .assert *=$FFFA, error, "vectors in wrong place"
  .addr nmi_handler, resetstub_entry, irq_handler
.endscope
.endmacro

; Call gates are trivial in UNROM
.import unpb53_some, unpb53_file_cb, load_sb53_file_cb
.export unpb53_gate, unpb53_file, load_sb53_file

unpb53_gate = unpb53_some
unpb53_file = unpb53_file_cb
load_sb53_file = load_sb53_file_cb

resetstub_in "STUB15"

