;
; iNES header for NROM-128 with CHR RAM
; Copyright 2018 Damian Yerrick
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
  .byt 1          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $01        ; lower mapper nibble, vertical mirroring
  .byt $00        ; upper mapper nibble

; Fixed code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CODE"
nmi_handler:
  inc nmis
irq_handler:
  rti  

.segment "VECTORS"
  .addr nmi_handler, reset_handler, irq_handler
