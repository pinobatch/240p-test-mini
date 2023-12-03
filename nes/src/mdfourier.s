.include "nes.inc"
.include "global.inc"

test_section     = test_state+1
test_row         = test_state+2
test_ticksleft   = test_state+3
test_subtype     = test_state+4
test_lastpulsehi = test_state+5
test_good_phase  = test_state+6

.ifdef FDSHEADER
FDS_OFFSET = 4
.else
FDS_OFFSET = 0
.endif

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
.proc mdfourier_push_apu
  ; There are 18 cycles from one APU write to the next
  ldx #0
  ldy apu_addressbuf,x
  bmi no_apu_tasks
    apu_loop:
      lda apu_databuf,x     ; 4
      sta $4000,y           ; 5
      inx                   ; 2
      ldy apu_addressbuf,x  ; 4
      bpl apu_loop          ; 3
    sty apu_addressbuf+0
  no_apu_tasks:
  rts
.endproc

.proc mdfourier_run
  lda mdfourier_good_phase
  sta test_good_phase
  jsr pattern_trash_beep
  jsr pattern_sync
  inc test_section

  ; Pattern being tested goes here
  ;jsr pattern_dmc_fading

  ; Column 1
  lda #$00  ; 12.5% pulse
  jsr chromatic_scale_subtype_A
  inc test_section
  lda #$40  ; 25% pulse
  jsr chromatic_scale_subtype_A
  inc test_section
  lda #$80  ; 50% pulse
  jsr chromatic_scale_subtype_A

  ; Past this phase, the triangle wave's phase gets corrupted.
  inc test_section
  bit new_keys
  bvs skip_all
  lda #0
  sta mdfourier_good_phase

  lda #$C0  ; triangle
  jsr chromatic_scale_subtype_A
  inc test_section
  lda #$00  ; 32767 step noise
  jsr noise_scale_subtype_A
  inc test_section
  lda #$80  ; 93 step noise
  jsr noise_scale_subtype_A
  inc test_section
  jsr noise_steady
  inc test_section

  ; Column 2
  jsr pattern_dmc_pops
  inc test_section
  jsr pattern_dmc_scale
  inc test_section
  jsr pattern_phase_resets
  inc test_section
  lda #$04
  jsr long_slide_channel_A
  lda #$08
  jsr long_slide_channel_A
  inc test_section
  lda #60
  jsr wait_a_ticks
  inc test_section
  jsr pattern_pulse_volume_ramp
  jsr pattern_noise_volume_ramp
  inc test_section
  jsr pattern_dmc_fading

  inc test_section
  jsr pattern_sync
skip_all:
  ; fall through to pattern_trash_beep
.endproc

.proc pattern_trash_beep
  ldx test_good_phase
  bne skip_trash_beep

  rowloop:
    stx test_row
    ldy #volramp_data - pattern_y_data
    jsr load_pattern_y
    ldx test_row
    ldy trash_beep_pitches,x
    lda periodTableLo,y
    sta apu_databuf+1
    lda periodTableHi,y
    sta apu_databuf+2
    lda trash_beep_durations,x
    jsr wait_a_ticks
    ldx test_row
    inx
    cpx #TRASH_BEEP_LEN
    bcc rowloop
  lda #5
  jsr silence_a_ticks
skip_trash_beep:
  rts
.endproc

.proc pattern_sync
  jsr silence_20_ticks
  lda #10
  sta test_ticksleft
  syncloop:
    ldy #syncon_data - pattern_y_data
    jsr load_pattern_y
    jsr mdfourier_present
    ldy #pulseoff_data - pattern_y_data
    jsr load_pattern_y
    jsr mdfourier_present
    dec test_ticksleft
    bne syncloop
  ; fall through to silence_20_ticks
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
mdfourier_ready_tone = pattern_sync

;;
; Loads the silence pattern into the address and data buffer
.proc mdfourier_init_apu
  ldy #silence_data - pattern_y_data
  ; fall through to load_pattern_y
.endproc
.proc load_pattern_y
  ldx #0
  beq current_x
  loadloop:
    iny
    lda pattern_y_data,y
    sta apu_databuf,x
    iny
    inx
  current_x:
    lda pattern_y_data,y
    sta apu_addressbuf,x
    bpl loadloop
  loaded:
  rts
.endproc

.proc chromatic_scale_subtype_A
  sta test_subtype
  lda #0
  sta test_row
  sta test_lastpulsehi
  loop:
    ; Writes: volume, period lo, period hi, APU frame reset
    ldx test_row
    lda periodTableLo,x
    sta apu_databuf+1
    lda periodTableHi,x
    sta apu_databuf+2
    lda #$40
    sta apu_databuf+3
    lda #$17
    sta apu_addressbuf+3
    lda #$FF
    sta apu_addressbuf+4

    ; Choose the destination
    lda test_subtype
    cmp #$C0
    bcs is_triangle
      ora #$3F
      sta apu_databuf+0
      lda #$00
      sta apu_addressbuf+0
      lda #$02
      sta apu_addressbuf+1
      lda #$03
      sta apu_addressbuf+2

      ; Pulse: skip period write if same as last
      lda apu_databuf+2
      cmp test_lastpulsehi
      sta test_lastpulsehi
      bne :+
        lda #$FF
        sta apu_addressbuf+2
      :
      jmp rowend
    is_triangle:
      sta apu_databuf+0
      lda #$08
      sta apu_addressbuf+0
      lda #$0A
      sta apu_addressbuf+1
      lda #$0B
      sta apu_addressbuf+2
    rowend:
    
    lda #10
    jsr wait_a_ticks
    inc test_row
    lda test_row
    cmp #87
    bcc loop
  ; fall through to silence_10_ticks
.endproc
.proc silence_10_ticks
  lda #10
  jmp silence_a_ticks
.endproc

.proc noise_scale_subtype_A
  sta test_subtype
  lda #$0F
  sta test_row
  loop:
    ldy #noisenote_data - pattern_y_data
    jsr load_pattern_y
    lda test_row
    ora test_subtype
    sta apu_databuf+1
    lda #20
    jsr wait_a_ticks
    dec test_row
    bpl loop
  rts
.endproc

TRASH_SHORT_BEEP_PERIOD = 932-1

.proc noise_steady
  ; In the v5/v6 profile, this padding was longer (20 frames) than
  ; other paddings.  This let me add another indication of whether
  ; the starting phase of the triangle channel was valid or not.
  ; https://github.com/pinobatch/240p-test-mini/issues/23
  lda #8
  jsr silence_a_ticks

  ; High pitch for good tri phase, low pitch for trashed
  ldy #volramp_data - pattern_y_data
  jsr load_pattern_y
  lda test_good_phase
  bne keep_tone_high_for_valid_phase
    lda #<TRASH_SHORT_BEEP_PERIOD
    sta apu_databuf+1
    lda #>TRASH_SHORT_BEEP_PERIOD
    sta apu_databuf+2
  keep_tone_high_for_valid_phase:
  lda #2
  jsr wait_a_ticks

  jsr silence_10_ticks

  ldy #noisenote_data - pattern_y_data
  jsr load_pattern_y
  lda #88
  jsr wait_a_ticks
  lda #12
  jmp silence_a_ticks
.endproc

.proc pattern_dmc_pops
  ldy #$7F
  jsr dmc_pop_y_wait_20
  ldy #$00
.endproc
.proc dmc_pop_y_wait_20
  lda #20
.endproc
.proc dmc_pop_y_wait_a
  sty apu_databuf+0
  ldy #$11
  sty apu_addressbuf+0
  ldy #$FF
  sty apu_addressbuf+1
  jmp wait_a_ticks
.endproc

.proc pattern_dmc_scale
  lda #0
  sta test_row
  loop:
    ldy #instsamp1_data - pattern_y_data
    jsr load_pattern_y
    lda test_row
    sta apu_databuf+1
    lda #19
    jsr wait_a_ticks
    ldy #homeposition_data - pattern_y_data
    jsr load_pattern_y
    jsr mdfourier_present
    inc test_row
    lda test_row
    cmp #16
    bcc loop
  jmp silence_20_ticks
.endproc

PHASE_RESET_START_PERIOD = 284
PHASE_SLIDE_START_PERIOD = 268

.proc pattern_phase_resets
  ; 1. Phase reset each tick
  lda #20
  sta test_ticksleft
  loop1:
    ldy #phase_slide_data - pattern_y_data
    jsr load_pattern_y
    lda #<PHASE_RESET_START_PERIOD
    sta apu_databuf+2
    jsr mdfourier_present
    dec test_ticksleft
    bne loop1
  jsr silence_10_ticks

  ; 2. Hardware sweep
  ldy #phase_slide_data - pattern_y_data
  jsr load_pattern_y
  lda #$9F
  sta apu_databuf+1
  lda #20
  jsr wait_a_ticks
  jsr silence_10_ticks

  ; 3. Software sweep
  ldy #phase_slide_data - pattern_y_data
  jsr load_pattern_y
  jsr mdfourier_present
  lda #<(PHASE_SLIDE_START_PERIOD - 2)
  sta test_ticksleft
  lda #>(PHASE_SLIDE_START_PERIOD - 2)
  sta test_lastpulsehi
  loop:
    lda #$06
    sta apu_addressbuf+0
    lda #$FF
    sta apu_addressbuf+1
    sta apu_addressbuf+2

    lda test_ticksleft
    sec
    sbc #2
    sta apu_databuf+0
    sta test_ticksleft
    lda test_lastpulsehi
    sbc #0
    cmp test_lastpulsehi
    sta test_lastpulsehi
    sta apu_databuf+1
    beq :+
      lda #$07
      sta apu_addressbuf+1
    :

    jsr mdfourier_present
    lda test_ticksleft
    cmp #<(PHASE_SLIDE_START_PERIOD - 40)
    bne loop

  jmp silence_10_ticks
.endproc

.proc long_slide_channel_A  ; $04 or $08
  sta test_subtype
  sta apu_addressbuf+0
  ora #$02
  sta apu_addressbuf+1
  ora #$01
  sta apu_addressbuf+2

  cmp #8
  lda #$3F
  bcc :+
    ror a
  :
  sta apu_databuf+0

  ; For a steady A, we would write 253 for a period of 254.
  ; But FamiTracker applies a pitch slide effect to a note's
  ; first tick as well.  So we need to start it at 252.
  lda #252
  sta apu_databuf+1
  sta test_ticksleft
  lda #0
  sta apu_databuf+2
  lda #$17
  sta apu_addressbuf+3
  lda #$40
  sta apu_databuf+3  ; APU Frame Counter reset
  lda #$FF
  sta apu_addressbuf+4

  ; 253 ticks decreasing period
  loop:
    jsr mdfourier_present
    lda test_subtype
    ora #2
    sta apu_addressbuf+0
    lda #$FF
    sta apu_addressbuf+1
    dec test_ticksleft
    lda test_ticksleft
    sta apu_databuf
    bne loop

  ; 18 ticks of highest ultrasound (tri) or muting (pulse),
  ; then 10 of silence
  lda #18
  jsr wait_a_ticks
  jmp silence_10_ticks
.endproc

.proc pattern_pulse_volume_ramp
  lda #0
  sta test_subtype
  testloop:
    ldy #volramp_data - pattern_y_data
    jsr load_pattern_y
    lda #15
    sta test_row
    ldy test_subtype
    lda volramp_periods,y
    sta apu_databuf+4
    lda volramp_addamounts,y
    and #$0F
    ora #$B0
    sta test_lastpulsehi  ; (ab)used to hold pulse 2 parameter
    sta apu_databuf+3

    testrowloop:
      lda #5
      jsr wait_a_ticks
      lda #$00
      sta apu_addressbuf+0
      lda #$04
      sta apu_addressbuf+1
      lda #$FF
      sta apu_addressbuf+2
      ldy test_subtype
      clc
      lda volramp_addamounts,y
      adc test_lastpulsehi
      sta test_lastpulsehi
      sta apu_databuf+1
      dec test_row
      lda test_row
      ora #$B0
      sta apu_databuf+0
      lda test_row
      bne testrowloop
    jsr silence_15_ticks
    inc test_subtype
    lda test_subtype
    cmp #5
    bcc testloop
  rts
.endproc

.proc pattern_noise_volume_ramp
  ldy #noise_volramp_data - pattern_y_data
  jsr load_pattern_y
  lda #15
  sta test_row
  loop:
    lda #5
    jsr wait_a_ticks
    lda #$0C
    sta apu_addressbuf+0
    lda #$FF
    sta apu_addressbuf+1
    dec test_row
    lda test_row
    ora #$30
    sta apu_databuf+0
    lda test_row
    bne loop

  ; fall through to silence_5_ticks
.endproc
.proc silence_15_ticks
  lda #15
  jmp silence_a_ticks
.endproc

.proc pattern_dmc_fading
  ldx #9
  loop:
    stx test_row
    ldy #dmc_fading_step1_data - pattern_y_data
    jsr load_pattern_y
    ldx test_row
    lda dmc_fading_values,x
    sta apu_databuf+0
    lda #10
    jsr wait_a_ticks
    ldy #dmc_fading_step2_data - pattern_y_data
    jsr load_pattern_y
    lda #20
    jsr wait_a_ticks
    ldy #dmc_fading_step3_data - pattern_y_data
    jsr load_pattern_y
    lda #20
    jsr wait_a_ticks
    ldy #dmc_fading_step4_data - pattern_y_data
    jsr load_pattern_y
    lda #10
    jsr wait_a_ticks
    ldx test_row
    dex
    bpl loop

  ; This pattern leaves ultrasound playing on triangle.  It is the
  ; responsibility of the next pattern (currently the ending pulse)
  ; to silence it.
  rts
.endproc


.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.rodata
.endif
pattern_y_data:
silence_data:
  ; Silence pulses, reset their phase, and disable sweep
  .dbyt $00B0, $04B0, $0108, $0508, $0200, $0600, $0300, $0700
  ; Silence triangle and noise
  .dbyt $0800, $0CB0
  ; Silence DPCM, set highest pitch and default level,
  ; and enable other channels (which were just set silent)
  .dbyt $100F, $1100, $150F
  ; Reset APU length counter
  .dbyt $1780
  .byte $FF

syncon_data:
  ; 8 kHz 50% pulse
  .dbyt $00BF, $020D, $0300
  .byte $FF

pulseoff_data:
  ; 8 kHz 50% pulse
  .dbyt $00B0
  .byte $FF

noisenote_data:
  .dbyt $0C3F, $0E01, $0F00
  .byte $FF

instsamp1_data:
  .dbyt $150F
  .dbyt $100F
  .dbyt $1200 | <(instsamp1_dmc >> 6)
  .dbyt $1300 | <((instsamp1_dmc_end - instsamp1_dmc) >> 4)
  .dbyt $151F
  .byte $FF
  
homeposition_data:
  .dbyt $150F
  .dbyt $100C
  .dbyt $1200 | <(homeposition_dmc >> 6)
  .dbyt $1301
  .dbyt $151F
  .byte $FF

phase_slide_data:
  .dbyt $043F, $0508
  .dbyt $0600|<PHASE_SLIDE_START_PERIOD, $0700|>PHASE_SLIDE_START_PERIOD
  .dbyt $1740
  .byte $FF

volramp_data:
  .dbyt $00BF, $026F, $0300, $04B0, $06DF, $0700
  .byte $FF

dmc_fading_step1_data:
  .dbyt $1100
  .dbyt $08FF, $0A00, $0B00, $1780  ; triangle on ultrasound
  .byte $FF

dmc_fading_step2_data:
  .dbyt $0A37  ; triangle to 1 kHz
  .byte $FF

dmc_fading_step3_data:
  .dbyt $0A00  ; triangle back to ultrasound
noise_volramp_data:
  .dbyt $0C3F, $0E07, $0F00
  .byte $FF

dmc_fading_step4_data:
  .dbyt $0C30  ; noise off
  .byte $FF

.out .sprintf("%d of 256 pattern_y_data bytes used", * - pattern_y_data)

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.segment "DMC"
.endif
.align 64
instsamp1_dmc:    .incbin "audio/instsamp1.dmc"
instsamp1_dmc_end:

; there are 63 bytes usable for anything
volramp_periods:
  .byte 255, 223, 111, 223, 111
volramp_addamounts:
  .byte 0, <-1, <-1, 1, 1

dmc_fading_values:  ; in reverse order
  .byte $00, $7F, $6F, $5F, $4F, $3F, $2F, $1F, $0F, $00

trash_beep_pitches:
  .byte 34, 39, 43, 34, 37, 41
TRASH_BEEP_LEN = * - trash_beep_pitches
trash_beep_durations:
  .byte 3, 3, 4, 3, 3, 9

.align 64
homeposition_dmc: .res 17, $00
