.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_mdfourier, RF_mdfourier, RF_mdfourier_15k

skip_ppu         = test_state+0
test_section     = test_state+1
test_good_phase  = test_state+6  ; from the previously run test

NUM_PPU_LOADERS = 6
crosstalk8k_chr = $01B0

.bss
mdfourier_good_phase: .res 1

.code
.proc do_mdfourier
  lda #0
  sta skip_ppu
restart:
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette
test_interrupted:
  lda mdfourier_good_phase
  sta test_good_phase
test_finished:
  jsr write_phase_ok
  jsr mdfourier_init_apu
  lda #0
  sta test_section

  ; Wait for B Button release before resuming menu loop so that
  ; the packet to silence the APU isn't skipped
  another_run_wait_b:
    jsr read_pads
    jsr mdfourier_present
    bit cur_keys
    bvs another_run_wait_b

  ; If Start+A is held, start test immediately
  lda mdfourier_good_phase
  beq not_startplusa
  lda cur_keys
  and #KEY_START|KEY_A
  cmp #KEY_START|KEY_A
  bne not_startplusa
    lda #1
    sta skip_ppu
    jsr run_ppu_loader
    jsr mdfourier_run
    dec skip_ppu
    jmp after_run
  not_startplusa:

  wait_for_start:
    lda #helpsect_mdfourier
    jsr read_pads_helpcheck
    bcs restart

    lda new_keys
    and #KEY_LEFT
    beq not_left
      dec skip_ppu
      bpl :+
        lda #NUM_PPU_LOADERS-1
        sta skip_ppu
      :
      jsr run_ppu_loader
      jsr mdfourier_present
    not_left:
    lda new_keys
    and #KEY_RIGHT
    beq not_right
      inc skip_ppu
      lda skip_ppu
      cmp #NUM_PPU_LOADERS
      bcc :+
        lda #0
        sta skip_ppu
      :
      jsr run_ppu_loader
      jsr mdfourier_present
    not_right:

    bit new_keys
    bvs done
    bpl wait_for_start

  jsr mdfourier_run

after_run:

  ; If B was pressed to interrupt, transition from "OK" to based
  ; on the phase. Otherwise, transition from "OK" to "Complete".
  bit new_keys
  bvc test_finished
  bvs test_interrupted
done:
  rts
.endproc

.proc write_phase_ok
  lda #0
  sta PPUMASK
  lda #RF_mdfourier
  jsr rf_load_layout

  ; Replace bad phase message with good phase if good
  ; MGP nonzero and TGP nonzero: OK
  ; TGP nonzero, MGP zero: Complete
  ; TGP zero: Trash
  lda test_good_phase
  beq dont_write_good_phase
    ; Erase "Trash. Press Reset" message
    ldy #$22
    lda #$80
    sty PPUADDR
    sta PPUADDR
    asl a
    ldx #32
    :
      sta PPUDATA
      dex
      bne :-

    ; Write "OK" or "Complete"
    lda #$8A
    sty PPUADDR
    sta PPUADDR
    lda mdfourier_good_phase
    bne write_phase_ok
    ldx #$22
    :
      stx PPUDATA
      inx
      cpx #$30
      bcc :-
    rts
  write_phase_ok:
    ; Write "OK"
    ldx #$20
    stx PPUDATA
    inx
    stx PPUDATA
    ldx #48
    lda #0
    :
      sta PPUDATA
      dex
      bne :-

    ; Change message color to green (attribute 2)
    iny
    lda #$EA
    sty PPUADDR
    sta PPUADDR
    sta PPUDATA
  dont_write_good_phase:
  rts
.endproc

.proc mdfourier_present
  lda cur_keys+0
  and #KEY_B
  bne skip_it_all
  jsr read_pads
  
  ; Good; we have the full screen ready.  Wait for a vertical blank
  ; and set the scroll registers to display it.
  lda nmis
vw3:
  cmp nmis
  beq vw3
  
  jsr mdfourier_push_apu
  lda skip_ppu
  bne skip_it_all
    ldx #0
    stx OAMADDR
    lda #>OAM
    sta OAM_DMA
    ldy #0
    lda #VBLANK_NMI|BG_0000|OBJ_0000
    clc  ; no sprites this time
    jsr ppu_screen_on
  skip_it_all:

  rts
.endproc

.proc run_ppu_loader
  lda skip_ppu
  asl a
  tax
  lda ppu_loaders+1,x
  pha
  lda ppu_loaders+0,x
  pha
  rts
ppu_loaders:
  .addr ppu_loader_black-1
  .addr ppu_loader_subblack-1
  .addr ppu_loader_black-1
  .addr ppu_loader_white-1
  .addr ppu_loader_15k-1
  .addr ppu_loader_8k-1
.endproc

.proc ppu_loader_subblack
  ldy #$E0  ; enable all emphases
  lda #$0D
  bne ppu_set_bgcolor_a_mask_y
.endproc

.proc ppu_loader_white
  lda #$20
  bne ppu_set_bgcolor_a
.endproc

.proc ppu_loader_black
  lda #$0F
.endproc
.proc ppu_set_bgcolor_a
  ldy #0
.endproc
.proc ppu_set_bgcolor_a_mask_y
  ldx #$3F
  sty PPUMASK
  stx PPUADDR
  ldy #0
  sty PPUADDR
  sta PPUDATA
  sty PPUADDR
  sty PPUADDR
  rts
.endproc

; synthesize a 3/8 duty pulse wave at 7.8 kHz
.proc ppu_loader_8k
  jsr ppu_loader_black
  ldx #$2C
  lda #<(crosstalk8k_chr>>4)
  ldy #0
  jsr ppu_clear_nt
  ; fall through to ppu_screen_on_ntB
.endproc
.proc ppu_screen_on_ntB
  jsr mdfourier_present
  ldx #0
  ldy #0
  lda #VBLANK_NMI|BG_0000|OBJ_0000|3
  clc
  jmp ppu_screen_on
.endproc

; synthesize a sine wave at 15.7 kHz
.proc ppu_loader_15k
  jsr ppu_loader_black
  lda #RF_mdfourier_15k
  jsr rf_load_layout
  jmp ppu_screen_on_ntB
.endproc
