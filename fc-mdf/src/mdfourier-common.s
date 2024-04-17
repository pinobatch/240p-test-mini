.include "nes.inc"
.include "global.inc"
.export silence_10_ticks, silence_20_ticks, silence_a_ticks, wait_a_ticks
.export mdfourier_push_regs
.export apu_addressbuf, apu_databuf
.exportzp test_section, test_row, test_ticksleft, test_subtype

test_section     = test_state+1
test_row         = test_state+2
test_ticksleft   = test_state+3
test_subtype     = test_state+4

apu_addressbuf = $0100 + FDS_OFFSET
apu_databuf    = $0120 + FDS_OFFSET

; FDS code and mapper configuration by Persune 2023
; with code from Brad Smith 2021
; https://github.com/bbbradsmith/NES-ca65-example/tree/fds

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.code
.endif


.align 32
.proc mdfourier_push_regs
  ; There are 20 cycles from one APU write to the next
  ldx #0
  ldy apu_addressbuf,x
  cpy #$FF
  beq no_apu_tasks
    apu_loop:
      lda apu_databuf,x     ; 4
      sta $4000,y           ; 5
      inx                   ; 2
      ldy apu_addressbuf,x  ; 4
      cpy #$FF              ; 2
      bne apu_loop          ; 3
    sty apu_addressbuf+0
  no_apu_tasks:
  rts
.endproc

.proc silence_10_ticks
  lda #10
  jmp silence_a_ticks
.endproc

.proc silence_20_ticks
  lda #20
  ; fall through to silence_a_ticks
.endproc

.proc silence_a_ticks
  pha
  jsr mdfourier_init_apu
  pla
  ; fall through to wait_a_ticks
.endproc

.proc wait_a_ticks
  sta test_ticksleft
  waitloop:
    jsr mdfourier_present
    dec test_ticksleft
    bne waitloop
  rts
.endproc
