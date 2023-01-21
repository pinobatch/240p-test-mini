;
; MMC1 driver for NES
; Copyright 2011-2023 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.import reset_handler
.importzp nmis
.import unpb53_some, unpb53_file_cb, load_sb53_file_cb, load_iu53_file_cb
.export unpb53_gate, unpb53_file, load_sb53_file, load_iu53_file
.import rf_vwfClearPuts_cb, rf_load_layout_cb
.export rf_vwfClearPuts, rf_load_layout

.segment "INESHDR"
  .byt "NES",$1A  ; magic signature
  .byt 4          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $10        ; lower mapper nibble
  .byt $00        ; upper mapper nibble

; Fixed code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


MAIN_CODE_BANK = $02
GATE_DATA_BANK = $01
RESETSTUB_BASE = $FF70

.macro resetstub_in segname, scopename
.segment segname
.proc scopename
  .assert * = ::RESETSTUB_BASE, error, "RESETSTUB_BASE doesn't match linker configuration"

; Call gates
unpb53_gate:
  lda #GATE_DATA_BANK
  sta unpb53_gate+1
  jsr unpb53_some
rtl:
  ldx #MAIN_CODE_BANK
  stx rtl+1
  rts

load_sb53_file:
  jsr load_sb53_file_cb
  jmp rtl

load_iu53_file:
  jsr load_iu53_file_cb
  jmp rtl

unpb53_file:
  jsr unpb53_file_cb
  jmp rtl

rf_load_layout:
  ldx #GATE_DATA_BANK
  stx rf_load_layout+1
  jsr rf_load_layout_cb
  jmp rtl

rf_vwfClearPuts:
  lda #MAIN_CODE_BANK
  sta rtl+1
  jsr rf_vwfClearPuts_cb
  lda #GATE_DATA_BANK
  sta rf_load_layout+1
  rts

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
  .assert * <= $FFE0, warn, "reset stub extends into Famicom Box header area"
  .res ::scopename - ::RESETSTUB_BASE + $FFFA - *
  .addr nmi_handler, resetstub_entry, irq_handler
.endproc
.endmacro

resetstub_in "STUB15", stub1
unpb53_gate = stub1::unpb53_gate
unpb53_file = stub1::unpb53_file
load_sb53_file = stub1::load_sb53_file
load_iu53_file = stub1::load_iu53_file
rf_vwfClearPuts = rf_vwfClearPuts_cb
rf_load_layout = stub1::rf_load_layout

