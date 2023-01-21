;
; MMC3 driver for NES
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
  .byt 4          ; size of PRG ROM in 16384 byte units (two MMC3 banks per unit)
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $40        ; lower mapper nibble
  .byt $00        ; upper mapper nibble

; Fixed code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


MAIN_CODE_BANK = $04
GATE_DATA_BANK = $02
RESETSTUB_BASE = $FF70

.segment "STUB15"
resetstub_start:
.assert resetstub_start = ::RESETSTUB_BASE, error, "RESETSTUB_BASE doesn't match linker configuration"

; Call gates
unpb53_gate:
  lda #GATE_DATA_BANK
  sta unpb53_gate+1
  jsr unpb53_some
rtl:
  lda #MAIN_CODE_BANK
mmc_bank_a:
  ldx #6
  stx $8000
  sta $8001
  inx
  stx $8000
  ora #$01
  sta $8001
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
resetstub_entry:
  sei
  ldx #7
  loop:
    lda mmc3_initial_banks,x
    stx $8000
    sta $8001
    dex
    bpl loop
  txs
  jmp reset_handler

mmc3_initial_banks: .byte 0, 2, 4, 5, 6, 7, 0, 1
  .assert * <= $FFE0, warn, "reset stub extends into Famicom Box header area"
  .res ::resetstub_start - ::RESETSTUB_BASE + $FFFA - *
  .addr nmi_handler, resetstub_entry, irq_handler

rf_vwfClearPuts = rf_vwfClearPuts_cb
