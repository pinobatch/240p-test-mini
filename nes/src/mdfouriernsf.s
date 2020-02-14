.exportzp test_state, tvSystem, new_keys
.export mdfourier_present, mdfourier_good_phase
.import __ROM7_START__
.import mdfourier_init_apu, mdfourier_run, mdfourier_push_apu
SIZEOF_TEST_STATE = 24

.segment "NSFHDR"
  .byt "NESM", $1A  ; signature
  .byt $01  ; version: NSF classic (no NSFe metadata)
  .byt 1  ; song count
  .byt 1  ; first song to play
  .addr __ROM7_START__  ; load address (should match link script)
  .addr mdfourier_nsf_init
  .addr mdfourier_nsf_play
names_start:
  .byte "MDFourier v7"
  .res names_start+32-*, $00
  .byte "Damian Yerrick (@PinoBatch)"
  .res names_start+64-*, $00
  .byte "2020 Damian Yerrick"
  .res names_start+96-*, $00
  .word 16639  ; NTSC frame length
  .byt $00,$00,$00,$00,$00,$00,$00,$00  ; bankswitching disabled
  .word 19997  ; PAL frame length
  .byt $02  ; NTSC/PAL dual compatible; NTSC preferred
  .byt $00  ; Famicom mapper sound not used
  .dword 0  ; no NSFe metadata

mdfourier_good_phase = mdfourier_present

.zeropage

song_id: .res 1
new_keys = song_id
tvSystem: .res 1
sp_on_play_call: .res 1
saved_stack_depth: .res 1
saved_stack: .res 16
test_state: .res SIZEOF_TEST_STATE

.code
.proc mdfourier_nsf_init
  sta song_id
  stx tvSystem
  tsx
  stx sp_on_play_call
  jsr mdfourier_init_apu
  jsr mdfourier_present
  jmp mdfourier_run
.endproc

;;
; Saves coroutine state and returns to the NSF player
.proc mdfourier_present
  sta $4444
  tsx
  txa
  eor #$FF
  sec
  adc sp_on_play_call
  sta saved_stack_depth
  beq stack_is_empty
  ldy #0
  stack_loop:
    pla
    sta saved_stack,y
    iny
    cpy saved_stack_depth
    bcc stack_loop
  stack_is_empty:  
  rts
.endproc

.proc mdfourier_nsf_play
  sta $4444
  jsr mdfourier_push_apu

  ; Figure out how much stack we'll have to save next time
  tsx
  stx sp_on_play_call

  ; Restore what we saved last time
  ldy saved_stack_depth
  beq stack_is_empty
  unstack_loop:
    lda saved_stack-1,y
    pha
    dey
    bne unstack_loop
  stack_is_empty:
  rts
.endproc
