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
.export rtl, mmc_bank_a

.segment "INESHDR"
  .byt "NES",$1A  ; magic signature
  .byt 4          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $10        ; lower mapper nibble
  .byt $00        ; upper mapper nibble

; Fixed code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MAIN_CODE_BANK = $02
GATE_DATA_BANK = $01
RESETSTUB_BASE = $FFD0

.code
; Second stage reset handler: init $8000 and $A000
reset_stage2:
  ldx #1
  lda #0
  sta $8000  ; vertical mirroring
  stx $8000  ; not 1-screen mirroring
  stx $8000  ; fix last bank
  stx $8000  ; not 32k mode
  sta $8000  ; 8K CHR bank
  sta $A000
  sta $A000
  sta $A000
  sta $A000
  sta $A000
  jmp reset_handler

; Call gates
unpb53_gate:
  lda #GATE_DATA_BANK
  jsr mmc_bank_a
  jsr unpb53_some
rtl:
  lda #MAIN_CODE_BANK
mmc_bank_a:
  sta $E000
  lsr a
  sta $E000
  lsr a
  sta $E000
  lsr a
  sta $E000
  lsr a
  sta $E000
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
  pha
  lda #GATE_DATA_BANK
  jsr mmc_bank_a
  pla
  jsr rf_load_layout_cb
  jmp rtl

nmi_handler:
  inc nmis
irq_handler:
  rti

.macro resetstub_in segname, scopename
.segment segname
.proc scopename
  .assert * = ::RESETSTUB_BASE || * = ::RESETSTUB_BASE - $4000, error, "RESETSTUB_BASE doesn't match linker configuration"

resetstub_entry:
  sei
  ldx #$FF
  txs
  stx resetstub_entry+2
  jmp reset_stage2
  .assert * <= $FFE0, warn, "reset stub extends into Famicom Box header area"
  .res ::scopename - ::RESETSTUB_BASE + $FFFA - *
  .addr nmi_handler, resetstub_entry, irq_handler
.endproc
.endmacro

resetstub_in "STUB00", stub00
resetstub_in "STUB01", stub01
resetstub_in "STUB02", stub02
resetstub_in "STUB15", stub15

rf_vwfClearPuts = rf_vwfClearPuts_cb
